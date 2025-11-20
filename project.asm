;****************************************************************************
;* Lab 7 – Read Guider Demo                                                 *
;****************************************************************************
; Export symbols
        XDEF    Entry, _Startup          ; Export 'Entry' symbol
        ABSENTRY Entry                   ; Mark this as application entry point

; Include derivative-specific definitions
        INCLUDE 'derivative.inc'

;---------------------------------------------------------------------------
; 'Read Guider' Demo Routine
;
; Reads the eebot guider sensors and displays the values on the LCD.
;
; Author:  Peter Hiscocks
; Version: 2
;
; Modified from version 1 to support selection of the individual LED
; associated with a sensor, to reduce crosstalk from unselected sensor LEDs.
;
; The guider hardware was modified with the addition of a 74HC138 decoder that
; drives the individual LEDs, so that only the LED associated with a given
; sensor is ON when that sensor is being read.
; This requires that the software be modified to enable the decoder with bit
; PA5 in PORTA.
;
; The CdS cells are very slow in responding to changes in light, so a 20 ms
; delay is inserted between selecting a particular sensor and reading its
; value.
;
; Substantial improvements:
;   - Draws less battery current for longer life
;   - Creates less heat in the 5V logic regulator
;   - Much greater contrast between dark and light readings
;
; Overview:
; ---------
; This program is intended as a test routine for the guider sensors of the
; eebot robot and contains routines that will be useful in the robot
; guidance project.
;
; The guider consists of four absolute brightness sensors and one
; differential brightness pair of sensors. They are arranged at the nose of
; the robot in the following pattern (viewed from above):
;
;       A
;     B C D
;     E-F
;
; The sensors are cadmium sulphide (CdS) photoresistive cells, for which the
; resistance increases with decreasing light level. The absolute cells
; A, B, C and D are driven from a constant current source, and the voltage
; across each cell is measured via the HCS12 A/D converter channel AN1. Thus
; the sensor reading increases as the sensor becomes darker (over a black
; line, for example).
;
; The differential sensor E-F is a voltage divider with the two CdS cells E
; and F separated by 0.75 inches, which is the width of electrical tape.
; It is intended to be used to track the edges of the electrical tape "line"
; once the absolute cells have "found" a black line. Cell E is at the top of
; the divider, so as the reading from this sensor increases, cell E is becoming
; lighter (straying onto the white background).
;
; Simultaneously, cell F is becoming darker as it moves over the black
; tape, and its resistance is increasing, reinforcing the same effect. The
; differential action should ignore ambient light.
;
; The program reads the sensor values, hopefully without disturbing any
; other settings on the robot. The values are displayed in hexadecimal on
; the LCD. On the LCD display, the pattern is as described in the routine
; 'DISPLAY_SENSORS'.
;
; The 4 absolute sensors should show readings equivalent to approximately
; 2 volts when over a light surface and 4 volts when covered by a finger.
; The range from light background to black tape background is typically
; 1.5 volts over a light background to 2.4 volts over black tape.
;
; We have yet to quantify the readings from the differential sensor E-F.
;
; Using the program:
; ------------------
; Connect the eebot chassis to an HCS12 computer board as usual. Load
; the 'read-guider' program into the microcomputer. Run the routine 'MAIN'.
; The display should show the five sensor readings. Placing a finger over
; one of the sensors to block its illumination should cause the reading to
; increase significantly. Be extremely careful not to bend the sensors or
; LED illuminators when doing this.
;---------------------------------------------------------------------------


;===========================================================================
; EQUATES SECTION
;===========================================================================

; A/D Converter Equates (documented for clarity)
;-----------------------------------------------

; ATDCTL2 – A/D Control Register 2
;   7 6 5 4 3 2 1 0
;   - - - - - - - -
;   | | | | | | | |
;   - - - - - - - -
;   ^ ^ ^ ^ ^ ^ ^ ^
;   | | | | | | | |
;   +-------- ADPU: 0 = A/D powered down, 1 = A/D powered up
ATDCTL2         EQU     $0082

; ATDCTL3 – A/D Control Register 3
;   7 6 5 4 3 2 1 0
;   - - - - - - - -
;   | | | | | | | |
;   - - - - - - - -
;   ^ ^ ^ ^ ^ ^ ^ ^
;   | | | | | | | |
;   | | | |
;   +---+---+---+--- Conversion Sequence Limit:
;       0001 = 1 conversion
;       ...
;       0111 = 7 conversions
;       1xxx = 8 conversions
ATDCTL3         EQU     $0083

; ATDCTL4 – A/D Control Register 4
;   7 6 5 4 3 2 1 0
;   - - - - - - - -
;   | | | | | | | |
;   - - - - - - - -
;   ^ ^ ^ ^ ^ ^ ^ ^
;   | | | | | | | |
;   | +---+---+---+---+-- ATD Clock Prescaler bits:
;   |       00101 = ÷12
;   |       01011 = ÷24
;   |       10111 = ÷48
;   |
;   +--- SRES8: 0 = 10 bits, 1 = 8 bits
ATDCTL4         EQU     $0084

; ATDCTL5 – A/D Control Register 5
;   7 6 5 4 3 2 1 0
;   - - - - - - - -
;   | | | | | | | |
;   - - - - - - - -
;   ^ ^ ^ ^ ^ ^ ^ ^
;   | | | | | | | |
;   | | | | +---+---+--- Channel Select
;   | | | |
;   | | | +-- MULT: 0 = sample one channel,
;   | | |           1 = sample several channels starting with selected
;   | | |
;   | | +-- SCAN: 0 = single conversion sequence per write to ATDCTL5
;   | |          1 = continuous conversion sequences
;   | |
;   | +-- not used
;   |
;   +--- DJM: 0 = left justified data, 1 = right justified data
ATDCTL5         EQU     $0085

; ATDSTAT0 – A/D Status Register 0
;   7 6 5 4 3 2 1 0
;   - - - - - - - -
;   | | | | | | | |
;   - - - - - - - -
;   ^ ^ ^ ^ ^ ^ ^ ^
;   | | | | | | | |
;   |
;   +-------- SCF: 0 = conversion not completed, 1 = completed
ATDSTAT0        EQU     $0086

; The A/D converter automatically puts the 4 results in these registers.
ATDDR0L         EQU     $0091       ; A/D Result Register 0 (low byte)
ATDDR1L         EQU     $0093       ; A/D Result Register 1 (low byte)
ATDDR2L         EQU     $0095       ; A/D Result Register 2 (low byte)
ATDDR3L         EQU     $0097       ; A/D Result Register 3 (low byte)


; PORTA Register
;--------------------------------
; This register selects which sensor is routed to AN1 of the A/D converter.
PORTA           EQU     $0000       ; PORTA register

;   7 6 5 4 3 2 1 0
;   - - - - - - - -
;   | | | | | | | |
;   - - - - - - - -
;   ^ ^ ^ ^ ^ ^ ^ ^
;   | | | | | | | |
;   | | | | | | | +--- Port motor direction (0 = FWD)
;   | | | | | | |
;   | | | | | | +--- Starboard motor direction (0 = FWD)
;   | | | | | |
;   | | | +---+---+-- Sensor select:
;   | | |        000 = Sensor Line
;   | | |        001 = Sensor Bow
;   | | |        010 = Sensor Port
;   | | |        011 = Sensor Mid
;   | | |        100 = Sensor Starboard
;   | | |
;   | | +-- Sensor LED enable (1 = ON)
;   | |
;   +--- not used

; Liquid Crystal Display Equates
;-------------------------------
CLEAR_HOME      EQU     $01         ; Clear display and home cursor
INTERFACE       EQU     $38         ; 8-bit interface, 2-line display
CURSOR_OFF      EQU     $0C         ; Display on, cursor off
SHIFT_OFF       EQU     $06         ; Address increments, no shift
LCD_SEC_LINE    EQU     64          ; Starting addr. of 2nd line (decimal)

; LCD addresses / pins
LCD_CNTR        EQU     PTJ         ; LCD control register: E = PJ7, RS = PJ6
LCD_DAT         EQU     PORTB       ; LCD data register: D7 = PB7 .. D0 = PB0
LCD_E           EQU     $80         ; LCD E signal pin
LCD_RS          EQU     $40         ; LCD RS signal pin

; Other codes
NULL            EQU     $00         ; String null terminator
CR              EQU     $0D         ; Carriage return
SPACE           EQU     ' '         ; Space character


;===========================================================================
; VARIABLE / DATA SECTION
;===========================================================================

        ORG     $3800              ; 9S12C32 RAM space: $3800..$3FFF

; Guider sensor storage
SENSOR_LINE     FCB     $01        ; Storage for guider sensor readings
SENSOR_BOW      FCB     $23        ; Initialized to test values
SENSOR_PORT     FCB     $45
SENSOR_MID      FCB     $67
SENSOR_STBD     FCB     $89

SENSOR_NUM      RMB     1          ; Currently selected sensor

; LCD shadow buffers
TOP_LINE        RMB     20         ; Top line of display
                FCB     NULL       ; Null-terminated

BOT_LINE        RMB     20         ; Bottom line of display
                FCB     NULL       ; Null-terminated

CLEAR_LINE      FCC     ' '        ; Single space (used for copies)
                FCB     NULL       ; Null-terminated

TEMP            RMB     1          ; Temporary location


;===========================================================================
; CODE SECTION
;===========================================================================

        ORG     $4000              ; Start of program text (FLASH)

;---------------------------------------------------------------------------
; Initialization
;---------------------------------------------------------------------------
Entry:
_Startup:
        LDS     #$4000             ; Initialize stack pointer
        CLI                         ; Enable interrupts

        JSR     INIT                ; Initialize ports
        JSR     openADC             ; Initialize the ATD
        JSR     openLCD             ; Initialize the LCD
        JSR     CLR_LCD_BUF         ; Clear LCD shadow buffer

;---------------------------------------------------------------------------
; Main Loop – Display Sensors
;---------------------------------------------------------------------------
MAIN:
        JSR     G_LEDS_ON           ; Enable guider LEDs
        JSR     READ_SENSORS        ; Read the 5 guider sensors
        JSR     G_LEDS_OFF          ; Disable guider LEDs
        JSR     DISPLAY_SENSORS     ; Write sensor values to the LCD

        LDY     #6000               ; 300 ms delay to avoid display artifacts
        JSR     del_50us
        BRA     MAIN                ; Loop forever


;===========================================================================
; SUBROUTINE SECTION
;===========================================================================

;---------------------------------------------------------------------------
; Initialize ports
;---------------------------------------------------------------------------
INIT:
        BCLR    DDRAD,$FF           ; Make PORTAD an input (DDRAD @ $0272)
        BSET    DDRA,$FF            ; Make PORTA an output (DDRA @ $0002)
        BSET    DDRB,$FF            ; Make PORTB an output (DDRB @ $0003)
        BSET    DDRJ,$C0            ; Make pins 7,6 of PTJ outputs (DDRJ @ $026A)
        RTS


;---------------------------------------------------------------------------
; Initialize the ADC
;---------------------------------------------------------------------------
openADC:
        MOVB    #$80,ATDCTL2        ; Turn on ADC (ATDCTL2 @ $0082)
        LDY     #1                  ; Wait 50 µs for ADC to be ready
        JSR     del_50us

        MOVB    #$20,ATDCTL3        ; 4 conversions on channel AN1 (ATDCTL3)
        MOVB    #$97,ATDCTL4        ; 8-bit resolution, prescaler=48 (ATDCTL4)
        RTS


;---------------------------------------------------------------------------
; Clear LCD Buffer
;
; This routine writes 'space' characters into the LCD display buffer in
; order to prepare it for building a new display. Needs to be done once at
; the start. Thereafter the display routine should maintain the buffer.
;---------------------------------------------------------------------------
CLR_LCD_BUF:
        LDX     #CLEAR_LINE
        LDY     #TOP_LINE
        JSR     STRCPY

CLB_SECOND:
        LDX     #CLEAR_LINE
        LDY     #BOT_LINE
        JSR     STRCPY

CLB_EXIT:
        RTS


;---------------------------------------------------------------------------
; STRCPY – String Copy
;
; Copies a null-terminated string (including the null) from one location to
; another.
;
; Passed:
;   X = starting address of null-terminated source string
;   Y = first address of destination
;---------------------------------------------------------------------------
STRCPY:
        PSHX                        ; Protect registers used
        PSHY
        PSHA

STRCPY_LOOP:
        LDAA    0,X                 ; Get a source character
        STAA    0,Y                 ; Copy it to destination
        BEQ     STRCPY_EXIT         ; If null, exit
        INX                          ; Else increment pointers
        INY
        BRA     STRCPY_LOOP         ; And repeat

STRCPY_EXIT:
        PULA                        ; Restore registers
        PULY
        PULX
        RTS


;---------------------------------------------------------------------------
; G_LEDS_ON – Guider LEDs ON
;
; Enables the guider LEDs so that sensor readings correspond to the
; "illuminated" condition.
;
; Side effect:
;   Sets PORTA bit 5.
;---------------------------------------------------------------------------
G_LEDS_ON:
        BSET    PORTA,%00100000     ; Set bit 5
        RTS


;---------------------------------------------------------------------------
; G_LEDS_OFF – Guider LEDs OFF
;
; Disables the guider LEDs so that readings correspond to ambient lighting.
;
; Side effect:
;   Clears PORTA bit 5.
;---------------------------------------------------------------------------
G_LEDS_OFF:
        BCLR    PORTA,%00100000     ; Clear bit 5
        RTS


;---------------------------------------------------------------------------
; READ_SENSORS
;
; This routine reads the eebot guider sensors and puts the results in RAM.
;
; Note:
;   Do not confuse the analog multiplexer on the guider board with the
;   multiplexer in the HCS12. The guider board mux must be set using
;   SELECT_SENSOR. The HCS12 always reads the selected sensor on AN1.
;
; A/D mode:
;   Reads AN1 four times into ATDDR0..ATDDR3. Only ATDDR0 is used here,
;   but others are available if needed.
;
; Passed:  None
; Returns:
;   SENSOR_LINE (0) – Sensor E/F
;   SENSOR_BOW  (1) – Sensor A
;   SENSOR_PORT (2) – Sensor B
;   SENSOR_MID  (3) – Sensor C
;   SENSOR_STBD (4) – Sensor D
;
; Algorithm:
;   1. Initialize SENSOR_NUM to 0.
;   2. Initialize X to start of sensor array.
;   3. Loop:
;        - Select sensor via SELECT_SENSOR.
;        - Delay 20 ms for CdS cells to stabilize.
;        - Start A/D conversion on AN1.
;        - Wait for SCF=1 in ATDSTAT0.
;        - Store ATDDR0L at [X].
;        - If last sensor, exit; else increment SENSOR_NUM and X and repeat.
;---------------------------------------------------------------------------
READ_SENSORS:
        CLR     SENSOR_NUM          ; Select sensor number 0
        LDX     #SENSOR_LINE        ; Point at start of sensor array

RS_MAIN_LOOP:
        LDAA    SENSOR_NUM          ; Select correct sensor
        JSR     SELECT_SENSOR       ; on the hardware

        LDY     #400                ; 20 ms delay (400 x 50 µs)
        JSR     del_50us

        LDAA    #%10000001          ; Start A/D conversion on AN1
        STAA    ATDCTL5

        BRCLR   ATDSTAT0,$80,*      ; Wait until SCF = 1 (conversion done)

        LDAA    ATDDR0L             ; A/D conversion result
        STAA    0,X                 ; Store into current sensor byte

        CPX     #SENSOR_STBD        ; If this is last reading
        BEQ     RS_EXIT             ; then exit

        INC     SENSOR_NUM          ; Else next sensor
        INX
        BRA     RS_MAIN_LOOP

RS_EXIT:
        RTS


;---------------------------------------------------------------------------
; SELECT_SENSOR
;
; Selects the sensor whose number is passed in ACCA.
;
; Motor direction bits (0,1), guider LED enable bit (5) and unused bits
; (6,7) in PORTA are not affected.
;
; Bits PA2, PA3, PA4 are connected to a 74HC4051 analog mux on the guider
; board, which selects the guider sensor connected to AN1.
;
; Passed:
;   ACCA = sensor number (0..4)
;
; Algorithm:
;   1. Copy PORTA to TEMP and clear bits 2,3,4 by ANDing with 11100011b.
;   2. Shift sensor number left twice to align with bits 2..4.
;   3. Mask with 00011100b to keep only those bits.
;   4. OR with TEMP.
;   5. Write back to PORTA.
;---------------------------------------------------------------------------
SELECT_SENSOR:
        PSHA                        ; Save sensor number

        LDAA    PORTA               ; Clear sensor selection bits
        ANDA    #%11100011
        STAA    TEMP

        PULA                        ; Get sensor number back
        ASLA                        ; Shift left twice
        ASLA
        ANDA    #%00011100          ; Keep only bits 2..4
        ORAA    TEMP                ; Merge into TEMP
        STAA    PORTA               ; Update hardware

        RTS


;---------------------------------------------------------------------------
; DISPLAY_SENSORS
;
; Passed:
;   SENSOR_LINE..SENSOR_STBD in RAM
;
; Uses a shadow buffer approach: builds a buffer then copies to LCD.
; Layout (sensor positions mimic physical arrangement):
;
;   01234567890123456789
;   ___FF_______________
;   PP_MM_SS_LL_________
;
; Where:
;   FF = front (SENSOR_BOW)
;   PP = port
;   MM = mid
;   SS = starboard
;   LL = line sensor
;
; DP_* equates define positions in the buffers.
;---------------------------------------------------------------------------
DP_FRONT_SENSOR EQU     TOP_LINE+3
DP_PORT_SENSOR  EQU     BOT_LINE+0
DP_MID_SENSOR   EQU     BOT_LINE+3
DP_STBD_SENSOR  EQU     BOT_LINE+6
DP_LINE_SENSOR  EQU     BOT_LINE+9

DISPLAY_SENSORS:
        ; FRONT sensor (SENSOR_BOW)
        LDAA    SENSOR_BOW
        JSR     BIN2ASC             ; Convert to ASCII in D
        LDX     #DP_FRONT_SENSOR
        STD     0,X                 ; Store both ASCII digits

        ; PORT sensor
        LDAA    SENSOR_PORT
        JSR     BIN2ASC
        LDX     #DP_PORT_SENSOR
        STD     0,X

        ; MID sensor
        LDAA    SENSOR_MID
        JSR     BIN2ASC
        LDX     #DP_MID_SENSOR
        STD     0,X

        ; STARBOARD sensor
        LDAA    SENSOR_STBD
        JSR     BIN2ASC
        LDX     #DP_STBD_SENSOR
        STD     0,X

        ; LINE sensor
        LDAA    SENSOR_LINE
        JSR     BIN2ASC
        LDX     #DP_LINE_SENSOR
        STD     0,X

        ; Now update the physical LCD from shadow buffer
        LDAA    #CLEAR_HOME         ; Clear display and home cursor
        JSR     cmd2LCD

        LDY     #40                 ; Wait 2 ms for clear to complete
        JSR     del_50us

        LDX     #TOP_LINE           ; Copy top line
        JSR     putsLCD

        LDAA    #LCD_SEC_LINE       ; Position cursor on second line
        JSR     LCD_POS_CRSR

        LDX     #BOT_LINE           ; Copy bottom line
        JSR     putsLCD

        RTS


;---------------------------------------------------------------------------
; BIN2ASC – Binary to ASCII (two hex digits)
;
; Converts 8-bit value in ACCA to a 2-character ASCII hex string in D.
;
; Uses HEX_TABLE for conversion.
;
; Passed:
;   ACCA = 8-bit binary value
;
; Returns:
;   D = two ASCII hex characters (MS nibble in A, LS nibble in B)
;
; Side effects:
;   ACCB destroyed
;---------------------------------------------------------------------------
HEX_TABLE       FCC     '0123456789ABCDEF'

BIN2ASC:
        PSHA                        ; Save input value
        TAB                         ; Copy to B

        ANDB    #%00001111          ; Strip upper nibble of B
        CLRA                        ; D = 000n (LS nibble)
        ADDD    #HEX_TABLE          ; Point into table
        XGDX
        LDAA    0,X                 ; Get LS nibble character

        PULB                        ; Retrieve original byte into B
        PSHA                        ; Save LS nibble char on stack

        RORB                        ; Move MS nibble into lower nibble
        RORB
        RORB
        RORB

        ANDB    #%00001111
        CLRA                        ; D = 000n (MS nibble)
        ADDD    #HEX_TABLE
        XGDX
        LDAA    0,X                 ; Get MS nibble character into A

        PULB                        ; Get LS nibble char into B
        RTS


;---------------------------------------------------------------------------
; LCD Routines
;---------------------------------------------------------------------------
; Initialize the LCD
;---------------------------------------------------------------------------
openLCD:
        LDY     #2000               ; Wait ~100 ms for LCD to be ready
        JSR     del_50us

        LDAA    #INTERFACE          ; 8-bit, 2-line, 5x8 font
        JSR     cmd2LCD

        LDAA    #CURSOR_OFF         ; Display on, cursor off, blink off
        JSR     cmd2LCD

        LDAA    #SHIFT_OFF          ; Move cursor right, no display shift
        JSR     cmd2LCD

        LDAA    #CLEAR_HOME         ; Clear display and home cursor
        JSR     cmd2LCD

        LDY     #40                 ; Wait 2 ms for clear to complete
        JSR     del_50us
        RTS


;---------------------------------------------------------------------------
; cmd2LCD – Send command in ACCA to LCD instruction register
;---------------------------------------------------------------------------
cmd2LCD:
        BCLR    LCD_CNTR,LCD_RS     ; Select LCD instruction register (RS=0)
        JSR     dataMov             ; Send data
        RTS


;---------------------------------------------------------------------------
; putcLCD – Send character in ACCA to LCD data register
;---------------------------------------------------------------------------
putcLCD:
        BSET    LCD_CNTR,LCD_RS     ; Select LCD data register (RS=1)
        JSR     dataMov             ; Send data
        RTS


;---------------------------------------------------------------------------
; putsLCD – Send NULL-terminated string pointed to by X
;---------------------------------------------------------------------------
putsLCD:
        LDAA    1,X+                ; Get one character
        BEQ     donePS              ; If NULL, we are done
        JSR     putcLCD
        BRA     putsLCD

donePS:
        RTS


;---------------------------------------------------------------------------
; dataMov – Send ACCA to LCD IR or DR depending on RS
;---------------------------------------------------------------------------
dataMov:
        BSET    LCD_CNTR,LCD_E      ; Pull LCD E high
        STAA    LCD_DAT             ; Put data on LCD data bus
        NOP
        NOP
        NOP
        BCLR    LCD_CNTR,LCD_E      ; Pull E low to latch data

        LDY     #1                  ; Short delay for most instructions
        JSR     del_50us
        RTS


;---------------------------------------------------------------------------
; LCD_POS_CRSR – Position cursor
;
; For a 20x2 display:
;   First line addresses: 0 .. 19
;   Second line:          64 .. 83
;
; Command format:
;   1aaaaaaa  (a = 7-bit address)
;
; Passed:
;   ACCA = 7-bit cursor address
;---------------------------------------------------------------------------
LCD_POS_CRSR:
        ORAA    #%10000000          ; Set high bit to form control word
        JSR     cmd2LCD
        RTS


;---------------------------------------------------------------------------
; del_50us – 50 Microsecond Delay
;
; Outer loop controlled by Y.
;---------------------------------------------------------------------------
del_50us:
        PSHX                        ; Protect X

eloop:
        LDX     #300                ; Inner loop count

iloop:
        NOP                          ; 1 E-clock
        DBNE    X,iloop             ; 3 E-clocks; loop until X=0
        DBNE    Y,eloop             ; 3 E-clocks; outer loop

        PULX                        ; Restore X
        RTS


;===========================================================================
; INTERRUPT VECTORS
;===========================================================================

        ORG     $FFFE
        DC.W    Entry               ; Reset vector
