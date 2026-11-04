// Tremor Cue Pen - POD v6 (saddlebags, roomy)
// Cross-section (looking down the pen):   [ section 1 ] ( pen ) [ section 2 ]
//   section 1 = NodeMCU + wires/foam + IMU + vibration module stack (13 x 30.5 x 59.3), standing on edge
//   section 2 = battery + TP4056 + switch (13.9 x 19.6 x 30.8), standing on edge (either way up)
// Both pockets slide in from the BACK; a closed back cap (USB slot per pocket + switch slot)
// holds them in with 2 x M2 self-tapping screws. A channel behind the pen joins the pockets for the
// battery-to-MCU wires (<= 36 mm).
// Print: base standing on its FRONT face (pen axis vertical), cap flat, as exported. Supports OFF.
// PLA, 0.2 mm layers, 3 walls, 15% infill, 4 mm brim on the base.

part = "base";   // "base", "cap", "plate", "view", "clash_parts"

// measured packs: [thickness (across the pen), height, length (along the pen)]
s1 = [13.0, 30.5, 59.3];
s2 = [13.9, 19.6, 30.8];          // battery pack lying lengthwise so the TP4056 USB faces the back cap
clr = 1.0;                         // per side: roomy, foam tape takes up the slack

hole_comp = 0.30;  bore_free = 0.30;  pen_d = 10.8;     // same bore that fit the Panda + rubber on v5
rb = (pen_d + hole_comp + bore_free) / 2;               // 5.7
tube = 1.2;  rt = rb + tube;                             // 6.9
wall = 1.6;  front_t = 2.0;  cap_t = 2.4;
pocket_h = max(s1[1], s2[1]) + 2*clr;                    // 32.8
pocket_L = s1[2] + 2*clr + 0.7;                          // 62
p1x = [-rt - s1[0] - 2*clr, -rt];                        // section 1 pocket, x
p2x = [rt, rt + s2[0] + 2*clr];                          // section 2 pocket, x
OX = [p1x[0] - wall, p2x[1] + wall];
OZ = [-pocket_h/2 - wall, pocket_h/2 + wall];
y_back = front_t + pocket_L;
// wire channel behind the pen, above it, joining the pockets (last 12 mm, open to the back)
ch_z = [rt + 0.4, rt + 4.6];  ch_L = 12;
screw_z = [ (ch_z[1] + OZ[1]) / 2, -(ch_z[1] + OZ[1]) / 2 ];
pilot = 1.7;  m2_clear = 2.4;  lip = 2.0;
fudge = 0.01;  $fn = 64;

assert(OZ[1] - ch_z[1] >= 4.5, "no room for the top screw above the wire channel");
assert(-2 + usb[1]/2 + 1.2 <= sw_z - sw_slot[1]/2, "USB and switch slots merge");
assert(s2[2] <= pocket_L && s2[1] <= pocket_L, "battery pack does not fit either way");

module box(xr, yr, zr) translate([xr[0], yr[0], zr[0]]) cube([xr[1]-xr[0], yr[1]-yr[0], zr[1]-zr[0]]);
module along_y(r, y0, y1) translate([0, y0, 0]) rotate([-90, 0, 0]) cylinder(r = r, h = y1 - y0);

r_out = 4.5;  r_pkt = r_out - wall;                    // rounded long edges; pockets follow with the same wall
usb = [11, 13];                                          // cap slot for a micro-USB plug, [across, tall]
sw_slot = [4.5, 9];  sw_z = pocket_h/2 - 1 - sw_slot[1]/2;   // switch handle slot, top of section 2
// rounded prism along y: 2D (x, -z) extruded from y0 to y1
module rbox(xr, yr, zr, r) translate([0, yr[0], 0]) rotate([-90, 0, 0]) linear_extrude(yr[1] - yr[0])
    translate([xr[0], -zr[1]]) offset(r = r) offset(delta = -r) square([xr[1] - xr[0], zr[1] - zr[0]]);
module rslot(xc, zc, sz, y0, y1) rbox([xc - sz[0]/2, xc + sz[0]/2], [y0, y1], [zc - sz[1]/2, zc + sz[1]/2], min(sz) / 2 - fudge);

module base() difference() {
    rbox(OX, [0, y_back], OZ, r_out);
    rbox(p1x, [front_t, y_back + 1], [-pocket_h/2, pocket_h/2], r_pkt);
    rbox(p2x, [front_t, y_back + 1], [-pocket_h/2, pocket_h/2], r_pkt);
    along_y(rb, -1, y_back + 1);                                                    // pen bore
    translate([0, -fudge, 0]) rotate([-90, 0, 0]) cylinder(r1 = rb + 0.5, r2 = rb, h = 0.5);   // elephant-foot lead-in
    box([p1x[1] - 1, p2x[0] + 1], [y_back - ch_L, y_back + 1], ch_z);              // wire channel
    for (z = screw_z) translate([0, y_back - 10, z]) rotate([-90, 0, 0]) cylinder(d = pilot, h = 11);
}

// closed cap: only a USB slot per pocket + the switch slot
module cap() difference() {
    rbox(OX, [0, cap_t], OZ, r_out);
    along_y(rb, -1, cap_t + 1);
    for (z = screw_z) translate([0, -1, z]) rotate([-90, 0, 0]) {
        cylinder(d = m2_clear, h = cap_t + 2);
        translate([0, 0, cap_t + 1 - 1.0]) cylinder(d1 = m2_clear, d2 = 4.4, h = 1.0 + fudge);   // countersink, outer face
    }
    rslot((p1x[0] + p1x[1]) / 2, 0, usb, -1, cap_t + 1);          // NodeMCU USB (center of section 1)
    rslot((p2x[0] + p2x[1]) / 2, -2, usb, -1, cap_t + 1);         // TP4056 USB (just below center of section 2)
    rslot((p2x[0] + p2x[1]) / 2, sw_z, sw_slot, -1, cap_t + 1);   // switch handle (top of section 2)
}

module dummies() {
    color("royalblue")  box([p1x[0] + clr, p1x[0] + clr + s1[0]], [front_t + clr, front_t + clr + s1[2]], [-s1[1]/2, s1[1]/2]);
    color("darkorange") box([p2x[0] + clr, p2x[0] + clr + s2[0]], [y_back - clr - s2[2], y_back - clr], [-s2[1]/2, s2[1]/2]);
}

module base_print() rotate([90, 0, 0]) base();   // front face on the bed, pen axis vertical
module cap_print()  rotate([90, 0, 0]) cap();    // inner face on the bed

if (part == "base")  base_print();
if (part == "cap")   cap_print();
if (part == "plate") { base_print(); translate([OX[1] - OX[0] + 8, 0, 0]) cap_print(); }
if (part == "view")  { color("seagreen") base(); dummies(); color("lightsteelblue", 0.5) translate([0, y_back + 0.3, 0]) cap();
                       color("gray", 0.4) along_y(pen_d/2, -40, y_back + 60); }
if (part == "clash_parts") intersection() { base(); dummies(); }
echo(str("Pod v6: ", OX[1] - OX[0], " W x ", OZ[1] - OZ[0], " H x ", y_back + cap_t, " L mm"));
