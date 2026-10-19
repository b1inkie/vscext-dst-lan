// 参考工具验证
const Module = require('module');
const orig = Module._load;
Module._load = function (request, ...rest) {
	if (request === 'vscode') {
		return { window: { createOutputChannel: () => ({ appendLine() {}, show() {} }) } };
	}
	return orig.call(this, request, ...rest);
};

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { packScmlToZip } = require('../../out/lib/anim2/pack.js');
const { kleiHash: strhash } = require('../../out/lib/anim2/bins.js');


const SCML = 'D:/DST_content/tools/win-dst-mod-tool/bow/bow.scml';
const GOLD = 'D:/tmp/gold/bow_gold.zip';

// 参考工具验证
const AdmZipLike = require('child_process');
function readZipEntry(zipPath, name) {
	// 用 archiver 不行(只写), 借助内置? 用 python 太慢; 直接手撸 minimal zip 读取(本地条目, deflate)
	const buf = fs.readFileSync(zipPath);
	// 找 EOCD
	let eocd = -1;
	for (let i = buf.length - 22; i >= 0 && i > buf.length - 22 - 65536; i--) {
		if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
	}
	assert.ok(eocd >= 0, 'EOCD');
	const count = buf.readUInt16LE(eocd + 10);
	const cdOff = buf.readUInt32LE(eocd + 16);
	let off = cdOff;
	const entries = {};
	for (let i = 0; i < count; i++) {
		assert.strictEqual(buf.readUInt32LE(off), 0x02014b50, 'CD sig');
		const method = buf.readUInt16LE(off + 10);
		const csize = buf.readUInt32LE(off + 20);
		const usize = buf.readUInt32LE(off + 24);
		const nameLen = buf.readUInt16LE(off + 28);
		const extraLen = buf.readUInt16LE(off + 30);
		const commentLen = buf.readUInt16LE(off + 32);
		const lho = buf.readUInt32LE(off + 42);
		const name = buf.toString('utf8', off + 46, off + 46 + nameLen);
		// local header
		const lNameLen = buf.readUInt16LE(lho + 26);
		const lExtraLen = buf.readUInt16LE(lho + 28);
		const dataStart = lho + 30 + lNameLen + lExtraLen;
		const raw = buf.subarray(dataStart, dataStart + csize);
		entries[name] = { method, data: method === 8 ? require('zlib').inflateRawSync(raw) : Buffer.from(raw), usize };
		off += 46 + nameLen + extraLen + commentLen;
	}
	return entries[name].data;
}

function parseGoldAnim(b) {
	let o = 0;
	const rd = (n) => { const s = b.toString('utf8', o, o + n); o += n; return s; };
	const i32 = () => { const v = b.readInt32LE(o); o += 4; return v; };
	const u32 = () => { const v = b.readUInt32LE(o); o += 4; return v; };
	const f32 = () => { const v = b.readFloatLE(o); o += 4; return v; };
	const ls = () => { const n = i32(); return rd(n); };
	const by = () => b.readUInt8(o++);
	assert.strictEqual(rd(4), 'ANIM');
	const ver = i32();
	const nele = u32(), nfrm = u32(), nevt = u32(), nanim = u32();
	const anims = [];
	for (let i = 0; i < nanim; i++) {
		const name = ls();
		const facing = by();
		const root = u32();
		const fps = f32();
		const nf = u32();
		const frames = [];
		for (let f = 0; f < nf; f++) {
			const bbox = [f32(), f32(), f32(), f32()];
			const nev = u32();
			const events = [];
			for (let e = 0; e < nev; e++) events.push(u32());
			const ne = u32();
			const elms = [];
			for (let e = 0; e < ne; e++) {
				elms.push({ sym: u32(), frame: u32(), layer: u32(), m: [f32(), f32(), f32(), f32(), f32(), f32(), f32()] });
			}
			frames.push({ bbox, events, elms });
		}
		anims.push({ name, facing, root, fps, frames });
	}
	const nh = u32();
	const ht = {};
	for (let i = 0; i < nh; i++) { const hv = u32(); ht[hv] = ls(); }
	return { ver, nele, nfrm, nevt, nanim, anims, ht };
}

(async () => {
	const goldBuf = readZipEntry(GOLD, 'anim.bin');
	const readZipEntryBuffer = (buf, name) => { const entries = {}; const b = buf; let eocd=-1; for(let i=b.length-22;i>=0&&i>b.length-22-65536;i--){if(b.readUInt32LE(i)===0x06054b50){eocd=i;break;}} const count=b.readUInt16LE(eocd+10); const cdOff=b.readUInt32LE(eocd+16); let off=cdOff; for(let i=0;i<count;i++){const method=b.readUInt16LE(off+10);const csize=b.readUInt32LE(off+20);const nameLen=b.readUInt16LE(off+28);const extraLen=b.readUInt16LE(off+30);const commentLen=b.readUInt16LE(off+32);const lho=b.readUInt32LE(off+42);const name=b.toString('utf8',off+46,off+46+nameLen);const lNameLen=b.readUInt16LE(lho+26);const lExtraLen=b.readUInt16LE(lho+28);const dataStart=lho+30+lNameLen+lExtraLen;const raw=b.subarray(dataStart,dataStart+csize);entries[name]=method===8?require('zlib').inflateRawSync(raw):Buffer.from(raw);off+=46+nameLen+extraLen+commentLen;} return entries[name]; };
	const gold = parseGoldAnim(goldBuf);
	console.log(`gold anim.bin: v${gold.ver} anims=${gold.nanim} frames=${gold.nfrm} elements=${gold.nele}`);

	const result = await packScmlToZip(SCML, 'D:/tmp/animlab/_cmp_tmp.zip');
	const zipBuf = require('fs').readFileSync('D:/tmp/animlab/_cmp_tmp.zip');
	// 从 zip 里取 anim.bin(手写 zip 读取已在 readZipEntry)
	const goldBuf0 = readZipEntryBuffer(zipBuf, 'anim.bin');
	const anims = parseMineAnim(goldBuf0);

	// ---- 对比 ----
	assert.strictEqual(anims.length, gold.nanim, `anim count ${anims.length} vs ${gold.nanim}`);
	let frameTotal = 0, elemTotal = 0;
	let bboxClose = 0, bboxFar = 0;
	const problems = []; const cats = {}; const cat = (c) => { cats[c] = (cats[c]||0)+1; };
	for (let i = 0; i < gold.anims.length; i++) {
		const g = gold.anims[i];
		const m = anims[i];
		frameTotal += g.frames.length;
		if (m.name !== g.name) problems.push(`anim[${i}] name ${m.name} vs ${g.name}`);
		if (m.facing !== g.facing) problems.push(`${g.name}: facing ${m.facing} vs ${g.facing}`);
		if (m.root !== g.root) problems.push(`${g.name}: root hash`);
		if (Math.abs(30 - g.fps) > 0.01) problems.push(`${g.name}: fps`);
		if (m.frames.length !== g.frames.length) { problems.push(`${g.name}: frames ${m.frames.length} vs ${g.frames.length}`); continue; }
		for (let f = 0; f < g.frames.length; f++) {
			const gf = g.frames[f];
			const mf = m.frames[f];
			elemTotal += gf.elms.length;
			if (gf.elms.length !== mf.elms.length) { problems.push(`${g.name}[${f}] elements ${mf.elms.length} vs ${gf.elms.length}`); continue; }
			for (let e = 0; e < gf.elms.length; e++) {
				const ge = gf.elms[e];
				const me = mf.elms[e];
				if (me.sym !== ge.sym) cat('sym');
				if (me.frame !== ge.frame) cat('frame');
				if (me.layer !== ge.layer) { cat('layer'); if (cats.layer<=5) console.log('LAYER', g.name, f, 'minehash', me.layer, 'gold', gold.ht[ge.layer]); }
				const names = ['a', 'b', 'c', 'd', 'tx', 'ty', 'z'];
				for (let k = 0; k < 7; k++) {
					if (Math.abs(me.m[k] - ge.m[k]) > 0.01) {
						cat('m_' + names[k]);
					}
				}
			}
			const dbx = Math.abs(gf.bbox[0] - mf.x) + Math.abs(gf.bbox[1] - mf.y) + Math.abs(gf.bbox[2] - mf.w) + Math.abs(gf.bbox[3] - mf.h);
			if (dbx < 2) bboxClose++; else { bboxFar++; if (bboxFar<=3) console.log('BBOX', g.name, f, 'mine', mf.bbox.map(v=>v.toFixed(1)).join(','), 'gold', gf.bbox.map(v=>v.toFixed(1)).join(',')); }
		}
	}
	console.log(`frames=${frameTotal} elements=${elemTotal} bboxClose=${bboxClose} bboxFar=${bboxFar}`);
	if (problems.length) {
		console.log(`PROBLEMS (${problems.length}):`);
		for (const p of problems.slice(0, 30)) console.log('  ' + p);
	}
	console.log('bboxClose=' + bboxClose + ' bboxFar=' + bboxFar);
	console.log(problems.length === 0 ? 'ANIM BIN FULL MATCH (semantics)' : `SEMANTIC DIFFS: ${problems.length}`);
	console.log('cats:', JSON.stringify(cats));
	for (const pr of problems.slice(0, 15)) console.log('  ' + pr);
})().catch(e => { console.error('FAILED:', e); process.exit(1); });

function parseMineAnim(b) {
	let o = 0;
	const rd = (n) => { const s = b.toString('utf8', o, o + n); o += n; return s; };
	const i32 = () => { const v = b.readInt32LE(o); o += 4; return v; };
	const u32 = () => { const v = b.readUInt32LE(o); o += 4; return v; };
	const f32 = () => { const v = b.readFloatLE(o); o += 4; return v; };
	const ls = () => { const n = i32(); return rd(n); };
	const by = () => b.readUInt8(o++);
	rd(4);
	i32(); u32(); u32(); u32();
	const nanim = u32();
	const anims = [];
	for (let i = 0; i < nanim; i++) {
		const name = ls(); const facing = by(); const root = u32(); f32();
		const nf = u32(); const frames = [];
		for (let f = 0; f < nf; f++) {
			const bbox = [f32(), f32(), f32(), f32()]; const nev = u32(); for (let e = 0; e < nev; e++) u32();
			const ne = u32(); const elms = [];
			for (let e = 0; e < ne; e++) elms.push({ sym: u32(), frame: u32(), layer: u32(), m: [f32(), f32(), f32(), f32(), f32(), f32(), f32()] });
			frames.push({ bbox, elms });
		}
		anims.push({ name, facing, root, frames });
	}
	return anims;
}
