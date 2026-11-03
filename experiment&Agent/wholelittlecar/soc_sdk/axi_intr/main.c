/*
 * ============================================================================
 *  main.c - PS 侧控制层 bring-up（分区验证 + V8 蓝牙/超声闭环）
 * ============================================================================
 *
 *  【这个文件现在是什么】
 *    最开始它只是"AXI PWM 呼吸灯验证"（V1，2026-10-29）。现在长成了一个
 *    **带六个互斥分区的上板验证台**：一段所有分区共用的前置自检，
 *    后面接六段互斥的实验代码，改几个宏就能来回切，
 *    不用回滚文件、不用改位流以外的任何东西。
 *
 *    分区宏在下面 :262 附近（V3_TEST / V5_TEST / V7_TEST / BT_TEST /
 *    V8_TEST，五个全 0 时落到 V4）。**当前置 1 的是 BT_TEST**（蓝牙回环）。
 *    切换分区只改这几个宏，**不用改位流**（六段都在同一份 V8 位流上跑）。
 *
 *    责任划分（这条一直没变，是理解整个工程的关键）：
 *      - 占空比的"数值"    由 PS 决定（C 代码里写一个 32 位寄存器）
 *      - 波形的"时序/边沿"  由 PL 决定（硬件计数器按 20 ns 一拍数出来）
 *    PS 并不直接翻转引脚 —— 那样根本做不到 5 kHz（软件延迟是毫秒级抖动）。
 *    V8 新增的 15 cm 门控同样守这条：**判断和执行都在 PL**，
 *    PS 只负责把状态读出来打印。所以就算 PS 卡在 printf 上，
 *    车到 15 cm 一样会停。
 *
 *  【硬件链路】
 *    PS 的 M_AXI_GP0
 *      -> AXI_Matrix 的 DS_AXI2          按基址把这次访问路由给第 3 个从端
 *      -> AXI_Protocol_Converter_2       AXI4 降级成 AXI4-Lite（类比 AHB->APB）
 *      -> axi_lite_pwm_0 的 S_AXI        只解码低 8 位地址
 *    基址 0x80200000、窗口 4 KB，由 Design Integrator 的 Address Editor 分配。
 *    另外两个从端：AXI_GPIO_1（4 位方向）= 0x80100000，AXI_test = 0x80300000。
 *
 *    时钟/复位不用自己接，DI 生成时已自动连到：
 *      s_axi_aclk    = p2f_clk0     （PS 送出的 PL 时钟）
 *      s_axi_aresetn = p2f_rst0_n   （低有效）
 *
 *    ★ p2f_clk0 实测 = **50.0 MHz**（V1-c 五档占空比标定，T = 200 µs）。
 *      早期注释里的 49.995 MHz 是 soc_plat.h 里的"名义值"（其实就是 400/8），
 *      两者差 0.01%；算 PWM 频率用哪个都不影响判读，但写死 50.0 更好对表。
 *      ⇒ 一句"soc_plat.h 说 49.995"、"示波器说 50.0"并不矛盾，是同一件事。
 *
 *  【寄存器速查】（偏移相对 0x80200000，全部 32 位访问）
 *    0x00 CTRL      bit0..2 = 通道 0/1/2 使能
 *                   bit3    = 电机使能（★ V8 起会**门控** pwm_out[0]/[1]）
 *    0x04 DIR       bit0..1 = 电机方向（V8 起不再驱动电机，方向改走 AXI_GPIO_1）
 *    0x08 STATUS    bit2..0 = 待提交标志；bit5..3 = 通道使能；bit6 = 电机使能
 *    0x0C VERSION   只读，固定 0x00010000
 *    0x10/14/18     CH0 的 PSC / ARR / CCR
 *    0x20/24/28     CH1 的 PSC / ARR / CCR
 *    0x30/34/38     CH2 的 PSC / ARR / CCR
 *    0x40 UPDATE    写 1 到 bit[n] = 提交通道 n 的新参数
 *
 *    ---- 以下四组是 V8 新增，旧位流里这些地址没译码（读全 0、写被丢）----
 *    0x50 SONAR_TICKS  HC-SR04 回波宽度，单位 50 MHz 拍（1 cm 往返 ≈ 2900 拍）
 *    0x54 SONAR_CFG    bit16 软触发 / bit17 使能 / bit18 清门控锁存（均自清）
 *                       ★ 注意：自救位在 SONAR_CFG[18]，**不是** GUARD_CFG[16]
 *                         （后者是 exit_ticks 的 bit0，动它等于改阈值）
 *    0x58 GUARD_CFG    {exit[31:16], enter[15:0]}，复位 0xC094A9EC
 *                       enter = 43500 拍 = 15 cm；exit = 49300 拍 = 17 cm
 *                       进 15 cm 锁、出 17 cm 才放 —— 中间地带保持原状态（迟滞）
 *    0x5C GUARD_ST     门控状态位 + 自检位（bit3 = 门控"曾在前进中命中过"）
 *    0x60 BT_RX        读一次 = 取走一个字节，并清 fresh（★ 读有副作用）
 *    0x64 BT_TX        写一个字节 = 启动一次发送（LSB first，8N1）
 *    0x68 BT_CFG       bit0..15 = 分频（115200 -> 434），bit16 = 使能，bit17 = 忙（只读）
 *    0x6C GUARD_CNT    门控累计命中次数（排查"到底拦过没有"用）
 *
 *    三个 PWM 通道的设置是"影子寄存器 + 周期边界切换"：
 *      写 PSC/ARR/CCR 只是改影子值，真正生效要等下一个周期回绕点。
 *      这样改占空比就不会把当前那个脉冲截断，输出不会出现窄毛刺。
 *
 *  【★ CTRL[3] 的语义在 V8 转了向 —— 全文件最容易记错的一条】
 *    V3 时期：assign motor_enable = ctrl_reg[3];
 *             它和 pwm 表达式完全无关，所以"STBY 不门控 PWM"当时是对的
 *             （V3 实测过，round0/round1 都能在 PIN 9 上量到方波）。
 *    V8 起  ：pwm_out[0] = ch_pwm[0] && ctrl_reg[3] && !guard_hit
 *             pwm_out[1] = ch_pwm[1] && ctrl_reg[3] && !guard_hit
 *             pwm_out[2] = ch_pwm[2]                      （CH2 舵机，不门控）
 *      ⇒ CTRL[3] 现在同时管三件事：STBY、两路电机 PWM、LED4 的亮灭。
 *      ⇒ 因此 V3 区那条"STBY=0 时 PIN 9 还有波"的判据**已经失效**：
 *        在 V8 位流上重跑 V3 会看到"STBY=0 波形消失"，那是设计如此，
 *        不是"STBY 被误接进门控"。要看这段历史结论，得回 V3 那份位流。
 *    详见 axi_lite_pwm.v 头部"CTRL[3] 语义反转"那一节。
 *
 *  【为什么分三步，而不是一把梭】
 *    AXI 通路一旦有问题，"灯不亮"这一个现象对应好几种病因，没有信息量。
 *    拆成三步，每步只验证一件事，失败点立刻收敛：
 *      步骤 1  只读 VERSION     -> 证明"读"通（地址窗口、从端响应、总线连线）
 *      步骤 2  写一个值再读回   -> 证明"写"通（AW/W 握手、wstrb、影子寄存器）
 *      步骤 3  配参数并使能     -> 证明"波形"出得来（计数器、引脚）
 *
 *  【当前为什么直接是 step 3】
 *    步骤 1 的 VERSION 检查写在 #if 外面，任何 step 都会执行；
 *    步骤 2 自检失败会就地停住（StatFailLoop），不会带着坏通路继续往下跑。
 *    所以 step=3 等价于"1、2、3 串起来"，一次烧写就拿到全部诊断信息，
 *    不用为了看下一步重新编译、重新下载。
 *
 *  ⚠️ 【步骤 3 会"半通电"，六个分区都躲不掉】
 *    步骤 3 末尾有三件事：PWM_Init() 使能 CH0/CH1、PWM_SetMotor(0,1)
 *    把 CTRL[3] 写 1、然后进分区。结果是**每个分区开头 STBY 都是高的、
 *    LED4 都是亮的、TB6612 已经使能**。
 *
 *    此时 CCR = 0（PWM_Init 把三路占空比都配成 0）、DIR = 0（滑行），
 *    所以 pwm_out 恒低、轮子不转 —— 安全，但**不是断电**。
 *    要"绝对不动电机"的分区（BT_TEST 就是）必须自己再写一次
 *    PWM_SetMotor(0, 0)，把 STBY 拉低。别指望公共段替你做这件事。
 *
 *  【三条互不依赖的反馈通道】（最早三条，V8 又加了蓝牙回环这一条）
 *    本机串口一直不稳，所以特意做了几条互相独立的观察点，
 *    任何一条单独有效就能定位问题：
 *
 *      通道          引脚/地址              通路段             回答什么
 *      ------------  ---------------------  -----------------  ------------------
 *      LED5          MIO51（PS GPIO）       纯 PS，不走 AXI    程序跑起来了吗
 *      LED4          M20（motor_enable）    AXI 写 -> CTRL[3]  AXI 的"写"生效了吗
 *      pwm_out[0]    J12 PIN 9（V6）        PL 计数器          频率/占空比对吗
 *      串口          0xF8401000 / 115200     UART1              想看文字细节时用
 *      蓝牙回环      T9 出 / T5 入（软 UART）PL 软 UART + AXI   输入链路整条通不通
 *
 *    ⚠ 2026-10-31 改约束：pwm_out[0] 已从 LED1(T19) 挪到 J12 PIN 9(V6)，
 *      pwm_out[1] 从 R19 挪到 J12 PIN 11(U7)。板载 LED1/LED2 不再随 PWM 变化，
 *      波形判读只能靠示波器（地夹接 J12 PIN 2 = GND，量程 3.3 V 档）。
 *
 *    现象对照表（LED5 / LED4 / pwm_out[0] 波形）：
 *      慢闪不止 / 灭 / 无波   -> VERSION 或写回读失败，AXI 通路有问题
 *      常亮     / 灭 / 无波   -> 寄存器读写 OK，但 CTRL 写没落到引脚上
 *      常亮     / 常亮 / 无波 -> CTRL 生效了，但 PWM 通道不出波
 *      常亮     / 常亮 / 有波 -> 全通
 *      完全不动 / 灭 / 无波   -> 程序根本没执行到 main（或位流没下）
 *    ⚠ V8 起 LED4 = ctrl_reg[3] && !guard_hit，所以"前进中撞到 15 cm 时
 *      LED4 灭、车轮停"是正常门控，不是 AXI 掉了 —— 别按上面这张表误判。
 *      另外 BT_TEST 会主动把 STBY 拉低，LED4 就是灭的，也不能按表判。
 *
 *  【平台与工程】
 *    芯片   DR1M90GEG400（安路 DR1，PS = ARM Cortex 核 + PL = 逻辑）
 *    工具   Tang Dynasty 6.2.2（PL） + FD（PS 侧 C）
 *    工程   D:\FPGAproject\AnLuRun\PSPWM
 *    位流   soc_prj\soc_prj_Runs\best_result\soc_prj.bit
 *    注意   本程序 DOWNLOAD = ddr，下载配置里的加载地址要与 Makefile 一致
 *    ⚠️ 铁律：改 system.v / RTL 之后，TD 里可以综合，但**绝不能**在 DI 里
 *       点 Generate —— 那会把手改过的 system.v 无声覆盖掉，且不报错。
 *       判据是综合后看 IO Report 里的 Instance 树仍是 top -> I_system ->
 *       system_axi_* 且端口数对得上。
 *
 *  【修改记录】
 *    2026-10-29  首版：三步验证骨架（step 1/2/3）
 *    2026-10-29  加 LED5 状态灯、自检失败停机、寄存器回读打印
 *    2026-10-29  补全注释
 *    2026-10-31  V1-c 五档占空比标定；引脚从 LED1 挪到 J12 PIN 9/11
 *    2026-11-01  V2 相位机 / V3 引脚对位 / V4 单电机 / V5 双轮差速 / V7 命令链
 *                （V3–V5、V7 均上板通过，逐段结论见 分区验证\ 目录）
 *    2026-11-02  V6 重分配引脚；V8 加 PL 软 UART 蓝牙 + HC-SR04 + 15 cm 硬门控
 *                新增 BT_TEST 回环分区：先把输入链路单独打通，再上闭环
 *                新增 TIM_SONAR.c / TIM_BT.c 两个驱动
 * ============================================================================
 */

/* ---------------------------------------------------------------------------
 * 头文件
 *   说明 who 提供什么，避免以后翻半天找不到函数在哪。
 * ------------------------------------------------------------------------- */
#include <stdio.h>          /* printf：重定向到 UART1，见 al_log.c 的 AlLog_Write */
#include "al_core.h"        /* 芯片级初始化、AlSys_MDelay 等通用接口 */
#include "al_systimer.h"    /* AlSys_GetTimerTickCount / GetTimerFreq：V8 主循环计时 */
#include "ui_io.h"          /* UI_In32 / UI_Out32：volatile 裸指针读写，用于 MMIO */
#include "ui_type.h"        /* u32 / u8 等类型别名 */
#include "al_gpio_hal.h"    /* AlGpio_Hal_*：PS 侧 GPIO，用来驱动板载 LED5 */
#include "TIM_PWM.h"        /* 本工程自己写的 PWM 寄存器封装（偏移宏 + API） */
#include "TIM_GPIO.h"       /* AXI_GPIO_1（4 位）驱动：TB6612 方向控制 */
#include "uart_cmd.h"       /* V7：串口命令帧解析与执行 */
#include "TIM_SONAR.h"      /* V8：HC-SR04 超声 + 15 cm 门控（PL 侧硬门控的观察窗口） */
#include "TIM_BT.h"         /* V8：PL 软 UART 上的蓝牙模块 */
#include "AXI_test.h"       /* AXI4-Lite 通路验证从端（PL 侧 AXI_test） */

/* ---------------------------------------------------------------------------
 * 验证步进
 *
 *   1 = 只读 VERSION，一个字节都不写（最安全的探针）
 *   2 = 加上"写 CCR 再读回"的自检
 *   3 = 加上 PSC/ARR/CCR 配置、通道使能，然后进六选一的分区
 *       （3 这一段里**没有**"呼吸灯"了：PWM_Breath 函数还在 TIM_PWM.c，
 *         但已经不在主流程上；分区代码才是主角）
 *
 *   调到 3 不是跳步：1 的检查在 #if 之外无条件执行，2 失败会停机，
 *   所以 3 天然包含 1 和 2。
 * ------------------------------------------------------------------------- */
#define BRINGUP_STEP        3


/* ============================================================================
 *  AXI_test 通路验证开关（2026-10-30 追加）
 *
 *  ✅ 四个前提已于 2026-10-30 20:58 全部完成并逐项复核：
 *    1) AXI_test.v 打包成 IP：ip_repo/AXI_test_1.0/Component.xml
 *       45,763 B，3 条 busInterface（S_AXI / S_AXI_ACLK / S_AXI_ARESetn）
 *    2) DI 里实例化 + 连线：Converter_3.aclk/aresetn 与 AXI_test_0 的
 *       s_axi_aclk/s_axi_aresetn 全部接在同一根 p2f_clk0 / p2f_rst0_n 上
 *    3) 地址：AXI_test_0 = 0x80300000~0x80300FFF（与 AXI_TEST_BASE 一致）
 *    4) ★ 矩阵解码表：DS3_BASEADDR0 = 0x80300000（与 Address Editor 一致）
 *       —— 这一项最容易漏：Address Editor 的分配**不会**回写矩阵参数。
 *          漏了的表现是 PS 读 0x80300000 时矩阵四段都不命中 ⇒ 挂死。
 *          复核命令：python tools/check_axi_map.py（退出码 0 才算通过）
 *
 *  ⚠️ 为什么曾经默认关着（保留这段是为了记住判据）：
 *     从端没接好时，PS 读 0x80300000 是一次"无人应答"的 AXI 访问。
 *     这种访问可能返回 DECERR 变成 data abort，也可能被总线直接挂住，
 *     表现是**开机就卡死、连后面的 printf 都不出** —— 看起来像板子坏了。
 *
 *  开机会多打一段：
 *     ===== AXI_test bring-up =====
 *     [1] ID  = 0x41584954 (expect 0x41584954) OK
 *     [2] SCR0/SCR1 ... byte-strobe ...
 *     [3] LIVE_LO: 值 -> 另一个值  OK (PL clock is running)
 *     [4] CLR/START/DONE/COUNT ...
 *     ===== AXI_test PASSED (0 failure) =====
 *
 *  失败不影响后续 PWM 测试继续跑 —— 这里只报错不 return，
 *  因为两个测试的失败原因可能不同，多留一份证据总是好的。
 * ========================================================================== */
#define AXI_TEST_BRINGUP    1


/* ============================================================================
 *  时钟实测开关（2026-10-29 22:30 追加）
 *
 *   背景：UART 实测发现实际时钟只有 soc_plat.h 假设值的 1/3.87
 *         （divisor 用 7 才对，软件算出的是 27）。
 *         p2f_clk0 与 UART 时钟同源（都来自 IO_400），所以必须确认
 *         p2f_clk0 是否也偏了 —— 这直接决定 PWM 的实际频率，
 *         也决定以后所有 PL 时序参数按哪个时钟算。
 *
 *   1 = 时钟实测模式：跳过后续分区，把 CH0 降成 1 Hz、50% 占空比方波，
 *       然后死等。**用示波器**量 pwm_out[0]（J12 PIN 9）的周期：
 *         约 1.0 秒  -> p2f_clk0 ≈ 50 MHz，名义频率表可信
 *         约 3.9 秒  -> p2f_clk0 ≈ 12.9 MHz，所有 PL 参数要按 1/3.87 重算
 *       （当初怀疑的是 soc_plat.h 的时钟假设，实测否掉了这个怀疑。
 *         那时 pwm_out[0] 还在 LED1 上，所以最早是用秒表看灯闪的。）
 *
 *   ✅ 2026-10-29 22:36 实测结果 = 约 1.0 秒（名义 0.9999 Hz）。
 *      => p2f_clk0 正常，PWM 的 4.9995 kHz 属实。
 *      => UART 那个 3.87 倍偏差只出现在 UART 时钟分支，与 PL 无关。
 *      测试已完成，开关改回 0。
 *
 *   ⚠ 2026-10-31：pwm_out[0] 已挪到 J12 PIN 9，LED1 不再跟着变。
 *      再跑本模式要用示波器量，不能靠看灯。后来改用五档占空比扫描标定，
 *      实测 T = 200 µs -> f_clk = 50.0 MHz（见下面 V1-c 段）。
 *
 *   0 = 不进时钟实测模式（当前）：直接往下走步骤 3 和后面的分区
 *
 *   注意：串口已经修好（divisor=7 已写死，见 uart_probe.c），
 *         所以这个模式下 printf 也可信，两路证据可以互相对照。
 * ========================================================================== */
#define CLK_TEST_1HZ        0

/* ---------------------------------------------------------------------------
 * 分区验证：测试段六选一（互斥，按下面的先后取第一个置 1 的）
 *   V3_TEST 1  V3 引脚对位（AXI_GPIO_1 四位落点 + STBY 解耦）  ✅ 2026-11-01 通过
 *   V5_TEST 1  V5 双轮差速（标定 B 侧 + 直行 + 差速 + 原地转）  ✅ 2026-11-02 通过（拆线后复验）
 *   V7_TEST 1  V7 串口命令链（帧解析 + 命令执行 + 看门狗）      ✅ 2026-11-01 通过
 *   BT_TEST 1  BT 蓝牙串口回环（手机发什么就回什么）            ✅ 2026-11-02 通过
 *   V8_TEST 1  V8 控制层最小闭环（蓝牙单字节 + 15cm 硬门控）    ← 当前
 *   全 0        V4 单电机开环（第一次让电机动起来）             ✅ 2026-11-01 通过
 *
 * 六段代码都保留在文件里，改这几个宏就能来回切，不用回滚文件。
 * ⚠️ 多个同时置 1 时按 #if 链的先后取前面的，不是报错 —— 别这么用。
 * ⚠️ BT_TEST 与 V8_TEST 都要 V8 位流（0x50~0x6C 已译码）。
 *    两者都会跑完公共的步骤 1/2/3；区别是 BT_TEST 一进来就把 CTRL[3]
 *    清 0（STBY 低、两路电机 PWM 被门控），所以回环期间车轮绝对不会转。
 *    V8_TEST 相反：它要靠 PWM 让车走，CTRL[3] 保持高。
 * ------------------------------------------------------------------------- */
#define V3_TEST             0
#define V5_TEST             0
#define V7_TEST             0
#define BT_TEST             0
#define V8_TEST             1

/* V5 循环轮数：0 = 一直循环（默认，方便连续观察六种动作）；
 * 想跑固定轮数就改成 2 / 3，跑完自动停在刹停态。
 * 每一轮结尾都有 BRAKE 3 s，所以无限循环也不会一直转着不放。 */
#define V5_ROUNDS           0U

/* BT 分区专用：如果蓝牙模块还是出厂 9600（HC-05/06 常见），把这里改 1，
 * 回环就用 9600 跑。**不用改 RTL、不用重综合** —— Bt_SetBaud() 是运行时写 0x68。
 * 判据没变：能收到同样的字节就说明链路通，只是速率不同。 */
#define BT_TEST_BAUD_9600   0


/* ============================================================================
 *  状态灯：板载 LED5 = MIO51，走 PS GPIO（写 1 = 亮）
 * ============================================================================
 *
 *  【为什么要单独搞这一路】
 *    串口在本机一直不稳，而 AXI 和 PWM 的所有判断都依赖"能看到结果"。
 *    LED5 不经过 AXI、不经过 PL、不经过串口，只依赖 PS 自己的 GPIO 控制器，
 *    是板子上最不容易出岔子的"程序还活着"信号。
 *
 *    换句话说：如果连这三下短闪都没有，那后面所有的灯躺着不动都是理所当然的，
 *    问题根本不在 PWM，而在"程序有没有跑起来 / 位流有没有下"。
 *
 *  【引脚号 51 是怎么来的（不是猜的）】
 *    PS 侧引脚的全局编号是线性排的：MIO0..MIO53 之后接着 PL 侧的 GPIO 54..117。
 *    本工程的 soc_base/platform/src/soc_plat.c 里 psio_data_0[] 有这几行注释：
 *        // Config GPIO, PS IO 50->FUNCSEL: GPIO
 *        // Config GPIO, PS IO 51->FUNCSEL: GPIO
 *    也就是说本工程被配置成 GPIO 功能的 MIO 一共 7 个：
 *        MIO 0 / 7 / 8 / 9 / 46 / 50 / 51
 *    其中 MIO50 = 板上 KEY3（按下读 0，松开读 1），MIO51 = 板上 LED5。
 *    注意这个集合是"逐工程"的，换工程要重新核对，不能照抄。
 *
 *  【极性】
 *    板上 LED5 由 N-MOS 低边驱动，栅极接 MIO51，所以写 1 = 点亮。
 *    如果实测发现正好相反（上电就常亮、写 1 反而灭），
 *    把 StatLed() 里的 1U/0U 对调即可，逻辑不用动。
 *
 *  【编码规则】用肉眼就能分辨，不需要数拍子
 *    上电               : 短闪 3 次（亮 120 ms / 灭 120 ms） = 程序在跑
 *    VERSION + 写回读全过 : 常亮（不再闪）                    = 通路 OK
 *    任何一步失败        : 慢闪不止（亮 250 ms / 灭 250 ms）  = 有故障
 *
 *    "常亮"和"慢闪"必须一眼能分开 —— 这是刻意设计的，
 *    因为最容易误判的就是"好像亮着"其实程序早就停了。
 *
 *  【想整体关掉这一路】
 *    把 STAT_LED_OK 改成 0。函数体会被 #if 掏空，-O2 下会被优化掉不占空间，
 *    不用删代码，也不影响后面的验证流程。
 * ========================================================================== */
#define STAT_LED_PIN        51U     /* MIO51 = 板上 LED5 */
#define STAT_LED_OK         1       /* 1 = 启用状态灯，0 = 整体关闭 */

/* GPIO 驱动句柄。
 * 由 AlGpio_Hal_Init 填充，之后所有读写都要带着它。
 * 初值给 AL_NULL（即 (void*)0），是为了让"初始化失败"这种情况
 * 在 StatLed() 里能用一个 != AL_NULL 的判断挡掉，避免野指针。 */
static AL_GPIO_HalStruct *g_stat_led = AL_NULL;

/* ---------------------------------------------------------------------------
 * 初始化 GPIO 驱动，并先把灯关掉
 *
 *   AlGpio_Hal_Init(&handle, DevId, CallBack)
 *     DevId     = 0        GPIO 控制器在驱动配置表里的编号
 *                          （AlGpio_HwConfig[0].DeviceId 就是 0，
 *                            而且整张表只有这一条，管全部 118 个引脚）
 *     CallBack  = AL_NULL  不用中断，所以不注册回调
 *
 *   注意：拿不到句柄也不能中断后续验证。
 *         状态灯只是辅助手段，不该成为新的故障点 ——
 *         万一 GPIO 初始化失败，我们仍然希望把 AXI 那部分测完。
 * ------------------------------------------------------------------------- */
static void StatLed_Init(void)
{
#if STAT_LED_OK
    if (AlGpio_Hal_Init(&g_stat_led, 0U, AL_NULL) != AL_OK) {
        g_stat_led = AL_NULL;       /* 失败就置空，后面所有 StatLed() 自动变成空操作 */
        return;
    }
    AlGpio_Hal_WritePin(g_stat_led, STAT_LED_PIN, 0U);   /* 上电先确保是灭的 */
#endif
}

/* ---------------------------------------------------------------------------
 * 点灯 / 灭灯
 *
 *   on = 1 点亮，on = 0 熄灭。
 *
 *   【为什么用 WritePin 而不是 WriteBank】
 *     AlGpio_Hal_WritePin 只把"自己那一位"设成输出方向，同 Bank 的其它引脚
 *     一个都不碰；
 *     而 AlGpio_Hal_WriteBank / DiscreteSet / DiscreteClear 会把整个 Bank 的
 *     32 个引脚**全部设成输出**。
 *     MIO50（KEY3 按键）就在同一个 Bank 里，用 WriteBank 会把按键废掉。
 *     这是个很容易踩、而且当时看不出来的坑，所以这里固定只用 WritePin。
 * ------------------------------------------------------------------------- */
static void StatLed(u32 on)
{
#if STAT_LED_OK
    if (g_stat_led != AL_NULL) {
        AlGpio_Hal_WritePin(g_stat_led, STAT_LED_PIN, on ? 1U : 0U);
    }
#else
    (void)on;                       /* 关掉功能时把这个参数"用掉"，免得编译器报警告 */
#endif
}

/* ---------------------------------------------------------------------------
 * 闪 times 次：每次亮 on_ms 毫秒、灭 off_ms 毫秒
 *
 *   AlSys_MDelay 的时基来自 ARM 通用定时器（cntpct_el0），
 *   在启动阶段 al_aarch64_start.S -> AlChip_Init -> AlSys_StartTimer 就已经打开，
 *   所以进 main 之后可以直接用，不需要再初始化。
 *
 *   参数用 AL_U64 传，是因为 AlSys_MDelay 的形参就是 64 位，
 *   直接传 u32 虽然能隐式转换，但显式写出来更清楚。
 * ------------------------------------------------------------------------- */
static void StatBlink(u32 times, u32 on_ms, u32 off_ms)
{
    while (times--) {                           /* 先判断再自减，times=3 就闪 3 次 */
        StatLed(1U);
        AlSys_MDelay((AL_U64)on_ms);
        StatLed(0U);
        AlSys_MDelay((AL_U64)off_ms);
    }
}

/* ---------------------------------------------------------------------------
 * 失败时的"停机 + 慢闪"
 *
 *   【为什么不用单纯的 for(;;) 空转】
 *     空转从外面看和"程序跑飞了"一模一样，没有任何信息量；
 *     而有节奏的慢闪至少能说明：CPU 还在跑、定时器还活着、GPIO 还能驱动。
 *     这就把"死机"和"检查没过"两种情况区分开了。
 *
 *   【为什么不快闪】
 *     快闪容易被看成一团模糊的亮，和"常亮"不好分辨；
 *     250 ms 的慢闪节奏清楚，一眼就能和"成功常亮"分开。
 * ------------------------------------------------------------------------- */
static void StatFailLoop(void)
{
    for (;;) {
        StatBlink(1U, 250U, 250U);
    }
}

/* ---------------------------------------------------------------------------
 * 两侧占空比的"同周期提交"已上移到驱动层：TIM_PWM.c 的 PWM_SetBoth()
 *
 *   原来这里是 V5 专用的 static V5_SetBoth()。V7 的命令链、V8 的 PID 输出
 *   都要用同一个出口，所以挪进驱动 —— 只留一份实现，避免三处各写一遍、
 *   哪天改了其中一处就出现"V5 直行是齐的、V7 直行起步歪一下"这种鬼现象。
 * ------------------------------------------------------------------------- */


/* ---------------------------------------------------------------------------
 * V8 蓝牙回话：每条命令都给手机回一行"干了什么"
 *
 *   ★ 为什么要回话
 *     手机是"盲发"的：它不知道 FPGA 收没收到、有没有到顶、现在是几档。
 *     每按一个键回一行，才能把"没收到"、"收到了但到了上限"、"执行成功"
 *     这三种情况分开 —— 否则全是"没反应"，排障只能靠猜。
 *
 *   ★ 为什么自己写十进制转换，不用 snprintf
 *     printf 家族已经链进来了，但只为发一个数字再拉 snprintf 不划算。
 *     这里只处理 0..99999，档位和占空比足够。
 *
 *   ⚠️ 每条回话控制在 ≤16 字节：Bt_SendByte 每字节固定等 1 ms，
 *      16 字节 = 16 ms。人手按一次至少几百毫秒，不会把下一条命令挤掉；
 *      但若手机端做"长按自动重复"，间隔必须 >20 ms，否则 PL 的单字节
 *      RX 缓冲会丢掉中间的字节（这是 RTL 的取舍，不是驱动的 bug）。
 *
 *   ⚠️ 整段包在 #if V8_TEST 里：不跑 V8 时这些 static 函数没人调用，
 *      编译会报 -Wunused-function。别把 #if 删了。
 * ------------------------------------------------------------------------- */
#if V8_TEST
static void V8_SendNum(u32 v)
{
    char t[6];
    u32  n = 0U;

    if (v == 0U) {
        Bt_SendByte((u8)'0');
        return;
    }
    while ((v != 0U) && (n < 5U)) {
        t[n] = (char)('0' + (v % 10U));
        v /= 10U;
        n++;
    }
    while (n > 0U) {
        n--;
        Bt_SendByte((u8)t[n]);
    }
}

/* 方向类命令的回话："FWD 30%" */
static void V8_AckDir(const char *name, u32 pct)
{
    Bt_SendStr(name);
    Bt_SendByte((u8)' ');
    V8_SendNum(pct);
    Bt_SendStr("%\r\n");
}

/* 档位类命令的回话："GEAR 4/17 35%" */
static void V8_AckGear(u32 gear, u32 total, u32 pct)
{
    Bt_SendStr("GEAR ");
    V8_SendNum(gear);
    Bt_SendByte((u8)'/');
    V8_SendNum(total);
    Bt_SendByte((u8)' ');
    V8_SendNum(pct);
    Bt_SendStr("%\r\n");
}

/* 直线微调的回话："TRIM +3%" / "TRIM -2%" / "TRIM 0%" */
static void V8_AckTrim(int t)
{
    Bt_SendStr("TRIM ");
    if (t < 0) {
        Bt_SendByte((u8)'-');
        V8_SendNum((u32)(-t));
    } else {
        if (t > 0) {
            Bt_SendByte((u8)'+');
        }
        V8_SendNum((u32)t);
    }
    Bt_SendStr("%\r\n");
}

/* 命令码 -> 回话用的短名。与 V7_CmdName 的区别：这里不补齐空格，
 * 因为要发到手机上，多一个空格就多 1 ms 且看起来不整齐。 */
static const char *V8_CmdName(u8 cmd)
{
    switch (cmd) {
    case V7_CMD_FWD:    return "FWD";
    case V7_CMD_BACK:   return "BACK";
    case V7_CMD_SPIN_L: return "SPIN_L";
    case V7_CMD_SPIN_R: return "SPIN_R";
    case V7_CMD_ARC_L:  return "ARC_L";
    case V7_CMD_ARC_R:  return "ARC_R";
    default:            return "?";
    }
}
#endif /* V8_TEST */


/* ============================================================================
 *  主函数
 * ========================================================================== */
int main(void)
{
    u32 ver;        /* 步骤 1：读回的 VERSION 值，应为 0x00010000 */
    u32 ret;        /* 步骤 2：自检返回码，0 = 正常，1/2 = 两种失败 */
    u32 status;     /* STATUS 寄存器的快照，用来观察使能位和待提交位 */

    /* ------------------------------------------------------------------
     * 开机自报平安
     *
     *   先闪三下，证明三件事同时成立：
     *     1) 程序真的执行到 main 了（不是卡在启动、也不是位流没下）
     *     2) GPIO 驱动初始化成功
     *     3) 系统定时器在走（否则 AlSys_MDelay 会卡死，连三下都闪不完）
     *
     *   这三件事都成立，后面的失败才有意义；否则先回去查下载。
     * ------------------------------------------------------------------ */
    StatLed_Init();
    StatBlink(3U, 120U, 120U);

    /* ------------------------------------------------------------------
     * AXI 通路验证（只有 AXI_TEST_BRINGUP 置 1 才编进来）
     *
     *   放在 PWM 测试之前：先验"地基"，再验"业务"。
     *   AXI 通路不通时 PWM 必然不通，先看这一段能省掉一整轮排查。
     *
     *   失败不 return，让它继续往下跑 —— 两个测试的失败原因可能不同，
     *   多留一份现象总是好的；灯语 5 次快闪用来在没接串口时也能分辨。
     * ------------------------------------------------------------------ */
#if AXI_TEST_BRINGUP
    if (AXI_Test_Bringup() != 0U) {
        printf("!! AXI_test FAILED -- PWM 测试大概率也会失败\r\n");
        printf("!! 依次查：DI 里 S_AXI 连没连 / 地址是否 0x80300000 / p2f_clk0 到没到 PL\r\n");
        StatBlink(5U, 60U, 60U);
    }
#endif

    /* 串口这两行是给人看的，不参与判断。
     * UART 由启动阶段的 components_init() -> AlLog_Init() 初始化（115200 8N1），
     * 排在 main 之前，所以这里可以直接 printf。 */
    printf("\r\n===== AXI PWM bring-up =====\r\n");
    printf("base = 0x%08X  step = %d\r\n", (unsigned)AXI_PWM_BASE, BRINGUP_STEP);

    /* ------------------------------------------------------------------
     * 步骤 1：只读 VERSION 寄存器（0x8020000C）
     *
     *   这是整条 AXI 通路唯一的"零副作用"探针：一个字节都不写。
     *   所以它能干净地回答"这根总线到底通不通"，不会被写入副作用干扰。
     *
     *   结果怎么判：
     *     读到 0x00010000            -> 地址窗口命中、从端有响应、连线正确
     *     读到 0x00000000            -> 从端可能没被选中，或返回了全 0
     *     读到 0xFFFFFFFF            -> 总线错误（DECERR）常见的表现
     *     干脆卡住不返回、串口没有第三行 -> 该地址没有任何从端应答，
     *                                      AXI 读会一直等下去（挂死）
     *
     *   补充：这句在目标码里就是一条 ldr 打在 0x8020000C 上（反汇编核对过），
     *   没有多余的地址运算。所以读不到只可能是硬件链路的问题，
     *   不可能是"地址算错了"。
     * ------------------------------------------------------------------ */
    ver = PWM_ReadVersion();
    printf("[1] VERSION = 0x%08X (expect 0x%08X) %s\r\n",
           (unsigned)ver, (unsigned)PWM_VERSION_EXPECT,
           (ver == PWM_VERSION_EXPECT) ? "OK" : "FAIL");

    if (ver != PWM_VERSION_EXPECT) {
        printf("AXI path NOT ready. check: DS_AXI2 base / bus wiring / p2f_clk0\r\n");

        /* 到这儿就不要往下写了。
         * 往一个没有从端应答的地址写，同样会挂死调试器，
         * 而且会把"读就不通"这个已经很明确的线索搅浑。 */
        StatFailLoop();
    }

#if BRINGUP_STEP >= 2
    /* ------------------------------------------------------------------
     * 步骤 2：写-读回自检 —— 验证"写"这一半
     *
     *   PWM_SelfTest() 内部做的动作：
     *     1) 再读一次 VERSION（防呆）
     *     2) 往 CH0 的 CCR 影子寄存器写 0x1234
     *     3) 立刻把它读回来比对
     *     4) 最后把 CCR 清回 0，不留痕迹
     *
     *   返回码含义：
     *     0 -> 写通了
     *     1 -> VERSION 不对（正常情况下走不到这里）
     *     2 -> 写进去的值读出来不一样：AW/W 握手、wstrb 字节使能
     *          或影子寄存器实现有问题
     *
     *   【为什么挑 CCR 当测试寄存器】
     *     - 它可读可写（VERSION 只读，UPDATE 写完就读不出原值）
     *     - 它不受 UPDATE 提交影响，写进去是什么就读到什么
     *     - 此刻通道还没使能，改它不会让 LED 闪一下，没有副作用
     * ------------------------------------------------------------------ */
    ret = PWM_SelfTest();
    printf("[2] self-test %s (code %d)\r\n", (ret == 0U) ? "OK" : "FAIL", (int)ret);

    /* STATUS 位序（和 PL 侧 axi_lite_pwm.v 的读多路选择器一一对应）：
     *   bit2..0 = update_pending  三路的"待提交"标志
     *   bit5..3 = ctrl[2:0]       三路的通道使能
     *   bit6    = ctrl[3]         电机驱动使能
     * 此刻还没使能任何通道，所以正常应该读到 0x00000000。 */
    status = PWM_ReadStatus();
    printf("    STATUS = 0x%08X  (pending=%d, en=%d, motor_en=%d)\r\n",
           (unsigned)status,
           (int)(status & 0x7U),                /* bit0..2：待提交 */
           (int)((status >> 3) & 0x7U),         /* bit3..5：通道使能 */
           (int)((status >> 6) & 0x1U));        /* bit6   ：电机使能 */

    /* 自检不过就地停机。
     * 否则会一路跑到步骤 3 的分区里，到时候轮子不转、波形也没有，
     * 就分不清到底是通路坏了还是分区逻辑坏了 —— 这两种病因的修法完全不同。 */
    if (ret != 0U) {
        printf("register write-back FAILED. check W channel / wstrb / shadow reg\r\n");
        StatFailLoop();
    }

    /* 走到这里说明"读"和"写"都通了。
     * LED5 转常亮，作为永久标记 —— 之后不管后面成不成，都留着这个证据。 */
    StatLed(1U);
#endif

#if BRINGUP_STEP >= 3
    /* ------------------------------------------------------------------
     * 步骤 3：配置参数、使能通道（然后交给下面的分区）
     *
     *   PWM_Init() 内部依次做四件事：
     *     1) CTRL 写 0，先关掉所有通道
     *        —— 避免配置过程中输出出现半截脉冲或毛刺
     *     2) 写三路的 PSC / ARR / CCR 影子值
     *          CH0、CH1：PSC=0、ARR=9999  -> 4.9995 kHz（电机用）
     *          CH2      ：PSC=0、ARR=3999599 -> 12.5 Hz（舵机预留）
     *     3) 写 UPDATE，把三路一起提交
     *        然后等 1 ms，让影子值在各自的周期回绕点切入
     *        （一个 5 kHz 周期只要 0.2 ms，等 1 ms 相当于等 5 个周期，足够）
     *     4) 最后只使能 CH0 / CH1，CH2 留着备用
     * ------------------------------------------------------------------ */
    PWM_Init();

    /* 使能之后 STATUS 的 bit5..3 应该从 0 变成 3（CH0+CH1 开），
     * 也就是整个寄存器读到 0x00000018。
     * 这一行是"使能到底有没有写进去"的直接证据。 */
    status = PWM_ReadStatus();
    printf("[3] after init STATUS = 0x%08X (en=%d)\r\n",
           (unsigned)status, (int)((status >> 3) & 0x7U));

    /* 频率验算，纯打印：
     *   f = 50.0 MHz / ((PSC+1) * (ARR+1))
     *     = 50,000,000 / (1 * 10,000)
     *     = 5,000 Hz
     * 时钟取 50.0 MHz 是 V1-c 实测值（T = 200 µs），不是 soc_plat.h 的
     * 名义 49.995 MHz —— 两者差 0.01%，但既然量过了就按量到的写。
     * 注意分母是 ARR+1 而不是 ARR —— 计数器从 0 数到 ARR，一共 ARR+1 个计数。
     * 写成 +1.0 是为了强制浮点运算，否则整数除法会把结果截断。 */
    printf("    PWM0: ARR=%d PSC=%d -> %.1f Hz\r\n",
           (int)PWM_DEFAULT_ARR, (int)PWM_DEFAULT_PSC,
           50000000.0 / ((PWM_DEFAULT_PSC + 1.0) * (PWM_DEFAULT_ARR + 1.0)));

    /* 再回读一遍实际寄存器值 —— 这是整个程序里最强的一条证据。
     *
     *   ARR 能读回 9999、CTRL 能读回 3，就说明"PS 写进去的值真的落到了
     *   影子寄存器"，也就是 AXI 写通路端到端打通了。
     *
     *   为什么这比"看灯亮不亮"更硬：
     *     灯还受引脚分配、极性、位流版本的影响，任何一个不对都不亮；
     *     而回读只反映"写通路"这一件事，变量少得多。
     *
     *   如果这里 ARR 读回 0，而步骤 2 的自检却过了，
     *   那问题范围就缩小到"PWM_Init 里那几笔写有没有生效"。 */
    printf("    readback CTRL=0x%08X ARR=%d PSC=%d CCR=%d\r\n",
           (unsigned)PWM_ReadReg(PWM_REG_CTRL),
           (int)PWM_ReadReg(PWM_REG_CH_ARR(PWM_CH0)),
           (int)PWM_ReadReg(PWM_REG_CH_PSC(PWM_CH0)),
           (int)PWM_ReadReg(PWM_REG_CH_CCR(PWM_CH0)));

    /* 点 LED4（M20），也就是把 CTRL[3] 写 1。
     *
     *   ★ V8 起 CTRL[3] 的语义变了（见文件头"CTRL[3] 语义反转"）：
     *       motor_enable = ctrl_reg[3] && !guard_hit      -> M20 / LED4
     *       pwm_out[0/1] = ch_pwm[x] && ctrl_reg[3] && !guard_hit
     *     也就是说它**现在会门控两路电机 PWM**，不再是纯观测脚。
     *
     *   但此刻它仍然是个干净的单点判据，因为这三件事同时成立：
     *     ① 超声还没初始化，guard_latched = 0 ⇒ guard_hit 恒 0
     *     ② DIR 刚被 PWM_SetMotor 写成 0（滑行），dir_is_fwd = 0
     *     ③ CCR 三路都是 0 ⇒ 就算门控放开也没有波
     *   所以：
     *     LED4 亮 = 这一笔 AXI 写确实生效了，没有别的解释。
     *
     *   如果 LED4 亮但 pwm_out[0] 上量不到波（且 CCR 给过非 0）
     *     -> 写没问题，是 PL 波形生成的问题。
     *   ⚠ 如果后面在前进中（DIR=0x5）撞到 15 cm，LED4 会灭 —— 那是门控，
     *     不是 AXI 掉了。这两件事现象一样、病因完全不同，别混。 */
    PWM_SetMotor(0U, 1U);

    /* 下面这一段是分区入口。六选一的分区代码就在 #else 里，
     * 当前是哪一个由 :267 附近那五个宏决定（现在是 BT_TEST）。 */
    printf("    -> entering test partition\r\n");

#if CLK_TEST_1HZ
    /* ------------------------------------------------------------------
     * 时钟实测模式：把 CH0 降到 1 Hz、50% 占空比，用示波器量周期
     *
     *   名义计算（p2f_clk0 = 50.0 MHz）：
     *     f = 50,000,000 / ((4999+1) × (9999+1))
     *       = 50,000,000 / 50,000,000
     *       = 1.000 Hz   ->  1 秒一个完整周期，亮 0.5 s、灭 0.5 s
     *     （按 49.995 MHz 算则是 0.9999 Hz，差 0.01%，秒表分不出来）
     *
     *   为什么用 50% 占空比而不是很小的值：
     *     占空比太低时只有一个窄脉冲，示波器的触发和读周期都不稳；
     *     50% 的上升沿/下降沿最干净，自动测量直接就出 T。
     *
     *   ⚠ 本模式当初是"看 LED1 闪"实现的，2026-10-31 起 pwm_out[0] 已经
     *     不在 LED1 上了（挪到 J12 PIN 9），所以**必须用示波器**，看灯无效。
     *
     *   写完之后必须 PWM_Commit，因为 PSC/ARR/CCR 是影子寄存器，
     *   要等下一个周期回绕点才整体切入（避免把当前脉冲截断）。
     *   这里多等 5 ms 保证一定完成切换。
     *
     *   CH0 在 PWM_Init() 里已经使能，这里不需要再动 CTRL。
     * ------------------------------------------------------------------ */
    PWM_SetTiming(PWM_CH0, 4999U, 9999U, 5000U);
    PWM_Commit(PWM_UPDATE_CH(PWM_CH0));
    AlSys_MDelay(5U);

    printf("    CLK TEST: PSC=4999 ARR=9999 CCR=5000\r\n");
    printf("    nominal 1.000 Hz / 50%% duty\r\n");
    printf("    scope pwm_out[0] on J12 PIN 9 (V6), probe T = 1 s\r\n");

    /* 死等，不再改动 PWM —— 保证量到的周期是稳定的 */
    for (;;) {
    }
#else
    /* ------------------------------------------------------------------
     * 五档占空比扫描的判据（V1-c 留下来的，现在仍然是"波形对不对"的标准）
     *
     *   ⚠ 这一段已经**不在主流程上**了：2026-11-01 起，这里换成了六选一的
     *     分区代码（V3/V5/V7/BT/V8/V4），扫频只用它的判据，不再自动跑。
     *     想再跑一次扫频，把下面整段 #if V3_TEST ... #endif 临时注掉，
     *     再把本注释里的五个 Vavg 值当判据手动给 CCR 即可。
     *
     *   为什么不能只量周期：
     *     周期对只证明 p2f_clk0 对；占空比对才证明
     *     "影子寄存器 -> UPDATE 提交 -> 比较器 -> 输出引脚" 整条路对。
     *
     *   为什么取 {0, 2500, 5000, 7500, 10000} 这五个值：
     *     axi_lite_pwm.v:302-304
     *       period_wrap = prescale_tick && (period_count >= active_arr)
     *       pwm         = enable && (period_count < active_ccr)
     *     period_count 走 0..ARR = 0..9999（周期 = ARR+1 = 10000 拍）
     *     => CCR = 0      ：0 < 0 恒假        = 真 0%
     *        CCR = 10000  ：0..9999 < 10000 恒真 = 真 100%
     *     所以两端不会出现"以为到底了结果差一档"的边界问题。
     *
     *   通道：PWM_CH0 = pwm_out[0] -> J12 PIN 9 (V6, BANK11 3V3)
     *         地夹接 J12 PIN 2 (GND)
     *
     *   示波器怎么读（这一步容易踩）：
     *     0% 和 100% 两档输出是直流，量不到周期，表上会显示"无信号"。
     *     所以五档统一读 Vavg，不要读 Period：
     *       0% -> 0.00 V / 25% -> 0.825 V / 50% -> 1.650 V
     *       75% -> 2.475 V / 100% -> 3.300 V   （判据：偏差 < 2%）
     *     中间三档可顺带看 Duty 读数应为 25.0 / 50.0 / 75.0 %。
     *
     *   若五档都不对但周期是对的，查这三处：
     *     1) 通道使能位有没有真的置上（看上面 STATUS 打印）
     *     2) PWM_Commit 有没有真的写 UPDATE（W1C，写 1 才提交）
     *     3) 位流是不是最新那份（旧位流里没有这个 PWM IP）
     *
     *   想单独看呼吸效果（纯演示，不影响任何验证）：
     *     PWM_Breath(PWM_CH0, PWM_DEFAULT_ARR, PWM_DEFAULT_ARR / 200U, 10U);
     *   （函数仍在 TIM_PWM.c 里，没删；但它已经不在 main 的主流程上了）
     * ------------------------------------------------------------------ */
#if V3_TEST
    {
        /* ---------------------------------------------------------------
         * V3 · AXI_GPIO_1 -> TB6612 引脚对位 + STBY 解耦验证
         *
         * 本段替换掉 V2 的 PWM 相位机（相位机已上板通过，见
         *   分区验证\02a-V2-上板通过.md）。V2 代码留在 main.c.bak-20261101-v2。
         *
         * 只验两件事，都是纯电平，不需要示波器：
         *   ① DATA 的 bit0..3 到底落在 J12 的哪根针上
         *   ② CTRL[3]（motor_enable -> STBY）会不会把 PWM 门控掉
         *      ★ V3 当时的答案是"不会"；**V8 起 RTL 改成"会"了**，
         *        所以这条判据在 V8 位流上已经反过来，见下面"判据"末尾。
         *        本区保留下来主要是 ① 还有用（引脚对位永远要验）。
         *
         * 引脚（V3 约束，BANK11 3V3，满载实测 3.45 V）：
         *   bit0 AIN1 -> PIN13 U9
         *   bit1 AIN2 -> PIN14 U8
         *   bit2 BIN1 -> PIN15 V11
         *   bit3 BIN2 -> PIN16 V10
         *   CTRL[3] STBY -> PIN17 Y7
         *   地           -> PIN2  GND
         *
         * 扫描序列：
         *   0x1 0x2 0x4 0x8   四位逐根点亮，用来做"单线定址"
         *   0x0 0xF           全低 / 全高，验证没有相邻短路
         *   0x3 0xC           A 侧两高 / B 侧两高，验证成对关系
         *
         * ★ STBY 按"整轮"翻转，不是按档翻转。
         *   3 s 一档本来就紧，若同档内还翻 STBY，量线的人分不清"这档是哪个
         *   pattern、STBY 是几"。整轮翻转后，一轮 8 档内 STBY 恒定，串口表头
         *   和电平表能一一对上。
         *     round 0/2/4... STBY=1 ; round 1/3/5... STBY=0
         *
         * ★ 判据
         *   P13/P14/P15/P16 逐档与打印表一致、3.45 V / 0 V 分明
         *     => DATA 四位全部落到正确引脚，AXI_GPIO_1 通了
         *   只动一根     => 位宽仍是 1（自检第 1 步会先报出来）
         *   全不动       => TRI 没清掉，或位流不是含 GPIO_1 的那份(eced412a)
         *   相邻两根一起动 => 约束里 ball 号写串了，回 fpga_pin.adc 核对
         *
         *   ---- 以下两条是 V3 位流上的结论，V8 位流上已经反转 ----
         *   round0（STBY=1）和 round1（STBY=0）里 PIN 9 的 CH0 方波都在
         *     => STBY 不门控 PWM（与当时 RTL 的 assign motor_enable = ctrl_reg[3] 一致）
         *   round1 里 PIN 9 波形消失
         *     => STBY 被误接进 PWM 使能，要回 PL 查
         *
         *   ⚠️⚠️ 在 V8 及以后的位流上重跑本区，round1（STBY=0）**必然**
         *     看不到 PIN 9 的方波 —— 因为 pwm_out 现在就是
         *     ch_pwm && ctrl_reg[3] && !guard_hit。这是设计要求，不是故障，
         *     别照着上面第二条去改 PL。要复现 V3 结论，只能用 V3 那份位流。
         *
         * ⚠ 全序列不含 0x5 / 0xA，电机全程不转，只有 0xF 的短接制动。
         * ------------------------------------------------------------------ */
        static const u32 v3_seq[8] = {
            0x1U, 0x2U, 0x4U, 0x8U, 0x0U, 0xFU, 0x3U, 0xCU
        };
        u32 idx;
        u32 round;
        u32 st;

        printf("\r\n===== V3: AXI_GPIO_1 -> TB6612 pin mapping =====\r\n");
        printf("    AIN1=PIN13(U9) AIN2=PIN14(U8) BIN1=PIN15(V11) BIN2=PIN16(V10)\r\n");
        printf("    STBY=PIN17(Y7) GND=PIN2   full scale 3.45 V\r\n");

        /* PWM 保持在 PIN 9 上跑 50%，专门用来观察 STBY 有没有门控它。
         * 选 50% 是为了示波器上"有波 / 无波"一眼可辨，不必读具体占空比。 */
        PWM_SetTiming(PWM_CH0, PWM_DEFAULT_PSC, PWM_DEFAULT_ARR, 5000U);
        PWM_Commit(PWM_UPDATE_CH(PWM_CH0));
        printf("    CH0 = 50%% on J12 PIN 9 (V6), used as STBY probe\r\n");

        /* ① 寄存器自检：第 1 步兼作位宽探针（位宽还是 1 时写 0xF 只回读 0x1） */
        st = Gpio1_SelfTest();
        printf("[1] GPIO1 self-test = %u (%s)\r\n",
               (unsigned)st, (st == 0U) ? "OK" : "FAIL");
        if (st == 1U) {
            printf("    step1 fail -> readback != 0xF : AL_GPIO_WD is still 1\r\n");
            printf("    => bitstream is OLD, re-synthesize before trusting the sweep\r\n");
        } else if (st != 0U) {
            printf("    step%u fail -> AXI write path to 0x80100000 is broken\r\n",
                   (unsigned)st);
        }

        /* ② TRI 兜底清零。
         * All Outputs 模式下 TRI 寄存器很可能已被综合裁掉，读回值不可信，
         * 这里只取"写了不报错"，不拿读回值当判据。 */
        Gpio1_WriteTri(0x0U);
        printf("[2] TRI <- 0x0 (readback 0x%X, ignore if register was trimmed)\r\n",
               (unsigned)Gpio1_ReadTri());

        /* ③ 逐值扫描 */
        printf("[3] sweep: 8 values x 3 s, STBY flips once per round\r\n");
        printf("    if the meter is too slow, change 3000 below to 6000\r\n\r\n");
        printf("    #  DATA  AIN1 AIN2 BIN1 BIN2  STBY  readback\r\n");
        printf("           ----  P13  P14  P15  P16   P17\r\n");
        printf("    ------------------------------------------------\r\n");

        for (round = 0U; ; round++) {
            /* 整轮锁定 STBY：round 偶数 = 1，奇数 = 0 */
            u32 stby = ((round & 1U) != 0U) ? 0U : 1U;

            PWM_SetMotor(0U, stby);
            printf("    == round %u : STBY=%u (PIN17 = %s) ==\r\n",
                   (unsigned)round, (unsigned)stby,
                   (stby != 0U) ? "3.45V" : "0V");

            for (idx = 0U; idx < 8U; idx++) {
                u32 pat = v3_seq[idx];

                Gpio1_WriteData(pat);

                printf("    %u  0x%X    %u    %u    %u    %u    %u    0x%X\r\n",
                       (unsigned)idx, (unsigned)pat,
                       (unsigned)((pat >> 0) & 1U),
                       (unsigned)((pat >> 1) & 1U),
                       (unsigned)((pat >> 2) & 1U),
                       (unsigned)((pat >> 3) & 1U),
                       (unsigned)stby,
                       (unsigned)(Gpio1_ReadData() & GPIO1_MASK));

                AlSys_MDelay((AL_U64)3000);
            }

            /* 一轮结束回滑行：下一轮开头要切 STBY，别让它带着 0xC 过去 */
            Gpio1_WriteData(MOTOR_DIR_COAST);
            printf("    == STATUS = 0x%08X (en=%u) ==\r\n\r\n",
                   (unsigned)PWM_ReadStatus(),
                   (unsigned)((PWM_ReadStatus() >> 3) & 0x7U));
        }
    }
#elif V5_TEST
    {
        /* ---------------------------------------------------------------
         * V5 · 双轮差速（第一次让整车动起来）
         *
         * 前置（V3/V4 已验）：方向四位落点正确、A 侧 = 左侧两轮且前后向正确
         * （2026-11-01 21:20 实测）。
         * ⚠️ "STBY 独立不门控 PWM"那条在 V8 位流上不再成立（CTRL[3] 现在
         *    门控 pwm_out[0]/[1]）。但本区一进来就 PWM_SetMotor(0,1) 把
         *    CTRL[3] 拉高，门控恒放开 ⇒ **本区的动作与结论完全不受影响**。
         *
         * 本段按"先标定、后动作"的顺序跑四件事：
         *   ① B 侧单独标定  —— B 侧（右轮）朝哪边转，V4 从来没验过
         *   ② 直行          —— 两侧同速同向
         *   ③ 差速转弯      —— 内外侧占空比不同，走弧线
         *   ④ 原地转        —— 两侧反向，绕车身中心转
         *
         * 接线（A 侧同 V4，B 侧新增 3 根 + 电机线 2 根）：
         *   A 侧  PWMA <- V6   (pwm_out[0], J12 PIN 9)
         *         AIN1 <- U9   (J12 PIN 13)
         *         AIN2 <- U8   (J12 PIN 14)
         *         AO1/AO2 -> 左电机
         *   B 侧  PWMB <- U7   (pwm_out[1], J12 PIN 11)
         *         BIN1 <- V11  (J12 PIN 15)
         *         BIN2 <- V10  (J12 PIN 16)
         *         BO1/BO2 -> 右电机
         *   公共  STBY <- Y7   (J12 PIN 17)
         *         VCC  <- J12 PIN 1 (3V3)
         *         GND  <- J12 PIN 2，且必须与电池负极、TB6612 的 GND 共地
         *         VM   <- 电池 6~12 V（一片 TB6612 的 A/B 两通道共用这一路）
         *
         * ★ 与 V4 相比新增的唯一电源风险：两个电机同时转，电流接近翻倍。
         *   小容量 9 V 方块电池带两个 TT 电机，起步瞬间就掉压，典型症状是
         *   "一启动串口就重启"或"轮子只抖一下不转"。这不是程序问题，别改代码：
         *     处理 ① 空载（轮子离地）时电流很小，先这样验逻辑是对的
         *          ② 要落地跑，换 18650×2 或 2S 锂电，并把 VM 线加粗
         *          ③ TB6612 是单片双通道，两路电机共用一路 VM —— 所以 VM 线
         *             要按"两路电流之和"选线径，不能按单电机估
         *
         * ★ 安全三条（沿用 V4，且因两轮同时转而更重要）
         *   1) 车轮必须离地（垫书/架空），首次绝不允许落地跑
         *   2) 每次换向前先 duty=0 + 刹停，再滑行 1 s
         *   3) 只跑 2 轮就停在刹停态，人离开也不会一直转
         *
         * ★ 判据
         *   ① 标定段：A 侧单独转（应朝车头，V4 已确认）→ 再看 B 侧
         *        B 侧朝车头  => B_SIDE_INVERT = 0 正确，直接往下看
         *        B 侧朝车尾  => TIM_GPIO.h 里 B_SIDE_INVERT 改 1，重编译再跑
         *        B 侧完全不转 => 先查 B 侧三根线（U7/V11/V10）和 STBY
         *   ② 直行段：两轮同向、同速。一正一反 = ① 没解决
         *   ③ 差速段：★ 这条最容易记反 ——
         *        左 30% 右 60%（左慢右快）=> 车头向左偏
         *        左 60% 右 30%（左快右慢）=> 车头向右偏
         *      道理：转弯时外侧轮走的路更长，所以外侧轮必须更快。
         *      往左转 => 右轮在外侧 => 右轮快。
         *   ④ 原地转：一侧进一侧退，两轮转向相反，车身绕中心转
         *
         * ⚠️ 电机绝不可直连 FPGA 引脚，反电动势会打穿 I/O。必须经驱动板。
         * ------------------------------------------------------------------ */
        u32 round;
        u32 ccr_norm = 3000U;   /* 30%：直行、标定、原地转都用这一档 */
        u32 ccr_fast = 6000U;   /* 60%：差速转弯的外侧轮 */

        printf("\r\n===== V5: two-wheel differential =====\r\n");
        printf("    A(left)  PWMA=V6  AIN1=U9  AIN2=U8\r\n");
        printf("    B(right) PWMB=U7  BIN1=V11 BIN2=V10\r\n");
        printf("    STBY=Y7  B_SIDE_INVERT=%u\r\n", (unsigned)B_SIDE_INVERT);
        printf("    CAR MUST BE LIFTED (both wheels off the ground)\r\n");

        /* 上电姿态：两侧占空比 0、方向滑行、STBY 拉高。
         * STBY 高是必须的 —— 它是 TB6612 的总使能，低电平下无论方向位和
         * PWM 怎么给，输出都是高阻，轮子一动不动。
         * ★ V8 起它还会门控 pwm_out[0]/[1]（Ctrl[3] && !guard_hit），
         *   所以这里拉高同时也是"允许 PWM 出去"；不拉高的话轮子不会转，
         *   而且会误判成"PWM 没出来"。 */
        Motor_Init();
        PWM_SetBoth(0U, 0U);
        PWM_SetMotor(0U, 1U);
        printf("[0] STBY=1 (LED4 on), duty=0/0, dir=COAST -> both wheels must stay still\r\n");
        AlSys_MDelay((AL_U64)2000);

        /* ---- ① B 侧标定：同一档占空比下，左边转一次、右边转一次 ---- */
        printf("\r\n[1] CALIBRATION: A alone 2 s, then B alone 3 s\r\n");
        printf("    watch which way each wheel turns relative to the car nose\r\n");

        /* A 侧：V4 已确认朝车头，这里再走一遍是为了给 B 侧一个同条件对照 */
        PWM_SetBoth(ccr_norm, 0U);
        Gpio1_WriteData(DIR_A_ONLY_FWD);
        printf("    A only FWD: dir=0x%X CCR=%u -> LEFT wheel, expect nose-ward\r\n",
               (unsigned)DIR_A_ONLY_FWD, (unsigned)ccr_norm);
        AlSys_MDelay((AL_U64)2000);

        PWM_SetBoth(0U, 0U);
        Gpio1_WriteData(MOTOR_DIR_BRAKE);
        AlSys_MDelay((AL_U64)1000);
        Gpio1_WriteData(MOTOR_DIR_COAST);
        AlSys_MDelay((AL_U64)1000);

        /* B 侧：这一档是 V5 的唯一"未知量"。
         * 给 3 s 而不是 2 s，是因为要在这 3 s 里看清转向并记住，比 A 侧多留 1 s。 */
        PWM_SetBoth(0U, ccr_norm);
        Gpio1_WriteData(DIR_B_ONLY_FWD);
        printf("    B only FWD: dir=0x%X CCR=%u -> RIGHT wheel, nose-ward?\r\n",
               (unsigned)DIR_B_ONLY_FWD, (unsigned)ccr_norm);
        AlSys_MDelay((AL_U64)3000);

        PWM_SetBoth(0U, 0U);
        Gpio1_WriteData(MOTOR_DIR_BRAKE);
        printf("    >> if the RIGHT wheel went BACKWARD: set B_SIDE_INVERT=1 and rebuild\r\n");
        AlSys_MDelay((AL_U64)2000);
        Gpio1_WriteData(MOTOR_DIR_COAST);
        AlSys_MDelay((AL_U64)1000);

        /* ---- ②③④ 动作段（2 轮） ---- */
        for (round = 0U; (V5_ROUNDS == 0U) || (round < V5_ROUNDS); round++) {
            if (V5_ROUNDS == 0U) {
                printf("\r\n    == round %u (endless, reset to stop) ==\r\n",
                       (unsigned)(round + 1U));
            } else {
                printf("\r\n    == round %u / %u ==\r\n",
                       (unsigned)(round + 1U), (unsigned)V5_ROUNDS);
            }

            /* ---- ② 直行：两侧 30% ---- */
            PWM_SetBoth(ccr_norm, ccr_norm);
            Gpio1_WriteData(DIR_BOTH(1, 1));
            printf("[2] STRAIGHT dir=0x%X CCR=%u/%u (30%%/30%%), 6 s\r\n",
                   (unsigned)DIR_BOTH(1, 1), (unsigned)ccr_norm, (unsigned)ccr_norm);
            printf("    both wheels same direction, same speed\r\n");
            AlSys_MDelay((AL_U64)6000);

            PWM_SetBoth(0U, 0U);
            Gpio1_WriteData(MOTOR_DIR_BRAKE);
            AlSys_MDelay((AL_U64)1500);
            Gpio1_WriteData(MOTOR_DIR_COAST);
            AlSys_MDelay((AL_U64)1000);

            /* ---- ③-a 差速：左慢右快 => 车头向左偏 ---- */
            PWM_SetBoth(ccr_norm, ccr_fast);
            Gpio1_WriteData(DIR_BOTH(1, 1));
            printf("[3] DIFF left=30%% right=60%% -> nose should swing LEFT, 6 s\r\n");
            printf("    (turning left, so the RIGHT wheel is the outer one = faster)\r\n");
            AlSys_MDelay((AL_U64)6000);

            PWM_SetBoth(0U, 0U);
            Gpio1_WriteData(MOTOR_DIR_BRAKE);
            AlSys_MDelay((AL_U64)1500);
            Gpio1_WriteData(MOTOR_DIR_COAST);
            AlSys_MDelay((AL_U64)1000);

            /* ---- ③-b 差速：左快右慢 => 车头向右偏 ---- */
            PWM_SetBoth(ccr_fast, ccr_norm);
            Gpio1_WriteData(DIR_BOTH(1, 1));
            printf("[4] DIFF left=60%% right=30%% -> nose should swing RIGHT, 6 s\r\n");
            AlSys_MDelay((AL_U64)6000);

            PWM_SetBoth(0U, 0U);
            Gpio1_WriteData(MOTOR_DIR_BRAKE);
            AlSys_MDelay((AL_U64)1500);
            Gpio1_WriteData(MOTOR_DIR_COAST);
            AlSys_MDelay((AL_U64)1000);

            /* ---- ④-a 原地右转：左进右退 ----
             * 一侧进一侧退时，两侧输出是反相的，反电动势叠加最狠，
             * 所以这一档固定用 30% 而不用 60%。 */
            PWM_SetBoth(ccr_norm, ccr_norm);
            Gpio1_WriteData(DIR_BOTH(1, 0));
            printf("[5] SPIN RIGHT dir=0x%X (left FWD / right REV) 30%%/30%%, 4 s\r\n",
                   (unsigned)DIR_BOTH(1, 0));
            AlSys_MDelay((AL_U64)4000);

            PWM_SetBoth(0U, 0U);
            Gpio1_WriteData(MOTOR_DIR_BRAKE);
            AlSys_MDelay((AL_U64)1500);
            Gpio1_WriteData(MOTOR_DIR_COAST);
            AlSys_MDelay((AL_U64)1000);

            /* ---- ④-b 原地左转：左退右进 ---- */
            PWM_SetBoth(ccr_norm, ccr_norm);
            Gpio1_WriteData(DIR_BOTH(0, 1));
            printf("[6] SPIN LEFT dir=0x%X (left REV / right FWD), 4 s\r\n",
                   (unsigned)DIR_BOTH(0, 1));
            AlSys_MDelay((AL_U64)4000);

            /* ---- 本轮收尾：归零 + 刹停 ---- */
            PWM_SetBoth(0U, 0U);
            Gpio1_WriteData(MOTOR_DIR_BRAKE);
            printf("    BRAKE both. STATUS=0x%08X\r\n\r\n", (unsigned)PWM_ReadStatus());
            AlSys_MDelay((AL_U64)3000);
        }

        printf("===== V5 DONE, both motors braked. Press reset to run again =====\r\n");
        printf("    wheel mirrored? set B_SIDE_INVERT=1 in TIM_GPIO.h and rebuild\r\n");
        printf("    both wheels dead? check STBY=Y7 and the shared GND\r\n");
        for (;;) {
        }
    }
#elif V7_TEST
    {
        /* ---------------------------------------------------------------
         * V7 · 串口命令链（输入层）
         *
         * 本区不碰 PL、不碰接线、不改位流 —— 用的就是日志那一路 UART1
         * （0xF8401000，115200 8N1，板上 U26=CH342K 通道 0）。
         *
         * 验四件事：
         *   ① 帧解析正确：4 字节帧头 + CMD + ARG + 4 字节帧尾
         *   ② 命令执行正确：方向 / 差速 / 停止，与 V5 的语义一致
         *   ③ 错帧不误触发：帧头少一个、帧尾少一个、纯噪声混入都不动电机
         *   ④ 断链能自保：500 ms 没收到有效帧，自动停在刹停态
         *
         * 为什么先做单口：V7 的核心是"协议 + 控制链"，与串口屏无关。
         * 串口屏要独占一路，得在 PL 上加软 UART（J12 空脚），那是 V7b，
         * 属于"加 AXI 从端"，必须重导 hpf + 回跑 V0，不能和本区混在一起做。
         *
         * ★ 后来 V8 走了更便宜的路：软 UART 不是新开一个 AXI 从端，而是
         *   **往已有的 axi_lite_pwm 里加寄存器**（0x60/0x64/0x68）。
         *   地址不变、从端不变 ⇒ 不需要重导 hpf，只重综合位流即可。
         *   这条经验值得记住：加外设优先"扩已有从端"，别急着加新从端。
         *
         * ⚠️ 本区会真的驱动电机。测试时整车必须架空。
         * --------------------------------------------------------------- */
        printf("\r\n===== V7: uart command link =====\r\n");
        printf("    shares UART1 with this log (0xF8401000, 115200 8N1)\r\n");
        printf("    CAR MUST BE LIFTED -- commands really drive the motors\r\n");

        V7_Init();

        for (;;) {
            V7_Task();      /* 非阻塞：捞字节 -> 合并 -> 执行 -> 喂看门狗 */
        }
    }
#elif BT_TEST
    {
        /* ---------------------------------------------------------------
         * BT · 蓝牙串口回环（手机发什么，原样回什么）
         *
         * 为什么先做这个再上 V8：V8 的闭环一旦不通，"车轮不转"可能是
         * 蓝牙、可能是门控、可能是电机、可能是超声 —— 四个嫌疑混在一起。
         * 先把蓝牙这一条打穿，后面只剩三个。
         *
         * 一次验完四段链路：
         *   ① 手机 -> PL   RX 解出字节        （BT_RX 的 fresh 位 = 1）
         *   ② PL -> PS     AXI 读通           （PS 读到非 0 字节）
         *   ③ PS -> PL     AXI 写通           （写 BT_TX 后 BT_CFG[17] 变忙）
         *   ④ PL -> 手机   TX 时序对          （手机收到同样的字）
         *
         * ★ 本区**不驱动电机**，但要说清楚"不驱动"是怎么做到的：
         *   公共前段（步骤 3）已经 PWM_Init() 使能了 CH0/CH1，并且
         *   PWM_SetMotor(0,1) 把 CTRL[3] 写成了 1 ⇒ 进来时 STBY 是高、
         *   LED4 是亮的、TB6612 已经使能。**所以本区第一件事是显式压回去**：
         *     PWM_SetMotor(0, 0) ⇒ CTRL[3]=0 ⇒ STBY 低
         *                                     + pwm_out[0]/[1] 被门控（双保险）
         *   再加上三路 CCR 一直是 0、DIR 一直是 COAST，整车落地也不会动，
         *   可以放心测回环。
         *   （代价：LED4 常灭。别拿它当"程序活着"的判据 —— 看 LED5 的三下
         *     快闪和 5 s 一次的心跳行。）
         *
         * ★ 前置：位流必须是 V8 那份。旧位流里 0x50~0x6C 全没译码，
         *   读出来全是 0、写进去返回 SLVERR 但不报错，现象是"回环完全没反应"。
         *   下面开机就做一次指纹检查，把这件事直接说出来，不用猜。
         *
         * ★ 判据（C1b，五条全中才算通过）：
         *   ① 串口打 "[BT] bitstream OK (BT_CFG = 0x000101B2)"
         *      —— 位流对了，AXI 写 0x68 生效
         *   ② 手机上电就看到 "FPGA ready"（Bt_Init 发的）
         *      —— 最少证明 TX 通路 + 波特率对
         *   ③ 手机发一个字符，立刻收到同一个字符
         *      —— 四段链路（手机→PL→PS→PL→手机）全通
         *   ④ 5 s 心跳行里 n_rx 与 n_tx 同步 +1，last 后面出现刚发的那个字节
         *   ⑤ 连发 3 个单字节（间隔 0.5 s 以上），n_rx 加 3
         *     （PS 侧一轮约 1 µs，能跟上；加间隔是为了避开单字节缓冲）
         *
         * ⚠️ 已知限制：PL 的 RX 只有**单字节缓冲**。手机 App 手动发单字节没问题；
         *   若一次粘一整串（如 "hello" 5 字节，间隔 87 µs），只有最后一个能留下。
         *   这是 RTL 的取舍（不为 115200 配 FIFO），不是回环的 bug。
         * --------------------------------------------------------------- */
        u8  b;
        u8  hist[8];
        u32 hist_n = 0U;
        u32 n_rx   = 0U;
        u32 n_tx   = 0U;
        u32 cfg;
        u32 now;
        u32 ms_div;
        u32 last_hb;
        u32 i;
        u32 start;

        printf("\r\n===== BT: soft-UART loopback =====\r\n");
        printf("    TX=T9/PIN5 (-> module RX)   RX=T5/PIN7 (<- module TX)\r\n");
        printf("    STBY forced LOW, duty 0/0 -- wheels cannot turn\r\n");

        /* ★ 显式把电机断电。
         *   公共前段刚把 CTRL[3] 写成 1（为了 LED4 那个单点判据），
         *   本区不需要它，于是写回 0：
         *     CTRL[3]=0 -> STBY 低（TB6612 输出高阻）
         *                -> pwm_out[0]/[1] 同时被门控掉（V8 RTL 的额外保险）
         *   这一步在回环测试里没有任何副作用，只是让"轮子绝对不会转"
         *   这件事从"靠占空比为 0"变成"靠使能关断"，更硬。 */
        PWM_SetMotor(0U, 0U);

        Bt_Init();          /* 会顺手发一行 "FPGA ready" 给手机，那就是 TX 的第一次判据 */

#if BT_TEST_BAUD_9600
        /* 出厂 9600 的模块用这一支：改 0x68 的分频，PL 侧不用重综合。
         * ⚠️ 测完记得把 BT_TEST_BAUD_9600 改回 0，否则 V8 分区还是 115200
         *    （这个宏只在本分区生效，不会影响 V8），容易下次看日志时搞混。 */
        Bt_SetBaud(BT_DIV_9600);
        printf("[BT] !! module assumed at 9600\r\n");
#endif

        /* 位流指纹：刚写进去的 BT_CFG 读回来应该一模一样。
         *   0x000101B2 -> 对，0x68 已译码
         *   0x00000000 -> 旧位流（地址未映射，写被 SLVERR 丢掉）
         *   其它       -> 写通路或 AXI 有问题 */
        cfg = Bt_ReadCfg();
        if ((cfg & 0x1FFFFU) != (BT_CFG_EN | BT_DIV_115200)) {
            printf("!! BT_CFG readback = 0x%08X, expect 0x%08X\r\n",
                   (unsigned)cfg, (unsigned)(BT_CFG_EN | BT_DIV_115200));
            printf("!! 0x68 is not decoded -> the bitstream is NOT the V8 one\r\n");
            printf("!! re-synthesise in TD (do NOT press Generate in DI), then retry\r\n");
            StatBlink(7U, 100U, 100U);
        } else {
            printf("[BT] bitstream OK (BT_CFG = 0x%08X)\r\n", (unsigned)cfg);
        }

        printf("[BT] loopback armed. send ONE byte from the phone, it echoes back\r\n");
        printf("[BT] judge: same byte comes back; n_rx and n_tx both +1\r\n");

        ms_div  = (u32)(AlSys_GetTimerFreq() / 1000ULL);
        if (ms_div == 0U) {
            ms_div = 1U;
        }
        last_hb = 0U;

        for (;;) {
            /* 每轮把 RX 捞干净再回。
             *
             * ★ 这里**不加任何延时**：PL 的 RX 是单字节缓冲，115200 下
             *   一个字节 87 µs。若按 1 ms 节流，连发会只剩最后一个。
             *   AXI 读本身几百纳秒，一轮约 1 µs，余量 40 倍。
             *
             * ★ 回显优先于日志：Bt_SendByte 里有 1 ms 的等发送完成，
             *   如果每字节再打一行 printf（约 1.7 ms），连发必丢。
             *   所以**逐字节不打印**，只把最近 8 个字节攒起来，
             *   等心跳时一起打 —— 既有诊断又不阻塞回环。 */
            while (Bt_PollByte(&b) != 0U) {
                n_rx++;

                Bt_SendByte(b);     /* 原样回显 */
                n_tx++;

                hist[hist_n & 7U] = b;
                hist_n++;
            }

            now = (u32)(AlSys_GetTimerTickCount() / (AL_U64)ms_div);

            if ((u32)(now - last_hb) >= 5000U) {
                last_hb = now;

                printf("[BT] alive %u ms | n_rx=%u n_tx=%u | cfg=0x%08X\r\n",
                       (unsigned)now, (unsigned)n_rx, (unsigned)n_tx,
                       (unsigned)Bt_ReadCfg());

                /* 最近 8 个字节的十六进制。判据：
                 *   手机发 41 42 43，这里应该是 41 42 43
                 *   收到一堆 FF / 00 / 乱码 -> 波特率不对（不是接线问题）*/
                printf("     last:");
                if (hist_n == 0U) {
                    printf(" (nothing received yet)");
                } else {
                    start = (hist_n > 8U) ? (hist_n - 8U) : 0U;
                    for (i = start; i < hist_n; i++) {
                        printf(" %02X", (unsigned)hist[i & 7U]);
                    }
                }
                printf("\r\n");

                /* 分段判据提示：n_rx 一直是 0 时，帮使用者缩小范围 */
                if (n_rx == 0U) {
                    printf("     n_rx=0 -> no byte ever arrived. check:\r\n");
                    printf("       1) module TX really wired to T5 (PIN 7)?\r\n");
                    printf("       2) module baud = 115200? (HC-05/06 factory default is 9600)\r\n");
                    printf("       3) module powered, and GND shared with the board?\r\n");
                } else if (n_tx != n_rx) {
                    printf("     n_tx != n_rx -> TX side stuck, check T9 (PIN 5)\r\n");
                }
            }
        }
    }
#elif V8_TEST
    {
        /* ---------------------------------------------------------------
         * V8 · 控制层最小闭环（蓝牙指令 + 15 cm 硬门控）
         *
         * 本区第一次把三条通路接在一起：
         *   ① 手机 --蓝牙--> PL 软 UART --> PS（本文件轮询 BT_RX）
         *   ② PS --V7_Apply--> AXI_GPIO_1(方向) + AXI PWM(占空比)
         *   ③ HC-SR04 --ECHO--> PL 硬门控 --截断--> pwm_out[0]/[1]
         *
         * ★ 本区最关键的设计：**"小于 15 cm 就停"不在 PS 里**。
         *   判断和执行都在 PL（axi_lite_guard + axi_lite_pwm 的那两行 assign）。
         *   PS 只负责读出来打印给人看。所以就算 PS 卡在 printf 上、
         *   或者整个主循环停住，车到 15 cm 一样会停 —— 这是刻意的。
         *
         * ★ 为什么保留 V7_Init() 却不调 V7_Task()
         *   V7_Init 里有三件该复用的事：解析器自测（12 例）、电机置安全态、
         *   把 s_cur_dir 初始化成 COAST（V7_Apply 的换向保护靠它）。
         *   V7_Task 不调，是因为它会去轮询日志口 UART1 —— 那个口在 V8 里
         *   只当输出用，不该再吃命令字节。顺带看门狗也随之关闭：
         *   手机是"按住走、松手停"的话，按住期间链路一个字节都没有，
         *   看门狗设短了会误停，所以默认关掉（用户已确认这个取舍）。
         *
         * ⚠️ 本区会真的驱动电机。测试时整车必须架空。
         *
         * 判据（C4）：
         *   手机发 0x01（前进）-> 车轮转，串口打 [V7] FWD
         *   手放超声前 10 cm   -> 车轮停，状态行 guard=ON、LED4 灭
         *   手拿开到 20 cm     -> 车轮恢复（迟滞：必须 >17 cm 才放）
         *   发 0x02（后退）    -> 手挡着也照转（门控只管前进，用户明确要求）
         *   发 0x10            -> 打印 guard latch cleared，车能重新前进
         *                         （超声线松了/模块坏了时的现场救命指令）
         * --------------------------------------------------------------- */
        /* ---------------- 速度档位（本区唯一的速度旋钮） ----------------
         * 17 档，20% → 100%，每档 +5%。PWM 分辨率是 1%（ARR=9999 ⇒ 1% = 100 拍），
         * 所以档与档之间是 500 拍，转速差肉眼可辨，不会"按了没反应"。
         *
         *   档位      1     2     3     4  ...              17
         *   占空比   20%   25%   30%   35%  ...            100%
         *
         * ⚠️ 1 档是电机死区边缘：架空能转，落地大概率带不动 —— 那时从 2 档起，
         *    不是"档位坏了"。V5 实测的可靠起转点是 30%（= 3 档）。
         * ⚠️ 100% 只在架空时试；落地跑建议 ≤70%，且 9 V 方块电池在高占空比
         *    下会掉压，典型症状是"一加速串口就重启"。
         */
#define V8_SPD_MIN      20U
#define V8_SPD_MAX      100U
#define V8_SPD_STEP     5U
#define V8_SPD_DEF      30U     /* 默认 = 3 档，V5 实测的起转下限 */
#define V8_GEAR_N       (((V8_SPD_MAX - V8_SPD_MIN) / V8_SPD_STEP) + 1U)
#define V8_GEAR_OF(p)   ((((p) - V8_SPD_MIN) / V8_SPD_STEP) + 1U)

        /* ---------------- 斜率器（软启动 / 软刹车） ----------------
         * 命令只改"目标"，真正的占空比由主循环每 V8_RAMP_MS 挪 1% 追上去。
         *   0 → 60%：1.2 s 爬完，起步不打滑、电池不掉压
         *   60% → 0：1.2 s 收完，刹车时车头不会点一下
         * 副作用是"按了键车不会瞬间窜出去"，这也是我们要的。 */
#define V8_RAMP_MS      20U

        /* ---------------- 减速区（PS 侧软门，配合 PL 的硬门） ----------------
         * PL 只认 15/17 cm 一对阈值，负责"硬关断"。
         * PS 这层管"提前减速"：25 cm 内把目标压到 30%，15 cm 内目标降到 0。
         * 后者不是替代 PL —— PL 已经在那一拍把 PWM 截断了；PS 把目标归零，
         * 是为了让车脱离 17 cm 后从 0 慢慢爬，而不是一下子窜回原档位。 */
#define V8_ZONE_MS      50U     /* 减速区检测周期 */
#define V8_SLOW_TICKS   72500U  /* 25 cm × 2900 拍/cm */
#define V8_SLOW_PCT     30U     /* 减速区内的占空比上限 */

        /* ---------------- 遥测 ----------------
         * 每 1 s 往蓝牙发一行 "D25 G3/17 30% OK"，手机端就是个仪表盘。
         * 一行约 20 字节 = 20 ms（Bt_SendByte 每字节等 1 ms），占空比 2%。 */
#define V8_TEL_MS       1000U

#define V8_TRIM_MAX     10      /* 直线微调范围 ±10% */

        u8  b;
        u8  spd = V8_SPD_DEF;   /* 目标占空比（%），来自档位；档号由 V8_GEAR_OF 换算 */
        u8  ramp_pct = 0U;      /* 实际已输出的占空比，按斜率追 spd */
        u8  run = 0U;           /* 1 = 有方向命令在执行；STOP 清 0 */
        u8  stop_pending = 0U;  /* 1 = 已收到 STOP，等斜率收到 0 再真刹 */
        u8  last_cmd = 0xFFU;   /* 0xFF = 当前没有动作（停着） */
        u8  hit = 0U;           /* 15 cm 硬门控命中（PL 已截断） */
        u8  slow = 0U;          /* 进入减速区 */
        int trim = 0;           /* 直线微调：>0 右轮加快，<0 左轮加快 */
        u32 now;
        u32 ms_div;
        u32 last_zone;
        u32 last_ramp;
        u32 last_print;
        u32 last_tel;
        u32 last_hb;
        u32 ticks = 0U;
        u32 st = 0U;
        u32 cm = 0U;

        printf("\r\n===== V8: bluetooth + 15cm guard =====\r\n");
        printf("    BT    TX=T9/PIN5   RX=T5/PIN7   @115200\r\n");
        printf("    SONAR TRIG=Y6/PIN18  ECHO=Y8/PIN20\r\n");
        printf("    CAR MUST BE LIFTED -- commands really drive the motors\r\n");

        V7_Init();              /* 解析器自测 + 电机安全态（滑行 / 0% / STBY=1） */

        /* 超声寄存器自检：GUARD_CFG 的复位值就是"位流是不是 V8 那份"的指纹。
         * 读到 0 说明 0x58 还没被译码（烧的是 V8 之前的位流），要重综合。 */
        if (Sonar_SelfTest() != 0U) {
            printf("!! GUARD_CFG readback != 0x%08X\r\n", (unsigned)GUARD_CFG_RESET);
            printf("!! bitstream is NOT the V8 one -- re-synthesise before testing\r\n");
            StatBlink(6U, 80U, 80U);
        }

        Sonar_Init();
        Bt_Init();

        printf("[V8] single-byte commands (each one answers back on BT):\r\n");
        printf("     00 stop  01 fwd   02 back  03 spinL 04 spinR\r\n");
        printf("     05 arcL  06 arcR  07 gear+ 08 gear- 09 gear=3\r\n");
        printf("     0B trim+ 0C trim-  11..1F = gear 1..15 (direct)\r\n");
        printf("     10 clear-guard-latch  7F ping\r\n");
        printf("[V8] gears = %u, %u%%..%u%% step %u%% | start gear %u/%u = %u%%\r\n",
               (unsigned)V8_GEAR_N, (unsigned)V8_SPD_MIN, (unsigned)V8_SPD_MAX,
               (unsigned)V8_SPD_STEP,
               (unsigned)V8_GEAR_OF(spd), (unsigned)V8_GEAR_N, (unsigned)spd);
        printf("[V8] ramp %u ms/1%%, slow zone < %u cm -> %u%%, telemetry %u ms\r\n",
               (unsigned)V8_RAMP_MS,
               (unsigned)(V8_SLOW_TICKS / SONAR_TICKS_PER_CM),
               (unsigned)V8_SLOW_PCT, (unsigned)V8_TEL_MS);

        ms_div     = (u32)(AlSys_GetTimerFreq() / 1000ULL);
        if (ms_div == 0U) {
            ms_div = 1U;
        }
        now        = 0U;
        last_zone  = 0U;
        last_ramp  = 0U;
        last_print = 0U;
        last_tel   = 0U;
        last_hb    = 0U;

        for (;;) {
            /* ---------------- ① 蓝牙字节：每轮捞干净 ---------------- */
            /* ★ 这里不加延时。PL 侧的 RX 只有**单字节缓冲**，115200 下
             *   一个字节 87 µs；若主循环按 1 ms 节流，连发的 10 字节会只剩 1 个。
             *   AXI 读本身几百纳秒，一次循环约 1 µs，余量 40 倍 —— 
             *   天然的节流已经够了，不需要额外空转。 */
            while (Bt_PollByte(&b) != 0U) {
                switch (b) {
                case V7_CMD_STOP:
                    /* 不是立刻刹停，而是"把目标降到 0，让斜率收下去"。
                     * 收到 0 的那一拍才真正写 BRAKE —— 见下面 ③ 的 stop_pending。 */
                    run = 0U;
                    stop_pending = 1U;
                    Bt_SendStr("STOP\r\n");
                    break;

                case V7_CMD_FWD:
                case V7_CMD_BACK:
                case V7_CMD_SPIN_L:
                case V7_CMD_SPIN_R:
                case V7_CMD_ARC_L:
                case V7_CMD_ARC_R:
                    run = 1U;
                    stop_pending = 0U;
                    /* 只在"方向/动作变了"的时候调 V7_Apply：
                     *   - 它负责方向位、以及带载反转前的 20 ms 断电刹停
                     *   - 调完立刻把占空比压回 0，交给斜率器从 0 往上爬
                     * 同一条命令重复按不重置，否则每按一次都会顿一下。 */
                    if (b != last_cmd) {
                        V7_Apply(b, spd);       /* 方向 + 反转保护 + 日志 */
                        last_cmd = b;
                        ramp_pct = 0U;
                        PWM_SetBoth(0U, 0U);    /* 目标占空比先压回 0 */
                    }
                    V8_AckDir(V8_CmdName(b), spd);
                    break;

                case V7_CMD_SPD_UP: {
                    /* 升一档。到顶就不再刷屏：手机长按重复发送时会很难看，
                     * 只回一句 MAX 告诉它"已经到顶了"。
                     * ★ 这里**不再调 V7_Apply** —— 改的只是目标值，
                     *   实际占空比由斜率器爬上去，否则就变成硬切了。 */
                    u8 ns = (u8)((spd + V8_SPD_STEP > V8_SPD_MAX)
                                 ? V8_SPD_MAX : (spd + V8_SPD_STEP));

                    if (ns == spd) {
                        Bt_SendStr("MAX\r\n");
                        break;
                    }
                    spd = ns;
                    printf("[V8] gear %u/%u = %u%%\r\n",
                           (unsigned)V8_GEAR_OF(spd), (unsigned)V8_GEAR_N,
                           (unsigned)spd);
                    V8_AckGear(V8_GEAR_OF(spd), V8_GEAR_N, spd);
                    break;
                }

                case V7_CMD_SPD_DN: {
                    u8 ns = (u8)((spd < V8_SPD_MIN + V8_SPD_STEP)
                                 ? V8_SPD_MIN : (spd - V8_SPD_STEP));

                    if (ns == spd) {
                        Bt_SendStr("MIN\r\n");
                        break;
                    }
                    spd = ns;
                    printf("[V8] gear %u/%u = %u%%\r\n",
                           (unsigned)V8_GEAR_OF(spd), (unsigned)V8_GEAR_N,
                           (unsigned)spd);
                    V8_AckGear(V8_GEAR_OF(spd), V8_GEAR_N, spd);
                    break;
                }

                case V7_CMD_SPD_RST:
                    spd = V8_SPD_DEF;
                    printf("[V8] gear %u/%u = %u%% (reset)\r\n",
                           (unsigned)V8_GEAR_OF(spd), (unsigned)V8_GEAR_N,
                           (unsigned)spd);
                    V8_AckGear(V8_GEAR_OF(spd), V8_GEAR_N, spd);
                    break;

                case V7_CMD_TRIM_UP:
                    if (trim >= V8_TRIM_MAX) {
                        Bt_SendStr("TRIM MAX\r\n");
                        break;
                    }
                    trim++;
                    printf("[V8] trim = %d%%\r\n", trim);
                    V8_AckTrim(trim);
                    break;

                case V7_CMD_TRIM_DN:
                    if (trim <= -V8_TRIM_MAX) {
                        Bt_SendStr("TRIM MIN\r\n");
                        break;
                    }
                    trim--;
                    printf("[V8] trim = %d%%\r\n", trim);
                    V8_AckTrim(trim);
                    break;


                case V7_CMD_PING:
                    Bt_SendStr("OK\r\n");
                    break;

                case V7_CMD_GRD_CLR:
                    /* 现场救命：超声线松了/模块坏了以后 latched 会一直保持
                     * 最后一次"近"，车再也前进不了。清一下就好。
                     * ⚠️ 如果超声本身还是坏的，清完门控就等于失效 —— 
                     *    这时 d= 那个数会一直不变、to=Y，看状态行能发现。 */
                    Sonar_ClearGuard();
                    printf("[V8] guard latch cleared on request\r\n");
                    Bt_SendStr("CLR\r\n");
                    break;

                default:
                    /* 0x11–0x1F：直达档位，码值减去 0x10 就是档号（1..15）。
                     * 这一段也是控制字符（< 0x20），手打不出来，
                     * 所以"人打的字撞不上命令"这条红线仍然成立。 */
                    if ((b > V8_CMD_GEAR_BASE) && (b <= V8_CMD_GEAR_MAX)) {
                        u32 g = (u32)(b - V8_CMD_GEAR_BASE);

                        spd = (u8)(V8_SPD_MIN + (g - 1U) * V8_SPD_STEP);
                        printf("[V8] gear %u/%u = %u%% (direct 0x%02X)\r\n",
                               (unsigned)V8_GEAR_OF(spd), (unsigned)V8_GEAR_N,
                               (unsigned)spd, (unsigned)b);
                        V8_AckGear(V8_GEAR_OF(spd), V8_GEAR_N, spd);
                        break;
                    }

                    /* 其余未知字节一律不动电机 —— 宁可没反应，也不能因为一个
                     * 坏字节让车动起来。这里**刻意不打印也不回话**：手机 App
                     * 会发 "+CONN"、"OK"、"AT+..." 这类文本，逐字回话会把蓝牙
                     * 缓冲冲爆。命令码只占 0x00–0x0C 和 0x10–0x1F，
                     * 而 ASCII 可打印字符 ≥ 0x20，两段值域不相交。 */
                    break;
                }
            }

            /* ---------------- ② 时间基准 ---------------- */
            now = (u32)(AlSys_GetTimerTickCount() / (AL_U64)ms_div);

            /* ---------------- ③ 减速区取样（50 ms） ----------------
             * 只采样，不做动作。硬门（15 cm）在 PL 里已经截断 PWM，
             * 这里拿它的状态是为了把"目标"也归零，避免放开时窜出去。 */
            if ((u32)(now - last_zone) >= V8_ZONE_MS) {
                last_zone = now;

                ticks = Sonar_ReadTicks();
                st    = Sonar_ReadState();
                cm    = ticks / SONAR_TICKS_PER_CM;

                hit  = (st & GUARD_ST_HIT) ? 1U : 0U;
                /* 减速区只在"前进 + 测到过有效距离"时生效：
                 *   - 倒车不减速（要能退出障碍区）
                 *   - 超声没接过（EVER=0）就不做软门，否则 ticks=0 会被
                 *     当成"贴脸"，车永远只能 30% 爬 */
                slow = ((st & GUARD_ST_EVER) && (st & GUARD_ST_DIR_FWD) &&
                        (ticks < V8_SLOW_TICKS) && (hit == 0U)) ? 1U : 0U;
            }

            /* ---------------- ④ 斜率器（20 ms 一步） ----------------
             * 稳态占空比只有这一个出口；命令只改"目标"，输出由这里追。
             * 另有两处瞬时写：方向/动作切换时压回 0（让斜率重爬）、
             * V7_Apply 内部的 20 ms 换向断电 —— 都不产生稳态输出。 */
            if ((u32)(now - last_ramp) >= V8_RAMP_MS) {
                u32 tgt = 0U;
                u8  next;

                last_ramp = now;

                if (run) {
                    tgt = spd;
                    if (hit) {
                        tgt = 0U;                    /* 硬门命中：PL 已截断，目标也归零 */
                    } else if (slow && (tgt > V8_SLOW_PCT)) {
                        tgt = V8_SLOW_PCT;           /* 25 cm 内压到 30% */
                    }
                }

                next = ramp_pct;
                if (next < tgt) {
                    next++;
                } else if (next > tgt) {
                    next--;
                }

                if (next != ramp_pct) {
                    ramp_pct = next;

                    if (last_cmd != 0xFFU) {
                        int tl = (int)ramp_pct;
                        int tr = (int)ramp_pct;

                        /* 弧线：内侧轮减半，与 V7_Apply 的语义保持一致 */
                        if (last_cmd == V7_CMD_ARC_L) { tl /= 2; }
                        if (last_cmd == V7_CMD_ARC_R) { tr /= 2; }

                        /* 直线微调：只加一侧。修的是机械偏差，不是转弯，
                         * 所以不要求平均速度不变 —— 那样会让车整体变慢。 */
                        if (trim > 0) {
                            tr += trim;
                        } else if (trim < 0) {
                            tl += -trim;
                        }
                        if (tl > 100) { tl = 100; }
                        if (tr > 100) { tr = 100; }
                        if (tl < 0)   { tl = 0; }     /* 保险，逻辑上到不了 */
                        if (tr < 0)   { tr = 0; }

                        PWM_SetBoth((u32)tl * 100U, (u32)tr * 100U);
                    } else {
                        PWM_SetBoth(0U, 0U);
                    }
                }

                /* STOP 的两段式：先收到 0，再写 BRAKE。
                 * 直接在 60% 上短接制动会让车头点一下，人也听着难受。 */
                if ((run == 0U) && (stop_pending != 0U) && (ramp_pct == 0U)) {
                    V7_Apply(V7_CMD_STOP, 0U);
                    stop_pending = 0U;
                    last_cmd = 0xFFU;
                }
            }

            /* ---------------- ⑤ 状态行（500 ms，走串口） ---------------- */
            if ((u32)(now - last_print) >= 500U) {
                last_print = now;

                printf("[V8] d=%u cm (%u ticks) gear=%u/%u %u%% out=%u%% trim=%d | guard=%s slow=%s latch=%s ever=%s fwd=%s busy=%s to=%s hits=%u\r\n",
                       (unsigned)cm, (unsigned)ticks,
                       (unsigned)V8_GEAR_OF(spd), (unsigned)V8_GEAR_N,
                       (unsigned)spd, (unsigned)ramp_pct, trim,
                       (st & GUARD_ST_HIT)     ? "ON " : "off",
                       slow ? "Y" : "n",
                       (st & GUARD_ST_LATCHED) ? "Y" : "n",
                       (st & GUARD_ST_EVER)    ? "Y" : "n",
                       (st & GUARD_ST_DIR_FWD) ? "Y" : "n",
                       (st & GUARD_ST_BUSY)    ? "Y" : "n",
                       (st & GUARD_ST_TIMEOUT) ? "Y" : "n",
                       (unsigned)Sonar_ReadGuardCnt());
            }

            /* ---------------- ⑥ 蓝牙遥测（1 s） ----------------
             * 手机端不用看串口就知道现在什么状态：
             *   D25  = 25 cm（D-- 表示从没测到有效值）
             *   G3/17 30% = 3 档
             *   OK / SLOW / HIT = 正常 / 进减速区 / 被硬门截断 */
            if ((u32)(now - last_tel) >= V8_TEL_MS) {
                last_tel = now;

                if ((st & GUARD_ST_EVER) != 0U) {
                    Bt_SendStr("D");
                    V8_SendNum(cm);
                } else {
                    Bt_SendStr("D--");
                }
                Bt_SendStr(" G");
                V8_SendNum(V8_GEAR_OF(spd));
                Bt_SendStr("/");
                V8_SendNum(V8_GEAR_N);
                Bt_SendStr(" ");
                V8_SendNum(spd);
                Bt_SendStr("% ");
                Bt_SendStr(hit ? "HIT" : (slow ? "SLOW" : "OK"));
                Bt_SendStr("\r\n");
            }

            /* ---------------- ⑦ 心跳（5 s） ---------------- */
            if ((u32)(now - last_hb) >= 5000U) {
                last_hb = now;
                /* ⚠️ 这里刻意**不读** Bt_ReadRxCount()：它读的是 0x60，
                 *   而 RTL 里"读 0x60 就清 fresh" —— 心跳每 5 s 跑一次，
                 *   只要撞上正有一个字节在缓冲里，就会把它静默吞掉。
                 *   现象是"偶尔发命令没反应"，极难复现。
                 *
                 *   要判断线路有没有字节，看回环分区（BT_TEST）的 n_rx；
                 *   或者停手几秒后手动读一次 count。 */
                printf("[V8] alive %u ms | gear %u/%u %u%% | dir=0x%X\r\n",
                       (unsigned)now,
                       (unsigned)V8_GEAR_OF(spd), (unsigned)V8_GEAR_N,
                       (unsigned)spd,
                       (unsigned)(Gpio1_ReadData() & GPIO1_MASK));
            }
        }
    }
#else
    {
        /* ---------------------------------------------------------------
         * V4 · 单电机开环（第一次碰机械）
         *
         * 前置（V3 已验）：方向四位落点正确；STBY 需为高才输出
         * （V3 位流上它不门控 PWM，V8 位流上门控；本区开头就把它拉高，
         *   所以两种位流下行为一致）。
         * 本段只加"电机动起来"这一层，验四件事：
         *   ① 正转指令 -> 轮子朝车头方向转
         *   ② 反转指令 -> 反向
         *   ③ 10% / 30% / 50% 三档转速肉眼可辨递增
         *   ④ 停 = 刹停（0xF）不是滑行（0x0）
         *
         * 接线（本区只接 A 侧一个电机）：
         *   TB6612 PWMA  <- V6  (pwm_out[0], J12 PIN 9)
         *   TB6612 AIN1  <- U9  (J12 PIN 13)
         *   TB6612 AIN2  <- U8  (J12 PIN 14)
         *   TB6612 STBY  <- Y7  (J12 PIN 17)
         *   TB6612 AO1/AO2 -> 电机
         *   TB6612 VCC   <- J12 PIN 1 (3V3)
         *   TB6612 VM    <- 6~12 V 电池
         *   TB6612 GND   <- 与板卡共地（J12 PIN 2）
         *
         * ★ 安全设计（三条，都是"宁可慢一点"）
         *   1) 空载起步：首次必须把车轮垫离地，确认转向后再落地。
         *   2) 换向前先归零：0x5 <-> 0xA 之间先把占空比写到 0 并滑行 2.5 s。
         *      带载直接反接会产生很大的反向电流，是最容易烧驱动管的动作。
         *   3) 只跑 3 轮就停在刹停态，不无限循环 —— 人离开也不会一直转。
         *
         * ★ 判据速查
         *   正转 10% -> 慢；30% -> 明显快；50% -> 更快          ⇒ 调速成立
         *   反转同样三档、方向与正转相反                        ⇒ 换向成立
         *   0xF + duty 0 -> 立刻停住（用手轻拨轴有明显阻力）    ⇒ 刹停成立
         *   0x0 + duty 0 -> 松手后靠惯性滑一小段                ⇒ 滑行成立
         *   方向反了 -> 交换 TIM_GPIO.h 里 MOTOR_DIR_FWD / REV 的值，不用改接线
         *
         * ⚠️ 电机绝不可直连 FPGA 引脚，反电动势会打穿 I/O。必须经驱动板。
         * ------------------------------------------------------------------ */
        static const u32 v4_ccr[3] = { 1000U, 3000U, 5000U };
        static const u32 v4_pct[3] = { 10U, 30U, 50U };
        u32 round;
        u32 i;

        printf("\r\n===== V4: single motor open loop =====\r\n");
        printf("    A side: AIN1=U9 AIN2=U8 PWMA=V6 | STBY=Y7 | GND=PIN2\r\n");
        printf("    CAR MUST BE LIFTED. 3 rounds, then auto-brake.\r\n");

        Motor_Init();
        PWM_SetTiming(PWM_CH0, PWM_DEFAULT_PSC, PWM_DEFAULT_ARR, 0U);
        PWM_Commit(PWM_UPDATE_CH(PWM_CH0));
        PWM_SetMotor(0U, 1U);
        printf("[1] STBY=1 (LED4 on), dir=COAST, duty=0 -> MUST stay still\r\n");
        AlSys_MDelay((AL_U64)2000);

        for (round = 0U; round < 3U; round++) {
            printf("    == round %u / 3 ==\r\n", (unsigned)(round + 1U));

            /* ---- 正转：10 / 30 / 50 ---- */
            Gpio1_WriteData(MOTOR_DIR_FWD);
            for (i = 0U; i < 3U; i++) {
                PWM_SetTiming(PWM_CH0, PWM_DEFAULT_PSC, PWM_DEFAULT_ARR, v4_ccr[i]);
                PWM_Commit(PWM_UPDATE_CH(PWM_CH0));
                printf("    FWD  dir=0x%X CCR=%u (%u%%)  expect faster each step\r\n",
                       (unsigned)MOTOR_DIR_FWD, (unsigned)v4_ccr[i], (unsigned)v4_pct[i]);
                AlSys_MDelay((AL_U64)8000);
            }

            /* ---- 停：先降占空比，再刹停 ---- */
            PWM_SetTiming(PWM_CH0, PWM_DEFAULT_PSC, PWM_DEFAULT_ARR, 0U);
            PWM_Commit(PWM_UPDATE_CH(PWM_CH0));
            Gpio1_WriteData(MOTOR_DIR_BRAKE);
            printf("    BRAKE dir=0x%X duty=0 -> stops at once, shaft has drag\r\n",
                   (unsigned)MOTOR_DIR_BRAKE);
            AlSys_MDelay((AL_U64)3000);

            /* ---- 换向前归零 + 滑行，避免带载反接 ---- */
            Gpio1_WriteData(MOTOR_DIR_COAST);
            printf("    COAST dir=0x0 duty=0 -> free wheel, spins down by inertia\r\n");
            AlSys_MDelay((AL_U64)2500);

            /* ---- 反转：10 / 30 / 50 ---- */
            Gpio1_WriteData(MOTOR_DIR_REV);
            for (i = 0U; i < 3U; i++) {
                PWM_SetTiming(PWM_CH0, PWM_DEFAULT_PSC, PWM_DEFAULT_ARR, v4_ccr[i]);
                PWM_Commit(PWM_UPDATE_CH(PWM_CH0));
                printf("    REV  dir=0x%X CCR=%u (%u%%)  expect opposite direction\r\n",
                       (unsigned)MOTOR_DIR_REV, (unsigned)v4_ccr[i], (unsigned)v4_pct[i]);
                AlSys_MDelay((AL_U64)8000);
            }

            /* ---- 本轮收尾：归零 + 刹停 ---- */
            PWM_SetTiming(PWM_CH0, PWM_DEFAULT_PSC, PWM_DEFAULT_ARR, 0U);
            PWM_Commit(PWM_UPDATE_CH(PWM_CH0));
            Gpio1_WriteData(MOTOR_DIR_BRAKE);
            printf("    BRAKE. STATUS=0x%08X\r\n\r\n", (unsigned)PWM_ReadStatus());
            AlSys_MDelay((AL_U64)4000);
        }

        printf("===== V4 DONE, motor held in brake. Press reset to run again =====\r\n");
        printf("    direction inverted? swap MOTOR_DIR_FWD / MOTOR_DIR_REV in TIM_GPIO.h\r\n");
        for (;;) {
        }
    }
#endif
#endif
#else
    /* 只跑到步骤 1 或 2 的时候，打印完就停住。
     * 用空循环而不是 return，是为了不让 main 返回后跑进 undefined 区域，
     * 也让调试器能一直停在这个状态方便观察。 */
    printf("done (step %d), idling\r\n", BRINGUP_STEP);
    for (;;) {
    }
#endif

    return 0;
}
