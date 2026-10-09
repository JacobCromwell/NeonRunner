extends TestSuite
## The Golden Convergence's Missile Barrage (GDD §10; task E5d-b), at 3, 5 and 6 lanes and 18 and 25 m/s, with the
## real player (no god mode):
## - its numbers: the fire burns longer than one layer of protection (the dash's 0.6 s, a blocked hit's second
##   of invulnerability), shorter than two (one armor hit and the dash, 1.6 s) and shorter than a wall run
##   without claws; its flames a metre high (a jump only delays them); its sounds and hint;
## - its warning: the hatches opening, the launch, the dive's whistle, the marks spreading over every lane of its
##   stretch (floor warnings: BossProps.warned) and filling in, the missiles in the air, hanging where the run
##   camera sees them in front of the suit; long enough to reach the wall from the far side (the reaction, every
##   lane switch, the wall entry, a margin) at 3, 5 and 6 lanes;
## - its fire: every lane over the stretch the runner runs while it burns (a dash included) and margins, lit for
##   fire_seconds and no longer, the burning floor over just what burns; a jump only delays it; the missiles and
##   marks never hurt;
## - the wall: its boxes clear of a wall runner's body at every height on either wall, and a runner on the open
##   wall through the whole burn is never touched (getting on as the marks fill in, wall hopping if need be);
## - the layers of protection, the real player standing in it: the free armor alone dies, one armor hit and the
##   dash get through, two armor hits do, the armor and the shield do, no protection dies at once;
## - no wall: the barrage comes anyway and hits; it follows its slams in the beat script;
## - Reduced flashing: the marks steady, no blasts;
## - E5d polish: the marks' fill and the burning floor read red on the court's white marble on both renderers'
##   blending, never toward the fences' pink;
## - E5d polish: F6's ranges never break it: at every end of the warning's steps, the reaction and the margin the
##   warning still leaves time to reach the wall from the far side (the missiles hang longer where needed; played at
##   the worst ends on 6 lanes), and the toppled tower's wall outlasts the warning and the fire at every end.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const SPEEDS: Array[float] = [18.0, 25.0]
const REACTION: float = 0.35
const NEW_SOUNDS: Array[StringName] = [&"gc_hatch", &"gc_launch", &"gc_whistle", &"gc_fire"]
const WARNINGS: Array[StringName] = [&"gc_hatch", &"gc_launch", &"gc_whistle"]

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Golden Convergence's fight is built")
		return
	_test_numbers()
	_test_marks_read_red()
	for lanes: int in LANES:
		for speed: float in SPEEDS:
			await _test_warning_and_fire(lanes, speed)
	await _test_jump_delays()
	for lanes: int in LANES:
		_test_wall_clear(lanes)
		await _test_wall_runner(lanes)
	await _test_stacking()
	await _test_no_wall()
	await _test_reduced_flashing()
	await _test_f6_extremes()


# --- The marks' red ------------------------------------------------------------------------------------------

## The court's white marble as the run camera shows it (sRGB; frames of the barrage on both renderers).
const MARBLE := Color(0.835, 0.83, 0.81)


## E5d polish (the review: a fill of 60 % red over the white marble may read salmon or pink): the marks' fill, its
## ring and the burning floor laid over the marble come out red, their green and blue well under their red, both
## where the renderer blends in linear space (Forward+, Mobile: then shown in sRGB) and where it blends in sRGB
## (Compatibility, which takes the authored colour as it is).
func _test_marks_read_red() -> void:
	var code: String = (load("res://scripts/bosses/golden_convergence/golden_convergence_floor.gdshader") as Shader).code
	var mark: PackedFloat64Array = _uniform(code, "mark_color")
	var energy: float = _uniform(code, "energy")[0]
	var faults: PackedStringArray = []
	check(mark.size() == 3, "the marks' colour is the floor shader's mark_color (%s)" % [mark])
	if mark.size() != 3:
		return
	for part: String in ["fill_alpha", "ring_alpha"]:
		var a: float = _uniform(code, part)[0]
		var src := Color(mark[0], mark[1], mark[2])
		for linear: bool in [true, false]:
			var out: Color = _blend(src, energy, a, linear)
			if out.g > 0.32 * out.r or out.b > 0.32 * out.r:
				faults.append("%s %.2f %s: %s" % [part, a, "linear" if linear else "sRGB", out])
	check(faults.is_empty(), "the target marks read red on the white marble on every renderer, never salmon or pink (%s)" % [
		", ".join(faults)])


## The numbers a shader's uniform `uniform_name` defaults to in its `code` (headless runs compile no shader).
static func _uniform(code: String, uniform_name: String) -> PackedFloat64Array:
	var re := RegEx.new()
	re.compile("uniform\\s+\\w+\\s+" + uniform_name + "\\s*=\\s*(?:vec3\\()?([-0-9., ]+)\\)?;")
	var m: RegExMatch = re.search(code)
	var out := PackedFloat64Array()
	if m != null:
		for v: String in m.get_string(1).split(",", false):
			out.append(float(v.strip_edges()))
	if out.is_empty():
		out.append(NAN)
	return out


## The colour shown where `src` (sRGB, times `energy`) is laid at `alpha` over MARBLE, blending in linear space (then
## clipped and shown in sRGB) or straight in sRGB.
static func _blend(src: Color, energy: float, alpha: float, linear: bool) -> Color:
	if linear:
		var s: Color = src.srgb_to_linear() * energy
		var d: Color = MARBLE.srgb_to_linear()
		var o := Color(s.r * alpha + d.r * (1.0 - alpha), s.g * alpha + d.g * (1.0 - alpha), s.b * alpha + d.b * (1.0 - alpha))
		return Color(minf(o.r, 1.0), minf(o.g, 1.0), minf(o.b, 1.0)).linear_to_srgb()
	var c: Color = src * energy
	var out := Color(c.r * alpha + MARBLE.r * (1.0 - alpha), c.g * alpha + MARBLE.g * (1.0 - alpha), c.b * alpha + MARBLE.b * (1.0 - alpha))
	return Color(minf(out.r, 1.0), minf(out.g, 1.0), minf(out.b, 1.0))


# --- F6's ranges -----------------------------------------------------------------------------------------------

## The warning's steps, the reaction and the margin (each at either end of its F6 range), the fire and the tower's
## wall: the tunables a runner's way onto the wall and along it depend on.
const WARNING_KNOBS: Array[StringName] = [&"barrage_hatch_seconds", &"barrage_climb_seconds", &"barrage_hang_seconds",
	&"barrage_dive_seconds", &"barrage_reaction", &"barrage_margin"]


## E5d polish (F6's shortest steps, or its longest reaction and margin, left a warning shorter than the way onto the
## wall from the far side; its longest steps and fire outlasted the toppled tower's shortest wall): at every end of
## every range the warning (GoldenConvergenceBarrage.warning_for: the missiles hang longer where needed) leaves time
## to reach the wall on 3, 5 and 6 lanes, and the tower's wall (GoldenConvergenceTower.wall_seconds) outlasts the
## warning, the fire and its spare; then a barrage at the worst ends, played on 6 lanes at 25 m/s, warns that long.
func _test_f6_extremes() -> void:
	var t0: GoldenConvergenceTuning = def.tuning as GoldenConvergenceTuning
	var faults: PackedStringArray = []
	var corners: int = 0
	var lengthened: int = 0
	for corner: int in 1 << WARNING_KNOBS.size():
		var t := t0.duplicate() as GoldenConvergenceTuning
		for k: int in WARNING_KNOBS.size():
			t.set(WARNING_KNOBS[k], _range_end(t0, WARNING_KNOBS[k], (corner & (1 << k)) != 0))
		var raw: float = t.barrage_hatch_seconds + t.barrage_climb_seconds + t.barrage_hang_seconds + t.barrage_dive_seconds
		var warning: float = GoldenConvergenceBarrage.warning_for(t, tuning)
		for lanes: int in LANES:
			corners += 1
			var need: float = GoldenConvergenceBarrage.wall_reach_seconds(t, tuning, lanes)
			if raw < need - 0.001:
				lengthened += 1
			if warning < need - 0.001 or warning < raw - 0.001:
				faults.append("warning %.2f s < %.2f s (%d lanes, corner %d)" % [warning, need, lanes, corner])
		for fire_high: bool in [false, true]:
			for wall_high: bool in [false, true]:
				t.fire_seconds = _range_end(t0, &"fire_seconds", fire_high)
				t.tower_wall_seconds = _range_end(t0, &"tower_wall_seconds", wall_high)
				var wall: float = GoldenConvergenceTower.wall_seconds(t, tuning)
				if wall < warning + t.fire_seconds + GoldenConvergenceTower.WALL_SPARE - 0.001 or wall < t.tower_wall_seconds:
					faults.append("the tower's wall %.1f s < the warning %.1f s and the fire %.1f s (corner %d)" % [
						wall, warning, t.fire_seconds, corner])
	check(faults.is_empty() and lengthened > 0,
		"at every end of F6's ranges the warning leaves time to reach the wall (%d of %d cases hang longer for it) and the toppled tower's wall outlasts the barrage (%s)" % [
			lengthened, corners, ", ".join(faults.slice(0, 4))])
	# Played at the worst ends: the shortest steps, the longest reaction and margin.
	var pair: Array = _fight(6, 25.0, null, "barrage", func(t: GoldenConvergenceTuning) -> void:
		for k: int in WARNING_KNOBS.size():
			t.set(WARNING_KNOBS[k], _range_end(t0, WARNING_KNOBS[k], k >= 4)))
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	await _run(world, null, 20.0, func() -> bool: return not _events(boss, &"barrage_fire").is_empty())
	var warned: Array[Dictionary] = _events(boss, &"barrage_warned")
	var fire: Array[Dictionary] = _events(boss, &"barrage_fire")
	var need6: float = GoldenConvergenceBarrage.wall_reach_seconds(boss.tuning, tuning, 6)
	var lead: float = float(fire[0]["t"]) - float(warned[0]["t"]) if not fire.is_empty() and not warned.is_empty() else -1.0
	check(lead >= need6 - 2.0 / Engine.physics_ticks_per_second,
		"a barrage at the worst ends warns %.2f s ahead of its fire: time to reach the wall from the far side on 6 lanes (%.2f s)" % [
			lead, need6])
	await sim.free_world(world)


## The low (or the high) end of `prop`'s F6 range on `res` (its @export_range), or its value without one.
static func _range_end(res: Resource, prop: StringName, high: bool) -> float:
	for info: Dictionary in res.get_property_list():
		if StringName(info["name"]) == prop and int(info["hint"]) == PROPERTY_HINT_RANGE:
			var parts: PackedStringArray = String(info["hint_string"]).split(",")
			return float(parts[1] if high else parts[0])
	return float(res.get(prop))


# --- Helpers ------------------------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s, past the entrance, every phase's beat script `beats`, its tuning's copy
## changed by `mutate` if given: [world, boss].
func _fight(lanes: int, speed: float, loadout: Loadout = null, beats: String = "barrage", mutate: Callable = Callable()) -> Array:
	var d: BossDef = def.duplicate() as BossDef
	var t := (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
	var list := PackedStringArray()
	for i: int in t.phase_beats.size():
		list.append(beats)
	t.phase_beats = list
	if mutate.is_valid():
		mutate.call(t)
	d.tuning = t
	var boss := BossEncounter.create(d) as GoldenConvergence
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = d
	ctx.config = BossArena.base_config(d)
	ctx.config.lane_count = lanes
	ctx.config.run_speed = speed
	ctx.tuning = tuning
	ctx.boss_resume = {"phase": 0, "time": 0.0}
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


func _bot(boss: GoldenConvergence) -> GoldenConvergenceBot:
	var bot := GoldenConvergenceBot.new(boss)
	bot.reaction = REACTION
	return bot


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(boss: BossEncounter, sound_name: StringName) -> int:
	return boss.events.filter(func(e: Dictionary) -> bool: return e["event"] == &"sound" and e["name"] == sound_name).size()


func _run(world: RunWorld, bot: GoldenConvergenceBot, seconds: float, done: Callable = Callable(),
		each: Callable = Callable()) -> void:
	if not world.player.running:
		await tree.physics_frame
		world.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if bot != null:
			bot.step()
		if each.is_valid():
			each.call()
		if (done.is_valid() and done.call()) or not world.player.alive:
			return
		await tree.physics_frame


func _death(world: RunWorld) -> Array[String]:
	var cause: Array[String] = [""]
	world.player.died.connect(func(c: String) -> void: cause[0] = c)
	return cause


## A wall runner's hurtbox on the wall on `side` at height `h` (Player.hurtbox_aabb's, on a wall).
func _wall_body(geo: TrackGeometry, side: int, h: float) -> AABB:
	var height: float = tuning.hurtbox_size.y
	var hx: float = tuning.hurtbox_size.x * 0.5
	var x: float = side * geo.wall_x()
	var x0: float = x - height if side > 0 else x
	return AABB(Vector3(x0, h - hx, -1.0), Vector3(height, hx * 2.0, 2.0))


# --- Its numbers ----------------------------------------------------------------------------------------------

func _test_numbers() -> void:
	var t: GoldenConvergenceTuning = def.tuning as GoldenConvergenceTuning
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var wall_run: float = tuning.wall_entry_time + tuning.wall_slide_time
	check(t.fire_seconds > pt.dash_duration and t.fire_seconds > rules.hit_invulnerability,
		"the fire burns longer than one layer of protection alone (%.1f s vs the dash's %.1f s, a blocked hit's %.1f s)" % [
			t.fire_seconds, pt.dash_duration, rules.hit_invulnerability])
	check(t.fire_seconds < rules.hit_invulnerability + pt.dash_duration,
		"long enough that two layers carry the runner through (an armor hit and the dash, %.1f s)" % (rules.hit_invulnerability + pt.dash_duration))
	check(t.fire_seconds < wall_run, "and shorter than one wall run without claws (%.2f s): the runner drops onto floor no longer burning" % wall_run)
	check(absf(t.fire_seconds - 1.5) < 0.01, "about 1.5 s (GDD §10, proposed: %.2f s)" % t.fire_seconds)
	check(t.fire_height >= 0.8 and t.fire_height <= 1.2 and t.fire_height < tuning.jump_height,
		"its flames about a metre high (%.1f m): a jump clears them for a moment, no more" % t.fire_height)
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var missing: PackedStringArray = []
	for sound: StringName in NEW_SOUNDS:
		if not sfx.volume_db.has(String(sound)) or sfx.stream(sound) == null or sfx.stream(sound).get_length() >= 2.5:
			missing.append(String(sound))
	check(missing.is_empty(), "its sounds are in the library, each under 2.5 s (%s)" % ", ".join(missing))
	var varied: PackedStringArray = []
	for sound: StringName in WARNINGS:
		if float(sfx.pitch_variation.get(String(sound), 0.0)) != 0.0:
			varied.append(String(sound))
	check(varied.is_empty(), "its warnings sound the same every time (%s)" % ", ".join(varied))
	var whistle: AudioStream = sfx.stream(&"gc_whistle")
	check(whistle != null and absf(whistle.get_length() - t.barrage_dive_seconds) < 0.05, "the dive's whistle lasts the dive")
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: Array[String] = []
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		triggers.append(String(h.get("trigger", "")))
	check(triggers.has("boss:golden_boss/barrage"), "the barrage (and its wall) has a hint")
	for lanes: int in LANES:
		var need: float = GoldenConvergenceBarrage.wall_reach_seconds(t, tuning, lanes)
		var warning: float = t.barrage_hatch_seconds + t.barrage_climb_seconds + t.barrage_hang_seconds + t.barrage_dive_seconds
		check(warning >= need, "its warning (%.2f s) leaves time to reach the wall from the far side at %d lanes (%.2f s: the reaction, %d lane switches, the wall entry, a margin)" % [
			warning, lanes, need, lanes - 1])


# --- Its warning and its fire ------------------------------------------------------------------------------------

func _test_warning_and_fire(lanes: int, speed: float) -> void:
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var loadout := Loadout.new()
	loadout.tiers[&"dash"] = 1
	var pair: Array = _fight(lanes, speed, loadout)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	var br: GoldenConvergenceBarrage = boss.barrage
	var seen := {"hatch": 0.0, "marks": 0, "missiles": 0, "warned_lanes": true, "fill": 0.0, "early": [], "live_frames": 0,
		"outran": 0.0, "dashed": false, "covered": true, "hang_frames": 0, "hang_over_top": -INF, "hang_before_suit": INF,
		"floor_fits": true}
	# The run camera's top edge, above level (RunCamera: camera_distance behind the runner, camera_height up,
	# looking at a metre up camera_look_ahead ahead).
	var pitch: float = atan2(tuning.camera_height - 1.0, tuning.camera_distance + tuning.camera_look_ahead)
	var top: float = deg_to_rad(tuning.camera_fov * 0.5) - pitch
	var hints: Array[String] = []
	boss.hint_due.connect(func(key: String) -> void: hints.append(key))
	await _run(world, null, 30.0, func() -> bool: return not _events(boss, &"barrage_out").is_empty(), func() -> void:
		var live: bool = br.missiles.live()
		if br.stage in [GoldenConvergenceBarrage.Stage.HATCH, GoldenConvergenceBarrage.Stage.CLIMB, GoldenConvergenceBarrage.Stage.HANG,
				GoldenConvergenceBarrage.Stage.DIVE]:
			seen["hatch"] = maxf(float(seen["hatch"]), boss.suit.pipes_open[0])
			seen["marks"] = maxi(int(seen["marks"]), br.missiles.marks_shown())
			seen["missiles"] = maxi(int(seen["missiles"]), br.missiles._missiles.multimesh.visible_instance_count)
			if live:
				(seen["early"] as Array).append(boss.fight_time())
			seen["fill"] = maxf(float(seen["fill"]), br.missiles.mark_ring(0).y)
			if br.stage == GoldenConvergenceBarrage.Stage.HANG:
				# Hanging where the runner sees them: under the view's top edge, in front of the suit.
				seen["hang_frames"] = int(seen["hang_frames"]) + 1
				for m: Dictionary in br.plan["marks"]:
					var hang: Vector3 = m["hang"]
					var ahead: float = hang.z
					var up: float = atan2(hang.y - tuning.camera_height, ahead + tuning.camera_distance)
					seen["hang_over_top"] = maxf(float(seen["hang_over_top"]), up - top)
					seen["hang_before_suit"] = minf(float(seen["hang_before_suit"]), boss.tuning.suit_ahead - ahead)
			var from: float = float(br.plan["from"])
			var to: float = float(br.plan["to"])
			for lane: int in lanes:
				seen["warned_lanes"] = bool(seen["warned_lanes"]) and boss.props.warned(lane, from, to)
		if br.stage == GoldenConvergenceBarrage.Stage.FIRE:
			seen["live_frames"] = int(seen["live_frames"]) + (1 if live else 0)
			# The runner dashes as it lands and never gets past its far end, nor out of any lane's fire.
			if not bool(seen["dashed"]):
				seen["dashed"] = (world.powerups as PowerupController).dash.trigger()
			var d: float = world.player.distance
			seen["outran"] = maxf(float(seen["outran"]), d + tuning.hurtbox_size.z * 0.5 - float(br.plan["to"]))
			if live:
				for rig: Dictionary in br.missiles.lanes:
					if int(rig["lane"]) >= lanes:
						continue
					var x: float = world.geo.lane_x(int(rig["lane"]))
					seen["covered"] = bool(seen["covered"]) and float(rig["x0"]) <= x - tuning.hurtbox_size.x * 0.5 \
						and float(rig["x1"]) >= x + tuning.hurtbox_size.x * 0.5 and float(rig["from"]) <= d - 1.0 and float(rig["to"]) >= d + 1.0
					# The burning floor lies over just what burns (no unburnt strip between two lanes).
					var glow: Node3D = rig["floor"]
					var span: Vector3 = glow.global_transform.basis.get_scale()
					var at: Vector3 = glow.global_position
					seen["floor_fits"] = bool(seen["floor_fits"]) and glow.visible \
						and absf(at.x - span.x * 0.5 - float(rig["x0"])) < 0.01 and absf(at.x + span.x * 0.5 - float(rig["x1"])) < 0.01 \
						and absf(span.z - (float(rig["to"]) - float(rig["from"]))) < 0.01)
	var warned: Array[Dictionary] = _events(boss, &"barrage_warned")
	var fire: Array[Dictionary] = _events(boss, &"barrage_fire")
	var out: Array[Dictionary] = _events(boss, &"barrage_out")
	check(warned.size() == 1 and fire.size() == 1 and out.size() == 1, "a barrage warns, lands and goes out %s" % tag)
	if fire.is_empty() or warned.is_empty() or out.is_empty():
		await sim.free_world(world)
		return
	var t: GoldenConvergenceTuning = boss.tuning
	var lead: float = float(fire[0]["t"]) - float(warned[0]["t"])
	var need: float = GoldenConvergenceBarrage.wall_reach_seconds(t, tuning, lanes)
	check(lead >= need and absf(lead - br.warning_seconds()) < 0.05,
		"its warning leads the fire by %.2f s: time to reach the wall from the far side (%.2f s) %s" % [lead, need, tag])
	check(float(seen["hatch"]) > 0.99 and int(seen["marks"]) == lanes * t.marks_per_lane and int(seen["missiles"]) == lanes * t.marks_per_lane,
		"the hatches open, the missiles fly and the marks spread over the floor (%d marks, %d missiles) %s" % [seen["marks"], seen["missiles"], tag])
	check(bool(seen["warned_lanes"]), "its marks are floor warnings over every lane of its stretch (pickups keep off) %s" % tag)
	check(float(seen["fill"]) > 0.9, "the marks fill in as the missiles dive (%.2f) %s" % [seen["fill"], tag])
	check(int(seen["hang_frames"]) > 0 and float(seen["hang_over_top"]) < 0.0 and float(seen["hang_before_suit"]) > 2.0,
		"the missiles hang in the run camera's view (%.1f deg under its top edge at the least), in front of the suit (%.1f m) %s" % [
			-rad_to_deg(float(seen["hang_over_top"])), seen["hang_before_suit"], tag])
	check(bool(seen["floor_fits"]), "the burning floor lies over just what burns, lane to lane %s" % tag)
	check((seen["early"] as Array).is_empty(), "nothing burns before the marks are full %s" % tag)
	var burnt: float = float(out[0]["t"]) - float(fire[0]["t"])
	check(absf(burnt - t.fire_seconds) < 0.03 and absf(float(seen["live_frames"]) / Engine.physics_ticks_per_second - t.fire_seconds) < 0.05,
		"it burns %.1f s, no longer (%.2f s) %s" % [t.fire_seconds, burnt, tag])
	check(bool(seen["covered"]) and float(seen["outran"]) <= 0.0 and bool(seen["dashed"]),
		"it covers every lane over the stretch the runner runs while it burns, a dash included (%.1f m short of its end) %s" % [-float(seen["outran"]), tag])
	var land: float = float(fire[0]["runner"])
	check(float(br.plan["from"]) <= land - t.fire_behind + 0.01 and float(br.plan["to"]) >= land + speed * t.fire_seconds + 4.8 + t.fire_ahead - 0.5,
		"from %.0f m behind the runner as it lands to past where a dash could carry them %s" % [t.fire_behind, tag])
	check(_sounds(boss, &"gc_hatch") == 1 and _sounds(boss, &"gc_launch") == 1 and _sounds(boss, &"gc_whistle") == 1 and _sounds(boss, &"gc_fire") == 1,
		"the hatches' clank, the launch's roar, the dive's whistle and the fire are heard %s" % tag)
	check(hints.count("golden_boss/barrage") == 1, "its hint comes with the first barrage %s" % tag)
	var hazards: Array = br.missiles.find_children("*", "Hazard", true, false)
	check(hazards.size() == br.missiles.hazards().size(), "only its fire hurts: the missiles and the marks have no hitbox %s" % tag)
	await sim.free_world(world)


## Its flames a metre high: a jump only delays them (a runner who jumps as it lands is hit coming down).
func _test_jump_delays() -> void:
	var pair: Array = _fight(5, 18.0)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var cause: Array[String] = _death(world)
	var jumped := {"done": false}
	await _run(world, null, 20.0, Callable(), func() -> void:
		var br: GoldenConvergenceBarrage = boss.barrage
		# Above the flames as they land (a jump's apex 0.36 s after it starts).
		if not bool(jumped["done"]) and br.stage == GoldenConvergenceBarrage.Stage.DIVE and br.land_eta() <= 0.3:
			world.player.press(&"jump")
			jumped["done"] = true)
	var fire: Array[Dictionary] = _events(boss, &"barrage_fire")
	var hits: Array[Dictionary] = boss.barrage.missiles.hits
	check(not world.player.alive and cause[0] == "the missiles' fire" and not fire.is_empty() and hits.size() == 1
		and float(hits[0]["t"]) > float(fire[0]["t"]) + 0.15, "a jump only delays the fire: the runner is hit coming down (%s)" % [hits])
	await sim.free_world(world)


# --- The wall ------------------------------------------------------------------------------------------------------

## Its boxes keep clear of a wall runner's body at every height a wall run reaches, on either wall.
func _test_wall_clear(lanes: int) -> void:
	var geo := TrackGeometry.new(lanes, tuning)
	var n: int = lanes
	var faults: PackedStringArray = []
	var reach: float = tuning.hurtbox_size.y + GoldenConvergenceMissiles.WALL_CLEAR
	for k: int in [0, n - 1]:
		var x0: float = geo.lane_x(k) - geo.lane_width * 0.5
		var x1: float = geo.lane_x(k) + geo.lane_width * 0.5
		if k == 0:
			x0 = -geo.wall_x() + reach
		if k == n - 1:
			x1 = geo.wall_x() - reach
		var box := AABB(Vector3(x0, 0.0, -1.0), Vector3(x1 - x0, (def.tuning as GoldenConvergenceTuning).fire_height, 2.0))
		for side: int in [-1, 1]:
			var h: float = 0.0
			while h <= tuning.wall_max_height + 0.01:
				if box.intersects(_wall_body(geo, side, h)):
					faults.append("lane %d, the %s wall at %.1f m" % [k, "left" if side < 0 else "right", h])
				h += 0.1
		# A runner in the outer lane on the floor (its middle, or bumped toward the balustrade) is still in it.
		var mid: float = geo.lane_x(k)
		var bumped: float = mid + (-1.0 if k == 0 else 1.0) * tuning.wall_bump_distance
		for x: float in [mid, bumped]:
			var body := AABB(Vector3(x - tuning.hurtbox_size.x * 0.5, 0.0, -0.2), Vector3(tuning.hurtbox_size.x, 1.0, 0.4))
			if not box.intersects(body):
				faults.append("lane %d's floor runner at x %.2f not covered" % [k, x])
	check(faults.is_empty(), "its fire stays inside the lanes, clear of a wall runner at every height on either wall, and covers the outer lanes' floor (%d lanes): %s" % [
		lanes, ", ".join(faults.slice(0, 4))])


## A runner on the open wall through the whole burn is never touched: getting on as the marks fill in.
func _test_wall_runner(lanes: int) -> void:
	for side: int in [-1, 1]:
		var tag: String = "(%d lanes, the %s wall)" % [lanes, "left" if side < 0 else "right"]
		var pair: Array = _fight(lanes, 25.0)
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		var cause: Array[String] = _death(world)
		var opened := {"done": false}
		var on_wall := {"frames": 0, "burn_frames": 0}
		await _run(world, bot, 25.0, func() -> bool: return not _events(boss, &"barrage_out").is_empty(), func() -> void:
			var br: GoldenConvergenceBarrage = boss.barrage
			if not bool(opened["done"]) and br.stage != GoldenConvergenceBarrage.Stage.IDLE:
				opened["done"] = true
				boss.court.open_wall(side, world.player.distance + 5.0, float(br.plan["to"]) + 60.0)
			if br.stage == GoldenConvergenceBarrage.Stage.FIRE:
				on_wall["burn_frames"] = int(on_wall["burn_frames"]) + 1
				if world.player.surface == Player.Surface.WALL:
					on_wall["frames"] = int(on_wall["frames"]) + 1)
		check(world.player.alive and boss.barrage.missiles.hits.is_empty() and int(on_wall["frames"]) == int(on_wall["burn_frames"])
			and int(on_wall["burn_frames"]) > 0, "a runner on the open wall through the whole burn is never touched (%s, %d of %d frames on the wall) %s" % [
				cause[0], on_wall["frames"], on_wall["burn_frames"], tag])
		await sim.free_world(world)


# --- Layers of protection -------------------------------------------------------------------------------------------

## The real player standing in the fire (no wall): the free armor alone dies; one armor hit and the dash, two
## armor hits, the armor and the shield get through; no protection dies at once.
func _test_stacking() -> void:
	for setup: String in ["none", "armor", "armor+dash", "armor x2", "armor+shield"]:
		var loadout := Loadout.new()
		match setup:
			"armor":
				loadout.armor = true
			"armor+dash":
				loadout.armor = true
				loadout.tiers[&"dash"] = 1
			"armor x2":
				loadout.armor = true
				loadout.tiers[&"armor"] = 1
			"armor+shield":
				loadout.armor = true
				loadout.charges[&"shield"] = 1
		var pair: Array = _fight(5, 18.0, loadout)
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		bot.home_lane = 2
		var cause: Array[String] = _death(world)
		await _run(world, bot, 25.0, func() -> bool: return not _events(boss, &"barrage_out").is_empty())
		var hits: Array[Dictionary] = boss.barrage.missiles.hits
		var outcomes: String = ""
		for h: Dictionary in hits:
			outcomes += "%d" % int(h["outcome"])
		var block: String = "%d" % DamageRules.Outcome.BLOCKED_ARMOR
		var kill: String = "%d" % DamageRules.Outcome.KILL
		match setup:
			"none":
				check(not world.player.alive and outcomes == kill, "no protection: the fire kills at once (%s)" % outcomes)
			"armor":
				check(not world.player.alive and outcomes == block + kill and float(hits[1]["t"]) - float(hits[0]["t"]) >= 0.95,
					"the free armor alone (1 hit) isn't enough: hit again once its second is over (%s)" % [hits])
			"armor+dash":
				check(world.player.alive and outcomes == block and bot.log.any(func(l: Dictionary) -> bool: return l["action"] == &"dash"),
					"one armor hit and the dash get through (%s, %s)" % [cause[0], outcomes])
			"armor x2":
				check(world.player.alive and outcomes == block + block, "two armor hits get through (%s, %s)" % [cause[0], outcomes])
			"armor+shield":
				check(world.player.alive and outcomes == block + "%d" % DamageRules.Outcome.BLOCKED_SHIELD,
					"the armor and the shield get through (%s, %s)" % [cause[0], outcomes])
		await sim.free_world(world)


## No wall (the fist never baited): the barrage comes anyway, after its slams, and hits.
func _test_no_wall() -> void:
	var pair: Array = _fight(5, 25.0, null, "slams,barrage")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	bot.baits = false
	var cause: Array[String] = _death(world)
	await _run(world, bot, 40.0, func() -> bool: return not _events(boss, &"barrage_out").is_empty())
	var done: Array[Dictionary] = _events(boss, &"slams_done")
	var beats: Array[Dictionary] = _events(boss, &"beat")
	var fire: Array[Dictionary] = _events(boss, &"barrage_fire")
	check(done.size() == 1 and not bool(done[0]["hit"]) and beats.size() == 2 and beats[1]["kind"] == &"barrage"
		and float(beats[1]["t"]) >= float(done[0]["t"]) + boss.tuning.beat_gap / boss.pace() - 0.02,
		"the barrage follows its slams in the beat script, a beat's gap after them")
	check(fire.size() == 1 and int(fire[0]["wall"]) == 0 and not world.player.alive and cause[0] == "the missiles' fire",
		"with no wall it comes anyway, and the runner takes the hit (%s)" % cause[0])
	await sim.free_world(world)


# --- Reduced flashing ----------------------------------------------------------------------------------------------

func _test_reduced_flashing() -> void:
	var code: String = (load("res://scripts/bosses/golden_convergence/golden_convergence_barrage.gdshader") as Shader).code
	check(code.contains("reduced_flashing") and code.contains("RENDERER_COMPATIBILITY"),
		"its flames' flicker reads Reduced flashing, and the shader has a Compatibility path")
	var was: bool = Settings.flashing_reduced
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var pair: Array = _fight(5, 18.0)
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		world.player.god_mode = true
		var scales: Array[float] = []
		await _run(world, null, 20.0, func() -> bool: return boss.barrage.stage == GoldenConvergenceBarrage.Stage.FIRE, func() -> void:
			var br: GoldenConvergenceBarrage = boss.barrage
			if br.stage == GoldenConvergenceBarrage.Stage.DIVE:
				scales.append(br.missiles.mark_ring(0).x))
		var dips: int = 0
		for i: int in range(1, scales.size()):
			if scales[i] < scales[i - 1] - 0.0005:
				dips += 1
		if reduced:
			check(scales.size() > 10 and dips == 0, "with Reduced flashing the marks hold steady (%d dips)" % dips)
		else:
			check(dips > 0, "they pulse otherwise (%d dips in %s)" % [dips, scales.slice(0, 12)])
		await sim.free_world(world)
	Settings.flashing_reduced = was
