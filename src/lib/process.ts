/**
 * 子进程执行工具:输出统一写入 dst-lan OutputChannel。
 */
import { exec } from 'child_process';
import * as vscode from 'vscode';
import { logLine } from './output';

/**
 * 执行外部命令;stdout/stderr 逐行记录到输出通道, 失败时弹错误并抛出。
 */
export function executeCommand(command: string): Promise<void> {
	return new Promise((resolve, reject) => {
		exec(command, { maxBuffer: 32 * 1024 * 1024, windowsHide: true }, (error, stdout, stderr) => {
			const output = `${stdout.toString()}\n${stderr.toString()}`;
			for (const line of output.split(/\r?\n/)) {
				if (line.trim().length > 0) {
					logLine(line);
				}
			}
			if (error) {
				vscode.window.showErrorMessage(`Error executing command: ${error.message}`);
				reject(error);
				return;
			}
			resolve();
		});
	});
}
