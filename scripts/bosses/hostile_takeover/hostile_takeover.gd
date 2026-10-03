class_name HostileTakeover
extends BossEncounter
## Hostile Takeover, the Corporate zone's boss (GDD §10): "corporations and the military are one and the
## same in this zone, so the boss is a merger, literally". Task E5b: E5b-a built the arena (the Chairman's
## train), the gunship and the locomotive, and phase 1 (The Board: its guards and the carriage couplings);
## E5b-b phase 2 (The Contract: the gunship's strafes, the Buzz Overdrive it drops, the armored carriage
## passed on its belly, its drop bay the weak point); E5b-c phase 3 (The Merger: the gunship docked onto the
## locomotive, its three docking clamps the weak points), the defeat, the par times and its slot in the
## campaign (after Corporate 2, at the zone's 23.4 m/s).
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
## 2. Its pattern (pattern_of): The Board in phase 1, The Contract in phase 2, The Merger in phase 3.
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
##    - The Merger: once phase 2's last ride is over, the docking (Step.DOCK): the locomotive comes back
##      from far ahead to merger_ahead while the gunship settles onto its rear, its huge arms gripping it and
##      its three docking clamps unfolding under its belly (HostileTakeoverGunship.set_docked), and
##      "MERGER COMPLETE" flashes on every screen with the Chairman's face (HostileTakeoverScreens; steady
##      with Reduced flashing). Then the war engine leads the train (Step.MERGED) and its attacks combine
##      both phases' (GDD §10): the Board's guards and wall fences on some carriages
##      (HostileTakeoverBoard.merger), the strafes, a Buzz Overdrive dropped onto each flatcar, and after
##      each a pass (HostileTakeoverContract.plan_pass): the war engine comes back over the runner, a runway
##      of pads before it, and they ride its belly forward under its three glowing red clamps; a jump from
##      the belly that comes back up onto one stomps it and tears it loose. Missed clamps come around in the
##      next pass (no time limit, no escalation); the third one beats it.
##    Weapons chip the gunship up to BossDef.weapon_share_cap, but never end a phase: its data turns
##    BossDef.weapons_can_end_phase off (DESIGN-TBD, docs/questions/e5b.md), so the stomps do, each phase's
##    hits counted (phase 3 always takes its three clamps).
## 3. The defeat (GDD §10: "the gunship spins away and explodes; the locomotive derails and ploughs through
##    the lobby of a corporate tower, bringing down a giant, soulless logo sculpture"): the last clamp torn
##    loose, the gunship pulls free and spins away, exploding explode_at seconds later; the locomotive
##    leaves the guideway toward a corporate tower beside the line (HostileTakeoverLobby) and ploughs
##    through its sky lobby crash_at seconds in, its plaza's logo sculpture toppling; the screens glitch and
##    go dark (still with Reduced flashing). The results follow defeat_seconds after the stomp.
## Distances that stand for a time follow the run's pace (run_pace(): the Corporate zone's 23.4 m/s in the
## campaign); where the gunship and the locomotive fly and stand is framing, in metres. Random choices come
## from seeds of the fight and of each carriage, time from the physics step, so every attempt plays the
## same. Numbers: HostileTakeoverTuning (data/bosses/corporate_boss_tuning.tres), all DESIGN-TBD
## (docs/questions/e5b.md).

enum Step { ENTER, FLY, DOCK, MERGED, DEFEAT }
## A phase's pattern.
enum Pattern { BOARD, CONTRACT, MERGER }

const GUNSHIP_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_gunship.gd")
const LOCOMOTIVE_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_locomotive.gd")
const COUPLINGS_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_couplings.gd")
const ARMORED_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_armored.gd")
const STRAFES_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_strafes.gd")
const SCREENS_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_screens.gd")
const LOBBY_SCRIPT: Script = preload("res://scripts/bosses/hostile_takeover/hostile_takeover_lobby.gd")
## No coupling glows (an intro, or a phase that doesn't play The Board).
const NONE: int = 1 << 30
## Couplings are laid over the gaps from this far behind the runner to this far ahead (the built track).
const RIG_BEHIND: float = 30.0
const RIG_AHEAD: float = 230.0
## A later phase's intro: the gunship lurches up and rolls over this long.
const LURCH_SECONDS: float = 1.6
## The breakaway stops being drawn once the carriages are this long gone.
const BREAK_GONE: float = 6.0
## Phase 1's wall fences ahead switch off as phase 2 begins: those within this of the stretch ahead.
const STAND_DOWN_REACH: float = 400.0
## A pickup's search is kept this much further off a ride than its own reach (metres): a frame's margin.
const PICKUP_MARGIN: float = 5.0
## Docked, the gunship's middle is this far behind the locomotive's rear face (its nose over the
## locomotive's roof, its belly's front just behind its face).
const DOCK_OFFSET: float = 12.0
## The docking's clamps lock this far through it.
const CLAMPS_LOCK_AT: float = 0.7
## The defeat: the locomotive ploughs into the lobby this far ahead of the runner (metres at 18 m/s), its
## rear face ending this far short of the lobby's middle and this far past the barrier, turned this much.
const LOBBY_AHEAD: float = 40.0
const DERAIL_SHORT: float = 22.0
const DERAIL_OUT: float = 3.0
const DERAIL_YAW: float = 0.6
## The sculpture topples over this long, and the screens go dark this long into the defeat.
const TOPPLE_SECONDS: float = 1.1
const SCREENS_DARK_AT: float = 0.9

var tuning: HostileTakeoverTuning
var train: HostileTakeoverTrain
var gunship: HostileTakeoverGunship
var locomotive: HostileTakeoverLocomotive
var couplings: HostileTakeoverCouplings
var armored: HostileTakeoverArmored
var strafes: HostileTakeoverStrafes
var screens: HostileTakeoverScreens
var lobby: HostileTakeoverLobby
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
## Phase 3: the war engine has docked (the contract flies it), and the clamps torn loose so far.
var docked: bool = false
var clamps_torn: int = 0

var _hinted: Dictionary = {}
var _phase_sounded: Dictionary = {}
var _lurch: float = 0.0
## The docking's start: how far ahead the locomotive was.
var _dock_loco: float = 0.0
## The defeat's start: the runner's distance, the gunship's pose, the locomotive's front; where the lobby
## stands; what has happened so far.
var _defeat_d: float = 0.0
var _defeat_pose: Dictionary = {}
var _defeat_loco: float = 0.0
var _lobby_at: float = 0.0
var _exploded: bool = false
var _crashed: bool = false


func _tuning() -> HostileTakeoverTuning:
	var t := (def.tuning as HostileTakeoverTuning) if def != null else null
	return t if t != null else HostileTakeoverTuning.new()


## Phase `index`'s pattern: The Board in phase 1, The Contract in phase 2, The Merger in phase 3.
static func pattern_of(index: int) -> Pattern:
	if index <= 0:
		return Pattern.BOARD
	return Pattern.CONTRACT if index == 1 else Pattern.MERGER


# --- The arena: the train ----------------------------------------------------------------------

## GDD §10's arena: the Chairman's train. Every lap holds the same carriages: a gap across every lane at
## the end of each (HostileTakeoverTrain), and nothing else of the generator's (no holes, fences, signs,
## ceilings, pads, ramps, speed pads, doodads, cuts, enemies, wall fences or credits): the phases bring
## their own (HostileTakeoverBoard, HostileTakeoverContract).
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
## spawn's frame), and the Tithe Collector; The Contract's and The Merger's Buzz Overdrive, dropped onto a
## flatcar. (Its own parts, phase 3's among them, are built with the fight and hidden till they're needed,
## so the shader warm-up draws them during the load too.)
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
	screens = add_part(SCREENS_SCRIPT, {"tuning": tuning, "locomotive": locomotive}) as HostileTakeoverScreens
	lobby = add_part(LOBBY_SCRIPT, {}) as HostileTakeoverLobby
	board = HostileTakeoverBoard.new(self)
	contract = HostileTakeoverContract.new(self)
	world.director.enemy_spawned.connect(_on_enemy_spawned)
	# Made now, not mid-fight: the Collectors' credits' look.
	CreditField.mesh_for(tuning.tithe_value)
	var skin := world.skin as HostileTakeoverSkin
	if skin != null:
		skin.clear_breakaway()
	# The phase the fight starts at (a checkpoint's): The Board plans only if it plays it.
	board.tick(pattern_of(clampi(int(context.boss_resume.get("phase", 0)), 0, phase_count() - 1)) == Pattern.BOARD)
	_update_couplings()
	_place_gunship()


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
	match pattern_of(index):
		Pattern.CONTRACT:
			_stand_down()
			# Planned from the phase's start, so its first flatcar's drop still finds the track ahead unbuilt;
			# the strafes wait for its pattern.
			contract.start()
		Pattern.MERGER:
			# Phase 2's planned drops stay for the war engine if they come after the docking, with passes for
			# their rides (a ride under way flies through); the Board comes back for phase 3's carriages; the
			# war engine's drops and passes are planned from now on (from a checkpoint, from its start).
			board.merger = true
			if contract.active:
				contract.merge(_docking_done_at())
			else:
				contract.start(true, _docking_done_at())
		_:
			if contract != null and contract.active:
				contract.stop()


## Phase 2 begins: what phase 1 planned ahead stands down. The Board stops planning, its guards still to
## come are retired as they come into play (_on_enemy_spawned) and its wall fences ahead switch off.
func _stand_down() -> void:
	if board != null:
		board.pause()
	var ahead := Vector3(0.0, 2.0, TrackGeometry.world_z(player_distance() + STAND_DOWN_REACH * 0.5))
	fences_stood_down = world.track.disable_fences_near(ahead, STAND_DOWN_REACH * 0.6)
	log_event(&"stand_down", {"wall_fences": fences_stood_down})


## Where the runner is, at the latest, when phase 3's docking is over: after phase 2's ride still under
## way, the docking and a second.
func _docking_done_at() -> float:
	var from: float = player_distance()
	var ride: Dictionary = contract.ride_now()
	if not ride.is_empty():
		from = maxf(from, float(ride["climb_to"]))
	return from + (tuning.dock_seconds + 1.0) * world.tuning.run_speed


func _intro_tick(delta: float) -> void:
	_update(delta)


func _on_pattern_started(index: int) -> void:
	if step == Step.ENTER:
		_set_step(Step.FLY)
	if pattern_of(index) != Pattern.BOARD:
		lit_from = NONE
		return
	lit_from = train.next_gap(player_distance() + speed() * tuning.lit_sight) + tuning.opening_for(index)
	log_event(&"couplings_from", {"gap": lit_from, "at": train.gap_start(lit_from)})


func _pattern_tick(delta: float) -> void:
	_update(delta)


## A weak point stomped (its damage applies right after): a coupling breaks, and the carriages behind
## break away; the gunship's drop bay bursts; or one of its docking clamps is torn loose.
func _on_weak_point_hit(part: BossPart, hazard: Hazard) -> void:
	if part == gunship:
		var i: int = gunship.clamp_of(hazard)
		if i >= 0:
			_clamp_stomped(i)
		else:
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


## Phase 3's hit: the runner on the war engine's belly stomped docking clamp `i`. It's torn loose (its lock
## dark, its arm swung free); a third of the phase each, the last one beats it (the hits are counted:
## BossEncounter.hit_damage).
func _clamp_stomped(i: int) -> void:
	var at: Vector3 = gunship.clamp_world(i)
	gunship.tear_clamp(i)
	clamps_torn += 1
	var ride: Dictionary = contract.ride_now()
	if not ride.is_empty() and ride.has("stomps"):
		(ride["stomps"] as Array).append(i)
	sound(&"takeover_clamp", at)
	world.effects.burst(at, HostileTakeoverModel.WEAK, 36, 1.1)
	world.effects.debris(at, HostileTakeoverModel.GUNMETAL_LIGHT, 10, 1.0)
	world.effects.shake(0.45, 0.35)
	log_event(&"clamp_stomped", {"clamp": i, "side": int(gunship.clamps[i]["side"]), "left": gunship.clamps_left(),
		"runner_lane": world.player.lane, "d": player_distance()})


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


## Phase 3: the war engine comes back over the runner for a pass (HostileTakeoverContract), its clamps
## glowing under its belly.
func pass_begins(ride: Dictionary) -> void:
	sound(&"takeover_gunship", gunship.global_position)
	hint("clamps")
	log_event(&"pass_begins", {"carriage": ride["k"], "clamps": gunship.clamps_left()})


## The runner has dropped off the war engine's belly: it takes on a new tank for the next drop.
func pass_ends(ride: Dictionary) -> void:
	if contract.active:
		gunship.set_saw(true)
	var torn: int = (ride.get("stomps", []) as Array).size()
	log_event(&"pass_landed" if torn > 0 else &"pass_missed", {"carriage": ride["k"], "torn": torn, "lane": world.player.lane})


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


# --- The Merger: the docking ---------------------------------------------------------------------

## Phase 3's docking, once phase 2's last ride is over (see the header): it begins (DOCK), its clamps lock
## CLAMPS_LOCK_AT through it, and when it's done "MERGER COMPLETE" goes up on every screen (MERGED).
func _update_merger() -> void:
	if pattern_of(phase_index) != Pattern.MERGER or is_defeated():
		return
	match step:
		Step.ENTER, Step.FLY:
			if contract.ride_now().is_empty():
				_set_step(Step.DOCK)
				_dock_loco = locomotive.front_at - player_distance()
				sound(&"takeover_gunship", gunship.global_position)
				log_event(&"docking")
		Step.DOCK:
			if not gunship.docked and step_time >= tuning.dock_seconds * CLAMPS_LOCK_AT:
				gunship.set_docked(true)
				sound(&"takeover_clamps", gunship.global_transform * Vector3(0.0, 0.0, -HostileTakeoverModel.BELLY_FRONT))
				world.effects.shake(0.35, 0.3)
				log_event(&"clamps_locked")
			if step_time >= tuning.dock_seconds:
				_set_step(Step.MERGED)
				docked = true
				locomotive.set_chairman_shown(false)
				screens.set_on(true)
				sound(&"takeover_merger", locomotive.global_transform * Vector3(0.0, 3.0, 2.0))
				hint("merger")
				log_event(&"merger_complete")


## Where the docked war engine's gunship flies between passes and drops: the locomotive's rear face
## merger_ahead ahead of the runner, the gunship's belly dock_height over the roofs, steady on the line.
func docked_pose() -> Dictionary:
	return {"middle": player_distance() + tuning.merger_ahead - DOCK_OFFSET, "y": tuning.dock_height, "x": 0.0, "roll": 0.0,
		"pitch": 0.0}


# --- The defeat ----------------------------------------------------------------------------------

## The last clamp torn loose (GDD §10, see the header): everything stops; the lobby is set up ahead beside
## the line where the locomotive will plough into it; the screens glitch.
func _on_defeated() -> void:
	lit_from = NONE
	_set_step(Step.DEFEAT)
	_update_couplings()
	if contract != null:
		contract.halt()
	var d: float = player_distance()
	_defeat_d = d
	_defeat_pose = {"middle": gunship.track_distance(), "y": gunship.global_position.y, "x": gunship.global_position.x}
	_defeat_loco = locomotive.front_at
	var v: float = world.tuning.run_speed
	_lobby_at = d + v * tuning.crash_at + LOBBY_AHEAD * run_pace() + DERAIL_SHORT
	lobby.place(_lobby_at, tuning.derail_side)
	screens.set_glitch(1.0)
	gunship.set_saw(false)
	gunship.end_fall()
	sound(&"takeover_gunship", gunship.global_position)
	log_event(&"defeat", {"lobby": _lobby_at})


func _defeated_tick(delta: float) -> void:
	step_time += delta
	_update_breakaway(delta)
	if contract != null:
		contract.tick(delta)
	var t: float = step_time
	if t >= SCREENS_DARK_AT and screens.on:
		screens.set_on(false)
	if not _exploded and t >= tuning.explode_at:
		_explode()
	if not _crashed and t >= tuning.crash_at:
		_crash()
	if _crashed:
		lobby.topple((t - tuning.crash_at) / TOPPLE_SECONDS)
	_place_gunship()
	screens.pace(player_distance())


## The gunship blows up in the sky, away from the line.
func _explode() -> void:
	_exploded = true
	var at: Vector3 = gunship.global_position + Vector3(0.0, 2.0, 0.0)
	gunship.visible = false
	world.effects.burst(at, Color(1.0, 0.86, 0.6), 60, 2.6)
	world.effects.burst(at, HostileTakeoverModel.ENGINE, 30, 2.0)
	world.effects.debris(at, HostileTakeoverModel.OLIVE, 14, 1.6)
	world.effects.debris(at, HostileTakeoverModel.GUNMETAL_LIGHT, 12, 1.3)
	world.effects.shake(0.55, 0.5)
	sound(&"takeover_explode", at)
	log_event(&"gunship_exploded")


## The locomotive ploughs into the lobby; its sculpture starts to topple.
func _crash() -> void:
	_crashed = true
	var at: Vector3 = lobby.lobby_world()
	world.effects.burst(at, HostileTakeoverModel.COLD_WHITE, 50, 2.2)
	world.effects.debris(at, HostileTakeoverModel.GLASS.lightened(0.4), 16, 1.4)
	world.effects.debris(at, HostileTakeoverModel.GUNMETAL, 12, 1.6)
	world.effects.shake(0.6, 0.6)
	sound(&"takeover_derail", at)
	log_event(&"locomotive_crashed")


## Once its defeat has played out (or at once if the runner is gone).
func victory_over() -> bool:
	if world == null or world.player == null or not world.player.alive:
		return true
	return step == Step.DEFEAT and step_time >= tuning.defeat_seconds


# --- Every frame -------------------------------------------------------------------------------

func _update(delta: float) -> void:
	step_time += delta
	_lurch = maxf(_lurch - delta, 0.0)
	var pattern: Pattern = pattern_of(phase_index)
	board.merger = pattern == Pattern.MERGER
	board.tick(pattern != Pattern.CONTRACT)
	contract.tick(delta)
	_update_merger()
	_keep_pickups_off_rides()
	_update_couplings()
	_update_breakaway(delta)
	_place_gunship()
	screens.pace(player_distance())


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
## clock): {middle (its middle's track distance), y, x, roll, pitch}; docked (phase 3), the war engine's
## (docked_pose).
func station_pose() -> Dictionary:
	if docked:
		return docked_pose()
	var t: float = fight_time()
	return {
		"middle": player_distance() + tuning.gunship_ahead + HostileTakeoverModel.GUNSHIP_LENGTH * 0.5,
		"y": tuning.gunship_height + tuning.gunship_bob * sin(TAU * t / 3.1),
		"x": tuning.gunship_sway * sin(TAU * t / maxf(tuning.gunship_sway_seconds, 0.5)),
		"roll": -0.07 * cos(TAU * t / maxf(tuning.gunship_sway_seconds, 0.5)),
		"pitch": 0.02 * sin(TAU * t / 4.3),
	}


## Flies the gunship and sets the locomotive: at its station, or as the contract flies it (a drop, a ride, a
## strafe, a pass); in the entrance it eases in from behind and above; in a later intro it lurches up and
## rolls (never while it's low over a ride); docking, it settles onto the locomotive coming back; docked,
## the locomotive moves with it; beaten, the defeat (_place_defeat).
func _place_gunship() -> void:
	if not is_instance_valid(gunship) or not is_instance_valid(locomotive):
		return
	if step == Step.DEFEAT:
		_place_defeat()
		return
	var d: float = player_distance()
	var pose: Dictionary = station_pose()
	if contract != null and step != Step.DOCK:
		pose = contract.pose(pose, d)
	var riding: bool = contract != null and contract.riding(d)
	var middle: float = float(pose["middle"])
	var y: float = float(pose["y"])
	var x: float = float(pose["x"])
	var roll: float = float(pose["roll"])
	var pitch: float = float(pose["pitch"])
	var loco: float = d + tuning.loco_ahead
	match step:
		Step.ENTER:
			var k: float = clampf(state_time / maxf(phase().intro_seconds, 0.05), 0.0, 1.0)
			var e: float = 1.0 - pow(1.0 - k, 2.4)
			middle -= tuning.gunship_enter_behind * (1.0 - e)
			y += tuning.gunship_enter_rise * (1.0 - e)
			pitch -= 0.12 * (1.0 - e)
		Step.DOCK:
			var e: float = smoothstep(0.0, 1.0, step_time / maxf(tuning.dock_seconds, 0.1))
			var to: Dictionary = docked_pose()
			middle = lerpf(middle, float(to["middle"]), e)
			y = lerpf(y, float(to["y"]), e)
			x = lerpf(x, 0.0, e)
			roll = lerpf(roll, 0.0, e)
			pitch = lerpf(pitch, 0.0, e)
			loco = d + lerpf(_dock_loco, tuning.merger_ahead, e)
		Step.MERGED:
			loco = middle + DOCK_OFFSET
	if _lurch > 0.0 and not riding and step != Step.DOCK and step != Step.MERGED:
		var l: float = sin(PI * (1.0 - _lurch / LURCH_SECONDS))
		y += 3.0 * l
		roll += 0.35 * l
	gunship.set_pose(Vector3(x, y, TrackGeometry.world_z(middle)), roll, pitch)
	if step == Step.MERGED:
		# Docked: it sinks into its guideway as the gunship comes down over the runner.
		locomotive.set_pose(loco, Vector3(0.0, minf(y - tuning.dock_height, 0.0), 0.0))
	else:
		locomotive.set_front(loco)


## The defeat's motion, on its clock (see the header): the gunship pulling free of the locomotive, up and
## away from the line, spinning, until it explodes; the locomotive surging on and veering off the guideway
## into the lobby, where it stays.
func _place_defeat() -> void:
	var t: float = step_time
	var v: float = world.tuning.run_speed
	var side: float = float(tuning.derail_side if tuning.derail_side != 0 else 1)
	if not _exploded:
		var middle: float = float(_defeat_pose["middle"]) + v * t + 9.0 * t * t
		var y: float = float(_defeat_pose["y"]) + 1.5 * t + 5.0 * t * t
		var x: float = float(_defeat_pose["x"]) - side * 4.0 * t * t
		gunship.set_pose(Vector3(x, y, TrackGeometry.world_z(middle)), -side * 2.4 * t, 0.3 * t)
	var k: float = clampf(t / maxf(tuning.crash_at, 0.1), 0.0, 1.0)
	var end_front: float = _lobby_at - DERAIL_SHORT
	var front: float = lerpf(_defeat_loco, end_front, k)
	var veer: float = smoothstep(0.15, 1.0, k)
	var out: float = side * (world.geo.wall_x() + DERAIL_OUT) * veer
	locomotive.set_pose(front, Vector3(out, -0.8 * veer, 0.0), -side * DERAIL_YAW * veer, side * 0.18 * veer)


func _set_step(next: Step) -> void:
	if step != next:
		step_time = 0.0
	step = next


## An enemy came into play: a Tithe Collector gets its credits to skim; a guard planned in another phase
## coming in once that phase is over is retired at once (never seen: it stood beyond the built track).
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
