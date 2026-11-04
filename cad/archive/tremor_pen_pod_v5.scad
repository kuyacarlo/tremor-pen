// === DESCRIPTION ===
// Tremor Cue Pen pod (v5: recessed poke switch facing the back wall, no clamp screw;
// v4: 22 AWG wiring room, IMU channel open to the wiring gap,
// snug TP4056 pocket, measured switch; v3.1 thick shelves kept): a small rounded box that sits on a ballpen
// above the grip (friction fit on a rubber-sleeved pen) and carries the tremor-cue electronics (ESP32-S3
// SuperMini, TP4056 charger, DRV8833 motor driver, LSM6DS3 IMU, 1027 coin
// motor, slide switch, FL902030 560 mAh LiPo).
// Physical context: hand-held, sits on the pen above the grip. Loads are
// small: hand pressure, a USB plug pushed in.
// Charging the TP4056 is the main heat source, so the charger is the top
// board, under the vents and LED holes.
//
// Design decisions:
//   - Two printed parts. BASE holds the pen and every part.
//     COVER drops over it and is held by 2 x M2 screws in the front face.
//   - Repair path: remove 2 screws, lift the cover. Battery, ESP32, TP4056
//     and IMU slide out the back like cards (the IMU's wires go up through the floor). The DRV8833 lifts out. The motor
//     and switch come out sideways. Every path is checked by a clash_* part.
//   - Boards ride on ledges; open sides between three posts let wires pass
//     between layers. Front stops keep the USB ports at the back wall.
//   - Pen: plain 8 mm sleeve behind the box, same bore as the box; the
//     rubber-sleeved pen friction-fits (no clamp screw, so nothing blocks the
//     back wall).
//   - Switch: recessed, handle points at the back wall and stops 0.3 mm short;
//     flick it through the back-wall poke slot with a pin. A stop tab behind
//     the body and a step in front hold it; it drops in sideways.
//   - Cover retention: 2 front screws plus a snap ridge on each back post that
//     clicks into a slot in the cover side wall (PETG snap, 0.4 mm).
//   - Print orientation: base stands on its front face (ledges and posts are
//     vertical fins, inserts vertical). Cover prints upside down on its top
//     (top edges are 45 deg chamfers, not rounds, so nothing overhangs).
//
// Terminology -> code:
//   "the base" / "rack"   -> base(), base_print(); posts, ledges in rack()
//   "the cover"           -> cover(), cover_print()
//   "front screws"        -> front_screws, insert_d, insert_len
//   "pen hole"            -> pen_d, hole_comp, bore_free
//   "pen sleeve / collar" -> collar_l, collar_wall (plain sleeve; the rubber-sleeved pen friction-fits)
//   "shelves / ledges"    -> ledge_t, ledge_lip
//   "LED holes", "vents"  -> led_x, led_dz, vent_dz
//   "switch poke slot"    -> sw_poke (back wall); switch pocket sw_x, sw_y, sw_body_z, sw_legs_z
//   "snap ridges"         -> detent_y, detent_h; ridges in base_raw(), slots in cover()
//   "part sizes"          -> batt, mcu, chg, drv, imu, mot, sw (bare, measured)
//
// Common modifications:
//   Different pen         -> pen_d (bore = pen_d + hole_comp + bore_free, box and sleeve)
//   Different battery     -> batt; the asserts say what no longer fits
//   LEDs not under holes  -> led_x, led_dz (measure your TP4056)
//   Looser part fit       -> clr (per side; PETG sliding 0.3-0.4)
//   Different inserts     -> insert_d (datasheet hole), insert_len
//
// Overall dimensions: see ECHO "Pod" line (about 30.7 x 38.6 x 40 mm, +8 mm sleeve)
// Coordinate system (use pose): Z along the pen (0 = front, toward the tip),
//   Y up away from the pen, X across. Pen axis = Z axis.
// NOTE: printable parts are output in print orientation on Z=0:
//   base_print(): use pose, standing on its front face.
//   cover_print(): turned so the cover's top is on the plate.

// === PRINT SETTINGS ===
// Material: base Bambu PLA Basic, cover matte PETG (on a Bambu A1 mini, 0.4 nozzle).
//   The charger heat sits under the PETG cover. Fits were tuned for PETG; this
//   printer prints holes small, so dry-fit the switch, IMU and charger first.
// Layer Height: 0.2 mm
// Walls/Perimeters: 3 (1.35 mm)
// Infill: 30% gyroid
// Supports: None required. Horizontal holes are teardrops, ledge ends are
//   45 deg chamfers, short flat ceilings are bridges under 10 mm.
// Orientation: base on its front face, cover on its top (as output).
// Notes: PETG 240 C (245 first layer), bed 70 C, fan 30-40%; PLA per preset.
//   Heat-set inserts in the PLA base at 180-200 C. Slicer elephant-foot comp 0 (modelled).

// === PARAMETERS ===
// Printer settings (makerspace printer, assumed 0.4 nozzle)
nozzle_diameter = 0.4;
layer_height = 0.2;
build_x = 180; build_y = 180; build_z = 180;   // conservative; parts are small

// Fits (PETG, see skill Rule 8 and material notes)
hole_comp = 0.30;   // printed holes come out small by this much
bore_free = 0.30;   // free-running allowance for the pen bore
clr       = 0.30;   // per-side clearance, every electronic part in its pocket
rack_gap  = 0.30;   // per-side gap between base rack and cover (PETG sliding fit)

// Body
c_top   = 2.5;      // 45 deg chamfer on the cover's top edges
r_bot   = 2.5;      // rounding on the bottom edges (base)
y_bot   = -8.5;     // underside, pen axis = 0
y_seam  = -5.0;     // cover side walls end here and sit on the base shoulder
pen_d   = 10.8;     // measured pen barrel

// Hardware
insert_d   = 3.2;   // M2 heat-set insert hole (check the datasheet)
insert_len = 3.0;   // insert length; pocket = len + 1
m2         = 2.0;
front_screws = [[-9.0, 2.5], [9.0, 2.5]];   // clear of the cover's pen notch and the outer wall
collar_l    = 8;   // plain sleeve behind the box: extra grip length on the pen
stop_t      = 1.2; // board stop thickness along the pen
detent_h    = 0.4; // snap ridge engagement into the cover wall
collar_wall = 1.35;  // 3 perimeters; the sleeve carries no clamp load now

// Parts, bare measurements [width, length, thickness]
batt = [19.8, 30.5, 8.7];   // FL902030 560 mAh, flat on the floor
mcu  = [17.8, 24.9, 4.3];   // ESP32-S3 SuperMini incl. USB-C, port to the back
chg  = [17.2, 27.5, 3.3];   // TP4056 as measured (longest edge incl. micro-B), port to the back, top board
clr_c = 0.2;                // snug fit for the charger (it wobbled at 0.3+)
drv  = [15.5, 18.6, 3.2];   // DRV8833, stands upright behind the bulkhead
imu  = [12.9, 18.4, 2.3];   // LSM6DS3, stands in the left channel
imu_clr_t = 0.65;           // per side, thickness: 3.6 mm channel for a 2.3 board (roomy; foam-tape it rigid)
imu_clr_h = 0.3;            // per side, height: 13.5 mm channel for a 12.9 board
mot  = [9.9, 3.2];          // 1027 coin motor [diameter, thickness], right channel
sw   = [10.2, 5.6, 4.7];    // slide switch body [length (travel, vertical), width, depth], measured
sw_handle = 2.7;            // handle 2.7 x 2.7
sw_handle_h = 5.3;          // handle height; it points at the back wall
sw_travel = 4.1;            // handle travel (1.8 and 5.9 from the body end)
sw_leg_len = 4.3 + 1.0;     // straight legs + room for the solder joints
sw_gap = 0.3;               // handle tip to the inside of the back wall
sw_poke = [sw_handle + 0.8 + hole_comp, sw_handle + sw_travel + 0.8 + hole_comp];   // poke slot in the back wall [x, y]

// Cover openings
usbc_hole   = [9.8, 3.8];
microb_hole = [8.6, 3.4];
led_d   = 2.0;
led_x   = [-3.5, 0, 3.5];
led_dz  = 9;                // LED row, distance from the back wall
vent    = [9.0, 1.2];
vent_dz = [15, 17.5, 20, 22.5];

// === DERIVED CONSTANTS ===
extrusion_width = nozzle_diameter * 1.125;      // 0.45
wall      = extrusion_width * 3;                // 1.35 cover walls
top_wall  = extrusion_width * 3;
tube_wall = extrusion_width * 2;                // 0.9
floor_t   = extrusion_width * 2;
ledge_t   = extrusion_width * 3;                // 1.35: shelves are the load-bearing fins
bh_t      = extrusion_width * 4;                // 1.8 front bulkhead
ledge_lip = 1.5;
top_gap   = 0.6;
fudge     = 0.01;
ef_chamfer = 0.4;
$fn = $preview ? 32 : 64;

hx  = 14.0;                       // inner half width: 3.5 mm wiring gap beside the battery for 22 AWG
W   = 2 * (hx + wall);
hxr = hx - rack_gap;              // rack outer face
rb  = (pen_d + hole_comp + bore_free) / 2;     // pen bore radius
rt  = rb + tube_wall;
rco = rb + collar_wall;                         // sleeve outer radius (same bore as the box)

function fit(p) = [p[0] + 2*clr, p[1] + 2*clr, p[2] + 2*clr];
B = fit(batt); M = fit(mcu); C = chg + [2, 2, 2] * clr_c; D = fit(drv); I = [imu[0] + 2*imu_clr_h, imu[1] + 2*clr, imu[2] + 2*imu_clr_t]; S = fit(sw);
md = mot[0] + 2*clr;  mt = mot[1] + 2*clr;

// layers above the pen (Y)
y_f  = rt + floor_t;
y_b1 = y_f + B[2];
y_m0 = y_b1 + ledge_t;  y_m1 = y_m0 + M[2];
y_c0 = y_m1 + ledge_t;  y_c1 = y_c0 + C[2];
y_it = y_c1 + top_gap;
y_top = y_it + top_wall;

// along the pen (Z)
z_b  = wall + rack_gap;           // base front face
z_d  = [z_b + bh_t, z_b + bh_t + D[2]];
z_b0 = z_d[1] + 0.3;              // battery and boards start
z_bi = z_b0 + B[1];               // inside face of the cover back wall
L    = z_bi + wall;
z_be = z_bi - rack_gap;           // base rack back end
z_c  = L + rack_gap;              // collar starts just behind the cover
detent_y = (y_f + y_b1) / 2;      // snap ridge height (battery layer, on the back posts)

// channels beside the pen
imu_x = [-(hxr - wall), -(hxr - wall) + I[2]];   // 3-perimeter outer wall; wire opening runs from here to the battery edge
imu_open_x = [imu_x[0], imu_x[0] + 3.0];         // 3 mm floor opening over the IMU (battery edge overhangs it slightly)
imu_y = [y_f - floor_t - I[0], y_f - floor_t];
imu_z = [10, z_be + fudge];       // open to the back so the IMU slides out
mot_x = [hx - mt, hx + 1];
mot_c = [0.5, z_b + insert_len + 1 + 2 + md/2];   // [y, z] centre
sw_x  = [hx - S[1], hx + 1];                     // open to the right side: drops in sideways with the cover off
sw_y  = [rt - 0.45 - S[0], rt - 0.45];           // under the floor (1.35 mm floor above), travel runs up and down
sw_xc = (sw_x[0] + hx) / 2;  sw_yc = (sw_y[0] + sw_y[1]) / 2;
sw_body_z = [z_bi - sw_gap - sw_handle_h - sw[2] - clr, z_bi - sw_gap - sw_handle_h + clr];
sw_legs_z = [sw_body_z[0] - sw_leg_len, sw_body_z[0]];
sw_tab = [sw_x[0], sw_x[0] + 1.2];                 // stop tab behind the body (inner side, clear of the handle)
sw_open_x0 = sw_x[0] + 1.5;                        // wire opening over the legs starts here
sw_z  = [sw_legs_z[0], z_be];                     // whole switch zone, for the overlap checks
post_x0 = B[0]/2 + 0.1;
posts_z = [[z_d[0] - fudge, z_b0 + 2], [(z_b0 + z_bi)/2 - 1, (z_b0 + z_bi)/2 + 1], [z_be - 6, z_be]];

// === CONTRACTS ===
function mult(v) = abs(v / extrusion_width - round(v / extrusion_width)) < 1e-6;
assert(mult(wall) && mult(top_wall) && mult(tube_wall) && mult(floor_t) && mult(ledge_t) && mult(bh_t), "walls must be whole perimeters");
assert(post_x0 + 3 * extrusion_width <= hxr + 1e-6, "posts beside the battery thinner than 3 perimeters");
assert(M[0]/2 - ledge_lip > 0 && M[0]/2 < hxr && C[0]/2 < hxr, "board wider than the rack");
assert(D[1]/2 < post_x0, "DRV8833 hits the posts");
assert(C[1] <= B[1] && M[1] <= B[1], "board longer than the battery bay");
assert(D[0] <= y_it - rack_gap - y_f, "DRV8833 too tall to stand up");
assert(imu_y[0] - y_bot >= 1.2, "IMU channel breaks the underside");
assert(-imu_x[1] > rt && sw_x[0] > rt && mot_x[0] > rt, "channel cuts into the pen tube");
assert(-imu_x[1] - clr > rco, "collar blocks the IMU slide-out");
assert(sw_y[0] > y_seam && mot_c[0] - md/2 > y_seam, "motor or switch below the cover seam (cannot come out sideways)");
assert(mot_c[1] + md/2 < sw_z[0], "motor and switch overlap");
assert(rco < y_f + clr - 0.1, "collar blocks the battery slide-out");
assert(sw_x[0] > rt + 0.9, "switch pocket cuts the pen tube");
assert(sw_tab[1] < sw_xc - sw_handle/2 - 0.3, "switch stop tab hits the handle");
assert(sw_tab[1] > sw_x[0] + clr + 0.6, "switch stop tab overlaps the body by under 0.6 mm");
assert(sw_xc - sw_poke[0]/2 - (rco + rack_gap) >= 1.2, "poke slot too close to the collar notch");
assert(insert_len + 1 + 2 <= mot_c[1] - md/2 - z_b + 1e-6, "less than 2 mm between front inserts and the motor pocket");
assert(min([for (s = front_screws) hxr - abs(s[0]) - insert_d/2]) >= 3 * extrusion_width - 1e-6, "insert boss outer wall under 3 perimeters");
assert(min([for (s = front_screws) abs(s[0]) - (m2 + hole_comp + 0.3)/2 - sqrt(pow(rt + rack_gap, 2) - pow(s[1], 2))]) >= 1.0, "cover web between screw hole and pen notch under 1 mm");
assert(rco < y_f, "collar neck must sit under the floor");
assert(W <= 31 && y_top - y_bot <= 39.5 && L <= 41, "pod grew past 31 x 39.5 x 41");
assert(hx - rack_gap - B[0]/2 >= 3.0, "wiring gap beside the battery under 3 mm (22 AWG)");
assert(norm([imu_x[0] - (-W/2 + r_bot), imu_y[0] - (y_bot + r_bot)]) <= r_bot - 1.2 || imu_x[0] > -W/2 + r_bot || imu_y[0] > y_bot + r_bot, "IMU channel too close to the bottom corner");
echo(str("Pod: ", W, " wide x ", y_top - y_bot, " tall x ", L, " long, +", collar_l, " collar"));

// === MODULES ===
module box(xr, yr, zr) translate([xr[0], yr[0], zr[0]]) cube([xr[1]-xr[0], yr[1]-yr[0], zr[1]-zr[0]]);
module mirror_x() { children(); mirror([1, 0, 0]) children(); }

// teardrop along X or Y, point toward +Z (base print orientation = use pose)
module teardrop_hole(d, h, axis = "y") {
    r = d / 2;
    rotate([0, 0, axis == "x" ? 90 : 0]) rotate([90, 0, 0])
        linear_extrude(height = h, center = true) union() { circle(r = r); rotate(45) square(r); }
}
// teardrop along Z with the point toward -Y (cover printed on its top: -Y is up)
module teardrop_z_down(d, h) linear_extrude(h) union() { circle(d = d); rotate(225) square(d/2); }

// 2D profiles (cross-section looking along the pen)
module p_out() hull() {
    translate([-W/2, y_top - c_top - fudge]) square([W, fudge]);
    translate([-W/2 + c_top, y_top - fudge]) square([W - 2*c_top, fudge]);
    translate([-W/2 + r_bot, y_bot + r_bot]) circle(r_bot);
    translate([ W/2 - r_bot, y_bot + r_bot]) circle(r_bot);
}
module p_in() offset(delta = -wall) p_out();
module p_rack() offset(delta = -rack_gap) p_in();
module base_outline() {
    intersection() { p_out(); translate([-W, y_bot - 1]) square([2*W, y_seam - y_bot + 1]); }
    intersection() { p_rack(); translate([-W, y_seam - fudge]) square([2*W, y_it]); }
}

// ---------------- base ----------------
module rack() intersection() {
    translate([0, 0, z_b - 1]) linear_extrude(L) p_rack();
    mirror_x() union() {
        for (i = [0 : 2]) box([post_x0, hx], [y_f - fudge, i == 0 ? y_it : y_c0 + fudge], posts_z[i]);  // only the front post (on the bulkhead) reaches the top
        for (yr = [[y_b1, y_m0], [y_m1, y_c0]]) {          // ledges, 45 deg lead-in at the front
            lip = (yr[0] == y_b1 ? M[0] : C[0]) / 2 - ledge_lip;
            hull() {
                box([lip, hx], yr, [z_b0 + (post_x0 - lip), z_be]);
                box([post_x0, hx], yr, [z_b0, z_b0 + fudge]);
            }
        }
        // back locators beside the boards (keep the ports on the holes)
        box([M[0]/2, hx], [y_m0 - fudge, y_m1 + fudge], [z_be - 6, z_be]);
        hull() {   // 45 deg underside, grows off the top ledge when printed
            box([C[0]/2, hx], [y_c0 - fudge, y_c0], [z_be - 6, z_be]);
            box([C[0]/2, hx], [y_c0 - fudge, y_c1], [z_be - 6 + (y_c1 - y_c0), z_be]);
        }
        // front stops: ramps in front of each board (45 deg side faces the plate)
        for (s = [[M, y_m0], [C, y_c0]]) {
            zf = z_bi - s[0][1];
            intersection() {   // never reach forward into the DRV8833 zone
            box([-W, W], [y_bot, 2 * y_top], [z_b0, L]);
            hull() {
                box([s[0][0]/2 - ledge_lip, hx], [s[1] - fudge, s[1] + 1.5], [zf - stop_t, zf]);
                box([s[0][0]/2 - ledge_lip, hx], [s[1] - fudge, s[1]], [zf - stop_t - 1.5, zf - stop_t]);
            }
            }
        }
    }
}

module base_raw() {
    translate([0, 0, z_b]) linear_extrude(z_be - z_b) base_outline_lower();
    translate([0, 0, z_b]) linear_extrude(bh_t) intersection() { p_rack(); translate([-W, y_f - fudge]) square([2*W, y_it - rack_gap - y_f + fudge]); }
    rack();
    translate([0, 0, z_b]) cylinder(r = rt, h = z_be - z_b + fudge);
    translate([0, 0, z_be - 1]) cylinder(r = rco, h = z_c + collar_l - z_be + 1);   // thick neck through the cover notch, then the collar
    // snap ridges on the back posts (45 deg both sides)
    mirror_x() translate([0, 0, z_be - 5]) linear_extrude(4) polygon([[hxr - 0.2, detent_y - 1.0], [hxr + rack_gap + detent_h, detent_y - 0.1], [hxr + rack_gap + detent_h, detent_y + 0.1], [hxr - 0.2, detent_y + 1.0]]);
}
// opening whose far end rises at 45 deg toward +X, so the plate above it prints supported from the -X side
module ramp_open(xr, yr, zr) hull() {
    box([xr[0], xr[0] + fudge], yr, zr);
    box([xr[1] - fudge, xr[1]], yr, [zr[0], zr[1] + (xr[1] - xr[0])]);
}
module front_face2d() union() { base_outline_lower(); intersection() { p_rack(); translate([-W, y_f - 0.5]) square([2*W, y_it - rack_gap - y_f + 0.5]); } }
module base_outline_lower() intersection() { base_outline(); translate([-W, y_bot - 1]) square([2*W, y_f - y_bot + 1]); }

module base() union() {
    base_cut();
    // switch stop tab, added after the pocket cuts: keeps the switch from walking back through the poke slot
    box(sw_tab + [-fudge, 0], sw_y, [sw_body_z[1], sw_body_z[1] + 1.2]);
}
module base_cut() {
    difference() {
        base_raw();
        // pen bore, same size all the way through the sleeve
        translate([0, 0, z_b - 1]) cylinder(r = rb, h = z_c + collar_l + 2);
        // channels: IMU (left, open to the back), motor and switch (right, open to the side)
        box(imu_x, imu_y, imu_z);
        translate([(mot_x[0] + mot_x[1])/2, mot_c[0], mot_c[1]]) teardrop_hole(md, mot_x[1] - mot_x[0], "x");
        box(sw_x, sw_y, [sw_body_z[0], z_be + 1]);                                  // switch body + handle, open to the back wall
        box([sw_x[0] + 1.5, hx + 1], sw_y, [sw_legs_z[0], sw_body_z[0] + fudge]);  // legs; the 1.5 mm inner step stops the body moving forward
        // wire slots from the channels up beside the battery
        for (zr = [[imu_z[0], posts_z[1][0] - 0.4], [posts_z[1][1] + 0.4, imu_z[0] + I[1]]])   // floor bridge left under the middle post (holds the IMU down)
            box(imu_open_x, [imu_y[1] - fudge, y_f + fudge], zr);
        ramp_open([post_x0, hx + 1], [mot_c[0] + md/2 - 2, y_f + fudge], [mot_c[1] - 3, mot_c[1] + 3]);
        ramp_open([sw_open_x0, hx + 1], [sw_y[1] - fudge, y_f + fudge], [max(sw_legs_z[0], posts_z[1][1] + 0.2), sw_body_z[0]]);   // over the switch legs: wires straight up
        box([sw_x[0], hx + 1], [mot_c[0] + md/2 - 2, rt - 0.6], [mot_c[1], sw_legs_z[0] + 2]);   // motor to switch run
        // notches in the ledges beside the boards: wire crossings between layers
        mirror_x() for (zr = [[z_b0 + 4, z_b0 + 9], [(z_b0 + z_bi)/2 + 3, (z_b0 + z_bi)/2 + 8]])
            for (yr = [[y_b1, y_m0], [y_m1, y_c0]]) box([M[0]/2 + 0.2, hx + 1], yr + [-fudge, fudge], zr + [-0.5, 0.5]);
        // front inserts (vertical in print)
        for (s = front_screws) translate([s[0], s[1], z_b - fudge]) {
            cylinder(d = insert_d, h = insert_len + 1);
            cylinder(d1 = insert_d + 2 * ef_chamfer, d2 = insert_d, h = ef_chamfer);   // mouth chamfer (elephant foot, insert lead-in)
        }
        // elephant-foot chamfer on the plate face (two 0.2 mm steps)
        for (i = [0, 1]) translate([0, 0, z_b - fudge + i * 0.2]) linear_extrude(0.2 + fudge)
            difference() { offset(delta = 2) front_face2d(); offset(delta = -(ef_chamfer - i * 0.2)) front_face2d(); }
    }
}
module base_print() translate([0, 0, -z_b]) base();

// ---------------- cover ----------------
module notch2d(n) { translate([-n, y_bot - 1]) square([2*n, -y_bot + 1]); circle(n); }

module cover() {
    difference() {
        linear_extrude(L) p_out();
        translate([0, 0, wall]) linear_extrude(L - 2*wall) p_in();
        box([-W, W], [y_bot - 1, y_seam], [wall, L - wall]);
        translate([0, 0, -1]) linear_extrude(wall + 2) notch2d(rt + rack_gap);
        translate([0, 0, L - wall - 1]) linear_extrude(wall + 2) notch2d(rco + rack_gap);
        mirror_x() box([hx - 0.5, W/2 + 1], [detent_y - 1.3, detent_y + 1.3], [z_be - 5.4, z_be - 0.6]);   // snap slots
        for (s = front_screws) translate([s[0], s[1], -1]) teardrop_z_down(m2 + hole_comp + 0.3, wall + 2);
        // back wall: USB-C (ESP32) and micro-B (TP4056)
        usb_y = y_m0 + clr + 1.0 + 1.6;
        mub_y = y_c0 + clr_c + 1.0 + 1.2;
        translate([0, usb_y, L - wall - 1]) linear_extrude(wall + 2) offset(r = 1) square([usbc_hole[0] - 2, usbc_hole[1] - 2], center = true);
        translate([0, mub_y, L - wall - 1]) linear_extrude(wall + 2) offset(r = 0.6) square([microb_hole[0] - 1.2, microb_hole[1] - 1.2], center = true);
        // switch poke slot in the back wall (flick the handle with a pin or the pen tip)
        translate([sw_xc - sw_poke[0]/2, sw_yc - sw_poke[1]/2, L - wall - 1]) cube([sw_poke[0], sw_poke[1], wall + 2]);
        // top: LED windows, vents
        for (x = led_x) translate([x, y_it - 1, z_bi - led_dz]) rotate([-90, 0, 0]) cylinder(d = led_d + hole_comp, h = top_wall + 2);
        for (dz = vent_dz) translate([-vent[0]/2, y_it - 1, z_bi - dz - vent[1]/2]) cube([vent[0], top_wall + 2, vent[1]]);
        // elephant-foot chamfer where the top meets the end faces (the side edges are already 45 deg)
        for (z = [0, L]) translate([0, y_top, z]) rotate([45, 0, 0]) cube([W + 2, ef_chamfer * sqrt(2), ef_chamfer * sqrt(2)], center = true);
    }
}
module cover_print() translate([0, 0, y_top]) rotate([-90, 0, 0]) cover();

// ---------------- dummies (bare parts, seated with clearance all round) ----------------
module d_batt() box([-batt[0]/2, batt[0]/2], [y_f + clr, y_f + clr + batt[2]], [z_b0 + clr, z_b0 + clr + batt[1]]);
module d_mcu()  box([-mcu[0]/2, mcu[0]/2], [y_m0 + clr, y_m0 + clr + mcu[2]], [z_bi - clr - mcu[1], z_bi - clr]);
module d_chg()  box([-chg[0]/2, chg[0]/2], [y_c0 + clr_c, y_c0 + clr_c + chg[2]], [z_bi - clr_c - chg[1], z_bi - clr_c]);
module d_drv()  box([-drv[1]/2, drv[1]/2], [y_f + clr, y_f + clr + drv[0]], [z_d[0] + clr, z_d[0] + clr + drv[2]]);
module d_imu()  box([imu_x[0] + imu_clr_t, imu_x[0] + imu_clr_t + imu[2]], [imu_y[0] + imu_clr_h, imu_y[0] + imu_clr_h + imu[0]], [imu_z[0] + clr, imu_z[0] + clr + imu[1]]);
module d_mot()  translate([mot_x[0] + clr, mot_c[0], mot_c[1]]) rotate([0, 90, 0]) cylinder(d = mot[0], h = mot[1]);
module d_sw_body()   box([sw_x[0] + clr, sw_x[0] + clr + sw[1]], [sw_y[0] + clr, sw_y[0] + clr + sw[0]], [sw_body_z[0] + clr, sw_body_z[0] + clr + sw[2]]);
module d_sw_handle() box([sw_xc - sw_handle/2, sw_xc + sw_handle/2], [sw_yc - sw_handle/2, sw_yc + sw_handle/2], [sw_body_z[0] + clr + sw[2] - fudge, z_bi - sw_gap]);
module d_sw()   { d_sw_body(); d_sw_handle(); }
module dummies() {
    color("dimgray") d_batt(); color("royalblue") d_mcu(); color("seagreen") d_chg();
    color("crimson") d_drv(); color("purple") d_imu(); color("silver") d_mot(); color("orange") d_sw();
}
module sweep(v) hull() { children(); translate(v) children(); }
far = L + collar_l + 60;

// === ASSEMBLY / RENDER ===
part = "all"; // "all", "explode", "base", "cover", "plate_both", "view_dummies", "clash_cover", "clash_parts_base", "clash_parts_cover", "clash_slide_batt", "clash_slide_mcu", "clash_slide_chg", "clash_slide_imu", "clash_lift_drv", "clash_side_mot", "clash_side_sw"
if (part == "all")     { color("lightslategray") base(); color("lightsteelblue", 0.35) cover(); dummies(); }
if (part == "explode") { color("lightslategray") base(); color("lightsteelblue") translate([0, 40, 0]) cover(); dummies(); }
if (part == "base")    base_print();
if (part == "cover")   cover_print();
if (part == "plate_both") { base_print(); translate([W + 8, 0, 0]) cover_print(); }   // one A1 mini plate
if (part == "view_dummies") dummies();
if (part == "clash_cover")       intersection() { base(); translate([0, fudge, 0]) cover(); }
if (part == "clash_parts_base")  intersection() { base(); dummies(); }
if (part == "clash_parts_cover") intersection() { cover(); dummies(); }
if (part == "clash_slide_batt")  intersection() { base(); sweep([0, 0, far]) d_batt(); }
if (part == "clash_slide_mcu")   intersection() { base(); sweep([0, 0, far]) d_mcu(); }
if (part == "clash_slide_chg")   intersection() { base(); sweep([0, 0, far]) d_chg(); }
if (part == "clash_slide_imu")   intersection() { base(); sweep([0, 0, far]) d_imu(); }
if (part == "clash_lift_drv")    intersection() { base(); sweep([0, 40, 0]) d_drv(); }
if (part == "clash_side_mot")    intersection() { base(); sweep([20, 0, 0]) d_mot(); }
if (part == "clash_side_sw")     intersection() { base(); union() { sweep([20, 0, 0]) d_sw_body(); sweep([20, 0, 0]) d_sw_handle(); } }
