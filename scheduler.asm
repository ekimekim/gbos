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


; Check to see if NextWakeTime has been reached, and if so wake the task.
CheckNextWake:
	ld A, [NextWake]
	cp $ff
	ret z ; NextWake = $ff means no tasks to wake
	ld B, A ; Since we loaded it, we might as well not load it again later. B for safekeeping.

	ld C, Uptime & $ff
	ld HL, NextWakeTime
	; Compare Uptime to NextWakeTime
	REPT 3
	ld A, [C] ; A = Uptime byte
	cp [HL] ; Set c if A < [HL], ie. if Uptime < NextWakeTime. Set z if equal.
	ret c ; No wake, Uptime is before wake time
	jr nz, .wake ; not equal, then Uptime > NextWakeTime, time to wake! Otherwise continue comparing.
	inc C
	inc HL ; inc both pointers and continue
	ENDR
	; This is the same as above, but without preparing for next loop
	ld A, [C]
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
	add B
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
