extends TestSuite
## The Floating Head, the Neon City's boss (GDD §10; task E1: E1a's part here, the face-off's in
## test_floating_head_faceoff.gd, the stomp windows' in test_floating_head_stomps.gd, the propaganda,
## the defeat and the campaign's flow in test_floating_head_defeat.gd):
## - its data and its route in: the City's boss step plays the fight (task E1d), and debug builds'
##   --boss=city_boss plays that step;
## - its build: the scene makes a FloatingHead, the ship fits the street at 3, 5 and 6 lanes, a boss's
##   body with its hitboxes (the hull solid, a weak point over each lane near its middle and the
##   crown's deck off until it's pinned), the face dark before the reveal, only its attacks and weak
##   points in hazard colours, and a draw budget;
## - its arena: the City's roofs with no signs on its walls, fair and the same on every attempt;
## - the entrance: it flies in overhead from behind and only attacks once it's at its station;
## - the bombing run: bombs fall only where the searchlight lingered, after its visual and audio
##   warning; a player who keeps moving escapes every bomb and one who stands still is hit; the first
##   run lasts 15-20 s; the rules hold on the real arena at every lane count; every attempt plays out
##   the same way; the blast's damage rules, and a wall runner beside it is safe;
## - the reveal (its face powers on once) and the later, shorter runs of the faster phases;
## - the later runs' salvos (owner's request, October 9, 2026; task E1g): 2-4 spots marked at once, the
##   nearest first and each next one further along the track, each leaving the runner one lane on 3
##   lanes and a choice of two from 5 (up to two and three bombs); a way through them all is always left,
##   a runner who weaves along it escapes every bomb and one who stands still is hit by the first; the
##   rules hold on the real arena; every attempt plays out the same way.
## Every fight here runs at the City's speed (21 m/s), as the campaign plays it (GDD §3; task E1f:
## FloatingHeadBot.campaign_tuning).

const BOSS_PATH: String = "res://data/bosses/city_boss.tres"
const LANES: Array[int] = [3, 5, 6]

var sim: RunSim
var def: BossDef


func run() -> void:
	# The fight at the City's speed, as the campaign plays it (GDD §3; E1f).
	tuning = FloatingHeadBot.campaign_tuning(tuning)
	sim = RunSim.new(tree, tuning)
	def = load(BOSS_PATH) as BossDef
	_test_data()
	if def == null:
		return
	await _test_build()
	_test_arena()
	await _test_entrance()
	await _test_bombing_run()
	await _test_standing_still()
	await _test_real_arena()
	await _test_same_every_attempt()
	await _test_blast_rules()
	await _test_reveal_and_later_runs()
	await _test_salvos()
	await _test_route_in()


# --- Helpers -------------------------------------------------------------------------------

## A fight against `p_def` in a bare world at `lanes`: [world, head].
func _fight(p_def: BossDef, lanes: int, resume: Dictionary = {}, loadout: Loadout = null) -> Array:
	var head := BossEncounter.create(p_def) as FloatingHead
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	ctx.boss_resume = resume
	var arena: BossArena = head.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	head.setup(world, ctx, arena)
	return [world, head]


## The Floating Head on a plain street (floor and walls only), for exact scenarios.
func _plain_def() -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	out.arena = null
	return out


## Steps the world until `condition` holds or `seconds` pass. True if it held.
func _until(world: RunWorld, condition: Callable, seconds: float) -> bool:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if condition.call():
			return true
		await tree.physics_frame
	return condition.call()


func _events(head: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in head.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(head: BossEncounter, sound: StringName) -> int:
	var n: int = 0
	for e: Dictionary in _events(head, &"sound"):
		if e["name"] == sound:
			n += 1
	return n


## A runner who keeps moving: when a lock strikes its lane, it switches to the free lane the rules
## leave it (once per lock); in a salvo, it heads for the lane the way through the spots still ahead of
## it leads to (FloatingHeadBombing.dodge_lane), one lane a frame. Call it every physics frame.
func _dodge(head: FloatingHead, dodged: Dictionary) -> void:
	var b: FloatingHeadBombing = head.bombing
	if b.target.has("spots"):
		var at: int = head.player_lane()
		var to: int = b.dodge_lane(at, head.world.player.distance)
		if to >= 0 and to != at:
			head.world.player.press(&"move_right" if to > at else &"move_left")
		return
	if b.target.is_empty() or dodged.has(b.target["lock"]):
		return
	dodged[b.target["lock"]] = true
	var pl: int = head.player_lane()
	var lanes: Array[int] = []
	for l: int in b.target["lanes"]:
		lanes.append(l)
	if not lanes.has(pl):
		return
	var e: int = b.escape_lane(lanes, pl, head.world.player.distance, float(b.target["at"]))
	for i: int in absi(e - pl):
		head.world.player.press(&"move_right" if e > pl else &"move_left")


## The face screen's power as its shader has it (0 until the body first sets it).
func _power(body: FloatingHeadBody) -> float:
	var v: Variant = body.screen_material().get_shader_parameter(&"power")
	return 0.0 if v == null else float(v)


## True if the player's hurtbox overlaps a live blast now.
func _inside_blast(head: FloatingHead) -> bool:
	var body: AABB = head.world.player.hurtbox_aabb()
	for h: Hazard in head.bombing.blast_hazards():
		if AABB(h.global_position - h.size * 0.5, h.size).intersects(body):
			return true
	return false


## True if a lane's floor is free of holes and fences between two track distances (the arena's own
## layout, checked here without the boss's code).
func _floor_clear(layout: LevelLayout, lane: int, from: float, to: float) -> bool:
	for g: Dictionary in layout.gaps:
		if int(g["lane"]) == lane and float(g["start"]) <= to and float(g["end"]) >= from:
			return false
	for f: Dictionary in layout.fences:
		if int(f["lane"]) == lane and not f.get("disabled", false) and float(f["at"]) >= from and float(f["at"]) <= to:
			return false
	return true


## The fairness rules for a lock, rechecked from the arena's layout: the lanes struck are clear around
## the blast, and a free lane lies within reach, clear (with every lane on the way) from the player to
## past the blast. Its margins along the track at the run's `pace` (GDD §3: as long to run as at 18 m/s).
func _lock_fair(layout: LevelLayout, t: FloatingHeadTuning, lock: Dictionary, lanes_count: int, pace: float) -> bool:
	var lanes: Array = lock["lanes"]
	var at: float = float(lock["at"])
	var pl: int = int(lock["player_lane"])
	var d0: float = float(lock["d0"])
	for l: int in lanes:
		if not _floor_clear(layout, l, at - t.clear_before_impact * pace, at + t.clear_after_impact * pace):
			return false
	for e: int in lanes_count:
		if lanes.has(e) or absi(e - pl) > t.max_escape_lanes:
			continue
		var ok: bool = true
		for l: int in range(mini(pl, e), maxi(pl, e) + 1):
			if l != pl and not _floor_clear(layout, l, d0, at + t.escape_clear_after * pace):
				ok = false
		if ok:
			return true
	return false


## The lanes a runner keeping a salvo's rules could be in past each of its spots, rechecked from the
## arena's layout: from the runner's lane at most max_escape_lanes to a free lane at the first spot, then
## at most salvo_max_shift from spot to spot, every lane on the way clear from where it sets off (the
## runner's spot, then the spot before) to past the spot (the runner's own lane is theirs to run). One
## set per spot, up to the first that leaves none.
func _salvo_reach(layout: LevelLayout, t: FloatingHeadTuning, lock: Dictionary, lanes_count: int, pace: float) -> Array:
	var pl: int = int(lock["player_lane"])
	var from: float = float(lock["d0"])
	var reach_set: Array[int] = [pl]
	var spots: Array = lock["spots"]
	var out: Array = []
	for k: int in spots.size():
		var lanes: Array = spots[k]["lanes"]
		var at: float = float(spots[k]["at"])
		var reach: int = t.max_escape_lanes if k == 0 else t.salvo_max_shift
		var next: Array[int] = []
		for r: int in reach_set:
			for e: int in lanes_count:
				if lanes.has(e) or next.has(e) or absi(e - r) > reach:
					continue
				var ok: bool = true
				for l: int in range(mini(r, e), maxi(r, e) + 1):
					if (l != pl or k > 0) and not _floor_clear(layout, l, from, at + t.escape_clear_after * pace):
						ok = false
				if ok:
					next.append(e)
		out.append(next)
		if next.is_empty():
			break
		reach_set = next
		from = at
	return out


## A salvo's rules, rechecked from the arena's layout: every spot lands on clear roof, and a way runs
## through them all (_salvo_reach never runs out).
func _salvo_fair(layout: LevelLayout, t: FloatingHeadTuning, lock: Dictionary, lanes_count: int, pace: float) -> bool:
	var spots: Array = lock["spots"]
	for spot: Dictionary in spots:
		var at: float = float(spot["at"])
		for l: int in spot["lanes"]:
			if not _floor_clear(layout, l, at - t.clear_before_impact * pace, at + t.clear_after_impact * pace):
				return false
	var sets: Array = _salvo_reach(layout, t, lock, lanes_count, pace)
	return sets.size() == spots.size() and not (sets[-1] as Array).is_empty()


# --- Data and preview ----------------------------------------------------------------------------

func _test_data() -> void:
	var slot := load(BOSS_PATH) as BossDef
	check(slot.id == &"city_boss" and slot.display_name == "Floating Head", "the City's boss slot holds the Floating Head")
	check(slot.is_built() and slot.scene == "res://scenes/bosses/floating_head.tscn" and slot.preview() == null,
		"the fight is built: the City's boss step plays its scene, with no preview left (E1d)")
	var made: BossEncounter = BossEncounter.create(slot)
	check(made is FloatingHead, "its scene makes the Floating Head's encounter")
	if made != null:
		made.free()
	if def == null:
		return
	var t := def.tuning as FloatingHeadTuning
	check(t != null and t.resource_path == "res://data/bosses/city_boss_tuning.tres", "its numbers are its own tuning resource")
	check(is_equal_approx(t.first_run_seconds, 16.0 * 0.7), "the first bombing run is 30%% shorter (%.1f s)" % t.first_run_seconds)
	check(is_equal_approx(t.later_run_seconds, 6.5),
		"the later runs are a little longer than 5.6 s for their salvos (%.1f s; owner, October 9, 2026)" % t.later_run_seconds)
	check(t.later_run_seconds > 0.0 and t.later_run_seconds < t.first_run_seconds and t.later_runs >= 1 and t.later_runs <= 2,
		"GDD §10: once or twice it rises for a shorter run (%d of %.1f s)" % [t.later_runs, t.later_run_seconds])
	check(def.phase_count() == 3 and def.phase_list()[0].intro_seconds >= 3.0, "three phases; the first's intro is the entrance")
	check(def.arena != null and not def.arena.features.has("ceilings") and not def.arena.features.has("cyborg"),
		"its arena: the City's roofs, gaps and fences, no ceilings or enemies of its own")
	# The ship fills the street high up, so its arena's City hangs no big screens out over the street.
	var skin := def.arena.skin as CitySkin
	check(skin != null, "its arena has the City's look")
	if skin != null:
		var city := load("res://data/skins/city_skin.tres") as CitySkin
		var wall: float = TrackGeometry.new(5, tuning).wall_x()
		var hung: int = 0
		var usual: int = 0
		for side: int in [-1, 1]:
			for board: Dictionary in skin.feed_boards(side, side * wall, 0.0, 3000.0):
				hung += 1 if board["kind"] == &"tower_screen" else 0
			for board: Dictionary in city.feed_boards(side, side * wall, 0.0, 3000.0):
				usual += 1 if board["kind"] == &"tower_screen" else 0
		check(hung == 0 and usual > 0, "no big screens hang out over its street, where the ship flies (the City's has %d over 3 km)" % usual)
	# Every warning is heard (CLAUDE.md), the same every time.
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in [&"head_flyover", &"searchlight_on", &"searchlight_lock", &"bomb_whistle", &"bomb_blast", &"head_reveal"]:
		check(sfx.names().has(String(sound)) and sfx.stream(sound) != null, "its sound %s exists" % sound)
	for warning: StringName in [&"head_flyover", &"searchlight_lock", &"bomb_whistle"]:
		check(float(sfx.pitch_variation.get(String(warning), 0.0)) == 0.0, "warning %s sounds the same every time" % warning)
	var whistle: float = sfx.stream(&"bomb_whistle").get_length()
	check(whistle >= 0.5 and whistle <= t.lock_seconds, "the falling whistle fits in the warning (%.2f s)" % whistle)


# --- The build ------------------------------------------------------------------------------------

func _test_build() -> void:
	for lanes: int in LANES:
		var pair: Array = _fight(def, lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var tag: String = "(%d lanes)" % lanes
		var body: FloatingHeadBody = head.body
		check(head is FloatingHead and body is FloatingHeadBody and head.parts == [body], "the scene makes the fight and its ship %s" % tag)
		check(body.is_boss and body.claw_immune and not body.dash_kills and not body.stompable and body.shares_health,
			"the ship is a boss's body: claws never, the dash passes, only weak points take stomps %s" % tag)
		# It fits the street it flies down, ears and all.
		body.set_pose(Vector3(0.0, 3.0, TrackGeometry.world_z(world.player.distance + 30.0)))
		var widest: float = 0.0
		for node: Node in body.find_children("*", "MeshInstance3D", true, false):
			var m := node as MeshInstance3D
			if m.mesh == null or m.name == "FloorGlow":
				continue
			var box: AABB = m.global_transform * m.get_aabb()
			widest = maxf(widest, maxf(absf(box.position.x), absf(box.end.x)))
		check(widest < world.geo.wall_x() - 0.05, "the ship fits between the walls (%.2f m of %.2f) %s" % [widest, world.geo.wall_x(), tag])
		var s: FloatingHeadModel.Shape = body.shape
		check(s.height >= 10.0 and s.length >= 20.0, "a giant ship: %.1f m tall, %.1f m long %s" % [s.height, s.length, tag])
		# Hitboxes: the hull solid; a weak point over each lane near the crown's middle (3, 3 and 4 at 3, 5
		# and 6 lanes) and the crown's deck, off until a stomp window opens.
		var solid: int = 0
		for child: Node in body.find_children("*", "Hazard", true, false):
			var h := child as Hazard
			if h.part == &"body" and h.is_solid and h.is_active():
				solid += 1
		check(solid == 1 and body.hull_solid(), "its hull has a solid hitbox %s" % tag)
		var expected: int = 4 if lanes == 6 else 3
		check(body.weak_points.size() == expected and s.weak_points.size() == expected and not body.weak_points_enabled(),
			"%d weak points, off until it's pinned %s" % [expected, tag])
		var on_top: bool = true
		var over_lanes: bool = true
		for p: Vector3 in s.weak_points:
			on_top = on_top and p.y > s.height * 0.9 and absf(p.x) <= s.width * 0.4
			var near: float = INF
			for l: int in lanes:
				near = minf(near, absf(p.x - world.geo.lane_x(l)))
			over_lanes = over_lanes and near < 0.01
		check(on_top, "its weak points sit on top of its head (GDD §10) %s" % tag)
		check(over_lanes, "each over a lane's middle, where a runner comes down on it %s" % tag)
		check(not body.top_solid(), "its crown's deck is no surface to stand on until it's pinned %s" % tag)
		check(body.screen_material() != null and is_zero_approx(body.screen_power) and _power(body) == 0.0,
			"its face screen is dark before the reveal %s" % tag)
		# Low-poly and merged: a few draw calls and vertices for a giant ship.
		var stats: Dictionary = body.draw_stats()
		check(int(stats["surfaces"]) <= 14 and int(stats["vertices"]) <= 16000,
			"a ship within budget: %d surfaces, %d vertices %s" % [stats["surfaces"], stats["vertices"], tag])
		if lanes == 5:
			print("  Floating Head (5 lanes): %d mesh instances, %d surfaces, %d vertices" % [stats["instances"],
				stats["surfaces"], stats["vertices"]])
		await sim.free_world(world)
	_check_colours()


## The colour rule (GDD §5, CLAUDE.md): only hazards glow in hazard colours. The ship's lights are cold
## whites and blues; red glows only on its weak points and its bombs.
func _check_colours() -> void:
	var s: FloatingHeadModel.Shape = FloatingHeadModel.shape_for(12.6, 5, def.tuning as FloatingHeadTuning, tuning.lane_width)
	var meshes: Dictionary = FloatingHeadModel.meshes(s)
	var loud: PackedStringArray = []
	for key: String in ["hull", "jaw", "lamp", "door", "cover"]:
		loud.append_array(_hazard_glows(meshes[key], key))
	check(loud.is_empty(), "nothing on the ship glows in a hazard colour: %s" % ", ".join(loud))
	var reds: int = 0
	for mesh: ArrayMesh in [meshes["weak"], FloatingHeadModel.bomb_mesh()]:
		for s2: int in mesh.get_surface_count():
			for c: Color in mesh.surface_get_arrays(s2)[Mesh.ARRAY_COLOR]:
				if c.a > 0.0 and c.s > 0.5 and (c.h < 0.05 or c.h > 0.95):
					reds += 1
	check(reds > 0, "its weak points and bombs glow enemy-attack red")


func _hazard_glows(mesh: ArrayMesh, tag: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for s: int in mesh.get_surface_count():
		var colors: PackedColorArray = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
		for c: Color in colors:
			if c.a > 0.0 and c.s > 0.3 and (c.h < 0.55 or c.h > 0.8) and out.size() < 3:
				out.append("%s %s" % [tag, c])
	return out


# --- The arena ------------------------------------------------------------------------------------

func _test_arena() -> void:
	for lanes: int in LANES:
		var config: LevelConfig = BossArena.base_config(def)
		config.lane_count = lanes
		var head := BossEncounter.create(def) as FloatingHead
		var again := BossEncounter.create(def) as FloatingHead
		var a: BossArena = BossArena.plan(def, config, tuning, head)
		var b: BossArena = BossArena.plan(def, config, tuning, again)
		again.free()
		check(var_to_str(a.layout.to_dict()) == var_to_str(b.layout.to_dict()), "its arena is the same on every attempt (%d lanes)" % lanes)
		var signs: int = 0
		var pieces: int = 0
		for lap: LevelLayout in a.laps:
			signs += lap.signs.size()
			pieces += lap.gaps.size() + lap.fences.size()
			LayoutChecks.check_layout(self, lap, config, "(Floating Head arena, %d lanes)" % lanes)
		check(signs == 0, "its walls carry no signs: the ship fills the street (%d lanes)" % lanes)
		check(pieces > 0 and a.layout.hulls.is_empty() and a.layout.enemies.is_empty(),
			"its laps have the City's gaps and fences, no ceilings and no enemies of their own (%d lanes)" % lanes)
		head.free()


# --- The entrance ---------------------------------------------------------------------------------

func _test_entrance() -> void:
	var pair: Array = _fight(_plain_def(), 5)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	world.player.god_mode = true
	var t: FloatingHeadTuning = head.tuning
	check(head.step == FloatingHead.Step.ENTER and head.pose.z < -world.tuning.camera_distance,
		"it starts behind the runner, out of sight (%.1f m)" % head.pose.z)
	check(_sounds(head, &"head_flyover") == 1, "its roar comes first (the arrival's warning)")
	var passed: Array[bool] = [false]
	var targeted: Array[bool] = [false]
	await _until(world, func() -> bool:
		if absf(head.pose.z) < 3.0 and head.body.global_position.y > world.player.global_position.y + 5.0:
			passed[0] = true
		if head.state == BossEncounter.State.INTRO and head.body.targetable():
			targeted[0] = true
		return head.state == BossEncounter.State.FIGHT, 8.0)
	var intro: float = head.phase().intro_seconds
	check(passed[0], "it passes overhead")
	check(not targeted[0], "weapons can't hurt it during its entrance")
	check(_events(head, &"lock").is_empty() and _events(head, &"blast").is_empty(), "it attacks nothing during its entrance")
	check(head.pose.distance_to(head.station_pose()) < 0.01, "it ends the entrance at its bombing station")
	var starts: Array[Dictionary] = _events(head, &"run_start")
	check(starts.size() == 1 and absf(float(starts[0]["t"]) - intro) < 0.05,
		"the run starts as the entrance ends (%.2f s)" % (float(starts[0]["t"]) if not starts.is_empty() else -1.0))
	check(_sounds(head, &"searchlight_on") == 1 and head.body.bay_open, "the searchlight clunks on and the bay opens")
	await sim.free_world(world)


# --- The bombing run ------------------------------------------------------------------------------

## On a plain street at every lane count, with a runner who keeps moving (and no god mode): bombs fall
## only where the light lingered, after its warning; the runner escapes every one; the run lasts its
## configured duration.
func _test_bombing_run() -> void:
	for lanes: int in LANES:
		var pair: Array = _fight(_plain_def(), lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var t: FloatingHeadTuning = head.tuning
		var tag: String = "(%d lanes)" % lanes
		var dodged: Dictionary = {}
		var inside: Array[int] = [0]
		var drift: Array[float] = [0.0]
		var unwarned: Array[int] = [0]
		var white_lock: Array[int] = [0]
		# Every blast's look is one of the shared fireballs (task H6), sized to the blast and gone about when it is.
		var fires: Array[float] = []
		world.effects.fireball_played.connect(func(_at: Vector3, size: float) -> void: fires.append(size))
		var done: bool = await _until(world, func() -> bool:
			_dodge(head, dodged)
			if _inside_blast(head):
				inside[0] += 1
			var b: FloatingHeadBombing = head.bombing
			if b.step == FloatingHeadBombing.Step.LOCK:
				drift[0] = maxf(drift[0], maxf(absf(b.spot_x - float(b.target["x"])), absf(b.spot_d - float(b.target["at"]))))
				for l: int in b.target["lanes"]:
					if not head.props.warned(l, float(b.target["at"]) - 0.5, float(b.target["at"]) + 0.5):
						unwarned[0] += 1
				if head.body.lamp != FloatingHeadBody.Lamp.LOCK and b.step_time > 0.2:
					white_lock[0] += 1
			return head.step == FloatingHead.Step.FACE_OFF or not world.player.alive, 40.0)
		check(done and world.player.alive, "a runner who keeps moving escapes every bomb %s" % tag)
		check(inside[0] == 0, "and is never inside a blast %s" % tag)
		var locks: Array[Dictionary] = _events(head, &"lock")
		var blasts: Array[Dictionary] = _events(head, &"blast")
		var straddles: int = 0
		for l: Dictionary in locks:
			if l["straddle"]:
				straddles += 1
		check(locks.size() >= 4, "the light locks on again and again (%d locks) %s" % [locks.size(), tag])
		check(straddles >= 1 and straddles < locks.size(), "some locks straddle two lanes (%d) %s" % [straddles, tag])
		var salvos: int = 0
		for l: Dictionary in locks:
			if l.has("spots"):
				salvos += 1
		check(salvos == 0, "the first run marks one spot at a time, as before the salvos (E1g) %s" % tag)
		print("  Floating Head's first run %s: %d locks (%d over two lanes), %d bombs" % [tag, locks.size(), straddles,
			blasts.size()])
		# Every blast was a lock's: the same spot, after the whole warning.
		var matched: bool = true
		var bombs: int = 0
		for bl: Dictionary in blasts:
			var found: bool = false
			for l: Dictionary in locks:
				if (l["lanes"] as Array).has(bl["lane"]) and is_equal_approx(float(l["at"]), float(bl["at"])):
					var wait: float = float(bl["t"]) - float(l["t"])
					found = wait >= float(l["warning"]) - 0.02 and wait <= float(l["warning"]) + 0.05
			matched = matched and found
		for l: Dictionary in locks:
			bombs += (l["lanes"] as Array).size()
		check(matched and blasts.size() == bombs, "bombs fall only where the light lingered, after its warning (%d of %d) %s" % [
			blasts.size(), bombs, tag])
		var fire_size: float = t.blast_radius * FloatingHeadBombing.FIRE_SIZE_PER_RADIUS
		var fires_ok: bool = fires.size() == blasts.size()
		for size: float in fires:
			fires_ok = fires_ok and is_equal_approx(size, fire_size)
		check(fires_ok, "each blast is one pooled fireball, sized to it (%d fireballs for %d blasts, %.2f m) %s" % [
			fires.size(), blasts.size(), fire_size, tag])
		check(drift[0] < 0.01, "the light stays on the spot while it lingers (%.3f m) %s" % [drift[0], tag])
		check(unwarned[0] == 0, "the red target circle marks every spot while the bomb falls %s" % tag)
		check(white_lock[0] == 0, "the light turns red while it lingers %s" % tag)
		check(_sounds(head, &"searchlight_lock") == locks.size() and _sounds(head, &"bomb_whistle") == bombs,
			"every lock is heard, and every bomb whistles as it falls %s" % tag)
		var warnings_equal: bool = true
		for l: Dictionary in locks:
			warnings_equal = warnings_equal and is_equal_approx(float(l["warning"]), t.lock_seconds / head.phase().pace)
		check(warnings_equal, "every warning lasts the same (no escalation) %s" % tag)
		var start: Array[Dictionary] = _events(head, &"run_start")
		var end: Array[Dictionary] = _events(head, &"run_end")
		if not start.is_empty() and not end.is_empty():
			var length: float = float(end[0]["t"]) - float(start[0]["t"])
			check(absf(length - 16.0 * 0.7) < 0.05,
				"the first run lasts %.2f s (30%% shorter) %s" % [length, tag])
			var late: bool = false
			for bl: Dictionary in blasts:
				late = late or float(bl["t"]) > float(end[0]["t"]) + 0.02
			check(not late, "its last bomb lands before the run ends %s" % tag)
		else:
			check(false, "the run starts and ends %s" % tag)
		await sim.free_world(world)


## A runner who stands still is hit by the first bomb, where and when it goes off (it's aimed at them).
func _test_standing_still() -> void:
	for lanes: int in LANES:
		var pair: Array = _fight(_plain_def(), lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var cause: Array[String] = [""]
		world.player.died.connect(func(c: String) -> void: cause[0] = c)
		await _until(world, func() -> bool: return not world.player.alive, 12.0)
		var blasts: Array[Dictionary] = _events(head, &"blast")
		check(not world.player.alive and cause[0] == FloatingHeadBombing.BOMB_NAME and blasts.size() == 1,
			"a runner who stands still is hit by the first bomb (%s) (%d lanes)" % [cause[0], lanes])
		if not blasts.is_empty():
			check(absf(world.player.distance - float(blasts[0]["at"])) < 2.0,
				"it goes off right where the runner gets to (%.2f m away) (%d lanes)" % [world.player.distance - float(blasts[0]["at"]), lanes])
		await sim.free_world(world)


## On its real arena (the City's roofs, gaps and fences) at every lane count: every lock keeps the
## fairness rules (checked here from the layout), the dodging runner is never inside a blast, and
## bombs still fall.
func _test_real_arena() -> void:
	for lanes: int in LANES:
		var pair: Array = _fight(def, lanes)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		world.player.god_mode = true
		world.player.grapples = 1_000_000
		var dodged: Dictionary = {}
		var inside: Array[int] = [0]
		await _until(world, func() -> bool:
			_dodge(head, dodged)
			if _inside_blast(head):
				inside[0] += 1
			return head.step == FloatingHead.Step.FACE_OFF, 40.0)
		var locks: Array[Dictionary] = _events(head, &"lock")
		var unfair: int = 0
		for l: Dictionary in locks:
			if not _lock_fair(world.layout, head.tuning, l, lanes, head.run_pace()):
				unfair += 1
		check(locks.size() >= 4, "bombs fall on the real arena too (%d locks, %d lanes)" % [locks.size(), lanes])
		check(unfair == 0, "every lock leaves a clear way out and lands on clear roof (%d unfair, %d lanes)" % [unfair, lanes])
		check(inside[0] == 0, "the dodging runner is never inside a blast (%d lanes)" % lanes)
		await sim.free_world(world)


## Two attempts with the same moves play out the same way.
func _test_same_every_attempt() -> void:
	var runs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(def, 5)
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		world.player.god_mode = true
		world.player.grapples = 1_000_000
		var dodged: Dictionary = {}
		await _until(world, func() -> bool:
			_dodge(head, dodged)
			return head.step == FloatingHead.Step.FACE_OFF, 40.0)
		var log: PackedStringArray = []
		for e: Dictionary in head.events:
			if e["event"] in [&"lock", &"blast", &"run_start", &"run_end", &"reveal"]:
				log.append("%s %.3f %s %s" % [e["event"], float(e["t"]), e.get("lanes", e.get("lane", "")), e.get("at", "")])
		runs.append("\n".join(log))
		await sim.free_world(world)
	check(runs[0] == runs[1] and runs[0].length() > 0, "every attempt plays out the same way")


# --- The blast ------------------------------------------------------------------------------------

func _test_blast_rules() -> void:
	# The shared damage rules on a live blast: an enemy attack (armor and the shield block it, the dash
	# passes through it, claws don't help).
	var pair: Array = _fight(_plain_def(), 3)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	world.player.god_mode = true
	await _until(world, func() -> bool: return not head.bombing.blast_hazards().is_empty(), 12.0)
	var hazards: Array[Hazard] = head.bombing.blast_hazards()
	check(not hazards.is_empty(), "a bomb goes off")
	if not hazards.is_empty():
		var h: Hazard = hazards[0]
		var d := DamageRules.Defense.new()
		check(DamageRules.resolve(h, d) == DamageRules.Outcome.KILL, "a blast kills an unprotected runner")
		d.armor = true
		check(DamageRules.resolve(h, d) == DamageRules.Outcome.BLOCKED_ARMOR, "armor blocks it (an enemy attack)")
		d.armor = false
		d.shield = true
		check(DamageRules.resolve(h, d) == DamageRules.Outcome.BLOCKED_SHIELD, "the shield blocks it")
		d.shield = false
		d.claws = true
		check(DamageRules.resolve(h, d) == DamageRules.Outcome.KILL, "claws don't")
		d.claws = false
		d.dashing = true
		check(DamageRules.resolve(h, d) == DamageRules.Outcome.IGNORE, "the dash passes through it")
		check(h.size.y > tuning.jump_height + 0.3, "it's too tall to jump over (%.1f m)" % h.size.y)
	await sim.free_world(world)
	# A wall runner beside a blast in the outer lane is safe: the blast keeps clear of the wall, and
	# still covers a runner in that lane.
	for setup: Vector2i in [Vector2i(3, -1), Vector2i(3, 1), Vector2i(5, -1), Vector2i(6, 1)]:
		var lanes: int = setup.x
		var side: int = setup.y
		pair = _fight(_plain_def(), lanes)
		world = pair[0]
		head = pair[1]
		var outer: int = 0 if side < 0 else lanes - 1
		var tag: String = "(%d lanes, %s wall)" % [lanes, "left" if side < 0 else "right"]
		var entered: Array[bool] = [false]
		var on_wall: Array[bool] = [false]
		var covers: Array[bool] = [false]
		var cause: Array[String] = [""]
		world.player.died.connect(func(c: String) -> void: cause[0] = c)
		await _until(world, func() -> bool:
			var b: FloatingHeadBombing = head.bombing
			# To the outer lane first, so the bombs come there.
			if world.player.lane != outer and world.player.surface_name() == "floor" and not entered[0]:
				world.player.press(&"move_left" if side < 0 else &"move_right")
			if not entered[0] and world.player.lane == outer and not b.target.is_empty() \
					and (b.target["lanes"] as Array).has(outer) and b.clock >= float(b.target["impact"]) - 0.45:
				# Onto the wall beside the lane the bomb falls on.
				world.player.press(&"move_left" if side < 0 else &"move_right")
				entered[0] = true
			for h: Hazard in b.blast_hazards():
				var x0: float = h.global_position.x - h.size.x * 0.5
				var x1: float = h.global_position.x + h.size.x * 0.5
				var lx: float = world.geo.lane_x(outer)
				if x0 < lx and x1 > lx:
					covers[0] = x0 <= lx - tuning.hurtbox_size.x * 0.5 and x1 >= lx + tuning.hurtbox_size.x * 0.5
					on_wall[0] = world.player.surface_name() == "wall"
			return not _events(head, &"blast").is_empty() and b.blast_hazards().is_empty() \
				or not world.player.alive, 14.0)
		check(entered[0] and on_wall[0] and world.player.alive,
			"a wall runner beside a blast in the outer lane is safe %s %s" % [tag, cause[0]])
		check(covers[0], "that blast still covers a runner in its lane %s" % tag)
		await sim.free_world(world)


# --- The reveal and the later runs ----------------------------------------------------------------

func _test_reveal_and_later_runs() -> void:
	# The reveal: after the first run it drops in front of the runner and its face powers on, once.
	var pair: Array = _fight(_plain_def(), 5)
	var world: RunWorld = pair[0]
	var head: FloatingHead = pair[1]
	world.player.god_mode = true
	var dark_until_reveal: Array[bool] = [true]
	var revealed: bool = await _until(world, func() -> bool:
		if head.step == FloatingHead.Step.BOMBING and head.body.screen_power > 0.0:
			dark_until_reveal[0] = false
		return head.step == FloatingHead.Step.FACE_OFF, 30.0)
	check(revealed and dark_until_reveal[0], "its face stays dark through the run (GDD §10: its back turns out to be the face)")
	check(_events(head, &"reveal").size() == 1 and _sounds(head, &"head_reveal") == 1 and is_equal_approx(head.body.screen_power, 1.0),
		"then it drops in front of the runner and its face powers on (the reveal)")
	check(head.pose.distance_to(head.face_pose()) < 0.01, "it hovers in front of the runner")
	check(head.body.global_position.y >= 2.6, "above the fences, so the track stays in view under it")
	var locks: int = _events(head, &"lock").size()
	await _until(world, func() -> bool: return false, 3.0)
	check(_events(head, &"lock").size() == locks, "no bombs in the face-off: it attacks with its eyes and mouth there")
	await sim.free_world(world)
	# The faster phases: a shorter run after it rises, faster warnings, the face already on.
	var t := def.tuning as FloatingHeadTuning
	for phase: int in [1, 2]:
		pair = _fight(_plain_def(), 5, {"phase": phase})
		world = pair[0]
		head = pair[1]
		world.player.god_mode = true
		check(head.revealed and is_equal_approx(head.body.screen_power, 1.0), "phase %d: its face is already on" % (phase + 1))
		await _until(world, func() -> bool: return head.step == FloatingHead.Step.FACE_OFF, 30.0)
		var start: Array[Dictionary] = _events(head, &"run_start")
		var end: Array[Dictionary] = _events(head, &"run_end")
		var expected: float = head.run_seconds(phase)
		if phase <= t.later_runs:
			check(start.size() == 1 and end.size() == 1
				and absf(float(end[0]["t"]) - float(start[0]["t"]) - expected) < 0.05 and expected == t.later_run_seconds,
				"phase %d: it rises for a shorter run (%.1f s)" % [phase + 1, expected])
			var lk: Array[Dictionary] = _events(head, &"lock")
			check(not lk.is_empty() and is_equal_approx(float(lk[0]["warning"]), t.lock_seconds / def.phase_list()[phase].pace)
				and float(lk[0]["warning"]) < t.lock_seconds, "phase %d: its warnings are faster, as its pace says" % (phase + 1))
		else:
			check(start.is_empty(), "phase %d: no run" % (phase + 1))
		check(_events(head, &"reveal").is_empty(), "phase %d: no second reveal" % (phase + 1))
		await sim.free_world(world)


# --- Salvos --------------------------------------------------------------------------------------

## The later runs' salvos (owner's request, October 9, 2026; task E1g).
func _test_salvos() -> void:
	var t := def.tuning as FloatingHeadTuning
	check(t.salvo_spots_in(0) == 1, "the first run marks one spot at a time (E1g)")
	check(t.salvo_min_spots == 2 and t.salvo_spots_in(1) == 4 and t.salvo_spots_in(2) == 4,
		"the later runs drop salvos of 2 to 4 spots (owner, October 9, 2026)")
	check(t.salvo_spacing < 12.0, "its spots lie closer together than the first 12 m (owner: tighter; %.1f m)" % t.salvo_spacing)
	check(t.salvo_wide_lanes == 5 and t.salvo_wide_bombs == 3 and t.salvo_bombs == 2,
		"a spot takes up to three bombs from 5 lanes, two below (owner: harder on 5 or more lanes)")
	check(t.salvo_choices == 1 and t.salvo_wide_choices == 2,
		"a spot leaves one lane on 3 lanes (a path to take) and a choice of two from 5 lanes (owner)")
	# Seconds from one spot's blast to the next: salvo_spacing at 18 m/s, as long at any speed.
	var gap: float = t.salvo_spacing / MovementTuning.REFERENCE_SPEED
	var sizes: Dictionary = {}
	var spots_seen: int = 0
	var pairs: int = 0
	var widest: int = 0
	var circles_fogged: int = 0
	for phase: int in [1, 2]:
		for lanes: int in LANES:
			var pair: Array = _fight(_plain_def(), lanes, {"phase": phase})
			var world: RunWorld = pair[0]
			var head: FloatingHead = pair[1]
			var tag: String = "(phase %d, %d lanes)" % [phase + 1, lanes]
			var dodged: Dictionary = {}
			var inside: Array[int] = [0]
			var unwarned: Array[int] = [0]
			var seen: Dictionary = {}
			# Every blast, a salvo's too, is one of the shared fireballs (task H6, GDD §11), sized to the blast.
			var fires: Array[float] = []
			world.effects.fireball_played.connect(func(_at: Vector3, size: float) -> void: fires.append(size))
			var done: bool = await _until(world, func() -> bool:
				var b: FloatingHeadBombing = head.bombing
				if b.target.has("spots") and not seen.has(b.target["lock"]):
					# The lock's first frame: every spot's circle shows already, before its bombs fall.
					seen[b.target["lock"]] = true
					for spot: Dictionary in b.target["spots"]:
						for l: int in spot["lanes"]:
							if not head.props.warned(l, float(spot["at"]) - 0.5, float(spot["at"]) + 0.5):
								unwarned[0] += 1
					for d: Dictionary in b._drops:
						var circle := d["circle"] as MeshInstance3D
						var m := circle.material_override as BaseMaterial3D
						if m == null or not m.disable_fog or not m.emission.is_equal_approx(BossProps.WARNING_COLOR):
							circles_fogged += 1
				_dodge(head, dodged)
				if _inside_blast(head):
					inside[0] += 1
				return head.step == FloatingHead.Step.FACE_OFF or not world.player.alive, 30.0)
			check(done and world.player.alive, "a runner who weaves along the way through escapes every bomb %s" % tag)
			check(inside[0] == 0, "and is never inside a blast %s" % tag)
			check(unwarned[0] == 0, "every spot's red circle shows from the lock, before its bombs fall %s" % tag)
			var lt: float = t.lock_seconds / head.phase().pace
			var locks: Array[Dictionary] = _events(head, &"lock")
			var blasts: Array[Dictionary] = _events(head, &"blast")
			check(not locks.is_empty(), "the light locks on %s" % tag)
			var shaped: bool = true
			var wide: bool = lanes >= t.salvo_wide_lanes
			var most_bombs: int = t.salvo_wide_bombs if wide else t.salvo_bombs
			var choices: int = t.salvo_wide_choices if wide else t.salvo_choices
			var stepped_clear: int = 0
			var off_choices: int = 0
			var aimed: bool = true
			var spaced: bool = true
			var timed: bool = true
			var unfair: int = 0
			var bombs: int = 0
			for l: Dictionary in locks:
				if not l.has("spots"):
					shaped = false
					continue
				var spots: Array = l["spots"]
				shaped = shaped and spots.size() >= t.salvo_min_spots and spots.size() <= t.salvo_spots_in(phase)
				sizes[spots.size()] = true
				aimed = aimed and (spots[0]["lanes"] as Array).has(int(l["player_lane"])) \
					and is_equal_approx(float(spots[0]["at"]), float(l["at"]))
				for k: int in spots.size():
					var spot_lanes: Array = spots[k]["lanes"]
					bombs += spot_lanes.size()
					if wide:
						widest = maxi(widest, spot_lanes.size())
					else:
						spots_seen += 1
						if spot_lanes.size() == 2:
							pairs += 1
					# Side by side: one block of lanes, at most most_bombs wide.
					shaped = shaped and spot_lanes.size() >= 1 and spot_lanes.size() <= most_bombs \
						and int(spot_lanes[-1]) - int(spot_lanes[0]) == spot_lanes.size() - 1
					timed = timed and absf(float(spots[k]["warning"]) - (lt + k * gap)) < 0.01
					if k > 0:
						spaced = spaced and absf(float(spots[k]["at"]) - float(spots[k - 1]["at"])
							- t.salvo_spacing * head.run_pace()) < 0.01
				if not _salvo_fair(world.layout, t, l, lanes, head.run_pace()):
					unfair += 1
				# Past every spot the runner has the street's choice of lanes: one on 3 lanes, two from 5.
				for left: Array in _salvo_reach(world.layout, t, l, lanes, head.run_pace()):
					if left.size() != choices:
						off_choices += 1
				# No lane in the runner's reach at the first spot is clear of every spot.
				for e: int in lanes:
					var hit: bool = absi(e - int(l["player_lane"])) > t.max_escape_lanes
					for spot: Dictionary in spots:
						hit = hit or (spot["lanes"] as Array).has(e)
					if not hit:
						stepped_clear += 1
			check(shaped, "every lock marks %d to %d spots, 1 to %d bombs side by side each %s" % [t.salvo_min_spots,
				t.salvo_spots_in(phase), most_bombs, tag])
			check(off_choices == 0, "past every spot the runner has %d lane%s to be in (%d spots off) %s" % [choices,
				"" if choices == 1 else "s", off_choices, tag])
			check(stepped_clear == 0, "a runner can't step clear of a whole salvo (%d lanes clear) %s" % [stepped_clear, tag])
			check(aimed, "the nearest spot is where a single lock's would be, on the runner's lane %s" % tag)
			check(spaced, "each next spot lies salvo_spacing further along the track %s" % tag)
			check(timed, "each spot blows %.2f s after the one before, the first after the warning %s" % [gap, tag])
			check(unfair == 0, "every salvo leaves a way through it (%d unfair) %s" % [unfair, tag])
			# Every blast is a spot's, after its own warning: nearest first, each as the runner gets there.
			var matched: bool = true
			for bl: Dictionary in blasts:
				var found: bool = false
				for l: Dictionary in locks:
					for spot: Dictionary in l.get("spots", []):
						if (spot["lanes"] as Array).has(bl["lane"]) and is_equal_approx(float(spot["at"]), float(bl["at"])):
							var wait: float = float(bl["t"]) - float(l["t"])
							found = wait >= float(spot["warning"]) - 0.02 and wait <= float(spot["warning"]) + 0.05
				matched = matched and found
			check(matched and blasts.size() == bombs, "bombs fall only on the spots, each after its warning (%d of %d) %s" % [
				blasts.size(), bombs, tag])
			var fire_size: float = t.blast_radius * FloatingHeadBombing.FIRE_SIZE_PER_RADIUS
			var fires_ok: bool = fires.size() == blasts.size()
			for size: float in fires:
				fires_ok = fires_ok and is_equal_approx(size, fire_size)
			var cut_short: int = world.effects.fireballs().recycled
			check(fires_ok and cut_short == 0,
				"each of a salvo's blasts is one pooled fireball, sized to it, none cut short (%d fireballs for %d blasts, %.2f m, %d cut short) %s"
				% [fires.size(), blasts.size(), fire_size, cut_short, tag])
			check(_sounds(head, &"searchlight_lock") == locks.size() and _sounds(head, &"bomb_whistle") == bombs,
				"every lock is heard, and every bomb whistles as it falls %s" % tag)
			var end: Array[Dictionary] = _events(head, &"run_end")
			var late: bool = end.is_empty()
			for bl: Dictionary in blasts:
				late = late or float(bl["t"]) > float(end[0]["t"]) + 0.02
			check(not late, "its last bomb lands before the run ends %s" % tag)
			print("  Floating Head's run in phase %d %s: %d salvos, %d bombs" % [phase + 1, tag, locks.size(), bombs])
			await sim.free_world(world)
	check(sizes.size() >= 2, "salvos come in different sizes (%s spots)" % [sizes.keys()])
	check(pairs >= 1 and pairs < spots_seen, "on 3 lanes some spots take two bombs side by side, others one (%d of %d)" % [
		pairs, spots_seen])
	check(widest == t.salvo_wide_bombs, "on 5 and 6 lanes some spots take %d bombs side by side" % t.salvo_wide_bombs)
	check(circles_fogged == 0, "every target circle is the same red at any distance, out of the fog (owner)")
	# A runner who stands still is hit by the first spot's bomb, where it goes off.
	for lanes: int in LANES:
		var pair: Array = _fight(_plain_def(), lanes, {"phase": 1})
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		var cause: Array[String] = [""]
		world.player.died.connect(func(c: String) -> void: cause[0] = c)
		await _until(world, func() -> bool: return not world.player.alive, 15.0)
		var locks: Array[Dictionary] = _events(head, &"lock")
		var blasts: Array[Dictionary] = _events(head, &"blast")
		var first: bool = not locks.is_empty() and not blasts.is_empty()
		for bl: Dictionary in blasts:
			first = first and is_equal_approx(float(bl["at"]), float(locks[0]["at"]))
		check(not world.player.alive and cause[0] == FloatingHeadBombing.BOMB_NAME and first,
			"a runner who stands still is hit by a salvo's first spot (%s) (%d lanes)" % [cause[0], lanes])
		await sim.free_world(world)
	# On the real arena (its holes and fences), every salvo still leaves a way through.
	for phase: int in [1, 2]:
		for lanes: int in LANES:
			var pair: Array = _fight(def, lanes, {"phase": phase})
			var world: RunWorld = pair[0]
			var head: FloatingHead = pair[1]
			world.player.god_mode = true
			world.player.grapples = 1_000_000
			var dodged: Dictionary = {}
			var inside: Array[int] = [0]
			await _until(world, func() -> bool:
				_dodge(head, dodged)
				if _inside_blast(head):
					inside[0] += 1
				return head.step == FloatingHead.Step.FACE_OFF, 30.0)
			var locks: Array[Dictionary] = _events(head, &"lock")
			var unfair: int = 0
			for l: Dictionary in locks:
				if not l.has("spots") or not _salvo_fair(world.layout, head.tuning, l, lanes, head.run_pace()):
					unfair += 1
			var tag: String = "(phase %d, %d lanes)" % [phase + 1, lanes]
			check(not locks.is_empty(), "salvos fall on the real arena too (%d) %s" % [locks.size(), tag])
			check(unfair == 0, "every salvo lands on clear roof and leaves a way through (%d unfair) %s" % [unfair, tag])
			check(inside[0] == 0, "the weaving runner is never inside a blast %s" % tag)
			await sim.free_world(world)
	# Two attempts with the same moves play out the same way.
	var runs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(def, 5, {"phase": 1})
		var world: RunWorld = pair[0]
		var head: FloatingHead = pair[1]
		world.player.god_mode = true
		world.player.grapples = 1_000_000
		var dodged: Dictionary = {}
		await _until(world, func() -> bool:
			_dodge(head, dodged)
			return head.step == FloatingHead.Step.FACE_OFF, 30.0)
		var log: PackedStringArray = []
		for e: Dictionary in head.events:
			if e["event"] in [&"lock", &"blast", &"run_start", &"run_end"]:
				log.append("%s %.3f %s %s %s" % [e["event"], float(e["t"]), e.get("lanes", e.get("lane", "")),
					e.get("at", ""), e.get("spots", "")])
		runs.append("\n".join(log))
		await sim.free_world(world)
	check(runs[0] == runs[1] and runs[0].contains("lock"), "every attempt at a salvo run plays out the same way")


# --- The route in -----------------------------------------------------------------------------------

## The campaign's boss step plays the fight (task E1d: no placeholder card), and debug builds'
## --boss=city_boss plays that step, through the campaign's flow.
func _test_route_in() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var saved: Profile = App.profile
	App.profile = Profile.new()
	App.play_step(App.campaign.step("city/boss"))
	App.begin_run()
	await physics_frames(3)
	var run: LevelRun = App.run
	check(not App.screen is SlotScreen and run != null and run.encounter is FloatingHead
		and run.context.mode == RunContext.Mode.CAMPAIGN and run.context.step.id == "city/boss",
		"the campaign's boss step starts the fight, no placeholder card (E1d)")
	var city: float = App.campaign.step("city/boss").zone.run_speed
	if run != null:
		check(run.world.skin is CitySkin and run.hud.boss_bar.visible, "in the City's look, with the boss bar")
		# GDD §3 (E1f): as fast as the City's levels, and the fight's distances follow its pace.
		var head := run.encounter as FloatingHead
		check(is_equal_approx(run.world.tuning.run_speed, city) and is_equal_approx(run.world.player.speed, city)
			and head != null and is_equal_approx(head.run_pace(), city / MovementTuning.REFERENCE_SPEED)
			and is_equal_approx(head.arena.lap_length, city * head.arena.config.duration_seconds),
			"at the City's speed, like its levels (%.1f m/s, pace %.3f)" % [run.world.tuning.run_speed,
			head.run_pace() if head != null else 0.0])
	App.show_title()
	await tree.process_frame
	check(App.call(&"_start_boss_arg", "city_boss", PackedStringArray()), "--boss=city_boss starts the fight")
	await physics_frames(3)
	run = App.run
	check(run != null and run.encounter is FloatingHead and run.context.mode == RunContext.Mode.CAMPAIGN,
		"as the campaign's step (the full flow)")
	check(run != null and is_equal_approx(run.world.tuning.run_speed, city), "at the City's speed too")
	App.show_title()
	await tree.process_frame
	# A harder tier multiplies its speed, as it does a level's (GDD §6); the fight follows that pace too.
	App.start_boss(App.campaign.step("city/boss"), 2)
	App.begin_run()
	await physics_frames(3)
	run = App.run
	var tier_speed: float = city * App.campaign.speed_multiplier(2)
	check(run != null and is_equal_approx(run.world.tuning.run_speed, tier_speed)
		and is_equal_approx((run.encounter as FloatingHead).run_pace(), tier_speed / MovementTuning.REFERENCE_SPEED),
		"on the hardest tier, %.1f m/s" % tier_speed)
	App.show_title()
	await tree.process_frame
	App.profile = saved
	main.queue_free()
	App.main = null
	await tree.process_frame
