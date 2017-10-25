
import struct

file = 'scheduler'

target = 'SchedEnqueueSleepTask'


def sleep_queue(next_wake_time, items):
	"""Generates a Memory representing a particular sleep queue.
	Each item should be a tuple (task, time)"""
	result = ''
	last_time = next_wake_time
	for task, time in items:
		result += struct.pack('<BH', task, time - last_time)
		last_time = time
	result += '\xff' # terminator
	return Memory(result)


def uptime(value):
	"""Generates a Memory() representing the given time value"""
	return Memory(struct.pack('<I', value))


init = Test('SchedInit',
	out_NextWake = Memory(255),
	out_SleepingTasks = sleep_queue(0, []),
)

# in most cases, we're interested in whether the runlist has been added to,
# so we default to an empty runlist
RunList = Memory(0, 0)

read_empty = Test('CheckNextWake',
	in_NextWake = Memory(255),
	out_NextWake = Memory(255),
	out_RunList = Memory(0, 0),
)

read_not_ready = Test('CheckNextWake',
	in_NextWake = Memory(10),
	in_NextWakeTime = uptime(0x100),
	in_Uptime = uptime(0xf8),
	out_NextWake = Memory(10),
	out_NextWakeTime = uptime(0x100),
	out_RunList = Memory(0, 0),
)

read_one = Test('CheckNextWake',
	in_NextWake = Memory(10),
	in_NextWakeTime = uptime(0xff),
	in_Uptime = uptime(0x100),
	in_SleepingTasks = sleep_queue(0xff, []),
	out_NextWake = Memory(255),
	out_RunList = Memory(1, 0, 10),
)

read_many = Test('CheckNextWake',
	in_NextWake = Memory(10),
	in_NextWakeTime = uptime(0xf0),
	in_Uptime = uptime(0x101),
	in_SleepingTasks = sleep_queue(0xf0, [(20, 0xf8), (4, 0xffff)]),
	out_NextWake = Memory(20),
	out_RunList = Memory(1, 0, 10),
	out_NextWakeTime = uptime(0xf8),
	out_SleepingTasks = sleep_queue(0xf8, [(4, 0xffff)]),
)
