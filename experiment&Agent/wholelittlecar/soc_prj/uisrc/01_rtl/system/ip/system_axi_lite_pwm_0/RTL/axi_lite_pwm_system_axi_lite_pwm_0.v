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
// ★ 2026-11-02 语义反转（V8/C1）：CTRL[3] 现在**门控** pwm_out[0] 与 pwm_out[1]。
//
//   旧行为（V3 实测过）：CTRL[3] 只是导出成 motor_enable，不影响 PWM 波形。
//   新行为：pwm_out[0]/[1] = 通道波形 && CTRL[3] && !guard_hit
//           guard_hit = guard_latched && (motor_dir_in == 4'h5)
//
//   【为什么必须这样改】
//     15 cm 急停要在 PL 侧硬关断，不能等 PS 收到信息再写寄存器 —— PS 一旦
//     卡住（printf 阻塞、看门狗没喂），车就带着 PWM 冲出去。门控放在这一层，
//     只要超声量到 <15 cm 就立刻截断波形，PS 完全不知情也照样停。
//
//   【为什么判据里要带 motor_dir_in == 4'h5】
//     用户要求"停前进，但允许转向和后退脱离"。4'h5 = AIN1/BIN1 高 =
//     前进（见 TIM_GPIO.h 的 MOTOR_DIR_FWD）。方向不是 0x5 时门控不生效，
//     于是倒车 / 原地转可以自由脱离障碍。
//
//   【为什么不强拉方向到 0xF 刹车】
//     TB6612 真值表：IN1=H, IN2=L, PWM=L ⇒ **短路制动**（不是滑行）。
//     所以只截 PWM 就已经是刹车，不需要额外的方向 mux —— 这一点是
//     V4 实测推翻了我最初"截 PWM 会滑行"的判断。
//
//   【CH2 为什么不门控】
//     CH2 是舵机通道（pwm_out[2]），与电机无关。CTRL[2] 单独管它。
//
//   【motor_stby 为什么不被门控】
//     STBY 若跟着掉，整片 TB6612 失能（含 B 通道）。从 0x5 切 0xA 的瞬间
//     会出现一段"整片不响应"的窗口，换向手感会断。所以拆成两根：
//       motor_enable = CTRL[3] && !guard_hit   -> M20 / LED4（门控后，可观察）
//       motor_stby   = CTRL[3]                 -> Y7       （始终跟随 CTRL[3]）
//
//   ⚠️ 判据 C1 就是"把 V3 的结论反过来验"：CTRL[3]=0 时 V6/U7 必须是死电平，
//      而 V3 当时看到的是方波。看到方波说明改错了文件（多半改的是 ip_repo
//      里的原件，而综合用的是工程内那份 system/ip/... 副本）。
//
// ----------------------------------------------------------------------------
// 寄存器地图补充（0x50–0x6C，V8 新增）
//   0x50 SONAR_TICKS  RO  最近一次 ECHO 高电平的时钟拍数（1 拍 = 20 ns）
//   0x54 SONAR_CFG    RW  [15:0]=自动触发周期(ms)  [16]=写 1 软触发(自清)
//                         [17]=使能  [18]=写 1 清门控锁存(自清)
//   0x58 GUARD_CFG    RW  [15:0]=进入阈值(ticks)  [31:16]=退出阈值(ticks)
//   0x5C GUARD_ST     RO  [0]=当前拦  [1]=锁存  [2]=有过读数  [3]=方向自检
//                         [4]=超声超时  [5]=测距忙
//   0x60 BT_RX        RO  [7:0]=字节  [8]=有新字节(读清)  [23:16]=收字节数低 8 位
//   0x64 BT_TX        WO  [7:0]=要发的字节（写入即入队，单字节缓冲）
//   0x68 BT_CFG       RW  [15:0]=每 bit 时钟数(434 @50 MHz/115200)  [16]=使能
//   0x6C GUARD_CNT    RO  进入拦停的累计次数
//
//   全部落在 addressBlock range=128(0x80) 之内，Component.xml 不用改 range。
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
    output wire [1:0]                        motor_dir,      /* 保留（DI 端口不动），V8 起不再驱动电机 */
    output wire                              motor_enable,   /* CTRL[3] && !guard_hit -> M20/LED4 */
    output wire                              motor_stby,     /* CTRL[3]（不门控）     -> Y7 */

    /* ★ V8 新增：方向从 GPIO_1_gpio_io_o 直接读进来，不再经 REG_DIR。
     *   同一根 s_axi_aclk 驱动 AXI GPIO 与本模块 ⇒ 同域，无 CDC。
     *   好处：PS 侧方向驱动一字不改，.adc 方向那 4 行一字不改。 */
    input  wire [3:0]                        motor_dir_in,

    /* ★ V8 新增：HC-SR04 超声测距 */
    output wire                              sonar_trig,
    input  wire                              sonar_echo,

    /* ★ V8 新增：蓝牙软 UART（BT_TX 接模块 RX，BT_RX 接模块 TX） */
    output wire                              bt_tx,
    input  wire                              bt_rx
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

    /* ---- V8 新增寄存器 ---- */
    localparam [7:0] REG_SONAR_TICKS = 8'h50;
    localparam [7:0] REG_SONAR_CFG   = 8'h54;
    localparam [7:0] REG_GUARD_CFG   = 8'h58;
    localparam [7:0] REG_GUARD_ST    = 8'h5C;
    localparam [7:0] REG_BT_RX       = 8'h60;
    localparam [7:0] REG_BT_TX       = 8'h64;
    localparam [7:0] REG_BT_CFG      = 8'h68;
    localparam [7:0] REG_GUARD_CNT   = 8'h6C;

    /* 默认值：超声 60 ms 一轮、门控 15 cm 进 / 17 cm 出、蓝牙 115200。
     * ticks 的算法见文件末尾 axi_lite_guard_system_axi_lite_pwm_0 的注释（50 MHz 下 1 cm ≈ 2900 拍）。*/
    localparam [31:0] RESET_SONAR_CFG = 32'h0001_003C;  /* enable=1, period=60 ms */
    localparam [31:0] RESET_GUARD_CFG = 32'hC094_A9EC;  /* exit=49300, enter=43500 */
    localparam [31:0] RESET_BT_CFG    = 32'h0001_01B2;  /* enable=1, div=434 */

    reg [31:0] ctrl_reg;
    reg [31:0] dir_reg;

    reg [31:0] sonar_cfg_reg;
    reg [31:0] guard_cfg_reg;
    reg [31:0] bt_cfg_reg;

    reg [7:0]  bt_rx_data;
    reg        bt_rx_fresh;
    reg [15:0] bt_rx_count;
    reg [7:0]  bt_tx_data;
    reg        bt_tx_start;
    reg        sonar_sw_trig;
    reg        guard_clear;

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

    /* ---- V8 内部信号 ---- */
    wire [2:0]  ch_pwm;            /* 三通道原始波形，门控前 */
    wire [31:0] sonar_ticks;
    wire        sonar_valid;
    wire        sonar_busy;
    wire        sonar_timeout;
    wire        sonar_start;
    wire        bt_rx_valid;
    wire [7:0]  bt_rx_byte;
    wire        bt_tx_busy;
    reg         sonar_ever_valid;
    wire [31:0] guard_hit_count;

    wire        guard_latched;
    wire        dir_is_fwd;
    wire        guard_hit;
    wire        motor_en_final;

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

            /* ---- V8 ---- */
            REG_SONAR_TICKS: read_data_mux = sonar_ticks;
            REG_SONAR_CFG:   read_data_mux = sonar_cfg_reg;
            REG_GUARD_CFG:   read_data_mux = guard_cfg_reg;
            REG_GUARD_ST:    read_data_mux = {26'd0, sonar_busy, sonar_timeout,
                                              dir_is_fwd, sonar_ever_valid,
                                              guard_latched, guard_hit};
            REG_BT_RX:       read_data_mux = {8'd0, bt_rx_count[7:0],
                                              bt_rx_fresh, bt_rx_data};
            REG_BT_TX:       read_data_mux = {24'd0, bt_tx_data};   /* 只写，读回最后写入值 */
            REG_BT_CFG:      read_data_mux = {14'd0, bt_tx_busy, bt_cfg_reg[16:0]};
            REG_GUARD_CNT:   read_data_mux = guard_hit_count;

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
        .pending(update_pending[0]), .pwm(ch_pwm[0])
    );

    axi_lite_pwm_channel_system_axi_lite_pwm_0 #(.RESET_ARR(RESET_MOTOR_ARR)) u_pwm1 (
        .clk(s_axi_aclk), .rst_n(s_axi_aresetn), .enable(ctrl_reg[1]),
        .cfg_psc(pwm1_psc_shadow), .cfg_arr(pwm1_arr_shadow),
        .cfg_ccr(pwm1_ccr_shadow), .commit(commit_req[1]),
        .pending(update_pending[1]), .pwm(ch_pwm[1])
    );

    axi_lite_pwm_channel_system_axi_lite_pwm_0 #(.RESET_ARR(RESET_SERVO_ARR)) u_pwm2 (
        .clk(s_axi_aclk), .rst_n(s_axi_aresetn), .enable(ctrl_reg[2]),
        .cfg_psc(pwm2_psc_shadow), .cfg_arr(pwm2_arr_shadow),
        .cfg_ccr(pwm2_ccr_shadow), .commit(commit_req[2]),
        .pending(update_pending[2]), .pwm(ch_pwm[2])
    );

    // ========================================================================
    //  V8 电机门控（15 cm 硬急停）
    // ========================================================================
    assign motor_dir      = dir_reg[1:0];           /* 保留回读语义，但不再驱动引脚 */
    assign dir_is_fwd     = (motor_dir_in == 4'h5); /* AIN1=BIN1=1 => 前进 */
    assign guard_hit      = guard_latched && dir_is_fwd;
    assign motor_en_final = ctrl_reg[3] && !guard_hit;

    assign pwm_out[0]   = ch_pwm[0] && motor_en_final;
    assign pwm_out[1]   = ch_pwm[1] && motor_en_final;
    assign pwm_out[2]   = ch_pwm[2];                /* CH2 = 舵机，不跟随电机门控 */

    assign motor_enable = motor_en_final;           /* -> M20 / LED4 */
    assign motor_stby   = ctrl_reg[3];              /* -> Y7，不门控 */

    // ---------------- 1 ms 基准（超声自动触发用） ----------------
    // 50 MHz / 50000 = 1 kHz。写死而不用参数：本项目 p2f_clk0 已实测 50.0 MHz。
    reg [15:0] ms_div;
    reg        ms_tick;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            ms_div  <= 16'd0;
            ms_tick <= 1'b0;
        end else if (ms_div >= 16'd49999) begin
            ms_div  <= 16'd0;
            ms_tick <= 1'b1;
        end else begin
            ms_div  <= ms_div + 1'b1;
            ms_tick <= 1'b0;
        end
    end

    reg [15:0] ms_cnt;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            ms_cnt <= 16'd0;
        end else if (ms_tick) begin
            if (ms_cnt >= sonar_cfg_reg[15:0])
                ms_cnt <= 16'd0;
            else
                ms_cnt <= ms_cnt + 1'b1;
        end
    end

    /* ms_tick 与 ms_cnt 归零在同一拍，条件用的是旧值 ⇒ 这个脉冲只有 1 拍宽。 */
    wire auto_trig = sonar_cfg_reg[17] && ms_tick &&
                     (ms_cnt >= sonar_cfg_reg[15:0]) && !sonar_busy;

    assign sonar_start = auto_trig || sonar_sw_trig;

    // ---------------- 子模块 ----------------
    axi_lite_sonar_system_axi_lite_pwm_0 u_sonar (
        .clk     (s_axi_aclk),
        .rst_n   (s_axi_aresetn),
        .start   (sonar_start),
        .trig    (sonar_trig),
        .echo    (sonar_echo),
        .ticks   (sonar_ticks),
        .valid   (sonar_valid),
        .timeout (sonar_timeout),
        .busy    (sonar_busy)
    );

    axi_lite_guard_system_axi_lite_pwm_0 u_guard (
        .clk         (s_axi_aclk),
        .rst_n       (s_axi_aresetn),
        .sonar_ticks (sonar_ticks),
        .sonar_valid (sonar_valid),
        .enter_ticks (guard_cfg_reg[15:0]),
        .exit_ticks  (guard_cfg_reg[31:16]),
        .latched     (guard_latched),
        .clear       (guard_clear),
        .hit_count   (guard_hit_count)
    );

    axi_lite_uart_bt_system_axi_lite_pwm_0 u_bt (
        .clk      (s_axi_aclk),
        .rst_n    (s_axi_aresetn),
        .enable   (bt_cfg_reg[16]),
        .div      (bt_cfg_reg[15:0]),
        .rx_i     (bt_rx),
        .rx_byte  (bt_rx_byte),
        .rx_valid (bt_rx_valid),
        .tx_data  (bt_tx_data),
        .tx_start (bt_tx_start),
        .tx_o     (bt_tx),
        .tx_busy  (bt_tx_busy)
    );

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
            sonar_cfg_reg   <= RESET_SONAR_CFG;
            guard_cfg_reg   <= RESET_GUARD_CFG;
            bt_cfg_reg      <= RESET_BT_CFG;
            bt_rx_data      <= 8'd0;
            bt_rx_fresh     <= 1'b0;
            bt_rx_count     <= 16'd0;
            bt_tx_data      <= 8'd0;
            bt_tx_start     <= 1'b0;
            sonar_sw_trig   <= 1'b0;
            guard_clear     <= 1'b0;
            sonar_ever_valid <= 1'b0;
        end else begin
            commit_req    <= 3'b000;
            bt_tx_start   <= 1'b0;
            sonar_sw_trig <= 1'b0;
            guard_clear   <= 1'b0;

            /* 超声：有读数就记一笔，GUARD_ST[2] 用它区分"没测过"和"测到远处" */
            if (sonar_valid)
                sonar_ever_valid <= 1'b1;

            /* 蓝牙收字节放在本 always 块的最末尾（见文件下部），
             * 因为它和"读 BT_RX 清 fresh"写的是同一个标志位 ——
             * 非阻塞赋值里后写的赢，要保证"新字节到达"优先于"读过就算旧"。 */

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

                    /* ---- V8 ---- */
                    REG_SONAR_CFG: begin
                        /* bit16 = 软触发：写 1 立刻测一轮，但**不存进寄存器**
                         * （存了软件就得自己记着清，多一个出错的机会）。
                         * bit18 = 清门控锁存：现场救命用。超声线松了、模块坏了，
                         * latched 会保持最后一次"近"的状态，车就永远不能前进；
                         * 写一下 bit18 把锁存清掉，不用重新上电。
                         * 掩码 0x0002FFFF 只保留 bit17(enable)，bit16/bit18 都强制为 0。 */
                        sonar_cfg_reg <= merge_wstrb(sonar_cfg_reg, write_data, write_strb)
                                         & 32'h0002FFFF;
                        if (write_strb[2]) begin
                            if (write_data[16])
                                sonar_sw_trig <= 1'b1;
                            if (write_data[18])
                                guard_clear   <= 1'b1;
                        end
                    end
                    REG_GUARD_CFG: begin
                        guard_cfg_reg <= merge_wstrb(guard_cfg_reg, write_data, write_strb);
                    end
                    REG_BT_TX: begin
                        if (write_strb[0]) begin
                            bt_tx_data  <= write_data[7:0];
                            bt_tx_start <= 1'b1;
                        end
                    end
                    REG_BT_CFG: begin
                        bt_cfg_reg <= merge_wstrb(bt_cfg_reg, write_data, write_strb)
                                      & 32'h0001FFFF;
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

                /* 读 BT_RX 顺便把 fresh 清掉 —— 这样 PS 只要看到 [8]=1，
                 * 就说明这一拍读到的字节是新的，不需要额外写一个"确认"寄存器。
                 * 用读地址而不是 read_addr_valid_mux 判断，避免地址判错时误清。 */
                if (s_axi_araddr[7:0] == REG_BT_RX)
                    bt_rx_fresh <= 1'b0;
            end

            /* ★ 必须是本 always 块的最后一个赋值块。
             *   同一拍"收到新字节"与"软件读走旧字节"同时发生时，
             *   新字节的 fresh=1 必须赢 —— 否则那一帧会静默消失。
             *   概率极低（PS 读 AXI 只有几百 ns，一个字节 87 µs），
             *   但这类丢帧在遥控车上表现为"偶尔没反应"，极难复现排查。 */
            if (bt_rx_valid) begin
                bt_rx_data  <= bt_rx_byte;
                bt_rx_fresh <= 1'b1;
                bt_rx_count <= bt_rx_count + 1'b1;
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


// ============================================================================
//  HC-SR04 超声测距
// ============================================================================
//
//  【时序】TRIG 给 ≥10 µs 高电平 -> 模块发 8 个 40 kHz 脉冲 -> ECHO 拉高，
//         高电平宽度 = 声波往返时间 -> ECHO 拉低。
//
//  【换算】声速 340 m/s，往返 ⇒ 1 cm = 2×1 cm / 34000 cm per s = 58.8 µs。
//         50 MHz 下 1 µs = 50 拍 ⇒ 1 cm ≈ 2941 拍。
//         本工程用 2900（对应 344.8 m/s，室温 22 °C 左右）。
//         15 cm = 870 µs = 43500 拍；400 cm = 23.2 ms = 1160000 拍。
//
//  【为什么 PL 不做除法】门控只需要和阈值比大小（ticks < 43500），
//         除法留给 PS 打印用。省一个除法器（约 200 LUT），而且
//         精度从"±1 cm"变成"1 拍 = 20 ns ≈ 3.4 µm"。
//
//  【为什么超时值这么定】
//         ECHO 一直不来（模块没接 / 线断了）若死等，整个门控就废了。
//         等上升沿 5 ms、测高电平 30 ms（400 cm 上限的 1.3 倍），
//         超时就置 timeout 并回 IDLE，下一轮照常触发。
// ============================================================================
module axi_lite_sonar_system_axi_lite_pwm_0 #(
    parameter [31:0] TRIG_PULSE_CYCLES = 32'd600,     /* 12 µs @ 50 MHz，规格要 ≥10 µs */
    parameter [31:0] ECHO_RISE_TIMEOUT = 32'd250000,  /* 5 ms  */
    parameter [31:0] ECHO_HIGH_TIMEOUT = 32'd1500000  /* 30 ms */
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,     /* 单拍脉冲：开始一轮测量 */
    output wire        trig,
    input  wire        echo,      /* 异步输入，模块内部同步 */
    output reg  [31:0] ticks,     /* ECHO 高电平拍数 */
    output reg         valid,     /* ticks 更新时的单拍脉冲 */
    output reg         timeout,   /* 上一轮超时（sticky，下次启动清） */
    output wire        busy
);

    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_TRIG = 3'd1;
    localparam [2:0] S_WAIT = 3'd2;
    localparam [2:0] S_MEAS = 3'd3;

    reg [2:0]  state;
    reg [31:0] cnt;
    reg        echo_d0;
    reg        echo_d1;

    /* ECHO 是板外信号，与 s_axi_aclk 无相位关系 ⇒ 必须两级同步再进状态机。
     * 少了这两级，状态机会因为亚稳态随机跳态，现象是"偶尔测到一个离谱的距离"。 */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            echo_d0 <= 1'b0;
            echo_d1 <= 1'b0;
        end else begin
            echo_d0 <= echo;
            echo_d1 <= echo_d0;
        end
    end

    assign trig = (state == S_TRIG);
    assign busy = (state != S_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            cnt     <= 32'd0;
            ticks   <= 32'd0;
            valid   <= 1'b0;
            timeout <= 1'b0;
        end else begin
            valid <= 1'b0;

            case (state)
            S_IDLE: begin
                cnt <= 32'd0;
                if (start) begin
                    state   <= S_TRIG;
                    timeout <= 1'b0;
                end
            end

            S_TRIG: begin
                if (cnt >= TRIG_PULSE_CYCLES) begin
                    cnt   <= 32'd0;
                    state <= S_WAIT;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end

            S_WAIT: begin
                if (echo_d1) begin
                    cnt   <= 32'd1;   /* 见到上升沿这一拍就算第 1 拍 */
                    state <= S_MEAS;
                end else if (cnt >= ECHO_RISE_TIMEOUT) begin
                    cnt     <= 32'd0;
                    timeout <= 1'b1;
                    state   <= S_IDLE;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end

            S_MEAS: begin
                if (!echo_d1) begin
                    ticks <= cnt;
                    valid <= 1'b1;
                    cnt   <= 32'd0;
                    state <= S_IDLE;
                end else if (cnt >= ECHO_HIGH_TIMEOUT) begin
                    cnt     <= 32'd0;
                    timeout <= 1'b1;
                    state   <= S_IDLE;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end

            default: begin
                state <= S_IDLE;
                cnt   <= 32'd0;
            end
            endcase
        end
    end
endmodule


// ============================================================================
//  15 cm 距离门控（带迟滞）
// ============================================================================
//
//  【为什么要有迟滞】
//     只用单个阈值时，车停在 15.0 cm 附近，超声读数抖动 1~2 cm 就会让
//     latched 反复翻转，PWM 被切成"断续"——听起来像电机在打嗝，还会
//     加速驱动管发热。进 15 cm / 出 17 cm 两道门把抖动挡在中间地带。
//
//  【中间地带保持原状态】这是迟滞的本质：14.9 -> 拦，16.5 -> 仍拦，17.1 -> 放。
//
//  【为什么阈值用 ticks 而不是 cm】
//     见 axi_lite_sonar_system_axi_lite_pwm_0 的注释。PL 侧不做除法。
// ============================================================================
module axi_lite_guard_system_axi_lite_pwm_0 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] sonar_ticks,
    input  wire        sonar_valid,
    input  wire [15:0] enter_ticks,   /* 默认 43500 = 15 cm */
    input  wire [15:0] exit_ticks,    /* 默认 49300 = 17 cm */
    input  wire        clear,         /* 单拍脉冲：软件强制解除锁存 */
    output reg         latched,
    output reg  [31:0] hit_count
);
    /* 用 32 位比较：ticks 满量程到 23.2 ms（1160000 拍），16 位装不下。
     * 阈值本身 16 位够（65535 拍 ≈ 22.6 cm），零扩展即可。 */
    wire [31:0] enter32 = {16'd0, enter_ticks};
    wire [31:0] exit32  = {16'd0, exit_ticks};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched   <= 1'b0;
            hit_count <= 32'd0;
        end else if (sonar_valid) begin
            if (sonar_ticks < enter32) begin
                if (!latched) begin
                    latched   <= 1'b1;
                    hit_count <= hit_count + 1'b1;   /* 只在"进入"时计数 */
                end
            end else if (sonar_ticks > exit32) begin
                latched <= 1'b0;
            end
            /* 中间地带：什么都不做，保持原状 */
        end else if (clear) begin
            /* ★ 软件强制解除（SONAR_CFG[18] 写 1）。
             *
             *   为什么需要这条：超声线松了 / 模块坏了之后 sonar_valid 不再更新，
             *   latched 会永远保持最后一次"近"的状态 —— 车就再也前进不了，
             *   现场唯一的办法是重新上电。有了这一位，发一条命令就能解。
             *
             *   优先级低于 sonar_valid：同一拍既有新读数又要清除时，以新读数为准
             *   （清完立刻按实测距离重判），免得"刚清完就撞上"。 */
            latched <= 1'b0;
        end
    end
endmodule


// ============================================================================
//  软 UART（蓝牙模块用，8N1）
// ============================================================================
//
//  【为什么用软 UART 而不是 PS 的 UART0】
//     PS 侧只有 UART1 引到了 Type-C（0xF8401000），已经占给日志用。
//     UART0 在本工程没引出。要在 PL 侧接 HC-05/HC-06，只能自己搓一个。
//
//  【波特率】div = 每 bit 的时钟数 = 50e6 / 115200 = 434.03 -> 434
//         实际波特率 = 50e6 / 434 = 115207，误差 +0.006%，远小于 2% 容限。
//
//  【RX 采样点在位中心】检测到起始位下降沿后先等 div/2 拍再确认，
//         之后每隔 div 拍采一位 —— 这样每个采样点都落在位的正中间，
//         对时钟偏差的容忍度最大（±半位 = ±217 拍 = ±4.3 µs）。
//
//  【div 保护】写 0 会让计数器永远不满足条件（16 位减法下溢），
//         所以内部夹到最小 2。
// ============================================================================
module axi_lite_uart_bt_system_axi_lite_pwm_0 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [15:0] div,
    input  wire        rx_i,
    output reg  [7:0]  rx_byte,
    output reg         rx_valid,
    input  wire [7:0]  tx_data,
    input  wire        tx_start,
    output wire        tx_o,
    output wire        tx_busy
);
    wire [15:0] div_safe = (div < 16'd2) ? 16'd2 : div;
    wire [15:0] half     = div_safe >> 1;

    /* ---------------- RX ---------------- */
    localparam [1:0] R_IDLE  = 2'd0;
    localparam [1:0] R_START = 2'd1;
    localparam [1:0] R_DATA  = 2'd2;
    localparam [1:0] R_STOP  = 2'd3;

    reg [1:0]  r_state;
    reg [15:0] r_cnt;
    reg [2:0]  r_bit;
    reg [7:0]  r_shift;
    reg        rx_d0;
    reg        rx_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_d0 <= 1'b1;
            rx_d1 <= 1'b1;
        end else begin
            rx_d0 <= rx_i;
            rx_d1 <= rx_d0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state  <= R_IDLE;
            r_cnt    <= 16'd0;
            r_bit    <= 3'd0;
            r_shift  <= 8'd0;
            rx_byte  <= 8'd0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            if (!enable) begin
                r_state <= R_IDLE;
                r_cnt   <= 16'd0;
            end else begin
                case (r_state)
                R_IDLE: begin
                    if (!rx_d1) begin      /* 起始位下降沿 */
                        r_cnt   <= 16'd0;
                        r_state <= R_START;
                    end
                end

                R_START: begin
                    /* 等半位到起始位中心再确认，滤掉 <半位宽的毛刺 */
                    if (r_cnt >= (half - 16'd1)) begin
                        r_cnt <= 16'd0;
                        if (!rx_d1) begin
                            r_bit   <= 3'd0;
                            r_state <= R_DATA;
                        end else begin
                            r_state <= R_IDLE;   /* 假起始位 */
                        end
                    end else begin
                        r_cnt <= r_cnt + 1'b1;
                    end
                end

                R_DATA: begin
                    if (r_cnt >= (div_safe - 16'd1)) begin
                        r_cnt <= 16'd0;
                        r_shift[r_bit] <= rx_d1;   /* LSB first */
                        if (r_bit == 3'd7)
                            r_state <= R_STOP;
                        else
                            r_bit <= r_bit + 1'b1;
                    end else begin
                        r_cnt <= r_cnt + 1'b1;
                    end
                end

                R_STOP: begin
                    if (r_cnt >= (div_safe - 16'd1)) begin
                        r_cnt <= 16'd0;
                        if (rx_d1) begin           /* 停止位必须是高，否则整帧作废 */
                            rx_byte  <= r_shift;
                            rx_valid <= 1'b1;
                        end
                        r_state <= R_IDLE;
                    end else begin
                        r_cnt <= r_cnt + 1'b1;
                    end
                end

                default: r_state <= R_IDLE;
                endcase
            end
        end
    end

    /* ---------------- TX ---------------- */
    /* tx_frame = {停止位 1, 8 位数据, 起始位 0}
     * 索引 0 = 起始位（先发），9 = 停止位（后发）—— 天然就是 LSB first。 */
    reg [9:0]  tx_frame;
    reg [3:0]  tx_bit;
    reg [15:0] tx_cnt;
    reg        tx_active;

    assign tx_o    = tx_active ? tx_frame[tx_bit] : 1'b1;
    assign tx_busy = tx_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_frame  <= 10'h3FF;
            tx_bit    <= 4'd0;
            tx_cnt    <= 16'd0;
            tx_active <= 1'b0;
        end else if (!enable) begin
            tx_active <= 1'b0;
        end else if (tx_start && !tx_active) begin
            tx_frame  <= {1'b1, tx_data, 1'b0};
            tx_bit    <= 4'd0;
            tx_cnt    <= 16'd0;
            tx_active <= 1'b1;
        end else if (tx_active) begin
            if (tx_cnt >= (div_safe - 16'd1)) begin
                tx_cnt <= 16'd0;
                if (tx_bit == 4'd9)
                    tx_active <= 1'b0;
                else
                    tx_bit <= tx_bit + 1'b1;
            end else begin
                tx_cnt <= tx_cnt + 1'b1;
            end
        end
    end
endmodule
