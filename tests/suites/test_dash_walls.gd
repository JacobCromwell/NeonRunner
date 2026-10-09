extends TestSuite
## Dash walls (task H7a; GDD §9.14, owner, October 8, 2026): a building standing across every floor lane that
## the runner dashes through; it crumbles into rubble, and without the dash it's one hit.
## - The layout: a level without dash walls is the same data as before (no "dash_walls" key); copy() and
##   append_pieces() carry them; a wall counts as a doodad in every lane for the enemies' and the generator's
##   checks (LevelLayout.doodad_between).
## - The generator (dash_wall_rules.gd) over every level with the feature (Corporate 1 to Golden 3) at 3, 5 and
##   6 lanes, on the levels' own seeds and others: the level's count, every one fair (LayoutChecks
##   .check_dash_walls: the spacing, a clear approach and stretch past it, no ceiling, a side wall open, no dash
##   bait just before, the enemies' keep-outs), the same every time; Corporate 1 introduces them right after
##   their start; past an introduction they stand after the danger density pass and the doodads, which add
##   what they add without them, taking out only what stood in their way; and a level without the feature (or
##   a count of 0) draws nothing and is built as before.
## - The track: a DashBreakable on the dash wall layer across the floor lanes, short of the side walls, taller
##   than any jump, with a forgiving solid hitbox (armor absorbs it, it breaks the wall) from the floor up; the
##   skin's hook gets its box and seed; a broken one is never built again.
## - The damage rules: the dash passes; armor, then the shield, absorb the crash; otherwise it kills; god mode
##   and the invulnerability window ignore it; armor still never blocks other solid hits.
## - On real physics at 3, 5 and 6 lanes, in every lane: a dash smashes it before the body touches it (no hit,
##   the lane and the speed kept); without the dash the runner crashes (it kills a runner with no protection,
##   and breaks); a jump or a slide crashes too; a wall runner passes it on either side wall.
## - In a full world: armor or a shield absorbs a crash (then the invulnerability window), god mode shrugs it
##   off, the wall breaks every time; it crumbles (its pieces in its look's colours, lit, never glowing, dust,
##   a heavier shake that Screen shake scales away, the crash's sound), Reduced flashing changes nothing; the
##   warm-up draws its look and its crumble while the level loads.
## - It stays broken for the attempt, through a death and a revive, and a retry rebuilds it whole.
## - Every skin dresses it inside its box, lit and never glowing, and names its pieces' colours; every zone's own look
##   (task H7b: built from its side-wall kit, a few layouts by seed, on the surfaces the skin names, one small mesh
##   built in a moment) keeps to the same contract; the hint.
## - The enemies: a hover truck gives way to a wall (it drops behind the runner, who meets the wall first) and
##   bursts through one it can't give way to; a heli drone rises over one and holds its barrage near it.

const DashWallRules := preload("res://scripts/enemies/dash_wall_rules.gd")
const DroneScript := preload("res://scripts/enemies/drone.gd")
const TruckScript := preload("res://scripts/enemies/hover_truck.gd")
const TankScript := preload("res://scripts/enemies/buzz_overdrive.gd")
const TankRules := preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const CyborgRules := preload("res://scripts/enemies/cyborg_rules.gd")
## Every level that has dash walls.
const LEVELS: PackedStringArray = ["corporate/1", "corporate/2", "dead_zone/1", "dead_zone/2", "golden/1", "golden/2",
	"golden/3"]
## Seeds other than a level's own tried per level and lane count.
const OTHER_SEEDS: int = 2
## A wall's look is one small mesh: at most this many surfaces and vertices, built (the first time, in a skin whose
## materials already exist) in under these milliseconds on average and at most (DESIGN-TBD: measured about 1 ms and
## 4000 vertices; the room is for a loaded machine).
const WALL_SURFACES_MAX: int = 3
const WALL_VERTICES_MAX: int = 8000
const WALL_BUILD_MEAN_MS: float = 12.0
const WALL_BUILD_MAX_MS: float = 60.0
## Seeds a skin's walls are built with: all 12 layouts and tones (DashWallKit.look_of, tone_of), at 3, 5 and 6 lanes.
const LOOK_SEEDS: int = 12
const LANE_COUNTS: Array[int] = [3, 5, 6]
## The lowest a wall's silhouette may dip over the floor lanes (metres above the floor): the hitbox reaches the box's
## top, so what is open above a broken top is out of a jump's reach (the wall jump's feet reach about 5.3 m,
## MovementTuning) and only a flyer gets over. Columns across the lanes the silhouette is measured at.
const SILHOUETTE_MIN: float = 5.8
const SILHOUETTE_COLUMNS: int = 90
## How far a hard-coded Corporate podium seed's hash must be from the shader's threshold (0.45): the shader's float
## arithmetic is not the test's double, a seed near the line could flip.
const SHADER_HASH_MARGIN: float = 0.1
## How far into the body a frame may carry it while a wall still stands (metres): rounding only.
const TOUCH_TOLERANCE: float = 0.02
const O = DamageRules.Outcome


## Records the dash wall hook's calls (and dresses each with the default look).
class RecordingSkin extends ZoneSkin:
	var calls: Array[Dictionary] = []

	func dash_wall(body: Node3D, size: Vector3, look_seed: int) -> void:
		calls.append({"body": body, "size": size, "seed": look_seed})
		super(body, size, look_seed)


var sim: RunSim
var powerups: PowerupTuning
var campaign: Campaign


func run() -> void:
	sim = RunSim.new(tree, tuning)
	powerups = load("res://data/tuning/powerups.tres") as PowerupTuning
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	_test_layout_data()
	_test_generator()
	_test_introduction()
	_test_after_danger_density()
	_test_hush()
	_test_feature_absent()
	await _test_track()
	_test_damage_rules()
	await _test_dash_through()
	await _test_crash()
	await _test_jump_and_slide()
	await _test_wall_runner()
	await _test_world_protection()
	await _test_world_crumble()
	await _test_retry()
	_test_skins()
	_test_hint()
	await _test_truck_gives_way()
	await _test_truck_bursts_through()
	await _test_drone_rises()
	await _test_panic_cyborg()
	await _test_ground_enemies_leave()


# --- Helpers -------------------------------------------------------------------------------------

## A dash wall entry with its face at `face` (MovementTuning.dash_wall_depth deep).
func _wall(face: float, look_seed: int = 3) -> Dictionary:
	return {"start": face, "end": face + tuning.dash_wall_depth, "seed": look_seed}


## A plain layout of `lanes` lanes and `length` metres holding a fresh dash wall at `face` alone.
func _one_wall(lanes: int, face: float, length: float = 300.0) -> LevelLayout:
	var layout := RunSim.layout(lanes, length)
	layout.dash_walls.append(_wall(face))
	return layout


## The dash's length (metres) at run speed `run_speed`: its duration at the speed plus its bonus.
func _dash_length(run_speed: float) -> float:
	return powerups.dash_duration * (run_speed + powerups.dash_speed_bonus)


func _run_until(w: RunWorld, seconds: float, done: Callable) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


## The deepest the runner's body went past a wall's face while the wall still stood (metres, 0 if never):
## from a run's trace, frame by frame until the first smash.
func _touch(trace: Array, face: float) -> float:
	var worst: float = 0.0
	for s: Dictionary in trace:
		if int(s.get("smashes", 0)) > 0:
			break
		worst = maxf(worst, float(s["d"]) + tuning.visual_size.z * 0.5 - face)
	return worst


## Every DashBreakable built under `node`.
func _walls_in(node: Node) -> Array[DashBreakable]:
	var out: Array[DashBreakable] = []
	for n: Node in node.find_children("*", "DashBreakable", true, false):
		var b := n as DashBreakable
		if b != null and b.kind == &"dash_wall":
			out.append(b)
	return out


## True if anything on the dash wall or hazard layers fills the floor of the wall entry `w` in the middle of
## the track (a standing wall's box or its hitbox).
func _standing_at(world: RunWorld, w: Dictionary) -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, float(w["end"]) - float(w["start"]) - 0.4)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.collision_mask = TrackBuilder.LAYER_DASH_WALL | TrackBuilder.LAYER_HAZARD
	q.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, TrackGeometry.world_z((float(w["start"]) + float(w["end"])) * 0.5)))
	return not world.player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# --- The layout and the generator ----------------------------------------------------------------

## A layout without dash walls keeps its data as before; with them, its dictionary carries them, copy() and
## append_pieces() carry them, and they count as doodads in every lane (doodad_between) and on their own
## (dash_wall_between), broken or not.
func _test_layout_data() -> void:
	var l := RunSim.layout(5)
	check(not l.to_dict().has("dash_walls"), "a layout without dash walls has no dash_walls key: the same data as before")
	l.dash_walls.append(_wall(100.0))
	var d: Dictionary = l.to_dict()
	check(d.has("dash_walls") and (d["dash_walls"] as Array).size() == 1, "with one, its dictionary carries it")
	var c: LevelLayout = l.copy()
	check(c.dash_walls.size() == 1 and c.dash_walls[0] == l.dash_walls[0] and not is_same(c.dash_walls[0], l.dash_walls[0]),
		"copy() copies it, a fresh entry")
	var more := RunSim.layout(5)
	more.dash_walls.append(_wall(300.0))
	var joined := RunSim.layout(5)
	joined.append_pieces(more)
	check(joined.dash_walls.size() == 1 and float(joined.dash_walls[0]["start"]) == 300.0, "append_pieces() carries them")
	check(l.dash_wall_between(99.0, 100.5) and l.dash_wall_between(102.0, 105.0) and not l.dash_wall_between(103.0, 110.0)
		and not l.dash_wall_between(90.0, 99.0), "dash_wall_between finds it from its face to its back")
	for lane: int in 5:
		check(l.doodad_between(100.0, 101.0, lane), "a dash wall counts as a doodad in lane %d (doodad_between)" % lane)
	l.dash_walls[0]["smashed"] = true
	check(l.doodad_between(100.0, 101.0), "and still does once broken: an attack waits by it the same every attempt")


## Every level with the feature, at 3, 5 and 6 lanes, on its own seed (the campaign's) and others: no warning
## about walls, its count of them on its own seed and at least one on any, every one fair (LayoutChecks
## .check_dash_walls), and the same walls every time it's built.
func _test_generator() -> void:
	var builds: int = 0
	for id: String in LEVELS:
		var step: CampaignStep = campaign.step(id)
		for lanes: int in [3, 5, 6]:
			for k: int in OTHER_SEEDS + 1:
				var config: LevelConfig = campaign.configure(step, lanes)
				if k > 0:
					config.level_seed = 7100 + k
				var tag: String = "(%s, %d lanes, seed %d)" % [id, lanes, config.level_seed]
				var gen: LevelGenerator
				if k == 0:
					gen = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
				else:
					gen = LevelGenerator.new()
					gen.generate(config, tuning, LevelGenerator.load_for(config))
				var layout: LevelLayout = gen.layout
				builds += 1
				var warned: bool = false
				for w: String in gen.warnings:
					warned = warned or w.contains("dash wall")
				check(not warned, "no warning about dash walls %s %s" % [tag, gen.warnings])
				check(config.dash_walls >= 1 and config.dash_walls <= 4, "the level asks for 1 to 4 walls %s" % tag)
				if k == 0:
					check(layout.dash_walls.size() == config.dash_walls,
						"the campaign level gets its %d walls (%d) %s" % [config.dash_walls, layout.dash_walls.size(), tag])
				else:
					check(not layout.dash_walls.is_empty() and layout.dash_walls.size() <= config.dash_walls,
						"at least one wall, at most the level's count (%d) %s" % [layout.dash_walls.size(), tag])
				LayoutChecks.check_dash_walls(self, layout, config, tag)
				if k == 1:
					var again := LevelGenerator.new()
					again.generate(config, tuning, LevelGenerator.load_for(config))
					check(JSON.stringify(again.layout.dash_walls) == JSON.stringify(layout.dash_walls)
						and JSON.stringify(again.layout.to_dict()) == JSON.stringify(layout.to_dict()),
						"the same walls (and level) every time it's built %s" % tag)
	check(builds == LEVELS.size() * 3 * (OTHER_SEEDS + 1), "every level built (%d)" % builds)


## Corporate 1 introduces them (GDD §9.14, proposed: after the Buzz Overdrive's introduction): at 3, 5 and 6
## lanes on its own seed, its first wall comes within the introduction window of the feature's start
## (DashWallTuning.intro_window_seconds), after the Buzz Overdrive's start, alone (no other feature's
## introduction within the same window), and no other level gives the feature a start.
func _test_introduction() -> void:
	var t: DashWallTuning = DashWallTuning.load_default()
	for s: CampaignStep in campaign.steps():
		if s.is_level() and s.id != "corporate/1":
			check(not s.level.feature_starts.has("dash_wall"), "%s doesn't introduce dash walls" % s.id)
	var intro: LevelConfig = campaign.step("corporate/1").level
	check(intro.feature_starts.has("dash_wall") and intro.feature_start("dash_wall") > intro.feature_start("buzz_overdrive"),
		"Corporate 1 introduces them after the Buzz Overdrive's start")
	for lanes: int in [3, 5, 6]:
		var config: LevelConfig = campaign.configure(campaign.step("corporate/1"), lanes)
		var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
		var layout: LevelLayout = gen.layout
		var start: float = gen.feature_start("dash_wall")
		var tag: String = "(%d lanes)" % lanes
		check(not layout.dash_walls.is_empty(), "Corporate 1 has its walls " + tag)
		if layout.dash_walls.is_empty():
			continue
		var first: float = float(layout.dash_walls[0]["start"])
		var approach: float = t.approach_seconds * (gen.speed + powerups.dash_speed_bonus)
		check(first >= start - 0.01 and first <= start + approach + t.intro_window_seconds * gen.speed,
			"the first wall comes right after the feature's start (%.0f m, start %.0f m) %s" % [first, start, tag])
		for f: String in config.feature_starts:
			if f == "dash_wall":
				continue
			var other: float = gen.feature_start(f)
			check(absf(other - first) > t.intro_window_seconds * gen.speed,
				"no other introduction (%s at %.0f m) right at the wall's (%.0f m) %s" % [f, other, first, tag])


## Past an introduction the walls stand after the danger density pass and the zone doodads
## (DashWallRules.after_doodads), in the room the passes before them left: in a level that doesn't introduce
## them, on 3 lanes (the least room) and 5, the danger density pass's report, the fill pass's fillers, the
## enemies and the doodads are what the level gets with no walls at all (the share of danger the owner asked
## for holds), and the only pieces the walls cost are holes and fences in their footprints and signs beside them.
func _test_after_danger_density() -> void:
	var t: DashWallTuning = DashWallTuning.load_default()
	for id: String in ["dead_zone/1", "golden/2"]:
		for lanes: int in [3, 5]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var none: LevelConfig = campaign.configure(campaign.step(id), lanes)
			none.dash_walls = 0
			var tag: String = "(%s, %d lanes)" % [id, lanes]
			check(not config.feature_starts.has("dash_wall"), "%s doesn't introduce them %s" % [id, tag])
			var gen := LevelGenerator.new()
			gen.generate(config, tuning, LevelGenerator.load_for(config))
			var plain := LevelGenerator.new()
			plain.generate(none, tuning, LevelGenerator.load_for(none))
			check(gen.layout.dash_walls.size() == config.dash_walls, "its %d walls stand %s" % [config.dash_walls, tag])
			check(_before_wall_fences(gen.danger_density_result) == _before_wall_fences(plain.danger_density_result),
				"the danger density pass adds what it adds without them %s" % tag)
			check(JSON.stringify(gen.fills) == JSON.stringify(plain.fills), "and so does the fill pass %s" % tag)
			check(JSON.stringify(gen.layout.enemies) == JSON.stringify(plain.layout.enemies), "the enemies are the same %s" % tag)
			check(JSON.stringify(gen.layout.doodads) == JSON.stringify(plain.layout.doodads), "and the doodads %s" % tag)
			var spans: Array[Vector2] = []
			var routes: Array[Vector2] = []
			for w: Dictionary in gen.layout.dash_walls:
				spans.append(DashWallRules.footprint(gen, w, t))
				routes.append(Vector2(float(w["start"]) - t.wall_route_seconds * gen.speed, float(w["end"])))
			var kept: Dictionary = {}
			for g: Dictionary in gen.layout.gaps:
				kept[["gap", g["start"], g["end"], g["lane"]]] = true
			for f: Dictionary in gen.layout.fences:
				kept[["fence", f["at"], f["lane"]]] = true
			for s: Dictionary in gen.layout.signs:
				kept[["sign", s["start"], s["side"]]] = true
			var gone: int = 0
			for g: Dictionary in plain.layout.gaps:
				if not kept.has(["gap", g["start"], g["end"], g["lane"]]):
					gone += 1
					check(_reaches(spans, Vector2(float(g["start"]), float(g["end"]))),
						"a hole that went (%.1f m) stood in a wall's footprint %s" % [float(g["start"]), tag])
			var half: float = tuning.fence_depth * 0.5
			for f: Dictionary in plain.layout.fences:
				if not kept.has(["fence", f["at"], f["lane"]]):
					gone += 1
					check(_reaches(spans, Vector2(float(f["at"]) - half, float(f["at"]) + half)),
						"a fence that went (%.1f m) stood in a wall's footprint %s" % [float(f["at"]), tag])
			for s: Dictionary in plain.layout.signs:
				if not kept.has(["sign", s["start"], s["side"]]):
					gone += 1
					check(_reaches(routes, Vector2(float(s["start"]), float(s["end"]))),
						"a sign that went (%.1f m) stood beside a wall %s" % [float(s["start"]), tag])
			print("  dash walls after the danger density pass %s: %d walls, %d pieces taken out" % [tag,
				gen.layout.dash_walls.size(), gone])


## Danger density report `report` (LevelGenerator.danger_density_result) as JSON, without what its wall fence half
## adds (DangerDensity.apply_wall_fences: the wall fences come after the walls and keep off their wall routes).
func _before_wall_fences(report: Dictionary) -> String:
	var out: Dictionary = report.duplicate(true)
	for key: String in ["baseline_wall_fences", "wall_fence_target", "wall_fences_added", "wall_fences"]:
		out.erase(key)
	var constraints: PackedStringArray = []
	for c: String in out.get("constraints", PackedStringArray()):
		if not c.begins_with("wall fences"):
			constraints.append(c)
	out["constraints"] = constraints
	return JSON.stringify(out)


## True if `span` overlaps one of `spans`.
func _reaches(spans: Array[Vector2], span: Vector2) -> bool:
	for s: Vector2 in spans:
		if s.x <= span.y + 0.001 and s.y >= span.x - 0.001:
			return true
	return false


## The Hush (Dead Zone 2; GDD §5: "long silent stretches broken by sudden threats") keeps its quiet stretches free of
## walls as the fill and danger density passes do (DashWallRules.plan_for, `quiet`): on its own seed at 3, 5 and 6
## lanes every wall stands in a burst.
func _test_hush() -> void:
	for lanes: int in [3, 5, 6]:
		var config: LevelConfig = campaign.configure(campaign.step("dead_zone/2"), lanes)
		check(config.paced_in_bursts(), "The Hush is paced in bursts")
		var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
		check(not gen.layout.dash_walls.is_empty(), "it has its walls (%d lanes)" % lanes)
		for w: Dictionary in gen.layout.dash_walls:
			var fp: Vector2 = DashWallRules.footprint(gen, w)
			var quiet: bool = false
			for q: Vector2 in gen.quiet_stretches():
				quiet = quiet or (q.x <= fp.y and q.y >= fp.x)
			check(not quiet, "the wall at %.0f m stands in a burst, out of every quiet stretch (%d lanes)" % [
				float(w["start"]), lanes])


## A level without the feature draws nothing: no walls and no dash_walls key (a level of every zone before the
## Corporate one); and one that has it with a count of 0 is built exactly as with the feature left out.
func _test_feature_absent() -> void:
	for id: String in ["city/2", "gangland/3", "marketplace/2"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		check(not config.has_feature("dash_wall"), "%s has no dash walls in its features" % id)
		var layout: LevelLayout = LayoutCache.generate(config, tuning, LevelGenerator.load_for(config))
		check(layout.dash_walls.is_empty() and not layout.to_dict().has("dash_walls"), "%s has no dash walls" % id)
	var with_none: LevelConfig = campaign.configure(campaign.step("corporate/2"), 3)
	with_none.dash_walls = 0
	var without: LevelConfig = campaign.configure(campaign.step("corporate/2"), 3)
	var features := PackedStringArray(without.features)
	features.remove_at(features.find("dash_wall"))
	without.features = features
	var a := LevelGenerator.new()
	a.generate(with_none, tuning, LevelGenerator.load_for(with_none))
	var b := LevelGenerator.new()
	b.generate(without, tuning, LevelGenerator.load_for(without))
	check(a.layout.dash_walls.is_empty() and JSON.stringify(a.layout.to_dict()) == JSON.stringify(b.layout.to_dict()),
		"a count of 0 builds the level exactly as without the feature")


# --- The track -----------------------------------------------------------------------------------

## Each wall in a layout is built once its chunk is: a DashBreakable of kind dash_wall on the dash wall layer
## (never a lane blocker, a wall blocker or a hazard itself), over its stretch, as wide as the floor less the
## open strip beside each side wall, taller than any jump; its hitbox a solid Hazard that armor absorbs and that
## breaks it, a little smaller than its look, from just above the floor; the skin's hook gets its box and its
## seed, and names its pieces' colours. A wall already broken in this attempt isn't built.
func _test_track() -> void:
	for lanes: int in [3, 5, 6]:
		var layout := RunSim.layout(lanes, 300.0)
		layout.dash_walls.append(_wall(40.0, 5))
		layout.dash_walls.append(_wall(110.0, 6))
		var broken: Dictionary = _wall(75.0, 7)
		broken["smashed"] = true
		layout.dash_walls.append(broken)
		var root := Node3D.new()
		tree.root.add_child(root)
		var track := TrackBuilder.new()
		root.add_child(track)
		var skin := RecordingSkin.new()
		track.set_layout(layout, tuning, skin)
		track.update(0.0, 0.0)
		await tree.physics_frame
		var geo := TrackGeometry.new(lanes, tuning)
		var tag: String = "(%d lanes)" % lanes
		var walls: Array[DashBreakable] = _walls_in(track)
		check(walls.size() == 2 and skin.calls.size() == 2, "the standing walls are built and dressed, the broken one isn't (%d) %s"
			% [walls.size(), tag])
		check(track.dash_wall_for(layout.dash_walls[0]) != null and track.dash_wall_for(broken) == null,
			"dash_wall_for finds a built wall by its entry %s" % tag)
		var size: Vector3 = TrackBuilder.dash_wall_size(geo, tuning, tuning.dash_wall_depth)
		var jump_top: float = tuning.wall_max_height + tuning.wall_jump_velocity * tuning.wall_jump_velocity \
			/ (2.0 * 2.0 * tuning.jump_height / (tuning.jump_time_to_apex * tuning.jump_time_to_apex)) + tuning.hurtbox_size.y
		for b: DashBreakable in walls:
			var w: Dictionary = b.entry
			var shape := (b.get_child(0) as CollisionShape3D).shape as BoxShape3D
			check(b.collision_layer == TrackBuilder.LAYER_DASH_WALL and b.collision_mask == 0 and not b.monitoring,
				"its box is on the dash wall layer alone: no lane blocker, wall blocker or hazard %s" % tag)
			check(shape != null and shape.size.is_equal_approx(size) and b.size.is_equal_approx(size)
				and is_equal_approx(b.global_position.y, size.y * 0.5) and is_zero_approx(b.global_position.x)
				and is_equal_approx(-b.global_position.z, (float(w["start"]) + float(w["end"])) * 0.5),
				"over its stretch, centred across the track, standing on the floor %s" % tag)
			check(is_equal_approx(size.x * 0.5, geo.wall_x() - tuning.dash_wall_wall_room) and size.x * 0.5 > geo.half_width() - 1.0,
				"across every floor lane, short of the side walls by the strip a wall runner passes in %s" % tag)
			check(size.y > jump_top, "taller than any jump (%.1f m against %.1f m) %s" % [size.y, jump_top, tag])
			var hitbox: Hazard = b.hitbox()
			check(hitbox != null and hitbox.is_solid and hitbox.armor_blocks_solid and hitbox.breakable == b
				and hitbox.collision_layer == TrackBuilder.LAYER_HAZARD and not hitbox.is_electrical and not hitbox.is_enemy_attack
				and hitbox.enemy == null, "its hitbox: a solid hazard armor absorbs, which breaks it %s" % tag)
			if hitbox == null:
				continue
			var hb: AABB = AABB(hitbox.global_position - hitbox.size * 0.5, hitbox.size)
			var look: AABB = b.world_box()
			check(hb.position.x > look.position.x and hb.end.x < look.end.x and hb.end.z < look.end.z
				and is_equal_approx(hb.position.z, look.position.z) and is_equal_approx(hb.end.y, look.end.y),
				"a little smaller than its look at its sides and its face %s" % tag)
			check(hb.position.y <= TrackBuilder.DASH_WALL_FLOOR_LIFT + 0.001 and hb.position.y > 0.0,
				"from just above the floor: a slide never passes under it %s" % tag)
			check(not b.debris_colors.is_empty() and b.debris_colors == skin.dash_wall_debris_colors(b, int(w["seed"])),
				"the skin names its pieces' colours %s" % tag)
		for call: Dictionary in skin.calls:
			var b := call["body"] as DashBreakable
			check(b != null and (call["size"] as Vector3).is_equal_approx(size) and int(call["seed"]) == int(b.entry["seed"]),
				"the skin's hook gets the wall's box and its seed %s" % tag)
		root.queue_free()
		await tree.process_frame


# --- The damage rules ----------------------------------------------------------------------------

## A dash wall's hitbox through DamageRules: the dash passes it, armor absorbs the crash (an exception to
## armor's rule for solid hits), then the shield, otherwise it kills; god mode and the invulnerability window
## ignore it. A sign stays a solid hit armor never blocks.
func _test_damage_rules() -> void:
	var wall := Hazard.new()
	wall.is_solid = true
	wall.armor_blocks_solid = true
	var sign := Hazard.new()
	sign.is_solid = true
	var d := DamageRules.Defense.new()
	check(DamageRules.resolve(wall, d) == O.KILL, "with no protection, the crash kills")
	d.dashing = true
	check(DamageRules.resolve(wall, d) == O.IGNORE, "the dash passes it")
	d.dashing = false
	d.armor = true
	d.shield = true
	check(DamageRules.resolve(wall, d) == O.BLOCKED_ARMOR, "armor absorbs the crash first")
	check(DamageRules.resolve(sign, d) == O.BLOCKED_SHIELD, "a sign stays a solid hit armor never blocks")
	d.armor = false
	check(DamageRules.resolve(wall, d) == O.BLOCKED_SHIELD, "then the shield")
	d.shield = false
	d.god_mode = true
	check(DamageRules.resolve(wall, d) == O.IGNORE, "god mode ignores it")
	d.god_mode = false
	d.invulnerable = true
	check(DamageRules.resolve(wall, d) == O.IGNORE, "the invulnerability window ignores it")
	wall.free()
	sign.free()


# --- On real physics -----------------------------------------------------------------------------

## A dash into a wall at 3, 5 and 6 lanes, in every lane: it smashes it once (dash_wall_smash), broken by the
## dash, a frame before the body would touch it; no hit, the lane kept and the run's speed after it unchanged.
func _test_dash_through() -> void:
	sim.trace = true
	for lanes: int in [3, 5, 6]:
		for lane: int in lanes:
			var layout := _one_wall(lanes, 90.0)
			var w: Dictionary = layout.dash_walls[0]
			var dash_at: Array = [[90.0 - 0.6 * _dash_length(tuning.run_speed), &"dash"]]
			var r: Dictionary = await sim.run(layout, lane, 7.0, dash_at)
			var plain: Dictionary = await sim.run(RunSim.layout(lanes, 300.0), lane, 7.0, dash_at)
			var events: Array = r["events"]
			var tag: String = "(%d lanes, lane %d)" % [lanes, lane]
			check(r["alive"] and int(r["smashes"]) == 1 and int(r["crashes"]) == 0 and int(r["wall_passes"]) == 0
				and events.count(&"dash_wall_smash") == 1, "a dash smashes it, once, unhurt (%s) %s" % [events, tag])
			check(bool(w.get("smashed", false)) and String(w.get("broken_by", "")) == "dash", "broken by the dash %s" % tag)
			check(_touch(r["trace"], 90.0) <= TOUCH_TOLERANCE, "before the body touches it (%.3f m in) %s"
				% [_touch(r["trace"], 90.0), tag])
			check(int(r["lane"]) == lane, "the runner keeps their lane %s" % tag)
			check(absf(float(r["distance"]) - float(plain["distance"])) < 0.01,
				"and runs on as far as with no wall there: it costs no speed (%.2f m, %.2f m) %s"
				% [float(r["distance"]), float(plain["distance"]), tag])
	sim.trace = false


## Without the dash a runner crashes into it at 3, 5 and 6 lanes, in every lane (the outer ones too: the strip
## by the side wall is for wall runners): with no protection the crash kills ("dash wall"), at its face, and the
## wall breaks all the same (broken by the crash). A dash that ends before the body gets there crashes too.
func _test_crash() -> void:
	for lanes: int in [3, 5, 6]:
		for lane: int in lanes:
			var layout := _one_wall(lanes, 90.0)
			var w: Dictionary = layout.dash_walls[0]
			var r: Dictionary = await sim.run(layout, lane, 7.0, [])
			var tag: String = "(%d lanes, lane %d)" % [lanes, lane]
			check(not r["alive"] and String(r["cause"]) == "dash wall" and int(r["crashes"]) == 1 and int(r["smashes"]) == 0,
				"without the dash and with no protection the crash kills (%s) %s" % [r["cause"], tag])
			check(float(r["distance"]) >= 90.0 - tuning.visual_size.z and float(r["distance"]) <= 90.0 + 0.5,
				"at its face (%.2f m) %s" % [float(r["distance"]), tag])
			check(bool(w.get("smashed", false)) and String(w.get("broken_by", "")) == "crash", "and it breaks all the same %s" % tag)
	var short := _one_wall(3, 90.0)
	var ended: Dictionary = await sim.run(short, 1, 7.0, [[90.0 - 2.5 * _dash_length(tuning.run_speed), &"dash"]])
	check(not ended["alive"] and int(ended["crashes"]) == 1 and int(ended["smashes"]) == 0,
		"a dash that ends before the body gets there crashes")


## A jump into it (taller than any jump) and a slide into it (its hitbox reaches the floor) both crash; a dash in
## the air smashes it.
func _test_jump_and_slide() -> void:
	for lanes: int in [3, 6]:
		var tag: String = "(%d lanes)" % lanes
		var jumped: Dictionary = await sim.run(_one_wall(lanes, 90.0), 1, 7.0, [[84.0, &"jump"]])
		check(not jumped["alive"] and String(jumped["cause"]) == "dash wall", "a jump into it crashes " + tag)
		var slid: Dictionary = await sim.run(_one_wall(lanes, 90.0), 1, 7.0, [[87.5, &"slide"]])
		check(not slid["alive"] and String(slid["cause"]) == "dash wall", "a slide into it crashes " + tag)
		var aerial: Dictionary = await sim.run(_one_wall(lanes, 90.0), 1, 7.0, [[84.0, &"jump"], [85.0, &"dash"]])
		check(aerial["alive"] and int(aerial["smashes"]) == 1, "a dash in the air smashes it " + tag)


## A runner on either side wall passes it at 3, 5 and 6 lanes: stepping onto the wall from the outer lane
## before it, they run past it untouched, and it crumbles as they reach its face (broken by the pass), costing
## nothing; the same runner staying in the outer lane crashes (above).
func _test_wall_runner() -> void:
	for lanes: int in [3, 5, 6]:
		for side: int in [-1, 1]:
			var lane: int = 0 if side < 0 else lanes - 1
			var layout := _one_wall(lanes, 90.0)
			var w: Dictionary = layout.dash_walls[0]
			var r: Dictionary = await sim.run(layout, lane, 7.0, [[72.0, &"move_left" if side < 0 else &"move_right"]], [90.0])
			var tag: String = "(%d lanes, %s wall)" % [lanes, "left" if side < 0 else "right"]
			var at: Dictionary = (r["at"] as Dictionary).get(90.0, {})
			check(String(at.get("surface", "")) == "wall", "the runner is on the wall at its face (%s) %s" % [at.get("surface", ""), tag])
			check(r["alive"] and int(r["wall_passes"]) == 1 and int(r["crashes"]) == 0 and int(r["smashes"]) == 0,
				"a wall runner passes it unhurt (%s) %s" % [r["cause"], tag])
			check(bool(w.get("smashed", false)) and String(w.get("broken_by", "")) == "pass", "it crumbles as they pass %s" % tag)


# --- In a full world -----------------------------------------------------------------------------

## In a full world: the armor absorbs a crash (armor_break, the invulnerability window, alive), a shield
## absorbs one when the armor's down, god mode shrugs one off; the wall breaks every time, the crash counted.
func _test_world_protection() -> void:
	var layout := RunSim.layout(3, 600.0)
	for face: float in [60.0, 160.0, 260.0]:
		layout.dash_walls.append(_wall(face))
	var w: RunWorld = sim.build_world(layout)
	var p: Player = w.player
	p.armor = 1
	var events: Array[StringName] = []
	p.movement_event.connect(func(kind: StringName) -> void: events.append(kind))
	await _run_until(w, 6.0, func() -> bool: return p.crashes >= 1)
	check(p.alive and p.crashes == 1 and events.has(&"armor_break") and p.invulnerable_left > 0.0 and not p.armor_state.is_up(),
		"the armor absorbs a crash, and the invulnerability window follows (%s)" % [events])
	check(bool(layout.dash_walls[0].get("smashed", false)) and not _standing_at(w, layout.dash_walls[0]), "the wall breaks")
	p.shield = 1
	await _run_until(w, 8.0, func() -> bool: return p.crashes >= 2)
	check(p.alive and p.crashes == 2 and events.has(&"shield_break") and p.shield == 0, "with the armor down, the shield absorbs one")
	p.god_mode = true
	await _run_until(w, 8.0, func() -> bool: return p.crashes >= 3)
	check(p.alive and p.crashes == 3 and bool(layout.dash_walls[2].get("smashed", false)), "god mode shrugs one off, and it breaks")
	await sim.free_world(w)


## A dash wall crumbling in a full world in the Corporate look, carrying the dash: its pieces fly (RunEffects
## .crumble) in its look's own colours, lit and never glowing, gone within their life, with dust from its foot;
## the camera shakes harder than for a doodad (none with Screen shake off); the crash's sound plays; nothing
## protective is used up by the dash; Reduced flashing changes nothing (nothing in it flashes). The warm-up
## draws its look, its pieces and its dust while the level loads.
func _test_world_crumble() -> void:
	var layout := RunSim.layout(3, 600.0)
	var first: Dictionary = _wall(80.0, 2)
	var second: Dictionary = _wall(330.0, 5)
	layout.dash_walls.append(first)
	layout.dash_walls.append(second)
	var loadout := Loadout.new()
	loadout.tiers[&"dash"] = 4
	var config := LevelConfig.new()
	config.skin = load("res://data/skins/corporate_skin.tres") as ZoneSkin
	var w: RunWorld = sim.build_world(layout, loadout, null, config)
	var parts: Array[GeometryInstance3D] = w.effects.crumble_parts()
	check(parts.size() == 2 and not parts[0].visible and not parts[1].visible, "the crumble's pieces and dust wait hidden, made at the load")
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	var stage := ShaderWarmup.new()
	stage.setup(w, camera)
	var look := Node3D.new()
	config.skin.dash_wall(look, TrackBuilder.dash_wall_size(w.geo, w.tuning, w.tuning.dash_wall_depth), 0)
	var look_mesh := look.get_child(0) as MeshInstance3D
	var drawn: bool = false
	for n: Node in stage.find_children("*", "MeshInstance3D", true, false):
		drawn = drawn or ((n as MeshInstance3D).mesh == look_mesh.mesh and (n as MeshInstance3D).material_override == look_mesh.material_override)
	check(drawn and stage.keys.has("multimesh10|ArrayMesh|%s" % ShaderWarmup.shader_key(MeshKit.solid())),
		"the warm-up draws the wall's look and its pieces while the level loads")
	var dust := parts[1] as CPUParticles3D
	var dust_key: String = "particles|%s|%s" % [dust.mesh.get_class(), ShaderWarmup.shader_key(dust.material_override)]
	check(stage.keys.has(dust_key), "and its dust (%s)" % dust_key)
	look.free()
	stage.queue_free()
	camera.queue_free()
	await tree.process_frame
	var p: Player = w.player
	p.armor = 1
	var fx: SpeedFxTuning = w.effects.tuning
	var crumbled: Array[DashBreakable] = []
	var sounds: Array[StringName] = []
	var shakes: Array[float] = []
	w.effects.crumbled.connect(func(b: DashBreakable) -> void: crumbled.append(b))
	w.sounds.requested.connect(func(s: StringName) -> void: sounds.append(s))
	w.effects.shake_requested.connect(func(strength: float, _duration: float) -> void: shakes.append(strength))
	await _run_until(w, 5.0, func() -> bool: return p.distance >= 80.0 - _dash_length(w.tuning.run_speed) * 0.6)
	var body: DashBreakable = w.track.dash_wall_for(first)
	check(body != null and not body.debris_colors.is_empty() and _standing_at(w, first), "the wall stands, built with its look's colours")
	if body == null:
		await sim.free_world(w)
		return
	check(bool(w.powerups.call(&"try_dash")), "the dash starts")
	await _run_until(w, 2.0, func() -> bool: return not crumbled.is_empty())
	check(crumbled.size() == 1 and crumbled[0] == body and p.smashes == 1 and not _standing_at(w, first) and not body.visible,
		"the dash smashes it: it crumbles, its box, hitbox and look gone")
	check(sounds.count(&"dash_wall_smash") == 1, "the crash's sound plays, once (%s)" % [sounds])
	check(w.effects.crumble_active(), "its pieces fly")
	var burst := parts[0] as RubbleBurst
	var lit: bool = burst.material_override == MeshKit.solid() and burst.count > RubbleBurst.MAX_PIECES
	var own: bool = true
	for i: int in burst.count:
		var c: Color = burst.piece_colors[i]
		lit = lit and c.a == 0.0
		var found: bool = false
		for o: Color in body.debris_colors:
			var k: float = c.r / maxf(o.r, 0.0001)
			found = found or (k >= 0.84 and k <= 1.09 and absf(c.g - o.g * k) < 0.002 and absf(c.b - o.b * k) < 0.002)
		own = own and found
	check(lit, "more pieces than a doodad's, lit on the kit's solid material, never glowing (%d)" % burst.count)
	check(own, "in the wall's own colours, a shade either way")
	check(dust.visible and dust.emitting and dust.color.a <= fx.wall_dust_opacity + 0.001 and dust.color.a > 0.0,
		"dust rolls out from its foot, see-through")
	check(shakes.has(fx.wall_shake_strength) and fx.wall_shake_strength > fx.smash_shake_strength,
		"a heavier shake than a doodad's (%.2f): %s" % [fx.wall_shake_strength, shakes])
	check(p.alive and p.armor == 1 and p.invulnerable_left == 0.0 and p.crashes == 0, "the dash costs nothing: no hit")
	await _run_until(w, fx.wall_rubble_life + 0.3, func() -> bool: return false)
	check(not w.effects.crumble_active(), "the pieces are gone within their life")
	# The second, with Screen shake off and Reduced flashing on: it crumbles the same, with no shake.
	w.effects.shake_scale = 0.0
	p.steady_flash = true
	var shaken: int = shakes.size()
	await _run_until(w, 14.0, func() -> bool: return p.distance >= 330.0 - _dash_length(w.tuning.run_speed) * 0.6)
	check(bool(w.powerups.call(&"try_dash")), "the dash is back for the second")
	await _run_until(w, 2.0, func() -> bool: return crumbled.size() == 2)
	check(crumbled.size() == 2 and w.effects.crumble_active() and shakes.size() == shaken,
		"with Screen shake off it shakes nothing, and with Reduced flashing it crumbles as before")
	await sim.free_world(w)


## It stays broken for the rest of the attempt, and a retry rebuilds it whole. A quick run of Corporate 1 at 3
## lanes (its own seed, the walls' introduction moved to the run-up's end so the first comes early; god mode and
## no falls, the runner keeping to the middle lane) crashes through its first wall. Through a death and a revive
## it stays broken (its entry marked, nothing standing there). LevelRun's retry plays a fresh copy of the level's
## build (LevelCache, task PERF2; the crash marked only the attempt's own copy): the very same layout as before the
## crash, the wall whole on the track.
func _test_retry() -> void:
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.config = campaign.configure(campaign.step("corporate/1"), 3)
	ctx.config.feature_starts["dash_wall"] = 0.0
	ctx.tuning = tuning
	ctx.loadout = Loadout.new()
	ctx.god_mode = true
	ctx.no_fall = true
	var run := LevelRun.new()
	tree.root.add_child(run)
	run.start(ctx)
	var before: String = JSON.stringify(run.world.layout.to_dict())
	check(not run.world.layout.dash_walls.is_empty(), "Corporate 1 has dash walls at 3 lanes")
	if run.world.layout.dash_walls.is_empty():
		run.queue_free()
		await tree.process_frame
		return
	var wall: Dictionary = run.world.layout.dash_walls[0]
	var w: RunWorld = run.world
	var face: float = float(wall["start"])
	check(face < 900.0, "its first wall comes early (%.0f m)" % face)
	var limit: float = face / w.tuning.run_speed + 6.0
	await _run_until(w, limit, func() -> bool: return w.player.crashes > 0 or w.player.distance > face + 5.0)
	check(w.player.crashes == 1 and bool(wall.get("smashed", false)) and not _standing_at(w, wall),
		"the runner crashes through it (god mode): it breaks")
	w.player._die("test hazard")
	await _run_until(w, 0.1, func() -> bool: return false)
	check(run.state == LevelRun.State.DEAD, "the runner dies")
	run.revive()
	await _run_until(w, 0.5, func() -> bool: return false)
	check(run.state == LevelRun.State.RUNNING and w.player.alive and bool(wall.get("smashed", false)) and not _standing_at(w, wall),
		"through a death and a revive it stays broken: nothing builds it again")
	run.restart(run.context.retry())
	var reused: bool = LevelCache.last_reused
	await tree.physics_frame
	w = run.world
	var again: Dictionary = w.layout.dash_walls[0]
	check(JSON.stringify(w.layout.to_dict()) == before and not again.has("smashed") and not again.has("broken_by")
		and (reused or not LevelCache.enabled),
		"a retry plays the very same level, a copy of its build (LevelCache, task PERF2; reused: %s), the wall whole in its data" % reused)
	await _run_until(w, limit, func() -> bool: return w.player.distance >= float(again["start"]) - 30.0)
	var rebuilt: DashBreakable = w.track.dash_wall_for(again)
	check(rebuilt != null and not rebuilt.is_smashed() and rebuilt.visible and rebuilt.collision_layer == TrackBuilder.LAYER_DASH_WALL
		and _standing_at(w, again), "and on the track: built whole")
	run.queue_free()
	await tree.process_frame


# --- The look ------------------------------------------------------------------------------------

## Every skin's dash wall (ZoneSkin.dash_wall): under the wall's node, inside its box and filling its face, lit and
## never glowing, the same mesh for the same box and seed (cached), a few looks over the seeds (all 12 layouts and tones
## at 3, 5 and 6 lanes); its pieces' colours are its look's own lit colours; a zone's is its own look, not the
## default's (no material override on the instance: DashWallKit.dress); and it has no bite in its roofline the runner
## could see through, a jump's reach under (SILHOUETTE_MIN over the lanes, from the mesh's triangles).
func _test_skins() -> void:
	var skins: Array[ZoneSkin] = [GreyboxSkin.new()]
	var names: PackedStringArray = ["grey box"]
	for file: String in DirAccess.get_files_at("res://data/skins"):
		var path: String = "res://data/skins".path_join(file)
		if file.ends_with(".tres") and load(path) is ZoneSkin:
			skins.append(load(path) as ZoneSkin)
			names.append(file)
	check(skins.size() >= 8, "every skin looked at (%d)" % skins.size())
	for lanes: int in LANE_COUNTS:
		var geo := TrackGeometry.new(lanes, tuning)
		var size: Vector3 = TrackBuilder.dash_wall_size(geo, tuning, tuning.dash_wall_depth)
		# The lanes the hitbox covers: the box less its inset at each side, within the floor.
		var reach: float = minf(size.x * 0.5 - tuning.dash_wall_inset, geo.half_width())
		for i: int in skins.size():
			var skin: ZoneSkin = skins[i]
			# The grey box (and the skin file made from it) keeps the default look; every zone has one of its own.
			var own_look: bool = names[i] != "grey box" and names[i] != "greybox_skin.tres"
			var meshes: Dictionary = {}
			var lowest: float = INF
			for look_seed: int in LOOK_SEEDS:
				var tag: String = "(%s, %d lanes, seed %d)" % [names[i], lanes, look_seed]
				var body := Node3D.new()
				skin.dash_wall(body, size, look_seed)
				var insts: Array[Node] = body.find_children("*", "MeshInstance3D", true, false)
				check(not insts.is_empty() and body.get_child_count() > 0, "it dresses the wall under its node " + tag)
				var colors: PackedColorArray = skin.dash_wall_debris_colors(body, look_seed)
				var own: Dictionary = {}
				for n: Node in insts:
					var inst := n as MeshInstance3D
					check(not inst.top_level, "nothing of it is top-level " + tag)
					# The default look draws every instance with one material_override; a zone's own look leaves it to
					# its surfaces' materials (DashWallKit.dress).
					check((inst.material_override == null) == own_look,
						"the zone has a look of its own, the default's has an override (%s) %s" % [names[i], tag])
					var aabb: AABB = inst.mesh.get_aabb()
					var half: Vector3 = size * 0.5 + Vector3.ONE * 0.001
					check(aabb.position.x >= -half.x and aabb.position.y >= -half.y and aabb.position.z >= -half.z
						and aabb.end.x <= half.x and aabb.end.y <= half.y and aabb.end.z <= half.z,
						"inside its box (%s in %s) %s" % [aabb, size, tag])
					check(aabb.size.x >= size.x - 0.01 and aabb.size.y >= size.y - 0.01 and aabb.end.z >= half.z - 0.01,
						"filling its face %s" % tag)
					var glows: bool = false
					var lit_materials: bool = inst.mesh.get_surface_count() > 0
					for surface: int in inst.mesh.get_surface_count():
						for col: Color in inst.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:
							glows = glows or col.a > 0.0
							if col.a == 0.0:
								own[Color(col.r, col.g, col.b)] = true
						# Each surface draws with a material the skin names (its own facade shader or the solid kit),
						# the instance's override or the surface's own.
						var mat: Material = inst.get_active_material(surface)
						lit_materials = lit_materials and mat != null and mat in skin.dash_wall_materials()
					check(not glows and lit_materials, "lit, never glowing (materials the skin names) %s" % tag)
					meshes[inst.mesh] = true
					var vertices: int = 0
					for surface: int in inst.mesh.get_surface_count():
						vertices += inst.mesh.surface_get_array_len(surface)
					check(inst.mesh.get_surface_count() <= WALL_SURFACES_MAX and vertices <= WALL_VERTICES_MAX,
						"one small mesh (%d surfaces, %d vertices) %s" % [inst.mesh.get_surface_count(), vertices, tag])
				var inside: bool = not colors.is_empty()
				for c: Color in colors:
					var found: bool = false
					for o: Color in own:
						found = found or (absf(o.r - c.r) < 0.0045 and absf(o.g - c.g) < 0.0045 and absf(o.b - c.b) < 0.0045)
					inside = inside and found
				check(inside, "its pieces take its look's own lit colours (%s) %s" % [colors, tag])
				var top: float = _lowest_top(insts, -reach, reach) + size.y * 0.5
				lowest = minf(lowest, top)
				check(top >= SILHOUETTE_MIN, "no bite out of its roofline (lowest top %.2f m over the lanes, at least %.1f) %s" % [
					top, SILHOUETTE_MIN, tag])
				var twin := Node3D.new()
				skin.dash_wall(twin, size, look_seed)
				check((twin.get_child(0) as MeshInstance3D).mesh == (body.get_child(0) as MeshInstance3D).mesh,
					"the same mesh for the same box and seed (built once) %s" % tag)
				body.free()
				twin.free()
			check(meshes.size() >= 4, "a few looks over the seeds (%d) (%s, %d lanes)" % [meshes.size(), names[i], lanes])
			if lanes == LANE_COUNTS[0]:
				print("  dash wall (%s): lowest silhouette top over the lanes %.2f m" % [names[i], lowest])
	_test_corporate_seeds()
	_test_skin_build_times(skins, names)


## The lowest the front silhouette of `insts` (MeshInstance3D nodes, in their body's space) gets across x in [x0, x1],
## in the body's own y: the highest point of any triangle in each of SILHOUETTE_COLUMNS columns, the least of those
## (-INF where a column is open: nothing covers it). From the triangles, not the bounding box, so a bite taken out of
## a roofline shows.
func _lowest_top(insts: Array[Node], x0: float, x1: float) -> float:
	var tops := PackedFloat32Array()
	tops.resize(SILHOUETTE_COLUMNS)
	tops.fill(-INF)
	var step: float = (x1 - x0) / float(SILHOUETTE_COLUMNS - 1)
	var tri: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for n: Node in insts:
		var inst := n as MeshInstance3D
		var moved: bool = inst.transform != Transform3D.IDENTITY
		for surface: int in inst.mesh.get_surface_count():
			var arrays: Array = inst.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			var count: int = verts.size() if indices.is_empty() else indices.size()
			for t: int in range(0, count - 2, 3):
				for k: int in 3:
					var v: Vector3 = verts[t + k if indices.is_empty() else indices[t + k]]
					if moved:
						v = inst.transform * v
					tri[k] = Vector2(v.x, v.y)
				_raise_columns(tops, tri, x0, step)
	var lowest: float = INF
	for c: int in SILHOUETTE_COLUMNS:
		lowest = minf(lowest, tops[c])
	return lowest


## Raises each column `tops` (at x0 + i * step) that the triangle `tri` (x, y) covers to the triangle's highest point
## there.
func _raise_columns(tops: PackedFloat32Array, tri: Array[Vector2], x0: float, step: float) -> void:
	var lo: float = minf(tri[0].x, minf(tri[1].x, tri[2].x))
	var hi: float = maxf(tri[0].x, maxf(tri[1].x, tri[2].x))
	if hi - lo < 0.0001:
		return
	var first: int = maxi(ceili((lo - x0) / step - 0.0001), 0)
	var last: int = mini(floori((hi - x0) / step + 0.0001), tops.size() - 1)
	for c: int in range(first, last + 1):
		var x: float = x0 + float(c) * step
		var best: float = -INF
		for e: int in 3:
			var p: Vector2 = tri[e]
			var q: Vector2 = tri[(e + 1) % 3]
			if absf(p.x - q.x) < 0.00001 or x < minf(p.x, q.x) - 0.00001 or x > maxf(p.x, q.x) + 0.00001:
				continue
			best = maxf(best, lerpf(p.y, q.y, clampf((x - p.x) / (q.x - p.x), 0.0, 1.0)))
		tops[c] = maxf(tops[c], best)


## Corporate's podium seeds are hard-coded by what the shader draws for them (corp_facade.gdshader gives a podium its
## smoked-glass lobby where hash11(seed * 1.7 + 0.3) < 0.45; DashWallKit.hash11 replicates the hash): the solid ones have
## no lobby and the lobby ones have it, each well clear of the threshold.
func _test_corporate_seeds() -> void:
	var sets: Array[Dictionary] = [
		{"name": "solid", "seeds": CorporateDashWall.SEEDS_SOLID, "lobby": false},
		{"name": "lobby", "seeds": CorporateDashWall.SEEDS_LOBBY, "lobby": true},
		{"name": "podium", "seeds": CorporateDashWall.SEEDS_PODIUM, "lobby": false},
	]
	for entry: Dictionary in sets:
		var seeds: Array = entry["seeds"]
		check(seeds.size() == 3, "a podium seed per tone (%s)" % entry["name"])
		for podium_seed: int in seeds:
			var h: float = DashWallKit.hash11(float(podium_seed) * 1.7 + 0.3)
			check((h < 0.45) == entry["lobby"] and absf(h - 0.45) >= SHADER_HASH_MARGIN,
				"seed %d draws a %s podium, well clear of the shader's threshold (hash %.3f)" % [podium_seed, entry["name"], h])


## A zone's walls are cheap to build: every layout and tone (12 seeds) in a box of a size not built before, in a skin
## whose materials already exist (they are made the first time a wall is, and again by every chunk's walls).
func _test_skin_build_times(skins: Array[ZoneSkin], names: PackedStringArray) -> void:
	var geo := TrackGeometry.new(6, tuning)
	for i: int in skins.size():
		var skin: ZoneSkin = skins[i]
		skin.dash_wall_materials()
		var size: Vector3 = TrackBuilder.dash_wall_size(geo, tuning, tuning.dash_wall_depth)
		size.x += 0.0371
		var total: float = 0.0
		var worst: float = 0.0
		for look_seed: int in 12:
			var body := Node3D.new()
			var t0: int = Time.get_ticks_usec()
			skin.dash_wall(body, size, look_seed)
			var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
			total += ms
			worst = maxf(worst, ms)
			body.free()
		print("  dash wall (%s, 12 looks built): mean %.2f ms, max %.2f ms" % [names[i], total / 12.0, worst])
		check(total / 12.0 < WALL_BUILD_MEAN_MS and worst < WALL_BUILD_MAX_MS, "a wall builds in a moment (%s: mean %.2f ms, max %.2f ms)" % [
			names[i], total / 12.0, worst])


## The first-encounter hint (data/hints/hints.json, trigger dash_wall): it says to dash through, names the dash
## action, and is picked for a level whose layout has a wall (HintDirector), not for one without.
func _test_hint() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var hint: Dictionary = {}
	for h: Dictionary in (parsed as Dictionary).get("hints", []):
		if String(h.get("id", "")) == "dash_wall":
			hint = h
	check(String(hint.get("trigger", "")) == "dash_wall" and String(hint.get("text", "")).contains("{dash}")
		and String(hint.get("text", "")).to_lower().contains("dash through"), "the hint says to dash through (%s)" % [hint])
	var text: String = String(hint.get("text", "")).to_lower()
	check(text.contains("armor") and text.contains("shield") and text.contains("kills"),
		"and what a crash without the dash costs: the armor or the shield, else a death (%s)" % text)
	for with_wall: bool in [true, false]:
		var world := RunWorld.new()
		world.config = LevelConfig.new()
		world.layout = RunSim.layout(3)
		if with_wall:
			world.layout.dash_walls.append(_wall(120.0))
		world.director = EnemyDirector.new()
		world.add_child(world.director)
		var director := HintDirector.new()
		director.setup(world, Profile.new(), false)
		var ids: Array = director.intro_hints.map(func(entry: Dictionary) -> String: return entry["id"])
		check(ids.has("dash_wall") == with_wall, "the hint is picked %s (%s)" % ["for a wall" if with_wall else "only with a wall", ids])
		if with_wall:
			for entry: Dictionary in director.intro_hints:
				if entry["id"] == "dash_wall":
					check(not String(entry["text"]).contains("{"), "its text names the dash's key (%s)" % entry["text"])
		director.free()
		world.free()


# --- The enemies ---------------------------------------------------------------------------------

## A hover truck pacing ahead gives way to a dash wall (GDD §9.14; HoverTruck._wall_ahead): before the runner
## reaches the wall it has dropped behind them, so the runner meets the wall first and breaks it, and the truck
## never bursts through it; it doesn't rev for its forward lurch with a wall coming; past the wall it paces again.
func _test_truck_gives_way() -> void:
	var layout := RunSim.layout(3, 900.0)
	layout.dash_walls.append(_wall(220.0))
	var w: RunWorld = sim.build_world(layout)
	w.player.god_mode = true
	w.player.setup(w.tuning, w.geo, 0)
	var truck := w.director.spawn({"type": "hover_truck", "at": 0.0, "lane": 2, "side": 1, "seed": 5,
		"params": {"skip_entrance": true, "phase": "pace", "offset": 10.0, "guns": false, "stay": 60.0}}) as TruckScript
	var face: float = 220.0
	var ahead_at_face: Array = [false]
	var revved_near: Array = [false]
	var paced_before: Array = [false]
	var behind_at_face: Array = [false]
	var paced_after: Array = [false]
	await _run_until(w, 20.0, func() -> bool:
		if not is_instance_valid(truck):
			return true
		var nose: float = w.player.distance + truck.offset + truck.tune.length * 0.5 + truck.tune.nose_length
		var standing: bool = not bool(layout.dash_walls[0].get("smashed", false))
		if standing and nose >= face:
			ahead_at_face[0] = true
		if face - w.player.distance > 100.0 and truck.state == TruckScript.State.PACE and truck.offset > 5.0:
			paced_before[0] = true
		if standing and face - w.player.distance < 1.0:
			behind_at_face[0] = nose < w.player.distance
		if not standing and truck.state == TruckScript.State.PACE:
			paced_after[0] = true
		if truck.state == TruckScript.State.REV and face - w.player.distance > 0.0 and face - w.player.distance < 60.0:
			revved_near[0] = true
		return w.player.distance > face + 150.0)
	check(is_instance_valid(truck), "the truck is still about")
	check(paced_before[0], "it paces ahead of the runner before the wall")
	check(not ahead_at_face[0] and truck.walls_burst == 0 and behind_at_face[0],
		"its nose never reaches the standing wall: it has dropped behind the runner as they reach it")
	check(String(layout.dash_walls[0].get("broken_by", "")) in ["dash", "crash", "pass"], "the runner breaks the wall first (%s)"
		% layout.dash_walls[0].get("broken_by", ""))
	check(not revved_near[0], "no rev for its forward lurch with the wall coming")
	check(paced_after[0], "past the wall it paces again")
	await sim.free_world(w)


## Where a hover truck can't give way (the runner in its lane behind it: it never backs into them), its nose bursts
## through a standing wall it reaches, as it burst out of the building: the wall crumbles with its crash, broken
## by the truck, before the runner gets there; the runner then meets nothing.
func _test_truck_bursts_through() -> void:
	var layout := RunSim.layout(3, 900.0)
	layout.dash_walls.append(_wall(200.0))
	var w: RunWorld = sim.build_world(layout)
	w.player.god_mode = true
	w.player.setup(w.tuning, w.geo, 2)
	var truck := w.director.spawn({"type": "hover_truck", "at": 0.0, "lane": 2, "side": 1, "seed": 5,
		"params": {"skip_entrance": true, "phase": "pace", "offset": 10.0, "guns": false, "stay": 60.0}}) as TruckScript
	var crumbled: Array[DashBreakable] = []
	w.effects.crumbled.connect(func(b: DashBreakable) -> void: crumbled.append(b))
	await _run_until(w, 15.0, func() -> bool: return w.player.distance > 230.0 or not is_instance_valid(truck))
	check(is_instance_valid(truck) and truck.walls_burst == 1 and String(layout.dash_walls[0].get("broken_by", "")) == "hover_truck",
		"boxed in, the truck bursts through the wall (%s)" % layout.dash_walls[0].get("broken_by", ""))
	check(crumbled.size() == 1 and w.player.crashes == 0 and w.player.wall_passes == 0, "it crumbles, and the runner meets nothing")
	await sim.free_world(w)


## A heli drone hovering ahead of the runner rises over a standing dash wall in its way and comes back down past
## it (Enemy.dash_wall_lift): over the wall's top while its body is over the wall, back at its hover height well
## past it; and it never winds up a barrage with a wall within its reach.
func _test_drone_rises() -> void:
	var layout := RunSim.layout(3, 900.0)
	var face: float = 300.0
	layout.dash_walls.append(_wall(face))
	var w: RunWorld = sim.build_world(layout)
	w.player.god_mode = true
	w.player.setup(w.tuning, w.geo, 1)
	var d := w.director.spawn({"type": "drone", "at": 20.0, "lane": 1, "side": 0, "seed": 7, "params": {"slot": 0}}) as DroneScript
	var top: float = w.tuning.dash_wall_height
	# The barrage's reach (Drone._doodad_in_reach): its wind-up, its bullets and their flight, at the player's speed.
	var s: float = w.config.enemy_scaling
	var window: float = w.rules.hit_invulnerability if w.rules != null else 1.0
	var flight: float = d.tune.hover_ahead / maxf(d.tune.bullet_speed_at(s), 1.0) + d.tune.bullet_overshoot
	var seconds: float = d.tune.windup_at(s) + d.tune.barrage_count(s, window) * d.tune.bullet_interval_at(s) + flight
	var under: Array = [false]
	var over: Array = [false]
	var wound_near: Array = [false]
	var was: Array = [d.state]
	await _run_until(w, 25.0, func() -> bool:
		if not is_instance_valid(d):
			return true
		var at: float = d.track_distance()
		var standing: bool = not bool(layout.dash_walls[0].get("smashed", false))
		if standing and at >= face - 1.0 and at <= face + w.tuning.dash_wall_depth + 1.0:
			if d.global_position.y < top + 0.2:
				under[0] = true
			else:
				over[0] = true
		var gap: float = face - w.player.distance
		if d.state == DroneScript.State.WINDUP and was[0] != DroneScript.State.WINDUP \
				and gap > -1.0 and gap < w.player.speed * seconds:
			wound_near[0] = true
		was[0] = d.state
		return w.player.distance > face + 150.0)
	check(is_instance_valid(d), "the drone is still about")
	check(over[0] and not under[0], "it flies over the standing wall, never through it")
	check(is_instance_valid(d) and d.lift < 0.5, "and comes back down past it (%.2f m up)" % (d.lift if is_instance_valid(d) else -1.0))
	check(not wound_near[0], "it never winds up with the wall within its barrage's reach")
	await sim.free_world(w)


## A panic cyborg ahead of a wall (task H7a; CyborgRules.obstacle_spans holds every wall's footprint): its run
## stops its obstacle margin short of the wall's clear approach, so it never runs through the standing wall nor
## cowers in the clear stretch behind it; one standing past a wall never walks back into that stretch.
func _test_panic_cyborg() -> void:
	var ct := EnemyDirector.tuning_for("cyborg") as CyborgTuning
	var t: DashWallTuning = DashWallTuning.load_default()
	var face: float = 150.0
	var layout := RunSim.layout(3, 600.0)
	var w_entry: Dictionary = _wall(face)
	layout.dash_walls.append(w_entry)
	var w: RunWorld = sim.build_world(layout)
	w.player.god_mode = true
	var fp: Vector2 = t.footprint(w_entry, w.tuning.run_speed + powerups.dash_speed_bonus)
	var margin: float = CyborgRules.obstacle_margin_at(ct, w.tuning.pace())
	# Its run unclamped (panic_run_max) would carry it past the wall.
	var home: float = face - 30.0
	check(home + ct.panic_run_max * w.tuning.pace() > face + tuning.dash_wall_depth, "the cyborg's own run would reach past the wall")
	var c := w.director.spawn({"type": "cyborg", "at": home, "lane": 0, "side": 0, "seed": 4,
		"params": {"panic": true, "fires": false}}) as Cyborg
	var behind := w.director.spawn({"type": "cyborg", "at": fp.y + margin + 2.0, "lane": 2, "side": 0, "seed": 5,
		"params": {"panic": false, "fires": false}}) as Cyborg
	check(c.is_panic and c.run_limit <= fp.x - margin + 0.01,
		"its run stops short of the wall's clear approach (%.1f, the approach from %.1f)" % [c.run_limit, fp.x])
	check(behind.walk_limit >= fp.y + margin - 0.01,
		"one past the wall walks back no further than past its clear stretch (%.1f, the stretch to %.1f)" % [behind.walk_limit, fp.y])
	var furthest: Array = [home]
	var fled: Array = [false]
	# Its instance id, not the cyborg: the lambda outlives it (it retires behind the runner).
	var c_id: int = c.get_instance_id()
	await _run_until(w, 12.0, func() -> bool:
		var it := instance_from_id(c_id) as Cyborg
		if it != null and it.alive:
			furthest[0] = maxf(furthest[0], it.track_distance())
			fled[0] = fled[0] or it.mode == Cyborg.Mode.FLEE
		return w.player.distance > face + 20.0)
	check(fled[0], "it fled from the runner")
	check(furthest[0] < fp.x, "and never got into the wall's footprint (%.1f m, the approach from %.1f m)" % [furthest[0], fp.x])
	await sim.free_world(w)


## Ground enemies ahead of the runner never drive through a standing wall (task H7a; Enemy.dash_wall_reached): an
## Octodog running off ahead (or pacing) leaves play at the wall's face, and a Buzz Overdrive that lets the runner
## pass, speeding off ahead, is gone there.
func _test_ground_enemies_leave() -> void:
	var face: float = 200.0
	var layout := RunSim.layout(3, 800.0)
	layout.dash_walls.append(_wall(face))
	var w: RunWorld = sim.build_world(layout)
	w.player.god_mode = true
	var dog := w.director.spawn({"type": "octodog", "at": 120.0, "lane": 2, "side": 0, "seed": 5, "params": {}}) as Octodog
	dog.call("_set_phase", Octodog.Phase.LEAVE)
	var step: float = (w.tuning.run_speed + 40.0) / Engine.physics_ticks_per_second
	var furthest: Array = [dog.track_distance()]
	var gone_at: Array = [-1.0]
	# Its instance id, not the dog: the lambda outlives it.
	var dog_id: int = dog.get_instance_id()
	await _run_until(w, 10.0, func() -> bool:
		var it := instance_from_id(dog_id) as Octodog
		if it != null and not it.is_queued_for_deletion():
			furthest[0] = maxf(furthest[0], it.track_distance())
		elif gone_at[0] < 0.0:
			gone_at[0] = w.player.distance
		return gone_at[0] >= 0.0 or w.player.distance > face)
	check(gone_at[0] >= 0.0 and gone_at[0] < face,
		"the Octodog running off ahead left play before the runner reached the wall (%.1f m)" % gone_at[0])
	check(furthest[0] + Octodog.DASH_WALL_REACH <= face + step,
		"at the wall's face, never through it (its front got to %.1f m, the face %.1f m)" % [
			furthest[0] + Octodog.DASH_WALL_REACH, face])
	await sim.free_world(w)

	var bt := EnemyDirector.tuning_for("buzz_overdrive") as BuzzOverdriveTuning
	var cut: Dictionary = TankRules.plan_for(bt, 1, 120.0, tuning.run_speed, tuning.pace(), 8.0 / 14.0)
	var tank_face: float = FloorCutPlan.warn_at(cut) + float(cut["charge"]) + 30.0
	layout = RunSim.layout(3, 900.0)
	layout.cuts.append(cut)
	layout.enemies.append({"type": "buzz_overdrive", "at": float(cut["end"]), "lane": 1, "side": 0, "seed": 11,
		"params": {}})
	layout.dash_walls.append(_wall(tank_face))
	w = sim.build_world(layout)
	w.player.god_mode = true
	w.player.setup(w.tuning, w.geo, 0)
	# The tank's instance id once it's in play (0 before): the lambda outlives it.
	var tank_id: Array = [0]
	var passed: Array = [false]
	var before_gone: Array = [-INF]
	var gone: Array = [false]
	var player_then: Array = [INF]
	await _run_until(w, 25.0, func() -> bool:
		if tank_id[0] == 0:
			for e: Enemy in w.director.active:
				if is_instance_valid(e) and e.type_id == &"buzz_overdrive":
					tank_id[0] = e.get_instance_id()
		var tk := instance_from_id(int(tank_id[0])) as Enemy if tank_id[0] != 0 else null
		if tk == null:
			return w.player.distance > tank_face
		var state: int = int(tk.get("state"))
		if not passed[0] and state == TankScript.State.ROLL:
			tk.call("_pass")
			passed[0] = true
		elif state == TankScript.State.PASS:
			before_gone[0] = maxf(before_gone[0], float(tk.get("front")))
		elif state == TankScript.State.GONE and passed[0] and not gone[0]:
			gone[0] = true
			player_then[0] = w.player.distance
		return gone[0] or w.player.distance > tank_face)
	check(passed[0] and gone[0], "the Buzz Overdrive let the runner pass and was gone")
	check(before_gone[0] < tank_face and player_then[0] < tank_face,
		"at the standing wall's face, ahead of the runner (it got to %.1f m, the face %.1f m; the runner at %.1f m)" % [
			before_gone[0], tank_face, player_then[0]])
	await sim.free_world(w)

