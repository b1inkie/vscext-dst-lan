/**
 * tex/xml 解包入口: .tex → png(整图); 图集(.xml+.tex) → 每元素一个 png。
 *
 * 元素裁切按图集 key 的 uv: x0 = u1*W - 0.5, w = (u2-u1)*W + 1(半像素内缩的逆运算),
 * 与打包端 scatter.ts/atlasPack.ts 的写入公式互逆。
 */
import * as fs from 'fs';
import * as path from 'path';
import sharp from 'sharp';
import { decodeKtexMip } from './ktexDecode';

export interface AtlasElement {
	name: string;
	x: number;
	y: number;
	w: number;
	h: number;
}

/** 解析图集 key xml 的 Element(name,u1,u2,v1,v2) → 像素矩形 */
export function parseAtlasXml(xml: string, pageWidth: number, pageHeight: number): { texture: string; elements: AtlasElement[] } {
	const texMatch = xml.match(/<Texture\s+filename="([^"]+)"/);
	const elements: AtlasElement[] = [];
	for (const m of xml.matchAll(/<Element\s+name="([^"]+)"\s+u1="([\d.]+)"\s+u2="([\d.]+)"\s+v1="([\d.]+)"\s+v2="([\d.]+)"\s*\/>/g)) {
		const [, name, u1s, u2s, v1s, v2s] = m;
		const u1 = parseFloat(u1s);
		const u2 = parseFloat(u2s);
		const v1 = parseFloat(v1s);
		const v2 = parseFloat(v2s);
		// 打包公式逆运算: u1=(x+0.5)/W, u2=(x+w-0.5)/W, v1=(H-y-h+0.5)/H, v2=(H-y-0.5)/H
		const x = Math.round(u1 * pageWidth - 0.5);
		const w = Math.round(u2 * pageWidth + 0.5) - x;
		const yBottom = Math.round((1 - v2) * pageHeight - 0.5);
		const h = Math.round((1 - v1) * pageHeight + 0.5) - yBottom;
		elements.push({ name, x, y: yBottom, w, h });
	}
	return { texture: texMatch ? texMatch[1] : '', elements };
}

export interface UnpackResult {
	/** 输出的 png 路径列表 */
	pngs: string[];
	/** tex 尺寸 */
	width: number;
	height: number;
}

/**
 * 解包单个 .tex → 同目录 <name>.png(整图)。
 */
export async function unpackTexToPng(texPath: string, outPng?: string): Promise<UnpackResult> {
	const buf = fs.readFileSync(texPath);
	const { rgba, width, height } = decodeKtexMip(buf, 0);
	const out = outPng ?? texPath.replace(/\.tex$/i, '.png');
	fs.mkdirSync(path.dirname(out), { recursive: true });
	await sharp(rgba, { raw: { width, height, channels: 4 } }).png().toFile(out);
	return { pngs: [out], width, height };
}

/**
 * 解包图集: key xml + 同名 tex → 每元素一个 png(输出到 outDir)。
 * 元素名以 .tex 结尾时输出文件名去掉该后缀(与主流工具一致)。
 */
export async function unpackAtlas(xmlPath: string, outDir: string): Promise<UnpackResult> {
	const xml = fs.readFileSync(xmlPath, 'utf8');
	const texPath = path.join(path.dirname(xmlPath), path.basename(xmlPath, '.xml') + '.tex');
	if (!fs.existsSync(texPath)) {
		throw new Error(`atlas tex not found next to xml: ${texPath}`);
	}
	const buf = fs.readFileSync(texPath);
	const { rgba, width, height } = decodeKtexMip(buf, 0);
	const { elements } = parseAtlasXml(xml, width, height);
	fs.mkdirSync(outDir, { recursive: true });

	const page = await sharp(rgba, { raw: { width, height, channels: 4 } }).png().toBuffer();
	const pngs: string[] = [];
	for (const el of elements) {
		const w = Math.max(1, Math.min(el.w, width - el.x));
		const h = Math.max(1, Math.min(el.h, height - el.y));
		const name = el.name.replace(/\.tex$/i, '');
		const out = path.join(outDir, `${name}.png`);
		await sharp(page).extract({ left: el.x, top: el.y, width: w, height: h }).png().toFile(out);
		pngs.push(out);
	}
	return { pngs, width, height };
}

/**
 * 解包图集(自动输出形态): 多元素 → 同名文件夹 <xml名>/;
 * 单元素(散图) → png 直接生成在 xml 所在目录, 不建文件夹。
 */
export async function unpackAtlasAuto(xmlPath: string): Promise<UnpackResult> {
	const xml = fs.readFileSync(xmlPath, 'utf8');
	const texPath = path.join(path.dirname(xmlPath), path.basename(xmlPath, '.xml') + '.tex');
	if (!fs.existsSync(texPath)) {
		throw new Error(`atlas tex not found next to xml: ${texPath}`);
	}
	const { rgba, width, height } = decodeKtexMip(fs.readFileSync(texPath), 0);
	const single = parseAtlasXml(xml, width, height).elements.length === 1;
	const outDir = single ? path.dirname(xmlPath) : xmlPath.replace(/\.xml$/i, '');
	return unpackAtlas(xmlPath, outDir);
}
