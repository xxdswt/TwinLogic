# 灵弦——FPGA智能电子乐器

TwinLogic 是基于 Tang Mega NEO 60K 的实时 FPGA 音频合成工程。4×4 键盘用于选音和触发，板上按键切换变调、音量、音色、ADSR 包络与测试模式。普通演奏支持四复音，TEST 模式可同时运行 32 路独立振荡器，并可选择或静音某一路。OLED 提供状态反馈。

## 构建和运行

使用 Gowin EDA 1.9.12.04 打开 twinlogic_final_gain6.gprj。器件为 GW5AT-LV60PG484AC1/I0 B，顶层模块为 twinlogic_audio_top。运行综合和布局布线，或从本目录运行 gw_sh.exe build.tcl。在 Gowin Programmer 选择 SRAM Program，载入生成的 .fs。

KEY1 复位到 BEND。KEY0 和 KEY2 同时按住约 0.7 秒，再一起松开可切换模式。普通模式按住 1、2、3、B 可演示四复音。TEST 模式下按住 A 开启 32 路。保持 A 时短按 KEY2 可切换焦点声部静音。

src 保存 Verilog，constraints 保存板级引脚和时序约束，tests 保存串行音频仿真入口。音频由 FPGA 逐样本生成，以 PT8211 原生串行格式输出。板卡与外设的接法见约束和源码。
