
file = 'waiters'


# Materialize macros and declare test waiter for use in testing
asm = """

include "longcalc.asm"
include "hram.asm"
include "waiter.asm"

SECTION "Test waiter", WRAM0[$c123]

TestWaiter:
	DeclareWaiter

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

TestWaiter = 0xc123

def testpair(target, **kwargs):
	return Test(target, **kwargs), Test(target + "HL", **kwargs)

def task(stack, rambank, waiter):
	return [stack >> 8, stack & 0xff, 0, rambank, waiter >> 8, waiter & 0xff]

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
		result += task(stack, bank, addr)
	return Memory(result)

init, initHL = testpair('TestWaiterInit',
	out_TestWaiter = Memory(0, 255),
)

wait_to_one = Test('WaiterWait',
	in_HL = 'TestWaiter',
	in_TestWaiter = Memory(0, 0xff),
	in_CurrentTask = Memory(6),
	in_TaskList = tasks(None, (6, 0xffff)), # note different WRAMX bank is loaded,
	                                        # to check we don't look at it
	in_CurrentRAMBank = Memory(7), # to check that we don't look at it
	out_TestWaiter = Memory(1, 6),
	out_TaskList = tasks(None, (6, TestWaiter)),
)

wait_to_two = Test('WaiterWait',
	in_HL = 'TestWaiter',
	in_TestWaiter = Memory(1, 0),
	in_CurrentTask = Memory(6),
	in_TaskList = tasks((0, TestWaiter), None),
	out_TestWaiter = Memory(2, 0),
	out_TaskList = tasks((0, TestWaiter), (0, TestWaiter)),
)

# TODO test WaiterWake and WaiterWakeHL for zero and non-zero cases
# TODO test WaiterWake for hard non-zero cases
