/**
 * 文件系统工具集(全部为异步实现, 带基础容错)。
 */
import * as fs from 'fs';
import * as path from 'path';
import { logWarn } from './output';

/** 路径是否存在 */
export async function pathExists(target: string): Promise<boolean> {
	try {
		await fs.promises.access(target);
		return true;
	} catch {
		return false;
	}
}

/** 读文本文件, 不存在返回 null */
export async function readFileText(filePath: string): Promise<string | null> {
	try {
		return await fs.promises.readFile(filePath, 'utf8');
	} catch {
		return null;
	}
}

/** 写文本文件(自动创建父目录) */
export async function writeFileText(filePath: string, content: string): Promise<void> {
	await fs.promises.mkdir(path.dirname(filePath), { recursive: true });
	await fs.promises.writeFile(filePath, content, 'utf8');
}

/** 复制单个文件(源不存在则静默跳过, 目标目录自动创建) */
export async function copyFile(sourcePath: string, targetPath: string): Promise<void> {
	try {
		if (!(await pathExists(sourcePath))) {
			return;
		}
		await fs.promises.mkdir(path.dirname(targetPath), { recursive: true });
		await fs.promises.copyFile(sourcePath, targetPath);
	} catch (error) {
		logWarn(`copyFile: ${sourcePath} -> ${targetPath}: ${String(error)}`);
	}
}

/** 递归复制文件夹, excludeNames 为需要跳过的文件名(如 .gitkeep) */
export async function copyFolder(source: string, target: string, excludeNames: string[] = []): Promise<void> {
	await fs.promises.mkdir(target, { recursive: true });
	const entries = await fs.promises.readdir(source, { withFileTypes: true });
	for (const entry of entries) {
		if (excludeNames.includes(entry.name)) {
			continue;
		}
		const sourcePath = path.join(source, entry.name);
		const targetPath = path.join(target, entry.name);
		if (entry.isDirectory()) {
			await copyFolder(sourcePath, targetPath, excludeNames);
		} else {
			await fs.promises.copyFile(sourcePath, targetPath);
		}
	}
}

/**
 * 重命名文件/文件夹( newName 只含名字, 不含路径 )。
 * 目标已存在时跳过并记录警告, 返回 false —— 调用方可据此向用户汇总,
 * 不再像旧版一样完全静默地留下半成品。
 */
export async function renameEntry(oldPath: string, newName: string): Promise<boolean> {
	try {
		if (!(await pathExists(oldPath))) {
			logWarn(`rename: source not found, skipped: ${oldPath}`);
			return false;
		}
		const newPath = path.join(path.dirname(oldPath), newName);
		if (await pathExists(newPath)) {
			logWarn(`rename: target already exists, skipped: ${newPath}`);
			return false;
		}
		await fs.promises.rename(oldPath, newPath);
		return true;
	} catch (error) {
		logWarn(`rename: ${oldPath} -> ${newName}: ${String(error)}`);
		return false;
	}
}

/** 列出目录下的文件名(仅文件, 可选去掉扩展名) */
export function listFiles(directory: string, noExt = false): string[] {
	try {
		const entries = fs.readdirSync(directory, { withFileTypes: true });
		const files = entries.filter(e => e.isFile()).map(e => e.name);
		return noExt ? files.map(f => path.basename(f, path.extname(f))) : files;
	} catch (error) {
		logWarn(`listFiles: ${directory}: ${String(error)}`);
		return [];
	}
}

/** 列出目录的直接子目录 */
export function listSubdirectories(directory: string): string[] {
	try {
		const entries = fs.readdirSync(directory, { withFileTypes: true });
		return entries.filter(e => e.isDirectory()).map(e => path.join(directory, e.name));
	} catch (error) {
		logWarn(`listSubdirectories: ${directory}: ${String(error)}`);
		return [];
	}
}

/** 递归获取目录下所有文件 */
export async function listFilesRecursive(directory: string): Promise<string[]> {
	const files: string[] = [];

	async function traverse(current: string): Promise<void> {
		const entries = await fs.promises.readdir(current, { withFileTypes: true });
		for (const entry of entries) {
			const full = path.join(current, entry.name);
			if (entry.isDirectory()) {
				await traverse(full);
			} else if (entry.isFile()) {
				files.push(full);
			}
		}
	}

	await traverse(directory);
	return files;
}

/** 用正则筛选目录下的文件(不递归), 返回完整路径 */
export function getFilesByRegex(directory: string, regex: RegExp): string[] {
	const matched: string[] = [];
	try {
		const entries = fs.readdirSync(directory, { withFileTypes: true });
		for (const entry of entries) {
			if (entry.isFile() && regex.test(entry.name)) {
				matched.push(path.join(directory, entry.name));
			}
		}
	} catch (error) {
		logWarn(`getFilesByRegex: ${directory}: ${String(error)}`);
	}
	return matched;
}

/** 在若干目录中查找 .scml 文件 */
export function findScmlFiles(directories: string[]): string[] {
	const scmlFiles: string[] = [];
	for (const directory of directories) {
		for (const name of listFiles(directory)) {
			if (path.extname(name) === '.scml') {
				scmlFiles.push(path.join(directory, name));
			}
		}
	}
	return scmlFiles;
}

/**
 * 递归收集目录下"尚未打包"的 png(同名 .tex 已存在则跳过,
 * 即只处理新增图片, 避免重复打包)。
 */
export async function getValidPngFiles(directory: string): Promise<string[]> {
	const validPngFiles: string[] = [];

	async function processDirectory(dirPath: string): Promise<void> {
		const entries = await fs.promises.readdir(dirPath, { withFileTypes: true });
		for (const entry of entries) {
			const filePath = path.join(dirPath, entry.name);
			if (entry.isDirectory()) {
				await processDirectory(filePath);
			} else if (entry.isFile() && entry.name.endsWith('.png')) {
				const baseName = path.basename(entry.name, '.png');
				const texExists = await pathExists(path.join(dirPath, `${baseName}.tex`));
				if (!texExists) {
					validPngFiles.push(filePath);
				}
			}
		}
	}

	await processDirectory(directory);
	return validPngFiles;
}

/** 读取文件前两行(trim 后) */
export async function readFirstTwoLines(filePath: string): Promise<{ firstLine: string; secondLine: string }> {
	const content = await readFileText(filePath);
	if (content === null) {
		return { firstLine: '', secondLine: '' };
	}
	const lines = content.split(/\r?\n/);
	return {
		firstLine: lines[0] ? lines[0].trim() : '',
		secondLine: lines[1] ? lines[1].trim() : '',
	};
}

/** 读文件 → 正则替换 → 写回 */
export async function replaceInFile(filePath: string, regex: RegExp, replacement: string): Promise<void> {
	const content = await readFileText(filePath);
	if (content === null) {
		logWarn(`replaceInFile: file not found: ${filePath}`);
		return;
	}
	await fs.promises.writeFile(filePath, content.replace(regex, replacement), 'utf8');
}
