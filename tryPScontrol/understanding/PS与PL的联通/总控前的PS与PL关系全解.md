# PS 与 PL 关系全解 · 以 `mipiHDMIbySD` 基线为底稿

> 工程：`GetStabilityPS(base-fdma_en)/稳定的平台存档/mipiHDMIbySD` ｜ 平台：安路飞龙 DR1（PS 双核 A35 + PL）
> 本文以图为主，逐条解释「PS 与 PL 之间**到底连了哪几根线**、每根线**实际通不通**、C 语言**能不能调 PL 的外设**」。
> 全部数值与结论的出处：`soc_prj/uisrc/01_rtl/system/Design.xml`（100 KB）· `soc_prj/uisrc/01_rtl/system/hdl/system.v`（BD 生成网表）· `soc_prj/uisrc/01_rtl/system.v`（顶层 `system_top`）· `soc_prj/uisrc/01_rtl/system/system.violation`（TD 自带告警）· `soc_sdk/soc_base/platform/inc/soc_plat.h` · `soc_sdk/soc_base/dr1m90_fpsoc_cpu0/inc/al_hal.h`。

---

## 一、图：PS ↔ PL 全连线总图

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 560" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>PS 与 PL 之间的全部连线及其当前可用性</title>
<desc>左列 PS 子系统、右列 PL、中列六条接口；绿色为当前可用，红框为已配置但未接通，灰色为已关闭</desc>
<text x="120" y="30" font-size="12" font-weight="500" fill="#444441" text-anchor="middle">PS 子系统（硬核）</text>
<text x="340" y="30" font-size="12" font-weight="500" fill="#633806" text-anchor="middle">六条接口</text>
<text x="560" y="30" font-size="12" font-weight="500" fill="#085041" text-anchor="middle">PL（FPGA 逻辑）</text>

<rect x="30" y="44" width="180" height="478" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<rect x="44" y="78" width="152" height="136" rx="8" fill="#FFFFFF" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="56" y="100" font-size="11" font-weight="500" fill="#444441">A35 双核 ×2</text>
<text x="56" y="120" font-size="10" fill="#5F5E5A">CPU_CLOCK 999.9 MHz</text>
<text x="56" y="138" font-size="10" fill="#5F5E5A">跑 C 程序（无 CubeMX）</text>
<text x="56" y="156" font-size="10" fill="#5F5E5A">初始化结构体要手写</text>

<rect x="44" y="232" width="152" height="136" rx="8" fill="#FFFFFF" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="56" y="254" font-size="11" font-weight="500" fill="#444441">PSB 硬核外设</text>
<text x="56" y="274" font-size="10" fill="#5F5E5A">GPIO_PS / UART1 / SD</text>
<text x="56" y="292" font-size="10" fill="#5F5E5A">ETH0 · USB0 · QSPI</text>
<text x="56" y="310" font-size="10" fill="#5F5E5A">经 MIO 直达引脚</text>

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
<text x="496" y="254" font-size="11" font-weight="500" fill="#085041">上游 AXI 主机</text>
<text x="496" y="274" font-size="10" fill="#0F6E56">uiFDMA 读写 DDR</text>
<text x="496" y="292" font-size="10" fill="#0F6E56">帧缓存 0x0A000000</text>
<text x="496" y="310" font-size="10" fill="#0F6E56">PS 不经手，只供钟</text>

<rect x="484" y="386" width="152" height="136" rx="8" fill="#FFFFFF" stroke="#0F6E56" stroke-width="0.5"/>
<text x="496" y="408" font-size="11" font-weight="500" fill="#085041">控制线落点</text>
<text x="496" y="428" font-size="10" fill="#0F6E56">p2f_clk0 → DBUF</text>
<text x="496" y="446" font-size="10" fill="#0F6E56">p2f_rst0_n → PLL</text>
<text x="496" y="464" font-size="10" fill="#0F6E56">无寄存器通路</text>

<rect x="230" y="78" width="220" height="64" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="246" y="98" font-size="11" font-weight="500" fill="#085041">p2f_clk0 ✅ 唯一 PL 时钟</text>
<text x="246" y="116" font-size="10" fill="#0F6E56">199.98 MHz（请求 200）</text>
<text x="246" y="132" font-size="10" fill="#0F6E56">→ uidbuf / VTC / FDMA</text>
<text x="434" y="98" font-size="10" fill="#0F6E56" text-anchor="end">PS → PL</text>

<rect x="230" y="152" width="220" height="64" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="246" y="172" font-size="11" font-weight="500" fill="#085041">p2f_rst0_n ✅ 唯一复位线</text>
<text x="246" y="190" font-size="10" fill="#0F6E56">含 PLL 复位（4 路开 1 路）</text>
<text x="246" y="206" font-size="10" fill="#0F6E56">→ PLL / uidbuf / FDMA</text>
<text x="434" y="172" font-size="10" fill="#0F6E56" text-anchor="end">PS → PL</text>

<rect x="230" y="226" width="220" height="64" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="246" y="246" font-size="11" font-weight="500" fill="#C83C3C">Master_AXI_GP0 / GP1 ❌</text>
<text x="246" y="264" font-size="10" fill="#C83C3C">= 0 ⇒ 没有 AXI 主机口</text>
<text x="246" y="280" font-size="10" fill="#C83C3C">读不到 PL 任何寄存器</text>
<text x="434" y="246" font-size="10" fill="#C83C3C" text-anchor="end">PS → PL</text>

<rect x="230" y="300" width="220" height="64" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="246" y="320" font-size="11" font-weight="500" fill="#C83C3C">GPIO_PL ❌ 三线全断</text>
<text x="246" y="338" font-size="10" fill="#C83C3C">out 悬空、oe 空接、in 恒 0</text>
<text x="246" y="354" font-size="10" fill="#C83C3C">宏已勾选，RTL 无落点</text>
<text x="434" y="320" font-size="10" fill="#C83C3C" text-anchor="end">PS → PL</text>

<rect x="230" y="374" width="220" height="64" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="246" y="394" font-size="11" font-weight="500" fill="#633806">Slave_AXI_HP0 ✅ 数据通路</text>
<text x="246" y="412" font-size="10" fill="#633806">64 bit · PL 读写 DDR</text>
<text x="246" y="428" font-size="10" fill="#633806">方向：PL 主机，PS 从端</text>
<text x="434" y="394" font-size="10" fill="#633806" text-anchor="end">PL → PS</text>

<rect x="230" y="448" width="220" height="64" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="246" y="468" font-size="11" font-weight="500" fill="#C83C3C">f2p_irq ❌ RTL 里恒 0</text>
<text x="246" y="486" font-size="10" fill="#C83C3C">f2p_irq_TB[19:0] 全赋 0</text>
<text x="246" y="502" font-size="10" fill="#C83C3C">PL 无法通知 PS</text>
<text x="434" y="468" font-size="10" fill="#C83C3C" text-anchor="end">PL → PS</text>

<text x="30" y="542" font-size="10" fill="#5F5E5A">注：状态出自 Design.xml 与 01_rtl/system.v 网表（2026-10-11 实测）。</text>
</svg>

**读图口诀**：🟡 中间一列是**六条接口的全部家当**，只有 `p2f_clk0` / `p2f_rst0_n` / `Slave_AXI_HP0` 三格是活的（绿/黄），其余三格白底红框 = **配置上写了、硬件上没通**。左边灰列是 PS 子系统，右边绿列是 PL；**PS 输出给 PL 的只有"时钟 + 复位"，PL 输出给 PS 的只有"写 DDR"，两条方向中间没有寄存器通道，也没有中断。**

---

## 二、一句话总览

**把 PS 和 PL 想成两间办公室：PL 那间里有一条完整的流水线（MIPI→ISP→帧缓存→HDMI）自己转个不停，PS 那间只管做两件事——给对面送电（`p2f_clk0`）和按总闸（`p2f_rst0_n`）。两间办公室之间没有内线电话（无中断）、没有文件柜互相翻（无 AXI 主口），只有一条传真机——PL 把画面底稿投进 DDR 这个公共仓库，PS 需要时可以去仓库看。**

三节导读：

| 想搞清楚 | 直接跳 |
|---|---|
| 到底连了哪几根线、每根通不通 | 第一节图 + 第三节逐条 |
| "要不要 PL 当中介"该怎么问 | 第四节（三型模型） |
| 时钟和复位为什么能决定生死 | 第五节 |
| 那些 TD 里能勾的 IP 到底算什么 | 第六节 |
| **C 语言能不能调 PL 的外设** | 第七节 |

---

## 三、逐条详解

> 这六条不是"流水线的六级"，而是**并行的六根线**。每条按五问展开：参数 / 输入 / 输出 / 干什么 / **为什么**。

### 第 1 条：`p2f_clk0`（PS → PL，唯一系统时钟）

| 项 | 内容 |
|---|---|
| 参数 | 请求 200 MHz，**实得 199.98 MHz**（`p2f_clk0_Dot_Actual_IO_Frequency`）；1 级分频比 = 2；时钟源 = IO PLL；范围 6.25–200 MHz |
| 输入 | PS 的 IO PLL |
| 输出 | `uidbuf.I_ui_clk` · `uiFDMA_0.M_AXI_ACLK` · `slave_hp0_axi_aclk` |
| 干什么 | 给 PL 里**所有跨 PS 的电路**供钟 |
| 为什么 | HP0 是 PS 侧的 AXI 从端，必须与 PS 同步时钟；帧缓存读写跨域，靠这个钟定拍 |

⚠️ `p2f_clk1/2/3` 的 `Dot_Enable` **全为 0** ⇒ 四路只开一路。

### 第 2 条：`p2f_rst0_n`（PS → PL，唯一复位线）

| 项 | 内容 |
|---|---|
| 参数 | `P2F_Reset0_Available = 1`；`Reset1/2/3 = 0` |
| 输入 | PS 的复位控制器 |
| 输出 | `pll.reset` · `fdma_rstn` · `uiFDMA.M_AXI_ARESETN` |
| 干什么 | 释放/拉低 PL 的复位 |
| 为什么 | **它是整条链的总闸**——见第五节 |

### 第 3 条：`Master_AXI_GP0 / GP1`（PS → PL，**关闭**）

| 项 | 内容 |
|---|---|
| 参数 | **= 0 / 0**（`Design.xml:291-292`） |
| 输入 | — |
| 输出 | — |
| 干什么 | 本应提供"PS 作为主机去读写 PL 寄存器"的地址通道 |
| 为什么重要 | 这是"PS 下发阈值 / 读回状态"的**唯一正统通路**；关着 ⇒ 该能力为零 |

### 第 4 条：`GPIO_PL`（PS → PL 直连，**断开**）

| 项 | 内容 |
|---|---|
| 参数 | `GPIO_PL_Dot_Enable = 1`、`GPIO_PL_Dot_IO = 1`（位宽 1 位，不是编号） |
| 输入 | — |
| 输出 | 端口 `pl_gpio_in` / `pl_gpio_oe` / `pl_gpio_out`（各 `[0:0]`） |
| 干什么 | 本应提供**不吃地址、不经 AXI** 的少量开关量 |
| 为什么不通 | 三条线在 RTL 里各自断在不同地方，见第七节陷阱 ② |

### 第 5 条：`Slave_AXI_HP0`（PL → PS，**唯一在跑的数据通路**）

| 项 | 内容 |
|---|---|
| 参数 | `Slave_AXI_HP0_Interface = 1`、`Slave_AXI_HP0_DATA_WIDTH = 64`；`HP1 = 0` |
| 输入 | PL 的 `uiFDMA` 作为 AXI 主机 |
| 输出 | DDR（PS 侧的 DDR 控制器） |
| 干什么 | PL 把 ISP 出来的像素写进帧缓存，再把帧缓存读回来送给 HDMI |
| 为什么 | 帧缓存放在 DDR 才能跨时钟域、跨帧率解耦；**PS 全程不参与** |

### 第 6 条：`f2p_irq`（PL → PS，**关闭**）

| 项 | 内容 |
|---|---|
| 参数 | `F2P_IRQ_Available = 0`；RTL 里 `wire [19:0] f2p_irq_TB` **全部赋常量 0**（`ARM_Processor_System_59fb6a0bf2ca.v:67-75`） |
| 输入 | — |
| 输出 | — |
| 干什么 | 本应让 PL 主动通知 PS（帧就绪 / 异常） |
| 为什么重要 | 没有它，**PS 只能轮询**；PL 侧任何异常（PLL 失锁、MIPI 无信号）对 PS 不可见 |

---

## 四、通路三型（取代"要不要 PL 当中介"）

> 原来的问法"PS 要不要以 PL 为中介"是**问错了**。正确的问法是：**这个 PL 外设有没有拿到 AXI 门牌？**

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 410" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>PS 与 PL 之间的三种通路形态</title>
<desc>A 型 PS 外设经 MIO 直达引脚，PL 完全不参与；B 型 PS 经 AXI 访问 PL 的从端，当前关闭；C 型 PLB 旁路直连，只有时钟与复位在用</desc>
<defs>
<marker id="flow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<text x="30" y="26" font-size="12" font-weight="500" fill="#085041">A 型 · PS 外设经 MIO 直达引脚（PL 完全不参与）</text>
<rect x="30" y="38" width="180" height="76" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="120" y="62" font-size="11" font-weight="500" fill="#085041" text-anchor="middle">PSB 硬核外设</text>
<text x="120" y="80" font-size="10" fill="#0F6E56" text-anchor="middle">GPIO_PS / UART1</text>
<text x="120" y="98" font-size="10" fill="#0F6E56" text-anchor="middle">SD / ETH0 / USB0</text>
<rect x="250" y="38" width="180" height="76" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="340" y="62" font-size="11" font-weight="500" fill="#085041" text-anchor="middle">MIO 复用（54 个）</text>
<text x="340" y="80" font-size="10" fill="#0F6E56" text-anchor="middle">FUNCSEL 值选通</text>
<text x="340" y="98" font-size="10" fill="#0F6E56" text-anchor="middle">0xF8803000 + 4n</text>
<rect x="470" y="38" width="180" height="76" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="560" y="62" font-size="11" font-weight="500" fill="#085041" text-anchor="middle">芯片引脚</text>
<text x="560" y="80" font-size="10" fill="#0F6E56" text-anchor="middle">B2B → 底板器件</text>
<text x="560" y="98" font-size="10" fill="#0F6E56" text-anchor="middle">✅ 现在就能用</text>
<line x1="212" y1="76" x2="246" y2="76" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>
<line x1="432" y1="76" x2="466" y2="76" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<text x="30" y="146" font-size="12" font-weight="500" fill="#C83C3C">B 型 · PS 经 AXI 访问 PL 的从端（PL 是被访问方，不是中介）</text>
<rect x="30" y="162" width="180" height="76" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="120" y="186" font-size="11" font-weight="500" fill="#C83C3C" text-anchor="middle">A35 核（AXI 主机）</text>
<text x="120" y="204" font-size="10" fill="#C83C3C" text-anchor="middle">Master_AXI_GP0/GP1</text>
<text x="120" y="222" font-size="10" fill="#C83C3C" text-anchor="middle">= 0 ⇒ 门没开</text>
<rect x="250" y="162" width="180" height="76" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="340" y="186" font-size="11" font-weight="500" fill="#C83C3C" text-anchor="middle">AXI 互连 + 地址段</text>
<text x="340" y="204" font-size="10" fill="#C83C3C" text-anchor="middle">由 TD 自动分配</text>
<text x="340" y="222" font-size="10" fill="#C83C3C" text-anchor="middle">当前无实例</text>
<rect x="470" y="162" width="180" height="76" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="560" y="186" font-size="11" font-weight="500" fill="#C83C3C" text-anchor="middle">PL 的 AXI 从端</text>
<text x="560" y="204" font-size="10" fill="#C83C3C" text-anchor="middle">AXI GPIO / UART Lite</text>
<text x="560" y="222" font-size="10" fill="#C83C3C" text-anchor="middle">自写 AXI-Lite 寄存器</text>
<line x1="212" y1="200" x2="246" y2="200" stroke="#888780" stroke-width="1.5" stroke-dasharray="4 3" marker-end="url(#flow)"/>
<line x1="432" y1="200" x2="466" y2="200" stroke="#888780" stroke-width="1.5" stroke-dasharray="4 3" marker-end="url(#flow)"/>

<text x="30" y="268" font-size="12" font-weight="500" fill="#633806">C 型 · PLB 旁路直连（不吃地址、不走 AXI）</text>
<rect x="30" y="284" width="180" height="76" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="120" y="308" font-size="11" font-weight="500" fill="#633806" text-anchor="middle">PS 的 PLB</text>
<text x="120" y="326" font-size="10" fill="#633806" text-anchor="middle">复位 / 时钟 / GPIO</text>
<text x="120" y="344" font-size="10" fill="#633806" text-anchor="middle">四类旁路信号</text>
<rect x="250" y="284" width="180" height="76" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="340" y="308" font-size="11" font-weight="500" fill="#633806" text-anchor="middle">p2f_clk0 ✅</text>
<text x="340" y="326" font-size="10" fill="#633806" text-anchor="middle">p2f_rst0_n ✅</text>
<text x="340" y="344" font-size="10" fill="#633806" text-anchor="middle">GPIO_PL ❌ · f2p_irq ❌</text>
<rect x="470" y="284" width="180" height="76" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="560" y="308" font-size="11" font-weight="500" fill="#633806" text-anchor="middle">PL 内部逻辑</text>
<text x="560" y="326" font-size="10" fill="#633806" text-anchor="middle">PLL / DBUF / FDMA</text>
<text x="560" y="344" font-size="10" fill="#633806" text-anchor="middle">无寄存器通路</text>
<line x1="212" y1="322" x2="246" y2="322" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>
<line x1="432" y1="322" x2="466" y2="322" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<text x="30" y="392" font-size="10" fill="#5F5E5A">注：三型由“谁发起访问”划分；同一块 PL 逻辑可以同时处在 B 型与 C 型之下。</text>
</svg>

**读图口诀**：🟢 A 型是"**PS 自己走线**"——外设信号从 MIO 直接出芯片，PL 那间屋子根本没人参与，所以你现在的 GPIO / 串口**一根 PL 的线都不需要**。🔴 B 型才是"PS 去敲 PL 的门"，此时 **PL 是被敲的那扇门（AXI 从端），不是传话的中介**——可这扇门现在是砌死的（`GP0/GP1 = 0`）。🟡 C 型是"两间屋子之间预埋的几根暗线"，不走地址、不走总线，现在只有时钟与复位在通电。

### 三型对照

| 型 | 谁发起 | 通路载体 | PL 的角色 | 本工程 | 你能立刻拿它做什么 |
|---|---|---|---|---|---|
| **A 型** | PS | MIO 复用 → B2B → 底板器件 | **完全不存在** | ✅ 可用 | GPIO_PS（6 个 MIO）· UART1 · SD · ETH0 · USB0 · QSPI |
| **B 型** | PS | `Master_AXI_GP0/GP1` → AXI 互连 → PL 从端 | **被访问的从端** | ❌ 关闭 | 无（需三件套齐备，见第七节） |
| **C 型** | PS（单向推） | PLB 旁路直连 | 直连少量控制线 | 🟡 部分 | 整片复位（`p2f_rst0_n`）· 供钟（`p2f_clk0`） |

> **最值得记住的一句话**：问"PS 能不能控 PL"，先分清是**A 型（压根不用 PL）**、**B 型（PL 是从端）**还是 **C 型（直连几根线）**——三者的问题、代价、前置条件完全不同。

---

## 五、时钟与复位：为什么这两根线能决定生死

### 5.1 `p2f_rst0_n` 在 PL 里的四个落点

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 415" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>p2f_clk0 与 p2f_rst0_n 在 PL 内部的落点</title>
<desc>PS 的 PLB 输出两路旁路信号进入 PL；时钟驱动 DBUF、FDMA 与 HP0 三处，复位驱动 PLL、DBUF 复位与 FDMA 复位三处</desc>
<defs>
<marker id="flow2" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<text x="30" y="24" font-size="12" font-weight="500" fill="#633806">p2f_clk0 · 199.98 MHz（PS 请求 200，4 路只开 1 路）</text>
<rect x="230" y="34" width="220" height="44" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="340" y="61" font-size="11" fill="#444441" text-anchor="middle">PS 的 PLB → PL</text>
<line x1="340" y1="78" x2="340" y2="94" stroke="#888780" stroke-width="1.5"/>
<line x1="120" y1="94" x2="560" y2="94" stroke="#888780" stroke-width="1.5"/>
<line x1="120" y1="94" x2="120" y2="106" stroke="#888780" stroke-width="1.5" marker-end="url(#flow2)"/>
<line x1="340" y1="94" x2="340" y2="106" stroke="#888780" stroke-width="1.5" marker-end="url(#flow2)"/>
<line x1="560" y1="94" x2="560" y2="106" stroke="#888780" stroke-width="1.5" marker-end="url(#flow2)"/>

<rect x="30" y="108" width="180" height="76" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="120" y="132" font-size="11" font-weight="500" fill="#633806" text-anchor="middle">uidbuf.I_ui_clk</text>
<text x="120" y="150" font-size="10" fill="#633806" text-anchor="middle">DBUF 读写时钟</text>
<text x="120" y="168" font-size="10" fill="#633806" text-anchor="middle">写侧跨域到读侧</text>
<rect x="250" y="108" width="180" height="76" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="340" y="132" font-size="11" font-weight="500" fill="#633806" text-anchor="middle">uiFDMA.M_AXI_ACLK</text>
<text x="340" y="150" font-size="10" fill="#633806" text-anchor="middle">AXI 主机时钟</text>
<text x="340" y="168" font-size="10" fill="#633806" text-anchor="middle">读 / 写 DDR</text>
<rect x="470" y="108" width="180" height="76" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="560" y="132" font-size="11" font-weight="500" fill="#633806" text-anchor="middle">slave_hp0_axi_aclk</text>
<text x="560" y="150" font-size="10" fill="#633806" text-anchor="middle">HP0 从端时钟</text>
<text x="560" y="168" font-size="10" fill="#633806" text-anchor="middle">PS ↔ PL 桥</text>

<text x="30" y="216" font-size="12" font-weight="500" fill="#633806">p2f_rst0_n（4 路只开 1 路）</text>
<rect x="230" y="226" width="220" height="44" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="340" y="253" font-size="11" fill="#444441" text-anchor="middle">PS 的 PLB → PL 唯一复位</text>
<line x1="340" y1="270" x2="340" y2="286" stroke="#888780" stroke-width="1.5"/>
<line x1="120" y1="286" x2="560" y2="286" stroke="#888780" stroke-width="1.5"/>
<line x1="120" y1="286" x2="120" y2="298" stroke="#888780" stroke-width="1.5" marker-end="url(#flow2)"/>
<line x1="340" y1="286" x2="340" y2="298" stroke="#888780" stroke-width="1.5" marker-end="url(#flow2)"/>
<line x1="560" y1="286" x2="560" y2="298" stroke="#888780" stroke-width="1.5" marker-end="url(#flow2)"/>

<rect x="30" y="300" width="180" height="76" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="120" y="324" font-size="11" font-weight="500" fill="#633806" text-anchor="middle">pll.reset(~rst0_n)</text>
<text x="120" y="342" font-size="10" fill="#633806" text-anchor="middle">直接复位 PLL</text>
<text x="120" y="360" font-size="10" fill="#633806" text-anchor="middle">1'b1 表示一直复位</text>
<rect x="250" y="300" width="180" height="76" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="340" y="324" font-size="11" font-weight="500" fill="#633806" text-anchor="middle">fdma_rstn</text>
<text x="340" y="342" font-size="10" fill="#633806" text-anchor="middle">= rst0_n 与 locked 相与</text>
<text x="340" y="360" font-size="10" fill="#633806" text-anchor="middle">→ uidbuf.I_ui_rstn</text>
<rect x="470" y="300" width="180" height="76" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="560" y="324" font-size="11" font-weight="500" fill="#633806" text-anchor="middle">M_AXI_ARESETN</text>
<text x="560" y="342" font-size="10" fill="#633806" text-anchor="middle">uiFDMA 与 HP0 复位</text>
<text x="560" y="360" font-size="10" fill="#633806" text-anchor="middle">经 system_inst 传入</text>

<text x="30" y="396" font-size="10" fill="#C83C3C">⇒ PS 不跑程序 ⇒ p2f_rst0_n 不释放 ⇒ PLL 不 lock ⇒ locked=0 ⇒ MIPI→ISP→DBUF→HDMI 整链停。</text>
</svg>

**读图口诀**：🟡 两张表结构相同——上层是 `p2f_clk0` 的三个消费者，下层是 `p2f_rst0_n` 的三个消费者；灰色块是 PS 的 PLB 输出。**关键在下层最左边那格**：`p2f_rst0_n` 直接进 PLL 的 `reset`，所以 PS 一旦不跑，PLL 就一直处于复位，`locked` 永远是 0，而中间那格的 `fdma_rstn` 是 `rst0_n & locked` 相与——**两个条件都依赖 PS**。

### 5.2 两张时钟域表

| 时钟域 | 来源 | 谁在用 | 节拍由谁决定 |
|---|---|---|---|
| `pclkx1` | PL 的 `pll`（clk0） | `uidbuf.I_R_rclk` · `uivtc` · `hdmi_tx` 像素时钟 | PL 自己（`pll` 由 `I_sysclk` 驱动） |
| `pclkx5` | PL 的 `pll`（clk1） | TMDS 串行器（= 5 × `pclkx1`） | PL 自己 |
| `S_hs_rx_clk` | MIPI 接收侧恢复时钟 | `mipi_rx` · `isp` 写侧计数 | **对端摄像头** |
| **`p2f_clk0`** | **PS 的 IO PLL** | `uidbuf.I_ui_clk` · `uiFDMA.M_AXI_ACLK` · `slave_hp0_axi_aclk` | **PS** |

**为什么不能合成一个钟**：视频链的写入侧跟摄像头走、读出侧跟显示走、帧缓存访问跟 PS 的 AXI 走，三者频率互不相关（例如 MIPI 的 `S_hs_rx_clk` 与 `pclkx1` 就不同源）。强行同源会让某一侧被迫降频或产生撕裂。

**跨域桥接机制**：`uidbuf` 内部就是那个桥——写侧用 `S_hs_rx_clk`、读侧用 `pclkx1`、控制/仲裁侧用 `p2f_clk0`，三域之间靠内部 FIFO 与 `wbuf_sync` / `rbuf_sync` 两个同步计数器协调。

**源码里的保护性写法**（逐条解释）：

| 写法 | 出处 | 意图 |
|---|---|---|
| `assign fdma_rstn = p2f_rst0_n & locked;` | `01_rtl/system.v:134` | 双条件复位——**PLL 没锁就不放行帧缓存**，避免用未稳定的钟去读写 |
| `if(!locked \|\| I_video_in_user) h_cnt <= 0;` | `:145` | 失锁或换帧时清零行计数，防止残帧错位 |
| `S_clk_sensor_idelay = 20` 之类延迟常量 | 顶层 assign 区 | 对 MIPI 接收侧做固定延迟校准 |

---

## 六、那些"能在 TD 里勾的 IP"到底算什么

### 6.1 三层含义，别混

| 层 | 含义 | 判据 | 本工程实例 |
|---|---|---|---|
| **存在** | 硬核硅刻在 PS 里，永远在 | 芯片手册 | 全部 20+ 个外设 |
| **使能** | TD 的 PS 配置器里被勾上 | `*_Dot_Enable = 1` | GPIO_PS / GPIO_PL / UART1 / SD0/1 / ETH0 / USB0 / QSPI / DDR / MDIO0 |
| **可见** | FD 生成的 `soc_plat.h` 里有它的地址与时钟 | `AlXxx_HwConfig[]` 有条目 | 同上（`HAVE_*_DRIVER` 已定义者） |

⚠️ **只有第三层才等于"C 能调"**。`Dot_Enable = 0` 的外设在表里是**零填充空槽**——调用它不报错，只是静默失效。

### 6.2 本工程 PS 配置器实测开关（`Design.xml`）

| 已开 | 未开 |
|---|---|
| `GPIO_PS` · `GPIO_PL` · `UART1` · `SD0` · `SD1` · `ETH0` · `USB0` · `QSPI` · `DDR` · `MDIO0` | `UART0` · `Timer0` · `Timer1` · `I2C0` · `I2C1` · `SPI0` · `SPI1` · `CAN0` · `CAN1` · `ETH1` · `USB1` · `Watchdog` · `TRACE` · `NPU`（= `"Disable"`）· `PJTAG` |

> ⚠️ **`Timer0_Dot_Enable = 0` / `Timer1_Dot_Enable = 0`**（`Design.xml:447/449`）——比"宏被注释"更强：**TD 层面 TC 就是关的**。而 `TC_CLOCK 200000000` 依然被生成，`AlTc_HwConfig[6]` 六条全为零填充 ⇒ 这就是"看得见时钟、调不动外设"的典型。

### 6.3 改配置的代价链条（不可绕）

```
TD 勾 Dot_Enable / 分 Dot_IO  →  重新导出 .hpf  →  FD 重生成 soc_plat.h + AlXxx_cfg.c
                              →  重编 FSBL / 应用  →  重新下载
```

> **一次 TD 配置 = 一次硬件改动**。C 代码里没有任何办法绕开这条链。

---

## 七、C 语言能调用 PL 的外设吗？

## **能——这是安路官方支持的路径。但你现在的工程，三件事一件都没满足。**

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 450" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>C 语言访问 PL 外设的三个前提与当前状态</title>
<desc>三个前提当前全部未满足，故 C 无法访问 PL 外设；另发现 al_axi 驱动文件在本 SDK 中缺失</desc>
<defs>
<marker id="flow3" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<text x="30" y="26" font-size="12" font-weight="500" fill="#444441">要用 C 访问 PL 自建外设，三件事缺一不可</text>
<rect x="30" y="38" width="600" height="56" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="48" y="60" font-size="11" font-weight="500" fill="#C83C3C">① PL 侧那个外设必须是 AXI 从端（不是随便一段 Verilog）</text>
<text x="48" y="80" font-size="10" fill="#C83C3C">例如 AXI GPIO / AXI UART Lite / 自写 AXI-Lite 寄存器组</text>
<rect x="30" y="106" width="600" height="56" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="48" y="128" font-size="11" font-weight="500" fill="#C83C3C">② BD 里打开 PS 的主机口 Master_AXI_GP0 / GP1</text>
<text x="48" y="148" font-size="10" fill="#C83C3C">当前 = 0 / 0 ⇒ PS 根本没有通往 PL 的地址通道</text>
<rect x="30" y="174" width="600" height="56" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="48" y="196" font-size="11" font-weight="500" fill="#C83C3C">③ soc_plat.h 里 AL_AXI_*_NUM_INSTANCE 大于 0</text>
<text x="48" y="216" font-size="10" fill="#C83C3C">8 项当前全为 0：DMA / ETH_LITE / GPIO / IIC / QSPI / SOFT_NPU / UART_LITE / VDMA</text>
<line x1="340" y1="230" x2="340" y2="250" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>
<rect x="30" y="252" width="600" height="72" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="48" y="276" font-size="11" font-weight="500" fill="#085041">三件齐备后：C 就像用 PS 外设一样调用 PL 外设</text>
<text x="48" y="296" font-size="10" fill="#0F6E56">查表拿 BaseAddress，然后一次 MMIO 读写；API 形如 AlAxiGpio_Hal_xxx</text>
<text x="48" y="314" font-size="10" fill="#0F6E56">对写 C 的人来说，PS 外设与 PL 外设在代码里没有区别</text>
<rect x="30" y="342" width="600" height="72" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="48" y="366" font-size="11" font-weight="500" fill="#C83C3C">本轮新发现：驱动文件本身也不在 SDK 里</text>
<text x="48" y="386" font-size="10" fill="#C83C3C">glob al_axi* 全仓 0 命中；driver 下只有 ps_driver，没有 pl_driver</text>
<text x="48" y="404" font-size="10" fill="#C83C3C">宏为 0 时头文件不参与编译，所以缺失不报错；一开宏即编译失败</text>
<text x="30" y="436" font-size="10" fill="#5F5E5A">注：三件套判据出自 soc_plat.h:336-345 与 al_hal.h:94-124。</text>
</svg>

**读图口诀**：上面三个白底红框是**三道闸门**，现在是**三道全关**。中间绿框才是你想要的结局——"像用 PS 外设一样用 PL 外设"。最下面那个红框是本轮新挖出来的坑：**即使你打开了闸门，驱动文件也不在**。

### 7.1 官方现成支持的 PL 侧 IP 清单

| 来自 `soc_plat.h:336-345`（PL AXI IP instance） | 来自 `al_hal.h:94-124`（按宏条件引入） |
|---|---|
| `AL_AXI_DMA` · `AL_AXI_ETH_LITE` · `AL_AXI_GPIO` · `AL_AXI_IIC` · `AL_AXI_QSPI` · `AL_AXI_SOFT_NPU` · `AL_AXI_UART_LITE` · `AL_AXI_VDMA` | `al_axi_canfd_hal.h` · `al_axi_quad_spi_hal.h` · `al_axi_uart_lite_hal.h` · `al_axi_iic_hal.h` · `al_axi_uart_16550_hal.h` · `al_axi_ethernet_lite_hal.h` |

### 7.2 调用形态：和 PS 外设完全一样

```c
/* 与 AlGpio_Hal_* 同构：查表 → 拿 BaseAddress → MMIO */
AlAxiGpio_HwConfigStruct *cfg = AlAxiGpio_Dev_LookupConfig(DevId);   /* PL 侧 IP 的地址段 */
AlAxiGpio_Hal_Init(&h, cfg);
AlAxiGpio_Hal_SetOutput(&h, pin, 1);                                  /* 写到 PL 里 */
```

> **对写 C 的人，唯一的区别是地址从哪来**：PS 外设的地址由 `al_chip.h` 固定写死；PL 侧 IP 的地址由 **TD 在 BD 里分配**、再由 HPF 导出到 `soc_plat.h`。

---

## 八、参数一览

### 8.1 PS↔PL 接口实测值（`system/Design.xml`）

| 参数 | 值 | 行 |
|---|---|---|
| `Slave_AXI_HP0_Interface` | **1** | `:438` |
| `Slave_AXI_HP0_DATA_WIDTH` | **64** | `:437` |
| `Slave_AXI_HP1_Interface` | 0 | `:439` |
| `Slave_AXI_GP0_Interface` / `GP1` / `ACP` | 0 / 0 / 0 | `:435` / `:436` / `:434` |
| `Master_AXI_GP0_Interface` / `GP1` | **0 / 0** | `:291` / `:292` |
| `F2P_IRQ_Available` | **0** | `:171` |
| `P2F_IRQ_*_Available`（11 项） | 全 0 | `:295-305` |
| `P2F_Reset0_Available` | **1** | `:306` |
| `P2F_Reset1/2/3_Available` | 0 / 0 / 0 | `:307-309` |
| `p2f_clk0_Dot_Requested_Frequency` | 200（MHz） | `:542` |
| `p2f_clk0_Dot_Actual_IO_Frequency` | **199.98**（MHz） | `:539` |
| `p2f_clk0_1st_Divisor` | 2 | `:538` |
| `p2f_clk0_Dot_Range` | `6.25:200` | `:541` |
| `p2f_clk1/2/3_Dot_Enable` | 0 / 0 / 0 | `:543-545` |
| `GPIO_PL_Dot_Enable` | **1** | `:178` |
| `GPIO_PL_Dot_IO` | **1**（位宽，1 位） | `:179` |
| `GPIO_PS_Dot_Enable` | 1 | `:180` |
| `GPIO_PS_IO0/7/8/46/50/51_Present` | 1（仅这 6 个） | `:187/258/264/232/242/248` |
| `Timer0_Dot_Enable` / `Timer1_Dot_Enable` | **0 / 0** | `:447` / `:449` |
| `UART0_Dot_Enable` / `UART1_Dot_Enable` | 0 / **1** | `:451` / `:456` |
| `PJTAG_Dot_Enable` | 0（⇒ 走 PL JTAG） | `:310` |
| `NPU_Dot_Enable` | `"Disable"` | `:294` |

### 8.2 `soc_plat.h` 生成的时钟常量（`#define` 区）

| 常量 | 值 | 推导 / 备注 |
|---|---|---|
| `CPU_CLOCK` | 999900000 | 1000 MHz × 0.9999（`CPU_FBK_DIV 120 / CPU_REF_DIV 2 / CPU_OUT_DIV 2`） |
| `IO_1000_FREQ` | 999900000 | 同源 |
| `P2F_CLOCK_0` | **199980000** | 200 MHz × 0.9999，与 `Design.xml` 的 199.98 MHz 互为印证 |
| `UART_CLOCK` | 49995000 | 50 MHz × 0.9999 |
| `GPIO_CLOCK` | 12500000 | 12.5 MHz |
| `TC_CLOCK` | 200000000 | ⚠️ 定义了但 TC 未使能 |
| `MMC_CLOCK` | 399960000 | 400 MHz × 0.9999 |
| `I2C_CLOCK` | 100000000 | ⚠️ I2C 未使能 |
| `GBE_CLOCK` | 500000000 | ETH0 在用 |
| `QSPI_CLOCK` | 19998000 | `QSPI_2ND_DIVISOR = 2` ⇒ `QSPI_IO_FREQ = 9999000` |
| `OSC_CLK` | 33.33 | 晶振 |
| `SYSTEM_CLOCK` | 33333333 | 33.33 MHz |

> **`P2F_CLOCK_0` 的推导**：`199980000 / 200000000 = 0.9999`，与 `CPU_CLOCK / 1000000000 = 0.9999` 是同一个系数 ⇒ **PS 的主 PLL 整体偏低 0.01%**，不是配置错误，而是晶振/PLL 的实际分频结果。

### 8.3 PL 侧 AXI IP 实例数（`soc_plat.h:336-345`）

| 宏 | 值 |
|---|---|
| `AL_AXI_DMA_NUM_INSTANCE` | 0 |
| `AL_AXI_ETH_LITE_NUM_INSTANCE` | 0 |
| `AL_AXI_GPIO_NUM_INSTANCE` | 0 |
| `AL_AXI_IIC_NUM_INSTANCE` | 0 |
| `AL_AXI_QSPI_NUM_INSTANCE` | 0 |
| `AL_AXI_SOFT_NPU_NUM_INSTANCE` | 0 |
| `AL_AXI_UART_LITE_NUM_INSTANCE` | 0 |
| `AL_AXI_VDMA_NUM_INSTANCE` | 0 |

---

## 九、总结

1. **通路**：PS↔PL 之间只有六条线，其中**只有三条是活的**（`p2f_clk0` / `p2f_rst0_n` / `Slave_AXI_HP0`）。
2. **方向**：PS→PL **只有时钟与复位**（`GPIO_PL` 断、`Master_AXI_GP0/GP1` 关）；PL→PS **只有写 DDR**（`f2p_irq` 恒 0）；**没有寄存器通道，没有中断**。
3. **分类**：问"要不要 PL 当中介"是问错了——应分 **A 型**（PS 外设走 MIO，PL 完全不参与）· **B 型**（PL 是 **AXI 从端**，被访问方）· **C 型**（PLB 旁路直连几根线）。
4. **关键约束**：`p2f_rst0_n` 直接接 PLL 的 `reset`，所以 **PS 不跑 ⇒ PLL 不 lock ⇒ 整链停**；这条线决定生死。
5. **能力边界**：**C 可以调 PL 外设，但需三件套齐备**（PL 侧 AXI 从端 + BD 开 `Master_AXI_GP0` + `AL_AXI_*_NUM_INSTANCE > 0`），当前三件全缺，**且 `al_axi_*` 驱动文件在本 SDK 里不存在**，须先向安路索取。

---

## 附：三条读数纪律（血泪教训）

1. **`_Dot_Enable` 与 `_Available` 是两套东西**。反例：`SD0_Dot_Enable=1` 但 `SD0_Available=0`；`MDIO0_Dot_Enable=1` 但 `MDIO0_Available=0`。⇒ **不要把 `_Available=0` 读成"功能关闭"**；涉及中断能不能用，以 **RTL 里那根线接到什么** 为准。
2. **宏被定义 ≠ 设备存在**。`GPIOPL_ENABLE` 在 `soc_plat.h:172` 有定义，但 `al_hal.h` 只认 `HAVE_GPIOPS_DRIVER`（无 `HAVE_GPIOPL_DRIVER`），且 `AlGpio_HwConfig[AL_GPIO_NUM_INSTANCE]` **只有 1 个条目**（`.DeviceId=0` / `GPIO_BASE_ADDR`）。⇒ **GPIO_PL 与 GPIO_PS 共用同一个控制器，没有独立设备实例。**
3. **"配置勾了" ≠ "RTL 接了"**。`GPIO_PL_Dot_Enable=1` 是真的，但 `pl_gpio_out` 引到顶层后悬空、`pl_gpio_oe` 是空连接、`pl_gpio_in` 接常量 `1'b0`——TD 自带的 `system/system.violation` 就是这条结论的直接证据。

## 附：源码索引（全部只读）

| 关注点 | 路径（相对 `mipiHDMIbySD/`） |
|---|---|
| PS↔PL 接口全量配置 | `soc_prj/uisrc/01_rtl/system/Design.xml` |
| BD 生成的 `system` 网表（看连线） | `soc_prj/uisrc/01_rtl/system/hdl/system.v` |
| 顶层 `system_top`（看谁被引出去） | `soc_prj/uisrc/01_rtl/system.v` |
| TD 自带的未连接告警 | `soc_prj/uisrc/01_rtl/system/system.violation` |
| PS 侧 IP 使能与 PL AXI IP 实例数 | `soc_sdk/soc_base/platform/inc/soc_plat.h` |
| 外设 HAL 总头与 AXI 驱动条件引入 | `soc_sdk/soc_base/dr1m90_fpsoc_cpu0/inc/al_hal.h` |
| PS 引脚复用出厂表 | `soc_sdk/soc_base/platform/src/soc_plat.c` 的 `psio_data_0[]` |

## 关联

- 本目录《00-教程规划-PS侧C开发（STM32视角）.md》—— PS 侧 C 开发的入门教程（外设清单、DevId、MIO 占用全表、API 对照）
- 上级目录《总控架构.md》—— 总控架构分层、I1–I10 接口契约、两条改造路线
- 上级目录《推进总控前/推进总控前的PS架构.md》—— PS 侧上电与初始化全流程
