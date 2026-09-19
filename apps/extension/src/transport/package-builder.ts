const encoder = new TextEncoder();

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function write16(view: DataView, offset: number, value: number): void { view.setUint16(offset, value, true); }
function write32(view: DataView, offset: number, value: number): void { view.setUint32(offset, value, true); }

export class PackageBuilder {
  private readonly files = new Map<string, Uint8Array>();

  addText(path: string, contents: string): void { this.files.set(path, encoder.encode(contents)); }
  addJson(path: string, value: unknown): void { this.addText(path, `${JSON.stringify(value, null, 2)}\n`); }

  build(): Blob {
    const locals: Uint8Array[] = [];
    const centrals: Uint8Array[] = [];
    let offset = 0;
    for (const [path, data] of this.files) {
      const name = encoder.encode(path);
      const crc = crc32(data);
      const local = new Uint8Array(30 + name.length + data.length);
      const localView = new DataView(local.buffer);
      write32(localView, 0, 0x04034b50); write16(localView, 4, 20); write16(localView, 6, 0x0800);
      write16(localView, 8, 0); write32(localView, 14, crc); write32(localView, 18, data.length); write32(localView, 22, data.length);
      write16(localView, 26, name.length); local.set(name, 30); local.set(data, 30 + name.length); locals.push(local);

      const central = new Uint8Array(46 + name.length);
      const centralView = new DataView(central.buffer);
      write32(centralView, 0, 0x02014b50); write16(centralView, 4, 20); write16(centralView, 6, 20); write16(centralView, 8, 0x0800);
      write16(centralView, 10, 0); write32(centralView, 16, crc); write32(centralView, 20, data.length); write32(centralView, 24, data.length);
      write16(centralView, 28, name.length); write32(centralView, 42, offset); central.set(name, 46); centrals.push(central);
      offset += local.length;
    }
    const centralSize = centrals.reduce((sum, entry) => sum + entry.length, 0);
    const end = new Uint8Array(22);
    const endView = new DataView(end.buffer);
    write32(endView, 0, 0x06054b50); write16(endView, 8, this.files.size); write16(endView, 10, this.files.size);
    write32(endView, 12, centralSize); write32(endView, 16, offset);
    const parts = [...locals, ...centrals, end].map((part) => part.buffer.slice(part.byteOffset, part.byteOffset + part.byteLength) as ArrayBuffer);
    return new Blob(parts, { type: 'application/zip' });
  }
}
