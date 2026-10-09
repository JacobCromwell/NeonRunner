class_name GoldenConvergenceBot
extends RefCounted
## A runner who plays the Golden Convergence by what it shows, for tests and reviews
## (tools/showcase/golden_convergence_showcase.gd). Call step() every physics frame. It only presses the
## player's named actions (Player.press), only reacts to what the fight shows (a warning, a gate rising), and
## reacts `reaction` seconds after it shows, like a player. It reads the fight attack by attack, one reader
## each (the first that wants a lane wins), so each build step adds its own:
## - the Helidrone Strafe (E5d-a, _read_strafe): a vertical pass's red lines over its lane: out into the
##   nearest lane it doesn't cover (every other lane, so one switch) until its rake has gone by; a horizontal
##   pass: into the Flying Buttress's lane (its opening) as soon as the gate shows and no vertical pass is
##   still to come before it, there until the line is behind it (`takes_cover` off: it stays where it is, to
##   show the line hits);
## - E5d-b's Fist Slam and Missile Barrage, E5d-c's Refill Ship cage and pad, E5d-d's Magnate: stubs
##   (_read_fist, _read_barrage, _read_refill, _read_magnate) returning no lane until those steps fill them;
## - otherwise it keeps to `home_lane` (if set).
## It never jumps or slides through the strafe (a jump doesn't dodge it); on the floor it moves one lane a
## frame toward the lane it wants.

## Seconds from a warning (or a gate rising) to its first move.
var reaction: float = 0.3
## Dodges the vertical passes (off: stands in them, to show they hit).
var dodges: bool = true
## Takes cover in the buttress's arch on a horizontal pass (off: stays put).
var takes_cover: bool = true
## The lane it keeps to while nothing threatens it (-1: wherever it is).
var home_lane: int = -1
## What it did, for tests: {t (fight time), action, why}.
var log: Array[Dictionary] = []

var boss: GoldenConvergence
var _target: int = -1
var _why: String = ""
## Fight time each thing was first seen: pass ids ("p<strafe>:<n>"), gates ("b<id>").
var _seen: Dictionary = {}


func _init(p_boss: GoldenConvergence) -> void:
	boss = p_boss


func step() -> void:
	var player: Player = boss.world.player
	if not player.alive or not player.running:
		return
	var want: Dictionary = {}
	for reader: Callable in [_read_fist, _read_barrage, _read_refill, _read_magnate, _read_strafe]:
		want = reader.call()
		if not want.is_empty():
			break
	if want.is_empty() and home_lane >= 0:
		want = {"lane": home_lane, "why": "home"}
	if not want.is_empty():
		_target = clampi(int(want["lane"]), 0, boss.lane_count() - 1)
		_why = String(want["why"])
	_walk()


# --- Readers (one per attack; the later steps fill theirs) -------------------------------------------

## E5d-b: the Fist Slam (out from under the fist's red square, or into a buttress's lane to bait it).
func _read_fist() -> Dictionary:
	return {}


## E5d-b: the Missile Barrage (onto the toppled tower's wall).
func _read_barrage() -> Dictionary:
	return {}


## E5d-c: the Refill Ship (the generator, the pad in its cage).
func _read_refill() -> Dictionary:
	return {}


## E5d-d: The Magnate (out of his Pounce's lane, the buttress's bait, the stomp).
func _read_magnate() -> Dictionary:
	return {}


## The Helidrone Strafe: the lane it wants for the pass under way or the gate ahead ({} for none).
func _read_strafe() -> Dictionary:
	var s: GoldenConvergenceStrafe = boss.strafe
	if s == null or s.stage == GoldenConvergenceStrafe.Stage.IDLE or s.held:
		return {}
	var now: float = boss.fight_time()
	var d: float = boss.player_distance()
	var me: int = _target if _target >= 0 else boss.player_lane()
	if s.current >= 0:
		var p: Dictionary = s.passes[s.current]
		if not _seen_long_enough("p%d:%d" % [s.strafes, int(p["n"])], now):
			return {}
		if String(p["kind"]) == "H":
			if takes_cover and d < float(p["line_at"]) + 2.0:
				return {"lane": int(p["opening"]), "why": "the buttress's arch"}
			return {}
		if not dodges or _rake_past(p, d):
			return {}
		var lanes: Array = p["lanes"]
		if lanes.has(me):
			return {"lane": _nearest_free(lanes, me), "why": "out of a raked lane"}
		return {"lane": me, "why": "a lane between the rakes"}
	# No pass under way: a horizontal pass next whose gate is up, its lane to take cover in.
	var next: Dictionary = {}
	for p: Dictionary in s.passes:
		if int(p["stage"]) != GoldenConvergenceStrafe.PassStage.DONE:
			next = p
			break
	if takes_cover and not next.is_empty() and String(next["kind"]) == "H":
		var b: Variant = next.get("buttress")
		if b != null and is_instance_valid(b) and (b as GoldenConvergenceButtress).standing() \
				and d < float(next["line_at"]) + 2.0:
			if _seen_long_enough("b%d:%d" % [(b as Node).get_instance_id(), (b as GoldenConvergenceButtress).places], now):
				return {"lane": int(next["opening"]), "why": "to the buttress"}
	return {}


## True once `id` has been seen for the bot's reaction time (it notes the first time it sees it).
func _seen_long_enough(id: String, now: float) -> bool:
	if not _seen.has(id):
		_seen[id] = now
		log.append({"t": now, "action": &"sees", "why": id})
	return now >= float(_seen[id]) + reaction


## True once a vertical pass's rake has gone by the runner (head-on: its front behind them; from behind:
## ahead of them).
func _rake_past(p: Dictionary, d: float) -> bool:
	if int(p["stage"]) != GoldenConvergenceStrafe.PassStage.FIRE:
		return false
	var front: float = float(p.get("front", 0.0))
	if String(p["kind"]) == "v":
		return front > d + GoldenConvergenceFire.RAKE_DEPTH + 1.0
	return front < d - GoldenConvergenceFire.RAKE_DEPTH - 1.0


## The lane nearest `me` that isn't in `lanes` (toward the middle on a tie).
func _nearest_free(lanes: Array, me: int) -> int:
	var n: int = boss.lane_count()
	var mid: float = (n - 1) * 0.5
	var best: int = -1
	for lane: int in n:
		if lanes.has(lane):
			continue
		if best < 0 or absi(lane - me) < absi(best - me) \
				or (absi(lane - me) == absi(best - me) and absf(lane - mid) < absf(best - mid)):
			best = lane
	return best if best >= 0 else me


## One lane a frame toward the lane it's heading for (on the floor).
func _walk() -> void:
	var player: Player = boss.world.player
	if _target < 0 or player.surface != Player.Surface.FLOOR:
		return
	if player.lane == _target:
		return
	_press(&"move_right" if _target > player.lane else &"move_left", _why)


func _press(action: StringName, why: String) -> void:
	boss.world.player.press(action)
	log.append({"t": boss.fight_time(), "action": action, "why": why})
