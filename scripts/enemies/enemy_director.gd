class_name EnemyDirector
extends Node3D
## Creates enemies from the layout as the player approaches and retires them when they're done.
## An enemy type is found by name, so adding one never touches a shared registry:
##   res://scripts/enemies/<type>.gd      the Enemy subclass (required)
##   res://data/enemies/<type>.tres       its EnemyTuning (optional)
## A layout entry {type, at, lane, side, seed, params} is spawned when the player comes within the
## type's spawn_lead of `at`.
##
## Big attacks take turns (GDD §9; docs/ARCHITECTURE.md, Enemies): an enemy asks
## major_attack_blocked() before its big attack's warning starts and waits (pacing, following) while
## the answer is true; its attack is on while it reports Enemy.is_major_attack_active(), and the
## attack's shots hold its turn until they've passed the player (note_attack_shot).

const SCRIPTS_DIR: String = "res://scripts/enemies"
const TUNING_DIR: String = "res://data/enemies"
const DEFAULT_LEAD: float = 110.0
## A big attack's shot holds its turn this long after it reaches the player (by then it's behind
## them, whatever small change of speed they made meanwhile).
const SHOT_PASS_MARGIN: float = 0.2

## Why an enemy's big attack is held: not at all, GDD §9.7's exclusive rule, or taking turns.
enum Hold { NONE, EXCLUSIVE, TURN }

signal enemy_spawned(enemy: Enemy)
signal enemy_defeated(enemy: Enemy, cause: StringName)

var world: RunWorld
## Enemies currently in play.
var active: Array[Enemy] = []

var _pending: Array[Dictionary] = []
var _next: int = 0
## Physics frames since setup (update() counts them): when each enemy last asked for its turn.
var _frame: int = 0
## Each enemy's last major_attack_blocked() call, by instance id: {frame, hold, since_frame, since}
## (since: when its current wait began, as a frame and a level time).
var _asks: Dictionary = {}
## Per type: the level time until which a big attack's shots are still on their way to the player.
var _shots_until: Dictionary = {}
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
	_frame = 0
	_asks.clear()
	_shots_until.clear()
	for entry: Dictionary in world.layout.enemies:
		var e: Dictionary = entry.duplicate()
		e["spawn_at"] = float(entry["at"]) - lead_for(String(entry["type"]))
		_pending.append(e)
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["spawn_at"] < b["spawn_at"])


## Spawns what the player has come close to and retires enemies that are done. RunWorld calls this
## every physics frame.
func update(player_distance: float) -> void:
	_frame += 1
	for id: int in _asks.keys():
		if int(_asks[id]["frame"]) < _frame - 2:
			_asks.erase(id)
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


## True if `enemy` must hold off its big attack right now. An enemy asks just before its attack's
## warning would start, once everything else about the attack is ready, and every frame after that
## until the answer is false; meanwhile it goes on as it was (pacing, following). A warning that has
## started always finishes with its attack: nothing here stops an attack that is on. Two rules:
## - GDD §9.7, always: an exclusive major attack (Enemy.exclusive_major_attack) and those of the types
##   it names (Enemy.exclusive_of) never overlap: the Bad Dream's chase and the Octodog's charge
##   sequences and drone barrages.
## - GDD §9, while big attacks take turns (GameRules.big_attacks_take_turns): no big attack starts
##   while one of another type is on (Enemy.is_major_attack_active) or its shots are still on their
##   way to the player (note_attack_shot). An enemy whose own attack is already on carries on (the
##   Bad Dream's next slash in its chase). Otherwise, of the enemies of different types waiting for
##   their turn, the one that has waited longest goes first (then the one spawned first), so no enemy
##   is kept waiting for ever by others that keep asking. Types space their own attacks themselves
##   (one drone barrage at a time, one Octodog or hover truck at a time).
func major_attack_blocked(enemy: Enemy) -> bool:
	var hold: Hold = _hold_for(enemy)
	if big_attacks_take_turns():
		_note_ask(enemy, hold)
	return hold != Hold.NONE


## GameRules.big_attacks_take_turns for this run (on when the run has no rules).
func big_attacks_take_turns() -> bool:
	return world == null or world.rules == null or world.rules.big_attacks_take_turns


## True if `enemy` asked for its turn this frame or the last and was held for another type's big
## attack (not by GDD §9.7's exclusive rule): an enemy that may only attack within a window (the
## Octodog's planned charges) moves the window on while it waits.
func held_for_turn(enemy: Enemy) -> bool:
	var rec: Dictionary = _asks.get(enemy.get_instance_id(), {})
	return _waiting(rec) and int(rec["hold"]) == Hold.TURN


## Seconds `enemy` has been waiting to start its big attack (0 when it isn't waiting): the delay
## turn-taking adds (tests and tools/measure read it).
func turn_wait(enemy: Enemy) -> float:
	var rec: Dictionary = _asks.get(enemy.get_instance_id(), {})
	if not _waiting(rec) or world == null:
		return 0.0
	return maxf(world.level_time() - float(rec["since"]), 0.0)


## A shot of `enemy`'s big attack reaches the player in `reach_seconds`: while big attacks take
## turns, the attack's turn lasts until the shot has passed them (SHOT_PASS_MARGIN).
func note_attack_shot(enemy: Enemy, reach_seconds: float) -> void:
	if world == null:
		return
	var until: float = world.level_time() + maxf(reach_seconds, 0.0) + SHOT_PASS_MARGIN
	_shots_until[enemy.type_id] = maxf(float(_shots_until.get(enemy.type_id, -INF)), until)


## True while shots of a big attack of `type` are still on their way to the player.
func shots_on_their_way(type: StringName) -> bool:
	return world != null and float(_shots_until.get(type, -INF)) > world.level_time()


func _hold_for(enemy: Enemy) -> Hold:
	for e: Enemy in active:
		if e == enemy or not _in_play(e) or not e.is_major_attack_active():
			continue
		if _excludes(enemy, e) or _excludes(e, enemy):
			return Hold.EXCLUSIVE
	if not big_attacks_take_turns():
		return Hold.NONE
	for type: StringName in _shots_until:
		if type != enemy.type_id and shots_on_their_way(type):
			return Hold.TURN
	for e: Enemy in active:
		if e != enemy and e.type_id != enemy.type_id and _in_play(e) and e.is_major_attack_active():
			return Hold.TURN
	if enemy.is_major_attack_active():
		return Hold.NONE
	# Nothing is on: an enemy of another type that has been waiting longer goes first.
	var mine: Dictionary = _asks.get(enemy.get_instance_id(), {})
	var my_since: int = int(mine["since_frame"]) if _waiting(mine) else _frame
	var my_index: int = active.find(enemy)
	for i: int in active.size():
		var e: Enemy = active[i]
		if e == enemy or e.type_id == enemy.type_id or not _in_play(e):
			continue
		var rec: Dictionary = _asks.get(e.get_instance_id(), {})
		if not _waiting(rec):
			continue
		var since: int = int(rec["since_frame"])
		if since < my_since or (since == my_since and my_index >= 0 and i < my_index):
			return Hold.TURN
	return Hold.NONE


func _note_ask(enemy: Enemy, hold: Hold) -> void:
	var id: int = enemy.get_instance_id()
	var rec: Dictionary = _asks.get(id, {})
	if hold == Hold.NONE or not _waiting(rec):
		rec = {"since_frame": _frame, "since": world.level_time() if world != null else 0.0}
	rec["frame"] = _frame
	rec["hold"] = hold
	_asks[id] = rec


## An ask record of an enemy that is waiting for its turn: held when it asked, this frame or the last.
func _waiting(rec: Dictionary) -> bool:
	return not rec.is_empty() and int(rec["hold"]) != Hold.NONE and int(rec["frame"]) >= _frame - 1


## True if `a`'s exclusive major attack keeps `b`'s apart (GDD §9.7).
static func _excludes(a: Enemy, b: Enemy) -> bool:
	return a.exclusive_major_attack and (a.exclusive_of.is_empty() or a.exclusive_of.has(b.type_id)
		or a.type_id == b.type_id)


static func _in_play(e: Enemy) -> bool:
	return is_instance_valid(e) and e.alive


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
