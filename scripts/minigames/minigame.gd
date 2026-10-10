class_name MiniGame
extends Node3D
## A level that plays a mini-game (LevelConfig.minigame, MiniGameDef; the owner, October 10, 2026: the Beach's
## second level is a beach volleyball match, VolleyballMatch). It is a run like any level's, in the normal run world
## with the same controls, camera, HUD, pause and results: LevelRun asks the game for the level's track instead of
## the generator (plan_layout), builds the world on it, and the game joins the world (setup) between the player and
## the enemies, so it acts on the player's moves the frame they happen. The level ends as every level does, when the
## runner crosses the finish line at the end of the track. The game holds the runner meanwhile through
## Player.speed_override (walking up, standing still to play), and says what it paid and how well it went:
## RunResult.from_world takes payout() as the level's completion bonus, stars() as its stars and merges stats().
##
## To build one: a script extending MiniGame as the root of a scene in scenes/minigames/, its tuning in
## data/minigames/<id>_tuning.tres, a MiniGameDef in data/minigames/<id>.tres naming both, and the level's
## LevelConfig.minigame set to it. Override plan_layout, _start, payout, stars, stats; random choices come from
## `rng` (seeded from the def's id and the level's seed, so every attempt plays the same), time from the physics step.

## The world's meta key the running game is kept under (of()).
const META: StringName = &"minigame"

var def: MiniGameDef
var world: RunWorld
var context: RunContext
var rng := RandomNumberGenerator.new()


## The game a def's scene makes, or null (no def, not built, or a root that isn't a MiniGame).
static func create(p_def: MiniGameDef) -> MiniGame:
	if p_def == null or not p_def.is_built():
		return null
	var node: Node = (load(p_def.scene) as PackedScene).instantiate()
	var game := node as MiniGame
	if game == null:
		push_error("MiniGame: the root of %s doesn't extend MiniGame" % p_def.scene)
		node.free()
		return null
	game.def = p_def
	return game


## The game running in `p_world`, or null (a level without one, a boss fight).
static func of(p_world: Node) -> MiniGame:
	if p_world == null or not is_instance_valid(p_world) or not p_world.has_meta(META):
		return null
	var value: Variant = p_world.get_meta(META)
	if not is_instance_valid(value):
		return null
	return value as MiniGame


## The level's track for `p_context` (its config's lane count and run speed, its tuning). The default: a plain
## track as long as the level's duration at its speed, with nothing on it.
func plan_layout(p_context: RunContext) -> LevelLayout:
	var out := LevelLayout.new()
	out.lane_count = p_context.config.lane_count
	out.length = p_context.config.duration_seconds * p_context.config.movement_for(p_context.tuning).run_speed
	return out


## Joins the built world, right after the player, and starts the game (_start).
func setup(p_world: RunWorld, p_context: RunContext) -> void:
	world = p_world
	context = p_context
	name = "MiniGame"
	rng.seed = hash([String(def.id) if def != null else "", context.config.level_seed if context.config != null else 0])
	world.add_child(self)
	world.move_child(self, world.player.get_index() + 1)
	world.set_meta(META, self)
	_start()


## The credits the game paid (RunResult: the level's completion bonus on a finish).
func payout() -> int:
	return 0


## The level's stars for a finish (1–3), or 0 when it isn't finished.
func stars(completed: bool) -> int:
	return 3 if completed else 0


## The game's numbers for the results (merged into RunResult.stats); "minigame" holds its id.
func stats() -> Dictionary:
	return {"minigame": String(def.id) if def != null else ""}


## The hint catalog's trigger for this game (data/hints/hints.json, HintDirector): "minigame:<id>".
func hint_trigger() -> String:
	return "minigame:%s" % (String(def.id) if def != null else "")


## The tuning resource of the def, or null.
func def_tuning() -> Resource:
	return def.tuning if def != null else null


func _start() -> void:
	pass


func _exit_tree() -> void:
	if world != null and is_instance_valid(world) and world.has_meta(META) and world.get_meta(META) == self:
		world.remove_meta(META)
