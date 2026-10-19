/**
 * "当前 mod 根目录"定位:从激活编辑器文件向上逐级查找 modinfo.lua,
 * 不越过工作区根目录。
 */
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

/** 激活编辑器文件路径(无则 undefined) */
export function getActiveEditorPath(): string | undefined {
	return vscode.window.activeTextEditor?.document.uri.fsPath;
}

/**
 * 从 startPath 逐级向上查找 modinfo.lua, 返回所在目录;
 * 到工作区根目录仍未找到则返回 undefined。
 */
export function findModInfoFile(startPath: string | undefined): string | undefined {
	if (!startPath) {
		return undefined;
	}
	const workspaceRoot = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;

	let currentPath = startPath;
	for (; ;) {
		if (fs.existsSync(path.join(currentPath, 'modinfo.lua'))) {
			return currentPath;
		}
		if (workspaceRoot && currentPath === workspaceRoot) {
			return undefined;
		}
		const parent = path.dirname(currentPath);
		if (parent === currentPath) {
			return undefined; // 已到文件系统根
		}
		currentPath = parent;
	}
}
