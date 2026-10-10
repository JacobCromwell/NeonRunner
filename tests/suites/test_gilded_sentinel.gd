extends TestSuite
## The Gilded Sentinels (GDD §9.11) in full RunWorlds on real physics, at the reference 18 m/s and the
## Golden Zone's 25 m/s: the warning (its eyes flare, stone grinds, the marks of its cut light up) always
## comes first and lasts its whole time; a wall runner who enters the wall high (a jump onto it) or low
## (early) passes, and one who steps onto it right before it is hit; a floor runner out of the outer lane
## is safe and one in it is hit, standing, jumping or sliding, at 3, 5 and 6 lanes; armor and the shield
## block its swing, the dash passes through it; its body is solid and stands back in its niche, out of
## the wall-run path; 17 laser tier 1 shots bring it down; a wall jump by its head kicks it (a stomp);
## twice and pairs; it takes turns with the other big attacks (it lets the runner pass when one is on);
## Reduced flashing; every attempt plays out the same way. Its look (the statue kit's merged frames, the
## eyes' own material, nothing of it out of its niche), the Golden skins opening its niche, decorative
## statues never at wall-run height, its sounds and hint, its generator rules at 3, 5 and 6 lanes, and
## Golden 2 and the Golden Palace's real layouts. And, for the owner's requests of October 8, 2026 (GDD §9.11,
## task H1): the 0.6 s warning against a runner's 0.35 s reaction (a floor runner leaves the lane in time, a wall
## runner escapes with two moves), the grind as long as the warning, the statue and every statue niche lit (not
## black), the flare's red hue, and no see-through slot beside a live niche at a chunk's end.

const Rules = preload("res://scripts/enemies/gilded_sentinel_rules.gd")
const AttackWatch = preload("res://tools/measure/attack_watch.gd")
const DangerDensity := preload("res://scripts/world/danger_density.gd")
const TURN_DUMMY: String = "res://tests/helpers/turn_dummy.gd"
const GOLDEN_SKIN: String = "res://data/skins/golden_skin.tres"
const PALACE_SKIN: String = "res://data/skins/golden_palace_skin.tres"
const CUT_NAME: String = "Gilded Sentinel's halberd"
## The scripted runs' Sentinel stands here (inside a track chunk), and they run at these speeds.
const AT: float = 60.0
const SPEEDS: Array[float] = [18.0, 25.0]
## Campaign builds, as {id, lanes, seed}, where the danger density pass would add a wall enemy on a
## Sentinel's wall section if it didn't ask the Sentinels' rules (SentinelWallsUnchecked; task K4): the Golden
## Palace at 3 lanes on seed 9024, whose pass would put a window cyborg on the wall section of the Sentinel at
## 2285 m (one of 54 such builds of Golden 2's and the Palace's 720 on seeds 9001-9120 since the H series merged
## main's Casino; the Palace at 3 lanes on seed 9039, task K5's case, the only one of 240 then, and Golden 2 at 5
## lanes on seed 9034, K4's, no longer build that way). Since the owner's October 10, 2026 call (task I1: a Buzz
## Overdrive's encounter shared with the rest of the track), Golden 2 at 5 lanes on seed 9001 (a window cyborg on the
## wall section of the Sentinel at 772 m), re-found where the Palace's case no longer builds that way. Built as
## shipped every Sentinel keeps its rules; built without the check, the problem shows (else re-pin the case).
const SENTINEL_WALL_CASES: Array[Dictionary] = [{"id": "golden/2", "lanes": 5, "seed": 9001}]

var sim: RunSim
var t: GildedSentinelTuning


## A generator whose later passes don't ask the rules where wall enemies may stand (no wall_section_rules):
## its danger density pass adds window cyborgs and vent Screeches as it did before task K4 (SENTINEL_WALL_CASES).
class SentinelWallsUnchecked extends LevelGenerator:
	func wall_section_rules() -> Array[GDScript]:
		return []


func run() -> void:
	sim = RunSim.new(tree, tuning)
	t = EnemyDirector.tuning_for("gilded_sentinel") as GildedSentinelTuning
	check(t != null, "data/enemies/gilded_sentinel.tres is a GildedSentinelTuning")
	if t == null:
		return
	_test_numbers()
	_test_sounds_and_hint()
	_test_decorative_statues()
	_test_lit_niche()
	_test_niche_flare_hue()
	await _test_alcoves_lit()
	await _test_chunk_boundaries()
	_test_open_rects()
	await _test_look()
	await _test_skin_opens_niche()
	await _test_warning_first()
	await _test_floor()
	await _test_wall()
	await _test_reaction()
	await _test_protection()
	await _test_body_solid()
	await _test_weapons()
	await _test_kick()
	await _test_twice_and_pair()
	await _test_takes_turns()
	await _test_attack_watch()
	await _test_reduced_flashing()
	await _test_same_every_attempt()
	_test_placement()
	_test_wall_section()
	_test_campaign()


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


## A world at `speed` with the player in `lane` and a Sentinel for each of `entries` ({at, side,
## swings}), and its Sentinels: [world, Array of GildedSentinel].
func _world(lanes: int, lane: int, speed: float, entries: Array, loadout: Loadout = null, skin_path: String = "",
		config: LevelConfig = null) -> Array:
	var c: LevelConfig = config if config != null else LevelConfig.new()
	c.run_speed = speed
	c.enemy_scaling = 1.0
	if skin_path != "":
		c.skin = load(skin_path) as ZoneSkin
	var w: RunWorld = sim.build_world(RunSim.layout(lanes, 700.0), loadout, null, c)
	w.player.setup(w.tuning, w.geo, lane)
	var made: Array[GildedSentinel] = []
	var seed_value: int = 11
	for e: Dictionary in entries:
		var side: int = int(e.get("side", -1))
		var s := w.director.spawn({"type": "gilded_sentinel", "at": float(e.get("at", AT)), "lane": w.layout.outer_lane(side),
			"side": side, "seed": seed_value, "params": {"swings": int(e.get("swings", 1))}}) as GildedSentinel
		seed_value += 1
		made.append(s)
	await tree.physics_frame
	return [w, made]


## Runs `w` for `seconds` with `actions` ([distance, action] pairs); the result as RunSim.step_world.
func _run(w: RunWorld, seconds: float, actions: Array = []) -> Dictionary:
	return await sim.step_world(w, seconds, actions)


func _count(s: GildedSentinel, event: String) -> int:
	var n: int = 0
	for h: Array in s.history:
		n += 1 if String(h[0]) == event else 0
	return n


## The physics frames a run of `metres` takes at `speed`, plus a second.
func _seconds_to(metres: float, speed: float) -> float:
	return metres / speed + 1.0


# --- Numbers --------------------------------------------------------------------------------------

## The tuning's promises (GDD §9.11, §3): the band sits on the free wall-entry height, a jump onto the
## wall clears its top and an early entry slides below its bottom; the cut over the wall covers a wall
## runner's whole body and the cut over the lane never touches one, nor the lane beside; no jump clears
## the lane's cut; the niche is at wall-run height and holds the statue; 17 laser tier 1 shots.
func _test_numbers() -> void:
	var band: Vector2 = t.band(tuning)
	var half: float = tuning.hurtbox_size.x * 0.5
	var entry: float = tuning.wall_entry_height
	check(band.x < entry - half and band.y > entry + half,
		"a free wall entry's body (%.2f-%.2f m) lies inside the band (%.2f-%.2f m): stepping on right before it is hit"
		% [entry - half, entry + half, band.x, band.y])
	var jump_entry: float = minf(entry + tuning.jump_height * tuning.wall_air_entry_factor, tuning.wall_max_height)
	check(jump_entry - half > band.y + 0.15, "a jump onto the wall (%.2f m) runs above the band with room (%.2f m over it)"
		% [jump_entry, jump_entry - half - band.y])
	check(tuning.wall_exit_height + half < band.x - 0.3, "the end of a wall run (%.2f m) runs well below it"
		% tuning.wall_exit_height)
	check(t.wall_reach >= tuning.hurtbox_size.y + 0.05, "the cut on its wall reaches over a wall runner's whole body (%.2f m)"
		% t.wall_reach)
	var lane_end: float = tuning.wall_margin + tuning.lane_width - t.lane_margin
	var outer_runner: float = tuning.wall_margin + tuning.lane_width * 0.5 - half
	var next_runner: float = tuning.wall_margin + tuning.lane_width * 1.5 - half
	check(t.wall_reach < outer_runner and lane_end > outer_runner + half * 2.0 and lane_end < next_runner,
		"the lane's cut covers a runner in the outer lane (%.2f-%.2f m out) and stops short of the next lane's (%.2f m)"
		% [outer_runner, outer_runner + half * 2.0, next_runner])
	check(band.y > tuning.jump_height + 0.05, "no jump clears the lane's cut (its top %.2f m over a jump's %.2f m)"
		% [band.y, tuning.jump_height])
	# GDD §9.11 (owner, October 8, 2026): the warning is half as long as first built, 0.6 s instead of 1.2 s.
	check(t.warning_seconds >= 0.6 and t.strike_seconds > t.section_length / 25.0 + 0.05,
		"a warning of at least the owner's 0.6 s, and a cut on for longer than a runner takes to cross it at 25 m/s")
	check(t.raise_seconds() > 0.1 and t.raise_seconds() <= t.warning_seconds * 0.6,
		"the halberd's draw-back (%.2f s) leaves the eyes and the grinding a head start in the warning (%.2f s)"
		% [t.raise_seconds(), t.warning_seconds])
	# The keep-out of its attack (the generator's) covers the floor its cut uses (the escape lane's clear lead,
	# escape_lead_seconds, is longer than the owner's 0.6 s warning, GDD §9.11, October 8, 2026), at every speed.
	for speed: float in [18.0, 25.0, 31.0]:
		for swings: int in [1, 2]:
			var window: Vector2 = t.attack_window(AT, swings, speed)
			var use: Vector2 = t.floor_use(AT, swings, speed)
			check(window.x <= use.x + 0.001 and window.x <= t.warn_at(AT, swings, speed) + 0.001
					and is_equal_approx(window.y, t.guarded_stretch(AT, swings).y) and t.claim_window(AT, swings, speed).x <= window.x,
				"its attack window %s covers its warning and the floor it uses %s (%d swings, %.0f m/s)" % [window, use, swings, speed])
	check(t.niche_sill >= 0.0 and t.niche_sill + t.niche_height <= 4.0 and t.niche_sill + t.statue_height() < t.niche_sill + t.niche_height,
		"the niche stands at wall-run height and holds the statue (%.2f-%.2f m)" % [t.niche_sill, t.niche_sill + t.niche_height])
	check(t.health_at(0.0) == 15.0 and t.health_at(1.0) == 15.0 and t.uses_floor,
		"health 15 (17 laser tier 1 shots with G4's rule) and it uses the floor (its cut of the outer lane)")
	check(not LevelConfig.PLANNED_FEATURES.has("gilded_sentinel"), "it's out of LevelConfig.PLANNED_FEATURES: it's built")


## Its three sounds exist with a level each; its warning never varies; its first-encounter hint.
func _test_sounds_and_hint() -> void:
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in [&"gilded_sentinel_grind", &"gilded_sentinel_swing", &"gilded_sentinel_break"]:
		check(library.has_file(sound) and library.volume_db.has(String(sound)), "the sound %s exists with a level" % sound)
	check(not library.pitch_variation.has("gilded_sentinel_grind"), "its warning sounds exactly the same every time")
	# The grind fills the warning (tools/asset_gen/sfx_bank_sentinel.gd: the warning and a tail of 0.15 s): the file
	# has to be regenerated whenever the warning changes (`tools/godot.sh sfx --only=gilded_sentinel_grind`).
	var grind: AudioStream = library.stream(&"gilded_sentinel_grind")
	check(grind != null and absf(grind.get_length() - (t.warning_seconds + 0.15)) < 0.03,
		"its grind lasts its warning and a short tail (%.2f s for a %.2f s warning)"
		% [grind.get_length() if grind != null else 0.0, t.warning_seconds])
	var hints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json"))
	var found: bool = false
	for h: Dictionary in hints.get("hints", []):
		found = found or String(h.get("trigger", "")) == "enemy:gilded_sentinel"
	check(found, "it has a first-encounter hint (enemy:gilded_sentinel)")


## GDD §9.11: decorative statues stand at the wall base, while a statue at wall-run height is a live
## one. The Golden Zone's recessed facade mounts and Golden Palace's base alcoves share that rule.
func _test_decorative_statues() -> void:
	var top: float = tuning.wall_max_height + tuning.hurtbox_size.x * 0.5
	for path: String in [GOLDEN_SKIN, PALACE_SKIN]:
		var skin := load(path) as GoldenSkin
		var lowest: float = INF
		var count: int = 0
		for side: int in [-1, 1]:
			for spot: Dictionary in skin.statue_spots(side, side * 4.5, 0.0, 600.0):
				lowest = minf(lowest, (spot["center"] as Vector3).y)
				count += 1
		var base_y: float = skin.decorative_statue_mount_y()
		check(count > 0 and absf(lowest - base_y) < 0.001 and lowest < top,
			"%s: its %d decorative statues use the wall-base mount at %.1f m, below the wall-run band (%.1f m)"
			% [path.get_file(), count, lowest, top])


## GoldenSkin.open_rects: the wall face less the niches, exactly, with neighbouring pieces sharing edges.
func _test_open_rects() -> void:
	var whole: Array[PackedFloat64Array] = GoldenSkin.open_rects(10.0, 50.0, 0.0, 7.0, [] as Array[Rect2])
	check(whole.size() == 1 and whole[0] == PackedFloat64Array([10.0, 50.0, 0.0, 7.0]), "without a niche, the whole face")
	var hole := Rect2(Vector2(29.3, 0.75), Vector2(1.4, 2.7))
	var pieces: Array[PackedFloat64Array] = GoldenSkin.open_rects(10.0, 50.0, 0.0, 7.0, [hole])
	var area: float = 0.0
	var covers_hole: bool = false
	for r: PackedFloat64Array in pieces:
		area += (r[1] - r[0]) * (r[3] - r[2])
		var mid := Vector2((r[0] + r[1]) * 0.5, (r[2] + r[3]) * 0.5)
		covers_hole = covers_hole or (r[0] < hole.end.x - 0.01 and r[1] > hole.position.x + 0.01
			and r[2] < hole.end.y - 0.01 and r[3] > hole.position.y + 0.01)
		check(mid.x >= 10.0 and mid.x <= 50.0, "a piece lies within the face")
	check(is_equal_approx(area, 40.0 * 7.0 - hole.get_area()) and not covers_hole and pieces.size() == 4,
		"one niche leaves four pieces around it covering the rest exactly (%.3f m2)" % area)
	var edge: Array[PackedFloat64Array] = GoldenSkin.open_rects(30.0, 70.0, 0.0, 7.0, [hole])
	var edge_area: float = 0.0
	for r: PackedFloat64Array in edge:
		edge_area += (r[1] - r[0]) * (r[3] - r[2])
	check(is_equal_approx(edge_area, 40.0 * 7.0 - (hole.end.x - 30.0) * hole.size.y), "a niche straddling the face's start is cut there")


# --- The look -----------------------------------------------------------------------------------------

## The statue: one mesh of two surfaces (the gold, and the eyes with each Sentinel's own glowing red
## material), its frames baked once and shared; at rest nothing of it reaches out of its niche; on both
## walls it swings toward the approaching runner (mirrored on the left wall).
func _test_look() -> void:
	var made: Array = await _world(5, 2, 25.0, [{"side": -1}, {"side": 1, "at": AT + 1.0}], null, GOLDEN_SKIN)
	var w: RunWorld = made[0]
	var left: GildedSentinel = made[1][0]
	var right: GildedSentinel = made[1][1]
	var body_l := left.get_node("Statue/Body") as MeshInstance3D
	var body_r := right.get_node("Statue/Body") as MeshInstance3D
	check(body_l.mesh.get_surface_count() == 2, "the statue is one mesh of two surfaces (gold, eyes)")
	var eyes_l := body_l.get_surface_override_material(1) as StandardMaterial3D
	var eyes_r := body_r.get_surface_override_material(1) as StandardMaterial3D
	check(eyes_l != null and eyes_r != null and eyes_l != eyes_r and eyes_l.emission_enabled
		and eyes_l.emission.r > 0.8 and eyes_l.emission.g < 0.3, "each Sentinel's eyes glow red on a material of its own")
	var kit: GoldenStatue = (w.skin as GoldenSkin).statues()
	var frames_a: Array = GildedSentinel.frames_for(kit, t.statue_scale, true)
	var frames_b: Array = GildedSentinel.frames_for(kit, t.statue_scale, true)
	check(is_same(frames_a, frames_b) and (frames_a[0] as Array)[0] == body_l.mesh,
		"its frames are baked once and shared (the left wall's mirrored)")
	# GDD §9.11 (owner, October 8, 2026): the live statue reads against its niche. Its gold is lifted in albedo
	# like the decorative statues' (and never glows: GDD §5), and its eyes glow a little even at rest.
	var gold_colors: PackedColorArray = body_l.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var never_glows: bool = not gold_colors.is_empty()
	for c: Color in gold_colors:
		never_glows = never_glows and c.a == 0.0
	check(never_glows, "the statue's gold never glows (GDD §5)")
	# The body is the first part baked into the gold (the right wall's frames are not mirrored): compare it with the kit's.
	var raw: PackedColorArray = kit.part(GoldenStatue.Part.BODY).colors
	var lit_gold: PackedColorArray = body_r.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var lifted: float = 0.0
	for i: int in mini(raw.size(), lit_gold.size()):
		lifted = maxf(lifted, lit_gold[i].r - raw[i].r)
	check(absf(lifted - GildedSentinel.STATUE_LIFT) < 0.01,  # vertex colours are stored as bytes
		"its gold is lifted in albedo by the decorative statues' amount (%.3f)" % lifted)
	check(GildedSentinel.EYES_IDLE >= 1.5 and GildedSentinel.EYES_FULL >= 3.0 * GildedSentinel.EYES_IDLE,
		"its eyes glow at rest (%.1f) and flare to much more (%.1f)" % [GildedSentinel.EYES_IDLE, GildedSentinel.EYES_FULL])
	for s: GildedSentinel in [left, right]:
		var niche_glow := s.get_node("NicheGlow") as MeshInstance3D
		var glow_shader: Shader = (niche_glow.material_override as ShaderMaterial).shader
		check(glow_shader.code.contains("blend_mix") and not glow_shader.code.contains("blend_add"),
			"side %d: the flare tints the lit niche red, not adds red to it (it would turn orange)" % s.side)
	for s: GildedSentinel in [left, right]:
		var reach: Vector2 = _statue_reach(s)
		check(reach.x <= 0.001 and reach.y <= t.niche_depth + 0.01,
			"side %d: at rest the statue stands inside its niche (%.2f m out of the face, %.2f m deep)" % [s.side, reach.x, reach.y])
		# GDD §9.11 (owner, October 8, 2026): the live statue and the back of its niche stand further forward.
		# The statue's front is almost flush with the wall face (never in front of it: collision stays physical, a
		# wall runner's body lies along the face), the niche's back is close behind it, and the solid body, which
		# is what a touch would hit, reaches as far back as the statue does.
		check(reach.x >= -(t.statue_inset + 0.01) and reach.x <= 0.001,
			"side %d: the statue's front stands almost flush with the face (%.3f m behind it, statue_inset %.2f)"
			% [s.side, -reach.x, t.statue_inset])
		check(reach.y <= t.niche_depth - 0.03 and t.niche_depth <= 0.8,
			"side %d: the niche's back is close behind the statue (the statue %.2f m deep, the niche %.2f)"
			% [s.side, reach.y, t.niche_depth])
		var body: Hazard = s.body_box()
		var body_front: float = s.side * (body.global_position.x - s.side * body.size.x * 0.5) - w.geo.wall_x()
		var body_back: float = s.side * (body.global_position.x + s.side * body.size.x * 0.5) - w.geo.wall_x()
		check(body_front >= -0.001 and reach.y <= body_back + 0.03,
			"side %d: the solid body stands behind the face and as far back as the statue (%.2f to %.2f m, the statue to %.2f)"
			% [s.side, body_front, body_back, reach.y])
	await sim.free_world(w)


## How far the statue's current frame reaches out of the wall face (x, > 0 = out over the wall-run path)
## and into the wall (y), in metres.
func _statue_reach(s: GildedSentinel) -> Vector2:
	var body := s.get_node("Statue/Body") as MeshInstance3D
	var root := s.get_node("Statue") as Node3D
	var out := Vector2(-INF, -INF)
	# Its real vertices: the bounds of a turned figure's box overstate how deep it stands.
	for si: int in body.mesh.get_surface_count():
		var verts: PackedVector3Array = body.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			var p: Vector3 = root.transform * v
			out.x = maxf(out.x, -s.side * p.x)
			out.y = maxf(out.y, s.side * p.x)
	return out


## The Golden Zone's skin and the Palace's open a Sentinel's niche where one stands (note_wall_enemies):
## the face has a hole there and the recess stands behind it; elsewhere the wall is as before.
func _test_skin_opens_niche() -> void:
	for path: String in [GOLDEN_SKIN, PALACE_SKIN]:
		var skin := load(path) as GoldenSkin
		var face_x: float = -4.5
		# Keep the live niche clear of the decorative alcoves (the Palace's deterministic bay at distance 20, say):
		# a decorative alcove that crowds a live niche is left out (tested below), which would change the count.
		var spots: Array[Dictionary] = skin.statue_spots(-1, face_x, 0.0, 40.0)
		var at: float = 22.0
		while at < 36.0 and not _clear_of_spots(spots, at):
			at += 0.5
		var entry := {"type": "gilded_sentinel", "at": at, "side": -1, "lane": 0}
		var plain := Node3D.new()
		tree.root.add_child(plain)
		skin.note_wall_enemies(-1, 0.0, 40.0, [] as Array[Dictionary])
		skin.wall_section(plain, -1, face_x, 0.0, 40.0)
		var opened := Node3D.new()
		tree.root.add_child(opened)
		var entries: Array[Dictionary] = [entry]
		skin.note_wall_enemies(-1, 0.0, 40.0, entries)
		skin.wall_section(opened, -1, face_x, 0.0, 40.0)
		var hole: Rect2 = GildedSentinel.niche_rect(entry)
		var centre := Vector3(face_x, hole.get_center().y, -hole.get_center().x)
		check(_face_covers(plain, centre, face_x) and not _face_covers(opened, centre, face_x),
			"%s: the wall face covers the spot without a Sentinel, and opens it with one" % path.get_file())
		check(_vertices(opened) > _vertices(plain), "%s: the recess is drawn behind the opening" % path.get_file())
		skin.note_wall_enemies(-1, 0.0, 40.0, [] as Array[Dictionary])
		plain.queue_free()
		opened.queue_free()
		await _test_alcoves_keep_off(skin, path, face_x, spots)
	await tree.process_frame


## GDD §9.11 (owner, October 8, 2026: the live statue and the back of its niche were too hard to see in the
## shadow of the arch): the inside of a statue niche (recess(): the live Sentinel's and the decorative alcoves',
## alike, so the live one is told by its eyes and its warning, USER_REQUESTS.md) is a lit chamber, not a black
## hole: the back and sides well above black as the kit shows them (the colour in linear light times its shade),
## darker than the statue's gold so the figure stands out, plain lit surfaces that never use the glow channel
## (GDD §5), and none of a hazard's colours (red, orange or pink: a bronze, whose hue is far from them).
func _test_lit_niche() -> void:
	var kit := GoldenStatue.new()
	var inside: MeshLayer = kit.recess(t.niche_width, t.niche_height, t.niche_depth)
	check(inside == kit.recess(t.niche_width, t.niche_height, t.niche_depth), "a niche is a cached template")
	var gold: Color = kit.gold
	gold = Color(gold.r + GildedSentinel.STATUE_LIFT, gold.g + GildedSentinel.STATUE_LIFT, gold.b + GildedSentinel.STATUE_LIFT)
	var surfaces: Dictionary = {"LIT_BACK": GoldenStatue.LIT_BACK, "LIT_SIDES": GoldenStatue.LIT_SIDES,
		"LIT_CEILING": GoldenStatue.LIT_CEILING}
	for name: String in surfaces:
		var c: Color = surfaces[name]
		var shown: Color = _shown(c)
		check(shown.get_luminance() >= 0.2 and shown.get_luminance() * 1.15 <= gold.get_luminance(),
			"%s %s shows as %s: well above black (%.2f), and the statue's gold stands out against it (%.2f)"
			% [name, c, shown, shown.get_luminance(), gold.get_luminance()])
		# A bronze: orange-brown but dim (a glowing orange is a hazard's, and the lit kit never glows).
		check(c.s <= 0.6 and c.v <= 0.85, "%s is a muted stone colour, not a hazard's (saturation %.2f, value %.2f)" % [name, c.s, c.v])
	var glows: bool = false
	for i: int in inside.colors.size():
		glows = glows or inside.colors[i].a > 0.0
	check(not glows, "nothing of the niche glows (gold, stone and cloth never do: GDD §5)")
	var darkest: float = 1.0
	for i: int in 30:
		darkest = minf(darkest, _shown(inside.colors[i]).get_luminance())
	check(darkest >= 0.1, "no part of the niche's inside is near black (%.2f)" % darkest)


## How a lit kit surface of colour `c` shows on screen (kit_solid.gdshader: the colour in linear light times a
## shade, GoldenStatue.LIT_SHADE), as a display colour.
func _shown(c: Color) -> Color:
	var lin: Color = c.srgb_to_linear()
	return Color(lin.r * GoldenStatue.LIT_SHADE, lin.g * GoldenStatue.LIT_SHADE, lin.b * GoldenStatue.LIT_SHADE).linear_to_srgb()


## The flare tints the niche red: laid over the bronze, not added to it, and from `NICHE_TINT_RAMP` of the warning
## on the blended colour is Sentinel red, not a hue near the gap edges' orange (about 13 degrees; Sentinel red
## is about 3, the electric fence's pink is far the other way). The blend is worked out in linear light (what the
## renderers blend in) and, as the worst case, in the display's encoding.
func _test_niche_flare_hue() -> void:
	var tint: Color = GildedSentinel.NICHE_TINT
	check(GildedSentinel.niche_tint_alpha(0.0) == 0.0 and GildedSentinel.niche_tint_alpha(1.0) <= 1.0
		and GildedSentinel.niche_tint_alpha(0.3) > GildedSentinel.niche_tint_alpha(0.1), "the tint rises with the flare, from nothing")
	var surfaces: Dictionary = {"back": GoldenStatue.LIT_BACK, "sides": GoldenStatue.LIT_SIDES, "ceiling": GoldenStatue.LIT_CEILING}
	var worst: float = 0.0
	for name: String in surfaces:
		var shown: Color = _shown(surfaces[name])
		var shown_lin: Color = shown.srgb_to_linear()
		for flare: float in [GildedSentinel.NICHE_TINT_RAMP, 0.5, 0.75, 1.0]:
			var a: float = GildedSentinel.niche_tint_alpha(flare)
			var in_light: Color = shown_lin.lerp(tint.srgb_to_linear(), a).linear_to_srgb()
			var on_screen: Color = shown.lerp(tint, a)
			for blended: Color in [in_light, on_screen]:
				var hue: float = blended.h * 360.0
				hue = minf(hue, 360.0 - hue)
				worst = maxf(worst, hue)
				check(hue <= 8.0 and blended.s >= 0.5,
					"the %s at flare %.2f blends to %s: red (hue %.1f degrees, under 8; gap-edge orange is about 13)"
					% [name, flare, blended, hue])
	check(worst <= 8.0, "the flare is Sentinel red over every part of the niche (at worst %.1f degrees)" % worst)
	# What the first build did (added the red) would have been orange: this is why it is a tint.
	var added: Color = GoldenStatue.LIT_BACK.srgb_to_linear() * GoldenStatue.LIT_SHADE + Color(0.9, 0.1, 0.07)
	var added_hue: float = Color(added.r, added.g, added.b).linear_to_srgb().h * 360.0
	check(added_hue > 8.0, "(red added over the bronze would be %.1f degrees: orange-ish)" % added_hue)


## Every statue niche is lit alike: the decorative alcoves too (task H1; USER_REQUESTS.md: they are there so a
## live Sentinel can surprise the player, so it isn't the only lit niche), in both Golden skins.
func _test_alcoves_lit() -> void:
	for path: String in [GOLDEN_SKIN, PALACE_SKIN]:
		var skin := load(path) as GoldenSkin
		var spots: Array[Dictionary] = skin.statue_spots(-1, -4.5, 0.0, 800.0)
		check(not spots.is_empty(), "%s has decorative alcoves on its left wall" % path.get_file())
		if spots.is_empty():
			continue
		var at: float = float(spots[0]["at"])
		var c0: float = floorf(at / TrackBuilder.CHUNK_LENGTH) * TrackBuilder.CHUNK_LENGTH
		var wall := Node3D.new()
		tree.root.add_child(wall)
		skin.note_wall_enemies(-1, c0, c0 + TrackBuilder.CHUNK_LENGTH, [] as Array[Dictionary])
		skin.wall_section(wall, -1, -4.5, c0, c0 + TrackBuilder.CHUNK_LENGTH)
		var lit: bool = false
		var black: bool = false
		for inst: Node in wall.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (inst as MeshInstance3D).mesh
			for si: int in mesh.get_surface_count():
				var colors: PackedColorArray = mesh.surface_get_arrays(si)[Mesh.ARRAY_COLOR]
				for c: Color in colors:
					lit = lit or (absf(c.r - GoldenStatue.LIT_BACK.r) < 0.01 and absf(c.g - GoldenStatue.LIT_BACK.g) < 0.01
						and absf(c.b - GoldenStatue.LIT_BACK.b) < 0.01)
					black = black or (absf(c.r - 0.07) < 0.006 and absf(c.g - 0.06) < 0.006 and absf(c.b - 0.055) < 0.006)
		check(lit and not black, "%s: the decorative alcove at %.1f is lit like a live niche, not the old near-black (lit %s, black %s)"
			% [path.get_file(), at, lit, black])
		wall.queue_free()
	await tree.process_frame


## The wall is built a chunk at a time (TrackBuilder: each chunk notes only its own enemies, then builds its
## wall). A facade statue's alcove across a chunk's end had its hole cut by both chunks but its recess built by
## the one with its middle, so a chunk that left the alcove out for a live niche beside it (crowds_niche) left a
## see-through slot in the other's face. So a facade statue never reaches across a chunk's end
## (GoldenFacades.chunk_straddled), in either skin, and with a live niche just past (and just short of) a
## chunk's end, built as TrackBuilder does, every open point of the face has a recess behind it.
func _test_chunk_boundaries() -> void:
	var chunk: float = TrackBuilder.CHUNK_LENGTH
	for path: String in [GOLDEN_SKIN, PALACE_SKIN]:
		var sk := load(path) as GoldenSkin
		var count: int = 0
		var across: int = 0
		for side: int in [-1, 1]:
			for spot: Dictionary in sk.statue_spots(side, side * 4.5, 0.0, 2000.0):
				count += 1
				# Its opening (2.0 m) and the gold frame (0.12 m each side) across a multiple of the chunk length.
				var at: float = float(spot["at"])
				across += 1 if floorf((at - 1.12) / chunk) != floorf((at + 1.12) / chunk) else 0
		check(count > 0 and across == 0, "%s: none of its %d decorative alcoves reaches across a chunk's end" % [path.get_file(), count])
	var skin := load(GOLDEN_SKIN) as GoldenSkin
	# The reviewer's case first (right wall, a live niche at 401.2 m: a facade statue stood at 400.1), then others.
	var cases: Array = [[400.0, 401.2], [400.0, 398.8]]
	for k: int in [3, 7, 11, 15, 19, 23, 27, 31, 35]:
		cases.append([float(k) * chunk, float(k) * chunk + 1.2])
		cases.append([float(k) * chunk, float(k) * chunk - 1.2])
	var slots: int = 0
	for c: Array in cases:
		for side: int in [1, -1] if c[0] == 400.0 else [1]:
			var bad: int = _open_without_recess(skin, side, side * 4.5, float(c[0]), float(c[1]))
			slots += bad
			check(bad == 0, "the wall on side %d with a live niche at %.1f, built as chunks to %.0f and from it: %d open points of the face have no recess behind"
				% [side, c[1], c[0], bad])
	check(slots == 0, "no see-through slot beside a live niche at a chunk's end (%d cases)" % cases.size())


## Builds the two chunks [boundary - 40, boundary) and [boundary, boundary + 40) of the wall on `side` as
## TrackBuilder does, each noting only its own Sentinel (the one at `niche_at`, if it is in it), and counts the
## sample points near the boundary at wall-run height and below where the face is open (no face in its plane)
## and nothing stands behind it (no recess back): a slot you could see through.
func _open_without_recess(skin: GoldenSkin, side: int, face_x: float, boundary: float, niche_at: float) -> int:
	var chunk: float = TrackBuilder.CHUNK_LENGTH
	var wall := Node3D.new()
	tree.root.add_child(wall)
	for c0: float in [boundary - chunk, boundary]:
		var mine: Array[Dictionary] = []
		if niche_at >= c0 and niche_at < c0 + chunk:
			mine.append({"type": "gilded_sentinel", "at": niche_at, "side": side, "lane": 0})
		skin.note_wall_enemies(side, c0, c0 + chunk, mine)
		skin.wall_section(wall, side, face_x, c0, c0 + chunk)
	skin.note_wall_enemies(side, 0.0, chunk, [] as Array[Dictionary])
	var face: Array[PackedVector2Array] = []
	var behind: Array[PackedVector2Array] = []
	for inst: Node in wall.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (inst as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si: int in mesh.get_surface_count():
			var v: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for i: int in range(0, v.size() - 2, 3):
				var tri := PackedVector2Array([Vector2(v[i].z, v[i].y), Vector2(v[i + 1].z, v[i + 1].y), Vector2(v[i + 2].z, v[i + 2].y)])
				var flat: bool = true
				var deep: bool = true
				for j: int in 3:
					flat = flat and absf(v[i + j].x - face_x) < 0.002
					deep = deep and (v[i + j].x - face_x) * side >= 0.3
				if flat:
					face.append(tri)
				elif deep:
					behind.append(tri)
	var bad: int = 0
	var z: float = boundary - 4.0 + 0.037
	while z < boundary + 4.0:
		var y: float = 0.213
		while y < 3.3:
			var p := Vector2(-z, y)
			if not _in_any(face, p) and not _in_any(behind, p):
				bad += 1
			y += 0.25
		z += 0.1
	wall.queue_free()
	return bad


func _in_any(triangles: Array[PackedVector2Array], p: Vector2) -> bool:
	for tri: PackedVector2Array in triangles:
		if Geometry2D.point_is_inside_triangle(p, tri[0], tri[1], tri[2]):
			return true
	return false


## Spots further than 3.5 m from `at` along the track: a live niche there neither touches nor crowds a
## decorative alcove.
func _clear_of_spots(spots: Array[Dictionary], at: float) -> bool:
	for spot: Dictionary in spots:
		if absf(float(spot["at"]) - at) < 3.5:
			return false
	return true


## A decorative wall-base alcove that would overlap or touch a live Sentinel's niche (less than
## GoldenSkin.NICHE_CLEARANCE of wall between the frames) is left out, hole and statue, so a live niche is never
## overlapped by a decorative one; one further off stays (the live niche is not to stand apart from the
## decorative ones: USER_REQUESTS.md); with no live niche it is there.
func _test_alcoves_keep_off(skin: GoldenSkin, path: String, face_x: float, spots: Array[Dictionary]) -> void:
	var near: Dictionary = {}
	for spot: Dictionary in spots:
		var spot_at: float = float(spot["at"])
		if near.is_empty() and spot_at >= 4.0 and spot_at <= 34.0:
			near = spot
	if near.is_empty():
		return
	var a: float = float(near["at"])
	# A point in the alcove's opening at its end nearer the runner (a live niche over it opens further along).
	var mid := Vector3(face_x, skin.decorative_statue_mount_y() + 1.0, -(a - 0.9))
	var gap: float = t.niche_width * 0.5 + 1.0 + GoldenSkin.NICHE_CLEARANCE
	var cases: Array = [["with no live niche", 1000.0, false], ["a live niche beside it", a + gap - 0.3, true],
		["a live niche over it", a + 0.4, true], ["a live niche well clear of it", a + gap + 0.3, false]]
	for c: Array in cases:
		var wall := Node3D.new()
		tree.root.add_child(wall)
		var entries: Array[Dictionary] = []
		if float(c[1]) < 39.0:
			entries.append({"type": "gilded_sentinel", "at": float(c[1]), "side": -1, "lane": 0})
		skin.note_wall_enemies(-1, 0.0, 40.0, entries)
		skin.wall_section(wall, -1, face_x, 0.0, 40.0)
		var whole: bool = _face_covers(wall, mid, face_x)
		check(whole == bool(c[2]),
			"%s: %s, the decorative alcove at %.1f is %s" % [path.get_file(), c[0], a, "left out" if whole else "open"])
		skin.note_wall_enemies(-1, 0.0, 40.0, [] as Array[Dictionary])
		wall.queue_free()
	await tree.process_frame


## True if a triangle of the meshes under `root` lies in the wall plane at `face_x` over `point`.
func _face_covers(root: Node, point: Vector3, face_x: float) -> bool:
	for inst: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (inst as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si: int in mesh.get_surface_count():
			var v: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for i: int in range(0, v.size() - 2, 3):
				if absf(v[i].x - face_x) > 0.002 or absf(v[i + 1].x - face_x) > 0.002 or absf(v[i + 2].x - face_x) > 0.002:
					continue
				if Geometry2D.point_is_inside_triangle(Vector2(point.z, point.y), Vector2(v[i].z, v[i].y),
						Vector2(v[i + 1].z, v[i + 1].y), Vector2(v[i + 2].z, v[i + 2].y)):
					return true
	return false


func _vertices(root: Node) -> int:
	var n: int = 0
	for inst: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (inst as MeshInstance3D).mesh
		if mesh != null:
			for si: int in mesh.get_surface_count():
				n += mesh.surface_get_array_len(si)
	return n


# --- The warning comes first ----------------------------------------------------------------------

## Its warning (the grind, the eyes' flare, the marks) starts before its cut and runs its whole length
## first; the cut is live for strike_seconds while the runner is in its stretch; nothing hurts before.
func _test_warning_first() -> void:
	for speed: float in SPEEDS:
		var made: Array = await _world(3, 1, speed, [{"side": -1}])
		var w: RunWorld = made[0]
		var s: GildedSentinel = made[1][0]
		var warn_t: float = -1.0
		var first_cut_t: float = -1.0
		var cut_d: float = -1.0
		var flared: bool = false
		var marks_lit: bool = false
		var live_frames: int = 0
		var clean_before: bool = true
		w.player.running = true
		for i: int in int(_seconds_to(AT + 5.0, speed) * 60.0):
			await tree.physics_frame
			if warn_t < 0.0 and s.state == GildedSentinel.State.WARNING:
				warn_t = w.level_time()
			if s.cutting():
				live_frames += 1
				if first_cut_t < 0.0:
					first_cut_t = w.level_time()
					cut_d = w.player.distance
			elif warn_t >= 0.0 and first_cut_t < 0.0:
				flared = flared or s.flare > 0.9
				marks_lit = marks_lit or (s.get_node("Marks0") as MeshInstance3D).visible
			if first_cut_t < 0.0 and warn_t < 0.0:
				for boxes: Array in s.cut_boxes():
					for h: Hazard in boxes:
						clean_before = clean_before and not h.is_active()
		var tag: String = "(%.0f m/s)" % speed
		check(warn_t >= 0.0 and first_cut_t > warn_t + t.warning_seconds - 0.02,
			"the warning comes first and runs its whole %.1f s before the cut (%.2f s) %s" % [t.warning_seconds,
				first_cut_t - warn_t, tag])
		check(clean_before, "nothing of its cut is live before its warning " + tag)
		check(s.sounds.size() >= 2 and s.sounds[0][0] == &"gilded_sentinel_grind" and absf(float(s.sounds[0][1]) - warn_t) < 0.05,
			"stone grinds as the warning starts " + tag)
		check(flared and marks_lit, "its eyes flare and the marks of its cut light up during the warning " + tag)
		var stretch: Vector2 = t.swing_stretch(AT, 1, 0)
		check(cut_d <= stretch.x and cut_d >= stretch.x - t.strike_lead_seconds * speed - 1.0,
			"the cut starts as the runner reaches its stretch (%.1f m, the stretch from %.1f) %s" % [cut_d, stretch.x, tag])
		var expected: int = roundi(t.strike_seconds * 60.0)
		check(absi(live_frames - expected) <= 2, "it's live for %.2f s (%d frames) %s" % [t.strike_seconds, live_frames, tag])
		await sim.free_world(w)


# --- The floor: the outer lane is cut, the others are safe ------------------------------------------

func _test_floor() -> void:
	# [lanes, side, the runner's lane, what they do, hit]
	var cases: Array = [[3, -1, 0, "", true], [3, -1, 1, "", false], [3, 1, 2, "", true], [3, 1, 1, "", false],
		[5, 1, 4, "", true], [5, 1, 3, "", false], [6, -1, 0, "", true], [6, -1, 1, "", false],
		[3, -1, 0, "jump", true], [3, -1, 0, "slide", true], [6, 1, 5, "jump", true]]
	for speed: float in SPEEDS:
		for case: Array in cases:
			var made: Array = await _world(case[0], case[2], speed, [{"side": case[1]}])
			var w: RunWorld = made[0]
			var s: GildedSentinel = made[1][0]
			var actions: Array = []
			var stretch: Vector2 = t.swing_stretch(AT, 1, 0)
			if case[3] == "jump":
				# At the top of a jump as the cut comes.
				actions.append([stretch.x - (t.strike_lead_seconds + 0.3) * speed, &"jump"])
			elif case[3] == "slide":
				actions.append([stretch.x - (t.strike_lead_seconds + 0.25) * speed, &"slide"])
			var r: Dictionary = await _run(w, _seconds_to(AT + 8.0, speed), actions)
			var tag: String = "(%d lanes, Sentinel on side %d, runner in lane %d%s, %.0f m/s)" % [case[0], case[1], case[2],
				", " + String(case[3]) if case[3] != "" else "", speed]
			if case[4]:
				check(not r["alive"] and r["cause"] == CUT_NAME, "a runner in the outer lane is cut %s (%s)" % [tag, r["cause"]])
			else:
				check(r["alive"] and _count(s, "swing") == 1, "a runner out of the outer lane is safe as it swings " + tag)
			await sim.free_world(w)


# --- The wall: above or below by timing the wall entry ---------------------------------------------

## The runner starts in the outer lane by its wall: stepping onto the wall right before it puts them in
## the band (hit); jumping onto it (an entry from the top of a jump) runs above it; stepping on early
## slides below it.
func _test_wall() -> void:
	for speed: float in SPEEDS:
		for side: int in [-1, 1]:
			for route: String in ["late", "high", "low"]:
				var lanes: int = 5
				var made: Array = await _world(lanes, 0 if side < 0 else lanes - 1, speed, [{"side": side}])
				var w: RunWorld = made[0]
				var s: GildedSentinel = made[1][0]
				var r: Dictionary = await _run(w, _seconds_to(AT + 6.0, speed), _wall_route(route, side, speed))
				var tag: String = "(route %s, side %d, %.0f m/s)" % [route, side, speed]
				check(r["events"].has(&"wall_enter"), "the runner gets onto the wall " + tag)
				if route == "late":
					check(not r["alive"] and r["cause"] == CUT_NAME, "stepping onto the wall right before it, the runner is cut %s (%s)"
						% [tag, r["cause"]])
				else:
					check(r["alive"] and _count(s, "swing") == 1, "the runner passes %s the swing %s" % ["above" if route == "high"
						else "below", tag])
				await sim.free_world(w)


# --- The 0.6 s warning against a runner's reaction ---------------------------------------------------

## The reaction time the boss suites use (a runner sees the warning and starts a move this long after it).
const REACTION: float = 0.35


## GDD §9.11 (owner, October 8, 2026): the warning is 0.6 s, half as long as first built. What that leaves a runner
## who reacts after REACTION (0.35 s, as the boss suites assume):
## - on the floor in the outer lane: a lane change started then gets them out of the cut in time (both walls, 3 and
##   6 lanes, at 18 and 25 m/s);
## - on the wall in the band (they stepped onto it before the warning, so they saw none before it): a move off the
##   wall alone leaves them in the outer lane's cut, but a move off the wall at REACTION and a lane change
##   started by REACTION + 0.15 s, both within the 0.6 s, get them clear; a jump or a slide on the floor doesn't
##   do it (the lane's cut reaches above any jump);
## - passing above or below the band by timing the wall entry has to be planned from the statue at rest: the
##   scripted "high" route starts its jump as the warning begins (the jump to the wall takes the whole warning).
func _test_reaction() -> void:
	for speed: float in SPEEDS:
		var warn: float = t.warn_at(AT, 1, speed)
		for lanes: int in [3, 6]:
			for side: int in [-1, 1]:
				var lane: int = 0 if side < 0 else lanes - 1
				var inward: StringName = &"move_right" if side < 0 else &"move_left"
				var tag: String = "(%d lanes, side %d, %.0f m/s)" % [lanes, side, speed]
				# On the floor: a lane change started REACTION after the warning begins is in time...
				var made: Array = await _world(lanes, lane, speed, [{"side": side}])
				var w: RunWorld = made[0]
				var s: GildedSentinel = made[1][0]
				var r: Dictionary = await _run(w, _seconds_to(AT + 8.0, speed), [[warn + REACTION * speed, inward]])
				check(r["alive"] and _count(s, "swing") == 1 and _count(s, "warning") == 1,
					"a runner who leaves the outer lane %.2f s after the warning begins is safe %s (%s)" % [REACTION, tag, r["cause"]])
				await sim.free_world(w)
				# ... and one that doesn't is cut.
				made = await _world(lanes, lane, speed, [{"side": side}])
				w = made[0]
				s = made[1][0]
				r = await _run(w, _seconds_to(AT + 8.0, speed), [])
				check(not r["alive"] and r["cause"] == CUT_NAME, "one who stays is cut %s (%s)" % [tag, r["cause"]])
				await sim.free_world(w)
		# On the wall (5 lanes), stepped on 0.3 s before the warning.
		for side: int in [-1, 1]:
			var lanes: int = 5
			var lane: int = 0 if side < 0 else lanes - 1
			var toward: StringName = &"move_left" if side < 0 else &"move_right"
			var away: StringName = &"move_right" if side < 0 else &"move_left"
			var enter: float = warn - 0.3 * speed
			var tag: String = "(side %d, %.0f m/s)" % [side, speed]
			# [what they do at REACTION, then at REACTION + 0.15 s, escapes?]
			var plans: Array = [["steps off the wall then changes lane", [[warn + REACTION * speed, away], [warn + (REACTION + 0.15) * speed, away]], true],
				["steps off the wall and stays", [[warn + REACTION * speed, away]], false],
				["does nothing", [], false]]
			for plan: Array in plans:
				var made: Array = await _world(lanes, lane, speed, [{"side": side}])
				var w: RunWorld = made[0]
				var s: GildedSentinel = made[1][0]
				var acts: Array = [[enter, toward]]
				acts.append_array(plan[1])
				var r: Dictionary = await _run(w, _seconds_to(AT + 8.0, speed), acts)
				check(r["events"].has(&"wall_enter") and _count(s, "warning") == 1 and (r["alive"] == bool(plan[2])),
					"a wall runner who %s %s: %s" % [plan[0], tag, "safe" if r["alive"] else "cut (%s)" % r["cause"]])
				await sim.free_world(w)
	# The "high" route's jump: it starts as the warning does, so this dodge is planned from the statue at rest.
	var lead: float = tuning.wall_entry_time + 0.08 + tuning.jump_time_to_apex
	check(lead >= t.warning_seconds - 0.02, "the jump of a run above the band takes the whole warning (%.2f s of %.2f s): plan it before it" % [lead, t.warning_seconds])


## The scripted actions for a route onto the wall on `side` past a Sentinel at AT (see _test_wall).
func _wall_route(route: String, side: int, speed: float) -> Array:
	var toward: StringName = &"move_left" if side < 0 else &"move_right"
	var stretch: Vector2 = t.swing_stretch(AT, 1, 0)
	var strike_at: float = stretch.x - t.strike_lead_seconds * speed
	match route:
		"late":
			return [[strike_at - 0.35 * speed, toward]]
		"high":
			# Onto the wall from the top of a jump, done before the cut starts and high enough all through it. With the
			# 0.6 s warning this starts the jump exactly as the warning begins (the wall entry, 0.08 s and the jump's apex
			# time are 0.6 s, _test_reaction checks it): a run above the band is planned from the statue at rest.
			var enter: float = strike_at - (tuning.wall_entry_time + 0.08) * speed
			return [[enter - tuning.jump_time_to_apex * speed, &"jump"], [enter, toward]]
		"low":
			return [[stretch.x - 1.6 * speed, toward]]
	return []


# --- Protection -------------------------------------------------------------------------------------

## GDD §9.11: armor blocks the halberd (and the shield); the dash passes through the cut unharmed and
## leaves the Sentinel standing (a cut isn't its body).
func _test_protection() -> void:
	for kind: String in ["armor", "shield", "dash"]:
		var loadout: Loadout = _loadout({"armor": 1}) if kind == "armor" else (_loadout({"shield": 1}) if kind == "shield" else null)
		var made: Array = await _world(3, 0, 25.0, [{"side": -1}], loadout)
		var w: RunWorld = made[0]
		var s: GildedSentinel = made[1][0]
		var history: Array = s.history
		var downed: Array[bool] = [false]
		s.defeated.connect(func(_e: Enemy, _c: StringName) -> void: downed[0] = true)
		var outcomes: Array[int] = []
		for boxes: Array in s.cut_boxes():
			for h: Hazard in boxes:
				h.contacted.connect(func(o: int) -> void: outcomes.append(o))
		var actions: Array = []
		if kind == "dash":
			w.player.running = true
			await _run(w, (t.swing_stretch(AT, 1, 0).x - 4.0) / 25.0)
			w.player.start_dash(0.8, 4.0)
		var r: Dictionary = await _run(w, _seconds_to(AT + 8.0, 25.0), actions)
		match kind:
			"armor":
				check(r["alive"] and outcomes.has(DamageRules.Outcome.BLOCKED_ARMOR) and not w.player.armor_state.is_up(),
					"armor blocks the halberd (and breaks) %s" % [outcomes])
			"shield":
				check(r["alive"] and outcomes.has(DamageRules.Outcome.BLOCKED_SHIELD) and w.player.shield == 0,
					"the shield blocks the halberd %s" % [outcomes])
			"dash":
				var swung: int = 0
				for h: Array in history:
					swung += 1 if String(h[0]) == "swing" else 0
				check(r["alive"] and not downed[0] and swung == 1, "the dash passes through the cut, and leaves it standing")
		await sim.free_world(w)


# --- Its body is solid, and stands back in its niche ---------------------------------------------------

func _test_body_solid() -> void:
	var made: Array = await _world(3, 1, 25.0, [{"side": -1}, {"side": 1}])
	var w: RunWorld = made[0]
	for s: GildedSentinel in made[1]:
		var body: Hazard = s.body_box()
		var armored := DamageRules.Defense.new()
		armored.armor = true
		var shielded := DamageRules.Defense.new()
		shielded.shield = true
		check(body.is_solid and body.part == &"body" and DamageRules.resolve(body, armored) == DamageRules.Outcome.KILL,
			"its body is solid: armor doesn't stop a touch (side %d)" % s.side)
		check(DamageRules.resolve(body, shielded) == DamageRules.Outcome.BLOCKED_SHIELD, "the shield does (side %d)" % s.side)
		var cut: Hazard = s.cut_boxes()[0][0]
		cut.set_enabled(true)
		check(cut.is_enemy_attack and DamageRules.resolve(cut, armored) == DamageRules.Outcome.BLOCKED_ARMOR,
			"its cut is an enemy attack that armor blocks (side %d)" % s.side)
		cut.set_enabled(false)
		# Behind the wall face: out of the wall-run path (a wall runner's body lies along the face).
		var street_face: float = s.side * (body.global_position.x - s.side * body.size.x * 0.5)
		check(street_face >= w.geo.wall_x() - 0.001,
			"its body stands back in its niche, behind the wall face (side %d: %.2f m from the middle, the face at %.2f)"
			% [s.side, street_face, w.geo.wall_x()])
	await sim.free_world(w)


# --- Weapons ------------------------------------------------------------------------------------------

## 17 laser tier 1 shots (GDD §9.11: health 15, G4's tier 1 rule adds two), through the real weapon's
## damage; auto-fire can target it; down, its eyes go dark, its cut goes and it counts as a kill.
func _test_weapons() -> void:
	var made: Array = await _world(3, 1, 25.0, [{"side": -1}], _loadout({"weapon": 1}))
	var w: RunWorld = made[0]
	var s: GildedSentinel = made[1][0]
	check(is_equal_approx(s.max_health, 15.0) and s.targetable(), "health 15, and weapons can target it")
	var controller := w.powerups as PowerupController
	controller.weapon.tier = 1
	var dmg: float = controller.weapon.damage(s)
	for i: int in 16:
		s.take_damage(dmg, &"weapon")
	check(s.alive, "16 laser tier 1 shots leave it standing")
	s.take_damage(dmg, &"weapon")
	check(not s.alive and s.state == GildedSentinel.State.DOWN, "the 17th brings it down")
	await tree.physics_frame
	await tree.process_frame
	var dark: bool = (s.get_node("Statue/Body") as MeshInstance3D).get_surface_override_material(1).emission_energy_multiplier < 0.01
	check(dark and not s.cutting() and not s.is_major_attack_active() and w.score.kills == 1,
		"its eyes go dark, its cut is gone and it counts as a kill")
	await sim.free_world(w)
	# Auto-fire at tier 1 targets it within its reach.
	made = await _world(3, 0, 25.0, [{"side": -1, "at": 30.0}], _loadout({"weapon": 1}))
	w = made[0]
	s = made[1][0]
	var range_m: float = PowerupTuning.at_tier(w.powerup_tuning.weapon_range, 1)
	check(w.director.targets_ahead(w.player.position + Vector3.UP, range_m).has(s), "auto-fire can pick it out in its niche")
	await sim.free_world(w)


# --- The kick: a stomp from a wall jump --------------------------------------------------------------

## GDD §9.11 (proposed): running its wall above its band (onto it from a jump), a wall jump right by its
## head kicks its helmet: DamageRules' stomp (it's defeated, the runner bounces up). One made further off
## does nothing.
func _test_kick() -> void:
	for speed: float in SPEEDS:
		for side: int in [-1, 1]:
			for near: bool in [true, false]:
				var made: Array = await _world(3, 0 if side < 0 else 2, speed, [{"side": side}])
				var w: RunWorld = made[0]
				var s: GildedSentinel = made[1][0]
				var actions: Array = _wall_route("high", side, speed)
				# Too far: past its stretch (a wall jump before it would land the runner in its live cut).
				actions.append([AT - 0.5 if near else t.swing_stretch(AT, 1, 0).y + 1.5, &"jump"])
				var cause: Array = [&""]
				s.defeated.connect(func(_e: Enemy, c: StringName) -> void: cause[0] = c)
				var r: Dictionary = await _run(w, _seconds_to(AT + 6.0, speed), actions)
				var tag: String = "(side %d, %.0f m/s)" % [side, speed]
				if near:
					check(r["alive"] and cause[0] == &"stomp" and r["events"].has(&"stomp") and w.score.kills == 1,
						"a wall jump by its head kicks it down %s (%s)" % [tag, cause[0]])
				else:
					check(r["alive"] and s.alive, "a wall jump further off doesn't " + tag)
				await sim.free_world(w)


# --- Twice, and pairs ---------------------------------------------------------------------------------

## A Sentinel that swings twice cuts the stretch before its niche, then swings back across the one past
## it, each as the runner reaches it; a pair cuts both outer lanes and both walls at once, and at 3 lanes
## the middle lane is the safe one.
func _test_twice_and_pair() -> void:
	for speed: float in SPEEDS:
		var made: Array = await _world(3, 1, speed, [{"side": -1, "swings": 2}])
		var w: RunWorld = made[0]
		var s: GildedSentinel = made[1][0]
		var swings: Array = []
		w.player.running = true
		for i: int in int(_seconds_to(AT + 8.0, speed) * 60.0):
			await tree.physics_frame
			for k: int in 2:
				if s.cutting(k) and swings.size() == k:
					swings.append(w.player.distance)
		var tag: String = "(%.0f m/s)" % speed
		check(swings.size() == 2 and swings[0] < t.swing_stretch(AT, 2, 0).x + 0.5 and swings[1] < t.swing_stretch(AT, 2, 1).x + 0.5
			and swings[1] > swings[0], "it swings twice, each as the runner reaches its half of the stretch %s %s" % [swings, tag])
		await sim.free_world(w)
		for lane: int in 3:
			made = await _world(3, lane, speed, [{"side": -1}, {"side": 1}])
			w = made[0]
			var r: Dictionary = await _run(w, _seconds_to(AT + 8.0, speed))
			check(r["alive"] == (lane == 1), "a pair across the street: lane %d is %s %s" % [lane, "safe" if lane == 1 else "cut", tag])
			await sim.free_world(w)


# --- Big attacks take turns ---------------------------------------------------------------------------

## GDD §9: its attack is a big one, from its eyes' flare until its last swing is over, and it can't wait,
## so it claims its turn claim_seconds before its warning: another type's attack that gets ready from
## then on waits for it. One already on before its claim and still on as its warning would start makes
## it let the runner pass (no warning, no swing); its cut never overlaps another's attack. With the
## switch off it attacks regardless.
func _test_takes_turns() -> void:
	var speed: float = 25.0
	# Far enough along that its claim starts well into the run.
	var at: float = AT + 100.0
	var warn_s: float = t.warn_at(at, 1, speed) / speed
	var claim_s: float = warn_s - t.claim_seconds
	check(t.claim_seconds > 0.0, "it claims its turn before its warning (%.2f s)" % t.claim_seconds)
	# [name, the other's first ready (s), its warning + attack (s), turns on]
	var cases: Array = [["claims its turn", claim_s + 0.5, 1.0, true], ["the other waits", warn_s + 0.3, 0.4, true],
		["passes", claim_s - 0.5, t.claim_seconds + 1.5, true], ["switch off", warn_s - 0.6, 2.5, false]]
	for case: Array in cases:
		var config := LevelConfig.new()
		var made: Array = await _world(3, 1, speed, [{"side": -1, "at": at}], null, "", config)
		var w: RunWorld = made[0]
		var s: GildedSentinel = made[1][0]
		w.rules = w.rules.duplicate() as GameRules
		w.rules.big_attacks_take_turns = case[3]
		var dummy := w.director.spawn({"type": "turn_dummy", "script": TURN_DUMMY, "at": 400.0, "lane": 1, "seed": 2,
			"params": {"first": case[1], "interval": 100.0, "warning": float(case[2]) * 0.4, "attack": float(case[2]) * 0.6}})
		var overlap: bool = false
		var claimed_at: float = -1.0
		var claim_early: bool = false
		w.player.running = true
		for i: int in int(_seconds_to(at + 6.0, speed) * 60.0):
			await tree.physics_frame
			# Its own attack, not its claim: the cut and its warning.
			var attacking: bool = s.is_major_attack_active() and not s.claiming()
			overlap = overlap or (attacking and dummy.is_major_attack_active())
			if s.claiming() and claimed_at < 0.0:
				claimed_at = w.level_time()
			claim_early = claim_early or (s.is_major_attack_active() and w.level_time() < claim_s - 0.1)
		var tag: String = "(%s)" % case[0]
		var held: bool = false
		for h: Array in dummy.history:
			held = held or String(h[0]) == "held"
		match case[0]:
			"claims its turn":
				check(absf(claimed_at - claim_s) < 0.1 and not claim_early,
					"it claims its turn claim_seconds before its warning (at %.2f s, %.2f s expected)" % [claimed_at, claim_s])
				check(_count(s, "swing") == 1 and held and not overlap,
					"another type's attack that gets ready during its claim waits for it %s %s" % [s.history, dummy.history])
			"the other waits":
				check(_count(s, "swing") == 1 and held and not overlap, "its attack goes, and the other waits for it " + tag)
			"passes":
				check(_count(s, "pass") == 1 and _count(s, "warning") == 0 and _count(s, "swing") == 0 and not overlap
					and not held, "with another's attack on since before its claim, it lets the runner pass %s" % [s.history])
				check(not s.is_major_attack_active(), "and its claim is over " + tag)
			"switch off":
				check(_count(s, "swing") == 1 and _count(s, "pass") == 0, "with turns off it attacks regardless " + tag)
		await sim.free_world(w)


## R3's turn-taking tool (tools/measure/attack_watch.gd) reads its state, never is_major_attack_active:
## AttackWatch.open_kinds reports "sentinel_strike" from its warning through its swing, empty before and
## after, and AttackWatch.observe() counts exactly one over the whole attack.
func _test_attack_watch() -> void:
	var made: Array = await _world(3, 1, 25.0, [{"side": -1}])
	var w: RunWorld = made[0]
	var s: GildedSentinel = made[1][0]
	var watch := AttackWatch.new(w)
	var open_before: bool = false
	var open_during: bool = true
	var open_after: bool = false
	w.player.running = true
	for i: int in int(_seconds_to(AT + 5.0, 25.0) * 60.0):
		await tree.physics_frame
		watch.observe()
		var kinds: Array[String] = AttackWatch.open_kinds(s)
		if s.state == GildedSentinel.State.IDLE:
			open_before = open_before or not kinds.is_empty()
		elif s.state in [GildedSentinel.State.WARNING, GildedSentinel.State.HOLD, GildedSentinel.State.STRIKE]:
			open_during = open_during and kinds == ["sentinel_strike"]
		elif s.state in [GildedSentinel.State.RECOVER, GildedSentinel.State.DONE]:
			open_after = open_after or not kinds.is_empty()
	check(not open_before, "AttackWatch sees nothing open before its warning")
	check(open_during, "AttackWatch sees sentinel_strike open from the warning through the swing")
	check(not open_after, "AttackWatch sees nothing open once it's recovered")
	check(int(watch.attacks.get("sentinel_strike", 0)) == 1, "AttackWatch counts its one strike (%s)" % watch.attacks)
	await sim.free_world(w)


# --- Reduced flashing ---------------------------------------------------------------------------------

## Its eyes rise steadily (no throb) and a swing's flash is softer with Reduced flashing.
func _test_reduced_flashing() -> void:
	var peaks: Array[float] = []
	for reduced: bool in [false, true]:
		Settings.flashing_reduced = reduced
		var made: Array = await _world(3, 1, 25.0, [{"side": -1}])
		var w: RunWorld = made[0]
		var s: GildedSentinel = made[1][0]
		var eyes := (s.get_node("Statue/Body") as MeshInstance3D).get_surface_override_material(1) as StandardMaterial3D
		var last: float = -1.0
		var steady: bool = true
		var peak: float = 0.0
		w.player.running = true
		for i: int in int(_seconds_to(AT + 4.0, 25.0) * 60.0):
			await tree.process_frame
			await tree.physics_frame
			if s.state == GildedSentinel.State.WARNING:
				var e: float = eyes.emission_energy_multiplier
				steady = steady and e >= last - 0.001
				last = e
			var slash := s.get_node("Slash0") as MeshInstance3D
			peak = maxf(peak, float((slash.material_override as ShaderMaterial).get_shader_parameter(&"flash")))
		peaks.append(peak)
		if reduced:
			check(steady, "with Reduced flashing its eyes rise steadily through the warning")
		await sim.free_world(w)
	Settings.flashing_reduced = false
	check(peaks[1] < peaks[0] and peaks[1] > 0.0, "a swing's flash is softer with Reduced flashing (%.2f against %.2f)" % [peaks[1], peaks[0]])


# --- The same every attempt ---------------------------------------------------------------------------

func _test_same_every_attempt() -> void:
	var runs: Array = []
	for attempt: int in 2:
		var made: Array = await _world(5, 0, 25.0, [{"side": -1, "swings": 2}, {"side": 1, "at": AT + 80.0}])
		var w: RunWorld = made[0]
		# Their histories, kept by reference: a Sentinel leaves play (and is freed) once far behind.
		var histories: Array = []
		for s: GildedSentinel in made[1]:
			histories.append(s.history)
		await _run(w, _seconds_to(AT + 90.0, 25.0), _wall_route("low", -1, 25.0))
		var log: Array = []
		for history: Array in histories:
			for h: Array in history:
				log.append("%s@%.3f/%.2f" % [h[0], h[1], h[2]])
		runs.append(log)
		await sim.free_world(w)
	check(runs[0] == runs[1] and not (runs[0] as Array).is_empty(), "every attempt plays out the same way (%d events)" % (runs[0] as Array).size())


# --- Placement --------------------------------------------------------------------------------------------

## Its generator rules on hand-built layouts at 3, 5 and 6 lanes: what may stand on its wall section, the
## lane beside its cut, what may run meanwhile, ramps, ceilings, chunks, other Sentinels; the wall fences
## keep off its wall section; the introduction swings once, alone.
func _test_placement() -> void:
	for lanes: int in [3, 5, 6]:
		for side: int in [-1, 1]:
			var tag: String = "(%d lanes, side %d)" % [lanes, side]
			var at: float = 220.0
			var outer: int = _outer(lanes, side)
			var escape: int = outer - side
			check(_problem(lanes, side, at, {}) == "", "a clear spot is fine " + tag)
			check(_problem(lanes, side, at, {"signs": [{"side": side, "start": at - 40.0, "end": at - 36.0, "bottom": 0.0, "top": 6.0}]})
				.contains("sign"), "no sign on its wall section " + tag)
			check(_problem(lanes, side, at, {"signs": [{"side": -side, "start": at - 40.0, "end": at - 36.0, "bottom": 0.0, "top": 6.0}]})
				== "", "a sign on the other wall is fine " + tag)
			check(_problem(lanes, side, at, {"enemies": [{"type": "window_cyborg", "at": at - 20.0, "lane": outer, "side": side}]})
				.contains("window cyborg"), "no window cyborg on its wall section " + tag)
			check(_problem(lanes, side, at, {"gaps": [{"lane": escape, "start": at - 4.0, "end": at - 1.0}]}).contains("hole"),
				"never when the outer lane is the only safe lane: the lane beside its cut holds no hole " + tag)
			check(_problem(lanes, side, at, {"fences": [RunSim.fence(escape, at - 6.0, "full")]}).contains("fence"),
				"nor a fence " + tag)
			check(_problem(lanes, side, at, {"gaps": [{"lane": outer, "start": at - 30.0, "end": at - 27.0}]}) == "",
				"a hole in the outer lane itself is no matter " + tag)
			check(_problem(lanes, side, at, {"ramps": [{"side": side, "at": at - 30.0}]}).contains("ramp"),
				"a ramp whose wall run slides into its band is " + tag)
			check(_problem(lanes, side, at, {"ramps": [{"side": side, "at": at - 2.0}]}).contains("ramp"),
				"and so is one in the outer lane by its stretch " + tag)
			check(_problem(lanes, side, at, {"ramps": [{"side": side, "at": at - 160.0}]}) == "",
				"a ramp whose wall run is over long before it is fine " + tag)
			check(_problem(lanes, side, at, {"hulls": [{"start": at - 70.0, "end": at - 20.0}]}).contains("landing"),
				"no ceiling's landing zone in its window " + tag)
			check(_problem(lanes, side, at, {"enemies": [{"type": "octodog", "at": at, "lane": _outer(lanes, -side), "side": 0,
				"params": {"floor_span": Vector2(at - 40.0, at + 5.0)}}]}).contains("big attack"), "no Octodog run meanwhile " + tag)
			check(_problem(lanes, side, 279.6, {}).contains("chunk") and is_equal_approx(Rules.in_chunk(t, 279.6),
				280.0 - t.niche_width * 0.5 - Rules.CHUNK_MARGIN), "its niche stays within a track chunk " + tag)
			check(_problem(lanes, side, at, {"pads": [{"lane": outer, "at": at - 12.0}]}).contains("pad"),
				"its cut keeps off an anti-grav pad's way " + tag)
			var other_same := {"type": "gilded_sentinel", "at": at - 25.0, "lane": outer, "side": side, "params": {"swings": 1}}
			check(_problem(lanes, side, at, {"enemies": [other_same]}, [other_same]).contains("Sentinel"),
				"no other Sentinel on its wall section " + tag)
			var pair := {"type": "gilded_sentinel", "at": at, "lane": _outer(lanes, -side), "side": -side, "params": {"swings": 1}}
			check(_problem(lanes, side, at, {"enemies": [pair]}, [pair]) == "", "a pair across the street is fine " + tag)
			var near := {"type": "gilded_sentinel", "at": at + 12.0, "lane": _outer(lanes, -side), "side": -side, "params": {"swings": 1}}
			check(_problem(lanes, side, at, {"enemies": [near]}, [near]).contains("meanwhile"),
				"but not another attacking meanwhile " + tag)
			_check_wall_fence_keeps_off(lanes, side, at, tag)
			_check_introduction(lanes, side, tag)


static func _outer(lanes: int, side: int) -> int:
	return 0 if side < 0 else lanes - 1


## A generator over a hand-built layout of `lanes` lanes holding `pieces` ({gaps, fences, signs, ramps,
## hulls, enemies}), at 25 m/s, with the Sentinel and the other features in its level.
func _gen(lanes: int, pieces: Dictionary) -> LevelGenerator:
	var layout := RunSim.layout(lanes, 900.0)
	for key: String in pieces:
		var list: Array = layout.get(key)
		for item: Dictionary in pieces[key]:
			list.append(item)
	var config := LevelConfig.new()
	config.lane_count = lanes
	config.run_speed = 25.0
	config.features = PackedStringArray(["ramps", "ceilings", "window_cyborg", "octodog", "gilded_sentinel"])
	return LevelGenerator.for_layout(config, tuning, layout)


func _problem(lanes: int, side: int, at: float, pieces: Dictionary, others: Array = []) -> String:
	var gen: LevelGenerator = _gen(lanes, pieces)
	var typed: Array[Dictionary] = []
	typed.assign(others)
	return Rules.problem(gen, side, at, 1, gen.layout, typed)


## The wall fences keep off a Sentinel's wall section (WallFencePlacement, B5's notes for C4).
func _check_wall_fence_keeps_off(lanes: int, side: int, at: float, tag: String) -> void:
	var sentinel := {"type": "gilded_sentinel", "at": at, "lane": _outer(lanes, side), "side": side, "params": {"swings": 1}}
	var gen: LevelGenerator = _gen(lanes, {"enemies": [sentinel]})
	var fence: Dictionary = {"side": side, "at": at - 20.0, "band": "full", "pulse_on": 1.0, "pulse_off": 1.5, "phase": 0.2}
	check(WallFencePlacement.problem(gen, fence).contains("Gilded Sentinel"), "no wall fence on its wall section " + tag)
	var far: Dictionary = fence.duplicate()
	far["at"] = at + 140.0
	check(WallFencePlacement.problem(gen, far) == "", "one well past it is fine " + tag)


## The level's first Sentinel is its introduction: alone (a first pair loses its partner), swinging once.
func _check_introduction(lanes: int, side: int, tag: String) -> void:
	var at: float = 260.0
	var first := {"type": "gilded_sentinel", "at": at, "lane": _outer(lanes, side), "side": side, "seed": 1, "params": {"swings": 2}}
	var partner := {"type": "gilded_sentinel", "at": at, "lane": _outer(lanes, -side), "side": -side, "seed": 2, "params": {}}
	var gen: LevelGenerator = _gen(lanes, {"enemies": [first, partner]})
	Rules.apply(gen)
	var left: Array[Dictionary] = Rules.sentinels_in(gen.layout)
	check(left.size() == 1 and int(left[0]["params"]["swings"]) == 1 and left[0]["params"].get("floor_span") is Vector2,
		"the introduction swings once, alone, its floor planned " + tag)


## The wall enemies a pass adds after the Sentinels' rules ran (the danger density pass's window cyborgs and
## vent Screeches) ask GildedSentinelRules.on_wall_section where they may stand (task K4). Along both walls
## around a Sentinel, at 3, 5 and 6 lanes, it puts a window cyborg or a wall vent's Screech on the Sentinel's
## wall section exactly where problem() finds one there, to the centimetre at the section's ends, and a
## manhole's Screech (not on the wall) never. The generator hands the pass these rules (wall_section_rules),
## and the pass's own check (DangerDensity._type_rules_ok) turns such a probe down on the section, and takes it
## past the section or on the other wall.
func _test_wall_section() -> void:
	var at: float = 220.0
	var kinds: Array = [["window_cyborg", {}], ["screech", {}], ["screech", {"source": "vent"}], ["screech", {"source": "manhole"}]]
	for lanes: int in [3, 5, 6]:
		for side: int in [-1, 1]:
			var tag: String = "(%d lanes, side %d)" % [lanes, side]
			var sentinel := {"type": "gilded_sentinel", "at": at, "lane": _outer(lanes, side), "side": side, "seed": 1,
				"params": {"swings": 1}}
			var gen: LevelGenerator = _gen(lanes, {"enemies": [sentinel]})
			var guard: Vector2 = t.guarded_stretch(at, 1)
			var section := Vector2(guard.x - t.approach_seconds * gen.speed, guard.y + t.wall_clear_seconds * gen.speed)
			var mismatches: PackedStringArray = []
			var on: int = 0
			for kind: Array in kinds:
				var type: String = kind[0]
				var params: Dictionary = kind[1]
				var reach: float = Rules._window_cyborg_half_length() if type == "window_cyborg" else 0.0
				var spots: Array[float] = []
				var spot: float = section.x - reach - 20.0
				while spot <= section.y + reach + 20.0:
					spots.append(spot)
					spot += 0.5
				for edge: float in [section.x - reach, section.y + reach]:
					spots.append_array([edge - 0.01, edge + 0.01])
				for wall: int in [side, -side]:
					# The same wall enemy, moved along its wall, in a layout without the Sentinel: problem() asks
					# where a Sentinel at `at` would stand beside it.
					var e := {"type": type, "at": 0.0, "lane": _outer(lanes, wall), "side": wall, "seed": 2, "params": params}
					var beside: LevelGenerator = _gen(lanes, {"enemies": [e]})
					for s: float in spots:
						e["at"] = s
						var said: bool = Rules.on_wall_section(gen, type, wall, s, params)
						var why: String = Rules.problem(beside, side, at, 1, beside.layout)
						var found: bool = why == "a window cyborg is on its wall section" or why == "a wall vent's screech is on its wall section"
						if said != found:
							mismatches.append("%s %s on wall %d at %.2f: %s, problem() \"%s\"" % [type, params, wall, s, said, why])
						on += 1 if said else 0
			check(mismatches.is_empty() and on > 0,
				"on_wall_section puts a wall enemy on its wall section exactly where problem() finds it %s (%d spots on it): %s"
				% [tag, on, "; ".join(mismatches.slice(0, 4))])
			var rules: Array[GDScript] = gen.wall_section_rules()
			check(rules.size() == 1 and rules[0] == Rules, "the generator hands a later pass the Sentinels' rules " + tag)
			var plan: DangerDensity.Plan = DangerDensity._plan(gen, [], RandomNumberGenerator.new())
			DangerDensity._index_enemies(plan)
			for kind: Array in [["window_cyborg", {}], ["screech", {"source": "vent"}]]:
				var probe := {"type": kind[0], "at": (section.x + section.y) * 0.5, "lane": _outer(lanes, side), "side": side,
					"params": kind[1]}
				check(not DangerDensity._type_rules_ok(plan, probe), "the danger density pass turns down a %s on its wall section %s"
					% [kind[0], tag])
				var past: Dictionary = probe.duplicate()
				past["at"] = section.y + 30.0
				var across: Dictionary = probe.duplicate()
				across["side"] = -side
				across["lane"] = _outer(lanes, -side)
				check(DangerDensity._type_rules_ok(plan, past) and DangerDensity._type_rules_ok(plan, across),
					"and takes one past it, or on the other wall %s" % tag)


# --- The campaign -----------------------------------------------------------------------------------------

## Golden 2 (Sentinel Row, which brings them in) and the Golden Palace at 3, 5 and 6 lanes, on their own
## seeds and another: every Sentinel keeps its rules (Rules.problems), the layout its fairness checks (the
## wall fences included), Golden 2's first comes right after its start, and a level builds the same twice.
func _test_campaign() -> void:
	var campaign := load("res://data/campaign/campaign.tres") as Campaign
	var total: int = 0
	for id: String in ["golden/2", "golden/3"]:
		for lanes: int in [3, 5, 6]:
			for extra: int in [0, 7]:
				var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
				config.level_seed += extra
				# T-SPEED: shared across the run (LayoutCache); at extra==0 this is the level's own
				# default build, shared with other suites too.
				var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
				var layout: LevelLayout = gen.layout
				var tag: String = "%s lanes=%d seed=%d" % [id, lanes, config.level_seed]
				var sentinels: Array[Dictionary] = Rules.sentinels_in(layout)
				total += sentinels.size()
				check(not sentinels.is_empty() and gen.warnings.is_empty(), "%s has Sentinels and no warnings %s" % [tag, gen.warnings])
				var problems: PackedStringArray = Rules.problems(layout, config, tuning)
				check(problems.is_empty(), "%s: every Sentinel keeps its rules %s" % [tag, problems])
				for e: Dictionary in sentinels:
					check(is_equal_approx(Rules.in_chunk(t, float(e["at"])), float(e["at"])), "%s: its niche lies in a chunk" % tag)
				LayoutChecks.check_layout(self, layout, config, tag)
				if id == "golden/2" and not sentinels.is_empty():
					var gen2: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
					var start: float = gen2.feature_start("gilded_sentinel")
					check(float(sentinels[0]["at"]) >= start and t.warn_at(float(sentinels[0]["at"]), 1, gen2.speed) <= start + gen2.metres(210.0),
						"%s: the first comes right after the feature's start (%.0f m, from %.0f)" % [tag, sentinels[0]["at"], start])
				if lanes == 5 and extra == 0:
					var again := LevelGenerator.new()
					check(JSON.stringify(again.generate(config, tuning, LevelGenerator.load_for(config)).to_dict())
						== JSON.stringify(layout.to_dict()), "%s builds the same twice" % tag)
	check(total >= 24, "the Sentinels appear often in Golden 2 and the Palace (%d over 12 levels)" % total)
	for case: Dictionary in SENTINEL_WALL_CASES:
		var config: LevelConfig = campaign.configure(campaign.step(String(case["id"])), int(case["lanes"]))
		config.level_seed = int(case["seed"])
		var tag: String = "%s lanes=%d seed=%d" % [case["id"], case["lanes"], case["seed"]]
		var patterns: Array = LevelGenerator.load_for(config)
		var gen := LevelGenerator.new()
		var shipped: LevelLayout = gen.generate(config, tuning, patterns)
		var problems: PackedStringArray = Rules.problems(shipped, config, tuning)
		check(gen.warnings.is_empty() and problems.is_empty(),
			"%s: every Sentinel keeps its rules, the danger density pass's wall enemies off their wall sections %s" % [tag,
			problems])
		var shown: PackedStringArray = []
		for p: String in Rules.problems(SentinelWallsUnchecked.new().generate(config, tuning, patterns), config, tuning):
			if p.ends_with("a window cyborg is on its wall section") or p.ends_with("a wall vent's screech is on its wall section"):
				shown.append(p)
		check(not shown.is_empty(), ("%s still shows its case: without the check the pass puts a wall enemy on a Sentinel's wall "
			+ "section (%s); else re-pin SENTINEL_WALL_CASES") % [tag, ", ".join(shown)])
