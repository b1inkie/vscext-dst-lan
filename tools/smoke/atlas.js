// 图集打包交互流程冒烟: 选源文件夹 → 选输出目录(默认定位 mod/images) → 打包
const Module = require('module');
const orig = Module._load;
const registered = new Map();
let openDialogCalls = [];
let dialogs = [];
let activeEditor;

const vscodeStub = {
	commands: {
		registerCommand: (id, cb) => { registered.set(id, cb); return { dispose() {} }; },
	},
	languages: {
		registerCompletionItemProvider: () => ({ dispose() {} }),
	},
	window: {
		showInputBox: async () => undefined,
		showQuickPick: async () => undefined,
		showInformationMessage: (...a) => { console.log('[info]', ...a); },
		showWarningMessage: (...a) => { console.log('[warn]', ...a); },
		showErrorMessage: (...a) => { console.log('[error]', ...a); },
		setStatusBarMessage: () => {},
		createOutputChannel: () => ({ appendLine() {}, show() {} }),
		showOpenDialog: async (opts) => {
			dialogs.push(opts);
			return openDialogCalls.shift();
		},
		get activeTextEditor() { return activeEditor; },
	},
	workspace: { workspaceFolders: undefined, applyEdit: async () => true },
	Uri: { file: (f) => ({ fsPath: f }) },
	ViewColumn: { One: 1 },
	l10n: { t: (k) => k },
};

Module._load = function (request, ...rest) {
	if (request === 'vscode') {
		return vscodeStub;
	}
	return orig.call(this, request, ...rest);
};

const assert = require('assert');
const fs = require('fs');
const path = require('path');

async function main() {
	const { packFolderAsAtlas } = require('../../out/commands/extrafn.js');

	// 准备: mod 结构(有 images/) + 源文件夹(两张图)
	const wp = fs.mkdtempSync(path.join('D:/tmp/animlab', 'atlas-flow-'));
	const mod = path.join(wp, 'mymod');
	fs.mkdirSync(path.join(mod, 'images'), { recursive: true });
	fs.writeFileSync(path.join(mod, 'modinfo.lua'), 'name="t"');
	const srcDir = path.join(wp, 'pics');
	fs.mkdirSync(srcDir, { recursive: true });
	fs.copyFileSync('D:/tmp/animlab/quad20.png', path.join(srcDir, 'a.png'));
	fs.copyFileSync('D:/tmp/animlab/g256.png', path.join(srcDir, 'b.png'));

	// 场景1: 编辑器打开 mod 内文件 → 第二个对话框 defaultUri = mod/images, 输出到用户所选子目录
	activeEditor = { document: { uri: { fsPath: path.join(mod, 'modinfo.lua') } } };
	dialogs = [];
	const outDir = path.join(mod, 'images', 'ui');
	openDialogCalls = [
		[{ fsPath: srcDir }],   // 选源文件夹
		[{ fsPath: outDir }],   // 选输出目录
	];
	await packFolderAsAtlas();
	assert.strictEqual(dialogs.length, 2, 'two open dialogs');
	assert.strictEqual(dialogs[0].openLabel, 'src.extension.extra.op.atlas-pick-folder', 'first dialog picks source');
	assert.strictEqual(dialogs[1].openLabel, 'src.extension.extra.op.atlas-pick-outdir', 'second dialog picks outDir');
	assert.strictEqual(dialogs[1].defaultUri.fsPath, path.join(mod, 'images'), 'defaultUri = mod/images');
	assert.ok(fs.existsSync(path.join(outDir, 'pics.tex')), 'atlas tex in chosen outDir');
	assert.ok(fs.existsSync(path.join(outDir, 'pics.xml')), 'atlas xml in chosen outDir');
	console.log('[1] flow OK: pick src -> pick outDir (defaultUri=mod/images) -> atlas written to outDir');

	// 场景2: 第二个对话框取消 → 不打包
	fs.rmSync(outDir, { recursive: true, force: true });
	dialogs = [];
	openDialogCalls = [ [{ fsPath: srcDir }], undefined ];
	await packFolderAsAtlas();
	assert.strictEqual(dialogs.length, 2, 'both dialogs shown');
	assert.ok(!fs.existsSync(path.join(outDir, 'pics.tex')), 'cancelled -> nothing packed');
	console.log('[2] cancel on second dialog -> no packing');

	// 场景3: 无 mod 上下文(编辑器关着) → defaultUri 退到源文件夹父目录
	activeEditor = undefined;
	dialogs = [];
	openDialogCalls = [ [{ fsPath: srcDir }], [{ fsPath: wp }] ];
	await packFolderAsAtlas();
	assert.strictEqual(dialogs[1].defaultUri.fsPath, path.dirname(srcDir), 'no mod context -> defaultUri = parent of src');
	assert.ok(fs.existsSync(path.join(wp, 'pics.tex')), 'atlas in wp');
	console.log('[3] no-mod fallback OK (defaultUri = src parent)');

	fs.rmSync(wp, { recursive: true, force: true });
	console.log('ATLAS FLOW SMOKE: ALL PASSED');
}

main().catch(e => { console.error('FAILED:', e); process.exit(1); });
