#define LCD_DATAPORT PORTB
#define LCD_DATATRIS TRISB
#define LCD_E 	     PORTA,4
#define LCD_RW 	     PORTB,0
#define LCD_RS 	     PORTB,3

;a0-a3, b4-b7
;a4, b0, b3

TOGGLE_E        macro
        banksel PORTA
        bsf     LCD_E           ; minimum 450nS hold time...
        nop
        bcf     LCD_E
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

WRITE_W_ON_LCD	macro
	movwf	lcd_write_tmp ; can't do bitwise work directly on W (grrr)

	;low nybble of W goes on A[0:3]; high nybble goes on B[4:7]. Note that 
	;lcd_write_tmp must be in the same page as PORTA.
	banksel	PORTA
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
	ENDM

; skip the next statement if the busy flag is clear
READ_BF_AND_SKIP	MACRO
        banksel PORTB
        btfsc   PORTB, 7
	ENDM

RESET_BF	MACRO
	banksel	TRISB
	bcf	TRISB, 7 ; back as an output
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


