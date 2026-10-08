extends TestSuite
## The cyborgs' airspace (GDD §9.2, owner, October 8, 2026: up to two bursts of the cyborg-type guns,
## cyborgs, window cyborgs and Barnacle Turrets, in the air at once; CyborgAirspace, CyborgGun):
## - its claims: at most GameRules.max_bursts_in_air at once; a release ends only that shooter's claim;
##   a shooter that has left play (defeated, retired or freed) holds none; a boss's claim on the whole
##   airspace (the Floating Head's eye lasers) keeps every burst out, and the boss sees every burst's;
## - on real physics: two cyborgs ready together fire together and a third waits for one of them (at
##   once if one of the two is killed); with the limit at 1 they take turns, as the build had it;
## - the crossfire rule (DESIGN-TBD, docs/questions/h4.md): a burst that would leave the runner no way out
##   waits before its charge-up, never after it. On three lanes a second burst begun well after the first
##   waits while the runner in the middle lane could dodge the first into an edge lane; on five lanes it
##   fires at once, the lane beyond being free; either way a runner who dodges the bolts they see
##   survives. A hover truck alongside holds its lane; bolts at a wall runner aren't aimed at the lane
##   below, so two guns charging at a wall runner both fire, while a burst at a wall runner waits while
##   another's bolts come down the lane below; a ceiling rider dodges only within its ceiling and never
##   into a turret; a panic cyborg's wild fire waits until its bolts arrive well apart from another
##   burst's;
## - two Barnacle Turrets on one ceiling fire together (GDD §9.8);
## - the same scenario plays out the same way twice.

const CYBORG_TUNING_PATH: String = "res://data/enemies/cyborg.tres"
const TURRET_TUNING_PATH: String = "res://data/enemies/barnacle_turret.tres"
## A bolt that would reach the runner's spot within this long, closer than BOLT_REACH sideways, is dodged
## (as tests/helpers/floating_head_bot.gd does it: a player watching the bolts).
const BOLT_REACT: float = 0.7
const BOLT_REACH: float = 0.75

var sim: RunSim
var ct: CyborgTuning
var bt: BarnacleTurretTuning


func run() -> void:
	sim = RunSim.new(tree, tuning)
	ct = load(CYBORG_TUNING_PATH) as CyborgTuning
	bt = load(TURRET_TUNING_PATH) as BarnacleTurretTuning
	check(ct != null and bt != null, "the cyborg's and the turret's tunings load")
	if ct == null or bt == null:
		return
	_test_rules()
	_test_claims()
	_test_whole_airspace()
	_test_near()
	_test_aims_at()
	await _test_two_together()
	await _test_third_waits()
	await _test_killed_mid_charge()
	await _test_limit_of_one()
	await _test_crossfire(3)
	await _test_crossfire(5)
	await _test_truck()
	await _test_wall_runner()
	await _test_both_at_wall_runner()
	await _test_wild()
	await _test_moves()
	await _test_turrets_together()
	await _test_same_every_time()


# --- Helpers ----------------------------------------------------------------------------------------

func _cyborg(w: RunWorld, at: float, lane: int, seed_value: int) -> Cyborg:
	return w.director.spawn({"type": "cyborg", "at": at, "lane": lane, "side": 0, "seed": seed_value,
		"params": {"panic": false}}) as Cyborg


## Steps the world a frame at a time (the player runs) until `done` returns true or `seconds` pass.
## `each` runs before every frame (a bot's input).
func _step(w: RunWorld, seconds: float, done: Callable, each: Callable = Callable()) -> bool:
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


## Every burst of `guns`, in each gun's order: {"gun" (its index), "start" (its charge-up), "end" (its
## last bolt or its cancel), "cancelled", "why" (a cancel's, CyborgGun._cancel), "shots", "line" (the
## world x it was aimed along), "wild", "first" and "last" (when its bolts arrived, level times)}.
static func _bursts(guns: Array[CyborgGun]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in guns.size():
		var cur: Dictionary = {}
		for ev: Dictionary in guns[i].events:
			match ev["event"]:
				&"charge":
					cur = {"gun": i, "start": float(ev["t"]), "end": float(ev["t"]), "cancelled": false, "why": &"",
						"shots": 0, "line": 0.0, "wild": false, "first": INF, "last": -INF}
					out.append(cur)
				&"cancel":
					cur["end"] = float(ev["t"])
					cur["cancelled"] = true
					cur["why"] = ev.get("why", &"")
				&"shot":
					cur["end"] = float(ev["t"])
					cur["shots"] = int(cur["shots"]) + 1
					cur["line"] = float(ev["line"])
					cur["wild"] = bool(ev["wild"])
					cur["first"] = minf(float(cur["first"]), float(ev["arrive"]))
					cur["last"] = maxf(float(cur["last"]), float(ev["arrive"]))
	return out


## The most bursts in the air at once (one that ends as another starts doesn't overlap it).
static func _most_at_once(bursts: Array[Dictionary]) -> int:
	var most: int = 0
	for b: Dictionary in bursts:
		var on: int = 0
		for o: Dictionary in bursts:
			if float(o["start"]) <= float(b["start"]) and (is_same(o, b) or float(o["end"]) > float(b["start"]) + 0.001):
				on += 1
		most = maxi(most, on)
	return most


## The bursts that fired, of gun `gun`.
static func _fired(bursts: Array[Dictionary], gun: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in bursts:
		if int(b["gun"]) == gun and int(b["shots"]) > 0:
			out.append(b)
	return out


## The charge-ups the crossfire rule's last check called off as their aim would lock.
static func _crossfire_offs(bursts: Array[Dictionary]) -> int:
	var n: int = 0
	for b: Dictionary in bursts:
		if bool(b["cancelled"]) and b["why"] == &"crossfire":
			n += 1
	return n


## Whether two bursts' bolts arrived within `gap` seconds of each other.
static func _arrive_together(a: Dictionary, b: Dictionary, gap: float) -> bool:
	return float(a["first"]) < float(b["last"]) + gap and float(b["first"]) < float(a["last"]) + gap


## A runner watching the bolts: one that would reach its spot within BOLT_REACT seconds, closer than
## BOLT_REACH sideways, sends it to the nearest lane (one over, else two) no bolt is heading for and no
## cyborg stands in just ahead.
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


## True if a hostile bolt will cross the runner's spot in `lane` within BOLT_REACT seconds.
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


## True if a living cyborg stands in `lane` within 30 m ahead of the runner.
static func _cyborg_ahead(w: RunWorld, lane: int) -> bool:
	for e: Enemy in w.director.active:
		var c := e as Cyborg
		if c != null and is_instance_valid(c) and c.alive and c.lane == lane \
				and c.track_distance() > w.player.distance and c.track_distance() < w.player.distance + 30.0:
			return true
	return false


## A place for CyborgGun.aims_at and way_out ({"surface", "lane", "side", "x"}).
static func _place(surface: int, x: float, side: int = 0) -> Dictionary:
	return {"surface": surface, "lane": 0, "side": side, "x": x}


## The lanes of `places` (CyborgGun._moves), a wall as -1 or the lane count (left, right).
static func _lanes_of(places: Array[Dictionary], n: int) -> Array:
	var out: Array = []
	for place: Dictionary in places:
		if int(place["surface"]) == Player.Surface.WALL:
			out.append(-1 if int(place["side"]) < 0 else n)
		else:
			out.append(int(place["lane"]))
	return out


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if a[i] != b[i]:
			return false
	return true


# --- The airspace's claims --------------------------------------------------------------------------

## The limit is data, in the F6 panel, two by default (GDD §9.2); the crossfire rule's gap too.
func _test_rules() -> void:
	var rules := load("res://data/tuning/game_rules.tres") as GameRules
	check(rules != null and rules.max_bursts_in_air == 2, "two bursts in the air at once by default (GDD §9.2)")
	check(GameRules.new().max_bursts_in_air == CyborgAirspace.DEFAULT_MOST,
		"the airspace's fallback is GameRules' default")
	var found: bool = false
	for prop: Dictionary in GameRules.new().get_property_list():
		if prop["name"] == "max_bursts_in_air":
			found = prop["hint"] == PROPERTY_HINT_RANGE
	check(found, "max_bursts_in_air has a range hint, so it shows in the F6 panel")
	for t: CyborgGunTuning in [ct, bt, load("res://data/enemies/window_cyborg.tres") as CyborgGunTuning]:
		check(t.crossfire_gap > tuning.lane_switch_time,
			"the crossfire gap leaves time to switch lanes between two bursts (%.2f s)" % t.crossfire_gap)
		check(t.reaction_time > 0.0 and t.reaction_time < t.charge_time,
			"a runner reacts within a charge-up (%.2f s)" % t.reaction_time)
	# CLAUDE.md principle 7: the tunables are listed in their data files.
	check(FileAccess.get_file_as_string("res://data/tuning/game_rules.tres").contains("max_bursts_in_air = 2"),
		"game_rules.tres lists max_bursts_in_air")
	for path: String in ["res://data/enemies/cyborg.tres", "res://data/enemies/window_cyborg.tres",
			"res://data/enemies/barnacle_turret.tres"]:
		var text: String = FileAccess.get_file_as_string(path)
		check(text.contains("crossfire_gap = ") and text.contains("reaction_time = "),
			"%s lists crossfire_gap and reaction_time" % path.get_file())


## Claims: at most `most` at once; a release ends only that shooter's claim; a claim ends on time; a
## shooter that's defeated, retired or freed holds none.
func _test_claims() -> void:
	var world := Node.new()
	var air: CyborgAirspace = CyborgAirspace.of(world)
	check(CyborgAirspace.of(world) == air, "a world has one airspace")
	var other := Node.new()
	check(CyborgAirspace.of(other) != air, "every world its own")
	other.free()
	var a := Node.new()
	var b := Node.new()
	var c := Node.new()
	check(air.may_start(0.0, 2) and air.bursts(0.0) == 0, "an empty airspace lets a burst start")
	air.claim(a, 2.0, 1.5, 1.9, false, 0.0)
	check(air.may_start(0.1, 2) and air.bursts(0.1) == 1, "one burst in the air: a second may start")
	air.claim(b, 3.0, 2.5, 2.9, false, 0.1)
	check(not air.may_start(0.2, 2) and air.bursts(0.2) == 2, "two in the air: a third waits")
	check(air.may_start(0.2, 3), "with a limit of three, a third may start")
	check(air.may_start(2.0, 2) and air.bursts(2.0) == 1, "a claim ends on time, and the third may start")
	air.claim(c, 4.0, 3.5, 3.9, false, 2.0)
	air.release(b, 2.1)
	check(air.bursts(2.1) == 1 and air.may_start(2.1, 2), "a release ends that shooter's claim")
	check(air.claimed_until(2.1) == 4.0, "and no other: the third's claim stays")
	air.release(b, 2.2)
	check(air.bursts(2.2) == 1, "releasing again changes nothing")
	# A defeated, retired or freed shooter holds no claim.
	var shooter := Enemy.new()
	air.claim(shooter, 5.0, 4.5, 4.9, false, 2.3)
	check(air.bursts(2.3) == 2, "a living shooter's claim counts")
	shooter.alive = false
	check(air.bursts(2.3) == 1 and air.may_start(2.3, 2), "a defeated or retired shooter's claim doesn't")
	shooter.free()
	c.free()
	check(air.bursts(2.4) == 0 and air.may_start(2.4, 1), "nor does a freed shooter's")
	check(air.claimed_until(2.4) < 0.0, "nothing holds the airspace")
	for n: Node in [a, b, world]:
		n.free()


## A boss's claim on the whole airspace (the Floating Head's eye lasers): no burst starts while it's on,
## a later claim never shortens it, its release ends only its own, and a boss that's gone holds none.
func _test_whole_airspace() -> void:
	var world := Node.new()
	var air: CyborgAirspace = CyborgAirspace.of(world)
	var boss := Node.new()
	var shooter := Node.new()
	air.claim(shooter, 1.0, 0.8, 1.2, false, 0.0)
	check(air.claimed_until(0.5) == 1.0, "the boss sees a burst's claim (its lasers wait for it)")
	air.claim_whole(boss, 3.0, 1.0)
	check(not air.may_start(1.5, 2) and air.bursts(1.5) == 0, "no burst starts while the boss holds the airspace")
	air.claim_whole(boss, 2.0, 1.5)
	check(air.claimed_until(1.5) == 3.0, "a later, shorter claim doesn't shorten it")
	check(air.may_start(3.0, 2), "a burst may start once its claim is over")
	air.claim_whole(boss, 5.0, 3.0)
	air.claim(shooter, 6.0, 5.5, 5.9, false, 3.0)
	air.release(boss, 3.5)
	check(air.may_start(3.5, 2) and air.claimed_until(3.5) == 6.0, "its release ends only its own claim")
	air.claim_whole(boss, 8.0, 3.6)
	boss.free()
	check(air.may_start(3.7, 2), "a boss that's gone holds nothing")
	shooter.free()
	world.free()


## The crossfire rule's bursts: those whose bolts arrive within the gap of a window, the asking one's
## own left out; bursts still charging only when asked for; one whose bolts flew still counts after its
## release and its shooter's death, until a while after they've arrived.
func _test_near() -> void:
	var world := Node.new()
	var air: CyborgAirspace = CyborgAirspace.of(world)
	var a := Node.new()
	var b := Node.new()
	var own: Dictionary = air.claim(a, 2.0, 1.0, 1.4, false, 0.0)
	var charging: Dictionary = air.claim(b, 2.5, 1.6, 2.0, true, 0.1)
	check(air.near(own, 1.0, 1.4, 0.5, false, 0.2).size() == 1, "a burst still charging counts as predicted")
	check(air.near(own, 1.0, 1.4, 0.5, true, 0.2).is_empty(), "but not once only aimed bursts are asked for")
	check(air.near(own, 1.0, 1.4, 0.1, false, 0.2).is_empty(), "nor beyond the gap")
	check(float(charging["t0"]) == 0.1, "a claim keeps when its charge-up began")
	air.aim(charging, 2.4, Player.Surface.WALL, 1, 1.7, 2.1)
	var near: Array[Dictionary] = air.near({}, 1.0, 1.4, 0.5, false, 0.3)
	check(near.size() == 2 and not bool(near[0]["aimed"]) and bool(near[1]["aimed"])
		and float(near[1]["line"]) == 2.4 and int(near[1]["surface"]) == Player.Surface.WALL
		and int(near[1]["side"]) == 1 and bool(near[1]["wild"]),
		"an aimed burst brings its line, the surface (and wall) it was aimed at, and its wildness")
	check(air.near({}, 1.0, 1.4, 0.5, true, 0.3).size() == 1, "only it, when only aimed bursts are asked for")
	air.arrives(charging, 2.3)
	check(float(charging["last"]) == 2.3, "a bolt's actual arrival widens its burst's")
	air.release(b, 0.4)
	b.free()
	check(air.near(own, 1.0, 1.4, 0.5, true, 0.5).size() == 1,
		"a burst whose bolts are on their way counts after its release and its shooter's end")
	air.release(a, 0.5)
	check(air.near({}, 1.0, 1.4, 0.5, false, 0.6).size() == 1, "a burst that never fired goes with its release")
	air.may_start(2.3 + CyborgAirspace.KEEP_AFTER + 0.1, 2)
	check(air.near({}, 2.0, 2.4, 0.5, false, 4.5).is_empty(), "and one whose bolts arrived a while ago goes too")
	a.free()
	world.free()


## A burst is aimed at the places on its own surface within half a lane of its line, or at its wall; a
## place one move away that none is aimed at is a way out.
func _test_aims_at() -> void:
	var geo := TrackGeometry.new(3, tuning)
	var floor_line := func(lane: int) -> Dictionary: return _place(Player.Surface.FLOOR, geo.lane_x(lane))
	var floor_at := func(lane: int) -> Dictionary: return _place(Player.Surface.FLOOR, geo.lane_x(lane))
	check(CyborgGun.aims_at(floor_line.call(1), floor_at.call(1), geo), "a burst is aimed at the lane it was locked on")
	check(not CyborgGun.aims_at(floor_line.call(1), floor_at.call(0), geo), "and not at the lane beside it")
	var between: Dictionary = _place(Player.Surface.FLOOR, (geo.lane_x(0) + geo.lane_x(1)) * 0.5)
	check(CyborgGun.aims_at(between, floor_at.call(0), geo) and CyborgGun.aims_at(between, floor_at.call(1), geo),
		"a line between two lanes counts against both")
	# Bolts at a wall runner (aimed along the middle of its body, out from the wall) pass wide of the lane
	# below: further from its middle than a bolt can touch a runner there.
	var wall_x: float = geo.wall_x() - tuning.hurtbox_size.y * 0.5
	var wide: float = wall_x - ct.aim_error - ct.shot_jitter - geo.lane_x(2)
	var radius: float = (ProjectilePool.LOOKS[CyborgGun.LOOK]["size"] as Vector3).x * 0.5
	check(wide > tuning.hurtbox_size.x * 0.5 + radius,
		"bolts at a wall runner pass %.2f m wide of the lane below; a bolt touches a runner within %.2f m" % [wide,
		tuning.hurtbox_size.x * 0.5 + radius])
	var at_wall: Dictionary = _place(Player.Surface.WALL, wall_x, 1)
	check(not CyborgGun.aims_at(at_wall, floor_at.call(2), geo), "so a burst at a wall runner isn't aimed at the lane below")
	check(not CyborgGun.aims_at(floor_line.call(2), _place(Player.Surface.WALL, wall_x, 1), geo),
		"nor a burst at the outer lane at the runner on the wall above it")
	check(CyborgGun.aims_at(at_wall, _place(Player.Surface.WALL, wall_x, 1), geo)
		and not CyborgGun.aims_at(at_wall, _place(Player.Surface.WALL, -wall_x, -1), geo),
		"a burst at a wall runner is aimed at that wall, not the other")
	check(not CyborgGun.aims_at(_place(Player.Surface.CEILING, geo.lane_x(1)), floor_at.call(1), geo),
		"a ceiling rider's bolts fly far above the floor")
	var one: Array[Dictionary] = [floor_at.call(1)]
	var both: Array[Dictionary] = [floor_at.call(0), floor_at.call(2)]
	var none: Array[Dictionary] = []
	var at_one: Array[Dictionary] = [floor_line.call(1)]
	var at_wall_only: Array[Dictionary] = [at_wall]
	check(not CyborgGun.way_out(one, at_one, geo), "the edge lane of three: its only neighbour aimed at, no way out")
	check(CyborgGun.way_out(both, at_one, geo), "aimed at the middle lane: either side is a way out")
	check(CyborgGun.way_out(one, at_wall_only, geo), "a burst at the wall runner leaves the lane below free")
	check(CyborgGun.way_out(one, none, geo), "no other burst: any place will do")
	check(not CyborgGun.way_out(none, none, geo), "no place: no way out")


# --- On real physics --------------------------------------------------------------------------------

## GDD §9.2: two cyborgs that see the runner together charge up together and both fire, their bursts in
## the air at once.
func _test_two_together() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	w.player.god_mode = true
	var guns: Array[CyborgGun] = [_cyborg(w, 110.0, 0, 3).gun, _cyborg(w, 110.0, 4, 4).gun]
	await _step(w, 8.0, func() -> bool: return _fired(_bursts(guns), 0).size() >= 1 and _fired(_bursts(guns), 1).size() >= 1)
	var bursts: Array[Dictionary] = _bursts(guns)
	var a: Array[Dictionary] = _fired(bursts, 0)
	var b: Array[Dictionary] = _fired(bursts, 1)
	check(not a.is_empty() and not b.is_empty(), "both cyborgs fire (%d, %d bursts)" % [a.size(), b.size()])
	if not a.is_empty() and not b.is_empty():
		check(absf(float(a[0]["start"]) - float(b[0]["start"])) < 0.02,
			"they charge up together (%.2f s and %.2f s)" % [float(a[0]["start"]), float(b[0]["start"])])
		check(_most_at_once(bursts) == 2, "two bursts in the air at once")
		check(absf(float(a[0]["line"]) - float(b[0]["line"])) < tuning.lane_width * 0.5,
			"both aimed along the runner's lane")
	await sim.free_world(w)


## Three cyborgs ready together: two fire, and the third waits until one of their bursts is over
## (burst_gap after its last bolt), then fires; never more than two in the air.
func _test_third_waits() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	w.player.god_mode = true
	var guns: Array[CyborgGun] = [_cyborg(w, 110.0, 0, 3).gun, _cyborg(w, 110.0, 4, 4).gun, _cyborg(w, 110.0, 1, 5).gun]
	await _step(w, 8.0, func() -> bool:
		var all: Array[Dictionary] = _bursts(guns)
		return not _fired(all, 0).is_empty() and not _fired(all, 1).is_empty() and not _fired(all, 2).is_empty())
	var bursts: Array[Dictionary] = _bursts(guns)
	check(_most_at_once(bursts) == 2, "never more than two bursts in the air (%d)" % _most_at_once(bursts))
	var firsts: Array[float] = []
	for i: int in 3:
		var mine: Array[Dictionary] = _fired(bursts, i)
		firsts.append(float(mine[0]["start"]) if not mine.is_empty() else INF)
	var order: Array[float] = firsts.duplicate()
	order.sort()
	check(order[2] < INF, "all three fire in the end")
	check(order[1] - order[0] < 0.02 and order[2] - order[1] > ct.charge_time,
		"two charge up at once and the third waits (%.2f, %.2f, %.2f s)" % [order[0], order[1], order[2]])
	var ended: float = INF
	for b: Dictionary in bursts:
		if float(b["start"]) < order[2] - 0.001:
			ended = minf(ended, float(b["end"]) + ct.burst_gap)
	check(order[2] >= ended - 0.02, "until a burst is over, burst_gap after its last bolt (%.2f s, from %.2f s)" % [order[2], ended])
	await sim.free_world(w)


## A cyborg killed mid-charge leaves the air at once: the third, waiting, starts right away (its claim
## isn't left behind).
func _test_killed_mid_charge() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	w.player.god_mode = true
	var cyborgs: Array[Cyborg] = [_cyborg(w, 110.0, 0, 3), _cyborg(w, 110.0, 4, 4), _cyborg(w, 110.0, 1, 5)]
	var guns: Array[CyborgGun] = [cyborgs[0].gun, cyborgs[1].gun, cyborgs[2].gun]
	var charging := func() -> int:
		var n: int = 0
		for g: CyborgGun in guns:
			if g.state == CyborgGun.State.CHARGING:
				n += 1
		return n
	var started: bool = await _step(w, 8.0, func() -> bool: return charging.call() == 2)
	check(started, "two charge up")
	var waiting: int = -1
	var victim: int = -1
	for i: int in 3:
		if guns[i].state == CyborgGun.State.CHARGING:
			victim = i if victim < 0 else victim
		else:
			waiting = i
	if not started or waiting < 0 or victim < 0:
		await sim.free_world(w)
		return
	var killed_at: float = w.level_time()
	cyborgs[victim].defeat(&"test")
	await _step(w, 1.0, func() -> bool: return guns[waiting].state == CyborgGun.State.CHARGING)
	var third: Array[CyborgGun] = [guns[waiting]]
	var mine: Array[Dictionary] = _bursts(third)
	check(not mine.is_empty() and float(mine[0]["start"]) - killed_at < 0.1,
		"the third starts as soon as one charging is killed (%.2f s later)" % (float(mine[0]["start"]) - killed_at if not mine.is_empty() else INF))
	await sim.free_world(w)


## GameRules.max_bursts_in_air at 1: the cyborgs take turns, as the build had it.
func _test_limit_of_one() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	w.rules = w.rules.duplicate() as GameRules
	w.rules.max_bursts_in_air = 1
	w.player.god_mode = true
	var guns: Array[CyborgGun] = [_cyborg(w, 110.0, 0, 3).gun, _cyborg(w, 110.0, 4, 4).gun]
	await _step(w, 8.0, func() -> bool: return _fired(_bursts(guns), 0).size() >= 1 and _fired(_bursts(guns), 1).size() >= 1)
	var bursts: Array[Dictionary] = _bursts(guns)
	check(not _fired(bursts, 0).is_empty() and not _fired(bursts, 1).is_empty(), "both still fire")
	check(_most_at_once(bursts) == 1, "with the limit at 1, one burst in the air at a time")
	await sim.free_world(w)


## The crossfire rule. Two cyborgs on the left, 8 m apart: the second sees the runner well after the first
## began charging (more than reaction_time). The runner, in the middle lane, dodges the first burst one lane
## to the right as its aim locks.
## - 3 lanes: from the middle lane a dodge ends in an edge lane, whose only neighbour is the lane the first
##   burst comes down, so the second waits before its charge-up while the runner could end up there (task
##   R3's rule: a waiting attack waits before its telegraph), and fires once its bolts would arrive
##   crossfire_gap after the first's. No charge-up is called off.
## - 5 lanes: the lane beyond is free wherever the runner goes, so the second starts at once and fires at
##   the runner's new lane, its bolts arriving with the first's.
## Either way a runner who then dodges the bolts they see survives.
func _test_crossfire(lanes: int) -> void:
	var tag: String = "(%d lanes)" % lanes
	var w: RunWorld = sim.build_world(RunSim.layout(lanes, 600.0))
	var guns: Array[CyborgGun] = [_cyborg(w, 110.0, 0, 21).gun, _cyborg(w, 118.0, 0 if lanes == 3 else 1, 22).gun]
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
	await _step(w, 9.0, func() -> bool: return not w.player.alive or w.player.distance > 140.0, bot)
	check(w.player.alive, "a runner who dodges the bolts they see survives %s (%s)" % [tag, cause[0]])
	var bursts: Array[Dictionary] = _bursts(guns)
	var a: Array[Dictionary] = _fired(bursts, 0)
	var b: Array[Dictionary] = _fired(bursts, 1)
	check(not a.is_empty() and not b.is_empty(), "both fire %s (%d, %d bursts)" % [tag, a.size(), b.size()])
	check(_crossfire_offs(bursts) == 0, "no charge-up is called off %s" % tag)
	if a.is_empty() or b.is_empty():
		await sim.free_world(w)
		return
	var half: float = tuning.lane_width * 0.5
	var crossed: bool = absf(float(a[0]["line"]) - float(b[0]["line"])) > half \
		and _arrive_together(a[0], b[0], ct.crossfire_gap)
	var second: Array[Dictionary] = []
	for x: Dictionary in bursts:
		if int(x["gun"]) == 1:
			second.append(x)
	if lanes == 3:
		check(float(second[0]["start"]) > float(state["locked"]),
			"the second waits before its charge-up while the runner in the middle lane could be caught (it began %.2f s, the first locked %.2f s) %s"
			% [float(second[0]["start"]), float(state["locked"]), tag])
		check(not crossed, "its bolts never arrive in the edge lane with the first's beside it %s" % tag)
		check(float(b[0]["first"]) >= float(a[0]["last"]) + ct.crossfire_gap - 0.05,
			"they arrive crossfire_gap after the first's (%.2f s after) %s" % [float(b[0]["first"]) - float(a[0]["last"]), tag])
	else:
		check(float(second[0]["start"]) < float(state["locked"]), "the second starts before the first's aim locks %s" % tag)
		check(crossed, "and fires at the runner's new lane while the first's bolts arrive (a lane is free) %s" % tag)
	await sim.free_world(w)


## A hover truck alongside holds its lane (GDD §9.3: its solid side bumps a lane switch back), so it's no
## way out. Three lanes, the truck alongside in lane 2, two cyborgs ahead in lane 0; the runner, in lane 0,
## dodges the first burst into lane 1 as its aim locks. While the truck holds lane 2, the second burst
## never arrives in lane 1 within crossfire_gap of the first's (with no truck there, it may). Begun with the
## first, the second is called off as its aim locks (the last resort); begun well after (`late`), it waits
## before its charge-up.
func _test_truck() -> void:
	for late: bool in [false, true]:
		for truck: bool in [true, false]:
			var tag: String = "(%s, %s)" % ["the second begins late" if late else "together", "truck" if truck else "no truck"]
			var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
			w.player.god_mode = true
			var lorry: Enemy = null
			if truck:
				lorry = w.director.spawn({"type": "hover_truck", "at": 0.0, "side": 1, "seed": 2,
					"params": {"skip_entrance": true, "phase": "alongside", "offset": -2.8, "guns": false, "stay": 60.0}})
			var guns: Array[CyborgGun] = [_cyborg(w, 75.0, 0, 21).gun, _cyborg(w, 85.0 if late else 79.0, 0, 22).gun]
			var state := {"start": false, "dodged": false, "held": true}
			var bot := func() -> void:
				var p: Player = w.player
				if not bool(state["start"]):
					state["start"] = true
					p.press(&"move_left")
				elif not bool(state["dodged"]) and guns[0].state == CyborgGun.State.FIRING:
					state["dodged"] = true
					p.press(&"move_right")
				if truck and (not is_instance_valid(lorry) or int(lorry.get(&"lane")) != 2):
					state["held"] = false
			await _step(w, 6.0, func() -> bool: return w.player.distance > 100.0, bot)
			var bursts: Array[Dictionary] = _bursts(guns)
			var a: Array[Dictionary] = _fired(bursts, 0)
			var b: Array[Dictionary] = _fired(bursts, 1)
			check(not a.is_empty(), "the first fires %s" % tag)
			var crossed: bool = false
			for x: Dictionary in b:
				for y: Dictionary in a:
					crossed = crossed or (absf(float(x["line"]) - float(y["line"])) > tuning.lane_width * 0.5
						and _arrive_together(x, y, ct.crossfire_gap))
			if truck:
				check(bool(state["held"]), "the truck holds lane 2 throughout %s" % tag)
				check(not crossed, "the second never arrives in lane 1 with the first's bolts in lane 0 %s" % tag)
				if late:
					check(_crossfire_offs(bursts) == 0, "begun late, the second waits before its charge-up %s" % tag)
				else:
					check(_crossfire_offs(bursts) == 1, "begun with the first, it is called off as its aim locks %s" % tag)
			elif not late:
				check(crossed, "with lane 2 free the second fires at lane 1 meanwhile %s" % tag)
			await sim.free_world(w)


## A wall runner can only drop off into the outer lane below (GDD §3). A floor cyborg's burst locks on the
## runner in the outer lane, the runner steps up onto the wall, and a window cyborg on the far wall would
## fire at them: it waits before its charge-up (the runner in the outer lane could step onto the wall, and
## from there the only way down is the lane the floor cyborg's bolts come down), so no charge-up is called
## off, and its bolts never arrive within crossfire_gap of the floor cyborg's.
func _test_wall_runner() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
	w.player.god_mode = true
	var wc := w.director.spawn({"type": "window_cyborg", "at": 118.0, "lane": 0, "side": -1, "seed": 23,
		"params": {}}) as WindowCyborg
	var guns: Array[CyborgGun] = [_cyborg(w, 110.0, 0, 21).gun, wc.gun]
	var state := {"up": false, "wall_from": INF, "wall_to": INF}
	var bot := func() -> void:
		var p: Player = w.player
		if p.distance > 10.0 and p.surface == Player.Surface.FLOOR and p.lane == 1 and not bool(state["up"]):
			p.press(&"move_right")
		elif not bool(state["up"]) and guns[0].state == CyborgGun.State.FIRING:
			state["up"] = true
			p.press(&"move_right")
		if p.surface == Player.Surface.WALL and float(state["wall_from"]) == INF:
			state["wall_from"] = w.level_time()
		elif p.surface != Player.Surface.WALL and float(state["wall_from"]) < INF and float(state["wall_to"]) == INF:
			state["wall_to"] = w.level_time()
	await _step(w, 9.0, func() -> bool: return w.player.distance > 140.0, bot)
	var bursts: Array[Dictionary] = _bursts(guns)
	var shots: Array[Dictionary] = _fired(bursts, 0)
	check(not shots.is_empty() and float(state["wall_from"]) < float(shots[0]["first"]),
		"the runner steps onto the wall with the floor cyborg's bolts on their way to the outer lane")
	check(_crossfire_offs(bursts) == 0, "the window cyborg waits before its charge-up: none is called off")
	var on_wall: int = 0
	for b: Dictionary in _fired(bursts, 1):
		if float(b["start"]) > float(state["wall_from"]) and float(b["start"]) < float(state["wall_to"]):
			on_wall += 1
		for f: Dictionary in shots:
			check(not _arrive_together(b, f, ct.crossfire_gap),
				"its bolts never arrive with the floor cyborg's in the lane below (%.2f-%.2f s, %.2f-%.2f s)" % [
				float(b["first"]), float(b["last"]), float(f["first"]), float(f["last"])])
	check(on_wall > 0, "it fires at the wall runner once the floor cyborg's bolts are by")
	await sim.free_world(w)


## Bolts at a wall runner aren't aimed at the lane below, so two guns charging at the same wall runner both
## fire, whether they began together or one well after the other: a floor cyborg and a window cyborg on the
## far wall, at the runner on the right wall.
func _test_both_at_wall_runner() -> void:
	for apart: float in [0.0, 2.0, 4.0, 8.0]:
		var tag: String = "(%.0f m apart)" % apart
		var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
		w.player.god_mode = true
		var c: Cyborg = _cyborg(w, 80.0, 0, 21)
		var wc := w.director.spawn({"type": "window_cyborg", "at": 80.0 + apart, "lane": 0, "side": -1, "seed": 23,
			"params": {}}) as WindowCyborg
		var guns: Array[CyborgGun] = [c.gun, wc.gun]
		var state := {"frame": 0, "walls": [0, 0]}
		var press := func() -> void:
			state["frame"] = int(state["frame"]) + 1
			if int(state["frame"]) == 2 or int(state["frame"]) == 15:
				w.player.press(&"move_right")
		# Each gun firing while the runner is on the wall: seen after every frame, so the last one counts too.
		var done := func() -> bool:
			for k: int in 2:
				if guns[k].state == CyborgGun.State.FIRING and w.player.surface == Player.Surface.WALL:
					(state["walls"] as Array)[k] = 1
			return not _fired(_bursts(guns), 0).is_empty() and not _fired(_bursts(guns), 1).is_empty()
		await _step(w, 3.0, done, press)
		var bursts: Array[Dictionary] = _bursts(guns)
		check(not _fired(bursts, 0).is_empty() and not _fired(bursts, 1).is_empty() and (state["walls"] as Array) == [1, 1],
			"both fire at the wall runner %s" % tag)
		check(_crossfire_offs(bursts) == 0, "and neither is called off %s" % tag)
		await sim.free_world(w)


## Wild fire (the panic variant's: its bolts land anywhere around the runner, so no lane is sure to be
## free of them) never arrives within crossfire_gap of another burst. A panic cyborg starts running and
## firing as a cyborg further ahead fires at the runner: its burst waits until its bolts arrive well apart.
func _test_wild() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(5, 600.0))
	w.player.god_mode = true
	var panic: Cyborg = w.director.spawn({"type": "cyborg", "at": 110.0, "lane": 0, "side": 0, "seed": 31,
		"params": {"panic": true}}) as Cyborg
	var guns: Array[CyborgGun] = [_cyborg(w, 130.0, 4, 32).gun, panic.gun]
	var fled: Array[float] = [INF]
	var watch := func() -> void:
		if panic.mode == Cyborg.Mode.FLEE and fled[0] == INF:
			fled[0] = w.level_time()
	await _step(w, 9.0, func() -> bool:
		var all: Array[Dictionary] = _bursts(guns)
		return not _fired(all, 0).is_empty() and not _fired(all, 1).is_empty() \
			and guns[1].state != CyborgGun.State.FIRING, watch)
	var bursts: Array[Dictionary] = _bursts(guns)
	var aimed: Array[Dictionary] = _fired(bursts, 0)
	var wild: Array[Dictionary] = _fired(bursts, 1)
	check(not aimed.is_empty() and not wild.is_empty(), "both fire (%d, %d bursts)" % [aimed.size(), wild.size()])
	if aimed.is_empty() or wild.is_empty():
		await sim.free_world(w)
		return
	check(bool(wild[0]["wild"]) and not bool(aimed[0]["wild"]), "the panic cyborg's fire is wild, the other's aimed")
	check(float(wild[0]["start"]) > fled[0] + 0.5,
		"the panic cyborg holds its fire while the other's burst would arrive with it (fled %.2f s, fired %.2f s)"
		% [fled[0], float(wild[0]["start"])])
	for a: Dictionary in aimed:
		for x: Dictionary in wild:
			check(not _arrive_together(a, x, ct.crossfire_gap - 0.05),
				"wild fire never arrives within crossfire_gap of another burst (%.2f-%.2f s, %.2f-%.2f s)" % [
				float(x["first"]), float(x["last"]), float(a["first"]), float(a["last"])])
	await sim.free_world(w)


## The places one move away (CyborgGun._moves): beside the lane on the floor; from an outer lane, the wall
## beside it where one can step onto it (a candidate for where a dodge ends, never a way out); from a wall,
## only the outer lane below. A lane a hover truck alongside holds is none, while a zone doodad ahead
## doesn't count (path_clear keeps doodads off the bolts' arrival). On a ceiling, only its lanes and
## never one a turret stands in ahead.
func _test_moves() -> void:
	var layout: LevelLayout = RunSim.layout(5, 600.0)
	layout.doodads.append({"lane": 1, "start": 30.0, "end": 33.0, "size": &"medium", "side": 1, "seed": 3})
	var w: RunWorld = sim.build_world(layout)
	var wc := w.director.spawn({"type": "window_cyborg", "at": 300.0, "lane": 0, "side": -1, "seed": 3,
		"params": {"fires": false}}) as WindowCyborg
	var gun: CyborgGun = wc.gun
	gun._reach = 60.0
	await tree.physics_frame
	var floor_at := func(lane: int) -> Dictionary: return gun._lane_place(Player.Surface.FLOOR, lane)
	check(_same(_lanes_of(gun._moves(floor_at.call(2), true), 5), [1, 3]), "on the floor: the lanes either side")
	check(_same(_lanes_of(gun._moves(floor_at.call(0), false), 5), [1])
		and _same(_lanes_of(gun._moves(floor_at.call(4), false), 5), [3]), "in an outer lane: the one beside it")
	check(_same(_lanes_of(gun._moves(floor_at.call(0), true), 5), [1, -1])
		and _same(_lanes_of(gun._moves(floor_at.call(4), true), 5), [3, 5]),
		"and the wall beside it, where the runner could end a dodge")
	check(_same(_lanes_of(gun._moves(gun._wall_place(1), true), 5), [4])
		and _same(_lanes_of(gun._moves(gun._wall_place(-1), true), 5), [0]), "from a wall: only the outer lane below")
	check(not w.track.find_children("Doodad", "Area3D", true, false).is_empty(), "a doodad stands in lane 1 ahead")
	check(_same(_lanes_of(gun._moves(floor_at.call(2), false), 5), [1, 3]), "a doodad ahead doesn't hold its lane")
	var truck := w.director.spawn({"type": "hover_truck", "at": 0.0, "side": 1, "seed": 2,
		"params": {"skip_entrance": true, "phase": "alongside", "offset": -2.8, "guns": false, "stay": 60.0}})
	for i: int in 3:
		await tree.physics_frame
	check(int(truck.get(&"lane")) == 4, "the truck runs alongside in lane 4")
	check(_same(_lanes_of(gun._moves(floor_at.call(3), false), 5), [2]), "a hover truck alongside holds its lane")
	check(_same(_lanes_of(gun._moves(gun._wall_place(1), true), 5), []), "and the lane below the wall it runs beside")
	# A turret on a ceiling over lanes 1-3, another in lane 3 ahead of it.
	var params := {"hull_start": 100.0, "hull_end": 260.0, "first_lane": 1, "last_lane": 3, "fires": false}
	var t1 := w.director.spawn({"type": "barnacle_turret", "at": 200.0, "lane": 1, "side": 0, "seed": 5,
		"params": params}) as BarnacleTurret
	w.director.spawn({"type": "barnacle_turret", "at": 180.0, "lane": 3, "side": 0, "seed": 6, "params": params})
	var tg: CyborgGun = t1.gun
	var ceiling_at := func(lane: int) -> Dictionary: return tg._lane_place(Player.Surface.CEILING, lane)
	tg._reach = 150.0
	check(_same(_lanes_of(tg._moves(ceiling_at.call(1), true), 5), [2]), "a ceiling rider dodges only within its ceiling")
	check(_same(_lanes_of(tg._moves(ceiling_at.call(2), true), 5), [1, 3]), "into either lane beside them, no turret there yet")
	tg._reach = 185.0
	check(_same(_lanes_of(tg._moves(ceiling_at.call(2), true), 5), [1]), "never into a lane a turret stands in before the bolts pass")
	await sim.free_world(w)


## GDD §9.8: both turrets on a ceiling may fire together.
func _test_turrets_together() -> void:
	var layout: LevelLayout = RunSim.layout(5, 600.0)
	layout.hulls.append(LevelLayout.make_hull(97.0, 230.0, Vector2i(1, 3), 5))
	layout.pads.append({"lane": 2, "at": 100.0})
	var w: RunWorld = sim.build_world(layout)
	w.player.god_mode = true
	var params := {"hull_start": 97.0, "hull_end": 230.0, "first_lane": 1, "last_lane": 3}
	var guns: Array[CyborgGun] = []
	for lane: int in [1, 3]:
		var t := w.director.spawn({"type": "barnacle_turret", "at": 190.0, "lane": lane, "side": 0, "seed": 5 + lane,
			"params": params}) as BarnacleTurret
		guns.append(t.gun)
	await _step(w, 12.0, func() -> bool:
		var all: Array[Dictionary] = _bursts(guns)
		return (not _fired(all, 0).is_empty() and not _fired(all, 1).is_empty()) or w.player.distance > 220.0)
	var bursts: Array[Dictionary] = _bursts(guns)
	var a: Array[Dictionary] = _fired(bursts, 0)
	var b: Array[Dictionary] = _fired(bursts, 1)
	check(w.player.surface == Player.Surface.CEILING or w.player.distance > 220.0, "the runner rides the ceiling")
	check(not a.is_empty() and not b.is_empty(), "both turrets fire at the rider (%d, %d bursts)" % [a.size(), b.size()])
	if not a.is_empty() and not b.is_empty():
		check(absf(float(a[0]["start"]) - float(b[0]["start"])) < 0.02 and _most_at_once(bursts) == 2,
			"together (%.2f s and %.2f s)" % [float(a[0]["start"]), float(b[0]["start"])])
	await sim.free_world(w)


## Every attempt at a seed plays out the same way (GDD §6): the crossfire scenario on three lanes, run twice
## with the same runner, gives every gun the same events.
func _test_same_every_time() -> void:
	var logs: Array[String] = []
	for k: int in 2:
		var w: RunWorld = sim.build_world(RunSim.layout(3, 600.0))
		w.player.god_mode = true
		var guns: Array[CyborgGun] = [_cyborg(w, 110.0, 0, 21).gun, _cyborg(w, 118.0, 0, 22).gun,
			_cyborg(w, 118.0, 2, 23).gun]
		var state := {"dodged": false}
		var bot := func() -> void:
			if not bool(state["dodged"]) and guns[0].state == CyborgGun.State.FIRING:
				state["dodged"] = true
				w.player.press(&"move_right")
			elif bool(state["dodged"]):
				_dodge(w)
		await _step(w, 9.0, func() -> bool: return not w.player.alive or w.player.distance > 140.0, bot)
		var lines: Array[String] = []
		for i: int in guns.size():
			for e: Dictionary in guns[i].events:
				lines.append("%d %s %.4f %.4f %.4f %s" % [i, e["event"], float(e["t"]), float(e.get("impact", 0.0)),
					float(e.get("line", 0.0)), e.get("why", "")])
		logs.append("\n".join(lines))
		await sim.free_world(w)
	check(logs[0] != "" and logs[0] == logs[1], "the same scenario plays out the same way twice (%d events)" % logs[0].count("\n"))
