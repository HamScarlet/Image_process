module rgb4_downscale_8_15 (
    input  wire         I_clk,
    input  wire         I_rst_n,
    input  wire [127:0] I_tdata,
    input  wire         I_tlast,
    input  wire         I_tuser,
    input  wire         I_tvalid,
    output wire         I_tready,
    output reg  [127:0] O_tdata,
    output reg          O_tlast,
    output reg          O_tuser,
    output reg          O_tvalid,
    input  wire         O_tready
);

    reg [3:0] h_phase;
    reg [3:0] v_phase;
    reg [1:0] pack_count;
    reg [127:0] pack_data;
    reg frame_start_pending;

    reg [3:0] h_phase_next;
    reg [3:0] v_phase_next;
    reg [1:0] pack_count_next;
    reg [127:0] pack_data_next;
    reg [127:0] scaled_word;
    reg scaled_push;
    reg [3:0] line_v_phase;
    reg [3:0] h_phase_work;
    reg [1:0] pack_count_work;
    reg [127:0] pack_data_work;
    reg [31:0] pixel_work;
    integer lane;

    assign I_tready = ~O_tvalid | O_tready;

    always @* begin
        h_phase_next = h_phase;
        v_phase_next = v_phase;
        pack_count_next = pack_count;
        pack_data_next = pack_data;
        scaled_word = 128'd0;
        scaled_push = 1'b0;
        line_v_phase = I_tuser ? 4'd7 : v_phase;
        h_phase_work = I_tuser ? 4'd7 : h_phase;
        pack_count_work = I_tuser ? 2'd0 : pack_count;
        pack_data_work = I_tuser ? 128'd0 : pack_data;
        pixel_work = 32'd0;

        if (I_tvalid && I_tready) begin
            if (line_v_phase >= 4'd7) begin
                for (lane = 0; lane < 4; lane = lane + 1) begin
                    if (h_phase_work >= 4'd7) begin
                        h_phase_work = h_phase_work - 4'd7;
                        case (lane)
                            0: pixel_work = {8'd0, I_tdata[23:0]};
                            1: pixel_work = {8'd0, I_tdata[55:32]};
                            2: pixel_work = {8'd0, I_tdata[87:64]};
                            default: pixel_work = {8'd0, I_tdata[119:96]};
                        endcase

                        case (pack_count_work)
                            0: begin
                                pack_data_work[31:0] = pixel_work;
                                pack_count_work = 2'd1;
                            end
                            1: begin
                                pack_data_work[63:32] = pixel_work;
                                pack_count_work = 2'd2;
                            end
                            2: begin
                                pack_data_work[95:64] = pixel_work;
                                pack_count_work = 2'd3;
                            end
                            default: begin
                                pack_data_work[127:96] = pixel_work;
                                scaled_word = pack_data_work;
                                scaled_push = 1'b1;
                                pack_data_work = 128'd0;
                                pack_count_work = 2'd0;
                            end
                        endcase
                    end else begin
                        h_phase_work = h_phase_work + 4'd8;
                    end
                end
            end

            h_phase_next = h_phase_work;
            pack_count_next = pack_count_work;
            pack_data_next = pack_data_work;
            if (I_tuser)
                v_phase_next = 4'd7;

            if (I_tlast) begin
                h_phase_next = 4'd7;
                pack_count_next = 2'd0;
                pack_data_next = 128'd0;
                if (line_v_phase >= 4'd7)
                    v_phase_next = line_v_phase - 4'd7;
                else
                    v_phase_next = line_v_phase + 4'd8;
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            h_phase <= 4'd7;
            v_phase <= 4'd7;
            pack_count <= 2'd0;
            pack_data <= 128'd0;
            frame_start_pending <= 1'b1;
            O_tdata <= 128'd0;
            O_tlast <= 1'b0;
            O_tuser <= 1'b0;
            O_tvalid <= 1'b0;
        end else begin
            if (O_tvalid && O_tready)
                O_tvalid <= 1'b0;

            if (I_tvalid && I_tready) begin
                h_phase <= h_phase_next;
                v_phase <= v_phase_next;
                pack_count <= pack_count_next;
                pack_data <= pack_data_next;

                if (I_tuser)
                    frame_start_pending <= 1'b1;

                if (scaled_push) begin
                    O_tdata <= scaled_word;
                    O_tlast <= I_tlast;
                    O_tuser <= frame_start_pending | I_tuser;
                    O_tvalid <= 1'b1;
                    if (frame_start_pending | I_tuser)
                        frame_start_pending <= 1'b0;
                end
            end
        end
    end

endmodule
