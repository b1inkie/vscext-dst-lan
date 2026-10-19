/**
 * 打包流水线：SCML 工程(.scml + png) → anim zip(anim.bin + build.bin + atlas-N.tex)
 *
 * 内置实现, 不依赖任何外部打包工具。输出为饥荒可加载的 anim zip 格式。
 */
import * as fs from 'fs';
import * as path from 'path';
import sharp from 'sharp';

import { kleiHash } from './bins';
import { parseScml, ScmlDoc, ScmlFile, ScmlFolder } from './scml';
import { getImageRegions, Rect } from './regions';
import { packAtlas } from './atlas';
import { encodeKtex, premultiplyRgba } from './ktex';
import { BuildFrameInput, BuildSymbol, writeBuildBin } from './build';
import { sampleAnimations, writeAnimBin, baseLayerName } from './anim';
import { createZip } from './zip';

export interface PackOptions {
	/** 单页图集尺寸上限，exe 默认 2048 */
	sizeLimit?: number;
	/** 图集单元格内边距（实测 4） */
	pad?: number;
}

export interface PackResult {
	files: Map<string, Buffer>;
	buildName: string;
	pages: number;
	symbols: number;
	frames: number;
	anims: number;
	warnings: string[];
}

interface LoadedImage {
	key: string;
	name: string;
	width: number;
	height: number;
	rgba: Buffer;
	regions: { opaque: Rect[]; alpha: Rect[] };
	/** 自动裁剪后的包围盒（所有四边形并集）；无内容时为 null */
	trim: Rect | null;
	contentHash: string;
}

function unionRect(rects: Rect[]): Rect | null {
	if (rects.length === 0) {
		return null;
	}
	let x0 = Infinity;
	let y0 = Infinity;
	let x1 = -Infinity;
	let y1 = -Infinity;
	for (const r of rects) {
		x0 = Math.min(x0, r.x);
		y0 = Math.min(y0, r.y);
		x1 = Math.max(x1, r.x + r.w);
		y1 = Math.max(y1, r.y + r.h);
	}
	return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

async function loadRgba(file: string): Promise<{ data: Buffer; width: number; height: number }> {
	const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
	return { data, width: info.width, height: info.height };
}

function resolveImagePath(scmlDir: string, buildName: string, file: ScmlFile): string {
	let rel = file.name.replace(/\\/g, '/');
	rel = rel.replace(/%\(prefab\)s/g, buildName);
	return path.join(scmlDir, rel);
}

export async function packScml(scmlPath: string, options: PackOptions = {}): Promise<PackResult> {
	const warnings: string[] = [];
	const sizeLimit = options.sizeLimit ?? 2048;
	const scmlDir = path.dirname(scmlPath);
	const buildName = path.basename(scmlPath, path.extname(scmlPath));
	const doc: ScmlDoc = await parseScml(fs.readFileSync(scmlPath, 'utf8'));

	// ---- 1. 载入图片（按 folder/file 唯一化，同一路径只读一次） ----
	const images = new Map<string, LoadedImage>();
	const imageKeyOf = (folder: ScmlFolder, file: ScmlFile): string => `${folder.name}/${file.id}`;

	for (const folder of doc.folders) {
		for (const file of folder.files) {
			const abs = resolveImagePath(scmlDir, buildName, file);
			const key = imageKeyOf(folder, file);
			const cached = images.get(key);
			if (cached) {
				continue;
			}
			if (!fs.existsSync(abs)) {
				warnings.push(`缺少图片: ${file.name}`);
				continue;
			}
			const { data, width, height } = await loadRgba(abs);
			const regions = getImageRegions(data, width, height);
			const quads = [...regions.opaque, ...regions.alpha];
			images.set(key, {
				key,
				name: key,
				width,
				height,
				rgba: data,
				regions,
				trim: unionRect(quads),
				contentHash: `${width}x${height}:${hashBuffer(data)}`,
			});
		}
	}

	// ---- 2. 图集装箱（同一路径的图片只占一个单元格） ----
	// 自动裁剪：只把非透明区域的包围盒放进图集（exe 同款行为，省掉大量空白）
	const packInputs = [...images.values()]
		.filter(im => im.trim)
		.map(im => ({ name: im.key, width: (im.trim as Rect).w, height: (im.trim as Rect).h }));
	const pages = packAtlas(packInputs, sizeLimit);



	const placementOf = new Map<string, { page: number; x: number; y: number; w: number; h: number }>();
	for (const page of pages) {
		for (const p of page.placements) {
			placementOf.set(p.name, p);
		}
	}

	// ---- 3. 合成画布 + KTEX ----
	const pageCanvases: Buffer[] = [];
	for (const page of pages) {
		const canvas = Buffer.alloc(page.width * page.height * 4);
		for (const p of page.placements) {
			const im = images.get(p.name);
			if (!im || !im.trim) {
				continue;
			}
			const trim = im.trim;
			// 只把裁剪区域内的像素贴进去
			for (let y = 0; y < trim.h; y++) {
				const srcY = Math.min(im.height - 1, trim.y + y);
				const src = (srcY * im.width + trim.x) * 4;
				const dst = ((p.y + y) * page.width + p.x) * 4;
				im.rgba.copy(canvas, dst, src, src + trim.w * 4);
			}
		}
		// DST 的 KTEX 是「整页上下翻转」存储的：采样 v 对应的原始行是 (pageH-1) - atlasY。
		// 因此编码前把整页翻一次（对拍 --zip2scml 的输出方向确认）。
		const flipped = Buffer.alloc(canvas.length);
		const rowBytes = page.width * 4;
		for (let y = 0; y < page.height; y++) {
			canvas.copy(flipped, y * rowBytes, (page.height - 1 - y) * rowBytes, (page.height - y) * rowBytes);
		}
		pageCanvases.push(premultiplyRgba(flipped));
	}

	// ---- 4. build.bin：symbol / frame / quad ----
	const symbols: BuildSymbol[] = [];
	const quadCorners = new Map<string, [number, number][]>();

	for (const folder of doc.folders) {
		const frames: BuildFrameInput[] = [];
		let prevHash: string | undefined;
		for (const file of folder.files) {
			const im = images.get(imageKeyOf(folder, file));
			if (!im) {
				continue;
			}
			// 全透明图片没有内容：仍然要输出这一帧（nv=0），只是不占图集
			const placement = placementOf.get(im.key);
			const page = placement ? pages[placement.page] : undefined;
			const px = file.pivotX;
			const py = file.pivotY;
			// 注意：几何一律以**实际 PNG 尺寸**为准（实测 exe 如此，scml 里声明的
			// width/height 经常与实际图片不一致，例如 scml=100x100 而 png=300x300）
			const iw = im.width;
			const ih = im.height;
			const frameX = iw / 2 - px * iw;
			const frameY = py * ih - ih / 2;

			const quads = !placement || !page || !im.trim ? [] : [...im.regions.opaque, ...im.regions.alpha].map(rect => {
				const pos: Rect = {
					// x 相对 pivotX，y 相对 (1-pivotY) —— 实测 exe 的 y 方向是"从下往上"量的
					x: rect.x - px * iw,
					y: rect.y - (1 - py) * ih,
					w: rect.w,
					h: rect.h,
				};
				const uv = {
					u0: (placement.x + (rect.x - im.trim!.x)) / page.width,
					u1: (placement.x + (rect.x - im.trim!.x) + rect.w) / page.width,
					v0: 1 - (placement.y + (rect.y - im.trim!.y) + rect.h) / page.height,
					v1: 1 - (placement.y + (rect.y - im.trim!.y)) / page.height,
				};
				return { pos, uv, page: placement.page };
			});

			// anim 的包围盒用的是真实四边形角点（不是整图矩形）——对拍确认
			const corners: [number, number][] = [];
			for (const q of quads) {
				corners.push([q.pos.x, q.pos.y]);
				corners.push([q.pos.x + q.pos.w, q.pos.y]);
				corners.push([q.pos.x, q.pos.y + q.pos.h]);
				corners.push([q.pos.x + q.pos.w, q.pos.y + q.pos.h]);
			}
			quadCorners.set(`${folder.name}/${file.id}`, corners);

			// 连续「完全相同」的帧合并为 duration（内容 + 尺寸 + pivot 偏移都要一致，
			// 实测 exe 就是这么去重的：foot 的 8 张同图但 pivot 不同 -> 不合并）
			const dedupKey = `${im.contentHash}|${iw}x${ih}|${frameX}|${frameY}`;
			if (prevHash === dedupKey && frames.length > 0) {
				frames[frames.length - 1].duration += 1;
				continue;
			}
			prevHash = dedupKey;

			frames.push({
				frameNum: file.id,
				duration: 1,
				x: frameX,
				y: frameY,
				w: iw,
				h: ih,
				quads,
			});
		}
		symbols.push({ name: folder.name, hash: kleiHash(folder.name), frames });
	}

	// ---- 5. anim.bin ----
	const anims = sampleAnimations(doc, (folderName, fileId) => quadCorners.get(`${folderName}/${fileId}`) ?? []);

	// ---- 6. 名字表（build.bin: symbol；anim.bin: bank + symbol + layer） ----
	const buildNames = new Map<number, string>();
	for (const s of symbols) {
		buildNames.set(s.hash, s.name);
	}
	const animNames = new Map<number, string>(buildNames);
	for (const entity of doc.entities) {
		animNames.set(kleiHash(entity.name), entity.name);
		for (const anim of entity.animations) {
			for (const tl of anim.timelines.values()) {
				const base = baseLayerName(tl.name);
				animNames.set(kleiHash(base), base);
			}
		}
	}

	// ---- 7. 输出 ----
	const files = new Map<string, Buffer>();
	files.set('anim.bin', writeAnimBin(anims, animNames));
	files.set('build.bin', writeBuildBin(buildName, symbols, pages.map(p => p.name), buildNames));
	for (let i = 0; i < pages.length; i++) {
		files.set(pages[i].name, encodeKtex(pageCanvases[i], pages[i].width, pages[i].height));
	}

	return {
		files,
		buildName,
		pages: pages.length,
		symbols: symbols.length,
		frames: symbols.reduce((a, s) => a + s.frames.length, 0),
		anims: anims.length,
		warnings,
	};
}

/** 打包并写出 zip */
export async function packScmlToZip(scmlPath: string, zipPath: string, options: PackOptions = {}): Promise<PackResult> {
	const result = await packScml(scmlPath, options);
	const order = ['anim.bin', 'build.bin', ...[...result.files.keys()].filter(k => k.endsWith('.tex'))];
	const entries = order.filter(k => result.files.has(k)).map(k => ({ name: k, data: result.files.get(k) as Buffer }));
	fs.writeFileSync(zipPath, createZip(entries));
	return result;
}

function hashBuffer(buf: Buffer): number {
	let h = 2166136261;
	for (let i = 0; i < buf.length; i++) {
		h ^= buf[i];
		h = Math.imul(h, 16777619) >>> 0;
	}
	return h >>> 0;
}
