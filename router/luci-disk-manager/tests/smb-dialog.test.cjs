const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function harness(result, operation = 'password') {
    const elements = [], calls = [];
    let hidden = false, redirect;
    function E(tag, attrs = {}, children = []) {
        const node = { tag, attrs, children, value:attrs.value || '', disabled:false,
            addEventListener(type, callback) { this[type] = callback; } };
        elements.push(node);
        return node;
    }
    const rpc = { declare:spec => (user, password, shares) => {
        assert.equal(spec.method, operation);
        calls.push(shares ? {user, password, shares} : {user, password});
        assert.equal(field('New SMB password').value, '');
        assert.equal(field('Confirm password').value, '');
        return result();
    } };
    const ui = { showModal() {}, hideModal() { hidden = true; }, addNotification() {} };
    const field = name => elements.find(e => e.attrs['aria-label'] === name);
    const button = () => elements.find(e => e.tag === 'button' && e.children[0] === (operation === 'create' ? 'Add SMB account' : 'Change SMB password'));
    const source = fs.readFileSync(path.join(__dirname, '..', 'nas-smb-dialog.js'), 'utf8');
    const dialog = new Function('baseclass', 'rpc', 'ui', 'E', '_', 'L', 'TextEncoder', 'window', source)(
        {extend:x => x}, rpc, ui, E, x => x, {url:(...p) => '/cgi-bin/luci/' + p.join('/')}, TextEncoder,
        {location:{assign:path => { redirect = path; }}});
    if (operation === 'create') dialog.create([
        {id:'dangkhoa',name:'DANGKHOA',guest:false}, {id:'bitlocker',name:'BITLOCKER',guest:false},
        {id:'public',name:'PUBLIC',guest:true}
    ]);
    else dialog.show(['other', 'nas', 'nas'], 'nas', true);
    return {elements, calls, field, button, hidden:() => hidden, redirect:() => redirect};
}

test('invalid confirmation, byte length and line breaks never reach the RPC', () => {
    const h = harness(() => { throw new Error('must not submit'); });
    for (const [password, confirm] of [['test-only', 'different'], ['', ''], ['short', 'short'],
        ['a\nbcdefghi', 'a\nbcdefghi'], ['界'.repeat(43), '界'.repeat(43)]]) {
        h.field('New SMB password').value = password;
        h.field('Confirm password').value = confirm;
        h.button().click();
    }
    assert.equal(h.calls.length, 0);
});

test('selected account is preserved, secrets clear before RPC, and account link targets its own page', async () => {
    const h = harness(() => Promise.resolve({ok:true}));
    const password = 'disposable-test-only';
    h.field('New SMB password').value = password;
    h.field('Confirm password').value = password;
    h.button().click();
    assert.equal(h.field('SMB account').disabled, true);
    await new Promise(setImmediate);
    assert.deepEqual(h.calls, [{user:'nas', password}]);
    assert.equal(h.hidden(), true);
    assert.equal(h.field('SMB account').children.length, 2);
    const link = h.elements.find(e => e.tag === 'a');
    assert.equal(link.attrs.href, '/cgi-bin/luci/admin/services/nas/accounts');
    assert.equal(link.attrs.target, '_blank');
    assert.equal(link.attrs.rel, 'noopener noreferrer');
});

test('creation requires a valid name and explicit private folder selection', () => {
    const h = harness(() => { throw new Error('must not submit'); }, 'create');
    h.field('Account name').value = 'root;injection';
    h.button().click();
    h.field('Account name').value = 'family';
    h.button().click();
    assert.equal(h.calls.length, 0);
    assert.equal(h.field('PUBLIC'), undefined);
});

test('creation sends only the selected share, clears secrets and opens consolidated account tab', async () => {
    const h = harness(() => Promise.resolve({ok:true}), 'create');
    h.field('Account name').value = 'family';
    h.field('New SMB password').value = 'disposable-test-only';
    h.field('Confirm password').value = 'disposable-test-only';
    h.field('DANGKHOA').checked = true;
    h.button().click();
    await new Promise(setImmediate);
    assert.deepEqual(h.calls[0], {user:'family',password:'disposable-test-only',shares:['dangkhoa']});
    assert.equal(h.redirect(), '/cgi-bin/luci/admin/services/nas/accounts');
});

test('duplicate account failure preserves selections but requires re-entering the secret', async () => {
    const h = harness(() => Promise.resolve({error:'account_exists'}), 'create');
    h.field('Account name').value = 'nas';
    h.field('New SMB password').value = 'disposable-test-only';
    h.field('Confirm password').value = 'disposable-test-only';
    h.field('BITLOCKER').checked = true;
    h.button().click();
    await new Promise(setImmediate);
    assert.equal(h.field('BITLOCKER').checked, true);
    assert.equal(h.field('New SMB password').value, '');
    assert.equal(h.button().disabled, false);
    assert.match(h.elements.find(e => e.attrs.role === 'status').textContent, /already exists/);
});

test('RPC failure restores controls without restoring passwords', async () => {
    const h = harness(() => Promise.reject(new Error('transport failed')));
    h.field('New SMB password').value = 'disposable-test-only';
    h.field('Confirm password').value = 'disposable-test-only';
    h.button().click();
    await new Promise(setImmediate);
    assert.equal(h.hidden(), false);
    assert.equal(h.button().disabled, false);
    assert.equal(h.field('SMB account').disabled, false);
    assert.equal(h.field('New SMB password').value, '');
    assert.equal(h.field('Confirm password').value, '');
    assert.match(h.elements.find(e => e.attrs.role === 'status').textContent, /could not be changed/);
});
