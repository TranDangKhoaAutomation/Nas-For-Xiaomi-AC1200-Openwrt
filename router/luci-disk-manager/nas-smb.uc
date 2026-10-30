'use strict';
import { popen } from 'fs';
import { cursor } from 'uci';

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
    if (type(secret) != 'string' || length(secret) < 8 || length(secret) > 128 ||
        index(secret, '\x00') >= 0 || index(secret, '\r') >= 0 || index(secret, '\n') >= 0)
        return { error: 'invalid_password' };
    // Existing SMB account only. The password stays on stdin, never argv or disk.
    let pipe = popen('/usr/sbin/ksmbd.adduser -u ' + user + ' >/dev/null 2>&1', 'w');
    if (!pipe) return { error: 'update_failed' };
    let payload = secret + '\n' + secret + '\n';
    let written = pipe.write(payload);
    secret = null;
    let expected = length(payload);
    payload = null;
    let result = pipe.close();
    if (written != expected || result != 0) return { error: 'update_failed' };
    system('/etc/init.d/ksmbd restart >/dev/null 2>&1');
    return { ok: true };
}

return { 'nas.smb': { password: { args: { user: '', password: '' }, call: password } } };
