RSSET $ff80

; Machine uptime. Used for various timekeeping purposes.
; Accurate as long as interrupts are not disabled for longer than 1/2^10 seconds (~1ms).
; 32-bit unsigned int, big-endian. Units are 1/2^10 seconds (~1ms). Wraps every 48 days.
Uptime rb 4

; Currently running (or most recent) task ID. A task ID is an offset into the tasks array.
CurrentTask rb 1

; Flag for whether we are allowed to do a time-sharing switch right now.
; Used to create critical sections without needing to disable interrupts all together.
; Possible values:
;   0 - Allowed to switch
;   1 - Not allowed to switch
;   2 - An attempt to switch was made while switching was disabled
Switchable rb 1



; --- HRAM-related macros ---

; Prevent switching tasks due to time-sharing, for use in critical sections.
; This is the raw underlying action - most users should use T_DisableSwitch instead.
; Clobbers A.
DisableSwitch: MACRO
	ld A, 1
	ld [Switchable], A
	ENDM

; Allow switching tasks due to time-sharing.
; This is the raw underlying action - most users should use T_EnableSwitch instead.
; Clobbers A.
EnableSwitch: MACRO
	ld A, 0
	ld [Switchable], A
	ENDM
