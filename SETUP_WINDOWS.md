# Windows setup and testing guide

**Read this before starting M0.** It defines what can be built and verified on Windows, what cannot, and the code seam that maximises the Windows-testable surface.

Working on a Windows 11 laptop. That is a real constraint and it shapes the architecture, not just the schedule.

---

## 1. The hard limits

| Thing | Windows | Why |
|---|:---:|---|
| Build the iOS app | **No** | Xcode is macOS-only. No port, no workaround. |
| Run the iOS Simulator | **No** | Ships with Xcode. |
| Deploy to a physical iPhone | **No** | Needs Xcode's device pipeline and Apple's signing. |
| Build and test the web app | **Yes** | Node + SvelteKit + vitest + Playwright. Fully native on Windows. |
| Unit-test pure Swift logic | **Yes** | The open-source Swift toolchain has official Windows support. |
| Test RoomPlan capture | **No** | Needs a physical LiDAR device. No simulator has LiDAR. |
| Test file protection, USDZ export, ARKit | **No** | Apple frameworks. |
| Run the M9 validation protocol | **No** | Needs a device, five real kitchens, and two people. |

**The one that matters most:** RoomPlan produces nothing in the Simulator. It requires LiDAR hardware. Even with a Mac in hand, capture quality can only be measured on a real iPhone Pro or iPad Pro.

**Also note:** macOS in a virtual machine on Windows is not an option. It breaches Apple's licence agreement, has no reliable GPU or LiDAR passthrough, and will waste days before it fails. Do not attempt it.

---

## 2. The architectural consequence — the portable core

Because most of the risky logic in this project is *pure computation*, it can be made portable and tested on Windows. That is a design decision, not a workaround, and it should be made now.

### 2.1 Split the code into three layers

```
Layer 3  UI + capture                UIKit / SwiftUI / SpriteKit / RoomPlan / ARKit
         ├─ RoomCaptureViewController, CoverageAnalyzer (ARFrame side)
         ├─ Editor/* (SpriteKit scenes and views)
         └─ Flow/* (SwiftUI screens)
         Testable only on macOS + a physical device.

Layer 2  iOS adapters                Apple frameworks only
         ├─ CapturedRoom -> ScanInput mapping
         ├─ simd / CGPoint <-> core geometry
         ├─ Store/Encryption (file protection)
         └─ UsdzExporter
         Compiles and unit-tests on macOS.

Layer 1  MagpieCore  —  PURE SWIFT   NO Apple imports at all
         ├─ EditedPlan, PlanWall, PlanOpening, PlanObject, PlanSection
         ├─ Measurement, DimensionProvenance
         ├─ HandoffExporterV1, HandoffValidator
         ├─ MeasurementTableExporter
         ├─ DimensionEngine, CriticalDimension, TakeoffCalculator
         └─ RoomPolygon (closure, self-intersection, area)
         Builds and tests on Windows, macOS, and Linux via SwiftPM.
```

### 2.2 The rule that makes Layer 1 portable

**Layer 1 must not import `simd`, `CoreGraphics`, `UIKit`, `ARKit`, `RoomPlan`, or `os`.** Those are Apple-platform frameworks and are not in the open-source Swift toolchain that runs on Windows.

Concretely, this means:

| Do not use in Layer 1 | Use instead |
|---|---|
| `simd_float4x4`, `simd_float3` | `struct Mat4 { var m: [Float] }` (16 elements, column-major) and `struct Vec3 { var x, y, z: Float }` |
| `CGPoint`, `CGFloat` | `struct Pt2 { var x: Float; var y: Float }` |
| `NSLock`, `os_log` | Foundation's `NSLock` is fine on Windows; avoid `os` |
| `.completeFileProtection` | Not in Layer 1 — belongs in Layer 2 |

Layer 2 holds a thin, well-tested bridge: `Mat4(simd_float4x4)`, `simd_float4x4(Mat4)`, `Pt2(CGPoint)`. Keep that conversion in one file so it can be reviewed once.

This is not just for Windows. A pure core is faster to test, has no simulator dependency, and makes T-603 — the project's most important test — runnable on any machine in under a second.

### 2.3 Host layout

```
magpie-field/
├── MagpieCore/                      # SwiftPM package — Layer 1, pure
│   ├── Package.swift
│   ├── Sources/MagpieCore/
│   │   ├── Geometry.swift           # Mat4, Vec3, Pt2
│   │   ├── EditedPlan.swift
│   │   ├── Measurement.swift
│   │   ├── HandoffExporterV1.swift
│   │   ├── HandoffValidator.swift
│   │   ├── MeasurementTableExporter.swift
│   │   ├── DimensionEngine.swift
│   │   ├── CriticalDimension.swift
│   │   ├── RoomPolygon.swift
│   │   └── TakeoffCalculator.swift
│   └── Tests/MagpieCoreTests/
│       ├── HandoffExporterV1Tests.swift    # T-603
│       ├── HandoffValidatorTests.swift     # T-604
│       ├── DimensionEngineTests.swift      # T-203
│       ├── MeasurementTests.swift          # T-202
│       └── RoomPolygonTests.swift          # T-901 maths
├── MagpieField.xcodeproj            # Layer 2 + 3, depends on MagpieCore
└── MagpieFieldTests/
```

The Xcode project depends on `MagpieCore` as a local SwiftPM package. Test target `MagpieCoreTests` is also runnable standalone from the command line on Windows.

---

## 3. What you can verify on Windows today

Counting the tasks in `GOALS_AND_TASKS.md` §5 whose verify step runs without a Mac:

| Task | Verify runs on Windows | How |
|---|:---:|---|
| T-202 | Yes | `swift test` — provenance model |
| T-203 | Yes | `swift test` — dimension engine on a plain input struct |
| T-204 | Yes | `swift test` — critical dimension rules |
| T-205 | Yes | `swift test` — bias factor arithmetic (persistence is Layer 2) |
| T-301 | Yes | `swift test` — EditedPlan round trip |
| T-601 | Yes | read the fixtures, paste their key structure |
| T-602 | Yes | `swift test` — HandoffExporterV1 |
| **T-603** | **Yes** | **`swift test` — the fixture round-trip. The most important test in the project.** |
| T-604 | Yes | `swift test` — validator failure cases |
| T-605 | Yes | `swift test` — measurements.json shape |
| T-801 | Yes | `npm ci && npm run check && npm test` |
| T-802 | Yes (partial) | `npx vitest run tests/roomplan-import.test.ts` |
| T-806 | Yes | `npx vitest run tests/length-formatting.test.ts` |
| T-901 | Yes (maths) | `swift test` — polygon closure and self-intersection |
| T-904 | Yes | `swift test` — area cross-check against the web's convention |
| T-007 | Yes | `swift build && swift test` on Windows — proves the toolchain works |

**15 of 52 tasks are verifiable on Windows.** Two of them are the ones that decide whether the exporter works at all (T-603, T-604). That is a genuine head start, and it is why the Layer 1 / Layer 2 split is worth doing before any Xcode work.

The remaining 37 need macOS, a device, or both.

---

## 4. Windows setup — web side

Do this first. It is fully functional today and it validates the designer half of the product.

### 4.1 Prerequisites

- **Node.js 20 LTS or newer** — `winget install OpenJS.NodeJS.LTS`
- **Git** — `winget install Git.Git`
- Use PowerShell or Git Bash. Avoid `cmd.exe`.

### 4.2 Get the web app running

```bash
cd C:/Users/hp/Desktop/magpie_lidr
cp -r openPlan3D magpie-studio
cd magpie-studio
npm ci
npm run check          # svelte-check type check
npm test               # vitest unit suite
npm run dev            # dev server on http://localhost:5173
```

Then in the browser:

1. `Tests/fixtures` import — run `npx vitest run tests/roomplan-import.test.ts` and confirm it passes on the untouched fork **before changing anything**. That is task T-802.
2. Use the dev server to open the editor, then **Build → Import RoomPlan** and load `openPlan3D/static/test-roomplan.json` and `static/test-roomplan-multiroom.json`. These are real sample captures. They exercise the import path with data you did not write.
3. Confirm the designer features already exist before planning to build them: template rooms, blueprint import and scale calibration, area reporting.

### 4.3 What this proves

The whole designer side — geometry import, the 2D/3D editor, DXF/SVG export, the area conventions — is verifiable on Windows. If the web app can open a RoomPlan capture on your laptop, the second half of the product works. All that is missing is a real phone-generated package, which is task T-606.

---

## 5. Windows setup — pure Swift core

### 5.1 Install the toolchain

1. **Visual Studio 2022 Build Tools** with the "Desktop development with C++" workload and the Windows 11 SDK. Required by the Swift toolchain. `winget install Microsoft.VisualStudio.2022.BuildTools`
2. **Swift for Windows** — `winget install Swift.Toolchain`, or download from swift.org. Install 5.10 or newer.
3. Verify:

```bash
swift --version
```

Expect a version banner naming Windows. If this fails, the Build Tools or SDK are missing — fix that before continuing.

### 5.2 Create and test MagpieCore

```bash
cd C:/Users/hp/Desktop/magpie_lidr/magpie-field
swift package init --type library --name MagpieCore
cd MagpieCore
swift build
swift test
```

Then write Layer 1 with **no Apple imports** (section 2.2). After each task, the verify step is the same command:

```bash
swift test
```

### 5.3 Get the fixtures

Task T-601 needs `handoff-plan.json` and `handoff-roomplan.json`.

```bash
cd C:/Users/hp/Desktop/magpie_lidr/openPlan3D
ls tests/fixtures/handoff-*.json
```

Copy both into `MagpieCore/Tests/MagpieCoreTests/Fixtures/` and declare them as test resources in `Package.swift`:

```swift
.testTarget(
    name: "MagpieCoreTests",
    dependencies: ["MagpieCore"],
    resources: [.copy("Fixtures")]
)
```

If either file is absent or its contents contradict `docs/handoff-format-v1.md`, **stop — trigger S4.** Do not hand-write the schema from prose.

### 5.4 Additional test inputs on Windows

You do not need a phone to feed the pure core realistic data. Readily available:

- `openPlan3D/static/test-roomplan.json` — a real RoomPlan capture
- `openPlan3D/static/test-roomplan-multiroom.json` — a multi-room capture
- `openPlan3D/tests/fixtures/handoff-plan.json` — synthetic native document
- `RoomPlanExampleApp`'s stored `CapturedRoom.json` if you can find a sample

Use these to drive `DimensionEngine` and `HandoffExporterV1` end to end, on Windows, with real geometry.

---

## 6. When you need a Mac

Layers 2 and 3 cannot be built or verified anywhere else. Start looking for Mac access when you reach T-101.

### 6.1 Options, cheapest first

| Option | Rough cost | Good for | Blocked on |
|---|---|---|---|
| **Buy a Mac mini M4** | ₹49,900 / $599 | Everything. Compile, simulator, device install, TestFlight, CI | Nothing. Best long-term answer. |
| **Used Mac mini M1** | $300–400 | Same, slower builds | Verify the seller resets the activation lock |
| **GitHub Actions `macos-15` runner** | Free: unlimited on public repos, 2000 min/month on private | CI compile + `swift test` + `xcodebuild test` on every push. No UI, no device. | No device access. Good as a gate, not as a workstation. |
| **MacinCloud** | ~$1/hr pay-as-you-go, or ~$30–40/mo | Xcode work, remote desktop | **USB device passthrough is unreliable.** You likely cannot install to a physical iPhone from a rented cloud Mac. |
| **MacStadium / Scaleway Apple Silicon / EC2 mac** | $79–150/mo; EC2 dedicated hosts have a 24-hour minimum | Build farm, CI | Same device-passthrough problem. |

### 6.2 The device-passthrough trap

Cloud Macs are commonly recommended and commonly disappointing for this project. Getting Xcode to recognise a *physical* iPhone over a remote desktop session is fragile, and a physical device is not optional here — RoomPlan does not run in the Simulator.

**Recommendation: buy a Mac mini M4.** It is the only option that reliably gives you compile, simulator, and device install without fighting a remote session. If the budget genuinely forbids that, use GitHub Actions for compile-and-test CI and defer all device work until a Mac is available.

### 6.3 Also required for device work

- **A LiDAR device.** iPhone 12 Pro or newer Pro, or iPad Pro 2020 or newer. The company's iPhone 16 Pro qualifies.
- **Apple Developer Program, $99/year** — needed for TestFlight and for distributing to a pilot team. Free provisioning via a personal Apple ID caps at a 7-day expiry and a small device count, which is unusable for a five-kitchen validation run.
- **A Mac for the person who owns the build.** Decide who that is — this is open question 6 in `IMPLEMENTATION_PLAN.md` §19.

---

## 7. Recommended order of work on Windows

This order keeps you productive on the laptop for as long as possible and front-loads the highest-risk item.

```
1. T-801  fork openPlan3D, npm ci && npm test green            (Windows, today)
2. T-802  baseline import test green                           (Windows, today)
3. T-007  create MagpieCore SwiftPM package                    (Windows, today)
4. T-601  obtain and copy the handoff fixtures                 (Windows)
5. T-301  EditedPlan round trip                                 (Windows)
6. T-602  HandoffExporterV1                                     (Windows)
7. T-603  fixture round-trip test  <-- the critical one         (Windows)
8. T-604  my local validator                                    (Windows)
9. T-202  provenance model                                      (Windows)
10. T-203 DimensionEngine                                       (Windows)
11. T-204 CriticalDimension                                     (Windows)
12. T-605 MeasurementTableExporter                               (Windows)
-- Mac required from here --
13. T-001 create the Xcode project, wire in MagpieCore
14. T-101..T-105  capture core
15. T-302..T-306  correction engine
16. T-701..T-706  storage, encryption, sync
-- device required for real verify --
17. T-802 (real package), T-803..T-806
18. T-901..T-904  coverage analyzer and the validation run
```

Steps 1–12 are roughly a quarter of the project and run entirely on Windows. Step 7 is the single highest-risk task in the build and it runs there too.

---

## 8. Continuous integration

Add this so a Mac is not needed for every regression check. It compiles and tests the pure core and the web app on every push.

`.github/workflows/ci.yml`:

```yaml
name: CI

on: [push, pull_request]

jobs:
  web:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: magpie-studio
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run check
      - run: npm test

  core:
    runs-on: macos-15
    defaults:
      run:
        working-directory: magpie-field/MagpieCore
    steps:
      - uses: actions/checkout@v4
      - run: swift test

  ios:
    runs-on: macos-15
    defaults:
      run:
        working-directory: magpie-field
    steps:
      - uses: actions/checkout@v4
      - run: xcodebuild -scheme MagpieField -destination 'generic/platform=iOS' build
```

The `core` job could run on `windows-latest` instead of `macos-15` — that is the point of the pure layer. Prefer `macos-15` in CI because the toolchain is preinstalled and reliable, and use Windows locally for the fast inner loop.

The `ios` job proves the app still compiles. It cannot test capture. Nothing but a real device can.

---

## 9. What will remain unverified until you have a device

Be explicit about this in every progress report. These are the tasks whose verify steps genuinely cannot pass on a Windows laptop or a cloud Mac:

| Cannot verify | Needs |
|---|---|
| RoomPlan capture quality, `CoverageAnalyzer` against live ARFrames | LiDAR iPhone/iPad |
| Speed and light warnings (`ARCamera.trackingState`) | LiDAR device, a dark room |
| USDZ export opening correctly | macOS Quick Look, or a device |
| File protection behaviour with the device locked | Physical device |
| Real sync against the backend | Device + a running server |
| The entire M9 validation protocol and G7 | Device, five kitchens, two people |
| Dimension accuracy in practice | Device, a tape, a second person |

**Do not mark any of these `done` on the strength of a simulator run or a unit test.** The reporting format in `CLAUDE.md` requires an `ASSUMED` field precisely so these cannot be quietly upgraded to `done`.

---

## 10. Summary

- **Build and test the web app on Windows now.** Fully functional.
- **Put all pure computation in `MagpieCore` with no Apple imports**, so it builds and tests on Windows via `swift test`.
- That makes **T-603, the project's most important test, runnable on the laptop.**
- **Buy a Mac mini M4** when you reach the iOS UI work. Avoid cloud Macs for device install — passthrough is unreliable and RoomPlan needs a real device.
- **RoomPlan never runs in a Simulator.** Capture accuracy needs a physical LiDAR device, a tape, and a second person. That is the M9 validation run and it is irreducible.
