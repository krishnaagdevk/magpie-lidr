import { describe, it, expect, vi } from 'vitest';
import { readCapture, uploadHandoff, type HandoffSink } from '$lib/server/handoffUpload';
import { MAGPIE_PACKAGE_LIMITS, MAGPIE_PACKAGE_MESSAGES, type QuotaSnapshot, type QuotaState } from '$lib/server/handoffQuota';
import { writePackageZip, jsonBytes } from '$lib/utils/projectPackageZip';

const now = Date.UTC(2026, 8, 5, 12, 0, 30);
const emptyState = (): QuotaState => ({
  version: 1,
  day: Math.floor(now / 86_400_000),
  uploads: 0,
  bytes: 0,
  minute: Math.floor(now / 60_000),
  minuteUploads: 0,
});

class MockPackageSink implements HandoffSink {
  snapshot: QuotaSnapshot | null = null;
  captures: { name: string; bytes: Uint8Array; metadata?: Record<string, string> }[] = [];

  read = vi.fn(async () => structuredClone(this.snapshot));
  write = vi.fn(async (previous: QuotaSnapshot | null, state: QuotaState) => {
    this.snapshot = {
      state: structuredClone(state),
      generation: '1',
      metageneration: String(Number(this.snapshot?.metageneration ?? '0') + 1),
    };
    return true;
  });
  create = vi.fn(async (name: string, bytes: Uint8Array, metadata?: Record<string, string>) => {
    this.captures.push({ name, bytes, metadata });
    return true;
  });
  seed(state: Partial<QuotaState>) {
    this.snapshot = { state: { ...emptyState(), ...state }, generation: '1', metageneration: '1' };
  }
}

function packageRequest(bytes: Uint8Array, headers: Record<string, string> = {}) {
  return new Request('https://example.test/api/handoffs', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/zip',
      'Content-Length': String(bytes.byteLength),
      ...headers,
    },
    body: bytes as any,
    duplex: 'half',
  } as RequestInit);
}

describe('T-804 — Extend upload route with package support', () => {
  it('accepts a complete Magpie package containing plan, measurements, usdz, and photos', async () => {
    const store = new MockPackageSink();
    store.seed({});

    const dummyPixel = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    const zipBytes = writePackageZip({
      'manifest.json': jsonBytes({ format: 'openplan3d-project', version: 1, producer: 'ios', title: 'Test Kitchen' }),
      'plan.json': jsonBytes({ openplanHandoffVersion: 1, walls: [] }),
      'measurements.json': jsonBytes({
        measurementsVersion: 1,
        siteId: 'site-kitchen-202',
        workerName: 'Alice',
        capturedAt: '2026-10-10T12:00:00Z',
        deviceModel: 'iPhone 16 Pro',
        appVersion: '1.0.0',
        captureMode: 'lidar',
        handoffVersion: 1,
        tolerances: { wallToWallMm: 10, criticalOpeningMm: 5 },
        rooms: [],
        dimensions: [],
        kitchenTags: [],
        validation: { criticalCount: 0, criticalWithinTolerance: 0, passRate: 1, gateResult: 'pass', photosCaptured: 1 },
      }),
      'model.usdz': new Uint8Array([0x50, 0x4b, 0x03, 0x04]),
      'photos/photo-01.png': dummyPixel,
    });

    const result = await uploadHandoff(packageRequest(zipBytes), store, now);
    expect(result.code).toHaveLength(8);
    expect(result.packageType).toBe('magpie-package');
    expect(store.captures).toHaveLength(1);
    expect(store.captures[0].name).toMatch(/^inbox\/[A-Z0-9]{8}\.magpie$/);
    expect(store.captures[0].metadata?.source).toBe('magpie-package-v1');
    expect(store.snapshot?.state.uploads).toBe(1);
    expect(store.snapshot?.state.bytes).toBe(zipBytes.byteLength);
  });

  it('rejects an oversized package exceeding MAGPIE_PACKAGE_LIMITS with HTTP 413', async () => {
    const oversizedLength = MAGPIE_PACKAGE_LIMITS.maxBytes + 1024;
    const req = new Request('https://example.test/api/handoffs', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/zip',
        'Content-Length': String(oversizedLength),
      },
      body: new Uint8Array(10),
      duplex: 'half',
    } as RequestInit);

    await expect(readCapture(req)).rejects.toMatchObject({
      status: 413,
      message: MAGPIE_PACKAGE_MESSAGES.tooLarge,
    });
  });

  it('rejects a package with invalid measurements sidecar', async () => {
    const badZipBytes = writePackageZip({
      'plan.json': jsonBytes({ openplanHandoffVersion: 1, walls: [] }),
      'measurements.json': jsonBytes({ invalid: true }),
    });

    await expect(readCapture(packageRequest(badZipBytes))).rejects.toMatchObject({
      status: 422,
    });
  });
});
