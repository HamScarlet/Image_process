`timescale 1ns/1ps

// Fixed-point BT.601 RGB888 to 8-bit luma conversion.
// rgb input ordering is {R, G, B}, matching the low 24 bits of each
// downscaled 32-bit pixel word in system_top.
module lane_rgb_gray (
    input  wire [23:0] rgb,
    output wire [7:0]  gray
);
    wire [7:0] red   = rgb[23:16];
    wire [7:0] green = rgb[15:8];
    wire [7:0] blue  = rgb[7:0];
    wire [15:0] luma_sum;

    assign luma_sum = 16'd77 * red + 16'd150 * green + 16'd29 * blue + 16'd128;
    assign gray = luma_sum[15:8];
endmodule
