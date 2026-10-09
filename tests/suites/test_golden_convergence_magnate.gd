extends TestSuite
## The Golden Convergence's second stage, The Magnate, and its defeat (GDD §10; task E5d-d), its parts one at a
## time (the stage played through by the bot at every lane count and speed, the release everywhere and
## determinism: test_golden_convergence_magnate_fight.gd):
## - its data: phases 4-6's beat scripts (a Pounce and the bait in every phase, the Cable Lash from phase 5, more
##   of it in phase 6), its sounds (each under 2.5 s, the warnings never pitch-varied, the crackle as long as the
##   Lash's warning) and its hints;
## - his look: two to three times the runner's size, everything on him inside the lit surfaces' chroma limit but
##   the ports (the weak points' red, the only thing on him that glows a hazard colour), the dull red tear, the
##   cracks' warm white (no hazard hue, whiter than the runner's copper), grey smoke, unshaded shaders without
##   emission, his draw budget; never a target before he's out of the suit, one after;
## - the transition (from the checkpoint, again on a retry, and when phase 3 ends): the suit bursts, he claws out
##   and roars as the feed switches to his face, the suit topples off beside the causeway (never down onto the
##   track), he leaps high over the runner and lands behind them; nothing attacks, nothing can touch the runner;
## - the chase: behind the camera in the runner's lane (chase_lane_delay late), his shadow on the floor of his
##   lane ending at the screen's bottom, the marker under his lane; nothing of his solid or harmful;
## - the overtake: along the balustrades and over the lanes, never in a lane in sight, then home;
## - the Pounce: the roar and the red marker, the lock at least LOCK_MIN before he lands and the red square in the
##   runner's lane, the crash live only over the square and only after he lands, above a jump; a runner who
##   leaves the lane is never touched, one who stays is hit, jumping or not; the armor blocks it;
## - the bait: locked onto the buttress's lane he crashes into the gate and slumps across two lanes (its lane and
##   the one toward the middle), a weak point over each, his sides blocking (a switch into him bumps, never
##   hurts); a stomp ends the phase and he hurls himself clear; locked onto another lane it's a Pounce like any
##   other, the buttress stands and the bait comes round again; a runner who doesn't jump is never reached (the
##   release) and the bait comes round again;
## - the Cable Lash: the run-up along a balustrade, the warning (the crackle, the red line over every lane) as long
##   as lash_warning, the cable live across every lane at its heights before the runner gets there, in the enemy
##   attacks' red; a low one only jumped, a high one only slid under; the armor blocks it;
## - the defeat: the cables tearing out one by one, the screens dying outward and the music cut, the collapse
##   ahead in a lane away from the runner and out of their way, the light in his cracks out, the runner past him,
##   then the riff (or silence with victory_riff_on off), and only then victory_over;
## - Reduced flashing: the ports, the square and the cables steady.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
## Stage 2's first phase (phase 4: the checkpoint).
const STAGE_2: int = 3
const REACTION: float = 0.35
const NEW_SOUNDS: Array[StringName] = [&"magnate_roar", &"magnate_growl", &"magnate_breath", &"magnate_leap",
	&"magnate_crash", &"magnate_slam", &"magnate_stun", &"magnate_stomp", &"magnate_howl", &"magnate_crackle",
	&"magnate_whip", &"magnate_tear", &"magnate_screens", &"magnate_screen", &"magnate_burst", &"magnate_suit_fall",
	&"magnate_suit_down", &"magnate_death", &"magnate_collapse"]
## His warnings: the Pounce's roar and the Lash's crackle, each the same every time (no pitch variation).
const WARNINGS: Array[StringName] = [&"magnate_roar", &"magnate_crackle"]
## Lit (non-glowing) surfaces stay below this chroma (as test_golden_convergence checks the suit's).
const MAX_SURFACE_CHROMA: float = 0.45
## His draw budget (measured 21 instances and about 9,300 vertices).
const MAX_INSTANCES: int = 30
const MAX_VERTICES: int = 16000
## GDD §10: he locks onto the runner's lane "about a second before he lands".
const LOCK_MIN: float = 1.0
const FRAME: float = 1.0 / 60.0

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot.preview() if slot != null else null
	if def == null:
		check(false, "the Golden Convergence's preview loads")
		return
	_test_data()
	await _test_look()
	await _test_transition()
	await _test_transition_from_phase_three()
	for lanes: int in [3, 6]:
		await _test_chase(lanes)
	await _test_overtake()
	await _test_pounce(3, 18.0)
	await _test_pounce(6, 25.0)
	await _test_pounce_stays()
	await _test_bait(5, 18.0)
	await _test_bait(3, 25.0)
	await _test_bait_refused()
	await _test_release()
	await _test_bump()
	await _test_lash(&"low", 5, 18.0)
	await _test_lash(&"high", 6, 25.0)
	await _test_lash_wrong()
	await _test_defeat(true)
	await _test_defeat(false)
	await _test_reduced_flashing()


# --- The fight ---------------------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s from phase index `phase` (a checkpoint's resume: 3 is phase 4, the
## transition); every phase's beat script `beats` if given; `mutate` changes the tuning's copy: [world, boss].
func _fight(lanes: int, speed: float, loadout: Loadout = null, phase: int = STAGE_2, beats: String = "",
		mutate: Callable = Callable()) -> Array:
	var d: BossDef = def
	if beats != "" or mutate.is_valid():
		d = def.duplicate() as BossDef
		var t := (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
		if beats != "":
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
	ctx.boss_resume = {"phase": phase}
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


## Steps the fight until `done` holds, the runner dies or `seconds` pass, the bot playing; `each` every frame.
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


## Anything of his that could touch the runner live now (his crash, a cable, a weak point, his sides).
static func _hot(m: GoldenConvergenceMagnate) -> bool:
	if m.crash_box().is_active() or m.blocking():
		return true
	for box: Hazard in m.lash_boxes() + m.weak_boxes():
		if box.is_active():
			return true
	return false


## Brightest minus darkest channel.
static func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


## A saturated red (the hazards' and the enemies' hue).
static func _reddish(c: Color) -> bool:
	return (c.h < 0.06 or c.h > 0.94) and c.s > 0.45 and c.v > 0.3


## A box's world extent (a Hazard's own size about its global position).
static func _box(h: Hazard) -> AABB:
	return AABB(h.global_position - h.size * 0.5, h.size)


# --- Data --------------------------------------------------------------------------------------------------

func _test_data() -> void:
	var t: GoldenConvergenceTuning = def.tuning as GoldenConvergenceTuning
	var known: bool = true
	var each_pounce: bool = true
	var each_bait: bool = true
	var lashes: Array[int] = []
	var kinds: Dictionary = {}
	for index: int in range(STAGE_2, def.phase_count()):
		var n: int = 0
		var pounce: bool = false
		var bait: bool = false
		for beat: Dictionary in t.beats_for(index):
			var arg: String = String(beat["arg"])
			match StringName(beat["kind"]):
				&"pounce":
					pounce = true
					bait = bait or arg == "bait"
					known = known and arg in ["", "bait"]
				&"lash":
					n += 1
					kinds[arg] = true
					known = known and arg in ["low", "high"]
				&"overtake":
					pass
				_:
					known = false
		each_pounce = each_pounce and pounce
		each_bait = each_bait and bait
		lashes.append(n)
	check(def.phase_count() == 6 and known, "stage 2's beat scripts use only its own beats: overtake, pounce, pounce:bait, lash:low, lash:high")
	check(each_pounce and each_bait, "the Pounce is his main attack in every phase of stage 2, and every phase has the bait")
	check(lashes.size() == 3 and lashes[0] == 0 and lashes[1] > 0 and lashes[2] > lashes[1] and kinds.has("low")
		and kinds.has("high"), "the Cable Lash from the second phase of stage 2 (low and high), more of it in the third %s" % [lashes])
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var bad: Array[String] = []
	for sound: StringName in NEW_SOUNDS:
		var stream: AudioStream = library.stream(sound)
		if stream is AudioStreamRandomizer:
			stream = (stream as AudioStreamRandomizer).get_stream(0)
		var length: float = stream.get_length() if stream != null else 0.0
		if length <= 0.1 or length >= 2.5 or not library.volume_db.has(String(sound)):
			bad.append("%s %.2f s" % [sound, length])
	check(bad.is_empty(), "his %d sounds load, each in the library and under 2.5 s: %s" % [NEW_SOUNDS.size(), ", ".join(bad)])
	var varied: Array[String] = []
	for sound: StringName in WARNINGS:
		if float(library.pitch_variation.get(String(sound), 0.0)) > 0.0:
			varied.append(String(sound))
	check(varied.is_empty(), "his warnings (the roar, the crackle) sound the same every time: %s" % ", ".join(varied))
	var crackle: AudioStream = library.stream(&"magnate_crackle")
	var crackle_length: float = crackle.get_length() if crackle != null else 0.0
	check(absf(crackle_length - t.lash_warning) < 0.06, "the crackle lasts as long as the Lash's warning (%.2f s, %.2f s)" % [
		crackle_length, t.lash_warning])
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: Dictionary = {}
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		triggers[String(h.get("trigger", ""))] = true
	check(triggers.has("boss:golden_boss/pounce") and triggers.has("boss:golden_boss/stun") and triggers.has("boss:golden_boss/lash"),
		"the Pounce, the stun and the Cable Lash have hints")


# --- His look ----------------------------------------------------------------------------------------------

func _test_look() -> void:
	var pair: Array = _fight(5, 18.0, null, STAGE_2, "none")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	world.player.god_mode = true
	check(not m.targetable() and not m.shown(), "before the transition he's hidden and never a target")
	await _run(world, null, 1.5)
	check(m.shown() and not m.targetable(), "out of the suit in the transition, still no target")
	await _run(world, null, 8.0, func() -> bool: return boss.is_vulnerable() and boss.chase.home())
	await _run(world, null, 0.3)
	check(boss.is_vulnerable() and m.targetable(), "once his phase's pattern runs, weapons may hit him")
	# His size: two to three times the runner's (their drawn height).
	var runner := AABB()
	var first: bool = true
	for node: Node in world.player.find_children("*", "MeshInstance3D", true, false):
		var pm := node as MeshInstance3D
		if pm.mesh == null or not pm.is_visible_in_tree() or pm.get_aabb().size.y < 0.05:
			continue
		var b: AABB = pm.global_transform * pm.get_aabb()
		runner = b if first else runner.merge(b)
		first = false
	var length: float = GoldenConvergenceMagnateModel.BODY_LENGTH * boss.tuning.magnate_scale
	var ratio: float = length / maxf(runner.size.y, 0.1)
	check(ratio >= 2.0 and ratio <= 3.0, "he's two to three times the runner's size: %.1f m long to their %.2f m (%.1f times)" % [
		length, runner.size.y, ratio])
	# His colours: inside the lit surfaces' chroma limit but for the ports; the tear a dull red.
	var loud: Array[String] = []
	var tear: int = 0
	var tear_ok: bool = true
	var ports: int = 0
	for mi: MeshInstance3D in m.meshes():
		if mi.mesh == null:
			continue
		if mi.material_override == m.port_material():
			ports += 1
			continue
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			for c: Color in colors:
				var rgb := Color(c.r, c.g, c.b)
				if _chroma(rgb) > MAX_SURFACE_CHROMA and loud.size() < 4:
					loud.append(str(rgb))
				if rgb.r > rgb.g * 2.5 and rgb.r > rgb.b * 2.5 and rgb.v > 0.2:
					tear += 1
					tear_ok = tear_ok and rgb.v < 0.45
	check(loud.is_empty(), "his skin, gold, mask, tatters and cables stay below the hazards' saturation: %s" % ", ".join(loud))
	check(tear > 0 and tear_ok, "half the calm mask fused to his face, its tear a dull red (%d vertices)" % tear)
	var port: StandardMaterial3D = m.port_material()
	check(ports > 0 and port.emission_enabled and _reddish(port.emission),
		"the ports on his spine glow the weak points' red (%d meshes, %s)" % [ports, port.emission])
	var body: ShaderMaterial = m.body_material()
	var code: String = body.shader.code if body != null and body.shader != null else ""
	var crack: Color = Color(1.0, 0.93, 0.82)
	var value: Variant = body.get_shader_parameter(&"crack_color") if body != null else null
	if value is Color:
		crack = value
	elif value is Vector3:
		crack = Color((value as Vector3).x, (value as Vector3).y, (value as Vector3).z)
	check(code.contains("unshaded") and not code.contains("EMISSION"), "his body's shader is unshaded, without emission")
	check(not _reddish(crack) and _chroma(crack) < _chroma(PlayerSuit.GLOW) - 0.2,
		"his cracks leak the cult's warm white, no hazard hue and whiter than the runner's copper glow (%s, %s)" % [crack, PlayerSuit.GLOW])
	var smoke_ok: bool = true
	for node: Node in m.find_children("*", "CPUParticles3D", true, false):
		var p := node as CPUParticles3D
		smoke_ok = smoke_ok and _chroma(p.color) < 0.12
		var mat := p.material_override as StandardMaterial3D
		smoke_ok = smoke_ok and (mat == null or not mat.emission_enabled)
	check(smoke_ok, "his tatters trail grey smoke, never glowing embers")
	var stats: Dictionary = m.draw_stats()
	print("  The Magnate draws %d instances, %d surfaces, %d vertices" % [stats["instances"], stats["surfaces"], stats["vertices"]])
	check(int(stats["instances"]) <= MAX_INSTANCES and int(stats["vertices"]) <= MAX_VERTICES,
		"his draw budget: %d instances, %d vertices" % [stats["instances"], stats["vertices"]])
	await sim.free_world(world)


# --- The transition ----------------------------------------------------------------------------------------

## From the checkpoint, twice (a retry plays it the same).
func _test_transition() -> void:
	var timeline: Array = []
	for attempt: int in 2:
		var pair: Array = _fight(5, 18.0, null, STAGE_2, "none")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var skin := world.skin as GoldenCourtSkin
		var cause: Array[String] = _death(world)
		var rec := {"hot": 0, "suit_low": INF, "over": INF, "mode_before_roar": -1, "mode_after_roar": -1, "roared": false}
		await _run(world, null, 9.0, func() -> bool: return boss.is_vulnerable() and boss.chase.home(), func() -> void:
			var m: GoldenConvergenceMagnate = boss.magnate
			if _hot(m) or not _events(boss, &"beat").is_empty():
				rec["hot"] = int(rec["hot"]) + 1
			var suit: GoldenConvergenceSuit = boss.suit
			if suit.visible and absf(suit.global_position.x) <= world.geo.wall_x() + 1.0:
				rec["suit_low"] = minf(float(rec["suit_low"]), suit.global_position.y)
			var rel: float = -m.global_position.z - world.player.distance
			if boss.transition.kind == &"transition" and m.shown() and absf(rel) < 2.5 \
					and not _events(boss, &"transition_leap").is_empty():
				rec["over"] = minf(float(rec["over"]), m.global_position.y)
			var roared: bool = not _events(boss, &"magnate_roar").is_empty()
			if not roared:
				rec["mode_before_roar"] = int(skin.feed_state()["mode"])
			elif not bool(rec["roared"]):
				rec["roared"] = true
				rec["mode_after_roar"] = int(skin.feed_state()["mode"]))
		var order: Array[StringName] = [&"stage_2", &"transition", &"magnate_emerges", &"magnate_roar", &"transition_leap",
			&"transition_done"]
		var times: Array[float] = []
		for e: StringName in order:
			var found: Array[Dictionary] = _events(boss, e)
			times.append(float(found[0]["t"]) if found.size() == 1 else -1.0)
		var in_order: bool = not times.has(-1.0)
		for i: int in range(1, times.size()):
			in_order = in_order and times[i] >= times[i - 1]
		var tag: String = "(a retry)" if attempt == 1 else ""
		check(in_order, "from the checkpoint: the suit bursts, he claws out, roars and leaps over the runner, in order %s %s" % [times, tag])
		check(_sounds(boss, &"magnate_burst") == 1 and _sounds(boss, &"magnate_roar") == 1 and _sounds(boss, &"magnate_suit_fall") == 1,
			"with the burst, his roar (the screech) and the suit's fall heard %s" % tag)
		check(int(rec["mode_before_roar"]) == 0 and int(rec["mode_after_roar"]) == 1,
			"the feed switches to his roaring face as he roars %s" % tag)
		check(world.player.alive and int(rec["hot"]) == 0 and boss.magnate.touches.is_empty(),
			"nothing attacks during it and nothing of his can touch the runner (%s) %s" % [cause[0], tag])
		check(float(rec["over"]) > 2.0, "he leaps high over the runner (%.1f m up as he passes over them) %s" % [rec["over"], tag])
		var rel: float = -boss.magnate.global_position.z - world.player.distance
		check(boss.chase.home() and rel < -world.tuning.camera_distance and boss.chase.lane == world.player.lane,
			"and lands behind them, behind the camera in their lane (%.1f m) %s" % [rel, tag])
		await _run(world, null, 2.0, func() -> bool: return boss.transition.suit_down)
		check(boss.transition.suit_down and not boss.suit.visible and boss.suit.find_children("*", "Hazard", true, false).is_empty(),
			"the empty suit crashes down beside the causeway and is gone, never a hazard %s" % tag)
		check(float(rec["suit_low"]) > 4.0, "it never comes down onto the track (lowest %.1f m over it) %s" % [rec["suit_low"], tag])
		timeline.append(times)
		await sim.free_world(world)
	check(timeline.size() == 2 and timeline[0] == timeline[1], "a retry from the checkpoint plays the transition again, the same")


## When phase 3 ends (the third ship's blast: here a hit), phase 4 begins with the transition and the checkpoint.
func _test_transition_from_phase_three() -> void:
	var pair: Array = _fight(5, 18.0, null, STAGE_2 - 1, "none")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	world.player.god_mode = true
	await _run(world, null, 8.0, func() -> bool: return boss.is_vulnerable())
	for i: int in 6:
		if boss.phase_index >= STAGE_2 or not boss.is_vulnerable():
			break
		boss.damage(boss.hit_damage(), &"blast")
	check(boss.phase_index == STAGE_2 and not _events(boss, &"checkpoint").is_empty(),
		"phase 3's end begins phase 4 at the checkpoint (phase %d)" % (boss.phase_index + 1))
	await _run(world, null, 8.0, func() -> bool: return boss.is_vulnerable() and boss.chase.home())
	check(boss.transition.played == 1 and _events(boss, &"transition_done").size() == 1 and boss.chase.home()
		and boss.suit.immune_to_weapons and boss.magnate.targetable(),
		"and the transition plays there too: the suit no target any more, The Magnate hunts the runner")
	await sim.free_world(world)


# --- The chase ---------------------------------------------------------------------------------------------

func _test_chase(lanes: int) -> void:
	var pair: Array = _fight(lanes, 18.0, null, STAGE_2, "none")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	var t: GoldenConvergenceTuning = boss.tuning
	world.player.god_mode = true
	var tag: String = "(%d lanes)" % lanes
	await _run(world, null, 9.0, func() -> bool: return boss.is_vulnerable() and boss.chase.home())
	await _run(world, null, 1.0)
	var rec := {"hot": 0, "in_view": 0}
	var watch := func() -> void:
		if _hot(m):
			rec["hot"] = int(rec["hot"]) + 1
		if -m.global_position.z - world.player.distance > -world.tuning.camera_distance:
			rec["in_view"] = int(rec["in_view"]) + 1
	var from: int = world.player.lane
	var dir: int = 1 if from < lanes - 1 else -1
	world.player.press(&"move_right" if dir > 0 else &"move_left")
	await _run(world, null, t.chase_lane_delay * 0.6, Callable(), watch)
	check(boss.chase.lane == from, "he keeps to the lane the runner was in a moment ago %s" % tag)
	await _run(world, null, t.chase_lane_delay + 0.8, Callable(), watch)
	var lane_x: float = world.geo.lane_x(world.player.lane)
	check(boss.chase.lane == world.player.lane and absf(m.global_position.x - lane_x) < 0.05,
		"then follows them into their new lane %s" % tag)
	check(absf(m.marker.lane_x - m.global_position.x) < 0.01 and m.marker.shown > 0.95 and m.marker.alarm == 0.0
		and m.marker.color().is_equal_approx(GoldenConvergenceMagnateMarker.CALM),
		"the marker at the screen's bottom edge shows his lane, in the cult's warm white %s" % tag)
	var shadow: Variant = m.shadow_box()
	var box: AABB = shadow if shadow is AABB else AABB()
	var near_end: float = box.position.z - world.player.global_position.z
	check(shadow is AABB and box.position.x <= lane_x and box.end.x >= lane_x and box.size.x < world.geo.lane_width * 1.2
		and near_end > 0.0 and near_end < 1.5 and box.size.z > 3.0,
		"his shadow lies on the floor of his lane behind the runner, ending just behind them (%.2f m) %s" % [near_end, tag])
	check(int(rec["hot"]) == 0 and int(rec["in_view"]) == 0 and m.touches.is_empty(),
		"behind the camera, nothing of his solid or harmful %s" % tag)
	await sim.free_world(world)


## The overtake: he shows himself along the balustrades and high over the lanes, never in a lane in sight.
func _test_overtake() -> void:
	var pair: Array = _fight(5, 18.0, null, STAGE_2, "overtake")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	world.player.god_mode = true
	await _run(world, null, 9.0, func() -> bool: return boss.is_vulnerable() and boss.chase.home())
	var rec := {"hot": 0, "low_in_lane": 0, "ahead": -INF}
	await _run(world, null, 14.0, func() -> bool: return boss.overtake.count >= 1 and not boss.overtake.busy(), func() -> void:
		if _hot(m):
			rec["hot"] = int(rec["hot"]) + 1
		var rel: float = -m.global_position.z - world.player.distance
		rec["ahead"] = maxf(float(rec["ahead"]), rel)
		if rel > -world.tuning.camera_distance and absf(m.global_position.x) < world.geo.wall_x() - 0.2 \
				and m.global_position.y < 3.0:
			rec["low_in_lane"] = int(rec["low_in_lane"]) + 1)
	check(boss.overtake.count == 1 and not boss.overtake.busy() and boss.chase.home(), "he overtakes once and drops back home")
	check(float(rec["ahead"]) >= boss.tuning.overtake_ahead * 0.8, "he gets well ahead of the runner (%.0f m)" % rec["ahead"])
	check(int(rec["low_in_lane"]) == 0 and int(rec["hot"]) == 0 and m.touches.is_empty(),
		"along the balustrades and high over the lanes: never in a lane in sight, never touchable (%d frames)" % rec["low_in_lane"])
	await sim.free_world(world)


# --- The Pounce --------------------------------------------------------------------------------------------

## The bot dodges two Pounces: the warning, the lock, the square, the crash only there.
func _test_pounce(lanes: int, speed: float) -> void:
	var pair: Array = _fight(lanes, speed, null, STAGE_2, "pounce")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	var pc: GoldenConvergencePounce = boss.pounce
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var hints: Array[String] = []
	boss.hint_due.connect(func(key: String) -> void: hints.append(key))
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var rec := {"roar_frames": 0, "red": 0, "crash_frames": 0, "bad_crash": [], "unwarned": 0, "early": 0}
	await _run(world, bot, 40.0, func() -> bool: return _events(boss, &"pounce_bound").size() >= 2, func() -> void:
		if pc.stage == GoldenConvergencePounce.Stage.ROAR:
			rec["roar_frames"] = int(rec["roar_frames"]) + 1
			if m.marker.alarm >= 1.0 and m.marker.color().is_equal_approx(GoldenConvergenceMagnateMarker.ALARM):
				rec["red"] = int(rec["red"]) + 1
		var sq: Dictionary = pc.square()
		if not sq.is_empty() and not boss.props.warned(int(sq["lane"]), float(sq["from"]), float(sq["to"])):
			rec["unwarned"] = int(rec["unwarned"]) + 1
		if m.crash_box().is_active():
			rec["crash_frames"] = int(rec["crash_frames"]) + 1
			if pc.stage != GoldenConvergencePounce.Stage.CRASH:
				rec["early"] = int(rec["early"]) + 1
			var b: AABB = _box(m.crash_box())
			var lane: int = int(pc.p.get("lane", -1))
			var sqv: Vector2 = pc.p.get("square", Vector2.ZERO)
			var x: float = world.geo.lane_x(lane)
			var half: float = world.geo.lane_width * 0.5
			var ok: bool = b.position.x >= x - half - 0.01 and b.end.x <= x + half + 0.01 \
				and absf(-b.end.z - sqv.x) < 0.05 and absf(-b.position.z - sqv.y) < 0.05
			if not ok and (rec["bad_crash"] as Array).size() < 3:
				(rec["bad_crash"] as Array).append(str(b)))
	var locks: Array[Dictionary] = _events(boss, &"pounce_lock")
	var crashes: Array[Dictionary] = _events(boss, &"pounce_crash")
	var roars: Array[Dictionary] = _events(boss, &"pounce_roar")
	check(world.player.alive and m.touches.is_empty() and crashes.size() >= 2,
		"the bot dodges two Pounces untouched %s (%s)" % [tag, cause[0]])
	var lead_ok: bool = locks.size() >= 2
	var lane_ok: bool = true
	var warn_ok: bool = true
	for i: int in mini(locks.size(), crashes.size()):
		lead_ok = lead_ok and float(crashes[i]["t"]) - float(locks[i]["t"]) >= LOCK_MIN - FRAME
		lane_ok = lane_ok and int(crashes[i]["lane"]) == int(locks[i]["lane"]) and int(crashes[i]["runner_lane"]) != int(crashes[i]["lane"])
		warn_ok = warn_ok and i < roars.size() and float(crashes[i]["t"]) - float(roars[i]["t"]) >= LOCK_MIN
	check(lead_ok, "he locks onto the runner's lane at least %.1f s before he lands %s" % [LOCK_MIN, tag])
	check(lane_ok, "he crashes down in the lane he locked onto, the runner out of it %s" % tag)
	check(warn_ok and int(rec["roar_frames"]) > 0 and int(rec["red"]) == int(rec["roar_frames"]) and _sounds(boss, &"magnate_roar") >= 2,
		"each with a roar as the marker turns red, well before he lands %s" % tag)
	check(int(rec["unwarned"]) == 0, "the red square marks where he'll land, a floor warning %s" % tag)
	check(int(rec["crash_frames"]) > 0 and int(rec["early"]) == 0 and (rec["bad_crash"] as Array).is_empty(),
		"the crash is live only once he's down, only over the square: %s %s" % [", ".join(PackedStringArray(rec["bad_crash"])), tag])
	check(boss.tuning.crash_height > world.tuning.jump_height + world.tuning.hurtbox_size.y,
		"the crash reaches above a jump (%.1f m)" % boss.tuning.crash_height)
	check(hints.count("golden_boss/pounce") == 1, "the Pounce's hint comes once %s" % tag)
	await sim.free_world(world)


## A runner who stays in the square is hit there, a jump doesn't clear him, and the armor blocks him.
func _test_pounce_stays() -> void:
	for how: String in ["stays", "jumps", "armor"]:
		var loadout: Loadout = null
		if how == "armor":
			loadout = Loadout.new()
			loadout.armor = true
		var pair: Array = _fight(5, 18.0, loadout, STAGE_2, "pounce")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var m: GoldenConvergenceMagnate = boss.magnate
		var pc: GoldenConvergencePounce = boss.pounce
		var bot := _bot(boss)
		bot.dodges_pounce = false
		var cause: Array[String] = _death(world)
		var jumped := {"done": false}
		await _run(world, bot, 25.0, func() -> bool: return not m.touches.is_empty() and m.touches.size() >= 1 \
				and pc.stage != GoldenConvergencePounce.Stage.CRASH, func() -> void:
			var sq: Dictionary = pc.square()
			if how == "jumps" and not bool(jumped["done"]) and not sq.is_empty() and world.player.grounded \
					and float(sq["from"]) - world.player.distance <= boss.speed() * world.tuning.jump_time_to_apex:
				jumped["done"] = true
				world.player.press(&"jump"))
		var lock: Array[Dictionary] = _events(boss, &"pounce_lock")
		var touch: Dictionary = m.touches[0] if not m.touches.is_empty() else {}
		match how:
			"stays":
				check(not world.player.alive and touch.get("kind", &"") == &"crash" and not lock.is_empty()
					and int(touch.get("lane", -1)) == int(lock[0]["lane"]), "a runner who stays in his lane is hit by the crash (%s)" % cause[0])
			"jumps":
				check(bool(jumped["done"]) and not world.player.alive and touch.get("kind", &"") == &"crash"
					and float(touch.get("h", 0.0)) > 0.3, "a jump doesn't clear him: hit %.1f m up" % float(touch.get("h", 0.0)))
			"armor":
				check(world.player.alive and int(touch.get("outcome", -1)) == DamageRules.Outcome.BLOCKED_ARMOR,
					"the armor blocks the crash (%s)" % [touch])
		await sim.free_world(world)


# --- The bait ----------------------------------------------------------------------------------------------

## The bot takes the bait: the stun across two lanes, his weak points and sides; its stomp ends the phase.
func _test_bait(lanes: int, speed: float) -> void:
	var pair: Array = _fight(lanes, speed, null, STAGE_2, "pounce:bait")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	var pc: GoldenConvergencePounce = boss.pounce
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var tag: String = "(%d lanes, %.0f m/s)" % [lanes, speed]
	var rec := {"seen": false, "lanes": [], "gate": -1, "weak": [], "blocker": false, "body": 0, "ports": 0.0, "lock_lane": -1}
	await _run(world, bot, 40.0, func() -> bool: return boss.phase_index > STAGE_2 and not boss.transition.busy(), func() -> void:
		if pc.stunned() and not bool(rec["seen"]):
			rec["seen"] = true
			rec["lanes"] = (pc.p["stun_lanes"] as Array).duplicate()
			rec["gate"] = int(pc.p["gate_lane"])
			rec["blocker"] = m.blocking()
			rec["ports"] = m.ports_glow
			for i: int in 2:
				var w: Hazard = m.weak_boxes()[i]
				(rec["weak"] as Array).append({"on": w.is_active(), "box": _box(w)})
			if m.crash_box().is_active():
				rec["body"] = 1)
	var stun: Array[Dictionary] = _events(boss, &"stun")
	check(world.player.alive and m.touches.is_empty() and pc.stuns == 1 and stun.size() == 1,
		"locked onto the buttress's lane, he crashes into the gate, stunned %s (%s)" % [tag, cause[0]])
	var st_lanes: Array = rec["lanes"]
	var gate: int = int(rec["gate"])
	var mid: float = (lanes - 1) * 0.5
	var two: bool = st_lanes.size() == 2 and int(st_lanes[1]) == int(st_lanes[0]) + 1 and st_lanes.has(gate)
	var other: int = int(st_lanes[0]) if two and int(st_lanes[1]) == gate else (int(st_lanes[1]) if two else -1)
	check(two and (absf(other - mid) <= absf(gate - mid) or absf(gate - mid) < 0.6), "he slumps across two lanes, the buttress's and its neighbour toward the middle %s %s" % [st_lanes, tag])
	var weak_ok: bool = two and (rec["weak"] as Array).size() == 2
	var back: float = float(stun[0]["back"]) if not stun.is_empty() else 0.0
	for i: int in (rec["weak"] as Array).size():
		var w: Dictionary = rec["weak"][i]
		var b: AABB = w["box"]
		var x: float = world.geo.lane_x(int(st_lanes[i])) if two else 0.0
		weak_ok = weak_ok and bool(w["on"]) and absf(b.get_center().x - x) < 0.05 and b.size.x <= world.geo.lane_width \
			and -b.end.z <= back - 1.0 and -b.position.z >= back + 1.0 and b.end.y >= GoldenConvergencePounce.STUN_BACK_TOP
	check(weak_ok, "a weak point over his back in each of his lanes %s" % tag)
	check(bool(rec["blocker"]) and int(rec["body"]) == 0 and float(rec["ports"]) >= 1.0,
		"his sides solid but safe (no hitbox of his body), the red ports on his spine glowing %s" % tag)
	check(_events(boss, &"buttress_smashed").size() == 1 and _sounds(boss, &"magnate_slam") == 1 and _sounds(boss, &"magnate_stun") == 1,
		"the gate smashed, with the slam and the stun heard %s" % tag)
	check(pc.stomps == 1 and _events(boss, &"magnate_stomp").size() == 1 and boss.phase_index == STAGE_2 + 1
		and boss.transition.hurls == 1 and _sounds(boss, &"magnate_howl") >= 1,
		"a stomp on his back ends the phase and he hurls himself clear, howling %s" % tag)
	check(not m.blocking() and not m.weak_boxes()[0].is_active() and not m.weak_boxes()[1].is_active() and m.ports_glow == 0.0,
		"his weak points and sides are gone after the stomp %s" % tag)
	await sim.free_world(world)


## A runner who keeps out of the buttress's lane: a Pounce like any other, the buttress stands, the bait again.
func _test_bait_refused() -> void:
	var pair: Array = _fight(5, 18.0, null, STAGE_2, "pounce:bait")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	var pc: GoldenConvergencePounce = boss.pounce
	var bot := _bot(boss)
	bot.takes_bait = false
	var cause: Array[String] = _death(world)
	await _run(world, bot, 45.0, func() -> bool: return _events(boss, &"bait_placed").size() >= 2 and _events(boss, &"pounce_lock").size() >= 2)
	var locks: Array[Dictionary] = _events(boss, &"pounce_lock")
	var untaken: bool = not locks.is_empty()
	for e: Dictionary in locks:
		untaken = untaken and not bool(e["taken"])
	check(world.player.alive and m.touches.is_empty() and pc.stuns == 0 and untaken and _events(boss, &"buttress_smashed").is_empty(),
		"locked onto another lane, it's a Pounce like any other: no stun, the buttress stands (%s)" % cause[0])
	check(_events(boss, &"bait_placed").size() >= 2, "and the bait comes round again")
	await sim.free_world(world)


## A runner who doesn't jump onto his back: he shakes free before they reach him, and the bait comes again.
func _test_release() -> void:
	var pair: Array = _fight(5, 18.0, null, STAGE_2, "pounce:bait")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	var pc: GoldenConvergencePounce = boss.pounce
	var bot := _bot(boss)
	bot.stomps = false
	var cause: Array[String] = _death(world)
	await _run(world, bot, 45.0, func() -> bool: return _events(boss, &"bait_placed").size() >= 2)
	var released: Array[Dictionary] = _events(boss, &"stun_released")
	check(released.size() == 1 and pc.misses == 1 and float(released[0]["gap"]) > 0.0,
		"he shakes free before the runner reaches his back (%.1f m short)" % (float(released[0]["gap"]) if not released.is_empty() else -1.0))
	check(world.player.alive and m.touches.is_empty() and not m.blocking() and boss.phase_index == STAGE_2,
		"never touching them, the phase going on (%s)" % cause[0])
	check(_events(boss, &"bait_placed").size() >= 2, "and the bait comes round again")
	await sim.free_world(world)


## Stunned, he's solid but safe: a switch into him from the next lane (in the air beside him) bumps, never hurts.
func _test_bump() -> void:
	var pair: Array = _fight(5, 18.0, null, STAGE_2, "pounce:bait")
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	var pc: GoldenConvergencePounce = boss.pounce
	var bot := _bot(boss)
	bot.stomps = false
	var cause: Array[String] = _death(world)
	var bumps: Array[int] = [0]
	world.player.movement_event.connect(func(kind: StringName) -> void:
		if kind == &"lane_blocked":
			bumps[0] += 1)
	var rec := {"outside": -1, "jumped": false, "pressed": false, "lane_at_press": -1, "wait": 0.0}
	await _run(world, null, 40.0, func() -> bool: return pc.misses >= 1 or pc.stomps >= 1, func() -> void:
		if not pc.stunned():
			if int(rec["outside"]) < 0:
				bot.step()
			return
		var lanes: Array = pc.p["stun_lanes"]
		if int(rec["outside"]) < 0:
			rec["outside"] = int(lanes[1]) + 1 if int(lanes[1]) + 1 < boss.lane_count() else int(lanes[0]) - 1
		var outside: int = int(rec["outside"])
		var pl: Player = world.player
		var gap: float = pc.stun_back() - pl.distance
		rec["wait"] = float(rec["wait"]) - FRAME
		if pl.lane != outside and float(rec["wait"]) <= 0.0:
			pl.press(&"move_right" if outside > pl.lane else &"move_left")
			rec["wait"] = 0.2
		elif pl.lane == outside and not bool(rec["jumped"]) and pl.grounded and gap <= pc.release_gap() + 0.6:
			rec["jumped"] = true
			pl.press(&"jump")
		elif bool(rec["jumped"]) and not bool(rec["pressed"]) and gap <= 1.0:
			rec["pressed"] = true
			rec["lane_at_press"] = pl.lane
			pl.press(&"move_left" if int(lanes[0]) < outside else &"move_right"))
	check(bool(rec["pressed"]) and bumps[0] >= 1 and world.player.lane == int(rec["lane_at_press"]),
		"a switch into him while he's stunned bumps the runner back (%d bumps)" % bumps[0])
	check(world.player.alive and m.touches.is_empty(), "and never hurts them (%s)" % cause[0])
	await sim.free_world(world)


# --- The Cable Lash ----------------------------------------------------------------------------------------

func _test_lash(kind: StringName, lanes: int, speed: float) -> void:
	var pair: Array = _fight(lanes, speed, null, STAGE_2 + 1, "lash:%s" % kind)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	var l: GoldenConvergenceLash = boss.lash
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var hints: Array[String] = []
	boss.hint_due.connect(func(key: String) -> void: hints.append(key))
	var tag: String = "(%s, %d lanes, %.0f m/s)" % [kind, lanes, speed]
	var rec := {"unwarned": 0, "warn_frames": 0, "early": 0, "on_balustrade": true, "at_line": [], "bad_box": 0}
	await _run(world, bot, 40.0, func() -> bool: return _events(boss, &"lash_done").size() >= 2 and not l.busy(), func() -> void:
		if l.p.is_empty():
			return
		var line: float = float(l.p["line_at"])
		if l.stage == GoldenConvergenceLash.Stage.WARN:
			rec["warn_frames"] = int(rec["warn_frames"]) + 1
			for lane: int in boss.lane_count():
				if not boss.props.warned(lane, line - 0.3, line + 0.3):
					rec["unwarned"] = int(rec["unwarned"]) + 1
			if absf(absf(m.global_position.x) - absf(boss.chase.balustrade_x(1))) > 0.05:
				rec["on_balustrade"] = false
		var heights: Array = l.p["heights"]
		for i: int in 2:
			var box: Hazard = m.lash_boxes()[i]
			if not box.is_active():
				continue
			if l.stage in [GoldenConvergenceLash.Stage.RUN_UP, GoldenConvergenceLash.Stage.WARN]:
				rec["early"] = int(rec["early"]) + 1
			var b: AABB = _box(box)
			if i >= heights.size() or absf(b.get_center().y - float(heights[i])) > 0.01 or absf(-b.get_center().z - line) > 0.01:
				rec["bad_box"] = int(rec["bad_box"]) + 1
		# As the runner reaches the line: what's live across the track.
		if (rec["at_line"] as Array).size() < _events(boss, &"lash_whip").size() and world.player.distance + 0.5 >= line:
			var across: bool = true
			for i: int in heights.size():
				var b: AABB = _box(m.lash_boxes()[i])
				var half: float = world.geo.lane_width * 0.5
				across = across and m.lash_boxes()[i].is_active() and b.position.x <= world.geo.lane_x(0) - half \
					and b.end.x >= world.geo.lane_x(boss.lane_count() - 1) + half
			(rec["at_line"] as Array).append(across))
	var warned: Array[Dictionary] = _events(boss, &"lash_warned")
	var whips: Array[Dictionary] = _events(boss, &"lash_whip")
	var acrosses: Array[Dictionary] = _events(boss, &"lash_across")
	check(world.player.alive and m.touches.is_empty() and whips.size() >= 2,
		"the bot %s two Cable Lashes untouched %s (%s)" % ["jumps" if kind == &"low" else "slides under", tag, cause[0]])
	var timing_ok: bool = warned.size() >= 2 and whips.size() >= 2
	for i: int in mini(warned.size(), whips.size()):
		timing_ok = timing_ok and absf(float(whips[i]["t"]) - float(warned[i]["t"]) - boss.tuning.lash_warning) < 2.0 * FRAME
	check(timing_ok and _sounds(boss, &"magnate_crackle") >= 2 and _sounds(boss, &"magnate_whip") >= 2,
		"each warned by the rising crackle for lash_warning (%.2f s) before the whip %s" % [boss.tuning.lash_warning, tag])
	check(int(rec["warn_frames"]) > 0 and int(rec["unwarned"]) == 0 and bool(rec["on_balustrade"]),
		"a red line across every lane where it will sweep, him rearing on the balustrade %s" % tag)
	var lead_ok: bool = acrosses.size() >= 2 and warned.size() >= acrosses.size()
	for i: int in mini(acrosses.size(), warned.size()):
		var lead: float = float(warned[i]["line"]) - float(acrosses[i]["runner"])
		lead_ok = lead_ok and lead >= speed * (boss.tuning.lash_cross_lead - 2.0 * FRAME)
	check(lead_ok, "the cable lies across every lane lash_cross_lead (%.2f s) before the runner gets there %s" % [
		boss.tuning.lash_cross_lead, tag])
	check(int(rec["early"]) == 0 and int(rec["bad_box"]) == 0 and (rec["at_line"] as Array).size() >= 2
		and not (rec["at_line"] as Array).has(false), "the cable live across every lane at its heights as the runner reaches it %s %s" % [rec["at_line"], tag])
	var red: Color = GoldenConvergenceLash.COLOR
	check(_reddish(red) and red.b < 0.3, "in the enemy attacks' red, not the fences' pink (%s)" % red)
	check(hints.count("golden_boss/lash") == 1, "the Lash's hint comes once %s" % tag)
	await sim.free_world(world)


## A low Lash is only jumped and a high one only slid under: a runner who doesn't answer, or answers each the
## other way, is hit; the armor blocks it.
func _test_lash_wrong() -> void:
	for kind: StringName in [&"low", &"high"]:
		for how: String in ["runs on", "answers wrong", "armor"]:
			var loadout: Loadout = null
			if how == "armor":
				loadout = Loadout.new()
				loadout.armor = true
			var pair: Array = _fight(5, 18.0, loadout, STAGE_2 + 1, "lash:%s" % kind)
			var world: RunWorld = pair[0]
			var boss: GoldenConvergence = pair[1]
			var m: GoldenConvergenceMagnate = boss.magnate
			var bot := _bot(boss)
			bot.answers_lash = how == "answers wrong"
			bot.wrong_lash = how == "answers wrong"
			await _run(world, bot, 20.0, func() -> bool: return not m.touches.is_empty() or _events(boss, &"lash_done").size() >= 1)
			var touch: Dictionary = m.touches[0] if not m.touches.is_empty() else {}
			if how == "armor":
				check(world.player.alive and touch.get("kind", &"") == &"lash" and int(touch.get("outcome", -1)) == DamageRules.Outcome.BLOCKED_ARMOR,
					"the armor blocks a %s Lash (%s)" % [kind, touch])
			else:
				check(not world.player.alive and touch.get("kind", &"") == &"lash",
					"a runner who %s a %s Lash is hit (%s)" % [how, kind, touch])
			await sim.free_world(world)


# --- The defeat --------------------------------------------------------------------------------------------

## From phase 6: the bait and the stomp, then the feed dies.
func _test_defeat(riff_on: bool) -> void:
	var mutate := func(t: GoldenConvergenceTuning) -> void: t.victory_riff_on = riff_on
	var pair: Array = _fight(5, 18.0, null, STAGE_2 + 2, "pounce:bait", mutate)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var m: GoldenConvergenceMagnate = boss.magnate
	var skin := world.skin as GoldenCourtSkin
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	var tag: String = "" if riff_on else "(no riff)"
	var rec := {"early_over": 0, "in_way": 0, "radius": [], "hot": 0, "light_at_past": -1.0}
	await _run(world, bot, 60.0, func() -> bool: return boss.is_defeated() and boss.victory_over(), func() -> void:
		var d: GoldenConvergenceDefeat = boss.defeat
		if d.step == GoldenConvergenceDefeat.Step.NONE:
			return
		if d.step != GoldenConvergenceDefeat.Step.OVER and boss.victory_over():
			rec["early_over"] = int(rec["early_over"]) + 1
		var rel: float = -m.global_position.z - world.player.distance
		if rel > 0.0 and rel < 40.0 and absf(m.global_position.x - world.player.global_position.x) < world.geo.lane_width * 0.5 \
				and d.step == GoldenConvergenceDefeat.Step.DOWN:
			rec["in_way"] = int(rec["in_way"]) + 1
		if m.crash_box().is_active() or m.weak_boxes()[0].is_active() or m.weak_boxes()[1].is_active():
			rec["hot"] = int(rec["hot"]) + 1
		if d.blackout_radius >= 0.0:
			(rec["radius"] as Array).append(d.blackout_radius)
		if d.passed_at >= 0.0 and float(rec["light_at_past"]) < 0.0:
			rec["light_at_past"] = m.crack_light)
	var d: GoldenConvergenceDefeat = boss.defeat
	check(boss.is_defeated() and boss.victory_over() and d.over() and world.player.alive and m.touches.is_empty(),
		"the third stomp defeats him; the runner untouched to the end %s (%s)" % [tag, cause[0]])
	var t: GoldenConvergenceTuning = boss.tuning
	var torn: Array[Dictionary] = _events(boss, &"cable_torn")
	var start: Array[Dictionary] = _events(boss, &"defeat_start")
	var spaced: bool = torn.size() == m.cable_count() and m.cable_count() >= 4 and not start.is_empty()
	for i: int in range(1, torn.size()):
		spaced = spaced and float(torn[i]["time"]) - float(torn[i - 1]["time"]) >= t.tear_every - 2.0 * FRAME
	check(spaced and _sounds(boss, &"magnate_tear") == torn.size() and _sounds(boss, &"magnate_death") == 1,
		"he convulses and his cables tear out of his back one by one (%d) %s" % [torn.size(), tag])
	check(d.music_cut and _events(boss, &"music_cut").size() == 1, "the music cuts out with the screens %s" % tag)
	var collapse: Array[Dictionary] = _events(boss, &"collapse")
	var last_tear: float = float(torn[-1]["time"]) if not torn.is_empty() else INF
	check(collapse.size() == 1 and int(collapse[0]["lane"]) != int(collapse[0]["runner_lane"]) and float(collapse[0]["time"]) >= last_tear
		and float(collapse[0]["at"]) > float(collapse[0]["runner"]) and int(rec["in_way"]) == 0,
		"he collapses on the causeway ahead once his last cable is out, in a lane away from the runner, never in their way %s" % tag)
	check(int(rec["hot"]) == 0, "nothing of his can hurt the runner after the defeat %s" % tag)
	check(m.crack_light <= 0.0 and float(rec["light_at_past"]) >= 0.0, "the last light in his cracks goes out %s" % tag)
	var past: Array[Dictionary] = _events(boss, &"runner_past")
	var riff: Array[Dictionary] = _events(boss, &"riff")
	var over: Array[Dictionary] = _events(boss, &"defeat_over")
	check(past.size() == 1 and over.size() == 1 and int(rec["early_over"]) == 0, "the runner runs past him; only then is it over %s" % tag)
	if riff_on:
		check(riff.size() == 1 and not boss.victory_riff(), "then the victory riff, the defeat's own (%s)" % [riff])
	else:
		check(riff.is_empty() and not boss.victory_riff(), "with victory_riff_on off it ends in silence")
	# The screens go on dying outward until every one in the world is dark.
	await _run(world, null, 12.0, func() -> bool: return d.blackout_radius >= t.blackout_reach, func() -> void:
		(rec["radius"] as Array).append(d.blackout_radius))
	var radius: Array = rec["radius"]
	var grows: bool = radius.size() > 2
	for i: int in range(1, radius.size()):
		grows = grows and float(radius[i]) >= float(radius[i - 1])
	var state: Dictionary = skin.feed_state()
	check(grows and float(radius[-1]) >= t.blackout_reach and float(state["power"]) == 0.0 and _sounds(boss, &"magnate_screens") == 1,
		"the screens glitch and go dark from him outward, until every one is dark %s" % tag)
	await sim.free_world(world)


# --- Reduced flashing --------------------------------------------------------------------------------------

## The ports, the square and the cables pulse normally and stay steady with Reduced flashing.
func _test_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var tag: String = "with Reduced flashing" if reduced else "normally"
		var pair: Array = _fight(5, 18.0, null, STAGE_2, "pounce:bait")
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var m: GoldenConvergenceMagnate = boss.magnate
		var pc: GoldenConvergencePounce = boss.pounce
		world.player.god_mode = true
		var bot := _bot(boss)
		bot.stomps = false
		var seen := {"ports": {}, "square": {}}
		await _run(world, bot, 40.0, func() -> bool: return pc.misses >= 1 or pc.stomps >= 1, func() -> void:
			if pc.stunned():
				seen["ports"][snappedf(m.port_material().emission_energy_multiplier, 0.001)] = true
			var sq: MeshInstance3D = pc._square
			if sq != null and is_instance_valid(sq) and pc._square_t > 0.7:
				seen["square"][snappedf(sq.transform.basis.x.length(), 0.0001)] = true)
		var ports: int = (seen["ports"] as Dictionary).size()
		var square: int = (seen["square"] as Dictionary).size()
		if reduced:
			check(ports == 1 and square == 1, "%s the ports and the square stay steady (%d, %d values)" % [tag, ports, square])
		else:
			check(ports > 1 and square > 1, "%s the ports and the square pulse (%d, %d values)" % [tag, ports, square])
		await sim.free_world(world)
		pair = _fight(5, 18.0, null, STAGE_2 + 1, "lash:low")
		world = pair[0]
		boss = pair[1]
		world.player.god_mode = true
		var widths := {}
		await _run(world, _bot(boss), 25.0, func() -> bool: return _events(boss, &"lash_done").size() >= 1, func() -> void:
			var l: GoldenConvergenceLash = boss.lash
			if l.stage == GoldenConvergenceLash.Stage.HOLD:
				widths[snappedf(l._cables[0].global_transform.basis.x.length(), 0.0001)] = true)
		if reduced:
			check(widths.size() == 1, "%s the whipped cable stays steady (%d widths)" % [tag, widths.size()])
		else:
			check(widths.size() > 1, "%s it crackles (%d widths)" % [tag, widths.size()])
		await sim.free_world(world)
	Settings.flashing_reduced = was
	var code: String = (load("res://scripts/bosses/golden_convergence/golden_convergence_magnate.gdshader") as Shader).code
	check(code.contains("reduced_flashing"), "his defeat's convulsions shake him less with Reduced flashing")
