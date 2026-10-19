/**
 * 命令 dst-lan.toggle-language —— 切换补全/帮助内容的中英文。
 *
 * 实现:用 snippets_backup / custom_rules_backup 中的 cn/en 版本覆盖
 * 活动文件(snippets 与规则均为静态贡献, 必须重启后生效)。
 * 语言状态保存在 ~/Documents/dst-lan/lang.ini(2.0 起迁出 out/,
 * 旧版 out/lang.ini 会被自动迁移)。
 */
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { EXT_ROOT, LANG_INI, userConfigPath } from '../constants';
import { copyFile } from '../lib/fsx';

/** 读取当前语言(不存在时默认 zh-cn;自动迁移旧版 out/lang.ini) */
export function currentLanguage(): string {
	const langIni = userConfigPath(LANG_INI);
	if (!fs.existsSync(langIni)) {
		// 迁移旧版状态文件(旧版写在 out/ 内, 重编译会丢)
		const legacy = path.join(__dirname, 'lang.ini');
		if (fs.existsSync(legacy)) {
			try {
				fs.copyFileSync(legacy, langIni);
			} catch {
				// 迁移失败按默认处理
			}
		}
	}
	try {
		return fs.readFileSync(langIni, 'utf8').trim() || 'zh-cn';
	} catch {
		return 'zh-cn';
	}
}

export function registerToggleLanguage(context: vscode.ExtensionContext): vscode.Disposable {
	return vscode.commands.registerCommand('dst-lan.toggle-language', async () => {
		try {
			const lang = currentLanguage();
			if (lang === 'zh-cn') {
				await applyLanguage('en');
				vscode.window.showWarningMessage('dst-lan: Please restart VSCode to complete the code-snippets language switch.');
				offerReload('Switch to English/切换到英文');
			} else {
				await applyLanguage('zh-cn');
				vscode.window.showWarningMessage('dst-lan: 已切换到中文,请立即重启 VSCode 以应用更改!');
				offerReload('Switch to Chinese/切换到中文');
			}
		} catch (error) {
			vscode.window.showWarningMessage(`error: ${error}`);
		}
	});
}

/** 覆盖活动 snippets / rules / help 并写入语言状态 */
async function applyLanguage(lang: 'zh-cn' | 'en'): Promise<void> {
	const suffix = lang === 'zh-cn' ? 'cn' : 'en';
	await copyFile(
		path.join(EXT_ROOT, 'snippets_backup', `snippets_${suffix}.code-snippets`),
		path.join(EXT_ROOT, 'snippets', 'snippets.code-snippets'),
	);
	await copyFile(
		path.join(EXT_ROOT, 'custom_rules_backup', `rules_${suffix}.json`),
		path.join(EXT_ROOT, 'custom_rules', 'rules.json'),
	);
	await copyFile(
		path.join(EXT_ROOT, 'custom_rules_backup', `help_${suffix}.json`),
		path.join(EXT_ROOT, 'custom_rules', 'help.json'),
	);
	fs.writeFileSync(userConfigPath(LANG_INI), lang, 'utf8');
}

/** 弹出"立即重启"按钮 */
function offerReload(buttonTitle: string): void {
	vscode.window.showInformationMessage(buttonTitle, vscode.l10n.t('src.extension.switch_btn_title')).then(button => {
		if (button === vscode.l10n.t('src.extension.switch_btn_title')) {
			vscode.window.showWarningMessage(vscode.l10n.t('src.extension.switch_btn_info'));
			vscode.commands.executeCommand('workbench.action.reloadWindow');
		}
	});
}
