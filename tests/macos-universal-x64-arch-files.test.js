const test = require('node:test');
const assert = require('node:assert/strict');
const { minimatch } = require('minimatch');
const pkg = require('../package.json');

test('macOS universal x64ArchFiles explicitly includes hidden Python .dylibs', () => {
    const rule = pkg.build?.mac?.x64ArchFiles;
    assert.equal(typeof rule, 'string');
    const hiddenDylib = 'Contents/Resources/python/runtime/lib/python3.12/site-packages/PIL/.dylibs/libXau.6.dylib';
    const normalRuntimeFile = 'Contents/Resources/python/runtime/bin/python3';

    // minimatch (dot=false) does not include hidden directories via plain **.
    assert.equal(
        minimatch(hiddenDylib, '**/Contents/Resources/{bin,python/runtime}/**'),
        false,
    );

    assert.equal(minimatch(hiddenDylib, rule), true);
    assert.equal(minimatch(normalRuntimeFile, rule), true);
});
