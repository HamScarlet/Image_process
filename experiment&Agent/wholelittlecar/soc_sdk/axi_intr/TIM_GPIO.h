/*
 * TIM_GPIO.h - PS 侧驱动：AXI4-Lite GPIO 通道（PL 侧 AXI_GPIO_1 实例）
 *
 * 本文件只做两件事：
 *   1. 把 AXI_GPIO_1 的 TRI / DATA 两个寄存器封装出来
 *   2. 把 TB6612 的四种状态（滑行 / 正转 / 反转 / 刹停）编码成 4 位数据
 *
 * ---------------- 基址来源（权威） ----------------
 * soc_base/dr1m90_fpsoc_cpu0/driver/pl_driver/axi_gpio/src/al_axi_gpio_cfg.c
 *     AlAxiGpio_HwConfig[] = {
 *         { DeviceId = 0, BaseAddress = 0x80000000, IntrId = 114 },   // AXI_GPIO_0 -> 顶层 GPIO
 *         { DeviceId = 1, BaseAddress = 0x80100000, IntrId = 115 },   // AXI_GPIO_1 -> 顶层 GPIO_1
 *     };
 * 与 Design.xml 的 DS1_BASEADDR0 = 0x80100000 / 上界 0x80100fff 一致。
 *
 * ---------------- 寄存器来源（权威） ----------------
 * driver/pl_driver/axi_gpio/inc/al_axi_gpio_hw.h：
 *     AL_AXI_GPIO_DATA  0x00
 *     AL_AXI_GPIO_TRI   0x04      // 1 = 输入（高阻），0 = 输出
 *     AL_AXI_GPIO_DATA2 0x08      // 本工程只用通道 1
 *     AL_AXI_GPIO_TRI2  0x0c
 *
 * ---------------- ★ 端口模式：All Outputs（2026-10-31 定） ----------------
 * DI 里本实例选的是 **All Outputs**（AL_ALL_OUT_PORTS = 1），不是双向。
 * 影响（都由 ip/system_AXI_GPIO_1/.params 与 .ports 坐实）：
 *   - IP 端口是 output [3:0] gpio_io_o，gpio_io_i / gpio_io_t 都是 0（未引出）；
 *   - AL_RESET_TRI = 0 ⇒ 复位后就是全输出，**不存在"上电高阻写不出去"的坑**；
 *   - TRI_DEFAULT 参数在 DI 里已被置灰（Dis），TRI 寄存器综合时很可能被裁掉。
 * ⇒ 驱动不依赖 TRI：判据全部建立在 DATA 回读上，TRI 清理只作兼容兜底。
 *
 * ⚠️ 副作用：本片 AXI GPIO 不能再读引脚。后续若要读按键/限位，走 PS MIO
 *    （KEY1 = K19 / KEY2 = J19）或另开一片双向 AXI GPIO。
 *
 * ---------------- 位宽 ----------------
 * AL_GPIO_WD 已由 1 改为 4，IP 顶层端口为 output [3:0] gpio_io_o。
 * Gpio1_SelfTest() 第 1 步兼作位宽探针：位宽若仍是 1，写 0xF 只会回读 0x1。
 * 本驱动只操作低 4 位，高位写法与读回行为不作假设。
 */

#ifndef TIM_GPIO_H
#define TIM_GPIO_H

#include "ui_type.h"

/* ---------------- 基址 ---------------- */
#define AXI_GPIO1_BASE          0x80100000U

/* ---------------- 寄存器偏移 ---------------- */
#define GPIO1_REG_DATA          0x00U
#define GPIO1_REG_TRI           0x04U   /* All Outputs 模式下可能已被综合裁掉，仅作兜底 */
#define GPIO1_REG_DATA2         0x08U
#define GPIO1_REG_TRI2          0x0CU

/* ---------------- 有效位宽 ---------------- */
#define GPIO1_WIDTH             4U
#define GPIO1_MASK              0x0FU

/* ---------------- TB6612 状态编码 ----------------
 * 位序：bit0 = AIN1  bit1 = AIN2  bit2 = BIN1  bit3 = BIN2
 * 两路同向：AIN1/AIN2 与 BIN1/BIN2 取相同逻辑电平
 */
#define MOTOR_DIR_COAST         0x0U    /* 0000  全低   -> 滑行（输出高阻）   */
#define MOTOR_DIR_FWD           0x5U    /* 0101  AIN1=BIN1=1 -> 两轮正转      */
#define MOTOR_DIR_REV           0xAU    /* 1010  AIN2=BIN2=1 -> 两轮反转      */
#define MOTOR_DIR_BRAKE         0xFU    /* 1111  全高   -> 短接制动（刹停）   */

/* ---------------- API ---------------- */

/* 读 TRI 寄存器（仅调试用）。All Outputs 模式下该寄存器可能已被综合裁掉，
 * 读回值无意义，不要拿它做判据 */
u32  Gpio1_ReadTri(void);

/* 写 TRI 寄存器，只写低 4 位；1 = 输入，0 = 输出。仅作兼容兜底 */
void Gpio1_WriteTri(u32 tri);

/* 读 DATA 寄存器（回读 gpio_data，即软件写进去的值） */
u32  Gpio1_ReadData(void);

/* 写 DATA 寄存器，只写低 4 位。All Outputs 模式下写完立即出现在引脚上 */
void Gpio1_WriteData(u32 val);

/* 寄存器读写自检。返回 0 = 通过；返回 n = 第 n 步失败
 *   1 = 写 DATA=0xF 后读回低 4 位不是 0xF  (★ 位宽仍是 1 时会在这里失败)
 *   2 = 写 DATA=0x3 后读回低 4 位不是 0x3
 *   3 = 写 DATA=0xC 后读回低 4 位不是 0xC
 * 图案全程不驱动电机（0xF/0x3/0xC 都只产生短路制动或滑行）。
 */
u32  Gpio1_SelfTest(void);

/* 电机方向初始化：DATA 先置滑行，再清 TRI（兼容兜底）。上电后第一件事就调它 */
void Motor_Init(void);

/* 设置方向。nibble 取 MOTOR_DIR_* 之一，只写低 4 位 */
void Motor_SetDir(u32 nibble);

/* ============================================================================
 * 差速驱动（V5 起）
 *
 *   A 侧 = 左轮：PWM = pwm_out[0] (V6) · AIN1 = U9 · AIN2 = U8
 *   B 侧 = 右轮：PWM = pwm_out[1] (U7) · BIN1 = V11 · BIN2 = V10
 *
 * ★ B_SIDE_INVERT —— 本文件唯一一个"需要实测后才定"的参数
 *   左右电机在车上常是镜像安装（尤其带减速箱的 TT 电机，对称装配后输出轴
 *   转向相反）。此时同一个"前进"位会让右轮倒退。
 *   V5 标定段会让 B 侧单独转一次：若右轮朝后，把这里改成 1，不用改接线、
 *   也不用改任何其它代码。
 *   0 = 左右同向（默认，与 V4 单电机时的接法一致）
 *   1 = B 侧反向
 * ========================================================================== */
#define B_SIDE_INVERT   0

#define A_FWD_BIT       0x1U    /* AIN1 高 = 左轮前进 */
#define A_REV_BIT       0x2U    /* AIN2 高 = 左轮后退 */
#define B_FWD_BIT       ((B_SIDE_INVERT) ? 0x8U : 0x4U)
#define B_REV_BIT       ((B_SIDE_INVERT) ? 0x4U : 0x8U)

/* 组合两路方向：a_fwd / b_fwd 取 1 = 前进、0 = 后退
 *   直行        = DIR_BOTH(1, 1)      -> 0x5（与 MOTOR_DIR_FWD 相同）
 *   双退        = DIR_BOTH(0, 0)      -> 0xA（与 MOTOR_DIR_REV 相同）
 *   原地左转    = DIR_BOTH(0, 1)      左退右进
 *   原地右转    = DIR_BOTH(1, 0)      左进右退
 */
#define DIR_BOTH(af, bf)  ( ((af) ? A_FWD_BIT : A_REV_BIT) | \
                            ((bf) ? B_FWD_BIT : B_REV_BIT) )

/* 单侧单独驱动（V5 标定段用）：只给一侧方向位，另一侧两位全 0 = 滑行。
 * 注意"另一侧全 0"是滑行不是刹停 —— 标定时另一侧轮子会被带着空转，
 * 这是正常的，不需要用手按。 */
#define DIR_A_ONLY_FWD   A_FWD_BIT
#define DIR_A_ONLY_REV   A_REV_BIT
#define DIR_B_ONLY_FWD   B_FWD_BIT
#define DIR_B_ONLY_REV   B_REV_BIT

#endif /* TIM_GPIO_H */
