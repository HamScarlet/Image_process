// ============================================================================
//  rgb4_downscale_8_15  ——  8/15 抽取降采样（A1 相位重叠平均版）
//  与原"点抽样版"的唯一区别：取点动作由"直接取 1 个像素"改为
//  "取相邻 3 个像素、按覆盖面积加权平均" —— 权重和恒为 15、零乘法器
//  1920×1080 → 1024×576，4 像素/拍，I_tdata = 4 × {8'b0, R8, G8, B8}
//  ⚠ 端口名与实际方向相反（同原版）：I_tready 是模块产生的反压，O_tready 是下游能否接收
// ============================================================================
module rgb4_downscale_8_15 (
    input  wire         I_clk,
    input  wire         I_rst_n,
    input  wire [127:0] I_tdata,    // 输入 4 像素
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

    // ---------- 相位机状态（与原版完全一致，未改动） ----------
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

    // ---------- A1 新增（改动 1）：输入延迟一拍 + 3 点加权所需 ----------
    // 为什么必须延迟：4 像素/拍 且相位在拍内串行推进（lane0→lane3），所以
    //   · 取点位置 x 的"右邻 x+1"，当 x 落在 lane3 时会跑到**下一拍**
    //     （例：x = 15，需要像素 16 = 下一拍的 lane0）→ 靠 w5 取
    //   · "左邻 x−1"，当 x 落在 lane0 时会落在**上一拍**
    //     （例：x = 4，需要像素 3 = 上一拍的 lane3）→ 靠 p_prev 取
    // 两个方向都需要，所以必须让"上一拍 + 本拍"共 8 个像素同时可见。
    reg [127:0] d1_tdata;               // 输入延迟一拍（无条件采样的纯延迟链）
    reg         d1_tlast;
    reg         d1_tuser;
    reg         d1_tvalid;
    reg [31:0]  p_prev;                 // 上一拍的 lane3，补 lane0 的 x−1
    reg [2:0]   n_cnt;                  // 输出像素在一行内的序号 mod 8（3 bit 自然回绕即 mod 8）
    reg [2:0]   n_cnt_work;
    reg [31:0]  px_l, px_m, px_r;       // 左 / 中 / 右三个输入像素（中 = 相位机取点位置）
    reg [11:0]  s_r, s_g, s_b;          // 三分量加权和，最大 15×255 = 3825
    reg [23:0]  t_r, t_g, t_b;          // ×4369 后的中间值，最大 16 711 425 < 2^24

    // 6 像素可见窗口：w0 补 lane0 的左邻，w1~w4 是 d1 的 4 个 lane，w5 是下一拍的 lane0
    wire [31:0] w0 = p_prev;            // 上一拍 lane3
    wire [31:0] w1 = d1_tdata[31:0];    // lane0
    wire [31:0] w2 = d1_tdata[63:32];   // lane1
    wire [31:0] w3 = d1_tdata[95:64];   // lane2
    wire [31:0] w4 = d1_tdata[127:96];  // lane3
    wire [31:0] w5 = I_tdata[31:0];     // 下一拍 lane0

    assign I_tready = ~O_tvalid | O_tready;      // ← 不改：d1 是无条件延迟链，反压式沿用

    always @* begin
        h_phase_next = h_phase;
        v_phase_next = v_phase;
        pack_count_next = pack_count;
        pack_data_next = pack_data;
        scaled_word = 128'd0;
        scaled_push = 1'b0;
        // 行首用 d1_tuser：整个逻辑已搬到"延迟一拍"的数据域
        line_v_phase = d1_tuser ? 4'd7 : v_phase;       // ← 改动 2
        h_phase_work = d1_tuser ? 4'd7 : h_phase;       // ← 改动 3
        pack_count_work = d1_tuser ? 2'd0 : pack_count; // ← 改动 4
        pack_data_work = d1_tuser ? 128'd0 : pack_data; // ← 改动 5
        n_cnt_work = d1_tuser ? 3'd0 : n_cnt;           // ← 改动 6：相位计数随行归零
        pixel_work = 32'd0;
        px_l = 32'd0; px_m = 32'd0; px_r = 32'd0;
        s_r = 12'd0; s_g = 12'd0; s_b = 12'd0;
        t_r = 24'd0; t_g = 24'd0; t_b = 24'd0;

        if (d1_tvalid && I_tready) begin                // ← 改动 7：推进条件改用 d1 域
            if (line_v_phase >= 4'd7) begin             // 垂直抽取：整行取 / 整行舍（同原版）
                for (lane = 0; lane < 4; lane = lane + 1) begin
                    if (h_phase_work >= 4'd7) begin
                        h_phase_work = h_phase_work - 4'd7;   // 相位回退 7 → 选中该像素

                        // ---------- 改动 8：按 lane 取三点，再三分量加权 ----------
                        // 【取点位置与输出序号的关系】
                        //   相位机取中的输入像素 x = 0,2,4,6,8,10,12,14,15,17,19,...
                        //   即 k=0..7 时 x=2k，k=8..15 时 x=15,17,...,29
                        //   令 n = k mod 8，则 n 恰好等于"输出区间起点的小数部分 ×8"
                        //   于是一个输出像素覆盖的区间 [1.875k, 1.875k+1.875] 只会跨
                        //   2 或 3 个输入像素，且权重（以 1/8 为单位，和恒为 15）为：
                        //       n=0 → (0, 8, 7)   n=4 → (4, 8, 3)
                        //       n=1 → (1, 8, 6)   n=5 → (5, 8, 2)
                        //       n=2 → (2, 8, 5)   n=6 → (6, 8, 1)
                        //       n=3 → (3, 8, 4)   n=7 → (7, 8, 0)
                        //   ⇒ 归纳为「左 = n、中 = 8、右 = 7 − n」，中心恒占 8/15 ≈ 53%
                        //   ⇒ n=0 时左权重为 0、n=7 时右权重为 0，所以行首/行末天然安全
                        case (lane)
                            0:       begin px_l = w0; px_m = w1; px_r = w2; end
                            1:       begin px_l = w1; px_m = w2; px_r = w3; end
                            2:       begin px_l = w2; px_m = w3; px_r = w4; end
                            default: begin px_l = w3; px_m = w4; px_r = w5; end
                        endcase

                        // 三点加权：RGB 三分量必须**各自独立**运算！
                        // 若写成整体 32 bit 相乘 px_l * n，B 字段乘 8 会溢出到 G 字段
                        // 权重和恒为 15 ⇒ 结果最大 15×255 = 3825，12 bit 足够
                        s_r = px_l[23:16] * n_cnt_work + (px_m[23:16] << 3)
                            + px_r[23:16] * (3'd7 - n_cnt_work);
                        s_g = px_l[15: 8] * n_cnt_work + (px_m[15: 8] << 3)
                            + px_r[15: 8] * (3'd7 - n_cnt_work);
                        s_b = px_l[ 7: 0] * n_cnt_work + (px_m[ 7: 0] << 3)
                            + px_r[ 7: 0] * (3'd7 - n_cnt_work);

                        // 归一化：×4369 >> 16 即 /15
                        // 4369 = 65536/15 = 2^12 + 2^8 + 2^4 + 1 ⇒ 纯移位加法，零乘法器
                        // 3825×4369 = 16 711 425 → >>16 = 255，满量程精确不损失
                        t_r = (s_r << 12) + (s_r << 8) + (s_r << 4) + s_r;
                        t_g = (s_g << 12) + (s_g << 8) + (s_g << 4) + s_g;
                        t_b = (s_b << 12) + (s_b << 8) + (s_b << 4) + s_b;

                        // 组装回 {8'b0, R8, G8, B8} 布局，与原版完全一致
                        pixel_work = {8'd0, t_r[23:16], t_g[23:16], t_b[23:16]};

                        n_cnt_work = n_cnt_work + 3'd1;     // 输出序号 +1（3 bit 自然回绕 = mod 8）

                        // 组包：攒满 4 个输出像素才推一拍（逻辑同原版）
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
                        h_phase_work = h_phase_work + 4'd8;   // 跳过该像素，相位前进 8
                    end
                end
            end

            // 把工作变量写回 next 寄存器
            h_phase_next = h_phase_work;
            pack_count_next = pack_count_work;
            pack_data_next = pack_data_work;
            if (d1_tuser)                               // ← 改动 9
                v_phase_next = 4'd7;

            // 行末：水平相位与组包复位；垂直相位用同一规则推进一次（同原版）
            if (d1_tlast) begin                         // ← 改动 10
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
            d1_tdata <= 128'd0;                         // ← 改动 11：新增寄存器复位
            d1_tlast <= 1'b0;
            d1_tuser <= 1'b0;
            d1_tvalid <= 1'b0;
            p_prev <= 32'd0;
            n_cnt <= 3'd0;
        end else begin
            // ---------- 改动 12：输入无条件延迟一拍 ----------
            // 关键：这里是"无条件"的，不挂在握手条件里。
            // 这样 d1 恒等于 I 的上一拍 ⇒ w5 = I_tdata[31:0] 恒为 d1 的下一拍，
            // 即使下游出现反压导致握手失败，像素之间的相对关系也不会错位。
            d1_tdata  <= I_tdata;
            d1_tlast  <= I_tlast;
            d1_tuser  <= I_tuser;
            d1_tvalid <= I_tvalid;
            // p_prev 比 d1 再早一拍：本拍存的是"上一拍的 lane3"，
            // 下一拍正好用来补 d1 域 lane0 的左邻 x−1
            p_prev    <= d1_tdata[127:96];

            // 输出握手：下游取走后清 O_tvalid；O_tlast/O_tuser 同时清零，
            // 保证标记只在"带数据的那一拍"有效
            // Keep line/frame markers aligned with valid data, and clear them
            // when the output beat is consumed.
            if (O_tvalid && O_tready) begin
                O_tvalid <= 1'b0;
                O_tlast <= 1'b0;
                O_tuser <= 1'b0;
            end

            if (d1_tvalid && I_tready) begin                // ← 改动 13
                h_phase <= h_phase_next;
                v_phase <= v_phase_next;
                pack_count <= pack_count_next;
                pack_data <= pack_data_next;
                n_cnt <= n_cnt_work;                        // ← 改动 14：相位计数同步更新

                if (d1_tuser)                               // ← 改动 15
                    frame_start_pending <= 1'b1;

                if (scaled_push) begin                      // 攒满 4 像素 → 推一拍输出
                    O_tdata <= scaled_word;
                    O_tlast <= d1_tlast;                    // ← 改动 16
                    O_tuser <= frame_start_pending | d1_tuser;  // ← 改动 17
                    O_tvalid <= 1'b1;
                    if (frame_start_pending | d1_tuser)     // ← 改动 18
                        frame_start_pending <= 1'b0;
                end
            end
        end
    end

endmodule