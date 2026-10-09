class_name GoldenConvergenceBarrage
extends GoldenConvergenceAttack
## The Missile Barrage (GDD §10, the owner's attack; task E5d-b), beat kind `barrage`: it follows its slam
## sequence in the beat script (warming up at once as the tower falls when a buttress was hit: the slams' gap
## after is none then), and comes whether or not there's a wall ("No wall ... the barrage comes anyway, and the
## player takes the hit"). Every point of its warning is keyed to the runner's distance at the run speed, so
## the fire lands where the marks said whatever the runner did; the warning keeps its seconds at every pace:
## 1. the shoulder pipes' hatches open (GoldenConvergenceSuit.pipes_open) with a heavy clank (gc_hatch): the
##    warning begins;
## 2. the missiles launch one after another from the pipes' mouths with a roar (gc_launch) and climb high,
##    while the red target marks spread over the floor, every lane over the fire's stretch
##    (GoldenConvergenceMissiles; counted as floor warnings, BossProps.floor_warning, so pickups keep off);
## 3. they hang at the top of their climb, ahead and above;
## 4. they dive with a rising whistle (gc_whistle) while the marks fill in; the fire lands as the marks are full
##    (gc_fire): over every lane from fire_behind behind the runner to as far as they can run while it burns
##    (the run speed plus the dash's bonus) and fire_ahead more, fire_height high (a jump only delays it), its
##    outer lanes clear of a wall runner's body: the wall is safe at every height;
## 5. it burns fire_seconds (never divided by the pace: GDD §10's layers of protection are seconds), then goes
##    out; its flames die down. It's an enemy attack: each armor hit and the shield block one touch and give the
##    usual second of invulnerability, the dash passes through: the free armor alone isn't enough, one armor hit
##    and the dash, two armor hits, or the armor and the shield get through (Player._check_hazards touches it
##    again every frame once the invulnerability is over).
## The warning leaves time to reach the wall from the far side (GoldenConvergenceTuning.wall_reach_seconds:
## the reaction, every lane switch, the wall entry and a margin; tested at 3, 5 and 6 lanes), and the burn
## is shorter than a wall run without claws, so a runner who got onto the wall as the marks filled drops back
## onto floor no longer burning (or wall hops, GDD §3, to stay up).
## Numbers: GoldenConvergenceTuning's "Missile Barrage" group (DESIGN-TBD, docs/questions/e5d.md, E5d-b).
## Extension points (E5d-c, the Refill Ship): `barrages` counts the barrages fired (a ship comes after the
## phase's); ends_at() says where the one under way will be over.

signal barrage_warned(info: Dictionary)
signal barrage_landed(info: Dictionary)

enum Stage { IDLE, HATCH, CLIMB, HANG, DIVE, FIRE }

const MISSILES_SCRIPT: Script = preload("res://scripts/bosses/golden_convergence/golden_convergence_missiles.gd")
## The missiles hang in the run camera's view, in front of the suit (it floats suit_ahead, 64 m, ahead, keeping
## pace with the runner; so do they, until they dive): this far ahead of the runner, spread this much along
## the track, out to either side of his chest from APEX_SIDE_MIN to APEX_SIDE_MAX (against his dark cape and
## the sky, not his gold), this much above and below missile_apex_height (framing). Their climb arcs up out of
## the top of the view first. DESIGN-TBD (docs/questions/e5d.md, E5d-b 10).
const APEX_AHEAD: float = 46.0
const APEX_SPREAD: float = 5.0
const APEX_SIDE_MIN: float = 8.0
const APEX_SIDE_MAX: float = 26.0
const APEX_HEIGHT_SPREAD: float = 2.5
## How far above its pipe a missile's climb reaches for (its curve's pull: it peaks about half this higher).
const CLIMB_PULL: float = 30.0
## Each mark spreads in over this long once it shows.
const MARK_IN: float = 0.15
## The hatches close this long once the last missile is out.
const HATCH_CLOSE: float = 0.6
## Blasts shown where missiles land (the rest of the fire is enough).
const BURSTS: int = 6

var missiles: GoldenConvergenceMissiles
var stage: Stage = Stage.IDLE
## Seconds since the barrage began, and in the fire.
var time: float = 0.0
var burn_time: float = 0.0
## Barrages fired this fight (E5d-c: the Refill Ship comes after the phase's).
var barrages: int = 0
## The barrage under way: {start, hatch_at, climb_at, hang_at, land_at (track distances the runner reaches),
## from, to (the fire's stretch), marks: Array[{lane, at, pos, hang (x, height, metres ahead of the runner),
## shows, launch, pipe, mouth}],
## markers: Array[Node3D]}.
var plan: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _hatch: float = 0.0


func _init(p_boss: GoldenConvergence) -> void:
	super(p_boss, &"barrage")
	missiles = boss.add_part(MISSILES_SCRIPT, {"tuning": boss.tuning}) as GoldenConvergenceMissiles


func busy() -> bool:
	return stage != Stage.IDLE


## Its warning shows or its fire burns.
func warning_on() -> bool:
	return stage != Stage.IDLE


## Where the barrage under way will be over: its fire burnt out.
func ends_at() -> float:
	var v: float = boss.speed_planned()
	match stage:
		Stage.IDLE:
			return -1.0
		Stage.FIRE:
			return boss.player_distance() + v * maxf(boss.tuning.fire_seconds - burn_time, 0.0)
	return float(plan["land_at"]) + v * boss.tuning.fire_seconds


## The time from its first warning to its fire, at the run speed (every lane count's: the warning never
## changes with it).
func warning_seconds() -> float:
	var t: GoldenConvergenceTuning = boss.tuning
	return t.barrage_hatch_seconds + t.barrage_climb_seconds + t.barrage_hang_seconds + t.barrage_dive_seconds


## What the warning must leave at `lanes` lanes (GDD §10: "the warning leaves time to reach the wall from the far
## side (up to 5 lane switches on 6 lanes, plus the wall entry)"): the reaction, a lane switch for every lane
## but one, the wall entry, a margin.
static func wall_reach_seconds(t: GoldenConvergenceTuning, movement: MovementTuning, lanes: int) -> float:
	return t.barrage_reaction + float(maxi(lanes - 1, 0)) * movement.lane_switch_time + movement.wall_entry_time \
		+ t.barrage_margin


## Seconds until the fire lands, at the run speed (-1 once it has, or with none coming).
func land_eta() -> float:
	if stage == Stage.IDLE or stage == Stage.FIRE or plan.is_empty():
		return -1.0
	return maxf(float(plan["land_at"]) - boss.player_distance(), 0.0) / boss.speed_planned()


## The barrage begins: its stretch and marks planned from the runner's distance at the run speed, the hatches
## opening.
func start(beat: Dictionary) -> void:
	clear()
	barrages += 1
	_rng.seed = hash([String(boss.def.id), "barrage", barrages, boss.rng.seed])
	_plan()
	stage = Stage.HATCH
	time = 0.0
	burn_time = 0.0
	var mouth: Vector3 = boss.suit.pipe_mouth(-1).lerp(boss.suit.pipe_mouth(1), 0.5)
	boss.sound(&"gc_hatch", boss.sound_point(mouth))
	var info: Dictionary = {"n": barrages, "from": plan["from"], "to": plan["to"], "land_at": plan["land_at"],
		"runner": boss.player_distance(), "lane": boss.player_lane(), "wall": _wall_side(), "marks": (plan["marks"] as Array).size(),
		"beat": beat.get("kind", &"barrage")}
	boss.log_event(&"barrage_warned", info)
	barrage_warned.emit(info)
	boss.hint("barrage")


## Its points along the track (the runner's distance at the run speed), its fire's stretch, its marks and
## missiles.
func _plan() -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var v: float = boss.speed_planned()
	var d: float = boss.player_distance()
	var lanes: int = geo.lane_count
	var hatch_at: float = d + v * t.barrage_hatch_seconds
	var climb_at: float = hatch_at + v * t.barrage_climb_seconds
	var hang_at: float = climb_at + v * t.barrage_hang_seconds
	var land_at: float = hang_at + v * t.barrage_dive_seconds
	var power: PowerupTuning = boss.world.powerup_tuning
	var dash: float = power.dash_speed_bonus * power.dash_duration if power != null else 0.0
	var from: float = land_at - t.fire_behind
	var to: float = land_at + v * t.fire_seconds + dash + t.fire_ahead
	var per: int = clampi(t.marks_per_lane, 1, GoldenConvergenceMissiles.MAX / maxi(lanes, 1))
	var spacing: float = (to - from) / float(per)
	var marks: Array[Dictionary] = []
	var order: Array[int] = []
	for r: int in per:
		for lane: int in lanes:
			var stagger: float = (0.3 if lane % 2 == 1 else -0.05) * spacing
			var at: float = clampf(from + (float(r) + 0.5) * spacing + stagger, from + t.mark_radius, to - t.mark_radius)
			var x: float = geo.lane_x(lane) + (_rng.randf() - 0.5) * geo.lane_width * 0.2
			var side: float = -1.0 if marks.size() % 2 == 0 else 1.0
			var hang := Vector3(side * lerpf(APEX_SIDE_MIN, APEX_SIDE_MAX, _rng.randf()),
				t.missile_apex_height + (_rng.randf() * 2.0 - 1.0) * APEX_HEIGHT_SPREAD,
				APEX_AHEAD + (_rng.randf() * 2.0 - 1.0) * APEX_SPREAD)
			order.append(marks.size())
			marks.append({"lane": lane, "at": at, "pos": Vector3(x, 0.0, TrackGeometry.world_z(at)), "hang": hang,
				"pipe": marks.size() % (GoldenConvergenceModel.PIPE_COUNT * 2), "mouth": Vector3.ZERO, "launched": false})
	# The marks spread over the floor in a scattered order; the missiles leave in another.
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	var n: int = marks.size()
	for k: int in n:
		var m: Dictionary = marks[order[k]]
		m["shows"] = float(k) / float(maxi(n, 1))
		m["launch"] = float(k) / float(maxi(n, 1))
	var markers: Array[Node3D] = []
	for lane: int in lanes:
		var marker := Node3D.new()
		marker.name = "BarrageMarks"
		boss.props.floor_warning(marker, lane, from, to)
		markers.append(marker)
	plan = {"start": d, "hatch_at": hatch_at, "climb_at": climb_at, "hang_at": hang_at, "land_at": land_at,
		"from": from, "to": to, "marks": marks, "markers": markers}
	missiles.show_missiles(0)
	missiles.show_marks(0)


func tick(delta: float) -> void:
	_tick_hatches(delta)
	if stage == Stage.IDLE:
		return
	time += delta
	var d: float = boss.player_distance()
	var t: GoldenConvergenceTuning = boss.tuning
	match stage:
		Stage.HATCH:
			if d >= float(plan["hatch_at"]):
				stage = Stage.CLIMB
				boss.sound(&"gc_launch", boss.sound_point(boss.suit.pipe_mouth(1)))
				boss.log_event(&"barrage_launch", {"n": barrages})
		Stage.CLIMB:
			if d >= float(plan["climb_at"]):
				stage = Stage.HANG
		Stage.HANG:
			if d >= float(plan["hang_at"]):
				stage = Stage.DIVE
				boss.sound(&"gc_whistle", boss.sound_point(Vector3(0.0, 8.0, TrackGeometry.world_z(d + 30.0))))
				boss.log_event(&"barrage_dive", {"n": barrages})
		Stage.DIVE:
			if d >= float(plan["land_at"]):
				_land()
		Stage.FIRE:
			burn_time += delta
			if burn_time >= t.fire_seconds:
				_out()
				return
	if stage != Stage.FIRE:
		_fly(d)


## The hatches open as the barrage begins and close once the missiles are out (and stay shut otherwise).
func _tick_hatches(delta: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var want: float = 0.0
	if stage in [Stage.HATCH, Stage.CLIMB]:
		want = 1.0
	if stage == Stage.CLIMB and not plan.is_empty():
		# Shut again once the last missile is out.
		var climb_span: float = maxf(float(plan["climb_at"]) - float(plan["hatch_at"]), 0.01)
		var k: float = (boss.player_distance() - float(plan["hatch_at"])) / climb_span
		if k * t.barrage_climb_seconds > t.barrage_salvo_seconds + 0.2:
			want = 0.0
	if want <= 0.0 and _hatch <= 0.0:
		# Shut: the hatches are left alone (nothing of the barrage drives them).
		return
	var rate: float = 1.0 / maxf(t.barrage_hatch_seconds if want > _hatch else HATCH_CLOSE, 0.05)
	_hatch = move_toward(_hatch, want, rate * delta)
	if boss.suit != null and is_instance_valid(boss.suit):
		boss.suit.pipes_open[0] = _hatch
		boss.suit.pipes_open[1] = _hatch


## The missiles and marks for where the runner is now.
func _fly(d: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var marks: Array = plan["marks"]
	var n: int = marks.size()
	var start: float = float(plan["start"])
	var hatch_at: float = float(plan["hatch_at"])
	var climb_at: float = float(plan["climb_at"])
	var hang_at: float = float(plan["hang_at"])
	var land_at: float = float(plan["land_at"])
	var salvo: float = t.barrage_salvo_seconds / maxf(t.barrage_climb_seconds, 0.05)
	# The marks spread in over the climb and the hang, and fill in over the dive.
	var spread: float = clampf((d - hatch_at) / maxf(hang_at - hatch_at, 0.01), 0.0, 1.0)
	var fill: float = clampf((d - hang_at) / maxf(land_at - hang_at, 0.01), 0.0, 1.0)
	var shown_count: int = 0
	var in_air: int = 0
	for i: int in n:
		var m: Dictionary = marks[i]
		var appear: float = clampf((spread - float(m["shows"]) * 0.85) / maxf(MARK_IN / maxf(t.barrage_climb_seconds + t.barrage_hang_seconds, 0.05), 0.01), 0.0, 1.0)
		missiles.set_mark(i, m["pos"], t.mark_radius, appear, fill)
		if spread >= float(m["shows"]) * 0.85:
			shown_count = i + 1
	missiles.show_marks(n if stage != Stage.HATCH else shown_count)
	if stage == Stage.HATCH:
		missiles.show_missiles(0)
		return
	# The missiles: launched one after another over the salvo, climbing to their apex, hanging, diving.
	var climb: float = clampf((d - hatch_at) / maxf(climb_at - hatch_at, 0.01), 0.0, 1.0)
	for i: int in n:
		var m: Dictionary = marks[i]
		var launch: float = float(m["launch"]) * salvo
		var pipe: int = int(m["pipe"])
		var side: int = -1 if pipe < GoldenConvergenceModel.PIPE_COUNT else 1
		var mouth: Vector3 = boss.suit.pipe_mouth(side) + Vector3(side * (float(pipe % GoldenConvergenceModel.PIPE_COUNT) - 1.5) * 1.5, 0.0, 0.0)
		# Where it hangs: pacing the runner until the dive, which leaves from where it hung then.
		var hang: Vector3 = m["hang"]
		var apex := Vector3(hang.x, hang.y, TrackGeometry.world_z(minf(d, hang_at) + hang.z))
		var pos: Vector3
		var dir: Vector3
		var trail: float = 1.0
		if climb < launch:
			# Still in its pipe.
			pos = mouth
			dir = Vector3.UP
			trail = 0.0
		elif stage == Stage.CLIMB or (stage == Stage.HANG and climb < 1.0):
			if not bool(m["launched"]):
				m["launched"] = true
				m["mouth"] = mouth
			var u: float = clampf((climb - launch) / maxf(1.0 - launch, 0.01), 0.0, 1.0)
			var from: Vector3 = m["mouth"]
			var ctrl: Vector3 = from + Vector3(0.0, CLIMB_PULL, 0.0)
			pos = _bezier(from, ctrl, apex, u)
			dir = _bezier(from, ctrl, apex, minf(u + 0.02, 1.0)) - pos
			trail = clampf(u * 4.0, 0.0, 1.0)
		elif stage == Stage.HANG:
			var wobble: float = sin(float(i) * 1.7 + boss.fight_time() * 3.0) * 0.6
			pos = apex + Vector3(wobble, 0.4 * sin(float(i) + boss.fight_time() * 2.0), 0.0)
			dir = Vector3(0.0, -0.35, 1.0)
			trail = 0.3
		else:
			var k: float = clampf((d - hang_at) / maxf(land_at - hang_at, 0.01), 0.0, 1.0)
			var target: Vector3 = m["pos"]
			var ctrl: Vector3 = apex + Vector3(0.0, 8.0, 0.0)
			var e: float = k * k
			pos = _bezier(apex, ctrl, target, e)
			dir = _bezier(apex, ctrl, target, minf(e + 0.02, 1.0)) - pos
			trail = 1.0
		missiles.set_missile(i, pos, dir, trail)
		in_air += 1
	missiles.show_missiles(in_air)


static func _bezier(a: Vector3, b: Vector3, c: Vector3, u: float) -> Vector3:
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


## The fire lands over the whole stretch, every lane at once.
func _land() -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	stage = Stage.FIRE
	burn_time = 0.0
	missiles.hide_missiles()
	missiles.hide_marks()
	var boxes: Array[Dictionary] = missiles.set_fire(float(plan["from"]), float(plan["to"]))
	var marks: Array = plan["marks"]
	for k: int in mini(BURSTS, marks.size()):
		missiles.burst(marks[(k * marks.size()) / BURSTS]["pos"])
	boss.world.effects.shake(0.4, 0.4)
	var p: Player = boss.world.player
	boss.sound(&"gc_fire", boss.sound_point(Vector3(p.position.x, 1.0, TrackGeometry.world_z(p.distance + 6.0))))
	var info: Dictionary = {"n": barrages, "from": plan["from"], "to": plan["to"], "runner": p.distance,
		"lane": boss.player_lane(), "surface": p.surface, "h": p.h, "wall": _wall_side(), "boxes": boxes}
	boss.log_event(&"barrage_fire", info)
	barrage_landed.emit(info)
	_remove_markers()


## The fire has burnt its time: out (its flames die down).
func _out() -> void:
	missiles.fire_off()
	stage = Stage.IDLE
	boss.log_event(&"barrage_out", {"n": barrages, "runner": boss.player_distance(), "burnt": burn_time})


## The side of a wall open where the runner is (-1 or 1), 0 for none.
func _wall_side() -> int:
	var d: float = boss.player_distance()
	for side: int in [-1, 1]:
		if boss.court.is_open(side, d) or boss.court.is_open(side, d + 30.0):
			return side
	return 0


func _remove_markers() -> void:
	for node: Variant in plan.get("markers", []):
		# The props free a warning once the runner is past it.
		if is_instance_valid(node):
			boss.props.remove(node as Node)


## Everything gone at once (a phase's end, the defeat), safely: no missile, no mark, no fire.
func clear() -> void:
	super()
	missiles.clear()
	if not plan.is_empty():
		_remove_markers()
	plan = {}
	stage = Stage.IDLE
	time = 0.0
	burn_time = 0.0
