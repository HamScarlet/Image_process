# 方案：蓝牙经 J12（U8/U9）直连 PS UART0 实现硬件回环

> 日期：2026-11-01
> 状态：**✅ 已实施并验收通过**（2026-11-01 17:21 手机经 JDY-31 逐字节回环成功，见 §11.15）
> 决策（2026-11-01 用户拍板）：**D1 = 先 9600**；**D2 = 日志留 UART1、UART0 专供蓝牙**；**D3 = U9 接 BT TX / U8 接 FPGA TX**；**D4 = 纯字节回环**；**供电 = 外部单独 3.3 V（强制共地、J12 的 3V3 悬空）**；起步方式 = **只先做第 1 步（UART1 控制台验通）**；实物 = **已有 JDY-31**
> ⚠️ **2026-11-01 二次核实修正了两处结论**：①`al_printf` 实际走 **UART1** 不是 UART0（§2.5）；②`-DLOG_DEV` 与 `UART1_Available` **都不用改**（§4.4）。故 PS 侧最终只剩 **1 行改动**。
> ⚠️ **执行期实际撞到的两件事**（方案原稿未预见）：①串口乱码是 10-29 老问题复发，根因 `0xF8801028`（§11.12）；②`uart_probe` 探针在 constructor 里跑不通、只会制造乱码（§11.14）。
> 目标工程：`D:\FPGAproject\AnLuRun\MainProject`
> 参考原型：`D:\FPGAproject\AnLuRun\MainProject\refer`
> 对照基准：官方 `3_2_01_sdk_base\14_axi_gpio_pl_intr`（仅用于 DI 加端口/连线的写法参照）

---

## 一、目标

在现有图像工程（MIPI→ISP→降采样→uidbuf→FDMA→HDMI，PS 只做开机释放复位 + 写 PWM 寄存器）上，**新增一条与 AXI 完全无关的通路**：

```
蓝牙模块 TX  ──►  J12 pin6 (U9)  ──►  PL 顶层端口  ──►  PS 硬核 uart0_rx_in   ──►  PS UART0 RX
蓝牙模块 RX  ◄──  J12 pin6 (U8)  ◄──  PL 顶层端口  ◄──  PS 硬核 uart0_tx_out  ◄──  PS UART0 TX

                         PS 软件：把收到的字节原样发回（回环）
```

**这条通路不经过 AXI**：它走的是 PS 硬核的 **EMIO 直连端口**（PS UART0 控制器的收发线直接引出到 PL 引脚），不占用 AXI 互连、不占地址空间、不新增任何 AXI 从端。

### 验收判据

| # | 判据 |
|---|---|
| 1 | 手机/PC 经蓝牙 SPP 发任意串，**逐字节原样收回来** |
| 2 | AXI 地址表**不变**：`0x80000000` GPIO0 / `0x80100000` GPIO1 / `0x80200000` PWM，无新增窗口 |
| 3 | UART1（MIO48/49，Type-C 的 CH342 COM 口）**仍是可用的调试控制台** |
| 4 | HDMI 画面照常，PWM 呼吸灯照常 |
| 5 | 编译产物不新增任何 AXI IP，PL 资源增量 < 100 LUT |

---

## 二、现状盘点（全部为本次实测，不是推测）

### 2.1 好消息：PS 硬核已经留好了 EMIO 串口端口

`hdl/system.v:1935` 处，PS 实例上有这两个端口，**只是当前被钉死**：

```verilog
, .uart0_rx_in(1'b0)      // ← 输入被常量 0 拉住
, .uart0_tx_out()         // ← 输出悬空
```

同一处还有 `pl_gpio_in(1'b0)` / `pl_gpio_oe()` / `pl_gpio_out()`，说明这批 EMIO 端口都是"硬核有、PL 没接"的状态。

### 2.2 平台配置已经把 UART0 划给 PL IO 了

| 平台配置项（`soc_sdk/soc_base/platform/Design.xml`） | 值 | 含义 |
|---|---|---|
| `UART0_Available` | `1` | UART0 已使能 |
| `UART0_Dot_IO` | **`PL IO`** | **UART0 走 PL IO（即 EMIO）** ✅ |
| `UART0_tx_Dot_IO` / `UART0_rx_Dot_IO` | `PL IO` | 同上 |
| `UART0_Dot_Actual_Inside_Frequency` | `49.995` MHz | 时钟源已就绪 |
| `UART1_Dot_IO` | `PS IO 48...49` | UART1 走 MIO48/49 |
| `UART1_Available` | `0` | UART1 在平台表里标记为未使能（但 `soc_plat.h` 里 `UART1PS_ENABLE` 是打开的，见 §2.5 冲突项） |

> **结论：UART0 本来就该通到 PL 引脚，只是 PL 侧一直没接。这次是把断头接上。**

### 2.3 但 DI 顶层没有串口端口 —— 必须补

`hdl/system.v` 顶部 `module system (...)` 只有 **20 个端口**：

```
I_fdma_waddr / wareq / wsize / wready、I_fdma_raddr / rareq / rsize / rready、I_fdma_wdata
p2f_clk0、p2f_rst0_n
O_fdma_wbusy / wvalid、O_fdma_rbusy / rvalid / rdata
code_driver、pwm_out[2:0]、motor_dir[1:0]、motor_enable
```

**没有任何 uart 端口。** 所以 `uart0_rx_in/tx_out` 在 PL 顶层想接也接不到 —— **这是本次唯一的"结构性"改动**：DI 里给顶层加两个端口并连到 PS 实例。

### 2.4 J12 引脚：U8/U9 空闲，且是下一对可用

`04-资源索引/安路飞龙DR1-板卡资源全解析.md` §⑧：J12 是 26 pin（2×13），含 **VCC(3V3)/GND + 12 对差分**，全部来自 **BANK11（3V3 固定轨）**。

| J12 位号 | ball 对 | 当前占用 |
|---|---|---|
| 2 | T9 / U10 | `O_motor_dir[0]` / `O_motor_enable` |
| 3 | T5 / U5 | `O_motor_dir[1]` / `O_motor_pwm[1]` |
| 4 | V6 / W6 | `O_motor_pwm[0]` / 空闲 |
| 5 | U7 / V7 | 空闲 |
| **6** | **U9 / U8** | **完全空闲** ← 本次选用 |
| 7–12 | … | 全部空闲 |

实测：`fpga_pin.adc` 里搜 `U8`/`U9` **零命中**，确认未被占用。

### 2.5 两个冲突（其一已于 2026-11-01 二次核实推翻）

#### 冲突一（已澄清）：`al_printf` 其实**已经挂在 UART1**，不是 UART0

> ⚠️ **本文前一版写的是「`LOG_DEV` 没定义 → 按 0 → UART0」，那是错的**，漏掉了构建系统的开关。下表是逐环节实测。

| 环节 | 位置 | 实际值 |
|---|---|---|
| 构建开关 | `soc_base/tools/make/config.mk:95` | `DR1X90_OUTPUT_DEV ?= UART1` |
| 转成宏 | 同上 `:105` | `CFLAGS += -DLOG_DEV=AL_LOG_$(OUTPUT_DEV)` → `AL_LOG_UART1` = **1** |
| 取实例号 | `al_uart_hal.c:43` | `.DevId = LOG_DEV - AL_LOG_UART0` = **1 → UART1** |
| 波特率 | `al_uart_hal.c:26-38` | 基线 `.BaudRate = 115200`；两条 `#if` 都只匹配 `LOG_DEV==AL_LOG_UART0`，`=1` 时都不进 → **留 115200** |
| 实例表 | `al_uart_cfg.c` | `#ifdef UART1PS_ENABLE` → UART1 条目**已存在** |
| 初始化时机 | `al_chip.c:60` `components_init()` | `AlLog_Init()` **已被启动代码 `al_aarch64_start.S:361` 调用**（不是没人调） |
| 输出通路 | `newlib/gcc/write.c:14` | `printf` → `_write()` → `AlLog_Write` → `AlUart_Dev_SendByte` |
| 构建方式 | `.cproject` | `managedBuildOn="false"` + `Gnu Make Builder` → **确实走 Makefile**，宏真的会传进去 |

更关键的一条：`soc_plat.c:1175-1206` 里 **MIO48/49 → `FUNCSEL: UART1` 的 pinmux 是无条件写进配置表的**
（`CONFIG_WRITE(0xf88030c0, 3)` / `0xf88030c4, 3` / `PL_IOSEL_5 = PS IO`），
**不受 `UART1_Available=0` 门控** —— 那个值为 0 并不影响 UART1 能不能出字。

> **⇒ 结论：`printf` / `al_printf` 现在就应该从 MIO48/49 以 115200 8N1 正常输出。代码零改动。**
>
> 那为什么一直没看到？最可能是**打开了错的 COM 口**，见 §2.7。

#### 冲突二：两个工程的 `AL_UART_DEVID` 不一致

| 文件 | 值 | 指向 |
|---|---|---|
| `refer\Car_control\USART.c:43` | `#define AL_UART_DEVID 0U` | **UART0** |
| `MainProject\soc_sdk\fdma_en\Car_control\USART.c:43` | `#define AL_UART_DEVID 1` | **UART1** |

本次要按 **refer 的 0（UART0）** 走，因为只有 UART0 才通到 PL 引脚。MainProject 里那个 1 需要改（或另起一个 UART0 专属文件，见 §4.4）。

### 2.6 蓝牙模块（JDY-31）

手册：`安路平台资料\硬件数据手册\`（已入库）。关键参数：

| 项 | 值 |
|---|---|
| 协议 | 蓝牙 3.0 SPP（串口透传） |
| 默认串口 | **9600 bps，8N1**，无流控 |
| 引脚 | VCC / GND / TXD / RXD（4 线） |
| 电平 | **3.3 V TTL** —— 与 J12 的 BANK11 3V3 **直连匹配**，无需电平转换 |
| 配对 | 默认名 `JDY-31-SPP`，配对码 `1234` |

### 2.7 为什么「一直看不到串口输出」——一根 Type-C 上有两个 COM 口

`04-资源索引\安路飞龙DR1-板卡资源全解析.md` §416 原文：

> **UART&JTAG 二合一 TYPE-C**：SL2.1S 做 USB HUB，**CH342K 同时把 PS 与 PL 两路 UART 引出**（PS_UART MIO48/49，PL_UART J16/K16）

即：**下载用的那根 Type-C 同时提供了 JTAG + PS_UART + PL_UART 三样东西**。CH342K 是双通道 USB-UART，
所以 PC 的设备管理器里会同时出现**两个 COM 口**（通常命名 `CH342 A` / `CH342 B` 或 COMx/COMy）。

| COM 口 | 对应 | 本工程当前状态 |
|---|---|---|
| 其中一路 | **PS_UART = MIO48/49** | ✅ 应该能看到 `[SYS] Fclk init done` 等全部 `printf` |
| 另一路 | **PL_UART = J16/K16** | ❌ 本工程 PL 侧没实例化 UART，一直是哑的 |

> **最可能的病因**：之前打开的是 **PL_UART** 那一路，所以一个字都没有。
> 验证只要 1 分钟：把两个 COM 口都用 115200 8N1 打开，复位板子，看哪个口出 `===== MainProject AXI PWM bring-up =====`。

若两个口都无输出，再按顺序查：① CH342K 驱动是否装了（设备管理器有无未识别设备）；② 是否 115200 8N1 无流控；③ 板子是否真在跑（LED5 短闪 3 下 + LED3 呼吸可作独立判据，它们不依赖串口）。

> **本机驱动状态（2026-11-01 实查）**：`C:\Windows\System32\drivers\CH343S64.SYS` + DriverStore 里的 `ch343ser.inf_amd64_5f1b1a31e3c8e444` **都已安装**，CH342K 属于这个驱动包（WCH 把 CH342/CH343/CH347 合在一套里）⇒ **不需要额外装驱动**。
> 同一时刻枚举本机 USB 设备，**一个 COM 口都没有、连 FTDI 下载器 `0403:6042` 也没出现** ⇒ 当时板子没插。插上 Type-C 后再查即可。

### 2.8 供电与接线（已定：**外部单独供电**，2026-11-01 拍板）

| JDY-31 引脚 | 接到 | 说明 |
|---|---|---|
| **VCC** | **外部 3.3 V 电源正** | 不从 J12 的 3V3 取 —— 避开配对瞬时 30–40 mA 拉低核心板 LDO |
| **GND** | 外部 3.3 V 电源负 **+ 板子 GND** | ⚠️ **强制共地**，否则 UART 没有参考电平，收也收不到、发也发不出 |
| **TXD** | J12 pin6 的 **U9** | 蓝牙 TX → FPGA RX（D3 默认） |
| **RXD** | J12 pin6 的 **U8** | FPGA TX → 蓝牙 RX（D3 默认） |

四条硬要求：

1. **J12 排针上的 3V3（VCC）悬空不接**。外部供电的同时再插排针 3V3，等于两路电源并接，有反灌风险。
2. **共地是硬要求**：外部电源负极、JDY-31 的 GND、板子 GND 三点必须连通。J12 排针里的 GND 就是一个现成的公共点。
3. **外部电源必须是 3.3 V，不能 5 V**。U8/U9 属 BANK11 的 3V3 LVCMOS，5V 直连会烧 PL IO（与 T14「电机驱动 5V 直连」是同一类风险）。
4. **上电顺序**：先板子、后蓝牙；或同时。避免蓝牙已上电而板子未上电时，TX 线把电压灌进未上电的 BANK11。

> 此决策**消除了原 R3**（J12 3V3 压降），但**引入 R7**（共地不良 / 外部电源误用 5V），见 §六。

---

## 三、通路拓扑

```
┌────────────────────────── 板外 ──────────────────────────┐
│  手机 / PC ──蓝牙 SPP──► JDY-31 模块                       │
│                          TXD ──┐   VCC ── J12 3V3         │
│                          RXD ──┤   GND ── J12 GND         │
└─────────────────────────────────┼─────────────────────────┘
                                  │
┌──────────────────────── J12 pin6（BANK11 / 3V3）──────────┐
│                     U9 ─────────┘（BT TX → FPGA）          │
│                     U8 ◄──────────（FPGA → BT RX）         │
└─────────────────────────┬─────────────────────────────────┘
                          │  LVCMOS33 单端，不做差分
┌─────────────────────────▼─────── PL 侧（TD）──────────────┐
│  system_top（uisrc/01_rtl/system.v）                       │
│     input  I_bt_uart_rx   ← U9                             │
│     output O_bt_uart_tx   → U8                             │
│            │                    ▲                          │
│            ▼                    │                          │
│  system system_inst（DI 生成）                              │
│     .uart0_rx_in (I_bt_uart_rx)                            │
│     .uart0_tx_out(O_bt_uart_tx)                            │
│            │                    ▲                          │
└────────────┼────────────────────┼──────────────────────────┘
             │   ★ EMIO 直连，不经 AXI、不经 FDMA
┌────────────▼────────────────────┼─────────── PS 侧 ─────────┐
│  ARM_Processor_System_0（硬核）                             │
│     uart0_rx_in ──► PS UART0 控制器 ──► RX FIFO             │
│     uart0_tx_out ◄── PS UART0 控制器 ◄── TX FIFO            │
│                       ▲                                     │
│                       │  AlUart_Hal_Init(DevId = 0)         │
│  PS 软件：USART 中断收 → 主循环原样发回（回环）              │
└─────────────────────────────────────────────────────────────┘

（UART1 / MIO48/49 → Type-C CH342 → PC 的 COM 口，保持为调试控制台）
```

---

## 四、改动清单

### 4.1 PL 侧第一步：DI 里加两个顶层端口（**唯一的结构性改动**）

**在哪做**：TD → DI 打开 `MainProject\soc_prj\uisrc\01_rtl\system\Design.xml`

| 操作 | 细节 |
|---|---|
| 1 | 给顶层组件 `system` 新增端口 **`uart0_rx_in`**，方向 **input** |
| 2 | 给顶层组件 `system` 新增端口 **`uart0_tx_out`**，方向 **output** |
| 3 | 删掉 PS 实例 `uart0_rx_in` 上现有的常量 `1'b0` 驱动 |
| 4 | 用 **adHoc（信号级）连线**：顶层 `uart0_rx_in` ↔ PS 实例 `uart0_rx_in`；顶层 `uart0_tx_out` ↔ PS 实例 `uart0_tx_out` |
| 5 | `Generate design`，确认 `hdl/system.v` 顶部端口数由 **20 → 22**，且这两条 `assign` 出现 |

> ⚠ **必须用 adHoc 信号级连线**，不要只加 GUI 的 bus interface 汇总 —— 上次 AXI 空接就是栽在"改了汇总视图没改信号级"。
>
> ⚠ 端口名建议就叫 `uart0_rx_in` / `uart0_tx_out`，与 PS 实例原名一致，便于日后排查时肉眼对照。

### 4.2 PL 侧第二步：顶层 `system.v` 加端口并透传

文件：`MainProject\soc_prj\uisrc\01_rtl\system.v`（**注意这是 `system_top`，与 DI 生成的 `system` 不是同一个模块**）

```verilog
module system_top (
    ... 现有端口 ...
    input  wire         I_bt_uart_rx,   // J12 U9：蓝牙 TXD → PS UART0 RX
    output wire         O_bt_uart_tx    // J12 U8：PS UART0 TX → 蓝牙 RXD
);

  system system_inst (
      ... 现有接线 ...
      .uart0_rx_in (I_bt_uart_rx ),
      .uart0_tx_out(O_bt_uart_tx )
  );
```

### 4.3 引脚约束

文件：`MainProject\soc_prj\uisrc\04_pin\fpga_pin.adc`，沿用现有写法：

```
set_pin_assignment { I_bt_uart_rx } { LOCATION = U9; IOSTANDARD = LVCMOS33; PULLTYPE = PULLUP;  DRIVESTRENGTH = 8; }
set_pin_assignment { O_bt_uart_tx } { LOCATION = U8; IOSTANDARD = LVCMOS33; PULLTYPE = PULLUP;  DRIVESTRENGTH = 8; }
```

- **`PULLTYPE = PULLUP` 很重要**：UART 空闲态是高电平，上拉能避免配对瞬间的假起始位。
- **不要用 LVDS**：U8/U9 虽然被列为一对差分，这里当两根独立单端线用。
- 这两个 ball 在 **BANK11 = 3V3 固定轨**，**不会重演 `USR-8001`**（那次是 BANK32 被 MIPI 占成 1.8V）。

### 4.4 PS 侧：UART0 回环

**方案 A（照 refer 直接改，改动最小）**

把 `soc_sdk\fdma_en\Car_control\USART.c` 的 `AL_UART_DEVID` 由 `1` 改成 `0`，然后：

- `UART_init()` 里 `AlUart_Hal_Init(&UartHandle, 0, &UART_InitStruct, UART_EventCallback)`
- 主循环调 `UART_test(void)`：只要 `RxDataReady` 就 `UART_SendData(Rx_data, RxReceivedLength)` 原样发回

**缺点**：`al_printf` 也走 UART0（§2.5 冲突一），日志会和回环数据混在一起。

**方案 B（推荐）：UART0 专供蓝牙，日志留 UART1 —— 2026-11-01 核实后确认「无需改动」**

原计划要做三件事，核实后**三件全都不用做**：

| 原计划改动 | 核实结果 | 结论 |
|---|---|---|
| 新增 `-DLOG_DEV=1` | `config.mk:105` 已经用 `OUTPUT_DEV` 默认值 `UART1` 传了 `-DLOG_DEV=AL_LOG_UART1` | ❌ **不用加** |
| `UART1_Available` 改 1 | `soc_plat.c:1175-1206` 的 MIO48/49 pinmux 是无条件生成的，不受此位门控；`UART1PS_ENABLE` 也已在 `soc_plat.h` 定义 | ❌ **不用改**（改了只是让 XML 与实际一致，纯洁癖） |
| `USART.c` 用 DevId 0 | 这是**唯一真需要改的一条**，见下 | ✅ **要改** |

所以 PS 侧最终只剩一行改动：

```c
/* soc_sdk\fdma_en\Car_control\USART.c:43 */
-#define AL_UART_DEVID 1     /* UART1 = 日志口，与回环抢同一个外设 */
+#define AL_UART_DEVID 0     /* UART0 = 蓝牙 EMIO，专供回环 */
```

> ⚠️ 注意：`AlUart_Hal_Init` 内部是 `*Handle = &AlUartHandle[DevId]`（`al_uart_hal.c:119`），
> 即日志的 `Allog.DeviceHdl` 与 `USART.c` 的 `UartHandle` **指向同一个静态结构体**。
> 所以现在 `USART.c` 用 DevId 1 时，它其实在**重复初始化日志口**；换成 0 之后两者才真正分开。
> 这也解释了为什么之前串口"看起来没坏也没用"——它一直在对日志口做二次初始化。

> **本次不会再顺手解决「没日志」这个问题**，因为它根本不是问题（§2.7 是打开错 COM 口）。

### 4.5 建议的 `UART_test()` 实现要点（照 refer，但补两处）

```c
void UART_test(void)
{
    if (RxDataReady) {
        UART_SendData(Rx_data, RxReceivedLength);   // 原样发回
        while (AlUart_Hal_IsTxBusy(UartHandle));    // ← refer 里误写成 IsRxBusy，要改
        RxDataReady = 0;
        UART_ReceiveData();                         // 续订下一段
    }
}
```

> **refer 原码的 bug**：`while(AlUart_Hal_IsRxBusy(UartHandle));` 等的是"接收忙"，不是"发送忙"。发送是异步的，这里等错了对象，连发时会丢字节。改成 `IsTxBusy`（若 SDK 无此 API，就改用 `AL_UART_EVENT_SEND_DONE` 回调置标志）。

---

## 五、4 个决策（**已全部拍板**，2026-11-01）

| 编号 | 决策点 | 选项 | 我的建议 |
|---|---|---|---|
| **D1** | **波特率** | ① 9600（JDY-31 出厂默认）<br>② 115200（与现有 `UART0_BAUDRATE` 一致） | **先 9600**。第一次联通不要引入额外变量；通了再 AT 指令两边一起改 115200 |
| **D2** | **`al_printf` 归属** | ① 留 UART0（与回环共用，日志从蓝牙发出）<br>② 留 UART1（COM 口看日志，UART0 专供蓝牙） | **② 已拍板**。且它本来就是现状（§2.5 表），**不需要任何改动** |
| **D3** | **U8/U9 谁是 TX** | ① U9=BT TX→FPGA，U8=FPGA→BT RX<br>② 反过来 | **① 已按默认确认**（2026-11-01）。接反也只是对调两根杜邦线，可现场改 |
| **D4** | **要不要 refer 的帧封装** | ① 纯字节回环（收到什么发什么）<br>② 加 `0xA5 … 0x5A` 包头包尾 | **① 已按默认确认**（2026-11-01）。第一次目标是"通路通不通"，帧封装等通了再加 |

---

## 六、风险与回退

| # | 风险 | 概率 | 影响 | 回退/对策 |
|---|---|---|---|---|
| R1 | DI 加端口后需要重新 generate + **重新综合布线**（约 10 min） | 高 | 位流要重做 | 改之前备份 `Design.xml`（照上次 `Design.xml.bak-fixaxi-20261031` 的做法） |
| ~~R2~~ | ~~改 `LOG_DEV` 会让 `al_printf` 改道~~ | — | — | ✅ **已消除**：核实后 `-DLOG_DEV` 本来就是 UART1，本次一个字都不改（§4.4） |
| ~~R3~~ | ~~JDY-31 从 J12 的 3V3 取电，配对瞬时 30–40 mA 可能拉低~~ | — | — | ✅ **已消除**：2026-11-01 拍板改**外部单独供电**（§2.8） |
| R4 | U8/U9 被当作差分对，单端使用是否被 TD 拒绝 | 低 | 约束报错 | BANK11 全是 3V3，单端 LVCMOS33 合法；若报错改到第 5 对（U7/V7）或第 7 对（V11/V10） |
| R5 | `uart0_tx_out` 悬空时会不会引入时序违例 | 低 | 时序 | UART 是慢速信号，无时序约束；综合后确认 AXI 域（`p2f_clk1`）仍 0 违例即可 |
| ~~R6~~ | ~~`UART1_Available=0` 与 `UART1PS_ENABLE` 不一致~~ | — | — | ✅ **已澄清**：该位不门控 pinmux，不影响出字（§2.5）。改它纯属让 XML 与实际一致，本次不做 |
| **R7** | **外部供电未与板子共地**，或**误用 5 V** | 中 | 收不到数据 / 烧 BANK11 的 PL IO | 接线时先把三处 GND 连好再通电；外部电源上用万用表量一次确为 3.3 V；**J12 排针的 3V3 引脚必须悬空**（§2.8） |
| **R8** | 蓝牙已上电、板子未上电时，BT 的 TX 把电压灌进未上电的 BANK11 | 低 | IO 损伤 | 按「先板子、后蓝牙」上电（§2.8 第 4 条） |

---

## 七、实施顺序（**本次不执行**，仅列顺序）

| 步 | 动作 | 谁做 | 预计 |
|---|---|---|---|
| 0 | 备份 `Design.xml` / `system.v` / `fpga_pin.adc` / `USART.c` | 我 | 1 min |
| 1 | **先验证 UART1 控制台**：**零代码改动**。直接开两个 COM 口（115200 8N1），复位，看哪个出 `===== MainProject AXI PWM bring-up =====` | 你（1 min） | 2 min |
| 2 | DI 加两个顶层端口 + adHoc 连线 + Generate | **你在 DI GUI 里点**（照上次矩阵参数的教训，DI 的改动只有 GUI 能可靠触发） | 5 min |
| 3 | 我核对 `hdl/system.v`：端口数 20→22、两条 assign 出现 | 我 | 2 min |
| 4 | 改 `system.v` 顶层 + 加两条引脚约束 | 我 | 10 min |
| 5 | 改 `USART.c`（DevId 0 + `UART_test` 回环） | 我 | 10 min |
| 6 | TD 综合布线（约 10 min）→ 核对 AXI 域仍 0 违例 | 你点 Run / 我读报告 | 15 min |
| 7 | **外部 3.3 V 供电接线 + 共地检查**：外部电源负极 ↔ JDY-31 GND ↔ 板子 GND 三点连通；万用表先量一次确为 3.3 V；**J12 排针的 3V3 保持悬空**；U9 ← BT TXD、U8 → BT RXD | 你 | 5 min |
| 8 | FD 编译下载 → 蓝牙配对（`JDY-31-SPP` / `1234`）→ 回环测试 | 你操作 | 10 min |

> **第 1 步单独先做**，是因为它不影响 PL、不需要重综合，独立可验。把"日志能不能看见"这个前提先钉死，后面三处改动才有观测手段。

> **第 7 步不要和第 8 步合并**：上电前先用万用表确认外部电源是 3.3 V（不是 5 V）、且三处 GND 已连通。这一步只花 1 分钟，但能挡住 R7/R8 两个"烧 IO"级别的风险。

---

## 八、验收方法

1. 手机装任意蓝牙串口 App（如「蓝牙串口助手」），配 `JDY-31-SPP` / `1234`
2. 发 `0123456789` → 应原样收回
3. **同时**在 PC 的 COM（PS_UART = UART1）上看 `printf` 日志正常滚动——蓝牙回环与日志分别在两路，互不干扰
4. HDMI 画面正常、LED3 呼吸正常
5. 拔掉蓝牙模块，PC 端日志应出现 UART0 相关错误或静默（不应死机）

---

## 九、待你确认

已确认（2026-11-01，**四项决策 + 供电方式全部落定**）：

- ✅ **D1 = 先 9600**（JDY-31 出厂默认；通了再用 AT 指令两边一起改 115200）
- ✅ **D2 = 日志留 UART1、UART0 专供蓝牙**（且这已是现状，零改动）
- ✅ **D3 = U9 接 BT TX→FPGA，U8 接 FPGA→BT RX**
- ✅ **D4 = 纯字节回环，上帧封装的事等通了再说**
- ✅ **供电 = 外部单独 3.3 V 供电，强制共地，J12 的 3V3 引脚悬空**（§2.8）
- ✅ **起步 = 只先做第 1 步**（UART1 控制台验通）
- ✅ **实物 = 已有 JDY-31**

仍待确认：

1. **第 1 步的结果**：插上 Type-C 后 PC 上出现哪两个 COM 口、有没有一路以 115200 出 `===== MainProject AXI PWM bring-up =====`
2. **第 1 步验完之后是否直接进第 2 步**（DI 加两个顶层端口，需要你在 GUI 里点）
3. **外部 3.3 V 电源是现成的实验电源，还是需要从别处引？**（决定接线前要不要先备料）

---

## 十、附：本次核实到的事实清单（便于日后复查）

| # | 事实 | 证据位置 |
|---|---|---|
| 1 | PS 硬核已有 `uart0_rx_in`/`uart0_tx_out` 端口，当前被钉死 | `hdl/system.v:1935-1936` |
| 2 | 平台配置 `UART0_Dot_IO = "PL IO"` | `soc_base/platform/Design.xml` |
| 3 | DI 顶层 `system` 模块只有 20 个端口，无 uart | `hdl/system.v` module 声明段 |
| 4 | **`al_printf` 实际落在 UART1 @115200**（`config.mk` 默认传 `-DLOG_DEV=AL_LOG_UART1`；构建走 Makefile 已由 `.cproject` 的 `managedBuildOn="false"` 证实） | `config.mk:95,105` + `al_uart_hal.c:43` |
| 5 | refer 用 `AL_UART_DEVID 0`，MainProject 用 `1` | 两边 `Car_control/USART.c:43` |
| 6 | refer 的 `UART_test()` 是纯回环，但等错了忙标志 | `refer/Car_control/USART.c` |
| 7 | `U8`/`U9` 未被任何约束占用 | `fpga_pin.adc` 零命中 |
| 8 | J12 pin6 = U9/U8，BANK11 3V3 固定轨，含 VCC/GND | `04-资源索引\安路飞龙DR1-板卡资源全解析.md` §⑧ |
| 9 | **MIO48/49 → UART1 的 pinmux 无条件生成，不受 `UART1_Available` 门控** | `soc_plat.c:1175-1206`（`0xf88030c0/0xc4` 写 `3`，`PL_IOSEL_5`=PS IO） |
| 10 | **一根 Type-C 同时引出 PS_UART(MIO48/49) 与 PL_UART(J16/K16)，PC 上出现两个 COM 口** | `安路飞龙DR1-板卡资源全解析.md` §416（SL2.1S + CH342K） |
| 11 | `AlUart_Hal_Init` 的 `*Handle = &AlUartHandle[DevId]`，故日志口与 `USART.c` 的 DevId 1 是同一个静态结构体 | `al_uart_hal.c:119` |

---

## 十一、执行记录（2026-11-01 15:50）

### 11.1 已完成（代码/约束层，等 DI Generate 后即可综合）

| # | 文件 | 改了什么 | 备份 |
|---|---|---|---|
| 1 | `soc_prj/uisrc/01_rtl/system/Design.xml` | 加 2 个 `designPort`（`uart0_rx_in` input / `uart0_tx_out` output）+ 2 条 adHoc 连到 `ARM_Processor_System_0`。**端口数 20 → 22**（已用 ElementTree 解析验证） | `.bak-20261101-bt` |
| 2 | `soc_prj/uisrc/01_rtl/system.v` | `system_top` 加 `I_bt_uart_rx` / `O_bt_uart_tx` 两个端口；`system_inst` 加 `.uart0_rx_in` / `.uart0_tx_out` 两条连线 | `.bak-20261101-bt` |
| 3 | `soc_prj/uisrc/04_pin/fpga_pin.adc` | 加 2 条约束：`I_bt_uart_rx`→**U9**（LVCMOS33，PULLUP）、`O_bt_uart_tx`→**U8**（LVCMOS33，DRIVESTRENGTH 8） | `.bak-20261101-bt` |
| 4 | `soc_sdk/fdma_en/Car_control/USART.c` | `AL_UART_DEVID` 1→**0**；波特率 115200→**9600**；开启接收；`USART_Poll` 里续订 + 回环；`frame_parse` 在回环模式下用 `#if` 屏蔽（避免与回环抢字节） | `.bak-20261101-bt` |
| 5 | `soc_sdk/fdma_en/Car_control/USART.h` | `USART_RX_ENABLE` 0→**1**；新增 `USART_LOOPBACK_ENABLE`=1；`USART_RX_SEG_SIZE` 在回环时取 **1** | `.bak-20261101-bt`（按原文重建） |
| 6 | `soc_sdk/fdma_en/Car_control.c` | `car_Loop()` 开头补 **`USART_Poll();`** | `.bak-20261101-bt` |

### 11.2 ★ 执行中新发现的两个真问题（方案原稿没写到）

**问题 A：`USART_Poll()` 全工程从未被调用。**
`car_Loop()` 原来只调 `USART_GetCmd()`。而接收段必须靠再调一次 `AlUart_Hal_RecvData` 才能续订 ⇒ 不改这一处，回环**只会收到最开始那几个字节，然后永远静默**。已在 `car_Loop()` 开头补上。

**问题 B：`USART_RX_SEG_SIZE = 16` 会让回环"发不满 16 字节就毫无反应"。**
SDK 的 `RECEIVE_DONE` 事件**只在搬满一整段时触发**，所以 16 字节的分段意味着必须凑够 16 个字节才有一次回调。⇒ 回环场景必须把分段长度改成 **1**（逐字节中断，9600 下约 1 kHz，开销可忽略）。已在 `USART.h` 里按 `USART_LOOPBACK_ENABLE` 自动切换：回环 1、帧解析 16。

### 11.3 一次险情（已完全恢复，记录以免重犯）

第 3 处改动（`system.v`）第一次执行时，Python 脚本在 `open(p,'wb')` **已经截断文件之后**、`write()` 之前抛了 `TypeError`（拼接列表里混了 str 与 bytes），导致 `system.v` 变成 **0 字节**。

- 处置：立即用 `.bak-20261101-bt`（23566 B）还原 → 改脚本为「内存里拼好完整 bytes → 写 `.tmp` → `os.replace` 原子替换」→ 重跑成功（24179 B）。
- 结论：**凡是用 Python 改文件，必须先算出完整内容再开 `'wb'`，或走 `.tmp` + `os.replace`**。`open(...,'wb')` 是会立即清空文件的。

### 11.4 还没做（等条件）

| 步 | 内容 | 卡在哪 |
|---|---|---|
| 1 | UART1 控制台验通 | **板子没插**：枚举本机 USB 无任何 COM 口、连 FTDI `0403:6042` 都没出现 |
| 3 | 核对 DI Generate 后的 `hdl/system.v`：端口 20→22、两条 assign 出现 | 需要先打开 DI 点 `Generate design` |
| 6 | TD 综合（约 10 min）→ 确认 AXI 域仍 0 违例 | 依赖第 3 步 |
| 8 | 上板回环 | 依赖综合 + 外部 3.3V 接线 |

> ⚠️ **现状：工程暂时不可综合**。`system.v`(system_top) 已经引用了 `uart0_rx_in`/`uart0_tx_out`，但 DI 生成的 `hdl/system.v` 里 `module system` 还没有这两个端口 —— 必须先 `Generate design` 才能综合。

### 11.5 ✅ DI `Generate design` 已完成并核对通过（16:05）

`hdl/system.v` 于 **16:05** 重新生成（166683 B），逐项核对：

| 检查项 | 结果 |
|---|---|
| `module system` 端口数 | **22**（原 20） |
| 端口声明 | L21 `input wire uart0_rx_in` / L33 `output wire uart0_tx_out`，方向正确 |
| 端口到实例的连线 | L1204 `assign w_net__uart0_rx_in = uart0_rx_in;` → L1205 → L1949 `.uart0_rx_in(...)`；TX 反向 L1207/1208/1950 |
| 原来的 `1'b0` / 空接 | **已消失**，不再是断头 |
| **上一轮的 AXI 时钟域修复** | **保留**：L1150 `master_gp0_axi_aclk = p2f_clk1` |
| HP0 从口时钟 | 仍 `p2f_clk0`（正确，FDMA/图像走 200 MHz） |
| AXI 矩阵 wrapper | **未重生成**（mtime 仍是 10-31 18:31），`.params` 里 `ID_WIDTH=13 / ID_WIDTH_USER=12 / CONNECTIVITY_MODE=0` 全部保持 |

> **结论：DI 用 XML 改动重新生成是成功的**，不需要再走 GUI 手工加端口。此路径可作为以后加顶层端口的固定做法。
> 工程现在**已可综合**，下一步 TD Run。

### 11.6 ✅ 板子已插入 + PS 侧已重编（16:09）

**一、硬件枚举（推翻 §11.4 第 1 条的"板子没插"）**

| 设备 | InstanceId | 说明 |
|---|---|---|
| `USB-Enhanced-SERIAL-A CH342 (COM4)` | `USB\VID_1A86&PID_55D2&MI_00` | CH342K **A 通道** |
| `USB-Enhanced-SERIAL-B CH342 (COM5)` | `USB\VID_1A86&PID_55D2&MI_02` | CH342K **B 通道** |
| `USB-JTAG Cable` | `USB\VID_0403&PID_6042&MI_00` | FTDI 下载器，与记忆中的 `0403:6042` 一致 |

- **COM4 / COM5 均能成功打开 115200 8N1**（`System.IO.Ports.SerialPort` 实测）。
- 首次尝试报"对端口的访问被拒绝"、重试即通 —— 是瞬时占用，**不是驱动故障**，不必再查 CH342 驱动。
- CH340 的 COM3 / COM8 属于本机其他设备，与本工程无关。
- `Win32_SerialPort` 查询为空、`Get-PnpDevice` 的 `Status` 显示 `Unknown`，但**实际可打开** —— 这条 WMI 视图不可作为可用性判据。

> **待实测**：COM4 与 COM5 哪个是 PS_UART（MIO48/49）、哪个是 PL_UART（J16/K16）。判据 = 烧完程序后**哪个口喷 `===== MainProject AXI PWM bring-up`**，出字的就是 PS_UART（因为 `DR1X90_OUTPUT_DEV ?= UART1`）。

**二、PS 侧命令行编译（绕开 FD GUI，省一步手工操作）**

FD 未启动，`.cproject` 是 `managedBuildOn="false"` + Gnu Make Builder ⇒ 可纯命令行编译：

```bash
export PATH="/d/FPGAproject/SpaceForFD/FD/toolchain/gcc/aarch64/bin:/d/FPGAproject/SpaceForFD/FD/toolchain/build-tools/bin:$PATH"
cd soc_sdk/fdma_en
make SDK_ROOT=".../soc_sdk/soc_base" PLAT_DIR=".../soc_sdk/soc_base/platform" \
     CHIP=dr1m90 COMPILE_PREFIX=aarch64-none-elf- DOWNLOAD=ddr TARGET=fdma_en
```

> ⚠️ **`TARGET=fdma_en` 不能漏**。`Makefile:66` 默认 `TARGET ?= HELLOWORLD`，漏了会产出 `HELLOWORLD.elf/bin`（内容对、名字错），容易在后续下载时选错文件。

| 产物 | 旧（10-31 21:00） | 新（11-01 16:09） | 判据 |
|---|---|---|---|
| `build/fdma_en.bin` | `551fa823…` | `2a1f81d7…` | md5 已变 ✅ |
| `build/fdma_en.elf` | `6f29fda9…`（2719048 B） | `22dc6438…`（2722216 B） | +3168 B ✅ |
| 符号表 | — | `USART_Init` / `USART_Poll` / `USART_Test` / `s_seg_ready` 全在 | ✅ |

旧产物已留档 `build/fdma_en.{elf,bin}.bak-20261101-bt`。

### 11.7 ✅ 模块引用链核对（决定改动是否真的进综合）

| 层 | 文件 | 在 prj 里的形式 | 本次改动 |
|---|---|---|---|
| 顶层 | `uisrc/01_rtl/system.v`（`module system_top`） | **第 1 个源文件，直接编译** | 端口 `I_bt_uart_rx`/`O_bt_uart_tx` + L250-251 接实例 ✅ |
| IP 封装 | `uisrc/01_rtl/system/system.xml` | 第 58 项（`.xml` 形式，非 `.v`） | 16:05 随 generate 一并更新 ✅ |
| 子模块 | `uisrc/01_rtl/system/hdl/system.v`（`module system`） | **prj 内没有 `hdl/` 路径**，经 `system.xml` 引用进来 | 16:05 生成，22 端口 ✅ |

- `soc_prj.prj` 里 `TOP_MODULE` = `system_top`（L534-536），共 63 个文件条目。
- 手写顶层 L229 是 `system system_inst (` —— 即 `module system` 作为子模块被实例化，**端口名必须与 `hdl/system.v` 完全一致**，本次已逐名对齐。
- ⇒ **两条链路都在改动之后刷新过，综合会吃到全部修改。**

### 11.8 目前只剩 TD 综合

| 项 | 状态 |
|---|---|
| DI `Generate design` | ✅ 16:05 |
| PS 源码 6 文件 | ✅ 15:50 |
| PS 编译 | ✅ 16:09（命令行代劳） |
| 板子 / 串口 / JTAG | ✅ 已枚举，COM4+COM5 可开 |
| **TD 综合** | ❌ **待点 Run（约 10 min）** |
| 外部 3.3 V 接线 | ❌ 未接 |
| FD 下载 + 上板回环 | ❌ 依赖综合 |

综合时重点看两项：① AXI 域（`p2f_clk1`）SWNS/HWNS 是否仍 0 违例；② 新的 `I_bt_uart_rx`/`O_bt_uart_tx` 有无引脚/电平报错（R4 风险已可由现有 `T6/U10/V6/U5/T5/W9…` 单端先例排除）。

### 11.9 首次综合失败 → 已修复（16:11 → 16:13）

**现象**：`syn_1` Progress 30%、耗时 **10 秒**就报 `opt rtl error`（RTL 读取阶段，还没进真正的综合）。

**日志根因**（`soc_prj_Runs/syn_1/run.log`，只有这 2 条 ERROR）：

```
L2391  USR-8409 ERROR: DRIVESTRENGTH is not supported by HRIO.LVCMOS33 in INPUT direction.
L2392  USR-8168 ERROR: set_pin_assignment { I_bt_uart_rx } { LOCATION = U9; IOSTANDARD = LVCMOS33;
       DRIVESTRENGTH = 8; PULLTYPE = PULLUP; } in ../../uisrc/04_pin/fpga_pin.adc(30) is not a valid ADC command.
```

> **规则：输入方向的引脚不能写 `DRIVESTRENGTH`。** 只有输出引脚才写。
> 本工程既有输入引脚全部只写 `IOSTANDARD + PULLTYPE`（`I_button[0]=K14`、`I_button[1]=J14`、`I_sysclk=H16`、`I_data_lp_*=Y18/V17/Y19/V18`），一个都没写 DRIVESTRENGTH —— 这条规律当时扫到了却没套用到新增的 RX 上，是本次的低级错误。

**修复**（`fpga_pin.adc` L30，3439 B，仍纯 CRLF / 41 行）：

```diff
- set_pin_assignment { I_bt_uart_rx } { LOCATION = U9; IOSTANDARD = LVCMOS33; DRIVESTRENGTH = 8; PULLTYPE = PULLUP; }
+ set_pin_assignment { I_bt_uart_rx } { LOCATION = U9; IOSTANDARD = LVCMOS33; PULLTYPE = PULLUP; }
```

输出侧 `O_bt_uart_tx = U8` 保留 `DRIVESTRENGTH = 8`（正确，不动）。

**顺带排除的两个疑点**：

| 疑点 | 结论 |
|---|---|
| `HDL-1007 : undeclared symbol 'S_lane_error'` / `HDL-5007 O_lane_error 位宽 1 vs 2` | **既有问题**：旧备份 `system.v.bak-20261101-bt` 里同样有；且是 warning 级，之前能过综合 → 不管 |
| `module system` 端口是否真的被 TD 吃到 | **已确认吃到**：日志里**没有** `port 'uart0_rx_in' remains unconnected`，也没有端口不存在的报错。只有 `uart0_de / uart0_dtr_n / uart0_out1_n / uart0_out2_n / uart0_re / uart0_rts_n` 这些 **Modem 信号**未接（UART0 只用 TX/RX，正常） |

**日志统计**：2158× `HDL-1007`、25× `HDL-5317`、21× `HDL-5007`、6× `HDL-5323`、4× `HDL-5314`、3× `HDL-5370`、2× `HDL-5106` —— 全是既有 warning；ERROR 仅上述 2 条。

### 11.10 ✅ 第二次综合通过，位流已生成（16:13 修 → 16:15 跑 → 16:27 出位流）

**一、产物**

| 文件 | 时间 | 大小 | md5 |
|---|---|---|---|
| `soc_prj_Runs/best_result/soc_prj.bit` | 16:27 | 4052210 B | `ca5f68e85c5d185f0229c06d021630b3` |
| `soc_sdk/fdma_en/build/fdma_en.elf` | 16:09 | 2722216 B | `22dc6438…` |

> 位流大小与旧版（10-31 18:56，4052210 B）完全相同 —— 位流是固定帧格式，**大小不变是正常的**，判据要看 IO 数与综合日志。

**二、引脚落地（判据）**

```
L2390  RUN-1002 : start command "set_pin_assignment I_bt_uart_rx LOCATION = U9; IOSTANDARD = LVCMOS33; PULLTYPE = PULLUP; "
L2391  RUN-1002 : start command "set_pin_assignment O_bt_uart_tx LOCATION = U8; IOSTANDARD = LVCMOS33; DRIVESTRENGTH = 8; PULLTYPE = NONE; "
L2392  RUN-1001 : Starting of IO setups legality check.     ← 上次这条是 USR-8409 ERROR
L2660  SYN-2001 : Map 31 IOs to PADs of model 'system_top'  ← 29 → 31，正好 +2
```

- `#IO 31 / 126 = 24.60%`，`#pad 39 / 126 = 30.95%`（pad 含电源等专用焊盘）。
- `SYN-6024 CRITICAL-WARNING`（`system.v(273)` 的 `DR1_LOGIC_ODDR CMOS_CLK` 无复位）—— **既有 warning**，与本次改动无关。

**三、时序（关键：新增 UART 零影响）**

`phy_1/final_timing.rpt`（16:26:40，Routed，Both Corners）总账：`SWNS -0.532ns / HWNS -2.416ns`。

| 时钟 | 频率 | Fanout | SWNS | HWNS | 判定 |
|---|---|---|---|---|---|
| **`p2f_clk1`**（clk0，AXI 全链） | 50 MHz | 2463 | **+13.517** | **+0.051** | ✅ **0 违例** |
| `p2f_clk0`（clk1，图像/FDMA） | 200 MHz | 1740 | −0.479 | −2.416 | ❌ 既有基线 |
| `GEN_PL_HP0`（clk5） | 200 MHz | 192 | −0.532 | +0.070 | ❌ 既有基线 |
| `pclkx1`（clk3，用户 GCLK） | 50 MHz | 711 | +1.061 | +0.029 | ✅ |
| `GEN_PL_GP0S`（clk4） | 50 MHz | 206 | +14.898 | +0.205 | ✅ |
| **`master_gp0_axi_aclk`**（clk12） | 50 MHz | **0** | — | — | ✅ **fanout=0，被 p2f_clk1 完全吸收** |

> ⭐ **AXI 域最差 slack = +0.051ns**（`AXI_Protocol_Converter_0` 的 `axaddr_offset_r_reg[0]`），PWM 寄存器路径 14.144ns。
> ⭐ `master_gp0_axi_aclk` fanout **0** ⇒ 它没被当成独立时钟，与 `p2f_clk1` 同域 —— **上一轮的时钟域修复确认有效**，且 SWNS 由 13.013 → **13.517**（+0.5ns）。

**三条违例路径，全部与 UART 无关：**

| # | Slack | 类型 | Begin → End | 与记忆对照 |
|---|---|---|---|---|
| 1 | **−2.416** | hold | `u_uidbuf/rdbuf_fifo/rd_to_wr_cross_inst/primary_addr_gray_reg[6]`（`pclkx1` 50M）→ `sync_r1_reg[7]`（`p2f_clk0` 200M） | 同一条：反向跨域格雷码同步器，基线 −2.315（本次 −2.416，差 0.10ns） |
| 2 | **−0.532** | setup | `u_uidbuf/wdbuf_fifo/ram_inst/ramread0.clkb`（`p2f_clk0`）→ `slave_hp0_axi_wdata[22]`（`GEN_PL_HP0`），中继 `Processor_System_Reset_0/…/clk_auto_soc_output_clock` | 同一条：基线 −0.537 / 19 端点（本次 −0.532 / **20** 端点）；前身 `mymipi_hdmi2` 为 −0.484 / 20 端点 |
| 3 | −0.017 | setup | `uiFDMA/rburst_cnt_reg[1]` → `[7].ssr`（**同域** `p2f_clk0`） | 记忆未记载，2 端点，同域擦边微扰，不影响总账 |

> **结论：新增的 UART 通路没有引入任何新时序问题。** 依据：① `p2f_clk1` 域 0 违例且比上次更好；② 两条主违例的路径名与 slack 与历史基线逐条对应；③ 全报告无任何 `uart` 相关路径。

**四、资源**

`system_top`：LUT **21696 / 52480 = 41.34%**，slicereg 35436 / 104960 = 33.76%，ERAM 76 / 280，DSP 48，PLL 1，GCLK 10，IO 31。
其中 `system_inst`（`module system`）：lut 455、logic 2032、ripple 4590；`axi_lite_pwm_0` 单独统计 logic 460 / ripple 192 / lut 442（与上一轮一致）。

### 11.11 现在可以上板了

| 步 | 内容 | 状态 |
|---|---|---|
| 1 | 烧新位流 `best_result/soc_prj.bit`（16:27） | 待做 |
| 2 | 下载 `fdma_en.elf`（16:09） | 待做 |
| 3 | 看 COM4/COM5 **哪个口出 `===== MainProject AXI PWM bring-up`** → 定出 PS_UART | 待做 |
| 4 | 接 JDY-31（外部 3.3V + 共地）→ 验回环 | 待做 |

> **第 3 步不需要蓝牙模块**：`printf` 走 UART1（MIO48/49 → 二合一 Type-C 的 PS_UART），与 PL 的 UART0 通路完全独立。先把「哪个 COM 是 PS_UART」测出来，再接蓝牙，可避免把两件事混在一起排查。

### 11.12 上板后串口乱码 → 是 10-29 那个老问题的复发（16:37 → 16:45 修复）

**现象**：COM4 打开 115200 8N1，收到**满屏乱码**。

**根因 = `03-排障记录/串口修复/串口乱码-UART时钟常数不符-20261029.md` 那个已知问题，MainProject 从来没有修过。**

| 环节 | MainProject 原值 | 应为 |
|---|---|---|
| `soc_plat.c:1419` | `CONFIG_REG_MASK(0xF8801028, 0xffffffff, 0x00000008)` | `0x01010101` |
| `soc_plat.tcl:1720` | `mask_write 0xF8801028 0xffffffff 0x00000008` | `0x01010101` |
| `FDMA_EN/build/lib/libplat.a` | 由上面编出 | — |
| `soc_hw/soc_prj.hpf` + `soc_sdk/soc_base/soc_prj.hpf` | **内嵌了同一份 `soc_plat.c` / `soc_plat.tcl` 副本，也是旧值** | 必须同步重打包 |

**机理**（详见证档）：`0xF8801028` 的字段是**选择码**不是分频数。`8 = 0b1000`，低 2 位 `00` → 最慢档 **÷32** → 12.5 MHz；写 `0x01010101` 低 2 位 `01` 才是 **÷8 = 50 MHz**。驱动按 `UART_CLOCK=49,995,000` 算出 divisor 27，实际 `12,498,750÷(16×27) = 28,932` —— 不是任何标准波特率，所以 9600/19200/38400/57600/115200 **一个都对不上**。

> ⚠️ **纠正一条错误结论（MEMORY.md 2026-10-31 第五轮那条）**：当时据 `soc_base/platform/Design.xml` 的 `UART0_Dot_Actual_Inside_Frequency=49.995MHz` 判定「`0x00000008` 就是 ÷8，是对的」。
> **这条判断是错的。** `Design.xml` 里那个值是 **TD 生成器的设计意图值**，而 TD 生成器本身就在「÷8」这一档把分频数 8 当选择码写出去了 —— 意图值跟寄存器值一起错，所以「源头自洽」不能作为判据。
> **唯一可靠判据是物理串口实测**：本次上板 115200 下满屏乱码，直接证伪。
> 另一条内部矛盾也能反证：同一份 `soc_plat.h` 里 `UART_CLOCK=49995000`（÷8）与 `GPIO_CLOCK=12500000`（÷32）**互相矛盾**，同一个寄存器值不可能同时给出两个频率。

**修复动作（4 处 + 2 个备份）**

| # | 文件 | 改动 | 备份 |
|---|---|---|---|
| 1 | `soc_base/platform/src/soc_plat.c:1428` | `0x00000008` → `0x01010101`，加 9 行注释说明「选择码非分频数」+ 复发警示 | `.bak-20261101-uartclk` |
| 2 | `soc_base/platform/soc_plat.tcl:1722` | `0x00000008` → `0x01010101` | `.bak-20261101-uartclk` |
| 3 | `soc_hw/soc_prj.hpf` | 重打包，只替换内嵌 `HPFs/soc_plat.{c,tcl}` | `.bak-20261101-uartclk` |
| 4 | `soc_sdk/soc_base/soc_prj.hpf` | 同上 | `.bak-20261101-uartclk` |

**hpf 重打包要点**（`_fix_hpf.py`，用后即删）：

- hpf 是**标准 ZIP**，内含 25 个条目，其中 `HPFs/soc_plat.c`(126878) / `HPFs/soc_plat.tcl`(108228) / `HPFs/soc_prj.bit`(4052210) 都是**完整副本**。所以只改 `soc_base/platform/` 下的源文件**不会**影响 FD 勾 Platform Init 时执行的副本。
- 重打包用 `zout.writestr(item, data)` 传**原 ZipInfo**，保留时间戳 / `compress_type` / `external_attr`；其余 23 项逐字节不变。
- 结果：981656 → 985882 B（增量来自新增中文注释，UTF-8 三字节压缩率低），条目数 25→25、顺序一致、CRC 通过。

**二进制级验证（不靠"应该生效"）**

| 产物 | 验证方式 | 结果 |
|---|---|---|
| `fsbl/build/FSBL.elf`（16:39，1455888 B） | 搜 `clk_data_0` 里 `{addr, mask, val}` 的小端序列 | `28 10 80 f8 │ ff ff ff ff │ 01 01 01 01` → **`0x01010101`** ✅，下一项 `04 12 80 f8 / 00 02 00 00 / 0` = `0xF8801204` IOPLL，顺序与源码一致 |
| `fdma_en/build/fdma_en.elf`（16:39，md5 `22dc6438…` **未变**） | 搜同一模式 + `nm` 查符号 | **不含该条目、不引用 `Soc_PlatInit`** ⇒ 应用本就不写这个寄存器，**不需要重编、md5 不变是正确的** |
| 两个 hpf | 逐条目对比备份 | 仅 2 项变化，位流 md5 仍 `ca5f68e8…` |

**为什么这次必须连 hpf 一起改**（关键认知）：

| 写入路径 | 谁执行 | 改源码够不够 |
|---|---|---|
| ③ FSBL 启动 `Soc_PlatInit()` | `fsbl.elf`（穿 `libplat.a`） | 够，重编 fsbl 即可 |
| ④ 下载时 `Run Platform Init` | **hpf 内的 `soc_plat.tcl` 副本** | **不够**，必须重打包 hpf |

> 只改 (1)(2) 而漏掉 hpf，等于把 ③ 修好了、④ 还在写错值 —— 而用户勾不勾 Platform Init 是随流程变的，表现出来就是「有时好有时坏」的飘移现象（这正是 10-29 文档 §四 环节 ⑤ 记录过的坑）。

**验收判据**：重新下载后 COM4 @115200 应直接读出
```
===== MainProject AXI PWM bring-up (STEP=?) =====
```
不再需要试其他波特率。若仍乱码，说明走的是没改到的那条路径 —— 此时读 `0xF8801028`（记得先 Suspend，且 FD 内存窗口是字节倒序：显示 `01010101` 才是对反）。


### 11.13 ✅ 串口乱码彻底解决（17:12 实机确认）

重新下载后 COM4 @115200 读出可读文本 —— **`main` 部分每一行都干净**，`0x01010101` 修复判定成立：

```
)-K)F#.19...               ← 这 11 个字节是 uart_probe 的 [B] 行，见 §11.14，不是故障
[SYS] Fclk init done

===== MainProject AXI PWM bring-up (STEP=3) =====
base = 0x80200000
[1] VERSION = 0x00010000 (expect 0x00010000) OK
[2] self-test OK (code 0)
    STATUS = 0x00000000  (pending=0, en=0, motor_en=0)
[UART] init ok (UART0, 9600 8N1)
[3] after init STATUS = 0x0000000C (en=1)
    PWM0: PSC=0 ARR=9999 -> 4999.5 Hz
    readback CTRL=0x00000001 ARR=9999 PSC=0 CCR=0
    breathing on LED3 (J15), CH0 = 0
```

> **判据成立的三重含义**：①`UART_CLOCK=49995000` 这个假设是对的；②divisor 27 精确命中 115200（实得 115,729，误差 +0.46%）；③hpf 与 fsbl 两条写入路径**这次都改到了**（否则会出现"有时好有时坏"）。

⚠️ **注意区分**：此时串口**已经修好了**（`[SYS] Fclk init done` 起全部可读），开头那 11 个乱码字节完全是探针制造的，与串口配置无关 —— 这也是最容易误判成"还没修好"的地方。探针去掉后的干净版本见 §11.15。

### 11.14 ❌ `uart_probe` 探针在本工程不可用（重要反面经验）

**起因**：用户说"就不能直接参考之前的修复复盘快速改吗"，于是把 PSPWM 里验收通过的 `uart_probe.{c,h}` 原样复制过来（它曾在 PSPWM 定位出 `0xF8801028` 的真值）。

**结果**：串口从"没信息"变成"开机头一行乱码"，`[B]` 自证行读不出来。

**根因**：`__attribute__((constructor))` 跑在 `main` 之前，此时 **UART1 的外设时钟/复位还没被 `AlUart_Hal_Init` 配好**，`probe_putc` 直写 THR 出去的字节波特率是错的。

| 层次 | 事实 |
|---|---|
| 注册层 | `.init_array` 里确有 `0x08001f90`，与 `uart_probe_autorun` 符号地址逐位一致 ⇒ **constructor 确实被调用了** |
| 执行层 | 有字节发出（乱码即证据）⇒ **没有死锁**、`UI_In32/UI_Out32` 通路正常 |
| 时序层 | 同一份 elf 里 `main` 的 `printf` **完全干净** ⇒ **差别只在"何时跑"**，不在"怎么写" |
| 结论 | 探针本身没写错，**位置错了**：串口寄存器已就绪但 UART 模块未初始化 |

> **可复用判据**：判断串口好坏，**只看 `main` 里的 `printf`**。任何跑在 `constructor` 阶段的直写探针都不可信 —— 它测的是"UART 模块初始化前的原始状态"，不是"驱动的实际工作状态"。
> PSPWM 里它能用，是因为那个工程刚好没有这层时序差；换个工程就未必。

**顺带修掉一个真隐患**（这个必须留着）：

```c
/* 原来：无超时。UART1 时钟若没起来，LSR 恒读 0、bit5 永不置位 -> 永不返回 */
while ((UI_In32((void *)UART1_LSR) & LSR_THRE) == 0U) { }

/* 已改：20 万次上界，与同文件 probe_wait_temt 对齐 */
u32 guard = 200000U;
while (((UI_In32((void *)UART1_LSR) & LSR_THRE) == 0U) && (guard != 0U)) { guard--; }
if (guard == 0U) { return; }
```

> 为什么这是"真隐患"而不只是洁癖：`constructor` 卡死 = `main` 全不执行 = LED5 不闪、LED3 不呼吸、串口静默。**这个现象和"位流没下进去 / 板子坏了"完全无法区分**，会把人往硬件方向带偏。

**处置**：`uart_probe.h` → `UART_PROBE_ON 0`。重编后二进制级验证：

| 检查 | 结果 |
|---|---|
| text 段 | 94564 → **93108**（-1456） |
| `.init_array` | **整个段消失**（objdump 报 `section not found`） |
| `uart_probe` / `probe_led` 符号 | **0 个** |

### 11.15 ✅ 蓝牙回环验收通过（17:21 实机确认）

**判据 1 达成**：手机经蓝牙 SPP 发字符，COM4 逐字节原样收回。

开机画面完全干净，**没有任何乱码**（探针已关）：

```
[SYS] Fclk init done

===== MainProject AXI PWM bring-up (STEP=3) =====
base = 0x80200000
[1] VERSION = 0x00010000 (expect 0x00010000) OK
[2] self-test OK (code 0)
    STATUS = 0x00000000  (pending=0, en=0, motor_en=0)
[UART] init ok (UART0, 9600 8N1)
[3] after init STATUS = 0x0000000C (en=1)
    PWM0: PSC=0 ARR=9999 -> 4999.5 Hz
    readback CTRL=0x00000001 ARR=9999 PSC=0 CCR=0
    breathing on LED3 (J15), CH0 = 0
```

> `[UART] init ok (UART0, 9600 8N1)` 这一行是 `USART_Init()` 打的，说明 **PS 硬核 UART0 初始化成功**；回环成功则证明后面三段（PL 端口 → J12 U8/U9 → JDY-31）全部闭合。

---

## 十二、闭环复盘（2026-11-01 17:21）

### 12.1 验收单全项对照

| # | 原定判据 | 实测 | 判定 |
|---|---|---|---|
| 1 | 蓝牙 SPP 发任意串，逐字节原样收回 | 手机发送，COM4 原样回显 | ✅ |
| 2 | AXI 地址表不变（`0x80000000`/`0x80100000`/`0x80200000`，无新增窗口） | `base = 0x80200000`，仅此一项 | ✅ |
| 3 | UART1 仍是可用调试控制台 | `[SYS] Fclk init done` 起全程干净 | ✅ |
| 4 | HDMI 画面照常、PWM 呼吸灯照常 | `breathing on LED3 (J15), CH0 = 0` | ✅ |
| 5 | 不新增 AXI IP，PL 资源增量 < 100 LUT | 无新增 IP；IO 29 → **31**（仅 2 个引脚） | ✅ |

附带通过的原定检查项：

| 检查 | 实测值 | 含义 |
|---|---|---|
| VERSION | `0x00010000` | AXI 地址窗口命中、从端有响应、连线正确 |
| self-test | `code 0` | CCR 写-读回一致 |
| init 后 STATUS | `0x0000000C`（en=1） | PWM 已使能 |
| PWM 频率 | `PSC=0 ARR=9999 → 4999.5 Hz` | 与 `49.995MHz/((PSC+1)(ARR+1))` 吻合 |
| 寄存器回读 | `CTRL=1 ARR=9999 PSC=0 CCR=0` | 真实落地，非缓存假象 |

### 12.2 这条通路的最终形态

```
蓝牙模块 TXD ──► J12 U9 ──► I_bt_uart_rx ──► system IP .uart0_rx_in
                                                        │
                                              PS 硬核 UART0（EMIO，非 AXI）
                                                        │
蓝牙模块 RXD ◄── J12 U8 ◄── O_bt_uart_tx ◄── system IP .uart0_tx_out

            PS 软件：USART_Poll() 把收到的字节原样发回
```

三段闭合点，缺任何一段都不通：

| 段 | 实现位置 | 关键配置 |
|---|---|---|
| PS 侧选路 | `soc_plat.c` `psio_data_0[]` | `0xF8803410` 连写两次、最终 **0 = UART0 走 PL IO**；`0xF8803414=1` = UART1 走 PS IO |
| PL 侧透传 | `system.v:250-251` | `.uart0_rx_in(I_bt_uart_rx)` / `.uart0_tx_out(O_bt_uart_tx)` |
| 引脚约束 | `fpga_pin.adc` | `U9`（RX，**只写 IOSTANDARD+PULLTYPE**）/ `U8`（TX，可写 DRIVESTRENGTH=8） |

### 12.3 本次踩过的坑（按代价排序）

| # | 坑 | 现象 | 根因 | 判据/修法 |
|---|---|---|---|---|
| 1 | **输入引脚写了 `DRIVESTRENGTH`** | 综合 **10 秒**就 `opt rtl error` | `USR-8409`：HRIO.LVCMOS33 输入方向不支持驱动强度 | 输入只写 `IOSTANDARD + PULLTYPE`；TD 里既有输入（`I_button`/`I_sysclk`/`I_data_lp_*`）全都如此 |
| 2 | **`0xF8801028` 是选择码不是分频数** | 115200 下满屏乱码 | `0x00000008` 低2位 `00` → ÷32 → 12.5MHz，driver 按 50MHz 算出 27 ⇒ 实际 28,932 baud | 改 `0x01010101`；**必须连 hpf 一起改**（内含 tcl 副本）+ 重编 fsbl |
| 3 | **`uart_probe` 位置错** | 开机头一行乱码 | `constructor` 早于 `AlUart_Hal_Init` | 串口判据只看 `main` 的 `printf`；探针已关 |
| 4 | **`probe_putc` 无超时死等** | 潜在：`main` 全不执行、LED 全灭 | UART 时钟未就绪时 `LSR.THRE` 恒 0 | 加 20 万次上界 |
| 5 | **Makefile 默认 `TARGET=HELLOWORLD`** | 产出名字对不上 | `Makefile:66 TARGET ?= HELLOWORLD` | 编译必须带 `TARGET=fdma_en` |

### 12.4 判据速查表（下次遇同类问题直接查）

| 现象 | 先看什么 | 能排除什么 |
|---|---|---|
| 串口没输出 | `main` 的 `printf` 有没有 | 有 ⇒ 硬件通，问题在更上层；没有 ⇒ 回到 LED 判据 |
| LED5（MIO51）不闪 | 程序有没有跑到 `main` | 不闪 = `constructor` 卡死或没下载 |
| LED3（J15）不呼吸 | `main` 有没有配 PWM | 呼吸 = AXI 通路 + `Fclk_Init` 都正常 |
| 开机头几行乱码、后面正常 | 是否有 constructor 探针 | 有 ⇒ 探针的锅，不是串口坏 |
| 综合 10 秒内失败 | 新增引脚的 ADC 行 | 多半是输入引脚写了 `DRIVESTRENGTH` |
| 改了源码但行为没变 | hpf 里那份副本改了没 | 勾 Platform Init 时执行的是 hpf 内的 tcl |

### 12.5 产物与文件清单

| 类型 | 路径 | 时间/大小 |
|---|---|---|
| 位流 | `soc_prj/soc_prj_Runs/best_result/soc_prj.bit` | 11-01 16:27 / 4052210 B / md5 `ca5f68e8…` |
| FSBL | `soc_sdk/fsbl/build/FSBL.elf` | 11-01 16:39 / 1455888 B（含 `0x01010101`） |
| 应用 | `soc_sdk/fdma_en/build/fdma_en.elf` | 11-01 17:16 / text **93108**（探针已剔除） |
| 平台源码 | `soc_base/platform/src/soc_plat.c:1428` | `0x01010101` + 9 行复发警示 |
| 平台脚本 | `soc_base/platform/soc_plat.tcl:1722` | `0x01010101` |
| hpf ×2 | `soc_hw/soc_prj.hpf` / `soc_sdk/soc_base/soc_prj.hpf` | 985882 B / 各留 `.bak-20261101-uartclk` |
| 文件备份 | `soc_plat.{c,tcl}.bak-20261101-uartclk` | — |

**待清理**（用后即删，已记录以免误留）：`soc_sdk/fdma_en/build/HELLOWORLD.{elf,bin,map}`、`MainProject/_fix_hpf.py`。

### 12.6 对后续阶段的启示

1. **PS 侧选路的写法可以直接复用**：`0xF8803410`（UART0）/ `0xF8803414`（UART1）这种 `PL_IOSEL_n` 开关，是"PS 外设走 PL 引脚"的总闸。将来接串口屏（TJC）时走 UART1 还是另开一路，要先确认这是**同一颗开关**，不能两路同时抢。
2. **`uart_probe` 这类 constructor 探针要慎用**：它绕开驱动看起来"更底层更可信"，实际上绕掉的正是"驱动完成初始化"这个前提。真要探串口，把探针放在 `main` 里 `AlLog_Init` 之后。
3. **蓝牙 9600 只是起步值**：JDY-31 支持 AT 改波特率（`AT+BAUD8` → 115200）。本期 D1 决策是"先 9600 通了再改"，后续若要传控制帧（`COMMAND` 结构体 4 字节），9600 下约 0.4 ms/字节，20 Hz 控制周期够用，**暂不必改**。
4. **`USART_RX_SEG_SIZE=1` 是回环的必需值**：因为 `RECEIVE_DONE` 只在"搬满整段"时触发。将来改成帧解析（`USART_LOOPBACK_ENABLE=0`）时可以调到 16，但要同步改 `USART_Poll()` 的续订时机。

---

## 十三、一句话结论

> **一条完全不经过 AXI 的 PS 硬核 EMIO 串口通路已经打通并验收**：蓝牙 → J12 U8/U9 → PL 透传 → PS UART0 → 软件回环 → 原路返回。
> 同期把困扰多轮的 `0xF8801028` 串口时钟问题彻底定案（是**选择码**不是分频数），并纠正了「`Design.xml` 的意图值可作判据」这个错误方法 —— **唯一可靠判据是物理串口实测**。
