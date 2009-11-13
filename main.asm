	include "processor_def.inc"
	include "common.inc"
	include "memory.inc"
	include "serial.inc"
	include "lcd.inc"

	__CONFIG ( _CP_OFF & _LVP_OFF & _BODEN_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC )

.string	code
msg_init
	da	"Initializing...\r\n"
	dw	0x0000

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

	banksel	TRISA
	movlw	b'00000000'	; all outputs
	movwf	TRISA
	banksel	TRISB
	movlw	b'00000000'	; all outputs
	movwf	TRISB
#if 0
	banksel	TRISC
	movlw	b'11000000'	; RC7 is serial RX, RC6 is TX. Both must be set per pic16f870 docs, p. 63
	movwf	TRISC
#endif
	banksel	0

	fcall	init_memory
	
	fcall	init_serial

#if 0
	PUTCH_CSTR_INLINE putch_cstr_worker, msg_init
#endif
	
	fcall	init_lcd
	
loop:
	;; wait for a char on the serial port
	lcall	getch_usart
	banksel	main_serial_tmp
	movwf	main_serial_tmp

	btfss	main_lcd_mode, 0 ; did we just receive an escape char?
	goto	not_escape_mode
is_escape_mode:
	;; last received an escape character, so clear the escape mode, send
	;; this character as a command to the LCD, and then loop.
	bcf	main_lcd_mode, 0
	movfw	main_serial_tmp
	fcall	lcd_send_command
	goto	loop
	
not_escape_mode:
	;; If we receive an escape character, then set escape mode and loop.
	sublw	0xFE
	skpz
	goto	not_escape_char
is_escape_char:
	bsf	main_lcd_mode, 0
	goto	loop
	
not_escape_char:	
	;; otherwise send it to the LCD display.
	movfw	main_serial_tmp	
	lcall	lcd_putch
	movfw	main_serial_tmp	;echo back down the line, too.
	fcall	putch_usart
	goto loop

	END

