extends TestSuite
## The ceiling scenarios (task I4; GDD §3, "Ceiling scenarios", owner, October 14, 2026; CeilingScenarios):
## - their numbers and heights: a stash holds two or three credits; a ceiling fence hangs below the underside, above
##   anything a floor runner, a hover truck's roof or a wall run reaches, and above the chase camera's highest;
## - placement: never in zones 1-2 (DESIGN-TBD: nor the Marketplace; their levels list neither feature and build
##   none); in every level that lists them, at 3, 5 and 6 lanes, each keeps its rules (LayoutChecks.check_scenarios,
##   with the rest of check_layout and check_rules); Casino 1 introduces the treasure stash at 5 and 6 lanes (none
##   fits on fewer, DESIGN-TBD) and Casino 2 the simple fenced ceiling (one unsafe pad, one safe) at every lane count;
##   the several-pad version comes later; both keep turning up over the campaign; endless mode gets them only where
##   its difficulty has reached their minimum; the same seed builds the same level (an uncached rebuild);
## - the physics they're timed by (CeilingScenarios: a pad's flip and rise, a drop off a return pad, a jump and its
##   low stretch) is the Player's, on real physics;
## - a fenced ceiling, on real physics (excerpts of the generated levels, at 3, 5 and 6 lanes, the simple version and
##   the several-pad one): every unsafe pad's rider meets a fence in every lane the ceiling covers, staying put, hopping
##   over the first row or jumping all the way, and dies of it; every safe pad's rider rides on in every lane, jumping
##   or not, and drops off past the ceiling alive; a floor runner under it, jumping, is never touched; armor gets an
##   unsafe pad's rider through; an EMP switches its fences off;
## - a treasure stash, on real physics (excerpts at 5 and 6 lanes): a floor runner switching toward it from every lane,
##   before it or alongside it, never gets in and takes none of its credits; the return pad's rider (switching to its
##   lane on the ceiling) drops in, never pushed, collects every credit and runs out of its open end; a rider who
##   stays on in another lane drops beyond it; the dash smashes in (H5; docs/questions/i4.md);
## - the track builds a ceiling fence as an electrical hazard hanging below the underside and a return pad as a
##   trigger on it, turned to face the floor; every skin dresses both (the fence's field in the zone's fence
##   materials, whose shader honours Reduced flashing; the return pad as its anti-grav pad); the chase camera stays
##   above a stash's doodads while a rider passes over them (RunCamera.doodad_floor).

const Stash = preload("res://scripts/enemies/treasure_stash_rules.gd")
const Fenced = preload("res://scripts/enemies/fenced_ceiling_rules.gd")
const STASH: String = CeilingScenarios.STASH
const FENCED: String = CeilingScenarios.FENCED
const LANE_COUNTS: Array[int] = [3, 5, 6]
## The zones whose levels never hold a ceiling scenario (GDD §3: never in zones 1-2; DESIGN-TBD: from the Casino).
const WITHOUT: Array[StringName] = [&"city", &"gangland", &"marketplace"]
## An excerpt's first pad lies this far along its fresh track.
const PAD_AT: float = 60.0
## A floor runner's excerpt starts this far before the stash.
const RUN_UP: float = 45.0

var campaign: Campaign
var st: CeilingScenarioTuning
var sim: RunSim
## The campaign builds that hold each scenario, by lane count: found[kind][lanes] = [{id, config, layout, hull}],
## in campaign order (_test_campaign).
var found: Dictionary = {}


func run() -> void:
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	st = CeilingScenarios.tuning()
	sim = RunSim.new(tree, tuning)
	_test_tuning()
	_test_campaign()
	_test_endless()
	_test_determinism()
	await _test_physics()
	await _test_fenced_rides()
	await _test_fenced_protection()
	await _test_stash_rides()
	await _test_track()
	_test_skins()
	await _test_camera()


# --- Helpers ----------------------------------------------------------------------------------------

## The rows of ceiling fences in `layout` within ceiling `h`, in track order.
static func _rows(layout: LevelLayout, h: Dictionary) -> Array[float]:
	var out: Array[float] = []
	for f: Dictionary in layout.ceiling_fences:
		var d: float = float(f["at"])
		if d >= float(h["start"]) and d <= float(h["end"]) and not out.has(d):
			out.append(d)
	out.sort()
	return out


## The treasure stash on ceiling `h` of `layout`, or {}.
static func _stash_on(layout: LevelLayout, h: Dictionary) -> Dictionary:
	for s: Dictionary in layout.stashes:
		if absf(float(s["hull_start"]) - float(h["start"])) < 0.01:
			return s
	return {}


## An excerpt of `layout`'s ceiling `h` on a fresh straight track: the ceiling, the pads under it (unless `pads` is
## false) and its scenario's pieces (ceiling fences, its stash's return pad, doodads and credits, the stash record),
## all shifted by `shift` metres. {layout, hull, stash (or {})}.
static func _excerpt(layout: LevelLayout, h: Dictionary, shift: float, pads: bool = true) -> Dictionary:
	var hull: Dictionary = h.duplicate(true)
	hull["start"] = float(h["start"]) + shift
	hull["end"] = float(h["end"]) + shift
	var out := RunSim.layout(layout.lane_count, float(hull["end"]) + 150.0)
	out.hulls.append(hull)
	if pads:
		for p: Dictionary in CeilingScenarios.pads_under(layout, h):
			var q: Dictionary = p.duplicate(true)
			q["at"] = float(p["at"]) + shift
			out.pads.append(q)
	for f: Dictionary in layout.ceiling_fences:
		if float(f["at"]) >= float(h["start"]) and float(f["at"]) <= float(h["end"]):
			out.ceiling_fences.append({"lane": int(f["lane"]), "at": float(f["at"]) + shift})
	var s: Dictionary = _stash_on(layout, h)
	var stash: Dictionary = {}
	if not s.is_empty():
		stash = s.duplicate(true)
		for key: String in ["start", "end", "walls_from", "pad", "hull_start", "keep_from", "keep_to"]:
			stash[key] = float(s[key]) + shift
		out.stashes.append(stash)
		out.return_pads.append({"lane": int(s["lane"]), "at": float(s["pad"]) + shift})
		for d: Dictionary in layout.doodads:
			if d.has("stash") and float(d["start"]) >= float(s["start"]) - 0.01 and float(d["end"]) <= float(s["end"]) + 0.01:
				var e: Dictionary = d.duplicate(true)
				e["start"] = float(d["start"]) + shift
				e["end"] = float(d["end"]) + shift
				out.doodads.append(e)
		for c: Dictionary in layout.credits:
			if c.has("stash") and float(c["at"]) >= float(s["start"]) and float(c["at"]) <= float(s["end"]):
				var k: Dictionary = c.duplicate(true)
				k["at"] = float(c["at"]) + shift
				out.credits.append(k)
	return {"layout": out, "hull": hull, "stash": stash}


## Runs a full world over `layout` (RunSim.build_world, at `mt`) from `start_lane` for up to `seconds`, calling
## `each.call(player)` before every physics frame; stops when the player dies. Returns {trace (after every frame:
## d, x, h, surface, lane, alive), alive, cause, distance, surface, lane, pushes, smashes, return_drops, pickups (credits
## collected), events}.
func _drive(layout: LevelLayout, mt: MovementTuning, start_lane: int, seconds: float, each: Callable,
		loadout: Loadout = null, before: Callable = Callable()) -> Dictionary:
	var world: RunWorld = sim.build_world(layout, loadout, mt)
	world.player.setup(mt, world.geo, start_lane)
	if before.is_valid():
		before.call(world)
	var result: Dictionary = await _drive_world(world, seconds, each)
	await sim.free_world(world)
	return result


func _drive_world(world: RunWorld, seconds: float, each: Callable) -> Dictionary:
	var player: Player = world.player
	var out := {"trace": [], "cause": "", "events": []}
	player.died.connect(func(c: String) -> void: out["cause"] = c)
	player.movement_event.connect(func(kind: StringName) -> void: (out["events"] as Array).append(kind))
	await tree.physics_frame
	player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		each.call(player)
		await tree.physics_frame
		(out["trace"] as Array).append({"d": player.distance, "x": player.position.x, "h": player.h,
			"surface": player.surface_name(), "lane": player.lane, "alive": player.alive})
		if not player.alive:
			break
	out["alive"] = player.alive
	out["distance"] = player.distance
	out["surface"] = player.surface_name()
	out["lane"] = player.lane
	out["pushes"] = player.pushes
	out["smashes"] = player.smashes
	out["return_drops"] = player.return_drops
	out["pickups"] = world.score.credit_pickups
	return out


## A driver (_drive's `each`) that does nothing.
static func _idle() -> Callable:
	return func(_p: Player) -> void: pass


## A driver for a rider: as soon as they're on the ceiling (rising to it, or on it), it presses toward `lane` until
## they're in it, and with `jumps` (track distances) presses jump at each, once.
static func _rider(lane: int, jumps: Array[float]) -> Callable:
	var left: Array[float] = jumps.duplicate()
	return func(p: Player) -> void:
		if p.surface == Player.Surface.CEILING and p.lane != lane:
			p.press(&"move_right" if lane > p.lane else &"move_left")
		while not left.is_empty() and p.distance >= left[0]:
			left.pop_front()
			p.press(&"jump")


## Track distances from `from` to `to`, `step` apart.
static func _every(from: float, to: float, step: float) -> Array[float]:
	var out: Array[float] = []
	var d: float = from
	while d <= to:
		out.append(d)
		d += step
	return out


## No track distances (a rider who never jumps).
static func _none() -> Array[float]:
	var out: Array[float] = []
	return out


## One track distance.
static func _one(d: float) -> Array[float]:
	var out: Array[float] = [d]
	return out


## The index of the first sample of `trace` from `from` on that `pred` holds for, or -1.
static func _first(trace: Array, from: int, pred: Callable) -> int:
	for i: int in range(maxi(from, 0), trace.size()):
		if pred.call(trace[i]):
			return i
	return -1


# --- Numbers and heights ----------------------------------------------------------------------------

func _test_tuning() -> void:
	check(st.resource_path == CeilingScenarios.TUNING_PATH, "the scenarios' numbers load from %s" % CeilingScenarios.TUNING_PATH)
	check(mini(st.credits_min, st.credits_max) >= 2 and maxi(st.credits_min, st.credits_max) <= 3,
		"a stash holds two or three credits (GDD §3)")
	var bottom: float = tuning.ceiling_height - tuning.ceiling_fence_depth
	check(tuning.jump_height + tuning.hurtbox_size.y < bottom - 0.1, "a floor runner's jump stays below a ceiling fence")
	var ht := EnemyDirector.tuning_for("hover_truck") as HoverTruckTuning
	check(ht != null and ht.roof_height + tuning.jump_height + tuning.hurtbox_size.y < bottom,
		"so does a jump from a hover truck's roof")
	check(tuning.wall_max_height + tuning.hurtbox_size.x < bottom, "and a wall runner's body at the top of a wall run")
	check(tuning.ceiling_height - tuning.camera_ceiling_clearance < bottom,
		"and the chase camera's highest under a ceiling (%.2f m, the fence's bottom %.2f m)"
		% [tuning.ceiling_height - tuning.camera_ceiling_clearance, bottom])
	check(tuning.camera_ceiling_height + 0.01 < tuning.doodad_height and tuning.doodad_height + tuning.camera_doodad_clearance
		< tuning.ceiling_height - tuning.camera_ceiling_clearance,
		"a ceiling rider's camera rides below a doodad's top, and has room above it under the ceiling")
	check(Stash.lanes_for(3).is_empty() and Stash.lanes_for(4).is_empty() and str(Stash.lanes_for(5)) == "[2]"
		and str(Stash.lanes_for(6)) == "[2, 3]", "a stash takes an inner lane with inner lanes either side: none on 3 or 4 lanes")
	check(Fenced.unsafe_count(2) == 1 and Fenced.unsafe_count(3) == 2 and Fenced.unsafe_count(4) == 2,
		"half of a fenced ceiling's pads, rounded up, are unsafe")


# --- Placement --------------------------------------------------------------------------------------

func _test_campaign() -> void:
	found = {STASH: {}, FENCED: {}}
	var counts: Dictionary = {STASH: 0, FENCED: 0, "several": 0, "stash_builds": 0, "fenced_builds": 0}
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame():
			continue
		var lists: bool = s.level.has_feature(STASH) or s.level.has_feature(FENCED)
		if WITHOUT.has(s.zone.id):
			check(not lists, "%s lists no ceiling scenario (GDD §3: never in zones 1-2)" % s.id)
		for lanes: int in LANE_COUNTS:
			if not lists and lanes != 3:
				continue
			var config: LevelConfig = campaign.configure(s, lanes)
			var tag: String = "%s lanes=%d" % [s.id, lanes]
			# T-SPEED: the level's own default build (LayoutCache), shared with test_campaign and others.
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			var layout: LevelLayout = gen.layout
			var taken: Array[Dictionary] = []
			for h: Dictionary in layout.hulls:
				if h.has(CeilingScenarios.KEY):
					taken.append(h)
			if not lists:
				var stash_doodads: int = 0
				for d: Dictionary in layout.doodads:
					stash_doodads += 1 if d.has("stash") else 0
				check(taken.is_empty() and layout.stashes.is_empty() and layout.return_pads.is_empty()
					and layout.ceiling_fences.is_empty() and stash_doodads == 0, "no ceiling scenario " + tag)
				continue
			LayoutChecks.check_scenarios(self, layout, config, tag)
			if lanes < 5:
				check(layout.stashes.is_empty(), "no treasure stash on fewer than 5 lanes (DESIGN-TBD) " + tag)
			counts["stash_builds"] = int(counts["stash_builds"]) + (1 if config.has_feature(STASH) and lanes >= 5 else 0)
			counts["fenced_builds"] = int(counts["fenced_builds"]) + (1 if config.has_feature(FENCED) else 0)
			for h: Dictionary in taken:
				var kind: String = CeilingScenarios.scenario_of(h)
				counts[kind] = int(counts[kind]) + 1
				if kind == FENCED and CeilingScenarios.pads_under(layout, h).size() >= 3:
					counts["several"] = int(counts["several"]) + 1
				var by_lanes: Dictionary = found[kind]
				if not by_lanes.has(lanes):
					by_lanes[lanes] = []
				(by_lanes[lanes] as Array).append({"id": s.id, "config": config, "layout": layout, "hull": h})
			# The introductions: Casino 1's stash (at 5 and 6 lanes), Casino 2's fenced ceiling, the simple version.
			if s.id == "casino/1" and lanes >= 5:
				check(layout.stashes.size() == 1, "Casino 1 introduces the treasure stash " + tag)
			if s.id == "casino/2":
				var simple: bool = false
				for h: Dictionary in taken:
					if CeilingScenarios.scenario_of(h) == FENCED:
						var unsafe: int = 0
						var pads: Array[Dictionary] = CeilingScenarios.pads_under(layout, h)
						for p: Dictionary in pads:
							unsafe += 1 if String(p.get("fenced", "")) == "unsafe" else 0
						simple = simple or (pads.size() == 2 and unsafe == 1)
				check(simple, "Casino 2 introduces the fenced ceiling simply: one unsafe pad, one safe " + tag)
			if s.id == "casino/1":
				check(not config.has_feature(FENCED), "the fenced ceiling comes after the stash, from Casino 2 " + tag)
	# Sprinkled in: most builds that can hold one do.
	check(int(counts[STASH]) * 2 >= int(counts["stash_builds"]),
		"treasure stashes keep turning up: %d in %d builds at 5 and 6 lanes" % [counts[STASH], counts["stash_builds"]])
	check(int(counts[FENCED]) * 2 >= int(counts["fenced_builds"]),
		"fenced ceilings keep turning up: %d in %d builds" % [counts[FENCED], counts["fenced_builds"]])
	check(int(counts["several"]) >= 3, "the several-pad version comes later in the campaign (%d)" % counts["several"])
	print("  ceiling scenarios: %d stashes in %d builds at 5-6 lanes, %d fenced ceilings in %d builds (%d with several pads)"
		% [counts[STASH], counts["stash_builds"], counts[FENCED], counts["fenced_builds"], counts["several"]])


## Endless mode (App.start_endless: the furthest zone's last level, its difficulty rising from 0.2, every feature
## from the start): a scenario comes only where the difficulty has reached its minimum.
func _test_endless() -> void:
	var base: LevelConfig = campaign.configure(campaign.step("casino/2"), 5)
	var config: LevelConfig = base.duplicate() as LevelConfig
	config.level_seed = 4242
	config.duration_seconds = 300.0
	config.difficulty = 0.2
	config.difficulty_ramp = 0.8
	config.feature_starts = {}
	config.guarantee_features = false
	var gen := LevelGenerator.new()
	var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
	LayoutChecks.check_scenarios(self, layout, config, "(endless)")
	var seen: int = 0
	for h: Dictionary in layout.hulls:
		var kind: String = CeilingScenarios.scenario_of(h)
		if kind == "":
			continue
		seen += 1
		var at: float = float(CeilingScenarios.pads_under(layout, h)[0]["at"])
		var need: float = st.stash_min_difficulty if kind == STASH else st.fenced_min_difficulty
		if kind == STASH:
			at = float(_stash_on(layout, h).get("pad", at))
		check(gen.difficulty_at(at / layout.length) >= need - 0.001,
			"endless: a %s only once the difficulty reaches %.2f (%.2f at %.0f m)" % [kind, need, gen.difficulty_at(at / layout.length), at])
	check(seen >= 1, "endless brings ceiling scenarios in once it's hard enough (%d)" % seen)


## The same seed builds the same level, scenarios and all (an uncached rebuild against the shared build).
func _test_determinism() -> void:
	for id: String in ["casino/1", "casino/2", "corporate/1"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		var patterns: Array = LevelGenerator.load_for(config)
		var cached: LevelLayout = LayoutCache.generate(config, tuning, patterns)
		var fresh: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
		check(JSON.stringify(cached.to_dict()) == JSON.stringify(fresh.to_dict()), "the same seed builds the same level %s" % id)
		check(not fresh.stashes.is_empty() or not fresh.ceiling_fences.is_empty(), "with its scenarios %s" % id)


# --- Physics ----------------------------------------------------------------------------------------

## CeilingScenarios' physics against the Player on real physics: where a pad flips the runner and how long the
## rise takes (to the underside, and to a fence's reach of it), where a return pad drops them and how long the fall
## takes, and a jump's time in the air and near the surface.
func _test_physics() -> void:
	var v: float = tuning.run_speed
	var frame: float = CeilingScenarios.frame_seconds()
	var depth: float = tuning.ceiling_fence_depth
	var layout := RunSim.layout(3, 300.0)
	layout.hulls.append(LevelLayout.make_hull(57.0, 170.0, Vector2i(0, 2), 3))
	layout.pads.append({"lane": 1, "at": 60.0})
	layout.return_pads.append({"lane": 1, "at": 120.0})
	sim.trace = true
	var r: Dictionary = await sim.run(layout, 1, 9.5, [])
	var tr: Array = r["trace"]
	var up: int = _first(tr, 0, func(s: Dictionary) -> bool: return s["surface"] == "ceiling")
	check(up > 0, "the pad lifts the runner")
	if up > 0:
		var d: float = tr[up]["d"]
		check(d >= CeilingScenarios.flip_early(60.0) - 0.01 and d <= CeilingScenarios.flip_late(60.0, v) + 0.01,
			"a pad flips its runner between flip_early and flip_late (%.2f in %.2f-%.2f)"
			% [d, CeilingScenarios.flip_early(60.0), CeilingScenarios.flip_late(60.0, v)])
		var t0: float = tr[up]["t"]
		var near: int = _first(tr, up, func(s: Dictionary) -> bool: return float(s["h"]) <= depth)
		var landed: int = _first(tr, up, func(s: Dictionary) -> bool: return float(s["h"]) <= 0.001)
		check(near > 0 and absf(float(tr[near]["t"]) - t0 - CeilingScenarios.rise_seconds(tuning, depth)) <= 2.0 * frame,
			"the rise into a fence's reach takes rise_seconds (%.3f s, the helper %.3f s)"
			% [float(tr[near]["t"]) - t0 if near > 0 else -1.0, CeilingScenarios.rise_seconds(tuning, depth)])
		check(landed > 0 and absf(float(tr[landed]["t"]) - t0 - CeilingScenarios.rise_seconds(tuning, 0.0)) <= 2.0 * frame,
			"the rise to the underside takes rise_seconds (%.3f s, the helper %.3f s)"
			% [float(tr[landed]["t"]) - t0 if landed > 0 else -1.0, CeilingScenarios.rise_seconds(tuning, 0.0)])
		var down: int = _first(tr, up, func(s: Dictionary) -> bool: return s["surface"] == "floor")
		check(down > 0, "the return pad drops the rider")
		if down > 0:
			var dd: float = tr[down]["d"]
			check(dd >= CeilingScenarios.flip_early(120.0) - 0.01 and dd <= CeilingScenarios.flip_late(120.0, v) + 0.01,
				"a return pad drops its rider between flip_early and flip_late (%.2f)" % dd)
			var floor_at: int = _first(tr, down, func(s: Dictionary) -> bool: return float(s["h"]) <= 0.001)
			var doodad: int = _first(tr, down, func(s: Dictionary) -> bool: return float(s["h"]) <= tuning.doodad_height)
			check(floor_at > 0 and absf(float(tr[floor_at]["t"]) - float(tr[down]["t"]) - CeilingScenarios.drop_seconds(tuning, 0.0))
				<= 2.0 * frame, "the fall to the floor takes drop_seconds (%.3f s, the helper %.3f s)"
				% [float(tr[floor_at]["t"]) - float(tr[down]["t"]) if floor_at > 0 else -1.0, CeilingScenarios.drop_seconds(tuning, 0.0)])
			check(doodad > 0 and absf(float(tr[doodad]["t"]) - float(tr[down]["t"]) - CeilingScenarios.drop_seconds(tuning, tuning.doodad_height))
				<= 2.0 * frame, "and comes down past a doodad's top when drop_seconds says (%.3f s, the helper %.3f s)"
				% [float(tr[doodad]["t"]) - float(tr[down]["t"]) if doodad > 0 else -1.0, CeilingScenarios.drop_seconds(tuning, tuning.doodad_height)])
			check(r["lane"] == 1 and (r["events"] as Array).count(&"hull_end") == 1, "and keeps its lane, with the drop's event")
	# A jump on the floor.
	var flat := RunSim.layout(3, 200.0)
	r = await sim.run(flat, 1, 2.5, [[30.0, &"jump"]])
	tr = r["trace"]
	var off: int = _first(tr, 0, func(s: Dictionary) -> bool: return float(s["h"]) > 0.0)
	var back: int = _first(tr, off + 1, func(s: Dictionary) -> bool: return float(s["h"]) <= 0.0)
	check(off > 0 and back > off and absf(float(tr[back]["t"]) - float(tr[off - 1]["t"]) - CeilingScenarios.jump_seconds(tuning)) <= 2.0 * frame,
		"a jump lasts jump_seconds (%.3f s, the helper %.3f s)" % [float(tr[back]["t"]) - float(tr[off - 1]["t"]) if back > off else -1.0,
			CeilingScenarios.jump_seconds(tuning)])
	var low: int = 0
	for i: int in range(off, back):
		low += 1 if float(tr[i]["h"]) < depth else 0
	check(absf(low * frame - CeilingScenarios.jump_low_seconds(tuning, depth)) <= 2.0 * frame,
		"a jump is within %.2f m of the surface for jump_low_seconds (%.3f s, the helper %.3f s)"
		% [depth, low * frame, CeilingScenarios.jump_low_seconds(tuning, depth)])
	sim.trace = false


# --- The fenced ceiling -----------------------------------------------------------------------------

## The fenced ceilings to ride at `lanes` lanes: the first simple one (two pads) and the first with several pads.
func _fenced_picks(lanes: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var simple: bool = false
	var several: bool = false
	for pick: Dictionary in (found[FENCED] as Dictionary).get(lanes, []):
		var n: int = CeilingScenarios.pads_under(pick["layout"], pick["hull"]).size()
		if n == 2 and not simple:
			simple = true
			out.append(pick)
		elif n >= 3 and not several:
			several = true
			out.append(pick)
	return out


func _test_fenced_rides() -> void:
	var rides: int = 0
	for lanes: int in LANE_COUNTS:
		var picks: Array[Dictionary] = _fenced_picks(lanes)
		check(picks.size() == 2, "a simple and a several-pad fenced ceiling to ride at %d lanes (%d)" % [lanes, picks.size()])
		for pick: Dictionary in picks:
			rides += await _ride_fenced(pick, lanes)
	print("  fenced ceilings: %d rides" % rides)


## Rides the fenced ceiling of `pick` (see the header); returns how many rides it ran.
func _ride_fenced(pick: Dictionary, lanes: int) -> int:
	var config: LevelConfig = pick["config"]
	var mt: MovementTuning = config.movement_for(tuning)
	var v: float = mt.run_speed
	var own: Array[Dictionary] = CeilingScenarios.pads_under(pick["layout"], pick["hull"])
	var shift: float = PAD_AT - float(own[0]["at"])
	var ex: Dictionary = _excerpt(pick["layout"], pick["hull"], shift)
	var layout: LevelLayout = ex["layout"]
	var h: Dictionary = ex["hull"]
	var span: Vector2i = layout.hull_lanes(h)
	var rows: Array[float] = _rows(layout, h)
	var half: float = mt.fence_depth * 0.5
	var tag: String = "(%s lanes=%d, the fenced ceiling at %.0f m)" % [pick["id"], lanes, float(pick["hull"]["start"])]
	var seconds: float = (float(h["end"]) + 20.0) / v
	var apex: float = mt.jump_velocity() / mt.gravity()
	var unsafe_lanes: Array[int] = []
	var last_unsafe: float = 0.0
	for p: Dictionary in layout.pads:
		if String(p["fenced"]) == "unsafe":
			unsafe_lanes.append(int(p["lane"]))
			last_unsafe = maxf(last_unsafe, float(p["at"]))
	var count: int = 0
	for p: Dictionary in layout.pads:
		var unsafe: bool = String(p["fenced"]) == "unsafe"
		var at: float = float(p["at"])
		var arrive: float = CeilingScenarios.flip_late(at, v) + v * CeilingScenarios.rise_seconds(mt, 0.0)
		# The safe pad's rider runs in a lane no unsafe pad is in, and switches into the pad's lane past them.
		var start: int = int(p["lane"])
		var floor_moves: Array = []
		if not unsafe:
			var free: int = -1
			for lane: int in layout.lane_count:
				if not unsafe_lanes.has(lane) and (free < 0 or absi(lane - start) < absi(free - start)):
					free = lane
			if free < 0:
				continue
			if free != start:
				var dir: StringName = &"move_right" if start > free else &"move_left"
				for k: int in absi(start - free):
					floor_moves.append([last_unsafe + mt.pad_length + 2.0 + k * 3.0, dir])
				start = free
		for lane: int in range(span.x, span.y + 1):
			var patterns: Array = [["still", _none()], ["jumping all the way", _every(arrive, float(h["end"]) - 1.0, 0.12 * v)]]
			if unsafe:
				patterns.append(["hopping over the first row", _one(rows[0] - apex * v)])
				patterns.append(["hopping over the second row", _one(rows[1] - apex * v)])
			for pattern: Array in patterns:
				var name: String = pattern[0]
				var jumps: Array[float] = pattern[1]
				var ride: Callable = _rider(lane, jumps)
				var moves: Array = floor_moves.duplicate()
				var driver := func(pl: Player) -> void:
					while not moves.is_empty() and pl.distance >= float(moves[0][0]):
						pl.press(moves.pop_front()[1])
					ride.call(pl)
				var r: Dictionary = await _drive(layout, mt, start, seconds, driver)
				count += 1
				var what: String = "%s pad at %.0f m (lane %d), riding in lane %d, %s %s" % ["the unsafe" if unsafe else "the safe",
					at - shift, p["lane"], lane, name, tag]
				if unsafe:
					check(not bool(r["alive"]) and String(r["cause"]) == "ceiling fence" and float(r["distance"]) <= rows[-1] + half + 1.0,
						"%s: meets a fence and dies (%s at %.1f m)" % [what, r["cause"], float(r["distance"]) - shift])
				else:
					check(bool(r["alive"]) and String(r["surface"]) == "floor" and float(r["distance"]) > float(h["end"]),
						"%s: rides past every fence and drops off alive (%s, %s at %.1f m)" % [what, r["cause"], r["surface"],
						float(r["distance"]) - shift])
					var rode: bool = false
					for s: Dictionary in r["trace"]:
						rode = rode or String(s["surface"]) == "ceiling"
					check(rode, "%s: took the pad" % what)
	# A floor runner jumping all the way under the fences is never touched (in a lane with no pad).
	for lane: int in layout.lane_count:
		var pads_here: bool = false
		for p: Dictionary in layout.pads:
			pads_here = pads_here or int(p["lane"]) == lane
		if pads_here:
			continue
		var r: Dictionary = await _drive(layout, mt, lane, seconds, _rider(lane, _every(rows[0] - 30.0, rows[-1] + 10.0, 0.7 * v)))
		count += 1
		check(bool(r["alive"]) and float(r["distance"]) > float(h["end"]), "a floor runner jumping under the fences in lane %d is never touched %s"
			% [lane, tag])
		break
	return count


## Armor gets an unsafe pad's rider through the fences (GDD §9.1: one hit, then the invulnerability), and an EMP
## switches a fenced ceiling's fences off (TrackBuilder.disable_fences_near), so its unsafe pad's rider rides on.
func _test_fenced_protection() -> void:
	var picks: Array[Dictionary] = _fenced_picks(5)
	if picks.is_empty():
		return
	var pick: Dictionary = picks[0]
	var config: LevelConfig = pick["config"]
	var mt: MovementTuning = config.movement_for(tuning)
	var own: Array[Dictionary] = CeilingScenarios.pads_under(pick["layout"], pick["hull"])
	var ex: Dictionary = _excerpt(pick["layout"], pick["hull"], PAD_AT - float(own[0]["at"]))
	var layout: LevelLayout = ex["layout"]
	var h: Dictionary = ex["hull"]
	var rows: Array[float] = _rows(layout, h)
	var lane: int = int(layout.pads[0]["lane"])
	var seconds: float = (float(h["end"]) + 20.0) / mt.run_speed
	var armor := Loadout.new()
	armor.armor = true
	var r: Dictionary = await _drive(layout, mt, lane, seconds, _idle(), armor)
	var events: Array = r["events"]
	check(bool(r["alive"]) and float(r["distance"]) > float(h["end"]) and (events.has(&"armor_break") or events.has(&"armor_hit")),
		"armor gets an unsafe pad's rider through the fences (%s, %s)" % [r["cause"], events])
	var switched: Array[int] = [0]
	var emp := func(world: RunWorld) -> void:
		switched[0] = world.emp(Vector3(world.geo.lane_x(lane), 0.0, TrackGeometry.world_z((rows[0] + rows[-1]) * 0.5)), 40.0)
	r = await _drive(layout, mt, lane, seconds, _idle(), null, emp)
	check(switched[0] == layout.ceiling_fences.size(), "an EMP switches the ceiling fences off (%d of %d)" % [switched[0], layout.ceiling_fences.size()])
	check(bool(r["alive"]) and float(r["distance"]) > float(h["end"]), "and the unsafe pad's rider rides on (%s)" % r["cause"])


# --- The treasure stash -----------------------------------------------------------------------------

func _test_stash_rides() -> void:
	for lanes: int in [5, 6]:
		var picks: Array = (found[STASH] as Dictionary).get(lanes, [])
		check(not picks.is_empty(), "a treasure stash to ride at %d lanes" % lanes)
		if picks.is_empty():
			continue
		# The first (the Casino's, the slowest zone) and the last (the fastest zone's).
		await _ride_stash(picks[0], lanes, true)
		if picks.size() > 1:
			await _ride_stash(picks[-1], lanes, false)


## Rides the treasure stash of `pick` (see the header); with `floor_runners`, the floor runners too.
func _ride_stash(pick: Dictionary, lanes: int, floor_runners: bool) -> void:
	var config: LevelConfig = pick["config"]
	var mt: MovementTuning = config.movement_for(tuning)
	var v: float = mt.run_speed
	var geo := TrackGeometry.new(lanes, mt)
	var s0: Dictionary = _stash_on(pick["layout"], pick["hull"])
	var tag: String = "(%s lanes=%d, the stash at %.0f m)" % [pick["id"], lanes, float(s0["start"])]
	var count: int = 0
	for c: Dictionary in (pick["layout"] as LevelLayout).credits:
		count += 1 if c.has("stash") and float(c["at"]) >= float(s0["start"]) and float(c["at"]) <= float(s0["end"]) else 0
	var front_end: float = INF
	for d: Dictionary in (pick["layout"] as LevelLayout).doodads:
		if d.has("stash") and int(d["lane"]) == int(s0["lane"]) and absf(float(d["start"]) - float(s0["start"])) < 0.01:
			front_end = float(d["end"])
	var lane: int = int(s0["lane"])
	if floor_runners:
		# Floor runners: no pads (nobody rides), the stash RUN_UP metres along.
		var shift: float = RUN_UP - float(s0["start"])
		var ex: Dictionary = _excerpt(pick["layout"], pick["hull"], shift, false)
		var layout: LevelLayout = ex["layout"]
		var s: Dictionary = ex["stash"]
		var inside_from: float = front_end + shift + 0.3
		var inside_to: float = float(s["end"]) - 0.3
		var seconds: float = (float(s["end"]) + 15.0) / v
		for start: int in lanes:
			for from: float in [float(s["start"]) - 12.0, float(s["walls_from"]) + 0.5, (float(s["walls_from"]) + float(s["end"])) * 0.5]:
				# Pressing toward the stash's lane every frame from `from` to its open end.
				var driver := func(p: Player) -> void:
					if p.distance >= from and p.distance <= float(s["end"]) and p.lane != lane:
						p.press(&"move_right" if lane > p.lane else &"move_left")
				var r: Dictionary = await _drive(layout, mt, start, seconds, driver)
				var inside: Array[Dictionary] = []
				for x: Dictionary in r["trace"]:
					if String(x["surface"]) == "floor" and float(x["d"]) > inside_from and float(x["d"]) < inside_to \
							and absf(float(x["x"]) - geo.lane_x(lane)) < geo.lane_width * 0.5:
						inside.append(x)
				check(inside.is_empty() and int(r["pickups"]) == 0 and bool(r["alive"]),
					"a floor runner from lane %d switching toward it from %.1f m never gets in (%d frames inside: %s; %d credits; from %.1f to %.1f) %s"
					% [start, from - float(s["start"]), inside.size(), inside.slice(0, 2), r["pickups"], inside_from, inside_to, tag])
		# The dash smashes in (H5; docs/questions/i4.md 3).
		var dash := func(p: Player) -> void:
			if p.distance >= float(s["start"]) - 4.0 and not p.dashing and p.smashes == 0:
				RunSim.act(p, &"dash")
		var r: Dictionary = await _drive(layout, mt, lane, seconds, dash)
		check(int(r["smashes"]) >= 1 and int(r["pickups"]) > 0, "the dash smashes into the stash (%d smashed, %d credits) %s"
			% [r["smashes"], r["pickups"], tag])
	# The return pad's rider, from the ceiling's first pad, switching to the stash's lane on the ceiling.
	var own: Array[Dictionary] = CeilingScenarios.pads_under(pick["layout"], pick["hull"])
	var shift2: float = PAD_AT - float(own[0]["at"])
	var ex2: Dictionary = _excerpt(pick["layout"], pick["hull"], shift2)
	var full: LevelLayout = ex2["layout"]
	var s2: Dictionary = ex2["stash"]
	var h2: Dictionary = ex2["hull"]
	var seconds2: float = (float(h2["end"]) + 20.0) / v
	var first_lane: int = int(full.pads[0]["lane"])
	var r2: Dictionary = await _drive(full, mt, first_lane, seconds2, _rider(lane, _none()))
	var rose: int = _first(r2["trace"], 0, func(x: Dictionary) -> bool: return String(x["surface"]) == "ceiling")
	var landed: int = _first(r2["trace"], maxi(rose, 0),
		func(x: Dictionary) -> bool: return String(x["surface"]) == "floor" and float(x["h"]) <= 0.001) if rose >= 0 else -1
	var at_landing: Dictionary = (r2["trace"] as Array)[landed] if landed > 0 else {}
	check(int(r2["return_drops"]) == 1 and landed > 0 and int(at_landing["lane"]) == lane
		and float(at_landing["d"]) > front_end + shift2 and float(at_landing["d"]) < float(s2["end"]),
		"the return pad drops its rider into the stash (%s) %s" % [at_landing, tag])
	check(bool(r2["alive"]) and int(r2["pushes"]) == 0 and float(r2["distance"]) > float(s2["end"]) + 5.0,
		"who runs out of its open end, never pushed (%d pushes, %s) %s" % [r2["pushes"], r2["cause"], tag])
	check(int(r2["pickups"]) == count and count >= 2, "and collects every one of its %d credits (%d) %s" % [count, r2["pickups"], tag])
	# A rider who stays on in another lane drops beyond it.
	var other: int = _other_lane(full, h2, lane)
	if other < 0:
		return
	var r3: Dictionary = await _drive(full, mt, first_lane, seconds2, _rider(other, _none()))
	var after_pad: float = float(full.pads[0]["at"]) + 5.0
	var dropped: int = _first(r3["trace"], 1,
		func(x: Dictionary) -> bool: return String(x["surface"]) == "floor" and float(x["d"]) > after_pad)
	check(int(r3["return_drops"]) == 0 and bool(r3["alive"]) and dropped > 0 and float((r3["trace"] as Array)[dropped]["d"]) > float(s2["end"]),
		"a rider who stays on in lane %d drops beyond the stash %s" % [other, tag])


## A lane next to `lane` that ceiling `h` covers, or -1.
static func _other_lane(layout: LevelLayout, h: Dictionary, lane: int) -> int:
	for other: int in [lane + 1, lane - 1]:
		if other >= 0 and other < layout.lane_count and layout.hull_covers(h, other):
			return other
	return -1


# --- Track, looks and camera ------------------------------------------------------------------------

## The track builds a fenced ceiling's fences as electrical hazards below the underside, a fence deep, a lane wide
## less a margin, dressed by the skin; and a stash's return pad as a trigger on the underside, turned to face down.
func _test_track() -> void:
	var picks: Array[Dictionary] = _fenced_picks(5)
	var stashes: Array = (found[STASH] as Dictionary).get(5, [])
	if picks.is_empty() or stashes.is_empty():
		check(false, "a fenced ceiling and a stash to build")
		return
	var mt: MovementTuning = tuning
	var own: Array[Dictionary] = CeilingScenarios.pads_under(picks[0]["layout"], picks[0]["hull"])
	var ex: Dictionary = _excerpt(picks[0]["layout"], picks[0]["hull"], PAD_AT - float(own[0]["at"]))
	var layout: LevelLayout = ex["layout"]
	var world: RunWorld = sim.build_world(layout, null, mt)
	world.track.update(PAD_AT, 0.0)
	await tree.physics_frame
	var hazards: Array[Hazard] = world.track.ceiling_fence_hazards()
	check(hazards.size() == layout.ceiling_fences.size(), "every ceiling fence is built (%d of %d)" % [hazards.size(), layout.ceiling_fences.size()])
	for hz: Hazard in hazards:
		check(hz.is_electrical and hz.hazard_name == "ceiling fence" and hz.is_active(), "a ceiling fence is an electrical hazard, on")
		check(absf(hz.global_position.y - (mt.ceiling_height - mt.ceiling_fence_depth * 0.5)) < 0.01
			and absf(hz.size.y - mt.ceiling_fence_depth) < 0.01 and absf(hz.size.z - mt.fence_depth) < 0.01
			and absf(hz.size.x - (world.geo.lane_width - 0.2)) < 0.01,
			"it hangs %.2f m below the underside, a fence deep, a lane wide less a margin" % mt.ceiling_fence_depth)
		var meshes: int = 0
		for c: Node in hz.get_children():
			meshes += 1 if c is MeshInstance3D else 0
		check(meshes >= 2, "the skin dresses it (%d meshes)" % meshes)
	await sim.free_world(world)
	var s_own: Array[Dictionary] = CeilingScenarios.pads_under(stashes[0]["layout"], stashes[0]["hull"])
	var sx: Dictionary = _excerpt(stashes[0]["layout"], stashes[0]["hull"], PAD_AT - float(s_own[0]["at"]))
	var slayout: LevelLayout = sx["layout"]
	world = sim.build_world(slayout, null, mt)
	world.track.update(float(sx["stash"]["pad"]) - 20.0, 0.0)
	await tree.physics_frame
	var pads: Array[Area3D] = []
	for n: Node in world.track.find_children("*", "Area3D", true, false):
		if n.get_meta(&"kind", &"") == &"return_pad":
			pads.append(n as Area3D)
	check(pads.size() == 1, "the stash's return pad is built (%d)" % pads.size())
	if pads.size() == 1:
		var a: Area3D = pads[0]
		check(absf(absf(a.rotation.z) - PI) < 0.01 and a.global_position.y > mt.ceiling_height - 0.5,
			"on the underside, turned to face the floor (%.2f m, %.2f rad)" % [a.global_position.y, a.rotation.z])
		check(absf(a.global_position.x - world.geo.lane_x(int(sx["stash"]["lane"]))) < 0.01, "over the stash's lane")
	var doodads: int = 0
	for n: Node in world.track.find_children("*", "DashBreakable", true, false):
		doodads += 1
	check(doodads == slayout.doodads.size(), "every doodad of the stash stands (%d of %d)" % [doodads, slayout.doodads.size()])
	await sim.free_world(world)


## Every skin (each in data/skins/, and the grey box) dresses a ceiling fence (its field in the zone's own fence
## field materials, whose energy-field shader honours Reduced flashing; an emitter along the underside; following the
## hazard's state) and a return pad (the skin's anti-grav pad look: as many meshes as its pad).
func _test_skins() -> void:
	var skins: Dictionary = {"grey box": GreyboxSkin.new()}
	for file: String in DirAccess.get_files_at("res://data/skins"):
		if file.ends_with(".tres"):
			skins[file.get_basename()] = load("res://data/skins".path_join(file))
	check(skins.size() >= 10, "every skin is swept (%d)" % skins.size())
	var size := Vector3(2.2, tuning.ceiling_fence_depth, tuning.fence_depth)
	for skin_name: String in skins:
		var skin := skins[skin_name] as ZoneSkin
		if skin == null:
			check(false, "%s is a zone skin" % skin_name)
			continue
		var root := Node3D.new()
		tree.root.add_child(root)
		var hazard := Hazard.new()
		hazard.size = size
		root.add_child(hazard)
		skin.ceiling_fence(hazard, size)
		var field_ok: bool = false
		var meshes: int = 0
		var visual: bool = false
		var fields: Array = skin.wall_fence_look()["field"]
		for c: Node in hazard.get_children():
			visual = visual or c is HazardStateVisual
			if c is MeshInstance3D:
				meshes += 1
				var mi := c as MeshInstance3D
				var m: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(0)
				field_ok = field_ok or fields.has(m)
		check(meshes >= 2 and visual, "%s dresses a ceiling fence, following the hazard's state" % skin_name)
		check(field_ok, "%s draws its field in the zone's fence field materials (they honour Reduced flashing)" % skin_name)
		for f: Material in fields:
			var shader: Shader = (f as ShaderMaterial).shader if f is ShaderMaterial else null
			check(shader != null and shader.code.contains("reduced_flash"), "%s: the field's shader honours Reduced flashing" % skin_name)
		var pad := Area3D.new()
		root.add_child(pad)
		skin.pad(pad, Vector3(2.0, 0.5, tuning.pad_length))
		var ret := Area3D.new()
		ret.rotation.z = PI
		root.add_child(ret)
		skin.return_pad(ret, Vector3(2.0, 0.5, tuning.pad_length))
		check(ret.get_child_count() > 0 and ret.get_child_count() == pad.get_child_count(),
			"%s dresses a return pad as its anti-grav pad (%d, %d)" % [skin_name, ret.get_child_count(), pad.get_child_count()])
		root.free()


## The chase camera of a rider passing over a stash on its ceiling stays camera_doodad_clearance above the top of
## every doodad it's level with, and never inside one (RunCamera.doodad_floor); the query itself.
func _test_camera() -> void:
	for lanes: int in [5, 6]:
		var picks: Array = (found[STASH] as Dictionary).get(lanes, [])
		if picks.is_empty():
			continue
		var pick: Dictionary = picks[0]
		var config: LevelConfig = pick["config"]
		var mt: MovementTuning = config.movement_for(tuning)
		var own: Array[Dictionary] = CeilingScenarios.pads_under(pick["layout"], pick["hull"])
		var ex: Dictionary = _excerpt(pick["layout"], pick["hull"], PAD_AT - float(own[0]["at"]))
		var layout: LevelLayout = ex["layout"]
		var s: Dictionary = ex["stash"]
		var h: Dictionary = ex["hull"]
		var other: int = _other_lane(layout, h, int(s["lane"]))
		if other < 0:
			continue
		var world: RunWorld = sim.build_world(layout, null, mt)
		world.player.setup(mt, world.geo, int(layout.pads[0]["lane"]))
		var camera := RunCamera.new()
		tree.root.add_child(camera)
		camera.follow(world)
		await tree.physics_frame
		world.start()
		var ride: Callable = _rider(other, _none())
		var worst: float = INF
		var inside: int = 0
		var over: int = 0
		var top: float = mt.doodad_height + mt.camera_doodad_clearance
		for i: int in int((float(s["end"]) + 10.0) / mt.run_speed * Engine.physics_ticks_per_second):
			ride.call(world.player)
			await tree.physics_frame
			await tree.process_frame
			var cam: Vector3 = camera.global_position
			var d: float = -cam.z
			for dd: Dictionary in layout.doodads:
				var half_w: float = mt.doodad_size(StringName(dd["size"])).x * 0.5
				var dx: float = absf(cam.x - world.geo.lane_x(int(dd["lane"])))
				if d >= float(dd["start"]) - 0.2 and d <= float(dd["end"]) + 0.2 and dx <= half_w + 0.2:
					over += 1
					worst = minf(worst, cam.y - top)
					inside += 1 if cam.y < mt.doodad_height + 0.05 else 0
			if not world.player.alive:
				break
		var tag: String = "(%s lanes=%d)" % [pick["id"], lanes]
		check(world.player.alive and world.player.return_drops == 0, "the rider passes over the stash " + tag)
		check(over > 0, "the camera passes over the stash's doodads (%d frames) %s" % [over, tag])
		check(inside == 0 and worst >= -0.01, "and stays %.2f m above their tops (worst %.3f m, %d frames inside) %s"
			% [mt.camera_doodad_clearance, worst, inside, tag])
		camera.queue_free()
		await sim.free_world(world)
	# The query: a doodad level with the camera, one ahead, none.
	var one := RunSim.layout(5, 200.0)
	one.doodads.append({"lane": 2, "start": 50.0, "end": 54.0, "size": &"medium", "side": 1, "seed": 3})
	var w: RunWorld = sim.build_world(one)
	w.track.update(40.0, 0.0)
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	var x: float = w.geo.lane_x(2)
	var want: float = tuning.doodad_height + tuning.camera_doodad_clearance
	var level: Vector2 = RunCamera.doodad_floor(space, Vector3(x, 2.4, TrackGeometry.world_z(52.0)), tuning)
	var ahead: Vector2 = RunCamera.doodad_floor(space, Vector3(x, 2.4, TrackGeometry.world_z(46.0)), tuning)
	var none: Vector2 = RunCamera.doodad_floor(space, Vector3(x, 2.4, TrackGeometry.world_z(20.0)), tuning)
	var aside: Vector2 = RunCamera.doodad_floor(space, Vector3(x + 2.0 * w.geo.lane_width, 2.4, TrackGeometry.world_z(52.0)), tuning)
	check(absf(level.x - want) < 0.01, "level with a doodad: its top and the clearance (%.2f)" % level.x)
	check(ahead.x == -INF and absf(ahead.y - want) < 0.01, "one ahead: rising toward it (%s)" % ahead)
	check(none == Vector2(-INF, -INF) and aside == Vector2(-INF, -INF), "none near, or two lanes aside: nothing (%s, %s)" % [none, aside])
	await sim.free_world(w)
