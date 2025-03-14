/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none




module tt_um_jonathancortez_prbs31(
input wire [7:0] ui_in, // Dedicated inputs
output wire [7:0] uo_out, // Dedicated outputs
input wire [7:0] uio_in, // IOs: Input path
output wire [7:0] uio_out, // IOs: Output path
output wire [7:0] uio_oe, // IOs: Enable path (active high: 0=input, 1=output)
input wire ena, // always 1 when the design is powered, so you can ignore it
input wire clk, // clock
input wire rst_n // reset_n - low to reset
);
// VGA signals
wire hsync;
wire vsync;
wire [1:0] R;
wire [1:0] G;
wire [1:0] B;
wire video_active;
wire [9:0] pix_x;
wire [9:0] pix_y;




// TinyVGA PMOD
assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};




// Unused outputs assigned to 0.
assign uio_out = 0;
assign uio_oe = 0;




// Suppress unused signals warning
wire _unused_ok = &{ena, ui_in, uio_in};




hvsync_generator hvsync_gen(
.clk(clk),
.reset(~rst_n),
.hsync(hsync),
.vsync(vsync),
.display_on(video_active),
.hpos(pix_x),
.vpos(pix_y)
);




// Ball position and movement
reg [9:0] ball_x = 320;
reg [9:0] ball_y = 240;
reg [1:0] ball_dir_x = 1; // 0: left, 1: right
reg [1:0] ball_dir_y = 1; // 0: up, 1: down




reg [23:0] counter;
always @(posedge clk) begin
if (~rst_n) begin
counter <= 0;
ball_x <= 320;
ball_y <= 240;
ball_dir_x <= 1;
ball_dir_y <= 1;
end else begin
counter <= counter + 1;
if (counter == 24'd50000) begin // Adjust speed by changing the counter limit
counter <= 0;
// Update ball position
if (ball_dir_x) ball_x <= ball_x + 1; else ball_x <= ball_x - 1;
if (ball_dir_y) ball_y <= ball_y + 1; else ball_y <= ball_y - 1;


// Check for collisions with screen edges
if (ball_x >= 640 - radius) ball_dir_x <= 0;
if (ball_x <= radius) ball_dir_x <= 1;
if (ball_y >= 480 - radius) ball_dir_y <= 0;
if (ball_y <= radius) ball_dir_y <= 1;
end
end
end


// Ball parameters
wire [9:0] center_x = ball_x;
wire [9:0] center_y = ball_y;
wire [9:0] radius = 100;


// Calculate distance from the center of the ball
wire signed [10:0] dx = pix_x - center_x;
wire signed [10:0] dy = pix_y - center_y;
wire [20:0] distance_squared = dx * dx + dy * dy;


// Determine if the pixel is inside the ball
wire inside_ball = (distance_squared < radius * radius);


// Hexagon parameters
wire signed [10:0] hx = pix_x - center_x;
wire signed [10:0] hy = pix_y - center_y;
wire signed [10:0] abs_hx = (hx < 0) ? -hx : hx;
wire signed [10:0] abs_hy = (hy < 0) ? -hy : hy;
wire signed [10:0] qx = abs_hx - abs_hy / 2;
wire signed [10:0] qy = abs_hy;


// Determine if the pixel is inside the hexagon
wire hexagon = (qx < 25) && (qy < 50) && (qx + qy < 50);


// Assign colors based on the position
assign {R, G, B} = video_active ? (inside_ball ? (hexagon ? 6'b00_00_00 : 6'b11_11_11) : 6'b00_00_00) : 6'b00_00_00;


endmodule


