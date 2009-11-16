        include "processor_def.inc"
	include "memory.inc"
	include "pins.inc"
	include "common.inc"
	include "piceeprom.inc"
	include "serial.inc"
	
	GLOBAL	init_lcd
	GLOBAL	lcd_putch
	GLOBAL	lcd_write
	GLOBAL	lcd_select
	GLOBAL	lcd_send_command
	GLOBAL	lcd_set_backlight

#define scroll_point 40

#define LCD_E1_TEST lcd_selection, 0
#define LCD_E2_TEST lcd_selection, 1
	
piclcd	code

;;; For the 4x40 display, given a character position (linear, 0-159),
;;; in W, return the character address for the position on the
;;; display. Note that this conveniently ignores E1/E2.
	
lookup:
	;; conveniently, character 0 is at ram 0, and so on through 39.
	;; after 39 we should subtract 40. After 79, we should subtract 80
	;; (and it would be on E2).
	return

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
	clrf	lcd_line

	;; initialize ram to match the display (which is to say, blank)
	call	clear_shadow_ram

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

	;; prepare to send all commands to both E lines
	bsf	LCD_E1_TEST
	bsf	LCD_E2_TEST
	
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

	;; done init; reset the selected controller to be E1-only
	bcf	LCD_E2_TEST
	
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
	call	clear_shadow_ram
	
	return

;;; lcd_write:
;;;  Write a character to the LCD, bypassing internal buffering, scrolling
;;;  and display tracking. This should only be used externally if lcd_putch
;;; is not going to be used at all.
	
lcd_write:
	movwf	lcd_tmp
	call	_wait_bf
	movfw	lcd_tmp
	SET_RS_CLEAR_RW
	WRITE_W_ON_LCD
	btfss	LCD_E1_TEST
	goto	skip_write_e1
	TOGGLE_E1
skip_write_e1:
	btfss	LCD_E2_TEST
	return
	TOGGLE_E2
	return

;;; lcd_putch:
;;;  take character in 'W' and place it on the LCD. This includes shifting
;;;  the existing text if required. (This should be the primary method used
;;;  to put characters on the display, if the application isn't manually
;;;  repositioning itself.)
lcd_putch:
	movwf	lcd_arg		; save it for later

	xorlw	10		; linefeed?
	skpnz
	goto	handle_linefeed
	xorlw	10^13		; CR?
	skpnz
	goto	handle_cr
	xorlw	13		; done messing around, then.

	movfw	lcd_pos
	sublw	scroll_point
	skpz
	goto	not_scroll
is_scroll:
	call	_shift_buffer	; shift our buffered data left 1 char & reprint

	movfw	lcd_arg		; take what's in lcd_arg and print it too
	movwf	lcd_datal0c0+scroll_point-1
	
	;; write it to the last position on the display
	movfw	lcd_arg
	call	lcd_write

	return
	
not_scroll:	
	;; put new char @ DD[lookup[pos]]
	movfw	lcd_pos
	call	lookup
	iorlw	b'10000000'
	call	lcd_send_command
	movfw	lcd_arg
	call	lcd_write
	movlw	lcd_datal0c0
	addwf	lcd_pos, W
	movwf	FSR
	movfw	lcd_arg
	movwf	INDF

	incf	lcd_pos, F

	return

;;; lcd_select
;;;   W: which device E lines to use. This is a bitwise test:
;;;   b'xxxxxx21' -- if '1' is on, use E1; if '2' is on, use E2. Note that
;;;   one of these bits must be set, or this module's code may do bad things
;;;   while waiting for the BF flag after sending commands...
lcd_select:
	movwf	lcd_selection
	btfsc	LCD_E1_TEST
	return			; bit1 is set, so we don't need failsafe...
	btfss	LCD_E2_TEST
	bsf	LCD_E1_TEST	; failsafe: no bits were on. turn on E1
	return
	
;;; handle_linefeed
handle_linefeed:
	incf	lcd_line, F
	movfw	lcd_line
	xorlw	4		; if we're on line 4 already (3), stay there
	skpnz
	decf	lcd_line, F
	return
	
;;; handle_cr
handle_cr:
	clrf	lcd_pos		; move back to start of line
	return
	
;;; _wait_bf:
;;;  wait until the "Busy Flag" is clear, meaning that the LCD is capable of
;;;  taking its next command. It might make sense at some point to call this
;;;  before we make our next call, rather than after we send this one, which
;;;  would streamline commands a bit.
;;; Note that this will wait for both E1 and E2 to be clear, if both are
;;; selected.
_wait_bf:
	START_READ_BF
	btfss	LCD_E1_TEST
	goto	dont_bf_test_e1
bf_retry_e1:
	ASSERT_E1
 	READ_BF_AND_SKIP	; skip next statement if BF is clear (unbusy)
	goto	bf_retry_e1
	DEASSERT_E1

dont_bf_test_e1:	
	btfss	LCD_E2_TEST
	goto	dont_bf_test_e2
bf_retry_e2:
	ASSERT_E2
	READ_BF_AND_SKIP
	goto	bf_retry_e2
	DEASSERT_E2

dont_bf_test_e2:
	bcf	LCD_RW
	
	RESET_BF

	return

;;; _send_init:
;;;  Send an initialization command to the LCD (that is, same as any other
;;;  command, but we won't wait for a busy flag check). Used during the
;;;  initialization sequence. Note that this initializes both E1 and E2
;;;  simultaneously.
_send_init:
	CLEAR_RS_AND_RW
	WRITE_W_ON_LCD
	TOGGLE_E1
	TOGGLE_E2
	return

;;; lcd_send_command:
;;;  used to send a command to the LCD. Should be used as the primary method
;;;  to do that; this properly waits for the busy flag.
lcd_send_command:
	movwf	lcd_tmp
	call	_wait_bf
	movfw	lcd_tmp
	
	;; FIXME: need to alter lcd_pos appropriately?
	
	CLEAR_RS_AND_RW
	WRITE_W_ON_LCD
	btfss	LCD_E1_TEST
	goto	send_to_e2
	TOGGLE_E1
send_to_e2:
	btfss	LCD_E2_TEST
	return
	TOGGLE_E2
	return

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
	;; save current lcd selection
	movfw	lcd_selection
	movwf	lcd_selection_tmp

	;; select device #0
	movlw	0x01
	movwf	lcd_selection
	
	;; move to DD addr 0x00
	movlw	b'10000000'
	call	lcd_send_command

	;; shift data left one byte, both on the display and in our ram cache
	movlw	lcd_datal0c0+1
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
	call	lcd_write

	;; increment the counter and loop as req'd
	incf	lcd_shift_tmp, F
	movfw	lcd_shift_tmp
	xorlw	scroll_point - 1 ; if we're at the end of the line, stop!
	skpz
	goto	loop

	;; restore current line selection
	;; save current lcd selection
	movfw	lcd_selection_tmp
	movwf	lcd_selection
	
	return

clear_shadow_ram:
	;; clear page0 and page1 of shadow ram (bytes 0x20 through 0x6F and
	;; bytes 0xa0 through 0xef) with spaces, which matches what the display
	;; would be displaying.
	movlw	lcd_datal0c0
	movwf	FSR
repeat_pg0:	
	movlw	' '
	movwf	INDF
	incf	FSR, F
	movlw	lcd_datal1c39
	xorwf	FSR, W
	skpz
	goto	repeat_pg0

	movlw	lcd_datal2c0
	movwf	FSR
repeat_pg1:
	movlw	' '
	movwf	INDF
	incf	FSR, F
	movlw	lcd_datal3c39
	xorwf	FSR, W
	skpz
	goto	repeat_pg1
	return

;;; dump_mem exists for debugging purposes
dump_mem:
	movlw	lcd_datal0c0
	movwf	FSR
	movlw	'\r'
	fcall	putch_usart
	movlw	'\n'
	fcall	putch_usart

	movlw	'0'
	fcall	putch_usart
	movlw	':'
	fcall	putch_usart
repeat_dump_l0:
	movfw	INDF
	fcall	putch_usart
	incf	FSR, F
	movlw	lcd_datal1c0
	xorwf	FSR, W
	skpz
	goto	repeat_dump_l0

	movlw	'\r'
	fcall	putch_usart
	movlw	'\n'
	fcall	putch_usart
	movlw	'1'
	fcall	putch_usart
	movlw	':'
	fcall	putch_usart
repeat_dump_l1:
	movfw	INDF
	fcall	putch_usart
	incf	FSR, F
	movlw	lcd_datal1c39 + 1
	xorwf	FSR, W
	skpz
	goto	repeat_dump_l1
	

	movlw	'\r'
	fcall	putch_usart
	movlw	'\n'
	fcall	putch_usart
	return

;;; W, bit 0, determines on/off.
lcd_set_backlight:
	movwf	lcd_tmp
	btfss	lcd_tmp, 0
	bcf	PORTA, 4
	btfsc	lcd_tmp, 0
	bsf	PORTA, 4
	return
	
	END

