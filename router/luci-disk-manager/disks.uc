'use strict';
import { access, readfile, open, mkdir, chmod, lstat, mkdtemp, unlink, rmdir, glob, basename } from 'fs';
import { cursor } from 'uci';
const STATE = '/tmp/nas-disks';
const KEYS = '/etc/nas-disks/keys';
function ident(uuid) { return 'v_' + replace(uuid, /[^A-Za-z0-9_]/g, '_'); }
function jsonfile(path, fallback) { try { return json(readfile(path) || 'null') || fallback; } catch (e) { return fallback; } }
function init_state() {
    mkdir(STATE);
    let st = lstat(STATE);
    return st && st.type == 'directory' && st.uid == 0 && chmod(STATE, 0o700);
}
function inventory() { return jsonfile(STATE + '/inventory.json', { scanned_at: 0, disks: [] }); }
function volume(uuid) {
    if (type(uuid) != 'string' || !match(uuid, /^[A-Za-z0-9-]{1,64}$/)) return null;
    for (let disk in inventory().disks)
        for (let part in disk.partitions)
            if (part.uuid == uuid) return part;
    return null;
}
function driver_ready(kind) {
    let driver = (kind == 'ntfs' || kind == 'BitLocker') ? 'ntfs3' : kind;
    if (!match(driver || '', /^[a-z0-9]+$/)) return false;
    let kernel = trim(readfile('/proc/sys/kernel/osrelease') || '');
    return !!match(readfile('/proc/filesystems') || '', regexp('(^|\n)[^\n]*[\t ]' + driver + '(\n|$)')) ||
        access('/lib/modules/' + kernel + '/' + driver + '.ko');
}
function status() {
    let result = inventory(), cfg = cursor(), mounts = {};
    let actual = [];
    for (let path in glob('/sys/class/block/*')) {
        let name = basename(path);
        if (match(name, /^(mtd|ubi|loop|ram|zram|dm-)/) || access(path + '/partition') || !access(path + '/device')) continue;
        push(actual, name + ':' + trim(readfile(path + '/diskseq') || ''));
    }
    let previous = map(result.disks, function(d) { return d.name + ':' + (d.sequence || ''); });
    if (join(sort(actual), '|') != join(sort(previous), '|') && !access(STATE + '/scan.lock')) scan();
    for (let line in split(readfile('/proc/mounts') || '', '\n')) {
        let f = split(line, ' ');
        if (length(f) >= 4) mounts[f[0]] = { path: replace(f[1], /\\040/g, ' '), mode: match(f[3], /(^|,)ro(,|$)/) ? 'ro' : 'rw' };
    }
    for (let disk in result.disks) {
        disk.online = access('/sys/class/block/' + disk.name + '/device');
        for (let part in disk.partitions) {
            let conf = part.id ? cfg.get_all('nas_disks', part.id) || {} : {};
            part.settings = { name: conf.name || part.label || part.device, path: conf.path || part.hint_path,
                readonly: conf.readonly != '0', enabled: conf.enabled == '1', configured: !!conf.uuid };
            let key = part.id ? lstat(KEYS + '/' + part.id) : null;
            part.key_saved = !!(key && key.size > 0);
            part.driver_ready = driver_ready(part.fstype);
            part.mount = mounts[part.device] || mounts['/dev/mapper/nasd_' + part.id] || null;
            part.unlocked = part.id ? access('/dev/mapper/nasd_' + part.id) : false;
            part.paused = part.id ? access(STATE + '/' + part.id + '.paused') : false;
            part.job = part.id ? jsonfile(STATE + '/' + part.id + '.json', {}) : {};
        }
    }
    result.scanning = access(STATE + '/scan.lock');
    result.busy = access(STATE + '/action.lock');
    result.module_ready = access('/sys/module/dm_zero');
    result.supported = split(trim(readfile('/proc/filesystems') || ''), '\n');
    return result;
}
function scan() {
    if (!init_state()) return { error: 'state_unavailable' };
    system('/usr/sbin/nas-disks-scan </dev/null >/dev/null 2>&1 &');
    return { accepted: true };
}
function configure(req) {
    let p = volume(req.args.uuid);
    if (!p) return { error: 'volume_missing' };
    if (access(STATE + '/action.lock')) return { error: 'busy' };
    let path = req.args.path || p.hint_path;
    if (!match(path, /^\/mnt\/[A-Za-z0-9_./-]+$/) || index(path, '..') >= 0 || length(path) > 120 || match(path, /\/$/))
        return { error: 'invalid_path' };
    let current = status();
    for (let d in current.disks) for (let other in d.partitions) {
        if (other.uuid == p.uuid && other.mount && other.mount.path != path) return { error: 'mounted_path' };
        if (other.uuid != p.uuid && other.settings.path == path) return { error: 'path_in_use' };
    }
    let name = req.args.name || p.label || p.device;
    if (length(name) > 64) return { error: 'invalid_name' };
    let c = cursor();
    c.set('nas_disks', p.id, 'volume');
    c.set('nas_disks', p.id, 'uuid', p.uuid);
    c.set('nas_disks', p.id, 'fstype', p.fstype);
    c.set('nas_disks', p.id, 'name', name);
    c.set('nas_disks', p.id, 'path', path);
    c.set('nas_disks', p.id, 'readonly', req.args.readonly ? '1' : '0');
    c.set('nas_disks', p.id, 'enabled', req.args.enabled ? '1' : '0');
    if (!c.commit('nas_disks')) return { error: 'save_failed' };
    // One manager owns automount for adopted volumes; do not compete with fstab.
    c.foreach('fstab', 'mount', function(s) {
        if (s.uuid && lc(s.uuid) == lc(p.uuid)) c.set('fstab', s['.name'], 'enabled', '0');
    });
    c.commit('fstab');
    return { ok: true };
}
function action(req) {
    if (!init_state()) return { error: 'state_unavailable' };
    let p = volume(req.args.uuid), op = req.args.operation;
    if (!p || !access(p.device)) return { error: 'volume_missing' };
    if (op != 'mount' && op != 'unmount') return { error: 'invalid_action' };
    if (op == 'mount' && !driver_ready(p.fstype)) return { error: 'driver_missing' };
    if (!cursor().get('nas_disks', p.id, 'uuid')) return { error: 'not_configured' };
    let secret = req.args.password || '';
    if (length(secret) > 1024 || index(secret, '\x00') >= 0) return { error: 'invalid_password' };
    if (op == 'mount' && p.fstype == 'BitLocker') {
        if (!access('/sys/module/dm_zero')) return { error: 'module_missing' };
        if (!length(secret) && !access(KEYS + '/' + p.id)) return { error: 'password_required' };
    }
    if (!mkdir(STATE + '/action.lock')) return { error: 'busy' };
    let job = mkdtemp('/tmp/nas-disks-key.XXXXXX');
    if (!job) { rmdir(STATE + '/action.lock'); return { error: 'state_unavailable' }; }
    if (length(secret) && p.fstype == 'BitLocker') {
        let f = open(job + '/key', 'wx', 0o600);
        if (!f) { rmdir(job); rmdir(STATE + '/action.lock'); return { error: 'state_unavailable' }; }
        let n = f.write(secret); f.close();
        if (n != length(secret)) {
            unlink(job + '/key'); rmdir(job); rmdir(STATE + '/action.lock'); return { error: 'state_unavailable' };
        }
    }
    secret = null;
    let f = open(STATE + '/' + p.id + '.json', 'w', 0o600);
    if (f) { f.write('{"phase":"working","result":""}'); f.close(); }
    system('/usr/sbin/nas-disks-job ' + p.id + ' ' + job + ' ' + op + ' </dev/null >/dev/null 2>&1 &');
    return { accepted: true };
}
return { 'nas.disks': {
    status: { call: status }, scan: { call: scan },
    configure: { args: { uuid: '', name: '', path: '', readonly: true, enabled: false }, call: configure },
    action: { args: { uuid: '', operation: '', password: '' }, call: action }
} };
