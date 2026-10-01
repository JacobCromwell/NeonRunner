extends TestSuite
## The Barnacle Turret (GDD §9.8), the Marketplace's ceiling hazard:
## - its numbers: slightly more accurate than the cyborg, 7 laser tier 1 shots where it first appears
##   and slightly more later, firing somewhat faster later, a charge sound that lasts the charge-up;
## - its hitboxes: the body ends at the stomp line, nothing reaches a player who isn't on its ceiling
##   (a jump from a hover truck's roof, the top of a wall run), and it stays in its lane;
## - its looks: mechanical in most zones, a creature in Gangland and the Marketplace, the same size;
##   only its muzzle glows in a hazard colour, enemy-fire red, and only while it charges;
## - placement (barnacle_turret_rules.gd, LayoutChecks.check_turrets): only in levels with the feature,
##   never on a one-lane ceiling, at most 2 per ceiling, over lanes it covers but no pad's; every level
##   with the feature has one, Marketplace 1 meets it soon after its start, alone; deterministic; the
##   rest of a level, and so the floor route under its ceilings, is what it was without it;
## - play on real physics: it pops out as the player nears; it fires only at a rider on its own
##   ceiling, never at the floor or at a rider on another ceiling, always after a charge-up (glow and
##   sound) and with time to dodge; a rider who stays in line is hit, one who switches lanes after the
##   charge-up isn't; on a two-lane ceiling the rider always has a lane or time (3, 5 and 6 lanes);
## - kills: claws, the dash, a stomp from the ceiling (the rider jumps and drops back onto its crown),
##   and 7 laser tier 1 shots; running into it is deadly, armor or not; the shield blocks that; armor
##   and the shield block its bolts;
## - the same seed plays out the same way, and generated levels played through check every burst.

const Rules = preload("res://scripts/enemies/barnacle_turret_rules.gd")
const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
const TURRET_TUNING_PATH: String = "res://data/enemies/barnacle_turret.tres"
const TYPE: String = "barnacle_turret"
## A hand-built ceiling: from CEIL_START to CEIL_END, its pad at CEIL_START + the lead-in.
const CEIL_START: float = 97.0
const CEIL_END: float = 195.0
const PAD_AT: float = 100.0
const TURRET_AT: float = 152.0

var sim: RunSim
var bt: BarnacleTurretTuning
var game_rules: GameRules
var campaign: Campaign


func run() -> void:
	sim = RunSim.new(tree, tuning)
	bt = load(TURRET_TUNING_PATH) as BarnacleTurretTuning
	game_rules = load("res://data/tuning/game_rules.tres") as GameRules
	campaign = load("res://data/campaign/campaign.tres") as Campaign
	check(bt != null, "the Barnacle Turret's tuning loads")
	if bt == null:
		return
	_test_tuning()
	_test_hitboxes()
	_test_looks()
	_test_placement()
	_test_narrow_ceilings()
	await _test_emerge()
	await _test_fires_only_at_rider()
	await _test_dodge()
	await _test_two_lane()
	await _test_contact()
	await _test_weapons()
	await _test_armor_and_shield()
	await _test_determinism()
	await _test_fair_play()


# --- Helpers ----------------------------------------------------------------------------------------

## A straight track of `lanes` lanes with one ceiling over `cover` (every lane by default) and its pad in
## `pad_lane`.
static func _layout(lanes: int, pad_lane: int, cover: Vector2i = Vector2i(-1, -1), end: float = CEIL_END) -> LevelLayout:
	var l := RunSim.layout(lanes, 600.0)
	var span: Vector2i = cover if cover.x >= 0 else Vector2i(0, lanes - 1)
	l.hulls.append(LevelLayout.make_hull(CEIL_START, end, span, lanes))
	l.pads.append({"lane": pad_lane, "at": PAD_AT})
	return l


func _spawn(w: RunWorld, at: float, lane: int, params: Dictionary = {}, seed_value: int = 5) -> BarnacleTurret:
	return w.director.spawn({"type": TYPE, "at": at, "lane": lane, "side": 0, "seed": seed_value,
		"params": params}) as BarnacleTurret


func _loadout(items: Dictionary) -> Loadout:
	var l := Loadout.new()
	for k: String in items:
		if k == "armor":
			l.armor = true
		elif k in ["shield", "grapple"]:
			l.charges[StringName(k)] = items[k]
		else:
			l.tiers[StringName(k)] = items[k]
	return l


## Steps the world a frame at a time until `done` returns true or `seconds` pass (the player runs).
func _step_until(w: RunWorld, done: Callable, seconds: float) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		await tree.physics_frame
		if done.call():
			return true
	return false


static func _events_of(gun: CyborgGun, kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in gun.events:
		if e["event"] == kind:
			out.append(e)
	return out


## The level's turret entries.
static func _turrets(layout: LevelLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in layout.enemies:
		if String(e["type"]) == TYPE:
			out.append(e)
	return out


## The layout's lists with their entries sorted (the generator's final sort by distance isn't stable).
static func _canon(d: Dictionary) -> String:
	var out: Dictionary = {}
	for key: String in d:
		var v: Variant = d[key]
		if v is Array:
			var items: Array = []
			for item: Variant in v:
				items.append(JSON.stringify(item, "", true))
			items.sort()
			out[key] = items
		else:
			out[key] = v
	return JSON.stringify(out, "", true)


# --- Numbers, hitboxes, looks -----------------------------------------------------------------------

## GDD §9.8 and §8: slightly more accurate than the cyborg (still hitting a rider who stays in line);
## 7 laser tier 1 shots where it first appears (5 plain, plus tier 1's two), slightly more later and
## never by much; it fires somewhat faster later; the warning sound lasts the whole charge-up; it
## never uses the floor.
func _test_tuning() -> void:
	var ct := load("res://data/enemies/cyborg.tres") as CyborgTuning
	check(bt.aim_error < ct.aim_error and bt.shot_jitter < ct.shot_jitter
		and bt.aim_error + bt.shot_jitter >= (ct.aim_error + ct.shot_jitter) * 0.5,
		"slightly more accurate than the cyborg (%.2f + %.2f m against %.2f + %.2f m)" % [bt.aim_error, bt.shot_jitter,
			ct.aim_error, ct.shot_jitter])
	check(bt.aim_error + bt.shot_jitter < tuning.hurtbox_size.x * 0.5 + 0.09,
		"a burst still hits a rider who stays in its line")
	check(bt.charge_time >= ct.charge_time - 0.001 and bt.min_warning_time >= ct.min_warning_time - 0.001
		and bt.burst_max <= ct.burst_max, "its warning and its bursts are the cyborg's, no harder")
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	var m1: float = campaign.configure(campaign.step("marketplace/1"), 3).enemy_scaling
	var plain: float = bt.whole_health_at(m1)
	check(is_equal_approx(plain, 5.0) and int(plain) + pt.tier1_extra_shots == 7,
		"7 laser tier 1 shots where it first appears, Marketplace 1 (%d plain + %d)" % [int(plain), pt.tier1_extra_shots])
	check(is_equal_approx(bt.whole_health_at(0.0), plain), "and in quick play")
	var most: float = plain
	var prev: float = plain
	for s: CampaignStep in campaign.steps():
		if s.is_level() and s.level.has_feature(TYPE):
			var h: float = bt.whole_health_at(campaign.configure(s, 3).enemy_scaling)
			check(h >= prev, "%s: it never gets easier to kill (%.0f plain shots)" % [s.id, h])
			prev = h
			most = maxf(most, h)
	check(most > plain and most <= plain + 1.0, "slightly more to kill later, never by much (%.0f at most)" % most)
	check(bt.reload_at(1.0) < bt.reload_at(m1) and bt.reload_at(1.0) >= bt.reload_at(m1) * 0.6,
		"it fires somewhat faster later (reload %.2f s → %.2f s)" % [bt.reload_at(m1), bt.reload_at(1.0)])
	check(not bt.uses_floor, "it never uses the floor")
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in [&"barnacle_charge", &"barnacle_shot", &"barnacle_emerge", &"barnacle_death"]:
		check(library.volume_db.has(String(sound)) and library.has_file(sound), "the sound %s is in the library" % sound)
	var charge: AudioStream = library.stream(&"barnacle_charge")
	var length: float = charge.get_length() if charge != null else 0.0
	check(length >= bt.charge_time and length <= bt.charge_time + 0.1,
		"the charge sound (%.2f s) lasts the whole %.2f s charge-up" % [length, bt.charge_time])
	var hints: Variant = JSON.parse_string(FileAccess.get_file_as_string(HintDirector.PATH))
	var hinted: bool = false
	for h: Dictionary in (hints as Dictionary).get("hints", []):
		hinted = hinted or String(h.get("trigger", "")) == "enemy:" + TYPE
	check(hinted, "it has a first-encounter hint")


## The body ends at the stomp line (dropping onto the crown only touches the crown); nothing of it
## reaches a player who isn't on its ceiling: one jumping on a hover truck's roof, or at the top of a
## wall run; and it stays well inside its lane, so a rider in the next lane never touches it.
func _test_hitboxes() -> void:
	check(BarnacleTurret.BODY_SIZE.y <= BarnacleTurret.REACH_BELOW - game_rules.stomp_tolerance + 0.001,
		"the body ends at the stomp line, so a rider dropping onto the crown only touches the crown")
	check(BarnacleTurret.TOP_FROM >= BarnacleTurret.BODY_SIZE.y, "the crown starts below the body")
	var truck := load("res://data/enemies/hover_truck.tres") as HoverTruckTuning
	var lowest: float = tuning.ceiling_height - BarnacleTurret.REACH_BELOW
	var truck_jump: float = truck.roof_height + truck.bob_height + tuning.jump_height + tuning.hurtbox_size.y
	check(lowest > truck_jump + 0.03, "a jump from a hover truck's roof never reaches it (%.2f m below %.2f m)"
		% [truck_jump, lowest])
	check(lowest > tuning.wall_max_height + tuning.hurtbox_size.x * 0.5 + 0.2,
		"nor the top of a wall run (%.2f m)" % (tuning.wall_max_height + tuning.hurtbox_size.x * 0.5))
	check(BarnacleTurret.BODY_SIZE.x * 0.5 + tuning.hurtbox_size.x * 0.5 < tuning.lane_width * 0.75,
		"its body stays inside its lane: a rider in the next lane never touches it")
	check(BarnacleTurret.TOP_SIZE.x <= BarnacleTurret.BODY_SIZE.x + 0.001, "and so does its crown")


## Mechanical in most zones, a furry creature in Gangland and the Marketplace (by the skins'
## enemy_variant); the same parts and size either way; nothing glows in a hazard colour but its
## muzzle, red, while it charges (the creature's fur and eyes don't glow; the mechanical sensor is the
## cyborgs' cold white).
func _test_looks() -> void:
	var expect: Dictionary = {&"city": false, &"scavenger": true, &"casino": true, &"vr_runner": false,
		&"burned": false, &"golden": false}
	for v: StringName in expect:
		check(BarnacleTurretModel.is_creature(v) == bool(expect[v]), "%s wears the %s look" % [v,
			"creature" if expect[v] else "mechanical"])
	for skin_path: String in ["res://data/skins/marketplace_skin.tres", "res://data/skins/gangland_skin.tres"]:
		var skin := load(skin_path) as ZoneSkin
		check(skin != null and BarnacleTurretModel.is_creature(skin.enemy_variant), "%s's turrets are creatures" % skin_path)
	for skin_path: String in ["res://data/skins/city_skin.tres", "res://data/skins/corporate_skin.tres",
			"res://data/skins/dead_zone_skin.tres", "res://data/skins/golden_skin.tres"]:
		var skin := load(skin_path) as ZoneSkin
		check(skin != null and not BarnacleTurretModel.is_creature(skin.enemy_variant), "%s's turrets are mechanical" % skin_path)
	var sizes: Array[AABB] = []
	for v: StringName in [&"casino", &"vr_runner"]:
		var m := BarnacleTurretModel.new()
		m.build(v, 3)
		var box := AABB()
		var first: bool = true
		for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
			var inst := mi as MeshInstance3D
			var part: String = String(inst.name)
			if part in ["Collar", "Body"]:
				box = inst.mesh.get_aabb() if first else box.merge(inst.mesh.get_aabb())
				first = false
			if part in ["Collar", "Body", "Eyes"]:
				_check_no_hazard_glow(inst.mesh, "%s %s" % [v, part])
		sizes.append(box)
		check(is_zero_approx(m.glow_amount()), "%s: the muzzle doesn't glow at rest" % v)
		m.set_charge(1.0)
		check(m.glow_amount() > 0.9, "%s: it glows red as the charge-up ends" % v)
		check(m.draw_call_count() <= 8, "%s: a few draw calls (%d)" % [v, m.draw_call_count()])
		m.set_charge(0.0)
		check(is_zero_approx(m.glow_amount()), "%s: and goes dark again" % v)
		m.free()
	check(sizes.size() == 2 and absf(sizes[0].size.y - sizes[1].size.y) < 0.2 and absf(sizes[0].size.x - sizes[1].size.x) < 0.5,
		"both looks are about the same size (%s, %s)" % [sizes[0].size, sizes[1].size])
	# Nothing of either look hangs within reach of a jump from a hover truck's roof (its hitboxes stop
	# shorter still: forgiving, GDD §3).
	var truck := load("res://data/enemies/hover_truck.tres") as HoverTruckTuning
	var reach: float = truck.roof_height + truck.bob_height + tuning.jump_height + tuning.hurtbox_size.y
	for box: AABB in sizes:
		check(tuning.ceiling_height + box.position.y > reach,
			"no part of it hangs within a truck-roof jump's reach (lowest %.2f m)" % (tuning.ceiling_height + box.position.y))


## No vertex of `mesh` glows (vertex alpha) except in the cyborgs' cold white.
func _check_no_hazard_glow(mesh: Mesh, what: String) -> void:
	var led: Color = Kit.LED_COLOR.srgb_to_linear()
	var bad: int = 0
	for s: int in mesh.get_surface_count():
		var colors: PackedColorArray = mesh.surface_get_arrays(s)[Mesh.ARRAY_COLOR]
		for c: Color in colors:
			if c.a > 0.01 and (absf(c.r - led.r) > 0.05 or absf(c.g - led.g) > 0.05 or absf(c.b - led.b) > 0.05):
				bad += 1
	check(bad == 0, "%s: nothing glows but the cold-white sensor (%d other glowing vertices)" % [what, bad])


# --- Placement ----------------------------------------------------------------------------------------

## Every campaign level with the feature, at 3, 5 and 6 lanes: it has turrets, all within their limits
## (LayoutChecks.check_turrets, and the shared checks), the same every time; Marketplace 1 meets its
## first one soon after the start, alone on its ceiling, and has no pairs; levels without the feature
## have none. Without the feature the same level is otherwise identical (bar the plain ceiling its
## introduction may add, with its pad and credits), so the floor and its route are unchanged.
func _test_placement() -> void:
	var pairs: int = 0
	var added: int = 0
	for s: CampaignStep in campaign.steps():
		if not s.is_level():
			continue
		var has: bool = s.level.has_feature(TYPE)
		for lanes: int in [3, 5, 6]:
			if not has and lanes != 3:
				continue
			var config: LevelConfig = campaign.configure(s, lanes)
			var tag: String = "%s lanes=%d" % [s.id, lanes]
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
			var turrets: Array[Dictionary] = _turrets(layout)
			if not has:
				check(turrets.is_empty(), "no turret in a level without the feature " + tag)
				continue
			check(not turrets.is_empty(), "a level with the feature has turrets " + tag)
			LayoutChecks.check_turrets(self, layout, config, gen.speed, tag)
			LayoutChecks.check_layout(self, layout, config, tag)
			var again := LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
			check(JSON.stringify(_turrets(again)) == JSON.stringify(turrets), "placement is deterministic " + tag)
			var per: Dictionary = {}
			for e: Dictionary in turrets:
				var key: float = float(e["params"]["hull_start"])
				per[key] = int(per.get(key, 0)) + 1
			for key: Variant in per:
				pairs += 1 if int(per[key]) == 2 else 0
			if s.id == "marketplace/1":
				var start: float = gen.feature_start(TYPE)
				var first: Dictionary = turrets[0]
				for e: Dictionary in turrets:
					if float(e["at"]) < float(first["at"]):
						first = e
				var reach: float = start + bt.intro_seconds * gen.speed
				check(float(first["at"]) >= start and float(first["at"]) <= reach,
					"Marketplace 1 meets its first turret soon after the start (%.0f m, start %.0f) %s" % [first["at"], start, tag])
				check(int(per[float(first["params"]["hull_start"])]) == 1, "alone on its ceiling " + tag)
				for key: Variant in per:
					check(int(per[key]) == 1, "no pairs in Marketplace 1 " + tag)
			# The same level without the feature.
			var bare: LevelConfig = config.duplicate() as LevelConfig
			var f := PackedStringArray()
			for x: String in config.features:
				if x != TYPE:
					f.append(x)
			bare.features = f
			bare.feature_starts = config.feature_starts.duplicate()
			bare.feature_starts.erase(TYPE)
			var other: LevelLayout = LevelGenerator.new().generate(bare, tuning, LevelGenerator.load_for(bare))
			var a: Dictionary = layout.to_dict()
			var kept: Array = []
			for e: Dictionary in layout.enemies:
				if String(e["type"]) != TYPE:
					kept.append(e)
			a["enemies"] = kept
			var b: Dictionary = other.to_dict()
			var extra: int = layout.hulls.size() - other.hulls.size()
			check(extra == 0 or (extra == 1 and config.feature_starts.has(TYPE)),
				"only the introduction may add a ceiling (%d added) %s" % [extra, tag])
			if extra == 1:
				# The introduction's ceiling, its pad and credits, and (the fill pass keeps off its
				# landing and pad, after the rules, on a random stream of its own) the fillers from there on.
				added += 1
				for key: String in ["hulls", "pads", "credits", "gaps", "fences"]:
					a.erase(key)
					b.erase(key)
			check(_canon(a) == _canon(b), "the rest of the level is what it is without turrets " + tag)
			for e: Dictionary in turrets:
				var k: Vector2 = Rules.keep_out(gen, e)
				check(k.x > k.y, "the fill pass keeps nothing for a turret (it never uses the floor) " + tag)
	check(pairs >= 1, "some ceilings get a second turret later in the campaign (%d)" % pairs)
	print("  turret placement: %d pairs over the campaign levels, %d introduction ceilings added" % [pairs, added])


## Narrow ceilings (B3): over many seeds and 3, 5 and 6 lanes, one-lane ceilings never get a turret,
## two-lane ones do, and every turret keeps to its ceiling's lanes and off its pads' lanes.
func _test_narrow_ceilings() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var one_lane: int = 0
	var two_lane_turrets: int = 0
	for lanes: int in [3, 5, 6]:
		for level_seed: int in range(1, 7):
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			config.level_seed = level_seed
			config.features = PackedStringArray(["ceilings", TYPE])
			config.narrow_ceiling_share = 0.7
			config.one_lane_ceiling_share = 0.5
			config.enemy_scaling = 0.8
			var tag: String = "lanes=%d seed=%d" % [lanes, level_seed]
			var gen := LevelGenerator.new()
			var layout: LevelLayout = gen.generate(config, tuning, LevelGenerator.load_for(config))
			check(gen.warnings.is_empty(), "no warnings %s %s" % [tag, gen.warnings])
			LayoutChecks.check_layout(self, layout, config, tag)
			LayoutChecks.check_rules(self, layout, config, tag)
			for h: Dictionary in layout.hulls:
				var on: Array[Dictionary] = Rules.turrets_on(layout, h)
				if layout.hull_width(h) == 1:
					one_lane += 1
					check(on.is_empty(), "never a turret on a one-lane ceiling " + tag)
				elif layout.hull_width(h) == 2:
					two_lane_turrets += on.size()
	check(one_lane > 5 and two_lane_turrets > 5, "the sweep had one-lane ceilings (%d) and turrets on two-lane ones (%d)"
		% [one_lane, two_lane_turrets])


# --- Play on real physics -----------------------------------------------------------------------------

## It stays in its hatch, out of play (no hitboxes, no target), until the player comes emerge_seconds
## away at their speed, then pops out and stays put.
func _test_emerge() -> void:
	var w: RunWorld = sim.build_world(_layout(3, 1), _loadout({"weapon": 1}))
	var t: BarnacleTurret = _spawn(w, TURRET_AT, 0, {"fires": false})
	check(t != null and not t.out and not t.targetable() and is_zero_approx(t.model.emerged),
		"it starts in its hatch, out of play")
	check(not t._body_box.is_active() and not t._top_box.is_active(), "its hitboxes are off meanwhile")
	check(t.hull_start == CEIL_START and t.hull_end == CEIL_END and t.first_lane == 0 and t.last_lane == 2,
		"it finds its ceiling in the layout when its params don't say")
	await _step_until(w, func() -> bool: return t.out, 8.0)
	var lead: float = t.track_distance() - w.player.distance
	check(t.out and absf(lead - bt.emerge_seconds * w.player.speed) < 1.0,
		"it pops out %.1f s before the player reaches it (%.1f m)" % [bt.emerge_seconds, lead])
	check(t._body_box.is_active() and t._top_box.is_active() and t.targetable(), "and is in play from then on")
	await _step_until(w, func() -> bool: return t.model.emerged >= 1.0, bt.emerge_time + 0.5)
	check(is_equal_approx(t.model.emerged, 1.0) and absf(t.track_distance() - TURRET_AT) < 0.001
		and absf(t.global_position.y - tuning.ceiling_height) < 0.001, "out of its hatch on the underside, where it stays")
	await sim.free_world(w)


## GDD §9.8: it fires only at a rider on its own ceiling: never at a floor runner under it, nor at a
## rider on another ceiling. At a rider it charges up first (the red glow and its sound), each burst's
## first bolt takes at least min_warning_time to arrive, and a rider who stays in line is hit.
func _test_fires_only_at_rider() -> void:
	# A floor runner who passes the pad by.
	var w: RunWorld = sim.build_world(_layout(3, 1))
	var t: BarnacleTurret = _spawn(w, TURRET_AT, 0)
	var gun: CyborgGun = t.gun  # it leaves play (freed) once the player is well past
	var r: Dictionary = await sim.step_world(w, 9.0, [[60.0, &"move_right"]])
	check(t.out, "it popped out as the floor runner came")
	r = await sim.step_world(w, 3.0)
	check(r["alive"] and r["surface"] == "floor" and float(r["distance"]) > CEIL_END, "a floor runner passes under it")
	check(gun.events.is_empty(), "and it never charges at them (%d events)" % gun.events.size())
	await sim.free_world(w)

	# A rider on the ceiling before its own.
	var two: LevelLayout = RunSim.layout(3, 600.0)
	two.hulls.append({"start": 97.0, "end": 165.0})
	two.pads.append({"lane": 1, "at": 100.0})
	two.hulls.append({"start": 180.0, "end": 280.0})
	two.pads.append({"lane": 2, "at": 183.0})
	w = sim.build_world(two)
	t = _spawn(w, 235.0, 0)
	gun = t.gun
	r = await sim.step_world(w, 11.0)
	check(r["alive"] and t.out and gun.events.is_empty(),
		"nor at a rider on another ceiling (%d events, %s)" % [gun.events.size(), r["cause"]])
	await sim.free_world(w)

	# A rider on its ceiling who stays in line.
	w = sim.build_world(_layout(3, 1))
	t = _spawn(w, TURRET_AT, 0)
	var seen := {"dark_before": true, "glow": 0.0, "surface": ""}
	var cause: Array[String] = [""]
	w.player.died.connect(func(c: String) -> void: cause[0] = c)
	var watch := func() -> bool:
		if t.gun.state == CyborgGun.State.READY and t.gun.events.is_empty():
			seen["dark_before"] = bool(seen["dark_before"]) and is_zero_approx(t.model.glow_amount())
		if t.gun.state == CyborgGun.State.CHARGING:
			seen["glow"] = maxf(float(seen["glow"]), t.model.glow_amount())
			if String(seen["surface"]) == "":
				seen["surface"] = w.player.surface_name()
		return not w.player.alive
	await _step_until(w, watch, 12.0)
	var charges: Array[Dictionary] = _events_of(t.gun, &"charge")
	var shots: Array[Dictionary] = _events_of(t.gun, &"shot")
	check(not w.player.alive and cause[0] == BarnacleTurret.SHOT_NAME, "a rider who stays in its line is hit (%s)" % cause[0])
	check(not charges.is_empty() and not shots.is_empty(), "it charged up and fired at the rider (%d bolts)" % shots.size())
	check(String(seen["surface"]) == "ceiling", "only once the player was on its ceiling (%s)" % seen["surface"])
	check(bool(seen["dark_before"]) and float(seen["glow"]) > 0.3,
		"its muzzle is dark until it charges, then glows red (%.2f)" % float(seen["glow"]))
	check(t.gun.charge_sound == &"barnacle_charge" and t.gun.shot_sound == &"barnacle_shot", "with its own sounds")
	if not charges.is_empty() and not shots.is_empty():
		check(float(shots[0]["t"]) - float(charges[0]["t"]) >= bt.charge_time - 0.02,
			"the charge-up comes before the first bolt (%.2f s)" % (float(shots[0]["t"]) - float(charges[0]["t"])))
		check(float(shots[0]["arrive"]) - float(shots[0]["t"]) >= bt.min_warning_time - 0.001,
			"the first bolt takes at least %.2f s to arrive" % bt.min_warning_time)
		check(int(charges[0]["shots"]) >= bt.burst_min and int(charges[0]["shots"]) <= bt.burst_max, "a short burst")
	await sim.free_world(w)


## A rider who switches lanes once the charge-up is over dodges the whole burst, and rides on past it.
func _test_dodge() -> void:
	var w: RunWorld = sim.build_world(_layout(3, 1))
	var t: BarnacleTurret = _spawn(w, TURRET_AT, 0)
	var fired: bool = await _step_until(w, func() -> bool: return t.gun.state == CyborgGun.State.FIRING, 10.0)
	check(fired, "it fires at the rider")
	w.player.press(&"move_right")
	await _step_until(w, func() -> bool: return t.gun.state != CyborgGun.State.FIRING, 2.0)
	var last: float = 0.0
	for s: Dictionary in _events_of(t.gun, &"shot"):
		last = maxf(last, float(s["arrive"]))
	await _step_until(w, func() -> bool: return w.level_time() > last + 0.3 or not w.player.alive, 3.0)
	check(w.player.alive and w.player.lane == 2, "switching lanes after the charge-up dodges the whole burst")
	await _step_until(w, func() -> bool: return w.player.distance > TURRET_AT + 10.0 or not w.player.alive, 4.0)
	check(w.player.alive, "and the rider rides on past it")
	await sim.free_world(w)


## GDD §9.8: on a two-lane ceiling (the pad's lane and the turret's) the rider always has a lane or
## time: its bolts only ever arrive well before it, so a rider who dodges into its lane has room to
## switch back before passing it. With one turret and with two in the turret's lane, at 3, 5 and 6
## lanes: a rider who dodges every burst into the other lane and back survives, and no bolt arrives
## within clear_after_impact + body_reach of a turret body ahead.
func _test_two_lane() -> void:
	for lanes: int in [3, 5, 6]:
		for pair: bool in [false, true]:
			var p: int = lanes / 2
			# The second turret stands far enough past the first to get a fair burst in once the rider is
			# past the first (in the only lane to dodge into, the first blocks every burst before that).
			var end: float = 245.0 if pair else CEIL_END
			var w: RunWorld = sim.build_world(_layout(lanes, p, Vector2i(p - 1, p), end))
			var ats: Array[float] = [TURRET_AT]
			if pair:
				ats = [TURRET_AT, 205.0]
			var turrets: Array[BarnacleTurret] = []
			var guns: Array[CyborgGun] = []
			for at: float in ats:
				turrets.append(_spawn(w, at, p - 1, {}, 7 + turrets.size()))
				guns.append(turrets[-1].gun)
			var tag: String = "(%d lanes, %s)" % [lanes, "two turrets" if pair else "one turret"]
			var cause: Array[String] = [""]
			w.player.died.connect(func(c: String) -> void: cause[0] = c)
			var state := {"back_at": -1.0, "dodges": 0}
			var bot := func() -> bool:
				var firing: bool = false
				var last: float = 0.0
				for g: CyborgGun in guns:
					firing = firing or g.state == CyborgGun.State.FIRING
					for s: Dictionary in _events_of(g, &"shot"):
						last = maxf(last, float(s["arrive"]))
				if firing and w.player.lane == p and float(state["back_at"]) < 0.0:
					w.player.press(&"move_left")
					state["dodges"] = int(state["dodges"]) + 1
					state["back_at"] = INF
				elif not firing and float(state["back_at"]) == INF:
					state["back_at"] = last + 0.05
				elif float(state["back_at"]) >= 0.0 and float(state["back_at"]) < INF and w.level_time() >= float(state["back_at"]):
					w.player.press(&"move_right")
					state["back_at"] = -1.0
				return not w.player.alive or w.player.distance > end + 5.0
			await _step_until(w, bot, 17.0)
			check(w.player.alive, "a rider who dodges every burst on a two-lane ceiling survives %s (%s)" % [tag, cause[0]])
			check(int(state["dodges"]) >= (2 if pair else 1), "each turret fired at them %s (%d bursts dodged)" % [tag,
				int(state["dodges"])])
			for g: CyborgGun in guns:
				for s: Dictionary in _events_of(g, &"shot"):
					var impact: float = s["impact"]
					for at: float in ats:
						if at > impact:
							check(at - BarnacleTurret.BODY_SIZE.z * 0.5 - impact >= bt.clear_after_impact + bt.body_reach - 0.05,
								"no bolt arrives close before a turret in the other lane (%.1f m before %.0f) %s"
								% [at - impact, at, tag])
			await sim.free_world(w)


## GDD §9.8: its body is the cyborg's: running into it is deadly, and armor doesn't help; the shield
## blocks that once; claws and the dash defeat it; a rider who jumps and drops back onto its crown
## stomps it, and bounces.
func _test_contact() -> void:
	var cases: Array = [["none", {}], ["armor", {"armor": 1}], ["shield", {"shield": 1}], ["claws", {"claws": 1}]]
	for c: Array in cases:
		var w: RunWorld = sim.build_world(_layout(3, 1), _loadout(c[1]))
		var t: BarnacleTurret = _spawn(w, TURRET_AT, 1, {"fires": false})
		var r: Dictionary = await sim.step_world(w, 9.5)
		match String(c[0]):
			"none":
				check(not r["alive"] and r["cause"] == t.display_name, "running into it kills (%s)" % r["cause"])
			"armor":
				check(not r["alive"] and r["cause"] == t.display_name and w.player.armor == 1,
					"armor doesn't help against its body (%s)" % r["cause"])
			"shield":
				check(r["alive"] and w.player.shield == 0 and is_instance_valid(t) and t.alive,
					"the shield blocks its body once (%s)" % r["cause"])
			"claws":
				check(r["alive"] and w.score.kills == 1, "claws defeat it on contact (%s)" % r["cause"])
		await sim.free_world(w)
	# The dash.
	var w: RunWorld = sim.build_world(_layout(3, 1))
	var t: BarnacleTurret = _spawn(w, TURRET_AT, 1, {"fires": false})
	await _step_until(w, func() -> bool: return t.track_distance() - w.player.distance <= 6.0, 10.0)
	w.player.start_dash(0.8, 0.0)
	var r: Dictionary = await sim.step_world(w, 1.5)
	check(r["alive"] and w.score.kills == 1, "the dash defeats it (%s)" % r["cause"])
	await sim.free_world(w)
	# The stomp: jump on the ceiling so the drop back meets its crown.
	w = sim.build_world(_layout(3, 1))
	t = _spawn(w, TURRET_AT, 1, {"fires": false})
	var causes: Array[StringName] = []
	t.defeated.connect(func(_e: Enemy, cause: StringName) -> void: causes.append(cause))
	await _step_until(w, func() -> bool: return t.track_distance() - w.player.distance <= _stomp_lead(), 10.0)
	check(w.player.surface == Player.Surface.CEILING and w.player.grounded, "the rider is on the ceiling, in its lane")
	w.player.press(&"jump")
	r = await sim.step_world(w, 1.5)
	check(r["alive"] and r["events"].has(&"stomp") and causes == [&"stomp"],
		"a rider who drops back onto its crown stomps it (%s, %s)" % [r["cause"], causes])
	check(w.score.stomps == 1 and w.score.kills == 1, "the stomp counts as a kill")
	await sim.free_world(w)


## How far before it a rider on the ceiling jumps to come back down onto its crown: the drop reaches
## the crown's far side (REACH_BELOW from the underside) this far into the jump, at the run speed.
func _stomp_lead() -> float:
	var g_down: float = tuning.gravity() * tuning.fall_gravity_multiplier
	var t_apex: float = tuning.jump_velocity() / tuning.gravity()
	var t_crown: float = t_apex + sqrt(2.0 * (tuning.jump_height - BarnacleTurret.REACH_BELOW) / g_down)
	return tuning.run_speed * t_crown


## GDD §9.8 and §8: 7 laser tier 1 shots where it first appears (its 5 plain ones, stretched by tier 1's
## rule, WeaponPowerup.damage()), slightly more later (8 at the campaign's end); auto-fire only targets
## it once it's out of its hatch.
func _test_weapons() -> void:
	for scaling: float in [campaign.configure(campaign.step("marketplace/1"), 3).enemy_scaling, 1.0]:
		var config := LevelConfig.new()
		config.enemy_scaling = scaling
		var w: RunWorld = sim.build_world(_layout(3, 2), _loadout({"weapon": 1}), null, config)
		var c := w.powerups as PowerupController
		var t: BarnacleTurret = _spawn(w, 70.0, 0, {"fires": false})
		var dmg: float = c.weapon.damage(t)
		var plain: float = t.max_health
		check(is_equal_approx(plain, 5.0 if scaling < 0.5 else 6.0), "its plain health at scaling %.2f (%.0f)" % [scaling, plain])
		check(c.weapon.pick_target() == null, "auto-fire doesn't target it in its hatch")
		await _step_until(w, func() -> bool: return t.out, 4.0)
		await _step_until(w, func() -> bool: return c.weapon.pick_target() == t or not t.alive, 3.0)
		check(not t.alive or c.weapon.pick_target() == t, "and does once it's out")
		await sim.free_world(w)
		# Laser tier 1 shots, each with the weapon's own damage against it, until it falls.
		var expected: int = 7 if scaling < 0.5 else 8
		w = sim.build_world(_layout(3, 2), null, null, config)
		t = _spawn(w, 70.0, 0, {"fires": false})
		await _step_until(w, func() -> bool: return t.out, 4.0)
		var shots: int = 0
		while t.alive and shots < 20:
			w.projectiles.fire_player(t.aim_point() + Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -90.0), dmg)
			shots += 1
			await physics_frames(10)
		check(not t.alive and shots == expected and w.score.kills == 1,
			"%d laser tier 1 shots kill it at scaling %.2f (took %d)" % [expected, scaling, shots])
		await sim.free_world(w)


## GDD §9.8: armor and the shield both block its bolts.
func _test_armor_and_shield() -> void:
	for item: String in ["armor", "shield"]:
		var w: RunWorld = sim.build_world(_layout(3, 1), _loadout({item: 1}))
		var t: BarnacleTurret = _spawn(w, TURRET_AT, 0)
		await _step_until(w, func() -> bool: return not _events_of(t.gun, &"shot").is_empty(), 10.0)
		await _step_until(w, func() -> bool: return t.gun.state == CyborgGun.State.RELOADING, 2.0)
		var last: float = 0.0
		for s: Dictionary in _events_of(t.gun, &"shot"):
			last = maxf(last, float(s["arrive"]))
		await _step_until(w, func() -> bool: return w.level_time() > last + 0.1 or not w.player.alive, 3.0)
		var used: bool = w.player.armor == 0 if item == "armor" else w.player.shield == 0
		check(w.player.alive and used, "%s blocks its bolts" % item)
		await sim.free_world(w)


## The same seed plays out the same way: two runs of the same rider fire the same bolts at the same
## moments.
func _test_determinism() -> void:
	var runs: Array[String] = []
	for k: int in 2:
		var w: RunWorld = sim.build_world(_layout(5, 2))
		w.player.god_mode = true
		var gun: CyborgGun = _spawn(w, TURRET_AT, 1, {}, 31).gun
		await _step_until(w, func() -> bool: return w.player.distance > CEIL_END, 12.0)
		var lines: Array[String] = []
		for e: Dictionary in gun.events:
			lines.append("%s %.4f %.4f" % [e["event"], float(e["t"]), float(e.get("impact", 0.0))])
		runs.append("\n".join(lines))
		await sim.free_world(w)
	check(runs[0] != "" and runs[0] == runs[1], "two runs at the same seed fire the same bolts")


## Generated levels played through by a rider who takes every pad (god mode, grapples for the gaps):
## every burst comes from a turret ahead of a rider on its own ceiling, after its charge-up, with
## enough warning, its bolts arriving while the rider is still on the ceiling; one burst in the air at
## a time; never at a player off its ceiling.
func _test_fair_play() -> void:
	var bursts_total: int = 0
	for c: Array in [["corporate/2", 3], ["corporate/2", 5], ["marketplace/2", 6]]:
		var config: LevelConfig = campaign.configure(campaign.step(String(c[0])), int(c[1]))
		var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
		var tag: String = "%s lanes=%d" % [c[0], c[1]]
		var w: RunWorld = sim.build_world(layout, _loadout({"grapple": 999}), null, config)
		w.player.god_mode = true
		# Each turret's gun and ceiling (turrets leave play, freed, once the player is well past).
		var met: Array[Dictionary] = []
		w.director.enemy_spawned.connect(func(e: Enemy) -> void:
			if e is BarnacleTurret:
				var turret := e as BarnacleTurret
				met.append({"gun": turret.gun, "start": turret.hull_start, "end": turret.hull_end}))
		var state := {"off_ceiling": 0, "last_press": -100, "frame": 0}
		var bot := func() -> bool:
			state["frame"] = int(state["frame"]) + 1
			var p: Player = w.player
			for m: Dictionary in met:
				var g: CyborgGun = m["gun"]
				if (g.state == CyborgGun.State.CHARGING or g.state == CyborgGun.State.FIRING) and g.shooter != null \
						and is_instance_valid(g.shooter) and g.shooter.alive and p.surface != Player.Surface.CEILING:
					state["off_ceiling"] = int(state["off_ceiling"]) + 1
			# Head for the next pad's lane.
			if p.surface == Player.Surface.FLOOR and int(state["frame"]) - int(state["last_press"]) > 12:
				for pad: Dictionary in layout.pads:
					var ahead: float = float(pad["at"]) - p.distance
					if ahead > 2.0 and ahead < 40.0:
						if p.lane != int(pad["lane"]):
							p.press(&"move_right" if int(pad["lane"]) > p.lane else &"move_left")
							state["last_press"] = state["frame"]
						break
			return p.distance > 1500.0
		await _step_until(w, bot, 90.0)
		check(int(state["off_ceiling"]) == 0, "it never charges or fires at a player off its ceiling %s" % tag)
		var bursts: Array = []
		for m: Dictionary in met:
			var gun: CyborgGun = m["gun"]
			var charge_t: float = -1.0
			var first: bool = false
			for ev: Dictionary in gun.events:
				match ev["event"]:
					&"charge":
						charge_t = ev["t"]
						first = true
						bursts.append([float(ev["t"]), float(ev["t"])])
						check(float(ev["player_d"]) >= float(m["start"]) - 0.5 and float(ev["player_d"]) <= float(m["end"]),
							"a charge-up only at a rider on its ceiling %s" % tag)
					&"cancel":
						charge_t = -1.0
					&"shot":
						var at: float = ev["t"]
						check(charge_t >= 0.0 and at - charge_t >= bt.charge_time - 0.02, "every bolt follows a charge-up " + tag)
						check(float(ev["shooter_d"]) > float(ev["player_d"]), "bolts only come from ahead " + tag)
						var warning: float = float(ev["arrive"]) - at
						check(warning >= (bt.min_warning_time if first else bt.min_warning_time * 0.5) - 0.02,
							"every bolt gives enough warning (%.2f s) %s" % [warning, tag])
						first = false
						check(float(ev["impact"]) + bt.clear_after_impact <= float(m["end"]) - bt.end_margin + 0.5,
							"every bolt arrives while the rider is still on the ceiling %s" % tag)
						bursts[-1][1] = at
		bursts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for k: int in range(1, bursts.size()):
			check(float(bursts[k][0]) >= float(bursts[k - 1][1]) - 0.001, "one burst in the air at a time " + tag)
		bursts_total += bursts.size()
		check(not met.is_empty(), "the run met turrets %s" % tag)
		await sim.free_world(w)
	check(bursts_total >= 3, "turrets fire through generated levels (%d bursts)" % bursts_total)
