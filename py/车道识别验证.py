"""用单张图片验证一条适合映射到 PL 的简化车道识别流水线。

处理步骤：缩放到 HDMI 有效图像大小 -> 整数灰度 -> 梯形 ROI -> 灰度阈值
-> 滑动窗口寻找左右车道线 -> 二次曲线拟合并生成诊断拼图。

示例：
    python py/车道识别验证.py "道路图片.jpg"
    python py/车道识别验证.py "道路图片.jpg" --threshold 175 --output "结果.png"
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

import cv2
import numpy as np


def read_image(path: Path) -> np.ndarray:
    """读取图片，支持 Windows 下包含中文的路径。"""
    encoded = np.fromfile(str(path), dtype=np.uint8)
    image = cv2.imdecode(encoded, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError(f"无法读取图片：{path}")
    return image


def write_image(path: Path, image: np.ndarray) -> None:
    """保存图片，支持 Windows 下包含中文的路径。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    suffix = path.suffix or ".png"
    success, encoded = cv2.imencode(suffix, image)
    if not success:
        raise ValueError(f"无法编码输出图片：{path}")
    encoded.tofile(str(path))


def integer_grayscale(bgr: np.ndarray) -> np.ndarray:
    """使用定点系数近似 BT.601 灰度，便于对应 PL 的乘加与移位实现。"""
    pixels = bgr.astype(np.uint16)
    blue = pixels[:, :, 0]
    green = pixels[:, :, 1]
    red = pixels[:, :, 2]
    gray = (29 * blue + 150 * green + 77 * red + 128) >> 8
    return gray.astype(np.uint8)


def make_roi_mask(
    height: int,
    width: int,
    top_ratio: float,
    bottom_ratio: float,
    top_half_width: float,
) -> tuple[np.ndarray, np.ndarray]:
    """生成梯形道路 ROI，并返回掩膜和四边形顶点。"""
    y_top = int(height * top_ratio)
    y_bottom = min(height - 1, int(height * bottom_ratio))
    center = width // 2
    half_top = int(width * top_half_width)
    polygon = np.array(
        [[
            [max(0, center - half_top), y_top],
            [min(width - 1, center + half_top), y_top],
            [width - 1, y_bottom],
            [0, y_bottom],
        ]],
        dtype=np.int32,
    )
    mask = np.zeros((height, width), dtype=np.uint8)
    cv2.fillPoly(mask, polygon, 255)
    return mask, polygon[0]


def sliding_window_lane(
    binary: np.ndarray,
    side: str,
    windows: int,
    margin: int,
    min_pixels: int,
) -> dict[str, object] | None:
    """从图像底部直方图开始，逐窗追踪一侧车道线。"""
    height, width = binary.shape
    midpoint = width // 2
    bottom_start = int(height * 0.72)
    bottom_points = binary[bottom_start:, :]
    histogram = np.count_nonzero(bottom_points, axis=0)

    if side == "left":
        search_start, search_end = 0, midpoint
    else:
        search_start, search_end = midpoint, width
    if search_end <= search_start:
        return None

    base_x = search_start + int(np.argmax(histogram[search_start:search_end]))
    if histogram[base_x] < min_pixels:
        return None

    nonzero_y, nonzero_x = binary.nonzero()
    current_x = base_x
    window_height = max(1, height // windows)
    selected_indices: list[np.ndarray] = []
    rectangles: list[tuple[int, int, int, int]] = []

    for window in range(windows):
        y_low = height - (window + 1) * window_height
        y_high = height - window * window_height
        y_low = max(0, y_low)
        x_low = max(0, current_x - margin)
        x_high = min(width, current_x + margin)
        rectangles.append((x_low, y_low, x_high, min(height, y_high)))

        indices = np.flatnonzero(
            (nonzero_y >= y_low)
            & (nonzero_y < y_high)
            & (nonzero_x >= x_low)
            & (nonzero_x < x_high)
        )
        if indices.size:
            selected_indices.append(indices)
            if indices.size >= min_pixels:
                current_x = int(np.mean(nonzero_x[indices]))

    if not selected_indices:
        return None

    indices = np.concatenate(selected_indices)
    ys = nonzero_y[indices]
    xs = nonzero_x[indices]
    if len(ys) < 3 or len(np.unique(ys)) < 3:
        return None

    coefficients = np.polyfit(ys.astype(np.float64), xs.astype(np.float64), 2)
    return {
        "coefficients": coefficients,
        "ys": ys,
        "xs": xs,
        "rectangles": rectangles,
        "base_x": base_x,
        "pixel_count": int(len(ys)),
    }


def evaluate_curve(lane: dict[str, object], y: np.ndarray) -> np.ndarray:
    return np.polyval(lane["coefficients"], y)


def draw_lane_result(
    image: np.ndarray,
    roi_polygon: np.ndarray,
    left_lane: dict[str, object] | None,
    right_lane: dict[str, object] | None,
    curve_threshold: float,
) -> tuple[np.ndarray, str, float | None]:
    """绘制检测结果，并按中心线二阶差分给出粗略弯道方向。"""
    overlay = image.copy()
    cv2.polylines(overlay, [roi_polygon], True, (0, 200, 255), 2)

    for lane, color in ((left_lane, (0, 255, 0)), (right_lane, (255, 180, 0))):
        if lane is None:
            continue
        height = image.shape[0]
        ys = np.linspace(int(height * 0.43), height - 1, 180)
        xs = evaluate_curve(lane, ys)
        points = np.column_stack((np.clip(xs, 0, image.shape[1] - 1), ys))
        points = np.rint(points).astype(np.int32).reshape(-1, 1, 2)
        cv2.polylines(overlay, [points], False, color, 3)

    label = "NO LANE"
    curvature: float | None = None
    if left_lane is not None and right_lane is not None:
        sample_y = np.array(
            [image.shape[0] * 0.50, image.shape[0] * 0.70, image.shape[0] * 0.92]
        )
        center_x = (evaluate_curve(left_lane, sample_y) + evaluate_curve(right_lane, sample_y)) / 2
        curvature = float(center_x[0] - 2 * center_x[1] + center_x[2])
        if curvature > curve_threshold:
            label = "CURVE RIGHT"
        elif curvature < -curve_threshold:
            label = "CURVE LEFT"
        else:
            label = "STRAIGHT"

        y_ref = image.shape[0] * 0.90
        center_ref = float(
            (evaluate_curve(left_lane, np.array([y_ref]))[0]
             + evaluate_curve(right_lane, np.array([y_ref]))[0]) / 2
        )
        offset = center_ref - image.shape[1] / 2
        cv2.circle(overlay, (int(np.clip(center_ref, 0, image.shape[1] - 1)), int(y_ref)), 7, (0, 0, 255), -1)
        cv2.putText(
            overlay,
            f"center offset: {offset:+.0f}px",
            (18, image.shape[0] - 24),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.65,
            (255, 255, 255),
            2,
            cv2.LINE_AA,
        )

    cv2.putText(overlay, label, (18, 34), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2, cv2.LINE_AA)
    return overlay, label, curvature


def make_diagnostics(
    resized: np.ndarray,
    gray: np.ndarray,
    binary: np.ndarray,
    overlay: np.ndarray,
    left_lane: dict[str, object] | None,
    right_lane: dict[str, object] | None,
    roi_polygon: np.ndarray,
    threshold: int,
) -> np.ndarray:
    """输出 2x2 诊断拼图：输入/ROI、灰度、二值掩膜、拟合叠加图。"""
    roi_view = resized.copy()
    cv2.polylines(roi_view, [roi_polygon], True, (0, 200, 255), 2)
    for lane, color in ((left_lane, (0, 255, 0)), (right_lane, (255, 180, 0))):
        if lane is None:
            continue
        for x1, y1, x2, y2 in lane["rectangles"]:
            cv2.rectangle(roi_view, (x1, y1), (max(x1, x2 - 1), max(y1, y2 - 1)), color, 1)

    gray_view = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
    binary_view = cv2.cvtColor(binary, cv2.COLOR_GRAY2BGR)
    cv2.putText(gray_view, f"integer gray | threshold={threshold}", (14, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 0, 255), 2)
    cv2.putText(binary_view, "ROI threshold mask", (14, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 0, 255), 2)

    top = np.hstack((roi_view, gray_view))
    bottom = np.hstack((binary_view, overlay))
    return np.vstack((top, bottom))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="对单张道路图片运行简化车道识别流水线")
    parser.add_argument("--image", type=Path, default="./车道.png",help="输入道路图片")
    parser.add_argument("--output", type=Path, default="./检测结果.png",help="诊断拼图输出路径；默认在输入图片旁生成 *_lane_result.png")
    parser.add_argument("--width", type=int, default=1024, help="算法处理宽度，默认对应 HDMI 图像宽度 1024")
    parser.add_argument("--height", type=int, default=576, help="算法处理高度，默认对应 HDMI 有效图像高度 576")
    parser.add_argument("--threshold", type=int, default=160, help="灰度二值化阈值 0..255，默认 160")
    parser.add_argument("--roi-top", type=float, default=0.45, help="ROI 上边缘 y/图像高度，默认 0.45")
    parser.add_argument("--roi-bottom", type=float, default=0.98, help="ROI 下边缘 y/图像高度，默认 0.98")
    parser.add_argument("--roi-top-half-width", type=float, default=0.42, help="ROI 上边缘半宽/图像宽度，默认 0.42")
    parser.add_argument("--windows", type=int, default=9, help="滑动窗口数量，默认 9")
    parser.add_argument("--margin", type=int, default=80, help="每层窗口的横向搜索半宽像素，默认 80")
    parser.add_argument("--min-pixels", type=int, default=8, help="更新窗口中心所需的最少像素数，默认 8")
    parser.add_argument("--curve-threshold", type=float, default=30.0, help="曲率二阶差分分类阈值（像素），默认 18")
    parser.add_argument("--show", action="store_true",default= True, help="处理后用 OpenCV 窗口显示诊断图")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.image.is_file():
        print(f"输入文件不存在：{args.image}", file=sys.stderr)
        return 2
    if args.width <= 0 or args.height <= 0 or args.windows <= 0 or args.margin <= 0:
        print("width、height、windows 和 margin 必须为正数", file=sys.stderr)
        return 2
    if not 0 <= args.threshold <= 255:
        print("threshold 必须在 0..255 范围内", file=sys.stderr)
        return 2
    if not (0 <= args.roi_top < args.roi_bottom <= 1):
        print("ROI 参数必须满足 0 <= roi-top < roi-bottom <= 1", file=sys.stderr)
        return 2
    if not 0 < args.roi_top_half_width <= 0.5:
        print("roi-top-half-width 必须在 (0, 0.5] 范围内", file=sys.stderr)
        return 2

    try:
        source = read_image(args.image)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2

    resized = cv2.resize(source, (args.width, args.height), interpolation=cv2.INTER_AREA)
    gray = integer_grayscale(resized)
    roi_mask, roi_polygon = make_roi_mask(
        args.height, args.width, args.roi_top, args.roi_bottom, args.roi_top_half_width
    )
    _, thresholded = cv2.threshold(gray, args.threshold, 255, cv2.THRESH_BINARY)
    binary = cv2.bitwise_and(thresholded, roi_mask)

    left_lane = sliding_window_lane(binary, "left", args.windows, args.margin, args.min_pixels)
    right_lane = sliding_window_lane(binary, "right", args.windows, args.margin, args.min_pixels)
    overlay, label, curvature = draw_lane_result(
        resized, roi_polygon, left_lane, right_lane, args.curve_threshold
    )
    diagnostics = make_diagnostics(
        resized, gray, binary, overlay, left_lane, right_lane, roi_polygon, args.threshold
    )

    output = args.output or args.image.with_name(f"{args.image.stem}_lane_result.png")
    try:
        write_image(output, diagnostics)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2

    print(f"检测结果：{label}")
    print(f"左车道：{'找到' if left_lane else '未找到'}；右车道：{'找到' if right_lane else '未找到'}")
    if curvature is not None:
        print(f"中心线曲率指标（二阶差分）：{curvature:+.1f} px")
    print(f"诊断图：{output}")
    if args.show:
        cv2.imshow("Single-frame lane detection", diagnostics)
        cv2.waitKey(0)
        cv2.destroyAllWindows()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
