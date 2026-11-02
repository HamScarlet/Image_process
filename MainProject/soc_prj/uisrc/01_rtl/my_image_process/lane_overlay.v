`timescale 1ns/1ps

// Draw perspective guide lines from the detected lower lane points toward a
// fixed horizon. Coordinates are in the 1024x576 scaled-image space.
module lane_overlay #(
    parameter integer IMG_WIDTH      = 1024,
    parameter integer IMG_HEIGHT     = 576,
    parameter integer HORIZON_X      = IMG_WIDTH / 2,
    parameter integer HORIZON_Y      = 96,
    parameter integer BOTTOM_Y       = 540,
    parameter integer LINE_TOLERANCE = 2
)(
    input  wire        I_enable,
    input  wire [9:0]  I_x,
    input  wire [9:0]  I_y,
    input  wire [9:0]  I_left_x,
    input  wire [9:0]  I_right_x,
    input  wire [23:0] I_rgb,
    output reg  [23:0] O_rgb
);
    localparam integer DY = BOTTOM_Y - HORIZON_Y;
    localparam integer LIMIT = LINE_TOLERANCE * DY;

    wire signed [10:0] pixel_dx = $signed({1'b0, I_x}) - HORIZON_X;
    wire signed [10:0] left_dx  = $signed({1'b0, I_left_x}) - HORIZON_X;
    wire signed [10:0] right_dx = $signed({1'b0, I_right_x}) - HORIZON_X;
    wire signed [10:0] pixel_dy = $signed({1'b0, I_y}) - HORIZON_Y;

    wire signed [21:0] left_cross = pixel_dx * DY - left_dx * pixel_dy;
    wire signed [21:0] right_cross = pixel_dx * DY - right_dx * pixel_dy;
    wire [21:0] left_error = left_cross[21] ? -left_cross : left_cross;
    wire [21:0] right_error = right_cross[21] ? -right_cross : right_cross;
    wire in_line_region = (I_y >= HORIZON_Y) && (I_y <= BOTTOM_Y);
    wire on_left_line = (left_error <= LIMIT);
    wire on_right_line = (right_error <= LIMIT);

    always @* begin
        O_rgb = I_rgb;
        if (I_enable && in_line_region) begin
            if (on_left_line)
                O_rgb = 24'h00FF40; // green left boundary
            else if (on_right_line)
                O_rgb = 24'hFFB000; // amber right boundary
        end
    end
endmodule
