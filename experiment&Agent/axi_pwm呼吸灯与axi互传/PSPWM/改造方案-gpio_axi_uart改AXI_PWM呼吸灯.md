# 改造方案：官方 gpio_axi_uart 工程 → PS 写占空比的 AXI PWM 呼吸灯

> **目标工程**：`D:\FPGAproject\AnLuRun\PSPWM`
> **当前工程性质**：TD 2026.1 的 BD/IPXACT 工程（官方 AXI GPIO + 中断 + UART 例程）
> **本阶段目标**：PS 侧通过 AXI 写入占空比，PL 侧输出 PWM，驱动板载 LED 做呼吸
> **终极目标**：同一套 PWM 驱动直流电机（本期只验证 AXI-PWM 通路可行）
> **状态**：仅规划，未改动工程

---

## 一、现状盘点（均已实测核对）

| 项目 | 实际值 | 出处 |
|---|---|---|
| 工程架构 | **Block Design（IPXACT）**，`system/hdl/system.v` 由 Design Integrator 生成 | `soc_prj.al` 只登记 4 个源文件 |
| BD 内 IP | ARM_Processor_System ×1、AXI_Matrix ×1、AXI_Protocol_Converter ×2、AXI_GPIO ×2、Concat、Constant、Processor_System_Reset | `system/Design.xml` |
| AXI 主从规模 | **1 主 2 从**（`AL_US_NUM=1`、`AL_DS_NUM=2`） | `Design.xml` |
| 地址映射 | GP0 基址 `0x80000000`；PC0 → `0x80000000~0x80000FFF`（GPIO_0）；PC1 → `0x80100000~0x80100FFF`（GPIO_1） | `system.address.xml` |
| 外设时钟 | **`p2f_clk0` = 49.995 MHz**（IO PLL ÷ 8） | `Design.xml`：`p2f_clk0_1st_Divisor=8`、`Actual_IO_Frequency=49.995` |
| 当前引脚 | `GPIO → K14`、`GPIO_1 → J14`，均 LVCMOS33 | `04_pin/fpga_pin.adc` |
| 时序约束 | `timing.sdc` 把 `p2f_clk0` 按 **10 ns（100 MHz）** 约束，实际周期 20.002 ns（过约束，偏保守但安全） | `04_pin/timing.sdc` |
| TD 是否自带 PWM IP | **没有**（全盘 `*pwm*` 无命中） | `D:\exe\Anlu\TD` |
| TD 是否支持用户 IP | **支持**，`mpack.exe`（Module Packager）+ `design_integrator.exe` | `TD\bin`、`SWUG507`、`SWUG501` |
| 应用入口 | `soc_sdk/axi_intr/main.c`，当前是 AXI GPIO 双边沿中断测例 | 已读全文 |
| 延时 API | `AlSys_MDelay(AL_U64 Msec)` 存在 | `inc/al_systimer.h:27` |

### 参考素材（`PSPWM/refer/`）

| 文件 | 用途 | 可用性判断 |
|---|---|---|
| `axi_lite_pwm.v` | 完整 AXI4-Lite 三通道 PWM，影子寄存器 + UPDATE 提交 | ✅ **本方案基础**，需修 3 处 |
| `Car_control/TIM_PWM.c/.h` | 寄存器访问封装 + 呼吸循环 | ⚠️ 半成品，需修 3 个 bug |
| `PWM.v` | 单路 PWM 草稿 | ❌ **不要用**：`prescaler_cnt = ...` 阻塞赋值、复位判据写反、`cnt <= DUTY_VALUE` 逻辑错 |
| `system.v` | 另一工程的手写顶层，已含 `O_motor_pwm[2:0]` | 参考价值：证明该 RTL 能进 BD |

---

## 二、三项已定决策

| 决策 | 结论 | 理由 |
|---|---|---|
| **① AXI 从端数量** | AXI_Matrix 的 `AL_DS_NUM` **2 → 3**，新增一路 `AXI_Protocol_Converter` + PWM IP，地址 **`0x80200000`** | 保留官方两路 GPIO；且与 `TIM_PWM.h` 里已写死的 `0x80200000` 完全一致，C 代码地址零改动 |
| **② 呼吸灯引脚** | 板载 **LED1 = `T19`**（BANK32，`VCC_ADJ1` 默认 3V3） | 最直观、无需外接；若呼吸方向相反，把输出取反即可 |
| **③ 通道使能语义** | 每通道仅由自己的 `CTRL[n]` 使能；**`CTRL[3]` 只作电机驱动使能**，单独输出 `motor_enable`，不再门控 PWM | 去掉 PS 侧"必须同时置 bit3 才出波"的隐式依赖，避免"配好了却没波形"的坑 |

---

## 三、总路线

> **核心判断：必须走「mpack 封 IP → IP Catalog → DI 拖入 → bus 连线 → Address Editor」。**
> DI 虽支持 `Add module` 直接导入 RTL（文档 3.9 节），但那样模块没有 bus 定义，AXI 只能一根一根连线（40+ 根），且**无法进入 Address Editor 分配地址**，因此不可行。

| 阶段 | 内容 | 执行者 |
|---|---|---|
| **P0** | 修改 `axi_lite_pwm.v` 四处（原三处 + mpack 位宽解析补丁） | ✅ 已完成 |
| **P1** | mpack 封装成 IP 并注册到 IP Catalog | **你在 GUI 操作** |
| **P2** | DI 中扩矩阵、加 Converter、加 PWM、连线、导端口、配地址 | **你在 GUI 操作** |
| **P3** | `system_top.v` + `fpga_pin.adc` + C 代码 | 我 |
| **P4** | TD 综合布线出位流 → FD 下载 → 分步验证 | 你操作，我排障 |

---

## 四、P0：RTL 四处修改

### ① 地址位宽 9 → 32（**必须**，否则连不上矩阵）

原：`parameter integer C_S_AXI_ADDR_WIDTH = 9`
改：`parameter integer C_S_AXI_ADDR_WIDTH = 32`

> 依据：本工程 `AXI_GPIO_0` 的 `s_axi_awaddr` 实测为 `[31:0]`（`system.v:458`），协议转换器下游也是 32 位。9 位接 32 位在 bus 连线时位宽不匹配。
> 内部解码只用 `s_axi_awaddr[7:0]` / `s_axi_araddr[7:0]`，加宽**不影响任何功能**。

### ② 通道使能去掉 `& ctrl_reg[3]`（**必须**，否则 PWM0/PWM1 永不出波）

```diff
  axi_lite_pwm_channel #(.RESET_ARR(RESET_MOTOR_ARR)) u_pwm0 (
-     .clk(s_axi_aclk), .rst_n(s_axi_aresetn), .enable(ctrl_reg[0] & ctrl_reg[3]),
+     .clk(s_axi_aclk), .rst_n(s_axi_aresetn), .enable(ctrl_reg[0]),
  ...
  axi_lite_pwm_channel #(.RESET_ARR(RESET_MOTOR_ARR)) u_pwm1 (
-     .clk(s_axi_aclk), .rst_n(s_axi_aresetn), .enable(ctrl_reg[1] & ctrl_reg[3]),
+     .clk(s_axi_aclk), .rst_n(s_axi_aresetn), .enable(ctrl_reg[1]),
```

> `assign motor_enable = ctrl_reg[3];` **保持不变**——它就是要给电机驱动芯片 EN 脚的独立信号。

### ③ 默认 ARR 9998 → 9999（一致性）

`RESET_MOTOR_ARR = 32'd9998` → `32'd9999`；`axi_lite_pwm_channel` 的 `RESET_ARR = 32'd9998` → `32'd9999`。

> 与 C 侧 `TIM_PWM_Init()` 写入的 9999 对齐，避免调试时读回值与预期差 1 而误判。初始化会被覆盖，不改也能跑。

### ④ 地址端口位宽改为字面量 `[31:0]`（**2026-10-29 追加，mpack 实测发现**）

①号修改只把**参数默认值**改成 32，端口仍写成 `[C_S_AXI_ADDR_WIDTH-1:0]`。mpack 无法展开带参数的位宽表达式，实测 `Ports` 页把 `s_axi_awaddr` / `s_axi_araddr` 报告成 **1 位**（同屏 `s_axi_wdata` 因写字面量 `[31:0]` 正确显示 32，可作对照）。该宽度会写进 `Component.xml`，DI 按它生成连线，1 位接不上 32 位矩阵。

```diff
- input  wire [C_S_AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,
+ input  wire [31:0]                    s_axi_awaddr,
- input  wire [C_S_AXI_ADDR_WIDTH-1:0]  s_axi_araddr,
+ input  wire [31:0]                    s_axi_araddr,
- wire [C_S_AXI_ADDR_WIDTH-1:0] write_addr;
+ wire [31:0] write_addr;
- reg  [C_S_AXI_ADDR_WIDTH-1:0] awaddr_hold;
+ reg  [31:0] awaddr_hold;
- awaddr_hold <= {C_S_AXI_ADDR_WIDTH{1'b0}};
+ awaddr_hold <= 32'd0;
```

> `C_S_AXI_ADDR_WIDTH` 参数**保留但不参与任何范围表达式**（仅供 IP-XACT/DI 记账），已在 RTL 注释里写明不得引入端口声明。
> 原件备份：`axi_lite_pwm.v.bak-20261029`（md5 `c0e2b4952c5e985e323a0b345c8fd061`）；改后 md5 `cc59a43f94d6cd4fafab8b50635c5d2a`。

### 落盘位置

```
soc_prj/uisrc/03_ip/axi_lite_pwm/axi_lite_pwm.v
```

> ⚠️ **不要把它加进 TD 的 Source Files 列表**。DI 会在 `ip/system_axi_lite_pwm_0/` 下生成自己的副本，原文件再加进工程会导致 module **重复定义**。

---

## 五、P1：mpack 封装 IP（GUI 操作）

**产物**：IP 仓库目录 `D:\FPGAproject\AnLuRun\PSPWM\ip_repo\axi_lite_pwm\`

| 步 | 操作 |
|---|---|
| 1 | TD 菜单栏 **Tools → Module Packager** |
| 2 | **File → Create Project**；① 工作空间目录 = `D:\FPGAproject\AnLuRun\PSPWM\ip_repo`（这是**仓库根**，不是单个 IP）② IP 名称 = `axi_lite_pwm` → Finish |
| 3 | 左侧 **FileSets** 下的 `axi_lite_pwm_files` 子页 → 右侧空白处**右键 → Add File** → 选 `axi_lite_pwm.v` ｜ ✅ 已完成 |
| 4 | **top module name** 填 `axi_lite_pwm` ｜ ✅ 已完成 |
| 5 | 切 **ports** 子页，核对端口齐全（**19** 个 `s_axi_*` + `pwm_out[2:0]` + `motor_dir[1:0]` + `motor_enable`）｜ ✅ 已完成，22 行、宽度全对 |
| 6 | **businterfaces** ｜ ⛔ 不走 GUI，改由脚本写 XML（见 §5.1） |
| 7 | **memoryMaps** ｜ ⛔ 同上，随 bus 一起写入 |
| 8 | **File → Save Project** ｜ ⚠️ 写入 XML 后**禁止再用 mpack 保存**，否则被内存里的旧内容覆盖 |

### portMaps 对照表（17 项，以界面实际命名大小写为准）

| bus 侧 logicPort | RTL 侧 physicalPort | 方向 |
|---|---|---|
| AWADDR | `s_axi_awaddr` | in |
| AWVALID | `s_axi_awvalid` | in |
| AWREADY | `s_axi_awready` | out |
| WDATA | `s_axi_wdata` | in |
| WSTRB | `s_axi_wstrb` | in |
| WVALID | `s_axi_wvalid` | in |
| WREADY | `s_axi_wready` | out |
| BRESP | `s_axi_bresp` | out |
| BVALID | `s_axi_bvalid` | out |
| BREADY | `s_axi_bready` | in |
| ARADDR | `s_axi_araddr` | in |
| ARVALID | `s_axi_arvalid` | in |
| ARREADY | `s_axi_arready` | out |
| RDATA | `s_axi_rdata` | out |
| RRESP | `s_axi_rresp` | out |
| RVALID | `s_axi_rvalid` | out |
| RREADY | `s_axi_rready` | in |

**注册仓库**：TD → **Tools → IP Catalog → 左侧 User IP 上右键 → Add IP Depot → 选 `ip_repo` 目录**。
注册后 DI 自动可见，无需重复添加。

### 5.1 总线接口：三条，不是一条（2026-10-29 依 TD 自带 IP 实证更正）

⚠️ **原方案写的「`s_axi_aclk`→`ACLK`、`s_axi_aresetn`→`ARESETN` 一起归进 `S_AXI`」是错的。** 对照 TD 自带 `ip/depot/AXI_GPIO_1.0/Component.xml`（本工程正在用的 IP）以及 `AXI_ERAM_Controller` / `AXI2APB` / `AXI_Clock_Converter` 四个样本，安路的写法一律是：

| 接口名 | busType（`anlogic.com/bus/…`） | 逻辑口 → 物理口 |
|---|---|---|
| `S_AXI` | `AXI4MM` ver `1.0`（abstraction `AXI4MM_rtl`） | 见上表 17 项；**`ACLK`/`ARESETn` 逻辑口保留但留空** |
| `S_AXI_ACLK` | `clock` ver `1.0`（`clock_rtl`） | `CLK` → `s_axi_aclk` |
| `S_AXI_AResetn` | `reset` ver `1.0`（`reset_rtl`） | `RESETn` → `s_axi_aresetn` |

- `AXI4MM` 逻辑口共 **50** 个（含 `AWID/AWLEN/AWSIZE/AWBURST/AWLOCK/AWCACHE/AWPROT/CSYSREQ…` 等 AXI4-Lite 用不到的），只映射 17 个，其余留空即可。
- 接口内必须有 `<ipxact:slave><ipxact:memoryMapRef memoryMapRef="axi_lite_slave"/></ipxact:slave>` —— DI 靠它判定从端并挂接 Address Editor。

**实施方式**：GUI 里 50 行表逐条点风险太高，改为脚本直接写 `Component.xml`（脚本 `C:\Users\21996\WorkBuddy\2026-09-08-11-13-26\build_bus_if.py`，模板取自 AXI_GPIO 原文，只把接口名 `S_AXI_Lite`→`S_AXI`）。

产物校验（已通过）：

| 项 | 结果 |
|---|---|
| `Component.xml` XML 良构 | ✅ root `{http}component` |
| 顶层元素顺序 | `vendor→library→name→version→busInterfaces→memoryMaps→model→fileSets→parameters→vendorExtensions`，与 AXI_GPIO 一致 |
| 接口数 / 映射数 | `S_AXI` 50 逻辑口映射 17；`S_AXI_ACLK` 1/1；`S_AXI_AResetn` 1/1 |
| 悬空物理端口 | 无（17+1+1 全部命中 22 个 RTL 端口） |
| 未被接口引用 | `pwm_out` / `motor_dir` / `motor_enable`（预期：留作普通输出引脚） |
| `memoryMaps` | `axi_lite_slave` / addressBlock `pwm_regs` / range 128 / 14 个寄存器 |
| 备份 | `Component.xml.bak-20261029-pre-bus`（md5 `3190417b9b24d51e5236f1c7029b202a`） |

> **若 mpack 报"只支持单个 module"**：文档说的是"单个 RTL **文件**"，同文件多 module 属于文档推荐的合并写法，正常可行。若确实失败，退路是把 `axi_lite_pwm_channel` 用 `generate` 内联进顶层。
> **若 bus 绑定界面出现 `AWPROT` / `ARPROT` 而 RTL 没有**：本工程 `AXI_GPIO` 也无此二端口，说明该 bus 定义容忍缺省；若强制要求，补两个空输入并在内部忽略即可。

---

## 六、P2：Design Integrator 集成（GUI 操作）

打开 DI 的 `system` design（`soc_prj\uisrc\01_rtl\system\`），按序做 6 步。

### ⓿ 动手前基线（依 `Design.xml` / `system.address.xml` / `hdl/system.v` 实测，2026-10-29）

**现有 10 个实例**：`ARM_Processor_System_0`、`AXI_Matrix_0`、`AXI_Protocol_Converter_0/1`、`AXI_GPIO_0/1`、`Concat_0`、`Constant_0/1`、`Processor_System_Reset_0`。

**现有 5 条总线互连**：

| 网络名 | 端点 A | 端点 B |
|---|---|---|
| `w_net__ARM_Processor_System_0__M_AXI_GP0` | PS `.M_AXI_GP0` | `AXI_Matrix_0 .US_AXI0` |
| `w_net__AXI_Matrix_0__DS_AXI0` | `AXI_Matrix_0 .DS_AXI0` | `AXI_Protocol_Converter_0 .US_AXI` |
| `w_net__AXI_Matrix_0__DS_AXI1` | `AXI_Matrix_0 .DS_AXI1` | `AXI_Protocol_Converter_1 .US_AXI` |
| `w_net__AXI_Protocol_Converter_0__DS_AXI` | `Converter_0 .DS_AXI` | `AXI_GPIO_0 .S_AXI_Lite` |
| `w_net__AXI_Protocol_Converter_1__DS_AXI` | `Converter_1 .DS_AXI` | `AXI_GPIO_1 .S_AXI_Lite` |

**时钟/复位**：全部由 PS 的 `p2f_clk0` / `p2f_rst0_n` 单网驱动（`system.v:702-715`），`AXI_Matrix`、两个 Converter、两个 GPIO 的 aclk/aresetn 都挂在同一根网上。

**地址**：GP0 主口基址 `0x80000000`；`Converter_0` → `0x80000000–0x80000FFF`；`Converter_1` → `0x80100000–0x80100FFF`；两段各 12 位宽（4 KB）。

### ① 矩阵扩到 3 从端

**双击 `AXI_Matrix_0`** → 弹出 IP 配置对话框。左树分组实测为：`Basic Settings` / `Protocol Sel` / `User Signals` / `Matrix Options` / `US Arbitration Priority` / `US Write Accpetance` / `US Read Accpetance` / `Internal Sample ID Width` / `Single Thread` / `DS Write Issuing` / `DS Read Issuing` / `Secure Slave` / `DS_00…DS_15` / `US_00…US_15`。

| 位置 | 字段（**实测界面显示名**） | 改成 |
|---|---|---|
| `Basic Settings` 组 | **`Number of DS(downstream) Interface`**（参数名 `AL_DS_NUM`，当前 2） | **3** |
| `DS_02` 组 | **`Base Address00(0x)`**（默认 `0000000000200000`） | `0000000080200000` |
| `DS_02` 组 | `Address Space Width00`（默认已是 `12`） | **不用动** |

> 字段名与 TD 5.9 文档措辞不同：GUI 上是 `Base Address00(0x)` / `Address Space Width00`，底层才是 `DS2_BASEADDR0` / `DS2_BASEADDR_WIDTH0`。
> 未使用的行显示 `FFFFFFFFFFFFFFFF`（= 无地址映射），保持原样。

**⚠️ `DS_02` 的默认值 `0x00200000` 必须改，不能留。** 矩阵是按「US 侧完整 32 位地址」与各 DS 的基址+宽度做译码：
- `DS0` = `0x80000000` + 12 位 → 覆盖 `0x80000000–0x80000FFF`
- `DS1` = `0x80100000` + 12 位 → 覆盖 `0x80100000–0x80100FFF`
- `DS2` 若留 `0x00200000` → 覆盖 `0x00200000–0x00200FFF`

则 PS 写 `0x80200000` **三段都不命中 ⇒ 无从端应答 ⇒ PS 读挂死 / 总线报错**，而现场表现极像「PWM 寄存器没实现」。所以基址必须对齐到 `0x80200000`，与前两段连成一片。

对照参照：`DS_00` 组 `Base Address00(0x)=0000000080000000`、`Width=12`；`DS_01` 组 `0000000080100000`、`12`。

- 改完 Diagram 上应多出 `DS_AXI2`，原有 `DS_AXI0/1` 连线**不应断开**（断了自己重连，网络名不变）。
- ⚠️ 其余 128/64 位打包参数（`AL_DS_AXI_BASE_ADDR`、`AL_DS_AXI_ADDR_WIDTH`、`AL_AXI_READ/WRITE_CONNECTIVITY`）**由工具按上面三个字段自动重算**，不要手填。当前实测：`AL_AXI_ADDR_WIDTH=32`、`AL_AXI_DATA_WIDTH=32`、`AL_AXI_ID_WIDTH=13`（USER 12）、`AL_DS_AXI_ADDR_WIDTH=0xC`。
- ⚠️ `Design.xml` 里残留 `ipCatalogDir = D:/Program Files/Anlgic/TD_5.9.1/ip/depot`（**该路径本机不存在**，现装在 `D:\exe\Anlu\TD`）。DI 实际读的是各实例自己的 `ip/system_AXI_Matrix_0/` 副本，一般不受影响；若双击矩阵报「找不到 IP / 版本不匹配」，就是这个原因，告诉我再处理。

### ② 加协议转换器

> ⛔ **`Ctrl+C` / `Ctrl+V` 不可用**（2026-10-29 实测）：粘贴后弹出的是 IpTool 配置窗，`Component Name` 仍是 `system_AXI_Protocol_Converter_1`（原有实例），底部红字 `Customization changes are not allowed` —— 即 DI 把 Ctrl+V 解释成「打开已有实例」，并没有产生新实例；且已生成过的实例不允许再改参数。

**正确做法：IP+ 新建。**

1. 工具栏 **IP+** → 搜 `AXI_Protocol_Converter` → 双击添加
2. `Component Name` 改为 **`system_AXI_Protocol_Converter_2`**（必须以 `_2` 结尾，用默认名会与 `_0/_1` 冲突）
3. 只改下表两个参数，**其余保持默认**

| 参数 | IP 默认值 | **必须改成** | 为什么 |
|---|---|---|---|
| `AL_AXI_ID_WIDTH` | **4** | **12** | 矩阵侧 `DS_AXI*` 的 ID 是 12 位（矩阵 `AL_AXI_ID_WIDTH=13`、`AL_AXI_ID_WIDTH_USER=12`）；4 位接 12 位在 bus 连线时位宽不匹配 |
| `AL_AXI_SUPPORTS_USER_SIGNALS` | **0** | **1** | 与 `Converter_0/1` 一致；设 0 后 `US_AXI` 总线不带 USER 信号，与矩阵侧总线视图不一致 |

其余参数默认值已与现有实例相同，**不要动**：`AL_AXI_ADDR_WIDTH=32`、`AL_AXI_DATA_WIDTH=32`、`AL_US_AXI_PROTOCOL=AXI4`、`AL_DS_AXI_PROTOCOL=AXI4LITE`、`READ_WRITE_Mode=READ_WRITE`、`ds_axi_awlen_de=7`、`us_axi_awlen_de=7`、`aximm_us=1`、`aximm_ds=0`。

> 参考：`Converter_0/1` 的 26 个参数全量实测值记在本文档 §六② 的历史版本与 `Design.xml` 中；只有上面两个与 IP 默认不同，这也证明它们是被**人为调过**的，不是默认。

### ③ 加 PWM IP

点 **IP+** → 搜 `axi_lite_pwm`（User IP 分类）→ 双击添加。实例名形如 `system_axi_lite_pwm_0`。

### ④ 连线（4 条）

| 连接 | 端点 | 说明 |
|---|---|---|
| ① | `AXI_Matrix_0 .DS_AXI2` ↔ `AXI_Protocol_Converter_2 .US_AXI` | 矩阵第 3 个下游口，粗蓝线 |
| ② | `AXI_Protocol_Converter_2 .DS_AXI` ↔ `axi_lite_pwm_0 .S_AXI` | 粗蓝线；PWM 的 AXI 口名是 `S_AXI` |
| ③ | `ARM_Processor_System_0 .p2f_clk0` → `AXI_Protocol_Converter_2 .aclk` | 细线 |
| ④ | `ARM_Processor_System_0 .p2f_rst0_n` → `AXI_Protocol_Converter_2 .aresetn` | 细线 |
| ⑤ | `ARM_Processor_System_0 .p2f_clk0` → `axi_lite_pwm_0 .s_axi_aclk` | 细线 |
| ⑥ | `ARM_Processor_System_0 .p2f_rst0_n` → `axi_lite_pwm_0 .s_axi_aresetn` | 细线 |

**画布上实测的端口名**（2026-10-29）：转换器是 `US_AXI` / `aclk` / `aresetn` / `DS_AXI`；PWM 是 `S_AXI` / `s_axi_aclk` / `s_axi_aresetn` ／ `pwm_out[2:0]` / `motor_dir[1:0]` / `motor_enable`。

> ③~⑥ 必须接到与 `AXI_GPIO_0/1`、`Converter_0/1` 同一根网（`w_net__ARM_Processor_System_0__p2f_clk0` / `..._p2f_rst0_n`）。DI 提示「复用现有网络」时**选复用**；若一个源引脚不允许挂第二根线，就**从已有那根线上拖出支线**（在导线上按住拖到目标引脚）。
> bus 连接后可用"点住 AXI_GPIO 的 bus 端口看粉色高亮"的办法，反查自己的连线是否同源。

### ⑤ 导端口

右键 `pwm_out` → **Create Design Port** → **Add**。
`motor_dir`、`motor_enable` 同样导出（后续接电机要用）。

### ⑥ 配地址 + 生成

**地址已实测自动正确**（2026-10-29，因 `DS_02` 基址提前填好，Address Editor 直接带出，无需手改）：

| Slave | Interface | Base | Range | High |
|---|---|---|---|---|
| `AXI_GPIO_0` | `S_AXI_Lite` | `0x8000_0000` | 4 K | `0x8000_0FFF` |
| `AXI_GPIO_1` | `S_AXI_Lite` | `0x8010_0000` | 4 K | `0x8010_0FFF` |
| **`axi_lite_pwm_0`** | **`S_AXI`** | **`0x8020_0000`** | **4 K** | **`0x8020_0FFF`** |

- `Auto Assign` **不要勾**（会重排既有窗口）
- 先跑 **Design 检查**（时钟检查 / 复位检查 / 地址空间检查），确认无红项
- 再 **生成 design**

**生成后必须复核两项**（这是判断地址是否真的生效的唯一凭据）：

1. `system.address.xml` 里应多出第 3 条 `addressDest`：`baseAddress=0x0000000080200000`、`highAddress=0x0000000080200FFF`；
2. `Design.xml` 里 `AXI_Matrix_0` 的 `AL_DS_AXI_BASE_ADDR`（128 位）应变成三段、`DS2_BASEADDR0=0000000080200000`、`DS2_BASEADDR_WIDTH0=12`。

若 Address Editor 分配了但矩阵参数没跟着变 ⇒ 矩阵的地址解码表没更新，P4 会表现为"写 `0x80200000` 无反应"，务必在生成前解决。

> ✅ **生成结果已核对（2026-10-29 19:09，DI 197563 / App 6.2.2.200067）**：
> 1. `system.address.xml` 第 3 条 `addressDest` = `0x0000000080200000` ~ `0x0000000080200FFF` ✅
> 2. `hdl/system.v` 端口顺序为 **`pwm_out[2:0]` / `motor_dir[1:0]` / `motor_enable` / `GPIO` / `GPIO_1`**
> 3. ⚠️ **端口名没有 `_0` 后缀**（此前文档里"很可能是 `pwm_out_0`"的推测是错的），直接用 `pwm_out` / `motor_dir` / `motor_enable`
> 4. 时钟/复位已自动接好：`system.v:954` `s_axi_aclk = p2f_clk0`、`:966` `s_axi_aresetn = p2f_rst0_n`
> 5. 新目录 `ip/system_axi_lite_pwm_0/`（含 `RTL/axi_lite_pwm_system_axi_lite_pwm_0.v`），`system.xml:233-241` 已登记三个文件，与既有 `AXI_Matrix_0`（同为 `RTL/` 子目录）布局一致

### 6.1 P3 C 侧已交付（2026-10-29，先于 DI 生成完成）

C 代码不依赖 DI 生成的端口名，仅依赖基址 `0x80200000`（Address Editor 已确认），故提前落地。

| 文件 | 说明 |
|---|---|
| `soc_sdk/axi_intr/TIM_PWM.h` | 寄存器偏移宏 + 9 个 API 原型；含 `PWM_CTRL_CH_EN(ch)` / `PWM_UPDATE_CH(ch)` 位宏 |
| `soc_sdk/axi_intr/TIM_PWM.c` | 驱动实现；`PWM_SelfTest()` 做 VERSION 比对 + CCR 影子寄存器回读 |
| `soc_sdk/axi_intr/main.c` | 重写为三步验证，`#define BRINGUP_STEP` 1/2/3 切换 |
| `soc_sdk/axi_intr/main.c.bak-20261029` | 原 AXI GPIO 中断例程备份（md5 `c9efc02d956e4e64a054ffde8b7b84ed`） |

**Makefile 无需改动**：`axi_intr/Makefile:37` 用 `find "./" -type d` + `wildcard *.c` 自动发现源码，新增 .c 自动参与编译。

**编译验证**（CLI，非 FD GUI）：

```bash
export PATH="D:/FPGAproject/SpaceForFD/FD/toolchain/gcc/aarch64/bin:D:/FPGAproject/SpaceForFD/FD/toolchain/build-tools/bin:$PATH"
make SDK_ROOT="D:/FPGAproject/AnLuRun/PSPWM/soc_sdk/soc_base" \
     COMPILE_PREFIX=aarch64-none-elf- TARGET=axi_intr
```

结果：`exit=0`，**0 error / 0 warning**，`build/axi_intr.elf` 1,158,288 B / `axi_intr.bin` 122,024 B。
`nm` 可见 `PWM_ReadVersion / PWM_SelfTest / PWM_Init / PWM_SetMotor / PWM_Breath`（`PWM_SetDuty`/`PWM_Commit`/`PWM_Enable` 被 -O2 内联，属正常）。
`grep -a "AXI PWM bring-up" axi_intr.bin` 命中、旧字符串 `PL interrupt  TEST` 已消失 ⇒ 确属重编。

> ⚠️ `axi_intr/Makefile:6` 是 `DOWNLOAD = ddr`（不是 ocm），链接脚本为 `lds/gcc_dr1m90_ddr_aarch64.ld`，程序运行在 DDR。下载时 FD 里对应的 launch 配置也要一致。

---

## 七、P3：三处代码改动

### ① `soc_prj/uisrc/01_rtl/system_top.v` ✅ 已按生成结果改写

DI 生成后 `system` 的真实端口是 `pwm_out[2:0]` / `motor_dir[1:0]` / `motor_enable` / `GPIO` / `GPIO_1`（**无 `_0` 后缀**）。顶层只引出 4 个（`motor_dir` 暂不引出）：

```verilog
module system_top
(
inout  wire         GPIO,
inout  wire         GPIO_1,
output wire [2:0]   pwm_out,
output wire         motor_enable
);

// motor_dir 暂不引出：不能直接写 .motor_dir(2'b00)，
// Verilog 不允许输出端口接常量表达式，必须先给一根真实 net 再闲置。
wire [1:0] motor_dir_nc;

system I_system
(
.GPIO           (GPIO),
.GPIO_1         (GPIO_1),
.pwm_out        (pwm_out),
.motor_dir      (motor_dir_nc),
.motor_enable   (motor_enable)
) ;

endmodule
```

> ⚠️ **必须用具名连接**（`.pwm_out(...)`），不能用位置连接 —— DI 每次重新生成都可能重排端口顺序，位置连接会静默接错。
> ⚠️ 顺手排掉一个坑：`.motor_dir(2'b00)` 是**非法**的（输出端口不能接常量表达式），我第一次这么写，已改为一根闲置 wire。

**备份**：`system_top.v.bak-20261029`（md5 `7d25d7462ec81c806209283809f73f42`）

### ② `soc_prj/uisrc/04_pin/fpga_pin.adc` ✅ 已改

```tcl
set_pin_assignment	{ GPIO     		}	{ LOCATION = K14;  IOSTANDARD = LVCMOS33;}
set_pin_assignment	{ GPIO_1     	}	{ LOCATION = J14;  IOSTANDARD = LVCMOS33;}
set_pin_assignment	{ pwm_out[0] 	}	{ LOCATION = T19;  IOSTANDARD = LVCMOS33;}
set_pin_assignment	{ pwm_out[1] 	}	{ LOCATION = R19;  IOSTANDARD = LVCMOS33;}
set_pin_assignment	{ pwm_out[2] 	}	{ LOCATION = J15;  IOSTANDARD = LVCMOS33;}
set_pin_assignment	{ motor_enable 	}	{ LOCATION = M20;  IOSTANDARD = LVCMOS33;}
```

| 端口 | 引脚 | 板上丝印 | 来源 |
|---|---|---|---|
| `pwm_out[0]` | T19 | LED1 | `AnLuRun\01_run_led\uisrc\04_pin\fpga_pin.adc` 实测对照 |
| `pwm_out[1]` | R19 | LED2 | 同上 |
| `pwm_out[2]` | J15 | LED3 | 同上 |
| `motor_enable` | M20 | LED4 | 同上 |

> `motor_dir` 没有引脚 —— 它在顶层被一根闲置 wire 接着，综合时会优化掉。
> **上板后若呼吸方向相反**（该亮时灭），说明 LED 为低电平点亮，把对应端口改成 `~pwm_out[n]` 即可。
> **备份**：`fpga_pin.adc.bak-20261029`（md5 `dc77451b41b30506bc2e43b065637603`）

### ③ SDK 代码：`TIM_PWM.h` / `TIM_PWM.c` / `main.c` ✅ 已交付

**最终实现见 §6.1 与仓库实际文件**，接口为 `PWM_Init / PWM_SetTiming / PWM_SetDuty / PWM_Commit / PWM_Enable / PWM_SetMotor / PWM_Breath / PWM_SelfTest`。

> 下面保留的是**初版草案**（接口名 `TIM_*`、影子逻辑更简单），已被实际文件取代，仅作设计演进记录，**不要照抄**。

<details>
<summary>初版草案（已作废）</summary>

放到 `soc_prj/../soc_sdk/axi_intr/`。

**`TIM_PWM.h`**

```c
#ifndef TIM_PWM_H_
#define TIM_PWM_H_

#include <stdint.h>

#define AXI_PWM_BASE        0x80200000U

#define AXI_PWM_CTRL        (AXI_PWM_BASE + 0x00U)
#define AXI_PWM_DIR         (AXI_PWM_BASE + 0x04U)
#define AXI_PWM_STATUS      (AXI_PWM_BASE + 0x08U)
#define AXI_PWM_VERSION     (AXI_PWM_BASE + 0x0CU)
#define AXI_PWM0_PSC        (AXI_PWM_BASE + 0x10U)
#define AXI_PWM0_ARR        (AXI_PWM_BASE + 0x14U)
#define AXI_PWM0_CCR        (AXI_PWM_BASE + 0x18U)
#define AXI_PWM_UPDATE      (AXI_PWM_BASE + 0x40U)

/* 三通道寄存器组间距固定 0x10：PSC=n*0x10, ARR=+4, CCR=+8 */
#define AXI_PWM_REG_STRIDE  0x10U

typedef enum { PWM0 = 0, PWM1, PWM2, PWM_NUM } PWM_ID;

void     TIM_PWM_Init(void);
int      TIM_SetCompare(PWM_ID id, float duty);
int      PWM_Output(PWM_ID id, int cmd);
int      PWM_MotorEnable(int en);
void     TIM_PWM_Breath(PWM_ID id, uint32_t steps, uint32_t step_ms);
uint32_t TIM_GetVersion(void);
uint32_t TIM_GetARR(PWM_ID id);

#endif /* TIM_PWM_H_ */
```

**`TIM_PWM.c`**

```c
#include "TIM_PWM.h"
#include "ui_io.h"
#include "al_systimer.h"

#define PWM_ARR_DEFAULT  9999U

static uint32_t pwm_arr[PWM_NUM];
static uint32_t pwm_ctrl;

uint32_t TIM_GetVersion(void)
{
    return UI_In32((void *)(uintptr_t)AXI_PWM_VERSION);
}

uint32_t TIM_GetARR(PWM_ID id)
{
    if ((unsigned)id >= (unsigned)PWM_NUM) return 0U;
    return UI_In32((void *)(uintptr_t)(AXI_PWM0_ARR + (uint32_t)id * AXI_PWM_REG_STRIDE));
}

void TIM_PWM_Init(void)
{
    uint32_t id;

    for (id = 0U; id < (uint32_t)PWM_NUM; ++id) {
        pwm_arr[id] = PWM_ARR_DEFAULT;
        UI_Out32((void *)(uintptr_t)(AXI_PWM0_PSC + id * AXI_PWM_REG_STRIDE), 0U);
        UI_Out32((void *)(uintptr_t)(AXI_PWM0_ARR + id * AXI_PWM_REG_STRIDE), PWM_ARR_DEFAULT);
        UI_Out32((void *)(uintptr_t)(AXI_PWM0_CCR + id * AXI_PWM_REG_STRIDE), 0U);
    }
    UI_Out32((void *)(uintptr_t)AXI_PWM_UPDATE, 0x7U);

    pwm_ctrl = 0U;
    UI_Out32((void *)(uintptr_t)AXI_PWM_CTRL, pwm_ctrl);
}

/* duty: 0.0 ~ 1.0。分母是 ARR+1，因此 duty=1.0 对应 100% 恒高 */
int TIM_SetCompare(PWM_ID id, float duty)
{
    uint32_t arr, ccr;

    if ((unsigned)id >= (unsigned)PWM_NUM) return 0;
    if (duty < 0.0f) duty = 0.0f;
    if (duty > 1.0f) duty = 1.0f;

    arr = pwm_arr[id];
    ccr = (uint32_t)((float)(arr + 1U) * duty + 0.5f);
    if (ccr > arr + 1U) ccr = arr + 1U;

    UI_Out32((void *)(uintptr_t)(AXI_PWM0_CCR + (uint32_t)id * AXI_PWM_REG_STRIDE), ccr);
    UI_Out32((void *)(uintptr_t)AXI_PWM_UPDATE, 1U << (uint32_t)id);
    return 1;
}

/* 逐位改写软件影子，避免原参考代码"静态变量只置不清"的问题 */
int PWM_Output(PWM_ID id, int cmd)
{
    if ((unsigned)id >= (unsigned)PWM_NUM) return 0;

    if (cmd) pwm_ctrl |=  (1U << (uint32_t)id);
    else     pwm_ctrl &= ~(1U << (uint32_t)id);

    UI_Out32((void *)(uintptr_t)AXI_PWM_CTRL, pwm_ctrl);
    return 1;
}

int PWM_MotorEnable(int en)
{
    if (en) pwm_ctrl |=  0x8U;
    else    pwm_ctrl &= ~0x8U;

    UI_Out32((void *)(uintptr_t)AXI_PWM_CTRL, pwm_ctrl);
    return 1;
}

void TIM_PWM_Breath(PWM_ID id, uint32_t steps, uint32_t step_ms)
{
    uint32_t i;

    if (steps == 0U) steps = 100U;

    for (i = 0U; i <= steps; ++i) {
        TIM_SetCompare(id, (float)i / (float)steps);
        AlSys_MDelay(step_ms);
    }
    for (i = steps; i > 0U; --i) {
        TIM_SetCompare(id, (float)(i - 1U) / (float)steps);
        AlSys_MDelay(step_ms);
    }
}
```

> 与参考代码 `TIM_PWM.c` 相比修掉的三个问题：
> 1. `PWM_Output()` 用 `static int pwm_status` 只置位不清位，且未处理 `CTRL[3]` → 改为显式影子变量 + 逐位改写
> 2. `new_ccr = (arr+1)*duty - 1` 在 `duty=0` 时得 `-1`，转无符号即 `0xFFFFFFFF`（100% 占空比）→ 改为 `+0.5` 四舍五入并夹紧
> 3. `int arr = 9999;` 硬编码 → 改为 `pwm_arr[]` 影子，与 `TIM_PWM_Init()` 写入值始终一致

**`main.c`（替换原 AXI GPIO 中断测例）**

```c
#include <stdio.h>
#include "al_core.h"
#include "ui_io.h"
#include "ui_type.h"
#include "TIM_PWM.h"

int main(void)
{
    uint32_t ver;

    printf("AXI PWM BREATH TEST!\r\n");

    /* 步骤①：先只读 VERSION，确认 AXI 通路打通（期望 0x00010000） */
    ver = TIM_GetVersion();
    printf("AXI PWM VERSION = 0x%08X\r\n", (unsigned)ver);
    if (ver != 0x00010000U) {
        printf("AXI PWM unreachable, halt.\r\n");
        while (1) { }
    }

    TIM_PWM_Init();
    printf("AXI PWM init done, ARR0 = %u\r\n", (unsigned)TIM_GetARR(PWM0));

    PWM_Output(PWM0, 1);

    while (1) {
        TIM_PWM_Breath(PWM0, 100U, 10U);   /* 100 级 × 10 ms ⇒ 单程 1 秒 */
    }

    return 0;
}
```

</details>

---

## 七-A、P4 前置：TD 综合 / 布线 / 位流（GUI 操作）

| 步 | 操作 | 判据 |
|---|---|---|
| 1 | 打开 `soc_prj/soc_prj.al`（若已开则确认 TD 弹出"文件已被外部修改/重新加载"时选**重新加载**） | Source 面板里 `system_top` 的端口树出现 `pwm_out[2:0]` / `motor_enable` |
| 2 | 确认 `system/ip/system_axi_lite_pwm_0/RTL/axi_lite_pwm_system_axi_lite_pwm_0.v` 已被带进层次（展开 `system` → `I_system` 子树能找到 `system_axi_lite_pwm_0_Inst`） | 不需要手动 Add Files；`.al` 只列 `system.xml`，IP 由它递归带出（既有 `AXI_Matrix_0` 同为 `RTL/` 子目录，证明 TD 会递归） |
| 3 | 跑 **Synthesis**（`syn_1`） | 报告里 `system_axi_lite_pwm_0` 有非零 LUT/DFF（说明真的被综合了，不是空壳） |
| 4 | 若综合阶段重现 3 条 `AXI ID port width inconsistency`（13 位矩阵 DS vs 12 位转换器 US） | **不是新引入的回归**：改动前的 `hdl/system.v`（2025-07-22）就有 2 条；`AL_US_NUM=1` 时多余位恒为 0。处置：Violations 面板 Waive；或把转换器 `AXI_ID_WIDTH` 抬到 13（**不要动矩阵的 12 位**） |
| 5 | 跑 **Physical Design**（`phy_1`）→ 生成位流 | 时序报告 `p2f_clk0` 需 Positive Slack |

> ⚠️ **`timing.sdc` 是 2 倍过约束**：`create_clock -period 10`，而 `p2f_clk0` 实际是 49.995 MHz（≈20.002 ns）。这项来自官方例程、既有工程一直这么跑，**本轮先不动**（避免引入新变量）；若时序报红再单独改成 `-period 20.002`。
> ⚠️ **顶层不要加 `uisrc/03_ip/axi_lite_pwm/axi_lite_pwm.v`** —— 它和 `ip/system_axi_lite_pwm_0/RTL/` 里那份是同一模块的两份拷贝，同时进编译会 `module already defined`。
> ⚠️ **不要再用 mpack 打开并保存这个 IP** —— 会覆盖脚本写进去的 `busInterfaces` / `memoryMaps`，AXI 连接当场失效。

---

## 八、P4：上板验证 ✅ **已通过（2026-10-29 20:17）**

| 步 | 做什么 | 判据 | 实测结果 |
|---|---|---|---|
| ① | 只读 `VERSION`（`0x80200000+0x0C`），一个字节都不写 | 读到 `0x00010000` ⇒ AXI 从端可达、地址映射正确 | ✅ 通过（`VER==EXPECT`，代码继续往下走） |
| ② | 写 `CCR0=0x1234` 再读回，然后清 0 | 回读值一致 ⇒ AW/W 握手、`wstrb`、影子寄存器都正常 | ✅ 通过（自检返回 0） |
| ③ | `PWM_Init()` 配 PSC/ARR + 使能 CH0/CH1 + `PWM_SetMotor(0,1)` | `STATUS` 的 `bit5:3` 变成 3（`0x18`）；`ARR` 回读 9999；LED4 亮 | ✅ 通过 |
| ④ | 进呼吸循环 | LED1 平滑呼吸 | ✅ 通过，约 2 秒一个来回 |

**实测三灯现象（决定性证据）**：

| LED | 引脚 | 含义 | 实测 |
|---|---|---|---|
| LED5 | MIO51（PS GPIO，不经 AXI） | 程序在跑 + VERSION 与写回读全过 | **常亮** ✅ |
| LED4 | M20（`motor_enable`＝`CTRL[3]`） | AXI 写真的落地了 | **常亮** ✅ |
| LED1 | T19（`pwm_out[0]`） | PL 计数器出波 | **呼吸** ✅ |

⇒ **PS 软件 → AXI4 → 矩阵 DS2 → 协议转换器 → AXI4-Lite → PWM 影子寄存器 → 计数器 → 引脚** 整条链路闭合。

### 8.1 验证手段的调整（串口不可靠时的替代方案）

本机串口长期不稳，因此没有把串口作为唯一判据，而是搭了**三条互不依赖**的观察通道：

| 通道 | 通路段 | 回答的问题 |
|---|---|---|
| LED5 = MIO51 | 纯 PS GPIO，绕开 AXI / PL / 串口 | CPU 跑起来了吗 |
| LED4 = M20 | AXI 写 → `CTRL[3]` | AXI 的"写"生效了吗 |
| LED1 = T19 | PL 计数器 | 波形出来了吗 |

现象对照表：

| LED5 | LED4 | LED1 | 结论 |
|---|---|---|---|
| 慢闪不止 | 灭 | 灭 | VERSION 或写回读失败，AXI 通路问题 |
| 常亮 | 灭 | 灭 | 寄存器读写 OK，但 `CTRL` 没落到引脚 |
| 常亮 | 常亮 | 灭 | `CTRL` 生效，PWM 通道不出波 |
| 常亮 | 常亮 | **呼吸** | 全通 |
| 完全不动 | 灭 | 灭 | 程序没执行到 `main` / 位流没下 |

> 第三条通道：FD 调试器的 Memory 窗口直接读 `0x8020000C`，读到 `00010000` 即 AXI 通，完全不依赖串口。

### 8.2 过程中踩到并修掉的两个非 PWM 问题

| # | 问题 | 根因 | 处置 |
|---|---|---|---|
| 1 | FD 编译 72 errors，全在 `al_mpu.c`（`AL_MPU_HalStruct` 等类型未声明） | `soc_base/platform/inc/soc_plat.h` 里 15 行 `#define HAVE_*PS_DRIVER` 被 FD 重新导出时**整块写空**（只剩占位符 `/*{{device}}*/`）；`al_hal.h:41` 是 `#ifdef HAVE_MPUPS_DRIVER` 才 include `al_mpu_hal.h` | 补回 15 行（与 `3_2_01_sdk_base/14_axi_gpio_pl_intr` 同名文件一致）。⚠️ **每次 FD 重新导出 platform 都会复发**，判据 = `grep -c "^#define HAVE_" soc_plat.h` 应为 15 |
| 2 | 串口无输出 | 之前能烧的 elf 是靠**陈旧 `.o` 拼出来的**（`al_log.c` 里 `#if !defined(HAVE_UARTPS_DRIVER) ... #error`，宏丢失后该文件处于"一编就报错"状态，从未被重编） | 修好头文件后全量重编，`al_log.c.o` / `al_uart_hal.c.o` / `al_chip.c.o` 统一在 19:46 生成，BSP 状态一致 |

> **为何要分步**：本工程历史上出现过"AXI 访存导致异常复位"（当时未结案）。第 ① 步是最小可判定的探针——若读 `VERSION` 就挂死或复位，问题在 AXI 通路本身，与 PWM 逻辑无关，可立即把范围锁死。

**下载方式**：SoC 工程 TD 直下不出图，**必须走 FD**（下载 fsbl + 应用，或打 `BOOT.BIN`）。

**关键产物**：位流 `soc_prj\soc_prj_Runs\best_result\soc_prj.bit`（19:22）；程序 `soc_sdk\axi_intr\build\axi_intr.elf`（20:10，`BRINGUP_STEP=3`）。

---

## 九、寄存器表与时序参数

### 寄存器映射（基址 `0x80200000`）

| 偏移 | 名称 | 位定义 | 读/写 |
|---|---|---|---|
| `0x00` | `CTRL` | [0] PWM0 使能、[1] PWM1 使能、[2] PWM2 使能、[3] 电机驱动使能 | R/W |
| `0x04` | `DIR` | [0] 电机0 方向、[1] 电机1 方向 | R/W |
| `0x08` | `STATUS` | [2:0] 通道待提交标志、[5:3] 通道使能、[6] 电机使能 | R |
| `0x0C` | `VERSION` | 固定 `0x00010000` | R |
| `0x10/14/18` | `PWM0_PSC/ARR/CCR` | 预分频 / 周期 / 比较值 | R/W |
| `0x20/24/28` | `PWM1_PSC/ARR/CCR` | 同上 | R/W |
| `0x30/34/38` | `PWM2_PSC/ARR/CCR` | 同上 | R/W |
| `0x40` | `UPDATE` | 写 1 到 bit[2:0] 提交对应通道的新 PSC/ARR/CCR | W |

> 影子寄存器机制：新值写入后**不立即生效**，要等 `UPDATE` 对应位被写 1，且在**下一个周期边界**统一生效 —— 这样改占空比不会截断半个脉冲。

### 频率与分辨率

```
f_pwm = 49.995 MHz / ((PSC + 1) × (ARR + 1))
```

| PSC | ARR | PWM 频率 | 占空比分辨率 | 适用 |
|---|---|---|---|---|
| 0 | 9999 | **4.9995 kHz** | 1/10000 | ✅ 本期呼吸灯（无频闪） |
| 0 | 4999 | 9.999 kHz | 1/5000 | 一般电机 |
| 0 | 2499 | 19.998 kHz | 1/2500 | ✅ 电机推荐（超出人耳，无啸叫） |
| 0 | 199 | 249.975 kHz | 1/200 | 舵机/高响应场景不适用 |

> 呼吸节拍：100 级 × 10 ms = 1 s 单程，2 s 一个来回。若觉得太慢改 `step_ms`。

---

## 十、风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| **PSPWM 的 AXI 异常复位史** | 首次持续读写 AXI 从端可能重现挂死 | 按 P4 分四步走，第①步只读 `VERSION` 做探针 |
| 通道使能位 | PWM0/PWM1 不出波（静默） | P0 ② 已修 |
| 地址位宽 9 vs 32 | bus 连线直接报错 | P0 ① 已修 |
| mpack 单 module 限制 | 打包失败 | 退路：`generate` 内联 channel |
| `AWPROT/ARPROT` 缺失 | bus 绑定报缺端口 | 补两个空输入（3 行） |
| DI 生成后端口名变化 | `system_top.v` 编译报未定义端口 | 以生成结果为准，需回贴端口列表 |
| `timing.sdc` 过约束 | 布线偏紧，可能影响时序余量 | 本次不动；后续可把 `-period 10` 改 `20.002` |
| FD 才能下载 | TD 直下不出图 | P4 走 FD |
| `DS_NUM` 改动后地址表 | 新增从端未分配地址会报"地址空间检查"红项 | 必须在 Address Editor 里显式给 `0x80200000` |

---

## 十一、待补信息（P2 完成后回填）

1. ✅ **DI 生成后 `system` wrapper 的实际端口名** = `pwm_out[2:0]` / `motor_dir[1:0]` / `motor_enable`，**无 `_0` 后缀**（2026-10-29 19:09 实测）
2. ✅ **mpack 打包是否一次通过** —— 原始 RTL 因参数化位宽被解析成 1 bit，补丁后（§四-④）+ 删除 Fileset 重新 Add 后一次通过
3. ✅ **上板第 ① 步读 `VERSION` 是否稳定** —— 2026-10-29 20:17 实测稳定读到 `0x00010000`，AXI 通路可用（详见 §八）

---

## 附录：文件清单

| 类型 | 路径 | 说明 |
|---|---|---|
| 新建 | `soc_prj/uisrc/03_ip/axi_lite_pwm/axi_lite_pwm.v` | P0 产物（修改后 RTL） |
| 新建 | `ip_repo/axi_lite_pwm/`（mpack 生成） | P1 产物（IP 仓库） |
| 改动 | `soc_prj/uisrc/01_rtl/system/hdl/system.v`、`Design.xml` | 由 DI **自动重写**，不手改 |
| 改动 | `soc_prj/uisrc/01_rtl/system_top.v` | P3 加端口 + 连实例 |
| 改动 | `soc_prj/uisrc/04_pin/fpga_pin.adc` | P3 加 `pwm_led → T19` |
| 新建 | `soc_sdk/axi_intr/TIM_PWM.h` / `TIM_PWM.c` | P3 |
| 改动 | `soc_sdk/axi_intr/main.c` | P3 换为 PWM 呼吸 + VERSION 探针 |

---

*文档起始：2026-10-28（规划态）· 最后回填：2026-10-29 20:18（实测态）· 对应工程 `D:\FPGAproject\AnLuRun\PSPWM` · **状态：已上板，整链闭合***
*阶段封版记录见同目录《阶段归档-AXI_PWM呼吸灯-20261029.md》*
