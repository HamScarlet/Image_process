#include "Image.h"
#include "ui_io.h"
#include "al_printf.h"
#include <stdlib.h>

static inline void *Image_Reg(uintptr_t address)
{
    return (void *)address;
}

IMAGE_INFO* Image_init(void)
{
    IMAGE_INFO* info = (IMAGE_INFO*)malloc(sizeof(IMAGE_INFO));
    info->cdc_overrun = 0;
    info->center_offset = 0;
    info->confidence = 0;
    info->curve_class = 0;
    info->frame_count = 0;
    info->frame_pending = 0;
    info->lane_valid = 0;
    info->left_x = 0;
    info->result_valid = 0;
    info->right_x = 0;
    info->snapshot_seq = 0;

    return info;
}

int Image_ReadResult(IMAGE_INFO *info)
{
    uint32_t status;

    if (info == 0 || !Image_init())
        return 0;

    /* The PL copies all live fields to its snapshot bank on this write. */
    UI_Out32(Image_Reg(IMAGE_REG_CTRL), IMAGE_CTRL_SNAPSHOT);

    status = UI_In32(Image_Reg(IMAGE_REG_STATUS));
    info->result_valid = (status & IMAGE_STATUS_RESULT_VALID) != 0U;
    info->lane_valid = (status & IMAGE_STATUS_LANE_VALID) != 0U;
    info->frame_pending = (status & IMAGE_STATUS_FRAME_PENDING) != 0U;
    info->cdc_overrun = (status & IMAGE_STATUS_CDC_OVERRUN) != 0U;

    info->frame_count = UI_In32(Image_Reg(IMAGE_REG_FRAME_COUNT));
    info->left_x = (uint16_t)(UI_In32(Image_Reg(IMAGE_REG_LEFT_X)) & 0x3FFU);
    info->right_x = (uint16_t)(UI_In32(Image_Reg(IMAGE_REG_RIGHT_X)) & 0x3FFU);
    info->center_offset = (int16_t)(int32_t)UI_In32(Image_Reg(IMAGE_REG_CENTER));
    info->curve_class = (uint8_t)(UI_In32(Image_Reg(IMAGE_REG_CURVE)) & 0x3U);
    info->confidence = (uint8_t)(UI_In32(Image_Reg(IMAGE_REG_CONFIDENCE)) & 0xFFU);
    info->snapshot_seq = UI_In32(Image_Reg(IMAGE_REG_SNAPSHOT_SEQ));

    return info->result_valid;
}

void Image_ClearEvents(uint32_t events)
{
    events &= IMAGE_CTRL_CLEAR_FRAME | IMAGE_CTRL_CLEAR_OVERRUN;
    if (events != 0U)
        UI_Out32(Image_Reg(IMAGE_REG_CTRL), events);
}

void Image_Show(IMAGE_INFO *info)
{
    al_printf("=======Image Information=======\r\n");
    al_printf("Result valid = %d\r\n",info->result_valid);
    al_printf("lane_valid = %d\r\n",info->lane_valid);
    al_printf("frame_pending = %d\r\n",info->frame_pending);
    al_printf("cdc_overrun = %d\r\n",info->cdc_overrun);
    al_printf("frame_count = %d\r\n",info->frame_count);
    al_printf("left_x = %d\r\n",info->left_x);
    al_printf("right_x = %d\r\n",info->right_x);
    al_printf("center_offset = %d\r\n",info->center_offset);
    al_printf("curve_class = %d\r\n",info->curve_class);
    al_printf("confidence = %d\r\n",info->confidence);
    al_printf("snapshot_seq = %d\r\n",info->snapshot_seq);
    al_printf("=======End Information=======\r\n");
}
