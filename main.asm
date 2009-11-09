	include "processor_def.inc"
	include "common.inc"
	include "memory.inc"
	include "serial.inc"
	include "lcd.inc"

	__CONFIG ( _CP_OFF & _DEBUG_OFF & _WRT_ENABLE_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC )

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
	banksel	ADCON0
	movlw	b'01100000'	; AN0 is analog, others digital. Powered off.
	movwf	ADCON0
	banksel	ADCON1
	movlw	b'11001110'
	movwf	ADCON1

	banksel	TRISA
	movlw	b'00000000'	; all outputs
	movwf	TRISA
	banksel	TRISB
	movlw	b'00000000'	; all outputs
	movwf	TRISB
	banksel	TRISC
	movlw	b'11000000'	; RC7 is serial RX, RC6 is TX. Both must be set per pic16f870 docs, p. 63
	movwf	TRISC
	banksel	0

	fcall	init_serial

	PUTCH_CSTR_INLINE putch_cstr_worker, msg_init

	fcall	init_lcd
	
loop:
;;; 	movlw	'a'
;;; 	fcall	putch_usart
	lgoto loop
	

	END
	