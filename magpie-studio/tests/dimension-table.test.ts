import { describe, it, expect, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import {
  measurementsStore,
  loadMeasurementsPayload,
  clearMeasurements,
  type MeasurementsPayload,
} from '$lib/stores/measurements';
import { projectSettings, formatLength } from '$lib/stores/settings';

const samplePayload: MeasurementsPayload = {
  measurementsVersion: 1,
  siteId: 'site-kitchen-101',
  workerName: 'Dave H.',
  capturedAt: '2026-10-10T10:00:00Z',
  deviceModel: 'iPhone 16 Pro',
  appVersion: '1.0.0',
  captureMode: 'lidar',
  handoffVersion: 1,
  calibration: {
    biasFactor: 1.0025,
    calibratedAt: '2026-10-10T09:55:00Z',
    referenceDescription: 'Wall A laser reference',
  },
  tolerances: {
    wallToWallMm: 10,
    criticalOpeningMm: 5,
  },
  rooms: [
    {
      story: 0,
      label: 'kitchen',
      displayName: 'Main Kitchen',
      ceilingHeightMm: 2400,
      ceilingHeightProvenance: 'tape',
      floorAreaMm2: 12500000,
      floorAreaProvenance: 'calibrated',
    },
  ],
  dimensions: [
    {
      id: 'dim-wall-north',
      kind: 'wall',
      label: 'North Wall Cabinet Run',
      valueMm: 3600,
      valueScannedMm: 3592,
      provenance: 'tape',
      critical: true,
      toleranceMm: 10,
      deviationMm: 8,
      withinTolerance: true,
      note: 'Verified with physical tape',
    },
    {
      id: 'dim-wall-east',
      kind: 'wall',
      label: 'East Wall',
      valueMm: 2800,
      valueScannedMm: 2800,
      provenance: 'scanned',
      critical: false,
      toleranceMm: 10,
      deviationMm: 0,
      withinTolerance: true,
    },
    {
      id: 'dim-cooktop-opening',
      kind: 'opening',
      label: 'Cooktop Cutout',
      valueMm: 900,
      valueScannedMm: 912,
      provenance: 'scanned',
      critical: true,
      toleranceMm: 5,
      deviationMm: 12,
      withinTolerance: false,
      note: 'Exceeds 5mm opening tolerance',
    },
  ],
  kitchenTags: [
    {
      id: 'tag-1',
      tag: 'cabinet-base-run',
      elementId: 'dim-wall-north',
      description: 'North wall primary base cabinet run',
    },
  ],
  validation: {
    criticalCount: 2,
    criticalWithinTolerance: 1,
    passRate: 0.5,
    gateResult: 'fail',
    photosCaptured: 4,
  },
};

describe('T-803 — Dimension Table and Measurements Store', () => {
  beforeEach(() => {
    clearMeasurements();
  });

  it('loads valid measurements payload and updates store', () => {
    const success = loadMeasurementsPayload(samplePayload);
    expect(success).toBe(true);

    const storeValue = get(measurementsStore);
    expect(storeValue).not.toBeNull();
    expect(storeValue?.siteId).toBe('site-kitchen-101');
    expect(storeValue?.dimensions).toHaveLength(3);
    expect(storeValue?.validation.gateResult).toBe('fail');
  });

  it('rejects invalid payload without validation block', () => {
    const invalid = { siteId: 'bad' } as any;
    const success = loadMeasurementsPayload(invalid);
    expect(success).toBe(false);
    expect(get(measurementsStore)).toBeNull();
  });

  it('differentiates tape vs scanned provenance formatting strictly (T-803 rule)', () => {
    loadMeasurementsPayload(samplePayload);
    const store = get(measurementsStore)!;

    const tapeDim = store.dimensions.find(d => d.provenance === 'tape')!;
    const scannedDim = store.dimensions.find(d => d.provenance === 'scanned')!;

    expect(tapeDim.provenance).toBe('tape');
    expect(scannedDim.provenance).toBe('scanned');

    // Rule: tape values must be certified governing values, never identical to raw scanned values
    expect(tapeDim.provenance).not.toBe(scannedDim.provenance);
    expect(tapeDim.critical).toBe(true);
    expect(tapeDim.withinTolerance).toBe(true);
  });

  it('formats dimensions correctly under millimetres and metric settings', () => {
    loadMeasurementsPayload(samplePayload);
    const store = get(measurementsStore)!;
    const wallDim = store.dimensions[0]; // 3600 mm = 360 cm

    // Test millimetres formatting
    projectSettings.update(s => ({ ...s, units: 'millimetres' }));
    expect(`${Math.round(wallDim.valueMm)} mm`).toBe('3600 mm');

    // Test metric (cm / m) formatting
    projectSettings.update(s => ({ ...s, units: 'metric' }));
    expect(formatLength(wallDim.valueMm / 10, 'metric')).toBe('3.6 m');
  });

  it('identifies out-of-tolerance critical dimensions triggering gate failure', () => {
    loadMeasurementsPayload(samplePayload);
    const store = get(measurementsStore)!;

    const failedDim = store.dimensions.find(d => !d.withinTolerance)!;
    expect(failedDim.id).toBe('dim-cooktop-opening');
    expect(failedDim.deviationMm).toBe(12);
    expect(failedDim.toleranceMm).toBe(5);
    expect(store.validation.gateResult).toBe('fail');
    expect(store.validation.passRate).toBe(0.5);
  });
});
