        include "processor_def.inc"
	include "memory.inc"
	include "pins.inc"
	include "common.inc"
	include "serial.inc" 	; for debugging

	GLOBAL	init_lcd
	GLOBAL	lcd_write

TOGGLE_E	macro
	bsf	LCD_E		; minimum 450nS hold time...
	nop
	bcf	LCD_E
	ENDM
	
piclcd	code

init_lcd:
	banksel	LCD_DATATRIS
	movlw	0x00		; all outputs ('on' == 'in'; 'off' == 'out')
	movwf	LCD_DATATRIS
	banksel	0

	movlw	'A'
	fcall	putch_usart
	
	;; lcd 8-bit initialization procedure, per HD44780 documentation
	;; sleep ~15mS (@3.5795 MHz)
	clrf    lcd_init_tmp1
	movlw	-18
	movwf	lcd_init_tmp2
	incfsz	lcd_init_tmp1, F
	goto    $-1
	incfsz  lcd_init_tmp2, F
	goto    $-3
	
	movlw	'B'
	fcall	putch_usart
	
	;; RS=0; RW=0; DB[7..0] = 0011xxxx; toggle E
	movlw	b'00110000'
	call	send_init
	;; sleep ~4.1mS
	clrf	lcd_init_tmp1
	movlw	-5
	movwf	lcd_init_tmp2
	incfsz	lcd_init_tmp1, F
	goto    $-1
	incfsz  lcd_init_tmp2, F
	goto    $-3

	movlw	'C'
	fcall	putch_usart
	
	;; RS=0; RW=0; DB[7..0] = 0011xxxx; toggle E
	movlw	b'00110000'
	call	send_init
	;; sleep ~100uS
	clrf	lcd_init_tmp1
	incfsz	lcd_init_tmp1, F
	goto	$-1
	
	movlw	'D'
	fcall	putch_usart
	
	;; RS=0; RW=0; DB[7..0] = 0011NFxx; toggle E
	movlw	b'00110000'	; 1 line, 5x7 font
	call	send_init

	;; wait for BF
	call	wait_bf
	
	movlw	'G'
	fcall	putch_usart
	
	;; RS=0; RW=0; DB[7..0] = 00001000 - disable display; toggle E
	movlw	b'00001000'
	call	send_init
	;; wait for BF
	call	wait_bf
	
	movlw	'H'
	fcall	putch_usart
	
	;; RS=0; RW=0; DB[7..0] = 00000001 - enable display; toggle E
	movlw	b'00000001'
	call	send_init
	;; wait for BF
	call	wait_bf
	
	movlw	'I'
	fcall	putch_usart
	
	;; RS=0; RW=0; DB[7..0] = 0 0 0 0 0 1 I/D S; toggle E
	movlw	b'00000101'	; auto-shift in incremental direction
	call	send_init
	;; wait for BF
	call	wait_bf
	;; Initialization is complete

	movlw	'J'
	fcall	putch_usart
	
	;; write an 'H' to the display
	movlw	'H'
	call	lcd_write
	
	movlw	'K'
	fcall	putch_usart
	
	return

lcd_write:
	bsf	LCD_RS
	bcf	LCD_RW
	movwf	LCD_DATAPORT
	TOGGLE_E
	goto	wait_bf

	
wait_bf:
	bcf	LCD_RS
	bsf	LCD_RW
	banksel	LCD_DATATRIS
	bsf	LCD_DATATRIS, 7
	banksel	0
bf_retry:	
	TOGGLE_E
	btfss	LCD_DATAPORT, 7
	goto	bf_retry
	bcf	LCD_RW

	banksel	LCD_DATATRIS
	bcf	LCD_DATATRIS, 7
	banksel	0


	return


send_init:	
	bcf	LCD_RS
	bcf	LCD_RW
	movwf	LCD_DATAPORT
	TOGGLE_E
	return
	
	END

