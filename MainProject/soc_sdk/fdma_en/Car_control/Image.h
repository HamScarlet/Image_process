/* PS interface for the PL lane-detection result register bank. */
#ifndef IMAGE_H_
#define IMAGE_H_

#include <stdint.h>

#define IMAGE_BASE_ADDR             ((uintptr_t)0x80200000U)

#define IMAGE_REG_ID_VERSION        (IMAGE_BASE_ADDR + 0x50U)
#define IMAGE_REG_STATUS            (IMAGE_BASE_ADDR + 0x54U)
#define IMAGE_REG_FRAME_COUNT       (IMAGE_BASE_ADDR + 0x58U)
#define IMAGE_REG_LEFT_X            (IMAGE_BASE_ADDR + 0x5CU)
#define IMAGE_REG_RIGHT_X           (IMAGE_BASE_ADDR + 0x60U)
#define IMAGE_REG_CENTER            (IMAGE_BASE_ADDR + 0x64U)
#define IMAGE_REG_CURVE             (IMAGE_BASE_ADDR + 0x68U)
#define IMAGE_REG_CONFIDENCE        (IMAGE_BASE_ADDR + 0x6CU)
#define IMAGE_REG_CTRL              (IMAGE_BASE_ADDR + 0x70U)
#define IMAGE_REG_SNAPSHOT_SEQ      (IMAGE_BASE_ADDR + 0x74U)

#define IMAGE_ID_VERSION            0x4C520001U

#define IMAGE_STATUS_RESULT_VALID   (1U << 0)
#define IMAGE_STATUS_LANE_VALID     (1U << 1)
#define IMAGE_STATUS_FRAME_PENDING  (1U << 2)
#define IMAGE_STATUS_CDC_OVERRUN    (1U << 3)
#define IMAGE_STATUS_SNAPSHOT_VALID (1U << 4)

#define IMAGE_CTRL_SNAPSHOT         (1U << 0)
#define IMAGE_CTRL_CLEAR_FRAME      (1U << 1)
#define IMAGE_CTRL_CLEAR_OVERRUN    (1U << 2)

typedef struct {
    uint32_t frame_count;
    uint16_t left_x;
    uint16_t right_x;
    int16_t  center_offset;
    uint8_t  curve_class;
    uint8_t  confidence;
    uint32_t snapshot_seq;
    uint8_t  result_valid;
    uint8_t  lane_valid;
    uint8_t  frame_pending;
    uint8_t  cdc_overrun;
} IMAGE_INFO;

/* Returns 1 when the PL result-bank version matches IMAGE_ID_VERSION. */
IMAGE_INFO* Image_init(void);

/* Snapshots one coherent PL result into info. Returns 1 for a valid result,
 * 0 when the hardware is not connected or no frame result is available.
 */
int Image_ReadResult(IMAGE_INFO *info);

/* Write-one-to-clear event flags. */
void Image_ClearEvents(uint32_t events);

void Image_Show(IMAGE_INFO *info);

#endif /* IMAGE_H_ */
