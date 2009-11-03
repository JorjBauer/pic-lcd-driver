;;; *********************************************************************
;;; * Useful macros:
;;; *
;;; *
;;; * SKPWGT: skip if W greater than
;;; * SKPWLE: skip if W less than
;;; *
;;; * Usage: 
;;; *
;;; * movlw (value1)
;;; * sublw (value2)
;;; * skpwgt            ; will skip if (value1) > (value2)
;;; *

#define SKPWGT  SKPNC
#define skpwgt  skpnc
#define SKPWLE SKPC
#define skpwle skpc
#define CLC    BCF STATUS, C
#define clc    bcf STATUS, C


;;; * fcall <subroutine>
;;; *
;;; * sets up pagesel appropriately for subroutine (using 'lcall'), and 
;;; * sets pagesel properly on return
;;; *
fcall macro subroutine_name
      local dummy_fcall
      lcall subroutine_name
      pagesel dummy_fcall
dummy_fcall:
	endm
