class_name HostileTakeover
extends BossEncounter
## Hostile Takeover, the Corporate zone's boss (GDD §10): "corporations and the military are one and the
## same in this zone, so the boss is a merger, literally". Task E5b: E5b-a built the arena (the Chairman's
## train), the gunship and the locomotive, and phase 1 (The Board: its guards and the carriage couplings);
## E5b-b phase 2 (The Contract: the gunship's strafes, the Buzz Overdrive it drops, the armored carriage
## passed on its belly, its drop bay the weak point); E5b-c brings phase 3 (The Merger), the defeat, the
## par times and the campaign's slot. Until then it plays as a preview (BossDef.preview_scene:
## ./play.sh --boss=corporate_boss), phase 3 playing The Board again, with a placeholder defeat.
##
## The arena is the boss (GDD §10: "the player lands on the rear roof of the Chairman's armored maglev train
## ... and runs forward along it toward the locomotive. Carriage roofs are the floor and the gaps between
## carriages are the gaps, so it plays like a level"): the arena's laps are the train (_plan_lap,
## HostileTakeoverTrain: a gap across every lane at the end of each carriage, a jump at the run speed long
## enough, the corporate carriages and now and then a long flatcar in a repeating consist, the laps
## joining seamlessly), drawn by its own skin (HostileTakeoverSkin: the express's roofs, the track's sound
## barriers as the walls, the city and the street streaming past). The gunship (HostileTakeoverGunship,
## the boss's body: weapons chip it) paces the train overhead, a little ahead of the runner and swaying;
## the locomotive (HostileTakeoverLocomotive) leads the train far ahead, the Chairman watching from its rear
## window.
##
## Each phase:
## 1. Its intro: the first phase's is the entrance (the gunship sweeps in from behind and over the runner
##    with its roar and settles over the train ahead); a later one follows a stomp, the gunship lurching.
## 2. Its pattern (pattern_of): The Board in phase 1 (and phase 3, until E5b-c), The Contract in phase 2.
##    - The Board (HostileTakeoverBoard): carriage by carriage the guards come onto the roofs, a Tithe
##      Collector on each flatcar (a few a phase), partial wall fences along the barriers; and every gap's
##      coupling (HostileTakeoverCouplings) glows red in its lane from the phase's first gaps on
##      (opening_gaps of them stay dark), with the take-off cue on the roof before it and a sound as the
##      first lights up. Landing on one while jumping the gap stomps it (the phase's hit: BossEncounter.
##      stomp_weak_point); the carriages behind break away and tumble off the track (the train's material,
##      HostileTakeoverSkin.set_breakaway). A coupling passed is missed: the next gap's comes, the same way
##      (no time limit, no escalation).
##    - The Contract (HostileTakeoverContract): the gunship's strafes (HostileTakeoverStrafes), a Buzz
##      Overdrive dropped onto each flatcar, and the armored carriage after it (HostileTakeoverArmored)
##      ridden over on the gunship's belly, whose open drop bay is the phase's weak point (a stomp from
##      the ceiling). A ride whose bay isn't stomped comes around again with the next flatcar. The couplings
##      stay dark. As it begins, what phase 1 planned ahead stands down: its guards still to come never
##      do (retired as they come into play) and its wall fences switch off (the EMP's way,
##      TrackBuilder.disable_fences_near).
##    Weapons chip the gunship up to BossDef.weapon_share_cap, but never end a phase: its data turns
##    BossDef.weapons_can_end_phase off (DESIGN-TBD, docs/questions/e5b.md), so the stomps do.
## 3. The last stomp beats it (a placeholder defeat until E5b-c: the couplings go dark and the gunship
##    climbs away).
## Distances that stand for a time follow the run's pace (run_pace(): the Corporate zone's 23.4 m/s in the
## campaign); where the gunship and the locomotive fly and stand is framing, in metres. Random choices come
## from seeds of the fight and of each carriage, time from the physics step, so every attempt plays the
## same. Numbers: HostileTakeoverTuning (data/bosses/corporate_boss_tuning.tres), all DESIGN-TBD
## (docs/questions/e5b.md).

enum Step { ENTER, FLY, DEFEAT }
## A phase's pattern.
enum Pattern { BOARD, CONTRACT }

const GUNSHIP_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_gunship.gd")
const LOCOMOTIVE_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_locomotive.gd")
const COUPLINGS_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_couplings.gd")
const ARMORED_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_armored.gd")
const STRAFES_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_strafes.gd")
## No coupling glows (an intro, or a phase that doesn't play The Board).
const NONE: int = 1 << 30
## Couplings are laid over the gaps from this far behind the runner to this far ahead (the built track).
const RIG_BEHIND: float = 30.0
const RIG_AHEAD: float = 230.0
## A later phase's intro: the gunship lurches up and rolls over this long.
const LURCH_SECONDS: float = 1.6
## The placeholder defeat plays out this long before the results.
const DEFEAT_SECONDS: float = 2.4
## The breakaway stops being drawn once the carriages are this long gone.
const BREAK_GONE: float = 6.0
## Phase 1's wall fences ahead switch off as phase 2 begins: those within this of the stretch ahead.
const STAND_DOWN_REACH: float = 400.0
## A pickup's search is kept this much further off a ride than its own reach (metres): a frame's margin.
const PICKUP_MARGIN: float = 5.0

var tuning: HostileTakeoverTuning
var train: HostileTakeoverTrain
var gunship: HostileTakeoverGunship
var locomotive: HostileTakeoverLocomotive
var couplings: HostileTakeoverCouplings
var armored: HostileTakeoverArmored
var strafes: HostileTakeoverStrafes
var board: HostileTakeoverBoard
var contract: HostileTakeoverContract
var step: Step = Step.ENTER
var step_time: float = 0.0
## Couplings glow from this gap on (set as a Board phase's pattern begins; NONE otherwise).
var lit_from: int = NONE
## Gaps whose coupling has shown live, been missed and been stomped.
var shown: Dictionary = {}
var missed: Dictionary = {}
var stomped: Dictionary = {}
## The last breakaway: the gap stomped and the seconds since (-1: none yet).
var break_gap: int = -1
var break_age: float = -1.0
## Phase 1's guards retired as they came into play once its phase was over, and its wall fences switched off.
var guards_retired: int = 0
var fences_stood_down: int = 0

var _hinted: Dictionary = {}
var _phase_sounded: Dictionary = {}
var _lurch: float = 0.0


func _tuning() -> HostileTakeoverTuning:
	var t := (def.tuning as HostileTakeoverTuning) if def != null else null
	return t if t != null else HostileTakeoverTuning.new()


## Phase `index`'s pattern: The Contract in phase 2, The Board otherwise (phase 3's until task E5b-c).
static func pattern_of(index: int) -> Pattern:
	return Pattern.CONTRACT if index == 1 else Pattern.BOARD


# --- The arena: the train ----------------------------------------------------------------------

## GDD §10's arena: the Chairman's train. Every lap holds the same carriages: a gap across every lane at
## the end of each (HostileTakeoverTrain), and nothing else of the generator's (no holes, fences, signs,
## ceilings, pads, ramps, speed pads, doodads, cuts, enemies, wall fences or credits): the phases bring
## their own (phase 1: HostileTakeoverBoard; phase 2: HostileTakeoverContract).
func _plan_lap(lap: LevelLayout, _index: int, p_arena: BossArena) -> void:
	if tuning == null:
		tuning = _tuning()
	train = HostileTakeoverTrain.plan(p_arena.tuning, p_arena.lap_length, tuning)
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
	lap.gaps.append_array(train.lap_gaps(lap.lane_count))


## The enemies the fight brings onto the roofs itself, readied with the fight's load (task PERF1,
## EnemyDirector.warm_up): The Board's guards, the zone's cyborgs (the first one's look took 230 ms in its
## spawn's frame), and the Tithe Collector; The Contract's Buzz Overdrive, dropped onto a flatcar.
func warm_enemies() -> Array[Dictionary]:
	return [{"type": "cyborg", "at": 0.0, "lane": 0, "side": 0, "seed": 1, "params": {}},
		{"type": "tithe_collector", "at": 0.0, "lane": 0, "side": 0, "seed": 1, "params": {}},
		{"type": "buzz_overdrive", "at": 0.0, "lane": 0, "side": 0, "seed": 1, "params": {}}]


func _build_boss() -> void:
	tuning = _tuning()
	if train == null:
		train = HostileTakeoverTrain.plan(world.tuning, arena.lap_length if arena != null else 1000.0, tuning)
	gunship = add_part(GUNSHIP_SCRIPT, {"tuning": tuning}) as HostileTakeoverGunship
	locomotive = add_part(LOCOMOTIVE_SCRIPT, {"tuning": tuning}) as HostileTakeoverLocomotive
	couplings = add_part(COUPLINGS_SCRIPT, {"tuning": tuning, "train": train}) as HostileTakeoverCouplings
	armored = add_part(ARMORED_SCRIPT, {"tuning": tuning, "length": _corporate_roof()}) as HostileTakeoverArmored
	strafes = add_part(STRAFES_SCRIPT, {"tuning": tuning}) as HostileTakeoverStrafes
	board = HostileTakeoverBoard.new(self)
	contract = HostileTakeoverContract.new(self)
	world.director.enemy_spawned.connect(_on_enemy_spawned)
	# Made now, not mid-fight: the Collectors' credits' look.
	CreditField.mesh_for(tuning.tithe_value)
	var skin := world.skin as HostileTakeoverSkin
	if skin != null:
		skin.clear_breakaway()
	board.tick(pattern_of(phase_index) == Pattern.BOARD)
	_update_couplings()
	_place_gunship()
	locomotive.set_front(player_distance() + tuning.loco_ahead)


func _exit_tree() -> void:
	super._exit_tree()
	var skin := world.skin as HostileTakeoverSkin if world != null else null
	if skin != null:
		skin.clear_breakaway()


## A corporate carriage's roof (the armored carriage covers one).
func _corporate_roof() -> float:
	for j: int in train.kinds.size():
		if train.kinds[j] == HostileTakeoverTrain.Kind.CORPORATE:
			return train.roofs[j]
	return train.roofs[0]


# --- Helpers -----------------------------------------------------------------------------------

## The runner's speed now (m/s).
func speed() -> float:
	return maxf(world.player.speed, 1.0) if world != null and world.player != null else MovementTuning.REFERENCE_SPEED


## The run's speed over the reference 18 m/s (MovementTuning.pace()): the tuning's distances that stand for
## a time are written at 18 m/s and multiplied by it. (Not the phase's pace().)
func run_pace() -> float:
	if world != null and world.tuning != null:
		return world.tuning.pace()
	if arena != null and arena.tuning != null:
		return arena.tuning.pace()
	return 1.0


## Plays a sound at `pos` and notes it (tests read the notes).
func sound(sound_name: StringName, pos: Vector3) -> void:
	world.play_sfx_at(sound_name, pos)
	log_event(&"sound", {"name": sound_name})


## Asks for a first-time hint of its own (boss:corporate_boss/<key>), once a fight.
func hint(key: String) -> void:
	if _hinted.has(key):
		return
	_hinted[key] = true
	hint_due.emit("%s/%s" % [def.id, key])


## True if the coupling over gap `k` is live: glowing red, its weak point on.
func coupling_live(k: int) -> bool:
	return couplings != null and couplings.is_live(k)


## The live coupling the runner comes to next (its gap), or -1.
func next_live_coupling() -> int:
	var d: float = player_distance()
	var k: int = train.next_gap(d)
	for i: int in 4:
		if coupling_live(k + i) and couplings.box_span(k + i).y > d:
			return k + i
	return -1


# --- Phases ------------------------------------------------------------------------------------

func _on_phase_started(index: int) -> void:
	lit_from = NONE
	if index == 0 and carried_time <= 0.0 and context.boss_resume.is_empty():
		# The entrance: the gunship sweeps in from behind and over the runner, roaring.
		_set_step(Step.ENTER)
		sound(&"takeover_gunship", world.player.global_position + Vector3(0.0, 12.0, 20.0))
		log_event(&"enter")
	else:
		_set_step(Step.FLY)
		_lurch = LURCH_SECONDS
	if pattern_of(index) == Pattern.CONTRACT:
		_stand_down()
		# Planned from the phase's start, so its first flatcar's drop still finds the track ahead unbuilt;
		# the strafes wait for its pattern.
		contract.start()
	elif contract != null and contract.active:
		contract.stop()


## Phase 2 begins: what phase 1 planned ahead stands down. The Board stops planning, its guards still to
## come are retired as they come into play (_on_enemy_spawned) and its wall fences ahead switch off.
func _stand_down() -> void:
	if board != null:
		board.pause()
	var ahead := Vector3(0.0, 2.0, TrackGeometry.world_z(player_distance() + STAND_DOWN_REACH * 0.5))
	fences_stood_down = world.track.disable_fences_near(ahead, STAND_DOWN_REACH * 0.6)
	log_event(&"stand_down", {"wall_fences": fences_stood_down})


func _intro_tick(delta: float) -> void:
	_update(delta)


func _on_pattern_started(index: int) -> void:
	if step == Step.ENTER:
		_set_step(Step.FLY)
	if pattern_of(index) == Pattern.CONTRACT:
		lit_from = NONE
		return
	lit_from = train.next_gap(player_distance() + speed() * tuning.lit_sight) + tuning.opening_for(index)
	log_event(&"couplings_from", {"gap": lit_from, "at": train.gap_start(lit_from)})


func _pattern_tick(delta: float) -> void:
	_update(delta)


## A weak point stomped (its damage applies right after): a coupling breaks, and the carriages behind
## break away; or the gunship's drop bay bursts.
func _on_weak_point_hit(part: BossPart, hazard: Hazard) -> void:
	if part == gunship:
		_bay_stomped()
		return
	var k: int = couplings.gap_of(hazard)
	if k < 0:
		return
	var at: Vector3 = couplings.dome_world(k)
	couplings.break_open(k)
	stomped[k] = true
	break_gap = k
	break_age = 0.0
	_apply_breakaway()
	sound(&"takeover_decouple", at)
	sound(&"takeover_breakaway", at + Vector3(0.0, 0.0, 12.0))
	world.effects.burst(at, HostileTakeoverModel.WEAK, 40, 1.2)
	world.effects.debris(at, HostileTakeoverModel.GUNMETAL_LIGHT, 8, 0.9)
	world.effects.shake(0.4, 0.35)
	log_event(&"coupling_stomped", {"gap": k, "lane": int(board.lanes.get(k, -1)), "runner_lane": world.player.lane,
		"d": player_distance()})


## Phase 2's hit: the runner on its belly stomped its open drop bay. It bursts and shuts (the ride flies on
## until they drop off).
func _bay_stomped() -> void:
	var ride: Dictionary = contract.ride_now()
	if not ride.is_empty():
		ride["stomped"] = true
	var at: Vector3 = gunship.global_transform * Vector3(0.0, -0.4, -HostileTakeoverModel.BAY_AHEAD)
	gunship.set_bay(false)
	sound(&"takeover_decouple", at)
	world.effects.burst(at, HostileTakeoverModel.WEAK, 40, 1.2)
	world.effects.debris(at, HostileTakeoverModel.GUNMETAL_LIGHT, 10, 1.0)
	world.effects.shake(0.4, 0.35)
	log_event(&"bay_stomped", {"carriage": int(ride.get("k", -1)), "runner_lane": world.player.lane, "d": player_distance()})


## A ride's gunship starts down (HostileTakeoverContract): in phase 2 its drop bay opens, the weak point.
func ride_begins(ride: Dictionary) -> void:
	var open: bool = pattern_of(phase_index) == Pattern.CONTRACT and not is_defeated()
	if open:
		gunship.set_bay(true)
		sound(&"takeover_bay", gunship.global_transform * Vector3(0.0, 0.0, -HostileTakeoverModel.BAY_AHEAD))
		hint("ride")
	sound(&"takeover_gunship", gunship.global_position)
	log_event(&"ride_begins", {"carriage": ride["k"], "bay": open})


## The runner has dropped off the ride's belly: its bay shuts; in phase 2 the gunship takes on a new tank.
func ride_ends(ride: Dictionary) -> void:
	gunship.set_bay(false)
	if contract.active:
		gunship.set_saw(true)
	log_event(&"ride_landed" if ride["stomped"] else &"ride_missed", {"carriage": ride["k"], "lane": world.player.lane})


## The standard armor rule's pickup: on the floor ahead as any boss's (offer_pickup), but never on a ride's
## runway of pads, under its belly or before the runner is back on the roof (they can't take it there:
## missed, it's gone), so past the ride if the pickup's search would reach into it (_pickup_at; an offer
## still waiting for a fair spot is moved on the same way, _keep_pickups_off_rides).
func _on_armor_pickup_due(_reason: StringName) -> void:
	offer_pickup(&"armor", _pickup_at(-1.0))


## Where a pickup asked for at or after `at` may go: `at`, or past the next ride if the pickup's search
## (PickupField: lead_distance ahead of the runner, over search_window) would reach into its stretch
## (HostileTakeoverContract.ride_stretch).
func _pickup_at(at: float) -> float:
	if contract == null or world.pickups == null or world.pickups.tuning == null:
		return at
	var ride: Dictionary = contract.next_ride()
	if ride.is_empty():
		return at
	var t: PickupTuning = world.pickups.tuning
	var first: float = maxf(player_distance() + t.lead_distance, at)
	var last: float = first + t.search_window + t.clear_after + PICKUP_MARGIN
	var stretch: Vector2 = contract.ride_stretch(ride)
	if first - t.clear_before <= stretch.y and last >= stretch.x:
		return maxf(at, stretch.y + t.clear_before)
	return at


## Every frame: a pickup offer still waiting for a fair spot keeps off the rides too.
func _keep_pickups_off_rides() -> void:
	if world.pickups == null:
		return
	for offer: Dictionary in world.pickups.pending:
		offer["at"] = _pickup_at(float(offer["at"]))


## The last stomp: a placeholder defeat until task E5b-c (GDD §10's: the gunship spins away and explodes;
## the locomotive derails and ploughs through the lobby of a corporate tower). The couplings go dark and
## the gunship climbs away.
func _on_defeated() -> void:
	lit_from = NONE
	_set_step(Step.DEFEAT)
	_update_couplings()
	if contract != null:
		contract.halt()
	log_event(&"defeat")


func _defeated_tick(delta: float) -> void:
	step_time += delta
	_update_breakaway(delta)
	if contract != null:
		contract.tick(delta)
	_place_gunship()
	if is_instance_valid(locomotive):
		locomotive.set_front(player_distance() + tuning.loco_ahead)


## Once its placeholder defeat has played out (or at once if the runner is gone).
func victory_over() -> bool:
	if world == null or world.player == null or not world.player.alive:
		return true
	return step == Step.DEFEAT and step_time >= DEFEAT_SECONDS


# --- Every frame -------------------------------------------------------------------------------

func _update(delta: float) -> void:
	step_time += delta
	_lurch = maxf(_lurch - delta, 0.0)
	board.tick(pattern_of(phase_index) == Pattern.BOARD)
	contract.tick(delta)
	_keep_pickups_off_rides()
	_update_couplings()
	_update_breakaway(delta)
	_place_gunship()
	locomotive.set_front(player_distance() + tuning.loco_ahead)


## Lays the couplings over the gaps in sight (from just behind the runner to the built track's end) and
## lights the ones the pattern makes live; notes each one shown, missed or stomped.
func _update_couplings() -> void:
	var d: float = player_distance()
	couplings.release_before(d, RIG_BEHIND)
	var k: int = train.next_gap(d - RIG_BEHIND)
	var vulnerable: bool = is_vulnerable()
	while train.gap_start(k) <= d + RIG_AHEAD:
		if board.lanes.has(k):
			couplings.place(k, int(board.lanes[k]), d - RIG_BEHIND)
			var span: Vector2 = couplings.box_span(k)
			var live: bool = vulnerable and k >= lit_from and not stomped.has(k) and span.y > d
			couplings.set_live(k, live)
			if live and not shown.has(k):
				shown[k] = true
				log_event(&"coupling_lit", {"gap": k, "lane": int(board.lanes[k]), "ahead": train.gap_start(k) - d})
				if not _phase_sounded.has(phase_index):
					_phase_sounded[phase_index] = true
					sound(&"takeover_couplings", couplings.dome_world(k))
					hint("couplings")
			if shown.has(k) and not stomped.has(k) and not missed.has(k) and span.y <= d and k >= lit_from:
				missed[k] = true
				log_event(&"coupling_missed", {"gap": k, "lane": int(board.lanes[k])})
		k += 1
	couplings.arm(vulnerable)


## The breakaway's clock, on the train's material.
func _update_breakaway(delta: float) -> void:
	if break_age < 0.0:
		return
	break_age += delta
	_apply_breakaway()


func _apply_breakaway() -> void:
	var skin := world.skin as HostileTakeoverSkin
	if skin == null or break_gap < 0:
		return
	if break_age > BREAK_GONE:
		skin.clear_breakaway()
		return
	skin.set_breakaway(train.gap_start(break_gap), maxf(break_age - tuning.break_delay, 0.0001),
		train.ends_behind(break_gap, 8), tuning)


## Where the gunship flies at its station (relative to the runner, swaying and bobbing on the fight's
## clock): {middle (its middle's track distance), y, x, roll, pitch}.
func station_pose() -> Dictionary:
	var t: float = fight_time()
	return {
		"middle": player_distance() + tuning.gunship_ahead + HostileTakeoverModel.GUNSHIP_LENGTH * 0.5,
		"y": tuning.gunship_height + tuning.gunship_bob * sin(TAU * t / 3.1),
		"x": tuning.gunship_sway * sin(TAU * t / maxf(tuning.gunship_sway_seconds, 0.5)),
		"roll": -0.07 * cos(TAU * t / maxf(tuning.gunship_sway_seconds, 0.5)),
		"pitch": 0.02 * sin(TAU * t / 4.3),
	}


## Flies the gunship over the train: at its station, or as phase 2's contract flies it (a drop, a ride, a
## strafe); in the entrance it eases in from behind and above; in a later intro it lurches up and rolls
## (never while it's low over a ride); beaten, it climbs away.
func _place_gunship() -> void:
	if not is_instance_valid(gunship):
		return
	var d: float = player_distance()
	var pose: Dictionary = station_pose()
	if contract != null:
		pose = contract.pose(pose, d)
	var riding: bool = contract != null and contract.riding(d)
	var middle: float = float(pose["middle"])
	var y: float = float(pose["y"])
	var roll: float = float(pose["roll"])
	var pitch: float = float(pose["pitch"])
	match step:
		Step.ENTER:
			var k: float = clampf(state_time / maxf(phase().intro_seconds, 0.05), 0.0, 1.0)
			var e: float = 1.0 - pow(1.0 - k, 2.4)
			middle -= tuning.gunship_enter_behind * (1.0 - e)
			y += tuning.gunship_enter_rise * (1.0 - e)
			pitch -= 0.12 * (1.0 - e)
		Step.DEFEAT:
			if not riding:
				var c: float = minf(step_time / DEFEAT_SECONDS, 1.0)
				middle += 60.0 * c * c
				y += 24.0 * c * c
				roll += 0.5 * c
				pitch += 0.25 * c
	if _lurch > 0.0 and not riding:
		var l: float = sin(PI * (1.0 - _lurch / LURCH_SECONDS))
		y += 3.0 * l
		roll += 0.35 * l
	gunship.set_pose(Vector3(float(pose["x"]), y, TrackGeometry.world_z(middle)), roll, pitch)


func _set_step(next: Step) -> void:
	if step != next:
		step_time = 0.0
	step = next


## An enemy came into play: a Tithe Collector gets its credits to skim; one of phase 1's guards coming in
## once its phase is over is retired at once (never seen: it stood beyond the built track).
func _on_enemy_spawned(enemy: Enemy) -> void:
	if enemy == null or is_defeated():
		return
	if enemy.type_id == &"cyborg" and enemy.spawn.has("board_phase") and int(enemy.spawn["board_phase"]) != phase_index:
		guards_retired += 1
		enemy.retire()
		return
	if enemy.type_id != &"tithe_collector":
		return
	board.lay_tithe(enemy)
