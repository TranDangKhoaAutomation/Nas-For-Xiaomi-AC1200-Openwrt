'use strict';
'require view';
'require rpc';
'require ui';

var getInfo = rpc.declare({object:'nas.disks',method:'connection_info',expect:{'':{}},reject:true});

function steps(items) {
    return E('ol', {'style':'padding-left:24px;line-height:1.8'}, items.map(function(item) {
        return E('li', {}, [item]);
    }));
}
function section(title, nodes) {
    return E('section', {'class':'cbi-section'}, [E('h3', {}, [title])].concat(nodes));
}
function value(label, text, copy) {
    var input = E('input', {'type':'text','readonly':true,'value':text || '',
        'aria-label':label,'style':'width:100%;min-width:0;font-family:monospace'});
    var nodes = [input];
    if (copy && text) nodes.push(E('button', {'type':'button','class':'cbi-button','click':function() {
        input.focus(); input.select();
        var copied = false;
        try { copied = document.execCommand('copy'); } catch (e) {}
        ui.addNotification(null, E('p', {}, [copied ? _('Copied.') : _('Press Ctrl+C or long-press to copy the selected value.')]), 'info');
    }}, [_('Copy')]));
    return E('div', {'style':'margin:10px 0'}, [E('label', {}, [label]),
        E('div', {'style':'display:flex;gap:8px;align-items:center'}, nodes)]);
}

return view.extend({
    // Existing LuCI sessions may still cache the menu from before installation.
    load:function() { ui.menu.flushCache(); return getInfo(); },
    render:function(initial) {
        var info = initial, content = E('div'), selected = '', method = 'remote', platform = 'windows';
        var refresh = E('button', {'type':'button','class':'cbi-button cbi-button-action'}, [_('Refresh connection details')]);
        refresh.addEventListener('click', function() {
            refresh.disabled = true;
            getInfo().then(function(data) { info = data; draw(); }).catch(function() {
                ui.addNotification(null, E('p', {}, [_('Connection details could not be loaded. Try again.')]), 'error');
            }).finally(function() { refresh.disabled = false; });
        });
        function draw() {
            var shares = info.shares || [];
            var share = shares.filter(function(s) { return s.name === selected; })[0] ||
                shares.filter(function(s) { return s.mounted; })[0] || shares[0];
            selected = share ? share.name : '';
            var host = method === 'remote' ? info.tailscale_ip : info.lan_ip;
            var mode = E('select', {'aria-label':_('Connection type')}, [
                E('option', {'value':'remote'}, [_('Remote access (Tailscale)')]),
                E('option', {'value':'lan'}, [_('Home network (LAN)')])
            ]);
            mode.value = method;
            mode.addEventListener('change', function() { method = mode.value; draw(); });
            var choose = E('select', {'aria-label':_('Shared folder')}, shares.map(function(s) {
                return E('option', {'value':s.name}, [s.name + ' — ' + (s.mounted ?
                    (s.readonly ? _('Mounted read-only') : _('Mounted read-write')) : _('Not mounted'))]);
            }));
            choose.value = selected;
            choose.addEventListener('change', function() { selected = choose.value; draw(); });
            var nodes = [section(_('1. Choose a connection and shared folder'), [
                E('p', {}, [_('Addresses and shares below come from this router. Refresh after changing disks, shares or Tailscale.')]),
                E('div', {'style':'display:flex;gap:16px;flex-wrap:wrap'}, [
                    E('label', {}, [_('Connection type') + ' ', mode]),
                    E('label', {}, [_('Shared folder') + ' ', choose])
                ]),
                value(_('Router address'), host || _('Not available'), !!host),
                E('p', {}, [method === 'remote' ?
                    _('Install Tailscale on Windows or Android, sign in to a tailnet allowed to reach this router, and keep it connected. The router must also be online in Tailscale. No exit node is needed to access the router itself.') :
                    _('Connect the computer or phone to this router’s home network. This LAN address is not for access over mobile data or another network.')]),
                method === 'remote' ? E('p', {}, [E('a', {'href':'https://tailscale.com/download','target':'_blank','rel':'noopener noreferrer'}, [_('Download Tailscale')])]) : ''
            ])];
            if (!host) nodes.push(E('p', {'class':'alert-message warning'}, [method === 'remote' ?
                _('No Tailscale IPv4 address is available. Check Tailscale in Services, connect the router, then refresh this page.') :
                _('No LAN IPv4 address is available. Check the LAN configuration, then refresh this page.')]));
            if (!share) nodes.push(E('p', {'class':'alert-message warning'}, [
                _('No SMB shares are configured. Configure network shares first, then refresh this page.')]));
            if (share) {
                if (!share.mounted) nodes.push(E('p', {'class':'alert-message warning'}, [
                    _('The shared folder has no detected data mount under /mnt. Open Disk Manager and mount or unlock the correct volume before connecting.')]));
                else if (share.readonly) nodes.push(E('p', {'class':'alert-message notice'}, [
                    _('This share is read-only. You can open files and copy them to your device; creating, renaming or deleting files on the NAS is unavailable.')]));
                var account = share.users ? (Array.isArray(share.users) ? share.users.join(', ') : share.users) :
                    (share.guest ? _('Guest access is enabled') : _('Ask the router administrator for an SMB account'));
                var tabs = E('ul', {'class':'cbi-tabmenu'}, ['windows','android'].map(function(p) {
                    return E('li', {'class':platform === p ? 'cbi-tab' : 'cbi-tab-disabled'}, [
                        E('a', {'href':'#','click':function(ev) { ev.preventDefault(); platform = p; draw(); }}, [p === 'windows' ? 'Windows' : 'Android'])
                    ]);
                }));
                var guide = [tabs];
                if (host && platform === 'windows') {
                    guide.push(E('div', {'class':'nas-connect-actions'}, [
                        E('a', {'class':'cbi-button cbi-button-action',
                            'href':'khoanas://open?host=' + encodeURIComponent(host) + '&share=' + encodeURIComponent(share.name)}, [_('Open NAS folder')]),
                        E('a', {'class':'cbi-button',
                            'href':'https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/raw/refs/heads/main/releases/windows-open-nas/KhoaNAS-Open.exe'}, [_('Download Windows NAS opener')])
                    ]),
                    E('p', {}, [_('On Windows, install the NAS opener once and allow this router’s IP addresses. Your browser may ask before opening File Explorer.')]),
                    value(_('Path for File Explorer'), '\\\\' + host + '\\' + share.name, true), steps([
                        _('Open File Explorer, paste the path above into its address bar, then press Enter.'),
                        _('When asked, choose Use a different account and enter an SMB account listed below with its SMB password.'),
                        _('To keep it in This PC, choose Map network drive, select a free drive letter, and paste the same path into Folder.'),
                        _('Enable Reconnect at sign-in. Use Connect using different credentials if needed, then finish. If the drive shows disconnected after sign-in, connect Tailscale and open it again.')
                    ]));
                } else if (host) {
                    guide.push(E('div', {'class':'nas-connect-actions'}, [E('a', {'class':'cbi-button cbi-button-action',
                        'href':'smb://' + host + '/' + encodeURIComponent(share.name)}, [_('Open NAS folder')])]),
                    E('p', {}, [_('Requires an Android file manager that handles smb:// links. If no app opens, add the SMB connection manually using the details below.')]),
                    steps([
                        _('Open a file manager that supports SMB2 or SMB3. Choose Network, Add connection, then SMB or Windows share.'),
                        _('Enter the server, port, share and account below. Leave Domain empty unless your administrator specifies one.'),
                        _('Save the connection and open the shared folder. For offline use, copy the files you need to phone storage.')
                    ]), value(_('Server / Host'), host, true), value(_('Port'), '445', false),
                    value(_('Share name'), share.name, true),
                    E('p', {}, [_('Android permits one active VPN at a time. Another VPN may disconnect Tailscale.')]));
                }
                guide.push(value(_('SMB account'), account, false), E('p', {}, [
                    _('Use the SMB password for this account. It is separate from the router administrator password, the BitLocker password and the Tailscale account. This page never displays passwords.')]));
                nodes.push(section(_('2. Connect your device'), guide));
            }
            nodes.push(section(_('3. If the connection fails'), [steps([
                _('For remote access, check Internet access, Tailscale at both ends, and permission to reach this router. Do not use the LAN address while away from home.'),
                _('Check that the correct volume is mounted or unlocked in Disk Manager. A configured share name alone does not mean its disk is ready.'),
                _('If Windows keeps asking for credentials, check the SMB account. For error 1219, disconnect only the conflicting connection to this NAS, then reconnect.'),
                _('Do not expose or port-forward SMB port 445 to the public Internet. Use the authenticated Tailscale connection.')
            ]), E('p', {}, [E('a', {'href':L.url('admin','system','disks')}, [_('Disk Manager')]), ' · ',
                E('a', {'href':L.url('admin','services','ksmbd')}, [_('Configure network shares')]), ' · ',
                E('a', {'href':'https://github.com/TranDangKhoaAutomation/Nas-For-Xiaomi-AC1200-Openwrt/blob/main/docs/REMOTE-ACCESS.md','target':'_blank','rel':'noopener noreferrer'}, [_('Detailed remote access guide')])])
            ]));
            content.replaceChildren.apply(content, nodes);
        }
        draw();
        return E('div', {'class':'nas-connect-guide'}, [E('style', {}, [
            '.nas-connect-guide p{margin:12px 0;line-height:1.65}' +
            '.nas-connect-guide .cbi-section{margin-top:18px}' +
            '.nas-connect-guide .cbi-tabmenu{margin:0 0 16px}' +
            '.nas-connect-guide .nas-connect-actions{display:flex;flex-wrap:wrap;gap:12px;align-items:center;margin:16px 0}' +
            '.nas-connect-guide ol li{margin:6px 0}' +
            '.nas-connect-guide h3{scroll-margin-top:88px}'
        ]), E('h2', {}, [_('Connection guide')]),
            E('p', {}, [_('Open your NAS from Windows or Android, at home or remotely through Tailscale.')]),
            refresh, content]);
    }, handleSaveApply:null, handleSave:null, handleReset:null
});
