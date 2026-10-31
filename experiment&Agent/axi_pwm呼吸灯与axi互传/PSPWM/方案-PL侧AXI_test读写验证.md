---
日期: 2026-10-30
工程: PSPWM（AnLuRun\PSPWM）
阶段: PL 侧 AXI 从端最小验证
关联: [[阶段归档-AXI_PWM呼吸灯-20261029]]
排障: <D:\项目\FPGA工程\03-排障记录\BSP导入问题\BSP平台头注入缺失-编译72错-20261030.md>
---

# 方案 —— PL 侧 AXI_test：PS 写数据 / PL 产数据 / PS 读回来

> **一句话**：这个模块不做任何外设功能，只回答一个问题 —— 「PS 和 PL 之间的 AXI 通路，到底通没通、通在哪一环」。它是一次性的**探针模块**，验收通过后就可以从工程里摘掉。

---

## 一、要证明什么、不证明什么

| ✅ 这一版要证明 | ❌ 这一版不管 |
|---|---|
| PS 能按地址读到 PL 里的常量（地址映射、AW/AR 握手、从端选通） | 带宽、突发传输（burst）、多拍流水 |
| PS 写进去的数，下次能原样读回（写通路、字节选通 `wstrb`） | 中断、DMA、HP 口高带宽通路 |
| **PL 自己产生的数**（计数器）PS 能读到，且两次读不一样 | 时序收敛 / 跨时钟域 |
| PS 写命令 → PL 执行 → PS 轮询状态，这条握手链能跑通 | 任何实际外设功能 |

**为什么先做这个**：`axi_lite_pwm` 虽然已经在板上跑通（PS 读出 `VERSION`/`ARR`/`CCR`），但它是"带业务的"——出了问题分不清是 AXI 坏了还是 PWM 逻辑坏了。`AXI_test` 把 AXI 单独剥出来，**它是后面所有 PL 模块的地基**；地基验一次，以后每个新模块只需验它自己的业务逻辑。

---

## 二、现状：AXI 通路**已经通过**，不是从零开始

这一点必须先说清，否则会误以为要打通一条新路。

`PSPWM` 工程里已有 `axi_lite_pwm` 挂在 GP0 上，且 2026-10-30 上板实测：

```
base = 0x80200000  step = 3
[1] VERSION = 0x00010000 (expect 0x00010000) OK
    readback CTRL=0x00000003 ARR=9999 PSC=0 CCR=0
```

**能读出 `VERSION` 和 `readback`，本身就说明"PS 写进去、PS 读回来"这条 AXI-Lite 通路是通的。** 所以 `AXI_test` 的目标不是"打通"，而是：

1. 把它变成**可重复、可定位**的验证（分三组寄存器，读错哪组就知道断在哪）
2. 补上 PWM 没验证的那一条：**PL 主动产生数据 → PS 读**（PWM 的数据全是 PS 写的，PL 只输出引脚电平，PS 读回来的还是自己写的影子寄存器）

现有地址分配（`system.address.xml`）：

| 实例 | 基址 | 窗口 |
|---|---|---|
| `AXI_GPIO_1` | `0x80100000` | 4 KB |
| `axi_lite_pwm_0` | `0x80200000` | 4 KB |
| **`AXI_test_0`（本次新增）** | **`0x80300000`** | 4 KB |

---

## 三、通路链路

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 340" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>AXI_test 链路：PS 经 GP0 访问 PL 从端，四组寄存器各验一条通路</title>
<desc>PS 应用的 MMIO 读写经 Master_AXI_GP0 进入 PL 侧的 AXI_test 从端；从端内部四组寄存器分别验证只读常量、写读回、PL 自由计数器、命令状态握手</desc>
<defs>
<marker id="ax" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>
<rect x="16" y="118" width="146" height="96" rx="10" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="28" y="140" font-size="12" font-weight="500" fill="#3C3489">PS · Cortex-A35</text>
<text x="28" y="158" font-size="11" fill="#534AB7">裸机 C（main.c）</text>
<text x="28" y="174" font-size="11" fill="#534AB7">UI_In32 / UI_Out32</text>
<text x="28" y="190" font-size="11" fill="#534AB7">基址 0x80300000</text>
<text x="28" y="206" font-size="11" fill="#534AB7">偏移 +0x00 … +0x30</text>

<line x1="162" y1="166" x2="206" y2="166" stroke="#888780" stroke-width="1.5" marker-end="url(#ax)"/>
<text x="164" y="158" font-size="10" fill="#5F5E5A">MMIO</text>

<rect x="208" y="130" width="106" height="72" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="220" y="152" font-size="12" font-weight="500" fill="#2C2C2A">Master_AXI_GP0</text>
<text x="220" y="170" font-size="11" fill="#5F5E5A">AXI4-Lite 主口</text>
<text x="220" y="186" font-size="11" fill="#5F5E5A">译码 0x8010/8020/8030</text>

<line x1="314" y1="166" x2="368" y2="166" stroke="#888780" stroke-width="1.5" marker-end="url(#ax)"/>
<text x="316" y="158" font-size="10" fill="#5F5E5A">S_AXI</text>
<text x="316" y="184" font-size="10" fill="#0F6E56">p2f_clk0</text>
<text x="316" y="197" font-size="10" fill="#0F6E56">199.98 MHz</text>

<rect x="372" y="44" width="292" height="272" rx="12" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="388" y="68" font-size="13" font-weight="500" fill="#085041">AXI_test_0 · 从端（PL）</text>
<text x="388" y="85" font-size="11" fill="#0F6E56">纯寄存器，无对外引脚；一切观测都走 AXI 读</text>

<rect x="388" y="94" width="260" height="46" rx="6" fill="#FFFFFF" stroke="#0F6E56" stroke-width="0.5"/>
<text x="400" y="111" font-size="11" font-weight="500" fill="#085041">① 读通路 · ID / VER / PAT0–3</text>
<text x="400" y="128" font-size="10" fill="#0F6E56">RO 常量 → 地址映射与读握手</text>

<rect x="388" y="148" width="260" height="46" rx="6" fill="#FFFFFF" stroke="#0F6E56" stroke-width="0.5"/>
<text x="400" y="165" font-size="11" font-weight="500" fill="#085041">② 写通路 · SCR0 / SCR1</text>
<text x="400" y="182" font-size="10" fill="#0F6E56">RW → PS 写进去、PS 读回来</text>

<rect x="388" y="202" width="260" height="46" rx="6" fill="#FFFFFF" stroke="#0F6E56" stroke-width="0.5"/>
<text x="400" y="219" font-size="11" font-weight="500" fill="#085041">③ PL 产数据 · LIVE_LO / HI</text>
<text x="400" y="236" font-size="10" fill="#0F6E56">RO 自由计数器 → 时钟真的到了 PL</text>

<rect x="388" y="256" width="260" height="46" rx="6" fill="#FFFFFF" stroke="#0F6E56" stroke-width="0.5"/>
<text x="400" y="273" font-size="11" font-weight="500" fill="#085041">④ 握手 · CMD / STATUS / COUNT</text>
<text x="400" y="290" font-size="10" fill="#0F6E56">PS 触发 → PL 跑 → PS 轮询到 DONE</text>

<text x="16" y="300" font-size="11" fill="#5F5E5A">复位：p2f_rst0_n（低有效）</text>
<text x="16" y="318" font-size="11" fill="#5F5E5A">本模块无输出引脚，集成只需连时钟、复位、AXI 三样</text>
</svg>

---

## 四、寄存器映射

全部 32 位访问，偏移相对基址。窗口 4 KB，但只解码低 8 位（256 字节），够用且省资源。

| 偏移 | 名称 | 读写 | 复位值 | 含义 |
|---|---|---|---|---|
| `0x00` | `ID` | RO | `0x41584954` | `'A''X''I''T'`。**读到它 = 整条 AXI 通路基本通了** |
| `0x04` | `VER` | RO | `0x00010000` | 版本，与 PWM 的版本号同格式便于区分 |
| `0x08` | `SCR0` | RW | `0x0` | PS 写→读回，第 1 组 |
| `0x0C` | `SCR1` | RW | `0x0` | 第 2 组，**用来发现"两个地址落到同一个寄存器"** |
| `0x10` | `LIVE_LO` | RO | — | 64 位自由计数器低 32 位 |
| `0x14` | `LIVE_HI` | RO | — | 高 32 位 |
| `0x18` | `PAT0` | RO | `0xA5A50000` | 常量，用来和 LIVE 做对照 |
| `0x1C` | `PAT1` | RO | `0xA5A50001` | |
| `0x20` | `PAT2` | RO | `0x5A5A0002` | |
| `0x24` | `PAT3` | RO | `0x5A5A0003` | |
| `0x28` | `CMD` | WO | `0x0` | `[0]=START` 启动计数，`[1]=CLR` 清零（**CLR 优先**）|
| `0x2C` | `STATUS` | RO | `0x0` | `[0]=BUSY`, `[1]=DONE` |
| `0x30` | `COUNT` | RO | `0x0` | 受控计数值，跑满 `RUN_TARGET` 停住 |

**`RUN_TARGET` 默认 `0x0010_0000`（1,048,576）**，@200 MHz 约 **5.24 ms**。选这个值的理由：

- 太短（几百拍）→ PS 侧轮询抓不到 `BUSY=1`，只能看到 `DONE`，少一个观测点
- 太长（几秒）→ 手测时以为死机
- 5 ms → 轮询一定能连续看到 `BUSY=1 → DONE=1`，同时不阻塞

---

## 五、三组寄存器各自能定位什么（这是本模块的核心价值）

单看"A 通了"没有诊断价值；**读错哪一组**才有。

| 现象 | 说明断在 | 下一步查哪 |
|---|---|---|
| `ID` 读不到（全 0 / 全 1 / 卡死） | 地址映射、AXI 连接、从端没选通 | DI 里接口有没有连上；`system.address.xml` 有没有分配地址 |
| `ID` 对，`PAT` 也全对 | 读通路好 | 继续看下一行 |
| `PAT` 对，但 `LIVE` 两次读**不变** | **PL 没有时钟**（`p2f_clk0` 没接进来）或计数器被优化掉 | 检查 `s_axi_aclk` 连线；查综合报告有无 "removed unused" |
| `PAT` 对，`LIVE` 在变 | 读通路 + PL 时钟都好 | 继续 |
| `SCR` 写进去读回**不一样** | 写通路坏 / `wstrb` 没处理 | 用整字写再试；看是不是只有低字节进去 |
| `SCR0` 和 `SCR1` 读回**相同值** | 地址译码串了（两个地址落到同一寄存器） | 查 `case (write_addr[7:0])` 的分支 |
| `SCR` 正常，`CMD/STATUS` 不动 | 握手 / 状态位方向错 | 看 `run_busy` 是否被置起 |
| `DONE=1` 但 `COUNT ≠ 0x100000` | 计数逻辑错 | 查 `RUN_TARGET` 比较与停止条件 |
| 访问没映射的地址不报错 | 从端没做 SLVERR | 本模块已做：未映射 → SLVERR |

> **这九行就是这张方案的全部意义。** 以后每加一个 PL 模块，都能用同一套流程定位"是 AXI 地基坏了还是我这个模块坏了"。

---

## 六、DI 集成步骤（TD 侧）

### 6.0 先看这道硬门槛：从端已经用满

实测 `soc_prj/uisrc/01_rtl/system/Design.xml`（2026-10-30 20:00）：

| 现场 | 实测值 | 含义 |
|---|---|---|
| `AXI_Matrix_0` / `AL_DS_NUM` | **3** | 三个下游口**全占满**，没有空位 |
| `AL_US_NUM` | 1 | 只有 PS 一个主（`M_AXI_GP0`） |
| `AL_DS_AXI_BASE_ADDR` | `192'h…80200000_…80100000_…80000000` | 三段 × 64 位打包，不是手填 |
| `AL_DS_AXI_ADDR_WIDTH` | `96'h…0C_…0C_…0C` | 每段 12 位 = **4 KB** |
| 已占地址 | `0x80000000` GPIO_0 ｜ `0x80100000` GPIO_1 ｜ `0x80200000` PWM | 相邻两个隔 1 MB |
| **下一个空位** | **`0x80300000`** | 与 `AXI_test.h` 的 `AXI_TEST_BASE` 一致 |

> ⚠️ **不加第 4 个从端，`0x80300000` 上就永远没有从端应答。** PS 读它就是一次「无人应答」的 AXI 访问：可能 DECERR 变 data abort，也可能被总线直接挂住 —— 表现是**开机卡死、连 `printf` 都不出**，看起来像板子坏了。
> 这正是 `main.c:135` 里 `AXI_TEST_BRINGUP` 默认写 `0` 的唯一原因。**从端没接好之前不要把它改成 1。**

---

### 6.1 放源文件 ✅ 已完成

```
soc_prj/uisrc/03_ip/AXI_test/AXI_test.v
```

跟 `axi_lite_pwm` 同级。已核对：UTF-8 无 BOM、LF 行尾、`module AXI_test` 与文件名一致。

> `.al` 工程文件里**不会**出现这个路径，这是正常的：`soc_prj.al` 只登记 `system_top.v` 和 `system.xml` 两项，`axi_lite_pwm.v` 也不在里面。IP 由 `system.xml` 递归带出，**不需要手动 Add Files**。

---

### 6.2 mpack 打包 ✅ 已完成（2026-10-30 20:14）

工具：`D:\exe\Anlu\TD\bin\mpack.exe`（GUI）。

| 项 | 值 |
|---|---|
| 源文件 | `soc_prj/uisrc/03_ip/AXI_test/AXI_test.v` |
| 顶层模块 | `AXI_test`（必须与文件名一致，否则找不到顶层） |
| 版本 | `1.0` |
| 输出目录 | `D:\FPGAproject\AnLuRun\PSPWM\ip_repo\AXI_test_1.0` |

> 输出位置不能随便挑：`Design.xml` 里 `axi_lite_pwm_0` 的 `ipPath` 写的是 `../../../../ip_repo/axi_lite_pwm_1.0`（相对 `uisrc/01_rtl/system/`，即 `PSPWM/ip_repo/`）。AXI_test 照同一位置放。

**打包后在 Ports 页必须核对：19 个端口全部在，且 `awaddr` / `araddr` 是 32 位。**
如果这两条被识别成 1 bit，说明参数化位宽又踩坑了 —— 但本次 RTL 已硬写 `[31:0]`，正常不会出现。

**19 个端口的正确位宽（2026-10-30 20:11 实测截图，逐项全对）**：

| 端口 | 方向 | 位宽 | 端口 | 方向 | 位宽 |
|---|---|---|---|---|---|
| `s_axi_aclk` | in | 1 | `s_axi_bready` | in | 1 |
| `s_axi_aresetn` | in | 1 | `s_axi_araddr` | in | **32** |
| `s_axi_awaddr` | in | **32** | `s_axi_arvalid` | in | 1 |
| `s_axi_awvalid` | in | 1 | `s_axi_arready` | out | 1 |
| `s_axi_awready` | out | 1 | `s_axi_rdata` | out | 32 |
| `s_axi_wdata` | in | 32 | `s_axi_rresp` | out | 2 |
| `s_axi_wstrb` | in | **4** | `s_axi_rvalid` | out | 1 |
| `s_axi_wvalid` | in | 1 | `s_axi_rready` | in | 1 |
| `s_axi_wready` | out | 1 | | | |
| `s_axi_bresp` | out | 2 | | | |
| `s_axi_bvalid` | out | 1 | | | |

三个必须确认的位宽：`awaddr`/`araddr` = **32**（不是 1，这是参数化位宽那个坑的报警灯）、`wstrb` = **4**、`bresp`/`rresp` = **2**。

---

#### ⚠️ 骨架陷阱：Ports 页显示对了 ≠ 文件写进去了

**2026-10-30 20:07 实测**：mpack 界面上 19 行端口全部正确，但磁盘上的 `Component.xml` 只有 **1,867 字节**：

```xml
<ipxact:moduleName></ipxact:moduleName>   ← 空
<ipxact:ports/>                            ← 空
```

它只是先落了个骨架，端口表还停在界面里没落盘。**这个状态做后续任何一步都是白做** —— 补出来的 busInterface 会指向一堆不存在的物理端口，不报错，但 DI 里照样连不上，而且比"没补"更难查（看起来已经补过了）。

**保存完成的判据（对比已验证的 `axi_lite_pwm_1.0`）**：

| 检查 | 骨架态 | 完成态 |
|---|---|---|
| `Component.xml` 大小 | 1,867 B | **约 20,000 B**（pwm 是 20,158 B） |
| `grep -c '<ipxact:port>'` | 0 | **19** |
| `grep 'moduleName'` | `<ipxact:moduleName></ipxact:moduleName>` | `<ipxact:moduleName>AXI_test</ipxact:moduleName>` |
| `signals.vrename`（旁证） | 已含 19 端口 + 参数 | 同左 |

> `signals.vrename` 是最早能看出"解析成功"的文件：本次实测 20:10 写入 463 B，19 个端口位宽全对，还带一行 `parameter 31:0 RUN_TARGET 32'h0010_0000` —— 说明 mpack 已经把 RTL 读懂了，只是 Component.xml 还没生成。**这个参数默认值 `0x00100000` 正好等于 `AXI_test.h` 的 `AT_RUN_TARGET`，不需要在 GUI 里改。**

动作：回 mpack 点 **File → Save**（或关窗口选保存），确认 `Component.xml` 涨到约 20 KB 再继续。

---

产物应是：

```
ip_repo/AXI_test_1.0/
├── AXI_test_1.0.pack            447 B
├── AXI_test_files/RTL/AXI_test.v  15,629 B（md5 与 03_ip 源一致：bfc3220f…）
├── Component.xml                约 20 KB ← 关键，见 6.3
├── Dependency.tcl               0 B（pwm 的也是 0，正常）
├── Layout.tcl                   0 B（同上）
└── signals.vrename              463 B
```

---

### 6.3 补 busInterface ✅ 已完成（2026-10-30 20:16）—— 最容易跳过、代价最大的一步

**mpack 生成的 `Component.xml` 里一条 `busInterface` 都没有。**

这不是猜测，是 2026-10-29 在 `axi_lite_pwm` 上实测的：`Component.xml.bak-20261029-pre-bus` 里 `busInterface` 出现 **0 次**，手工补完变成 **8 次**。

后果是**静默的**，不会报任何错：

- DI 画布上这个 IP 只有一个光秃秃的方块，**没有 `S_AXI` 粗蓝线可接**
- Address Editor 的从端列表里**根本看不到它**，地址也就无从分配

**做法：跑本次配套脚本。**

```
python 官方axi_gpio工程/pl_axi_ps/build_bus_if_axi_test.py
```

它做的事：从 TD 自带的 `AXI_GPIO_1.0/Component.xml` 抄三条 busInterface（`S_AXI_Lite`→`S_AXI`、`S_AXI_ACLK`、`S_AXI_AResetn`），再补 AXI_test 的 13 个寄存器作为 memoryMaps。**AXI_test 的 19 个端口名与 `axi_lite_pwm` 逐字相同，所以抄来的 portMap 一个物理端口都不用改。**

脚本自带五道保护 + 一组写入前自校验（前两道是 2026-10-30 用真实骨架件实测后补的）：

| 保护 | 触发条件 | 行为 |
|---|---|---|
| **骨架拦截** | `<ipxact:ports/>` 为空（mpack 没保存完） | 退出，并提示回 mpack 保存、文件应从 1.8 KB 涨到 20 KB |
| **顶层名拦截** | `<ipxact:moduleName>` 为空 | 退出 —— 空着 TD 找不到顶层，会实例化失败或生成空 wrapper |
| 端口体检 | 19 个端口有缺（**正则整词匹配**） | 列出缺谁并退出，替代人工核对 Ports 页 |
| 幂等 | 已含 `busInterface` 条目 | 直接退出，不重复写（mpack 重打包后再补也安全） |
| 锚点唯一 | 找不到唯一的 `<ipxact:model>` | 退出，不乱插 |
| **写入前自校验** | 见下 | 任何一条不满足就退出，**一个字节都不写** |

写入前自校验的四条（都是"XML 良构、TD 不报错，但 DI 里就是不通"那一类）：

| # | 检查 | 不通过的后果 |
|---|---|---|
| a | 每条 `physicalPort` 引用都能对上真实端口（空名=该 AXI 信号未使用，合法） | 接口连不上 |
| b | 每个 `memoryMapRef` 都有同名 `memoryMap` | **Address Editor 里从端没有 range** |
| c | 端口数没被插入破坏（仍 19） | 端口丢失 |
| d | XML 良构 | 整个 IP 加载失败 |

#### ⚠️ 6.3.1 实测踩到的坑：`memoryMapRef` 悬空

第一次跑完，文件结构、端口、寄存器全部正常，但验证时发现 `S_AXI` 里写着：

```xml
<ipxact:memoryMapRef memoryMapRef="axi_lite_slave"/>   ← 抄自 AXI_GPIO
```

而脚本当时把映射命名成 `axi_test_mm` —— **引用指向一个不存在的映射**。这是典型的静默故障：XML 良构、TD 不报错，但 DI 读不到地址块范围，Address Editor 里那个从端**没有 range**，表现是"接口有了、连不上，或者说不出为什么"。

修法不是去改引用（那要动抄来的整块内容），而是**让映射名跟着引用走**：脚本从 `memoryMapRef` 里把值读出来，用同一个名字命名 `memoryMap`，并加进写入前自校验 b。反向测试（把名字故意改成 `wrong_name`）已确认能被抓住：

```
ABORT: 写入前自校验失败：
      memoryMapRef="axi_lite_slave" 悬空，现有映射: ['wrong_name']
      未修改任何文件。
```

---

**2026-10-30 20:16 实跑结果（正式落盘）**

| 项 | 值 |
|---|---|
| `Component.xml` | 15,813 → **45,763 B** |
| `busInterface` 条目 | 0 → **3**（`S_AXI` / `S_AXI_ACLK` / `S_AXI_AResetn`） |
| `memoryMap` | **1**（名 `axi_lite_slave`，与引用一致） |
| 寄存器 | **13** 个，偏移/权限与 RTL 逐个对齐 |
| 端口 | 19 → **19**（未被破坏） |
| `physicalPort` 引用 | 19 条全部指向真实端口；另 34 条空名 = AXI4 全协议独有的信号（AWLEN/AWSIZE/RID/RLAST…），AXI4-Lite 没有，留空是对的 |
| 行尾 | 全 CRLF，裸 LF = 0 |
| XML | 良构 |

> **最强的一条交叉佐证**：把生成物与已验证可用的 `axi_lite_pwm_1.0/Component.xml` 做元素名序列比对，**前 500 个元素完全一致**（覆盖 busInterfaces 与 memoryMaps 全部段落）。总元素数 1,207 vs 1,331，差额来自 pwm 多 3 个端口 + 多 1 个寄存器 + 3 个 moduleParameter。

已做的验证（8 项全过）：

| 用例 | 输入 | 预期 | 实测 |
|---|---|---|---|
| 正向 | mpack 完整件 | 写入，`busInterface`=8 次、CRLF 统一 | ✅ 20,158 → 50,105 B |
| **骨架** | **真实 AXI_test 骨架件** | 退出并报"还是骨架" | ✅ 正确报 1,867 B |
| **顶层名空** | 端口齐但 `moduleName` 空 | 退出并报顶层名 | ✅ |
| 幂等 | 已补过的件 | 退出提示已含接口 | ✅ |
| 反向·端口 | 把 `s_axi_rready` 改坏 | 退出列出缺失端口 | ✅ |
| **反向·映射** | **`mm_name` 改成 `wrong_name`** | **自校验报悬空引用** | ✅ |
| 预演 | `--dry-run` | 只校验不落盘 | ✅ |
| **实跑** | **真实 AXI_test 完整件** | 写入且七项校验全过 | ✅ 15,813 → 45,763 B |

> 端口体检第一版用子串匹配，反向测试发现 `s_axi_rready_x` 仍"包含" `s_axi_rready` ⇒ 漏报。改成整词正则 `(?<![A-Za-z0-9_])name(?![A-Za-z0-9_])` 后通过。**这就是为什么要做反向测试：正向测试永远只会告诉你"没报错"。**

> ⛔ **补完之后不要再用 mpack 打开并保存这个 IP。** mpack 保存会**整体重写** `Component.xml`，把 `busInterfaces` / `memoryMaps` 全部抹掉，AXI 连接当场消失（不是编译错，是 DI 里那根线没了，很难往这上面想）。
> 要改 RTL 就改 `.v` → mpack 重新打包 → 重跑本脚本 → DI 里重新生成 design。
> 补接口前的状态已备份在 `ip_repo/AXI_test_1.0/Component.xml.bak-20261030-pre-bus`（15,813 B），要重来时直接覆盖回去。

---

### 6.4 矩阵从端数 3 → 4

**双击 `AXI_Matrix_0`** → IP 配置对话框。左树分组（2026-10-29 实测界面）：`Basic Settings` / `Protocol Sel` / `User Signals` / `Matrix Options` / `US Arbitration Priority` / … / `DS_00…DS_15` / `US_00…US_15`。

| 位置 | 字段（**界面显示名**） | 改成 |
|---|---|---|
| `Basic Settings` 组 | **`Number of DS(downstream) Interface`**（参数名 `AL_DS_NUM`，当前 3） | **4** |
| `DS_03` 组 | **`Base Address00(0x)`**（默认 `0000000000300000`） | **`0000000080300000`** |
| `DS_03` 组 | `Address Space Width00`（默认已是 `12`） | **不用动** |

> 字段名与 TD 文档措辞不同：GUI 上是 `Base Address00(0x)` / `Address Space Width00`，底层才是 `DS3_BASEADDR0` / `DS3_BASEADDR_WIDTH0`。未使用的行显示 `FFFFFFFFFFFFFFFF`（= 无地址映射），保持原样。

> ⚠️ **`DS_03` 的默认值 `0x00300000` 必须改，不能留。** 矩阵是按「US 侧完整 32 位地址」与各 DS 的基址+宽度做译码。若 `DS_03` 留 `0x00300000`，则 PS 写 `0x80300000` 四段都不命中 ⇒ 无从端应答 ⇒ PS 读挂死 / 总线报错，而现场表现极像「AXI_test 的寄存器没实现」—— 会白查很久。

- 改完 Diagram 上应多出 `DS_AXI3`，原有 `DS_AXI0/1/2` 连线**不应断开**（断了自己重连，网络名不变）。
- ⚠️ 128/64 位打包参数（`AL_DS_AXI_BASE_ADDR` 变 256 位、`AL_DS_AXI_ADDR_WIDTH` 变 128 位、`AL_AXI_READ/WRITE_CONNECTIVITY`）**由工具按上面三个字段自动重算，不要手填**。

---

### 6.5 加协议转换器

矩阵的下游口是 AXI4 全协议，AXI_test 是 AXI4-Lite，中间必须有一个转换器 —— 现有三个从端各配一个（`AXI_Protocol_Converter_0/1/2` ↔ GPIO_0/1/pwm_0），AXI_test 同理。

> ⛔ **`Ctrl+C` / `Ctrl+V` 不可用**（2026-10-29 实测）：粘贴出来的是 IpTool 配置窗，`Component Name` 仍是被复制的那个老实例，底部红字 `Customization changes are not allowed` —— DI 把 Ctrl+V 解释成「打开已有实例」，且已生成过的实例不允许再改参数。

**正确做法：IP+ 新建。**

1. 工具栏 **IP+** → 搜 `AXI_Protocol_Converter` → 双击添加
2. `Component Name` 改为 **`system_AXI_Protocol_Converter_3`**（必须以 `_3` 结尾，用默认名会与 `_0/_1/_2` 冲突）
3. 只改下表两个参数，**其余保持默认**

| 参数 | IP 默认值 | **必须改成** | 为什么 |
|---|---|---|---|
| `AL_AXI_ID_WIDTH` | **4** | **12** | 矩阵侧 `DS_AXI*` 的 ID 是 12 位（矩阵 `AL_AXI_ID_WIDTH=13`、`AL_AXI_ID_WIDTH_USER=12`）；4 接 12 位宽不匹配 |
| `AL_AXI_SUPPORTS_USER_SIGNALS` | **0** | **1** | 与 `Converter_0/1/2` 一致；设 0 后 `US_AXI` 不带 USER 信号，与矩阵侧总线视图不一致 |

其余默认值已与现有实例相同，**不要动**：`AL_AXI_ADDR_WIDTH=32`、`AL_AXI_DATA_WIDTH=32`、`AL_US_AXI_PROTOCOL=AXI4`、`AL_DS_AXI_PROTOCOL=AXI4LITE`、`READ_WRITE_Mode=READ_WRITE`、`ds_axi_awlen_de=7`、`us_axi_awlen_de=7`、`aximm_us=1`、`aximm_ds=0`。

---

### 6.6 加 AXI_test 实例

**IP+** → 搜 `AXI_test`（User IP 分类，需先确认 6.2/6.3 已完成）→ 双击添加。实例名形如 `system_AXI_test_0`。

> 若搜不到：DI 的 User IP 库没刷新。先确认 `ip_repo/AXI_test_1.0/Component.xml` 存在且含 `busInterfaces`（`grep -c busInterface` 应为 8），再在 DI 里刷新 IP 库。

---

### 6.7 连线（6 条）

| # | 连接 | 端点 | 说明 |
|---|---|---|---|
| ① | bus | `AXI_Matrix_0 .DS_AXI3` ↔ `AXI_Protocol_Converter_3 .US_AXI` | 矩阵第 4 个下游口，粗蓝线 |
| ② | bus | `AXI_Protocol_Converter_3 .DS_AXI` ↔ `AXI_test_0 .S_AXI` | 粗蓝线；**没有这条线，说明 6.3 没做或没生效** |
| ③ | 细线 | `ARM_Processor_System_0 .p2f_clk0` → `Converter_3 .aclk` | |
| ④ | 细线 | `ARM_Processor_System_0 .p2f_rst0_n` → `Converter_3 .aresetn` | |
| ⑤ | 细线 | `ARM_Processor_System_0 .p2f_clk0` → `AXI_test_0 .s_axi_aclk` | 本工程实测 **199.98 MHz** |
| ⑥ | 细线 | `ARM_Processor_System_0 .p2f_rst0_n` → `AXI_test_0 .s_axi_aresetn` | 低有效 |

**画布上实测的端口名**：转换器 `US_AXI` / `aclk` / `aresetn` / `DS_AXI`；AXI_test `S_AXI` / `s_axi_aclk` / `s_axi_aresetn`（本模块无任何对外引脚，所以**不需要导出 design port**，这是它与 PWM 的唯一操作差别）。

> ③~⑥ 必须接到与 `AXI_GPIO_0/1`、`Converter_0/1/2` 同一根网（`w_net__ARM_Processor_System_0__p2f_clk0` / `..._p2f_rst0_n`）。DI 提示「复用现有网络」时**选复用**；若一个源引脚不允许挂第二根线，就**从已有那根线上拖出支线**（在导线上按住拖到目标引脚）。

---

### 6.8 配地址 + 生成 + 复核

Address Editor 里应出现第 4 条：

| Slave | Interface | Base | Range | High |
|---|---|---|---|---|
| `AXI_GPIO_0` | `S_AXI_Lite` | `0x8000_0000` | 4 K | `0x8000_0FFF` |
| `AXI_GPIO_1` | `S_AXI_Lite` | `0x8010_0000` | 4 K | `0x8010_0FFF` |
| `axi_lite_pwm_0` | `S_AXI` | `0x8020_0000` | 4 K | `0x8020_0FFF` |
| **`AXI_test_0`** | **`S_AXI`** | **`0x8030_0000`** | **4 K** | **`0x8030_0FFF`** |

- `Auto Assign` **不要勾**（会重排既有窗口，C 代码里写死的 `0x80200000` 当场失效）
- **连完线时 `DS_AXI3` 会挂在 Address Editor 的 `Incomplete Paths` 分组下** —— 这是正常的中间态（矩阵下游口出去了，但还没接到从端）。接上 `Converter_3.DS_AXI ↔ AXI_test_0.S_AXI` 后，这条会自己移进 `Data` 分组。**它没移过去就说明那根粗蓝线没连上。**
- 先跑 **Design 检查**（时钟检查 / 复位检查 / 地址空间检查），**确认无红项**
- 再 **生成 design**

---

#### ⚠️ 6.8.1 实测：Address Editor 的分配**不会**写回矩阵参数

2026-10-30 20:51 生成后的真实读数：

| 来源 | DS3 的基址 | 状态 |
|---|---|---|
| `system.address.xml`（Address Editor 分配） | `AXI_test_0 @ 0x80300000 ~ 0x80300FFF` | ✅ 对 |
| `Design.xml` 的 `DS3_BASEADDR0` | `0000000000300000`（= `0x00300000`） | ❌ **还是 IP 默认值** |
| `AL_DS_AXI_BASE_ADDR`（256 位打包） | `256'h0000000000300000_…80200000_…80100000_…80000000` | ❌ 第 4 段没跟着变 |

**两处各写各的。** 矩阵按 `DS*_BASEADDR` 做译码，所以 PS 写 `0x80300000` 时四段都不命中 ⇒ 无从端应答 ⇒ 总线挂死或 DECERR，**现场极像"AXI_test 的寄存器没实现"**。

> 10-29 那次加 PWM 没出这问题，纯属运气：`DS_02` 基址是**提前在 IP 配置里填好**的，Address Editor 直接沿用，两处天然一致。这次 `DS_03` 没提前填，就露出来了。
> **结论：`DS_0n` 基址必须在双击矩阵时就填对，不能指望 Address Editor 回写。**

修法：双击 `AXI_Matrix_0` → `DS_03` 组 → `Base Address00(0x)`：`0000000000300000` → **`0000000080300000`** → 重新生成 design。

---

#### 6.8.2 生成后复核：直接跑脚本

```
python tools/check_axi_map.py -v
```

`PSPWM/tools/check_axi_map.py`（本次新建）做六项交叉检查，覆盖"人眼看不出"的那几类：

| 项 | 检查 | 级别 |
|---|---|---|
| F1 | 地址表条数 == `AL_DS_NUM` | FAIL |
| F2 | 每个从端的基址，都能在矩阵的 `DSn_BASEADDR0` 里找到（**就是抓 6.8.1 那个坑**） | FAIL |
| F3 | `AL_DS_AXI_BASE_ADDR` 解出来的段 == 各 `DSn_BASEADDR0` | FAIL |
| F4 | 地址窗口互不重叠 | FAIL |
| F5 | C 代码写死的基址（`AXI_TEST_BASE` / `AXI_PWM_BASE`）== 地址表 | FAIL |
| W1 | 转换器 ID 宽度 12 == 矩阵 DS 侧 13−1 | WARN |

退出码 `0` = 无 FAIL，`1` = 有 FAIL，`2` = 找不到文件。

本次实跑输出（修之前）：

```
OK    F1 地址表 4 条 == AL_DS_NUM 4
FAIL  F2 有 1 个从端分配的地址，矩阵没有哪个 DS 解得了：
        AXI_test_0         0x80300000  ← 矩阵里找不到这段
        矩阵里没用上的 DS：DS3=0x00300000

        修法：双击 AXI_Matrix_0 → DS_03 组 → Base Address00(0x)
              把 0000000000300000 改成 0000000080300000，然后重新生成 design。
              注意 Address Editor 的分配不会自动写回矩阵参数。
OK    F3 打包参数 4 段与逐项参数一致
OK    F4 4 个窗口互不重叠
OK    F5 C 侧基址与地址表一致（2 项）
OK    W1 转换器 ID 宽度 12 位 == 矩阵 DS 侧 13-1

明细：
  从端                   base           high           矩阵对应
  AXI_GPIO_0           0x80000000     0x80000FFF     DS0
  AXI_GPIO_1           0x80100000     0x80100FFF     DS1
  axi_lite_pwm_0       0x80200000     0x80200FFF     DS2
  AXI_test_0           0x80300000     0x80300FFF     —

结果：1 项 FAIL，0 项 WARN —— 先修 FAIL，别综合。
```

脚本自身验证过 6 组用例：真实故障态（退出码 1）、修正态（退出码 0）、C 基址写错（F5 命中）、窗口重叠（F4 命中）、`-v` 明细、找不到文件（退出码 2）。

> 写这脚本时踩过一个坑，记下来：第一版用一条跨段大正则捞"displayName + baseAddress + highAddress"，结果把主口 `ARM_Processor_System_0` 的 displayName 和 baseAddress 配成了第一个从端 —— 因为它的 base `0x80000000` 恰好等于 `AXI_GPIO_0` 的 base，**数字看着对、名字错了**。现在改成按 `<ipxact:addressDest>` 逐块切。

---

#### 6.8.3 人工复核三项（脚本之外再看一眼）

| # | 查什么 | 期望（2026-10-30 20:51 实测） |
|---|---|---|
| 1 | `system.address.xml` | 4 条 `addressDest`，第 4 条 `AXI_test_0` = `0x80300000 ~ 0x80300FFF` ✅ |
| 2 | `Design.xml` 的 `AXI_Matrix_0` | `AL_DS_NUM=4` ✅；`AL_DS_AXI_BASE_ADDR` 位数 **256** ✅、`AL_DS_AXI_ADDR_WIDTH` **128** ✅；但 `DS3_BASEADDR0` **错**，见 6.8.1 |
| 3 | `hdl/system.v` | `AXI_test_0` 实例在 ✅；`s_axi_aclk = p2f_clk0`（第 1177 行）、`s_axi_aresetn = p2f_rst0_n`（第 1192 行）✅；`ip/system_AXI_test_0/` 已生成 ✅ |

#### 6.8.4 关于 `system.violation` 里那 4 个 `[error]`

生成后 `system.violation` 有 **4 个 error**，都是同一种：

```
[error - PortConnection] AXI ID port width inconsistency
    SocInstPort output:AXI_Matrix_0::DS_AXI0::ds0_arid[12:0]
    SocInstPort input:AXI_Protocol_Converter_0::US_AXI::us_axi_awid[11:0]
```

**这不是本次改动引入的**：DS0/DS1/DS2 三条一模一样的报错，在 10-29 那次生成时就有，而 PWM 已经在板上跑通了。原因是矩阵 `AL_AXI_ID_WIDTH=13`（12 位用户 ID + 1 位 DS 路由），转换器 `AL_AXI_ID_WIDTH=12`。

TD 的处置是**静默截掉最高位**，生成为：

```verilog
assign w_port__AXI_Protocol_Converter_0__us_axi_arid =
       w_net__AXI_Matrix_0__ds0_arid ;   // 13 位赋给 12 位
```

单主系统里 ID 只是事务标签，少一位不影响功能；只有当 PS 上有超过 2048 笔并发未完成事务时才可能别名 —— 本工程不会到。

**所以这 4 个 error 不阻塞综合，但要知道它在那里。** 想让报错清零的唯一办法是把矩阵的 `AL_AXI_ID_WIDTH_USER` 也降到 12（使 DS 侧变 12 位），那是改既有工作配置，风险大于收益，**不建议动**。

---

### 6.9 三条禁令

| 禁令 | 原因 |
|---|---|
| 不要用 `Ctrl+C/V` 复制 IP 实例 | 只打开已有实例的配置窗，且 `Customization changes are not allowed` |
| 不要用 mpack 重新打开并保存已补过接口的 IP | 会抹掉 `busInterfaces`，AXI 线消失 |
| 不要勾 `Auto Assign` | 会重排既有三个从端的窗口，C 代码里的 `0x80200000` 当场失效 |

---

### 6.10 两个必须照抄的坑（`axi_lite_pwm.v` 上踩过，已写进 RTL 注释）

| 坑 | 后果 | 做法 |
|---|---|---|
| 地址端口写成 `[C_S_AXI_ADDR_WIDTH-1:0]` | Module Packager 无法 elaborate 参数化范围，把端口报成 **1 bit**，DI 里 AXI 连接**直接断** | 地址端口**硬写 `[31:0]`**，宽度参数只做记账 |
| 参数出现在端口范围表达式里 | 同上 | 参数只用来定常量（如 `RUN_TARGET`），不进端口 |

---

## 七、PS 侧测试程序

写法对齐工程里已有的 `TIM_PWM.c/.h`（基址放 .h，访问宏放 .c），这样风格统一、以后好维护。
建议同样拆成 `AXI_test.h` + `AXI_test.c` 两个文件——`axi_intr/Makefile:37` 用 `find` 自动收 `.c`，**不用改 Makefile**。

### 7.1 `AXI_test.h`

```c
#ifndef AXI_TEST_H
#define AXI_TEST_H

#include "ui_type.h"

/* 基址由 DI 的 Address Editor 分配，与 axi_lite_pwm(0x80200000) 不重叠 */
#define AXI_TEST_BASE       0x80300000U

#define AT_ID               0x00U
#define AT_VER              0x04U
#define AT_SCR0             0x08U
#define AT_SCR1             0x0CU
#define AT_LIVE_LO          0x10U
#define AT_LIVE_HI          0x14U
#define AT_PAT0             0x18U
#define AT_PAT1             0x1CU
#define AT_PAT2             0x20U
#define AT_PAT3             0x24U
#define AT_CMD              0x28U
#define AT_STATUS           0x2CU
#define AT_COUNT            0x30U

#define AT_ID_VALUE         0x41584954U     /* "AXIT" */
#define AT_VER_VALUE        0x00010000U
#define AT_RUN_TARGET       0x00100000U     /* 与 RTL 的 RUN_TARGET 保持一致 */

/* 返回 0 = 全部通过，非 0 = 失败项数 */
int AXI_Test_Bringup(void);

#endif /* AXI_TEST_H */
```

### 7.2 `AXI_test.c`

```c
#include <stdio.h>
#include "ui_io.h"          /* UI_In32 / UI_Out32 */
#include "AXI_test.h"

/* 与 TIM_PWM.c 同一套写法：先加偏移，再转 (void *) */
#define AT_RD(off)          UI_In32((void *)(AXI_TEST_BASE + (u32)(off)))
#define AT_WR(off, val)     UI_Out32((void *)(AXI_TEST_BASE + (u32)(off)), (u32)(val))

int AXI_Test_Bringup(void)
{
    u32 v, v2, lo, hi;
    volatile u32 i;
    int fail = 0;
    int guard;

    printf("\r\n===== AXI_test bring-up =====\r\n");
    printf("base = 0x%08X  target = %u\r\n",
           (unsigned)AXI_TEST_BASE, (unsigned)AT_RUN_TARGET);

    /* ---- ① 读通路：ID / VER / PAT ---- */
    v = AT_RD(AT_ID);
    printf("[1] ID  = 0x%08X (expect 0x41584954) %s\r\n",
           (unsigned)v, (v == AT_ID_VALUE) ? "OK" : "FAIL");
    if (v != AT_ID_VALUE) fail++;

    v = AT_RD(AT_VER);
    printf("    VER = 0x%08X (expect 0x00010000) %s\r\n",
           (unsigned)v, (v == AT_VER_VALUE) ? "OK" : "FAIL");
    if (v != AT_VER_VALUE) fail++;

    v  = AT_RD(AT_PAT0);
    v2 = AT_RD(AT_PAT1);
    printf("    PAT = %08X %08X", (unsigned)v, (unsigned)v2);
    if (v != 0xA5A50000U || v2 != 0xA5A50001U) fail++;
    v  = AT_RD(AT_PAT2);
    v2 = AT_RD(AT_PAT3);
    printf(" %08X %08X\r\n", (unsigned)v, (unsigned)v2);
    if (v != 0x5A5A0002U || v2 != 0x5A5A0003U) fail++;

    /* ---- ② 写通路：两组写不同值，顺便排除"两个地址落到同一寄存器" ---- */
    AT_WR(AT_SCR0, 0xDEADBEEFU);
    AT_WR(AT_SCR1, 0x12345678U);
    v  = AT_RD(AT_SCR0);
    v2 = AT_RD(AT_SCR1);
    printf("[2] SCR0 = 0x%08X (expect DEADBEEF) %s\r\n",
           (unsigned)v,  (v  == 0xDEADBEEFU) ? "OK" : "FAIL");
    printf("    SCR1 = 0x%08X (expect 12345678) %s\r\n",
           (unsigned)v2, (v2 == 0x12345678U) ? "OK" : "FAIL");
    if (v != 0xDEADBEEFU || v2 != 0x12345678U) fail++;

    /* ---- ② 附：字节选通。只写 byte0，另外三个字节必须保持 0 ---- */
    AT_WR(AT_SCR0, 0x00000000U);
    *(volatile u8 *)(AXI_TEST_BASE + (u32)AT_SCR0) = (u8)0xAA;
    v = AT_RD(AT_SCR0);
    printf("    byte-strobe: SCR0 = 0x%08X (expect 000000AA) %s\r\n",
           (unsigned)v, (v == 0x000000AAU) ? "OK" : "FAIL");
    if (v != 0x000000AAU) fail++;

    /* ---- ③ PL 产数据：连读两次必须不同，否则说明 PL 没有时钟 ---- */
    lo = AT_RD(AT_LIVE_LO);
    for (i = 0; i < 1000U; i++) { }        /* 空转，拉开两次读的间隔 */
    hi = AT_RD(AT_LIVE_LO);
    printf("[3] LIVE_LO: %u -> %u  %s\r\n",
           (unsigned)lo, (unsigned)hi,
           (lo != hi) ? "OK (PL clock is running)" : "FAIL (counter frozen)");
    if (lo == hi) fail++;

    /* ---- ④ 握手：CLR -> 检查空 -> START -> 轮询 DONE -> 读 COUNT ---- */
    AT_WR(AT_CMD, 0x00000002U);            /* CLR */
    v = AT_RD(AT_STATUS);
    printf("[4] after CLR: STATUS = 0x%08X (expect 0x00000000) %s\r\n",
           (unsigned)v, (v == 0U) ? "OK" : "FAIL");
    if (v != 0U) fail++;

    AT_WR(AT_CMD, 0x00000001U);            /* START */
    v = AT_RD(AT_STATUS);
    printf("    just after START: STATUS = 0x%08X\r\n", (unsigned)v);
    if ((v & 0x1U) == 0U)
        printf("    -> BUSY not observed (target too small? polling too slow?)\r\n");

    guard = 0;
    do {
        v = AT_RD(AT_STATUS);
    } while (((v & 0x2U) == 0U) && (++guard < 2000000));

    if (guard >= 2000000) {
        printf("    -> TIMEOUT waiting DONE, STATUS = 0x%08X\r\n", (unsigned)v);
        fail++;
    } else {
        printf("    DONE after %d polls, STATUS = 0x%08X\r\n",
               guard, (unsigned)v);
    }

    v = AT_RD(AT_COUNT);
    printf("    COUNT = %u (expect %u) %s\r\n",
           (unsigned)v, (unsigned)AT_RUN_TARGET,
           (v == AT_RUN_TARGET) ? "OK" : "FAIL");
    if (v != AT_RUN_TARGET) fail++;

    printf("===== AXI_test %s (%d failure) =====\r\n\r\n",
           (fail == 0) ? "PASSED" : "FAILED", fail);
    return fail;
}
```

### 7.3 调用位置 ✅ 已接入（2026-10-30 21:00）

`main.c` 三处改动，均已落地：

| 位置 | 内容 |
|---|---|
| 第 95 行 | `#include "AXI_test.h"` |
| 第 141 行 | `#define AXI_TEST_BRINGUP 1`（原为 0，四个前提全部完成后打开） |
| 第 337–343 行 | `#if AXI_TEST_BRINGUP` 块内调用 `AXI_Test_Bringup()` |

```c
#if AXI_TEST_BRINGUP
    if (AXI_Test_Bringup() != 0U) {
        printf("!! AXI_test FAILED -- PWM 测试大概率也会失败\r\n");
        printf("!! 依次查：DI 里 S_AXI 连没连 / 地址是否 0x80300000 / p2f_clk0 到没到 PL\r\n");
        StatBlink(5U, 60U, 60U);
    }
#endif
```

**放在 `printf("===== AXI PWM bring-up =====")` 之前** —— 先验地基，再验业务。失败不 `return`，让 PWM 继续跑，多留一份现象。

> 验证方式：用真实的 `aarch64-none-elf-gcc`（gcc 13.2.1）做 `-fsyntax-only -Wall -Wextra`，**0 错 0 警**；再用 `-E` 预处理确认 `if (AXI_Test_Bringup() != 0U)` 真的出现在展开结果里 —— 证明它没被 `#if` 吃掉，是真实编译进去的，不是"因为被注释掉所以编过"。
> 备份：`main.c.bak-20261030`（26,381 B，开关为 0 的版本）。

#### ⚠️ 7.3.1 接入后第一次 Build 的「72 错」不是这段代码的锅

本节接完（21:00）后直接在 FD 点 Build，报 **72 errors**，错误全落在 `al_mpu.c` / `al_log.c` 这些 SDK 文件里，`AXI_test.c` / `main.c` 反而一个错都没有。

根因是另一件事：FD 的 `Regenerate BSP Sources` 只做了拷贝、没做注入，`soc_plat.h` 少了 16 行 `HAVE_*_DRIVER`，`al_hal.h` 的 19 个 `#ifdef` 全不成立。

```bash
cd D:/FPGAproject/AnLuRun/PSPWM
python tools/check_soc_plat.py --fix     # 一条命令自愈，先备份再改
```

详细机理、判据与处置顺序见排障记录：
<D:\项目\FPGA工程\03-排障记录\BSP导入问题\BSP平台头注入缺失-编译72错-20261030.md>

> **一句话判别**：错误全在 SDK 的 `al_*.c` 里、且报的是「类型未定义 / 常量未声明」，先查平台头，别查自己刚写的代码。

---

## 八、验收判据

全部通过才算"AXI 地基可用"：

| # | 判据 | 通过标准 |
|---|---|---|
| 1 | `ID` | `0x41584954` |
| 2 | `VER` / `PAT0–3` | 与表一致 |
| 3 | `SCR0` / `SCR1` | 写入值与读回值相同，且**两组互不相同** |
| 4 | 字节选通 | 只写 byte0 后为 `0x000000AA` |
| 5 | `LIVE_LO` | **连续两次读不同** |
| 6 | `STATUS` | CLR 后为 0；START 后 `bit0=1`；最终 `bit1=1` |
| 7 | `COUNT` | `== 1048576` |

**任一 FAIL 都不要往下做**——后面所有 PL 模块都建立在这条通路上。

---

## 九、已知不确定项（实施时先确认，别等出错才发现）

前三条已于 2026-10-30 20:00 查证关闭，保留编号以便与旧记录对照：

| # | 事项 | 结论 / 怎么确认 |
|---|---|---|
| 1 | GP0 上是否还有空闲的 AXI 从端槽位 | ✅ **没有**。`AL_DS_NUM=3`，三个下游口全占满 ⇒ 必须先改 4（§6.4） |
| 2 | `0x80300000` 是否真正空闲 | ✅ **空闲**。现有三段止于 `0x80200FFF`，`0x80300000` 未占用 |
| 3 | 加第四个从端后，是否影响已有 PWM 地址 | ⚠️ 生成后必须复核，PWM 必须仍是 `0x80200000`（§6.8 第 1 项） |
| 4 | `wstrb` 在 GP0 路径上是否被保留 | 本模块的字节选通测试就是来验这个的（判据 4） |
| 5 | 计数器在综合里会不会被优化掉 | `LIVE` 有 AXI 读路径，正常不会被删；若两次读不变，先查综合 warning |
| 6 | mpack 打包后 `Component.xml` 有无 `busInterface` | ❌ **不会有**（`axi_lite_pwm` 上实测 0 条）。必须跑 `build_bus_if_axi_test.py`（§6.3） |
| 7 | 类名 `AXI_test` 大小写是否影响 mpack | ✅ **不影响**。2026-10-30 实测 mpack 正常识别，`<ipxact:name>AXI_test</ipxact:name>`、fileSet `AXI_test_files`、`signals.vrename` 第一行 `module AXI_test` 全部正确 |

---

## 十、这一步之后

`AXI_test` 只是地基。它通过后，后面每个真正的外设模块都按同一套路走：

```
寄存器映射 → 复用这套 AXI-Lite 骨架 → 只写业务逻辑（PWM / 图像 / 传感器）
```

**并且可以把这个模块留在工程里长期不删**——它占的资源极少（十几条 AXI 逻辑 + 一个 64 位计数器），却能让你在任何时候用一条命令确认"AXI 地基还好着"。真要省资源，验收通过后也可以直接摘掉，两者都行。

## 标签

#PS侧总控 #AXI4-Lite #PL从端 #安路DR1 #通路验证
