; N4V128Sys bootrom - (C) 2017-2018 Robert Finch, Waterloo
;
; This file is part of FT64v7SoC
;
; how to build:
; 1. assemble using "AS64 +gFn .\boottc\boottc.asm"
; 2. copy boottc.ve0 to the correct directory if not already there
;
;------------------------------------------------------------------------------
;
; system memory map
;
;
; 00000000 +----------------+
;          |                |
;          |                |
;          |                |
;          |                |
;          :  dram memory   : 512 MB
;          |                |
;          |                |
;          |                |
;          |                |
; 20000000 +----------------+
;          |                |
;          :     unused     :
;          |                |
; FF400000 +----------------+
;          |   scratchpad   | 32 kB
; FF408000 +----------------+
;          |     unused     |
; FFD00000 +----------------+
;          |                |
;          :    I/O area    : 1.0 M
;          |                |
; FFE00000 +----------------+
;          |                |
;          :     unused     :
;          |                |
; FFFC0000 +----------------+
;          |                |
;          :    boot rom    :
;          |                |
; FFFF0000 +----------------+
;          |  cmp insn tbl  |
; FFFFFFFF +----------------+
;
;
;
;SUPPORT_DCI	equ		0
;SUPPORT_SMT		equ		0
; SUPPORT_AVIC	equ		1
SUPPORT_BMP		equ		1
;SUPPORT_TLB		equ		1

E_BadCallno	equ		-4

ROMBASE		equ		$FFFFFFFFFFFC0000
IOBASE		equ		$FFFFFFFFFFD00000
TEXTSCR		equ		$FFFFFFFFFFD00000
KEYBD		equ		$FFFFFFFFFFDC0000
LEDS		equ		$FFFFFFFFFFDC0600
BUTTONS		equ		$FFFFFFFFFFDC0600
SCRATCHPAD	equ		$FFFFFFFFFF400000
AVIC		equ		$FFFFFFFFFFDCC000
TC1			equ		$FFFFFFFFFFD0DF00
I2C			equ		$FFFFFFFFFFDC0200
PIT			equ		$FFFFFFFFFFDC1100
PIC			equ		$FFFFFFFFFFDC0F00
SPRCTRL	equ		$FFFFFFFFFFDAD000		// sprite controller
BMPCTRL	equ		$FFFFFFFFFFDC5000

WHITE		equ		$7FFF
MEDBLUE		equ		$000F

; Exception cause codes
TS_IRQ		equ		$9F
GC_EXEC		equ		$9E
GC_STOP		equ		$9D

macro mGfxCmd (cmd, dat)
		lh		r3,dat
		ldi		r5,#cmd<<32	
		or		r3,r3,r5
		sw		r3,$DC0[r6]
		memdb
		sw		r0,$DD0[r6]
		memdb
		bra		.testbr@
		dc		0x1234
.testbr@
endm

			bss
			org		SCRATCHPAD
__GCExecPtr		dw		0
__GCStopPtr		dw		0
fgcolor				dw		0
bkcolor				dw		0
_randStream		dw		0	
_S19Address		dw		0
_S19StartAddress	dw		0
_DBGCursorCol	db		0
_DBGCursorRow	db		0
_KeybdID			dc		0
_KeyState1		db		0
_KeyState2		db		0
_KeyLED				db		0
_S19Abort			db		0
_S19Reclen		db		0
			align		8
_mmu_key			dw		0
_RTCBuf				fill.b	96,0
			align		8
_DBGAttr			dw		0
_milliseconds	dw		0
___garbage_list	dw	0
_regfile			fill.w	32,0
			org		SCRATCHPAD + 32752
__brk_stack		dw		0

; Help the assembler out by telling it how many bits are required for code
; addresses
{+
		code	18 bits
		org		ROMBASE			; start of ROM memory space
		jmp		__BrkHandler	; jump to the exception handler
		org		ROMBASE + $100	; The PC is set here on reset
start2:
		ldi		r1,#$AA
		sb		r1,LEDS
;		call	ClearTxtScreen
;		jmp		StartHere
		jmp		start			; Comment out this jump to test i-cache
;		jmp		_SieveOfEratosthenes	

ifdef SUPPORT_SMT		
		ldi		r1,#$10000		; turn on SMT use $10000
		csrrs	r0,#0,r1
		add		r0,r0,#0		; fetch adjustment ramp
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		csrrd	r1,#$044,r0		; which thread is running ?
		bbs		r1,#24,test_icache
		jmp		_SieveOfEratosthenes
endif

test_icache:
	; This seems stupid but maybe necessary. Writes to r0 always cause it to
	; be loaded with the value zero regardless of the value written. Readback
	; should then always be a zero. The only case it might not be is at power
	; on. At power on the reg should be zero, but let's not assume that and
	; write a zero to it.

		and		r0,r0,#0		; cannot use LDI which does an or operation
		; set trap vector
		ldi		r1,#ROMBASE
		csrrw	r0,#$30,r1
		ldi		$sp,#$10000000+$7BF8	; set stack pointer
		sei		#0

	; Seed random number generator
		call	_InitPRNG
.st4:
	; Get a random number
		sh		r0,$0C04[r6]	; set the stream
		memdb
		nop						; delay a wee bit
		lvhu	r1,$0C00[r6]	; get a number
		sh		r0,$0C00[r6]	; generate next number

	; convert to random address
	;	mul		r1,r1,#5
		and		r1,r1,#$1FFC
		add		r1,r1,#SCRATCHPAD+$1000	; scratchram address
		
	; Fill an area with test code
		ldi		r2,#(.st6-.st2)/4		; number of ops - 1
		ldi		r3,#.st2		; address of test routine copy
.st3:
		lhu		r4,[r3+r2*4]	; move from boot rom to
		sh		r4,[r1+r2*4]	; scratch ram
		sub		r2,r2,#1
		bne		r2,r0,.st3
		; Do the last char copy
		lhu		r4,[r3+r2*4]	; move from boot rom to
		sh		r4,[r1+r2*4]	; scratch ram
	
	; Now jump to the test code
		cache	#3,[r1]			; invalidate the cache

	; The following is important to allow the last few store
	; operations to complete before trying to execute code.
		sync

		jal		r29,[r1]
		ldi		r2,#14			; this is the value that should be returned
		xor		r1,r1,r2
		bne		r1,r0,.st5
		bra		.st4

	; Display fail code
.st5:
		ldi		r1,#$FA
		sb		r1,$0600[r6]
		bra		.st5

; Test code accumulates for 16 instructions, sum should be 14
		align	4
.st2:
		ldi		r1,#0
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		add		r1,r1,#1		
		ret
.st6:

start:
	; This seems stupid but maybe necessary. Writes to r0 always cause it to
	; be loaded with the value zero regardless of the value written. Readback
	; should then always be a zero. The only case it might not be is at power
	; on. At power on the reg should be zero, but let's not assume that and
	; write a zero to it.
		and		r0,r0,#0		; cannot use LDI which does an or operation
		ldi		$sp,#SCRATCHPAD+$7BF8	; set stack pointer
	
		call	_Delay2s
		ldi		r1,#$FFFF000F0000
		sw		r1,_DBGAttr
		call	_DBGClearScreen
		call	_DBGHomeCursor
		ldi		$r1,#MsgBoot
		push	$r1
		call	_DBGDisplayAsciiStringCRLF
		add		sp,sp,#8
		ldi		$r1,#7
		sb		$r1,LEDS
		call	_InitPRNG
		call  _RandomizeSpritePositions2
		call	_i2c_init
		call	_KeybdInit
		call	_SetTrapVector
		call	_InitPIC
		call	_InitPIT
		; Enable interrupts
;		sei		#0
		call	_monitor
;		call	_ramtest
		call	_SpriteDemo
		call	_SetCursorImage
		; The following must be after the RTC is read
		call	_init_memory_management
		ldi		$r1,#8
		sb		$r1,LEDS

		
		
	; The following code must run shortly after the org statement determining
	; where code is located.
	; Get the high order bits of the program address into the program
	; address pointer register r22.
		jal		$r22,.st3
.st3:
		and		$r22,$r22,#$FFFC0000	; mask off the low order bits
ifdef SUPPORT_DCI
		call	_InitCompressedInsns
endif
+}
		bra		.st1
.st2:
		ldi		r2,#$AA
		sb		r2,LEDS			; write to LEDs
		bra		.st2

	; First thing to do, LED status indicates core at least hit the reset
	; vector.
.st1:
		ldi		r2,#$FF
		sb		r2,LEDS			; write to LEDs

		; set garbage handler vectors
		ldi		$r1,#__GCExec
		sw		$r1,__GCExecPtr
		ldi		$r1,#__GCStop
		sw		$r1,__GCStopPtr

		; set trap vector
		ldi		r1,#$FFFFFFFFFFFC0000
		csrrw	r0,#$30,r1
		ldi		r1,#__BrkHandler6
		csrrw	r0,#$36,r1			// tvec[6]
		ldi		sp,#__brk_stack+4088
		sw		r0,_milliseconds
		jmp		StartHere

	; Write buffering test
;		sb		r0,_milliseconds
;		ldi		r1,#1
;		sb		r1,_milliseconds+1
;		ldi		r1,#2
;		sb		r1,_milliseconds+2
;		ldi		r1,#3
;		sb		r1,_milliseconds+3
;		ldi		r1,#4
;		sb		r1,_milliseconds+4
;		ldi		r1,#5
;		sb		r1,_milliseconds+5
;		ldi		r1,#6
;		sb		r1,_milliseconds+6
;		ldi		r1,#7
;		sb		r1,_milliseconds+7
;		ldi		r1,#8
;		sb		r1,_milliseconds+8
;		ldi		r1,#9
;		sb		r1,_milliseconds+9
;		ldi		r1,#10
;		sb		r1,_milliseconds+10
;		ldi		r1,#11
;		sb		r1,_milliseconds+11
;		ldi		r1,#12
;		sb		r1,_milliseconds+12
;		ldi		r1,#13
;		sb		r1,_milliseconds+13

		; enable time slice interrupt
;		ldi		$r1,#31
;		sh		$r1,PIC+$0C
;		sei		#0

		call	_init_memory_management
		call	_FMTK_Initialize
		call	_InitPIC
		call	_InitPIT
		
		; Enable interrupts
		sei		#0
		
		ldi		r1,#$00000		; turn on SMT use $10000
		csrrs	r0,#0,r1
		add		r0,r0,#0		; fetch adjustment ramp
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		csrrd	r1,#$044,r0		; which thread is running ?
		bbs		r1,#24,.st2

		call	calltest3

;		ldi		r1,#16
;		vmov	vl,r1
;		ldi		r1,#$FFFF
;		vmov	vm0,r1
;		sync
;		lv		v1,vec1data
;		lv		v2,vec2data
;		vadd	v3,v1,v2,vm0

		ldi		r1,#MEDBLUE	
		sh		r1,bkcolor		; set text background color
		ldi		r1,#WHITE
		sh		r1,fgcolor		; set foreground color

	ldi		r1,#$AAAA5555	; pick some data to write
	ldi		r3,#0
	ldi		r4,#start1
start1:
	shr		r2,r1,#12
	sb		r2,LEDS			; write to LEDs
	add		r1,r1,#1
	add		r3,r3,#1
	xor		r2,r3,#10	; stop after a few cycles
;	bne		r2,r0,r4

	; Initialize PRNG
		call	_InitPRNG

		ldi		r2,#6
		sb		r2,LEDS			; write to LEDs
		jal		lr,clearTxtScreen
		ldi		r4,#$0025
		sb		r4,LEDS
_StartApp:
		jmp		_BIOSMain
start3:
		bra		start3

brkrout:
;		sub		sp,sp,#16
;		sw		r1,[sp]			; save off r1
;		sw		r23,8[sp]		; save off assembler's working reg
		add		r0,r0,#0
	; Set the interrupt level back to the interrupting level
	; to allow nesting higher priority interrupts
		csrrd	r1,#$044,r0
		shr		r1,r1,#40
		and		r1,r1,#7
		;sei		r1
		lh		r1,_milliseconds
		add		r1,r1,#1
		sh		r1,_milliseconds
		ldi		r1,#$20000		; sequence number reset bit
		csrrs	r0,#0,r1		; pulse sn reset bit
		add		r0,r0,#0		; now a ramp of instructions
		add		r0,r0,#0		; that don't depend on sequence
		add		r0,r0,#0		; number to operate properly
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
		add		r0,r0,#0
;		lw		r1,[sp]			; get r1 back
;		lw		r23,8[sp]
;		add		sp,sp,#16
		rti

calltest:
		sw		r1,SCRATCHPAD		; 1
		add		r1,r1,#2			; 2
		lw		r1,SCRATCHPAD		; 3
		ret

calltest1:
		sub		sp,sp,#8
		sw		lr,[sp]
		call	calltest
		lw		lr,[sp]
		add		sp,sp,#8
		ret

calltest2:
		sub		sp,sp,#8
		sw		lr,[sp]
		call	calltest1
		lw		lr,[sp]
		add		sp,sp,#8
		ret

calltest3:
		sub		sp,sp,#8
		sw		lr,[sp]
		call	calltest2
		lw		lr,[sp]
		add		sp,sp,#8
		ret

StartHere:
		ldi		$sp,#SCRATCHPAD+$FF8	; set stack pointer
;		call	_InitTLB
		call	_Set400x300
ifdef SUPPORT_AVIC
		call	_BootCopyFont
endif
		call	_InitPRNG
		call	_SetCursorPalette
		call	_SetCursorImage
		call	_RandomizeSpritePositions2
		call	_ColorBandMemory2
.0001:
		jmp		.0001
		jmp		_BIOSMain

ifdef SUPPORT_DCI
;------------------------------------------------------------------------------
; Copy compressed instruction table in processor's compressed instruction
; table.
;------------------------------------------------------------------------------
; can't have compressed instructions here
{+
_InitCompressedInsns:
		lw		$r3,cmp_insns		; get compressed instruction count (256)
		beq		$r3,$r0,.0002		; make sure we don't loop 2^64 times
		ldi		$r2,#8					; instructions begin offset by 8
.0001:
		lw		$r1,cmp_insns[$r2]
		sw		$r1,$FFFEFFF8[$r2]
		add		$r2,$r2,#8
		sub		$r3,$r3,#1
		bne		$r3,$r0,.0001
.0002:
		ret
+}
endif

;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

_SetTrapVector:
		ldi		r1,#$FFFFFFFFFFFC0000
		csrrw	r0,#$30,r1
		ldi		r1,#__BrkHandler6
		csrrw	r0,#$36,r1			// tvec[6]
		ret
		
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------

_Delay2s:
		ldi			$r1,#3000000
.0001:
		shr			$r2,$r1,#16
		sb			$r2,LEDS
		sub			$r1,$r1,#1
		bne			$r1,$r0,.0001
		ret

;------------------------------------------------------------------------------
; Initialize the TLB with entries for the BIOS rom and variables.
;------------------------------------------------------------------------------
ifdef SUPPORT_TLB
_InitTLB:
		; Set ASID to 1
		sub				sp,sp,#8
		sw				lr,[sp]
		ldi				$r18,#1
		call			_SetASID

		tlbwrreg 	MA,$r0			; clear TLB miss address register
		ldi				$r1,#2			; 2 wired registers
		tlbwrreg	Wired,$r1

		; setup the first translation
		; virtual page $F..FFC0000 maps to physical page $F..FFC0000
		; This places the BIOS ROM at $FFFFxxxx in the memory map
		ldi				$r1,#%1_00_010_10000_001_111	; _P_GDUSA_C_RWX
		; ASID=1, G=1,Read/Write/Execute=111, 128kiB pages
		tlbwrreg	ASID,r1
		ldi				$r1,#$FFFFFFFFFFFFFFFE
		tlbwrreg	VirtPage,$r1
		tlbwrreg	PhysPage,$r1
		tlbwrreg	Index,$r0		; select way #0
		tlbwi									; write to TLB entry group #0 with hold registers

		; setup second translation
		; virtual page 0 maps to physical page 0
		ldi				$r1,#%1_00_010_10000_001_111	; _P_GDUSA_C_RWX
		; ASID=1, G=1,Read/Write/Execute=111, 128kiB pages
		tlbwrreg	ASID,$r1
		tlbwrreg	VirtPage,$r0
		tlbwrreg	PhysPage,$r0
		ldi				$r1,#16			; select way#1
		tlbwrreg	Index,$r1		
		tlbwi						; write to TLB entry group #0 with hold registers

		; turn on the TLB
;		tlben
		lw			lr,[sp]
		ret			#8
endif

;------------------------------------------------------------------------------
; Set400x300 video mode.
; *
;------------------------------------------------------------------------------
ifdef SUPPORT_AVIC
_Set400x300:
		sub		$sp,$sp,#8
		sw		$r6,[sp]
		ldi		$r6,#AVIC
		ldi		$r1,#$0190012C	; 400x300
		sw		$r1,$FD0[r6]
		ldi		$r1,#$00328001	; 50 strips per line, 4 bit z-order
		sw		$r1,$FE0[r6]		; set lowres = divide by 2
		lw		$r6,[sp]
		add		$sp,$sp,#8
		ret
endif
ifdef SUPPORT_BMP
_Set400x300:
		sub		$sp,$sp,#32
		sw		$r6,[sp]
		sw		$r5,8[sp]
		sw		$r7,16[sp]
		sw		$r8,24[sp]
		ldi		$r6,#$AA
		sb		$r6,LEDS
		ldi		$r6,#BMPCTRL
		ldi		$r7,#bmp_reg_val
		ldi		$r8,#4						; four registers to update
		ldi		$r5,#0					
.0001:
		lw		$r1,[$r7+$r5*8]
		sw		$r1,[$r6+$r5*8]
		add		$r5,$r5,#1
		bne		$r5,$r8,.0001
		lw		$r6,[sp]
		lw		$r5,8[sp]
		lw		$r7,16[sp]
		sw		$r8,24[sp]
		ret		#32

		align	8
bmp_reg_val:
		dw		$0000000000120301
		dw		$001B00DA012C0190
		dw		$0000000000040000
		dw		$0000000000080000
endif


;------------------------------------------------------------------------------
; Initialize PRNG
;------------------------------------------------------------------------------
_InitPRNG:
		sw		r0,_randStream
		ldi		r6,#$FFFFFFFFFFDC0000
		sh		r0,$0C04[r6]			; select stream #0
		memdb
		ldi		r1,#$88888888
		sh		r1,$0C08[r6]			; set initial m_z
		memdb
		ldi		r1,#$01234567
		sh		r1,$0C0C[r6]			; set initial m_w
		memdb
		ret

;------------------------------------------------------------------------------
; Get a random number, and generate the next number.
;
; Parameters:
;	r18 = random stream number.
; Returns:
;	r1 = random 32 bit number.
;------------------------------------------------------------------------------

_GetRand:
		sh		r18,$FFFFFFFFFFDC0C04	; set the stream
		memdb
		lvhu	r1,$FFFFFFFFFFDC0C00	; get a number
		memdb
		sh		r0,$FFFFFFFFFFDC0C00	; generate next number
		memdb
		ret

;------------------------------------------------------------------------------
; Fill the display memory with bands of color.
;------------------------------------------------------------------------------

_ColorBandMemory2:
		sub		sp,sp,#32
		sw		r1,[sp]
		sw		r2,8[sp]
		sw		r6,16[sp]
		sw		lr,24[sp]
		ldi		r2,#7
		sb		r2,LEDS			; write to LEDs
		ldi		r6,#$40000
		mov		r18,r0
		call	_GetRand
.0002:
		sc		r1,[r6]
		sb		r1,LEDS
		add		r6,r6,#2
		and		r2,r6,#$3FF
		bne		r2,r0,.0001
		mov		r18,r0
		call	_GetRand
.0001:
		sltu	r2,r6,#$C0000
		bne		r2,r0,.0002
		ldi		r2,#8
		sb		r2,LEDS			; write to LEDs
		lw		r1,[sp]
		lw		r2,8[sp]
		lw		r6,16[sp]
		lw		lr,24[sp]
		ret		#32

;------------------------------------------------------------------------------
; Copy font to AVIC ram
; *
;------------------------------------------------------------------------------

_BootCopyFont:
		sub		$sp,$sp,#24
		sw		$r2,[$sp]
		sw		$r3,8[$sp]
		sw		$r6,16[$sp]
		ldi		$r1,#$0004
		sb		$r1,LEDS
		ldi		$r6,#AVIC

		; Setup font table
		ldi		$r1,#$1FFFEFF0
		sw		$r1,$DE0[r6]			; set font table address
		sw		$r0,$DE8[r6]			; set font id (0)
		ldi		$r1,#%10000111000001110000000000000000	; set font fixed, width, height = 8
		sh		$r1,$1FFFEFF4
		ldi		$r1,#$1FFFF000		; set bitmap address (directly follows font table)
		sh		$r1,$1FFFEFF0

		ldi		$r6,#font8
		ldi		$r2,#127				; 128 chars @ 8 bytes per char
.0001:
		lw		$r3,[$r6+$r2*8]
		sw		$r3,[$r1+$r2*8]
		sub		$r2,$r2,#1
		bne		$r2,$r0,.0001
		lw		$r3,[$r6+$r2*8]
		sw		$r3,[$r1+$r2*8]
		ldi		$r1,#$0005
		sb		$r1,LEDS
		lw		$r2,[$sp]
		lw		$r3,8[$sp]
		lw		$r6,16[$sp]
		ret		#24

;------------------------------------------------------------------------------
; Display character at cursor position. The current foreground color and
; background color are used.
;
; Parameters:
;	r18			character to display
; Returns:
;	<none>
; Registers Affected:
;	<none>
;------------------------------------------------------------------------------

_TxtDispChar:
		beqi	$r18,#CR,.doCr
		lcu		$r1,bkcolor
		lcu		$r2,fgcolor
		shl		$r1,$r1,#32
		shl		$r2,$r2,#16
		or		$r1,$r1,$r2
		or		$r1,$r1,$r18
		lcu		$r3,_DBGCursorRow
		mul		$r3,$r3,#48*8
		lcu		$r4,_DBGCursorCol
		shl		$r4,$r4,#3
		add		$r3,$r3,$r4
		add		$r3,$r3,#TXTSCREEN
		sw		$r1,[$r3]
.doCr:
		lhu		$r1,_DBGCursorCol
		add		$r1,$r1,#1
		sh		$r1,_DBGCursorCol
		slt		$r2,$r1,#48
		bne		$r2,$r0,.xit
		sh		$r0,_DBGCursorCol
		lhu		$r1,_DBGCursorRow
		add		$r1,$r1,#1
		sh		$r1,_DBGCursorRow
		
.xit:
		ret
		
;------------------------------------------------------------------------------
; DispChar:
;
; Display character at cursor position. The current foreground color and
; background color are used.
;
; Parameters:
;	r18			character to display
; Returns:
;	<none>
; Registers Affected:
;	<none>
; *
;------------------------------------------------------------------------------

_DispChar:
		sub		$sp,$sp,#32
		sw		$r2,[$sp]
		sw		$r3,8[$sp]
		sw		$r6,16[$sp]
		sw		$r29,24[$sp]
		
		ldi		r6,#AVIC
		ldi		r4,#1016
.0001:			
									; wait for character que to empty
		lhu		r2,$DD0[r6]			; read character queue index into r2
		memdb
		bgtu	r2,r4,.0001			; allow up 24 entries to be in progress	
		
		mGfxCmd (12,fgcolor)
		mGfxCmd (13,bkcolor)
		mGfxCmd (16,_DBGCursorCol)
	
		lh		r3,fgcolor
		ldi		r5,#12<<32			; 12 = set pen color
		or		r3,r3,r5
		sw		r3,$DC0[r6]
		memdb
		sw		r0,$DD0[r6]			; queue
		memdb

		lh		r3,bkcolor
		ldi		r5,#13<<32			; 13 = set fill color
		or		r3,r3,r5
		sw		r3,$DC0[r6]
		memdb
		sw		r0,$DD0[r6]			; queue
		memdb

		lhu		r3,_DBGCursorCol
		ldi		r5,#16<<32				; 16 = set X0 pos
		shl		r3,r3,#19			; multiply by eight and convert to fixed (multiply by 65536)
		or		r3,r3,r5
		sw		r3,$DC0[r6]
		memdb
		sw		r0,$DD0[r6]			; queue
		memdb

		lhu		r3,_DBGCursorRow
		ldi		r5,#17<<32				; 17 = set Y0 pos
		shl		r3,r3,#19
		or		r3,r3,r5
		sw		r3,$DC0[r6]
		memdb
		sh		r0,$DD0[r6]			; queue
		memdb

;		0 = draw character
		zxc		r3,r18
		sw		r3,$DC0[r6]			; data = character code
		memdb
		sw		r0,$DD0[r6]			; queue
		memdb

		call	_SyncCursorPos
		lw		$r2,[$sp]
		lw		$r3,8[$sp]
		lw		$r6,16[$sp]
		lw		$r29,24[$sp]
		ret		#32

;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
_SyncCursorPos:
		sub		$sp,$sp,#24
		sw		$r2,[$sp]
		sw		$r3,8[$sp]
		sw		$r6,16[$sp]
		ldi		r6,#SPRCTRL
		lhu		r2,_DBGCursorCol
		lhu		r3,_DBGCursorRow
		shl		r3,r3,#3
		add		r3,r3,#28
		shl		r3,r3,#16
		shl		r2,r2,#3
		add		r2,r2,#256
		or		r2,r2,r3
		sh		r2,$810[r6]			;
		lw		$r2,[$sp]
		lw		$r3,8[$sp]
		lw		$r6,16[$sp]
		ret		#24

;----------------------------------------------------------------------------
; *
;----------------------------------------------------------------------------
_EnableCursor:
		sub		sp,sp,#24
		sw		r2,[$sp]
		sw		r3,8[$sp]
		sw		r6,16[$sp]
		ldi		r6,#SPRCTRL
		ldi		r2,#$FFFFFFFF
		sh		r2,$A00[a6]		; enable sprite #0
		lw		r2,[$sp]
		lw		r3,8[$sp]
		lw		r6,16[$sp]
		ret		#24

;----------------------------------------------------------------------------
; Setup the sprite color palette. The palette is loaded with random colors.
; *
;----------------------------------------------------------------------------

_SetCursorPalette:
		sub		sp,sp,#32
		sw		r2,[sp]
		sw		r6,8[sp]
		sw		r7,16[sp]
		sw		lr,24[sp]
		ldi		r6,#SPRCTRL
		ldi		r2,#WHITE
		sh		r2,8[r6]				; palette entry #1
		ldi		r2,#%111110000000000	; RED
		sh		r2,$10[r6]				; palette entry #2
		ldi		r7,#12
.0001:
		mov		r18,r0
		call	_GetRand
		and		r1,r1,#$7FFF
		sh		r1,[r6+r7]
		add		r7,r7,#8
		slt		r2,r7,#$800
		bne		r2,r0,.0001
		lw		r2,[sp]
		lw		r6,8[sp]
		lw		r7,16[sp]
		lw		lr,24[sp]
		add		sp,sp,#32
		ret
		
;----------------------------------------------------------------------------
; Establish a default image for all the sprites.
;----------------------------------------------------------------------------

_SetCursorImage:
		sub		$sp,$sp,#64
		sw		r2,[$sp]
		sw		r3,8[$sp]
		sw		r4,16[$sp]
		sw		r5,24[$sp]
		sw		r6,32[$sp]
		sw		r7,40[$sp]
		sw		r8,48[$sp]
		sw		r9,56[$sp]

		ldi		r6,#SPRCTRL
		ldi		r7,#$800
		ldi		r8,#$1FFEE000	; sprite image address
		ldi		r9,#$03C0000000000000			; size 30vx32h = 960 pixels, x = y = 0
.0002:
		sw		r8,[r6+r7]		; sprite image address
		add		r7,r7,#8			; advance to pos/size field
		sh		r9,[r6+r7]		; 
		add		r7,r7,#8			; next sprite
		xor		r2,r7,#$A00
		bne		r2,r0,.0002

		ldi		r2,#$1FFEE000
		ldi		r3,#_XImage
		ldi		r5,#30
.0001:
		lw		r4,[r3]				; swap the order of the words around
		sw		r4,[r2]
		add		r3,r3,#8
		add		r2,r2,#8
		sub		r5,r5,#1
		bne		r5,r0,.0001

		lw		r2,[$sp]
		lw		r3,8[$sp]
		lw		r4,16[$sp]
		lw		r5,24[$sp]
		lw		r6,32[$sp]
		lw		r7,40[$sp]
		lw		r8,48[$sp]
		lw		r9,56[$sp]
		ret		#64

	align	8
_CursorBoxImage:
	dw		$1111111111000000,$00
	dw		$1000000001000000,$00
	dw		$1000000001000000,$00
	dw		$1000000001000000,$00
	dw		$1000000001000000,$00
	dw		$1000000001000000,$00
	dw		$1000000001000000,$00
	dw		$1000000001000000,$00
	dw		$1000110001000000,$00
	dw		$1111111111000000,$00

; Higher order word appears later in memory but is displayed first. So the
; order of these words are swapped around above. To make it convenient to
; define the sprite image.

_XImage:
	dw		%1111111111111111111111111111111100000000000000000000000000000000
	dw		%1110000000000000000000000000011100000000000000000000000000000000
	dw		%1011000000000000000000000000110100000000000000000000000000000000
	dw		%1001100000000000000000000001100100000000000000000000000000000000
	dw		%1000110000000000000000000011000100000000000000000000000000000000
	dw		%1000011000000000000000000110000100000000000000000000000000000000
	dw		%1000001100000000000000001100000100000000000000000000000000000000
	dw		%1000000110000000000000011000000100000000000000000000000000000000
	dw		%1000000011000000000000110000000100000000000000000000000000000000
	dw		%1000000001100000000001100000000100000000000000000000000000000000
	dw		%1000000000110000000011000000000100000000000000000000000000000000
	dw		%1000000000011000000110000000000100000000000000000000000000000000
	dw		%1000000000001100001100000000000100000000000000000000000000000000
	dw		%1000000000000110011000000000000100000000000000000000000000000000
	dw		%1000000000000011110000000000000100000000000000000000000000000000
	dw		%1000000000000011110000000000000100000000000000000000000000000000
	dw		%1000000000000110011000000000000100000000000000000000000000000000
	dw		%1000000000001100001100000000000100000000000000000000000000000000
	dw		%1000000000011000000110000000000100000000000000000000000000000000
	dw		%1000000000110000000011000000000100000000000000000000000000000000
	dw		%1000000001100000000001100000000100000000000000000000000000000000
	dw		%1000000011000000000000110000000100000000000000000000000000000000
	dw		%1000000110000000000000011000000100000000000000000000000000000000
	dw		%1000001100000000000000001100000100000000000000000000000000000000
	dw		%1000011000000000000000000110000100000000000000000000000000000000
	dw		%1000110000000000000000000011000100000000000000000000000000000000
	dw		%1001100000000000000000000001100100000000000000000000000000000000
	dw		%1011000000000000000000000000110100000000000000000000000000000000
	dw		%1110000000000000000000000000011100000000000000000000000000000000
	dw		%1111111111111111111111111111111100000000000000000000000000000000

;----------------------------------------------------------------------------
; *
;----------------------------------------------------------------------------
_RandomizeSpritePositions2:
		sub		$sp,$sp,#32
		sw		$r1,[$sp]
		sw		$r6,8[$sp]
		sw		$r7,16[$sp]
		sw		lr,24[$sp]
		ldi		r6,#SPRCTRL
		ldi		r7,#$808
.0001:
		mov		r18,r0
		call	_GetRand
		shr		r2,r1,#10
		mod		r1,r1,#800
		mod		r2,r2,#600
;		and		r1,r1,#$01FF01FF	; 512,512
;		add		r1,r1,#$000E0080	; add +28 to y and +256 to x
		shl		r2,r2,#16
		or		r1,r1,r2
		add		r1,r1,#$000E0080	; add +28 to y and +256 to x
		sh		r1,[r6+r7]
		add		r7,r7,#$10			; advance to next sprite
		slt		r1,r7,#$9F0
		bne		r1,r0,.0001
		lw		$r1,[$sp]
		lw		$r6,8[$sp]
		lw		$r7,16[$sp]
		lw		lr,24[$sp]
		ret		#32

;----------------------------------------------------------------------------
;----------------------------------------------------------------------------
ClearTxtScreen:
		ldi		r4,#$0024
		sb		r4,LEDS
		ldi		r1,#$FFFFFFFFFFD00000	; text screen address
		ldi		r2,#2480							; number of chars 2480 (48x35)
		ldi		r3,#$00000080FFFF0020
.cts1:
		sw		r3,[r1]
		add		r1,r1,#8
		sub		$r2,$r2,#1
		bne		$r2,$r0,.cts1
		ret

;----------------------------------------------------------------------------
; The GC needs an interrupt level all to itself.
; - a higher priority interrupt may interrupt the GC, the GC stop interrupt
;   will only be able to run when the GC exec interrupt routine is executing
; - if there were other interrupt routines at the same level as the GC then
;   it would be possible that some other interrupt might be running when
;   the GC stop interrupt occurs. That would make it impossible to use a
;   two up-level interrupt return and some other means of stopping execution
;   of the GC would have to be found.
;----------------------------------------------------------------------------
brkrout2:
		; Read the golex viewport register to determine if the exception
		; should be handled globally or locally.
		csrrd	r1,#GOLEXVP,r0
		; 0=global, 1=local handling
		beq		r1,r0,.0001		; branch to global handler
		
		; now setup to invoke the local hander
		; load r1,r2 with cause and type
		csrrd	r1,#CAUSE,r0	; get cause code into r1
		mov		r1:x,r1			; put into exceptioned register set
		ldi		r2,#45			; exception type = system exception
		mov		r2:x,r2
		
		; Return to the exception handler code, not the exception return
		; point. The exception handler address should be in r28.
		mov		r1,r28:x
		; Should probably do a quick check for a reasonable return
		; address here.
		csrrw	r0,#EPC,r1		; stuff r28 into the return pc
		sync
		rti						; go back to the local code
		
		; Here global handling of exceptions is done
.0001:
		csrrd	$r1,#$6,r0				; read cause code
		beqi	$r1,#GC_EXEC,execGC
		beqi	$r1,#GC_STOP,stopGC

ts_irq:
		ldi		$r1,#31						; interrupt to reset
		sh		$r1,PIC+$14				; reset edge sense circuit register
		lw		$r1,_milliseconds
		add		$r1,$r1,#1
		sw		$r1,_milliseconds
		shl		$r2,$r1,#16
		and		$r1,$r1,#$FFFF
		or		$r1,$r1,$r2
		sw		$r1,$FFFFFFFFFFD0178
		rti
		
		; Here $r22 is used, meaning the GC code can't pass more than four
		; values in registers. $r22 is normally arg#5.
execGC:
		ldi		$r1,#30						; interrupt to reset
		sh		$r1,PIC+$14				; reset edge sense circuit register
		rti
		; GC stop interrupt programmed for one-shot operation here
		ldi		$r22,#PIT
		; The number of cycles to allow the GC to run must be less than
		; the number of cycles between GC interrupts
		ldi		$r1,#1900000			; number of cycles to run GC for (0.1s)
		sh		$r1,$24[$r22]			; max count
		sub		$r1,$r1,#2				; back off a couple of cycles
		sh		$r1,$28[$r22]			; store when 1 output
		ldi		$r1,#3					; configure for one-shot
		sb		$r1,$0D[$r22]			; counter #2 only control
		
		; Re-enable the GC interrupt level so that a GC stop interrupt
		; may interrupt the routine.
		sei		#3
		
		csrrd	$r1,#$C,$r0
		bbc		$r1,#1,.xgc		; if the state was IDLE just call the routine and return

		; Restore operating key		
		lbu		$r22,_gc_mapno
		csrrd	$r1,#3,$r0		; get PCR
		and		$r1,$r1,#$FFFFFFFFFFFFFF00
		or		$r1,$r1,$r22
		csrrw	$r0,#3,$r1		; set PCR

		; The following load must be before data level is set
		lw		$r22,_gc_pc
		; Restore data level (current level is 0)
		lbu		$r1,_gc_dl
		and		$r1,$21,#3
		shl		$r1,$r1,#20
		csrrs	$r0,#$44,$r1

		csrrd	$r1,#$6,$r0		; get back r1
		jmp		[$r22]
.xgc:
		lea		$sp,_gc_stack+255*8	; switch to GC stack
		ldi		$r1,#2			; flag GC busy
		csrrs	$r0,#$C,r1
		lw		$r1,__GCExecPtr
		call	[$r1]
		rti		#1				; flag GC not busy

		; GCStop can only be entered when GC is running. It does a two up level
		; return after saving the GC context. There isn't that much to save because
		; a register set is reserved for the interrupt level. That means there's no
		; need to save and restore it.
stopGC:
		ldi		$r1,#29						; interrupt to reset
		sh		$r1,PIC+$14				; reset edge sense circuit register
		rti
		lw		$r1,__GCStopPtr
		jmp		[$r1]
__GCStop:
		; Save data level - the data level was stacked by the GCStop irq
		csrrd	$r1,#$41,$r0		; read stacked data level
		shr		$r1,$r1,#16			; extract data level bits
		and		$r1,$r1,#3
		sb		$r1,_gc_dl			; save off data level

		; Save operating key, restore old operating key
		lbu		$r22,_gc_omapno
		csrrd	$r1,#3,$r0
		sb		$r1,_gc_mapno		; save off the map that was active
		and		$r1,$r1,#$FFFFFFFFFFFFFF00
		or		$r1,$r1,$r22
		csrrw	$r0,#3,$r1
		
		; Replace the EPC pointer with a pointer to an RTI. The the RTI will
		; execute another RTI.
		lea		$r1,.stopRti
		csrrw	$r1,#EPC0,$r1
		sw		$r1,_gc_pc
		csrrd	$r1,#9,$r0			; get back r1
.stopRti:
		rti
		
;===============================================================================
; Keyboard routines
;===============================================================================

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Initialize the keyboard.
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_KeybdInit:
	  push  lr
	  push	r3
		ldi		r3,#5
.0002:
		call	_Wait10ms
		ldi		$a0,#-1			; send reset code to keyboard
		sb		$a0,KEYBD+1	; write $FF to status reg to clear TX state
		memdb
		call	_KeybdSendByte	; now write to transmit register
		call	_KeybdWaitTx		; wait until no longer busy
		call	_KeybdRecvByte	; look for an ACK ($FA)
		xor		r2,r1,#$FA
		bne		r2,r0,.tryAgain
		call	_KeybdRecvByte	; look for BAT completion code ($AA)
		xor		r2,r1,#$FC	; reset error ?
		beq		r2,r0,.tryAgain
		xor		r1,r1,#$AA	; reset complete okay ?
		bne		r2,r0,.tryAgain

		; After a reset, scan code set #2 should be active
.config:
		ldi		$a0,#$F0			; send scan code select
		sb		$a0,LEDS
		call	_KeybdSendByte
		call	_KeybdWaitTx
		bbs		r1,#7,.tryAgain
		call	_KeybdRecvByte	; wait for response from keyboard
		bbs		r1,#7,.tryAgain
		xor		r2,r1,#$FA
		beq		r2,r0,.0004
.tryAgain:
    sub   r3,r3,#1
		bne	  r3,r0,.0002
.keybdErr:
		ldi		r1,#msgBadKeybd
		push	$r1
		call	_DBGDisplayAsciiStringCRLF
		add		sp,sp,#8
		bra		ledxit
.0004:
		ldi		$a0,#2			; select scan code set #2
		call	_KeybdSendByte
		call	_KeybdWaitTx
		bbs		r1,#7,.tryAgain
		call	_KeybdRecvByte	; wait for response from keyboard
		bbs		r1,#7,.tryAgain
		xor		r2,r1,#$FA
		bne		r2,r0,.tryAgain
		call	_KeybdGetID
ledxit:
		ldi		$a0,#$07
		call	_KeybdSetLED
		call	_Wait300ms
		ldi		$a0,#$00
		call	_KeybdSetLED
		lw		r3,[sp]
		lw		lr,8[sp]
		ret		#16

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Set the LEDs on the keyboard.
;
; Parameters: $a0 LED status to set
; Returns: none
; Modifies: none
; Stack Space: 2 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_KeybdSetLED:
		push	lr
		push	$r1
		mov		$r1,$a0
		ldi		$a0,#$ED
		call	_KeybdSendByte
		call	_KeybdWaitTx
		call	_KeybdRecvByte	; should be an ack
		mov		$a0,$r1
		call	_KeybdSendByte
		call	_KeybdWaitTx
		call	_KeybdRecvByte	; should be an ack
		lw		$r1,[sp]
		lw		lr,8[sp]
		ret		#16

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Get ID - get the keyboards identifier code.
;
; Parameters: none
; Returns: r1 = $AB83, $00 on fail
; Modifies: r1, KeybdID updated
; Stack Space: 2 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_KeybdGetID:
		push	lr
		push	$a0
		ldi		$a0,#$F2
		call	_KeybdSendByte
		call	_KeybdWaitTx
		call	_KeybdRecvByte
		bbs		r1,#7,.notKbd
		xor		r2,r1,#$AB
		bne		r2,r0,.notKbd
		call	_KeybdRecvByte
		bbs		r1,#7,.notKbd
		xor		r2,r1,#$83
		bne		r2,r0,.notKbd
		ldi		r1,#$AB83
.0001:
		sc		r1,_KeybdID
		lw		$a0,[sp]
		lw		lr,8[sp]
		ret		#16
.notKbd:
		ldi		r1,#$00
		bra		.0001

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Recieve a byte from the keyboard, used after a command is sent to the
; keyboard in order to wait for a response.
;
; Parameters: none
; Returns: r1 = recieved byte ($00 to $FF), -1 on timeout
; Modifies: r1
; Stack Space: 2 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_KeybdRecvByte:
  	push  lr
		push	r3
		ldi		r3,#100			; wait up to 1s
.0003:
		call	_KeybdGetStatus	; wait for response from keyboard
		bbs		r1,#7,.0004			; is input buffer full ? yes, branch
		call	_Wait10ms				; wait a bit
		sub   r3,r3,#1
		bne   r3,r0,.0003			; go back and try again
		lw		r3,[sp]					; timeout
		lw		lr,8[sp]
		ldi		r1,#-1				; return -1
		ret		#16
.0004:
		call	_KeybdGetScancode
		lw		r3,[sp]
		lw		lr,8[sp]
		ret		#16

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Send a byte to the keyboard.
;
; Parameters: $a0 byte to send
; Returns: none
; Modifies: none
; Stack Space: 0 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_KeybdSendByte:
		sb		$a0,KEYBD
		memdb
		ret
	
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Wait for 10 ms
;
; Parameters: none
; Returns: none
; Modifies: none
; Stack Space: 2 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_Wait10ms:
		push	r3
    push  r4
    csrrd	r3,#$002,r0		; get orginal count
.0001:
		csrrd	r4,#$002,r0
		sub		r4,r4,r3
		blt  	r4,r0,.0002			; shouldn't be -ve unless counter overflowed
		slt		r4,r4,#100000		; about 10ms at 10 MHz
		bne		r4,r0,.0001
.0002:
		lw		r4,[sp]
		lw		r3,8[sp]
		ret		#16


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Wait for 300 ms
;
; Parameters: none
; Returns: none
; Modifies: none
; Stack Space: 2 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_Wait300ms:
		push	r3
    push  r4
    csrrd	r3,#$002,r0		; get orginal count
.0001:
		csrrd	r4,#$002,r0
		sub		r4,r4,r3
		blt  	r4,r0,.0002			; shouldn't be -ve unless counter overflowed
		slt		r4,r4,#3000000	; about 300ms at 10 MHz
		bne		r4,r0,.0001
.0002:
		lw		r4,[sp]
		lw		r3,8[sp]
		ret		#16


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Wait until the keyboard transmit is complete
;
; Parameters: none
; Returns: r1 = 0 if successful, r1 = -1 timeout
; Modifies: r1
; Stack Space: 3 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_KeybdWaitTx:
		push  lr
		push	r2
    push  r3
		ldi		r3,#100			; wait a max of 1s
.0001:
		call	_KeybdGetStatus
		bbs	  r1,#6,.0002	; check for transmit complete bit; branch if bit set
		call	_Wait10ms		; delay a little bit
		sub   r3,r3,#1
		bne	  r3,r0,.0001	; go back and try again
		lw		r3,[sp]
		lw		r2,8[sp]		; timed out
		lw		lr,16[sp]
		ldi		r1,#-1			; return -1
		ret		#24
.0002:
		lw		r3,[sp]
		lw		r2,8[sp]		; wait complete, return 
		lw		lr,16[sp]
		ldi		r1,#0				; return 0
		ret		#24


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Get the keyboard status
;
; Parameters: none
; Returns: r1 = status
; Modifies: r1
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_KeybdGetStatus:
		ldi		$r1,#KEYBD+1
		lvb		$r1,[$r1+$r0]
		memdb
		ret

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Get the scancode from the keyboard port
;
; Parameters: none
; Returns: r1 = scancode
; Modifies: r1
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_KeybdGetScancode:
		ldi		$r1,#KEYBD
		lvbu	$r1,[$r1+$r0]		; get the scan code
		memdb									; need the following store in order
		sb		$r0,KEYBD+1			; clear receive register
		memdb
		ret

;===============================================================================
; Generic I2C routines
;===============================================================================

I2C_PREL	EQU		$0
I2C_PREH	EQU		$1
I2C_CTRL	EQU		$2
I2C_RXR		EQU		$3
I2C_TXR		EQU		$3
I2C_CMD		EQU		$4
I2C_STAT	EQU		$4

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; i2c initialization, sets the clock prescaler
;
; Parameters: none
; Returns: none
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_i2c_init:
		push	r6
		ldi		r6,#I2C
		ldi		r1,#4								; setup prescale for 400kHz clock
		sb		r1,I2C_PREL[r6]
		sb		r0,I2C_PREH[r6]
		lw		r6,[sp]
		ret		#8

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Wait for I2C transfer to complete
;
; Parameters
; 	a0 - I2C controller base address
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

i2c_wait_tip:
		push		r1
.0001:					
		lb			r1,I2C_STAT[$a0]
		bbs			r1,#1,.0001				; wait for tip to clear
		lw			r1,[sp]
		ret			#8

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Write command to i2c
;
; Parameters
;		a2 - data to transmit
;		a1 - command value
;		a0 - I2C controller base address
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

i2c_wr_cmd:
		push		lr
		sb			$a2,I2C_TXR[$a0]
		memdb
		sb			$a1,I2C_CMD[$a0]
		memdb
		call		i2c_wait_tip
		lb			$r1,I2C_STAT[$a0]
		lw			lr,[sp]
		ret			#8

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Parameters
;		a0 - I2C controller base address
;		a1 - data to send
; Returns: none
; Stack space: 3 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_i2c_xmit1:
		push		lr
		push		$a1								; save data value
		push		$a2
		ldi			$a1,#1
		sb			$a1,I2C_CTRL[$a0]	; enable the core
		memdb
		ldi			$a2,#$76					; set slave address = %0111011
		ldi			$a1,#$90					; set STA, WR
		call		i2c_wr_cmd
		call		i2c_wait_rx_nack
		lw			$a2,[sp]					; get back data value
		add			sp,sp,#8
		ldi			$a1,#$50					; set STO, WR
		call		i2c_wr_cmd
		call		i2c_wait_rx_nack
		lw			$a2,[sp]
		lw			$a1,8[sp]
		lw			lr,16[sp]
		ret			#24

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

i2c_wait_rx_nack:
		push		$a1
.0001:
		lb			$a1,I2C_STAT[$a0]	; wait for RXack = 0
		bbs			$a1,#7,.0001
		lw			$a1,[sp]
		ret			#8

;===============================================================================
; Realtime clock routines
;===============================================================================

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Read the real-time-clock chip.
;
; The entire contents of the clock registers and sram are read into a buffer
; in one-shot rather than reading the registers individually.
;
; Parameters: none
; Returns: r1 = 0 on success, otherwise non-zero
; Modifies: r1 and RTCBuf
; Stack space: 6 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_rtc_read:
		push		lr
		push		$r3
		push		$a0
		push		$a1
		push		$a2
		push		$a3
		ldi			$a0,#I2C
		ldi			$a3,#RTCBuf
		ldi			$r1,#$80
		sb			$r1,I2C_CTRL[$a0]	; enable I2C
		ldi			$a2,#$DE			; read address, write op
		ldi			$a1,#$90			; STA + wr bit
		call		i2c_wr_cmd
		bbs			$r1,#7,.rxerr
		ldi			$a2,#$00			; address zero
		ldi			$a1,#$10			; wr bit
		call		i2c_wr_cmd
		bbs			$r1,#7,.rxerr
		ldi			$a2,#$DF			; read address, read op
		ldi			$a1,#$90			; STA + wr bit
		call		i2c_wr_cmd
		bbs			$r1,#7,.rxerr
		
		ldi			$r2,#$00
.0001:
		ldi			$r3,#$20
		sb			$r3,I2C_CMD[$a0]	; rd bit
		call		i2c_wait_tip
		call		i2c_wait_rx_nack
		lb			$r1,I2C_STAT[$a0]
		bbs			$r1,#7,.rxerr
		lb			$r1,I2C_RXR[$a0]
		sb			$r1,[$a3+$r2]
		add			$r2,$r2,#1
		slt			$r1,$r2,#$5F
		bne			$r1,$r0,.0001
		ldi			$r1,#$68
		sb			$r1,I2C_CMD[$a0]	; STO, rd bit + nack
		call		i2c_wait_tip
		call		i2c_wait_rx_nack
		lb			$r1,I2C_STAT[$a0]
		bbs			$r1,#7,.rxerr
		lb			$r1,I2C_RXR[$a0]
		sb			$r1,[$a3+$r2]
		mov			$r1,$r0						; return 0
.rxerr:
		sb			$r0,I2C_CTRL[$a0]	; disable I2C and return status
		lw			$a3,[sp]
		lw			$a2,8[sp]
		lw			$a1,16[sp]
		lw			$a0,24[sp]
		lw			$r3,32[sp]
		lw			lr,40[sp]
		ret			#48

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Write the real-time-clock chip.
;
; The entire contents of the clock registers and sram are written from a 
; buffer (RTCBuf) in one-shot rather than writing the registers individually.
;
; Parameters: none
; Returns: r1 = 0 on success, otherwise non-zero
; Modifies: r1 and RTCBuf
; Stack space: 6 words
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

_rtc_write:
		push		lr
		push		$r3
		push		$a0
		push		$a1
		push		$a2
		push		$a3
		ldi			$a0,#I2C
		ldi			$a3,#RTCBuf
		ldi			$r1,#$80
		sb			$r1,I2C_CTRL[$a0]	; enable I2C
		ldi			$a2,#$DE			; read address, write op
		ldi			$a1,#$90			; STA + wr bit
		call		i2c_wr_cmd
		bbs			$r1,#7,.rxerr
		ldi			$a2,#$00			; address zero
		ldi			$a1,#$10			; wr bit
		call		i2c_wr_cmd
		bbs			$r1,#7,.rxerr

		ldi			$r2,#0
.0001:
		lb			$a2,[$a3+$r2]
		ldi			$a1,#$10
		call		i2c_wr_cmd
		bbs			$r1,#7,.rxerr
		add			$r2,$r2,#1
		slt			$r1,$r2,#$5F
		bne			$r1,$r0,.0001
		lb			$a2,[$a3+$r2]
		ldi			$a1,#$50			; STO, wr bit
		call		i2c_wr_cmd
		bbs			$r1,#7,.rxerr
		mov			$r1,$r0						; return 0
.rxerr:
		sb			$r0,I2C_CTRL[$a0]	; disable I2C and return status
		lw			$a3,[sp]
		lw			$a2,8[sp]
		lw			$a1,16[sp]
		lw			$a0,24[sp]
		lw			$r3,32[sp]
		lw			lr,40[sp]
		ret			#48

;===============================================================================
; String literals
;===============================================================================

MsgBoot:
		db		"FT64 ROM BIOS v1.0",0
msgBadKeybd:
		db		"Keyboard not responding.",0
msgRtcReadFail:
		db		"RTC read/write failed.",$0D,$0A,$00

		align		2

;===============================================================================
;===============================================================================
;===============================================================================
;===============================================================================
	align	16
font8:
	db	$00,$00,$00,$00,$00,$00,$00,$00	; $00
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; $04
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; $08
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; $0C
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; $10
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; $14
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; $18
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; $1C
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; 
	db	$00,$00,$00,$00,$00,$00,$00,$00	; SPACE
	db	$18,$18,$18,$18,$18,$00,$18,$00	; !
	db	$6C,$6C,$00,$00,$00,$00,$00,$00	; "
	db	$6C,$6C,$FE,$6C,$FE,$6C,$6C,$00	; #
	db	$18,$3E,$60,$3C,$06,$7C,$18,$00	; $
	db	$00,$66,$AC,$D8,$36,$6A,$CC,$00	; %
	db	$38,$6C,$68,$76,$DC,$CE,$7B,$00	; &
	db	$18,$18,$30,$00,$00,$00,$00,$00	; '
	db	$0C,$18,$30,$30,$30,$18,$0C,$00	; (
	db	$30,$18,$0C,$0C,$0C,$18,$30,$00	; )
	db	$00,$66,$3C,$FF,$3C,$66,$00,$00	; *
	db	$00,$18,$18,$7E,$18,$18,$00,$00	; +
	db	$00,$00,$00,$00,$00,$18,$18,$30	; ,
	db	$00,$00,$00,$7E,$00,$00,$00,$00	; -
	db	$00,$00,$00,$00,$00,$18,$18,$00	; .
	db	$03,$06,$0C,$18,$30,$60,$C0,$00	; /
	db	$3C,$66,$6E,$7E,$76,$66,$3C,$00	; 0
	db	$18,$38,$78,$18,$18,$18,$18,$00	; 1
	db	$3C,$66,$06,$0C,$18,$30,$7E,$00	; 2
	db	$3C,$66,$06,$1C,$06,$66,$3C,$00	; 3
	db	$1C,$3C,$6C,$CC,$FE,$0C,$0C,$00	; 4
	db	$7E,$60,$7C,$06,$06,$66,$3C,$00	; 5
	db	$1C,$30,$60,$7C,$66,$66,$3C,$00	; 6
	db	$7E,$06,$06,$0C,$18,$18,$18,$00	; 7
	db	$3C,$66,$66,$3C,$66,$66,$3C,$00	; 8
	db	$3C,$66,$66,$3E,$06,$0C,$38,$00	; 9
	db	$00,$18,$18,$00,$00,$18,$18,$00	; :
	db	$00,$18,$18,$00,$00,$18,$18,$30	; ;
	db	$00,$06,$18,$60,$18,$06,$00,$00	; <
	db	$00,$00,$7E,$00,$7E,$00,$00,$00	; =
	db	$00,$60,$18,$06,$18,$60,$00,$00	; >
	db	$3C,$66,$06,$0C,$18,$00,$18,$00	; ?
	db	$7C,$C6,$DE,$D6,$DE,$C0,$78,$00	; @
	db	$3C,$66,$66,$7E,$66,$66,$66,$00	; A
	db	$7C,$66,$66,$7C,$66,$66,$7C,$00	; B
	db	$1E,$30,$60,$60,$60,$30,$1E,$00	; C
	db	$78,$6C,$66,$66,$66,$6C,$78,$00	; D
	db	$7E,$60,$60,$78,$60,$60,$7E,$00	; E
	db	$7E,$60,$60,$78,$60,$60,$60,$00	; F
	db	$3C,$66,$60,$6E,$66,$66,$3E,$00	; G
	db	$66,$66,$66,$7E,$66,$66,$66,$00	; H
	db	$3C,$18,$18,$18,$18,$18,$3C,$00	; I
	db	$06,$06,$06,$06,$06,$66,$3C,$00	; J
	db	$C6,$CC,$D8,$F0,$D8,$CC,$C6,$00	; K
	db	$60,$60,$60,$60,$60,$60,$7E,$00	; L
	db	$C6,$EE,$FE,$D6,$C6,$C6,$C6,$00	; M
	db	$C6,$E6,$F6,$DE,$CE,$C6,$C6,$00	; N
	db	$3C,$66,$66,$66,$66,$66,$3C,$00	; O
	db	$7C,$66,$66,$7C,$60,$60,$60,$00	; P
	db	$78,$CC,$CC,$CC,$CC,$DC,$7E,$00	; Q
	db	$7C,$66,$66,$7C,$6C,$66,$66,$00	; R
	db	$3C,$66,$70,$3C,$0E,$66,$3C,$00	; S
	db	$7E,$18,$18,$18,$18,$18,$18,$00	; T
	db	$66,$66,$66,$66,$66,$66,$3C,$00	; U
	db	$66,$66,$66,$66,$3C,$3C,$18,$00	; V
	db	$C6,$C6,$C6,$D6,$FE,$EE,$C6,$00	; W
	db	$C3,$66,$3C,$18,$3C,$66,$C3,$00	; X
	db	$C3,$66,$3C,$18,$18,$18,$18,$00	; Y
	db	$FE,$0C,$18,$30,$60,$C0,$FE,$00	; Z
	db	$3C,$30,$30,$30,$30,$30,$3C,$00	; [
	db	$C0,$60,$30,$18,$0C,$06,$03,$00	; \
	db	$3C,$0C,$0C,$0C,$0C,$0C,$3C,$00	; ]
	db	$10,$38,$6C,$C6,$00,$00,$00,$00	; ^
	db	$00,$00,$00,$00,$00,$00,$00,$FE	; _
	db	$18,$18,$0C,$00,$00,$00,$00,$00	; `
	db	$00,$00,$3C,$06,$3E,$66,$3E,$00	; a
	db	$60,$60,$7C,$66,$66,$66,$7C,$00	; b
	db	$00,$00,$3C,$60,$60,$60,$3C,$00	; c
	db	$06,$06,$3E,$66,$66,$66,$3E,$00	; d
	db	$00,$00,$3C,$66,$7E,$60,$3C,$00	; e
	db	$1C,$30,$7C,$30,$30,$30,$30,$00	; f
	db	$00,$00,$3E,$66,$66,$3E,$06,$3C	; g
	db	$60,$60,$7C,$66,$66,$66,$66,$00	; h
	db	$18,$00,$18,$18,$18,$18,$0C,$00	; i
	db	$0C,$00,$0C,$0C,$0C,$0C,$0C,$78	; j
	db	$60,$60,$66,$6C,$78,$6C,$66,$00	; k
	db	$18,$18,$18,$18,$18,$18,$0C,$00	; l
	db	$00,$00,$EC,$FE,$D6,$C6,$C6,$00	; m
	db	$00,$00,$7C,$66,$66,$66,$66,$00	; n
	db	$00,$00,$3C,$66,$66,$66,$3C,$00	; o
	db	$00,$00,$7C,$66,$66,$7C,$60,$60	; p
	db	$00,$00,$3E,$66,$66,$3E,$06,$06	; q
	db	$00,$00,$7C,$66,$60,$60,$60,$00	; r
	db	$00,$00,$3C,$60,$3C,$06,$7C,$00	; s
	db	$30,$30,$7C,$30,$30,$30,$1C,$00	; t
	db	$00,$00,$66,$66,$66,$66,$3E,$00	; u
	db	$00,$00,$66,$66,$66,$3C,$18,$00	; v
	db	$00,$00,$C6,$C6,$D6,$FE,$6C,$00	; w
	db	$00,$00,$C6,$6C,$38,$6C,$C6,$00	; x
	db	$00,$00,$66,$66,$66,$3C,$18,$30	; y
	db	$00,$00,$7E,$0C,$18,$30,$7E,$00	; z
	db	$0E,$18,$18,$70,$18,$18,$0E,$00	; {
	db	$18,$18,$18,$18,$18,$18,$18,$00	; |
	db	$70,$18,$18,$0E,$18,$18,$70,$00	; }
	db	$72,$9C,$00,$00,$00,$00,$00,$00	; ~
	db	$FE,$FE,$FE,$FE,$FE,$FE,$FE,$00	; 

	align 	64
_msgTestString:
	db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	db	"abcdefghijklmnopqrstuvwxyz"
	db	"0123456789#$",0

	align	8
cmp_insns:
	dh_htbl

	align	8
tblvect:
	dw	0
	dw	1
	dw	2
	dw	3
	dw	4
	dw	5
	dw	6
	dw	7
	dw	8
	dw	9
	dw	10
	dw	11
	dw	12
	dw	13
	dw	14
	dw	15

vec1data:
	dw	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
vec2data:
	dw	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2

;==============================================================================		
; This area reserved for libc
;==============================================================================		

.include "d:\Cores5\FT64\v7\software\c_standard_lib-master\libc.asm"

.include "d:\Cores5\FT64\v7\software\test\SieveOfE.s"
.include "d:\Cores5\FT64\v7\software\cc64libc\source\gc.s"
.include "d:\Cores5\FT64\v7\software\cc64libc\source\cc64rt.s"
.include "d:\Cores5\FT64\v7\software\boot\brkrout.asm"
.include "d:\Cores5\FT64\v7\software\boot\BIOSMain.s"
.include "d:\Cores5\FT64\v7\software\boot\FloatTest.s"
;.include "d:\Cores5\FT64\v7\software\boot\ramtest.s"
	align	4096
;.include "d:\Cores5\FT64\v7\software\cc64libc\source\stdio.s"
;.include "d:\Cores5\FT64\v7\software\cc64libc\source\ctype.s"
;.include "d:\Cores5\FT64\v7\software\cc64libc\source\string.s"
;.include "d:\Cores5\FT64\v7\software\cc64libc\source\malloc.s"
.include "d:\Cores5\FT64\v7\software\cc64libc\source\putch.s"
.include "d:\Cores5\FT64\v7\software\cc64libc\source\puthexnum.s"
.include "d:\Cores5\FT64\v7\software\cc64libc\source\prtflt.s"
.include "d:\Cores5\FT64\v7\software\cc64libc\source\FT64\io.s"
.include "d:\Cores5\FT64\v7\software\cc64libc\source\FT64\getCPU.s"
	align	4096
.include "d:\Cores5\FT64\v7\software\c64libc\source\libquadmath\log10q.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\LockSemaphore.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\UnlockSemaphore.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\console.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\PIT.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\PIC.s"
	align	4096
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\FMTKc.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\FMTKmsg.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\TCB.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\IOFocusc.s"

.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\keybd.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\memmgnt3.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\app.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\shell.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\misc.s"
.include "d:\Cores5\FT64\v7\software\FMTK\source\monitor.s"
.include "d:\Cores5\FT64\v7\software\bootrom\source\video.asm"
.include "d:\Cores5\FT64\v7\software\bootrom\source\TinyBasicDSD9.asm"

	align	4096
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\scancodes.asm"
.include "d:\Cores5\FT64\v7\software\FMTK\source\kernel\fmtk_vars.asm"
