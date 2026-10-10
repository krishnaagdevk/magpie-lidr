# CLAUDE.md

Project instructions for this repository. Loaded automatically. These rules override default behaviour.

---

## What this project is

A LiDAR room-capture iOS app plus a designer web app for kitchen measurement. Assembled from four reference repositories that live in this same directory.

**Three documents govern all work. Read them before touching code:**

| File | Purpose |
|---|---|
| `GOALS_AND_TASKS.md` | **The execution contract.** Operating rules, verified-vs-unknown file inventory, forbidden actions, stop-and-ask triggers, the task list, required decisions, reporting format. |
| `IMPLEMENTATION_PLAN.md` | **The design.** Architecture, precision model, data contracts, milestone definitions, validation protocol. |
| `SETUP_WINDOWS.md` | **The build environment.** What runs on Windows, what needs a Mac, and the portable-core architecture that makes the critical tests Windows-runnable. Read before T-001. |

If these conflict, `GOALS_AND_TASKS.md` wins for *what to do*. `IMPLEMENTATION_PLAN.md` wins for *how it should be designed*. `SETUP_WINDOWS.md` wins for *where it can be built and verified*.

---

## Reference repositories — read-only

These four directories are reference checkouts. **Never modify them.**

```
iOS-RoomPlan/         SwiftUI + SwiftData starter. Shape reference for the library screen.
RoomPlanDemo/         UIKit + SpriteKit. THE correction engine. Port the FloorPlan/ and CustomViews/ code.
RoomPlanExampleApp/   UIKit. THE foundation. App source is RoomPlanSimple/. Port capture, storage, export.
openPlan3D/           SvelteKit + Three.js. THE designer side. Fork it to magpie-studio/, don't edit in place.
```

New code goes in `magpie-field/` (iOS) and `magpie-studio/` (web fork).

---

## Hard rules

**1. Read before you port.**
Before porting any file, read it in full and emit its public symbol list (types, functions, properties) as intermediate output. Then port. Never port from a filename, from a summary, or from the plan documents. The plan tells you *which* files matter; it does not tell you *what is in them*.

**2. Cite, or stop.**
Use a RoomPlan or ARKit symbol only if you read it in a source file or it appears in `IMPLEMENTATION_PLAN.md` Appendix B. Otherwise stop — trigger S1. Guessed API names compile-fail at best and produce wrong geometry at worst.

**3. Section 1.3 of `GOALS_AND_TASKS.md` lists files known by name only.**
Their contents are unknown. Do not infer behaviour from a filename.

**4. Phase 2 is a hard gate.**
Do not begin Phase 3 until T-201 (millimetre conversion) and T-202 (provenance model) are complete and green. Report the `ScanStatistics` field list before porting it.

**5. T-603 is the project's most important test.**
The exporter must round-trip `handoff-plan.json` → `handoff-roomplan.json` exactly. If it fails, fix the exporter. **Never modify the fixture.**

**6. Read `GOALS_AND_TASKS.md` §2 before writing anything.**
It contains the validator schema reproduced verbatim, the API traps, and the scope bans. Violating the contract rejects the entire web import.

**7. `MagpieCore` is pure Swift — no Apple imports.**
Everything in `magpie-field/MagpieCore/` must build and test on Windows via `swift test`. Do not import `simd`, `CoreGraphics`, `UIKit`, `ARKit`, `RoomPlan`, or `os` inside it. Use the core's own `Mat4` / `Vec3` / `Pt2` types; the `simd` and `CGPoint` bridges live in the iOS target only. See `SETUP_WINDOWS.md` §2.

---

## Forbidden — do not build

- WiFi, RF propagation, or signal mapping (`WiFiSignalManager`, `WiFiOverlayView`, `RFPropagationModel`, `_wifi.json`)
- IFC / BIM export (`IfcExportBridge`, `bimifc_ffi`, `BimIfcFFI.xcframework`)
- OBJ / STL export
- Room type detection (`RoomTypeDetector`)
- Any LLM, assistant, or AI feature
- Material takeoff (M12)
- Non-LiDAR capture modes, templates, corner plotting, blueprint tracing (M10, M11)
- Cabinet layout generation

Do not add a `vertices`/`nodes`/`perimeter`/`area` field to the handoff payload. Do not rename contract fields. Do not add dependencies — Swift: Apple frameworks + `MagpieCore` only; web: only what is in `package.json`.

---

## Stop and ask

Stop and ask a human when any of these hold. Do not pick a default and continue.

```
S1  A required symbol is unfindable and not in the verified list
S2  RESOLVED — RoomPlanExampleApp app target is RoomPlanSimple (verified 2026-10-10)
S3  Secrets.swift appears to contain a live credential — report the filename only, never the value
S4  The handoff fixtures are missing or contradict docs/handoff-format-v1.md
S5  The web rejects a package the local validator passed
S6  The upload quota is smaller than a realistic package
S7  A task needs an answer from GOALS_AND_TASKS.md §6 (D2–D10)
S8  A file to port contains substantial code outside the task's stated purpose
```

---

## Every task ends with this receipt

```
TASK    T-<id>
STATUS  done | blocked | partial
READ    <files actually read, with line ranges>
WROTE   <files created or modified>
VERIFY  <the exact command run, and its exact result>
ASSUMED <anything not read or not run — should be empty>
BLOCKER <S<id> or D<id>, or none>
```

`ASSUMED` must be empty for a task to be `done`. If it is not, the status is `partial`.

Do not report a task done because a file exists. Every task has a verify step — run it and quote the result.

**After completing a task, update `PROGRESS.md`.** One row change plus a change-log line. Keep it current; it is the handoff between sessions.

---

## Conventions

- Commit one task at a time. Message: `<TYPE>(T-<id>): <summary>` — `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.
- Lengths: metres internally, millimetres at the display and export boundary only. Never do arithmetic in millimetres and convert back.
- Never overwrite a `scanned` dimension with a `tape` dimension. Export both.
- Non-trivial logic leaves one runnable check behind — an assert-based self-check or a small `test_*.swift` / `*.test.ts`.

---

## Current state

See `PROGRESS.md` for the live task ledger, the current phase, and open blockers.

Working on Windows. Build the web app and `MagpieCore` locally; a Mac is required only from the iOS UI work onward. `SETUP_WINDOWS.md` §7 gives the recommended work order.
