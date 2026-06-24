// =============================================================================
// Pinpoint Smart-Pin sensor cap — parametric, 3D-printable
// =============================================================================
// A two-part grip "puck" that replaces the ball knob on a weight-stack pin:
//   - BODY:  knurled grip, socket on the back for the steel pin, cavity for the
//            sensor PCB + battery, quarter-turn (bayonet) mount on the front.
//   - LID:   front cap with the red-LED window; twists off for battery changes.
//
// A bayonet/quarter-turn is used instead of fine screw threads because printed
// threads in this size strip easily and a twist-lock survives many battery
// swaps. A screw-thread variant is easy to add later if you prefer.
//
// EVERYTHING below is a PLACEHOLDER until you send real dimensions. Values are
// my best guesses so the geometry is visible; treat them as a starting point.
// 3D-printed fits ALWAYS need a test print to tune clearances (see `clr`).
//
// Render:  open in OpenSCAD (free) -> F5 preview / F6 render -> Export STL.
// Tip: set `part = "body"` then export, then `part = "lid"` and export again.
// =============================================================================

part = "both";        // "body", "lid", or "both" (both = laid out side by side)
$fn = 96;             // smoothness

// ---- Steel pin (the slug the cap mounts onto) -------------------------- TODO
pin_dia        = 8.0;   // diameter of the steel pin
pin_socket_len = 16.0;  // how deep the pin seats into the body
pin_setscrew   = true;  // add a cross-hole for an M3 grub screw to lock the pin
setscrew_dia   = 3.2;   // M3 clearance

// ---- Sensor module (the puck/PCB the cap must contain) ----------------- TODO
sensor_dia     = 24.0;  // diameter of the sensor board/puck
sensor_thick   = 6.0;   // its thickness
led_offset     = 0.0;   // LED distance from center (0 = centered)
led_window_dia = 5.0;   // hole/window in the LID over the LED

// ---- Battery (defaults: CR2032 coin cell) ------------------------------ TODO
batt_dia       = 20.0;  // CR2032 = 20.0
batt_thick     = 3.2;   // CR2032 = 3.2
batt_holder    = true;  // print a simple retaining shelf (else assume on-board holder)

// ---- Grip / shell ------------------------------------------------------------
wall           = 2.4;   // shell wall thickness (>=3 perimeters)
grip_dia       = 38.0;  // outer grip diameter (sized to push/pull comfortably)
knurl          = true;  // vertical grip ribs
knurl_count    = 28;
knurl_depth    = 0.8;

// ---- Closure / sealing -------------------------------------------------------
clr            = 0.25;  // print clearance for moving fits — TUNE PER PRINTER
lug_count      = 2;     // bayonet lugs
lug_w          = 5.0;   // lug width (deg handled below)
lug_h          = 2.2;   // lug height (axial)
lug_proj       = 1.6;   // how far the lug sticks out radially
twist_deg      = 70;    // quarter-turn lock angle
oring          = true;  // O-ring groove on the lid plug for sweat resistance
oring_cs       = 1.5;   // O-ring cross-section (e.g., 1.5mm)

// ---- Lanyard attachment ------------------------------------------------------
// Attaches to the BODY (never the removable lid) and sits near the front rim so
// the puck hangs like a branded medallion with the LED/engraved face outward.
// Use a real lanyard with a SPLIT RING + BREAKAWAY clasp (safety near equipment).
lanyard        = true;
lanyard_ang    = 90;    // position around the rim (deg). 90 = "top"
ear_proj       = 7.0;   // how far the loop boss sticks out past the rim
ear_thick      = 8.0;   // boss thickness along the puck axis (>= hole + ~3)
ear_hole       = 4.5;   // through-hole for a split ring
ear_boss       = 9.0;   // outer boss diameter (leaves wall around the hole)

// ---- Derived -----------------------------------------------------------------
inner_dia  = max(sensor_dia, batt_dia) + 1.0;     // cavity diameter
cavity_len = sensor_thick + batt_thick + 1.0;     // cavity depth
plug_dia   = inner_dia - 2*clr;                   // lid plug fits the cavity bore
lid_len    = 6.0;                                 // lid plug insertion depth
body_len   = pin_socket_len + cavity_len + 3.0;
bore_dia   = inner_dia;                            // front bore the lid enters

// =============================================================================
module knurled_cylinder(d, h) {
    cylinder(d=d, h=h);
    if (knurl)
        for (i = [0:knurl_count-1])
            rotate([0,0, i*360/knurl_count])
                translate([d/2, 0, 0])
                    cylinder(d=knurl_depth*2, h=h, $fn=6);
}

// Bayonet slots cut into the body's front bore (L-shaped: axial entry + lock).
module bayonet_slots(at_radius) {
    for (i = [0:lug_count-1])
        rotate([0,0, i*360/lug_count]) {
            // axial entry channel from the front face
            translate([at_radius, 0, body_len - lid_len - 0.1])
                rotate([0,0,-(lug_w*2)/2])
                    rotate_extrude(angle = lug_w*2)
                        translate([0,0]) square([lug_proj+clr+0.5, lid_len+0.2]);
            // circumferential locking channel
            translate([0,0, body_len - lug_h - clr - 0.5])
                rotate([0,0, 0])
                    rotate_extrude(angle = twist_deg + lug_w*2)
                        translate([at_radius,0])
                            square([lug_proj+clr+0.5, lug_h+2*clr]);
        }
}

// Lanyard loop: a rounded boss on the rim with a through-hole for a split ring.
ear_z = body_len - ear_thick/2 - 1;
module lanyard_ear_solid() {
    rotate([0,0, lanyard_ang])
        translate([0,0, ear_z])
            linear_extrude(height = ear_thick, center = true)
                hull() {
                    translate([grip_dia/2 - 2, 0]) circle(d = ear_boss);
                    translate([grip_dia/2 + ear_proj, 0]) circle(d = ear_boss);
                }
}
module lanyard_ear_hole() {
    rotate([0,0, lanyard_ang])
        translate([grip_dia/2 + ear_proj - ear_boss*0.35, 0, ear_z])
            cylinder(d = ear_hole, h = ear_thick + 4, center = true);
}

module body() {
    difference() {
        union() {
            knurled_cylinder(grip_dia, body_len);
            if (lanyard) lanyard_ear_solid();
        }
        if (lanyard) lanyard_ear_hole();
        // front cavity (holds sensor + battery, and receives the lid)
        translate([0,0, body_len - cavity_len - lid_len + 0.01])
            cylinder(d=bore_dia, h=cavity_len + lid_len);
        // back socket for the steel pin
        translate([0,0,-0.01]) cylinder(d=pin_dia + clr, h=pin_socket_len);
        // set screw to lock the pin
        if (pin_setscrew)
            translate([0,0, pin_socket_len*0.5])
                rotate([0,90,0]) cylinder(d=setscrew_dia, h=grip_dia);
        // bayonet slots
        bayonet_slots(bore_dia/2 - 0.01);
        // battery retaining shelf (leaves a lip the battery sits behind)
        if (batt_holder)
            translate([0,0, body_len - lid_len - 0.5])
                cylinder(d=bore_dia, h=0.6);
    }
}

module lid() {
    difference() {
        union() {
            // outer flange (matches grip diameter, knurled edge to grab)
            cylinder(d=grip_dia, h=wall);
            // plug that enters the body bore
            translate([0,0, -lid_len]) cylinder(d=plug_dia, h=lid_len);
            // bayonet lugs
            for (i = [0:lug_count-1])
                rotate([0,0, i*360/lug_count])
                    translate([plug_dia/2, 0, -lid_len + lug_h/2 + 0.5])
                        rotate([0,0,-lug_w])
                            rotate_extrude(angle = lug_w*2)
                                translate([0,0]) square([lug_proj, lug_h]);
        }
        // LED window
        translate([led_offset, 0, -lid_len-0.1])
            cylinder(d=led_window_dia, h=wall + lid_len + 0.2);
        // O-ring groove around the plug
        if (oring)
            translate([0,0, -lid_len + lid_len*0.5])
                rotate_extrude()
                    translate([plug_dia/2 - oring_cs*0.4, 0])
                        circle(d=oring_cs);
        // shallow engraving ring for "PINPOINT FITNESS" (laser/print or paint-fill)
        translate([0,0, wall-0.4])
            difference() {
                cylinder(d=grip_dia*0.86, h=0.6);
                cylinder(d=grip_dia*0.72, h=0.6);
            }
    }
}

// =============================================================================
if (part == "body" || part == "both") body();
if (part == "lid"  || part == "both") translate([part=="both" ? grip_dia*1.3 : 0, 0, 0]) lid();
