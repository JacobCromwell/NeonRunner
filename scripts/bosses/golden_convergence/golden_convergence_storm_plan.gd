class_name GoldenConvergenceStormPlan
extends RefCounted
## The Screen Storm's fairness (GDD §10, the owner's playtest, approved: "a storm drops 10-16 screens over about
## 5 s, planned so a runner who moves a reaction time after each warning always has a way through"; task E5d-e):
## which lane each screen may crash in, chosen as its warning begins (from the runner's lane then: the screens come
## down on either side of the runner and in their lane), so that a runner who reads the warnings always has a way
## through at any lane count, never asked to jump into or switch into another square's crash. Pure numbers in
## seconds from the storm's start (where the runner is along the track follows from the run speed:
## GoldenConvergenceScreens), so the tests play thousands of storms without the engine. The model's runner (The
## House's way: TheHouseRoute's reaction and switch margin) stays in their lane until a warning shows in it, then,
## `reaction` later, switches to a neighbouring lane that showed no warning when theirs appeared; a switch takes
## `switch` (lane_switch_time times a margin), and the runner is in both lanes meanwhile.
## The rule:
## - a lane is free at time t while no screen in it is warned or crashing at t (from its warning to `margin` after
##   its touch is over);
## - a screen may be warned in lane L at time w only if L isn't reserved at w and at least one of L's neighbours is
##   free at w;
## - every neighbour free at w is then reserved (no new warning in it) until w + reaction + switch + margin, so
##   whichever of them a runner in L picks stays free while they move into it and settle; they're out of L by
##   w + reaction + switch, well before its crash at w + warning (warning_for() keeps the warning at least that
##   long, whatever F6 says).
## Every screen notes its `escapes` (its lane's neighbours free as it was warned) and `escape` (the one a runner is
## sent to: the bot's, GoldenConvergenceBot; toward the side with more free lanes, then the middle). Screens on The
## Magnate (lane -1) touch no lane. The storm's slots (when each screen crashes; which are his, which come down on
## the runner, which beside them) come from slots(); pick() places a slot's screen: one meant for the runner in their
## lane once the rule allows it there (it may wait a moment for that), one beside them in a lane around theirs, two
## lanes off rather than one (a screen next to their lane keeps theirs reserved, and then none can come down on them).

## A warning's spare over the time a runner needs to get out of its lane (warning_for: F6's ranges never leave
## less).
const WARN_SPARE: float = 0.1
## A slot meant for the runner waits at most ON_WAIT for the rule to let it come down in their lane (then it comes
## down beside them); a slot no lane may take yet waits at most SLOT_SLACK, then it's let go.
const ON_WAIT: float = 0.4
const SLOT_SLACK: float = 0.5
## How a screen beside the runner picks its lane (by lanes from the runner's: never theirs, two off rather than one,
## further ones less), and how much less it likes the lane it just struck.
const BESIDE_WEIGHTS: Array[float] = [0.0, 1.0, 1.6, 0.6, 0.4, 0.3, 0.25]
const REPEAT_WEIGHT: float = 0.35

var lanes: int = 3
## Seconds: a screen's warning before its crash, its touch's life, the runner's reaction, a lane switch (with its
## margin), the spare around each crash.
var warning: float = 0.9
var touch: float = 0.1
var reaction: float = 0.35
var switch: float = 0.21
var margin: float = 0.1
## The screens warned so far: {n, lane (-1: on him), warn, crash, escapes: Array[int], escape}.
var screens: Array[Dictionary] = []
## Per lane, the time until which no new warning may show in it.
var reserved := PackedFloat32Array()
## The storm's slots (slots(): {crash, him, on}, crash times from `first_warn`), the next to warn, and the slots let
## go (place_due).
var storm_slots: Array[Dictionary] = []
var next_slot: int = 0
var first_warn: float = 0.0
var dropped: int = 0

var _last_lane: int = -1


## A plan for a storm at `p_lanes` lanes with the fight's tuning and movement.
static func make(p_lanes: int, t: GoldenConvergenceTuning, movement: MovementTuning) -> GoldenConvergenceStormPlan:
	var plan := GoldenConvergenceStormPlan.new()
	plan.lanes = maxi(p_lanes, 1)
	plan.touch = t.screen_hit_seconds
	plan.reaction = t.screen_reaction
	plan.switch = movement.lane_switch_time * t.screen_switch_margin
	plan.margin = t.screen_margin
	plan.warning = warning_for(t, movement)
	plan.reserved.resize(plan.lanes)
	plan.reserved.fill(-INF)
	return plan


## A screen's warning: screen_warning, or longer where the reaction, a lane switch and the spares would leave less
## (F6's ranges can't take a runner's way out of a square away).
static func warning_for(t: GoldenConvergenceTuning, movement: MovementTuning) -> float:
	var need: float = t.screen_reaction + movement.lane_switch_time * t.screen_switch_margin + t.screen_margin + WARN_SPARE
	return maxf(t.screen_warning, need)


## How many screens a storm drops at `p_lanes` lanes: storm_screens_min on 3 lanes up to storm_screens_max on 6.
static func count_for(t: GoldenConvergenceTuning, p_lanes: int) -> int:
	var k: float = clampf(float(p_lanes - 3) / 3.0, 0.0, 1.0)
	return maxi(roundi(lerpf(float(t.storm_screens_min), float(t.storm_screens_max), k)), 1)


## The storm's slots: `count` crashes over `seconds` from 0 (evenly, each moved a little by `rng`), `hits` of them
## on him spread through it (never the first: the storm opens on the track), the track's taking turns to come down
## on the runner (`on`, the first of them) and beside them. [{crash, him, on}], by time.
static func slots(count: int, hits: int, seconds: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: int = maxi(count, 1)
	var step: float = seconds / maxf(float(n - 1), 1.0)
	for i: int in n:
		var jitter: float = rng.randf_range(-0.18, 0.18) * step if i > 0 and i < n - 1 else 0.0
		out.append({"crash": float(i) * step + jitter, "him": false, "on": false})
	var k: int = clampi(hits, 0, n - 1)
	if k > 0:
		var shift: float = rng.randf_range(-0.2, 0.2)
		var taken: Dictionary = {}
		for j: int in k:
			var at: int = clampi(floori((float(j) + 0.5 + shift) * float(n) / float(k)), 1, n - 1)
			while taken.has(at) and at < n - 1:
				at += 1
			while taken.has(at) and at > 1:
				at -= 1
			taken[at] = true
			out[at]["him"] = true
	var track: int = 0
	for slot: Dictionary in out:
		if not bool(slot["him"]):
			slot["on"] = track % 2 == 0
			track += 1
	return out


## Takes the storm's slots (slots()), its first warning at `p_first_warn` (seconds from the storm's start).
func set_slots(p_slots: Array[Dictionary], p_first_warn: float) -> void:
	storm_slots = p_slots
	first_warn = p_first_warn
	next_slot = 0
	dropped = 0


## True once every slot is warned or let go.
func all_placed() -> bool:
	return next_slot >= storm_slots.size()


## Warns the slots whose time has come at `t` (seconds from the storm's start), the runner in `runner_lane`: his,
## and the track's, each meant for the runner in their lane once the rule allows it (waiting up to ON_WAIT, then
## beside them), or beside them around their lane (else in it); a slot no lane may take yet waits up to SLOT_SLACK,
## then it's let go (`dropped`). Returns the screens warned now (warn(), warn_on_him()), with "slot" (its index) and
## "meant" (&"him", &"on", &"beside").
func place_due(t: float, runner_lane: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	while next_slot < storm_slots.size():
		var slot: Dictionary = storm_slots[next_slot]
		var due: float = first_warn + float(slot["crash"])
		if t < due:
			break
		if bool(slot["him"]):
			var s: Dictionary = warn_on_him(t)
			s["slot"] = next_slot
			s["meant"] = &"him"
			out.append(s)
			next_slot += 1
			continue
		var on: bool = bool(slot.get("on", false))
		var lane: int = pick(t, runner_lane, rng, on)
		if lane < 0 and (not on or t > due + ON_WAIT):
			lane = pick(t, runner_lane, rng, not on)
		if lane >= 0:
			var s: Dictionary = warn(lane, t)
			s["slot"] = next_slot
			s["meant"] = &"on" if on else &"beside"
			out.append(s)
			next_slot += 1
			continue
		if t > due + SLOT_SLACK:
			dropped += 1
			next_slot += 1
			continue
		break
	return out


## True while no screen in `lane` is warned or crashing at `t` (seconds from the storm's start), with the margin.
func free_at(lane: int, t: float) -> bool:
	if lane < 0 or lane >= lanes:
		return false
	for s: Dictionary in screens:
		if int(s["lane"]) == lane and float(s["warn"]) <= t + margin and float(s["crash"]) + touch + margin >= t:
			return false
	return true


## The neighbours of `lane` free at `t`.
func free_neighbours(lane: int, t: float) -> Array[int]:
	var out: Array[int] = []
	for other: int in [lane - 1, lane + 1]:
		if free_at(other, t):
			out.append(other)
	return out


## True if a screen may be warned in `lane` at `t` (the rule above).
func can_warn(lane: int, t: float) -> bool:
	if lane < 0 or lane >= lanes or reserved[lane] > t:
		return false
	return not free_neighbours(lane, t).is_empty()


## The lane for a screen warned at `t` with the runner in `runner_lane`: `on` (meant for the runner) their lane if the
## rule allows it now, else -1 (the caller may wait a moment, or ask for one beside them instead); beside them, a lane
## the rule allows around theirs, picked by `rng` (BESIDE_WEIGHTS; less the lane struck last), or -1 if none may be
## warned now.
func pick(t: float, runner_lane: int, rng: RandomNumberGenerator, on: bool = false) -> int:
	if on:
		return runner_lane if can_warn(runner_lane, t) else -1
	var total: float = 0.0
	var weights: Array[float] = []
	for lane: int in lanes:
		var w: float = 0.0
		if can_warn(lane, t):
			w = BESIDE_WEIGHTS[mini(absi(lane - runner_lane), BESIDE_WEIGHTS.size() - 1)]
			if lane == _last_lane:
				w *= REPEAT_WEIGHT
		weights.append(w)
		total += w
	if total <= 0.0:
		return -1
	var roll: float = rng.randf() * total
	for lane: int in lanes:
		roll -= weights[lane]
		if weights[lane] > 0.0 and roll <= 0.0:
			return lane
	for lane: int in range(lanes - 1, -1, -1):
		if weights[lane] > 0.0:
			return lane
	return -1


## Warns a screen in `lane` at `t` (can_warn must allow it): notes it, reserves its free neighbours. Returns it.
func warn(lane: int, t: float) -> Dictionary:
	var escapes: Array[int] = free_neighbours(lane, t)
	for other: int in escapes:
		reserved[other] = maxf(reserved[other], t + reaction + switch + margin)
	var s: Dictionary = {"n": screens.size(), "lane": lane, "warn": t, "crash": t + warning, "escapes": escapes,
		"escape": _best_escape(lane, escapes, t)}
	screens.append(s)
	_last_lane = lane
	return s


## Warns a screen that comes down on him at `t` (no lane).
func warn_on_him(t: float) -> Dictionary:
	var s: Dictionary = {"n": screens.size(), "lane": -1, "warn": t, "crash": t + warning, "escapes": [] as Array[int],
		"escape": -1}
	screens.append(s)
	return s


## The escape a runner is sent to: of `escapes`, the one with more free lanes beyond it at `t`, then the nearer the
## middle, then the left.
func _best_escape(lane: int, escapes: Array[int], t: float) -> int:
	if escapes.is_empty():
		return -1
	var best: int = escapes[0]
	var best_room: int = -1
	var mid: float = (lanes - 1) * 0.5
	for e: int in escapes:
		var dir: int = signi(e - lane)
		var room: int = 0
		var k: int = e + dir
		while k >= 0 and k < lanes and free_at(k, t):
			room += 1
			k += dir
		if room > best_room or (room == best_room and absf(float(e) - mid) < absf(float(best) - mid)):
			best = e
			best_room = room
	return best


## True if a screen in `lane` crashes (its touch live, with the margin) at some time in [from, to].
func strikes(lane: int, from: float, to: float) -> bool:
	for s: Dictionary in screens:
		if int(s["lane"]) != lane:
			continue
		if float(s["crash"]) - margin <= to and float(s["crash"]) + touch + margin >= from:
			return true
	return false


## Screens warned in lanes (not on him) so far.
func lane_screens() -> int:
	var n: int = 0
	for s: Dictionary in screens:
		if int(s["lane"]) >= 0:
			n += 1
	return n
