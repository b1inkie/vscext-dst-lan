/**
 * 命令 dst-lan.extrafn —— Extra 功能菜单。
 *
 *  1. 打包当前 mod 为 zip(创意工坊上传所需的精简包 / 全量包)
 *  2. 画布一键扩/裁(scml 关联 png 与 XML pivot 同步修正)
 *  3. 取色器(webview)
 *  4. 解包: 选图集 .xml(多元素出文件夹, 单元素出 png)
 *  5. fdp 声音工程生成 —— 2.0 重构中, 暂为 WIP 提示
 */
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { genPathIn } from '../constants';
import { pickAndPackDirectory } from './packZip';
import { packFolderToAtlas } from '../lib/anim2/atlasPack';
import { opExpandAll, opCropAll, selectScmlFile, DEFAULT_EXPAND_SCALE, DEFAULT_MAX_SIZE } from '../lib/canvas';
import { getActiveEditorPath, findModInfoFile } from '../lib/modroot';
import { unpackAtlasAuto } from '../lib/anim2/unpack';

export function registerExtraFn(context: vscode.ExtensionContext): vscode.Disposable {
	return vscode.commands.registerCommand('dst-lan.extrafn', runExtraFn);
}

async function runExtraFn(): Promise<void> {
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

	const dstIcon = vscode.Uri.file(genPathIn('icons', 'dst-logo-32px.png'));
	const fmodIcon = vscode.Uri.file(genPathIn('icons', 'fmod-32px.png'));

	const quickpick = vscode.window.createQuickPick();
	quickpick.title = vscode.l10n.t('src.extension.extra.title');
	quickpick.placeholder = vscode.l10n.t('src.extension.extra.ph');
	quickpick.items = [
		{ label: '1. ', description: vscode.l10n.t('src.extension.extra.op.packzip'), iconPath: { light: dstIcon, dark: dstIcon } },
		{ label: '2. ', description: vscode.l10n.t('src.extension.extra.op.expand-crop-canvas'), iconPath: { light: dstIcon, dark: dstIcon } },
		{ label: '3. ', description: vscode.l10n.t('src.extension.extra.op.color-picker'), iconPath: { light: dstIcon, dark: dstIcon } },
		{ label: '4. ', description: vscode.l10n.t('src.extension.extra.op.unpack'), iconPath: { light: dstIcon, dark: dstIcon } },
		{ label: '5. ', description: vscode.l10n.t('src.extension.extra.op.fdp-gener'), iconPath: { light: fmodIcon, dark: fmodIcon } },
	];

	quickpick.onDidAccept(async () => {
		const selected = quickpick.selectedItems[0];
		quickpick.dispose();
		if (!selected) {
			return;
		}
		switch (selected.label) {
			case '1. ':
				await pickAndPackDirectory(modInfoDirectory);
				break;
			case '2. ':
				await pickCanvasOp();
				break;
			case '3. ':
				openColorPicker();
				break;
		case '4. ':
			await unpackTexFiles();
			break;
		case '5. ':
			// fdp 生成器重构中
			vscode.window.showInformationMessage(vscode.l10n.t('src.extension.extra.op.fdp-wip'));
			break;
			default:
				break;
		}
	});

	quickpick.show();
}


/** 画布操作选择: 扩大一倍 / 尽量裁剪 */
async function pickCanvasOp(): Promise<void> {
	const quickpick = vscode.window.createQuickPick();
	quickpick.title = vscode.l10n.t('src.extension.extra.op.expand-choose-title');
	quickpick.placeholder = vscode.l10n.t('src.extension.extra.ph');
	quickpick.items = [
		{ label: '0. ', description: 'Never Mind!' },
		{ label: '1. ', description: vscode.l10n.t('src.extension.extra.op.expand-choose-1-expand') },
		{ label: '2. ', description: vscode.l10n.t('src.extension.extra.op.expand-choose-2-crop') },
	];

	quickpick.onDidAccept(async () => {
		const selected = quickpick.selectedItems[0];
		quickpick.dispose();
		if (!selected) {
			return;
		}
		switch (selected.label) {
			case '1. ': {
				const scmlPath = await selectScmlFile();
				if (scmlPath) {
					const scale = await askNumber('扩展倍数 (scale)', String(DEFAULT_EXPAND_SCALE), v => v >= 1);
					if (scale === undefined) { return; }
					const maxSize = await askNumber('最大尺寸 (max size)', String(DEFAULT_MAX_SIZE), v => v >= 1);
					if (maxSize === undefined) { return; }
					await opExpandAll(scmlPath, scale, maxSize);
				}
				break;
			}
			case '2. ': {
				const scmlPath = await selectScmlFile();
				if (scmlPath) {
					const edge = await askNumber('边缘像素 (edge, 四周保留的透明边)', '0', v => v >= 0);
					if (edge === undefined) { return; }
					await opCropAll(scmlPath, edge);
				}
				break;
			}
			default:
				break;
		}
	});

	quickpick.show();
}

/** 数值输入框: 取消返回 undefined, 留空用默认值; 校验失败重问 */
async function askNumber(prompt: string, defaultValue: string, validate: (v: number) => boolean): Promise<number | undefined> {
	for (; ;) {
		const input = await vscode.window.showInputBox({ prompt, value: defaultValue });
		if (input === undefined) {
			return undefined;
		}
		const num = input.trim() === '' ? Number(defaultValue) : Number(input.trim());
		if (!Number.isFinite(num)) {
			vscode.window.showErrorMessage(vscode.l10n.t('src.extension.compiler.novalid_switch'));
			continue;
		}
		if (!validate(num)) {
			vscode.window.showErrorMessage(vscode.l10n.t('src.extension.compiler.novalid_switch'));
			continue;
		}
		return num;
	}
}
/** 多图打包成图集: 选文件夹 → <文件夹名>.tex + .xml(零依赖) */
/** 多图打包成图集(入口在 dst-lan.compiler 菜单): 选源文件夹 -> 选输出目录(默认定位 mod/images) -> 打包 */
export async function packFolderAsAtlas(): Promise<void> {
	// 1. 选源文件夹(其内 png 打包为图集)
	const picked = await vscode.window.showOpenDialog({
		canSelectMany: false,
		canSelectFolders: true,
		openLabel: vscode.l10n.t('src.extension.extra.op.atlas-pick-folder'),
	});
	if (!picked || picked.length === 0) {
		return;
	}
	const inputDir = picked[0].fsPath;

	// 2. 选输出目录: 优先定位到当前 mod(编辑器文件向上找 modinfo.lua)的 images/
	//    子目录, 便于直接下钻选择; 无 mod 上下文时退到源文件夹父目录
	const activeEditorPath = getActiveEditorPath();
	const modDir = activeEditorPath ? findModInfoFile(path.dirname(activeEditorPath)) : undefined;
	let defaultDir = modDir;
	if (modDir && fs.existsSync(path.join(modDir, 'images'))) {
		defaultDir = path.join(modDir, 'images');
	}
	if (!defaultDir) {
		defaultDir = path.dirname(inputDir);
	}
	const outPicked = await vscode.window.showOpenDialog({
		canSelectMany: false,
		canSelectFolders: true,
		defaultUri: vscode.Uri.file(defaultDir),
		openLabel: vscode.l10n.t('src.extension.extra.op.atlas-pick-outdir'),
	});
	if (!outPicked || outPicked.length === 0) {
		return;
	}
	const outDir = outPicked[0].fsPath;

	// 3. 打包(输出 <文件夹名>.tex/.xml 到所选目录)
	try {
		const result = await packFolderToAtlas(inputDir, outDir);
		vscode.window.showInformationMessage(vscode.l10n.t('src.extension.extra.op.atlas-done')
			.replace('{n}', String(result.elements))
			.replace('{size}', `${result.width}x${result.height}`)
			+ `\n${result.texPath}`);
	} catch (error) {
		vscode.window.showErrorMessage(`atlas pack failed: ${error}`);
	}
}
/** 解包: 选图集 .xml(整图还原 png) 或多元素图集(每元素一个 png) */
async function unpackTexFiles(): Promise<void> {
	const picked = await vscode.window.showOpenDialog({
		canSelectMany: true,
		canSelectFolders: false,
		filters: { 'Atlas key (xml)': ['xml'] },
		openLabel: vscode.l10n.t('src.extension.compiler.unpack-pick'),
	});
	if (!picked || picked.length === 0) {
		return;
	}
	const pngs: string[] = [];
	const failures: string[] = [];
	for (const uri of picked) {
		const p = uri.fsPath;
		try {
			// 解包部件: 多元素图集 -> 同名文件夹; 单元素(散图) -> png 直接在 xml 旁
			const r = await unpackAtlasAuto(p);
			pngs.push(...r.pngs);
		} catch (err) {
			failures.push(`${path.basename(p)}: ${err instanceof Error ? err.message : err}`);
		}
	}
	if (pngs.length > 0) {
		vscode.window.showInformationMessage(vscode.l10n.t('src.extension.compiler.unpack-done')
			.replace('{n}', String(pngs.length))
			+ (failures.length > 0 ? vscode.l10n.t('src.extension.compiler.partial').replace('{n}', String(failures.length)) : ''));
	} else if (failures.length > 0) {
		vscode.window.showErrorMessage(failures.join('; '));
	}
}
/** 取色器 webview */
function openColorPicker(): void {
	const panel = vscode.window.createWebviewPanel('colorPicker', 'Color Picker', vscode.ViewColumn.One, {});

	panel.webview.html = /*html*/`
		<!DOCTYPE html>
		<html lang="en">
		<head>
			<meta charset="UTF-8">
			<meta name="viewport" content="width=device-width, initial-scale=1.0">
			<title>Color Picker</title>
			<style>
				body {
					font-family: Arial, sans-serif;
					margin: 0;
					padding: 10px;
					background-color: #303030;
					color: #ffffff;
					display: flex;
					flex-direction: column;
					align-items: flex-start; /* 左对齐 */
				}
				input[type="color"] {
					border: thin solid #303030; /* 调整边框样式 */
					width: 80px; /* 设置宽度 */
					height: 60px; /* 设置高度 */
					border-radius: 4px; /* 移除圆角以呈现矩形 */
				}
				.hint {
					margin-top: 5px;
					font-size: 14px;
					color: #aaaaaa;
				}
			</style>
		</head>
		<body>
			<input type="color" id="colorPicker">
			<div class="hint">Pick Color</div>
			<script>
				const vscode = acquireVsCodeApi();
				document.getElementById('colorPicker').addEventListener('input', (event) => {
					vscode.postMessage({
						command: 'colorSelected',
						color: event.target.value
					});
				});
			</script>
		</body>
		</html>
	`;

	panel.webview.onDidReceiveMessage(message => {
		if (message.command === 'colorSelected') {
			vscode.window.showInformationMessage(`Selected color: ${message.color}`);
		}
	});
}
