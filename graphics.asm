include "macros.asm"
include "vram.asm"


; If the queue size exceeds this value, convert it from queue mode into array mode.
; Max 128.
QUEUE_MODE_THRESHOLD EQU 64


SECTION "Core assets", ROM0

FontTileData:
include "assets/font.asm"
FONT_TILE_DATA_SIZE EQU @ - FontTileData


SECTION "Graphics system RAM", RAM0

; For now, we make no attempt to mediate access. But if more than one task is writing
; they're gonna be uncoordinated and have a bad time.

; lengths of tile queues, in items, 0 to QUEUE_MODE_THRESHOLD.
; 255 means no queue, it's a straight copy, see below.
TileQueueLengths:
	ds 4
; heads of tile queues as index into queue.
; Valid items in queues are from head - length to head - 1.
TileQueueHeads:
	ds 4


SECTION "Graphics system aligned RAM", RAMX[$d000]

; An array of 4 tile queues, each 256 bytes long.
; Each queue is 128 entries of 2 bytes (addr, value), where addr is the lower byte of
; the tilemap address to write into.
; Aligned so we can select the queue with the high byte and address into it with the low.
; When the length is 255 (see above), it's no longer a queue but instead a direct array of
; values to write into the tilemap.
TileQueues:
	ds 256 * 4


SECTION "Graphics system functions", ROM0


; Init graphics system. Display must be disabled.
GraphicsInit::
	; Load core tile data
	ld HL, FontTileData
	ld DE, OverlapTileMap + $20 ; first char in font is ' ' = $20
	ld B, FONT_TILE_DATA_SIZE
	Copy ; Copy B bytes from HL to DE

	; Init queues by zeroing heads and lengths
	xor A
	ld HL, TileQueueLengths
REPT 4
	ld [HL+], A
ENDR
	ld HL, TileQueueHeads
REPT 4
	ld [HL+], A
ENDR

	ret


; VBlank handler that actually does the writes.
; It does as much as it can before vblank time runs out, then returns.
GraphicsVBlank::
	



; Set tile at tilemap index DE to value C
GraphicsWriteTile::
	; We assume we're the only writer, but we need to be constantly aware that vblank could
	; occur and change the queues at any time.

	LongAdd 0,D, TileQueueLengths >> 8,TileQueueLengths & $ff, H,L ; HL = TileQueueLengths + D
	ld A, $ff

	; Since vblank can convert an array-mode queue back into queue mode, we need to check
	; for and possibly apply an update to an array-mode queue with interrupts disabled.
	di
	cp [HL] ; set z if length = $ff, ie. queue is in array-mode.
	jp .queuemode
	ld A, D
	add TileQueues >> 8
	ld D, A ; DE = TileQueue in question + index into array
	ld A, C
	ld [DE], A ; Write new value into array
	reti ; With that, we're done! Enable interrupts and return.
.queuemode
	ei

	; Since vblank can only take mode from array to queue, and we know it's currently in queue mode,
	; we can assume it stays in queue mode until we change it.

	push HL ; push addr of queue length to stack, useful later
	; Repoint HL from its index into TileQueueLengths to the same index of TileQueueHeads
	RepointStruct HL, TileQueueLengths, TileQueueHeads
	; Note there is always room to add another item before considering if we've hit threshold.
	
	; TODO UPTO
