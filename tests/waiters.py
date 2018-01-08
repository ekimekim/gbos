
file = 'waiters'


# Materialize macros and declare test waiter for use in testing
asm = """

include "longcalc.asm"
include "hram.asm"
include "waiter.asm"

SECTION "Test waiter", WRAM0[$c123]

TestWaiter:
	DeclareWRAMWaiter

SECTION "Test waiter materialized macros", ROM0

TestWaiterInit:
	WaiterInit TestWaiter
	ret

TestWaiterInitHL:
	ld HL, TestWaiter
	WaiterInitHL
	ret

TestWaiterWake:
	WaiterWake TestWaiter
	ret

TestWaiterWakeHL:
	ld HL, TestWaiter
	WaiterWakeHL
	ret
"""

TestWaiter = (0, 0xc123)

def testpair(target, **kwargs):
	return Test(target, **kwargs), Test(target + "HL", **kwargs)

def task(stack, waiter_det):
	return [stack >> 8, stack & 0xff, 0, 0, waiter_det >> 8, waiter_det & 0xff]

def tasks(*waiters):
	"""creates tasklist of tasks with given waiter value,
	either (bank, addr), None for no waiter, or (None, bank, addr) for no task in that slot,
	but set it as though bank and addr had been in that slot before it was wiped.
	"""
	result = []
	for w in waiters:
		if w is None:
			w = (0, 0xffff)
		stack = 0 if w[0] is None else 0xd000
		if w[0] is None:
			w = w[1:]
		bank, addr = w
		result += task(stack, determinant(bank, addr))
	return Memory(result)

def determinant(bank, addr):
	if addr == 0xffff: # sentinel
		return addr
	if (addr & 0xe000) >> 13 == 5: # sram
		return ((addr & 0x1fff) >> 2) | (bank << 11)
	if (addr & 0xe000) >> 13 == 6: # wram
		return ((addr & 0x0fff >> 1) | (bank << 11) | (1 << 15))
	if (addr & 0xff00) >> 8 == 0xff: # hram
		return 0xc000 | (addr & 0xff)
	raise ValueError("Bad waiter addr: {:04x}".format(addr))

init, initHL = testpair('TestWaiterInit',
	out_TestWaiter = Memory(0, 255),
)

def det_test(bank, addr):
	return Test('WaiterDeterminant',
		in_HL = addr,
		in_CurrentRAMBank = Memory(bank),
		out_HL = addr,
		out_DE = determinant(bank, addr),
	)
determinantSRAM = det_test(0, 0xb123)
determinantWRAM0 = det_test(0, 0xc001)
determinantWRAMX = det_test(5, 0xdead)
determinantHRAM = det_test(0, 0xffac)

wait_to_one = Test('WaiterWait',
	in_HL = 'TestWaiter',
	in_TestWaiter = Memory(0, 0xff),
	in_CurrentTask = Memory(6),
	in_TaskList = tasks(None, None),
	in_CurrentRAMBank = Memory(7), # to check that we don't look at it
	out_TestWaiter = Memory(1, 6),
	out_TaskList = tasks(None, TestWaiter),
)

wait_to_two = Test('WaiterWait',
	in_HL = 'TestWaiter',
	in_TestWaiter = Memory(1, 0),
	in_CurrentTask = Memory(6),
	in_TaskList = tasks(TestWaiter, None),
	out_TestWaiter = Memory(2, 0),
	out_TaskList = tasks(TestWaiter, TestWaiter),
)

# TODO test WaiterWake and WaiterWakeHL for zero and non-zero cases
# TODO test WaiterWake for hard non-zero cases
