class_name BossEncounter
extends Node3D
## A boss fight (GDD §10), played inside the normal run world so it plays like the runner: the same
## controls, camera, movement, HUD, power-ups, damage rules, pause, hints and death flow as a level.
## The root of a boss's scene (BossDef.scene) extends this class and runs the boss's own pattern
## through the hooks below; the framework does the rest:
## - the arena: the run's track, planned lap after lap by the generator (BossArena), so it keeps going
##   for as long as the fight lasts and is the same on every attempt;
## - health and phases from BossDef: a phase ends when weapons or weak-point stomps take its share of
##   the health; a single hit never skips a phase; the next phase begins with its intro (the boss can't
##   be hurt and doesn't attack) and then its pattern;
## - the checkpoint: reaching a phase marked `checkpoint` stores where a retry resumes
##   (RunContext.boss_resume, with the fight time and score so far);
## - the win: the time bonus and the defeat score go to the ScoreKeeper, the boss's parts are
##   defeated, and LevelRun ends the run (results, payout, stars from par times, the leaderboard);
## - events for other systems: phase_started / phase_ended, protection_broken (the player's armor or
##   shield broke; task B7's pickups use both), weak_point_hit, checkpoint_reached, defeated.
##
## Rules a boss script keeps (CLAUDE.md, GDD §10): input only through the player's named actions (the
## boss never reads input), hits only through hitboxes and projectiles (DamageRules decides), a visual
## and an audio warning before every attack, and no escalation: a pattern depends only on its phase
## (pace() and the phase's own numbers), never on how long the fight or the attempt has lasted, so it
## keeps cycling the same way until the player lands the hits. Random choices use `rng`, seeded from
## the boss and the arena, and time comes from the physics step, so every attempt plays out the same
## way for the same inputs.
##
## Hooks, all optional: _build_boss() (make parts with add_part, visuals), _on_phase_started(i) and
## _intro_tick(delta) (entrance and transitions), _on_pattern_started(i) and _pattern_tick(delta) (the
## pattern), _on_weak_point_hit(part, hazard), _on_phase_ended(i), _on_defeated() and
## _defeated_tick(delta). Helpers: add_part(), spawn_enemy() (normal enemies, e.g. a cyborg drop),
## arena.floor_clear(), pace(), phase(), is_final_phase(), player_distance(), log_event().

## A phase begins: its intro starts (the entrance for the first phase, the transition for later ones).
signal phase_started(index: int)
## A phase's share of health is gone.
signal phase_ended(index: int)
signal health_changed(health: float, max_health: float)
## A stomp landed on a weak point (before its damage applies).
signal weak_point_hit(part: BossPart, damage: float)
## A checkpoint phase began: a death from now on restarts the fight at that phase.
signal checkpoint_reached(index: int)
## The player's armor or shield broke during the fight (GDD §10: the Floating Head then drops an
## armor pickup 10–15 s later, at most once per phase; task B7).
signal protection_broken(item: StringName)
signal defeated

## INTRO: a phase's intro (the boss can't be hurt). FIGHT: its pattern. DEFEATED: the boss is beaten.
enum State { INTRO, FIGHT, DEFEATED }

## RunWorld metadata holding the world's encounter (BossEncounter.of).
const META: StringName = &"boss_encounter"
## Health shares closer than this count as equal.
const EPSILON: float = 0.0001

var def: BossDef
var world: RunWorld
var context: RunContext
var arena: BossArena
## Seeded from the boss and the arena: use it for every random choice.
var rng := RandomNumberGenerator.new()
var max_health: float = 1.0
var health: float = 1.0
var phase_index: int = 0
var state: State = State.INTRO
## Seconds in the current state (the intro, the pattern, or since the defeat).
var state_time: float = 0.0
## The boss's bodies (add_part), the first one being its main body.
var parts: Array[BossPart] = []
var weak_points_hit: int = 0
## Fight time carried over from the attempt that reached the checkpoint this one resumes at.
var carried_time: float = 0.0
## What happened, for tests and debugging: {t (fight time), event, phase, ...}.
var events: Array[Dictionary] = []

var _ends: PackedFloat32Array = PackedFloat32Array()
var _defeat_time: float = -1.0
var _spawned: int = 0


## A new encounter from a built boss's scene, or null (with an error) if its root isn't one.
static func create(p_def: BossDef) -> BossEncounter:
	if p_def == null or not p_def.is_built():
		return null
	var node: Node = (load(p_def.scene) as PackedScene).instantiate()
	var encounter := node as BossEncounter
	if encounter == null:
		push_error("BossEncounter: the root of %s doesn't extend BossEncounter" % p_def.scene)
		node.free()
	return encounter


## The encounter running in `p_world`, or null (a level).
static func of(p_world: Node) -> BossEncounter:
	if p_world == null or not is_instance_valid(p_world) or not p_world.has_meta(META):
		return null
	var value: Variant = p_world.get_meta(META)
	if not is_instance_valid(value):
		return null
	return value as BossEncounter


## Starts the fight in a built world: joins it (as its last child), runs the arena, builds the boss
## and begins its first phase, or the checkpoint phase a retry resumes at (context.boss_resume).
func setup(p_world: RunWorld, p_context: RunContext, p_arena: BossArena) -> void:
	world = p_world
	context = p_context
	def = context.boss
	arena = p_arena
	name = "Boss"
	rng.seed = hash([String(def.id), context.config.level_seed if context.config != null else 0])
	max_health = maxf(def.health, 1.0)
	health = max_health
	_ends = def.phase_ends()
	world.add_child(self)
	world.set_meta(META, self)
	if arena != null:
		arena.attach(world)
	world.player.item_used.connect(_on_item_used)
	var start: int = 0
	var resume: Dictionary = context.boss_resume
	if not resume.is_empty():
		start = clampi(int(resume.get("phase", 0)), 0, phase_count() - 1)
		health = phase_start_health(start)
		carried_time = maxf(float(resume.get("time", 0.0)), 0.0)
		var carried_score: int = int(resume.get("score", 0))
		if carried_score > 0:
			world.score.add_bonus(&"checkpoint", carried_score, "Checkpoint")
	_build_boss()
	_sync_parts()
	_begin_phase(start)


# --- State ----------------------------------------------------------------------------

func phase() -> BossPhase:
	return def.phase_list()[phase_index]


func phase_count() -> int:
	return def.phase_count()


func is_final_phase() -> bool:
	return phase_index >= phase_count() - 1


## The current phase's pace (GDD §10: a later phase may be faster). Boss scripts divide their timings
## by it; nothing else changes the pattern's speed.
func pace() -> float:
	return maxf(phase().pace, 0.05)


## True while the boss can be hurt: its pattern is running.
func is_vulnerable() -> bool:
	return state == State.FIGHT


func is_defeated() -> bool:
	return state == State.DEFEATED


func health_ratio() -> float:
	return clampf(health / max_health, 0.0, 1.0)


## The health shares where each phase but the last ends (the HUD's phase markers).
func phase_marks() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i: int in _ends.size() - 1:
		out.append(_ends[i])
	return out


## The health the phase at `index` starts with.
func phase_start_health(index: int) -> float:
	return max_health * (1.0 if index <= 0 else _ends[index - 1])


## Seconds of fight so far: the time carried from a checkpoint plus this attempt's (the player's run
## clock, which stops while the player is down), frozen at the defeat.
func fight_time() -> float:
	if _defeat_time >= 0.0:
		return _defeat_time
	return carried_time + (world.player.elapsed if world != null and world.player != null else 0.0)


## The player's distance along the track.
func player_distance() -> float:
	return world.player.distance


func lane_count() -> int:
	return world.geo.lane_count


## The damage one weak-point stomp deals in the current phase.
func stomp_damage() -> float:
	var share: float = (1.0 if phase_index == 0 else _ends[phase_index - 1]) - _ends[phase_index]
	return max_health * share / maxf(phase().stomps, 1)


## Numbers for the results screen: weak points hit, the phase reached, the time bonus.
func stats() -> Dictionary:
	return {
		"weak_points": weak_points_hit,
		"phase": phase_index + 1,
		"phases": phase_count(),
		"time_bonus": def.time_bonus(fight_time()) if is_defeated() else 0,
	}


# --- Damage ---------------------------------------------------------------------------

## Hurts the boss by `amount` (weapons through BossPart.take_damage, stomps through weak points, or a
## boss script's own causes). Only counts while its pattern runs (is_vulnerable). A single hit ends at
## most the current phase: it never carries the boss past the end of the next one. Returns the damage
## dealt.
func damage(amount: float, cause: StringName) -> float:
	if state != State.FIGHT or amount <= 0.0:
		return 0.0
	var before: float = health
	health = maxf(health - amount, _lowest_after_hit())
	var dealt: float = before - health
	if dealt <= 0.0:
		return 0.0
	health_changed.emit(health, max_health)
	_sync_parts()
	if health <= max_health * EPSILON:
		health = 0.0
		_defeat(cause)
	elif health <= max_health * (_ends[phase_index] + EPSILON):
		_end_phase(cause)
	return dealt


## A stomp landed on one of `part`'s weak points (BossPart). It scores, switches that part's weak
## points off until the boss script shows them again, and deals the phase's stomp damage.
func stomp_weak_point(part: BossPart, hazard: Hazard) -> void:
	if state != State.FIGHT:
		return
	var amount: float = stomp_damage()
	weak_points_hit += 1
	world.score.stomps += 1
	world.score.add_bonus(&"weak_point", def.weak_point_score, "Weak point")
	part.set_weak_points_enabled(false)
	log_event(&"weak_point", {"damage": amount})
	weak_point_hit.emit(part, amount)
	_on_weak_point_hit(part, hazard)
	damage(amount, &"stomp")


# --- Helpers for boss scripts ----------------------------------------------------------

## Adds one of the boss's bodies: a BossPart subclass (its script), spawned through the enemy
## director so weapons and the damage rules treat it like any enemy. `params` reach it as
## spawn.params (with `encounter` set); it starts a little ahead of the player in the middle lane,
## and the boss script moves it from there.
func add_part(script: Script, params: Dictionary = {}) -> BossPart:
	var p: Dictionary = params.duplicate()
	p["encounter"] = self
	var entry := {"type": String(def.id), "script": script.resource_path,
		"at": player_distance() + 40.0, "lane": lane_count() / 2, "side": 0,
		"seed": hash([String(def.id), parts.size(), rng.seed]), "params": p}
	var part := world.director.spawn(entry) as BossPart
	if part == null:
		push_error("BossEncounter: %s isn't a BossPart" % script.resource_path)
		return null
	part.encounter = self
	part.sync_health()
	parts.append(part)
	return part


## Brings a normal enemy into play now (the Floating Head's cyborg drop, GDD §10): a layout entry
## for the director, with a seed from the fight's random stream so every attempt matches.
func spawn_enemy(type: String, at: float, lane: int, side: int = 0, params: Dictionary = {}) -> Enemy:
	_spawned += 1
	return world.director.spawn({"type": type, "at": at, "lane": lane, "side": side,
		"seed": hash([String(def.id), type, _spawned, rng.seed]), "params": params.duplicate(true)})


## Switches the weak points of every part on or off.
func set_weak_points_enabled(on: bool) -> void:
	for part: BossPart in parts:
		if is_instance_valid(part):
			part.set_weak_points_enabled(on)


## Adds an entry to `events` (for tests and the debug readout).
func log_event(event: StringName, extra: Dictionary = {}) -> void:
	var entry := {"t": fight_time(), "event": event, "phase": phase_index}
	entry.merge(extra)
	events.append(entry)


# --- Hooks (override in a boss script) --------------------------------------------------

## Once, before the first phase: make the parts (add_part) and anything else the boss needs.
func _build_boss() -> void:
	pass


## A phase's intro begins: the boss's entrance for the first phase, the transition for later ones.
func _on_phase_started(_index: int) -> void:
	pass


## Every physics frame of a phase's intro.
func _intro_tick(_delta: float) -> void:
	pass


## The phase's pattern begins (the boss can be hurt from now on).
func _on_pattern_started(_index: int) -> void:
	pass


## Every physics frame of the pattern, while the player is up (the pattern holds while they're down).
func _pattern_tick(_delta: float) -> void:
	pass


## A weak point was stomped; its damage applies right after this.
func _on_weak_point_hit(_part: BossPart, _hazard: Hazard) -> void:
	pass


## A phase's health is gone; the next phase's intro follows at once.
func _on_phase_ended(_index: int) -> void:
	pass


## The boss is beaten (its parts are defeated just before): the defeat's look and sound.
func _on_defeated() -> void:
	pass


## Every physics frame after the defeat, until the run ends.
func _defeated_tick(_delta: float) -> void:
	pass


# --- Internals -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null or world.player == null:
		return
	if arena != null:
		arena.update(world.player.distance)
	if state == State.DEFEATED:
		state_time += delta
		_defeated_tick(delta)
		return
	var player: Player = world.player
	if not player.alive or not player.running:
		return
	state_time += delta
	if state == State.INTRO:
		_intro_tick(delta)
		if state_time >= phase().intro_seconds:
			state = State.FIGHT
			state_time = 0.0
			log_event(&"pattern")
			_on_pattern_started(phase_index)
	else:
		_pattern_tick(delta)


func _begin_phase(index: int) -> void:
	phase_index = index
	state = State.INTRO
	state_time = 0.0
	set_weak_points_enabled(false)
	var p: BossPhase = phase()
	var resume: Dictionary = context.boss_resume
	if p.checkpoint and (resume.is_empty() or int(resume.get("phase", -1)) < index):
		context.boss_resume = {"phase": index, "time": fight_time(), "score": world.score.score}
		log_event(&"checkpoint")
		checkpoint_reached.emit(index)
	log_event(&"phase")
	phase_started.emit(index)
	_on_phase_started(index)


func _end_phase(_cause: StringName) -> void:
	var ended: int = phase_index
	log_event(&"phase_end")
	phase_ended.emit(ended)
	_on_phase_ended(ended)
	_begin_phase(mini(ended + 1, phase_count() - 1))


func _defeat(cause: StringName) -> void:
	state = State.DEFEATED
	state_time = 0.0
	_defeat_time = carried_time + world.player.elapsed
	set_weak_points_enabled(false)
	log_event(&"defeated", {"cause": cause})
	var bonus: int = def.time_bonus(_defeat_time)
	if bonus > 0:
		world.score.add_bonus(&"time", bonus, "Time bonus")
	world.score.add_bonus(&"boss", def.defeat_score, def.display_name)
	for part: BossPart in parts:
		if is_instance_valid(part) and part.alive:
			part.defeat(&"boss")
	defeated.emit()
	_on_defeated()


## The lowest health one hit may leave: the end of the phase after the current one (just short of
## it), so a hit ends at most the current phase and every phase gets played; 0 in the last phase.
func _lowest_after_hit() -> float:
	if phase_index >= phase_count() - 1:
		return 0.0
	return max_health * (_ends[phase_index + 1] + 2.0 * EPSILON)


func _sync_parts() -> void:
	for part: BossPart in parts:
		if is_instance_valid(part):
			part.sync_health()


func _on_item_used(item: StringName) -> void:
	if item == &"armor" or item == &"shield":
		log_event(&"protection_broken", {"item": item})
		protection_broken.emit(item)
