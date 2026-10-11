class_name MechaGuppyTop
extends Node3D
## Phase 3 of Mecha Guppy and Captain Cogs, "Level with Captain Cogs" (GDD §10: "the player character reaches the top
## and then is on equal footing with Captain Cogs. The captain's ship comes level with the player, fires rounds of
## attacks at the player that the player must dodge by switching lanes like normal. And there will be some waves that
## crash over the lanes that the player has to jump over, and if the player dodges these long enough, then the Mecha
## Guppy jumps over to the boss, Captain Cogs, and eats the boss"; task E5e-c). MechaGuppy begins it the moment the runner
## stands on the top (top_reached): the climb's last roof, a long tiki bar roof deck running on flat, with no more pads,
## huts, bites or bombs. From then on:
## - the minute (top_seconds, counted from top_reached): the boss bar runs down over it (GDD §10, proposed: run_down), so
##   the player sees how long is left; when it's up, the fight is won (MechaGuppy: the leap, MechaGuppyLeap);
## - Captain Cogs' ship comes level, alongside the top (CaptainCogsShip.come_level);
## - the script (MechaGuppyTuning.top_script, looped: GDD §10, a fixed, learnable script, like the Golden Convergence's
##   strafes; DESIGN-TBD): beat after beat top_beat apart from top_first, each an R (a round: MechaGuppyRounds, the
##   cannons striking every other lane, the struck lanes alternating round by round, so there is always a lane clear one
##   switch away), a W (a wave: MechaGuppyWaves, crashing over every lane: jump it) or a rest; no beat starts unless its
##   attack is over top_clear before the minute ends. Everything is timed from top_reached, by the fight's clock: nothing
##   changes with time (GDD §10: no escalation), and a retry plays the same.
## Fairness (plan(): every beat's times, the same for any runner at the run speed): each round leaves every other lane
## clear, reached in one switch, and its cannonballs reach the runner at least a reaction, a switch and dodge_margin
## after its warning shows (round_warning, round_flight, round_ahead, round_close); a wave's surge reaches them at least
## a reaction after its swell starts, and a normal jump clears it (wave_height); no beat's warning starts until the last
## beat's attack has passed the runner, so a jump and a switch are never asked for at the same moment, and a round never
## strikes a lane holding a pickup in its stretch.

## No beat's warning starts until the last beat's attack has passed the runner by this much (seconds): the beat's length
## is checked against it (plan()).
const BEAT_SPARE: float = 0.3
## A round leaves out a struck lane with a pickup within this of its stretch (metres).
const PICKUP_CLEAR: float = 3.0

var boss: MechaGuppy
var world: RunWorld
var tuning: MechaGuppyTuning
var rounds: MechaGuppyRounds
var waves: MechaGuppyWaves
## The fight time the runner reached the top (the minute counts from it), or -1 before.
var began_at: float = -1.0
## The beats planned for the minute (plan()), and how many have started.
var beats: Array[Dictionary] = []
var next_beat: int = 0
## True once the minute is up (the fight is won then).
var finished: bool = false


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	world = boss.world
	tuning = boss.tuning
	top_level = true
	transform = Transform3D.IDENTITY
	rounds = MechaGuppyRounds.new()
	rounds.name = "Rounds"
	add_child(rounds)
	rounds.setup(boss)
	waves = MechaGuppyWaves.new()
	waves.name = "Waves"
	add_child(waves)
	waves.setup(boss)


## True once phase 3's minute has begun (the runner reached the top).
func started() -> bool:
	return began_at >= 0.0


## The runner reached the top at fight time `at`: the minute begins, the ship comes level, the script is planned.
func begin(at: float) -> void:
	if started():
		return
	began_at = at
	beats = plan(tuning)
	next_beat = 0
	if boss.ship != null:
		boss.ship.come_level()
	boss.log_event(&"top_begin", {"beats": beats.size()})


## Seconds of the minute so far (0 before it begins).
func elapsed() -> float:
	return maxf(boss.fight_time() - began_at, 0.0) if started() else 0.0


## Seconds of the minute left.
func left() -> float:
	return maxf(tuning.top_seconds - elapsed(), 0.0)


## True once the minute is up.
func over() -> bool:
	return started() and elapsed() >= tuning.top_seconds - 0.0001


## One physics step of phase 3 (MechaGuppy's ticks drive it): the rounds and the waves move, the beats start on time
## (while the pattern runs: never in an intro), and the boss bar runs down.
func tick(delta: float) -> void:
	rounds.tick(delta)
	waves.tick(delta)
	if not started() or finished:
		return
	var t: float = elapsed()
	while next_beat < beats.size() and t >= float(beats[next_beat]["at"]) - 0.0001 and boss.is_vulnerable() \
			and boss.attacks_enabled:
		_start(beats[next_beat])
		next_beat += 1
	run_down()


## GDD §10 (proposed): the boss bar runs down over the minute, from phase 3's share of the health to nothing, so the
## player sees how long is left. The fight's end itself is MechaGuppy's (a counted hit as the minute ends).
func run_down() -> void:
	if not started() or not boss.is_vulnerable():
		return
	var full: float = boss.phase_start_health(boss.phase_index)
	var want: float = full * clampf(1.0 - elapsed() / maxf(tuning.top_seconds, 0.01), 0.0, 1.0)
	# Never to nothing here: the minute's end is the fight's (its last hit), never the bar alone.
	want = maxf(want, boss.max_health * BossEncounter.EPSILON * 4.0)
	if want < boss.health:
		boss.health = want
		boss.health_changed.emit(boss.health, boss.max_health)


## Everything of phase 3's attacks off (the fight is won): the rounds and the waves gone, no more beats.
func clear() -> void:
	finished = true
	rounds.clear()
	waves.clear()


## Phase 3's beats for `t` (MechaGuppyTuning; tests check them): [{k (its place in the minute), kind (&"round", &"wave"),
## at (seconds after the top is reached), parity (a round: 0 strikes the lanes 0, 2, 4..., 1 the others; -1 for a wave),
## n (its number among its kind), lead (seconds from its warning to its attack reaching the runner), ends (seconds after
## the top: its attack past the runner)}]. The script loops from top_first, a beat every top_beat; none whose attack
## would end later than top_clear before the minute's end.
static func plan(t: MechaGuppyTuning) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var script: String = t.top_script.strip_edges()
	if script.is_empty():
		return out
	var round_lead: float = t.round_warning + t.round_flight + t.round_ahead / maxf(t.round_close, 1.0)
	var wave_lead: float = t.wave_warning + t.wave_ahead / maxf(t.wave_close, 1.0)
	var rounds_n: int = 0
	var waves_n: int = 0
	var k: int = 0
	while k < 400:
		var at: float = t.top_first + t.top_beat * float(k)
		var letter: String = script[k % script.length()].to_upper()
		k += 1
		if letter != "R" and letter != "W":
			if at > t.top_seconds:
				break
			continue
		var lead: float = round_lead if letter == "R" else wave_lead
		var ends: float = at + lead + BEAT_SPARE
		if ends > t.top_seconds - t.top_clear:
			break
		if letter == "R":
			out.append({"k": k - 1, "kind": &"round", "at": at, "parity": rounds_n % 2, "n": rounds_n, "lead": lead,
				"ends": ends})
			rounds_n += 1
		else:
			out.append({"k": k - 1, "kind": &"wave", "at": at, "parity": -1, "n": waves_n, "lead": lead, "ends": ends})
			waves_n += 1
	return out


## The lanes a round of `parity` strikes on `lanes` lanes (every other lane: 0 the lanes 0, 2, 4..., 1 the others).
static func struck(parity: int, lanes: int) -> Array[int]:
	var out: Array[int] = []
	for lane: int in lanes:
		if lane % 2 == parity:
			out.append(lane)
	return out


func _start(beat: Dictionary) -> void:
	if beat["kind"] == &"round":
		var lanes: Array[int] = []
		var r: Dictionary = rounds.timing(world.player.speed)
		var d: float = world.player.distance
		for lane: int in struck(int(beat["parity"]), boss.lane_count()):
			if not _pickup_in(lane, d + float(r["meet_ahead"]) - PICKUP_CLEAR, d + float(r["land_ahead"]) + PICKUP_CLEAR):
				lanes.append(lane)
		if lanes.is_empty():
			boss.log_event(&"round_skipped", {"k": int(beat["k"])})
			return
		rounds.fire(int(beat["k"]), lanes)
	else:
		waves.start(int(beat["k"]))


## True if a pickup waits in `lane` between track distances `from` and `to`.
func _pickup_in(lane: int, from: float, to: float) -> bool:
	if world.pickups == null:
		return false
	for p: Pickup in world.pickups.active:
		if is_instance_valid(p) and p.lane == lane and p.at >= from and p.at <= to:
			return true
	return false
