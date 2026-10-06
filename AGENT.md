## 项目描述

这是一个从官方案例改编的安路FPGA工程。
基本功能为驱动mipi摄像头并输出画面到HDMI屏幕。
## 硬件资源
+ DR1M90GEG400-2
+ HDMI屏幕1024 $\times$ 600 
+ mipi摄像头（与官方案例同款）

## 文件架构
- anlu_document 
    > 所用开发板相关资料
- soc_hw
    > 存放.hpf文件
- soc_prj
    > 存放PL侧文件，主要代码位于uisrc \
    > uisrc结构：
    > 1. 01_rtl: 用户文件
    > 2. 02_sim: 仿真文件
    > 3. 03_ip:  ip核（包括安路官方的一些IP，如mipi,ISP,HDMI等）
    > 4. 04_pin: 引脚约束文件
    > 5. 05_boot: boot文件
- soc_sdk
    > 存放PS侧文件

## 注意事项
+ 增加新模块时注意复用已有模块
+ 新增模块注意阐明接口描述

### TODO:
+ 图像处理