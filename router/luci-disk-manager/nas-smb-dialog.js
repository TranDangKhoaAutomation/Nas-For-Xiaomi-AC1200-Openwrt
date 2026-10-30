'use strict';
'require baseclass';
'require rpc';
'require ui';

var setPassword = rpc.declare({object:'nas.smb',method:'password',params:['user','password'],expect:{'':{}},reject:true,nobatch:true});
var createAccount = rpc.declare({object:'nas.smb',method:'create',params:['user','password','shares'],expect:{'':{}},reject:true,nobatch:true});

return baseclass.extend({
    show:function(users, selected, showAccountsLink) {
        users = Array.from(new Set(users)).filter(Boolean);
        var user = E('select', {'aria-label':_('SMB account')}, users.map(function(name) {
            return E('option', {'value':name}, [name]);
        }));
        user.value = users.indexOf(selected) >= 0 ? selected : users[0] || '';
        var secret = E('input', {'type':'password','autocomplete':'new-password','maxlength':'128','style':'width:100%','aria-label':_('New SMB password')});
        var confirm = E('input', {'type':'password','autocomplete':'new-password','maxlength':'128','style':'width:100%','aria-label':_('Confirm password')});
        var message = E('p', {'role':'status','aria-live':'polite','style':'margin:14px 0'});
        var cancel = E('button', {'class':'cbi-button','type':'button','click':ui.hideModal}, [_('Cancel')]);
        var save = E('button', {'class':'cbi-button cbi-button-apply','type':'button'}, [_('Change SMB password')]);
        save.disabled = !users.length;
        save.addEventListener('click', function() {
            var pw = secret.value;
            if (pw !== confirm.value) { message.textContent = _('Passwords do not match.'); return; }
            var size = new TextEncoder().encode(pw).length;
            if (size < 8 || size > 128 || /[\x00\r\n]/.test(pw)) { message.textContent = _('Use 8 to 128 UTF-8 bytes without line breaks.'); return; }
            secret.value = ''; confirm.value = ''; save.disabled = cancel.disabled = user.disabled = true;
            setPassword(user.value,pw).then(function(reply) {
                pw = null;
                if (!reply.ok) throw new Error('update_failed');
                ui.hideModal();
                ui.addNotification(null,E('p',{},[_('SMB password changed. Reconnect your devices using the new password.')]),'info');
            }).catch(function() {
                pw = null; save.disabled = cancel.disabled = user.disabled = false;
                message.textContent = _('The SMB password could not be changed. Check that this account already exists.');
            });
        });
        function row(label,input) {
            return E('div', {'style':'margin:16px 0'}, [E('label', {'style':'display:block;margin-bottom:8px'}, [label]), input]);
        }
        var accountNodes = [user];
        if (showAccountsLink) accountNodes.push(E('a', {
            'href':L.url('admin','services','nas','accounts'),'target':'_blank','rel':'noopener noreferrer'
        }, [_('Configure SMB accounts')]));
        ui.showModal(_('Change SMB password'), [
            row(_('SMB account'), E('div', {'style':'display:flex;flex-wrap:wrap;gap:12px;align-items:center'}, accountNodes)),
            row(_('New SMB password'),secret), row(_('Confirm password'),confirm),
            E('p', {}, [_('NAS sharing will reconnect. Devices using this account need the new password.')]), message,
            E('div', {'style':'display:flex;gap:12px;justify-content:flex-end;margin-top:18px'}, [cancel,save])
        ]);
    },
    create:function(shares) {
        var user = E('input', {'type':'text','autocomplete':'off','maxlength':'31','placeholder':'gia_dinh','aria-label':_('Account name'),'style':'width:100%;margin:0;box-sizing:border-box'});
        var secret = E('input', {'type':'password','autocomplete':'new-password','maxlength':'128','aria-label':_('New SMB password'),'style':'width:100%;margin:0;box-sizing:border-box'});
        var confirm = E('input', {'type':'password','autocomplete':'new-password','maxlength':'128','aria-label':_('Confirm password'),'style':'width:100%;margin:0;box-sizing:border-box'});
        var choices = shares.filter(function(s) { return s.id && !s.guest; }).map(function(s) {
            var input = E('input', {'type':'checkbox','value':s.id,'aria-label':s.name});
            return {input:input, node:E('label', {'style':'display:flex;align-items:center;gap:8px;margin:8px 0'}, [input, s.name])};
        });
        var message = E('p', {'role':'status','aria-live':'polite'});
        var cancel = E('button', {'type':'button','class':'cbi-button','click':ui.hideModal}, [_('Cancel')]);
        var save = E('button', {'type':'button','class':'cbi-button cbi-button-apply'}, [_('Add SMB account')]);
        var controls = [user,secret,confirm,cancel,save].concat(choices.map(function(c) { return c.input; }));
        var errors = {
            account_exists:_('This account name already exists. Choose another name.'),
            storage_owner_unavailable:_('Mount the selected disks first. Their data must use the same non-root owner.'),
            share_not_private:_('Choose private NAS folders without guest access or Force Root.'),
            configuration_pending:_('Save or discard pending network share changes first.'),
            busy:_('Another account operation is running. Try again.'),
            cleanup_required:_('Account creation needs cleanup on the router before trying again.'),
            useradd_missing:_('Install shadow-useradd on the router first.')
        };
        save.disabled = !choices.length;
        save.addEventListener('click', function() {
            var name = user.value.trim(), pw = secret.value;
            var selected = choices.filter(function(c) { return c.input.checked; }).map(function(c) { return c.input.value; });
            if (!/^[a-z][a-z0-9_-]{0,30}$/.test(name)) { message.textContent = _('Use 1–31 lowercase letters, numbers, underscores or hyphens; start with a letter.'); return; }
            if (!selected.length) { message.textContent = _('Choose at least one shared folder.'); return; }
            if (pw !== confirm.value) { message.textContent = _('Passwords do not match.'); return; }
            var size = new TextEncoder().encode(pw).length;
            if (size < 8 || size > 128 || /[\x00\r\n]/.test(pw)) { message.textContent = _('Use 8 to 128 UTF-8 bytes without line breaks.'); return; }
            secret.value = ''; confirm.value = '';
            controls.forEach(function(c) { c.disabled = true; });
            createAccount(name,pw,selected).then(function(reply) {
                pw = null;
                if (!reply.ok) throw new Error(reply.error || 'account_creation_failed');
                ui.hideModal();
                window.location.assign(L.url('admin','services','nas','accounts'));
            }).catch(function(error) {
                pw = null;
                controls.forEach(function(c) { c.disabled = false; });
                message.textContent = errors[error.message] || _('The account could not be created. Check the router and try again.');
            });
        });
        function row(label, input) { return E('div', {'style':'margin:12px 0'}, [E('label', {'style':'display:block;margin-bottom:6px'}, [label]), input]); }
        ui.showModal(_('Add SMB account'), [
            row(_('Account name'),user), row(_('New SMB password'),secret), row(_('Confirm password'),confirm),
            row(_('Allowed shared folders'), E('div', {}, choices.length ? choices.map(function(c) { return c.node; }) : [_('No private shared folders are available. Configure sharing first.') ])),
            E('p', {}, [_('For NAS file access only. This account cannot sign in to router administration. Folder read/write settings still apply.')]),
            message, E('div', {'style':'display:flex;gap:12px;justify-content:flex-end;margin-top:18px'}, [cancel,save])
        ]);
    }
});
