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
## Big attacks started, by kind: drone, truck_lurch, truck_cannon, dog_charge, dream_slash.
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
## Octodogs by spawn index: the most charges each made.
var dog_charges: Dictionary = {}
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
		if e.type_id == &"octodog":
			dog_charges[key] = maxi(int(dog_charges.get(key, 0)), int(e.get(&"charges_done")))
		if e.type_id == &"hover_truck" and e.alive:
			var s: int = int(e.get(&"state"))
			entrance = entrance or s == TruckScript.State.BANGING \
				or (s == TruckScript.State.EMERGE and now - float(e.get(&"burst_time")) < 0.45)
		for kind: String in open_kinds(e):
			open_types[e.type_id] = true
			var wk: String = "%d/%s" % [key, kind]
			if not _was_open.has(wk):
				# An attack starts: how long did its enemy wait for it (as seen the frame before)?
				attacks[kind] = int(attacks.get(kind, 0)) + 1
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


## The event log's hash: equal for two runs whose enemies did the same things at the same times.
func log_hash() -> String:
	return "\n".join(log).md5_text()


func summary() -> Dictionary:
	return {"overlap": overlap, "overlap_pairs": overlap_pairs, "events": events, "attacks": attacks,
		"open": open_seconds, "held": waits, "held_turn": turn_waits, "entrance_overlap": entrance_overlap,
		"hosts_stomped": hosts_stomped, "dogs": dog_charges.size(), "dog_charges": charges(),
		"dogs_no_charge": dogs_without_a_charge(), "log_hash": log_hash(), "log_lines": log.size()}


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
		&"cyborg":
			return "%s mode=%d" % [base, int(e.get(&"mode"))]
	return base
