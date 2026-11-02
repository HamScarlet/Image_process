/*
 * Car_control.h
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */

#ifndef CAR_CONTROL_H_
#define CAR_CONTROL_H_

#include <stdint.h>

typedef struct {
    uint8_t direct;     // 0: forward   1: backward     2: left     3: right        4: stop
    int8_t speed;      // Signed motor speed
}COMMAND;

void Process_Cmd(COMMAND cmd);
void car_init(void);
void car_loop(void);

#endif /* CAR_CONTROL_H_ */
