/**
 * 命令 dst-lan.makeimg —— 制作预制物动画和图片。
 *
 * 两步工作流(与 1.x 一致):
 *  1. "提取模板图":把三张模板底图(地面/物品栏/手持)释放到 mod 的 _temp 目录,
 *     用户按需绘制(可删掉不需要的图);
 *  2. "我画好了":按输入的 prefab id 注入
 *     - exported/ground_<p>/ground/<p>.png + ground.scml
 *     - exported/swap_<p>/swap_<p>/swap_<p>-0-0..9.png(10 帧)+ swap.scml
 *     - images/inventoryimages/<p>.png
 */
import * as vscode from 'vscode';
import * as path from 'path';
import { genPathIn } from '../constants';
import { copyFile, pathExists, readFileText, writeFileText } from '../lib/fsx';
import { regexRep, genFolder } from '../lib/placeholder';
import { getActiveEditorPath, findModInfoFile } from '../lib/modroot';

export function registerMakeimg(context: vscode.ExtensionContext): vscode.Disposable {
	return vscode.commands.registerCommand('dst-lan.makeimg', runMakeimg);
}

async function runMakeimg(): Promise<void> {
	const activeEditorPath = getActiveEditorPath();
	if (!activeEditorPath) {
		vscode.window.showErrorMessage(vscode.l10n.t('src.extension.compiler.didnt_open_any_editor'));
		return;
	}
	const modInfoDirectory = findModInfoFile(path.dirname(activeEditorPath));
	if (!modInfoDirectory) {
		vscode.window.showErrorMessage(vscode.l10n.t('src.extension.compiler.fail_to_find_modinfo'));
		return;
	}

	const tempPath = genFolder(modInfoDirectory, '_temp');

	const options = [
		vscode.l10n.t('src.extension.makeimg.done'),
		vscode.l10n.t('src.extension.makeimg.fetch'),
	];
	const selectedOption = await vscode.window.showQuickPick(options);
	if (!selectedOption) {
		return;
	}

	switch (selectedOption) {
		case vscode.l10n.t('src.extension.makeimg.done'):
			await injectPrefabImages(modInfoDirectory, tempPath);
			break;
		case vscode.l10n.t('src.extension.makeimg.fetch'):
			await fetchTemplateImages(tempPath);
			break;
		default:
			vscode.window.showErrorMessage(vscode.l10n.t('src.extension.compiler.novalid_switch'));
			break;
	}
}

/** 提取三张模板底图到 _temp */
async function fetchTemplateImages(tempPath: string): Promise<void> {
	for (const name of ['lan_img_ground.png', 'lan_img_inv.png', 'lan_img_swap.png']) {
		await copyFile(genPathIn('resource', 'prefabimg', name), path.join(tempPath, name));
	}
	vscode.window.showInformationMessage(
		vscode.l10n.t('src.extension.makeimg.fetch_done'),
		vscode.l10n.t('src.extension.makeimg.igotit'),
	);
}

/** 将 _temp 中绘制好的图注入到 mod 的对应目录 */
async function injectPrefabImages(modInfoDirectory: string, tempPath: string): Promise<void> {
	const prefabName = await vscode.window.showInputBox({
		prompt: vscode.l10n.t('src.extension.makeimg.enter_prefab_name'),
		placeHolder: vscode.l10n.t('src.extension.makeimg.enter_prefab_name_ph'),
	});
	if (prefabName === undefined) {
		return;
	}
	if (prefabName === '') {
		vscode.window.showErrorMessage(vscode.l10n.t('src.extension.empty_enter'));
		return;
	}

	// 导出目录兜底创建
	genFolder(modInfoDirectory, 'exported');
	genFolder(modInfoDirectory, 'images', 'inventoryimages');

	// 1. 地面图 -> exported/ground_<p>/ground/<p>.png + scml
	const groundPng = path.join(tempPath, 'lan_img_ground.png');
	if (await pathExists(groundPng)) {
		const groundPath = genFolder(modInfoDirectory, 'exported', `ground_${prefabName}`);
		const groundImgPath = genFolder(groundPath, 'ground');
		await copyFile(groundPng, path.join(groundImgPath, `${prefabName}.png`));
		await writeScml(genPathIn('resource', 'scml', 'ground.scml'), path.join(groundPath, `${prefabName}.scml`), prefabName);
	}

	// 2. 手持图 -> exported/swap_<p>/swap_<p>/swap_<p>-0-0..9.png(10 帧)+ scml
	const swapPng = path.join(tempPath, 'lan_img_swap.png');
	if (await pathExists(swapPng)) {
		const swapPath = genFolder(modInfoDirectory, 'exported', `swap_${prefabName}`);
		const swapImgPath = genFolder(swapPath, `swap_${prefabName}`);
		for (let index = 0; index < 10; index++) {
			await copyFile(swapPng, path.join(swapImgPath, `swap_${prefabName}-0-${index}.png`));
		}
		await writeScml(genPathIn('resource', 'scml', 'swap.scml'), path.join(swapPath, `swap_${prefabName}.scml`), prefabName);
	}

	// 3. 物品栏图 -> images/inventoryimages/<p>.png
	const invPng = path.join(tempPath, 'lan_img_inv.png');
	if (await pathExists(invPng)) {
		await copyFile(invPng, path.join(modInfoDirectory, 'images', 'inventoryimages', `${prefabName}.png`));
	}

	vscode.window.showInformationMessage(vscode.l10n.t('src.extension.makeimg.success'));
}

/** 从内部模板生成 scml(替换 %(prefab)s 占位符) */
async function writeScml(templatePath: string, targetPath: string, prefabName: string): Promise<void> {
	const template = await readFileText(templatePath);
	if (template === null) {
		vscode.window.showErrorMessage(`error: scml template not found: ${templatePath}`);
		return;
	}
	await writeFileText(targetPath, regexRep(template, 'prefab', prefabName));
}
