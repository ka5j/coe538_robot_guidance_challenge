;***************************************************************************
; main.asm – COE538 eebot Project (current stage)
;   - Modularized: guider, motors, timers
;   - Behaviour: read guider sensors and display on LCD
;***************************************************************************

        XDEF    Entry, _Startup
        ABSENTRY Entry

        INCLUDE 'derivative.inc'
        INCLUDE 'read_guider.inc'      ; guider + LCD + ADC
        INCLUDE 'motors.inc'           ; motor control routines
        INCLUDE 'timers.inc'           ; TOF timing + ISR


;===========================================================================
; RAM VARIABLE SECTION
;===========================================================================

        ORG     $1000                  ; Start of RAM (adjust if needed)

;--- Guider sensors ---
SENSOR_LINE     DS.B    1
SENSOR_BOW      DS.B    1
SENSOR_PORT     DS.B    1
SENSOR_MID      DS.B    1
SENSOR_STBD     DS.B    1

SENSOR_NUM      DS.B    1              ; internal to READ_SENSORS

;--- LCD shadow buffers (20 chars + NULL) ---
TOP_LINE        DS.B    21             ; 20 chars + NULL
BOT_LINE        DS.B    21

TEMP            DS.B    1              ; scratch for SELECT_SENSOR, etc.

;--- Timer / state-related variables (from Lab 5 timing idea) ---
TOF_COUNTER     DS.B    1              ; increments in TOF_ISR (~23 Hz)

T_FWD           DS.B    1              ; alarm time for forward
T_REV           DS.B    1              ; alarm time for reverse
T_FWD_TRN       DS.B    1              ; alarm time for forward turn
T_REV_TRN       DS.B    1              ; alarm time for reverse turn

CRNT_STATE      DS.B    1              ; (reserved for later state machine)


;===========================================================================
; CODE SECTION
;===========================================================================

        ORG     $4000                  ; Start of program code in Flash

Entry:
_Startup:
        LDS     #$4000                 ; Initialize stack pointer

        ;--- Hardware / peripheral init ---
        JSR     INIT                   ; guider/LCD-related ports (from read_guider.inc)
        JSR     MOTOR_INIT             ; motor DDRs, motors off
        JSR     openADC                ; ADC configuration
        JSR     openLCD                ; LCD initialization
        JSR     CLR_LCD_BUF            ; clear shadow LCD buffers
        JSR     ENABLE_TOF             ; enable TOF-based timing

        CLR     TOF_COUNTER            ; start TOF counter at 0
        CLR     CRNT_STATE             ; we will use later for robot states

        CLI                             ; Enable global interrupts


;===========================================================================
; MAIN LOOP – CURRENT STAGE: SENSOR DEBUG ONLY
;===========================================================================

MAIN:
        JSR     G_LEDS_ON              ; illuminate guider LEDs
        JSR     READ_SENSORS           ; read all 5 sensors
        JSR     G_LEDS_OFF             ; LEDs off

        JSR     DISPLAY_SENSORS        ; show sensor values on LCD

        BRA     MAIN                   ; loop forever


;===========================================================================
; INTERRUPT VECTORS
;===========================================================================

        ORG     $FFDE
        DC.W    TOF_ISR                ; Timer Overflow Interrupt Vector

        ORG     $FFFE
        DC.W    Entry                  ; Reset Vector

        END
