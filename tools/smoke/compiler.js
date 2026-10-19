// 端到端冒烟: 在纯 node 环境用 vscode 桩激活扩展, 真实执行 gen-mod 与 inject-avatar 命令
const Module = require('module');
const path = require('path');
const fs = require('fs');
const os = require('os');
const assert = require('assert');

const registered = new Map();
let inputQueue = [];
let quickPickQueue = [];
let statusMsgs = [];
let outputLines = [];

const stub = {
	commands: {
		registerCommand: (id, cb) => { registered.set(id, cb); return { dispose() {} }; },
		executeCommand: async () => undefined,
	},
	languages: {
		registerCompletionItemProvider: () => ({ dispose() {} }),
	},
	window: {
		showInputBox: async () => inputQueue.shift(),
		showQuickPick: async () => quickPickQueue.shift(),
		showInformationMessage: (...a) => { statusMsgs.push(['info', ...a]); },
		showWarningMessage: (...a) => { statusMsgs.push(['warn', ...a]); },
		showErrorMessage: (...a) => { statusMsgs.push(['error', ...a]); },
		setStatusBarMessage: () => {},
		createOutputChannel: () => ({ appendLine(l) { outputLines.push(l); }, show() {} }),
		activeTextEditor: undefined,
	},
	workspace: {
		workspaceFolders: undefined,
		applyEdit: async () => true,
	},
	Uri: { file: (f) => ({ fsPath: f }) },
	ViewColumn: { One: 1 },
	l10n: { t: (k) => k },
	CompletionItem: class { constructor() {} },
	CompletionItemKind: { Text: 1 },
	MarkdownString: class { constructor(s) { this.value = s; } },
	WorkspaceEdit: class {
		constructor() { this.ops = []; }
		replace(uri, range, text) { this.ops.push({ uri, range, text }); }
	},
	Position: class {},
	Range: class {},
};

const orig = Module._load;
Module._load = function (request, ...rest) {
	if (request === 'vscode') { return stub; }
	return orig.call(this, request, ...rest);
};


async function main() {
  const fs = require('fs'), path = require('path'), os = require('os');
  const wp = 'D:/tmp/animlab/robust-SYYQdf';
  // 确保: images/broken.png 坏 + images/good.png 好 + exported/bad/bad.scml 坏 + exported/ok 工程好
  fs.copyFileSync('D:/tmp/animlab/quad20.png', path.join(wp, 'images', 'good.png'));
  fs.mkdirSync(path.join(wp, 'exported', 'ok'), {recursive: true});
  // 最小合法 scml(一张 4x4 图)
  fs.copyFileSync('D:/tmp/animlab/quad20.png', path.join(wp, 'exported', 'ok', 'a.png'));
  fs.writeFileSync(path.join(wp, 'exported', 'ok', 'ok.scml'),
    '<spriter_data><folder id="0" name="a"><file id="0" name="a.png" width="20" height="20"/></folder>' +
    '<entity id="0" name="e"><animation id="0" name="idle" length="100" interval="33">' +
    '<mainline><key id="0"><object_ref id="0" timeline="0" key="0" z_index="0"/></key></mainline>' +
    '<timeline id="0" name="a"><key id="0" time="0" spin="0"><object folder="0" file="0" x="0" y="0"/></key></timeline>' +
    '</animation></entity></spriter_data>');
  stub.window.activeTextEditor = { document: { uri: { fsPath: path.join(wp, 'modinfo.lua') } } };

  const ext = require('../../out/extension.js');
  const context = { subscriptions: [] };
  ext.activate(context);

  // 选择内置编译: compiler 命令进入 QuickPick? 查看编译器入口逻辑
  // (dst-lan.compiler 直接 doCompile? 若有模式选择需先选内置)
  quickPickQueue.length = 0;
  quickPickQueue.push('src.extension.compiler.switch_normal');
  inputQueue.length = 0;
  await registered.get('dst-lan.compiler')();
  console.log('--- toasts ---');
  for (const [k, m] of statusMsgs) console.log('[' + k + ']', String(m).slice(0, 110));
  console.log('--- output (warn/failed lines) ---');
  for (const l of outputLines) { if (/fail|FAIL|pack/i.test(l)) console.log(' ', String(l).slice(0, 140)); }
  console.log('--- 产物 ---');
  console.log('good.tex exists:', fs.existsSync(path.join(wp, 'images', 'good.tex')));
  console.log('anim/ok.zip exists:', fs.existsSync(path.join(wp, 'anim', 'ok.zip')));
  console.log('broken.png.tex absent (failed isolated):', !fs.existsSync(path.join(wp, 'images', 'broken.tex')));
}
main().catch(e => { console.error('FAILED:', e); process.exit(1); });
