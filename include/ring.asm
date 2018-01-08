IF !DEF(_G_RING)
_G_RING EQU "true"

include "longcalc.asm"

; A ring is a fixed-size array that forms a queue.
; Ring capacities must be 1 less than powers of 2, up to 255.
; Structure is semi-threadsafe: It is safe for exactly one reader and one writer.
; Internal note: Our buffer is 1 more than our capacity, and head == tail means empty.

; --- Ring struct ---
RSRESET
ring_head rb 1 ; next slot to put a value in
ring_tail rb 1 ; next value to pop
ring_data rb 0 ; variable-length

RING_SIZE_NO_DATA rb 0

; Declare a ring in a RAM section of capacity \1
RingDeclare: MACRO
	; Check capacity is (2**n-1)
IF (\1) & ((\1) + 1) != 0
FAIL "\1 = {\1} is not a power of 2 minus 1"
ENDC
	ds RING_SIZE_NO_DATA + (\1) + 1
	ENDM

; Initialize a ring at immediate address \1
; Clobbers A.
RingInit: MACRO
	xor A
	ld [\1 + ring_head], A
	ld [\1 + ring_tail], A
	ENDM

; Return current number of items in ring at immediate \1 of capacity \2.
; Returns value in A. Clobbers B.
RingLen: MACRO
	ld A, [(\1) + ring_tail]
	ld B, A
	ld A, [(\1) + ring_head]
	sub B
	and \2 ; modulo capacity+1
	ENDM

; Push value in reg \3 (not A, H or L) to ring at immediate \1 of capacity \2.
; Clobbers A, H, L.
; Does NOT check if ring is full! Behaviour in that case is undefined.
RingPushNoCheck: MACRO
	ld A, [(\1) + ring_head]
	LongAddToA (\1)+ring_data, HL ; HL = \1 + ring_data + (value of ring_head) = addr of ring_head'th element of ring_data
	ld [HL], \3
	ld A, [(\1) + ring_head]
	inc A
	and \2 ; A = (A+1) % (capacity+1)
	ld [(\1) + ring_head], A
	ENDM

; Push value in reg \3 (not A, H or L) to ring at immediate \1 of capacity \2.
; You must specify a register \4 (not A, H, L or \3) to use for working.
; Clobbers A, H, L and \4.
; If ring is full, sets zero flag and does nothing. Otherwise unsets zero flag.
RingPush: MACRO
	ld HL, (\1) + ring_head
	ld A, [HL+]
	RepointStruct HL, ring_head + 1, ring_tail
	inc A
	and \2 ; A = (head+1) % (capacity+1)
	cp [HL] ; set z if head+1 == tail, ie. we're full
	jr z, .end\@
	ld \4, A ; store new head for safekeeping.
	RepointStruct HL, ring_tail, ring_head
	ld A, [HL] ; it would be faster to update head now, but this breaks interrupt-safety
	LongAddToA (\1)+ring_data, HL ; HL = \1 + ring_data + head index
	ld [HL], \3
	ld HL, (\1) + ring_head
	ld [HL], \4 ; update head
.end\@
ENDM

; Helper for pop macros. Args are (ring address, ring capacity, target reg)
; Pops into target reg assuming HL already points at tail index.
_RingPopHL: MACRO
	ld \3, [HL]
	ld HL, (\1) + ring_tail
	ld A, [HL]
	inc A
	and \2 ; A = (A+1) % (capacity+1)
	ld [HL], A
	ENDM

; Pop value into reg \3 (not A, H or L) from ring at immediate \1 of capacity \2.
; Clobbers A, H, L.
; Does NOT check if ring is empty! Behaviour in that case is undefined.
RingPopNoCheck: MACRO
	ld A, [(\1) + ring_tail]
	LongAddToA (\1)+ring_data, HL ; HL = \1 + ring_data + (value of ring_tail) = addr of ring_tail'th element of ring_data
	_RingPopHL \1, \2, \3
	ENDM

; Pop value into reg \3 (not A, H or L) from ring at immediate \1 of capacity \2 if possible.
; Otherwise (if ring is empty), sets zero flag and does not change \3.
; Clobbers A, H, L
RingPop: MACRO
	ld HL, (\1) + ring_head
	ld A, [HL+] ; A = head
	RepointStruct HL, ring_head + 1, ring_tail
	cp [HL] ; Set z if tail == head (no items)
	jr z, .end\@ ; if no items, finish with z flag set
	ld A, [HL+] ; A = tail
	RepointStruct HL, ring_tail + 1, ring_data
	LongAddToA HL, HL ; HL += tail index
	_RingPopHL \1, \2, \3
	or $ff ; unset z, which may be set
.end\@
	ENDM

ENDC
