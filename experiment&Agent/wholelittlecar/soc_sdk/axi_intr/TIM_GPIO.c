/*
 * TIM_GPIO.c - PS 侧驱动：AXI_GPIO_1（4 位）-> TB6612 方向控制
 *
 * 基址 0x80100000：来自 al_axi_gpio_cfg.c 的 AlAxiGpio_HwConfig[1]（DeviceId = 1）。
 * 寄存器偏移：DATA 0x00 / TRI 0x04，与 al_axi_gpio_hw.h 一致。
 * 这里不用官方 al_axi_gpio_hal，原因有二：
 *   1. 官方 HAL 依赖 AL_AXI_GPIO_NUM_INSTANCE 宏和 AlAxiGpio_HwConfig 表，
 *      多一层实例查找，对"单实例、只写两个寄存器"的场景没有收益；
 *   2. TIM_PWM.c 已经是裸寄存器写法，保持同一风格便于对照排障。
 * 基址与偏移仍以官方 cfg/hw 头文件为准，改板时只改宏。
 */

#include "al_core.h"
#include "ui_io.h"
#include "TIM_GPIO.h"

#define GPIO1_WR(off, val)  UI_Out32((void *)(AXI_GPIO1_BASE + (u32)(off)), (u32)(val))
#define GPIO1_RD(off)       UI_In32((void *)(AXI_GPIO1_BASE + (u32)(off)))

u32 Gpio1_ReadTri(void)
{
    return GPIO1_RD(GPIO1_REG_TRI);
}

void Gpio1_WriteTri(u32 tri)
{
    GPIO1_WR(GPIO1_REG_TRI, tri & GPIO1_MASK);
}

u32 Gpio1_ReadData(void)
{
    return GPIO1_RD(GPIO1_REG_DATA);
}

void Gpio1_WriteData(u32 val)
{
    GPIO1_WR(GPIO1_REG_DATA, val & GPIO1_MASK);
}

u32 Gpio1_SelfTest(void)
{
    /* 判据不建立在 TRI 上。
     * 原因：DI 里本实例选的是 All Outputs（AL_ALL_OUT_PORTS = 1），
     * IP 包装层没有引出 gpio_io_t（.ports 里 gpio_io_t; 0），
     * 综合时 TRI 寄存器很可能整块被裁掉 ⇒ 读回值不可信。
     * 输出方向由 IP 自己保证（AL_RESET_TRI = 0），不需要软件干预。
     *
     * 图案选取原则：★ 全程不让电机转。
     *   0xF = AIN1/AIN2/BIN1/BIN2 全高 -> 两侧短路制动，静止
     *   0x3 = AIN1/AIN2 高（A 侧制动），BIN1/BIN2 低（B 侧滑行），静止
     *   0xC = BIN1/BIN2 高（B 侧制动），AIN1/AIN2 低（A 侧滑行），静止
     *   0x0 = 全低 -> 两侧滑行，静止
     * 这三个图案两两不同，任一位坏掉都会被抓到。
     */

    /* 第 1 步：全 4 位高。★ 位宽仍是 1 时这里只会回读到 0x1，直接返回 1 */
    Gpio1_WriteData(GPIO1_MASK);
    if ((Gpio1_ReadData() & GPIO1_MASK) != GPIO1_MASK) {
        return 1U;
    }

    /* 第 2 步：只 A 侧高（bit0/bit1），验证低两位 */
    Gpio1_WriteData(0x3U);
    if ((Gpio1_ReadData() & GPIO1_MASK) != 0x3U) {
        return 2U;
    }

    /* 第 3 步：只 B 侧高（bit2/bit3），验证高两位 */
    Gpio1_WriteData(0xCU);
    if ((Gpio1_ReadData() & GPIO1_MASK) != 0xCU) {
        return 3U;
    }

    /* 收尾：滑行 */
    Gpio1_WriteData(MOTOR_DIR_COAST);

    return 0U;
}

void Motor_Init(void)
{
    /* All Outputs 模式下 IP 的 AL_RESET_TRI = 0，复位即全输出，理论上一上电就能写。
     * 这里仍先写一次 TRI = 0，作为兼容兜底：
     *   - 若 TRI 寄存器被综合保留 -> 明确清成输出，无害；
     *   - 若已被裁掉 -> 该写落到保留地址，同样无害。
     * 顺序仍坚持"先 DATA=滑行，再清 TRI"：万一 TRI 真的在工作，
     * 切换输出的那一瞬间引脚上已经是滑行电平，不会窜一下。 */
    Gpio1_WriteData(MOTOR_DIR_COAST);
    Gpio1_WriteTri(0x0U);
}

void Motor_SetDir(u32 nibble)
{
    Gpio1_WriteData(nibble & GPIO1_MASK);
}
