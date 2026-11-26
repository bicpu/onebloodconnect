const privateImageStore = require('./privateImageStore');

async function sendPrivateImage(res, metadata, legacyValue) {
  try {
    const image = await privateImageStore.read({ metadata, legacyValue });
    res.set({
      'Content-Type': image.mimeType,
      'Content-Length': String(image.bytes.length),
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
      'Content-Disposition': 'inline; filename="proof-image"',
    });
    return res.status(200).send(image.bytes);
  } catch (error) {
    if (error.status === 503) {
      console.error('[Private image storage] Storage operation unavailable');
      return res.status(503).json({ error: 'private_storage_unavailable' });
    }
    return res.status(404).json({ error: 'image_not_found' });
  }
}

module.exports = sendPrivateImage;
