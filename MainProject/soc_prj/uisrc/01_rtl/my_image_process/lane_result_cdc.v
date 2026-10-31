`timescale 1ns/1ps

// Bundled-data mailbox from the camera pixel clock to the AXI-Lite clock.
// The source holds the 76-bit bundle until the destination acknowledges it;
// only the request/acknowledge toggles pass through two-flop synchronizers.
module lane_result_cdc #(
    parameter integer BUNDLE_WIDTH = 76
)(
    input  wire                     src_clk,
    input  wire                     src_rst_n,
    input  wire                     I_src_update,
    input  wire [BUNDLE_WIDTH-1:0]  I_src_bundle,
    input  wire                     dst_clk,
    input  wire                     dst_rst_n,
    output reg                      O_dst_update,
    output reg  [BUNDLE_WIDTH-1:0]  O_dst_bundle,
    output reg                      O_dst_overrun
);
    reg [BUNDLE_WIDTH-1:0] mailbox_bundle;
    reg request_toggle;
    reg acknowledge_toggle;
    reg request_sync1;
    reg request_sync2;
    reg acknowledge_sync1;
    reg acknowledge_sync2;
    reg request_seen;
    reg mailbox_busy;
    reg source_overrun_toggle;
    reg overrun_sync1;
    reg overrun_sync2;
    reg overrun_seen;

    wire mailbox_available = !mailbox_busy ||
                             (acknowledge_sync2 == request_toggle);

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            acknowledge_sync1 <= 1'b0;
            acknowledge_sync2 <= 1'b0;
            request_toggle <= 1'b0;
            mailbox_bundle <= {BUNDLE_WIDTH{1'b0}};
            mailbox_busy <= 1'b0;
            source_overrun_toggle <= 1'b0;
        end else begin
            acknowledge_sync1 <= acknowledge_toggle;
            acknowledge_sync2 <= acknowledge_sync1;

            if (mailbox_busy && mailbox_available)
                mailbox_busy <= 1'b0;

            if (I_src_update) begin
                if (mailbox_available) begin
                    mailbox_bundle <= I_src_bundle;
                    request_toggle <= ~request_toggle;
                    mailbox_busy <= 1'b1;
                end else begin
                    // Toggle per dropped frame so the destination can report
                    // a later overrun again after software clears its sticky bit.
                    source_overrun_toggle <= ~source_overrun_toggle;
                end
            end
        end
    end

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            request_sync1 <= 1'b0;
            request_sync2 <= 1'b0;
            request_seen <= 1'b0;
            acknowledge_toggle <= 1'b0;
            O_dst_update <= 1'b0;
            O_dst_bundle <= {BUNDLE_WIDTH{1'b0}};
            overrun_sync1 <= 1'b0;
            overrun_sync2 <= 1'b0;
            overrun_seen <= 1'b0;
            O_dst_overrun <= 1'b0;
        end else begin
            request_sync1 <= request_toggle;
            request_sync2 <= request_sync1;
            overrun_sync1 <= source_overrun_toggle;
            overrun_sync2 <= overrun_sync1;
            O_dst_update <= 1'b0;
            O_dst_overrun <= 1'b0;
            if (overrun_sync2 != overrun_seen) begin
                O_dst_overrun <= 1'b1;
                overrun_seen <= overrun_sync2;
            end

            if (request_sync2 != request_seen) begin
                O_dst_bundle <= mailbox_bundle;
                O_dst_update <= 1'b1;
                request_seen <= request_sync2;
                acknowledge_toggle <= request_sync2;
            end
        end
    end
endmodule
