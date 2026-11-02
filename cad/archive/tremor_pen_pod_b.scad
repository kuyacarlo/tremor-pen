// Tremor Cue Pen - pen pod B (base + cover)
//
// A rounded box that sits on top of the pen. The BASE clamps to the pen
// and carries every part: battery on the floor, ESP32-S3 and TP4056 on
// ledges above it, DRV8833 standing behind the front bulkhead, IMU, motor
// and switch in the two channels beside the pen. The COVER drops over the
// base and is held by two M2 screws in the front face. Both USB ports
// face the back of the pen. Unscrew two screws, lift the cover, and every
// part is in reach.
//
// Axes: z runs along the pen (z = 0 is the front, toward the tip),
// y points up away from the pen, x is across. Pen axis is the z axis.
// Part sizes are bare measurements; allowances are added below.

part = "assembly"; // [assembly, exploded, base, cover, dummies, print_plate]

$fn = 64;

// ---------------- body ----------------
W         = 26.6;   // outside width
wall      = 1.2;    // cover side and end walls
top_wall  = 1.4;
r_top     = 3.0;    // top edge rounding
r_bot     = 2.5;    // bottom edge rounding
y_bot     = -8.5;   // underside (pen axis = 0)
y_seam    = -5.0;   // cover side walls stop here and sit on the base

pen_d     = 10.8;
pen_clr   = 0.4;    // bore clearance (the collar does the clamping)
tube_wall = 1.0;
floor_t   = 1.0;
bh_t      = 2.0;    // front bulkhead
ledge_t   = 1.0;    // board ledges
ledge_lip = 1.5;    // how far a ledge reaches under a board edge
top_gap   = 0.6;    // above the top board

// ---------------- allowances ----------------
clr_xy = 0.3;       // per side, width and length
clr_t  = 0.25;      // per side, thickness

// ---------------- hardware ----------------
insert_d = 3.2;  insert_l = 4.5;     // M2 heat-set insert hole
m2_clear = 2.4;  m2_head = 4.2;
nut_af   = 4.2;
front_screws = [[-9.5, 0], [9.5, 0]];
collar_l = 8;  collar_wall = 2.0;  ear_half = 4.5;  // collar uses M2 x 6 + nut

// ---------------- parts [width, length, thickness] ----------------
batt = [19.8, 30.5, 8.7];   // FL902030 560 mAh, lies flat on the floor
mcu  = [17.8, 24.9, 4.3];   // ESP32-S3 SuperMini incl. USB-C, USB toward the back
chg  = [17.1, 28.6, 3.4];   // TP4056 incl. micro-B, USB toward the back, on top
drv  = [15.5, 18.6, 3.2];   // DRV8833, stands upright behind the front bulkhead
imu  = [12.9, 18.4, 2.3];   // stands upright in the left channel
mot  = [9.9, 3.2];          // 1027 coin motor [diameter, thickness], right channel
sw   = [10.4, 5.7, 5.0];    // slide switch [length, height, body depth], right channel
sw_slot = [7.0, 2.8];       // handle opening [along, height]

// ---------------- cover openings ----------------
usbc_hole   = [9.8, 3.8];
microb_hole = [8.6, 3.4];
led_d   = 2.0;
led_x   = [-3.5, 0, 3.5];   // measure your TP4056 LEDs and move these
led_dz  = 9;                // LED row distance from the back wall
vent    = [9.0, 1.2];       // vent slot [across, along]
vent_dz = [15, 17.5, 20, 22.5];  // vent slots above the TP4056 chip, from the back wall

// ---------------- derived ----------------
function fit(p) = [p[0] + 2*clr_xy, p[1] + 2*clr_xy, p[2] + 2*clr_t];
B = fit(batt); M = fit(mcu); C = fit(chg); D = fit(drv); I = fit(imu); S = fit(sw);
md = mot[0] + 2*clr_xy;  mt = mot[1] + 2*clr_t;

hx = W/2 - wall;                 // inner half width
rb = (pen_d + pen_clr)/2;
rt = rb + tube_wall;

// layers above the pen
y_f  = rt + floor_t;             // floor top
y_b1 = y_f + B[2];               // battery top
y_m0 = y_b1 + ledge_t;  y_m1 = y_m0 + M[2];
y_c0 = y_m1 + ledge_t;  y_c1 = y_c0 + C[2];
y_it = y_c1 + top_gap;           // cover inside top
y_top = y_it + top_wall;
H = y_top - y_bot;

// along the pen
z_bh = [wall, wall + bh_t];
z_d  = [z_bh[1], z_bh[1] + D[2]];
z_b0 = z_d[1] + 0.3;             // battery and boards start
z_bi = z_b0 + B[1];              // inside face of the back wall
L    = z_bi + wall;

// channels beside the pen
imu_x = [-(rt + 1.1) - I[2], -(rt + 1.1)];
imu_y = [y_f - floor_t - I[0], y_f - floor_t];
imu_z = [10, 10 + I[1]];
mot_x = [hx - mt, hx];
mot_c = [0, 6.0 + md/2];         // [y, z] centre
sw_x  = [hx - S[2], hx];
sw_y  = [-4.6, -4.6 + S[1]];
sw_z  = [z_bi - 1 - S[0], z_bi - 1];

// ---------------- fit checks ----------------
assert(B[0]/2 < hx - 1.6, "battery too wide for the posts");
assert(M[0]/2 < hx && C[0]/2 < hx && D[0]/2 < hx, "board wider than the box");
assert(C[1] <= B[1] && M[1] <= B[1], "board longer than the battery bay");
assert(D[1] <= y_it - y_f, "DRV8833 too tall to stand up");
assert(imu_y[0] - y_bot >= 1.2, "IMU channel too deep");
assert(-imu_x[1] > rt, "IMU hits the pen tube");
assert(sw_x[0] > rt, "switch hits the pen tube");
assert(sw_y[0] > y_seam, "switch below the cover seam");
assert(mot_c[1] + md/2 < sw_z[0], "motor and switch overlap");
assert(mot_c[1] - md/2 > front_screws[0][0]*0 + z_bh[0] + insert_l, "motor hits the front inserts");
echo(str("Pod B: ", W, " wide x ", H, " tall x ", L, " long (", L + collar_l, " with collar)"));

// ---------------- 2D profiles ----------------
module p_out() {
    hull() {
        translate([-W/2 + r_top, y_top - r_top]) circle(r_top);
        translate([ W/2 - r_top, y_top - r_top]) circle(r_top);
        translate([-W/2 + r_bot, y_bot + r_bot]) circle(r_bot);
        translate([ W/2 - r_bot, y_bot + r_bot]) circle(r_bot);
    }
}
module p_in() offset(delta = -wall) p_out();
module notch2d() {
    n = rt + 0.2;
    translate([-n, y_bot - 1]) square([2*n, -y_bot + 1]);
    circle(n);
}

module box(xr, yr, zr) translate([xr[0], yr[0], zr[0]]) cube([xr[1]-xr[0], yr[1]-yr[0], zr[1]-zr[0]]);
module mirror_x() { children(); mirror([1, 0, 0]) children(); }

// ---------------- base ----------------
module base_solid() {
    // lower block: full outside width under the seam, inside width above it, up to the floor top
    translate([0, 0, z_bh[0]]) linear_extrude(z_bi - z_bh[0]) {
        intersection() { p_out(); translate([-W, y_bot - 1]) square([2*W, y_seam - y_bot + 1]); }
        intersection() { p_in();  translate([-W, y_seam]) square([2*W, y_f - y_seam]); }
    }
    // front bulkhead
    translate([0, 0, z_bh[0]]) linear_extrude(bh_t) intersection() { p_in(); translate([-W, y_f - 0.1]) square([2*W, y_it - y_f + 0.1]); }
    // rack: posts beside the battery, ledges under board edges, locators at the back
    intersection() {
        translate([0, 0, -1]) linear_extrude(L + 2) p_in();
        mirror_x() union() {
            for (zp = [[z_b0, z_b0 + 2], [(z_b0 + z_bi)/2 - 1, (z_b0 + z_bi)/2 + 1], [z_bi - 6, z_bi]])
                box([B[0]/2 + 0.1, hx + 0.01], [y_f - 0.1, y_it], zp);
            box([M[0]/2 - ledge_lip, hx + 0.01], [y_b1, y_m0], [z_b0, z_bi]);
            box([C[0]/2 - ledge_lip, hx + 0.01], [y_m1, y_c0], [z_b0, z_bi]);
            box([M[0]/2, hx + 0.01], [y_m0 - 0.01, y_m1 + 0.01], [z_bi - 6, z_bi]);
            box([C[0]/2, hx + 0.01], [y_c0 - 0.01, y_c1], [z_bi - 6, z_bi]);
        }
    }
    // pen tube and collar
    translate([0, 0, z_bh[0]]) cylinder(r = rt, h = L - z_bh[0]);
    rco = (pen_d + 0.2)/2 + collar_wall;
    translate([0, 0, L - 0.01]) cylinder(r = rco, h = collar_l);
    box([-ear_half, ear_half], [rco - 1.5, rco + 6], [L - 0.01, L + collar_l]);
}

module base() {
    rc  = (pen_d + 0.2)/2;
    rco = rc + collar_wall;
    ys  = rco + 2.6;                 // collar screw height
    difference() {
        base_solid();
        // pen bore, snug in the collar
        translate([0, 0, -1]) cylinder(r = rb, h = L + 1);
        translate([0, 0, L - 1]) cylinder(r = rc, h = collar_l + 2);
        // collar slit, clamp screw, head and nut
        box([-0.6, 0.6], [0, rco + 7], [L + 0.5, L + collar_l + 1]);
        translate([0, ys, L + collar_l/2]) rotate([0, 90, 0]) cylinder(d = m2_clear, h = 2*ear_half + 2, center = true);
        translate([2.0, ys, L + collar_l/2]) rotate([0, 90, 0]) cylinder(d = m2_head, h = ear_half);
        translate([-2.0 - ear_half, ys, L + collar_l/2]) rotate([0, 90, 0]) rotate([0, 0, 30]) cylinder(d = nut_af/cos(30), h = ear_half, $fn = 6);
        // IMU channel (left), motor and switch channel (right)
        box(imu_x, imu_y, imu_z);
        translate([mot_x[0], mot_c[0], mot_c[1]]) rotate([0, 90, 0]) cylinder(d = md, h = mt + 1);
        box(sw_x + [0, 1], sw_y, sw_z);
        // wire slots from the channels up into the rack
        box([-hx - 1, -B[0]/2 - 0.1], [imu_y[1] - 1.5, y_f + 0.1], [imu_z[0] + 2, imu_z[0] + 8]);
        box([B[0]/2 + 0.1, hx + 1],  [mot_c[0] + md/2 - 0.5, y_f + 0.1], [mot_c[1] - 3, mot_c[1] + 3]);
        box([B[0]/2 + 0.1, hx + 1],  [sw_y[1] - 0.5, y_f + 0.1], [sw_z[0] + 1, sw_z[0] + 5]);
        box([sw_x[0], sw_x[1]], [sw_y[1] - 0.5, mot_c[0] + md/2], [mot_c[1], sw_z[0] + 1]);   // motor to switch run
        // front screw inserts
        for (s = front_screws) translate([s[0], s[1], z_bh[0] - 0.01]) cylinder(d = insert_d, h = insert_l);
    }
}

// ---------------- cover ----------------
module cover() {
    difference() {
        linear_extrude(L) p_out();
        translate([0, 0, wall]) linear_extrude(L - 2*wall) p_in();
        box([-W, W], [y_bot - 1, y_seam], [wall, L - wall]);              // open below the seam
        for (z = [-1, L - wall - 1]) translate([0, 0, z]) linear_extrude(wall + 2) notch2d();
        // front screws
        for (s = front_screws) translate([s[0], s[1], -1]) cylinder(d = m2_clear, h = wall + 2);
        // back: USB-C (MCU) and micro-B (TP4056)
        usb_y  = y_m0 + clr_t + 1.0 + 1.6;
        mub_y  = y_c0 + clr_t + 1.0 + 1.2;
        translate([0, usb_y, L - wall - 1]) linear_extrude(wall + 2) offset(r = 1) square([usbc_hole[0] - 2, usbc_hole[1] - 2], center = true);
        translate([0, mub_y, L - wall - 1]) linear_extrude(wall + 2) offset(r = 0.6) square([microb_hole[0] - 1.2, microb_hole[1] - 1.2], center = true);
        // switch handle
        translate([hx - 0.5, (sw_y[0] + sw_y[1])/2 - sw_slot[1]/2, (sw_z[0] + sw_z[1])/2 - sw_slot[0]/2]) cube([wall + 2, sw_slot[1], sw_slot[0]]);
        // top: LED windows and vents over the TP4056
        for (x = led_x) translate([x, y_it - 1, z_bi - led_dz]) rotate([-90, 0, 0]) cylinder(d = led_d, h = top_wall + 2);
        for (dz = vent_dz) translate([-vent[0]/2, y_it - 1, z_bi - dz - vent[1]/2]) cube([vent[0], top_wall + 2, vent[1]]);
    }
}

// ---------------- dummies ----------------
module dummies() {
    color("dimgray")   box([-batt[0]/2, batt[0]/2], [y_f + clr_t, y_f + clr_t + batt[2]], [z_b0 + clr_xy, z_b0 + clr_xy + batt[1]]);
    color("royalblue") box([-mcu[0]/2, mcu[0]/2], [y_m0 + clr_t, y_m0 + clr_t + mcu[2]], [z_bi - clr_xy - mcu[1], z_bi - clr_xy]);
    color("seagreen")  box([-chg[0]/2, chg[0]/2], [y_c0 + clr_t, y_c0 + clr_t + chg[2]], [z_bi - clr_xy - chg[1], z_bi - clr_xy]);
    color("crimson")   box([-drv[1]/2, drv[1]/2], [y_f + clr_xy, y_f + clr_xy + drv[0]], [z_d[0] + clr_t, z_d[0] + clr_t + drv[2]]);
    color("purple")    box(imu_x + [clr_t, -clr_t], [imu_y[0] + clr_xy, imu_y[0] + clr_xy + imu[0]], [imu_z[0] + clr_xy, imu_z[0] + clr_xy + imu[1]]);
    color("silver")    translate([mot_x[0] + clr_t, mot_c[0], mot_c[1]]) rotate([0, 90, 0]) cylinder(d = mot[0], h = mot[1]);
    color("orange")    box([sw_x[0] + clr_t, sw_x[0] + clr_t + sw[2]], [sw_y[0] + clr_xy, sw_y[0] + clr_xy + sw[1]], [sw_z[0] + clr_xy, sw_z[0] + clr_xy + sw[0]]);
    color("khaki", 0.5) translate([0, 0, -40]) cylinder(d = pen_d, h = L + 80);
}

// ---------------- output ----------------
if (part == "assembly") { color("lightslategray") base(); color("lightsteelblue", 0.35) cover(); dummies(); }
else if (part == "exploded") { color("lightslategray") base(); color("lightsteelblue") translate([0, 35, 0]) cover(); dummies(); }
else if (part == "base") base();
else if (part == "cover") cover();
else if (part == "dummies") dummies();
else if (part == "print_plate") {
    // base stands on its front face; cover prints upside down on its top
    translate([0, 0, -z_bh[0]]) base();
    translate([45, 0, y_top]) rotate([-90, 0, 0]) cover();
}
