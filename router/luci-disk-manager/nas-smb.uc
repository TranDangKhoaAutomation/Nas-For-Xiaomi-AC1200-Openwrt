'use strict';
import { readfile, open, stat, mkdir, rmdir, rename, unlink, access } from 'fs';
import { md4 } from 'digest';
import { cursor } from 'uci';

const LOCK = '/var/lock/nas-smb.lock';
function valid_secret(secret) {
    return type(secret) == 'string' && length(secret) >= 8 && length(secret) <= 128 &&
        index(secret, '\x00') < 0 && index(secret, '\r') < 0 && index(secret, '\n') < 0;
}
function nt_hash(secret) {
    let utf16 = '';
    for (let i = 0; i < length(secret);) {
        let first = ord(substr(secret, i++, 1)), cp, extra, minimum;
        if (first < 0x80) { cp = first; extra = 0; minimum = 0; }
        else if (first >= 0xc2 && first <= 0xdf) { cp = first & 0x1f; extra = 1; minimum = 0x80; }
        else if (first >= 0xe0 && first <= 0xef) { cp = first & 0x0f; extra = 2; minimum = 0x800; }
        else if (first >= 0xf0 && first <= 0xf4) { cp = first & 7; extra = 3; minimum = 0x10000; }
        else return null;
        for (let j = 0; j < extra; j++) {
            if (i >= length(secret)) return null;
            let next = ord(substr(secret, i++, 1));
            if ((next & 0xc0) != 0x80) return null;
            cp = (cp << 6) | (next & 0x3f);
        }
        if (cp < minimum || cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff)) return null;
        if (cp > 0xffff) {
            cp -= 0x10000;
            let high = 0xd800 | (cp >> 10), low = 0xdc00 | (cp & 0x3ff);
            utf16 += chr(high & 255, high >> 8, low & 255, low >> 8);
        }
        else utf16 += chr(cp & 255, cp >> 8);
    }
    let hex = md4(utf16), raw = '';
    utf16 = null;
    for (let i = 0; i < 32; i += 2) raw += chr(int(substr(hex, i, 2), 16));
    return b64enc(raw);
}
function set_secret(user, secret, mode) {
    // KSMBD 3.5.6's terminal password prompt uses uninitialized termios on a pipe.
    // Generate the documented NT hash in-process and atomically replace its DB row.
    // Cleartext never enters argv, a child process, or a temporary file.
    let hash = nt_hash(secret);
    secret = null;
    if (!hash) return false;
    let path = '/etc/ksmbd/ksmbdpwd.db', original = readfile(path);
    if (original == null) return false;
    let found = false, lines = [];
    for (let line in split(original, '\n')) {
        if (!length(line)) continue;
        if (split(line, ':')[0] == user) {
            if (mode == '-a' || found) return false;
            found = true; line = user + ':' + hash;
        }
        push(lines, line);
    }
    if (mode == '-u' && !found) return false;
    if (!found) push(lines, user + ':' + hash);
    let text = join('\n', lines) + '\n';
    let out = open(path + '.nas-new', 'w', 0o600);
    if (!out) return false;
    let written = out.write(text); out.close();
    hash = null; text = null;
    if (written == length(join('\n', lines)) + 1 && rename(path + '.nas-new', path)) return true;
    unlink(path + '.nas-new'); return false;
}
function known_user(user) {
    for (let path in ['/etc/passwd', '/etc/ksmbd/ksmbdpwd.db'])
        for (let line in split(readfile(path) || '', '\n'))
            if (lc(split(line, ':')[0]) == user) return true;
    return false;
}
function private_share(s) {
    return s && s['.type'] == 'share' && s.enabled != '0' && s.name &&
        (s.guest_ok == 'no' || s.guest_ok == '0') &&
        index(['1','yes','true','on'], lc(s.force_root || '')) < 0 &&
        type(s.path) == 'string' && index(s.path, '/mnt/') == 0 && index(s.path, '..') < 0;
}
// Roll back only this newly-created identity. Never remove homes or NAS files.
function remove_identity(user) {
    let present = false;
    for (let line in split(readfile('/etc/ksmbd/ksmbdpwd.db') || '', '\n'))
        if (split(line, ':')[0] == user) present = true;
    let ok = !present || system('/usr/sbin/ksmbd.adduser -d ' + user + ' >/dev/null 2>&1') == 0;
    for (let path in ['/etc/passwd', '/etc/shadow']) {
        let original = readfile(path), st = stat(path);
        if (!original || !st) continue;
        let lines = filter(split(original, '\n'), function(line) { return split(line, ':')[0] != user; });
        let out = open(path + '.nas-smb-new', 'w', st.mode & 0o777);
        if (!out) { ok = false; continue; }
        let text = join('\n', lines), written = out.write(text);
        out.close();
        if (written != length(text) || !rename(path + '.nas-smb-new', path)) {
            unlink(path + '.nas-smb-new'); ok = false;
        }
    }
    return ok;
}

function create_locked(req) {
    let user = req.args.user, secret = req.args.password, selected = req.args.shares;
    if (type(user) != 'string' || !match(user, /^[a-z][a-z0-9_-]{0,30}$/)) return { error:'invalid_username' };
    if (!valid_secret(secret)) return { error:'invalid_password' };
    if (type(selected) != 'array' || !length(selected) || length(selected) > 32) return { error:'select_shares' };
    if (known_user(user)) return { error:'account_exists' };
    if (!access('/usr/sbin/useradd')) return { error:'useradd_missing' };
    let cfg = cursor(), shares = [], seen = {}, uid = null, gid = null;
    if (length(cfg.changes('ksmbd') || {})) return { error:'configuration_pending' };
    for (let id in selected) {
        if (type(id) != 'string' || !match(id, /^[A-Za-z0-9_]{1,64}$/) || seen[id]) return { error:'invalid_share' };
        seen[id] = true;
        let s = cfg.get_all('ksmbd', id);
        if (!private_share(s)) return { error:'share_not_private' };
        let owner = stat(s.path);
        if (!owner || owner.type != 'directory' || owner.uid <= 0 || owner.uid >= 65534 || owner.gid <= 0 ||
            (uid != null && (uid != owner.uid || gid != owner.gid))) return { error:'storage_owner_unavailable' };
        uid = owner.uid; gid = owner.gid;
        let users = type(s.users) == 'array' ? s.users : filter(split(s.users || '', /[ ,\t]+/), function(v) { return length(v); });
        push(shares, {id, original:s.users, users});
    }
    // SMB-only aliases use the existing data owner's non-root UID. No Unix password,
    // shell, home or root access is granted; KSMBD still enforces each share's users.
    let command = sprintf('/usr/sbin/useradd -r -M -N -o -u %d -g %d -d /var/empty -s /bin/false -c "Khoa NAS SMB account" %s >/dev/null 2>&1', uid, gid, user);
    if (system(command) != 0) return { error:'user_creation_failed' };
    let committed = false;
    try {
        if (!set_secret(user, secret, '-a')) die('credential_write_failed');
        secret = null;
        for (let share in shares)
            if (!cfg.set('ksmbd', share.id, 'users', join(' ', [...share.users, user]))) die('config_write_failed');
        if (!cfg.commit('ksmbd')) die('config_write_failed');
        committed = true;
        if (system('/etc/init.d/ksmbd restart >/dev/null 2>&1') != 0) die('service_reload_failed');
        return {ok:true, user};
    }
    catch (e) {
        secret = null;
        cfg.revert('ksmbd');
        for (let share in shares) {
            if (share.original == null) cfg.delete('ksmbd', share.id, 'users');
            else cfg.set('ksmbd', share.id, 'users', share.original);
        }
        let restored = cfg.commit('ksmbd'), removed = remove_identity(user);
        if (committed) system('/etc/init.d/ksmbd restart >/dev/null 2>&1');
        return { error: restored && removed ? 'account_creation_failed' : 'cleanup_required' };
    }
}
function create(req) {
    if (!mkdir(LOCK, 0o700)) return { error:'busy' };
    let result;
    try { result = create_locked(req); }
    catch (e) { result = {error:'account_creation_failed'}; }
    rmdir(LOCK);
    return result;
}

function password(req) {
    let user = req.args.user, secret = req.args.password;
    if (type(user) != 'string' || !match(user, /^[A-Za-z_][A-Za-z0-9_.-]{0,46}$/))
        return { error: 'account_not_allowed' };
    let allowed = false;
    cursor().foreach('ksmbd', 'share', function(s) {
        let users = type(s.users) == 'array' ? s.users : split(s.users || '', /[ ,\t]+/);
        if (index(users, user) >= 0) allowed = true;
    });
    if (!allowed) return { error: 'account_not_allowed' };
    if (!valid_secret(secret))
        return { error: 'invalid_password' };
    // Update an existing SMB account only; persist its hash, never cleartext.
    if (!mkdir(LOCK, 0o700)) return { error:'busy' };
    let ok = false;
    try { ok = set_secret(user, secret, '-u'); } catch (e) {}
    secret = null; rmdir(LOCK);
    if (!ok) return { error:'update_failed' };
    system('/etc/init.d/ksmbd restart >/dev/null 2>&1');
    return { ok: true };
}

return { 'nas.smb': {
    password: { args: { user: '', password: '' }, call: password },
    create: { args: { user:'', password:'', shares:[] }, call:create }
} };
