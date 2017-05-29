include "ring.asm"
include "task.asm"
include "hram.asm"


SECTION "Scheduler RAM", WRAM0

; For now, we have a super simple round-robin scheduler.

; RunList is a ring.
; We assume it can never fill since tasks shouldn't be able to be in there twice.
RUN_LIST_SIZE EQU MAX_TASKS
RunList:
	RingDeclare RUN_LIST_SIZE

; NextWakeTime is a 4-byte integer containing Uptime value at which time the next
; sleeping task is to be woken.
NextWakeTime:
	ds 4
; NextWake contains the task id to be woken at NextWakeTime, or $ff if none.
NextWake:
	db
; SleepingTasks is an array of sleeping task ids, in wake order.
; It is terminated by a $ff
SleepingTasks:
	ds MAX_TASKS ; NextWake contains one task, but we also need one byte for terminator
; SleepTimeDeltas is an array of 16-bit values which indicate the number of time ticks AFTER
; the previous entry that the respective task from SleepingTasks should be woken.
; Not terminated - SleepTimeDeltas array entry is valid only of SleepingTasks entry is.
SleepTimeDeltas:
	ds (MAX_TASKS + (-1)) * 2


SECTION "Scheduler", ROM0

; Initialize scheduler structs
SchedInit::
	RingInit RunList, RUN_LIST_SIZE
	ld A, $ff
	ld [SleepingTasks], A ; set length to 0 by setting first item to terminator
	ret

; Enqueue a task with task id in B to be scheduled
; Clobbers A, H, L.
SchedAddTask::
	RingPushNoCheck RunList, RUN_LIST_SIZE, B
	ret

; task-callable version of SchedAddTask
T_SchedAddTask::
	call T_DisableSwitch
	call SchedAddTask
	jp T_EnableSwitch


; Choose next task to run and run it.
; Does not return.
SchedLoadNext::

	; halt loop until any task is ready
.loop
	; TODO checking for now-enquable items goes here
	call CheckNextWake
	RingPop RunList, RUN_LIST_SIZE, B
	jp nz, .found
	halt
	jp .loop

.found
	; immediately re-enqueue it
	RingPushNoCheck RunList, RUN_LIST_SIZE, B

	ld A, B
	jp TaskLoad ; does not return


; Put task in B to sleep for DE time units
SchedSleepTask::
	; First, we calculate our target wake time by adding current time
	; We need to disable timer interrupt for the duration so we can get a consistent read.
	; HLDE = Uptime + DE
	; We want to use HL to point to uptime for speed, so we temporarily use H,
	; and move all the memory reads earlier.
	ld HL, Uptime
	di
	ld A, [HL+]
	add E
	ld E, A
	ld A, [HL+]
	adc D
	ld D, A
	ld A, [HL+]
	ld H, [HL]
	ei ; we're done reading from Uptime
	adc 0
	ld L, A
	xor A
	adc H
	ld H, A
	; HLDE now contains target time

	; We only support 16-bit deltas. We know that as long as NextWakeTime is after now,
	; the difference from our target time < 16 bits because target time can only be up to 16 bits after now.
	; Easiest way to check that is just to wake it if it's ready.
	; This had to be done after the above, otherwise a race can occur where NextWake becomes ready between the two operations.
	push BC
	push DE
	push HL
	call CheckNextWake
	pop HL
	pop DE
	; Note: not popping BC here since we're about to clobber it below and will need B later.

	; check if NextWake is empty ($ff) - if so, we can just put target time in and finish
	ld A, [NextWake]
	and $ff
	jp nz, .not_empty
	ld B, H
	ld C, L
	ld HL, NextWakeTime ; to make below load faster, BC = HL so we can use HL for NextWakeTime addr
	; so now BCDE contains target time. Now we set NextWakeTime = BCDE.
	ld A, E
	ld [HL+], A
	ld A, D
	ld [HL+], A
	ld A, C
	ld [HL+], A
	ld A, B
	ld [HL+], A
	pop BC ; B = target task
	ld A, B
	ld [NextWake], A ; NextWake = target task
	ret

.not_empty
	; BC = NextWakeTime - HLDE and set carry depending on if we borrow
	; (we do it in this order since it doesn't really matter and the load instructions work out easier)
	LongSub [NextWakeTime+1],[NextWakeTime], D,E, B,C ; BC = bottom word of NextWakeTime - DE, and set carry
	; for the rest of the calculation, we don't care about result (it'll be either 0 or -1)
	; we just need to know the final carry state
	ld A, [NextWakeTime+2]
	sbc L
	ld A, [NextWakeTime+3]
	sbc H
	; if our target time was before NextWakeTime:
	;   carry is unset, BC = time from target time to NextWakeTime
	; if our target time was after NextWakeTime:
	;   carry is set, BC = -(time from NextWakeTime to target time)
	jp c, .target_after_next

	; target time is before NextWake, swap them and push old NextWake to sleeping tasks instead
	; NextWakeTime = HLDE = target time
	ld A, E
	ld [NextWakeTime], A
	ld A, D
	ld [NextWakeTime+1], A
	ld A, L
	ld [NextWakeTime+2], A
	ld A, H
	ld [NextWakeTime+3], A
	; DE = BC = time from target time to old nextwake time
	ld D, B
	ld E, C
	pop BC ; B = target task
	ld HL, NextWake
	ld A, [HL]
	ld [HL, B]
	ld B, A ; Swap target task and old NextWake task
	; TODO DE = delta, B = task, indicate somehow that we know it's the smallest time and goes on head, then call some spot below to do the copy

.target_after_next
	; target time is after NextWake, push it to sleeping tasks
	; DE = -BC = time from NextWakeTime to target time
	xor A
	sub C
	ld E, A
	xor A
	sbc B
	ld D, A
	pop BC ; B = target task

	; We iterate through sleeping task times until we find our position in it
	ld HL, SleepTimeDeltas
	ld C, 0 ; C is index, HL is addr into SleepTimeDeltas

.maybe_insert_delta
	; if DE < [delta at HL], swap them and 


; Check to see if NextWakeTime has been reached, and if so wake the task.
; Clobbers all.
CheckNextWake:
	ld A, [NextWake]
	cp $ff
	ret z ; NextWake = $ff means no tasks to wake
	ld B, A ; Since we loaded it, we might as well not load it again later. B for safekeeping.

	; Compare Uptime to NextWakeTime. We need to disable timer interrupt for the duration
	; so we can get a consistent read.
	ld C, Uptime & $ff
	ld HL, NextWakeTime
	di
	REPT 3
	ld A, [C] ; A = Uptime byte
	cp [HL] ; Set c if A < [HL], ie. if Uptime < NextWakeTime. Set z if equal.
	reti c ; No wake, Uptime is before wake time. Ensure we re-enable interrupts.
	jr nz, .wake ; not equal, then Uptime > NextWakeTime, time to wake! Otherwise continue comparing.
	inc C
	inc HL ; inc both pointers and continue
	ENDR
	; This is the same as above, but without preparing for next loop
	ld A, [C]
	ei
	cp [HL]
	ret c

	; If we reached here, they're exactly equal, which counts as time to wake.
.wake
	call SchedAddTask ; enqueue NextWake to be scheduled (since it's still in B)

	; Now the hard part: new values for nextwake and friends

	; Copy SleepingTasks[0] to NextWake and copy everything in SleepingTasks forward
	ld HL, SleepingTasks
	ld C, $ff
	ld A, [HL+]
	ld [NextWake], A
	; iterate through array, copying everything forward an entry, up to and including terminator
	; we count with B to get the last valid (old) index
	cp C
	ret z ; if first entry is $ff, we're done - there were no more sleeping tasks to move up
	ld B, -1
.sleeping_copy_loop
	inc B
	ld A, [HL-]
	ld [HL+], A ; [HL - 1] = [HL], HL unchanged
	inc HL
	cp C ; set z if A was $ff
	jp nz, .sleeping_copy_loop

	; Calculate new NextWakeTime from SleepTimeDeltas[0]
	ld DE, SleepTimeDeltas
	ld HL, NextWakeTime
	; [HL:uint32le] += [DE:uint16le]
	ld A, [DE]
	add [HL]
	ld [HL+], A
	inc DE ; add lowest byte, inc both pointers
	ld A, [DE]
	adc [HL]
	ld [HL+], A ; add next byte, don't bother inc'ing DE since we're done with it
	; last two bytes
	REPT 2
	xor A
	adc [HL]
	ld [HL+], A
	ENDR

	; Copy everything in SleepTimeDeltas forward
	; Note that currently DE = SleepTimeDeltas + 1
	ld A, B
	add B ; BUG: overflow?
	LongAddToA D,E, H,L ; HL = DE + 2*B = index into SleepTimeDeltas of second byte of last previously-valid entry
	; We loop B times, iterating backwards along the array, saving current value for next iteration before overwriting it
	; At the start of each iteration, prev values are in DE
	; So to set up we start by reading into DE
	ld A, [HL-]
	ld D, A
	ld A, [HL-]
	ld E, A
.delta_copy_loop
	ld A, D
	ld D, [HL]
	ld [HL-], A
	ld A, E
	ld E, [HL]
	ld [HL-], A
	dec B
	jp nz, .delta_copy_loop

	ret
