;***************************************************************************
; main.asm – COE538 eebot Project (single-file version)
;   - Guider + LCD + ADC
;   - Motor control + TOF timing
;   - Current behaviour: read guider sensors and display on LCD
;***************************************************************************

        XDEF    Entry, _Startup
        ABSENTRY Entry

        INCLUDE 'derivative.inc'


;===========================================================================
; EQUATES
;===========================================================================

;----------------------------
; A/D Converter Registers
;----------------------------
ATDCTL2         EQU     $0082
ATDCTL3         EQU     $0083
ATDCTL4         EQU     $0084
ATDCTL5         EQU     $0085
ATDSTAT0        EQU     $0086

ATDDR0L         EQU     $0091
ATDDR1L         EQU     $0093
ATDDR2L         EQU     $0095
ATDDR3L         EQU     $0097

;----------------------------
; PORTA – sensor select / motor direction / LED enable
;----------------------------
PORTA           EQU     $0000

;----------------------------
; LCD Equates
;----------------------------
CLEAR_HOME      EQU     $01         ; Clear display & home cursor
INTERFACE       EQU     $38         ; 8-bit, 2-line display
CURSOR_OFF      EQU     $0C         ; Display on, cursor off
SHIFT_OFF       EQU     $06         ; Increment, no shift
LCD_SEC_LINE    EQU     64          ; Second line DDRAM address

LCD_CNTR        EQU     PTJ         ; Control port: E = PJ7, RS = PJ6
LCD_DAT         EQU     PORTB       ; Data port
LCD_E           EQU     $80
LCD_RS          EQU     $40

NULL            EQU     $00
SPACE           EQU     ' '

;----------------------------
; Motor control equates
;----------------------------
FWD_INT         EQU     69          ; ~3.0 s forward   (TOF ticks)
REV_INT         EQU     69          ; ~3.0 s reverse
FWD_TRN_INT     EQU     46          ; ~2.0 s fwd turn
REV_TRN_INT     EQU     46          ; ~2.0 s rev turn

MOTOR_DIR_MASK   EQU    %00000011   ; PA0 = PORT_DIR, PA1 = STAR_DIR
MOTOR_SPEED_MASK EQU    %00110000   ; PTT4/5 = motor enable / speed

;----------------------------
; LCD buffer positions for sensor display
;----------------------------
; TOP_LINE and BOT_LINE are RAM buffers (defined below).
DP_FRONT_SENSOR  EQU    TOP_LINE+3
DP_PORT_SENSOR   EQU    BOT_LINE+0
DP_MID_SENSOR    EQU    BOT_LINE+3
DP_STBD_SENSOR   EQU    BOT_LINE+6
DP_LINE_SENSOR   EQU    BOT_LINE+9


;===========================================================================
; RAM VARIABLES
;===========================================================================

        ORG     $1000                  ; Start of RAM (adjust if needed)

;--- Guider sensors ---
SENSOR_LINE     DS.B    1              ; E/F differential
SENSOR_BOW      DS.B    1              ; A
SENSOR_PORT     DS.B    1              ; B
SENSOR_MID      DS.B    1              ; C
SENSOR_STBD     DS.B    1              ; D

SENSOR_NUM      DS.B    1              ; current sensor index

;--- LCD shadow buffers (20 chars + NULL) ---
TOP_LINE        DS.B    21             ; 20 chars + NULL
BOT_LINE        DS.B    21

TEMP            DS.B    1              ; scratch for SELECT_SENSOR, etc.

;--- Timer / state-related variables ---
TOF_COUNTER     DS.B    1              ; increments in TOF_ISR

T_FWD           DS.B    1              ; alarm time for forward
T_REV           DS.B    1              ; alarm time for reverse
T_FWD_TRN       DS.B    1              ; alarm for fwd turn
T_REV_TRN       DS.B    1              ; alarm for rev turn

CRNT_STATE      DS.B    1              ; reserved for later state machine


;===========================================================================
; CODE / CONSTANTS
;===========================================================================

        ORG     $4000                  ; Start of program code / constants

;--- ROM string: 20 spaces + NULL for clearing LCD buffers ---
CLEAR_LINE:
        FCC     '                    ' ; 20 spaces
        FCB     NULL

;--- HEX table for BIN2ASC ---
HEX_TABLE:
        FCC     '0123456789ABCDEF'


;---------------------------------------------------------------------------
; Entry / Startup
;---------------------------------------------------------------------------
Entry:
_Startup:
        LDS     #$4000                 ; Initialize stack pointer

        ;--- Hardware / peripheral init ---
        JSR     INIT                   ; guider + LCD-related ports
        JSR     MOTOR_INIT             ; motor DDRs, motors off
        JSR     openADC                ; ADC configuration
        JSR     openLCD                ; LCD initialization
        JSR     CLR_LCD_BUF            ; clear shadow LCD buffers
        JSR     ENABLE_TOF             ; enable TOF-based timing

        CLR     TOF_COUNTER            ; start TOF counter at 0
        CLR     CRNT_STATE             ; will be used later

        CLI                             ; enable global interrupts


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
; SUBROUTINES – PORT / ADC / GUIDER / LCD
;===========================================================================

;---------------------------------------------------------------------------
; INIT – Initialize ports (guider + LCD)
;---------------------------------------------------------------------------
INIT:
        BCLR    DDRAD,$FF              ; PORTAD input (DDRAD @ $0272)
        BSET    DDRA,$FF               ; PORTA output (DDRA @ $0002)
        BSET    DDRB,$FF               ; PORTB output (DDRB @ $0003)
        BSET    DDRJ,$C0               ; PTJ7,6 output (DDRJ @ $026A)
        RTS


;---------------------------------------------------------------------------
; openADC – Initialize ADC for guider reading
;---------------------------------------------------------------------------
openADC:
        MOVB    #$80,ATDCTL2           ; power up ADC
        LDY     #1                     ; 50 µs delay
        JSR     del_50us

        MOVB    #$20,ATDCTL3           ; 4 conversions on AN1
        MOVB    #$97,ATDCTL4           ; 8-bit, prescaler ÷48
        RTS


;---------------------------------------------------------------------------
; G_LEDS_ON / G_LEDS_OFF – guider LED control (PORTA bit 5)
;---------------------------------------------------------------------------
G_LEDS_ON:
        BSET    PORTA,%00100000        ; enable guider LEDs
        RTS

G_LEDS_OFF:
        BCLR    PORTA,%00100000        ; disable guider LEDs
        RTS


;---------------------------------------------------------------------------
; CLR_LCD_BUF – clear TOP_LINE / BOT_LINE using CLEAR_LINE string
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
; STRCPY – copy NULL-terminated string from X → Y
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
        CLR     SENSOR_NUM             ; sensor index = 0
        LDX     #SENSOR_LINE           ; point to first sensor byte

RS_MAIN_LOOP:
        LDAA    SENSOR_NUM
        JSR     SELECT_SENSOR          ; set guider mux

        LDY     #400                   ; ~20 ms (400 x 50 µs)
        JSR     del_50us

        LDAA    #%10000001             ; start single conversion on AN1
        STAA    ATDCTL5

        BRCLR   ATDSTAT0,$80,*         ; wait for SCF=1

        LDAA    ATDDR0L                ; result
        STAA    0,X

        CPX     #SENSOR_STBD           ; last sensor?
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
        PSHA                            ; save sensor number

        LDAA    PORTA
        ANDA    #%11100011              ; clear bits 2..4
        STAA    TEMP

        PULA                            ; sensor num
        ASLA
        ASLA                            ; shift into bits 2..4
        ANDA    #%00011100              ; keep only those bits
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

        LDY     #40                    ; ~2 ms for clear
        JSR     del_50us

        LDX     #TOP_LINE
        JSR     putsLCD

        LDAA    #LCD_SEC_LINE
        JSR     LCD_POS_CRSR

        LDX     #BOT_LINE
        JSR     putsLCD

        RTS


;---------------------------------------------------------------------------
; BIN2ASC – 8-bit binary → 2-char ASCII hex (returns in D)
;---------------------------------------------------------------------------
BIN2ASC:
        PSHA                            ; save original value
        TAB                             ; copy to B

        ANDB    #%00001111              ; LS nibble
        CLRA
        ADDD    #HEX_TABLE
        XGDX
        LDAA    0,X                     ; LS char in A

        PULB                            ; original byte in B
        PSHA                            ; save LS char on stack

        RORB
        RORB
        RORB
        RORB                            ; MS nibble into low bits

        ANDB    #%00001111
        CLRA
        ADDD    #HEX_TABLE
        XGDX
        LDAA    0,X                     ; MS char in A

        PULB                            ; LS char into B
        RTS


;---------------------------------------------------------------------------
; LCD Routines
;---------------------------------------------------------------------------
openLCD:
        LDY     #2000                   ; ~100 ms
        JSR     del_50us

        LDAA    #INTERFACE
        JSR     cmd2LCD

        LDAA    #CURSOR_OFF
        JSR     cmd2LCD

        LDAA    #SHIFT_OFF
        JSR     cmd2LCD

        LDAA    #CLEAR_HOME
        JSR     cmd2LCD

        LDY     #40                    ; ~2 ms
        JSR     del_50us
        RTS


cmd2LCD:
        BCLR    LCD_CNTR,LCD_RS        ; RS=0 → command
        JSR     dataMov
        RTS


putcLCD:
        BSET    LCD_CNTR,LCD_RS        ; RS=1 → data
        JSR     dataMov
        RTS


putsLCD:
        LDAA    1,X+                   ; get char
        BEQ     donePS                 ; NULL?
        JSR     putcLCD
        BRA     putsLCD

donePS:
        RTS


dataMov:
        BSET    LCD_CNTR,LCD_E         ; E high
        STAA    LCD_DAT                ; put data on bus
        NOP
        NOP
        NOP
        BCLR    LCD_CNTR,LCD_E         ; E low (latch)

        LDY     #1
        JSR     del_50us
        RTS


LCD_POS_CRSR:
        ORAA    #%10000000             ; set DDRAM address command bit
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


;===========================================================================
; MOTOR CONTROL ROUTINES
;===========================================================================

;---------------------------------------------------------------------------
; MOTOR_INIT – configure motor pins and ensure motors off
;---------------------------------------------------------------------------
MOTOR_INIT:
        BSET    DDRA,MOTOR_DIR_MASK    ; direction pins output
        BSET    DDRT,MOTOR_SPEED_MASK  ; speed pins output
        BCLR    PTT,MOTOR_SPEED_MASK   ; motors initially off
        RTS


;---------------------------------------------------------------------------
; INIT_FWD – forward motion for FWD_INT ticks
;---------------------------------------------------------------------------
INIT_FWD:
        BCLR    PORTA,MOTOR_DIR_MASK   ; FWD direction for both motors
        BSET    PTT,MOTOR_SPEED_MASK   ; turn on drive motors

        LDAA    TOF_COUNTER
        ADDA    #FWD_INT
        STAA    T_FWD
        RTS


;---------------------------------------------------------------------------
; INIT_REV – reverse motion for REV_INT ticks
;---------------------------------------------------------------------------
INIT_REV:
        BSET    PORTA,MOTOR_DIR_MASK   ; REV direction for both motors
        BSET    PTT,MOTOR_SPEED_MASK   ; turn on drive motors

        LDAA    TOF_COUNTER
        ADDA    #REV_INT
        STAA    T_REV
        RTS


;---------------------------------------------------------------------------
; INIT_ALL_STP – stop both motors
;---------------------------------------------------------------------------
INIT_ALL_STP:
        BCLR    PTT,MOTOR_SPEED_MASK   ; motors off
        RTS


;---------------------------------------------------------------------------
; INIT_FWD_TRN – spin in place for FWD_TRN_INT ticks
;   (example: starboard reversed, port forward)
;---------------------------------------------------------------------------
INIT_FWD_TRN:
        BSET    PORTA,%00000010        ; REV dir for starboard motor
        ; (assumes port motor remains forward)

        LDAA    TOF_COUNTER
        ADDA    #FWD_TRN_INT
        STAA    T_FWD_TRN
        RTS


;---------------------------------------------------------------------------
; INIT_REV_TRN – spin opposite direction for REV_TRN_INT ticks
;   (example: starboard forward, port reverse)
;---------------------------------------------------------------------------
INIT_REV_TRN:
        BCLR    PORTA,%00000010        ; FWD dir for starboard motor
        ; (assumes port motor reversed externally)

        LDAA    TOF_COUNTER
        ADDA    #REV_TRN_INT
        STAA    T_REV_TRN
        RTS


;===========================================================================
; TIMER / TOF ROUTINES
;===========================================================================

;---------------------------------------------------------------------------
; ENABLE_TOF – enable main timer and TOF interrupt
;   Uses TSCR1, TSCR2, TFLG2 from derivative.inc
;---------------------------------------------------------------------------
ENABLE_TOF:
        LDAA    #%10000000
        STAA    TSCR1                 ; TEN=1, enable timer
        STAA    TFLG2                 ; clear TOF flag by writing 1

        LDAA    #%10000100            ; TOI=1, prescale=÷16
        STAA    TSCR2
        RTS


;---------------------------------------------------------------------------
; TOF_ISR – Timer Overflow ISR
;   Increments TOF_COUNTER every overflow
;---------------------------------------------------------------------------
TOF_ISR:
        INC     TOF_COUNTER
        LDAA    #%10000000
        STAA    TFLG2                 ; clear TOF flag
        RTI


;===========================================================================
; INTERRUPT VECTORS
;===========================================================================

        ORG     $FFDE
        DC.W    TOF_ISR                ; Timer Overflow Vector

        ORG     $FFFE
        DC.W    Entry                  ; Reset Vector

        END
