	EXTERN	init_memory


;;; lcd.asm
#define lcd_datal0c0 0x20	; start of LCD shadow RAM, first line
#define lcd_datal0c39 0x47	; LCD shadow ram, end of first line
#define lcd_datal1c0 0x48	; start of second line
#define lcd_datal1c39 0x6F	; end of second line
#define lcd_datal2c0 0xA0	; start of third line
#define lcd_datal2c39 0xC7	; end of third line
#define lcd_datal3c0  0xC8	; start of fourth line
#define lcd_datal3c39 0xEF	; end of fourth line

#define lcd_tmr0 0x70
#define lcd_tmr1 0x71
#define lcd_pos 0x72
#define lcd_line 0x73
#define lcd_tmp 0x74
#define lcd_arg 0x75
#define lcd_shift_tmp 0x76
#define lcd_shift_tmp2 0x77
#define lcd_write_tmp 0x78
#define lcd_selection 0x79
#define lcd_selection_tmp 0x7A

;;; general arguments (used for eeprom, must be globally addressable)
#define arg1          0x7B
#define arg2          0x7C

;;; main.asm
#define main_serial_tmp 0x7D
#define main_lcd_mode 0x7E

;;; serial.asm
#define echo_buf 0x7F

#define serial_timeout_0 0x120
#define serial_timeout_1 0x121
#define serial_timeout_2 0x122
#define serial_work_tmp  0x123
#define serial_work_tmp2 0x124

