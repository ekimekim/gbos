
file = 'waiters'


# Materialize macros and declare test waiter for use in testing
asm = """

include "longcalc.asm"
include "hram.asm"
include "waiter.asm"

SECTION "Test waiter", WRAM0[$c123]

TestWaiter:
	DeclareWaiter

SECTION "Test ISW", WRAM0[$c223]

TestISW:
	DeclareIntSafeWaiter

SECTION "Test WRAMX Waiter", WRAMX[$d000], BANK[1]

TestWRAMXWaiter:
	DeclareWaiter

SECTION "Test waiter materialized macros", ROM0

TestWaiterInit:
	WaiterInit TestWaiter
	ret

TestWaiterInitHL:
	ld HL, TestWaiter
	WaiterInitHL
	ret

TestIntSafeWaiterInit:
	IntSafeWaiterInit TestISW
	ret

TestWaiterWake:
	WaiterWake TestWaiter
	ret

TestWaiterWakeHL:
	ld HL, TestWaiter
	WaiterWakeHL
	ret

TestWRAMXWaiterWake:
	WaiterWake TestWRAMXWaiter
	ret

TestIntSafeWaiterWake:
	IntSafeWaiterWake TestISW
	ret

TestIntSafeWaiterCheckOrWait:
	IntSafeWaiterCheckOrWait TestISW, TestISW_Checker
	ret

TestISW_Checker:
	; Set c if A < B
	cp B
	ret
"""

TestWaiter = 0xc123
TestISW = 0xc223
TestWRAMXWaiter = 0xd000
TestWRAMXBank = 1
TASK_SIZE = 6
MAX_TASKS = 31
TASK_IDS = range(0, (MAX_TASKS + 1) * TASK_SIZE, TASK_SIZE)

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
			w = (None, 0xffff)
		if len(w) == 3:
			stack = 0
			bank, addr = w[1:]
		else:
			stack = 0xd000
			bank, addr = w
		result += task(stack, bank, addr)
	return Memory(result)

def runlist(*task_ids):
	return Memory(len(task_ids), 0, task_ids)

init, initHL = testpair('TestWaiterInit',
	out_TestWaiter = Memory(0, 255),
)

initISW = Test('TestIntSafeWaiterInit',
	out_TestISW = Memory(0, 0, 255),
)

wait_to_one = Test('WaiterWait',
	in_HL = 'TestWaiter',
	in_TestWaiter = Memory(0, 0xff),
	in_CurrentTask = Memory(TASK_IDS[1]),
	in_TaskList = tasks(None, (6, 0xffff)), # note different WRAMX bank is loaded,
	                                        # to check we don't look at it
	in_CurrentRAMBank = Memory(7), # to check that we don't look at it
	out_TestWaiter = Memory(1, TASK_IDS[1]),
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

# basic tests to cover HL and immediate versions
wake_none, wake_none_HL = testpair('TestWaiterWake',
	in_TestWaiter = Memory(0, 255),
	in_RunList = runlist(),
	out_TestWaiter = Memory(0, 255),
	out_RunList = runlist(),
)

wake_one, wake_one_HL = testpair('TestWaiterWake',
	in_TestWaiter = Memory(1, TASK_IDS[0]),
	in_RunList = runlist(),
	in_TaskList = tasks((0, TestWaiter)),
	out_TestWaiter = Memory(0, 255),
	out_RunList = runlist(TASK_IDS[0]),
	out_TaskList = tasks(None),
)

def wake_test(count, min_id, tasks_in, tasks_out, runlist_out):
	return Test('TestWaiterWake',
		in_TestWaiter = Memory(count, min_id),
		in_RunList = runlist(),
		in_TaskList = tasks(*tasks_in),
		out_TestWaiter = Memory(0, 255),
		out_RunList = runlist(*runlist_out),
		out_TaskList = tasks(*tasks_out),
	)

wake_not_first = wake_test(
	1, TASK_IDS[2],
	[None, None, (0, TestWaiter)],
	[None, None, None],
	[TASK_IDS[2]],
)

wake_many = wake_test(
	3, TASK_IDS[0],
	[(0, TestWaiter), (0, TestWaiter), None, (0, TestWaiter)],
	[None] * 4,
	[TASK_IDS[0], TASK_IDS[1], TASK_IDS[3]],
)

wake_with_dead_entries = wake_test(
	2, TASK_IDS[1],
	[None, (None, 0, TestWaiter), (0, TestWaiter)] + [None]*(MAX_TASKS-3),
	[None, (None, 0, TestWaiter)] + [None]*(MAX_TASKS-2),
	[TASK_IDS[2]],
)

wake_wramx = wake_test(
	2, TASK_IDS[0],
	[(TestWRAMXBank, TestWRAMXWaiter), (TestWRAMXBank+1, TestWRAMXWaiter)],
	[None, (TestWRAMXBank+1, TestWRAMXWaiter)],
	[TASK_IDS[0]],
)

# TODO test ISW wait and wake cases
