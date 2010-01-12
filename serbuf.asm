	include	"processor_def.inc"
	include	"memory.inc"
	include "serial.inc"
	include "common.inc"
	
.serbuf	CODE

	GLOBAL	putch_usart_buffered
	GLOBAL	getch_usart_buffered
	
putch_usart_buffered:
	banksel	sbuf_tmpw
	movwf	sbuf_tmpw	; save the char to xmit
	
pb_loop
	;; While TXIF is clear, we'll wait; there's data already waiting to go
	banksel	PIR1
	btfss	PIR1, TXIF
	goto	pb_loop

	banksel	sbuf_tmpw	; transmit the byte
	movfw	sbuf_tmpw
	banksel	0
	lgoto	putch_usart

getch_usart_buffered:
	banksel sbuf_rsize
gb_spin
	movfw   sbuf_rsize
	addlw   0
	skpnz
	goto    gb_spin
	
;;;  pull a byte from the queue
	bankisel start_serial_rbuffer
	movfw   sbuf_rptr_out
	movwf   FSR
	movfw   INDF		; grab byte from buffer's current read head
	
	movwf   sbuf_tmpr	; save the byte just rx'd
	decf    sbuf_rsize, F	; decrease queue size
	incf    sbuf_rptr_out, F ; move buffer read head
	movfw   sbuf_rptr_out	 ; ... it's circular, so see if we hit the end
	xorlw   end_serial_rbuffer+1
	movlw   start_serial_rbuffer ; preload, doesn't change Z
	skpnz
	movwf   sbuf_rptr_out ; rolled around the buffer...
	movfw   sbuf_tmpr	; put back the byte rx'd, which we now return
	
	banksel 0
	bankisel 0
	return

	END
	