// 参考工具验证
// 断言 anim.bin / build.bin / atlas-N.tex 的结构与逆向结论一致。
// 运行: npm run compile && node .smoke-anim2.js
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const zlib = require('zlib');

const { packScml } = require('../../out/lib/anim2/pack');
const { kleiHash } = require('../../out/lib/anim2/bins');

// ---------- 最小 PNG 编码器（RGBA8, filter 0） ----------
function crc32(buf) {
	let c = -1;
	for (let i = 0; i < buf.length; i++) {
		c ^= buf[i];
		for (let k = 0; k < 8; k++) {
			c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
		}
	}
	return (c ^ -1) >>> 0;
}

function chunk(type, data) {
	const t = Buffer.from(type, 'ascii');
	const body = Buffer.concat([t, data]);
	const out = Buffer.alloc(8 + data.length + 4);
	out.writeUInt32BE(data.length, 0);
	body.copy(out, 4);
	out.writeUInt32BE(crc32(body), 8 + data.length);
	return out;
}

function writePng(file, w, h, paint) {
	const raw = Buffer.alloc((w * 4 + 1) * h);
	for (let y = 0; y < h; y++) {
		const rowStart = y * (w * 4 + 1);
		raw[rowStart] = 0;
		for (let x = 0; x < w; x++) {
			const [r, g, b, a] = paint(x, y);
			const p = rowStart + 1 + x * 4;
			raw[p] = r;
			raw[p + 1] = g;
			raw[p + 2] = b;
			raw[p + 3] = a;
		}
	}
	const ihdr = Buffer.alloc(13);
	ihdr.writeUInt32BE(w, 0);
	ihdr.writeUInt32BE(h, 4);
	ihdr[8] = 8;   // bit depth
	ihdr[9] = 6;   // RGBA
	const png = Buffer.concat([
		Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
		chunk('IHDR', ihdr),
		chunk('IDAT', zlib.deflateSync(raw)),
		chunk('IEND', Buffer.alloc(0)),
	]);
	fs.writeFileSync(file, png);
}

// ---------- 夹具 ----------
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'anim2-smoke-'));
fs.mkdirSync(path.join(root, 'a'));
fs.mkdirSync(path.join(root, 'b'));
// a.png: 左半不透明, 右半 a=128
// 64x64: 区域网格是 2x2 的 32px 块 -> 左半全不透明 / 右半半透明 = 2 个四边形
writePng(path.join(root, 'a', 'a.png'), 64, 64, (x, y) => (x < 32 ? [255, 0, 0, 255] : [0, 0, 255, 128]));
// b.png: 实际 128x128，但 scml 里故意声明成 64x64（真实工程里大量存在），
//        内容只占左上角 40x30 -> 应被自动裁剪
writePng(path.join(root, 'b', 'b.png'), 128, 128, (x, y) => (x < 40 && y < 30 ? [0, 255, 0, 255] : [0, 0, 0, 0]));

const scml = `<?xml version="1.0" encoding="UTF-8"?>
<spriter_data scml_version="1.0" generator="BrashMonkey Spriter" generator_version="r7">
  <folder id="0" name="a"><file id="0" name="a/a.png" width="64" height="64" pivot_x="0.5" pivot_y="0.5"/></folder>
  <folder id="1" name="b"><file id="0" name="b/b.png" width="64" height="64" pivot_x="0.25" pivot_y="0.75"/></folder>
  <entity id="0" name="bank1">
    <animation id="0" name="idle" length="1000" interval="100">
      <mainline>
        <key id="0" time="0">
          <object_ref id="0" timeline="0" key="0" z_index="0"/>
          <object_ref id="1" timeline="1" key="0" z_index="1"/>
        </key>
      </mainline>
      <timeline id="0" name="layer1"><key id="0" time="0" spin="0"><object folder="0" file="0" x="0" y="0" pivot_x="0.5" pivot_y="0.5"/></key></timeline>
      <timeline id="1" name="layer2"><key id="0" time="0" spin="0" instant="true"><object folder="1" file="0" x="10" y="20" angle="90" scale_x="2" scale_y="3" pivot_x="0.25" pivot_y="0.75"/></key></timeline>
    </animation>
    <animation id="1" name="walk_up" length="400" interval="100">
      <mainline><key id="0" time="0"><object_ref id="0" timeline="0" key="0" z_index="0"/></key></mainline>
      <timeline id="0" name="layer1"><key id="0" time="0" spin="0"><object folder="0" file="0" x="0" y="0" pivot_x="0.5" pivot_y="0.5"/></key></timeline>
    </animation>
  </entity>
</spriter_data>
`;
const scmlPath = path.join(root, 'testbuild.scml');
fs.writeFileSync(scmlPath, scml);

// ---------- 断言 ----------
function u32(b, o) { return b.readUInt32LE(o); }
function f32(b, o) { return b.readFloatLE(o); }

(async () => {
	const result = await packScml(scmlPath);
	const names = [...result.files.keys()].sort();
	assert.deepStrictEqual(names, ['anim.bin', 'atlas-0.tex', 'build.bin'], 'zip 内容: ' + names);
	assert.strictEqual(result.buildName, 'testbuild');

	// ---- build.bin ----
	const b = result.files.get('build.bin');
	assert.strictEqual(b.subarray(0, 4).toString('ascii'), 'BILD');
	assert.strictEqual(u32(b, 4), 6, 'BILD 版本');
	const numSymbols = u32(b, 8);
	const numFrames = u32(b, 12);
	assert.strictEqual(numSymbols, 2, 'symbol 数');
	assert.strictEqual(numFrames, 2, '帧数');
	let p = 16;
	const nameLen = u32(b, p);
	const buildName = b.subarray(p + 4, p + 4 + nameLen).toString('utf8');
	p += 4 + nameLen;
	assert.strictEqual(buildName, 'testbuild');
	const numPages = u32(b, p);
	p += 4;
	const pages = [];
	for (let i = 0; i < numPages; i++) {
		const n = u32(b, p);
		pages.push(b.subarray(p + 4, p + 4 + n).toString('utf8'));
		p += 4 + n;
	}
	assert.ok(pages[0].startsWith('atlas-'), '页名 ' + pages[0]);
	const hashes = [];
	const frameInfo = [];
	for (let s = 0; s < numSymbols; s++) {
		hashes.push(u32(b, p));
		p += 4;
		const nf = u32(b, p);
		p += 4;
		for (let f = 0; f < nf; f++) {
			frameInfo.push({
				num: u32(b, p),
				dur: u32(b, p + 4),
				x: f32(b, p + 8), y: f32(b, p + 12),
				w: f32(b, p + 16), h: f32(b, p + 20),
				off: u32(b, p + 24), nv: u32(b, p + 28),
			});
			p += 32;
		}
	}
	assert.deepStrictEqual(hashes, [kleiHash('a'), kleiHash('b')].sort((x, y) => x - y), 'symbol 按 hash 升序');
	const fA = frameInfo[0];
	assert.strictEqual(fA.w, 64);
	assert.strictEqual(fA.x, 0, 'pivot 0.5 -> x=0');
	assert.strictEqual(fA.nv, 12, 'a.png 两个四边形(不透明+半透明) = 12 顶点');
	assert.strictEqual(fA.x, 0);
	const fB = frameInfo[1];
	// 尺寸以**实际 PNG** 为准（scml 声明 64x64，实际 128x128）
	assert.strictEqual(fB.w, 128);
	assert.strictEqual(fB.h, 128);
	// frame x = w/2 - pivotX*w = 64 - 32 = 32 ; frame y = pivotY*h - h/2 = 96 - 64 = 32
	assert.strictEqual(fB.x, 32);
	assert.strictEqual(fB.y, 32);
	// 内容只占左上 40x30：裁剪后图集单元格按 4 对齐 -> 40x32，顶点只有 1 个四边形
	assert.strictEqual(fB.nv, 6, 'b.png 内容单块 -> 1 个四边形');
	const bVertX = f32(b, p + 6 * 24 * 0 + 0);  // 第一个顶点（a.png 之后）需要按偏移取，见下
	// 顶点：每组 6 个三角形顶点，第 3 位为 0，第 6 位为页号
	const nv = u32(b, p);
	p += 4;
	assert.ok(nv >= fA.nv + fB.nv);
	for (let i = 0; i < nv; i++) {
		assert.strictEqual(f32(b, p + i * 24 + 8), 0, 'vert[2] 恒 0');
		const page = f32(b, p + i * 24 + 20);
		assert.ok(page === 0, '单页时 page=0');
	}

	// ---- anim.bin ----
	const a = result.files.get('anim.bin');
	assert.strictEqual(a.subarray(0, 4).toString('ascii'), 'ANIM');
	assert.strictEqual(u32(a, 4), 4, 'ANIM 版本');
	const totalElements = u32(a, 8);
	const totalFrames = u32(a, 12);
	assert.strictEqual(u32(a, 16), 0);
	const nAnims = u32(a, 20);
	assert.strictEqual(nAnims, 2);
	// idle: ceil(1000/33)+1 = 32 帧 ; walk_up: ceil(400/33)+1 = 14 帧
	assert.strictEqual(totalFrames, 32 + 14, '总帧数 ' + totalFrames);
	assert.strictEqual(totalElements, 32 * 2 + 14, '总元素数 ' + totalElements);

	let q = 24;
	const anims = [];
	for (let i = 0; i < nAnims; i++) {
		const n = u32(a, q);
		const nm = a.subarray(q + 4, q + 4 + n).toString('utf8');
		q += 4 + n;
		const facing = a[q];
		q += 1;
		const bank = u32(a, q);
		q += 4;
		const fps = f32(a, q);
		q += 4;
		const frames = u32(a, q);
		q += 4;
		anims.push({ nm, facing, bank, fps, frames });
		// 跳过帧数据
		for (let f = 0; f < frames; f++) {
			q += 16;
			const ev = u32(a, q);
			q += 4;
			const ne = u32(a, q);
			q += 4;
			assert.strictEqual(ev, 0, '事件数恒 0');
			q += ne * 40;
		}
	}
	assert.deepStrictEqual(anims.map(x => x.nm), ['idle', 'walk'], '方向后缀被剥离');
	assert.deepStrictEqual(anims.map(x => x.facing), [0xff, 0x02], '_up -> facing 0x02');
	assert.ok(anims.every(x => x.fps === 30), 'fps 恒 30');
	assert.ok(anims.every(x => x.bank === kleiHash('bank1')), 'bank = entity hash');
	assert.deepStrictEqual(anims.map(x => x.frames), [32, 14]);

	// ---- atlas-0.tex ----
	const t = result.files.get('atlas-0.tex');
	assert.strictEqual(t.subarray(0, 4).toString('ascii'), 'KTEX');
	const spec = u32(t, 4);
	assert.strictEqual(spec & 0xf, 0, 'platform');
	assert.strictEqual((spec >> 4) & 0x1f, 2, 'pixelFormat = DXT5');
	assert.strictEqual((spec >> 9) & 0xf, 1, 'textureType');
	assert.strictEqual((spec >> 18) & 0x3, 3, 'flags');
	assert.strictEqual((spec >> 20) & 0xfff, 4095, 'fill');
	const mips = (spec >> 13) & 0x1f;
	let mp = 8;
	let sum = 0;
	for (let i = 0; i < mips; i++) {
		const w = t.readUInt16LE(mp);
		const h = t.readUInt16LE(mp + 2);
		const pitch = t.readUInt16LE(mp + 4);
		const size = u32(t, mp + 6);
		assert.strictEqual(pitch, w * 4, 'pitch = w*4');
		assert.ok(size >= 16, 'dataSize');
		sum += size;
		mp += 10;
	}
	assert.strictEqual(t.length, mp + sum, 'mip 数据长度与头部一致');

	fs.rmSync(root, { recursive: true, force: true });
	console.log('smoke-anim2: OK  (' + names.join(', ') + ')');
})().catch(err => {
	console.error('smoke-anim2 FAILED:', err && err.message || err);
	process.exitCode = 1;
});
