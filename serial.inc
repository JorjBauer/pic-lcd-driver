#ifndef HAVE_SERIAL_EXTERNS
	EXTERN	init_serial
	EXTERN	putch_usart
	EXTERN	getch_usart
	EXTERN	getch_usart_timeout
	EXTERN	putch_hex_usart
	EXTERN	putch_BCD_usart
	EXTERN	putch_cstr_worker
#endif

#ifdef DISABLE_SERIAL
#define SKIP_UNLESS_SERIAL_DATA	goto	$+2
#define SKIP_IF_SERIAL_DATA	nop
#else
#define SKIP_UNLESS_SERIAL_DATA	btfsc	PIR1, RCIF
#define SKIP_IF_SERIAL_DATA	btfss	PIR1, RCIF
#endif

;;; putch_cstr_inlinewkr can be used to minimize the code size used by cstr
;;; inside of a module. Make sure there's one PUTCH_CSTR_INLINEWKR with a
;;; unique symbol name for that module, and then call PUTCH_CSTR_INLINE_DATA
;;; with that symbol's name and the string as arguments. (See bootloader.asm.)

PUTCH_CSTR_INLINEWKR	MACRO
	LOCAL	read_next
	LOCAL	not_increment
read_next:
	banksel	0
	fcall	fpm_read
	banksel	arg2
	incfsz	arg2, F
	goto	not_increment
	incf	arg1, F
not_increment:
	;; EEDATH and EEDATA have the data. BUT it's a packed string -
	;; the program memory is only 14 bits wide. So we have to do some
	;; work to extract it. And we can only access each register once,
	;; at which point the PIC invalidates the value. So grab a temporary
	;; copy of EEDATA, which we'll need to touch the high bit of...
	banksel	EEDATA
	movfw	EEDATA
	banksel	serial_work_tmp
	movwf	serial_work_tmp
	
	banksel	EEDATH
	movfw	EEDATH
	banksel	serial_work_tmp2
	movwf	serial_work_tmp2
	clc
	banksel	serial_work_tmp
	btfsc	serial_work_tmp, 7
	setc
	banksel	serial_work_tmp2
	rlf	serial_work_tmp2, W
	banksel	0
	xorlw	0x00
	skpnz
	return
	fcall	putch_usart
	;; now repeat with the low 7 bits
	banksel	serial_work_tmp
	movfw	serial_work_tmp
	andlw	0x7F
	banksel	0
	skpnz
	return
	fcall	putch_usart
	goto	read_next
	ENDM

PUTCH_CSTR_INLINE_DATA	MACRO	SYMBOL, CSTR_DATA
	LOCAL	string_data
	LOCAL	done_macro
	movlw	high(string_data)
	banksel	arg1
	movwf	arg1
	movlw	low(string_data)
	banksel	arg2
	movwf	arg2
	pagesel	SYMBOL
	call	SYMBOL
	goto	done_macro
	;; construct a lookup table containing the string, null-terminated.
string_data:
	da	CSTR_DATA
	dw	0x0000
done_macro:
	ENDM

PUTCH_CSTR_INLINE	MACRO	SYMBOL, STRING_PTR
	movlw	high(STRING_PTR)
	movwf	arg1
	movlw	low(STRING_PTR)
	movwf	arg2
	fcall	SYMBOL
	ENDM
	
PUTCH_CSTR_USART	MACRO	CSTR_DATA
	LOCAL	string_data
	LOCAL	read_next
	LOCAL	not_increment
	LOCAL	done_macro
	
	movlw	high(string_data)
	banksel	arg1
	movwf	arg1
	movlw	low(string_data)
	banksel	arg2
	movwf	arg2
	pagesel	read_next
read_next:
	banksel	0
	fcall	fpm_read
	banksel	arg2
	incfsz	arg2, F
	goto	not_increment
	incf	arg1, F
not_increment:
	;; EEDATH and EEDATA have the data. BUT it's a packed string -
	;; the program memory is only 14 bits wide. So we have to do some
	;; work to extract it. And we can only access each register once,
	;; at which point the PIC invalidates the value. So grab a temporary
	;; copy of EEDATA, which we'll need to touch the high bit of...
	banksel	EEDATA
	movfw	EEDATA
	banksel	serial_work_tmp
	movwf	serial_work_tmp
	
	banksel	EEDATH
	movfw	EEDATH
	banksel	serial_work_tmp2
	movwf	serial_work_tmp2
	clc
	banksel	serial_work_tmp
	btfsc	serial_work_tmp, 7
	setc
	banksel	serial_work_tmp2
	rlf	serial_work_tmp2, W
	banksel	0
	xorlw	0x00
	skpnz
	goto	done_macro
	fcall	putch_usart
	;; now repeat with the low 7 bits
	banksel	serial_work_tmp
	movfw	serial_work_tmp
	andlw	0x7F
	banksel	0
	skpnz
	goto	done_macro
	fcall	putch_usart
	goto	read_next

	;; construct a lookup table containing the string, null-terminated.
string_data:
	da	CSTR_DATA
	dw	0x0000
	
done_macro:	
	
	ENDM
	