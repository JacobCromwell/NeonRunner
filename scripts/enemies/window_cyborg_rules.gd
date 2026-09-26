extends RefCounted
## Generator rules for window cyborgs (GDD §9.2), run for levels with the `window_cyborg` feature:
## drops a window cyborg whose window would overlap a sign on the same wall. A sign there would
## cover the window and block wall entry right at it, so "wall-entry timing decides whether you pass
## above or below" wouldn't hold.

const TUNING_PATH: String = "res://data/enemies/window_cyborg.tres"
## Extra room kept between a window and a sign along the track.
const SIGN_CLEARANCE: float = 1.5


static func apply(gen: LevelGenerator) -> void:
	var tuning := load(TUNING_PATH) as WindowCyborgTuning
	if tuning == null:
		tuning = WindowCyborgTuning.new()
	var half: float = tuning.window_length * 0.5 + SIGN_CLEARANCE
	var kept: Array[Dictionary] = []
	for e: Dictionary in gen.layout.enemies:
		if String(e.get("type", "")) == "window_cyborg" and _sign_near(gen.layout, int(e["side"]), float(e["at"]), half):
			continue
		kept.append(e)
	gen.layout.enemies = kept


static func _sign_near(layout: LevelLayout, side: int, d: float, margin: float) -> bool:
	for s: Dictionary in layout.signs:
		if int(s["side"]) == side and d >= float(s["start"]) - margin and d <= float(s["end"]) + margin:
			return true
	return false
