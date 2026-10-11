import { describe, it, expect, vi } from 'vitest';
import { uploadHandoff, type HandoffSink } from '$lib/server/handoffUpload';
import { type QuotaSnapshot, type QuotaState } from '$lib/server/handoffQuota';
import { writePackageZip, readPackageZip, jsonBytes } from '$lib/utils/projectPackageZip';

const now = Date.UTC(2026, 9, 11, 10, 0, 0);

class TestHandoffSink implements HandoffSink {
  snapshot: QuotaSnapshot | null = null;
  storage = new Map<string, { bytes: Uint8Array; metadata?: Record<string, string> }>();

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
    this.storage.set(name, { bytes, metadata });
    return true;
  });

  seed() {
    this.snapshot = {
      state: {
        version: 1,
        day: Math.floor(now / 86_400_000),
        uploads: 0,
        bytes: 0,
        minute: Math.floor(now / 60_000),
        minuteUploads: 0,
      },
      generation: '1',
      metageneration: '1',
    };
  }
}

describe('WO-8: Phone -> Studio Handoff Package Round-trip', () => {
  it('builds package, uploads via route logic, retrieves by code, and verifies plan, measurements, and asset count survive', async () => {
    const sink = new TestHandoffSink();
    sink.seed();

    const planPayload = {
      openplanHandoffVersion: 1,
      createdAt: '2026-10-11T10:00:00Z',
      walls: [
        { id: 'wall-1', start: { x: 0, y: 0 }, end: { x: 300, y: 0 }, thickness: 20 }
      ]
    };

    const measurementsPayload = {
      measurementsVersion: 1,
      siteId: 'SITE-ROUNDTRIP-42',
      workerName: 'Field Inspector',
      capturedAt: '2026-10-11T10:00:00Z',
      deviceModel: 'iPhone 15 Pro',
      appVersion: '1.0.0',
      captureMode: 'lidar',
      handoffVersion: 1,
      tolerances: { wallToWallMm: 50, criticalOpeningMm: 20 },
      rooms: [],
      dimensions: [
        {
          id: 'dim-1',
          kind: 'wall',
          label: 'North Wall',
          valueMm: 3000,
          valueScannedMm: 3000,
          provenance: 'scanned',
          critical: true,
          toleranceMm: 20,
          deviationMm: 0,
          withinTolerance: true
        }
      ],
      kitchenTags: [],
      validation: {
        criticalCount: 1,
        criticalWithinTolerance: 1,
        passRate: 1.0,
        gateResult: 'pass',
        photosCaptured: 2
      }
    };

    const mockUsdzBytes = new Uint8Array([0x50, 0x4b, 0x03, 0x04, 0x01, 0x02, 0x03, 0x04]);
    const mockPhoto1 = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46]);
    const mockPhoto2 = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x01]);

    // 1. Build client-side package ZIP
    const packageZipBytes = writePackageZip({
      'manifest.json': jsonBytes({
        format: 'magpie-package',
        version: 1,
        producer: 'ios',
        title: 'Main Kitchen Scan',
        siteId: 'SITE-ROUNDTRIP-42',
        capturedAt: '2026-10-11T10:00:00Z',
        files: ['manifest.json', 'plan.json', 'measurements.json', 'model.usdz', 'photos/photo1.jpg', 'photos/photo2.jpg']
      }),
      'plan.json': jsonBytes(planPayload),
      'measurements.json': jsonBytes(measurementsPayload),
      'model.usdz': mockUsdzBytes,
      'photos/photo1.jpg': mockPhoto1,
      'photos/photo2.jpg': mockPhoto2
    });

    // 2. Simulate HTTP POST request with Content-Type: application/zip and x-magpie-package: true
    const request = new Request('https://studio.example.com/api/handoffs', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/zip',
        'Content-Length': String(packageZipBytes.byteLength),
        'x-magpie-package': 'true',
        'Authorization': 'Bearer test-bearer-token'
      },
      body: packageZipBytes as any,
      duplex: 'half'
    } as RequestInit);

    // 3. Process upload through route handler
    const response = await uploadHandoff(request, sink, now);

    expect(response).toBeDefined();
    expect(response.packageType).toBe('magpie-package');
    expect(response.code).toMatch(/^[A-Z0-9]{8}$/);
    expect(response.reuseUntil).toBe(new Date(now + 86_400_000).toISOString());

    // 4. Retrieve package from storage by generated code
    const storedObject = sink.storage.get(`inbox/${response.code}.magpie`);
    expect(storedObject).toBeDefined();
    expect(storedObject!.metadata?.packageType).toBe('magpie-package');

    // 5. Unpack retrieved ZIP and assert contents survive intact
    const unpacked = readPackageZip(storedObject!.bytes);
    expect(unpacked['plan.json']).toBeDefined();
    expect(unpacked['measurements.json']).toBeDefined();
    expect(unpacked['model.usdz']).toBeDefined();
    expect(unpacked['photos/photo1.jpg']).toBeDefined();
    expect(unpacked['photos/photo2.jpg']).toBeDefined();

    // Verify parsed plan.json
    const decodedPlan = JSON.parse(new TextDecoder().decode(unpacked['plan.json']));
    expect(decodedPlan.openplanHandoffVersion).toBe(1);
    expect(decodedPlan.walls).toHaveLength(1);
    expect(decodedPlan.walls[0].id).toBe('wall-1');

    // Verify parsed measurements.json
    const decodedMeasurements = JSON.parse(new TextDecoder().decode(unpacked['measurements.json']));
    expect(decodedMeasurements.siteId).toBe('SITE-ROUNDTRIP-42');
    expect(decodedMeasurements.validation.gateResult).toBe('pass');
    expect(decodedMeasurements.dimensions[0].label).toBe('North Wall');
    expect(decodedMeasurements.dimensions[0].valueMm).toBe(3000);

    // Verify binary assets byte-for-byte equality
    expect(new Uint8Array(unpacked['model.usdz'])).toEqual(new Uint8Array(mockUsdzBytes));
    expect(new Uint8Array(unpacked['photos/photo1.jpg'])).toEqual(new Uint8Array(mockPhoto1));
    expect(new Uint8Array(unpacked['photos/photo2.jpg'])).toEqual(new Uint8Array(mockPhoto2));

    // Verify asset count: 3 docs + 3 binary assets = 6 files
    expect(Object.keys(unpacked)).toHaveLength(6);
  });
});
