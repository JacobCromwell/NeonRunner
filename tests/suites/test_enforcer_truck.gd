extends TestSuite
## The Enforcer Truck (GDD §9.13; task C6), from its numbers and look to its placement (its runs on real
## physics are test_enforcer_truck_runs.gd):
## - Its numbers: the owner's (about 0.8 s lane delay, about 25 s chase, up to 3 riders, up to 2 a level),
##   its close gap inside an Octodog's lunge at every zone's pace, its follow gap behind the camera, a volley's
##   bolts reaching over a slide and a whole jump.
## - Its look: in every zone's look within an enemy's budget, only its lights and its riders' faces glow (the
##   light bar's red and a blue well away from the safe cyan); at its close gap nothing of it rises into the
##   camera's line of sight to the runner's feet (GDD §9.13: it must not hide the runner).
## - The core hooks (Enemy.charge_bait, ScoreKeeper, EnemyTuning.behind_runner): a charge contact destroys it
##   and is the player's kill; weapons (direct, splash, targeting, health bars) never touch it; a stomp, the
##   claws and the dash never defeat it; hosts, generators and every other enemy keep their old behaviour
##   (charges pass hosts and generators by; another enemy a charge flattens earns nothing); an Octodog whose
##   charges a wait moved on still winds up past its entry.
## - Placement: every campaign level that lists it at 3, 5 and 6 lanes (its own seed and others): at most 2,
##   never two at once, each with a bait in its chase, arriving off every bait's attack; Corporate 2 always
##   has one; the same every build; a level differs from the same level without it only by its trucks
##   (danger density off); quick play without a bait has none.
## - Showing itself (GDD §9.13, the owner, October 8, 2026): its numbers; beside the runner its whole look on
##   screen in the chase camera's view, hiding nothing of the runner or the side they dodge to, at 3, 5 and 6
##   lanes; never taking the only free lane (EnforcerTruckRoom.can_dodge). Its blast (the owner: a visible
##   explosion however it's destroyed): seen wherever it goes off, never in front of the runner, softer with
##   Reduced flashing. (Its showings and blasts in play are test_enforcer_truck_runs.gd.)
## - Its marker, its light bar and Reduced flashing; its warm-up look (no physics object, its blast's every
##   material); its data (the hint, its sounds).
## The worlds here keep its showings off (they move it beside the runner), unless a test asks for them.

const Rules = preload("res://scripts/enemies/enforcer_truck_rules.gd")
const BuzzRules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
const OctodogRules = preload("res://scripts/enemies/octodog_rules.gd")
const DUMMY: String = "res://tests/helpers/dummy_enemy.gd"
## Its levels (GDD §9.13: introduced in Corporate 2, then every later level with an Octodog or a Buzz
## Overdrive).
const LEVELS: Array[String] = ["corporate/2", "dead_zone/1", "dead_zone/2", "golden/1", "golden/2", "golden/3"]
## The zones' run speeds where it appears.
const SPEEDS: Array[float] = [23.4, 24.2, 25.0]
const VARIANTS: Array[StringName] = [&"city", &"vr_runner", &"burned", &"scavenger", &"golden", &"casino"]

var sim: RunSim
var t: EnforcerTruckTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = Rules.tuning()
	_test_numbers()
	await _test_model()
	_test_line_of_sight()
	_test_show_numbers()
	_test_show_view()
	_test_room()
	await _test_blast_view()
	await _test_charge_bait()
	await _test_weapons_never()
	await _test_contacts_never()
	await _test_old_behaviour()
	await _test_dog_past_its_entry()
	_test_campaign()
	_test_show_windows()
	_test_chases_with_room()
	_test_only_its_trucks()
	_test_quick_play()
	await _test_marker_and_lights()
	await _test_warm_up()
	_test_data()


# --- Helpers -------------------------------------------------------------------------------------

func _mt(speed: float = 0.0) -> MovementTuning:
	if speed <= 0.0:
		return tuning
	var out: MovementTuning = tuning.duplicate() as MovementTuning
	out.run_speed = speed
	return out


## A world on a plain track of `lanes` lanes whose truck arrives at once, the runner in the middle lane; its
## showings off unless `shows`.
func _world(lanes: int = 3, mt: MovementTuning = null, extra: Array[Dictionary] = [], shows: bool = false) -> RunWorld:
	var layout := RunSim.layout(lanes, 1500.0)
	layout.enemies.append({"type": "enforcer_truck", "at": 1.0, "lane": lanes / 2, "side": 0, "seed": 7, "params": {}})
	for e: Dictionary in extra:
		layout.enemies.append(e)
	var w: RunWorld = sim.build_world(layout, Loadout.new(), mt if mt != null else tuning)
	w.player.god_mode = true
	if not shows:
		var no_shows := func(e: Enemy) -> void:
			if e is EnforcerTruck:
				var truck := e as EnforcerTruck
				truck.tuning = truck.tuning.duplicate() as EnforcerTruckTuning
				truck.tuning.show_count = 0
		for e: Variant in w.director.active:
			if is_instance_valid(e):
				no_shows.call(e)
		w.director.enemy_spawned.connect(no_shows)
	return w


func _truck(w: RunWorld) -> EnforcerTruck:
	for e: Variant in w.director.active:
		if is_instance_valid(e) and e is EnforcerTruck:
			return e as EnforcerTruck
	return null


## Steps `w` until `done` holds or `seconds` pass. True if it held.
func _run_until(w: RunWorld, seconds: float, done: Callable) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if done.call():
			return true
		await tree.physics_frame
	return done.call()


## A world whose truck has arrived and settled behind the runner, its volleys held off for the test.
func _chasing(lanes: int = 3, mt: MovementTuning = null, extra: Array[Dictionary] = []) -> RunWorld:
	var w: RunWorld = _world(lanes, mt, extra)
	await _run_until(w, 6.0, func() -> bool:
		var tr: EnforcerTruck = _truck(w)
		return tr != null and tr.state == EnforcerTruck.State.CHASING)
	var truck: EnforcerTruck = _truck(w)
	if truck != null:
		truck.tuning = truck.tuning.duplicate() as EnforcerTruckTuning
		truck.tuning.first_volley_seconds = 999.0
	return w


# --- Numbers --------------------------------------------------------------------------------------

func _test_numbers() -> void:
	check(is_equal_approx(t.lane_delay_seconds, 0.8) and is_equal_approx(t.chase_seconds, 25.0),
		"it copies the runner's lane about 0.8 s late and gives up after about 25 s (GDD §9.13)")
	check(t.max_riders == 3 and t.per_level_max == 2, "up to 3 riders, up to 2 a level (GDD §9.13)")
	var dog := EnemyDirector.tuning_for("octodog") as OctodogTuning
	for pace: float in [1.0, 21.0 / 18.0, 23.4 / 18.0, 24.2 / 18.0, 25.0 / 18.0]:
		var gap: float = t.close_gap_for(dog, pace)
		# The lunge ends lunge_overshoot behind the runner (stretched by the pace), its body half a metre deep.
		check(gap <= dog.lunge_overshoot * pace - t.close_margin + 0.001 and gap >= EnforcerTruck.MIN_GAP,
			"at pace %.2f its close gap (%.2f m) is inside the lunge's reach (%.2f m) and never on the runner" % [pace, gap,
			dog.lunge_overshoot * pace])
	check(t.follow_gap > tuning.camera_distance, "it follows behind the camera (%.1f m > %.1f m)" % [t.follow_gap, tuning.camera_distance])
	check(t.hitbox_size.z + 0.2 <= t.body_size.z and t.hitbox_size.y + t.hitbox_floor <= t.body_size.y + 0.001
		and t.hitbox_size.x <= t.body_size.x, "its hitbox is a little smaller than its look")
	# A shot's column of bolts reaches a runner at any height of a jump, and a sliding one.
	var radius: float = 0.09
	var uncovered: PackedStringArray = []
	var top: float = tuning.jump_height + 0.05
	var h: float = 0.0
	while h <= top:
		var hit: bool = false
		for b: float in t.bolt_heights:
			hit = hit or (b + radius > h and b - radius < h + tuning.hurtbox_size.y)
		if not hit:
			uncovered.append("%.2f" % h)
		h += 0.02
	var slide_hit: bool = false
	for b: float in t.bolt_heights:
		slide_hit = slide_hit or b - radius < tuning.hurtbox_slide_height
	check(uncovered.is_empty() and slide_hit, "a shot's bolts reach a sliding runner and one at any height of a jump (%s)" % [uncovered])
	check(t.warning_seconds >= 0.8 and t.bolt_flight_seconds >= 0.2,
		"a volley's warning (%.2f s) and the bolts' flight (%.2f s) give time to change lanes" % [t.warning_seconds,
		t.bolt_flight_seconds])
	var intervals: Array[float] = []
	for n: int in t.max_riders + 1:
		intervals.append(t.volley_interval(n))
	var faster: bool = true
	for i: int in range(1, intervals.size()):
		faster = faster and intervals[i] < intervals[i - 1] - 0.01
	check(faster, "each rider raises its rate of fire: the intervals %s" % [intervals])
	check(not t.uses_floor and t.behind_runner, "it never stands on the floor ahead of the runner (no floor use, behind_runner)")


# --- Look -----------------------------------------------------------------------------------------

func _test_model() -> void:
	var looks: Dictionary = {}
	for variant: StringName in VARIANTS:
		var m := EnforcerTruckModel.new()
		tree.root.add_child(m)
		m.build(variant, t.body_size)
		m.set_riders(3)
		looks[EnforcerTruckModel.look_of(variant)] = true
		check(m.draw_call_count() <= 12, "%s: a few draw calls with three riders (%d)" % [variant, m.draw_call_count()])
		check(m.triangle_count() <= 2400, "%s: %d triangles with three riders (within an enemy's 2,400)" % [variant, m.triangle_count()])
		var faults: PackedStringArray = []
		var glowing: int = 0
		for entry: Dictionary in m.materials():
			var mat := entry["material"] as StandardMaterial3D
			if mat == null or not mat.emission_enabled:
				continue
			glowing += 1
			var c: Color = mat.emission
			var part: String = String(entry["part"])
			var red: bool = c.r > 0.85 and c.g < 0.3 and c.b < 0.3
			var blue: bool = c.b > 0.8 and c.r < 0.3 and c.g < 0.45
			var white: bool = c.r > 0.75 and c.g > 0.85 and c.b > 0.9
			var ok: bool = (part.begins_with("light bar") or part.begins_with("Bar")) and (red or blue \
				or (c.v < 0.6 and (c.r > c.g * 2.0 or c.b > c.r * 2.0)))
			ok = ok or (part == "Headlights" and white) or (part.ends_with("/Face") and white)
			if not ok:
				faults.append("%s glows %s" % [part, c])
		check(faults.is_empty() and glowing >= 5, "%s: only its headlights, its light bar and its riders' faces glow %s" % [variant, faults])
		m.queue_free()
	check(looks.size() == 3, "three looks: clean, weathered and gilded (%s)" % [looks.keys()])
	# The light bar's blue stays well away from the safe cyan (GDD: only hazards glow in hazard colours).
	var blue: Color = EnforcerTruckModel.BAR_BLUE
	var cyan := Color(0.25, 0.85, 1.0)
	check(absf(blue.h - cyan.h) > 0.08, "the light bar's blue (hue %.2f) is no safe cyan (hue %.2f)" % [blue.h, cyan.h])
	# Its floor lights: unshaded, added light, in its lane.
	var lights: Node3D = EnforcerTruckModel.floor_lights()
	var additive: bool = true
	for c: Node in lights.get_children():
		var mat := (c as MeshInstance3D).material_override as StandardMaterial3D
		additive = additive and mat != null and mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD \
			and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		var aabb: AABB = (c as MeshInstance3D).mesh.get_aabb()
		additive = additive and aabb.size.y < 0.01 and aabb.position.x >= -t.body_size.x * 0.7 \
			and aabb.end.x <= t.body_size.x * 0.7
	check(lights.get_child_count() == 3 and additive,
		"its headlights' beams and the light bar's washes are flat, unshaded, additive shapes on the floor of its lane")
	lights.free()
	await tree.process_frame


## GDD §9.13: while it closes up behind the runner it must not hide them. At its close gap, at every zone's
## pace, every vertex of its body, light bar and riders lies under the line from the camera (its height and
## distance behind the runner, MovementTuning) to the runner's feet, at its own distance behind them.
func _test_line_of_sight() -> void:
	var dog := EnemyDirector.tuning_for("octodog") as OctodogTuning
	for variant: StringName in [&"vr_runner", &"burned", &"golden"]:
		var m := EnforcerTruckModel.new()
		m.build(variant, t.body_size)
		m.set_riders(3)
		var verts: PackedVector3Array = m.solid_vertices()
		for pace: float in [1.0, 23.4 / 18.0, 25.0 / 18.0]:
			var gap: float = t.close_gap_for(dog, pace)
			var worst: float = INF
			var worst_at: Vector3 = Vector3.ZERO
			for v: Vector3 in verts:
				var behind: float = gap + v.z
				var limit: float = tuning.camera_height * behind / tuning.camera_distance
				if limit - v.y < worst:
					worst = limit - v.y
					worst_at = Vector3(v.x, v.y, behind)
			check(worst > 0.0, "%s at pace %.2f: nothing of it rises into the camera's line of sight to the runner's feet (closest %.2f m below it, at %.1f m behind, %.2f m up)"
				% [variant, pace, worst, worst_at.z, worst_at.y])
		m.free()


# --- Showing itself and its blast (task C6b) ---------------------------------------------------------

## GDD §9.13 "Showing itself" (the owner, October 8, 2026): its numbers. A few seconds alongside (the owner), its
## shortest stay a little less; on arrival and once more mid-chase; it closes in and drops back quicker than it
## gives up the chase; it's back behind the runner before a bait with a margin; its blast comes a lurch after it's
## hit and lasts about a second.
func _test_show_numbers() -> void:
	check(t.show_seconds >= 2.0 and t.show_seconds <= 4.0 and t.show_min_seconds <= t.show_seconds and t.show_min_seconds >= 1.0,
		"it stays alongside a few seconds (%.1f s; never under %.1f s)" % [t.show_seconds, t.show_min_seconds])
	check(t.show_count >= 2 and t.show_on_arrival, "it shows itself as it arrives and once more mid-chase (%d)" % t.show_count)
	check(t.show_yield_speed >= t.show_drop_speed and t.show_close_speed > t.leave_speed,
		"it gives way faster than it drops back, and closes in faster than it gives up")
	check(t.show_margin_seconds > 0.0 and t.close_lead_seconds > 0.0, "it's back behind the runner a margin before a bait")
	check(t.wreck_surge_seconds <= 0.5 and t.blast_seconds >= 0.5 and t.blast_seconds <= 1.5 and t.blast_radius_in_lane < t.blast_radius,
		"its wreck blows up %.2f s after it's hit, burning %.2f s; smaller in the runner's lane" % [t.wreck_surge_seconds, t.blast_seconds])
	check(t.blocker_ahead >= 1.0, "its solid side reaches ahead of its front (%.1f m)" % t.blocker_ahead)


## GDD §9.13: shown beside the runner, the chase camera shows its whole look and it never hides the runner (nor
## the floor of their lane and the lanes past it, the side they dodge to). In the run camera's resting view
## (EnforcerTruckView), at 3, 5 and 6 lanes, a runner in every lane with a lane on each side, the truck in either
## lane beside them, and a runner by a wall, the truck two lanes in (task C6c: EnforcerTruckRoom.sides), every look,
## with three riders: every corner of it on screen, nothing of the runner or of that floor (up to 2 m above it, to
## 60 m ahead; two lanes in, the lane between them too) behind it. The room's table of where it fits
## (EnforcerTruckRoom.fits_for) holds every one of those pairs.
func _test_show_view() -> void:
	var faults: PackedStringArray = []
	var worst: float = 0.0
	for look: StringName in EnforcerTruckModel.LOOKS:
		var profile: Array[AABB] = EnforcerTruckModel.profile(look, t.body_size, EnforcerTruckModel.RIDER_SLOTS.size())
		for lanes: int in [3, 5, 6]:
			for r: int in lanes:
				var ls: Array[int] = []
				if r > 0 and r < lanes - 1:
					ls.append_array([r - 1, r + 1])
				else:
					ls.append(r + (2 if r == 0 else -2))
				for l: int in ls:
					var c: Dictionary = EnforcerTruckView.check(tuning, lanes, r, l, t.show_ahead, profile)
					worst = maxf(worst, float(c["worst"]))
					if not bool(c["fits"]) or bool(c["hides_runner"]) or bool(c["hides_floor"]):
						faults.append("%s %d lanes, runner %d, truck %d: %s" % [look, lanes, r, l, c])
	check(faults.is_empty(), "beside the runner (two lanes in from one by a wall) its whole look is on screen (its furthest corner %.0f%% of the way to the edge), hiding nothing of them or their side (%s)"
		% [worst * 100.0, faults])
	var unfit: PackedStringArray = []
	for lanes: int in [3, 5, 6]:
		var fits: Dictionary = EnforcerTruckRoom.fits_for(tuning, t, lanes)
		for key: int in fits:
			if not bool(fits[key]):
				unfit.append("%d lanes: runner %d, truck %d" % [lanes, key / 64, key % 64])
		check(fits.size() == 2 * lanes - 2, "%d lanes: the room's table holds a pair for each side of every runner lane (%d)" % [lanes,
			fits.size()])
	check(unfit.is_empty(), "every pair fits in the room's table (%s)" % [unfit])
	# Beside the runner its inner neighbour lane would hide the floor of a runner by a wall's lane at 5 and 6 lanes
	# (the camera sits inward of them): why it goes two lanes in (task C6c; the owner's answer to docs/OPEN_QUESTIONS.md
	# item 382, October 9, 2026).
	var hidden: PackedStringArray = []
	for lanes: int in [5, 6]:
		var c: Dictionary = EnforcerTruckView.check(tuning, lanes, 0, 1, t.show_ahead,
			EnforcerTruckModel.profile(&"clean", t.body_size, EnforcerTruckModel.RIDER_SLOTS.size()))
		if bool(c["hides_floor"]) or bool(c["hides_runner"]):
			hidden.append("%d lanes" % lanes)
	check(hidden.size() == 2, "beside a runner by a wall, on their inner side, it would hide their side of the floor (%s)" % [hidden])
	# The run camera widens with speed (never narrower than its base field of view), and the riders sit above the
	# light bar: the profile holds them all.
	var bare: Array[AABB] = EnforcerTruckModel.profile(&"clean", t.body_size, 0)
	check(bare.size() == 1 and EnforcerTruckModel.profile(&"clean", t.body_size, 3).size() == 4,
		"its look's boxes: its body, and one for each rider aboard")


## GDD §9.13: it never takes the only free lane (EnforcerTruckRoom.can_dodge, the layout's side), at 3, 5 and 6
## lanes, the runner in the middle lane: a row of holes across every lane is no free lane taken (the runner jumps
## it, the truck hops its gap); holes in the runner's lane and the far lane with the truck's lane free would leave it
## the only free one; a zone doodad in the runner's lane needs the far lane open, holes or not in the truck's lane;
## holes a lane change apart in the runner's lane and the far lane are fine. A runner by a wall (task C6c): it shows
## itself two lanes in, leaving them the lane between (EnforcerTruckRoom.sides, escape_lane), held to the same rule
## both ways: a doodad in the runner's lane needs the lane between open, one in the lane between needs the runner's
## lane open (they stay in it), and a row of holes across every lane takes no free lane.
func _test_room() -> void:
	for lanes: int in [3, 5, 6]:
		var r: int = lanes / 2
		var l: int = r + 1
		var o: int = r - 1
		var v: float = 23.4
		var cases: Array = [
			["a row of holes across every lane", [[r, "gap"], [o, "gap"], [l, "gap"]], true],
			["holes in the runner's lane and the far lane, the truck's lane free", [[r, "gap"], [o, "gap"]], false],
			["a hole in the runner's lane only", [[r, "gap"]], true],
			["a doodad in the runner's lane, the far lane open", [[r, "doodad"]], true],
			["a doodad in the runner's lane and a hole in the far lane, a hole in the truck's lane too", [[r, "doodad"], [o, "gap"], [l, "gap"]], false],
			["holes a lane change apart in the runner's lane and the far lane", [[r, "gap"], [o, "gap_later"]], true],
		]
		for case: Array in cases:
			var room: EnforcerTruckRoom = _room_with(lanes, case[1], v)
			var ok: bool = room.can_dodge(r, l, t, 50.0, 4.0, v)
			check(ok == bool(case[2]), "%d lanes, %s: %s" % [lanes, case[0], "it may show itself" if bool(case[2]) else "it never does"])
		# A runner by each wall: the truck two lanes in, the lane between theirs.
		for wall: int in [0, lanes - 1]:
			var in_: int = 1 if wall == 0 else -1
			var between: int = wall + in_
			var truck: int = wall + 2 * in_
			var plain: EnforcerTruckRoom = _room_with(lanes, [], v)
			check(plain.sides(wall, 0) == [truck] and plain.sides(wall, 1) == [truck] and plain.escape_lane(wall, truck) == between
				and plain.escape_lane(wall, between) == -1, "%d lanes, a runner in lane %d (by a wall): it shows itself only in lane %d, two lanes in, leaving them lane %d (%s)"
				% [lanes, wall, truck, between, plain.sides(wall, 0)])
			var outer: Array = [
				["a row of holes across every lane", [[wall, "gap"], [between, "gap"], [truck, "gap"]], true],
				["a doodad in the runner's lane, the lane between open", [[wall, "doodad"]], true],
				["a doodad in the runner's lane and a hole in the lane between", [[wall, "doodad"], [between, "gap"]], false],
				["a doodad in the lane between, the runner's lane open", [[between, "doodad"]], true],
				["a doodad in the lane between and a hole in the runner's lane", [[between, "doodad"], [wall, "gap"]], false],
				["holes in the runner's lane and the lane between, the truck's lane free", [[wall, "gap"], [between, "gap"]], false],
			]
			for case: Array in outer:
				var room: EnforcerTruckRoom = _room_with(lanes, case[1], v)
				var ok: bool = room.can_dodge(wall, truck, t, 50.0, 4.0, v)
				check(ok == bool(case[2]), "%d lanes, a runner in lane %d, the truck in lane %d, %s: %s" % [lanes, wall, truck, case[0],
					"it may show itself" if bool(case[2]) else "it never does"])


## A room (EnforcerTruckRoom) over a plain track of `lanes` lanes holding `items` ([lane, "gap" | "gap_later" |
## "doodad"]) around 100 m, at run speed `v`.
func _room_with(lanes: int, items: Array, v: float) -> EnforcerTruckRoom:
	var layout := LevelLayout.new()
	layout.lane_count = lanes
	layout.length = 600.0
	for item: Array in items:
		var lane: int = int(item[0])
		match String(item[1]):
			"gap":
				layout.gaps.append({"lane": lane, "start": 100.0, "end": 106.0})
			"gap_later":
				layout.gaps.append({"lane": lane, "start": 106.0 + 0.3 * v, "end": 112.0 + 0.3 * v})
			"doodad":
				layout.doodads.append({"lane": lane, "start": 100.0, "end": 103.0, "size": "medium", "side": 1, "seed": 1})
	return EnforcerTruckRoom.build(layout, TrackGeometry.new(lanes, tuning), tuning, t, v)


## The owner (October 8, 2026): when it's destroyed there's a visible explosion. Its blast where it goes off (its
## wreck's front wreck_gap behind the runner, or closer beside them; in a hole, at the hole's far edge, up to 3.75 m
## behind), at 3, 5 and 6 lanes, the runner in every lane, the truck in their lane or beside it, burning out
## falling back at blast_drift: in the run camera's resting view its fireball shows in every frame from its
## first moments (0.05 s: at its farthest, its first swell rises from under the view's bottom edge), and no puff
## of it ever stands between the camera and the runner. With Reduced flashing it has no white-hot core and its
## fire comes up over its swell, softer (no bright flash). Its fading copies of its materials are the warmed
## ones' twins (the same shaders: nothing to build mid-run).
func _test_blast_view() -> void:
	var faults: PackedStringArray = []
	var closest: float = INF
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		for r: int in lanes:
			for l: int in [r - 1, r, r + 1]:
				if l < 0 or l >= lanes:
					continue
				var in_lane: bool = l == r
				for front: float in ([t.wreck_gap, 3.0, 3.75] if in_lane else [2.4, t.wreck_gap]):
					var blast := EnforcerTruckBlast.new()
					var spot: Vector3 = EnforcerTruck.blast_spot(in_lane, signf(geo.lane_x(l) - geo.lane_x(r)))
					blast.start(t.blast_radius_in_lane if in_lane else t.blast_radius, t.blast_seconds, false, in_lane)
					var view := EnforcerTruckView.of_runner(tuning, geo, r, 0.0)
					var points: PackedVector3Array = EnforcerTruckView.runner_points(tuning, geo.lane_x(r), 0.0)
					var unseen: int = 0
					var age: float = 0.0
					while age < t.blast_seconds:
						var at := Vector3(geo.lane_x(l), 0.0, TrackGeometry.world_z(-(front + t.blast_drift * age))) + spot
						var seen: bool = false
						for s: Vector4 in blast.spheres():
							var c: Vector3 = at + Vector3(s.x, s.y, s.z)
							seen = seen or view.on_screen(c + Vector3(0.0, s.w * 0.5, 0.0), 0.0)
							for p: Vector3 in points:
								var ab: Vector3 = p - view.origin
								var k: float = clampf((c - view.origin).dot(ab) / ab.length_squared(), 0.0, 1.0)
								closest = minf(closest, (view.origin + ab * k).distance_to(c) - s.w)
						if not seen and not blast.spheres().is_empty() and age >= 0.05:
							unseen += 1
						blast.advance(1.0 / 60.0)
						age += 1.0 / 60.0
					if unseen > 0:
						faults.append("%d lanes, runner %d, truck %d, %.2f m: unseen %d frames" % [lanes, r, l, front, unseen])
					blast.free()
	check(faults.is_empty(), "the camera sees its blast wherever it goes off (%s)" % [faults])
	check(closest > 0.0, "and it never stands between the camera and the runner (%.2f m clear at the closest)" % closest)
	# Reduced flashing: no white-hot core, a softer fire coming up over its swell.
	var normal := EnforcerTruckBlast.new()
	normal.start(t.blast_radius, t.blast_seconds, false)
	var soft := EnforcerTruckBlast.new()
	soft.start(t.blast_radius, t.blast_seconds, true)
	var normal_alpha: float = _first_fire_alpha(normal)
	var soft_alpha: float = _first_fire_alpha(soft)
	check(soft.get_child_count() == normal.get_child_count() - 1 and soft_alpha < normal_alpha * 0.5,
		"with Reduced flashing: no white-hot core, its fire coming up softly (%.2f, against %.2f at once)" % [soft_alpha, normal_alpha])
	var twins: PackedStringArray = []
	for blast: EnforcerTruckBlast in [normal, soft]:
		for p: Dictionary in blast.get(&"_puffs") as Array[Dictionary]:
			if not _same_shader(p["mat"] as StandardMaterial3D, EnforcerTruckBlast.material(p["kind"])):
				twins.append(String(p["kind"]))
		if not _same_shader(blast.get(&"_glow_mat") as StandardMaterial3D, EnforcerTruckBlast.material(&"glow")):
			twins.append("glow")
	check(twins.is_empty(), "its fading materials have the warmed ones' shaders (unlike: %s)" % [twins])
	normal.free()
	soft.free()
	await tree.process_frame


## True if `a` and `b` build the same shader (the settings a StandardMaterial3D's shader depends on that the
## blast's materials use).
static func _same_shader(a: StandardMaterial3D, b: StandardMaterial3D) -> bool:
	if a == null or b == null:
		return false
	for prop: StringName in [&"shading_mode", &"transparency", &"blend_mode", &"cull_mode", &"depth_draw_mode",
			&"no_depth_test", &"vertex_color_use_as_albedo", &"emission_enabled"]:
		if a.get(prop) != b.get(prop):
			return false
	return true


## The opacity of `blast`'s first fire puff as it goes off.
static func _first_fire_alpha(blast: EnforcerTruckBlast) -> float:
	for c: Node in blast.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not mi.visible or mi.name == "FloorGlow":
			continue
		var m := mi.material_override as StandardMaterial3D
		if m != null and m.emission_enabled and m.emission.is_equal_approx(EnforcerTruckBlast.FIRE):
			return m.albedo_color.a
	return 0.0


# --- Core hooks -------------------------------------------------------------------------------------

## A charge contact (Enemy._hurt_charge_contacts) destroys it, as the player's kill with its score and the
## rider bonus; the director relays one defeat with the charge's cause.
func _test_charge_bait() -> void:
	var w: RunWorld = await _chasing(3)
	var truck: EnforcerTruck = _truck(w)
	check(truck != null and truck.charge_bait and truck.immune_to_weapons, "it declares charge_bait and weapon immunity")
	if truck == null:
		await sim.free_world(w)
		return
	truck.riders = 2
	truck.model.set_riders(2)
	var attacker := Enemy.new()
	w.add_child(attacker)
	attacker.setup(w, {}, null)
	var box: Hazard = attacker.add_hitbox(&"body", Vector3(0.8, 0.8, 0.9), Vector3(0.0, 0.4, 0.0), true)
	attacker.global_position = truck.global_position + Vector3(0.0, 0.0, 1.5)
	attacker.set_physics_process(false)
	var causes: Array[StringName] = []
	w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
		if e == truck:
			causes.append(cause))
	var before: Dictionary = w.score.stats()
	await physics_frames(2)
	attacker._begin_charge_contacts()
	attacker._hurt_charge_contacts(box, box.global_transform)
	var after: Dictionary = w.score.stats()
	check(not truck.alive and causes == [Enemy.CHARGE_DAMAGE_CAUSE], "a charge's contact destroys it, once (%s)" % [causes])
	check(int(after["kills"]) == int(before["kills"]) + 1, "it's the player's kill (a bait)")
	var gained: int = int(after["score"]) - int(before["score"])
	check(gained == t.score_value + 2 * t.rider_bonus, "with its score and a bonus for each rider aboard (%d)" % gained)
	check(int((after["bonuses"] as Dictionary).get("enforcer_riders", 0)) == 2 * t.rider_bonus,
		"the riders' bonus shows as its own (%s)" % [after["bonuses"]])
	check(truck.history.back()[0] == "wreck:enemy_charge", "it's wrecked by the charge (%s)" % [truck.history.back()])
	attacker.free()
	await sim.free_world(w)


## Weapons never touch it: auto-fire never targets it, a shot through it and a missile's splash beside it do
## nothing, and it shows no health bar.
func _test_weapons_never() -> void:
	var w: RunWorld = await _chasing(3)
	var truck: EnforcerTruck = _truck(w)
	if truck == null:
		check(false, "a truck to shoot at")
		await sim.free_world(w)
		return
	var hits: Array[int] = [0]
	w.projectiles.enemy_hit.connect(func(e: Enemy, _d: float, _s: bool) -> void:
		if e == truck:
			hits[0] += 1)
	var targets: Array[Enemy] = w.director.targets_ahead(truck.aim_point() + Vector3(0.0, 0.0, 20.0), 100.0)
	check(not targets.has(truck) and not truck.targetable(), "auto-fire never picks it")
	var from: Vector3 = truck.aim_point() + Vector3(0.0, 0.0, 6.0)
	w.projectiles.fire_player(from, Vector3(0.0, 0.0, -60.0), 99.0, &"laser")
	w.projectiles.fire_player(from, Vector3(0.0, 0.0, -60.0), 99.0, &"heavy_missile", null, 0.0, 6.0, 1.0)
	truck.take_damage(99.0, &"weapon")
	truck.take_damage(99.0, &"weapon", true)
	await physics_frames(20)
	check(truck.alive and hits[0] == 0 and is_equal_approx(truck.health, truck.max_health),
		"shots and splash pass it by: no hit, no damage (%d hits, health %.1f)" % [hits[0], truck.health])
	check(not EnemyHealthBars.wants_bar(truck), "it never shows a health bar")
	await sim.free_world(w)


## A stomp, the claws and the dash never defeat it, whatever protects the runner (DamageRules on its
## hitbox); it never touches the runner anyway (its gap, test_enforcer_truck_runs.gd).
func _test_contacts_never() -> void:
	var w: RunWorld = await _chasing(3)
	var truck: EnforcerTruck = _truck(w)
	var box: Hazard = truck.get(&"_body") as Hazard if truck != null else null
	check(box != null and box.part == &"body" and box.is_active(), "its body is a live hitbox (charges can reach it)")
	if box != null:
		var faults: PackedStringArray = []
		for protection: String in ["", "armor", "shield", "claws", "dashing", "invulnerable", "god_mode"]:
			for stomping: bool in [false, true]:
				var d := DamageRules.Defense.new()
				if protection != "":
					d.set(protection, true)
				var outcome: DamageRules.Outcome = DamageRules.resolve(box, d, stomping)
				if outcome == DamageRules.Outcome.STOMP or outcome == DamageRules.Outcome.DEFEAT_ENEMY:
					faults.append("%s/stomp=%s" % [protection, stomping])
		check(faults.is_empty(), "a stomp, the claws and the dash never defeat it (%s)" % [faults])
		check(not truck.stompable and truck.claw_immune and not truck.dash_kills, "it declares it: not stompable, claw-immune, no dash kill")
	await sim.free_world(w)


## Hosts and fence generators keep their immunity to charges as to weapons; another enemy a charge flattens
## still earns the player nothing.
func _test_old_behaviour() -> void:
	var w: RunWorld = _world(3)
	await physics_frames(2)
	var host: Enemy = w.director.spawn({"type": "cyborg", "at": 60.0, "lane": 1, "side": 0, "seed": 3,
		"params": {"host": true, "fires": false}})
	var generator: Enemy = w.director.spawn({"type": "generator", "at": 60.0, "lane": 1, "side": 0, "seed": 4, "params": {}})
	var cyborg: Enemy = w.director.spawn({"type": "cyborg", "at": 60.0, "lane": 1, "side": 0, "seed": 5,
		"params": {"fires": false}})
	for e: Enemy in [host, generator, cyborg]:
		e.set_physics_process(false)
		e.global_position = Vector3(0.0, 0.0, -60.0)
	var attacker := Enemy.new()
	w.add_child(attacker)
	attacker.setup(w, {}, null)
	var box: Hazard = attacker.add_hitbox(&"body", Vector3(1.0, 1.6, 1.0), Vector3(0.0, 0.8, 0.0), true)
	attacker.global_position = Vector3(0.0, 0.0, -60.0)
	attacker.set_physics_process(false)
	var before: Dictionary = w.score.stats()
	await physics_frames(2)
	attacker._begin_charge_contacts()
	attacker._hurt_charge_contacts(box, box.global_transform)
	var after: Dictionary = w.score.stats()
	check(host.alive and generator.alive, "a charge passes a host and a fence generator by, as before")
	check(not host.charge_bait and not generator.charge_bait and not cyborg.charge_bait, "none of them declares charge_bait")
	check(not cyborg.alive and int(after["kills"]) == int(before["kills"]) and int(after["score"]) == int(before["score"]),
		"a cyborg a charge flattens is no kill of the player's, as before")
	host.take_damage(99.0, &"weapon")
	generator.take_damage(99.0, &"weapon")
	check(host.alive and generator.alive, "weapons still never hurt a host or a generator")
	attacker.free()
	await sim.free_world(w)


## An Octodog whose charges a wait moved on checks other enemies near its stretch (Octodog.charge_clear); a
## truck's entry there (where it arrived) never holds it back, while any other enemy there still does.
func _test_dog_past_its_entry() -> void:
	var layout := RunSim.layout(3, 600.0)
	layout.enemies.append({"type": "enforcer_truck", "at": 205.0, "lane": 1, "side": 0, "seed": 1, "params": {}})
	check(Octodog.charge_clear(layout, 200.0, 40.0), "a truck's entry inside a charge's stretch keeps it clear")
	layout.enemies.append({"type": "cyborg", "at": 205.0, "lane": 1, "side": 0, "seed": 2, "params": {}})
	check(not Octodog.charge_clear(layout, 200.0, 40.0), "a cyborg there still doesn't")
	await tree.process_frame


# --- Placement ------------------------------------------------------------------------------------

func _test_campaign() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var listed: bool = s.level.has_feature("enforcer_truck")
		check(listed == LEVELS.has(String(s.id)), "%s %s the Enforcer Truck" % [s.id, "lists" if listed else "doesn't list"])
		if not listed:
			continue
		var counts: PackedStringArray = []
		var with_baits: bool = true
		for lanes: int in [3, 5, 6]:
			for k: int in 3:
				var config: LevelConfig = campaign.configure(s, lanes)
				if k > 0:
					config.level_seed = 9100 + k
				var m: MovementTuning = config.movement_for(tuning)
				var patterns: Array = LevelGenerator.load_for(config)
				var gen: LevelGenerator = LayoutCache.generator(config, m, patterns)
				var tag: String = "(%s, %d lanes, seed %d)" % [s.id, lanes, config.level_seed]
				var trucks: Array[Dictionary] = Rules.trucks_in(gen.layout)
				var problems: PackedStringArray = Rules.problems(gen)
				check(problems.is_empty(), "its placement rules hold %s: %s" % [tag, "; ".join(problems)])
				for e: Dictionary in trucks:
					with_baits = with_baits and not ((e.get("params", {}) as Dictionary).get("baits", []) as Array).is_empty()
				if k == 0:
					counts.append("%d lanes: %d" % [lanes, trucks.size()])
					if String(s.id) == "corporate/2":
						check(not trucks.is_empty(), "Corporate 2 introduces it on its own seed %s" % tag)
					var again: LevelLayout = LevelGenerator.new().generate(config, m, patterns)
					check(JSON.stringify(Rules.trucks_in(again)) == JSON.stringify(trucks), "the same trucks every build " + tag)
		check(with_baits, "%s: every truck lists the baits planned in its chase" % s.id)
		print("  %s Enforcer Trucks: %s" % [s.id, ", ".join(counts)])


func _generate(config: LevelConfig, m: MovementTuning, patterns: Array) -> LevelGenerator:
	var gen := LevelGenerator.new()
	gen.generate(config, m, patterns)
	return gen


## Task C6c (GDD §9.13 "Showing itself", the owner, October 8, 2026): each chase's planned showing window, on every
## campaign level with the truck at 3, 5 and 6 lanes (its own seed and another). Where one is planned (its params'
## "show"), it lies in its chase (as it arrives, or later before it gives up) and holds in the finished level
## (ShowPlanner.problem_of): for a runner in every lane, as its showing begins and show_window_slack_seconds later,
## a lane beside them where its look fits on screen, its lane stays clear, they keep a lane to dodge into and it
## hides no enemy (EnforcerTruckRoom.layout_lane), and no other big attack, floor cut, hover truck or Gilded Sentinel
## comes meanwhile. Every pass after the trucks kept off it: no zone doodad, filler, wider gap or row the danger
## density pass made or widened stands in it, nor any enemy that pass added or cyborg planted in a charge path
## (where it stands or attacks). Corporate 2 at 3 lanes has its first truck's arrival showing. Each level's windows
## are printed (gen.show_window_result: why a chase has none).
func _test_show_windows() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var room_m: float = LevelGenerator.DangerDensity.CALM_ROOM
	for id: String in LEVELS:
		var counts: PackedStringArray = []
		for lanes: int in [3, 5, 6]:
			for k: int in 2:
				var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
				if k > 0:
					config.level_seed = 9101
				var m: MovementTuning = config.movement_for(tuning)
				var gen: LevelGenerator = LayoutCache.generator(config, m, LevelGenerator.load_for(config))
				var tag: String = "(%s, %d lanes, seed %d)" % [id, lanes, config.level_seed]
				var trucks: Array[Dictionary] = Rules.trucks_in(gen.layout)
				var planner: Rules.ShowPlanner = Rules.ShowPlanner.make(gen, t)
				var v: float = gen.speed
				var windows: int = 0
				var arrivals: int = 0
				var faults: PackedStringArray = []
				for e: Dictionary in trucks:
					var at: float = float(e["at"])
					var w: Vector2 = Rules.window_of(e)
					if w.y < w.x:
						continue
					windows += 1
					var due: float = float(((e["params"] as Dictionary)["show"] as Dictionary)["at"])
					arrivals += 1 if absf(due - at) < 0.001 else 0
					var where: String = "the truck at %.0f m, its window %.0f-%.0f m" % [at, w.x, w.y]
					if due < at - 0.001 or due > at + (t.chase_seconds - t.show_min_seconds) * v or w.x >= due or w.y <= due:
						faults.append("%s: due at %.0f m, outside its chase or its stretch" % [where, due])
					var why: String = planner.problem_of(e)
					if why != "":
						faults.append("%s: %s" % [where, why])
					for d: Dictionary in gen.layout.doodads:
						if float(d["start"]) <= w.y and float(d["end"]) >= w.x:
							faults.append("%s: a zone doodad at %.0f m" % [where, float(d["start"])])
					for f: Dictionary in gen.fills:
						if float(f["at"]) <= w.y and float(f["at"]) + float(f["used"]) >= w.x:
							faults.append("%s: a filler at %.0f m" % [where, float(f["at"])])
					for r: Variant in gen.wide_gap_result.get("rows", []):
						if (r as Vector2).x <= w.y and (r as Vector2).y >= w.x:
							faults.append("%s: a wider gap at %.0f m" % [where, (r as Vector2).x])
					for r: Variant in gen.danger_density_result.get("rows_touched", []):
						if float((r as Dictionary)["start"]) <= w.y and float((r as Dictionary)["end"]) >= w.x:
							faults.append("%s: a row the danger density pass made or widened at %.0f m" % [where, float((r as Dictionary)["start"])])
					for a: Variant in gen.danger_density_result.get("added_enemies", []):
						var spot: float = float((a as Dictionary)["at"])
						var kw: Vector2 = LevelGenerator.DangerDensity.attack_window(gen, a as Dictionary)
						var lo: float = minf(spot - room_m, kw.x if kw.y >= kw.x else INF)
						var hi: float = maxf(spot + room_m, kw.y if kw.y >= kw.x else -INF)
						if lo <= w.y and hi >= w.x:
							faults.append("%s: a %s the danger density pass added at %.0f m" % [where, (a as Dictionary)["type"], spot])
					for c: Variant in gen.charge_path_result.get("planted", []):
						var spot: float = float(((c as Dictionary)["cyborg"] as Dictionary)["at"])
						if spot - room_m <= w.y and spot + room_m >= w.x:
							faults.append("%s: a cyborg planted in a charge path at %.0f m" % [where, spot])
				check(faults.is_empty(), "%s each planned showing window holds in the finished level, kept clear by every later pass (%s)"
					% [tag, "; ".join(faults)])
				var report: Array = gen.show_window_result.get("chases", [])
				check(report.size() == trucks.size(), "%s the report lists each chase (%d of %d)" % [tag, report.size(), trucks.size()])
				if k == 0:
					var none: PackedStringArray = []
					for line: Variant in report:
						if ((line as Dictionary)["window"] as Dictionary).is_empty():
							none.append(String((line as Dictionary)["why"]))
					counts.append("%d lanes: %d of %d (%d as it arrives)%s" % [lanes, windows, trucks.size(), arrivals,
						"" if none.is_empty() else " - none: " + ", ".join(none)])
					if id == "corporate/2" and lanes == 3:
						var first: Dictionary = trucks[0] if not trucks.is_empty() else {}
						var show: Dictionary = (first.get("params", {}) as Dictionary).get("show", {})
						check(not show.is_empty() and absf(float(show["at"]) - float(first["at"])) < 0.001,
							"Corporate 2 at 3 lanes: its first truck's showing is planned as it arrives (%s)" % [show])
		print("  %s showing windows: %s" % [id, "; ".join(counts)])


## Task C6d (GDD §9.13 "Room to show itself", the owner, October 9, 2026: it shows itself before the player can bait
## it, arriving early enough for that, and a chase with no room for a showing gives its truck to another bait's chase
## that has room).
## - On a plain track at 3, 5 and 6 lanes with two Octodogs (their rules plan their charges): the first's first
##   wind-up comes about 8 s past the run-up, too soon for a showing before it, the second's over a minute later. One
##   truck a level: it goes to the second, its window before its bait (C6c's choice, one window each, kept the
##   first); a level that introduces it there moves its introduction too; with the first wind-up later, where its
##   chase has room, the truck stays at the first. Two a level: both baits get one.
## - Every campaign level with the truck at 3, 5 and 6 lanes, on its own seed and two others: every truck keeps its
##   placement rules (a bait in its chase, never two at once, never arriving where none may: Rules.problems), those
##   that arrive earlier than their preferred arrival and those that skip an earlier free bait included; a truck
##   without a window before its bait has no bait left whose own chase has one and that its level could give a
##   truck beside the others (gen.show_window_result's baits), nor does a level with fewer trucks than it may have;
##   Corporate 2 always has its introduction (a truck in its layout, so the level's intro lists its first-encounter
##   hint; the charge-path cyborg before it is test_charge_paths'). The chases' windows are printed.
func _test_chases_with_room() -> void:
	var keep_max: int = t.per_level_max
	for lanes: int in [3, 5, 6]:
		# [trucks a level, introduced, where the first dog stands, the bait its truck should take (0 or 1), trucks]
		for case: Array in [[1, false, 230.0, 1, 1], [1, true, 230.0, 1, 1], [1, false, 500.0, 0, 1],
				[2, false, 230.0, -1, 2]]:
			t.per_level_max = int(case[0])
			var gen: LevelGenerator = _dogs_gen(lanes, [float(case[2]), 1500.0], bool(case[1]))
			Rules.apply(gen)
			var tag: String = "(%d lanes, %d a level%s, first dog at %.0f m)" % [lanes, int(case[0]),
				", introduced" if bool(case[1]) else "", float(case[2])]
			var baits: Array = gen.show_window_result.get("baits", [])
			var chases: Array = gen.show_window_result.get("chases", [])
			var own: PackedStringArray = []
			for b: Variant in baits:
				own.append(String((b as Dictionary)["window"]))
			check(Rules.problems(gen).is_empty(), "its placement rules hold %s: %s" % [tag, "; ".join(Rules.problems(gen))])
			check(baits.size() == 2 and chases.size() == int(case[4]), "%s: %d trucks for the 2 baits (%d, %d)" % [tag,
				int(case[4]), chases.size(), baits.size()])
			if baits.size() != 2 or chases.size() != int(case[4]):
				continue
			var first_room: bool = String(baits[0]["window"]) == "before"
			check(first_room == (float(case[2]) > 300.0) and String(baits[1]["window"]) == "before",
				"%s: the first bait's chase has room before it only when it comes later; the second's has (%s)" % [tag, own])
			var want: int = int(case[3])
			for c: Variant in chases:
				var cd: Dictionary = c
				var w: Dictionary = cd["window"]
				var on: int = 0 if absf(float(cd["bait"]) - float(baits[0]["at"])) < 0.01 else 1
				if want >= 0:
					check(on == want and not w.is_empty() and not bool(w.get("after_bait", false)),
						"%s: its truck takes bait %d, its window before it (bait %d, %s)" % [tag, want, on, w])
				elif on == 1:
					check(not w.is_empty() and not bool(w.get("after_bait", false)),
						"%s: the second truck's window comes before its bait" % tag)
	t.per_level_max = keep_max
	_campaign_chases_with_room()


## A plain track of `lanes` lanes, 3 km long, at quick play's speed, with Octodogs standing at `dogs` (their rules plan
## their charges), in a level listing the truck (`intro`: from 3% of the level, so the level introduces it there).
func _dogs_gen(lanes: int, dogs: Array[float], intro: bool) -> LevelGenerator:
	var layout := RunSim.layout(lanes, 3000.0)
	for at: float in dogs:
		layout.enemies.append({"type": "octodog", "at": at, "lane": 0, "side": 0, "seed": int(at), "params": {}})
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.features = PackedStringArray(["octodog", "enforcer_truck"])
	if intro:
		config.feature_starts = {"enforcer_truck": 0.03}
	var gen := LevelGenerator.for_layout(config, tuning, layout)
	OctodogRules.apply(gen)
	return gen


func _campaign_chases_with_room() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var lines: PackedStringArray = []
	for id: String in LEVELS:
		var counts := {"chases": 0, "before": 0, "after": 0, "none": 0, "earlier": 0, "skipped": 0}
		for lanes: int in [3, 5, 6]:
			for k: int in 3:
				var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
				if k > 0:
					config.level_seed = 9100 + k
				var m: MovementTuning = config.movement_for(tuning)
				var gen: LevelGenerator = LayoutCache.generator(config, m, LevelGenerator.load_for(config))
				var tag: String = "(%s, %d lanes, seed %d)" % [id, lanes, config.level_seed]
				var trucks: Array[Dictionary] = Rules.trucks_in(gen.layout)
				var chases: Array = gen.show_window_result.get("chases", [])
				var baits: Array = gen.show_window_result.get("baits", [])
				check(Rules.problems(gen).is_empty() and chases.size() == trucks.size(),
					"every truck keeps its placement rules, moved or arriving earlier %s: %s" % [tag, "; ".join(Rules.problems(gen))])
				if id == "corporate/2":
					check(not trucks.is_empty(), "Corporate 2 keeps its introduction (and its hint) %s" % tag)
				var room: float = t.spacing_seconds * gen.speed
				var spans: Array[Vector2] = []
				for c: Variant in chases:
					spans.append(Rules.chase_span(gen, t, float((c as Dictionary)["at"])))
				var faults: PackedStringArray = []
				for i: int in chases.size():
					var c: Dictionary = chases[i]
					var w: Dictionary = c["window"]
					var before: bool = not w.is_empty() and not bool(w.get("after_bait", false))
					counts["chases"] = int(counts["chases"]) + 1
					var kind: String = "before" if before else ("after" if not w.is_empty() else "none")
					counts[kind] = int(counts[kind]) + 1
					if float(c["at"]) < float(c["preferred"]) - 0.01:
						counts["earlier"] = int(counts["earlier"]) + 1
					for b: Variant in baits:
						var bd: Dictionary = b
						if not bool(bd["chosen"]) and float(bd["chase"]) < INF and float(bd["at"]) < float(c["bait"]) - 0.01 \
								and _fits_beside(bd["span"], spans, i, room):
							counts["skipped"] = int(counts["skipped"]) + 1
							break
					if before:
						continue
					# A truck without a window before its bait: no free bait whose own chase has one fits beside the others.
					for b: Variant in baits:
						var bd: Dictionary = b
						if not bool(bd["chosen"]) and String(bd["window"]) == "before" \
								and _fits_beside(bd["span"], spans, i, room):
							faults.append("the truck at %.0f m has none, and the bait at %.0f m has room" % [float(c["at"]),
								float(bd["at"])])
				if trucks.size() < t.per_level_max:
					for b: Variant in baits:
						var bd: Dictionary = b
						if not bool(bd["chosen"]) and String(bd["window"]) == "before" \
								and _fits_beside(bd["span"], spans, -1, room):
							faults.append("a free bait at %.0f m has room beside its %d trucks" % [float(bd["at"]), trucks.size()])
				check(faults.is_empty(), "%s every truck's chase has a window before its bait wherever a free bait has room (%s)"
					% [tag, "; ".join(faults)])
		lines.append(("%s: %d chases, %d with a window before the bait, %d after it, %d none; %d arriving earlier than"
			+ " preferred, %d past an earlier free bait") % [id, counts["chases"], counts["before"], counts["after"],
			counts["none"], counts["earlier"], counts["skipped"]])
	print("  chases with room (own seed and 2 others, 3, 5 and 6 lanes):\n    " + "\n    ".join(lines))


## True if a chase over `span` keeps spacing `room` from every one of `spans` but the one at `skip` (-1: none).
static func _fits_beside(span: Vector2, spans: Array[Vector2], skip: int, room: float) -> bool:
	for j: int in spans.size():
		if j != skip and span.x < spans[j].y + room and span.y + room > spans[j].x:
			return false
	return true


## Its rules only add its trucks: with danger density off (whose enemy count counts them), the wider gaps off (task
## G7: they go in a truck's chase first) and its showing windows not planned (task C6c: a window moves a truck's
## arrival, takes out what's in its way and keeps the later passes off it, _test_show_windows), Corporate 2 and Golden
## 2 are the same level with or without the feature but for the trucks.
func _test_only_its_trucks() -> void:
	t.show_window_planned = false
	_only_its_trucks()
	t.show_window_planned = true


func _only_its_trucks() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	for id: String in ["corporate/2", "golden/2"]:
		var config: LevelConfig = campaign.configure(campaign.step(id), 5)
		config.danger_density_increase = 0.0
		config.wide_gaps = 0
		var m: MovementTuning = config.movement_for(tuning)
		var patterns: Array = LevelGenerator.load_for(config)
		var with_it: LevelLayout = LevelGenerator.new().generate(config, m, patterns)
		var without: LevelConfig = config.duplicate() as LevelConfig
		var features: PackedStringArray = config.features.duplicate()
		features.remove_at(features.find("enforcer_truck"))
		without.features = features
		var plain: LevelLayout = LevelGenerator.new().generate(without, m, patterns)
		var stripped: LevelLayout = with_it.copy()
		var kept: Array[Dictionary] = []
		for e: Dictionary in stripped.enemies:
			if String(e["type"]) != "enforcer_truck":
				kept.append(e)
		stripped.enemies = kept
		check(not Rules.trucks_in(with_it).is_empty() and JSON.stringify(stripped.to_dict()) == JSON.stringify(plain.to_dict()),
			"%s (no danger density, no wider gaps): the same level but for its trucks" % id)


## Quick play: no bait, no truck (GDD §9.13: only where an Octodog or a Buzz Overdrive charges); with
## Octodogs, around their charges.
func _test_quick_play() -> void:
	var base := load("res://data/levels/prototype_level.tres") as LevelConfig
	for features: PackedStringArray in [PackedStringArray(["cyborg", "enforcer_truck"]),
			PackedStringArray(["cyborg", "octodog", "enforcer_truck"])]:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			config.features = features
			config.duration_seconds = 120.0
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
			var trucks: Array[Dictionary] = Rules.trucks_in(layout)
			var baits: bool = features.has("octodog") and not Rules.bait_points(gen).is_empty()
			check(Rules.problems(gen).is_empty(), "quick play %s at %d lanes keeps its rules (%s)" % [features, lanes,
				"; ".join(Rules.problems(gen))])
			if not features.has("octodog"):
				check(trucks.is_empty(), "quick play without a bait at %d lanes has no truck" % lanes)
			elif baits:
				check(not trucks.is_empty(), "quick play with Octodogs at %d lanes has trucks around their charges" % lanes)


# --- Marker, lights -------------------------------------------------------------------------------

func _test_marker_and_lights() -> void:
	var w: RunWorld = await _chasing(5)
	var truck: EnforcerTruck = _truck(w)
	if truck == null:
		check(false, "a truck for its marker")
		await sim.free_world(w)
		return
	var marker: EnforcerTruckMarker = truck.marker
	check(marker.is_inside_tree() and (marker.get_parent() as CanvasLayer).visible and marker.shown > 0.99,
		"its marker shows while it chases")
	check(is_equal_approx(marker.lane_x, truck.global_position.x), "its marker stands under the truck's lane")
	var p: Vector2 = marker.place()
	check(p.y > marker.get_viewport_rect().size.y * 0.8, "its marker sits at the screen's bottom edge (y %.0f)" % p.y)
	# The light bar takes turns; with Reduced flashing both halves stay lit, steady.
	var phases: Dictionary = {}
	for i: int in 40:
		await tree.physics_frame
		phases[truck.model.flash_phase] = true
	check(phases.has(0) and phases.has(1), "its light bar's red and blue take turns (%s)" % [phases.keys()])
	Settings.flashing_reduced = true
	var steady: bool = true
	for i: int in 40:
		await tree.physics_frame
		steady = steady and truck.model.flash_phase == -1 and marker.phase == -1 \
			and (truck.get(&"_wash_red") as MeshInstance3D).material_override == EnforcerTruckModel.floor_material(&"dim") \
			and (truck.get(&"_wash_blue") as MeshInstance3D).material_override == EnforcerTruckModel.floor_material(&"dim")
	Settings.flashing_reduced = false
	check(steady, "with Reduced flashing its light bar, its washes and its marker stay lit, steady")
	await sim.free_world(w)


func _test_warm_up() -> void:
	var w: RunWorld = _world(3)
	var look: Node = EnforcerTruck.warm_up(w, {"type": "enforcer_truck", "at": 1.0, "lane": 1, "seed": 1, "params": {}})
	var geometry: int = 0
	var physics: int = 0
	var stack: Array[Node] = [look]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			geometry += 1
		if n is CollisionObject3D:
			physics += 1
		stack.append_array(n.get_children())
	check(not look.is_inside_tree() and geometry >= 15 and physics == 0,
		"its warm-up look has every part (%d to draw), outside the tree, and no physics object" % geometry)
	# Its blast (the owner, October 8, 2026): every material it shows drawn while the level loads, so it never
	# builds a shader mid-run.
	var blast: Node = look.find_child("BlastWarmUp", false, false)
	var kinds: Array[StringName] = []
	if blast != null:
		for c: Node in blast.get_children():
			var mi := c as MeshInstance3D
			for kind: StringName in [&"core", &"fire", &"ember", &"smoke", &"glow"]:
				if mi != null and mi.material_override == EnforcerTruckBlast.material(kind):
					kinds.append(kind)
	check(kinds.size() == 5, "its warm-up look shows its blast's every material (%s)" % [kinds])
	look.free()
	check(w.director.warm_entries().any(func(e: Dictionary) -> bool: return String(e["type"]) == "enforcer_truck"),
		"the director readies it with the level")
	await sim.free_world(w)


# --- Data -----------------------------------------------------------------------------------------

func _test_data() -> void:
	check(not LevelConfig.PLANNED_FEATURES.has("enforcer_truck") and LayoutChecks.known_feature("enforcer_truck"),
		"it's a built feature, never a planned one")
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var hint: bool = false
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		hint = hint or String(h.get("trigger", "")) == "enemy:enforcer_truck"
	check(hint, "its first encounter has a hint")
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var config: LevelConfig = campaign.configure(campaign.step("corporate/2"), 3)
	check(int(config.feature_ages.get("enforcer_truck", -1)) == 0, "Corporate 2 introduces it (its age there is 0)")
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var missing: PackedStringArray = []
	for sound: StringName in [&"enforcer_siren", &"enforcer_whine", &"enforcer_laser", &"enforcer_pickup", &"enforcer_crash",
			&"truck_explode"]:
		if library.stream(sound) == null or not library.volume_db.has(String(sound)):
			missing.append(String(sound))
	check(missing.is_empty(), "its siren, warning, shots, rider, crash and explosion have sounds (missing %s)" % [missing])
	var whine: AudioStream = library.stream(&"enforcer_whine")
	check(whine != null and absf(whine.get_length() - t.warning_seconds) < 0.05,
		"its whine lasts its warning (%.2f s)" % (whine.get_length() if whine != null else 0.0))
