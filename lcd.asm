        include "processor_def.inc"
	include "memory.inc"
	include "pins.inc"
	include "common.inc"
	include "piceeprom.inc"
	include "serial.inc"
	
	GLOBAL	init_lcd
	GLOBAL	lcd_write	; raw action
	GLOBAL	lcd_putch	; buffered action
	GLOBAL	lcd_select
	GLOBAL	lcd_send_command
	GLOBAL	lcd_set_backlight
	GLOBAL	lcd_debug
	
#define line_width 40
#define num_lines 4

#define LCD_E1_TEST lcd_selection, 0
#define LCD_E2_TEST lcd_selection, 1
	
.piclcd	code

;;; init_lcd:
;;;  Initializes the LCD, mostly per the documentation. Unfortunately the
;;;  (printed) docs I've got appear to be wrong (or at least the procedure
;;;  there doesn't work on the 16166 I've got). This procedure is a
;;;  combination of what's in my printed docs as well as various information
;;;  gleaned from the web and other peoples' initialization code. Time will
;;;  tell how portable it is. So far, it has only been confirmed to work on
;;;  a 16166.
	
init_lcd:
	banksel	lcd_x
	clrf	lcd_x
	clrf	lcd_y

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
	movlw	'2'
	lcall	lcd_putch

	;; delay to show startup banner, then clear display and let it run. If
	;; we were allowing multiple serial configurations, this would be the
	;; place to look for a 'reset the EEPROM' command. This
	;; is about a 1-second delay.
	movlw	0x04
	movwf	lcd_tmp
_startup_delay:	
	movlw	255
	call	_lcd_delay
	decfsz	lcd_tmp
	goto	_startup_delay
	
	;; clear, return home
	movlw	b'00000001'
	call	lcd_send_command
	movlw	b'00000010'
	call	lcd_send_command

	;; reset display buffer
	clrf	lcd_x
	
	return

;;; lcd_write:
;;;  Write a character to the LCD, bypassing internal buffering, scrolling
;;;  and display tracking. Primarily for internal use, but it may also be
;;;  useful to call this externally if lcd_putch is not going to be used
;;;  at all (i.e. if scrolling and buffering are not desired).
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
;;;  take character in 'W' and place it on the LCD. This includes scrolling
;;;  the existing text if required. (This should be the primary method used
;;;  to put characters on the display.)
lcd_putch:
	movwf	lcd_arg		; save it for later

	xorlw	8		; backspace?
	skpnz
	goto	_handle_backspace
	xorlw	8^255		; delete?
	skpnz
	goto	_handle_backspace
	xorlw	255		; done messing around, then.

	;; test for end-of-line before we print the character. (We do it here
	;; so that we don't accidentally scroll off the last line.)
	movfw	lcd_x
	xorlw	line_width
	skpz
	goto	_not_eol
_is_eol:
	;; reached the end of a line. If it's the end of the last line, we'll
	;; need to move to a new line. If we've moved from line 1 to 2, we'll
	;; need to change from E1 to E2.
	clrf	lcd_x
	incf	lcd_y, F

	movfw	lcd_y
	xorlw	num_lines	; did we scroll off the screen?
	skpnz
	call	_scroll		; yes, so scroll display.

	;; fall through and print the new character.
	
_not_eol:
	movfw	lcd_arg		; get back the character being printed.
	xorlw	10		; linefeed?
	skpnz
	goto	_handle_linefeed
	xorlw	10^13		; CR?
	skpnz
	goto	_handle_cr
	
	;; Put the character on the display in the current position, as well
	;; as in our memory buffer.
#if 1
	;; debugging!
	call	_position_cursor
#endif	
	movfw	lcd_arg
	call	lcd_write	; write the char to the display.
	movfw	lcd_arg
	call	_store_byte	; store it in our memory buffer, too.
	
	;; Move to the next character on the line. We'll do end-of-line
	;; wrapping when we receive the next character. (Or not, if we instead
	;; get a reposition-cursor command before then.)
	incf	lcd_x, F
	
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
_handle_linefeed:
	incf	lcd_y, F
	movfw	lcd_y
	xorlw	num_lines	; if we're on line 4 already (3), scroll.
	skpz
	goto	_hlf_noscroll
	decf	lcd_y, F	; leave the cursor on line 3.
	call	_scroll		; scroll contents up one line.
_hlf_noscroll:
	goto	_position_cursor
	
;;; handle_cr
_handle_cr:
	clrf	lcd_x		; move back to start of line.
	goto	_position_cursor

;;; handle_backspace
_handle_backspace:
	decf	lcd_x, F	; move back one character.
	btfsc	STATUS, C
	goto	_position_cursor
	;; We rolled around to the line before. If we're on line 0, do nothing.
	clrf	lcd_x		; move to X=0 no matter what
	movfw	lcd_y
	skpz
	goto	_position_cursor ; on line 0 already! done.
	decf	lcd_y, F	 ; else go back to line above.
	goto	_position_cursor

;;; _position_cursor
;;;  enable the cursor on E1 or E2, and put it at the right x/y based on
;;;  the current contents of lcd_x and lcd_y.
_position_cursor:
	;; For a two-display system, we need to disable the cursor on the
	;; "wrong" display, enable it on the "right" display, and also set
	;; the current input position on the "right" display.
	;; (FIXME: should be able to tell whether or not we need to do that,
	;;  rather than doing it every time!)
	
	btfsc	lcd_y, 1	; is it line 2 or 3?
	movlw	0x01		; yes, select E1 (note, "wrong" display)
	btfss	lcd_y, 1	;  no, select E2 (note, "wrong" display)
	movlw	0x02
	call	lcd_select

	;; disable cursor on this one.
	movlw	b'00001100'
	call	lcd_send_command

	btfsc	lcd_y, 1	; is it line 2 or 3?
	movlw	0x02		; yes, select E2
	btfss	lcd_y, 1	;  no, select E1
	movlw	0x01
	call	lcd_select

	;; enable cursor on this one.
	movlw	b'00001111'
	call	lcd_send_command

	;; now position the cursor on the given display.
	;; figure out how much has to be added to X for desired posn
	movfw	lcd_x		; start with X position
	btfsc	lcd_y, 0	; if (lcd_y%2) == 0, add none
	addlw	0x40		; ... else add 0x40
	iorlw	0x80		; either way, set the high bit ("move cursor")
	goto	lcd_send_command

;;; _write_line
;;;  write memory contents out to the line starting at offset given in W.
_write_line:
	movwf	lcd_read_tmp1

	movlw	lcd_datal0c0
	movwf	FSR

	movfw	lcd_read_tmp1
	addlw	0x80		; for "set ddram"
	call	lcd_send_command ; set start position

	movlw	line_width
	movwf	lcd_read_tmp1
_wl_loop:
	movfw	INDF
	call	lcd_write
	incf	FSR, F
	decfsz	lcd_read_tmp1, F
	goto	_wl_loop
	return

_lcd_read_byte:
	;; set TRIS appropriately for read
	banksel   TRISA
	bsf       TRISA, 0
	bsf       TRISA, 1
	bsf       TRISA, 2
	bsf       TRISA, 3
	banksel   TRISB
	bsf       TRISB, 4
	bsf       TRISB, 5
	bsf       TRISB, 6
	bsf       TRISB, 7
	banksel	0

	;; Set LCD for command mode
	SET_RS_AND_RW

	;; After taking E high, need to wait 160nS for the data read to
	;; execute (if LCD has at least 4.5v; 360nS if lower than 4.5v). But
	;; at 4MHz, one instruction cycle is 1000nS, so there are no delays
	;; in this code.

	;; Also note that this will have unexpected results if E1 and E2 are
	;; both enabled...
	
	btfss	LCD_E1_TEST
	goto	skip_read_e1
        ASSERT_E1
skip_read_e1:
	btfss	LCD_E2_TEST
	goto	skip_read_e2
	ASSERT_E2
skip_read_e2:
	READ_W_FROM_LCD

	DEASSERT_E1
	DEASSERT_E2
	
	CLEAR_RS_AND_RW
	
	;; reset TRIS for normal operation
	banksel   TRISA
	bcf       TRISA, 0
	bcf       TRISA, 1
	bcf       TRISA, 2
	bcf       TRISA, 3
	banksel   TRISB
	bcf       TRISB, 4
	bcf       TRISB, 5
	bcf       TRISB, 6
	bcf       TRISB, 7
	banksel	0
	return
	
;;; _read_line
;;;  read the DD ram on a line into ram. W is the memory offset.
_read_line:
	movwf	lcd_read_tmp1
	
	movlw	lcd_datal0c0	; prep FSR/INDF
	movwf	FSR

	movfw	lcd_read_tmp1
	addlw	0x80		; 0x80 for "set ddram"
	call	lcd_send_command ; set start position

	movlw	line_width
	movwf	lcd_read_tmp1
	
_rl1_loop:
	call	_lcd_read_byte
	movwf	INDF
	incf	FSR, F
	decfsz	lcd_read_tmp1, F
	goto	_rl1_loop
	return
	
;;; _scroll
;;;  roll the lines of text on the screen up one line.
_scroll:
	;; Start by reading the <line_width> chars on line 1, and move them
	;; to line 0. Repeat with line 2 (using E2) to line 1 (using E1),
	;; then 3 (E2) to 2 (also E2).
	movlw	0x01
	call	lcd_select
	movlw	0x40
	call	_read_line	; read line 1 (0x40 on E1)
	movlw	0x01
	call	lcd_select
	movlw	0x00
	call	_write_line	; write to line 0 (0x00 on E1)
	movlw	0x02
	call	lcd_select
	movlw	0
	call	_read_line	; read line 2 (0x00 on E2)
	movlw	0x01
	call	lcd_select
	movlw	0x40
	call	_write_line	; write to line 1 (0x40 on E1)
	movlw	0x02
	call	lcd_select
	movlw	0x40
	call	_read_line	; read line 3 (0x40 on E2)
	;; clear second display, then write line 3 to line 2
	movlw	0x01		; "clear" command
	call	lcd_send_command
	movlw	0x02
	call	lcd_select
	movlw	0x00		; write to line 2 (0x00 on E2)
	call	_write_line

	;; And leave the cursor @ Y=3 (fourth line), X=0.
	clrf	lcd_x
	movlw	3
	movwf	lcd_y
	goto	_position_cursor

;;; _store_byte
;;;  store the byte that's in W in our memory-resident shadow buffer at the
;;;  right position.
_store_byte:
	;; FIXME? Consulting the LCD's memory buffer. If that's fast enough,
	;; we can ditch _store_byte.
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
	goto	_dont_bf_test_e1
_bf_retry_e1:
	ASSERT_E1
 	READ_BF_AND_SKIP	; skip next statement if BF is clear (unbusy)
	goto	_bf_retry_e1
	DEASSERT_E1

_dont_bf_test_e1:	
	btfss	LCD_E2_TEST
	goto	_dont_bf_test_e2
_bf_retry_e2:
	ASSERT_E2
	READ_BF_AND_SKIP
	goto	_bf_retry_e2
	DEASSERT_E2

_dont_bf_test_e2:
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

	;; If it's a clear command, reset the cursor appropriately.
	xorlw	0x01
	skpz
	goto	_lsc_not_clear
	clrf	lcd_x
	;; If it's a command for E2, then we're on line 2. Else line 0.
	clrf	lcd_y		; assume line 0
	btfsc	LCD_E2_TEST
	bsf	lcd_y, 1	; if for E2, then it's line 2
_lsc_not_clear:
	xorlw	0x01		;undo the damage to W

	;; if W & 0x80 == 0x80, then it's a reposition command, and we need to
	;; set the cursor appropriately.
	andlw	0x80
	xorlw	0x80
	skpz
	goto	_lsc_not_reposition
	;; Determine which line we're on
	clrf	lcd_y		; assume we're on line 0/1
	btfsc	LCD_E2_TEST
	bsf	lcd_y, 1	; if for E2, then we're on 2/3
	;; Get the address we're telling the LCD to move to
	movfw	lcd_tmp		; get back the argument
	andlw	0x40		; check the "second line" bit
	xorlw	0x40		; FIXME: shouldn't be necessary, but is - check logic of previous line and following skip!
	skpnz
	incf	lcd_y, F	; yep, second line of the display
	movfw	lcd_tmp		; get back the argument again
	andlw	0x3F		; and get back the position on the line
	movwf	lcd_x		;  which is simply our X position


_lsc_not_reposition:
	movfw	lcd_tmp		; restore the original argument
	
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

;;; W, bit 0, determines on/off.
lcd_set_backlight:
	movwf	lcd_tmp
	btfss	lcd_tmp, 0
	bcf	PORTA, 4
	btfsc	lcd_tmp, 0
	bsf	PORTA, 4
	return

lcd_debug:
	movlw	0x03
	call	lcd_select	; select E1 + E2
	movlw	0x01
	call	lcd_send_command ; clear display
	movlw	0x01
	call	lcd_select	; select just E1
	movlw	0x80
	call	lcd_send_command ; goto position 0

forever:	
	movlw	'1'
	call	lcd_putch
        movlw   255
	call    _lcd_delay
	movlw	'2'
	call	lcd_putch
        movlw   255
	call    _lcd_delay
	movlw	'3'
	call	lcd_putch
        movlw   255
	call    _lcd_delay
	movlw	'4'
	call	lcd_putch
        movlw   255
	call    _lcd_delay
	movlw	'5'
	call	lcd_putch
        movlw   255
	call    _lcd_delay
	movlw	'6'
	call	lcd_putch
        movlw   255
	call    _lcd_delay
	goto	forever
	
	END

