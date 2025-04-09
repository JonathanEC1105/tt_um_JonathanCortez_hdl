`default_nettype none


module tt_um_jonathancortez_prbs31(
input wire [7 : 0] ui_in,
output wire [7 : 0] uo_out,
input wire [7 : 0] uio_in,
output wire [7 : 0] uio_out,
output wire [7 : 0] uio_oe,
input wire ena,
input wire clk,
input wire rst_n
);


// VGA signals
wire hsync;
wire vsync;
wire [1 : 0] R;
wire [1 : 0] G;
wire [1 : 0] B;
wire video_active;
wire [9 : 0] pix_x;
wire [9 : 0] pix_y;


  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
assign uio_out = 0;
assign uio_oe = 0;
wire _unused_ok = & {ena, ui_in, uio_in};


hvsync_generator hvsync_gen(
.clk(clk),
.reset(~rst_n),
.hsync(hsync),
.vsync(vsync),
.display_on(video_active),
.hpos(pix_x),
.vpos(pix_y)
);


// Ball animation
reg [9 : 0] ball_x = 320;
reg [9 : 0] ball_y = 240;
reg [1 : 0] ball_dir_x = 1;
reg [1 : 0] ball_dir_y = 1;
reg [23 : 0] counter;
always @(posedge clk) begin
if (~rst_n) begin
counter <= 0;
ball_x <= 320;
ball_y <= 240;
ball_dir_x <= 1;
ball_dir_y <= 1;
end else begin
counter <= counter + 1;
if (counter == 24'd150000) begin
counter <= 0;
if (ball_dir_x)
ball_x <= ball_x + 1;
else
ball_x <= ball_x - 1;
if (ball_dir_y)
ball_y <= ball_y + 1;
else
ball_y <= ball_y - 1;


if (ball_x >= 640 - 100)
ball_dir_x <= 0;
if (ball_x <= 100)
ball_dir_x <= 1;
if (ball_y >= 480 - 100)
ball_dir_y <= 0;
if (ball_y <= 100)
ball_dir_y <= 1;
end
end
end


// Ball rendering
wire [9 : 0] center_x = ball_x;
wire [9 : 0] center_y = ball_y;
wire [9 : 0] radius = 100;
wire signed [10 : 0] dx = pix_x - center_x;
wire signed [10 : 0] dy = pix_y - center_y;
wire [20 : 0] distance_squared = dx * dx + dy * dy;
wire inside_ball = (distance_squared < radius * radius);


// Hollow inner circle
wire [9 : 0] inner_radius = (radius * 2) / 3;
wire [9 : 0] inner_hole_radius = inner_radius - 36;
wire inside_inner_circle =
(distance_squared < inner_radius * inner_radius) &&
(distance_squared > inner_hole_radius * inner_hole_radius);


// Original curved yellow line at the top
wire [9 : 0] curve_center_y = center_y - inner_radius + 15;
wire signed [20 : 0] curve_y = ((dx * dx) >> 7) + curve_center_y;
wire in_curve_original =
(pix_y >= curve_y - 2) && (pix_y <= curve_y + 2) &&
(distance_squared < (inner_radius * inner_radius)) && (pix_y < center_y);


// Horizontally reflected curved yellow line
wire signed [10 : 0] reflected_dx = -(pix_x - center_x);
wire signed [20 : 0] reflected_curve_y =
((reflected_dx * reflected_dx) >> 7) + curve_center_y;
wire in_curve_reflected =
(pix_y >= reflected_curve_y - 2) && (pix_y <= reflected_curve_y + 2) &&
(distance_squared < (inner_radius * inner_radius)) && (pix_y < center_y);


// 90-degree rotated version of the curve (positioned to the right and up)
wire [9 : 0] rotated_curve_center_x =
center_x + inner_radius - 15 - 25 + 4 + 4; // Shift right by another 4
wire signed [20 : 0] rotated_curve_x =
rotated_curve_center_x - ((dy * dy) >> 7) - 4; // Keep the upward shift
wire in_curve_rotated_orig =
(pix_x >= rotated_curve_x - 2 + 30) &&
(pix_x <= rotated_curve_x + 2 + 30) &&
(distance_squared < (inner_radius * inner_radius)) &&
(pix_x > center_x + 20); // Keep the right boundary


// Duplicated and vertically reflected rotated curve (positioned to the left and up)
wire [9 : 0] rotated_curve_center_x_reflected =
center_x - (inner_radius - 15 - 25 + 4 + 4); // Mirrored X center
wire signed [20 : 0] rotated_curve_x_reflected =
rotated_curve_center_x_reflected + ((dy * dy) >> 7) + 4; // Mirrored X calculation
wire in_curve_rotated_reflected =
(pix_x >= rotated_curve_x_reflected - 2 - 30) &&
(pix_x <= rotated_curve_x_reflected + 2 - 30) &&
(distance_squared < (inner_radius * inner_radius)) &&
(pix_x < center_x - 20); // Keep the left boundary


// New vertical left inner circle curve (shifted 2 pixels right)
wire [9 : 0] left_curve_x = center_x - inner_radius + 2 + 2 + 1; // Original left curve X + 1
wire in_left_inner_curve =
(pix_x >= left_curve_x) && (pix_x < left_curve_x + 4) && // 4 pixels thick
(pix_y >= center_y - 20) && (pix_y < center_y + 20) && // 40 pixels long
(distance_squared < inner_radius * inner_radius);


// Reflected vertical right inner circle curve (shifted 2 pixels left)
wire [9 : 0] right_curve_x = center_x + inner_radius - 2 - 4 - 2; // Mirrored X position, shifted left
wire in_right_inner_curve =
(pix_x >= right_curve_x) && (pix_x < right_curve_x + 4) && // 4 pixels thick
(pix_y >= center_y - 20) && (pix_y < center_y + 20) && // 40 pixels long
(distance_squared < inner_radius * inner_radius);


wire in_curve =
in_curve_original || in_curve_reflected || in_curve_rotated_orig ||
in_curve_rotated_reflected || in_left_inner_curve || in_right_inner_curve;


// Top centered vertical gray line
wire top_centered_vertical_gray_line =
(pix_x >= center_x - 1) && (pix_x < center_x + 1) && // 2 pixels wide
(distance_squared >= inner_radius * inner_radius) &&
(distance_squared < radius * radius) && (pix_y >= center_y - radius) &&
(pix_y <= center_y - inner_radius);


// Rotated top gray line (45 degrees clockwise about the center)
wire signed [10 : 0] rot_dx = pix_x - center_x;
wire signed [10 : 0] rot_dy = pix_y - center_y;
wire in_rotated_top_gray_line =
(rot_dx - rot_dy >= -2) && // Approximating rotation for a 2-pixel width line
(rot_dx - rot_dy < 2) &&
(distance_squared >= inner_radius * inner_radius) &&
(distance_squared < radius * radius) &&
(rot_dy < 0); // Only in the top half


// Reflected rotated top gray line (across vertical axis)
wire in_reflected_rotated_top_gray_line =
(-rot_dx - rot_dy >= -2) && // Reflected X coordinate
(-rot_dx - rot_dy < 2) &&
(distance_squared >= inner_radius * inner_radius) &&
(distance_squared < radius * radius) &&
(rot_dy < 0); // Only in the top half


// Reflected reflected rotated top gray line (across horizontal axis)
wire in_vertically_reflected_rotated_top_gray_line =
(-rot_dx + rot_dy >= -2) && // Reflected Y coordinate
(-rot_dx + rot_dy < 2) &&
(distance_squared >= inner_radius * inner_radius) &&
(distance_squared < radius * radius) &&
(rot_dy > 0); // Only in the bottom half


// Reflected vertically reflected rotated top gray line (across vertical axis)
wire in_reflected_vertically_reflected_rotated_top_gray_line =
(rot_dx + rot_dy >= -2) && // Reflected X coordinate
(rot_dx + rot_dy < 2) &&
(distance_squared >= inner_radius * inner_radius) &&
(distance_squared < radius * radius) &&
(rot_dy > 0); // Only in the bottom half


// Bottom centered vertical gray line (reflected)
wire bottom_centered_vertical_gray_line =
(pix_x >= center_x - 1) && (pix_x < center_x + 1) && // 2 pixels wide
(distance_squared >= inner_radius * inner_radius) &&
(distance_squared < radius * radius) && (pix_y <= center_y + radius) &&
(pix_y >= center_y + inner_radius);


// Left horizontal gray line
wire left_horizontal_gray_line =
(pix_y >= center_y - 1) && (pix_y < center_y + 1) && // 2 pixels thick
(distance_squared >= inner_radius * inner_radius) &&
(distance_squared < radius * radius) && (pix_x >= center_x - radius) &&
(pix_x <= center_x - inner_radius);


// Right horizontal gray line (reflected)
wire right_horizontal_gray_line =
(pix_y >= center_y - 1) && (pix_y < center_y + 1) && // 2 pixels thick
(distance_squared >= inner_radius * inner_radius) &&
(distance_squared < radius * radius) && (pix_x <= center_x + radius) &&
(pix_x >= center_x + inner_radius);


// Left-to-right gradient (Burgundy to Green)
wire [7 : 0] grad_pos =
((pix_x - (center_x - inner_radius)) * 255 / (inner_radius * 2));


// 4x4 Bayer dither matrix
wire [1 : 0] dither_x = pix_x[1 : 0];
wire [1 : 0] dither_y = pix_y[1 : 0];
reg [3 : 0] dither_threshold;
always @(*) begin
case ({dither_y, dither_x})
4'b00_00 : dither_threshold = 4'd0;
4'b00_01 : dither_threshold = 4'd8;
4'b00_10 : dither_threshold = 4'd2;
4'b00_11 : dither_threshold = 4'd10;
4'b01_00 : dither_threshold = 4'd12;
4'b01_01 : dither_threshold = 4'd4;
4'b01_10 : dither_threshold = 4'd14;
4'b01_11 : dither_threshold = 4'd6;
4'b10_00 : dither_threshold = 4'd3;
4'b10_01 : dither_threshold = 4'd11;
4'b10_10 : dither_threshold = 4'd1;
4'b10_11 : dither_threshold = 4'd9;
4'b11_00 : dither_threshold = 4'd15;
4'b11_01 : dither_threshold = 4'd7;
4'b11_10 : dither_threshold = 4'd13;
4'b11_11 : dither_threshold = 4'd5;
endcase
end


// Dithered gradient calculation
wire [1 : 0] R_grad = (dither_threshold < grad_pos[7 : 4]) ? 2'b01 : 2'b00;
wire [1 : 0] G_grad =
(dither_threshold < (15 - grad_pos[7 : 4])) ? 2'b00 : 2'b01;
wire [1 : 0] B_grad = 2'b00;


// Vertical rectangles
wire [9 : 0] bottom_y = center_y + 2;
wire in_left_rect =
(pix_x >= center_x - 10) && (pix_x <= center_x - 6) && (pix_y <= bottom_y) &&
(pix_y >= bottom_y - 8);
wire in_middle_rect =
(pix_x >= center_x - 2) && (pix_x <= center_x + 2) && (pix_y <= bottom_y) &&
(pix_y >= bottom_y - 10);
wire in_right_rect =
(pix_x >= center_x + 6) && (pix_x <= center_x + 10) && (pix_y <= bottom_y) &&
(pix_y >= bottom_y - 12);
wire in_triple_rect = in_left_rect || in_middle_rect || in_right_rect;


// "adidas" text
wire [9 : 0] text_start_y = bottom_y + 2;
localparam CHAR_WIDTH = 6;
wire [9 : 0] a_x_start = center_x - 18;
wire [9 : 0] d_x_start = center_x - 12;
wire [9 : 0] i_x_start = center_x - 6;
wire [9 : 0] d2_x_start = center_x;
wire [9 : 0] a2_x_start = center_x + 6;
wire [9 : 0] s_x_start = center_x + 12;


wire in_a =
(pix_x >= a_x_start) && (pix_x < a_x_start + 5) && (pix_y >= text_start_y) &&
(pix_y < text_start_y + 7) &&
((pix_y == text_start_y) || (pix_y == text_start_y + 3) ||
(pix_x == a_x_start) || (pix_x == a_x_start + 4));


wire in_d =
(pix_x >= d_x_start) && (pix_x < d_x_start + 5) && (pix_y >= text_start_y) &&
(pix_y < text_start_y + 7) &&((pix_x == d_x_start) || (pix_y == text_start_y || pix_y == text_start_y + 6) ||
(pix_x == d_x_start + 4 && pix_y > text_start_y && pix_y < text_start_y + 6));


wire in_i =
(pix_x >= i_x_start) && (pix_x < i_x_start + 5) && (pix_y >= text_start_y) &&
(pix_y < text_start_y + 7) &&
((pix_x == i_x_start + 2) || (pix_y == text_start_y || pix_y == text_start_y + 6));


wire in_d2 =
(pix_x >= d2_x_start) && (pix_x < d2_x_start + 5) && (pix_y >= text_start_y) &&
(pix_y < text_start_y + 7) &&
((pix_x == d2_x_start) ||
(pix_y == text_start_y || pix_y == text_start_y + 6) ||
(pix_x == d2_x_start + 4 && pix_y > text_start_y && pix_y < text_start_y + 6));


wire in_a2 =
(pix_x >= a2_x_start) && (pix_x < a2_x_start + 5) && (pix_y >= text_start_y) &&
(pix_y < text_start_y + 7) &&
((pix_y == text_start_y) || (pix_y == text_start_y + 3) ||
(pix_x == a2_x_start) || (pix_x == a2_x_start + 4));


wire in_s =
(pix_x >= s_x_start) && (pix_x < s_x_start + 5) && (pix_y >= text_start_y) &&
(pix_y < text_start_y + 7) &&
((pix_y == text_start_y) || (pix_y == text_start_y + 3) ||
(pix_y == text_start_y + 6) ||
(pix_x == s_x_start && pix_y < text_start_y + 4) ||
(pix_x == s_x_start + 4 && pix_y > text_start_y + 2));

wire in_adidas = in_a || in_d || in_i || in_d2 || in_a2 || in_s;

// Background gradient with dithering
wire [7 : 0] bg_grad_pos = (pix_x + pix_y * 2) >> 1;
wire [3 : 0] bg_grad_level = bg_grad_pos[7 : 4];
wire [1 : 0] R_bg = (dither_threshold < bg_grad_level) ? 2'b11 : 2'b00;
wire [1 : 0] G_bg = (dither_threshold < bg_grad_level) ? 2'b11 : 2'b00;
wire [1 : 0] B_bg =
(dither_threshold < (15 - bg_grad_level)) ? 2'b11 : 2'b00;


// Final output
assign {R, G, B} = video_active
? (inside_ball
? (top_centered_vertical_gray_line ||
in_rotated_top_gray_line ||
in_reflected_rotated_top_gray_line ||
in_vertically_reflected_rotated_top_gray_line ||
in_reflected_vertically_reflected_rotated_top_gray_line ||
bottom_centered_vertical_gray_line ||
left_horizontal_gray_line ||
right_horizontal_gray_line
? 6'b10_10_10 // Gray color for the lines
: ((in_triple_rect || in_adidas)
? 6'b00_00_00
: (in_curve
? 6'b11_11_00 // Yellow color for the curves
: (inside_inner_circle
? {R_grad, G_grad, B_grad}
: 6'b11_11_11))))
: {R_bg, G_bg, B_bg})
: 6'b00_00_00;

endmodule





