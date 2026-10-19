/**
 * 打包勾选记忆:按 mod 根目录记忆用户上次勾选的打包内容。
 * 存储在 ~/Documents/dst-lan/pack-prefs.json, 结构:
 *   { "<modRoot>": { "included": ["modinfo.lua", "scripts", ...], "updatedAt": "ISO" } }
 * 读写均容错:文件损坏/不可写时静默降级为"无记忆"。
 */
import * as fs from 'fs';
import * as path from 'path';
import { logWarn } from './output';

export interface PackPrefs {
	[modRoot: string]: {
		included: string[];
		updatedAt: string;
	};
}

/** 读取记忆;prefsPath 可注入(测试用) */
export function loadPackPrefs(prefsPath: string): PackPrefs {
	try {
		if (!fs.existsSync(prefsPath)) {
			return {};
		}
		const parsed = JSON.parse(fs.readFileSync(prefsPath, 'utf8')) as PackPrefs;
		if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
			return {};
		}
		return parsed;
	} catch (error) {
		logWarn(`loadPackPrefs: ${String(error)}`);
		return {};
	}
}

/** 保存某个 mod 的勾选记忆;prefsPath 可注入(测试用) */
export function savePackPrefs(prefsPath: string, modRoot: string, included: string[]): void {
	try {
		const prefs = loadPackPrefs(prefsPath);
		prefs[modRoot] = { included, updatedAt: new Date().toISOString() };
		fs.mkdirSync(path.dirname(prefsPath), { recursive: true });
		fs.writeFileSync(prefsPath, JSON.stringify(prefs, null, '\t'), 'utf8');
	} catch (error) {
		logWarn(`savePackPrefs: ${String(error)}`);
	}
}

/** 取某个 mod 的历史勾选(无记忆或条目已失效时返回 undefined) */
export function getRememberedInclude(prefsPath: string, modRoot: string): string[] | undefined {
	const entry = loadPackPrefs(prefsPath)[modRoot];
	if (!entry || !Array.isArray(entry.included)) {
		return undefined;
	}
	return entry.included;
}
