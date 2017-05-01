include "ring.asm"
include "task.asm"


SECTION "Scheduler RAM", WRAM0

; For now, we have a super simple round-robin scheduler.

; RunList is a ring.
; We assume it can never fill since tasks shouldn't be able to be in there twice.
; We assume it can never empty since we should never have no runnable tasks for now.
RUN_LIST_SIZE EQU MAX_TASKS
RunList::
	RingDeclare RUN_LIST_SIZE

SECTION "Scheduler", ROM0

; Initialize scheduler structs
SchedInit::
	RingInit RunList, RUN_LIST_SIZE
	ret

; Enqueue a task with task id in B to be scheduled
; Clobbers A, H, L.
SchedAddTask::
	RingPushNoCheck RunList, RUN_LIST_SIZE, B
	ret

; Choose next task to run and run it.
; Does not return.
SchedLoadNext::
	RingPopNoCheck RunList, RUN_LIST_SIZE, B

	; immediately re-enqueue it
	RingPushNoCheck RunList, RUN_LIST_SIZE, B

	ld A, B
	jp TaskLoad ; does not return
