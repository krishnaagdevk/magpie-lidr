# Magpie LiDAR — Implementation Plan (v1)

**Purpose of this document.** Build specification for an AI coding agent (Gemini) to assemble a working v1 from four existing repositories. It states what to copy, what to write, what to delete, the exact data contract between the phone and the web, and the accuracy policy that governs every dimension the app produces.

**Read this whole document before writing code.** Sections 3, 4, and 6 contain constraints that will silently break the build if ignored.

**Companion document:** `GOALS_AND_TASKS.md` in this directory holds the task-level execution checklist, the verified-vs-unknown file inventory, and the anti-hallucination rules. Use it to drive the build; use this document to understand the design.

---

## Table of contents

1. [Product scope](#1-product-scope)
2. [Source repository analysis](#2-source-repository-analysis)
3. [The critical discovery: the handoff contract already exists](#3-the-critical-discovery-the-handoff-contract-already-exists)
4. [Target architecture](#4-target-architecture)
5. [Target repository layout](#5-target-repository-layout)
6. [The precision model — read before writing any dimension code](#6-the-precision-model--read-before-writing-any-dimension-code)
7. [Data contracts](#7-data-contracts)
8. [Guided capture engine](#8-guided-capture-engine)
9. [On-site correction engine](#9-on-site-correction-engine)
10. [Kitchen tagging and field metadata](#10-kitchen-tagging-and-field-metadata)
11. [Tape verification gate](#11-tape-verification-gate)
12. [Export pipeline](#12-export-pipeline)
13. [Offline storage, encryption, and sync](#13-offline-storage-encryption-and-sync)
14. [Designer-side web work](#14-designer-side-web-work)
15. [Milestones and task breakdown](#15-milestones-and-task-breakdown)
16. [Validation protocol](#16-validation-protocol)
17. [Explicitly out of scope — do not build](#17-explicitly-out-of-scope--do-not-build)
18. [Risks and mitigations](#18-risks-and-mitigations)
19. [Open decisions that must be answered before build](#19-open-decisions-that-must-be-answered-before-build)
20. [Capture modes and layout ingestion](#20-capture-modes-and-layout-ingestion)
21. [Appendix A — file copy map](#appendix-a--file-copy-map)
22. [Appendix B — RoomPlan API cheat sheet](#appendix-b--roomplan-api-cheat-sheet)
23. [Appendix C — build order quick reference](#appendix-c--build-order-quick-reference)

---

## 1. Product scope

### 1.1 Problem

A kitchen design company takes a 50% advance, sends a worker to measure a site by hand, then the designer builds a layout from hand-written notes. Slow, and note errors surface late — after design work has started.

### 1.2 v1 goal

An iOS app for LiDAR-equipped iPhone Pro / iPad Pro that lets a worker scan a kitchen in a few minutes and produce a dimensioned model plus a machine-readable dimension table that goes directly to the designer. It replaces hand-measurement for the **room shell only**: walls, corners, openings, ceiling height, and large fixed objects.

### 1.3 v1 non-goals

- Detecting water or power points.
- Recommending appliance placement.
- Generating cabinet layouts.
- Any LLM-based analysis.

These all depend on data the scanner cannot see. Design them separately, after v1 is validated.

### 1.4 Primary user

Field worker, no design training, working in a partly finished or occupied home, sometimes in poor light. Assume they will get the procedure wrong once. The app must make the correct next action obvious and make the wrong action hard.

### 1.5 Secondary user

Designer, at a desk, receiving the scan. Needs dimensions they can trust without re-measuring the whole room. Needs to know **which** numbers were measured by tape and which came from the scanner.

### 1.6 Device reality

The company owns one iPhone 16 Pro. That is enough for the prototype. Any multi-worker rollout depends on how many LiDAR devices exist — see [section 19](#19-open-decisions-that-must-be-answered-before-build).

---

## 2. Source repository analysis

Four repositories in `magpie_lidr/`. Each answers a different part of the problem.

### 2.1 Fulfillment scorecard

Scores are per-requirement, judged against the v1 core-function list in section 1.2.

| # | Requirement | iOS-RoomPlan | RoomPlanDemo | RoomPlanExampleApp | openPlan3D |
|---|---|:---:|:---:|:---:|:---:|
| 1 | Guided room capture with prompts | 15% | 20% | 60% | — |
| 2 | Auto detection + dimensions in mm | 5% | 30% | 60% | 40% |
| 3 | Manual on-site correction | 0% | 85% | 5% | 90% |
| 4 | Kitchen appliance/fixed-item tagging | 10% | 70% | 25% | 80% |
| 5 | Export model + measurements file | 20% | 55% | 75% | 70% |
| 6 | Offline capture + later upload | 50% | 20% | 85% | 40% |
| 7 | Tape-measure override / accuracy gate | 0% | 0% | 0% | 0% |
| 8 | Client/home data privacy controls | 30% | 10% | 50% | 30% |
| 9 | Field metadata (site ID, worker, timestamp) | 25% | 5% | 30% | 20% |
| | **Weighted total** | **~15%** | **~50%** | **~65%** | **~85% (designer side only)** |

### 2.2 iOS-RoomPlan — `iOS-RoomPlan/RoomPlanTest/`

Lightweight SwiftUI + SwiftData starter. `Views/RoomscanView.swift`, `ViewModels/ScanViewModel.swift`, `Models/Scan.swift`, `Utilities/ScanThumbnailGenerator.swift`.

- **Good:** clean SwiftUI structure; `Scan` / `Folder` models already represent "a named scan belonging to a grouping"; thumbnail generation.
- **Missing:** no dimensions, no editing, no structured export, no metadata.
- **Use it for:** the SwiftData model pattern for the scan library screen only. `Scan.swift` is a good starting shape for the local `SiteCapture` record.
- **Do not use:** the capture layer. It wraps `RoomCaptureView` too thinly.

### 2.3 RoomPlanDemo — `RoomPlanDemo/RoomPlanDemo/`

LiDAR capture plus an interactive **SpriteKit 2D floor-plan editor** generated immediately after the scan.

- **Good — this is the correction engine:**
  - `FloorPlan/FloorPlanScene.swift` — converts `CapturedRoom` into interactive 2D nodes.
  - `FloorPlan/FloorPlanSurface.swift`, `FloorPlanObject.swift`, `FloorPlanAnnotation.swift`, `FloorPlanViewModel.swift` — the editable model.
  - `CustomViews/SurfaceDetailsView/SurfaceDetailsView.swift` — slider editor for a wall's length, thickness, angle, position.
  - `CustomViews/ObjectDetailsView/ObjectDetailsView.swift` — object edit.
  - `CustomViews/AdjustMesurementView/AdjustMesurementView.swift` — measurement adjustment UI.
  - `CustomViews/AddFurnitureView/AddFurnitureView.swift` — appliance catalog including `stove`, `sink`, `dishwasher`, `refrigerator`, `storage`/cabinets.
  - `CustomViews/AnnotationsDetailsView/AnnotationsDetailsView.swift` — free-text notes dropped on the plan.
  - `Extensions/CapturedRoom+Extensions.swift`, `simd_float4x4+Extensions.swift`, `CGPoint+Extensions.swift` — geometry helpers.
- **Missing:** edits live in a display model and are **not** written back into the export. Slider units are internal scene points, not millimetres. No structured dimension export. Hardcoded output filenames.
- **Use it for:** the entire on-site correction UI and the `FloorPlanScene` rendering approach. This repo saves weeks.

### 2.4 RoomPlanExampleApp — `RoomPlanExampleApp/RoomPlanSimple/`

A hardened UIKit capture utility with multi-format export and real local storage.

- **Good — this is the foundation:**
  - `RoomCaptureViewController.swift` — capture session with delegate handling.
  - `MemoryMonitor.swift` — prevents memory crashes on dense scans.
  - `HapticFeedbackManager.swift` — tactile cues on detection and tracking loss.
  - `RoomCaptureError.swift` — typed errors and the `ExportFormat` enum (parametric / model / mesh / obj / stl / …).
  - `ScanStatistics.swift` — computes bounding boxes, floor area, ceiling height, wall area, dimensions. **This is the dimension engine seed.**
  - `FloorPlanExporter.swift` — SVG and DXF writers (603 lines).
  - `RoomExportManager.swift` — share-sheet dispatch.
  - `RoomStorageManager.swift` — full local library in `Application Support/SavedRooms/`, thumbnails, per-room folders, export bundles.
  - `PhotoCaptureManager.swift` — reference photos during scan.
  - `FloorPlanView.swift` / `FloorPlanViewController.swift` — read-only 2D plan with dimension overlay.
  - `Constants.swift`, `AppSettings.swift`, `LocalizationHelper.swift` with `en.lproj`, `de.lproj`, `es.lproj`.
- **Missing:** no editing at all. Dimensions in metres, not millimetres. No site ID or worker name. No tape workflow. No sync queue.
- **Contains dead weight — see [section 17](#17-explicitly-out-of-scope--do-not-build).** `WiFiSignalManager.swift`, `WiFiOverlayView.swift`, `RFPropagationModel.swift`, `RoomTypeDetector.swift`, `IfcExportBridge.swift`, `bimifc_ffi.swift`, and the `BimIfcFFI.xcframework` are all out of v1 scope. **Also check `Secrets.swift` before committing anything.**

### 2.5 openPlan3D — `openPlan3D/`

SvelteKit 5 + Three.js 2D/3D floor-plan CAD editor. Not an iOS app; browsers cannot run RoomPlan.

- **Good — and better than expected:**
  - `src/lib/utils/roomplanImport.ts` — parses RoomPlan JSON (transforms, dimensions, categories) into editable geometry.
  - `src/lib/utils/roomplanValidation.ts` — strict validator with typed failure messages.
  - `docs/handoff-format-v1.md` — **the written contract for the iPhone-to-web payload.**
  - `src/lib/server/handoffUpload.ts`, `handoffStorage.ts`, `handoffQuota.ts` — server-side upload endpoint with quota.
  - `src/routes/api/handoffs/` — the upload route.
  - `src/lib/firebase.ts` — Firebase auth already wired.
  - `tests/roomplan-import.test.ts`, `tests/fixtures/handoff-plan.json`, `tests/fixtures/handoff-roomplan.json` — contract fixtures.
  - Full kitchen furniture catalog, metric dimensions, DXF/SVG/PDF/PNG export, 2D/3D modes.
- **Missing:** no dimension table panel showing which values are tape-verified; no capture metadata display; no access control per site.
- **Use it for:** the whole designer side. Do not rewrite it.

---

## 3. The critical discovery: the handoff contract already exists

`openPlan3D/docs/handoff-format-v1.md` documents a payload format called the **iPhone → web geometry handoff, version 1**. It is emitted by the iPhone app's "Export Editable Plan (JSON)" and consumed by the web toolbar's **Export → Import JSON** or **Build → Import RoomPlan**. It is validated by `validateRoomPlan()` in `openPlan3D/src/lib/utils/roomplanValidation.ts`.

**None of the three iOS repositories in this folder emit that format.** A repository-wide search for `openplanPrepared`, `openplanHandoffVersion`, and `openplanImportOptions` across all `.swift` files returns zero hits.

The iPhone app that originally emitted it is a separate, private app from the same lineage (both `openPlan3D` and `RoomPlanExampleApp` are `theLodgeStudio` / `theLodgeBots` projects). It is not in this folder.

### 3.1 What this means for the build

The single highest-leverage task in this project is **writing the Swift exporter that emits handoff v1**. Everything else is assembly. Once that exporter exists and passes the web fixtures, the designer pipeline works end to end with no web changes for geometry.

### 3.2 The fixtures are executable specification

`openPlan3D/tests/fixtures/handoff-plan.json` is a synthetic native document. `openPlan3D/tests/fixtures/handoff-roomplan.json` is its expected handoff output. Per the doc, **identical copies live in the iOS test bundle**, and "Swift tests compare the actual exporter against every fixture key/value."

The fixtures and their copies are not present in these three repos. Obtain them from the openPlan3D repository at the version you fork, copy them into the new iOS test bundle, and write a Swift test that round-trips your exporter against them. **Do not hand-write a schema from the prose doc — use the fixtures.**

### 3.3 Contract rules that must be obeyed exactly

Extracted from `handoff-format-v1.md` and `roomplanValidation.ts`:

| Rule | Detail |
|---|---|
| Lengths | **Metres** in the payload, centimetres in the web model. Conversion rounds to eight decimal places. |
| Transforms | Column-major 4×4. Translation at indices 12–14. Local X direction is `(transform[0], transform[2])`. |
| Axis mapping | RoomPlan X → web X. RoomPlan Z → web Y. |
| Heading | `atan2(transform[2], transform[0])`, radians to degrees. |
| Identifiers | `identifier` values survive import and **must be unique across all elements**. |
| Openings | Reference a wall via `parentIdentifier`, and must be on the **same `story`**. |
| Floors | Integer `story`, absent means zero. `stories` array carries `{index, name}`, including intentionally empty floors. |
| Wall dimensions | `[length, height, thickness]`. Zero/missing raw-scan thickness falls back to 15 cm. |
| Doors | `style` ∈ `single` / `double` / `sliding` / `patio`. `hingeLeft` boolean. `opensInward` boolean. |
| Windows | `style` ∈ `fixed` / `sliding`. `sillHeight` in metres, non-negative. |
| Sections | `{center: [x,y,z], label, displayName?, color?}` per detected room. |
| Prepared flag | `openplanPrepared: true` disables automatic geometry straightening by default. |
| Version | `openplanHandoffVersion: 1`. An unknown version is rejected before replacing the project. |
| Validation | Any malformed element **rejects the whole import** and leaves the current project open. |

### 3.4 ZIP rules

- A **raw capture** ZIP must contain exactly one `room.json`. This is the unedited Apple output.
- A dataset containing `plan.json` is rejected by the raw-capture import path, with instructions to use Export Editable Plan JSON instead — because importing the raw `room.json` would silently discard the worker's edits.
- Therefore the exporter must produce **two distinct artifacts**: `room.json` for the raw path and `plan.json` for the edited path. See [section 12](#12-export-pipeline).

---

## 4. Target architecture

Two systems, one contract between them.

```
┌───────────────────────────────────────────────────────────────────┐
│  FIELD — iOS app  ("Magpie Field")                                │
│                                                                   │
│  Base: RoomPlanExampleApp                                         │
│    capture session, MemoryMonitor, Haptics, RoomStorageManager    │
│    ScanStatistics -> millimetre dimension engine                  │
│                                                                   │
│  + Correction engine ported from RoomPlanDemo                     │
│    FloorPlanScene, SurfaceDetailsView, ObjectDetailsView,         │
│    AddFurnitureView, AnnotationsDetailsView                       │
│    ** with edits written back to an exportable model **           │
│                                                                   │
│  + NEW: HandoffExporterV1  (the missing link)                     │
│  + NEW: CaptureMetadata  (site ID, worker, timestamp)             │
│  + NEW: TapeVerificationGate                                      │
│  + NEW: SyncQueue  (offline, encrypted, delete-after-upload)      │
└──────────────────────────────┬────────────────────────────────────┘
                               │  ZIP: room.json + plan.json
                               │       + measurements.json
                               │       + model.usdz
                               │       + photos/
                               ▼
┌───────────────────────────────────────────────────────────────────┐
│  OFFICE — web app  ("Magpie Studio", a fork of openPlan3D)        │
│                                                                   │
│  Existing: roomplanImport.ts, roomplanValidation.ts,               │
│            api/handoffs, firebase auth, 2D/3D editor, DXF/SVG      │
│                                                                   │
│  + NEW: dimension table panel (scanned vs tape-verified)          │
│  + NEW: capture metadata panel                                     │
│  + NEW: per-site access control                                    │
└───────────────────────────────────────────────────────────────────┘
```

### 4.1 Governing principle

**One source of truth for geometry: an `EditedPlan` model that seeds from `CapturedRoom` and is the only thing the exporter reads.** RoomPlanDemo's bug is that its edits live in a SpriteKit scene graph that is never serialised. Do not repeat that. Every edit mutates `EditedPlan`; the scene graph is a pure view of it.

---

## 5. Target repository layout

Two new repositories. Do not build inside the four existing ones — keep them as reference checkouts.

```
magpie-field/                       # iOS, Swift 5.9+, iOS 17+
├── MagpieField.xcodeproj
├── MagpieField/
│   ├── App/
│   │   ├── MagpieFieldApp.swift
│   │   ├── AppDelegate.swift
│   │   └── AppSettings.swift
│   ├── Capture/                    # from RoomPlanExampleApp
│   │   ├── RoomCaptureViewController.swift
│   │   ├── RoomCaptureError.swift
│   │   ├── MemoryMonitor.swift
│   │   ├── HapticFeedbackManager.swift
│   │   ├── PhotoCaptureManager.swift
│   │   └── CoverageAnalyzer.swift          # NEW
│   ├── Model/
│   │   ├── EditedPlan.swift                # NEW - single source of truth
│   │   ├── PlanWall.swift                  # NEW
│   │   ├── PlanOpening.swift               # NEW
│   │   ├── PlanObject.swift                # NEW
│   │   ├── PlanSection.swift               # NEW
│   │   ├── CaptureMetadata.swift           # NEW
│   │   ├── Measurement.swift               # NEW - scanned/tape/derived
│   │   └── KitchenTag.swift                # NEW
│   ├── Dimension/                  # from RoomPlanExampleApp, converted to mm
│   │   ├── ScanStatistics.swift
│   │   ├── DimensionEngine.swift           # NEW
│   │   └── CriticalDimension.swift         # NEW
│   ├── Editor/                     # from RoomPlanDemo
│   │   ├── FloorPlanScene.swift
│   │   ├── FloorPlanSceneView.swift
│   │   ├── FloorPlanSurface.swift
│   │   ├── FloorPlanObject.swift
│   │   ├── FloorPlanAnnotation.swift
│   │   ├── FloorPlanViewModel.swift
│   │   ├── SurfaceDetailsView.swift
│   │   ├── ObjectDetailsView.swift
│   │   ├── AdjustMesurementView.swift
│   │   ├── AddFurnitureView.swift
│   │   └── AnnotationsDetailsView.swift
│   ├── Export/
│   │   ├── HandoffExporterV1.swift         # NEW - the missing link
│   │   ├── MeasurementTableExporter.swift  # NEW
│   │   ├── UsdzExporter.swift              # from RoomPlanExampleApp
│   │   └── PackageBuilder.swift            # NEW - ZIP assembly
│   ├── Store/
│   │   ├── RoomStorageManager.swift        # from RoomPlanExampleApp
│   │   ├── SiteCapture.swift               # NEW - SwiftData record
│   │   └── Encryption.swift                # NEW
│   ├── Sync/
│   │   ├── SyncQueue.swift                 # NEW
│   │   └── SyncClient.swift                # NEW
│   ├── Flow/                       # NEW - the worker's screen sequence
│   │   ├── SiteSetupView.swift
│   │   ├── ScanFlowView.swift
│   │   ├── ReviewFlowView.swift
│   │   ├── TapeGateView.swift
│   │   ├── ExportFlowView.swift
│   │   └── LibraryView.swift
│   ├── Drafting/                   # NEW - M10/M11, deferred (section 20)
│   │   ├── RoomPolygon.swift               # derived node/vertex model
│   │   ├── RoomTemplate.swift              # preset vertex lists
│   │   ├── ManualScanFlowView.swift        # Mode B
│   │   ├── CornerPlotScene.swift           # Modes C + D
│   │   ├── BlueprintImportView.swift       # Mode E
│   │   └── ScaleCalibration.swift          # Mode E
│   ├── Takeoff/                    # NEW - M12, deferred (section 20.9)
│   │   └── TakeoffCalculator.swift
│   ├── Resources/
│   │   ├── en.lproj/ de.lproj/ es.lproj/
│   │   └── Fixtures/
│   │       ├── handoff-plan.json           # from openPlan3D tests
│   │       └── handoff-roomplan.json       # from openPlan3D tests
│   └── Info.plist
└── MagpieFieldTests/
    ├── HandoffExporterV1Tests.swift        # round-trips the fixtures
    ├── DimensionEngineTests.swift
    └── CriticalDimensionTests.swift

magpie-studio/                      # fork of openPlan3D
└── (existing tree, plus the additions in section 14)
```

---

## 6. The precision model — read before writing any dimension code

This section governs every number the app produces. Getting this wrong makes the product actively harmful: a designer who trusts a wrong number builds a cabinet that does not fit.

### 6.1 The hard truth

Apple's RoomPlan output is **accurate to a few centimetres, not millimetres.** LiDAR depth error, ARKit drift, and surface-material effects all compound. A 3.5 m wall may read 3.487 m or 3.512 m on consecutive passes.

The v1 target from the brief — 10 mm wall-to-wall, 5 mm critical openings — is **not achievable from scan data alone.** Any plan that presents scan values as certified will fail validation.

### 6.2 The three-tier dimension model

Every dimension in the app and in every export carries an explicit provenance. This is the central data-model decision.

```swift
enum DimensionProvenance: String, Codable {
    case scanned    // straight from RoomPlan. ADVISORY ONLY.
    case tape       // typed by the worker from a physical tape. GOVERNING.
    case derived    // computed from other dimensions (area, perimeter, run length)
    case calibrated // scanned, then bias-corrected by a known reference
}
```

Rules:

1. **Never overwrite a `scanned` value with a `tape` value.** Export both. The designer needs to see the disagreement — a 40 mm gap between scan and tape is itself information about the room.
2. **`derived` inherits the weakest provenance of its inputs.** A run length computed from three `scanned` walls is `scanned`. If any input is `tape`, it is at best `scanned` unless all inputs are `tape`.
3. **The UI must never show a `scanned` number in the same visual weight as a `tape` number.** Use colour and a label. A bare number with no provenance is a bug.

### 6.3 Units: millimetres are canonical

- **Store** lengths in metres as `Float`, matching RoomPlan's native output. Do not pre-round at storage time.
- **Convert** to millimetres at the display and export boundary only: `Int((metres * 1000).rounded())`.
- **Never** do arithmetic in millimetres and convert back. Rounding compounds.
- **Export** millimetres as integers in `measurements.json`; export metres as floats in `handoff.json` (the contract requires metres).

Float32 has roughly seven significant decimal digits. At 3.5 m that resolves far below 1 mm, so the raw storage type is not the precision limit — accumulated transform error is. Do not chase Float64; it will not help.

### 6.4 What actually governs cabinet fit

Not every wall needs a tape measurement. Tape is expensive; each one costs site time. The app must identify the small set of **critical dimensions** and force tape entry for exactly those.

Critical dimension rules for a kitchen:

| Critical | Rule | Rationale |
|---|---|---|
| Cabinet run wall length | Any wall with a tagged cabinet run (base or wall) | Determines total cabinet length |
| Opening width | Any door or window opening where an appliance or cabinet sits adjacent | Determines filler panels and appliance clearances |
| Ceiling height | Always, for the primary room | Determines wall-cabinet stack height |
| Corner-to-corner diagonal | Primary kitchen corners, if the room is not rectangular | Catches non-90° corners that scan smoothing hides |
| Appliance gap | Distance between two tagged fixed objects | Determines whether a unit fits |

Everything else stays `scanned` and is labelled advisory.

### 6.5 Bias calibration

Scan error is not purely random; it has a systematic component (scale bias) that repeats across a session and a device.

**Procedure:**

1. On the first scan of a new device, or after any iOS major update, the worker measures one known reference with a tape — a doorway, or a marked 2 m length on a wall.
2. The app compares the tape value to the scanned value of the same feature.
3. Store `biasFactor = tapeLength / scannedLength` per device, persisted in `AppSettings`.
4. Apply `biasFactor` to subsequent `scanned` dimensions in that session, marking them `calibrated`.
5. Re-calibrate if any `calibrated` value later disagrees with a fresh tape by more than the tolerance.

This is a small addition with a large effect: a consistent 1.5% scale bias on a 3.5 m wall is 52 mm of error, well outside any tolerance. Do not skip it. **Leave the bias factor user-visible and user-editable** — a real sensor drifts, and the physical world needs a tuning knob a fixed constant cannot provide.

### 6.6 Known error sources to expect

- Reflective surfaces, glass, and dark cabinetry reduce depth accuracy. Dark matte cabinetry in low light is the worst case.
- Incomplete wall coverage produces confidently wrong room geometry with no visible warning. This is why [section 8](#8-guided-capture-engine) computes closure explicitly rather than trusting RoomPlan's success callback.
- Device motion during capture skews transforms.
- Very long continuous scans accumulate drift; a long L-shaped kitchen degrades at the far end.

### 6.7 How the app must present this

- Every scan value in the review UI carries an "ADVISORY" badge unless it is `tape` or `calibrated`.
- The review screen opens with a persistent banner: *"Scanned dimensions are approximate. Verify highlighted dimensions with a tape before finalising."*
- The export carries a `confidence` block per dimension (see [section 7.3](#73-measurementsjson)).
- The designer UI renders `scanned` values in a muted style and `tape` values in a strong style. Never mix them in one column without a marker.

---

## 7. Data contracts

Three files ride in one ZIP. Each has one job.

### 7.1 `room.json` — raw Apple capture

Unmodified output of `CapturedRoom`'s built-in JSON encoding, plus the `openplanPrepared: false` state. Used by the web **Build → Import RoomPlan** path. Include it so the designer always has the untouched original for comparison. Exactly one `room.json` per ZIP.

### 7.2 `plan.json` — editable plan, handoff v1

The worker's corrected geometry, emitted per `openPlan3D/docs/handoff-format-v1.md`. This is the primary designer input. Requirements:

- `openplanHandoffVersion: 1`
- `openplanPrepared: true`
- `walls`, `doors`, `windows`, `openings`, `objects` arrays, each element with a unique `identifier`, a `dimensions` array, and a 16-element column-major `transform`
- Openings carry `parentIdentifier` pointing at a wall on the same `story`
- `stories` array of `{index, name}`
- `sections` array of `{center, label, displayName?, color?}`
- Resolved opening `style` on every door and window, including defaults
- `hingeLeft` and `opensInward` on every door
- `sillHeight` on every window
- Lengths in **metres**

**Validation before export.** Run the iOS exporter's own validator against the same rules as `roomplanValidation.ts` before writing the file. A malformed `plan.json` rejects the entire import on the web and leaves the designer with nothing. Catch it on the phone.

### 7.3 `measurements.json`

The dimension table. Deliberately **not** part of `handoff.json` — `validateRoomPlan()` ignores unknown top-level keys, but keeping the table in a sidecar means (a) the geometry contract stays byte-identical to what openPlan3D already accepts, and (b) the dimension table can carry data that has no place in a geometry payload.

```json
{
  "measurementsVersion": 1,
  "siteId": "SITE-2026-0142",
  "workerName": "R. Menon",
  "capturedAt": "2026-10-10T09:14:23Z",
  "deviceModel": "iPhone16,1",
  "appVersion": "1.0.0 (12)",
  "captureMode": "lidar",
  "handoffVersion": 1,
  "calibration": {
    "biasFactor": 1.0021,
    "calibratedAt": "2026-10-09T17:40:00Z",
    "referenceDescription": "doorway, left jamb to right jamb"
  },
  "tolerances": {
    "wallToWallMm": 10,
    "criticalOpeningMm": 5
  },
  "rooms": [
    {
      "story": 0,
      "label": "Kitchen",
      "displayName": "Kitchen",
      "ceilingHeightMm": 2740,
      "ceilingHeightProvenance": "tape",
      "floorAreaMm2": 11480000,
      "floorAreaProvenance": "scanned"
    }
  ],
  "dimensions": [
    {
      "id": "wall-3f2a",
      "kind": "wall",
      "label": "North run wall",
      "valueMm": 3512,
      "valueScannedMm": 3505,
      "provenance": "tape",
      "critical": true,
      "toleranceMm": 10,
      "deviationMm": 7,
      "withinTolerance": true,
      "note": ""
    },
    {
      "id": "obj-91bc",
      "kind": "opening",
      "label": "Window over sink",
      "valueMm": 1180,
      "valueScannedMm": 1172,
      "provenance": "tape",
      "critical": true,
      "toleranceMm": 5,
      "deviationMm": 8,
      "withinTolerance": false,
      "note": "re-measured twice, consistent"
    }
  ],
  "kitchenTags": [
    { "elementId": "obj-4d10", "category": "refrigerator", "label": "Existing fridge", "fixed": true },
    { "elementId": "wall-3f2a", "category": "base-cabinet-run", "label": "Proposed base run", "fixed": false }
  ],
  "validation": {
    "criticalCount": 6,
    "criticalWithinTolerance": 5,
    "passRate": 0.833,
    "gateResult": "fail",
    "photosCaptured": 4
  }
}
```

Field notes:

- `valueMm` is the governing value — the tape value where one exists, otherwise the scanned value.
- `valueScannedMm` is always present, so the designer can always see the raw scan.
- `deviationMm` is `abs(valueMm - valueScannedMm)`. It is not an error metric on its own; large values tell the designer where the scanner struggled.
- `gateResult` is `pass` or `fail` per [section 16](#16-validation-protocol). A `fail` does not block export — it flags the package for designer attention. Blocking export would push workers to lie.
- `captureMode` is `lidar` / `manual` / `template` / `corners` / `blueprint`. A `manual` package has no scanner error to fight — every dimension is tape. A `blueprint` package needs its calibration error considered. See [section 20](#20-capture-modes-and-layout-ingestion).
- `kitchenTags` reference element identifiers in `plan.json`, so the designer can join the two files.

### 7.4 `model.usdz` and `photos/`

- `model.usdz` — the RoomPlan USDZ export. Which variant (`parametric` / `model` / `mesh`) is a v1 decision; see [section 19](#19-open-decisions-that-must-be-answered-before-build). Default to `parametric` for size.
- `photos/` — reference photos from `PhotoCaptureManager`, named `photo-01.jpg` etc., with an index in `measurements.json` if you want the designer UI to link them.

---

## 8. Guided capture engine

Source: `RoomPlanExampleApp/RoomPlanSimple/RoomCaptureViewController.swift`, `MemoryMonitor.swift`, `HapticFeedbackManager.swift`.

### 8.1 What already works

The capture session, delegate wiring, memory guard, and haptics are production-shaped. Copy them.

### 8.2 What to add — three explicit warnings

The brief requires prompts for **missed walls**, **low coverage**, and **scanning too fast**. Build these as a `CoverageAnalyzer` that evaluates live ARKit data.

**A. Scanning too fast.**

Track the camera's world-space translation between consecutive `ARFrame`s. Compute metres per second. If it exceeds a threshold (~0.6 m/s sustained over ~1 s), show a *"Slow down"* banner and stop accepting volume additions. Also read `ARCamera.trackingState`; on `.limited(.excessiveMotion)` show the same warning. Haptic warning tap on entry.

**B. Low light / poor tracking.**

`ARCamera.trackingState == .limited(.insufficientFeatures)` means the room is too dark or too featureless for reliable depth. This is the specific failure mode of a partly finished home at night. Show a persistent *"Move to better light"* banner and mark the resulting scan as `lowConfidence` in `measurements.json` so the designer knows.

**C. Missed walls / incomplete coverage.**

This is the one RoomPlan will not tell you about, and the one that produces confidently wrong geometry. After the session ends, before showing results:

1. Run `RoomBuilder` on the captured data to get a `CapturedRoom`.
2. Extract wall endpoints on the ground plane from each wall's `transform` and `dimensions[0]`.
3. Order the walls into a chain by matching endpoints within a 200 mm tolerance.
4. **Check closure.** If the chain does not close — first endpoint near last endpoint — the room is open. Report the gap size and the gap's location.
5. **Check coverage.** Sum wall lengths and compare to the floor polygon perimeter from `sections`. A shortfall above ~15% means a missed wall.
6. **Check sanity.** If the wall count is below 3, or the derived floor area is below 1 m², the scan failed.

On any failure: do not show the review screen as a success. Show a specific, actionable message naming the direction of the gap, with two buttons — *Rescan* and *Continue anyway (flagged)*. Continuing flags `validation.lowCoverage: true` in `measurements.json`.

### 8.3 Session flow

```
SiteSetupView          → worker name (persisted, prefilled next time)
                       → site ID (typed, or scanned from a QR if added later)
                       → [first scan on device] calibration step
ScanFlowView           → RoomCaptureViewController
                       → live coverage indicator, live speed warning
                       → Stop
CoverageAnalyzer       → pass / fail with named reason
ReviewFlowView         → FloorPlanScene editor, dimension overlay
TapeGateView           → critical dimensions, tape entry
ExportFlowView         → package summary, export / queue for upload
```

**Do not let the worker reach Review with a failed coverage check without passing through the explicit "Continue anyway" confirmation.** Silent acceptance is how wrong geometry ships.

---

## 9. On-site correction engine

Source: `RoomPlanDemo/RoomPlanDemo/FloorPlan/*` and `CustomViews/*`. This is the largest port and the most valuable reuse in the project.

### 9.1 The port that matters

RoomPlanDemo's editors mutate a SpriteKit node tree. The export never sees those edits. To fix this:

1. Introduce `EditedPlan` in `Model/` — a plain, `Codable`, immutable-by-convention struct tree: `walls`, `openings`, `objects`, `sections`, each with a stable `identifier`, a `simd_float4x4 transform`, and a `simd_float3 dimensions`.
2. Seed `EditedPlan` from the `CapturedRoom` on review entry. Either auto-provision missing identifiers or preserve RoomPlan's when present.
3. Make `FloorPlanScene` render **from** `EditedPlan` and route every gesture into a mutation of `EditedPlan`.
4. Rebuild only the affected nodes on change. Do not rebuild the scene per frame.

`FloorPlanScene.swift` currently derives its nodes directly from `CapturedRoom`. Re-pointing it at `EditedPlan` is the core refactor. Budget real time for it.

### 9.2 Edits to support in v1

Ported from RoomPlanDemo's existing UI:

| Edit | Source UI | Notes |
|---|---|---|
| Adjust wall length | `SurfaceDetailsView` | Convert slider units from scene points to **millimetres with a numeric text field**. Sliders alone cannot hit a 10 mm target. |
| Adjust wall thickness | `SurfaceDetailsView` | Same conversion. |
| Adjust wall position | `SurfaceDetailsView` | |
| Adjust wall angle | `SurfaceDetailsView` | Snap to 90° within 1° by default. |
| Relabel an object | `ObjectDetailsView` | Drives `KitchenTag`. |
| Delete a false detection | `ObjectDetailsView` | Required by the brief. |
| Add a missed wall | new | Draw a wall by two taps; length in mm. Required by the brief. |
| Add a fixed object | `AddFurnitureView` | Kitchen catalog. |
| Add a text annotation | `AnnotationsDetailsView` | |
| Set room name and colour | `RoomOptionsView` | Feeds `sections`. |

### 9.3 Numeric entry is mandatory

RoomPlanDemo's sliders are the wrong tool for this product. A slider with 400 points of travel mapped over 5 m gives ~12 mm per point — coarser than the tolerance. **Every numeric edit needs a text field with a millimetre keyboard.** Keep the slider for coarse motion, add the field for precision.

### 9.4 Live correction of scan error

When the worker enters a tape value for a wall, offer *"Apply to geometry"*:

- Scale that wall's `dimensions[0]` so the model matches the tape.
- Move the connected wall chain's downstream endpoints to preserve closure.
- Mark the wall `provenance: .tape` and record `valueScannedMm` for comparison.

Do not apply automatically. Automatic geometry mutation with imperfect closure logic will create new errors. Show a preview and a confirm.

---

## 10. Kitchen tagging and field metadata

### 10.1 Kitchen tags

`AddFurnitureView` already has appliance categories. Extend the catalog for the specific list in the brief.

v1 tag vocabulary:

```
fixed objects:   refrigerator, sink, stove, dishwasher, oven, range-hood,
                 water-heater, column, beam, radiator, pipe-boxing
cabinet intents: base-cabinet-run, wall-cabinet-run, tall-cabinet,
                 island, pantry
openings:        door, window, doorway-passage, service-hatch
```

Two important distinctions:

- **`fixed: true`** — physically present and must be worked around: existing fridge, column, beam, radiator, pipe boxing. The designer cannot move these.
- **`fixed: false`** — a design intent the worker is marking: "this wall is where the base run goes". These drive the critical-dimension rules in [section 6.4](#64-what-actually-governs-cabinet-fit).

Tagging a wall as a `base-cabinet-run` or `wall-cabinet-run` is what makes its length a critical dimension. This is the mechanism that turns a generic room scan into a kitchen measurement job.

### 10.2 Field metadata

Captured in `SiteSetupView`, persisted in `CaptureMetadata`, emitted into `measurements.json`:

- **Worker name** — required. Persisted across scans; prefilled. Free text with a picker of recent names.
- **Site ID** — required. Free text. Validate a non-empty, no-whitespace format so it survives being a filename and a URL segment.
- **Timestamp** — automatic, ISO 8601 UTC.
- **Device model** — automatic, from `utsname`.
- **App version** — automatic, from the bundle.
- **Room label** — required per scan. Free text with kitchen-relevant defaults.
- **Optional note** — free text, one per site.

**Also capture site ID and worker name inside the ZIP on every export**, not only in `measurements.json`, so a package that loses its sidecar is still attributable. Write a `package-manifest.json` at the ZIP root duplicating the identity fields.

---

## 11. Tape verification gate

The requirement: *"the workflow must require the worker to take a manual tape measurement of any dimension that governs cabinet or appliance fit. The app should flag this clearly and not present scan values as certified."*

### 11.1 Screen design

`TapeGateView` shows one card per critical dimension.

Each card contains:

1. The dimension name and a small plan thumbnail with the dimension highlighted.
2. **The scanned value, clearly badged "SCANNED — APPROXIMATE".** Show it, because a worker who cannot see the scanner's guess will distrust the whole screen.
3. A numeric entry field, millimetre keyboard, placeholder *"Tape measurement (mm)"*.
4. On entry: the deviation from the scanned value, in mm, with a colour band — green within tolerance, amber up to 3× tolerance, red beyond.
5. On red: the card demands a note before it can be completed. *"Scan and tape disagree by 84 mm. Explain."* This is the honest path; a worker who cannot proceed will re-measure, which is the correct outcome.
6. A *"Could not measure"* escape that marks the dimension `provenance: scanned` and requires a reason. **This must exist.** A gate with no escape produces fabricated numbers.

### 11.2 Gate behaviour

- The worker can leave the gate with incomplete critical dimensions.
- Doing so sets `validation.gateResult = "fail"` and lists the incomplete dimensions in the export.
- The review screen shows a persistent amber banner until every critical dimension is `tape` or explicitly waived.
- Export is never hard-blocked. See [section 7.3](#73-measurementsjson).

### 11.3 Optional — two-person check

The validation protocol requires a second person to tape measure the same dimensions for comparison. For v1, that is an offline paper process captured in the validation spreadsheet. Do not build a second-app flow. If the pilot shows the gate works, consider a "verifier" mode later.

---

## 12. Export pipeline

`Export/PackageBuilder.swift` assembles the ZIP. Order of operations:

```
EditedPlan
    ├─→ HandoffExporterV1   → plan.json      (metres, handoff v1)
    ├─→ MeasurementTableExporter → measurements.json (mm, provenance)
    ├─→ RoomCaptureViewController's stored raw capture → room.json
    ├─→ UsdzExporter        → model.usdz
    ├─→ PhotoCaptureManager → photos/
    └─→ PackageBuilder      → package-manifest.json + ZIP
```

### 12.1 Validate before writing

`HandoffExporterV1` runs its own validator on the in-memory document, mirroring every rule in `roomplanValidation.ts`:

- Every element has a non-empty, unique `identifier`.
- `dimensions` has 2–3 finite positive entries.
- `transform` has exactly 16 finite entries and a horizontal direction (`hypot(t[0], t[2]) >= 1e-8`).
- `story` is a safe integer where present.
- `hingeLeft` / `opensInward` are booleans where present.
- `sillHeight` is a non-negative finite number where present.
- Door `style` ∈ `{single, double, sliding, patio}`; window `style` ∈ `{fixed, sliding}`.
- Every opening's `parentIdentifier` resolves to a wall on the same `story`.
- `stories` entries have integer `index` and string `name`.
- `sections` entries have a finite 3-element `center` and a string `label`.
- `openplanHandoffVersion == 1`.

**A validation failure blocks export and names the offending element.** Shipping a broken package is worse than shipping none — the web import rejects the whole document.

### 12.2 Fixture round-trip test

`MagpieFieldTests/HandoffExporterV1Tests.swift` must:

1. Load `Fixtures/handoff-plan.json`.
2. Decode it into `EditedPlan`.
3. Encode it with `HandoffExporterV1`.
4. Assert the output equals `Fixtures/handoff-roomplan.json` for every key and value.

This is the single most important test in the project. It is also the reason to obtain the fixture pair from openPlan3D rather than writing a schema from prose. Per the contract doc, the same fixtures live in the iOS test bundle on the original app — reuse them verbatim.

### 12.3 Export destinations

- **Save to app library** — always. Written by `RoomStorageManager`.
- **Share sheet** — `RoomExportManager` handles this already; keep it.
- **Queue for upload** — writes to `SyncQueue`; see [section 13](#13-offline-storage-encryption-and-sync).
- **Files app / AirDrop** — free, via the share sheet. Useful during the pilot.

### 12.4 Formats beyond the ZIP

Keep the existing `FloorPlanExporter` SVG and DXF writers. They are cheap, they already exist, and a designer who does not want to open the web app gets a usable drawing. Do not extend them in v1.

---

## 13. Offline storage, encryption, and sync

Source: `RoomPlanExampleApp/RoomPlanSimple/RoomStorageManager.swift`.

### 13.1 What already works

`RoomStorageManager` writes a complete local library under `Application Support/SavedRooms/`, with per-room folders (`<uuid>.json` metadata, `<uuid>_floorplan.json`, `<uuid>_wifi.json`, thumbnails) and export bundles. Keep the structure; drop the WiFi files.

### 13.2 Encryption

Use iOS Data Protection. Do not write custom crypto.

```swift
// Directory-level: files are unreadable while the device is locked.
try FileManager.default.setAttributes(
    [.protectionKey: FileProtectionType.complete],
    ofItemAtPath: savedRoomsDirectory.path
)

// Write sites: belt and braces on every file write.
let options: Data.WritingOptions = [.atomic, .completeFileProtection]
try data.write(to: url, options: options)
```

Set the same protection level on the ZIP staging directory. Scans contain photos and layouts of clients' homes; `completeFileProtection` is the native answer and requires no key management. Flag in the Info.plist review that the app must not opt out of data protection.

**Note:** `NSFileProtectionComplete` makes files inaccessible while the device is locked. If any background sync runs while locked, it will fail to read them. Use `NSFileProtectionCompleteUnlessOpen` for anything the sync queue must read in the background, and `Complete` for everything else. Decide this deliberately; it is a correctness issue, not a preference.

### 13.3 Sync queue

`SyncQueue.swift` — a small, atomic, resumable queue. Keep it simple; a manifest plus per-item state files is enough for one device.

State machine per package:

```
pending → uploading → uploaded → confirmed → deleted
                    ↘ failed (retry with backoff)
```

Rules:

- Each package directory contains `state.json` with `{packageId, siteId, attempts, lastError, remoteId, checksum}`.
- `SyncClient` `POST`s the ZIP to the designer backend. Target: `openPlan3D`'s existing handoff upload route under `src/routes/api/handoffs/` — see [section 14.3](#143-upload-endpoint).
- Retry with exponential backoff. Cap attempts and surface the failure in the library UI; a package that silently never syncs is a lost day of work.
- **Delete local copies only after a confirmed server acknowledgement that includes a checksum match.** Not on HTTP 200 alone. A truncated upload that returns 200 will destroy the only copy of a site visit.
- Keep the metadata row in SwiftData after deleting files, so the library still shows that the site was captured and synced.

### 13.4 Connectivity

Site WiFi is unreliable — that is a stated premise. Detect via `NWPathMonitor`. Do not block the worker on upload. The scan flow ends at *"Queued for upload"*, never at *"Waiting for upload"*.

---

## 14. Designer-side web work

Fork `openPlan3D` to `magpie-studio`. The geometry pipeline already works; do not touch `roomplanImport.ts` or `roomplanValidation.ts` beyond what the contract requires.

### 14.1 What already works

- `roomplanImport.ts` ingests handoff v1 into editable geometry.
- `roomplanValidation.ts` rejects malformed imports with a typed message.
- The 2D/3D editor, kitchen furniture catalog, metric dimensions, DXF/SVG/PDF/PNG export.
- `roomplan-import.test.ts` plus fixtures guard the contract.
- `firebase.ts` provides auth.
- `api/handoffs/` plus `handoffUpload.ts`, `handoffStorage.ts`, `handoffQuota.ts` provide upload and quota.

### 14.2 New: dimension table panel

A panel that reads `measurements.json` from the same package and renders:

- Every dimension with its `provenance`, `valueMm`, `valueScannedMm`, and `deviationMm`.
- **Distinct visual treatment per provenance.** `tape` values strong and dark; `scanned` values muted with an "approx" marker; `calibrated` values intermediate. Never render them identically.
- The `validation` summary at the top: pass rate, gate result, count of incomplete critical dimensions.
- The `kitchenTags` list, cross-linked to the geometry so clicking a tag selects the element on the plan.
- The `calibration` block, so the designer knows what bias was applied.
- The capture metadata: site ID, worker, timestamp, device.

**Do not import `measurements.json` geometry back into the model.** It is a report, not a plan. `plan.json` is the geometry.

### 14.3 Upload endpoint

`src/routes/api/handoffs/` and `src/lib/server/handoffUpload.ts` already handle package upload. Verify against the ZIP shape in [section 7](#7-data-contracts) and extend to accept `measurements.json` and `model.usdz` alongside the existing geometry payload. `handoffQuota.ts` already bounds upload size — check the limit is compatible with a USDZ plus photos; a 40 MB model may exceed a small quota.

### 14.4 New: per-site access control

The brief requires restricting access to the company's designers and the assigned worker.

- Authenticate with the existing Firebase setup.
- Key each package by `siteId` and store an assignment record: which worker captured it, which designers may read it.
- Enforce on the server in the handoff routes, not in the Svelte client. A client-side check is not access control.
- Designers see only assigned sites. Workers see only their own captures.

### 14.5 Dimension rendering in mm

openPlan3D stores and displays centimetres per its contract. The designer works in millimetres. Add a display unit setting rather than converting the model — convert at the format boundary only. There is an existing `length-formatting` test in the repo; extend it rather than replacing it.

---

## 15. Milestones and task breakdown

Twelve milestones. M0–M9 are v1. M10–M12 are deferred and listed so scope is explicit; see [section 20.11](#2011-scope-call) for the rationale. Each has a goal, a definition of done, and a test. Do M0–M9 in order; M2 and M9 are the ones that decide whether the product works.

### M0 — Foundations

**Goal.** A buildable iOS target with the device gate and permission handling.

Tasks:
1. Create `magpie-field` Xcode project, iOS 17+, SwiftUI app lifecycle with a UIKit bridge for the capture controller.
2. Copy `Constants.swift`, `AppSettings.swift`, `LocalizationHelper.swift`, the three `lproj` folders, and `Info.plist` from `RoomPlanExampleApp`.
3. Add the LiDAR capability gate: check `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)` and refuse to start a scan on unsupported hardware with a clear message.
4. Add `NSCameraUsageDescription` and confirm no unnecessary entitlements.
5. Add `Secrets.swift` **to `.gitignore`** and replace with a template — see [section 18](#18-risks-and-mitigations).

**Done when:** the app launches on an iPhone 16 Pro, shows the device-supported state, and refuses cleanly on a non-LiDAR simulator.

### M1 — Capture core

**Goal.** Scan a room and get a `CapturedRoom`.

Tasks:
1. Port `RoomCaptureViewController.swift`, `RoomCaptureError.swift`, `MemoryMonitor.swift`, `HapticFeedbackManager.swift`.
2. Port `PhotoCaptureManager.swift`.
3. Strip the WiFi and IFC code paths out of the ported files.

**Done when:** a room scans, USDZ exports via share sheet, five consecutive scans do not crash.

### M2 — Dimension engine

**Goal.** Millimetre dimensions with provenance. This is where "high precision" is actually delivered.

Tasks:
1. Port `ScanStatistics.swift`. Convert every output to millimetres at the boundary; keep metres internally.
2. Write `DimensionEngine.swift` — walk an `CapturedRoom` or `EditedPlan`, emit `Measurement` values with `DimensionProvenance.scanned`.
3. Write `CriticalDimension.swift` — the rules in [section 6.4](#64-what-actually-governs-cabinet-fit).
4. Write `Measurement.swift` with the three-tier model.
5. Implement bias calibration in `AppSettings` — `biasFactor`, `calibratedAt`, `referenceDescription`.
6. Write `DimensionEngineTests.swift`: golden tests asserting mm conversion and correct provenance propagation.

**Done when:** a scanned room produces a dimension list in mm, every value badged `scanned`, and the critical set is correctly identified for a room with no tags (falls back to ceiling height and the longest wall).

### M3 — Correction engine

**Goal.** The worker can fix the scan on site.

Tasks:
1. Write `EditedPlan.swift` and the four child types, `Codable`.
2. Seed `EditedPlan` from `CapturedRoom`.
3. Port `FloorPlanScene.swift`, `FloorPlanSceneView.swift`, `FloorPlanSurface.swift`, `FloorPlanObject.swift`, `FloorPlanAnnotation.swift`, `FloorPlanViewModel.swift` from `RoomPlanDemo`.
4. Re-point the scene at `EditedPlan`. This is the main refactor.
5. Port `SurfaceDetailsView`, `ObjectDetailsView`, `AdjustMesurementView`, `RoomOptionsView`, `AnnotationsDetailsView`.
6. Add millimetre numeric text fields beside every slider ([section 9.3](#93-numeric-entry-is-mandatory)).
7. Add "add a missed wall" and "delete a false detection".

**Done when:** a worker moves a wall, relabels an object, deletes a false detection, and adds a missed wall; the `EditedPlan` reflects every change and a fresh USDZ renders the corrected geometry.

### M4 — Kitchen tagging and metadata

**Goal.** A scan knows what it is and who took it.

Tasks:
1. Write `KitchenTag.swift` with the v1 vocabulary from [section 10.1](#101-kitchen-tags).
2. Port `AddFurnitureView.swift`; extend the catalog to the kitchen list; wire tags into `EditedPlan`.
3. Write `CaptureMetadata.swift`.
4. Write `SiteSetupView.swift` with worker name and site ID, persisted and validated.
5. Wire tags into `CriticalDimension` so tagging a cabinet run promotes that wall to critical.

**Done when:** tagging a wall as a base cabinet run makes its length appear as a critical dimension in the tape gate.

### M5 — Tape verification gate

**Goal.** No uncertified number reaches the designer without a flag.

Tasks:
1. Write `TapeGateView.swift` per [section 11.1](#111-screen-design).
2. Implement the deviation bands and the mandatory note on red.
3. Implement *"Could not measure"* with a required reason.
4. Compute the `validation` block from [section 7.3](#73-measurementsjson).

**Done when:** the gate shows the critical set, a tape entry updates provenance to `tape` and records `deviationMm`, and waiving a dimension marks the gate `fail` in the export.

### M6 — Export pipeline

**Goal.** A package the designer can open.

Tasks:
1. Write `HandoffExporterV1.swift` and its validator.
2. Copy `handoff-plan.json` and `handoff-roomplan.json` from openPlan3D's tests into `Resources/Fixtures/`.
3. Write `HandoffExporterV1Tests.swift` — the fixture round-trip from [section 12.2](#122-fixture-round-trip-test). **Get this green before proceeding.**
4. Write `MeasurementTableExporter.swift`.
5. Port `UsdzExporter` from `RoomExportManager` / `RoomCaptureError`'s format list.
6. Write `PackageBuilder.swift` — ZIP assembly, `package-manifest.json`, `room.json`.
7. Wire the existing `FloorPlanExporter` SVG/DXF into the share sheet.

**Done when:** a scanned and edited room produces a ZIP that imports into an unmodified `openPlan3D` with correct geometry, floors, and openings — verified by opening a real package in the real web app.

### M7 — Storage, encryption, sync

**Goal.** Offline capture, later upload, delete after confirmed sync.

Tasks:
1. Port `RoomStorageManager.swift`; drop the WiFi artifacts; apply `NSFileProtectionComplete` per [section 13.2](#132-encryption).
2. Write `SiteCapture.swift` as the SwiftData record for the library screen. Model it on `iOS-RoomPlan`'s `Scan.swift`.
3. Write `Encryption.swift` — the protection helpers.
4. Write `SyncQueue.swift` with the state machine and atomic state files.
5. Write `SyncClient.swift` targeting openPlan3D's handoff endpoint.
6. Delete local files **only** on checksum-confirmed acknowledgement.
7. Add `NWPathMonitor` connectivity handling.

**Done when:** the device is put in airplane mode, three sites are scanned and queued, airplane mode is turned off, all three upload, and the local files are removed only after checksum confirmation.

### M8 — Designer side

**Goal.** The designer sees dimensions, provenance, and metadata.

Tasks:
1. Fork `openPlan3D` to `magpie-studio`.
2. Verify the existing import accepts your `plan.json` — run the existing `roomplan-import.test.ts`.
3. Add `roomplan-import.test.ts` coverage for your own real package's `plan.json`.
4. Build the dimension table panel from [section 14.2](#142-new-dimension-table-panel).
5. Extend the handoff upload route to accept `measurements.json`, `model.usdz`, and `photos/`.
6. Add per-site access control on the server ([section 14.4](#144-new-per-site-access-control)).
7. Add the millimetre display unit setting ([section 14.5](#145-dimension-rendering-in-mm)).

**Done when:** a designer logs in, sees only assigned sites, opens a package, and reads a dimension table where tape and scanned values are visually distinct.

### M9 — Validation

**Goal.** Decide with data whether v1 ships.

Tasks:
1. Build the capture harness from [section 16](#16-validation-protocol).
2. Run five kitchens.
3. Produce the accuracy report.
4. Produce the time report.

**Done when:** the report states pass or fail against the pre-agreed criteria, and names the specific dimensions and room conditions where the app failed.

### M10 — Non-LiDAR capture modes (v1.1)

Deferred. Do not start before M9 passes. Details in [section 20](#20-capture-modes-and-layout-ingestion).

Tasks:
1. Device gate routes non-LiDAR hardware to Mode B instead of refusing ([section 20.4](#204-mode-b--guided-manual-wallcorner-scan-non-lidar-tier)).
2. Guided wall/corner flow with mandatory mm tape entry per wall.
3. `RoomPolygon` validation: self-intersection, minimum vertices, non-zero area — hard blocks.
4. Template picker backed by a preset vertex list ([section 20.5](#205-mode-c--parametric-templates)).
5. Freeform corner plotting on a blank canvas ([section 20.6](#206-mode-d--freeform-corner-plotting)).
6. Export path with `captureMode: "manual"`, no `model.usdz`, all dimensions `tape`.

**Done when:** a scan-free plan can be built on a non-LiDAR iPad, exported, and opened in `magpie-studio` with correct geometry.

### M11 — Blueprint import and tracing (v1.1)

Deferred. Details in [section 20.7](#207-mode-e--raster-blueprint-import-scale-calibration-and-tracing).

Tasks:
1. Import image or PDF; render PDF pages via `PDFKit`'s `PDFPage.thumbnail`.
2. Two-point scale calibration, storing `mmPerPixel`.
3. Locked underlay at ~40% opacity.
4. Corner tracing snapped to the calibrated scale.
5. Provenance capped at `derived`; critical dimensions still route through the tape gate.
6. Block tracing until calibration is complete.

**Done when:** a blueprint is calibrated, traced, exported, and opened in `magpie-studio` with traced dimensions matching the printed dimensions within the stated calibration error.

### M12 — Material takeoff (v2)

Deferred. Details in [section 20.9](#209-calculation-engine-and-material-takeoff).

Tasks:
1. Core calculations in `DimensionEngine`: perimeter inner/outer, floor area matching the web's area convention, wall area net of openings, opening schedule.
2. Separate `takeoff.json` in the package.
3. Explicit, configurable waste margin per material. Never baked into the area.
4. Extend `planStatistics.ts` on the web rather than adding a second calculator.

**Done when:** the takeoff for a plan matches a hand calculation, and the phone and web report identical floor areas for the same room.

---

## 16. Validation protocol

The brief is explicit that tolerances are **"to be measured rather than assumed."** This protocol is how you measure them.

### 16.1 Pre-agreed pass/fail

Define these **before** the first test scan. Write them down. Changing them after seeing the data invalidates the result.

| Criterion | Threshold | Measurement |
|---|---|---|
| Critical dimensions within tolerance | ≥ 90% | Tape value vs. tape value, per dimension |
| Wall-to-wall within 10 mm | ≥ 80% of non-critical walls | Same |
| Scan time vs. manual | ≥ 30% faster | Stopwatch, per site |
| Crash-free scans | 100% | Any crash fails the site |
| Scan abandoned | ≤ 1 of 5 sites | Abandonment rate |

Tolerances: 10 mm wall-to-wall, 5 mm critical openings — as proposed in the brief. **Expect the 5 mm opening target to fail on the first run.** That is the expected result and the reason the tape gate exists. Record it honestly rather than tuning the threshold.

### 16.2 Site selection

Five kitchens, deliberately varied:

1. Small galley, good light, empty.
2. Medium L-shape, good light, occupied with existing cabinetry.
3. Large open plan, poor light, cluttered.
4. Room with significant glazing or reflective surfaces.
5. Non-rectangular or awkward geometry.

Variation across **size, lighting, and clutter** is the point. Five identical easy rooms prove nothing.

### 16.3 Procedure per site

1. **Second person measures first**, by tape, and records values on paper. Do not let the app user see these numbers.
2. **Worker scans and completes the full flow**, including the tape gate.
3. **Compare.** Per dimension, compute `signedError_mm = appValue - referenceValue`.
4. **Record time** for the manual process on the same site, and the app process.
5. **Record failures** verbatim: which dimension, what the app said, what the tape said.

The second person must be different from the worker, and must not be watching the screen.

### 16.4 Metrics to report

- **Mean signed error per axis** — detects a systematic scale bias. If all X walls read 1.5% short, that is a calibration problem, not a random error. This is the single most diagnostic number.
- **Mean absolute error** — overall accuracy.
- **P95 absolute error** — the tail is what breaks a design.
- **Percentage within tolerance**, split critical vs non-critical.
- **Deviation between tape and scanned value** for every gated dimension.
- **Coverage-check true-positive and false-positive rate** — did `CoverageAnalyzer` catch the bad scans, and did it cry wolf on good ones?
- **Time per site**, app vs manual.

### 16.5 Deliverable

One spreadsheet plus a short written report. The report must state, in plain terms:

- Pass or fail against each criterion in [16.1](#161-pre-agreed-passfail).
- Which room conditions produced the worst error.
- Which critical dimensions are reliably achievable by tape (probably all) and which are reliably achievable by scan (probably few).
- Whether the coverage warnings helped or just added noise.

---

## 17. Explicitly out of scope — do not build

Deleting these is part of the job. They are present in the source repos and none of them serve v1.

| Item | Source | Reason |
|---|---|---|
| `WiFiSignalManager.swift` | RoomPlanExampleApp | Power/utility detection is a v1 non-goal |
| `WiFiOverlayView.swift` | RoomPlanExampleApp | Same |
| `RFPropagationModel.swift` | RoomPlanExampleApp | Same |
| `_wifi.json` export | `RoomStorageManager` | Same |
| `IfcExportBridge.swift`, `bimifc_ffi.swift`, `BimIfcFFI.xcframework` | RoomPlanExampleApp | IFC/BIM is a large Rust FFI dependency for a format no v1 consumer reads. Drop it. |
| `RoomTypeDetector.swift` | RoomPlanExampleApp | Auto room typing is not required and will be wrong |
| OBJ / STL export | RoomCapatureError's `ExportFormat` | No v1 consumer |
| DXF/SVG *extensions* | `FloorPlanExporter` | Keep as-is; do not invest further |
| iCloud backup | `RoomStorageManager` | Stated v1 policy is local-until-synced |
| `openPlan3D`'s render-lab, benchmarks, skills, MCP routes | openPlan3D | Not needed; consider removing to shrink the fork |
| LLM / assistant features | openPlan3D | v1 non-goal |

**Also remove the dead weight from anything you copy** — do not port a file wholesale if half of it is WiFi or IFC code. A smaller port is a smaller surface to get wrong.

---

## 18. Risks and mitigations

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| 1 | RoomPlan output is centimetre-accurate, not millimetre | Designer builds a cabinet that does not fit | The three-tier provenance model ([section 6](#6-the-precision-model--read-before-writing-any-dimension-code)). Tape governs every fit-critical dimension. Never present scan as certified. |
| 2 | Reflective surfaces, glass, dark cabinetry degrade depth | Wrong dimensions with no warning | `CoverageAnalyzer` closure check ([section 8.2C](#82-what-to-add--three-explicit-warnings)); record `lowConfidence` in the export; validation sites 3 and 4 target exactly this |
| 3 | Incomplete wall coverage produces wrong geometry silently | The worst outcome — plausible but wrong | Explicit closure and coverage checks before the review screen. Never trust RoomPlan's success callback alone. |
| 4 | RoomPlan output is hard to correct after capture | Worker cannot fix it on site, and the correction is the whole point | The entire M3 milestone, plus `EditedPlan` as the single source of truth |
| 5 | Custom mesh pipeline is far larger than building on RoomPlan | Schedule blowout | Build on RoomPlan. Accept the format constraints. Do not write a mesher. |
| 6 | **`RoomPlanExampleApp/Configuration/Secrets.swift` may contain live API keys** | Credential leak into the new repo | **Inspect `Secrets.swift` before copying anything.** Replace with a template, add to `.gitignore`, verify no key strings reach the new repo's history. Do this in M0. |
| 7 | iOS Data Protection vs. background sync | Sync fails silently while the device is locked | Choose `CompleteUnlessOpen` for queue-readable files ([section 13.2](#132-encryption)); test with the device locked |
| 8 | Deleting local files before a confirmed upload | The only copy of a site visit is lost | Delete only on checksum-confirmed acknowledgement ([section 13.3](#133-sync-queue)) |
| 9 | Real vs. reference (simulator/fixture) divergence | Web import works in tests, fails with real captures | M6's done-when requires opening a **real package** in the **real web app**, not just a passing test |
| 10 | Tape gate produces fabricated values | False confidence, worse than no gate | Severity-banded feedback, mandatory note on red ([section 11.1](#111-screen-design)), and the *"Could not measure"* escape |
| 11 | Worker cannot complete the flow under time pressure | Abandonment, and a return to hand measurement | Measure time in M9; if scan time is not ≥30% faster the product has no case. Treat the time result as a gate, not a note. |
| 12 | One team member is preparing for an exam until late November | Reduced build capacity | M0–M2 are the critical path and are mostly porting. Do them first. M3 is the largest single port; do not start it before M2 is green. |
| 13 | `handoff-plan.json` / `handoff-roomplan.json` fixtures missing from this folder | Exporter cannot be tested against the real contract | Obtain them from openPlan3D at the forked commit. If genuinely unavailable, generate them by running the existing openPlan3D import test and capturing its inputs — do not hand-write the schema. |

---

## 19. Open decisions that must be answered before build

These block work. Resolve them with the client before M0.

1. **How many LiDAR devices does the workforce have?** Determines whether this is one prototype device or a rollout, and therefore whether sync and identity story matter in v1.
2. **Who owns the final dimensions when the scan and the designer disagree?** The three-tier model assumes *tape governs*. Confirm this. If the designer's own re-measure governs instead, the tape gate is redundant and the whole project shrinks.
3. **What tolerance does the designer actually need, per item type?** The brief proposes 10 mm / 5 mm. `measurements.json` carries `tolerances` per dimension — get real numbers from the designer rather than defaults.
4. **Which USDZ variant ships?** `parametric`, `model`, or `mesh`. Affects file size and quota (`handoffQuota.ts`). Default to `parametric` unless the designer needs textures.
5. **What does the sync backend actually run?** `openPlan3D`'s handoff route assumes a Node server. Confirm hosting, storage, and Firebase project ownership before M7.
6. **Who builds and tests the app**, given one of the two people is on exam leave until late November? [Section 15](#15-milestones-and-task-breakdown) is sized for roughly one focused builder through M6.
7. **Compliance posture.** Client home photos and layouts are personal data under most regimes. Confirm the retention period after sync, and who authorises a delete. `NSFileProtection` covers at-rest encryption on device; it does not cover what happens on the server.

---

## 20. Capture modes and layout ingestion

This section covers five ways a plan can enter the system, plus the room data model, the calculation engine, and the material takeoff that consumes it.

**Read this first:** three of the five modes already exist in `openPlan3D` (section [20.10](#2010-web-side-coverage--what-already-exists)). Do not rebuild them on the web. The only genuinely new work is on iOS, and only for the non-LiDAR device tier. Section [20.11](#2011-scope-call) states what ships when.

### 20.1 The unifying principle — capture modes are producers, not features

The plan already defines `EditedPlan` as the single source of truth for geometry ([section 9.1](#91-the-port-that-matters)). Every capture mode is simply a **producer** of an `EditedPlan`. LiDAR is one producer. Manual wall tracing, templates, corner plotting, and blueprint tracing are four more.

```
                    ┌──────────────────────────────┐
   Mode A LiDAR ───►│                              │
   Mode B Manual ──►│                              │
   Mode C Template►│    EditedPlan                │──► plan.json
   Mode D Corners ─►│    (single source of truth)  │──► measurements.json
   Mode E Blueprint►│                              │──► model.usdz (optional)
                    └──────────────────────────────┘
                                    │
                            FloorPlanScene
                            (pure view, no state)
```

**Do not add a parallel model per mode.** A top-level `captureMode` enum on the plan plus the existing element types is sufficient. A template room produces walls; a traced blueprint produces walls. Walls are walls.

### 20.2 Mode registry

| Mode | Device tier | Produces USDZ? | New iOS work | Web equivalent |
|---|---|:---:|---|---|
| **A. LiDAR auto-scan** (primary) | LiDAR only | Yes | M1–M3 as planned | `roomplanImport.ts` |
| **B. Guided manual wall/corner scan** | Any | No | New, M10 | `addWall`, corner drag |
| **C. Parametric templates** | Any | No | New, M10 (thin) | `roomTemplates.ts` |
| **D. Freeform corner plotting** | Any | No | New, M10 | `addWall` free draw |
| **E. Raster blueprint import + trace** | Any | No | New, M11 | `calibrationMode`, `setBackgroundImage` |

Modes C and D are the same underlying operation — create a polyline of wall segments — differing only in whether the polyline starts empty or from a preset. **Build them as one feature with a template picker, not two.** A template is a preset vertex list fed into the same corner-plotting flow.

### 20.3 Mode A — LiDAR auto-scan (primary)

As specified in [section 8](#8-guided-capture-engine). RoomPlan performs mesh reconstruction and plane detection; the app converts `CapturedRoom` surfaces into `EditedPlan` elements via `transform` + `dimensions`.

The 3D-to-2D vector conversion the product briefs describe is **already done by RoomPlan** and by `FloorPlanScene`'s renderer. `CapturedRoom.Surface.transform` gives position and heading; `dimensions[0]` gives length. Do not write a point-cloud-to-vector pipeline. That is the "much larger than building on RoomPlan" trap named in [section 18](#18-risks-and-mitigations), risk 5.

For the designer side, the web derives independent start/end wall coordinates from the same `transform` + `dimensions` on import ([handoff contract](#33-contract-rules-that-must-be-obeyed-exactly)). Same data, different representation.

### 20.4 Mode B — Guided manual wall/corner scan (non-LiDAR tier)

**Purpose.** Answer open question #1 ([section 19](#19-open-decisions-that-must-be-answered-before-build)): how many LiDAR devices does the workforce have? A manual mode removes the device constraint entirely and makes rollout to any recent iPhone or iPad possible.

**Important honesty constraint:** without LiDAR, ARKit plane detection is materially worse — no depth sensor, no scene mesh, and it fails in the exact conditions the brief names (poor light, reflective surfaces, cluttered rooms). **Do not build AR-assisted wall detection for the non-LiDAR tier.** It will produce plausible-looking wrong geometry, which is the failure mode [section 18](#18-risks-and-mitigations) risk 3 exists to prevent. On non-LiDAR devices, go straight to manual:

**Flow (Mode B):**

1. Worker stands at a corner, taps **Set corner**.
2. App shows a distance readout from the device's motion tracking — this is a **guide only**, never a recorded value. Mark it clearly as an estimate.
3. Worker taps **Set next corner**, physically walks the wall, taps again.
4. App creates a wall segment. Corner angle is snapped to 90° by default with a manual override.
5. Worker enters the **tape length in millimetres** for that wall when the card appears. Unlike Mode A, this is not optional — no scanner produced the number, so the tape is the only source.
6. Repeat per wall. The app closes the polygon when the last endpoint nears the first, using the same closure check as [section 8.2C](#82-what-to-add--three-explicit-warnings).
7. Fixtures (doors, windows, openings) are placed by tapping a wall and entering width and position in millimetres.

**Consequence for provenance.** Every Mode B dimension is `DimensionProvenance.tape`. The tape gate ([section 11](#11-tape-verification-gate)) is trivially satisfied. The export carries `captureMode: "manual"` so the designer knows no scanner was involved.

**This mode has no `scanned` values at all.** That is a feature: a Mode B plan is fully tape-verified by construction, and therefore more trustworthy than a Mode A scan. Say so in the UI.

### 20.5 Mode C — Parametric templates

Preset polygonal room footprints with adjustable dimensions. A template is a named vertex list plus a default wall set.

v1 catalog (iOS side — keep it small):

```
rectangle          width x depth
L-shape            width, depth, leg width, leg depth
U-shape / galley   run length, return depth x2
T-shape
freeform           -> routes to Mode D
```

Placement flow: pick template, pick orientation, enter two or three millimetre dimensions, place. Then all walls are immediately editable via the standard `SurfaceDetailsView` editor with mm text fields ([section 9.3](#93-numeric-entry-is-mandatory)).

**Reuse the web's implementation as the reference model.** `openPlan3D/src/lib/utils/roomTemplates.ts` defines the geometry and `houseTemplates.ts` composes multi-room presets. Read them before writing the Swift version — the vertex math is already solved, and matching its conventions avoids a translation bug.

**Do not port every web template to iOS.** The field app needs kitchen-shaped presets. The full library is a designer tool that already works in the browser.

### 20.6 Mode D — Freeform corner plotting

Blank canvas. Worker drops anchor points in order; each consecutive pair becomes a wall. Same flow as Mode B steps 2–6 minus the physical-walk guidance.

Useful for irregular footprints, angled walls, and bay windows where the kitchen is not a clean polygon. Angle snapping to 90° is on by default, with a modifier to place a free angle.

**Self-intersection validation is mandatory.** A polygon that crosses itself produces a nonsense area and a wrong perimeter, and neither `planStatistics` nor a human notices quickly. Validate on polygon close: reject self-intersecting polylines with a highlighted crossing and a named message. Zero-area and fewer-than-three-vertex polygons are rejected too.

This is the one place in the whole plan where geometry validation must be a hard block rather than a warning. A self-intersecting kitchen polygon is not a warning-level problem.

### 20.7 Mode E — Raster blueprint import, scale calibration, and tracing

Import a floor-plan photo or PDF page, calibrate its scale, then trace over it.

**Flow:**

1. Import an image or PDF page. PDF is preferred — pages are usually vector or high-resolution and the plan is already orthographic.
2. **Scale calibration:** the worker taps two points on the image whose real distance they know — usually a dimension printed on the drawing, or a tape measurement of one wall — and enters that distance in millimetres.
3. App computes `mmPerPixel` and stores it with the underlay.
4. Underlay renders at ~40% opacity, locked against accidental drag.
5. Worker traces walls by tapping corners. Every traced vertex snaps to the calibrated scale, so traced dimensions are in real millimetres.
6. Traced walls carry `DimensionProvenance.derived` with the calibration as their basis, **not `tape`**. State the calibration error explicitly: a 2-point calibration over 3 m with a 3-pixel tap error is roughly ±15 mm at the far end of the image. That is outside the 10 mm target. **Flag traced dimensions as lower confidence than tape, and require a tape check on critical dimensions exactly as Mode A does.**

**Do not trust a traced plan for critical dimensions without tape.** A blueprint may also be a *proposal* rather than a record of the room as built — the walls may have moved. Note this in the UI.

**Reuse:** the web already implements this entire flow — `calibrationMode`, `calibrationPoints`, `setBackgroundImage`, `updateBackgroundImage`, and the `underlay` block carrying `center`, `widthMeters`, and `angle`. Read `FloorPlanCanvas.svelte` and the `project` store for the reference behaviour before writing the Swift version.

**PDF handling.** PDF page rendering needs a rasteriser. On iOS, `PDFKit`'s `PDFPage.thumbnail(of:for:)` renders a page to an image in a few lines — use it, do not add a PDF library.

### 20.8 Room data model

**Wire format is unchanged.** `plan.json` stays exactly as specified in [section 7.2](#72-planjson--editable-plan-handoff-v1). Walls are `transform` + `dimensions`, openings reference `parentIdentifier`. **Do not introduce a vertices/nodes array into the payload** — `roomplanValidation.ts` does not know about it, the web derives start/end coordinates from `transform` + `dimensions` on import, and a second representation of the same geometry will drift.

The node/vertex view is a **derived read model**, computed in memory for the editor and the takeoff. Both representations describe the same walls:

| Concept | Wire (`plan.json`) | Derived (editor / takeoff) |
|---|---|---|
| Wall | `dimensions: [length, height, thickness]` + `transform` | `start: CGPoint`, `end: CGPoint`, `thicknessMm` |
| Corner / node | not stored | computed as a shared endpoint between two walls |
| Opening | `parentIdentifier` + `dimensions[0]` + offset from parent transform | `wallId`, `offsetMm`, `widthMm`, `sillHeightMm` |
| Room / section | `sections[].center` + `label` + `displayName` + `color` | polygon of wall endpoints enclosing `center`; `label`, `type` |
| Perimeter | not stored | sum of wall lengths |
| Floor area | not stored | polygon area, e.g. shoelace |
| Ceiling height | not stored | max wall `dimensions[1]`, or the room override |

**Room type / label.** Carried in `sections[].label` and `displayName`. Add a kitchen-specific vocabulary on top rather than a new field — `kitchen`, `pantry`, `utility`, `dining-off-kitchen`, `hall`, `other`. Keep it in `measurements.json`'s `kitchenTags` if it needs to be richer than a free-text label; do not extend the geometry payload.

**Perimeter and area are computed, never stored, never transmitted.** Storing them invites a stale value after an edit. Compute on demand at export time.

Derived-view Swift shape, for reference:

```swift
struct PlanNode: Hashable { let point: CGPoint; let wallIds: Set<String> }

struct WallSegment {
    let id: String
    let start: CGPoint        // metres, ground plane
    let end: CGPoint
    let thicknessM: Float
    let heightM: Float
    var lengthMm: Int { Int((hypot(end.x - start.x, end.y - start.y) * 1000).rounded()) }
}

struct RoomPolygon {
    let nodeIds: [String]
    let label: String
    let type: RoomType
}
```

### 20.9 Calculation engine and material takeoff

Everything here is derived from `EditedPlan` at export time. No new storage, no new sync state.

**Core calculations** (`DimensionEngine`, extending [M2](#m2--dimension-engine)):

- **Wall length** — `hypot(dx, dy)` in mm.
- **Perimeter** — sum of wall lengths, minus the width of every opening measured to its own depth if you want an internal perimeter. Report both: `perimeterOuterMm` and `perimeterInnerMm`. Kitchen skirting runs on the inner face.
- **Floor area** — polygon area via the shoelace formula, taking the **absolute value** and applying the project's area convention. `openPlan3D` already has `area-convention.test.ts` and `interior-area.test.ts` — match their convention rather than inventing one, or the phone and the web will report different areas for the same room.
- **Ceiling height** — max wall `dimensions[1]` for the room, or an explicit override the worker tapes. Tape wins.
- **Wall area** — sum of `length x height` per wall, minus openings. This is the tile / cladding / splashback figure.
- **Opening schedule** — count and dimensions of every door, window, and passage, grouped by type.

**Material takeoff** (phase 2, see [20.11](#2011-scope-call)). The takeoff is a thin layer over the core calculations:

```
floorAreaMm2        = polygon area
floorMaterialM2     = floorAreaMm2 / 1e6 x (1 + wasteMargin)
skirtingLengthMm    = perimeterInnerMm - sum(opening widths)
wallMaterialM2      = sum(wall areas) - sum(opening areas), x (1 + wasteMargin)
ceilingMaterialM2   = floorAreaMm2 / 1e6 x (1 + wasteMargin)
```

Rules:

- **Waste margin is explicit and configurable, defaulted per material** — typically 5–10% for flooring, 10% for tiles on a patterned layout. Never bake a margin into the area. Existing kitchen/bathroom flooring jobs typically quote 5–10% and tile jobs 10–15%.
- **Takeoff never mutates the plan.** It is a report.
- **Takeoff is not a cabinet layout.** The brief's non-goals exclude cabinet layout generation. Material takeoff for surfaces (flooring, tiling, skirting, ceiling) is a different thing and is in scope for phase 2; cabinet panel takeoff is not.
- Emit takeoff into `measurements.json` under a `takeoff` key, or as a separate `takeoff.json` in the package. Prefer a separate file — the dimension table stays focused.

**Consume, do not duplicate.** `openPlan3D/src/lib/utils/planStatistics.ts` already computes plan-level statistics. The designer-facing takeoff should extend that rather than adding a second calculator on the web side.

### 20.10 Web-side coverage — what already exists

Verified by inspection of the forked repository. **Do not rebuild any of this.**

| Web capability | Implementation |
|---|---|
| Template rooms | `src/lib/utils/roomTemplates.ts`, `houseTemplates.ts`, `src/lib/i18n/templateLabels.ts`, `tests/room-templates.test.ts` |
| Freeform wall drawing, corner drag, wall split, parallel move | `FloorPlanCanvas.svelte`, `addWall` / `moveWallEndpoint` / `splitWall` / `moveWallParallel` in the `project` store |
| Blueprint image import + scale calibration | `calibrationMode`, `calibrationPoints`, `setBackgroundImage`, `updateBackgroundImage` in the `project` store |
| Locked, semi-transparent tracing underlay | `underlay` block (`center`, `widthMeters`, `angle`) in `projectPackage.ts` — rendered at 0.4 opacity, locked |
| Dimension and measurement display | `addMeasurement`, `dimension-plan-geometry.test.ts`, `print-scale.test.ts` |
| Area and interior area | `planStatistics.ts`, `area-convention.test.ts`, `interior-area.test.ts` |
| Columns, stairs, guides, annotations, text | `addColumn`, `addStair`, `addGuide`, `addAnnotation`, `addTextAnnotation` |
| Curved walls | `curved-rooms.test.ts`, `curved-wall-openings.test.ts` |

**Net new web work is only:** the dimension table panel ([section 14.2](#142-new-dimension-table-panel)), capture metadata display, per-site access control, and the takeoff report. Everything else the briefs ask for on the designer side is already shipped.

### 20.11 Scope call

Adding modes B–E expands the v1 definition in [section 1](#1-product-scope), which said LiDAR room shell only. That is a real product decision, not a documentation detail. Recommended split:

| Phase | Content | Rationale |
|---|---|---|
| **v1** | Mode A only | LiDAR is the accuracy-critical path and the brief's core case. Five validation kitchens test one mode, which is the only way the M9 result means anything. |
| **v1.1** | Modes B, C, D | Removes the LiDAR device constraint, which is open question #1. **Mode B is the highest-value addition in this whole section** — a fully tape-verified plan on any device, with no scanner error to fight. |
| **v1.1** | Mode E | Blueprint tracing. Valuable but the weakest accuracy story; ship after tape-gate discipline is proven on Mode A/B. |
| **v2** | Material takeoff | Cheap once core calculations and the web statistics exist. Not needed to validate the capture premise. |
| **Web, now** | Templates, calibration, tracing, area | Already built. Zero work. |

**Do not let modes B–E delay M9.** The validation protocol needs five Mode A kitchens before anything else is worth measuring.

### 20.12 Edge cases and failure handling

| Condition | Mode(s) | Behaviour |
|---|---|---|
| Low light | A | `trackingState == .limited(.insufficientFeatures)` → persistent banner, mark `lowConfidence`, require tape on critical dimensions |
| Mirror / glass | A | Depth noise. `CoverageAnalyzer` closure check catches gross failure; surface `confidence == .low` downgrades the dimension to advisory |
| Dark matte cabinetry | A | Worst realistic case. Same as above; expect `low` confidence and require tape |
| Furniture occluding a wall | A | Wall reads short. Closure check catches an open polygon; the worker adds a missed wall via M3 |
| Scanning too fast | A | Speed warning and haptic ([section 8.2A](#82-what-to-add--three-explicit-warnings)) |
| Incomplete wall coverage | A | The critical one. Explicit closure + coverage check, never trust the success callback |
| Non-LiDAR device | A | Blocked at the device gate in M0; route to Mode B |
| No tape available on site | A, B, E | *"Could not measure"* escape with a required reason; gate result `fail`; dimension stays `scanned` |
| Self-intersecting polygon | C, D | **Hard block.** Highlight the crossing, reject the shape |
| Polygon with <3 vertices or zero area | C, D | Hard block |
| Uncalibrated blueprint | E | Block tracing until calibration is complete. An uncalibrated trace produces millimetre numbers that are meaningless |
| Blueprint is a proposal, not as-built | E | UI warning; traced dimensions capped at `derived` provenance and never `tape` |
| Huge PDF scan | E | Render a downsampled page via `PDFPage.thumbnail`; cap stored image size |
| Door/window wider than its wall | any | Reject at edit time with a named message; it will also fail web validation |
| Two walls at the same coordinates | any | Deduplicate on export; duplicate geometry fails the web identifier check if it collides |
| Room label collision across floors | any | Labels are display-only; identifiers must remain unique. Never key anything on the label |

---

## Appendix A — file copy map

Copy from the reference repos. Do not build the new repo inside them.

### From `RoomPlanExampleApp/RoomPlanSimple/` → `magpie-field/MagpieField/`

| Source | Destination | Action |
|---|---|---|
| `Constants.swift` | `App/Constants.swift` | copy |
| `AppSettings.swift` | `App/AppSettings.swift` | copy, extend with `biasFactor` |
| `LocalizationHelper.swift` | `App/LocalizationHelper.swift` | copy |
| `AppDelegate.swift`, `SceneDelegate.swift` | `App/` | copy if the UIKit lifecycle is kept |
| `RoomCaptureViewController.swift` | `Capture/` | copy, strip WiFi |
| `RoomCaptureError.swift` | `Capture/` | copy, prune `ExportFormat` |
| `MemoryMonitor.swift` | `Capture/` | copy verbatim |
| `HapticFeedbackManager.swift` | `Capture/` | copy verbatim |
| `PhotoCaptureManager.swift` | `Capture/` | copy verbatim |
| `ScanStatistics.swift` | `Dimension/` | copy, convert output to mm at the boundary |
| `FloorPlanExporter.swift` | `Export/` | copy, keep SVG/DXF only |
| `RoomExportManager.swift` | `Export/` | copy, use for the share sheet |
| `UsdzExporter` (inside `RoomExportManager` / `RoomCaptureError`) | `Export/UsdzExporter.swift` | extract |
| `RoomStorageManager.swift` | `Store/` | copy, drop WiFi artifacts, add file protection |
| `FloorPlanView.swift`, `FloorPlanViewController.swift` | reference only | superseded by the RoomPlanDemo editor |
| `HomeViewController.swift`, `SavedRoomsViewController.swift`, `SettingsViewController.swift`, `RoomViewerViewController.swift`, `OnboardingViewController.swift`, `HelpViewController.swift` | reference | rebuild screens as SwiftUI; use these for behaviour, not layout |
| `en.lproj`, `de.lproj`, `es.lproj` | `Resources/` | copy |
| `WiFiSignalManager.swift`, `WiFiOverlayView.swift`, `RFPropagationModel.swift` | — | **drop** |
| `IfcExportBridge.swift`, `bimifc_ffi.swift`, `BimIfcFFI.xcframework` | — | **drop** |
| `RoomTypeDetector.swift` | — | **drop** |
| `Secrets.swift` | — | **inspect, then template + gitignore** |

### From `RoomPlanDemo/RoomPlanDemo/` → `magpie-field/MagpieField/Editor/`

| Source | Action |
|---|---|
| `FloorPlan/FloorPlanScene.swift` | copy, re-point at `EditedPlan` |
| `FloorPlan/FloorPlanSceneView.swift` | copy |
| `FloorPlan/FloorPlanSurface.swift` | copy |
| `FloorPlan/FloorPlanObject.swift` | copy |
| `FloorPlan/FloorPlanAnnotation.swift` | copy |
| `FloorPlan/FloorPlanViewModel.swift` | copy, extend for `EditedPlan` mutations |
| `FloorPlan/DrawParameters.swift` | copy |
| `CustomViews/SurfaceDetailsView/SurfaceDetailsView.swift` | copy, add mm text fields |
| `CustomViews/ObjectDetailsView/ObjectDetailsView.swift` | copy |
| `CustomViews/AdjustMesurementView/AdjustMesurementView.swift` | copy, add mm text fields |
| `CustomViews/AddFurnitureView/AddFurnitureView.swift` | copy, extend kitchen catalog |
| `CustomViews/AnnotationsDetailsView/AnnotationsDetailsView.swift` | copy |
| `CustomViews/RoomOptionsView/RoomOptionsView.swift` | copy |
| `CustomViews/ShareImageView/ShareImageView.swift` | copy if image sharing is kept |
| `Extensions/CapturedRoom+Extensions.swift` | copy |
| `Extensions/simd_float4x4+Extensions.swift` | copy |
| `Extensions/CGPoint+Extensions.swift`, `CGFloat+Extensions.swift`, `CGMutablePath+Extensions.swift`, `SKShapeNode+Extensions.swift` | copy |
| `Models/DetailsType.swift`, `ImageFormat.swift`, `MainColor.swift`, `OpenDirection.swift`, `RoomOptionType.swift`, `SliderMesurementType.swift` | copy |
| `RoomCapture/RoomCaptureScanView.swift`, `RoomCaptureRepresentable.swift`, `RoomCaptureViewModel.swift` | reference — prefer the RoomPlanExampleApp capture layer |
| `MockDataManager.swift` | copy into the test target |
| `WelcomeView.swift`, `RoomPlanDemo.swift` | reference |

### From `iOS-RoomPlan/RoomPlanTest/` → reference only

| Source | Use |
|---|---|
| `Models/Scan.swift`, `Models/Folder.swift`, `Models/Item.swift` | shape for `SiteCapture` |
| `ViewModels/FolderViewModel.swift`, `ScanViewModel.swift` | shape for the library screen |
| `Views/SavedRoomsView.swift`, `ScanSaveSheet.swift` | shape for the library and save sheet |
| `Utilities/ScanThumbnailGenerator.swift` | copy |
| `Views/RoomscanView.swift`, `ContentView.swift` | reference only |

### From `openPlan3D/` → `magpie-studio/`

| Source | Action |
|---|---|
| entire tree | fork |
| `tests/fixtures/handoff-plan.json`, `handoff-roomplan.json` | **copy into `magpie-field`'s test bundle** |
| `src/lib/utils/roomplanImport.ts`, `roomplanValidation.ts` | keep unchanged |
| `src/lib/server/handoffUpload.ts`, `handoffStorage.ts`, `handoffQuota.ts` | extend for `measurements.json`, `model.usdz`, `photos/` |
| `src/routes/api/handoffs/` | extend; add per-site authz |
| `src/routes/render-lab/`, `src/lib/renderLab/`, `src/lib/skills/`, `src/routes/mcp/`, `tests/benchmarks/`, `tests/browser/` | consider removing to shrink the fork |

---

## Appendix B — RoomPlan API cheat sheet

Points the build will need. Verify against the SDK for your deployment target.

**Capture**

- `RoomCaptureSession` — drives the scan.
- `RoomCaptureSession.Configuration` — session options.
- `RoomCaptureView` — Apple's prebuilt UI with built-in coaching. Use it only if you decide not to build custom guidance; a custom `ARView` plus `RoomCaptureSession` gives more control over the warnings in [section 8](#8-guided-capture-engine).
- `RoomCaptureSessionDelegate` — `captureSession(_:didUpdate:)` for live updates, `captureSession(_:didProvide:)` for ARFrame access, `captureSession(_:didEndWith:error:)` for the final `CapturedRoom`.

**Model**

- `CapturedRoom` — `walls`, `doors`, `windows`, `openings`, `objects`, `floors`, plus `identifier` and `version`.
- `CapturedRoom.Surface` — `identifier`, `category`, `dimensions` (`simd_float3`), `transform` (`simd_float4x4`), `confidence`, `parentIdentifier` for openings.
- `CapturedRoom.Object` — `identifier`, `category`, `dimensions`, `transform`, `confidence`.
- `CapturedRoom.Confidence` — `.low` / `.medium` / `.high`. **Use this.** Gate critical dimensions on confidence.
- `CapturedRoom.Surface.Category` — `.wall`, `.floor`, `.door(isOpen:)`, `.window`, `.opening`, plus a large object category set.

**Construction and export**

- `RoomBuilder` — build a `CapturedRoom` from captured data. The hook for `CoverageAnalyzer`'s partial-result checks.
- `CapturedRoom.encode(to:)` — the built-in JSON encoding, for `room.json`.
- `CapturedRoom.USDZExportOption` — `.parametric`, `.mesh`, `.model`. Feeds `model.usdz`.

**ARKit**

- `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)` — the LiDAR gate.
- `ARFrame.camera.transform` — device pose, for the speed check.
- `ARCamera.trackingState` — `.normal`, `.notAvailable`, `.limited(reason)`. `.limited(.insufficientFeatures)` is the dark-room case.
- `ARCamera.TrackingState.Reason.excessiveMotion` — the too-fast case.
- `ARWorldTrackingConfiguration.sceneReconstruction = .mesh` — required for RoomPlan.

---

## Appendix C — build order quick reference

```
M0  Foundations          device gate, permissions, gitignore Secrets
M1  Capture core         port 5 files, strip WiFi/IFC
M2  Dimension engine     mm + provenance + critical set + calibration   <-- decides "high precision"
M3  Correction engine    EditedPlan + port the RoomPlanDemo scene       <-- largest port
M4  Tagging + metadata   kitchen vocabulary + site ID / worker
M5  Tape gate            the honest-number gate
M6  Export               handoff v1 exporter + fixtures test green      <-- the integration link
M7  Store + sync         encryption + queue + delete-after-checksum
M8  Designer side        fork openPlan3D + dimension panel + authz
M9  Validation           5 kitchens, tape comparison, pass/fail report  <-- v1 gate
- - - - - - - - - - - - - - deferred below this line - - - - - - - - - - -
M10 Non-LiDAR modes      manual wall scan, templates, corner plotting
M11 Blueprint tracing    import, calibrate, trace
M12 Material takeoff     perimeter, area, waste margin, takeoff.json
```

**Do not skip M2's tests or M6's fixture round-trip.** Those two tests are the difference between a prototype that demos and a prototype whose numbers can be trusted.

**Do not start M10–M12 before M9 passes.** The validation protocol measures one capture mode; adding modes first makes the result uninterpretable.
