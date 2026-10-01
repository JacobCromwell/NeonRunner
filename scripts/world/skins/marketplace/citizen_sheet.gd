class_name CitizenSheet
extends RefCounted
## The Marketplace citizens' flipbook layout (task D3): both the offline baking tool
## (tools/asset_gen/citizen_sheet_gen.gd) and the runtime card (MarketCitizen) read these constants,
## so a sheet baked today still lines up with a card built tomorrow. A fixed COLS x ROWS grid, one
## row per CitizenRig.Clip in that enum's order (idle, startled, cheer); every row uses the same
## column count so the UV math never needs a per-row frame count.

const COLS: int = 8
const ROWS: int = 3
## One cell's pixel size: tall and narrow, like a person seen through a shop window.
const CELL := Vector2i(96, 176)
## Playback speed (frames per second) per clip (CitizenRig.Clip): fast enough to read as a gesture,
## slow enough that it never flickers (Settings > Reduced flashing: this is a slow flipbook, never a
## strobe, on every setting).
const FPS: Dictionary = {
	0: 5.0,  ## CitizenRig.Clip.IDLE
	1: 9.0,  ## CitizenRig.Clip.STARTLED
	2: 7.0,  ## CitizenRig.Clip.CHEER
}


## Where the baked sheet for one archetype lives (assets/sprites/citizens/, regenerable:
## assets/LICENSES.md).
static func texture_path(archetype_name: String) -> String:
	return "res://assets/sprites/citizens/%s.png" % archetype_name
