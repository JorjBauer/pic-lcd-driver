#define LCD_DATAPORT PORTB
#define LCD_DATATRIS TRISB
#define LCD_E1 	     PORTA,6
#define LCD_E2 	     PORTA,7
#define LCD_RW 	     PORTB,0
#define LCD_RS 	     PORTB,3

;a0-a3, b4-b7
;a4, b0, b3

TOGGLE_E1        macro
        banksel PORTA
        bsf     LCD_E1           ; minimum 450nS hold time...
        nop
        bcf     LCD_E1
        ENDM

TOGGLE_E2        macro
        banksel PORTA
        bsf     LCD_E2           ; minimum 450nS hold time...
        nop
        bcf     LCD_E2
        ENDM

ASSERT_E1	macro
	banksel	PORTA
	bsf	LCD_E1
	nop
	ENDM

DEASSERT_E1	macro
	banksel	PORTA
	bcf	LCD_E1
	ENDM

ASSERT_E2	macro
	banksel	PORTA
	bsf	LCD_E2
	nop
	ENDM

DEASSERT_E2	macro
	banksel	PORTA
	bcf	LCD_E2
	ENDM

MOVEBIT	macro	from, to, bitnum
	btfss	from, bitnum
	bcf	to, bitnum
	btfsc	from, bitnum
	bsf	to, bitnum
	ENDM

SET_RS_CLEAR_RW macro
        banksel PORTB
        bsf     LCD_RS
        bcf     LCD_RW
	ENDM

CLEAR_RS_AND_RW macro
        banksel PORTB
        bcf     LCD_RS
        bcf     LCD_RW
	ENDM

READ_W_FROM_LCD	macro
	banksel	PORTA
	movfw	PORTA
	andlw	0x0F
	movwf	lcd_write_tmp
	movfw	PORTB
	andlw	0xF0
	iorwf	lcd_write_tmp, W
	ENDM

WRITE_W_ON_LCD	macro
	banksel	PORTA
	movwf	lcd_write_tmp ; can't do bitwise work directly on W (grrr)

	;low nybble of W goes on A[0:3]; high nybble goes on B[4:7]. Note that 
	;lcd_write_tmp must be in the same page as PORTA.

	MOVEBIT lcd_write_tmp, PORTA, 0
	MOVEBIT lcd_write_tmp, PORTA, 1
	MOVEBIT lcd_write_tmp, PORTA, 2
	MOVEBIT lcd_write_tmp, PORTA, 3
	MOVEBIT lcd_write_tmp, PORTB, 4
	MOVEBIT lcd_write_tmp, PORTB, 5
	MOVEBIT lcd_write_tmp, PORTB, 6
	MOVEBIT lcd_write_tmp, PORTB, 7

	ENDM

; initialize reading of the BF flag.
START_READ_BF	MACRO
        banksel PORTB
        bcf     LCD_RS
        bsf     LCD_RW
	banksel	TRISB
        bsf     TRISB, 7 ; now an input
	bsf	TRISB, 6
	bsf	TRISB, 5
	bsf	TRISB, 4
	bsf	TRISA, 3
	bsf	TRISA, 2
	bsf	TRISA, 1
	bsf	TRISA, 0
	ENDM

; skip the next statement if the busy flag is clear
READ_BF_AND_SKIP	MACRO
        banksel PORTB
        btfsc   PORTB, 7
	ENDM

RESET_BF	MACRO
	banksel	TRISB
	bcf	TRISB, 7 ; back as an output
	bcf	TRISB, 6
	bcf	TRISB, 5
	bcf	TRISB, 4
	bcf	TRISA, 3
	bcf	TRISA, 2
	bcf	TRISA, 1
	bcf	TRISA, 0
	banksel	0
	ENDM



init_tris MACRO
      ;set up data pins to LCD as outputs (cleared)
      banksel	TRISA
      bcf	TRISA, 0
      bcf	TRISA, 1
      bcf	TRISA, 2
      bcf	TRISA, 3
      banksel	TRISB
      bcf	TRISB, 4
      bcf	TRISB, 5
      bcf	TRISB, 6
      bcf	TRISB, 7

      ; setup E, RW, RS
      banksel TRISA
      bcf     TRISA, 4
      banksel TRISB
      bcf     TRISB, 0
      bcf     TRISB, 3
      banksel 0
      ENDM


