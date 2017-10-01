include "macros.asm"
include "longcalc.asm"
include "vram.asm"
include "ioregs.asm"
include "hram.asm"


; Timing info for keeping the vblank handler from running too long
VBLANK_INITIAL_CREDITS EQU 60
; One credit is very roughly 11 cycles. DMA + setup takes a bit over 160 cycles.
; 160/11 ~= 14.5, we add a little leeway
VBLANK_SPRITE_DMA_COST EQU 16


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

; An aside on the tradeoffs of the same approach as above for OAM (sprite) RAM.
; If we were to use this method, it would cost us 256b of RAM, and 45+11/item cycles.
; In comparison, using the hardware DMA method costs us 160b of RAM and 160 cycles.
; It only takes 11 items before the queue method is slower.
; We still use a dirty flag to know when to do the DMA,
; though we store that dirty flag in HRAM so we can clear it during otherwise useless DMA time.

; This is the shadow sprite table that can be updated whenever and gets copied during VBlank.
; Aligned so we can do DMA.
WorkingSprites::
	ds 40 * 4


SECTION "Graphics system functions", ROM0


; Init graphics system. Display must be disabled.
GraphicsInit::
	; Load core tile data
	ld HL, FontTileData
	ld DE, OverlapTileMap + $20 * $10 ; first char in font is ' ' = $20, each char is 16 bytes
	ld BC, FONT_TILE_DATA_SIZE
	LongCopy ; Copy BC bytes from HL to DE

	; Init queues by zeroing heads and lengths
	xor A
	ld HL, TileQueueInfo
REPT 8
	ld [HL+], A
ENDR

	; Init sprite ram (and working sprites) to disable all sprites by setting Y = 0
	ld HL, WorkingSprites
	ld B, 40
	call ClearSprites
	ld HL, SpriteTable
	ld B, 40
	call ClearSprites

	; Init DirtySprites to not dirty
	xor A
	ld [DirtySprites], A

	; Copy DMAWait into place
	ld HL, _DMAWaitROM
	ld DE, DMAWait
	ld B, DMA_WAIT_SIZE
	Copy ; Copy B bytes from HL to DE

	ret


; Helper function that disables B sprites starting from address HL.
; We disable sprites by setting Y = 0.
; Clobbers A, B, HL.
ClearSprites::
	xor A
.loop
	ld [HL+], A
	inc L
	inc L
	inc L ; note we know L won't wrap because sprite ram is always aligned
	dec B
	jr nz, .loop
	ret


; Function that executes in HRAM during an ongoing DMA.
; Do not call this function - it gets copied to DMAWait in HRAM. Call that instead.
; It also clears DirtySprites.
; Expects A = high byte of WorkingSprites to save space.
; Clobbers A.
_DMAWaitROM:
	ldh [DMATransfer], A ; initiate DMA transfer. start 160 cycle timer. 2 bytes.
	ld A, 39 ; 2 cycles. 2 bytes.
.loop ; Loop runs for 38*4 + 1*3 = 155 cycles
	dec A ; 1 cycle. 1 byte.
	jr nz, .loop ; 3 cycles if taken, 2 if not. 2 bytes.
	ldh [DirtySprites], A ; DirtySprites = 0. 3 cycles. 2 bytes.
	; we should be done with the DMA by now, since ret accesses [SP].
	; cycles passed: 2 + 155 + 3 = 160.
	ret ; 1 byte
DMA_WAIT_SIZE_ACTUAL EQU @ - _DMAWaitROM
IF DMA_WAIT_SIZE_ACTUAL != DMA_WAIT_SIZE
FAIL "DMAWait routine size mismatch: Expected {DMA_WAIT_SIZE}, got {DMA_WAIT_SIZE_ACTUAL}"
ENDC


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

	; Sprites get priority update over background
	ld A, [DirtySprites]
	and A ; set z if A = 0
	jr z, .no_sprites
	ld A, B ; TODO we can do this bit during the DMA to shave cycles
	sub VBLANK_SPRITE_DMA_COST ; note we assume we can always afford since we're first priority
	ld B, A
	ld A, WorkingSprites >> 8
	call DMAWait ; calls into HRAM routine to do the transfer and unset DirtySprites
.no_sprites

; Helper macro for unrolling loop. Takes loop iteration 0-3 as \1.
; Cycle cost (worst case): 45 + 11/item
_GraphicsVBlankLoop: MACRO
	ld A, [HL+] ; A = queue length, HL now points at queue head
	and A ; set z if A == 0
	jr z, .inc_hl_and_next\@
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
	jr nc, .can_afford\@
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
	jr nz, .queue_loop\@ ; consider unrolling? lose granularity in time credits
	pop HL ; HL = next queue length

.inc_hl_and_next\@
	inc HL
ENDM

	_GraphicsVBlankLoop 0
	_GraphicsVBlankLoop 1
	_GraphicsVBlankLoop 2
	_GraphicsVBlankLoop 3

	; If we've reached here, we either never ran out of credits, or we ran out in the last loop
	; We check if there are any left (it's ok for us to consider 'exactly enough' as 'not enough' here)
	ld A, B
	and A ; set z if A == 0
	jr z, .ret ; if we ran out, return now

	; If we never ran out of credits, all queues are now empty.
	; We disable any future vblank interrupts from happening at all, until a new value is written
	ld HL, InterruptsEnabled
	res 0, [HL] ; reset bit 0 of Interrupt Enable register

.ret
	pop HL
	pop DE
	pop BC
	pop AF
	reti


; VBlank interrupt handler turns itself off if it completes all work,
; this function turns it back on and should be called after giving it more work.
; Clobbers HL.
GraphicsEnableVBlank::
	; Make sure to clear any pending VBlank first, or else it'll fire immediately!
	ld HL, InterruptFlags
	res 0, [HL] ; clear vblank flag in InterruptFlags register
	ld HL, InterruptsEnabled
	set 0, [HL] ; set vblank flag in InterruptsEnabled register
	ret


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
	ld A, TileQueues >> 8
	add D
	ld H, A ; H = TileQueues high byte + D
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

	call GraphicsEnableVBlank

	xor A ; A = 0 to indicate success
	ret


; As GraphicsTryWriteTile, but callable from tasks
T_GraphicsTryWriteTile::
	call T_DisableSwitch
	call GraphicsTryWriteTile
	ld H, A ; safekeeping, since T_EnableSwitch clobbers A
	call T_EnableSwitch
	ld A, H
	ret


; As T_GraphicsTryWriteTile, but blocks until the write succeeds.
; Clobbers A, HL.
; Note: Since this may block, there is no non-T_ version
T_GraphicsWriteTile::
	; TODO for now, busy loop. Use something smarter involving scheduler later.
.loop
	call T_GraphicsTryWriteTile
	and A ; set z on success
	jr nz, .loop
	ret


; Writes a sprite to the sprite table and sets the flag for it to be drawn next frame.
; A = sprite index, B = X coord, C = Y coord, D = Tile number, E = flags.
; Clobbers A, HL.
GraphicsWriteSprite::
	rla
	rla ; Shift A left twice, ie. A = 4 * A. Note the rotate is equiv to shift because A < 64.
	LongAddToA WorkingSprites >> 8,WorkingSprites & $ff, H,L ; HL = WorkingSprites + A
	; In order to avoid a half-written sprite from being drawn, we ensure no draw will occur
	; until we are done. We do this by clearing the dirty flag regardless of whether it was set.
	; We know this won't be overwritten because we've disabled switching when calling this function.
	xor A
	ld [DirtySprites], A
	ld A, C
	ld [HL+], A ; Y coord = C, HL points to X coord
	ld A, B
	ld [HL+], A ; X coord = B, HL points to tile number
	ld A, D
	ld [HL+], A ; Tile number = D, HL points to flags
	ld [HL], E ; Flags = E
	; Now we set the dirty flag so the sprite will be drawn next frame.
	jp GraphicsSetDirtySprites


; Set dirty sprites flag so that sprites will be drawn to screen next frame.
; Clobbers A, HL
GraphicsSetDirtySprites::
	ld A, 1
	ld [DirtySprites], A
	jp GraphicsEnableVBlank


T_GraphicsWriteSprite::
	ld H, A ; DisableSwitch clobbers A
	call T_DisableSwitch
	ld A, H
	call GraphicsWriteSprite
	jp T_EnableSwitch


T_GraphicsSetDirtySprites::
	call T_DisableSwitch
	call GraphicsSetDirtySprites
	jp T_EnableSwitch
