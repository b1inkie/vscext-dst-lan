import * as assert from 'assert';
import { regexRep, replacePlaceholders } from '../lib/placeholder';
import { stripLuaComments } from '../lib/lua';

suite('placeholder protocol', () => {
	test('regexRep replaces all %(name)s', () => {
		const text = "local id = '%(modid)s'\nGLOBAL.%(modid_upper)s_API = env";
		const out = replacePlaceholders(text, { modid: 'mymod', modid_upper: 'MYMOD' });
		assert.strictEqual(out, "local id = 'mymod'\nGLOBAL.MYMOD_API = env");
	});

	test('regexRep keeps unrelated placeholders', () => {
		assert.strictEqual(regexRep('%(a)s %(b)s', 'a', 'X'), 'X %(b)s');
	});

	test('replacement containing $ does not corrupt patterns', () => {
		// $& / $1 之类的替换模式不应被展开
		assert.strictEqual(regexRep('%(x)s', 'x', '$&$1'), '$&$1');
	});
});

suite('stripLuaComments', () => {
	test('removes line comments and blank lines', () => {
		const src = 'local a = 1 -- comment\n\n-- only comment\nlocal b = 2\n';
		assert.strictEqual(stripLuaComments(src), 'local a = 1\nlocal b = 2\n');
	});

	test('removes block comments', () => {
		const src = '--[[\nblock\n]]\nlocal a = 1\n';
		assert.strictEqual(stripLuaComments(src), 'local a = 1\n');
	});

	test('removes leveled block comments', () => {
		const src = '--[==[ contains ]] inside ]==]\nlocal a = 1\n';
		assert.strictEqual(stripLuaComments(src), 'local a = 1\n');
	});

	test('keeps -- inside strings (fix over 1.x)', () => {
		const src = 'local s = "a--b" -- real comment\n';
		assert.strictEqual(stripLuaComments(src), 'local s = "a--b"\n');
	});

	test('keeps long strings verbatim', () => {
		const src = 'local s = [[\n-- not a comment\n]]\n';
		assert.strictEqual(stripLuaComments(src), 'local s = [[\n-- not a comment\n]]\n');
	});

	test('keeps trailing content after comment removal and trims trailing spaces', () => {
		const src = 'local a = 1 -- c';
		assert.strictEqual(stripLuaComments(src), 'local a = 1');
	});

	test('preserves CRLF line endings', () => {
		const src = 'local a = 1 -- c\r\nlocal b = 2\r\n';
		assert.strictEqual(stripLuaComments(src), 'local a = 1\r\nlocal b = 2\r\n');
	});
});
