const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const sharp = require('sharp');
const {
  createPrivateImageStore,
  PrivateImageError,
} = require('../src/storage/privateImageStore');

const temporaryRoot = path.join(os.tmpdir(), `oneblood-private-images-${process.pid}-${Date.now()}`);
const store = createPrivateImageStore({ root: temporaryRoot });

async function pngDataUri() {
  const bytes = await sharp({
    create: { width: 3, height: 2, channels: 4, background: '#cc0000' },
  }).png().toBuffer();
  return `data:image/png;base64,${bytes.toString('base64')}`;
}

test('stores re-encoded PNG with opaque key and complete metadata', async () => {
  await fs.mkdir(temporaryRoot, { recursive: true });
  const source = await pngDataUri();
  const metadata = await store.storeDataUri(source);
  assert.match(metadata.key, /^[0-9a-f-]{36}\.png$/i);
  assert.equal(metadata.mimeType, 'image/png');
  assert.ok(metadata.size > 0);
  assert.match(metadata.checksum, /^[a-f0-9]{64}$/);
  assert.ok(metadata.uploadedAt instanceof Date);

  const loaded = await store.read({ metadata });
  assert.deepEqual(loaded, {
    bytes: await fs.readFile(path.join(temporaryRoot, metadata.key)),
    mimeType: 'image/png',
  });
});

test('rejects malformed Base64, MIME mismatch, unsupported and invalid image bytes', async () => {
  await fs.mkdir(temporaryRoot, { recursive: true });
  await assert.rejects(store.storeDataUri('data:image/png;base64,%%%'),
    (error) => error instanceof PrivateImageError && error.code === 'invalid_image_data');
  const png = Buffer.from((await pngDataUri()).split(',')[1], 'base64');
  await assert.rejects(store.storeDataUri(`data:image/jpeg;base64,${png.toString('base64')}`),
    (error) => error instanceof PrivateImageError && error.code === 'unsupported_or_mismatched_image_type');
  await assert.rejects(store.storeDataUri(`data:image/png;base64,${Buffer.from('not an image').toString('base64')}`),
    (error) => error instanceof PrivateImageError && error.code === 'invalid_image_data');
  await assert.rejects(store.storeDataUri(`data:image/gif;base64,${Buffer.from('GIF89a').toString('base64')}`),
    (error) => error instanceof PrivateImageError && error.code === 'invalid_image_data');
});

test('enforces per-image and combined proof limits', async () => {
  await fs.mkdir(temporaryRoot, { recursive: true });
  const valid = await pngDataUri();
  const perImageLimit = createPrivateImageStore({ root: temporaryRoot, maxImageBytes: 10 });
  await assert.rejects(perImageLimit.storeDataUri(valid),
    (error) => error instanceof PrivateImageError && error.status === 413);

  const inputLength = Buffer.from(valid.split(',')[1], 'base64').length;
  const combinedLimit = createPrivateImageStore({
    root: temporaryRoot,
    maxImageBytes: inputLength + 100,
    maxProofBytes: inputLength * 2 - 1,
  });
  await assert.rejects(combinedLimit.storeSet({ first: valid, second: valid }),
    (error) => error instanceof PrivateImageError && error.code === 'proof_images_too_large');
});

test('rejects traversal keys and fails closed when configured storage is unavailable', async () => {
  assert.throws(() => store.resolveKey('../outside.png'),
    (error) => error instanceof PrivateImageError && error.status === 404);
  const missingRoot = createPrivateImageStore({ root: path.join(temporaryRoot, 'missing-root') });
  await assert.rejects(missingRoot.storeDataUri(await pngDataUri()),
    (error) => error instanceof PrivateImageError && error.status === 503);
});

test('cleans a successfully written first image when a later image fails validation', async () => {
  await fs.rm(temporaryRoot, { recursive: true, force: true });
  await fs.mkdir(temporaryRoot, { recursive: true });
  const valid = await pngDataUri();
  const invalid = `data:image/png;base64,${Buffer.from('bad content').toString('base64')}`;
  await assert.rejects(store.storeSet({ first: valid, second: invalid }));
  assert.deepEqual(await fs.readdir(temporaryRoot), []);
});

test('serves a legacy Base64 data URI through the same validated compatibility reader', async () => {
  const legacyValue = await pngDataUri();
  const image = await store.read({ legacyValue });
  assert.equal(image.mimeType, 'image/png');
  assert.ok(image.bytes.length > 0);
});

after(async () => {
  await fs.rm(temporaryRoot, { recursive: true, force: true });
});
