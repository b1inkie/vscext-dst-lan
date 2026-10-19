/**
 * 帮助补全提供者(custom_rules/help.json), 触发字符 '?'。
 * 配置文件损坏/缺失时降级为"无规则", 不影响扩展激活。
 */
import * as vscode from 'vscode';
import { genPathIn } from '../constants';
import { readFileText } from '../lib/fsx';

interface HelpItem {
	label: string;
	documentation: string;
	author: string;
}

interface HelpTrigger {
	regex: string;
	items: HelpItem[];
}

interface HelpFile {
	triggers: HelpTrigger[];
}

async function loadHelp(): Promise<HelpFile> {
	const raw = await readFileText(genPathIn('custom_rules', 'help.json'));
	if (raw === null) {
		return { triggers: [] };
	}
	try {
		const parsed = JSON.parse(raw) as HelpFile;
		return { triggers: Array.isArray(parsed.triggers) ? parsed.triggers : [] };
	} catch {
		return { triggers: [] };
	}
}

export function registerHelpCompletionProvider(): vscode.Disposable {
	let cachedHelp: HelpFile | undefined;

	const provider = {
		async provideCompletionItems(document: vscode.TextDocument, position: vscode.Position) {
			if (!cachedHelp) {
				cachedHelp = await loadHelp();
			}
			const textBeforeCursor = document.lineAt(position).text.substring(0, position.character);

			for (const trigger of cachedHelp.triggers) {
				let regex: RegExp;
				try {
					regex = new RegExp(trigger.regex);
				} catch {
					continue;
				}
				if (regex.test(textBeforeCursor)) {
					return trigger.items.map(item => {
						const completionItem = new vscode.CompletionItem(item.label, vscode.CompletionItemKind.Text);
						completionItem.documentation = new vscode.MarkdownString(`${item.documentation}`);
						return completionItem;
					});
				}
			}
			return undefined;
		},
	};

	return vscode.languages.registerCompletionItemProvider(
		{ scheme: 'file', language: 'lua' },
		provider,
		'?',
	);
}
