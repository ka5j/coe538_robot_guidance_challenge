;***************************************************************************
; motors.inc – Motor control routines for eebot (HCS12)
;
; Provides:
;   MOTOR_INIT      – configure DDRs and turn motors off
;   INIT_FWD        – go forward for FWD_INT ticks
;   INIT_REV        – go reverse for REV_INT ticks
;   INIT_ALL_STP    – stop both motors
;   INIT_FWD_TRN    – forward-turn (spin) for FWD_TRN_INT ticks
;   INIT_REV_TRN    – reverse-turn (spin) for REV_TRN_INT ticks
;
; Uses RAM variables (defined in main.asm):
;   TOF_COUNTER, T_FWD, T_REV, T_FWD_TRN, T_REV_TRN
;***************************************************************************

        XREF    TOF_COUNTER
        XREF    T_FWD, T_REV, T_FWD_TRN, T_REV_TRN

        XDEF    MOTOR_INIT
        XDEF    INIT_FWD, INIT_REV, INIT_ALL_STP
        XDEF    INIT_FWD_TRN, INIT_REV_TRN

; Movement timing constants (TOF ticks at ~23 Hz from Lab 5)
FWD_INT         EQU     69      ; ~3.0 s forward
REV_INT         EQU     69      ; ~3.0 s reverse
FWD_TRN_INT     EQU     46      ; ~2.0 s forward turn
REV_TRN_INT     EQU     46      ; ~2.0 s reverse turn

; Bit masks for PORTA/ PTT (direction / speed)
MOTOR_DIR_MASK  EQU     %00000011    ; PA0 = PORT_DIR, PA1 = STAR_DIR
MOTOR_SPEED_MASK EQU    %00110000    ; PTT4/5 = speed/enable

;---------------------------------------------------------------------------
; MOTOR_INIT – configure motor pins and ensure motors off
;---------------------------------------------------------------------------
MOTOR_INIT:
        BSET    DDRA,MOTOR_DIR_MASK      ; direction pins output
        BSET    DDRT,MOTOR_SPEED_MASK    ; speed pins output
        BCLR    PTT,MOTOR_SPEED_MASK     ; motors initially off
        RTS

;---------------------------------------------------------------------------
; INIT_FWD – forward motion for FWD_INT ticks
;---------------------------------------------------------------------------
INIT_FWD:
        BCLR    PORTA,MOTOR_DIR_MASK     ; FWD direction for both motors
        BSET    PTT,MOTOR_SPEED_MASK     ; turn on drive motors

        LDAA    TOF_COUNTER              ; mark forward timeout
        ADDA    #FWD_INT
        STAA    T_FWD
        RTS

;---------------------------------------------------------------------------
; INIT_REV – reverse motion for REV_INT ticks
;---------------------------------------------------------------------------
INIT_REV:
        BSET    PORTA,MOTOR_DIR_MASK     ; REV direction for both motors
        BSET    PTT,MOTOR_SPEED_MASK     ; turn on drive motors

        LDAA    TOF_COUNTER              ; mark reverse timeout
        ADDA    #REV_INT
        STAA    T_REV
        RTS

;---------------------------------------------------------------------------
; INIT_ALL_STP – stop both motors
;---------------------------------------------------------------------------
INIT_ALL_STP:
        BCLR    PTT,MOTOR_SPEED_MASK     ; motors off
        RTS

;---------------------------------------------------------------------------
; INIT_FWD_TRN – spin in place (one motor reversed) for FWD_TRN_INT
;---------------------------------------------------------------------------
INIT_FWD_TRN:
        BSET    PORTA,%00000010          ; REV dir for starboard (right) motor
        ; (port motor remains forward → turning)

        LDAA    TOF_COUNTER
        ADDA    #FWD_TRN_INT
        STAA    T_FWD_TRN
        RTS

;---------------------------------------------------------------------------
; INIT_REV_TRN – spin in opposite direction for REV_TRN_INT
;---------------------------------------------------------------------------
INIT_REV_TRN:
        BCLR    PORTA,%00000010          ; FWD dir for starboard (right) motor
        ; (assuming port stays reverse → opposite turn)

        LDAA    TOF_COUNTER
        ADDA    #REV_TRN_INT
        STAA    T_REV_TRN
        RTS
