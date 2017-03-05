
; "P1" Joypad input/output. Bits 6 and 7 are unused (count low to high, so bit 7 is 128)
; Bits 4 and 5 are written to to "select" one of two lines.
; When bit 4 is set to 0, the bits 0-3 are: Right, Left, Up, Down
; When bit 5 is set to 0, the bits 0-3 are: A, B, Select, Start
; It takes "a few cycles" between setting the bits and getting results.
; Result bits are 0 if the button is pressed, else 1
JoyIO EQU $ff00
JoySelectDPad EQU $20
JoySelectButtons EQU $10

; "SB" Serial transfer data
SerialData EQU $ff01
; "SC" Serial control
SerialControl EQU $ff02

; "DIV" fixed timer register. Incremented every ~610us (2^14 Hz)
; Write any value to set it to 0
DivTimer EQU $ff04

; "TIMA" Timer counter register. Incremented at a variable frequency (see TAC)
; When it overflows (increments from $ff), a Timer interrupt fires.
; After overflowing, its value is set to the value at TimerModulo.
; Can be set manually.
TimerCounter EQU $ff05
; "TMA" Timer modulo register. When TimerCounter overflows, it sets set to this value.
; By setting this value, you can fine tune the timer counter overflow frequency.
TimerModulo EQU $ff06
; "TAC" Timer control register. Set this to control the timer.
; Bits 3-7 are unused. Bit 2 enables the timer when set, disables it when unset.
; Bits 0-1 are a 2-bit number where the values 0-3 mean timer frequencies
; 2^12 Hz, 2^18 Hz, 2^16 Hz and 2^14 Hz respectively.
TimerControl EQU $ff07

; "IF" Interrupt flag register. The hardware will set a bit in this register when an interrupt
; would be generated, even if interrupts are currently disabled. Bits respectively (from 0 to 5) refer to
; VBlank, LCDC, Timer, Serial and Joystick interrupts.
InterruptFlags EQU $ff0f

; $ff10 - $ff3f are sound registers, which I'm not gonna touch.
; Except for this one: Sound control. Sets individual channels on or off for bits 0-3,
; sets all sound on/off for bit 7. You should set this to 0 on start to disable sound.
SoundControl EQU $ff26

; "LCDC" LCD control register. Defaults to $91. Write to these bits to control the display mode:
; 0: Background and Window display off/on
; 1: Sprite display off/on
; 2: Sprite size (width x height): 8x8 if unset, 8x16 if set
; 3: Background Tile grid region select: 0 for TileGrid, 1 for AltTileGrid
; 4: Background and Window tile map mode select: 0 for signed, 1 for unsigned.
;    Note Sprites always use unsigned.
; 5: Window display off/on
; 6: Window Tile grid region select: 0 for TileGrid, 1 for AltTileGrid
; 7: Global display enable/disable: 0 to turn off screen, 1 to turn on
; Default value $91 = %10010001 = enabled display, signed tile map, background only
LCDControl EQU $ff40

; "STAT" LCD Status register. Its value changes as the LCD goes through draw cycles.
; It has 4 "modes". The current mode is indicated by the bits 0-1 as a 2 bit mode value:
; 00: During H-Blank
; 01: During V-Blank
; 10: While searching sprite ram. The CPU cannot access the sprite ram during this mode.
; 11: While transferring data. The CPU cannot access sprite ram or vram during this mode.
; You can also write to bits 2-6 to set the conditions under which a LCDC Interrupt should occur:
; bit 3: When mode becomes H-Blank
; bit 4: When mode becomes V-Blank (how is this different from vblank interrupt?)
; bit 5: When mode becomes Sprite search
; bit 6: When the LY register reaches a certain condition according to bit 2:
;        When bit 2 is 0: Trigger when LY != LYC
;        When bit 2 is 1: Trigger when LY == LYC
LCDStatus EQU $ff41

; "SCY" Scroll Y register. Controls scroll position of the background.
ScrollY EQU $ff42
; "SCX" Scroll X register. Controls scroll position of the background.
ScrollX EQU $ff43

; "LY" LCD Y-coordinate register. Contains the current y-coordinate that the screen
; is drawing. Contains values 0-143 while drawing, 144-153 during VBlank.
; Writing to this register will set it to 0.
; You should probably just never touch this unless you're doing something funky.
LCDYCoordiate EQU $ff44
; "LYC" LCD Y-coordinate comparison register. Is used when deciding whether to trigger an interrupt,
; see STAT register.
LCDYCompare EQU $ff45

; "DMA" Direct Memory Access Transfer control register.
; DMA transfer allows you to rapidly copy data from elsewhere in memory ($0000-$f19f) to the sprite memory
; area ($fe00-$fe9f). While this is happening, only high ram ($ff80-$fffe) can be used.
; DMA transfer is initiated by writing the upper byte of the start source address to this register.
; eg. to start the transfer from address $1200, you would write $12.
; The DMA will complete 448 cycles later, best calculated as 28 loops of {dec a; jr nz}
DMATransfer EQU $ff46

; "BGP" Background and Window palette data
TileGridPalette EQU $ff47
; "OBP0", "OBP1" Sprite data palettes
SpritePaletteTransparent EQU $ff48
SpritePaletteSolid EQU $ff49

; "WY", "WX" Window X and Y position.
; The window overwrites the background on the display, unlike sprites which are transparent.
; The actual on-screen coordinates of the window's top left are (WX-7, WY).
; If X or Y is set greater than 166 or 143 respectively, window will not show.
WindowY EQU $ff4a
WindowX EQU $ff4b

; "IE" Interrupt Enable flags. Write to this register to selectively disable interrupts.
; Bits 0-4 control off/on for respectively: VBlank, LCDC, Timer, Serial, Joypad
InterruptsEnabled EQU $ffff
