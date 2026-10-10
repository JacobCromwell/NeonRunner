class_name MechaGuppy
extends BossEncounter
## Mecha Guppy and Captain Cogs, the Beach's boss (GDD §10; task E5e). Mecha Guppy, a building-sized mechanical
## shark, eats the level from below while Captain Cogs, a pirate in a flying ship, throws bombs down at the
## runner; through the first two phases the runner climbs, by anti-grav pads and tiki-hut ceilings, onto higher
## and higher tiki bar roofs, the camera following them up past a waterfall, under Sunset Strip's setting sun.
## Task E5e-b1 builds the climb, its look and the fight's frame; E5e-b2 the shark, the pirate, the bombs and what
## hurts the shark; E5e-c phase 3 and the defeat (the slot then switches from preview_scene to scene).
##
## The arena (BossDef.arena, data/bosses/beach_boss.tres): the Beach's look (MechaGuppySkin, a BeachSkin with the
## climb's tiki huts, tiki bar roofs and basins, data/bosses/beach_boss_skin.tres), the street eaten from the start
## (_plan_lap: a gap in every lane over every lap: the water below the climb) and no side walls anywhere (a wall
## gap over every lap on both sides, so a runner on a high roof never meets a wall measured from the street; the
## open beach and the sea beyond).
## The climb (phases 1 and 2): MechaGuppyClimb plans it step after step (the pads, the hut, the higher roof, the
## lanes that lead up and the cue that shows them, the fairness margins), MechaGuppyStairs builds it within sight
## (collision and look) and keeps the floor the runner's falls count from (Player.floor_base) at the roof they
## climb to; the climbing view is on for the whole fight (RunWorld.camera_climbs). A wrong drop falls into the
## floor Mecha Guppy has eaten: a fall, death unless the grapple saves it (_grapple_save: up onto the higher roof,
## into its nearest lane that leads up; a revive after a fall goes there too). Phase 2's climb is about 20%
## faster: its steps come closer together (MechaGuppyTuning.roof_seconds), the run speed never rises.
## Phase 3 is a stub (DESIGN-TBD, E5e-c): its step is the top, a roof that runs on flat, and the phase ends
## top_seconds into its pattern; the waterfall backdrop (MechaGuppyWaterfall) gives way to the Beach's own sky.
##
## Hits (GDD §10: phase 1 ends after 4, phase 2 after 6; BossPhase.hits): register_hit(), which E5e-b2's bombs call
## when one falls through a gap, off a roof's edge or onto the exposed shark (and the tests call now). Weapons do
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

var tuning: MechaGuppyTuning
var climb: MechaGuppyClimb
var stairs: MechaGuppyStairs
var waterfall: MechaGuppyWaterfall
## Hits landed over the fight (register_hit).
var hits_landed: int = 0

## Armor pickups due but not yet placed (a roof run far enough ahead comes soon).
var _armor_waiting: int = 0


func _tuning() -> MechaGuppyTuning:
	var t := (def.tuning as MechaGuppyTuning) if def != null else null
	return t if t != null else MechaGuppyTuning.new()


# --- The arena -------------------------------------------------------------------------------------

## Every lap: nothing of the generator's (no holes, fences, ceilings, pads, enemies, credits), the street eaten in
## every lane (the climb's own roofs carry the runner from the start), and no side walls on either side.
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
	if is_final_phase():
		waterfall.set_shown(false, 0.0)


## The run's pace (MovementTuning.pace(): 1 at 18 m/s): the climb's distances that stand for a time follow it.
func run_pace() -> float:
	if world != null and world.tuning != null:
		return world.tuning.pace()
	if arena != null and arena.tuning != null:
		return arena.tuning.pace()
	return 1.0


## True once the climb gives way to the top (phase 3's flat run, E5e-c: the last phase).
func top_due() -> bool:
	return phase_index >= phase_count() - 1 and phase_count() > 2


# --- Phases ----------------------------------------------------------------------------------------

func _on_phase_started(index: int) -> void:
	log_event(&"climb_phase", {"index": index, "step": climb.steps.size()})
	if top_due() and waterfall != null:
		# GDD §10: the waterfall in phases 1 and 2, the Beach's normal backdrop in phase 3.
		waterfall.set_shown(false, 2.0)


func _intro_tick(_delta: float) -> void:
	_place_armor()


func _pattern_tick(_delta: float) -> void:
	_place_armor()
	# DESIGN-TBD (E5e-c builds phase 3): the stub's minute on the top runs out and the fight is won.
	if top_due() and state_time >= tuning.top_seconds:
		log_event(&"top_over")
		damage(hit_damage(), &"time")


func _on_defeated() -> void:
	_armor_waiting = 0


## A hit on Mecha Guppy (GDD §10: a bomb that falls through a gap, off a roof's edge or onto the exposed shark):
## one of the phase's BossPhase.hits (4 in phase 1, 6 in phase 2). E5e-b2's bombs call this; the tests too. Only
## counts while the phase's pattern runs (not in an intro, not once it's beaten). True if it counted.
func register_hit(cause: StringName = &"bomb") -> bool:
	if not is_vulnerable():
		return false
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
	if stairs == null:
		return {}
	var spot: Dictionary = stairs.save_spot(player)
	log_event(&"save", {"cause": cause, "lane": spot.get("lane", player.lane), "height": spot.get("height", NAN)})
	return spot
