/**
 * 命令 dst-lan.compiler —— 打包当前 mod 的动画与贴图(内置引擎, 零外部依赖)。
 * 执行时二选一: ① 正常打包动画和图片 ② 多图片打包成图集(解包功能在 dst-lan.extra 菜单)。
 *
 * 打包范围:
 *  - images / bigportraits / levels / fx(递归子目录, 已有同名 .tex 的 png 跳过)
 *    + 根目录 modicon.png  → 同目录 .tex + .xml
 *  - exported/<build>/<build>.scml → anim/<build>.zip(anim.bin + build.bin + atlas)
 *  - XML 后处理: _none.xml 中 _none.tex → _none_oval.tex; 剥离 names_*.xml
 *    中 Element name 的 names_ 前缀
 * 单个文件失败不中断整体, 结束后汇总提示(详见 dst-lan 输出面板)。
 */
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { getValidPngFiles, getFilesByRegex, listSubdirectories, findScmlFiles, replaceInFile } from '../lib/fsx';
import { genFolder } from '../lib/placeholder';
import { getActiveEditorPath, findModInfoFile } from '../lib/modroot';
import { packScmlToZip } from '../lib/anim2/pack';
import { packPngToTex } from '../lib/anim2/scatter';
import { logLine, logWarn, showOutput } from '../lib/output';
import { packFolderAsAtlas } from './extrafn';
import { genPathIn } from '../constants';

export function registerCompiler(context: vscode.ExtensionContext): vscode.Disposable {
	return vscode.commands.registerCommand('dst-lan.compiler', runCompiler);
}

async function runCompiler(): Promise<void> {
	const dstIcon = vscode.Uri.file(genPathIn('icons', 'dst-logo-32px.png'));
	const options: vscode.QuickPickItem[] = [
		{ label: '1. ', description: vscode.l10n.t('src.extension.compiler.switch_normal'), iconPath: { light: dstIcon, dark: dstIcon } },
		{ label: '2. ', description: vscode.l10n.t('src.extension.compiler.switch_atlas'), iconPath: { light: dstIcon, dark: dstIcon } },
	];
	const selectedOption = await vscode.window.showQuickPick(options);
	if (!selectedOption) {
		return;
	}
	if (selectedOption.label === '1. ') {
		await doCompileBuiltin();
	} else {
		await packFolderAsAtlas();
	}
}


/**
 * 内置引擎编译(2.1+): 无需配置任何外部工具, 开箱即用。
 * 遍历 exported/<build>/<build>.scml, 输出 anim/<build>.zip。
 */
async function doCompileBuiltin(): Promise<void> {
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

	// 散装图片 png -> tex(零依赖, 与外部工具行为一致)
	// 健壮性: 目录不存在/单张图失败均跳过并告警, 不中断整体流程
	let packedCount = 0;
	const failures: string[] = [];
	const safePackPng = async (pngPath: string, outDir: string): Promise<void> => {
		try {
			if (await packPngToTex(pngPath, outDir)) {
				packedCount++;
			}
		} catch (err) {
			failures.push(`${path.relative(modInfoDirectory, pngPath)}: ${err instanceof Error ? err.message : err}`);
		}
	};
	// 图片打包目录白名单: 仅这些目录 + 根目录 modicon.png(子目录递归)
	for (const dirName of ['images', 'bigportraits', 'levels', 'fx']) {
		const dirPath = path.join(modInfoDirectory, dirName);
		if (!fs.existsSync(dirPath)) {
			continue;
		}
		for (const pngFile of await getValidPngFiles(dirPath)) {
			await safePackPng(pngFile, path.dirname(pngFile));
		}
	}
	const modiconPath = path.join(modInfoDirectory, 'modicon.png');
	if (fs.existsSync(modiconPath)) {
		await safePackPng(modiconPath, modInfoDirectory);
	}
	logLine(`builtin: packed ${packedCount} png -> tex${failures.length > 0 ? `, ${failures.length} failed` : ''}`);

	const exportedPath = path.join(modInfoDirectory, 'exported');
	const scmlFiles = fs.existsSync(exportedPath) ? findScmlFiles(listSubdirectories(exportedPath)) : [];
	if (scmlFiles.length === 0) {
		vscode.window.setStatusBarMessage('');
		if (packedCount === 0) {
			vscode.window.showErrorMessage(vscode.l10n.t('src.extension.compiler.fail_to_find_scml'));
			return;
		}
		vscode.window.showInformationMessage(vscode.l10n.t('src.extension.compiler.success'));
		showOutput();
		return;
	}
	vscode.window.setStatusBarMessage(`$(package) dst-lan: builtin compiler running...`, 300_000);
	try {
		let animOk = 0;
		for (const scmlFile of scmlFiles) {
			const buildName = path.basename(scmlFile, '.scml');
			const zipPath = path.join(genFolder(modInfoDirectory, 'anim'), `${buildName}.zip`);
			try {
				const result = await packScmlToZip(scmlFile, zipPath);
				for (const warning of result.warnings) {
					logWarn(warning);
				}
				animOk++;
				logLine(`builtin compile OK: ${zipPath} (pages=${result.pages} symbols=${result.symbols} frames=${result.frames} anims=${result.anims})`);
			} catch (err) {
				failures.push(`${path.relative(modInfoDirectory, scmlFile)}: ${err instanceof Error ? err.message : err}`);
				logWarn(`builtin compile FAILED: ${scmlFile} (${err instanceof Error ? err.message : err})`);
			}
		}
		// XML 后处理与外部工具一致
		await fixNoneOvalXml(modInfoDirectory);
		await stripNamesPrefixXml(modInfoDirectory);

		vscode.window.setStatusBarMessage('');
		if (failures.length > 0) {
			logWarn(`failures (${failures.length}):`);
			for (const f of failures) {
				logWarn('  ' + f);
			}
			vscode.window.showWarningMessage(vscode.l10n.t('src.extension.compiler.partial').replace('{n}', String(failures.length)));
		} else {
			vscode.window.showInformationMessage(vscode.l10n.t('src.extension.compiler.success'));
		}
		showOutput();
	} catch (error) {
		vscode.window.setStatusBarMessage('');
		vscode.window.showErrorMessage(`builtin compile failed: ${error}`);
		showOutput();
	}
}







/** bigportraits/*_none.xml: _none.tex 引用改为椭圆头像 _none_oval.tex */
async function fixNoneOvalXml(modInfoDirectory: string): Promise<void> {
	const bigportraitsPath = path.join(modInfoDirectory, 'bigportraits');
	if (!fs.existsSync(bigportraitsPath)) {
		return;
	}
	for (const xmlFile of getFilesByRegex(bigportraitsPath, /_none\.xml/)) {
		await replaceInFile(xmlFile, /_none\.tex" u1/, '_none_oval.tex" u1');
	}
}

/** images/names_*.xml: 剥离 Element name 的 names_ 前缀 */
async function stripNamesPrefixXml(modInfoDirectory: string): Promise<void> {
	const imagesPath = path.join(modInfoDirectory, 'images');
	if (!fs.existsSync(imagesPath)) {
		return;
	}
	for (const xmlFile of getFilesByRegex(imagesPath, /names_.*?\.xml/)) {
		await replaceInFile(xmlFile, /Element name="names_/, 'Element name="');
	}
}
