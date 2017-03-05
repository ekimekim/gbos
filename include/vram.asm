
; Tile map is a array 0 to 255 of 16-byte tile images from $8000-$8fff
; Alt tile map is a array -128 to 127 from $8800-$97ff (0 is at $9000)
; You can switch whether the background map uses TileMap or AltTileMap using LCDC register
; Here we define the base, the overlapping region, and the start of the non-overlapping alt part
BaseTileMap EQU $8000
OverlapTileMap EQU $8800
AltTileMap EQU $9000
; Tile data is 32x32 grid of tile numbers from $9800-$9bff
; Background and Window are windows into this area
TileGrid EQU $9800
; You can switch between which TileGrid is used by background or window using LCDC register
AltTileGrid EQU $9c00

SpriteTable EQU $fe00
