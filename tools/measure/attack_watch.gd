extends RefCounted
## Watches the big attacks in a run (GDD §9, "Big attacks take turns") frame by frame, for
## tools/measure/big_attacks.gd and the tests (test_enemy_director.gd). It reads the attacks from the
## enemies' own states and the live shots, never from the turn-taking code it checks (only the waits
## come from the director's answers), so it measures a build with the rule on, off, or without it the
## same way.
##   const AttackWatch = preload("res://tools/measure/attack_watch.gd")
##   var watch := AttackWatch.new(world)     # before the enemies spawn
##   ... every physics frame: await tree.physics_frame; watch.observe()
##   watch.overlap, watch.attacks, watch.summary()
##
## Each big attack is open from its warning until its last hazard is over:
##   drone: wind-up and barrage, until its last bullet has passed the player
##   hover truck: the rev and the forward lurch; a cannon shot from the charge until the shell and
##     the window shooters' bolts have passed the player
##   Octodog: each charge, wind-up and lunge
##   Bad Dream: each slash, telegraph to claws
##   Resonator: each pulse, from its warning (the halos and the chime) until its last wave has passed
##     the player
##   Gilded Sentinel: each strike, from its eyes' flare (its warning) until its last swing's cut is over
##   Buzz Overdrive: its charge, from its rev (its warning) until it's gone (its cut has passed the player)
##   Enforcer Truck: each volley, from its warning (the red line and the whine) until its last bolt has passed
##     the player (task C6)
## Overlap is the time during which attacks of two or more types are open at once. Also watched
## (not a big attack, docs/questions/r3.md): a hover truck's entrance, from its first bang until its
## burst stops hurting. The event log lists every state change of every enemy, so two builds can be
## compared run by run. A wait for a turn lasts from the first frame the director holds its enemy for
## another type's turn until the enemy's next big attack starts, through short gaps (WAIT_BRIDGE). Each
## Buzz Overdrive that sets off rolling is followed to its end (buzz_tanks): it revs (into another
## type's open big attack, or not), lets the runner pass, or is shot down first. Each Enforcer Truck that
## arrives is followed too (enforcers): its volleys, its riders, and what destroyed it.

const DroneScript := preload("res://scripts/enemies/drone.gd")
const TruckScript := preload("res://scripts/enemies/hover_truck.gd")
const BuzzScript := preload("res://scripts/enemies/buzz_overdrive.gd")
## Enemy shots that belong to a big attack, by name, and the type they belong to.
const SHOT_TYPES: Dictionary = {"drone gatling": &"drone", "hover truck cannon": &"hover_truck",
	"hover truck gunner": &"hover_truck"}
## A wait for a turn runs from the first frame the director holds its enemy for another type's turn
## (EnemyDirector.held_for_turn: it asked this frame or the last and was held for another's attack)
## until its attack starts, through gaps of up to this many seconds in which it isn't held (its stretch
## not clear for a while, its turn come while it isn't quite ready); a wait whose attack comes later
## than that after its last hold isn't counted. An Octodog's wait lasts until it charges or runs off,
## however long it moves its charges on and uses its slack: all of that is its delay. The director
## answers each ask the same whatever it keeps in its queue, so two directors measure the same asks
## alike; waits for GDD §9.7's exclusive rule (the Bad Dream's chase) don't count.
const WAIT_BRIDGE: float = 3.0

var world: RunWorld
## The runner stomps every host it passes (each releases a Bad Dream chase).
var stomp_hosts: bool = false
## The lane the runner keeps to: the one it starts in (the middle one). A zone doodad (GDD §3, task G5)
## pushes it out, and it steps back once the doodad is behind it, so it keeps to that lane all the
## way as it did before doodads stood in lanes (in a level without them it never moves). -1: it stays
## wherever it's pushed.
var keep_lane: int = -1
## Seconds of overlap between types, in all and by the types involved ("drone+hover_truck").
var overlap: float = 0.0
var overlap_pairs: Dictionary = {}
## How many times an overlap began.
var events: int = 0
## Big attacks started, by kind: drone, truck_lurch, truck_cannon, dog_charge, dream_slash,
## resonator_pulse.
var attacks: Dictionary = {}
## Seconds each type had an attack open.
var open_seconds: Dictionary = {}
## By kind: for each attack that started after a wait for its turn (WAIT_BRIDGE), how long it waited
## (seconds), and how much of that it was held (only a director that takes turns holds any).
var waits: Dictionary = {}
var turn_waits: Dictionary = {}
## Seconds a hover truck's entrance was on while a big attack was open.
var entrance_overlap: float = 0.0
var hosts_stomped: int = 0
## Octodogs by spawn index: the charges (wind-ups) each made.
var dog_charges: Dictionary = {}
## Resonators by spawn index: the pulses each made (from the time it starts pacing the player).
var resonator_pulses: Dictionary = {}
## Drones by spawn index: the barrages each started (from the time it swoops in).
var drone_barrages: Dictionary = {}
## Hover trucks by spawn index: the forward lurches (revs) and cannon shots (charges) each started
## (from the time it bursts out): {"lurch": n, "cannon": n}.
var truck_attacks: Dictionary = {}
## Buzz Overdrives by spawn index, once they set off rolling ahead of the runner (task FIX2): {"rev": it
## revved (its big attack began), "met": another type's big attack was open as its rev began, "pass": it
## left its roll another way than its rev while alive (it let the runner pass), "down": shot down before
## its rev}. Read from its states only, so it measures a build whose tank never passes the same way.
var buzz_tanks: Dictionary = {}
## Enforcer Trucks by spawn index, once they arrive behind the runner (task C6): {"volleys": volleys warned,
## "riders": riders aboard, "down": what destroyed it ("" while it isn't)}.
var enforcers: Dictionary = {}
var log := PackedStringArray()

var _ids: Dictionary = {}
var _sigs: Dictionary = {}
var _was_open: Dictionary = {}
## Enemies waiting for their turn, by spawn index: when the current wait began and when the director
## last held it for another type's turn (level times), and the seconds it was held.
var _wait_began: Dictionary = {}
var _wait_seen: Dictionary = {}
var _held_turn: Dictionary = {}
var _overlapping: bool = false
## The level time before which the runner won't step back toward keep_lane again (one move at a time).
var _next_step: float = 0.0
## Buzz Overdrives whose rev began this frame (their spawn index), and each one's last state seen.
var _revs_now: Array[int] = []
var _tank_state: Dictionary = {}


func _init(p_world: RunWorld, p_stomp_hosts: bool = false) -> void:
	world = p_world
	stomp_hosts = p_stomp_hosts
	keep_lane = world.player.lane
	for e: Enemy in world.director.active:
		_on_spawned(e)
	world.director.enemy_spawned.connect(_on_spawned)
	world.director.enemy_defeated.connect(_on_defeated)


## Looks at the run once; call it every physics frame.
func observe() -> void:
	var p: Player = world.player
	_keep_to_lane(p)
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var now: float = world.level_time()
	var open_types: Dictionary = {}
	var entrance: bool = false
	var turns_known: bool = world.director.has_method(&"held_for_turn")
	for e: Enemy in world.director.active:
		if not is_instance_valid(e):
			continue
		var key: int = int(_ids.get(e.get_instance_id(), -1))
		var sig: String = _signature(e)
		if _sigs.get(key, "") != sig:
			_sigs[key] = sig
			log.append("%.3f #%d %s %s" % [now, key, e.type_id, sig])
		if stomp_hosts and e.alive and e.is_host and e.type_id == &"cyborg":
			var ahead: float = e.track_distance() - p.distance
			if ahead > 0.0 and ahead < 2.5:
				e.defeat(&"stomp")
				hosts_stomped += 1
		if e.type_id == &"octodog" and not dog_charges.has(key):
			dog_charges[key] = 0
		if e.type_id == &"resonator" and not resonator_pulses.has(key) and e.alive \
				and int(e.get(&"state")) != Resonator.State.APPROACH:
			resonator_pulses[key] = 0
		if e.type_id == &"drone" and not drone_barrages.has(key) and e.alive \
				and int(e.get(&"state")) != DroneScript.State.WAITING:
			drone_barrages[key] = 0
		if e.type_id == &"hover_truck" and e.alive:
			var s: int = int(e.get(&"state"))
			entrance = entrance or s == TruckScript.State.BANGING \
				or (s == TruckScript.State.EMERGE and now - float(e.get(&"burst_time")) < 0.45)
			if not truck_attacks.has(key) and s != TruckScript.State.HIDDEN and s != TruckScript.State.BANGING:
				truck_attacks[key] = {"lurch": 0, "cannon": 0}
		if e.type_id == &"buzz_overdrive" and e.alive:
			_note_tank(key, int(e.get(&"state")))
		if e.type_id == &"enforcer_truck" and e.alive and int(e.get(&"state")) != EnforcerTruck.State.WAITING:
			var rec: Dictionary = enforcers.get_or_add(key, {"volleys": 0, "riders": 0, "down": ""})
			rec["volleys"] = int(e.get(&"volleys"))
			rec["riders"] = int(e.get(&"riders"))
		for kind: String in open_kinds(e):
			open_types[e.type_id] = true
			var wk: String = "%d/%s" % [key, kind]
			if not _was_open.has(wk):
				# An attack starts: how long did its enemy wait for it (as seen the frame before)?
				attacks[kind] = int(attacks.get(kind, 0)) + 1
				if kind == "dog_charge":
					dog_charges[key] = int(dog_charges.get(key, 0)) + 1
				if kind == "resonator_pulse":
					resonator_pulses[key] = int(resonator_pulses.get(key, 0)) + 1
				if kind == "drone":
					drone_barrages[key] = int(drone_barrages.get(key, 0)) + 1
				if kind == "truck_lurch" or kind == "truck_cannon":
					var made: Dictionary = truck_attacks.get_or_add(key, {"lurch": 0, "cannon": 0})
					var k: String = "lurch" if kind == "truck_lurch" else "cannon"
					made[k] = int(made[k]) + 1
				if kind == "buzz_charge":
					_revs_now.append(key)
				if _wait_began.has(key) and not _wait_over(e, now - float(_wait_seen[key]) - dt):
					(waits.get_or_add(kind, []) as Array).append(now - float(_wait_began[key]))
					(turn_waits.get_or_add(kind, []) as Array).append(float(_held_turn[key]))
				_end_wait(key)
			_was_open[wk] = now
		if turns_known and bool(world.director.call(&"held_for_turn", e)):
			if not _wait_began.has(key):
				_wait_began[key] = now
				_held_turn[key] = 0.0
			_wait_seen[key] = now
			_held_turn[key] = float(_held_turn[key]) + dt
		elif _wait_began.has(key) and _wait_over(e, now - float(_wait_seen[key])):
			_end_wait(key)
	var reach: float = p.position.z + world.tuning.hurtbox_size.z * 0.5
	for shot: Projectile in world.projectiles.live_shots():
		if not shot.friendly and shot.in_use and SHOT_TYPES.has(shot.hazard_name) and shot.position.z <= reach + shot.radius:
			open_types[SHOT_TYPES[shot.hazard_name]] = true
	for key: int in _revs_now:
		(buzz_tanks.get_or_add(key, _new_tank()) as Dictionary)["met"] = open_types.size() >= 2
	_revs_now.clear()
	for wk: String in _was_open.keys():
		if float(_was_open[wk]) < now:
			_was_open.erase(wk)
	for t: StringName in open_types:
		open_seconds[String(t)] = float(open_seconds.get(String(t), 0.0)) + dt
	if open_types.size() >= 2:
		overlap += dt
		var names := PackedStringArray(open_types.keys())
		names.sort()
		var pair: String = "+".join(names)
		overlap_pairs[pair] = float(overlap_pairs.get(pair, 0.0)) + dt
		if not _overlapping:
			events += 1
		_overlapping = true
	else:
		_overlapping = false
	if entrance and not open_types.is_empty():
		entrance_overlap += dt


## The big attacks `e` has open right now (see the header), by kind.
static func open_kinds(e: Enemy) -> Array[String]:
	var out: Array[String] = []
	if not is_instance_valid(e) or not e.alive:
		return out
	match e.type_id:
		&"drone":
			var s: int = int(e.get(&"state"))
			if s == DroneScript.State.WINDUP or s == DroneScript.State.FIRE:
				out.append("drone")
		&"hover_truck":
			var s: int = int(e.get(&"state"))
			if s == TruckScript.State.REV or s == TruckScript.State.LURCH_FWD:
				out.append("truck_lurch")
			if bool(e.call(&"charging")) or not (e.get(&"_volley") as Array).is_empty():
				out.append("truck_cannon")
		&"octodog":
			var ph: int = int(e.get(&"phase"))
			if ph == Octodog.Phase.WINDUP or ph == Octodog.Phase.LUNGE:
				out.append("dog_charge")
		&"bad_dream":
			var s: int = int(e.get(&"state"))
			if s == BadDream.State.TELEGRAPH or s == BadDream.State.LUNGE:
				out.append("dream_slash")
		&"resonator":
			var s: int = int(e.get(&"state"))
			if s == Resonator.State.WARNING or s == Resonator.State.PULSE or bool(e.call(&"waves_on_their_way")):
				out.append("resonator_pulse")
		&"gilded_sentinel":
			var s: int = int(e.get(&"state"))
			if s == GildedSentinel.State.WARNING or s == GildedSentinel.State.HOLD or s == GildedSentinel.State.STRIKE:
				out.append("sentinel_strike")
		&"buzz_overdrive":
			var s: int = int(e.get(&"state"))
			if s == BuzzScript.State.REV or s == BuzzScript.State.CHARGE:
				out.append("buzz_charge")
		&"enforcer_truck":
			if int(e.get(&"volley")) != EnforcerTruck.Volley.IDLE:
				out.append("enforcer_volley")
	return out


## True once a wait for `e`'s turn that has seen no hold for `gap` seconds is over: after WAIT_BRIDGE,
## and an Octodog's only once it runs off or is out of play (until then it paces on, moving its charges
## on or using its slack: all of that is its delay).
func _wait_over(e: Enemy, gap: float) -> bool:
	if e.type_id == &"octodog":
		return not e.alive or int(e.get(&"phase")) in [Octodog.Phase.GIVE_UP, Octodog.Phase.LEAVE, Octodog.Phase.FALLING]
	return gap > WAIT_BRIDGE


func _end_wait(key: int) -> void:
	_wait_began.erase(key)
	_wait_seen.erase(key)
	_held_turn.erase(key)


## Octodogs that never charged, and the charges all of them made.
func dogs_without_a_charge() -> int:
	var n: int = 0
	for key: int in dog_charges:
		if int(dog_charges[key]) == 0:
			n += 1
	return n


func charges() -> int:
	var n: int = 0
	for key: int in dog_charges:
		n += int(dog_charges[key])
	return n


## Resonators that came to pace the player and never pulsed (none should: GDD §9's turns never
## starve one, Resonator.turn_wait_max).
func resonators_without_a_pulse() -> int:
	var n: int = 0
	for key: int in resonator_pulses:
		if int(resonator_pulses[key]) == 0:
			n += 1
	return n


## Drones that swooped in and never fired a barrage (a pad may bring one down first).
func drones_without_a_barrage() -> int:
	var n: int = 0
	for key: int in drone_barrages:
		if int(drone_barrages[key]) == 0:
			n += 1
	return n


## Hover trucks that burst out and never made an attack of `kind` ("lurch" or "cannon"; "" = neither).
func trucks_without(kind: String) -> int:
	var n: int = 0
	for key: int in truck_attacks:
		var made: Dictionary = truck_attacks[key]
		if (kind == "" and int(made["lurch"]) + int(made["cannon"]) == 0) or (kind != "" and int(made[kind]) == 0):
			n += 1
	return n


## Buzz Overdrives that set off rolling ahead of the runner (`what` ""), or those of them that revved
## ("rev"), revved while another type's big attack was open ("met"), let the runner pass ("pass") or
## were shot down before their rev ("down").
func tanks_that(what: String = "") -> int:
	var n: int = 0
	for key: int in buzz_tanks:
		if what == "" or bool((buzz_tanks[key] as Dictionary)[what]):
			n += 1
	return n


## The event log's hash: equal for two runs whose enemies did the same things at the same times.
func log_hash() -> String:
	return "\n".join(log).md5_text()


func summary() -> Dictionary:
	return {"overlap": overlap, "overlap_pairs": overlap_pairs, "events": events, "attacks": attacks,
		"open": open_seconds, "held": waits, "held_turn": turn_waits, "entrance_overlap": entrance_overlap,
		"hosts_stomped": hosts_stomped, "dogs": dog_charges.size(), "dog_charges": charges(),
		"dogs_no_charge": dogs_without_a_charge(), "resonators": resonator_pulses.size(),
		"resonators_no_pulse": resonators_without_a_pulse(), "drones": drone_barrages.size(),
		"drones_no_barrage": drones_without_a_barrage(), "trucks": truck_attacks.size(),
		"trucks_no_lurch": trucks_without("lurch"), "trucks_no_cannon": trucks_without("cannon"),
		"trucks_idle": trucks_without(""), "tanks": tanks_that(), "tanks_rev": tanks_that("rev"),
		"tanks_met": tanks_that("met"), "tanks_pass": tanks_that("pass"), "tanks_down": tanks_that("down"),
		"enforcers": enforcers.size(), "enforcers_down": enforcers_destroyed(), "enforcer_riders": enforcer_riders(),
		"log_hash": log_hash(), "log_lines": log.size()}


## Enforcer Trucks destroyed (by a bait, a cut or a gap), of those that arrived.
func enforcers_destroyed() -> int:
	var n: int = 0
	for key: int in enforcers:
		if String((enforcers[key] as Dictionary)["down"]) != "":
			n += 1
	return n


## Riders aboard the Enforcer Trucks that arrived, in all.
func enforcer_riders() -> int:
	var n: int = 0
	for key: int in enforcers:
		n += int((enforcers[key] as Dictionary)["riders"])
	return n


func _on_spawned(e: Enemy) -> void:
	if not _ids.has(e.get_instance_id()):
		_ids[e.get_instance_id()] = _ids.size()


## A Buzz Overdrive shot down (or dashed through) before its rev; an Enforcer Truck destroyed.
func _on_defeated(e: Enemy, cause: StringName) -> void:
	if not _ids.has(e.get_instance_id()):
		return
	if e.type_id == &"enforcer_truck":
		var truck: Dictionary = enforcers.get_or_add(int(_ids[e.get_instance_id()]), {"volleys": 0, "riders": 0, "down": ""})
		truck["down"] = String(cause)
		return
	if e.type_id != &"buzz_overdrive":
		return
	var rec: Dictionary = buzz_tanks.get_or_add(int(_ids[e.get_instance_id()]), _new_tank())
	rec["down"] = not bool(rec["rev"])


## Follows a living Buzz Overdrive's state (`s`): it counts once it sets off rolling; then it revs (REV,
## CHARGE), or it leaves its roll another way (it lets the runner pass).
func _note_tank(key: int, s: int) -> void:
	var was: int = int(_tank_state.get(key, -1))
	_tank_state[key] = s
	if s == BuzzScript.State.ROLL or s == BuzzScript.State.REV or s == BuzzScript.State.CHARGE:
		var rec: Dictionary = buzz_tanks.get_or_add(key, _new_tank())
		rec["rev"] = bool(rec["rev"]) or s != BuzzScript.State.ROLL
	elif was == BuzzScript.State.ROLL and buzz_tanks.has(key):
		(buzz_tanks[key] as Dictionary)["pass"] = true


static func _new_tank() -> Dictionary:
	return {"rev": false, "met": false, "pass": false, "down": false}


## What the event log records of an enemy: alive, and the states its big attacks come from.
static func _signature(e: Enemy) -> String:
	var base: String = "alive" if e.alive else "down"
	match e.type_id:
		&"drone":
			return "%s state=%d barrages=%d" % [base, int(e.get(&"state")), int(e.get(&"barrages"))]
		&"hover_truck":
			return "%s state=%d charging=%s shots=%d lurches=%d" % [base, int(e.get(&"state")),
				bool(e.call(&"charging")), int(e.get(&"cannon_shots")), int(e.get(&"forward_lurches"))]
		&"octodog":
			return "%s phase=%d charges=%d" % [base, int(e.get(&"phase")), int(e.get(&"charges_done"))]
		&"bad_dream":
			return "%s state=%d slashes=%d" % [base, int(e.get(&"state")), int(e.get(&"slashes"))]
		&"resonator":
			return "%s state=%d pulses=%d waves=%d" % [base, int(e.get(&"state")), int(e.get(&"pulses_done")),
				int(e.get(&"waves_sent"))]
		&"cyborg":
			return "%s mode=%d" % [base, int(e.get(&"mode"))]
		&"gilded_sentinel":
			return "%s state=%d" % [base, int(e.get(&"state"))]
		&"buzz_overdrive":
			return "%s state=%d" % [base, int(e.get(&"state"))]
		&"enforcer_truck":
			return "%s state=%d volley=%d volleys=%d riders=%d" % [base, int(e.get(&"state")), int(e.get(&"volley")),
				int(e.get(&"volleys")), int(e.get(&"riders"))]
	return base


## Steps the runner back toward keep_lane after a zone doodad pushed it out, once that doodad is no longer
## beside it: one move at a time, on the floor, through named actions as a player would.
func _keep_to_lane(p: Player) -> void:
	if keep_lane < 0 or not p.alive or not p.running or p.surface != Player.Surface.FLOOR or p.lane == keep_lane:
		return
	var toward: int = 1 if keep_lane > p.lane else -1
	if world.level_time() < _next_step or world.layout.doodad_between(p.distance - 2.0, p.distance + 2.0, p.lane + toward):
		return
	_next_step = world.level_time() + 0.3
	p.press(&"move_right" if toward > 0 else &"move_left")
