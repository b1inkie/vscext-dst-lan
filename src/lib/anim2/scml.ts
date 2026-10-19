/**
 * SCML(Spriter) 解析 —— 只保留打包实际需要的字段。
 *
 * 依据：exe .rdata 0x13674f5 处的属性名表
 *   angle scale_x scale_y pivot_x pivot_y folder interval mainline timeline
 *   spin curve_type instant object object_ref z_index
 * 以及 mainline 中的 bone_ref（0x11f269 "bone_ref"）。
 */
import { parseStringPromise } from 'xml2js';

export interface ScmlFile {
	id: number;
	name: string;
	width: number;
	height: number;
	pivotX: number;
	pivotY: number;
}

export interface ScmlFolder {
	id: number;
	name: string;
	files: ScmlFile[];
}

export interface ScmlObject {
	folder: number;
	file: number;
	x: number;
	y: number;
	angle: number;
	scaleX: number;
	scaleY: number;
	pivotX: number;
	pivotY: number;
}

export interface ScmlKey {
	id: number;
	time: number;
	spin: number;
	instant: boolean;
	obj: ScmlObject;
}

export interface ScmlTimeline {
	id: number;
	name: string;
	keys: ScmlKey[];
}

export interface BoneRef {
	id: number;
	parent: number;
	timeline: number;
	key: number;
}

export interface ObjectRef {
	id: number;
	parent: number;
	timeline: number;
	key: number;
	zIndex: number;
}

export interface MainlineKey {
	id: number;
	time: number;
	bones: BoneRef[];
	objects: ObjectRef[];
}

export interface ScmlAnimation {
	id: number;
	name: string;
	length: number;
	interval: number;
	mainline: MainlineKey[];
	/** object 时间线：timeline id -> timeline */
	timelines: Map<number, ScmlTimeline>;
	/** bone 时间线（key 内没有 <object>） */
	boneTimelines: Map<number, ScmlTimeline>;
}

export interface ScmlEntity {
	id: number;
	name: string;
	animations: ScmlAnimation[];
}

export interface ScmlDoc {
	folders: ScmlFolder[];
	/** 多 entity: 所有 entity 的动画都会导出(bank = entity 名) */
	entities: ScmlEntity[];
	/** 兼容旧引用: 首个 entity 名 */
	entityName: string;
	/** 兼容旧引用: 首个 entity 的动画 */
	animations: ScmlAnimation[];
}

type AnyNode = Record<string, unknown>;

function arr<T>(v: T | T[] | undefined | null): T[] {
	if (v === undefined || v === null) {
		return [];
	}
	return Array.isArray(v) ? v : [v];
}

function num(v: unknown, def = 0): number {
	if (v === undefined || v === null || v === '') {
		return def;
	}
	const n = typeof v === 'number' ? v : parseFloat(String(v));
	return Number.isFinite(n) ? n : def;
}

function boolish(v: unknown): boolean {
	return v === 'true' || v === '1' || v === true;
}

function attr(node: AnyNode, key: string): unknown {
	const a = node.$ as AnyNode | undefined;
	return a ? a[key] : undefined;
}

function parseObject(node: AnyNode | undefined): ScmlObject {
	return {
		folder: num(attr(node ?? {}, 'folder')),
		file: num(attr(node ?? {}, 'file')),
		x: num(attr(node ?? {}, 'x')),
		y: num(attr(node ?? {}, 'y')),
		angle: num(attr(node ?? {}, 'angle')),
		scaleX: num(attr(node ?? {}, 'scale_x'), 1),
		scaleY: num(attr(node ?? {}, 'scale_y'), 1),
		pivotX: num(attr(node ?? {}, 'pivot_x'), 0.5),
		pivotY: num(attr(node ?? {}, 'pivot_y'), 0.5),
	};
}

function parseKey(node: AnyNode): { key: ScmlKey; isObject: boolean } {
	const objNode = arr(node.object as AnyNode | AnyNode[])[0];
	return {
		key: {
			id: num(attr(node, 'id')),
			time: num(attr(node, 'time')),
			spin: num(attr(node, 'spin')),
			// Spriter 用 curve_type="instant" 表示阶跃插值；exe 两者都认
			instant: boolish(attr(node, 'instant')) || String(attr(node, 'curve_type') ?? '') === 'instant',
			obj: parseObject(objNode),
		},
		isObject: objNode !== undefined,
	};
}

export async function parseScml(xml: string): Promise<ScmlDoc> {
	const doc = (await parseStringPromise(xml, {
		explicitArray: false,
		mergeAttrs: false,
		attrkey: '$',
	})) as AnyNode;

	const root = (doc.spriter_data ?? {}) as AnyNode;

	const folders: ScmlFolder[] = arr(root.folder as AnyNode | AnyNode[]).map((f, fi) => ({
		id: num(attr(f, 'id'), fi),
		name: String(attr(f, 'name') ?? ''),
		files: arr(f.file as AnyNode | AnyNode[]).map((fl, idx) => ({
			id: num(attr(fl, 'id'), idx),
			name: String(attr(fl, 'name') ?? ''),
			width: num(attr(fl, 'width')),
			height: num(attr(fl, 'height')),
			pivotX: num(attr(fl, 'pivot_x'), 0.5),
			pivotY: num(attr(fl, 'pivot_y'), 0.5),
		})),
	}));

	const entityNodes = arr(root.entity as AnyNode | AnyNode[]);
	const parseEntity = (entity: AnyNode): ScmlAnimation[] => arr(entity.animation as AnyNode | AnyNode[]).map((an, ai) => {

		const mainlineNode = arr(an.mainline as AnyNode | AnyNode[])[0] ?? {};
		const mainline: MainlineKey[] = arr(mainlineNode.key as AnyNode | AnyNode[]).map(k => ({
			id: num(attr(k, 'id')),
			time: num(attr(k, 'time')),
			bones: arr(k.bone_ref as AnyNode | AnyNode[]).map(b => ({
				id: num(attr(b, 'id')),
				parent: num(attr(b, 'parent'), -1),
				timeline: num(attr(b, 'timeline')),
				key: num(attr(b, 'key')),
			})),
			objects: arr(k.object_ref as AnyNode | AnyNode[]).map(o => ({
				id: num(attr(o, 'id')),
				parent: num(attr(o, 'parent'), -1),
				timeline: num(attr(o, 'timeline')),
				key: num(attr(o, 'key')),
				zIndex: num(attr(o, 'z_index')),
			})),
		}));

		const timelines = new Map<number, ScmlTimeline>();
		const boneTimelines = new Map<number, ScmlTimeline>();
		for (const tl of arr(an.timeline as AnyNode | AnyNode[])) {
			const parsedKeys = arr(tl.key as AnyNode | AnyNode[]).map(parseKey);
			const timeline: ScmlTimeline = {
				id: num(attr(tl, 'id')),
				name: String(attr(tl, 'name') ?? ''),
				keys: parsedKeys.map(k => k.key),
			};
			const isObject = parsedKeys.some(k => k.isObject);
			(isObject ? timelines : boneTimelines).set(timeline.id, timeline);
		}

		return {
			id: num(attr(an, 'id'), ai),
			name: String(attr(an, 'name') ?? ''),
			length: num(attr(an, 'length'), 1000),
			interval: num(attr(an, 'interval'), 100),
			mainline,
			timelines,
			boneTimelines,
		};
	});

	const entities: ScmlEntity[] = entityNodes.map((e, ei) => ({
		id: num(attr(e, 'id'), ei),
		name: String(attr(e, 'name') ?? 'entity'),
		animations: parseEntity(e),
	}));
	const first = entities[0];
	return { folders, entities, entityName: first?.name ?? 'entity', animations: first?.animations ?? [] };
}
