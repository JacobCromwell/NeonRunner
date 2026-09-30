extends TestSuite
## The Resonator (GDD §9.10) in full RunWorlds on real physics: the warning (the halos lining up and the
## chime) always before the wave, for the whole warning time; a runner who jumps each wave survives at
## 3, 5 and 6 lanes and one who stands still (or slides) is hit, with the jump's margin measured; walls
## and the ceiling are safe; armor and the shield block a wave (one armor covers a double) and the dash
## passes through it; weapons kill it and it can't be stomped; it takes turns with the other big attacks
## and still pulses; its model, sounds and Reduced flashing; its generator rules, and on the real
## campaign layouts of Golden 1-3 at 3, 5 and 6 lanes no wave meets the runner on a gap or a fence, big
## attacks never overlap, and every attempt plays out the same way.

const Rules = preload("res://scripts/enemies/resonator_rules.gd")
const AttackWatch = preload("res://tools/measure/attack_watch.gd")
const TURN_DUMMY: String = "res://tests/helpers/turn_dummy.gd"
const WAVE_NAME: String = "Resonator's wave"

var sim: RunSim
var t: ResonatorTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = EnemyDirector.tuning_for("resonator") as ResonatorTuning
	check(t != null, "data/enemies/resonator.tres is a ResonatorTuning")
	if t == null:
		return
	_test_numbers()
	_test_model()
	_test_sounds_and_hint()
	await _test_warning_then_wave()
	await _test_jump_and_stand()
	await _test_walls_and_ceiling()
	await _test_protection()
	await _test_weapons_and_stomp()
	await _test_takes_turns()
	await _test_reduced_flashing()
	_test_generator()
	await _test_campaign()


# --- Helpers ------------------------------------------------------------------------------------

func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k == "armor":
			l.armor = true
		elif k in ["shield", "grapple", "revive"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


## A world with the player in `player_lane` (running) and one Resonator placed at `at`.
func _world(lanes: int, player_lane: int, params: Dictionary = {}, loadout: Loadout = null, at: float = 60.0,
		layout: LevelLayout = null, config: LevelConfig = null) -> Array:
	var w: RunWorld = sim.build_world(layout if layout != null else RunSim.layout(lanes, 900.0), loadout, null, config)
	w.player.setup(tuning, w.geo, player_lane)
	var p: Dictionary = {"pulses": 1}
	p.merge(params, true)
	var r := w.director.spawn({"type": "resonator", "at": at, "lane": lanes / 2, "side": 0, "seed": 5,
		"params": p}) as Resonator
	await tree.physics_frame
	w.player.running = true
	return [w, r]


## Steps physics frames until `cond` is true (true) or `seconds` pass (false).
func _until(cond: Callable, seconds: float) -> bool:
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if cond.call():
			return true
		await tree.physics_frame
	return cond.call()


func _res(id: int) -> Resonator:
	var o: Object = instance_from_id(id)
	return o as Resonator if is_instance_valid(o) else null


## Seconds until the nearest wave on its way reaches the front of the player's hitbox (INF if none).
func _arrival_in(w: RunWorld, r: Resonator) -> float:
	var best: float = INF
	if r == null or not is_instance_valid(r):
		return best
	for wave: Resonator.Wave in r.wave_list():
		if not wave.on_its_way():
			continue
		var gap: float = (wave.d - t.wave_depth * 0.5) - (w.player.distance + tuning.hurtbox_size.z * 0.5)
		best = minf(best, gap / maxf(wave.speed + w.player.speed, 1.0))
	return best


## True once the Resonator has no pulse left to come and no wave on its way (or it's gone).
func _done(id: int) -> bool:
	var r: Resonator = _res(id)
	return r == null or not r.alive or r.state == Resonator.State.LEAVE


func _count(r: Resonator, event: String) -> int:
	var n: int = 0
	for h: Array in r.history:
		n += 1 if h[0] == event else 0
	return n


# --- Numbers --------------------------------------------------------------------------------------

## The tuning's shape (GDD §9.10, and the placeholders' own promises): it scales across the Golden Zone
## (pulses faster, double waves, faster waves later), a jump clears the wave with a margin, a double's
## second wave comes inside the invulnerability window, the hitbox covers every lane and stays clear of
## a wall runner (the visible wave too), and it hovers within the weapon's reach.
func _test_numbers() -> void:
	check(t.health_at(1.0) == 15.0 and t.score_value > 0 and not t.uses_floor,
		"15 laser tier 1 shots, a score, and it never uses the floor (%.0f)" % t.health_at(1.0))
	var golden_1: float = 12.0 / 14.0
	check(t.zone_t(golden_1) < 0.1 and is_equal_approx(t.zone_t(1.0), 1.0) and t.zone_t(0.0) == 0.0,
		"its early numbers are Golden 1's and its late ones Golden 3's (zone_t %.2f at Golden 1)" % t.zone_t(golden_1))
	check(t.pulse_rest_at(1.0) < t.pulse_rest_at(golden_1) and t.wave_speed_at(1.0) > t.wave_speed_at(golden_1)
		and t.double_share_at(1.0) > t.double_share_at(golden_1) and t.double_share_at(golden_1) < 0.1,
		"later in the zone it pulses faster, its waves roll faster and some pulses are double (GDD §9.10)")
	check(t.pulses_at(golden_1) >= 2 and t.pulses_at(1.0) >= t.pulses_at(golden_1), "a few pulses a visit (%d to %d)"
		% [t.pulses_at(golden_1), t.pulses_at(1.0)])
	# A jump from the floor: the feet stay above the wave's band from t1 to t2.
	var g_up: float = tuning.gravity()
	var g_down: float = g_up * tuning.fall_gravity_multiplier
	var v0: float = tuning.jump_velocity()
	var t_apex: float = v0 / g_up
	var t1: float = (v0 - sqrt(v0 * v0 - 2.0 * g_up * t.wave_height)) / g_up
	var t2: float = t_apex + sqrt(2.0 * (tuning.jump_height - t.wave_height) / g_down)
	var air: float = t_apex + sqrt(2.0 * tuning.jump_height / g_down)
	check(t2 - t1 > 0.45, "a jump's feet stay above the wave's band for %.2f s of its %.2f s in the air" % [t2 - t1, air])
	check(tuning.jump_height > t.wave_height * 3.0, "the jump rises far above it (%.2f m over a %.2f m band)"
		% [tuning.jump_height, t.wave_height])
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	check(t.double_gap < rules.hit_invulnerability and t.double_gap > air,
		"a double's waves come %.2f s apart: after a jump has landed (%.2f s) and inside the invulnerability window (%.2f s)"
		% [t.double_gap, air, rules.hit_invulnerability])
	check(Resonator.CREST_HEIGHT_SCALE > 1.0 and Resonator.CREST_DEPTH_SCALE > 1.0,
		"the wave looks a little bigger than its hitbox (GDD §3)")
	for lanes: int in [3, 5, 6]:
		var geo := TrackGeometry.new(lanes, tuning)
		var half: float = t.band_half_width(lanes, tuning)
		var outer_body: float = geo.lane_x(lanes - 1) + tuning.hurtbox_size.x * 0.5
		var wall_body: float = ResonatorTuning.wall_body_reach(lanes, tuning)
		var visual_end: float = minf(half + Resonator.CREST_END_TAPER, wall_body - Resonator.CREST_WALL_CLEARANCE)
		check(half > geo.lane_x(lanes - 1) and half < outer_body,
			"%d lanes: the band reaches past the outer lanes' middles (%.2f m of %.2f) over most of a runner there" % [lanes, half, geo.lane_x(lanes - 1)])
		check(half < wall_body - 0.2 and visual_end < wall_body,
			"%d lanes: the band (%.2f m) and the visible wave (%.2f m) stop short of a wall runner's body (%.2f m)"
			% [lanes, half, visual_end, wall_body])
	var powerups := load("res://data/tuning/powerups.tres") as PowerupTuning
	check(t.hover_ahead < powerups.weapon_range - 5.0, "it hovers within the weapon's reach (%.0f of %.0f m)"
		% [t.hover_ahead, powerups.weapon_range])
	var top: float = t.hover_height + ResonatorModel.TOP_Y * t.model_scale
	var bottom: float = t.hover_height + ResonatorModel.BOTTOM_Y * t.model_scale
	var halo: float = (ResonatorModel.HALO_RADII[-1] + ResonatorModel.HALO_WIDTH * 0.5) * t.model_scale
	check(top < tuning.ceiling_height - 0.1 and t.hover_height - halo > 0.3,
		"its spire stays under the ceiling (top %.2f m) and its halos off the floor (lowest %.2f m)" % [top, t.hover_height - halo])
	check(t.hover_height > tuning.jump_height + tuning.hurtbox_size.y and bottom > 0.3,
		"its core hovers above a jumping runner's head (%.2f m over %.2f m)" % [t.hover_height, tuning.jump_height + tuning.hurtbox_size.y])


# --- Model, sounds, hint ------------------------------------------------------------------------------

## Low-poly and cheap on every renderer; red glows only (the core, and the halos' and emitter's trims in
## the warning), gold and ivory everywhere else; the halos turn to face the runner when lined up.
func _test_model() -> void:
	var m := ResonatorModel.new()
	tree.root.add_child(m)
	m.build()
	check(m.draw_call_count() == 4, "the model is 4 draw calls (%d)" % m.draw_call_count())
	check(m.triangle_count() <= 2400, "and %d triangles (within a cyborg's 2,400)" % m.triangle_count())
	var kinds: Dictionary = {}
	var ok_colours: bool = true
	# Vertex colours are stored at 8 bits a channel.
	var near := func(a: Color, b: Color) -> bool:
		return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01
	for mesh: ArrayMesh in [ResonatorModel.spire_mesh(), ResonatorModel.halo_mesh(0), ResonatorModel.halo_mesh(1),
			ResonatorModel.halo_mesh(2)]:
		var colours: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for c: Color in colours:
			kinds[snappedf(c.a, 0.5)] = true
			if c.a > 0.75:
				ok_colours = ok_colours and near.call(c, ResonatorModel.RED)
			else:
				ok_colours = ok_colours and (near.call(c, ResonatorModel.GOLD) or near.call(c, ResonatorModel.GOLD_DEEP)
					or near.call(c, ResonatorModel.IVORY))
	check(ok_colours and kinds.has(0.0) and kinds.has(0.5) and kinds.has(1.0),
		"lit gold and ivory, gold trims that glow only while it warns, and the red core (%s)" % [kinds.keys()])
	check(ResonatorModel.GOLD.is_equal_approx(CultEmblem.GOLD_COLOR) and ResonatorModel.GOLD_DEEP.v < ResonatorModel.GOLD.v,
		"its gold is the Golden Zone's own (CultEmblem.GOLD_COLOR), with a darker gold inside")
	# Its glow and its wave are enemy-fire red (ProjectilePool's enemy_bolt), the same in every zone.
	var red: String = "vec3(1.0, 0.15, 0.1)"
	check(ResonatorModel.shader().code.contains("glow_color : source_color = " + red)
		and ResonatorModel.wave_shader().code.contains("wave_color : source_color = " + red)
		and Resonator.RED.is_equal_approx(ResonatorModel.RED),
		"it glows, and its wave is drawn, in enemy-fire red")
	m.align = [1.0, 1.0, 1.0]
	m.animate(0.0)
	var facing: bool = true
	for n: Vector3 in m.halo_normals():
		facing = facing and absf(n.dot(Vector3.BACK)) > 0.999
	check(facing, "lined up, all three halos face the runner (%s)" % [m.halo_normals()])
	m.align = [0.0, 0.0, 0.0]
	m.animate(0.0)
	var tumbling: int = 0
	for n: Vector3 in m.halo_normals():
		tumbling += 1 if absf(n.dot(Vector3.BACK)) < 0.95 else 0
	check(tumbling == 3, "at rest they tumble at angles of their own")
	m.queue_free()


## Its sounds are in the library (the chime, a warning, always at the same pitch), and the chime's three
## notes start on CHIME_NOTES, where the halos line up; a first-encounter hint names the dodge.
func _test_sounds_and_hint() -> void:
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in [&"resonator_chime", &"resonator_pulse", &"resonator_death"]:
		check(library.names().has(String(sound)) and library.stream(sound) != null, "the sound library has %s" % sound)
	check(float(library.pitch_variation.get("resonator_chime", 0.0)) == 0.0, "the chime always plays at its pitch (a warning)")
	var raw := AudioStreamWAV.load_from_file("res://assets/sfx/resonator_chime.wav", {"compress/mode": 0})
	check(raw != null and raw.mix_rate == 32000 and not raw.stereo, "the chime is 32 kHz mono")
	if raw != null:
		var pcm: PackedByteArray = raw.data
		var n: int = pcm.size() / 2
		var energy := func(from_s: float, to_s: float) -> float:
			var a: int = clampi(int(from_s * 32000.0), 1, n - 1)
			var b: int = clampi(int(to_s * 32000.0), a + 1, n)
			var sum: float = 0.0
			for i: int in range(a, b):
				var d: float = (pcm.decode_s16(i * 2) - pcm.decode_s16((i - 1) * 2)) / 32768.0
				sum += d * d
			return sum / float(b - a)
		var onsets: bool = true
		for note: float in Resonator.CHIME_NOTES:
			if note <= 0.0:
				continue
			var before: float = energy.call(note - 0.04, note - 0.005)
			var after: float = energy.call(note + 0.002, note + 0.03)
			onsets = onsets and after > before * 2.0
		check(onsets, "the chime's notes start on Resonator.CHIME_NOTES (%s)" % [Resonator.CHIME_NOTES])
		check(raw.get_length() > Resonator.CHIME_NOTES[-1] + 0.4 and raw.get_length() < 2.5,
			"and the last rings on after it (%.2f s)" % raw.get_length())
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var has_hint: bool = false
	for h: Variant in (hints as Dictionary).get("hints", []):
		if String((h as Dictionary).get("trigger", "")) == "enemy:resonator":
			has_hint = String((h as Dictionary).get("text", "")).contains("{jump}")
	check(has_hint, "a first-encounter hint for the Resonator names the jump")


# --- The warning and the wave ---------------------------------------------------------------------

## GDD §9.10: before each pulse, the halos line up and the chime plays, for the whole warning, and only
## then does a wave leave; a double pulse's second wave follows double_gap later. The pulse is a big
## attack until its last wave has passed the player. The same every attempt.
func _test_warning_then_wave() -> void:
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var logs: Array = []
	for lanes: int in [3, 5, 6, 5]:
		var tag: String = "lanes=%d" % lanes
		var made: Array = await _world(lanes, lanes / 2, {"pulses": 3, "double": [false, true, false]})
		var w: RunWorld = made[0]
		var r: Resonator = made[1]
		w.player.god_mode = true
		var id: int = r.get_instance_id()
		var early_hit: bool = false
		var lined_before_wave: bool = true
		var charge_ok: bool = true
		var last_charge: float = -1.0
		var major_ok: bool = true
		var waves_before: int = 0
		for i: int in int(24.0 * Engine.physics_ticks_per_second):
			await tree.physics_frame
			var res: Resonator = _res(id)
			if res == null or res.state == Resonator.State.LEAVE:
				break
			# No wave's hitbox is live except while that wave rolls toward the player.
			for wave: Resonator.Wave in res.wave_list():
				if wave.hitbox.is_active() and not wave.on_its_way():
					early_hit = true
			if res.state == Resonator.State.WARNING:
				charge_ok = charge_ok and res.charge >= last_charge - 0.0001
				last_charge = res.charge
				major_ok = major_ok and res.is_major_attack_active()
				if res.waves_sent == waves_before and res.charge > 1.0 - dt / t.warning_seconds * 1.5:
					for k: int in 3:
						lined_before_wave = lined_before_wave and res.line_up(k) > 0.99
			else:
				last_charge = -1.0
			if res.waves_sent != waves_before:
				waves_before = res.waves_sent
			if res.waves_on_their_way():
				major_ok = major_ok and res.is_major_attack_active()
		var r2: Resonator = _res(id)
		check(r2 != null, "it's still there after its pulses " + tag)
		if r2 == null:
			await sim.free_world(w)
			continue
		var warnings: Array = r2.events(PackedStringArray(["warning"]))
		var waves: Array = r2.events(PackedStringArray(["wave"]))
		check(warnings.size() == 3 and waves.size() == 4 and r2.waves_sent == 4,
			"three pulses, the second double: 3 warnings, 4 waves (%d, %d) %s" % [warnings.size(), waves.size(), tag])
		var timed: bool = warnings.size() == 3 and waves.size() == 4
		if timed:
			var firsts: Array = [waves[0], waves[1], waves[3]]
			for k: int in 3:
				var gap: float = float(firsts[k][1]) - float(warnings[k][1])
				timed = timed and absf(gap - t.warning_seconds) <= dt * 1.5
			timed = timed and absf(float(waves[2][1]) - float(waves[1][1]) - t.double_gap) <= dt * 1.5
		check(timed, "each wave leaves after the full warning (%.2f s), a double's second %.2f s after its first %s"
			% [t.warning_seconds, t.double_gap, tag])
		var chimes: Array = []
		for s: Array in r2.sounds:
			if s[0] == &"resonator_chime":
				chimes.append(float(s[1]))
		var chimed: bool = chimes.size() == warnings.size()
		for k: int in mini(chimes.size(), warnings.size()):
			chimed = chimed and absf(chimes[k] - float(warnings[k][1])) < 0.001
		check(chimed, "the chime plays as each warning starts (%d chimes) %s" % [chimes.size(), tag])
		check(lined_before_wave and charge_ok, "the halos have all lined up, and the warning built up, before each wave " + tag)
		check(not early_hit, "no wave can hurt before it leaves, or after it has passed " + tag)
		check(major_ok, "it reports a big attack from each warning until its waves have passed the player " + tag)
		check(_count(r2, "pass") == 4 and r2.state == Resonator.State.LEAVE and not r2.is_major_attack_active(),
			"every wave passes the player, then it leaves %s" % tag)
		var line: Array = []
		for h: Array in r2.history:
			line.append("%s %.4f %.3f" % [h[0], h[1], h[2]])
		if lanes == 5:
			logs.append(line)
		# It pulls away and is gone.
		var gone: bool = await _until(func() -> bool: return _res(id) == null or _res(id).is_queued_for_deletion(), 12.0)
		check(gone, "after leaving it's retired " + tag)
		await sim.free_world(w)
	check(logs.size() == 2 and logs[0] == logs[1], "identical on every attempt (the same history at the same times)")


# --- Jump it, or be hit -------------------------------------------------------------------------------

## GDD §9.10: jump the wave. At 3, 5 and 6 lanes, from the outer lanes and the middle: a runner who
## stays put is hit, one who slides is hit, one who jumps in time survives. The jump's window is
## measured: how early and how late before the wave reaches them a jump still clears it.
func _test_jump_and_stand() -> void:
	for lanes: int in [3, 5, 6]:
		for lane: int in [0, lanes / 2, lanes - 1]:
			for action: String in ["stand", "slide", "jump"]:
				var tag: String = "lanes=%d lane=%d %s" % [lanes, lane, action]
				var made: Array = await _world(lanes, lane)
				var w: RunWorld = made[0]
				var r: Resonator = made[1]
				var id: int = r.get_instance_id()
				var went: bool = await _until(func() -> bool: return _arrival_in(w, _res(id)) <= (0.33 if action == "jump" else 0.25), 12.0)
				check(went, "the wave comes " + tag)
				if action == "jump":
					w.player.press(&"jump")
				elif action == "slide":
					w.player.press(&"slide")
				await _until(func() -> bool: return not w.player.alive or _count(_res(id), "pass") >= 1, 3.0)
				if action == "jump":
					check(w.player.alive, "jumping the wave clears it %s (%s)" % [tag, w.player.last_event])
				else:
					check(not w.player.alive and w.player.last_event.contains(WAVE_NAME),
						"%s: the wave hits (%s)" % [tag, w.player.last_event])
				await sim.free_world(w)
	# The window, measured at 5 lanes in the middle: jumps started this many seconds before the wave
	# reaches the runner.
	var cleared: Array[float] = []
	var offsets: Array[float] = [1.0, 0.8, 0.7, 0.6, 0.55, 0.5, 0.4, 0.3, 0.2, 0.1, 0.05, 0.0]
	for offset: float in offsets:
		var made: Array = await _world(5, 2)
		var w: RunWorld = made[0]
		var r: Resonator = made[1]
		var id: int = r.get_instance_id()
		await _until(func() -> bool: return _arrival_in(w, _res(id)) <= offset, 12.0)
		w.player.press(&"jump")
		await _until(func() -> bool: return not w.player.alive or _count(_res(id), "pass") >= 1, 3.0)
		if w.player.alive:
			cleared.append(offset)
		await sim.free_world(w)
	var earliest: float = cleared.max() if not cleared.is_empty() else -1.0
	var latest: float = cleared.min() if not cleared.is_empty() else -1.0
	check(cleared.has(0.5) and cleared.has(0.3) and cleared.has(0.1) and not cleared.has(1.0) and not cleared.has(0.0),
		"a jump clears the wave if it starts between %.1f and %.1f s before the wave reaches the runner (%s)"
		% [earliest, latest, cleared])
	print("  the jump's window: started %.1f to %.1f s before the wave reaches the runner (tried %s)" % [earliest, latest, offsets])


# --- Walls and the ceiling ------------------------------------------------------------------------------

## GDD §9.10: waves travel along the floor only. A runner on either wall, high on it or at the very bottom
## of their run as the wave passes below, is never hit, at 3, 5 and 6 lanes; neither is one riding a
## ceiling.
func _test_walls_and_ceiling() -> void:
	for lanes: int in [3, 5, 6]:
		for side: int in [-1, 1]:
			# Entering 0.6 s before the wave: high up. 2.08 s: at the bottom of the run as it passes.
			for before: float in [0.6, 2.08]:
				var tag: String = "lanes=%d side=%d entered %.2f s before" % [lanes, side, before]
				var lane: int = 0 if side < 0 else lanes - 1
				var made: Array = await _world(lanes, lane)
				var w: RunWorld = made[0]
				var r: Resonator = made[1]
				var id: int = r.get_instance_id()
				await _until(func() -> bool: return _arrival_in(w, _res(id)) <= before, 12.0)
				w.player.press(&"move_left" if side < 0 else &"move_right")
				var at_pass: Array = ["", 0.0]
				var passes: int = 0
				for i: int in int(4.0 * Engine.physics_ticks_per_second):
					await tree.physics_frame
					var res: Resonator = _res(id)
					if res == null or not w.player.alive:
						break
					if _count(res, "pass") > passes:
						passes = _count(res, "pass")
						break
					for wave: Resonator.Wave in res.wave_list():
						if wave.on_its_way() and absf(wave.d - w.player.distance) < 0.4:
							at_pass = [w.player.surface_name(), w.player.h]
				check(w.player.alive and at_pass[0] == "wall",
					"on the wall as the wave passes (%s at %.2f m), never hit %s (%s)" % [at_pass[0], at_pass[1], tag, w.player.last_event])
				await sim.free_world(w)
	# The ceiling: a pad early on and a long ceiling; the wave meets the runner riding it.
	for lanes: int in [3, 6]:
		var layout := RunSim.layout(lanes, 900.0)
		var lane: int = lanes / 2
		layout.pads.append({"lane": lane, "at": 25.0})
		layout.hulls.append({"start": 22.0, "end": 420.0})
		var made: Array = await _world(lanes, lane, {}, null, 120.0, layout)
		var w: RunWorld = made[0]
		var r: Resonator = made[1]
		var id: int = r.get_instance_id()
		var surface_at_pass: Array = [""]
		var passed: bool = await _until(func() -> bool:
			var res: Resonator = _res(id)
			if res != null:
				for wave: Resonator.Wave in res.wave_list():
					if wave.on_its_way() and absf(wave.d - w.player.distance) < 0.4:
						surface_at_pass[0] = w.player.surface_name()
			return not w.player.alive or (res != null and _count(res, "pass") >= 1), 16.0)
		check(passed and w.player.alive and surface_at_pass[0] == "ceiling",
			"riding the ceiling as the wave passes below (%s), never hit (lanes=%d, %s)" % [surface_at_pass[0], lanes, w.player.last_event])
		await sim.free_world(w)


# --- Protection ----------------------------------------------------------------------------------------

## Armor and the shield each block a wave (an enemy attack); one armor covers both waves of a double
## (the second comes in the invulnerability window); the dash passes through a wave; claws alone don't
## help against it.
func _test_protection() -> void:
	var cases: Array = [["armor", {"armor": 1}, false], ["shield", {"shield": 1}, false], ["armor, double", {"armor": 1}, true],
		["dash", {}, false], ["claws", {"claws": 1}, false]]
	for case: Array in cases:
		var tag: String = String(case[0])
		var made: Array = await _world(5, 2, {"double": case[2]}, _loadout(case[1]))
		var w: RunWorld = made[0]
		var r: Resonator = made[1]
		var id: int = r.get_instance_id()
		var events: Array = []
		w.player.movement_event.connect(func(k: StringName) -> void: events.append(k))
		if tag == "dash":
			await _until(func() -> bool: return _arrival_in(w, _res(id)) <= 0.15, 12.0)
			w.player.start_dash(0.5, 0.0)
		await _until(func() -> bool: return not w.player.alive or _count(_res(id), "pass") >= (2 if case[2] else 1), 14.0)
		match tag:
			"armor", "shield":
				check(w.player.alive and events.has(StringName(tag + "_break")), "%s blocks a wave (%s)" % [tag, w.player.last_event])
			"armor, double":
				check(w.player.alive and events.count(&"armor_break") == 1,
					"one armor covers both waves of a double (the second in the invulnerability window) (%s)" % w.player.last_event)
			"dash":
				check(w.player.alive and not events.has(&"armor_break") and _res(id) != null and _res(id).alive,
					"the dash passes through a wave, and doesn't touch the Resonator (%s)" % w.player.last_event)
			"claws":
				check(not w.player.alive and w.player.last_event.contains(WAVE_NAME), "claws don't help against a wave")
		await sim.free_world(w)


# --- Weapons, no stomp ---------------------------------------------------------------------------------

## Weapons: auto-fire targets it within the weapon's reach, 15 laser tier 1 shots bring it down, and a
## wave still rolling fizzles out with it (its turn ends too). No stomp: it hovers out of reach ahead of
## the player, even when they speed up, and has no body or top to land on.
func _test_weapons_and_stomp() -> void:
	var made: Array = await _world(3, 1, {"pulses": 2})
	var w: RunWorld = made[0]
	var r: Resonator = made[1]
	var id: int = r.get_instance_id()
	w.player.god_mode = true
	check(not r.stompable and r.claw_immune and not r.dash_kills, "it declares: no stomp, no claws, the dash passes its waves")
	var parts: Dictionary = {}
	for wave: Resonator.Wave in r.wave_list():
		parts[wave.hitbox.part] = wave.hitbox.is_enemy_attack
	check(parts.size() == 1 and parts.has(&"attack") and bool(parts[&"attack"]),
		"its only hitboxes are its waves' (enemy attacks): no body or top to stomp (%s)" % parts)
	await _until(func() -> bool: return _res(id) != null and _res(id).state == Resonator.State.PACE, 6.0)
	var ahead_ok: bool = true
	w.player.start_dash(0.6, 8.0)
	for i: int in 90:
		await tree.physics_frame
		var res: Resonator = _res(id)
		if res != null and res.state in [Resonator.State.PACE, Resonator.State.WARNING]:
			ahead_ok = ahead_ok and res.track_distance() - w.player.distance > t.hover_ahead - 0.5 \
				and res.global_position.y > tuning.jump_height + tuning.hurtbox_size.y
	check(ahead_ok, "it keeps hover_ahead in front of the player, out of reach above a jump, even through a dash")
	var targets: Array[Enemy] = w.director.targets_ahead(w.player.position + Vector3.UP, w.powerup_tuning.weapon_range)
	check(targets.has(r) and r.targetable(), "auto-fire can target it")
	# Let a wave leave, then shoot it down with laser tier 1 shots.
	await _until(func() -> bool: return _res(id) != null and _res(id).waves_on_their_way(), 8.0)
	var laser: float = PowerupTuning.at_tier(w.powerup_tuning.weapon_damage, 1)
	for i: int in 15:
		var res: Resonator = _res(id)
		if res == null or not res.alive:
			break
		res.take_damage(laser, &"weapon")
		if i < 14:
			check(res.alive, "alive after %d laser tier 1 shots" % [i + 1])
	var down: Resonator = _res(id)
	check(down == null or not down.alive, "the 15th brings it down")
	if down != null:
		var harmless: bool = true
		for wave: Resonator.Wave in down.wave_list():
			harmless = harmless and not wave.hitbox.is_active()
		check(harmless and not down.is_major_attack_active() and down.state == Resonator.State.DOWN,
			"its rolling wave fizzles out with it, and its turn is over")
	check(w.score.kills == 1, "and it counts as a kill")
	await sim.free_world(w)
	# Auto-fire, heavy missiles: it's shot down before it leaves.
	made = await _world(3, 1, {"pulses": 3}, _loadout({"weapon": 4}))
	w = made[0]
	r = made[1]
	w.player.god_mode = true
	var cause: Array = [&""]
	r.defeated.connect(func(_e: Enemy, c: StringName) -> void: cause[0] = c)
	id = r.get_instance_id()
	await _until(func() -> bool: return _res(id) == null or not _res(id).alive, 16.0)
	check(cause[0] == &"weapon", "auto-fire brings it down (%s)" % cause[0])
	await sim.free_world(w)


# --- Big attacks take turns ------------------------------------------------------------------------------

## GDD §9: a pulse is a big attack. While another type's is on, it waits (hovering) and its pulses move on,
## then pulses once that's over; while its pulse is on (from the warning until its last wave has passed
## the player) another type's waits. Switched off, it pulses during the other. A long wait never starves
## it: its first pulse always comes.
func _test_takes_turns() -> void:
	# [name, the other's first moment (s), its warning + attack (s), switch, seconds between the other's
	# attacks]
	var cases: Array = [["waits", 1.0, 3.0, true, 100.0], ["holds the other", 3.1, 0.6, true, 100.0],
		["switch off", 1.0, 3.0, false, 100.0], ["never starved", 1.0, 14.0, true, 1.0]]
	for case: Array in cases:
		var tag: String = "%s, turns %s" % [case[0], "on" if case[3] else "off"]
		var config := LevelConfig.new()
		var w: RunWorld = sim.build_world(RunSim.layout(3, 1200.0), null, null, config)
		w.rules = w.rules.duplicate() as GameRules
		w.rules.big_attacks_take_turns = case[3]
		w.player.setup(tuning, w.geo, 1)
		w.player.god_mode = true
		var other := w.director.spawn({"type": "blocker", "script": TURN_DUMMY, "at": 0.0, "lane": 0, "side": 0,
			"seed": 1, "params": {"first": float(case[1]), "interval": float(case[4]), "warning": 0.5,
			"attack": float(case[2]) - 0.5}}) as Enemy
		var r := w.director.spawn({"type": "resonator", "at": 60.0, "lane": 1, "side": 0, "seed": 5,
			"params": {"pulses": 2}}) as Resonator
		var id: int = r.get_instance_id()
		await tree.physics_frame
		w.player.running = true
		await _until(func() -> bool: return _done(id), 30.0)
		var res: Resonator = _res(id)
		var spans: Array = other.call(&"spans")
		var other_start: float = float(spans[0][0]) if not spans.is_empty() else -1.0
		var other_end: float = float(spans[0][1]) if not spans.is_empty() else -1.0
		var warnings: Array = res.events(PackedStringArray(["warning"])) if res != null else []
		var passes: Array = res.events(PackedStringArray(["pass"])) if res != null else []
		var first_warning: float = float(warnings[0][1]) if not warnings.is_empty() else -1.0
		match case[0]:
			"waits":
				check(first_warning >= other_end - 0.001 and float(res.waited_for.get(&"turn", 0.0)) > 0.5,
					"%s: it waits for the other and pulses once it's over (%.2f s, over at %.2f s)" % [tag, first_warning, other_end])
				check(int(other.call(&"count", "held")) == 0 and res.pulses_done == 2, "%s: the other never waited; both pulses came" % tag)
				check(float(res.get(&"_shift")) > 5.0, "%s: its pulses moved on by the wait (%.1f m)" % [tag, float(res.get(&"_shift"))])
			"holds the other":
				check(first_warning > 0.0 and first_warning < other_start and not passes.is_empty() and other_start >= float(passes[0][1]) - 0.001,
					"%s: the other waits from its warning until its wave has passed the player (other at %.2f s, wave past at %.2f s)"
					% [tag, other_start, float(passes[0][1]) if not passes.is_empty() else -1.0])
				check(int(other.call(&"count", "held")) == 1, "%s: the other was held" % tag)
			"switch off":
				check(first_warning >= 0.0 and first_warning < other_end and float(res.waited_for.get(&"turn", 0.0)) == 0.0,
					"%s: it pulses during the other, as before the rule (%.2f s, over at %.2f s)" % [tag, first_warning, other_end])
			"never starved":
				# The other attacks for 14 s from 1 s, and again a second after each (the longest waiter goes
				# first, so the Resonator's first pulse gets in between).
				check(first_warning >= other_end - 0.001 and res.pulses_done >= 1,
					"%s: its first pulse still comes, after the other's long attack (%.2f s, over at %.2f s)" % [tag, first_warning, other_end])
				check(res.pulses_done == 1 and _count(res, "dropped") == 1 and float(res.waited_for.get(&"turn", 0.0)) > t.turn_wait_max,
					"%s: having waited over turn_wait_max for turns, it drops the pulse left rather than wait again (%d pulses)"
					% [tag, res.pulses_done])
		await sim.free_world(w)


# --- Reduced flashing --------------------------------------------------------------------------------------

## Settings > Reduced flashing: the halos' warning glow ramps up steadily instead of throbbing, and the
## wave's stripes hold still. Without it, the glow throbs.
func _test_reduced_flashing() -> void:
	var saved: bool = Settings.flashing_reduced
	for reduced: bool in [true, false]:
		Settings.flashing_reduced = reduced
		var made: Array = await _world(5, 2)
		var w: RunWorld = made[0]
		var r: Resonator = made[1]
		w.player.god_mode = true
		var id: int = r.get_instance_id()
		await _until(func() -> bool: return _res(id) != null and _res(id).state == Resonator.State.WARNING, 8.0)
		var glows: Array[float] = []
		var warning: Array[bool] = []
		var rolls: Array = []
		for i: int in int(t.warning_seconds * 60.0) + 40:
			var res: Resonator = _res(id)
			if res == null:
				break
			res._process(1.0 / 60.0)
			glows.append(res.model().halo_glow[0])
			warning.append(res.state == Resonator.State.WARNING)
			for wave: Resonator.Wave in res.wave_list():
				if wave.rolling:
					rolls.append(wave.material.get_shader_parameter(&"roll"))
			await tree.physics_frame
		var falls: int = 0
		for i: int in range(1, glows.size()):
			if warning[i] and warning[i - 1] and glows[i] < glows[i - 1] - 0.0001:
				falls += 1
		var rolled: bool = rolls.size() > 1 and rolls.min() != rolls.max()
		if reduced:
			check(falls <= 1 and not rolled, "Reduced flashing: the halos' glow ramps up without throbbing, the wave's stripes hold still (%d dips)" % falls)
		else:
			check(falls > 3 and rolled, "without it the glow throbs and the stripes roll (%d dips)" % falls)
		await sim.free_world(w)
	Settings.flashing_reduced = saved


# --- The generator --------------------------------------------------------------------------------------

## Its rules on many levels: every Resonator gets pulses whose waves meet the player on clear floor (no
## gap, fence, floor enemy, pad or ceiling landing in any lane), off chases and Octodog runs, one visit at
## a time; the same seed gives the same level; none without the feature. The campaign's Golden levels,
## on their own seeds and others, at 3, 5 and 6 lanes.
func _test_generator() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var total: int = 0
	var doubles: int = 0
	for lanes: int in [3, 5, 6]:
		for scaling: float in [0.0, 1.0]:
			for level_seed: int in range(1, 7):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = 0.6
				config.enemy_scaling = scaling
				config.level_seed = level_seed
				config.features = PackedStringArray(["ramps", "ceilings", "pulsing", "octodog", "resonator"])
				var tag: String = "lanes=%d scaling=%.0f seed=%d" % [lanes, scaling, level_seed]
				var patterns: Array = LevelGenerator.load_for(config)
				var gen := LevelGenerator.new()
				var a: LevelLayout = gen.generate(config, tuning, patterns)
				check(gen.warnings.is_empty(), "resonator levels generate without warnings %s %s" % [tag, gen.warnings])
				var b: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
				check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "same seed, same level " + tag)
				var problems: PackedStringArray = Rules.problems(a, config, tuning)
				check(problems.is_empty(), "every pulse is fair %s: %s" % [tag, problems])
				for e: Dictionary in Rules.resonators_in(a):
					total += 1
					for d: Variant in e["params"]["double"]:
						doubles += 1 if bool(d) else 0
	check(total > 36, "levels with the feature get Resonators (%d)" % total)
	check(doubles > 5, "and some double pulses late in the zone (%d)" % doubles)
	var plain: LevelConfig = base.duplicate() as LevelConfig
	var layout: LevelLayout = LevelGenerator.new().generate(plain, tuning, LevelGenerator.load_for(plain))
	check(Rules.resonators_in(layout).is_empty(), "no Resonators without the feature")
	# The Golden levels: on their own seeds, Golden 1 introduces it right after the feature's start (within
	# test_campaign's INTRODUCTION_REACH); on other seeds almost always.
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var late: Array = []
	for id: String in ["golden/1", "golden/2", "golden/3"]:
		for lanes: int in [3, 5, 6]:
			for extra: int in [0, 1, 2, 3]:
				var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
				if extra > 0:
					config.level_seed = 8100 + extra
				var tag: String = "%s lanes=%d seed=%d" % [id, lanes, config.level_seed]
				var gen := LevelGenerator.new()
				var l: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
				check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
				var problems: PackedStringArray = Rules.problems(l, config, tuning)
				check(problems.is_empty(), "every pulse is fair %s: %s" % [tag, problems])
				var found: Array[Dictionary] = Rules.resonators_in(l)
				check(not found.is_empty(), "%s has a Resonator" % tag)
				if id == "golden/1" and not found.is_empty():
					var start: float = gen.feature_start("resonator")
					var first: float = float(found[0]["at"])
					check(first >= start, "%s: nothing of it before the feature's start (%.0f m, start %.0f m)" % [tag, first, start])
					if first > start + 210.0:
						late.append(tag)
					if extra == 0:
						check(first <= start + 210.0, "%s: its first comes right after the feature's start (%.0f m, start %.0f m)"
							% [tag, first, start])
	check(late.size() <= 1, "Golden 1 introduces it right after its start on other seeds too (late: %s)" % [late])
	# The campaign's recency curve never boosts it (FeatureRecency.max_factor): its rules keep one visit at
	# a time, so they'd drop most extra picks and leave their stretches empty (boosted, Golden 1 lost about
	# 2 enemies and 3 obstacle rows a level).
	var curve: FeatureRecency = campaign.feature_recency
	check(curve != null and curve.max_factor.has("resonator") and float(curve.max_factor["resonator"]) <= 1.0,
		"the recency curve never boosts the Resonator: its rules keep one visit at a time")


# --- The campaign, played ----------------------------------------------------------------------------------

## The real campaign layouts of Golden 1-3 at 3, 5 and 6 lanes, played by a god-mode runner in the middle
## lane (grapples, stomping every host it passes: tools/measure/big_attacks.gd's runner) with the enemies
## as in the game, until the last Resonator has left: every wave meets the runner where no lane holds a
## gap or a live fence, no two types' big attacks overlap (tools/measure/attack_watch.gd), and every
## Resonator that came pulsed.
func _test_campaign() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var waves_met: int = 0
	var zones: CeilingZones = null
	for case: Array in [["golden/1", 3], ["golden/1", 5], ["golden/1", 6], ["golden/2", 3], ["golden/2", 5], ["golden/2", 6],
			["golden/3", 3], ["golden/3", 5], ["golden/3", 6]]:
		var tag: String = "%s lanes=%d" % [case[0], case[1]]
		var config: LevelConfig = campaign.configure(campaign.step(case[0]), case[1])
		config.skin = null  # the grey box: skins never change gameplay
		zones = CeilingZones.make(config, tuning)
		var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
		# Played until the last Resonator's visit is well over (its pulses may wait at run time).
		var until: float = 0.0
		for e: Dictionary in Rules.resonators_in(layout):
			until = maxf(until, float((e["params"]["pulse_at"] as Array)[-1]) + 20.0 * tuning.run_speed)
		var w: RunWorld = sim.build_world(layout, null, null, config)
		w.player.god_mode = true
		w.player.grapples = 1_000_000
		var watch: AttackWatch = AttackWatch.new(w, true)
		await tree.physics_frame
		w.player.running = true
		var met: Array[float] = []
		var last_rel: Dictionary = {}
		while w.player.distance < minf(until, layout.length) or _resonator_in_play(w):
			await tree.physics_frame
			watch.observe()
			for e: Enemy in w.director.active:
				if not is_instance_valid(e) or not (e is Resonator):
					continue
				for wave: Resonator.Wave in (e as Resonator).wave_list():
					var key: int = wave.get_instance_id()
					var rel: float = wave.d - w.player.distance
					if wave.on_its_way() and float(last_rel.get(key, INF)) > 0.0 and rel <= 0.0:
						met.append(w.player.distance)
					last_rel[key] = rel if wave.rolling else INF
		var bad: PackedStringArray = []
		var margin: float = 0.4 * tuning.run_speed
		for d: float in met:
			var zone := Vector2(d - margin, d + margin)
			for g: Dictionary in layout.gaps:
				if zones.gap_in(g, zone):
					bad.append("a gap at %.0f" % float(g["start"]))
			for f: Dictionary in layout.fences:
				if zones.fence_in(f, zone) and not f.get("disabled", false):
					bad.append("a fence at %.0f" % float(f["at"]))
		waves_met += met.size()
		check(bad.is_empty(), "%s: no wave meets the runner on a gap or a fence (%d waves: %s)" % [tag, met.size(), bad])
		check(not met.is_empty(), "%s: waves come" % tag)
		check(is_zero_approx(watch.overlap), "%s: no two types' big attacks overlap (%.2f s: %s)" % [tag, watch.overlap, watch.overlap_pairs])
		check(int(watch.attacks.get("resonator_pulse", 0)) > 0 and watch.resonators_without_a_pulse() == 0,
			"%s: every Resonator that came pulsed (%d pulses, %d Resonators)" % [tag, int(watch.attacks.get("resonator_pulse", 0)),
			watch.resonator_pulses.size()])
		await sim.free_world(w)
	print("  Golden 1-3 at 3, 5 and 6 lanes: %d waves met the runner, none on a gap or a fence" % waves_met)


## True while a Resonator is still in play and hasn't left.
func _resonator_in_play(w: RunWorld) -> bool:
	if w.player.distance >= w.layout.length:
		return false
	for e: Enemy in w.director.active:
		if is_instance_valid(e) and e is Resonator and e.alive and (e as Resonator).state != Resonator.State.LEAVE:
			return true
	return false
