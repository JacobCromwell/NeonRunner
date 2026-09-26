class_name EnemyDirector
extends Node3D
## Creates enemies from the layout as the player approaches and retires them when they're done.
## An enemy type is found by name, so adding one never touches a shared registry:
##   res://scripts/enemies/<type>.gd      the Enemy subclass (required)
##   res://data/enemies/<type>.tres       its EnemyTuning (optional)
## A layout entry {type, at, lane, side, seed, params} is spawned when the player comes within the
## type's spawn_lead of `at`.

const SCRIPTS_DIR: String = "res://scripts/enemies"
const TUNING_DIR: String = "res://data/enemies"
const DEFAULT_LEAD: float = 110.0

signal enemy_spawned(enemy: Enemy)
signal enemy_defeated(enemy: Enemy, cause: StringName)

var world: RunWorld
## Enemies currently in play.
var active: Array[Enemy] = []

var _pending: Array[Dictionary] = []
var _next: int = 0
static var _scripts: Dictionary = {}
static var _tunings: Dictionary = {}
static var _warned: Dictionary = {}


func setup(p_world: RunWorld) -> void:
	world = p_world
	for child: Node in get_children():
		child.queue_free()
	active.clear()
	_pending.clear()
	_next = 0
	for entry: Dictionary in world.layout.enemies:
		var e: Dictionary = entry.duplicate()
		e["spawn_at"] = float(entry["at"]) - lead_for(String(entry["type"]))
		_pending.append(e)
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["spawn_at"] < b["spawn_at"])


## Spawns what the player has come close to and retires enemies that are done. RunWorld calls this
## every physics frame.
func update(player_distance: float) -> void:
	while _next < _pending.size() and player_distance >= float(_pending[_next]["spawn_at"]):
		spawn(_pending[_next])
		_next += 1
	for i: int in range(active.size() - 1, -1, -1):
		var e: Enemy = active[i]
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			active.remove_at(i)
		elif e.alive and e.should_retire():
			active.remove_at(i)
			e.retire()


## Creates one enemy from a layout entry now (tests call this directly). Null if the type has no script.
func spawn(entry: Dictionary) -> Enemy:
	var type: String = String(entry.get("type", ""))
	# An entry may name its script directly (tests, one-off set pieces).
	var script: GDScript = load(entry["script"]) as GDScript if entry.has("script") else script_for(type)
	if script == null:
		return null
	var enemy := script.new() as Enemy
	if enemy == null:
		push_warning("EnemyDirector: %s.gd doesn't extend Enemy" % type)
		return null
	enemy.type_id = StringName(type)
	var tuning: Resource = tuning_for(type)
	if tuning is EnemyTuning:
		enemy.score_value = (tuning as EnemyTuning).score_value
		enemy.max_health = (tuning as EnemyTuning).health_at(world.config.enemy_scaling if world.config != null else 0.0)
	add_child(enemy)
	enemy.setup(world, entry, tuning)
	enemy.defeated.connect(_on_defeated)
	active.append(enemy)
	enemy_spawned.emit(enemy)
	return enemy


## Every living enemy that auto-fire may target, nearest first (GDD §8: the weapon fires at the
## nearest valid target; hosts and weapon-immune enemies are never targeted).
func targets_ahead(from: Vector3, max_distance: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in active:
		if not is_instance_valid(e) or not e.targetable():
			continue
		var ahead: float = from.z - e.aim_point().z
		if ahead < -1.0 or ahead > max_distance:
			continue
		out.append(e)
	out.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.aim_point().distance_squared_to(from) < b.aim_point().distance_squared_to(from))
	return out


func count_alive(type: StringName = &"") -> int:
	var n: int = 0
	for e: Enemy in active:
		if is_instance_valid(e) and e.alive and (type == &"" or e.type_id == type):
			n += 1
	return n


func _on_defeated(enemy: Enemy, cause: StringName) -> void:
	enemy_defeated.emit(enemy, cause)


static func script_for(type: String) -> GDScript:
	if _scripts.has(type):
		return _scripts[type]
	var path: String = SCRIPTS_DIR.path_join(type + ".gd")
	var script: GDScript = null
	if ResourceLoader.exists(path):
		script = load(path) as GDScript
	elif not _warned.has(type):
		_warned[type] = true
		push_warning("EnemyDirector: no script for enemy type '%s' (%s)" % [type, path])
	_scripts[type] = script
	return script


static func tuning_for(type: String) -> Resource:
	if _tunings.has(type):
		return _tunings[type]
	var path: String = TUNING_DIR.path_join(type + ".tres")
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	_tunings[type] = res
	return res


static func lead_for(type: String) -> float:
	var t: Resource = tuning_for(type)
	return (t as EnemyTuning).spawn_lead if t is EnemyTuning else DEFAULT_LEAD
