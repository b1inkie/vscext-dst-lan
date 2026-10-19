/**
 * 图片区域(四边形)切分:
 *
 *   1. 每个轴按 2 的幂等分为 N 块，直到块边长 <= 32：
 *        N = 1; while (size / N > 32) N *= 2;   block = size / N
 *   2. 每块分类（对块内像素统计 alpha）：
 *        含任一 0 < a < 255      -> ALPHA
 *        否则含任一 a > 0        -> OPAQUE
 *        全透明                  -> 丢弃
 *   3. 同类块按 4-邻接求连通分量，取分量包围盒 -> 一个矩形
 *   4. 先输出 OPAQUE 分量，再输出 ALPHA 分量；同类内按行优先
 *
 * 实测样例（见 probe）：half68 -> 2 块 34x68；grad68 -> 整图 1 块；
 * circle/checker -> 整图 1 块；corner(左上 32x32 不透明) -> 1 块 32x32。
 */

export const BLOCK_MAX = 32;

export interface Rect {
	x: number;
	y: number;
	w: number;
	h: number;
}

export interface Regions {
	/** 完全不透明的连通块包围盒 */
	opaque: Rect[];
	/** 含半透明像素的连通块包围盒 */
	alpha: Rect[];
}

const enum Kind {
	Skip = 0,
	Opaque = 1,
	Alpha = 2,
}

/**
 * 块边界：对边长做**整数**折半递归，直到每段 <= 32。
 * 实测 141 -> 0,17,35,52,70,87,105,123,141（注意 87 而不是 88）
 */
export function splitEdges(size: number): number[] {
	let edges = [0, size];
	for (;;) {
		let changed = false;
		const next: number[] = [edges[0]];
		for (let i = 1; i < edges.length; i++) {
			const a = edges[i - 1];
			const b = edges[i];
			if (b - a > BLOCK_MAX) {
				next.push(a + ((b - a) >> 1));
				changed = true;
			}
			next.push(b);
		}
		edges = next;
		if (!changed) {
			return edges;
		}
	}
}

/**
 * @param rgba 未预乘的 RGBA 像素
 */
export function getImageRegions(rgba: Buffer, width: number, height: number): Regions {
	const xs = splitEdges(width);
	const ys = splitEdges(height);
	const nx = xs.length - 1;
	const ny = ys.length - 1;

	const kinds = new Uint8Array(nx * ny);
	for (let by = 0; by < ny; by++) {
		const y0 = ys[by];
		const y1 = ys[by + 1];
		for (let bx = 0; bx < nx; bx++) {
			const x0 = xs[bx];
			const x1 = xs[bx + 1];
			let anyPartial = false;
			let anySolid = false;
			for (let y = y0; y < y1 && !(anyPartial && anySolid); y++) {
				let p = (y * width + x0) * 4 + 3;
				for (let x = x0; x < x1; x++, p += 4) {
					const a = rgba[p];
					if (a === 0) {
						continue;
					}
					if (a === 255) {
						anySolid = true;
					} else {
						anyPartial = true;
					}
					if (anyPartial && anySolid) {
						break;
					}
				}
			}
			kinds[by * nx + bx] = anyPartial ? Kind.Alpha : anySolid ? Kind.Opaque : Kind.Skip;
		}
	}


	/**
	 * 贪心最大矩形切分：行优先扫描未访问块，先向右、再向下扩展，
	 * 得到互不重叠、同类别的矩形（与 exe 的 bg 5 块 / frame_circle 10 块对得上）。
	 */
	function collect(kind: Kind): Rect[] {
		const used = new Uint8Array(nx * ny);
		const out: Rect[] = [];
		for (let by = 0; by < ny; by++) {
			for (let bx = 0; bx < nx; bx++) {
				if (used[by * nx + bx] || kinds[by * nx + bx] !== kind) {
					continue;
				}
				// 向右扩展
				let x1 = bx;
				while (x1 + 1 < nx && !used[by * nx + x1 + 1] && kinds[by * nx + x1 + 1] === kind) {
					x1++;
				}
				// 向下扩展（整行都必须可用）
				let y1 = by;
				while (y1 + 1 < ny) {
					let okRow = true;
					for (let x = bx; x <= x1; x++) {
						const i = (y1 + 1) * nx + x;
						if (used[i] || kinds[i] !== kind) {
							okRow = false;
							break;
						}
					}
					if (!okRow) {
						break;
					}
					y1++;
				}
				for (let y = by; y <= y1; y++) {
					for (let x = bx; x <= x1; x++) {
						used[y * nx + x] = 1;
					}
				}
				out.push({
					x: xs[bx],
					y: ys[by],
					w: xs[x1 + 1] - xs[bx],
					h: ys[y1 + 1] - ys[by],
				});
			}
		}
		return out;
	}

	return { opaque: collect(Kind.Opaque), alpha: collect(Kind.Alpha) };
}
