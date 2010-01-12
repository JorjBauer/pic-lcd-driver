        Processor       16f627a
        Radix           DEC
        EXPAND

        include         "p16f627a.inc"

;;; pins specific to serial on this processor
#define USART_X_TRIS TRISB
#define USART_RX_TRIS TRISB, 1
#define USART_TX_TRIS TRISB, 2
