#include "al_axi_gpio_hw.h"
AlAxiGpio_HwConfigStruct AlAxiGpio_HwConfig[AL_AXI_GPIO_NUM_INSTANCE] = {
{
.DeviceId             = 0,
.BaseAddress          = 0x0,
.IntrId               = ~0UL,
},
{
.DeviceId             = 1,
.BaseAddress          = 0x100000,
.IntrId               = ~0UL,
}
};
