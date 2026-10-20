/**
 * 命令 dst-lan.inject-avatar —— 向已有 mod 注入人物模板。
 *
 * 输入 mod 文件夹名 / modid / avatarid, 复制 mod_avatar_template 后
 * 重命名全套 avatarid 资源并替换占位符(%(avatarid)s / %(modid)s),
 * 目录结构与文件命名约定与 1.x 完全一致。
 */
import * as vscode from 'vscode';
import * as path from 'path';
import { genPathIn } from '../constants';
import { copyFolder, pathExists, renameEntry, replaceInFile } from '../lib/fsx';
import { rewriteContent } from '../lib/placeholder';
import { showOutput } from '../lib/output';
import { getActiveEditorPath } from '../lib/modroot';

export function registerInjectAvatar(context: vscode.ExtensionContext): vscode.Disposable {
	return vscode.commands.registerCommand('dst-lan.inject-avatar', async () => {
		try {
			await runInjectAvatar();
		} catch (error) {
			vscode.window.showErrorMessage(`error: ${error}`);
			showOutput();
		}
	});
}

async function runInjectAvatar(): Promise<void> {
	const activeEditorPath = getActiveEditorPath();
	if (!activeEditorPath) {
		vscode.window.showErrorMessage(vscode.l10n.t('src.extension.compiler.didnt_open_any_editor'));
		return;
	}
	const directoryPath = path.dirname(activeEditorPath);

	// 三段输入: mod 文件夹名 / modid / avatarid
	const modFolder = await vscode.window.showInputBox({
		prompt: vscode.l10n.t('src.extension.inject-avatar.folderName'),
		placeHolder: vscode.l10n.t('src.extension.inject-avatar.folderName_ph'),
	});
	if (modFolder === undefined) {
		return;
	}
	if (modFolder === '') {
		vscode.window.showErrorMessage(vscode.l10n.t('src.extension.empty_enter'));
		return;
	}
	const targetFolder = path.join(directoryPath, modFolder);
	if (!(await pathExists(targetFolder))) {
		vscode.window.showErrorMessage(vscode.l10n.t('src.extension.inject-avatar.current_modpath_not_exist'));
		return;
	}

	const modID = await mustInput('src.extension.inject-avatar.enter_modID', 'src.extension.inject-avatar.enter_modID_ph');
	if (modID === undefined) {
		return;
	}

	const avatarID = await mustInput('src.extension.inject-avatar.enter_avatarID', 'src.extension.inject-avatar.enter_avatarID_ph');
	if (avatarID === undefined) {
		return;
	}
	const avatarUpper = avatarID.toUpperCase();

	// 复制人物模板
	await copyFolder(genPathIn('mod_avatar_template'), targetFolder, ['.gitkeep']);

	const sub = (...rel: string[]): string => path.join(targetFolder, ...rel);
	const renameFailures: string[] = [];
	const rename = async (oldPath: string, newName: string): Promise<void> => {
		if (!(await renameEntry(oldPath, newName))) {
			renameFailures.push(`${path.relative(targetFolder, oldPath)} -> ${newName}`);
		}
	};

	// bigportraits
	await rename(sub('bigportraits', 'avatarid_none.png'), `${avatarID}_none.png`);
	await rename(sub('bigportraits', 'avatarid.png'), `${avatarID}.png`);
	// images/avatars
	await rename(sub('images', 'avatars', 'avatar_avatarid.png'), `avatar_${avatarID}.png`);
	await rename(sub('images', 'avatars', 'avatar_ghost_avatarid.png'), `avatar_ghost_${avatarID}.png`);
	await rename(sub('images', 'avatars', 'self_inspect_avatarid.png'), `self_inspect_${avatarID}.png`);
	// images/map_icons / saveslot_portraits / selectscreen_portraits / names
	await rename(sub('images', 'map_icons', 'avatarid.png'), `${avatarID}.png`);
	await rename(sub('images', 'saveslot_portraits', 'avatarid.png'), `${avatarID}.png`);
	await rename(sub('images', 'selectscreen_portraits', 'avatarid_silho.png'), `${avatarID}_silho.png`);
	await rename(sub('images', 'selectscreen_portraits', 'avatarid.png'), `${avatarID}.png`);
	await rename(sub('images', 'names_avatarid.png'), `names_${avatarID}.png`);

	// exported: scml 内容替换 + 文件与文件夹重命名
	await rewriteContent(sub('exported', 'avatarid', 'avatarid.scml'), { avatarid: avatarID });
	await rename(sub('exported', 'avatarid', 'avatarid.scml'), `${avatarID}.scml`);
	await rename(sub('exported', 'ghost_avatarid_build', 'ghost_avatarid_build.scml'), `ghost_${avatarID}_build.scml`);
	await rename(sub('exported', 'avatarid'), `${avatarID}`);
	await rename(sub('exported', 'ghost_avatarid_build'), `ghost_${avatarID}_build`);

	// scripts: 内容替换 + 重命名
	await rewriteContent(sub('scripts', 'data_avatar', 'data_avatar_avatarid.lua'), {
		avatarid: avatarID,
		avatarid_upper: avatarUpper,
		modid: modID,
	});
	await rewriteContent(sub('scripts', 'prefabs', 'avatar_avatarid.lua'), {
		avatarid: avatarID,
		avatarid_upper: avatarUpper,
		modid_upper: modID.toUpperCase(),
		modid: modID,
	});
	await rename(sub('scripts', 'data_avatar', 'data_avatar_avatarid.lua'), `data_avatar_${avatarID}.lua`);
	await rename(sub('scripts', 'prefabs', 'avatar_avatarid.lua'), `avatar_${avatarID}.lua`);

	// modmain: 替换「导入人物」行中的 %(avatar_id_to_replace)s 占位符, 并去掉行首注释直接启用导入
	// (modmain 缺失时 rewriteContent/replaceInFile 自行警告跳过, 不中断注入)
	await rewriteContent(sub('modmain.lua'), { avatar_id_to_replace: avatarID });
	const avatarImport = `modimport('scripts/data_avatar/data_avatar_${avatarID}.lua')`;
	const escaped = avatarImport.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
	await replaceInFile(sub('modmain.lua'), new RegExp(`^\\s*--\\s*${escaped}`, 'm'), avatarImport);

	if (renameFailures.length > 0) {
		vscode.window.showWarningMessage(
			vscode.l10n.t('src.extension.inject-avatar.inject_succeed') +
			` (rename skipped: ${renameFailures.length}, see dst-lan output)`,
		);
		showOutput();
	} else {
		vscode.window.showInformationMessage(vscode.l10n.t('src.extension.inject-avatar.inject_succeed') + `${avatarID}.lua`);
	}
}

/** 输入框:取消返回 undefined, 留空报错后返回 undefined */
async function mustInput(promptKey: string, placeholderKey: string): Promise<string | undefined> {
	const value = await vscode.window.showInputBox({
		prompt: vscode.l10n.t(promptKey),
		placeHolder: vscode.l10n.t(placeholderKey),
	});
	if (value === undefined) {
		return undefined;
	}
	if (value === '') {
		vscode.window.showErrorMessage(vscode.l10n.t('src.extension.empty_enter'));
		return undefined;
	}
	return value;
}
