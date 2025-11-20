;***************************************************************************
;* Lab 7 – Read Guider Demo Program
;***************************************************************************
;  This program reads the eebot guider sensors and displays their values
;  on the LCD. It is a reference implementation for COE538 students.
;  
;  Written by: Peter Hiscocks
;  Version:    2
;  
;  Notes:
;    - Updated to support individual LED activation using a 74HC138 decoder.
;    - Only the LED for the currently selected sensor is on.
;    - Reduces crosstalk and power consumption.
;    - CdS cells respond slowly, so a 20 ms delay is added after sensor select.
;***************************************************************************

; Export symbols
        XDEF    Entry, _Startup
        ABSENTRY Entry

; Include derivative-specific definitions
        INCLUDE 'derivative.inc'


;===========================================================================
;  EQUATES SECTION
;===========================================================================

;----------------------------
; LCD Equates
;----------------------------
CLEAR_HOME      EQU     $01        ; Clear display & home cursor
INTERFACE       EQU     $38        ; 8-bit interface, 2-line display
CURSOR_OFF      EQU     $0C        ; Display on, cursor off
SHIFT_OFF       EQU     $06        ; Auto-increment, no shift
LCD_SEC_LINE    EQU     64         ; Address of start of line 2

LCD_CNTR        EQU     PTJ        ; LCD control register
LCD_DAT         EQU     PORTB      ; LCD data register
LCD_E           EQU     $80        ; LCD Enable pin
LCD_RS          EQU     $40        ; LCD RS pin

;----------------------------
; Other constants
;----------------------------
NULL            EQU     $00
CR              EQU     $0D
SPACE           EQU     ' '

;----------------------------
; A/D Converter Equates
;----------------------------
; These registers are defined in derivative.inc, but documented here
; for clarity. The comments below lightly summarize the bit functions.

; ATDCTL2 – A/D Control Register 2
;   ADPU: Power up/down
ATDCTL2         EQU     $0082

; ATDCTL3 – A/D Control Register 3
;   S8C..S0C: Conversion sequence length
ATDCTL3         EQU     $0083

; ATDCTL4 – A/D Control Register 4
;   SRES8: 8-bit or 10-bit mode
;   PRS:   ADC clock prescaler
ATDCTL4         EQU     $0084

; ATDCTL5 – A/D Control Register 5
;   DJM:   Data justification
;   SCAN:  Scan mode
;   MULT:  Multi-channel mode
;   CH:    Channel select
ATDCTL5         EQU     $0085

; ATDSTAT0 – Status Register
;   SCF: Conversion complete flag
ATDSTAT0        EQU     $0086

; ATD Result Registers (low bytes)
ATDDR0L         EQU     $0091
ATDDR1L         EQU     $0093
ATDDR2L         EQU     $0095
ATDDR3L         EQU     $0097

;----------------------------
; PORTA – Sensor Select / Motor Direction
;----------------------------
PORTA           EQU     $0000


;===========================================================================
;  VARIABLE / DATA SECTION
;===========================================================================

        ORG     $3800          ; Start of 9S12C32 RAM

; Guider sensor storage
SENSOR_LINE     FCB     $01     ; Differential sensor E/F
SENSOR_BOW      FCB     $23     ; Absolute sensor A
SENSOR_PORT     FCB     $45     ; Absolute sensor B
SENSOR_MID      FCB     $67     ; Absolute sensor C
SENSOR_STBD     FCB     $89     ; Absolute sensor D

SENSOR_NUM      RMB     1       ; Currently selected sensor index

; LCD shadow buffers
TOP_LINE        RMB     20
                FCB     NULL

BOT_LINE        RMB     20
                FCB     NULL

CLEAR_LINE      FCC     '                    '   ; 20 spaces
                FCB     NULL

TEMP            RMB     1                       ; Temporary scratch byte
