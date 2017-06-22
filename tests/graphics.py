
file = 'graphics'

asm = """
; Functions being tested may enable VBlank interrupt, ensure it safely does nothing
SECTION "graphics test vblank", ROM0[$40]
	reti
"""

init = Test('GraphicsInit',
	out_TileQueueInfo = Memory([0] * 8),
)


write_tile_from_empty = Test('GraphicsTryWriteTile',
	in_TileQueueInfo = Memory([0] * 8), # initially empty
	in_DE = 0x0020,
	in_C = 42, # write 42 to position 0x20 in first section
	out_A = 0, # success
	out_TileQueueInfo = Memory(1, 2), # first queue has one entry
	out_TileQueues = Memory(0x20, 42), # first item is 'write 42 to 0x20'
	out_InterruptsEnabled = Memory(1), # vblank int enabled
)

write_tile_not_empty = Test('GraphicsTryWriteTile',
	in_TileQueueInfo = Memory([None]*4, 5, 16), # 3rd queue is at head 16 with 5 items
	in_DE = 0x02ab,
	in_C = 0xcd, # write 0xcd to position 0xab in 3rd section
	out_A = 0, # success
	out_TileQueueInfo = Memory([None]*4, 6, 18), # 3rd queue is at head 18 with 6 items
	out_TileQueues = Memory([None]*256*2, [None]*16, 0xab, 0xcd), # pos 15 in 3rd queue is 'write 0xcd to 0xab'
)

write_tile_full = Test('GraphicsTryWriteTile',
	in_TileQueueInfo = Memory(128, 0), # length = 128, ie. full
	in_DE = 0x0000,
	out_A = 128, # with current impl, failure value = length = 128
	out_TileQueueInfo = Memory(128, 0), # unchanged
	out_InterruptsEnabled = Memory(0), # vblank remains disabled
)


VBLANK_INITIAL_CREDITS = 60

writes = [(x, x+10) for x in range(60, 80)] # pos, value to set range 60-80 to values 70-90 in order
random.shuffle(writes)
writes = sum(map(list, writes), []) # flatten
vblank_small = Test('GraphicsVBlank',
	in_TileQueueInfo = Memory(0, 0, 20, 40, [0]*4), # 2nd queue has 20 items with head 40
	in_TileQueues = Memory([None]*256, writes),
	in_InterruptsEnabled = Memory(1),
	out_TileQueueInfo = Memory(0, 0, 0, 40, [0]*4),
	out_TileGrid = Memory([None]*256, [None]*60, range(70, 90)), # check values were written
	out_InterruptsEnabled = Memory(0), # vblank was disabled
)

vblank_large = Test('GraphicsVBlank',
	in_TileQueueInfo = Memory([128, 0]*4), # completely full
	in_InterruptsEnabled = Memory(1),
	out_TileQueueInfo = Memory(128 - VBLANK_INITIAL_CREDITS, 0, [128, 0]*3),
	out_InterruptsEnabled = Memory(1), # vblank remains enabled
)
