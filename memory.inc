	EXTERN	init_memory


;;; lcd.asm
#define lcd_data0 0x50
#define lcd_data1 0x51
#define lcd_data2 0x52
#define lcd_data3 0x53
#define lcd_data4 0x54
#define lcd_data5 0x55
#define lcd_data6 0x56
#define lcd_data7 0x57
#define lcd_data8 0x58
#define lcd_data9 0x59
#define lcd_dataA 0x5a
#define lcd_dataB 0x5b
#define lcd_dataC 0x5c
#define lcd_dataD 0x5d
#define lcd_dataE 0x5e
#define lcd_dataF 0x5f

#define lcd_tmr0 0x70
#define lcd_tmr1 0x71
#define lcd_pos 0x72
#define lcd_tmp 0x73
#define lcd_arg 0x74
#define lcd_shift_tmp 0x75
#define lcd_shift_tmp2 0x76
#define lcd_write_tmp 0x77

;;; general arguments (used for eeprom, must be globally addressable)
#define arg1          0x78
#define arg2          0x79

;;; main.asm
#define main_serial_tmp 0x7A
#define main_lcd_mode 0x7B

;;; serial.asm
#define serial_timeout_0 0x120
#define serial_timeout_1 0x121
#define serial_timeout_2 0x122
#define serial_work_tmp  0x123
#define serial_work_tmp2 0x124
#define echo_buf 0x7C

