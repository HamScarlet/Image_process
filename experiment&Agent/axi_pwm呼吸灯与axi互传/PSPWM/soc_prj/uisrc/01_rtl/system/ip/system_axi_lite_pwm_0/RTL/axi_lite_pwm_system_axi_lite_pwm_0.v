`timescale 1ns/1ps

// AXI4-Lite programmable PWM peripheral for the DR1M90 PL.
//
// Register map (byte offsets, 32-bit accesses):
//   0x00 CTRL     [0]=PWM0 enable, [1]=PWM1 enable, [2]=PWM2 enable,
//                 [3]=motor driver enable
//   0x04 DIR      [0]=motor0 direction, [1]=motor1 direction
//   0x08 STATUS   [2:0]=channel update pending, [5:3]=channel enable,
//                 [6]=motor driver enable
//   0x0C VERSION  read-only, 0x00010000
//   0x10 PWM0_PSC, 0x14 PWM0_ARR, 0x18 PWM0_CCR
//   0x20 PWM1_PSC, 0x24 PWM1_ARR, 0x28 PWM1_CCR
//   0x30 PWM2_PSC, 0x34 PWM2_ARR, 0x38 PWM2_CCR
//   0x40 UPDATE   write-one to bits [2:0] to commit PWM0/1/2 settings
//
// Each PWM channel counts from 0 through ARR. The prescaler divides the input
// clock by PSC+1, and the output is high while counter < CCR. New PSC/ARR/CCR
// values are shadowed and become active together at a period boundary after
// the corresponding UPDATE bit is written.
//
// Connect s_axi_aclk to the GP0 peripheral clock (p2f_clk0) and
// s_axi_aresetn to its active-low reset (p2f_rst0_n).
//
// Note on the address width: the AXI Matrix / AXI Protocol Converter downstream
// of GP0 in this project uses 32-bit addresses (same as the AXI_GPIO instances),
// so the address ports are hard-wired to [31:0]. Only the low 8 bits are decoded
// here, therefore the port width does not change any behaviour.
//
// C_S_AXI_ADDR_WIDTH is kept as a parameter for IP-XACT/DI bookkeeping only and
// is deliberately NOT used in any range expression: the Module Packager fails to
// elaborate parameterised ranges and reports such ports as 1 bit wide, which
// breaks the AXI connection in DI. Do not reintroduce it into the port list.
//
// Note on channel enable: each channel is enabled by its own CTRL bit only.
// CTRL[3] is a separate motor-driver enable that is exported as motor_enable
// and does NOT gate the PWM outputs. This keeps the PS-side register writes
// free of any hidden dependency on the motor enable bit.
module axi_lite_pwm_system_axi_lite_pwm_0 #(
    parameter integer C_S_AXI_ADDR_WIDTH = 32,  /* bookkeeping only, see note above */
    parameter [31:0] RESET_MOTOR_ARR = 32'd9999,
    parameter [31:0] RESET_SERVO_ARR = 32'd3999599
)(
    input  wire                              s_axi_aclk,
    input  wire                              s_axi_aresetn,

    input  wire [31:0]                       s_axi_awaddr,
    input  wire                              s_axi_awvalid,
    output wire                              s_axi_awready,
    input  wire [31:0]                       s_axi_wdata,
    input  wire [3:0]                        s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output wire                              s_axi_wready,
    output reg  [1:0]                        s_axi_bresp,
    output reg                               s_axi_bvalid,
    input  wire                              s_axi_bready,

    input  wire [31:0]                       s_axi_araddr,
    input  wire                              s_axi_arvalid,
    output wire                              s_axi_arready,
    output reg  [31:0]                       s_axi_rdata,
    output reg  [1:0]                        s_axi_rresp,
    output reg                               s_axi_rvalid,
    input  wire                              s_axi_rready,

    output wire [2:0]                        pwm_out,
    output wire [1:0]                        motor_dir,
    output wire                              motor_enable
);

    localparam [7:0] REG_CTRL      = 8'h00;
    localparam [7:0] REG_DIR       = 8'h04;
    localparam [7:0] REG_STATUS    = 8'h08;
    localparam [7:0] REG_VERSION   = 8'h0C;
    localparam [7:0] REG_PWM0_PSC  = 8'h10;
    localparam [7:0] REG_PWM0_ARR  = 8'h14;
    localparam [7:0] REG_PWM0_CCR  = 8'h18;
    localparam [7:0] REG_PWM1_PSC  = 8'h20;
    localparam [7:0] REG_PWM1_ARR  = 8'h24;
    localparam [7:0] REG_PWM1_CCR  = 8'h28;
    localparam [7:0] REG_PWM2_PSC  = 8'h30;
    localparam [7:0] REG_PWM2_ARR  = 8'h34;
    localparam [7:0] REG_PWM2_CCR  = 8'h38;
    localparam [7:0] REG_UPDATE    = 8'h40;

    reg [31:0] ctrl_reg;
    reg [31:0] dir_reg;

    reg [31:0] pwm0_psc_shadow;
    reg [31:0] pwm0_arr_shadow;
    reg [31:0] pwm0_ccr_shadow;
    reg [31:0] pwm1_psc_shadow;
    reg [31:0] pwm1_arr_shadow;
    reg [31:0] pwm1_ccr_shadow;
    reg [31:0] pwm2_psc_shadow;
    reg [31:0] pwm2_arr_shadow;
    reg [31:0] pwm2_ccr_shadow;
    reg [2:0]  commit_req;

    wire [2:0] update_pending;
    wire        aw_fire;
    wire        w_fire;
    wire        write_commit;
    wire [31:0] write_addr;
    wire [31:0] write_data;
    wire [3:0]  write_strb;

    reg aw_pending;
    reg w_pending;
    reg [31:0] awaddr_hold;
    reg [31:0] wdata_hold;
    reg [3:0]  wstrb_hold;

    reg [31:0] read_data_mux;
    reg        read_addr_valid_mux;

    assign s_axi_awready = !aw_pending && !s_axi_bvalid;
    assign s_axi_wready  = !w_pending  && !s_axi_bvalid;
    assign s_axi_arready = !s_axi_rvalid;

    assign aw_fire = s_axi_awvalid && s_axi_awready;
    assign w_fire  = s_axi_wvalid  && s_axi_wready;
    assign write_commit = (aw_pending || aw_fire) &&
                          (w_pending  || w_fire)  && !s_axi_bvalid;

    assign write_addr = aw_pending ? awaddr_hold : s_axi_awaddr;
    assign write_data = w_pending  ? wdata_hold  : s_axi_wdata;
    assign write_strb = w_pending  ? wstrb_hold  : s_axi_wstrb;

    function [31:0] merge_wstrb;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0]  strobe;
        integer byte_index;
        begin
            merge_wstrb = old_value;
            for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                if (strobe[byte_index])
                    merge_wstrb[byte_index*8 +: 8] = new_value[byte_index*8 +: 8];
            end
        end
    endfunction

    // Register read mux. Unmapped and write-only registers return SLVERR.
    always @* begin
        read_data_mux = 32'd0;
        read_addr_valid_mux = 1'b1;
        case (s_axi_araddr[7:0])
            REG_CTRL:       read_data_mux = ctrl_reg;
            REG_DIR:        read_data_mux = dir_reg;
            REG_STATUS:     read_data_mux = {25'd0, ctrl_reg[3], ctrl_reg[2:0],
                                             update_pending};
            REG_VERSION:    read_data_mux = 32'h00010000;
            REG_PWM0_PSC:   read_data_mux = pwm0_psc_shadow;
            REG_PWM0_ARR:   read_data_mux = pwm0_arr_shadow;
            REG_PWM0_CCR:   read_data_mux = pwm0_ccr_shadow;
            REG_PWM1_PSC:   read_data_mux = pwm1_psc_shadow;
            REG_PWM1_ARR:   read_data_mux = pwm1_arr_shadow;
            REG_PWM1_CCR:   read_data_mux = pwm1_ccr_shadow;
            REG_PWM2_PSC:   read_data_mux = pwm2_psc_shadow;
            REG_PWM2_ARR:   read_data_mux = pwm2_arr_shadow;
            REG_PWM2_CCR:   read_data_mux = pwm2_ccr_shadow;
            default: begin
                read_data_mux = 32'd0;
                read_addr_valid_mux = 1'b0;
            end
        endcase
    end

    axi_lite_pwm_channel_system_axi_lite_pwm_0 #(.RESET_ARR(RESET_MOTOR_ARR)) u_pwm0 (
        .clk(s_axi_aclk), .rst_n(s_axi_aresetn), .enable(ctrl_reg[0]),
        .cfg_psc(pwm0_psc_shadow), .cfg_arr(pwm0_arr_shadow),
        .cfg_ccr(pwm0_ccr_shadow), .commit(commit_req[0]),
        .pending(update_pending[0]), .pwm(pwm_out[0])
    );

    axi_lite_pwm_channel_system_axi_lite_pwm_0 #(.RESET_ARR(RESET_MOTOR_ARR)) u_pwm1 (
        .clk(s_axi_aclk), .rst_n(s_axi_aresetn), .enable(ctrl_reg[1]),
        .cfg_psc(pwm1_psc_shadow), .cfg_arr(pwm1_arr_shadow),
        .cfg_ccr(pwm1_ccr_shadow), .commit(commit_req[1]),
        .pending(update_pending[1]), .pwm(pwm_out[1])
    );

    axi_lite_pwm_channel_system_axi_lite_pwm_0 #(.RESET_ARR(RESET_SERVO_ARR)) u_pwm2 (
        .clk(s_axi_aclk), .rst_n(s_axi_aresetn), .enable(ctrl_reg[2]),
        .cfg_psc(pwm2_psc_shadow), .cfg_arr(pwm2_arr_shadow),
        .cfg_ccr(pwm2_ccr_shadow), .commit(commit_req[2]),
        .pending(update_pending[2]), .pwm(pwm_out[2])
    );

    assign motor_dir = dir_reg[1:0];
    assign motor_enable = ctrl_reg[3];

    // AXI-Lite register interface. AW and W are accepted independently as
    // required by AXI-Lite; a write takes effect after both handshakes.
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            aw_pending      <= 1'b0;
            w_pending       <= 1'b0;
            awaddr_hold     <= 32'd0;
            wdata_hold      <= 32'd0;
            wstrb_hold      <= 4'd0;
            s_axi_bresp     <= 2'b00;
            s_axi_bvalid    <= 1'b0;
            s_axi_rdata     <= 32'd0;
            s_axi_rresp     <= 2'b00;
            s_axi_rvalid    <= 1'b0;
            ctrl_reg        <= 32'd0;
            dir_reg         <= 32'd0;
            pwm0_psc_shadow <= 32'd0;
            pwm0_arr_shadow <= RESET_MOTOR_ARR;
            pwm0_ccr_shadow <= 32'd0;
            pwm1_psc_shadow <= 32'd0;
            pwm1_arr_shadow <= RESET_MOTOR_ARR;
            pwm1_ccr_shadow <= 32'd0;
            pwm2_psc_shadow <= 32'd0;
            pwm2_arr_shadow <= RESET_SERVO_ARR;
            pwm2_ccr_shadow <= 32'd0;
            commit_req      <= 3'b000;
        end else begin
            commit_req <= 3'b000;

            if (aw_fire && !write_commit) begin
                awaddr_hold <= s_axi_awaddr;
                aw_pending  <= 1'b1;
            end
            if (w_fire && !write_commit) begin
                wdata_hold <= s_axi_wdata;
                wstrb_hold <= s_axi_wstrb;
                w_pending  <= 1'b1;
            end

            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;

            if (write_commit) begin
                aw_pending  <= 1'b0;
                w_pending   <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= 2'b00;

                case (write_addr[7:0])
                    REG_CTRL: begin
                        ctrl_reg <= merge_wstrb(ctrl_reg, write_data, write_strb) & 32'h0000000F;
                    end
                    REG_DIR: begin
                        dir_reg <= merge_wstrb(dir_reg, write_data, write_strb) & 32'h00000003;
                    end
                    REG_PWM0_PSC: pwm0_psc_shadow <= merge_wstrb(pwm0_psc_shadow, write_data, write_strb);
                    REG_PWM0_ARR: pwm0_arr_shadow <= merge_wstrb(pwm0_arr_shadow, write_data, write_strb);
                    REG_PWM0_CCR: pwm0_ccr_shadow <= merge_wstrb(pwm0_ccr_shadow, write_data, write_strb);
                    REG_PWM1_PSC: pwm1_psc_shadow <= merge_wstrb(pwm1_psc_shadow, write_data, write_strb);
                    REG_PWM1_ARR: pwm1_arr_shadow <= merge_wstrb(pwm1_arr_shadow, write_data, write_strb);
                    REG_PWM1_CCR: pwm1_ccr_shadow <= merge_wstrb(pwm1_ccr_shadow, write_data, write_strb);
                    REG_PWM2_PSC: pwm2_psc_shadow <= merge_wstrb(pwm2_psc_shadow, write_data, write_strb);
                    REG_PWM2_ARR: pwm2_arr_shadow <= merge_wstrb(pwm2_arr_shadow, write_data, write_strb);
                    REG_PWM2_CCR: pwm2_ccr_shadow <= merge_wstrb(pwm2_ccr_shadow, write_data, write_strb);
                    REG_UPDATE: begin
                        if (write_strb[0])
                            commit_req <= write_data[2:0];
                    end
                    default: s_axi_bresp <= 2'b10;
                endcase
            end

            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;

            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rdata  <= read_data_mux;
                s_axi_rresp  <= read_addr_valid_mux ? 2'b00 : 2'b10;
                s_axi_rvalid <= 1'b1;
            end
        end
    end

endmodule


// One independent PWM timer. The configuration is committed only at a
// period boundary so duty and frequency changes cannot truncate a pulse.
module axi_lite_pwm_channel_system_axi_lite_pwm_0 #(
    parameter [31:0] RESET_ARR = 32'd9999
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [31:0] cfg_psc,
    input  wire [31:0] cfg_arr,
    input  wire [31:0] cfg_ccr,
    input  wire        commit,
    output reg         pending,
    output wire        pwm
);
    reg [31:0] active_psc;
    reg [31:0] active_arr;
    reg [31:0] active_ccr;
    reg [31:0] prescale_count;
    reg [31:0] period_count;

    wire prescale_tick = (prescale_count >= active_psc);
    wire period_wrap = prescale_tick && (period_count >= active_arr);

    assign pwm = enable && (period_count < active_ccr);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_psc    <= 32'd0;
            active_arr    <= RESET_ARR;
            active_ccr    <= 32'd0;
            prescale_count <= 32'd0;
            period_count  <= 32'd0;
            pending       <= 1'b0;
        end else begin
            if (prescale_tick) begin
                prescale_count <= 32'd0;
                if (period_wrap) begin
                    period_count <= 32'd0;
                    if (pending || commit) begin
                        active_psc <= cfg_psc;
                        active_arr <= cfg_arr;
                        active_ccr <= cfg_ccr;
                        pending    <= 1'b0;
                    end
                end else begin
                    period_count <= period_count + 1'b1;
                end
            end else begin
                prescale_count <= prescale_count + 1'b1;
            end

            if (commit && !period_wrap)
                pending <= 1'b1;
        end
    end
endmodule


