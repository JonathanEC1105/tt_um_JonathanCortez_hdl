`default_nettype none
`include "hvsync_generator.v"




module tt_um_vga_example(
 input wire [7:0] ui_in,
 output wire [7:0] uo_out,
 input wire [7:0] uio_in,
 output wire [7:0] uio_out,
 output wire [7:0] uio_oe,
 input wire ena,
 input wire clk,
 input wire rst_n
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




 assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
 assign uio_out = 0;
 assign uio_oe = 0;
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


 // Ball animation
 reg [9:0] ball_x = 320;
 reg [9:0] ball_y = 240;
 reg [1:0] ball_dir_x = 1;
 reg [1:0] ball_dir_y = 1;
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
         if (counter == 24'd150000) begin
             counter <= 0;
             if (|ball_dir_x)  // Changed to check if any bit is set
                 ball_x <= ball_x + 1;
             else
                 ball_x <= ball_x - 1;
             if (|ball_dir_y)  // Changed to check if any bit is set
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
 wire [9:0] center_x = ball_x;
 wire [9:0] center_y = ball_y;
 wire [9:0] radius = 100;
 wire signed [10:0] dx = pix_x - center_x;
 wire signed [10:0] dy = pix_y - center_y;
 wire [20:0] distance_squared = dx * dx + dy * dy;
 wire inside_ball = (distance_squared < radius * radius);




 // Hollow inner circle
 wire [9:0] inner_radius = (radius * 2) / 3;
 wire [9:0] inner_hole_radius = inner_radius - 36;
 wire inside_inner_circle =
     (distance_squared < inner_radius * inner_radius) &&
     (distance_squared > inner_hole_radius * inner_hole_radius);




 // Original curved yellow line at the top
 wire [9:0] curve_center_y = center_y - inner_radius + 15;
 wire signed [20:0] curve_y = ((dx * dx) >> 7) + {11'b0, curve_center_y};
 wire in_curve_original =
     ({11'b0, pix_y} >= curve_y - 2) &&
     ({11'b0, pix_y} <= curve_y + 2) &&
     (distance_squared < (inner_radius * inner_radius)) &&
     (pix_y < center_y);




 // Horizontally reflected curved yellow line
 wire signed [10:0] reflected_dx = -(pix_x - center_x);
 wire signed [20:0] reflected_curve_y =
     ((reflected_dx * reflected_dx) >> 7) + {11'b0, curve_center_y};
 wire in_curve_reflected =
     ({11'b0, pix_y} >= reflected_curve_y - 2) &&
     ({11'b0, pix_y} <= reflected_curve_y + 2) &&
     (distance_squared < (inner_radius * inner_radius)) &&
     (pix_y < center_y);








 // 90-degree rotated version of the curve (positioned to the right and up)
 wire [9:0] rotated_curve_center_x = center_x + inner_radius - 15 - 25 + 4 + 4;
 wire signed [20:0] rotated_curve_x =
     {11'b0, rotated_curve_center_x} - ((dy * dy) >> 7) - 4;
 wire in_curve_rotated_orig =
     ({11'b0, pix_x} >= rotated_curve_x - 2 + 30) &&
     ({11'b0, pix_x} <= rotated_curve_x + 2 + 30) &&
     (distance_squared < (inner_radius * inner_radius)) &&
     (pix_x > center_x + 20);






 // Duplicated and vertically reflected rotated curve (positioned to the left and up)
 wire [9:0] rotated_curve_center_x_reflected = center_x - (inner_radius - 15 - 25 + 4 + 4);
 wire signed [20:0] rotated_curve_x_reflected =
     {11'b0, rotated_curve_center_x_reflected} + ((dy * dy) >> 7) + 4;
 wire in_curve_rotated_reflected =
     ({11'b0, pix_x} >= rotated_curve_x_reflected - 2 - 30) &&
     ({11'b0, pix_x} <= rotated_curve_x_reflected + 2 - 30) &&
     (distance_squared < (inner_radius * inner_radius)) &&
     (pix_x < center_x - 20);






 // New vertical left inner circle curve (shifted 2 pixels right)
 wire [9:0] left_curve_x = center_x - inner_radius + 2 + 2 + 1;
 wire in_left_inner_curve =
     (pix_x >= left_curve_x) && (pix_x < left_curve_x + 4) &&
     (pix_y >= center_y - 20) && (pix_y < center_y + 20) &&
     (distance_squared < inner_radius * inner_radius);




 // Reflected vertical right inner circle curve (shifted 2 pixels left)
 wire [9:0] right_curve_x = center_x + inner_radius - 2 - 4 - 2;
 wire in_right_inner_curve =
     (pix_x >= right_curve_x) && (pix_x < right_curve_x + 4) &&
     (pix_y >= center_y - 20) && (pix_y < center_y + 20) &&
     (distance_squared < inner_radius * inner_radius);








 wire in_curve =
     in_curve_original || in_curve_reflected || in_curve_rotated_orig ||
     in_curve_rotated_reflected || in_left_inner_curve || in_right_inner_curve;




 // Top centered vertical gray line
 wire top_centered_vertical_gray_line =
     (pix_x >= center_x - 1) && (pix_x < center_x + 1) &&
     (distance_squared >= inner_radius * inner_radius) &&
     (distance_squared < radius * radius) && (pix_y >= center_y - radius) &&
     (pix_y <= center_y - inner_radius);




 // Rotated top gray line (45 degrees clockwise about the center)
 wire signed [10:0] rot_dx = pix_x - center_x;
 wire signed [10:0] rot_dy = pix_y - center_y;
 wire in_rotated_top_gray_line =
     (rot_dx - rot_dy >= -2) &&
     (rot_dx - rot_dy < 2) &&
     (distance_squared >= inner_radius * inner_radius) &&
     (distance_squared < radius * radius) &&
     (rot_dy < 0);




 // Reflected rotated top gray line (across vertical axis)
 wire in_reflected_rotated_top_gray_line =
     (-rot_dx - rot_dy >= -2) &&
     (-rot_dx - rot_dy < 2) &&
     (distance_squared >= inner_radius * inner_radius) &&
     (distance_squared < radius * radius) &&
     (rot_dy < 0);




 // Reflected reflected rotated top gray line (across horizontal axis)
 wire in_vertically_reflected_rotated_top_gray_line =
     (-rot_dx + rot_dy >= -2) &&
     (-rot_dx + rot_dy < 2) &&
     (distance_squared >= inner_radius * inner_radius) &&
     (distance_squared < radius * radius) &&
     (rot_dy > 0);




 // Reflected vertically reflected rotated top gray line (across vertical axis)
 wire in_reflected_vertically_reflected_rotated_top_gray_line =
     (rot_dx + rot_dy >= -2) &&
     (rot_dx + rot_dy < 2) &&
     (distance_squared >= inner_radius * inner_radius) &&
     (distance_squared < radius * radius) &&
     (rot_dy > 0);


 // Bottom centered vertical gray line (reflected)
 wire bottom_centered_vertical_gray_line =
     (pix_x >= center_x - 1) && (pix_x < center_x + 1) &&
     (distance_squared >= inner_radius * inner_radius) &&
     (distance_squared < radius * radius) && (pix_y <= center_y + radius) &&
     (pix_y >= center_y + inner_radius);




 // Left horizontal gray line
 wire left_horizontal_gray_line =
     (pix_y >= center_y - 1) && (pix_y < center_y + 1) &&
     (distance_squared >= inner_radius * inner_radius) &&
     (distance_squared < radius * radius) && (pix_x >= center_x - radius) &&
     (pix_x <= center_x - inner_radius);




 // Right horizontal gray line (reflected)
 wire right_horizontal_gray_line =
     (pix_y >= center_y - 1) && (pix_y < center_y + 1) &&
     (distance_squared >= inner_radius * inner_radius) &&
     (distance_squared < radius * radius) && (pix_x <= center_x + radius) &&
     (pix_x >= center_x + inner_radius);




// Modified to use all bits of grad_pos
wire [7:0] grad_pos;
wire [7:0] x_rel = (pix_x[9:2] - center_x[9:2]) + inner_radius[7:0];
wire [15:0] scaled_pos = x_rel * 8'd255;
wire [7:0] diameter = {1'b0, inner_radius[6:0]} << 1;


// Now using all 8 bits by selecting different bits from the scaled result
assign grad_pos = diameter != 0 ? {scaled_pos[15:12], scaled_pos[11:8]} : 8'd0;




 // 4x4 Bayer dither matrix
 wire [1:0] dither_x = pix_x[1:0];
 wire [1:0] dither_y = pix_y[1:0];
 reg [3:0] dither_threshold;
 always @(*) begin
     case ({dither_y, dither_x})
         4'b0000: dither_threshold = 4'd0;
         4'b0001: dither_threshold = 4'd8;
         4'b0010: dither_threshold = 4'd2;
         4'b0011: dither_threshold = 4'd10;
         4'b0100: dither_threshold = 4'd12;
         4'b0101: dither_threshold = 4'd4;
         4'b0110: dither_threshold = 4'd14;
         4'b0111: dither_threshold = 4'd6;
         4'b1000: dither_threshold = 4'd3;
         4'b1001: dither_threshold = 4'd11;
         4'b1010: dither_threshold = 4'd1;
         4'b1011: dither_threshold = 4'd9;
         4'b1100: dither_threshold = 4'd15;
         4'b1101: dither_threshold = 4'd7;
         4'b1110: dither_threshold = 4'd13;
         4'b1111: dither_threshold = 4'd5;
     endcase
 end




 // Dithered gradient calculation
 wire [1:0] R_grad = (dither_threshold < grad_pos[7:4]) ? 2'b01 : 2'b00;
 wire [1:0] G_grad = (dither_threshold < (15 - grad_pos[7:4])) ? 2'b00 : 2'b01;
 wire [1:0] B_grad = 2'b00;




 // Vertical rectangles
 wire [9:0] bottom_y = center_y + 2;
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
 wire [9:0] text_start_y = bottom_y + 2;
 // CHAR_WIDTH parameter removed since it wasn't used
 wire [9:0] a_x_start = center_x - 18;
 wire [9:0] d_x_start = center_x - 12;
 wire [9:0] i_x_start = center_x - 6;
 wire [9:0] d2_x_start = center_x;
 wire [9:0] a2_x_start = center_x + 6;
 wire [9:0] s_x_start = center_x + 12;




 wire in_a =
     (pix_x >= a_x_start) && (pix_x < a_x_start + 5) && (pix_y >= text_start_y) &&
     (pix_y < text_start_y + 7) &&
     ((pix_y == text_start_y) || (pix_y == text_start_y + 3) ||
     (pix_x == a_x_start) || (pix_x == a_x_start + 4));




 wire in_d =
     (pix_x >= d_x_start) && (pix_x < d_x_start + 5) && (pix_y >= text_start_y) &&
     (pix_y < text_start_y + 7) && ((pix_x == d_x_start) || (pix_y == text_start_y || pix_y == text_start_y + 6) ||
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


// Background gradient with dithering - Final clean version
wire [3:0] bg_grad_pos;


// Calculate exactly what we need with perfect bit alignment
wire [3:0] bg_grad_shifted = (pix_x[9:6] + pix_y[9:6]);  // Direct 4-bit calculation
assign bg_grad_pos = bg_grad_shifted;  // Simple assignment




wire [3:0] bg_grad_level = bg_grad_pos;  // Just use all bits since it's already 4 bits
wire [1:0] R_bg = (dither_threshold < bg_grad_level) ? 2'b11 : 2'b00;
wire [1:0] G_bg = (dither_threshold < bg_grad_level) ? 2'b11 : 2'b00;
wire [1:0] B_bg = (dither_threshold < (4'hF - bg_grad_level)) ? 2'b11 : 2'b00;  // 4'hF is hex for 15




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
