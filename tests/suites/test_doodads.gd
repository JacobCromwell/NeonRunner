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


## Records the doodad hook's calls (and dresses nothing).
class RecordingSkin extends ZoneSkin:
	var calls: Array[Dictionary] = []

	func doodad(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
		calls.append({"body": body, "size": size, "size_class": size_class, "side": side, "seed": look_seed})


var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	_test_layout_data()
	_test_share_zero()
	_test_placement()
	_test_campaign()
	_test_keep_outs()
	await _test_track()
	_test_skins()
	_test_cards()
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
## at 3 lanes into that case.
func _test_share_zero() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var checked: int = 0
	for id: String in ["city/1", "gangland/3", "marketplace/1", "dead_zone/2", "golden/2"]:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var tag: String = "%s lanes=%d" % [id, lanes]
			check(config.doodad_share > 0.0, "%s has doodads in its data" % tag)
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
## moved to start 30 m in, at `t`'s speed. The result of RunSim.run, with "reached" (the player got to
## the end of the cut) and "offset" (how far it moved).
func _run_into(layout: LevelLayout, d: Dictionary, t: MovementTuning, lead: float, after: float) -> Dictionary:
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
	var r: Dictionary = await sim.run(part, int(d["lane"]), (to - from + 30.0 + 2.0) / t.run_speed, [], [], t)
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
