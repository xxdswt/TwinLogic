//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12.04 (64-bit) 
//Created Time: 2026-11-01 22:02:02
create_clock -name sys_clk -period 20 -waveform {0 10} [get_ports {sys_clk}]
