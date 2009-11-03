	include	"processor_def.inc"
	include	"memory.inc"
	
	GLOBAL	eep_read
	GLOBAL	eep_write
	IFDEF __16F870
	GLOBAL	fpm_read
#if 0
	GLOBAL	fpm_write
#endif
	ENDIF

piceeprom	code

	;; this code is self-contained. As long as it doesn't cross a page
	;; boundary, it will be fine. It can live anywhere.

;;; ************************************************************************
;;; * eep_read
;;; *
;;; * Input
;;; *	W:	contains address to read
;;; *
;;; * Output
;;; *	W:	contains byte read
;;; ************************************************************************

	
eep_read:
	banksel	EEADR
	movwf	EEADR
	banksel	EECON1
	IFDEF	__16F870
	bcf	EECON1, EEPGD
	ENDIF
	bsf	EECON1, RD
	banksel	EEDATA
	movfw	EEDATA
	
	banksel	0
	return

	
;;; ************************************************************************
;;; * eep_write
;;; *
;;; * Input
;;; *	W:	contains data to write
;;; *   arg2:	contains address to write
;;; *
;;; * Output
;;; *	W:	contains byte read
;;; *
;;; * Trashes arg1.
;;; ************************************************************************

eep_write:
	movwf	arg1
	banksel	EECON1
	btfsc	EECON1, WR	; wait for EECON's write bit to be clear
	goto	$-1

	;; load the address
	banksel	arg2
	movfw	arg2
	banksel	EEADR
	movwf	EEADR

	;; load the data
	banksel	arg1
	movfw	arg1
	banksel	EEDATA
	movwf	EEDATA

	;; The only instructions that modify the carry flag are ADD, R[LR]F,
	;; and SUB instructions. So we use it as a 1-bit holding cell here:
	bcf	STATUS, C	; Use the Carry flag as a test for whether or
	btfsc	INTCON, GIE	; not interrupts were originally enabled so 
	bsf	STATUS, C	; we can put them back afterwards.

	banksel	EECON1		; start of magic code from docs
	IFDEF __16F870
	bcf	EECON1, EEPGD	; point to data memory
	ENDIF
	bsf	EECON1, WREN
	bcf	INTCON, GIE
	movlw	0x55
	movwf	EECON2
	movlw	0xAA
	movwf	EECON2
	bsf	EECON1, WR	; End of magic code
	
	bcf	EECON1, WREN	; Disable writes

	banksel	INTCON

	btfsc	STATUS, C	; re-enable interrupts if they had been on
	bsf	INTCON, GIE

	banksel	EECON1
	btfsc	EECON1, WR	; wait for EECON's write bit to be clear
	goto	$-1

	banksel	0
	
	return

	IFDEF __16F870

;;; fpm_read: put address location in arg1(high)/arg2(low).
;;; results are left in EEDATH (high) and EEDATA (low).
fpm_read:
	banksel	arg1
	movfw	arg1
	banksel	EEADRH
	movwf	EEADRH
	banksel	arg2
	movfw	arg2
	banksel	EEADR
	movwf	EEADR
	banksel	EECON1
	bsf	EECON1, EEPGD
	bsf	EECON1, RD	; start of required sequence
	nop
	nop			; end required sequence
	banksel	0
	return

#if 0
;;; not using fpm_write in production from this code.
	
;;; fpm_write: write to flash program memory.
;;; uses arg1(high)/arg2(low) for address.
;;; uses fpm_data_low[0..3] and fpm_data_high[0..3] for data.
;;; MUST write four bytes at a time, per hardware spec. And the address
;;; must be aligned on a multiple of 4.
;;; Destroys FSR.
fpm_write:
	movfw	arg1
	banksel	EEADRH
	movwf	EEADRH
	movfw	arg2
	banksel	EEADR
	movwf	EEADR
	bankisel	fpm_data_low_0
	banksel	EEDATA		; EEDATA, EEDATH and EEADR are all in the same bank. EECON is *not*.
	movlw	fpm_data_low_0
	movwf	FSR
fpm_write_loop:
	movfw	INDF
	movwf	EEDATA
	incf	FSR, F
	movfw	INDF
	movwf	EEDATH
	incf	FSR, F
	bsf	STATUS, RP0	; bank 3
	bsf	EECON1, EEPGD
	bsf	EECON1, WREN

	;; The only instructions that modify the carry flag are ADD, R[LR]F,
	;; and SUB instructions. So we use it as a 1-bit holding cell here:
	bcf	STATUS, C	; Use the Carry flag as a test for whether or
	btfsc	INTCON, GIE	; not interrupts were originally enabled so 
	bsf	STATUS, C	; we can put them back afterwards.
	
	bcf	INTCON, GIE	; disable interrupts
	
	movlw	0x55		; start of required sequence
	movwf	EECON2
	movlw	0xAA
	movwf	EECON2
	bsf	EECON1, WR
	nop
	nop			; end of required sequence
	bcf	EECON1, WREN

	btfsc	STATUS, C	; re-enable interrupts, but only if they 
	bsf	INTCON, GIE	;   were enabled previously
	
	bcf	STATUS, RP0	; bank 2
	incf	EEADR, F
	movfw	EEADR
	andlw	0x03
	xorlw	0x03
	btfsc	STATUS, Z	; exit if we've done our 4 words
	goto	fpm_write_loop

	bankisel 0
	banksel	0
	return
#endif
	
	ENDIF

	END
	