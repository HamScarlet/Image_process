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
<text x="72" y="346" font-size="11" fill="#185FA5">查 cfg.c 表序</text>
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

**读图口诀**：上半部分是**代码仓库的目录结构**（① 是你调用的，④ 是你永远不用碰的）；下半部分是**每次初始化的固定四步**。记住一句话：**DevId 是"第几个实例"的序号，不是 STM32 里的 `UART1` 这种宏**——填错就操作到别的外设上。

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
<text x="54" y="246" font-size="11" fill="#C83C3C">UART1 被日志占用 ⇒ 屏建议用 UART0</text>
<rect x="345" y="150" width="295" height="110" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="359" y="172" font-size="12" font-weight="500" fill="#3C3489">④ 通信协议 I2C / SPI</text>
<text x="359" y="192" font-size="11" fill="#534AB7">I2C0 0xF8414000 · I2C1 0xF8415000</text>
<text x="359" y="210" font-size="11" fill="#534AB7">SPI0 0xF8404000 · SPI1 0xF8405000</text>
<text x="359" y="228" font-size="11" fill="#534AB7">AlIic_Hal_Master*DataBlock / Polling</text>
<text x="359" y="246" font-size="11" fill="#534AB7">AlSpi_Hal_TranferDataBlock / Polling</text>
</svg>

**读图口诀**：四块按"由简到难"排列（左右两列各成一组）。🔴 红色那几行是**你一定会踩的坑**，不是补充说明：

1. **GPIO 引脚号是全局线性编号**——`MAX_PIN_NUMBER_IN_BANK_0 = 31`、`BANK1 = 53`、`BANK2 = 85`、`BANK3 = 117`，没有 `PA5` 这种写法。
2. **PWM 不是独立外设**——TC（Timer Counter）用"比较匹配 + 波形输出"两件事拼出 PWM，对应关系是 `EnableMatchMode` + `SetMatchVal` + `EnableWaveOutput` + `SetWaveformPolarity`。
3. **UART1 已被日志占用**——`printf` 走的就是它（`0xF8401000`，板上 Type-C 口）。串口屏或外部模块要用 **UART0**，否则和日志打架。
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
| 练习 | 手抄一张表：UART0 / UART1 / GPIO / TC0__TC0 / I2C0 / SPI0 各自的**基址、中断号、DevId** |
| 验收判据 | 任给一个需求（如"用 I2C1 读传感器"），能在 1 分钟内说出它的基址、中断号、DevId |
| 常见坑 | 把 DevId 当成"引脚号"；把 `AL_UART_NUM_INSTANCE = 2` 当成"UART1" |

### L2 · 串口闭环（最小可观测系统）

| 项目 | 内容 |
|---|---|
| 为什么排第一 | **没有日志，后面全是盲调**。串口是唯一的输出通道 |
| 目标 | 用 `AlUart_Hal_Init` 初始化 **UART0**，发一行字符串；同时保留 UART1 的 printf |
| 关键 API | `AlUart_Hal_Init` → `AlUart_Hal_SendDataBlock` → 循环 `AlUart_Hal_RecvDataPolling` |
| 练习 | ① 发 `"hello\r\n"`；② 收到 `'a'` 回一个自增值；③ 把收发封装成 `my_uart_init()` / `my_uart_puts()` 两个函数放独立文件 |
| 验收判据 | 串口助手（115200, 8N1）能看到输出；发字符能收到回应 |
| 常见坑 | ① 接了 Type-C 口却以为是 UART0（**Type-C = UART1 = 日志口**）；② 忘记波特率要两边一致；③ 把 UART0 的引脚复用漏配（见 `psio_data_0` 表） |

> **L2 的隐藏收获**：你会第一次体会到"**在 `fdma_en/` 下新建 `.c`/`.h` 文件不需要改 Makefile**"——因为 Makefile 用 `find "./" -type d` 递归扫描目录，任何子目录里的 `.c` 都会被自动加入编译。这意味着你可以按功能建 `my_drv/` 子目录组织代码。

### L3 · GPIO 输入输出

| 项目 | 内容 |
|---|---|
| 目标 | 读一个输入（按键 / 跳线），驱动一个输出（PL 排针上的 LED 或示波器可测的脚） |
| 关键点 | ⚠️ **先搞清楚"PS 的 GPIO"和"PL 的 IO"是两套东西**：`0xF8411000` 的 GPIO 控制器管的是 **PS 域引脚（MIO）**，不是 FPGA 的引脚 |
| 关键 API | `AlGpio_Hal_Init(&h, 0, CallBack)` → `AlGpio_ll_SetDirection(...)` → `AlGpio_Hal_WritePin` / `ReadPinInput` |
| 练习 | ① 把一个引脚设成输出，1 Hz 翻转（用 `AlSys_MDelay(500)`）；② 把一个引脚设成输入，读回值随电平变化；③ 启用硬件消抖 `AlGpio_ll_EnableDebounce` 做按键 |
| 验收判据 | 输出波形在示波器上可见；按键按下时读值稳定翻转（无抖动毛刺） |
| 常见坑 | ① 想控制 FPGA 引脚却去操作 PS GPIO（**必须走 PL 逻辑或 pl_gpio**）；② 引脚号写成 `PA5` 风格（**这里只有 0–117 的全局编号**）；③ 忘记设方向，默认可能不是想要的 |

### L4 · 定时器与 PWM

| 项目 | 内容 |
|---|---|
| 目标 | 用 TC 产生**周期固定、占空比可调**的方波 |
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
| UART | 2 | UART0 `0xF8400000` · UART1 `0xF8401000` | **UART1 = 日志口（Type-C）** |
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

### 8.3 GPIO Bank 与引脚号（出自 `al_gpio_hal.h`）

| Bank 枚举 | 引脚号范围 | 该 Bank 最大引脚号常量 |
|---|---|---|
| `AL_GPIO_BANK0` | 0 – 31 | `MAX_PIN_NUMBER_IN_BANK_0 = 31` |
| `AL_GPIO_BANK1` | 32 – 53 | `MAX_PIN_NUMBER_IN_BANK_1 = 53` |
| `AL_GPIO_BANK2` | 54 – 85 | `MAX_PIN_NUMBER_IN_BANK_2 = 85` |
| `AL_GPIO_BANK3` | 86 – 117 | `MAX_PIN_NUMBER_IN_BANK_3 = 117` |

> **引脚号是累加的**：BANK1 的起始不是 0，而是 `BANK0 最大号 + 1`。写引脚号前先确认它在哪个 Bank。
> ⚠️ **待确认**：具体哪些引脚号被 MIO 复用占用了（UART1 占了 MIO48/49），需查 `psio_data_0` 配置表或原理图 pinlist。**不要凭猜测写引脚号**。

### 8.4 实例编号（DevId）怎么定

`DevId` 是**该外设在 `al_xxx_cfg.c` 数组里的下标，从 0 开始**：

| 外设 | `_NUM_INSTANCE` | DevId 取值 | 对应关系 |
|---|---|---|---|
| GPIO | 1 | `0` | 唯一的 GPIO 控制器 |
| UART | 2 | `0` / `1` | 0 = UART0 · 1 = UART1 |
| I2C | 2 | `0` / `1` | 0 = I2C0 · 1 = I2C1 |
| SPI | 2 | `0` / `1` | 0 = SPI0 · 1 = SPI1 |
| TC | 6 | `0` … `5` | 0–2 = TC0__TC0/1/2 · 3–5 = TC1__TC0/1/2 |
| DMA | 1 | `0` | 8 个通道在通道配置结构体里区分 |

> ⚠️ **待确认**：TC 与 DMA 的 DevId 顺序需在 `al_tc_cfg.c` / `al_dma_cfg.c` 的数组里**逐个核对**（本表按基址递增推断，未逐行验证）。**这是唯一不能用"顾名思义"的地方**——填错就操作到别的实例。

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

---

## 九、总结

1. **心态**：安路 PS 侧**有库、且分层与 STM32 同构**（HAL / LL / DEV+CFG / HW），只是命名是 `Al*_Hal_*` / `Al*_ll_*`，且没有 CubeMX。门槛是**索引缺失**，不是能力缺失。
2. **通用四步**：定 DevId → 填 Init 结构体 → `AlXxx_Hal_Init(&h, ...)` 拿句柄 → 调业务 API。19 个外设一套逻辑。
3. **四个必踩的坑**：DevId 是数组下标不是宏；GPIO 引脚号是 0–117 的全局线性编号；PWM 要靠 TC 的 Match + Wave 组合；UART1 已被日志占用。
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

| 关联文档 | 路径 |
|---|---|
| 总控架构（要建成的样子） | `../总控架构.md` |
| PS 软件架构（现状全解） | `../推进总控前/推进总控前的PS架构.md` |
| PS 侧风险清单 | `../推进总控前/总控平台建立起的问题.md` |
