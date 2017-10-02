include "constants.asm"
include "longcalc.asm"
include "hram.asm"
include "ioregs.asm"
include "debug.asm"
include "macros.asm"


Section "Core Stack", WRAM0

CoreStackBase:
	ds CORE_STACK_SIZE
CoreStack::


Section "Core Functions", ROM0


; Temporary code for testing task switching
Start::

	; Disable LCD and audio.
	; Disabling LCD must be done in VBlank.
	; On hardware start, we have about 10-20 cycles of vblank before the first frame begins.
	; So this has to be done quick!
	; Note we save the A register to C before clearing it, as we need to save its initial value
	; for GB hardware detection below.
	ld C, A
	xor A
	ld [SoundControl], A
	ld [LCDControl], A

	; Initial state of A (stored in C) and B registers can be used to detect GB hardware variant
	; ie. GB/CGB/GBA/SGB.
	ld A, C
	cp $11 ; A = $11 means CGB or GBA
	jr nz, .notCGB
	; To distinguish between CGB and GBA, we further check bit 0 of B
	rrc B ; push lowest bit of B into carry flag
	ld A, 2
	jr nc, .setHardwareVariant ; leave A = 2 if CGB
	inc A ; otherwise set A = 3
	jr .setHardwareVariant
.notCGB
	cp $01 ; A = $01 means original GB or SGB
	jr nz, .notOriginalOrSGB
	xor A
	jr .setHardwareVariant
.notOriginalOrSGB
	cp $ff ; A = $ff means Pocket GB or SGB2
	jr nz, .notPGBorSGB2
	ld A, 1
	jr .setHardwareVariant
.notPGBorSGB2
	; if we've made it here, it means none of the known hardware indicators match.
	; this probably means a badly-written emulator which initialized everything to random or zero.
	ld A, 4
.setHardwareVariant
	ld [HardwareVariant], A

	Debug "Debug messages enabled. Expression test: A = %A%"

	; Use core stack
	ld SP, CoreStack

	; Set up timer
	ld A, TimerEnable | TimerFreq18
	ld [TimerControl], A
	xor A
	ld [Uptime], A
	ld [Uptime+1], A
	ld [Uptime+2], A
	ld [Uptime+3], A

	; Init things
	call TaskInit
	call SchedInit
	call GraphicsInit
	call JoyInit

	ld HL, GeneralDynMem
	ld B, GENERAL_DYN_MEM_SIZE
	call DynMemInit

	DisableSwitch

	ld A, %10000011 ; background map on + sprites
	ld [LCDControl], A

	xor A
	ld [TimerCounter], A ; Uptime timer starts from here
	ld [InterruptFlags], A ; Reset pending interrupts now that we're properly set up

	ld A, IntEnableTimer | IntEnableVBlank | IntEnableJoypad
	ld [InterruptsEnabled], A
	ei ; note we've still got switching disabled until we switch into our first task

	ld C, 0
	SetTaskNewEntryPoint Task1
	call TaskNewDynStack

	SetTaskNewEntryPoint TaskPaintMain
	call TaskNewDynStack

	SetTaskNewEntryPoint TaskClockMain
	call TaskNewDynStack

	jp SchedLoadNext ; does not return


Task1::
	ld A, 1
	ld B, 2
	ld C, 3
	ld D, 4
	ld E, 5
	ld HL, $face
.loop
	inc A
	jr .loop


Task2::
	ld B, 10
	call Fib
.loop
	jr .loop

; return Bth fibbonacci number in DE
; clobbers A
Fib:
	ld A, B
	cp 2
	jr nc, .noUnderflow
	ld D, 0
	ld E, 1
	ret ; return 1
.noUnderflow
	dec B
	call Fib ; DE = Fib(n-1)
	dec B
	push DE
	call Fib ; DE = Fib(n-2)
	ld H, D
	ld L, E
	pop DE
	LongAdd D,E, H,L, D,E ; DE += HL, ie. DE = Fib(n-1) + Fib(n-2)
	inc B
	inc B ; return B to initial value
	call T_TaskYield ; demonstrate yielding. Fib(B) should equal DE.
	ret


Task3::
	; write to screen in a loop, writing i'th tile to value (i+offset)%256 with changing offset
	ld C, 0
.outer
	inc C ; makes value 1 more out of phase with index

	ld DE, 50
	call T_SchedSleepTask ; sleep for 50ms

	ld DE, 0
.inner
	call T_GraphicsWriteTile
	inc C
	inc E
	jr nz, .inner
	inc D
	ld A, D
	cp 4 ; set z if DE = $0400
	jr nz, .inner
	jr .outer

