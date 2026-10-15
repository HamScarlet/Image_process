# 方案 · PL 侧键灯经 `GPIO_PL` 接入 PS（K14 / M20）

> 工程：`PScontrol` ｜ 平台：DR1 + MLK-F3P-CZ02 ｜ 通路：**PS GPIO 的 `GPIO_PL` 扩展**（直连、非 AXI）
> 本文以图为主，逐级解释「每一级在干什么、每个参数为什么是这个数」。
> ⚠️ 本文是对《方案-用KEY3控制PS侧LED5的点亮规律.md》的**补充路线** —— 那条走 MIO（A 型），这条走 `GPIO_PL`（C 型）。两者 API 相同、编号不同。

---

## 一、图：主通路

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 544" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>PL 侧键灯经 GPIO_PL 接入 PS 的通路</title>
<desc>KEY1 经 ball K14 与 pin.adc 约束进 PL 顶层，由 BD 的三态缓冲送入 PS 的 GPIO_PL，映射为 Pin 54；C 程序处理后再写 Pin 55 反向驱动 M20 上的 LED4</desc>
<defs>
<marker id="flow1" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<rect x="40" y="30" width="600" height="50" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="51" font-size="13" font-weight="500" fill="#0C447C">KEY1 按键（底板，ball K14）</text>
<text x="60" y="69" font-size="12" fill="#185FA5">VCC_3V3 上拉 2.2K + 100R 串阻 + 100nF → 按下 = 0，松开 = 1</text>
<line x1="340" y1="80" x2="340" y2="100" stroke="#888780" stroke-width="1.5" marker-end="url(#flow1)"/>

<rect x="40" y="104" width="600" height="50" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="125" font-size="13" font-weight="500" fill="#0C447C">pin.adc 引脚约束</text>
<text x="60" y="143" font-size="12" fill="#185FA5">key → K14（LVCMOS33 + PULLUP）· led → M20（LVCMOS33 + DRIVE 8）</text>
<line x1="340" y1="154" x2="340" y2="174" stroke="#888780" stroke-width="1.5" marker-end="url(#flow1)"/>

<rect x="40" y="178" width="600" height="50" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="60" y="199" font-size="13" font-weight="500" fill="#444441">PL 顶层 system.v</text>
<text x="60" y="217" font-size="12" fill="#5F5E5A">module system(input I_sysclk, inout key, inout led) · .GPIO_pl_gpio_io({led, key})</text>
<line x1="340" y1="228" x2="340" y2="248" stroke="#888780" stroke-width="1.5" marker-end="url(#flow1)"/>

<rect x="40" y="252" width="600" height="50" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="60" y="273" font-size="13" font-weight="500" fill="#444441">BD 外壳 + DR1_LOGIC_IOTRIBUF × 2</text>
<text x="60" y="291" font-size="12" fill="#5F5E5A">.o(pl_gpio_in) .i(pl_gpio_out) .t(~pl_gpio_oe) .io(io) ⇒ oe=1 时驱动引脚</text>
<line x1="340" y1="302" x2="340" y2="322" stroke="#888780" stroke-width="1.5" marker-end="url(#flow1)"/>

<rect x="40" y="326" width="600" height="50" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="60" y="347" font-size="13" font-weight="500" fill="#633806">PS GPIO 控制器 · Bank2（基址 0xF8411300）</text>
<text x="60" y="365" font-size="12" fill="#854F0B">Pin 54 = bit0 = key(K14) · Pin 55 = bit1 = led(M20)</text>
<line x1="340" y1="376" x2="340" y2="396" stroke="#888780" stroke-width="1.5" marker-end="url(#flow1)"/>

<rect x="40" y="400" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="421" font-size="13" font-weight="500" fill="#085041">C 程序 · soc_sdk/fdma_en/main.c</text>
<text x="60" y="439" font-size="12" fill="#0F6E56">AlGpio_Hal_ReadPinInput(h, 54) → 消抖 → 模式机 → WritePin(h, 55, v)</text>
<line x1="340" y1="450" x2="340" y2="470" stroke="#888780" stroke-width="1.5" marker-end="url(#flow1)"/>

<rect x="40" y="474" width="600" height="50" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="60" y="495" font-size="13" font-weight="500" fill="#3C3489">LED4 + Q17（底板，ball M20）</text>
<text x="60" y="513" font-size="12" fill="#534AB7">栅 = M20，1 = 亮（写 Pin 55 后经同一 IOTRIBUF 反向传出）</text>
</svg>

**读图口诀**：自上而下是「按键 → 约束 → 顶层 → 缓冲 → 寄存器 → 程序 → 灯」。🔵 蓝色 = 板级输入与引脚约束；⚪ 灰色 = PL 侧只是"过路的"顶层与三态缓冲；🟡 橙色 = PS 的寄存器落点（`GPIO_PL` 的编号空间）；🟢 绿色 = 你写的逻辑；🟣 紫色 = 输出侧。**关键差别：这里 PL 里没有寄存器、没有时钟、没有逻辑，只有 2 个 IOBUF。**

---

## 二、一句话总览

**你已经在 TD 里给 PS 开了一扇"通往 PL 引脚的门"（`GPIO_PL`），K14 和 M20 就挂在这扇门后面；PS 侧读写的仍是同一套 GPIO API，只是编号从 50/51 变成 54/55。**

先建立一个认知：**PS 的 GPIO 控制器管的引脚不止 MIO 那 54 个。**它还有一路 **64 位**的扩展信号 `pl_gpio_in/out/oe[63:0]`，由 PL 侧的一排三态缓冲（IOBUF）接到任意 PL 引脚。这 64 位在 PS 眼里就是 **Pin 54–117** —— 编号连续、和 MIO 混在同一套寄存器里。

| 图/章节 | 回答的问题 | 类比 |
|---|---|---|
| 第一节 图 + 第三节 详解 | 信号**怎么从 K14 进 PS、又从 PS 到 M20** | 一扇后门：屋里的人（PS）伸手到院子里 |
| 第三节 图二 + 第五节 | **54/55 这两个号是怎么来的** | 门牌号：楼里的房间连续编号，前面 54 间是内房、后面 64 间是外房 |
| 第六节 配置链 | **TD 要做什么、还差哪一步** | 门已经装好了，只差把钥匙给你（写 C） |

---

## 三、逐级详解

### 第 1 级：KEY1 / LED4（底板器件）

| 项目 | 内容 |
|---|---|
| 器件位号 | `KEY1`（ball **K14**）、`LED4`（ball **M20**） |
| 网络名 | `B35_L20P_K14` / `B35_L7N_M20` —— 命名规则是「Zynq 叫法的 BANK35 + 对号 + **DR1 球号**」 |
| KEY1 电路 | `VCC_3V3 —R110(2.2K)— R166(100R)— KEY1 — GND`，节点并 `C99(100nF)` ⇒ **按下 = 0** |
| LED4 电路 | `VCC_3V3 —限流电阻— LED4 — Q17(漏)`，**栅极 = M20**，源极 = GND ⇒ **写 1 = 亮** |
| 归属 | **PL 的 BANK33**（3.3 V 域） |
| 干什么 | 提供"人手按键"与"可见指示"两个物理接口 |
| 为什么能用 | 这两根线**在芯片外部已经焊死在 PL 引脚上** —— 想用它们，就必须让 PL 参与（哪怕只是当个"过路的"） |

> 🔴 **注意区分**：KEY4 接 `PS_SRST_B`，是 PS 复位键，**不能用**。MIO50/51 上的 KEY3/LED5 是另一对，走 A 型，见配套文档。

### 第 2 级：`pin.adc` 引脚约束

| 项目 | 内容 |
|---|---|
| 文件 | `soc_prj/uisrc/04_pin/pin.adc`（全文 3 行） |
| 干什么 | 告诉 TD："`key` 这个顶层端口，物理上就是 K14" |
| 具体内容 | `I_sysclk → H16`（LVCMOS33 + PULLUP）· `key → K14`（LVCMOS33 + PULLUP）· `led → M20`（LVCMOS33 + DRIVE 8 + NONE） |
| 为什么 | 不写这个，TD 会把 `key`/`led` 随机分配到某个空闲脚上，板上按键和灯就"接错人"了 |
| 为什么 PULLUP | KEY1 外部已有 2.2K 上拉，这里再配一次是**冗余保险**；`led` 配 `NONE`（推挽输出不需要上下拉，避免与 MOS 栅极争电流） |

### 第 3 级：PL 顶层 `system.v`

```verilog
module system(
    input I_sysclk,
    inout key,
    inout led
);
wire [1:0] GPIO_pl_gpio_io;
wire       p2f_clk0;
assign p2f_clk0 = I_sysclk;

ARMandgpioDesign u_ARMandgpioDesign (
    .GPIO_pl_gpio_io    ({led, key}),
    .p2f_clk0           (p2f_clk0)
);
endmodule
```

| 项目 | 内容 |
|---|---|
| 参数 | `GPIO_pl_gpio_io[1:0]` —— **Verilog 拼接 `{led, key}` ⇒ 高位 led、低位 key** |
| 干什么 | 把板级两个 `inout` 端口，拼成 BD 期望的那根 2 位双向总线 |
| 为什么是 `inout` | 同一根线既可能被读（key）又可能被驱（led），双向 IO 才能都兼顾 |
| ⚠️ 位序陷阱 | 拼接顺序决定了 **`io[0] = key`、`io[1] = led`** —— 这一条直接决定了后面 Pin 号是 54 还是 55，**改拼接顺序就要跟着改 C 代码** |

### 第 4 级：BD 外壳的三态缓冲

TD 的 Design Integrator 自动生成外壳 `ARMandgpioDesign.v`，关键就两行：

```verilog
DR1_LOGIC_IOTRIBUF GPIO_pl_gpio_DR1_LOGIC_IOTRIBUF_0 (
    .o (w_..._pl_gpio_in[0:0]),    // 引脚 → PS（读回）
    .i (w_..._pl_gpio_out[0:0]),   // PS → 引脚（写出）
    .t (~w_..._pl_gpio_oe[0:0]),   // 三态控制
    .io(GPIO_pl_gpio_io[0:0]) );   // 双向引脚
```

| 项目 | 内容 |
|---|---|
| 元件 | `DR1_LOGIC_IOTRIBUF`（安路 DR1 的 IO 三态缓冲原语） |
| 干什么 | 把一根双向线拆成"读回 / 写出 / 方向"三路信号 |
| 为什么 `t = ~oe` | `t` 是**高阻控制**（t=1 高阻）；`oe = 1` 表示要输出 ⇒ 取反后 t=0 才驱动。**这就是"方向"的物理实现** |
| 为什么在 BD 里 | 这是 TD 图形化流程的标准做法：你在 BD 里勾一个 GPIO 外部接口、给几位，DI 就自动生成对应数量的 IOTRIBUF，不用手写 |

> ⚠️ **这条路径的代价在这一级体现**：位流不加载，这些 IOBUF 就没被配置，K14/M20 处于高阻态 —— **按键读不到、灯点不亮**。这是与 MIO 方案最本质的区别。

### 第 5 级：PS 的 `GPIO_PL` 参数

| 项目 | 内容 |
|---|---|
| IP | `system_ARM_Processor_System_0`（TD 的 PS IP） |
| 参数 | **`GPIO_PL_Dot_IO = 2`**、`P2F_CLK0_DIV = 8` |
| 端口 | `input [1:0] pl_gpio_in` · `output [1:0] pl_gpio_oe` · `output [1:0] pl_gpio_out` |
| 位宽上限 | **64**（IP RTL 里 `parameter GPIO_PL_Dot_IO = 64`；未使能时接 `.gpio_in(64'h0)`） |
| 干什么 | 声明"PS 的 GPIO 控制器要向外扩几位" |
| 为什么 2 | 你正好要一个输入（key）+ 一个输出（led）⇒ 2 位足够。**想要更多 PL 引脚，改大这个数即可，上限 64** |
| 总线语义 | `GPIO` 这个 bus 的定义是 **`directConnection = true` + `isAddressable = false`** ⇒ **直连、不吃地址、不走 AXI** |

### 第 6 级：编号映射（`GPIO_PL` → Pin 54–117）

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 214" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>PS GPIO 的 118 个 Pin 编号空间</title>
<desc>Pin 0-53 是 MIO，Pin 54-117 是 GPIO_PL 的 64 位；本次用到 Pin 54 与 55</desc>

<rect x="40" y="60" width="270" height="56" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="175" y="82" font-size="13" font-weight="500" fill="#0C447C" text-anchor="middle">MIO · Pin 0–53</text>
<text x="175" y="102" font-size="12" fill="#185FA5" text-anchor="middle">芯片固定引脚 · KEY3 / LED5 在此</text>

<rect x="320" y="60" width="320" height="56" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="480" y="82" font-size="13" font-weight="500" fill="#633806" text-anchor="middle">GPIO_PL · Pin 54–117</text>
<text x="480" y="102" font-size="12" fill="#854F0B" text-anchor="middle">64 位 · 可接任意 PL 引脚</text>

<line x1="390" y1="116" x2="390" y2="150" stroke="#888780" stroke-width="0.5" stroke-dasharray="4 4"/>

<rect x="180" y="150" width="140" height="44" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="250" y="165" font-size="12" font-weight="500" fill="#C83C3C" text-anchor="middle">Pin 54 = key</text>
<text x="250" y="181" font-size="12" fill="#C83C3C" text-anchor="middle">Bank2 bit0 · K14</text>

<rect x="340" y="150" width="140" height="44" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="410" y="165" font-size="12" font-weight="500" fill="#C83C3C" text-anchor="middle">Pin 55 = led</text>
<text x="410" y="181" font-size="12" fill="#C83C3C" text-anchor="middle">Bank2 bit1 · M20</text>
</svg>

**读图口诀**：PS 眼里的一维编号从 0 排到 117。左边 54 个（0–53）是"内房"（MIO，焊死在 PS 引脚上）；右边 64 个（54–117）是"外房"（`GPIO_PL`，接哪由你定）。本次只用最前面两间外房：54 号是 key、55 号是 led（红框）。

**这个编号方案不是猜的，是三重吻合推出来的**：

| 证据 | 值 | 出处 |
|---|---|---|
| 驱动支持的 Pin 总数 | **118** | `al_gpio_hw.h:23 GPIO_MAX_PIN_NUM` |
| Bank 边界 | 31 / 53 / 85 / 117 | `al_gpio_hal.h` 的 `MAX_PIN_NUMBER_IN_BANK_0/1/2/3` |
| Bank0 + Bank1 = MIO | 32 + 22 = **54** | MIO 共 54 个 |
| Bank2 + Bank3 | 32 + 32 = **64** | ＝ `GPIO_PL` 的位宽上限 |
| 118 − 54 | = **64** ✓ | 两组数完全吻合 |

⇒ **`GPIO_PL` 的 bit*n* 对应 Pin (54 + n)**，而 `{led, key}` 决定了 bit0 = key、bit1 = led ⇒ **key = 54、led = 55**。
⇒ 寄存器地址：Bank2 基址 = `0xF8411000 + 2 × 0x100 = 0xF8411300`（`DR +0x0`、`DDR +0x4`、`EXT_PORTA +0x50`）。

> ⚠️ **「bit0 ↔ Pin 54」这一步没有官方文档明文**，是把上面五条数据串起来推的。上板后拿 `ReadPinInput(h, 54)` 试一下即可确认；若不动，改试 55（可能顺序相反）。**这是本方案唯一需要实测标定的点。**

### 第 7 级：PS 侧 C 代码

最简可用版本（把 `fdma_en/main.c` 的场景从 MIO 换成 `GPIO_PL`）：

```c
#include <stdio.h>
#include "al_core.h"
#include "al_systimer.h"
#include "al_gpio_hal.h"

#define PIN_KEY   54u    /* GPIO_PL bit0 → key (K14) */
#define PIN_LED   55u    /* GPIO_PL bit1 → led (M20) */

static AL_GPIO_HalStruct *g_gpio = AL_NULL;

int main(void)
{
    AlGpio_Hal_Init(&g_gpio, 0u, AL_NULL);   /* DevId = 0，与 MIO 方案相同 */

    AlGpio_Hal_WritePin(g_gpio, PIN_LED, 0u);
    printf("PL gpio: key(Pin54) -> led(Pin55)\r\n");

    while (1) {
        AL_U32 pressed = !AlGpio_Hal_ReadPinInput(g_gpio, PIN_KEY);
        AlGpio_Hal_WritePin(g_gpio, PIN_LED, pressed);
        AlSys_MDelay(10);
    }
}
```

| 项目 | 内容 |
|---|---|
| 头文件 | `al_gpio_hal.h` —— **与 MIO 方案完全同一个** |
| DevId | **0**（`AlGpio_HwConfig[0]`，一条配置管全部 118 个 Pin） |
| 干什么 | 读 key → 消抖 → 驱动 led |
| 为什么不用别的驱动 | `GPIO_PL` 与 MIO **共用同一个 GPIO 控制器**，`HAVE_GPIOPS_DRIVER` 一个宏全包了 —— **不需要 AXI 驱动、不需要额外实例** |

---

## 四、三型通路归属

| 型 | 通路 | 本项目实例 |
|---|---|---|
| **A 型** | PS 外设 → MIO → 芯片引脚 | ✅ KEY3(MIO50) / LED5(MIO51) —— 见配套文档 |
| **B 型** | `Master_AXI_GP0/GP1` → PL 的 AXI 从端 | ❌ 本项目 `GP0/GP1 = 0/0` |
| **C 型** | 旁路直连（不吃地址、不走 AXI） | ✅ **本文的 `GPIO_PL`** —— `directConnection=true` + `isAddressable=false` |

> **一个重要认知**：C 型并不等于"断的"。之前看到「`GPIO_PL` 三线全断」的结论来自 `mipiHDMIbySD` 工程 —— **这个状态逐工程不同**。你的 `PScontrol` 是**完整接通**的（`Dot_Enable=1`、`Dot_IO=2`、BD 有实例、引脚有约束、位流已生成）。

---

## 五、时钟与复位

| 项目 | 值 / 状态 | 说明 |
|---|---|---|
| PL 时钟 | `I_sysclk` → **H16**（100 MHz 板载晶振，`LVCMOS33`） | 被顶层声明、被约束，但 **`GPIO_PL` 是纯组合透传，逻辑上并不用它** |
| `p2f_clk0` | `ARMandgpioDesign` 的 output，`soc_plat.h` 记 `P2F_CLOCK_0 = 49995000`（约 50 MHz） | IP 参数 `P2F_CLK0_DIV = 8`；顶层里 `assign p2f_clk0 = I_sysclk` 只是占位，**本方案不依赖它** |
| 是否需要 PLL | **不需要**（PL 里没有时序逻辑） | 相比视频链路那种 8 个 PLL 的工程，这里简单到极致 |
| PL 复位 | `P2F_Reset0_Available = 0`（未使能） | **不影响** —— IOBUF 是组合元件，不受 PL 复位控制 |
| PS 复位 | 上电 / `PS_SRST_B`（KEY4） | 一按 GPIO 寄存器全回复位值 |

> ⚠️ **`GPIO_PL` 真正依赖的不是时钟，是"位流已加载"** —— 因为 IO 标准、方向、上下拉、驱动强度这些参数都在位流里。

---

## 六、配置与执行链

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 470" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>GPIO_PL 方案的配置链与待办</title>
<desc>TD 与 PL 侧五步已全部完成，只剩 PS 侧写 C 代码</desc>
<defs>
<marker id="flow3" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<rect x="40" y="30" width="600" height="50" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="60" y="51" font-size="13" font-weight="500" fill="#444441">① TD：勾选 GPIO_PL_Dot_Enable，位宽设为 2 ✅</text>
<text x="60" y="69" font-size="12" fill="#5F5E5A">Design.xml: GPIO_PL_Dot_Enable = 1 · GPIO_PL_Dot_IO = 2</text>
<line x1="340" y1="80" x2="340" y2="100" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<rect x="40" y="104" width="600" height="50" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="60" y="125" font-size="13" font-weight="500" fill="#444441">② TD：DI 自动生成 2 个 DR1_LOGIC_IOTRIBUF ✅</text>
<text x="60" y="143" font-size="12" fill="#5F5E5A">外壳 ARMandgpioDesign.v 内，无需手写</text>
<line x1="340" y1="154" x2="340" y2="174" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<rect x="40" y="178" width="600" height="50" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="199" font-size="13" font-weight="500" fill="#0C447C">③ PL 顶层接出 key / led，并拼成 2 位总线 ✅</text>
<text x="60" y="217" font-size="12" fill="#185FA5">system.v: inout key, inout led → .GPIO_pl_gpio_io({led, key})</text>
<line x1="340" y1="228" x2="340" y2="248" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<rect x="40" y="252" width="600" height="50" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="273" font-size="13" font-weight="500" fill="#0C447C">④ 引脚约束 key → K14、led → M20 ✅</text>
<text x="60" y="291" font-size="12" fill="#185FA5">pin.adc 3 行 · LVCMOS33 · key 带 PULLUP、led 带 DRIVE 8</text>
<line x1="340" y1="302" x2="340" y2="322" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<rect x="40" y="326" width="600" height="50" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="60" y="347" font-size="13" font-weight="500" fill="#633806">⑤ TD：综合 + 布局布线 → PScontrol.bit ✅</text>
<text x="60" y="365" font-size="12" fill="#854F0B">PScontrol_Runs/best_result/PScontrol.bit 已生成</text>
<line x1="340" y1="376" x2="340" y2="396" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<rect x="40" y="400" width="600" height="50" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="60" y="421" font-size="13" font-weight="500" fill="#C83C3C">⑥ PS 侧：写 C 代码 —— 唯一待做的一步</text>
<text x="60" y="439" font-size="12" fill="#C83C3C">ReadPinInput(h, 54) / WritePin(h, 55, v) · DevId = 0</text>
</svg>

**读图口诀**：前五格全打 ✅（灰色 TD 配置 → 蓝色 PL 侧 → 橙色位流），最后一格是红框待办。**换句话说：硬件侧你已经完成，这一格填上程序就闭环。**

### 6.1 已就绪清单（逐项核对）

| 检查项 | 现状 | 出处 |
|---|---|---|
| `GPIO_PL_Dot_Enable` | `1` | `Design.xml:162`（BD）/ `:455`（platform） |
| `GPIO_PL_Dot_IO` | `2` | 同上 `:163` / `:456` |
| BD 外壳有 IOTRIBUF × 2 | ✅ | `ARMandgpioDesign/hdl/ARMandgpioDesign.v:32-40` |
| PL 顶层拼接 `{led, key}` | ✅ | `uisrc/01_rtl/system.v:13` |
| 引脚约束 K14 / M20 | ✅ | `uisrc/04_pin/pin.adc:2-3` |
| 综合 + P&R | ✅ | `syn_1` + `phy_1` 已跑完 |
| 位流文件 | ✅ | `PScontrol_Runs/best_result/PScontrol.bit` |
| `Master_AXI_GP0/GP1` | `0/0` | **不需要，无影响** |
| `P2F_Reset0_Available` | `0` | **不需要，无影响** |

### 6.2 上板步骤

1. FD 打开 `PScontrol` → 编译 `soc_base`（`HAVE_GPIOPS_DRIVER` 已定义）+ `fdma_en`
2. **下载 PL 位流**（`Program FPGA` 勾上，或用 `BOOT.BIN`）—— **这一步不能省**
3. 下载 PS 程序；若用 debug，取消「Set stop at: main」
4. 串口（板上 **Type-C** 口 / UART1）看 `PL gpio: key(Pin54) -> led(Pin55)`
5. 按 KEY1 → LED4 跟随

---

## 七、其他细节速查

### 7.1 与 MIO 方案的差别（同一套 API，不同的"门"）

| 维度 | MIO50/51（KEY3 / LED5） | Pin 54/55（K14 / M20） |
|---|---|---|
| 通路 | PS GPIO → MIO 引脚 | PS GPIO → `pl_gpio_*` → PL 的 IOBUF → 引脚 |
| 三型归属 | **A 型** | **C 型**（直连，非 AXI） |
| API / 驱动 | `AlGpio_Hal_*` | **完全相同** |
| 头文件 | `al_gpio_hal.h` | **完全相同**（`HAVE_GPIOPS_DRIVER` 一个宏全包） |
| DevId | `0` | `0` |
| Pin 号 | 50 / 51（Bank1 bit18/19） | **54 / 55（Bank2 bit0/1）** |
| 电平 | 1.8 V | **3.3 V**（`LVCMOS33`） |
| PL 位流 | **不需要** | **必须加载** |
| PL 逻辑开销 | 0 | **2 个 IOBUF**（无寄存器/无时钟/纯组合） |
| PL 时钟 | 不需要 | **不需要** |
| 额外延迟 | — | 多一级 IOBUF，**ns 级** |
| 上板方式 | TD 直下也能跑 | **必须位流已加载**（FD 或 `BOOT.BIN`） |
| 可扩数量 | MIO 侧只剩 52 / 53 | **最多 64 位**（改 `GPIO_PL_Dot_IO` 即可） |
| 外部电路 | KEY3 RC 上拉 / LED5 经 MOS | **结构相同**（KEY1 RC 上拉 / LED4 经 Q17 MOS 低边） |
| 判据 | 按下 = 0、写 1 = 亮 | **完全一样** |

### 7.2 故障对照表

| 现象 | 首先怀疑什么 |
|---|---|
| 读 Pin 54 恒为 1，按 KEY1 无变化 | **PL 位流没加载**（最常见）；其次试 Pin 55（位序可能相反） |
| 读 Pin 54 恒为 0/1 且与按键无关 | `pin.adc` 是否真的被用（`PScontrol.al` 里 `UsedInSyn/P&R = true`） |
| 写 Pin 55 灯不亮 | 位流未加载；或 `pin.adc` 的 `led` 行被改；M20 上还有别的驱动源 |
| 灯一直亮 | `led_update` 未生效；或 `led` 引脚配了 `PULLUP`（应为 `NONE`） |
| 按 KEY1 时读值跳变厉害 | 未做软件消抖（外部 100nF 只滤高频，不解决机械抖动） |
| 编译报 GPIO 相关错 | `fdma_en/main.c` 还是 10-06 的诊断插桩版，先清掉 |
| TD 综合报 `key`/`led` 未约束 | `pin.adc` 未加进工程（`PScontrol.al` 的 `ADC_FILE` 段） |

### 7.3 交叉引用

- 同目录 `方案-用KEY3控制PS侧LED5的点亮规律.md` —— **MIO 路线（A 型）**，含 GPIO 驱动的寄存器全表、API 一览、四个源码级陷阱
- `..\..\PS与PL的联通\PS与PL通路范式（目标态）.md` —— A / B / C 三型通路总览
- `..\..\PS与PL的联通\J12-CEP-24口在链路中的作用.md` —— 需要更多 PL 引脚时的另一条出口（J12 / BANK11）
- `..\..\PS与PL的联通\总控前的PS与PL关系全解.md` —— 现状通路的完整清单

---

## 八、参数一览

| 常量 / 参数 | 值 | 推导 / 出处 |
|---|---|---|
| `GPIO_BASE_ADDR` | `0xF8411000` | `al_gpio_hw.h:20` |
| `GPIO_REG_OFFSET`（Bank 步长） | `0x100` | `al_gpio_hal.h` |
| Bank2 基址 | `0xF8411300` | `0xF8411000 + 2 × 0x100` |
| `GPIO_MAX_PIN_NUM` | `118` | `al_gpio_hw.h:23` |
| `MAX_PIN_NUMBER_IN_BANK_0/1/2/3` | `31 / 53 / 85 / 117` | `al_gpio_hal.h:88-91` |
| MIO 段 | Pin `0–53` | Bank0（32）+ Bank1（22） |
| `GPIO_PL` 段 | Pin `54–117` | Bank2（32）+ Bank3（32）= 64 |
| `key` → Pin | **54** | `54 + bit0`，bit0 来自 `{led, key}` 的低位 |
| `led` → Pin | **55** | `54 + bit1` |
| `key` 掩码 / `led` 掩码 | `1<<0` / `1<<1`（Bank2 内） | — |
| `GPIO_PL_Dot_IO` | **2** | `Design.xml:163` |
| `GPIO_PL_Dot_IO` 上限 | **64** | `ARM_Processor_System.v` 参数默认值 |
| `P2F_CLK0_DIV` | `8` | `system_ARM_Processor_System_0.v` |
| `P2F_CLOCK_0` | `49995000` | `soc_plat.h:106` |
| `DeviceId` | `0` | `al_gpio_cfg.c` |
| `key` 引脚 | ball **K14**，`LVCMOS33` + `PULLUP` | `pin.adc:2` |
| `led` 引脚 | ball **M20**，`LVCMOS33` + `DRIVE 8` + `NONE` | `pin.adc:3` |
| `I_sysclk` 引脚 | ball **H16**，`LVCMOS33` + `PULLUP` | `pin.adc:1` |
| 按键判据 | 按下 = 0 | 外部 2.2K 上拉到 3V3 |
| LED 判据 | 写 1 = 亮 | N-MOS 低边驱动 |

---

## 九、总结

1. **通路**：KEY1(K14) → `pin.adc` → PL 顶层 → BD 的 IOTRIBUF → PS 的 `GPIO_PL`（Pin 54）→ C 程序 → Pin 55 → IOTRIBUF → LED4(M20)，是一条 **C 型**（旁路直连）通路。
2. **变形**：PL 侧只做了一次"双向线拆成读/写/方向三路"的电气变形，**没有任何数据处理**。
3. **编号**：`GPIO_PL` 的 bit*n* = **Pin (54 + n)**；由 `GPIO_MAX_PIN_NUM=118`、Bank 边界、`GPIO_PL_Dot_IO` 上限 64 三重叠合推得。
4. **关键约束**：PL 位流**必须加载**（否则 IOBUF 不工作）；API 与 MIO 方案**完全相同**；`{led, key}` 的拼接顺序决定 Pin 号。
5. **当前状态**：TD / BD / 约束 / 位流**全部就绪**，只差 PS 侧 C 代码 —— 一个 `ReadPinInput(h,54)` + `WritePin(h,55,v)` 就闭环。
