extends RefCounted
## Watches the big attacks in a run (GDD §9, "Big attacks take turns") frame by frame, for
## tools/measure/big_attacks.gd and the tests (test_enemy_director.gd). It reads the enemies' own
## states and the live shots, never the turn-taking code it checks, so it measures a build with the
## rule on, off, or without it the same way.
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
## Overlap is the time during which attacks of two or more types are open at once. Also watched
## (not a big attack, docs/questions/r3.md): a hover truck's entrance, from its first bang until its
## burst stops hurting. The event log lists every state change of every enemy, so two builds can be
## compared run by run.

const DroneScript := preload("res://scripts/enemies/drone.gd")
const TruckScript := preload("res://scripts/enemies/hover_truck.gd")
## Enemy shots that belong to a big attack, by name, and the type they belong to.
const SHOT_TYPES: Dictionary = {"drone gatling": &"drone", "hover truck cannon": &"hover_truck",
	"hover truck gunner": &"hover_truck"}

var world: RunWorld
## The runner stomps every host it passes (each releases a Bad Dream chase).
var stomp_hosts: bool = false
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
## By kind: for each attack that started after a wait, how long it waited (seconds), and how much
## of that it waited for another type's turn (only a director that takes turns keeps track).
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
var log := PackedStringArray()

var _ids: Dictionary = {}
var _sigs: Dictionary = {}
var _was_open: Dictionary = {}
var _held: Dictionary = {}
var _held_turn: Dictionary = {}
var _overlapping: bool = false


func _init(p_world: RunWorld, p_stomp_hosts: bool = false) -> void:
	world = p_world
	stomp_hosts = p_stomp_hosts
	for e: Enemy in world.director.active:
		_on_spawned(e)
	world.director.enemy_spawned.connect(_on_spawned)


## Looks at the run once; call it every physics frame.
func observe() -> void:
	var p: Player = world.player
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var now: float = world.level_time()
	var open_types: Dictionary = {}
	var entrance: bool = false
	var turns_known: bool = world.director.has_method(&"is_waiting")
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
				if float(_held.get(key, 0.0)) > 0.0:
					(waits.get_or_add(kind, []) as Array).append(float(_held[key]))
				if float(_held_turn.get(key, 0.0)) > 0.0:
					(turn_waits.get_or_add(kind, []) as Array).append(float(_held_turn[key]))
			_was_open[wk] = now
		if turns_known and bool(world.director.call(&"is_waiting", e)):
			_held[key] = float(world.director.call(&"turn_wait", e)) + dt
			if bool(world.director.call(&"held_for_turn", e)):
				_held_turn[key] = float(_held_turn.get(key, 0.0)) + dt
		else:
			_held.erase(key)
			_held_turn.erase(key)
	var reach: float = p.position.z + world.tuning.hurtbox_size.z * 0.5
	for shot: Projectile in world.projectiles.live_shots():
		if not shot.friendly and shot.in_use and SHOT_TYPES.has(shot.hazard_name) and shot.position.z <= reach + shot.radius:
			open_types[SHOT_TYPES[shot.hazard_name]] = true
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
	return out


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
		"trucks_idle": trucks_without(""), "log_hash": log_hash(), "log_lines": log.size()}


func _on_spawned(e: Enemy) -> void:
	if not _ids.has(e.get_instance_id()):
		_ids[e.get_instance_id()] = _ids.size()


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
	return base
