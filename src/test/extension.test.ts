import * as assert from 'assert';

// 一个最小冒烟测试:模块可被加载且导出 activate/deactivate。
// 纯函数(占位符替换 / Lua 去注释)的用例在 src/test/pure.test.ts 中。
suite('extension smoke', () => {
	test('module exports activate/deactivate', async () => {
		const ext = await import('../extension.js');
		assert.strictEqual(typeof ext.activate, 'function');
		assert.strictEqual(typeof ext.deactivate, 'function');
	});
});
