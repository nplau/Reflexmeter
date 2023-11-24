; This is a reflex-o-meter and it utilizes polling to detect the reaction time of the user when the button is pressed
; It will then display the reaction time in binary 

				THUMB 		; Thumb instruction set 
                AREA 		My_code, CODE, READONLY
                EXPORT 		__MAIN
				ENTRY  
__MAIN

; They just turn off all LEDs 
				LDR			R10, =LED_BASE_ADR		; R10 is a permenant pointer to the base address for the LEDs, offset of 0x20 and 0x40 for the ports

				MOV 		R3, #0xB0000000		; Turn off three LEDs on port 1  
				STR 		R3, [R10, #0x20]
				MOV 		R3, #0x0000007C
				STR 		R3, [R10, #0x40] 	; Turn off five LEDs on port 2 

; This line is very important in your main program
; Initializes R11 to a 16-bit non-zero value and NOTHING else can write to R11 !!
				MOV			R11, #0xABCD		; Init the random number generator with a non-zero number
				
				;BL			COUNTER
loop 			BL 			RandomNum			; Generate psudeorandom number
				MOV			R4, R11				; Store pseudorandom number into R4
				LSL			R4, #28				; Shift left then right to get the first 4 bits (this will be between 1 and 15)
				LSR			R4, #28
				
				BL			CHECK_NUM			; Check if the number is between 2 and 10
				B 			start
				
start			MOV			R1, #10000				
				MUL			R0, R4, R1			; We get the delay by taking our psudeorandom number * 10000 * 0.1ms
				BL			DELAY				; Which gives us a delay between 2000ms and 10000ms or 2-10s
				
				LDR			R5, =FIO1SET
				MOV			R7, #0x20000000		
				STR			R7, [R5]			; Turn on LED P1.29 by setting bit 29 on FIO1SET
				
				MOV			R8, #0				; This will be the counter register	

POLL			LDR			R0, =FIO2PIN
				LDR			R1, [R0]			; Load the value of the button's status
				
				ADD			R8, #1
				MOV			R0, #1
				BL			DELAY				; Delay by 0.1ms
				
				TST			R1, #0x0400
				BNE			POLL				; If the status is not 0, continue polling until the button is pressed
				
				MOV			R4, R8
				BL			PRINT				; Display counter num
				
				B			start
				
CHECK_NUM		; If the pseudorandom number is less than 2, get a new number				
				CMP			R4, #2
				BLT			loop
				
				; If the pseudorandom number is greater than 10, get a new number
				CMP			R4, #10
				BGT			loop
				
				BX 			LR	
				
PRINT			STMFD		R13!,{R2, R14}
				MOV			R1, #0xFF			; The mask to get the first 8-bits
				MOV			R2, #4
				MOV			R8, R4				; We save the counter value so we can display it infinitely
printloop		
				AND			R3, R8, R1			; We make a mask and AND the counter value so we only get the first 8 bits
				BL			DISPLAY_NUM			; We display the 8 bits
				LSR			R8, #8				; Shift the counter register by 8 so we get the next 8-bits
				
				MOV			R0, #20000			
				BL 			DELAY				; Delay by 2 seconds
						
				SUBS		R2, #1				
				BNE			printloop			; Repeat this for 4 loops, as we want to get through the 32 bits
				
				MOV			R0, #30000		
				BL			DELAY				; After the final 8 bits have been displayed, delay for extra 3 seconds, giving us 5 seconds
				B 			PRINT				; Inifnitely display the 32 bits again
				LDMFD		R13!,{R2, R15}
				
;
; Display the number in R3 onto the 8 LEDs
DISPLAY_NUM		STMFD		R13!,{R1, R2, R4, R5, R6, R7, R14}

; Usefull commaands:  RBIT (reverse bits), BFC (bit field clear), LSR & LSL to shift bits left and right, ORR & AND and EOR for bitwise operations	
				; Initial addresses for FIOSET and FIOCLR
				LDR			R4, =FIO1SET
				LDR			R5, =FIO2SET
				LDR			R6, =FIO1CLR
				LDR			R7, =FIO2CLR
				
				; 1. Reverse the bits and turn the leds off
				RBIT		R3, R3
				EOR			R3, #-1
				STR			R3, [R10]
				
				; 2. Seperate port 1 and 2 
				; Port 1: shifts all the bits to the left, leaving us with bits 29, 30, 31
				; Then we shift it back to the right getting 28, 29, 30, 31
				; Finally we clear 30 so that we are left with bits 28, 29, 31 
				MOV			R1, R3
				LSL			R1, #5
				ASR			R1, #1
				AND 		R1, #0xB0000000
				
				; Port 2: shifts all the bits to the right by 25, leaving us with bits 0, 1, 2, 3, 4, 5, 6
				; Then we only take bits 2-6, as we don't need bits 0 and 1
				MOV 		R2, R3
				LSR			R2, #25
				AND			R2, #0x0000007C
				
				; Use FIOCLR to clear all the LEDS				
				STR			R1, [R6]
				STR			R2, [R7]
				
				; NOT the port 1 and port 2 led outputs
				EOR		 	R1, #-1
				EOR			R2, #-1
				
				; Use FIOSET to set the leds according to the port 1 and port 2 led outputs				
				STR			R1, [R4]
				STR			R2, [R5]
				
				; Reverse the R3 register again, then NOT it so we can continue incrementing it
				RBIT		R3, R3
				EOR			R3, #-1

				LDMFD		R13!,{R1, R2, R4, R5, R6, R7, R15}

;
; R11 holds a 16-bit random number via a pseudo-random sequence as per the Linear feedback shift register (Fibonacci) on WikiPedia
; R11 holds a non-zero 16-bit number.  If a zero is fed in the pseudo-random sequence will stay stuck at 0
; Take as many bits of R11 as you need.  If you take the lowest 4 bits then you get a number between 1 and 15.
; If you take bits 5..1 you'll get a number between 0 and 15 (assuming you right shift by 1 bit).
;
; R11 MUST be initialized to a non-zero 16-bit value at the start of the program OR ELSE!
; R11 can be read anywhere in the code but must only be written to by this subroutine
RandomNum		STMFD		R13!,{R1, R2, R3, R14}

				AND			R1, R11, #0x8000
				AND			R2, R11, #0x2000
				LSL			R2, #2
				EOR			R3, R1, R2
				AND			R1, R11, #0x1000
				LSL			R1, #3
				EOR			R3, R3, R1
				AND			R1, R11, #0x0400
				LSL			R1, #5
				EOR			R3, R3, R1		; the new bit to go into the LSB is present
				LSR			R3, #15
				LSL			R11, #1
				ORR			R11, R11, R3
				
				LDMFD		R13!,{R1, R2, R3, R15}
				
COUNTER			STMFD		R13!,{R0, R4, R14}
				MOV			R4, #0xFF
				MOV			R3, #0
counterloop		ADD 		R3, #1				
				;BL 			DISPLAY_NUM
				;MOV			R0, #0x3E8		; 1000 * 0.1ms = 100ms delay
				MOV			R0, #1
				BL			DELAY
				SUBS 		R4, #1
				BNE 		counterloop
				LDMFD		R13!,{R0, R4, R15}

;
;		Delay 0.1ms (100us) * R0 times
; 		aim for better than 10% accuracy
;       The formula to determine the number of loop cycles is equal to Clock speed x Delay time / (#clock cycles)
;       where clock speed = 4MHz and if you use the BNE or other conditional branch command, the #clock cycles =
;       2 if you take the branch, and 1 if you don't.

DELAY				STMFD		R13!,{R2, R14}
;
; code to generate a delay of 0.1ms * R0 times
;
		
MultipleDelay		TEQ		R0, #0		; test R0 to see if it's 0 - set Zero flag so you can use BEQ, BNE
					MOV 	R2, #0x85
					;MOV		R2, #3
counter				SUBS    R2, #1
					BNE		counter
					SUBS 	R0, #1
					BEQ		exitDelay
					BNE		MultipleDelay
					
exitDelay		LDMFD		R13!,{R2, R15}
				

LED_BASE_ADR	EQU 	0x2009c000 		; Base address of the memory that controls the LEDs 
PINSEL3			EQU 	0x4002c00c 		; Address of Pin Select Register 3 for P1[31:16]
PINSEL4			EQU 	0x4002c010 		; Address of Pin Select Register 4 for P2[15:0]
	
FIO1SET			EQU	    0x2009C038
FIO2SET			EQU		0x2009C058
FIO1CLR			EQU		0x2009C03C
FIO2CLR			EQU		0x2009C05C
	
FIO2PIN			EQU		0x2009C054
;	Usefull GPIO Registers
;	FIODIR  - register to set individual pins as input or output
;	FIOPIN  - register to read and write pins
;	FIOSET  - register to set I/O pins to 1 by writing a 1
;	FIOCLR  - register to clr I/O pins to 0 by writing a 1

				ALIGN 

				END 
					
; Check for 2-10 seconds
; We did this by first generating the pseudorandom number into R11
; Then we shifted R11 to the left and right until we are left with only one hex-bit, or 4 binary bits
; This guarantees us to get a number between 1-15, but we want 2-10
; We make another subroutine that compares the psudeorandom number we got with 2 and 10 
; If it's less than 2 or greater than 10, generate a new number
; Otherwise, we take that number between 2-10, multiply it by 10000 and delay for that long
; We multiply by 10000: let's say we got a number "3": 
; 3 * 10000 * 0.1ms delay = 3000ms = 3s

; -----------------------------------------------------------------------------------

