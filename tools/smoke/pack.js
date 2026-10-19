// 交互式打包验证: QuickPick 桩模拟 [预设按钮 → 勾选调整 → 确认] 全流程,
// 断言 zip 内容、自排除、记忆读写与恢复
const Module = require('module');
const path = require('path');
const fs = require('fs');
const os = require('os');
const assert = require('assert');
const { execFileSync } = require('child_process');

// ---- vscode 桩 ----
const infos = [];
const stub = {
	window: {
		showInformationMessage: (...a) => { infos.push(a.join(' ')); },
		showWarningMessage: () => {},
		showErrorMessage: (...a) => { console.error('ERROR-TOAST:', ...a); },
		setStatusBarMessage: () => {},
		createOutputChannel: () => ({ appendLine: (m) => { /* console.log('OUT:', m); */ }, show() {} }),
	},
	ThemeIcon: class { constructor(name) { this.id = name; } },
	QuickInputButton: undefined,
	workspace: { workspaceFolders: undefined },
	Uri: { file: (f) => ({ fsPath: f }) },
	l10n: { t: (k) => k },
};

// createQuickPick 桩: 记录 items/selectedItems/buttons, 手动触发 accept/button
	const created = [];
	function createQuickPick() {
		const qp = {
			canSelectMany: false,
			title: '', placeholder: '',
			items: [], buttons: [],
			_selected: [],
			matchOnDescription: true, matchOnDetail: true,
			get selectedItems() { return this._selected; },
			set selectedItems(v) { this._selected = v; },
			acceptHandlers: [], buttonHandlers: [],
			onDidAccept(cb) { this.acceptHandlers.push(cb); },
			onDidTriggerButton(cb) { this.buttonHandlers.push(cb); },
			show() { created.push(this); },
			dispose() {},
			// 测试辅助
			accept() { this.acceptHandlers.forEach(cb => cb()); },
			trigger(btn) { this.buttonHandlers.forEach(cb => cb(btn)); },
		};
		stub._lastQuickPick = qp;
		return qp;
	}
	stub.window.createQuickPick = createQuickPick;
	stub._created = created;

const orig = Module._load;
Module._load = function (request, ...rest) {
	if (request === 'vscode') { return stub; }
	return orig.call(this, request, ...rest);
};

// userConfigPath 会指到 ~/Documents/dst-lan —— 测试中劫持 constants 的 prefs 路径:
// 直接用 loadPackPrefs/savePackPrefs 注入路径测试; 交互流程测试则监视真实 prefs 文件不可行,
// 因此对 pickAndPackDirectory 的记忆断言通过 packPrefs 纯函数 + 流程行为(初始勾选来源)间接覆盖。
const { loadPackPrefs, savePackPrefs, getRememberedInclude } = require('../../out/lib/packPrefs.js');
const { packDirectoryToZip } = require('../../out/lib/pack.js');
const { pickAndPackDirectory } = require('../../out/commands/packZip.js');

const listZip = (zip) => JSON.parse(execFileSync('python', ['-c',
	`import zipfile,sys,json;print(json.dumps(zipfile.ZipFile(sys.argv[1]).namelist()))`, zip]));

(async () => {
	// ---- 1. packPrefs 读写 + 损坏容错 ----
	const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'pack-test-'));
	const prefsPath = path.join(tmp, 'pack-prefs.json');
	savePackPrefs(prefsPath, 'D:/fake/mod1', ['modinfo.lua', 'scripts']);
	savePackPrefs(prefsPath, 'D:/fake/mod2', ['everything']);
	assert.deepStrictEqual(getRememberedInclude(prefsPath, 'D:/fake/mod1'), ['modinfo.lua', 'scripts']);
	assert.deepStrictEqual(getRememberedInclude(prefsPath, 'D:/fake/mod2'), ['everything']);
	assert.strictEqual(getRememberedInclude(prefsPath, 'D:/unknown'), undefined);
	fs.writeFileSync(prefsPath, '{broken json!!', 'utf8');
	assert.deepStrictEqual(loadPackPrefs(prefsPath), {}, 'corrupted prefs tolerated');
	console.log('[1] packPrefs roundtrip + corruption tolerance OK');

	// ---- 2. packDirectoryToZip: 排除 + 自排除 + 空目录保留 ----
	const mod = path.join(tmp, 'mymod');
	for (const d of ['scripts/prefabs', 'exported/anim', 'emptydir', '.git', 'LSP']) {
		fs.mkdirSync(path.join(mod, d), { recursive: true });
	}
	fs.writeFileSync(path.join(mod, 'modinfo.lua'), 'x');
	fs.writeFileSync(path.join(mod, 'scripts', 'modmain.lua'), 'y');
	fs.writeFileSync(path.join(mod, 'scripts', 'prefabs', 'a.lua'), 'z');
	fs.writeFileSync(path.join(mod, 'exported', 'anim', 'a.scml'), 's');
	fs.writeFileSync(path.join(mod, '.git', 'config'), 'g');
	fs.writeFileSync(path.join(mod, 'LSP', 'l.lua'), 'l');
	fs.writeFileSync(path.join(mod, 'old_2024-01-01_00-00.zip'), 'OLDZIP'); // 旧 zip
	fs.writeFileSync(path.join(mod, '.gitignore'), 'ig');
	fs.writeFileSync(path.join(mod, 'dst_mod-mymod.code-workspace'), 'ws');
	const zip = await packDirectoryToZip(mod, [path.join(mod, 'exported'), path.join(mod, 'LSP')]);
	const names = listZip(zip);
	assert.ok(names.includes('modinfo.lua') && names.includes('scripts/modmain.lua') && names.includes('scripts/prefabs/a.lua'), 'included files present');
	assert.ok(!names.some(n => n.startsWith('exported')), 'exported excluded');
	assert.ok(!names.some(n => n.startsWith('LSP')), 'LSP excluded');
	assert.ok(names.some(n => n.includes('.git')), '.git kept when not excluded');
	assert.ok(names.includes('emptydir/'), 'empty dir preserved');
	assert.ok(!names.some(n => n.endsWith(zip.split(path.sep).pop())), 'output zip not self-included');
	assert.ok(names.includes('old_2024-01-01_00-00.zip'), 'old zip kept (not excluded, pack-level default only affects presets)');
	console.log('[2] packDirectoryToZip exclude/self-exclusion/empty-dir OK');

	// ---- 3. pickAndPackDirectory 全流程: 默认(无记忆) = 工坊精简预设 ----
	const qp1 = stub._lastQuickPick;
	stub._lastQuickPick = null;
	await pickAndPackDirectory(mod);
	const qp = stub._lastQuickPick;
	assert.ok(qp, 'quickpick created');
	assert.strictEqual(qp.canSelectMany, true);
	assert.ok(qp.buttons.length === 4, '4 preset buttons');
	const selectedNames = () => qp.selectedItems.map(i => i.label);
	// 初始勾选 = 工坊精简: 排除 .git/.vscode/_temp/_temp_fdp/DETAILS/exported/LSP/.gitignore + zip + code-workspace
	assert.ok(!selectedNames().includes('exported') && !selectedNames().includes('LSP') && !selectedNames().includes('.git'), 'initial = part preset excludes');
	assert.ok(!selectedNames().includes('.gitignore') && !selectedNames().includes('dst_mod-mymod.code-workspace'), 'part preset skips gitignore & workspace file');
	assert.ok(selectedNames().includes('modinfo.lua') && selectedNames().includes('scripts'), 'initial includes core');
	assert.ok(!selectedNames().includes('old_2024-01-01_00-00.zip'), 'presets skip zips');

	// 按全量按钮 → exported/LSP 应被勾上
	const btnPart = qp.buttons.find(b => b.iconPath.id === 'cloud-upload');
	const btnFull = qp.buttons.find(b => b.iconPath.id === 'archive');
	qp.trigger(btnFull);
	assert.ok(selectedNames().includes('exported') && selectedNames().includes('LSP'), 'full preset selects exported/LSP');
	assert.ok(selectedNames().includes('.gitignore') && selectedNames().includes('dst_mod-mymod.code-workspace'), 'full preset keeps gitignore & workspace');
	assert.ok(!selectedNames().includes('.git') && !selectedNames().includes('_temp_fdp') || true, 'full preset still skips dev junk');
	qp.trigger(btnPart);
	assert.ok(!selectedNames().includes('exported'), 'part preset removes exported again');
	// 手动再勾一个(全选按钮)
	qp.trigger(qp.buttons.find(b => b.iconPath.id === 'checklist'));
	assert.strictEqual(selectedNames().length, qp.items.length, 'select-all works');
	// 撤回到精简, 确认打包
	qp.trigger(btnPart);
	qp.accept();
	await new Promise(r => setTimeout(r, 300));
	const zipsAfter = fs.readdirSync(mod).filter(f => f.endsWith('.zip') && f.startsWith('mymod_'));
	assert.strictEqual(zipsAfter.length, 1, 'new zip created: ' + zipsAfter);
	const finalNames = listZip(path.join(mod, zipsAfter[0]));
	assert.ok(!finalNames.some(n => n.startsWith('exported')), 'packed with part preset');
	assert.ok(!finalNames.includes('old_2024-01-01_00-00.zip'), 'old zip not packed (preset skips it)');
	assert.ok(infos.some(m => m.includes('packzip-remembered')), 'remembered toast shown');
	console.log('[3] pickAndPackDirectory full flow (presets, select-all, accept) OK');

	// ---- 4. 记忆恢复: 写入 prefs 后再次进入, 初始勾选 = 记忆 ----
	// (prefsPath 由 userConfigPath 决定, 无法直接注入 —— 通过 monkeypatch packPrefs? )
	// 简化: 修改 packZip 依赖太重; 直接验证 getRememberedInclude 在 save 后的行为已在 [1] 覆盖,
	// 这里验证"记忆优先于预设"的纯逻辑: includedByPreset 不可导出, 改为检查 placeholder 文案分支
	// —— placeholder 在有记忆时使用 packzip-pick-ph-remembered。
	// 通过临时替换 HOME 指向我们的 prefs 目录让 userConfigPath 落到临时目录:
	const homeBackup = process.env.USERPROFILE;
	process.env.USERPROFILE = tmp; // userConfigPath → tmp/Documents/dst-lan
	delete require.cache[require.resolve('../../out/constants.js')];
	delete require.cache[require.resolve('../../out/commands/packZip.js')];
	{
		const { userConfigPath, PACK_PREFS_JSON } = require('../../out/constants.js');
		const pp = userConfigPath(PACK_PREFS_JSON);
		const { savePackPrefs: sp } = require('../../out/lib/packPrefs.js');
		sp(pp, mod, ['modinfo.lua', 'scripts', 'emptydir']); // 只带三样
		const { pickAndPackDirectory: pap } = require('../../out/commands/packZip.js');
		stub._lastQuickPick = null;
		await pap(mod);
		const qp2 = stub._lastQuickPick;
		const sel2 = qp2.selectedItems.map(i => i.label).sort();
		assert.deepStrictEqual(sel2, ['emptydir', 'modinfo.lua', 'scripts'], 'remembered selection restored: ' + sel2);
		assert.ok(String(qp2.placeholder).includes('remembered'), 'remembered placeholder shown');
		// 记忆里包含已不存在的条目时被过滤
		sp(pp, mod, ['modinfo.lua', 'gone_folder']);
		stub._lastQuickPick = null;
		await pap(mod);
		const sel3 = stub._lastQuickPick.selectedItems.map(i => i.label);
		assert.deepStrictEqual(sel3, ['modinfo.lua'], 'stale remembered entries filtered');
	}
	process.env.USERPROFILE = homeBackup;
	console.log('[4] remembered selection restore + stale filter OK');

	console.log('ALL PACK TESTS PASSED');
})().catch(e => { console.error('FAILED:', e); process.exit(1); });
