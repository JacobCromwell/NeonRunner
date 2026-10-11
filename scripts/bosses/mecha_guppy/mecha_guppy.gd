class_name MechaGuppy
extends BossEncounter
## Mecha Guppy and Captain Cogs, the Beach's boss (GDD §10; task E5e). Mecha Guppy, a building-sized mechanical
## shark, eats the level from below while Captain Cogs, a pirate in a flying ship, throws bombs down at the
## runner; through the first two phases the runner climbs, by anti-grav pads and tiki-hut ceilings, onto higher
## and higher tiki bar roofs, the camera following them up past a waterfall, under Sunset Strip's setting sun.
## Task E5e-b1 builds the climb, its look and the fight's frame; E5e-b2 the shark, the pirate, the bombs and what
## hurts the shark; E5e-b3 the hits by baiting; E5e-c phase 3 and the defeat, and the campaign plays it (the slot's
## scene, after Sunset Strip).
##
## The arena (BossDef.arena, data/bosses/beach_boss.tres): the Beach's look (MechaGuppySkin, a BeachSkin with the
## climb's tiki huts, tiki bar towers and chasms, data/bosses/beach_boss_skin.tres), the street eaten from the start
## (_plan_lap: a gap in every lane over every lap: the water below the climb) and no side walls anywhere (a wall
## gap over every lap on both sides, so a runner on a high roof never meets a wall measured from the street; the
## open beach and the sea beyond).
## The climb (phases 1 and 2): MechaGuppyClimb plans it step after step (the pads, the hut, the higher roof, the
## lanes that lead up and the cue that shows them, the fairness margins), MechaGuppyStairs builds it within sight
## (collision and look) and keeps the floor the runner's falls count from (Player.floor_base) at the roof they
## climb to; the climbing view is on for the whole fight (RunWorld.camera_climbs). A wrong drop falls into the
## floor Mecha Guppy has eaten: a fall, death unless the grapple saves it (_grapple_save: up onto the higher roof,
## into its nearest lane that leads up; a revive after a fall goes there too). Phase 2's climb is about 20%
## faster: its steps are higher (MechaGuppyTuning.phase2_rise) and as long, the run speed never rises.
## Phase 3, "Level with Captain Cogs" (GDD §10; task E5e-c, MechaGuppyTop): its step is the top, the climb's last roof
## running on flat (a long tiki bar roof deck: no more pads, huts, bites or bombs). When the runner reaches it
## (top_reached, logged), the waterfall backdrop (MechaGuppyWaterfall) and its low cloud give way to the Beach's own,
## Captain Cogs' ship comes level alongside the top, and the minute (top_seconds) starts: the boss bar runs down over it
## while the captain's rounds (lanes struck by cannonballs: a switch) and the waves (crashing over every lane: a jump)
## come on a fixed, looped script timed from that moment. When it's up, the fight is won (a counted hit, &"time").
## The defeat (MechaGuppyLeap): Mecha Guppy bursts up under the ship, gulps the captain with the ship's stern half, falls
## back and swims away; the results wait until it's gone (victory_over), and the victory riff comes after the gulp
## (MechaGuppyTuning.victory_riff_on), not at the defeat (victory_riff).
##
## The shark, the pirate and the bombs (E5e-b2, E5e-b3): Mecha Guppy (MechaGuppyShark) waits with its jaws open beside
## each roof's notch, then bites the end of the roof the runner has just left; Captain Cogs (CaptainCogsShip) flies
## ahead and above, throwing the bombs (MechaGuppyBombs: the Floating Head's warning, a circle at the floor's height
## and a whistle); MechaGuppyPattern times them step by step, the same every step. The bombs, the bites and the hits
## run only while attacks_enabled (tests turn them off to check the climb alone).
## Hits (GDD §10: phase 1 ends after 4, phase 2 after 6; BossPhase.hits; the owner, October 11, 2026: by baiting):
## register_hit(), which the bombs call when one falls into Mecha Guppy's open jaws (the stretch it has eaten through,
## where it's exposed and in the line of fire): the bait's bomb, locked onto a runner in the notch's lane who switched
## out before its edge, or the fallback's, Captain Cogs missing into the chasm once fallback_after steps in a row went
## by without a hit (MechaGuppyPattern). Never on a step the runner fell (_grapple_save tells the pattern). Weapons do
## nothing (BossDef.weapon_share_cap 0; weapons_can_end_phase off: each phase's hits are counted).
## The armor rule's pickups (GDD §10, the standard 15-17 s) appear on the roof the runner will run along
## (_on_armor_pickup_due, PickupField.place at the roof's height), never under a hut or near an edge.
## Random choices (the lanes that lead up) come from a seed of the fight and the lane count, time from the physics
## step, so every attempt plays the same; nothing changes with time but the phase (GDD §10: no escalation).

## The climb's random choices hash this with the boss's rng key and the lane count.
const CLIMB_SEED: String = "climb"
## The street is eaten from this far behind the start of every lap (metres): the street under the start is a
## roof of the climb's own (roof 0), so nothing of it is the track's.
const EATEN_BEHIND: float = 60.0
## The grapple's rope as it saves a runner (a warm white: no hazard colour), how long it shows and how thick it is.
const ROPE_COLOR := Color(1.0, 0.92, 0.78)
const ROPE_SECONDS: float = 0.35
const ROPE_THICKNESS: float = 0.06

## The runner stands on phase 3's top (its minute and its attacks start here: MechaGuppyTop).
signal top_reached

var tuning: MechaGuppyTuning
var climb: MechaGuppyClimb
var stairs: MechaGuppyStairs
var waterfall: MechaGuppyWaterfall
## Mecha Guppy itself (its bites and catches), Captain Cogs' ship and bombs, and the pattern that times them on each step.
var shark: MechaGuppyShark
var ship: CaptainCogsShip
var bombs: MechaGuppyBombs
var pattern: MechaGuppyPattern
## Phase 3 (its minute, the captain's rounds and the waves) and the defeat (the leap; null until the win).
var top: MechaGuppyTop
var leap: MechaGuppyLeap
## Off: no bombs and no bites (the climb's own tests turn them off to check the climb alone; on in the game).
var attacks_enabled: bool = true
## Hits landed over the fight (register_hit).
var hits_landed: int = 0
## The fight time the runner reached the top (phase 3), or -1 before.
var top_reached_at: float = -1.0

## Armor pickups due but not yet placed (a roof run far enough ahead comes soon).
var _armor_waiting: int = 0


func _tuning() -> MechaGuppyTuning:
	var t := (def.tuning as MechaGuppyTuning) if def != null else null
	return t if t != null else MechaGuppyTuning.new()


# --- The arena -------------------------------------------------------------------------------------

## Every lap: nothing of the generator's (no holes, fences, ceilings, pads, enemies, credits), the street eaten in
## every lane (the climb's own roofs carry the runner from the start), and no side walls on either side.
## DESIGN-TBD: the street eaten from the start (roof 0, the climb's own floor, eaten just past the first pads like
## every roof), and no walls at all (E5e-d's occasional walls: likely none); docs/questions/e5e.md.
func _plan_lap(lap: LevelLayout, _index: int, p_arena: BossArena) -> void:
	lap.gaps.clear()
	lap.fences.clear()
	lap.signs.clear()
	lap.hulls.clear()
	lap.pads.clear()
	lap.ramps.clear()
	lap.speed_pads.clear()
	lap.enemies.clear()
	lap.doodads.clear()
	lap.cuts.clear()
	lap.wall_fences.clear()
	lap.credits.clear()
	lap.dash_walls.clear()
	lap.wall_gaps.clear()
	for lane: int in lap.lane_count:
		lap.gaps.append({"lane": lane, "start": -EATEN_BEHIND, "end": p_arena.lap_length + 1.0})
	for side: int in [-1, 1]:
		lap.wall_gaps.append({"side": side, "start": 0.0, "end": p_arena.lap_length})


func _build_boss() -> void:
	tuning = _tuning()
	var dash: float = MechaGuppyClimb.dash_reach_of(world.powerup_tuning)
	climb = MechaGuppyClimb.make(world.tuning, tuning, lane_count(), dash, hash([def.rng_key(), CLIMB_SEED, lane_count()]))
	world.camera_climbs = true
	world.player.floor_base = 0.0
	stairs = MechaGuppyStairs.new()
	stairs.name = "Stairs"
	add_child(stairs)
	stairs.setup(self)
	waterfall = MechaGuppyWaterfall.new()
	waterfall.name = "Waterfall"
	add_child(waterfall)
	waterfall.setup(world)
	shark = MechaGuppyShark.new()
	shark.name = "Shark"
	add_child(shark)
	shark.setup(self)
	bombs = MechaGuppyBombs.new()
	bombs.name = "Bombs"
	add_child(bombs)
	bombs.setup(self)
	ship = CaptainCogsShip.new()
	ship.name = "Ship"
	add_child(ship)
	ship.setup(self)
	pattern = MechaGuppyPattern.new(self)
	shark.on_snap = pattern.on_snap
	top = MechaGuppyTop.new()
	top.name = "Top"
	add_child(top)
	top.setup(self)


## The run's pace (MovementTuning.pace(): 1 at 18 m/s): the climb's distances that stand for a time follow it.
func run_pace() -> float:
	if world != null and world.tuning != null:
		return world.tuning.pace()
	if arena != null and arena.tuning != null:
		return arena.tuning.pace()
	return 1.0


## True once the climb gives way to the top (phase 3, the last phase).
func top_due() -> bool:
	return phase_index >= phase_count() - 1 and phase_count() > 2


# --- Phases ----------------------------------------------------------------------------------------

func _on_phase_started(index: int) -> void:
	log_event(&"climb_phase", {"index": index, "step": climb.steps.size()})
	# A bait still following the runner is called off (the next phase's intro: no attacks).
	if bombs != null:
		bombs.drop_bait()


func _intro_tick(delta: float) -> void:
	_advance(delta)
	_place_armor()
	_watch_top()


func _pattern_tick(delta: float) -> void:
	_advance(delta)
	_place_armor()
	_watch_top()
	# GDD §10: the minute on the top is up (the runner dodged for it): Mecha Guppy leaps, the fight is won.
	if top_due() and top != null and top.over():
		log_event(&"top_over")
		damage(hit_damage(), &"time")


## True while the runner stands on phase 3's top (the last roof, which runs on).
func on_top() -> bool:
	if climb == null or not climb.top_planned() or world == null:
		return false
	var p: Player = world.player
	var roof: MechaGuppyClimb.Roof = climb.roofs[-1]
	return p.surface == Player.Surface.FLOOR and p.grounded and absf(p.floor_y - roof.top) < 0.05 \
		and p.distance >= roof.first_start()


## The moment the runner reaches the top: logged and signalled, the waterfall and its low cloud give way to the Beach's
## own backdrop (GDD §10: the waterfall in phases 1 and 2), and phase 3's minute begins (MechaGuppyTop.begin: the ship
## comes level, the script starts).
func _watch_top() -> void:
	if top_reached_at >= 0.0 or not top_due() or not on_top():
		return
	top_reached_at = fight_time()
	log_event(&"top_reached", {"height": world.player.floor_y, "step": climb.steps.size()})
	if waterfall != null:
		waterfall.set_shown(false, 2.0)
	if top != null:
		top.begin(top_reached_at)
	top_reached.emit()


## The win (phase 3's minute is up): every attack gone, and Mecha Guppy leaps (MechaGuppyLeap).
func _on_defeated() -> void:
	_armor_waiting = 0
	if bombs != null:
		bombs.clear()
	if top != null:
		top.clear()
	if shark != null and ship != null:
		leap = MechaGuppyLeap.new(self)
		leap.start()


func _defeated_tick(delta: float) -> void:
	if ship != null:
		ship.advance(delta)
	if shark != null:
		shark.advance(delta)
	if top != null:
		top.tick(delta)
	if leap != null:
		leap.tick(delta)


## The results wait until Mecha Guppy has swum away (at most LevelRun.BOSS_VICTORY_MAX).
func victory_over() -> bool:
	return leap == null or leap.over()


## No riff at the defeat: the leap plays it after the gulp, or not (MechaGuppyTuning.victory_riff_on).
func victory_riff() -> bool:
	return false


## The captain, the shark, the bombs and the pattern, one physics step (the fight's ticks: they wait while the runner is
## down).
func _advance(delta: float) -> void:
	if ship != null:
		ship.advance(delta)
	if bombs != null:
		bombs.tick(delta)
	if shark != null:
		shark.advance(delta)
	if pattern != null:
		pattern.tick()
	if top != null:
		top.tick(delta)


## True while Captain Cogs throws and Mecha Guppy rises to eat the bombs: the climb's pattern runs (not in an intro, not
## in phase 3, whose attacks are MechaGuppyTop's, not once it's won).
func attacks_live() -> bool:
	return attacks_enabled and is_vulnerable() and not top_due()


## True while Mecha Guppy eats the roofs the runner leaves (an intro too: the level being eaten isn't an attack), until
## the runner stands on the top.
func bites_live() -> bool:
	return attacks_enabled and not is_defeated() and top_reached_at < 0.0


## Plays a sound at `pos` and notes it (every warning is heard: the tests read the notes).
func sound(sound_name: StringName, pos: Vector3) -> void:
	world.play_sfx_at(sound_name, pos)
	log_event(&"sound", {"name": sound_name})


## A hit on Mecha Guppy (GDD §10: a bomb that falls through a gap, off a roof's edge or onto the exposed shark):
## one of the phase's BossPhase.hits (4 in phase 1, 6 in phase 2). The bombs call this (MechaGuppyBombs); the tests too. Only
## counts while the climb's pattern runs (not in an intro, not in phase 3, which a minute of dodging ends, not once
## it's beaten). True if it counted.
func register_hit(cause: StringName = &"bomb") -> bool:
	if not is_vulnerable() or top_due():
		return false
	if pattern != null:
		pattern.note_hit()
	hits_landed += 1
	log_event(&"hit", {"cause": cause, "of": phase().hits, "landed": phase_hits + 1})
	damage(hit_damage(), cause)
	return true


# --- The armor rule's pickups ------------------------------------------------------------------------

## GDD §10's standard armor rule: the pickup goes on the roof the runner will run along (MechaGuppyStairs.
## pickup_spot: past a landing, before the next pads, in the lane they'll land in or run in, at the roof's
## height), as soon as one is far enough ahead.
func _on_armor_pickup_due(_reason: StringName) -> void:
	_armor_waiting += 1
	_place_armor()


func armor_pickups_waiting() -> int:
	return _armor_waiting


func _place_armor() -> void:
	if _armor_waiting <= 0 or world == null or world.pickups == null or stairs == null or is_defeated():
		return
	var spot: Dictionary = stairs.pickup_spot(world.pickups.tuning.lead_distance)
	if spot.is_empty():
		return
	_armor_waiting -= 1
	log_event(&"pickup_offered", {"item": &"armor", "lane": spot["lane"], "at": spot["at"], "height": spot["height"]})
	world.pickups.place(&"armor", int(spot["lane"]), float(spot["at"]), float(spot["height"]))


# --- The grapple's save --------------------------------------------------------------------------------

## GDD §10 (proposed): the grapple pulls a falling runner up onto the higher roof, into its nearest lane that
## leads up; a revive after a fall goes there too (DESIGN-TBD, docs/questions/e5e.md). MechaGuppyStairs.save_spot
## picks the roof and the lane whose path is clear (no solid front in the way, the roof under them where they
## come down).
func _grapple_save(player: Player, cause: StringName) -> Dictionary:
	# A fall: no hit for this step (MechaGuppyPattern.catch_ok; GDD §10's bait never rewards a fall).
	if pattern != null:
		pattern.note_fall()
	if stairs == null:
		return {}
	var spot: Dictionary = stairs.save_spot(player)
	log_event(&"save", {"cause": cause, "lane": spot.get("lane", player.lane), "height": spot.get("height", NAN)})
	# DESIGN-TBD (docs/questions/e5e.md): the grapple's save shows its rope for a moment, from the runner, as the lift
	# brings them up (followed frame by frame), to the roof's edge it catches (E5e-a's proposal).
	if cause == &"grapple" and not spot.is_empty():
		var lane: int = int(spot["lane"])
		var roof_at: float = maxf(stairs.roof_front(lane, float(spot["height"]), player.distance), player.distance + 2.0)
		var rope := MechaGuppyRope.new()
		rope.name = "Rope"
		add_child(rope)
		rope.setup(player, world.lane_point(lane, roof_at, float(spot["height"])), ROPE_COLOR, ROPE_SECONDS, ROPE_THICKNESS)
	return spot
