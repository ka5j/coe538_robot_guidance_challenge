;***************************************************************************
; timers.inc – TOF-based timing support for eebot (HCS12)
;
; Provides:
;   ENABLE_TOF – configure main timer for TOF interrupts
;   TOF_ISR    – increments TOF_COUNTER each timer overflow
;
; Uses RAM variable (defined in main.asm):
;   TOF_COUNTER
;***************************************************************************

        XREF    TOF_COUNTER
        XDEF    ENABLE_TOF, TOF_ISR

;---------------------------------------------------------------------------
; ENABLE_TOF – enable main timer and TOF interrupt
;   - Uses TSCR1, TSCR2, TFLG2 (from derivative.inc)
;   - Prescaler = /16, TOI = 1
;---------------------------------------------------------------------------
ENABLE_TOF:
        LDAA    #%10000000
        STAA    TSCR1              ; TEN=1, enable timer
        STAA    TFLG2              ; clear TOF flag by writing 1

        LDAA    #%10000100         ; TOI=1, prescale=÷16
        STAA    TSCR2
        RTS

;---------------------------------------------------------------------------
; TOF_ISR – Timer Overflow Interrupt Service Routine
;   - Increments TOF_COUNTER every overflow (~43 ms at this prescale)
;---------------------------------------------------------------------------
TOF_ISR:
        INC     TOF_COUNTER        ; second-level counter (~23 Hz)
        LDAA    #%10000000
        STAA    TFLG2              ; clear TOF flag
        RTI
