;***************************************************************************
;* main.asm – Current Base Project File (COE538 eebot Project)             *
;***************************************************************************

        XDEF    Entry, _Startup
        ABSENTRY Entry

        INCLUDE 'derivative.inc'
        INCLUDE 'read_guider.inc'     ; Guider + LCD + ADC subroutine library


;===========================================================================
; RAM VARIABLE SECTION
;===========================================================================

        ORG     $1000                 ; Start of RAM (adjust if needed)

; Guider sensor storage
SENSOR_LINE     DS.B    1
SENSOR_BOW      DS.B    1
SENSOR_PORT     DS.B    1
SENSOR_MID      DS.B    1
SENSOR_STBD     DS.B    1

SENSOR_NUM      DS.B    1            ; Internal counter for READ_SENSORS

; LCD shadow buffers (20 chars + NULL)
TOP_LINE        DS.B    21            ; 20 chars + NULL terminator
BOT_LINE        DS.B    21

TEMP            DS.B    1             ; Scratch byte used by SELECT_SENSOR


;===========================================================================
; CODE SECTION
;===========================================================================

        ORG     $4000                 ; Start of program code in Flash

Entry:
_Startup:
        LDS     #$4000                ; Initialize stack pointer

        JSR     INIT                  ; Initialize ports (from read_guider.inc)
        JSR     openADC               ; Initialize ADC module
        JSR     openLCD               ; Initialize LCD controller
        JSR     CLR_LCD_BUF           ; Clear LCD shadow buffer

        CLI                            ; Enable global interrupts


;===========================================================================
; MAIN LOOP – Current Stage: Sensor Debug Display
;===========================================================================

MAIN:
        JSR     G_LEDS_ON             ; Turn guider LEDs ON
        JSR     READ_SENSORS          ; Read all 5 guider sensors
        JSR     G_LEDS_OFF            ; Turn guider LEDs OFF

        JSR     DISPLAY_SENSORS       ; Update LCD with sensor values

        BRA     MAIN                  ; Repeat forever


        END
