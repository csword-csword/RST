# RST — Smart Weight-Stack Workout Tracker

iOS app for tracking workouts on weight-stack machines fitted with a **smart pin**: a digital replacement for the standard stack pin containing a Bluetooth beacon and an accelerometer.

The device API isn't available yet, so **all hardware and ML integrations are stubbed behind protocols** with realistic mock implementations — the entire app flow is buildable and demoable today, and the real SDK drops into the same interfaces.

## The workout flow

Setting the weight is a physical action — you place the smart pin in the stack at the machine. The app then:

1. **Scan machine** — point the camera at the machine; a vision model identifies the equipment type (lat pulldown, chest press, …). *Stub: `MockEquipmentClassifier`.*
2. **Read the stack** — point the camera at the weight stack; the app reads where the pin was placed and infers the loaded weight (with a correction stepper for misreads, and a mismatch warning when a template calls for a different weight). *Stub: `MockWeightStackReader`.*
3. **Lift** — sets and reps are tracked live from the pin's accelerometer, with automatic set-end detection on rest. *Stub: `MockPinDevice` (simulates reps every 2–3.5 s and rest detection).*

Plus:

- **Location tracking** — each workout records where it happened (CoreLocation + reverse geocoding).
- **Gym profiles** — bundled equipment catalogs for a generic gym, **Planet Fitness**, and **LA Fitness**; detection and the builder are scoped to the active profile's machines (`RST/Resources/Catalogs/*.json`).
- **History** — every workout stored with date, time, location, machines, and sets × reps × weight (SwiftData).
- **Builder** — compose reusable workout templates from an equipment catalog and run them with planned sets/reps/weights pre-filled.

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
  - `EquipmentClassifying` — camera → machine type (future Core ML/Vision model)
  - `WeightStackReading` — camera → loaded weight (future vision + BLE confirmation)
  - `PinDeviceService` — smart-pin connection, accelerometer rep stream, set detection (future CoreBluetooth + device SDK)
- Mocks are injected in one place — `RSTApp.swift` — via SwiftUI environment keys (`ServiceEnvironment.swift`). Swap them for real implementations there.
- `RST/Models/WorkoutModels.swift` — SwiftData schema: `Workout → ExerciseEntry → SetRecord`, plus `WorkoutTemplate → TemplateExercise`.
- Equipment catalogs are plain bundled JSON; add a new gym chain by dropping in another catalog file and listing it in `EquipmentCatalogStore`.
