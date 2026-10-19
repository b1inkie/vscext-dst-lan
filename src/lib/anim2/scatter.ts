/**
 * 散装图片打包: 单张 png → .tex(DXT5) + .xml(atlas 描述)。
 *
 * 输出格式(与主流打包工具一致):
 *  - 非 2 次幂图片补齐到 2 次幂, 内容按原尺寸贴**左上角**, 右/下留透明
 *    (20x20 → 32x32, (2,2) 内容像素位置不变);
 *  - 完整 mipmap 链(log2(max)+1 级), DXT5(BC3) 压缩;
 *  - xml: <Atlas><Texture/><Elements><Element name u1 u2 v1 v2/></Elements></Atlas>,
 *    UV 为内容区**半像素内缩**: u1=0.5/W, u2=(cw-0.5)/W,
 *    v1=(H-ch+0.5)/H(下), v2=(H-0.5)/H(上), 半像素内缩防边缘采样渗色。
 */
import * as fs from 'fs';
import * as path from 'path';
import sharp from 'sharp';
import { encodeKtex, premultiplyRgba, flipYRgba } from './ktex';

export interface ScatterTexResult {
	texPath: string;
	xmlPath: string;
	/** 补 2 幂后的实际纹理尺寸(内容贴左上) */
	textureWidth: number;
	textureHeight: number;
}

function nextPow2(v: number): number {
	let p = 1;
	while (p < v) {
		p <<= 1;
	}
	return p;
}

/** RGBA 数据贴到 pw×ph 左上角(其余透明) */
function padTopLeft(rgba: Buffer, w: number, h: number, pw: number, ph: number): Buffer {
	if (w === pw && h === ph) {
		return rgba;
	}
	const out = Buffer.alloc(pw * ph * 4);
	for (let y = 0; y < h; y++) {
		rgba.copy(out, y * pw * 4, y * w * 4, (y + 1) * w * 4);
	}
	return out;
}

/**
 * 打包单张 png。
 * @param pngPath 源图
 * @param outDir  输出目录(.tex/.xml 与源图同名)
 * @param force   已存在同名 .tex 时是否重打
 */
export async function packPngToTex(pngPath: string, outDir: string, force = false): Promise<ScatterTexResult | null> {
	const base = path.basename(pngPath, '.png');
	const texPath = path.join(outDir, `${base}.tex`);
	const xmlPath = path.join(outDir, `${base}.xml`);
	if (!force && fs.existsSync(texPath)) {
		return null; // 增量: 已有 tex 跳过(与外部工具路径一致)
	}

	fs.mkdirSync(outDir, { recursive: true });

	const { data, info } = await sharp(pngPath).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
	const w = info.width;
	const h = info.height;
	const pw = nextPow2(w);
	const ph = nextPow2(h);
	const padded = padTopLeft(data, w, h, pw, ph);

	// 整页上下翻转(tex 按 v=底存储) + 预乘 alpha
	fs.writeFileSync(texPath, encodeKtex(premultiplyRgba(flipYRgba(padded, pw, ph)), pw, ph));

	const u1 = 0.5 / pw;
	const u2 = (w - 0.5) / pw;
	const v1 = (ph - h + 0.5) / ph;
	const v2 = (ph - 0.5) / ph;
	const xml = `<Atlas><Texture filename="${base}.tex" /><Elements><Element name="${base}.tex" u1="${u1}" u2="${u2}" v1="${v1}" v2="${v2}" /></Elements></Atlas>`;
	fs.writeFileSync(xmlPath, xml, 'utf8');

	return { texPath, xmlPath, textureWidth: pw, textureHeight: ph };
}
