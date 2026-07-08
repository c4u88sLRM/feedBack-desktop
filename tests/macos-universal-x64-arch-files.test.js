const test = require('node:test');
const assert = require('node:assert/strict');
const pkg = require('../package.json');

test('macOS universal x64ArchFiles explicitly includes hidden Python .dylibs', () => {
    const rule = pkg.build?.mac?.x64ArchFiles;
    assert.equal(typeof rule, 'string');
    assert.match(rule, /python\/runtime/);
    assert.match(rule, /\.dylibs/);
});
