#!/usr/bin/ucode
'use strict';
import { access, readfile, open } from 'fs';

// Keep the stock KSMBD view and ACL; its former route is an alias in menu.json.
// Remove only its menu declaration to avoid a duplicate entry beside NAS tabs.
const path = '/usr/share/luci/menu.d/luci-app-ksmbd.json';
if (access(path)) {
    let menu = json(readfile(path));
    delete menu['admin/services/ksmbd'];
    let out = open(path, 'w', 0o644);
    if (!out) die('Cannot consolidate the NAS menu');
    out.write(sprintf('%J\n', menu)); out.close();
}
