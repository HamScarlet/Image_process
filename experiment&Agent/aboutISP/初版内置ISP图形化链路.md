# 初版内置 ISP · isp_top.v 数据处理流程

> 工程：`1080p缩放为600p`（`soc_prj/uisrc/03_ip/isp/isp_top.v`）｜ 平台：DR1 + CS500(MIPI) ｜ 输入：1920×1080 RAW10 ｜ 输出：1920×1080 RGB888（128 位 / 4 像素每拍）
> 本文以图为主，逐级解释「每一级在干什么、每个参数为什么是这个数」。

---

## 一、图 1：主数据通路

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 1010" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>isp_top 内置 ISP 主数据通路</title>
<desc>40 位 RAW10 经黑电平校正、3x3 邻域成形、双线性插值变 RGB，再经位宽裁剪、白平衡、边缘屏蔽、伽马、对比度、亮度、饱和度六级增强，最后补齐为 128 位输出</desc>
<defs>
<marker id="flow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<rect x="40" y="30" width="600" height="50" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="51" font-size="13" font-weight="500" fill="#0C447C">AXI-Stream 输入（来自 uial2axis）</text>
<text x="60" y="69" font-size="12" fill="#185FA5">I_tdata[39:0] = 4 像素 × RAW10 · tlast / tuser / tvalid 随拍同步</text>
<line x1="340" y1="80" x2="340" y2="100" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="104" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="125" font-size="13" font-weight="500" fill="#085041">u_BLC · 黑电平校正</text>
<text x="60" y="143" font-size="12" fill="#0F6E56">Black_level_offset_r0~r3 = 65 → BLC_O_tdata[39:0]</text>
<line x1="340" y1="154" x2="340" y2="174" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="178" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="199" font-size="13" font-weight="500" fill="#085041">u_raw_matrix_3x3_buffer · 3×3 邻域成形</text>
<text x="60" y="217" font-size="12" fill="#0F6E56">IMG_WIDTH/HEIGHT=1920/1080 → matrix_*_line[95:0] ×3 + bayer_ypos</text>
<line x1="340" y1="228" x2="340" y2="248" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="252" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="273" font-size="13" font-weight="500" fill="#085041">u_bilinear_interpolation · Bayer → RGB</text>
<text x="60" y="291" font-size="12" fill="#0F6E56">BAYER_MODE="BGGR" → m_aixs_tdata[127:0]（4 像素 × RGB32）</text>
<line x1="340" y1="302" x2="340" y2="322" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="326" width="600" height="50" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="60" y="347" font-size="13" font-weight="500" fill="#633806">u_data128_96 · 位宽 128 → 96</text>
<text x="60" y="365" font-size="12" fill="#854F0B">丢掉每 32 位的最高字节（Alpha）→ m_aixs_tdata_96[95:0]</text>
<line x1="340" y1="376" x2="340" y2="396" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="400" width="600" height="50" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="60" y="421" font-size="13" font-weight="500" fill="#3C3489">u_awb · 自动白平衡（灰世界）</text>
<text x="60" y="439" font-size="12" fill="#534AB7">IMG_WIDTH/HEIGHT=1920/1080 → 全帧累加 G/R、G/B 定点增益</text>
<line x1="340" y1="450" x2="340" y2="470" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="474" width="600" height="50" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="60" y="495" font-size="13" font-weight="500" fill="#3C3489">u_image_cut · 边缘屏蔽</text>
<text x="60" y="513" font-size="12" fill="#534AB7">SKIP_COLS_left=1 → 每行最左 4 个像素置 0（尺寸不变）</text>
<line x1="340" y1="524" x2="340" y2="544" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="548" width="600" height="50" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="60" y="569" font-size="13" font-weight="500" fill="#3C3489">u_gamma · 伽马校正</text>
<text x="60" y="587" font-size="12" fill="#534AB7">GAMMA_10x=22（即 γ=2.2）→ 查 LUT lut_2_2 三通道</text>
<line x1="340" y1="598" x2="340" y2="618" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="622" width="600" height="50" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="60" y="643" font-size="13" font-weight="500" fill="#3C3489">u_contrast_adj · 对比度</text>
<text x="60" y="661" font-size="12" fill="#534AB7">contrast_level=140（Q0.7，128=1.0）→ ×1.094，以 128 为中点</text>
<line x1="340" y1="672" x2="340" y2="692" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="696" width="600" height="50" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="60" y="717" font-size="13" font-weight="500" fill="#3C3489">u_Brightness_adjustment · 亮度</text>
<text x="60" y="735" font-size="12" fill="#534AB7">BRIGHTNESS_ADD=20 · BRIGHTNESS_MINUS=0 → 每通道 +20</text>
<line x1="340" y1="746" x2="340" y2="766" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="770" width="600" height="50" rx="8" fill="#EEEDFE" stroke="#534AB7" stroke-width="0.5"/>
<text x="60" y="791" font-size="13" font-weight="500" fill="#3C3489">u_Saturation_adj · 饱和度</text>
<text x="60" y="809" font-size="12" fill="#534AB7">ADJUST_VAL=130 → 色差 ×1.504，亮度 Y 保持不变</text>
<line x1="340" y1="820" x2="340" y2="840" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="844" width="600" height="50" rx="8" fill="#FAEEDA" stroke="#854F0B" stroke-width="0.5"/>
<text x="60" y="865" font-size="13" font-weight="500" fill="#633806">u_data96_128 · 位宽 96 → 128</text>
<text x="60" y="883" font-size="12" fill="#854F0B">每个 24 位像素前补 8'd0 → Saturation_O_tdata_128[127:0]</text>
<line x1="340" y1="894" x2="340" y2="914" stroke="#888780" stroke-width="1.5" marker-end="url(#flow)"/>

<rect x="40" y="918" width="600" height="50" rx="8" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="60" y="939" font-size="13" font-weight="500" fill="#0C447C">AXI-Stream 输出（送往 rgb4_downscale_8_15）</text>
<text x="60" y="957" font-size="12" fill="#185FA5">O_tdata[127:0] · O_tlast · O_tuser · O_tvalid · O_tready 组合回压</text>

<text x="40" y="992" font-size="11" fill="#5F5E5A">注：O_tready 沿链组合回压至 u_BLC；但 isp_top 自己的 I_tready 端口未驱动（端口声明后无赋值），详见第九节</text>
</svg>

**读图口诀**：数字顺着箭头自上而下走，颜色分组代表职责——🔵 蓝色 = 数据进出的门（AXI-Stream 接口），🟢 绿色 = **RAW 域还原**（把 Bayer 原始数据变成彩色），🟡 橙色 = **只管打包拆包、不动像素值**的位宽转换器，🟣 紫色 = **RGB 域增强**（白平衡、裁剪、伽马、对比度、亮度、饱和度）。注意橙色只有两个节点，它们在链的首尾各出现一次——因为中间六级算法统一用 96 位（4 像素 × 24 位）的窄总线跑，更省布线。

---

## 二、图 2：像素打包与位宽变形


<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 310" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>128 位与 96 位两种打包格式的字节级拆解</title>
<desc>128 位等于 4 个 32 位槽，每槽为 8 位填充加 RGB888；96 位等于 4 个 24 位槽，每槽为 RGB888；两个转换器只改打包不改像素值</desc>
<defs>
<marker id="flow2" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<text x="43" y="26" font-size="13" font-weight="500" fill="#085041">① bilinear 输出 / isp_top 输出：128 位 = 4 个 32 位槽（每槽 1 像素）</text>
<text x="115" y="48" font-size="11" fill="#5F5E5A" text-anchor="middle">[127:96]</text>
<text x="265" y="48" font-size="11" fill="#5F5E5A" text-anchor="middle">[95:64]</text>
<text x="415" y="48" font-size="11" fill="#5F5E5A" text-anchor="middle">[63:32]</text>
<text x="565" y="48" font-size="11" fill="#5F5E5A" text-anchor="middle">[31:0]</text>

<rect x="43" y="54" width="144" height="46" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<line x1="79" y1="54" x2="79" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<line x1="115" y1="54" x2="115" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<line x1="151" y1="54" x2="151" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<text x="61" y="82" font-size="11" fill="#5F5E5A" text-anchor="middle">8'h00</text>
<text x="97" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">R</text>
<text x="133" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">G</text>
<text x="169" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">B</text>

<rect x="193" y="54" width="144" height="46" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<line x1="229" y1="54" x2="229" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<line x1="265" y1="54" x2="265" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<line x1="301" y1="54" x2="301" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<text x="211" y="82" font-size="11" fill="#5F5E5A" text-anchor="middle">8'h00</text>
<text x="247" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">R</text>
<text x="283" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">G</text>
<text x="319" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">B</text>

<rect x="343" y="54" width="144" height="46" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<line x1="379" y1="54" x2="379" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<line x1="415" y1="54" x2="415" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<line x1="451" y1="54" x2="451" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<text x="361" y="82" font-size="11" fill="#5F5E5A" text-anchor="middle">8'h00</text>
<text x="397" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">R</text>
<text x="433" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">G</text>
<text x="469" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">B</text>

<rect x="493" y="54" width="144" height="46" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<line x1="529" y1="54" x2="529" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<line x1="565" y1="54" x2="565" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<line x1="601" y1="54" x2="601" y2="100" stroke="#0F6E56" stroke-width="0.5" opacity="0.5"/>
<text x="511" y="82" font-size="11" fill="#5F5E5A" text-anchor="middle">8'h00</text>
<text x="547" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">R</text>
<text x="583" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">G</text>
<text x="619" y="82" font-size="11" fill="#0F6E56" text-anchor="middle">B</text>

<line x1="100" y1="108" x2="100" y2="138" stroke="#888780" stroke-width="1.5" marker-end="url(#flow2)"/>
<text x="132" y="128" font-size="12" fill="#854F0B">data128_96 · 丢掉每 32 位的最高字节</text>

<text x="43" y="160" font-size="13" font-weight="500" fill="#085041">② 96 位 = 4 个 24 位槽（每槽 1 像素）：比上面每槽少 1 个字节</text>
<text x="133" y="170" font-size="11" fill="#5F5E5A" text-anchor="middle">[95:72]</text>
<text x="283" y="170" font-size="11" fill="#5F5E5A" text-anchor="middle">[71:48]</text>
<text x="433" y="170" font-size="11" fill="#5F5E5A" text-anchor="middle">[47:24]</text>
<text x="583" y="170" font-size="11" fill="#5F5E5A" text-anchor="middle">[23:0]</text>

<rect x="43" y="176" width="36" height="36" rx="4" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5" stroke-dasharray="3 2"/>
<text x="61" y="199" font-size="12" fill="#5F5E5A" text-anchor="middle">×</text>
<rect x="79" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="97" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">R</text>
<rect x="115" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="133" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">G</text>
<rect x="151" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="169" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">B</text>

<rect x="193" y="176" width="36" height="36" rx="4" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5" stroke-dasharray="3 2"/>
<text x="211" y="199" font-size="12" fill="#5F5E5A" text-anchor="middle">×</text>
<rect x="229" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="247" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">R</text>
<rect x="265" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="283" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">G</text>
<rect x="301" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="319" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">B</text>

<rect x="343" y="176" width="36" height="36" rx="4" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5" stroke-dasharray="3 2"/>
<text x="361" y="199" font-size="12" fill="#5F5E5A" text-anchor="middle">×</text>
<rect x="379" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="397" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">R</text>
<rect x="415" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="433" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">G</text>
<rect x="451" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="469" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">B</text>

<rect x="493" y="176" width="36" height="36" rx="4" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5" stroke-dasharray="3 2"/>
<text x="511" y="199" font-size="12" fill="#5F5E5A" text-anchor="middle">×</text>
<rect x="529" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="547" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">R</text>
<rect x="565" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="583" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">G</text>
<rect x="601" y="176" width="36" height="36" rx="4" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="619" y="199" font-size="11" fill="#0F6E56" text-anchor="middle">B</text>

<text x="43" y="232" font-size="11" fill="#5F5E5A">data128_96：O_tdata = {I_tdata[119:96], I_tdata[87:64], I_tdata[55:32], I_tdata[23:0]}</text>
<text x="43" y="250" font-size="11" fill="#5F5E5A">data96_128：O_tdata = {{8'd0}, I[95:72], {8'd0}, I[71:48],</text>
<text x="43" y="266" font-size="11" fill="#5F5E5A">              {8'd0}, I[47:24], {8'd0}, I[23:0]}</text>
<text x="43" y="288" font-size="11" fill="#5F5E5A">两个转换器都是纯组合逻辑（无时钟、0 延迟），只改打包方式，不改像素值；虚线格 = 被丢弃或被补 0 的高字节</text>
</svg>

**读图口诀**：上下两条是"同一拍的 4 个像素"的两种打包法——上面 4 个槽各 32 位（每槽多一个 `8'h00` 填充字节），下面 4 个槽各 24 位（只剩真正的 RGB）。虚线格就是多出来的那个字节：`data128_96` 把它**丢掉**，`data96_128` 把它**补 0**。所以这条链是"宽 → 窄 → 又变宽"，变的只是打包，像素值始终是那 4 个。

---

## 三、图 3：Bayer 3×3 去马赛克机制

<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 680 690" width="100%" font-family="'Microsoft YaHei',sans-serif" role="img">
<title>Bayer 到 RGB 的去马赛克机制</title>
<desc>40 位 RAW10 取高 8 位变成 32 位，经窗口重排与两级行缓存形成三行 96 位容器，双线性插值取每行第 3 到 8 列共 18 个邻域像素求平均，输出 128 位</desc>
<defs>
<marker id="flow3" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="context-stroke" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>

<rect x="40" y="30" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="51" font-size="13" font-weight="500" fill="#085041">u_BLC 送来的一拍数据</text>
<text x="60" y="69" font-size="12" fill="#0F6E56">BLC_O_tdata[39:0] = 4 像素 × RAW10（每像素 10 位）</text>
<line x1="340" y1="80" x2="340" y2="100" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<rect x="40" y="104" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="125" font-size="13" font-weight="500" fill="#085041">u_mipi_to_raw_converter · 10 位取高 8 位</text>
<text x="60" y="143" font-size="12" fill="#0F6E56">raw_data[31:0] = 4 像素 × RAW8（源码注释：高位包含的颜色数据更多）</text>
<line x1="340" y1="154" x2="340" y2="174" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<rect x="40" y="178" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="199" font-size="13" font-weight="500" fill="#085041">u_zhenghe · 行内窗口重排</text>
<text x="60" y="217" font-size="12" fill="#0F6E56">IMG_WIDTH_4x = 480（1920&gt;&gt;2）· data_complete_delay = 15 → 每拍凑齐 6 个相邻像素</text>
<line x1="340" y1="228" x2="340" y2="248" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<rect x="40" y="252" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="273" font-size="13" font-weight="500" fill="#085041">u_line_buffer_demosaic × 2 · 两级行缓存</text>
<text x="60" y="291" font-size="12" fill="#0F6E56">BRAM 每拍输出延迟 1 周期，故 data[0] 延 2 拍、data[1] 延 1 拍来对齐</text>
<line x1="340" y1="302" x2="340" y2="326" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<text x="284" y="336" font-size="11" fill="#0F6E56">取第 3~8 列 → 6 个像素（源码里叫 matrix03 ~ matrix08）</text>
<line x1="284" y1="342" x2="510" y2="342" stroke="#0F6E56" stroke-width="0.5"/>
<line x1="284" y1="342" x2="284" y2="348" stroke="#0F6E56" stroke-width="0.5"/>
<line x1="510" y1="342" x2="510" y2="348" stroke="#0F6E56" stroke-width="0.5"/>

<text x="40" y="366" font-size="12" fill="#444441">上一行</text>
<text x="40" y="380" font-size="10" fill="#5F5E5A">matrix_last_line</text>
<rect x="170" y="352" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="188" y="372" font-size="11" fill="#5F5E5A" text-anchor="middle">0</text>
<rect x="208" y="352" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="226" y="372" font-size="11" fill="#5F5E5A" text-anchor="middle">1</text>
<rect x="246" y="352" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="264" y="372" font-size="11" fill="#5F5E5A" text-anchor="middle">2</text>
<rect x="284" y="352" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="302" y="372" font-size="11" fill="#085041" text-anchor="middle">3</text>
<rect x="322" y="352" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="340" y="372" font-size="11" fill="#085041" text-anchor="middle">4</text>
<rect x="360" y="352" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="378" y="372" font-size="11" fill="#085041" text-anchor="middle">5</text>
<rect x="398" y="352" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="416" y="372" font-size="11" fill="#085041" text-anchor="middle">6</text>
<rect x="436" y="352" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="454" y="372" font-size="11" fill="#085041" text-anchor="middle">7</text>
<rect x="474" y="352" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="492" y="372" font-size="11" fill="#085041" text-anchor="middle">8</text>
<rect x="512" y="352" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="530" y="372" font-size="11" fill="#5F5E5A" text-anchor="middle">9</text>
<rect x="550" y="352" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="568" y="372" font-size="11" fill="#5F5E5A" text-anchor="middle">10</text>
<rect x="588" y="352" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="606" y="372" font-size="11" fill="#5F5E5A" text-anchor="middle">11</text>

<text x="40" y="404" font-size="12" fill="#444441">当前行</text>
<text x="40" y="418" font-size="10" fill="#5F5E5A">matrix_cur_line</text>
<rect x="170" y="390" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="188" y="410" font-size="11" fill="#5F5E5A" text-anchor="middle">0</text>
<rect x="208" y="390" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="226" y="410" font-size="11" fill="#5F5E5A" text-anchor="middle">1</text>
<rect x="246" y="390" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="264" y="410" font-size="11" fill="#5F5E5A" text-anchor="middle">2</text>
<rect x="284" y="390" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="302" y="410" font-size="11" fill="#085041" text-anchor="middle">3</text>
<rect x="322" y="390" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="340" y="410" font-size="11" fill="#085041" text-anchor="middle">4</text>
<rect x="360" y="390" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="378" y="410" font-size="11" fill="#085041" text-anchor="middle">5</text>
<rect x="398" y="390" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="416" y="410" font-size="11" fill="#085041" text-anchor="middle">6</text>
<rect x="436" y="390" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="454" y="410" font-size="11" fill="#085041" text-anchor="middle">7</text>
<rect x="474" y="390" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="492" y="410" font-size="11" fill="#085041" text-anchor="middle">8</text>
<rect x="512" y="390" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="530" y="410" font-size="11" fill="#5F5E5A" text-anchor="middle">9</text>
<rect x="550" y="390" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="568" y="410" font-size="11" fill="#5F5E5A" text-anchor="middle">10</text>
<rect x="588" y="390" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="606" y="410" font-size="11" fill="#5F5E5A" text-anchor="middle">11</text>

<text x="40" y="442" font-size="12" fill="#444441">下一行</text>
<text x="40" y="456" font-size="10" fill="#5F5E5A">matrix_next_line</text>
<rect x="170" y="428" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="188" y="448" font-size="11" fill="#5F5E5A" text-anchor="middle">0</text>
<rect x="208" y="428" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="226" y="448" font-size="11" fill="#5F5E5A" text-anchor="middle">1</text>
<rect x="246" y="428" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="264" y="448" font-size="11" fill="#5F5E5A" text-anchor="middle">2</text>
<rect x="284" y="428" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="302" y="448" font-size="11" fill="#085041" text-anchor="middle">3</text>
<rect x="322" y="428" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="340" y="448" font-size="11" fill="#085041" text-anchor="middle">4</text>
<rect x="360" y="428" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="378" y="448" font-size="11" fill="#085041" text-anchor="middle">5</text>
<rect x="398" y="428" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="416" y="448" font-size="11" fill="#085041" text-anchor="middle">6</text>
<rect x="436" y="428" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="454" y="448" font-size="11" fill="#085041" text-anchor="middle">7</text>
<rect x="474" y="428" width="36" height="30" rx="3" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="492" y="448" font-size="11" fill="#085041" text-anchor="middle">8</text>
<rect x="512" y="428" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="530" y="448" font-size="11" fill="#5F5E5A" text-anchor="middle">9</text>
<rect x="550" y="428" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="568" y="448" font-size="11" fill="#5F5E5A" text-anchor="middle">10</text>
<rect x="588" y="428" width="36" height="30" rx="3" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="606" y="448" font-size="11" fill="#5F5E5A" text-anchor="middle">11</text>

<line x1="340" y1="462" x2="340" y2="486" stroke="#888780" stroke-width="1.5" marker-end="url(#flow3)"/>

<rect x="40" y="490" width="600" height="50" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="60" y="511" font-size="13" font-weight="500" fill="#085041">u_bilinear_interpolation · 3×3 邻域平均</text>
<text x="60" y="529" font-size="12" fill="#0F6E56">BAYER_MODE="BGGR" → m_aixs_tdata[127:0]（4 像素 × RGB32）</text>

<rect x="40" y="552" width="600" height="110" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="60" y="572" font-size="12" font-weight="500" fill="#444441">四条硬规则（都来自源码，可逐条核对）</text>
<text x="60" y="594" font-size="11" fill="#5F5E5A">bayer_ypos = !v_cnt_d[0] &amp; ch_valid —— 行号最低位决定 Bayer 奇/偶行，两行取邻公式不同</text>
<text x="60" y="614" font-size="11" fill="#5F5E5A">每个通道先求和：r*_matrix_plus = sum_part0 + sum_part1</text>
<text x="60" y="634" font-size="11" fill="#5F5E5A">再取平均：&gt;&gt;1 表示 2 点平均，&gt;&gt;2 表示 4 点平均（用移位代替除法器）</text>
<text x="60" y="654" font-size="11" fill="#5F5E5A">输出打包：4 像素各 {R[23:16], G[15:8], B[7:0]} → 128 位 RGB32</text>
</svg>

**读图口诀**：先看竖排四步——RAW10 只留高 8 位、窗口重排、两级行缓存，把数据"铺开成三行"。中间那一排小方格就是**三行容器**：每行 12 个 8 位像素（共 96 位），绿色的是真正被拿去算的**第 3~8 列**（6 个），灰色是陪跑的。三行 × 6 列 = 18 个邻域像素，正好够 4 个输出像素各取一个 3×3 窗口。最后一张灰底卡片列出四条算法硬规则。

---

## 四、一句话总览

**摄像头的原始数据像"每格只有一种颜色的马赛克画"，ISP 要把每个格子周围的颜色借过来，猜出它本来是什么颜色（去马赛克），再顺手把画面调好看（白平衡、伽马、对比度、亮度、饱和度）。**

必须先建立一个基本认知：**Bayer 传感器的每个像素只测一种颜色**（BGGR 排列：一行是 B G B G，下一行是 G R G R）。所以"彩色图像"不是拍出来的，是**算出来的**——这就是为什么必须有 3×3 邻域、必须有行缓存、必须区分奇偶行。

| 图/章节 | 回答的问题 | 类比 |
|---|---|---|
| 第一节 图 1 | 数据**往哪走、经过谁** | 一条 11 道工序的流水线 |
| 第二节 图 2 | 数据**打包成什么形状** | 同样 4 个鸡蛋，有时装在 4 个 32 格蛋托里，有时换成 4 个 24 格蛋托 |
| 第三节 图 3 | **颜色是怎么猜出来的** | 看每个像素的 8 个邻居，同色的求平均 |
| 第五节 逐级详解 | 每一道工序**参数是多少、为什么** | 工序卡 |
| 第七节 时钟域 | 流水线**听谁的节拍** | 全厂只有一个钟：MIPI 接收时钟 |
| 第八节 参数与配置 | **能不能在线调** | 不能——所有参数都是出厂时焊死的（编译期常量） |

---

## 五、逐级详解（13 级）

### 第 0 级：AXI-Stream 输入（接口）

| 项目 | 内容 |
|---|---|
| 参数 | `IMG_WIDTH=1920`、`IMG_HEIGHT=1080`（由 `system.v` 传入） |
| 端口 | `I_tdata[39:0]`、`I_tlast`、`I_tuser`、`I_tvalid`、`I_tdest[9:0]`、`O_tready`；另有一个输出口 `I_tready` |
| 输入 | 来自上一级 `uial2axis` 的一拍数据 |
| 输出 | 直接进 `u_BLC` |
| **为什么是 40 位** | 传感器输出 **RAW10**（每像素 10 位）；2 条数据 lane × 每条 DDR 双沿 → 一拍凑 4 个像素。4 × 10 = **40 位**。后面所有位宽（40 / 32 / 96 / 128）都是 **4 的倍数**，根源就在这里 |
| 时钟 | `axi4s_video_aclk`（`system.v` 里接 `S_hs_rx_clk`，复位接 PLL 的 `locked`） |

### 第 1 级：`u_BLC`（黑电平校正）

| 项目 | 内容 |
|---|---|
| 参数 | `Black_level_offset_r0 ~ r3 = 65`（4 个通道各一个，值全相同） |
| 输入 | `I_tdata[39:0]` |
| 输出 | `BLC_O_tdata[39:0]`、`BLC_O_tvalid`/`tlast`/`tuser` |
| 干什么 | 每个像素**减去 65** |
| **为什么** | 传感器在全黑时输出也不是 0（暗电流 + 读出偏置）。不减掉，黑的地方会发灰，而且后面所有涉及比例的算法（白平衡、伽马）都会算偏 |
| 保护写法 | 源码写了"不够减就归 0"：`if (I_blc_data[i] > black_level_offset[i]) ... else data_out[i] <= 10'd0;`——避免无符号减法下溢，黑区变成白色亮点 |
| 粒度 | `generate for(i=0;i<4;i=i+1)` 四路并行，4 个像素同一拍各减 65，**不增加节拍** |
| 65 是哪来的 | 代码里是**写死的常量**，不是寄存器读来的。65 / 1023 ≈ 6.4% 满幅。换镜头、改模拟增益后要重新标定 |

### 第 2 级：`u_raw_matrix_3x3_buffer`（3×3 邻域成形）

| 项目 | 内容 |
|---|---|
| 参数 | `IMG_WIDTH=1920`、`IMG_HEIGHT=1080`；模块内默认 `data_complete_delay = 15` |
| 输入 | `BLC_O_tdata[39:0]` + 同步信号 |
| 输出 | `matrix_last_line` / `matrix_cur_line` / `matrix_next_line`（各 **96 位**）+ `bayer_ypos` |
| 内部三步 | ① `mipi_to_raw_converter`：40 → 32 位 ② `zhenghe`：行内窗口重排（读窗口 `rd_valid_width_d0 = valid_width - IMG_WIDTH_4x + 15`）③ `line_buffer_demosaic × 2`：两级行缓存 |
| 干什么 | 把"一行一行流进来的像素"攒成"上一行 / 当前行 / 下一行"**三行同时可看**" |
| **为什么必须三行** | 去马赛克要算某个像素的颜色，必须看它上下左右的邻居。数据是顺着流进来的，不缓存就只能"看得到现在、看不到上下" |
| **为什么输出是 96 位** | 96 = 3 × 32，而 32 = 4 像素 × 8 位 → 每个 96 位容器装 **12 个 8 位像素**。插值器只取每行的**第 3~8 列**（源码 `matrix_last_line[71:24]`，48 ÷ 8 = 6 个像素），3 行 × 6 列 = **18 个邻域像素**，正好供 4 个输出像素各取自己的 3×3 |
| 行缓存为什么要对齐 | 源码注释原文：BRAM 每拍输出慢 1 个周期，所以 `data[0]` 延 2 拍、`data[1]` 延 1 拍，才能三者对齐 |

### 第 3 级：`u_bilinear_interpolation`（双线性插值 / 去马赛克）

| 项目 | 内容 |
|---|---|
| 参数 | `BAYER_MODE="BGGR"` |
| 输入 | `matrix_*_line[95:0]` × 3、`bayer_ypos`，以及 `matrix_tvalid/tlast/tuser` |
| 输出 | `m_aixs_tdata[127:0]`（4 像素 × RGB32，高 8 位是填充） |
| 干什么 | 每个像素取自己 3×3 邻域里**同色的邻居求平均**，补齐缺失的两个颜色通道 |
| **为什么叫"双线性"** | 横、竖两个方向各做一次线性平均（先把邻居求和，再除以 2 或 4） |
| 硬件怎么"除以" | `r0_mean <= bayer_ypos_r1 ? r0_matrix_plus >> 1 : r0_matrix_plus >> 2;` —— **`>>1` = 两点平均、`>>2` = 四点平均**。用移位代替除法器：省 DSP、零延迟 |
| **`bayer_ypos` 为什么必须存在** | BGGR 阵列里奇数行与偶数行的颜色排列不同（一行 B G B G，下一行 G R G R），所以"取哪些邻居求和"必须随行切换。源码里就是那个三目选择 |
| 输出为什么是 32 位/像素 | 输出端口定死 128 位 = 4 × 32；下一级 `u_data128_96` 再把高 8 位裁掉 |

### 第 4 级：`u_data128_96`（位宽 128 → 96）

| 项目 | 内容 |
|---|---|
| 参数 | 无（纯组合逻辑，无时钟） |
| 输入 / 输出 | `m_aixs_tdata[127:0]` → `m_aixs_tdata_96[95:0]` |
| 干什么 | 一个 assign：`O_tdata = {I_tdata[119:96], I_tdata[87:64], I_tdata[55:32], I_tdata[23:0]}` |
| **为什么** | 丢掉每个 32 位像素的最高 8 位（Alpha / 填充），只留 24 位 RGB888。接下来 6 级算法**只需要 24 位/像素**，用窄总线跑省布线资源、省 BRAM 位宽 |

### 第 5 级：`u_awb`（自动白平衡）

| 项目 | 内容 |
|---|---|
| 参数 | `IMG_HEIGHT=1080`、`IMG_WIDTH=1920` |
| 输入 / 输出 | `m_aixs_tdata_96[95:0]` → `awb_O_tdata[95:0]` |
| 干什么 | 整帧累加 R/G/B 之和 → 算 G/R、G/B → 把 R、B 通道乘上增益，让三通道均值趋于相等 |
| **为什么** | 这是"**灰世界假设**"：自然场景里所有颜色平均下来应该接近灰色。所以色偏可以靠一次乘法拉回来 |
| 硬件细节 | 4 路并行累加（`sum_r/g/b[0:3]`，各 32 位）→ `divider` 除法器 `numerator = {sum_g,16'd0}`、`denominator = sum_r` → 商是 **Q16.16 定点**（**1.0 = 0x10000**）。增益初值 `20'h10000`（=1.0，等于不调），上限 `20'hfffff`（≈ **16 倍**），防溢出 |
| 为什么延迟 50 拍 | 除法器有几十拍流水延迟，像素流用 `signal_delay(DELAY_CYCLE=50)` 挂在 BRAM 上等结果，两边对齐后再相乘 |
| 每帧复位 | `if (!I_rst_n \|\| I_tuser)` 把累加器与增益复位——**靠 tuser（帧首）对齐帧边界**，不靠额外状态机 |

### 第 6 级：`u_image_cut`（边缘屏蔽）

| 项目 | 内容 |
|---|---|
| 参数 | `IMG_WIDTH/HEIGHT=1920/1080`、`DATA_WIDTH=96`、`SKIP_ROWS_top=0`、`SKIP_ROWS_bottom=0`、`SKIP_COLS_left=1`、`SKIP_COLS_right=0` |
| 干什么 | 把指定区域的像素**置 0（涂黑）**，尺寸与时序都不变 |
| 判据 | `w_skip = (v_cnt < SKIP_ROWS_top) \|\| (h_cnt < SKIP_COLS_left) \|\| (v_cnt >= IMG_HEIGHT - SKIP_ROWS_bottom) \|\| (h_cnt >= IMG_WIDTH_4x - SKIP_COLS_right)` |
| **关键坑（最容易误判）** | 计数器按 **4 像素一拍**走（`IMG_WIDTH_4x = IMG_WIDTH >> 2`），所以 `SKIP_COLS_left=1` 是"跳过第 0 拍"= **每行最左边 4 个像素变黑**，**不是 1 个像素**。差 4 倍 |
| **为什么这么设计** | 数据流是连续的，真把像素"删掉"的话，后面每行的 tlast 位置、降采样比例全都要重算；置 0 则帧结构完全不变，最省事。**这是设计行为，不是 bug** |
| 副作用 | 出图左边缘有 4 像素黑边；下一级 8/15 降采样把 1920 变 1024 时，黑边也按比例缩小 |

### 第 7 级：`u_gamma`（伽马校正）

| 项目 | 内容 |
|---|---|
| 参数 | `GAMMA_10x=22` → γ = **2.2** |
| 干什么 | 每通道逐值查表（LUT） |
| **为什么需要** | 人眼对暗部差异比对亮部敏感（近似幂律），摄像头给的是线性光强，直接显示会"暗部挤成一片黑"。γ=2.2 就是 sRGB 显示的标准校正曲线 |
| 硬件怎么实现 | 模块内含 **9 组预生成 LUT**（`lut_0_8`、`lut_1_2` … `lut_2_6`，对应 γ=0.8~2.6），`GAMMA_10x=22` 选中 `lut_2_2` 那组；R/G/B 各一份，共 3 个 LUT 并行 |
| **为什么是"十倍整数"** | 参数位宽 `[4:0]` 只能存整数，所以用 22 代表 2.2、用 8 代表 0.8。**换 γ 只改参数，不用改代码** |

### 第 8 级：`u_contrast_adj`（对比度）

| 项目 | 内容 |
|---|---|
| 参数 | `contrast_level=140` |
| 干什么 | 以 128（中灰）为轴往外拉：`temp = ((pixel - 128) * contrast_level) >> 7`，再加回 128 |
| **为什么是 140** | 它是 **Q0.7 定点**（源码注释：128 对应 1.0），所以 140 / 128 = **1.09375**，对比度放大约 9.4% |
| **为什么先减 128** | 对比度是"以中灰为支点拉伸"。不减支点就变成整体变亮，跟亮度调节混在一起了 |
| 为什么右移 7 位 | 乘 128 相当于把定点数放大 128 倍，除回来就写 `>>7`，用移位代替除法 |
| 溢出保护 | 末级有饱和判断：`(R_d[9]) ? 0 : (R_d[8]) ? 255 : R_d[7:0]`，即 ≥256 直接截到 255 |

### 第 9 级：`u_Brightness_adjustment`（亮度）

| 项目 | 内容 |
|---|---|
| 参数 | `BRIGHTNESS_ADD=20`、`BRIGHTNESS_MINUS=0` |
| 干什么 | 每通道 `+ ADD - MINUS`，即整体 **+20** |
| **为什么给两个参数** | 一个加、一个减，等于提供 −128 ~ +127 的双向调节，不必用有符号参数 |
| 现值效果 | 画面整体抬亮约 20 / 255 ≈ **7.8%** |
| 溢出保护 | 与对比度同级：≥256 → 截到 255（不会回绕） |

### 第 10 级：`u_Saturation_adj`（饱和度）

| 项目 | 内容 |
|---|---|
| 参数 | `ADJUST_VAL=130`（9 位） |
| 干什么 | 先按 BT.601 求亮度 `Y = (R×306 + G×601 + B×117) >> 10`（即 0.299R + 0.587G + 0.114B），再把每个通道推离/靠近 Y |
| 算式（源码） | `RGB_C = 255 + ADJUST_VAL`；`Y_m = Y × \|ADJUST_VAL\|`；输出 `= (pixel × RGB_C − Y_m) >> 8`（取 `[15:8]`，即除以 256） |
| **有效倍数怎么算** | 对上式整理：`(R − Y)` 的放大倍数 = **`(255 + ADJUST_VAL) / 256`**。代入 130 → 385 / 256 = **1.504**，即色差放大约 50%；同时灰度像素保持不动（R=G=B 时分子分母正好抵消 255/256） |
| ⚠️ 参数口径 | 源码注释说"默认值 128"，但按算式 **128 已经是 ≈1.5 倍增强**；真正的"不调"是 **`ADJUST_VAL = 0`**。要"降饱和"则填负数（第 9 位是符号位，如 `-130`） |
| **为什么要先算亮度** | 饱和度的本质是"保留亮度、只放大色差（R−Y、G−Y、B−Y）"。不先算 Y 就没法保证调饱和度时画面不变亮变暗 |
| 溢出保护 | `Y_*_m_s[18] ? 0 : [17:16] > 0 ? 255 : [15:8]`（中间路径与对比度/亮度一致） |

### 第 11 级：`u_data96_128`（位宽 96 → 128）

| 项目 | 内容 |
|---|---|
| 干什么 | 每个 24 位像素前补 `8'd0`：`{{8'd0}, I[95:72], {8'd0}, I[71:48], {8'd0}, I[47:24], {8'd0}, I[23:0]}` |
| **为什么** | 下游 `uidbuf` 写通道按 32 位粒度（`W_DATAWIDTH=128`、`W_XSIZE=SCALED_IMAGE_WIDTH/4`）走，必须还原成"4 像素 × 32 位"的整齐排布。补的 0 就是 RGB32 的 Alpha 位 |

### 第 12 级：AXI-Stream 输出（接口）

| 项目 | 内容 |
|---|---|
| 端口 | `O_tdata[127:0]`、`O_tlast`、`O_tuser`、`O_tvalid`、`O_tready` |
| 接线 | `assign O_tdata = Saturation_O_tdata_128;` tlast/tuser/tvalid 直连；`assign Saturation_O_tready = O_tready;` |
| 去哪儿 | `system.v` 里 `.O_tready(ISP_O_tready)`，而 `assign ISP_O_tready = scale_I_tready;` → 直接进 **`rgb4_downscale_8_15`**（8/15 降采样，1920→1024、1080→576），再进 `uidbuf` 写 DDR |
| **为什么 ISP 排在缩放之前** | 去马赛克与白平衡都依赖"完整分辨率 + 全帧统计量"，放在缩放后做，统计样本会变少、边缘插值也不准。缩放只是"少要一些像素"，放后面不影响画质 |

---

## 六、数据变形总表

| 级 | 模块 | 位宽 in → out | 每拍携带 | 每像素位宽 | 备注 |
|---|---|---|---|---|---|
| 0 | 输入接口 | 40 → 40 | 4 px RAW10 | 10 | 来自 `uial2axis` |
| 1 | `u_BLC` | 40 → 40 | 4 px RAW10 | 10 | 减 65，下溢归 0 |
| 2 | `u_raw_matrix_3x3_buffer` | 40 → 3 × 96 | 3 行 × 12 px | 8 | 内部先 40→32（取高 8 位） |
| 3 | `u_bilinear_interpolation` | 96 → 128 | 4 px RGB32 | 8 × 3 + 8 填充 | 取 3×6 = 18 邻域 |
| 4 | `u_data128_96` | 128 → 96 | 4 px RGB888 | 24 | 纯组合 |
| 5 | `u_awb` | 96 → 96 | 4 px RGB888 | 24 | 乘定点增益 |
| 6 | `u_image_cut` | 96 → 96 | 4 px RGB888 | 24 | 置 0 不改尺寸 |
| 7 | `u_gamma` | 96 → 96 | 4 px RGB888 | 24 | 查 LUT |
| 8 | `u_contrast_adj` | 96 → 96 | 4 px RGB888 | 24 | 以 128 为轴 |
| 9 | `u_Brightness_adjustment` | 96 → 96 | 4 px RGB888 | 24 | +20 |
| 10 | `u_Saturation_adj` | 96 → 96 | 4 px RGB888 | 24 | 色差 ×1.504 |
| 11 | `u_data96_128` | 96 → 128 | 4 px RGB32 | 24 + 8 填充 | 纯组合 |
| 12 | 输出接口 | 128 | 4 px RGB32 | — | 去 `rgb4_downscale_8_15` |

> **最值得记住的话**：**"一拍 4 个像素"从进到出走完整条链都不变**；位宽只在 96（4×24）和 128（4×32）之间来回切了两次，而这两次切换纯粹是打包格式的转换，与图像内容无关。

---

## 七、时钟域

| 时钟域 | 来源 | 谁在用 | 节拍由谁决定 |
|---|---|---|---|
| `axi4s_video_aclk` | `system.v` 接 `S_hs_rx_clk`（MIPI 接收侧 PLL 产生） | **isp_top 内全部 11 个实例**（9 个时序模块 + 2 个纯组合转换器） | 摄像头像素节拍；复位接 PLL 的 `locked` |

**为什么不需要跨域桥接**：ISP 是一条**单时钟域同步流水线**——11 级全在 `S_hs_rx_clk` 下工作，级间靠 tvalid/tready 握手，数据不需要过 FIFO。真正发生跨域的地方在**下一级** `uidbuf`：写侧是 `S_hs_rx_clk`，读侧是显示时钟 `pclkx1`（`I_W_wclk` / `I_R_rclk` 是两个不同时钟），跨域由 `uidbuf` 内部的异步 FIFO 解决。

源码里的两处保护性写法：

1. **复位用 `locked`（PLL 锁定信号）而不是按键复位** —— PLL 未锁定前时钟不稳甚至没有，此时保持复位是最安全的做法。
2. **帧边界靠 `tuser` 而不是自己数行** —— `u_awb` 用 `if (!I_rst_n || I_tuser)` 复位累加器；`u_image_cut`、`u_zhenghe` 也都在 `I_tuser` 上复位行/列计数器。少一个状态机，就少一处出错的可能。

---

## 八、参数与配置（本模块没有运行时配置链）

与 MIPI 那一侧（有 I2C 配置链、要写传感器寄存器）不同：**ISP 的每一个参数都是编译期常量，没有任何运行时寄存器接口**。改任何一个值都必须重新综合、重新烧录。

| 模块 | 参数 | 当前值 | 改它会发生什么 |
|---|---|---|---|
| `u_BLC` | `Black_level_offset_r0~r3` | 65 / 65 / 65 / 65 | 画面整体明暗基准移动；值偏大 → 暗部被压死 |
| `u_raw_matrix_3x3_buffer` | `data_complete_delay` | 15（模块默认） | 控制读数窗口相对行末的距离；改坏会出现行错位、斜纹 |
| `u_bilinear_interpolation` | `BAYER_MODE` | `"BGGR"` | 填错 → 红蓝互换（整幅偏色） |
| `u_awb` | 无参数（用 `IMG_WIDTH/HEIGHT`） | 1920 / 1080 | 尺寸填错 → 帧统计错位 |
| `u_image_cut` | `SKIP_COLS_left` 等 4 个 | 0 / 0 / 1 / 0 | 改变被涂黑的黑边位置（粒度 = 4 像素） |
| `u_gamma` | `GAMMA_10x` | 22（γ=2.2） | 换 γ 曲线：8 → 0.8（更暗更平），26 → 2.6（更亮更硬） |
| `u_contrast_adj` | `contrast_level` | 140（1.094×） | 加大 → 对比更强、高光更早切到 255 |
| `u_Brightness_adjustment` | `BRIGHTNESS_ADD/MINUS` | 20 / 0 | 整体加减亮度（≥256 截到 255） |
| `u_Saturation_adj` | `ADJUST_VAL` | 130（≈1.5×） | 0 = 不调；负数 = 降饱和；绝对值越大色越浓 |

**上电→出图的推进顺序**（靠握手，不靠配置）：

1. PLL 锁定 → `locked = 1` → `I_rst_n` 释放；
2. MIPI 侧收流，`uial2axis` 把 native 信号转成 AXI-Stream，`I_tuser` 标出第一拍；
3. ISP 各级被同一根 `tvalid` 推着走；`u_awb` 每收到 `I_tuser` 就复位累加器与增益；
4. `O_tready` 从最后一级 `u_Saturation_adj` 沿链组合回压到 `u_BLC`（下游没准备好，上游就停）；
5. 出图后进 `rgb4_downscale_8_15` → `uidbuf` → DDR。

---

## 九、其他细节速查

| 项 | 位置 | 说明 |
|---|---|---|
| ⚠️ `I_tready` 未驱动 | `isp_top.v` 端口声明后**全文无对应 assign**，且例化时 `.I_tready()` 空接 | `u_BLC` 内部本来有 `assign I_tready = O_tready;`，但信号没被引出到顶层端口。结果是**上游永远看不到 ISP 的反压**（ISP 被认为随时可收）。若上游有独立反压需求，这是一处悬空 |
| `I_tdest[9:0]` 全程空跑 | `isp_top.v` + `BLC.v` + `mipi_to_raw_converter.v` | `system.v` 里把 `isp_top` 的 `I_tdest` 空接；进了 `u_BLC` 后 `BLC_O_tdest` 端口**在 BLC.v 内没有被赋值**（未驱动），下游 `mipi_to_raw_converter` 收了 `I_raw_tdest` 也**没有使用**。这条 10 位通道在 ISP 内是陪跑 |
| 两个转换器是"零延迟直通" | `data128_96.v` / `data96_128.v` | 各只有一个 assign、无时钟、无寄存器 → 组合直通，不增加拍数 |
| 反压链有一环很特别 | `bilinear_interpolation.v`：`assign I_tready = O_tready;`（`I_tready` 是**输出**口） | 即"把上游的 ready 直接连到下游的 ready"，本级不产生任何停顿 |
| `u_image_cut` 固定 2 拍延迟 | `image_cut.v` | 数据与 tvalid/tlast/tuser 各打两拍，保证裁切判据与像素对齐 |
| `u_awb` 固定 50 拍延迟 | `awb.v` `DELAY_CYCLE(50)` | 与 `divider` 除法器的流水深度对齐，等增益算完再相乘 |
| 行容器为什么是 12 像素却只用 6 列 | `raw_matrix_3x3_buffer.v` | 源码**未注明**。从 `zhenghe` 的地址计数器（按 `IMG_WIDTH_4x` 循环）与读数窗口推断，是为了让窗口在 4 像素/拍的粒度下滑动而不越界——**此句为推断，未在源码中找到说明，待确认** |

**故障对照表**（现象 → 首先怀疑什么）：

| 现象 | 首先怀疑 |
|---|---|
| 整幅发灰、黑场不黑 | `u_BLC` 的 65 与传感器实际黑电平不匹配 |
| 画面整体发黄 / 发蓝，且随场景漂移 | `u_awb`——灰世界假设在大片单色场景下会算错增益 |
| 红蓝互换 | `BAYER_MODE="BGGR"` 与传感器 CFA 实际排列不符 |
| 左边缘固定 4 像素黑边 | `u_image_cut` 的 `SKIP_COLS_left=1`（**设计行为，不是坏点**） |
| 高光区成片死白、无细节 | `contrast_level=140` 与亮度 +20 叠加后的饱和截断（255 硬切），不是回绕 |
| 色偏夸张、颜色发"塑料" | `ADJUST_VAL=130` 的 ≈1.5 倍饱和增强偏强（注意：**0 才是"不调"**） |
| 斜纹、行错位、边界撕裂 | `u_raw_matrix_3x3_buffer` 的行缓存对齐 / `data_complete_delay`（也可能是上游 MIPI 侧已错） |
| 整帧不动、无图像 | 上游 `uial2axis` 或更前面的 MIPI 链路（ISP 没收到 `tvalid`） |

---

## 十、参数一览

| 常量 | 值 | 推导 / 出处 |
|---|---|---|
| 每拍像素数 | **4** | 40 位 ÷ 10 位 = 4（2 lane × DDR 双沿） |
| RAW10 位宽 | 10 | 传感器输出格式 |
| 输入总线宽度 | **40** | 4 × 10 = 40 |
| 取高 8 位后的宽度 | **32** | 4 × 8 = 32（`mipi_to_raw_converter`） |
| `IMG_WIDTH_4x` | **480** | 1920 >> 2 = 480（一行有多少个 4 像素字） |
| 行容器宽度 | **96** | 3 × 32 = 96 → 12 个 8 位像素 |
| 插值取用窗口 | 6 列 = 48 位 | `[71:24]` → 48 ÷ 8 = 6 |
| 邻域像素总数 | **18** | 3 行 × 6 列，够 4 个输出像素各取 3×3 |
| 插值输出宽度 | **128** | 4 × 32 = 128 |
| 窄总线宽度 | **96** | 4 × 24 = 96（RGB888） |
| 黑电平 | **65** | 写死常量；65 / 1023 ≈ 6.4% 满幅 |
| `data_complete_delay` | **15** | 模块默认值，读数窗口相对行末的距离 |
| `GAMMA_10x` | **22** | 22 ÷ 10 = γ **2.2** |
| 可选 γ 值 | 0.8 / 1.2 / 1.4 / 1.6 / 1.8 / 2.0 / 2.2 / 2.4 / 2.6 | `gamma/` 下 9 组 LUT 目录 |
| `contrast_level` | **140** | Q0.7：140 ÷ 128 = **1.09375** |
| `BRIGHTNESS_ADD` | **20** | 20 / 255 ≈ 7.8% 抬亮 |
| `ADJUST_VAL` | **130** | (255 + 130) ÷ 256 = **1.504**（色差放大倍数） |
| AWB 定点 1.0 | **0x10000** | 2¹⁶ = 65536；`numerator = {sum_g, 16'd0}` 即左移 16 位 |
| AWB 增益上限 | **0xFFFFF** | ≈ 16 倍，防溢出 |
| AWB 对齐延迟 | **50** | `DELAY_CYCLE(50)`，等 `divider` 出结果 |
| `BAYER_MODE` | `"BGGR"` | 必须与传感器 CFA 排列一致 |
| 输出规格 | 1920 × 1080 | 不变尺寸；下一级再降采样为 1024 × 576 |

---

## 十一、总结

1. **通路**：11 个实例串成单时钟域流水线——3 级 RAW 域还原（黑电平 → 3×3 成形 → 双线性）+ 1 次位宽裁剪 + 6 级 RGB 域增强 + 1 次位宽补齐。
2. **变形**：全程保持"一拍 4 像素"，位宽在 40 → 32 → 96 → 128 → 96 → 128 之间变化，其中两端 128 与中间 96 的切换只是打包格式，与像素值无关。
3. **时钟**：ISP 全在 `S_hs_rx_clk` 单域内，无跨域桥接；跨域发生在下一级 `uidbuf` 的写/读两侧。
4. **关键约束**：`image_cut` 的裁切粒度是 **4 像素**（不是 1 像素），`awb` 依赖**灰世界假设**，`saturation` 的参考点 0 才是"不调"。
5. **配置**：全部参数为编译期常量，无运行时寄存器接口；帧同步完全交给 `tuser`，复位交给 PLL 的 `locked`。

---

## 附：原代码 · `isp_top`（`isp_top.v`，1080p 缩放为 600p 工程）（未做任何删改）

> 源文件：`1080p缩放为600p/1080pto600p/soc_prj/uisrc/03_ip/isp/isp_top.v`
> 逐字附于下方，便于与文中参数逐项对照核验。
> 同级子模块路径：`BLC/BLC.v`、`raw_matrix_3x3_buffer/{raw_matrix_3x3_buffer.v, mipi_to_raw_converter.v, zhenghe.v, line_buffer_demosaic.v}`、`bilinear_interpolation/bilinear_interpolation.v`、`data128_96/data128_96.v`、`awb/awb.v`、`image_cut/image_cut.v`、`gamma/gamma.v`、`contrast_adj/contrast_adj.v`、`brightness_adj/Brightness_adjustment.v`、`saturation_adj/Saturation_adj.v`、`data96_128/data96_128.v`

```verilog
module isp_top #(
    parameter IMG_WIDTH = 1920,
    parameter IMG_HEIGHT = 1080
)
(
    input 			axi4s_video_aclk,
    input 			I_rst_n			,
    input 			I_tlast			,
    input 			I_tuser			,
    input [39:0] 	I_tdata			,
    input 			I_tvalid		,
    input [9:0] 	I_tdest			,
    input 			O_tready		,
    output [127:0] 	O_tdata			,
    output 			O_tlast			,
    output 			O_tuser			,
    output 			O_tvalid		,
    output 			I_tready
);


  wire         	BLC_O_tlast;  
  wire         	BLC_O_tuser;  
  wire [39:0] 	BLC_O_tdata;  
  wire         	BLC_O_tvalid;  
  wire [9:0] 	BLC_O_tdest;  
  wire         	BLC_O_tready;  
  
  wire [9:0] 	black_level_offset_r0;
  wire [9:0] 	black_level_offset_r1;
  wire [9:0] 	black_level_offset_r2;
  wire [9:0] 	black_level_offset_r3;
  
  wire         	matrix_tlast;  
  wire         	matrix_tuser;  
  wire         	matrix_tvalid; 
  wire         	matrix_tready; 
  wire         	matrix_bayer_ypos;
  wire [ 95:0] 	matrix_last_line; 
  wire [ 95:0] 	matrix_cur_line;  
  wire [ 95:0] 	matrix_next_line; 

  wire         	m_aixs_tvalid;  
  wire [127:0] 	m_aixs_tdata;  
  wire         	m_aixs_tuser;  
  wire         	m_aixs_tlast;  
  wire         	m_aixs_tready;  
  wire [ 95:0] 	m_aixs_tdata_96;

  wire         	awb_O_tlast;  
  wire         	awb_O_tuser;  
  wire [ 95:0] 	awb_O_tdata;  
  wire         	awb_O_tvalid; 
  wire         	awb_O_tready; 
	
  wire         	gamma_O_tlast;  
  wire         	gamma_O_tuser;  
  wire [ 95:0] 	gamma_O_tdata;  
  wire         	gamma_O_tvalid;  
  wire         	gamma_O_tready;  
	
  wire         	cut_O_tlast;
  wire         	cut_O_tuser;
  wire [ 95:0] 	cut_O_tdata;
  wire         	cut_O_tvalid;
  wire         	cut_O_tready;
	
  wire         	contrast_O_tlast;
  wire         	contrast_O_tuser;
  wire [ 95:0] 	contrast_O_tdata;
  wire         	contrast_O_tvalid;
  wire         	contrast_O_tready;
	
  wire         	Brightness_O_tlast;
  wire         	Brightness_O_tuser;
  wire [ 95:0] 	Brightness_O_tdata;
  wire         	Brightness_O_tvalid;
  wire         	Brightness_O_tready;
	
  wire         	Saturation_O_tlast;
  wire         	Saturation_O_tuser;
  wire [ 95:0] 	Saturation_O_tdata;
  wire         	Saturation_O_tvalid;
  wire         	Saturation_O_tready;

  wire [127:0] 	Saturation_O_tdata_128;  

  assign Saturation_O_tready = O_tready;
  assign O_tdata  = Saturation_O_tdata_128;
  assign O_tlast  = Saturation_O_tlast    ;
  assign O_tuser  = Saturation_O_tuser    ;
  assign O_tvalid = Saturation_O_tvalid   ;


BLC #(
    .Black_level_offset_r0(65),
    .Black_level_offset_r1(65),
    .Black_level_offset_r2(65),
    .Black_level_offset_r3(65)
) u_BLC (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n ),
    .I_tlast (I_tlast ),
    .I_tuser (I_tuser ),
    .I_tdata (I_tdata ),
    .I_tvalid(I_tvalid),
    .I_tdest (I_tdest ),
    .I_tready(),

    .O_tlast (BLC_O_tlast),
    .O_tuser (BLC_O_tuser),
    .O_tdata (BLC_O_tdata),
    .O_tvalid(BLC_O_tvalid),
    .O_tdest (BLC_O_tdest),
    .O_tready(BLC_O_tready)
);

raw_matrix_3x3_buffer #(
    .IMG_WIDTH (IMG_WIDTH),
    .IMG_HEIGHT(IMG_HEIGHT)
) u_raw_matrix_3x3_buffer (
    .I_clk             (axi4s_video_aclk),
    .I_rst_n           (I_rst_n),
    .axi4s_video_tdata (BLC_O_tdata),
    .axi4s_video_tdest (BLC_O_tdest),
    .axi4s_video_tlast (BLC_O_tlast),
    .axi4s_video_tvalid(BLC_O_tvalid),
    .axi4s_video_tuser (BLC_O_tuser),
    .axi4s_video_tready(BLC_O_tready),
    .O_tlast           (matrix_tlast),
    .O_tuser           (matrix_tuser),
    .O_tvalid          (matrix_tvalid),
    .O_tready          (matrix_tready),
    .bayer_ypos        (matrix_bayer_ypos),
    .matrix_last_line  (matrix_last_line),
    .matrix_cur_line   (matrix_cur_line),
    .matrix_next_line  (matrix_next_line)
);

bilinear_interpolation #(
    .BAYER_MODE("BGGR")
) u_bilinear_interpolation (
    .I_clk           (axi4s_video_aclk),
    .I_rst_n         (I_rst_n),
    .I_tlast         (matrix_tlast),
    .I_tuser         (matrix_tuser),
    .I_tvalid        (matrix_tvalid),
    .I_tready        (matrix_tready),
    .bayer_ypos      (matrix_bayer_ypos),
    .matrix_last_line(matrix_last_line),
    .matrix_cur_line (matrix_cur_line),
    .matrix_next_line(matrix_next_line),
    .O_tlast         (m_aixs_tlast),
    .O_tuser         (m_aixs_tuser),
    .O_tdata         (m_aixs_tdata),
    .O_tvalid        (m_aixs_tvalid),
    .O_tready        (m_aixs_tready)
);

data128_96 u_data128_96 (
    .I_tdata(m_aixs_tdata),
    .O_tdata(m_aixs_tdata_96)
);

awb #(
    .IMG_HEIGHT(IMG_HEIGHT),
    .IMG_WIDTH (IMG_WIDTH)
) u_awb (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (m_aixs_tlast),
    .I_tuser (m_aixs_tuser),
    .I_tdata (m_aixs_tdata_96),
    .I_tvalid(m_aixs_tvalid),
    .I_tready(m_aixs_tready),
    .O_tlast (awb_O_tlast ),
    .O_tuser (awb_O_tuser ),
    .O_tdata (awb_O_tdata ),
    .O_tvalid(awb_O_tvalid),
    .O_tready(awb_O_tready)
);

image_cut #(
    .IMG_WIDTH(IMG_WIDTH),
    .IMG_HEIGHT(IMG_HEIGHT),
    .DATA_WIDTH(96),
    .SKIP_ROWS_top(0),
    .SKIP_ROWS_bottom(0),
    .SKIP_COLS_left(1),
    .SKIP_COLS_right(0)
) u_image_cut (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (awb_O_tlast),
    .I_tuser (awb_O_tuser),
    .I_tdata (awb_O_tdata),
    .I_tvalid(awb_O_tvalid),
    .I_tready(awb_O_tready),
    .O_tlast (cut_O_tlast),
    .O_tuser (cut_O_tuser),
    .O_tdata (cut_O_tdata),
    .O_tvalid(cut_O_tvalid),
    .O_tready(cut_O_tready)
);

gamma #(
    .GAMMA_10x(22)
) u_gamma (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (cut_O_tlast),
    .I_tuser (cut_O_tuser),
    .I_tdata (cut_O_tdata),
    .I_tvalid(cut_O_tvalid),
    .I_tready(cut_O_tready),
    .O_tlast (gamma_O_tlast),
    .O_tuser (gamma_O_tuser),
    .O_tdata (gamma_O_tdata),
    .O_tvalid(gamma_O_tvalid),
    .O_tready(gamma_O_tready)
);

contrast_adj #(
    .contrast_level(140) 
) u_contrast_adj (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (gamma_O_tlast),
    .I_tuser (gamma_O_tuser),
    .I_tdata (gamma_O_tdata),
    .I_tvalid(gamma_O_tvalid),
    .I_tready(gamma_O_tready),
    .O_tlast (contrast_O_tlast),
    .O_tuser (contrast_O_tuser),
    .O_tdata (contrast_O_tdata),
    .O_tvalid(contrast_O_tvalid),
    .O_tready(contrast_O_tready)
);

Brightness_adjustment #(
    .BRIGHTNESS_ADD  (20),
    .BRIGHTNESS_MINUS(0)
) u_Brightness_adjustment (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (contrast_O_tlast),
    .I_tuser (contrast_O_tuser),
    .I_tdata (contrast_O_tdata),
    .I_tvalid(contrast_O_tvalid),
    .I_tready(contrast_O_tready),
    .O_tlast (Brightness_O_tlast),
    .O_tuser (Brightness_O_tuser),
    .O_tdata (Brightness_O_tdata),
    .O_tvalid(Brightness_O_tvalid),
    .O_tready(Brightness_O_tready)
);

Saturation_adj #(
    .ADJUST_VAL(130)
) u_Saturation_adj (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (Brightness_O_tlast),
    .I_tuser (Brightness_O_tuser),
    .I_tdata (Brightness_O_tdata),
    .I_tvalid(Brightness_O_tvalid),
    .I_tready(Brightness_O_tready),
    .O_tlast (Saturation_O_tlast ),
    .O_tuser (Saturation_O_tuser ),
    .O_tdata (Saturation_O_tdata ),
    .O_tvalid(Saturation_O_tvalid),
    .O_tready(Saturation_O_tready)
);

data96_128 u_data96_128 (
    .I_tdata(Saturation_O_tdata),
    .O_tdata(Saturation_O_tdata_128)
);
	
endmodule
```
