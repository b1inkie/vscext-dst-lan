/**
 * 多图打包成图集: 文件夹(名=atlas 名)里的所有 png → 单个 <atlas>.tex + <atlas>.xml。
 *
 * 语义(与主流图集工具一致):
 *  - Element 名 = png 基名(已以 .tex 结尾则不再追加)+ '.tex';
 *  - uv 半像素内缩: u1=(x+0.5)/W, u2=(x+w-0.5)/W,
 *    v1=(H-y-h+0.5)/H(底), v2=(H-y-0.5)/H(顶) —— 与单图路径一致;
 *  - DXT5 + 完整 mip 链 + premultiply alpha。
 *
 * 差异(有意为之, 更安全): 装箱做 4px 对齐 —— DXT5 以 4x4 块压缩,
 * 非 4 对齐的相邻元素会共用压缩块导致边缘串色。
 * 页尺寸为 2 的幂, 装不下自动翻倍, 超过上限报错。
 */
import * as fs from 'fs';
import * as path from 'path';
import sharp from 'sharp';
import { encodeKtex, premultiplyRgba, flipYRgba } from './ktex';

interface PlacedRect {
	name: string;
	x: number;
	y: number;
	w: number;
	h: number;
}

interface FreeRect {
	x: number;
	y: number;
	w: number;
	h: number;
}

function nextPow2(v: number): number {
	let p = 1;
	while (p < v) {
		p <<= 1;
	}
	return p;
}

const align4 = (v: number): number => (v + 3) & ~3;

/** MaxRects: Best Short Side Fit 放置一个矩形; 失败返回 null */
function insertMaxRects(free: FreeRect[], w: number, h: number): { x: number; y: number } | null {
	let best: { x: number; y: number } | null = null;
	let bestShort = Infinity;
	let bestLong = Infinity;
	for (const f of free) {
		if (w <= f.w && h <= f.h) {
			const leftoverH = Math.abs(f.w - w);
			const leftoverV = Math.abs(f.h - h);
			const shortSide = Math.min(leftoverH, leftoverV);
			const longSide = Math.max(leftoverH, leftoverV);
			if (shortSide < bestShort || (shortSide === bestShort && longSide < bestLong)) {
				best = { x: f.x, y: f.y };
				bestShort = shortSide;
				bestLong = longSide;
			}
		}
	}
	return best;
}

/** 标准 MaxRects SplitFreeNode: 对每个与 used 相交的 free 矩形分裂出剩余区域 */
function splitFreeRects(free: FreeRect[], used: { x: number; y: number; w: number; h: number }): void {
	const additions: FreeRect[] = [];
	for (let i = free.length - 1; i >= 0; i--) {
		const f = free[i];
		const overlap = used.x < f.x + f.w && used.x + used.w > f.x && used.y < f.y + f.h && used.y + used.h > f.y;
		if (!overlap) {
			continue;
		}
		// 垂直切(used 横向穿过 f)
		if (used.x < f.x + f.w && used.x + used.w > f.x) {
			if (used.y > f.y && used.y < f.y + f.h) {
				additions.push({ x: f.x, y: f.y, w: f.w, h: used.y - f.y });
			}
			if (used.y + used.h < f.y + f.h) {
				additions.push({ x: f.x, y: used.y + used.h, w: f.w, h: f.y + f.h - (used.y + used.h) });
			}
		}
		// 水平切(used 纵向穿过 f)
		if (used.y < f.y + f.h && used.y + used.h > f.y) {
			if (used.x > f.x && used.x < f.x + f.w) {
				additions.push({ x: f.x, y: f.y, w: used.x - f.x, h: f.h });
			}
			if (used.x + used.w < f.x + f.w) {
				additions.push({ x: used.x + used.w, y: f.y, w: f.x + f.w - (used.x + used.w), h: f.h });
			}
		}
		free.splice(i, 1);
	}
	free.push(...additions);
	pruneFreeList(free);
}

/** 移除被其他 free 矩形完整包含的冗余项 */
function pruneFreeList(free: FreeRect[]): void {
	for (let i = 0; i < free.length; i++) {
		for (let j = i + 1; j < free.length; j++) {
			const a = free[i];
			const b = free[j];
			if (a.x >= b.x && a.y >= b.y && a.x + a.w <= b.x + b.w && a.y + a.h <= b.y + b.h) {
				free.splice(i, 1);
				i--;
				break;
			}
			if (b.x >= a.x && b.y >= a.y && b.x + b.w <= a.x + a.w && b.y + b.h <= a.y + a.h) {
				free.splice(j, 1);
				j--;
			}
		}
	}
}

/** 尝试用 MaxRects 把 rects 全部放进 size×size; 失败返回 null */
function tryPack(rects: Array<{ name: string; w: number; h: number }>, size: number): PlacedRect[] | null {
	const free: FreeRect[] = [{ x: 0, y: 0, w: size, h: size }];
	const placed: PlacedRect[] = [];
	for (const r of rects) {
		const cell = { w: align4(r.w), h: align4(r.h) };
		const pos = insertMaxRects(free, cell.w, cell.h);
		if (!pos) {
			return null;
		}
		const used = { x: pos.x, y: pos.y, w: cell.w, h: cell.h };
		splitFreeRects(free, used);
		placed.push({ name: r.name, x: pos.x, y: pos.y, w: r.w, h: r.h });
	}
	return placed;
}

export interface AtlasPackResult {
	texPath: string;
	xmlPath: string;
	width: number;
	height: number;
	elements: number;
}

/** element 名: foo.png -> foo.tex; foo.tex.png -> foo.tex */
export function elementNameOf(pngBase: string): string {
	return pngBase.endsWith('.tex') ? pngBase : `${pngBase}.tex`;
}

/**
 * 把 inputDir 里所有 png(仅第一层, 子目录忽略)打包成图集。
 * 输出 <inputDir 的文件夹名>.tex/.xml 到 outDir。
 */
export async function packFolderToAtlas(inputDir: string, outDir: string, sizeLimit = 2048): Promise<AtlasPackResult> {
	const pngs = fs.readdirSync(inputDir).filter(f => /\.png$/i.test(f)).sort();
	if (pngs.length === 0) {
		throw new Error(`no png in ${inputDir}`);
	}

	const items: Array<{ name: string; w: number; h: number; rgba: Buffer }> = [];
	for (const f of pngs) {
		const { data, info } = await sharp(path.join(inputDir, f)).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
		items.push({ name: path.basename(f, '.png'), w: info.width, h: info.height, rgba: data });
	}

	// 按最大边降序放置(装箱惯例)
	items.sort((a, b) => (Math.max(b.w, b.h) - Math.max(a.w, a.h)) || (b.w * b.h - a.w * a.h));

	const totalArea = items.reduce((t, it) => t + it.w * it.h, 0);
	let size = nextPow2(Math.ceil(Math.sqrt(totalArea)));
	size = Math.max(size, nextPow2(Math.max(...items.map(i => Math.max(i.w, i.h)))));
	let placed: PlacedRect[] | null = null;
	while (size <= sizeLimit) {
		placed = tryPack(items, size);
		if (placed) {
			break;
		}
		size <<= 1;
	}
	if (!placed) {
		throw new Error(`atlas exceeds size limit ${sizeLimit}: ${inputDir}`);
	}

	// 合成画布
	const canvas = Buffer.alloc(size * size * 4);
	for (const p of placed) {
		const item = items.find(i => i.name === p.name)!;
		for (let y = 0; y < item.h; y++) {
			item.rgba.copy(canvas, ((p.y + y) * size + p.x) * 4, y * item.w * 4, (y + 1) * item.w * 4);
		}
	}

	fs.mkdirSync(outDir, { recursive: true });
	const atlasName = path.basename(path.resolve(inputDir));
	const texPath = path.join(outDir, `${atlasName}.tex`);
	const xmlPath = path.join(outDir, `${atlasName}.xml`);
	// 整页上下翻转 + 预乘 alpha(与外部工具一致)
	fs.writeFileSync(texPath, encodeKtex(premultiplyRgba(flipYRgba(canvas, size, size)), size, size));

	const parts = placed.map(p => {
		const u1 = (p.x + 0.5) / size;
		const u2 = (p.x + p.w - 0.5) / size;
		const v1 = (size - p.y - p.h + 0.5) / size;
		const v2 = (size - p.y - 0.5) / size;
		return `<Element name="${elementNameOf(p.name)}" u1="${u1}" u2="${u2}" v1="${v1}" v2="${v2}" />`;
	});
	fs.writeFileSync(xmlPath, `<Atlas><Texture filename="${atlasName}.tex" /><Elements>${parts.join('')}</Elements></Atlas>`, 'utf8');

	return { texPath, xmlPath, width: size, height: size, elements: placed.length };
}
