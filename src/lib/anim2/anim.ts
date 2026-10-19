/**
 * anim.bin(ANIM v4) 采样与写入。
 *
 * anim.bin(ANIM v4) 格式与采样规则：
 *
 *   'ANIM' v4
 *   u32 totalElements, u32 totalFrames, u32 0, u32 numAnims
 *   per anim:
 *     str name        // 已剥离方向后缀
 *     u8  facing      // 无后缀=0xFF
 *     u32 bankHash    // entity 名哈希
 *     f32 fps         // 固定 30
 *     u32 frameCount  // floor(length*30/1000) + 2
 *     per frame:
 *       f32 bx, by, bw, bh       // 所有元素四边形角点的世界包围盒中心/尺寸
 *       u32 0                    // 事件数（exe 不解析 event_line，恒 0）
 *       u32 nElements
 *       per element（按 z 升序）:
 *         u32 symbolHash, u32 frameNum, u32 layerHash,
 *         f32 m0..m5  // [cos*sx, -sin*sx, sin*sy, cos*sy, tx, -ty]
 *         f32 z       // (n-1-zIndex)/n*10 - 5
 *   u32 numNames, { u32 hash, str name }[]
 *
 * 采样时刻 t = k * 33ms（整数，实测 1000ms → 32 帧、每帧步进 33ms）。
 */
import { BinWriter, kleiHash } from './bins';
import { ScmlAnimation, ScmlDoc, ScmlKey, ScmlTimeline } from './scml';

export const FPS = 30;
export const MS_PER_FRAME = 33;

export const FACING_RIGHT = 1 << 0;
export const FACING_UP = 1 << 1;
export const FACING_LEFT = 1 << 2;
export const FACING_DOWN = 1 << 3;
export const FACING_UPRIGHT = 1 << 4;
export const FACING_UPLEFT = 1 << 5;
export const FACING_DOWNRIGHT = 1 << 6;
export const FACING_DOWNLEFT = 1 << 7;
export const FACING_ALL = 0xff;

/** 方向后缀 → facing 位（顺序敏感：长后缀优先），实测值见 probe/exp_anim2.py */
const SUFFIXES: [string, number][] = [
	['_downleft', FACING_DOWNLEFT],
	['_downright', FACING_DOWNRIGHT],
	['_downside', FACING_DOWNRIGHT | FACING_DOWNLEFT],
	['_upleft', FACING_UPLEFT],
	['_upright', FACING_UPRIGHT],
	['_upside', FACING_UPRIGHT | FACING_UPLEFT],
	['_90s', FACING_UP | FACING_DOWN | FACING_LEFT | FACING_RIGHT],
	['_45s', FACING_UPRIGHT | FACING_UPLEFT | FACING_DOWNRIGHT | FACING_DOWNLEFT],
	['_side', FACING_LEFT | FACING_RIGHT],
	['_down', FACING_DOWN],
	['_left', FACING_LEFT],
	['_right', FACING_RIGHT],
	['_up', FACING_UP],
];

export interface Element {
	symbolHash: number;
	frameNum: number;
	layerHash: number;
	m: [number, number, number, number, number, number];
	z: number;
}

export interface Frame {
	box: [number, number, number, number];
	elements: Element[];
}

export interface Animation {
	name: string;
	facing: number;
	bankHash: number;
	frames: Frame[];
}

/**
 * layer 基名: 递归剥末尾 `-<数字>`/`_<数字>` 后缀(实测: 'tail-4'/'tail_1'
 * 'hand_4_35'/'stunstar_4'/'foot_1' → bin 里为 'hand'/'stunstar'/'foot';
 * 非数字后缀如 'healingarrow_a' 保留)。
 */
export function baseLayerName(name: string): string {
	let n = name;
	while (/[-_]\d+$/.test(n)) {
		n = n.replace(/[-_]\d+$/, '');
	}
	return n;
}
export function splitDirection(name: string): { name: string; facing: number } {
	for (const [suffix, facing] of SUFFIXES) {
		if (name.endsWith(suffix)) {
			return { name: name.slice(0, -suffix.length), facing };
		}
	}
	return { name, facing: FACING_ALL };
}

/**
 * 按时间在关键帧序列里取插值。
 * prev = 最后一个 time <= t 的关键帧；t 恰好落在关键帧上时直接取该帧。
 * 末帧之后回绕到首帧（跨度 = length - last.time + first.time）。
 * instant（curve_type="instant"）时取 prev 原值（阶跃）。
 */
function sampleTrack(keys: ScmlKey[], t: number, length: number): ScmlKey {
	if (keys.length === 1) {
		return keys[0];
	}
	const first = keys[0];
	const last = keys[keys.length - 1];
	if (t <= first.time) {
		return first;
	}
	let idx = -1;
	for (let i = 0; i < keys.length; i++) {
		if (keys[i].time <= t) {
			idx = i;
		} else {
			break;
		}
	}
	if (idx < 0) {
		return first;
	}
	const prev = keys[idx];
	if (idx + 1 < keys.length) {
		const next = keys[idx + 1];
		if (prev.instant) {
			return prev;
		}
		const span = next.time - prev.time;
		return span > 0 ? blendKey(prev, next, (t - prev.time) / span) : prev;
	}
	// 回绕
	if (prev.instant) {
		return prev;
	}
	const span = length - prev.time + first.time;
	if (span <= 0) {
		return last;
	}
	return blendKey(prev, first, (t - prev.time) / span);
}

function lerp(a: number, b: number, t: number): number {
	return a + (b - a) * t;
}

/** 角度按 spin 方向插值 */
function lerpAngle(a0: number, a1: number, t: number, spin: number): number {
	let delta = a1 - a0;
	if (spin > 0) {
		while (delta < 0) {
			delta += 360;
		}
	} else if (spin < 0) {
		while (delta > 0) {
			delta -= 360;
		}
	} else {
		while (delta > 180) {
			delta -= 360;
		}
		while (delta < -180) {
			delta += 360;
		}
	}
	return a0 + delta * t;
}

function blendKey(a: ScmlKey, b: ScmlKey, t: number): ScmlKey {
	if (a.instant) {
		return a;
	}
	return {
		id: a.id,
		time: a.time,
		spin: a.spin,
		instant: false,
		obj: {
			folder: a.obj.folder,
			file: a.obj.file,
			x: lerp(a.obj.x, b.obj.x, t),
			y: lerp(a.obj.y, b.obj.y, t),
			angle: lerpAngle(a.obj.angle, b.obj.angle, t, a.spin),
			scaleX: lerp(a.obj.scaleX, b.obj.scaleX, t),
			scaleY: lerp(a.obj.scaleY, b.obj.scaleY, t),
			pivotX: lerp(a.obj.pivotX, b.obj.pivotX, t),
			pivotY: lerp(a.obj.pivotY, b.obj.pivotY, t),
		},
	};
}

type Mat = [number, number, number, number, number, number];

const IDENTITY: Mat = [1, 0, 0, 1, 0, 0];

/** Spriter 局部变换 → DST 矩阵（y 轴取反只作用于平移） */
export function localMatrix(x: number, y: number, angleDeg: number, sx: number, sy: number): Mat {
	const r = (angleDeg * Math.PI) / 180;
	const cos = Math.cos(r);
	const sin = Math.sin(r);
	return [cos * sx, -sin * sx, sin * sy, cos * sy, x, -y];
}

export function compose(m: Mat, n: Mat): Mat {
	return [
		m[0] * n[0] + m[2] * n[1],
		m[1] * n[0] + m[3] * n[1],
		m[0] * n[2] + m[2] * n[3],
		m[1] * n[2] + m[3] * n[3],
		m[0] * n[4] + m[2] * n[5] + m[4],
		m[1] * n[4] + m[3] * n[5] + m[5],
	];
}

function timelineKeys(map: Map<number, ScmlTimeline>, id: number): ScmlKey[] | undefined {
	const tl = map.get(id);
	return tl && tl.keys.length ? tl.keys : undefined;
}

/** 计算某时刻每个 object_ref 的世界矩阵 */
function worldMatrices(anim: ScmlAnimation, mainlineIndex: number, t: number): Map<number, Mat> {
	const mk = anim.mainline[mainlineIndex];
	const boneWorld = new Map<number, Mat>();
	const out = new Map<number, Mat>();

	// 骨骼先算（mainline 中已按父先子后排列）
	for (const bone of mk.bones) {
		const keys = timelineKeys(anim.boneTimelines, bone.timeline);
		const key = keys ? sampleTrack(keys, t, anim.length) : undefined;
		const local = key ? localMatrix(key.obj.x, key.obj.y, key.obj.angle, key.obj.scaleX, key.obj.scaleY) : IDENTITY;
		const parent = bone.parent >= 0 ? boneWorld.get(bone.parent) : undefined;
		boneWorld.set(bone.id, parent ? compose(parent, local) : local);
	}

	for (const obj of mk.objects) {
		const keys = timelineKeys(anim.timelines, obj.timeline);
		const key = keys ? sampleTrack(keys, t, anim.length) : undefined;
		const local = key ? localMatrix(key.obj.x, key.obj.y, key.obj.angle, key.obj.scaleX, key.obj.scaleY) : IDENTITY;
		const parent = obj.parent >= 0 ? boneWorld.get(obj.parent) : undefined;
		out.set(obj.id, parent ? compose(parent, local) : local);
	}
	return out;
}

function mainlineIndexAt(anim: ScmlAnimation, t: number): number {
	const keys = anim.mainline;
	if (keys.length === 0) {
		return -1;
	}
	let found = 0;
	for (let i = 0; i < keys.length; i++) {
		if (keys[i].time <= t) {
			found = i;
		} else {
			break;
		}
	}
	return found;
}

export interface FrameGeometry {
	/** file id -> 四边形角点（相对 pivot 的局部坐标） */
	corners: (frameNum: number) => [number, number][];
}

/**
 * 采样出 anim.bin 需要的动画帧。
 * @param symbolOf folderId -> { hash, name }
 * @param cornersOf (folderId, fileId) -> 该帧四边形的局部角点
 */
export function sampleAnimations(
	doc: ScmlDoc,
	cornersOf: (folderName: string, fileId: number) => [number, number][],
): Animation[] {
	const out: Animation[] = [];

	for (const entity of doc.entities) {
		for (const anim of entity.animations) {
		const { name, facing } = splitDirection(anim.name);
		// 实测：ceil(length / 33) + 1（distinguishing cases: 3301 -> 102, 5325 -> 163）
		const frameCount = Math.ceil(anim.length / MS_PER_FRAME) + 1;
		const frames: Frame[] = [];

		for (let k = 0; k < frameCount; k++) {
			const t = k * MS_PER_FRAME;
			const mlIndex = mainlineIndexAt(anim, t);
			const mk = mlIndex >= 0 ? anim.mainline[mlIndex] : undefined;
			if (!mk || mk.objects.length === 0) {
				frames.push({ box: [0, 0, 0, 0], elements: [] });
				continue;
			}
			const worlds = worldMatrices(anim, mlIndex, t);
			const n = mk.objects.length;

			const elements: Element[] = [];
			let minX = Infinity;
			let minY = Infinity;
			let maxX = -Infinity;
			let maxY = -Infinity;

			for (const obj of mk.objects) {
				const keys = timelineKeys(anim.timelines, obj.timeline);
				const key = keys ? sampleTrack(keys, t, anim.length) : undefined;
				if (!key) {
					continue;
				}
				const folder = doc.folders.find(f => f.id === key.obj.folder);
				if (!folder) {
					continue;
				}
				const file = folder.files.find(f => f.id === key.obj.file);
				if (!file) {
					continue;
				}
				const matrix = worlds.get(obj.id) ?? IDENTITY;
				const z = ((n - 1 - obj.zIndex) / n) * 10 - 5;
				elements.push({
					symbolHash: kleiHash(folder.name),
					frameNum: file.id,
				layerHash: kleiHash(baseLayerName(anim.timelines.get(obj.timeline)?.name ?? '')),
					m: matrix,
					z,
				});
				// 包围盒：四边形角点
				for (const [cx, cy] of cornersOf(folder.name, file.id)) {
					const wx = matrix[0] * cx + matrix[2] * cy + matrix[4];
					const wy = matrix[1] * cx + matrix[3] * cy + matrix[5];
					if (wx < minX) {
						minX = wx;
					}
					if (wx > maxX) {
						maxX = wx;
					}
					if (wy < minY) {
						minY = wy;
					}
					if (wy > maxY) {
						maxY = wy;
					}
				}
			}

			elements.sort((a, b) => a.z - b.z);
			const box: [number, number, number, number] = minX === Infinity
				? [0, 0, 0, 0]
				: [(minX + maxX) / 2, (minY + maxY) / 2, maxX - minX, maxY - minY];
			frames.push({ box, elements });
		}

			out.push({ name, facing, bankHash: kleiHash(entity.name), frames });
		}
	}
	return out;
}

/** 写入 anim.bin；names 为需要写进名字表的 (hash,name) */
export function writeAnimBin(anims: Animation[], names: Map<number, string>): Buffer {
	const w = new BinWriter();
	let totalElements = 0;
	let totalFrames = 0;
	for (const a of anims) {
		totalFrames += a.frames.length;
		for (const f of a.frames) {
			totalElements += f.elements.length;
		}
	}
	w.bytes(Buffer.from('ANIM', 'ascii'));
	w.u32(4);
	w.u32(totalElements);
	w.u32(totalFrames);
	w.u32(0);
	w.u32(anims.length);
	for (const a of anims) {
		w.str(a.name);
		w.u8(a.facing);
		w.u32(a.bankHash);
		w.f32(FPS);
		w.u32(a.frames.length);
		for (const f of a.frames) {
			w.f32(f.box[0]).f32(f.box[1]).f32(f.box[2]).f32(f.box[3]);
			w.u32(0);
			w.u32(f.elements.length);
			for (const e of f.elements) {
				w.u32(e.symbolHash);
				w.u32(e.frameNum);
				w.u32(e.layerHash);
				for (const v of e.m) {
					w.f32(v);
				}
				w.f32(e.z);
			}
		}
	}
	const entries = [...names.entries()].sort((a, b) => a[0] - b[0]);
	w.u32(entries.length);
	for (const [h, n] of entries) {
		w.u32(h);
		w.str(n);
	}
	return w.toBuffer();
}
