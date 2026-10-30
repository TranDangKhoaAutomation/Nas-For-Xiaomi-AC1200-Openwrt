'use strict';
'require view';
'require rpc';
'require ui';
'require nas-smb-dialog as smbDialog';

var getInfo = rpc.declare({object:'nas.disks',method:'connection_info',expect:{'':{}},reject:true});

return view.extend({
    load:function() { ui.menu.flushCache(); return getInfo(); },
    render:function(info) {
        var accounts = Object.create(null);
        (info.shares || []).forEach(function(share) {
            var users = Array.isArray(share.users) ? share.users : (share.users || '').split(/[ ,\t]+/);
            users.filter(Boolean).forEach(function(user) {
                if (!accounts[user]) accounts[user] = [];
                if (accounts[user].indexOf(share.name) < 0) accounts[user].push(share.name);
            });
        });
        var users = Object.keys(accounts).sort();
        var rows = users.map(function(user) {
            return E('tr', {'class':'tr'}, [
                E('td', {'class':'td','data-title':_('SMB account')}, [E('strong', {}, [user])]),
                E('td', {'class':'td','data-title':_('Allowed shared folders')}, [accounts[user].join(', ')]),
                E('td', {'class':'td','data-title':_('Actions')}, [
                    E('button', {'type':'button','class':'cbi-button cbi-button-action','click':function() {
                        smbDialog.show(users,user,false);
                    }}, [_('Change SMB password')])
                ])
            ]);
        });
        if (!users.length) rows.push(E('tr', {'class':'tr'}, [
            E('td', {'class':'td','colspan':3}, [_('No SMB accounts are assigned to shared folders.')])
        ]));
        return E('div', {}, [
            E('h2', {}, [_('SMB accounts')]),
            E('p', {}, [_('SMB accounts used by the shared folders on this router. Select an account to change its password.')]),
            E('section', {'class':'cbi-section'}, [
                E('table', {'class':'table'}, [E('tr', {'class':'tr table-titles'}, [
                    E('th', {'class':'th'}, [_('SMB account')]),
                    E('th', {'class':'th'}, [_('Allowed shared folders')]),
                    E('th', {'class':'th'}, [_('Actions')])
                ])].concat(rows)),
                E('p', {'style':'margin-top:16px'}, [
                    E('a', {'href':L.url('admin','services','ksmbd')}, [_('Configure folder access')]), ' · ',
                    E('a', {'href':L.url('admin','services','nas-connect')}, [_('Connection guide')])
                ])
            ])
        ]);
    },
    handleSaveApply:null, handleSave:null, handleReset:null
});
