import { randomUUID } from 'node:crypto';
import { GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

export const ALLOWED_TYPES = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
};
export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

// STACKIT Object Storage ist S3-kompatibel: gleicher SDK, anderer Endpoint, Path-Style-Adressierung.
export function createStorage(s3) {
  if (!s3) return null;

  const client = new S3Client({
    endpoint: s3.endpoint,
    region: s3.region,
    forcePathStyle: true,
    credentials: { accessKeyId: s3.accessKeyId, secretAccessKey: s3.secretAccessKey },
    // Neuere SDK-Versionen senden standardmäßig CRC32-Checksummen. Nur mitschicken, wenn nötig –
    // das ist die robustere Einstellung für S3-kompatible Anbieter.
    requestChecksumCalculation: 'WHEN_REQUIRED',
    responseChecksumValidation: 'WHEN_REQUIRED',
  });

  async function putImage(buffer, contentType) {
    const ext = ALLOWED_TYPES[contentType];
    const key = `attachments/${randomUUID()}.${ext}`;
    await client.send(
      new PutObjectCommand({ Bucket: s3.bucket, Key: key, Body: buffer, ContentType: contentType }),
    );
    return key;
  }

  // Kurzlebige, signierte URL: Bucket bleibt privat, der Browser lädt das Bild direkt vom Object Storage.
  async function signedGetUrl(key) {
    return getSignedUrl(client, new GetObjectCommand({ Bucket: s3.bucket, Key: key }), {
      expiresIn: 900,
    });
  }

  return { putImage, signedGetUrl };
}
