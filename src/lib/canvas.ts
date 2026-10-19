/**
 * 画布扩/裁操作(sharp)与 .scml XML 后处理(xml2js)。
 *
 * 画布扩展/裁切算法(与社区常用 Scml resizer 工具行为一致):
 *  - 扩展: 目标画布为正方形 big = min(int(max(w,h)*scale), maxSize), 原图居中贴入;
 *          新 pivot = (px*w + (big-w)/2) / big(y 轴因上下对称 padding 无需翻转)
 *  - 裁切: 按 alpha>0 扫描内容边界(t/b/l/r), 四周保留 edge 像素透明边;
 *          新 pivot_x = (px*w - l2)/newW, pivot_y = (py*h - b2)/newH
 *          (scml pivot_y 自底向上, 等价于参考实现的 (1-py) 顶部坐标换算)
 *  - scml 中引用但磁盘缺失的图片: 自动补一张 1x1 透明图占位, XML 属性不动
 *  - 全透明图片: 缩为 1x1, pivot 置 (0.5, 0.5)
 */
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import sharp from 'sharp';
import * as xml2js from 'xml2js';
import { logLine, logWarn } from './output';

/** 默认扩展倍数(参考工具 SCALE) */
export const DEFAULT_EXPAND_SCALE = 2;
/** 默认画布尺寸上限(参考工具 MAX_SIZE) */
export const DEFAULT_MAX_SIZE = 1024;

export interface CanvasResult {
	/** 新 pivot(scml 归一化坐标) */
	px: number;
	py: number;
	/** 新尺寸 */
	width: number;
	height: number;
}

/** 透明 1x1 png(补图/全透明占位) */
const PNG_1X1_TRANSPARENT = Buffer.from(
	'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
	'base64',
);

async function write1x1Transparent(filePath: string): Promise<void> {
	await fs.promises.mkdir(path.dirname(filePath), { recursive: true });
	await fs.promises.writeFile(filePath, PNG_1X1_TRANSPARENT);
}

/**
 * 扩展单张图片画布: 目标正方形 big = min(int(max(w,h)*scale), maxSize), 原图居中。
 * 返回新 pivot 与新尺寸; 供调用方回写 scml。
 */
export async function expandCanvas(inputPath: string, px: number, py: number, scale: number, maxSize: number): Promise<CanvasResult> {
	const metadata = await sharp(inputPath).metadata();
	if (!metadata.width || !metadata.height) {
		throw new Error(`Image metadata does not contain width or height: ${inputPath}`);
	}
	const w = metadata.width;
	const h = metadata.height;

	let big = Math.trunc(Math.max(w, h) * scale);
	big = Math.min(big, maxSize);

	const tempPath = `${inputPath}.tmp`;
	await sharp(inputPath)
		.extend({
			left: Math.trunc((big - w) / 2),
			right: Math.trunc((big - w) / 2),
			top: Math.trunc((big - h) / 2),
			bottom: Math.trunc((big - h) / 2),
			background: { r: 0, g: 0, b: 0, alpha: 0 },
		})
		.toFile(tempPath);
	await fs.promises.unlink(inputPath);
	await fs.promises.rename(tempPath, inputPath);

	// pivot 换算使用未取整的 pad 值(与参考实现一致)
	const newPx = (px * w + (big - w) / 2) / big;
	const newPy = (py * h + (big - h) / 2) / big;
	return { px: newPx, py: newPy, width: big, height: big };
}

/** 裁切扫描结果: l/t 为内容边界坐标, r/b 为底部/右侧的透明量 */
interface ContentBounds {
	l: number;
	t: number;
	r: number;
	b: number;
}

/** 按 alpha>0 扫描内容边界(与参考实现逐像素扫描一致) */
async function scanContentBounds(inputPath: string, w: number, h: number): Promise<ContentBounds> {
	const { data } = await sharp(inputPath).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
	const channels = data.length / (w * h);
	const alphaAt = (x: number, y: number): number => data[(y * w + x) * channels + (channels - 1)];

	let l = -1, r = -1, t = -1, b = -1;
	// 自上而下找第一行内容
	for (let y = 0; y < h && t === -1; y++) {
		for (let x = 0; x < w; x++) {
			if (alphaAt(x, y) > 0) { t = y; break; }
		}
	}
	// 自下而上统计底部透明行数
	for (let y = 0; y < h && b === -1; y++) {
		for (let x = 0; x < w; x++) {
			if (alphaAt(x, h - 1 - y) > 0) { b = y; break; }
		}
	}
	// 自左向右找第一列内容
	for (let x = 0; x < w && l === -1; x++) {
		for (let y = 0; y < h; y++) {
			if (alphaAt(x, y) > 0) { l = x; break; }
		}
	}
	// 自右向左统计右侧透明列数
	for (let x = 0; x < w && r === -1; x++) {
		for (let y = 0; y < h; y++) {
			if (alphaAt(w - 1 - x, y) > 0) { r = x; break; }
		}
	}
	return { l, r, b, t };
}

/**
 * 裁切单张图片画布: 去掉四周透明边, 保留 edge 像素透明边距。
 * 全透明图片缩为 1x1, pivot (0.5, 0.5)。
 */
export async function cropCanvas(inputPath: string, px: number, py: number, edge: number): Promise<CanvasResult> {
	const metadata = await sharp(inputPath).metadata();
	if (!metadata.width || !metadata.height) {
		throw new Error(`Image metadata does not contain width or height: ${inputPath}`);
	}
	const w = metadata.width;
	const h = metadata.height;

	const { l, r, b, t } = await scanContentBounds(inputPath, w, h);
	if (l === -1 || t === -1 || r === -1 || b === -1 || l + r >= w || t + b >= h) {
		// 全透明
		await write1x1Transparent(inputPath);
		return { px: 0.5, py: 0.5, width: 1, height: 1 };
	}

	// 四周保留 edge 像素(不越界)
	const l2 = Math.max(0, l - edge);
	const t2 = Math.max(0, t - edge);
	const r2 = Math.max(0, r - edge);
	const b2 = Math.max(0, b - edge);

	const newW = w - l2 - r2;
	const newH = h - t2 - b2;

	const tempPath = `${inputPath}.tmp`;
	await sharp(inputPath)
		.extract({ left: l2, top: t2, width: newW, height: newH })
		.toFile(tempPath);
	await fs.promises.unlink(inputPath);
	await fs.promises.rename(tempPath, inputPath);

	// scml pivot_y 自底向上: 底部被裁掉 b2 像素
	const newPx = (px * w - l2) / newW;
	const newPy = (py * h - b2) / newH;
	return { px: newPx, py: newPy, width: newW, height: newH };
}

interface ScmlFileAttrs {
	$: Record<string, string>;
}

interface ScmlFolder {
	file?: ScmlFileAttrs[];
}

interface ScmlRoot {
	spriter_data?: { folder?: ScmlFolder[] };
}

/** 弹出文件选择框让用户选一个 .scml 文件 */
export async function selectScmlFile(): Promise<string | undefined> {
	const fileUri = await vscode.window.showOpenDialog({
		canSelectMany: false,
		filters: { 'SCML Files': ['scml'] },
		title: vscode.l10n.t('src.extension.extra.op.select_scml_file'),
	});
	return fileUri && fileUri.length > 0 ? fileUri[0].fsPath : undefined;
}

/**
 * 对 scml 引用的所有图片执行扩/裁, 并同步回写 XML 的
 * pivot_x / pivot_y / width / height。
 * 缺失图片自动补 1x1 透明占位(XML 属性不动)。
 */
export async function processScml(
	scmlPath: string,
	op: 'expand' | 'crop',
	options: { scale?: number; maxSize?: number; edge?: number },
): Promise<void> {
	const scale = options.scale ?? DEFAULT_EXPAND_SCALE;
	const maxSize = options.maxSize ?? DEFAULT_MAX_SIZE;
	const edge = options.edge ?? 0;

	const dirname = path.dirname(scmlPath);
	const xmlData = await fs.promises.readFile(scmlPath, 'utf8');
	const parser = new xml2js.Parser();

	await new Promise<void>((resolve, reject) => {
		parser.parseString(xmlData, (err: unknown, result: ScmlRoot) => {
			if (err) {
				reject(err instanceof Error ? err : new Error(String(err)));
				return;
			}

			(async () => {
				let processed = 0;
				let patched = 0;
				const folders = result?.spriter_data?.folder ?? [];
				for (const folder of folders) {
					for (const file of folder.file ?? []) {
						const relPath = file.$.name;
						const px = parseFloat(file.$.pivot_x);
						const py = parseFloat(file.$.pivot_y);
						if (!relPath || Number.isNaN(px) || Number.isNaN(py)) {
							continue;
						}
						const fullpath = path.join(dirname, relPath);
						processed++;

						if (!fs.existsSync(fullpath)) {
							// 参考实现: 缺图补一张, XML 不动
							logWarn(`image not found, patch 1x1 placeholder: ${relPath}`);
							await write1x1Transparent(fullpath);
							patched++;
							continue;
						}

						try {
							const res = op === 'expand'
								? await expandCanvas(fullpath, px, py, scale, maxSize)
								: await cropCanvas(fullpath, px, py, edge);
							file.$.pivot_x = String(res.px);
							file.$.pivot_y = String(res.py);
							file.$.width = String(res.width);
							file.$.height = String(res.height);
						} catch (error) {
							logWarn(`failed to ${op} ${relPath}: ${String(error)}`);
						}
					}
				}

				const builder = new xml2js.Builder();
				const xmlString = builder.buildObject(result);
				await fs.promises.writeFile(scmlPath, xmlString, 'utf8');
				logLine(`${op} done: ${processed} file entries, ${patched} placeholders patched.`);
				resolve();
			})().catch(reject);
		});
	});
}

/** 兼容旧入口: 扩展画布(全部 scml 引用图片) */
export async function opExpandAll(scmlPath: string, scale = DEFAULT_EXPAND_SCALE, maxSize = DEFAULT_MAX_SIZE): Promise<void> {
	await processScml(scmlPath, 'expand', { scale, maxSize });
}

/** 兼容旧入口: 裁切画布(全部 scml 引用图片) */
export async function opCropAll(scmlPath: string, edge = 0): Promise<void> {
	await processScml(scmlPath, 'crop', { edge });
}
