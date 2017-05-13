include "longcalc.asm"
include "hram.asm"
include "constants.asm"

; DynMem is organized into chunks. Each chunk consists of a length,
; an owner and a data range. A chunk can be between 2 and 256 bytes.
; Length is of the whole structure, not just the usable data.
RSRESET
; Chunk length including header. Special cases: 0 means 256 (254 bytes of data),
; 1 is a sentinel value meaning end-of-DynMem-range.
chunk_len rb 1
; Owner task_id, or 255 to indicate no owner.
chunk_owner rb 1
; Data itself, variable length
chunk_data rb 0


section "General Dynamic Memory Range", WRAM0

; This dynamic memory section is for general task use,
; even in tasks that also have their own dedicated RAM bank
GeneralDynMem::
	ds GENERAL_DYN_MEM_SIZE * 256


section "Dynamic Memory Management Routines", ROM0

; All functions here operate on a given DynMem range.


; Initialize DynMem range starting at HL with length B * 256 (min 1).
; Clobbers A, B, HL
DynMemInit::
	ld A, $ff
	dec B
	jp z, .last
.loop
	inc A ; A = 0
	ld [HL+], A ; chunk_len = 0 -> length 256, HL points to chunk_owner
	dec A ; A = $ff again
	ld [HL-], A ; owner = $ff (unowned), HL points to chunk_len
	inc H ; HL += 256, putting us at the start of the next chunk
	dec B
	jp nz, .loop
.last
	; last 256 needs to reserve a byte for the sentinel
	ld [HL+], A ; chunk_len = $ff -> length 255, HL points to chunk_owner
	ld [HL-], A ; owner = $ff (unowned), HL points to chunk_len
	inc H
	dec HL ; HL += 255
	inc B ; B was 0, so B = 1
	ld [HL], B ; chunk_len = 1 -> length 0 -> sentinel value, final byte of range
	ret


; Find and allocate a memory chunk of B length (that's B usable data, max 254)
; from DynMem range starting at HL. Returns newly allocated memory in HL, or $0000 on failure.
; Allocation is registered to task with task id D.
; Clobbers all but DE.
DynMemAlloc::
	; Simple allocation algorithm - first fit.
	inc B ; B = desired chunk length - 1, usable data + 1
	jp .start
.loop
	; A = chunk length - 1, HL points at chunk_owner
	ld C, A ; for safekeeping
	cp B ; set carry if A - B < 0, ie. A < B
	ld A, [HL] ; A = owner
	jp c, .nomatch ; jump if A < B
	cp $ff ; set z if chunk is unused
	jp nz, .nomatch
	; This allocation is good! Slice it off if we can and return it.
	ld A, D ; A = new owner id
	ld [HL-], A ; Set chunk as owned, point HL at chunk length
	ld A, C ; A = chunk length - 1
	sub B ; A = excess bytes in allocation
	ld C, A ; for safekeeping
	cp 3 ; set carry if A < 3
	jp c, .nosplit ; if we have < 3 bytes of excess, can't split since result wouldn't fit chunk header
	push HL ; push chunk start addr for safekeeping
	ld A, B
	inc A ; A = desired chunk length
	ld [HL+], A ; set this chunk's length to the desired length, set HL to this chunk + 1
	LongAdd H,L, 0,B, H,L ; HL += B, HL = chunk + 1, B = chunk length - 1, so HL + B = next chunk
	ld [HL], C ; C = excess bytes = length of new chunk
	inc HL
	ld A, $ff
	ld [HL], A ; set owner of new chunk to no-one
	pop HL ; restore HL = allocated chunk's addr
.nosplit
	; HL = allocated chunk header start
	RepointStruct HL, chunk_len, chunk_data ; point at data
	ret
.nomatch
	; C = chunk length - 1, HL points at chunk_owner = chunk start + 1, so HL + C = next chunk
	LongAdd H,L, 0,C, H,L ; HL += C
.start
	ld A, [HL+] ; A = chunk length, HL points at chunk_owner
	dec A ; A = chunk length - 1, set Z if A = 1 (end of range), wraps to 255 if A = 0 (ie. 256)
	jp nz, .loop
	; Couldn't find a suitable allocation
	ld HL, $00
	ret


; Task-callable version of DynMemAlloc.
; Can only allocate memory to yourself, not other tasks.
; Clobbers all but E.
T_DynMemAlloc::
	call T_DisableSwitch
	ld A, [CurrentTask]
	ld D, A
	call DynMemAlloc
	jp T_EnableSwitch
