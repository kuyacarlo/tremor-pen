include <model.scad>
step = 1;
$fn = 40;
module arrow(p, v, len = 14) {   // thicker for visibility   // v: unit direction the part moves (toward its seat)
    color("orangered") translate(p) {
        a = v[1] != 0 ? [ -90 * v[1], 0, 0] : (v[0] != 0 ? [0, 90 * v[0], 0] : (v[2] < 0 ? [180, 0, 0] : [0, 0, 0]));
        rotate(a) { translate([0, 0, -len]) cylinder(d = 2.2, h = len - 4); translate([0, 0, -4]) cylinder(d1 = 5.5, d2 = 0, h = 4); }
    }
}
module inserts(off = 0) for (s = front_screws) color("goldenrod") translate([s[0], s[1], z_b - 3.5 - off]) cylinder(d = 3.2, h = 3.5);
module nut(off = 0) color("silver") translate([rco + 2.6, -2.4 - off, z_c + collar_l - 2.5]) rotate([90, 0, 0]) rotate([0, 0, 90]) cylinder(d = 4.6, h = 1.6, $fn = 6);
module scr(off = 0) color("dimgray") translate([rco + 2.6, 4.5 + off, z_c + collar_l - 2.5]) rotate([-90, 0, 0]) { cylinder(d = 2, h = 6); translate([0, 0, 6]) cylinder(d = 3.8, h = 1.6); }
B_ = 14;   // how far parts are pulled out
rotate([90, 0, 0]) {
    color("gainsboro") base();
    if (step == 1) { inserts(10); arrow([front_screws[0][0], front_screws[0][1], -1], [0, 0, 1], 9); arrow([front_screws[1][0], front_screws[1][1], -1], [0, 0, 1], 9);
                     }
    if (step >= 2) { inserts(); }
    if (step == 2) {
        color("purple") translate([0, 0, 24]) d_imu();   arrow([-9.1, 0, L + 3], [0, 0, -1], 10);
        color("silver") translate([B_, 0, 0]) d_mot();   arrow([hx + 3, 0.5, mot_c[1]], [-1, 0, 0], 10);
        color("orange") translate([B_, 0, 0]) d_sw();    arrow([hx + 3, sw_yc, (sw_body_z[0] + sw_body_z[1]) / 2], [-1, 0, 0], 10);
    }
    if (step >= 3) { color("purple") d_imu(); color("silver") d_mot(); color("orange") d_sw(); }
    if (step == 3) { color("crimson") translate([0, 14, 0]) d_drv(); arrow([12, y_top + 6, z_d[0] + 2], [0, -1, 0], 10); }
    if (step >= 4) color("crimson") d_drv();
    if (step == 4) { color("dimgray") translate([0, 0, 22]) d_batt(); arrow([-14, (y_f + y_b1) / 2, L + 10], [0, 0, -1], 12); }
    if (step >= 5) color("dimgray") d_batt();
    if (step == 5) { color("royalblue") translate([0, 0, 16]) d_mcu(); color("seagreen") translate([0, 0, 28]) d_chg();
                     arrow([-14, (y_m0 + y_m1) / 2, L + 10], [0, 0, -1], 12); arrow([-14, (y_c0 + y_c1) / 2, L + 22], [0, 0, -1], 12); }
    if (step >= 6) { color("royalblue") d_mcu(); color("seagreen") d_chg(); }
    if (step == 6) { color("lightsteelblue", 0.85) translate([0, 42, 0]) cover(); arrow([-17, y_top + 22, L / 2], [0, -1, 0], 14); arrow([17, y_top + 22, L / 2], [0, -1, 0], 14);
                     for (s = front_screws) color("dimgray") translate([s[0], s[1], -12]) { cylinder(d = 2, h = 5); translate([0, 0, -1.6]) cylinder(d = 3.8, h = 1.6); } }
    if (step == 7) { color("lightsteelblue") cover(); color("khaki") translate([0, 0, -45]) cylinder(d = pen_d, h = L + 110); }
}
