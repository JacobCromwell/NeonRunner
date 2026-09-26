extends RefCounted
## Generator rules for host cyborgs and the Cyborg's Bad Dream each one carries (GDD §9.7), run for
## levels with the `host` feature. Numbers come from BadDreamTuning (data/enemies/bad_dream.tres).
## Hosts are cyborgs (type `cyborg` with params.host), so the cyborg rules run first (running those
## twice, in a level with both `cyborg` and `host`, changes nothing the second time). Then host by
## host along the track (a host that breaks a rule is dropped, and the rest of the level is left as
## it was):
## - Its chase fits: the stretch the longest chase can cover at run speed from the host's spot
##   (BadDreamTuning.chase_stretch), plus one last pad's ceiling and landing, ends before the level's
##   end-clear stretch.
## - Chases never overlap: a host comes at least host_gap_seconds after the previous chase could end
##   (GDD §9.7: only one on screen at a time; the gap is longer than a cyborg's spawn lead, so the
##   next host isn't even in play before the chase is over).
## - Anti-grav pads are guaranteed during the chase: across the whole stretch, never more than
##   pad_gap_seconds without a pad. Pads already there count (pattern ceilings, the drone schedule);
##   the missing ones are added pad_slack_seconds or less before the gap would run out, where their
##   ceiling touches no other ceiling (PadPlacement clears the floor under it and picks a lane no
##   hover truck holds).
## - Drones own every pad from a level's first drone on (drone_rules.gd: GDD §9.6's 10 s before the
##   first pad, then one every 8–10 s), so these rules run after the drone rules whatever the order
##   of the features (RUN_AFTER) and add no pad from there on: a chase their schedule doesn't cover
##   is dropped. The Bad Dream and the drones' barrages never overlap at runtime either
##   (EnemyDirector.major_attack_blocked).
## - Pads need ceilings: without the `ceilings` feature a chase can't get its pads, so every host is
##   dropped, with a warning (DESIGN-TBD: the GDD doesn't say what forms the ceiling outside the
##   city, OPEN_QUESTIONS §1).
## - Late starts (LevelConfig.feature_starts): a host before the `host` feature's start is dropped,
##   and so is one whose chase begins before the `ceilings` feature's start (its pads couldn't come).
## Like the cyborg rules they start with, these run after the hover truck's (its route ramp).

const RUN_AFTER: Array[String] = ["drone", "hover_truck"]
const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const PadPlacement = preload("res://scripts/enemies/pad_placement.gd")
const DREAM_TYPE: String = "bad_dream"
## Metres between the spots tried for an added pad, from the latest allowed spot back.
const PAD_SEARCH_STEP: float = 3.0


static func apply(gen: LevelGenerator) -> void:
	CyborgRules.apply(gen)
	var layout: LevelLayout = gen.layout
	var hosts: Array[Dictionary] = hosts_in(layout)
	if hosts.is_empty():
		return
	if not gen.config.has_feature("ceilings"):
		_remove_entries(layout, hosts)
		gen.warnings.append("host: the level has hosts but not the `ceilings` feature, so a Bad Dream's chase can't get its anti-grav pads (hosts dropped)")
		return
	var t: BadDreamTuning = tuning()
	var speed: float = gen.speed
	var last_ok: float = layout.length - gen.config.end_clear_distance \
		- (t.pad_ceiling_seconds + gen.config.hull_landing_seconds) * speed
	var pads_before: float = first_drone_at(layout) - 1.0
	var earliest: float = maxf(gen.feature_start("host"), gen.feature_start("ceilings"))
	var rng: RandomNumberGenerator = gen.rng_for("host_pads")
	var free_from: float = -INF
	var dropped: Array[Dictionary] = []
	for e: Dictionary in hosts:
		if not _has_entry(layout.enemies, e):
			continue  # cleared from under a pad added for an earlier host
		var stretch: Vector2 = t.chase_stretch(float(e["at"]), speed)
		if stretch.x < free_from or stretch.x < earliest or stretch.y > last_ok:
			dropped.append(e)
			continue
		var plan: Dictionary = plan_pads(gen, t, rng, stretch, pads_before)
		if not bool(plan["ok"]):
			dropped.append(e)
			continue
		for at: float in plan["pads"]:
			PadPlacement.place(gen, rng, at, t.pad_ceiling_seconds)
		free_from = stretch.y + t.host_gap_seconds * speed
	_remove_entries(layout, dropped)


static func tuning() -> BadDreamTuning:
	var res: Resource = EnemyDirector.tuning_for(DREAM_TYPE)
	return res as BadDreamTuning if res is BadDreamTuning else BadDreamTuning.new()


## Every host in the layout, along the track.
static func hosts_in(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == "cyborg" and bool((e.get("params", {}) as Dictionary).get("host", false)):
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	return out


## Where the level's first drone appears (INF without drones): the drone rules own every pad from
## there on.
static func first_drone_at(layout: LevelLayout) -> float:
	var first: float = INF
	for e: Dictionary in layout.enemies:
		if String(e.get("type", "")) == "drone":
			first = minf(first, float(e["at"]))
	return first


## The pads to add so that never more than pad_gap_seconds pass without one across `stretch`,
## counting the pads already there (the furthest one in reach each time). {"ok": false} if a pad is
## missing where none can go: at or after `pads_before`, or wherever its ceiling would touch another.
## Nothing is changed.
static func plan_pads(gen: LevelGenerator, t: BadDreamTuning, rng: RandomNumberGenerator, stretch: Vector2,
		pads_before: float) -> Dictionary:
	var speed: float = gen.speed
	var gap: float = t.pad_gap_seconds * speed
	var slack: float = clampf(t.pad_slack_seconds, 0.0, t.pad_gap_seconds * 0.5) * speed
	var existing: Array[float] = []
	for p: Dictionary in gen.layout.pads:
		existing.append(float(p["at"]))
	var added: Array[float] = []
	var cursor: float = stretch.x
	while cursor + gap < stretch.y:
		var reach: float = cursor + gap
		var next: float = -INF
		for at: float in existing:
			if at > cursor + 0.01 and at <= reach:
				next = maxf(next, at)
		if next > -INF:
			cursor = next
			continue
		var want: float = reach - rng.randf() * slack
		var spot: float = _free_spot(gen, t, want, cursor + gap * 0.5, added)
		if is_nan(spot) or spot >= pads_before:
			return {"ok": false, "pads": []}
		added.append(spot)
		cursor = spot
	return {"ok": true, "pads": added}


## The latest spot from `want` back to `lowest` where a pad's ceiling (with the lead-in before it)
## touches no ceiling already there nor one of `planned`; NAN if there's none.
static func _free_spot(gen: LevelGenerator, t: BadDreamTuning, want: float, lowest: float,
		planned: Array[float]) -> float:
	var length: float = t.pad_ceiling_seconds * gen.speed
	var at: float = want
	while at >= lowest:
		var start: float = at - gen.config.hull_lead_in
		var end: float = at + length
		var free: bool = true
		for h: Dictionary in gen.layout.hulls:
			if start <= float(h["end"]) + 1.0 and end >= float(h["start"]) - 1.0:
				free = false
				break
		for p: float in planned:
			if start <= p + length + 1.0 and end >= p - gen.config.hull_lead_in - 1.0:
				free = false
		if free:
			return at
		at -= PAD_SEARCH_STEP
	return NAN


static func _has_entry(list: Array[Dictionary], entry: Dictionary) -> bool:
	for e: Dictionary in list:
		if is_same(e, entry):
			return true
	return false


static func _remove_entries(layout: LevelLayout, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	var kept: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if not _has_entry(entries, e):
			kept.append(e)
	layout.enemies.assign(kept)
