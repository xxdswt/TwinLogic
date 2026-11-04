set_device GW5AT-LV60PG484AC1/I0 -device_version B
add_file -type verilog {src/dds_core.v}
add_file -type verilog {src/envelope_adsr.v}
add_file -type verilog {src/envelope_adsr_live.v}
add_file -type verilog {src/i2c_write_byte.v}
add_file -type verilog {src/keypad_scan_m3_1.v}
add_file -type verilog {src/note_to_phase_inc.v}
add_file -type verilog {src/oled_font.v}
add_file -type verilog {src/oled_status.v}
add_file -type verilog {src/oled_status32.v}
add_file -type verilog {src/oled_status_uart.v}
add_file -type verilog {src/parallel_controls.v}
add_file -type verilog {src/parallel_engine.v}
add_file -type verilog {src/parallel_status.v}
add_file -type verilog {src/parallel_voice.v}
add_file -type verilog {src/performance_controls.v}
add_file -type verilog {src/pitch_control.v}
add_file -type verilog {src/pt8211_tx.v}
add_file -type verilog {src/sine_rom.v}
add_file -type verilog {src/status_uart.v}
add_file -type verilog {src/synth_engine_bend.v}
add_file -type verilog {src/synth_voice_bend.v}
add_file -type verilog {src/twinlogic_audio_top_m4.v}
add_file -type verilog {src/voice_manager.v}
add_file -type cst {constraints/m3_oled.cst}
add_file -type sdc {constraints/m3.sdc}
set_option -synthesis_tool gowinsynthesis
set_option -top_module twinlogic_audio_top
set_option -output_base_name twinlogic_final_gain6
set_option -verilog_std v2001
run all
