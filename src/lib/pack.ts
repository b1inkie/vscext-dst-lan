/**
 * 将 mod 目录打包为 zip(供 extrafn 菜单使用)。
 */
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import archiver from 'archiver';
import { logLine, logWarn } from './output';

/**
 * 把 sourcePath 打包为 `${目录名}_${时间戳}.zip`, 放在 sourcePath 内。
 * excludePaths 中的目录及其内容不会进入归档;空目录会被保留。
 * 归档输出文件自身(含同目录下正在写的 zip)永远不会被加入。
 * 返回生成的 zip 路径。
 */
export async function packDirectoryToZip(sourcePath: string, excludePaths: string[]): Promise<string> {
	const dirName = path.basename(sourcePath);
	const now = new Date();
	const pad = (n: number) => String(n).padStart(2, '0');
	const formattedTime = `${now.getFullYear()}-${pad(now.getMonth() + 1)}_${pad(now.getDate())}-${pad(now.getHours())}-${pad(now.getMinutes())}`;
	const zipFilePath = path.join(sourcePath, `${dirName}_${formattedTime}.zip`);

	const output = fs.createWriteStream(zipFilePath);
	const archive = archiver('zip', { zlib: { level: 9 } });
	archive.pipe(output);

	await addDirectoriesToArchive(archive, sourcePath, '', excludePaths, zipFilePath);

	await new Promise<void>((resolve, reject) => {
		output.on('finish', () => {
			logLine(`Successfully created archive: ${zipFilePath}`);
			vscode.window.showInformationMessage(`Successfully created archive: ${zipFilePath}`);
			resolve();
		});
		archive.on('error', (err: Error) => {
			logWarn(`Failed to create archive: ${err.message}`);
			vscode.window.showErrorMessage(`Failed to create archive: ${err.message}`);
			reject(err);
		});
		archive.finalize();
	});
	return zipFilePath;
}

async function addDirectoriesToArchive(archive: archiver.Archiver, dirPath: string, baseDir: string, excludePaths: string[], zipFilePath: string): Promise<void> {
	if (excludePaths.includes(dirPath)) {
		return;
	}
	for (const entry of fs.readdirSync(dirPath, { withFileTypes: true })) {
		const fullPath = path.join(dirPath, entry.name);
		const relativePath = baseDir ? path.join(baseDir, entry.name) : entry.name;

		if (entry.isDirectory()) {
			await addDirectoriesToArchive(archive, fullPath, relativePath, excludePaths, zipFilePath);
			// 保留空目录
			if (fs.readdirSync(fullPath).length === 0) {
				archive.append('', { name: `${relativePath}/` });
			}
		} else if (entry.isFile()) {
			if (excludePaths.includes(fullPath)) {
				continue; // 文件级排除(如根目录下的旧 zip)
			}
			if (path.resolve(fullPath) === path.resolve(zipFilePath)) {
				continue; // 不把输出 zip 自己打进包里
			}
			archive.file(fullPath, { name: relativePath });
		}
	}
}
