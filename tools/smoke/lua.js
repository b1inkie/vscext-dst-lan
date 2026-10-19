// stripLuaComments 回归: 边界用例 + 真实文件语法校验(luaparse 缺失时降级为边界用例)
const { stripLuaComments } = require('../../out/lib/lua.js');

const NL = '\n';
const cases = [
	['local a = 1 -- comment', 'local a = 1'],
	['local s = "a--b"' + NL + 'local t = 1', 'local s = "a--b"' + NL + 'local t = 1'],
	["local s = 'c--[[d]]e'", "local s = 'c--[[d]]e'"],
	['s = [[ -- not comment' + NL + 'still ]]', 's = [[ -- not comment' + NL + 'still ]]'],
	['s = [==[ ]] ]=] keep ]==]', 's = [==[ ]] ]=] keep ]==]'],
	['code1' + NL + '--[[ c1' + NL + 'c2 ]] code2', 'code1' + NL + ' code2'],
	['a = 1 --[==[ has ]] inside ]==] b = 2', 'a = 1  b = 2'],
	['--- doc' + NL + 'local a = 1', 'local a = 1'],
	['---[[ looks' + NL + 'local a = 1', 'local a = 1'],
	['--[ not block' + NL + 'local a = 1', 'local a = 1'],
	['a = 1' + NL + NL + NL + NL + 'b = 2', 'a = 1' + NL + 'b = 2'],
	// 缩进空行删除; 带 tab 缩进的代码行保留缩进
	['a = 1' + NL + '   ' + NL + '\tb = 2', 'a = 1' + NL + '\tb = 2'],
	['s = "x -- \\" y" -- real', 's = "x -- \\" y"'],
	['a = b - c' + NL + 'd = e - -f', 'a = b - c' + NL + 'd = e - -f'],
	['a = 1 -- tail', 'a = 1'],
	['a = 1 -- c\r\nb = 2\r\n', 'a = 1\r\nb = 2\r\n'],
	['a = 1 --[[ forever', 'a = 1'],
];
let failed = 0;
for (const [src, expect] of cases) {
	const out = stripLuaComments(src);
	if (out !== expect) {
		failed++;
		console.error('CASE FAIL', JSON.stringify(src), '->', JSON.stringify(out), 'expect', JSON.stringify(expect));
	}
}
console.log('edge cases:', cases.length - failed + '/' + cases.length, 'passed');
if (failed > 0) {
	process.exit(1);
}

let luaparse = null;
try { luaparse = require('luaparse'); } catch {}
if (!luaparse) {
	console.log('smoke-lua: OK (edge cases only; install luaparse for corpus check)');
	process.exit(0);
}

// 真实文件语法校验 + 注释残留检查
const fs = require('fs');
const path = require('path');
const roots = ['D:/DST_content/modbackup', 'D:/DST_content/others_mods', 'D:/DST_content/UPLOAD_STEAM'];
const files = [];
function walk(d, depth) {
	if (depth > 5 || files.length > 500) {
		return;
	}
	try {
		for (const e of fs.readdirSync(d, { withFileTypes: true })) {
			const p = path.join(d, e.name);
			if (e.isDirectory()) {
				walk(p, depth + 1);
			} else if (e.name.endsWith('.lua')) {
				files.push(p);
			}
		}
	} catch {}
}
for (const r of roots) {
	walk(r, 0);
}
let total = 0;
let broken = 0;
let residue = 0;
for (const f of files) {
	let src;
	try { src = fs.readFileSync(f, 'utf8'); } catch { continue; }
	const out = stripLuaComments(src);
	total++;
	if (out.trim() !== '') {
		try {
			luaparse.parse(out, { luaVersion: '5.1' });
		} catch {
			broken++;
			console.error('BROKEN:', f);
		}
	}
	for (const line of out.split(/\r?\n/)) {
		if (/^\s*--/.test(line)) {
			residue++;
			console.error('RESIDUE:', f, line.trim().slice(0, 60));
			break;
		}
	}
}
console.log('corpus:', total, 'files, broken:', broken, ', residual comments:', residue);
if (broken > 0 || residue > 0) {
	process.exit(1);
}
console.log('smoke-lua: OK');
