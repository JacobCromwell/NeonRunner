extends TestSuite
## Zone doodads (GDD §3, owner's playtest September 30, 2026; task G5): scenery standing in lanes that
## never hurts; running into one pushes the player into a neighbouring lane.
## - The layout: a level without doodads is the same data as before (no "doodads" key), and a doodad
##   share of 0 builds a level exactly as before; with a share, doodads only add (every piece, enemy,
##   pick and fill stays; only credits inside a doodad go).
## - Placement (LevelGenerator._place_doodads), always fair (LayoutChecks.check_doodads) at 3, 5 and 6
##   lanes over many seeds, difficulties and every built feature, deterministic; City 1 introduces them
##   gently; the rules' keep-outs (a Bad Dream's chase, a hover truck's lane) and the enemies' own
##   fairness checks count them.
## - The track: a body on the doodad and lane-blocker layers (never a hazard), a standable top, the
##   skin's hook with the doodad's box, class, side and seed; every skin's default look stays inside
##   the box, lit and never glowing, in muted colours.
## - The push on real physics at 3, 5 and 6 lanes: head-on into the lane on its side, at the edges
##   and in the middle, quick, with the lean, costing nothing, the body never sinking into it; a jump
##   or a slide into one is pushed the same way; a front corner caught mid-switch pushes back the way
##   the player came; a lane switch into its side is blocked (the clank and the bump, never into it);
##   a player who comes down on its top lands on it; a ceiling rider passes over one even mid-jump;
##   shots pass through it.
## - A push onto safe floor every time: every campaign level's doodads (a few a level, at 3, 5 and 6
##   lanes) run into on real physics at the level's speed, landing on clear floor in the lane beside.
## - Enemies hold back what would come with a doodad in reach (a drone's barrage, the truck's cannon).
## - The dash smashes a doodad (GDD §3, owner, October 8, 2026; task H5), on real physics: head-on at 3, 5
##   and 6 lanes in every inner lane, both sides, every size (once, no push, the lane kept, no slowdown,
##   broken before the body touches it); from the side (a switch into it while dashing goes through, no
##   clank; pushed first, then a dash steering back into it smashes it, never sinking in, and a dash during
##   its push leaves it standing); a dash that ends short pushes as usual (swept over where the dash starts,
##   at two speeds: always a push or a smash, a smash only when the dash lasted until the body got there,
##   never a sink, the same every attempt); the dash's reach counts a boost fading; in a full world its
##   body, lane blocker and top are gone, the crunch plays,
##   its pieces fly in its look's own colours and never glow, a light shake that Screen shake scales
##   away, no damage, no score, and other solid sides still block a dash; it stays smashed through a
##   revive and a retry (LevelRun) rebuilds it whole, the same level as before; every skin names its
##   doodads' colours; campaign doodads dashed through on physics at each level's speed.
## - Fairness for a runner who dashes through: in every campaign level at 3, 5 and 6 lanes, the first
##   thing after a doodad (in its lane and in any lane) comes no sooner than a reaction and a lane
##   switch at the dash's speed from its front, where the smash shows what it hid.

const DroneScript := preload("res://scripts/enemies/drone.gd")
const TruckScript := preload("res://scripts/enemies/hover_truck.gd")
const HostRules := preload("res://scripts/enemies/host_rules.gd")
const HoverTruckRules := preload("res://scripts/enemies/hover_truck_rules.gd")
const CyborgRules := preload("res://scripts/enemies/cyborg_rules.gd")
const EVERY_FEATURE: PackedStringArray = ["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "window_cyborg",
	"hover_truck", "octodog", "screech", "drone", "generator", "host", "resonator"]
## How far the body may sink into a doodad on a frame (metres): never more than rounding.
const SINK_TOLERANCE: float = 0.03
## Generated doodads run into on real physics per campaign level and lane count.
const SAFE_RUNS_PER_LEVEL: int = 3
## Generated doodads dashed through on real physics per campaign level and lane count.
const DASH_RUNS_PER_LEVEL: int = 2
## The reaction time the suites give a runner to see something and start to act (the boss bots').
const REACTION: float = 0.35


## Records the doodad hook's calls (and dresses nothing).
class RecordingSkin extends ZoneSkin:
	var calls: Array[Dictionary] = []

	func doodad(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
		calls.append({"body": body, "size": size, "size_class": size_class, "side": side, "seed": look_seed})


var sim: RunSim
var powerups: PowerupTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	powerups = load("res://data/tuning/powerups.tres") as PowerupTuning
	_test_layout_data()
	_test_share_zero()
	_test_placement()
	_test_campaign()
	_test_keep_outs()
	await _test_track()
	_test_skins()
	await _test_push()
	await _test_jump_and_slide()
	await _test_mid_switch()
	await _test_blocked_side()
	await _test_on_top()
	await _test_ceiling_rider()
	await _test_shots_pass()
	await _test_safe_floor_every_time()
	await _test_drone_waits()
	await _test_truck_cannon_waits()
	await _test_dash_head_on()
	await _test_dash_sideways()
	await _test_dash_ends_short()
	await _test_dash_reach()
	await _test_dash_world()
	await _test_dash_retry()
	_test_debris_colors()
	await _test_dash_campaign()
	_test_dash_fairness()


# --- Helpers -------------------------------------------------------------------------------------

## A doodad entry of size class `size` (its length from the tuning unless `length` is given).
func _doodad(lane: int, start: float, size: StringName, side: int, length: float = -1.0) -> Dictionary:
	var l: float = length if length > 0.0 else tuning.doodad_size(size).z
	return {"lane": lane, "start": start, "end": start + l, "size": size, "side": side, "seed": 3}


## The most the visual body sank into doodad `d` over a run's trace (metres; 0 if it never touched
## it): the smallest of the overlaps across, along and up, on every frame on the floor.
func _sink(trace: Array, d: Dictionary, geo: TrackGeometry, t: MovementTuning = null) -> float:
	var mt: MovementTuning = t if t != null else tuning
	var box: Vector3 = mt.doodad_size(StringName(d["size"]))
	var x0: float = geo.lane_x(int(d["lane"])) - box.x * 0.5
	var x1: float = geo.lane_x(int(d["lane"])) + box.x * 0.5
	var hx: float = mt.visual_size.x * 0.5
	var hz: float = mt.visual_size.z * 0.5
	var worst: float = 0.0
	for s: Dictionary in trace:
		if String(s["surface"]) != "floor":
			continue
		var x: float = float(s["x"])
		var dist: float = float(s["d"])
		var h: float = float(s["h"])
		var ox: float = minf(x + hx, x1) - maxf(x - hx, x0)
		var oz: float = minf(dist + hz, float(d["end"])) - maxf(dist - hz, float(d["start"]))
		var oy: float = minf(h + mt.visual_size.y, box.y) - maxf(h, 0.0)
		if ox > 0.0 and oz > 0.0 and oy > 0.0:
			worst = maxf(worst, minf(ox, minf(oz, oy)))
	return worst


## A plain layout of `lanes` lanes holding a copy of doodad entry `d` alone (a fresh one for each run: a
## smash marks its entry for the rest of the attempt, DashBreakable).
func _one_doodad(lanes: int, d: Dictionary) -> LevelLayout:
	var layout := RunSim.layout(lanes)
	layout.doodads.append(d.duplicate())
	return layout


## The frames of a run's trace before the dash smashed anything: while a doodad still stood.
func _standing(trace: Array) -> Array:
	var out: Array = []
	for s: Dictionary in trace:
		if int(s.get("smashes", 0)) > 0:
			break
		out.append(s)
	return out


## The dash's length (metres) at run speed `run_speed`: its duration at the speed plus its bonus.
func _dash_length(run_speed: float) -> float:
	return powerups.dash_duration * (run_speed + powerups.dash_speed_bonus)


func _inner_lanes(lanes: int) -> Array[int]:
	var out: Array[int] = []
	for lane: int in range(1, lanes - 1):
		out.append(lane)
	return out


func _run_until(w: RunWorld, seconds: float, done: Callable) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


# --- The layout and the generator ----------------------------------------------------------------

func _test_layout_data() -> void:
	var l := RunSim.layout(3)
	check(not l.to_dict().has("doodads"), "a layout without doodads has no doodads list in its data: the same data as before")
	l.doodads.append(_doodad(1, 40.0, &"medium", 1))
	check((l.to_dict().get("doodads", []) as Array).size() == 1, "a layout's doodads are in its data")
	var c: LevelLayout = l.copy()
	c.doodads[0]["lane"] = 0
	check(int(l.doodads[0]["lane"]) == 1 and c.doodads.size() == 1, "a copy has its own doodads")
	check(l.doodad_between(30.0, 40.5) and not l.doodad_between(45.0, 60.0) and l.doodad_between(41.0, 42.0, 1)
		and not l.doodad_between(41.0, 42.0, 0), "doodad_between finds a doodad by stretch and lane")
	# The sizes: too tall to jump, low enough for a ceiling rider to pass over even mid-jump, inside a lane.
	var small: Vector3 = tuning.doodad_size(&"small")
	var medium: Vector3 = tuning.doodad_size(&"medium")
	var large: Vector3 = tuning.doodad_size(&"large")
	check(small.z < medium.z and medium.z < large.z, "the size classes grow in length (%.1f, %.1f, %.1f m)" % [small.z, medium.z, large.z])
	for box: Vector3 in [small, medium, large]:
		check(box.y > tuning.jump_height + 0.5, "a doodad is far too tall to jump (%.2f m; a jump's feet reach %.2f m)" % [box.y, tuning.jump_height])
		check(box.y < tuning.ceiling_height - tuning.jump_height - tuning.visual_size.y,
			"a ceiling rider's head clears it even mid-jump (%.2f m against %.2f m)"
			% [box.y, tuning.ceiling_height - tuning.jump_height - tuning.visual_size.y])
		check(box.x <= tuning.lane_width - 0.3, "a doodad fits in its lane with room to pass beside it (%.2f m)" % box.x)
	check(LevelConfig.new().doodad_share == 0.0 and (load(LEVEL_PATH) as LevelConfig).doodad_share == 0.0,
		"levels have no doodads unless their data says so (quick play's prototype level and the tests' have none)")


## A share of 0 builds a level exactly as before; a share only adds doodads: every piece, enemy, pick
## and fill stays, and only the credits inside a doodad go. City 1's extra gaps (GapDensity, after the doodads)
## are the one exception FIX4 left (docs/questions/fix4.md): a full-width widening or a new row keeps its margin
## from a doodad, so where both want the same stretch the extra gap goes elsewhere. There the level's own gaps
## stay, and as many extra gaps come, in as many lanes (_check_extra_gaps); task G7's wider gaps re-rolled City 1
## at 3 lanes into that case. Dash walls past an introduction come after the doodads too (task H7a,
## DashWallRules.after_doodads) and stand where they leave room, taking out the plain pieces in their way, so
## both builds leave them out: what's compared is the doodads' own doing.
func _test_share_zero() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var checked: int = 0
	for id: String in ["city/1", "gangland/3", "marketplace/1", "dead_zone/2", "golden/2"]:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var tag: String = "%s lanes=%d" % [id, lanes]
			check(config.doodad_share > 0.0, "%s has doodads in its data" % tag)
			check(not config.feature_starts.has("dash_wall"), "%s doesn't introduce dash walls %s" % [id, tag])
			config.dash_walls = 0
			var off: LevelConfig = config.duplicate() as LevelConfig
			off.doodad_share = 0.0
			var patterns: Array = LevelGenerator.load_for(config)
			var gen := LevelGenerator.new()
			var with: LevelLayout = gen.generate(config, tuning, patterns)
			var plain_gen := LevelGenerator.new()
			var plain: LevelLayout = plain_gen.generate(off, tuning, patterns)
			check(plain.doodads.is_empty() and not plain.to_dict().has("doodads"), "a share of 0 places none " + tag)
			check(not with.doodads.is_empty() or config.paced_in_bursts(), "the level's share places some (%d) %s" % [with.doodads.size(), tag])
			var a: Dictionary = with.to_dict()
			var b: Dictionary = plain.to_dict()
			for key: String in ["gaps", "fences", "signs", "hulls", "pads", "ramps", "speed_pads", "enemies"]:
				if key == "gaps" and (config.gap_encounter_increase > 0.0 or config.gap_lane_increase > 0.0) \
						and JSON.stringify(a[key]) != JSON.stringify(b[key]):
					_check_extra_gaps(config, patterns, gen, plain_gen, with, plain, tag)
					continue
				check(JSON.stringify(a[key]) == JSON.stringify(b[key]), "doodads leave the %s as they were %s" % [key, tag])
			check(JSON.stringify(gen.picks) == JSON.stringify(plain_gen.picks) and JSON.stringify(gen.fills) == JSON.stringify(plain_gen.fills)
				and gen.attempts == plain_gen.attempts, "and the pattern pass, the fill pass and the guarantee's builds " + tag)
			var kept: Dictionary = {}
			for credit: Dictionary in with.credits:
				kept[JSON.stringify(credit)] = true
			var dropped_ok: bool = true
			for credit: Dictionary in plain.credits:
				if kept.has(JSON.stringify(credit)):
					continue
				var d: float = float(credit["at"])
				dropped_ok = dropped_ok and String(credit["surface"]) == "floor" and with.doodad_between(
					d - LevelGenerator.DOODAD_CREDIT_MARGIN - 0.001, d + LevelGenerator.DOODAD_CREDIT_MARGIN + 0.001, int(credit["lane"]))
			check(dropped_ok and with.credits.size() <= plain.credits.size(),
				"only credits inside a doodad (or at its ends) go (%d of %d) %s" % [plain.credits.size() - with.credits.size(),
				plain.credits.size(), tag])
			checked += 1
	check(checked == 15, "levels compared with and without doodads: %d" % checked)


## City 1's gaps with doodads (`with`, `gen`'s build) and without (`plain`, `plain_gen`'s), where they differ: the
## level's own gaps (its build without the extra gaps) stay in both, the extra gaps come as many rows and holes
## in both, and only extra gaps differ.
func _check_extra_gaps(config: LevelConfig, patterns: Array, gen: LevelGenerator, plain_gen: LevelGenerator,
		with: LevelLayout, plain: LevelLayout, tag: String) -> void:
	var own: LevelConfig = config.duplicate() as LevelConfig
	own.gap_encounter_increase = 0.0
	own.gap_lane_increase = 0.0
	var base: LevelLayout = LevelGenerator.new().generate(own, tuning, patterns)
	var base_gaps: Dictionary = {}
	for g: Dictionary in base.gaps:
		base_gaps[JSON.stringify(g)] = true
	var with_gaps: Dictionary = {}
	for g: Dictionary in with.gaps:
		with_gaps[JSON.stringify(g)] = true
	var plain_gaps: Dictionary = {}
	for g: Dictionary in plain.gaps:
		plain_gaps[JSON.stringify(g)] = true
	var own_kept: bool = true
	for key: String in base_gaps:
		own_kept = own_kept and with_gaps.has(key) and plain_gaps.has(key)
	check(own_kept, "doodads leave the level's own gaps as they were %s" % tag)
	var moved: PackedStringArray = []
	for key: String in with_gaps:
		if not plain_gaps.has(key):
			moved.append(key)
			own_kept = own_kept and not base_gaps.has(key)
	for key: String in plain_gaps:
		if not with_gaps.has(key):
			moved.append(key)
			own_kept = own_kept and not base_gaps.has(key)
	var a: Dictionary = gen.gap_density_result
	var b: Dictionary = plain_gen.gap_density_result
	check(own_kept and int(a.get("rows", -1)) == int(b.get("rows", -2)) and int(a.get("lane_gaps", -1)) == int(b.get("lane_gaps", -2))
		and var_to_str(a.get("constraints", [])) == var_to_str(b.get("constraints", [])),
		"doodads move only City 1's extra gaps (FIX4), and as many come (%d rows, %d holes; moved %s) %s" % [
		int(a.get("rows", -1)), int(a.get("lane_gaps", -1)), moved, tag])


## Placement fairness (LayoutChecks.check_doodads, with the rest of check_layout and check_rules) at
## 3, 5 and 6 lanes, over many seeds and difficulties, with the prototype level's features and with every
## built feature, at the highest share; deterministic; both sides, every inner lane and every size.
func _test_placement() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var levels: int = 0
	for lanes: int in [3, 5, 6]:
		var count: int = 0
		var sides: Dictionary = {}
		var lanes_used: Dictionary = {}
		var sizes: Dictionary = {}
		for every: bool in [false, true]:
			for difficulty: float in [0.0, 0.5, 1.0]:
				for level_seed: int in range(1, 13):
					var config: LevelConfig = base.duplicate() as LevelConfig
					config.lane_count = lanes
					config.difficulty = difficulty
					config.level_seed = level_seed
					config.doodad_share = 1.0
					config.fill_empty_seconds = 2.0 if level_seed % 2 == 0 else 0.0
					if every:
						config.features = EVERY_FEATURE
						config.enemy_scaling = difficulty
					var tag: String = "lanes=%d diff=%.1f seed=%d%s" % [lanes, difficulty, level_seed, " every feature" if every else ""]
					var patterns: Array = LevelGenerator.load_for(config)
					var gen := LevelGenerator.new()
					var layout: LevelLayout = gen.generate(config, tuning, patterns)
					check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
					var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(again.to_dict()) == JSON.stringify(layout.to_dict()), "deterministic, doodads and all " + tag)
					LayoutChecks.check_layout(self, layout, config, tag)
					LayoutChecks.check_rules(self, layout, config, tag)
					for d: Dictionary in layout.doodads:
						count += 1
						sides[int(d["side"])] = true
						lanes_used[int(d["lane"])] = true
						sizes[StringName(d["size"])] = true
					levels += 1
		check(count > 0 and sides.size() == 2, "at %d lanes doodads stand (%d) and push both ways" % [lanes, count])
		check(lanes_used.size() == lanes - 2, "in every inner lane (%s)" % [lanes_used.keys()])
		check(sizes.size() == LevelLayout.DOODAD_SIZES.size(), "in every size class (%s)" % [sizes.keys()])
	# Another seed places them differently.
	var one: LevelConfig = base.duplicate() as LevelConfig
	one.doodad_share = 1.0
	var two: LevelConfig = one.duplicate() as LevelConfig
	two.level_seed = one.level_seed + 1
	var patterns_one: Array = LevelGenerator.load_for(one)
	check(JSON.stringify(LevelGenerator.new().generate(one, tuning, patterns_one).doodads)
		!= JSON.stringify(LevelGenerator.new().generate(two, tuning, patterns_one).doodads), "another seed, other doodads")
	print("  doodad placement checked in %d levels" % levels)


## Every campaign level has doodads at 3, 5 and 6 lanes, each checked where it stands (test_campaign
## checks them all, with every other rule); City 1 introduces them gently: none before its start, and
## no large one.
func _test_campaign() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var total: int = 0
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var level_total: int = 0
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(s, lanes)
			var tag: String = "%s lanes=%d" % [s.id, lanes]
			# T-SPEED: a campaign level's own default build (LayoutCache), the same one test_campaign.gd,
			# test_wall_fences.gd and _test_safe_floor_every_time below all build to run their own checks.
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			var layout: LevelLayout = gen.layout
			# A level paced in bursts keeps its quiet stretches empty, as the fill pass does, and its
			# dense bursts leave little room: it may have none at one lane count.
			check(not layout.doodads.is_empty() or config.paced_in_bursts(), "%s has doodads (%d)" % [tag, layout.doodads.size()])
			total += layout.doodads.size()
			level_total += layout.doodads.size()
			LayoutChecks.check_doodads(self, layout, config, tag)
			if s.id == "city/1":
				for d: Dictionary in layout.doodads:
					check(float(d["start"]) >= config.doodad_start * layout.length - 0.01 and StringName(d["size"]) != &"large",
						"City 1 brings in its doodads gently: from a fifth of the way in, never a large one " + tag)
				var minutes: float = layout.length / gen.speed / 60.0
				check(layout.doodads.size() / minutes <= 6.0, "and a few a minute at most (%.1f) %s" % [layout.doodads.size() / minutes, tag])
		check(level_total > 0, "%s has doodads over its lane counts (%d)" % [s.id, level_total])
	print("  %d doodads in the campaign's levels at 3, 5 and 6 lanes" % total)


## What the rules keep from doodads (LevelGenerator.doodad_keep_outs): a Bad Dream's chase in every lane,
## a hover truck's lane until it has left; and the enemies' own fairness checks count doodads.
func _test_keep_outs() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var chases: int = 0
	var truck_lanes: int = 0
	for level_seed: int in range(1, 9):
		var config: LevelConfig = base.duplicate() as LevelConfig
		config.lane_count = 5
		config.difficulty = 1.0
		config.enemy_scaling = 1.0
		config.level_seed = level_seed
		config.features = EVERY_FEATURE
		config.doodad_share = 1.0
		var patterns: Array = LevelGenerator.load_for(config)
		var gen := LevelGenerator.new()
		gen.generate(config, tuning, patterns)
		var lane_keeps: Array[Dictionary] = []
		var busy: Array[Vector2] = gen.doodad_keep_outs(patterns, lane_keeps)
		for s: Vector2 in HostRules.chase_stretches(gen):
			chases += 1
			check(busy.has(s), "a Bad Dream's chase is kept from doodads in every lane (seed %d)" % level_seed)
		var tt: HoverTruckTuning = HoverTruckRules.tuning()
		for e: Dictionary in gen.layout.enemies:
			if String(e["type"]) != "hover_truck":
				continue
			truck_lanes += 1
			var found: bool = false
			for k: Dictionary in lane_keeps:
				found = found or (int(k["lane"]) == int(e["lane"]) and is_equal_approx(float(k["to"]),
					HoverTruckRules.window_end(tt, float(e["at"]), gen.speed)))
			check(found, "a hover truck's lane is kept from doodads until it has left (seed %d)" % level_seed)
	check(chases > 0 and truck_lanes > 0, "chases (%d) and trucks (%d) were there to check" % [chases, truck_lanes])

	var l := RunSim.layout(3)
	l.doodads.append(_doodad(1, 100.0, &"large", 1))
	check(not Octodog.window_clear(l, 80.0, 102.0) and Octodog.window_clear(l, 110.0, 140.0),
		"an Octodog never charges with a doodad in its stretch (a charge a wait moved on)")
	var zones := CeilingZones.make(LevelConfig.new(), tuning)
	check(not Resonator.pulse_clear(l, zones, 90.0, Vector2(95.0, 101.0)) and Resonator.pulse_clear(l, zones, 120.0, Vector2(125.0, 130.0)),
		"a Resonator's wave never meets the player by a doodad")
	var spans: Array[Vector2] = CyborgRules.obstacle_spans(l, tuning, zones)
	check(spans.has(Vector2(100.0, 100.0 + tuning.doodad_large_length)),
		"a cyborg's walk and panic run keep their margin from doodads (they're among its obstacles)")


# --- The track and the skins ---------------------------------------------------------------------

## The track builds each doodad as a body on the doodad and lane-blocker layers (never a hazard, so
## nothing hurts and no shot sees it) with a standable top on the floor layer, its box from the size
## class, in its lane, and hands it to the skin's hook.
func _test_track() -> void:
	var lanes: int = 5
	var layout := RunSim.layout(lanes, 300.0)
	layout.doodads.append(_doodad(1, 30.0, &"small", -1))
	layout.doodads.append(_doodad(2, 70.0, &"medium", 1))
	layout.doodads.append(_doodad(3, 110.0, &"large", -1))
	var root := Node3D.new()
	tree.root.add_child(root)
	var track := TrackBuilder.new()
	root.add_child(track)
	var skin := RecordingSkin.new()
	track.set_layout(layout, tuning, skin)
	track.update(0.0, 0.0)
	await tree.physics_frame
	var geo := TrackGeometry.new(lanes, tuning)
	var bodies: Array[Area3D] = []
	for node: Node in track.find_children("*", "Area3D", true, false):
		if node.has_meta(&"doodad"):
			bodies.append(node as Area3D)
	check(bodies.size() == 3 and skin.calls.size() == 3, "every doodad is built and dressed (%d, %d)" % [bodies.size(), skin.calls.size()])
	for area: Area3D in bodies:
		var d: Dictionary = area.get_meta(&"doodad")
		var box: Vector3 = tuning.doodad_size(StringName(d["size"]))
		var shape := (area.get_child(0) as CollisionShape3D).shape as BoxShape3D
		var tag: String = "(%s in lane %d)" % [d["size"], d["lane"]]
		check(area.collision_layer == TrackBuilder.LAYER_DOODAD | TrackBuilder.LAYER_LANE_BLOCKER
			and area.collision_layer & TrackBuilder.LAYER_HAZARD == 0, "a doodad's body: the doodad and lane-blocker layers, never a hazard " + tag)
		check(shape != null and shape.size.is_equal_approx(Vector3(box.x, box.y, float(d["end"]) - float(d["start"]))),
			"its box is its size class's " + tag)
		check(is_equal_approx(area.global_position.x, geo.lane_x(int(d["lane"]))) and is_equal_approx(area.global_position.y, box.y * 0.5)
			and is_equal_approx(-area.global_position.z, (float(d["start"]) + float(d["end"])) * 0.5), "standing in its lane on the floor " + tag)
		var tops: Array[Node] = area.find_children("*", "StaticBody3D", false, false)
		check(tops.size() == 1 and (tops[0] as StaticBody3D).collision_layer == TrackBuilder.LAYER_FLOOR,
			"with a standable top on the floor layer " + tag)
		check(area.find_children("*", "Hazard", true, false).is_empty(), "and nothing in it is a hazard " + tag)
	for c: Dictionary in skin.calls:
		var d: Dictionary = (c["body"] as Node3D).get_meta(&"doodad")
		check(StringName(c["size_class"]) == StringName(d["size"]) and int(c["side"]) == int(d["side"]) and int(c["seed"]) == int(d["seed"])
			and (c["size"] as Vector3).is_equal_approx(Vector3(tuning.doodad_size(StringName(d["size"])).x, tuning.doodad_height,
			float(d["end"]) - float(d["start"]))), "the skin's hook gets the doodad's box, size class, push side and seed")
	root.queue_free()
	await tree.process_frame


## Every zone's default doodad look (ZoneSkin.doodad, default_doodad_mesh): inside the box, lit and
## never glowing (the kit's solid material, no glow in any vertex), in muted, non-hazard colours.
func _test_skins() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("res://data/skins")
	var skins: int = 0
	for file: String in files:
		if not file.ends_with(".tres"):
			continue
		var skin := load("res://data/skins".path_join(file)) as ZoneSkin
		if skin == null:
			continue
		skins += 1
		check(skin.doodad_palette.size() >= 3, "%s has a doodad palette" % file)
		for c: Color in skin.doodad_palette:
			check(c.s <= 0.6 and c.v <= 0.92 and c.a == 1.0, "%s's doodad colours are muted, never a hazard's glow (%s)" % [file, c])
		for size: StringName in LevelLayout.DOODAD_SIZES:
			for side: int in [-1, 1]:
				var box: Vector3 = tuning.doodad_size(size)
				var body := Node3D.new()
				skin.doodad(body, box, size, side, 7)
				var meshes: Array[Node] = body.find_children("*", "MeshInstance3D", true, false)
				check(not meshes.is_empty(), "%s dresses a %s doodad" % [file, size])
				for m: Node in meshes:
					var inst := m as MeshInstance3D
					var aabb: AABB = inst.mesh.get_aabb()
					var half: Vector3 = box * 0.5 + Vector3.ONE * 0.001
					check(aabb.position.x >= -half.x and aabb.position.y >= -half.y and aabb.position.z >= -half.z
						and aabb.end.x <= half.x and aabb.end.y <= half.y and aabb.end.z <= half.z,
						"%s's %s doodad stays inside its box (%s in %s)" % [file, size, aabb, box])
					var glows: bool = false
					for surface: int in inst.mesh.get_surface_count():
						var arrays: Array = inst.mesh.surface_get_arrays(surface)
						for col: Color in arrays[Mesh.ARRAY_COLOR]:
							glows = glows or col.a > 0.0
					check(not glows and inst.material_override == MeshKit.solid(), "%s's %s doodad is lit, never glowing" % [file, size])
				body.free()
	check(skins >= 7, "every skin's doodads looked at (%d)" % skins)


# --- The push on real physics ------------------------------------------------------------------

## Head-on into a doodad at 3, 5 and 6 lanes, in each inner lane (pushes into the edge lanes and
## between inner ones), both ways, small and large: one push into the lane on its side, quick (within
## doodad_push_time), with the runner leaning into it, the run's speed unchanged (it costs nothing),
## and the body never sinking into it.
func _test_push() -> void:
	sim.trace = true
	var runs: int = 0
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for lane: int in _inner_lanes(lanes):
			for side: int in [-1, 1]:
				for size: StringName in [&"small", &"large"]:
					var tag: String = "(lanes=%d, lane %d, side %+d, %s)" % [lanes, lane, side, size]
					var layout := RunSim.layout(lanes)
					var d: Dictionary = _doodad(lane, 40.0, size, side)
					layout.doodads.append(d)
					var r: Dictionary = await sim.run(layout, lane, 3.2, [])
					var events: Array = r["events"]
					check(r["alive"] and events.count(&"doodad_push") == 1 and int(r["lane"]) == lane + side,
						"running into a doodad pushes the player into the lane on its side, once (lane %d, %s) %s"
						% [r["lane"], events, tag])
					var sink: float = _sink(r["trace"], d, geo)
					check(sink <= SINK_TOLERANCE, "the body never sinks into it (%.3f m) %s" % [sink, tag])
					var start: float = -1.0
					var done: float = -1.0
					var leaned: bool = false
					var steady: bool = true
					for s: Dictionary in r["trace"]:
						steady = steady and absf(float(s["speed"]) - tuning.run_speed) < 0.001
						if start < 0.0 and int(s["lane"]) == lane + side:
							start = float(s["t"])
						if start >= 0.0 and done < 0.0:
							leaned = leaned or int(s["lean"]) == side
							if absf(float(s["x"]) - geo.lane_x(lane + side)) < 0.01:
								done = float(s["t"])
					check(start >= 0.0 and done >= 0.0 and done - start <= tuning.doodad_push_time + 1.5 / Engine.physics_ticks_per_second,
						"a quick shove: in the next lane's middle within %.2f s (%.3f s) %s" % [tuning.doodad_push_time, done - start, tag])
					check(leaned, "the runner leans into the push " + tag)
					check(steady, "the push costs nothing: the run's speed is unchanged " + tag)
					runs += 1
	sim.trace = false
	check(runs == 32, "pushes run: %d" % runs)


## GDD §3 (G5 brief): a player jumping into a doodad is pushed the same way (it's too tall to jump: the
## jump's feet stay below its top), and so is one sliding into it.
func _test_jump_and_slide() -> void:
	sim.trace = true
	var geo := TrackGeometry.new(3, tuning)
	var layout := RunSim.layout(3)
	var d: Dictionary = _doodad(1, 40.0, &"medium", 1)
	layout.doodads.append(d)
	var jump_at: float = 40.0 - tuning.jump_distance(tuning.run_speed) * 0.55
	var r: Dictionary = await sim.run(layout, 1, 3.0, [[jump_at, &"jump"]])
	var air: bool = false
	var apex: float = 0.0
	for s: Dictionary in r["trace"]:
		apex = maxf(apex, float(s["h"]))
		if int(s["lane"]) == 2 and not air:
			air = float(s["h"]) > 0.3
	check(r["alive"] and (r["events"] as Array).count(&"doodad_push") == 1 and int(r["lane"]) == 2 and air,
		"a jump into a doodad is pushed the same way, in the air (lane %d)" % r["lane"])
	check(apex < tuning.doodad_height, "it's too tall to jump: the jump's feet peaked at %.2f m, below its %.2f m top"
		% [apex, tuning.doodad_height])
	check(_sink(r["trace"], d, geo) <= SINK_TOLERANCE, "and the body never sank into it")
	r = await sim.run(layout, 1, 3.0, [[34.0, &"slide"]])
	check(r["alive"] and (r["events"] as Array).count(&"doodad_push") == 1 and int(r["lane"]) == 2
		and _sink(r["trace"], d, geo) <= SINK_TOLERANCE, "a slide into a doodad is pushed the same way (lane %d)" % r["lane"])
	sim.trace = false


## A front corner caught mid-switch pushes the player back the way they came (never through the
## doodad to its side); a switch finished before its front is pushed head-on, to its side. The same on
## every attempt.
func _test_mid_switch() -> void:
	sim.trace = true
	for lanes: int in [3, 5]:
		var geo := TrackGeometry.new(lanes, tuning)
		for side: int in [-1, 1]:
			var lane: int = 1 if lanes == 3 else 2
			var from: int = lane - side  # coming from the side away from its push
			var toward: StringName = &"move_right" if side > 0 else &"move_left"
			var layout := RunSim.layout(lanes)
			var d: Dictionary = _doodad(lane, 40.0, &"medium", side)
			layout.doodads.append(d)
			var tag: String = "(lanes=%d, from lane %d, its side %+d)" % [lanes, from, side]
			var late: Dictionary = await sim.run(layout, from, 3.0, [[38.4, toward]])
			check(late["alive"] and (late["events"] as Array).has(&"doodad_push") and int(late["lane"]) == from
				and _sink(late["trace"], d, geo) <= SINK_TOLERANCE,
				"caught by its front corner mid-switch, the player is pushed back the way they came (lane %d) %s" % [late["lane"], tag])
			var again: Dictionary = await sim.run(layout, from, 3.0, [[38.4, toward]])
			check(int(again["lane"]) == int(late["lane"]), "the same on every attempt " + tag)
			var early: Dictionary = await sim.run(layout, from, 3.0, [[36.6, toward]])
			check(early["alive"] and (early["events"] as Array).has(&"doodad_push") and int(early["lane"]) == lane + side
				and _sink(early["trace"], d, geo) <= SINK_TOLERANCE,
				"a switch finished before its front is pushed head-on, to its side (lane %d) %s" % [early["lane"], tag])
	sim.trace = false


## A lane switch into a doodad's side is blocked like a solid side's (R1's bump and clank: the
## lane_blocked event, which plays the clank), the runner leaning toward it and the body never reaching
## it; beside its front too, and past its end the switch goes through.
func _test_blocked_side() -> void:
	sim.trace = true
	for lanes: int in [3, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		var lane: int = 1
		var layout := RunSim.layout(lanes)
		var d: Dictionary = _doodad(lane, 40.0, &"large", -1)
		layout.doodads.append(d)
		var beside: int = lane + 1
		for at: float in [39.8, 43.0, 46.0]:
			var tag: String = "(lanes=%d, at %.1f m)" % [lanes, at]
			var r: Dictionary = await sim.run(layout, beside, 3.5, [[at, &"move_left"]], [at + 4.0])
			var events: Array = r["events"]
			check(r["alive"] and events.count(&"lane_blocked") == 1 and not events.has(&"doodad_push")
				and int((r["at"] as Dictionary)[at + 4.0]["lane"]) == beside,
				"a lane switch into a doodad's side is blocked: the clank and the bump, staying in the lane (%s) %s" % [events, tag])
			check(_sink(r["trace"], d, geo) <= 0.0001, "the bump never reaches it " + tag)
			var leaned: bool = false
			for s: Dictionary in r["trace"]:
				leaned = leaned or int(s["lean"]) == -1
			check(leaned, "the runner leans toward it, as into any solid side " + tag)
		var past: Dictionary = await sim.run(layout, beside, 3.5, [[float(d["end"]) + 1.0, &"move_left"]])
		check(int(past["lane"]) == lane and not (past["events"] as Array).has(&"lane_blocked"),
			"past its end the switch goes through (lanes=%d)" % lanes)
	sim.trace = false


## A doodad is solid all over: a player who comes down on it from above (off a wall jump, say) lands on
## its top and runs along it, never pushed, then drops off its end into its lane.
func _test_on_top() -> void:
	var layout := RunSim.layout(3, 300.0)
	layout.doodads.append(_doodad(1, 30.0, &"large", 1, 30.0))
	var w: RunWorld = sim.build_world(layout)
	var p: Player = w.player
	p.distance = 33.0
	p.h = 4.0
	p.grounded = false
	p.vh = 0.0
	var on_top: Array = [false]
	var landed_floor: Array = [false]
	await _run_until(w, 3.0, func() -> bool:
		if p.grounded and absf(p.h - tuning.doodad_height) < 0.02 and p.distance < 60.0:
			on_top[0] = true
		if on_top[0] and p.grounded and absf(p.h) < 0.02 and p.distance > 60.0:
			landed_floor[0] = true
		return landed_floor[0])
	check(on_top[0] and p.pushes == 0, "a player coming down on a doodad lands on its top, unpushed")
	check(landed_floor[0] and p.alive and p.lane == 1, "and drops off its end into its lane (lane %d)" % p.lane)
	await sim.free_world(w)


## GDD §3 (G5 brief): ceiling riders pass over doodads (the generator never puts one under a ceiling, but
## a doodad is low enough anyway): a rider over one, even mid-jump toward the floor, never touches it.
func _test_ceiling_rider() -> void:
	sim.trace = true
	var layout := RunSim.layout(3)
	layout.pads.append({"lane": 1, "at": 20.0})
	layout.hulls.append({"start": 17.0, "end": 110.0})
	var d: Dictionary = _doodad(1, 60.0, &"large", 1)
	layout.doodads.append(d)
	var r: Dictionary = await sim.run(layout, 1, 4.0, [[56.0, &"jump"]], [64.0])
	var lowest: float = INF
	for s: Dictionary in r["trace"]:
		if String(s["surface"]) == "ceiling" and float(s["d"]) >= 59.0 and float(s["d"]) <= 67.0:
			lowest = minf(lowest, tuning.ceiling_height - float(s["h"]) - tuning.visual_size.y)
	check(String((r["at"] as Dictionary)[64.0]["surface"]) == "ceiling" and not (r["events"] as Array).has(&"doodad_push")
		and r["alive"], "a ceiling rider passes over a doodad, unpushed")
	check(lowest > tuning.doodad_height, "even jumping toward the floor its body stays above the doodad (%.2f m over %.2f m)"
		% [lowest, tuning.doodad_height])
	sim.trace = false


## Weapons ignore doodads and doodads never stop a shot: an enemy bolt fired through one still reaches
## the player behind it.
func _test_shots_pass() -> void:
	var layout := RunSim.layout(3, 400.0)
	layout.doodads.append(_doodad(1, 80.0, &"large", 1))
	var loadout := Loadout.new()
	loadout.armor = true
	var w: RunWorld = sim.build_world(layout, loadout)
	var events: Array = []
	w.player.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
	await _run_until(w, 0.1, func() -> bool: return false)
	var from := Vector3(w.geo.lane_x(1), 0.6, TrackGeometry.world_z(100.0))
	w.projectiles.fire_enemy(from, Vector3(0.0, 0.0, 30.0), &"enemy_bolt", "test bolt", 4.0)
	await _run_until(w, 4.0, func() -> bool: return events.has(&"armor_hit") or events.has(&"armor_break"))
	check(events.has(&"armor_hit") or events.has(&"armor_break"), "a shot fired through a doodad still reaches the player (%s)" % [events])
	await sim.free_world(w)


## A push onto safe floor every time: in every campaign level, at 3, 5 and 6 lanes and its own speed, a
## few of its doodads are run into head-on on real physics with the level's pieces around them: the
## player is pushed once, lands in the lane beside on clear floor, and runs on safely to the level's
## spacing past it, never sinking into it.
func _test_safe_floor_every_time() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var runs: int = 0
	sim.trace = true
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(s, lanes)
			var fast: MovementTuning = config.movement_for(tuning)
			# T-SPEED: the same default build as _test_campaign above (LayoutCache).
			var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			var geo := TrackGeometry.new(lanes, fast)
			var lead: float = LevelGenerator.doodad_lead_for(fast)
			var after: float = config.spacing_seconds_hard * fast.run_speed
			var tried: int = 0
			for d: Dictionary in layout.doodads:
				if tried >= SAFE_RUNS_PER_LEVEL:
					break
				tried += 1
				var tag: String = "(%s lanes=%d, doodad at %.0f in lane %d)" % [s.id, lanes, d["start"], d["lane"]]
				var r: Dictionary = await _run_into(layout, d, fast, lead, after)
				check(r["alive"] and (r["events"] as Array).count(&"doodad_push") == 1 and r["reached"]
					and int(r["lane"]) == int(d["lane"]) + int(d["side"]),
					"pushed once onto clear floor in the lane beside, running on safely (%s, lane %d) %s" % [r["cause"], r["lane"], tag])
				var moved: Dictionary = d.duplicate()
				moved["start"] = float(d["start"]) + float(r["offset"])
				moved["end"] = float(d["end"]) + float(r["offset"])
				check(_sink(r["trace"], moved, geo, fast) <= SINK_TOLERANCE, "never sinking into it " + tag)
				runs += 1
	sim.trace = false
	check(runs >= 100, "campaign doodads run into on physics: %d" % runs)


## Runs into doodad `d` of `layout` head-on, from its lane, on a cut of the layout: every piece of every
## lane whose span reaches into the stretch from its push's lead before it to the spacing past it (the
## stretch the push and the run on after it take; by its rules nothing but the doodad stands there),
## moved to start 30 m in, at `t`'s speed. `actions` are [metres from the doodad's front (negative before
## it), action] (RunSim.run's actions, &"dash" too). The result of RunSim.run, with "reached" (the player
## got to the end of the cut) and "offset" (how far it moved).
func _run_into(layout: LevelLayout, d: Dictionary, t: MovementTuning, lead: float, after: float,
		actions: Array = []) -> Dictionary:
	var from: float = float(d["start"]) - lead
	var to: float = float(d["end"]) + after
	var offset: float = 30.0 - from
	var part := RunSim.layout(layout.lane_count, to - from + 120.0)
	var lists: Dictionary = layout.to_dict()
	var into: Dictionary = part.to_dict()
	var extent: Dictionary = {"fences": t.fence_depth * 0.5, "pads": t.pad_length, "ramps": t.ramp_length,
		"speed_pads": t.speed_pad_length}
	for key: String in ["gaps", "fences", "pads", "hulls", "ramps", "speed_pads", "signs", "doodads"]:
		for item: Dictionary in lists.get(key, []):
			var start: float = float(item.get("start", item.get("at", 0.0)))
			var end: float = float(item["end"]) if item.has("end") else start + float(extent.get(key, 0.0))
			if key == "fences":
				start -= float(extent["fences"])
			if end < from or start > to:
				continue
			var moved: Dictionary = item.duplicate()
			for k: String in ["at", "start", "end"]:
				if moved.has(k):
					moved[k] = float(moved[k]) + offset
			if key == "doodads":
				part.doodads.append(moved)
			else:
				(into[key] as Array).append(moved)
	var placed: Array = []
	for a: Array in actions:
		placed.append([float(d["start"]) + offset + float(a[0]), a[1]])
	var r: Dictionary = await sim.run(part, int(d["lane"]), (to - from + 30.0 + 2.0) / t.run_speed, placed, [], t)
	r["reached"] = float(r["distance"]) >= to + offset
	r["offset"] = offset
	return r


# --- Enemies hold back --------------------------------------------------------------------------

## GDD §3: a drone never fires a barrage at a player a doodad hems in: while doodads stand along the
## stretch its barrage would take, it keeps following and waits; past them it attacks.
func _test_drone_waits() -> void:
	var layout := RunSim.layout(3, 900.0)
	for i: int in 9:
		layout.doodads.append(_doodad(1, 60.0 + i * 40.0, &"medium", 1 if i % 2 == 0 else -1))
	var w: RunWorld = sim.build_world(layout)
	w.player.god_mode = true
	w.player.setup(w.tuning, w.geo, 0)
	var d := w.director.spawn({"type": "drone", "at": 20.0, "lane": 0, "side": 0, "seed": 7, "params": {"slot": 0}}) as DroneScript
	var wound_near: Array = [false]
	var last: float = float(layout.doodads[-1]["end"])
	await _run_until(w, 40.0, func() -> bool:
		if d.state == DroneScript.State.WINDUP and w.player.distance < last - 60.0:
			wound_near[0] = true
		return d.barrages > 0)
	check(not wound_near[0], "a drone never winds up with a doodad in its barrage's reach")
	check(d.barrages > 0 and w.player.distance > last - 70.0, "past the doodads it attacks (%d barrages, at %.0f m)"
		% [d.barrages, w.player.distance])
	await sim.free_world(w)


## GDD §3: a hover truck never charges its cannon at a player a doodad hems in; past them it fires.
func _test_truck_cannon_waits() -> void:
	var layout := RunSim.layout(3, 900.0)
	for i: int in 6:
		layout.doodads.append(_doodad(1, 40.0 + i * 40.0, &"medium", -1))
	var w: RunWorld = sim.build_world(layout)
	w.player.god_mode = true
	w.player.setup(w.tuning, w.geo, 0)
	var truck := w.director.spawn({"type": "hover_truck", "at": 0.0, "lane": 2, "side": 1, "seed": 5,
		"params": {"skip_entrance": true, "phase": "pace", "offset": 10.0, "guns": true}}) as TruckScript
	var last: float = float(layout.doodads[-1]["end"])
	var early_shot: Array = [false]
	await _run_until(w, 30.0, func() -> bool:
		if truck.cannon_shots > 0 and w.player.distance < last - 40.0:
			early_shot[0] = true
		return truck.cannon_shots > 0 or not is_instance_valid(truck))
	check(not early_shot[0], "a hover truck never fires its cannon with a doodad in the shot's reach")
	check(is_instance_valid(truck) and truck.cannon_shots > 0, "past the doodads it fires")
	await sim.free_world(w)


# --- The dash smashes a doodad (GDD §3, owner, October 8, 2026; task H5) ----------------------------

## Head-on at 3, 5 and 6 lanes, in each inner lane, both push sides, every size at 3 lanes (the small and
## the large at more): a dash that reaches a doodad smashes it once, with no push and no thud, the player
## keeping their lane (the body never leaves its middle) and their speed (the run's, plus the dash's
## bonus while it lasts: no slowdown), running on through where it stood; it breaks before the body
## touches it.
func _test_dash_head_on() -> void:
	sim.trace = true
	var runs: int = 0
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for lane: int in _inner_lanes(lanes):
			for side: int in [-1, 1]:
				for size: StringName in LevelLayout.DOODAD_SIZES:
					if lanes > 3 and size == &"medium":
						continue
					var tag: String = "(lanes=%d, lane %d, side %+d, %s)" % [lanes, lane, side, size]
					var layout := RunSim.layout(lanes)
					var d: Dictionary = _doodad(lane, 40.0, size, side)
					layout.doodads.append(d)
					var r: Dictionary = await sim.run(layout, lane, 3.2, [[32.0, &"dash"]])
					var events: Array = r["events"]
					check(r["alive"] and int(r["smashes"]) == 1 and events.count(&"doodad_smash") == 1 and int(r["pushes"]) == 0
						and not events.has(&"doodad_push"), "a dash into a doodad smashes it, once, with no push (%s) %s" % [events, tag])
					var off_lane: float = 0.0
					var slowest: float = INF
					var speed_ok: bool = true
					for s: Dictionary in r["trace"]:
						off_lane = maxf(off_lane, absf(float(s["x"]) - geo.lane_x(lane)))
						slowest = minf(slowest, float(s["speed"]))
						var expected: float = tuning.run_speed + (powerups.dash_speed_bonus if bool(s["dashing"]) else 0.0)
						speed_ok = speed_ok and absf(float(s["speed"]) - expected) < 0.001
					check(int(r["lane"]) == lane and off_lane < 0.001 and float(r["distance"]) > float(d["end"]) + 10.0,
						"the player keeps their lane, running on through where it stood (%.4f m off its middle) %s" % [off_lane, tag])
					check(speed_ok and slowest >= tuning.run_speed - 0.001,
						"and their speed: the run's, plus the dash's while it lasts (slowest %.2f m/s) %s" % [slowest, tag])
					check(_sink(_standing(r["trace"]), d, geo) <= 0.0001, "it breaks before the body touches it " + tag)
					runs += 1
	sim.trace = false
	check(runs == 34, "dashes run into doodads head-on: %d" % runs)


## From the side, consistent with "dashing into one": a dashing player switching into a doodad's side
## smashes it, and the switch goes through into its lane with no clank and no bump, beside its front, its
## middle and near its end, from either side, at 3 and 6 lanes; the body never sinks into it while it
## stands. A dashing switch whose body passes the doodad's end before it reaches its side touches nothing:
## it goes through and the doodad stands. (Without the dash the switch is blocked: _test_blocked_side.)
func _test_dash_sideways() -> void:
	sim.trace = true
	var runs: int = 0
	for lanes: int in [3, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for from: int in [1, -1]:
			var lane: int = 1 if from > 0 else lanes - 2
			var beside: int = lane + from
			var toward: StringName = &"move_left" if from > 0 else &"move_right"
			for at: float in [39.8, 43.0, 45.0, 46.4]:
				var tag: String = "(lanes=%d, from lane %d into lane %d, at %.1f m)" % [lanes, beside, lane, at]
				var layout := RunSim.layout(lanes)
				var d: Dictionary = _doodad(lane, 40.0, &"large", -from)
				layout.doodads.append(d)
				var r: Dictionary = await sim.run(layout, beside, 3.5, [[at - 2.0, &"dash"], [at, toward]])
				var events: Array = r["events"]
				var touches: bool = at < float(d["end"]) - 1.0
				check(r["alive"] and int(r["smashes"]) == (1 if touches else 0) and int(r["lane"]) == lane
					and not events.has(&"lane_blocked") and int(r["pushes"]) == 0,
					"a switch into a doodad's side while dashing goes through, smashing it where the body meets it (lane %d, %d smashed, %s) %s"
					% [r["lane"], r["smashes"], events, tag])
				check(_sink(_standing(r["trace"]), d, geo) <= 0.0001, "the body never sinks into it while it stands " + tag)
				runs += 1
	# Pushed first, then a dash and a move back into it while its push still holds it off (dash 0.1–0.5 m and
	# the move 0.2–1.0 m after the push, either first): the dash takes it, so it breaks where the body meets
	# it and the body never sinks into it. A move made before the dash, once its side is beside the runner,
	# is blocked as any runner's is (the clank and the bump; the runner stays in the push's lane, and the
	# dash smashes it if the bump touches it). A dash during the push with no move back leaves it standing:
	# the push completes (docs/OPEN_QUESTIONS.md item 640).
	var geo3 := TrackGeometry.new(3, tuning)
	var d3: Dictionary = _doodad(1, 40.0, &"medium", 1)
	var calib: Dictionary = await sim.run(_one_doodad(3, d3), 1, 3.0, [])
	var push_at: float = -1.0
	for s: Dictionary in calib["trace"]:
		if int(s["lane"]) == 2:
			push_at = float(s["d"])
			break
	check(push_at > 0.0 and int(calib["pushes"]) == 1, "the doodad pushes a runner who doesn't dash (at %.2f m)" % push_at)
	var back_in: int = 0
	for dash_after: float in [0.1, 0.3, 0.5]:
		for back_after: float in [0.2, 0.6, 1.0]:
			var tag: String = "(pushed at %.2f m, the dash %.1f m on, the move back %.1f m on)" % [push_at, dash_after, back_after]
			var actions: Array = [[push_at + dash_after, &"dash"], [push_at + back_after, &"move_left"]]
			actions.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
			var r: Dictionary = await sim.run(_one_doodad(3, d3), 1, 3.0, actions)
			if (r["events"] as Array).has(&"lane_blocked"):
				check(dash_after > back_after and r["alive"] and int(r["pushes"]) == 1 and int(r["lane"]) == 2,
					"a move back before the dash, beside it, is blocked: the runner stays in the push's lane (%d pushed, lane %d) %s"
					% [r["pushes"], r["lane"], tag])
			else:
				back_in += 1
				check(r["alive"] and int(r["pushes"]) == 1 and int(r["smashes"]) == 1 and int(r["lane"]) == 1,
					"pushed, then a dash steering back into it smashes it, back in its lane (%d pushed, %d smashed, lane %d) %s"
					% [r["pushes"], r["smashes"], r["lane"], tag])
			var sink: float = _sink(_standing(r["trace"]), d3, geo3)
			check(sink <= SINK_TOLERANCE, "the body never sinks into it while it stands (%.3f m) %s" % [sink, tag])
			runs += 1
	check(back_in >= 7, "every dash made before the move back steers back into it (%d of 9)" % back_in)
	var held: Dictionary = await sim.run(_one_doodad(3, d3), 1, 3.0, [[push_at + 0.1, &"dash"]])
	check(held["alive"] and int(held["pushes"]) == 1 and int(held["smashes"]) == 0 and int(held["lane"]) == 2
		and _sink(held["trace"], d3, geo3) <= SINK_TOLERANCE,
		"a dash started during its push leaves it standing: the push completes (lane %d, %d smashed)" % [held["lane"], held["smashes"]])
	runs += 1
	sim.trace = false
	check(runs == 26, "dashing switches into doodads' sides: %d" % runs)


## A dash that ends short of a doodad pushes as usual (GDD §3's push, at its usual moment), and one that
## lasts until the body gets there smashes it. Swept over where the dash starts, every 0.5 m from well
## before the doodad to well inside the dash's reach, at the base speed and at 25 m/s (the Golden Zone's):
## every run is a push or a smash, never both and never neither; a smash only when the dash lasted until
## the body reached the doodad, a push only when it ended before then (a frame either way); a push lands
## in the lane on its side and the body never sinks into a standing doodad; the same start runs the same
## every time.
func _test_dash_ends_short() -> void:
	sim.trace = true
	var fast: MovementTuning = tuning.duplicate() as MovementTuning
	fast.run_speed = 25.0
	for t: MovementTuning in [tuning, fast]:
		var geo := TrackGeometry.new(3, t)
		var d: Dictionary = _doodad(1, 36.0, &"medium", 1)
		var contact: float = float(d["start"]) - t.visual_size.z * 0.5
		var frame: float = (t.run_speed + powerups.dash_speed_bonus) / Engine.physics_ticks_per_second
		var length: float = _dash_length(t.run_speed)
		var smashes: int = 0
		var pushes: int = 0
		var start: float = contact - length - 5.0
		while start <= contact - length + 5.0:
			var tag: String = "(%.0f m/s, the dash from %.2f m, the body meets the doodad at %.2f m)" % [t.run_speed, start, contact]
			# A fresh layout for every run, as for every attempt: a smash marks its entry for the rest of one.
			var r: Dictionary = await sim.run(_one_doodad(3, d), 1, 3.0, [[start, &"dash"]], [], t)
			var dash_end: float = -INF
			for s: Dictionary in r["trace"]:
				if bool(s["dashing"]):
					dash_end = float(s["d"])
			var smashed: bool = int(r["smashes"]) == 1
			check(r["alive"] and int(r["smashes"]) + int(r["pushes"]) == 1,
				"a push or a smash, never both and never neither (%d smashed, %d pushed) %s" % [r["smashes"], r["pushes"], tag])
			if smashed:
				smashes += 1
				check(dash_end >= contact - 2.0 * frame, "a smash only when the dash lasted until the body got there (it ended at %.2f m) %s"
					% [dash_end, tag])
				check(int(r["lane"]) == 1 and _sink(_standing(r["trace"]), d, geo, t) <= 0.0001, "the lane kept, never touching it " + tag)
			else:
				pushes += 1
				check(dash_end < contact + frame, "a push only when the dash ended before the body got there (it ended at %.2f m) %s"
					% [dash_end, tag])
				check(int(r["lane"]) == 2 and _sink(r["trace"], d, geo, t) <= SINK_TOLERANCE,
					"pushed as usual into the lane on its side, never sinking into it (lane %d) %s" % [r["lane"], tag])
			start += 0.5
		check(smashes > 0 and pushes > 0, "both happen across the sweep (%d smashes, %d pushes at %.0f m/s)" % [smashes, pushes, t.run_speed])
		var a: Dictionary = await sim.run(_one_doodad(3, d), 1, 3.0, [[contact - length, &"dash"]], [], t)
		var b: Dictionary = await sim.run(_one_doodad(3, d), 1, 3.0, [[contact - length, &"dash"]], [], t)
		check(a["trace"] == b["trace"] and a["events"] == b["events"] and int(a["smashes"]) + int(a["pushes"]) == 1,
			"the same every attempt, at the edge of the dash's reach (%.0f m/s)" % t.run_speed)
	sim.trace = false


## The dash's reach as a claim counts it (Player._dash_reach: whether the dash lasts until the body gets to a
## doodad) is the track the dash really covers before it ends, with a speed pad's boost fading meanwhile at
## the fastest fade F6 allows (20 m/s a second), where counting the boost as if it lasted would overshoot by
## more than a metre.
func _test_dash_reach() -> void:
	var t: MovementTuning = tuning.duplicate() as MovementTuning
	t.boost_decay_per_second = 20.0
	var layout := RunSim.layout(3, 300.0)
	layout.speed_pads.append({"lane": 1, "at": 20.0})
	var w: RunWorld = sim.build_world(layout, null, t)
	var p: Player = w.player
	await _run_until(w, 3.0, func() -> bool: return p.distance >= 21.0)
	p.start_dash(powerups.dash_duration, powerups.dash_speed_bonus)
	await tree.physics_frame
	var boost: float = p._boost
	var from: float = p.distance
	var reach: float = float(p.call(&"_dash_reach"))
	var lasting: float = maxf(p.speed, 0.0) * p._dash_left
	# The dash ends within a frame: a frame's run at the dash's speed either way.
	var frame: float = maxf(p.speed, 0.0) / Engine.physics_ticks_per_second
	await _run_until(w, 1.0, func() -> bool: return not p.dashing)
	var covered: float = p.distance - from
	check(boost > 3.0 and absf(covered - reach) <= frame,
		"the dash's reach counts the boost fading: %.2f m counted, %.2f m covered (a %.1f m/s boost)" % [reach, covered, boost])
	check(lasting - covered > 2.0 * frame, "where a lasting boost would count %.2f m" % lasting)
	await sim.free_world(w)


## Every DashBreakable built under `node` (the track's doodads).
func _breakables(node: Node) -> Array[DashBreakable]:
	var out: Array[DashBreakable] = []
	for child: Node in node.find_children("*", "Area3D", true, false):
		if child is DashBreakable:
			out.append(child as DashBreakable)
	return out


## The built doodad for layout entry `d` under `node`, or null.
func _breakable_for(node: Node, d: Dictionary) -> DashBreakable:
	for b: DashBreakable in _breakables(node):
		if is_same(b.entry, d):
			return b
	return null


## True if anything on the doodad's, lane blocker's or floor layers is where doodad `d` stands (above
## the floor itself) in `w`.
func _solid_at(w: RunWorld, d: Dictionary) -> bool:
	var box: Vector3 = w.tuning.doodad_size(StringName(d["size"]))
	var shape := BoxShape3D.new()
	shape.size = Vector3(box.x, box.y - 0.4, float(d["end"]) - float(d["start"]))
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.collision_mask = TrackBuilder.LAYER_DOODAD | TrackBuilder.LAYER_LANE_BLOCKER | TrackBuilder.LAYER_FLOOR
	q.transform = Transform3D(Basis.IDENTITY, Vector3(w.geo.lane_x(int(d["lane"])), 0.3 + shape.size.y * 0.5,
		TrackGeometry.world_z((float(d["start"]) + float(d["end"])) * 0.5)))
	return not w.player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## In a full world in the City's look, carrying the dash (and the armor and a shield): a dash into a
## doodad smashes it there too. Its body, lane blocker and standable top are gone (nothing on their
## layers where it stood; hidden; its layout entry marked), the crunch plays (doodad_smash), its pieces fly
## (RunEffects.rubble) in its look's own colours (DashBreakable.debris_colors, from the skin), lit and never
## glowing, gone within their life, and a light shake asks for SpeedFxTuning's smash strength, none with
## Screen shake off; nothing protective is used up, there's no hit and no score; Reduced flashing changes
## nothing (nothing in it flashes). A dash still bumps off a solid side that isn't a doodad's.
func _test_dash_world() -> void:
	var layout := RunSim.layout(3, 400.0)
	var first: Dictionary = _doodad(1, 60.0, &"medium", 1)
	var second: Dictionary = _doodad(1, 160.0, &"small", -1)
	layout.doodads.append(first)
	layout.doodads.append(second)
	var loadout := Loadout.new()
	loadout.tiers[&"dash"] = 4
	var config := LevelConfig.new()
	var city := load("res://data/skins/city_skin.tres") as ZoneSkin
	config.skin = city
	var w: RunWorld = sim.build_world(layout, loadout, null, config)
	# The pieces' look is drawn while the level loads (ShaderWarmup samples the hidden pool), never first
	# in the frame of a smash.
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	var stage := ShaderWarmup.new()
	stage.setup(w, camera)
	check(stage.keys.has("multimesh10|ArrayMesh|%s" % ShaderWarmup.shader_key(MeshKit.solid())),
		"the warm-up draws the pieces' look while the level loads")
	stage.queue_free()
	camera.queue_free()
	await tree.process_frame
	var p: Player = w.player
	p.armor = 1
	p.shield = 1
	var fx: SpeedFxTuning = w.effects.tuning
	var smashed: Array[DashBreakable] = []
	var sounds: Array[StringName] = []
	var shakes: Array[float] = []
	var events: Array[StringName] = []
	p.smashed.connect(func(b: DashBreakable) -> void: smashed.append(b))
	w.sounds.requested.connect(func(s: StringName) -> void: sounds.append(s))
	w.effects.shake_requested.connect(func(strength: float, _duration: float) -> void: shakes.append(strength))
	p.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
	await _run_until(w, 5.0, func() -> bool: return p.distance >= 50.0)
	var body: DashBreakable = _breakable_for(w.track, first)
	check(body != null and body.collision_layer == TrackBuilder.LAYER_DOODAD | TrackBuilder.LAYER_LANE_BLOCKER and _solid_at(w, first)
		and not body.debris_colors.is_empty(), "the doodad stands, built as a DashBreakable with its look's colours")
	if body == null:
		await sim.free_world(w)
		return
	var score: int = w.score.score
	var kills: int = w.score.kills
	check(bool(w.powerups.call(&"try_dash")), "the dash starts")
	await _run_until(w, 2.0, func() -> bool: return not smashed.is_empty())
	check(smashed.size() == 1 and smashed[0] == body and body.is_smashed() and bool(first.get("smashed", false)),
		"the dash smashes it: its node, its layout entry marked")
	var tops: Array[Node] = body.find_children("*", "StaticBody3D", false, false)
	check(body.collision_layer == 0 and tops.size() == 1 and (tops[0] as StaticBody3D).collision_layer == 0
		and not body.visible and not _solid_at(w, first), "its body, lane blocker and standable top are gone, and its look")
	check(events.count(&"doodad_smash") == 1 and sounds.count(&"doodad_smash") == 1 and not events.has(&"doodad_push"),
		"the crunch plays, once, and no push (%s)" % [events])
	var bursts: Array[RubbleBurst] = w.effects.rubble_active()
	check(bursts.size() == 1, "its pieces fly (%d bursts)" % bursts.size())
	if bursts.size() == 1:
		var burst: RubbleBurst = bursts[0]
		var lit: bool = burst.material_override == MeshKit.solid() and burst.count >= RubbleBurst.MIN_PIECES
		var own: bool = true
		for i: int in burst.count:
			var c: Color = burst.piece_colors[i]
			lit = lit and c.a == 0.0
			var found: bool = false
			for o: Color in body.debris_colors:
				var k: float = c.r / maxf(o.r, 0.0001)
				found = found or (k >= 0.84 and k <= 1.09 and absf(c.g - o.g * k) < 0.002 and absf(c.b - o.b * k) < 0.002)
			own = own and found
		check(lit, "lit pieces on the kit's solid material, never glowing (%d pieces)" % burst.count)
		check(own, "in the doodad's own colours, a shade either way (%s)" % [body.debris_colors])
	check(body.debris_colors == city.doodad_debris_colors(body, &"medium", 1, int(first["seed"])),
		"its colours are the skin's for its look (ZoneSkin.doodad_debris_colors)")
	check(shakes.has(fx.smash_shake_strength) and fx.smash_shake_strength < 0.32,
		"a light shake (%.2f, under a dash kill's): %s" % [fx.smash_shake_strength, shakes])
	check(p.alive and p.armor == 1 and p.shield == 1 and p.invulnerable_left == 0.0 and not events.has(&"armor_hit")
		and not events.has(&"shield_break"), "no damage: nothing protective used up, no hit")
	check(w.score.score == score and w.score.kills == kills, "and no score (%d, %d kills)" % [w.score.score, w.score.kills])
	await _run_until(w, fx.rubble_life + 0.2, func() -> bool: return false)
	check(w.effects.rubble_active().is_empty(), "the pieces are gone within their life")
	# The second, with Screen shake off and Reduced flashing on: the pieces fly the same, with no shake.
	w.effects.shake_scale = 0.0
	p.steady_flash = true
	var shaken: int = shakes.size()
	await _run_until(w, 8.0, func() -> bool: return p.distance >= 150.0)
	check(bool(w.powerups.call(&"try_dash")), "the dash is back for the second")
	await _run_until(w, 2.0, func() -> bool: return smashed.size() == 2)
	check(smashed.size() == 2 and w.effects.rubble_active().size() == 1 and shakes.size() == shaken,
		"with Screen shake off it shakes nothing, and with Reduced flashing its pieces fly as before (%d smashed)" % smashed.size())
	# Another solid side (a hover truck's) still blocks a dashing player: the clank and the bump.
	var blocker := Area3D.new()
	blocker.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER
	blocker.collision_mask = 0
	blocker.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.0, 30.0)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = Vector3(w.geo.lane_x(2), 1.0, TrackGeometry.world_z(250.0))
	w.track.add_child(blocker)
	await _run_until(w, 8.0, func() -> bool: return p.distance >= 240.0)
	check(bool(w.powerups.call(&"try_dash")), "the dash is back for the third")
	await _run_until(w, 0.1, func() -> bool: return false)
	p.press(&"move_right")
	await _run_until(w, 0.5, func() -> bool: return false)
	check(p.lane == 1 and events.has(&"lane_blocked") and p.alive, "a dash still bumps off a solid side that isn't a doodad's (lane %d)" % p.lane)
	await sim.free_world(w)


## It stays smashed for the rest of the attempt, and a retry rebuilds it whole. A quick run of City 2 at
## 3 lanes (its own seed, the dash carried; god mode and no falls, since the runner just keeps to the
## middle lane, where every doodad stands at 3 lanes) dashes into its first doodad. Through a death and a
## revive it stays smashed (its entry marked, nothing on its layers where it stood). LevelRun's retry
## generates the level again: the very same layout as before the smash, that doodad whole on the track,
## and a runner who doesn't dash is pushed by it.
func _test_dash_retry() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.config = campaign.configure(campaign.step("city/2"), 3)
	ctx.tuning = tuning
	ctx.loadout = Loadout.new()
	ctx.loadout.tiers[&"dash"] = 4
	ctx.god_mode = true
	ctx.no_fall = true
	var run := LevelRun.new()
	tree.root.add_child(run)
	run.start(ctx)
	var before: String = JSON.stringify(run.world.layout.to_dict())
	check(not run.world.layout.doodads.is_empty(), "City 2 has doodads at 3 lanes")
	if run.world.layout.doodads.is_empty():
		run.queue_free()
		await tree.process_frame
		return
	var d: Dictionary = run.world.layout.doodads[0]
	var w: RunWorld = run.world
	var limit: float = float(d["start"]) / w.tuning.run_speed + 6.0
	await _run_until(w, limit, func() -> bool: return w.player.distance >= float(d["start"]) - 8.0)
	check(w.player.lane == int(d["lane"]) and w.player.surface == Player.Surface.FLOOR, "the runner comes up to it in its lane")
	w.powerups.call(&"try_dash")
	await _run_until(w, 2.0, func() -> bool: return w.player.smashes > 0)
	var body: DashBreakable = _breakable_for(w.track, d)
	check(w.player.smashes == 1 and body != null and body.is_smashed() and not _solid_at(w, d), "the dash smashes it")
	w.player._die("test hazard")
	await _run_until(w, 0.1, func() -> bool: return false)
	check(run.state == LevelRun.State.DEAD, "the runner dies")
	run.revive()
	await _run_until(w, 0.5, func() -> bool: return false)
	check(run.state == LevelRun.State.RUNNING and w.player.alive and bool(d.get("smashed", false)) and not _solid_at(w, d)
		and (body == null or body.collision_layer == 0), "through a death and a revive it stays smashed: nothing builds it again")
	run.restart(run.context.retry())
	await tree.physics_frame
	w = run.world
	var again: Dictionary = w.layout.doodads[0]
	check(JSON.stringify(w.layout.to_dict()) == before and not again.has("smashed"),
		"a retry generates the very same level, the doodad whole in its data")
	await _run_until(w, limit, func() -> bool: return w.player.distance >= float(again["start"]) - 8.0)
	var rebuilt: DashBreakable = _breakable_for(w.track, again)
	check(rebuilt != null and not rebuilt.is_smashed() and rebuilt.visible
		and rebuilt.collision_layer == TrackBuilder.LAYER_DOODAD | TrackBuilder.LAYER_LANE_BLOCKER and _solid_at(w, again),
		"and on the track: built whole, on its layers")
	await _run_until(w, 2.0, func() -> bool: return w.player.distance >= float(again["end"]) + 2.0)
	check(w.player.pushes == 1 and w.player.smashes == 0, "a runner who doesn't dash is pushed by it (%d pushes)" % w.player.pushes)
	run.queue_free()
	await tree.process_frame


## Every skin names its doodads' colours for their pieces (ZoneSkin.doodad_debris_colors): the main lit
## colours of the look's own meshes (each one a colour of a face that doesn't glow), a few a mesh, the
## same every time it's dressed; a look that tags none falls back to the skin's doodad_palette.
func _test_debris_colors() -> void:
	var skins: Array[ZoneSkin] = [GreyboxSkin.new()]
	var names: PackedStringArray = ["grey box"]
	for file: String in DirAccess.get_files_at("res://data/skins"):
		var skin_path: String = "res://data/skins".path_join(file)
		if file.ends_with(".tres") and load(skin_path) is ZoneSkin:
			skins.append(load(skin_path) as ZoneSkin)
			names.append(file)
	for i: int in skins.size():
		var skin: ZoneSkin = skins[i]
		for size: StringName in LevelLayout.DOODAD_SIZES:
			for look_seed: int in [3, 11]:
				var tag: String = "(%s, %s, seed %d)" % [names[i], size, look_seed]
				var box: Vector3 = tuning.doodad_size(size)
				var body := Node3D.new()
				skin.doodad(body, box, size, 1, look_seed)
				var colors: PackedColorArray = skin.doodad_debris_colors(body, size, 1, look_seed)
				# The look's lit vertex colours, as the mesh keeps them (8 bits a channel: within a step).
				var own: Dictionary = {}
				var meshes: int = 0
				for node: Node in body.find_children("*", "MeshInstance3D", true, false):
					var mesh: Mesh = (node as MeshInstance3D).mesh
					meshes += 1
					for surface: int in mesh.get_surface_count():
						for c: Color in mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:
							if c.a == 0.0:
								own[Color(c.r, c.g, c.b)] = true
				var inside: bool = true
				for c: Color in colors:
					var found: bool = false
					for o: Color in own:
						found = found or (absf(o.r - c.r) < 0.0045 and absf(o.g - c.g) < 0.0045 and absf(o.b - c.b) < 0.0045)
					inside = inside and found
				check(not colors.is_empty() and colors.size() <= ZoneSkin.DEBRIS_COLORS_MAX * maxi(meshes, 1) and inside,
					"its pieces take its look's own lit colours (%d of them) %s" % [colors.size(), tag])
				var twin := Node3D.new()
				skin.doodad(twin, box, size, 1, look_seed)
				check(skin.doodad_debris_colors(twin, size, 1, look_seed) == colors, "the same every time " + tag)
				body.free()
				twin.free()
	var bare := Node3D.new()
	var inst := MeshInstance3D.new()
	inst.mesh = BoxMesh.new()
	bare.add_child(inst)
	var plain := ZoneSkin.new()
	check(plain.doodad_debris_colors(bare, &"small", 1, 0) == plain.doodad_palette, "a look that tags none falls back to the doodad palette")
	bare.free()


## Campaign doodads dashed through on real physics: in every campaign level at 3, 5 and 6 lanes and its
## own speed, its first few doodads run into from their lane on a cut of the level (_run_into), with a
## dash started 6 m before, just ahead of where the push would come (so the runner comes through as fast
## as a dash goes): each smashed once, no push, the lane kept, the body never touching it, the runner on
## safely to the level's spacing past it.
func _test_dash_campaign() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var runs: int = 0
	sim.trace = true
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(s, lanes)
			var fast: MovementTuning = config.movement_for(tuning)
			var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			var geo := TrackGeometry.new(lanes, fast)
			var lead: float = LevelGenerator.doodad_lead_for(fast)
			var after: float = config.spacing_seconds_hard * fast.run_speed
			var tried: int = 0
			for d: Dictionary in layout.doodads:
				if tried >= DASH_RUNS_PER_LEVEL:
					break
				tried += 1
				var tag: String = "(%s lanes=%d, doodad at %.0f in lane %d)" % [s.id, lanes, d["start"], d["lane"]]
				var r: Dictionary = await _run_into(layout, d, fast, lead, after, [[-6.0, &"dash"]])
				check(r["alive"] and int(r["smashes"]) == 1 and int(r["pushes"]) == 0 and r["reached"] and int(r["lane"]) == int(d["lane"]),
					"dashed through: smashed once, no push, on safely in its lane (%s, %d smashed, lane %d) %s"
					% [r["cause"], r["smashes"], r["lane"], tag])
				var moved: Dictionary = d.duplicate()
				moved["start"] = float(d["start"]) + float(r["offset"])
				moved["end"] = float(d["end"]) + float(r["offset"])
				check(_sink(_standing(r["trace"]), moved, geo, fast) <= 0.0001, "never touching it while it stood " + tag)
				runs += 1
	sim.trace = false
	check(runs >= 60, "campaign doodads dashed through on physics: %d" % runs)


## The first of `spans` ([from, to] on the track) that a runner coming through doodad `d` meets at or after
## its front: its start (the doodad's front if it reaches back over it), or INF if none.
static func _first_from(spans: Array[Vector2], d: Dictionary) -> float:
	var front: float = float(d["start"])
	var first: float = INF
	for s: Vector2 in spans:
		if s.y < front:
			continue
		first = minf(first, maxf(s.x, front))
	return first


## Fairness for a runner who dashes through (task H5). A doodad is 2.6 m tall and hides its own lane right
## behind it, which a runner it pushes never reaches in that lane; a dash shows it only at the smash, and
## goes on at the dash's speed. For every doodad of every campaign level at 3, 5 and 6 lanes (its own
## build), the first thing that could catch a runner after it: in its lane (a hole, a wider gap among them,
## a fence, a pad, a speed pad, a floor cut's lane window, an enemy standing in its lane), and in any lane
## (what the fill pass counts as going on: every piece, each enemy's stretch as its rules keep it, a floor
## cut's whole window; a ceiling to the end of its landing zone; what the rules keep doodads off, a Bad
## Dream's chase, but not their calm stretches: an Enforcer Truck's showing window holds nothing that could catch
## a runner, task C6c). The seconds from its front (where the smash shows what it hid) to there at the dash's
## speed (the run's plus the dash's bonus, the fastest a runner comes through it) must leave a reaction
## (REACTION) and a lane switch (MovementTuning.lane_switch_time); and so must the seconds from its end, for
## a runner who dashed into its side near its end (_test_dash_sideways), the latest a smash can show it.
## Prints the spread at each lane count.
func _test_dash_fairness() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for lanes: int in [3, 5, 6]:
		var lane_times: Array[float] = []
		var any_times: Array[float] = []
		var side_times: Array[float] = []
		var worst: String = ""
		var worst_time: float = INF
		var need: float = REACTION + tuning.lane_switch_time
		for s: CampaignStep in campaign.steps():
			if not s.is_level():
				continue
			var config: LevelConfig = campaign.configure(s, lanes)
			var fast: MovementTuning = config.movement_for(tuning)
			var patterns: Array = LevelGenerator.load_for(config)
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, patterns)
			var layout: LevelLayout = gen.layout
			need = REACTION + fast.lane_switch_time
			var dash_speed: float = fast.run_speed + powerups.dash_speed_bonus
			var every: Array[Vector2] = []
			for k: Vector2 in gen.fill_keep_outs(patterns)["activity"]:
				every.append(k)
			for h: Dictionary in layout.hulls:
				every.append(Vector2(float(h["start"]), gen.zones.landing_zone(h).y))
			for k: Dictionary in gen.rules_doodad_keep_outs():
				# A calm stretch (an Enforcer Truck's showing window, task C6c) holds nothing that could catch a runner.
				if not k.has("lane") and not bool(k.get("calm", false)):
					every.append(Vector2(float(k["from"]), float(k["to"])))
			var half: float = fast.fence_depth * 0.5
			for d: Dictionary in layout.doodads:
				var lane: int = int(d["lane"])
				var mine: Array[Vector2] = []
				for g: Dictionary in layout.gaps:
					if int(g["lane"]) == lane:
						mine.append(Vector2(float(g["start"]), float(g["end"])))
				for f: Dictionary in layout.fences:
					if int(f["lane"]) == lane:
						mine.append(Vector2(float(f["at"]) - half, float(f["at"]) + half))
				for p: Dictionary in layout.pads:
					if int(p["lane"]) == lane:
						mine.append(Vector2(float(p["at"]), float(p["at"]) + fast.pad_length))
				for p: Dictionary in layout.speed_pads:
					if int(p["lane"]) == lane:
						mine.append(Vector2(float(p["at"]), float(p["at"]) + fast.speed_pad_length))
				for c: Dictionary in layout.cuts:
					if int(c["lane"]) == lane:
						mine.append(FloorCutPlan.lane_window(c))
				for e: Dictionary in layout.enemies:
					if int(e.get("lane", -1)) == lane:
						var span: Vector2 = LevelGenerator.enemy_floor_span(e, fast.pace())
						if span.y >= span.x:
							mine.append(span)
				var in_lane: float = (_first_from(mine, d) - float(d["start"])) / dash_speed
				var all: Array[Vector2] = every.duplicate()
				all.append_array(mine)
				var anywhere: float = (_first_from(all, d) - float(d["start"])) / dash_speed
				var from_end: float = (_first_from(all, d) - float(d["end"])) / dash_speed
				var tag: String = "(%s lanes=%d, doodad at %.0f in lane %d)" % [s.id, lanes, d["start"], lane]
				check(in_lane >= need and anywhere >= need,
					"a runner who dashes through has time to see what it hid and move: the next thing in its lane %.2f s on, in any lane %.2f s, at the dash's speed (a reaction and a switch take %.2f s) %s"
					% [in_lane, anywhere, need, tag])
				check(from_end >= need, "and one who dashed into its side by its end: %.2f s on %s" % [from_end, tag])
				if in_lane < INF:
					lane_times.append(in_lane)
				any_times.append(anywhere)
				side_times.append(from_end)
				if anywhere < worst_time:
					worst_time = anywhere
					worst = tag
		lane_times.sort()
		any_times.sort()
		side_times.sort()
		check(not any_times.is_empty() and not lane_times.is_empty(), "campaign doodads measured at %d lanes" % lanes)
		if any_times.is_empty() or lane_times.is_empty():
			continue
		print("  dashing through doodads at %d lanes (%d doodads): the next thing in its lane %.2f s after its front at the least (median %.2f s), in any lane %.2f s (median %.2f s, %s), from its end %.2f s; a reaction and a switch take %.2f s"
			% [lanes, any_times.size(), lane_times[0], lane_times[lane_times.size() / 2], any_times[0], any_times[any_times.size() / 2],
			worst, side_times[0], need])
