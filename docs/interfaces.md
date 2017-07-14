
The following is a brief introduction to the various interfaces the OS gives you.

It contains mostly general comments on behaviour. Consult the in-line comments for
details of what registers are used, etc.

### In General

The term **task** is used to refer to a single thread.

New tasks may be started at any time.

All core OS functions that are safe to call from a task are prefixed `T_`.
Do not call the non-prefixed versions of these functions when they exist.
For example, you should use `T_TaskNewDynStack`, not `TaskNewDynStack`.

### Creating tasks

You can use `T_TaskNewWithStack` or `T_TaskNewDynStack` to create a new task.
The latter is reccomended in most cases, and will automatically allocate a reasonably-sized stack
from the dynamic memory allocator (see below).

You must provide an entry point (a 'main function') for the new task.

*WARNING: It is not valid to return from this main function - doing so will cause undefined behaviour*

Currently there is no way to destroy a task. Coming soon.

### Using RAM/ROM banks

You can use `T_SetROMBank` and `T_SetRAMBank` to switch what ROM or RAM bank your task has active.

This setting is per-task and each task can be switched into different banks and work at the same time.

### Locking and critical sections

Currently there is no general lock mechanism. To prevent race conditions, you instead have the
capability to 'lock' task switching, so only your task may run until you release the lock.

The functions for doing this are `T_DisableSwitch` to lock switching, and `T_EnableSwitch` to re-enable it.

You can use this to safely access shared data structures without fear of another thread
accessing them until you are done.

Remember to always re-enable switching, or else no other task will be able to run!

Be aware that most task-callable OS functions will re-enable switching on exit, and are not
safe to call inside a critical section.

### Scheduling

You can call `T_TaskYield` to stop your task and allow other tasks to run.
Note that this is not needed in most cases - all tasks are switched between periodically,
you don't need to call Yield to allow them to run at all. This call exists for performance-tweaking
mainly.

You can put a task to sleep for up to 65535 **ticks** of 2^-10s (1/1024th of a second, ~= 1 millisecond)
using `T_SchedSleepTask`. If you would rather think in 'frames', 1 graphics frame occurs approx every 16 ticks.

Once put to sleep, the task will not run again until at least the given time has elapsed.

If you wish to sleep for longer than 65535 ticks (64 seconds), it is reccomended you sleep in a loop.

### Dynamic Memory Allocation

You can call `T_DynMemAlloc` to attempt to reserve some amount of RAM memory for use by your task.

If successful, you will get back a memory address which is a pointer to the start of your
requested area.

There is currently no way to free memory or change the size of an allocation.

### Joypad Input

When the system detects any change in Joypad state, it will:

- Emit an event to the joypad event queue
- Update the HRAM variable `JoyState`. It is safe for a task to read from this variable at any time.

Both a joypad state event and the JoyState variable have the same format, a single byte where
each bit represents a button being currently pressed (`1`) or not (`0`).

Events can be consumed from the queue directly in one of two ways:

- `T_JoyTryGetEvent`, which will either get an event if any is available, or indicate failure
- `T_JoyGetEvent`, which will block the task until an event is available.

However, in most cases, a user doesn't care about every time any state changes - they only care
about when a *button press* occurs. For example, if the player is holding down A and presses B,
you want to know 'B was pressed', not 'both A and B are now held down'.

To facilitate this, we have the `T_JoyGetPress` function. It consumes the same joypad event queue,
but does some filtering and processing on it. You must give it the old joypad state to compare to
(when you first call it, `0` is fine), and it will block the thread until a button press occurs,
at which point it will return a byte with each bit indicating if the button just *became pressed*,
not whether it's currently being held. It's unlikely but possible for the player to press two buttons
at the exact same time, so more than one bit may be set - but in most cases, it won't be.

You should not use this feature to detect 'player pressed A+B'-style events, since the player would
need to press them perfectly together (within 1ms of each other). Instead, detect either press
and then confirm the other one is currently held using the returned state.

### Graphics

Currently, the only possible graphics action is to write a tile to the main background tilemap.
You cannot write to the alternate tilemap, or sprite ram. This will be fixed soon.

The standard ascii character set is available at their standard values - eg. the character 'A'
is tile number 65.

Any other tiles you may require should be added during compilation so they are loaded at OS start.

The OS makes no attempt to govern access to other graphics-affecting registers like ScrollX and ScrollY.
Any task may read or write to these values at any time. Beware of race conditions if two tasks may
access it at once.

#### Writing tiles to the tilemap

The `T_GraphicsWriteTile` function enqueues a tile value to be written to a specific index
of the tilemap. At the next vblank, this value will be written to the screen.

If the graphics queue gets full, `T_GraphicsWriteTile` will block the task until a space is available.
If this behaviour is undesirable, use `T_GraphicsTryWriteTile`, which may indicate failure if the queue
is full.
