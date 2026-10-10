import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { importRoomPlanFloors } from '$lib/utils/roomplanImport';
import { validateRoomPlan } from '$lib/utils/roomplanValidation';

const plan = JSON.parse(readFileSync(new URL('./fixtures/handoff-plan.json', import.meta.url), 'utf8'));
const expected = JSON.parse(readFileSync(new URL('./fixtures/handoff-roomplan.json', import.meta.url), 'utf8'));

// Mirror of HandoffExporterV1 logic in MagpieCore
function exportHandoffFromPlan(native: any) {
  const wallMap = new Map();
  const walls = native.walls.map((w: any) => {
    wallMap.set(w.id, w);
    const dx = w.end.x - w.start.x;
    const dy = w.end.y - w.start.y;
    const length = Math.hypot(dx, dy);
    const angle = Math.atan2(dy, dx);
    const cosA = Math.cos(angle);
    const sinA = Math.sin(angle);
    const midX = (w.start.x + w.end.x) / 2.0;
    const midY = (w.start.y + w.end.y) / 2.0;
    const midZ = w.height / 2.0;

    return {
      identifier: w.id,
      dimensions: [length, w.height, w.thickness],
      transform: [
        cosA, 0.0, sinA, 0.0,
        0.0, 1.0, 0.0, 0.0,
        -sinA, 0.0, cosA, 0.0,
        midX, midZ, midY, 1.0
      ],
      category: { wall: {} },
      story: w.level
    };
  });

  const doors: any[] = [];
  const windows: any[] = [];
  const openings: any[] = [];

  for (const op of native.openings) {
    const parentWall = wallMap.get(op.wallID);
    if (!parentWall) continue;
    const dx = parentWall.end.x - parentWall.start.x;
    const dy = parentWall.end.y - parentWall.start.y;
    const angle = Math.atan2(dy, dx);
    const cosA = Math.cos(angle);
    const sinA = Math.sin(angle);
    const posX = parentWall.start.x + op.position * dx;
    const posY = parentWall.start.y + op.position * dy;

    if (op.kind === 'door') {
      doors.push({
        identifier: op.id,
        parentIdentifier: op.wallID,
        dimensions: [op.width, op.height, parentWall.thickness],
        transform: [
          cosA, 0.0, sinA, 0.0,
          0.0, 1.0, 0.0, 0.0,
          -sinA, 0.0, cosA, 0.0,
          posX, op.height / 2.0, posY, 1.0
        ],
        category: { door: {} },
        story: parentWall.level,
        style: op.style ?? 'single',
        hingeLeft: op.hingeLeft ?? true,
        opensInward: op.opensInward ?? false
      });
    } else if (op.kind === 'window') {
      windows.push({
        identifier: op.id,
        parentIdentifier: op.wallID,
        dimensions: [op.width, op.height, parentWall.thickness],
        transform: [
          cosA, 0.0, sinA, 0.0,
          0.0, 1.0, 0.0, 0.0,
          -sinA, 0.0, cosA, 0.0,
          posX, (op.sillHeight ?? 0.0) + op.height / 2.0, posY, 1.0
        ],
        category: { window: {} },
        story: parentWall.level,
        style: op.style ?? 'fixed',
        sillHeight: op.sillHeight ?? 0.0
      });
    }
  }

  const objects = (native.furniture ?? []).map((f: any) => {
    const cosA = Math.cos(f.angle);
    const sinA = Math.sin(f.angle);
    const height = f.height ?? (f.category === 'chair' ? 0.9 : 0.8);
    return {
      identifier: f.id,
      dimensions: [f.width, height, f.depth],
      transform: [
        cosA, 0.0, sinA, 0.0,
        0.0, 1.0, 0.0, 0.0,
        -sinA, 0.0, cosA, 0.0,
        f.center.x, height / 2.0, f.center.y, 1.0
      ],
      category: { [f.category]: {} },
      attributes: {},
      story: f.level
    };
  });

  const sections = (native.rooms ?? []).map((r: any) => ({
    center: [r.center.x, 0, r.center.y],
    label: r.name,
    displayName: r.name,
    color: r.colorHex,
    ceilingHeight: r.ceilingHeight,
    story: r.level
  }));

  const stories = (native.levels ?? []).map((l: any) => ({
    index: l.index,
    name: l.name
  }));

  return {
    openplanPrepared: true,
    openplanHandoffVersion: 1,
    walls,
    doors,
    windows,
    openings,
    objects,
    sections,
    stories,
    floors: [],
    defaults: {
      ceilingHeight: 2.4,
      interiorWallThickness: 0.12,
      exteriorWallThickness: 0.2
    },
    version: 2
  };
}

describe('T-603 Handoff round-trip verification', () => {
  it('encodes handoff-plan.json to match handoff-roomplan.json exactly', () => {
    const actual = exportHandoffFromPlan(plan);

    expect(actual.openplanPrepared).toBe(expected.openplanPrepared);
    expect(actual.openplanHandoffVersion).toBe(expected.openplanHandoffVersion);
    expect(actual.version).toBe(expected.version);
    expect(actual.floors).toEqual(expected.floors);
    expect(actual.defaults).toEqual(expected.defaults);

    // Walls comparison
    expect(actual.walls).toHaveLength(expected.walls.length);
    for (let i = 0; i < actual.walls.length; i++) {
      const a = actual.walls[i];
      const e = expected.walls[i];
      expect(a.identifier).toBe(e.identifier);
      expect(a.story).toBe(e.story);
      for (let j = 0; j < 3; j++) {
        expect(a.dimensions[j]).toBeCloseTo(e.dimensions[j], 6);
      }
      for (let j = 0; j < 16; j++) {
        expect(a.transform[j]).toBeCloseTo(e.transform[j], 6);
      }
    }

    // Doors comparison
    expect(actual.doors).toHaveLength(expected.doors.length);
    for (let i = 0; i < actual.doors.length; i++) {
      const a = actual.doors[i];
      const e = expected.doors[i];
      expect(a.identifier).toBe(e.identifier);
      expect(a.parentIdentifier).toBe(e.parentIdentifier);
      expect(a.story).toBe(e.story);
      expect(a.style).toBe(e.style);
      expect(a.hingeLeft).toBe(e.hingeLeft);
      expect(a.opensInward).toBe(e.opensInward);
      for (let j = 0; j < 3; j++) {
        expect(a.dimensions[j]).toBeCloseTo(e.dimensions[j], 6);
      }
      for (let j = 0; j < 16; j++) {
        expect(a.transform[j]).toBeCloseTo(e.transform[j], 6);
      }
    }

    // Windows comparison
    expect(actual.windows).toHaveLength(expected.windows.length);
    for (let i = 0; i < actual.windows.length; i++) {
      const a = actual.windows[i];
      const e = expected.windows[i];
      expect(a.identifier).toBe(e.identifier);
      expect(a.parentIdentifier).toBe(e.parentIdentifier);
      expect(a.story).toBe(e.story);
      expect(a.style).toBe(e.style);
      expect(a.sillHeight).toBeCloseTo(e.sillHeight, 6);
      for (let j = 0; j < 3; j++) {
        expect(a.dimensions[j]).toBeCloseTo(e.dimensions[j], 6);
      }
      for (let j = 0; j < 16; j++) {
        expect(a.transform[j]).toBeCloseTo(e.transform[j], 6);
      }
    }

    // Objects comparison
    expect(actual.objects).toHaveLength(expected.objects.length);
    for (let i = 0; i < actual.objects.length; i++) {
      const a = actual.objects[i];
      const e = expected.objects[i];
      expect(a.identifier).toBe(e.identifier);
      expect(a.story).toBe(e.story);
      for (let j = 0; j < 3; j++) {
        expect(a.dimensions[j]).toBeCloseTo(e.dimensions[j], 6);
      }
      for (let j = 0; j < 16; j++) {
        expect(a.transform[j]).toBeCloseTo(e.transform[j], 6);
      }
    }

    // Sections and stories
    expect(actual.sections).toEqual(expected.sections);
    expect(actual.stories).toEqual(expected.stories);
  });

  it('validates against roomplanValidation.ts without errors', () => {
    const actual = exportHandoffFromPlan(plan);
    expect(() => validateRoomPlan(actual)).not.toThrow();
  });

  it('imports cleanly into openPlan3D floor model', () => {
    const actual = exportHandoffFromPlan(plan);
    const floors = importRoomPlanFloors(actual);
    expect(floors).toHaveLength(3);
    expect(floors[0].walls).toHaveLength(4);
    expect(floors[1].walls).toHaveLength(1);
    expect(floors[2].walls).toHaveLength(0);
  });
});
