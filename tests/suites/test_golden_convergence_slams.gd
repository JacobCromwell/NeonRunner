extends TestSuite
## The Golden Convergence's Fist Slam and its toppled tower (GDD §10; task E5d-b), at 3, 5 and 6 lanes, with a
## runner who plays it by what it shows (GoldenConvergenceBot) or stays where a test puts it (no god mode):
## - the scripts (phase 1 ON, ON, AHEAD with chances on 2 and 3; later phases ON, AHEAD, ON, ON, AHEAD with
##   chances on 3 and 4), slams slam_gap apart over the phase's pace, their warning and lock;
## - the holes: the footprint (two lanes on 3 lanes, three on 5 or 6, around the locked lane, moved inward at the
##   edge, never every lane); every lane of a slam's row cut before its sequence begins, past the built track;
##   the floor whole until the impact, then the footprint's lanes open at once and the others stay whole; one
##   square hole (no lip, dark line, strip or wall left between two opened lanes, one halo across), nothing in its
##   look glowing but the orange edges and its inside dark;
## - the buttress rule at every lock lane of every lane count (3 lanes too): a hole never goes through a standing
##   gate; a fist locked onto the gate's lane smashes it, the sequence ends and the barrage begins at once;
## - the hit and the hold: a runner under the fist without protection dies; the armor's block, the shield's and
##   a dash through it each hold the floor under the runner (GameRules.cut_hold_seconds) and they run on; a
##   grapple doesn't save the hit, only a fall into a hole;
## - an ahead slam's hole lies ahead of the runner as it lands: jumped, or a fall;
## - the toppled tower: it falls on the side the arch leans to, beside the causeway (never over the track), its
##   side a wall open for tower_wall_seconds of running from the gate and closed after, run on there and
##   bumped off elsewhere; it sinks away behind the runner; the shake honours the Screen shake setting;
## - the warning: the red square and the shadow from the warning to the impact, the grind heard; the arm's fist
##   reaching its mark; the red square steady with Reduced flashing; the sounds and hints;
## - the same on every attempt.
## The bot playing phase 1's slams, bait and barrage clean at every lane count and speed:
## test_golden_convergence_bait.gd; the barrage: test_golden_convergence_barrage.gd.

const BOSS_PATH: String = "res://data/bosses/golden_boss.tres"
const LANES: Array[int] = [3, 5, 6]
const REACTION: float = 0.35
const NEW_SOUNDS: Array[StringName] = [&"gc_grind", &"gc_slam", &"gc_break", &"gc_topple"]
## A gap edge's orange and a hole's inside may be no brighter than this (linear luminance; test_floor_cuts').
const INSIDE_MAX_LUMINANCE: float = 0.02

var sim: RunSim
var def: BossDef


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var slot := load(BOSS_PATH) as BossDef
	def = slot if slot != null and slot.is_built() else null
	if def == null:
		check(false, "the Golden Convergence's fight is built")
		return
	_test_scripts()
	_test_footprints()
	await _test_row_gaps()
	for lanes: int in LANES:
		await _test_holes(lanes)
	for lanes: int in LANES:
		for kind: String in ["o", "a"]:
			await _test_buttress_rule(lanes, kind)
	await _test_hits_and_holds()
	await _test_ahead_hole()
	await _test_sequences()
	await _test_tower()
	await _test_warning()
	_test_shadow_renderers()
	await _test_reduced_flashing()
	await _test_same_every_attempt()


# --- Helpers ------------------------------------------------------------------------------------------------

## The fight at `lanes` and `speed` m/s from phase `phase` (past its entrance), every phase's beat script
## `beats`, the slam scripts `slam_scripts` if given: [world, boss].
func _fight(lanes: int, speed: float, loadout: Loadout = null, phase: int = 0, beats: String = "slams,barrage",
		slam_scripts: PackedStringArray = PackedStringArray()) -> Array:
	var d: BossDef = def.duplicate() as BossDef
	var t := (def.tuning as GoldenConvergenceTuning).duplicate() as GoldenConvergenceTuning
	var list := PackedStringArray()
	for i: int in t.phase_beats.size():
		list.append(beats)
	t.phase_beats = list
	if not slam_scripts.is_empty():
		t.slam_scripts = slam_scripts
	d.tuning = t
	var boss := BossEncounter.create(d) as GoldenConvergence
	var ctx := RunContext.new()
	ctx.mode = RunContext.Mode.QUICK
	ctx.boss = d
	ctx.config = BossArena.base_config(d)
	ctx.config.lane_count = lanes
	ctx.config.run_speed = speed
	ctx.tuning = tuning
	ctx.boss_resume = {"phase": phase, "time": 0.0}
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


## The same lanes in the same order (typed or not).
static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true


## True if a ray down at track distance `d` over lane `lane` meets floor.
func _floor_at(world: RunWorld, lane: int, d: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(world.geo.lane_x(lane), 0.5, -d), Vector3(world.geo.lane_x(lane), -0.5, -d),
		TrackBuilder.LAYER_FLOOR)
	return not world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# --- The scripts --------------------------------------------------------------------------------------------

func _test_scripts() -> void:
	var t: GoldenConvergenceTuning = def.tuning as GoldenConvergenceTuning
	check(t.slam_scripts.size() >= 2 and t.slam_scripts[0] == "Ooa" and t.slam_scripts[1] == "OAooA"
		and (t.slam_scripts.size() < 3 or t.slam_scripts[2] == "OAooA"),
		"phase 1: ON, ON, AHEAD with chances on 2 and 3; later phases ON, AHEAD, ON, ON, AHEAD with chances on 3 and 4 (GDD §10, proposed): %s" % [t.slam_scripts])
	for s: String in t.slam_scripts:
		var chances: int = 0
		for k: int in s.length():
			if s[k] != s[k].to_upper():
				chances += 1
		check(chances == 2, "two buttress chances a sequence (%s)" % s)
	check(t.slam_lock_seconds >= 0.95 and t.slam_lock_seconds <= 1.2, "the fist locks about a second before it falls (%.2f s)" % t.slam_lock_seconds)
	check(is_equal_approx(t.slam_gap, 2.0), "slams about two seconds apart (%.1f s, divided by the phase's pace)" % t.slam_gap)
	check(t.tower_wall_seconds >= 8.0 and t.tower_wall_seconds <= 12.0, "the tower's wall stays 8-12 s (%.1f s)" % t.tower_wall_seconds)
	check(t.slam_hit_height > tuning.jump_height + tuning.hurtbox_size.y, "the fist's touch reaches above a jump (%.1f m)" % t.slam_hit_height)
	var sfx := load("res://data/audio/sfx_library.tres") as SfxLibrary
	var missing: PackedStringArray = []
	var varied: PackedStringArray = []
	for sound: StringName in NEW_SOUNDS:
		if not sfx.volume_db.has(String(sound)) or sfx.stream(sound) == null:
			missing.append(String(sound))
		elif sfx.stream(sound).get_length() >= 2.5:
			missing.append("%s (too long)" % sound)
		if float(sfx.pitch_variation.get(String(sound), 0.0)) != 0.0:
			varied.append(String(sound))
	check(missing.is_empty(), "the fist's and the tower's sounds are in the library, each under 2.5 s (%s)" % ", ".join(missing))
	check(varied.is_empty(), "the grind (the warning) and the rest sound the same every time (%s)" % ", ".join(varied))
	var grind: AudioStream = sfx.stream(&"gc_grind")
	check(grind != null and absf(grind.get_length() - (t.slam_track_seconds + t.slam_lock_seconds)) < 0.05,
		"the grind lasts the fist's warning (%.2f s)" % (grind.get_length() if grind != null else 0.0))
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var triggers: Array[String] = []
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		triggers.append(String(h.get("trigger", "")))
	check(triggers.has("boss:golden_boss/fist") and triggers.has("boss:golden_boss/bait"), "the fist and the bait have hints")


# --- The footprint ------------------------------------------------------------------------------------------

func _test_footprints() -> void:
	var ok: bool = true
	var faults: PackedStringArray = []
	for lanes: int in LANES:
		var w: int = 2 if lanes == 3 else 3
		ok = ok and GoldenConvergenceHole.hole_lanes(lanes) == w
		for lane: int in lanes:
			for side: int in [-1, 1]:
				var fp: Array[int] = GoldenConvergenceHole.footprint(lane, lanes, side)
				var contiguous: bool = fp.size() == w
				for k: int in fp.size():
					contiguous = contiguous and fp[k] == fp[0] + k
				var inside: bool = fp[0] >= 0 and fp[fp.size() - 1] < lanes
				var around: bool = fp.has(lane)
				# Centred on the lane (an odd width), or as near as an even width allows, unless the edge moves it.
				var centred: bool = true
				if w % 2 == 1 and lane >= 1 and lane <= lanes - 2:
					centred = fp[1] == lane
				if not (contiguous and inside and around and centred and fp.size() < lanes):
					faults.append("%d lanes, lane %d: %s" % [lanes, lane, fp])
	check(ok, "a slam's hole is two lanes wide on 3 lanes, three on 5 or 6 (GDD §10, proposed)")
	check(faults.is_empty(), "around the locked lane, moved inward at the track's edge, never every lane: %s" % ", ".join(faults))
	check(_same(GoldenConvergenceHole.footprint(0, 5), [0, 1, 2]) and _same(GoldenConvergenceHole.footprint(4, 5), [2, 3, 4])
		and _same(GoldenConvergenceHole.footprint(5, 6), [3, 4, 5]) and _same(GoldenConvergenceHole.footprint(0, 3), [0, 1])
		and _same(GoldenConvergenceHole.footprint(2, 3), [1, 2]), "at the edges it moves inward")


# --- The rows' spacing --------------------------------------------------------------------------------------

## E5d polish (the review: at 18 m/s phase 3's ahead slam 2 and slam 3 on the runner overlapped by about 0.6 m on
## 5 and 6 lanes): every slam sequence keeps each row (or a chance's gate) at least a lane switch's run plus
## slam_row_margin before the next one, at every stage 1 phase, run speed and lane count, and still at the F6
## ranges' tightest spacing (the shortest slam_gap, the longest ahead lead).
func _test_row_gaps() -> void:
	var faults: PackedStringArray = []
	var plans: int = 0
	var spread: int = 0
	var t0 := def.tuning as GoldenConvergenceTuning
	for tight: bool in [false, true]:
		var scripts := PackedStringArray()
		if tight:
			# Every pair of letters in one script: on after ahead, ahead after on, chances among them.
			scripts = PackedStringArray(["OAoaAOaoA", "AOAoAaOA", "OAooA"])
		for lanes: int in LANES:
			for speed: float in [18.0, 21.0, 25.0, 28.0]:
				var pair: Array = _fight(lanes, speed, null, 0, "slams,barrage", scripts)
				var world: RunWorld = pair[0]
				var boss: GoldenConvergence = pair[1]
				if tight:
					boss.tuning.slam_gap = _range_end(t0, &"slam_gap", false)
					boss.tuning.slam_ahead_seconds = _range_end(t0, &"slam_ahead_seconds", true)
				var sl: GoldenConvergenceSlams = boss.slams
				var least: float = sl.row_gap()
				var switch_run: float = speed * tuning.lane_switch_time
				if least < switch_run + 0.05 * speed:
					faults.append("%d lanes, %.0f m/s: the least gap %.1f m isn't a lane switch's run (%.1f m) and a margin" % [
						lanes, speed, least, switch_run])
				for phase: int in GoldenConvergence.STAGE_2:
					sl._discard()
					# Each plan well past the last one's cuts (a dropped plan's stay on the track).
					sl._plan(world.player.distance + 20.0 + 700.0 * phase, phase)
					plans += 1
					var v: float = boss.speed_planned()
					var p: float = boss.def.phase_list()[phase].pace
					for k: int in range(1, sl.slams.size()):
						var a: Dictionary = sl.slams[k - 1]
						var b: Dictionary = sl.slams[k]
						var end: float = (a["row"] as Vector2).y
						if bool(a["chance"]):
							end = maxf(end, float(a["gate_at"]) + boss.tuning.pier_depth * 0.5)
						var gap: float = (b["row"] as Vector2).x - end
						if gap < least - 0.001:
							faults.append("%s, %d lanes, %.0f m/s, phase %d: slams %d and %d's rows %.2f m apart (least %.2f m)" % [
								"tight" if tight else "the script", lanes, speed, phase + 1, k, k + 1, gap, least])
						# Never nearer each other than the script says, and later only by what the gap needs.
						var apart: float = float(b["impact_at"]) - float(a["impact_at"])
						if apart < v * boss.tuning.slam_gap / p - 0.01:
							faults.append("phase %d: slams %d and %d %.2f s apart (the script's %.2f s)" % [phase + 1, k, k + 1,
								apart / v, boss.tuning.slam_gap / p])
						elif apart > v * boss.tuning.slam_gap / p + 0.01:
							spread += 1
							if absf(gap - least) > 0.01:
								faults.append("phase %d: slams %d and %d moved on further than the gap needs (%.2f m)" % [
									phase + 1, k, k + 1, gap])
				await sim.free_world(world)
	check(faults.is_empty() and plans > 0, "consecutive slam rows keep a lane switch's run and slam_row_margin apart at every phase, speed and lane count (%d plans, %d slams moved on): %s" % [
		plans, spread, ", ".join(faults.slice(0, 4))])
	check(spread > 0, "the later phases' ahead slams did bring rows that close, and the slams after them came later (%d)" % spread)


## The high (`high`) or low end of property `prop`'s F6 range on `res` (its @export_range hint). The fights here
## each play their own duplicate of the tuning, so a test may set it there.
static func _range_end(res: Resource, prop: StringName, high: bool) -> float:
	for info: Dictionary in res.get_property_list():
		if StringName(info["name"]) == prop and int(info["hint"]) == PROPERTY_HINT_RANGE:
			var parts: PackedStringArray = String(info["hint_string"]).split(",")
			return float(parts[1] if high else parts[0])
	return float(res.get(prop))


# --- The holes ----------------------------------------------------------------------------------------------

## One ON slam the runner dodges: its row cut in every lane past the built track before the sequence, the floor
## whole until the impact, then the footprint's lanes open at once (the others whole), as one hole.
func _test_holes(lanes: int) -> void:
	var tag: String = "(%d lanes)" % lanes
	var pair: Array = _fight(lanes, 18.0, null, 0, "slams,barrage", PackedStringArray(["O", "O", "O"]))
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	var cause: Array[String] = _death(world)
	await _run(world, bot, 1.0)
	var planned: Array[Dictionary] = _events(boss, &"slams_planned")
	var sl: GoldenConvergenceSlams = boss.slams
	check(planned.size() == 1 and sl.slams.size() == 1, "the sequence is planned before its beat begins %s" % tag)
	if sl.slams.is_empty():
		await sim.free_world(world)
		return
	var s: Dictionary = sl.slams[0]
	var row: Vector2 = s["row"]
	var stream: float = float(planned[0]["stream_from"])
	var cuts: int = 0
	for c: Dictionary in world.layout.cuts:
		if is_equal_approx(float(c["start"]), row.x) and is_equal_approx(float(c["end"]), row.y):
			cuts += 1
	var row_len: float = GoldenConvergenceHole.hole_lanes(lanes) * world.geo.lane_width
	check(cuts == lanes and row.x >= stream - 0.01 and is_equal_approx(row.y - row.x, row_len),
		"its row is cut in every lane, past the built track, as long as the hole is wide (%d cuts, %.1f m) %s" % [cuts, row.y - row.x, tag])
	# E5d polish: the court's floor_cut draws nothing; every footprint's meshes were made with the fight.
	var skin := world.skin as GoldenCourtSkin
	var made: int = skin.hole_meshes.size() if skin != null else -1
	var footprints: int = lanes - GoldenConvergenceHole.hole_lanes(lanes) + 1
	check(skin != null and made >= footprints, "every footprint's hole meshes are made with the fight (%d for %d footprints) %s" % [
		made, footprints, tag])
	var whole := {"ok": true, "seen": false, "built": false, "bare": true}
	await _run(world, bot, 20.0, func() -> bool: return int(s["stage"]) >= GoldenConvergenceSlams.SlamStage.HIT, func() -> void:
		if int(s["stage"]) >= GoldenConvergenceSlams.SlamStage.HIT:
			return
		# Built, the row's cuts draw nothing until the impact: no mesh in the chunk's frame, no hidden inside.
		for lane: int in lanes:
			var built: FloorCut = world.track.floor_cut(lane, row.y)
			if built != null:
				whole["built"] = true
				whole["bare"] = bool(whole["bare"]) and built.find_children("*", "MeshInstance3D", true, false).is_empty() \
					and built.section.statics.is_empty() and built.section.fars.is_empty()
		if world.player.distance < row.x - 120.0:
			return
		whole["seen"] = true
		for lane: int in lanes:
			whole["ok"] = bool(whole["ok"]) and _floor_at(world, lane, (row.x + row.y) * 0.5))
	await tree.physics_frame
	check(bool(whole["seen"]) and bool(whole["ok"]), "the floor is whole in every lane until the impact %s" % tag)
	check(bool(whole["built"]) and bool(whole["bare"]),
		"until the impact a row's cuts draw nothing (no mesh, no inside under the floor) in any lane %s" % tag)
	var lanes_open: Array = s["lanes"]
	var right: bool = true
	for lane: int in lanes:
		var open: bool = not _floor_at(world, lane, (row.x + row.y) * 0.5)
		right = right and open == lanes_open.has(lane)
	check(right and _same(lanes_open, GoldenConvergenceHole.footprint(int(s["lane"]), lanes, int(s["side"]))),
		"at the impact its footprint's lanes open at once round the locked lane, the others stay whole (%s) %s" % [lanes_open, tag])
	# One hole: no side part left facing another opened lane, one halo across it.
	var faults: PackedStringArray = []
	var halos: int = 0
	var fcs: Array[FloorCut] = []
	for lane: Variant in lanes_open:
		var fc: FloorCut = world.track.floor_cut(int(lane), row.y)
		if fc == null:
			faults.append("lane %d unbuilt" % int(lane))
			continue
		fcs.append(fc)
		for list: Array in [fc.section.statics, fc.section.spans, fc.section.fronts, fc.section.fars]:
			for node: Variant in list:
				if not is_instance_valid(node):
					continue
				var tagged: int = int((node as Node).get_meta(GoldenConvergenceHole.SIDE_META, 0))
				if tagged == GoldenConvergenceHole.HALO:
					halos += 1
					continue
				if tagged != 0 and lanes_open.has(int(lane) + tagged):
					faults.append("lane %d keeps its %s side's %s" % [int(lane), "left" if tagged < 0 else "right", (node as Node).name])
	check(faults.is_empty() and halos == 1, "it reads as one square hole: nothing left between its lanes, one halo across (%s; %d halos) %s" % [
		", ".join(faults), halos, tag])
	# Its look: the hole's five parts under its first lane's cut, each the fight's shared mesh (none made at the
	# impact); nothing under the other lanes' cuts, opened or not.
	var shared: Array = []
	for m: Variant in skin.hole_meshes.values():
		shared.append_array((m as Dictionary).values())
	var parts: Array[Node] = []
	var elsewhere: int = 0
	for lane: int in lanes:
		var fc: FloorCut = world.track.floor_cut(lane, row.y)
		if fc == null:
			continue
		var found: Array[Node] = fc.find_children("*", "MeshInstance3D", true, false)
		if lane == int(lanes_open[0]):
			parts = found
		else:
			elsewhere += found.size()
	var all_shared: bool = not parts.is_empty()
	for part: Node in parts:
		all_shared = all_shared and shared.has((part as MeshInstance3D).mesh)
	check(parts.size() >= 4 and parts.size() <= GoldenConvergenceHole.PARTS.size() and all_shared and elsewhere == 0
		and skin.hole_meshes.size() == made,
		"it's drawn as it opens: %d parts under its first lane's cut, all shared meshes (%s), none under the others (%d), no mesh made (%d -> %d) %s" % [
			parts.size(), all_shared, elsewhere, made, skin.hole_meshes.size(), tag])
	_check_look(fcs, world, tag)
	check(world.player.alive, "and the runner who left the footprint runs on (%s) %s" % [cause[0], tag])
	await sim.free_world(world)


## The hole's look (test_floor_cuts' rules): nothing glows but the orange edges, its inside dark; the near and
## far lips right on the collision edges, the outer side lips right at the hole's sides.
func _check_look(fcs: Array[FloorCut], world: RunWorld, tag: String) -> void:
	if fcs.is_empty():
		return
	var skin := world.skin as GoldenSkin
	var edge: Color = skin.gap_edge_color
	var faults: PackedStringArray = []
	var dark: int = 0
	var lo: float = INF
	var hi: float = -INF
	var front: float = -INF
	var far: float = INF
	var x0: float = INF
	var x1: float = -INF
	for fc: FloorCut in fcs:
		x0 = minf(x0, fc.section.x0)
		x1 = maxf(x1, fc.section.x1)
		var parts: Array[Node3D] = fc.section.statics + fc.section.spans + fc.section.fronts + fc.section.fars
		for part: Node3D in parts:
			var m := part as MeshInstance3D
			if m == null or m.mesh == null or not m.visible:
				continue
			for si: int in m.mesh.get_surface_count():
				var arrays: Array = m.mesh.surface_get_arrays(si)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var mat: Material = m.mesh.surface_get_material(si)
				var additive: bool = mat is ShaderMaterial and (mat as ShaderMaterial).shader.resource_path.ends_with("kit_glow.gdshader")
				for i: int in verts.size():
					var p: Vector3 = m.global_transform * verts[i]
					var c: Color = colors[i]
					if additive or c.a > 0.001:
						if absf(c.r - edge.r) > 0.01 or absf(c.g - edge.g) > 0.01 or absf(c.b - edge.b) > 0.01:
							faults.append("a glow in %s" % c)
							continue
						if p.y > 0.0 and not additive:
							if part in fc.section.fronts:
								front = maxf(front, -p.z)
							elif part in fc.section.fars:
								far = minf(far, -p.z)
							elif part in fc.section.spans:
								lo = minf(lo, p.x)
								hi = maxf(hi, p.x)
					elif part in fc.section.statics:
						var l: Color = c.srgb_to_linear()
						if 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b > INSIDE_MAX_LUMINANCE:
							faults.append("an inside lit %s" % c)
						dark += 1
	var start: float = fcs[0].start
	var end: float = fcs[0].end
	check(faults.is_empty() and dark > 0, "nothing in the hole's look glows but its orange edges, and its inside is dark (%s) %s" % [
		", ".join(faults.slice(0, 3)), tag])
	check(absf(front - start) < 0.01 and absf(far - end) < 0.01,
		"its near and far lips lie right on the collision edges (%.2f/%.2f, %.2f/%.2f) %s" % [front, start, far, end, tag])
	var geo: TrackGeometry = world.geo
	var inner_left: bool = x0 > -geo.wall_x() + 0.01
	var inner_right: bool = x1 < geo.wall_x() - 0.01
	check((not inner_left or (lo < x0 + 0.001 and lo > x0 - 0.3)) and (not inner_right or (hi > x1 - 0.001 and hi < x1 + 0.3)),
		"its side lips run along the hole's outer sides, on the lanes beside it (%.2f-%.2f for %.2f-%.2f) %s" % [lo, hi, x0, x1, tag])


# --- The buttress rule ----------------------------------------------------------------------------------------

## A chance slam (`kind` "o" ON, "a" AHEAD) locked onto every lane in turn: a hole never goes through a standing
## gate; locked onto the gate's lane, the fist smashes it, the sequence ends and the barrage begins at once.
func _test_buttress_rule(lanes: int, kind: String) -> void:
	var tag: String = "(%d lanes, %s)" % [lanes, "on the runner" if kind == "o" else "ahead"]
	var faults: PackedStringArray = []
	var baits: int = 0
	var gate_lane: int = -1
	for lane: int in lanes:
		var pair: Array = _fight(lanes, 18.0, null, 0, "slams,barrage", PackedStringArray([kind, kind, kind]))
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		bot.baits = false
		bot.home_lane = lane
		await _run(world, bot, 25.0, func() -> bool: return not _events(boss, &"slam_impact").is_empty())
		var sl: GoldenConvergenceSlams = boss.slams
		if sl.slams.is_empty() or _events(boss, &"slam_impact").is_empty():
			faults.append("lane %d: no impact" % lane)
			await sim.free_world(world)
			continue
		var s: Dictionary = sl.slams[0]
		gate_lane = int(s["buttress_lane"])
		var b: GoldenConvergenceButtress = s.get("buttress")
		var row: Vector2 = s["row"]
		var span: Vector2 = b.span() if b != null else Vector2.ZERO
		if b == null or gate_lane < 1 or gate_lane > lanes - 2:
			faults.append("lane %d: the gate in lane %d (inner lanes only)" % [lane, gate_lane])
		if int(s["lane"]) != lane:
			faults.append("lane %d: locked onto %d" % [lane, int(s["lane"])])
		# No opened cut reaches into a standing gate's span in its lane.
		for fc: FloorCut in world.track.floor_cuts():
			if fc.began() and fc.lane == gate_lane and fc.end > span.x - 0.001 and b != null and b.standing():
				faults.append("lane %d: a hole through the gate (%.1f-%.1f, gate %.1f-%.1f)" % [lane, fc.start, fc.end, span.x, span.y])
		var smashed: bool = b != null and b.state == GoldenConvergenceButtress.State.CRUMBLING
		var bait: bool = not _events(boss, &"slam_bait").is_empty()
		if lane == gate_lane:
			baits += 1
			var done: Array[Dictionary] = _events(boss, &"slams_done")
			var beat: Array[Dictionary] = _events(boss, &"beat").filter(func(e: Dictionary) -> bool: return e["kind"] == &"barrage")
			if not (smashed and bait and done.size() == 1 and bool(done[0]["hit"]) and beat.size() == 1
					and is_equal_approx(float(beat[0]["t"]), float(done[0]["t"]))):
				faults.append("lane %d (the gate's): smashed %s, bait %s, ended %s, barrage %s" % [lane, smashed, bait, done, beat])
			if row.y > span.x + 0.001:
				faults.append("the row runs into the gate")
		elif smashed or bait or (b != null and not b.standing()):
			faults.append("lane %d: a gate in lane %d smashed by a fist locked elsewhere" % [lane, gate_lane])
		await sim.free_world(world)
	check(faults.is_empty() and baits == 1, "a hole never goes through a standing gate; the fist smashes it only locked onto its lane (gate in lane %d) %s: %s" % [
		gate_lane, tag, ", ".join(faults)])


# --- The hit and the hold --------------------------------------------------------------------------------------

## A runner who stays under an ON slam: without protection dies (a grapple doesn't help); the armor's or the
## shield's block, or a dash, holds the floor under them and they run on.
func _test_hits_and_holds() -> void:
	for setup: String in ["none", "grapple", "armor", "shield", "dash"]:
		var loadout := Loadout.new()
		match setup:
			"armor":
				loadout.armor = true
			"shield":
				loadout.charges[&"shield"] = 1
			"grapple":
				loadout.charges[&"grapple"] = 1
			"dash":
				loadout.tiers[&"dash"] = 1
		var pair: Array = _fight(5, 18.0, loadout, 0, "slams,barrage", PackedStringArray(["O", "O", "O"]))
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		bot.dodges_fist = false
		bot.home_lane = 2
		var cause: Array[String] = _death(world)
		var dashed := {"done": false}
		var row := {"to": INF}
		await _run(world, bot, 25.0, func() -> bool: return world.player.distance > float(row["to"]) + 12.0, func() -> void:
			var sl: GoldenConvergenceSlams = boss.slams
			if sl.slams.is_empty():
				return
			var s: Dictionary = sl.slams[0]
			row["to"] = (s["row"] as Vector2).y
			# The dash timed to carry the runner through the impact.
			if setup == "dash" and not bool(dashed["done"]) and world.player.distance >= float(s["impact_at"]) - 4.0:
				dashed["done"] = (world.powerups as PowerupController).dash.trigger())
		var hits: Array[Dictionary] = boss.slams.fist.hits
		var holds: Array[Dictionary] = _events(boss, &"slam_hold")
		match setup:
			"none", "grapple":
				check(not world.player.alive and cause[0] == "the golden fist" and hits.size() == 1
					and int(hits[0]["outcome"]) == DamageRules.Outcome.KILL and holds.is_empty()
					and (setup != "grapple" or world.player.grapples == 1),
					"a runner under the fist without protection dies%s (%s)" % [" (a grapple saves a fall, not the hit)" if setup == "grapple" else "", cause[0]])
			"armor", "shield":
				var outcome: int = DamageRules.Outcome.BLOCKED_ARMOR if setup == "armor" else DamageRules.Outcome.BLOCKED_SHIELD
				check(world.player.alive and hits.size() == 1 and int(hits[0]["outcome"]) == outcome and holds.size() == 1,
					"the %s blocks the fist, the floor under the runner holds, and they run on over the hole (%s, %s)" % [setup, cause[0], holds])
			"dash":
				check(bool(dashed["done"]) and world.player.alive and hits.is_empty() and holds.size() == 1 and bool(holds[0]["dashing"]),
					"a dash through the fist gets the same hold (%s, %s)" % [cause[0], holds])
		await sim.free_world(world)


## An ahead slam's hole lies ahead of the runner as it lands: a jump clears it; running into it is a fall, which a
## grapple saves.
func _test_ahead_hole() -> void:
	for setup: String in ["jump", "fall", "grapple"]:
		var loadout := Loadout.new()
		if setup == "grapple":
			loadout.charges[&"grapple"] = 1
		var pair: Array = _fight(5, 25.0, loadout, 0, "slams,barrage", PackedStringArray(["A", "A", "A"]))
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		bot.home_lane = 2
		bot.jumps_holes = setup == "jump"
		var cause: Array[String] = _death(world)
		var impact := {"runner": -1.0, "row": Vector2.ZERO}
		await _run(world, bot, 25.0, func() -> bool: return float(impact["runner"]) > 0.0 and world.player.distance > (impact["row"] as Vector2).y + 15.0,
			func() -> void:
				var e: Array[Dictionary] = _events(boss, &"slam_impact")
				if float(impact["runner"]) < 0.0 and not e.is_empty():
					impact["runner"] = float(e[0]["runner"])
					impact["row"] = e[0]["row"])
		var row: Vector2 = impact["row"]
		var v: float = boss.speed_planned()
		var lead: float = row.x - float(impact["runner"])
		check(lead >= v * boss.tuning.slam_ahead_seconds - 1.0, "an ahead slam lands %.1f m ahead of the runner (%.2f s): its hole to jump" % [lead, lead / v])
		match setup:
			"jump":
				check(world.player.alive, "a jump clears it (%s)" % cause[0])
			"fall":
				check(not world.player.alive and cause[0] == "fell", "running into it is a fall (%s)" % cause[0])
			"grapple":
				check(world.player.alive and world.player.grapples == 0, "which the grapple hook saves (%s)" % cause[0])
		await sim.free_world(world)


# --- Sequences ------------------------------------------------------------------------------------------------

## Phase 1's and phase 2's scripts played without a bait: each slam where its letter says, slam_gap apart over
## the pace, the fists taking turns, the chances' gates up buttress_sight ahead; then with the bait, the
## sequence over at the hit.
func _test_sequences() -> void:
	for phase: int in [0, 1]:
		var pair: Array = _fight(6, 25.0, null, phase)
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		bot.baits = false
		var cause: Array[String] = _death(world)
		await _run(world, bot, 40.0, func() -> bool: return not _events(boss, &"slams_done").is_empty())
		var tag: String = "(phase %d, 6 lanes, 25 m/s)" % (phase + 1)
		var impacts: Array[Dictionary] = _events(boss, &"slam_impact")
		var want: String = "Ooa" if phase == 0 else "OAooA"
		var kinds: String = ""
		var sides_ok: bool = true
		var gaps_ok: bool = true
		var v: float = boss.speed_planned()
		var pace: float = boss.pace()
		var plan: Array[Dictionary] = boss.slams.slams
		for k: int in impacts.size():
			var e: Dictionary = impacts[k]
			var letter: String = "A" if e["kind"] == &"ahead" else "O"
			kinds += letter if not bool(e["chance"]) else letter.to_lower()
			sides_ok = sides_ok and int(e["side"]) == (-1 if k % 2 == 0 else 1)
			if k > 0:
				var gap: float = (float(e["impact_at"]) - float(impacts[k - 1]["impact_at"])) / v
				# slam_gap over the pace, or later by just what keeps its row row_gap() past the last one's (E5d polish).
				var rows_apart: float = INF
				if k < plan.size():
					var last_end: float = (plan[k - 1]["row"] as Vector2).y
					if bool(plan[k - 1]["chance"]):
						last_end = float(plan[k - 1]["gate_at"]) + boss.tuning.pier_depth * 0.5
					rows_apart = (plan[k]["row"] as Vector2).x - last_end
				gaps_ok = gaps_ok and (absf(gap - boss.tuning.slam_gap / pace) < 0.01
					or (gap > boss.tuning.slam_gap / pace and absf(rows_apart - boss.slams.row_gap()) < 0.01))
		check(kinds == want, "the slams come as the script says: %s (%s) %s" % [kinds, want, tag])
		check(sides_ok and gaps_ok, "the fists take turns, slam_gap apart over the pace (or just enough later to keep row_gap() between rows) %s" % tag)
		var placed: Array[Dictionary] = _events(boss, &"buttress_placed")
		var sight_ok: bool = placed.size() == 2
		for e: Dictionary in placed:
			sight_ok = sight_ok and (float(e["at"]) - float(e["runner"])) / v >= boss.tuning.buttress_sight - 0.05
		check(sight_ok, "each chance's gate rises at least %.0f s ahead (%d gates) %s" % [boss.tuning.buttress_sight, placed.size(), tag])
		check(world.player.alive and boss.slams.fist.hits.is_empty(), "the bot dodges and jumps every slam untouched (%s) %s" % [cause[0], tag])
		check(_sounds(boss, &"gc_grind") == want.length() and _sounds(boss, &"gc_slam") == want.length(),
			"each slam's grind and slam heard %s" % tag)
		await sim.free_world(world)
	# The bait ends the sequence.
	var pair: Array = _fight(5, 18.0, null, 1)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	await _run(world, bot, 40.0, func() -> bool: return not _events(boss, &"barrage_warned").is_empty())
	var bait: Array[Dictionary] = _events(boss, &"slam_bait")
	var impacts: Array[Dictionary] = _events(boss, &"slam_impact")
	check(bait.size() == 1 and int(bait[0]["n"]) == 2 and impacts.size() == 3 and float(impacts[2]["t"]) == float(bait[0]["t"]),
		"baited on its first chance (the third slam), the sequence ends at the hit (%d slams)" % impacts.size())
	await _run(world, bot, 6.0)
	check(_events(boss, &"slam_impact").size() == 3 and _events(boss, &"buttress_sunk").size() == 1,
		"no slam after it, and the other chance's gate sinks away")
	await sim.free_world(world)


# --- The tower ------------------------------------------------------------------------------------------------

func _test_tower() -> void:
	var pair: Array = _fight(5, 25.0)
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	bot.takes_wall = false
	world.player.god_mode = true
	var shakes: Array[float] = []
	world.effects.shake_requested.connect(func(strength: float, _d: float) -> void: shakes.append(strength))
	await _run(world, bot, 40.0, func() -> bool: return not _events(boss, &"slam_bait").is_empty())
	var bait: Array[Dictionary] = _events(boss, &"slam_bait")
	var falls: Array[Dictionary] = _events(boss, &"tower_fall")
	check(bait.size() == 1 and falls.size() == 1 and int(falls[0]["side"]) == int(bait[0]["side"]),
		"a smashed buttress's tower topples on the side its arch leans to")
	if falls.is_empty():
		await sim.free_world(world)
		return
	var tower: GoldenConvergenceTower = boss.slams.towers_down()[0]
	var side: int = tower.side
	var v: float = boss.speed_planned()
	var gate: float = float(bait[0]["gate"])
	# It starts out of view, behind the runner.
	check(tower.foot <= world.player.distance - boss.tuning.tower_behind + 0.01, "it stands out of view as it starts to fall (its foot %.0f m behind the runner)" % (world.player.distance - tower.foot))
	var shakes_before: int = shakes.size()
	var fall_t: float = boss.fight_time()
	await _run(world, bot, 3.0, func() -> bool: return tower.down())
	var down: Array[Dictionary] = _events(boss, &"tower_down")
	check(down.size() == 1 and absf(boss.fight_time() - fall_t - boss.tuning.tower_fall_seconds) < 0.05,
		"it lands in %.1f s (%.2f s)" % [boss.tuning.tower_fall_seconds, boss.fight_time() - fall_t])
	check(shakes.size() > shakes_before, "with a shake")
	# Beside the causeway: its body never reaches over the track.
	var aabb: AABB = tower.global_transform * tower._mesh.get_aabb()
	var inner: float = aabb.position.x if side > 0 else aabb.end.x
	check(side * inner >= world.geo.wall_x() - GoldenConvergenceTower.FLUSH - 0.05 and absf(tower.face_x()) <= world.geo.wall_x(),
		"it lies beside the causeway, its side flush with the wall's face (%.2f, the wall at %.2f)" % [inner, side * world.geo.wall_x()])
	var wall_to: float = gate + v * boss.tuning.tower_wall_seconds
	check(absf(tower.wall_to - wall_to) < 0.01 and tower.wall_from <= gate,
		"its side is a wall from the gate for %.0f s of running (%.0f-%.0f m)" % [boss.tuning.tower_wall_seconds, tower.wall_from, tower.wall_to])
	var open_ok: bool = true
	var x: float = maxf(tower.wall_from, world.player.distance) + 1.0
	while x < wall_to - 1.0:
		open_ok = open_ok and boss.court.is_open(side, x) and not boss.court.blocked(side, x) and not boss.court.is_open(-side, x)
		x += 10.0
	check(open_ok and not boss.court.is_open(side, wall_to + 2.0) and boss.court.blocked(side, wall_to + 5.0),
		"open over its stretch, on its side only, the balustrade past its end")
	# Run on it, then past its end it's gone (clear of the slam's hole first).
	var outer: int = 0 if side < 0 else world.geo.lane_count - 1
	await _run(world, bot, 1.0)
	await _run(world, null, 3.0, func() -> bool:
		if world.player.lane != outer:
			world.player.press(&"move_left" if side < 0 else &"move_right")
		return world.player.lane == outer and world.player.surface == Player.Surface.FLOOR)
	var moves: Array[StringName] = []
	world.player.movement_event.connect(func(kind: StringName) -> void: moves.append(kind))
	await _run(world, null, 0.3)
	world.player.press(&"move_left" if side < 0 else &"move_right")
	await _run(world, null, 0.3)
	check(world.player.surface == Player.Surface.WALL and moves.has(&"wall_enter"), "the runner runs its side as a wall (%s)" % [moves])
	await _run(world, null, (wall_to - world.player.distance) / v + 3.0, func() -> bool: return not _events(boss, &"wall_close").is_empty())
	check(not boss.court.is_open(side, wall_to - 5.0) and _events(boss, &"tower_sink").size() == 1,
		"once the runner is past its end, the wall closes and the tower sinks away")
	moves.clear()
	if world.player.surface == Player.Surface.WALL:
		await _run(world, null, 3.0, func() -> bool: return world.player.surface == Player.Surface.FLOOR)
	await _run(world, null, 0.4)
	world.player.press(&"move_left" if side < 0 else &"move_right")
	await _run(world, null, 0.3)
	check(moves.has(&"wall_blocked") and world.player.surface == Player.Surface.FLOOR, "past it the balustrade bumps the runner back (%s)" % [moves])
	await _run(world, null, boss.tuning.tower_sink_seconds + 0.5)
	check(not tower.in_use() and not tower.visible, "and it's back in the pool")
	await sim.free_world(world)
	# The Screen shake setting off: no shake.
	pair = _fight(5, 25.0)
	world = pair[0]
	boss = pair[1]
	world.effects.shake_scale = 0.0
	world.player.god_mode = true
	shakes.clear()
	world.effects.shake_requested.connect(func(strength: float, _d: float) -> void: shakes.append(strength))
	bot = _bot(boss)
	bot.takes_wall = false
	await _run(world, bot, 40.0, func() -> bool: return not _events(boss, &"tower_down").is_empty())
	check(not _events(boss, &"tower_down").is_empty() and shakes.is_empty(), "with Screen shake off, nothing shakes (%d)" % shakes.size())
	await sim.free_world(world)


# --- The warning ------------------------------------------------------------------------------------------------

## Each slam's warning: the red square and the shadow from its warning to its impact, the grind with them,
## the lock at least slam_lock_seconds before the impact; the fist at its mark as it lands.
func _test_warning() -> void:
	var pair: Array = _fight(5, 18.0, null, 0, "slams,barrage", PackedStringArray(["OAO", "OAO", "OAO"]))
	var world: RunWorld = pair[0]
	var boss: GoldenConvergence = pair[1]
	var bot := _bot(boss)
	var hints: Array[String] = []
	boss.hint_due.connect(func(key: String) -> void: hints.append(key))
	var seen := {"early": [], "square": 0, "shadow_growing": true, "last_scale": {}, "reach": []}
	await _run(world, bot, 30.0, func() -> bool: return not _events(boss, &"slams_done").is_empty(), func() -> void:
		var sl: GoldenConvergenceSlams = boss.slams
		for s: Dictionary in sl.slams:
			var st: int = int(s["stage"])
			var i: int = int(s["fist"])
			if st >= GoldenConvergenceSlams.SlamStage.TRACK and st <= GoldenConvergenceSlams.SlamStage.FALL:
				seen["square"] = int(seen["square"]) + 1
				if not boss.slams.fist.square_on(i) or not boss.slams.fist.shadow_on(i):
					(seen["early"] as Array).append("%.2f: slam %d's warning not shown" % [boss.fight_time(), int(s["n"])])
				var shadow: Node3D = boss.slams.fist.rigs[i]["shadow"]
				var key: String = "%d" % int(s["n"])
				var sc: float = shadow.global_transform.basis.x.length()
				if (seen["last_scale"] as Dictionary).has(key) and sc < float(seen["last_scale"][key]) - 0.001:
					seen["shadow_growing"] = false
				seen["last_scale"][key] = sc
			if st == GoldenConvergenceSlams.SlamStage.HIT and float(s["t"]) <= 0.001:
				(seen["reach"] as Array).append(boss.suit.hand_point(int(s["side"])).distance_to(
					Vector3(float(s["x"]), GoldenConvergenceSlams.CONTACT, TrackGeometry.world_z(float(s["mid"]))))))
	var v: float = boss.speed_planned()
	var warned: Array[Dictionary] = _events(boss, &"slam_warned")
	var locked: Array[Dictionary] = _events(boss, &"slam_locked")
	var impacts: Array[Dictionary] = _events(boss, &"slam_impact")
	var leads_ok: bool = warned.size() == 3 and locked.size() == 3 and impacts.size() == 3
	var least: float = INF
	for k: int in mini(warned.size(), mini(locked.size(), impacts.size())):
		var warn_lead: float = float(impacts[k]["t"]) - float(warned[k]["t"])
		var lock_lead: float = float(impacts[k]["t"]) - float(locked[k]["t"])
		least = minf(least, lock_lead)
		leads_ok = leads_ok and warn_lead >= boss.tuning.slam_track_seconds + boss.tuning.slam_lock_seconds - 0.05 \
			and lock_lead >= boss.tuning.slam_lock_seconds - 0.05
	check(leads_ok, "each fist warns %.1f s before it lands and locks %.1f s before (the least %.2f s)" % [
		boss.tuning.slam_track_seconds + boss.tuning.slam_lock_seconds, boss.tuning.slam_lock_seconds, least])
	check(int(seen["square"]) > 0 and (seen["early"] as Array).is_empty() and bool(seen["shadow_growing"]),
		"the red square and the growing shadow show through every warning: %s" % ", ".join(PackedStringArray((seen["early"] as Array).slice(0, 3))))
	var reach_ok: bool = (seen["reach"] as Array).size() == 3
	for r: Variant in seen["reach"]:
		reach_ok = reach_ok and float(r) < 2.5
	check(reach_ok, "the fist reaches its mark on its telescoping arm as it lands (%s m off)" % [seen["reach"]])
	check(hints.count("golden_boss/fist") == 1, "the fist's hint comes with its first warning")
	await sim.free_world(world)


## E5d polish: the fist's shadow darkens the white marble as much on the Compatibility renderer, which blends in
## sRGB space (the same alpha comes out much darker there), as on Forward+ and Mobile, which blend in linear space:
## a lighter alpha there, as The Magnate's shadow has.
func _test_shadow_renderers() -> void:
	var fwd: float = GoldenConvergenceFist.shadow_alpha_for("forward_plus")
	var compat: float = GoldenConvergenceFist.shadow_alpha_for("gl_compatibility")
	var marble: float = 0.835
	var linear: float = Color(marble, marble, marble).srgb_to_linear().r * (1.0 - fwd)
	var on_fwd: float = Color(linear, linear, linear).linear_to_srgb().r
	var on_compat: float = marble * (1.0 - compat)
	check(is_equal_approx(fwd, GoldenConvergenceFist.SHADOW_ALPHA) and is_equal_approx(GoldenConvergenceFist.shadow_alpha_for("mobile"), fwd)
		and is_equal_approx(compat, GoldenConvergenceMagnate.SHADOW_ALPHA_COMPAT) and absf(on_fwd - on_compat) < 0.03,
		"the fist's shadow is as dark on every renderer: %.2f on Forward+ and Mobile, %.2f on Compatibility (the marble at %.2f, %.2f)" % [
		fwd, compat, on_fwd, on_compat])


func _test_reduced_flashing() -> void:
	var was: bool = Settings.flashing_reduced
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var pair: Array = _fight(5, 18.0, null, 0, "slams,barrage", PackedStringArray(["O", "O", "O"]))
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		world.player.god_mode = true
		var widths: Array[float] = []
		await _run(world, null, 20.0, func() -> bool: return not _events(boss, &"slam_impact").is_empty(), func() -> void:
			var sl: GoldenConvergenceSlams = boss.slams
			if sl.slams.is_empty() or int(sl.slams[0]["stage"]) != GoldenConvergenceSlams.SlamStage.LOCKED:
				return
			var frame: Node3D = boss.slams.fist.rigs[int(sl.slams[0]["fist"])]["frame"][2]
			widths.append(frame.global_transform.basis.x.length()))
		await tree.process_frame
		# The frame only deepens as the warning comes on; the beat on top of it is the flicker.
		var dips: int = 0
		for i: int in range(1, widths.size()):
			if widths[i] < widths[i - 1] - 0.0005:
				dips += 1
		if reduced:
			check(widths.size() > 10 and dips == 0, "with Reduced flashing the red square holds steady, only deepening (%d dips)" % dips)
		else:
			check(dips > 0, "it pulses otherwise (%d dips in %d frames)" % [dips, widths.size()])
		await sim.free_world(world)
	Settings.flashing_reduced = was


# --- The same every attempt ----------------------------------------------------------------------------------------

func _test_same_every_attempt() -> void:
	var logs: Array[String] = []
	for attempt: int in 2:
		var pair: Array = _fight(6, 25.0, null, 1)
		var world: RunWorld = pair[0]
		var boss: GoldenConvergence = pair[1]
		var bot := _bot(boss)
		await _run(world, bot, 30.0)
		logs.append(JSON.stringify(boss.events))
		await sim.free_world(world)
	check(logs[0] == logs[1] and logs[0].length() > 100, "the slams, the bait, the tower and the barrage play the same on every attempt")
