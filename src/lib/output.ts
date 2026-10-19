/**
 * 扩展专属输出通道:所有子进程输出、文件操作警告统一记录在这里,
 * 替代旧版"每 500ms 弹一行状态栏消息"的方式。
 */
import * as vscode from 'vscode';

const CHANNEL_NAME = 'dst-lan';

let channel: vscode.OutputChannel | undefined;

export function getOutputChannel(): vscode.OutputChannel {
	if (!channel) {
		channel = vscode.window.createOutputChannel(CHANNEL_NAME);
	}
	return channel;
}

export function logLine(message: string): void {
	getOutputChannel().appendLine(message);
}

export function logWarn(message: string): void {
	getOutputChannel().appendLine(`[warn] ${message}`);
}

export function showOutput(): void {
	getOutputChannel().show(true);
}
