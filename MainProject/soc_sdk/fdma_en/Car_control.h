/*
 * Car_control.h
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */

#ifndef CAR_CONTROL_H_
#define CAR_CONTROL_H_

typedef struct {
    uint8_t direct;     // 0: forward   1: backward     2: left     3: right        4: stop
    int8_t speed       // 
}COMMAND;

void Process_Cmd(COMMAND cmd);


#endif /* CAR_CONTROL_H_ */
