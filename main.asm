	include "processor_def.inc"
	include "common.inc"
	include "memory.inc"
	include "serial.inc"
	include "lcd.inc"

	__CONFIG ( _CP_OFF & _LVP_OFF & _BODEN_OFF & _PWRTE_ON & _WDT_OFF & _INTRC_OSC_NOCLKOUT & _MCLRE_OFF )

.main code

_ResetVector	set	0x00
_InitVector	set	0x04

	;; Main code entry point (on startup/reset)
	org	_ResetVector
	lgoto	main

	;; Start of the interrupt handler
	org	_InitVector
	nop
	org	0x05
Interrupt:
;;; standard interrupt setup: save everything!
	movwf   save_w
	swapf   STATUS, W
	movwf   save_status
	bcf     STATUS, RP1
	bcf     STATUS, RP0
	movf    PCLATH, W
	movwf   save_pclath
	clrf    PCLATH
	movfw   FSR
	movwf   save_fsr

;;; handle interrupt working here
	;; RCIF is cleared automatically by hardware when we read RCREG.
	;; grab the serial character into INDF
	movfw	sbuf_wptr
	movwf	FSR
#if 1
	fcall	getch_usart
#else
	movfw	RCREG
#endif
	movwf	INDF
	incf	sbuf_size, F
	incf	sbuf_wptr, F
	movfw	sbuf_wptr
	xorlw	end_serial_buffer+1
	movlw	serial_buffer	; doesn't change Z
	skpnz
	movwf	sbuf_wptr
	
;;; clean up everything we saved...
	movfw   save_fsr
	movwf   FSR
	movf    save_pclath, W
	movwf   PCLATH
	swapf   save_status, W
	movwf   STATUS
	swapf   save_w, F
	swapf   save_w, W
	retfie

main:
#if 0
	banksel	ADCON0
	movlw	b'01100000'	; AN0 is analog, others digital. Powered off.
	movwf	ADCON0
	banksel	ADCON1
	movlw	b'11001110'
	movwf	ADCON1
#endif

	banksel	PCON
	bsf	PCON, OSCF	; high-speed (4MHz) internal oscillator mode
	
	banksel	OPTION_REG
	bsf	OPTION_REG, 1	; disable port b pull-ups
	banksel	CMCON
        movlw   0x07		; disable all comparators
	movwf	CMCON
	
	banksel	TRISA
	clrf	TRISA		; all outputs (0s)
	clrf	TRISB
	banksel	0

	fcall	init_memory
	
	fcall	init_serial

	movlw	'I'
	fcall	putch_usart
	movlw	'n'
	fcall	putch_usart
	movlw	'i'
	fcall	putch_usart
	movlw	't'
	fcall	putch_usart
	movlw	'i'
	fcall	putch_usart
	movlw	'a'
	fcall	putch_usart
	movlw	'l'
	fcall	putch_usart
	movlw	'i'
	fcall	putch_usart
	movlw	'z'
	fcall	putch_usart
	movlw	'i'
	fcall	putch_usart
	movlw	'n'
	fcall	putch_usart
	movlw	'g'
	fcall	putch_usart
	movlw	'.'
	fcall	putch_usart
	movlw	'.'
	fcall	putch_usart
	movlw	'.'
	fcall	putch_usart
	movlw	'.'
	fcall	putch_usart
	movlw	'\r'
	fcall	putch_usart
	movlw	'\n'
	fcall	putch_usart
	
	fcall	init_lcd

	movlw	'!'		; preload the first character to echo back.
	movwf	main_serial_getch ; It's garbage, and can be ignored...

	;; set up serial interrupt. All serial input goes back into our buffer,
	;; which is then emptied in the main loop (below).
	movlw	serial_buffer
	movwf	sbuf_rptr
	movwf	sbuf_wptr

	banksel	PIE1
	bsf	PIE1, RCIE
	banksel	0
	bsf	INTCON, PEIE
	bsf	INTCON, GIE
	
main_loop:
	;; echo back the previous character.
	movfw   main_serial_getch
	banksel	0
        lcall   putch_usart
	
	;; wait for a char on the serial port. Save a copy of it, as we need
	;; to echo it back again after we've performed the appropriate action.
_ml_spin:	
	movfw	sbuf_size
	addlw	0		; shouldn't be necessary, since movf should update Z... ?
	skpnz
	goto	_ml_spin

	;; pull a byte off of the queue...
	movfw	sbuf_rptr
	movwf	FSR
	movfw	INDF
	movwf	main_serial_getch	; save the character
	decf	sbuf_size, F		; and decrease the num bytes in buffer
	incf	sbuf_rptr, F		; move to next char in buffer
	movfw	sbuf_rptr		; check: did we reach the end of buf?
	xorlw	end_serial_buffer+1
	movlw	serial_buffer	; doesn't affect Z
	skpnz
	movwf	sbuf_rptr	; yes, so roll around to start of buffer
	movfw	main_serial_getch
	;; end of pulling byte off of queue

	;; W now contains the character read from serial
	btfss	main_lcd_mode, 0 ; did we just receive an escape char?
	goto	not_escape_mode
is_escape_mode:
	;; last received an escape character, so clear the escape mode, send
	;; this character as a command to the LCD, and then loop.
	bcf	main_lcd_mode, 0
	movfw	main_serial_getch
	fcall	lcd_send_command
	goto	main_loop
	
not_escape_mode:
	btfsc	main_lcd_mode, 1 ; are we in meta-escape mode?
	goto	meta_escape_mode	
	;; If we receive an escape character, then set escape mode and loop.
	xorlw	0xFE
	skpz
	goto	not_escape_char
is_escape_char:
	bsf	main_lcd_mode, 0
	goto	main_loop

is_meta_escape_char:
	bsf	main_lcd_mode, 1
	goto	main_loop
	
not_escape_char:
	;; check for a meta-escape char (0x7C).
	xorlw	0xFE ^ 0x7C
	skpnz
	goto	is_meta_escape_char
	;; otherwise send it to the LCD display.
	movfw	main_serial_getch
	lcall	lcd_putch
	goto main_loop

	;; meta-escape mode is 0x7C -- used to set properties of comms. Right
	;; now that means selecting which 'E' driver to use in the LCD module
	;; and setting the backlight on/off. In the future this might include
	;; setting backlight brightness and baud rate of the serial interface.
meta_escape_mode:
	bcf	main_lcd_mode, 1 ;turn off meta-escape mode
	movwf	arg1
	btfsc	arg1, 4
	call	handle_backlight_meta
	btfsc	arg1, 2
	call	handle_select_meta
	btfsc	arg1, 7
	call	handle_debug_meta
	goto	main_loop
handle_backlight_meta:
	;; bit 3 determines LCD on/off. Send 0/1 in W based on that bit.
	btfss	arg1, 3
	movlw	0x01
	btfsc	arg1, 3
	movlw	0x00
	fcall	lcd_set_backlight
	return
handle_select_meta:
	;; set the bits right for lcd_select...
	movfw	arg1
	andlw	0x03
	fcall	lcd_select
	return
handle_debug_meta:
	lgoto	lcd_debug

	END

