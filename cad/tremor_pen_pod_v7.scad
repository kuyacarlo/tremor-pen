// Tremor Cue Pen - POD v7 (tall, not wide) - built from the photos
// Cross-section (looking from the back cap):
//      +---------------------------------+
//      |  MCU stack (NodeMCU + IMU + vib) |   top pocket, lying flat, USB at the back
//      +==========shelf=========+  gap  -+   shelf gap at the back = battery wires
//      | (pen)  |  battery pack on edge  |   TP4056 faces the pen, battery faces the right wall
//      +--------+------------------------+   switch handle pokes out a window in the right wall
// Both packs slide in from the BACK; back cap: a 6.8 mm deep sleeve over the protruding board ends,
// USB slot per pack, 2 x M2 self-tapping screws on the diagonal (bottom-left, top-right).
// Print: base standing on its FRONT face (pen axis vertical), cap flat, as exported. Supports OFF.
// PLA, 0.2 mm layers, 3 walls, 15% infill, 4 mm brim on the base.

part = "base";   // "base", "cap", "plate", "view", "clash_parts"

// measured packs [across (x), up (z), along the pen (y)]
mcu  = [30.5, 13.0, 59.3];        // NodeMCU flat, IMU + vibration module on top
batt = [13.9, 19.6, 30.8];        // battery pack on edge: TP4056 face toward the pen
clr  = 0.8;                       // per side

hole_comp = 0.30;  bore_free = 0.30;  pen_d = 10.8;     // bore that fit the Panda + rubber on v5
rb = (pen_d + hole_comp + bore_free) / 2;               // 5.7
rt = rb + 1.2;                                           // pen tube outer radius
wall = 1.6;  wall_top = 4.2;  front_t = 2.0;  cap_t = 2.4;  shelf_t = 1.2;   // thicker top wall carries a screw
r_out = 4.0;  r_pkt = r_out - wall;

// layout, pen axis at x = z = 0
bx = [rt, rt + batt[0] + 2*clr];                         // battery pocket x
bz = [-(batt[1] + 2*clr)/2, (batt[1] + 2*clr)/2];        // battery pocket z (pen centered on it)
mx = [bx[1] - (mcu[0] + 2*clr), bx[1]];                  // MCU pocket x (flush with the right side)
mz = [bz[1] + shelf_t, bz[1] + shelf_t + mcu[1] + 2*clr];
OX = [min(mx[0], -rt) - wall, bx[1] + wall];
OZ = [bz[0] - wall, mz[1] + wall_top];
pocket_L = mcu[2] + 2*clr + 0.6;
y_back = front_t + pocket_L;
gap_y0 = 25;                                             // shelf over the battery ends here: wires pass behind it
sc_in = [4.2, 2.1];                                     // screw inset from the corner [sideways, up/down]
screws = [[OX[0] + sc_in[0], OZ[0] + sc_in[1]], [OX[1] - sc_in[0], OZ[1] - sc_in[1]]];   // diagonal pair: bottom-left + top-right
pilot = 1.7;  m2_clear = 2.4;
usb_mcu = [12, 9];   usb_mcu_c = [(mx[0] + mx[1]) / 2, mz[1] - clr - 3.9];    // NodeMCU micro-USB: board at the TOP, USB just under it (photo)
usb_chg = [8, 12];   usb_chg_c = [bx[1] - 3.0, 0];                             // TP4056 micro-USB: faces the RIGHT wall (photo)
batt_front = y_back - clr - batt[2];                     // pack pushed to the back cap
sw_win = [11, 15];                                       // right-wall window for the switch [along y, z]
fudge = 0.01;  $fn = 64;

assert(mx[0] < -rt + 3, "MCU pocket does not cover the pen side");
assert(norm(screws[0]) > rt + pilot/2 + 1.0, "bottom screw breaks into the pen tube");
assert(screws[0][0] + pilot/2 + 1.0 <= mx[0] || screws[0][1] + pilot/2 + 1.0 <= bz[1], "bottom screw hits a pocket");
assert(screws[1][1] - pilot/2 - 1.0 >= mz[1], "top screw breaks into the MCU pocket");
assert(sc_in[1] - pilot/2 >= 1.2, "screws too close to the outer skin");

module box(xr, yr, zr) translate([xr[0], yr[0], zr[0]]) cube([xr[1]-xr[0], yr[1]-yr[0], zr[1]-zr[0]]);
module along_y(r, y0, y1) translate([0, y0, 0]) rotate([-90, 0, 0]) cylinder(r = r, h = y1 - y0);
module rbox(xr, yr, zr, r) translate([0, yr[0], 0]) rotate([-90, 0, 0]) linear_extrude(yr[1] - yr[0])
    translate([xr[0], -zr[1]]) offset(r = r) offset(delta = -r) square([xr[1] - xr[0], zr[1] - zr[0]]);
module rslot(c, sz, y0, y1) rbox([c[0] - sz[0]/2, c[0] + sz[0]/2], [y0, y1], [c[1] - sz[1]/2, c[1] + sz[1]/2], min(sz)/2 - fudge);

module base() difference() {
    rbox(OX, [0, y_back], OZ, r_out);
    rbox(mx, [front_t, y_back + 1], mz, r_pkt);                                     // MCU pocket
    rbox(bx, [front_t, y_back + 1], bz, r_pkt);                                     // battery pocket
    box([bx[0] + 1.5, bx[1] - 1.5], [gap_y0, y_back + 1], [bz[1] - 1, mz[0] + 1]);  // shelf gap: battery wires
    along_y(rb, -1, y_back + 1);                                                    // pen bore
    translate([0, -fudge, 0]) rotate([-90, 0, 0]) cylinder(r1 = rb + 0.5, r2 = rb, h = 0.5);
    for (s = screws) translate([s[0], y_back - 10, s[1]]) rotate([-90, 0, 0]) cylinder(d = pilot, h = 11);
    // switch window in the right wall, around the pack's front end
    rbox([bx[1] - 1, OX[1] + 1], [batt_front - 4, batt_front - 4 + sw_win[0]], [-sw_win[1]/2, sw_win[1]/2], 0.5);
}

// cap: a hollow sleeve that continues the base outline over the 6.6 mm the boards stick out
// of the back, then an end plate with the USB slots. Screws pass the full cap length.
skirt = 6.8;                                             // packs protrude 6.6 mm; 0.2 mm slack
cap_L = skirt + cap_t;
module cap() difference() {
    rbox(OX, [0, cap_L], OZ, r_out);
    rbox(mx, [-1, skirt], mz, r_pkt);                                              // continues the MCU pocket
    rbox(bx, [-1, skirt], bz, r_pkt);                                              // continues the battery pocket
    box([bx[0] + 1.5, bx[1] - 1.5], [-1, skirt], [bz[1] - 1, mz[0] + 1]);          // wires between the packs
    along_y(rb, -1, cap_L + 1);
    for (s = screws) translate([s[0], -1, s[1]]) rotate([-90, 0, 0]) {
        cylinder(d = m2_clear, h = cap_L + 2);
        translate([0, 0, cap_L + 1 - 1.2]) cylinder(d1 = m2_clear, d2 = 4.6, h = 1.2 + fudge);   // countersink, outer face
    }
    rslot(usb_mcu_c, usb_mcu, skirt - 1, cap_L + 1);
    rslot(usb_chg_c, usb_chg, skirt - 1, cap_L + 1);
}

module dummies() {
    color("royalblue")  box([mx[0] + clr, mx[1] - clr], [front_t + clr, front_t + clr + mcu[2]], [mz[0] + clr, mz[0] + clr + mcu[1]]);
    color("darkorange") box([bx[0] + clr, bx[1] - clr], [batt_front, y_back - clr], [bz[0] + clr, bz[1] - clr]);
}

module base_print() rotate([90, 0, 0]) base();                       // front face on the bed
module cap_print()  translate([0, 0, cap_L]) rotate([-90, 0, 0]) cap();   // outer face on the bed, sleeve up

if (part == "base")  base_print();
if (part == "cap")   cap_print();
if (part == "plate") { base_print(); translate([OX[1] - OX[0] + 8, 0, 0]) cap_print(); }
if (part == "view")  { color("seagreen") base(); dummies(); color("lightsteelblue", 0.5) translate([0, y_back + 0.3, 0]) cap();
                       color("gray", 0.4) along_y(pen_d/2, -40, y_back + 60); }
if (part == "clash_parts") intersection() { base(); dummies(); }
echo(str("Pod v7: ", OX[1] - OX[0], " W x ", OZ[1] - OZ[0], " H x ", y_back + cap_t, " L mm; pen axis ", -OX[0], " mm from the left, ", -OZ[0], " mm from the bottom"));
