	include	"processor_def.inc"

        include	"common.inc"
	include	"memory.inc"
	include "piceeprom.inc"
#define HAVE_SERIAL_EXTERNS
	include "serial.inc"
	
	GLOBAL	putch_usart
#if 0
	GLOBAL	putch_hex_usart
	GLOBAL	putch_BCD_usart
#endif
	GLOBAL	getch_usart
#if 0
	GLOBAL	getch_usart_timeout
#endif
	GLOBAL	init_serial
#if 0
	GLOBAL	putch_cstr_worker
#endif	

serial	CODE

	;; this code does not need to reside in page 0.
	CONSTANT	_block_start = $
check_start_serial:	

;;; 9600 baud, highspeed
 #define USART_HIGHSPEED 1
 #define USART_BAUD_INITIALIZER 0x19
;;; 1200 baud, lowspeed
;;; #define USART_HIGHSPEED 0
;;; #define USART_BAUD_INITIALIZER 0xC4
	
init_serial:
	;; The USART requires that bits [21] of TRISB are enabled, or you'll
	;; get unpredictable results from it. Some PICs won't work at all,
	;; and others will look like they're working but fail unpredictably.
	;; NOTE: that's specific to the 16f62[78] series; dunno about others.
	banksel	USART_X_TRIS
  	bsf	USART_RX_TRIS
 	bsf	USART_TX_TRIS
	
	;; high-speed port speed math:
	;; Desired baud rate = Fosc / (16 * (X + 1))
	;; e.g. 4800 = 10000000 / (16 * (X + 1))
	;;      2083.333 = 16X + 16
	;;      2067.333 = 16X
	;;      X = 129.2 (use 129)
	;; other values @ 10MHz clock:
	;; 4800: X = 129 (129.2)
	;; 9600: X = 64 (64.104)
	;; 19200: X = 31.55 (works @ 32)
	;; 38400: X = 15.27 (not usable)
	;; 57600: X = 9.85
	;; 115200: 4.43
	;; 230400: 1.7127

	;; low-speed math:
	;; Desired baud rate = Fosc / (64 * (X + 1))
	;; e.g. 4800 = 10000000 / (64 * (X + 1))
	;;      2083.333 = 64X + 64
	;;      2019.333 = 64X
	;;      X = 31.55 (use 32)
	;; Others @ 10MHz:
	;;    1200: 129.2
	;;    2400: 64.1
	;;    4800: 31.55 (verified, 32 works)
	;;    9600: 15.28 (use 15; not tested)
	;;    19200: 7.14 (use 7; works)
	;;    38400: 3.07 (tried 3; not stable)
	;;    57600: 1.7126 (not tested, seems unlikely to work)

	banksel	TXSTA
#if USART_HIGHSPEED
	bsf	TXSTA, BRGH	; high-speed mode if 'bsf'; low-speed for 'bcf'
#else
	bcf	TXSTA, BRGH	; low-speed
#endif
	movlw	USART_BAUD_INITIALIZER ; 'X', per above comments, to set baud rate
	movwf	SPBRG

	bcf	TXSTA, CSRC	; unimportant
	bcf	TXSTA, TX9	; 8-bit
	bsf	TXSTA, TXEN	; enable transmit
	bcf	TXSTA, SYNC	; async mode
	bcf	TXSTA, TX9D	; (unused, but we'll clear it anyway)
	
	bcf	STATUS, RP0	; back to page 0

	bcf	RCSTA, RX9	; 8-bit mode
	bcf	RCSTA, SREN	; unused (in async mode)
	bsf	RCSTA, CREN	; receive enabled
	bcf	RCSTA, FERR	; clear framing error bit
	bcf	RCSTA, RX9D	; unused

	bsf	RCSTA, SPEN	; serial port enabled

	movlw	0x00
	movwf	TXREG		; transmit dummy char to start transmitter

	return

#if 0
;;; ************************************************************************
;;; * putch_hex_usart
;;; *
;;; * put the byte's value, in hex, on the serial usart.
;;; *
;;; * Input:
;;; *
;;; *   W	byte to send
;;; *
;;; ************************************************************************

putch_hex_usart:
	banksel	serial_work_tmp
	movwf	serial_work_tmp
	swapf	serial_work_tmp, W
	banksel	0
	andlw	0x0F		; grab low 4 bits of serial_work_tmp
	sublw	0x09		; Is it > 9?
	skpwgt			;   ... yes, so skip the next line
	goto	_send_under9	; If so, go to send_under9
	sublw	0x09		; undo what we did
	addlw	'A' - 10	; make it ascii
	goto	_send_hex

_send_under9:
	sublw	0x09		; undo what we did
	addlw	'0'		; make it ascii
_send_hex:
	PUTCH_USART_INLINE
	
	banksel	serial_work_tmp
	movfw	serial_work_tmp
	banksel	0
	andlw	0x0F
	sublw	0x09
	skpwgt
	goto	_send_under9_2
	sublw	0x09		; undo what we did
	addlw	'A' - 10	; make it ascii
	goto	putch_usart
	
_send_under9_2:
	sublw	0x09		; undo what we did
	addlw	'0'		; make it ascii
	goto	putch_usart

;;; ************************************************************************
;;; * putch_BCD_usart
;;; *
;;; * put the byte's value, in BCD, on the serial usart.
;;; *
;;; * Input:
;;; *
;;; *   W	byte to send
;;; *
;;; ************************************************************************

putch_BCD_usart:
	banksel	serial_work_tmp
	movwf	serial_work_tmp
	swapf	serial_work_tmp, W
	banksel	0
	andlw	0x0F
	addlw	'0'

	PUTCH_USART_INLINE

	banksel	serial_work_tmp
	movfw	serial_work_tmp
	banksel	0
	andlw	0x0F
	addlw	'0'
	;; fall through to putch_usart
#endif

;;; ************************************************************************
;;; * putch_usart
;;; *
;;; * put a character on the serial usart.
;;; *
;;; * Input:
;;; *    W	byte to send
;;; *
;;; ************************************************************************
putch_usart:
	PUTCH_USART_INLINE
	return

;;; ************************************************************************
;;; * getch_usart
;;; *
;;; * Block until a character is available from the USART. When a char is
;;; * received, echo it back out the usart.
;;; ************************************************************************

getch_usart:
	banksel	RCSTA
 	btfsc	RCSTA, OERR	; check for overrun
 	goto	_ovrrun

	btfss	PIR1, RCIF	; make sure there's data to receive
	goto	getch_usart	; loop if not

_retry:	
        movfw	RCREG		; grab the received character

	;; check for framing errors
	btfsc	RCSTA, FERR
	goto	_retry
	
#ifdef SERIAL_ECHO
	movwf	echo_buf	; save a copy
	call	putch_usart	; send a copy back out
	movfw	echo_buf	; restore the saved copy
#endif
	return

_ovrrun	bcf	RCSTA, CREN	; Clear overrun. Documented procedure: clear
	movfw	RCREG		; CREN, then flush the fifo by reading three
	movfw	RCREG		; bytes (the size of the backing store), and
	movfw	RCREG		; then re-enable CREN.
	bsf	RCSTA, CREN
	goto	getch_usart	; retry

#if 0
;;; ************************************************************************
;;; * getch_usart_timeout
;;; *
;;; * Wait about a second for a character from the USART. When a char is
;;; * received, echo it back out the usart. If nothing is received before
;;; * the timeout, we return 0. So the caller can't expect 0 as a valid
;;; * return character...
;;; ************************************************************************

getch_usart_timeout:
	banksel	serial_timeout_0
	clrf	serial_timeout_0
	clrf	serial_timeout_1
	clrf	serial_timeout_2
	banksel	0
_getch_usart_timeout_loop:
 	btfsc	RCSTA, OERR	; check for overrun
 	goto	overrun_timeout

	;; increment timeout timer. If we roll over, we're done.
	banksel	serial_timeout_0
	incfsz	serial_timeout_0, F
	goto	_getch_usart_timeout_loop1
	incfsz	serial_timeout_1, F
	goto	_getch_usart_timeout_loop1
	incf	serial_timeout_2, F
	movfw	serial_timeout_2
	banksel	0
	xorlw	0x02		; somewhere around a half second @ 20MHz
	skpnz
	retlw	0x00		; failed to rx in the allotted time
	
_getch_usart_timeout_loop1:
	banksel	0
	btfss	PIR1, RCIF	; make sure there's data to receive
	goto	_getch_usart_timeout_loop	; loop if not

        movfw	RCREG		; grab the received character

	;; check for framing errors
	btfsc	RCSTA, FERR
	goto	_getch_usart_timeout_loop
	
#ifdef SERIAL_ECHO
	movwf	echo_buf	; save a copy
	call	putch_usart	; send a copy back out
	movfw	echo_buf	; restore the saved copy
#endif
	return

overrun_timeout:
	bcf	RCSTA, CREN	; Clear overrun. Documented procedure: clear
	movfw	RCREG		; CREN, then flush the fifo by reading three
	movfw	RCREG		; bytes (the size of the backing store), and
	movfw	RCREG		; then re-enable CREN.
	bsf	RCSTA, CREN
	goto	_getch_usart_timeout_loop	; retry
#endif
	
#if 0
putch_cstr_worker:
	PUTCH_CSTR_INLINEWKR
	;; no 'return' necessary; INLINEWKR ends with a 'goto'
#endif
	
check_end_serial:
	if ( ((_block_start & 0x1800) >> 11) != (($ & 0x1800) >> 11) )
	ERROR	"serial.asm crosses a page boundary"
	endif
	
	END
