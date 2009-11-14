        include "processor_def.inc"
	include "memory.inc"
	include "pins.inc"
	include "common.inc"
	include "piceeprom.inc"
	include "serial.inc"
	
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
	movlw	d'20'
	call	_lcd_delay
	
	;; RS=0; RW=0; DB[7..0] = 0011xxxx
	movlw	b'00111000'
	call	_send_init
	;; sleep ~4.1mS
	movlw	d'6'
	call	_lcd_delay
	
	;; RS=0; RW=0; DB[7..0] = 0011xxxx
	movlw	b'00111000'
	call	_send_init
	;; sleep ~100uS
	movlw	1
	call	_lcd_delay

	
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

	;; delay to show startup banner, then clear display and let it run. If
	;; we were allowing multiple serial configurations, this would be the
	;; place to look for a 'reset the EEPROM' command. This
	;; is about a 1-second delay.
	movlw	0x04
	movwf	lcd_tmp
	movlw	255
	call	_lcd_delay
	decfsz	lcd_tmp
	goto	$-3
	
	;; clear, return home
	movlw	b'00000001'
	call	lcd_send_command
	movlw	b'00000010'
	call	lcd_send_command

	;; reset display buffer
	clrf	lcd_pos
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
	
	return

;;; _lcd_write:
;;;  Write a character to the LCD, bypassing internal buffering, scrolling
;;;  and display tracking. This should only be used internally by this module.
	
_lcd_write:
	SET_RS_CLEAR_RW
	WRITE_W_ON_LCD
	TOGGLE_E1
	goto	_wait_bf

;;; lcd_putch:
;;;  take character in 'W' and place it on the LCD. This includes shifting
;;;  the existing text if required. (This should be the primary method used
;;;  to put characters on the display, if the application isn't manually
;;;  repositioning itself.)
lcd_putch:
	movwf	lcd_arg		; save it for later

	movfw	lcd_pos
	sublw	d'16'
	skpz
	goto	not_16
is_16:
	call	_shift_buffer	; shift our buffered data left 1 char & reprint

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

;;; _wait_bf:
;;;  wait until the "Busy Flag" is clear, meaning that the LCD is capable of
;;;  taking its next command. It might make sense at some point to call this
;;;  before we make our next call, rather than after we send this one, which
;;;  would streamline commands a bit...
_wait_bf:
	START_READ_BF
bf_retry:
	ASSERT_E1

 	READ_BF_AND_SKIP	; skip next statement if BF is clear (unbusy)
	goto	bf_retry
	DEASSERT_E1
	bcf	LCD_RW
	
	RESET_BF

	return

;;; _send_init:
;;;  Send an initialization command to the LCD (that is, same as any other
;;;  command, but we won't wait for a busy flag check). Used during the
;;;  initialization sequence.
_send_init:
	CLEAR_RS_AND_RW
	WRITE_W_ON_LCD
	TOGGLE_E1
	return

;;; lcd_send_command:
;;;  used to send a command to the LCD. Should be used as the primary method
;;;  to do that; this properly waits for the busy flag.
lcd_send_command:
	;; FIXME: need to alter lcd_pos appropriately
	CLEAR_RS_AND_RW
	WRITE_W_ON_LCD
	TOGGLE_E1
	goto	_wait_bf

;;; _lcd_delay:
;;;  Delays for a specified number of loops, based on W:
;;; * W: number of cycles to run through this loop.
;;; * Clock is 4 MHz, so each instruction is 4/4000000 seconds, so
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
;;; which is ~.000776 seconds for each count of W.
;;;
;;; 15mS: W = 20
;;; 4.1mS: W = 6
;;; 100uS: W = 1 (really, 13-hundredths would be sufficient)
;;; 
	
_lcd_delay:
	banksel	lcd_tmr0
	movwf	lcd_tmr1
	clrf	lcd_tmr0
	incfsz	lcd_tmr0, F
	goto    $-1
	decfsz  lcd_tmr1, F
	goto    $-3
	return

;;; _shift_buffer:
;;;  used to shift our internal memory buffer of what's on the display, and
;;;  update the LCD display to show the characters that we think belong there.
;;;  This is fairly specific to the 16166.
_shift_buffer:
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

