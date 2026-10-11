# ISP 调试记录

> 日期：2026-10-10 ｜ 工程：`mymipi_hdmi2\soc_prj` ｜ 板卡：米联客 MLK-F3P-CZ02 / DR1M90GEG400
> 关联：[[初版内置ISP参数详解与应用建议]] ｜ [[初版内置ISP图形化链路]] ｜ [[8-15像素抽取降采样图形化链路]] ｜ [[移植尝试记录]]
> 定位：本文只记**调参过程中发现的画质问题与处置**；各级参数原理、现值与调参建议见 [[初版内置ISP参数详解与应用建议]]。

## 1. 淡淡的网格纹

###### 现象：
ISP 参数调整后画面整体可接受，但存在**淡淡的规则网格纹**。属抽取算法固有特征，**不是故障**。

###### 原因（`rgb4_downscale_8_15.v` 相位分配，逐拍点算得出）：
取点规则是 `if (h_phase >= 7) 取该点, h_phase -= 7; else h_phase += 8;`（L53~L54 / L83~L84），初值 7。逐拍展开后，**被取中的输入像素序号**是：

```
0 2 4 6 8 10 12 14 | 15 17 19 21 23 25 27 29 | 30 ...
└── 七个间隔 2 ─────┘ └── 一个间隔 1 ────────┘  ← 每 15 个输入像素重复
```

- 一个周期 = **15 个输入像素 → 8 个输出像素**。1920 = 128×15 ⇒ 全宽 **128 个周期**；垂直同样 1080 = 72×15 ⇒ **72 个周期**
- 采样间隔在 **2 与 1 之间周期跳动**（平均 1.875）⇒ 局部放大率抖 **±6%** ⇒ 对画面内容产生**周期性调制**
- 水平 × 垂直叠加 ⇒ **周期 8×8 屏幕像素的方格**（1024 宽上 128 格、576 行上 72 格）。周期太小，所以是"淡淡的"

**本质**：分数重采样（1.875）在整数像素格上**必然**是非均匀间隔 —— 任何"每 15 取 8"的最近邻实现都躲不掉这个网格。

###### 判据（先归因再动手，四种机制要分清）：
| 观察 | 归因 | 方向 |
|---|---|---|
| 只在实际画面内容上有格，对着**纯色/白纸**看不到 | 相位抖动（对内容调制） | 改线性插值重采样 |
| 对着**纯色也**能看到静态网格 | 面板 scaler 或 DDR/VTC 通路 | 查面板是否 1:1；试 `VIDEO_TPG` |
| 网格随镜头轻移**闪动/爬行** | 混叠（摩尔纹） | 加低通 |
| 网格**是彩色的** | 去马赛克残留被饱和放大 | 降 `ADJUST_VAL` |

**最硬的验证**：对齐屏幕数格子 —— 水平应正好 **128 格**、垂直 **72 格**（即周期 8 px）。

###### 处置：
**① 治标（改 ISP 参数即可，零成本）** —— 网格纹幅度被这两个参数放大：

- `isp_top.v:224` `contrast_level` 140 → **128 甚至 120**
  ⚠️ 对比度是网格纹的放大器，**与"更清晰"直接冲突**：把 contrast 调到 155~165 一定会让网格变明显。
- `isp_top.v:259` `ADJUST_VAL` 130 → **90~100**（消掉网格的彩色成分，通常效果最明显）

代价：画面整体变软。这是"干净 ↔ 锐利"的取舍。

**② 治本（改 RTL，把"取点"改成"按相位线性插值"）**

输出第 k 个像素对应输入位置 `x = k × 15/8`：

```
i = floor(x),  frac = x − i
out = in[i] × (1 − frac) + in[i+1] × frac
```

- `frac` 只有 **8 个取值**（`n/8`，`n = (7k) mod 8`）⇒ **移位 + 加法即可，无乘法器**
- 采样间隔变成严格均匀的 1.875，且线性插值本身是一阶低通 ⇒ **网格纹 + 摩尔纹 + 锯齿一起消掉**
- 代价：垂直方向要 **1 个行缓存**（约 2 个 ERAM20K），水平方向只要 1 个像素寄存器
- 折中：只做垂直方向（水平保留现取点），能改善约一半，且只加行缓存

###### 上板判据：
| 项 | 应然 |
|---|---|
| 纯色测试 | 对纯色画面**不应**出现网格（若出现 ⇒ 归因转到面板 scaler / DDR·VTC 通路） |
| 网格周期 | 水平 **128 格**、垂直 **72 格** |
| 改参数后 | `ADJUST_VAL` 降 40 左右，网格的彩色成分应明显变淡 |

## 2. 采样优化方案
##### 原`rgb4_downscale_8_15`代码：
```verilog
// ============================================================================
//  rgb4_downscale_8_15  ——  8/15 整数比抽取降采样（原点抽样版）
//  用途：1920×1080 → 1024×576（水平 1920×8/15 = 1024，垂直 1080×8/15 = 576）
//  数据格式：AXI4-Stream 风格，4 像素/拍
//            I_tdata[127:0] = 4 × {8'b0, R8, G8, B8}
//            lane0 = [31:0]、lane1 = [63:32]、lane2 = [95:64]、lane3 = [127:96]
//  算法：Bresenham 式相位累加 + 最近邻点抽样（**不做任何加权平均**）
//  ⚠ 端口名与实际方向相反：I_tready 是模块"产生"的反压，O_tready 是"接收"的下游信号
// ============================================================================
module rgb4_downscale_8_15 (
    input  wire         I_clk,
    input  wire         I_rst_n,
    input  wire [127:0] I_tdata,    // 输入 4 像素
    input  wire         I_tlast,    // 行末标记
    input  wire         I_tuser,    // 行首标记
    input  wire         I_tvalid,
    output wire         I_tready,   // 实为输出方向：模块给上游的反压
    output reg  [127:0] O_tdata,    // 输出 4 像素（每 4 个被选中的像素组一包）
    output reg          O_tlast,
    output reg          O_tuser,
    output reg          O_tvalid,
    input  wire         O_tready    // 实为输入方向：下游能否接收
);

    // ---------- 相位机状态（跨拍保持） ----------
    reg [3:0] h_phase;              // 水平相位。规则：>=7 → 取该像素并 −7；否则跳过并 +8
    reg [3:0] v_phase;              // 垂直相位。规则同水平，但每行只推进一次（整行取或整行舍）
    reg [1:0] pack_count;           // 输出组包计数：被选中的像素攒满 4 个才推一拍 O_tvalid
    reg [127:0] pack_data;          // 组包缓冲
    reg frame_start_pending;        // 帧首标记待发（保证 O_tuser 搭在首个有效输出拍上）

    // ---------- 组合逻辑用的中间变量（不占寄存器） ----------
    reg [3:0] h_phase_next;
    reg [3:0] v_phase_next;
    reg [1:0] pack_count_next;
    reg [127:0] pack_data_next;
    reg [127:0] scaled_word;        // 本拍要输出的 4 像素字
    reg scaled_push;                // 本拍是否产生输出
    reg [3:0] line_v_phase;         // 本行适用的垂直相位（行首强制为 7）
    reg [3:0] h_phase_work;         // 一拍内 4 个 lane 串行推进用的水平相位
    reg [1:0] pack_count_work;
    reg [127:0] pack_data_work;
    reg [31:0] pixel_work;          // 当前被选中的单个像素
    integer lane;                   // for 循环变量（0~3）

    // 反压：输出寄存器已空（上一拍被取走）或下游能接收时，才放行输入
    assign I_tready = ~O_tvalid | O_tready;

    // 组合逻辑：在"本拍"内一次性推演完 "4 个像素串行过相位机 → 选中者组包" 的全过程
    // 之所以能一拍内算完 4 个像素：相位机是纯组合推进，lane 0→3 顺序执行
    always @* begin
        // 默认值 = 保持
        h_phase_next = h_phase;
        v_phase_next = v_phase;
        pack_count_next = pack_count;
        pack_data_next = pack_data;
        scaled_word = 128'd0;
        scaled_push = 1'b0;

        // 行首（I_tuser）强制归位：h_phase 初值 7 ⇒ 本行第 0 个像素必定被取中
        line_v_phase = I_tuser ? 4'd7 : v_phase;
        h_phase_work = I_tuser ? 4'd7 : h_phase;
        pack_count_work = I_tuser ? 2'd0 : pack_count;
        pack_data_work = I_tuser ? 128'd0 : pack_data;
        pixel_work = 32'd0;

        if (I_tvalid && I_tready) begin               // 握手成功才推进状态
            // 垂直抽取：本行输出还是丢弃（整行取 / 整行舍，行与行之间不做任何混合）
            if (line_v_phase >= 4'd7) begin
                // 一拍 4 个像素串行共用同一条水平相位链（lane 0 → lane 3）
                // ⚠ 这一点是后面所有"跨拍"问题的根源：
                //    lane0 的前一个像素落在上一拍，lane3 的后一个像素落在下一拍
                for (lane = 0; lane < 4; lane = lane + 1) begin
                    if (h_phase_work >= 4'd7) begin
                        // ---- 取中该像素：相位回退 7，本次产生一个输出像素 ----
                        // 边界：phase ∈ [7,14] 时 −7 得 [0,7]，不会下溢
                        //       （phase = 15 实际不可达，所以 4 bit 足够）
                        h_phase_work = h_phase_work - 4'd7;

                        // 按 lane 从 128 bit 中取出对应的 32 bit 像素
                        // 像素布局 = {8'b0, R8, G8, B8}，高 8 bit 恒为 0
                        case (lane)
                            0: pixel_work = {8'd0, I_tdata[23:0]};
                            1: pixel_work = {8'd0, I_tdata[55:32]};
                            2: pixel_work = {8'd0, I_tdata[87:64]};
                            default: pixel_work = {8'd0, I_tdata[119:96]};
                        endcase

                        // ---- 把选中的像素塞进组包缓冲（攒满 4 个才推一拍）----
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
                            default: begin                       // 第 4 个 → 打包输出
                                pack_data_work[127:96] = pixel_work;
                                scaled_word = pack_data_work;     // 本拍输出字
                                scaled_push = 1'b1;               // 本拍产生输出
                                pack_data_work = 128'd0;
                                pack_count_work = 2'd0;
                            end
                        endcase
                    end else begin
                        // ---- 跳过该像素：相位前进 8 ----
                        // 边界：只有 phase < 7 时才 +8（得 [8,14]），不会溢出 4 bit
                        h_phase_work = h_phase_work + 4'd8;
                    end
                end
            end

            // 把工作变量写回 next 寄存器
            h_phase_next = h_phase_work;
            pack_count_next = pack_count_work;
            pack_data_next = pack_data_work;
            if (I_tuser)                              // 行首重新开始
                v_phase_next = 4'd7;

            // 行末：水平相位与组包复位；垂直相位用同一规则推进一次
            if (I_tlast) begin
                h_phase_next = 4'd7;
                pack_count_next = 2'd0;
                pack_data_next = 128'd0;
                if (line_v_phase >= 4'd7)
                    v_phase_next = line_v_phase - 4'd7;   // 本行已输出 → 垂直相位回退 7
                else
                    v_phase_next = line_v_phase + 4'd8;   // 本行被丢弃 → 垂直相位前进 8
            end
        end
    end

    // 时序逻辑：所有跨拍状态在"握手成功"时统一更新
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            // 复位：相位初值均为 7（保证行首第 0 像素被取中），输出全部清空
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
            // 输出握手：下游取走后清 O_tvalid；O_tlast/O_tuser 同时清零，
            // 保证这两个标记只在"带数据的那一拍"有效，不会残留到下一拍。
            // Keep line/frame markers aligned with valid data, and clear them
            // when the output beat is consumed.
            if (O_tvalid && O_tready) begin
                O_tvalid <= 1'b0;
                O_tlast <= 1'b0;
                O_tuser <= 1'b0;
            end

            if (I_tvalid && I_tready) begin
                h_phase <= h_phase_next;
                v_phase <= v_phase_next;
                pack_count <= pack_count_next;
                pack_data <= pack_data_next;

                if (I_tuser)
                    frame_start_pending <= 1'b1;      // 记住"帧首待发"

                if (scaled_push) begin                // 攒满 4 像素 → 推一拍输出
                    O_tdata <= scaled_word;
                    O_tlast <= I_tlast;
                    O_tuser <= frame_start_pending | I_tuser;
                    O_tvalid <= 1'b1;
                    if (frame_start_pending | I_tuser)
                        frame_start_pending <= 1'b0;  // 帧首标记已随本拍发出，撤销
                end
            end
        end
    end

endmodule
```

#### 所有待选方案极简述：

按"改哪里"分四组，降噪量为**单级**幅度改善：

| 组       | 编号     | 方案           | 一句话                                 | 降噪             | 锐度损失  | 改动量 |
| ------- | ------ | ------------ | ----------------------------------- | -------------- | ----- | --- |
| A 水平采样核 | **A1** | **相位重叠平均**   | 按输出像素与输入像素的重叠长度加权（本页 P0 方案）         | **−3.6 dB**    | 中     | 小   |
| A       | A2     | 相位线性插值       | 2 点插值，`frac = n/8`，`n = (7k) mod 8` | −1.7 dB（最差 0）  | 小     | 小   |
| A       | A3     | 1-2-1 三点     | 在取点处做 (1,2,1)/4                     | −4.3 dB        | 中偏大   | 小   |
| A       | A4     | 8 相多相 FIR    | 8 相位 × 4 抽头，系数可优化                   | −6 ~ −9 dB     | 可调    | 大   |
| B 垂直方向  | B1     | 2 行平均        | 把"整行通过"改成两行相加取均                     | −3.0 dB（叠加）    | 中     | 中   |
| B       | B2     | 垂直相位重叠平均     | 与 A1 同核，作用于行                        | −3.6 dB（叠加）    | 中     | 中   |
| C 时间域   | C1     | 帧平均（2 / 3 帧） | 借 `uidbuf` 现有 3 帧缓冲                 | −3.0 / −4.8 dB | **零** | 中   |
| D RAW 域 | D1     | 同色 2×2 均值    | 复用 `raw_matrix_3x3_buffer` 现有窗口     | −6.0 dB        | 大     | 中   |

补充说明：

- **A 组**：只改水平，垂直仍是整行取/舍 ⇒ 只消掉水平方向的相位抖动，8×8 方格会退化成**竖条纹**。要全消必须配 B 组。
- **A2 vs A1**：两者工作量相当，但 A2 在 `n = 0` 的相位上完全不降噪也不抗混叠，A1 在每个相位都 ≥ −3.0 dB ⇒ **A1 严格更优**。
- **B 组**：现状 `line_v_phase >= 7` 决定**整行取或整行舍**，没有任何混合；改成行平均要把"单行流"变成"双行流"，是全部方案里**唯一需要动架构**的一步。
- **C 组**：唯一**不损失空间锐度**的路径（用时间换信噪比），代价是运动拖影；且当前 `uidbuf` 读写帧率本已 2× 不匹配（写 30 fps / 读 60 fps，同帧显示两次 ⇒ 是"重复"不是"平均"），要做真平均需改 `uisetvbuf` 读出逻辑。
- **D 组**：RAW 域在去马赛克前抑制噪点最有效，也是**唯一能顺带消固定坏点**的路径；但同色分量间距为 2，等效 2× 下采样，分辨率损失大。
- **不推荐**：把降采样整体搬到 RAW 域去做 —— 直接平均会破坏 Bayer 4 像素组，色彩会毁掉。

**组合效应与推荐分档**：A1 + B1 全做 ⇒ 幅度增益 0.65 × 0.707 ⇒ **约 −6.6 dB**，但画面明显变糊。故：**P0 只做 A1（−3.6 dB）**，上板验证后再决定是否加 B1。

**前提提醒**：数字域滤波不创造信息，所有 −dB 都是"用空间分辨率换信噪比"。当前真正的瓶颈是**照度不足 + 曝光已满（2246 行）+ 模拟增益在 8× 档（AG=60 → `0x3e08/09 = 0x072C`）**，应**先降 AG（到 ≤47 跨档）、补光**，两者不够再改算法。


#### P0-A1方案代码：（约 800~1500 LUT，）
#### 说明
**A1 = 相位重叠平均**：输出像素取**它在输入上的覆盖区间与各输入像素的重叠长度**作加权平均。因为重采样比恒为 15/8，"中"像素权重恒为 8、两翼权重之和恒为 7 —— 权重只有 8 个图案，全部是 1/8 的整数倍。

##### 权重图案（n = 输出像素在一行内的序号 mod 8）

| n | 左 | 中 | 右 |
|---|---|---|---|
| 0 | 0 | 8 | 7 |
| 1 | 1 | 8 | 6 |
| 2 | 2 | 8 | 5 |
| 3 | 3 | 8 | 4 |
| 4 | 4 | 8 | 3 |
| 5 | 5 | 8 | 2 |
| 6 | 6 | 8 | 1 |
| 7 | 7 | 8 | 0 |

即 **左 = n、中 = 8、右 = 7 − n**；"中"就是现有相位机的取点位置，所以相位机可完全不动。

##### 改动位置（唯一改动文件：`uisrc/01_rtl/my_image_process/rgb4_downscale_8_15.v`）

以**未改动的原文件（148 行）行号**为基准；「加在 X 之后」= 在 X 行之后插入新行。

| # | 位置 | 操作 |
|---|---|---|
| 1 | **L33** `integer lane;` 之后 | **加**：新增声明（延迟线 `d1_*`、`p_prev`、`n_cnt`/`n_cnt_work`、`px_l/px_m/px_r`、`s_r/s_g/s_b`、`t_r/t_g/t_b`）+ 6 根窗口 `wire w0~w5` |
| 2 | **L44** | `line_v_phase = I_tuser ?` → **`d1_tuser`** |
| 3 | **L45** | `h_phase_work = I_tuser ?` → **`d1_tuser`** |
| 4 | **L46** | `pack_count_work = I_tuser ?` → **`d1_tuser`** |
| 5 | **L47** | `pack_data_work = I_tuser ?` → **`d1_tuser`** |
| 6 | **L48** `pixel_work = 32'd0;` 之后 | **加**：`n_cnt_work = d1_tuser ? 3'd0 : n_cnt;`，以及 `px_* / s_* / t_*` 的清初值 |
| 7 | **L50** | `if (I_tvalid && I_tready)` → **`if (d1_tvalid && I_tready)`** |
| 8 | **L55~L60** `case (lane)` 取 `pixel_work` | **整段替换**为「按 lane 取 `px_l/px_m/px_r` → 三分量加权 → `pixel_work` 组装」，并在其后**加** `n_cnt_work = n_cnt_work + 3'd1;` |
| 9 | **L92** | `if (I_tuser)` → **`if (d1_tuser)`** |
| 10 | **L95** | `if (I_tlast)` → **`if (d1_tlast)`** |
| 11 | **L117** `O_tvalid <= 1'b0;` 之后（复位块内） | **加**：`d1_*`、`p_prev`、`n_cnt` 的复位 |
| 12 | **L118** `end else begin` 之后 | **加**：`d1` 的无条件一拍延迟 4 行 + `p_prev <= d1_tdata[127:96];` |
| 13 | **L127** | `if (I_tvalid && I_tready)` → **`if (d1_tvalid && I_tready)`** |
| 14 | **L131** `pack_data <= pack_data_next;` 之后 | **加**：`n_cnt <= n_cnt_work;` |
| 15 | **L133** | `if (I_tuser)` → **`if (d1_tuser)`** |
| 16 | **L138** | `O_tlast <= I_tlast;` → **`O_tlast <= d1_tlast;`** |
| 17 | **L139** | `O_tuser <= frame_start_pending \| I_tuser;` → **`d1_tuser`** |
| 18 | **L141** | `if (frame_start_pending \| I_tuser)` → **`d1_tuser`** |

**不需要改的**：**L35** `assign I_tready = ~O_tvalid | O_tready;` —— `d1` 做成**无条件延迟链**（每拍都采样输入），所以反压表达式保持原样即可。

**改动后行数**：148 → **206 行**（净增 58 行，含新增注释与分隔空行）。

##### 关键片段

可见窗口（lane 串行取数，6 个像素刚好够用）：

```verilog
wire [31:0] w0 = p_prev;            // 上一拍 lane3
wire [31:0] w1 = d1_tdata[31:0];    // lane0
wire [31:0] w2 = d1_tdata[63:32];   // lane1
wire [31:0] w3 = d1_tdata[95:64];   // lane2
wire [31:0] w4 = d1_tdata[127:96];  // lane3
wire [31:0] w5 = I_tdata[31:0];     // 下一拍 lane0

// lane 循环内按 lane 取三元组
case (lane)
    0:       begin px_l = w0; px_m = w1; px_r = w2; end
    1:       begin px_l = w1; px_m = w2; px_r = w3; end
    2:       begin px_l = w2; px_m = w3; px_r = w4; end
    default: begin px_l = w3; px_m = w4; px_r = w5; end
endcase
```

加权与归一化。⚠️ RGB 三分量必须**各自独立**运算 —— 整体 32 bit 相乘会跨字段进位，G/B 溢出会串进 R。`×4369 >> 16` 即 `/15`（4369 = 2^12+2^8+2^4+1，纯移位加法，**零乘法器**）：

```verilog
s_r = px_l[23:16] * n_cnt_work + (px_m[23:16] << 3) + px_r[23:16] * (3'd7 - n_cnt_work);
s_g = px_l[15: 8] * n_cnt_work + (px_m[15: 8] << 3) + px_r[15: 8] * (3'd7 - n_cnt_work);
s_b = px_l[ 7: 0] * n_cnt_work + (px_m[ 7: 0] << 3) + px_r[ 7: 0] * (3'd7 - n_cnt_work);

t_r = (s_r << 12) + (s_r << 8) + (s_r << 4) + s_r;   // = s_r * 4369
t_g = (s_g << 12) + (s_g << 8) + (s_g << 4) + s_g;
t_b = (s_b << 12) + (s_b << 8) + (s_b << 4) + s_b;

pixel_work = {8'd0, t_r[23:16], t_g[23:16], t_b[23:16]};
```

##### 边界天然安全，不需要额外处理

每行输出 **1024 = 128 × 8**，正好 128 个完整周期：

- 每行**首**像素 `n = 0` ⇒ 左权重为 0 ⇒ `p_prev` 在行首不被使用
- 每行**末**像素 `n = 7` ⇒ 右权重为 0 ⇒ 行末不需要 `I_tdata[31:0]`

##### 代价与收益

| 项     | 值                                                                                     |
| ----- | ------------------------------------------------------------------------------------- |
| 新增寄存器 | `d1` 延迟线 131 + `p_prev` 32 + `n_cnt` 3 ≈ **166 FF**（窗口 `wire` 与 `px/s/t` 均为组合量，不占 FF） |
| 新增组合  | 4 lane × 3 分量 × 2 个 8bit×3bit 加权 + 归一化移位加 ⇒ **约 800~1500 LUT，零 DSP**                  |
| 收益    | 噪点 **−3.6 dB**；8×8 网格纹消失；混叠与锯齿减轻                                                      |
| 代价    | 画面整体变软（1.875 倍重采样本质是"用空间分辨率换信噪比"）                                                     |

##### 改动时不要破坏的前提

- `h_phase` 是 4 bit，`+8` 只在 `phase < 7` 时执行（否则溢出）；`phase = 15` 实际不可达
- `n_cnt` 必须与相位机同步：在 `d1_tuser` 归零，之后每个被选中的输出像素 +1
- `O_tvalid/O_tdata` 的组包时序会整体晚一拍，`tuser/tlast` 的对齐要跟着重算

#### 完整改后代码

按上面 18 处标记改完后的完整模块（148 → 206 行）。`←` 注释标出每处改动对应的行。

```verilog
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
```
