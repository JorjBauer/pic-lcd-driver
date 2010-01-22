;;; lcd driver module
;;;
;;; call init_lcd once to initialize the display.
;;; From there, either use lcd_putch (which will scroll on one line), or
;;;  use lcd_select to choose the driver and call lcd_write/lcd_send_command 
;;;  to send raw data to the device.

        EXTERN  init_lcd
	EXTERN	lcd_select
	EXTERN	lcd_putch
	EXTERN	lcd_write
	EXTERN	lcd_flush
	EXTERN	lcd_send_command
	EXTERN	putch_lcd_worker
	EXTERN	lcd_set_backlight
	EXTERN	lcd_debug

