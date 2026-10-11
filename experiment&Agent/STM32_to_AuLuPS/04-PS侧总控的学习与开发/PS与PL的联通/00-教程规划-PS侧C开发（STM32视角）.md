# PS 侧 C 语言开发教程规划 · 从 STM32 到 `fdma_en`

> 工程：`04-PS侧总控的学习与开发/PS与PL的联通` ｜ 平台：MLK-F3P-CZ02 + DR1M90GEG400（PS = 双核 Cortex-A35）
> 源码依据：`GetStabilityPS(base-fdma_en)/稳定的平台存档/mipiHDMIbySD/soc_sdk/`（只读引用，不在本目录改动）
> 本文以图为主，逐节解释「STM32 里的那个东西，在安路 PS 上叫什么、怎么写」，并给出**可直接照做的学习路线**。

---

## 一、图：STM32 → 安路 PS 的认知映射

你最大的障碍不是"不会写 C"，而是**找不到熟悉的地标**。这张图把 STM32 的地标一一定位到安路 PS 上。

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 394" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>STM32 写法与安路 PS 写法的逐条映射</title>
<desc>左列是 STM32 HAL 的常用写法，右列是安路 PS 的对应写法，中间用箭头连接；其中 CubeMX 图形化配置在安路侧没有对应物，需要手写初始化结构体</desc>
<defs>
<marker id="m1" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>
<rect x="40" y="30" width="250" height="30" rx="6" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="165" y="50" font-size="12" font-weight="500" fill="#444441" text-anchor="middle">STM32 的写法（你会的）</text>
<rect x="390" y="30" width="250" height="30" rx="6" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="515" y="50" font-size="12" font-weight="500" fill="#0C447C" text-anchor="middle">安路 PS 的写法（要学的）</text>
<rect x="40" y="70" width="250" height="38" rx="6" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="52" y="94" font-size="11" fill="#444441">HAL_GPIO_WritePin(GPIOA, PIN_5, 1)</text>
<line x1="292" y1="89" x2="386" y2="89" stroke="#888780" stroke-width="1.5" marker-end="url(#m1)"/>
<rect x="390" y="70" width="250" height="38" rx="6" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="402" y="94" font-size="11" fill="#0C447C">AlGpio_Hal_WritePin(h, Pin, 1)</text>
<rect x="40" y="116" width="250" height="38" rx="6" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="52" y="140" font-size="11" fill="#444441">HAL_UART_Transmit(&amp;huart, buf, len, t)</text>
<line x1="292" y1="135" x2="386" y2="135" stroke="#888780" stroke-width="1.5" marker-end="url(#m1)"/>
<rect x="390" y="116" width="250" height="38" rx="6" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="402" y="140" font-size="11" fill="#0C447C">AlUart_Hal_SendData(h, buf, len)</text>
<rect x="40" y="162" width="250" height="38" rx="6" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="52" y="186" font-size="11" fill="#444441">HAL_TIM_PWM_Start(&amp;htim, CH1)</text>
<line x1="292" y1="181" x2="386" y2="181" stroke="#888780" stroke-width="1.5" marker-end="url(#m1)"/>
<rect x="390" y="162" width="250" height="38" rx="6" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="402" y="186" font-size="11" fill="#0C447C">AlTc_Hal_EnableWaveOutput(h, 1)</text>
<rect x="40" y="208" width="250" height="38" rx="6" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="52" y="232" font-size="11" fill="#444441">HAL_I2C_Master_Transmit(..)</text>
<line x1="292" y1="227" x2="386" y2="227" stroke="#888780" stroke-width="1.5" marker-end="url(#m1)"/>
<rect x="390" y="208" width="250" height="38" rx="6" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="402" y="232" font-size="11" fill="#0C447C">AlIic_Hal_MasterSendDataBlock(..)</text>
<rect x="40" y="254" width="250" height="38" rx="6" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="52" y="278" font-size="11" fill="#444441">HAL_NVIC_EnableIRQ(IRQn)</text>
<line x1="292" y1="273" x2="386" y2="273" stroke="#888780" stroke-width="1.5" marker-end="url(#m1)"/>
<rect x="390" y="254" width="250" height="38" rx="6" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="402" y="278" font-size="11" fill="#0C447C">AlIntr_RegHandler(IntrId, ..)</text>
<rect x="40" y="300" width="250" height="38" rx="6" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="52" y="324" font-size="11" fill="#444441">CubeMX 图形化生成初始化代码</text>
<line x1="292" y1="319" x2="386" y2="319" stroke="#888780" stroke-width="1.5" stroke-dasharray="5 4"/>
<rect x="390" y="300" width="250" height="38" rx="6" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="402" y="324" font-size="11" fill="#C83C3C">无对应物——手写 Init 结构体</text>
<text x="40" y="358" font-size="11" fill="#5F5E5A">注 1：虚线那一行是本教程最大的认知落差——没有图形化配置工具，一切配置都要自己写进结构体。</text>
<text x="40" y="374" font-size="11" fill="#5F5E5A">注 2：另两条常用映射：HAL_Delay → AlSys_MDelay；*(volatile uint32_t *) → UI_In32 / UI_Out32。</text>
</svg>

**读图口诀**：左边是你已经会的东西（⚪ 灰卡），右边是要学的东西（🔵 蓝卡），中间的箭头就是"换个名字"。**六条里有五条是一一对应的**，唯一真正缺失的是 CubeMX（虚线那一行）——而它缺失的后果很有限：只是初始化代码要手写 10 行而已。

> **最重要的结论先给出来**：**安路 PS 侧不是"没有库"，而是有库、且分层与 STM32 同构**。它只是把 `HAL_` 前缀换成了 `Al*_Hal_`、把 `LL_` 换成了 `Al*_ll_`，并且没有 CubeMX 代劳。你缺的是**索引**，不是能力。

---

## 二、一句话总览

**PS 侧的 SDK 就是一套"换了字母的 STM32 HAL"：`HAL_GPIO_WritePin` 变成 `AlGpio_Hal_WritePin`，`.c` 文件丢进 `fdma_en/` 就自动参与编译——真正的门槛只有三个：找不到 API 名、不知道 DevId 填几、分不清 PS 的引脚和 PL 的引脚。**

| 图 / 章节 | 回答的问题 | 类比 |
|---|---|---|
| 第一节 映射图 | **我会的东西在哪** | 换了个公司，同事换了名字 |
| 第三节 分层图 + 初始化四步 | SDK 怎么组织、一次初始化要写哪几步 | 办入职：填表 → 领工牌 → 上岗 |
| 第四节 四大功能图 | GPIO / PWM / 串口 / 协议**具体怎么写** | 四件常用工具的说明书 |
| 第五节 PL 调度图 | **怎么指挥 PL**（这是 PS 独有能力） | 三种喊话方式，两种现在能用 |
| 第六节 API 对照表 | 遇到不会的，**去哪查** | 中英对照词典 |
| 第七节 学习路线 | **按什么顺序练** | 五级台阶 |

---

## 三、图：驱动分层与初始化四步法

安路 SDK 的每个外设都长成同一个样子——**认准这个结构，19 个外设一套逻辑通用**。

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 414" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>安路 PS 驱动的四层结构与初始化四步法</title>
<desc>驱动分为 HAL 层、DEV 层、LL 层、HW 层四层向下依赖；应用侧初始化统一走查实例表、填配置结构体、调 Hal_Init、调业务 API 四步</desc>
<defs>
<marker id="m2" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>
<rect x="40" y="30" width="600" height="232" rx="12" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="60" y="52" font-size="13" font-weight="500" fill="#444441">驱动的四层（以 GPIO 为例，19 个外设结构完全相同）</text>
<rect x="60" y="62" width="560" height="42" rx="6" fill="#FFFFFF" stroke="#185FA5" stroke-width="0.5"/>
<text x="72" y="79" font-size="12" font-weight="500" fill="#0C447C">① HAL 层 · al_gpio_hal.h — 应用直接调用</text>
<text x="72" y="95" font-size="11" fill="#185FA5">AlGpio_Hal_Init / WritePin / ReadPinInput / DiscreteSet（= STM32 的 HAL）</text>
<rect x="60" y="110" width="560" height="42" rx="6" fill="#FFFFFF" stroke="#185FA5" stroke-width="0.5"/>
<text x="72" y="127" font-size="12" font-weight="500" fill="#0C447C">② DEV 层 + CFG 表 · al_gpio_dev.h + al_gpio_cfg.c — 实例台账</text>
<text x="72" y="143" font-size="11" fill="#185FA5">DevId → BaseAddress / IntrId / 时钟；AlGpio_HwConfig[] 数组就是"设备名 → 地址"的字典</text>
<rect x="60" y="158" width="560" height="42" rx="6" fill="#FFFFFF" stroke="#185FA5" stroke-width="0.5"/>
<text x="72" y="175" font-size="12" font-weight="500" fill="#0C447C">③ LL 层 · al_gpio_ll.h — 寄存器级 inline 函数（= STM32 的 LL）</text>
<text x="72" y="191" font-size="11" fill="#185FA5">AlGpio_ll_Write / SetDirection / EnableDebounce（参数是 BaseAddr，不经句柄）</text>
<rect x="60" y="206" width="560" height="42" rx="6" fill="#FFFFFF" stroke="#185FA5" stroke-width="0.5"/>
<text x="72" y="223" font-size="12" font-weight="500" fill="#0C447C">④ HW 层 · al_gpio_hw.h — 寄存器偏移与位域</text>
<text x="72" y="239" font-size="11" fill="#185FA5">基址 0xF8411000 ｜ 0x0 = DR（数据）· 0x4 = DDR（方向）· 0x8/0xC = 清除寄存器</text>
<rect x="40" y="278" width="600" height="94" rx="12" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="300" font-size="13" font-weight="500" fill="#0C447C">应用侧初始化：永远是这四步</text>
<rect x="60" y="310" width="131" height="48" rx="6" fill="#FFFFFF" stroke="#185FA5" stroke-width="0.5"/>
<text x="72" y="329" font-size="11" font-weight="500" fill="#0C447C">① 定 DevId</text>
<text x="72" y="346" font-size="11" fill="#185FA5">按 DeviceId 匹配</text>
<line x1="191" y1="334" x2="199" y2="334" stroke="#888780" stroke-width="1.5" marker-end="url(#m2)"/>
<rect x="199" y="310" width="131" height="48" rx="6" fill="#FFFFFF" stroke="#185FA5" stroke-width="0.5"/>
<text x="211" y="329" font-size="11" font-weight="500" fill="#0C447C">② 填结构体</text>
<text x="211" y="346" font-size="11" fill="#185FA5">BaudRate 等</text>
<line x1="330" y1="334" x2="338" y2="334" stroke="#888780" stroke-width="1.5" marker-end="url(#m2)"/>
<rect x="338" y="310" width="131" height="48" rx="6" fill="#FFFFFF" stroke="#185FA5" stroke-width="0.5"/>
<text x="350" y="329" font-size="11" font-weight="500" fill="#0C447C">③ 调 Hal_Init</text>
<text x="350" y="346" font-size="11" fill="#185FA5">拿回 Handle</text>
<line x1="469" y1="334" x2="477" y2="334" stroke="#888780" stroke-width="1.5" marker-end="url(#m2)"/>
<rect x="477" y="310" width="131" height="48" rx="6" fill="#FFFFFF" stroke="#185FA5" stroke-width="0.5"/>
<text x="489" y="329" font-size="11" font-weight="500" fill="#0C447C">④ 调业务 API</text>
<text x="489" y="346" font-size="11" fill="#185FA5">Send / Write</text>
<text x="40" y="394" font-size="11" fill="#5F5E5A">注：Hal_Init 的第一个参数是二级指针（AL_Xxx_HalStruct **Handle），与 STM32 传 &amp;hxxx 的写法一致。</text>
</svg>

**读图口诀**：上半部分是**代码仓库的目录结构**（① 是你调用的，④ 是你永远不用碰的）；下半部分是**每次初始化的固定四步**。记住一句话：**DevId 不是数组下标，而是 `cfg.c` 里 `DeviceId` 字段的值**——驱动靠**线性扫描比对该字段**来取配置（`al_uart_dev.c:56` 那个 `for` 循环）。填错不但会操作到别的外设，还可能命中"零填充空洞"而**静默失效**（详见 8.4）。

| 层 | 文件 | 你什么时候用它 | 对应 STM32 |
|---|---|---|---|
| HAL | `al_xxx_hal.h` | **99% 的时间** | `stm32fxxx_hal_xxx.h` |
| DEV/CFG | `al_xxx_dev.h` · `al_xxx_cfg.c` | 查 DevId、查基址、查中断号 | `xxx_MspInit()` + 引脚表 |
| LL | `al_xxx_ll.h` | HAL 没提供的能力（如 GPIO 设方向） | `stm32fxxx_ll_xxx.h` |
| HW | `al_xxx_hw.h` | 查寄存器偏移与位域 | 参考手册的寄存器表 |

> **为什么要分四层**：`cfg.c` 里的实例表是**板级信息的唯一落点**（基址、中断号、输入时钟）。HAL 之上的代码一行都不用知道"GPIO 在 0xF8411000"。换板子只需改 `cfg.c`。

---

## 四、图：四大基础功能的实现路径

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 300" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>四大基础功能在安路 PS 上的实现路径</title>
<desc>GPIO 控制、PWM 输出、串口交互、通信协议四类功能的基址、关键 API 与注意事项</desc>
<rect x="40" y="30" width="295" height="110" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="54" y="52" font-size="12" font-weight="500" fill="#0C447C">① GPIO 控制</text>
<text x="54" y="72" font-size="11" fill="#185FA5">基址 0xF8411000 · 4 bank × 32 pin</text>
<text x="54" y="90" font-size="11" fill="#185FA5">AlGpio_Hal_Init(DevId=0) 拿句柄</text>
<text x="54" y="108" font-size="11" fill="#185FA5">AlGpio_Hal_WritePin / ReadPinInput</text>
<text x="54" y="126" font-size="11" fill="#C83C3C">引脚号是全局 0–117（非 PA0 形式）</text>
<rect x="345" y="30" width="295" height="110" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="359" y="52" font-size="12" font-weight="500" fill="#085041">② PWM 输出（用 TC 定时器）</text>
<text x="359" y="72" font-size="11" fill="#0F6E56">TC0__TC0/1/2 @0xF840C000/4/8</text>
<text x="359" y="90" font-size="11" fill="#0F6E56">AlTc_Hal_Init(DevId=0..5)</text>
<text x="359" y="108" font-size="11" fill="#0F6E56">EnableMatchMode + SetMatchVal</text>
<text x="359" y="126" font-size="11" fill="#C83C3C">无独立 PWM 外设 ⇒ 靠 Match + Wave</text>
<rect x="40" y="150" width="295" height="110" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="54" y="172" font-size="12" font-weight="500" fill="#633806">③ 串口交互</text>
<text x="54" y="192" font-size="11" fill="#854F0B">UART0 0xF8400000 · UART1 0xF8401000</text>
<text x="54" y="210" font-size="11" fill="#854F0B">AlUart_Hal_Init(&amp;h, DevId, &amp;cfg, cb)</text>
<text x="54" y="228" font-size="11" fill="#854F0B">SendData / RecvData（阻塞）</text>
<text x="54" y="246" font-size="11" fill="#C83C3C">PS 侧只有 UART1 被使能（UART0 未使能）</text>
<rect x="345" y="150" width="295" height="110" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="359" y="172" font-size="12" font-weight="500" fill="#3C3489">④ 通信协议 I2C / SPI</text>
<text x="359" y="192" font-size="11" fill="#534AB7">I2C0 0xF8414000 · I2C1 0xF8415000</text>
<text x="359" y="210" font-size="11" fill="#534AB7">SPI0 0xF8404000 · SPI1 0xF8405000</text>
<text x="359" y="228" font-size="11" fill="#534AB7">AlIic_Hal_Master*DataBlock / Polling</text>
<text x="359" y="246" font-size="11" fill="#534AB7">AlSpi_Hal_TranferDataBlock / Polling</text>
</svg>

**读图口诀**：四块按"由简到难"排列（左右两列各成一组）。🔴 红色那几行是**你一定会踩的坑**，不是补充说明：

1. **GPIO 引脚号 = MIO 编号**——BANK0 = MIO0–31、BANK1 = MIO32–53。`MAX_PIN_NUMBER_IN_BANK_0/1/2/3 = 31/53/85/117` 里**只有前两段有物理落点**：BANK2/3（54–117）对应 EMIO，而 DR1 没有 EMIO。没有 `PA5` 这种写法。
2. **PWM 不是独立外设**——TC（Timer Counter）用"比较匹配 + 波形输出"两件事拼出 PWM，对应关系是 `EnableMatchMode` + `SetMatchVal` + `EnableWaveOutput` + `SetWaveformPolarity`。
3. **PS 侧只有 UART1 一路串口可用**——`UART0` 在本平台的实例表里**根本不存在**（`soc_plat.h:186` 的 `UART0PS_ENABLE` 是注释），`AL_UART_NUM_INSTANCE = 2` 只是个"数组长度常量"。而 UART1（`0xF8401000`）就是日志口，物理上接到板载 USB 转双串口桥 **U26（CH342K）**。**想让串口屏走 PS，只能与日志共口**；想独占一路，就得改 TD 的 PS 引脚配置（见 8.4 与 L2）。
4. **I2C / SPI 各有 2 个实例、都提供"块传输"与"轮询"两套**——先会用块传输，需要高吞吐再换 DMA 版。

---

## 五、图：对 PL 的三条调度通路

**这是 PS 相对于 STM32 唯一多出来的能力**——但三条通路里只有两条现在能用。

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 324" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>PS 调度 PL 的三条通路及其当前可用性</title>
<desc>前两条通路 TOP 寄存器与 pl_gpio 当前可用，第三条 AXI-GP0 尚未使能，需修改 PL 侧并重新综合</desc>
<rect x="40" y="30" width="600" height="78" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="52" font-size="12" font-weight="500" fill="#0C447C">① TOP 寄存器 —— 今天就可用（复位 / 时钟）</text>
<text x="60" y="72" font-size="11" fill="#185FA5">AlTop_P2F_RstAssert(Index) / AlTop_P2F_RstRelease(Index) → 0xF8806330 bit[7:4]</text>
<text x="60" y="90" font-size="11" fill="#185FA5">能力：强制 PL 复位或释放。只能整片开关，不能调参数（也可以用 UI_Out32 直写）</text>
<rect x="40" y="118" width="600" height="78" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="140" font-size="12" font-weight="500" fill="#0C447C">② pl_gpio —— 今天就可用（少量开关量）</text>
<text x="60" y="160" font-size="11" fill="#185FA5">经 Design.xml 的 adHocConnections 连到 PL 侧的双向 GPIO</text>
<text x="60" y="178" font-size="11" fill="#185FA5">能力：传几个 bit 的使能 / 模式选择；不适合传数据</text>
<rect x="40" y="206" width="600" height="78" rx="8" fill="#FFFFFF" stroke="#C83C3C" stroke-width="0.5"/>
<text x="60" y="228" font-size="12" font-weight="500" fill="#C83C3C">③ AXI-GP0 —— 尚未使能（真正的读写通路）</text>
<text x="60" y="248" font-size="11" fill="#C83C3C">当前 Master_AXI_GP0 = 0 ⇒ PS 没有任何 AXI 主通道，读不到 PL 内部寄存器</text>
<text x="60" y="266" font-size="11" fill="#C83C3C">开启后：PS 读写 PL 寄存器（阈值下发、状态回读）；前置 = 改 PL 侧并重综合</text>
<text x="40" y="304" font-size="11" fill="#5F5E5A">注：三条通路的使能状态出自基线平台 Design.xml；改造路线见《总控架构.md》第六节。</text>
</svg>

**读图口诀**：从上往下是**能力由弱到强**。🔵 前两条今天就能用，但只能做"开关"级别的事；🔴 第三条才是"发参数、读状态"，可它还没开——**这也是为什么现阶段 PS 能写的东西，主要是 PS 自己的外设**。

**所以教程的重点排序应该反过来看**：先把 PS 自己的 GPIO / 串口 / 定时器练熟（这些**不需要动 PL**，改完就能下板验证），最后再碰 PL 调度。

---

## 六、API 对照速查表（STM32 ↔ 安路 PS）

> 这张表是本教程的使用频率最高的一节。查不到的东西，一律去 `soc_base/dr1m90_fpsoc_cpu0/driver/ps_driver/<外设>/inc/al_<外设>_hal.h` 里找。

### 6.1 通用机制

| 功能 | STM32 | 安路 PS |
|---|---|---|
| 寄存器直写 | `*(volatile uint32_t *)addr` | `UI_In32(addr)` / `UI_Out32(addr, v)` |
| 延时（ms） | `HAL_Delay(100)` | `AlSys_MDelay(100)` |
| 延时（µs） | `HAL_Delay` 无 µs 版 | `AlSys_UDelay(us)` |
| 取时间戳 | `HAL_GetTick()` | `AlSys_GetTimerTickCount()` |
| 取时钟频率 | `HAL_RCC_GetHCLKFreq()` | `AlSys_GetTimerFreq()` |
| 开中断 | `HAL_NVIC_SetPriority` + `EnableIRQ` | `AlIntr_RegHandler(IntrId, &Attr, Handler, Ref)` + `AlIntr_SetInterrupt(IntrId, 1)` |
| 关中断 | `__disable_irq()` | `AlIntr_SaveLocalInterruptMask()`（返回旧掩码，可恢复） |
| 恢复中断 | `__enable_irq()` | `AlIntr_RestoreLocalInterruptMask(Mask)` |
| 清所有挂起 | `HAL_NVIC_ClearPendingIRQ` | `AlIntr_ClearAllPending()` |
| 打印 | printf 需手动重定向到 UART | **内建可用**（`LOG_DEV = AL_LOG_UART1`，输出到 `0xF8401000` @115200） |
| 数据类型 | `uint32_t` / `uint8_t` | `AL_U32` / `AL_U8`（也可直接用 `uint32_t`） |
| 错误返回值 | `HAL_StatusTypeDef` | `AL_S32`，0 = 成功（`AL_OK`） |

### 6.2 GPIO

| 功能 | STM32 | 安路 PS |
|---|---|---|
| 初始化 | `HAL_GPIO_Init(GPIOA, &cfg)` | `AlGpio_Hal_Init(&h, DevId, CallBack)` |
| 设方向 | 含在 `Init` 的 `Mode` 字段 | `AlGpio_ll_SetDirection(BaseAddr, Mask)`（HAL 层无此函数，走 LL） |
| 写单个引脚 | `HAL_GPIO_WritePin(port, pin, val)` | `AlGpio_Hal_WritePin(h, Pin, Data)` |
| 读单个引脚 | `HAL_GPIO_ReadPin(port, pin)` | `AlGpio_Hal_ReadPinInput(h, Pin)` |
| 读回输出值 | `port->ODR` | `AlGpio_Hal_ReadPinOutput(h, Pin)` |
| 整组写 | `port->ODR = v` | `AlGpio_Hal_WriteBank(h, Bank, Data)` |
| 置位（不改其他位） | `HAL_GPIO_WritePin(...SET)` | `AlGpio_Hal_DiscreteSet(h, Bank, Mask)` |
| 清零 | `HAL_GPIO_WritePin(...RESET)` | `AlGpio_Hal_DiscreteClear(h, Bank, Mask)` |
| 中断配置 | `HAL_GPIO_EXTI_...` | `AlGpio_Hal_IntrPinCfg(h, Pin, IntrType, &Attr)` |
| 消抖 | 软件实现 | `AlGpio_ll_EnableDebounce(BaseAddr, Mask)`（**硬件消抖**，白送的） |
| Bank 枚举 | `GPIOA`/`GPIOB`/… | `AL_GPIO_BANK0` … `AL_GPIO_BANK3` |
| 电平枚举 | `GPIO_PIN_SET` / `RESET` | `AL_GPIO_ENABLE` (1) / `AL_GPIO_DISABLE` (0) |
| 引脚复用（pinmux） | CubeMX 里的引脚配置页 | 无 HAL 封装：`UI_Out32(0xF8803000 + 4×n, 4)`；**FUNCSEL = 4 才是 GPIO**，默认由 FSBL 的 `psio_data_0` 表写入。本板只有 **MIO0/7/8/9/46/47/50/51** 是 GPIO（全表见 8.3） |

### 6.3 UART

| 功能 | STM32 | 安路 PS |
|---|---|---|
| 初始化 | `HAL_UART_Init(&huart)` | `AlUart_Hal_Init(&h, DevId, &InitConfig, Callback)` |
| 配置字段 | `BaudRate`/`WordLength`/… | 同名：`BaudRate` · `WordLength` · `StopBits` · `Parity` · `HwFlowCtl` · `CharTimeoutEnable` |
| 阻塞发送 | `HAL_UART_Transmit(..., timeout)` | `AlUart_Hal_SendDataBlock(h, Data, Size, Timeout)` |
| 阻塞接收 | `HAL_UART_Receive(..., timeout)` | `AlUart_Hal_RecvDataBlock(h, Data, RequestSize, &RecvSize, Timeout)` |
| 轮询发送 | 无直接对应 | `AlUart_Hal_SendDataPolling(h, Data, Size)` |
| 轮询接收 | 无直接对应 | `AlUart_Hal_RecvDataPolling(h, Data, Size)` |
| 非阻塞 | `HAL_UART_Transmit_IT` | `AlUart_Hal_SendDataPollingNonBlock(h, Data, ReqSize, &Actual, Timeout)` |
| DMA 发送 | `HAL_UART_Transmit_DMA` | `AlUart_Hal_SendDataDmaBlock(h, Data, Size, Timeout)` |
| DMA 接收 | `HAL_UART_Receive_DMA` | `AlUart_Hal_RecvDataDmaBlock(h, Data, Size, Timeout)` |
| 中断回调 | `HAL_UART_RxCpltCallback` | `AlUart_Dev_RegisterEventCallBack(h, Callback, Ref)` |
| 空闲查询 | `__HAL_UART_GET_FLAG` | `AlUart_Hal_IsRxBusy(h)` / `IsTxBusy(h)` |
| 参数修改 | `HAL_UART_Init` 重初始化 | `AlUart_Hal_IoCtl(h, Cmd, &Param)` |

### 6.4 定时器 / PWM（TC）

| 功能 | STM32 | 安路 PS |
|---|---|---|
| 初始化 | `HAL_TIM_Base_Init` | `AlTc_Hal_Init(&h, DevId, &InitConfig, Callback)` |
| 配置字段 | `Prescaler` / `Period` | `CountDec`（计数方向）· `ClkSrc` · `EnablePrescale` · `PrescaleVal`（**最大 0xF**） |
| 启动计数 | `HAL_TIM_Base_Start` | `AlTc_Hal_EnableCounter(h, 1)` |
| PWM 输出 | `HAL_TIM_PWM_Start` + `__HAL_TIM_SET_COMPARE` | `AlTc_Hal_EnableMatchMode(h, 1)` + `AlTc_Hal_SetMatchVal(h, MatchNum, Value)` + `AlTc_Hal_EnableWaveOutput(h, 1)` |
| PWM 极性 | `HAL_TIM_PWM_ConfigChannel` 的 `Polarity` | `AlTc_Hal_SetWaveformPolarity(h, ClkEdge)` |
| 读计数 | `__HAL_TIM_GET_COUNTER` | `AlTc_Hal_GetCounterVal(h)` |
| 更新中断 | `HAL_TIM_PeriodElapsedCallback` | `AlTc_Hal_EnableIntr(h, IntrType, 1)` + `AlTc_Dev_RegisterEventCallBack` |
| 定时模式 | `HAL_TIM_Base_Start_IT` | `AlTc_Hal_EnableIntervalMode` / `EnableOverflowMode` + `SetIntervalMaxVal` |
| 计数器位宽 | 16/32 位看型号 | **16 位**（`AL_U16`） |
| 通道数 | 每 TIM 4 通道 | 每 TC 3 个 Match（`Match1/2/3`） |

### 6.5 通信协议与 DMA

| 功能 | STM32 | 安路 PS |
|---|---|---|
| I2C 主机发送 | `HAL_I2C_Master_Transmit` | `AlIic_Hal_MasterSendDataPolling`（轮询）/ `MasterSendDataBlock`（带超时） |
| I2C 主机接收 | `HAL_I2C_Master_Receive` | `AlIic_Hal_MasterRecvDataPolling` / `MasterRecvDataBlock` |
| I2C DMA | `HAL_I2C_Master_Transmit_DMA` | `AlIic_Hal_MasterDmaSendDataBlock` |
| I2C 从机 | `HAL_I2C_Slave_Transmit` | `AlIic_Hal_SlaveSendDataBlock` / `SlaveRecvDataBlock` |
| SPI 收發 | `HAL_SPI_TransmitReceive` | `AlSpi_Hal_TranferDataBlock` / `TranferDataPolling` |
| SPI 只发 / 只收 | `HAL_SPI_Transmit` / `Receive` | `AlSpi_Hal_SendDataBlock` / `RecvDataBlock` |
| SPI DMA | `HAL_SPI_TransmitReceive_DMA` | `AlSpi_Hal_DmaStartBlockTranfer` / `DmaStartBlockSend` / `DmaStartBlockReceive` |
| 内存搬运 | `HAL_DMA_Start` + 手动 | **`AlDma_Hal_MemCpy(Dst, Src, Len)` 一行搞定** |
| 外设↔内存（单次） | `HAL_DMA_Start` | `AlDma_Hal_PeriCpySingleBlock(h, MemAddr, Len, PerId)` |
| 外设↔内存（循环） | `HAL_DMA_Start_IT` 循环模式 | `AlDma_Hal_PeriCpyCycleBlock(h, MemAddr, Len, PerId)`（**循环模式现成**） |
| 停止 | `HAL_DMA_Abort` | `AlDma_Hal_StopCpy(h)` |

---

## 七、教程规划：五级台阶

**编排原则**：每一级都必须能**单独下板验证**，且不依赖 PL 侧改动。做到"一级一闭环"——上一级的验收判据成为下一级的起点。

### 阶段总览

| 阶段 | 主题 | 产出 | 依赖 |
|---|---|---|---|
| **L1** | 认清家底（只读） | 一张自填的"外设台账" | 无 |
| **L2** | 串口闭环 | 串口助手收到自己发的字符串 | L1 |
| **L3** | GPIO 输入输出 | 按键改变输出状态 | L2 |
| **L4** | 定时器与 PWM | 逻辑分析仪看到可调占空比方波 | L2 |
| **L5** | 通信协议与 DMA | 读到 I2C 传感器数据 / SPI 回环 | L2 L3 |

### L1 · 认清家底（不改一行代码）

| 项目 | 内容 |
|---|---|
| 目标 | 建立"外设 → 地址 / 中断号 / DevId"的索引能力 |
| 读什么 | `al_hwcfg.h`（全部基址）· `al_chip.h`（全部中断号）· `ps_driver/*/src/al_*_cfg.c`（实例表序）· `fdma_en/main.c`（现有用法） |
| 练习 | 手抄一张表：UART1 / GPIO / TC0__TC0 / I2C0 / SPI0 各自的**基址、中断号、DevId、以及"该实例到底存不存在"** |
| 验收判据 | 任给一个需求（如"用 I2C1 读传感器"），能在 1 分钟内说出它的基址、中断号、DevId |
| 常见坑 | 把 DevId 当成"引脚号"；把 `AL_UART_NUM_INSTANCE = 2` 当成"有两个可用 UART"（**宏是数组长度，`#ifdef` 才决定实际条目**） |

### L2 · 串口闭环（最小可观测系统）

| 项目 | 内容 |
|---|---|
| 为什么排第一 | **没有日志，后面全是盲调**。串口是唯一的输出通道 |
| 目标 | 用 `AlUart_Hal_Init` 初始化 **UART1（DevId = 1）**——这是 PS 侧唯一存在的串口；发一行字符串，并轮询收字符回显 |
| 关键 API | `AlUart_Hal_Init` → `AlUart_Hal_SendDataBlock` → 循环 `AlUart_Hal_RecvDataPolling` |
| 练习 | ① 发 `"hello\r\n"`；② 收到 `'a'` 回一个自增值；③ 把收发封装成 `my_uart_init()` / `my_uart_puts()` 两个函数放独立文件 |
| 验收判据 | 串口助手（115200, 8N1）能看到输出；发字符能收到回应 |
| 常见坑 | ① 按老习惯去初始化 **UART0**——它在本平台**没有实例**，`AlUart_Hal_Init(&h, 0, ...)` 会**静默命中一个全零配置**（基址 0，详见 8.4）；② 忘记波特率要两边一致；③ 以为"Type-C 口"和"UART1"是两个口——**它们就是同一个口**：板上 U26 = CH342K，通道 0 接 PS 的 MIO48/49，通道 1 才接 PL 的 J16/K16 |

> **L2 的隐藏收获**：你会第一次体会到"**在 `fdma_en/` 下新建 `.c`/`.h` 文件不需要改 Makefile**"——因为 Makefile 用 `find "./" -type d` 递归扫描目录，任何子目录里的 `.c` 都会被自动加入编译。这意味着你可以按功能建 `my_drv/` 子目录组织代码。

### L3 · GPIO 输入输出

| 项目 | 内容 |
|---|---|
| 目标 | 读一个输入（按键 / 跳线），驱动一个输出（PL 排针上的 LED 或示波器可测的脚） |
| 关键点 | ⚠️ **先搞清楚"PS 的 GPIO"和"PL 的 IO"是两套东西**：`0xF8411000` 的 GPIO 控制器管的是 **PS 域引脚（MIO）**，不是 FPGA 的引脚 |
| 关键 API | `AlGpio_Hal_Init(&h, 0, CallBack)` → `AlGpio_ll_SetDirection(...)` → `AlGpio_Hal_WritePin` / `ReadPinInput` |
| 练习 | ① 把一个引脚设成输出，1 Hz 翻转（用 `AlSys_MDelay(500)`）；② 把一个引脚设成输入，读回值随电平变化；③ 启用硬件消抖 `AlGpio_ll_EnableDebounce` 做按键 |
| 验收判据 | 输出波形在示波器上可见；按键按下时读值稳定翻转（无抖动毛刺） |
| 现成可用引脚 | **MIO50 = 按键 KEY3**（输入）· **MIO51 = LED5**（输出，经 MOS 管驱动）。这两个是板上仅有的"复用已经是 GPIO、且物理上就是给人用的"引脚——**L3 直接拿它们做实验：不改编译配置、不动 TD、不飞线。** |
| 常见坑 | ① 想控制 FPGA 引脚却去操作 PS GPIO（**必须走 PL 逻辑或 `pl_gpio`**）；② 引脚号写成 `PA5` 风格（**这里只有 0–53 的 MIO 编号**，54 以上是 DR1 没有的 EMIO）；③ 忘记设方向，默认可能不是想要的；④ 挑了一个 **FUNCSEL ≠ 4** 的 MIO，配置全对但毫无反应——本板只有 8 个 MIO 是 GPIO（全表见 8.3） |

#### 先分清：你要控制的是谁的引脚

⚠️ 这一步做错，后面全白费。**PS 的 GPIO 与 PL 的 IO 是两套完全独立的硬件。**

| 你要控制谁 | 谁在控制 | 要写 Verilog | 要动 TD | PS 怎么访问 |
|---|---|---|---|---|
| **PS 的 MIO 引脚** | PS 内 GPIO 控制器 `0xF8411000` | 不用 | **不用**（复用已是 GPIO 时） | `AlGpio_Hal_WritePin()` 直接写 |
| **PL 的 `pl_gpio` 专用脚** | PL 引脚，但由 PS 的 TOP 寄存器直驱（`Design.xml` adHoc 直连） | 不用 | 已配好，不用改 | 写 TOP 寄存器 |
| **PL 的任意 FPGA IO** | PL 逻辑 | **必须** | **必须**（综合 + `.adc` 引脚约束） | 只能经 PL 中转 |

> **结论**：用 PS 的 MIO，**完全不需要 PL 做中介，也不需要为这个 GPIO 写任何 TD 内容**——只要它的复用功能已经是 GPIO。

#### 唯一的"配置"是引脚复用（pinmux）

每个 PS MIO 引脚有一个复用寄存器：**`0xF8803000 + 4×n`**（n = 引脚号），低 4 位是 FUNCSEL。

| 事实 | 值 / 出处 |
|---|---|
| FUNCSEL = **4** | 该引脚为 **GPIO** |
| 默认配置（实测） | 整张表已解出：**FUNCSEL = 4（GPIO）的只有 8 个引脚 —— MIO0 / 7 / 8 / 9 / 46 / 47 / 50 / 51**；其余全被 QSPI、SD1、ETH0、USB0、SD0、UART1、MDIO 占满（全表见 8.3） |
| 谁写这些寄存器 | FSBL 上电时执行 `psio_data_0` 表；该表由 hpfTool 从 **TD 的 PS 引脚配置**导出 |

所以判断只有两种：

| 情况 | 做法 |
|---|---|
| 该引脚 FUNCSEL **已经是 4** | **零配置**，直接写 C 代码 |
| 该引脚**已被别的功能占用** | ① 回 **TD 的 PS 引脚配置**里改 → 重导 HPF → 重新生成 `psio_data_0` → 重编 FSBL（**要动 TD**）；② 运行时 `UI_Out32(0xF8803000 + 4*n, 4)` 自行改写（**不动 TD**，但必须先确认该引脚的原功能确实不再使用，否则会弄断 QSPI / UART 等） |

> ⚠️ **一个容易误判的点**：`soc_plat.h` 里 **`GPIOPL_ENABLE` 虽已定义，但 `Design.xml` 里没有任何 GPIO IP** ⇒ **不存在"PS 通过 AXI 控制 PL 通用 GPIO"的现成通路**。别看到这个宏就以为可用；想控 FPGA 引脚，现阶段只有"PL 自己写 Verilog"和"走 `pl_gpio` 那几根专用直连脚"两条实路。
> ✅ **已核实（2026-10-11，底板原理图 + FSBL `psio_data_0` 双证）**：DR1M90GEG400 的 PS 侧 **MIO0–MIO53 共 54 个，全部经 B2B 连接器引到底板**（核心板 B2B 表逐条列出）。但其中**只有 8 个的复用是 GPIO**，而这 8 个在板上又大多已被别的电路占用：
>
> - **MIO50 = 按键 KEY3**（VCC_1V8 上拉 + 100R + 100nF 去抖）→ **现成的输入**
> - **MIO51 = LED5**（经 MOS 管 Q5 驱动）→ **现成的输出**
> - MIO46 = USB PHY 复位 · MIO47 = TF 卡插入检测 · MIO7/MIO8 并接在同一根网线上（带上拉与红色 LED D2）· MIO0/MIO9 底板上未接外设（空脚）
>
> ⇒ **L3 的最佳实验对象就是"读 MIO50 按键 → 写 MIO51 LED"**；想扩展成任意数量的 IO，请往 PL 侧去，别在 MIO 上打转。全表见 8.3。

### L4 · 定时器与 PWM

| 项目 | 内容 |
|---|---|
| 目标 | 用 TC 产生**周期固定、占空比可调**的方波 |
| 前置条件 | 🔴 **TC 当前一个实例都没有**：`soc_plat.h:184-185` 的 `TC0PS_ENABLE` / `TC1PS_ENABLE` **都是注释** ⇒ `AlTc_HwConfig[6]` 六个槽全部被零填充，`AlTc_Dev_LookupConfig()` 返回的是**零配置而不是 NULL**，而 `AlTc_Hal_Init` 只判 `if (HwConfig != AL_NULL)` ⇒ 照样放行 ⇒ `BaseAddr = 0`，**不报错、静默失效**。**必须先放开这两个宏并重编 `soc_base`**——这一步改到的是 `PS与PL的联通` 目录之外的文件，**需单独授权** |
| 关键认知 | 安路 PS **没有独立的 PWM 外设**，PWM = TC 的"比较匹配（Match）+ 波形输出（Wave）"两件事组合。与 STM32 的 TIM 通道思路相同，但 API 拆成了四个函数 |
| 关键 API | `AlTc_Hal_Init` → `SetWaveformPolarity` → `EnableMatchMode(1)` → `SetMatchVal(Match1, v)` → `EnableWaveOutput(1)` → `EnableCounter(1)` |
| 练习 | ① 先出固定 50% 占空比；② 在主循环里改 `SetMatchVal` 做呼吸灯；③ 用 `EnableIntr` + 回调做一个 1 ms 软定时器，替代 `AlSys_MDelay` 轮询 |
| 验收判据 | 逻辑分析仪/示波器看到方波；占空比随 `SetMatchVal` 线性变化；中断回调计数与墙钟一致（1 s ±1%） |
| 常见坑 | ① 忘记 `EnableCounter`（配置全对但没输出）；② `PrescaleVal` 最大只有 `0xF`（16 分频上限，再慢要靠 `SetIntervalMaxVal`）；③ 计数是 **16 位**，别期望 32 位长周期 |

### L5 · 通信协议与 DMA

| 项目 | 内容 |
|---|---|
| 目标 | 用 I2C 读一个真实传感器；用 SPI 做回环；把一次大块搬运交给 DMA |
| 关键 API | `AlIic_Hal_MasterRecvDataBlock` · `AlSpi_Hal_TranferDataBlock` · `AlDma_Hal_MemCpy` |
| 练习 | ① I2C 读设备 ID 寄存器并打印；② SPI 自发自收比对；③ 用 `AlDma_Hal_MemCpy` 搬 1 KB 并校验 |
| 验收判据 | I2C 读回的 ID 与规格书一致；SPI 回环数据一致；DMA 搬运结果与逐字节拷贝一致 |
| 常见坑 | ① I2C 从机地址是 **7 位**（函数参数是 `AL_U16`，注意左移与否）；② 上拉电阻未接（I2C 必须外部上拉）；③ DMA 搬运的源/目标地址若在 DDR，需考虑**缓存一致性**（DDR 全段映射为 `NORM_CACHE`） |

### 进阶 · 对 PL 的调度

| 项目 | 内容 |
|---|---|
| 前置 | 至少完成 L2（有串口才看得到结果） |
| 目标 | 用 HAL 替代 `main.c` 里的裸地址魔数，并让 PS 能"干净地"重启 PL |
| 关键 API | `AlTop_P2F_RstAssert(Index)` / `AlTop_P2F_RstRelease(Index)`（对比现有 `Fclk_Init()` 的 `UI_Out32(0xF8806330, ...)` 手工写法） |
| 练习 | 把 `Fclk_Init()` 改写成 HAL 版，功能对比一致；再读 `0xF8806330` 打印 `p2f_rst_n[3:0]` 验证 |
| 验收判据 | HDMI 正常出图，且串口打印 `p2f_rst_n[3:0] = F` |
| 再往上 | 阈值下发 / 状态回读（**当前无通路**），需要先改造 PL 侧开 AXI-GP0——见《总控架构.md》第六节 |

---

## 八、参数一览与工程骨架

### 8.1 外设基址（出自 `chip/dr1x90/common/inc/al_hwcfg.h`）

| 外设 | 实例数 | 基址 | 备注 |
|---|---|---|---|
| UART | 2（宏）／**1（实际）** | UART0 `0xF8400000` · UART1 `0xF8401000` | ⚠️ `UART0PS_ENABLE` 是注释 ⇒ **UART0 没有实例**；UART1 = 日志口 = 板上 **U26（CH342K）通道 0**，通道 1 接 PL 的 J16/K16 |
| GPIO | 1（4 bank） | `0xF8411000` | 中断号 `GPIO0_IRQn = 84` |
| I2C | 2 | I2C0 `0xF8414000` · I2C1 `0xF8415000` | I2C 时钟 100 MHz |
| SPI | 2 | SPI0 `0xF8404000` · SPI1 `0xF8405000` | FIFO 深度 32 |
| TC | 6 | TC0: `0xF840C000` / `+0x4` / `+0x8` · TC1: `0xF840D000` / `+0x4` / `+0x8` | TC0__TC0/1/2、TC1__TC0/1/2 |
| WDT | 2 | WDT0 `0xF8410000` · WDT1 `0xF8410200` | 中断 `SOC_WDT0_IRQn = 58` |
| DMA | 1（8 通道） | S `0xF8418000` · NS `0xF8419000` | 通道数 8 |
| DMACAHB | 1（8 通道） | `0xF804D000` | 中断 `SOC_DMACAHB_IRQn = 78` |
| ADC | 1 | `0xF840B000` | 中断 `SOC_ADC_IRQn = 56` |
| QSPI | 1 | `0xF804E000` | 中断 `SOC_QSPI_IRQn = 80` |
| CAN | 2 | CAN0 `0xF8408000` · CAN1 `0xF8409000` | |
| MMC | 2 | MMC0 `0xF8049000` · MMC1 `0xF804A000` | |
| USB | 2 | USB0 `0xF8180000` · USB1 `0xF81C0000` | |
| GBE | 2 | GBE0 `0xF8100000` · GBE1 `0xF8110000` | |
| IPC | 1 | `0xF841F000` | 核间通信（本平台单核，用不到） |
| TOP | — | NS `0xF8800000` · CRP `0xF8801000` · PIN `0xF8803000` · SYSCNT_S `0xF8804000` · S `0xF8806000` | PL 复位在 `0xF8806330` |

### 8.2 TC 中断号（出自 `al_chip.h`）

| 实例 | 中断号 | 实例 | 中断号 |
|---|---|---|---|
| `SOC_TC0_TC0_IRQn` | 61 | `SOC_TC1_TC0_IRQn` | 64 |
| `SOC_TC0_TC1_IRQn` | 62 | `SOC_TC1_TC1_IRQn` | 65 |
| `SOC_TC0_TC2_IRQn` | 63 | `SOC_TC1_TC2_IRQn` | 66 |

### 8.3 GPIO Bank、引脚号与 MIO 占用（双证：`al_gpio_hw.h` + 底板原理图）

| Bank 枚举 | 引脚号范围 | 该 Bank 最大引脚号常量 |
|---|---|---|
| `AL_GPIO_BANK0` | 0 – 31 | `MAX_PIN_NUMBER_IN_BANK_0 = 31` |
| `AL_GPIO_BANK1` | 32 – 53 | `MAX_PIN_NUMBER_IN_BANK_1 = 53` |
| `AL_GPIO_BANK2` | 54 – 85 | `MAX_PIN_NUMBER_IN_BANK_2 = 85` |
| `AL_GPIO_BANK3` | 86 – 117 | `MAX_PIN_NUMBER_IN_BANK_3 = 117` |

> **引脚号 = MIO 编号**：BANK0 = MIO0–31、BANK1 = MIO32–53，两段加起来恰好是 MIO0–53 这 54 个。**BANK2/3（54–117）对应 EMIO，而 DR1 没有 EMIO**（`Design.xml` 里也没有任何 GPIO IP）⇒ **传 ≥54 的引脚号没有物理落点**。

**MIO 占用全表**（左半列出自 `soc_plat.c` 的 `psio_data_0` 出厂复用；右半列由底板原理图逐页核实）

| MIO | FUNCSEL | 复用功能 | 底板上实际接到 | 能当自由 GPIO 吗 |
|---|---|---|---|---|
| 0 | 4 | **GPIO** | 底板上未接外设 | ⚠️ 空脚，要飞线才用得上 |
| 1–6 | 0 | Quad_SPI_Flash | QSPI Flash（U4）；其中 MIO2–MIO5 另接启动拨码 SW1 | ❌ |
| 7 · 8 | 4 | **GPIO** | MIO7/MIO8 并接在同一根网线上，带上拉 + 红色 LED（D2） | ⚠️ 已被 LED 占用 |
| 9 | 4 | **GPIO**（原 SD1_cd） | 底板上未接外设 | ⚠️ 空脚，要飞线才用得上 |
| 10–15 | 0xA | SD1 | eMMC（U11） | ❌ |
| 16–27 | 0xE | ETH0（RGMII） | PS 侧以太网 PHY | ❌ |
| 28–39 | 0xF | USB0（ULPI） | USB2.0 PHY | ❌ |
| 40–45 | 0xA | SD0 | TF 卡座 | ❌ |
| 46 | 4 | **GPIO** | `MIO46_OTG_RESETN` = USB PHY 复位 | ⚠️ 被 USB 复位占用 |
| 47 | 4 | **GPIO**（原 SD0_cd） | `MIO47_SD0_DETECT` = TF 卡插入检测 | ⚠️ 被卡检测占用 |
| 48–49 | 3 | UART1 | U26（CH342K）通道 0 = **日志口** | ❌ |
| 50 | 4 | **GPIO** | **按键 KEY3**（VCC_1V8 上拉 + 100R + 100nF 去抖） | ✅ **现成输入** |
| 51 | 4 | **GPIO** | **LED5**（经 MOS 管 Q5 驱动） | ✅ **现成输出** |
| 52–53 | 0xE | MDIO0 | PS 侧以太网 MDC/MDIO | ❌ |

> **一句话结论**：PS 侧 **54 个 MIO 里只有 8 个的复用是 GPIO**，而这 8 个里真正"空着等你用"的只有 **MIO50（按键）与 MIO51（LED）**。**在 PS 侧扩展 GPIO 几乎一定会撞上引脚复用这一关**；需要不受限的 IO，就下到 PL 侧。

### 8.4 实例编号（DevId）怎么定

**先纠正一个危险的直觉**：`DevId` **不是数组下标**，也不必是连续序号。驱动的实现是**线性扫描 + 字段比对**（以 `al_uart_dev.c:51` 为例）：

```c
AL_UART_HwConfigStruct *AlUart_Dev_LookupConfig(AL_U32 DevId)
{
    for (Index = 0; Index < AL_UART_NUM_INSTANCE; Index++) {
        if (AlUart_HwConfig[Index].DeviceId == DevId) {   /* ← 比的是字段，不是下标 */
            ConfigPtr = &AlUart_HwConfig[Index];
            break;
        }
    }
    return ConfigPtr;
}
```

所以**唯一权威**是 `cfg.c` 里每个条目的 `.DeviceId` / `.DevId` 字段值。⚠️ 注意字段名各家不统一：**TC 用 `.DevId`，UART/GPIO/DMA 用 `.DeviceId`**。

**⚠️ 零填充陷阱（必读）**：`_NUM_INSTANCE` 是**固定长度的宏常量**，而条目由 `#ifdef` 决定。**没写初始化器的槽会被零填充，其 `DeviceId` 恰好是 0** ⇒ 用一个不存在的 DevId 去查，**不会返回 NULL，而是返回一个"全零配置"**（`BaseAddress = 0`）。驱动只判 `if (HwConfig != AL_NULL)` 就放行，于是**所有寄存器访问都落到地址 0**——不报错、静默失效。

| 外设 | `_NUM_INSTANCE` | 实际有效条目 | 可用的 DevId | 依据 |
|---|---|---|---|---|
| GPIO | 1 | 1 | **0**（`0xF8411000`） | `al_gpio_cfg.c`：`.DeviceId = 0` |
| UART | 2 | **1** | **只有 1**（`0xF8401000`） | `UART0PS_ENABLE` 是注释 ⇒ 另一槽零填充 |
| I2C | 2 | 见 `al_iic_cfg.c` | 待核 | 未逐行核 |
| SPI | 2 | 见 `al_spi_cfg.c` | 待核 | 未逐行核 |
| TC | 6 | **0** | **无可用**（`DevId 0–5` 全部命中零配置） | `TC0PS_ENABLE`/`TC1PS_ENABLE` 均为注释 |
| DMA | 1 | 1 | **0** | `al_dma_cfg.c`：`.DeviceId = 0`，8 通道在通道配置结构体里区分 |

> ⚠️ **两条已定案的坑**：
> ① **UART 传 `0` 是错的**——`UART0PS_ENABLE` 被注释后，数组只剩一个初始化器写 `.DeviceId = 1`，**另一个槽零填充成 `DeviceId = 0`**；传 0 命中的正是那个空槽。**正确值是 `1`**（TC 的 DevId 顺序也已核实：`0/1/2` = TC0__TC0/1/2，`3/4/5` = TC1__TC0/1/2）。
> ② **TC 目前完全不可用**——两个使能宏都是注释，6 个槽全是零填充，`AlTc_Dev_LookupConfig()` 返回零配置而非 NULL。**写 PWM 之前必须先放开 `soc_plat.h` 的 `TC0PS_ENABLE` 并重编 `soc_base`**（改到的是本目录之外的文件，需单独授权）。

### 8.5 工程骨架（在 `fdma_en/` 里怎么组织代码）

```
fdma_en/
├── Makefile              # 不用改（见下）
├── main.c                # 主流程：初始化 → 主循环
├── ui_io.h / ui_type.h   # 现成的寄存器读写与类型定义
├── lds/                  # 5 个链接脚本（ddr/ocm × aarch32/aarch64 + xip）
└── my_drv/               # ★ 新建：自己的驱动，任意子目录都会自动编译
    ├── my_uart.c / .h
    ├── my_gpio.c / .h
    └── my_tc.c   / .h
```

**为什么不用改 Makefile**——`fdma_en/Makefile` 里这两行：

```make
APP_SRC_DIR += $(abspath $(sort $(dir $(foreach dir, $(shell find "./" -type d), $(wildcard $(dir)/*.c $(dir)/*.cpp)))))
APP_INC_DIR += $(abspath $(sort $(dir $(foreach dir, $(shell find "./" -type d), $(wildcard $(dir)/*.h $(dir)/*.hpp)))))
```

它用 `find "./" -type d` **递归扫描当前目录下所有子目录**，把 `.c` / `.h` 全收进来。所以：**在 `fdma_en/` 下建任意深度的子目录、放任意 `.c`/`.h`，都会被自动编译**（`APP_SRC_DIR` 进源文件列表，`APP_INC_DIR` 进头文件搜索路径）。

**代价（必须知道）**：这是"全收"策略——**临时备份文件、测试代码、被排除的文件都会被一起编译**。所以别把 `xxx_bak.c`、`old/`、`test_废弃.c` 留在目录里，否则会编译报错或链接冲突。

### 8.6 需要包含的头文件

| 你要用的功能 | `#include` |
|---|---|
| 寄存器直写、打印 | `"ui_io.h"` `"ui_type.h"` `"al_core.h"` |
| 延时 / 时间 | `"al_systimer.h"` |
| GPIO | `"al_gpio_hal.h"` |
| 串口 | `"al_uart_hal.h"` |
| 定时器 / PWM | `"al_tc_hal.h"` |
| I2C | `"al_iic_hal.h"` |
| SPI | `"al_spi_hal.h"` |
| DMA | `"al_dma_hal.h"` |
| 中断 | `"al_intr.h"` `"al_chip.h"`（中断号宏） |
| 缓存维护 | `"al_cache.h"` |
| PL 复位 | `"al_top.h"` |
| 地址宏 | `"al_hwcfg.h"` |

> **省事写法**：SDK 里有一个**总头 `al_hal.h`**（在 `soc_base/dr1m90_fpsoc_cpu0/inc/`），一行 `#include "al_hal.h"` 就能把上表里**除前 5 类以外的全部外设 HAL** 一次带进来（GPIO / UART / TC / I2C / SPI / DMA / WDT / QSPI / GBE / MMC / ADC / CAN / USB，外加一批 AXI 版接口与 `al_core.h`）。
>
> ⚠️ **但它不管这 5 个，必须单独写**：`al_intr.h`（中断注册）、`al_top.h`（PL 复位）、`al_hwcfg.h`（地址宏）、`al_systimer.h`（延时）、`al_cache.h`（缓存维护）—— 这是最容易被"总头"漏掉的地方。
>
> 工程里现成的范例是 `fdma_en/main.c:31-40`，它**没用**总头，而是逐个包含 7 个（`al_core.h` · `ui_io.h` · `ui_type.h` · `al_cache.h` · `al_systimer.h` · `al_gpio_hal.h` + 3 个标准库）。**不确定就照抄它**。

---

## 九、总结

1. **心态**：安路 PS 侧**有库、且分层与 STM32 同构**（HAL / LL / DEV+CFG / HW），只是命名是 `Al*_Hal_*` / `Al*_ll_*`，且没有 CubeMX。门槛是**索引缺失**，不是能力缺失。
2. **通用四步**：定 DevId → 填 Init 结构体 → `AlXxx_Hal_Init(&h, ...)` 拿句柄 → 调业务 API。19 个外设一套逻辑。
3. **四个必踩的坑**：DevId 是 `cfg.c` 里的 `DeviceId` 字段值（**不是数组下标**，且查不到时返回的是"零填充空配置"而不是报错）；GPIO 引脚号 = MIO 编号（0–53；≥54 是 DR1 没有的 EMIO）；PWM 要靠 TC 的 Match + Wave 组合（**而 TC 目前还没使能**）；PS 侧只有 UART1 一路串口，且它就是日志口。
4. **PS 独有能力**是调度 PL，但三条通路里只有 TOP 寄存器与 `pl_gpio` 现在可用；"发阈值、读状态"要先改造 PL 侧开 AXI-GP0。
5. **学习顺序**：L1 认清家底 → L2 串口闭环 → L3 GPIO → L4 定时器/PWM → L5 协议与 DMA → 进阶 PL 调度。**每级都能在不改 PL 的前提下独立下板验证**。

---

## 附：本教程的源码索引（全部只读）

| 关注点 | 路径（相对 `mipiHDMIbySD/soc_sdk/`） |
|---|---|
| 全部外设基址 | `soc_base/dr1m90_fpsoc_cpu0/chip/dr1x90/common/inc/al_hwcfg.h` |
| 中断号、芯片初始化 | `soc_base/dr1m90_fpsoc_cpu0/chip/dr1x90/dr1m90/inc/al_chip.h` |
| PL 复位 / 时钟 HAL | `soc_base/dr1m90_fpsoc_cpu0/chip/dr1x90/common/inc/al_top.h` |
| 各外设 API（19 个） | `soc_base/dr1m90_fpsoc_cpu0/driver/ps_driver/<外设>/inc/al_<外设>_hal.h` |
| 各外设实例表（查 DevId） | `soc_base/dr1m90_fpsoc_cpu0/driver/ps_driver/<外设>/src/al_<外设>_cfg.c` |
| 公共头（类型/中断/延时/缓存） | `soc_base/dr1m90_fpsoc_cpu0/inc/` |
| 应用现有写法 | `fdma_en/main.c` |
| 寄存器读写与类型 | `fdma_en/ui_io.h` · `fdma_en/ui_type.h` |
| 链接脚本 | `fdma_en/lds/gcc_dr1m90_ddr_aarch64.ld` |

| 相关文档 | 路径 |
|---|---|
| 总控架构（要建成的样子） | `../总控架构.md` |
| PS 软件架构（现状全解） | `../推进总控前/推进总控前的PS架构.md` |
| 引脚复用配置表（`psio_data_0` 出处） | `<D:\项目\FPGA工程\02-工程实操\10-平台\GetStabilityPS(base-fdma_en)\稳定的平台存档\mipiHDMIbySD\soc_sdk\soc_base\platform\src\soc_plat.c>` |
| 底板原理图（MIO / KEY / LED 接法） | `<D:\项目\FPGA工程\安路平台资料\硬件数据手册\硬件资料_MLK_F3P_CZ02_DR1_20250526\02_原理图\MLK_F3P_DR1_250526.pdf>` |
| 外设分组引脚表（PS-ETH / PS-USB / PS-TF / UART / 按钮-LED） | `<D:\项目\FPGA工程\安路平台资料\硬件数据手册\硬件资料_MLK_F3P_CZ02_DR1_20250526\08_框图及pinlist\MLK-F3P>` |
| PS 侧风险清单 | `../推进总控前/总控平台建立起的问题.md` |
