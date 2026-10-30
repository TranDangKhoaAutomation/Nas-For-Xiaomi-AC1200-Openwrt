#!/usr/bin/ucode
'use strict';
import { access, readfile, open } from 'fs';

const path = '/usr/share/ucode/luci/template/themes/material/header.ut';
if (!access(path)) exit(0); // Other LuCI themes do not need this Material fix.
let header = readfile(path);
if (!header || index(header, 'cascade.css') < 0) die('Material header is not recognized');
let lines = [];
let hasCss = index(header, 'menu-layout-fix.css') >= 0;
for (let line in split(header, '\n')) {
    if (index(line, 'admin/translations') >= 0) {
        line = replace(line, /nas-disks-\d{8}-\d+/g, 'nas-disks-20261030-5');
        line = replace(line, /nas_disks_v=\d{8}-\d+/g, 'nas_disks_v=20261030-5');
    }
    if (index(line, 'admin/translations') >= 0 && index(line, 'nas_disks_v=') < 0) {
        let end = index(line, '"></script>');
        if (end >= 0) {
            let before = substr(line, 0, end);
            line = before + (index(before, '?') >= 0 ? '&' : '?') +
                'nas_disks_v=20261030-5' + substr(line, end);
        }
    }
    push(lines, line);
    if (!hasCss && index(line, '<link rel="stylesheet"') >= 0 && index(line, 'cascade.css') >= 0)
        push(lines, '<link rel="stylesheet" href="{{ media }}/menu-layout-fix.css?v=20261029-1">');
}
let f = open(path, 'w', 0o644);
if (!f) die('Cannot update Material header');
f.write(join('\n', lines)); f.close();

// LuCI uses the luci.js query string for all dynamically loaded view modules.
// Version custom views as well as translations when upgrading this integration.
const commonPath = '/usr/share/ucode/luci/template/header.ut';
let common = readfile(commonPath);
if (!common || index(common, '/luci.js?v=') < 0) die('LuCI header is not recognized');
let commonLines = [];
for (let line in split(common, '\n')) {
    if (index(line, '/luci.js?v=') >= 0) {
        line = replace(line, /-nas-disks-\d{8}-\d+/g, '');
        line = replace(line, '"></script>', '-nas-disks-20261030-5"></script>');
    }
    push(commonLines, line);
}
let commonFile = open(commonPath, 'w', 0o644);
if (!commonFile) die('Cannot update LuCI resource version');
commonFile.write(join('\n', commonLines)); commonFile.close();
