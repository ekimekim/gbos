IF !DEF(_G_VRAM)
_G_VRAM EQU "true"


; Tile map is a array 0 to 255 of 16-byte tile images from $8000-$8fff
; Alt tile map is a array -128 to 127 from $8800-$97ff (0 is at $9000)
; You can switch whether the background map uses TileMap or AltTileMap using LCDC register
; On GBC, there is a second bank which can hold an alternate set of both sets of tiles.
; Here we define the base, the overlapping region, and the start of the non-overlapping alt part
BaseTileMap EQU $8000
OverlapTileMap EQU $8800
AltTileMap EQU $9000

; Tile data is 32x32 grid of tile numbers from $9800-$9bff
; Background and Window are windows into this area.
TileGrid EQU $9800
; You can switch between which TileGrid is used by background or window using LCDC register
AltTileGrid EQU $9c00
; On CGB, accessing these maps in Bank 1 lets you specify a byte of flags for each tile:
; bit 0-2: Selects background palette number
; bit 3: Selects tile map bank. 0 = Bank 0, 1 = Bank 1.
; bit 5: Flip horizontally
; bit 6: Flip vertically
; bit 7: Priority. When 1, BG tile will draw over all sprites,
;        when 0 it defers to the sprite's prio value. But note the LCDControl register can
;        force sprites to always have priority over all tiles instead.

; The sprite table contains 40 sprites. Each sprite is 4 bytes:
; Y: Y coordinate - 16. Set Y=0 or Y > 160 to hide it offscreen.
; X: X coordinate - 8. You should not set X = 0 to hide the sprite as it still counts
;    to the 10 sprites/row limit.
; tile: The tile number in the tilemap. Note that if 8x16 sprites are in use, bottom bit is ignored,
;       ie. the top tile must be even and the bottom one must be odd.
; flags:
;   bit 7: Priority. If background (or window) has priority,
;          background color 0 is transparent (still visible behind sprite color 0) but 1-3 overrides
;          sprite. Otherwise, the background is only seen behind sprite color 0.
;   bit 6: Flip vertically
;   bit 5: Flip horizontally
;   bit 4 (non-CGB): palette number (0 or 1)
;   bit 3 (CGB): Selects tile map bank. 0 = Bank 0, 1 = Bank 1
;   bit 0-2 (CGB): Palette number (0-7) from sprite palettes
; Note that in non-CGB, sprites with lower X coord draw on top of other sprites,
; with ties split by lowest sprite table index. In CGB mode, lower-index sprites are always on top.
; This priority ordering also applies to the 10 sprites/row limit.
SpriteTable EQU $fe00

ENDC
