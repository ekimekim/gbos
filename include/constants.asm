; Size of the core stack, used in brief periods between when tasks run
CORE_STACK_SIZE EQU 64

; Size of task stacks allocated via the standard dyanamic stack allocation process
DYN_MEM_STACK_SIZE EQU 64

; Amount of 256-byte lots to allocate to GeneralDynMem
GENERAL_DYN_MEM_SIZE EQU 4 ; 1024 bytes

; Amount of 2^-10sec units to let a task run before switching for another.
SWITCH_TIME_INTERVAL EQU 8 ; approx 8ms
