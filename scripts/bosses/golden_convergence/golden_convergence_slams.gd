class_name GoldenConvergenceSlams
extends GoldenConvergenceAttack
## The Fist Slam (GDD §10, the owner's attack, "meant to be scary"; task E5d-b), beat kind `slams`: a sequence
## of slams from the phase's script (GoldenConvergenceTuning.slam_scripts: phase 1 "Ooa", ON, ON, AHEAD with
## chances on 2 and 3; later phases "OAooA", chances on 3 and 4), the suit's fists taking turns (left, right),
## each slam_gap apart over the phase's pace. Every point of a slam is keyed to the runner's distance at the
## run speed (so a dash never desyncs it):
## 1. out: the arm swings out on its golden segments and telescopes (GoldenConvergenceSuit.set_arm, past a
##    full telescope: extend_for) until the fist hovers over the runner's lane at fist_hover_height, over the
##    middle of the slam's row, following the runner's lane;
## 2. the warning (slam_track_seconds before the lock, never shortened by the pace): the fist rises toward
##    fist_raise_height, its shadow grows on the floor under it, the red square (GoldenConvergenceFist) shows
##    the hole's footprint round the runner's lane, and the deep grinding wind-up plays (gc_grind, a clank at
##    the lock);
## 3. the lock, slam_lock_seconds before it lands: the lane it's over now (GoldenConvergence.player_lane) and
##    the footprint round it (GoldenConvergenceHole.footprint: two lanes on 3 lanes, three on 5 or 6, moved
##    inward at the edge) are fixed; the red square stops following;
## 4. the fall (slam_fall_seconds), then the impact as the runner reaches its point: a slam ON the runner
##    lands as they reach the middle of its row (they're under it unless they've left the footprint); a slam
##    AHEAD lands slam_ahead_seconds before they reach its row (its hole to be jumped or gone round). The
##    footprint's floor cuts open at once (FloorCut.advance_to) and read as one square hole
##    (GoldenConvergenceHole.join); the fist's touch (an enemy attack over the footprint from the floor to
##    above a jump) is live for slam_hit_seconds; rubble, dust, a shake, gc_slam and gc_break. A runner under
##    it who lives through the touch (the armor or the shield blocks it, the dash passes, invulnerable) has
##    the floor under them held for GameRules.cut_hold_seconds (FloorCut.hold_under): a moment to jump out or
##    switch lanes. A grapple saves a fall, never the hit;
## 5. the fist plunges into the hole and goes back to rest at his side (slam_back_seconds over the pace).
## The holes: each slam's row is planned before the sequence begins (floor cuts must lie past the built track,
## BossArena.stream_from(), about 180 m ahead), a cut in every lane of the row, since the footprint isn't
## known until the lock; the lanes outside the footprint never open. The sequence is planned from the beat
## before it while that one plays (its ends_at), or from a phase's start (its first beat), or at the latest
## when its beat begins (the first fist then comes out at once and stalks the runner's lane until its warning).
## The chances (GDD §10: "two slams land at a Flying Buttress"): a Flying Buttress stands in an inner lane
## where the chance slam lands, its row dug just in front of the gate (so a hole sharing the gate's lane never
## goes through it: on 3 lanes the middle lane is the only inner one), coming into view buttress_sight before
## the runner gets there. A fist locked onto the buttress's lane smashes it (GoldenConvergenceButtress.smash):
## the building it held up topples on the side its arch leans toward (GoldenConvergenceTower, from a pool
## here) and its side is a wall for tower_wall_seconds of running; the sequence is over at once (the other
## gate still standing sinks away) and the Missile Barrage warms up at once as the tower falls (gap_after 0).
## A fist locked onto another lane digs its hole beside the gate, never through it.
## Numbers: GoldenConvergenceTuning's "Fist Slam" and "The toppled tower" groups (DESIGN-TBD,
## docs/questions/e5d.md, E5d-b).

## A slam's warning began, it locked, it landed (the bot and tests read them).
signal slam_warned(info: Dictionary)
signal slam_locked(info: Dictionary)
signal slam_landed(info: Dictionary)

enum Stage { IDLE, ON }
enum SlamStage { PLANNED, OUT, TRACK, LOCKED, FALL, HIT, BACK, DONE, SKIPPED }

const FIST_SCRIPT: Script = preload("res://scripts/bosses/golden_convergence/golden_convergence_fist.gd")
## Towers made with the fight (one falls per barrage, so two cover one sinking while the next falls).
const TOWER_POOL: int = 2
## The first row starts at least this far past the built track.
const ROW_MARGIN: float = 2.0
## How fast the fist follows the runner's lane (1/s), and how fast an arm eases back to rest.
const FOLLOW_RATE: float = 7.0
const ARM_RATE: float = 9.0
## The fist's middle this high over the floor as its knuckles meet it, and as deep as it plunges.
const CONTACT: float = 2.2
const PLUNGE: float = 0.4
## The fist's shadow at its fullest (metres across).
const SHADOW_SIZE: float = 7.0

var fist: GoldenConvergenceFist
var towers: Array[GoldenConvergenceTower] = []
var stage: Stage = Stage.IDLE
## The sequence under way or planned: {n, letter, kind (&"on" / &"ahead"), chance, fist (0 its right, 1 its
## left), side (-1, 1), impact_at, row (Vector2: from, to), mid (where the fist lands along the track),
## out_at, track_at, lock_at, fall_at, stage, t, lane, x, sq (Vector2: the red square's x edges), lanes,
## buttress_lane, lean, gate_at, buttress, bait, held, marker, out_from}.
var slams: Array[Dictionary] = []
## Slams of a plan dropped (a new one made, a sequence over) whose fist was still down or going back: they play
## on to rest (their touch off on time, the arm eased back) outside the plan.
var finishing: Array[Dictionary] = []
## Sequences begun this fight; whether the last one ended on a buttress hit.
var sequences: int = 0
var ended: bool = false
var ended_by_hit: bool = false
## The beat a plan is for ("phase:beat number"), and how it was made (&"ahead", &"phase", &"start").
var plan_key: String = ""
var planned_by: StringName = &""
## Rows planned this fight (their cuts are on the track for good; a cut never opened is the floor).
var rows_planned: int = 0

var _rng := RandomNumberGenerator.new()
var _pace: float = 1.0
## Per fist: the arm's handles now {target, blend, extend, fist}.
var _arms: Array[Dictionary] = []
var _hinted_bait: bool = false


func _init(p_boss: GoldenConvergence) -> void:
	super(p_boss, &"slams")
	fist = boss.add_part(FIST_SCRIPT, {"tuning": boss.tuning}) as GoldenConvergenceFist
	for i: int in TOWER_POOL:
		_new_tower()
	for i: int in GoldenConvergenceFist.RIGS:
		_arms.append({"target": Vector3.ZERO, "blend": 0.0, "extend": 0.0, "fist": false})
	boss.phase_started.connect(_on_phase_started)


func _new_tower() -> GoldenConvergenceTower:
	var tower := GoldenConvergenceTower.new()
	boss.add_child(tower)
	tower.setup(boss)
	towers.append(tower)
	return tower


## The towers' meshes at the run's length, now (not mid-fight).
func prewarm() -> void:
	var length: float = _tower_length()
	for tower: GoldenConvergenceTower in towers:
		tower.prewarm(length)


## The phase's slam script (a letter a slam).
func script_for(index: int) -> String:
	var list: PackedStringArray = boss.tuning.slam_scripts
	if list.is_empty():
		return "OOA"
	return list[clampi(index, 0, list.size() - 1)]


func busy() -> bool:
	return stage == Stage.ON


## A slam's warning shows (from its red square to its touch).
func warning_on() -> bool:
	for s: Dictionary in in_play():
		if int(s["stage"]) in [SlamStage.TRACK, SlamStage.LOCKED, SlamStage.FALL, SlamStage.HIT]:
			return true
	return false


## Where the sequence under way will be over: its last slam's touch done.
func ends_at() -> float:
	if stage != Stage.ON or slams.is_empty():
		return -1.0
	if ended:
		return boss.player_distance()
	var last: Dictionary = slams[slams.size() - 1]
	return float(last["impact_at"]) + boss.speed_planned() * boss.tuning.slam_hit_seconds


## None after a buttress hit: the barrage warms up as the tower falls.
func gap_after() -> float:
	return 0.0 if ended_by_hit else boss.tuning.beat_gap


## The sequence begins (its plan made beforehand if it could be, or now).
func start(beat: Dictionary) -> void:
	var d: float = boss.player_distance()
	var key: String = _key(boss.beats_played)
	sequences += 1
	ended = false
	ended_by_hit = false
	_pace = boss.pace()
	if plan_key != key or slams.is_empty() or not _fits(d):
		_discard()
		plan_key = key
		planned_by = &"start"
		_plan(d)
	stage = Stage.ON
	# The first fist comes out now if its plan has it later: it stalks the runner's lane until its warning.
	var first: Dictionary = slams[0]
	first["out_at"] = minf(float(first["out_at"]), d)
	boss.log_event(&"slams_start", {"n": sequences, "script": _letters(), "planned_by": planned_by,
		"first_impact": first["impact_at"], "runner": d, "beat": beat.get("kind", &"slams")})


## True if the plan's first warning can still play in full from `d`.
func _fits(d: float) -> bool:
	return not slams.is_empty() and float(slams[0]["track_at"]) >= d - 0.01


## The slams under way: those finishing from a dropped plan, then the plan's.
func in_play() -> Array[Dictionary]:
	if finishing.is_empty():
		return slams
	var out: Array[Dictionary] = finishing.duplicate()
	out.append_array(slams)
	return out


func _letters() -> String:
	var out: String = ""
	for s: Dictionary in slams:
		out += String(s["letter"])
	return out


## "phase:beat number" for the beat started as the encounter's `played`th.
func _key(played: int) -> String:
	return "%d:%d" % [boss.phase_index, played]


# --- Planning -------------------------------------------------------------------------------------------

## Plans the phase's sequence for a beat starting as the runner reaches `start_d`: each slam's points at the
## run speed, its row's floor cuts in every lane (past the built track: the whole sequence moves on if its
## first row would be nearer), the chances' gates.
func _plan(start_d: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var v: float = boss.speed_planned()
	var p: float = boss.pace()
	var lanes: int = boss.lane_count()
	var letters: String = script_for(boss.phase_index)
	var row_len: float = GoldenConvergenceHole.hole_lanes(lanes) * geo.lane_width
	var gap: float = v * t.slam_gap / p
	var ahead: float = v * t.slam_ahead_seconds
	_rng.seed = hash([String(boss.def.id), "slams", boss.phase_index, rows_planned, boss.rng.seed])
	var first_impact: float = start_d + v * (t.slam_out_seconds / p + t.slam_track_seconds + t.slam_lock_seconds)
	var first_ahead: bool = letters.length() > 0 and letters[0].to_upper() == "A"
	var first_row: float = first_impact + ahead if first_ahead else first_impact - row_len * 0.5
	var earliest: float = (boss.arena.stream_from() if boss.arena != null else 0.0) + ROW_MARGIN
	if first_row < earliest:
		first_impact += earliest - first_row
	var cuts := LevelLayout.new()
	cuts.lane_count = lanes
	slams.clear()
	for k: int in letters.length():
		var letter: String = letters[k]
		var kind: StringName = &"ahead" if letter.to_upper() == "A" else &"on"
		var impact_at: float = first_impact + float(k) * gap
		var from: float = impact_at + ahead if kind == &"ahead" else impact_at - row_len * 0.5
		var row := Vector2(from, from + row_len)
		var lock_at: float = impact_at - v * t.slam_lock_seconds
		var track_at: float = lock_at - v * t.slam_track_seconds
		var side: int = -1 if k % 2 == 0 else 1
		var s := {"n": k, "letter": letter, "kind": kind, "chance": letter != letter.to_upper(), "fist": 0 if side < 0 else 1,
			"side": side, "impact_at": impact_at, "row": row, "mid": (row.x + row.y) * 0.5,
			"out_at": track_at - v * t.slam_out_seconds / p, "track_at": track_at, "lock_at": lock_at,
			"fall_at": impact_at - v * t.slam_fall_seconds, "stage": SlamStage.PLANNED, "t": 0.0, "lane": -1, "x": 0.0,
			"sq": Vector2.ZERO, "lanes": [], "buttress_lane": -1, "lean": 0, "gate_at": 0.0, "buttress": null,
			"bait": false, "held": false, "marker": null, "out_from": 0.0}
		if bool(s["chance"]):
			var gate_lane: int = 0 if lanes <= 2 else _rng.randi_range(1, lanes - 2)
			s["buttress_lane"] = gate_lane
			s["lean"] = _lean(gate_lane, lanes)
			s["gate_at"] = row.y + t.slam_gate_gap + t.pier_depth * 0.5
			# The fist smashes into the gate's front, its hole in front of it.
			s["mid"] = row.y
		for lane: int in lanes:
			cuts.cuts.append({"lane": lane, "start": row.x, "end": row.y, "warn": row_len, "charge": 0.0, "keep": 0.0,
				"speed": 0.0, "slam": true})
		# Pickups keep off the row (an attack is telegraphed there; a pickup never waits over a hole to come).
		var marker := Node3D.new()
		marker.name = "SlamRow"
		for lane: int in lanes:
			boss.props.floor_warning(marker, lane, row.x, row.y)
		s["marker"] = marker
		slams.append(s)
		rows_planned += 1
	if not slams.is_empty():
		var last_row: Vector2 = slams[slams.size() - 1]["row"]
		cuts.length = last_row.y + 1.0
	if boss.arena != null:
		boss.arena.add_pieces(cuts)
	boss.log_event(&"slams_planned", {"script": letters, "first_impact": first_impact, "start": start_d,
		"by": planned_by, "rows": slams.size(), "stream_from": earliest - ROW_MARGIN})


## The side a chance gate's arch leans to: the nearer edge, either way from the middle lane by the seed.
func _lean(lane: int, lanes: int) -> int:
	var mid: float = (lanes - 1) * 0.5
	if float(lane) < mid - 0.01:
		return -1
	if float(lane) > mid + 0.01:
		return 1
	return -1 if _rng.randf() < 0.5 else 1


## Drops a plan that won't be played (its beat came too late for it, or it's over): its gates still up sink
## away, a fist still down or going back plays on to rest (finishing). Its cuts stay on the track, whole.
func _discard() -> void:
	for s: Dictionary in slams:
		if int(s["stage"]) in [SlamStage.HIT, SlamStage.BACK]:
			finishing.append(s)
		var b: Variant = s.get("buttress")
		if b != null and is_instance_valid(b) and (b as GoldenConvergenceButtress).standing():
			(b as GoldenConvergenceButtress).sink()
	slams.clear()
	plan_key = ""


## Plans the next slams beat ahead of time, from the beat under way (its ends_at), so its holes lie past the
## built track without a wait when it begins.
func _look_ahead() -> void:
	if stage == Stage.ON or boss.beats.is_empty():
		return
	var current: GoldenConvergenceAttack = boss.beat_attack
	if current == null or current == self:
		return
	var next: int = boss.beat_index + 1
	if next >= boss.beats.size():
		next = mini(boss.tuning.loop_start(boss.phase_index), boss.beats.size() - 1)
	if boss.beats[next]["kind"] != kind:
		return
	var key: String = _key(boss.beats_played + 1)
	if key == plan_key:
		return
	var end: float = current.ends_at()
	if end < 0.0:
		return
	_discard()
	plan_key = key
	planned_by = &"ahead"
	_plan(end + boss.speed_planned() * current.gap_after() / boss.pace())


## A phase begins: if its first beat is a slam sequence, it's planned from the phase's intro (once the
## encounter has set the phase up: it clears its attacks as the phase starts).
func _on_phase_started(index: int) -> void:
	_plan_phase.call_deferred(index)


func _plan_phase(index: int) -> void:
	if index != boss.phase_index or index >= GoldenConvergence.STAGE_2 or boss.is_defeated() or stage == Stage.ON:
		return
	var beats: Array[Dictionary] = boss.tuning.beats_for(index)
	if beats.is_empty() or beats[0]["kind"] != kind or boss.beat_index >= 0:
		return
	var key: String = _key(boss.beats_played + 1)
	if key == plan_key:
		return
	var intro: float = boss.def.phase_list()[index].intro_seconds
	var left: float = maxf(intro - (boss.state_time if boss.state == BossEncounter.State.INTRO else intro), 0.0)
	_discard()
	plan_key = key
	planned_by = &"phase"
	_plan(boss.player_distance() + boss.speed_planned() * (left + boss.tuning.first_beat_delay / boss.pace()))
	# Attacks don't tick in the intro: a gate due to rise before the pattern begins rises now.
	_place_buttresses(boss.speed_planned() * left)


# --- The slams ---------------------------------------------------------------------------------------------

func tick(delta: float) -> void:
	_look_ahead()
	_place_buttresses()
	var d: float = boss.player_distance()
	if stage == Stage.ON:
		for s: Dictionary in slams:
			_advance(s, d, delta)
		if ended or _over():
			stage = Stage.IDLE
			boss.log_event(&"slams_done", {"n": sequences, "hit": ended_by_hit})
	else:
		for s: Dictionary in slams:
			# A sequence over: its last fist goes on back to rest.
			if int(s["stage"]) in [SlamStage.HIT, SlamStage.BACK]:
				_advance(s, d, delta)
	for s: Dictionary in finishing:
		_advance(s, d, delta)
	finishing = finishing.filter(func(s: Dictionary) -> bool: return int(s["stage"]) in [SlamStage.HIT, SlamStage.BACK])
	_marks()
	_pose_arms(delta)
	for tower: GoldenConvergenceTower in towers:
		tower.tick(delta)


## Every slam past its touch (or skipped).
func _over() -> bool:
	for s: Dictionary in slams:
		if int(s["stage"]) < SlamStage.BACK:
			return false
	return true


## Moves slam `s` on through its stages as the runner reaches its points (several in one frame, if a dash
## carries them past).
func _advance(s: Dictionary, d: float, delta: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	if int(s["stage"]) in [SlamStage.HIT, SlamStage.BACK]:
		s["t"] = float(s["t"]) + delta
	for guard: int in 8:
		match int(s["stage"]):
			SlamStage.PLANNED:
				if ended or d < float(s["out_at"]):
					break
				s["stage"] = SlamStage.OUT
				s["out_from"] = d
				_follow(s, 1.0)
			SlamStage.OUT:
				if d < float(s["track_at"]):
					break
				_warn(s)
			SlamStage.TRACK:
				if d < float(s["lock_at"]):
					break
				_lock(s)
			SlamStage.LOCKED:
				if d < float(s["fall_at"]):
					break
				s["stage"] = SlamStage.FALL
			SlamStage.FALL:
				if d < float(s["impact_at"]):
					break
				_impact(s)
			SlamStage.HIT:
				_check_under(s)
				if float(s["t"]) < t.slam_hit_seconds:
					break
				fist.touch_off(int(s["fist"]))
				s["stage"] = SlamStage.BACK
			SlamStage.BACK:
				if float(s["t"]) < t.slam_hit_seconds + t.slam_back_seconds / _pace:
					break
				s["stage"] = SlamStage.DONE
			_:
				break
	if int(s["stage"]) in [SlamStage.OUT, SlamStage.TRACK]:
		_follow(s, 1.0 - exp(-FOLLOW_RATE * delta))


## The fist follows the runner's lane (by `k` of the way this frame): over the lane, the red square over the
## footprint round it.
func _follow(s: Dictionary, k: float) -> void:
	var geo: TrackGeometry = boss.world.geo
	var lane: int = boss.player_lane()
	s["lane"] = lane
	var box: Vector2 = _footprint_x(GoldenConvergenceHole.footprint(lane, geo.lane_count, int(s["side"])))
	if int(s["stage"]) == SlamStage.PLANNED or (s["sq"] as Vector2) == Vector2.ZERO:
		s["x"] = geo.lane_x(lane)
		s["sq"] = box
		return
	s["x"] = lerpf(float(s["x"]), geo.lane_x(lane), k)
	var sq: Vector2 = s["sq"]
	s["sq"] = Vector2(lerpf(sq.x, box.x, k), lerpf(sq.y, box.y, k))


## World x from the first lane's floor edge to the last's (the outer lanes' floor runs on to the wall).
func _footprint_x(lanes: Array) -> Vector2:
	var geo: TrackGeometry = boss.world.geo
	if lanes.is_empty():
		return Vector2.ZERO
	return Vector2(geo.lane_floor_span(int(lanes[0])).x, geo.lane_floor_span(int(lanes[lanes.size() - 1])).y)


## The warning: the red square, the shadow, the grinding wind-up.
func _warn(s: Dictionary) -> void:
	s["stage"] = SlamStage.TRACK
	s["warned_at"] = boss.fight_time()
	var info: Dictionary = _info(s)
	boss.sound(&"gc_grind", boss.sound_point(_fist_point(s)))
	boss.log_event(&"slam_warned", info)
	slam_warned.emit(info)
	boss.hint("fist")


## The lock: the lane under the fist now, and the footprint round it, fixed.
func _lock(s: Dictionary) -> void:
	var geo: TrackGeometry = boss.world.geo
	s["stage"] = SlamStage.LOCKED
	var lane: int = boss.player_lane()
	s["lane"] = lane
	s["lanes"] = GoldenConvergenceHole.footprint(lane, geo.lane_count, int(s["side"]))
	s["sq"] = _footprint_x(s["lanes"])
	s["x"] = geo.lane_x(lane)
	var b: Variant = s.get("buttress")
	s["bait"] = bool(s["chance"]) and b != null and is_instance_valid(b) and (b as GoldenConvergenceButtress).standing() \
		and lane == int(s["buttress_lane"])
	s["locked_at"] = boss.fight_time()
	var info: Dictionary = _info(s)
	boss.log_event(&"slam_locked", info)
	slam_locked.emit(info)


## The impact: the footprint's floor gone at once as one hole, the fist's touch live, rubble, the shake; a
## gate under it smashed.
func _impact(s: Dictionary) -> void:
	var row: Vector2 = s["row"]
	var i: int = int(s["fist"])
	s["stage"] = SlamStage.HIT
	s["t"] = 0.0
	s["impacted_at"] = boss.fight_time()
	var opened: Array[FloorCut] = []
	for lane: Variant in s["lanes"]:
		var fc: FloorCut = boss.world.track.floor_cut(int(lane), row.y)
		if fc == null:
			continue
		fc.advance_to(fc.start)
		opened.append(fc)
	GoldenConvergenceHole.join(opened)
	var box: Vector2 = s["sq"]
	fist.set_touch(i, box.x, box.y, row.x, row.y)
	fist.impact(box.x, box.y, row.x, row.y)
	boss.world.effects.shake(0.55, 0.45)
	var at: Vector3 = Vector3(float(s["x"]), 0.5, TrackGeometry.world_z(float(s["mid"])))
	boss.sound(&"gc_slam", boss.sound_point(at))
	boss.sound(&"gc_break", boss.sound_point(at))
	var info: Dictionary = _info(s)
	info["opened"] = opened.size()
	boss.log_event(&"slam_impact", info)
	slam_landed.emit(info)
	_check_under(s)
	if bool(s["bait"]):
		_bait(s)


## A runner under the fist's touch who lives through it (blocked by the armor or the shield, dashing,
## invulnerable) has the floor under them held, once (GDD §10: "the floor under the runner holds for about a
## second ... A dash through the fist gets the same second").
func _check_under(s: Dictionary) -> void:
	if bool(s["held"]):
		return
	var p: Player = boss.world.player
	if not p.alive or p.surface != Player.Surface.FLOOR or not fist.touch_on(int(s["fist"])):
		return
	var box: Vector2 = s["sq"]
	var row: Vector2 = s["row"]
	var half: float = boss.world.tuning.hurtbox_size.x * 0.5
	var depth: float = boss.world.tuning.hurtbox_size.z * 0.5
	var x: float = p.position.x
	if x + half < box.x or x - half > box.y or p.distance + depth < row.x or p.distance - depth > row.y:
		return
	var outcome: int = DamageRules.resolve(fist.touch_hazard(int(s["fist"])), p.defense())
	if outcome == DamageRules.Outcome.KILL:
		return
	s["held"] = true
	var seconds: float = boss.world.rules.cut_hold_seconds if boss.world.rules != null else 1.0
	var feet: float = boss.world.tuning.foot_half_width
	var held: Array[int] = []
	for lane: Variant in s["lanes"]:
		var span: Vector2 = boss.world.geo.lane_floor_span(int(lane))
		if x + feet < span.x or x - feet > span.y:
			continue
		var fc: FloorCut = boss.world.track.floor_cut(int(lane), row.y)
		if fc != null:
			fc.hold_under(p, seconds)
			held.append(int(lane))
	boss.log_event(&"slam_hold", {"n": int(s["n"]), "lanes": held, "outcome": outcome, "dashing": p.dashing,
		"runner": p.distance})


## A fist locked onto a gate's lane smashes it: the tower it held up topples, and the sequence is over (the
## barrage warms up at once).
func _bait(s: Dictionary) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var b: GoldenConvergenceButtress = s["buttress"]
	b.smash()
	var v: float = boss.speed_planned()
	var wall_to: float = b.at + v * t.tower_wall_seconds
	var length: float = _tower_length()
	var foot: float = minf(boss.player_distance() - t.tower_behind, wall_to + GoldenConvergenceTower.CROWN - length)
	var tower: GoldenConvergenceTower = _free_tower()
	tower.topple(b.lean, foot, length, b.span().x, wall_to)
	ended = true
	ended_by_hit = true
	for other: Dictionary in slams:
		if other == s:
			continue
		if int(other["stage"]) < SlamStage.HIT:
			other["stage"] = SlamStage.SKIPPED
		var ob: Variant = other.get("buttress")
		if ob != null and is_instance_valid(ob) and (ob as GoldenConvergenceButtress).standing():
			(ob as GoldenConvergenceButtress).sink()
	boss.log_event(&"slam_bait", {"n": int(s["n"]), "lane": int(s["lane"]), "side": b.lean, "gate": b.at,
		"wall_from": b.span().x, "wall_to": wall_to, "runner": boss.player_distance()})


## The longest tower the fight needs: from its foot behind the runner as an ahead chance's gate falls (the
## farthest a gate stands from the runner at its impact) to its wall's end.
func _tower_length() -> float:
	var t: GoldenConvergenceTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var v: float = boss.speed_planned()
	var row_len: float = GoldenConvergenceHole.hole_lanes(geo.lane_count) * geo.lane_width
	var reach: float = v * t.slam_ahead_seconds + row_len + t.slam_gate_gap + t.pier_depth
	return GoldenConvergenceTower.length_for(t, v, reach)


func _free_tower() -> GoldenConvergenceTower:
	for tower: GoldenConvergenceTower in towers:
		if not tower.in_use():
			return tower
	var oldest: GoldenConvergenceTower = towers[0]
	for tower: GoldenConvergenceTower in towers:
		if tower.falls < oldest.falls:
			oldest = tower
	# Every tower in use (a third barrage within one's stay): the oldest gives way, a new one if it's still down.
	return _new_tower() if oldest.down() else oldest


## The towers lying now (the bot and tests).
func towers_down() -> Array[GoldenConvergenceTower]:
	var out: Array[GoldenConvergenceTower] = []
	for tower: GoldenConvergenceTower in towers:
		if tower.in_use():
			out.append(tower)
	return out


## Raises each chance's gate once the runner is buttress_sight from it (or will be, `ahead` metres on).
func _place_buttresses(ahead: float = 0.0) -> void:
	var d: float = boss.player_distance() + ahead
	var sight: float = boss.speed_planned() * boss.tuning.buttress_sight
	for s: Dictionary in slams:
		if not bool(s["chance"]) or s.get("buttress") != null or int(s["stage"]) == SlamStage.SKIPPED:
			continue
		if d >= float(s["gate_at"]) - sight:
			s["buttress"] = boss.place_buttress(int(s["buttress_lane"]), float(s["gate_at"]), int(s["lean"]))
			if not _hinted_bait:
				_hinted_bait = true
				boss.hint("bait")


func _info(s: Dictionary) -> Dictionary:
	return {"n": int(s["n"]), "kind": s["kind"], "chance": s["chance"], "lane": int(s["lane"]), "lanes": s["lanes"],
		"row": s["row"], "impact_at": s["impact_at"], "bait": s["bait"], "side": int(s["side"]),
		"buttress_lane": int(s["buttress_lane"]), "runner": boss.player_distance(), "runner_lane": boss.player_lane()}


# --- What it shows -----------------------------------------------------------------------------------------

## The red squares and the shadows for the slams warning now.
func _marks() -> void:
	var shown: Array[bool] = [false, false]
	var d: float = boss.player_distance()
	for s: Dictionary in slams:
		var st: int = int(s["stage"])
		if st < SlamStage.TRACK or st > SlamStage.FALL:
			continue
		var i: int = int(s["fist"])
		shown[i] = true
		var row: Vector2 = s["row"]
		var sq: Vector2 = s["sq"]
		var k: float = clampf((d - float(s["track_at"])) / maxf(float(s["impact_at"]) - float(s["track_at"]), 0.01), 0.0, 1.0)
		fist.set_square(i, sq.x, sq.y, row.x, row.y, k)
		fist.set_shadow(i, float(s["x"]), float(s["mid"]), SHADOW_SIZE, k)
	for i: int in shown.size():
		if not shown[i]:
			fist.hide_square(i)
			fist.hide_shadow(i)


## Where the fist of slam `s` is now (world space; its goal, the arm reaching for it).
func _fist_point(s: Dictionary) -> Vector3:
	var goal: Dictionary = _goal(s, boss.player_distance())
	return goal.get("target", Vector3.ZERO)


## Drives both arms toward their goals: exact while a fist is over the track and coming down, easing back
## to rest otherwise.
func _pose_arms(delta: float) -> void:
	var suit: GoldenConvergenceSuit = boss.suit
	if suit == null or not is_instance_valid(suit):
		return
	var d: float = boss.player_distance()
	var pose: Transform3D = boss.suit_transform()
	var k: float = 1.0 - exp(-ARM_RATE * delta)
	for i: int in _arms.size():
		var side: int = -1 if i == 0 else 1
		var driving: Dictionary = {}
		for s: Dictionary in in_play():
			if int(s["fist"]) == i and int(s["stage"]) in [SlamStage.OUT, SlamStage.TRACK, SlamStage.LOCKED,
					SlamStage.FALL, SlamStage.HIT, SlamStage.BACK]:
				driving = s
		var arm: Dictionary = _arms[i]
		if driving.is_empty():
			# Easing back to rest; once there, the arm is left alone (nothing of the slams drives it).
			if not bool(arm.get("active", false)):
				continue
			arm["blend"] = lerpf(float(arm["blend"]), 0.0, k)
			arm["extend"] = lerpf(float(arm["extend"]), 0.0, k)
			arm["fist"] = float(arm["blend"]) > 0.3 and bool(arm["fist"])
			if float(arm["blend"]) < 0.002 and float(arm["extend"]) < 0.002:
				arm["blend"] = 0.0
				arm["extend"] = 0.0
				arm["fist"] = false
				arm["active"] = false
		else:
			arm["active"] = true
			var goal: Dictionary = _goal(driving, d)
			var target: Vector3 = goal["target"]
			var extend: float = suit.extend_for(side, target, pose) * float(goal["reach"])
			if bool(goal["exact"]):
				arm["target"] = target
				arm["blend"] = float(goal["blend"])
				arm["extend"] = extend
			else:
				arm["target"] = (arm["target"] as Vector3).lerp(target, k) if float(arm["blend"]) > 0.05 else target
				arm["blend"] = lerpf(float(arm["blend"]), float(goal["blend"]), k)
				arm["extend"] = lerpf(float(arm["extend"]), extend, k)
			arm["fist"] = bool(goal["fist"])
		suit.set_arm(side, arm["target"], float(arm["blend"]), float(arm["extend"]), bool(arm["fist"]))


## Where slam `s`'s fist should be now: {target (world space), blend, reach (a share of the arm's reach to it),
## fist, exact}.
func _goal(s: Dictionary, d: float) -> Dictionary:
	var t: GoldenConvergenceTuning = boss.tuning
	var z: float = TrackGeometry.world_z(float(s["mid"]))
	var x: float = float(s["x"])
	var hover := Vector3(x, t.fist_hover_height, z)
	match int(s["stage"]):
		SlamStage.OUT:
			var span: float = maxf(boss.speed_planned() * t.slam_out_seconds / maxf(_pace, 0.05), 0.5)
			var u: float = smoothstep(0.0, 1.0, clampf((d - float(s["out_from"])) / span, 0.0, 1.0))
			return {"target": hover, "blend": u, "reach": u, "fist": u > 0.25, "exact": false}
		SlamStage.TRACK, SlamStage.LOCKED:
			var k: float = clampf((d - float(s["track_at"])) / maxf(float(s["fall_at"]) - float(s["track_at"]), 0.01), 0.0, 1.0)
			var y: float = lerpf(t.fist_hover_height, t.fist_raise_height, smoothstep(0.0, 1.0, k))
			return {"target": Vector3(x, y, z), "blend": 1.0, "reach": 1.0, "fist": true, "exact": true}
		SlamStage.FALL:
			var k: float = clampf((d - float(s["fall_at"])) / maxf(float(s["impact_at"]) - float(s["fall_at"]), 0.01), 0.0, 1.0)
			var y: float = lerpf(t.fist_raise_height, CONTACT, k * k)
			return {"target": Vector3(x, y, z), "blend": 1.0, "reach": 1.0, "fist": true, "exact": true}
		SlamStage.HIT:
			var k: float = smoothstep(0.0, 1.0, clampf(float(s["t"]) / maxf(t.slam_hit_seconds, 0.01), 0.0, 1.0))
			return {"target": Vector3(x, lerpf(CONTACT, PLUNGE, k), z), "blend": 1.0, "reach": 1.0, "fist": true, "exact": true}
		SlamStage.BACK:
			var back: float = maxf(t.slam_back_seconds / maxf(_pace, 0.05), 0.05)
			var u: float = smoothstep(0.0, 1.0, clampf((float(s["t"]) - t.slam_hit_seconds) / back, 0.0, 1.0))
			return {"target": Vector3(x, PLUNGE, z), "blend": 1.0 - u, "reach": 1.0 - u, "fist": u < 0.75, "exact": false}
	return {"target": hover, "blend": 0.0, "reach": 0.0, "fist": false, "exact": false}


# --- Hold, clear ---------------------------------------------------------------------------------------

## Everything gone at once (a phase's end, the defeat), safely: the touches off, the marks gone, the arms
## easing back to rest, the plan dropped (its cuts stay whole). A tower already down stays its time.
func clear() -> void:
	super()
	fist.clear()
	for s: Dictionary in in_play():
		if int(s["stage"]) < SlamStage.DONE:
			s["stage"] = SlamStage.SKIPPED
	finishing.clear()
	_discard()
	stage = Stage.IDLE
	ended = false
	ended_by_hit = false
