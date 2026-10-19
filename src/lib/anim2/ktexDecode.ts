/**
 * KTEX(.tex) 解包: DXT5 解码 + mip 定位 + 翻转/去预乘还原。
 *
 * 与编码端(src/lib/anim2/ktex.ts)互逆:
 *  - mip 条目表与数据区均按 大→小 排列, mip0 在数据区头部;
 *  - tex 内 v 坐标对应原始行 pageH-1-y → 解码后整页 flip 还原;
 *  - 颜色为预乘 alpha(RGB×A/255) → 还原时 RGB×255/A(A=0 置 0)。
 */
import { flipYRgba } from './ktex';

export interface KtexInfo {
	width: number;
	height: number;
	mipCount: number;
	pixelFormat: number;
}

/** 解析 KTEX 头, 返回 mip 表与数据区起始偏移 */
export function parseKtexHeader(buf: Buffer): { mips: Array<{ w: number; h: number; size: number }>; dataOffset: number; pixelFormat: number } {
	if (buf.length < 8 || buf.readUInt32LE(0) !== 0x5845544B) { // 'KTEX' LE
		throw new Error('not a KTEX file');
	}
	const spec = buf.readUInt32LE(4);
	const pixelFormat = (spec >> 4) & 0x1f;
	const mipCount = (spec >> 13) & 0x1f;
	const mips: Array<{ w: number; h: number; size: number }> = [];
	let p = 8;
	for (let i = 0; i < mipCount; i++) {
		mips.push({ w: buf.readUInt16LE(p), h: buf.readUInt16LE(p + 2), size: buf.readUInt32LE(p + 6) });
		p += 10;
	}
	return { mips, dataOffset: p, pixelFormat };
}

/** DXT5(BC3) 块解码: 16 字节块 → 4x4 RGBA */
export function decodeDxt5(data: Buffer, width: number, height: number): Buffer {
	const bw = Math.max(1, Math.ceil(width / 4));
	const bh = Math.max(1, Math.ceil(height / 4));
	const out = Buffer.alloc(width * height * 4);
	let off = 0;
	for (let by = 0; by < bh; by++) {
		for (let bx = 0; bx < bw; bx++) {
			if (off + 16 > data.length) {
				return out;
			}
			const a0 = data[off];
			const a1 = data[off + 1];
			const abits = data.readBigUInt64LE(off + 2);
			// alpha 8 端点调色板
			const alphas = new Array<number>(8);
			alphas[0] = a0;
			alphas[1] = a1;
			if (a0 > a1) {
				for (let i = 1; i < 7; i++) {
					alphas[i + 1] = Math.round(((7 - i) * a0 + i * a1) / 7);
				}
			} else {
				for (let i = 1; i < 5; i++) {
					alphas[i + 1] = Math.round(((5 - i) * a0 + i * a1) / 5);
				}
				alphas[6] = 0;
				alphas[7] = 255;
			}
			// color 4 端点调色板(RGB565)
			const c0 = data.readUInt16LE(off + 8);
			const c1 = data.readUInt16LE(off + 10);
			const bits = data.readUInt32LE(off + 12);
			const rgb565 = (c: number): [number, number, number] => {
				const r = (c >> 11) & 0x1f;
				const g = (c >> 5) & 0x3f;
				const b = c & 0x1f;
				return [(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)];
			};
			const p0 = rgb565(c0);
			const p1 = rgb565(c1);
			const pal: Array<[number, number, number]> = [p0, p1];
			if (c0 > c1) {
				pal.push([(2 * p0[0] + p1[0]) / 3 | 0, (2 * p0[1] + p1[1]) / 3 | 0, (2 * p0[2] + p1[2]) / 3 | 0]);
				pal.push([(p0[0] + 2 * p1[0]) / 3 | 0, (p0[1] + 2 * p1[1]) / 3 | 0, (p0[2] + 2 * p1[2]) / 3 | 0]);
			} else {
				pal.push([(p0[0] + p1[0]) / 2 | 0, (p0[1] + p1[1]) / 2 | 0, (p0[2] + p1[2]) / 2 | 0]);
				pal.push([0, 0, 0]);
			}
			for (let i = 0; i < 16; i++) {
				const x = bx * 4 + (i % 4);
				const y = by * 4 + (i >> 2);
				if (x >= width || y >= height) {
					continue;
				}
				const a = alphas[Number((abits >> BigInt(3 * i)) & BigInt(7))];
				const c = pal[(bits >> (2 * i)) & 3];
				const o = (y * width + x) * 4;
				out[o] = c[0];
				out[o + 1] = c[1];
				out[o + 2] = c[2];
				out[o + 3] = a;
			}
			off += 16;
		}
	}
	return out;
}

/** 预乘还原: RGB×255/A(A=0 置 0) */
export function unpremultiplyRgba(rgba: Buffer): Buffer {
	for (let i = 0; i < rgba.length; i += 4) {
		const a = rgba[i + 3];
		if (a === 255 || a === 0) {
			if (a === 0) {
				rgba[i] = 0;
				rgba[i + 1] = 0;
				rgba[i + 2] = 0;
			}
			continue;
		}
		rgba[i] = Math.min(255, Math.round((rgba[i] * 255) / a));
		rgba[i + 1] = Math.min(255, Math.round((rgba[i + 1] * 255) / a));
		rgba[i + 2] = Math.min(255, Math.round((rgba[i + 2] * 255) / a));
	}
	return rgba;
}

/** 解码 tex 的指定 mip(默认 mip0), 返回原始方向、直通 alpha 的 RGBA */
export function decodeKtexMip(buf: Buffer, mipIndex = 0): { rgba: Buffer; width: number; height: number; info: KtexInfo } {
	const { mips, dataOffset, pixelFormat } = parseKtexHeader(buf);
	if (mipIndex >= mips.length) {
		throw new Error(`mip ${mipIndex} out of range (${mips.length})`);
	}
	if (pixelFormat !== 2) {
		throw new Error(`unsupported pixel format ${pixelFormat} (only DXT5)`);
	}
	// 数据区大→小: 第 i 个 mip 的偏移 = header + 前 i 个 size 之和
	let off = dataOffset;
	for (let i = 0; i < mipIndex; i++) {
		off += mips[i].size;
	}
	const m = mips[mipIndex];
	const rgba = decodeDxt5(buf.subarray(off, off + m.size), m.w, m.h);
	const flipped = flipYRgba(unpremultiplyRgba(rgba), m.w, m.h);
	return { rgba: flipped, width: m.w, height: m.h, info: { width: m.w, height: m.h, mipCount: mips.length, pixelFormat } };
}
