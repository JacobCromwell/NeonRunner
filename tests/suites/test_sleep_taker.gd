extends TestSuite
## The Sleep Taker, the Dead Zone's boss (GDD §10; task E5c-a; its attacks' fairness in
## test_sleep_taker_attacks.gd):
## - its data: the slot holds its fight (the campaign's Dead Zone boss step plays it), its own tuning, the
##   Dead Zone's existing music, weapons capped at nothing, its sounds;
## - its build: the scene makes the fight and the nightmare, a boss's body immune to weapons with no weak
##   points and its touch out of reach, its attacks' hitboxes off until they strike, dozens of maws, the
##   colour rule, it fits the street at 3, 5 and 6 lanes, and a draw budget;
## - its arena: the Dead Zone's look with nothing hung over the street, darker than normal but never
##   pitch black, no signs, its refuges (a bridge with pads) fair and the same on every attempt; owner,
##   October 8, 2026 (task H9): twice the floor gaps it was first built with, and many side wall gaps,
##   both walls kept whole over every refuge's stretch;
## - the entrance: it rises far ahead and drifts in, heard, attacking nothing;
## - weapons: no damage, no auto-fire at it, nothing from splash, the boss bar never moves;
## - lights out: the inhale before the dark, half as bright as first built (owner, October 8, 2026) and
##   never below its own floors (every other boss keeps the framework's), the warnings, hazards, pads
##   and ceilings' glows drawn without the scene's light, and the light always comes back.

const BOSS_PATH: String = "res://data/bosses/dead_zone_boss.tres"
const LANES: Array[int] = [3, 5, 6]
## Lights out as first built (task E5c-a): the arena's light sank to this share. The owner's October 8,
## 2026 lights out is half as bright.
const FIRST_DARK_LEVEL: float = 0.45
## Lights out after the owner's October 8, 2026 change (half the first build's); October 10, 2026: "about 75
## to 100% darker than it does currently".
const OCT8_DARK_LEVEL: float = 0.225
## Wall gaps a minute in a level, at the median (test_wall_gaps measures 1.0-3.5): the arena has far more.
const LEVEL_WALL_GAPS_A_MINUTE: float = 1.7
const SOUNDS: Array[StringName] = [&"sleep_taker_rise", &"sleep_taker_shriek", &"sleep_taker_slash",
	&"sleep_taker_whisper", &"sleep_taker_hand", &"sleep_taker_inhale", &"sleep_taker_exhale"]
## The warnings among them: each must sound the same every time.
const WARNINGS: Array[StringName] = [&"sleep_taker_shriek", &"sleep_taker_whisper", &"sleep_taker_inhale"]

var sim: RunSim
var slot: BossDef
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	slot = load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	_test_data()
	if def == null:
		return
	await _test_build()
	_test_arena()
	await _test_entrance()
	await _test_weapons()
	await _test_lights_out()


# --- Helpers -------------------------------------------------------------------------------

## A fight against `p_def` in a bare world at `lanes`: [world, boss].
func _fight(p_def: BossDef, lanes: int, resume: Dictionary = {}, loadout: Loadout = null) -> Array:
	var boss := BossEncounter.create(p_def) as SleepTaker
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = p_def
	ctx.config = BossArena.base_config(p_def)
	ctx.config.lane_count = lanes
	ctx.tuning = tuning
	ctx.boss_resume = resume
	var arena: BossArena = boss.plan_arena(ctx)
	var world: RunWorld = sim.build_world(arena.layout, loadout, tuning, ctx.config)
	boss.setup(world, ctx, arena)
	return [world, boss]


## The Sleep Taker with its attack list `pattern` in every phase (and its numbers otherwise) and no
## generators, on its own arena or, with `plain`, a plain street (floor and walls only); with `refuges`
## off, no refuges (so no slash) either.
func _def_with(pattern: String, plain: bool = false, refuges: bool = true) -> BossDef:
	var out: BossDef = def.duplicate() as BossDef
	var t: SleepTakerTuning = (def.tuning as SleepTakerTuning).duplicate() as SleepTakerTuning
	t.generator_delay = 100000.0
	if pattern != "":
		t.attack_patterns = PackedStringArray([pattern, pattern, pattern])
	if not refuges:
		t.refuge_first = 100000.0
	out.tuning = t
	if plain:
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


func _events(boss: BossEncounter, event: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in boss.events:
		if e["event"] == event:
			out.append(e)
	return out


func _sounds(boss: BossEncounter, sound: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _events(boss, &"sound"):
		if e["name"] == sound:
			out.append(e)
	return out


# --- Data -----------------------------------------------------------------------------------

func _test_data() -> void:
	check(slot != null and slot.id == &"dead_zone_boss" and slot.display_name == "Sleep Taker",
		"the Dead Zone's boss slot holds the Sleep Taker")
	if slot == null:
		return
	check(slot.is_built() and slot.scene == "res://scenes/bosses/sleep_taker.tscn" and slot.preview() == null,
		"the slot holds the fight itself (E5c-b), no preview")
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var step: CampaignStep = campaign.step("dead_zone/boss") if campaign != null else null
	check(step != null and step.boss == slot and step.boss.is_built(), "the campaign's Dead Zone boss step plays it")
	if def == null:
		return
	var made: BossEncounter = BossEncounter.create(def)
	check(made is SleepTaker, "its scene makes the Sleep Taker's encounter")
	if made != null:
		made.free()
	var t := def.tuning as SleepTakerTuning
	check(t != null and t.resource_path == "res://data/bosses/dead_zone_boss_tuning.tres", "its numbers are its own tuning resource")
	check(def.phase_count() == 3 and def.phase_list()[0].intro_seconds >= 3.0, "three phases; the first's intro is its entrance")
	check(def.weapon_share_cap == 0.0, "GDD §10: weapons have no effect at all (its weapon cap is 0)")
	check(def.armor_rule and def.armor_delay_min == 15.0 and def.armor_delay_max == 17.0,
		"the standard armor rule, 15-17 s after a break")
	# No new music (owner, September 28, 2026): the Dead Zone's own track.
	var music := load("res://data/audio/music_library.tres") as MusicLibrary
	check(def.music == &"dead_zone" and music.has(def.music), "its music is the Dead Zone's existing track")
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in SOUNDS:
		check(sfx.names().has(String(sound)) and sfx.stream(sound) != null, "its sound %s exists" % sound)
	for warning: StringName in WARNINGS:
		check(float(sfx.pitch_variation.get(String(warning), 0.0)) == 0.0, "warning %s sounds the same every time" % warning)
	var shriek: float = sfx.stream(&"sleep_taker_shriek").get_length()
	check(shriek >= 0.6 and shriek <= t.slash_warning(), "the shriek fits in the slash's warning (%.2f s)" % shriek)
	var whisper: float = sfx.stream(&"sleep_taker_whisper").get_length()
	check(whisper >= 0.6 and whisper <= t.mist_seconds + t.hand_rise_lead, "the whispering fits in the mist's warning (%.2f s)" % whisper)
	var inhale: float = sfx.stream(&"sleep_taker_inhale").get_length()
	check(inhale >= t.inhale_seconds * 0.8 and inhale <= t.inhale_seconds + t.dim_seconds,
		"the inhale lasts its warning (%.2f s)" % inhale)
	# Every list names only attacks it knows; the slash comes at the refuges instead.
	var known: bool = true
	for i: int in t.attack_patterns.size():
		for kind: String in t.pattern_for(i):
			known = known and SleepTaker.KINDS.has(kind)
	check(known and t.attack_patterns.size() == 3, "each phase lists only hands and lights out")
	var hints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: PackedStringArray = []
	for h: Dictionary in hints["hints"]:
		triggers.append(String(h["trigger"]))
	for key: String in ["enemy:dead_zone_boss", "boss:dead_zone_boss/hands", "boss:dead_zone_boss/lights_out",
			"boss:dead_zone_boss/refuge"]:
		check(triggers.has(key), "its first-time hint %s exists (item 39: weapons can't hurt it)" % key)


# --- The build ------------------------------------------------------------------------------

func _test_build() -> void:
	for lanes: int in LANES:
		var pair: Array = _fight(def, lanes)
		var world: RunWorld = pair[0]
		var boss: SleepTaker = pair[1]
		var tag: String = "(%d lanes)" % lanes
		var body: SleepTakerBody = boss.body
		check(body is SleepTakerBody and boss.parts == [body], "the scene makes the fight and the nightmare %s" % tag)
		check(body.is_boss and body.claw_immune and not body.dash_kills and not body.stompable and body.shares_health,
			"a boss's body: claws never, the dash passes, no stomps %s" % tag)
		check(body.immune_to_weapons and not body.targetable(), "immune to weapons: auto-fire never picks it %s" % tag)
		check(body.weak_points.is_empty(), "no weak points: only the EMP will hurt it %s" % tag)
		# Its touch: an enemy attack inside its body, far out of reach.
		var core: Hazard = body.core_hitbox()
		check(core.is_enemy_attack and core.is_active(), "its touch is an enemy attack %s" % tag)
		boss.pose = boss.hover_pose()
		boss._place()
		var lunge_front: float = boss.tuning.lunge_gap + body.claw_reach() - core.size.z * 0.5
		check(lunge_front > 3.0, "lunging, its touch stays %.1f m in front of the runner %s" % [lunge_front, tag])
		check(not boss.slash.hitbox().is_active() and boss.slash.hitbox().is_enemy_attack,
			"its slash's hitbox is an enemy attack, off until it strikes %s" % tag)
		var hands_off: bool = true
		for h: Hazard in boss.hands.hazards():
			hands_off = hands_off and h.is_enemy_attack and not h.is_active()
		var pool: int = boss.tuning.pool_hands(lanes)
		check(hands_off and boss.hands.hazards().size() == pool and boss.hands.pool_size() == pool
			and pool == boss.tuning.max_hands(lanes) + boss.tuning.row_hands(lanes),
			"its hands' hitboxes are enemy attacks, off until one rises: a pool of %d, a whole round's and a row more %s" % [pool, tag])
		# It fits the street it looms over.
		var widest: float = 0.0
		var tallest: float = 0.0
		for node: Node in body.find_children("*", "MeshInstance3D", true, false):
			var m := node as MeshInstance3D
			var box: AABB = m.global_transform * m.get_aabb()
			widest = maxf(widest, maxf(absf(box.position.x - body.position.x), absf(box.end.x - body.position.x)))
			tallest = maxf(tallest, box.end.y)
		check(widest < world.geo.wall_x() + 0.2, "the nightmare fits between the walls (%.2f m of %.2f) %s" % [widest, world.geo.wall_x(), tag])
		check(tallest >= 9.0, "a colossal nightmare: %.1f m tall %s" % [tallest, tag])
		# Low-poly and merged: a few draw calls and vertices for dozens of maws and fingers.
		var stats: Dictionary = body.draw_stats()
		check(int(stats["instances"]) <= 4 and int(stats["surfaces"]) <= 2 and int(stats["vertices"]) <= 16000,
			"a nightmare within budget: %d draws, %d surfaces, %d vertices %s" % [stats["instances"], stats["surfaces"],
			stats["vertices"], tag])
		if lanes == 5:
			var hand_verts: int = (SleepTakerModel.hand_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			print("  Sleep Taker (5 lanes): %d draws, %d surfaces, %d vertices; a hand %d vertices" % [stats["instances"],
				stats["surfaces"], stats["vertices"], hand_verts])
			check(hand_verts <= 2000, "a hand within budget (%d vertices)" % hand_verts)
		await sim.free_world(world)
	check(SleepTakerModel.maw_centres().size() >= 24, "GDD §10: dozens of circular maws (%d)" % SleepTakerModel.maw_centres().size())
	_check_colours()


## The colour rule (GDD §5, CLAUDE.md): only hazards glow in hazard colours. The nightmare is black with
## the Bad Dream's purple, leaning violet away from the fences' pink; red glows only in an attack (its
## shader heats the claws and the great maw's throat), never in its vertex colours.
func _check_colours() -> void:
	var loud: PackedStringArray = []
	for pair: Array in [["body", SleepTakerModel.liquid_mesh()], ["hand", SleepTakerModel.hand_mesh()]]:
		var mesh: ArrayMesh = pair[1]
		for s: int in mesh.get_surface_count():
			for c: Color in mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]:
				if c.a > 0.0 and c.s > 0.3 and (c.h < 0.62 or c.h > 0.8) and loud.size() < 3:
					loud.append("%s %s" % [pair[0], c])
	check(loud.is_empty(), "nothing on the nightmare glows in a hazard colour: %s" % ", ".join(loud))
	var pink: Color = load("res://scripts/enemies/cyborg_kit.gd").FENCE_PINK
	for c: Color in [SleepTakerModel.PURPLE, SleepTakerModel.MIST_COLOR, SleepTakerModel.HIGHLIGHT, SleepTakerModel.THROAT]:
		check(c.h > 0.62 and c.h < 0.8 and absf(c.h - pink.h) > 0.1,
			"its purple %s stays violet, away from the fences' pink (hue %.2f vs %.2f)" % [c, c.h, pink.h])


# --- The arena ------------------------------------------------------------------------------

func _test_arena() -> void:
	var t := def.tuning as SleepTakerTuning
	check(def.arena != null and def.arena.skin is DeadZoneSkin, "its arena has the Dead Zone's look")
	var skin := def.arena.skin as DeadZoneSkin
	check(skin.skybridge_share == 0.0 and skin.feed_tower_share == 0.0,
		"nothing hangs over its street, where the nightmare looms (no skybridges, no hung screens)")
	check(def.arena.darkness > 0.0 and ZoneSkin.scenery_light_for(def.arena.darkness) >= ZoneSkin.MIN_SCENERY_LIGHT,
		"GDD §10: its arena is darker than normal (darkness %.2f), never pitch black" % def.arena.darkness)
	check(not def.arena.features.has("ceilings") and not def.arena.features.has("cyborg"),
		"its arena: the Dead Zone's street with its holes and fences, its own refuges, no enemies")
	# Owner, October 8, 2026: its side walls have many gaps (the arena opts in with numbers of its own).
	check(def.arena.features.has(WallGapPlacement.FEATURE) and def.arena.wall_gap_tuning != null
		and BossArena.base_config(def).has_feature(WallGapPlacement.FEATURE)
		and def.arena.wall_gap_tuning.spacing_seconds_easy < WallGapPlacement.tuning().spacing_seconds_hard * 0.25,
		"its arena opts into side wall gaps, with numbers of its own: far more often than a level's")
	# As first built: no extra floor gaps and no wall gaps.
	var first: BossDef = def.duplicate() as BossDef
	var first_tuning: SleepTakerTuning = t.duplicate() as SleepTakerTuning
	first_tuning.floor_gap_increase = 0.0
	first.tuning = first_tuning
	var first_arena: LevelConfig = def.arena.duplicate() as LevelConfig
	first_arena.wall_gap_tuning = null
	first.arena = first_arena
	for lanes: int in LANES:
		var config: LevelConfig = BossArena.base_config(def)
		config.lane_count = lanes
		var boss := BossEncounter.create(def) as SleepTaker
		var again := BossEncounter.create(def) as SleepTaker
		# As plan_arena() does: the encounter shapes each lap with its own def's numbers.
		boss.def = def
		again.def = def
		var a: BossArena = BossArena.plan(def, config, tuning, boss)
		var b: BossArena = BossArena.plan(def, config, tuning, again)
		again.free()
		var was: SleepTaker = BossEncounter.create(first) as SleepTaker
		was.def = first
		var first_config: LevelConfig = BossArena.base_config(first)
		first_config.lane_count = lanes
		var before: BossArena = BossArena.plan(first, first_config, tuning, was)
		was.free()
		_check_floor_gaps(before, a, lanes)
		_check_wall_gaps(boss, a, lanes)
		var tag: String = "(%d lanes)" % lanes
		check(var_to_str(a.layout.to_dict()) == var_to_str(b.layout.to_dict()), "its arena is the same on every attempt %s" % tag)
		var v: float = tuning.run_speed
		var span: Vector2 = SleepTaker.refuge_clear_span(t, tuning, v)
		var zones: CeilingZones = CeilingZones.make(config, tuning)
		var pad_lanes: Array[int] = SleepTaker.pad_lanes(lanes, t)
		var refuges: int = 0
		var fair: bool = true
		var pieces: int = 0
		var signs: int = 0
		for i: int in a.laps.size():
			var lap: LevelLayout = a.laps[i]
			signs += lap.signs.size()
			pieces += lap.gaps.size() + lap.fences.size()
			LayoutChecks.check_layout(self, lap, config, "(Sleep Taker arena, %d lanes)" % lanes)
			for r: Dictionary in boss._refuge_plan[i]:
				refuges += 1
				var pad: float = float(r["pad"])
				var hull_ok: bool = false
				for h: Dictionary in lap.hulls:
					hull_ok = hull_ok or (float(h["start"]) <= pad and float(h["end"]) >= float(r["end"]) - 0.01 and lap.hull_width(h) == lanes)
				var pads_ok: int = 0
				for p: Dictionary in lap.pads:
					if is_equal_approx(float(p["at"]), pad) and pad_lanes.has(int(p["lane"])):
						pads_ok += 1
				var clear_ok: bool = true
				for l: int in lanes:
					clear_ok = clear_ok and not lap.gapped_between(l, pad + span.x, pad + span.y)
					for f: Dictionary in lap.fences:
						if int(f["lane"]) == l and float(f["at"]) >= pad + span.x and float(f["at"]) <= pad + span.y:
							clear_ok = false
				var landing: Vector2 = zones.landing_zone({"start": pad - config.hull_lead_in, "end": float(r["end"])})
				fair = fair and hull_ok and pads_ok == pad_lanes.size() and clear_ok and zones.landing_clear(lap, landing)
		check(refuges >= a.laps.size() * 3, "each lap has its refuges (%d) %s" % [refuges, tag])
		check(fair, "every refuge: a bridge across the street, pads in the middle, clear where its slash warns and its riders land %s" % tag)
		check(signs == 0 and pieces > 0, "its walls carry no signs; its laps keep the street's holes and fences %s" % tag)
		check(a.layout.enemies.is_empty() and a.layout.credits.is_empty(), "no enemies and no credits on its track %s" % tag)
		boss.free()


## Owner, October 8, 2026: twice the floor gaps the arena was first built with (`before`), over its laps
## (rows: holes sharing a stretch; lane-gaps: one lane's hole), each new row leaving an open lane.
func _check_floor_gaps(before: BossArena, after: BossArena, lanes: int) -> void:
	var tag: String = "(%d lanes)" % lanes
	var rows := Vector2i.ZERO
	var lane_gaps := Vector2i.ZERO
	var open: bool = true
	for i: int in after.laps.size():
		rows += Vector2i(GapDensity.rows(before.laps[i]).size(), GapDensity.rows(after.laps[i]).size())
		lane_gaps += Vector2i(before.laps[i].gaps.size(), after.laps[i].gaps.size())
		for row: Dictionary in GapDensity.rows(after.laps[i]):
			open = open and (row["lanes"] as Array).size() < lanes
	check(rows.x > 0 and rows.y >= 2 * rows.x and lane_gaps.y >= roundi(1.9 * lane_gaps.x),
		"twice the floor gaps it was first built with: %d rows of holes (%d first), %d lane-gaps (%d first) %s" % [
		rows.y, rows.x, lane_gaps.y, lane_gaps.x, tag])
	check(open, "every row of holes leaves an open lane %s" % tag)
	if lanes == 5:
		print("  Sleep Taker's arena (5 lanes, 3 laps): %d rows of holes, %d lane-gaps (first built: %d, %d)" % [rows.y,
			lane_gaps.y, rows.x, lane_gaps.x])


## Owner, October 8, 2026: many side wall gaps on its arena (far more than a level's), each as long as its
## numbers say, none along a refuge's bridge, where its slash strikes (SleepTaker.refuge_wall_span), and
## its laps keep them as they join the track. October 10, 2026: more again, and the slash's approach (where
## its warning finds the runner) no longer kept whole, so the wall isn't always there to take as it warns.
func _check_wall_gaps(boss: SleepTaker, a: BossArena, lanes: int) -> void:
	var tag: String = "(%d lanes)" % lanes
	var t := def.tuning as SleepTakerTuning
	var gaps: WallGapTuning = def.arena.wall_gap_tuning
	var count: int = 0
	var sides := {-1: 0, 1: 0}
	var sized: bool = true
	var whole: bool = true
	var approaches: int = 0
	var approach_gaps: int = 0
	for i: int in a.laps.size():
		var lap: LevelLayout = a.laps[i]
		for g: Dictionary in lap.wall_gaps:
			count += 1
			sides[int(g["side"])] = int(sides[int(g["side"])]) + 1
			var secs: float = (float(g["end"]) - float(g["start"])) / tuning.run_speed
			sized = sized and secs >= gaps.length_seconds_min - 0.01 and secs <= gaps.length_seconds_max + 0.01
		for r: Dictionary in boss._refuge_plan[i]:
			var pad: float = float(r["pad"])
			var span: Vector2 = SleepTaker.refuge_wall_span(t, a, pad)
			whole = whole and not lap.wall_gap_between(span.x, span.y)
			var v: float = a.tuning.run_speed
			var warn: float = pad + v * t.strike_after_pad - v * t.slash_warning()
			whole = whole and span.x <= pad - a.config.hull_lead_in and span.y >= pad + v * (t.strike_after_pad + t.slash_active)
			approaches += 1
			approach_gaps += 1 if lap.wall_gap_between(warn, span.x) else 0
	var minutes: float = a.laps.size() * a.lap_length / tuning.run_speed / 60.0
	var a_minute: float = count / minutes
	check(a_minute >= LEVEL_WALL_GAPS_A_MINUTE * 4.0 and int(sides[-1]) > 0 and int(sides[1]) > 0,
		"many side wall gaps, on both walls: %.1f a minute (a level's median: %.1f) %s" % [a_minute, LEVEL_WALL_GAPS_A_MINUTE, tag])
	check(sized, "each wall gap lasts %.1f-%.1f s %s" % [gaps.length_seconds_min, gaps.length_seconds_max, tag])
	check(whole, "both walls stay whole along each refuge's bridge, where its slash strikes %s" % tag)
	check(approach_gaps > 0, "the walls are open as some slashes warn (%d of %d refuges' approaches) %s" % [approach_gaps,
		approaches, tag])
	var later: LevelLayout = a.lap(a.laps.size() + 1)
	var source: LevelLayout = a.laps[1 % a.laps.size()]
	var moved: bool = later.wall_gaps.size() == source.wall_gaps.size() and not later.wall_gaps.is_empty()
	for k: int in mini(later.wall_gaps.size(), source.wall_gaps.size()):
		moved = moved and is_equal_approx(float(later.wall_gaps[k]["start"]),
			float(source.wall_gaps[k]["start"]) + a.lap_length * (a.laps.size() + 1))
	check(moved, "a lap that joins the track later keeps its wall gaps %s" % tag)
	if lanes == 5:
		print("  Sleep Taker's arena (5 lanes, 3 laps): %d wall gaps, %.1f a minute" % [count, a_minute])


# --- The entrance ---------------------------------------------------------------------------

func _test_entrance() -> void:
	var pair: Array = _fight(_def_with("", true), 5)
	var world: RunWorld = pair[0]
	var boss: SleepTaker = pair[1]
	world.player.god_mode = true
	check(boss.step == SleepTaker.Step.ENTER and boss.pose.y < -1.0 and boss.pose.z > boss.tuning.hover_ahead,
		"its entrance starts sunk below the street far ahead (%.1f m ahead, %.1f m down)" % [boss.pose.z, -boss.pose.y])
	check(boss.body.fade > 0.9, "it isn't there yet: it materializes as it rises")
	check(_sounds(boss, &"sleep_taker_rise").size() == 1, "its rise is heard")
	var attacked: bool = false
	await _until(world, func() -> bool:
		attacked = attacked or boss.attack_on() or boss.slash.busy() or boss.dark.is_dark()
		return boss.state == BossEncounter.State.FIGHT, 8.0)
	check(boss.state == BossEncounter.State.FIGHT and not attacked, "it attacks nothing during its entrance")
	check(is_zero_approx(boss.body.fade) and absf(boss.pose.z - boss.tuning.hover_ahead) < 0.5 and absf(boss.pose.y) < 0.01,
		"then it looms %.1f m ahead, whole" % boss.pose.z)
	await sim.free_world(world)
	# A retry resuming at a later phase: it's already there.
	pair = _fight(def, 5, {"phase": 1})
	world = pair[0]
	boss = pair[1]
	check(boss.step == SleepTaker.Step.REFORM and is_zero_approx(boss.body.fade) and _sounds(boss, &"sleep_taker_rise").is_empty(),
		"resuming at a later phase, there's no entrance")
	await sim.free_world(world)


# --- Weapons ----------------------------------------------------------------------------------

func _test_weapons() -> void:
	var loadout := Loadout.new()
	var pair: Array = _fight(_def_with("hands", true), 5, {}, loadout)
	var world: RunWorld = pair[0]
	var boss: SleepTaker = pair[1]
	world.player.god_mode = true
	await _until(world, func() -> bool: return boss.state == BossEncounter.State.FIGHT, 8.0)
	var body: SleepTakerBody = boss.body
	var full: float = boss.health
	body.take_damage(50.0, &"weapon")
	body.take_damage(50.0, &"weapon", true)
	check(is_equal_approx(boss.health, full) and is_zero_approx(boss.weapon_damage), "weapon hits never hurt it, direct or splash")
	check(boss.damage(50.0, &"weapon") == 0.0 and not boss.weapons_can_hurt(), "the fight takes no weapon damage (cap 0)")
	check(not body.targetable(), "auto-fire never targets it, even while it can be hurt")
	var offered: bool = false
	for e: Enemy in world.director.targets_ahead(world.player.position + Vector3(0.0, 1.0, 0.0), 300.0):
		offered = offered or e == body
	check(not offered, "the weapons' target list never offers it (R2's rule for hosts)")
	# Shots fired straight at it, and homing heavy missiles with splash: they pass through.
	var fired: Array = [0]
	world.projectiles.enemy_hit.connect(func(enemy: Enemy, _dmg: float, _splash: bool) -> void:
		if enemy == body:
			fired[0] += 1)
	var shots: int = 0
	for i: int in 240:
		if i % 20 == 0:
			var from: Vector3 = world.player.position + Vector3(0.0, 1.0, 0.0)
			var homing: bool = i % 40 == 0
			var shot: Projectile = world.projectiles.fire_player(from, (body.aim_point() - from).normalized() * 60.0, 10.0,
				&"missile" if homing else &"laser", body if homing else null, 6.0 if homing else 0.0, 3.0 if homing else 0.0,
				0.5, 1.0, 2.0)
			if shot != null:
				shots += 1
		await tree.physics_frame
	check(shots > 0 and fired[0] == 0 and is_equal_approx(boss.health, full) and is_zero_approx(boss.weapon_damage),
		"shots and missiles fired straight at it pass through: %d shots, %d hits, health %.0f of %.0f" % [shots, fired[0],
		boss.health, full])
	check(boss.health_ratio() == 1.0, "its boss bar never moves")
	await sim.free_world(world)


# --- Lights out -------------------------------------------------------------------------------

func _test_lights_out() -> void:
	var t := def.tuning as SleepTakerTuning
	# Owner, October 8, 2026: everything lit gets 50% darker than the first build's lights out; October 10,
	# 2026: 75 to 100% darker again, a dark tunnel where only the glows show.
	check(t.dark_level <= OCT8_DARK_LEVEL * 0.25 + 0.0001 and OCT8_DARK_LEVEL * 2.0 == FIRST_DARK_LEVEL,
		"lights out sinks to %.4f of the arena's light: at least 75%% darker than October 8's %.3f (first %.2f)" % [
		t.dark_level, OCT8_DARK_LEVEL, FIRST_DARK_LEVEL])
	check(t.light_floor <= t.dark_level and t.scenery_floor < ZoneSkin.MIN_SCENERY_LIGHT,
		"its own floors, below every other boss's (light %.3f, scenery %.3f)" % [t.light_floor, t.scenery_floor])
	var plain := BossEncounter.new()
	check(is_equal_approx(plain.light_floor(), BossEncounter.MIN_LIGHT_LEVEL)
		and is_equal_approx(plain.scenery_floor(), ZoneSkin.MIN_SCENERY_LIGHT),
		"every other boss keeps the framework's floors (%.1f): only the Sleep Taker's data lowers its own" % BossEncounter.MIN_LIGHT_LEVEL)
	plain.free()
	# The arena's own light, as its run sets it (LevelConfig.darkness; a bare test world has no level to
	# set it).
	var base: float = ZoneSkin.scenery_light_for(def.arena.darkness)
	ZoneSkin.set_scenery_light(base)
	var pair: Array = _fight(_def_with("lights_out", true, false), 5)
	var world: RunWorld = pair[0]
	var boss: SleepTaker = pair[1]
	world.player.god_mode = true
	await _until(world, func() -> bool: return not _events(boss, &"inhale").is_empty(), 12.0)
	var inhale: Array[Dictionary] = _events(boss, &"inhale")
	check(inhale.size() == 1 and _sounds(boss, &"sleep_taker_inhale").size() == 1 and boss.body.inhale > 0.5,
		"the warning: a deep inhale, heard and seen (its maws gape)")
	check(is_equal_approx(boss.light_level(), 1.0), "the light is still whole while it inhales")
	check(is_zero_approx(world.player.dark_glow()), "the runner glows only by its trim in the arena's own light")
	await _until(world, func() -> bool: return not _events(boss, &"dark").is_empty(), 4.0)
	var dark: Array[Dictionary] = _events(boss, &"dark")
	check(dark.size() == 1 and float(dark[0]["t"]) - float(inhale[0]["t"]) >= t.inhale_seconds - 0.05,
		"the light goes only after the inhale (%.2f s)" % (float(dark[0]["t"]) - float(inhale[0]["t"]) if not dark.is_empty() else -1.0))
	await _until(world, func() -> bool: return boss.dark.stage == SleepTakerLightsOut.Stage.DARK, 3.0)
	await _until(world, func() -> bool: return boss.light_level() <= t.dark_level + 0.001, 2.0)
	var lowest: float = boss.light_level()
	check(is_equal_approx(lowest, maxf(t.dark_level, t.light_floor)),
		"at its darkest the light (ambient, sky, fog, sun) is %.4f of the arena's (October 8's %.3f)" % [lowest, OCT8_DARK_LEVEL])
	# The scenery: October 8's lights out left it at max(base × 0.225, its floor then, 0.15).
	var oct8_scenery: float = maxf(base * OCT8_DARK_LEVEL, minf(base, 0.15))
	check(is_equal_approx(ZoneSkin.scenery_light_now, maxf(base * t.dark_level, minf(base, t.scenery_floor)))
		and ZoneSkin.scenery_light_now <= oct8_scenery * 0.25 + 0.0001,
		"the street and the ruins darken with it to %.4f of the zone's light, at least 75%% darker than October 8's %.3f (its floor %.3f)" % [
		ZoneSkin.scenery_light_now, oct8_scenery, t.scenery_floor])
	# Owner, October 10, 2026: the runner glows so they still see where they are.
	check(is_equal_approx(world.player.dark_glow(), t.runner_glow) and t.runner_glow > 0.0,
		"at its darkest the runner glows by its own light (%.2f)" % world.player.dark_glow())
	check(boss.body.swallowed > 0.5, "the swallowed light glows in its throats")
	# The light always comes back.
	await _until(world, func() -> bool: return boss.dark.idle(), t.dark_seconds + t.return_seconds + 2.0)
	check(is_equal_approx(boss.light_level(), 1.0) and _sounds(boss, &"sleep_taker_exhale").size() == 1
		and is_equal_approx(ZoneSkin.scenery_light_now, base), "after the dark it breathes out and the light comes back whole")
	check(is_zero_approx(world.player.dark_glow()), "and the runner's own glow goes with the dark")
	# ... at once on a phase change, and with the defeat.
	await _until(world, func() -> bool: return boss.dark.stage == SleepTakerLightsOut.Stage.DARK, 14.0)
	boss.damage(boss.hit_damage(), &"emp")
	check(boss.phase_index == 1 and boss.dark.idle(), "a phase change ends the dark")
	await _until(world, func() -> bool: return is_equal_approx(boss.light_level(), 1.0), t.return_seconds + 0.5)
	check(is_equal_approx(boss.light_level(), 1.0), "and the light comes back")
	await _until(world, func() -> bool: return boss.state == BossEncounter.State.FIGHT and boss.dark.stage == SleepTakerLightsOut.Stage.DARK, 20.0)
	boss.damage(boss.hit_damage(), &"emp")
	await _until(world, func() -> bool: return boss.state == BossEncounter.State.FIGHT and boss.dark.stage == SleepTakerLightsOut.Stage.DARK, 20.0)
	boss.damage(boss.hit_damage(), &"emp")
	check(boss.is_defeated() and boss.dark.idle(), "beaten, its dark ends")
	await _until(world, func() -> bool: return is_equal_approx(boss.light_level(), 1.0), t.return_seconds + 0.5)
	check(is_equal_approx(boss.light_level(), 1.0), "and the light comes back with the win")
	await tree.physics_frame
	check(is_zero_approx(world.player.dark_glow()), "and the runner's own glow with it")
	await sim.free_world(world)
	# As a run ends: the zone's own light again, for the suites after this one.
	ZoneSkin.set_scenery_light(1.0)
	_check_readable_in_the_dark()


## Measured on screen by tools/showcase/sleep_taker_showcase.gd --scenario=measure (headless runs draw
## nothing): here, what makes it hold: every warning, hazard, trigger and ceiling end band the fight
## shows is drawn without the scene's light (unshaded, or its brightness from its emission), so dimming
## the ambient light, the sky and the sun leaves it as bright as before.
func _check_readable_in_the_dark() -> void:
	var lit: PackedStringArray = []
	var mark := BadDreamModel.mark_material()
	var arc := BadDreamModel.arc_material()
	for pair: Array in [["slash marks", mark], ["claw streaks", arc], ["mist", SleepTakerModel.mist_material(0.0)]]:
		var code: String = ((pair[1] as ShaderMaterial).shader as Shader).code
		if not code.contains("unshaded"):
			lit.append(pair[0])
	var warning: StandardMaterial3D = GreyboxMaterials.glow(BossProps.WARNING_COLOR, 2.6, 0.75)
	if warning.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		lit.append("red floor warnings")
	check(lit.is_empty(), "every attack warning is drawn without the scene's light: %s" % ", ".join(lit))
	# The hands' and the body's attack heat is emission, independent of the light.
	for path: String in [SleepTakerModel.LIQUID_SHADER, SleepTakerModel.HAND_SHADER]:
		var code: String = (load(path) as Shader).code
		check(code.contains("EMISSION") and code.contains("attack_color"), "its attack heat glows by itself (%s)" % path.get_file())
