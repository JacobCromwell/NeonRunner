extends RefCounted
## Generator rules for the Octodog (GDD §9.4) that patterns can't express. LevelGenerator runs
## apply() after the patterns for every level with the "octodog" feature.
##
## - Bait: a dog placed with the param "bait" is moved to stand `bait_distance` past the hole in its
##   lane just before it, so a head-on lunge falls in (GDD §9.4: the generator sometimes places
##   Octodogs near gaps; baiting one in is a skill bonus).
## - Charges: each dog gets its number of charges (2–3 early, up to 4 at the maximum, from
##   data/enemies/octodog.tres and the level's enemy_scaling) and the player distances where each
##   wind-up may start ("charge_at"). Each is at a stretch with no fence, anti-grav pad, other enemy,
##   or holes in more than one lane, so a charge never stacks with an unavoidable obstacle; and the
##   dog never runs under a ceiling section (GDD §3). Charges that don't fit are left out (it gives
##   up sooner).
## - One at a time: a dog whose first charge overlaps another dog's charges, or can't be made fair,
##   is dropped.

## A dog is dropped when fewer charges than this fit (GDD §9.4 asks for at least 2).
const MIN_CHARGES: int = 2
## Metres kept clear of other enemies after a charge's stretch.
const OTHER_ENEMY_MARGIN: float = 25.0


static func apply(gen: LevelGenerator) -> void:
	var t := EnemyDirector.tuning_for("octodog") as OctodogTuning
	if t == null:
		t = OctodogTuning.new()
	var layout: LevelLayout = gen.layout
	var scaling: float = gen.config.enemy_scaling
	var speed: float = gen.speed
	var rng: RandomNumberGenerator = gen.rng_for("octodog")
	var stop: float = t.stop_distance(speed, scaling)
	var window: float = t.window_length(speed, scaling)
	var cycle: float = t.cycle_distance(speed, scaling)
	var last_ok: float = layout.length - gen.config.end_clear_distance
	var busy_until: float = -INF
	var dropped: Array[Dictionary] = []
	var dogs: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e["type"]) == "octodog":
			dogs.append(e)
	dogs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	for e: Dictionary in dogs:
		var params: Dictionary = e.get("params", {})
		if bool(params.get("bait", false)):
			_align_to_bait_gap(layout, e, t)
		var at: float = float(e["at"])
		var lane: int = int(e["lane"])
		var a0: float = at - stop
		var fair: bool = a0 > busy_until + 10.0 and a0 > 0.0 \
			and not layout.gapped_between(lane, at - 1.5, at + 1.5) \
			and not Octodog.ceiling_between(layout, a0 - 6.0, at + 2.0) \
			and _window_ok(layout, a0, window, e)
		if not fair:
			dropped.append(e)
			continue
		var r: Vector2i = t.charges_range(scaling)
		var wanted: int = rng.randi_range(r.x, r.y)
		var anchors: Array[float] = [a0]
		var prev: float = a0
		while anchors.size() < wanted:
			var found: float = -1.0
			var a: float = prev + cycle
			while a <= prev + cycle + t.charge_slack:
				if a + window > last_ok or Octodog.ceiling_between(layout, prev, a + stop + 2.0):
					break
				if _window_ok(layout, a, window, e):
					found = a
					break
				a += 2.0
			if found < 0.0:
				break
			anchors.append(found)
			prev = found
		if anchors.size() < mini(MIN_CHARGES, wanted):
			dropped.append(e)
			continue
		params["charges"] = anchors.size()
		params["charge_at"] = anchors
		e["params"] = params
		busy_until = anchors[-1] + window + stop
	for e: Dictionary in dropped:
		layout.enemies.erase(e)


## True if the player's stretch [a, a + window] has no fence, ceiling, pad, holes in two or more
## lanes, and no other enemy nearby.
static func _window_ok(layout: LevelLayout, a: float, window: float, dog: Dictionary) -> bool:
	if not Octodog.window_clear(layout, a, a + window):
		return false
	for other: Dictionary in layout.enemies:
		if other == dog:
			continue
		var d: float = float(other["at"])
		if String(other["type"]) != "octodog" and d >= a - 5.0 and d <= a + window + OTHER_ENEMY_MARGIN:
			return false
	return true


## Moves a bait dog to stand `bait_distance` past the far edge of the hole just before it in its lane.
static func _align_to_bait_gap(layout: LevelLayout, dog: Dictionary, t: OctodogTuning) -> void:
	var lane: int = int(dog["lane"])
	var at: float = float(dog["at"])
	var best: Dictionary = {}
	for g: Dictionary in layout.gaps:
		if int(g["lane"]) != lane or float(g["end"]) > at + 1.0 or float(g["end"]) < at - 25.0:
			continue
		if best.is_empty() or float(g["end"]) > float(best["end"]):
			best = g
	if not best.is_empty():
		dog["at"] = float(best["end"]) + t.bait_distance
