/**
 * Lua 注释删除(状态机实现)。
 *
 * 旧版用三段正则级联替换, 会误伤字符串字面量中的 "--"(例如
 * local s = "a--b" )。这里改为逐字符扫描:正确跳过引号字符串与
 * [[长字符串]], 只删除 -- 行注释与 --[[ ]] / --[=[ ]=] 块注释,
 * 最后去掉因删注释而变空的行(与旧版行为一致)。
 */

/** 删除 text 中的 Lua 注释与空行 */
export function stripLuaComments(text: string): string {
	const eol = text.includes('\r\n') ? '\r\n' : '\n';
	const n = text.length;
	const chunks: string[] = [];
	let i = 0;

	/** 若 text[start] 起是长括号开 [[ 或 [=[[, 返回 '=' 数量(级别), 否则 -1 */
	const longBracketLevel = (start: number): number => {
		if (start >= n || text[start] !== '[') {
			return -1;
		}
		let j = start + 1;
		let level = 0;
		while (j < n && text[j] === '=') {
			level++;
			j++;
		}
		return j < n && text[j] === '[' ? level : -1;
	};

	while (i < n) {
		const ch = text[i];

		// -- 注释
		if (ch === '-' && text[i + 1] === '-') {
			const level = longBracketLevel(i + 2);
			if (level >= 0) {
				// --[[ 块注释: 跳到匹配级别的闭括号
				const close = `]${'='.repeat(level)}]`;
				const end = text.indexOf(close, i);
				i = end === -1 ? n : end + close.length;
			} else {
				// 行注释: 跳到行尾(保留换行符)
				while (i < n && text[i] !== '\n' && text[i] !== '\r') {
					i++;
				}
			}
			continue;
		}

		// 引号字符串: 原样保留(其中的 -- 不是注释)
		if (ch === '"' || ch === "'") {
			const quote = ch;
			chunks.push(ch);
			i++;
			while (i < n) {
				const c = text[i];
				if (c === '\\') {
					chunks.push(c);
					if (i + 1 < n) {
						chunks.push(text[i + 1]);
					}
					i += 2;
					continue;
				}
				if (c === quote) {
					chunks.push(c);
					i++;
					break;
				}
				if (c === '\n' || c === '\r') {
					break; // 未闭合的字符串在行尾结束
				}
				chunks.push(c);
				i++;
			}
			continue;
		}

		// [[长字符串]]: 原样保留
		if (ch === '[') {
			const level = longBracketLevel(i);
			if (level >= 0) {
				const close = `]${'='.repeat(level)}]`;
				const end = text.indexOf(close, i);
				const stop = end === -1 ? n : end + close.length;
				chunks.push(text.slice(i, stop));
				i = stop;
				continue;
			}
		}

		chunks.push(ch);
		i++;
	}

	const stripped = chunks.join('');
	const endsWithNewline = /[\r\n]\s*$/.test(stripped);
	const lines = stripped
		.split(/\r?\n/)
		.map(line => line.trimEnd())
		.filter(line => line.length > 0);

	return lines.join(eol) + (endsWithNewline ? eol : '');
}
