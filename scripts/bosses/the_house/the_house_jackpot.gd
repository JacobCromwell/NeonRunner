class_name TheHouseJackpot
extends Node3D
## The House's jackpot (GDD §10: "With all three locked: JACKPOT. Sirens go off, the machine overloads
## and sprays a fountain of real credits to grab, and its coin hopper bursts open on top as a glowing red
## weak point while it sags low. The player stomps it."):
## 1. SAG: the sirens wail and its lights flash; it rolls on while it brakes to a stop (where the runner
##    reaches its face jackpot_approach later, at any speed, and the last attack's hazards lie at least
##    approach_clear before it), its
##    hopper bursts open on its top with the fountain (fountain_count real credits flung over the street
##    ahead of the runner, landing as credits of the run's CreditField: CreditField.place), and it sinks into
##    the street over sag_seconds until its top is deck_height up: a deck the runner steps onto, the
##    hopper glowing red across it (TheHouseBody.set_sunk: its cabinet's hitbox off).
## 2. OPEN: the hopper is its weak point: a runner coming down onto it, from the street or the deck, stomps
##    it (the stomp box is longer than a jump, so a runner who ran onto the deck can still jump and land on
##    it). The window closes once the runner has passed the box without a stomp: a miss (GDD §10: "it just
##    spins again"). A stomp is the phase's big hit (BossEncounter.stomp_weak_point).
## 3. LURCH: either way it lurches ahead, lurch_speed faster than the runner, its deck sliding out from
##    under a runner still on it, then
## 4. RECOVER: rises out of the street (its cabinet solid again) and rolls back to where it paces over
##    recover_seconds; `finished` tells the encounter, and its spins begin again.
## Nothing here depends on how long the fight has lasted.

signal finished(stomped: bool)

enum Stage { IDLE, SAG, OPEN, LURCH, RECOVER }

## The hopper bursts open (and the fountain flies) this long after the sirens.
const BURST_AFTER: float = 0.3
## Coins of the fountain leave over this long.
const FOUNTAIN_SPREAD: float = 0.3
## The fountain's coins land at least this long (at the run speed) ahead of the runner, and this far
## before the machine's face.
const FOUNTAIN_AHEAD: float = 0.3
const FOUNTAIN_FACE_MARGIN: float = 4.0
## It starts rising once its face (the deck's near end) is this far ahead of the runner.
const RISE_MARGIN: float = 3.0
const COIN_FIVE: int = 5
const COIN_RICH: int = 25

var boss: TheHouse
var tuning: TheHouseTuning
var world: RunWorld
var stage: Stage = Stage.IDLE
var stage_time: float = 0.0
## Where its face stops (track distance) and its speed along the track now.
var stall_front: float = 0.0
var front_speed: float = 0.0
## The jackpots so far, the stomps and the misses.
var count: int = 0
var stomps: int = 0
var misses: int = 0
## The fountain: coins in flight {value, lane, at, from: Vector3, t0, t1, idx, mm} and those placed.
var coins: Array[Dictionary] = []
var placed: int = 0
var stomped: bool = false

var _from_front: float = 0.0
var _from_sag: float = 0.0
var _coin_meshes: Dictionary = {}
var _brake_from: float = 0.0


func setup(p_boss: TheHouse) -> void:
	boss = p_boss
	tuning = boss.tuning
	world = boss.world
	top_level = true
	transform = Transform3D.IDENTITY


## Makes the fountain's flying coins (one MultiMesh per denomination) before the fight.
func prewarm() -> void:
	for value: int in [COIN_FIVE, COIN_RICH]:
		_coin_mesh(value)


func busy() -> bool:
	return stage != Stage.IDLE


## True while the hopper is open to a stomp.
func window_open() -> bool:
	return stage == Stage.OPEN


## JACKPOT: the sirens, the overload, the fountain and the sag (see the header).
func start() -> void:
	count += 1
	stomped = false
	_set_stage(Stage.SAG)
	var body: TheHouseBody = boss.body
	var front: float = boss.front_at
	# It stops where its approach is clear of the last attack's hazards, rolling on while it brakes.
	var v: float = boss.speed()
	var clear_from: float = boss.attacks.hazards_end() + tuning.approach_clear * boss.run_pace()
	var approach: float = world.player.distance + v * tuning.jackpot_approach
	stall_front = maxf(maxf(front + v * tuning.sag_seconds * 0.5, approach), clear_from)
	_brake_from = front
	front_speed = v
	body.jackpot = 1.0
	body.track_speed = v
	boss.sound(&"house_jackpot", body.reels_world())
	boss.react_citizens(&"cheer")
	boss.log_event(&"jackpot", {"stall_front": stall_front, "front": front})


## The hopper was stomped (the encounter's _on_weak_point_hit): it lurches ahead at once.
func on_stomp() -> void:
	if stage != Stage.OPEN:
		return
	stomps += 1
	stomped = true
	var body: TheHouseBody = boss.body
	world.effects.burst(body.hopper_world(), Color(1.0, 0.08, 0.1), 40, 1.2)
	world.effects.burst(body.hopper_world() + Vector3(0.0, 0.5, 0.0), Color(1.0, 0.85, 0.5), 24, 0.9)
	world.effects.shake(0.45, 0.4)
	boss.sound(&"house_hit", body.hopper_world())
	boss.react_citizens(&"cheer")
	boss.log_event(&"hopper_stomped", {"runner": world.player.distance, "span": body.hopper_span(boss.front_at)})
	_lurch()


## Everything back as it was at once (a defeat, a reset in a review): coins in flight dropped.
func clear() -> void:
	for c: Dictionary in coins:
		_hide_coin(c)
	coins.clear()
	if stage != Stage.IDLE:
		_set_stage(Stage.IDLE)
	var body: TheHouseBody = boss.body
	if body != null and is_instance_valid(body):
		body.hopper = 0.0
		body.jackpot = 0.0
		body.set_sunk(false)
		body.set_weak_points_enabled(false)


## The track distances the hopper's stomp box covers now.
func hopper_span() -> Vector2:
	return boss.body.hopper_span(boss.front_at)


func tick(delta: float) -> void:
	_update_coins(delta)
	if stage == Stage.IDLE:
		return
	stage_time += delta
	var body: TheHouseBody = boss.body
	var p: Player = world.player
	var v: float = boss.speed()
	match stage:
		Stage.SAG:
			# It rolls on, braking, to its stop, and sinks.
			var brake: float = clampf(stage_time / maxf(BURST_AFTER + tuning.sag_seconds, 0.05), 0.0, 1.0)
			var before: float = boss.front_at
			boss.front_at = lerpf(_brake_from, stall_front, 1.0 - (1.0 - brake) * (1.0 - brake))
			front_speed = (boss.front_at - before) / maxf(delta, 0.0001)
			if stage_time >= BURST_AFTER and body.hopper < 0.5:
				body.hopper = 1.0
				body.set_sunk(true)
				boss.sound(&"house_sag", body.reels_world())
				boss.sound(&"house_coins", body.hopper_world())
				_fountain()
			var sag_t: float = clampf((stage_time - BURST_AFTER) / maxf(tuning.sag_seconds, 0.05), 0.0, 1.0)
			body.sag = smoothstep(0.0, 1.0, sag_t)
			if sag_t >= 1.0 and brake >= 1.0:
				body.sag = 1.0
				boss.front_at = stall_front
				front_speed = 0.0
				body.set_weak_points_enabled(true)
				_set_stage(Stage.OPEN)
				boss.hint("jackpot")
				boss.log_event(&"hopper_open", {"span": hopper_span(), "runner": p.distance})
		Stage.OPEN:
			front_speed = 0.0
			if p.distance > hopper_span().y:
				misses += 1
				boss.log_event(&"hopper_missed", {"runner": p.distance, "span": hopper_span()})
				_lurch()
		Stage.LURCH:
			front_speed = v + tuning.lurch_speed
			boss.front_at += front_speed * delta
			# Out from under the runner once its face has passed them: then it rises.
			if boss.front_at >= p.distance + RISE_MARGIN:
				body.set_sunk(false)
				body.jackpot = 0.0
				_from_front = boss.front_at - p.distance
				_from_sag = body.sag
				_set_stage(Stage.RECOVER)
		Stage.RECOVER:
			var k: float = clampf(stage_time / maxf(tuning.recover_seconds, 0.05), 0.0, 1.0)
			var e: float = smoothstep(0.0, 1.0, k)
			body.sag = lerpf(_from_sag, 0.0, e)
			var ahead: float = lerpf(_from_front, boss.stand_distance(), e)
			var target: float = p.distance + ahead
			front_speed = (target - boss.front_at) / maxf(delta, 0.0001)
			boss.front_at = target
			if k >= 1.0:
				body.sag = 0.0
				_set_stage(Stage.IDLE)
				boss.log_event(&"jackpot_over", {"stomped": stomped})
				finished.emit(stomped)
	body.track_speed = front_speed


func _lurch() -> void:
	var body: TheHouseBody = boss.body
	body.set_weak_points_enabled(false)
	body.hopper = 0.0
	_set_stage(Stage.LURCH)


func _set_stage(next: Stage) -> void:
	stage = next
	stage_time = 0.0


# --- The fountain --------------------------------------------------------------------------------

## Flings the fountain's credits out of the hopper: each lands, after its flight, in a lane over the
## street between where the runner will be and the machine's face (keeping off whatever of the last
## attack lies there), and becomes a real credit there (CreditField.place).
func _fountain() -> void:
	var n_coins: int = tuning.fountain_count
	if n_coins <= 0 or world.credits == null:
		return
	var n: int = boss.lane_count()
	var v: float = boss.speed()
	var d: float = world.player.distance
	var from: Vector3 = boss.body.hopper_world()
	var last_land: float = FOUNTAIN_SPREAD + tuning.fountain_flight
	var near: float = d + v * (last_land + FOUNTAIN_AHEAD)
	var far: float = stall_front - FOUNTAIN_FACE_MARGIN
	if far < near + 2.0:
		far = near + 2.0
	var hazards: Array[Dictionary] = boss.attacks.obstacles(d)
	var rows: int = maxi(ceili(float(n_coins) / n), 1)
	var lanes: Array[int] = []
	for i: int in n_coins:
		if lanes.is_empty():
			for l: int in n:
				lanes.append(l)
			for k: int in range(lanes.size() - 1, 0, -1):
				var j: int = boss.rng.randi_range(0, k)
				var t: int = lanes[k]
				lanes[k] = lanes[j]
				lanes[j] = t
		var lane: int = lanes.pop_back()
		var row: int = i / n
		var at: float = lerpf(near, far, (float(row) + boss.rng.randf_range(0.2, 0.8)) / rows)
		lane = _free_lane(lane, at, hazards, n)
		var value: int = COIN_RICH if tuning.fountain_rich_every > 0 and (i + 1) % tuning.fountain_rich_every == 0 else COIN_FIVE
		var t0: float = FOUNTAIN_SPREAD * float(i) / maxf(n_coins - 1, 1)
		var coin := {"value": value, "lane": lane, "at": at, "from": from, "t": -t0, "flight": tuning.fountain_flight}
		_coin_look(coin)
		coins.append(coin)
	boss.log_event(&"fountain", {"coins": n_coins, "near": near, "far": far})


## `lane`, or the nearest lane with nothing of an attack over `at`.
func _free_lane(lane: int, at: float, hazards: Array[Dictionary], n: int) -> int:
	for dist: int in n:
		for s: int in [1, -1]:
			var l: int = lane + s * dist
			if l < 0 or l >= n:
				continue
			var hit: bool = false
			for o: Dictionary in hazards:
				if int(o["lane"]) == l and float(o["from"]) - 1.5 <= at and float(o["to"]) + 1.5 >= at:
					hit = true
					break
			if not hit:
				return l
	return lane


func _update_coins(delta: float) -> void:
	for i: int in range(coins.size() - 1, -1, -1):
		var c: Dictionary = coins[i]
		c["t"] = float(c["t"]) + delta
		var t: float = float(c["t"])
		if t < 0.0:
			continue
		var k: float = clampf(t / maxf(float(c["flight"]), 0.05), 0.0, 1.0)
		var to: Vector3 = world.lane_point(int(c["lane"]), float(c["at"]), 0.7)
		var from: Vector3 = c["from"]
		var pos: Vector3 = from.lerp(to, k)
		pos.y += 7.0 * 4.0 * k * (1.0 - k)
		_place_coin(c, pos, t)
		if k >= 1.0:
			_hide_coin(c)
			coins.remove_at(i)
			world.credits.place([{"surface": "floor", "lane": int(c["lane"]), "at": float(c["at"]), "value": int(c["value"]),
				"height": 0.7}])
			placed += 1


## A flying coin in the credits' own look (CreditField's mesh and spinning material): one MultiMesh per
## denomination, an instance per coin.
func _coin_look(c: Dictionary) -> void:
	var entry: Dictionary = _coin_mesh(CreditField.denomination(int(c["value"])))
	var mm: MultiMesh = entry["mm"]
	var free: Array = entry["free"]
	var idx: int
	if not free.is_empty():
		idx = free.pop_back()
	else:
		idx = mm.visible_instance_count
		if idx >= mm.instance_count:
			# Every instance in flight (more coins than fountain_count allows): the first one's.
			idx = 0
		else:
			mm.visible_instance_count = idx + 1
	c["mm"] = mm
	c["idx"] = idx
	c["free"] = free
	mm.set_instance_transform(idx, Transform3D(Basis().scaled(Vector3.ZERO), c["from"]))


## The flying coins' MultiMesh of denomination `value` ({mm, free: its instances free for a coin}), made
## the first time.
func _coin_mesh(value: int) -> Dictionary:
	if not _coin_meshes.has(value):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = CreditField.mesh_for(value)
		mm.instance_count = 64
		mm.visible_instance_count = 0
		var inst := MultiMeshInstance3D.new()
		inst.name = "Fountain%d" % value
		inst.multimesh = mm
		inst.material_override = CreditField.material_for(value)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		_coin_meshes[value] = {"mm": mm, "free": []}
	return _coin_meshes[value]


func _place_coin(c: Dictionary, pos: Vector3, t: float) -> void:
	var mm: MultiMesh = c["mm"]
	mm.set_instance_transform(int(c["idx"]), Transform3D(Basis(Vector3.UP, t * 9.0), pos))


func _hide_coin(c: Dictionary) -> void:
	var mm: MultiMesh = c.get("mm")
	if mm == null:
		return
	mm.set_instance_transform(int(c["idx"]), Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	(c["free"] as Array).append(int(c["idx"]))
	c["mm"] = null
