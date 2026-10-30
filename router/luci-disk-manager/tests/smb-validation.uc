'use strict';
import { readfile } from 'fs';
let source = readfile(ARGV[0] || '/usr/share/rpcd/ucode/nas-smb.uc');
// Expose only to this in-memory test wrapper, never through the production RPC.
let api = loadstring(replace(source, "return { 'nas.smb':", "return { nt_hash, private_share, 'nas.smb':"))();
let vectors = [
    ['', 'MdbP4NFq6TG3PFnX4MCJwA=='],
    ['password', 'iEb36u6PsRetBr3YMLdYbA=='],
    ['Mật khẩu thử 😊', 'qSl0IFQdm6b0cZ3CArHQDA=='],
    ['end_-', 'ORwqG/nUziwtxi45wmVH1g=='],
    ['xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'ZWgQI9DLXn6W/2YhUO8GDQ==']
];
for (let vector in vectors)
    if (api.nt_hash(vector[0]) != vector[1]) die('NT hash vector mismatch\n');
if (api.nt_hash(chr(0xc0, 0xaf)) != null) die('Accepted invalid UTF-8\n');
print('PASS: 5 NT hash vectors including Vietnamese, supplementary Unicode and maximum length; invalid UTF-8 rejected\n');
let folder = {'.type':'share',name:'test',path:'/mnt/test',guest_ok:'no'};
if (!api.private_share(folder)) die('Rejected a private share\n');
for (let flag in ['1','yes','true','on','YES']) {
    folder.force_root = flag;
    if (api.private_share(folder)) die('Accepted Force Root share\n');
}
print('PASS: all Force Root boolean forms rejected\n');

let cases = [
    [{user:'bad;name',password:'test-only-password',shares:['dangkhoa']}, 'invalid_username'],
    [{user:'safe_test',password:'short',shares:['dangkhoa']}, 'invalid_password'],
    [{user:'safe_test',password:'bad\npassword',shares:['dangkhoa']}, 'invalid_password'],
    [{user:'safe_test',password:'test-only-password',shares:[]}, 'select_shares'],
    [{user:'root',password:'test-only-password',shares:['dangkhoa']}, 'account_exists'],
    [{user:'safe_test',password:'test-only-password',shares:['../../etc']}, 'invalid_share'],
    [{user:'safe_test',password:'test-only-password',shares:['does_not_exist']}, 'share_not_private']
];
for (let entry in cases) {
    let result = api['nas.smb'].create.call({args:entry[0]});
    if (result.error != entry[1]) die(sprintf('Expected %s, got %J\n', entry[1], result));
}
print(sprintf('PASS: %d invalid creation requests rejected without adding users\n', length(cases)));
