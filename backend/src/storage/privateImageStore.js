const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

const DEFAULT_MAX_IMAGE_BYTES = 2 * 1024 * 1024;
const DEFAULT_MAX_PROOF_BYTES = 4 * 1024 * 1024;
const MAX_PIXELS = 20_000_000;
const KEY_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(?:jpg|png)$/i;

class PrivateImageError extends Error {
  constructor(code, status = 400) {
    super(code);
    this.name = 'PrivateImageError';
    this.code = code;
    this.status = status;
  }
}

function positiveInteger(value, fallback) {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function decodeDataUri(value) {
  if (typeof value !== 'string') throw new PrivateImageError('invalid_image_data');
  const match = /^data:(image\/(?:jpeg|png));base64,([A-Za-z0-9+/]+={0,2})$/.exec(value);
  if (!match) throw new PrivateImageError('invalid_image_data');
  const encoded = match[2];
  const bytes = Buffer.from(encoded, 'base64');
  if (!bytes.length || bytes.toString('base64') !== encoded) {
    throw new PrivateImageError('invalid_image_data');
  }
  return { bytes, declaredMimeType: match[1] };
}

async function normalizeImage(bytes, declaredMimeType, maxImageBytes) {
  if (bytes.length > maxImageBytes) throw new PrivateImageError('image_too_large', 413);
  let metadata;
  try {
    metadata = await sharp(bytes, { failOn: 'error', limitInputPixels: MAX_PIXELS }).metadata();
  } catch (_) {
    throw new PrivateImageError('invalid_image_data');
  }
  const actualMimeType = metadata.format === 'jpeg'
    ? 'image/jpeg'
    : metadata.format === 'png'
      ? 'image/png'
      : null;
  if (!actualMimeType || actualMimeType !== declaredMimeType) {
    throw new PrivateImageError('unsupported_or_mismatched_image_type');
  }
  if (!metadata.width || !metadata.height || metadata.width * metadata.height > MAX_PIXELS) {
    throw new PrivateImageError('invalid_image_dimensions');
  }

  try {
    const pipeline = sharp(bytes, { failOn: 'error', limitInputPixels: MAX_PIXELS }).rotate();
    const output = actualMimeType === 'image/jpeg'
      ? await pipeline.jpeg({ quality: 85, mozjpeg: true }).toBuffer()
      : await pipeline.png({ compressionLevel: 9 }).toBuffer();
    if (!output.length || output.length > maxImageBytes) {
      throw new PrivateImageError('image_too_large', 413);
    }
    return { bytes: output, mimeType: actualMimeType };
  } catch (error) {
    if (error instanceof PrivateImageError) throw error;
    throw new PrivateImageError('invalid_image_data');
  }
}

function createPrivateImageStore({
  root = () => process.env.PRIVATE_FILE_STORAGE_PATH,
  maxImageBytes = positiveInteger(process.env.PRIVATE_FILE_MAX_IMAGE_BYTES, DEFAULT_MAX_IMAGE_BYTES),
  maxProofBytes = positiveInteger(process.env.PRIVATE_FILE_MAX_PROOF_BYTES, DEFAULT_MAX_PROOF_BYTES),
  now = () => new Date(),
  keyFactory = () => crypto.randomUUID(),
} = {}) {
  function getRoot() {
    const configured = typeof root === 'function' ? root() : root;
    if (typeof configured !== 'string' || !configured.trim()) {
      throw new PrivateImageError('private_storage_unavailable', 503);
    }
    return path.resolve(configured);
  }

  function resolveKey(key) {
    if (typeof key !== 'string' || !KEY_PATTERN.test(key)) {
      throw new PrivateImageError('private_file_not_found', 404);
    }
    const base = getRoot();
    const target = path.resolve(base, key);
    const relative = path.relative(base, target);
    if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) {
      throw new PrivateImageError('private_file_not_found', 404);
    }
    return { base, target };
  }

  async function storeDataUri(value) {
    const base = getRoot();
    try {
      const rootStats = await fs.stat(base);
      if (!rootStats.isDirectory()) throw new Error('not a directory');
    } catch (_) {
      throw new PrivateImageError('private_storage_unavailable', 503);
    }
    const { bytes, declaredMimeType } = decodeDataUri(value);
    const normalized = await normalizeImage(bytes, declaredMimeType, maxImageBytes);
    const key = `${keyFactory()}.${normalized.mimeType === 'image/jpeg' ? 'jpg' : 'png'}`;
    const { target } = resolveKey(key);
    try {
      await fs.writeFile(target, normalized.bytes, { flag: 'wx', mode: 0o600 });
      return {
        key,
        mimeType: normalized.mimeType,
        size: normalized.bytes.length,
        checksum: crypto.createHash('sha256').update(normalized.bytes).digest('hex'),
        uploadedAt: now(),
      };
    } catch (error) {
      await fs.unlink(target).catch(() => {});
      if (error.code === 'EEXIST') throw new PrivateImageError('private_storage_unavailable', 503);
      throw new PrivateImageError('private_storage_unavailable', 503);
    }
  }

  async function storeSet(values) {
    const entries = Object.entries(values || {}).filter(([, value]) => value !== undefined);
    let totalBytes = 0;
    for (const [, value] of entries) {
      const decoded = decodeDataUri(value);
      if (decoded.bytes.length > maxImageBytes) throw new PrivateImageError('image_too_large', 413);
      totalBytes += decoded.bytes.length;
    }
    if (totalBytes > maxProofBytes) throw new PrivateImageError('proof_images_too_large', 413);

    const stored = {};
    try {
      for (const [name, value] of entries) stored[name] = await storeDataUri(value);
      return stored;
    } catch (error) {
      await Promise.all(Object.values(stored).map((metadata) => remove(metadata).catch(() => {})));
      throw error;
    }
  }

  async function read({ metadata, legacyValue }) {
    if (metadata?.key) {
      const { base, target } = resolveKey(metadata.key);
      try {
        const rootStats = await fs.stat(base);
        if (!rootStats.isDirectory()) throw new PrivateImageError('private_storage_unavailable', 503);
        const bytes = await fs.readFile(target);
        if (bytes.length !== metadata.size ||
            crypto.createHash('sha256').update(bytes).digest('hex') !== metadata.checksum ||
            !['image/jpeg', 'image/png'].includes(metadata.mimeType)) {
          throw new PrivateImageError('private_file_not_found', 404);
        }
        return { bytes, mimeType: metadata.mimeType };
      } catch (error) {
        if (error instanceof PrivateImageError) throw error;
        if (error.code === 'ENOENT') {
          try {
            await fs.stat(base);
            throw new PrivateImageError('private_file_not_found', 404);
          } catch (rootError) {
            if (rootError instanceof PrivateImageError) throw rootError;
            throw new PrivateImageError('private_storage_unavailable', 503);
          }
        }
        throw new PrivateImageError('private_storage_unavailable', 503);
      }
    }

    if (typeof legacyValue !== 'string' || !legacyValue) {
      throw new PrivateImageError('private_file_not_found', 404);
    }
    let decoded;
    try {
      decoded = decodeDataUri(legacyValue);
    } catch (_) {
      throw new PrivateImageError('private_file_not_found', 404);
    }
    const legacyMaxBytes = Math.max(maxImageBytes, 6 * 1024 * 1024);
    const normalized = await normalizeImage(decoded.bytes, decoded.declaredMimeType, legacyMaxBytes);
    return { bytes: normalized.bytes, mimeType: normalized.mimeType };
  }

  async function remove(metadata) {
    if (!metadata?.key) return;
    const { target } = resolveKey(metadata.key);
    try {
      await fs.unlink(target);
    } catch (error) {
      if (error.code !== 'ENOENT') throw new PrivateImageError('private_storage_unavailable', 503);
    }
  }

  return { storeDataUri, storeSet, read, remove, resolveKey };
}

const privateImageStore = createPrivateImageStore();
module.exports = privateImageStore;
module.exports.createPrivateImageStore = createPrivateImageStore;
module.exports.PrivateImageError = PrivateImageError;
module.exports.DEFAULT_MAX_IMAGE_BYTES = DEFAULT_MAX_IMAGE_BYTES;
module.exports.DEFAULT_MAX_PROOF_BYTES = DEFAULT_MAX_PROOF_BYTES;
