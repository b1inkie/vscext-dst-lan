/**
 * 占位符协议:模板文件中使用 %(name)s 形式的占位符,
 * 例如 mod_template 中的 %(modid)s / %(modid_upper)s,
 * scml 模板中的 %(prefab)s,人物模板中的 %(avatarid)s。
 */
import * as fs from 'fs';
import * as path from 'path';
import { logWarn } from './output';

/** 将 text 中所有 %(name)s 占位符替换为 after */
export function regexRep(text: string, name: string, after: string): string {
	// 用函数形式替换, 避免替换值中的 $&/$1 等模式被 String.replace 展开
	return text.replace(new RegExp(`%\\(${name}\\)s`, 'g'), () => after);
}

/** 按 replacements 字典批量替换 %(key)s 占位符 */
export function replacePlaceholders(template: string, replacements: Record<string, string>): string {
	let result = template;
	for (const [name, replacement] of Object.entries(replacements)) {
		result = regexRep(result, name, replacement);
	}
	return result;
}

/**
 * 读取文件并替换其中占位符后写回。
 * 文件不存在时记录警告并跳过(与模板内容解耦, 缺失不致中断整个流程)。
 */
export async function rewriteContent(filePath: string, replacements: Record<string, string>): Promise<void> {
	try {
		let content: string;
		try {
			content = await fs.promises.readFile(filePath, 'utf8');
		} catch {
			logWarn(`rewriteContent: file not found, skipped: ${filePath}`);
			return;
		}
		await fs.promises.writeFile(filePath, replacePlaceholders(content, replacements), 'utf8');
	} catch (error) {
		logWarn(`rewriteContent: failed on ${filePath}: ${String(error)}`);
	}
}

/** 生成目标文件所在的目录(不存在则创建)并返回该目录路径 */
export function genFolder(...args: string[]): string {
	const target = path.join(...args);
	if (!fs.existsSync(target)) {
		fs.mkdirSync(target, { recursive: true });
	}
	return target;
}
