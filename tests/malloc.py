
file = 'malloc'
target = 'DynMemAlloc'

# some references to other funcs
files = ['tasks', 'scheduler', 'main', 'graphics']

GENERAL_DYN_MEM_SIZE = 4

# this is the initial state assuming all uninitialized mem is set to 42
GeneralDynMem = Memory(
	([0, 255] + [42]*254) * (GENERAL_DYN_MEM_SIZE-1),
	255, 255, [42]*253, [1],
)

init = Test('DynMemInit',
	in_HL = 'GeneralDynMem',
	in_B = 4,
	in_GeneralDynMem = Memory([42] * 1024),
	out_GeneralDynMem = GeneralDynMem,
)

basic = Test(
	in_HL = 'GeneralDynMem',
	in_B = 64,
	in_D = 16,
	out_HL = 'GeneralDynMem + 2',
	out_GeneralDynMem = Memory(66, 16, [42]*64, 256-66, 255),
)

no_split = Test(
	in_HL = 'GeneralDynMem',
	in_B = 252,
	in_D = 0,
	out_HL = 'GeneralDynMem + 2',
	out_GeneralDynMem = Memory(0, 0, [42]*254, 0, 255),
)

first_no_fit = Test(
	in_HL = 'GeneralDynMem',
	in_B = 16,
	in_D = 40,
	in_GeneralDynMem = Memory(16, 255, [42]*14, 18, 255, [42]*16, 256-16-18, 255),
	out_HL = 'GeneralDynMem + 16 + 2',
	out_GeneralDynMem = Memory(16, 255, [42]*14, 18, 40),
)

first_taken = Test(
	in_HL = 'GeneralDynMem',
	in_B = 1,
	in_D = 40,
	in_GeneralDynMem = Memory(0, 0, [42]*254),
	out_HL = 'GeneralDynMem + 256 + 2',
	out_GeneralDynMem = Memory(0, 0, [42]*254, 3, 40),
)

# first one is too small, second is taken, then we hit sentinel
_full_mem = Memory(128, 255, [42]*126, 240, 32, [42]*238, 1)
alloc_failure = Test(
	in_HL = 'GeneralDynMem',
	in_B = 200,
	in_D = 40,
	in_GeneralDynMem = _full_mem,
	out_HL = 0,
	out_GeneralDynMem = _full_mem,
)
