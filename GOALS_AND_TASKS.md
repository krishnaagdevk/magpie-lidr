# Magpie LiDAR — Goals and Tasks

Execution checklist for an AI coding agent. Companion to `IMPLEMENTATION_PLAN.md` and `SETUP_WINDOWS.md` in the same directory.

**This document exists to prevent invention.** It states what is verified, what is merely known by filename, what is unknown, and what is forbidden. Read section 0, section 1, and section 2 before writing any code. If a task conflicts with this document, this document wins.

**Build environment is Windows.** This shapes the code: all pure computation lives in `MagpieCore` with no Apple imports, so it builds and tests locally. See `SETUP_WINDOWS.md` §2 before creating any source file, and §7 for the recommended work order.

---

## 0. Operating rules

**R0.1 — Read before you port. Always.**
Every task that says "port file X" requires you to read X in full first and emit a list of its public symbols (types, functions, properties) as intermediate output. Then port. Do not port from a filename, from a summary, or from this document. This document tells you *which* files matter; it does not tell you *what is in them*.

**R0.2 — Cite, do not assume.**
When you use an API, you must have seen it in a source file you read, or in `IMPLEMENTATION_PLAN.md` Appendix B. If neither, stop and say so. Do not invent a plausible-looking RoomPlan or ARKit symbol. RoomPlan API names are easy to guess wrong (`CapturedRoom.Surface.Category.wall` is real; `CapturedRoom.Wall` is not).

**R0.3 — Unknown means unknown.**
Section 1.3 lists files whose **existence** is verified but whose **contents are not**. Treat their contents as unknown until you read them. Do not infer behaviour from a filename.

**R0.4 — One task, one commit.**
Do not combine tasks. Do not skip ahead. The phase order in section 5 is load-bearing: phase 2 has a hard gate before phase 3.

**R0.5 — Report blockers, do not route around them.**
Section 3 lists conditions that require stopping and asking. Do not resolve them by picking a sensible default and continuing.

**R0.6 — No new dependencies without approval.**
Swift: use only Apple frameworks and anything already in the source repos' project files. Web: use only what is already in `package.json`. Adding a package requires an explicit decision recorded in section 6.

---

## 1. Verified facts

### 1.1 Repository inventory — VERIFIED

Working directory: `C:\Users\hp\Desktop\magpie_lidr`

| Directory | Content | Verification method |
|---|---|---|
| `iOS-RoomPlan/` | SwiftUI + SwiftData starter. Xcode project `RoomPlanTest.xcodeproj`, app target `RoomPlanTest`. | directory listing |
| `RoomPlanDemo/` | UIKit + SpriteKit capture app with 2D floor-plan editor. Target `RoomPlanDemo`. | directory listing + file listing |
| `RoomPlanExampleApp/` | UIKit capture app with multi-format export. App source dir `RoomPlanSimple/`, app target and scheme `RoomPlanSimple`. | directory listing + file listing; target verified 2026-10-10 |
| `openPlan3D/` | SvelteKit 5 + Three.js web CAD editor. Package name `open3dfloorplan`, v0.9.0, SvelteKit `^2.70.3`, Svelte `^5.57.0`, three `^0.182.0`, firebase `^12.18.0`, vitest, playwright. | `package.json` read |

**Do not modify any of these four directories.** They are reference checkouts. Build new projects alongside them.

### 1.2 Files inspected — what is actually known

Confidence legend:
- **FULL** — read completely. Content may be quoted and relied on.
- **PARTIAL** — read a range only. Do not assume the rest.
- **GENERIC** — first N lines only, for orientation.
- **GREP** — a symbol list or specific string matches, not the whole file.

| Path (under `magpie_lidr/`) | Conf. | What is known |
|---|---|---|
| `openPlan3D/docs/handoff-format-v1.md` | **FULL** | The complete iPhone→web handoff v1 contract. Metres on the wire, centimetres in the web model. Column-major 4×4 transforms. RoomPlan X→web X, Z→web Y. Heading `atan2(t[2], t[0])`. Unique identifiers. Openings need `parentIdentifier` on the same `story`. Wall thickness default 15 cm on zero/missing. Door styles `single/double/sliding/patio`; window styles `fixed/sliding`. Raw-capture ZIP must contain exactly one `room.json`. A dataset with `plan.json` is rejected by the raw-capture path. `openplanPrepared: true` disables auto-straightening. |
| `openPlan3D/src/lib/utils/roomplanValidation.ts` | **FULL** | The exact validator. Function `isRoomPlanJson(data)` (line 2) and `validateRoomPlan(data)` (line 8). Full field-by-field rules — see section 2.2, which reproduces every check. Throws `Error("Invalid RoomPlan file: <path> <reason>. No project was imported.")`. |
| `openPlan3D/src/lib/utils/roomplanImport.ts` | **PARTIAL** (1–70) | Exists, imports RoomPlan JSON into editable geometry. **The rest is unknown.** |
| `openPlan3D/tests/fixtures/handoff-roomplan.json` | **PARTIAL** (1–50) | Exists. Shape glimpsed only. **Contents are not fully known — read before using as a test oracle.** |
| `RoomPlanExampleApp/RoomPlanSimple/FloorPlanView.swift` | **PARTIAL** | `struct FloorPlanElement: Codable` (line 45) with nested `enum ElementType: Codable` (line 51) and a custom single-value `encode` (line 77). `struct FloorPlanData: Codable` (line 91) with a custom `encode` (line 117) and `var elements: [FloorPlanElement]` (line 126). `class FloorPlanView: UIView` (line 276) with `scale`, `offset`, `zoomScale`, `panOffset`, `rotationAngle`, `minZoom`, `maxZoom`, `wifiSamples`, `showDimensions`, `showLabels`, `showWifiHeatmap`. |
| `RoomPlanExampleApp/RoomPlanSimple/FloorPlanExporter.swift` | **PARTIAL** (1–100) + GREP | `enum ExportFormat: String, CaseIterable { case svg; case dxf }` (line 16) with `localizedName` and `fileExtension`. **Note the name collision:** there is *another* `ExportFormat` in `RoomCaptureError.swift`. They are different enums. Do not merge them blindly. |
| `RoomPlanExampleApp/RoomPlanSimple/RoomCaptureError.swift` | **PARTIAL** (50–110) | `enum ExportFormat: String, CaseIterable` (line 52) with cases commented as USDZ variants (`parametric`, `model`, `mesh`) and converted formats (`obj`, `stl`). **Second enum, same name as the one in `FloorPlanExporter.swift`.** |
| `RoomPlanExampleApp/RoomPlanSimple/RoomExportManager.swift` | **PARTIAL** (1–100) + GREP | It is a **share-sheet dispatcher**, 147 lines. `showExportOptions(...)` (line 32), `performExport(...)` (line 71), `convertToFormat(from:to:format:)` (line 108), `presentShareSheet(...)` (line 124), `formatDate(...)` (line 142). It is **not** the JSON writer. Do not look here for the plan serialiser. |
| `RoomPlanExampleApp/RoomPlanSimple/RoomStorageManager.swift` | **PARTIAL** (1–250) + GREP | A `JSONEncoder` at line 20. Per-room files in one directory: `<uuid>.json` metadata (lines 175, 459, 652, 797), `<uuid>_floorplan.json` (lines 115, 362, 582), `<uuid>_wifi.json` (lines 143, 250, 596). Export bundles copy to `dest<name>_metadata.json` etc. (lines 584–598). |
| `RoomPlanExampleApp/RoomPlanSimple/ScanStatistics.swift` | **PARTIAL** (1–100) | 197 lines. Exists and computes statistics. **Full field list unknown — read before extending.** |
| `RoomPlanExampleApp/RoomPlanSimple/RoomCaptureViewController.swift` | **PARTIAL** (1–100, 200–500) | Exists, drives the capture session. |
| `RoomPlanExampleApp/RoomPlanSimple/Constants.swift` | **GENERIC** (1–63) | 63 lines. |
| `RoomPlanDemo/RoomPlanDemo/FloorPlan/FloorPlanScene.swift` | **PARTIAL** (1–405) | The SpriteKit 2D plan scene. **This is the correction engine to port.** Full symbol list unknown — read before porting. |
| `RoomPlanDemo/RoomPlanDemo/FloorPlan/FloorPlanViewModel.swift` | **GENERIC** (1–23) | 23 lines only. |
| `RoomPlanDemo/RoomPlanDemo/RoomCapture/RoomCaptureScanView.swift` | **PARTIAL** (1–150) | SwiftUI representable wrapper. |
| `RoomPlanDemo/RoomPlanDemo/RoomCapture/RoomCaptureViewModel.swift` | **PARTIAL** (1–110) | Exists. |
| `RoomPlanDemo/RoomPlanDemo/CustomViews/SurfaceDetailsView/SurfaceDetailsView.swift` | **GENERIC** (1–60) | Wall editor UI. |
| `RoomPlanDemo/RoomPlanDemo/CustomViews/ObjectDetailsView/ObjectDetailsView.swift` | **GENERIC** (1–60) | Object editor UI. |
| `RoomPlanDemo/RoomPlanDemo/CustomViews/AdjustMesurementView/AdjustMesurementView.swift` | **GENERIC** (1–60) | Measurement adjust UI. |
| `iOS-RoomPlan/RoomPlanTest/Views/RoomscanView.swift` | **GENERIC** (1–100) | Capture view. |
| `iOS-RoomPlan/RoomPlanTest/Views/ScanSaveSheet.swift` | **GENERIC** (1–60) | Save sheet. |
| `openPlan3D/src/lib/components/editor/FloorPlanCanvas.svelte` | **GREP** | Imports from `$lib/stores/project`: `calibrationMode`, `calibrationPoints`, `setBackgroundImage`, `updateBackgroundImage`, `addWall`, `updateWall`, `moveWallEndpoint`, `moveWallGeometryDuringDrag`, `addDoor`, `addWindow`, `addFurniture`, `addColumn`, `addStair`, `addGuide`, `addMeasurement`, `addAnnotation`, `addTextAnnotation`, `splitWall`, `moveWallParallel`, `duplicateDoor`, `snapEnabled`, `placingDoorType`, `placingWindowType`, `placingStair`, `placingColumn`, `placingColumnShape`, `placingEntourageId`, `addEntourageItem`, `updateRoom`, `createGroup`, `ungroupElements`, `elevationWallId`, `elevationPickMode`, `canvasZoom`, `panMode`, `layerVisibility`, `showFurnitureStore`. Has `isCalibrating` state (line 218), calibration point rendering (line 1466), calibration click handling (line 2396). |
| `openPlan3D/src/lib/services/projectPackage.ts` | **GREP** | `underlayBackground(plan, assets)` (line 44) reads `plan.underlay`, `plan.underlay.imageFilename`, `plan.underlay.center.x/y`, `plan.underlay.widthMeters`, `plan.underlay.angle`. Renders at `opacity: 0.4`, `locked: true`. Reads `state?.native.underlay?.level` (line 79). |
| `openPlan3D/src/lib/utils/planStatistics.ts` | **GREP** | `export function planStatistics(project: Project, plan: ObjectMap, mapping: PackageMapping): PlanStatisticsBlock` (line 42). |

### 1.3 Files known by NAME ONLY — contents unknown

Existence is verified. **Contents are not.** Read before you rely on any of them. Do not infer behaviour from the name.

**`RoomPlanExampleApp/RoomPlanSimple/`** (full listing verified):
`AppDelegate.swift`, `AppSettings.swift`, `bimifc_ffi.swift`, `FloorPlanViewController.swift`, `HapticFeedbackManager.swift`, `HelpViewController.swift`, `HomeViewController.swift`, `IfcExportBridge.swift`, `LocalizationHelper.swift`, `MemoryMonitor.swift`, `OnboardingViewController.swift`, `PhotoCaptureManager.swift`, `RFPropagationModel.swift`, `RoomTypeDetector.swift`, `RoomViewerViewController.swift`, `SavedRoomsViewController.swift`, `SceneDelegate.swift`, `Secrets.swift`, `SettingsViewController.swift`, `WiFiOverlayView.swift`, `WiFiSignalManager.swift`, `Info.plist`; directories `Base.lproj/`, `de.lproj/`, `en.lproj/`, `es.lproj/`, `Assets.xcassets/`.

**`RoomPlanDemo/RoomPlanDemo/`** (full listing verified):
`FloorPlan/DrawParameters.swift`, `FloorPlan/FloorPlanAnnotation.swift`, `FloorPlan/FloorPlanObject.swift`, `FloorPlan/FloorPlanSceneView.swift`, `FloorPlan/FloorPlanSurface.swift`; `CustomViews/AddFurnitureView/AddFurnitureView.swift`, `CustomViews/AnnotationsDetailsView/AnnotationsDetailsView.swift`, `CustomViews/RoomOptionsView/RoomOptionsView.swift`, `CustomViews/ShareImageView/ShareImageView.swift`; `Extensions/CapturedRoom+Extensions.swift`, `Extensions/CGFloat+Extensions.swift`, `Extensions/CGMutablePath+Extensions.swift`, `Extensions/CGPoint+Extensions.swift`, `Extensions/simd_float4x4+Extensions.swift`, `Extensions/SKShapeNode+Extensions.swift`; `Models/DetailsType.swift`, `Models/ImageFormat.swift`, `Models/MainColor.swift`, `Models/OpenDirection.swift`, `Models/RoomOptionType.swift`, `Models/SliderMesurementType.swift`; `RoomCapture/RoomCaptureRepresentable.swift`; `MockDataManager.swift`, `WelcomeView.swift`, `RoomPlanDemo.swift`.

**`iOS-RoomPlan/RoomPlanTest/`** (full listing verified):
`ContentView.swift`, `RoomPlanTestApp.swift`, `Models/Folder.swift`, `Models/Item.swift`, `Models/Scan.swift`, `Utilities/ScanThumbnailGenerator.swift`, `ViewModels/FolderViewModel.swift`, `ViewModels/ScanViewModel.swift`, `Views/SavedRoomsView.swift`.

**`openPlan3D/`** (partial listing verified):
`src/lib/utils/roomplanImport.ts`, `src/lib/utils/roomplanValidation.ts`; `src/lib/server/handoffQuota.ts`, `handoffStorage.ts`, `handoffUpload.ts`; `src/lib/skills/handoff.ts`, `photos.ts`, `summary.ts`; `src/lib/stores/project.ts`, `settings.ts`, `project.ts`, `theme.ts`, `aiKeys.ts`; `src/lib/components/editor/FloorPlanCanvas.svelte`, `PrintLayout.svelte`, `ContextMenu.svelte`; `src/lib/components/sidebar/BuildPanel.svelte`, `LayersPanel.svelte`, `PropertiesPanel.svelte`; `src/routes/api/handoffs/`; `src/lib/utils/roomTemplates.ts`, `houseTemplates.ts`, `export.ts`, `alignment.ts`, `canvasRenderer.ts`, `planStatistics.ts`, `projectValidation.ts`, `projectPackageBridge.ts`; `src/lib/firebase.ts`, `src/lib/models/types.ts`; `src/lib/i18n/templateLabels.ts`; `docs/handoff-quotas.md`, `docs/reviews/*`.

**Test files verified to exist** in `openPlan3D/tests/` — relevant ones:
`roomplan-import.test.ts`, `room-templates.test.ts`, `area-convention.test.ts`, `interior-area.test.ts`, `print-scale.test.ts`, `dimension-plan-geometry.test.ts`, `curved-rooms.test.ts`, `curved-wall-openings.test.ts`, `crossing-rooms.test.ts`, `overlapping-rooms.test.ts`, `room-deletion.test.ts`, `room-nesting.test.ts`, `room-slab-geometry.test.ts`, `wall-room-split.test.ts`, `handoff-quota.test.ts`, `export-notice.test.ts`, `exports.test.ts`, `floors.test.ts`, `floor-stack.test.ts`, `furniture-categories.test.ts`, `furniture-models.test.ts`, `furniture-dxf.test.ts`, `furniture-svg.test.ts`, `itemDetails.test.ts`, `length-formatting.test.ts`, plus `tests/fixtures/`, `tests/browser/`, `tests/benchmarks/`.

### 1.4 Verified capabilities on the web side

These are confirmed to exist. **Do not rebuild them.**

| Capability | Evidence |
|---|---|
| Template rooms and multi-room house templates | `src/lib/utils/roomTemplates.ts`, `houseTemplates.ts`, `tests/room-templates.test.ts` |
| Blueprint image import + scale calibration | `calibrationMode`, `calibrationPoints`, `setBackgroundImage`, `updateBackgroundImage` imported by `FloorPlanCanvas.svelte` |
| Locked semi-transparent tracing underlay | `underlayBackground()` in `projectPackage.ts`, `opacity: 0.4`, `locked: true` |
| Freeform wall drawing, split, parallel move, corner drag | `addWall`, `splitWall`, `moveWallParallel`, `moveWallEndpoint` |
| Area conventions | `tests/area-convention.test.ts`, `tests/interior-area.test.ts`, `planStatistics.ts` |
| Plan statistics | `planStatistics(project, plan, mapping): PlanStatisticsBlock` |
| Furniture catalog and DXF/SVG export | `furniture-categories.test.ts`, `furniture-dxf.test.ts`, `furniture-svg.test.ts` |
| Handoff upload with quota | `src/routes/api/handoffs/`, `src/lib/server/handoffUpload.ts`, `handoffQuota.ts`, `docs/handoff-quotas.md` |

### 1.5 The verified gap

A repository-wide search for `openplanPrepared`, `openplanHandoffVersion`, and `openplanImportOptions` across all `.swift` files in the three iOS repositories returned **zero matches**.

**Conclusion: no iOS repository in this folder emits the handoff v1 format.** Writing that exporter is task T-601 and it is the single most important task in the project. Do not look for an existing implementation in the iOS repos. There isn't one.

---

## 2. Forbidden — hallucination traps

### 2.1 Do not invent RoomPlan or ARKit APIs

Only use a symbol if you have seen it in a file you read, or in `IMPLEMENTATION_PLAN.md` Appendix B. Known-good examples: `CapturedRoom`, `CapturedRoom.Surface`, `CapturedRoom.Object`, `CapturedRoom.Confidence`, `RoomCaptureSession`, `RoomCaptureSessionDelegate`, `RoomBuilder`, `ARWorldTrackingConfiguration`, `ARCamera.trackingState`.

Known traps:

| Invented | Reality |
|---|---|
| `CapturedRoom.Wall` | Does not exist. Walls are `CapturedRoom.Surface` with `category == .wall`. |
| `CapturedRoom.roomIdentifier` | Not verified. Read the SDK header before using. |
| `CapturedRoom.Surface.normal` | Not verified as a public property. Position/heading come from `transform`. |
| `ARView.session.currentFrame` for RoomPlan | RoomPlan's session is `RoomCaptureSession`, not a plain `ARSession`. |

If you need a symbol not on the verified list, **stop and say so** rather than writing a plausible guess. A guessed symbol produces a compile error at best and wrong geometry at worst.

### 2.2 Do not invent contract fields — the validator is the spec

`validateRoomPlan()` in `openPlan3D/src/lib/utils/roomplanValidation.ts` is the authoritative schema. Reproduced exactly, because violating any line rejects the **entire** import:

```
document                     must be an object
walls                        must be an array (required)
openplanHandoffVersion       if present, must equal 1
walls, doors, windows, openings, objects[]
  each item                  must be an object
  .identifier                must be a non-empty trimmed string, unique across ALL five arrays
  .dimensions                must be an array, length >= 2, all finite,
                             dimensions[0] > 0, dimensions[1] > 0,
                             dimensions[2] (if present) >= 0,
                             for objects specifically dimensions[2] must be > 0
  .transform                 must be an array of exactly 16 finite numbers,
                             and hypot(transform[0], transform[2]) >= 1e-8
  .story                     if present, must be a safe integer
  .hingeLeft, .opensInward   if present, must be boolean
  .sillHeight                if present, must be a finite number >= 0
  .style                     if present: doors -> single|double|sliding|patio
                                        windows -> fixed|sliding
doors, windows, openings[]
  .parentIdentifier          must resolve to a wall, on the SAME story
stories[]
  .index                     must be a safe integer
  .name                      must be a string
                             duplicate index is rejected
sections[]
  .center                    array of exactly 3 finite numbers
  .label                     must be a string
  .story                     if present, must be a safe integer
  .displayName, .color       if present, must be strings
openplanImportOptions        if present: object with boolean .straighten and boolean .orthogonal
```

Consequences:

- **Do not add a `vertices` or `nodes` array to the payload.** The validator does not know it. Start/end coordinates are derived on the web from `transform` + `dimensions`.
- **Do not add a `perimeter` or `area` field to the payload.** Derived, not transmitted. See `IMPLEMENTATION_PLAN.md` section 20.8.
- **Do not rename fields.** `parentIdentifier`, not `parentId`. `sillHeight`, not `sill`. `hingeLeft`, not `hinge`.
- Unknown **top-level** keys are ignored by the validator, so a namespaced extension block would pass. Do not rely on that without a decision recorded in section 6. Put variable capture data in the separate `measurements.json` sidecar instead.

### 2.3 Do not add scope

Forbidden in v1 (see `IMPLEMENTATION_PLAN.md` section 17). If you find yourself writing any of this, stop:

- WiFi, RF propagation, or signal mapping code. Do not port `WiFiSignalManager.swift`, `WiFiOverlayView.swift`, `RFPropagationModel.swift`, or any `_wifi.json` handling.
- IFC / BIM export. Do not port `IfcExportBridge.swift`, `bimifc_ffi.swift`, or link `BimIfcFFI.xcframework`.
- OBJ or STL export. Prune `ExportFormat` cases that nothing in v1 consumes.
- Automatic room type detection. Do not port `RoomTypeDetector.swift`.
- Any LLM, assistant, or AI feature. `openPlan3D` has an `ai/` component directory and `skills/` — leave them alone.
- Material takeoff. Deferred to M12. Do not start it during M0–M9.
- Non-LiDAR capture modes, templates, corner plotting, blueprint tracing. Deferred to M10/M11.
- Cabinet layout generation. A named v1 non-goal.

### 2.4 Do not add dependencies

- **Swift:** Apple frameworks only, plus what the source projects already link. Do not add a ZIP library to build the export package if the existing storage code already has a bundling approach — read `RoomStorageManager.swift` first. For PDF page rendering use `PDFKit`'s `PDFPage.thumbnail(of:for:)`; do not add a PDF library.
- **Web:** only what is in `openPlan3D/package.json` at the forked commit. Do not `npm install` anything new.

### 2.5 Do not trust a filename

Filenames in these repos are misleading in at least these verified cases:

- `RoomExportManager.swift` does **not** write JSON. It dispatches the share sheet. The JSON writer lives elsewhere — find it.
- There are **two different `ExportFormat` enums**: one in `FloorPlanExporter.swift` (svg/dxf) and one in `RoomCaptureError.swift` (parametric/model/mesh/obj/stl). They are unrelated. Do not merge them.
- `RoomStorageManager.swift` writes a `_floorplan.json` that is **not** the handoff format. It is that app's own internal plan serialisation. Do not assume it matches anything else.
- `Scanner.swift`-style names do not exist here; do not invent files that "should" be there.

### 2.6 Do not claim verified work you did not verify

When reporting progress, distinguish:
- **Ported and compiles** — you read the source, wrote the target, and it builds.
- **Ported and tested** — plus a test you wrote passes.
- **Assumed** — you did not read the source. Do not use this category; go read it.

Do not report a task done because the file exists. Every task in section 5 has an explicit verify step. Run it.

---

## 3. Stop-and-ask triggers

Stop and ask a human when any of these is true. Do not pick a default and continue.

| # | Trigger |
|---|---|
| S1 | A required symbol is not in section 1.2 and not in Appendix B, and you cannot find it by reading the SDK headers or the source repos. |
| S2 | **RESOLVED 2026-10-10.** `RoomPlanExampleApp`'s app target and scheme are `RoomPlanSimple`. Do not re-trigger this. |
| S3 | `RoomPlanExampleApp/RoomPlanSimple/Secrets.swift` contains what looks like a live credential. Report the file and stop; do not copy it, do not print the value, do not commit it. |
| S4 | `openPlan3D/tests/fixtures/handoff-plan.json` or `handoff-roomplan.json` cannot be found in the forked repo, or their contents do not match the contract in `docs/handoff-format-v1.md`. Do **not** hand-write the schema from prose. |
| S5 | The web import rejects a package that your exporter validated locally. Report both the local validator output and the server error verbatim. Do not "fix" the exporter by loosening the local validator. |
| S6 | `handoffQuota.ts`'s size limit is smaller than a realistic USDZ + photos package. Report the limit and the package size. |
| S7 | Any task in section 5 asks you to make a product decision that section 6 of `IMPLEMENTATION_PLAN.md` marks as an open question. |
| S8 | A file you are told to port contains substantial code outside the task's stated purpose (e.g. `RoomCaptureViewController.swift` contains WiFi handling you were told to strip). Report the boundary you found before porting. |

---

## 4. Goals

Goals are the acceptance criteria for the whole project. Every task in section 5 traces to at least one goal (see section 7).

| ID | Goal | Measurable success |
|---|---|---|
| **G1** | A field worker can scan a kitchen and get a dimensioned model in a few minutes, with no design training. | Five consecutive scans on an iPhone 16 Pro with zero crashes and no abandoned sites. |
| **G2** | Every dimension the app presents carries explicit provenance, and no scan value is ever presented as certified. | 100% of dimensions in `measurements.json` have a `provenance` field. Zero UI surfaces render a `scanned` value without an advisory marker. |
| **G3** | The worker can correct the scan on site — relabel, add a missed wall, delete a false detection. | An edit to a wall, an object label, a deletion, and an added wall all appear in the exported `plan.json`. |
| **G4** | Bad scans are caught before the worker trusts them. | `CoverageAnalyzer` flags every scan with an open wall polygon in the validation set; false-positive rate measured, not zero. |
| **G5** | The designer opens the package and gets trustworthy, correctly-labelled dimensions with no re-measuring. | A package exports from the phone and imports into an unmodified `openPlan3D` with correct geometry, floors, and openings. The dimension panel shows tape and scanned values visually distinct. |
| **G6** | Capture works offline and uploads later, without losing or leaking data. | Airplane-mode capture of three sites, all three upload on reconnect, local files removed only after checksum confirmation. Files unreadable while the device is locked. |
| **G7** | The product case is proven or disproven with data. | A written report against the pre-agreed criteria in `IMPLEMENTATION_PLAN.md` section 16.1, naming the dimensions and room conditions that failed. |

---

## 5. Task list

Ordering is mandatory. Phase 2 (T-201) is a **hard gate**: do not begin phase 3 until it is green.

Legend: **Src** = source to port from. **Tgt** = file to create. **Verify** = the check that proves it is done.

---

### Phase 0 — Setup and reconnaissance

---

**T-001 — Create the iOS project**
- Goal: G1
- Action: Create a new Xcode project for iOS 17+ at `magpie_lidr/magpie-field/`. SwiftUI app lifecycle, with a UIKit bridge available for the capture controller. Bundle id and team from the human, not invented.
- Verify: project builds and launches on an iPhone 16 Pro simulator.
- Blocker: D2. (S2 is resolved — target is `RoomPlanSimple`.)
- Note: requires macOS. See `SETUP_WINDOWS.md` §6.

---

**T-002 — Establish the target tree**
- Goal: G1
- Action: Create the directory structure from `IMPLEMENTATION_PLAN.md` section 5 inside `magpie-field/MagpieField/`. Empty groups are fine.
- Verify: `find magpie-field -type d` matches section 5.

---

**T-003 — Read and document the four reference repos**
- Goal: all
- Src: all four directories
- Action: For each repo, read its README if present and its Xcode project or `package.json`. Emit a short inventory: target names, deployment targets, linked frameworks, and any dependency manager in use.
- Verify: the inventory states the **actual** app target and scheme name for `RoomPlanExampleApp`.
- Status: **DONE 2026-10-10.** Target and scheme are `RoomPlanSimple`. S2 and D1 resolved.

---

**T-004 — Secure the credential surface**
- Goal: G6
- Src: `RoomPlanExampleApp/RoomPlanSimple/Secrets.swift`
- Action: Read the file. If it contains only placeholders, note that and continue. If it contains anything resembling a live key, **stop — trigger S3**, report the filename only, and proceed no further until the human responds.
- Action (safe path only): add `Secrets.swift` to `.gitignore` **before** creating the repo, and create a `Secrets.swift.template` with empty constants.
- Verify: `git log --all -p | grep -i <key-prefix>` returns nothing once the repo exists. Do not print a key to verify this.
- Status: **DONE 2026-10-10.** Inspected; loader only, no live keys. S3 not triggered. The `.gitignore` and template steps still apply when the new repo is created in T-001.

---

**T-005 — Device capability gate**
- Goal: G1
- Action: Port the LiDAR check. Verify `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)`. On unsupported hardware, show a clear message and route to the manual path when M10 exists, or refuse cleanly before M10.
- Verify: runs correctly on both a LiDAR device and a non-LiDAR simulator, with different behaviour on each.

---

**T-006 — Permissions and privacy manifest**
- Goal: G6
- Action: Add `NSCameraUsageDescription`. Confirm no entitlement is requested that the app does not use. Do not add data-protection opt-outs.
- Verify: `Info.plist` diff reviewed; no unused entitlements.

---

**T-007 — Create the MagpieCore SwiftPM package**
- Goal: G2, G5
- Action: Create `magpie-field/MagpieCore/` as a standalone SwiftPM library. Add an empty `Sources/MagpieCore/` and `Tests/MagpieCoreTests/`. Declare the package with no dependencies. **No Apple imports — see `CLAUDE.md` hard rule 7.**
- Tgt: `magpie-field/MagpieCore/Package.swift`
- Verify: `swift build` and `swift test` both pass **on Windows**. This is the task that establishes local testability; if it does not work, the rest of the Windows-first order in `SETUP_WINDOWS.md` §7 is invalid.
- Note: run this before any Xcode work. It needs no Mac.
- Reference: `SETUP_WINDOWS.md` §5.

---

### Phase 1 — Capture core

---

**T-101 — Port the capture controller**
- Goal: G1
- Src: `RoomPlanExampleApp/RoomPlanSimple/RoomCaptureViewController.swift`
- Action: **First** read it fully and emit its public symbol list. Then port. Strip any WiFi or IFC code paths — report the boundary you found (trigger S8 if substantial).
- Tgt: `Capture/RoomCaptureViewController.swift`
- Verify: a room scans and produces a `CapturedRoom`.

---

**T-102 — Port memory and haptics support**
- Goal: G1
- Src: `MemoryMonitor.swift`, `HapticFeedbackManager.swift`
- Action: Read both fully, emit symbol lists, port verbatim. These are stated to be self-contained.
- Tgt: `Capture/MemoryMonitor.swift`, `Capture/HapticFeedbackManager.swift`
- Verify: five consecutive scans without a memory crash.

---

**T-103 — Port typed errors, pruning the format enum**
- Goal: G1
- Src: `RoomCaptureError.swift`
- Action: Read fully. Port the error types. Prune `ExportFormat` cases that v1 does not consume (keep what T-602 needs: parametric/model/mesh for USDZ; drop obj/stl unless something else uses them — check callers first with a grep).
- Tgt: `Capture/RoomCaptureError.swift`
- Verify: compiles with no references to deleted cases. Grep for the deleted case names to confirm zero hits.

---

**T-104 — Port photo capture**
- Goal: G5
- Src: `PhotoCaptureManager.swift`
- Action: Read fully, port verbatim.
- Tgt: `Capture/PhotoCaptureManager.swift`
- Verify: a photo is captured during a scan and written to the package photo directory.

---

**T-105 — USDZ export**
- Goal: G3, G5
- Src: the USDZ path inside `RoomExportManager.swift` and the `ExportFormat` cases in `RoomCaptureError.swift`
- Action: Read both. Extract a `UsdzExporter` that takes a `CapturedRoom` and an export option and returns a URL. Do **not** use `RoomExportManager` for this; it is a share-sheet dispatcher (verified, section 2.5).
- Tgt: `Export/UsdzExporter.swift`
- Verify: exports each option in use, and the file opens in macOS Quick Look / Preview.

---

### Phase 2 — Dimension engine (HARD GATE)

Do not begin phase 3 until T-201 and T-202 are complete and green.

---

**T-201 — Port and convert ScanStatistics to millimetres**
- Goal: G2
- Src: `RoomPlanExampleApp/RoomPlanSimple/ScanStatistics.swift`
- Action: Read fully and emit the complete field list. Port it. Convert every length output to millimetres **at the boundary only**; keep metres internally. Do not perform arithmetic in millimetres and convert back.
- Tgt: `Dimension/ScanStatistics.swift`
- Verify: `DimensionEngineTests.swift` asserts that a known metre input produces the expected integer millimetre output, including a rounding case (e.g. 3.4565 m).
- **This is a hard gate.** Report the field list before porting.

---

**T-202 — The provenance model**
- Goal: G2
- Action: Implement `DimensionProvenance` with cases `scanned`, `tape`, `derived`, `calibrated`, and `Measurement` carrying `valueMm`, `valueScannedMm`, `provenance`, `critical`, `toleranceMm`, `deviationMm`, `withinTolerance`, `note`.
- Tgt: `Model/Measurement.swift`
- Verify: unit test asserting that a `derived` value computed from a mix of `tape` and `scanned` inputs does not claim `tape`.
- Rule from the plan: never overwrite a `scanned` value with a `tape` value. Both are exported.

---

**T-203 — Dimension engine**
- Goal: G2
- Action: Walk a `CapturedRoom` or `EditedPlan` and emit `[Measurement]`, every value `provenance: .scanned`. Use `CapturedRoom.Confidence` where available and downgrade `low` confidence dimensions in the output.
- Tgt: `Dimension/DimensionEngine.swift`
- Verify: a scanned room produces a dimension list in millimetres with every value badged `scanned`.

---

**T-204 — Critical dimension rules**
- Goal: G2, G4
- Action: Implement the rules from `IMPLEMENTATION_PLAN.md` section 6.4: cabinet-run wall length, opening width adjacent to an appliance or cabinet, ceiling height for the primary room, corner-to-corner diagonal for a non-rectangular room, gap between two tagged fixed objects. Fall back to ceiling height and the longest wall when no tags exist.
- Tgt: `Dimension/CriticalDimension.swift`
- Verify: a room with no tags yields a non-empty critical set. A room with a wall tagged `base-cabinet-run` includes that wall.
- **Do not implement tagging here.** T-401 wires tags in. This task handles the no-tag fallback.

---

**T-205 — Bias calibration**
- Goal: G2
- Action: Store `biasFactor`, `calibratedAt`, `referenceDescription` in app settings, persisted. Compare one known reference to its scanned length; apply the factor to subsequent `scanned` dimensions and mark them `calibrated`. Leave the factor user-visible and editable.
- Tgt: extend `App/AppSettings.swift`
- Verify: entering a reference of 2000 mm against a scanned 2010 mm stores a factor of ~0.995, and a later 3500 mm wall reports ~3483 mm with provenance `calibrated`.

---

### Phase 3 — Correction engine

---

**T-301 — EditedPlan, the single source of truth**
- Goal: G3, G5
- Action: Define `EditedPlan` and its children `PlanWall`, `PlanOpening`, `PlanObject`, `PlanSection` as `Codable` types with stable `identifier`, `simd_float4x4 transform`, `simd_float3 dimensions`. Seed an `EditedPlan` from a `CapturedRoom`.
- Tgt: `Model/EditedPlan.swift` and siblings
- Verify: a round trip `CapturedRoom -> EditedPlan -> EditedPlan` preserves wall count and every identifier.
- **Critical design rule:** every capture mode produces an `EditedPlan`. The scene graph is a view. Do not let edits live only in the scene.

---

**T-302 — Port the floor-plan scene**
- Goal: G3
- Src: `RoomPlanDemo/RoomPlanDemo/FloorPlan/FloorPlanScene.swift`, `FloorPlanSceneView.swift`, `FloorPlanSurface.swift`, `FloorPlanObject.swift`, `FloorPlanAnnotation.swift`, `FloorPlanViewModel.swift`, `DrawParameters.swift`
- Action: Read each fully and emit symbol lists. Port. Then **re-point every derivation at `EditedPlan`** and route every gesture into an `EditedPlan` mutation. This is the main refactor of the project — budget real time.
- Tgt: `Editor/Editor/*.swift`
- Verify: moving a wall in the scene changes the `EditedPlan` value; a snapshot of the edited plan encodes and decodes.

---

**T-303 — Port the geometry extensions**
- Goal: G3
- Src: `RoomPlanDemo/RoomPlanDemo/Extensions/*.swift` — `CapturedRoom+Extensions.swift`, `simd_float4x4+Extensions.swift`, `CGPoint+Extensions.swift`, `CGFloat+Extensions.swift`, `CGMutablePath+Extensions.swift`, `SKShapeNode+Extensions.swift`
- Action: Read each, emit symbol lists, port.
- Tgt: `Editor/Extensions/*.swift`
- Verify: compiles; the scene's existing geometry code uses them unchanged.

---

**T-304 — Port the edit UIs**
- Goal: G3
- Src: `SurfaceDetailsView.swift`, `ObjectDetailsView.swift`, `AdjustMesurementView.swift`, `RoomOptionsView.swift`, `AnnotationsDetailsView.swift`, `ShareImageView.swift`
- Action: Read each, emit symbol lists, port.
- Tgt: `Editor/*.swift`
- Verify: each editor opens and its changes reach `EditedPlan`.

---

**T-305 — Millimetre numeric entry on every edit**
- Goal: G2, G3
- Action: Add a numeric text field with a millimetre keyboard beside every slider in `SurfaceDetailsView` and `AdjustMesurementView`. Keep the slider for coarse motion.
- Rationale (do not skip): a slider with 400 points of travel over 5 m is ~12 mm per point, coarser than the 10 mm tolerance.
- Verify: typing `2740` sets the dimension to exactly 2740 mm; the slider and field stay in sync.

---

**T-306 — Add a missed wall, delete a false detection**
- Goal: G3
- Action: Implement "add wall" (two taps, then a millimetre length entry) and "delete element" acting on `EditedPlan`.
- Tgt: extend `Editor/FloorPlanViewModel.swift`
- Verify: adding a wall increments the wall count in the export; deleting an object removes its identifier.

---

### Phase 4 — Tagging and metadata

---

**T-401 — Kitchen tag vocabulary**
- Goal: G2, G4
- Action: Implement `KitchenTag` with the vocabulary from `IMPLEMENTATION_PLAN.md` section 10.1. Distinguish `fixed: true` (physically present) from `fixed: false` (design intent).
- Tgt: `Model/KitchenTag.swift`
- Verify: unit test asserting that a tag with `fixed: false` and category `base-cabinet-run` promotes its wall into the critical set via T-204.

---

**T-402 — Extend the object catalog**
- Goal: G3, G4
- Src: `RoomPlanDemo/RoomPlanDemo/CustomViews/AddFurnitureView/AddFurnitureView.swift`
- Action: Read fully. Port. Extend the catalog to the kitchen vocabulary. Do not port the entire web catalog — only what a field kitchen job needs.
- Tgt: `Model/Editor/AddFurnitureView.swift`
- Verify: each catalog entry creates a tagged object in `EditedPlan`.

---

**T-403 — Capture metadata**
- Goal: G2, G5
- Action: Implement `CaptureMetadata` with `siteId`, `workerName`, `capturedAt` (ISO 8601 UTC), `deviceModel`, `appVersion`, `captureMode`, plus a room label and an optional note.
- Tgt: `Model/CaptureMetadata.swift`
- Verify: encoding produces ISO 8601 UTC for `capturedAt` and a non-empty `siteId` in a validated format.

---

**T-404 — Site setup screen**
- Goal: G1, G5
- Action: Build `SiteSetupView` collecting worker name (persisted and prefilled) and site ID (validated non-empty, no whitespace, filename- and URL-safe). Include the calibration step on first use per device.
- Tgt: `Flow/SiteSetupView.swift`
- Verify: the second scan on the same device prefills the worker name. An invalid site ID is rejected with a named message.

---

### Phase 5 — Tape gate

---

**T-501 — Tape gate screen**
- Goal: G2, G4
- Action: Build `TapeGateView` per `IMPLEMENTATION_PLAN.md` section 11.1: one card per critical dimension showing the scanned value badged "SCANNED — APPROXIMATE", a millimetre entry field, a deviation readout with colour bands (green within tolerance, amber to 3×, red beyond), a mandatory note on red, and a "Could not measure" escape requiring a reason.
- Tgt: `Flow/TapeGateView.swift`
- Verify: entering a value sets provenance to `tape` and records `deviationMm`. Waiving marks the gate `fail`.
- **The escape must exist.** A gate with no escape produces fabricated numbers.

---

**T-502 — Validation block computation**
- Goal: G2, G7
- Action: Compute `criticalCount`, `criticalWithinTolerance`, `passRate`, `gateResult`, `photosCaptured`.
- Tgt: extend `Flow/ExportFlowView.swift` or `Dimension/DimensionEngine.swift`
- Verify: a plan with 5 of 6 critical dimensions in tolerance reports `passRate: 0.833` and `gateResult: "fail"`.

---

### Phase 6 — Export pipeline (the integration link)

---

**T-601 — Read the contract fixtures**
- Goal: G5
- Src: `openPlan3D/tests/fixtures/handoff-plan.json`, `openPlan3D/tests/fixtures/handoff-roomplan.json`
- Action: Locate both files in the forked repo. Read them **in full**. Emit their complete key structure as intermediate output. Copy both into `magpie-field/MagpieField/Resources/Fixtures/` and into the test bundle.
- Verify: both files are present in the test bundle and the target's build phase includes them.
- Blocker: S4 if either is missing or contradicts `docs/handoff-format-v1.md`. **Do not hand-write the schema.**

---

**T-602 — HandoffExporterV1**
- Goal: G5
- Action: Encode an `EditedPlan` into handoff v1. Obey every rule in section 2.2 above and in `docs/handoff-format-v1.md`: metres, column-major transforms, unique identifiers, `parentIdentifier` on the same `story`, resolved opening styles including defaults, `hingeLeft`, `opensInward`, `sillHeight`, `openplanHandoffVersion: 1`, `openplanPrepared: true`.
- Tgt: `Export/HandoffExporterV1.swift`
- Verify: **T-603.**

---

**T-603 — The fixture round-trip test (do not skip)**
- Goal: G5
- Action: Load `handoff-plan.json`, decode into `EditedPlan`, encode with `HandoffExporterV1`, assert the output equals `handoff-roomplan.json` for **every** key and value.
- Tgt: `MagpieFieldTests/HandoffExporterV1Tests.swift`
- Verify: test passes. If it does not, fix the exporter, never the fixture.
- **This is the single most important test in the project.** Per the contract doc the same fixtures live in the original iOS app's test bundle; reuse them verbatim rather than authoring a schema from prose.

---

**T-604 — Local contract validator**
- Goal: G5
- Action: Implement, in Swift, every check in section 2.2. Run it on the in-memory document **before** writing `plan.json`. On failure, block export and name the offending element.
- Tgt: `Export/HandoffValidator.swift`
- Verify: a unit test feeding a duplicate `identifier`, a `parentIdentifier` pointing at another `story`, a 15-element `transform`, and a `dimensions[0] <= 0` each produce a distinct, named failure.

---

**T-605 — Measurement table exporter**
- Goal: G2, G5, G7
- Action: Emit `measurements.json` per `IMPLEMENTATION_PLAN.md` section 7.3. Integer millimetres. Every dimension carries `provenance`, `valueMm`, `valueScannedMm`, `deviationMm`. Include `calibration`, `tolerances`, `rooms`, `kitchenTags`, `validation`, and `captureMode`.
- Tgt: `Export/MeasurementTableExporter.swift`
- Verify: the JSON parses, and every dimension has a non-null `provenance`.

---

**T-606 — Package builder**
- Goal: G5, G6
- Src: read `RoomStorageManager.swift` fully for any existing bundling approach **before** choosing one
- Action: Assemble the ZIP: `plan.json`, `room.json`, `measurements.json`, `model.usdz`, `photos/`, and `package-manifest.json` duplicating the identity fields at the ZIP root.
- Tgt: `Export/PackageBuilder.swift`
- Verify: the ZIP opens; `package-manifest.json` is at the root; the manifest carries `siteId` and `workerName` even if `measurements.json` were removed.

---

**T-607 — Keep the SVG/DXF export reachable**
- Goal: G5
- Src: `FloorPlanExporter.swift` (verified to contain an `ExportFormat` enum with `svg` and `dxf`)
- Action: Port the SVG and DXF writers. Wire them into the share sheet. Do not extend them.
- Tgt: `Export/FloorPlanExporter.swift`
- Verify: exporting SVG and DXF produces files that open.

---

### Phase 7 — Storage, encryption, sync

---

**T-701 — Port the storage manager**
- Goal: G6
- Src: `RoomStorageManager.swift`
- Action: Read fully. Port, dropping every WiFi artifact (`_wifi.json`). Keep the per-room directory layout.
- Tgt: `Store/RoomStorageManager.swift`
- Verify: a saved room reloads after an app restart.

---

**T-702 — File protection**
- Goal: G6
- Action: Set `NSFileProtectionComplete` on the saved-rooms directory and the ZIP staging directory. Use `.completeFileProtection` on individual writes. Use `NSFileProtectionCompleteUnlessOpen` for anything the sync queue must read while the device is locked — decide this deliberately, it is a correctness issue.
- Tgt: `Store/Encryption.swift`
- Verify: with the device locked, protected files cannot be read; the queue's own state files can.

---

**T-703 — Site capture record**
- Goal: G1, G6
- Src: `iOS-RoomPlan/RoomPlanTest/Models/Scan.swift` for shape only
- Action: Define the SwiftData record for the library screen.
- Tgt: `Store/SiteCapture.swift`
- Verify: the library lists captures with site ID, room label, timestamp, and sync state.

---

**T-704 — Sync queue**
- Goal: G6
- Action: Implement the state machine `pending -> uploading -> uploaded -> confirmed -> deleted`, with failed retry and backoff. Per-package `state.json` holding `packageId`, `siteId`, `attempts`, `lastError`, `remoteId`, `checksum`. **Delete local files only on a checksum-confirmed acknowledgement — never on HTTP 200 alone.**
- Tgt: `Sync/SyncQueue.swift`
- Verify: a simulated truncated upload (200 with a mismatched checksum) does **not** delete local files.

---

**T-705 — Sync client**
- Goal: G6
- Src: `openPlan3D/src/routes/api/handoffs/`, `src/lib/server/handoffUpload.ts` — read to learn the actual request shape
- Action: Implement the upload client against the real endpoint. Do not invent the request shape.
- Tgt: `Sync/SyncClient.swift`
- Verify: a package uploads and the server returns an identifier; a bad endpoint fails into the retry path, not a crash.

---

**T-706 — Connectivity handling**
- Goal: G6
- Action: `NWPathMonitor`. The scan flow ends at "Queued for upload", never at "Waiting for upload".
- Tgt: extend `Sync/SyncQueue.swift`
- Verify: airplane mode captures and queues without blocking; reconnect drains the queue.

---

### Phase 8 — Designer side

---

**T-801 — Fork the web app**
- Goal: G5
- Action: Fork `openPlan3D` to `magpie_lidr/magpie-studio/`. Record the forked commit hash. Consider removing `routes/render-lab/`, `lib/renderLab/`, `lib/skills/`, `routes/mcp/`, `tests/benchmarks/`, `tests/browser/` to shrink the fork — but only after confirming nothing imports them (grep first).
- Verify: `npm run check` and `npm test` pass on the unmodified fork.

---

**T-802 — Baseline import verification**
- Goal: G5
- Action: Run `npx vitest run tests/roomplan-import.test.ts` on the fork. Then take a real package produced by T-606 and import it. Record the result.
- Verify: the fixture test passes on the untouched fork; the real package either imports correctly or yields a specific validator error to act on.
- **Do not modify `roomplanImport.ts` or `roomplanValidation.ts` to make a package import.** Fix the exporter instead.

---

**T-803 — Dimension table panel**
- Goal: G2, G5
- Action: Read `measurements.json` from the package and render: every dimension with `provenance`, `valueMm`, `valueScannedMm`, `deviationMm`; the `validation` summary at the top; `kitchenTags` cross-linked to the geometry; the `calibration` block; and the capture metadata. **`tape` values strong and dark; `scanned` values muted with an approx marker; never render them identically.**
- Tgt: a new panel component plus wiring in the editor
- Verify: with a package containing both provenances, the two are visually distinguishable without reading the label.
- Rule: **do not import `measurements.json` geometry back into the model.** It is a report; `plan.json` is the geometry.

---

**T-804 — Extend the upload route**
- Goal: G5, G6
- Src: `src/routes/api/handoffs/`, `src/lib/server/handoffUpload.ts`, `handoffStorage.ts`, `handoffQuota.ts`, `docs/handoff-quotas.md`
- Action: Accept `measurements.json`, `model.usdz`, and `photos/` alongside the existing geometry payload. Check the quota against a realistic package — trigger S6 if it does not fit.
- Verify: a full package uploads; an oversized package is rejected with the quota message.

---

**T-805 — Per-site access control**
- Goal: G6
- Src: `src/lib/firebase.ts` for the existing auth setup
- Action: Authenticate, key each package by `siteId`, store an assignment of worker and permitted designers. **Enforce on the server in the handoff routes, not in the Svelte client.** A client-side check is not access control.
- Verify: a designer assigned to site A cannot fetch site B even with a hand-crafted request.

---

**T-806 — Millimetre display unit**
- Goal: G5
- Action: Add a display-unit setting converting at the format boundary only. Extend the existing `tests/length-formatting.test.ts` rather than replacing it.
- Verify: the existing length-formatting test still passes, plus a new assertion for millimetres.

---

### Phase 9 — Validation

---

**T-901 — Coverage analyzer**
- Goal: G4
- Action: Implement the checks in `IMPLEMENTATION_PLAN.md` section 8.2C: order walls into a chain by endpoint matching within 200 mm, check closure, compare summed wall length to the section perimeter, and sanity-check wall count and floor area. On failure, name the gap size and direction, offering *Rescan* and *Continue anyway (flagged)*.
- Tgt: `Capture/CoverageAnalyzer.swift`
- Verify: a deliberately incomplete scan is flagged; a complete scan is not.

---

**T-902 — Speed and light warnings**
- Goal: G1, G4
- Action: Track camera translation between `ARFrame`s for the metres-per-second check (threshold ~0.6 m/s sustained ~1 s), and read `ARCamera.trackingState` for `.limited(.insufficientFeatures)` (dark room) and `.limited(.excessiveMotion)` (too fast).
- Tgt: extend `Capture/CoverageAnalyzer.swift`
- Verify: walking fast produces the warning; a dark room produces the light warning.

---

**T-903 — Validation harness**
- Goal: G7
- Action: A spreadsheet plus the five-kitchen protocol from `IMPLEMENTATION_PLAN.md` section 16. Record per dimension: app value, tape value, signed error, absolute error. Record time per site for app and manual. Define pass/fail **before** the first scan.
- Verify: a completed report stating pass or fail against each criterion in section 16.1, naming the dimensions and room conditions that failed.

---

**T-904 — Cross-check phone and web areas**
- Goal: G2, G7
- Action: Compare the floor area from the phone's `DimensionEngine` against `planStatistics` on the same plan in the web app.
- Verify: identical values. If they differ, the phone has its own area convention — fix it to match the web's (`area-convention.test.ts`, `interior-area.test.ts`) rather than accepting two answers for one room.

---

## 6. Decisions required before coding

Each of these needs a recorded human answer. Do not default.

| ID | Decision | Blocks |
|---|---|---|
| D1 | **Resolved** — `RoomPlanSimple` (2026-10-10) | — | 2026-10-10 | — |
| D2 | Bundle identifier and signing team for `magpie-field` | T-001 |
| D3 | Which USDZ variant ships — `parametric`, `model`, or `mesh` | T-105, T-804 |
| D4 | Whether `measurements.json` is a sidecar file or an extension block inside `plan.json` | T-605, T-803 |
| D5 | File-protection level for sync-readable files: `CompleteUnlessOpen` vs. a background-safe alternative | T-702 |
| D6 | Sync backend host, storage, and Firebase project ownership | T-705, T-804, T-805 |
| D7 | Whether `handoffQuota.ts`'s limit accommodates a USDZ plus photos | T-804 |
| D8 | Real per-item tolerances from the designer, replacing the 10 mm / 5 mm defaults | T-202, T-502 |
| D9 | Whether the fork removes `render-lab`, `skills`, `mcp` routes | T-801 |
| D10 | Retention period after sync, and who authorises a deletion | T-704, T-805 |

---

## 7. Traceability

Every goal must be reachable through tasks with evidence.

| Goal | Tasks | Evidence |
|---|---|---|
| G1 — capture in minutes, no training | T-001, T-002, T-005, T-101, T-102, T-103, T-104, T-404, T-703, T-902 | Five crash-free scans; T-903 time per site |
| G2 — provenance on every dimension | T-201, T-202, T-203, T-204, T-205, T-305, T-401, T-403, T-501, T-502, T-605, T-803, T-806, T-904 | Every dimension has `provenance`; no uncertified scan value in the UI |
| G3 — on-site correction | T-105, T-301, T-302, T-303, T-304, T-305, T-306, T-402 | An edit, a relabel, a deletion, and an added wall all appear in `plan.json` |
| G4 — bad scans caught | T-204, T-401, T-501, T-901, T-902 | `CoverageAnalyzer` catches every open polygon; false-positive rate measured |
| G5 — designer gets trustworthy data | T-301, T-403, T-404, T-601, T-602, T-603, T-604, T-605, T-606, T-607, T-801, T-802, T-803, T-804, T-806 | Real package imports into an unmodified fork; tape vs scanned visually distinct |
| G6 — offline, encrypted, no loss | T-004, T-006, T-606, T-701, T-702, T-704, T-705, T-706, T-804, T-805 | Airplane-mode capture; checksum-mismatch does not delete; locked-device read behaves |
| G7 — proven or disproven | T-502, T-605, T-903, T-904 | Written report against the pre-agreed criteria; phone and web areas agree |

---

## 8. Reporting format

For every task, report exactly this. No prose padding.

```
TASK    T-<id>
STATUS  done | blocked | partial
READ    <files actually read, with line ranges>
WROTE   <files created or modified>
VERIFY  <the exact command run, and its exact result>
ASSUMED <anything not read or not run — should be empty>
BLOCKER <S<id> or D<id>, or none>
```

**`ASSUMED` must be empty for a task to be `done`.** If you filled it in, the status is `partial`.

Do not report a task `done` because a file exists. Every task has a verify step; run it and quote the result.
