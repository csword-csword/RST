# Pinpoint — Smart Weight-Stack Workout Tracker

iOS app for tracking workouts on weight-stack machines fitted with a **smart pin**: a digital replacement for the standard stack pin containing a Bluetooth beacon and an accelerometer.

> Brand: **Pinpoint** (pinpoint.fitness). The repo, Xcode project, and code keep the original internal name **RST** for old time's sake.

The **smart pin is now wired to real hardware** — the MOKO M1Pro sensor, driven over CoreBluetooth (see [`SENSOR_SETUP.md`](SENSOR_SETUP.md)). The camera/ML steps (machine identification, stack reading) are still stubbed behind protocols with realistic mocks, and every integration lives behind a protocol so mocks and real implementations swap cleanly.

## The workout flow

Setting the weight is a physical action — you place the smart pin in the stack at the machine. The app then:

1. **Scan machine** — point the camera at the machine's **name label**; on-device OCR (Vision) reads the text and matches it to a **universal machine taxonomy** (`EquipmentTextMatcher` against `master.json`, ~35 machine types with manufacturer aliases). Works at any gym, anywhere — no gym profile required. A mock classifier stands in on the simulator.
2. **Read the stack** — point the camera at the weight stack; the app reads where the pin was placed and infers the loaded weight (with a correction stepper for misreads, and a mismatch warning when a template calls for a different weight). *Stub: `MockWeightStackReader`.*
3. **Lift** — sets and reps are tracked live from the pin's accelerometer, with automatic set-end detection on rest. **Real:** `MokoPinDevice` scans the M1Pro's BLE advertisement and counts reps from its broadcast acceleration (`MockPinDevice` still drives the simulator and demos).

Plus:

- **Location tracking** — each workout records where it happened (CoreLocation + reverse geocoding).
- **Gym profiles** — bundled equipment catalogs for a generic gym, **Planet Fitness**, and **LA Fitness**; detection and the builder are scoped to the active profile's machines (`RST/Resources/Catalogs/*.json`).
- **History** — every workout stored with date, time, location, machines, and sets × reps × weight (SwiftData).
- **Builder** — compose reusable workout templates from an equipment catalog and run them with planned sets/reps/weights pre-filled.
- **Rest timer** — countdown between sets with haptic/voice cues (free).
- **Free core + optional Pro** — tracking, history, builder, and the rest timer are free with the pin; **Pinpoint Pro** ($49.99/year, Apple In-App Purchase) adds **Insights** (PRs, est. 1RM, volume & muscle-balance charts), a **voice coach**, and **CSV export**. See [`SUBSCRIPTION.md`](SUBSCRIPTION.md) and the [`PRO_FEATURES.md`](PRO_FEATURES.md) menu.

## Getting started

Requirements: Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
open RST.xcodeproj
```

Build and run the `RST` scheme (iOS 17+). The app is fully usable in the simulator — the camera preview falls back to a placeholder and all device interactions are simulated. Run tests with `Cmd-U`.

## Architecture

- **SwiftUI + SwiftData**, iOS 17+, Observation framework throughout.
- `RST/Services/` defines the integration seams:
  - Machine recognition — on-device OCR (`LabelScannerView`, Vision) reads the machine's label across all text lines, weighting larger text; `EquipmentTextMatcher` matches it (with aliases) against the universal taxonomy (`EquipmentCatalogStore.master`). Facility-agnostic — works at any gym. `MockEquipmentClassifier` is the simulator fallback. (A cloud vision-language model can be added later for unlabeled machines; the BLE Tag ID can identify machines outright under the gym/B2B model.)
  - `WeightStackReading` — camera → loaded weight (future vision + BLE confirmation)
  - `PinDeviceService` — smart-pin connection, accelerometer rep stream, set detection. Real impl: `MokoPinDevice` (`SensorFrame` parser + `RepCounter` over CoreBluetooth); mock: `MockPinDevice`.
- Implementations are chosen in one place — `RSTApp.swift` — and injected via SwiftUI environment keys (`ServiceEnvironment.swift`). The pin uses real hardware on device and the mock in the simulator / when "Use simulated pin" is on.
- `RST/Models/WorkoutModels.swift` — SwiftData schema: `Workout → ExerciseEntry → SetRecord`, plus `WorkoutTemplate → TemplateExercise`.
- Equipment catalogs are plain bundled JSON; add a new gym chain by dropping in another catalog file and listing it in `EquipmentCatalogStore`.
