`default_nettype none

module tt_um_jonathancortez_prbs31(
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire ena,
    input  wire clk,
    input  wire rst_n
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
                if (ball_dir_x != 0)
                    ball_x <= ball_x + 1;
                else
                    ball_x <= ball_x - 1;

                if (ball_dir_y != 0)
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
    wire [20:0] distance_squared = (dx * dx) + (dy * dy);
    wire inside_ball = (distance_squared < (radius * radius));

    // Hollow inner circle
    wire [9:0] inner_radius = (radius * 2) / 3;
    wire [9:0] inner_hole_radius = inner_radius - 36;
    wire inside_inner_circle =
        (distance_squared < (inner_radius * inner_radius)) &&
        (distance_squared > (inner_hole_radius * inner_hole_radius));

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

    // 90-degree rotated version of the curve
    wire [9:0] rotated_curve_center_x = center_x + inner_radius - 15 - 25 + 4 + 4;
    wire signed [20:0] rotated_curve_x =
        {11'b0, rotated_curve_center_x} - ((dy * dy) >> 7) - 4;
    wire in_curve_rotated_orig =
        ({11'b0, pix_x} >= rotated_curve_x - 2 + 30) &&
        ({11'b0, pix_x} <= rotated_curve_x + 2 + 30) &&
        (distance_squared < (inner_radius * inner_radius)) &&
        (pix_x > center_x + 20);

    // Duplicated and vertically reflected rotated curve
    wire [9:0] rotated_curve_center_x_reflected = center_x - (inner_radius - 15 - 25 + 4 + 4);
    wire signed [20:0] rotated_curve_x_reflected =
        {11'b0, rotated_curve_center_x_reflected} + ((dy * dy) >> 7) + 4;
    wire in_curve_rotated_reflected =
        ({11'b0, pix_x} >= rotated_curve_x_reflected - 2 - 30) &&
        ({11'b0, pix_x} <= rotated_curve_x_reflected + 2 - 30) &&
        (distance_squared < (inner_radius * inner_radius)) &&
        (pix_x < center_x - 20);

    // Gradient calculation (fixed width)
    wire [20:0] grad_num = (pix_x - (center_x - inner_radius)) * 255;
    wire [20:0] grad_den = inner_radius * 2;
    wire [7:0] grad_pos = (grad_num / grad_den)[7:0];

    // Background gradient with dithering (fixed width)
    wire [20:0] bg_grad_tmp = pix_x + (pix_y * 2);
    wire [7:0] bg_grad_pos = (bg_grad_tmp >> 1)[7:0];

    // [Rest of your code remains exactly the same...]
    // All other wire declarations and assignments can stay identical
    // as they either had no width issues or were fixed by the above changes

    // Final output (unchanged)
    assign {R, G, B} = video_active
        ? (inside_ball
            ? /* [your existing conditional logic] */
            : {R_bg, G_bg, B_bg})
        : 6'b00_00_00;

endmodule
