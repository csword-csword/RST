# Smart Pin (MOKO M1Pro) — setup & integration

The pin's sensor is a **MOKO MK Sensor series M1Pro** — a BLE beacon with a
3-axis accelerometer. Critically, it **broadcasts its acceleration and a motion
counter inside its advertisement** (MOKO "Sensor info" frame, Service Data UUID
`0xEA01`, frame type `0x80`). RST therefore tracks reps by **scanning** for that
advertisement and counting peaks in the broadcast acceleration — **no GATT
connection or pairing password is required**.

## How RST uses it

| Layer | File | Role |
|-------|------|------|
| Advertisement parser | `RST/Services/SensorFrame.swift` | Decodes status, motion count, X/Y/Z accel (mg), battery, Tag ID |
| Rep algorithm | `RST/Services/RepCounter.swift` | Peak detection on dynamic acceleration with hysteresis + refractory gap |
| Device driver | `RST/Services/MokoPinDevice.swift` | `CBCentralManager` scan → parse → count; rest auto-detected when motion stops |
| Mock | `RST/Services/PinDeviceService.swift` | Simulated session for the simulator / demos |

On device the app uses `MokoPinDevice` by default; the simulator (or Settings →
**Use simulated pin**) uses `MockPinDevice`. Both satisfy the same
`PinDeviceService` protocol, so the UI is identical.

The app starts scanning at launch (`RootView.task`). It locks onto the first
qualifying sensor (or a paired Tag ID) and, during a set, feeds each
advertisement's acceleration into `RepCounter`.

## Recommended sensor settings (configure with the MOKO app)

Until in-app configuration is added (see below), set the M1Pro up once using
MOKO's **MKSensor / BeaconX Pro** app. These values adapt the manual's
"Movement-based dynamic tracking" scenario for rep counting:

**Advertisement / SLOT**
- **Frame type: `Sensor info`** — required; this is the only frame RST parses.
- **Tag ID:** assign a unique value per pin (e.g. `000001`). Used to identify and
  "pair" a specific pin. (Leave "Tag ID autofill" off so the ID stays stable.)
- **Battery ADV mode: `Percentage`** — so the app shows battery %.

**Trigger function: enable**
- *Step 1* — Trigger type **Motion detection**, event **Device starts moving**,
  **Static verify period ≈ 3 s** (how quickly a set ends after you stop/rack).
- *Step 2 (moving)* — Frame **Sensor info**, **Advertising interval = 100 ms**
  (the rep-counting sample rate — use the smallest the firmware allows; 200–500 ms
  also works for slower lifts), **Total adv duration = 0** (broadcast continuously
  while moving), Tx power `0 dBm`.
- *Step 3 (before trigger / static)* — enable "Advertising before triggered",
  Frame **Sensor info**, interval `1000 ms`, Low-power mode **enable**, standby
  e.g. `600 s` (saves battery between sets/workouts).

**Sensor configurations → 3-axis accelerometer**
- Sampling rate: highest available.
- Motion detection threshold/sensitivity: low–medium, so a normal rep reliably
  registers as "moving."

**Quick switch**
- **Connectable status: ON** (lets you reconfigure later / add in-app config).
- Trigger LED indicator: optional — it blinks red on motion, which is on-brand;
  disable to save battery.
- Password verification: default is fine (not used for scanning).

> The advertising-while-moving interval is effectively your sample rate. Faster =
> better rep accuracy. Very fast reps at a slow interval can undercount.

## Tuning rep detection

If reps over- or under-count with your machine and pin orientation, adjust in
`RepCounter.swift` (or via the initializer):

- `threshold` (default `0.15` g) — lower = more sensitive.
- `minRepInterval` (default `0.7` s) — minimum time between counted reps.
- `rearmFraction` / `baselineAlpha` — hysteresis and gravity-tracking speed.

`MokoPinDevice.restTimeout` (default `4 s`) controls how long without motion ends
a set in the app.

## Testing checklist

1. Configure the M1Pro as above with the MOKO app; note its Tag ID.
2. Build & run RST on a physical iPhone (Bluetooth isn't available in the
   simulator). Grant the Bluetooth prompt.
3. Settings → **Smart Pin Device** should show **Scanning…** then **Connected**,
   with the sensor name, Tag ID, battery, and signal.
4. Start a workout → scan machine → read stack → on the live set screen, move the
   pin to simulate reps and confirm the counter advances; stop for ~4 s and the
   set should end.

## Future: in-app configuration via the MOKO SDK

To configure the sensor from inside RST (instead of the MOKO app), integrate
[`12-iOS-MKSensor-SDK`](https://github.com/BeaconX-Pro/12-iOS-MKSensor-SDK)
(`pod 'MKBXPSeriesSlathf'`, Objective-C, iOS 14+). Its `ConnectManager` connects
with the default password `Moko4321`; the `Functions` subspec exposes the slot,
trigger, and 3-axis-accelerometer configuration pages.

Note: that SDK is **CocoaPods-only**, while RST is generated with XcodeGen/SPM.
Adding it means introducing a Podfile + `.xcworkspace` (or wrapping the SDK in a
local pod). It is **not required** for rep tracking — RST's core loop is pure
CoreBluetooth and works against any M1Pro configured as above.
