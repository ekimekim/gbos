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
	LongAdd 0,[(\1) + ring_head], (((\1)+ring_data) >> 8),(((\1)+ring_data) & $ff), H,L ; HL = \1 + ring_data + (value of ring_head) = addr of ring_head'th element of ring_data
	ld [HL], \3
	ld A, [(\1) + ring_head]
	inc A
	and \2 ; A = (A+1) % (capacity+1)
	ld [(\1) + ring_head], A
	ENDM

; Pop value into reg \3 (not A, H or L) from ring at immediate \1 of capacity \2.
; Clobbers A, H, L.
; Does NOT check if ring is empty! Behaviour in that case is undefined.
RingPopNoCheck: MACRO
	LongAdd 0,[(\1) + ring_tail], (((\1)+ring_data) >> 8),(((\1)+ring_data) & $ff), H,L ; HL = \1 + ring_data + (value of ring_tail) = addr of ring_tail'th element of ring_data
	ld \3, [HL]
	ld A, [(\1) + ring_tail]
	inc A
	and \2 ; A = (A+1) % (capacity+1)
	ld [(\1) + ring_tail], A
	ENDM
