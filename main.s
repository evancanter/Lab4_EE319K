;****************** main.s ***************
; Program written by: **-UUU-*Your Names**update this***
; Date Created: 2/14/2017
; Last Modified: 8/29/2018
; You are given a simple stepper motor software system with one input and
; four outputs. This program runs, but you are asked to add minimally intrusive
; debugging instruments to verify it is running properly. 
;   If the input PE4 is low, the stepper motor outputs cycle 10,6,5,9,...
;   If the input PE4 is high, the stepper motor outputs cycle 5,6,10,9,...
;   Insert debugging instruments which gather data (state and timing)
;   to verify that the system is functioning as expected.
; Hardware connections (External: One button and four outputs to stepper motor)
;  PE4 is Button input  (1 means pressed, 0 means not pressed)
;  PE3-0 are stepper motor outputs 
;  PF2 is Blue LED on Launchpad used as a heartbeat
; Instrumentation data to be gathered is as follows:
; After every output to Port E, collect one state and time entry. 
; The state information is the 5 bits on Port E PE4-0
;   place one 8-bit entry in your Data Buffer  
; The time information is the 24-bit time difference between this output and the previous (in 12.5ns units)
;   place one 32-bit entry in the Time Buffer
;    24-bit value of the SysTick's Current register (NVIC_ST_CURRENT_R)
;    you must handle the roll over as Current goes 3,2,1,0,0x00FFFFFF,0xFFFFFE,
; Note: The size of both buffers is 100 entries. Once you fill these
;       entries you should stop collecting data
; The heartbeat is an indicator of the running of the program. 
; On each iteration of the main loop of your program toggle the 
; LED to indicate that your code(system) is live (not stuck or dead).

GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C
SYSCTL_RCGCGPIO_R  EQU 0x400FE608
NVIC_ST_CURRENT_R  EQU 0xE000E018
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_DEN_R   EQU 0x4002551C
; RAM Area
          AREA    DATA, ALIGN=2
Index     SPACE 4 ; index into Stepper table 0,1,2,3
Direction SPACE 4 ; -1 for CCW, 0 for stop 1 for CW

;place your debug variables in RAM here
DataBuffer 	SPACE 100	;100 8 bit entries
TimeBuffer 	SPACE 400
DataPt 		SPACE 4
TimePt		SPACE 4
PrevTime	SPACE 4
; ROM Area
        IMPORT TExaS_Init
        IMPORT SysTick_Init
;-UUU-Import routine(s) from other assembly files (like SysTick.s) here
        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
Stepper DCB 5,6,10,9
        EXPORT  Start

Start
 ; TExaS_Init sets bus clock at 80 MHz
      MOV  R0,#4 ; PORT E (PE5-PE0 out logic analyzer to TExasDisplay)
      BL   TExaS_Init ; logic analyzer, 80 MHz
 ;place your initializations here
      BL   Stepper_Init ; initialize stepper motor
	  BL   Heartbeat_Init
;**********************
      BL   Debug_Init ;(you write this)
;**********************
      CPSIE  I    ; TExaS logic analyzer runs on interrupts
      MOV  R5,#0  ; last PE4
loop  

      LDR  R1,=GPIO_PORTE_DATA_R
      LDR  R4,[R1]  ;current value of switch
      AND  R4,R4,#0x10 ; select just bit 4
      CMP  R4,#0
      BEQ  no     ; skip if not pushed
      CMP  R5,#0
      BNE  no     ; skip if pushed last time
      ; this time yes, last time no
      LDR  R1,=Direction
      LDR  R0,[R1]  ; current direction
      ADD  R0,R0,#1 ;-1,0,1 to 0,1,2
      CMP  R0,#2
      BNE  ok
      MOV  R0,#-1  ; cycles through values -1,0,1
ok    STR  R0,[R1] ; Direction=0 (CW)  
no    MOV  R5,R4   ; setup for next time
      BL   Stepper_Step               
      LDR  R0,=1600000
      BL   Wait  ; time delay fixed but not accurate   
      B    loop
;Initialize stepper motor interface
Stepper_Init
      MOV R0,#1
      LDR R1,=Direction
      STR R0,[R1] ; Direction=0 (CW)
      MOV R0,#0
      LDR R1,=Index
      STR R0,[R1] ; Index=0
    ; 1) activate clock for Port E
      LDR R1, =SYSCTL_RCGCGPIO_R
      LDR R0, [R1]
      ORR R0, R0, #0x10  ; Clock for E
      STR R0, [R1]
      NOP
      NOP                 ; allow time to finish activating
    ; 2) no need to unlock PE4-0
    ; 3) set direction register
      LDR R1, =GPIO_PORTE_DIR_R
      LDR R0, [R1]
      ORR R0, R0, #0x0F    ; Output on PE0-PE3
      BIC R0, R0, #0x10    ; Input on PE4
      STR R0, [R1]
    ; 4) regular port function
      LDR R1, =GPIO_PORTE_AFSEL_R
      LDR R0, [R1]
      BIC R0, R0, #0x1F    ; GPIO on PE4-0
      STR R0, [R1]
    ; 5) enable digital port
      LDR R1, =GPIO_PORTE_DEN_R
      LDR R0, [R1]
      ORR R0, R0, #0x1F    ; enable PE4-0
      STR R0, [R1]
      BX  LR
; Step the motor clockwise
; Direction determines the rotational direction
; Input: None
; Output: None
Stepper_Step
      PUSH {R4,LR}
      LDR  R1,=Index
	  LDR  R2,[R1]     ; old Index
      LDR  R3,=Direction
      LDR  R0,[R3]     ; -1 for CCW, 0 for stop 1 for CW
	  ADD  R2,R2,R0
	  AND  R2,R2,#3    ; 0,1,2,3,0,1,2,...
      STR  R2,[R1]     ; new Index
	  LDR  R3,=Stepper ; table
	  LDRB R0,[R2,R3]  ; next output: 5,6,10,9,5,6,10,...
      LDR  R1,=GPIO_PORTE_DATA_R ; change PE3-PE0
      STR  R0,[R1]
      BL   Debug_Capture
      POP {R4,PC}
; inaccurate and inefficient time delay
Wait 
      SUBS R0,R0,#1  ; outer loop
      BNE  Wait
      BX   LR
      
Debug_Init 
	PUSH {R0-R4,LR}
; you write this
	LDR R0,=DataBuffer
	MOV R1, #100
	MOV R2,#0xFF
loop1
	STRB R2,[R0]
	ADD R0,#1
	SUBS R1,#1
	BNE loop1
	
	LDR R0,=TimeBuffer
	MOV R1,#100
	LDR R2,=0xFFFFFFFF
loop2
	STR R2,[R0]
	ADD R0,#4
	SUBS R1,#1
	BNE loop2
	
	LDR R0,=DataBuffer
	LDR R1,=DataPt
	STR R0,[R1]
	LDR R0,=TimeBuffer
	LDR R1,=TimePt
	STR R0,[R1]
	LDR R0,=PrevTime
	MOV R1,#0
	STR R1,[R0] ;init prevtime to 0
	BL SysTick_Init
	
	
    POP {R0-R4,PC}
;Debug capture      
Debug_Capture 
	PUSH {R0-R6,LR}
; you write this
;R5: Data end address
;R6: Time end address
;R0: DataPt
;R1: TimePt
	
	MOV R5,#100
	LDR R0,=DataBuffer
	ADD R5,R0
	MOV R6,#400
	LDR R0,=TimeBuffer
	ADD R6,R0
	LDR R0,=DataPt
	LDR R0,[R0]
	LDR R1,=TimePt
	LDR R1,[R1]


;check if data is full
	CMP R0,R5
	BEQ done
;check if time is full
	CMP R1,R6
	BEQ done
;not full, capture data
	LDR R2,=GPIO_PORTE_DATA_R
	LDR R2,[R2]
	AND R2,0x1F
	STRB R2,[R0]
	ADD R0,#1
	
	LDR R2,=NVIC_ST_CURRENT_R
	LDR R2,[R2]
	LDR R3,=PrevTime
	LDR R3,[R3]
	SUB R4,R3,R2			;prev-current
	LDR R5,=0x00FFFFFF
	AND R4,R5
	STR R4,[R1]		;store time into buffer
	ADD R1,#4
	LDR R3,=PrevTime
	STR R2,[R3]		;update previous to current
	
	LDR R2,=DataPt
	STR R0,[R2]		;update time pointer
	LDR R2,=TimePt
	STR R1,[R2]		;update time pointer
	
	LDR R0,=GPIO_PORTF_DATA_R
	LDR R1,[R0]
	EOR R1,0x04		;toggle PF2
	STR R1,[R0]

done
      POP  {R0-R6,PC}

;DEBUG CAPTURE: 40 instructions, est intrusiveness = 0.000625%
;500ns/80ms

Heartbeat_Init
	PUSH {R0-R2,LR}
	LDR R0,=SYSCTL_RCGCGPIO_R
	LDR R1,[R0]
	ORR R1,0x20		;enable F clock
	STR R1,[R0]
	NOP
	NOP
	LDR R0,=GPIO_PORTF_DIR_R
	LDR R1,[R0]
	ORR R1,0x04		;set bit 2 high (output)
	STR R1,[R0]
	LDR R0,=GPIO_PORTF_DEN_R
	LDR R1,[R0]
	ORR R1,0x04		;enable PF2
	STR R1,[R0]
	POP {R0-R2,PC}

      ALIGN      ; make sure the end of this section is aligned
      END        ; end of file
