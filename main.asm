	include "processor_def.inc"
	include "common.inc"
	include "memory.inc"
	include "serial.inc"
	include "serbuf.inc"
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
	SERBUF_INTERRUPT
	
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
	SERBUF_INIT

	movlw	'I'
	fcall	putch_usart_buffered
	movlw	'n'
	fcall	putch_usart_buffered
	movlw	'i'
	fcall	putch_usart_buffered
	movlw	't'
	fcall	putch_usart_buffered
	movlw	'i'
	fcall	putch_usart_buffered
	movlw	'a'
	fcall	putch_usart_buffered
	movlw	'l'
	fcall	putch_usart_buffered
	movlw	'i'
	fcall	putch_usart_buffered
	movlw	'z'
	fcall	putch_usart_buffered
	movlw	'i'
	fcall	putch_usart_buffered
	movlw	'n'
	fcall	putch_usart_buffered
	movlw	'g'
	fcall	putch_usart_buffered
	movlw	'.'
	fcall	putch_usart_buffered
	movlw	'.'
	fcall	putch_usart_buffered
	movlw	'.'
	fcall	putch_usart_buffered
	movlw	'.'
	fcall	putch_usart_buffered
	movlw	'\r'
	fcall	putch_usart_buffered
	movlw	'\n'
	fcall	putch_usart_buffered
	
	fcall	init_lcd

	movlw	'!'		; preload the first character to echo back.
	movwf	main_serial_getch ; It's garbage, and can be ignored...

main_loop:
	;; echo back the previous character.
	movfw   main_serial_getch
	banksel	0
        lcall   putch_usart_buffered
	
	;; wait for a char on the serial port. Save a copy of it, as we need
	;; to echo it back again after we've performed the appropriate action.
	fcall	getch_usart_buffered
	movwf	main_serial_getch

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
	lcall	lcd_write	; or lcd_putch for cooked input
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

