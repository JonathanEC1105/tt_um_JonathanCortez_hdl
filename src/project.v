/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */
module tt_um_jonathancortez_prb31 (
    input wire clk,
    input wire [9:0] hcount, // Horizontal pixel counter
    input wire [9:0] vcount, // Vertical pixel counter
    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue
);

    // Center coordinates of the circle
    parameter CENTER_X = 320;
    parameter CENTER_Y = 240;
    parameter RADIUS = 50;

    always @(posedge clk) begin
        // Calculate the distance from the center
        integer dx = hcount - CENTER_X;
        integer dy = vcount - CENTER_Y;
        integer distance_squared = dx * dx + dy * dy;

        // Check if the current pixel is within the circle
        if (distance_squared <= RADIUS * RADIUS) begin
            red <= 8'hFF;   // White color
            green <= 8'hFF;
            blue <= 8'hFF;
        end else begin
            red <= 8'h00;   // Black color (background)
            green <= 8'h00;
            blue <= 8'h00;
        end
    end
endmodule
