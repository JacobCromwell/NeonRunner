class_name BossEncounter
extends Node3D
## A boss fight (GDD §10), played inside the normal run world so it plays like the runner: the same
## controls, camera, movement, HUD, power-ups, damage rules, pause, hints and death flow as a level.
## The root of a boss's scene (BossDef.scene) extends this class and runs the boss's own pattern
## through the hooks below; the framework does the rest:
## - the arena: the run's track, planned lap after lap by the generator (BossArena), so it keeps going
##   for as long as the fight lasts and is the same on every attempt; the boss adds track pieces
##   (arena.add_pieces) and props within sight (props: fences, blocks, pads, ceilings, a wall taken
##   away, floor warnings);
## - health and phases from BossDef: a phase ends when weapons or big hits (weak-point stomps, EMPs,
##   parts destroyed: hit_damage) take its share; a single hit never skips a phase; the next phase
##   begins with its intro (the boss can't be hurt and doesn't attack) and then its pattern; weapons
##   stop counting at the boss's weapon cap;
## - the checkpoint: reaching a phase marked `checkpoint` stores where a retry resumes
##   (RunContext.boss_resume, with the fight time, score and weapon damage so far);
## - the standard armor rule (GDD §10): armor_pickup_due at the start of the final phase and a while
##   after the player's armor or shield breaks, at most once per phase (with BossDef.
##   armor_when_unprotected, a phase begun with neither counts as a break), and an armor pickup on the
##   floor ahead each time (_on_armor_pickup_due; the run's PickupField places it fairly); a boss
##   script can offer other pickups too (offer_pickup: GDD §10's floor that spawns an armor, shield or
##   grapple pickup), and none comes after the fight;
## - the win: the time bonus and the defeat score go to the ScoreKeeper, the boss's parts are
##   defeated, and LevelRun ends the run (results, payout, stars from par times, the leaderboard) once
##   the defeat has played out (victory_over: at once, unless the boss's defeat plays out on the
##   track);
## - events for other systems: phase_started / phase_ended, protection_broken, armor_pickup_due,
##   weak_point_hit, checkpoint_reached, health_changed, defeated.
##
## Rules a boss script keeps (CLAUDE.md, GDD §10): input only through the player's named actions (the
## boss never reads input), hits only through hitboxes and projectiles (DamageRules decides), a visual
## and an audio warning before every attack, and no escalation: a pattern depends only on its phase
## (pace() and the phase's own numbers), never on how long the fight or the attempt has lasted, so it
## keeps cycling the same way until the player lands the hits. Random choices use `rng`, seeded from
## the boss and the arena, and time comes from the physics step, so every attempt plays out the same
## way for the same inputs. The encounter node stays at the world origin; its parts move.
##
## Hooks, all optional: _plan_lap(lap, index, arena) (the boss's own pieces on each lap, before the
## fight), _build_boss() (make parts with add_part, visuals), _on_phase_started(i) and _intro_tick(delta)
## (entrance and transitions), _on_pattern_started(i) and _pattern_tick(delta) (the pattern),
## _on_weak_point_hit(part, hazard), _on_part_defeated(part, cause), _on_part_emp(part, center, radius),
## _on_phase_ended(i), _on_defeated(), _defeated_tick(delta), victory_over() (when a defeat that plays
## out on the track is over), victory_riff() (false for a defeat that ends in silence) and
## _on_armor_pickup_due(reason) (where the armor rule's pickup goes).
## Helpers: add_part(), spawn_enemy() (normal enemies: a cyborg drop, a
## Buzz Overdrive onto the roof), offer_pickup() (an armor, shield or grapple pickup on the floor),
## damage() (a boss's own causes: a cluster shocked by a fence, an EMP), hit_damage(),
## set_light_level() and set_scenery_light(), arena queries (floor_clear, live_fence_between,
## hole_between), pace(), phase(), is_final_phase(), player_distance(), log_event().

## A phase begins: its intro starts (the entrance for the first phase, the transition for later ones).
signal phase_started(index: int)
## A phase's share of health is gone.
signal phase_ended(index: int)
signal health_changed(health: float, max_health: float)
## A stomp landed on a weak point (before its damage applies).
signal weak_point_hit(part: BossPart, damage: float)
## A checkpoint phase began: a death from now on restarts the fight at that phase.
signal checkpoint_reached(index: int)
## The player's armor or shield broke during the fight.
signal protection_broken(item: StringName)
## GDD §10's standard armor rule says an armor pickup appears now: `reason` is &"final_phase" (the
## final phase began), &"protection_broken" (BossDef.armor_delay_min–max seconds after a break, at
## most armor_pickups_per_phase per phase) or &"unprotected" (as long after a phase began with the
## player holding no armor and no shield, with BossDef.armor_when_unprotected; counted like a break).
## The encounter then offers it (_on_armor_pickup_due), and the run's PickupField puts it on the floor
## ahead of the player.
signal armor_pickup_due(reason: StringName)
signal defeated
## Legacy encounter cue (a way onto its head). HintDirector no longer listens during play:
## catalog entries for this boss are presented on the level intro instead.
signal hint_due(key: String)

## INTRO: a phase's intro (the boss can't be hurt). FIGHT: its pattern. DEFEATED: the boss is beaten.
enum State { INTRO, FIGHT, DEFEATED }

## RunWorld metadata holding the world's encounter (BossEncounter.of).
const META: StringName = &"boss_encounter"
## Health shares closer than this count as equal.
const EPSILON: float = 0.0001
## GDD §10 (Sleep Taker): the arena gets darker, but never pitch black.
const MIN_LIGHT_LEVEL: float = 0.3

var def: BossDef
var world: RunWorld
var context: RunContext
var arena: BossArena
var props: BossProps
## Seeded from the boss and the arena: use it for every random choice of the pattern.
var rng := RandomNumberGenerator.new()
var max_health: float = 1.0
var health: float = 1.0
var phase_index: int = 0
var state: State = State.INTRO
## Seconds in the current state (the intro, the pattern, or since the defeat).
var state_time: float = 0.0
## The boss's parts (add_part), the first one being its body.
var parts: Array[BossPart] = []
var weak_points_hit: int = 0
## Big hits (anything but weapons) landed in the current phase: counted while weapons can't end a phase
## (BossDef.weapons_can_end_phase off), so its last one ends it (hit_damage).
var phase_hits: int = 0
## Weapon damage dealt over the fight (with what a checkpoint carried), against BossDef.weapon_share_cap.
var weapon_damage: float = 0.0
## Fight time carried over from the attempt that reached the checkpoint this one resumes at.
var carried_time: float = 0.0
## What happened, for tests and debugging: {t (fight time), event, phase, ...}.
var events: Array[Dictionary] = []

var _ends: PackedFloat32Array = PackedFloat32Array()
var _defeat_time: float = -1.0
var _spawned: int = 0
## Armor pickups waiting for their moment: {at (fight time), phase}; breaks answered per phase.
var _armor_rng := RandomNumberGenerator.new()
var _armor_due: Array[Dictionary] = []
var _armor_breaks: Dictionary = {}
## The arena's light (set_light_level): the level now, the target, the fade speed, and the lights'
## own values to scale.
var _light: float = 1.0
var _light_target: float = 1.0
var _light_speed: float = 0.0
var _light_base: Dictionary = {}
## The scenery light it set last (scenery_light()).
var _scenery_set: float = 1.0


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


## Plans the fight's arena for `p_context` (its boss, its config with the lane count and difficulty,
## its tuning), shaped by this boss's _plan_lap. LevelRun builds the world from arena.layout.
func plan_arena(p_context: RunContext) -> BossArena:
	def = p_context.boss
	return BossArena.plan(def, p_context.config, p_context.tuning, self)


## Starts the fight in a built world: joins it (after the player, before the enemies, so the pattern
## moves the boss's parts before they act), runs the arena, builds the boss and begins its first
## phase, or the checkpoint phase a retry resumes at (context.boss_resume).
func setup(p_world: RunWorld, p_context: RunContext, p_arena: BossArena) -> void:
	world = p_world
	context = p_context
	def = context.boss
	arena = p_arena
	name = "Boss"
	# Seeded by its BossDef.rng_key() (its id, or the one it had before a move), so every attempt matches.
	rng.seed = hash([def.rng_key(), context.config.level_seed if context.config != null else 0])
	_armor_rng.seed = hash([def.rng_key(), "armor"])
	max_health = maxf(def.health, 1.0)
	health = max_health
	_ends = def.phase_ends()
	world.add_child(self)
	world.move_child(self, world.director.get_index())
	world.set_meta(META, self)
	if arena != null:
		arena.attach(world)
	props = BossProps.new()
	props.name = "Props"
	add_child(props)
	props.setup(world)
	world.director.warm_up_entries(warm_enemies())
	world.player.item_used.connect(_on_item_used)
	var start: int = 0
	var resume: Dictionary = context.boss_resume
	if not resume.is_empty():
		start = clampi(int(resume.get("phase", 0)), 0, phase_count() - 1)
		health = phase_start_health(start)
		carried_time = maxf(float(resume.get("time", 0.0)), 0.0)
		weapon_damage = maxf(float(resume.get("weapon_damage", 0.0)), 0.0)
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


## True while weapon hits still count (below BossDef.weapon_share_cap and, if weapons may not end a
## phase, above weapon_floor()).
func weapons_can_hurt() -> bool:
	var under_cap: bool = weapon_damage < max_health * def.weapon_share_cap - EPSILON * max_health
	if def.weapons_can_end_phase:
		return under_cap
	return under_cap and health > weapon_floor() + EPSILON * max_health


## The lowest health weapon hits may take the boss to now: 0 if weapons may end a phase
## (BossDef.weapons_can_end_phase), else just above where the current phase ends (the last one's end
## too: the fight), so only its big hits end it.
func weapon_floor() -> float:
	if def.weapons_can_end_phase:
		return 0.0
	return max_health * (_ends[phase_index] + 3.0 * EPSILON)


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


## The damage one big hit deals in the current phase (a weak-point stomp, an EMP, a cluster destroyed):
## the phase's share of health over its BossPhase.hits. While weapons can't end a phase
## (BossDef.weapons_can_end_phase off), an equal part of what's left of the phase for each hit still to
## land, so its BossPhase.hits big hits always end it, however much weapons chipped it, and nothing
## carries into the next phase (DESIGN-TBD, docs/questions/e5b.md).
func hit_damage() -> float:
	if not def.weapons_can_end_phase:
		var left: float = maxf(health - max_health * _ends[phase_index], 0.0)
		return left / maxf(phase().hits - phase_hits, 1)
	var share: float = (1.0 if phase_index == 0 else _ends[phase_index - 1]) - _ends[phase_index]
	return max_health * share / maxf(phase().hits, 1)


## Numbers for the results screen: weak points hit, the phase reached, the time bonus.
func stats() -> Dictionary:
	return {
		"weak_points": weak_points_hit,
		"phase": phase_index + 1,
		"phases": phase_count(),
		"time_bonus": def.time_bonus(fight_time()) if is_defeated() else 0,
	}


# --- Damage ---------------------------------------------------------------------------

## Hurts the boss by `amount`: weapons (BossPart.take_damage, cause &"weapon", up to the boss's weapon
## cap), stomps (stomp_weak_point), or a boss script's own causes (&"emp", &"fence", &"gap", ...). Only
## counts while its pattern runs (is_vulnerable). A single hit ends at most the current phase: it never
## takes the boss past the end of the next one. Returns the damage dealt.
func damage(amount: float, cause: StringName) -> float:
	if state != State.FIGHT or amount <= 0.0:
		return 0.0
	if cause == &"weapon":
		amount = minf(amount, max_health * def.weapon_share_cap - weapon_damage)
		if not def.weapons_can_end_phase:
			amount = minf(amount, health - weapon_floor())
		if amount <= 0.0:
			return 0.0
	var before: float = health
	health = maxf(health - amount, _lowest_after_hit())
	var counted: bool = cause != &"weapon" and not def.weapons_can_end_phase
	if counted:
		# Counted big hits (hit_damage): only the phase's last one ends it, exactly at its end.
		phase_hits += 1
		var end: float = max_health * _ends[phase_index]
		health = end if phase_hits >= phase().hits else maxf(health, end + max_health * EPSILON * 2.0)
	var dealt: float = before - health
	if dealt <= 0.0 and not counted:
		return 0.0
	if cause == &"weapon":
		weapon_damage += dealt
	health_changed.emit(health, max_health)
	_sync_parts()
	if counted and phase_hits < phase().hits:
		return dealt
	if health <= max_health * EPSILON:
		health = 0.0
		_defeat(cause)
	elif health <= max_health * (_ends[phase_index] + EPSILON):
		_end_phase(cause)
	return dealt


## A stomp landed on one of `part`'s weak points (BossPart). It scores, switches that part's weak
## points off until the boss script shows them again, and deals the phase's hit damage.
func stomp_weak_point(part: BossPart, hazard: Hazard) -> void:
	if state != State.FIGHT:
		return
	var amount: float = hit_damage()
	weak_points_hit += 1
	world.score.stomps += 1
	world.score.add_bonus(&"weak_point", def.weak_point_score, "Weak point")
	part.set_weak_points_enabled(false)
	log_event(&"weak_point", {"damage": amount})
	weak_point_hit.emit(part, amount)
	_on_weak_point_hit(part, hazard)
	damage(amount, &"stomp")


## A part with health of its own was defeated (BossPart; a swarm cluster). The boss script decides
## what it means (_on_part_defeated: hurt the boss by hit_damage(), move the phase on).
func part_defeated(part: BossPart, cause: StringName) -> void:
	log_event(&"part_defeated", {"cause": cause})
	_on_part_defeated(part, cause)


## An EMP reached one of the boss's parts (a fence generator destroyed nearby, RunWorld.emp). The boss
## script decides what it does (_on_part_emp: Sleep Taker loses a chunk).
func part_hit_by_emp(part: BossPart, center: Vector3, radius: float) -> void:
	log_event(&"emp")
	_on_part_emp(part, center, radius)


# --- Helpers for boss scripts ----------------------------------------------------------

## Adds one of the boss's parts: a BossPart subclass (its script), spawned through the enemy director
## so weapons and the damage rules treat it like any enemy. `params` reach it as spawn.params (with
## `encounter` set); it starts a little ahead of the player in the middle lane, and the boss script
## moves it from there.
func add_part(script: Script, params: Dictionary = {}) -> BossPart:
	var p: Dictionary = params.duplicate()
	p["encounter"] = self
	var entry := {"type": String(def.id), "script": script.resource_path,
		"at": player_distance() + 40.0, "lane": lane_count() / 2, "side": 0,
		"seed": hash([def.rng_key(), parts.size(), rng.seed]), "params": p}
	var part := world.director.spawn(entry) as BossPart
	if part == null:
		push_error("BossEncounter: %s isn't a BossPart" % script.resource_path)
		return null
	part.encounter = self
	part.sync_health()
	parts.append(part)
	return part


## The normal enemies this fight brings into play itself (spawn_enemy, add_pieces), as layout-like
## entries the director readies during the fight's load (EnemyDirector.warm_up_entries, task PERF1): a
## type's first spawn would otherwise load its scripts and build its look in that frame. A boss script that
## brings any overrides this; the default brings none.
func warm_enemies() -> Array[Dictionary]:
	return []


## Brings a normal enemy into play now (the Floating Head's cyborg drop, GDD §10): a layout entry for
## the director, with a seed from the fight's own count so every attempt matches.
func spawn_enemy(type: String, at: float, lane: int, side: int = 0, params: Dictionary = {}) -> Enemy:
	_spawned += 1
	return world.director.spawn({"type": type, "at": at, "lane": lane, "side": side,
		"seed": hash([def.rng_key(), type, _spawned, rng.seed]), "params": params.duplicate(true)})


## Offers the player a pickup (GDD §10: "a section of floor that spawns an armor, shield or grapple
## pickup"): `item` is &"armor", &"shield" or &"grapple". The run's PickupField puts it on the floor
## at the first fair spot ahead of the player (in plain view and within reach, never over a gap, in a
## fence or where an attack is telegraphed), at or after track distance `at` if given, in or nearest to
## `lane` if given, as soon as there is one. Nothing is offered once the boss is beaten. False if the
## offer wasn't taken.
func offer_pickup(item: StringName, at: float = -1.0, lane: int = -1) -> bool:
	if state == State.DEFEATED or world == null or world.pickups == null:
		return false
	log_event(&"pickup_offered", {"item": item})
	return world.pickups.offer(item, at, lane)


## Switches the weak points of every part on or off.
func set_weak_points_enabled(on: bool) -> void:
	for part: BossPart in parts:
		if is_instance_valid(part):
			part.set_weak_points_enabled(on)


## Dims the arena's light to `level` (1 = the zone's normal light) over `seconds`, or brings it back:
## a smooth fade, never a flash, and never below MIN_LIGHT_LEVEL (GDD §10, Sleep Taker: darker, but
## never pitch black). It scales the environment's ambient and sky light, its fog's light and the
## directional light, and the scenery's own light (ZoneSkin's `scenery_light`: the skins' scenery shaders
## are unshaded, so the lights alone don't dim them), never below ZoneSkin.MIN_SCENERY_LIGHT; glowing
## things (hazards, credits, the HUD) keep their colours. The light returns with the fight.
func set_light_level(level: float, seconds: float = 1.0) -> void:
	_capture_light()
	_light_target = clampf(level, MIN_LIGHT_LEVEL, 1.0)
	_light_speed = absf(_light_target - _light) / maxf(seconds, 0.001)
	if seconds <= 0.0:
		_light = _light_target
		_apply_light()


func light_level() -> float:
	return _light


## Sets the scenery's own light (ZoneSkin's `scenery_light`) directly, for a lighting moment of the
## boss's own beyond set_light_level's range (the Sleep Taker's defeat: the first grey dawn); like
## set_light_level's, it's put back when the fight ends.
func set_scenery_light(light: float) -> void:
	_capture_light()
	_scenery_set = light
	ZoneSkin.set_scenery_light(light)


## Adds an entry to `events` (for tests and the debug readout).
func log_event(event: StringName, extra: Dictionary = {}) -> void:
	var entry := {"t": fight_time(), "event": event, "phase": phase_index}
	entry.merge(extra)
	events.append(entry)


# --- Hooks (override in a boss script) --------------------------------------------------

## Before the fight, once per distinct lap of the arena (`lap` starts at 0; the fight repeats the laps
## in turn): add the boss's own set pieces, or clear room for them. Runs before _build_boss, from the
## boss and the arena seed only, so every attempt gets the same laps.
func _plan_lap(_lap: LevelLayout, _index: int, _arena: BossArena) -> void:
	pass


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


## A part with health of its own was defeated (a swarm cluster shot down, or defeated by the boss
## script after being baited into a fence or a hole).
func _on_part_defeated(_part: BossPart, _cause: StringName) -> void:
	pass


## An EMP reached a part (`center` and `radius` in world space).
func _on_part_emp(_part: BossPart, _center: Vector3, _radius: float) -> void:
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


## After the defeat: true once it has played out and the run may end (LevelRun shows the results a
## moment later, LevelRun.COMPLETE_PAUSE). At once by default; a boss whose defeat plays out on the
## track holds the results until then (the Floating Head crashes into the street ahead, and the runner
## runs through its wreck first). LevelRun waits at most LevelRun.BOSS_VICTORY_MAX seconds.
func victory_over() -> bool:
	return true


## True if the win plays the victory riff (LevelRun: the level-complete riff in the music's key, GDD
## §11), as by default; a boss whose defeat ends in silence says no (the Sleep Taker, GDD §10).
func victory_riff() -> bool:
	return true


## The standard armor rule says an armor pickup is due (armor_pickup_due; `reason` as there): by
## default one on the floor ahead of the player (offer_pickup). A boss may put it somewhere of its
## own (a spot on its arena) with offer_pickup's `at` and `lane`.
func _on_armor_pickup_due(_reason: StringName) -> void:
	offer_pickup(&"armor")


# --- Internals -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null or world.player == null:
		return
	if arena != null:
		arena.update(world.player.distance)
	if _light != _light_target:
		_light = move_toward(_light, _light_target, _light_speed * delta)
		_apply_light()
	if state == State.DEFEATED:
		state_time += delta
		_defeated_tick(delta)
		return
	var player: Player = world.player
	if not player.alive or not player.running:
		return
	state_time += delta
	_update_armor_rule()
	if state == State.INTRO:
		_intro_tick(delta)
		if state == State.INTRO and state_time >= phase().intro_seconds:
			state = State.FIGHT
			state_time = 0.0
			log_event(&"pattern")
			_on_pattern_started(phase_index)
	else:
		_pattern_tick(delta)


func _exit_tree() -> void:
	# The lights are the run's: give them back as they were (the scenery's only if nothing has set it
	# since: a new run's own light stays).
	if not _light_base.is_empty():
		var scenery_ours: bool = is_equal_approx(ZoneSkin.scenery_light_now, _scenery_set)
		_light = 1.0
		_apply_light(scenery_ours)


func _begin_phase(index: int) -> void:
	phase_index = index
	phase_hits = 0
	state = State.INTRO
	state_time = 0.0
	set_weak_points_enabled(false)
	var p: BossPhase = phase()
	var resume: Dictionary = context.boss_resume
	if p.checkpoint and (resume.is_empty() or int(resume.get("phase", -1)) < index):
		# DESIGN-TBD (docs/questions/b8.md): a retry from here carries the fight time and score so far,
		# so stars, the time bonus and the leaderboard compare whole fights.
		context.boss_resume = {"phase": index, "time": fight_time(), "score": world.score.score,
			"weapon_damage": weapon_damage}
		log_event(&"checkpoint")
		checkpoint_reached.emit(index)
	log_event(&"phase")
	phase_started.emit(index)
	if def.armor_rule and is_final_phase():
		log_event(&"armor_pickup", {"reason": &"final_phase"})
		armor_pickup_due.emit(&"final_phase")
		_on_armor_pickup_due(&"final_phase")
	elif def.armor_rule and def.armor_when_unprotected and not player_protected():
		_schedule_armor(&"unprotected")
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
	_armor_due.clear()
	# No pickup after the fight: none still waiting for a spot, none left on the track.
	if world.pickups != null:
		world.pickups.clear()
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
## DESIGN-TBD (docs/questions/b8.md): damage beyond a phase carries into the next one.
func _lowest_after_hit() -> float:
	if phase_index >= phase_count() - 1:
		return 0.0
	return max_health * (_ends[phase_index + 1] + 2.0 * EPSILON)


func _sync_parts() -> void:
	for part: BossPart in parts:
		if is_instance_valid(part):
			part.sync_health()


func _on_item_used(item: StringName) -> void:
	if (item != &"armor" and item != &"shield") or state == State.DEFEATED:
		return
	log_event(&"protection_broken", {"item": item})
	protection_broken.emit(item)
	if def.armor_rule:
		_schedule_armor(&"protection_broken")


## True if the player is protected or protection is on its way: armor or a shield held, or an armor
## pickup already due (after a break), on the track, waiting for a spot, or held back by the boss
## (armor_pickups_waiting).
func player_protected() -> bool:
	var p: Player = world.player
	if p.armor > 0 or p.shield > 0 or not _armor_due.is_empty() or armor_pickups_waiting() > 0:
		return true
	if world.pickups != null:
		for pickup: Pickup in world.pickups.active:
			if is_instance_valid(pickup) and pickup.item == &"armor":
				return true
		for offer: Dictionary in world.pickups.pending:
			if offer["item"] == &"armor":
				return true
	return false


## Armor pickups the boss script holds back to place its own way later (_on_armor_pickup_due), which
## player_protected counts as on their way. None by default.
func armor_pickups_waiting() -> int:
	return 0


## An armor pickup BossDef.armor_delay_min–max seconds from now (a break, or a phase begun unprotected),
## at most armor_pickups_per_phase a phase. DESIGN-TBD (docs/questions/b8.md): it counts against the
## phase it comes from, and its delay is picked from the fight's own seeded stream.
func _schedule_armor(reason: StringName) -> void:
	var used: int = int(_armor_breaks.get(phase_index, 0))
	if used >= def.armor_pickups_per_phase:
		return
	_armor_breaks[phase_index] = used + 1
	var delay: float = _armor_rng.randf_range(def.armor_delay_min, maxf(def.armor_delay_max, def.armor_delay_min))
	_armor_due.append({"at": fight_time() + delay, "phase": phase_index, "reason": reason})
	log_event(&"armor_scheduled", {"reason": reason, "at": fight_time() + delay})


## Pickups after breaks (and unprotected phases), when their delay is up (the fight's clock stops while
## the player is down).
func _update_armor_rule() -> void:
	for i: int in range(_armor_due.size() - 1, -1, -1):
		if fight_time() >= float(_armor_due[i]["at"]):
			var reason: StringName = _armor_due[i].get("reason", &"protection_broken")
			_armor_due.remove_at(i)
			log_event(&"armor_pickup", {"reason": reason})
			armor_pickup_due.emit(reason)
			_on_armor_pickup_due(reason)


## The environment and the directional lights of the run, as they are before any dimming.
func _capture_light() -> void:
	if not _light_base.is_empty() or not is_inside_tree():
		return
	# The run's WorldEnvironment sets its world's environment.
	var env: Environment = get_world_3d().environment
	var lights: Array = []
	var holder: Node = world.get_parent() if world != null and world.get_parent() != null else world
	for node: Node in holder.find_children("*", "DirectionalLight3D", true, false):
		lights.append([node, (node as DirectionalLight3D).light_energy])
	_light_base = {"env": env, "lights": lights,
		"ambient": env.ambient_light_energy if env != null else 1.0,
		"sky": env.background_energy_multiplier if env != null else 1.0,
		"fog": env.fog_light_energy if env != null else 1.0,
		"scenery": ZoneSkin.scenery_light_now}
	_scenery_set = ZoneSkin.scenery_light_now


## The scenery light set_light_level gives the arena now (its own, the level's darkness, times the
## light), never below ZoneSkin.MIN_SCENERY_LIGHT unless the arena's own is darker still.
func scenery_light() -> float:
	var base: float = float(_light_base.get("scenery", ZoneSkin.scenery_light_now))
	return maxf(base * _light, minf(base, ZoneSkin.MIN_SCENERY_LIGHT))


func _apply_light(scenery: bool = true) -> void:
	if _light_base.is_empty():
		return
	var env: Environment = _light_base["env"]
	if env != null:
		env.ambient_light_energy = float(_light_base["ambient"]) * _light
		env.background_energy_multiplier = float(_light_base["sky"]) * _light
		env.fog_light_energy = float(_light_base["fog"]) * _light
	for entry: Array in _light_base["lights"]:
		if is_instance_valid(entry[0]):
			(entry[0] as DirectionalLight3D).light_energy = float(entry[1]) * _light
	if scenery:
		_scenery_set = scenery_light()
		ZoneSkin.set_scenery_light(_scenery_set)
