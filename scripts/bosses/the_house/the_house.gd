class_name TheHouse
extends BossEncounter
## The House, the Marketplace's boss (GDD §10): "a slot machine the size of a building, rolling down the
## market street on treads, lights blazing and jingling. Loud, gaudy and a little ridiculous", secretly the
## cult's casino (its emblem is worked into the machine's marquee). Task E5a: E5a-a built the machine, its
## arena, the spin with its three attacks and their bigger versions, the 7 buttons on the floor, the jackpot
## (the credit fountain and the hopper stomped) and weapons chipping it; E5a-b brings phases 2 and 3 (a
## button on a wall with wall fences, then one on a ceiling guarded by Barnacle Turrets), the defeat, the
## par times and the campaign's slot. Until then it plays as a preview (BossDef.preview_scene:
## ./play.sh --boss=marketplace_boss), every phase as phase 1, with a placeholder defeat.
##
## The arena (BossDef.arena, data/bosses/marketplace_boss.tres): the Marketplace's stall roofs in its look
## with nothing hung low over the street where the machine rolls (data/bosses/marketplace_boss_skin.tres),
## kept plain (_plan_lap: no holes, fences, signs, ceilings, pads, ramps or doodads; DESIGN-TBD), so the
## danger is the machine's own.
##
## Each phase (GDD §10: three phases, one stomp each):
## 1. Its intro. The first phase's is its entrance: it rolls in from far ahead, lights blazing and its
##    jingle playing, and brakes to where it paces (stand_distance, in front of the runner, keeping pace,
##    its reels facing them). A later one follows a stomp: it lurches out from under the runner, rises out
##    of the street and rolls back to where it paces (TheHouseJackpot).
## 2. Its pattern: spin after spin (GDD §10, "the spin (the warning): it paces ahead of the player and
##    yanks its giant lever. Three huge reels on its chest spin and stop one at a time, each with a ding"):
##    the lever's pull, then the reels (TheHouseReels) stop on the phase's next symbols (TheHouseTuning.
##    spin_patterns), and their attacks follow in reel order (TheHouseAttacks: cherry bombs, a rolled pink
##    fence, gold blocks; two or three of a kind a bigger version). The phase's first opening_spins spins
##    offer no buttons; every one after does (TheHouseButtons): a 7 button for each reel still spinning,
##    lighting up along the route; run over one and its reel stops on 7 and stays locked there
##    (locks_persist); pass it by and the reel stops on its symbol. Three 7s: JACKPOT (TheHouseJackpot:
##    the sirens, the fountain of credits, the hopper bursting open as it sinks; stomp it). A miss, of a
##    button or of the hopper, just means more spins (no time limit, no escalation).
## 3. A stomp on the hopper is the phase's hit (BossEncounter.stomp_weak_point: hit_damage()); weapons chip
##    at it up to BossDef.weapon_share_cap (GDD §10: "weapons chip away at it; stomps do the real damage").
##    The last stomp beats it (a placeholder defeat until E5a-b: the power dies and it sinks away).
## Every attack and every button is fair by TheHouseRoute (route_through): a way exists for a runner who
## reads the warnings and moves a reaction time after them, at every lane count, through everything else
## still on the track. Nothing depends on how long the fight has lasted; random choices come from `rng`.
## The citizens in the shop windows cheer at a jackpot and a stomp and duck at a big attack (D3's
## react() on the "market_citizens" group). Distances that stand for a time follow the run's pace
## (run_pace(): the Marketplace's 22.6 m/s in the campaign). Numbers: TheHouseTuning
## (data/bosses/marketplace_boss_tuning.tres), all DESIGN-TBD (docs/questions/e5a.md).

enum Step { ENTER, PACE, JACKPOT, DEFEAT }
enum Spin { IDLE, LEVER, SPINNING }

const BODY_SCRIPT: Script = preload("res://scripts/bosses/the_house/the_house_body.gd")
## The placeholder defeat (until E5a-b) plays out this long before the results.
const DEFEAT_SECONDS: float = 1.8
## The "market_citizens" group (MarketCitizen.GROUP, task D3).
const CITIZENS: StringName = &"market_citizens"

var body: TheHouseBody
var tuning: TheHouseTuning
var attacks: TheHouseAttacks
var buttons: TheHouseButtons
var jackpot: TheHouseJackpot
var step: Step = Step.ENTER
var step_time: float = 0.0
## Its face's track distance (where its front stands on the street).
var front_at: float = 0.0
## The spin: where it is, how long it has been there, whether it offers buttons, and what its reels will
## show (TheHouseReels.Symbol, in reel order).
var spin: Spin = Spin.IDLE
var spin_time: float = 0.0
var rigging: bool = false
var spin_symbols: Array[int] = []
## Spins this phase, its place in the phase's spin list, and spins over the fight.
var spins_this_phase: int = 0
var spin_index: int = 0
var spins: int = 0
## Citizen reactions asked for (tests).
var reactions: Dictionary = {}

var _stopped := PackedByteArray([0, 0, 0])
var _wait: float = 0.0
var _hinted: Dictionary = {}
var _route: TheHouseRoute
var _route_speed: float = -1.0
var _enter_from: float = 0.0
var _button_plan: Array[Dictionary] = []


func _build_boss() -> void:
	tuning = _tuning()
	body = add_part(BODY_SCRIPT, {"tuning": tuning}) as TheHouseBody
	attacks = TheHouseAttacks.new()
	attacks.name = "Attacks"
	add_child(attacks)
	attacks.setup(self)
	buttons = TheHouseButtons.new()
	buttons.name = "Buttons"
	add_child(buttons)
	buttons.setup(self)
	buttons.pressed.connect(_on_button_pressed)
	buttons.missed.connect(_on_button_missed)
	jackpot = TheHouseJackpot.new()
	jackpot.name = "Jackpot"
	add_child(jackpot)
	jackpot.setup(self)
	jackpot.finished.connect(_on_jackpot_finished)
	var resume: int = int(context.boss_resume.get("phase", 0))
	front_at = player_distance() + (stand_distance() if resume > 0 else tuning.enter_ahead)
	_place()


func _tuning() -> TheHouseTuning:
	var t := (def.tuning as TheHouseTuning) if def != null else null
	return t if t != null else TheHouseTuning.new()


# --- The arena -----------------------------------------------------------------------------------

## GDD §10's arena, kept plain (DESIGN-TBD, docs/questions/e5a.md): the Marketplace's stall roofs with no
## holes, fences, wall fences, signs, ceilings, pads, ramps, speed pads, doodads, floor cuts or enemies:
## the machine's attacks are the danger (phases 2 and 3 add a wall's fences and a guarded ceiling, task
## E5a-b).
func _plan_lap(lap: LevelLayout, _index: int, _arena: BossArena) -> void:
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


# --- Where it stands -----------------------------------------------------------------------------

## How far ahead of the runner its face paces: stand_ahead, or further at a speed where its longest
## warning would land closer than stand_margin to it (every attack lands between it and the runner).
func stand_distance() -> float:
	return maxf(tuning.stand_ahead, speed() * tuning.longest_warning() + tuning.stand_margin)


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


## The citizens in the shop windows react (D3: MarketCitizen.react, &"cheer" or &"startled"): GDD §10,
## "the citizens in the shop windows cheer and duck throughout".
func react_citizens(kind: StringName) -> void:
	reactions[kind] = int(reactions.get(kind, 0)) + 1
	if is_inside_tree():
		get_tree().call_group(CITIZENS, &"react", kind)


## Asks for a first-time hint of its own (boss:marketplace_boss/<key>), once a fight.
func hint(key: String) -> void:
	if _hinted.has(key):
		return
	_hinted[key] = true
	hint_due.emit("%s/%s" % [def.id, key])


## True while one of its attacks warns or strikes: its big attack, for the director.
func attack_on() -> bool:
	return attacks != null and attacks.warning_on()


## True while any of its warnings plays (a spin, an attack's).
func warning_active() -> bool:
	return attack_on() or spin != Spin.IDLE


# --- Fairness ------------------------------------------------------------------------------------

## The route finder for this run's lanes and speed.
func route() -> TheHouseRoute:
	var v: float = speed()
	if _route == null or not is_equal_approx(v, _route_speed):
		_route = TheHouseRoute.for_run(lane_count(), v, world.tuning, tuning)
		_route_speed = v
	return _route


## A way for the runner, from where they are now, through everything of its attacks still ahead plus
## `extra` obstacles, over `waypoints` ({lane, at}: buttons), to `until` or past the last obstacle by
## escape_clear_after: TheHouseRoute.find's result. They start to move a reaction time after `delay`
## seconds from now (when the warning shows).
func route_through(extra: Array[Dictionary], waypoints: Array = [], until: float = -1.0, delay: float = 0.0) -> Dictionary:
	var d0: float = world.player.distance
	var v: float = speed()
	var obs: Array[Dictionary] = attacks.obstacles(d0 - 3.0)
	obs.append_array(extra)
	var end: float = maxf(until, d0)
	for o: Dictionary in obs:
		end = maxf(end, float(o["to"]))
	for w: Dictionary in waypoints:
		end = maxf(end, float(w["at"]))
	end += tuning.escape_clear_after * run_pace()
	return route().find(player_lane(), d0, d0 + v * (delay + tuning.reaction), end, obs, waypoints)


# --- Phases --------------------------------------------------------------------------------------

func _on_phase_started(index: int) -> void:
	attacks.clear()
	buttons.clear()
	spin = Spin.IDLE
	spins_this_phase = 0
	spin_index = 0
	_reset_reels()
	if index == 0 and carried_time <= 0.0 and context.boss_resume.is_empty():
		# Its entrance: it rolls in from far ahead, lights blazing, its jingle playing.
		_set_step(Step.ENTER)
		_enter_from = front_at - player_distance()
		body.jackpot = 0.0
		sound(&"house_roll", body.reels_world())
		log_event(&"enter")
	elif jackpot.busy():
		# A stomp ended the phase before: it lurches out from under the runner and rises (the jackpot's
		# own steps), then paces again.
		_set_step(Step.JACKPOT)
		log_event(&"recover")
	else:
		_set_step(Step.PACE)
		front_at = player_distance() + stand_distance()


func _intro_tick(delta: float) -> void:
	step_time += delta
	match step:
		Step.ENTER:
			var k: float = clampf(step_time / maxf(phase().intro_seconds, 0.05), 0.0, 1.0)
			var before: float = front_at
			front_at = player_distance() + lerpf(_enter_from, stand_distance(), 1.0 - pow(1.0 - k, 2.2))
			body.track_speed = (front_at - before) / maxf(delta, 0.0001)
		Step.JACKPOT:
			jackpot.tick(delta)
			if not jackpot.busy():
				_set_step(Step.PACE)
		_:
			front_at = player_distance() + stand_distance()
			body.track_speed = speed()
	_place()


func _on_pattern_started(_index: int) -> void:
	if step == Step.ENTER:
		_set_step(Step.PACE)
	_wait = tuning.first_spin_delay / pace()


func _pattern_tick(delta: float) -> void:
	step_time += delta
	attacks.tick(delta)
	buttons.tick(delta)
	jackpot.tick(delta)
	if jackpot.busy():
		_set_step(Step.JACKPOT)
	elif step == Step.JACKPOT:
		_set_step(Step.PACE)
	if step == Step.PACE:
		front_at = player_distance() + stand_distance()
		body.track_speed = speed()
		_spin_tick(delta)
	_place()


func _on_weak_point_hit(_part: BossPart, _hazard: Hazard) -> void:
	jackpot.on_stomp()


## The last stomp: a placeholder defeat until task E5a-b (GDD §10's: the reels spin wildly and jam, "TILT"
## flashes, it collapses in an explosion of coins while the shops erupt in cheers). Its attacks stop, its
## power dies and it sinks away into the street, coins bursting from it.
func _on_defeated() -> void:
	attacks.clear()
	buttons.clear()
	spin = Spin.IDLE
	_set_step(Step.DEFEAT)
	body.power = 0.0
	body.jackpot = 0.0
	world.effects.burst(body.hopper_world(), Color(0.86, 0.66, 0.24), 60, 1.6)
	react_citizens(&"cheer")
	log_event(&"defeat")


func _defeated_tick(delta: float) -> void:
	step_time += delta
	# It sinks the rest of the way (its deck under a runner still on it until it has gone by).
	if front_at < player_distance() + 3.0:
		front_at += (speed() + tuning.lurch_speed) * delta
	else:
		body.sag = minf(body.sag + delta / 1.2, 1.25)
		front_at = maxf(front_at, player_distance() + 3.0)
	_place()


## Once its placeholder defeat has played out (or at once if the runner is gone).
func victory_over() -> bool:
	if world == null or world.player == null or not world.player.alive:
		return true
	return step == Step.DEFEAT and step_time >= DEFEAT_SECONDS


# --- The spin ------------------------------------------------------------------------------------

## The reels still spinning their symbols, in order (those not locked on 7).
func unlocked_reels() -> Array[int]:
	var out: Array[int] = []
	for i: int in 3:
		if body.reels.locked[i] == 0:
			out.append(i)
	return out


func _reset_reels() -> void:
	body.reels.unlock()
	for i: int in 3:
		if body.reels.state[i] == TheHouseReels.State.SPINNING:
			body.reels.stop(i, body.reels.shown[i])
	_stopped = PackedByteArray([0, 0, 0])


## The spin's steps: waiting for its moment (the last attack's strikes revealed and spin_gap gone, the
## jackpot over, and for a spin with buttons a fair set), the lever's pull, the reels spinning and stopping.
func _spin_tick(delta: float) -> void:
	match spin:
		Spin.IDLE:
			_wait = maxf(_wait - delta, 0.0)
			if _wait > 0.0 or attacks.busy() or jackpot.busy():
				return
			if attacks.last_reveal >= 0.0 and attacks.clock - attacks.last_reveal < tuning.spin_gap / pace():
				return
			_try_pull()
		Spin.LEVER:
			spin_time += delta
			if spin_time >= tuning.lever_seconds / pace():
				body.lever = 0.0
				for i: int in unlocked_reels():
					body.reels.spin(i)
				spin = Spin.SPINNING
				spin_time = 0.0
				sound(&"house_spin", body.reels_world())
		Spin.SPINNING:
			spin_time += delta
			if not rigging:
				for i: int in 3:
					if _stopped[i] == 0 and spin_time >= _reel_stop(i) / pace():
						_stop_reel(i, spin_symbols[i], false)
			if _stopped.count(1) >= 3:
				_result()


## Seconds after the reels start when reel `i` stops in a spin without buttons.
func _reel_stop(i: int) -> float:
	var stops: PackedFloat32Array = tuning.reel_stop_seconds
	if stops.is_empty():
		return 0.6 * (i + 1)
	return stops[mini(i, stops.size() - 1)]


## Pulls the lever if it may now: a spin with buttons (once the phase's opening spins are over) only with
## a fair set (TheHouseButtons.plan), which lights up from the pull on.
func _try_pull() -> void:
	rigging = spins_this_phase >= tuning.opening_spins_for(phase_index)
	var reels: Array[int] = unlocked_reels()
	if reels.is_empty():
		# Every reel already locked (a resumed fight): straight to the jackpot.
		rigging = true
	_button_plan = []
	if rigging and not reels.is_empty():
		_button_plan = buttons.plan(reels)
		if _button_plan.is_empty():
			return
	var list: Array[PackedStringArray] = tuning.spins_for(phase_index)
	var entry: PackedStringArray = list[spin_index % list.size()]
	spin_index += 1
	spins += 1
	spins_this_phase += 1
	spin_symbols = []
	for i: int in 3:
		spin_symbols.append(TheHouseReels.symbol_of(entry[i]))
	_stopped = PackedByteArray([0, 0, 0])
	for i: int in 3:
		if body.reels.locked[i] != 0:
			_stopped[i] = 1
	spin = Spin.LEVER
	spin_time = 0.0
	body.lever = 1.0
	sound(&"house_lever", body.global_transform * body.shape().lever_pivot)
	log_event(&"spin", {"n": spins, "rigging": rigging, "symbols": entry.duplicate(), "locked": body.reels.locked.duplicate()})
	if not _button_plan.is_empty():
		buttons.start(_button_plan)
		hint("buttons")


func _stop_reel(i: int, symbol: int, lock: bool) -> void:
	if _stopped[i] != 0:
		return
	_stopped[i] = 1
	body.reels.stop(i, symbol, lock)
	var at: Vector3 = body.global_transform * Vector3(body.shape().reel_x[i], body.shape().reels_middle().y,
		TheHouseModel.FACE_Z)
	sound(&"house_lock" if lock else &"house_ding", at)
	log_event(&"reel", {"reel": i, "symbol": TheHouseReels.symbol_name(symbol), "locked": lock})


func _on_button_pressed(reel: int) -> void:
	if spin == Spin.IDLE or reel < 0 or reel > 2:
		return
	_stop_reel(reel, TheHouseReels.Symbol.SEVEN, true)
	react_citizens(&"cheer")


func _on_button_missed(reel: int) -> void:
	if spin == Spin.IDLE or reel < 0 or reel > 2:
		return
	_stop_reel(reel, spin_symbols[reel], false)


## All three reels stopped: three 7s are the JACKPOT; otherwise their attacks follow in reel order.
func _result() -> void:
	var symbols: Array[int] = body.reels.symbols()
	var names := PackedStringArray()
	for s: int in symbols:
		names.append(TheHouseReels.symbol_name(s))
	spin = Spin.IDLE
	spin_time = 0.0
	buttons.clear()
	if symbols.count(TheHouseReels.Symbol.SEVEN) >= 3:
		log_event(&"result", {"symbols": names, "jackpot": true})
		_set_step(Step.JACKPOT)
		jackpot.start()
		return
	log_event(&"result", {"symbols": names, "jackpot": false})
	attacks.queue_spin(symbols)
	if not tuning.locks_persist:
		body.reels.unlock()


## The jackpot's window is over: after a miss it spins again (its locks gone: rig it again); after a stomp
## the next phase has begun (or it's beaten).
func _on_jackpot_finished(stomped: bool) -> void:
	body.reels.unlock()
	if is_defeated():
		return
	_set_step(Step.PACE)
	_wait = tuning.spin_gap / pace()
	if not stomped:
		log_event(&"spin_again")


func _set_step(next: Step) -> void:
	if step != next:
		step_time = 0.0
	step = next


## Puts the machine where its face stands now.
func _place() -> void:
	if body == null or not is_instance_valid(body):
		return
	body.set_pose(front_at)
