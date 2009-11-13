        include "processor_def.inc"
	include "memory.inc"
	include "pins.inc"
	include "common.inc"
	include "piceeprom.inc"

	GLOBAL	init_lcd
	GLOBAL	lcd_putch
	GLOBAL	lcd_send_command

piclcd	code

;;; simple lookup table: given a character position in W, return the LCD
;;; display's character address for that position. This is written for the
;;; 16166, which is a one-line 16-char display. It logically breaks up the
;;; display into two "lines" (which happen to be side-by-side). Hence
;;; the jump from 0x07 to 0x40...
	
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
	retlw	0x47		;extra to catch lcd-display-overflow...

;;; init_lcd:
;;;  Initializes the LCD, mostly per the documentation. Unfortunately the
;;;  (printed) docs I've got appear to be wrong (or at least the procedure
;;;  there doesn't work on the 16166 I've got). This procedure is a
;;;  combination of what's in my printed docs as well as various information
;;;  gleaned from the web and other peoples' initialization code. Time will
;;;  tell how portable it is. So far, it has only been confirmed to work on
;;;  a 16166.
	
init_lcd:
	banksel	lcd_pos
	clrf	lcd_pos

	;; initialize ram to match the display (which is to say, blank)
	movlw	' '
	movwf	lcd_data0
	movwf	lcd_data1
	movwf	lcd_data2
	movwf	lcd_data3
	movwf	lcd_data4
	movwf	lcd_data5
	movwf	lcd_data6
	movwf	lcd_data7
	movwf	lcd_data8
	movwf	lcd_data9
	movwf	lcd_dataA
	movwf	lcd_dataB
	movwf	lcd_dataC
	movwf	lcd_dataD
	movwf	lcd_dataE
	movwf	lcd_dataF

	init_tris		; from pins.inc

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

	;; return home
	movlw	b'00000010'
	call	lcd_send_command
	
	;; write an init message to the display

#if 0
	;; I believe this delay requirement was due to a faulty
	;; wait_bf, which has now been fixed. Needs to be confirmed or
	;; disproven experimentally yet.
	
	;; debug: do we need a delay here?
	;; apparently, yes - w/o a delay, the init message is garbled. With it,
	;; the init message appears to be okay.
	movlw	5
	call	lcd_delay
#endif

	movlw	' '
	lcall	lcd_putch
	movlw	' '
	lcall	lcd_putch
	movlw	' '
	lcall	lcd_putch
	movlw	'L'
	lcall	lcd_putch
	movlw	'C'
	lcall	lcd_putch
	movlw	'D'
	lcall	lcd_putch
	movlw	' '
	lcall	lcd_putch
	movlw	'S'
	lcall	lcd_putch
	movlw	'l'
	lcall	lcd_putch
	movlw	'e'
	lcall	lcd_putch
	movlw	'd'
	lcall	lcd_putch
	movlw	' '
	lcall	lcd_putch
	movlw	'v'
	lcall	lcd_putch
	movlw	'0'
	lcall	lcd_putch
	movlw	'.'
	lcall	lcd_putch
	movlw	'1'
	lcall	lcd_putch
	
	return

;;; _lcd_write:
;;;  Write a character to the LCD, bypassing internal buffering, scrolling
;;;  and display tracking. This should only be used internally by this module.
	
_lcd_write:
	SET_RS_CLEAR_RW
	WRITE_W_ON_LCD
	TOGGLE_E
	goto	wait_bf

;;; putch with internal buffering
lcd_putch:
	movwf	lcd_arg		; save it for later

	movfw	lcd_pos
	sublw	d'16'
	skpz
	goto	not_16
is_16:
	call	shift_buffer	; shift our buffered data left 1 char & reprint

	movfw	lcd_arg		; take what's in lcd_arg and print it too
	movwf	lcd_dataF
	
	;; write it to the last position on the display
	movfw	lcd_arg
	call	_lcd_write

	return
	
not_16:	
	;; put new char @ DD[lookup[pos]]
	movfw	lcd_pos
	call	lookup
	iorlw	b'10000000'
	call	lcd_send_command
	movfw	lcd_arg
	call	_lcd_write
	movlw	lcd_data0
	addwf	lcd_pos, W
	movwf	FSR
	movfw	lcd_arg
	movwf	INDF

	incf	lcd_pos, F

	return
	
wait_bf:
	START_READ_BF
bf_retry:	
	TOGGLE_E
	
	READ_BF_AND_SKIP	; skip next statement if BF is clear (unbusy)
	goto	bf_retry
	bcf	LCD_RW

	RESET_BF

	return


send_init:
	CLEAR_RS_AND_RW
	WRITE_W_ON_LCD
	TOGGLE_E
	return

lcd_send_command:
	;; FIXME: need to alter lcd_pos appropriately
	CLEAR_RS_AND_RW
	WRITE_W_ON_LCD
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
;;; 
	
lcd_delay:
	banksel	lcd_tmr0
	movwf	lcd_tmr1
	clrf	lcd_tmr0
	incfsz	lcd_tmr0, F
	goto    $-1
	decfsz  lcd_tmr1, F
	goto    $-3
	return

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

	;; shift data left one byte, both on the display and in our ram cache
	movlw	lcd_data1
	movwf	FSR

	clrf	lcd_shift_tmp	; new cursor position
loop:	
	movfw	INDF
	decf	FSR, F
	movwf	INDF
	incf	FSR, F
	incf	FSR, F
	movwf	lcd_shift_tmp2	; save the char

	;; move to the right spot on the LCD
	movfw	lcd_shift_tmp
	call	lookup
	iorlw	b'10000000'
	call	lcd_send_command
	;; write the character now
	movfw	lcd_shift_tmp2
	call	_lcd_write

	;; increment the counter and loop as req'd
	incf	lcd_shift_tmp, F
	movfw	lcd_shift_tmp
	sublw	0x0F		; if lcd_shift_tmp == 15, stop!
	skpz
	goto	loop

	return
	
	END

