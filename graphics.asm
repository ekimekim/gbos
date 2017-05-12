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



; Set tile at tilemap index DE to value C
; Sets A to 0 on success, otherwise on failure.
; Clobbers HL.
GraphicsTryWriteTile::
	; We assume we're the only writer, but we need to be constantly aware that vblank could
	; run at any time.

	ld A, D
	add D
	LongAddToA TileQueueInfo >> 8,TileQueueInfo & $ff, H,L ; HL = TileQueueInfo + 2 * D
	; HL = length of D'th queue

	ld A, [HL+] ; A = length of queue, HL = addr of head
	cp 128 ; set carry if length < 128, ie. if there's room for another item
	ret nc ; if no carry, fail. A = length != 0 so we're indicating failure.

	push HL ; we'll need TileQueueInfo again later
	ld L, [HL] ; L = current queue head position
	ld A, TileQueueInfo >> 8
	add D
	ld H, A ; H = TileQueueInfo high byte + D
	; now HL = addr of queue head position
	ld [HL], E
	inc L
	ld [HL], C
	inc L ; add (index, value) to queue and set L to new queue head position
	ld A, L
	pop HL ; HL = addr of queue head in TileQueueInfo

	; This section needs to be done atomically, otherwise if vblank runs in between
	; it would do the wrong items.
	di
	ld [HL-], A ; set head to new value, set HL to length addr
	inc [HL] ; increment length
	ei

	xor A ; A = 0 to indicate success
	ret
