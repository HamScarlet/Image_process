/*==========================================================================
 * uart_probe.c —— UART1 波特率探针（细扫 + 自动修复）
 *
 * 【问题背景】
 *   串口全是乱码，但软件侧 10 项配置逐项实测全部正确：
 *     引脚复用 MIO48/49=FUNCSEL:UART1、LCR=0x03 (8N1)、
 *     CRG(0xF8801028)=8、IOPLL 已释放、CPU 取自 PLL、
 *     LSR=0x60（发送器空闲）、IER=0（轮询）、日志设备=UART1。
 *   而标准波特率 9600/19200/38400/57600 全试过，没有一档能读。
 *
 *   结论：配置没错，错的是"配置值 × 晶振"这一环 —— 实际 UART 输入时钟
 *         不是 soc_plat.h 假设的 49,995,000 Hz。
 *
 * 【2026-10-29 22:20 实测结果】
 *   宽扫 1..260 中唯一可读的一行是 `baud=446383]`。
 *   49995000 / 16 / 446383 = 7  ->  当时分频是 7。
 *   反推实际 UART 时钟 ≈ 16 × 7 × 115200 ≈ 12.9 MHz，
 *   而软件按 49.995 MHz 算出的分频是 27 —— 差了近 4 倍，正是乱码来源。
 *
 * 【2026-10-30 机理追查：找到 4 倍差的出处】
 *   0xF8801028 的寄存器名是 IO400_DIV8_PARA —— 它是 IO_400 的分频参数。
 *   同一块板上的官方例程 `3_2_01_sdk_base\08_ps_uart_intr` 写的是
 *     0xF8801028 = 0x01010101   (四字节全 1)，其 soc_plat.h 定义
 *     UART_CLOCK = 50 MHz ( = IO_400 / 8 )  —— 例程实测正常。
 *   本工程写的是
 *     0xF8801028 = 0x00000008   (只有最低字节 = 8)，其 soc_plat.h 却定义
 *     UART_CLOCK = 49.995 MHz ( = IO_400 / 8 )  —— 自相矛盾。
 *
 *   更硬的证据在同一个 soc_plat.h 里，两行相邻：
 *     #define GPIO_CLOCK   12500000      <-- IO_400 / 32
 *     #define UART_CLOCK   49995000      <-- IO_400 / 8
 *   两行都由同一个 IO400_DIV8_PARA 推导，值不可能互相矛盾。
 *   TD 用 12.5 MHz 算 GPIO，用 50 MHz 算 UART，说明这次 TD 生成的
 *   SoC 配置里 UART 那一项的分频参数填错了（填 8，正确应为 1）。
 *
 *   => 实际 UART 输入时钟 = 12.5 MHz，不是 49.995 MHz。差额正好 4 倍。
 *      12,500,000 / (16 x 7) = 111,607 ≈ 115200（误差 -3.1%，接收端仍可读）
 *      12,500,000 / (16 x 27) = 28,935  -> 乱码（与现场一致）
 *      分频 6 -> 130,208 (+13%)、分频 8 -> 97,656 (-15%)，都读不出来
 *      => 细扫里"只有 7 可用"被完整解释。
 *
 * 【2026-10-29 22:55 实测确认（CRG 候选扫描）】
 *   终端 115200、分频 27 下逐个改写 0xF8801028：
 *     C1 0x01010101  -> 三遍全干净，能读        => 这个值确实给出 50 MHz
 *     C2 0x00000001  \
 *     C3 0x00000100   |  全部乱码
 *     C4 0x00010000   |
 *     C5 0x01000000  /
 *   关键细节：只把某一个字节置 1 不行，四个字节必须同为 1 —— 这四个字节
 *   不是"一个外设一个分频"，而是同一组分频参数、按组生效。
 *   字段的准确语义待 CRG 手册确认，但修法已不依赖它：照抄官方值即可。
 *   => 修法：写 0x01010101 + 把分频恢复成驱动自己算的 27，
 *      115,729 baud、误差 +0.46%，余量从 6% 回到 99%。
 *
 * 【本模块现在承担的职责】
 *   1) 开机把 0xF8801028 改成 0x01010101（真 50 MHz），再把 UART 分频写成 27
 *      —— 这是正式修复，不是临时补丁；[B] 那行能读 = 串口已修好。
 *   2) 可选 [C] CRG 候选扫描（UART_PROBE_CRG_SCAN，已跑完，现为 0）
 *   3) 可选 [V] 验收扫描 24..30（UART_PROBE_VERIFY）
 *   4) 可选 [F] 细扫 4..14（UART_PROBE_SCAN，排障期用，现为 0）
 *
 *   注意：先改 CRG 再写分频，顺序不能反 —— 分频是按目标时钟算的，
 *   换了时钟不重写分频，就是本工程串口乱码的完整形态。
 *
 * 【原理】
 *   波特率 = UART输入时钟 / (16 × 分频系数)，分频系数为 16 位整数
 *   （DLL 低 8 位 + DLH 高 8 位）。直接穷举分频系数，不需要知道时钟真值，
 *   也不需要示波器 —— 接收端能读懂的那一档，编号就是正确分频。
 *
 * 【为什么自己写寄存器，不用 AlUart_Dev_SetBaudRate】
 *   驱动接口是 SetBaudRate(波特率, 假设时钟)，内部拿"假设的时钟"算分频。
 *   而我们恰恰在怀疑这个时钟，用它等于用错误的前提。
 *   直写 DLL/DLH 是唯一能绕开前提的办法，而且不依赖驱动是否初始化过。
 *========================================================================*/

#include "uart_probe.h"
#include "ui_io.h"

#if UART_PROBE_ON

/* ---------------------------------------------------------------------------
 * UART1 寄存器（基址 0xF8401000，32 位对齐，步长 0x04）
 * ------------------------------------------------------------------------- */
#define UART1_BASE          0xF8401000U
#define UART1_THR_DLL       (UART1_BASE + 0x00U)  /* 写=THR，DLAB=1 时=DLL */
#define UART1_IER_DLH       (UART1_BASE + 0x04U)  /* IER，DLAB=1 时=DLH   */
#define UART1_LCR           (UART1_BASE + 0x0CU)  /* 线路控制，bit7=DLAB  */
#define UART1_LSR           (UART1_BASE + 0x14U)  /* 线路状态             */

/* IO_400 的分频参数。名字来自 TD 生成的 soc_plat.c 注释：
 *   register: IO400_DIV8_PARA.io400_div8_para
 * 官方 UART 例程写 0x01010101（四字节各 1）-> UART 时钟 50 MHz；
 * 本工程写 0x00000008（仅最低字节 8）-> 实际约 12.5 MHz（见文件头说明）。 */
#define UART1_CRG_DIV8      0xF8801028U

#define LSR_THRE            0x20U  /* bit5：保持寄存器空，可塞下一个字节 */
#define LSR_TEMT            0x40U  /* bit6：发送器全空，连移位寄存器都空 */
#define LCR_8N1             0x03U  /* 8 位数据 + 1 停止 + 无校验         */
#define LCR_DLAB            0x80U  /* 置 1 时 0x00/0x04 变 DLL/DLH       */

/* 软件假设的 UART 输入时钟。只用来给每档标一个"名义波特率"做参考对照，
 * 它算得对不对不重要 —— 重要的是接收端能不能读懂标记。 */
#define UART_ASSUMED_HZ     49995000U

volatile u32 g_clk_dbg[8];

/* ---------------------------------------------------------------------------
 * 等发送器全空
 *   不加超时是故意的：裸机启动早期，一旦卡住说明 UART 根本没在工作，
 *   那本身就是结论，而不是需要容忍的偶发情况。
 * ------------------------------------------------------------------------- */
static void probe_wait_temt(void)
{
    while ((UI_In32((void *)UART1_LSR) & LSR_TEMT) == 0U) {
        /* 空转等待 */
    }
}

/* ---------------------------------------------------------------------------
 * 设置分频系数
 *
 *   顺序：存 IER -> 置 DLAB -> 写 DLL -> 写 DLH -> 清 DLAB -> 还原 IER
 *
 *   最后一步"还原 IER"不能省：DLH 和 IER 是同一个寄存器地址，
 *   分频系数 > 255 时 DLH 非 0，清掉 DLAB 后这些位就变成中断使能位，
 *   会打开一个本来没开的中断。所以先把原 IER 存下来，写完放回去。
 * ------------------------------------------------------------------------- */
static void probe_set_div(u32 div)
{
    u32 ier_save = UI_In32((void *)UART1_IER_DLH) & 0xFFU;  /* DLAB=0 时读到的才是 IER */

    UI_Out32((void *)UART1_LCR,     LCR_8N1 | LCR_DLAB);    /* 进入分频锁存模式 */
    UI_Out32((void *)UART1_THR_DLL, (div & 0xFFU));         /* DLL = 低 8 位      */
    UI_Out32((void *)UART1_IER_DLH, ((div >> 8) & 0xFFU));  /* DLH = 高 8 位      */
    UI_Out32((void *)UART1_LCR,     LCR_8N1);               /* 回到正常模式       */
    UI_Out32((void *)UART1_IER_DLH, ier_save);              /* 还原 IER           */
}

/* 发一个字节：等保持寄存器空 -> 写 THR */
static void probe_putc(char c)
{
    while ((UI_In32((void *)UART1_LSR) & LSR_THRE) == 0U) {
        /* 空转等待 */
    }
    UI_Out32((void *)UART1_THR_DLL, (u32)(unsigned char)c);
}

static void probe_puts(const char *s)
{
    while (*s != '\0') {
        probe_putc(*s++);
    }
}

/* 十进制输出。不用 printf：printf 走驱动，而驱动此刻的分频认知是错的。
 * 这里发的都是纯 ASCII，只要接收端速率对上就能正常显示。 */
static void probe_putu(u32 v)
{
    char buf[12];
    int  i = 0;

    if (v == 0U) {
        probe_putc('0');
        return;
    }
    while (v != 0U) {
        buf[i++] = (char)('0' + (v % 10U));
        v /= 10U;
    }
    while (i > 0) {
        probe_putc(buf[--i]);
    }
}

/* 十六进制输出（8 位）。扫描时把 CRG 候选值原样打出来，方便逐行对照。 */
static void probe_puthex32(u32 v)
{
    int i;

    for (i = 28; i >= 0; i -= 4) {
        u32 n = (v >> (u32)i) & 0xFU;
        probe_putc((char)((n < 10U) ? ('0' + n) : ('A' + (n - 10U))));
    }
}

/* 改写 IO_400 分频参数，并等新时钟稳定。
 * 等待是必须的：分频参数一变，PLL 下游要重新同步，紧接着写的 UART 分频
 * 有可能落在一个还没稳定的时钟域里而被丢掉。 */
static void probe_set_crg(u32 v)
{
    volatile u32 wait;

    UI_Out32((void *)UART1_CRG_DIV8, v);
    for (wait = 0U; wait < 2000000U; wait++) {
        /* 空转约 10 ms（CPU 主频不受这个寄存器影响，所以耗时稳定） */
    }
}

/* 每档标记，重复 reps 遍。
 * 重复的意义：换分频的瞬间，第一个字节可能被拉长/截断而变成乱码，
 * 但后面的字节一定干净。所以只要"其中任一遍"能完整读出，就说明这一档对。 */
#if UART_PROBE_SCAN
static void probe_marker(u32 div, u32 reps)
{
    u32 i;

    for (i = 0U; i < reps; i++) {
        probe_puts("\r\n[DIV=");
        probe_putu(div);
        probe_puts("]\r\n");
    }
}
#endif

/* ---------------------------------------------------------------------------
 * 抓取 CRG 时钟寄存器
 *   调试器经 DAP 直读 0xF8801000 区域会显示 ????????（访问被拒），
 *   但 CPU 在安全态下读得到，所以由 CPU 代读后放到普通 RAM，
 *   之后在 Watch 窗口看 g_clk_dbg[0..7]。
 * ------------------------------------------------------------------------- */
void UartProbe_DumpClocks(void)
{
    g_clk_dbg[0] = UI_In32((void *)0xF8801028U);  /* UART 分频，实测 0x08      */
    g_clk_dbg[1] = UI_In32((void *)0xF880103CU);  /* fclk 分频，实测 0x…0307   */
    g_clk_dbg[2] = UI_In32((void *)0xF8801204U);  /* IOPLL 释放，实测 bit9=0   */
    g_clk_dbg[3] = UI_In32((void *)0xF8801280U);  /* IOPLL 锁定，期望 bit0=1   */
    g_clk_dbg[4] = UI_In32((void *)0xF8801180U);  /* CPUPLL 锁定，期望 bit0=1  */
    g_clk_dbg[5] = UI_In32((void *)0xF8801040U);  /* CLK_SEL，实测 bit4=0      */
    g_clk_dbg[6] = UI_In32((void *)UART1_LCR);    /* 期望 0x03 = 8N1           */
    g_clk_dbg[7] = 0xA5A5A5A5U;                   /* 哨兵：确认这段真执行了    */
}

/* ---------------------------------------------------------------------------
 * CRG 候选值扫描 —— 定机理的那一个实验
 *
 *   待验证的假设：实际 UART 时钟是 12.5 MHz，而不是头文件写的 49.995 MHz；
 *                 根因是 IO400_DIV8_PARA 写成了 8（官方例程写 1）。
 *
 *   测法（接收端完全不动，终端固定 115200）：
 *     逐个改写 IO400_DIV8_PARA，每写一次就把 UART 分频设成 27 再打标记。
 *       分频 27 + 50 MHz  -> 115,740 baud -> 终端能读
 *       分频 27 + 12.5 MHz -> 28,935 baud  -> 乱码
 *     哪一行的标记读得出来，那一行的 CRG 值就真的给出了 50 MHz。
 *
 *   为什么要试 5 个值而不是 1 个：
 *     官方值 0x01010101 是"四字节全 1"。若寄存器真的按字节分槽给 4 个
 *     外设用，那 UART1 未必在 byte0。单试 0x01010101 只能证明"能通"，
 *     试完 5 个才能顺带确定 UART1 占哪个字节 —— 以后写别的外设要用。
 * ------------------------------------------------------------------------- */
void UartProbe_CrgScan(void)
{
    static const u32 cands[] = {
        0x01010101U,   /* C1 官方 UART 例程值：四字节全 1                 */
        0x00000001U,   /* C2 只有 byte0 = 1                               */
        0x00000100U,   /* C3 只有 byte1 = 1（UART1 若按字节分槽应命中这条）*/
        0x00010000U,   /* C4 只有 byte2 = 1                               */
        0x01000000U    /* C5 只有 byte3 = 1                               */
    };
    u32 i;

    for (i = 0U; i < (u32)(sizeof(cands) / sizeof(cands[0])); i++) {
        u32 rep;

        probe_set_crg(cands[i]);
        probe_wait_temt();
        probe_set_div(27U);          /* 按"50 MHz + 115200"算出的分频 */

        for (rep = 0U; rep < 3U; rep++) {
            probe_puts("\r\n##C");
            probe_putc((char)('1' + (int)i));
            probe_puts(" CRG=");
            probe_puthex32(cands[i]);
            probe_puts(" DIV=27 ABCDEFGH ##\r\n");
        }
    }
}


/* ---------------------------------------------------------------------------
 * 主流程
 *
 *   [A] 对照组：按软件算出的 27 发一行
 *         -> 这行能读 = 波特率本来就是对的，问题在别处
 *   [F] 细扫 4..14，每档重复 6 遍
 *         -> 哪档能读，那档编号就是正确分频
 *   [W] 可选：1..260 全扫（仅当细扫全灭时打开 UART_PROBE_WIDE）
 *   [B] 应用最终配置（CRG_FINAL + FINAL_DIV）并打一行自证
 *         -> 这行能读 = 串口已修好，后面 main 的 printf 全部正常
 * ------------------------------------------------------------------------- */
void UartProbe_Sweep(void)
{
    u32 div;
    u32 crg_before;

    UartProbe_DumpClocks();

#if UART_PROBE_SCAN
    /* ---- [A] 对照组 ---- */
    probe_wait_temt();
    probe_set_div(27U);
    probe_puts("\r\n\r\n===[A] DIV=27 CONTROL===\r\n");
    probe_puts("===[A] IF THIS READS, BAUD WAS ALREADY OK===\r\n");

    /* ---- [F] 细扫 ---- */
    probe_puts("\r\n##### FINE SCAN 4..14 x6 #####\r\n");
    for (div = UART_PROBE_FINE_MIN; div <= UART_PROBE_FINE_MAX; div++) {
        probe_wait_temt();          /* 等上一档发干净，避免边界残字节 */
        probe_set_div(div);         /* 切到本档速率                   */
        probe_marker(div, UART_PROBE_REPS);
    }

#if UART_PROBE_WIDE
    /* ---- [W] 宽扫（排障用） ---- */
    probe_puts("\r\n##### WIDE SCAN 1..260 #####\r\n");
    for (div = 1U; div <= 260U; div++) {
        probe_wait_temt();
        probe_set_div(div);
        probe_puts("\r\n[DIV=");
        probe_putu(div);
        probe_puts(" baud=");
        probe_putu(UART_ASSUMED_HZ / 16U / div);
        probe_puts("]\r\n");
    }
#endif
#else
    /* 正式运行态：不扫描，只修正。
     * div 参数在 scanning 关闭时用不到，这里吃掉是为了避免 unused 告警。 */
    (void)div;
#endif

#if UART_PROBE_CRG_SCAN
    /* ---- [C] CRG 候选扫描（已完成定案，正式态关闭） ---- */
    probe_puts("\r\n##### CRG SCAN: 5 CANDIDATES @ DIV=27 #####\r\n");
    probe_puts("##### only the line whose CRG really is 50MHz will read #####\r\n");
    UartProbe_CrgScan();
#endif

    /* ---- [B] 应用最终配置并自证 ----
     * 顺序必须是"先改 CRG，再写分频"：分频是按目标时钟算出来的，
     * 换了时钟不重写分频，等于用旧尺子量新布 —— 这正是本工程串口
     * 乱码的完整形态（时钟 12.5 MHz，分频却按 50 MHz 算成 27）。
     *
     * crg_before 是"上游刚写进去的值"快照，必须在本函数改它之前取。
     * 它只在改完之后才打印 —— 改之前串口还是坏的，那时打印出来也是乱码。 */
    crg_before = UI_In32((void *)UART1_CRG_DIV8);

    probe_set_crg(UART_PROBE_CRG_FINAL);
    probe_wait_temt();
    probe_set_div(UART_PROBE_FINAL_DIV);
    probe_puts("\r\n\r\n===[B] CRG=");
    probe_puthex32(UART_PROBE_CRG_FINAL);
    probe_puts(" DIV=");
    probe_putu(UART_PROBE_FINAL_DIV);
    probe_puts(" APPLIED===\r\n");
    probe_puts("===[B] IF THIS READS, CONSOLE IS FIXED===\r\n");

    /* 上游（fsbl.elf 的 Soc_PlatInit 或 FD 跑的平台脚本）刚写进去的值。
     *   01010101 = 上游配置正常，本次覆盖只是保险；
     *   00000008 = soc_plat.c / soc_plat.tcl 又被生成回错误值了，
     *              说明"上游污染"复发 —— 这一行就是复发的报警线。 */
    probe_puts("===[B] UPSTREAM WROTE=");
    probe_puthex32(crg_before);
    probe_puts(" (EXPECT 01010101)===\r\n\r\n");

#if UART_PROBE_VERIFY
    /* ---- [V] 验收：正确时钟下扫 24..30，可读带应"以 27 为中心" ----
     * 50 MHz  : 27 -> 115,730 (+0.46%)；26 -> 120,192 (+4.3%)、28 -> 111,607
     *           (-3.1%) 落在接收容限边缘，可能勉强可读；25/29 已超限。
     * 12.5 MHz: 这一整段全是乱码。
     * 所以"27 附近出现可读带"才算真修好，单看 [B] 一行有碰巧的可能。 */
    probe_puts("##### VERIFY 24..30 (readable band should centre on 27) #####\r\n");
    for (div = 24U; div <= 30U; div++) {
        probe_wait_temt();
        probe_set_div(div);
        probe_puts("\r\n[V");
        probe_putu(div);
        probe_puts("]\r\n");
    }
    probe_wait_temt();
    probe_set_div(UART_PROBE_FINAL_DIV);
    probe_puts("\r\n##### VERIFY DONE, BACK TO DIV=");
    probe_putu(UART_PROBE_FINAL_DIV);
    probe_puts(" #####\r\n");
#endif
}

/* ---------------------------------------------------------------------------
 * 自动执行
 *   __attribute__((constructor)) 把函数指针放进 .init_array，
 *   启动链在 main 之前调用 __libc_init_array 时自动执行。
 *   => 一行现有代码都不用改。
 *
 *   前提：Platform Init 已经把 CRG 配好（实测 0xF8801028=8，成立）；
 *         本函数自己会设 LCR，所以不依赖 AlLog_Init 有没有跑。
 * ------------------------------------------------------------------------- */
__attribute__((constructor))
static void uart_probe_autorun(void)
{
    UartProbe_Sweep();
}

#endif /* UART_PROBE_ON */
