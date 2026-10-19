/**
 * 交互式打包:列出 mod 根目录下所有一级文件/文件夹的复选框列表,
 * 勾选 = 打包。工具栏按钮一键套用预设(全选 / 全不选 / 工坊精简 / 全量),
 * 确认后打包并把本次勾选记忆到 ~/Documents/dst-lan/pack-prefs.json,
 * 下次进入时自动恢复上次的选择。
 *
 * 预设(与 1.x 的两个打包模式一致):
 *  - 工坊精简: 排除 .git/.vscode/_temp/_temp_fdp/DETAILS/exported/LSP
 *  - 全量:     排除 .git/.vscode/_temp/_temp_fdp/DETAILS
 * 两个预设均默认不勾选根目录下已有的 *.zip(避免旧包套娃)。
 */
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { PACK_PREFS_JSON } from '../constants';
import { packDirectoryToZip } from '../lib/pack';
import { getRememberedInclude, savePackPrefs } from '../lib/packPrefs';
import { userConfigPath } from '../constants';
import { showOutput } from '../lib/output';

/** 工坊精简包默认排除的一级条目(另加: 根目录旧 zip 与 *.code-workspace) */
const PART_PACK_EXCLUDES = ['.git', '.vscode', '_temp', '_temp_fdp', 'DETAILS', 'exported', 'LSP', '.gitignore'];
/** 全量包默认排除的一级条目(另加: 根目录旧 zip) */
const FULL_PACK_EXCLUDES = ['.git', '.vscode', '_temp', '_temp_fdp', 'DETAILS'];

const isZipName = (name: string): boolean => /\.zip$/i.test(name);
const isWorkspaceName = (name: string): boolean => /\.code-workspace$/i.test(name);

/** 某个一级条目在指定预设下是否应勾选 */
function includedByPreset(name: string, preset: 'part' | 'full' | 'none'): boolean {
	if (preset === 'none') {
		return false;
	}
	const excludes = preset === 'part' ? PART_PACK_EXCLUDES : FULL_PACK_EXCLUDES;
	if (excludes.includes(name) || isZipName(name)) {
		return false;
	}
	// 工坊精简包不带上传无关的本地开发文件(编辑器工作区配置等)
	return preset === 'part' ? !isWorkspaceName(name) : true;
}

export async function pickAndPackDirectory(modRoot: string): Promise<void> {
	const entries = fs.readdirSync(modRoot, { withFileTypes: true })
		.filter(e => e.isDirectory() || e.isFile())
		.sort((a, b) => (Number(b.isDirectory()) - Number(a.isDirectory())) || a.name.localeCompare(b.name));
	if (entries.length === 0) {
		vscode.window.showErrorMessage(vscode.l10n.t('src.extension.extra.op.packzip-empty-dir'));
		return;
	}

	const items: vscode.QuickPickItem[] = entries.map(e => ({
		label: e.name,
		description: e.isDirectory() ? '' : undefined,
		iconPath: e.isDirectory() ? new vscode.ThemeIcon('folder') : new vscode.ThemeIcon('file'),
	}));

	const prefsPath = userConfigPath(PACK_PREFS_JSON);
	const remembered = getRememberedInclude(prefsPath, modRoot);
	// 初始勾选: 上次的选择(过滤掉已不存在的条目) > 工坊精简预设
	const initialSet = new Set(
		remembered?.filter(name => entries.some(e => e.name === name))
		?? entries.map(e => e.name).filter(name => includedByPreset(name, 'part')),
	);

	const buttonAll: vscode.QuickInputButton = { iconPath: new vscode.ThemeIcon('checklist'), tooltip: vscode.l10n.t('src.extension.extra.op.packzip-btn-all') };
	const buttonNone: vscode.QuickInputButton = { iconPath: new vscode.ThemeIcon('clear-all'), tooltip: vscode.l10n.t('src.extension.extra.op.packzip-btn-none') };
	const buttonPart: vscode.QuickInputButton = { iconPath: new vscode.ThemeIcon('cloud-upload'), tooltip: vscode.l10n.t('src.extension.extra.op.packzip-btn-part') };
	const buttonFull: vscode.QuickInputButton = { iconPath: new vscode.ThemeIcon('archive'), tooltip: vscode.l10n.t('src.extension.extra.op.packzip-btn-full') };

	const quickpick = vscode.window.createQuickPick<vscode.QuickPickItem>();
	quickpick.canSelectMany = true;
	quickpick.title = vscode.l10n.t('src.extension.extra.op.packzip-pick-title');
	quickpick.placeholder = remembered
		? vscode.l10n.t('src.extension.extra.op.packzip-pick-ph-remembered')
		: vscode.l10n.t('src.extension.extra.op.packzip-pick-ph');
	quickpick.matchOnDescription = false;
	quickpick.matchOnDetail = false;
	quickpick.items = items;
	quickpick.buttons = [buttonAll, buttonNone, buttonPart, buttonFull];
	quickpick.selectedItems = items.filter(i => initialSet.has(i.label));

	const applyPreset = (preset: 'all' | 'none' | 'part' | 'full'): void => {
		quickpick.selectedItems = preset === 'all'
			? items
			: preset === 'none'
				? []
				: items.filter(i => includedByPreset(i.label, preset));
	};

	quickpick.onDidTriggerButton(button => {
		if (button === buttonAll) { applyPreset('all'); }
		else if (button === buttonNone) { applyPreset('none'); }
		else if (button === buttonPart) { applyPreset('part'); }
		else if (button === buttonFull) { applyPreset('full'); }
	});

	quickpick.onDidAccept(async () => {
		const included = quickpick.selectedItems.map(i => i.label);
		quickpick.dispose();

		if (included.length === 0) {
			vscode.window.showWarningMessage(vscode.l10n.t('src.extension.extra.op.packzip-empty'));
			return;
		}

		const excludePaths = entries
			.filter(e => !included.includes(e.name))
			.map(e => path.join(modRoot, e.name));

		try {
			await packDirectoryToZip(modRoot, excludePaths);
			savePackPrefs(prefsPath, modRoot, included);
			vscode.window.showInformationMessage(vscode.l10n.t('src.extension.extra.op.packzip-remembered'));
			showOutput();
		} catch (error) {
			vscode.window.showErrorMessage(`Failed to pack zip: ${error}`);
		}
	});

	quickpick.show();
}
