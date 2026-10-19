/**
 * 命令 dst-lan.delete-comments —— 删除当前 Lua 文件中的注释与空行。
 * 2.0 起为状态机实现, 字符串字面量中的 "--" 不再被误删。
 */
import * as vscode from 'vscode';
import { stripLuaComments } from '../lib/lua';

export function registerDeleteComments(context: vscode.ExtensionContext): vscode.Disposable {
	return vscode.commands.registerCommand('dst-lan.delete-comments', async () => {
		try {
			const editor = vscode.window.activeTextEditor;
			if (!editor) {
				vscode.window.showErrorMessage('No active text editor found.');
				return;
			}
			const document = editor.document;
			if (document.languageId !== 'lua') {
				vscode.window.showErrorMessage('This command only works with Lua files.');
				return;
			}

			const text = document.getText();
			const newText = stripLuaComments(text);

			const editBuilder = new vscode.WorkspaceEdit();
			editBuilder.replace(document.uri, new vscode.Range(document.positionAt(0), document.positionAt(text.length)), newText);
			const applied = await vscode.workspace.applyEdit(editBuilder);
			if (!applied) {
				vscode.window.showErrorMessage('Failed to remove comments: edit was not applied.');
				return;
			}

			vscode.window.showInformationMessage(vscode.l10n.t('src.extension.delete_comment_tips'));
			vscode.window.showInformationMessage(vscode.l10n.t('src.extension.delete_comment'));
		} catch (error) {
			vscode.window.showErrorMessage(`Failed to remove comments: ${error}`);
		}
	});
}
