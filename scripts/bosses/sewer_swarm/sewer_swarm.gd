class_name SewerSwarm
extends BossEncounter
## The Sewer Swarm, Gangland's boss (GDD §10): "a mutant horde of screeches rising from the sewers. It builds
## up on both sides of the street, and a mob attacks while the horde shifts ahead of and behind the player."
## The fight is Gangland's final exam: "the street is the weapon. The player baits the swarm into attacking,
## dodges in time, and the swarm hits a live electric fence and is shocked, which damages the boss. Baiting a
## cluster into a hole also works. Weapons thin clusters too." Task E4 (E4a: the clusters, the arena and
## phase 1; E4b: phases 2 and 3, the defeat, the par times and its slot): the campaign plays it after
## Gangland 3 (BossDef.scene), and debug builds with ./play.sh --boss=gangland_boss.
##
## What it is (GDD §10's implementation): SewerSwarmTuning.cluster_count clusters (SwarmCluster: boss parts
## with health of their own and is_swarm), each drawn as a crowd of screeches (SwarmCrowd, one MultiMesh and
## swarm_crowd.gdshader: it looks like hundreds, only the clusters are simulated), the Host (SwarmHost, "one
## more entity": the boss's body, hidden until phase 3), and the horde at the roadsides (SwarmHorde: a crowd
## in each gutter, the manholes and vents along both sides, the screeches pouring out of them), all made
## before the fight begins (no mesh or material is made mid-fight). Crowd sizes are the look only
## (SewerSwarmTuning, smaller on a low-end device): the fight never reads them.
##
## The arena (BossDef.arena, data/bosses/gangland_boss.tres): Gangland's street, the generator's holes and
## fences, with nothing else on the track (no signs, ceilings, pads, doodads, enemies), and on each lap its
## bait spots (_plan_lap): from bait_first on, one every bait_spacing, a live full-height fence or a hole in
## one lane (bait_kinds in turn; the lane seeded, at most bait_max_shift from the one before), the street
## clear of every other hole and fence in every lane around it (bait_clear_span) so the runner can always
## reach the bait and always get out of a surge's way; and after each its host spot (_plan_host_spots): a
## ramp in an outer lane (sides in turn), the street clear around it, where the Host crouches in phase 3.
##
## Phase 1, the Rising (GDD §10: "manholes and wall vents shake all along both sides, and screeches pour out
## and merge into clusters at the roadside. A cluster surges down a lane ahead of the player, with a red lane
## line and a rising chitter as the warning"):
## 1. Its intro: the lairs in sight rattle and burst, screeches pour out, the gutters fill and the clusters
##    rise at their stations at the roadside ahead, alternating sides, pacing the runner (the next to surge
##    nearest).
## 2. Its pattern (SwarmSurges): a surge at every bait spot the runner reaches: warning_seconds before it
##    would meet the runner the nearest cluster rears up at the roadside where it will pour in, its chitter
##    rises and a red line runs down the runner's lane to it, following the runner from lane to lane and
##    ending at a fence or a hole on it; lock_seconds before, it lands in the runner's lane and charges
##    (the line locks: the standard red lane warning). A runner who was in the bait's lane gets out of the way
##    (or jumps the fence or the hole) and the cluster, charging at them, runs into it: shocked by the fence
##    or falling into the hole, it's destroyed (the phase's hit, hit_damage(), and bait_score). One that
##    meets no bait hits only through its hitbox (an enemy attack), passes, scatters out of sight and
##    re-forms at the back of the line. Weapons thin a surging cluster (the heavy missile's swarm bonus
##    applies); thinned to nothing, it's destroyed too (weapon damage: within weapon_share_cap).
## 3. Two clusters destroyed end it (BossPhase.hits); otherwise it keeps cycling, the same way at every spot
##    (GDD §10: no time limit, no escalation).
## Phase 2, Surrounded (GDD §10: "clusters also strike from behind ... The swarm also climbs the walls ... one
## wall at a time for a few seconds, alternating sides, so one wall is always free"): the surges come in turn
## from behind and ahead (SewerSwarmTuning.surge_sides): from behind, a wave of the swarm rises behind the runner
## in their lane, curling over them, crashes down and surges on along the lane into the fence or hole ahead
## (SwarmSurges); meanwhile the swarm climbs one wall at a time (SwarmClimb: the wall taken away, never both).
## The rest of the clusters destroyed end it.
## Phase 3, The Host (GDD §10): it bursts out of a pipe across the street ahead, paces the runner, flings
## the swarm at them at hole spots, lunges down their lane at fence spots (baited into the fence: a hit) and
## crouches in a host spot's ramp lane, its implants glowing: a ramp, a wall run and a wall jump bring the
## runner down on them (a stomp: a hit). Three hits free the Host: its defeat (SwarmHostAttacks).
## Every attack is warned (visual and audio) before it can hit, every one has an escape and a bait the runner
## can reach, at any lane count (test_sewer_swarm_*.gd prove it). Nothing depends on how long the fight has
## lasted: the spots are the track's, planned from the arena's seed, and everything is timed from the
## runner's distance, so every attempt plays the same way for the same runner. Distances that stand for a
## time follow the run's pace (run_pace(): Gangland's 21.8 m/s in the campaign, 18 m/s in quick play).

enum Step { RISING, FIGHT, BEATEN }

const CLUSTER_SCRIPT: Script = preload("res://scripts/bosses/sewer_swarm/swarm_cluster.gd")
const HOST_SCRIPT: Script = preload("res://scripts/bosses/sewer_swarm/swarm_host.gd")
## The Host's phase (phase 3): no clusters, no surges.
const HOST_PHASE: int = 2
## How far ahead it looks for the track's bait spots (metres at 18 m/s, times run_pace()).
const SIGHT: float = 400.0
## A surge's chitter plays where the cluster gathers, but never further ahead than this (so it's heard).
const SOUND_AHEAD: float = 32.0
var tuning: SewerSwarmTuning
var horde: SwarmHorde
var surges: SwarmSurges
## Phase 2's wall climb, phase 3's Host (the boss's body), its attacks, its pipe and its way up's marks.
var climb: SwarmClimb
var host: SwarmHost
var host_attacks: SwarmHostAttacks
var pipe: SwarmPipe
var marks: SwarmJumpMarks
## Surges begun in the current phase (phase 2's sides take turns by it).
var phase_surges: int = 0
## The clusters in play, alive or dying.
var clusters: Array[SwarmCluster] = []
## The clusters waiting at the roadside, in the order they'll surge (the first nearest).
var queue: Array[SwarmCluster] = []
## Clusters destroyed over the fight, and by what ({cause: count}).
var destroyed: int = 0
var destroyed_by: Dictionary = {}
var step: Step = Step.RISING
var step_time: float = 0.0
## Draws fewer creatures (DeviceProfile.is_low_end(), read in setup; tools may set it before).
var low_end: bool = false

## Each distinct lap's bait spots (lap index -> [{at, lane, kind, far}], lap-relative track distances).
var _spot_plan: Dictionary = {}
## Each distinct lap's host spots (lap index -> [{at (the ramp), side, lane, from, to (the crouch), drop}]).
var _host_plan: Dictionary = {}
## Spots whose surge came (or whose moment passed), by their key.
var _used: Dictionary = {}
var _crowd_pool: Array[SwarmCrowd] = []
var _crowds: Node3D
var _spawned_clusters: int = 0
var _hinted: Dictionary = {}
## Where each waiting cluster stands ahead of the runner, easing toward its station (instance id -> m).
var _offsets: Dictionary = {}


func _tuning() -> SewerSwarmTuning:
	var t := (def.tuning as SewerSwarmTuning) if def != null else null
	return t if t != null else SewerSwarmTuning.new()


# --- The arena -----------------------------------------------------------------------------------

## GDD §10's arena: Gangland's street with the generator's holes and fences, nothing else on the track, and
## the lap's bait spots, each in a stretch kept clear of every other hole and fence.
## DESIGN-TBD (docs/OPEN_QUESTIONS.md 325): bait spots every bait_spacing, a surge at each, rather than surges
## at the generator's own fences and holes wherever they fall.
func _plan_lap(lap: LevelLayout, index: int, p_arena: BossArena) -> void:
	var t: SewerSwarmTuning = _tuning()
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
	# Pulsing fences would be off when a cluster reaches them: none (the arena has no "pulsing" feature).
	for i: int in range(lap.fences.size() - 1, -1, -1):
		if bool(lap.fences[i].get("pulsing", false)):
			lap.fences.remove_at(i)
	var k: float = p_arena.tuning.pace()
	var span: Vector2 = bait_clear_span(t, p_arena.tuning)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(def.id) if def != null else "sewer_swarm", "baits", p_arena.config.level_seed, index])
	var n: int = lap.lane_count
	var plan: Array[Dictionary] = []
	var at: float = t.bait_first * k
	var prev: int = -1
	var j: int = 0
	while at + span.y <= p_arena.lap_length - 1.0:
		var kind: String = t.bait_kind(j)
		var lane: int = _pick_lane(rng, n, prev, t.bait_max_shift)
		_clear_track(lap, at + span.x, at + span.y)
		var far: float = at
		if kind == "hole":
			far = at + t.hole_length * k
			lap.gaps.append({"lane": lane, "start": at, "end": far})
		else:
			lap.fences.append({"lane": lane, "at": at, "variant": "full", "pulsing": false,
				"pulse_on": 1.0, "pulse_off": 1.0, "phase": 0.0})
		plan.append({"at": at, "lane": lane, "kind": kind, "far": far})
		prev = lane
		at += t.bait_spacing * k
		j += 1
	_spot_plan[index] = plan
	_plan_host_spots(lap, index, p_arena, plan, span, rng)


## Each lap's host spots (the Host's way up, phase 3): one after each bait spot, host_after on, whose stretch
## fits before the next bait spot's (and the lap's end): a ramp in the outer lane on one side (sides in turn,
## the first seeded), every lane clear from host_lead_in before it to host_clear_after past where the Host
## crouches, and the ramp's lane clear on to where its wall run drops back into it.
func _plan_host_spots(lap: LevelLayout, index: int, p_arena: BossArena, baits: Array[Dictionary], span: Vector2,
		rng: RandomNumberGenerator) -> void:
	var t: SewerSwarmTuning = _tuning()
	var k: float = p_arena.tuning.pace()
	var v: float = p_arena.tuning.run_speed
	var first_side: int = -1 if rng.randi_range(0, 1) == 0 else 1
	var hosts: Array[Dictionary] = []
	for i: int in baits.size():
		var ramp_at: float = float(baits[i]["at"]) + t.host_after * k
		var reach: Vector2 = host_clear_span(t, p_arena.tuning, ramp_at)
		# The lap's last one may run into the next lap's clear start (every lap begins clear).
		var lap_room: float = p_arena.lap_length - 1.0 + p_arena.config.start_clear_distance * k * 0.9
		var limit: float = lap_room
		var next_bait: float = INF
		if i + 1 < baits.size():
			next_bait = float(baits[i + 1]["at"])
			limit = minf(limit, next_bait + span.x - 0.5)
		var side: int = first_side * (1 if posmod(hosts.size(), 2) == 0 else -1)
		var ramp := {"side": side, "at": ramp_at}
		# Where its wall run drops back into its lane (a wall run never jumped off), with a margin.
		var drop: float = RampLaunch.of(ramp, p_arena.tuning, v).end() + 4.0 * k
		# Its ramp's lane stays clear to the drop, which may reach into the next spot's clear stretch (clear
		# but for its bait, further on).
		if reach.x < float(baits[i]["at"]) + span.y + 0.5 or reach.y > limit or drop >= minf(next_bait - 2.0 * k, lap_room):
			continue
		_clear_track(lap, reach.x, reach.y)
		_clear_lane(lap, lap.outer_lane(side), reach.y, drop)
		lap.ramps.append(ramp)
		hosts.append({"at": ramp_at, "side": side, "lane": lap.outer_lane(side),
			"from": ramp_at + t.crouch_from * k, "to": ramp_at + (t.crouch_from + t.crouch_length) * k,
			"drop": drop})
	_host_plan[index] = hosts


## The stretch a host spot whose ramp starts at `ramp_at` keeps clear in every lane (track distances).
static func host_clear_span(t: SewerSwarmTuning, movement: MovementTuning, ramp_at: float) -> Vector2:
	var k: float = movement.pace()
	return Vector2(ramp_at - t.host_lead_in * k, ramp_at + (t.crouch_from + t.crouch_length + t.host_clear_after) * k)


## A bait spot's lane: seeded, never the last one's, at most `shift` lanes from it.
static func _pick_lane(rng: RandomNumberGenerator, n: int, prev: int, shift: int) -> int:
	if prev < 0:
		return rng.randi_range(0, n - 1)
	var options: Array[int] = []
	for lane: int in n:
		if lane != prev and absi(lane - prev) <= maxi(shift, 1):
			options.append(lane)
	return options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else prev


## The stretch around a bait spot (relative to it) kept clear of holes and fences in every lane but the bait
## itself: from a jump before where its surge's warning finds the runner (they may be anywhere then, and
## need the whole street to reach the bait's lane), to clear_after past where its cluster lands (and its
## mass behind that). `movement` is the arena's (its run speed).
static func bait_clear_span(t: SewerSwarmTuning, movement: MovementTuning) -> Vector2:
	var k: float = movement.pace()
	var v: float = movement.run_speed
	var jump: float = movement.jump_distance(v)
	# A surge from ahead's warning, and a strike from behind's (phase 2), whichever starts further back.
	var before: float = maxf(t.strike_before * k + v * t.warning_seconds,
		t.behind_strike_before * k + v * t.behind_warning_seconds) + jump + 2.0
	var after: float = (t.charge_speed * t.lock_seconds - t.strike_before) * k + t.mass_length + t.clear_after * k
	return Vector2(-before, after)


## Takes holes and fences (any part of one) out of `lane` between two track distances.
static func _clear_lane(lap: LevelLayout, lane: int, from: float, to: float) -> void:
	if to <= from:
		return
	for i: int in range(lap.gaps.size() - 1, -1, -1):
		if int(lap.gaps[i]["lane"]) == lane and float(lap.gaps[i]["start"]) <= to and float(lap.gaps[i]["end"]) >= from:
			lap.gaps.remove_at(i)
	for i: int in range(lap.fences.size() - 1, -1, -1):
		var f: float = float(lap.fences[i]["at"])
		if int(lap.fences[i]["lane"]) == lane and f >= from - 0.5 and f <= to + 0.5:
			lap.fences.remove_at(i)


## Takes holes and fences (any part of one) out of every lane between two track distances.
static func _clear_track(lap: LevelLayout, from: float, to: float) -> void:
	for i: int in range(lap.gaps.size() - 1, -1, -1):
		if float(lap.gaps[i]["start"]) <= to and float(lap.gaps[i]["end"]) >= from:
			lap.gaps.remove_at(i)
	for i: int in range(lap.fences.size() - 1, -1, -1):
		var f: float = float(lap.fences[i]["at"])
		if f >= from - 0.5 and f <= to + 0.5:
			lap.fences.remove_at(i)


## The bait spots reaching into [from, to] (track distances), in order: {at, lane, kind, far, key}.
func spots_between(from: float, to: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if arena == null or arena.laps.is_empty():
		return out
	for k: int in range(maxi(arena.lap_at(from), 0), arena.lap_at(to) + 1):
		var offset: float = k * arena.lap_length
		for s: Dictionary in _spot_plan.get(k % arena.laps.size(), []):
			var at: float = float(s["at"]) + offset
			if at >= from and at <= to:
				out.append({"at": at, "lane": int(s["lane"]), "kind": s["kind"], "far": float(s["far"]) + offset,
					"key": snappedf(at, 0.01)})
	return out


## The host spots reaching into [from, to] (their ramps' track distances), in order: {at, side, lane, from, to,
## drop, key}.
func host_spots_between(from: float, to: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if arena == null or arena.laps.is_empty():
		return out
	for k: int in range(maxi(arena.lap_at(from), 0), arena.lap_at(to) + 1):
		var offset: float = k * arena.lap_length
		for s: Dictionary in _host_plan.get(k % arena.laps.size(), []):
			var at: float = float(s["at"]) + offset
			if at >= from and at <= to:
				out.append({"at": at, "side": int(s["side"]), "lane": int(s["lane"]), "from": float(s["from"]) + offset,
					"to": float(s["to"]) + offset, "drop": float(s["drop"]) + offset, "key": snappedf(at, 0.01)})
	return out


## The next bait spot whose surge hasn't come and whose warning point the runner hasn't passed: {at, lane,
## kind, far, key, warn_at}, or {} for none within sight (`behind`: its surge would strike from behind, which
## warns from further back). One whose moment passed unused (the runner was down, the phase changing) is
## logged (bait_missed) and skipped.
func next_spot(behind: bool = false) -> Dictionary:
	var d: float = player_distance()
	var v: float = run_speed()
	for s: Dictionary in spots_between(d - 5.0, d + SIGHT * run_pace()):
		if _used.has(s["key"]):
			continue
		var w: float = warn_at(s, behind)
		if d <= w + v * (1.5 / 60.0):
			s["warn_at"] = w
			return s
		_used[s["key"]] = true
		log_event(&"bait_missed", {"at": s["at"], "lane": s["lane"]})
	return {}


## Marks a spot's surge as come.
func use_spot(s: Dictionary) -> void:
	_used[s["key"]] = true


## True while a spot's moment hasn't come (its surge, the Host's lunge or fling, or its crouch).
func spot_unused(s: Dictionary) -> bool:
	return not _used.has(s["key"])


## Where an unbaited surge meets the runner: strike_before before the spot (behind_strike_before for a strike
## from behind: it crashes down on the lane there and runs on into the spot's bait).
func strike_at(s: Dictionary, behind: bool = false) -> float:
	return float(s["at"]) - (tuning.behind_strike_before if behind else tuning.strike_before) * run_pace()


## Where its cluster lands in the lane and charges from: the lock's distance on from the strike.
func entry_at(s: Dictionary) -> float:
	return strike_at(s) + charge_speed() * tuning.lock_seconds


## Where the runner is when its warning starts: warning_seconds before the strike (behind_warning_seconds for
## a strike from behind).
func warn_at(s: Dictionary, behind: bool = false) -> float:
	return strike_at(s, behind) - run_speed() * (tuning.behind_warning_seconds if behind else tuning.warning_seconds)


## How far a strike from behind at spot `s` can run on along its lane: behind_run_on past where it crashes
## down (the strike); its bait is the first fence or hole up to there.
func behind_reach(s: Dictionary) -> float:
	return strike_at(s, true) + tuning.behind_run_on * run_pace()


## True if the next surge strikes from behind: phase 2's surges come in turn from SewerSwarmTuning.surge_sides.
func surge_from_behind() -> bool:
	return phase_index == 1 and tuning.surge_side(phase_surges) == "behind"


## The charge's speed down the lane (m/s): charge_speed at 18 m/s, times the run's pace.
func charge_speed() -> float:
	return tuning.charge_speed * run_pace()


## How far ahead of the runner a surge's cluster gathers (the nearest station).
func surge_reach() -> float:
	return run_speed() * tuning.warning_seconds + charge_speed() * tuning.lock_seconds


## The first fence or hole a cluster charging down `lane` from `to` toward `from` (track distances) runs
## into: {kind ("fence" or "hole"), at (where it meets it: the fence, or the hole's far edge)}, or {}. Only a
## live, always-on full-height fence counts (a gapped one is open below, the swarm runs under it).
func bait_between(lane: int, from: float, to: float) -> Dictionary:
	var best: Dictionary = {}
	if arena == null:
		return best
	var layout: LevelLayout = arena.layout
	for f: Dictionary in layout.fences:
		if int(f["lane"]) != lane or f.get("disabled", false) or String(f["variant"]) != "full" or bool(f.get("pulsing", false)):
			continue
		var a: float = float(f["at"])
		if a >= from and a <= to and (best.is_empty() or a > float(best["at"])):
			best = {"kind": "fence", "at": a}
	for g: Dictionary in layout.gaps:
		if int(g["lane"]) != lane:
			continue
		var e: float = float(g["end"])
		var s: float = float(g["start"])
		# A cluster coming down from `to` drops in at the far edge (or at once, if it's over the hole already).
		var meet: float = minf(e, to)
		if meet >= from and s <= to and (best.is_empty() or meet > float(best["at"])):
			best = {"kind": "hole", "at": meet}
	return best


## The first live full fence the Host lunging down `lane` from `to` toward `from` meets: {kind, at}, or {} (GDD
## §10: its lunge can be baited into a fence; it bounds over holes).
func fence_between(lane: int, from: float, to: float) -> Dictionary:
	var hit: Dictionary = {}
	if arena == null:
		return hit
	for f: Dictionary in arena.layout.fences:
		if int(f["lane"]) != lane or f.get("disabled", false) or String(f["variant"]) != "full" or bool(f.get("pulsing", false)):
			continue
		var a: float = float(f["at"])
		if a >= from and a <= to and (hit.is_empty() or a > float(hit["at"])):
			hit = {"kind": "fence", "at": a}
	return hit


## The first fence or hole a cluster charging along `lane` from `from` toward `to` (track distances, `to`
## further: a strike from behind) runs into: {kind, at (where it meets it: the fence, or the hole's near edge)},
## or {}. Only a live, always-on full-height fence counts.
func bait_ahead(lane: int, from: float, to: float) -> Dictionary:
	var best: Dictionary = {}
	if arena == null:
		return best
	var layout: LevelLayout = arena.layout
	for f: Dictionary in layout.fences:
		if int(f["lane"]) != lane or f.get("disabled", false) or String(f["variant"]) != "full" or bool(f.get("pulsing", false)):
			continue
		var a: float = float(f["at"])
		if a >= from and a <= to and (best.is_empty() or a < float(best["at"])):
			best = {"kind": "fence", "at": a}
	for g: Dictionary in layout.gaps:
		if int(g["lane"]) != lane:
			continue
		var s: float = float(g["start"])
		var e: float = float(g["end"])
		var meet: float = maxf(s, from)
		if meet <= to and e >= from and (best.is_empty() or meet < float(best["at"])):
			best = {"kind": "hole", "at": meet}
	return best


# --- Helpers ---------------------------------------------------------------------------------------

## The run's speed over the reference 18 m/s (MovementTuning.pace()): the tuning's distances that stand for a
## time are written at 18 m/s and multiplied by it. (Not the phase's pace().)
func run_pace() -> float:
	if world != null and world.tuning != null:
		return world.tuning.pace()
	if arena != null and arena.tuning != null:
		return arena.tuning.pace()
	return 1.0


## The run's speed (m/s): the surges are timed by it (a dash's moment of extra speed changes nothing planned).
func run_speed() -> float:
	if world != null and world.tuning != null:
		return world.tuning.run_speed
	return MovementTuning.REFERENCE_SPEED


## The lane the runner is in or heading for (a wall runner counts as the outer lane on that side).
func player_lane() -> int:
	var p: Player = world.player
	if p.surface == Player.Surface.WALL:
		return 0 if p.wall_side < 0 else lane_count() - 1
	return clampi(p.lane, 0, lane_count() - 1)


## Plays a sound at `pos` and notes it (every warning is heard: tests read the notes).
func sound(sound_name: StringName, pos: Vector3) -> void:
	world.play_sfx_at(sound_name, pos)
	log_event(&"sound", {"name": sound_name})


## Where a sound of the cluster gathering at `side` and `at` plays: by its wall, never far out of earshot.
func sound_point(side: int, at: float) -> Vector3:
	var d: float = minf(at, player_distance() + SOUND_AHEAD * run_pace())
	return Vector3(side * (world.geo.wall_x() - 0.5), 0.6, TrackGeometry.world_z(d))


## Asks for a first-time hint of its own (boss:gangland_boss/<key>), once a fight.
func hint(key: String) -> void:
	if _hinted.has(key):
		return
	_hinted[key] = true
	hint_due.emit("%s/%s" % [def.id, key])


## True while one of its surges or the Host's attacks warns or strikes.
func warning_active() -> bool:
	return (surges != null and surges.busy()) or (host_attacks != null and host_attacks.busy())


# --- Building the swarm ----------------------------------------------------------------------------

func _build_boss() -> void:
	tuning = _tuning()
	if not low_end:
		low_end = DeviceProfile.is_low_end()
	# The Host first: the boss's body (its parts[0]), hidden until phase 3.
	host = add_part(HOST_SCRIPT, {"tuning": tuning, "low_end": low_end}) as SwarmHost
	_crowds = Node3D.new()
	_crowds.name = "Crowds"
	_crowds.top_level = true
	add_child(_crowds)
	# Every crowd the fight draws, made now: as many cluster crowds as can be in play over the fight (no mesh
	# or material is made once it has begun), and the wall climb's.
	var grime: float = 1.0 if world.skin == null or world.skin.enemy_variant != &"city" else 0.0
	for i: int in crowd_pool_size():
		var crowd := SwarmCrowd.make(SwarmCrowd.Kind.CLUSTER, tuning.cluster_size(low_end), hash([String(def.id), "crowd", i]),
			grime, tuning.creature_scale)
		crowd.visible = false
		_crowds.add_child(crowd)
		_crowd_pool.append(crowd)
	var climb_crowd := SwarmCrowd.make(SwarmCrowd.Kind.CLIMB, tuning.climb_size(low_end), hash([String(def.id), "climb"]),
		grime, tuning.creature_scale)
	climb_crowd.name = "Climb"
	_crowds.add_child(climb_crowd)
	climb = SwarmClimb.new(self, climb_crowd)
	horde = SwarmHorde.new()
	add_child(horde)
	horde.setup(world, tuning, tuning.horde_size(low_end), tuning.spill_size(low_end), hash([String(def.id), "horde"]),
		_lair_floor_ok)
	surges = SwarmSurges.new(self)
	pipe = SwarmPipe.new()
	add_child(pipe)
	pipe.setup(world, tuning.pipe_height, tuning.pipe_radius)
	marks = SwarmJumpMarks.new()
	add_child(marks)
	var green: Color = (world.skin as GanglandSkin).ramp_color if world.skin is GanglandSkin else Color(0.3, 1.0, 0.35)
	marks.setup(world, tuning.jump_mark_until * run_pace(), green)
	host_attacks = SwarmHostAttacks.new(self, host, pipe, marks)
	var start: int = clampi(int(context.boss_resume.get("phase", 0)), 0, phase_count() - 1)
	for i: int in clusters_at_phase(start):
		_spawn_cluster()
	_order_queue()
	for c: SwarmCluster in queue:
		_offsets[c.get_instance_id()] = station_offset(queue.find(c))
		c.at = player_distance() + float(_offsets[c.get_instance_id()])
		c.place()


## Crowds the fight may need at once: every cluster, a flung ball, and one more while a destroyed cluster's
## death plays out as another re-forms.
func crowd_pool_size() -> int:
	return tuning.cluster_count + 2


## Clusters in play when phase `index` begins: those the phases before it haven't destroyed, and at least
## as many as it needs (none in the Host's phase).
func clusters_at_phase(index: int) -> int:
	if index >= HOST_PHASE:
		return 0
	var gone: int = 0
	var list: Array[BossPhase] = def.phase_list()
	for i: int in mini(index, list.size()):
		gone += list[i].hits
	return maxi(tuning.cluster_count - gone, list[clampi(index, 0, list.size() - 1)].hits)


## Clusters the current phase still needs (its hits still to land: weapons may have taken some health
## without a whole hit's worth), none in the Host's phase.
func clusters_needed() -> int:
	if phase_index >= HOST_PHASE or state == State.DEFEATED:
		return 0
	var remaining: float = health - phase_start_health(phase_index + 1)
	return maxi(ceili(remaining / maxf(hit_damage(), 0.001) - 0.001), 0)


## A crowd from the pool (null if it's empty: a fight that runs out draws that cluster without one).
func take_crowd() -> SwarmCrowd:
	if _crowd_pool.is_empty():
		push_warning("SewerSwarm: no crowd left in the pool")
		return null
	return _crowd_pool.pop_back()


## A destroyed cluster's crowd (or a flung ball's), back in the pool.
func release_crowd(crowd: SwarmCrowd) -> void:
	if crowd != null and not _crowd_pool.has(crowd):
		crowd.visible = false
		_crowd_pool.append(crowd)


func _spawn_cluster() -> SwarmCluster:
	var index: int = _spawned_clusters
	_spawned_clusters += 1
	var cluster := add_part(CLUSTER_SCRIPT, {"tuning": tuning, "index": index, "crowd": take_crowd()}) as SwarmCluster
	if cluster == null:
		return null
	clusters.append(cluster)
	queue.append(cluster)
	_offsets[cluster.get_instance_id()] = station_offset(queue.size() - 1)
	return cluster


## Puts the waiting clusters in order, sides alternating: the next to surge first.
func _order_queue() -> void:
	queue.sort_custom(func(a: SwarmCluster, b: SwarmCluster) -> bool: return a.index < b.index)


## Where waiting cluster `slot` (0: the next to surge) stands ahead of the runner: the next where its surge
## will gather, the others station_spacing apart behind it.
func station_offset(slot: int) -> float:
	return surge_reach() + slot * tuning.station_spacing


## The next cluster to surge (taken out of the line), or null: the first in line on `side` (the bait's side
## of the street, so it pours in close to it), or the first on either side (`side` 0, or none on that side).
func next_cluster(side: int = 0) -> SwarmCluster:
	for pass_side: int in ([side, 0] if side != 0 else [0]):
		for i: int in queue.size():
			var c: SwarmCluster = queue[i]
			if is_instance_valid(c) and c.ready_to_surge() and (pass_side == 0 or c.side == pass_side):
				queue.remove_at(i)
				return c
	return null


## A surge began (SwarmSurges): phase 2's sides take turns by it.
func note_surge() -> void:
	phase_surges += 1


## The side of the street nearer `lane` (-1 left, +1 right; 0 for the middle lane at an odd count).
func side_of_lane(lane: int) -> int:
	var mid: float = (lane_count() - 1) * 0.5
	return 0 if is_equal_approx(float(lane), mid) else (-1 if float(lane) < mid else 1)


## A cluster whose surge missed: it re-forms at the back of the line.
func requeue(cluster: SwarmCluster) -> void:
	if not is_instance_valid(cluster) or not cluster.alive:
		return
	cluster.vanish()
	queue.erase(cluster)
	if phase_index >= HOST_PHASE:
		return
	queue.append(cluster)
	_offsets[cluster.get_instance_id()] = station_offset(queue.size() - 1)
	cluster.at = player_distance() + station_offset(queue.size() - 1)
	cluster.form(tuning.reform_seconds)
	cluster.place()


## The waiting clusters keep pace at their stations, easing forward as the line moves up.
func _update_stations(delta: float) -> void:
	var d: float = player_distance()
	for i: int in queue.size():
		var c: SwarmCluster = queue[i]
		if not is_instance_valid(c) or not c.alive:
			continue
		var id: int = c.get_instance_id()
		var target: float = station_offset(i)
		var now: float = float(_offsets.get(id, target))
		now = move_toward(now, target, 14.0 * delta)
		_offsets[id] = now
		c.at = d + now
		c.rear = move_toward(c.rear, 0.0, delta * 2.0)
		c.bristle = move_toward(c.bristle, 0.25, delta * 2.0)
		if c.stage == SwarmCluster.Stage.FORMING and c.formed >= 1.0:
			c.stage = SwarmCluster.Stage.WAITING
		c.place()


## A phase short of the clusters it needs (weapons took some without a whole hit's worth of the boss's
## health) has them rise at the back of the line, so it always has clusters to bait.
func _ensure_clusters() -> void:
	var alive: int = 0
	for c: SwarmCluster in clusters:
		if is_instance_valid(c) and c.alive:
			alive += 1
	for i: int in maxi(clusters_needed() - alive, 0):
		var c: SwarmCluster = _spawn_cluster()
		if c != null:
			c.at = player_distance() + station_offset(queue.size() - 1)
			c.form(maxf(tuning.reform_seconds, 0.5), 0.3 * i)
			log_event(&"cluster_reformed", {"index": c.index})


## A manhole may stand at the street's edge on `side` at track distance `d`: no hole there in the outer lane,
## and no fence near it.
func _lair_floor_ok(side: int, d: float) -> bool:
	if arena == null:
		return true
	var lane: int = 0 if side < 0 else lane_count() - 1
	return not arena.hole_between(d - 1.2, d + 1.2, lane) and not arena.live_fence_between(d - 2.0, d + 2.0, lane)


# --- Phases --------------------------------------------------------------------------------------

func _on_phase_started(index: int) -> void:
	surges.clear()
	climb.clear()
	host_attacks.clear()
	step = Step.RISING
	step_time = 0.0
	phase_surges = 0
	if index >= HOST_PHASE:
		# The Host: any clusters left sink into the gutters; the pipe hangs ahead.
		for c: SwarmCluster in queue:
			if is_instance_valid(c):
				c.vanish()
		queue.clear()
		host_attacks.begin()
		log_event(&"the_host")
		return
	if index == 0 and carried_time <= 0.0 and context.boss_resume.is_empty():
		# The Rising: the lairs burst, the gutters fill and the clusters rise at the roadside, one after another.
		for i: int in queue.size():
			queue[i].form(maxf(phase().intro_seconds * 0.7, 0.5), 0.25 * i)
		sound(&"swarm_rise", Vector3(0.0, 0.8, TrackGeometry.world_z(player_distance() + 30.0 * run_pace())))
		log_event(&"rising")
		return
	_ensure_clusters()
	for c: SwarmCluster in queue:
		if c.formed <= 0.0 and c.formed_target <= 0.0:
			c.form(maxf(phase().intro_seconds, 0.5))
	if index == 1:
		# Surrounded: the horde surges up again behind as well as ahead.
		sound(&"swarm_rise", Vector3(0.0, 0.8, TrackGeometry.world_z(player_distance() - 6.0)))
		log_event(&"surrounded")
	else:
		log_event(&"regroup")


func _intro_tick(delta: float) -> void:
	step_time += delta
	if phase_index >= HOST_PHASE:
		host_attacks.tick(delta)
	else:
		_update_stations(delta)


func _on_pattern_started(_index: int) -> void:
	step = Step.FIGHT
	step_time = 0.0


func _pattern_tick(delta: float) -> void:
	step_time += delta
	if phase_index >= HOST_PHASE:
		host_attacks.tick(delta)
		return
	surges.tick(delta)
	if phase_index == 1:
		climb.tick(delta)
	_update_stations(delta)


## A cluster was destroyed: shocked by a fence or swallowed by a hole (baited: a skill bonus), or thinned to
## nothing by weapons. Each is the phase's hit (GDD §10: phase 1 ends when two clusters are destroyed, phase 2
## when the rest are); one weapons destroyed counts as weapon damage, within the boss's weapon_share_cap.
func _on_part_defeated(part: BossPart, cause: StringName) -> void:
	var cluster := part as SwarmCluster
	if cluster == null:
		return
	surges.cluster_destroyed(cluster)
	queue.erase(cluster)
	destroyed += 1
	destroyed_by[cause] = int(destroyed_by.get(cause, 0)) + 1
	var where: Vector3 = cluster.aim_point()
	match cause:
		&"fence":
			sound(&"swarm_shock", where)
			world.score.add_bonus(&"swarm_bait", tuning.bait_score, "Shocked!")
			world.effects.burst(where + Vector3(0.0, 0.4, 0.0), Color(1.0, 0.3, 0.7), 34, 1.1)
			world.effects.burst(where + Vector3(0.0, 0.6, 0.0), Color(1.0, 0.95, 0.9), 18, 0.8)
			world.effects.shake(0.3, 0.3)
		&"hole":
			sound(&"swarm_fall", where)
			world.score.add_bonus(&"swarm_bait", tuning.bait_score, "Into the hole!")
			world.effects.burst(where, Color(0.42, 0.34, 0.24), 22, 0.9)
			world.effects.shake(0.2, 0.25)
		_:
			sound(&"swarm_scatter", where)
			world.effects.burst(where, ScreechLair.MIST, 26, 0.9)
	log_event(&"cluster_destroyed", {"cause": cause, "index": cluster.index, "lane": cluster.lane,
		"at": snappedf(cluster.at, 0.01)})
	if state == State.FIGHT:
		damage(hit_damage(), &"weapon" if cause == &"weapon" else &"cluster")
		if state == State.FIGHT and phase_index < HOST_PHASE:
			_ensure_clusters()


## A stomp on the Host's implants (its damage follows: BossEncounter.stomp_weak_point).
func _on_weak_point_hit(part: BossPart, _hazard: Hazard) -> void:
	if part == host:
		host_attacks.stomped()


## The Host is freed (GDD §10: "the screeches scatter, the implants short out, and the person slumps free"),
## the horde drains away into the sewers.
func _on_defeated() -> void:
	surges.clear()
	climb.clear()
	if phase_index >= HOST_PHASE and host != null and host.visible:
		host_attacks.free_host()
	step = Step.BEATEN
	step_time = 0.0
	horde.drain(tuning.freed_seconds * 0.7)
	log_event(&"beaten")


func _defeated_tick(delta: float) -> void:
	step_time += delta
	if host_attacks.step == SwarmHostAttacks.Step.FREED:
		host_attacks.tick(delta)


func victory_over() -> bool:
	if world == null or world.player == null or not world.player.alive:
		return true
	return step == Step.BEATEN and step_time >= tuning.freed_seconds
