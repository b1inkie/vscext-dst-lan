/**
 * KTEX(.tex) 写入 —— DXT5(BC3) + 完整 mip 链。
 *
 * 头格式(KTEX, 洞穴更新后版本)：
 *   'KTEX' + u32 位域: platform(4bit) | pixelFormat(5bit)<<4 | textureType(4bit)<<9
 *          | mipCount(5bit)<<13 | flags(2bit)<<18 | fill(12bit)<<20
 *   mip 条目 * mipCount: u16 w, u16 h, u16 pitch, u32 dataSize   (10 字节)
 *   随后按 大->小 顺序连续存放 DXT5 数据
 *
 * 实测：pixelFormat=2(DXT5), textureType=1, flags=3, fill=4095,
 *       pitch = w*4, dataSize = w*h（DXT5 = 1 byte/px；2x2、1x1 也占满一个 4x4 块 = 16）
 *       无 premultiply 标志字节；--unpacktex 解出的颜色与源图一致（直通 alpha）
 */

export const PIXEL_FORMAT_DXT5 = 2;
export const TEXTURE_TYPE_2D = 1;

export interface KtexMip {
	width: number;
	height: number;
	/** DXT5 压缩数据 */
	data: Buffer;
}

export function ktexSpec(mipCount: number): number {
	const platform = 0;
	const pixelFormat = PIXEL_FORMAT_DXT5;
	const textureType = TEXTURE_TYPE_2D;
	const flags = 3;
	const fill = 4095;
	return ((platform
		| (pixelFormat << 4)
		| (textureType << 9)
		| ((mipCount & 0x1f) << 13)
		| ((flags & 0x3) << 18)
		| ((fill & 0xfff) << 20)) >>> 0);
}

/** 生成 mip 链（长度 = log2(max(w,h)) + 1，直到 1x1） */
export function nextMipSize(w: number, h: number): [number, number] {
	return [Math.max(1, w >> 1), Math.max(1, h >> 1)];
}

/** 2x2 盒式降采样（直通 alpha，不做预乘） */
export function downsampleRgba(rgba: Buffer, w: number, h: number): { data: Buffer; w: number; h: number } {
	const [nw, nh] = nextMipSize(w, h);
	const out = Buffer.alloc(nw * nh * 4);
	for (let y = 0; y < nh; y++) {
		for (let x = 0; x < nw; x++) {
			const sx = Math.min(w - 1, x * 2);
			const sy = Math.min(h - 1, y * 2);
			const sx1 = Math.min(w - 1, sx + 1);
			const sy1 = Math.min(h - 1, sy + 1);
			const p00 = (sy * w + sx) * 4;
			const p10 = (sy * w + sx1) * 4;
			const p01 = (sy1 * w + sx) * 4;
			const p11 = (sy1 * w + sx1) * 4;
			const o = (y * nw + x) * 4;
			for (let c = 0; c < 4; c++) {
				out[o + c] = (rgba[p00 + c] + rgba[p10 + c] + rgba[p01 + c] + rgba[p11 + c] + 2) >> 2;
			}
		}
	}
	return { data: out, w: nw, h: nh };
}

/**
 * 预乘 alpha（DST 的 .tex 是预乘存储的：半透明像素 RGB 已乘 alpha）。
 * 对拍证据：zip2scml 会把 tex 当作预乘来反解，不预乘时半透明区域颜色偏差极大。
 */
/** 整页上下翻转: tex 内 v 坐标对应原始行 pageH-1-y, 编码前必须整页 flip */
export function flipYRgba(rgba: Buffer, width: number, height: number): Buffer {
	const out = Buffer.alloc(rgba.length);
	const row = width * 4;
	for (let y = 0; y < height; y++) {
		rgba.copy(out, y * row, (height - 1 - y) * row, (height - y) * row);
	}
	return out;
}

export function premultiplyRgba(rgba: Buffer): Buffer {
	const out = Buffer.from(rgba);
	for (let i = 0; i < out.length; i += 4) {
		const a = out[i + 3];
		if (a === 255) {
			continue;
		}
		if (a === 0) {
			out[i] = 0;
			out[i + 1] = 0;
			out[i + 2] = 0;
			continue;
		}
		out[i] = Math.round((out[i] * a) / 255);
		out[i + 1] = Math.round((out[i + 1] * a) / 255);
		out[i + 2] = Math.round((out[i + 2] * a) / 255);
	}
	return out;
}

/** 生成完整 mip 链（RGBA） */
export function buildMipChain(rgba: Buffer, w: number, h: number): { data: Buffer; w: number; h: number }[] {
	const chain = [{ data: rgba, w, h }];
	let cur = chain[0];
	while (cur.w > 1 || cur.h > 1) {
		const next = downsampleRgba(cur.data, cur.w, cur.h);
		chain.push(next);
		cur = next;
	}
	return chain;
}

/**
 * 一像素块的 alpha 端点/索引。
 * BC3 有两种模式：
 *   a0 > a1 : 8 级插值（通用）
 *   a0 <= a1: 6 级插值 + 显式 0/255（硬边/二值 alpha 更准）
 * 两种都算一遍取误差小的。
 */
function encodeAlphaBlock(rgba: Buffer, width: number, ox: number, oy: number, out: Buffer, off: number): void {
	const alphas: number[] = [];
	for (let y = 0; y < 4; y++) {
		for (let x = 0; x < 4; x++) {
			alphas.push(rgba[((oy + y) * width + ox + x) * 4 + 3]);
		}
	}

	const build = (a0: number, a1: number): number[] => {
		const pal = new Array<number>(8).fill(a0);
		pal[0] = a0;
		pal[1] = a1;
		if (a0 > a1) {
			for (let i = 1; i <= 6; i++) {
				pal[i + 1] = Math.round(((7 - i) * a0 + i * a1) / 7);
			}
		} else {
			for (let i = 1; i <= 4; i++) {
				pal[i + 1] = Math.round(((5 - i) * a0 + i * a1) / 5);
			}
			pal[6] = 0;
			pal[7] = 255;
		}
		return pal;
	};

	const assignAlpha = (pal: number[]): { idx: number[]; err: number } => {
		const idx: number[] = [];
		let err = 0;
		for (let i = 0; i < 16; i++) {
			let best = 0;
			let bestErr = Infinity;
			for (let j = 0; j < 8; j++) {
				const e = Math.abs(pal[j] - alphas[i]);
				if (e < bestErr) {
					bestErr = e;
					best = j;
				}
			}
			idx.push(best);
			err += bestErr * bestErr;
		}
		return { idx, err };
	};

	// 候选端点：取块内出现的 alpha 值（最多 10 个，等距抽样），两两组合搜索最优
	const distinct = [...new Set(alphas)].sort((a, b) => a - b);
	let cand = distinct;
	if (cand.length > 10) {
		const step = (cand.length - 1) / 9;
		cand = Array.from({ length: 10 }, (_, i) => cand[Math.round(i * step)]);
	}

	let bestA0 = 255;
	let bestA1 = 0;
	let bestIdx: number[] = [];
	let bestErr = Infinity;
	const modes: [number, number, boolean][] = [];
	for (const hi of cand) {
		for (const lo of cand) {
			if (hi > lo) {
				modes.push([hi, lo, true]);      // 8 值模式
			}
			// 6 值模式：a0 <= a1，附带 0/255
			modes.push([Math.min(lo, hi), Math.max(lo, hi), false]);
		}
	}
	for (const [a0c, a1c, is8] of modes) {
		const pal = build(a0c, a1c);
		// 6 值模式要求 a0 <= a1（build 里按 a0>a1 判断）
		if (!is8 && a0c > a1c) {
			continue;
		}
		const res = assignAlpha(pal);
		if (res.err < bestErr) {
			bestErr = res.err;
			bestA0 = a0c;
			bestA1 = a1c;
			bestIdx = res.idx;
		}
	}
	const a0 = bestA0;
	const a1 = bestA1;
	const idx = bestIdx;
	out[off] = a0;
	out[off + 1] = a1;
	let bits = 0n;
	for (let i = 0; i < 16; i++) {
		bits |= BigInt(idx[i] & 7) << BigInt(3 * i);
	}
	for (let i = 0; i < 6; i++) {
		out[off + 2 + i] = Number((bits >> BigInt(8 * i)) & 0xffn);
	}
}

function color565(r: number, g: number, b: number): number {
	return (((r >> 3) & 0x1f) << 11) | (((g >> 2) & 0x3f) << 5) | ((b >> 3) & 0x1f);
}

function expand565(c: number): [number, number, number] {
	const r = (c >> 11) & 0x1f;
	const g = (c >> 5) & 0x3f;
	const b = c & 0x1f;
	return [(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)];
}

/**
 * 一像素块的色度端点/索引。
 *
 * 采用「主轴（PCA）+ 最小二乘端点重拟合」的两段式，接近 squish/stb_dxt 的质量；
 * 实测比朴素的 min/max 端点好一个数量级（与 exe 的 image_dds 编码器对拍）。
 */
function encodeColorBlock(rgba: Buffer, width: number, ox: number, oy: number, out: Buffer, off: number): void {
	const r = new Float64Array(16);
	const g = new Float64Array(16);
	const b = new Float64Array(16);
	let mr = 0;
	let mg = 0;
	let mb = 0;
	for (let i = 0; i < 16; i++) {
		const x = ox + (i % 4);
		const y = oy + (i >> 2);
		const p = (y * width + x) * 4;
		r[i] = rgba[p];
		g[i] = rgba[p + 1];
		b[i] = rgba[p + 2];
		mr += r[i];
		mg += g[i];
		mb += b[i];
	}
	mr /= 16;
	mg /= 16;
	mb /= 16;

	// 3x3 协方差
	let cxx = 0;
	let cxy = 0;
	let cxz = 0;
	let cyy = 0;
	let cyz = 0;
	let czz = 0;
	for (let i = 0; i < 16; i++) {
		const dr = r[i] - mr;
		const dg = g[i] - mg;
		const db = b[i] - mb;
		cxx += dr * dr;
		cxy += dr * dg;
		cxz += dr * db;
		cyy += dg * dg;
		cyz += dg * db;
		czz += db * db;
	}
	// 幂迭代求最大特征向量
	let ax = 1;
	let ay = 1;
	let az = 1;
	for (let it = 0; it < 8; it++) {
		const nx = cxx * ax + cxy * ay + cxz * az;
		const ny = cxy * ax + cyy * ay + cyz * az;
		const nz = cxz * ax + cyz * ay + czz * az;
		const len = Math.hypot(nx, ny, nz) || 1;
		ax = nx / len;
		ay = ny / len;
		az = nz / len;
	}
	// 投影到主轴，取极值作为端点
	let tmin = Infinity;
	let tmax = -Infinity;
	for (let i = 0; i < 16; i++) {
		const t = (r[i] - mr) * ax + (g[i] - mg) * ay + (b[i] - mb) * az;
		if (t < tmin) {
			tmin = t;
		}
		if (t > tmax) {
			tmax = t;
		}
	}
	let e0: [number, number, number] = [
		Math.max(0, Math.min(255, mr + ax * tmax)),
		Math.max(0, Math.min(255, mg + ay * tmax)),
		Math.max(0, Math.min(255, mb + az * tmax)),
	];
	let e1: [number, number, number] = [
		Math.max(0, Math.min(255, mr + ax * tmin)),
		Math.max(0, Math.min(255, mg + ay * tmin)),
		Math.max(0, Math.min(255, mb + az * tmin)),
	];

	const clamp565 = (v: number): number => Math.max(0, Math.min(255, Math.round(v)));
	const toPalette = (a: [number, number, number], c: [number, number, number]) => {
		const p0 = expand565(color565(clamp565(a[0]), clamp565(a[1]), clamp565(a[2])));
		const p1 = expand565(color565(clamp565(c[0]), clamp565(c[1]), clamp565(c[2])));
		return [
			p0,
			p1,
			[(2 * p0[0] + p1[0]) / 3 | 0, (2 * p0[1] + p1[1]) / 3 | 0, (2 * p0[2] + p1[2]) / 3 | 0],
			[(p0[0] + 2 * p1[0]) / 3 | 0, (p0[1] + 2 * p1[1]) / 3 | 0, (p0[2] + 2 * p1[2]) / 3 | 0],
		] as [number, number, number][];
	};
	const assign = (pal: [number, number, number][]): number[] => {
		const idx: number[] = [];
		for (let i = 0; i < 16; i++) {
			let best = 0;
			let bestErr = Infinity;
			for (let j = 0; j < 4; j++) {
				const dr = pal[j][0] - r[i];
				const dg = pal[j][1] - g[i];
				const db = pal[j][2] - b[i];
				const err = dr * dr + dg * dg + db * db;
				if (err < bestErr) {
					bestErr = err;
					best = j;
				}
			}
			idx.push(best);
		}
		return idx;
	};

	const errorOf = (pal: [number, number, number][], idx: number[]): number => {
		let e = 0;
		for (let i = 0; i < 16; i++) {
			const dr = pal[idx[i]][0] - r[i];
			const dg = pal[idx[i]][1] - g[i];
			const db = pal[idx[i]][2] - b[i];
			e += dr * dr + dg * dg + db * db;
		}
		return e;
	};

	// 候选端点对：主轴极值 / 各轴包围盒极值 / 分量 min-max，取误差最小者
	const candidates: [number, number, number][][] = [[e0, e1]];
	{
		let minR = 255, maxR = 0, minG = 255, maxG = 0, minB = 255, maxB = 0;
		for (let i = 0; i < 16; i++) {
			minR = Math.min(minR, r[i]); maxR = Math.max(maxR, r[i]);
			minG = Math.min(minG, g[i]); maxG = Math.max(maxG, g[i]);
			minB = Math.min(minB, b[i]); maxB = Math.max(maxB, b[i]);
		}
		candidates.push([[maxR, minG, minB], [minR, maxG, maxB]]);
		candidates.push([[minR, maxG, minB], [maxR, minG, maxB]]);
		candidates.push([[minR, minG, maxB], [maxR, maxG, minB]]);
		candidates.push([[maxR, maxG, maxB], [minR, minG, minB]]);
		candidates.push([[minR, minG, minB], [maxR, maxG, maxB]]);
	}

	let bestErr = Infinity;
	let palette: [number, number, number][] = [];
	let indices: number[] = [];
	let best: [[number, number, number], [number, number, number]] = [e0, e1];
	for (const [a, b2] of candidates) {
		const pal = toPalette(a, b2);
		const idx = assign(pal);
		const err = errorOf(pal, idx);
		if (err < bestErr) {
			bestErr = err;
			palette = pal;
			indices = idx;
			best = [a, b2];
		}
	}
	e0 = best[0];
	e1 = best[1];

	// 最小二乘重拟合一次
	{
		const solve = (comp: Float64Array): [number, number] => {
			let a00 = 0;
			let a01 = 0;
			let a11 = 0;
			let b0 = 0;
			let b1 = 0;
			for (let i = 0; i < 16; i++) {
				let w0: number;
				let w1: number;
				switch (indices[i]) {
					case 0: w0 = 1; w1 = 0; break;
					case 1: w0 = 0; w1 = 1; break;
					case 2: w0 = 2 / 3; w1 = 1 / 3; break;
					default: w0 = 1 / 3; w1 = 2 / 3; break;
				}
				a00 += w0 * w0;
				a01 += w0 * w1;
				a11 += w1 * w1;
				b0 += w0 * comp[i];
				b1 += w1 * comp[i];
			}
			const det = a00 * a11 - a01 * a01;
			if (Math.abs(det) < 1e-6) {
				return [comp[0], comp[1]];
			}
			return [(a11 * b0 - a01 * b1) / det, (a00 * b1 - a01 * b0) / det];
		};
		const [r0, r1] = solve(r);
		const [g0, g1] = solve(g);
		const [b0v, b1v] = solve(b);
		const ne0: [number, number, number] = [
			Math.max(0, Math.min(255, r0)), Math.max(0, Math.min(255, g0)), Math.max(0, Math.min(255, b0v))];
		const ne1: [number, number, number] = [
			Math.max(0, Math.min(255, r1)), Math.max(0, Math.min(255, g1)), Math.max(0, Math.min(255, b1v))];
		const pal2 = toPalette(ne0, ne1);
		const idx2 = assign(pal2);
		if (errorOf(pal2, idx2) <= bestErr) {
			e0 = ne0;
			e1 = ne1;
			palette = pal2;
			indices = idx2;
		}
	}

	const c0 = color565(clamp565(e0[0]), clamp565(e0[1]), clamp565(e0[2]));
	const c1 = color565(clamp565(e1[0]), clamp565(e1[1]), clamp565(e1[2]));
	let cc0 = c0;
	let cc1 = c1;
	let idx = indices;
	if (cc0 < cc1) {
		// 交换端点并重映射索引（保持 4 色模式）
		cc0 = c1;
		cc1 = c0;
		idx = indices.map(i => (i === 0 ? 1 : i === 1 ? 0 : i === 2 ? 3 : 2));
	} else if (cc0 === cc1) {
		// 纯色块：微调端点，保证 c0 > c1
		if (cc0 < 0xffff) {
			cc0 = cc0 + 1;
		} else {
			cc1 = cc0 - 1;
		}
		idx = assign([expand565(cc0), expand565(cc1), expand565(cc0), expand565(cc1)] as [number, number, number][]);
	}
	out.writeUInt16LE(cc0, off);
	out.writeUInt16LE(cc1, off + 2);
	let bits = 0;
	for (let i = 0; i < 16; i++) {
		bits |= (idx[i] & 3) << (2 * i);
	}
	out.writeUInt32LE(bits >>> 0, off + 4);
}

/** 把 RGBA 图压缩成 DXT5；宽高需为 4 的倍数（不足按边缘像素补齐） */
export function encodeDxt5(rgba: Buffer, width: number, height: number): Buffer {
	const bw = Math.max(1, Math.ceil(width / 4));
	const bh = Math.max(1, Math.ceil(height / 4));
	const paddedW = bw * 4;
	const paddedH = bh * 4;
	let src = rgba;
	if (paddedW !== width || paddedH !== height) {
		src = Buffer.alloc(paddedW * paddedH * 4);
		for (let y = 0; y < paddedH; y++) {
			const sy = Math.min(height - 1, y);
			for (let x = 0; x < paddedW; x++) {
				const sx = Math.min(width - 1, x);
				src.set(rgba.subarray((sy * width + sx) * 4, (sy * width + sx) * 4 + 4), (y * paddedW + x) * 4);
			}
		}
	}
	const out = Buffer.alloc(bw * bh * 16);
	let off = 0;
	for (let by = 0; by < bh; by++) {
		for (let bx = 0; bx < bw; bx++) {
			encodeAlphaBlock(src, paddedW, bx * 4, by * 4, out, off);
			encodeColorBlock(src, paddedW, bx * 4, by * 4, out, off + 8);
			off += 16;
		}
	}
	return out;
}

/** 组装 KTEX 文件 */
export function writeKtex(mips: KtexMip[]): Buffer {
	const headerSize = 8 + mips.length * 10;
	const sizes = mips.map(m => m.data.length);
	const total = headerSize + sizes.reduce((a, b) => a + b, 0);
	const head = Buffer.alloc(headerSize);
	head.write('KTEX', 0, 'ascii');
	head.writeUInt32LE(ktexSpec(mips.length), 4);
	let p = 8;
	for (let i = 0; i < mips.length; i++) {
		const m = mips[i];
		head.writeUInt16LE(m.width, p);
		head.writeUInt16LE(m.height, p + 2);
		head.writeUInt16LE(Math.min(0xffff, m.width * 4), p + 4);
		head.writeUInt32LE(sizes[i], p + 6);
		p += 10;
	}
	// mip 条目表与数据区均按 大→小 连续存放
	return Buffer.concat([head, ...mips.map(m => m.data)], total);
}

/** RGBA -> 完整 KTEX（含 mip 链） */
export function encodeKtex(rgba: Buffer, width: number, height: number): Buffer {
	const chain = buildMipChain(rgba, width, height);
	return writeKtex(chain.map(m => ({ width: m.w, height: m.h, data: encodeDxt5(m.data, m.w, m.h) })));
}
