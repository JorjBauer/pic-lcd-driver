	EXTERN	eep_read
	EXTERN	eep_write

;;; 16f877a only: flash program read/write
        IFDEF __16F877A
	EXTERN	fpm_read
#if 0
	EXTERN	fpm_write
#endif
	ENDIF

	IFDEF __16F870
	EXTERN	   fpm_read
#if 0
	EXTERN	fpm_write
#endif
	ENDIF

