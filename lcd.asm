        include "processor_def.inc"
	include "memory.inc"
	include "pins.inc"
	include "common.inc"
	include "serial.inc" 	; for debugging
	include "piceeprom.inc"

	GLOBAL	init_lcd
	GLOBAL	lcd_putch
	GLOBAL	lcd_send_command

PUTCH_LCD_INLINE	MACRO	SYMBOL, STRING_PTR
	movlw	high(STRING_PTR)
	movwf	arg1
	movlw	low(STRING_PTR)
	movwf	arg2
	fcall	SYMBOL
	ENDM
	
PUTCH_LCD_INLINEWKR	MACRO
	LOCAL	read_next
	LOCAL	not_increment
read_next:
	banksel	0
	fcall	fpm_read
	banksel	arg2
	incfsz	arg2, F
	goto	not_increment
	incf	arg1, F
not_increment:
	;; EEDATH and EEDATA have the data. BUT it's a packed string -
	;; the program memory is only 14 bits wide. So we have to do some
	;; work to extract it. And we can only access each register once,
	;; at which point the PIC invalidates the value. So grab a temporary
	;; copy of EEDATA, which we'll need to touch the high bit of...
        banksel EEDATA
	movfw   EEDATA
	banksel serial_work_tmp
	movwf   serial_work_tmp
	
	banksel EEDATH
	movfw   EEDATH
	banksel serial_work_tmp2
	movwf   serial_work_tmp2
	clc
	banksel serial_work_tmp
	btfsc   serial_work_tmp, 7
	setc
	banksel serial_work_tmp2
	rlf     serial_work_tmp2, W
	banksel 0
	xorlw   0x00
	skpnz
	return
	fcall   lcd_putch
;;;  now repeat with the low 7 bits
	banksel serial_work_tmp
	movfw   serial_work_tmp
	andlw   0x7F
	banksel 0
	skpnz
	return
	fcall   lcd_putch
	goto    read_next
	ENDM
	
TOGGLE_E	macro
	banksel	LCD_AUXPORT
	bsf	LCD_E		; minimum 450nS hold time...
	nop
	bcf	LCD_E
	ENDM

.string	code
msg_lcd_init
	da	"Jakob Talbutt-Bauer"
	dw	0x0000
	
piclcd	code

lookup:
	addwf	PCL, F
	retlw	0x00
	retlw	0x01
	retlw	0x02
	retlw	0x03
	retlw	0x04
	retlw	0x05
	retlw	0x06
	retlw	0x07
	retlw	0x40
	retlw	0x41
	retlw	0x42
	retlw	0x43
	retlw	0x44
	retlw	0x45
	retlw	0x46
	retlw	0x47
	
init_lcd:
	banksel	lcd_pos
	clrf	lcd_pos
	banksel	LCD_DATATRIS
	movlw	0x00		; all outputs ('on' == 'in'; 'off' == 'out')
	movwf	LCD_DATATRIS
	banksel	LCD_AUXTRIS
	bcf	TRISC, 5	; FIXME: abstract into pins.inc
	bcf	TRISC, 4
	bcf	TRISC, 3
	banksel	0

	;; lcd 8-bit initialization procedure, per HD44780 documentation
	;; sleep ~15mS 
	movlw	18
	call	lcd_delay
	
	;; RS=0; RW=0; DB[7..0] = 0011xxxx
	movlw	b'00111000'
	call	send_init
	;; sleep ~4.1mS
	movlw	5
	call	lcd_delay
	
	;; RS=0; RW=0; DB[7..0] = 0011xxxx
	movlw	b'00111000'
	call	send_init
	;; sleep ~100uS
	movlw	1
	call	lcd_delay

	
	;; RS=0; RW=0; DB[7..0] = 0011NFxx
	movlw	b'00111000'	; 2 lines, 5x7 font
	call	lcd_send_command

	;; RS=0; RW=0; DB[7..0] = 0 0 0 0 0 1 I/D S
	movlw	b'00000110'	; auto-shift cursor, but not display
	call	lcd_send_command
	
	;; RS=0; RW=0; DB[7..0] = 00001000 - disable display
	;; NOTE: If I send 00001000 here, we never recover from that; there's
	;; no way I've been able to (experimentally, with a 1x16 display)
	;; get it to show anything. But if I send 00001111, it works.
	movlw	b'00001111'
	call	lcd_send_command

	;; RS=0; RW=0; DB[7..0] = 00000001 - enable display
	movlw	b'00000001'
	call	lcd_send_command

	;; Initialization is complete
#if 1
	;; return home
	movlw	b'00000010'
	call	lcd_send_command
#endif
	
	;; write an init message to the display

	PUTCH_LCD_INLINE	putch_lcd_worker, msg_lcd_init
	
	return

lcd_write:
	banksel	LCD_AUXPORT
	bsf	LCD_RS
	bcf	LCD_RW
	banksel	LCD_DATAPORT
	movwf	LCD_DATAPORT
	TOGGLE_E
	goto	wait_bf

;;; putch with internal buffering
lcd_putch:
	movwf	lcd_arg		; save it for later

	movfw	lcd_pos
	sublw	d'15'
	skpz
	goto	not_15
is_15:
	call	shift_buffer	; shift our buffered data left 1 char & reprint
	movfw	lcd_arg		; take what's in lcd_arg and print it too
	movwf	lcd_dataF
	goto	lcd_write
	
not_15:	
	;; put new char @ DD[lookup[pos]]
	movfw	lcd_pos
	call	lookup
	iorlw	b'10000000'
	call	lcd_send_command
	movfw	lcd_arg
	call	lcd_write
	movlw	lcd_data0
	addwf	lcd_pos, W
	movwf	FSR
	movfw	lcd_arg
	movwf	INDF
	incf	lcd_pos, F
	
	return
	
wait_bf:
	banksel	LCD_AUXPORT
	bcf	LCD_RS
	bsf	LCD_RW
	banksel	LCD_DATATRIS
	bsf	LCD_DATATRIS, 7
	banksel	LCD_DATAPORT
bf_retry:	
	TOGGLE_E
	banksel	LCD_DATAPORT
	btfss	LCD_DATAPORT, 7
	goto	bf_retry
	bcf	LCD_RW

	banksel	LCD_DATATRIS
	bcf	LCD_DATATRIS, 7
	banksel	0

#if 0
	;; debugging
	movlw	3
	goto	lcd_delay
	;; end debugging
#endif
	
	return


send_init:	
	banksel	LCD_AUXPORT
	bcf	LCD_RS
	bcf	LCD_RW
	banksel	LCD_DATAPORT
	movwf	LCD_DATAPORT
	TOGGLE_E
	return

lcd_send_command:
	banksel	LCD_AUXPORT
	bcf	LCD_RS
	bcf	LCD_RW
	banksel	LCD_DATAPORT
	movwf	LCD_DATAPORT
	TOGGLE_E
	goto	wait_bf

;;; * W: number of cycles to run through this loop.
;;; * Clock is 3.5795 MHz, so each instruction is 4/3579500 seconds, so
;;; * setting W to 1 and calling this will delay 
;;; *
;;; * 3 cycles for set and call
;;; * 2 cycles for movwf/clrf
;;; * 3 cycles for 255 reps of tmr0 loop
;;; *   2 cycles for last tmr0 loop
;;; * 3 cycles for W-1 tmr1 loops
;;; *   2 cycles for last tmr1 loop
;;; * 2 cycles for return
;;; * == 5 + 767 * (W) + 4 cycles
;;;
;;; which is ~.000867 seconds for each count of W.
;;;
;;; 15mS: W = 18
;;; 4.1mS: W = 5
;;; 100uS: W = 1 (really, 12-hundredths would be sufficient)
x;;; 
	
lcd_delay:
	banksel	lcd_tmr0
	movwf	lcd_tmr1
	clrf	lcd_tmr0
	incfsz	lcd_tmr0, F
	goto    $-1
	decfsz  lcd_tmr1, F
	goto    $-3
	return

putch_lcd_worker:
	PUTCH_LCD_INLINEWKR	; has its own return, no none necessary

set_shift:
	movlw	b'00000111'
	goto	lcd_send_command
clear_shift:
	movlw	b'00000110'
	goto	lcd_send_command

shift_buffer:
	;; move to DD addr 0x00
	movlw	b'10000000'
	call	lcd_send_command

	;; shift each byte of data down, and overwrite whatever was on the
	;; display previously.
	movfw	lcd_data1
	movwf	lcd_data0
	call	lcd_write

	movfw	lcd_data2
	movwf	lcd_data1
	call	lcd_write

	movfw	lcd_data3
	movwf	lcd_data2
	call	lcd_write

	movfw	lcd_data4
	movwf	lcd_data3
	call	lcd_write

	movfw	lcd_data5
	movwf	lcd_data4
	call	lcd_write

	movfw	lcd_data6
	movwf	lcd_data5
	call	lcd_write

	movfw	lcd_data7
	movwf	lcd_data6
	call	lcd_write

	movfw	lcd_data8
	movwf	lcd_data7
	call	lcd_write

	movfw	lcd_data9
	movwf	lcd_data8
	call	lcd_write

	movfw	lcd_dataA
	movwf	lcd_data9
	call	lcd_write

	movfw	lcd_dataB
	movwf	lcd_dataA
	call	lcd_write

	movfw	lcd_dataC
	movwf	lcd_dataB
	call	lcd_write

	movfw	lcd_dataD
	movwf	lcd_dataC
	call	lcd_write

	movfw	lcd_dataE
	movwf	lcd_dataD
	call	lcd_write

	movfw	lcd_dataF
	movwf	lcd_dataE
	goto	lcd_write
	
	END

