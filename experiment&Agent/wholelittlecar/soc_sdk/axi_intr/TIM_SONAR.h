/*
 * TIM_SONAR.h - PS 侧驱动：HC-SR04 超声测距 + 15 cm 距离门控
 *
 * ============================================================================
 * 【PL 侧做了什么，PS 侧只做什么】
 *
 *   PL（axi_lite_pwm.v 内的 axi_lite_sonar / axi_lite_guard）：
 *     - 每 60 ms 自动发一次 TRIG（12 µs），量 ECHO 高电平的时钟拍数
 *     - 拿拍数跟 GUARD_CFG 的两个阈值比，小于"进入阈值"就锁存拦停
 *     - 拦停时**直接把 pwm_out[0]/[1] 截断**，不等 PS
 *
 *   PS（本文件）：
 *     - 读 SONAR_TICKS 换算成 cm，打印给人看
 *     - 读 GUARD_ST 看当前拦没拦、有没有测到过、方向对不对
 *     - 改阈值（一般不需要，默认 15/17 cm 已写在 RTL 复位值里）
 *
 *   ★ 为什么换算放在 PS：PL 侧硬门只需要 `ticks < 43500` 这种整数比较，
 *     做除法要占一个除法器（约 200 LUT）且没必要。cm 只有打印时用得上。
 *
 * ============================================================================
 * 【单位换算】（f_clk = 50.0 MHz，V1 实测，不是代码里写的 49.995）
 *
 *   1 拍        = 20 ns
 *   1 cm 往返   = 2 × 1 cm / 34000 cm/s = 58.8 µs = 2941 拍
 *   本工程取 2900（对应 344.8 m/s，约 22 °C）
 *
 *   量程        拍数
 *   15 cm       43500    ← 进入阈值（默认）
 *   17 cm       49300    ← 退出阈值（默认，迟滞用）
 *   100 cm      290000
 *   400 cm      1160000  ← HC-SR04 上限，PL 侧超时设 1500000
 *
 *   ⚠️ GUARD_CFG 的两个阈值字段各 16 位，上限 65535 拍 ≈ 22.6 cm。
 *      想把阈值调到 22 cm 以上必须改 RTL 位宽，光改这个头文件没用。
 *
 * ============================================================================
 * 【迟滞为什么必须有】
 *   单阈值时车停在 15.0 cm 附近，超声读数抖 1~2 cm 就会让门控反复翻转，
 *   PWM 变成断续输出 —— 听起来像电机打嗝，还会加速驱动管发热。
 *   进 15 出 17 把抖动挡在中间地带（中间地带保持原状态）。
 * ============================================================================
 */

#ifndef TIM_SONAR_H
#define TIM_SONAR_H

#include "ui_type.h"

/* ---------------- 寄存器偏移（相对 AXI_PWM_BASE = 0x80200000） ---------------- */
#define SONAR_REG_TICKS     0x50U   /* RO  ECHO 高电平拍数                  */
#define SONAR_REG_CFG       0x54U   /* RW  [15:0]周期ms [16]软触发 [17]使能 */
#define SONAR_REG_GUARD_CFG 0x58U   /* RW  [15:0]进入阈值 [31:16]退出阈值    */
#define SONAR_REG_GUARD_ST  0x5CU   /* RO  状态位                            */
#define SONAR_REG_GUARD_CNT 0x6CU   /* RO  累计拦停次数                      */

/* ---------------- SONAR_CFG 位 ---------------- */
#define SONAR_CFG_EN        (1U << 17)
#define SONAR_CFG_TRIG      (1U << 16)   /* 写 1 立刻测一轮，硬件自清 */
#define SONAR_CFG_CLR       (1U << 18)   /* 写 1 清门控锁存，硬件自清 */
#define SONAR_CFG_PERIOD(n) ((u32)(n) & 0xFFFFU)

/* ---------------- GUARD_ST 位 ---------------- */
#define GUARD_ST_HIT        (1U << 0)    /* 当前正在拦（= latched 且方向 0x5） */
#define GUARD_ST_LATCHED    (1U << 1)    /* 距离锁存（还在 17 cm 以内）        */
#define GUARD_ST_EVER       (1U << 2)    /* 上电后测到过至少一次有效距离       */
#define GUARD_ST_DIR_FWD    (1U << 3)    /* 方向自检：GPIO_1 == 0x5            */
#define GUARD_ST_TIMEOUT    (1U << 4)    /* 上一轮超时（模块没接 / 线断了）    */
#define GUARD_ST_BUSY       (1U << 5)    /* 正在测距                           */

/* ---------------- 换算常量 ---------------- */
#define SONAR_TICKS_PER_CM  2900U

/* 默认阈值。与 axi_lite_pwm.v 的 RESET_GUARD_CFG = 32'hC094_A9EC 一致 */
#define GUARD_ENTER_CM      15U
#define GUARD_EXIT_CM       17U
#define GUARD_ENTER_TICKS   43500U
#define GUARD_EXIT_TICKS    49300U

/* GUARD_CFG 的复位指纹，Sonar_SelfTest() 拿它判断 RTL 是不是新的 */
#define GUARD_CFG_RESET     ((GUARD_EXIT_TICKS << 16) | GUARD_ENTER_TICKS)

/* ---------------- API ---------------- */

/* 初始化：打开自动测距（60 ms 一轮），把阈值写回默认值，打印量程表。
 * ⚠️ 会覆盖 GUARD_CFG，如果之前用 Sonar_SetGuardCm() 改过，要重新设。 */
void Sonar_Init(void);

/* 最近一次的原始拍数（未换算） */
u32  Sonar_ReadTicks(void);

/* 最近一次的距离，单位 cm（ticks / 2900）。测距失败时返回上一次的有效值 */
u32  Sonar_ReadCm(void);

/* GUARD_ST 快照 */
u32  Sonar_ReadState(void);

/* 累计拦停次数 */
u32  Sonar_ReadGuardCnt(void);

/* 改门控阈值（cm）。
 * ⚠️ 上限 22 cm —— 阈值字段只有 16 位，65535 / 2900 = 22.6。
 *    超限会被夹到 22 并打印一行提示。 */
void Sonar_SetGuardCm(u32 enter_cm, u32 exit_cm);

/* 软触发一轮测距（不等待，结果下一轮轮询时才能读到） */
void Sonar_SoftTrigger(void);

/* ★ 强制解除门控锁存（现场救命用）
 *
 *   什么时候需要：
 *     超声线松了 / 模块进水 / ECHO 线断了 —— 这时 sonar_valid 不再更新，
 *     guard 的 latched 会永远保持最后一次"近"（<15 cm）的状态，
 *     车就再也前进不了。现象是"发 0x01 车轮一动不动，但 guard 状态行
 *     一直显示 latch=Y，而且 d= 那个数不再变化"。
 *
 *   清完之后：
 *     - 如果超声已修好，下一轮读数会立刻重新判定（<15 cm 还是会拦）
 *     - 如果超声还是坏的，latched 会一直是 0 —— 也就是说**门控失效**了。
 *       这时候要么修线，要么别再让车往障碍物开。
 *
 *   ⚠️ 这不是"复位"，不会影响方向 / 占空比 / 超声使能。 */
void Sonar_ClearGuard(void);

/* 只读自检：返回 0 = 通过；1 = GUARD_CFG 复位值与 RTL 不符（位流不是 V8 的） */
u32  Sonar_SelfTest(void);

#endif /* TIM_SONAR_H */
