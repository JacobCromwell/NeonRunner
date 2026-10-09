class_name BeachWaterWatch
extends Node3D
## Watches for the runner going into the water of a stretch of the Beach's pools and makes the splash (the owner,
## October 9, 2026: "a fall makes a splash"). One goes in with each piece of a chunk's wall that carries the water
## plane (BeachSkin.wall_section and wall_gap, the left wall's), as MarketCitizen does for the Marketplace: it finds
## the RunWorld up the tree and reads the runner's own track distance and position, never touching its gameplay
## state in the other direction (CLAUDE.md principle 1: no new collision or gameplay).
## The runner enters the water when its height crosses `water_y` going down: the water plane is the only thing
## under the street there (a floor or a floor cut's hole, never a floor), so a crossing is always a fall into a
## pool. The grapple hook fires at MovementTuning.pit_depth, above the water (BeachSkin.pool_depth is deeper by
## test), so a grappled runner never reaches it and never splashes.
## What falls after the runner (an Octodog baited into a gap, the Enforcer's wreck) doesn't splash: visual only for
## the runner (docs/OPEN_QUESTIONS.md, item 525).

const SPLASH_SOUND: StringName = &"splash"

## The track distances [start, end) this watch covers, the water's height and half the street's width.
var start: float = 0.0
var end: float = 0.0
var water_y: float = -0.45
var half_width: float = 6.0
## How many splashes it has made (for tests).
var splashes: int = 0
var _prev_y: float = INF
var _world: WeakRef


func setup(p_start: float, p_end: float, p_water_y: float, p_half_width: float) -> void:
	start = p_start
	end = p_end
	water_y = p_water_y
	half_width = p_half_width
	name = "BeachWaterWatch"
	process_physics_priority = 10


func _physics_process(_delta: float) -> void:
	var world: RunWorld = _find_world()
	if world == null or world.player == null:
		return
	observe(world.player.global_position, world.player_distance())


## One look at the runner (its world position and its track distance): true, and a splash on the water at its
## x and z, when its height has just crossed the water going down inside this piece of the street.
func observe(pos: Vector3, distance: float) -> bool:
	var crossed: bool = not is_inf(_prev_y) and _prev_y > water_y and pos.y <= water_y
	_prev_y = pos.y
	if not crossed or distance < start or distance >= end or absf(pos.x) > half_width + 0.5:
		return false
	var splash := BeachSplash.new()
	add_child(splash)
	splash.global_position = Vector3(pos.x, water_y, pos.z)
	splashes += 1
	var world: RunWorld = _find_world()
	if world != null:
		world.play_sfx_at(SPLASH_SOUND, splash.global_position)
	return true


func _find_world() -> RunWorld:
	if _world != null:
		var w: Object = _world.get_ref()
		if w != null:
			return w as RunWorld
	var n: Node = get_parent()
	while n != null and not (n is RunWorld):
		n = n.get_parent()
	if n != null:
		_world = weakref(n)
	return n as RunWorld
