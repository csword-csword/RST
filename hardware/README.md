# Pinpoint smart-pin sensor cap (3D-printable)

`pinpoint-sensor-cap.scad` — a parametric OpenSCAD model of the grip "puck" that
replaces the ball knob on a weight-stack pin: it mounts on the steel slug, houses
the sensor PCB + battery, and has a **twist-off front cap** (quarter-turn bayonet)
for battery changes.

## Use
1. Install [OpenSCAD](https://openscad.org) (free).
2. Open the `.scad` file, edit the parameters at the top (all the `TODO` values).
3. `F5` to preview, `F6` to render, then **File → Export → STL**.
   Export `part = "body"` and `part = "lid"` separately.
4. Slice and print (PETG / ABS / ASA recommended over PLA — sweat + heat + abuse).

> Every value is currently a **placeholder**. The model becomes real once the pin,
> sensor, and battery dimensions are filled in — and any 3D-printed fit needs one
> test print to tune the `clr` (clearance) value for your printer.

## Why a bayonet (quarter-turn) instead of screw threads
Fine printed threads in this size strip easily after a few battery changes. A
quarter-turn twist-lock is more durable and quicker to open. A screw-thread
variant can be added if preferred.
