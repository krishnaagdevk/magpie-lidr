import { writable, derived } from 'svelte/store';

export type DimensionProvenance = 'scanned' | 'tape' | 'derived' | 'calibrated';

export interface MeasurementItem {
  id: string;
  kind: 'wall' | 'opening' | 'ceiling' | 'diagonal' | 'gap' | 'object' | string;
  label: string;
  valueMm: number;
  valueScannedMm: number;
  provenance: DimensionProvenance;
  critical: boolean;
  toleranceMm: number;
  deviationMm: number;
  withinTolerance: boolean;
  note?: string;
}

export interface CalibrationBlock {
  biasFactor: number;
  calibratedAt: string;
  referenceDescription: string;
}

export interface TolerancesBlock {
  wallToWallMm: number;
  criticalOpeningMm: number;
}

export interface RoomMeasurement {
  story: number;
  label: string;
  displayName: string;
  ceilingHeightMm: number;
  ceilingHeightProvenance: DimensionProvenance;
  floorAreaMm2: number;
  floorAreaProvenance: DimensionProvenance;
}

export interface KitchenTagItem {
  id: string;
  tag: string;
  dimensionId?: string;
  elementId?: string;
  description?: string;
}

export interface ValidationBlock {
  criticalCount: number;
  criticalWithinTolerance: number;
  passRate: number;
  gateResult: 'pass' | 'fail' | string;
  photosCaptured: number;
}

export interface MeasurementsPayload {
  measurementsVersion: number;
  siteId: string;
  workerName: string;
  capturedAt: string;
  deviceModel: string;
  appVersion: string;
  captureMode: string;
  handoffVersion: number;
  calibration?: CalibrationBlock;
  tolerances: TolerancesBlock;
  rooms: RoomMeasurement[];
  dimensions: MeasurementItem[];
  kitchenTags: KitchenTagItem[];
  validation: ValidationBlock;
}

export const measurementsStore = writable<MeasurementsPayload | null>(null);

export function loadMeasurementsPayload(data: MeasurementsPayload | string | null): boolean {
  if (!data) {
    measurementsStore.set(null);
    return true;
  }
  try {
    const payload: MeasurementsPayload = typeof data === 'string' ? JSON.parse(data) : data;
    if (!payload.validation || !Array.isArray(payload.dimensions)) {
      throw new Error('Invalid measurements payload: missing validation or dimensions array');
    }
    measurementsStore.set(payload);
    return true;
  } catch (err) {
    console.error('Failed to parse measurements.json:', err);
    return false;
  }
}

export function clearMeasurements(): void {
  measurementsStore.set(null);
}
