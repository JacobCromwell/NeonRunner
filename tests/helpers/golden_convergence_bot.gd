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
## - the Fist Slam (E5d-b, _read_fist): into a chance's Flying Buttress lane while its gate is up and the fist
##   hasn't locked (`baits`; the fist follows the runner's lane, so it locks onto the gate's), then, once a fist
##   has locked, out of its footprint if it comes down on the runner (the nearest lane outside it), or a jump
##   over its hole if it lands ahead (`jumps_holes`); never into a lane whose floor is an open hole there;
## - the Missile Barrage (E5d-b, _read_barrage): with a toppled tower's wall open, into the outer lane beside it
##   and onto the wall wall_lead before the fire lands (a wall run outlasts the fire), wall hopping if the run
##   would end before the fire does; with no wall, its protection: with one armor hit left and the dash, the
##   dash just as the armor's second of invulnerability ends;
## - The Magnate (E5d-d, _read_magnate, the stage 2 block at the end): out of a Pounce's square's lane once it
##   locks, into a bait's buttress lane before the lock and then onto his back for the stomp (E5d-e: a jump from
##   the green chevrons), a low Cable Lash jumped and a high one slid under; E5d-e's Claw Slash (out of the locked
##   lane into one its warning left clear, a reaction late) and Screen Storm (out of a lane a screen is warned in,
##   a reaction late, into the escape the storm's plan keeps clear for it: the route GoldenConvergenceStormPlan
##   guarantees);
## - the Refill Ship's cage (E5d-c, _read_refill, the block before stage 2's): by `refill_way`, into the
##   generator's lane and a stomp onto it (a jump timed to come down on its top), then into the pad's lane in the
##   air once its pulse has switched the cage off, and onto the pad; or into the pad's lane and the dash through
##   the front fence; or out of the cage's and the generator's lanes (a missed pad); it rides the belly up there and
##   lands where it drops;
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

## E5d-b: the Fist Slam (_read_fist_slams, below).
func _read_fist() -> Dictionary:
	return _read_fist_slams()


## E5d-b: the Missile Barrage (_read_missiles, below).
func _read_barrage() -> Dictionary:
	return _read_missiles()


## E5d-c: the Refill Ship (the generator, the pad in its cage): see the block before stage 2's.
func _read_refill() -> Dictionary:
	return _read_cage()


## E5d-d: The Magnate (out of his Pounce's lane, the buttress's bait, the stomp, the Cable Lash): see the stage 2
## block at the end.
func _read_magnate() -> Dictionary:
	if boss.pounce == null:
		return {}
	_read_lash()
	var want: Dictionary = _read_slash()
	if not want.is_empty():
		return want
	want = _read_storm()
	if not want.is_empty():
		return want
	return _read_pounce()


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
		var b: GoldenConvergenceButtress = s.gate(next)
		if b != null and b.standing() and d < float(next["line_at"]) + 2.0:
			if _seen_long_enough("b%d:%d" % [b.get_instance_id(), b.places], now):
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
	# E5d-b: never into a lane whose floor is a slam's open hole here.
	if not _lane_clear(player.lane + (1 if _target > player.lane else -1)):
		return
	_press(&"move_right" if _target > player.lane else &"move_left", _why)


func _press(action: StringName, why: String) -> void:
	boss.world.player.press(action)
	log.append({"t": boss.fight_time(), "action": action, "why": why})


# --- E5d-b: the Fist Slam and the Missile Barrage -----------------------------------------------------

## Baits the fist into a chance's Flying Buttress (off: lets it lock wherever the runner is).
var baits: bool = true
## Leaves a slam's footprint once it has locked (off: stays under it, to show it hits).
var dodges_fist: bool = true
## Jumps a hole ahead in its lane (off: runs into it).
var jumps_holes: bool = true
## Takes a toppled tower's wall for the barrage (off: stays on the floor).
var takes_wall: bool = true
## Gets onto the wall this long before the fire lands, at the run speed.
var wall_lead: float = 0.45

var _jumped: Dictionary = {}
## A wall hop under way: frames until it presses back toward the wall (0: none).
var _hop: int = 0
var _hop_side: int = 0
var _wall_since: float = -1.0
var _dashed_for: int = -1


## The Fist Slam: the lane it wants for the slam to come ({} for none).
func _read_fist_slams() -> Dictionary:
	var sl: GoldenConvergenceSlams = boss.slams
	if sl == null:
		return {}
	var now: float = boss.fight_time()
	var d: float = boss.player_distance()
	var me: int = _target if _target >= 0 else boss.player_lane()
	if jumps_holes:
		_jump_holes(d)
	for s: Dictionary in sl.slams:
		var st: int = int(s["stage"])
		if st >= GoldenConvergenceSlams.SlamStage.HIT:
			continue
		if st == GoldenConvergenceSlams.SlamStage.LOCKED or st == GoldenConvergenceSlams.SlamStage.FALL:
			# The next to land has locked: out from under it (once seen), or stay for its hole ahead.
			if not _seen_long_enough("lock%d:%d" % [sl.sequences, int(s["n"])], now):
				return {"lane": me, "why": "a fist locked (reacting)"}
			var lanes: Array = s["lanes"]
			if s["kind"] == &"on" and dodges_fist and lanes.has(me):
				return {"lane": _nearest_free(lanes, me), "why": "out from under the fist"}
			return {"lane": me, "why": "beside the fist" if not lanes.has(me) else "its hole to jump"}
		# Before the next one locks: to a chance's gate (from this slam on) while it stands.
		if baits and sl.stage == GoldenConvergenceSlams.Stage.ON:
			for c: Dictionary in sl.slams:
				if int(c["n"]) < int(s["n"]) or not bool(c["chance"]) or int(c["stage"]) >= GoldenConvergenceSlams.SlamStage.LOCKED:
					continue
				var b: GoldenConvergenceButtress = sl.gate_of(c)
				if b == null or not b.standing():
					continue
				if not _seen_long_enough("b%d:%d" % [b.get_instance_id(), b.places], now):
					break
				return {"lane": int(c["buttress_lane"]), "why": "bait the fist into the buttress"}
		return {}
	return {}


## True if a switch into `lane` now keeps the runner off an open hole there (a slam's opened cuts, from just
## behind the runner to where a lane switch's run ends).
func _lane_clear(lane: int) -> bool:
	if lane < 0 or lane >= boss.lane_count():
		return true
	var d: float = boss.player_distance()
	var reach: float = boss.speed_planned() * boss.world.tuning.lane_switch_time + 1.0
	for fc: FloorCut in boss.world.track.floor_cuts():
		if fc.lane != lane or not fc.began():
			continue
		if fc.start <= d + reach and fc.end >= d - 1.0 and not fc.holding():
			return false
	return true


## Jumps an open hole ahead in its lane (from where the jump clears it), once each.
func _jump_holes(d: float) -> void:
	var player: Player = boss.world.player
	if not player.grounded or player.surface != Player.Surface.FLOOR:
		return
	var flight: float = boss.world.tuning.jump_distance(maxf(player.speed, 1.0))
	for fc: FloorCut in boss.world.track.floor_cuts():
		if fc.lane != player.lane or not fc.began() or fc.start < d:
			continue
		var length: float = fc.end - fc.start
		# Take off so the flight lands as far past the hole as it starts before it.
		var takeoff: float = fc.start - maxf(flight - length, 0.0) * 0.5
		var key: String = "%d:%d" % [fc.lane, roundi(fc.end * 10.0)]
		if d >= takeoff and not _jumped.has(key):
			_jumped[key] = true
			_press(&"jump", "over a hole")
			return


## The Missile Barrage: the lane it wants for it ({} for none).
func _read_missiles() -> Dictionary:
	var br: GoldenConvergenceBarrage = boss.barrage
	var player: Player = boss.world.player
	if player.surface == Player.Surface.WALL:
		if _wall_since < 0.0:
			_wall_since = boss.fight_time()
	else:
		_wall_since = -1.0
	if _hop > 0:
		_hop -= 1
		if _hop == 0 and player.surface == Player.Surface.FLOOR:
			_press(&"move_left" if _hop_side < 0 else &"move_right", "a wall hop")
	if br == null or br.stage == GoldenConvergenceBarrage.Stage.IDLE:
		return {}
	var now: float = boss.fight_time()
	if not _seen_long_enough("barrage%d" % br.barrages, now):
		return {}
	var side: int = _wall_for(br)
	if side != 0 and takes_wall:
		var outer: int = 0 if side < 0 else boss.lane_count() - 1
		if player.surface == Player.Surface.WALL:
			_hop_if_short(br, side)
			return {"lane": outer, "why": "on the wall"}
		var eta: float = br.land_eta()
		if player.lane == outer and eta >= 0.0 and eta <= wall_lead and _hop == 0:
			_press(&"move_left" if side < 0 else &"move_right", "onto the wall")
		return {"lane": outer, "why": "to the wall"}
	_protect(br)
	return {}


## The side of a wall open over the fire's stretch (-1, 1), or 0.
func _wall_for(br: GoldenConvergenceBarrage) -> int:
	if br.plan.is_empty():
		return 0
	var from: float = float(br.plan["from"])
	var to: float = float(br.plan["to"])
	for side: int in [-1, 1]:
		if boss.court.is_open(side, from) and boss.court.is_open(side, to):
			return side
	return 0


## On the wall: a hop (jump off and straight back on) if the run would end before the fire is out, while still
## high enough to stay clear of it.
func _hop_if_short(br: GoldenConvergenceBarrage, side: int) -> void:
	var player: Player = boss.world.player
	var mt: MovementTuning = boss.world.tuning
	var run: float = mt.wall_entry_time + mt.wall_slide_time * player.wall_time_multiplier
	var left: float = run - (boss.fight_time() - _wall_since)
	var fire_left: float = (br.land_eta() + boss.tuning.fire_seconds) if br.stage != GoldenConvergenceBarrage.Stage.FIRE \
		else boss.tuning.fire_seconds - br.burn_time
	if left < fire_left + 0.15 and player.h >= 1.3 and _hop == 0:
		_press(&"jump", "a wall hop")
		_hop = 2
		_hop_side = side


## No wall: with one armor hit left (no shield) and the dash, the dash as the armor's second of invulnerability
## runs out while the fire still burns.
func _protect(br: GoldenConvergenceBarrage) -> void:
	if br.stage != GoldenConvergenceBarrage.Stage.FIRE or _dashed_for == br.barrages:
		return
	var player: Player = boss.world.player
	var fire_left: float = boss.tuning.fire_seconds - br.burn_time
	if player.invulnerable_left > 0.0 and player.invulnerable_left <= 0.08 and fire_left > player.invulnerable_left \
			and player.armor <= 0 and player.shield <= 0:
		var powerups: Node = boss.world.powerups
		if powerups != null and powerups.has_method(&"try_dash") and bool(powerups.call(&"try_dash")):
			_dashed_for = br.barrages
			log.append({"t": boss.fight_time(), "action": &"dash", "why": "through the fire"})


# --- E5d-c: the Refill Ship's cage --------------------------------------------------------------------------
# _read_cage, by what it shows, `reaction` late, once the cage is up (GoldenConvergenceCage):
# - &"generator": to the generator's lane; a jump `stomp_lead()` before it, timed to come down on its top (a stomp:
#   its pulse switches the cage off); in the air, into the pad's lane (the side fence is dark); onto the pad;
# - &"dash": to the pad's lane at once, and the dash `dash_lead` before the front fence (so it's dashing as it
#   passes through), onto the pad;
# - &"miss": out of the pad's and the generator's lanes until it's past the cage (the loop comes round again);
# - &"armor": to the pad's lane and through the front fence on the armor (or the shield), onto the pad.

## How it gets onto the pad (&"generator", &"dash", &"armor") or lets it go by (&"miss").
var refill_way: StringName = &"generator"
## Starts the dash this far (metres at the run speed's second: run speed × dash_lead) before the front fence.
var dash_lead: float = 0.2

var _gen_jumped: int = -1
var _cage_dashed: int = -1


## The Refill Ship's cage: the lane it wants ({} for none).
func _read_cage() -> Dictionary:
	var r: GoldenConvergenceRefill = boss.refill
	if r == null or not r.cage_up():
		return {}
	var c: GoldenConvergenceCage = r.cage
	var plan: Dictionary = c.plan
	var n: int = int(plan["n"])
	var now: float = boss.fight_time()
	var me: int = _target if _target >= 0 else boss.player_lane()
	if not _seen_long_enough("cage%d" % n, now):
		return {"lane": me, "why": "a cage (reacting)"}
	var player: Player = boss.world.player
	var d: float = player.distance
	var pad_lane: int = int(plan["lane"])
	var gen_lane: int = int(plan["gen_lane"])
	var gen: FenceGenerator = c.generator
	var gen_up: bool = gen != null and is_instance_valid(gen) and gen.alive
	match refill_way:
		&"miss":
			if me == pad_lane or me == gen_lane:
				return {"lane": _nearest_free([pad_lane, gen_lane], me), "why": "around the cage"}
			return {"lane": me, "why": "beside the cage"}
		&"dash":
			if player.surface == Player.Surface.FLOOR and player.lane == pad_lane and _cage_dashed != n \
					and d >= float(plan["front_at"]) - boss.speed() * dash_lead - 2.0:
				var powerups: Node = boss.world.powerups
				if powerups != null and powerups.has_method(&"try_dash") and bool(powerups.call(&"try_dash")):
					_cage_dashed = n
					log.append({"t": now, "action": &"dash", "why": "through the cage's fence"})
			return {"lane": pad_lane, "why": "into the cage's lane, to dash in"}
		&"armor":
			return {"lane": pad_lane, "why": "into the cage's lane, through the fence on the armor"}
	# The generator: knock it out, then into the pad's lane.
	if not gen_up:
		return {"lane": pad_lane, "why": "into the cage, its fences dark"}
	if player.surface == Player.Surface.FLOOR and player.grounded and player.lane == gen_lane and _gen_jumped != n:
		var ahead: float = float(plan["gen_at"]) - d
		if ahead <= stomp_generator_lead() and ahead > 0.0:
			_gen_jumped = n
			_press(&"jump", "stomp the cage's generator")
	return {"lane": gen_lane, "why": "to the cage's generator"}


## How far before a generator to jump so the runner comes down on its top: up to the jump's top and back down to
## the generator's top, at the runner's speed (the Sleep Taker's bot's).
func stomp_generator_lead() -> float:
	var t: MovementTuning = boss.world.tuning
	var top: float = FenceGenerator.TOP_Y
	var t_down: float = sqrt(2.0 * maxf(t.jump_height - top, 0.0) / (t.gravity() * t.fall_gravity_multiplier))
	return boss.speed() * (t.jump_time_to_apex + t_down)


# --- Stage 2, The Magnate (E5d-d) ------------------------------------------------------------------------
# _read_magnate's readers, by what he shows, `reaction` late:
# - the Pounce: it stays in its lane until the red square shows (the lock), then leaves the square's lane for the
#   nearest other (`dodges_pounce` off: it stays, to show the crash hits), and keeps out of it until it's past;
# - the bait: once the buttress has risen it goes into the buttress's lane before the lock (`takes_bait` off: it
#   keeps out of it), and when the square shows at the gate it leaves for his other lane (the stun's second);
#   stunned, he lies across two lanes: it goes into the nearer and jumps onto his back with a stomp lead (the
#   House's and the Sleep Taker's bots' way: up to its jump's top and down to his weak points' height at the run
#   speed; `stomps` off: it runs on, to show the release);
# - the Cable Lash: a low one jumped, a high one slid under, as the cable nears (`answers_lash` off: it runs on;
#   `wrong_lash`: it answers each the other way, to show the answer matters).

## Goes for the bait (in the buttress's lane at the lock).
var takes_bait: bool = true
## Jumps onto his back when he's stunned.
var stomps: bool = true
## Leaves a Pounce's square's lane.
var dodges_pounce: bool = true
## Jumps a low Lash and slides under a high one (wrong_lash: the other way round).
var answers_lash: bool = true
var wrong_lash: bool = false

## The stun it has jumped for (its pounce number), the lash it has answered.
var _stomp_jump: int = -1
var _lash_answered: int = -1


## The Pounce: the lane it wants ({} for none).
func _read_pounce() -> Dictionary:
	var pc: GoldenConvergencePounce = boss.pounce
	if pc.stage == GoldenConvergencePounce.Stage.IDLE or pc.p.is_empty():
		return {}
	var now: float = boss.fight_time()
	var d: float = boss.player_distance()
	var me: int = _target if _target >= 0 else boss.player_lane()
	var n: int = int(pc.p.get("n", 0))
	var bait: bool = bool(pc.p.get("bait", false))
	if pc.stage == GoldenConvergencePounce.Stage.STUN:
		return _read_stun(pc, now, d, me)
	var sq: Dictionary = pc.square()
	if not sq.is_empty():
		if not _seen_long_enough("sq%d" % n, now):
			return {}
		var lane: int = int(sq["lane"])
		if d > float(sq["to"]) + 1.0:
			return {}
		if bool(pc.p.get("taken", false)):
			# The bait's taken: out of the square at the gate, into his other lane, ready for his back.
			return {"lane": _stun_other(pc), "why": "out of the bait's square, into his other lane"}
		if dodges_pounce and me == lane:
			return {"lane": _nearest_free([lane], me), "why": "out of the pounce's square"}
		if dodges_pounce:
			# Keeping out of the square's lane until it's past.
			return {"lane": me, "why": "beside the pounce's square"}
		return {"lane": lane, "why": "standing in the pounce's square"}
	if bait and int(pc.p.get("lane", -1)) < 0 and pc.gate() != null and pc.gate().standing():
		var gate: int = int(pc.p["gate_lane"])
		if not _seen_long_enough("bait%d" % n, now):
			return {}
		if takes_bait:
			return {"lane": gate, "why": "into the bait's lane"}
		if me == gate:
			return {"lane": _nearest_free([gate], me), "why": "out of the bait's lane"}
	return {}


## His other lane while stunned (the one that isn't the buttress's).
func _stun_other(pc: GoldenConvergencePounce) -> int:
	var lanes: Array = pc.p.get("stun_lanes", [])
	for l: Variant in lanes:
		if int(l) != int(pc.p.get("gate_lane", -1)):
			return int(l)
	return int(lanes[0]) if not lanes.is_empty() else boss.player_lane()


## Stunned: into the nearer of his two lanes, and a jump timed to come down on his back.
func _read_stun(pc: GoldenConvergencePounce, now: float, d: float, me: int) -> Dictionary:
	var n: int = int(pc.p.get("n", 0))
	if not stomps or not _seen_long_enough("stun%d" % n, now):
		return {}
	var lanes: Array = pc.p["stun_lanes"]
	var want: int = int(lanes[0]) if absi(int(lanes[0]) - me) <= absi(int(lanes[1]) - me) else int(lanes[1])
	if lanes.has(me):
		want = me
	var player: Player = boss.world.player
	var gap: float = pc.stun_back() - d
	# E5d-e: the take-off where the green chevrons say (chevron_point along them: 0 their near end, 1 their far end),
	# or, without them, a jump timed to come down on his back's middle.
	var lead: float = stomp_lead()
	var marks: Dictionary = pc.takeoff_marks.marked if pc.takeoff_marks != null else {}
	if not marks.is_empty():
		lead = pc.stun_back() - lerpf(float(marks["from"]), float(marks["to"]), chevron_point)
	if _stomp_jump != n and player.grounded and player.lane == want and gap <= lead and gap > pc.release_gap():
		_stomp_jump = n
		_press(&"jump", "onto his back, from the chevrons" if not marks.is_empty() else "onto his back")
	return {"lane": want, "why": "into his lane, for his back"}


## How far before his back to jump so the runner comes down on his weak points' middle: up to its jump's top
## and down through their stomp height, over the middle of their boxes, at the run speed.
func stomp_lead() -> float:
	var t: MovementTuning = boss.world.tuning
	var top: float = GoldenConvergencePounce.stomp_top(boss.tuning, t, boss.world.rules)
	var tol: float = boss.world.rules.stomp_tolerance
	var g: float = t.gravity() * t.fall_gravity_multiplier
	var t_top: float = sqrt(2.0 * maxf(t.jump_height - top, 0.0) / g)
	var t_low: float = sqrt(2.0 * maxf(t.jump_height - (top - tol), 0.0) / g)
	var t_mid: float = t.jump_time_to_apex + (t_top + t_low) * 0.5
	var reach: float = boss.tuning.stun_reach * boss.run_pace()
	return boss.speed() * t_mid + (reach - GoldenConvergencePounce.STUN_DEPTH) * 0.5


## The Cable Lash: a low one jumped (its top at the cable), a high one slid under, once its warning shows.
func _read_lash() -> void:
	var l: GoldenConvergenceLash = boss.lash
	if l == null or l.p.is_empty() or not answers_lash:
		return
	if not (l.stage in [GoldenConvergenceLash.Stage.WARN, GoldenConvergenceLash.Stage.WHIP, GoldenConvergenceLash.Stage.HOLD]):
		return
	var n: int = int(l.p["n"])
	if _lash_answered == n or not _seen_long_enough("lash%d" % n, boss.fight_time()):
		return
	var player: Player = boss.world.player
	if not player.grounded or player.surface != Player.Surface.FLOOR:
		return
	var ahead: float = float(l.p["line_at"]) - boss.player_distance()
	var t: MovementTuning = boss.world.tuning
	var low: bool = l.p["kind"] == &"low"
	if wrong_lash:
		low = not low
	if low and ahead <= boss.speed() * t.jump_time_to_apex and ahead > 0.0:
		_lash_answered = n
		_press(&"jump", "over the low cable")
	elif not low and ahead <= boss.speed() * 0.3 and ahead > 0.0:
		_lash_answered = n
		_press(&"slide", "under the high cable")


# --- E5d-e: the owner's playtest (the Claw Slash, the Screen Storm) ---------------------------------------------
# _read_slash: once the claw marks show in its lane (a reaction late), out into a lane the warning left clear (its
# `escapes`: the one nearer the middle); `dodges_slash` off stays, to show the swipe hits.
# _read_storm: every screen warned in its lane (a reaction late) sends it to that screen's escape (the plan's,
# kept clear for it while it moves: GoldenConvergenceStormPlan); `weaves` off stays put, to show a crash hits.

## Dodges a Claw Slash.
var dodges_slash: bool = true
## Weaves through a Screen Storm.
var weaves: bool = true
## Where along the green chevrons it takes off for the stomp (0 their near end, 1 their far end).
var chevron_point: float = 0.5


## The Claw Slash: the lane it wants ({} for none).
func _read_slash() -> Dictionary:
	var sl: GoldenConvergenceSlash = boss.slash
	if sl == null or sl.p.is_empty():
		return {}
	var m: Dictionary = sl.marks()
	if m.is_empty():
		return {}
	var now: float = boss.fight_time()
	if not _seen_long_enough("slash%d:%d" % [int(sl.p["n"]), int(sl.p["k"])], now):
		return {}
	var lane: int = int(m["lane"])
	var me: int = _target if _target >= 0 else boss.player_lane()
	if not dodges_slash:
		return {"lane": lane, "why": "standing in the slash"}
	if me != lane:
		return {"lane": me, "why": "beside the slash"}
	var ways: Array = sl.p.get("escapes", [])
	if ways.is_empty():
		return {}
	var mid: float = (boss.lane_count() - 1) * 0.5
	var best: int = int(ways[0])
	for w: Variant in ways:
		if absf(float(w) - mid) < absf(float(best) - mid):
			best = int(w)
	return {"lane": best, "why": "out of the slash's lane"}


## The Screen Storm: the lane it wants ({} for none).
func _read_storm() -> Dictionary:
	var sc: GoldenConvergenceScreens = boss.screens
	if sc == null or sc.live.is_empty():
		return {}
	var now: float = boss.fight_time()
	var me: int = _target if _target >= 0 else boss.player_lane()
	var t: GoldenConvergenceTuning = boss.tuning
	var want: Dictionary = {}
	var soonest: float = INF
	for th: Dictionary in sc.threats():
		if int(th["lane"]) < 0 or int(th["stage"]) == GoldenConvergenceScreens.ScreenStage.YANK:
			continue
		# Note every screen the moment it shows (the reaction counts from its warning).
		var seen: bool = _seen_long_enough("scr%d:%d" % [int(th["storm"]), int(th["n"])], now)
		if int(th["lane"]) != me or not seen or now > float(th["crash_at"]) + t.screen_hit_seconds:
			continue
		if float(th["crash_at"]) < soonest:
			soonest = float(th["crash_at"])
			want = {"lane": int(th["escape"]) if weaves else me, "why": "out of a screen's square" if weaves else "under a screen"}
	return want
