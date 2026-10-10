import { randomBytes } from 'node:crypto';
import { isRoomPlanJson, validateRoomPlan } from '$lib/utils/roomplanValidation';
import { readPackageZip, packageJSON } from '$lib/utils/projectPackageZip';
import {
  HANDOFF_LIMITS,
  MAGPIE_PACKAGE_LIMITS,
  MAGPIE_PACKAGE_MESSAGES,
  HandoffError,
  reserveHandoff,
  reserveMagpiePackage,
  type QuotaStore
} from './handoffQuota';

export interface HandoffSink extends QuotaStore {
  create(name: string, bytes: Uint8Array, metadata?: Record<string, string>): Promise<boolean>;
}

export type UploadPayloadType = 'json' | 'magpie-package';

export interface ParsedUpload {
  bytes: Uint8Array;
  type: UploadPayloadType;
  metadata?: Record<string, string>;
}

/** Count the actual streamed bytes, even with missing or dishonest Content-Length. */
export async function readCapture(request: Request): Promise<Uint8Array> {
  const contentType = request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() ?? '';
  const isJson = contentType === 'application/json';
  const isZip = contentType === 'application/zip' ||
                contentType === 'application/x-zip-compressed' ||
                contentType === 'application/octet-stream' ||
                request.headers.get('x-magpie-package') === 'true';

  if (!isJson && !isZip) {
    throw new HandoffError(415, 'Link sharing accepts an editable plan JSON file or Magpie package bundle.');
  }

  if (request.headers.has('content-encoding') && request.headers.get('content-encoding') !== 'identity') {
    throw new HandoffError(415, 'Compressed request content-encoding is not supported.');
  }

  const maxAllowedBytes = isZip ? MAGPIE_PACKAGE_LIMITS.maxBytes : HANDOFF_LIMITS.maxBytes;
  const declaredLength = Number(request.headers.get('content-length'));
  if (declaredLength > maxAllowedBytes) {
    const errorMsg = isZip
      ? MAGPIE_PACKAGE_MESSAGES.tooLarge
      : 'This plan is too large for link sharing. Use Export Editable Plan (JSON) instead.';
    throw new HandoffError(413, errorMsg);
  }

  if (!request.body) throw new HandoffError(400, 'The upload body is empty.');
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  let timer: ReturnType<typeof setTimeout>;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new HandoffError(408, 'The upload took too long. Please try again.')), 10_000);
  });

  try {
    while (true) {
      const chunk = await Promise.race([reader.read(), timeout]);
      if (chunk.done) break;
      size += chunk.value.byteLength;
      if (size > maxAllowedBytes) {
        const errorMsg = isZip
          ? MAGPIE_PACKAGE_MESSAGES.tooLarge
          : 'This plan is too large for link sharing. Use Export Editable Plan (JSON) instead.';
        throw new HandoffError(413, errorMsg);
      }
      chunks.push(chunk.value);
    }
    const bytes = Buffer.concat(chunks);

    if (isJson) {
      try {
        const capture = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
        if (!isRoomPlanJson(capture)) throw new Error('Unrecognized RoomPlan export');
        validateRoomPlan(capture);
      } catch {
        throw new HandoffError(422, 'This capture cannot be shared. Check it using Export Editable Plan (JSON).');
      }
      (bytes as any).packageType = 'json';
      return bytes;
    } else {
      // Validate Magpie Package ZIP structure
      try {
        const files = readPackageZip(bytes);
        if (!files['plan.json'] && !files['manifest.json']) {
          throw new Error('Package must contain plan.json or manifest.json');
        }
        if (files['measurements.json']) {
          const measurements = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(files['measurements.json']));
          if (!measurements.validation || !Array.isArray(measurements.dimensions)) {
            throw new Error('Invalid measurements.json sidecar in package');
          }
        }
      } catch (err: any) {
        throw new HandoffError(422, `Invalid package archive: ${err?.message ?? 'Damaged or unsupported ZIP'}`);
      }
      (bytes as any).packageType = 'magpie-package';
      return bytes;
    }
  } finally {
    clearTimeout(timer!);
    void reader.cancel().catch(() => {});
  }
}

export async function uploadHandoff(request: Request, sink: HandoffSink, now = Date.now()) {
  const bytes = await readCapture(request);
  const isPackage = (bytes as any).packageType === 'magpie-package';

  if (isPackage) {
    await reserveMagpiePackage(sink, bytes.byteLength, now);
  } else {
    await reserveHandoff(sink, bytes.byteLength, now);
  }

  const reuseUntil = new Date(now + 86_400_000).toISOString();
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const ext = isPackage ? 'magpie' : 'json';

  for (let attempt = 0; attempt < 3; attempt++) {
    const code = [...randomBytes(8)].map(value => alphabet[value & 31]).join('');
    if (await sink.create(`inbox/${code}.${ext}`, bytes, {
      source: isPackage ? 'magpie-package-v1' : 'quota-v1',
      packageType: isPackage ? 'magpie-package' : 'json',
      reuseUntil,
    })) {
      return { code, reuseUntil, packageType: isPackage ? 'magpie-package' : 'json' };
    }
  }
  throw new HandoffError(503, 'Could not reserve a sharing code. Please try again.', 5);
}
