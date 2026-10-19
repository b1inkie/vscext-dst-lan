/**
 * build.bin(BILD v6) 写入。
 *
 * build.bin(BILD v6) 字段布局：
 *
 *   'BILD' v6
 *   u32 numSymbols, u32 numFramesTotal(各 symbol 唯一帧数之和)
 *   str buildName
 *   u32 numPages, str pageName[]
 *   per symbol（按 hash 升序）:
 *     u32 hash, u32 numFrames
 *     per frame（32 字节）:
 *       u32 frameNum, u32 duration, f32 x, f32 y, f32 w, f32 h,
 *       u32 vertOffset, u32 vertCount
 *   u32 numVerts
 *   verts: f32 x, f32 y, f32 _0, f32 u, f32 v, f32 page      (24 字节)
 *   u32 numNames, { u32 hash, str name }[]
 *
 * 其中 x = w/2 - pivotX*w, y = pivotY*h - h/2（y 轴向下）；
 * u,v 为图集页上的归一化坐标，且 v = 1 - y/pageH（已实测翻转）。
 */
import { BinWriter, kleiHash } from './bins';
import { Rect } from './regions';

export const BILD_VERSION = 6;

export interface BuildFrameInput {
	frameNum: number;
	duration: number;
	x: number;
	y: number;
	w: number;
	h: number;
	/** 该帧的四边形：局部位置 + 图集取样矩形 */
	quads: {
		pos: Rect;
		uv: { u0: number; u1: number; v0: number; v1: number };
		page: number;
	}[];
}

export interface BuildSymbol {
	name: string;
	hash: number;
	frames: BuildFrameInput[];
}

export function writeBuildBin(
	buildName: string,
	symbols: BuildSymbol[],
	pageNames: string[],
	names: Map<number, string>,
): Buffer {
	const w = new BinWriter();
	const sorted = [...symbols].sort((a, b) => a.hash - b.hash);
	let totalFrames = 0;
	for (const s of sorted) {
		totalFrames += s.frames.length;
	}

	w.bytes(Buffer.from('BILD', 'ascii'));
	w.u32(BILD_VERSION);
	w.u32(sorted.length);
	w.u32(totalFrames);
	w.str(buildName);
	w.u32(pageNames.length);
	for (const p of pageNames) {
		w.str(p);
	}

	// 顶点池：按 symbol 顺序追加
	const pool: number[] = [];
	for (const symbol of sorted) {
		w.u32(symbol.hash);
		w.u32(symbol.frames.length);
		for (const f of symbol.frames) {
			const offset = pool.length / 6;
			const count = f.quads.length * 6;
			w.u32(f.frameNum);
			w.u32(f.duration);
			w.f32(f.x);
			w.f32(f.y);
			w.f32(f.w);
			w.f32(f.h);
			w.u32(offset);
			w.u32(count);
			for (const q of f.quads) {
				const x0 = q.pos.x;
				const y0 = q.pos.y;
				const x1 = q.pos.x + q.pos.w;
				const y1 = q.pos.y + q.pos.h;
				const { u0, u1, v0, v1 } = q.uv;
				const page = q.page;
				// 三角形 1
				pool.push(x0, y0, 0, u0, v1, page);
				pool.push(x1, y0, 0, u1, v1, page);
				pool.push(x0, y1, 0, u0, v0, page);
				// 三角形 2
				pool.push(x1, y0, 0, u1, v1, page);
				pool.push(x1, y1, 0, u1, v0, page);
				pool.push(x0, y1, 0, u0, v0, page);
			}
		}
	}

	w.u32(pool.length / 6);
	for (const v of pool) {
		w.f32(v);
	}

	const entries = [...names.entries()].sort((a, b) => a[0] - b[0]);
	w.u32(entries.length);
	for (const [h, n] of entries) {
		w.u32(h);
		w.str(n);
	}
	return w.toBuffer();
}

export function symbolNames(symbols: BuildSymbol[]): Map<number, string> {
	const m = new Map<number, string>();
	for (const s of symbols) {
		m.set(s.hash, s.name);
	}
	return m;
}

export { kleiHash };
