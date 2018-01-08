IF !DEF(_G_HRAM)
_G_HRAM EQU "true"

RSSET $ff80

; Machine uptime. Used for various timekeeping purposes.
; Accurate as long as interrupts are not disabled for longer than 1/2^10 seconds (~1ms).
; 32-bit unsigned int, little-endian. Units are 1/2^10 seconds (~1ms). Wraps every 48 days.
Uptime rb 4

; Count of how many 2^-10sec increments left until the next task switch.
; Reset on each switch.
SwitchTimer rb 1

; Currently running (or most recent) task ID. A task ID is an offset into the tasks array.
CurrentTask rb 1

; Currently loaded RAM and ROM banks.
CurrentROMBank rb 1
CurrentRAMBank rb 1

; Flag for whether we are allowed to do a time-sharing switch right now.
; Used to create critical sections without needing to disable interrupts all together.
; Possible values:
;   0 - Allowed to switch
;   1 - Not allowed to switch
;   2 - An attempt to switch was made while switching was disabled
Switchable rb 1

; Most recent joypad state. Bits are, from most to least signifigant,
; Down Up Left Right Start Select B A
JoyState rb 1


; Whether working sprite ram should be copied into real sprite ram next VBlank:
; 0 - Not dirty (don't copy)
; 1 - Dirty (copy)
DirtySprites rb 1


; Detected GB hardware we're running on:
; 0 - Original GB or SGB
; 1 - GB Pocket or SGB2
; 2 - Color GB
; 3 - Gameboy Advance
; 4 - Unknown (none of them matched - probably a leaky emulator)
; The main difference you'll care about most of the time is if CGB functionality is available.
; This is the case for 2 and 3, ie. check if bit 1 is set.
HardwareVariant rb 1

; This is where the DMA wait routine will be copied in. This size must match that routine's size.
; The routine is not heavily size-optimised, and can be changed if we're short on HRAM.
DMA_WAIT_SIZE EQU 10
DMAWait rb DMA_WAIT_SIZE


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
	xor A
	ld [Switchable], A
	ENDM

ENDC
