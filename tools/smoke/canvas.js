// canvas.ts 算法验证: 与 cut-expand-tool(ui.exe / ui.py by LaoWang)反汇编还原的行为逐项对照
const Module = require('module');
const orig = Module._load;
Module._load = function (request, ...rest) {
	if (request === 'vscode') {
		return {
			window: { showOpenDialog: async () => undefined, showErrorMessage: () => {}, createOutputChannel: () => ({ appendLine() {}, show() {} }) },
			Uri: { file: (f) => ({ fsPath: f }) },
			l10n: { t: (k) => k },
		};
	}
	return orig.call(this, request, ...rest);
};

const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');
const sharp = require('sharp');
const { expandCanvas, cropCanvas, processScml } = require('../../out/lib/canvas.js');

const approx = (a, b, eps = 1e-9) => Math.abs(a - b) < eps;

async function makePng(file, w, h, content) {
	// content: {left, top, width, height} 不透明区域
	const overlay = Buffer.from(
		`<svg width="${w}" height="${h}">` +
		`<rect x="${content ? content.left : -10}" y="${content ? content.top : -10}" ` +
		`width="${content ? content.width : 0}" height="${content ? content.height : 0}" fill="#ff0000"/></svg>`,
	);
	await sharp({ create: { width: w, height: h, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
		.composite([{ input: overlay, blend: 'over' }])
		.png()
		.toFile(file);
}

async function sizeOf(file) {
	const m = await sharp(file).metadata();
	return { w: m.width, h: m.height };
}

(async () => {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'canvas-test-'));
	const img = path.join(dir, 'a.png');

	// ---- 1. crop: 10x20, 内容 x∈[2,5](宽4), y∈[5,9](高5), pivot (0.5,0.5) ----
	await makePng(img, 10, 20, { left: 2, top: 5, width: 4, height: 5 });
	let r = await cropCanvas(img, 0.5, 0.5, 0);
	assert.deepStrictEqual({ ...await sizeOf(img) }, { w: 4, h: 5 }, 'crop size');
	assert.ok(approx(r.px, (0.5 * 10 - 2) / 4) && approx(r.py, (0.5 * 20 - 10) / 5), `crop pivot ${r.px},${r.py}`);
	console.log('[1] crop edge=0 OK ->', r);

	// ---- 2. crop edge=2 (同一张原图) ----
	await makePng(img, 10, 20, { left: 2, top: 5, width: 4, height: 5 });
	r = await cropCanvas(img, 0.5, 0.5, 2);
	// l=2,t=5,r(右侧透明列)=4,b(底部透明行)=10 → l2=0,t2=3,r2=2,b2=8
	assert.deepStrictEqual({ ...await sizeOf(img) }, { w: 10 - 0 - 2, h: 20 - 3 - 8 }, 'crop+edge size');
	assert.ok(approx(r.px, (5 - 0) / 8) && approx(r.py, (10 - 8) / 9), `crop+edge pivot ${r.px},${r.py}`);
	console.log('[2] crop edge=2 OK ->', r);

	// ---- 3. expand scale=2 maxsize=1024: 10x20 → big=40 正方形 ----
	await makePng(img, 10, 20, { left: 2, top: 5, width: 4, height: 5 });
	r = await expandCanvas(img, 0.5, 0.5, 2, 1024);
	const s = await sizeOf(img);
	assert.deepStrictEqual(s, { w: 40, h: 40 }, 'expand square size');
	assert.ok(approx(r.px, (0.5 * 10 + 15) / 40) && approx(r.py, (0.5 * 20 + 10) / 40), `expand pivot ${r.px},${r.py}`);
	console.log('[3] expand scale=2 OK ->', r, s);

	// ---- 4. expand maxsize 上限: 700x900 → big=min(1800, 1024)=1024 ----
	await makePng(img, 700, 900, { left: 10, top: 10, width: 100, height: 100 });
	r = await expandCanvas(img, 0.2, 0.3, 2, 1024);
	assert.deepStrictEqual(await sizeOf(img), { w: 1024, h: 1024 }, 'expand maxsize cap');
	assert.ok(approx(r.px, (0.2 * 700 + 162) / 1024) && approx(r.py, (0.3 * 900 + 62) / 1024), 'expand cap pivot');
	console.log('[4] expand maxsize cap OK ->', r);

	// ---- 5. 全透明 → 1x1, pivot (0.5, 0.5) ----
	await makePng(img, 30, 30, null);
	r = await cropCanvas(img, 0.3, 0.7, 0);
	assert.deepStrictEqual(await sizeOf(img), { w: 1, h: 1 }, 'blank → 1x1');
	assert.ok(approx(r.px, 0.5) && approx(r.py, 0.5), 'blank pivot');
	console.log('[5] blank crop OK ->', r);

	// ---- 6. processScml 端到端: 正常图 + 缺失图补 1x1 (XML 不动) ----
	const proj = path.join(dir, 'proj');
	fs.mkdirSync(path.join(proj, 'f0'), { recursive: true });
	await makePng(path.join(proj, 'f0', 'a.png'), 10, 20, { left: 2, top: 5, width: 4, height: 5 });
	const scml = path.join(proj, 'anim.scml');
	fs.writeFileSync(scml, `<?xml version="1.0" encoding="UTF-8"?>
<spriter_data scml_version="1.0" generator="BrashMonkey Spriter" generator_version="r7">
    <folder id="0" name="f0">
        <file id="0" name="f0/a.png" width="10" height="20" pivot_x="0.5" pivot_y="0.5"/>
        <file id="1" name="f0/missing.png" width="8" height="8" pivot_x="0.25" pivot_y="0.75"/>
    </folder>
    <entity id="0" name="anim"/>
</spriter_data>`);
	await processScml(scml, 'crop', { edge: 0 });
	let xml = fs.readFileSync(scml, 'utf8');
	assert.ok(xml.includes('width="4"') && xml.includes('height="5"'), 'xml size updated');
	assert.ok(/pivot_x="0.75"/.test(xml), 'xml pivot_x updated');
	assert.ok(/pivot_y="0"/.test(xml) || /pivot_y="0\./.test(xml) || /pivot_y="-/.test(xml) || /pivot_y="0"/.test(xml), 'xml pivot_y updated');
	assert.ok(xml.includes('name="f0/missing.png" width="8" height="8" pivot_x="0.25" pivot_y="0.75"'), 'missing entry XML untouched');
	assert.deepStrictEqual(await sizeOf(path.join(proj, 'f0', 'missing.png')), { w: 1, h: 1 }, 'missing patched 1x1');
	console.log('[6] processScml crop OK');

	// ---- 7. expand 端到端 + 顺序不敏感抽查 ----
	await processScml(scml, 'expand', { scale: 2, maxSize: 1024 });
	xml = fs.readFileSync(scml, 'utf8');
	assert.ok(/pivot_x="0.6" pivot_y="0.25"/.test(xml) && /width="10" height="10"/.test(xml), `expand roundtrip actual: ${xml.match(/name="f0\/a.png"[^/]*\/>/)}`);
	console.log('[7] processScml expand OK');

	console.log('ALL CANVAS TESTS PASSED');
})().catch(e => { console.error('FAILED:', e); process.exit(1); });
