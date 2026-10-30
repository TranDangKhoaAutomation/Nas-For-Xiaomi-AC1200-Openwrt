'use strict';
'require view';
'require rpc';
'require poll';
'require ui';

var status = rpc.declare({object:'nas.disks',method:'status',expect:{'':{}},reject:true});
var scan = rpc.declare({object:'nas.disks',method:'scan',expect:{'':{}},reject:true});
var configure = rpc.declare({object:'nas.disks',method:'configure',params:['uuid','name','path','readonly','enabled'],expect:{'':{}},reject:true});
var action = rpc.declare({object:'nas.disks',method:'action',params:['uuid','operation','password'],expect:{'':{}},reject:true,nobatch:true});

function bytes(n) {
    if (n == null || !isFinite(n)) return '—';
    var units=['B','KiB','MiB','GiB','TiB'], i=0;
    while(n>=1024 && i<units.length-1){n/=1024;i++;}
    return n.toFixed(i?1:0)+' '+units[i];
}
function errorText(code) {
    var map={
        volume_missing:_('The volume is no longer available. Scan the disks again.'),
        busy:_('Another disk operation is running. Please wait.'),
        invalid_path:_('Use a mount path under /mnt with letters, numbers, hyphens or underscores.'),
        mounted_path:_('Unmount the volume before changing its mount path.'),
        path_in_use:_('Another volume already uses this mount path.'),
        invalid_name:_('The display name is too long.'),
        save_failed:_('The settings could not be saved.'),
        state_unavailable:_('The router could not start the operation.'),
        invalid_password:_('The password is invalid or too long.'),
        password_required:_('Enter the password for this encrypted volume.'),
        module_missing:_('The BitLocker module is not available for the current kernel.'),
        driver_missing:_('The filesystem driver is not installed on this router.'),
        unlock_failed:_('Unlock failed. Check the password and the disk connection.'),
        mount_failed:_('Mount failed. Check the filesystem and disk connection; do not force a dirty volume.'),
        unmount_failed:_('The volume is still in use or could not be unmounted. Close open files and try again.'),
        not_configured:_('Save the volume settings first.')
    };
    return map[code]||_('The operation could not be completed.');
}
function check(reply){if(reply.error)throw new Error(errorText(reply.error));return reply;}

return view.extend({
    load:function(){return scan().then(status);},
    render:function(initial){
        var latest=initial, list=E('div'), note=E('div',{'role':'status','aria-live':'polite','style':'margin:12px 0'});
        var scanButton=E('button',{'type':'button','class':'cbi-button cbi-button-action'},[_('Scan disks')]);
        var scanTime=E('small',{'style':'margin-left:12px'});
        function refresh(){return status().then(function(data){latest=data;draw(data);});}
        scanButton.addEventListener('click',function(){scanButton.disabled=true;scan().then(check).then(refresh).catch(function(e){note.textContent=e.message;scanButton.disabled=false;});});
        function field(label,input,description){return E('div',{'class':'cbi-value'},[
            E('label',{'class':'cbi-value-title'},[label]),E('div',{'class':'cbi-value-field'},[input,description?E('div',{'class':'cbi-value-description'},[description]):''])]);}
        function manage(p,disk){
            var name=E('input',{'type':'text','value':p.settings.name,'maxlength':'64'});
            var path=E('input',{'type':'text','value':p.settings.path,'maxlength':'120','style':'width:100%'});
            var ro=E('input',{'type':'checkbox'});ro.checked=p.settings.readonly;
            var auto=E('input',{'type':'checkbox'});auto.checked=p.settings.enabled;
            var password=E('input',{'type':'password','autocomplete':'off','maxlength':'1024','style':'width:100%',
                'placeholder':p.key_saved?_('Leave empty to use the saved password'):_('Enter the volume password')});
            var msg=E('div',{'role':'status','style':'margin:12px 0'}), working=false;
            var save=E('button',{'class':'cbi-button cbi-button-apply','type':'button'},[_('Save settings')]);
            var mount=E('button',{'class':'cbi-button cbi-button-action important','type':'button'},[p.fstype==='BitLocker'?_('Save and unlock'):_('Save and mount')]);
            mount.disabled=!p.driver_ready;
            var cancel=E('button',{'class':'cbi-button','type':'button'},[_('Cancel')]);
            cancel.addEventListener('click',ui.hideModal);
            function submit(open){
                if(working)return;
                if(open&&!p.driver_ready){msg.textContent=errorText('driver_missing');return;}
                var secret=open?password.value:'';
                if(open && p.fstype==='BitLocker'&&!secret&&!p.key_saved){msg.textContent=errorText('password_required');password.focus();return;}
                password.value='';working=true;save.disabled=true;mount.disabled=true;cancel.disabled=true;
                configure(p.uuid,name.value,path.value,ro.checked,auto.checked).then(check).then(function(){
                    if(open)return action(p.uuid,'mount',secret).then(check);
                }).then(function(){secret=null;ui.hideModal();note.textContent=open?_('The operation has started. Its status will update automatically.'):_('Settings saved. Changes apply the next time the volume is mounted.');return refresh();
                }).catch(function(e){secret=null;msg.textContent=e.message;working=false;save.disabled=false;mount.disabled=!p.driver_ready;cancel.disabled=false;});
            }
            save.addEventListener('click',function(){submit(false);});
            mount.addEventListener('click',function(){submit(true);});
            var content=[
                E('p',{},[p.device+' • '+bytes(p.size)+' • '+p.fstype]),
                field(_('Display name'),name),field(_('Mount path'),path),
                field(_('Read-only'),ro,_('Read-write mounts fall back to read-only when the filesystem refuses writing.')),
                field(p.fstype==='BitLocker'?_('Unlock automatically after startup'):_('Mount automatically after startup'),auto,
                    p.fstype==='BitLocker'?_('The verified password is saved on the router only when automatic unlock is enabled.'):_('This setting follows the volume UUID, even if its device name changes.'))
            ];
            if(disk.io_warning)content.push(E('p',{'class':'alert-message warning'},[_('The boot log contains I/O errors for this disk name. Check the connection and use read-only access first.')]));
            if(!p.driver_ready)content.push(E('p',{'class':'alert-message warning'},[_('The filesystem driver is not installed on this router.')]));
            if(p.fstype==='BitLocker')content.push(field(_('Saved password'),E('span',{},[p.key_saved?_('Saved (administrator-only)'):_('Not saved')]),_('Turning off automatic unlock does not delete a previously saved password.')));
            if(p.fstype==='BitLocker'&&!p.mount)content.push(field(_('Volume password'),password,_('The password is used only when you choose Save and unlock. A router administrator can read saved passwords.')));
            if(p.mount)content.push(E('p',{},[_('Unmount the volume to change the mount path or apply a new access mode.')]));
            content.push(msg,E('div',{'class':'right','style':'display:flex;gap:10px;justify-content:flex-end'},p.mount?[cancel,save]:[cancel,save,mount]));
            ui.showModal(_('Manage volume'),content);
        }
        function unmount(p){
            action(p.uuid,'unmount','').then(check).then(function(){note.textContent=_('Unmounting safely. Automatic mounting is paused until you mount it again or restart the router.');return refresh();}).catch(function(e){note.textContent=e.message;});
        }
        function draw(data){
            scanButton.disabled=!!data.scanning;
            scanButton.textContent=data.scanning?_('Scanning…'):_('Scan disks');
            scanTime.textContent=data.scanned_at?_('Last scan')+': '+new Date(data.scanned_at*1000).toLocaleTimeString():'';
            list.replaceChildren();
            if(!data.disks||!data.disks.length){list.appendChild(E('div',{'class':'cbi-section'},[data.scanning?_('Detecting attached disks…'):_('No attached data disks were found. Connect a disk and scan again.')]));return;}
            data.disks.forEach(function(disk){
                var header=E('div',{'style':'display:flex;justify-content:space-between;gap:16px;flex-wrap:wrap;margin-bottom:14px'},[
                    E('div',{},[E('h3',{'style':'margin:0'},[disk.model.trim()||_('Disk')]),E('small',{},[disk.device+' • '+(disk.transport==='USB'?'USB':_('Local drive'))+(disk.serial?' • '+_('Serial')+': '+disk.serial:'')])]),
                    E('div',{},[E('strong',{'style':'font-size:20px'},[disk.size>=1e12?(disk.size/1e12).toFixed(2)+' TB':bytes(disk.size)]),E('div',{},[disk.size>=1e12?bytes(disk.size)+' • ':'',disk.online?_('Connected'):_('Disconnected')])])
                ]);
                var table=E('table',{'class':'table'},[E('tr',{'class':'tr table-titles'},[_('Volume'),_('Capacity'),_('Filesystem'),_('Status'),_('Automatic mounting'),_('Actions')].map(function(v){return E('th',{'class':'th'},[v]);}))]);
                disk.partitions.forEach(function(p){
                    var state=p.mount?(p.mount.mode==='ro'?_('Mounted read-only'):_('Mounted read-write')):(p.fstype==='BitLocker'?_('Locked'):_('Not mounted'));
                    if(p.job.phase==='working'&&data.busy)state=_('Processing…');
                    var controls=[];
                    var supported=['ntfs','BitLocker','vfat','exfat','ext2','ext3','ext4','f2fs','btrfs','xfs'].indexOf(p.fstype)>=0;
                    if(p.uuid&&supported){
                        controls.push(E('button',{'type':'button','class':'cbi-button cbi-button-edit','disabled':data.busy?true:null,'click':function(){manage(p,disk);}},[_('Manage')]));
                        if(p.mount&&p.settings.configured)controls.push(E('button',{'type':'button','class':'cbi-button','disabled':data.busy?true:null,'click':function(){unmount(p);}},[_('Unmount')]));
                    }else controls.push(E('small',{},[p.uuid?_('Unsupported filesystem'):_('No filesystem UUID')]));
                    var auto=p.settings.enabled?(p.paused?_('Paused'):(p.fstype==='BitLocker'&&!p.key_saved?_('Password required'):_('Enabled'))):(p.hint_auto&&!p.settings.configured?_('System mount settings'):_('Disabled'));
                    var stateNode=E('div',{},[E('strong',{},[state]),p.mount?E('div',{},[p.mount.path]):'',p.share?E('div',{},[E('small',{},['SMB: '+p.share])]):'']);
                    if(p.job.phase==='error')stateNode.appendChild(E('div',{'style':'color:#b42318;max-width:300px'},[errorText(p.job.result)]));
                    var sizeNode=E('div',{},[bytes(p.size)]);
                    if(p.mount&&p.usage)sizeNode.appendChild(E('small',{'style':'display:block;margin-top:3px'},[bytes(p.usage.available)+' '+_('available')]));
                    table.appendChild(E('tr',{'class':'tr'},[
                        E('td',{'class':'td'},[E('strong',{},[p.settings.name]),E('div',{},[p.device]),p.uuid?E('small',{'style':'display:block;max-width:240px;overflow-wrap:anywhere'},['UUID: '+p.uuid]):'']),
                        E('td',{'class':'td'},[sizeNode]),E('td',{'class':'td'},[p.fstype||_('Unknown')]),
                        E('td',{'class':'td'},[stateNode]),E('td',{'class':'td'},[auto]),
                        E('td',{'class':'td','style':'display:flex;gap:8px;flex-wrap:wrap'},controls)
                    ]));
                });
                var nodes=[header];
                if(disk.io_warning)nodes.push(E('div',{'class':'alert-message warning'},[_('I/O errors were recorded during this boot. Check the disk, USB cable and power supply before enabling writes.')]));
                nodes.push(table);
                list.appendChild(E('section',{'class':'cbi-section'},nodes));
            });
        }
        draw(initial);
        poll.add(refresh,3);
        return E('div',{},[
            E('h2',{},[_('Disk Manager')]),
            E('p',{},[_('Detect attached disks, manage each volume and configure mounting or encrypted unlock by UUID.')]),
            E('p',{},[E('a',{'href':L.url('admin','services','nas','connect')},[_('Connection guide')])]),
            E('div',{'style':'display:flex;align-items:center;flex-wrap:wrap'},[scanButton,scanTime]),note,list,
            E('p',{'class':'cbi-section-descr'},[_('New disks appear after a scan. Existing settings are only applied to matching UUIDs; a replacement disk is never unlocked using a device name alone.')]),
            E('a',{'href':L.url('admin','services','nas','shares')},[_('Configure network shares')])
        ]);
    },handleSaveApply:null,handleSave:null,handleReset:null
});
