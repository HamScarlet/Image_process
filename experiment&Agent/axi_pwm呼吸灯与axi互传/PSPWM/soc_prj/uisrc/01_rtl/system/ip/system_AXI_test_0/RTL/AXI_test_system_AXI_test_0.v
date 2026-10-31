`timescale 1ns/1ps

//=============================================================================
// AXI_test —— PS <-> PL AXI4-Lite 通路的最小可验证从端
//
// 目的：不引入任何外设逻辑，只回答一个问题 ——
//       「PS 写进 PL 的数、以及 PL 自己产生的数，PS 能不能读回来？」
//
// 设计原则：为"故障定位"服务，不为"功能"服务。
//   三组寄存器分别独立地证明一条通路，读错哪一组就知道断在哪一环：
//
//     组别          寄存器        它证明了什么                  读错的含义
//     ----------    ----------    --------------------------    ----------------------
//     ① 读通路      ID / VER      地址映射、AXI 读握手          地址算错 / 没连上 / 从端没选通
//     ② 写通路      SCR0 / SCR1   PS 写 -> PL 存 -> PS 读回     写握手坏 / wstrb 没处理 / 地址译码串了
//     ③ PL 产生数据 LIVE_LO/HI    PL 时钟在跑，且数据是 PL 给的  PL 没时钟（p2f_clk0 没接）/ 计数器没综合进去
//     ③ 附 常量     PAT0..PAT3    绕过计数器，单独证明"读常量"  与 ① 对照可区分"常量读不出"vs"计数器不动"
//     ④ 控制-状态   CMD/STATUS    PS 触发 -> PL 执行 -> PS 轮询  双向时序、握手延迟、轮询可见性
//                   /COUNT
//
// 寄存器映射（偏移 + 基址，32 位访问；基址由 DI 的 Address Editor 分配）
//
//   0x00  ID         RO   0x41584954  ('A''X''I''T')  —— 读到它说明整条 AXI 通路基本通了
//   0x04  VER        RO   0x00010000
//   0x08  SCR0       RW   PS 可写可读，上电为 0
//   0x0C  SCR1       RW   第二组，用来发现"两个地址实际落到同一个寄存器"
//   0x10  LIVE_LO    RO   自由运行计数器 [31:0]
//   0x14  LIVE_HI    RO   自由运行计数器 [63:32]
//   0x18  PAT0       RO   0xA5A50000
//   0x1C  PAT1       RO   0xA5A50001
//   0x20  PAT2       RO   0x5A5A0002
//   0x24  PAT3       RO   0x5A5A0003
//   0x28  CMD        W    [0]=START 启动一次 PL 侧计数（自清零），[1]=CLR 清 COUNT/DONE
//   0x2C  STATUS     RO   [0]=BUSY, [1]=DONE
//   0x30  COUNT      RO   START 之后 PL 累加到的计数，跑满 RUN_TARGET 停住并置 DONE
//
// 一次完整的 ④ 流程：
//     PS: 写 CMD[1]=1 (CLR)  -> 读 STATUS 应为 0
//        写 CMD[0]=1 (START) -> 立刻读 STATUS 应看到 BUSY=1
//        轮询 STATUS 直到 DONE=1（RUN_TARGET=0x100000，约 5 ms @200MHz，轮询一定抓得到）
//        读 COUNT 应等于 0x100000
//     这一步同时验证了：PS 写、PL 反应、PS 轮询、PS 读，四件事都活着。
//
//-----------------------------------------------------------------------------
// 【连接方式】（与 axi_lite_pwm 完全一致，已经在板上跑通的那套）
//     s_axi_aclk    <- p2f_clk0      （本工程实测 199.98 MHz）
//     s_axi_aresetn <- p2f_rst0_n    （低有效）
//
// 【两个必须照抄的坑，来自 axi_lite_pwm.v 的实测记录，别重犯】
//   1) 地址端口必须硬写 [31:0]，不能写成 [C_S_AXI_ADDR_WIDTH-1:0]。
//      本工程 GP0 后面的 AXI Matrix / Protocol Converter 用 32 位地址，
//      而 TD 的 Module Packager 无法 elaborate 参数化位宽的范围表达式，
//      会把这种端口报成 1 bit，DI 里的 AXI 连接直接断掉。
//      -> 所以这里不设地址宽度参数，只解码低 8 位（窗口 4 KB 里只用到 256 字节）。
//   2) 不要把任何参数的表达式用进端口范围。参数只用来定常量（如 RUN_TARGET），
//      一旦出现在范围里就回到坑 1。
//
// 【未映射地址与只读寄存器的处理策略】
//    - 未映射地址 -> BRESP/RRESP = SLVERR(2'b10)：PS 侧地址算错时能立刻发现，
//      而不是"读到一个 0 还以为正常"。
//    - 对只读寄存器执行写 -> 忽略数据，返回 OKAY：故意宽容，避免测试期间
//      PS 侧因为一个笔误吃到总线异常，把真正要看的现象盖掉。
//=============================================================================

module AXI_test_system_AXI_test_0 #(
    // ④ 组的目标值。0x100000 = 1,048,576 拍，@200MHz 约 5.24 ms，
    // 足够长，PS 侧轮询一定能看到 BUSY=1 -> DONE=1 的过程；
    // 又足够短，不会让一次手测卡住。
    parameter [31:0] RUN_TARGET = 32'h0010_0000
)(
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    // ---- AXI4-Lite 写地址通道 ----
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    // ---- AXI4-Lite 写数据通道 ----
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    // ---- AXI4-Lite 写响应通道 ----
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    // ---- AXI4-Lite 读地址通道 ----
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    // ---- AXI4-Lite 读数据通道 ----
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready
);

    //------------------------------------------------------------------
    // 寄存器地址译码（只用低 8 位）
    //------------------------------------------------------------------
    localparam [7:0] REG_ID       = 8'h00;
    localparam [7:0] REG_VER      = 8'h04;
    localparam [7:0] REG_SCR0     = 8'h08;
    localparam [7:0] REG_SCR1     = 8'h0C;
    localparam [7:0] REG_LIVE_LO  = 8'h10;
    localparam [7:0] REG_LIVE_HI  = 8'h14;
    localparam [7:0] REG_PAT0     = 8'h18;
    localparam [7:0] REG_PAT1     = 8'h1C;
    localparam [7:0] REG_PAT2     = 8'h20;
    localparam [7:0] REG_PAT3     = 8'h24;
    localparam [7:0] REG_CMD      = 8'h28;
    localparam [7:0] REG_STATUS   = 8'h2C;
    localparam [7:0] REG_COUNT    = 8'h30;

    //------------------------------------------------------------------
    // 读常量
    //------------------------------------------------------------------
    localparam [31:0] ID_VALUE    = 32'h4158_4954;  // "AXIT"
    localparam [31:0] VER_VALUE   = 32'h0001_0000;

    localparam [31:0] PAT0_VALUE  = 32'hA5A5_0000;
    localparam [31:0] PAT1_VALUE  = 32'hA5A5_0001;
    localparam [31:0] PAT2_VALUE  = 32'h5A5A_0002;
    localparam [31:0] PAT3_VALUE  = 32'h5A5A_0003;

    //------------------------------------------------------------------
    // 内部寄存器
    //------------------------------------------------------------------
    reg  [31:0] scr0_reg;        // ② 写通路
    reg  [31:0] scr1_reg;

    reg  [63:0] live_cnt;        // ③ PL 自由运行计数器
    reg  [31:0] run_cnt;         // ④ PL 受控计数
    reg         run_busy;
    reg         run_done;

    //------------------------------------------------------------------
    // AXI 握手（AW / W 各自独立受理，两个都到齐才算一次写）
    //------------------------------------------------------------------
    reg         aw_pending;
    reg         w_pending;
    reg  [31:0] awaddr_hold;
    reg  [31:0] wdata_hold;
    reg  [3:0]  wstrb_hold;

    wire        aw_fire;
    wire        w_fire;
    wire        write_commit;
    wire [31:0] write_addr;
    wire [31:0] write_data;
    wire [3:0]  write_strb;

    reg  [31:0] read_data_mux;
    reg         read_addr_valid_mux;

    assign s_axi_awready = !aw_pending && !s_axi_bvalid;
    assign s_axi_wready  = !w_pending  && !s_axi_bvalid;
    assign s_axi_arready = !s_axi_rvalid;

    assign aw_fire = s_axi_awvalid && s_axi_awready;
    assign w_fire  = s_axi_wvalid  && s_axi_wready;

    assign write_commit = (aw_pending || aw_fire) &&
                          (w_pending  || w_fire)  &&
                          !s_axi_bvalid;

    assign write_addr = aw_pending ? awaddr_hold : s_axi_awaddr;
    assign write_data = w_pending  ? wdata_hold  : s_axi_wdata;
    assign write_strb = w_pending  ? wstrb_hold  : s_axi_wstrb;

    // CMD 的写译码，单独提出来给"受控计数"那段用。
    // 原因：受控计数和写 case 都在同一个 always 块里改 run_cnt/run_busy，
    // 若不加这个互斥，CLR 的那一拍会被紧随其后的 run_cnt+1 覆盖掉
    // （非阻塞赋值下后写的赢），表现为"清了没清干净"。
    wire cmd_write = write_commit && (write_addr[7:0] == REG_CMD) && write_strb[0];
    wire do_clear  = cmd_write && write_data[1];
    wire do_start  = cmd_write && write_data[0] && !write_data[1];

    //------------------------------------------------------------------
    // 字节选通合并：只把 wstrb 选中的字节写进去
    //   PS 侧用 8 位/16 位访问时，wstrb 会只亮部分位；
    //   如果这里直接整字覆盖，会出现"写一个字节，另外三个字节被清零"的怪现象。
    //------------------------------------------------------------------
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

    //------------------------------------------------------------------
    // 读数据选择
    //   写只读寄存器不在这里体现；未映射地址置 read_addr_valid_mux = 0 -> SLVERR
    //------------------------------------------------------------------
    always @* begin
        read_data_mux       = 32'd0;
        read_addr_valid_mux = 1'b1;
        case (s_axi_araddr[7:0])
            REG_ID:      read_data_mux = ID_VALUE;
            REG_VER:     read_data_mux = VER_VALUE;
            REG_SCR0:    read_data_mux = scr0_reg;
            REG_SCR1:    read_data_mux = scr1_reg;
            REG_LIVE_LO: read_data_mux = live_cnt[31:0];
            REG_LIVE_HI: read_data_mux = live_cnt[63:32];
            REG_PAT0:    read_data_mux = PAT0_VALUE;
            REG_PAT1:    read_data_mux = PAT1_VALUE;
            REG_PAT2:    read_data_mux = PAT2_VALUE;
            REG_PAT3:    read_data_mux = PAT3_VALUE;
            REG_STATUS:  read_data_mux = {30'd0, run_done, run_busy};
            REG_COUNT:   read_data_mux = run_cnt;
            REG_CMD:     read_data_mux = 32'd0;   // 写专用；读回 0，不报错
            default: begin
                read_data_mux       = 32'd0;
                read_addr_valid_mux = 1'b0;   // -> SLVERR
            end
        endcase
    end

    //------------------------------------------------------------------
    // PL 侧数据产生
    //   live_cnt 自由跑：只要 p2f_clk0 到了 PL，它就在动。
    //   这是"PL 自己产生数据、PS 读走"的最直接证据 ——
    //   PS 从没写过这个寄存器，读两次值不同就说明是 PL 给的。
    //------------------------------------------------------------------
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn)
            live_cnt <= 64'd0;
        else
            live_cnt <= live_cnt + 64'd1;
    end

    //------------------------------------------------------------------
    // AXI-Lite 从端主状态机
    //------------------------------------------------------------------
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            aw_pending   <= 1'b0;
            w_pending    <= 1'b0;
            awaddr_hold  <= 32'd0;
            wdata_hold   <= 32'd0;
            wstrb_hold   <= 4'd0;

            s_axi_bresp  <= 2'b00;
            s_axi_bvalid <= 1'b0;
            s_axi_rdata  <= 32'd0;
            s_axi_rresp  <= 2'b00;
            s_axi_rvalid <= 1'b0;

            scr0_reg     <= 32'd0;
            scr1_reg     <= 32'd0;

            run_cnt      <= 32'd0;
            run_busy     <= 1'b0;
            run_done     <= 1'b0;
        end else begin

            // ---------- 写地址 / 写数据的暂存 ----------
            if (aw_fire && !write_commit) begin
                awaddr_hold <= s_axi_awaddr;
                aw_pending  <= 1'b1;
            end
            if (w_fire && !write_commit) begin
                wdata_hold <= s_axi_wdata;
                wstrb_hold <= s_axi_wstrb;
                w_pending  <= 1'b1;
            end

            // ---------- 写响应回收 ----------
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;

            // ---------- 写生效 ----------
            if (write_commit) begin
                aw_pending   <= 1'b0;
                w_pending    <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;

                case (write_addr[7:0])
                    REG_SCR0: begin
                        scr0_reg <= merge_wstrb(scr0_reg, write_data, write_strb);
                    end
                    REG_SCR1: begin
                        scr1_reg <= merge_wstrb(scr1_reg, write_data, write_strb);
                    end

                    REG_CMD: begin
                        // CLR 优先于 START：同一次写两个位都置 1 时以 CLR 为准
                        if (do_clear) begin
                            run_cnt  <= 32'd0;
                            run_busy <= 1'b0;
                            run_done <= 1'b0;
                        end else if (do_start) begin
                            run_cnt  <= 32'd0;
                            run_busy <= 1'b1;
                            run_done <= 1'b0;
                        end
                    end

                    // 只读寄存器：故意忽略写入并回 OKAY（见文件头说明）
                    REG_ID, REG_VER,
                    REG_LIVE_LO, REG_LIVE_HI,
                    REG_PAT0, REG_PAT1, REG_PAT2, REG_PAT3,
                    REG_STATUS, REG_COUNT: begin
                        /* ignore, OKAY */
                    end

                    // 未映射地址：报 SLVERR，便于发现 PS 侧地址算错
                    default: begin
                        s_axi_bresp <= 2'b10;
                    end
                endcase
            end

            // ---------- 读响应回收 ----------
            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;

            // ---------- 读受理 ----------
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rdata  <= read_data_mux;
                s_axi_rresp  <= read_addr_valid_mux ? 2'b00 : 2'b10;
                s_axi_rvalid <= 1'b1;
            end

            // ---------- ④ 受控计数 ----------
            // !do_clear && !do_start：这两拍由上面的 case 负责，这里让开，
            // 否则同一拍会有两个地方给 run_cnt 赋值（后写的赢，CLR 就失效了）。
            if (run_busy && !do_clear && !do_start) begin
                if (run_cnt >= RUN_TARGET) begin
                    run_busy <= 1'b0;
                    run_done <= 1'b1;      // COUNT 停在 RUN_TARGET 上不再加
                end else begin
                    run_cnt <= run_cnt + 32'd1;
                end
            end
        end
    end

endmodule


