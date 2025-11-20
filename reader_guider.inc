;***************************************************************************
; read_guider.inc
; Guider + LCD support for eebot (HCS12 / COE538)
;
; This file provides:
;   - ADC setup for guider sensors
;   - Guider LED control
;   - Sensor selection and reading
;   - LCD driver routines
;   - Hex conversion (BIN2ASC)
;   - Delay routine (del_50us)
;
; EXPECTS the following RAM symbols to be defined in your main file:
;   SENSOR_LINE, SENSOR_BOW, SENSOR_PORT, SENSOR_MID, SENSOR_STBD
;   SENSOR_NUM, TOP_LINE, BOT_LINE, TEMP
;
; Your main file must:
;   INCLUDE 'derivative.inc'
;   INCLUDE 'read_guider.inc'
;
; And in startup:
;   JSR INIT
;   JSR openADC
;   JSR openLCD
;   JSR CLR_LCD_BUF
;***************************************************************************

; External RAM variables (defined in main .asm)
        XREF    SENSOR_LINE
        XREF    SENSOR_BOW
        XREF    SENSOR_PORT
        XREF    SENSOR_MID
        XREF    SENSOR_STBD
        XREF    SENSOR_NUM
        XREF    TOP_LINE
        XREF    BOT_LINE
        XREF    TEMP

;---------------------------------------------------------------------------
; EQUATES
;---------------------------------------------------------------------------

; A/D converter registers (addresses also in derivative.inc)
ATDCTL2         EQU     $0082
ATDCTL3         EQU     $0083
ATDCTL4         EQU     $0084
ATDCTL5         EQU     $0085
ATDSTAT0        EQU     $0086

ATDDR0L         EQU     $0091
ATDDR1L         EQU     $0093
ATDDR2L         EQU     $0095
ATDDR3L         EQU     $0097

; PORTA – sensor select / motor dir / LED enable
PORTA           EQU     $0000

; LCD control
CLEAR_HOME      EQU     $01
INTERFACE       EQU     $38
CURSOR_OFF      EQU     $0C
SHIFT_OFF       EQU     $06
LCD_SEC_LINE    EQU     64

LCD_CNTR        EQU     PTJ      ; from derivative.inc
LCD_DAT         EQU     PORTB
LCD_E           EQU     $80
LCD_RS          EQU     $40

NULL            EQU     $00
SPACE           EQU     ' '

; LCD buffer positions for sensor display
DP_FRONT_SENSOR EQU     TOP_LINE+3
DP_PORT_SENSOR  EQU     BOT_LINE+0
DP_MID_SENSOR   EQU     BOT_LINE+3
DP_STBD_SENSOR  EQU     BOT_LINE+6
DP_LINE_SENSOR  EQU     BOT_LINE+9

;---------------------------------------------------------------------------
; CONSTANTS IN ROM (local to this module)
;---------------------------------------------------------------------------

CLEAR_LINE:
        FCC     '                    '   ; 20 spaces
        FCB     NULL

HEX_TABLE:
        FCC     '0123456789ABCDEF'


;===========================================================================
; SUBROUTINES
;===========================================================================

;---------------------------------------------------------------------------
; INIT – Initialize ports for guider + LCD
;---------------------------------------------------------------------------
INIT:
        BCLR    DDRAD,$FF           ; PORTAD input (DDRAD @ $0272)
        BSET    DDRA,$FF            ; PORTA output  (DDRA @ $0002)
        BSET    DDRB,$FF            ; PORTB output  (DDRB @ $0003)
        BSET    DDRJ,$C0            ; PTJ7,6 output (DDRJ @ $026A)
        RTS


;---------------------------------------------------------------------------
; openADC – Initialize ADC for guider reading
;---------------------------------------------------------------------------
openADC:
        MOVB    #$80,ATDCTL2        ; Power up ADC
        LDY     #1                  ; 50 µs delay
        JSR     del_50us

        MOVB    #$20,ATDCTL3        ; 4 conversions on AN1
        MOVB    #$97,ATDCTL4        ; 8-bit, prescaler ÷48
        RTS


;---------------------------------------------------------------------------
; G_LEDS_ON / G_LEDS_OFF – guider LEDs control (PORTA bit 5)
;---------------------------------------------------------------------------
G_LEDS_ON:
        BSET    PORTA,%00100000     ; Enable guider LEDs
        RTS

G_LEDS_OFF:
        BCLR    PORTA,%00100000     ; Disable guider LEDs
        RTS


;---------------------------------------------------------------------------
; CLR_LCD_BUF – clear shadow LCD buffers
;---------------------------------------------------------------------------
CLR_LCD_BUF:
        LDX     #CLEAR_LINE
        LDY     #TOP_LINE
        JSR     STRCPY

        LDX     #CLEAR_LINE
        LDY     #BOT_LINE
        JSR     STRCPY

        RTS


;---------------------------------------------------------------------------
; STRCPY – copy NULL-terminated string from X to Y
;---------------------------------------------------------------------------
STRCPY:
        PSHX
        PSHY
        PSHA

STRCPY_LOOP:
        LDAA    0,X
        STAA    0,Y
        BEQ     STRCPY_EXIT
        INX
        INY
        BRA     STRCPY_LOOP

STRCPY_EXIT:
        PULA
        PULY
        PULX
        RTS


;---------------------------------------------------------------------------
; READ_SENSORS – read all 5 guider sensors into RAM
;
; Uses:
;   SENSOR_LINE, SENSOR_BOW, SENSOR_PORT, SENSOR_MID, SENSOR_STBD
;   SENSOR_NUM
;---------------------------------------------------------------------------
READ_SENSORS:
        CLR     SENSOR_NUM          ; sensor index = 0
        LDX     #SENSOR_LINE        ; point to first sensor byte

RS_MAIN_LOOP:
        LDAA    SENSOR_NUM
        JSR     SELECT_SENSOR       ; set guider mux

        LDY     #400                ; 20 ms (400 x 50 µs)
        JSR     del_50us

        LDAA    #%10000001          ; start single conversion on AN1
        STAA    ATDCTL5

        BRCLR   ATDSTAT0,$80,*      ; wait for SCF=1

        LDAA    ATDDR0L             ; result
        STAA    0,X

        CPX     #SENSOR_STBD        ; last sensor?
        BEQ     RS_EXIT

        INC     SENSOR_NUM
        INX
        BRA     RS_MAIN_LOOP

RS_EXIT:
        RTS


;---------------------------------------------------------------------------
; SELECT_SENSOR – choose guider sensor via PORTA bits 2..4
;
; ACCA = sensor number (0..4)
;---------------------------------------------------------------------------
SELECT_SENSOR:
        PSHA                        ; save sensor number

        LDAA    PORTA
        ANDA    #%11100011          ; clear bits 2..4
        STAA    TEMP

        PULA                        ; sensor num
        ASLA
        ASLA                        ; shift into bits 2..4
        ANDA    #%00011100          ; keep only those bits
        ORAA    TEMP
        STAA    PORTA

        RTS


;---------------------------------------------------------------------------
; DISPLAY_SENSORS – update LCD from sensor values using shadow buffers
;---------------------------------------------------------------------------
DISPLAY_SENSORS:
        ; FRONT (bow) sensor
        LDAA    SENSOR_BOW
        JSR     BIN2ASC
        LDX     #DP_FRONT_SENSOR
        STD     0,X

        ; PORT
        LDAA    SENSOR_PORT
        JSR     BIN2ASC
        LDX     #DP_PORT_SENSOR
        STD     0,X

        ; MID
        LDAA    SENSOR_MID
        JSR     BIN2ASC
        LDX     #DP_MID_SENSOR
        STD     0,X

        ; STARBOARD
        LDAA    SENSOR_STBD
        JSR     BIN2ASC
        LDX     #DP_STBD_SENSOR
        STD     0,X

        ; LINE (E/F)
        LDAA    SENSOR_LINE
        JSR     BIN2ASC
        LDX     #DP_LINE_SENSOR
        STD     0,X

        ; push buffer to physical LCD
        LDAA    #CLEAR_HOME
        JSR     cmd2LCD

        LDY     #40                 ; ~2 ms for clear
        JSR     del_50us

        LDX     #TOP_LINE
        JSR     putsLCD

        LDAA    #LCD_SEC_LINE
        JSR     LCD_POS_CRSR

        LDX     #BOT_LINE
        JSR     putsLCD

        RTS


;---------------------------------------------------------------------------
; BIN2ASC – 8-bit binary to 2-char ASCII hex (returns in D)
;---------------------------------------------------------------------------
BIN2ASC:
        PSHA                        ; save original value
        TAB                         ; copy to B

        ANDB    #%00001111          ; LS nibble
        CLRA
        ADDD    #HEX_TABLE
        XGDX
        LDAA    0,X                 ; LS char in A

        PULB                        ; original byte in B
        PSHA                        ; save LS char on stack

        RORB
        RORB
        RORB
        RORB                        ; move MS nibble into lower bits

        ANDB    #%00001111
        CLRA
        ADDD    #HEX_TABLE
        XGDX
        LDAA    0,X                 ; MS char into A

        PULB                        ; LS char into B
        RTS


;---------------------------------------------------------------------------
; LCD routines
;---------------------------------------------------------------------------
openLCD:
        LDY     #2000               ; ~100 ms
        JSR     del_50us

        LDAA    #INTERFACE
        JSR     cmd2LCD

        LDAA    #CURSOR_OFF
        JSR     cmd2LCD

        LDAA    #SHIFT_OFF
        JSR     cmd2LCD

        LDAA    #CLEAR_HOME
        JSR     cmd2LCD

        LDY     #40                 ; ~2 ms
        JSR     del_50us
        RTS


cmd2LCD:
        BCLR    LCD_CNTR,LCD_RS     ; RS=0 → command
        JSR     dataMov
        RTS


putcLCD:
        BSET    LCD_CNTR,LCD_RS     ; RS=1 → data
        JSR     dataMov
        RTS


putsLCD:
        LDAA    1,X+                ; get char
        BEQ     donePS              ; NULL?
        JSR     putcLCD
        BRA     putsLCD

donePS:
        RTS


dataMov:
        BSET    LCD_CNTR,LCD_E      ; E high
        STAA    LCD_DAT             ; put data on bus
        NOP
        NOP
        NOP
        BCLR    LCD_CNTR,LCD_E      ; E low (latch)

        LDY     #1
        JSR     del_50us
        RTS


LCD_POS_CRSR:
        ORAA    #%10000000          ; set DDRAM address command bit
        JSR     cmd2LCD
        RTS


;---------------------------------------------------------------------------
; del_50us – ~50 µs delay, scaled by Y
;---------------------------------------------------------------------------
del_50us:
        PSHX

eloop:
        LDX     #300

iloop:
        NOP
        DBNE    X,iloop
        DBNE    Y,eloop

        PULX
        RTS
