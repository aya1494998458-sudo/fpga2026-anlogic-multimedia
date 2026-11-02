# 基于安路 EG4S20 的 HDMI 图像与音频展示系统

目标板 HX4S20C，器件 EG4S20BG256，工具 Anlogic TD 6.2.168116。
本发布以 build_20261029_011328 为基线。综合、布局布线、STA、位流生成及临时 SRAM 下载有日志；完整功能的最终板级验收待补充。

## 文件与依赖

TD 入口：`project/src/td_project/HDMI1.4b_Transmitter_v1.0.al`，顶层模块 `top`。
扩展 RTL 在 `rtl`，测试在 `tb`，约束在 `project/src/user_source/constraints_source`。
最终位流及工具证据在 `reports/build_20261029_011328`。

四个加密第三方 IP 的再分发许可尚未找到明确条款，因此未放入本发布副本。`dependencies.json` 记录相对路径和 SHA256。获得官方参考资料的合法使用权后，使用下面的脚本从本机参考工程恢复：

```powershell
.\scripts\restore_dependencies.ps1 -ReferenceRoot '你的完整参考工作工程目录'
.\scripts\verify_release.ps1
```

不能直接从缺失加密 IP 的副本完成综合。原电脑完整可构建工程与既有 SwitchFix ZIP 均保持原样。恢复脚本不获取、复制或分发 TD 许可证。

## 构建和仿真

`scripts/build.ps1` 默认 TD 路径为 `D:\FPGA_Tools\Anlogic_TD`。其他电脑可设置环境变量 `ANLOGIC_TD_HOME` 指向合法安装目录。
在 PowerShell 运行 `.\scripts\build.ps1`。检查新构建的 final.ts，建立和保持 WNS 均应非负；退出码不能代替 STA。
GUI 综合须设置 `pack_seq_in_io=off`，启用 timing.sdc 和 cdc.sdc。

运行 `.\scripts\test.ps1`。需安装 Icarus Verilog 并将 iverilog、vvp 加入 PATH；也支持 `tools/oss-cad-suite/bin`。本包不捆绑约 600MB 的仿真工具。
测试使用真实 RTL 和测试用 FIFO/SD 扇区事务模型，不包含加密 HDMI/SDRAM IP 的周期精确联合仿真。

## 操作

FAT32 TF 卡根目录放最多四张 24 位未压缩 BMP（宽 2～640，高 2～480），可放一个 48kHz 16/24 位整数 PCM WAV（单/双声道）。按目录物理顺序查找；不扫描子目录。HDMI 连接 HDMI_B。
KEY1 复位，KEY2 下一图；SW1/SW2 选页，SW3 自动轮播，SW4 OSD。
PAGE0：KEY3 静音，KEY4 波形/频谱/关闭；PAGE1：KEY3/4 亮度加/减；PAGE2：对比度加/减；PAGE3：转场类型/时长。
PAGE 位值为 SW2:SW1：00 播放、01 亮度、10 对比度、11 转场。0/1 是电平，不指定物理上下方向。
详细步骤见按键开关使用说明.md 和 WAV播放使用说明.md。

## 源码来源

系统沿用官方 lab_ex_5 的 SD SPI、HDMI 发射及 SDRAM 接口，新增 FAT32、BMP 双线性缩放、双帧转场、参数控制、字幕和 WAV/音频可视化逻辑。
原有版权声明保留；本仓库未给第三方资料重新授予开源许可。公开发布前须确认相关参考代码及 IP 的分发条款。
