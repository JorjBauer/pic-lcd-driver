	EXTERN	init_memory


;;; lcd.asm
#define lcd_datal0c0 0x20	; One line of display - used during scrolling.
#define lcd_datal0c39 0x47	; ... last byte in that buffer.

;;; main.asm
#define cursor_bits 0x48
#define main_serial_tmp 0x49
#define main_lcd_mode 0x4A

;;; serial.asm
#define echo_buf 0x4B

#define main_serial_getch 0x4C
#define hex_tmp           0x4C	; yes, same as main_serial_getch

#define	sbuf_tmpw 0x4D
#define sbuf_rsize 0x4E
#define sbuf_rptr_out 0x4F
#define sbuf_tmpr 0x50
#define sbuf_rptr_in 0x51
#define start_serial_rbuffer 0x52
#define end_serial_rbuffer 0x6F

#define lcd_tmr0 0x70
#define lcd_tmr1 0x71
#define lcd_x 0x72
#define lcd_y 0x73
#define lcd_tmp 0x74
#define lcd_arg 0x75
#define lcd_read_tmp1 0x76

#define lcd_write_tmp 0x78
#define lcd_selection 0x79

;;; general arguments (used for eeprom, must be globally addressable)
#define arg1          0x7A
#define arg2          0x7B

#define save_w 0x7C
#define save_status 0x7D
#define save_fsr 0x7E
#define save_pclath 0x7F

#define serial_timeout_0 0x120
#define serial_timeout_1 0x121
#define serial_timeout_2 0x122
#define serial_work_tmp  0x123
#define serial_work_tmp2 0x124

