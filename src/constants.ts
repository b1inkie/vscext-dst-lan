/**
 * 全局路径与常量。
 *
 * 扩展内资源(mod_template / resource / snippets / custom_rules ...)一律通过
 * genPathIn() 从扩展安装根目录解析;用户级持久配置(打包工具路径、语言状态)
 * 统一放在 ~/Documents/dst-lan/ 下。
 */
import * as path from 'path';
import * as fs from 'fs';

/** 扩展安装根目录(out/ 的上一级, 资源文件所在地) */
export const EXT_ROOT: string = path.join(__dirname, '..');

/** 生成扩展内部资源路径 */
export function genPathIn(...args: string[]): string {
	return path.join(EXT_ROOT, ...args);
}

/** 普通路径拼接 */
export function genPath(...args: string[]): string {
	return path.join(...args);
}

function homeDir(): string {
	if (process.env.USERPROFILE) {
		return process.env.USERPROFILE;
	}
	if (process.env.HOMEDRIVE && process.env.HOMEPATH) {
		return process.env.HOMEDRIVE + process.env.HOMEPATH;
	}
	return process.cwd();
}

/**
 * 用户级配置目录 ~/Documents/dst-lan(不存在则创建)。
 * 旧版将 lang.ini 写在 out/ 内, 重编译会丢失, 2.0 起迁移至此。
 */
export function userConfigDir(): string {
	const dir = path.join(homeDir(), 'Documents', 'dst-lan');
	if (!fs.existsSync(dir)) {
		fs.mkdirSync(dir, { recursive: true });
	}
	return dir;
}

/** 用户级配置文件完整路径 */
export function userConfigPath(filename: string): string {
	return path.join(userConfigDir(), filename);
}


/** 语言状态文件名(内容为 'zh-cn' 或 'en') */
export const LANG_INI = 'lang.ini';

/** 打包勾选记忆文件名(按 mod 根目录记忆上次勾选的打包内容) */
export const PACK_PREFS_JSON = 'pack-prefs.json';
