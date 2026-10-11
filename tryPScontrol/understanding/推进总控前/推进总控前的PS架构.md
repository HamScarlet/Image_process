# mipiHDMIbySD 稳定平台 · soc_sdk 软件架构（FSBL + BSP + 应用）

> 存档：`GetStabilityPS(base-fdma_en)/稳定的平台存档/mipiHDMIbySD` ｜ 范围：**只读 `soc_sdk`**（PS 软件侧）｜ 芯片：DR1M90GEG400（-2 速度等级）｜ 核：单核 APU Core0（Cortex-A35，AArch64）
> 本文以图为主，逐级解释「每一层在干什么、每个数值为什么是这个数」。PL 侧逻辑在 `../soc_prj` 与 `../soc_hw`，**不在本文范围内**，仅在接口处引用。

---

## 一、图 1：启动链与运行时

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 630" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>mipiHDMIbySD 的启动链与运行时序</title>
<desc>SD 卡启动镜像经 CSU BootROM 加载 FSBL 到 OCM，FSBL 四个阶段完成平台初始化与分区加载后 Handoff 给应用，应用在 DDR 运行并释放 PL 复位</desc>
<defs>
<marker id="flow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<rect x="40" y="30" width="600" height="50" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="51" font-size="13" font-weight="500" fill="#0C447C">SD 卡启动镜像（FATFS 文件系统）</text>
<text x="60" y="69" font-size="12" fill="#185FA5">分区顺序：P0 = FSBL · P1 = PL 码流 · P2 = fdma_en（本核程序排最后）</text>
<line x1="340" y1="80" x2="340" y2="100" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="104" width="600" height="50" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="125" font-size="13" font-weight="500" fill="#0C447C">CSU BootROM（芯片内固化，不可改）</text>
<text x="60" y="143" font-size="12" fill="#185FA5">上电运行：把 FSBL 读进 OCM、验证签名，再释放 APU Core0 复位</text>
<line x1="340" y1="154" x2="340" y2="174" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="178" width="600" height="50" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="60" y="199" font-size="13" font-weight="500" fill="#633806">FSBL · Stage 1：系统初始化</text>
<text x="60" y="217" font-size="12" fill="#854F0B">AlFsbl_Initialize() + Soc_PlatInit()：7 张配置表 + DDR 初始化</text>
<line x1="340" y1="228" x2="340" y2="248" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="252" width="600" height="50" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="60" y="273" font-size="13" font-weight="500" fill="#633806">FSBL · Stage 2：读盘与校验</text>
<text x="60" y="291" font-size="12" fill="#854F0B">DeviceOps 赋值 + 校验 Image/Partition Header；JTAG 模式直接跳 Stage 4</text>
<line x1="340" y1="302" x2="340" y2="322" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="326" width="600" height="50" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="60" y="347" font-size="13" font-weight="500" fill="#633806">FSBL · Stage 3：加载各分区</text>
<text x="60" y="365" font-size="12" fill="#854F0B">循环 AlFsbl_PartitionLoad()：PartitionIdx 从 1 到 PartitionNum</text>
<line x1="340" y1="376" x2="340" y2="396" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="400" width="600" height="50" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="60" y="421" font-size="13" font-weight="500" fill="#633806">FSBL · Stage 4：Handoff</text>
<text x="60" y="439" font-size="12" fill="#854F0B">AlFsbl_Handoff()：把控制权交给本核的应用程序（fdma_en）</text>
<line x1="340" y1="450" x2="340" y2="470" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="474" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="495" font-size="13" font-weight="500" fill="#085041">fdma_en 应用运行（DDR）</text>
<text x="60" y="513" font-size="12" fill="#0F6E56">_start 0x08000000 · main 0x08001720 · 链接窗 16 MB</text>
<line x1="340" y1="524" x2="340" y2="544" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="548" width="600" height="50" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="60" y="569" font-size="13" font-weight="500" fill="#3C3489">Fclk_Init() → PL 解除复位</text>
<text x="60" y="587" font-size="12" fill="#534AB7">p2f_rst_n[3:0] = 0xF → PLL → locked → VTC/HDMI_TX，HDMI 出 TMDS</text>

<text x="40" y="618" font-size="11" fill="#5F5E5A">注：FSBL 全程在 OCM 0x61000000（252 KB）；应用链接到 DDR 0x08000000（跳过 BootROM 不可访问的前 1 MB）</text>
</svg>

**读图口诀**：自上而下就是**上电到出图的时间顺序**。🔵 蓝色 = 芯片外部/固化的第一段（SD 卡、BootROM）；🟡 橙色 = FSBL 的四个阶段（一个程序、一个 while 循环里的四个 case）；🟢 绿色 = 真正的应用（跑在 DDR）；🟣 紫色 = 应用做的最后一件关键事：把 PL 从复位里放出来。**注意 FSBL 和应用是两段独立程序**，之间是"跳转"，不是函数调用。

---

## 二、图 2：软件分层与构建产物

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 500" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>soc_sdk 的软件分层与构建产物</title>
<desc>应用层、平台板级层、BSP 层、第三方与预编译库四层向下依赖，最终链接成四个静态库与一个可执行文件</desc>

<rect x="40" y="30" width="600" height="54" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="51" font-size="13" font-weight="500" fill="#085041">① 应用层 · fdma_en（Application Project）</text>
<text x="60" y="71" font-size="11" fill="#0F6E56">main.c · ui_io.h · ui_type.h · lds/ 5 个链接脚本 → build/fdma_en.elf（2,693,952 B）</text>

<rect x="40" y="104" width="600" height="54" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="60" y="125" font-size="13" font-weight="500" fill="#633806">② 平台板级层 · soc_base/platform → libplat.a</text>
<text x="60" y="145" font-size="11" fill="#854F0B">soc_plat.c（7 张配置表 + 操作码解释器）· fd_ddr_init.c（DDR 训练与映射）· ddr_speed_bin.c</text>

<rect x="40" y="178" width="600" height="54" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="199" font-size="13" font-weight="500" fill="#0C447C">③ BSP 芯片支持层 · soc_base/dr1m90_fpsoc_cpu0 → libalbsp.a</text>
<text x="60" y="219" font-size="11" fill="#185FA5">inc（al_core · al_cache · al_systimer）· arch/armv8 · chip/dr1x90 · ps_driver 19 个</text>

<rect x="40" y="252" width="600" height="54" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="60" y="273" font-size="13" font-weight="500" fill="#444441">④ 第三方与预编译库</text>
<text x="60" y="293" font-size="11" fill="#5F5E5A">FATFS vR0.14b（SD 启动必需）· semihost（半主机打印）· prebuild/dr1m90/64/libddr.a</text>

<rect x="40" y="326" width="600" height="54" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="60" y="347" font-size="13" font-weight="500" fill="#3C3489">⑤ 链接产物：4 个静态库 + 1 个对象文件</text>
<text x="60" y="367" font-size="11" fill="#534AB7">libalbsp.a + libfatfs.a + libplat.a + libsemihost.a → fdma_en.elf / .bin / .map</text>

<rect x="40" y="396" width="600" height="64" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="60" y="416" font-size="12" font-weight="500" fill="#444441">构建开关（Makefile / board_cfg.mk）</text>
<text x="60" y="435" font-size="10" fill="#5F5E5A">DOWNLOAD=ddr|ocm 决定链接脚本；ARMv8_STATE=64 → aarch64；-march=armv8-a -mcpu=cortex-a35 -mstrict-align</text>
<text x="60" y="452" font-size="10" fill="#5F5E5A">-DAL_CLK_800M · -DAL_OSC_33 · -DAL_BRINGUP · -DBOARD_DR1X90_AD101_V10（日志走 UART1）</text>
</svg>

**读图口诀**：从上到下 = **编译依赖方向**（上层要用下层的接口，下层不知道上层存在）。①②③ 是三个工程/目录层级，④ 是外来的库，⑤ 是最终被链进可执行文件的东西。底部灰卡是"开关"，决定了链接脚本、指令集与外设初值——**改硬件配置后，这些宏跟着 soc_plat.h 一起被重新生成**。

---

## 三、图 3：时钟树与分频推导

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 490" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>DR1M90 平台时钟树与分频推导</title>
<desc>33.33MHz 晶振经 PLL 得到 1999.8MHz 基准，再分频得到 CPU、IO 各档、p2f_clk0 与外设时钟</desc>
<defs>
<marker id="flow3" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<rect x="40" y="30" width="240" height="42" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="52" y="50" font-size="13" font-weight="500" fill="#444441">OSC 晶振 33.33 MHz</text>
<text x="52" y="66" font-size="11" fill="#5F5E5A">SYSTEM_CLOCK · -DAL_OSC_33</text>
<line x1="160" y1="72" x2="160" y2="90" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<rect x="40" y="90" width="240" height="42" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="52" y="110" font-size="13" font-weight="500" fill="#633806">PLL 基准 1999.8 MHz</text>
<text x="52" y="126" font-size="11" fill="#854F0B">33.33 × FBK_DIV(120) ÷ REF_DIV(2)</text>

<line x1="50" y1="132" x2="50" y2="433" stroke="#888780" stroke-width="1"/>
<line x1="50" y1="193" x2="76" y2="193" stroke="#888780" stroke-width="1"/>
<line x1="50" y1="233" x2="76" y2="233" stroke="#888780" stroke-width="1"/>
<line x1="50" y1="273" x2="76" y2="273" stroke="#888780" stroke-width="1"/>
<line x1="50" y1="313" x2="76" y2="313" stroke="#888780" stroke-width="1"/>
<line x1="50" y1="353" x2="76" y2="353" stroke="#888780" stroke-width="1"/>
<line x1="50" y1="393" x2="76" y2="393" stroke="#888780" stroke-width="1"/>
<line x1="50" y1="433" x2="76" y2="433" stroke="#888780" stroke-width="1"/>

<rect x="76" y="176" width="200" height="34" rx="6" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="88" y="197" font-size="11" fill="#085041">CPU 999.9 MHz（÷2）</text>
<text x="292" y="197" font-size="11" fill="#0F6E56">CPU_CLOCK = 1999.8 ÷ 2 = 999.9 MHz</text>

<rect x="76" y="216" width="200" height="34" rx="6" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="88" y="237" font-size="11" fill="#085041">IO_1000 999.9 MHz（÷2）</text>
<text x="292" y="237" font-size="11" fill="#0F6E56">IO_1000_FREQ = 1999.8 ÷ 2 = 999.9 MHz</text>

<rect x="76" y="256" width="200" height="34" rx="6" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="88" y="277" font-size="11" fill="#085041">IO_400 399.96 MHz（÷5）</text>
<text x="292" y="277" font-size="11" fill="#0F6E56">IO_400_FREQ = ÷5 = 399.96 MHz（= MMC_CLOCK）</text>

<rect x="76" y="296" width="200" height="34" rx="6" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="88" y="317" font-size="11" fill="#085041">IO_80 79.992 MHz（÷25）</text>
<text x="292" y="317" font-size="11" fill="#0F6E56">IO_80_FREQ = ÷25 = 79.992 MHz</text>

<rect x="76" y="336" width="200" height="34" rx="6" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="88" y="357" font-size="11" fill="#085041">IO_25 24.9975 MHz（÷80）</text>
<text x="292" y="357" font-size="11" fill="#0F6E56">IO_25_FREQ = ÷80 = 24.9975 MHz</text>

<rect x="76" y="376" width="200" height="34" rx="6" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="88" y="397" font-size="11" fill="#3C3489">p2f_clk0 199.98 M（÷10）</text>
<text x="292" y="397" font-size="11" fill="#534AB7">P2F_CLOCK_0 = 199.98 MHz → 送 PL</text>

<rect x="76" y="416" width="200" height="34" rx="6" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="88" y="437" font-size="11" fill="#444441">外设时钟 49.995 / 19.998 M</text>
<text x="292" y="437" font-size="11" fill="#5F5E5A">UART_CLOCK / QSPI_CLOCK（÷40 / ÷100）</text>

<text x="40" y="470" font-size="11" fill="#5F5E5A">注：IO 域各分频取自同一条 1999.8 MHz 基准；49.995 MHz = ÷40，19.998 MHz = ÷100</text>
</svg>

**读图口诀**：左边一列盒子是"档位"，右边是该档位的推导式。最上面两条是根（晶振 → PLL 基准），下面七条是从同一根基准分出来的。🟢 绿色 = 片内（CPU 与 IO 各档），🟣 紫色 = **唯一一根送出去的时钟 `p2f_clk0`**，⚪ 灰色 = 外设派生档。看这张图只需要记住一句：**全部时钟都从 1999.8 MHz 这一条分下来，没有第二个参考源。**

---

## 四、图 4：Fclk_Init 的寄存器时序（本存档最核心的一段代码）

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 480" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>Fclk_Init 的寄存器写序列与读回判据</title>
<desc>应用启动后依次操作三个寄存器把 PL 按进复位再释放，最后读回 p2f_rst_n 并进入保活循环</desc>
<defs>
<marker id="flow4" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<line x1="92" y1="30" x2="92" y2="400" stroke="#888780" stroke-width="1"/>

<rect x="40" y="38" width="44" height="30" rx="6" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="62" y="58" font-size="13" fill="#0C447C" text-anchor="middle">0</text>
<rect x="104" y="30" width="536" height="46" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="118" y="49" font-size="12" font-weight="500" fill="#0C447C">App 启动：延时 2 s 后打印 banner</text>
<text x="118" y="66" font-size="11" fill="#185FA5">AlSys_MDelay(2000) · 日志口 UART1 = 0xF8401000（115200 bps）</text>

<rect x="40" y="94" width="44" height="30" rx="6" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="62" y="114" font-size="13" fill="#633806" text-anchor="middle">1</text>
<rect x="104" y="86" width="536" height="46" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="118" y="105" font-size="12" font-weight="500" fill="#633806">① 先把 PL 按进复位</text>
<text x="118" y="122" font-size="11" fill="#854F0B">0xF8806330 ← val &amp; ~0xF0（bit[7:4] = p2f_rst_n[3:0] 全部清零）</text>

<rect x="40" y="150" width="44" height="30" rx="6" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="62" y="170" font-size="13" fill="#633806" text-anchor="middle">2</text>
<rect x="104" y="142" width="536" height="46" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="118" y="161" font-size="12" font-weight="500" fill="#633806">② 使能 GP / FAHB 端口</text>
<text x="118" y="178" font-size="11" fill="#854F0B">0xF8800080 ← val &amp; ~0x2（bit1 清零）</text>

<rect x="40" y="206" width="44" height="30" rx="6" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="62" y="226" font-size="13" fill="#633806" text-anchor="middle">3</text>
<rect x="104" y="198" width="536" height="46" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="118" y="217" font-size="12" font-weight="500" fill="#633806">③ 复位再释放 4 个 AXI 接口</text>
<text x="118" y="234" font-size="11" fill="#854F0B">0xF8801078 ← val &amp; ~0x33 → 延时 1 ms → val | 0x33（GP0M/GP1M/HP0/HP1）</text>

<rect x="40" y="262" width="44" height="30" rx="6" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="62" y="282" font-size="13" fill="#085041" text-anchor="middle">4</text>
<rect x="104" y="254" width="536" height="46" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="118" y="273" font-size="12" font-weight="500" fill="#085041">④ 释放 PL 复位（关键一步）</text>
<text x="118" y="290" font-size="11" fill="#0F6E56">0xF8806330 ← val | 0xF0 → p2f_rst_n[3:0] = 0xF</text>

<rect x="40" y="318" width="44" height="30" rx="6" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="62" y="338" font-size="13" fill="#444441" text-anchor="middle">5</text>
<rect x="104" y="310" width="536" height="46" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="118" y="329" font-size="12" font-weight="500" fill="#444441">⑤ 读回判据（诊断插桩的核心）</text>
<text x="118" y="346" font-size="11" fill="#5F5E5A">(v6330 &gt;&gt; 4) &amp; 0xF == 0xF → 已释放；否则「全黑根因在这里」</text>

<rect x="40" y="374" width="44" height="30" rx="6" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="62" y="394" font-size="13" fill="#3C3489" text-anchor="middle">6</text>
<rect x="104" y="366" width="536" height="46" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="118" y="385" font-size="12" font-weight="500" fill="#3C3489">⑥ 保活循环（每秒复查一次）</text>
<text x="118" y="402" font-size="11" fill="#534AB7">while(1) { AlSys_MDelay(1000); 读 0xF8806330 并打印 }</text>

<text x="40" y="436" font-size="11" fill="#5F5E5A">注：0xF8801078 在 FSBL 平台初始化（ps_pl_0 表）里已被写过一次：bit0 = nic_hp0_srst_n 置 1。</text>
<text x="40" y="454" font-size="11" fill="#5F5E5A">App 的 Fclk_Init 又整体清 0 再置 0x33 —— 同一寄存器被两处操作，是排查时容易忽略的一处交叉。</text>
</svg>

**读图口诀**：左侧竖线是时间轴，圆形数字是顺序。读法只有一条主线：**先把 PL 按死（①）→ 把接口使能（②）→ 给四个 AXI 口一个干净的复位脉冲（③）→ 再把 PL 放出来（④）→ 读回来确认（⑤）→ 别让程序结束（⑥）**。🟡 橙色三步是"准备工作"，🟢 绿色那一步才是真正让图亮起来的动作，⚪ 灰色是判据，🟣 紫色是保命用的。

---

## 五、一句话总览

**SD 卡里躺着三段东西（FSBL、PL 码流、应用）。芯片自带的 BootROM 先把 FSBL 搬进 OCM 跑起来；FSBL 负责"配好板子 → 把 PL 配上 → 把应用搬进 DDR"，然后把 CPU 交给应用；应用做的最后一件关键事，是把 PL 从复位里放出来——图像才开始流动。**

一个必须先建立的认知：**PS 侧不是"操作系统 + 驱动"，而是"两段裸机程序接力"**。FSBL 跑完就消失（Handoff 跳转，不返回），应用接管 CPU。所以"程序有没有跑起来"和"PL 有没有被放出来"是两件事，排障时要分开看。

| 图/章节 | 回答的问题 | 类比 |
|---|---|---|
| 第一节 图 1 | 从上电到出图**经过谁** | 接力赛：BootROM → FSBL → 应用，三棒 |
| 第二节 图 2 | 代码**怎么组织、怎么编成产物** | 四层楼，上层用下层的接口 |
| 第三节 图 3 | 全芯片的**节拍从哪来** | 一台上游水轮机带动所有皮带轮 |
| 第四节 图 4 | 应用**怎么把 PL 放出来** | 按 4 个开关的顺序问题，顺序错了 PL 不动 |
| 第六节 逐级详解 | 每一棒的**细节与为什么** | 交接单 |
| 第九节 配置与上电顺序 | 硬件配置**怎么流进软件** | 硬件改一版 → 自动生成一份表 → PS 代码不改 |

---

## 六、逐级详解（9 级）

### 第 1 级：SD 卡启动镜像（不是"一个 bin"，而是"一串分区"）

| 项目 | 内容 |
|---|---|
| 载体 | SD 卡，**FATFS 文件系统**（本平台使能 `LIB_FATFS vR0.14b`，`PS_DRIVER_USB`/MMC 都依赖它） |
| 分区顺序 | **P0 = FSBL（必须第一）→ P1 = PL 码流（要加载 PL 就必须第二）→ P2…= 各核应用；运行 FSBL 的那个核的程序必须排最后** |
| 为什么是这个顺序 | 由 FSBL/BootROM 的解析逻辑决定（`alfsbl_readme.md` 明文规定）。FSBL 要"先读到自己"，所以它必须在最前 |
| 打包方式 | 用 FD 工具把码流/程序打包成启动镜像；有安全需求时可对每个 Partition 指定加密与签名验证 |
| 待确认 | 本存档**未包含 `.bif`/打包脚本**，实际分区表以 SD 卡上的镜像为准 |

### 第 2 级：CSU BootROM（芯片内固化，不可修改）

| 项目 | 内容 |
|---|---|
| 干什么 | 上电 → CSU 运行 BootROM → 从启动设备读启动镜像 → **把 FSBL 加载到 OCM** → 解密/验签（若配置）→ 释放目标处理器复位 |
| 读启动模式 | `SYSCTRL_NS_BOOT_MODE = 0xF8800200`（`soc_plat.h`：`0xF8800000 + 0x200`） |
| **为什么 DDR 前 1 MB 不能用** | BootROM **访问不到 `0x0~0xFFFFF`**（1 MB），官方建议这段保留不用。这就是应用链接基址是 `0x08000000` 的直接原因 |
| 本存档的启动模式 | 目录名 `mipiHDMIbySD`、SD 模式受支持、FATFS 与 MMC 驱动均已使能 → 按 **SD 启动**；确切值以串口 `[BOOT INFO] Boot Mode` 为准（`al_bootMode_Log()` 会打印） |

### 第 3 级：FSBL · Stage 1（系统初始化）

| 项目 | 内容 |
|---|---|
| 干什么 | `AlFsbl_Initialize()`；`main()` 第一句就调 `Soc_PlatInit()`（`soc_plat.c`） |
| 平台初始化 7 步 | `system_data_0` → `psio_data_0` → `clk_data_0` → 打印 Boot Mode → `ps_pl_0` → DDR → `peripherals_data_0` → `debug_data_0` |
| DDR 那一步 | `DDRPS_ENABLE == 1` 时走 **`fd_ddr_init()`**（真训练 + 自动算地址映射）；否则走静态表 `ddr_data_0`。本平台是前者 |
| **为什么必须放最前** | 后面要读 SD 卡（MMC 控制器）、要打日志（UART），都依赖时钟与外设已经配好。**先配钟，再用外设**是这类裸机程序不变的顺序 |
| 版本判据 | `Soc_PlatGetDeviceVersion()` 硬编码返回 `SOC_VERSION_1`；不等于该值就返回 `PLAT_INIT_VERSION_ERROR` |

### 第 4 级：FSBL · Stage 2（读盘与校验）

| 项目 | 内容 |
|---|---|
| 干什么 | 读 `SYSCTRL_NS_BOOT_MODE` → `switch` 分支给 `DeviceOps` 三个函数指针赋值（`DeviceInit` / `DeviceCopy` / `DeviceRelease`）→ 读并校验 Image Header / Partition Header |
| 支持的启动模式 | JTAG / QSPI24 / QSPI32 / NAND / EMMC / EMMC1 / SD / EMMC Raw（`soc_plat.h` 给出取值 0x0~0x7）；**不支持 USB、Ethernet** |
| SD / EMMC 走同一驱动 | 三个 case（`EMMC`、`EMMC1`、`SD`）共用 `AlFsbl_SdInit/Copy/Release`，统一由 `HAVE_MMCPS_DRIVER` 门控 |
| **JTAG 模式是短路路径** | 返回 `ALFSBL_STATUS_JTAG` → `main()` 直接跳到 Stage 4（不加载任何分区），这是调试用的入口 |
| 为什么用函数指针 | 一份主流程适配 4 类非易失存储器；换启动介质只换三个函数，不动流程 |

### 第 5 级：FSBL · Stage 3（循环加载分区）

| 项目 | 内容 |
|---|---|
| 干什么 | `PartitionIdx` **从 1 开始**（0 是 FSBL 自己），循环调 `AlFsbl_PartitionLoad()`，直到 `PartitionIdx == PartitionNum` |
| 边界处理 | 只有 1 个分区时打印 "Only one partition exists in boot image, which is fsbl itself / for test only"；`PartitionIdx > PartitionNum` → `ALFSBL_ERROR_INVALID_PARTITION_NUM` |
| 缓冲区 | `ReadBuffer[READ_BUFFER_SIZE]`、`AuthBuffer[ALFSBL_AUTH_BUFFER_SIZE]`、`HashBuffer[32]`，**全部 `__attribute__((aligned(64)))`** |
| 为什么 64 字节对齐 | 对齐到缓存行，避免 DMA/校验时的缓存一致性问题；`HashBuffer` 32 字节 = **SHA-256 摘要长度**，对应验签流程 |

### 第 6 级：FSBL · Stage 4（Handoff）

| 项目 | 内容 |
|---|---|
| 干什么 | `AlFsbl_Handoff()`：把控制权交给本核应用；成功后**再也不会返回**（源码注释 "we should never be here"） |
| 出错路径 | Stage Err → `AlFsbl_PrintErrorMessage()` + `AlFsbl_ErrorLockDown()` |
| Fallback | 启动出错时 FSBL 可把 **MultiBoot 寄存器 +1** 并触发复位，让 BootROM 换下一个启动镜像（readme） |
| **为什么是"跳转"而不是"调用"** | FSBL 与应用是两个独立 ELF，各有自己的异常向量与栈（FSBL 栈 8 KB、应用栈 6 MB）。Handoff 之后 FSBL 的内存可以被覆盖 |

### 第 7 级：应用 `fdma_en`（当前是"诊断插桩版"）

| 项目 | 内容 |
|---|---|
| 链接位置 | `_start = 0x08000000`、`main = 0x08001720`（实测 ELF 入口 `0x08000000`，AArch64 / ELF64 / 小端） |
| 运行流程 | 延时 2 s → 打印 banner → `dump_regs("before")` → `Fclk_Init()` → `dump_regs("after ")` → 判据打印 → **死循环保活（每秒打印一次 `0xF8806330`）** |
| **为什么要保活** | main.c 注释写明：`main()` return 后 C 运行时的复位流程会把 `p2f_rst_n` 重新拉低——这正是"闪一下 → 全黑"的嫌疑机理 |
| 日志口 | **UART1 = `0xF8401000`**，115200（`UART1_BAUDRATE`）；板上是 **Type-C 那个口**（PS MIO48/49），接错口会一行日志都没有 |
| banner 里的 `str` | 源码里 `const AL_CHAR *str = "axi fdma test!"` —— 这是原始 demo 留下的字符串，**不代表当前功能** |
| ⚠️ **重要** | **`soc_sdk` 里没有任何 FDMA 驱动代码**：全仓 grep 只有 main.c 的这句字符串。平台名里的 `fdma_en` 指 **PL 侧 FDMA 通道被使能**；PS 侧只负责提供通路（HP0 + DDR） |

### 第 8 级：平台初始化机制（7 张表 + 操作码解释器）

| 表名 | 管什么 | 关键项（实测） |
|---|---|---|
| `system_data_0` | 系统级 | Bank201 强制 LVCMOS 1.8V（`0xF8803C04[5:4]=0x1`）；**NPU Disable**（`0xF88001B8[1:0]=0`） |
| `psio_data_0` | PS IO 引脚 | 引脚复用与驱动 |
| `clk_data_0` | 时钟 | 分频器（结果见第三节时钟树） |
| `ps_pl_0` | PS↔PL 接口 | **只有 2 条**：`0xF8801078[0]=1` 释放 HP0 复位；`0xF8800084[0]=0` HP0 = 64 bit |
| `ddr_data_0` | DDR 静态配置 | 本平台**未走这条**（`DDRPS_ENABLE=1` → `fd_ddr_init()`） |
| `peripherals_data_0` | 外设 | 各外设使能与参数 |
| `debug_data_0` | 调试 | DDR 调试开关（`USE_DDR_DEBUG`） |

操作码机制（`__plat_config()`）：

| opcode | 语义 | 参数 |
|---|---|---|
| `CONFIG_EXIT` | 结束 | 0 |
| `CONFIG_CLEAR` | 整字写 0 | addr |
| `CONFIG_WRITE_REG` | 整字写值 | addr, val |
| `CONFIG_MASKWRITE` | 位域改写 | addr, mask, val |
| `CONFIG_MASKPOLL` | 轮询直到匹配 | addr, mask, val（超时 `CONFIG_POLL_TIME = 100000` 次 → `PLAT_INIT_TIMEOUT`）|

- 每条表项 = `(opcode << 4) | numargs`，后跟参数（最多 16 个）。
- **为什么解释器要加 `__attribute__((optimize(0)))`**：这些写操作是 MMIO，编译器若把循环/重复读写优化掉，时序就变了——关优化等于给寄存器时序上保险。
- **为什么要"表 + 解释器"**：7 张表都是 **hpfTool 从 TD/HPF 导出时自动生成的**。硬件改一版，重新导出即可，**PS 代码一行不用改**。

### 第 9 级：PS↔PL 边界（4 条线，全部出自 `Design.xml`）

| 信号 | 方向 | 位宽 / 值 | 出处 |
|---|---|---|---|
| `slave_hp0_axi_*` | **PL 主 → PS 从**（PL 写 DDR） | **64 bit** | `Slave_AXI_HP0_DATA_WIDTH=64`、`wmode_hp0=0` |
| `p2f_rst0_n` | PS → PL | 1 bit 复位 | `P2F_Reset0_Available=1`（Reset1~3 = 0） |
| `p2f_clk0` | PS → PL | 199.98 MHz | `P2F_CLOCK_0` / `p2f_clk0_Dot_Actual_IO_Frequency=199.98` |
| `pl_gpio_in` / `pl_gpio_oe` / `pl_gpio_out` | 双向 | 1 bit，**三线全断** | `Design.xml` adHocConnections 里勾了宏，但 RTL 侧 `out` 悬空（不在顶层端口表内）、`oe` 空连接、`in` 接常量 `1'b0`；TD 自带的 `system.violation` 已报 `input port lack of connection` |

> ⚠️ **两条硬约束（很容易踩）**：
> 1. **GP0 / GP1 主从口全部未使能**（`Master_AXI_GP0/1=0`、`Slave_AXI_GP0/1=0`）→ **PS 没有任何 AXI 通道能主动读写 PL 内部寄存器**。PS 对 PL 的控制手段实际上**只剩 `p2f_rst0_n` 一根线**——`pl_gpio` 看着像第二条通道，但 RTL 里三根线全没接（见上表），不能用。
> 2. **中断全部未使能**：`F2P_IRQ_Available = 0`，`P2F_IRQ_*`（DMAC_AHB/QSPI/DDR/GPIO/USB/ETH/SDIO/UART1）全为 0 → **PL 不能中断通知 PS**，PS 只能轮询。这正是 main.c 用"每秒读一次寄存器"这种做法的原因。

---

## 七、地址与容量总表

| 区域 | 地址 | 容量 | 谁在用 / 出处 |
|---|---|---|---|
| BootROM 保留区 | `0x00000000 ~ 0x000FFFFF` | 1 MB | BootROM 访问不到，建议保留（`alfsbl_readme.md`） |
| **应用运行区（DDR）** | `0x08000000` | **16 MB 链接窗** | `ram: ORIGIN=0x8000000 LENGTH=0x1000000`；`_start=0x08000000`、`main=0x08001720` |
| **FSBL 运行区（OCM）** | `0x61000000` | **252 KB**（`0x3F000`） | 链接脚本 `gcc_dr1m90_ocm_aarch64.ld`；readme 写 `0x61000000~0x6103FFFF`（256 KB）；`fsbl.bin` = **207,488 B** |
| NPU RAM | `0x63E00000` | 256 KB | `npuram` 段（NPU 配置为 Disable，但链接区仍在） |
| `.rt_text` 搬运段 | LMA `0x08011780` → VMA `0x61000000` | — | map 可见：启动时把这段代码搬进 OCM 执行（把热代码放快内存的老手法） |
| 栈 | DDR 末尾 −32 KB −`__stack_size` | 应用 **6 MB** / FSBL **8 KB** | 两个脚本的默认值不同，别混用 |
| 打印环形缓冲 | 数据段内 | 1 MB | `__async_print_ring_buf_size` |
| 日志串口 | `0xF8401000`（UART1） | — | `al_hwcfg.h`；115200 |
| 帧缓存（PL 侧使用） | `0x0A000000` | — | 由 PL 的 `uidbuf` 写入，**属 `../soc_prj` 范围，本文不展开** |

> **最值得记住的一句话**：**DDR 的链接起点是 `0x08000000` 而不是 `0x0`，因为前 1 MB 是 BootROM 的盲区。** 这一条同时解释了"为什么应用不是从 0 开始"和"为什么 FSBL 文档要强调保留这段地址"。

---

## 八、时钟域

| 时钟 / 域 | 频率 | 来源 | 谁在用 |
|---|---|---|---|
| OSC | **33.33 MHz** | 板载晶振（`-DAL_OSC_33`） | PLL 参考 |
| PLL 基准 | **1999.8 MHz** | 33.33 × `CPU_FBK_DIV(120)` ÷ `CPU_REF_DIV(2)` | 全部时钟的父节点 |
| CPU | **999.9 MHz** | 1999.8 ÷ `CPU_OUT_DIV(2)` | Cortex-A35 |
| IO 各档 | 999.9 / 399.96 / 79.992 / 24.9975 MHz | ÷2 / ÷5 / ÷25 / ÷80 | 外设与 IO |
| 外设时钟 | UART 49.995 · QSPI 19.998（IO 再 ÷2 = 9.999）· MMC 399.96 · MMC0/1 IO 49.995 · WDT 16.665 · GBE 500 · I2C 100 · GPIO 12.5 · SPI/TC 200 · ADC 50 MHz | 见推导 | 对应驱动 |
| **p2f_clk0** | **199.98 MHz** | 1999.8 ÷ 10 | **送给 PL** 作参考时钟 |

**为什么没有"多时钟域"问题**：本平台是**单核单域**——只有一个 APU Core0 在跑，应用是裸机（standalone），不存在 SMP / AMP 拆分。`Soc_PlatInit()` 里其实已经准备好了 AMP 分支（`HAVE_OPENAMP` 或 `ARM_CORE_SLAVE` 时走 `__Soc_PlatInit_AMP()`，只配 psio/ps_pl/peripherals），但**本存档没有定义这些宏**，走的是完整版 `__Soc_PlatInit()`。

源码里的保护性写法（逐条）：

| 写法 | 位置 | 为什么 |
|---|---|---|
| `volatile` 指针读写寄存器 | `ui_io.h`（`UI_In32` / `UI_Out32`） | 防止编译器把 MMIO 读写优化掉 |
| 配置解释器关优化 | `soc_plat.c` `__plat_config()` | 同上，保证写寄存器的顺序与次数不被改 |
| `CONFIG_MASKPOLL` 带上限 | `CONFIG_POLL_TIME = 100000` | 防止硬件异常时死等（返回 `PLAT_INIT_TIMEOUT`） |
| 校验缓冲 64 字节对齐 | `alfsbl_main.c` | 缓存行对齐 |
| 复位用 PLL `locked` | （PL 侧）`system.v` | 时钟未稳前保持复位，属 PL 范围 |
| 靠 `tuser`/帧首复位统计量 | （PL 侧 ISP） | 少一个状态机少一处错 |

---

## 九、配置链与上电顺序

**配置从哪里流进软件（三级来源）：**

| 层级 | 文件 | 内容 |
|---|---|---|
| ① 硬件导出 | `soc_base/soc_prj.hpf`（873,403 B）→ `platform/inc/soc_plat.h` + `system.mss` + `Design.xml` | 时钟参数、外设使能、DDR 参数、Bank 电压、7 张配置表 —— **全部由 hpfTool 自动生成**（头部注释：`HPF_EXPORT_TIME 2026/10/05 17:20:34`、`BITSTREAM_GENERATE_TIME 2026/10/05 17:18:00`） |
| ② 工程设置（FD / App Setting） | `fsbl/Makefile`、`fdma_en/.settings/*.xml` | `DOWNLOAD=ocm`（FSBL）/ `DOWNLOAD=ddr`（应用）、`ARMv8_EL=EL3`、`DDR_2M_MAPPING=0`、`ALFSBL_WDT_EXCLUDE_VAL=0`、`ALFSBL_PMU_EXCLUDE_VAL=0`、`ALFSBL_PJTAG_ENABLE_VAL=0`、architecture=aarch64、standalone |
| ③ 板级开关 | `soc_base/platform/board_cfg.mk` | `-DAL_CLK_CONFIG`、`-DAL_CLK_800M`、`-DAL_OSC_33`、`-DAL_BRINGUP`、`-DBOARD_DR1X90_AD101_V10` |

**两级开关（容易混淆，实测有"编了但没配"的情况）：**

- `*PS_ENABLE`（`soc_plat.h`）= **外设是否被配置**：使能了 `DMAPS / ADCPS / GBE0PS / GPIOPL / GPIOPS / QSPIPS / MMC0PS / MMC1PS / UART1PS / USB0PS / DDRPS`；注释掉的有 `CAN0/1PS / GBE1PS / I2C0/1PS / SMCPS / SPI0/1PS / TC0/1PS / UART0PS / USB1PS / WDTPS`。
- `HAVE_*_DRIVER`（`soc_plat.h`，由 FD 生成）= **驱动代码是否编进来**，共 14 个：`ADCPS / DMAPS / GBEPS / GPIOPS / IICPS / IPCPS / MMCPS / MPUPS / QSPIPS / SMCPS / SPIPS / TCPS / UARTPS`…
- ⚠️ **实测不一致的例子**：`HAVE_IICPS_DRIVER` 已定义，但 `I2C0PS_ENABLE` / `I2C1PS_ENABLE` 都是注释状态 → **驱动编译进来了，外设却没配**。排查时不能只看其中一个。

**上电 / 启动推进顺序（谁先谁后、靠什么推）：**

1. 上电 → CSU BootROM（读启动模式 `0xF8800200`）→ 加载 FSBL 到 OCM → 验签 → 释放 Core0；
2. FSBL Stage 1：`Soc_PlatInit()` 7 张表（**先钟后外设**）+ DDR；
3. Stage 2：读盘 + 校验（JTAG 则直跳 Stage 4）；
4. Stage 3：逐个 Partition 加载（P1 = PL 码流）；
5. Stage 4：`AlFsbl_Handoff()` 跳转到应用（**不回返**）；
6. 应用：延时 → banner → `Fclk_Init()` → 读回 → 保活循环。

> ⚠️ **WDT 实际没在跑**：`ALFSBL_WDT_EXCLUDE_VAL = 0`（不排除 WDT 代码），但 `alfsbl_boot.c` 里 `AlFsbl_InitWdt()` 被注释掉（`/// todo`），且 `soc_plat.h` 里 `WDTPS_ENABLE` 也是注释状态。两处独立证据一致：**看门狗未启用**，所以"程序卡死"不会有 WDT 复位来救。

---

## 十、其他细节速查

| 项 | 出处 | 说明 |
|---|---|---|
| `p2f_rst_n` 名义 4 位，实际只用 bit0 | `Design.xml`：`P2F_Reset0_Available=1`，Reset1/2/3 = 0 | App 却整体读写 `0xF0`（4 位一起） |
| **同一寄存器被两处操作** | `ps_pl_0` 表 与 `main.c` | `0xF8801078`：FSBL 置`[0]=1`（释放 HP0 复位），App 又整体清 0 再置 `0x33` |
| FSBL 与应用共用同一个 BSP | 两个工程都以 `soc_base` 为 BSP | 都链 `libalbsp.a` / `libplat.a`（map 可证） |
| `pl_driver` 目录为空 | `soc_base/dr1m90_fpsoc_cpu0/driver/pl_driver` | 规则文件里列了 10 个 PL IP 驱动（axi_dma、axi_vdma…），但**本平台一个都没用** |
| 应用里没有 FDMA 代码 | 全仓 grep 只有 `main.c` 的字符串 | 见第 7 级 |
| FSBL 镜像大小贴近 OCM 上限 | `fsbl.bin` = 207,488 B vs OCM 252 KB | 余量约 44 KB，**再加功能要留意** |
| 串口速率 | `UART1_BAUDRATE = 115200` | 换季/换板先确认这个数 |
| 工具链 | `aarch64-none-elf-`（gcc / ld / ar / objcopy / objdump / size） | `-mtune/-mcpu=cortex-a35 -march=armv8-a -mstrict-align` |
| IDE 版本 | `.fdworkspace`：2026.1 / Build 20260330；`soc_plat.h`：TD `Release 6.2.1 Build 168116` | 两个是不同的工具（FD = SDK IDE，TD = FPGA IDE） |

**故障对照表（现象 → 首先怀疑什么）：**

| 现象 | 首先怀疑 |
|---|---|
| 串口一行都没有 | 接错口（**必须 UART1 = Type-C**）；或 FSBL 没起来（启动模式 / SD 镜像分区顺序） |
| 串口停在 `Stage Err` | 看 `AlFsbl_PrintErrorMessage()` 的错误码；先确认 `[BOOT INFO] Boot Mode` 是不是预期值 |
| 有 banner 但 HDMI 全黑 | 直接看 `[RESULT] p2f_rst_n[3:0]` 是不是 `F` —— 这一行就是判据 |
| 图像闪一下后全黑 | `main()` 是否退出了（保活循环还在不在）→ 复位被 C 运行时重新拉低 |
| `[RESULT] != F` | `Fclk_Init()` 没跑完，或 `0xF8806330` 被别处改写 |
| 程序跑一会儿卡死 | **没有 WDT 兜底**（见第九节），得靠外部手段复位 |
| DDR 不稳定 / 容量不对 | `DDRC_TRAINING_EN`、`DDR_DQ_WIDTH=32`、`DDRC_COMP_DENSITY=4096` 是否与实际颗粒一致；以串口 `[DDR INFO]` 打印为准 |
| 改了硬件配置但 PS 行为没变 | 忘了重新导出 HPF 并重编（`soc_plat.h` 与 7 张表都是**生成物**） |
| 想用 PS 读 PL 内部寄存器 | **做不到**：GP0/GP1 未使能（见第 9 级）；`pl_gpio` 也指望不上（三线全断）——**只能让 PL 写进 DDR，再由 PS 去读** |

---

## 十一、参数一览（含推导）

| 常量 | 值 | 推导 / 出处 |
|---|---|---|
| 晶振 | 33.33 MHz | `OSC_CLK 33.33`、`SYSTEM_CLOCK 33333333`、`-DAL_OSC_33` |
| PLL 基准 | **1999.8 MHz** | 33.33 × 120 ÷ 2 = 1999.8 |
| `CPU_CLOCK` | **999.9 MHz** | 1999.8 ÷ 2 = 999.9（宏值 `999900000` 完全吻合） |
| `IO_1000_FREQ` | 999.9 MHz | 1999.8 ÷ `IO1000_OUT_DIV(2)` |
| `IO_400_FREQ` | 399.96 MHz | 1999.8 ÷ 5 |
| `IO_80_FREQ` | 79.992 MHz | 1999.8 ÷ 25 |
| `IO_25_FREQ` | 24.9975 MHz | 1999.8 ÷ 80 |
| `P2F_CLOCK_0` | **199.98 MHz** | 1999.8 ÷ 10；与 `Design.xml` 的 `199.98` 一致 |
| `MMC_CLOCK` | 399.96 MHz | = `IO_400_FREQ` |
| `MMC0/1_IO_FREQ` | 49.995 MHz | 399.96 ÷ 8 |
| `UART_CLOCK` | 49.995 MHz | 1999.8 ÷ 40 |
| `QSPI_CLOCK` | 19.998 MHz | 1999.8 ÷ 100；`QSPI_IO_FREQ = QSPI_CLOCK ÷ 2 = 9.999 MHz` |
| `WDT_CLOCK` | 16.665 MHz | 1999.8 ÷ 120 |
| `SPI_CLOCK` / `TC_CLOCK` | 200 MHz | 宏直接给出 |
| `ADC_CLOCK` / `I2C_CLOCK` / `GPIO_CLOCK` / `GBE_CLOCK` | 50 / 100 / 12.5 / 500 MHz | 宏直接给出 |
| FSBL 运行区 | `0x61000000`，**252 KB** | `0x3F000` = 258,048 B；官方文档写 256 KB（`0x61000000~0x6103FFFF`），链接脚本留了 0x3F000 |
| 应用链接窗 | `0x08000000`，**16 MB** | `0x1000000` = 16,777,216 B |
| DDR 保留区 | `0x0~0xFFFFF`，**1 MB** | readme：BootROM 不可访问 |
| 应用栈 / FSBL 栈 | **6 MB** / **8 KB** | 两个链接脚本各自的 `__stack_size` 默认值 |
| 打印环形缓冲 | 1 MB | `__async_print_ring_buf_size` |
| `HashBuffer` | 32 B | SHA-256 摘要长度 |
| DDR 类型 / 速率 / 位宽 | DDR3 / **1333** / **DQ 32 bit** / IO 1.35 V | `DDRC_DDR_TYPE=DDR3`、`DDRC_DDR_SPEED=1333`、`DDRC_DQ_WIDTH=32`、`DDRC_IO_VOL=1.35` |
| DDR 颗粒配置 | 密度 **4096**、位宽 **x16** | `DDRC_COMP_DENSITY=4096`、`DDRC_COMP_TYPE=DDR_COMP_WIDTH_x16` → 按 `DQ_WIDTH ÷ 16 = 2 片` 推得 **8 Gb / 1 GB**（**以串口 `[DDR INFO]` 打印的实际容量为准**） |
| DDR 地址映射 / ECC / 训练 | `ROW_COL_BANK` / **NONE** / **开启(1)** | `DDRC_ADDR_MAP`、`DDRC_ECC_EN`、`DDRC_TRAINING_EN=1` |
| 配置轮询上限 | **100000** 次 | `CONFIG_POLL_TIME` → 超时返回 `PLAT_INIT_TIMEOUT` |
| Boot Mode 取值 | JTAG 0x0 · QSPI24 0x1 · EMMC 0x2 · QSPI32 0x3 · NAND 0x4 · **SD 0x5** · EMMC Raw 0x6 · EMMC1 0x7 | `soc_plat.h`；读地址 `0xF8800200` |
| 串口 | UART1 = `0xF8401000`，**115200** | `al_hwcfg.h`、`UART1_BAUDRATE` |
| HP0 位宽 | **64 bit** | `Slave_AXI_HP0_DATA_WIDTH=64`；`wmode_hp0=0` |
| Bank 电压 | Bank200 **3.3 V**、Bank201 **1.8 V**（强制） | `soc_plat.h` + `system_data_0` 表 |
| CPU / 架构 / EL | Cortex-A35 · armv8-a · **EL3**（FSBL） | `tools/make/dr1m90.inc`、`fsbl/Makefile` |

---

## 十二、总结

1. **通路**：三段接力——BootROM 把 FSBL 送进 OCM（`0x61000000`），FSBL 四阶段配好板子并加载 PL 码流，最后 Handoff 跳到 DDR（`0x08000000`）上的应用。
2. **分层**：应用 → 平台板级（`libplat.a`）→ BSP（`libalbsp.a`）→ 第三方/预编译（FATFS、semihost、`libddr.a`），最终链成 `fdma_en.elf`。
3. **时钟**：全部从 33.33 MHz 晶振经 PLL 得到 1999.8 MHz 基准再分频；CPU 999.9 MHz，送 PL 的 `p2f_clk0` = 199.98 MHz。
4. **关键约束**：DDR 前 1 MB 不可用（所以应用从 `0x08000000` 起）；GP0/GP1 与全部中断均未使能（PS 对 PL 实际只有 `p2f_rst0_n` 一根线可用，`pl_gpio` 三线全断）；看门狗实际未启用。
5. **配置**：所有硬件参数来自 HPF 自动生成的 `soc_plat.h` 与 7 张操作码表，改硬件只需重新导出，PS 代码不动。

---

## 附：所在地图与相关文档

| 类型 | 路径 |
|---|---|
| 平台工程（BSP） | `soc_sdk/soc_base/`（`system.mss`、`platform/`、`dr1m90_fpsoc_cpu0/`） |
| 第一阶段引导 | `soc_sdk/fsbl/`（`alfsbl_main.c` / `alfsbl_boot.c` / `alfsbl_readme.md`） |
| 应用 | `soc_sdk/fdma_en/`（`main.c`、`ui_io.h`、`lds/`） |
| 硬件平台描述 | `soc_sdk/soc_base/platform/{Design.xml, board_cfg.mk, soc_plat.tcl, soc_prj.bit}` |
| 硬件工程文件 | `../soc_hw/soc_prj.hpf`、`../soc_prj/`（**PL 侧，本文范围外**） |
| 同级存档 | `../../GetStabilityPS(base-fdma_en)/`（"稳定的平台存档"所在） |
