"""Example test to test the testing framework"""

# Normally you'd specify a top-level directory .asm file to 'include'.
# This file should contain the target function. We 'include' it rather than linking it
# so the test can potentially access unexported ('private') labels.
# You can say None, but it's a weird case.
file = None

# What top-level directory .asm files to link with. Default is all top-level *.asm files
# excepting the target file, since they tend to be very cross-dependent.
# It also excludes 'header.asm' as this special-case file contains specific things like
# interrupt handlers and the start address, which conflict with the test harness.
# However, you can also set it to any explicit list or the empty list as shown here.
files = []

# function to test
target = 'TestCode'

# extra asm to add as a helper (should be rare)
asm = """
SECTION "Test Mem", WRAM0

TestMem:
	ds 5

SECTION "Test code", ROM0

; Basic function to test. Should output HL = $face, B = input B + 1,
; A = TestMem[0] + TestMem[1], TestMem[3] = TestMem[0] - TestMem[1],
; and set z iff A == TestMem[2]
TestCode:
	ld HL, $face
	inc B
	ld A, [TestMem+2]
	ld D, A
	ld A, [TestMem+1]
	ld C, A
	ld A, [TestMem]
	sub C
	ld [TestMem+3], A
	ld A, [TestMem]
	add C
	cp D
	ret
"""

# anything of type Memory is set as a default initial value for that label in memory
TestMem = Memory(5, 2, 7)

# Create a test and assign it to a name
basic = Test(
	# in_REG sets initial register states
	in_B = 42,
	# out_REG checks register states after call
	out_A = 7,
	out_HL = 0xface,
	out_B = 43,
	# in/out also works for z, c flags
	out_zflag = True,
	# out_LABEL checks contents of memory LABEL after call (as long as type is Memory)
	out_TestMem = Memory(5, 2, 7, 3),
)

no_match = Test(
	# We're leaving a lot of things unspecified here since they're tested by basic.
	# Note the in_LABEL here overrides the overlapping part of the outer TestMem definition
	in_TestMem = Memory(6),
	out_zflag = False,
)

this_fails = Test(
	out_HL = 0xcefa
)

# The 'random' global is an RNG seeded with the test suite name, and should be used
# for any 'random' values you wish to generate. This keeps the tests consistent.
b = random.randrange(256)
testmem = [random.randrange(256) for _ in range(4)]
rand_test = Test(
	in_B = b,
	in_TestMem = Memory(testmem),
	out_B = (b+1) % 256,
	out_A = (testmem[0] + testmem[1]) % 256,
	out_TestMem = Memory(testmem[:3], (testmem[0] - testmem[1]) % 256),
	out_zflag = (testmem[0] + testmem[1]) % 256 == testmem[2],
)

# You can leave 'gaps' in a memory spec which remain unspecified using None
mem_none = Test(
	in_TestMem = Memory(None, 1, 2, 3, 4),
	out_TestMem = Memory(None, 1, 2, None, 4),
)

# You can specify arbitrary asm to run before setup or immediately after the call.
# Note any registers set by pre_asm may be clobbered before the call.
# Note any post_asm runs before checkout out_* values and must be careful to preserve them.
# Asm can be string or list of lines.
pre_and_post_asm = Test(
	pre_asm = "ld B, 10",
	post_asm = ["ld A, B", "add A"],
	out_A = 22,
	out_B = 11,
)

# Currently no way to specify input/output stack, but it wouldn't be much of a change.
