// === DESCRIPTION ===
// Tremor Cue Pen pod (v3.1, thicker shelves/stops/collar web for 0.3 mm layers): a small rounded box that clamps onto a ballpen
// above the rubber grip and carries the tremor-cue electronics (ESP32-S3
// SuperMini, TP4056 charger, DRV8833 motor driver, LSM6DS3 IMU, 1027 coin
// motor, slide switch, FL902030 560 mAh LiPo).
// Physical context: hand-held, sits on the pen above the grip. Loads are
// small: hand pressure, a USB plug pushed in, the pen clamp screw.
// Charging the TP4056 is the main heat source, so the charger is the top
// board, under the vents and LED holes.
//
// Design decisions:
//   - Two printed parts. BASE clamps to the pen and holds every part.
//     COVER drops over it and is held by 2 x M2 screws in the front face.
//   - Repair path: remove 2 screws, lift the cover. Battery, ESP32, TP4056
//     and IMU slide out the back like cards. The DRV8833 lifts out. The motor
//     and switch come out sideways. Every path is checked by a clash_* part.
//   - Boards ride on ledges; open sides between three posts let wires pass
//     between layers. Front stops keep the USB ports at the back wall.
//   - Pen clamp is a split collar behind the box with its screw on the right
//     side, so nothing blocks the slide-out path. Its ear grows out of the
//     collar at 45 deg so it prints without support.
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
//   "pen clamp / collar"  -> collar_l, collar_wall, collar(), clamp screw M2 x 6 + nut
//   "shelves / ledges"    -> ledge_t, ledge_lip
//   "LED holes", "vents"  -> led_x, led_dz, vent_dz
//   "switch slot"         -> sw_slot
//   "snap ridges"         -> detent_y, detent_h; ridges in base_raw(), slots in cover()
//   "part sizes"          -> batt, mcu, chg, drv, imu, mot, sw (bare, measured)
//
// Common modifications:
//   Different pen         -> pen_d (collar bore follows; bore gets free fit)
//   Different battery     -> batt; the asserts say what no longer fits
//   LEDs not under holes  -> led_x, led_dz (measure your TP4056)
//   Looser part fit       -> clr (per side; PETG sliding 0.3-0.4)
//   Different inserts     -> insert_d (datasheet hole), insert_len
//
// Overall dimensions: see ECHO "Pod" line (about 27 x 38 x 40 mm, +8 mm collar)
// Coordinate system (use pose): Z along the pen (0 = front, toward the tip),
//   Y up away from the pen, X across. Pen axis = Z axis.
// NOTE: printable parts are output in print orientation on Z=0:
//   base_print(): use pose, standing on its front face.
//   cover_print(): turned so the cover's top is on the plate.

// === PRINT SETTINGS ===
// Material: PETG, transparent (first print: PLA Basic on a Bambu A1 mini, 0.4 nozzle) (Tg ~80 C vs PLA ~60 C: charging heat; clear
//   plastic shows the TP4056 LEDs). PLA works for a fit-test print.
// Layer Height: 0.2 mm
// Walls/Perimeters: 3 (1.35 mm)
// Infill: 30% gyroid
// Supports: None required. Horizontal holes are teardrops, ledge ends are
//   45 deg chamfers, short flat ceilings are bridges under 10 mm.
// Orientation: base on its front face, cover on its top (as output).
// Notes: nozzle 0.4. PETG 235-240 C, bed 75-80 C, fan 30-40%. Dry filament.
//   Heat-set inserts at 200-220 C. Slicer elephant-foot comp 0 (modelled).

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
m2_head_d  = 3.8;
nut_af     = 4.0;
front_screws = [[-9.0, 2.5], [9.0, 2.5]];   // clear of the cover's pen notch and the outer wall
collar_l    = 12;  // long enough for the ear's 45 deg underside
slit_w      = 1.5; // closes ~0.5 mm on the bore
slit_web    = 1.5; // solid ring at the front of the collar (5 layers at 0.3 mm)
stop_t      = 1.2; // board stop thickness along the pen
detent_h    = 0.4; // snap ridge engagement into the cover wall
collar_wall = 1.8;
ear_half    = 4.5;  // clamp screw M2 x 6 through the ear + M2 nut

// Parts, bare measurements [width, length, thickness]
batt = [19.8, 30.5, 8.7];   // FL902030 560 mAh, flat on the floor
mcu  = [17.8, 24.9, 4.3];   // ESP32-S3 SuperMini incl. USB-C, port to the back
chg  = [17.1, 28.6, 3.4];   // TP4056 incl. micro-B, port to the back, top board
drv  = [15.5, 18.6, 3.2];   // DRV8833, stands upright behind the bulkhead
imu  = [12.9, 18.4, 2.3];   // LSM6DS3, stands in the left channel
mot  = [9.9, 3.2];          // 1027 coin motor [diameter, thickness], right channel
sw   = [10.4, 5.7, 5.0];    // slide switch [length, height, body depth], pins clipped
sw_slot = [7.0, 2.8];       // switch handle opening [along, height]

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

hx  = 12.25;                      // inner half width (set by switch + post widths)
W   = 2 * (hx + wall);
hxr = hx - rack_gap;              // rack outer face
rb  = (pen_d + hole_comp + bore_free) / 2;     // pen bore radius
rt  = rb + tube_wall;
rc  = (pen_d + hole_comp) / 2;                 // collar bore (screw closes the slit)
rco = rc + collar_wall;

function fit(p) = [p[0] + 2*clr, p[1] + 2*clr, p[2] + 2*clr];
B = fit(batt); M = fit(mcu); C = fit(chg); D = fit(drv); I = fit(imu); S = fit(sw);
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
imu_x = [-(rt + 1.1) - I[2], -(rt + 1.1)];
imu_y = [y_f - floor_t - I[0], y_f - floor_t];
imu_z = [10, z_be + fudge];       // open to the back so the IMU slides out
mot_x = [hx - mt, hx + 1];
mot_c = [0.5, z_b + insert_len + 1 + 2 + md/2];   // [y, z] centre
sw_x  = [hx - sw[2] - clr - 0.05, hx + 1];   // clearance on the inner face only; top face sits at the cover wall
sw_y  = [-4.6, -4.6 + S[1]];
sw_z  = [z_bi - 1 - S[0], z_bi - 1];
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
assert(rco + 5.5 < W/2, "clamp ear sticks out of the side");
assert(insert_len + 1 + 2 <= mot_c[1] - md/2 - z_b + 1e-6, "less than 2 mm between front inserts and the motor pocket");
assert(min([for (s = front_screws) hxr - abs(s[0]) - insert_d/2]) >= 3 * extrusion_width - 1e-6, "insert boss outer wall under 3 perimeters");
assert(min([for (s = front_screws) abs(s[0]) - (m2 + hole_comp + 0.3)/2 - sqrt(pow(rt + rack_gap, 2) - pow(s[1], 2))]) >= 1.0, "cover web between screw hole and pen notch under 1 mm");
assert(rco < y_f, "collar neck must sit under the floor");
assert(W <= 27.5 && y_top - y_bot <= 39.5 && L <= 41, "pod grew past 27.5 x 39.5 x 41");
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
    hull() {   // clamp ear, right side, 45 deg underside
        box([rco - 1.5, rco], [-3, 3], [z_c, z_c + fudge]);
        box([rco - 1.5, rco + 5.5], [-ear_half, ear_half], [z_c + 5.5 + 1.5, z_c + collar_l]);
    }
    // snap ridges on the back posts (45 deg both sides)
    mirror_x() translate([0, 0, z_be - 5]) linear_extrude(4) polygon([[hxr - 0.2, detent_y - 1.0], [hxr + rack_gap + detent_h, detent_y - 0.1], [hxr + rack_gap + detent_h, detent_y + 0.1], [hxr - 0.2, detent_y + 1.0]]);
}
module front_face2d() union() { base_outline_lower(); intersection() { p_rack(); translate([-W, y_f - 0.5]) square([2*W, y_it - rack_gap - y_f + 0.5]); } }
module base_outline_lower() intersection() { base_outline(); translate([-W, y_bot - 1]) square([2*W, y_f - y_bot + 1]); }

module base() {
    ys = rco + 2.6;   // clamp screw x position
    zs = z_c + collar_l - 2.5;   // clamp screw height, above the ear chamfer
    difference() {
        base_raw();
        // pen bore, collar bore
        translate([0, 0, z_b - 1]) cylinder(r = rb, h = L);
        translate([0, 0, z_c - fudge]) cylinder(r = rc, h = collar_l + 1);
        // collar slit (right side) and clamp screw along Y: head up, nut down
        box([0, rco + 7], [-slit_w/2, slit_w/2], [z_c + slit_web, z_c + collar_l + 1]);
        translate([ys, 0, zs]) teardrop_hole(m2 + hole_comp + 0.3, 2*ear_half + 2, "y");
        translate([ys, slit_w/2 + 1.0 + ear_half/2, zs]) teardrop_hole(m2_head_d + hole_comp, ear_half + fudge, "y");
        translate([ys, -slit_w/2 - 1.0, zs]) rotate([90, 0, 0]) rotate([0, 0, 90]) cylinder(d = (nut_af + hole_comp + 0.1)/cos(30), h = ear_half, $fn = 6);
        // channels: IMU (left, open to the back), motor and switch (right, open to the side)
        box(imu_x, imu_y, imu_z);
        translate([(mot_x[0] + mot_x[1])/2, mot_c[0], mot_c[1]]) teardrop_hole(md, mot_x[1] - mot_x[0], "x");
        box(sw_x, sw_y, sw_z);
        // wire slots from the channels up beside the battery
        box([-hx + 0.3, imu_x[0] + 2.1], [imu_y[1] - 2, y_f + fudge], [imu_z[0] + 2, imu_z[0] + 8]);   // 2 mm into the IMU channel
        box([post_x0, hx + 1], [mot_c[0] + md/2 - 2, y_f + fudge], [mot_c[1] - 3, mot_c[1] + 3]);
        box([post_x0, hx + 1], [sw_y[1] - 2, y_f + fudge], [sw_z[0] + 1, sw_z[0] + 5]);
        box([sw_x[0], hx + 1], [sw_y[1] - 2, sw_y[1] + 0.5], [mot_c[1], sw_z[0] + 2]);   // motor to switch run
        // notches in the ledges beside the boards: wire crossings between layers
        mirror_x() for (zr = [[z_b0 + 4, z_b0 + 9], [(z_b0 + z_bi)/2 + 3, (z_b0 + z_bi)/2 + 8]])
            for (yr = [[y_b1, y_m0], [y_m1, y_c0]]) box([M[0]/2 + 0.2, hx + 1], yr + [-fudge, fudge], zr);
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
        mub_y = y_c0 + clr + 1.0 + 1.2;
        translate([0, usb_y, L - wall - 1]) linear_extrude(wall + 2) offset(r = 1) square([usbc_hole[0] - 2, usbc_hole[1] - 2], center = true);
        translate([0, mub_y, L - wall - 1]) linear_extrude(wall + 2) offset(r = 0.6) square([microb_hole[0] - 1.2, microb_hole[1] - 1.2], center = true);
        // switch handle
        translate([hx - 0.5, (sw_y[0] + sw_y[1])/2 - sw_slot[1]/2, (sw_z[0] + sw_z[1])/2 - sw_slot[0]/2]) cube([wall + 2, sw_slot[1], sw_slot[0]]);
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
module d_chg()  box([-chg[0]/2, chg[0]/2], [y_c0 + clr, y_c0 + clr + chg[2]], [z_bi - clr - chg[1], z_bi - clr]);
module d_drv()  box([-drv[1]/2, drv[1]/2], [y_f + clr, y_f + clr + drv[0]], [z_d[0] + clr, z_d[0] + clr + drv[2]]);
module d_imu()  box(imu_x + [clr, -clr], [imu_y[0] + clr, imu_y[0] + clr + imu[0]], [imu_z[0] + clr, imu_z[0] + clr + imu[1]]);
module d_mot()  translate([mot_x[0] + clr, mot_c[0], mot_c[1]]) rotate([0, 90, 0]) cylinder(d = mot[0], h = mot[1]);
module d_sw()   box([sw_x[0] + clr, sw_x[0] + clr + sw[2]], [sw_y[0] + clr, sw_y[0] + clr + sw[1]], [sw_z[0] + clr, sw_z[0] + clr + sw[0]]);
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
if (part == "clash_side_sw")     intersection() { base(); sweep([20, 0, 0]) d_sw(); }
