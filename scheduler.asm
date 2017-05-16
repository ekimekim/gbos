include "ring.asm"
include "task.asm"


SECTION "Scheduler RAM", WRAM0

; For now, we have a super simple round-robin scheduler.

; RunList is a ring.
; We assume it can never fill since tasks shouldn't be able to be in there twice.
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
	RingPop RunList, RUN_LIST_SIZE, B
	jp nz, .found
	halt
	jp .loop

.found
	; immediately re-enqueue it
	RingPushNoCheck RunList, RUN_LIST_SIZE, B

	ld A, B
	jp TaskLoad ; does not return
