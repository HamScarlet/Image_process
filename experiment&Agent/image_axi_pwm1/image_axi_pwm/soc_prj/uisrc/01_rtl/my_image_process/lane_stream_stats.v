`timescale 1ns/1ps

// Streaming lane detector for the 1024x576, four-pixels-per-beat stream.
// It performs fixed-point luma thresholding and accumulates x moments in
// eight vertical road bands. At frame start, the previous frame's moments
// are copied to  a snapshot and divided by a small serial FSM while the next
// frame is accumulated. No full-frame image buffer is required.
module lane_stream_stats #(
    parameter integer IMG_WIDTH       = 1024,
    parameter integer IMG_HEIGHT      = 576,
    parameter integer ROI_Y_START     = 259,
    parameter integer ROI_Y_END       = 564,
    parameter integer ROI_TOP_MARGIN  = 82,
    parameter integer THRESHOLD       = 160,
    parameter integer NUM_ZONES       = 8,
    parameter integer MIN_ZONE_PIXELS = 8,
    parameter integer CURVE_THRESHOLD = 18
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire [127:0] I_tdata,
    input  wire         I_tlast,
    input  wire         I_tuser,
    input  wire         I_tvalid,
    input  wire         I_tready,
    output wire         O_result_valid,
    output wire         O_lane_valid,
    output wire         O_frame_done,
    output wire         O_frame_overrun,
    output wire [31:0]  O_frame_count,
    output wire [9:0]   O_left_x,
    output wire [9:0]   O_right_x,
    output wire signed [11:0] O_center_offset,
    output wire [1:0]   O_curve_class,
    output wire [7:0]   O_confidence
);
    localparam integer PIXELS_PER_BEAT = 4;
    localparam integer ZONE_HEIGHT = (ROI_Y_END - ROI_Y_START + NUM_ZONES) / NUM_ZONES;
    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_PREP = 2'd1;
    localparam [1:0] ST_DIV  = 2'd2;
    localparam [1:0] ST_DONE = 2'd3;
    localparam integer NUM_BINS = NUM_ZONES * 2;

    reg [10:0] x_count;
    reg [10:0] y_count;
    reg        frame_seen;
    reg [1:0]  state;
    reg [4:0]  scan_index;
    reg        frame_overrun;

    // Flat arrays use zone*2 + {left,right} indexing for broad Verilog support.
    reg [31:0] accum_x [0:NUM_BINS-1];
    reg [23:0] accum_n [0:NUM_BINS-1];
    reg [31:0] snapshot_x [0:NUM_BINS-1];
    reg [23:0] snapshot_n [0:NUM_BINS-1];
    reg [9:0]  zone_centroid [0:NUM_BINS-1];
    reg        zone_valid [0:NUM_BINS-1];

    wire [31:0] gray_pixels;
    genvar pixel;
    generate
        for (pixel = 0; pixel < PIXELS_PER_BEAT; pixel = pixel + 1) begin: GEN_GRAY
            lane_rgb_gray u_lane_rgb_gray (
                .rgb(I_tdata[pixel*32 +: 24]),
                .gray(gray_pixels[pixel*8 +: 8])
            );
        end
    endgenerate

    wire [10:0] beat_x = I_tuser ? 11'd0 : x_count;
    wire [10:0] beat_y = I_tuser ? 11'd0 : y_count;
    wire [10:0] roi_y_remaining = (beat_y <= ROI_Y_END) ?
                                   (ROI_Y_END - beat_y) : 11'd0;
    wire [10:0] roi_x_margin =
        (roi_y_remaining * ROI_TOP_MARGIN) / (ROI_Y_END - ROI_Y_START);
    wire [3:0] zone_index = (beat_y >= ROI_Y_START) ?
                             ((beat_y - ROI_Y_START) / ZONE_HEIGHT) : 4'd0;

    reg [12:0] add_left_x;
    reg [12:0] add_right_x;
    reg [2:0]  add_left_n;
    reg [2:0]  add_right_n;
    reg [10:0] pixel_x;
    integer p;
    always @* begin
        add_left_x  = 13'd0;
        add_right_x = 13'd0;
        add_left_n  = 3'd0;
        add_right_n = 3'd0;
        pixel_x     = 11'd0;
        for (p = 0; p < PIXELS_PER_BEAT; p = p + 1) begin
            pixel_x = beat_x + p;
            if ((beat_y >= ROI_Y_START) && (beat_y <= ROI_Y_END) &&
                (pixel_x >= roi_x_margin) && (pixel_x < (IMG_WIDTH - roi_x_margin)) &&
                (zone_index < NUM_ZONES) && (gray_pixels[p*8 +: 8] >= THRESHOLD)) begin
                if (pixel_x < (IMG_WIDTH / 2)) begin
                    add_left_x = add_left_x + pixel_x;
                    add_left_n = add_left_n + 1'b1;
                end else begin
                    add_right_x = add_right_x + pixel_x;
                    add_right_n = add_right_n + 1'b1;
                end
            end
        end
    end

    reg [31:0] divider_dividend;
    reg [23:0] divider_divisor;
    reg [23:0] divider_remainder;
    reg [31:0] divider_quotient;
    reg [4:0]  divider_bit;
    wire [24:0] divider_trial = {divider_remainder, divider_dividend[divider_bit]};
    wire divider_subtract = (divider_trial >= {1'b0, divider_divisor});
    wire [24:0] divider_remainder_sub = divider_trial - {1'b0, divider_divisor};

    reg         result_update;
    reg         result_lane_valid;
    reg [9:0]   result_left_x;
    reg [9:0]   result_right_x;
    reg signed [11:0] result_offset;
    reg [1:0]   result_curve;
    reg [7:0]   result_confidence;

    // Select the lowest valid paired band for lateral offset and gather the
    // three fixed bands used for the coarse curve sign/straight decision.
    reg [3:0] paired_zones;
    reg       bottom_pair_valid;
    reg [9:0] final_left_x;
    reg [9:0] final_right_x;
    reg [10:0] center_top;
    reg [10:0] center_middle;
    reg [10:0] center_lower;
    reg [10:0] center_bottom;
    reg       top_pair_valid;
    reg       middle_pair_valid;
    reg       lower_pair_valid;
    reg signed [13:0] curvature_metric;
    reg signed [11:0] final_offset;
    localparam signed [11:0] HALF_WIDTH = IMG_WIDTH / 2;
    integer z;
    always @* begin
        paired_zones = 4'd0;
        bottom_pair_valid = 1'b0;
        final_left_x = 10'd0;
        final_right_x = 10'd0;
        center_top = 11'd0;
        center_middle = 11'd0;
        center_lower = 11'd0;
        center_bottom = 11'd0;
        top_pair_valid = 1'b0;
        middle_pair_valid = 1'b0;
        lower_pair_valid = 1'b0;
        curvature_metric = 14'sd0;
        final_offset = 12'sd0;
        for (z = 0; z < NUM_ZONES; z = z + 1) begin
            if (zone_valid[z*2] && zone_valid[z*2+1]) begin
                paired_zones = paired_zones + 1'b1;
                // Ascending iteration leaves the lowest (largest y) pair selected.
                bottom_pair_valid = 1'b1;
                final_left_x = zone_centroid[z*2];
                final_right_x = zone_centroid[z*2+1];
                center_bottom = ({1'b0, zone_centroid[z*2]} +
                                 {1'b0, zone_centroid[z*2+1]}) >> 1;
                if (z == (NUM_ZONES / 4)) begin
                    center_top = ({1'b0, zone_centroid[z*2]} +
                                  {1'b0, zone_centroid[z*2+1]}) >> 1;
                    top_pair_valid = 1'b1;
                end
                if (z == (NUM_ZONES / 2)) begin
                    center_middle = ({1'b0, zone_centroid[z*2]} +
                                     {1'b0, zone_centroid[z*2+1]}) >> 1;
                    middle_pair_valid = 1'b1;
                end
                if (z == ((3 * NUM_ZONES) / 4)) begin
                    center_lower = ({1'b0, zone_centroid[z*2]} +
                                    {1'b0, zone_centroid[z*2+1]}) >> 1;
                    lower_pair_valid = 1'b1;
                end
            end
        end
        curvature_metric = $signed({3'b000, center_top}) -
                           ($signed({3'b000, center_middle}) <<< 1) +
                           $signed({3'b000, center_lower});
        if (bottom_pair_valid)
            final_offset = $signed({1'b0, center_bottom}) - HALF_WIDTH;
        else
            final_offset = 12'sd0;
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_count <= 11'd0;
            y_count <= 11'd0;
            frame_seen <= 1'b0;
            frame_overrun <= 1'b0;
            state <= ST_IDLE;
            scan_index <= 5'd0;
            divider_dividend <= 32'd0;
            divider_divisor <= 24'd0;
            divider_remainder <= 24'd0;
            divider_quotient <= 32'd0;
            divider_bit <= 5'd0;
            result_update <= 1'b0;
            result_lane_valid <= 1'b0;
            result_left_x <= 10'd0;
            result_right_x <= 10'd0;
            result_offset <= 12'sd0;
            result_curve <= 2'd0;
            result_confidence <= 8'd0;
            for (i = 0; i < NUM_BINS; i = i + 1) begin
                accum_x[i] <= 32'd0;
                accum_n[i] <= 24'd0;
                snapshot_x[i] <= 32'd0;
                snapshot_n[i] <= 24'd0;
                zone_centroid[i] <= 10'd0;
                zone_valid[i] <= 1'b0;
            end
        end else begin
            result_update <= 1'b0;

            if (I_tvalid && I_tready) begin
                if (I_tuser) begin
                    x_count <= I_tlast ? 11'd0 : 11'd4;
                    y_count <= I_tlast ? 11'd1 : 11'd0;
                    if (frame_seen) begin
                        if (state == ST_IDLE) begin
                            for (i = 0; i < NUM_BINS; i = i + 1) begin
                                snapshot_x[i] <= accum_x[i];
                                snapshot_n[i] <= accum_n[i];
                                accum_x[i] <= 32'd0;
                                accum_n[i] <= 24'd0;
                                zone_valid[i] <= 1'b0;
                            end
                            scan_index <= 5'd0;
                            state <= ST_PREP;
                        end else begin
                            // A full frame arrives before the previous 16-bin
                            // serial division should finish: drop this snapshot.
                            frame_overrun <= 1'b1;
                            for (i = 0; i < NUM_BINS; i = i + 1) begin
                                accum_x[i] <= 32'd0;
                                accum_n[i] <= 24'd0;
                            end
                        end
                    end else begin
                        frame_seen <= 1'b1;
                        for (i = 0; i < NUM_BINS; i = i + 1) begin
                            accum_x[i] <= 32'd0;
                            accum_n[i] <= 24'd0;
                        end
                    end
                end else if (I_tlast) begin
                    x_count <= 11'd0;
                    y_count <= y_count + 1'b1;
                end else begin
                    x_count <= x_count + PIXELS_PER_BEAT;
                end

                if ((zone_index < NUM_ZONES) && (beat_y < IMG_HEIGHT) &&
                    (beat_y >= ROI_Y_START) &&
                    (beat_y <= ROI_Y_END)) begin
                    if (add_left_n != 0) begin
                        accum_x[zone_index*2] <= accum_x[zone_index*2] + add_left_x;
                        accum_n[zone_index*2] <= accum_n[zone_index*2] + add_left_n;
                    end
                    if (add_right_n != 0) begin
                        accum_x[zone_index*2+1] <= accum_x[zone_index*2+1] + add_right_x;
                        accum_n[zone_index*2+1] <= accum_n[zone_index*2+1] + add_right_n;
                    end
                end
            end

            case (state)
                ST_IDLE: begin end
                ST_PREP: begin
                    if (snapshot_n[scan_index] < MIN_ZONE_PIXELS) begin
                        zone_centroid[scan_index] <= 10'd0;
                        zone_valid[scan_index] <= 1'b0;
                        if (scan_index == NUM_BINS-1) begin
                            state <= ST_DONE;
                        end else begin
                            scan_index <= scan_index + 1'b1;
                        end
                    end else begin
                        divider_dividend <= snapshot_x[scan_index];
                        divider_divisor <= snapshot_n[scan_index];
                        divider_remainder <= 24'd0;
                        divider_quotient <= 32'd0;
                        divider_bit <= 5'd31;
                        state <= ST_DIV;
                    end
                end
                ST_DIV: begin
                    divider_quotient[divider_bit] <= divider_subtract;
                    if (divider_subtract)
                        divider_remainder <= divider_remainder_sub[23:0];
                    else
                        divider_remainder <= divider_trial[23:0];

                    if (divider_bit == 0) begin
                        zone_centroid[scan_index] <= {divider_quotient[9:1], divider_subtract};
                        zone_valid[scan_index] <= 1'b1;
                        if (scan_index == NUM_BINS-1) begin
                            state <= ST_DONE;
                        end else begin
                            scan_index <= scan_index + 1'b1;
                            state <= ST_PREP;
                        end
                    end else begin
                        divider_bit <= divider_bit - 1'b1;
                    end
                end
                ST_DONE: begin
                    result_update <= 1'b1;
                    result_lane_valid <= (paired_zones >= 2) && bottom_pair_valid;
                    result_left_x <= final_left_x;
                    result_right_x <= final_right_x;
                    result_offset <= final_offset;
                    result_confidence <= paired_zones * 8'd31;
                    if (top_pair_valid && middle_pair_valid && lower_pair_valid) begin
                        if (curvature_metric > CURVE_THRESHOLD)
                            result_curve <= 2'd3; // image center bends toward the right
                        else if (curvature_metric < -CURVE_THRESHOLD)
                            result_curve <= 2'd2; // image center bends toward the left
                        else
                            result_curve <= 2'd1; // approximately straight
                    end else begin
                        result_curve <= 2'd0; // insufficient geometry
                    end
                    state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

    lane_result_latch u_lane_result_latch (
        .clk(clk),
        .rst_n(rst_n),
        .I_update(result_update),
        .I_lane_valid(result_lane_valid),
        .I_left_x(result_left_x),
        .I_right_x(result_right_x),
        .I_center_offset(result_offset),
        .I_curve_class(result_curve),
        .I_confidence(result_confidence),
        .O_result_valid(O_result_valid),
        .O_lane_valid(O_lane_valid),
        .O_frame_done(O_frame_done),
        .O_frame_count(O_frame_count),
        .O_left_x(O_left_x),
        .O_right_x(O_right_x),
        .O_center_offset(O_center_offset),
        .O_curve_class(O_curve_class),
        .O_confidence(O_confidence)
    );
    assign O_frame_overrun = frame_overrun;
endmodule
