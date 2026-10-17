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
## - Rows (task L3, the owner, October 17, 2026: "occasionally ... rows of similar doodads"): placed over many seeds
##   at 3, 5 and 6 lanes with both spacings, every length and size class, each a row of one kind (one look) in one
##   lane checked where it stands (LayoutChecks.check_doodads, check_row); none with their chance at 0; the enemies'
##   checks see a row from its first front to its last end; the track dresses a row in its one look; on real physics
##   a row pushes once and its sides block a switch all along it, and the dash smashes every one it reaches, the next
##   one pushing as usual where the dash ends; campaign rows run into and dashed into.
## - The lane by a side wall (task L3, the owner's held October 9 request): doodads take it where the wall is open
##   (LayoutChecks.check_wall_lane_doodad; never with the share at 0), wall fences and side wall gaps keep off them;
##   on real physics a wall runner low on that wall breaks one as they reach it (no push, no damage, the wall run
##   goes on, the body never inside it), one high enough passes over it standing, a floor runner in its lane is
##   pushed inward, and a switch into its side from the next lane is blocked.

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
	_test_rows()
	_test_wall_lane()
	_test_campaign()
	_test_keep_outs()
	await _test_track()
	await _test_row_track()
	_test_skins()
	_test_cards()
	await _test_push()
	await _test_push_holds()
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
	await _test_row_push()
	await _test_dash_row()
	await _test_wall_runner()
	await _test_wall_lane_floor()
	await _test_campaign_rows()


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
## both builds leave them out: what's compared is the doodads' own doing. A treasure stash's walls (task I4) come with
## the stash, whatever the share, in both builds alike.
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
			# A treasure stash's walls (task I4) are the stash's own, placed by its rules whatever the share.
			var zone_doodads: int = 0
			for d: Dictionary in plain.doodads:
				zone_doodads += 0 if d.has("stash") else 1
			check(zone_doodads == 0 and (plain.doodads.is_empty() or not plain.stashes.is_empty())
				and (plain.doodads.is_empty() == not plain.to_dict().has("doodads")), "a share of 0 places no zone doodad " + tag)
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
## built feature, at the highest share; deterministic; both sides, every lane (the outermost ones by an open side
## wall, task L3) and every size.
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
		# Task L3: the outermost lanes too, by an open side wall (LayoutChecks.check_wall_lane_doodad).
		check(lanes_used.size() == lanes, "in every lane, the ones by the side walls too (%s)" % [lanes_used.keys()])
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


## The rows of `layout`'s doodads (task L3: LevelLayout.doodads `row`), each its doodads in order.
static func _rows_of(layout: LevelLayout) -> Array[Array]:
	var by: Dictionary = {}
	var out: Array[Array] = []
	for d: Dictionary in layout.doodads:
		if not d.has("row"):
			continue
		var key: String = var_to_str(d["row"])
		if not by.has(key):
			by[key] = []
			out.append(by[key])
		(by[key] as Array).append(d)
	for row: Array in out:
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	return out


## Rows (task L3, the owner, October 17, 2026: "occasionally ... rows of similar doodads: three plant doodads one
## right after the other, or three market stalls, one followed by a space ..."; LevelGenerator._row_shape): with every
## doodad the first of a row (doodad_row_chance 1), in quick play's level at 3, 5 and 6 lanes over seeds and
## difficulties, with and without every built feature: rows of every length from two to four, both spacings and every
## size class stand, each where it's fair (check_layout's check_doodads and check_row), in inner lanes and by the side
## walls, deterministic, no warnings; with the chance at 0 no doodad is in a row or carries a row's keys.
func _test_rows() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	for lanes: int in [3, 5, 6]:
		var lengths: Dictionary = {}
		var spacings: Dictionary = {}
		var sizes: Dictionary = {}
		var where: Dictionary = {}
		var rows: int = 0
		var singles_left: bool = true
		for every: bool in [false, true]:
			for difficulty: float in [0.0, 1.0]:
				for level_seed: int in range(1, 9):
					var config: LevelConfig = base.duplicate() as LevelConfig
					config.lane_count = lanes
					config.difficulty = difficulty
					config.level_seed = level_seed
					config.doodad_share = 1.0
					config.doodad_row_chance = 1.0
					if every:
						config.features = EVERY_FEATURE
						config.enemy_scaling = difficulty
					var tag: String = "rows lanes=%d diff=%.1f seed=%d%s" % [lanes, difficulty, level_seed, " every feature" if every else ""]
					var patterns: Array = LevelGenerator.load_for(config)
					var gen := LevelGenerator.new()
					var layout: LevelLayout = gen.generate(config, tuning, patterns)
					check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
					var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
					check(JSON.stringify(again.to_dict()) == JSON.stringify(layout.to_dict()), "deterministic, rows and all " + tag)
					LayoutChecks.check_layout(self, layout, config, tag)
					for row: Array in _rows_of(layout):
						rows += 1
						lengths[row.size()] = true
						var space: float = float((row[1] as Dictionary)["start"]) - float((row[0] as Dictionary)["end"])
						spacings["touching" if absf(space - LevelGenerator.DOODAD_ROW_TOUCH) < 0.01 else "spaced"] = true
						sizes[StringName((row[0] as Dictionary)["size"])] = true
						var lane: int = int((row[0] as Dictionary)["lane"])
						where["by a wall" if lane == 0 or lane == lanes - 1 else "inner"] = true
					var off: LevelConfig = config.duplicate() as LevelConfig
					off.doodad_row_chance = 0.0
					var plain: LevelLayout = LevelGenerator.new().generate(off, tuning, patterns)
					for d: Dictionary in plain.doodads:
						singles_left = singles_left and not d.has("row") and not d.has("look")
		check(rows > 0 and lengths.has(2) and lengths.has(3) and lengths.has(4),
			"at %d lanes rows of two, three and four stand (%d rows: %s)" % [lanes, rows, lengths.keys()])
		check(spacings.size() == 2, "one right after the other and a doodad's length apart (%s)" % [spacings.keys()])
		check(sizes.size() == LevelLayout.DOODAD_SIZES.size(), "in every size class (%s)" % [sizes.keys()])
		check(where.size() == 2, "in inner lanes and by the side walls (%s)" % [where.keys()])
		check(singles_left, "with the row chance at 0 no doodad is in a row (lanes=%d)" % lanes)


## The lane by a side wall (task L3, the owner, October 9, 2026: "doodads prefer the lane next to the side wall when
## it's open, without costing gameplay: not where the generator already has something on that part of the wall or
## needs it open"; LevelGenerator.wall_lane_keep_outs), in quick play's level with what puts something on or by a wall
## (ramps and the patterns' signs, window cyborgs, wall vents' screeches, hover trucks, wall fences full and partial,
## side wall gaps, wall-run gaps, dash walls), at 3, 5 and 6 lanes over seeds and difficulties, with doodads in every
## stretch with room and rows now and then: doodads stand by both walls, each where the wall is open
## (check_layout: check_doodads' check_wall_lane_doodad, and check_wall_fences, whose drop windows keep off them),
## deterministic, no warnings; and the share draws: none by a wall with it at 0, most with it at 1.
func _test_wall_lane() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var walls: PackedStringArray = ["ramps", "ceilings", "cyborg", "window_cyborg", "screech", "screech_vents", "hover_truck",
		"wall_fences", "wall_fences_partial", "wall_gaps", "wall_run_gaps", "dash_wall", "octodog", "drone"]
	var by_share: Dictionary = {}
	for lanes: int in [3, 5, 6]:
		var sides: Dictionary = {}
		for share: float in [0.0, 0.6, 1.0]:
			var outer: int = 0
			var total: int = 0
			for difficulty: float in [0.2, 0.8]:
				for level_seed: int in range(1, 7):
					var config: LevelConfig = base.duplicate() as LevelConfig
					config.lane_count = lanes
					config.difficulty = difficulty
					config.level_seed = level_seed
					config.features = walls
					config.enemy_scaling = difficulty
					config.dash_walls = 2
					config.doodad_share = 1.0
					config.doodad_wall_lane_share = share
					var tag: String = "wall lane share=%.1f lanes=%d diff=%.1f seed=%d" % [share, lanes, difficulty, level_seed]
					var patterns: Array = LevelGenerator.load_for(config)
					var gen := LevelGenerator.new()
					var layout: LevelLayout = gen.generate(config, tuning, patterns)
					check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
					if share == 1.0 and level_seed <= 2:
						var again: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
						check(JSON.stringify(again.to_dict()) == JSON.stringify(layout.to_dict()), "deterministic " + tag)
					LayoutChecks.check_layout(self, layout, config, tag)
					for d: Dictionary in layout.doodads:
						if d.has("stash"):
							continue
						total += 1
						var lane: int = int(d["lane"])
						if lane == 0 or lane == lanes - 1:
							outer += 1
							sides[-1 if lane == 0 else 1] = true
			by_share["%d %.1f" % [lanes, share]] = [outer, total]
			if share == 0.0:
				check(outer == 0, "with the share at 0 no doodad stands by a wall (lanes=%d: %d of %d)" % [lanes, outer, total])
		var low: Array = by_share["%d 0.6" % lanes]
		var high: Array = by_share["%d 1.0" % lanes]
		check(int(high[0]) > int(low[0]) and int(high[0]) * 2 > int(high[1]),
			"the share draws: more stand by a wall at 1 than at 0.6, most of them (lanes=%d: %d of %d, %d of %d)"
			% [lanes, high[0], high[1], low[0], low[1]])
		check(sides.size() == 2, "by both walls (lanes=%d)" % lanes)
		print("  doodads by a side wall at %d lanes: %d of %d at the share 0.6, %d of %d at 1" % [lanes, low[0], low[1],
			high[0], high[1]])


## Every campaign level has doodads at 3, 5 and 6 lanes, each checked where it stands (test_campaign
## checks them all, with every other rule); City 1 introduces them gently: none before its start, and
## no large one.
func _test_campaign() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var total: int = 0
	# Task L3: the campaign's rows and doodads by a side wall.
	var rows: int = 0
	var in_rows: int = 0
	var by_wall: int = 0
	for s: CampaignStep in campaign.steps():
		# A mini-game level (the Beach's volleyball match) isn't generated: no doodads.
		if not s.is_level() or s.is_minigame():
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
			for row: Array in _rows_of(layout):
				rows += 1
				in_rows += row.size()
			for d: Dictionary in layout.doodads:
				by_wall += 1 if not d.has("stash") and (int(d["lane"]) == 0 or int(d["lane"]) == lanes - 1) else 0
			if s.id == "city/1":
				for d: Dictionary in layout.doodads:
					check(float(d["start"]) >= config.doodad_start * layout.length - 0.01 and StringName(d["size"]) != &"large",
						"City 1 brings in its doodads gently: from a fifth of the way in, never a large one " + tag)
				var minutes: float = layout.length / gen.speed / 60.0
				check(layout.doodads.size() / minutes <= 6.0, "and a few a minute at most (%.1f) %s" % [layout.doodads.size() / minutes, tag])
		check(level_total > 0, "%s has doodads over its lane counts (%d)" % [s.id, level_total])
	print("  %d doodads in the campaign's levels at 3, 5 and 6 lanes: %d rows holding %d of them, %d by a side wall"
		% [total, rows, in_rows, by_wall])
	# Task L3: rows come now and then (the owner: "occasionally"), never most of the doodads; and doodads take the
	# lane by an open side wall.
	check(rows > 0 and in_rows * 2 < total, "the campaign has rows now and then (%d rows, %d of %d doodads)" % [rows, in_rows, total])
	check(by_wall > 0, "and doodads by the side walls (%d of %d)" % [by_wall, total])


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
	# Task L3: a row counts from its first one's front to its last one's end, the space between them too, in every
	# check that counts doodads (LevelLayout.doodad_between, doodad_extent).
	var r := RunSim.layout(3)
	var length: float = tuning.doodad_large_length
	for i: int in 3:
		var d: Dictionary = _doodad(1, 100.0 + i * 2.0 * length, &"large", 1)
		d["row"] = [100.0, 100.0 + 5.0 * length]
		d["look"] = 3
		r.doodads.append(d)
	# Inside the space between its first two, clear of both by more than the checks' own metre.
	var space := Vector2(100.0 + length + 2.0, 100.0 + 2.0 * length - 2.0)
	check(r.doodad_between(space.x, space.y) and r.doodad_between(space.x, space.y, 1) and not r.doodad_between(space.x, space.y, 0),
		"a spaced row stands in its lane all along, the space between its doodads too (doodad_between)")
	check(not Octodog.window_clear(r, space.x, space.y) and not Resonator.pulse_clear(r, zones, space.x + 1.0, space),
		"an Octodog never charges and a Resonator's wave never meets the player in a row's space")
	check(CyborgRules.obstacle_spans(r, tuning, zones).has(Vector2(100.0, 100.0 + 5.0 * length)),
		"a cyborg's walk and panic run keep their margin from a whole row")
	check(LevelLayout.doodad_extent(r.doodads[1]) == Vector2(100.0, 100.0 + 5.0 * length)
		and LevelLayout.doodad_extent(l.doodads[0]) == Vector2(100.0, 100.0 + length), "a doodad's extent: its row's, or its own")


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


## A row on the track (task L3): each of its doodads its own body and box (one right after the other, two boxes stand
## LevelGenerator.DOODAD_ROW_TOUCH apart, so their faces and the pictures on them never lie in one plane), each
## dressed with the row's look (`look`, its first one's seed: one kind all along it, where their own seeds would pick
## different pictures), the same mesh in a zone with picture cards (the Marketplace's small class: a potted palm or a
## flowering bush).
func _test_row_track() -> void:
	var lanes: int = 5
	var layout := RunSim.layout(lanes, 300.0)
	var length: float = tuning.doodad_small_length
	var step: float = length + LevelGenerator.DOODAD_ROW_TOUCH
	var cards := DoodadCards.for_zone("marketplace")
	# A look seed whose own seeds after it would pick another picture, so one look is what keeps the row one kind.
	var look: int = 0
	var mixed: bool = false
	while not mixed and look < 200:
		look += 1
		for i: int in range(1, 3):
			mixed = mixed or String(cards.design(&"small", look + i).get("name", "")) != String(cards.design(&"small", look).get("name", ""))
	check(mixed, "the Marketplace's small doodads have more than one picture to pick from")
	for i: int in 3:
		var d: Dictionary = _doodad(lanes - 1, 30.0 + i * step, &"small", -1)
		d["seed"] = look + i
		d["look"] = look
		d["row"] = [30.0, 30.0 + 2.0 * step + length]
		layout.doodads.append(d)
	var root := Node3D.new()
	tree.root.add_child(root)
	var track := TrackBuilder.new()
	root.add_child(track)
	var skin := RecordingSkin.new()
	track.set_layout(layout, tuning, skin)
	track.update(0.0, 0.0)
	await tree.physics_frame
	var boxes: Array[Vector2] = []
	for node: Node in track.find_children("*", "Area3D", true, false):
		if node.has_meta(&"doodad"):
			var shape := ((node as Area3D).get_child(0) as CollisionShape3D).shape as BoxShape3D
			var mid: float = -(node as Area3D).global_position.z
			boxes.append(Vector2(mid - shape.size.z * 0.5, mid + shape.size.z * 0.5))
	boxes.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var apart: bool = boxes.size() == 3
	for i: int in range(1, boxes.size()):
		apart = apart and absf(boxes[i].x - boxes[i - 1].y - LevelGenerator.DOODAD_ROW_TOUCH) < 0.001
	check(apart, "a row's doodads each have their own box, %.2f m apart one right after the other (%s)"
		% [LevelGenerator.DOODAD_ROW_TOUCH, boxes])
	var looks: Dictionary = {}
	for c: Dictionary in skin.calls:
		looks[int(c["seed"])] = true
	check(skin.calls.size() == 3 and looks.size() == 1 and looks.has(look),
		"every doodad of a row is dressed with the row's look (%s)" % [looks.keys()])
	root.queue_free()
	await tree.process_frame
	var market := load("res://data/skins/marketplace_skin.tres") as ZoneSkin
	var meshes: Dictionary = {}
	var size := Vector3(tuning.doodad_small_width, tuning.doodad_height, length)
	for d: Dictionary in layout.doodads:
		var body := Node3D.new()
		market.doodad(body, size, &"small", int(d["side"]), int(d.get("look", d["seed"])))
		for m: Node in body.find_children("*", "MeshInstance3D", true, false):
			meshes[(m as MeshInstance3D).mesh.get_instance_id()] = true
		body.free()
	check(meshes.size() == 1, "in the Marketplace's cards a row is one picture all along (%d meshes)" % meshes.size())


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
						if arrays[Mesh.ARRAY_COLOR] != null:
							for col: Color in arrays[Mesh.ARRAY_COLOR]:
								glows = glows or col.a > 0.0
					var lit: bool = inst.material_override == MeshKit.solid() or DoodadCards.is_card_material(inst.material_override)
					check(not glows and lit, "%s's %s doodad is lit, never glowing" % [file, size])
				body.free()
	check(skins >= 7, "every skin's doodads looked at (%d)" % skins)


## The zones' picture cards (DoodadCards; owner's request October 9, 2026): every zone's manifest
## loads and gives each size class a look, was painted for today's box sizes (rerun `tools/godot.sh
## doodads` after changing MovementTuning's doodad sizes), and every card shows a picture from its
## atlas on a plane inside its box. The card shader never emits light.
func _test_cards() -> void:
	var shader := load(DoodadCards.SHADER_PATH) as Shader
	check(shader != null and not shader.code.contains("EMISSION"), "the doodad card shader is lit scenery, never emissive")
	for zone: String in DoodadCards.ZONES:
		var cards := DoodadCards.for_zone(zone)
		check(cards.ok, "%s has doodad cards (tools/godot.sh doodads)" % zone)
		if not cards.ok:
			continue
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DoodadCards.DIR.path_join(zone + ".json")))
		var import := ConfigFile.new()
		check(import.load(String(m["atlas"]) + ".import") == OK
			and int(import.get_value("params", "compress/mode", -1)) == 2 and bool(import.get_value("params", "mipmaps/generate", false)),
			"%s's atlas is VRAM-compressed with mipmaps (a cheap load mid-run; no shimmer far away)" % zone)
		var boxes: Dictionary = m["boxes"]
		var images: Dictionary = m["images"]
		for size: StringName in LevelLayout.DOODAD_SIZES:
			var box: Vector3 = tuning.doodad_size(size)
			var drawn: Array = boxes.get(String(size), [])
			check(drawn.size() == 3 and Vector3(float(drawn[0]), float(drawn[1]), float(drawn[2])).is_equal_approx(box),
				"%s's %s pictures were painted for today's box %s (%s): rerun tools/godot.sh doodads" % [zone, size, box, drawn])
			var looks: Array = cards.designs.get(String(size), [])
			check(not looks.is_empty(), "%s has a %s look" % [zone, size])
			for d: Dictionary in looks:
				var tag: String = "%s's %s look %s" % [zone, size, d["name"]]
				check(not (d["cards"] as Array).is_empty(), "%s has cards" % tag)
				# Its mesh carries the look's main colours: vertex colours that never glow, and its metadata.
				var mesh: ArrayMesh = cards.mesh_for(d, box)
				var palette: PackedColorArray = mesh.get_meta(DoodadCards.COLORS_META, PackedColorArray())
				var listed: bool = palette.size() == (d["colors"] as Array).size() and palette.size() > 0
				for c: Color in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
					var known: bool = false
					for p: Color in palette:
						known = known or Color(c.r, c.g, c.b).is_equal_approx(p) or Color(c.r, c.g, c.b).to_rgba32() == p.to_rgba32()
					listed = listed and known and c.a == 0.0
				check(listed, "%s's mesh carries its main colours, never glowing (%s)" % [tag, palette])
				for c: Dictionary in d["cards"]:
					var rect: Array = c["rect"]
					var at: float = float(c["at"])
					check(images.has(String(c["image"])), "%s shows a picture in its atlas (%s)" % [tag, c["image"]])
					check(String(c["plane"]) in ["x", "y", "z"] and at >= 0.0 and at <= 1.0, "%s's cards lie on planes inside its box" % tag)
					check(rect.size() == 4 and float(rect[0]) >= 0.0 and float(rect[1]) >= 0.0 and float(rect[2]) <= 1.0
						and float(rect[3]) <= 1.0 and float(rect[0]) < float(rect[2]) and float(rect[1]) < float(rect[3]),
						"%s's cards stay inside its box (%s)" % [tag, rect])


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


## A move against the push (task I4): a move back into the pushing doodad's lane while its push carries the runner is
## blocked (the clank), as its side would block it beside them, so the body never sinks into it; and moves mashed
## toward it all along it leave the push to finish (a quick shove into the lane beside, never stuck between the
## lanes against its side, where a treasure stash's walls would let a runner slip in).
func _test_push_holds() -> void:
	sim.trace = true
	var geo := TrackGeometry.new(3, tuning)
	var d: Dictionary = _doodad(1, 40.0, &"medium", 1)
	var calib: Dictionary = await sim.run(_one_doodad(3, d), 1, 3.0, [])
	var push_at: float = -1.0
	for s: Dictionary in calib["trace"]:
		if int(s["lane"]) == 2:
			push_at = float(s["d"])
			break
	check(push_at > 0.0, "the doodad pushes the runner (at %.2f m)" % push_at)
	var frame: float = 1.0 / Engine.physics_ticks_per_second
	var cases: Array = []
	for back_after: float in [0.05, 0.3, 0.8]:
		cases.append(["a move back %.2f m into the push" % back_after, [[push_at + back_after, &"move_left"]]])
	var mash: Array = []
	var at: float = push_at
	while at < float(d["end"]) - 0.5:
		mash.append([at, &"move_left"])
		at += 0.3
	cases.append(["moves back mashed from the push to its end", mash])
	for c: Array in cases:
		var r: Dictionary = await sim.run(_one_doodad(3, d), 1, 3.0, c[1])
		var events: Array = r["events"]
		var start: float = -1.0
		var done: float = -1.0
		for s: Dictionary in r["trace"]:
			if start < 0.0 and int(s["lane"]) == 2:
				start = float(s["t"])
			if start >= 0.0 and done < 0.0 and absf(float(s["x"]) - geo.lane_x(2)) < 0.01:
				done = float(s["t"])
		check(r["alive"] and events.count(&"doodad_push") == 1 and events.has(&"lane_blocked") and int(r["lane"]) == 2,
			"%s is blocked: the runner ends in the lane beside (lane %d, %s)" % [c[0], r["lane"], events])
		check(start >= 0.0 and done >= 0.0 and done - start <= tuning.doodad_push_time + 1.5 * frame,
			"%s: the push still lands in the next lane's middle within %.2f s (%.3f s)" % [c[0], tuning.doodad_push_time, done - start])
		var sink: float = _sink(r["trace"], d, geo)
		check(sink <= SINK_TOLERANCE, "%s: the body never sinks into it (%.3f m)" % [c[0], sink])
	sim.trace = false


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
		if not s.is_level() or s.is_minigame():
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
				# A treasure stash's doodads stand together, under its ceiling (task I4): test_ceiling_scenarios runs them.
				# A row's (task L3): _test_campaign_rows runs into each row as one.
				if d.has("stash") or d.has("row"):
					continue
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
## plays a fresh copy of the level's build (LevelCache, task PERF2; the smash marked only the attempt's own
## copy): the very same layout as before the smash, that doodad whole on the track, and a runner who
## doesn't dash is pushed by it.
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
	var reused: bool = LevelCache.last_reused
	await tree.physics_frame
	w = run.world
	var again: Dictionary = w.layout.doodads[0]
	check(JSON.stringify(w.layout.to_dict()) == before and not again.has("smashed") and (reused or not LevelCache.enabled),
		"a retry plays the very same level, a copy of its build (reused: %s), the doodad whole in its data" % reused)
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
		# A mini-game level (the Beach's volleyball match) isn't generated: no doodads.
		if not s.is_level() or s.is_minigame():
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
				# A treasure stash's doodads (task I4): test_ceiling_scenarios dashes into one. A row's (task L3):
				# _test_campaign_rows dashes into each row as one.
				if d.has("stash") or d.has("row"):
					continue
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
			if not s.is_level() or s.is_minigame():
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
				# A treasure stash's doodads stand under its ceiling, and what the dash shows behind them is the stash
				# (task I4: test_ceiling_scenarios).
				if d.has("stash"):
					continue
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


# --- Rows and the lane by a side wall (task L3) ------------------------------------------------------

## A row of `count` doodads of `size` in `lane` from `start`, pushing to `side`, `spaced` (a doodad's length between
## each two) or one right after the other (LevelGenerator.DOODAD_ROW_TOUCH), marked as the generator marks one.
func _row(lane: int, start: float, size: StringName, side: int, count: int, spaced: bool) -> Array[Dictionary]:
	var length: float = tuning.doodad_size(size).z
	var step: float = length + (length if spaced else LevelGenerator.DOODAD_ROW_TOUCH)
	var out: Array[Dictionary] = []
	for i: int in count:
		var d: Dictionary = _doodad(lane, start + i * step, size, side)
		d["seed"] = 3 + i
		d["look"] = 3
		d["row"] = [start, start + (count - 1) * step + length]
		out.append(d)
	return out


## A plain layout of `lanes` lanes holding copies of `doodads` (fresh ones for each run, as _one_doodad).
func _with_doodads(lanes: int, doodads: Array[Dictionary], length: float = 400.0) -> LevelLayout:
	var layout := RunSim.layout(lanes, length)
	for d: Dictionary in doodads:
		layout.doodads.append(d.duplicate(true))
	return layout


## The most the visual body sank into doodad `d` over a run's trace while the body was on a wall (metres; 0 if it
## never touched it), until the first doodad broke as a wall runner reached it: on a wall the body lies from the wall's
## face out to its head (visual_size.y across the track), visual_size.x high around `h`, visual_size.z long.
func _wall_sink(trace: Array, d: Dictionary, geo: TrackGeometry, t: MovementTuning = null) -> float:
	var mt: MovementTuning = t if t != null else tuning
	var box: Vector3 = mt.doodad_size(StringName(d["size"]))
	var x0: float = geo.lane_x(int(d["lane"])) - box.x * 0.5
	var x1: float = geo.lane_x(int(d["lane"])) + box.x * 0.5
	var worst: float = 0.0
	for s: Dictionary in trace:
		if int(s.get("doodad_passes", 0)) > 0:
			break
		if String(s["surface"]) != "wall":
			continue
		var x: float = float(s["x"])
		var head: float = x - signf(x) * mt.visual_size.y
		var ox: float = minf(maxf(x, head), x1) - maxf(minf(x, head), x0)
		var oz: float = minf(float(s["d"]) + mt.visual_size.z * 0.5, float(d["end"])) \
			- maxf(float(s["d"]) - mt.visual_size.z * 0.5, float(d["start"]))
		var oy: float = minf(float(s["h"]) + mt.visual_size.x * 0.5, box.y) - maxf(float(s["h"]) - mt.visual_size.x * 0.5, 0.0)
		if ox > 0.0 and oz > 0.0 and oy > 0.0:
			worst = maxf(worst, minf(ox, minf(oz, oy)))
	return worst


## The most the body sank into any of `row`'s doodads while it stood (the dash breaks them in order: the k-th of them
## the dash smashed stands until the run's k-th smash), on the floor (_sink) and on a wall (_wall_sink).
func _row_sink(trace: Array, row: Array[Dictionary], smashed: int, geo: TrackGeometry, t: MovementTuning = null) -> float:
	var worst: float = 0.0
	for i: int in row.size():
		var standing: Array = []
		for s: Dictionary in trace:
			if i < smashed and int(s.get("smashes", 0)) > i:
				break
			standing.append(s)
		worst = maxf(worst, maxf(_sink(standing, row[i], geo, t), _wall_sink(standing, row[i], geo, t)))
	return worst


## The frames of a run's trace before a wall runner broke a doodad by their wall (Player.doodad_passes).
func _before_pass(trace: Array) -> Array:
	var out: Array = []
	for s: Dictionary in trace:
		if int(s.get("doodad_passes", 0)) > 0:
			break
		out.append(s)
	return out


## A row on real physics (task L3), at 3, 5 and 6 lanes, in an inner lane and by either side wall, one right after the
## other (small ones) and spaced (medium ones): a runner in its lane is pushed once, by its first one, into the lane on
## its side (inward by a wall), and runs on beside it past its last one, never pushed again and never sinking into any
## of them; a switch back into its lane beside one of them is blocked (the clank and the bump, never into it); and a
## runner who switches into a space between two of a spaced row is caught by the next one's front corner and pushed
## back out the way they came, never stuck and never sinking into it: a row is never a slalom nobody asked for.
func _test_row_push() -> void:
	sim.trace = true
	var runs: int = 0
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for lane: int in [1, 0, lanes - 1]:
			var side: int = 1 if lane == 0 else (-1 if lane == lanes - 1 else (1 if lanes > 3 else -1))
			for spaced: bool in [false, true]:
				var size: StringName = &"medium" if spaced else &"small"
				var row: Array[Dictionary] = _row(lane, 40.0, size, side, 3, spaced)
				var tag: String = "(lanes=%d, lane %d, side %+d, %s row of 3 %s)" % [lanes, lane, side, "a spaced" if spaced else "a",
					size]
				var row_end: float = float(row[-1]["end"])
				var seconds: float = (row_end + 15.0) / tuning.run_speed
				var r: Dictionary = await sim.run(_with_doodads(lanes, row), lane, seconds, [])
				check(r["alive"] and int(r["pushes"]) == 1 and int(r["lane"]) == lane + side and float(r["distance"]) > row_end,
					"a row pushes once, into the lane on its side, and the runner runs on beside it past its end (%d pushes, lane %d) %s"
					% [r["pushes"], r["lane"], tag])
				check(_row_sink(r["trace"], row, 0, geo) <= SINK_TOLERANCE, "never sinking into any of its doodads " + tag)
				var back: StringName = &"move_left" if side > 0 else &"move_right"
				var beside: float = (float(row[1]["start"]) + float(row[1]["end"])) * 0.5
				var b: Dictionary = await sim.run(_with_doodads(lanes, row), lane + side, seconds, [[beside, back]], [beside + 1.0])
				check(b["alive"] and (b["events"] as Array).has(&"lane_blocked") and int((b["at"] as Dictionary)[beside + 1.0]["lane"]) == lane + side
					and _row_sink(b["trace"], row, 0, geo) <= 0.0001,
					"a switch into its lane beside one of its doodads is blocked, never into it (%s) %s" % [b["events"], tag])
				runs += 2
				if spaced:
					# Into the space, a little before the next one's front: its corner catches the switch.
					var space: float = float(row[1]["start"]) - 1.6
					var s: Dictionary = await sim.run(_with_doodads(lanes, row), lane + side, seconds, [[space, back]])
					check(s["alive"] and int(s["pushes"]) == 1 and int(s["lane"]) == lane + side
						and _row_sink(s["trace"], row, 0, geo) <= SINK_TOLERANCE,
						"into a space between two of them, the next one pushes the runner back out, never stuck in it (%d pushes, lane %d) %s"
						% [s["pushes"], s["lane"], tag])
					runs += 1
	sim.trace = false
	check(runs == 45, "rows run into: %d" % runs)


## The dash along a row (task L3; GDD §3, owner, October 8, 2026: "dashing into one breaks it apart, and the player
## keeps their lane with no push and no damage"), at 3, 5 and 6 lanes, in an inner lane and by a side wall: a dash
## started 6 m before a row of four small ones one right after the other smashes every one of them, each once, each
## before the body touches it, the lane kept and no push; one started as far before a spaced row of three medium ones
## ends between its second and its third: the first two break, and the third pushes as usual, once, into the lane on
## its side, the body never inside any of them while they stand.
func _test_dash_row() -> void:
	sim.trace = true
	var runs: int = 0
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for lane: int in [1, lanes - 1]:
			var side: int = -1 if lane == lanes - 1 else 1
			for spaced: bool in [false, true]:
				var row: Array[Dictionary] = _row(lane, 40.0, &"medium" if spaced else &"small", side, 3 if spaced else 4, spaced)
				var tag: String = "(lanes=%d, lane %d, %s)" % [lanes, lane, "a spaced row of three medium ones" if spaced
					else "four small ones in a row"]
				var row_end: float = float(row[-1]["end"])
				var r: Dictionary = await sim.run(_with_doodads(lanes, row), lane, (row_end + 15.0) / tuning.run_speed, [[34.0, &"dash"]])
				var reach: float = 34.0 + _dash_length(tuning.run_speed) + tuning.visual_size.z * 0.5
				var expect: int = 0
				for d: Dictionary in row:
					expect += 1 if float(d["start"]) < reach else 0
				check(expect == (2 if spaced else 4), "the case reaches as planned (%d of %d) %s" % [expect, row.size(), tag])
				check(r["alive"] and int(r["smashes"]) == expect and (r["events"] as Array).count(&"doodad_smash") == expect,
					"the dash smashes every doodad of the row it reaches, each once (%d smashed) %s" % [r["smashes"], tag])
				if expect == row.size():
					check(int(r["pushes"]) == 0 and int(r["lane"]) == lane, "no push, the lane kept (lane %d) %s" % [r["lane"], tag])
				else:
					check(int(r["pushes"]) == 1 and int(r["lane"]) == lane + side,
						"where the dash ends short of the next one, it pushes as usual, once (%d pushes, lane %d) %s" % [r["pushes"], r["lane"], tag])
				check(_row_sink(r["trace"], row, expect, geo) <= SINK_TOLERANCE, "the body never inside one while it stands " + tag)
				runs += 1
	sim.trace = false
	check(runs == 12, "dashes along rows: %d" % runs)


## A wall runner never meets a doodad by their wall (task L3: Player._check_wall_doodads; the owner's October 9 request
## put doodads in the lane by a side wall, and a wall runner's body reaches into it), at 3, 5 and 6 lanes, by either
## wall, small and large ones, on real physics: a runner who stepped onto the wall from the outer lane 15 m before it
## (low on the wall, as a free entry and the slide down leave every runner) breaks it as they reach it: once, with the
## crunch, no push, no damage, still on the wall past it, the body never inside it while it stood. One a ramp launched
## 12 m before a small one runs over it high on the wall: it stands, untouched. Swept over where the runner gets onto
## the wall (free entries and ramps from 3 m to 35 m before it): never a push, at most one break, alive, the body never
## inside it while it stands.
func _test_wall_runner() -> void:
	sim.trace = true
	var runs: int = 0
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for wall: int in [-1, 1]:
			var lane: int = 0 if wall < 0 else lanes - 1
			var toward: StringName = &"move_left" if wall < 0 else &"move_right"
			for size: StringName in [&"small", &"large"]:
				var d: Dictionary = _doodad(lane, 60.0, size, -wall)
				var tag: String = "(lanes=%d, by wall %+d, %s)" % [lanes, wall, size]
				var past: float = float(d["end"]) + 1.0
				var low: Dictionary = await sim.run(_one_doodad(lanes, d), lane, 4.0, [[45.0, toward]], [past])
				var events: Array = low["events"]
				check(low["alive"] and int(low["doodad_passes"]) == 1 and events.count(&"doodad_smash") == 1 and int(low["pushes"]) == 0
					and not events.has(&"doodad_push") and not events.has(&"armor_hit"),
					"a wall runner low on the wall breaks a doodad by it as they reach it, once, with no push (%s) %s" % [events, tag])
				check(String((low["at"] as Dictionary)[past]["surface"]) == "wall", "and runs on along the wall past it " + tag)
				check(_wall_sink(low["trace"], d, geo) <= 0.0001, "the body never inside it while it stood " + tag)
				runs += 1
				if size == &"small":
					var ramped: LevelLayout = _one_doodad(lanes, d)
					ramped.ramps.append({"at": 48.0, "side": wall})
					var high: Dictionary = await sim.run(ramped, lane, 4.0, [], [past])
					check(high["alive"] and int(high["doodad_passes"]) == 0 and int(high["pushes"]) == 0
						and String((high["at"] as Dictionary)[past]["surface"]) == "wall" and _wall_sink(high["trace"], d, geo) <= 0.0001,
						"a runner a ramp launched runs over it high on the wall: it stands, untouched (%d broke) %s" % [high["doodad_passes"], tag])
					runs += 1
				for before: float in [3.0, 8.0, 15.0, 25.0, 35.0]:
					for ramp: bool in [false, true]:
						var layout: LevelLayout = _one_doodad(lanes, d)
						var actions: Array = []
						if ramp:
							layout.ramps.append({"at": float(d["start"]) - before - tuning.ramp_length, "side": wall})
						else:
							actions.append([float(d["start"]) - before, toward])
						var r: Dictionary = await sim.run(layout, lane, 4.5, actions)
						var x: String = "(%s %.0f m before it) %s" % ["a ramp" if ramp else "onto the wall", before, tag]
						check(r["alive"] and int(r["pushes"]) == 0 and int(r["doodad_passes"]) <= 1,
							"a wall runner meets no push and breaks it at most once (%d broke) %s" % [r["doodad_passes"], x])
						check(_wall_sink(r["trace"], d, geo) <= 0.0001 and _sink(_before_pass(r["trace"]), d, geo) <= SINK_TOLERANCE,
							"the body is never inside it while it stands " + x)
						runs += 1
	sim.trace = false
	check(runs == 138, "wall runners by doodads: %d" % runs)


## A doodad by a side wall on the floor (task L3), at 3, 5 and 6 lanes, by either wall: a floor runner in its lane meets
## its front and is pushed inward, once, into the lane beside, never sinking into it; a switch into its side from the
## lane beside is blocked (the clank and the bump, never into it); a runner in its lane who steps toward the wall just
## before it gets onto the wall and breaks it as they reach it (Player._check_wall_doodads), never inside it.
func _test_wall_lane_floor() -> void:
	sim.trace = true
	var runs: int = 0
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for wall: int in [-1, 1]:
			var lane: int = 0 if wall < 0 else lanes - 1
			var inner: int = lane - wall
			var d: Dictionary = _doodad(lane, 40.0, &"medium", -wall)
			var tag: String = "(lanes=%d, by wall %+d)" % [lanes, wall]
			var r: Dictionary = await sim.run(_one_doodad(lanes, d), lane, 3.2, [])
			check(r["alive"] and int(r["pushes"]) == 1 and int(r["lane"]) == inner and _sink(r["trace"], d, geo) <= SINK_TOLERANCE,
				"a floor runner in its lane is pushed inward, once, never sinking into it (lane %d) %s" % [r["lane"], tag])
			var toward: StringName = &"move_left" if wall < 0 else &"move_right"
			var b: Dictionary = await sim.run(_one_doodad(lanes, d), inner, 3.2, [[42.0, toward]], [46.0])
			check(b["alive"] and (b["events"] as Array).has(&"lane_blocked") and int((b["at"] as Dictionary)[46.0]["lane"]) == inner
				and _sink(b["trace"], d, geo) <= 0.0001, "a switch into its side from the lane beside is blocked (%s) %s" % [b["events"], tag])
			var w: Dictionary = await sim.run(_one_doodad(lanes, d), lane, 3.2, [[38.5, toward]])
			check(w["alive"] and int(w["pushes"]) == 0 and int(w["doodad_passes"]) == 1 and _wall_sink(w["trace"], d, geo) <= 0.0001
				and _sink(_before_pass(w["trace"]), d, geo) <= SINK_TOLERANCE,
				"a step onto the wall just before it gets onto the wall and breaks it as the body reaches it (%d pushes, %d broke) %s"
				% [w["pushes"], w["doodad_passes"], tag])
			runs += 3
	sim.trace = false
	check(runs == 18, "doodads by the walls run at from the floor: %d" % runs)


## The campaign's rows and doodads by the side walls on real physics (task L3), at 3, 5 and 6 lanes and each level's
## speed, with the level's pieces around them (_run_into's cut, stretched over a whole row): each level's first row
## run into (pushed once by its first doodad, landing on clear floor in the lane beside, on safely past the row, never
## inside any of them) and dashed into (every doodad the dash reaches smashed, the next one, if any, pushing as usual,
## never inside a standing one); and its first doodad by a side wall met by a runner who steps onto that wall just
## before it (it breaks as the body reaches it, never inside it; a row by the wall all along).
func _test_campaign_rows() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var rows_run: int = 0
	var walls_run: int = 0
	sim.trace = true
	for s: CampaignStep in campaign.steps():
		if not s.is_level() or s.is_minigame():
			continue
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(s, lanes)
			var fast: MovementTuning = config.movement_for(tuning)
			var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
			var geo := TrackGeometry.new(lanes, fast)
			var lead: float = LevelGenerator.doodad_lead_for(fast)
			var after: float = config.spacing_seconds_hard * fast.run_speed
			var rows: Array[Array] = _rows_of(layout)
			if not rows.is_empty():
				var typed: Array[Dictionary] = []
				typed.assign(rows[0])
				var first: Dictionary = typed[0]
				var tag: String = "(%s lanes=%d, a row of %d at %.0f in lane %d)" % [s.id, lanes, typed.size(), first["start"], first["lane"]]
				# The cut reaches past the whole row: its first one's window stretched to the row's end.
				var whole: Dictionary = first.duplicate()
				whole["end"] = LevelLayout.doodad_extent(first).y
				var r: Dictionary = await _run_into(layout, whole, fast, lead, after)
				var moved: Array[Dictionary] = []
				for d: Dictionary in typed:
					var m: Dictionary = d.duplicate()
					m["start"] = float(d["start"]) + float(r["offset"])
					m["end"] = float(d["end"]) + float(r["offset"])
					moved.append(m)
				check(r["alive"] and int(r["pushes"]) == 1 and r["reached"] and int(r["lane"]) == int(first["lane"]) + int(first["side"]),
					"a row pushes once onto clear floor in the lane beside, on safely past it (%s, lane %d) %s" % [r["cause"], r["lane"], tag])
				check(_row_sink(r["trace"], moved, 0, geo, fast) <= SINK_TOLERANCE, "never sinking into any of its doodads " + tag)
				var dash: Dictionary = await _run_into(layout, whole, fast, lead, after, [[-6.0, &"dash"]])
				check(dash["alive"] and int(dash["smashes"]) >= 1 and int(dash["pushes"]) <= 1 and dash["reached"]
					and (int(dash["pushes"]) == 0) == (int(dash["smashes"]) == typed.size()),
					"dashed into: smashed as far as the dash reaches, the next one pushing as usual (%d smashed, %d pushed) %s"
					% [dash["smashes"], dash["pushes"], tag])
				check(_row_sink(dash["trace"], moved, int(dash["smashes"]), geo, fast) <= SINK_TOLERANCE, "never inside one while it stands " + tag)
				rows_run += 1
			for d: Dictionary in layout.doodads:
				var lane: int = int(d["lane"])
				if d.has("stash") or (lane != 0 and lane != lanes - 1):
					continue
				var toward: StringName = &"move_left" if lane == 0 else &"move_right"
				var whole: Dictionary = d.duplicate()
				var extent: Vector2 = LevelLayout.doodad_extent(d)
				whole["start"] = extent.x
				whole["end"] = extent.y
				var tag: String = "(%s lanes=%d, by a wall at %.0f in lane %d)" % [s.id, lanes, extent.x, lane]
				var w: Dictionary = await _run_into(layout, whole, fast, lead, after, [[-lead + 0.5, toward]])
				var m: Dictionary = d.duplicate()
				m["start"] = float(d["start"]) + float(w["offset"])
				m["end"] = float(d["end"]) + float(w["offset"])
				check(w["alive"] and int(w["pushes"]) == 0 and int(w["doodad_passes"]) >= 1 and _wall_sink(w["trace"], m, geo, fast) <= 0.0001,
					"a runner who steps onto the wall just before it breaks it as they reach it (%s, %d broke) %s"
					% [w["cause"], w["doodad_passes"], tag])
				walls_run += 1
				break
	sim.trace = false
	print("  campaign rows run into and dashed into: %d; doodads by a wall met from it: %d" % [rows_run, walls_run])
	check(rows_run >= 10 and walls_run >= 30, "campaign rows (%d) and doodads by a wall (%d) run on physics" % [rows_run, walls_run])
