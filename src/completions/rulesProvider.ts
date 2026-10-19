/**
 * 自定义规则补全提供者(custom_rules/rules.json)。
 *
 * rules.json 由若干 trigger 组成, 每个trigger 带一条正则;当光标前的
 * 文本命中正则且当前行存在对应的括号对时, 弹出该 trigger 的补全项。
 * 触发字符: " ' +
 *
 * 配置文件损坏/缺失时降级为"无规则", 不影响扩展激活。
 */
import * as vscode from 'vscode';
import { genPathIn } from '../constants';
import { readFileText } from '../lib/fsx';

interface RuleItem {
	label: string;
	documentation: string;
	author: string;
}

interface RuleTrigger {
	regex: string;
	pairs?: [string, string];
	kind?: vscode.CompletionItemKind;
	items: RuleItem[];
}

interface RulesFile {
	triggers: RuleTrigger[];
}

/** 检查当前行光标左右是否存在配对的括号(与旧版行为一致) */
function hasMatchingPair(document: vscode.TextDocument, position: vscode.Position, leftBracket: string, rightBracket: string): boolean {
	const line = document.lineAt(position).text;
	const before = line.substring(0, position.character);
	const after = line.substring(position.character);

	let foundLeft = false;
	for (let i = before.length - 1; i >= 0; i--) {
		const char = before[i];
		if (char === rightBracket) {
			return false;
		}
		if (char === leftBracket) {
			foundLeft = true;
			break;
		}
	}

	let foundRight = false;
	for (let i = 0; i < after.length; i++) {
		const char = after[i];
		if (char === leftBracket) {
			return false;
		}
		if (char === rightBracket) {
			foundRight = true;
			break;
		}
	}

	return foundLeft && foundRight;
}

/** 惰性加载规则(加载失败降级为空规则, 只警告一次) */
async function loadRules(): Promise<RulesFile> {
	const raw = await readFileText(genPathIn('custom_rules', 'rules.json'));
	if (raw === null) {
		return { triggers: [] };
	}
	try {
		const parsed = JSON.parse(raw) as RulesFile;
		return { triggers: Array.isArray(parsed.triggers) ? parsed.triggers : [] };
	} catch {
		return { triggers: [] };
	}
}

export function registerRulesCompletionProvider(langAuthor: string): vscode.Disposable {
	let cachedRules: RulesFile | undefined;

	const provider = {
		async provideCompletionItems(document: vscode.TextDocument, position: vscode.Position) {
			if (!cachedRules) {
				cachedRules = await loadRules();
			}
			const textBeforeCursor = document.lineAt(position).text.substring(0, position.character);

			for (const trigger of cachedRules.triggers) {
				let regex: RegExp;
				try {
					regex = new RegExp(trigger.regex);
				} catch {
					continue;
				}
				if (!regex.test(textBeforeCursor)) {
					continue;
				}
				if (trigger.pairs && !hasMatchingPair(document, position, trigger.pairs[0], trigger.pairs[1])) {
					continue;
				}

				return trigger.items.map(item => {
					const completionItem = new vscode.CompletionItem(item.label, trigger.kind);
					completionItem.documentation = new vscode.MarkdownString(`${item.documentation} \n\n※${langAuthor}: ${item.author}`);
					return completionItem;
				});
			}
			return undefined;
		},
	};

	return vscode.languages.registerCompletionItemProvider(
		{ scheme: 'file', language: 'lua' },
		provider,
		'"', "'", '+',
	);
}
