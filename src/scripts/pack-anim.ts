/** CLI: dst-lan 内置动画打包器（scml -> anim zip）。用法： node out/scripts/pack-anim.js <in.scml> <out.zip> */
import * as path from 'path';
import { packScmlToZip } from '../lib/anim2/pack';

async function main(): Promise<void> {
	const [inPath, outPath] = process.argv.slice(2);
	if (!inPath || !outPath) {
		console.error('usage: pack-anim <in.scml> <out.zip> [sizeLimit]');
		process.exitCode = 2;
		return;
	}
	const limit = process.argv[4] ? parseInt(process.argv[4], 10) : 2048;
	const result = await packScmlToZip(path.resolve(inPath), path.resolve(outPath), { sizeLimit: limit });
	console.log(JSON.stringify({
		out: path.resolve(outPath),
		buildName: result.buildName,
		pages: result.pages,
		symbols: result.symbols,
		frames: result.frames,
		anims: result.anims,
		warnings: result.warnings,
	}));
}

void main();
