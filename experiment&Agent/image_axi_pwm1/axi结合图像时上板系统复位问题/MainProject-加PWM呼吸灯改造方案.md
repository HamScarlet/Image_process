# MainProject 增加 AXI PWM 呼吸灯 · 改造方案（v1.0）

> **一句话**：PL 侧把 DI 里那个「靠 AXI GPIO 送数」的坏 `PWM.v` 换成 `axi_lite_pwm` AXI 从端；PS 侧把 `main.c` 从「裸地址写一个字节」重写成「探针 → 自检 → 非阻塞呼吸」；**图像链路一个像素都不碰**。
>
> 依据：`tryPScontrol/官方axi_gpio工程/官方文件改PS_axi_pwm/` 下的《改造方案》与《阶段归档》（PSPWM 工程 2026-10-29 上板通过）。
> 本文记录 **2026-10-31 这一轮改造**：已改了哪些文件、DI 还需要你手工做哪几步、怎么验。

工程根目录：`D:\FPGAproject\AnLuRun\MainProject`
文档位置：`D:\项目\FPGA工程\02-工程实操\04-PS侧总控的学习与开发\`

---

## 一、改造前实测（不是推测，逐条有据）

### 1.1 PL 侧

| 项 | 改造前实际状态 | 后果 |
|---|---|---|
| 图像链路 | 完整：MIPI D-PHY → CSI 解包 → RAW10 → al2axis → ISP → `rgb4_downscale_8_15` → `uidbuf` 三帧缓存/FDMA → VTC → HDMI 1024×600，另有 `lane_stream_stats` 车道检测旁路（结果挂在 `lane_result_hold`） | 正常，**不动** |
| `axi_lite_pwm.v` | md5 `cc59a43f94d6cd4fafab8b50635c5d2a`，与官方封版逐字节一致（P0 的 4 处修改已在） | 可直接用 |
| `ip_repo/axi_lite_pwm_1.0/Component.xml` | 20,158 B、`busInterfaces = 0`，`build_bus_if.py` 没跑 | IP 在 DI 里加不进去 |
| DI 里的 PWM 实例 | **`PWM_0`，`ipPath = ../PWM.v`、`customTool = use_rtl`**；`DUTY_VALUE` / `RELOAD_VALUE` 由 `AXI_GPIO_1` 的 `gpio_io_o` / `gpio2_io_o` 喂 | 不是 AXI 从端，PS 无法用一条 store 指令改占空比 |
| `01_rtl/PWM.v` 本身 | `prescaler_cnt <= PRESCALER + 1`（应为 `==`）、`cnt` / `pwm_state` 阻塞非阻塞混用、`cnt <= DUTY_VALUE` 无条件覆盖 | 波形不可控，属该废弃的实验件 |
| DI 导出端口 | 只有 `pwm_clk`(in) + `pwm_out1`(out)；`pwm_clk` 来自 PLL 的 `clk4_out` | 与 `axi_lite_pwm` 的端口契约完全不同 |
| 顶层 `01_rtl/system.v` | 实例化连了 `.pwm_out` / `.motor_dir` / `.motor_enable`，而 DI 生成的模块**没有这些端口**；`pwm_out1` 是隐式 wire、`O_pwm_out1` 悬空；`system.rst_n` 未连 | **TD 综合必报 port not found** |
| `fpga_pin.adc` | 已加 `O_motor_pwm[2:0]`=V6/U5/T5、`O_motor_dir`=T9、`O_motor_enable`=U10、`O_pwm_out1`=Y13 | 信号名与 DI 端口对不上；`motor_dir` 1 位 vs 模块 2 位 |
| 地址表 | 已有 3 个从端槽位：`0x80000000` / `0x80100000` / `0x80200000`（`Converter_2` 占 `0x80200000` 但下游悬空） | **DS_NUM 不用再扩**，比官方工程少一步 |
| `system.violation` | 3 条 `design port lack of connection`（`pwm_out[2:0]` / `motor_dir[1:0]` / `motor_enable`）+ 3 条 AXI ID 位宽不一致 + 2 条 reset 无驱动 | 前两条是 error 级，必须消 |

### 1.2 PS 侧

| 文件 | 改造前的问题 |
|---|---|
| `Car_control.h` | `uint8_t speed` **缺分号** → 整个工程编译失败 |
| `Car_control.c` | 调 `motor_init()`，`motor.c` 定义的是 `motor_Init()` → 链接失败；`Process_Cmd` 声明 `int` 却无 `return`；`car_loop` 全空 |
| `Servo.c` | 调 `TIM_SetCompare(PWM2, …)`，**两个符号都不存在** → 编译失败；CCR 按 ARR=1999 写死；缺 `al_systimer.h` |
| `motor.c/h` | 空壳；`SetSpeed` 有定义无声明 |
| `AXI_GPIO_test.c` | `reg = NULL` 赋给 `uint32_t` 再 `if(reg)` 判断 → 类型与语义都错 |
| `Definitions.h` | `0x80000000 + 0x100000` 缺括号；AXI GPIO1 实际基址是 `0x80100000` |
| `USART.c` | `Cmd_Receive` 里 `index` 未初始化即用；同轮 `index++` 两次导致跳字节；`Rx_data[index]` 越界；要求连续 4 个 `0x55` 才算帧头，与注释的单字节语义不符 |
| `main.c` | `while(1)` 只跑 `UART_Test()`；`AL_REG32_WRITE(0x80200000,0x01)` 裸地址直写且没配 ARR/CCR（写进去灯也不呼吸）；`%d` 打 `u32` |
| `TIM_PWM.h/.c` | 完整可用，仅 `PWM_Init()` 里 `PWM_DisableAll()` 会连带清掉别的通道使能；`PWM_Breath()` 是 `for(;;)` 死循环 |
| `.cproject` / `Makefile` | 正常：`Car_control` 已入编译，Makefile 用 `find` 自动搜集子目录 |

> **结论**：改造前 PL 综合挂在端口不匹配，PS 编译挂在缺分号和 `TIM_SetCompare`。图像链路本身是好的。

---

## 二、通道与引脚分配（本期定案）

| 通道 | 用途 | 引脚 | 板上位置 |
|---|---|---|---|
| CH0 | **呼吸灯** | `J15` | 板载 **LED3**（BANK33，3V3） |
| CH1 | 左轮电机 PWM | `V6` | J12（BANK11） |
| CH2 | 右轮电机 PWM | `U5` | J12（BANK11） |
| `motor_enable` | 电机驱动使能 | `U10` | J12（BANK11） |
| `motor_dir[0]` / `[1]` | 左右轮方向 | `T9` / `T5` | J12（BANK11） |
| — | `code_driver[3:0]`（图像链路原有） | `W9/W10/Y11/W11` | J12（BANK11） |

> **为什么是 LED3(J15) 而不是 LED1(T19)**（2026-10-31 综合报错后修订）
>
> TD 报 `USR-8001: Design contains multiple IOSTANDARD setups on bank 32`，根因是**同 bank 内供电轨必须一致**：
> - **BANK32**（VCC_ADJ1）在本工程被 **MIPI 子卡占为 1.8V 域** —— 摄像头引脚 `IO_cam_sda`/`O_cam_rst`/`O_cam_scl`/`O_clk_24m` 是 LVCMOS18，`I_clk_hs_p`/`I_data_*` 是 LVDS18。
>   板载 **LED1 = T19、LED2 = R19 恰好都在 BANK32**（见《板卡资源全解析》§3.5⑦），把 3.3V 的 PWM 塞进去必然冲突 → **T19/R19 在本工程物理上不可用**。
> - **BANK33**（VCC_ADJ2 = 3V3 固定）承载全部板载外设，**LED3 = J15** 在此；本工程已用的 HDMI（`LVDS33_E`：K17/M14/F16/D19）与按键（`LVCMOS33`：K14/J14）也在此 bank，**同为 3.3V 轨 → 不冲突**。
> - 因此呼吸灯最终落在 **J15 = 板载 LED3**，仍是**板载灯、免外接**，只是从 LED1 换成 LED3。
>
> 备选（若 J15 也被占）：J12 的 **Y13**（BANK11，3V3 核心板固定）——需外接 LED + 1k 电阻，但与 10-28 那次**综合成功**的引脚集完全同构，最稳。
>
> **代价**：板载 LED3 的点亮极性未实测（原 LED1 是"高=亮"，LED3 极性可能相反）。若上板后灯完全不亮 → 把 `O_pwm_led` 取反即可（`system.v` 里 `assign O_pwm_led = ~pwm_ch[0];`）。
>
> 原 `O_pwm_out1 → Y13` 的那个 IO 改给 `motor_dir[1]`（现落在 T5，原 `O_motor_pwm[2]` 的位置）。

**频率**：`f_pwm = 49,995,000 / ((PSC+1) × (ARR+1))`。这里的 49,995,000 Hz 就是 **`p2f_clk1`**（MainProject 实测 `p2f_clk1_Dot_Actual_IO_Frequency = 49.995`；**`p2f_clk0` 在本工程是 199.98 MHz，别搞混**）。PSC=0 / ARR=9999 → **4.9995 kHz**（该时钟已在 PSPWM 用 1 Hz PWM + 秒表实测确认）；ARR=999899 → **50 Hz**（舵机标准）。

---

## 三、本次已完成（已落盘）

### 3.1 PL / 工程配置

| 文件 | 改动 | 判据 |
|---|---|---|
| `ip_repo/axi_lite_pwm_1.0/build_bus_if.py` | 从官方目录拷入，`PKG` 路径改为本工程 | — |
| `ip_repo/axi_lite_pwm_1.0/Component.xml` | 跑脚本注入 `S_AXI` / `S_AXI_ACLK` / `S_AXI_AResetn` + 14 个寄存器 | ✅ 20,158 → **50,516 B**，md5 `61ebfad2074bd5703e7b731d51d26c98`，**与 PSPWM 成功工程完全一致** |
| `uisrc/01_rtl/system.v` | 端口：删 `O_pwm_out1`，加 `O_pwm_led`；`O_motor_pwm` 3→2 位；`O_motor_dir` 1→2 位<br>实例：删 `.pwm_clk` / `.pwm_out1`，改接 `.pwm_out(pwm_ch)`<br>新增 `assign` 把 `pwm_ch[2:0]` 展开到 LED / 电机引脚<br>PLL：`.clk4_out()` 空接（PWM 时钟与 AXI 同源 `p2f_clk1`，不引第二时钟） | 端口与 adc 一一对应 |
| `uisrc/04_pin/fpga_pin.adc` | `O_pwm_out1` → `O_pwm_led` = **J15**（板载 LED3）；`O_motor_dir` → `[0]`=T9 / `[1]`=T5；删 `O_motor_pwm[2]` | 6 条 motor/pwm 约束全对上；**引脚 location 集合与 10-28 综合成功时一致（仅信号名变）** |

### 3.2 PS 代码（`soc_sdk/fdma_en/`）

| 文件 | 改动 |
|---|---|
| `Definitions.h` | 重写：基址常量带括号，`AXI_GPIO1_BASE` 修正为 `0x80100000`，DATA/TRI 偏移分离 |
| `AXI_GPIO_test.h/.c` | `TRI_REG` 宏移入 `Definitions.h`；`reg = NULL` → `0`（无效通道返回 0）；`ch` 语义改为 0/1 对应 GPIO0/GPIO1 |
| `Car_control.h` | **补上 `speed` 的分号**；结构体加 `reserved` 对齐；声明 `car_Init` / `car_Loop` / `Process_Cmd(const COMMAND *)` |
| `Car_control.c` | 重写：`car_Init` 顺序 = `PWM_Init` → `motor_Init` → `Servo_Init` → `USART_Init`；`car_Loop` 取命令并下发；`Process_Cmd` 做四道校验后调 `motor_SetSpeed`（差速转向为占位策略） |
| `Car_control/motor.h/.c` | 补齐 `motor_Init` / `motor_Enable` / `motor_SetSpeed` / `motor_Stop`；百分比 → CCR 换算；负值反向靠 `DIR[1:0]`；两轮都为零时自动撤销驱动使能 |
| `Car_control/Servo.h/.c` | 删掉不存在的 `TIM_SetCompare` / `PWM2`；**当前不占用任何通道**（3 个通道已被呼吸灯 + 双轮占满），文件头写明阶段 6 的二选一方案 |
| `Car_control/USART.h/.c` | 环形缓冲 + 单字节状态机解析帧 `0x55 / direct / diversion / speed / 0x56`；`USART_Poll` 由 `USART_POLL_ENABLE` 宏控制（**默认 0**，优先保证呼吸节拍）；`USART_GetCmd` 取命令 |
| `Car_control/TIM_PWM.h` | 加 `PWM_CH_MASK` / `PWM_SERVO_ARR = 999899`（50 Hz）/ `PWM_BREATH_TICK_MS` / `PWM_BreathTick` 声明；重写通道分配注释 |
| `Car_control/TIM_PWM.c` | `PWM_Init()` 改为**只配 CH0**（去掉 `PWM_DisableAll`，避免与 `motor_Init` 互相抹掉使能）；新增非阻塞 `PWM_BreathTick()`；`PWM_Breath()` 保留但标注「主循环里别用」 |
| `main.c` | 重写：`Fclk_Init` → `BRINGUP_STEP` 分级探针（读 VERSION=65536）→ 自检 → `car_Init` → `while(1)` 里 `PWM_BreathTick` + `AlSys_MDelay(2)`；删掉裸地址写；格式化符修正 |

> **与初版规划的一处偏差（已按低风险调整）**：初版建议顺手删掉 `AXI_GPIO_1`。实测它在 DI 里还挂着 `PWM_0` 的送数连线，删它要动 AXI 矩阵，收益只有几百 LUT。**本期保留它**（换掉 `PWM_0` 后它自然悬空、无害），留到后续清理。PS 侧 `AXI_GPIO_test.c` 因此也保留并修好，只是不被 `main` 调用。

---

## 四、待你在 GUI 完成（按顺序，缺一步就综合不过）

### 4.1 Design Integrator（DI）

> **逐步操作单见同目录《MainProject-DI改造逐步操作单.md》**（带每步界面动作与判据）。
> 下表是提纲版，**已按 MainProject 实测修正过三处**与官方 PSPWM 不同的地方。

| # | 动作 | 判据 |
|---|---|---|
| 1 | 打开 `soc_prj` 工程 → Design Integrator | 能加载 `Design.xml` |
| 2 | **删除 `PWM_0` 实例**（`use_rtl` 挂 `../PWM.v` 的那个） | 方块消失；`AXI_GPIO_1` 的两根输出变悬空（正常） |
| 3 | **删除导出端口 `pwm_out1` / `pwm_clk` / `rst_n`** | 画布边缘只剩 `I_fdma_*` / `p2f_clk0` / `p2f_rst0_n` / `O_fdma_*` / `code_driver[3:0]` |
| 4 | IP+ 添加 `axi_lite_pwm_1.0`（User IP） | 方块上能看到粗蓝 `S_AXI` + `s_axi_aclk`/`s_axi_aresetn` + `pwm_out[2:0]`/`motor_dir[1:0]`/`motor_enable`。**只有光秃方块 = IP 库没刷新，重启 TD** |
| 5 | **连 3 根线**：`Converter_2.DS_AXI` ↔ IP `S_AXI`（粗蓝）；`p2f_clk1` → `s_axi_aclk`；`p2f_rst0_n` → `s_axi_aresetn` | 三根都在；细线要选「复用已有网络」或从已有线上拖支线 |
| 6 | 导出三个端口：`pwm_out[2:0]` / `motor_dir[1:0]` / `motor_enable` | **生成后无 `_0` 后缀** |
| 7 | **Generate** | `system.violation` 里 `design port lack of connection` 三条消失 |

**⚠️ 三处与官方 PSPWM 不同，务必按本工程来**：

| 项 | 官方 PSPWM 做法 | **MainProject 正确做法** | 依据 |
|---|---|---|---|
| PWM 的 AXI 时钟 | 接 `p2f_clk0` | **接 `p2f_clk1`** | MainProject `p2f_clk0 = 199.98 MHz`、`p2f_clk1 = 49.995 MHz`；矩阵与三个转换器**全部**挂在 `p2f_clk1` 上，从端必须同域 |
| 矩阵从端数 | 从 3 加到 4 | **不动**（`AL_DS_NUM=3`，`DS2_BASEADDR0` 已是 `0x80200000`） | `Design.xml` 实测；官方 6.8.1 强调「基址必须提前填好」，本工程已填对 |
| 协议转换器 | 新建 `_3` | **不动**（`AXI_Protocol_Converter_2` 已存在，参数与 `_0/_1` 完全一致：ID=12、AXI4→AXI4LITE；只是下游 20 根线空接） | `Design.xml` + `hdl/system.v` 实测 |

**另外两条**：
- `Processor_System_Reset_0` 的 `aux_rst`/`system_rst` 无驱动（2 条 error）**不要修** —— 那是既有状态，图像链路本来就这样且能出图，改它反而动到图像的复位行为。
- Address Editor **不要勾 `Auto Assign`**（会重排窗口，C 代码里写死的 `0x80200000` 当场失效）。地址 `0x80200000` 已在矩阵参数里定好，Address Editor 会沿用。

> ⚠️ 如果 Generate 后生成的端口名与预期不同（比如带了实例名前缀），**改 `01_rtl/system.v` 里对应的 3 行 `.pwm_out/.motor_dir/.motor_enable` 和 3 行 `assign`** 即可，别去改 DI 生成的文件（每次 Generate 都会覆盖）。

### 4.2 TD（Tang Dynasty）

1. 确认 `uisrc/01_rtl/axi_lite_pwm/axi_lite_pwm.v` **没有被加进编译列表**（已在 `soc_prj.al` 里核实为「不在」，保持即可）。它和 DI 生成的 `ip/system_axi_lite_pwm_0/RTL/` 是同一模块的两份拷贝，同时编译必然 `module already defined`。
2. Synthesis（`syn_1`）→ Physical Design（`phy_1`）→ 生成位流。
3. 判据：0 violation；`p2f_clk1` 组正裕量；记录 `#slice` 占用。

### 4.3 FD（Fusion Design）

1. **全量重编**（不要增量）。判据：`exit=0`，且 `al_log.c.o` / `al_uart_hal.c.o` / `al_chip.c.o` 时间戳一致。
2. 下载配置 `DOWNLOAD = ddr`，首次调试勾 `Run Platform Init` + `Program FPGA`。
3. ⚠️ SoC 工程 **TD 直下不出图，必须走 FD**。

---

## 五、上板验证（三条独立通道，互不依赖）

| 通道 | 通路段 | 回答什么问题 |
|---|---|---|
| 串口打印 `[PWM] VERSION = 65536` | PS → AXI → 从端 | AXI 通路通不通 |
| 串口打印 `[PWM] selftest = 0` | CCR 写-读回 | 寄存器真的可读可写（不是假 ACK） |
| **LED3（J15）呼吸** | PL 计数器 → 比较器 → 引脚 | 波形出来了 |
| **HDMI 图像照常显示** | 图像链路未被破坏 | **这条最重要** |

**现象对照表**（排障直接查）：

| VERSION | 呼吸 | 图像 | 结论 |
|---|---|---|---|
| 读不到 65536 | 灭 | 正常 | AXI 通路没通 → 查 DI 连线 / 基址 / `Component.xml` |
| 65536 | 灭 | 正常 | 寄存器通但没出波 → 查 CH0 使能位（`CTRL[0]`）、ARR/CCR |
| 65536 | **呼吸** | 正常 | **全通** |
| 任何 | 任何 | 黑屏 | PL 综合/位流问题，不是 PS 的事 |

`BRINGUP_STEP` 分级（`main.c` 顶部）：

| 值 | 行为 |
|---|---|
| 1 | 只读 VERSION，一个字节都不写（**最小探针**）。此时灯全灭是**正确现象** |
| 2 | 加 CCR 写回读自检 |
| 3 | 完整：`car_Init` + 呼吸灯（当前默认） |

无串口时的兜底：FD 调试器 Memory 窗口直接读 `0x8020000C`，读到 `00010000` 即 AXI 通（注意该窗口按**大端显示**，真实值是小端）。

---

## 六、会复发的坑（官方已踩过）

| # | 现象 | 根因 | 处置 / 判据 |
|---|---|---|---|
| 1 | FD 编译 72 errors，全在 `al_mpu.c` | FD **重新导出 platform** 会把 `soc_base/platform/inc/soc_plat.h` 里 15 行 `#define HAVE_*PS_DRIVER` 整块写空 | 补回。判据：`grep -c "^#define HAVE_" soc_plat.h` = **15** |
| 2 | 串口无输出，但 elf「编译成功」 | 陈旧 `.o` 掩盖了坑 1（`al_log.c` 里有 `#error`，从未被重编） | 修头文件后**全量重编**，看目标文件时间戳 |
| 3 | `module already defined` | 同名 IP 源被编译两次 | `01_rtl/axi_lite_pwm/` 不进编译列表 |
| 4 | DI 里看不到 IP 端口 | 用 mpack 打开保存过一次，把 `busInterfaces` 抹了 | 改 `.v` 后必须重跑「mpack → `build_bus_if.py`」两步。脚本幂等，重跑会 ABORT 退出 |
| 5 | 呼吸灯忽快忽慢 | 主循环里有阻塞调用（串口） | `USART_POLL_ENABLE` 保持 0；要调试串口时临时置 1 |
| 6 | 一改占空比就出窄脉冲毛刺 | 直接写 CCR 没走 `UPDATE` | 统一走 `PWM_Commit()`，影子寄存器在周期边界整体切换 |

> 串口乱码那条（CRG 选择码 `0x00000008` 被当成 ÷8，实为 ÷32）是 PSPWM 那台工程环境特定的坑，本工程若串口正常**不要动** `0xF8801028`。

---

## 七、备份与回滚

本次改动前的原件均已就地备份为 `.bak-20261031`：

| 目录 | 备份文件 |
|---|---|
| `soc_prj/uisrc/01_rtl/` | `system.v.bak-20261031` |
| `soc_prj/uisrc/04_pin/` | `fpga_pin.adc.bak-20261031` |
| `soc_prj/uisrc/01_rtl/system/` | `Design.xml.bak-20261031` |
| `ip_repo/axi_lite_pwm_1.0/` | `Component.xml.bak-20261031`（注入前，20 KB 版） |
| `soc_sdk/fdma_en/` | `main.c` / `Car_control.c` / `Car_control.h` / `Definitions.h` / `AXI_GPIO_test.c` / `AXI_GPIO_test.h` / `ui_type.h` 各一份 |
| `soc_sdk/fdma_en/Car_control/` | `TIM_PWM.c/h` / `motor.c/h` / `Servo.c/h` / `USART.c/h` 各一份 |

回滚方式：把 `.bak-20261031` 改回原名即可（DI 的 `Design.xml` 需在 DI 关闭状态下替换）。

---

## 八、变更日志

| 日期 | 内容 |
|---|---|
| 2026-10-31 | 现状实测（PL 综合与 PS 编译均为「必挂」状态）；IP 包补全总线接口，md5 与 PSPWM 一致；顶层 `system.v` 与 `fpga_pin.adc` 按 AXI PWM 契约改写；PS 侧 9 个源文件全部重写；本文落盘 |
| 2026-10-31 | **DI 改造完成并 generate 通过**；修复 depot 登记缺失（`soc_prj/.recent_user_depot.ini` 为 0 字节 → 按 PSPWM 格式写入 142 B，需重启 TD 生效） |
| 2026-10-31 | **综合失败 `USR-8001`（bank 32 IOSTANDARD 冲突）→ 呼吸灯引脚 T19 改 J15**；`motor_dir[1]` 由 Y13 改 T5（引脚 location 集合回到 10-28 综合成功态）；代码/文档中 T19 表述全部同步为 J15/LED3 |
| 2026-10-31 | **PL 综合验收通过（§13）**：AXI 域（p2f_clk1 50MHz）**SWNS 13.013ns / HWNS 0.041ns / 0 违例**，GP0 主口双向跨域 0 违例 → **跨时钟域根因被时序报告独立证实修复**；`axi_lite_pwm_0` 三通道实例化确认；位流 `soc_prj.bit` 已生成。剩余 2 组违例定性为**既有基线**（200MHz 域异步 FIFO 反向跨域 hold；HP0 setup 与前身 `mymipi_hdmi2` 同型且端点更少）。**更正 §11.4 的 UART 结论**：`0x00000008` 才是对的（FD 平台源头 399.96÷8=49.995 自洽），官方 `0x01010101` 不可作参照；**`HAVE_` 是 14 不是 15** |
| 2026-10-31 | **「运行中突然系统复位」根因完全定位并修复（§12）**：①AXI 链与 GP0 主口**跨时钟域**（199.98MHz vs 49.995MHz）②AXI ID 被截成 1 bit ③Converter_0/1 空接。修复：GP0 主口并入 `p2f_clk1`（AXI 全链单域 49.995MHz，与官方/PSPWM 同构）、矩阵参数改回 13/12/SASD/thread=12、移植官方 34 条信号级连线补齐 DS0/DS1、GPIO 地址位宽 9→32。**PS 侧零改动**（PWM 频率公式仍 49.995MHz） |

---

## 九、综合排障记录（2026-10-31）

### 9.1 `USR-8001: Design contains multiple IOSTANDARD setups on bank 32`

| 项 | 内容 |
|---|---|
| 现象 | TD 综合在 **IO setups legality check** 阶段就停住，报 bank 32 有多种 IOSTANDARD |
| 日志 | `soc_prj/soc_prj_Runs/syn_1/run.log` L2408 起，`RUN-1001` 列出 bank 32 全部引脚 |
| 判据 | TD 要求**同一 bank 内供电轨电压一致**；同为 1.8V 的 LVCMOS18 与 LVDS18 可以共存（摄像头引脚本就如此），但 3.3V 的 LVCMOS33 塞进 1.8V 的 bank 必炸 |
| 冲突源 | `O_pwm_led` = **T19**（板载 LED1，BANK32）——本次新增，**唯一入侵者** |
| 处置 | 呼吸灯改到 **J15 = 板载 LED3**（BANK33，VCC_ADJ2 = 3V3 固定，与 HDMI/按键同 bank 同轨）；`motor_dir[1]` 从 Y13 改 **T5**（原 `O_motor_pwm[2]` 的位置） |
| 复核 | `diff` 改造前后 adc：**location 集合与 10-28 综合成功那次完全一致**，只有信号名变了（T9/U10/V6/U5/T5 六脚不动，`O_pwm_led` 新占 J15 之外还余 Y13 空闲） |
| 代价 | 板载 LED3 点亮极性未实测。若上板灯不亮 → `assign O_pwm_led = ~pwm_ch[0];` 取反 |

> ⚠️ **口径更正**：板载 **LED1(T19) / LED2(R19) 在 BANK32**，本工程该 bank 已被 MIPI 子卡占为 1.8V → **这两个 LED 在带 MIPI 的工程里一律不可用**。带外设的 3.3V 板载 LED 只有 **LED3(J15)** 和 **LED4(M20，兼功放 SPK_CTL_H)**。

### 9.2 已发现但尚未处理的既有问题：时序不收敛

`soc_prj/soc_prj_Runs/syn_1/flow.status`（10-28 旧记录，来自 `E:\FPGA\anlu_prj\Image_process\MainProject\`）显示**改造前**的 MainProject 本来就没收敛：

| 项 | 旧值 |
|---|---|
| Setup WNS | **−3977 ps** |
| Setup TNS | **−2,496,316 ps** |
| 违例端点 | **1220** |
| Hold WNS | −353 ps |

**这不是本次改造引入的**，但会挡住"能跑起来"这一步。等 `USR-8001` 解决、重新综合出新的 timing report 后再单独排（大概率是 ISP/降采样链路的流水级不足或 `p2f_clk1` 域跨域缺约束）。

---

## 十、PS ↔ PL 契约交叉核对（2026-10-31 第二轮）

本机只有 TD、**没有 FD 和交叉编译器**，PS 代码无法在本地编译。为降低首次 FD 编译的返工率，改用「逐条比对 SDK 真实原型 + PL 侧 RTL 实现」的方式做静态核对。

### 10.1 核对结果（全部一致 ✅）

| 核对项 | PS 侧 | PL / SDK 侧 | 结论 |
|---|---|---|---|
| 寄存器偏移 | `PWM_REG_CH_PSC/ARR/CCR(ch) = 0x10/0x14/0x18 + ch*0x10` | `REG_PWM{0,1,2}_{PSC,ARR,CCR} = 0x10/0x14/0x18 / 0x20/0x24/0x28 / 0x30/0x34/0x38` | ✅ 逐位一致 |
| `UPDATE` | `0x40`，写 1 到 bit[ch] | `REG_UPDATE = 0x40`，write-one to bits[2:0] | ✅ |
| `CTRL` 位域 | `[0..2]` 通道使能、`[3]` 电机使能 | `[0]=PWM0 enable … [3]=motor driver enable` | ✅ |
| `DIR` | `[0:1]` 电机方向 | `[0]=motor0 direction, [1]=motor1 direction` | ✅ |
| `STATUS` | `[2:0]` 待更新、`[5:3]` 使能、`[6]` 电机使能 | `{25'd0, ctrl_reg[3], ctrl_reg[2:0], update_pending}` | ✅ 位布局完全对应 |
| `VERSION` | 期望 `0x00010000`（65536） | `read_data_mux = 32'h00010000` | ✅ |
| 影子寄存器 | 写 CCR 后立即读回应得原值 | 读 mux 返回 `*_ccr_shadow` | ✅ `PWM_SelfTest` 成立 |
| `CTRL` 可读回 | `PWM_Enable` 用读-改-写 | `REG_CTRL: read_data_mux = ctrl_reg` | ✅ 不会丢 motor enable 位 |
| `AlUart_Hal_Init` | `(&UartHandle, DevId, &InitStruct, AL_NULL)` | `(Handle**, DevId, InitConfig*, Callback)` | ✅ 4 参数匹配 |
| `AlUart_Hal_RecvData` | `(Handle, buf, size)` | `(Handle*, Data*, Size)` | ✅ **3 参数，无 timeout** |
| `AlUart_Hal_SendData` | `(Handle, buf, len)` | `(Handle*, Data*, Size)` | ✅ |
| `AL_UART_InitStruct` 字段 | `.BaudRate/.WordLength/.StopBits/.Parity/.HwFlowCtl/.CharTimeoutEnable` | 同名同序 | ✅ |
| UART 枚举常量 | `AL_UART_NO_PARITY` / `AL_UART_CHAR_8BITS` / `AL_UART_STOP_1BIT` | 定义在 `al_uart_ll.h`（`al_uart_dev.h` 已链式 include） | ✅ |
| `RecvBuffer.HandledCnt` | `UartHandle->Dev.RecvBuffer.HandledCnt` | `AL_Uart_BufferStruct{BufferPtr, RequestedCnt, HandledCnt}` | ✅ |
| `AlSys_MDelay` | `AlSys_MDelay(1U/2U/...)` | `AL_VOID AlSys_MDelay(AL_U64 Msec)` | ✅ |
| `al_printf` | 各 .c 直接调用 | `al_core.h` → `al_utils_def.h` → `al_printf.h` | ✅ |
| 21 个本工程 API | 调用点 | 声明 + 定义 | ✅ 21/21 齐全 |

### 10.2 修掉的 P0 bug：`motor_Init()` 把呼吸灯使能抹掉了

| 项 | 内容 |
|---|---|
| 现象 | 呼吸灯**永远不输出**，但 `VERSION=65536`、`selftest=0` 全都正常 —— 上板后极易误判成"PL 没出波"或"LED 极性反了" |
| 根因 | `car_Init()` 顺序是 `PWM_Init()`（使能 CH0）→ `motor_Init()`，而 **`motor_Init()` 第一行是 `PWM_DisableAll()` → `PWM_WR(CTRL, 0)` → 把 CH0 的使能位一起清零** |
| 修复 | 新增 `PWM_DisableCh(ch_mask)`（读-改-写 CTRL，只清指定通道，保留 CH0 与 CTRL[3]）；`motor_Init()` 改用它；另外把 `car_Init()` 顺序改成 **motor → PWM**，让 CH0 最后使能，双保险 |
| 现状 | `PWM_DisableAll()` 全工程**已无调用点**（仅保留定义与声明，并在头文件旁标注"会连 CH0 一起清掉"） |

> 这类 bug 编译器抓不到、静态语法检查也抓不到 —— 只有把 PL 的 RTL 行为（CTRL 可读回 / 影子寄存器）和调用顺序一起读一遍才会暴露。**上板后若灯不亮，第一件事是读 STATUS 寄存器看 `[5:3]` 通道使能位**，而不是先怀疑极性。

### 10.3 更正一条此前的错误记录

原记录"`ui_io.h` 的 `extern "C" {` 未闭合（花括号 7 vs 6）"**是错的**。实际文件：

```c
#ifdef __cplusplus
extern "C" {
#endif
```

`extern "C"` 整块被 `#ifdef __cplusplus` 包着，C 编译模式下**整块跳过**，语法完全正确，不需要改。

### 10.4 顺手修掉的注释陷阱（PL 侧，只改注释不动 RTL）

`axi_lite_pwm.v` 从官方 PSPWM 工程继承而来，其头部注释写着"Connect s_axi_aclk to … (p2f_clk0)"。**但 MainProject 的编号相反**：`p2f_clk0` = 199.98 MHz、`p2f_clk1` = 49.995 MHz。照注释接线会静默地把 PWM 频率变成 4 倍（19.998 kHz）—— 不报错，只是呼吸快 4 倍。已在 `ip_repo/axi_lite_pwm_1.0/axi_lite_pwm_files/RTL/axi_lite_pwm.v` 与 `soc_prj/uisrc/01_rtl/axi_lite_pwm/axi_lite_pwm.v` 两份（md5 相同）同时改成显眼的警告块。

### 10.5 尚未验证的部分（如实说明）

- **本机无法编译**：只有 TD，没有 FD、没有 `arm-none-eabi-gcc`。上述核对是"读 SDK 真实原型 + 读 PL RTL 实现"的人工比对，**不能替代编译器**。
- 首次 FD 编译仍可能有小问题（宏、`inline`、类型宽度），需现场修。
- **上板第一件事读 STATUS**：`0x80200008` 的 `[5:3]` 必须是 `001`（CH0 使能），`[6]` 电机使能应为 0。若 `[5:3]` 为 0 → 说明 CTRL 被谁抹了，回来查调用顺序。

---

## 十一、参考官方成功工程 axi_intr 的移植（2026-10-31 第三轮）

参照物：`D:\FPGAproject\AnLuRun\PSPWM\soc_sdk\axi_intr\`（**有 `build/axi_intr.elf`，即编译跑通过**）。四个源文件：`AXI_test.c/h`（AXI 通路验证）、`TIM_PWM.c/h`（PWM 驱动）、`uart_probe.c/h`（串口时钟探针）、`main.c`（三步验证 + 状态灯）。

### 11.1 移植清单

| # | 来源 | 移植到 | 内容 |
|---|---|---|---|
| 1 | `AXI_test.c` 的 MMIO 宏 | `TIM_PWM.c` | 加 `(uintptr_t)` 过渡：`UI_Out32((void *)(uintptr_t)(BASE + off), val)`。目标机是 AArch64（64 位指针），直接 `(void *)` 转 32 位整数会触发 `-Wint-to-pointer-cast` 警告，淹没真正的告警 |
| 2 | `main.c` 的 `StatLed_*` | `main.c` | **状态灯 LED5 = MIO51**（PS GPIO）：上电短闪 3 下 → 全过转常亮 → 失败慢闪 250 ms |
| 3 | `main.c` 的诊断打印 | `main.c` | STATUS 逐位解码（pending/en/motor_en）、**寄存器回读**（CTRL/ARR/PSC/CCR）、失败就地停机 `StatFailLoop` |
| 4 | `main.c` 的 printf 风格 | `main.c` | `#include <stdio.h>` + `printf`（经 `al_log.c` 的 `AlLog_Write` 重定向到 UART1）+ `%08X`/`%u` + `(unsigned)` 强转；替换掉原来的 `al_printf` + `%d` 打 u32 |
| 5 | SDK 源码实读的**接收模型** | `USART.c` | 接收从"轮询 `AlUart_Hal_RecvData`"改成**中断回调 + 分段接收**（见 11.3） |

### 11.2 状态灯在本工程的适用性（已逐项核对，不能照抄的地方）

| 核对项 | axi_intr（PSPWM） | MainProject | 结论 |
|---|---|---|---|
| MIO51 是否配成 GPIO | `soc_plat.c` 有 `PS IO 51->FUNCSEL: GPIO` | **同样有** | ✅ 可用 |
| GPIO MIO 全集 | {0,7,8,9,46,50,51} | **{0,7,8,16..27,46,50,51,52,53}** | ⚠ 集合不同，**必须按本工程的来**（axi_intr 注释里也写了这句） |
| `AlGpio_Hal_Init` DevId | 0（`AlGpio_HwConfig[0].DeviceId`） | **0**（`al_gpio_cfg.c` 实测，单实例） | ✅ |
| `GPIO_MAX_PIN_NUM` | 118 | **118** | ✅ MIO51 在范围内 |
| `AlGpio_Hal_WritePin` 语义 | 只改自己那一位 + 设输出方向 | **完全一致**（实读 `al_gpio_hal.c:411`） | ✅ |
| LED5 极性 | 写 1 = 亮（N-MOS 低边） | 同板同接法 | ✅ 若反了把 `StatLed()` 里 1U/0U 对调 |
| ⚠ 复用风险 | — | **MIO51 = PS 网口复位 `PS_ETH_RST_B`** | 本工程不用网口；将来用网口就把 `STAT_LED_OK` 改 0 |

> **本工程其实有比 LED5 更强的独立判据**：**HDMI 图像本身就是"位流活着"的证据** —— MIPI→ISP→FDMA→HDMI 全在 PL，既不经过 AXI 也不经过 PS。所以 MainProject 的两条互不依赖观察通道是 **LED5（MIO51，PS 侧）** + **HDMI 图像（PL 侧）**，比 axi_intr 的三条更干净。

### 11.3 修掉的第二个真 bug：串口接收模型用错

上一版 `USART.c` 在主循环里轮询调用 `AlUart_Hal_RecvData`。实读 SDK 源码（`al_uart_dev.c:475` `AlUart_Dev_RecvData`）后确认这是错的：

| 事实 | 后果 |
|---|---|
| `AlUart_Hal_RecvData` 是"**启动**接收"：先搬 FIFO 现成的字节，没搬满就**记下 `RecvBuffer` 并使能 RX 线中断**，由中断继续搬，**搬满 Size 才触发 `AL_UART_EVENT_RECEIVE_DONE`** | 轮询反复调用会撞上 `AL_ASSERT(!AlUart_Dev_IsRxBusy(Uart))` |
| `RecvBuffer.HandledCnt` **只在"没搬满"的分支更新**；一次搬满时走 else 分支，**不更新 `HandledCnt`** | 轮询读出来的是**上一次的陈旧值** |
| `AlUart_Hal_RecvDataPolling` 是 `while (HandledCnt < Size)` **阻塞读满** | 放进主循环会卡住呼吸灯节拍 |

**改成**：`AlUart_Hal_Init` 注册 `uart_evt_cb` → 回调（中断上下文）只做"把 `RecvBuffer.HandledCnt` 字节搬进环形缓冲 + 置标志" → **续订下一段（再次调 `AlUart_Hal_RecvData`）放回主循环上下文**。分段大小 `USART_RX_SEG_SIZE = 16`（115200 下约 1.4 ms 一段），环形缓冲 64 字节。

> 本期 `USART_RX_ENABLE = 0`（只验证 AXI PWM 呼吸灯，不引入接收链路的变量）；阶段 5 接蓝牙/串口屏时置 1 即可，代码路径已就绪。
> 原 `USART_POLL_ENABLE` 宏已删除（它建立在错误的"阻塞"理解上）。**"AlUart_Hal_RecvData 带字符超时是阻塞调用"是错的** —— 带字符超时的是 `AlUart_Hal_RecvDataPollingForCharTimeout`。

### 11.4 从 `uart_probe.c` 读到的一条关键情报：串口时钟的 4 倍差（**MainProject 没有这个问题**）

`uart_probe.c` 记录了 PSPWM 工程踩过的坑：

- `0xF8801028` = `IO400_DIV8_PARA`。官方例程写 **`0x01010101`**（四字节全 1）→ UART 时钟 50 MHz；**PSPWM 工程写 `0x00000008`** → 实际只有 12.5 MHz → **串口乱码**。修法：写 `0x01010101` + 分频 27（115,729 baud，误差 +0.46%）。
- 关键细节：**只把某一个字节置 1 不行，四个字节必须同为 1**；顺序必须是**先改 CRG 再写分频**。

**已实测核对 MainProject**：❗**本节结论有误，已在 §13.7 更正。** 实测 `soc_base/platform/src/soc_plat.c:1419` 与 `platform/soc_plat.tcl:1720` 写的都是 **`0x00000008`**（不是本节所说的 `0x01010101`）—— **但这才是对的**：FD 平台源头 `platform/Design.xml` 里 `IO_400_Actual = 399.96 MHz`、`UART0_Dot_Actual_Inside_Frequency = 49.995 MHz`，`399.96 ÷ 8 = 49.995` 与 `UART_CLOCK = 49995000` **三者精确自洽**。

> ❗**不能用「官方字面一致」当判据**：官方 `08_ps_uart_intr` 的 `UART0_Available = 0`，**它根本没用 PS UART**，那个 `0x01010101` 是给其他外设的默认值。取值由各工程 IO400 实际频率决定。
>
> ❗**反过来，PSPWM 的 UART 是不对的**：`div_fclk0 = 0x07`（÷8）→ `p2f_clk0 = 50 MHz`，却配 `0x00000008`（÷8）→ UART 实际 6.25 MHz，而 `UART_CLOCK` 仍写 49995000。它当时「能跑通」只是没真正验证串口输出。
>
> **MainProject 的串口时钟配置是对的，一个字节都不用改，`AlUart_Hal_Init(115200)` 可直接用。** 完整证据链见 §13.7。

### 11.5 本轮改动后的静态自检结果

| 检查 | 结果 |
|---|---|
| 括号配平（7 个改动文件 × 花/圆/方） | ✅ 21/21 |
| 新引入符号一致性（`AlGpio_Hal_*` / `uart_evt_cb` / `USART_RX_*` / `PWM_DisableCh` / `StatLed_*` / `AXI_PWM_BASE`） | ✅ 11/11 |
| `USART.c` 里 `AlUart_Hal_RecvData` 出现次数 | ✅ 恰好 2（Init 首启 + Poll 续订） |
| `USART.c` 里阻塞版 `RecvDataPolling` | ✅ 0 次 |
| `main.c` 里 `al_printf` / `printf` | ✅ 0 / 15 |
| `main.c` 里 `%d` 直接打 u32 | ✅ 0 处 |
| `main.c` 全部 15 条 printf 的格式符与实参数量 | ✅ 逐条核对一致 |
| PS 侧 API 声明/定义齐全（21 个） | ✅ 21/21 |

> ⚠ **依然不能替代编译器**：本机只有 TD，没有 FD 与交叉编译器。首次 FD 编译仍可能有小问题需现场修。
> 特别留意：`soc_plat.h` 的 15 行 `#define HAVE_*PS_DRIVER` 会被 FD 重新导出 platform 时写空（判据 `grep -c "^#define HAVE_" soc_plat.h` = 15），且**必须全量重编**，否则陈旧 `.o` 会掩盖这个坑。
| 待办 | DI 换 IP + 接线（§4.1）→ TD 综合布线 → FD 全量编译下载 → 上板验证（§5） |

---

*2026-10-31 · 工程 `D:\FPGAproject\AnLuRun\MainProject` · 状态：**根因已定位并完成 PL 侧修复（§12.6 三组改动全部落盘），待 TD 重新 generate → 综合 → FD 重编 → 上板验收***

> ⚠ **本轮最重要的一条结论**：官方 11 个含 GP0 主口的例程**无一例外**把 GP0 主口与 AXI 全链路放在同一时钟域。**「PS 的 AXI 主口时钟」必须与「AXI 从端时钟」同域**，这是安路 SoC 的硬约束，不是风格问题。跨域必然导致事务挂死 → PS 卡死 → 异常复位，且**报错信息（JTAG-DP STICKY ERROR）与真实病因毫无关联**。

---

## 十二、「运行中突然系统复位」的根因定位与修复（2026-10-31 第四轮）

### 12.1 现象与判定边界

| 项 | 内容 |
|---|---|
| 现象 | 位流下载成功、`Platform initialization Succeed`，PS 一启动系统立刻复位 |
| JTAG 报错 | `JTAG-DP STICKY ERROR` / `target dr1m90.core.0 is not halted (gdb fileio)` / `Error: Target not examined yet` |
| 关键约束 | **PSPWM 工程"读 VERSION 成功"从未结案**——AXI 访存导致异常复位这条线一直是悬案，本次按用户指令「后面所以从官方 axi 工程入手修改」重新走了一遍基准对照法 |
| 定位方法 | 不再猜寄存器，逐层比对 **官方 `14_axi_gpio_pl_intr` → 已跑通的 `PSPWM` → 本工程**三份 DI 主状态文件 |

### 12.2 根因 A（决定性）：AXI 总线跨时钟域

| 信号 | 官方 `14_axi_gpio_pl_intr` | PSPWM（已跑通） | MainProject（修复前） |
|---|---|---|---|
| `master_gp0_axi_aclk`（PS GP0 主口） | p2f_clk0 | p2f_clk0 | **p2f_clk0（199.98 MHz）** |
| `AXI_Matrix_0.aclk` | p2f_clk0 | p2f_clk0 | **p2f_clk1（49.995 MHz）** ⚠ |
| `AXI_Protocol_Converter_0/1/2.aclk` | p2f_clk0 | p2f_clk0 | **p2f_clk1** ⚠ |
| `axi_lite_pwm_0.s_axi_aclk` | — | p2f_clk0 | **p2f_clk1** ⚠ |

> **决定性证据**：扫遍官方例程库 **11 个** 含 GP0 主口的工程（`14_axi_gpio_pl_intr`、`15_axi_uart`、`16_axi_earm_ram`、`01_axi_bram_ctrl`、`02_axi_i2c_eeprom`、`03_pl_fdma`、`04_pl_fdma_video_1080P`、`05/08/09/10_Lwip`、`08_DAQ7606`），**无一例外把 GP0 主口与 AXI 全链路放在同一个 p2f_clk 域**。MainProject 是唯一例外。

机理：PS 用 199.98 MHz 发起 AXI 事务，矩阵/转换器/PWM 从端用 49.995 MHz 采样 → AR/AW 握手跨域无同步器 → 事务挂死 → PS 核卡在 load 指令 → 异常复位。

**为什么以前没炸**：`Design.xml.bak-20261031`（改造前备份）的时钟归属与当前**完全一致** → 这是**模板自带缺陷**，不是本次改造引入。改造前 PS 从未发起过 GP0 事务，缺陷一直潜伏；加了 PWM 之后第一次访问 `0x8020000C` 才引爆。

### 12.3 根因 B（叠加致命）：AXI ID 位宽截断

`uisrc/01_rtl/system/hdl/system.v`（DI 生成的 interconnect RTL）里的硬证据：

```
// MainProject（错误）
wire [0:0]  w_port__AXI_Matrix_0__us0_arid ;                        // 只接 1 bit
assign w_port__AXI_Matrix_0__us0_arid = w_net__..._master_gp0_axi_arid ;   // 12 → 1 截断
assign w_port__AXI_Protocol_Converter_2__us_axi_arid = {10'b0, w_net__AXI_Matrix_0__ds2_arid} ;  // 2 → 12 零扩展

// PSPWM（正确）
wire [11:0] w_port__AXI_Matrix_0__us0_arid ;
wire [12:0] w_net__AXI_Matrix_0__ds2_arid ;
assign w_port__AXI_Protocol_Converter_2__us_axi_arid = w_net__AXI_Matrix_0__ds2_arid ;  // 直连
```

参数根源（`AXI_Matrix_0` 实例）：MainProject 为 `AL_AXI_ID_WIDTH=2` / `AL_AXI_ID_WIDTH_USER=1` / `AL_CONNECTIVITY_MODE=1(SAMD)` / `us0_thread_id_width=1`；官方与 PSPWM 均为 `13 / 12 / 0(SASD) / 12`。**PS 的 GP0 ID 是 12 bit，被截成 1 bit 后不同事务会撞 ID**，AXI 协议失效。

### 12.4 根因 C（结构缺陷，非本次直接触发）

- `AXI_Protocol_Converter_0/1` 的 `DS_AXI` **空接** → `0x80000000`/`0x80100000` 是死地址；`system.violation` 里 20 条 `input port lack of connection` 与此完全吻合。
- 缺 `Concat_0 → f2p_irq` 汇聚（本工程暂不用中断，可不补）。
- `AXI_GPIO_0` 参数被改成 4 位纯输出（`AL_GPIO_WD=4`/`IN_OUT_USE=0`/`AL_INTR_ENABLE=0`/`AL_AXIS_ADDR_WD=9`），官方为 1 位双向+中断。**`AL_GPIO_WD=4` 不能动**——它驱动顶层 `O_code_driver[3:0]`（W9/W10/Y11/W11），改了 `fpga_pin.adc` 也要跟着改。

### 12.5 已排除的假设（都实测核对过）

| 假设 | 排除依据 |
|---|---|
| `Fclk_Init()` 本身有问题 | 与两份出图存档（`GetStabilityPS(base-fdma_en)` / `mipiHDMIbySD`）**逐行相同** |
| PS 侧访问死地址 | PS 代码对 `0x80000000`/`0x80100000` **零访问**（`AXI_GPIO_test.c` 零调用点） |
| FD 侧 FCLK 分频与 PL 不一致 | `soc_plat.c:1396-1404` 的 `div_fclk0=0x01`(÷2→199.98M)、`div_fclk1=0x07`(÷8→49.995M) 与 PL 侧 divisor 2/8 **一致** |
| PS GPIO / UART / CRG 串口时钟 | 上一轮已修，且与官方一致 |
| `Processor_System_Reset_0` 没接输出导致复位链断 | 生成 RTL 显示其 5 个输出（`soc_reset`/`bus_reset`/`peripheral_reset`/`interconnect_aresetn`/`peripheral_aresetn`）**本来就全空接**，`aresetn` 由 `p2f_rst0_n` 直接供给，与官方同构 → 无关 |

### 12.6 修复方案（三组改动，已全部落盘）

**修复 A：把 GP0 主口并入 AXI 域**（`Design.xml` 的 `adHocConnection`）

```
p2f_clk0 (199.98 MHz):  p2f_clk0, slave_hp0_axi_aclk, uiFDMA_0.M_AXI_ACLK, Processor_System_Reset_0.clk
p2f_clk1 ( 49.995 MHz): p2f_clk1, master_gp0_axi_aclk ★新增, AXI_Matrix_0.aclk,
                        AXI_GPIO_0/1.s_axi_aclk, AXI_Protocol_Converter_0/1/2.aclk, axi_lite_pwm_0.s_axi_aclk
```

**修复 B：`AXI_Matrix_0` 参数对齐官方/PSPWM**（6 项，per-DS 字段本来就是对的，只改这 6 个）

| 参数 | 修复前 | 修复后 | 官方/PSPWM |
|---|---|---|---|
| `AL_AXI_ID_WIDTH` | 2 | **13** | 13 |
| `AL_AXI_ID_WIDTH_USER` | 1 | **12** | 12 |
| `AL_CONNECTIVITY_MODE` | 1 | **0** | 0 |
| `conectivity_type` | Multi-Data(SAMD) | **Shared-Data(SASD)** | Shared-Data(SASD) |
| `AL_US_AXI_THREAD_ID_WIDTH` | `32'h00000001` | **`32'h0000000C`** | `32'h0000000C` |
| `us0_thread_id_width` | 1 | **12** | 12 |

> `AL_DS_NUM` 保持 **3**（本工程比官方多一路 PWM）。已核对 `AL_DS_AXI_BASE_ADDR` / `AL_DS_AXI_ADDR_WIDTH` / `AL_AXI_*_CONNECTIVITY` / `AL_DS_AXI_*_ISSUING` 的逐 DS 编码规则（每 DS 一个 32-bit word，基址 word 高 32 位、位宽 word = 0x0C），**本工程这组字段本来就与 PSPWM 一致，无需改**。

**修复 C：补齐 DS0/DS1 接线**（对齐官方）

- 从官方 DI **原样移植 34 条信号级连线**（`AXI_Protocol_Converter_0 ↔ AXI_GPIO_0` 17 条、`_1 ↔ _1` 17 条）。DI 里 `adHocConnections` 才是权威（`interconnections` 只是 GUI 汇总视图），必须补信号级。
- `AXI_GPIO_0/1` 的 `AL_AXIS_ADDR_WD`：**9 → 32**（与矩阵 32 位地址 / 转换器 32 位地址对齐，否则接口位宽不匹配）。
- 补 2 条总线级 `interconnection`：`Converter_0.DS_AXI → AXI_GPIO_0.S_AXI_Lite`、`Converter_1.DS_AXI → AXI_GPIO_1.S_AXI_Lite`。
- **保持不动**：`AXI_GPIO_0` 的 `AL_GPIO_WD=4`（`code_driver[3:0]` 靠它，`fpga_pin.adc` 不用动）、`IN_OUT_USE`、`AL_INTR_ENABLE`。

### 12.7 决策记录：为什么不把 AXI 链迁到 200 MHz

两种做法都能让 AXI 同域，本工程选了**把 GP0 主口降到 50 MHz**，理由三条：

| 维度 | 迁 AXI 链到 200MHz | **迁 GP0 主口到 50MHz（本工程采用）** |
|---|---|---|
| 时序风险 | `p2f_clk0` 已有 **HWNS −2.322 ns** 的 hold 违例，再塞进矩阵+3 转换器+2 GPIO，setup 极可能崩 | `p2f_clk1` 现状 **全绿**（SWNS 0.324 / HWNS 0.054），零新增风险 |
| PS 侧改动 | PWM 频率公式 49.995MHz → 199.98MHz，`ARR` 9999 → 39999，改 3 处 | **零改动**，频率常量 `49995000.0` 继续成立 |
| 与已跑通基线的同构度 | 未验证 | **与 PSPWM 逐位同构**（AXI 链 49.995MHz + GP0 同域） |

> 官方例程的 `p2f_clk0` 本来就是 49.995 MHz，MainProject 只是**编号相反**（p2f_clk0=199.98 是 FDMA 图像通路要的）。本工程把 GP0 主口挪到 `p2f_clk1`，等价于官方拓扑；FDMA/HP0/uidbuf 图像通路**完全没动**。

### 12.8 本轮改动文件清单

| 文件 | 改动 | 备份 |
|---|---|---|
| `soc_prj/uisrc/01_rtl/system/Design.xml` | 修复 A + B + C（时钟网 2 处、矩阵参数 6 项、GPIO 参数 2 项、新增 34 条 adHoc + 2 条 interconnection） | `Design.xml.bak-fixaxi-20261031` |
| `ip_repo/axi_lite_pwm_1.0/axi_lite_pwm_files/RTL/axi_lite_pwm.v` | 时钟注释块重写（原"警告"改为"已对齐 + 故障机理"） | 同目录 `Component.xml.bak-20261031` 之外未另存 |
| `soc_prj/uisrc/01_rtl/axi_lite_pwm/axi_lite_pwm.v` | 同上（两份保持逐字节一致） | `.bak-20261029` 为更早版本 |
| `soc_sdk/fdma_en/main.c` | 仅 VERSION 失败时的提示文案（指向"时钟域"这一新的怀疑点） | — |

### 12.9 下一步（按顺序，缺一步结论就不成立）

1. **TD 重新 generate**（必须）：矩阵 ID 宽度、连接模式、GPIO 地址位宽都变了，IP wrapper 与 `hdl/system.v` 会重生成。
   - 验收：`uisrc/01_rtl/system/hdl/system.v` 里应出现 `assign w_port__AXI_Protocol_Converter_2__us_axi_arid = w_net__AXI_Matrix_0__ds2_arid ;`（**不再有 `{10'b0,...}` 拼接**），且 `w_port__AXI_Matrix_0__us0_arid` 为 `[11:0]`。
   - 验收：`system.violation` 里 AXI_GPIO_0/1 的 `S_AXI_Lite` 未连接告警应**清零**。
2. **TD 综合 + 布线**，读 `soc_prj_Runs/phy_1/final_timing.rpt`：
   - `p2f_clk1`（50 MHz）应保持全绿；`p2f_clk0`（200 MHz）的既有 hold 违例（HWNS −2.322 ns）不应恶化。
3. **FD 全量重编**：先确认 `grep -c "^#define HAVE_" soc_plat.h` = **15**，再 `DOWNLOAD=ddr` + `Run Platform Init` + `Program FPGA`。
4. **上板四通道验收**（互不依赖）：

| 通道 | 判据 | 说明 |
|---|---|---|
| LED5（MIO51） | 短闪 3 下 → 常亮 | PS 活着、定时器在走 |
| 串口 | `[1] VERSION = 0x00010000 (expect 0x00010000) OK` | AXI 读通路打通 |
| 串口 | `[2] self-test OK (code 0)` + `STATUS = 0x00000000` | AXI 写通路 + 影子寄存器 |
| **LED3（J15）** | **缓慢呼吸** | PWM 输出，≈4999.5 Hz 载波 |
| HDMI | 画面照常 | 图像通路未被本次改动影响 |

> 若 VERSION 仍读不到：此时只剩三种可能——① 位流没重新下载 ② generate 没跑 ③ DI 里 `master_gp0_axi_aclk` 没真落到 `p2f_clk1`。前两者自己查，第三者回 `Design.xml` 对照 §12.6 修复 A。


### 12.10 踩坑补记：**只改 `Design.xml` 的参数快照不生效**（2026-10-31 第一次 generate 后追加）

按 §12.6 改完 `system/Design.xml` 后第一次 generate，结果**只修好了一半**：

| 修复项 | 第一次 generate 后 | 判定 |
|---|---|---|
| **A 时钟归域** | `master_gp0_axi_aclk = p2f_clk1` | ✅ **已生效** |
| **C 补齐 DS0/DS1 接线** | `system.violation` 的 warn 从 40 → 6（34 条 `S_AXI_Lite` 未连接告警整段消失） | ✅ **已生效** |
| **B 矩阵参数** | `us0_arid` 仍是 `[0:0]`、`ds2_arid` 仍是 `[1:0]`、转换器仍 `{10'b0,...}` 拼接，4 条 `AXI ID port width inconsistency` error **原样还在** | ❌ **没生效** |

**根因**：TD 里 IP 实例的参数有**三个副本**，而 `Design.xml` 只是给 GUI 看的快照，**不是生成器的输入**：

| 文件 | 角色 | 谁读它 |
|---|---|---|
| `system/Design.xml` | GUI 显示用的参数快照 | DI 画布 |
| **`ip/<inst>/.params_<inst>.txt`** | **IP 生成器的真值源**，格式 `名称 : 值 : 类型(U/G) : En/Dis : 范围下限 : 范围上限`，`U`=用户可改、`G`=由 U 推导 | IP 生成器 |
| `ip/<inst>/.m_params_<inst>.txt` | 生成器输入快照，三列 `名称; 显示宽度; 值` | IP 生成器 |
| `ip/<inst>/Design.xml` | IP 实例自身的参数记录 | 打包/重生成 |

**推论链（本轮实测确认）**：generate 时 TD 用 `.params` 重建 `system/Design.xml` 并重新生成 IP —— 第一次 generate 后，主 DI 的 6 个参数**被回退成 `.params` 的旧值**（2/1/1/SAMD/0x01/1），与 `.params` 完全一致。故修法必须是**改 `.params`（真值源）**，只改 Design.xml 一定被覆盖。

**矩阵里只有 2 个「真·用户参数」**，其余全是推导量：

| 参数 | 类型 | 改什么 |
|---|---|---|
| `AL_AXI_ID_WIDTH_USER` | **U** | 1 → **12**（= PS GP0 的 12 bit ID） |
| `conectivity_type` | **U** | Multi-Data(SAMD) → **Shared-Data(SASD)** |
| `AL_AXI_ID_WIDTH` | G | 由上推导 → 13（已显式写死为 13，双保险） |
| `AL_CONNECTIVITY_MODE` | G | 由上推导 → 0（已显式写死） |
| `AL_US_AXI_THREAD_ID_WIDTH` | G | 由上推导 → `32'h0000000C`（已显式写死） |
| `us0_thread_id_width` | U/G | 1 → **12**（官方为 U 型，范围 0..12，已按官方对齐） |

**处置**：四处（主 DI `Design.xml` / IP `Design.xml` / `.params` / `.m_params`）**全部同步为新值**，两边一致，TD 无论从哪边取参数都得到同一结果。备份后缀 `.bak-fixid-20261031` / `.bak-fixid2-20261031`。

> ⚠ **行尾坑**：`.params` / `.m_params` / IP `Design.xml` 是 **CRLF**，主 DI `Design.xml` 是 **LF**。用 Python 读写时必须走**二进制模式**（`open(f,'rb')` / `open(f,'wb')`）—— 默认文本读会把 CRLF 统一成 `\r\n`→`\n`，写回时行尾被静默改掉。本轮第一次改 `.params` 就踩了这个坑（1316 个 CRLF 变成 LF），已用 CRLF 备份为基底重建修回。

**验收判据（第二次 generate 后）**：

```
cd D:/FPGAproject/AnLuRun/MainProject/soc_prj/uisrc/01_rtl/system
grep -c "^\[error" system.violation      # 期望 2（原 6）
grep -n "us0_arid\|ds2_arid" hdl/system.v | head   # 期望 [11:0] / [12:0]
grep -n "AL_AXI_ID_WIDTH\|AL_CONNECTIVITY_MODE" ip/system_AXI_Matrix_0/system_AXI_Matrix_0.v
```


---

## 十三、第五轮：PL 综合验收（2026-10-31 18:40–18:56）

### 13.1 综合结果

| 项 | 值 |
|---|---|
| 耗时 | **9m36s**（place 5m32s / route 2m56s / phys_opt 22s / fix_hold 18s / bitgen 23s） |
| 位流 | `soc_prj_Runs/best_result/soc_prj.bit`（4.05 MB，18:56） |
| 时序报告 | `soc_prj_Runs/phy_1/final_timing.rpt`（2.24 MB，18:55） |
| 综合网表 | `soc_prj_Runs/syn_1/soc_prj_gate.db`（17.1 MB） |

### 13.2 ★ 核心判据：AXI 时钟域全绿（本次修复的目标）

| 路径组 | SWNS | 违例 | HWNS | 违例 | 判定 |
|---|---|---|---|---|---|
| `p2f_clk1 → p2f_clk1`（50 MHz AXI 域） | **13.013 ns** | **0** | **0.041 ns** | **0** | ✅ |
| `p2f_clk1 → GEN_PL_GP0S`（PS GP0 主口发出） | **14.691 ns** | **0** | 0.227 ns | 0 | ✅ |
| `GEN_PL_GP0S → p2f_clk1`（AXI 应答回 PS） | **13.714 ns** | **0** | 0.744 ns | 0 | ✅ |

> **双向跨时钟域零违例** —— §12.2 的跨时钟域根因已被时序报告**独立证实修复**。这三条路径覆盖了 GP0 主口 ↔ 矩阵 ↔ 三个协议转换器 ↔ AXI_GPIO ×2 ↔ `axi_lite_pwm` 的完整链路。

PWM 实例化确认（未被优化掉）：

```
| system_axi_lite_pwm_0_Inst | axi_lite_pwm_system_axi_lite_pwm_0 | 442 LUT | 192 FF | 862 |
|   u_pwm0 | axi_lite_pwm_channel_system_axi_lite_pwm_0 | 81 LUT | 64 FF | 161 |
|   u_pwm1 | axi_lite_pwm_channel_system_axi_lite_pwm_0 | 81 LUT | 64 FF | 161 |
|   u_pwm2 | axi_lite_pwm_channel_system_axi_lite_pwm_0 | 81 LUT | 64 FF | 161 |
```

### 13.3 剩余 2 组违例的定性（均与本次改造无关）

**① 200 MHz 域 hold −2.315 ns（11 端点）**

路径：`u_uidbuf/rdbuf_fifo/rd_to_wr_cross_inst/primary_addr_gray_reg_reg[10]_syn_2.clk` → `primary_addr_gray_sync_reg[5]_syn_2.imb`

- 源时钟 `pclkx1`（50 MHz）→ 目的时钟 `p2f_clk0`（200 MHz），**反向跨域**
- 数据路径延迟仅 0.425 ns，**Clock Skew 2.652 ns** 是元凶
- 性质：FDMA 缓冲的**异步 FIFO 格雷码同步器**，属图像链路固有设计
- 为何官方 `mymipi_hdmi2` 没有：它 `p2f_clk0` 分频为 ÷8（50 MHz），MainProject 是 ÷2（200 MHz），跨域斜率才暴露出来

**② HP0 setup −0.537 ns（19 端点）**

路径：`u_uidbuf/wdbuf_fifo/ram_inst/ramread0_syn_67.clkb` → `slave_hp0_axi_wdata[49]`

延迟构成：

```
p2f_clk0(200MHz) → Reset IP 自动门控链 4.058 ns → 770 扇出 → u_uidbuf 写 FIFO
                  → ERAM clk2q 1.700 → slave_hp0_axi_wdata[49] → HP0 采样
```

- 元凶是 `Processor_System_Reset_0` 的 `clk` 接了 **p2f_clk0（200 MHz）**，其内部 `clk_auto_soc_output_clock` 产生 **770 扇出**的门控时钟网去驱动 FDMA 写 FIFO
- **官方 `14_axi_gpio_pl_intr` 把 `Reset.clk` 接 `p2f_clk1`（50 MHz）** —— 本工程接的是 200 MHz 那一路
- **但是既有基线，不是本次引入**：前置工程 `mymipi_hdmi2` 同一组为 **SWNS −0.484 ns / 20 端点**，本工程 **−0.537 ns / 19 端点**，**端点反而少 1 个**

### 13.4 顺带查明：§12 剩下的 2 条 `port lack of driver` 是虚报

`system.violation` 报的 `Processor_System_Reset_0::aux_rst` / `::system_rst` 无驱动，在生成的 RTL 里实际是：

```verilog
, .aux_rst(1'b0)
, .system_rst(1'b0)
```

TD 生成器已在 RTL 层给常量，**功能无影响**。官方同样空接（官方 violation 里这两条是 warn）。

### 13.5 剩余 5 条 `error` 的官方对照结论

| 项 | 官方 `14_axi_gpio_pl_intr` | 本工程 | 判定 |
|---|---|---|---|
| 矩阵 `AL_AXI_ID_WIDTH` | 13 | 13 | ✅ |
| 矩阵 `AL_US_AXI_THREAD_ID_WIDTH` | `32'h0000000C` | `32'h0000000C` | ✅ |
| 矩阵 `AL_CONNECTIVITY_MODE` | 0 (SASD) | 0 (SASD) | ✅ |
| 转换器 `AL_AXI_ID_WIDTH` | **12** | **12** | ✅ |
| RTL 位宽 | 矩阵 DS`[12:0]` ↔ 转换器 US`[11:0]` | **完全相同** | ✅ 同型 |
| `master_gp0_axi_aclk` | 50 MHz local（fanout 0） | p2f_clk1 49.995 MHz | ✅ 同构 |

> 官方 `system.violation` 是 **2025-07-22 的旧产物**，用旧版检查器生成，所以看不到这 3 条 `AXI ID port width inconsistency` —— **不是官方没有，而是官方工程从未用新版检查器重新 generate 过**。且官方 RTL L787 就是 `assign w_port__AXI_Protocol_Converter_0__us_axi_arid = w_net__AXI_Matrix_0__ds0_arid ;`（13 bit → 12 bit 隐式截断），与本工程逐位一致。
>
> **硬实证**：16:44–17:00 那次综合在 `error=6` 的状态下**完整跑通** syn→place→route→bitgen 全套产物 ⇒ error 级别不阻断综合流程。

### 13.6 地址解码交叉验证（位序实证）

| DS | 向量位段 | 解出基址 | 对应从端 | `address.xml` | PS 侧常量 | 判定 |
|---|---|---|---|---|---|---|
| DS0 | `[63:0]` | 0x80000000 | `AXI_GPIO_0` | 0x80000000 | — | ✅ |
| DS1 | `[127:64]` | 0x80100000 | `AXI_GPIO_1` | 0x80100000 | — | ✅ |
| DS2 | `[191:128]` | 0x80200000 | **`axi_lite_pwm_0`** | 0x80200000 | `AXI_PWM_BASE=0x80200000` | ✅ |

窗口宽度 `AL_DS_AXI_ADDR_WIDTH=0x0C`（12）→ 4 KB，与 `highAddress 0x…0FFF` 一致。位序约定（index 0 在 LSB）由官方 `128'h…80100000…80000000` 反证：官方 DS0=0x80000000 同样落在低位段。

### 13.7 ★ 更正 §11.4 关于 UART 时钟的错误结论

§11.4 与早期记忆都称「MainProject 的 `0xF8801028` 写的是 `0x01010101`（官方正确值）」。**实测为 `0x00000008`，但这才是对的** —— 判据不在「与官方字面一致」，而在 **FD 平台源头配置自洽**：

| 证据 | 值 |
|---|---|
| `platform/Design.xml` → `IO_400_Actual` | **399.96 MHz** |
| `platform/Design.xml` → `UART0_Dot_Actual_Inside_Frequency` | **49.995 MHz** |
| 生成的 `soc_plat.c` → `0xF8801028` | `0x00000008`（**÷8**） |
| `399.96 ÷ 8` | **49.995 MHz** ✅ 三者精确自洽 |
| `soc_plat.h` → `UART_CLOCK` | **49995000** ✅ |

**为什么官方写 `0x01010101` 不能当参照**：官方 `08_ps_uart_intr` 的 `UART0_Available = 0` —— **它根本没用 PS UART**，那个 `0x01010101` 是给其他外设的默认值。全库统计 18 处 `0x01010101` / 13 处 `0x00000008`，取值由各自工程的 IO400 实际频率决定，**不存在「哪个字面正确」的问题**。

> ⚠ **PSPWM 的 UART 其实是不对的**：`div_fclk0 = 0x07`（÷8）→ `p2f_clk0 = 50 MHz`，却配 `0x00000008`（÷8）→ UART 实际 6.25 MHz，而 `UART_CLOCK` 仍写 49995000。它当时「能跑通」只是因为没真正验证串口输出。**MainProject 不要照抄 PSPWM 的这一项**。

**结论：MainProject 的 UART 配置正确，一个字节都不用改。**

### 13.8 顺带更正：`HAVE_` 驱动数是 14 不是 15

`grep -c "^#define HAVE_" soc_plat.h` = **14**，与官方 `15_axi_uart` 的 14 项**逐项完全一致**。此前记录的「期望 15」是数错了。

### 13.9 本轮新增/修改文件

| 文件 | 变化 |
|---|---|
| `soc_prj/soc_prj_Runs/**` | TD 综合产物（syn_1 / phy_1 / best_result），非手改 |
| 本文 | 新增 §13 |

### 13.10 下一步

1. **FD 侧全量重编** `soc_sdk/fdma_en` → `DOWNLOAD=ddr`（BOOT.bin 走 SD 卡）→ **Program FPGA**（`soc_prj.bit`）
2. **上板四通道验收**

| 通道 | 期望 |
|---|---|
| LED5（MIO51） | 短闪 3 下 → 常亮 |
| 串口 | `[1] VERSION = 0x00010000 OK` |
| 串口 | `[2] self-test OK (code 0)` |
| **LED3（J15）** | **缓慢呼吸** ← 本次新增主目标 |
| HDMI | 画面照常 |

> 编译前确认 `soc_plat.h` 的 `HAVE_` 仍为 **14 项**；**不要动 `soc_plat.c` 的 `0xF8801028`**（§13.7）。
