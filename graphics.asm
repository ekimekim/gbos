include "macros.asm"
include "longcalc.asm"
include "vram.asm"


; Timing info for keeping the vblank handler from running too long
VBLANK_INITIAL_CREDITS EQU 60


SECTION "Core assets", ROM0

FontTileData:
include "assets/font.asm"
FONT_TILE_DATA_SIZE EQU @ - FontTileData


SECTION "Graphics system RAM", WRAM0

; For now, we make no attempt to mediate access. But if more than one task is writing
; they're gonna be uncoordinated and have a bad time.

TileQueueInfo:
; Array of 4 x (length, head) info for the respective tile queues in TileQueues.
; - length: length of tile queue, in items, 0 to 128.
; - head: head of tile queue as index into queue.
;   Valid items in queues are from head - 2 * length to head - 1.
	ds 2 * 4


SECTION "Graphics system aligned RAM", WRAMX[$d000]

; An array of 4 tile queues, each 256 bytes long.
; Each queue is 128 entries of 2 bytes (addr, value), where addr is the lower byte of
; the tilemap address to write into.
; Aligned so we can select the queue with the high byte and address into it with the low.
TileQueues:
	ds 256 * 4


SECTION "Graphics system functions", ROM0


; Init graphics system. Display must be disabled.
GraphicsInit::
	; Load core tile data
	ld HL, FontTileData
	ld DE, OverlapTileMap + $20 ; first char in font is ' ' = $20
	ld BC, FONT_TILE_DATA_SIZE
	LongCopy ; Copy BC bytes from HL to DE

	; Init queues by zeroing heads and lengths
	xor A
	ld HL, TileQueueInfo
REPT 8
	ld [HL+], A
ENDR

	; TODO remove this testing code that intentionally writes garbage
	ld HL, TileQueueInfo
	ld [HL], 1
	inc HL
	inc HL
	ld [HL], 1
	inc HL
	inc HL
	ld [HL], 1
	inc HL
	inc HL
	ld [HL], 128
	inc HL
	inc HL
	ret


; VBlank handler that actually does the writes.
; It does as much as it can before vblank time runs out, then returns.
GraphicsVBlank::
	push AF
	push BC
	push DE
	push HL

	ld HL, TileQueueInfo

	; We use a primitive scheme of timekeeping here, where we have a number of 'credits'.
	; Doing a queue item write costs 1 credit.
	; We check if we can afford actions before doing them and track how many we have left.
	; This prevents us running too long and not being in vblank anymore.
	ld B, VBLANK_INITIAL_CREDITS

	; A possible improvement - read io regs to determine where in vblank we are,
	; preventing a delayed interrupt from causing havoc.

; Helper macro for unrolling loop. Takes loop iteration 0-3 as \1.
; Cycle cost (worst case): 45 + 11/item
_GraphicsVBlankLoop: MACRO
	ld A, [HL+] ; A = queue length, HL now points at queue head
	and A ; set z if A == 0
	jp z, .inc_hl_and_next\@
	; queue mode
	ld C, A
	ld D, A ; C = D = length for safekeeping
	ld A, [HL-] ; A = queue head, HL points at queue length
	sub C
	sub C
	ld E, A ; E = queue head - 2 * queue length = queue tail
	        ; we want this in L eventually but need HL for now
	ld A, B ; A = time credits remaining
	and A ; set z if we have no time credits left
	jp z, .ret ; return if we're out of time
	sub C ; A = time credits - items, set c if too many items
	jp nc, .can_afford\@
	ld C, B ; C = all remaining time credits
	xor A ; A = 0 in prep for next line, faster than having two paths
.can_afford\@
	ld B, A ; set remaining credits to A (either subtract result or 0)
	ld A, D ; A = original length
	sub C ; A -= actual length we're consuming. A = remaining length.
	ld [HL+], A ; update queue's length, point HL at queue head
	push HL
	ld L, E ; L = queue tail
	ld H, (TileQueues >> 8) + \1 ; HL = addr of queue tail slot
	ld D, (TileGrid >> 8) + \1 ; by setting E, we can now manipulate DE = addr into TileGrid
	; We're finally ready. C is the loop counter.
.queue_loop\@
	ld A, [HL+] ; L will only ever wrap around on every second increment, so this is safe
	            ; since we DON'T want H to change. A = target addr low byte.
	ld E, A ; DE = target addr
	ld A, [HL] ; NOT safe to HL+ here because we don't want H to increment if L wraps
	ld [DE], A ; set value in array
	inc L
	dec C
	jp nz, .queue_loop\@ ; consider unrolling? lose granularity in time credits
	pop HL ; HL = next queue length

.inc_hl_and_next\@
	inc HL
ENDM

	_GraphicsVBlankLoop 0
	_GraphicsVBlankLoop 1
	_GraphicsVBlankLoop 2
	_GraphicsVBlankLoop 3

.ret
	pop HL
	pop DE
	pop BC
	pop AF
	reti



;; Set tile at tilemap index DE to value C
;; TODO needs fixing after TileQueueLengths/Heads became Info.
;GraphicsWriteTile::
;	; We assume we're the only writer, but we need to be constantly aware that vblank could
;	; occur and change the queues at any time.
;
;	LongAdd 0,D, TileQueueLengths >> 8,TileQueueLengths & $ff, H,L ; HL = TileQueueLengths + D
;	ld A, $ff
;
;	; Since vblank can convert an array-mode queue back into queue mode, we need to check
;	; for and possibly apply an update to an array-mode queue with interrupts disabled.
;	di
;	cp [HL] ; set z if length = $ff, ie. queue is in array-mode.
;	jp .queuemode
;	ld A, D
;	add TileQueues >> 8
;	ld D, A ; DE = TileQueue in question + index into array
;	ld A, C
;	ld [DE], A ; Write new value into array
;	reti ; With that, we're done! Enable interrupts and return.
;.queuemode
;	ei
;
;	; Since vblank can only take mode from array to queue, and we know it's currently in queue mode,
;	; we can assume it stays in queue mode until we change it.
;
;	push HL ; push addr of queue length to stack, useful later
;	; Repoint HL from its index into TileQueueLengths to the same index of TileQueueHeads
;	RepointStruct HL, TileQueueLengths, TileQueueHeads
;	; Note there is always room to add another item before considering if we've hit threshold.
;	
;	; TODO UPTO
