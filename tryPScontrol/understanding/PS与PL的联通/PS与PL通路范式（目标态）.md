# 目标态 PS↔PL 通路范式 · 理想态总控系统各类型交互该走哪条线

> 工程：AnLu 智能交通辅助 ｜ 平台：安路飞龙 DR1M90GEG400（PS 双核 A35 + NPU 0.4 TOPS + PL 52,480 LUT6 / 240 DSP）
> 底稿：`00-路线/规划-AnLu智能交通辅助-v2架构重构版.md` §1.4–§1.6（D1–D6 决策 / I1–I10 接口契约 / C1–C11 硬约束）
> 现状实测：同目录《总控前的PS与PL关系全解.md》（底稿 = `mipiHDMIbySD` 基线）
> 本文回答一个问题：**理想态下每一类交互该走哪条线、为什么是这条、TD 里要动什么。** 现状是"三条线只有一条在跑"，本文给的是"三条线全部打通 + 两条新增"之后的样子。

---

## 一、图：目标态 PS↔PL 通路总图

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 560" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>目标态 PS 与 PL 之间的六条通路</title>
<desc>左列 PS 子系统、右列 PL、中列六条通路；已开为绿/黄，待开为红框，新增面为蓝框</desc>
<text x="120" y="30" font-size="12" font-weight="500" fill="#444441" text-anchor="middle">PS 子系统（硬核）</text>
<text x="340" y="30" font-size="12" font-weight="500" fill="#633806" text-anchor="middle">六条通路（目标态）</text>
<text x="560" y="30" font-size="12" font-weight="500" fill="#085041" text-anchor="middle">PL（FPGA 逻辑）</text>

<rect x="30" y="44" width="180" height="478" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<rect x="44" y="78" width="152" height="136" rx="8" fill="#FFFFFF" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="56" y="100" font-size="11" font-weight="500" fill="#444441">A35 双核 ×2</text>
<text x="56" y="120" font-size="10" fill="#5F5E5A">总控 / 人机 / 通信</text>
<text x="56" y="138" font-size="10" fill="#5F5E5A">决策由 PL 出（D1）</text>
<text x="56" y="156" font-size="10" fill="#5F5E5A">PS 只调度与呈现</text>

<rect x="44" y="232" width="152" height="136" rx="8" fill="#FFFFFF" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="56" y="254" font-size="11" font-weight="500" fill="#444441">PS 硬核外设</text>
<text x="56" y="274" font-size="10" fill="#5F5E5A">UART1 → 串口屏</text>
<text x="56" y="292" font-size="10" fill="#5F5E5A">蓝牙 / SD / ETH0 / USB0</text>
<text x="56" y="310" font-size="10" fill="#5F5E5A">经 MIO 直达，不占 PL IO</text>

<rect x="44" y="386" width="152" height="136" rx="8" fill="#FFFFFF" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="56" y="408" font-size="11" font-weight="500" fill="#444441">DDR 控制器 + PLB</text>
<text x="56" y="428" font-size="10" fill="#5F5E5A">HP0 从端 64 bit</text>
<text x="56" y="446" font-size="10" fill="#5F5E5A">p2f_clk0 199.98 MHz</text>
<text x="56" y="464" font-size="10" fill="#5F5E5A">P2F_Reset0 已开</text>

<rect x="470" y="44" width="180" height="478" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<rect x="484" y="78" width="152" height="136" rx="8" fill="#FFFFFF" stroke="#0F6E56" stroke-width="0.5"/>
<text x="496" y="100" font-size="11" font-weight="500" fill="#085041">视频流水线（纯 PL）</text>
<text x="496" y="120" font-size="10" fill="#0F6E56">mipi_rx → isp</text>
<text x="496" y="138" font-size="10" fill="#0F6E56">→ uidbuf → uivtc</text>
<text x="496" y="156" font-size="10" fill="#0F6E56">→ hdmi_tx → TMDS</text>

<rect x="484" y="232" width="152" height="136" rx="8" fill="#FFFFFF" stroke="#0F6E56" stroke-width="0.5"/>
<text x="496" y="254" font-size="11" font-weight="500" fill="#085041">决策与执行（新增）</text>
<text x="496" y="274" font-size="10" fill="#0F6E56">决策状态机 + OSD</text>
<text x="496" y="292" font-size="10" fill="#0F6E56">电机 PID 闭环</text>
<text x="496" y="310" font-size="10" fill="#0F6E56">走 J12 的 24 根 IO</text>

<rect x="484" y="386" width="152" height="136" rx="8" fill="#FFFFFF" stroke="#0F6E56" stroke-width="0.5"/>
<text x="496" y="408" font-size="11" font-weight="500" fill="#085041">控制面（新增）</text>
<text x="496" y="428" font-size="10" fill="#0F6E56">AXI-Lite 从端</text>
<text x="496" y="446" font-size="10" fill="#0F6E56">AXI-ERAM + 状态寄存器</text>
<text x="496" y="464" font-size="10" fill="#0F6E56">中断汇聚 → f2p_irq</text>

<rect x="230" y="78" width="220" height="64" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="246" y="98" font-size="11" font-weight="500" fill="#633806">① Slave_AXI_HP0 ✅</text>
<text x="246" y="116" font-size="10" fill="#633806">视觉大数据 PL→PS</text>
<text x="246" y="132" font-size="10" fill="#633806">64 bit · 写 DDR 帧缓存</text>
<text x="434" y="98" font-size="10" fill="#633806" text-anchor="end">PL → PS</text>

<rect x="230" y="152" width="220" height="64" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="246" y="172" font-size="11" font-weight="500" fill="#0C447C">② Master_AXI_GP0</text>
<text x="246" y="190" font-size="10" fill="#185FA5">控制下行 PS→PL</text>
<text x="246" y="206" font-size="10" fill="#185FA5">PL 侧须挂 AXI-Lite 从端</text>
<text x="434" y="172" font-size="10" fill="#185FA5" text-anchor="end">PS → PL</text>

<rect x="230" y="226" width="220" height="64" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="246" y="246" font-size="11" font-weight="500" fill="#0C447C">③ AXI-ERAM（GP0 窗内）</text>
<text x="246" y="264" font-size="10" fill="#185FA5">阈值 / 参数下行</text>
<text x="246" y="280" font-size="10" fill="#185FA5">PS 写、PL 直接读参数</text>
<text x="434" y="246" font-size="10" fill="#185FA5" text-anchor="end">PS → PL</text>

<rect x="230" y="300" width="220" height="64" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="246" y="320" font-size="11" font-weight="500" fill="#085041">④ 状态 / 屏显上行</text>
<text x="246" y="338" font-size="10" fill="#0F6E56">小：GP0 状态寄存器</text>
<text x="246" y="354" font-size="10" fill="#0F6E56">大：HP0 写 DDR 屏显区</text>
<text x="434" y="320" font-size="10" fill="#0F6E56" text-anchor="end">PL → PS</text>

<rect x="230" y="374" width="220" height="64" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="246" y="394" font-size="11" font-weight="500" fill="#3C3489">⑤ F2P_IRQ[19:0]</text>
<text x="246" y="412" font-size="10" fill="#534AB7">事件中断 PL→PS</text>
<text x="246" y="428" font-size="10" fill="#534AB7">RTL 现为恒 0，需接源</text>
<text x="434" y="394" font-size="10" fill="#534AB7" text-anchor="end">PL → PS</text>

<rect x="230" y="448" width="220" height="64" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="246" y="468" font-size="11" font-weight="500" fill="#C83C3C">⑥ C 型硬线 + UART</text>
<text x="246" y="486" font-size="10" fill="#C83C3C">急停直拉 p2f_rst0_n</text>
<text x="246" y="502" font-size="10" fill="#C83C3C">STM32 ↔ PS 串口</text>
<text x="434" y="468" font-size="10" fill="#C83C3C" text-anchor="end">双向</text>

<text x="30" y="542" font-size="10" fill="#5F5E5A">注：①⑥ 沿用现行位流即可；②③④⑤ 需要在 TD 的 PS 配置器里开开关并在 PL 侧补 IP。</text>
</svg>

**读图口诀**：🟡 中间一列是**六条通路的全部家当**。黄色 ① 和红框 ⑥ 是**现在就能用**的；蓝色 ②③ 是**PS 往 PL 写**（控制与阈值）；绿色 ④ 与紫色 ⑤ 是**PL 往 PS 回**（状态/屏显与中断）。左边灰列是 PS 三大件，右边绿列是 PL 三大块——**注意右列中间与下面两块是"新增"的：目标态的 PL 不再只是视频流水线，还要装下决策状态机、PID 闭环和一张 AXI 控制面**。

---

## 二、一句话总览

**把 PS 和 PL 想成"办公室 + 车间"：车间（PL）里有两条线——一条是早就自转的视频流水线，一条是新增的决策与执行线；办公室（PS）负责接电话（MIO 上的串口屏、蓝牙）、记账（DDR 里的帧缓存），以及在需要时往车间递图纸。三条设计公理决定了一切：**

| 公理 | 内容 | 直接后果 |
|---|---|---|
| **① 按延迟敏感度分家** | µs 级闭环全在 PL 内部闭合；ms 级调度才交给 PS 软件 | 电机 PID、PWM、编码器解码**不经** PS↔PL（C11 的执行端） |
| **② 按数据量与实时性选载体** | 大块连续数据 → HP0 直写 DDR；小控制字 → GP0 寄存器 | 一帧 1920×1080×4 B ≈ 8.3 MB 走 DDR；一个阈值 4 B 走寄存器 |
| **③ A 型不占 PL IO** | 能挂 MIO 的绝不占 J12 的 24 根 | 蓝牙、串口屏、SD、网口、USB 全在 PS 侧 → C10 才够用 |

三节导读：

| 想搞清楚 | 直接跳 |
|---|---|
| 每类交互走哪条线、为什么 | 第三、四节 |
| 现在缺什么、要改几处 | 第五节 |
| 按什么顺序做最稳 | 第六节（P-0…P-4） |
| 有哪些坑 | 第七节 |

---

## 三、逐路详解

> 六条通路不是"流水线的六级"，而是**并行可同时存在的六根线**。每条按五问展开：载体 / 方向 / 带宽 / 干什么 / **为什么是这条**。

### 第 ① 条：`Slave_AXI_HP0`（视觉大数据 PL → PS）

| 项 | 内容 |
|---|---|
| 载体 | PS 的高性能从端口，PL 作为 AXI 主机直接读写 DDR |
| 参数 | `Slave_AXI_HP0_Interface=1`、`HP0_DATA_WIDTH=64`（HP1 = 0） |
| 干什么 | PL 把 ISP 处理后的整帧写进 DDR 帧缓存；PS 需要时去读 |
| 为什么 | 帧数据是 MB 级连续流，只有 DDR 这条 64 bit 总线扛得住；走寄存器窗每秒只能搬几 MB，连 720p30 的一帧都不够 |

> **现状**：唯一在跑的数据通路，`mipiHDMIbySD` 基线已在用，**目标态沿用不动**。

### 第 ② 条：`Master_AXI_GP0` → PL 的 AXI-Lite 从端（控制下行）

| 项 | 内容 |
|---|---|
| 载体 | PS 的通用主机口，打到一个**由 PL 实现的 AXI-Lite 从端**上 |
| 参数 | `Master_AXI_GP0 = 0`（现状未开）；须 ≥1 个 PL 侧 AXI 从端实例 |
| 干什么 | 写控制字：模式（跟随/自动/急停）、手动速度、使能、清故障 |
| 为什么 | 控制字只有几十字节，但要求"写下去立刻生效"；走 HP0+DDR 会引入一整帧的延迟（≥33 ms），而 GP0 是直连、单拍可读 |

> ⚠️ **B 型三件套缺一不可**：① PL 侧实现 AXI 从端 → ② BD 里开 `Master_AXI_GP0` → ③ `soc_plat.h` 的 `AL_AXI_*_NUM_INSTANCE > 0`。**现状三件全缺**，且 `driver/` 下 `al_axi_*` 头文件全仓 0 命中，一开宏即 `fatal error` ⇒ **必须同时向安路索取 PL IP 驱动包**。

### 第 ③ 条：AXI-ERAM（阈值下行）

| 项 | 内容 |
|---|---|
| 载体 | 挂在 GP0 窗内的双口 RAM 型 AXI 从端 |
| 干什么 | 存**会被频繁改**的参数：安全距离阈值、速度上限、PID 三个系数 |
| 为什么 | 这些参数是"PS 写一次、PL 每帧读很多次"，用 RAM 比寄存器省地址空间、比 DDR 省延迟。ERAM 在同一窗内 ⇒ 不额外占地址、不额外占引脚 |

### 第 ④ 条：状态 / 屏显上行（PL → PS）

这条按数据量拆成**两截**，否则两头不讨好：

| 子路 | 载体 | 装什么 | 为什么 |
|---|---|---|---|
| ④a 小 | GP0 窗内的**状态寄存器**段 | 决策状态、电机转速、故障码、当前模式 | 几十字节、要求低延迟读取，寄存器最合适 |
| ④b 大 | HP0 → DDR **屏显区** | 串口屏要的多值曲线、统计数据、告警文本 | 串口屏 ≥5–10 Hz 刷新，几十到几百字节/次，走 DDR 用一个环形缓冲最省事，也不挤 GP0 |

### 第 ⑤ 条：`F2P_IRQ[19:0]`（事件中断 PL → PS）

| 项 | 内容 |
|---|---|
| 载体 | PL → PS 的中断线组，20 根可用 |
| 参数 | `F2P_IRQ_Available = 0`（现状）；RTL 里 `f2p_irq_TB[19:0]` 被**全部赋常量 0** |
| 干什么 | 告警、目标越界、急停触发、屏显数据就绪 |
| 为什么 | 安全相关事件不能等轮询周期；轮询要么慢（漏事件）要么费 CPU（白跑）。中断是**唯一**能同时做到"实时 + 省电"的机制 |

> 现在 PS 只能轮询，这正是基线 `main.c` 用"每秒读一次寄存器"的原因——**不是设计选择，是没得选**。

### 第 ⑥ 条：C 型硬线 + UART（安全冗余）

| 子路 | 载体 | 干什么 | 为什么 |
|---|---|---|---|
| 急停 | `p2f_rst0_n` 直拉 PL 的 PLL / DBUF / FDMA | 物理断开视频与执行链 | 软件失效时，只有硬件直拉才救得回来（C 型旁路，不吃地址、不走 AXI） |
| 冗余对话 | STM32 ↔ PS 的 UART（走 MIO，不占 PL IO） | 安全层与主控层互相报状态 | D5 定 STM32 为安全冗余方，它不能挂在 PL 上（PL 自己可能就是失效方） |

> ⚠️ **执行链（第 ⑦ 项）不走 PS↔PL**：电机 PWM、方向、使能、编码器解码、超声回波捕获，全部在 **PL 内部**闭环，只借 J12 的 24 根 IO 出去接驱动器。理由见公理①——跨到 PS 会吃掉软件调度抖动（几十 µs 到 ms 级），PID 环路根本不稳。

---

## 四、I3 契约：四类寄存器分区与"方向分离"地址布局

规划 §1.5 对 I3 的原话是「基地址、帧缓冲地址与数量、中断号、**控制/状态/阈值/屏显数据四类寄存器分区**」。落到实现上，唯一正确做法是**按数据"往哪边流"分段，而不是按功能分段**：

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 330" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>I3 契约的四类寄存器方向分离地址布局</title>
<desc>一个 AXI 窗内按方向分成控制、状态、阈值、屏显数据、中断控制五段，每段只有一个写入方</desc>
<text x="40" y="26" font-size="12" font-weight="500" fill="#444441">一个 AXI 窗 · 四类寄存器 · 按「方向」分段</text>
<text x="56" y="54" font-size="11" fill="#5F5E5A">偏移 / 名称 / 容量</text>
<text x="620" y="54" font-size="11" fill="#5F5E5A" text-anchor="end">唯一写入方 → 读取方</text>

<rect x="40" y="70" width="600" height="40" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="56" y="96" font-size="12" fill="#0C447C">+0x0000　控制寄存器　128 B</text>
<text x="624" y="96" font-size="12" fill="#0C447C" text-anchor="end">PS 写 → PL 读</text>

<rect x="40" y="120" width="600" height="40" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="56" y="146" font-size="12" fill="#085041">+0x0080　状态寄存器　32 B</text>
<text x="624" y="146" font-size="12" fill="#085041" text-anchor="end">PL 写 → PS 读</text>

<rect x="40" y="170" width="600" height="40" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="56" y="196" font-size="12" fill="#0C447C">+0x0100　阈值寄存器　128 B</text>
<text x="624" y="196" font-size="12" fill="#0C447C" text-anchor="end">PS 写 → PL 读</text>

<rect x="40" y="220" width="600" height="40" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="56" y="246" font-size="12" fill="#085041">+0x0200　屏显数据　256 B</text>
<text x="624" y="246" font-size="12" fill="#085041" text-anchor="end">PL 写 → PS 读</text>

<rect x="40" y="270" width="600" height="40" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="56" y="296" font-size="12" fill="#0C447C">+0x0400　中断控制　32 B</text>
<text x="624" y="296" font-size="12" fill="#0C447C" text-anchor="end">PS 写 → PL 读</text>

<text x="40" y="326" font-size="10" fill="#5F5E5A">注：偏移值为布局建议；容量按 I4 帧与 I6 屏显映射估算，可整体缩放宽高。</text>
</svg>

**读图口诀**：🔵 蓝底三段（控制 / 阈值 / 中断控制）**只有 PS 写**；🟢 绿底两段（状态 / 屏显数据）**只有 PL 写**。**每一段都只有一个写入方 ⇒ 天生不需要锁、不需要原子操作、不会出现"两边同时写坏一半"**——这是这个布局唯一的设计要点，比段名怎么起重要得多。

> **为什么不用"一个寄存器同时读写"的写法**：那是共享内存语义，PS 读一半时 PL 更新了，就拿到撕裂值；要修就得加握手或双缓冲，成本远高于多花 128 B 地址。**地址空间不要钱，一致性才是成本。**

I4 电机控制帧（走 ②③ 两个窗）字段：目标速度 L/R `16+16` · PWM L/R `12+12` · 方向 L/R `1+1` · 使能 `1`（**失效安全默认 0**）· 制动等级 `2`（**3 = 紧急制动**）· 编码器回读 L/R `32+32`。

---

## 五、现状 → 目标对照

| 通路 | 现状（`mipiHDMIbySD` 实测） | 目标态 | 要动的地方 |
|---|---|---|---|
| ① HP0 大数据 | ✅ `HP0=1` · 64 bit | ✅ 不变 | 无 |
| ② GP0 控制下行 | ❌ `Master_AXI_GP0=0` | ✅ AXI-Lite 从端可读写 | TD 开 GP0 + PL 加从端 IP + 索取驱动包 |
| ③ ERAM 阈值 | ❌ 同上 | ✅ GP0 窗内 | 同上 |
| ④a 状态寄存器 | ❌ 无任何通路 | ✅ GP0 状态段 | PL 加状态寄存器 |
| ④b 屏显 DDR 区 | 🟡 HP0 能写 DDR，但无屏显区约定 | ✅ 固定 DDR 屏显区 + 环形缓冲 | PS 侧定地址、PL 侧加写通道 |
| ⑤ 中断 | ❌ `F2P_IRQ_Available=0`，RTL 恒 0 | ✅ 20 根可用 | TD 开 F2P_IRQ + PL 接中断源 + PS 装 ISR |
| ⑥ 急停 / 冗余 | 🟡 `p2f_rst0_n` 在用；`GPIO_PL` 三线全断 | ✅ 硬线 + STM32 串口 | 加急停按钮 → 硬线；STM32 走 MIO |
| ⑦ 执行链 | ❌ 不存在 | ✅ PL 内闭环 + J12 出线 | PL 加 PID/PWM/正交解码；24 根 IO 预算 |
| ⑧ 人机外设 | ✅ UART1=1（`UART0=0`） | ✅ 沿用 | 无（不占 PL IO） |
| ⑨ 时钟 / 复位 | ✅ `p2f_clk0` 199.98 MHz · `P2F_Reset0=1` | ✅ 沿用 | 无 |

**一句话**：目标态**新增四件事**——GP0 控制窗（②③④a）、中断线（⑤）、执行链（⑦）、屏显区（④b）；**其余沿用**。⑧⑨ 两条旁路提醒我们：**能放在 PS 侧的就别放进 PL**。

---

## 六、分阶段推进 P-0 … P-4

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 396" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>目标态通路的分阶段推进顺序</title>
<desc>五个阶段：打通地基、状态先可见、阈值下行、中断闭环、安全冗余</desc>
<defs>
<marker id="flow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<rect x="40" y="30" width="600" height="50" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="60" y="51" font-size="13" font-weight="500" fill="#444441">P-0　打通地基 · TD 里开三样、索取驱动包</text>
<text x="60" y="69" font-size="12" fill="#5F5E5A">开 Master_AXI_GP0 + F2P_IRQ；向安路索取 PL IP 驱动包（al_axi_* 全仓缺失，开宏即 fatal error）</text>

<line x1="340" y1="80" x2="340" y2="100" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="104" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="125" font-size="13" font-weight="500" fill="#085041">P-1　状态先可见 · 路线 B（HP0 + DDR 轮询）</text>
<text x="60" y="143" font-size="12" fill="#0F6E56">PL 把状态写进 DDR，PS 轮询读；不改 PL 逻辑即可见效，风险最低</text>

<line x1="340" y1="154" x2="340" y2="174" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="178" width="600" height="50" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="199" font-size="13" font-weight="500" fill="#0C447C">P-2　阈值下行 · 路线 A（GP0 窗内 AXI-ERAM）</text>
<text x="60" y="217" font-size="12" fill="#185FA5">PS 经 GP0 写参数窗；与 P-1 不冲突，可在同一窗内并存</text>

<line x1="340" y1="228" x2="340" y2="248" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="252" width="600" height="50" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="60" y="273" font-size="13" font-weight="500" fill="#3C3489">P-3　中断闭环 · f2p_irq[n] → PS 中断服务</text>
<text x="60" y="291" font-size="12" fill="#534AB7">前置：PL 侧先有中断源与状态寄存器；做完即可弃轮询</text>

<line x1="340" y1="302" x2="340" y2="322" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="326" width="600" height="50" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="60" y="347" font-size="13" font-weight="500" fill="#C83C3C">P-4　安全冗余 · C 型急停硬线 + STM32 ↔ PS 串口</text>
<text x="60" y="365" font-size="12" fill="#C83C3C">急停不走软件：物理断开执行链，硬件直拉 p2f_rst0_n</text>

<text x="40" y="392" font-size="10" fill="#5F5E5A">注：P-1 与 P-2 是两条独立的改造路线，建议仍按「先 B 后 A」——先让状态可见，再让参数下行。</text>
</svg>

**读图口诀**：从灰到绿到蓝到紫到红，**颜色对应"离现状的距离"**——灰色 P-0 是纯配置动作，绿色 P-1 几乎不碰 PL 逻辑，蓝色 P-2 才开始写新 IP，紫色 P-3 依赖前两步，红框 P-4 是安全兜底、可以最后做但**不能不做**。**顺序不可颠倒**：没有 P-0 的驱动包，后面全是编译错误；没有 P-1 的状态可见，P-3 的中断装上去也不知道触发对不对。

---

## 七、硬约束与陷阱速查

| 现象 | 首先怀疑什么 |
|---|---|
| 一开 `AL_AXI_*_ENABLE` 就 `fatal error: al_axi_...h: No such file` | 驱动包没到手——`driver/` 下只有 `ps_driver`，`al_axi_*` 全仓 0 命中 |
| TD 里勾了 GP0，PS 还是读不到 PL | B 型三件套缺零件：PL 侧没实现 AXI 从端（只开 BD 开关没用） |
| 中断装了不触发 | `f2p_irq` 在 RTL 里被赋常量 0（`ARM_Processor_System_*.v:67-75`）⇒ PL 侧必须先接真源 |
| 数据读出来时不时撕裂 | 把某一类寄存器配成了"双向共享"——回到第四节，**方向分离** |
| `GPIO_PL` 看起来"能用" | 它三线全断：`pl_gpio_out` 悬空、`pl_gpio_oe` 空连接、`pl_gpio_in` 接常量 `1'b0`，TD 的 `system.violation` 已报 `input port lack of connection` |
| 帧率上不去 | 用了 GP0 搬图像——图像必须走 ①，GP0 只搬控制字 |

**两条读数纪律**（沿用《关系全解》）：① `_Dot_Enable` 与 `_Available` 是两套东西，别把 `_Available=0` 读成"硬件没有"；② `Timer0/1_Dot_Enable=0` 比"宏被注释掉"更强——**是在 TD 里就没挂**。

---

## 八、参数一览

| 常量 / 参数 | 值 | 出处 / 推导 |
|---|---|---|
| `Slave_AXI_HP0` | `1`，`HP0_DATA_WIDTH=64` | `system/Design.xml` 实测 |
| `Master_AXI_GP0 / GP1` | `0 / 0`（现状）→ 目标 `GP0=1` | 同上 |
| `Slave_AXI_GP0 / GP1 / ACP` | `0 / 0 / 0` | 同上 |
| `F2P_IRQ_Available` | `0`（现状）→ 目标 `1`；`f2p_irq[19:0]` | 同上 + BD 网表 |
| `P2F_Reset0_Available` | `1`（Reset1–3 = 0 ⇒ 只有 bit0 有效） | 同上 |
| `P2F_CLOCK_0` | 请求 200 MHz / 实测 **199.98 MHz** | `soc_plat.h` 的 `P2F_CLOCK_0 199980000` |
| 一帧数据量 | 1920×1080×4 B ≈ **8.29 MB** | 1920·1080·4 = 8 294 400 B |
| GP0 窗建议容量 | 五段合计 **576 B** | 128+32+128+256+32 = 576 |
| 建议地址步长 | 每段 128 B 对齐 | 2⁷，便于译码只比高位 |
| J12 可用 PL IO | **24**（12 对差分 @3V3） | 规划 C10；详见《J12-CEP-24口在链路中的作用.md》 |

---

## 九、总结

1. **通路**：目标态六条线——HP0 搬大数据、GP0 传控制与阈值、GP0 窗内回状态、F2P_IRQ 报事件、C 型硬线兜安全、MIO 接人机；**现状只有 HP0 与两根 C 型线在跑**。
2. **变形**：数据形态决定载体——MB 级走 DDR，几十字节走寄存器，几十到几百字节走 ERAM 或 DDR 环形缓冲。
3. **时钟**：`p2f_clk0` 199.98 MHz 一根到底，执行链与视频链共用；跨域只发生在 PS 与 PL 之间，靠中断与寄存器同步。
4. **关键约束**：**方向分离**是这套布局唯一不可让步的设计——每段只有一个写入方，就不需要锁；B 型三件套缺一不可，且驱动包不到手一切免谈。
5. **配置**：所有开关都在 TD 的 PS 配置器里，改完必须重新导出 HPF 并重编——`soc_plat.h` 与七张表都是**生成物**。

---

## 附：与本文配套的两份文档

- **现状版** →《总控前的PS与PL关系全解.md》：讲清"现在连了哪几根线、通不通"。
- **引脚落地面** →《J12-CEP-24口在链路中的作用.md》：讲清"执行链要从哪 24 根球号出去、能接什么、接不了什么"。
