/**
 * 图集装箱。
 *
 * exe 的摆放顺序每次运行都不同（HashMap 迭代序 → 已实测同一输入多次运行
 * build.bin/tex 均不同），因此这里无法也不必逐字节复刻；本实现复刻的是
 * **可观测的规则**：
 *   - 单元格 = (w+4, h+4)，图像贴在单元格左上角（实测 68->72, 32->36, 16->20）
 *   - 页尺寸各轴为 2 的幂，初始 = nextPow2(最大单元格)，不足时先把较小轴翻倍
 *   - 货架（shelf）式摆放，行优先
 *   - 超过尺寸上限时另开新页，页名 atlas-N.tex
 */

export interface AtlasInput {
	name: string;
	width: number;
	height: number;
}

export interface AtlasPlacement {
	name: string;
	page: number;
	x: number;
	y: number;
	w: number;
	h: number;
}

export interface AtlasPage {
	index: number;
	name: string;
	width: number;
	height: number;
	placements: AtlasPlacement[];
}

export const CELL_PAD = 4;
export const MIN_PAGE = 16;

function align4(v: number): number {
	return (v + 3) & ~3;
}

function nextPow2(v: number): number {
	let p = MIN_PAGE;
	while (p < v) {
		p *= 2;
	}
	return p;
}

interface Cell {
	name: string;
	w: number;
	h: number;
}

class PageBuilder {
	readonly index: number;
	width: number;
	height: number;
	private cells: Cell[] = [];
	private placed: { cell: Cell; x: number; y: number }[] = [];

	constructor(index: number, width: number, height: number) {
		this.index = index;
		this.width = width;
		this.height = height;
	}

	get count(): number {
		return this.cells.length;
	}

	/** 尝试放入；不修改状态（失败时回滚） */
	tryAdd(cell: Cell, limit: number): boolean {
		this.cells.push(cell);
		if (this.layout()) {
			return true;
		}
		this.cells.pop();
		// 尝试放大后重排
		while (true) {
			const growW = this.width <= this.height;
			const nw = growW ? this.width * 2 : this.width;
			const nh = growW ? this.height : this.height * 2;
			if (Math.max(nw, nh) > limit) {
				return false;
			}
			const oldW = this.width;
			const oldH = this.height;
			this.width = nw;
			this.height = nh;
			this.cells.push(cell);
			if (this.layout()) {
				return true;
			}
			this.cells.pop();
			this.width = oldW;
			this.height = oldH;
			return false;
		}
	}

	/** 依序尝试不同内边距：4 -> 0（exe 在单图刚好填满页时不留边） */
	private layout(): boolean {
		for (const pad of [CELL_PAD, 0]) {
			if (this.layoutWith(pad)) {
				return true;
			}
		}
		// 失败时保留上次成功的 placed(否则试放新图失败会把已放好的图全部丢失)
		return false;
	}

	private layoutWith(pad: number): boolean {
		const placed: { cell: Cell; x: number; y: number }[] = [];
		let x = 0;
		let y = 0;
		let shelfH = 0;
		for (const cell of this.cells) {
			// DXT5 以 4x4 块为单位：单元格必须 4 对齐，否则相邻图会共用压缩块（画面上会串色）
			const cw = align4(cell.w) + pad;
			const ch = align4(cell.h) + pad;
			if (x + cw > this.width) {
				y += shelfH;
				x = 0;
				shelfH = 0;
			}
			if (cw > this.width || y + ch > this.height) {
				return false;
			}
			placed.push({ cell, x, y });
			x += cw;
			if (ch > shelfH) {
				shelfH = ch;
			}
		}
		this.placed = placed;
		return true;
	}

	finalize(name: string): AtlasPage {
		return {
			index: this.index,
			name,
			width: this.width,
			height: this.height,
			placements: this.placed.map(p => ({
				name: p.cell.name,
				page: this.index,
				x: p.x,
				y: p.y,
				w: p.cell.w,
				h: p.cell.h,
			})),
		};
	}
}

/**
 * @param limit 单页尺寸上限（exe 的 Texture Size Limit，默认 2048）
 */
export function packAtlas(images: AtlasInput[], limit = 2048): AtlasPage[] {
	if (images.length === 0) {
		return [];
	}
	// 货架装箱：按高度降序（同高按宽度降序）能显著提高利用率
	images = [...images].sort((a, b) => (b.height - a.height) || (b.width - a.width));
	let maxW = 0;
	let maxH = 0;
	for (const im of images) {
		maxW = Math.max(maxW, im.width);
		maxH = Math.max(maxH, im.height);
	}
	const pages: PageBuilder[] = [];
	let page = new PageBuilder(0, nextPow2(maxW), nextPow2(maxH));
	pages.push(page);

	for (const im of images) {
		const cell: Cell = { name: im.name, w: im.width, h: im.height };
		let placed = false;
		for (const p of pages) {
			if (p.tryAdd(cell, limit)) {
				placed = true;
				break;
			}
		}
		if (!placed) {
			page = new PageBuilder(pages.length, nextPow2(maxW), nextPow2(maxH));
			if (!page.tryAdd(cell, limit)) {
				throw new Error('texture exceeds size limit: ' + im.name);
			}
			pages.push(page);
		}
	}

	return pages.map((p, i) => p.finalize(`atlas-${i}.tex`));
}
