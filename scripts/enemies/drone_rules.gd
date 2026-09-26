extends RefCounted
## Generator rules for the heli drone (GDD §9.6). LevelGenerator runs apply() after the patterns for
## levels with the `drone` feature. Numbers come from DroneTuning (data/enemies/drone.tres).
## - No drone appears in the last ~15 s of a level (no_spawn_last_seconds), nor so late that its
##   first pad wouldn't fit before the finish.
## - Drones placed at the same spot form a wave; a level's first wave is a single drone, and a
##   second drone joins later waves only from pair_min_scaling on (DESIGN-TBD).
## - The first anti-grav pad comes at least
##   first_pad_seconds (10 s) after a wave appears; after each pad another follows 8–10 s later
##   (pad_repeat_*), until the level ends. The schedule is pre-placed: the generator can't know when
##   the player destroys the drone, and pads left after it dies are just ordinary ceilings.
## - From the first wave on these rules own every pad (any pad hurls the drones, so a pattern's pad
##   inside the 10 s would break the rule): pattern ceilings after the first wave give way to the
##   schedule. A later wave arrives at one of the scheduled pads, as the player steps on it (it isn't
##   on screen yet, so that pad doesn't hurl it), so its own 10 s and the earlier drone's 8–10 s both
##   hold. DESIGN-TBD: waves come at least min_wave_gap_seconds apart; closer ones are dropped.
## - GDD §3: the floor under each scheduled ceiling is cleared (no gaps, fences or floor enemies
##   under it, and the landing after it stays clear), and its pad avoids a hover truck's lane.
## - Pads need ceilings: a level with drones but without the `ceilings` feature gets a warning and no
##   pad schedule.

const TYPE: String = "drone"
## Scheduled pads are placed like every rule's guaranteed pad (shared with host_rules.gd).
const PadPlacement = preload("res://scripts/enemies/pad_placement.gd")


static func apply(gen: LevelGenerator) -> void:
	var t: DroneTuning = tuning()
	var layout: LevelLayout = gen.layout
	var speed: float = gen.speed
	var drones: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == TYPE:
			drones.append(e)
	drones.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	var has_ceilings: bool = gen.config.has_feature("ceilings")
	var last_pad: float = last_pad_at(gen, t)
	var latest: float = layout.length - t.no_spawn_last_seconds * speed
	if has_ceilings:
		latest = minf(latest, last_pad - t.first_pad_seconds * speed)
	if t.guarantee_one_wave:
		var kept_any: bool = false
		for e: Dictionary in drones:
			kept_any = kept_any or float(e["at"]) <= latest
		if not kept_any:
			var added: Dictionary = _add_guaranteed(gen, t, latest)
			if not added.is_empty():
				drones.push_front(added)
	if drones.is_empty():
		return

	var removed: Array[Dictionary] = []
	var waves: Array = []
	for e: Dictionary in drones:
		var at: float = e["at"]
		if at > latest:
			removed.append(e)
			continue
		if not waves.is_empty():
			var lead: float = (waves[-1] as Array)[0]["at"]
			if at - lead < 1.0:
				(waves[-1] as Array).append(e)
				continue
			if at - lead < t.min_wave_gap_seconds * speed:
				removed.append(e)
				continue
		waves.append([e])
	# Extra drones in a wave: never in the first wave of a level, and only later in the campaign.
	for w: int in waves.size():
		var wave: Array = waves[w]
		if wave.size() > 1 and (w == 0 or gen.config.enemy_scaling < t.pair_min_scaling):
			for k: int in range(wave.size() - 1, 0, -1):
				removed.append(wave[k])
				wave.remove_at(k)
	if not has_ceilings:
		_remove_entries(layout, removed)
		gen.warnings.append("drone: the level has drones but not the `ceilings` feature, so no anti-grav pad can destroy them (pad schedule skipped)")
		return
	if waves.is_empty():
		_remove_entries(layout, removed)
		return

	var first_at: float = (waves[0] as Array)[0]["at"]
	_remove_ceilings_from(layout, first_at)
	var rng: RandomNumberGenerator = gen.rng_for("drone_pads")
	var next_wave: int = 1
	var lo: float = first_at + t.first_pad_seconds * speed
	var hi: float = lo + t.first_pad_slack_seconds * speed
	while lo <= last_pad:
		var at: float = rng.randf_range(lo, minf(hi, last_pad)) if hi > lo else lo
		if not _place_pad(gen, t, rng, at):
			break
		var joined: bool = false
		while next_wave < waves.size() and float((waves[next_wave] as Array)[0]["at"]) <= at:
			if at <= latest:
				for e: Dictionary in waves[next_wave]:
					e["at"] = at
				joined = true
			else:
				removed.append_array(waves[next_wave])
			next_wave += 1
		if joined:
			lo = at + t.first_pad_seconds * speed
			hi = lo
		else:
			lo = at + t.pad_repeat_min_seconds * speed
			hi = at + t.pad_repeat_max_seconds * speed
	# Waves the schedule never reached are dropped: no drone without its pads.
	while next_wave < waves.size():
		removed.append_array(waves[next_wave])
		next_wave += 1
	_remove_entries(layout, removed)


## One drone somewhere in the first half of the level (between the tuning's shares, never before the
## run-up ends or after `latest`). Returns its entry, or {} if the level has no room for it.
static func _add_guaranteed(gen: LevelGenerator, t: DroneTuning, latest: float) -> Dictionary:
	var rng: RandomNumberGenerator = gen.rng_for("drone_wave")
	var lo: float = maxf(gen.layout.length * t.guaranteed_wave_from, gen.config.start_clear_distance)
	var hi: float = minf(gen.layout.length * t.guaranteed_wave_to, latest)
	if hi < lo:
		return {}
	var lane: int = rng.randi_range(0, gen.layout.lane_count - 1)
	return gen.add_enemy(TYPE, rng.randf_range(lo, hi), lane, 0, {"slot": 0})


static func tuning() -> DroneTuning:
	var res: Resource = EnemyDirector.tuning_for(TYPE)
	return res as DroneTuning if res is DroneTuning else DroneTuning.new()


## The furthest spot a scheduled pad can take: its ceiling and landing must end before the
## level's end-clear stretch (LevelGenerator.add_hull_with_pad).
static func last_pad_at(gen: LevelGenerator, t: DroneTuning) -> float:
	return gen.layout.length - gen.config.end_clear_distance \
		- (t.pad_ceiling_seconds + gen.config.hull_landing_seconds) * gen.speed - 0.5


## A ceiling with a pad at `at`, clearing whatever is in its way (a ceiling from another rule set
## gives way to the schedule), in a lane no hover truck holds. Returns false if it didn't fit.
static func _place_pad(gen: LevelGenerator, t: DroneTuning, rng: RandomNumberGenerator, at: float) -> bool:
	return PadPlacement.place(gen, rng, at, t.pad_ceiling_seconds)


## Removes every ceiling with a pad at or after `d` (and its pads).
static func _remove_ceilings_from(layout: LevelLayout, d: float) -> void:
	for h: Dictionary in layout.hulls.duplicate():
		for p: Dictionary in layout.pads:
			var pad_at: float = p["at"]
			if pad_at >= float(h["start"]) and pad_at <= float(h["end"]) and pad_at >= d - 0.5:
				_remove_hull(layout, h)
				break


static func _remove_hull(layout: LevelLayout, h: Dictionary) -> void:
	PadPlacement.remove_hull(layout, h)


static func _remove_entries(layout: LevelLayout, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	_keep(layout.enemies, func(e: Dictionary) -> bool:
		for r: Dictionary in entries:
			if is_same(r, e):
				return false
		return true)


## Keeps the items of `list` for which `keep` returns true (in place, so typed arrays stay typed).
static func _keep(list: Array[Dictionary], keep: Callable) -> void:
	var out: Array[Dictionary] = []
	for item: Dictionary in list:
		if keep.call(item):
			out.append(item)
	list.assign(out)
