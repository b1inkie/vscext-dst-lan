// 一键回归: 顺序跑全部冒烟脚本, 全绿 exit 0
const { spawnSync } = require('child_process');
const path = require('path');

const scripts = [
	'e2e.js',
	'compiler.js',
	'anim2.js',
	'atlas.js',
	'pack.js',
	'canvas.js',
	'lua.js',
];

let failed = 0;
for (const s of scripts) {
	console.log(`\n===== ${s} =====`);
	const r = spawnSync(process.execPath, [path.join(__dirname, s)], { stdio: 'inherit' });
	if (r.status !== 0) {
		failed++;
		console.error(`[FAIL] ${s}`);
	}
}
console.log(`\n${failed === 0 ? 'ALL SMOKE PASSED' : failed + ' SCRIPT(S) FAILED'} (${scripts.length - failed}/${scripts.length})`);
process.exit(failed === 0 ? 0 : 1);
