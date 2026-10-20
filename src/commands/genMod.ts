/**
 * 命令 dst-lan.gen-mod —— 生成 mod 框架。
 *
 * 流程:输入 modid → 复制 mod_template 到工作区 → 按"占位符替换 →
 * 文件/文件夹重命名 → 汇总生成 modmain 导入列表"的固定管线加工。
 * 占位符协议与目录结构与 1.x 完全一致(%(modid)s / %(modid_upper)s)。
 */
import * as vscode from 'vscode';
import * as path from 'path';
import { genPathIn } from '../constants';
import { copyFolder, listFiles, readFirstTwoLines, renameEntry } from '../lib/fsx';
import { rewriteContent } from '../lib/placeholder';
import { showOutput } from '../lib/output';

export function registerGenMod(context: vscode.ExtensionContext): vscode.Disposable {
	return vscode.commands.registerCommand('dst-lan.gen-mod', async () => {
		try {
			await runGenMod();
		} catch (error) {
			vscode.window.showErrorMessage(vscode.l10n.t('src.extension.entry_mod_name_fail') + `: ${error}`);
			showOutput();
		}
	});
}

async function runGenMod(): Promise<void> {
	const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
	if (!workspaceFolder) {
		vscode.window.showErrorMessage(vscode.l10n.t('src.extension.please_open_folder'));
		return;
	}

	// mod 名称(取消输入则中止; 留空则用默认名)
	const input = await vscode.window.showInputBox({
		prompt: vscode.l10n.t('src.extension.entry_mod_name'),
		placeHolder: vscode.l10n.t('src.extension.entry_mod_name_placeholder'),
	});
	if (input === undefined) {
		return;
	}
	const modid = input || 'new_mod';
	const modidUpper = modid.toUpperCase();

	// 复制模板
	const targetFolder = path.join(workspaceFolder.uri.fsPath, modid);
	await copyFolder(genPathIn('mod_template'), targetFolder, ['.gitkeep']);

	/** 目标 mod 内的相对路径 */
	const sub = (...rel: string[]): string => path.join(targetFolder, ...rel);
	const renameFailures: string[] = [];
	const rename = async (oldPath: string, newName: string): Promise<void> => {
		if (!(await renameEntry(oldPath, newName))) {
			renameFailures.push(`${path.relative(targetFolder, oldPath)} -> ${newName}`);
		}
	};

	// 对 core_modid 下某子目录的全部文件做占位符替换
	// 对 core_modid 下某子目录的全部文件做占位符替换(映射与 1.x 各目录保持一致)
	const rewriteDir = async (mapping: Record<string, string>, ...rel: string[]): Promise<string[]> => {
		const dir = sub(...rel);
		const files = listFiles(dir);
		for (const file of files) {
			await rewriteContent(path.join(dir, file), mapping);
		}
		return files;
	};

	// 1. 单文件占位符替换
	await rewriteContent(sub('modinfo.lua'), { modid });
	await rewriteContent(sub('scripts', 'core_modid', 'api', '_register.lua'), { modid });
	await rewriteContent(sub('scripts', 'api_skins', 'modid_skins.lua'), { modid, modid_upper: modidUpper });
	// modmain 以 <modid>_skins 导入, 文件名必须同步改名
	await rename(sub('scripts', 'api_skins', 'modid_skins.lua'), `${modid}_skins.lua`);
	await rewriteContent(sub('scripts', 'core_modid', 'data', 'unlock_skins.lua'), { modid, modid_upper: modidUpper });
	await rewriteContent(sub('scripts', 'core_modid', 'skins', 'myspear.lua'), { modid, modid_upper: modidUpper });
	await rewriteContent(sub('modworldgenmain.lua'), { modid, modid_upper: modidUpper });
	// 语言文件: modid 直接使用大写形式(与 1.x 行为一致)
	await rewriteContent(sub('scripts', 'core_modid', 'languages', 'cn.lua'), { modid: modidUpper, modid_upper: modidUpper });
	await rewriteContent(sub('scripts', 'core_modid', 'languages', 'en.lua'), { modid: modidUpper, modid_upper: modidUpper });

	// 2. callers:替换 + 汇总为 modmain 中的注释导入列表
	let allCallers = '';
	for (const file of await rewriteDir({ modid }, 'scripts', 'core_modid', 'callers')) {
		allCallers += `-- modimport('scripts/core_'..modid..'/callers/${file}')\n`;
	}

	// 3. LSP 目录
	await rewriteDir({ modid }, 'LSP', 'api');
	await rewriteDir({ modid }, 'LSP', 'manager');

	// 4. api / data / utils / sg 目录
	await rewriteDir({ modid, modid_upper: modidUpper }, 'scripts', 'core_modid', 'api');
	await rewriteDir({ modid, modid_upper: modidUpper }, 'scripts', 'core_modid', 'data');
	await rewriteDir({ modid, modid_upper: modidUpper }, 'scripts', 'core_modid', 'utils');
	await rewriteDir({ modid, modid_upper: modidUpper }, 'scripts', 'core_modid', 'sg');

	// 5. managers:替换 + 按首行 '-- show' 决定导入是否注释, 汇总到 modmain
	let allManagers = '';
	for (const file of listFiles(sub('scripts', 'core_modid', 'managers'))) {
		const filePath = sub('scripts', 'core_modid', 'managers', file);
		await rewriteContent(filePath, { modid, modid_upper: modidUpper });
		const { firstLine, secondLine } = await readFirstTwoLines(filePath);
		const importStatement = `modimport('scripts/core_${modid}/managers/${file}') ${secondLine}`;
		allManagers += firstLine.trim() === '-- show' ? `${importStatement}\n` : `-- ${importStatement}\n`;
	}

	// 6. components:替换 + 文件名中的 modid 替换为实际 modid
	for (const file of listFiles(sub('scripts', 'components'))) {
		const filePath = sub('scripts', 'components', file);
		await rewriteContent(filePath, { modid, modid_upper: modidUpper });
		await rename(filePath, file.split('modid').join(modid));
	}

	// 7. prefabs:替换 + 加前缀重命名 + 汇总 PrefabFiles 注释列表
	let allPrefabs = '';
	for (const name of listFiles(sub('scripts', 'prefabs'), true)) {
		await rewriteContent(sub('scripts', 'prefabs', `${name}.lua`), { modid });
		await rename(sub('scripts', 'prefabs', `${name}.lua`), `${modid}_${name}.lua`);
		allPrefabs += `\t-- '${modid}_${name}',\n`;
	}

	// 8. modmain:注入汇总的 callers / managers / prefabs
	await rewriteContent(sub('modmain.lua'), {
		modid,
		modid_upper: modidUpper,
		callers: allCallers,
		managers: allManagers,
		prefabs: allPrefabs,
	});

	// 9. 文件夹 / 工作区文件 / 介绍文档
	await rename(sub('scripts', 'core_modid'), `core_${modid}`);
	await rewriteContent(sub('dst_mod-modid-wp.json'), { modid });
	await rename(sub('dst_mod-modid-wp.json'), `dst_mod-${modid}.code-workspace`);

	if (renameFailures.length > 0) {
		vscode.window.showWarningMessage(
			`${vscode.l10n.t('src.extension.entry_mod_name_success')}` +
			` (rename skipped: ${renameFailures.length}, see dst-lan output)`,
		);
		showOutput();
	} else {
		vscode.window.showInformationMessage(vscode.l10n.t('src.extension.entry_mod_name_success'));
	}
}
