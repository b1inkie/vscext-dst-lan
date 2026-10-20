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
		createOutputChannel: () => ({ appendLine() {}, show() {} }),
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
	// 临时工作区
	const wp = fs.mkdtempSync(path.join(os.tmpdir(), 'dstlan-e2e-'));
	stub.workspace.workspaceFolders = [{ uri: { fsPath: wp } }];

	const ext = require('../../out/extension.js');
	const context = { subscriptions: [] };
	ext.activate(context);
	assert.ok(registered.has('dst-lan.gen-mod'), 'gen-mod registered');
	assert.ok(registered.has('dst-lan.inject-avatar'), 'inject-avatar registered');
	assert.ok(registered.has('dst-lan.compiler'), 'compiler registered');
	assert.ok(registered.has('dst-lan.makeimg'), 'makeimg registered');
	assert.ok(registered.has('dst-lan.delete-comments'), 'delete-comments registered');
	assert.ok(registered.has('dst-lan.toggle-language'), 'toggle-language registered');
	assert.ok(registered.has('dst-lan.extrafn'), 'extrafn registered');
	assert.ok(!registered.has('dst-lan.pack-zip'), 'pack-zip removed (as decided)');
	console.log('[1] all 7 commands registered, pack-zip removed');

	// ---- gen-mod ----
	inputQueue = ['testmod'];
	await registered.get('dst-lan.gen-mod')();
	const mod = path.join(wp, 'testmod');
	assert.ok(fs.existsSync(path.join(mod, 'modinfo.lua')), 'modinfo.lua exists');
	let s = fs.readFileSync(path.join(mod, 'modinfo.lua'), 'utf8');
	assert.ok(s.includes("local modid = 'testmod'") && !s.includes('%(modid)s'), 'modinfo placeholders replaced');
	assert.ok(fs.existsSync(path.join(mod, 'scripts', 'core_testmod')), 'core folder renamed');
	assert.ok(!fs.existsSync(path.join(mod, 'scripts', 'core_modid')), 'old core folder gone');
	assert.ok(fs.existsSync(path.join(mod, `dst_mod-testmod.code-workspace`)), 'wp json renamed');
	assert.ok(fs.existsSync(path.join(mod, 'scripts', 'api_skins', 'testmod_skins.lua')), 'api_skins renamed');
	assert.ok(!fs.existsSync(path.join(mod, 'scripts', 'api_skins', 'modid_skins.lua')), 'old api_skins name gone');
	assert.ok(!fs.existsSync(path.join(mod, 'lan_modframe.md')) && !fs.existsSync(path.join(mod, '.modframe')), 'modframe files removed from template');
	s = fs.readFileSync(path.join(mod, 'modmain.lua'), 'utf8');
	assert.ok(s.includes("local modid = 'testmod'"), 'modmain modid replaced');
	assert.ok(s.includes('-- modimport('), 'modmain has callers list');
	// prefab 重命名与前缀
	const prefabs = fs.readdirSync(path.join(mod, 'scripts', 'prefabs'));
	assert.ok(prefabs.every(f => f.startsWith('testmod_')), 'prefabs prefixed: ' + prefabs.join(','));
	assert.ok(s.includes(`\t-- 'testmod_`), 'modmain prefabs list injected');
	// 全模板不再残留占位符(除有意保留的)
	const leftover = [];
	const walk = (d) => {
		for (const e of fs.readdirSync(d, { withFileTypes: true })) {
			const p = path.join(d, e.name);
			if (e.isDirectory()) { walk(p); }
			else if (/\.(lua|json|md)$/.test(e.name)) {
				const c = fs.readFileSync(p, 'utf8');
				if (c.includes('%(modid')) { leftover.push(p); }
				if (c.includes('%(avatarid')) { leftover.push(p); }
			}
		}
	};
	walk(mod);
	assert.deepStrictEqual(leftover, [], 'no leftover placeholders: ' + leftover.join(','));
	console.log('[2] gen-mod end-to-end OK (placeholders, renames, lists)');

	// ---- inject-avatar ----
	// 原版语义: modfolder 相对于当前编辑器文件所在目录, 因此编辑器指向 mod 父目录中的文件
	stub.window.activeTextEditor = { document: { uri: { fsPath: path.join(wp, 'rootfile.lua') }, languageId: 'lua' } };
	inputQueue = ['testmod', 'testmod', 'wilson2'];
	await registered.get('dst-lan.inject-avatar')();
	const av = (p) => fs.readFileSync(path.join(mod, ...p), 'utf8');
	assert.ok(fs.existsSync(path.join(mod, 'bigportraits', 'wilson2.png')), 'bigportrait renamed');
	assert.ok(fs.existsSync(path.join(mod, 'bigportraits', 'wilson2_none.png')), 'bigportrait none renamed');
	assert.ok(fs.existsSync(path.join(mod, 'exported', 'wilson2', 'wilson2.scml')), 'scml renamed');
	assert.ok(fs.existsSync(path.join(mod, 'exported', 'ghost_wilson2_build')), 'ghost build renamed');
	assert.ok(fs.existsSync(path.join(mod, 'scripts', 'prefabs', 'avatar_wilson2.lua')), 'avatar prefab renamed');
	assert.ok(!av(['modmain.lua']).includes('%(avatar_id_to_replace)s'), 'modmain avatar placeholder replaced');
	assert.ok(av(['modmain.lua']).includes("modimport('scripts/data_avatar/data_avatar_wilson2.lua')"), 'modmain avatar import updated');
	assert.ok(!av(['modmain.lua']).includes("-- modimport('scripts/data_avatar/wilson2.lua')"), 'modmain avatar import uncommented');
	assert.ok(!av(['scripts', 'prefabs', 'avatar_wilson2.lua']).includes('%(avatarid)s'), 'prefab placeholders replaced');
	assert.ok(!av(['scripts', 'prefabs', 'avatar_wilson2.lua']).includes('%(modid)s'), 'prefab modid replaced');
	assert.ok(!av(['exported', 'wilson2', 'wilson2.scml']).includes('%(avatarid)s'), 'scml placeholders replaced');
	console.log('[3] inject-avatar end-to-end OK');

// ---- makeimg ----
// 编辑器指向 mod 内部文件, findModInfoFile 向上找到 mod 根
stub.window.activeTextEditor = { document: { uri: { fsPath: path.join(mod, 'scripts', 'prefabs', 'some.lua') }, languageId: 'lua' } };
fs.mkdirSync(path.join(mod, '_temp'), { recursive: true });
for (const n of ['lan_img_ground.png', 'lan_img_inv.png', 'lan_img_swap.png']) {
	fs.copyFileSync(path.join('resource', 'prefabimg', n), path.join(mod, '_temp', n));
}
quickPickQueue = ['src.extension.makeimg.done'];
inputQueue = ['myprefab'];
await registered.get('dst-lan.makeimg')();
assert.ok(fs.existsSync(path.join(mod, 'exported', 'ground_myprefab', 'ground', 'myprefab.png')), 'ground png injected');
const groundScml = fs.readFileSync(path.join(mod, 'exported', 'ground_myprefab', 'myprefab.scml'), 'utf8');
assert.ok(groundScml.includes('ground/myprefab.png') && !groundScml.includes('%(prefab)s'), 'ground scml replaced');
const swapFrames = fs.readdirSync(path.join(mod, 'exported', 'swap_myprefab', 'swap_myprefab'));
assert.strictEqual(swapFrames.length, 10, '10 swap frames');
assert.ok(swapFrames.includes('swap_myprefab-0-9.png'), 'swap frame naming');
assert.ok(fs.existsSync(path.join(mod, 'images', 'inventoryimages', 'myprefab.png')), 'inventory png injected');
console.log('[4] makeimg end-to-end OK');
	// ---- delete-comments (经 WorkspaceEdit 桩回写) ----
	const luaText = 'local a = 1 -- c\nlocal s = "a--b"\n--[[ block ]]\n';
	let captured = null;
	stub.window.activeTextEditor = {
		document: {
			uri: { fsPath: path.join(wp, 'x.lua') },
			languageId: 'lua',
			getText: () => luaText,
			positionAt: (o) => o,
		},
	};
	stub.workspace.applyEdit = async (edit) => { captured = edit.ops[0].text; return true; };
	await registered.get('dst-lan.delete-comments')();
	assert.strictEqual(captured, 'local a = 1\nlocal s = "a--b"\n', 'comments stripped, string intact, trailing newline kept');
	console.log('[5] delete-comments end-to-end OK');

	const errors = statusMsgs.filter(m => m[0] === 'error');
	assert.deepStrictEqual(errors, [], 'no error messages: ' + JSON.stringify(errors));
	console.log('[6] zero error toasts during whole run');
	console.log('E2E SMOKE: ALL PASSED  (workspace: ' + wp + ')');
}

main().catch(e => { console.error('E2E FAILED:', e); console.error('statusMsgs:', JSON.stringify(statusMsgs, null, 2)); process.exit(1); });
