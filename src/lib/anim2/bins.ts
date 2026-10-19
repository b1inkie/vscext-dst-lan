/**
 * 饥荒动画二进制(build.bin / anim.bin)写入器与符号哈希。
 *
 * 按 BILD v6 / ANIM v4 格式的字段顺序写入(小端)。
 */

/** 符号哈希：逐字符转小写累加，h = c + (h<<6) + (h<<16) - h(饥荒内部同名算法) */
export function kleiHash(name: string): number {
	let h = 0;
	for (let i = 0; i < name.length; i++) {
		let v = name.charCodeAt(i);
		if (v >= 65 && v <= 90) {
			v += 32;
		}
		h = (v + ((h << 6) >>> 0) + ((h << 16) >>> 0) - h) >>> 0;
	}
	return h >>> 0;
}

/** 小端二进制写入器（仅本模块用，不依赖 node Buffer 的写法） */
export class BinWriter {
	private chunks: Buffer[] = [];
	private total = 0;

	u32(v: number): this {
		const b = Buffer.allocUnsafe(4);
		b.writeUInt32LE(v >>> 0, 0);
		this.chunks.push(b);
		this.total += 4;
		return this;
	}

	i32(v: number): this {
		const b = Buffer.allocUnsafe(4);
		b.writeInt32LE(v | 0, 0);
		this.chunks.push(b);
		this.total += 4;
		return this;
	}

	f32(v: number): this {
		const b = Buffer.allocUnsafe(4);
		b.writeFloatLE(v, 0);
		this.chunks.push(b);
		this.total += 4;
		return this;
	}

	u8(v: number): this {
		this.chunks.push(Buffer.from([v & 0xff]));
		this.total += 1;
		return this;
	}

	/** 字符串：u32 长度 + utf8 字节，无对齐填充 */
	str(s: string): this {
		const b = Buffer.from(s, 'utf8');
		this.u32(b.length);
		this.chunks.push(b);
		this.total += b.length;
		return this;
	}

	bytes(b: Buffer): this {
		this.chunks.push(b);
		this.total += b.length;
		return this;
	}

	get length(): number {
		return this.total;
	}

	toBuffer(): Buffer {
		return Buffer.concat(this.chunks, this.total);
	}
}
