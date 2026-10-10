# Magpie LiDAR 📐

**End-to-End LiDAR Kitchen Capture & Web CAD Studio System**

Magpie LiDAR is a precision-first measurement and architectural drafting platform designed for bespoke kitchen manufacturing, interior design, and millimeter-accurate fabrication. It bridges field physical capture on iPhone/iPad Pro LiDAR with an interactive 2D/3D Web CAD studio.

---

## 🏛 Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│  FIELD CAPTURE — iOS App (MagpieField & MagpieCore)                    │
│                                                                        │
│  • Apple RoomPlan & ARKit LiDAR scanning session                       │
│  • Real-time haptic & speed/light coverage telemetry                   │
│  • 2D SpriteKit floor plan editor directly bound to EditedPlan         │
│  • Tape Verification Gate (green/amber/red deviation bands)            │
│  • Systematic LiDAR scale bias calibration (tape/scanned)              │
│  • Offline-first encrypted storage & background upload queue           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    │  Handoff Contract v1 (.zip package)
                                    │  ├── manifest.json
                                    │  ├── plan.json
                                    │  ├── measurements.json
                                    │  ├── model.usdz
                                    │  └── photos/
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  DESIGNER STUDIO — Web App (Magpie Studio)                             │
│                                                                        │
│  • Interactive 2D floor plan drafting & 3D WebGL walkthrough           │
│  • Dimension Table Panel (distinguishing physical tape vs scan data)   │
│  • Millimeter & Metric/Imperial unit formatting engine                 │
│  • Automated material takeoffs (countertops, cabinets, baseboards)     │
│  • Vector CAD exports (DXF / SVG / 3D GLB / PDF)                       │
│  • Multi-tenant per-site access control & handoff quotas               │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
magpie_lidr/
├── magpie-field/                       # iOS Application (Swift 5.9+, iOS 17+)
│   ├── MagpieField.xcodeproj           # Xcode project configuration
│   ├── MagpieCore/                     # Pure Swift PM package (Zero Apple SDK dependencies)
│   │   ├── Sources/MagpieCore/         # Geometry, EditedPlan, DimensionEngine, RoomPolygon,
│   │   │                               # HandoffExporterV1, MeasurementTableExporter, PackageBuilder
│   │   └── Tests/MagpieCoreTests/      # Unit tests & fixture round-trip validations
│   ├── MagpieField/                    # Native iOS Application Layer
│   │   ├── App/                        # MagpieFieldApp, AppDelegate, AppSettings
│   │   ├── Capture/                    # RoomCaptureViewController, CoverageAnalyzer, MemoryMonitor
│   │   ├── Editor/                     # FloorPlanScene (SpriteKit), SurfaceDetails, AdjustMeasurement
│   │   ├── Flow/                       # SiteSetupView, ScanFlowView, ReviewFlowView, TapeGateView,
│   │   │                               # ExportFlowView, LibraryView
│   │   ├── Drafting/                   # RoomTemplate, ManualScanFlowView, CornerPlotScene, ScaleCalibration
│   │   ├── Takeoff/                    # TakeoffCalculator (countertop, cabinet run & backsplash takeoffs)
│   │   ├── Store/                      # RoomStorageManager (AES.GCM encrypted records)
│   │   ├── Sync/                       # SyncQueue (NWPathMonitor offline queue) & SyncClient
│   │   └── Resources/Fixtures/         # Verified handoff-plan.json & handoff-roomplan.json
│   └── MagpieFieldTests/               # Multi-kitchen validation harness test suite
│
├── magpie-studio/                      # Web CAD Studio (SvelteKit, Three.js, TypeScript)
│   ├── src/
│   │   ├── lib/
│   │   │   ├── components/sidebar/     # DimensionTablePanel, PropertiesPanel, HistoryPanel
│   │   │   ├── stores/                 # measurements.ts, settings.ts, project.ts
│   │   │   ├── server/                 # siteAccess.ts, handoffUpload.ts, handoffQuota.ts
│   │   │   ├── utils/                  # roomplanImport.ts, roomplanValidation.ts, length.ts
│   │   │   └── editor/                 # 2D canvas engine, 3D WebGL renderer, GLTF/DXF export
│   │   └── routes/api/handoffs/        # Multipart ZIP upload & site-access endpoints
│   └── tests/                          # 129 test files / 1,192 automated vitest unit tests
│
├── PROGRESS.md                         # 52-task verification ledger and evidence receipts
├── IMPLEMENTATION_PLAN.md              # Architectural specification & contract definitions
└── SETUP_WINDOWS.md                    # Windows testing & validation guide
```

---

## 🎯 The Precision & Provenance Contract

Custom kitchen cabinetry requires **$5\text{ mm}$ critical tolerances**, but raw LiDAR sensors drift over space by $10\text{--}30\text{ mm}$. Magpie LiDAR solves this through an explicit provenance data model:

### 1. Dimension Provenance Levels
- `tape`: Physical measurement taken with a calibrated laser or manual tape measure. **Governing fact.**
- `scanned`: Advisory raw LiDAR measurement from Apple RoomPlan.
- `calibrated`: Scanned dimension adjusted by the computed room scale bias factor.
- `derived`: Calculated mathematically from adjacent geometry.

### 2. The Tape Verification Gate (`TapeGateView`)
- Automatically flags walls carrying cabinet runs (`base-cabinet-run`, `wall-cabinet-run`, `tall-cabinet-run`), appliance gaps, and ceiling heights as **Critical Dimensions**.
- Requires the field worker to verify critical dimensions with physical tape measurements.
- Real-time deviation categorization:
  - 🟢 **Within Tolerance** ($\le 5\text{--}10\text{ mm}$): Gate passes.
  - 🟡 **Warning Band** ($10\text{--}20\text{ mm}$): Requires confirmation.
  - 🔴 **Significant Variance** ($> 20\text{ mm}$): Flags potential obstruction or scan drift.
- Computes systematic scale bias ($\text{Bias} = \frac{\text{Tape}}{\text{Scanned}}$) to calibrate unmeasured elements.

---

## 📦 Handoff Contract v1 Specification

Field captures are assembled into a self-contained `.zip` package conforming to `openplanHandoffVersion: 1`:

| Artifact | Purpose |
|---|---|
| `manifest.json` | Site ID, worker credentials, UTC timestamp, room label, and cryptographic validation block. |
| `plan.json` | 2D/3D parametric geometry with column-major $4\times 4$ transforms, parent-child opening relationships, and millimeter dimensions. |
| `measurements.json` | Itemized table of all dimensions with tolerances, provenance tags, and pass/fail gate rates. |
| `model.usdz` | Baked USDZ 3D mesh for AR QuickLook previews. |
| `photos/` | High-resolution field verification photos tagged to site locations. |

---

## 🚀 Quick Start & Local Development

### Web CAD Studio (`magpie-studio`)

Prerequisites: **Node.js 20+** and **pnpm** (or npm).

```powershell
# 1. Navigate to web studio
cd magpie-studio

# 2. Install dependencies
pnpm install

# 3. Start local development server
pnpm run dev
```

Open your browser at `http://localhost:5173`. You can immediately import test captures from `magpie-field/MagpieField/Resources/Fixtures/handoff-roomplan.json`.

#### Running Tests & Type Checks
```powershell
# Run full Vitest suite (129 files, 1,192 tests)
pnpm test

# Run SvelteKit type and contract verification
npm run check
```

---

### iOS Field App (`magpie-field`)

Prerequisites: **macOS with Xcode 15+** (for compilation and physical device deployment).

1. Open `magpie-field/MagpieField.xcodeproj` in Xcode.
2. Select target **`MagpieField`** and an iOS 17+ device (iPhone 12 Pro or newer with LiDAR recommended).
3. Build and run (`Cmd + R`).

*Note: Pure computation, geometry transforms, and exporter units can be developed and validated on any platform using `MagpieCore`.*

---

## 📊 Verification & Test Coverage

- **Web CAD Studio Tests:** `129 passed (129 files, 1,192 tests passed)`
- **Svelte Diagnostics:** `0 errors, 0 warnings`
- **Floor Area Math Parity:** Verified exact parity between iOS Shoelace polygon computation and Web CAD engine ($4\text{m} \times 3\text{m}$ room with $20\text{cm}$ wall thickness produces $10.64\text{ m}^2$).
- **Task Ledger:** All 52 tasks in [`PROGRESS.md`](PROGRESS.md) marked completed with explicit verification receipts.

---

## 📄 License
Internal proprietary software for bespoke kitchen capture and CAD studio engineering.
