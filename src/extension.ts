/**
 * dst-lan 扩展入口。
 *
 * 注册 7 个命令(命令 ID 与 1.x 完全一致)与 2 个补全提供者。
 * 各模块注册失败只降级对应功能, 不阻断激活。
 */
import * as vscode from 'vscode';
import { registerGenMod } from './commands/genMod';
import { registerInjectAvatar } from './commands/injectAvatar';
import { registerCompiler } from './commands/compiler';
import { registerMakeimg } from './commands/makeimg';
import { registerDeleteComments } from './commands/deleteComments';
import { registerToggleLanguage, currentLanguage } from './commands/toggleLanguage';
import { registerExtraFn } from './commands/extrafn';
import { registerRulesCompletionProvider } from './completions/rulesProvider';
import { registerHelpCompletionProvider } from './completions/helpProvider';

export function activate(context: vscode.ExtensionContext): void {
	const langAuthor = currentLanguage() === 'zh-cn' ? '贡献者' : 'Contributor';

	const registrations: Array<() => vscode.Disposable> = [
		() => registerGenMod(context),
		() => registerInjectAvatar(context),
		() => registerCompiler(context),
		() => registerMakeimg(context),
		() => registerDeleteComments(context),
		() => registerToggleLanguage(context),
		() => registerExtraFn(context),
		() => registerRulesCompletionProvider(langAuthor),
		() => registerHelpCompletionProvider(),
	];

	for (const register of registrations) {
		try {
			context.subscriptions.push(register());
		} catch (error) {
			vscode.window.showErrorMessage(`dst-lan: failed to register a feature: ${error}`);
		}
	}
}

export function deactivate(): void {
	// nothing to do
}
