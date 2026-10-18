

#ifndef UI_IO_H           /* prevent circular inclusions */
#define UI_IO_H           /* by using protection macros */



#ifdef __cplusplus
extern "C" {
#endif

#include "ui_type.h"
#include <stdint.h>
static inline u8 UI_In8(void* Addr)
{
	return *(volatile u8 *) Addr;
}

static inline u16 UI_In16(void* Addr)
{
	return *(volatile u16 *) Addr;
}

static inline u32 UI_In32(void* Addr)
{
	return *(volatile u32 *) Addr;
}


static inline void UI_Out8(void* Addr, u8 Value)
{
	volatile u8 *LocalAddr = (volatile u8 *)Addr;
	*LocalAddr = Value;
}

static inline void UI_Out16(void* Addr, u16 Value)
{
	volatile u16 *LocalAddr = (volatile u16 *)Addr;
	*LocalAddr = Value;
}


static inline void UI_Out32(void* Addr, u32 Value)
{
	volatile u32 *LocalAddr = (volatile u32 *)Addr;
	*LocalAddr = Value;
}


#endif /* end of protection macro */
