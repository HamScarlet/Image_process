/*
 * main.c - AnLuRun MainProject 的 PS 主程序
 *
 * 本工程的分工（重要，别改错层）：
 *   图像链路全部在 PL 里硬件自走：MIPI -> CSI -> ISP -> 降采样 -> uidbuf 三帧缓存
 *   -> FDMA -> VTC -> HDMI(1024x600)。PS 只负责在开机时释放 PL 复位（Fclk_Init），
 *   之后就只剩"通过 AXI 写 PWM 寄存器"这一件事，完全不参与像素处理。
 *
 * 原 main.c 的问题：
 *   1. while(1) 里只有 UART_Test()，没有呼吸灯，也没有任何控制逻辑
 *   2. AL_REG32_WRITE(0x80200000, 0x01) 是裸地址直写，绕过了 TIM_PWM 的寄存器定义，
 *      而且写进去的 0x01 只打开 CH0 使能、ARR/CCR 还是复位默认值，灯不会呼吸
 *   3. al_printf("addr: %d") 用 %d 打 u32，格式符不匹配
 *   4. TIM_PWM_Init / AXI_GPIO_Init 全被注释，整块能力没接上
 *
 * 本版结构（参考官方成功工程 axi_intr/main.c 的实战做法）：
 *   BRINGUP_STEP 分级 -> 探针(AXI 通不通) -> 自检(寄存器可读可写) -> 呼吸灯
 *   主循环只做两件事：PWM_BreathTick 推进占空比 + AlSys_MDelay 定节拍
 *
 * ---------------------------------------------------------------------------
 * 【2026-10-31 移植自官方成功工程 D:\FPGAproject\AnLuRun\PSPWM\soc_sdk\axi_intr】
 *   移植了三样东西，都是那边踩过坑之后总结出来的：
 *
 *   ① 状态灯 LED5（MIO51，PS GPIO）—— 独立于 AXI / PL / 串口的"程序还活着"信号。
 *      axi_intr 靠它区分"程序根本没跑"和"检查没过"：上电短闪 3 下 = 程序在跑，
 *      全部通过转常亮，失败则慢闪 250 ms。裸机空转从外面看和"跑飞了"没区别，
 *      有节奏的慢闪至少能证明 CPU 还在跑、定时器还活着、GPIO 还能驱动。
 *      ⚠ 本工程用 LED5 更划算的地方：**HDMI 图像本身就是更强的独立判据**
 *        （MIPI->ISP->FDMA->HDMI 全在 PL，不经过 AXI 也不经过 PS）。
 *        所以 LED5 与 HDMI 图像构成两条互不依赖的观察通道。
 *
 *   ② 强诊断打印 —— 寄存器回读比"看灯亮不亮"硬得多。
 *      灯还受引脚分配、极性、位流版本影响，任何一个不对都不亮；
 *      而回读只反映"AXI 写通路"这一件事，变量少得多。
 *
 *   ③ 失败就地停机 —— 带着坏通路继续跑会把线索搅浑：
 *      到底是"通路坏了"还是"波形坏了"，这两种病因修法完全不同。
 *
 *   另外：MMIO 宏按 AXI_test.c 的写法加了 (uintptr_t) 过渡（见 TIM_PWM.c）。
 * ---------------------------------------------------------------------------
 */

#include <stdio.h>
#include "al_core.h"
#include "al_systimer.h"
#include "al_gpio_hal.h"
#include "ui_io.h"
#include "ui_type.h"
#include "Definitions.h"

#include "TIM_PWM.h"
#include "Car_control.h"
#include "motor.h"
#include "USART.h"

/* ---------------------------------------------------------------------------
 * 状态灯：板载 LED5 = MIO51，走 PS GPIO（写 1 = 亮）
 *
 *  【引脚号 51 的来源（不是猜的）】
 *    MainProject 的 soc_base/platform/src/soc_plat.c 里 psio_data_0[] 的注释：
 *        // Config GPIO, PS IO 50->FUNCSEL: GPIO
 *        // Config GPIO, PS IO 51->FUNCSEL: GPIO
 *    即本工程被配置成 GPIO 功能的 MIO 是 {0,7,8,16..27,46,50,51,52,53}，
 *    其中 MIO50 = 板上 KEY3、MIO51 = 板上 LED5。
 *    ⚠ 这个集合是"逐工程"的，换工程必须重新核对，不能照抄。
 *
 *  【极性】
 *    LED5 由 N-MOS 低边驱动，栅极接 MIO51，写 1 = 点亮。
 *    若实测正好相反，把 StatLed() 里的 1U/0U 对调即可，逻辑不用动。
 *
 *  【为什么只用 WritePin，不用 WriteBank】
 *    AlGpio_Hal_WritePin 只改"自己那一位"的输出方向，同 Bank 其它引脚一个都不碰；
 *    WriteBank / DiscreteSet / DiscreteClear 会把整个 Bank 的 32 个引脚全部设成输出，
 *    MIO50（KEY3 按键）就在同一个 Bank 里，用 WriteBank 会把按键废掉。
 *
 *  【⚠ 复用风险】
 *    MIO51 同时是 PS 网口复位 PS_ETH_RST_B。本工程不用网口，随便用；
 *    将来若启用以太网，把 STAT_LED_OK 改成 0。
 * ------------------------------------------------------------------------- */
#define STAT_LED_PIN        51U     /* MIO51 = 板上 LED5 */
#define STAT_LED_OK         1       /* 1 = 启用状态灯，0 = 整体关闭 */

static AL_GPIO_HalStruct *g_stat_led = AL_NULL;

/* GPIO 驱动句柄。初始化失败时置 AL_NULL，StatLed() 里用 != AL_NULL 挡掉野指针。 */
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

/* 闪 times 次：每次亮 on_ms 毫秒、灭 off_ms 毫秒。
 * AlSys_MDelay 的时基来自 ARM 通用定时器（cntpct_el0），在启动阶段
 * al_aarch64_start.S -> AlChip_Init -> AlSys_StartTimer 就已经打开，
 * 进 main 之后可以直接用。参数用 AL_U64 传，因为形参就是 64 位。 */
static void StatBlink(u32 times, u32 on_ms, u32 off_ms)
{
    while (times--) {                           /* 先判断再自减，times=3 就闪 3 次 */
        StatLed(1U);
        AlSys_MDelay((AL_U64)on_ms);
        StatLed(0U);
        AlSys_MDelay((AL_U64)off_ms);
    }
}

/* 失败时的"停机 + 慢闪"。
 * 不快闪的原因：快闪容易看成一团模糊的亮，和"常亮"不好分辨；
 * 250 ms 的慢闪节奏清楚，一眼就能和"成功常亮"分开。 */
static void StatFailLoop(void)
{
    for (;;) {
        StatBlink(1U, 250U, 250U);
    }
}

/* ---------------- 分级上板开关 ---------------- */
/* 1 = 只读 VERSION，一个字节都不写（怀疑 AXI 通路时用，此时灯全灭是正常现象）
 * 2 = 加 CCR 写-读回自检
 * 3 = 完整：初始化 + 呼吸灯 */
#define BRINGUP_STEP            3

/* ---------------- 呼吸灯参数 ---------------- */
#define BREATH_STEP             20U     /* 占空比步长，ARR=9999 -> 500 级 */
#define BREATH_STEP_MS          5U      /* 每级停留 5 ms -> 单程约 2.5 s */
#define MAIN_TICK_MS            2U      /* 主循环节拍，须等于 PWM_BREATH_TICK_MS */

/* 开机时释放 PL 侧 FCLK 与 p2f 总线复位
 * ⚠ 这里操作的是**时钟模块的复位寄存器**，不是 AXI PWM 的时钟源。
 *    AXI PWM 的时钟源是 p2f_clk1 = 49.995 MHz（见 TIM_PWM.h 频率公式）。 */
static void Fclk_Init(void)
{
    u32 val;

    /* 复位 PL 的时钟 FCLK（将 p2f_rst_n 全部置低） */
    val = UI_In32((void *)(uintptr_t)0xF8806330U);
    UI_Out32((void *)(uintptr_t)0xF8806330U, val & (~0xF0U));

    /* 使能 GP 和 FAHB 端口 */
    val = UI_In32((void *)(uintptr_t)0xF8800080U);
    val &= ~0x2U;
    UI_Out32((void *)(uintptr_t)0xF8800080U, val);

    /* 复位 GP0M/GP1M/HP0/HP1 */
    val = UI_In32((void *)(uintptr_t)0xF8801078U);
    UI_Out32((void *)(uintptr_t)0xF8801078U, val & (~0x33U));
    AlSys_MDelay(1U);
    UI_Out32((void *)(uintptr_t)0xF8801078U, val | 0x33U);

    /* 释放 PL 端 FCLK 的复位（将 p2f_rst_n 全部置高） */
    val = UI_In32((void *)(uintptr_t)0xF8806330U);
    UI_Out32((void *)(uintptr_t)0xF8806330U, val | 0xF0U);
}

int main(void)
{
    u32 ver;        /* 步骤 1：读回的 VERSION 值，应为 0x00010000 */
    u32 rc;         /* 步骤 2：自检返回码，0 = 正常，1/2 = 两种失败 */
    u32 status;     /* STATUS 寄存器的快照 */
    u32 ctrl;

    /* ------------------------------------------------------------------
     * 开机自报平安
     *   先闪三下，证明三件事同时成立：
     *     1) 程序真的执行到 main 了（不是卡在启动、也不是位流没下）
     *     2) GPIO 驱动初始化成功
     *     3) 系统定时器在走（否则 AlSys_MDelay 会卡死，连三下都闪不完）
     *   这三件事都成立，后面的失败才有意义；否则先回去查下载。
     * ------------------------------------------------------------------ */
    StatLed_Init();
    StatBlink(3U, 120U, 120U);

    /* ------------------------------------------------------------------
     * 释放 PL 侧时钟与总线复位。
     *   ⚠ 必须放在 Fclk_Init 之后、任何 AXI 访问之前 ——
     *     在没释放复位时读 0x8020000C 属于"向没有应答的从端发起访问"，
     *     可能返回 DECERR，也可能被总线直接挂住。
     * ------------------------------------------------------------------ */
    Fclk_Init();
    AlSys_MDelay(250U);
    printf("[SYS] Fclk init done\r\n");

    printf("\r\n===== MainProject AXI PWM bring-up (STEP=%d) =====\r\n", BRINGUP_STEP);
    printf("base = 0x%08X\r\n", (unsigned)AXI_PWM_BASE);

#if (BRINGUP_STEP >= 1)
    /* ------------------------------------------------------------------
     * 步骤 1：只读 VERSION 寄存器（0x8020000C）
     *   整条 AXI 通路唯一的"零副作用"探针：一个字节都不写。
     *   结果怎么判：
     *     读到 0x00010000   -> 地址窗口命中、从端有响应、连线正确
     *     读到 0x00000000   -> 从端可能没被选中，或返回了全 0
     *     读到 0xFFFFFFFF   -> 总线错误（DECERR）常见的表现
     *     干脆卡住不返回   -> 该地址没有任何从端应答，AXI 读会一直等下去
     * ------------------------------------------------------------------ */
    ver = PWM_ReadVersion();
    printf("[1] VERSION = 0x%08X (expect 0x%08X) %s\r\n",
           (unsigned)ver, (unsigned)PWM_VERSION_EXPECT,
           (ver == PWM_VERSION_EXPECT) ? "OK" : "FAIL");

    if (ver != PWM_VERSION_EXPECT) {
        printf("AXI path NOT ready. check: DS_AXI2 base / bus wiring / clock domain\r\n");
        printf("hint: GP0 master + AXI chain must share ONE clock domain.\r\n");
        printf("      official layout: master_gp0_axi_aclk == p2f_clk1 (49.995MHz),\r\n");
        printf("      same net as AXI_Matrix_0.aclk / Converter_*.aclk / pwm.s_axi_aclk\r\n");

        /* 到这儿就不要往下写了。往一个没有从端应答的地址写，同样会挂死调试器，
         * 而且会把"读就不通"这个已经很明确的线索搅浑。 */
        StatFailLoop();
    }
#endif

#if (BRINGUP_STEP >= 2)
    /* ------------------------------------------------------------------
     * 步骤 2：写-读回自检 —— 验证"写"这一半
     *   返回码：0 = 通；1 = VERSION 不对；2 = 写进去读出来不一样
     *   （AW/W 握手、wstrb 字节使能或影子寄存器实现有问题）
     * ------------------------------------------------------------------ */
    rc = PWM_SelfTest();
    printf("[2] self-test %s (code %d)\r\n", (rc == 0U) ? "OK" : "FAIL", (int)rc);

    /* STATUS 位序（与 PL 侧 axi_lite_pwm.v 的读多路选择器一一对应）：
     *   bit2..0 = update_pending  三路的"待提交"标志
     *   bit5..3 = ctrl[2:0]       三路的通道使能
     *   bit6    = ctrl[3]         电机驱动使能
     * 此刻还没使能任何通道，正常应读到 0x00000000。 */
    status = PWM_ReadStatus();
    printf("    STATUS = 0x%08X  (pending=%d, en=%d, motor_en=%d)\r\n",
           (unsigned)status,
           (int)(status & 0x7U),                /* bit0..2：待提交 */
           (int)((status >> 3) & 0x7U),         /* bit3..5：通道使能 */
           (int)((status >> 6) & 0x1U));        /* bit6   ：电机使能 */

    /* 自检不过就地停机。 */
    if (rc != 0U) {
        printf("register write-back FAILED. check W channel / wstrb / shadow reg\r\n");
        StatFailLoop();
    }

    /* 走到这里说明"读"和"写"都通了。LED5 转常亮，作为永久标记。 */
    StatLed(1U);
#endif

#if (BRINGUP_STEP >= 3)
    /* ------------------------------------------------------------------
     * 步骤 3：配置参数、使能通道、跑呼吸灯
     *   car_Init() 内部顺序：motor(CH1/CH2) -> PWM(CH0) -> Servo -> USART
     *   CH0 放最后初始化，保证 CH0 的使能位不会被前面的步骤抹掉。
     * ------------------------------------------------------------------ */
    car_Init();

    /* 使能之后 STATUS 的 bit5..3 应从 0 变成 1（CH0 开），
     * 也就是整个寄存器读到 0x00000008。
     * 这一行是"使能到底有没有写进去"的直接证据。 */
    status = PWM_ReadStatus();
    printf("[3] after init STATUS = 0x%08X (en=%d)\r\n",
           (unsigned)status, (int)((status >> 3) & 0x7U));

    /* 频率验算，纯打印：
     *   f = 49.995 MHz / ((PSC+1) * (ARR+1)) = 49,995,000 / 10,000 = 4,999.5 Hz
     * 注意分母是 ARR+1 而不是 ARR —— 计数器从 0 数到 ARR，一共 ARR+1 个计数。
     * 写成 +1.0 是为了强制浮点运算，否则整数除法会把结果截成 4999。 */
    printf("    PWM0: PSC=%d ARR=%d -> %.1f Hz\r\n",
           (int)PWM_DEFAULT_PSC, (int)PWM_DEFAULT_ARR,
           49995000.0 / ((PWM_DEFAULT_PSC + 1.0) * (PWM_DEFAULT_ARR + 1.0)));

    /* 再回读一遍实际寄存器值 —— 整个程序里最强的一条证据。
     *   ARR 能读回 9999、CTRL 的 CH0 位是 1，就说明"PS 写进去的值真的落到了
     *   影子寄存器"，也就是 AXI 写通路端到端打通了。
     *   如果这里 ARR 读回 0 而步骤 2 的自检却过了，
     *   那问题范围就缩小到"PWM_Init 里那几笔写有没有生效"。 */
    ctrl = PWM_ReadReg(PWM_REG_CTRL);
    printf("    readback CTRL=0x%08X ARR=%d PSC=%d CCR=%d\r\n",
           (unsigned)ctrl,
           (int)PWM_ReadReg(PWM_REG_CH_ARR(PWM_CH0)),
           (int)PWM_ReadReg(PWM_REG_CH_PSC(PWM_CH0)),
           (int)PWM_ReadReg(PWM_REG_CH_CCR(PWM_CH0)));

    if ((ctrl & 0x1U) == 0U) {
        printf("!! CH0 enable bit is 0 -- breathing LED will NOT output\r\n");
        printf("!! check: who cleared CTRL after PWM_Init (motor_Init? DisableAll?)\r\n");
        StatFailLoop();
    }

    printf("    breathing on LED3 (J15), CH0 = %d\r\n", (int)PWM_CH0);
#endif

    /* ------------------------------------------------------------------
     * 主循环：呼吸灯 + 串口命令
     *
     * 呼吸灯：PWM_Breath() 是 for(;;) 死循环，会把主循环卡死，
     *         所以用非阻塞的 PWM_BreathTick()，按固定节拍推进。
     *
     * 串口：USART_POLL_ENABLE / USART_RX_ENABLE 本期都是 0，
     *       car_Loop() 里 USART_GetCmd 恒返回 0，空转无害。
     * ------------------------------------------------------------------ */
    while (1) {
#if (BRINGUP_STEP >= 3)
        PWM_BreathTick(PWM_CH0, PWM_DEFAULT_ARR, BREATH_STEP, BREATH_STEP_MS);
        car_Loop();     /* USART_GetCmd 在 RX 关闭时恒返回 0，空转无害 */
#endif
        AlSys_MDelay(MAIN_TICK_MS);
    }

    return 0;
}
