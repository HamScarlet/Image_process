# MainProject · DI 改造逐步操作单（照着做，一步一判据）

> **这份是动手用的**：左边是动作，右边是判据。判据不满足就停下，别往下做。
> 配套总方案：`MainProject-加PWM呼吸灯改造方案.md`
> 工程：`D:\FPGAproject\AnLuRun\MainProject\soc_prj`

---

## 零、先记住三个"与官方文档不同"的地方

官方那篇《PL侧AXI_test读写验证》写的是 **PSPWM 工程**的配置，MainProject 的时钟规划不一样，照抄会踩坑。

| 项 | 官方 PSPWM | **MainProject 实测** | 你该怎么填 |
|---|---|---|---|
| AXI 链时钟 | `p2f_clk0` | **`p2f_clk1`**（`p2f_clk0` 在本工程是 199.98 MHz） | `s_axi_aclk` 接 **`p2f_clk1`** |
| `p2f_clk1` 频率 | — | **49.995 MHz**（`p2f_clk1_1st_Divisor = 8`） | PWM 公式不变：`f = 49.995e6/((PSC+1)(ARR+1))`，ARR=9999 → **4.9995 kHz** |
| 矩阵从端数 | 要从 3 加到 4 | **已经是 3，且 `DS2_BASEADDR0 = 0x80200000` 已经填对了** | **矩阵一个参数都不用动** |

> ✅ 由此推出：**PS 侧代码（`TIM_PWM.h` 里的 ARR=9999、舵机 ARR=999899）不用改**，频率公式照旧。

### 当前画布实况（已从 `Design.xml` + `hdl/system.v` 逐条核实）

| 实例 | 现状 | 要做什么 |
|---|---|---|
| `AXI_Matrix_0` | `AL_DS_NUM=3`；DS0/1/2 = `0x80000000`/`0x80100000`/`0x80200000`，宽度 12（4KB）；`AL_DS_AXI_BASE_ADDR` 三段打包正确 | **不动** |
| `AXI_Protocol_Converter_0` | 接矩阵 DS0 → 下游接 `AXI_GPIO_0`；`aclk = p2f_clk1` | 不动 |
| `AXI_Protocol_Converter_1` | 接矩阵 DS1 → 下游接 `AXI_GPIO_1`；`aclk = p2f_clk1` | 不动 |
| `AXI_Protocol_Converter_2` | 接矩阵 DS2 ✅；`aclk = p2f_clk1` ✅；`aresetn = p2f_rst0_n` ✅；**下游 DS 侧 20 根线全部空接** | **把 axi_lite_pwm 接上去** |
| `PWM_0` | 挂 `../PWM.v`（`use_rtl`），输入来自 AXI_GPIO_1 | **删掉** |
| 导出端口 | `pwm_clk`(in) / `pwm_out1`(out) / `rst_n`(in) | **删掉** |
| `Processor_System_Reset_0` | `aux_rst`/`system_rst` 接常量 0（2 条 error） | **不要动**（既有状态，图像链路本来就这样且能出图；改它反而动到图像的复位行为） |

---

## 第 1 步 · 删掉旧的 `PWM_0`

1. 打开 TD → 打开工程 `D:\FPGAproject\AnLuRun\MainProject\soc_prj\soc_prj.al`
2. 进入 **Design Integrator**（双击 `system.xml` 或工具栏进 DI）
3. 在画布上找到标着 **`PWM`** 的方块（实例名 `PWM_0`，`use_rtl` 类型，`ipPath = ../PWM.v`）

> ⚠️ 认准特征：它的输入端叫 `DUTY_VALUE` / `RELOAD_VALUE`，**没有** `S_AXI` 粗蓝接口。真 AXI 从端是一根粗蓝线连到转换器上的。

4. 点选它 → 按 **Delete**（或右键 → Delete）

**判据**：`PWM_0` 方块消失；`AXI_GPIO_1` 的两个输出（原本接 `DUTY_VALUE`/`RELOAD_VALUE`）变成悬空——**这是正常的，AXI_GPIO_1 保留不动，它只是空转**。

**删不掉 / 删不掉引脚怎么办**：双击方块开配置窗，顶部有 `Component Name` 与端口列表；也可以在画布上右键方块看有没有 `Delete Instance`。若 DI 报错说实例已生成过，先在左侧 `Design` 树里删。

---

## 第 2 步 · 删掉三个导出端口

DI 里「导出端口」= 顶层 `system` 模块对外的引脚。你现在的顶层实例写的是 `.pwm_out / .motor_dir / .motor_enable`，所以这次要导出的正是这三个；旧的 `pwm_out1` / `pwm_clk` / `rst_n` 要删掉。

1. 在画布上找**画布边缘的端口方块**（不是 IP 端口，是 design port）：
   - `pwm_out1`（输出，连着刚删掉的 PWM）
   - `pwm_clk`（输入，来自 PLL `clk4_out`）
   - `rst_n`（输入）
2. 逐个点选 → Delete

**判据**：画布边缘只剩原来那批端口（`I_fdma_*` / `p2f_clk0` / `p2f_rst0_n` / `O_fdma_*` / `code_driver[3:0]`），**没有** `pwm_out1` / `pwm_clk` / `rst_n`。

**`rst_n` 删不掉怎么办**：有些版本不允许删顶层端口。留着也行，但**必须在顶层补一根线**（否则 TD 会报 `port not found` 或输入悬空）——先记住这条，第 6 步会用到。

---

## 第 3 步 · 把 `axi_lite_pwm` 加进画布

1. 工具栏点 **IP+**（有的版本叫 `Add IP` / `+`）
2. 分类选 **User IP**（用户自定义），搜 **`axi_lite_pwm`**
3. 双击 `axi_lite_pwm_1.0` 添加

**判据（IP 库刷新问题）**：画布上出现一个新方块，**上面必须能看到**：
- 一根粗的 **bus 接口 `S_AXI`**
- 细线 `s_axi_aclk`、`s_axi_aresetn`
- 输出 `pwm_out[2:0]`、`motor_dir[1:0]`、`motor_enable`

> **搜不到 / 只有光秃秃的方块（连 `S_AXI` 都没有）** → 说明 DI 没读到这个 IP 的总线接口。
> 诊断命令（我来跑，你也可以自己看）：
> ```
> grep -c busInterfaces D:/FPGAproject/AnLuRun/MainProject/ip_repo/axi_lite_pwm_1.0/Component.xml
> ```
> 必须是 **2**（开标签 + 闭标签各一次）。我们这边已经是 2 了，所以大概率只是 **IP 库没刷新**：在 DI 里找 `Refresh` / 重新加载 IP 库，或**重启 TD 再进 DI**。
>
> ⛔ **绝对不要用 mpack 打开并保存这个 IP** —— 保存会整体重写 `Component.xml`，把 `busInterfaces` 抹掉，AXI 线当场消失。

---

## 第 4 步 · 连 3 根线

这是全部工作量的核心，就 3 根。

| # | 从 | 到 | 线型 |
|---|---|---|---|
| ① | `AXI_Protocol_Converter_2` 的 **`DS_AXI`** | `axi_lite_pwm` 的 **`S_AXI`** | **粗蓝线**（bus） |
| ② | `ARM_Processor_System_0` 的 **`p2f_clk1`** | `axi_lite_pwm` 的 **`s_axi_aclk`** | 细线 |
| ③ | `ARM_Processor_System_0` 的 **`p2f_rst0_n`** | `axi_lite_pwm` 的 **`s_axi_aresetn`** | 细线 |

**操作要点**：

- **① 粗蓝线**：从 `Converter_2` 右边那个粗接口 `DS_AXI` 按住拖到 PWM 方块的 `S_AXI`。
  > 转换器 2 现在下游是空的（`DS_AXI` 悬着一个粗口），你是在**填空**，不是拆线。
- **② ③ 细线**：DI 会弹出「是否复用已有网络 `w_net__ARM_Processor_System_0__p2f_clk1`」→ **选「复用 / Use existing」**。
  > 如果源引脚不允许挂第二根线，就**从已有那根线上按住拖出支线**到 PWM 方块。`p2f_clk1` 上已经挂着矩阵和 3 个转换器共 4 根线了，拖支线是正常操作。
- **② 一定要选 `p2f_clk1`，不是 `p2f_clk0`**（`p2f_clk0` 在本工程是 199.98 MHz）。选错 → PWM 不出波，或时序报告爆表。

**判据**：三根线都在，`Converter_2` 的 `DS_AXI` 不再是悬空口；`AXI GPIO_1` 那两根线**保持悬空**（不用管）。

---

## 第 5 步 · 导出三个端口

DI 里把 IP 的输出引脚「提升」为 design port（这样顶层 `system.v` 才能连）。

1. 右键 `axi_lite_pwm` 的 **`pwm_out[2:0]`** → `Export as design port` / `导出为设计端口`
2. 同样导出 **`motor_dir[1:0]`**、**`motor_enable`**
3. 端口名**保持默认**（`pwm_out` / `motor_dir` / `motor_enable`），不要改

**判据**：画布边缘出现 3 个新端口方块，名字分别是 `pwm_out[2:0]`、`motor_dir[1:0]`、`motor_enable`。

> ⚠️ 官方经验：**生成后端口名不要带 `_0` 后缀**。如果你导出时 DI 给了 `pwm_out_0` 这种名字，改掉。
>
> ⚠️ 如果端口名和顶层对不上（顶层写的是 `.pwm_out` / `.motor_dir` / `.motor_enable`），**改顶层那 3 行 + 3 行 assign**，不要改 DI 生成的文件（每次 Generate 都会覆盖）。

---

## 第 6 步 · Generate + 核对

1. DI 里点 **Generate design**（有的版本叫 `Generate Output Products`）

**判据（我可以替你跑，你也可以自己查）**：

```
cd D:/FPGAproject/AnLuRun/MainProject/soc_prj/uisrc/01_rtl/system
grep -E "pwm_out|motor_dir|motor_enable" hdl/system.v | head
```
→ 必须出现 `pwm_out[2:0]`、`motor_dir[1:0]`、`motor_enable` 三个端口，且**顶层 `system.v` 里连的这 3 个名字能对上**。

再看违例：
```
grep -c "^\[error" system.violation
```
→ 期望 **5** 条 error：3 条 `AXI ID port width inconsistency`（既有，官方说无害）+ 2 条 `Processor_System_Reset_0` 复位无驱动（既有，别动）。
→ **如果还剩 `design port lack of connection`（pwm_out / motor_dir / motor_enable），说明第 5 步没做成功**，回上一步。

---

## 第 7 步 · 顶层兜底检查（只在前 6 步全对、但 TD 报端口不匹配时才做）

我改好的 `01_rtl/system.v` 里 `system` 实例是这样连的：

```verilog
  system system_inst (
      ...
      .code_driver  (O_code_driver),
      .pwm_out      (pwm_ch       ),     // ← DI 导出的 pwm_out[2:0]
      .motor_dir    (O_motor_dir  ),     // ← DI 导出的 motor_dir[1:0]
      .motor_enable (O_motor_enable)     // ← DI 导出的 motor_enable
  );
  assign O_pwm_led      = pwm_ch[0];
  assign O_motor_pwm[0] = pwm_ch[1];
  assign O_motor_pwm[1] = pwm_ch[2];
```

- 如果 DI 里的端口名**不是**这三个 → 改这 3 行 `.xxx(...)` 和 3 行 `assign`（共 6 行）。
- 如果 DI 里 `rst_n` **删不掉** → 在实例里补一行 `.rst_n (p2f_rst0_n)`。

---

## 第 8 步 · TD 综合与位流

1. 退出 DI，回到 TD 工程
2. **确认 `uisrc/01_rtl/axi_lite_pwm/axi_lite_pwm.v` 没有被 Add Files 加进编译列表**
   > 它和 DI 生成的 `ip/system_axi_lite_pwm_0/RTL/` 里那份是**同一个模块的两份拷贝**，同时编译必然报 `module already defined`。
   > 我已经核对过 `soc_prj.al`，它**不在**列表里，保持现状即可。
3. **Synthesis** → **Physical Design** → 生成位流

**判据**：
- 综合 0 error，无 `module already defined`
- `phy_1` 报告里 `p2f_clk1` 组正裕量（Slack ≥ 0）
- 记一下 `#slice` 占用（官方 PSPWM 是 3065/52480 = 5.84%，本工程图像链路会高一些）

> ⚠️ `timing.sdc` 里 `create_clock -period 10` 对 49.995 MHz 是 2 倍过约束——**这是官方模板带的既有情况，故意不动**，报告里 `p2f_clk1` 显示 100 MHz 就是这个原因，不是真实频率。

---

## 第 9 步 · FD 编译与下载

1. 打开 FD 工程 `soc_sdk/fdma_en`
2. **全量重编**（Project → Clean，然后 Build）。**不要用增量**
3. 下载：`DOWNLOAD = ddr`，勾 **`Run Platform Init`** + **`Program FPGA`**，加载 `fsbl` + `fdma_en`

**判据**：编译 `exit=0`，**且** `al_log.c.o` / `al_uart_hal.c.o` / `al_chip.c.o` 三个目标文件时间戳一致。

> ⚠️ **SoC 工程 TD 直下不出图，必须走 FD。**
>
> ⚠️ 如果编译报 70+ 个错、全在 `al_mpu.c` / `al_log.c`：**不是你的代码**，是 FD 重新导出 platform 时把 `soc_base/platform/inc/soc_plat.h` 里 15 行 `#define HAVE_*PS_DRIVER` 整块写空了。
> 判据：`grep -c "^#define HAVE_" soc_base/platform/inc/soc_plat.h` 必须是 **15**。补回即可。

---

## 第 10 步 · 上板看灯

**四条独立观察通道，缺一条就说明对应环节没通**：

| 通道 | 现象 | 证明 |
|---|---|---|
| 串口 | `[PWM] VERSION = 65536` | AXI 通路通（读到 `0x00010000`） |
| 串口 | `[PWM] selftest = 0` | 寄存器真的可读可写（不是假 ACK） |
| **LED3（J15）呼吸** | 亮灭渐变 | PL 计数器+比较器+引脚约束都成立 |
| **HDMI 图像照常显示** | 画面正常 | **没破坏原有图像链路（最重要）** |

**排查对照表**：

| VERSION | 呼吸 | 图像 | 结论 | 下一步 |
|---|---|---|---|---|
| 读不到 65536 | 灭 | 正常 | AXI 没通 | 查第 4 步三根线 + 第 3 步 IP 库 + 基址 |
| 65536 | 灭 | 正常 | 寄存器通但没波 | 查 `CTRL[0]` 使能位、`ARR`/`CCR` |
| 65536 | **呼吸** | 正常 | **全通** | ✅ |
| 65536 | 呼吸 | **黑屏** | PL 综合/位流问题 | 不是 PS 的事，回第 8 步 |
| 全灭且串口无输出 | 灭 | 黑屏 | 程序没跑起来 / 位流没下 | 查 FD 下载 |

**分级开关**（`main.c` 顶部，改完重编即可切换）：

| `BRINGUP_STEP` | 行为 | 用途 |
|---|---|---|
| 1 | 只读 `VERSION`，一个字节都不写 | 怀疑 AXI 通路。**此时 5 个 LED 全灭是正确现象**，不是故障 |
| 2 | 加 CCR 写-读回自检 | 怀疑寄存器 |
| 3 | 完整 + 呼吸灯 | 正常跑（当前默认） |

**无串口时的兜底**：FD 调试器 Memory 窗口读 `0x8020000C`，读到 `00010000` 即 AXI 通。
> 注意：该窗口按**大端显示**，你看到 `00010000` 就是 `0x00010000`，不用反转。

---

## 三条禁令（官方实测踩过）

| 禁令 | 原因 |
|---|---|
| ⛔ 不要用 `Ctrl+C/V` 复制 IP 实例 | DI 会解释成「打开已有实例」，底部红字 `Customization changes are not allowed` |
| ⛔ 不要用 mpack 打开并保存 `axi_lite_pwm_1.0` | 会抹掉 `busInterfaces`，AXI 线在 DI 里直接消失（不报错，最难查） |
| ⛔ 不要勾 `Auto Assign` | 会重排既有三个从端的地址窗口，C 代码里写死的 `0x80200000` 当场失效 |

---

*2026-10-31 · 依据 MainProject 实际 `Design.xml` / `hdl/system.v` 逐条核实后编写*
