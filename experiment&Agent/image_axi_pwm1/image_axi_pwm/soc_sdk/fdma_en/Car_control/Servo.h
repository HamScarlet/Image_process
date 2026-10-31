/*
 * Servo.h - 舵机接口（当前阶段不占用 PWM 通道，见 Servo.c 说明）
 */

#ifndef SERVO_H_
#define SERVO_H_

#include <stdint.h>

void Servo_Init(void);

/* angle: 0..180 度 */
void Servo_SetAngle(uint8_t angle);

#endif /* SERVO_H_ */
