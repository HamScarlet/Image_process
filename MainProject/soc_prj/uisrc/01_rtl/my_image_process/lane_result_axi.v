`timescale 1ns/1ps

// Lane-result register bank for the existing GP0 AXI-Lite peripheral slot.
// axi_lite_pwm provides the AXI-Lite channel handling and forwards accesses
// in the 0x50..0x74 subrange to this independent register bank.
module lane_result_axi (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         I_result_update,
    input  wire [75:0]  I_result_bundle,
    input  wire         I_cdc_overrun,
    input  wire         I_wr_en,
    input  wire [7:0]   I_wr_addr,
    input  wire [31:0]  I_wr_data,
    input  wire [3:0]   I_wr_strb,
    input  wire [7:0]   I_rd_addr,
    output reg          O_rd_valid,
    output reg  [31:0]  O_rd_data,
    output wire         O_wr_addr_valid
);
    localparam [7:0] REG_ID_VERSION = 8'h50;
    localparam [7:0] REG_STATUS     = 8'h54;
    localparam [7:0] REG_FRAME_COUNT= 8'h58;
    localparam [7:0] REG_LEFT_X     = 8'h5C;
    localparam [7:0] REG_RIGHT_X    = 8'h60;
    localparam [7:0] REG_CENTER     = 8'h64;
    localparam [7:0] REG_CURVE      = 8'h68;
    localparam [7:0] REG_CONFIDENCE = 8'h6C;
    localparam [7:0] REG_CTRL       = 8'h70;
    localparam [7:0] REG_SNAPSHOT_SEQ = 8'h74;

    reg [75:0] live_bundle;
    reg [75:0] snapshot_bundle;
    reg        snapshot_valid;
    reg [31:0] snapshot_seq;
    reg        frame_irq_pending;
    reg        cdc_overrun_sticky;
    wire       snapshot_write = I_wr_en && (I_wr_addr == REG_CTRL) &&
                                I_wr_strb[0] && I_wr_data[0];
    wire       clear_frame_irq = I_wr_en && I_wr_strb[0] &&
                                 (((I_wr_addr == REG_CTRL) && I_wr_data[1]) ||
                                  ((I_wr_addr == REG_STATUS) && I_wr_data[2]));
    wire       clear_cdc_overrun = I_wr_en && I_wr_strb[0] &&
                                   (((I_wr_addr == REG_CTRL) && I_wr_data[2]) ||
                                    ((I_wr_addr == REG_STATUS) && I_wr_data[3]));

    assign O_wr_addr_valid =
        (I_wr_addr == REG_CTRL) ||
        (I_wr_addr == REG_STATUS);

    always @* begin
        O_rd_valid = 1'b1;
        O_rd_data = 32'd0;
        case (I_rd_addr)
            REG_ID_VERSION: O_rd_data = 32'h4C520001; // "LR", version 1
            REG_STATUS: begin
                O_rd_data[0] = live_bundle[75];
                O_rd_data[1] = live_bundle[74];
                O_rd_data[2] = frame_irq_pending;
                O_rd_data[3] = cdc_overrun_sticky;
                O_rd_data[4] = snapshot_valid;
            end
            REG_FRAME_COUNT: O_rd_data = snapshot_bundle[73:42];
            REG_LEFT_X:      O_rd_data = {22'd0, snapshot_bundle[41:32]};
            REG_RIGHT_X:     O_rd_data = {22'd0, snapshot_bundle[31:22]};
            REG_CENTER:      O_rd_data = {{20{snapshot_bundle[21]}}, snapshot_bundle[21:10]};
            REG_CURVE:       O_rd_data = {30'd0, snapshot_bundle[9:8]};
            REG_CONFIDENCE:  O_rd_data = {24'd0, snapshot_bundle[7:0]};
            REG_CTRL:        O_rd_data = {31'd0, snapshot_valid};
            REG_SNAPSHOT_SEQ: O_rd_data = snapshot_seq;
            default: begin
                O_rd_data = 32'd0;
                O_rd_valid = 1'b0;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            live_bundle <= 76'd0;
            snapshot_bundle <= 76'd0;
            snapshot_valid <= 1'b0;
            snapshot_seq <= 32'd0;
            frame_irq_pending <= 1'b0;
            cdc_overrun_sticky <= 1'b0;
        end else begin
            if (I_result_update)
                live_bundle <= I_result_bundle;

            if (snapshot_write) begin
                snapshot_bundle <= I_result_update ? I_result_bundle : live_bundle;
                snapshot_valid <= 1'b1;
                snapshot_seq <= snapshot_seq + 1'b1;
            end

            // A new frame event takes priority over a simultaneous W1C.
            if (clear_frame_irq)
                frame_irq_pending <= 1'b0;
            if (I_result_update)
                frame_irq_pending <= 1'b1;

            if (clear_cdc_overrun)
                cdc_overrun_sticky <= 1'b0;
            if (I_cdc_overrun)
                cdc_overrun_sticky <= 1'b1;
        end
    end
endmodule
