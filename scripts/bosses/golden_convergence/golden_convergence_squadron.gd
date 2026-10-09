class_name GoldenConvergenceSquadron
extends BossPart
## The Helidrone Strafe's squadron (GDD §10: "heli drones (the heli drone's model, never coloured red) come
## out of the cape, move and fire as one through all of the strafe's passes, and then leave. It's a single
## attack, not separate enemies"). Its drones are the heli drone's model (Drone.add_model, not hostile: the
## eye a cold white and the band unlit gold, never red), built once with the fight, MAX of them, hidden until
## a strafe brings them out; the strafe (GoldenConvergenceStrafe) says where each one is, which way it flies,
## what its guns aim at and whether they fire (set_drone), and this draws it: the rotors turning, the
## gatling spinning up and its muzzle flashing (warm white; steady with Reduced flashing), a gentle bob.
## DESIGN-TBD (docs/questions/e5d.md, E5d-a 3): the look without red (the eye a cold white, the band unlit
## gold) and its size (GoldenConvergenceTuning.drone_scale).
## A part of the boss that's no target and has no touch of its own (GDD §10: "weapons never target the
## squadron"; it only hurts through its fire, GoldenConvergenceFire): immune to weapons, no hitbox,
## is_obstacle.
## The pad rule (GDD §9.6: "stepping on any anti-grav pad hurls every drone on screen up into the ship's
## hull"; §10: "anti-grav pads destroy the whole squadron"): hurl() sends every drone out up, spinning, keeping
## pace with the runner, and each crashes (drone_crash, a burst) hurl_rise metres up or HURL_TIME later;
## `hurled_out` says when the last is down (E5d-c: the Refill Ship's chain reaction starts from here).

## Every drone is down: the squadron is gone.
signal hurled_out

const DroneScript: GDScript = preload("res://scripts/enemies/drone.gd")
## The most drones a squadron has (GDD §10: three on 5 or 6 lanes).
const MAX: int = 3
## Hurled by a pad: how fast it speeds up (m/s²), how fast it starts, and how long it takes at most.
const HURL_ACCEL: float = 45.0
const HURL_SPEED: float = 9.0
const HURL_TIME: float = 0.8
## The muzzle flash's warm white, and how fast it flickers while firing (steady with Reduced flashing).
const FLASH_COLOR := Color(1.0, 0.86, 0.6)
const FLASH_HZ: float = 22.0

enum Mode { HIDDEN, FLYING, DOWN }

var tuning: GoldenConvergenceTuning
## {node, pivot, rotors, gun, barrels, muzzle, flash, mode, firing, spin, aim, facing, rise, hurl_t, hurl_v,
## rel_ahead, start_y}
var rigs: Array[Dictionary] = []
## Metres a pad hurls a drone up before it crashes (E5d-c sets it for the Refill Ship's belly).
var hurl_rise: float = 6.0
## Drones crashed by a pad so far (tests).
var crashed: int = 0
var _t: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as GoldenConvergenceTuning
	if tuning == null:
		tuning = GoldenConvergenceTuning.new()
	display_name = "the helidrone squadron"
	is_obstacle = true
	immune_to_weapons = true
	var variant: StringName = world.skin.enemy_variant if world.skin != null else &"golden"
	var flash_mat: Material = GreyboxMaterials.glow(FLASH_COLOR, 4.0)
	for i: int in MAX:
		var node := Node3D.new()
		node.name = "Drone%d" % i
		node.top_level = true
		add_child(node)
		var parts: Dictionary = DroneScript.add_model(node, variant, tuning.drone_scale, false)
		var gun: Node3D = parts["gun"]
		var muzzle := Node3D.new()
		muzzle.position = Vector3(0.0, 0.0, -0.7)
		gun.add_child(muzzle)
		var flash: MeshInstance3D = GreyboxMaterials.add_box(gun, Vector3(0.0, 0.0, -0.8), Vector3(0.26, 0.26, 0.4), flash_mat)
		flash.visible = false
		rigs.append({"node": node, "pivot": parts["pivot"], "rotors": parts["rotors"], "gun": gun,
			"barrels": parts["barrels"], "muzzle": muzzle, "flash": flash, "mode": Mode.HIDDEN, "firing": false,
			"spin": 0.0, "aim": Vector3.ZERO, "facing": Vector3.BACK, "hurl_t": 0.0, "hurl_v": 0.0, "rel_ahead": 0.0,
			"start_y": 0.0, "phase": float(i) * 1.7})
		_hide(i)


## How many drones fly at this run's lane count (GoldenConvergenceTuning.squadron_size).
func size() -> int:
	return mini(GoldenConvergenceTuning.squadron_size(world.geo.lane_count), MAX)


## Puts drone `i` at world point `pos`, flying toward `facing` (its nose leads; tilted down by `pitch`
## radians), its guns aimed at world point `aim`, firing or not, its gatling spinning at `spin` (0-1).
func set_drone(i: int, pos: Vector3, facing: Vector3, aim: Vector3, firing: bool, spin: float, pitch: float = 0.0) -> void:
	var rig: Dictionary = rigs[i]
	if int(rig["mode"]) == Mode.DOWN:
		return
	var node: Node3D = rig["node"]
	if int(rig["mode"]) == Mode.HIDDEN:
		rig["mode"] = Mode.FLYING
		node.visible = true
	var bob: float = 0.0 if firing else sin(_t * 2.1 + float(rig["phase"])) * 0.12
	node.global_position = pos + Vector3(0.0, bob, 0.0)
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() > 0.0001:
		var want := Basis.looking_at(-flat.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -pitch)
		node.basis = node.basis.orthonormalized().slerp(want.orthonormalized(), 0.25)
	rig["aim"] = aim
	rig["firing"] = firing
	rig["spin"] = clampf(spin, 0.0, 1.0)
	var gun: Node3D = rig["gun"]
	if aim.distance_squared_to(gun.global_position) > 0.25:
		var up: Vector3 = Vector3.UP if absf((aim - gun.global_position).normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		gun.look_at(aim, up)


## Hides drone `i` (back in the cape).
func stow(i: int) -> void:
	if int(rigs[i]["mode"]) != Mode.DOWN:
		_hide(i)


## Hides every drone (a strafe over, a phase's end).
func stow_all() -> void:
	for i: int in rigs.size():
		_hide(i)


## The muzzle of drone `i` (world space): its tracers start here.
func muzzle_point(i: int) -> Vector3:
	return (rigs[i]["muzzle"] as Node3D).global_position


func drone_position(i: int) -> Vector3:
	return (rigs[i]["node"] as Node3D).global_position


## True if drone `i` is out (flying, not hidden and not down).
func flying(i: int) -> bool:
	return int(rigs[i]["mode"]) == Mode.FLYING


## How many drones are out.
func out_count() -> int:
	var n: int = 0
	for i: int in rigs.size():
		if flying(i):
			n += 1
	return n


## A pad hurls every drone that's out up, spinning, keeping pace with the runner, each crashing a moment
## later (GDD §9.6's rule; E5d-c's Refill Ship catches them). True if any was out.
func hurl() -> bool:
	var any: bool = false
	var d: float = world.player.distance
	for rig: Dictionary in rigs:
		if int(rig["mode"]) != Mode.FLYING:
			continue
		any = true
		var node: Node3D = rig["node"]
		rig["mode"] = Mode.DOWN
		rig["firing"] = false
		rig["hurl_t"] = 0.0
		rig["hurl_v"] = HURL_SPEED
		rig["rel_ahead"] = -node.global_position.z - d
		rig["start_y"] = node.global_position.y
		(rig["flash"] as Node3D).visible = false
		world.effects.burst(node.global_position, Color(1.0, 0.86, 0.6), 12, 0.5)
	return any


## True while a hurled drone is still on its way up.
func hurling() -> bool:
	for rig: Dictionary in rigs:
		if int(rig["mode"]) == Mode.DOWN and (rig["node"] as Node3D).visible:
			return true
	return false


func _tick(delta: float) -> void:
	_t += delta
	for i: int in rigs.size():
		var rig: Dictionary = rigs[i]
		match int(rig["mode"]):
			Mode.FLYING:
				_animate(rig, delta)
			Mode.DOWN:
				_update_hurl(i, delta)


func _animate(rig: Dictionary, delta: float) -> void:
	var rotors: Array = rig["rotors"]
	if rotors.size() >= 2:
		(rotors[0] as Node3D).rotate_y(30.0 * delta)
		(rotors[1] as Node3D).rotate_y(-30.0 * delta)
	var spin: float = float(rig["spin"])
	(rig["barrels"] as Node3D).rotate_z(spin * 40.0 * delta)
	var flash: MeshInstance3D = rig["flash"]
	if bool(rig["firing"]):
		# A flickering muzzle flash, or a steady one with Reduced flashing.
		flash.visible = Settings.flashing_reduced or fmod(_t * FLASH_HZ + float(rig["phase"]), 1.0) < 0.55
	else:
		flash.visible = false


func _update_hurl(i: int, delta: float) -> void:
	var rig: Dictionary = rigs[i]
	var node: Node3D = rig["node"]
	if not node.visible:
		return
	rig["hurl_t"] = float(rig["hurl_t"]) + delta
	rig["hurl_v"] = float(rig["hurl_v"]) + HURL_ACCEL * delta
	var y: float = node.global_position.y + float(rig["hurl_v"]) * delta
	var d: float = world.player.distance + float(rig["rel_ahead"])
	node.global_position = Vector3(node.global_position.x, y, TrackGeometry.world_z(d))
	var pivot: Node3D = rig["pivot"]
	pivot.rotate_y(16.0 * delta)
	pivot.rotation.x = minf(pivot.rotation.x + 3.0 * delta, 0.9)
	if y - float(rig["start_y"]) >= hurl_rise or float(rig["hurl_t"]) >= HURL_TIME:
		var at: Vector3 = node.global_position
		if encounter is GoldenConvergence:
			(encounter as GoldenConvergence).sound(&"drone_crash", (encounter as GoldenConvergence).sound_point(at))
		else:
			world.play_sfx_at(&"drone_crash", at)
		world.effects.burst(at, Color(1.0, 0.5, 0.15), 36, 1.1)
		world.effects.burst(at, Color(0.7, 0.75, 0.85), 16, 0.7)
		world.effects.shake(0.2, 0.25)
		_hide(i)
		rig["mode"] = Mode.DOWN
		crashed += 1
		if not hurling():
			hurled_out.emit()


## Back to the pool after a hurl (a new strafe brings them all out again).
func reset() -> void:
	for i: int in rigs.size():
		_hide(i)
		(rigs[i]["pivot"] as Node3D).rotation = Vector3.ZERO


func _hide(i: int) -> void:
	var rig: Dictionary = rigs[i]
	rig["mode"] = Mode.HIDDEN
	rig["firing"] = false
	rig["spin"] = 0.0
	var node: Node3D = rig["node"]
	node.visible = false
	node.global_position = Vector3(0.0, -300.0, 0.0)
	(rig["flash"] as Node3D).visible = false


## Never a target (GDD §10: "weapons never target the squadron").
func targetable() -> bool:
	return false


## The fight is won: the squadron is gone.
func _on_defeated(_cause: StringName) -> void:
	stow_all()
