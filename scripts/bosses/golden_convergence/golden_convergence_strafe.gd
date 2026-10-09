class_name GoldenConvergenceStrafe
extends GoldenConvergenceAttack
## The Helidrone Strafe (GDD §10, the owner's attack; task E5d-a): the squadron (GoldenConvergenceSquadron)
## comes out of the cape, flies its passes as one, raking the floor (GoldenConvergenceFire), and goes back
## into the cape. Its script is the beat's argument (GoldenConvergenceTuning.phase_beats: "VVH" in phase 1,
## "VVHvVHv" in later phases), one letter a pass, fixed so it's learnable and fair for par times:
## - V, a vertical pass head-on: the drones fly down the lanes toward the runner raking every other lane
##   (covered_lanes): lanes 1, 3, 5 counting from 1 on the strafe's first vertical pass (the outer lanes on 3
##   and 5 lanes; proposed), the others on the next, switching each vertical pass, so each one moves the
##   runner. A drone flies over each covered lane; a spare one (a pass covering fewer lanes than there are
##   drones: on 5 lanes 3 then 2, on 3 lanes 2 then 1) climbs above the formation over a covered lane and
##   holds its fire, so a drone never flies over a safe lane. Red lines over the raked stretch of each
##   covered lane and the gatling's spin-up whine warn warning_seconds before the guns start, at the far end
##   of the stretch, their front closing in at rake_speed and on past the runner;
## - v, a vertical pass from behind (proposed: the 7-pass strafe's 4th and 7th): the same, but the drones
##   come from behind the runner and rake forward past them, their front gaining at behind_rake_speed;
## - H, a horizontal pass: a Flying Buttress (GoldenConvergenceButtress) rises in an inner lane at least
##   buttress_sight before the runner gets to it; the live line lies exactly along it, and its red warning
##   line crosses every lane but the buttress's opening; the squadron sweeps across from wall to wall: one
##   drone rakes the live line, each other drone a line for show further down the field (no warning, no
##   buttress, no hitbox, its fire over well before the runner gets there, then only a dark scorch mark). The
##   live line burns over every lane but the opening and up any open wall at every height, above a jump, from
##   the moment the sweep reaches each lane until the runner is past it: the runner takes cover in the arch
##   (the bullets spark off the stone above it) or dashes through. Its timing is anchored to the line: its
##   warning starts as the runner comes within (warning + sweep + cross_lead) of it at the run speed.
## Passes follow each other a second or two apart (pass_gap after the last one's fire, divided by the phase's
## pace), each anchored to where the runner will be (warn_at, planned at the run speed when the strafe
## starts), so a pass always comes where it was planned to: the same every attempt. Nothing else is on the
## track during a strafe (the beat script plays one beat at a time).
## The Refill Ship (E5d-c, GoldenConvergenceRefill) plays a strafe with it (`refill`): hold(true) stops its fire
## and takes its warnings away at once, the squadron hovering at hold_station (a Callable giving drone i's world
## point: beside the ship, under its racks; or the station ahead), no gate rising meanwhile, and hold(false) plans
## the passes left on from the runner; a pad (the runner's movement_event &"pad" while the squadron is out) hurls
## the whole squadron up (GDD §9.6's rule) and ends the strafe, and `hurled` says so (the chain reaction starts
## there; GoldenConvergenceSquadron.hurl_rise sets how high they go: up into the ship's racks).

## The squadron was hurled up by a pad: the strafe is over (E5d-c: the Refill Ship's chain reaction).
signal hurled
## A pass's warning began (the bot and tests read the pass).
signal pass_warned(info: Dictionary)

enum Stage { IDLE, EMERGE, PASSES, RETURN, HURLED }
enum PassStage { WAIT, WARN, FIRE, DONE }

## The default script when a beat names none (phase 1's).
const DEFAULT_SCRIPT: String = "VVH"
## How fast drones close in on where they're going (1/s) between and before passes.
const FOLLOW_RATE: float = 4.5
## The H sweep: the drones start and end this far beyond the walls.
const SWEEP_OUT: float = 9.0
## The live line stops burning at the latest this long after its sweep (a runner who's down), seconds.
const LINE_TIMEOUT: float = 3.0

var squadron: GoldenConvergenceSquadron
var fire: GoldenConvergenceFire
var stage: Stage = Stage.IDLE
## Seconds in the current stage.
var stage_time: float = 0.0
## The strafe's pass script and its passes: {n, kind (V, v or H), stage, warn_at, lanes, parity, from, to, front,
## t, line_at, opening, lean, buttress, shows, dir, warnings, scorch, warned_at, sparked}.
var pass_script: String = ""
var passes: Array[Dictionary] = []
## The pass under way (WARN or FIRE), or -1.
var current: int = -1
## Strafes flown this fight, and whether this one came with the Refill Ship (E5d-c).
var strafes: int = 0
var refill: bool = false
## Drone i's world point while held (Callable(i: int) -> Vector3); empty: the station ahead.
var hold_station: Callable = Callable()

var _rng := RandomNumberGenerator.new()
var _pace: float = 1.0
var _hints: int = 0
## E5d-b: where the strafe will be over (ends_at).
var _ends_at: float = -1.0


func _init(p_boss: GoldenConvergence) -> void:
	super(p_boss, &"strafe")
	squadron = boss.squadron
	fire = boss.fire
	fire.hit.connect(_on_fire_hit)
	boss.world.player.movement_event.connect(_on_player_event)


func busy() -> bool:
	return stage != Stage.IDLE


## A pass warns or its fire is live.
func warning_on() -> bool:
	return current >= 0 and int(passes[current]["stage"]) in [PassStage.WARN, PassStage.FIRE]


## Starts a strafe flying `beat`'s script (its argument: "VVH", "VVHvVHv").
func start(beat: Dictionary) -> void:
	clear()
	pass_script = String(beat.get("arg", ""))
	if pass_script == "":
		pass_script = DEFAULT_SCRIPT
	refill = beat.get("kind", &"strafe") == &"refill"
	strafes += 1
	_rng.seed = hash([String(boss.def.id), "strafe", strafes, boss.rng.seed])
	_pace = boss.pace()
	squadron.reset()
	_plan(boss.player_distance() + boss.speed_planned() * boss.tuning.emerge_seconds)
	stage = Stage.EMERGE
	stage_time = 0.0
	boss.sound(&"gc_emerge", boss.sound_point(boss.cape_point(0)))
	boss.log_event(&"strafe_start", {"script": pass_script, "n": strafes, "refill": refill, "drones": squadron.size()})


## Plans every pass of the script from the runner reaching `first_at` (its first warning), at the run speed:
## each next pass's warning pass_gap (over the phase's pace) after the last one's fire is over.
func _plan(first_at: float, from_pass: int = 0) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var v: float = boss.speed_planned()
	var rp: float = boss.run_pace()
	var lanes: int = boss.lane_count()
	var at: float = first_at
	var vertical: int = 0
	var horizontal: int = 0
	for i: int in from_pass:
		var kind: String = String(passes[i]["kind"])
		if kind == "H":
			horizontal += 1
		else:
			vertical += 1
	for i: int in range(from_pass, pass_script.length()):
		var kind: String = pass_script[i]
		if kind != "V" and kind != "v" and kind != "H":
			continue
		var p: Dictionary = {}
		if i < passes.size():
			p = passes[i]
		else:
			p = {"n": i, "kind": kind}
			passes.append(p)
		p["stage"] = PassStage.WAIT
		p["warn_at"] = at
		p["t"] = 0.0
		p["warnings"] = []
		p["scorch"] = []
		p["sparked"] = false
		var seconds: float = t.warning_seconds
		if kind == "H":
			var line_at: float = at + v * (t.warning_seconds + t.sweep_seconds + t.cross_lead)
			p["line_at"] = line_at
			if not p.has("opening"):
				p["opening"] = _pick_buttress_lane(lanes)
				p["lean"] = _pick_lean(int(p["opening"]), lanes)
				p["dir"] = 1 if horizontal % 2 == 0 else -1
			var shows: Array[float] = []
			for k: int in range(1, squadron.size()):
				shows.append(line_at + float(k) * t.show_spacing * rp)
			p["shows"] = shows
			seconds += t.sweep_seconds + t.cross_lead + t.line_burn_after
			horizontal += 1
		else:
			p["parity"] = vertical % 2
			p["lanes"] = GoldenConvergenceTuning.covered_lanes(lanes, vertical % 2)
			if kind == "V":
				p["from"] = at - t.vertical_behind * rp
				p["to"] = at + t.vertical_length * rp
				seconds += (t.vertical_length + t.vertical_behind) * rp / maxf(t.rake_speed * rp, 1.0) \
					+ GoldenConvergenceFire.RAKE_DEPTH / maxf(t.rake_speed * rp, 1.0)
			else:
				p["from"] = at - t.behind_start * rp
				p["to"] = at + t.behind_length * rp
				var ground: float = v + t.behind_rake_speed * rp
				seconds += (t.behind_length + t.behind_start) * rp / ground + GoldenConvergenceFire.RAKE_DEPTH / ground
			vertical += 1
		at += v * (seconds + t.pass_gap / _pace)
	# E5d-b: where it will be over (its last pass done, the squadron back in the cape).
	_ends_at = at - v * t.pass_gap / _pace + v * t.return_seconds


## E5d-b (GoldenConvergenceAttack.ends_at): where the strafe under way will be over, at the run speed (-1 while
## it's held or idle).
func ends_at() -> float:
	match stage:
		Stage.EMERGE, Stage.PASSES:
			return -1.0 if held else _ends_at
		Stage.RETURN:
			return boss.player_distance() + boss.speed_planned() * maxf(boss.tuning.return_seconds - stage_time, 0.0)
	return -1.0


## An inner lane (never an outer one, GDD §10) for a buttress, seeded.
func _pick_buttress_lane(lanes: int) -> int:
	if lanes <= 2:
		return 0
	return _rng.randi_range(1, lanes - 2)


## The side its flying arch leans to: the nearer edge, either way from the middle lane by the seed.
func _pick_lean(lane: int, lanes: int) -> int:
	var mid: float = (lanes - 1) * 0.5
	if float(lane) < mid - 0.01:
		return -1
	if float(lane) > mid + 0.01:
		return 1
	return -1 if _rng.randf() < 0.5 else 1


func tick(delta: float) -> void:
	if stage == Stage.IDLE:
		return
	stage_time += delta
	match stage:
		Stage.EMERGE:
			if not held:
				_place_buttresses()
			_fly(delta)
			if stage_time >= boss.tuning.emerge_seconds:
				stage = Stage.PASSES
				stage_time = 0.0
		Stage.PASSES:
			if not held:
				# Held (the Refill Ship's cage), no gate rises for a pass planned before the hold: the passes left
				# are planned on from where the runner is on release.
				_place_buttresses()
				_tick_passes(delta)
			_fly(delta)
			if current < 0 and _all_done():
				_return()
		Stage.RETURN:
			_fly(delta)
			if stage_time >= boss.tuning.return_seconds:
				squadron.stow_all()
				stage = Stage.IDLE
				boss.log_event(&"strafe_done", {"n": strafes})
		Stage.HURLED:
			if not squadron.hurling():
				stage = Stage.IDLE
				boss.log_event(&"strafe_done", {"n": strafes, "hurled": true})


func _all_done() -> bool:
	for p: Dictionary in passes:
		if int(p["stage"]) != PassStage.DONE:
			return false
	return true


func _return() -> void:
	stage = Stage.RETURN
	stage_time = 0.0
	for i: int in GoldenConvergenceSquadron.MAX:
		fire.hide_tracer(i)
	boss.sound(&"gc_return", boss.sound_point(boss.cape_point(0)))
	boss.log_event(&"strafe_return", {"n": strafes})


# --- The passes ------------------------------------------------------------------------------------

func _tick_passes(delta: float) -> void:
	var d: float = boss.player_distance()
	if current < 0:
		for i: int in passes.size():
			var p: Dictionary = passes[i]
			if int(p["stage"]) == PassStage.WAIT:
				if d >= float(p["warn_at"]):
					_warn(i)
				break
	if current < 0:
		return
	var p: Dictionary = passes[current]
	p["t"] = float(p["t"]) + delta
	var t: float = float(p["t"])
	if int(p["stage"]) == PassStage.WARN and t >= boss.tuning.warning_seconds:
		_fire(current)
	if int(p["stage"]) == PassStage.FIRE:
		if String(p["kind"]) == "H":
			_tick_line(p)
		else:
			_tick_rake(p)


## A pass's warning: its red lines on the floor and the gatling's whine.
func _warn(i: int) -> void:
	var p: Dictionary = passes[i]
	var t: GoldenConvergenceTuning = boss.tuning
	current = i
	p["stage"] = PassStage.WARN
	p["t"] = 0.0
	p["warned_at"] = boss.fight_time()
	var d: float = boss.player_distance()
	var warnings: Array = []
	var info: Dictionary = {"n": i, "kind": p["kind"], "runner": d, "lane": boss.player_lane()}
	if String(p["kind"]) == "H":
		var line_at: float = float(p["line_at"])
		var opening: int = int(p["opening"])
		var half: float = t.line_depth * 0.5 + 0.15
		var burning: Array[int] = []
		for lane: int in boss.lane_count():
			if lane == opening:
				continue
			burning.append(lane)
			warnings.append(boss.cross_warning(lane, line_at - half, line_at + half))
		p["burning"] = burning
		info["line"] = line_at
		info["opening"] = opening
		info["lanes"] = burning
		info["shows"] = p["shows"]
		boss.hint("buttress")
	else:
		for lane: int in p["lanes"]:
			warnings.append(boss.props.lane_warning(lane, float(p["from"]), float(p["to"])))
		info["lanes"] = p["lanes"]
		info["from"] = p["from"]
		info["to"] = p["to"]
		boss.hint("strafe")
	p["warnings"] = warnings
	boss.sound(&"gc_whine", boss.sound_point(_formation_point(p)))
	boss.log_event(&"pass_warned", info)
	pass_warned.emit(info)


## The warning is over: the guns open up.
func _fire(i: int) -> void:
	var p: Dictionary = passes[i]
	p["stage"] = PassStage.FIRE
	p["fired_at"] = boss.fight_time()
	if String(p["kind"]) == "H":
		var line_at: float = float(p["line_at"])
		fire.set_line(0, line_at, int(p["opening"]))
		var shows: Array = p["shows"]
		for k: int in mini(shows.size(), GoldenConvergenceFire.LINES - 1):
			fire.set_line(k + 1, float(shows[k]), -1)
		p["lit"] = {}
		boss.sound(&"gc_sweep", boss.sound_point(Vector3(0.0, 2.0, TrackGeometry.world_z(line_at))))
	else:
		var lanes: Array = p["lanes"]
		var behind: bool = String(p["kind"]) == "v"
		var front: float = float(p["from"]) if behind else float(p["to"])
		p["front"] = front
		var scorch: Array = []
		for j: int in mini(lanes.size(), GoldenConvergenceFire.RAKES):
			fire.set_rake_lane(j, int(lanes[j]))
			fire.set_rake_front(j, front, boss.court.is_open(_lane_side(int(lanes[j])), front))
			scorch.append(fire.scorch_lane(int(lanes[j]), front, front))
		p["scorch"] = scorch
		boss.sound(&"gc_rake", boss.sound_point(Vector3(0.0, 2.0, TrackGeometry.world_z(front))))
	boss.log_event(&"pass_fire", {"n": i, "kind": p["kind"], "runner": boss.player_distance(), "lane": boss.player_lane()})


## A vertical pass's rakes: the front closing in (head-on) or gaining (from behind), until it's past the
## stretch's other end.
func _tick_rake(p: Dictionary) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var rp: float = boss.run_pace()
	var tf: float = float(p["t"]) - t.warning_seconds
	var lanes: Array = p["lanes"]
	var from: float = float(p["from"])
	var to: float = float(p["to"])
	var front: float
	var done: bool
	if String(p["kind"]) == "v":
		front = from + (boss.speed_planned() + t.behind_rake_speed * rp) * tf
		done = front > to + GoldenConvergenceFire.RAKE_DEPTH * 0.5
	else:
		front = to - t.rake_speed * rp * tf
		done = front < from - GoldenConvergenceFire.RAKE_DEPTH * 0.5
	p["front"] = front
	var scorch: Array = p["scorch"]
	for j: int in mini(lanes.size(), GoldenConvergenceFire.RAKES):
		var lane: int = int(lanes[j])
		fire.set_rake_front(j, front, boss.court.is_open(_lane_side(lane), front))
		var a: float = clampf(front, from, to)
		if String(p["kind"]) == "v":
			fire.update_scorch(int(scorch[j]), from, a)
		else:
			fire.update_scorch(int(scorch[j]), a, to)
	if done:
		_end_pass(p)


## A horizontal pass's lines: the sweep across, each lane burning from the moment it reaches it; the live
## line until the runner is past it, the lines for show for show_burn.
func _tick_line(p: Dictionary) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var tf: float = float(p["t"]) - t.warning_seconds
	var s: float = clampf(tf / maxf(t.sweep_seconds, 0.05), 0.0, 1.0)
	var dir: int = int(p["dir"])
	var x: float = _sweep_x(s, dir, geo.wall_x() + 1.0)
	var lit: Dictionary = p["lit"]
	var line_at: float = float(p["line_at"])
	var opening: int = int(p["opening"])
	var shows: Array = p["shows"]
	for lane: int in geo.lane_count:
		if lit.has(lane):
			continue
		if (x - geo.lane_x(lane)) * dir >= 0.0:
			lit[lane] = true
			fire.set_line_lane(0, lane, true)
			for k: int in mini(shows.size(), GoldenConvergenceFire.LINES - 1):
				fire.set_line_lane(k + 1, lane, true)
			if lane == opening and not bool(p["sparked"]):
				_spark(p)
	# The walls: the one it starts from at once, the other as the sweep gets there.
	for side: int in [-1, 1]:
		var on: bool = side == -dir or s >= 1.0
		var wall_open: bool = boss.court.is_open(side, line_at)
		fire.set_line_wall(0, side, on, wall_open)
	var shows_out: bool = tf >= t.sweep_seconds + t.show_burn
	if shows_out and not p.has("shows_done"):
		p["shows_done"] = true
		for k: int in mini(shows.size(), GoldenConvergenceFire.LINES - 1):
			fire.stop_line(k + 1)
			(p["scorch"] as Array).append(fire.scorch_line(float(shows[k]), -geo.wall_x(), geo.wall_x()))
	var past: bool = boss.player_distance() > line_at + t.line_depth * 0.5 + 1.0
	if past and not p.has("passed_at"):
		p["passed_at"] = tf
	var over: bool = p.has("passed_at") and tf >= float(p["passed_at"]) + t.line_burn_after
	if (over and shows_out) or tf >= t.sweep_seconds + t.cross_lead + t.line_burn_after + LINE_TIMEOUT:
		fire.stop_line(0)
		(p["scorch"] as Array).append(fire.scorch_line(line_at, -geo.wall_x(), geo.wall_x()))
		if not p.has("shows_done"):
			p["shows_done"] = true
			for k: int in mini(shows.size(), GoldenConvergenceFire.LINES - 1):
				fire.stop_line(k + 1)
		_end_pass(p)


## The sweep's x at progress `s` (0-1) going toward `dir` across `half` either side of the middle.
static func _sweep_x(s: float, dir: int, half: float) -> float:
	return dir * lerpf(-half, half, s)


## The bullets spark off the stone above the buttress's opening.
func _spark(p: Dictionary) -> void:
	p["sparked"] = true
	var b: GoldenConvergenceButtress = p.get("buttress") as GoldenConvergenceButtress
	var at: Vector3 = b.spark_point() if b != null and is_instance_valid(b) and b.standing() \
		else boss.world.lane_point(int(p["opening"]), float(p["line_at"]), boss.tuning.arch_height + 0.6)
	boss.world.effects.burst(at, Color(1.0, 0.82, 0.55), 26, 0.9)
	boss.sound(&"gc_spark", boss.sound_point(at))
	boss.log_event(&"pass_spark", {"n": int(p["n"]), "lane": int(p["opening"])})


func _end_pass(p: Dictionary) -> void:
	p["stage"] = PassStage.DONE
	for node: Variant in p["warnings"]:
		boss.props.remove(node as Node)
	p["warnings"] = []
	fire.clear()
	for i: int in GoldenConvergenceSquadron.MAX:
		fire.hide_tracer(i)
	boss.log_event(&"pass_done", {"n": int(p["n"]), "kind": p["kind"]})
	current = -1


## Raises each horizontal pass's buttress once the runner is buttress_sight from its line.
func _place_buttresses() -> void:
	var d: float = boss.player_distance()
	var v: float = boss.speed_planned()
	for p: Dictionary in passes:
		if String(p["kind"]) != "H" or p.get("buttress") != null or int(p["stage"]) == PassStage.DONE:
			continue
		if d >= float(p["line_at"]) - v * boss.tuning.buttress_sight:
			p["buttress"] = boss.place_buttress(int(p["opening"]), float(p["line_at"]), int(p["lean"]))


func _lane_side(lane: int) -> int:
	if lane == 0:
		return -1
	if lane == boss.lane_count() - 1:
		return 1
	return 0


# --- The squadron's flight ---------------------------------------------------------------------------

## Where every drone is now, and what its guns do.
func _fly(delta: float) -> void:
	var n: int = squadron.size()
	var k: float = 1.0 - exp(-FOLLOW_RATE * delta)
	var p: Dictionary = passes[current] if current >= 0 else {}
	for i: int in n:
		var pose: Dictionary = _pose(i, p)
		var at: Vector3 = pose["pos"]
		var now: Vector3 = squadron.drone_position(i) if squadron.flying(i) else boss.cape_point(i)
		var exact: bool = bool(pose.get("exact", false))
		var pos: Vector3 = at if exact else now.lerp(at, k)
		var facing: Vector3 = pose.get("facing", at - now)
		var aim: Vector3 = pose.get("aim", pos + Vector3(0.0, -3.0, 6.0))
		var firing: bool = bool(pose.get("firing", false))
		squadron.set_drone(i, pos, facing, aim, firing, float(pose.get("spin", 0.0)), float(pose.get("pitch", 0.15)))
		if firing:
			fire.set_tracer(i, squadron.muzzle_point(i), aim)
		else:
			fire.hide_tracer(i)
	for i: int in range(n, GoldenConvergenceSquadron.MAX):
		squadron.stow(i)


## Drone `i`'s pose now ({pos, facing, aim, firing, spin, pitch, exact}) for pass `p` ({} between passes).
func _pose(i: int, p: Dictionary) -> Dictionary:
	var t: GoldenConvergenceTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var d: float = boss.player_distance()
	if stage == Stage.RETURN:
		return {"pos": boss.cape_point(i), "facing": Vector3.FORWARD, "pitch": -0.1}
	if held:
		var held_at: Vector3 = hold_station.call(i) if hold_station.is_valid() else _station(i, d)
		return {"pos": held_at, "facing": Vector3.BACK}
	if stage == Stage.EMERGE or p.is_empty():
		return {"pos": _station(i, d), "facing": Vector3.BACK}
	var warn: bool = int(p["stage"]) == PassStage.WARN
	var tf: float = float(p["t"]) - t.warning_seconds
	var spin: float = clampf(float(p["t"]) / t.warning_seconds, 0.0, 1.0) if warn else 1.0
	if String(p["kind"]) == "H":
		var lines: Array[float] = [float(p["line_at"])]
		for s: Variant in p["shows"]:
			lines.append(float(s))
		var line: float = lines[mini(i, lines.size() - 1)]
		var dir: int = int(p["dir"])
		var half: float = geo.wall_x() + SWEEP_OUT
		var s_now: float = 0.0 if warn else clampf(tf / maxf(t.sweep_seconds, 0.05), 0.0, 1.0)
		var x: float = _sweep_x(s_now, dir, half)
		var pos := Vector3(x, t.line_fly_height + 0.6 * i, TrackGeometry.world_z(line + 3.0))
		var aim := Vector3(_sweep_x(s_now, dir, geo.wall_x() + 1.0), 0.1, TrackGeometry.world_z(line))
		var firing: bool = not warn and s_now < 1.0 and (i == 0 or not p.has("shows_done"))
		return {"pos": pos, "facing": Vector3(dir, 0.0, 0.0), "aim": aim, "firing": firing, "spin": spin, "exact": not warn,
			"pitch": 0.2}
	var lanes: Array = p["lanes"]
	var behind: bool = String(p["kind"]) == "v"
	var lane: int = -1
	var climb: float = 0.0
	if i < lanes.size():
		lane = int(lanes[i])
	else:
		# The spare drone: above the formation, over the covered lane nearest the middle, holding its fire.
		lane = _middle_lane(lanes)
		climb = t.spare_climb * float(i - lanes.size() + 1)
	var x: float = geo.lane_x(lane)
	var y: float = t.fly_height + climb
	# Before the guns open up the drones hold where their fire will start (the stretch's far end head-on,
	# its near end from behind), so they open up from where they are.
	var front: float
	if warn:
		front = float(p["from"]) if behind else float(p["to"])
	else:
		front = float(p["front"])
	var ahead: float = -t.rake_lead if behind else t.rake_lead
	var pos := Vector3(x, y, TrackGeometry.world_z(front + ahead))
	var aim := Vector3(x, 0.1, TrackGeometry.world_z(front))
	var firing: bool = not warn and climb <= 0.0
	return {"pos": pos, "facing": Vector3.FORWARD if behind else Vector3.BACK, "aim": aim, "firing": firing,
		"spin": spin if climb <= 0.0 else 0.2, "exact": not warn, "pitch": 0.3}


## The covered lane nearest the track's middle (the spare drone holds above it).
func _middle_lane(lanes: Array) -> int:
	var mid: float = (boss.lane_count() - 1) * 0.5
	var best: int = int(lanes[0]) if not lanes.is_empty() else 0
	for l: Variant in lanes:
		if absf(float(l) - mid) < absf(float(best) - mid):
			best = int(l)
	return best


## Drone `i`'s station ahead of the runner at `d`, between passes: spread across the track, high.
func _station(i: int, d: float) -> Vector3:
	var t: GoldenConvergenceTuning = boss.tuning
	var n: int = squadron.size()
	var spread: float = boss.world.geo.half_width() * 0.7
	var x: float = 0.0 if n <= 1 else lerpf(-spread, spread, float(i) / float(n - 1))
	return Vector3(x, t.station_height + (0.8 if i % 2 == 1 else 0.0), TrackGeometry.world_z(d + t.station_ahead))


## Where a pass's warning is heard: where its drones gather.
func _formation_point(p: Dictionary) -> Vector3:
	var d: float = boss.player_distance()
	if String(p["kind"]) == "H":
		return Vector3(0.0, 4.0, TrackGeometry.world_z(float(p["line_at"])))
	if String(p["kind"]) == "v":
		return Vector3(0.0, 4.0, TrackGeometry.world_z(d - 6.0))
	return Vector3(0.0, 4.0, TrackGeometry.world_z(float(p["to"])))


# --- Hold, the pad, clear ------------------------------------------------------------------------------

## Holds its fire (E5d-c's cage: "the squadron holds its fire while the cage comes up and the runner goes
## for it, hovering in formation beside the ship, and fires on once the runner is past the pad"): the pass
## under way stops at once (its warnings and fire gone) and comes again on release, with the passes after it
## planned on from where the runner is then.
func hold(on: bool) -> void:
	if on == held:
		return
	held = on
	if on:
		if current >= 0:
			var p: Dictionary = passes[current]
			for node: Variant in p["warnings"]:
				boss.props.remove(node as Node)
			p["warnings"] = []
			p["stage"] = PassStage.WAIT
			fire.clear()
			for i: int in GoldenConvergenceSquadron.MAX:
				fire.hide_tracer(i)
			current = -1
		boss.log_event(&"strafe_held", {"n": strafes})
		return
	var next: int = -1
	for i: int in passes.size():
		if int(passes[i]["stage"]) != PassStage.DONE:
			next = i
			break
	if next >= 0 and stage == Stage.PASSES:
		# Buttresses already up for passes still to come stand where their lines no longer are: they go.
		for i: int in range(next, passes.size()):
			var b: Variant = passes[i].get("buttress")
			if b != null and is_instance_valid(b):
				(b as GoldenConvergenceButtress).release()
			passes[i]["buttress"] = null
		_plan(boss.player_distance() + boss.speed_planned() * boss.tuning.pass_gap / _pace, next)
	boss.log_event(&"strafe_released", {"n": strafes, "next": next})


## Everything at once (a phase's end, the defeat): warnings, fire and tracers gone, the squadron back in the
## cape, buttresses still ahead of the runner gone.
func clear() -> void:
	super()
	for p: Dictionary in passes:
		for node: Variant in p.get("warnings", []):
			boss.props.remove(node as Node)
		var b: Variant = p.get("buttress")
		if b != null and is_instance_valid(b) and (b as GoldenConvergenceButtress).at > boss.player_distance():
			(b as GoldenConvergenceButtress).release()
	passes.clear()
	current = -1
	fire.clear()
	for i: int in GoldenConvergenceSquadron.MAX:
		fire.hide_tracer(i)
	if stage != Stage.HURLED:
		squadron.stow_all()
	stage = Stage.IDLE
	stage_time = 0.0


## GDD §9.6, §10: a pad hurls the whole squadron up while it's out, and the strafe is over.
func _on_player_event(movement: StringName) -> void:
	if movement != &"pad" or stage == Stage.IDLE or stage == Stage.HURLED:
		return
	if squadron.out_count() <= 0:
		return
	for p: Dictionary in passes:
		for node: Variant in p.get("warnings", []):
			boss.props.remove(node as Node)
		p["warnings"] = []
	fire.clear()
	for i: int in GoldenConvergenceSquadron.MAX:
		fire.hide_tracer(i)
	squadron.hurl()
	current = -1
	held = false
	stage = Stage.HURLED
	stage_time = 0.0
	boss.sound(&"gc_hurl", boss.sound_point(squadron.drone_position(0)))
	boss.log_event(&"squadron_hurled", {"n": strafes})
	hurled.emit()


func _on_fire_hit(hit_kind: StringName, lane: int, outcome: int) -> void:
	boss.log_event(&"strafe_hit", {"kind": hit_kind, "lane": lane, "outcome": outcome, "pass": current,
		"runner": boss.player_distance()})
