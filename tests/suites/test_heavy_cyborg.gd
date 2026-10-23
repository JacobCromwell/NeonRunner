extends TestSuite
## The Heavy Cyborg (GDD §9.16; task S1): a bigger, bulkier cyborg with a gatling.
## - Its numbers: twice a cyborg's shots to kill at every weapon tier and twice its score in every level it appears
##   in; a stream that fits the hit invulnerability window, spaced to zigzag through, after a readable wind-up, that
##   fits between where it engages and where the runner reaches it; the cyborg numbers it never reads hidden from the
##   editor and the F6 panel.
## - Its hitboxes and look: the body below the stomp line, the stompable top within a jump's reach and above a
##   standing runner, both inside a body drawn bigger and bulkier than a cyborg's; its look's armour; only the face
##   and the gatling glow; a warm-up look built outside the tree with every part shown and nothing physical.
## - The warning before the stream (the wind-up's sound lasting it, the red aim line on the runner, the barrels hot),
##   the stream itself (hits a runner who stays on its line, misses one who switches lanes once it fires, follows one
##   who moves during the wind-up, lets one zigzag back through it), armor and the shield through a whole stream,
##   no fire at a ceiling rider, a teleport calling it off.
## - A cyborg's small attack: its stream takes one of the cyborgs' places in the air (never more than
##   GameRules.max_bursts_in_air at once; with the limit at one, it and a cyborg take turns), keeps their crossfire
##   rule (a cyborg's burst that would leave no way out waits for its stream), and takes no part in the big attacks'
##   turns (it fires through another type's big attack, and holds none back).
## - Its kills: a stomp on its head and the dash kill it; the claws don't (a claw runner who touches it dies), nor
##   does armor stop its body; laser tier 1 takes twice a cyborg's shots; another enemy's charge and a falling
##   gantryway destroy it; it never boards an Enforcer Truck.
## - The stream when it no longer fits whole: as many rounds as still fit, min_stream_rounds at the least, every one
##   flying its warning from the barrels' tips; with fewer than that, none.
## - The generator (HeavyCyborgRules: its pattern's cyborgs and the top-up, last of the rules), over seeds, lane counts
##   and difficulties: each Heavy Cyborg where its stream gets to fire (its stream's zone clear of every gap, live fence
##   and doodad in every lane: what its gun's path_clear holds a stream for; no cyborg or window cyborg within a second
##   of run of it), clear of every obstacle, off the stretches a cyborg may stand nearer to than other enemies, spaced,
##   the level's last plain cyborg kept, the same every build, most builds with some, none without the feature; the campaign's levels (introduced in
##   Relay Station from its start, after the teleporters; Specimen Vault and Golden 1-3 with no introduction of their
##   own; none in Frost Foundry; every build on their own seeds with two at the campaign's lane count and one at least
##   at 3 and 6 lanes, every one where its stream gets to fire); and full levels in god mode, every round fair, every
##   Heavy Cyborg passed firing. test_heavy_cyborg_play plays the campaign's own builds.

const CyborgRules = preload("res://scripts/enemies/cyborg_rules.gd")
const HeavyRules = preload("res://scripts/enemies/heavy_cyborg_rules.gd")
const GantrywayRules := preload("res://scripts/enemies/gantryway_rules.gd")
const HEAVY_TUNING_PATH: String = "res://data/enemies/heavy_cyborg.tres"
const CYBORG_TUNING_PATH: String = "res://data/enemies/cyborg.tres"
const CAMPAIGN_PATH: String = "res://data/campaign/campaign.tres"
const TURN_DUMMY: String = "res://tests/helpers/turn_dummy.gd"
## The campaign levels that list it (GDD §9.16, proposed: Relay Station, then Specimen Vault; and all three of the
## Golden Zone's, owner), the one that brings it in, and the Ice Lab's level before it.
const LEVELS: Array[String] = ["ice_lab/2", "ice_lab/3", "golden/1", "golden/2", "golden/3"]
const INTRODUCED_IN: String = "ice_lab/2"
const BEFORE: String = "ice_lab/1"
## Jump this far (track distance) before it to drop onto its top on the way down from the jump's highest point.
const STOMP_LEAD: float = 8.5
## A round that would reach the runner's spot within this long, closer than this sideways, is dodged (the airspace
## suite's dodging runner).
const BOLT_REACT: float = 0.7
const BOLT_REACH: float = 0.75
## The gantryway take's pillar and run (test_gantryways' hand-built track).
const PILLAR: float = 90.0
const RUN_SECONDS: float = 7.5

var sim: RunSim
var ht: HeavyCyborgTuning
var ct: CyborgTuning
var campaign: Campaign


func run() -> void:
	sim = RunSim.new(tree, tuning)
	ht = load(HEAVY_TUNING_PATH) as HeavyCyborgTuning
	ct = load(CYBORG_TUNING_PATH) as CyborgTuning
	campaign = load(CAMPAIGN_PATH) as Campaign
	check(ht != null and ct != null and campaign != null, "its tuning, the cyborg's and the campaign load")
	if ht == null or ct == null or campaign == null:
		return
	_test_numbers()
	_test_hitboxes()
	_test_warning_sound()
	await _test_look()
	await _test_stream()
	await _test_partial_stream()
	await _test_dodge()
	await _test_follows_windup()
	await _test_zigzag()
	await _test_protection()
	await _test_ceiling()
	await _test_teleport()
	await _test_airspace()
	await _test_limit_of_one()
	await _test_crossfire()
	await _test_no_turns()
	await _test_contact()
	await _test_weapons()
	await _test_charges()
	await _test_gantryway()
	await _test_enforcer()
	_test_generation()
	_test_campaign()
	await _test_fair_play()


# --- Helpers ----------------------------------------------------------------------------------------

func _spawn(w: RunWorld, at: float, lane: int, params: Dictionary = {}, seed_value: int = 7) -> HeavyCyborg:
	return w.director.spawn({"type": "heavy_cyborg", "at": at, "lane": lane, "side": 0, "seed": seed_value,
		"params": params}) as HeavyCyborg


func _cyborg(w: RunWorld, at: float, lane: int, seed_value: int, params: Dictionary = {"panic": false}) -> Cyborg:
	return w.director.spawn({"type": "cyborg", "at": at, "lane": lane, "side": 0, "seed": seed_value,
		"params": params}) as Cyborg


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


## Steps the world a frame at a time (the runner running) until `done` returns true or `seconds` pass; `each` runs
## before every frame (a bot's input).
func _step_until(w: RunWorld, done: Callable, seconds: float, each: Callable = Callable()) -> bool:
	if not w.player.running:
		await tree.physics_frame
		w.player.running = true
	for i: int in int(seconds * Engine.physics_ticks_per_second):
		if each.is_valid():
			each.call()
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


## The predicted arrivals (level times) of a gun's rounds, in order.
static func _arrivals(gun: CyborgGun) -> Array[float]:
	var out: Array[float] = []
	for e: Dictionary in _events_of(gun, &"shot"):
		out.append(float(e["arrive"]))
	out.sort()
	return out


## Every burst of `guns`, in each gun's order: {"gun", "start", "end", "cancelled", "why", "shots", "line", "first",
## "last"} (as test_cyborg_airspace reads them).
static func _bursts(guns: Array[CyborgGun]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in guns.size():
		var cur: Dictionary = {}
		for ev: Dictionary in guns[i].events:
			match ev["event"]:
				&"charge":
					cur = {"gun": i, "start": float(ev["t"]), "end": float(ev["t"]), "cancelled": false, "why": &"",
						"shots": 0, "line": 0.0, "first": INF, "last": -INF}
					out.append(cur)
				&"cancel":
					cur["end"] = float(ev["t"])
					cur["cancelled"] = true
					cur["why"] = ev.get("why", &"")
				&"shot":
					cur["end"] = float(ev["t"])
					cur["shots"] = int(cur["shots"]) + 1
					cur["line"] = float(ev["line"])
					cur["first"] = minf(float(cur["first"]), float(ev["arrive"]))
					cur["last"] = maxf(float(cur["last"]), float(ev["arrive"]))
	return out


## The most bursts in the air at once, from each burst's [its charge-up, its last round or its cancel] (as
## test_cyborg_airspace counts them: one that ends as another starts doesn't overlap it).
static func _most_at_once(bursts: Array[Dictionary]) -> int:
	var most: int = 0
	for b: Dictionary in bursts:
		var on: int = 0
		for o: Dictionary in bursts:
			if float(o["start"]) <= float(b["start"]) and (is_same(o, b) or float(o["end"]) > float(b["start"]) + 0.001):
				on += 1
		most = maxi(most, on)
	return most


static func _fired(bursts: Array[Dictionary], gun: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in bursts:
		if int(b["gun"]) == gun and int(b["shots"]) > 0:
			out.append(b)
	return out


## A runner watching the rounds and bolts: one that would reach its spot within BOLT_REACT seconds, closer than
## BOLT_REACH sideways, sends it to the nearest lane (one over, else two) none is heading for and no cyborg (a Heavy
## Cyborg among them) stands in just ahead.
static func _dodge(w: RunWorld) -> void:
	var p: Player = w.player
	if not p.alive or p.surface != Player.Surface.FLOOR or not _bolt_toward(w, p.lane):
		return
	for s: int in [1, -1, 2, -2]:
		var to: int = p.lane + s
		if to < 0 or to >= w.geo.lane_count or _bolt_toward(w, to) or _cyborg_ahead(w, to):
			continue
		for k: int in absi(s):
			p.press(&"move_right" if s > 0 else &"move_left")
		return


## True if a living cyborg (a Heavy Cyborg too) stands in `lane` within 30 m ahead of the runner.
static func _cyborg_ahead(w: RunWorld, lane: int) -> bool:
	for e: Enemy in w.director.active:
		var c := e as Cyborg
		if c != null and is_instance_valid(c) and c.alive and c.lane == lane \
				and c.track_distance() > w.player.distance and c.track_distance() < w.player.distance + 30.0:
			return true
	return false


static func _bolt_toward(w: RunWorld, lane: int) -> bool:
	var p: Player = w.player
	var x: float = w.geo.lane_x(lane)
	for shot: Projectile in w.projectiles.live_shots():
		if shot.friendly:
			continue
		var gap: float = -shot.global_position.z - p.distance
		var closing: float = shot.velocity.z + p.speed
		if gap < -0.5 or closing <= 0.1:
			continue
		var t: float = maxf(gap, 0.0) / closing
		if t <= BOLT_REACT and absf(shot.global_position.x + shot.velocity.x * t - x) < BOLT_REACH:
			return true
	return false


## No live fence and no gap in any lane between two track distances.
static func _clear(layout: LevelLayout, from_d: float, to_d: float) -> bool:
	for f: Dictionary in layout.fences:
		if float(f["at"]) >= from_d and float(f["at"]) <= to_d and not f.get("disabled", false):
			return false
	for g: Dictionary in layout.gaps:
		if float(g["start"]) <= to_d and float(g["end"]) >= from_d:
			return false
	return true


## Laser shots of `tier` to kill an enemy with `health` (WeaponPowerup.damage: laser tier 1 takes
## PowerupTuning.tier1_extra_shots more than its plain count, every other tier its plain count).
static func _shots_to_kill(health: float, tier: int, pt: PowerupTuning) -> int:
	var plain: float = PowerupTuning.at_tier(pt.weapon_damage, tier)
	var shots: int = ceili(health / plain - 0.0001)
	if tier == 1 and pt.tier1_extra_shots > 0 and shots > 1:
		shots += pt.tier1_extra_shots
	return shots


## The world-space box round every mesh drawn under `node` (the aim line, top level, left out).
static func _visual_box(node: Node) -> AABB:
	var out := AABB()
	var first: bool = true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree() or mi.top_level:
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


static func _count(node: Node, kind: String) -> int:
	var n: int = 1 if node.is_class(kind) else 0
	for child: Node in node.get_children():
		n += _count(child, kind)
	return n


# --- Its numbers ------------------------------------------------------------------------------------

func _test_numbers() -> void:
	# The cyborg numbers it never reads are hidden from the editor and the F6 panel; its own show.
	var shown := PackedStringArray()
	for prop: Dictionary in ht.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			shown.append(String(prop["name"]))
	for name: String in HeavyCyborgTuning.UNUSED:
		check(not shown.has(name), "`%s` (a cyborg's, unused) is hidden from the F6 panel" % name)
	for name: String in ["engage_distance", "charge_time", "reload_late", "bolt_speed_late", "bullets_late",
			"bullet_gap_late", "invulnerability_share", "later_round_warning_share", "min_stream_rounds", "model_scale",
			"health_late", "score_value", "walk_speed", "obstacle_margin", "keep_clear_seconds", "share", "spacing_seconds",
			"rival_clear_seconds", "windup_heard_within", "crossfire_gap"]:
		check(shown.has(name), "`%s` is in the F6 panel" % name)
	check(ht.score_value == 2 * ct.score_value, "it pays twice a cyborg's score (%d, %d)" % [ht.score_value, ct.score_value])
	# Owner: twice a cyborg's laser hits (laser tier 1); proposed: the other tiers and the missiles twice too.
	var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
	for id: String in LEVELS:
		var scaling: float = campaign.configure(campaign.step(id), 5).enemy_scaling
		for tier: int in range(1, 5):
			var cyborg: int = _shots_to_kill(ct.health_at(scaling), tier, pt)
			var heavy: int = _shots_to_kill(ht.health_at(scaling), tier, pt)
			check(heavy == 2 * cyborg, "%s (enemy scaling %.3f): weapon tier %d takes %d shots, twice a cyborg's %d"
				% [id, scaling, tier, heavy, cyborg])
	# The stream (GDD §9.6's barrage): it fits the invulnerability window, its rounds are spaced to zigzag through, the
	# wind-up is a readable warning, and a whole stream fits between where it engages and where the runner reaches it.
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	for s: float in [0.0, 0.25, 0.5, 0.75, 0.86, 1.0]:
		var n: int = ht.barrage_count(s, rules.hit_invulnerability)
		var gap: float = ht.bullet_gap_at(s)
		var round_speed: float = ht.bolt_speed_at(s)
		var closing: float = round_speed + MovementTuning.REFERENCE_SPEED
		check(n >= 5 and (n - 1) * gap <= rules.hit_invulnerability * ht.invulnerability_share + 0.0001,
			"scaling %.2f: a stream of %d rounds arrives within the invulnerability window (%.2f s)" % [s, n, (n - 1) * gap])
		check(ht.min_stream_rounds >= 2 and ht.min_stream_rounds < n,
			"scaling %.2f: a stream that no longer fits whole still fires %d of its %d rounds" % [s, ht.min_stream_rounds, n])
		# A round fills the runner's depth for (hurtbox + round) / closing speed; the rest is the gap to zigzag through.
		var busy: float = (tuning.hurtbox_size.z + 0.5) / closing
		check(gap - busy > 0.08, "scaling %.2f: %.2f s between rounds to zigzag through" % [s, gap - busy])
		var interval: float = gap * closing / round_speed
		var need: float = MovementTuning.REFERENCE_SPEED * (ht.charge_time + (n - 1) * interval) \
			+ ht.min_warning_time * 0.5 * closing
		check(ht.engage_distance >= need, "scaling %.2f: a whole stream fits before the runner reaches it (%.1f m of %.1f)"
			% [s, need, ht.engage_distance])
	check(ht.charge_time >= 0.8, "the wind-up is a readable warning (%.2f s)" % ht.charge_time)
	check(ht.aim_error + ht.shot_jitter < 0.3, "the stream stays on its line: a runner who keeps to it is hit")


## The body ends below the stomp line, the top starts above a standing runner and ends within a jump's reach.
func _test_hitboxes() -> void:
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var top: float = HeavyCyborg.TOP_Y + HeavyCyborg.TOP_BOX.y * 0.5
	var bottom: float = HeavyCyborg.TOP_Y - HeavyCyborg.TOP_BOX.y * 0.5
	check(HeavyCyborg.BODY_BOX.y <= top - rules.stomp_tolerance + 0.001,
		"the body ends below the stomp line, so dropping onto its top only touches its top")
	check(bottom > tuning.hurtbox_size.y, "a running player can't touch the stomp zone (only a jumping one)")
	check(top <= tuning.jump_height + 0.001 and top - rules.stomp_tolerance < tuning.jump_height,
		"its stompable top is within a jump's reach (%.2f m; a jump's feet reach %.2f m)" % [top, tuning.jump_height])
	check(HeavyCyborg.BODY_BOX.x > Cyborg.BODY_SIZE.x and HeavyCyborg.TOP_BOX.x > Cyborg.HEAD_SIZE.x,
		"its hitboxes are wider than a cyborg's, as its body is")
	check(HeavyCyborg.BODY_BOX.x * 0.5 + tuning.hurtbox_size.x * 0.5 < tuning.lane_width,
		"a runner in the lane beside it never touches it")


## The audio half of the warning lasts the whole wind-up and ends as the first round fires.
func _test_warning_sound() -> void:
	var library := load("res://data/audio/sfx_library.tres") as SfxLibrary
	for sound: StringName in [&"heavy_cyborg_windup", &"heavy_cyborg_shot"]:
		check(library != null and library.names().has(String(sound)) and library.stream(sound) != null,
			"the sound library has '%s'" % sound)
	var windup: AudioStream = library.stream(&"heavy_cyborg_windup") if library != null else null
	var length: float = windup.get_length() if windup != null else 0.0
	check(length >= ht.charge_time and length <= ht.charge_time + 0.1,
		"the wind-up's sound (%.2f s) lasts the whole %.2f s wind-up" % [length, ht.charge_time])
	check(library != null and float(library.pitch_variation.get("heavy_cyborg_windup", 0.0)) == 0.0,
		"the warning sounds the same every time (no pitch variation)")


# --- Its look ---------------------------------------------------------------------------------------

func _test_look() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 400.0))
	var heavy: HeavyCyborg = _spawn(w, 60.0, 1, {"fires": false})
	var cyborg: Cyborg = _cyborg(w, 60.0, 0, 3, {"panic": false, "fires": false})
	await physics_frames(3)
	var hb := heavy.body as HeavyCyborgBody
	check(hb != null, "its body is a heavy one")
	if hb == null:
		await sim.free_world(w)
		return
	var hbox: AABB = _visual_box(hb)
	var cbox: AABB = _visual_box(cyborg.body)
	check(hbox.size.y > cbox.size.y * 1.1 and hbox.size.x > cbox.size.x * 1.3,
		"bigger and much bulkier than a cyborg (%.2f m tall, %.2f wide; a cyborg %.2f, %.2f)" % [hbox.size.y, hbox.size.x,
			cbox.size.y, cbox.size.x])
	var top: float = HeavyCyborg.TOP_Y + HeavyCyborg.TOP_BOX.y * 0.5
	check(hbox.size.x > HeavyCyborg.BODY_BOX.x and hbox.end.y > top + 0.15,
		"its hitboxes are smaller than its body (drawn %.2f m tall and %.2f wide)" % [hbox.end.y, hbox.size.x])
	check(hb.rig.attachments().has(CyborgSuit.heavy_set(hb.look)) and hb.rig.attachments().has(CyborgSuit.look_for(hb.look)),
		"it wears its zone's look with that look's armour over it (%s)" % [hb.rig.attachments()])
	# The cannon's orb grows with the material's charge, which a Heavy Cyborg never sets (null: never set at all).
	var orb: Variant = hb.material.get_shader_parameter(&"charge")
	check((orb == null or is_zero_approx(float(orb))) and not hb.barrels_hot() and not hb.aim_line_shown(),
		"at rest nothing of it glows but its face: the cannon's orb never grows, the gatling is cold, no aim line")
	check(hb.draw_call_count() <= 20, "a cyborg's draw calls and its gatling's (%d)" % hb.draw_call_count())
	check(not heavy.is_host and not heavy.is_panic and heavy.claw_immune and heavy.stompable and heavy.dash_kills
		and not heavy.immune_to_weapons and heavy.type_id == &"heavy_cyborg" and heavy.score_value == ht.score_value,
		"never a host or a panic variant; claw-immune, stompable, killed by the dash and by weapons")
	# Never a host, even if a pattern says so, and it brings nothing into play.
	var asked: HeavyCyborg = _spawn(w, 80.0, 2, {"fires": false, "host": true, "panic": true}, 9)
	check(not asked.is_host and not asked.is_panic and HeavyCyborg.brings({"params": {"host": true}}).is_empty(),
		"no host and no panic variant, whatever its params (GDD §9.16)")
	# EnemyDirector.warm_up's look: built outside the tree, with every part it shows later, and nothing physical.
	var look := HeavyCyborg.warm_up(w, {"type": "heavy_cyborg", "at": 1.0, "lane": 1, "seed": 4, "params": {}}) as HeavyCyborgBody
	check(look != null and not look.is_inside_tree() and look.aim_line_shown() and look.barrels_hot()
		and _count(look, "CollisionObject3D") == 0 and _count(look, "GeometryInstance3D") > 10,
		"its warm-up look is built outside the tree, every part shown, nothing physical")
	if look != null:
		look.free()
	await sim.free_world(w)


# --- The stream -------------------------------------------------------------------------------------

## The warning before every stream, the stream's spacing, and a runner who stays on its line is hit.
func _test_stream() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.god_mode = true
	var heavy: HeavyCyborg = _spawn(w, 110.0, 2)
	var gun := heavy.gun as HeavyCyborgGun
	var hb := heavy.body as HeavyCyborgBody
	var seen := {"line": false, "hot": false, "on_runner": true, "early": false}
	var fired: bool = await _step_until(w, func() -> bool:
		if gun.state == CyborgGun.State.CHARGING:
			seen["line"] = bool(seen["line"]) or hb.aim_line_shown()
			seen["hot"] = bool(seen["hot"]) or hb.barrels_hot()
			var c: Vector3 = w.player.hurtbox_aabb().get_center()
			seen["on_runner"] = bool(seen["on_runner"]) and hb.aim_line_target().distance_to(c) < 1.0
		elif gun.state == CyborgGun.State.READY and hb.aim_line_shown():
			seen["early"] = true
		return not _events_of(gun, &"shot").is_empty(), 8.0)
	check(fired, "it fires at an approaching runner")
	check(bool(seen["line"]) and bool(seen["hot"]) and bool(seen["on_runner"]) and not bool(seen["early"]),
		"its wind-up shows first: the red aim line on the runner and the barrels red-hot (%s)" % [seen])
	check(gun.charge_sound == &"heavy_cyborg_windup" and gun.look == HeavyCyborgGun.BULLET_LOOK,
		"with the wind-up's sound, and its rounds the drone gatling's look")
	await _step_until(w, func() -> bool: return gun.state == CyborgGun.State.RELOADING, 4.0)
	var charges: Array[Dictionary] = _events_of(gun, &"charge")
	var shots: Array[Dictionary] = _events_of(gun, &"shot")
	check(not charges.is_empty() and not shots.is_empty(), "a wind-up, then rounds")
	if not charges.is_empty() and not shots.is_empty():
		check(float(shots[0]["t"]) - float(charges[0]["t"]) >= ht.charge_time - 0.02,
			"the wind-up (%.2f s) comes before the first round" % (float(shots[0]["t"]) - float(charges[0]["t"])))
		check(float(shots[0]["arrive"]) - float(shots[0]["t"]) >= ht.min_warning_time,
			"the first round takes at least the minimum warning time to arrive")
		var n: int = gun.most_shots()
		check(int(charges[0]["shots"]) == n and shots.size() == n, "a stream of %d rounds (%d fired)" % [n, shots.size()])
		var arrivals: Array[float] = _arrivals(gun)
		var gap: float = ht.bullet_gap_at(w.config.enemy_scaling)
		var spaced: bool = true
		for i: int in range(1, arrivals.size()):
			spaced = spaced and absf(arrivals[i] - arrivals[i - 1] - gap) < 0.02
		check(spaced, "its rounds reach the runner %.2f s apart, the gap to zigzag through (%s)" % [gap, arrivals])
		# Each round leaves on the first physics frame its interval allows (CyborgGun._fire_step), so a stream runs up to a
		# frame a round longer than planned: well inside the window all the same.
		var frames: float = (arrivals.size() - 1) / float(Engine.physics_ticks_per_second)
		check(arrivals[-1] - arrivals[0] <= w.rules.hit_invulnerability * ht.invulnerability_share + frames
			and arrivals[-1] - arrivals[0] < w.rules.hit_invulnerability,
			"the whole stream arrives within the hit invulnerability window (%.2f s)" % (arrivals[-1] - arrivals[0]))
		for s: Dictionary in shots:
			check(absf(float(s["line"]) - float(shots[0]["line"])) < 0.001 and float(s["shooter_d"]) > float(s["player_d"]),
				"every round flies down the one locked line, from ahead")
	await sim.free_world(w)
	# Without god mode, a runner who keeps to the line is hit.
	w = sim.build_world(RunSim.layout(3, 600.0))
	_spawn(w, 110.0, 2)
	var r: Dictionary = await sim.step_world(w, 8.0)
	check(not r["alive"] and r["cause"] == HeavyCyborgGun.GATLING_NAME,
		"a stream hits a runner who stays on its line (%s)" % r["cause"])
	await sim.free_world(w)


## The review's partial streams: a stream that starts late (its gun held until the runner is nearer than a whole stream
## fits: at the reference speed and the lowest scaling, its 6 rounds need the wind-up to start about 66 m off, 4 about
## 54 m off) fires as many of its rounds as still fit, min_stream_rounds at the least, each flying its warning from the
## barrels' tips (the first min_warning_time, the rest later_round_warning_share of it: HeavyCyborgGun.min_flight_time);
## let go where fewer than that fit, it fires none.
func _test_partial_stream() -> void:
	for let_go: float in [58.0, 50.0]:
		var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
		w.player.god_mode = true
		var heavy: HeavyCyborg = _spawn(w, 110.0, 1, {"fires": false})
		var gun := heavy.gun as HeavyCyborgGun
		await _step_until(w, func() -> bool:
			if not gun.enabled and heavy.track_distance() - w.player.distance <= let_go:
				gun.enabled = true
			return heavy.track_distance() < w.player.distance - 5.0, 8.0)
		var charges: Array[Dictionary] = _events_of(gun, &"charge")
		var shots: Array[Dictionary] = _events_of(gun, &"shot")
		var tag: String = "(let go %.0f m off: %d wind-ups, %d rounds)" % [let_go, charges.size(), shots.size()]
		if let_go > 54.0:
			check(charges.size() == 1 and shots.size() == int(charges[0]["shots"]) and shots.size() >= ht.min_stream_rounds
				and shots.size() < gun.most_shots(), "a stream that no longer fits whole fires the rounds that still do " + tag)
			for i: int in shots.size():
				var least: float = ht.min_warning_time * (1.0 if i == 0 else ht.later_round_warning_share)
				var flight: float = float(shots[i]["arrive"]) - float(shots[i]["t"])
				check(flight >= least - 0.005, "round %d flies %.3f s from the barrels' tips (%.3f at the least) %s"
					% [i, flight, least, tag])
		else:
			check(charges.is_empty() and shots.is_empty(), "one with fewer than %d rounds left to fire waits, and fires none %s"
				% [ht.min_stream_rounds, tag])
		await sim.free_world(w)


## A runner who switches lanes once the stream starts (its aim locked) dodges all of it.
func _test_dodge() -> void:
	for lanes: int in [3, 5, 6]:
		var w: RunWorld = sim.build_world(RunSim.layout(lanes, 600.0))
		var start: int = lanes / 2
		w.player.setup(w.tuning, w.geo, start)
		var heavy: HeavyCyborg = _spawn(w, 110.0, start)
		var gun: CyborgGun = heavy.gun
		await _step_until(w, func() -> bool: return gun.state == CyborgGun.State.FIRING, 8.0)
		w.player.press(&"move_left")
		await _step_until(w, func() -> bool: return gun.state == CyborgGun.State.RELOADING, 4.0)
		var arrivals: Array[float] = _arrivals(gun)
		var last: float = arrivals[-1] if not arrivals.is_empty() else 0.0
		await _step_until(w, func() -> bool: return w.level_time() > last + 0.3, 4.0)
		check(arrivals.size() == gun.most_shots() and w.player.alive and w.player.lane == start - 1,
			"%d lanes: one lane switch once it fires dodges the whole stream (%d rounds)" % [lanes, arrivals.size()])
		await sim.free_world(w)


## During the wind-up its aim follows the runner: one who switches early and stays there is hit.
func _test_follows_windup() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	var heavy: HeavyCyborg = _spawn(w, 110.0, 2)
	var died: Array[String] = [""]
	w.player.died.connect(func(cause: String) -> void: died[0] = cause)
	await _step_until(w, func() -> bool: return heavy.gun.state == CyborgGun.State.CHARGING, 8.0)
	w.player.press(&"move_left")
	await _step_until(w, func() -> bool: return not w.player.alive, 5.0)
	check(not w.player.alive and died[0] == HeavyCyborgGun.GATLING_NAME and w.player.lane == 0,
		"its aim follows a runner who moves during the wind-up (%s, lane %d)" % [died[0], w.player.lane])
	await sim.free_world(w)


## GDD §9.6: enough spacing between rounds to zigzag through: out of the stream, then back across it between two.
func _test_zigzag() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	var heavy: HeavyCyborg = _spawn(w, 110.0, 1)
	var gun: CyborgGun = heavy.gun
	await _step_until(w, func() -> bool: return gun.state == CyborgGun.State.FIRING, 8.0)
	w.player.press(&"move_left")
	await _step_until(w, func() -> bool: return false, 0.2)
	var passed: Array[int] = [0]
	var crossed: bool = await _step_until(w, func() -> bool:
		var n: int = 0
		for s: Projectile in w.projectiles.live_shots():
			if not s.friendly and s.position.z > w.player.position.z + 0.5:
				n += 1
		if n > passed[0] and passed[0] > 0:
			return true
		passed[0] = maxi(passed[0], n)
		return false, 3.0)
	w.player.press(&"move_right")
	w.player.press(&"move_right")
	await _step_until(w, func() -> bool: return gun.state == CyborgGun.State.RELOADING, 3.0)
	var arrivals: Array[float] = _arrivals(gun)
	var last: float = arrivals[-1] if not arrivals.is_empty() else 0.0
	await _step_until(w, func() -> bool: return w.level_time() > last + 0.3, 3.0)
	check(crossed and w.player.alive and w.player.lane == 2,
		"a runner can zigzag back through the stream between two rounds (lane %d, %d rounds)" % [w.player.lane, arrivals.size()])
	await sim.free_world(w)


## GDD §9.6 (the drone's): armor or a shield, with the invulnerability after a hit, protects through a whole stream.
func _test_protection() -> void:
	for item: String in ["armor", "shield"]:
		var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0), _loadout({item: 1}))
		var heavy: HeavyCyborg = _spawn(w, 110.0, 2)
		var gun: CyborgGun = heavy.gun
		await _step_until(w, func() -> bool: return gun.state == CyborgGun.State.RELOADING, 8.0)
		var arrivals: Array[float] = _arrivals(gun)
		var last: float = arrivals[-1] if not arrivals.is_empty() else 0.0
		await _step_until(w, func() -> bool: return w.level_time() > last + 0.4, 4.0)
		check(w.player.alive and w.score.blocked == 1 and arrivals.size() == gun.most_shots(),
			"%s protects through a whole stream (blocked %d, %d rounds)" % [item, w.score.blocked, arrivals.size()])
		await sim.free_world(w)


## It holds its fire at a runner riding a ceiling (as the cyborgs do), and fires at one on the floor below it.
func _test_ceiling() -> void:
	for ride: bool in [true, false]:
		var l: LevelLayout = RunSim.layout(3, 600.0)
		l.pads.append({"lane": 1 if ride else 0, "at": 60.0})
		l.hulls.append({"start": 57.0, "end": 220.0})
		var w: RunWorld = sim.build_world(l)
		w.player.god_mode = true
		var heavy: HeavyCyborg = _spawn(w, 170.0, 2)
		# A lambda's locals are its own copies: what it counts goes in a dictionary.
		var seen := {"aimed_up": 0, "rode": false}
		await _step_until(w, func() -> bool:
			if w.player.surface == Player.Surface.CEILING:
				seen["rode"] = true
				if is_instance_valid(heavy) and heavy.gun.is_attacking():
					seen["aimed_up"] = int(seen["aimed_up"]) + 1
			return w.player.distance > 175.0, 12.0)
		var tag: String = "(riding the ceiling)" if ride else "(on the floor below)"
		check(bool(seen["rode"]) == ride, "the runner %s the ceiling %s" % ["took" if ride else "stayed off", tag])
		if ride:
			check(int(seen["aimed_up"]) == 0 and _events_of(heavy.gun, &"shot").is_empty(),
				"it holds its fire at a runner on the ceiling above it (%d frames aiming) %s" % [int(seen["aimed_up"]), tag])
		else:
			check(not _events_of(heavy.gun, &"shot").is_empty(), "it fires at a runner on the floor under the ceiling " + tag)
		await sim.free_world(w)


## Task Q4: a teleport calls a stream under way off; the next one warns from the start.
func _test_teleport() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.god_mode = true
	var heavy: HeavyCyborg = _spawn(w, 110.0, 2)
	await _step_until(w, func() -> bool: return heavy.gun.state == CyborgGun.State.CHARGING, 8.0)
	await physics_frames(5)
	heavy.runner_teleported(w.player.distance, w.player.distance)
	await physics_frames(1)
	var cancels: Array[Dictionary] = _events_of(heavy.gun, &"cancel")
	check(heavy.gun.state == CyborgGun.State.READY and not cancels.is_empty() and cancels[-1]["why"] == &"teleport"
		and not (heavy.body as HeavyCyborgBody).aim_line_shown(),
		"a teleport calls its wind-up off, aim line and all")
	await sim.free_world(w)


# --- A cyborg's small attack ------------------------------------------------------------------------

## Its stream takes one of the cyborgs' places in the air: it winds up first, then two cyborgs are ready together;
## never more than GameRules.max_bursts_in_air (two) at once, its stream among them (one cyborg fires beside it, the
## other waits for a place), and every one fires in the end.
func _test_airspace() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	w.player.god_mode = true
	var guns: Array[CyborgGun] = [_spawn(w, 100.0, 0, {}, 3).gun, _cyborg(w, 110.0, 4, 4).gun, _cyborg(w, 110.0, 1, 5).gun]
	var claimed: Array[int] = [0]
	await _step_until(w, func() -> bool:
		if guns[0].is_attacking():
			claimed[0] = maxi(claimed[0], CyborgAirspace.of(w).bursts(w.level_time()))
		var all: Array[Dictionary] = _bursts(guns)
		return not _fired(all, 0).is_empty() and not _fired(all, 1).is_empty() and not _fired(all, 2).is_empty(), 10.0)
	var bursts: Array[Dictionary] = _bursts(guns)
	check(not _fired(bursts, 0).is_empty() and not _fired(bursts, 1).is_empty() and not _fired(bursts, 2).is_empty(),
		"it and both cyborgs fire")
	check(_most_at_once(bursts) <= w.rules.max_bursts_in_air,
		"never more than %d in the air at once, its stream counted (%d)" % [w.rules.max_bursts_in_air, _most_at_once(bursts)])
	check(claimed[0] >= 1 and claimed[0] <= w.rules.max_bursts_in_air,
		"its stream holds a place in the cyborgs' airspace while it's on (%d)" % claimed[0])
	await sim.free_world(w)


## GameRules.max_bursts_in_air at 1: it and a cyborg take turns (the cyborg, ready while the stream is on, waits).
func _test_limit_of_one() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	w.rules = w.rules.duplicate() as GameRules
	w.rules.max_bursts_in_air = 1
	w.player.god_mode = true
	var guns: Array[CyborgGun] = [_spawn(w, 100.0, 0, {}, 3).gun, _cyborg(w, 150.0, 4, 4).gun]
	await _step_until(w, func() -> bool:
		return _fired(_bursts(guns), 0).size() >= 1 and _fired(_bursts(guns), 1).size() >= 1, 10.0)
	var bursts: Array[Dictionary] = _bursts(guns)
	check(not _fired(bursts, 0).is_empty() and not _fired(bursts, 1).is_empty(), "both still fire")
	check(_most_at_once(bursts) == 1, "with the limit at one, they take turns")
	await sim.free_world(w)


## The crossfire rule (the cyborgs' airspace): three lanes, it and a cyborg further on, on the left, the runner in the
## middle dodging its stream one lane right as its aim locks. From the edge lane the only way out is the lane its stream
## comes down, so the cyborg's burst waits until its bolts arrive crossfire_gap after the stream; a runner who dodges
## what they see survives.
func _test_crossfire() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	var heavy: HeavyCyborg = _spawn(w, 110.0, 0, {}, 21)
	var guns: Array[CyborgGun] = [heavy.gun, _cyborg(w, 128.0, 0, 22).gun]
	var cause: Array[String] = [""]
	w.player.died.connect(func(c: String) -> void: cause[0] = c)
	var state := {"dodged": false, "locked": INF}
	var bot := func() -> void:
		if not bool(state["dodged"]) and guns[0].state == CyborgGun.State.FIRING:
			state["dodged"] = true
			state["locked"] = w.level_time()
			w.player.press(&"move_right")
		elif bool(state["dodged"]):
			_dodge(w)
	await _step_until(w, func() -> bool: return not w.player.alive or w.player.distance > 140.0, 10.0, bot)
	check(w.player.alive, "a runner who dodges what they see survives its stream and a cyborg's burst (%s)" % cause[0])
	var bursts: Array[Dictionary] = _bursts(guns)
	var a: Array[Dictionary] = _fired(bursts, 0)
	var b: Array[Dictionary] = _fired(bursts, 1)
	check(not a.is_empty() and not b.is_empty(), "both fire (%d, %d)" % [a.size(), b.size()])
	var offs: int = 0
	for x: Dictionary in bursts:
		offs += 1 if bool(x["cancelled"]) and x["why"] == &"crossfire" else 0
	check(offs == 0, "no wind-up or charge-up is called off at its lock")
	if not a.is_empty() and not b.is_empty():
		var crossed: bool = absf(float(a[0]["line"]) - float(b[0]["line"])) > tuning.lane_width * 0.5 \
			and float(a[0]["first"]) < float(b[0]["last"]) + ct.crossfire_gap and float(b[0]["first"]) < float(a[0]["last"]) + ct.crossfire_gap
		check(not crossed, "the cyborg's bolts never arrive in the edge lane while the stream comes down the lane beside it")
	await sim.free_world(w)


## Owner: it fires when the other small enemies fire and doesn't wait its turn as the bigger enemies' attacks do. It
## takes no part in the director's turns: it winds up and fires through another type's big attack, is never queued,
## and holds no big attack back.
func _test_no_turns() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.god_mode = true
	var dummy: Enemy = w.director.spawn({"type": "turn_dummy", "script": TURN_DUMMY, "at": 0.0, "lane": 0, "side": 0,
		"seed": 1, "params": {"first": 0.3, "interval": 0.4, "warning": 0.6, "attack": 0.6}})
	var heavy: HeavyCyborg = _spawn(w, 110.0, 2)
	var during: Array[int] = [0]
	var queued: Array[int] = [0]
	await _step_until(w, func() -> bool:
		if heavy.gun.is_attacking() and dummy.is_major_attack_active():
			during[0] += 1
		if w.director.is_waiting(heavy) or heavy.is_major_attack_active():
			queued[0] += 1
		return heavy.gun.state == CyborgGun.State.RELOADING, 8.0)
	var held: int = 0
	for h: Array in dummy.get(&"history"):
		held += 1 if h[0] == &"held" else 0
	check(not _events_of(heavy.gun, &"shot").is_empty() and during[0] > 0,
		"it winds up and fires while another type's big attack is on (%d frames)" % during[0])
	check(queued[0] == 0, "it is never queued for a turn, and reports no big attack")
	check(held == 0, "and no big attack is held back for its stream (%d holds)" % held)
	await sim.free_world(w)


# --- Its kills --------------------------------------------------------------------------------------

func _test_contact() -> void:
	var flat: LevelLayout = RunSim.layout(3, 400.0)
	# Stomp: drop onto its top from a jump's highest point.
	var w: RunWorld = sim.build_world(flat)
	var heavy: HeavyCyborg = _spawn(w, 45.0, 1, {"fires": false})
	await _step_until(w, func() -> bool: return heavy.track_distance() - w.player.distance <= STOMP_LEAD, 4.0)
	w.player.press(&"jump")
	var r: Dictionary = await sim.step_world(w, 1.5)
	check(r["alive"] and r["events"].has(&"stomp") and (not is_instance_valid(heavy) or not heavy.alive),
		"a stomp on its head kills it (%s)" % r["cause"])
	check(w.score.stomps == 1 and w.score.kills == 1 and w.score.score >= ht.score_value + App.rules.stomp_bonus,
		"the stomp is a kill, with its score and the stomp bonus (%d)" % w.score.score)
	await sim.free_world(w)
	# The dash kills it.
	w = sim.build_world(flat)
	heavy = _spawn(w, 45.0, 1, {"fires": false})
	await _step_until(w, func() -> bool: return heavy.track_distance() - w.player.distance <= 6.0, 4.0)
	w.player.start_dash(0.8, 0.0)
	r = await sim.step_world(w, 1.5)
	check(r["alive"] and w.score.kills == 1 and (not is_instance_valid(heavy) or not heavy.alive), "the dash kills it (%s)" % r["cause"])
	await sim.free_world(w)
	# The claws don't: a claw runner who runs into it is hit like anyone, and armor doesn't stop its body.
	for items: Dictionary in [{"claws": 1}, {"claws": 1, "armor": 1}, {"armor": 1}, {}]:
		w = sim.build_world(flat, _loadout(items))
		heavy = _spawn(w, 45.0, 1, {"fires": false})
		r = await sim.step_world(w, 3.0)
		check(not r["alive"] and r["cause"] == "heavy cyborg" and heavy.alive and w.score.kills == 0,
			"running into its body kills, with %s (%s)" % [items.keys() if not items.is_empty() else "nothing", r["cause"]])
		await sim.free_world(w)


## Owner: twice a cyborg's laser hits. Laser tier 1 at Relay Station's enemy scaling: 14 shots, a cyborg's 7.
func _test_weapons() -> void:
	var config := LevelConfig.new()
	config.enemy_scaling = campaign.configure(campaign.step(INTRODUCED_IN), 5).enemy_scaling
	var w: RunWorld = sim.build_world(RunSim.layout(3, 400.0), _loadout({"weapon": 1}), null, config)
	var heavy: HeavyCyborg = _spawn(w, 50.0, 0, {"fires": false})
	var cyborg: Cyborg = _cyborg(w, 52.0, 2, 3, {"panic": false, "fires": false})
	var weapon: WeaponPowerup = (w.powerups as PowerupController).weapon
	var needed: int = ceili(heavy.max_health / weapon.damage(heavy) - 0.001)
	var cyborg_needs: int = ceili(cyborg.max_health / weapon.damage(cyborg) - 0.001)
	check(needed == 2 * cyborg_needs, "laser tier 1 takes %d shots to kill it, twice a cyborg's %d" % [needed, cyborg_needs])
	check(heavy.targetable() and w.director.targets_ahead(Vector3(0.0, 0.8, 0.0), 80.0).has(heavy), "auto-fire targets it")
	for i: int in needed:
		w.projectiles.fire_player(heavy.aim_point() + Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -90.0), weapon.damage(heavy))
		await physics_frames(10)
		if i < needed - 1:
			check(heavy.alive, "still up after %d of %d shots" % [i + 1, needed])
	check((not is_instance_valid(heavy) or not heavy.alive) and w.score.kills == 1, "%d laser tier 1 shots kill it" % needed)
	await sim.free_world(w)


## Proposed: another enemy's charge (an Octodog's lunge, a Buzz Overdrive's) destroys it as it destroys a cyborg.
func _test_charges() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 400.0))
	var heavy: HeavyCyborg = _spawn(w, 50.0, 0, {"fires": false})
	check(heavy.charge_can_hurt(), "another enemy's charge can hurt it")
	heavy.take_damage(heavy.health, Enemy.CHARGE_DAMAGE_CAUSE)
	check(not is_instance_valid(heavy) or not heavy.alive, "and a charge's contact destroys it")
	await sim.free_world(w)


## Proposed: a falling gantryway destroys it as it destroys a cyborg. Dashed through, the pillar drops the walkway
## on it while the runner steps out (test_gantryways' take, with a Heavy Cyborg planted under it).
func _test_gantryway() -> void:
	for lanes: int in [3, 5]:
		var lane: int = 1
		var side: int = 1
		var layout := RunSim.layout(lanes, 600.0)
		var config := LevelConfig.new()
		config.lane_count = lanes
		var gt: GantrywayTuning = GantrywayTuning.load_default()
		var gen: LevelGenerator = LevelGenerator.for_layout(config, tuning, layout)
		var walkway: float = GantrywayRules.walkway_length(gen, gt)
		var calm: float = GantrywayRules.calm_length(gen, gt)
		var start: float = PILLAR - GantrywayRules.NEAR_OVERHANG
		layout.gantryways.append({"id": 0, "lane": lane, "start": start, "end": start + walkway, "pillar": PILLAR,
			"side": side, "calm": [PILLAR, PILLAR + calm], "seed": 7, "intro": true, "both": true})
		layout.doodads.append({"lane": lane, "start": PILLAR, "end": PILLAR + tuning.doodad_size(Gantryway.PILLAR_SIZE).z,
			"size": Gantryway.PILLAR_SIZE, "side": side, "seed": 7, LevelLayout.GANTRY_PILLAR: 0})
		var reach: Vector2 = GantrywayRules.plant_range(gen, PILLAR, start + walkway, gt)
		var hold := Vector2(PILLAR - gt.hold_before_seconds * gen.speed, PILLAR + calm)
		layout.enemies.append({"type": "heavy_cyborg", "at": reach.x + 1.0, "lane": lane, "side": 0, "seed": 3,
			"params": {"stand": true, "hold_fire": hold}})
		var w: RunWorld = sim.build_world(layout)
		w.player.setup(w.tuning, w.geo, lane)
		var crushed: Array[StringName] = []
		w.director.enemy_defeated.connect(func(e: Enemy, cause: StringName) -> void:
			if e is HeavyCyborg:
				crushed.append(cause))
		var pt := load("res://data/tuning/powerups.tres") as PowerupTuning
		var dash_at: float = PILLAR - 0.5 * pt.dash_duration * (w.tuning.run_speed + pt.dash_speed_bonus)
		var r: Dictionary = await sim.step_world(w, RUN_SECONDS, [[dash_at, &"dash"], [PILLAR + 2.0, &"move_right"]], [], false)
		check(r["alive"] and crushed == [Gantryway.CRUSH_CAUSE],
			"%d lanes: a falling gantryway crushes it while the runner steps out (%s, %s)" % [lanes, crushed, r["cause"]])
		await sim.free_world(w)


## It never boards an Enforcer Truck: only a passed `cyborg` does (GDD §9.13), and it's another type.
func _test_enforcer() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.god_mode = true
	var truck := w.director.spawn({"type": "enforcer_truck", "at": 1.0, "lane": 1, "side": 0, "seed": 7, "params": {}}) \
		as EnforcerTruck
	var heavy: HeavyCyborg = _spawn(w, 30.0, 1, {"fires": false})
	var cyborg: Cyborg = _cyborg(w, 31.0, 2, 4, {"panic": false, "fires": false})
	heavy.mode = Cyborg.Mode.PASSED
	cyborg.mode = Cyborg.Mode.PASSED
	truck.call(&"_record_passed_cyborgs")
	var passed: Array = truck.get(&"_passed")
	var boards: Array = []
	for rec: Dictionary in passed:
		boards.append((rec["cyborg"] as WeakRef).get_ref())
	check(boards.has(cyborg) and not boards.has(heavy), "a passed cyborg may board an Enforcer Truck, never a Heavy Cyborg")
	await sim.free_world(w)


# --- The generator ----------------------------------------------------------------------------------

## Heavy Cyborgs (HeavyCyborgRules: its pattern's cyborgs and the top-up's) on the prototype level with cyborgs over lane
## counts, difficulties and seeds: the same on a second build; each stands on the floor in a lane, with none of a
## cyborg's params, where its stream gets to fire (_check_places); the level keeps a plain cyborg; most builds have some
## (the prototype level has no guarantee, LevelConfig.guarantee_features), in every lane across them; levels without the
## feature have none.
func _test_generation() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var heavies: int = 0
	var builds: int = 0
	var with_some: int = 0
	var lanes_seen: Dictionary = {}
	for lanes: int in [3, 5, 6]:
		for difficulty: float in [0.3, 0.6, 0.9]:
			for level_seed: int in range(1, 9):
				var config: LevelConfig = base.duplicate() as LevelConfig
				config.lane_count = lanes
				config.difficulty = difficulty
				config.level_seed = level_seed
				config.features = PackedStringArray(["ramps", "ceilings", "pulsing", "speed_pads", "cyborg", "heavy_cyborg"])
				var patterns: Array = LevelGenerator.load_for(config)
				var gen := LevelGenerator.new()
				var a: LevelLayout = gen.generate(config, tuning, patterns)
				var tag: String = "lanes=%d diff=%.1f seed=%d" % [lanes, difficulty, level_seed]
				check(gen.warnings.is_empty(), "it generates without warnings %s %s" % [tag, gen.warnings])
				var b: LevelLayout = LevelGenerator.new().generate(config, tuning, patterns)
				check(JSON.stringify(a.enemies) == JSON.stringify(b.enemies), "the same seed, the same Heavy Cyborgs " + tag)
				var at: Array[float] = _check_places(gen, tag)
				check(not LevelGenerator.feature_positions(a, "cyborg").is_empty(), "the level keeps a cyborg " + tag)
				for e: Dictionary in a.enemies:
					if String(e["type"]) == "heavy_cyborg":
						lanes_seen[int(e["lane"])] = true
						check(int(e["lane"]) >= 0 and int(e["lane"]) < lanes and int(e.get("side", 0)) == 0
							and (e.get("params", {}) as Dictionary).is_empty(), "on the floor, in a lane of the track, no cyborg's params " + tag)
				heavies += at.size()
				builds += 1
				with_some += 1 if not at.is_empty() else 0
				LayoutChecks.check_ceilings(self, a, config, tag)
	check(heavies > 60 and with_some * 10 >= builds * 9, "plenty of them (%d), in most builds (%d of %d)" % [heavies,
		with_some, builds])
	check(lanes_seen.size() >= 5, "in every lane across the builds (%s)" % [lanes_seen.keys()])
	var plain: LevelConfig = base.duplicate() as LevelConfig
	plain.features = PackedStringArray(["ramps", "ceilings", "pulsing", "cyborg"])
	var none: LevelLayout = LevelGenerator.new().generate(plain, tuning, LevelGenerator.load_for(plain))
	check(LevelGenerator.feature_positions(none, "heavy_cyborg").is_empty(), "levels without the feature have none")
	# Quick play's `--features=heavy_cyborg` alone: its pattern's Heavy Cyborgs, and none of its cyborgs left plain.
	var alone: LevelConfig = base.duplicate() as LevelConfig
	alone.features = PackedStringArray(["ramps", "ceilings", "pulsing", "heavy_cyborg"])
	var solo := LevelGenerator.new()
	solo.generate(alone, tuning, LevelGenerator.load_for(alone))
	var solo_at: Array[float] = _check_places(solo, "without cyborgs of its own")
	check(not solo_at.is_empty() and LevelGenerator.feature_positions(solo.layout, "cyborg").is_empty(),
		"a level without cyborgs of its own has its pattern's Heavy Cyborgs (%d) and no plain cyborg" % solo_at.size())


## Checks where every Heavy Cyborg of `gen`'s build stands (HeavyCyborgRules.fits) and returns their spots: none before
## the feature's start; each clear of every obstacle by the cyborgs' margin; its stream's zone clear of every gap, live
## fence and doodad in every lane, so it gets to fire (CyborgGun.floor_clear, what its gun's path_clear asks around each
## round's arrival; the review's B1); its reach off every dash wall's footprint, wider gap's zone, wall-run gap's clear
## stretch and every-lane calm stretch (HeavyCyborgRules.taken_spans); no cyborg or window cyborg within
## rival_clear_seconds of run of it (HeavyCyborgRules.rivals_clear: their bursts could hold its stream's start); at
## least spacing_seconds of run after the one before.
func _check_places(gen: LevelGenerator, tag: String) -> Array[float]:
	var lay: LevelLayout = gen.layout
	var spans: Array[Vector2] = CyborgRules.obstacle_spans(lay, gen.tuning, gen.zones)
	var margin: float = CyborgRules.obstacle_margin_at(ht, gen.pace)
	var taken: Array[Vector2] = HeavyRules.taken_spans(gen)
	var at: Array[float] = LevelGenerator.feature_positions(lay, "heavy_cyborg")
	for e: Dictionary in lay.enemies:
		if String(e["type"]) != "heavy_cyborg":
			continue
		var a: float = float(e["at"])
		var zone: Vector2 = HeavyRules.stream_zone(gen, a, ht)
		var reach: Vector2 = HeavyRules.reach_of(gen, e, ht)
		var off: bool = true
		for s: Vector2 in taken:
			off = off and (s.x > reach.y or s.y < reach.x)
		check(a >= gen.feature_start("heavy_cyborg") - 0.01, "none before its start (%.0f m) %s" % [a, tag])
		check(not CyborgRules.near_any(spans, a, margin - 0.01), "clear of every obstacle by the cyborgs' margin at %.0f m %s"
			% [a, tag])
		check(CyborgGun.floor_clear(lay, zone.x, zone.y), "its stream's zone (%.0f-%.0f m) holds no gap, live fence or doodad %s"
			% [zone.x, zone.y, tag])
		check(off, "its reach (%.0f-%.0f m) keeps off every dash wall, wider gap, wall-run gap and calm stretch %s"
			% [reach.x, reach.y, tag])
		var rivals: Array[float] = []
		for o: Dictionary in lay.enemies:
			if HeavyRules.RIVALS.has(String(o["type"])) and absf(float(o["at"]) - a) <= ht.rival_clear_seconds * gen.speed:
				rivals.append(float(o["at"]))
		check(rivals.is_empty(), "no cyborg or window cyborg within %.1f s of run of it (%.0f m: %s) %s"
			% [ht.rival_clear_seconds, a, rivals, tag])
	for i: int in range(1, at.size()):
		check(at[i] - at[i - 1] >= ht.spacing_seconds * gen.speed - 0.01,
			"at least %.1f s of run after the one before (%.0f m) %s" % [ht.spacing_seconds, at[i], tag])
	return at


## GDD §9.16 (proposed): introduced in Relay Station after its teleporters, one new thing at a time; then Specimen Vault;
## and all three of the Golden Zone's levels with no introduction of their own (owner). None in Frost Foundry. Every
## build at 3, 5 and 6 lanes on the levels' own seeds, as the campaign configures it, has Heavy Cyborgs where their
## streams get to fire (_check_places), with no warning: two at least at the campaign's lane count (GameRules.lanes_pc
## and lanes_mobile; Relay Station's from its start for them, its introduction) and one at least at the others (the
## review's target, DESIGN-TBD, docs/questions/s1.md; LevelConfig.guarantee_features, each level's weight for their
## pattern, `feature_weights`). The counts are printed; test_heavy_cyborg_play plays these builds through.
func _test_campaign() -> void:
	var intro: LevelConfig = campaign.step(INTRODUCED_IN).level
	check(intro.has_feature("heavy_cyborg") and intro.feature_start("heavy_cyborg") > intro.feature_start("teleporter"),
		"Relay Station brings it in after its teleporters (%.2f, the teleporters %.2f)" % [intro.feature_start("heavy_cyborg"),
			intro.feature_start("teleporter")])
	check(not campaign.step(BEFORE).level.has_feature("heavy_cyborg"), "none in Frost Foundry")
	for id: String in LEVELS:
		var level: LevelConfig = campaign.step(id).level
		check(level.has_feature("heavy_cyborg") and level.feature_starts.has("heavy_cyborg") == (id == INTRODUCED_IN),
			"%s has it%s" % [id, ", from a start of its own" if id == INTRODUCED_IN else ", with no introduction of its own"])
		var order: PackedStringArray = level.features
		check(order.find("heavy_cyborg") == order.find("teleporter") + 1, "%s lists it right after the teleporters" % id)
		check(level.guarantee_features, "%s guarantees its features, the Heavy Cyborg's among them" % id)
	var golden_ages: Dictionary[String, int] = campaign.configure(campaign.step("golden/1"), 3).feature_ages
	check(int(golden_ages.get("heavy_cyborg", -1)) == 1, "Golden 1's Heavy Cyborgs are a level old, the Ice Lab's (%s)"
		% golden_ages.get("heavy_cyborg", -1))
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	var counts: PackedStringArray = []
	for id: String in [BEFORE] + LEVELS:
		for lanes: int in [3, 5, 6]:
			var config: LevelConfig = campaign.configure(campaign.step(id), lanes)
			var gen: LevelGenerator = LayoutCache.generator(config, tuning, LevelGenerator.load_for(config))
			var tag: String = "%s lanes=%d" % [id, lanes]
			var at: Array[float] = _check_places(gen, tag)
			if id == BEFORE:
				check(at.is_empty(), "no Heavy Cyborg in %s" % tag)
				continue
			counts.append("%s: %d" % [tag, at.size()])
			var least: int = 2 if lanes == rules.lanes_pc or lanes == rules.lanes_mobile else 1
			check(at.size() >= least, "%s brings Heavy Cyborgs in where their streams get to fire (%d, %d at the least)"
				% [tag, at.size(), least])
			check(gen.warnings.is_empty(), "%s builds without warnings %s" % [tag, gen.warnings])
	print("  Heavy Cyborgs on the campaign levels' own seeds: %s" % ", ".join(counts))


## Full levels in god mode (grapples pull the runner out of gaps) over lane counts and seeds: every round follows a
## wind-up, comes from ahead with enough warning (measured from the barrels' tips), never arrives near a fence or gap; at
## most max_bursts_in_air bursts of the cyborg-type guns at once, its streams among them; no Heavy Cyborg ever stands
## near an obstacle; and every one the runner passes fires a stream of min_stream_rounds rounds at the least (each
## stands where its stream's zone is clear: HeavyCyborgRules).
func _test_fair_play() -> void:
	var base: LevelConfig = load(LEVEL_PATH) as LevelConfig
	var rounds: int = 0
	var passed: int = 0
	var fired: int = 0
	for lanes: int in [3, 5, 6]:
		for level_seed: int in [2, 5]:
			var config: LevelConfig = base.duplicate() as LevelConfig
			config.lane_count = lanes
			config.difficulty = 0.7
			config.level_seed = level_seed
			config.features = PackedStringArray(["ceilings", "pulsing", "cyborg", "heavy_cyborg"])
			var layout: LevelLayout = LevelGenerator.new().generate(config, tuning, LevelGenerator.load_for(config))
			var tag: String = "lanes=%d seed=%d" % [lanes, level_seed]
			var w: RunWorld = sim.build_world(layout, _loadout({"grapple": 999}), null, config)
			w.player.god_mode = true
			var guns: Array[CyborgGun] = []
			var heavy_guns: Array[CyborgGun] = []
			var homes: Array[float] = []
			w.director.enemy_spawned.connect(func(e: Enemy) -> void:
				if e is Cyborg:
					guns.append((e as Cyborg).gun)
					if e is HeavyCyborg:
						heavy_guns.append((e as Cyborg).gun)
						homes.append((e as HeavyCyborg).home))
			var spans: Array[Vector2] = CyborgRules.obstacle_spans(layout, tuning, CeilingZones.make(config, tuning))
			var too_close: int = 0
			await tree.physics_frame
			w.player.running = true
			for i: int in 40 * 60:
				await tree.physics_frame
				if i % 5 != 0:
					continue
				for e: Enemy in w.director.active:
					var h := e as HeavyCyborg
					if h != null and h.alive and h.mode != Cyborg.Mode.PASSED \
							and CyborgRules.near_any(spans, h.track_distance(), ht.obstacle_margin - 0.05):
						too_close += 1
			check(too_close == 0, "no Heavy Cyborg ever stands near an obstacle " + tag)
			for k: int in heavy_guns.size():
				var gun: CyborgGun = heavy_guns[k]
				if homes[k] < w.player.distance:
					passed += 1
					fired += 1 if _events_of(gun, &"shot").size() >= ht.min_stream_rounds else 0
				var charge_t: float = -1.0
				var first: bool = false
				for ev: Dictionary in gun.events:
					match ev["event"]:
						&"charge":
							charge_t = ev["t"]
							first = true
						&"cancel":
							charge_t = -1.0
						&"shot":
							rounds += 1
							var t: float = ev["t"]
							check(charge_t >= 0.0 and t - charge_t >= ht.charge_time - 0.02, "every round follows a wind-up " + tag)
							check(float(ev["shooter_d"]) > float(ev["player_d"]), "rounds only come from ahead " + tag)
							var warning: float = float(ev["arrive"]) - t
							check(warning >= ht.min_warning_time * (1.0 if first else ht.later_round_warning_share) - 0.005,
								"every round gives enough warning (%.2f s) %s" % [warning, tag])
							first = false
							var impact: float = ev["impact"]
							check(_clear(layout, impact - ht.clear_before_impact + 1.5, impact + ht.clear_after_impact - 1.5),
								"no round arrives near a fence or gap (%.1f) %s" % [impact, tag])
			var most: int = _most_at_once(_bursts(guns))
			check(most <= w.rules.max_bursts_in_air, "at most %d bursts in the air at a time, its streams counted (%d) %s"
				% [w.rules.max_bursts_in_air, most, tag])
			await sim.free_world(w)
	check(passed >= 4 and fired == passed and rounds > 0,
		"every Heavy Cyborg the runner passes fires a stream (%d of %d, %d rounds)" % [fired, passed, rounds])
