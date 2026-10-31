`timescale 1ns/1ps

// Frame-level lane result registers. Results remain stable until the next
// completed frame; O_frame_done is a one-cycle update pulse.
module lane_result_latch (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              I_update,
    input  wire              I_lane_valid,
    input  wire [9:0]        I_left_x,
    input  wire [9:0]        I_right_x,
    input  wire signed [11:0] I_center_offset,
    input  wire [1:0]        I_curve_class,
    input  wire [7:0]        I_confidence,
    output reg               O_result_valid,
    output reg               O_lane_valid,
    output reg               O_frame_done,
    output reg  [31:0]       O_frame_count,
    output reg  [9:0]        O_left_x,
    output reg  [9:0]        O_right_x,
    output reg signed [11:0] O_center_offset,
    output reg  [1:0]        O_curve_class,
    output reg  [7:0]        O_confidence
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            O_result_valid <= 1'b0;
            O_lane_valid   <= 1'b0;
            O_frame_done   <= 1'b0;
            O_frame_count  <= 32'd0;
            O_left_x       <= 10'd0;
            O_right_x      <= 10'd0;
            O_center_offset <= 12'sd0;
            O_curve_class  <= 2'd0;
            O_confidence   <= 8'd0;
        end else begin
            O_frame_done <= 1'b0;
            if (I_update) begin
                O_result_valid  <= 1'b1;
                O_lane_valid    <= I_lane_valid;
                O_frame_done    <= 1'b1;
                O_frame_count   <= O_frame_count + 1'b1;
                O_left_x        <= I_left_x;
                O_right_x       <= I_right_x;
                O_center_offset <= I_center_offset;
                O_curve_class   <= I_curve_class;
                O_confidence    <= I_confidence;
            end
        end
    end
endmodule
