#include "al_axi_gpio_hw.h"
AlAxiGpio_HwConfigStruct AlAxiGpio_HwConfig[AL_AXI_GPIO_NUM_INSTANCE] = {
{
.DeviceId             = 0,
.BaseAddress          = 0x80000000,
.IntrId               = 114,
},
{
.DeviceId             = 1,
.BaseAddress          = 0x80100000,
.IntrId               = 0xFFFFFFFF,
}
};
