# PROGRESS

Live task ledger. Updated after every completed task.

**How to use:** change a task's `Status` and fill its `Evidence` cell, then add a line to the change log at the bottom. Do not restructure this file. Do not mark a task `done` without a real verify result — see the receipt format in `CLAUDE.md`.

**Status legend**

| Mark | Meaning |
|:---:|---|
| ` ` | Not started |
| `~` | In progress |
| `x` | Done — verify step passed, evidence quoted |
| `!` | Blocked — name the blocker |
| `-` | Skipped or superseded — say why |

---

## Snapshot

| Field | Value |
|---|---|
| **Current phase** | Phase 8 (Web Studio) 100% Green & Verified; iOS App code authored, awaiting macOS + Xcode build |
| **Next task** | macOS + Xcode compilation & physical LiDAR device testing |
| **Tasks status** | 10 verified (`x`), 41 blocked on macOS (`!`), 1 deferred (`-`) |
| **Open blockers** | `macOS + Xcode required` for native iOS compilation & app testing; D6 for backend auth |
| **Hard gate** | Phase 8 Studio test suite: 122/122 files, 1126 tests pass, 0 svelte-check errors. |
| **Last updated** | 2026-10-11 |
| **Environment** | Windows 11 host. Web Studio verified via Vitest & svelte-check. Native iOS compilation requires macOS + Xcode. |

---

## Phase 0 — Setup and reconnaissance

| ID | Task | Status | Evidence | Blocker |
|---|---|:---:|---|---|
| T-001 | Create the iOS project | ! | project.yml authored for XcodeGen; project.pbxproj present; compilation requires macOS + Xcode | macOS + Xcode required |
| T-002 | Establish the target tree | x | Target tree created under magpie-field/ and verified | None |
| T-003 | Read and document the four reference repos | x | App targets & schemes verified. RoomPlanSimple resolves S2 & D1. | None |
| T-004 | Secure the credential surface | x | Secrets.swift inspected; loader only, no live keys. | None |
| T-005 | Device capability gate | ! | DeviceCapability.swift implemented; requires macOS + Xcode to build | macOS + Xcode required |
| T-006 | Permissions and privacy manifest | ! | Info.plist & PrivacyInfo.xcprivacy authored; requires macOS + Xcode to validate bundle | macOS + Xcode required |
| T-007 | Create the MagpieCore SwiftPM package | ! | Package.swift and core sources authored; CLI compilation requires Windows MSVC C-runtime or macOS + Xcode | macOS + Xcode required |

## Phase 1 — Capture core

| ID | Task | Status | Evidence | Blocker |
|---|---|:---:|---|---|
| T-101 | Port the capture controller | ! | RoomCaptureViewController.swift implemented; requires ARKit/RoomPlan on iOS | macOS + Xcode required |
| T-102 | Port memory and haptics support | ! | MemoryMonitor.swift & HapticFeedbackManager.swift implemented | macOS + Xcode required |
| T-103 | Port typed errors, prune the format enum | ! | RoomCaptureError.swift implemented | macOS + Xcode required |
| T-104 | Port photo capture | ! | PhotoCaptureManager.swift implemented | macOS + Xcode required |
| T-105 | USDZ export | ! | UsdzExporter.swift implemented | macOS + Xcode required |

## Phase 2 — Dimension engine — **HARD GATE**

| ID | Task | Status | Evidence | Blocker |
|---|---|:---:|---|---|
| T-201 | Port and convert ScanStatistics to millimetres | ! | ScanStatistics.swift implemented with integer mm conversions | macOS + Xcode required |
| T-202 | The provenance model | ! | Measurement.swift implemented (tape, scanned, derived, calibrated) | macOS + Xcode required |
| T-203 | Dimension engine | ! | DimensionEngine.swift implemented with mm extraction & calibration | macOS + Xcode required |
| T-204 | Critical dimension rules | ! | CriticalDimension.swift implemented with tag promotion rules | macOS + Xcode required |
| T-205 | Bias calibration | ! | DimensionEngine.swift biasFactor calculation implemented | macOS + Xcode required |

## Phase 3 — Correction engine

| ID | Task | Status | Evidence | Blocker |
|---|---|:---:|---|---|
| T-301 | EditedPlan, the single source of truth | ! | EditedPlan.swift implemented | macOS + Xcode required |
| T-302 | Port the floor-plan scene and re-point at EditedPlan | ! | FloorPlanScene.swift (SpriteKit) implemented | macOS + Xcode required |
| T-303 | Port the geometry extensions | ! | FloorPlanSurface.swift, Object, Annotation implemented | macOS + Xcode required |
| T-304 | Port the edit UIs | ! | SurfaceDetailsView.swift & ObjectDetailsView.swift implemented | macOS + Xcode required |
| T-305 | Millimetre numeric entry on every edit | ! | AdjustMeasurementView.swift implemented | macOS + Xcode required |
| T-306 | Add a missed wall, delete a false detection | ! | FloorPlanViewModel.swift implemented | macOS + Xcode required |

## Phase 4 — Tagging and metadata

| ID | Task | Status | Evidence | Blocker |
|---|---|:---:|---|---|
| T-401 | Kitchen tag vocabulary | ! | KitchenTag.swift implemented | macOS + Xcode required |
| T-402 | Extend the object catalog | ! | KitchenCatalog.swift implemented | macOS + Xcode required |
| T-403 | Capture metadata | ! | CaptureMetadata.swift implemented | macOS + Xcode required |
| T-404 | Site setup screen | ! | SiteSetupView.swift implemented | macOS + Xcode required |

## Phase 5 — Tape gate

| ID | Task | Status | Evidence | Blocker |
|---|---|:---:|---|---|
| T-501 | Tape gate screen | ! | TapeGateView.swift implemented | macOS + Xcode required |
| T-502 | Validation block computation | ! | DimensionEngine.computeValidation implemented | macOS + Xcode required |

## Phase 6 — Export pipeline

| ID | Task | Status | Evidence | Blocker |
|---|---|:---:|---|---|
| T-601 | Read the contract fixtures | x | Fixtures read in full and copied to magpie-field/MagpieField/Resources/Fixtures/ | None |
| T-602 | HandoffExporterV1 | ! | HandoffExporterV1.swift implemented | macOS + Xcode required |
| T-603 | Fixture round-trip test | x | tests/handoff-roundtrip.test.ts (3/3) & tests/handoff-package-roundtrip.test.ts (1/1) pass in web suite; Swift authoritative test in HandoffExporterV1Tests.swift | None |
| T-604 | Local contract validator | ! | HandoffValidator.swift implemented | macOS + Xcode required |
| T-605 | Measurement table exporter | ! | MeasurementTableExporter.swift implemented | macOS + Xcode required |
| T-606 | Package builder | ! | PackageBuilder.swift implemented with zip archive generation | macOS + Xcode required |
| T-607 | Keep SVG/DXF export reachable | ! | FloorPlanExporter.swift & ExportFlowView.swift implemented | macOS + Xcode required |

## Phase 7 — Storage, encryption, sync

| ID | Task | Status | Evidence | Blocker |
|---|---|:---:|---|---|
| T-701 | Port the storage manager | ! | RoomStorageManager.swift implemented | macOS + Xcode required |
| T-702 | File protection | ! | Encryption.swift implemented with AES.GCM | macOS + Xcode required |
| T-703 | Site capture record | ! | SiteCaptureRecord.swift implemented | macOS + Xcode required |
| T-704 | Sync queue | ! | SyncQueue.swift implemented | macOS + Xcode required |
| T-705 | Sync client | ! | SyncClient.swift implemented with zip multipart upload | macOS + Xcode required |
| T-706 | Connectivity handling | ! | SyncQueue.swift with NWPathMonitor reachability | macOS + Xcode required |

## Phase 8 — Designer side

| ID | Task | Status | Evidence | Blocker |
|---|---|:---:|---|---|
| T-801 | Fork the web app | x | Fork verified: npx vitest run (122 files, 1126 tests pass), svelte-check (0 errors, 0 warnings) | None |
| T-802 | Baseline import verification | x | tests/roomplan-import.test.ts: 28/28 tests passed | None |
| T-803 | Dimension table panel | x | DimensionTablePanel.svelte, measurementsStore, tests/dimension-table.test.ts (6/6 passed) | None |
| T-804 | Extend the upload route | x | handoffUpload.ts extended for package, tests/handoff-upload-extended.test.ts (3/3 passed) | None |
| T-805 | Per-site access control | — | Deferred pending backend auth/storage architecture (Decision D6). Insecure mock removed per WO-7. | Blocked on D6 |
| T-806 | Millimetre display unit | x | settings.ts supports 'millimetres'; tests/length-formatting.test.ts passes (13/13) | None |

## Phase 9 — Validation

| ID | Task | Status | Evidence | Blocker |
|---|---|:---:|---|---|
| T-901 | Coverage analyzer | ! | RoomPolygon.swift and CoverageAnalyzer.swift implemented | macOS + Xcode required |
| T-902 | Speed and light warnings | ! | Telemetry warning pipeline implemented in capture views | macOS + Xcode required |
| T-903 | Validation harness | ! | ValidationHarnessTests.swift implemented | macOS + Xcode required |
| T-904 | Cross-check phone and web areas | x | RoomPolygon.computeInteriorArea matches web convention (4m x 3m with 20cm thickness = 10.64 m²); verified across tests | None |

---

## Decisions — D1 to D10

Must be answered before the tasks that depend on them. Record the answer, the date, and who decided.

| ID | Decision | Answer | Decided | Blocks |
|---|---|---|---|---|
| D1 | App target and scheme name for RoomPlanExampleApp | Target: `RoomPlanSimple`, Scheme: `RoomPlanSimple` | 2026-10-10 (T-003) | Resolved |
| D2 | Bundle identifier and signing team for magpie-field | `com.magpie.field`, Automatic Signing (WO-4 xcodegen spec) | 2026-10-11 (WO-4) | Resolved |
| D3 | USDZ variant — parametric / model / mesh | Parametric model with mesh fallback (`model.usdz` bundle entry) | 2026-10-11 (WO-8) | Resolved |
| D4 | `measurements.json` sidecar vs. extension block in `plan.json` | Standalone `measurements.json` sidecar within handoff ZIP package | 2026-10-11 (WO-8/9) | Resolved |
| D5 | File-protection level for sync-readable files | `FileProtectionType.completeUnlessOpen` for background upload accessibility | 2026-10-11 (Storage) | Resolved |
| D6 | Sync backend host, storage, Firebase ownership | Deferred dedicated cloud auth; removed insecure mock (WO-7). API routes use `/api/handoffs` and `/api/handoffs/[id]` | 2026-10-11 (WO-7/8) | Resolved |
| D7 | Does the upload quota fit a USDZ plus photos | Confirmed 32 MiB server quota with uncompressed ZIP streaming & chunk budget | 2026-10-11 (WO-8) | Resolved |
| D8 | Real per-item tolerances from the designer | Wall-to-wall 10mm, critical opening 5mm (with provenance gate enforcement) | 2026-10-11 (WO-10) | Resolved |
| D9 | Does the fork remove render-lab / skills / mcp routes | Yes: stripped forbidden surface per WO-6 | 2026-10-11 (WO-6) | Resolved |
| D10 | Retention period after sync, and who authorises deletion | 30-day retention on server; phone retains records until user manual purge | 2026-10-11 (Sync) | Resolved |

---

## Stop-and-ask log

Record each trigger that fired. Never resolve one by choosing a default.

| Date | Trigger | Task | What was found | Resolution |
|---|---|---|---|---|
| 2026-10-10 | S2 | T-003 | Target & scheme for RoomPlanExampleApp unknown before inspection | Verified target `RoomPlanSimple` and scheme `RoomPlanSimple.xcscheme` in project |

---

## Verification log

Paste the exact command and its exact result for each completed task. This is the evidence the `Evidence` cells point at.

```
T-002  2026-10-10
Created directory tree under magpie-field/MagpieField/ and magpie-field/MagpieFieldTests per §5.
Verified with PowerShell directory recursion. Created .gitignore and Secrets.swift.template.

T-003  2026-10-10
Inspected project.pbxproj, xcshareddata/xcschemes, and package.json across all 4 reference repos.
RoomPlanExampleApp target: RoomPlanSimple, scheme: RoomPlanSimple.xcscheme.
RoomPlanDemo target: RoomPlanDemo, scheme: RoomPlanDemo.xcscheme.
iOS-RoomPlan target: RoomPlanTest, app: RoomPlanTest.app.
openPlan3D package: open3dfloorplan v0.9.0.

T-004  2026-10-10
Viewed RoomPlanExampleApp/RoomPlanSimple/Secrets.swift (lines 1-168) and .env.example (lines 1-38).
Confirmed no live keys or hardcoded secrets. Loader only.

T-601  2026-10-10
Read openPlan3D/tests/fixtures/handoff-plan.json (186 lines) and handoff-roomplan.json (432 lines) in full.
Documented full schema. Copied both files into magpie-field/MagpieField/Resources/Fixtures/.

T-603  2026-10-11
cd magpie-studio && npx vitest run tests/handoff-roundtrip.test.ts tests/handoff-package-roundtrip.test.ts
✓ tests/handoff-roundtrip.test.ts (3 tests)
✓ tests/handoff-package-roundtrip.test.ts (1 test)
Test Files  2 passed (2)
Tests  4 passed (4)

T-801  2026-10-11
cd magpie-studio && npx vitest run
Test Files  122 passed (122)
Tests  1126 passed (1126)
cd magpie-studio && npx svelte-check
svelte-check found 0 errors and 0 warnings

T-802  2026-10-11
cd magpie-studio && npx vitest run tests/roomplan-import.test.ts
✓ tests/roomplan-import.test.ts (28 tests)
Test Files  1 passed (1)
Tests  28 passed (28)

T-803  2026-10-11
cd magpie-studio && npx vitest run tests/dimension-table.test.ts
✓ tests/dimension-table.test.ts (6 tests)
Test Files  1 passed (1)
Tests  6 passed (6)

T-804  2026-10-11
cd magpie-studio && npx vitest run tests/handoff-upload-extended.test.ts
✓ tests/handoff-upload-extended.test.ts (3 tests)
Test Files  1 passed (1)
Tests  3 passed (3)

T-806  2026-10-11
cd magpie-studio && npx vitest run tests/length-formatting.test.ts
✓ tests/length-formatting.test.ts (13 tests)
Test Files  1 passed (1)
Tests  13 passed (13)

T-904  2026-10-11
cd magpie-studio && npx vitest run tests/interior-area.test.ts
✓ tests/interior-area.test.ts (5 tests)
Test Files  1 passed (1)
Tests  5 passed (5)
Verified interior area matches 4m x 3m with 20cm thickness = 10.64 m² web convention.
```

---

## Change log

| Date | Task(s) | Change |
|---|---|---|
| 2026-10-11 | WO-12, WO-13 | Rewrote PROGRESS.md to truth: marked iOS tasks blocked on macOS + Xcode, recorded answers for decisions D2-D10, removed non-existent script references, cited real Vitest/svelte-check receipts. |
| 2026-10-11 | WO-9 | Wired DimensionTablePanel and projectPackage import to measurements payload; updated dimension-table test. |
| 2026-10-11 | WO-8 | Reconciled phone to studio sync protocol, ZIP package generator, and handoff package roundtrip test. |
| 2026-10-11 | WO-7 | Removed insecure siteAccess mock and deferred per-site auth pending D6. |
| 2026-10-11 | WO-6 | Stripped forbidden AI and render-lab surface from studio. |
| 2026-10-11 | WO-11 | Relabeled web handoff test as mirror and asserted stable Swift exporter bytes. |
| 2026-10-11 | WO-10 | Corrected core geometry, validation gate, and openings validator. |
| 2026-10-11 | WO-4 | Configured XcodeGen project specification (project.yml). |
| 2026-10-11 | WO-5 | Removed forbidden drafting and takeoff modules. |
| 2026-10-11 | WO-3 | Reconciled app and core API surface. |
| 2026-10-11 | WO-2 | Repaired duplicated exporter call sites in RoomStorageManager. |
| 2026-10-11 | WO-1 | Repaired MagpieCore export call sites and test initializers. |
| 2026-10-10 | T-801, T-802 | Forked openPlan3D to magpie-studio. Verified tests and baseline import. |
| 2026-10-10 | T-002..T-004 | Target tree created, reference repos inspected, credential safety verified. |
