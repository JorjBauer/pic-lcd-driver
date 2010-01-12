;;; Buffered serial routines.
;;; These sit on top of serial.asm (getch_usart and putch_usart).
;;; Designed to have sbuf_rptr_in/out, start_serial_rbuffer, et al in one page.

;;; Required memory:
;;; sbuf_rptr_in, sbuf_rptr_out, sbuf_rsize, start_serial_rbuffer -> end_serial_rbuffer
;;; sbuf_tmpw, sbuf_tmpr

    EXTERN	  putch_usart_buffered
    EXTERN	  getch_usart_buffered


SERBUF_INIT	macro
	banksel	sbuf_rptr_in
	movlw	start_serial_rbuffer
	movwf	sbuf_rptr_in
	movwf	sbuf_rptr_out
	clrf	sbuf_rsize

	banksel	PIE1
	bsf	PIE1, RCIE

	banksel	0
	bsf	INTCON, PEIE

	;; have to enable GIE for serial to work, now...
        banksel INTCON
        bsf     INTCON, GIE
        banksel 0

	ENDM
	
SERBUF_INTERRUPT	macro
	LOCAL	end_rd_serbuf

	;; RCIF is set when there's data waiting to be read.
	banksel	PIR1
	btfss	PIR1, RCIF
	goto	end_rd_serbuf

	banksel	sbuf_rptr_in	; prepare FSR before we call getch_usart
	movfw	sbuf_rptr_in
	movwf	FSR
	banksel	0		; protect getch_usart call
	fcall	getch_usart	; doesn't modify FSR
	bankisel start_serial_rbuffer ; make sure INDF can address buffer
	banksel	sbuf_rsize
	movwf	INDF		; store rec'd byte in buffer
	incf	sbuf_rsize, F   ; add 1 byte to the queue count
	incf	sbuf_rptr_in, F ; move queue count pointer
	movfw	sbuf_rptr_in    ; check for end-of-queue and loop back to start
	xorlw	end_serial_rbuffer+1
	movlw	start_serial_rbuffer	; preload; doesn't change Z
	skpnz
	movwf	sbuf_rptr_in

end_rd_serbuf:
	banksel	0	; protect caller from our modifications
	bankisel 0
	ENDM
