class_name SleepTakerSlash
extends Node3D
## The Sleep Taker's giant slash (GDD §10: "giant slash across three lanes: the maw opens with a shriek
## (the Bad Dream's warning, bigger). Get out of those lanes, or up onto the ceiling"). The Bad Dream's
## slash (BadDream), grown, in its language:
## - the warning (slash_telegraph, then the lunge's slash_lunge: slash_warning() in all): its great maw
##   opens with its shriek (sleep_taker_shriek), its arms rise over the lanes and its claws and throat
##   heat up to enemy-attack red; the lanes it will slash are locked as the warning starts and light up
##   on the floor in enemy-attack red, filling toward the runner as the strike nears (the Bad Dream's
##   lane marks, BadDreamModel.marks_mesh); then it lunges at the runner (sleep_taker_slash);
## - the strike: its claws are live for slash_active over the locked lanes at the runner's spot (an
##   enemy attack: armor or a shield blocks one, the dash passes through), drawn as claw streaks; the
##   box keeps a margin at the lanes' edges and clear of the walls, and stops at slash_height, above a
##   jump's reach but far below a ceiling rider: leaving the lanes, a wall or the ceiling dodge it;
## - its timings don't follow the phase's pace: its warning is what gets a runner to a pad in time;
## - three lanes: the runner's and the ones on either side, kept within the street (at an edge the three
##   outermost; at 3 lanes the whole street). The encounter times every slash to a refuge
##   (SleepTaker: a bridge with its pads), so a runner reacting as the warning starts can always reach
##   a pad's lane, or at 5 and 6 lanes a lane outside the slash;
## - the locked lanes count as floor warnings (BossProps.floor_warning) from the warning to the strike,
##   so pickups keep off them.

enum Step { IDLE, TELEGRAPH, LUNGE, STRIKE, RECOVER }

## The lane marks start this far behind the runner and reach this far in front.
const MARKS_BEHIND: float = 1.2
const MARKS_AHEAD: float = 16.0
## How long the claw streaks stay in view after the strike.
const ARC_FADE: float = 0.25
## How much stronger the lane marks are drawn at no light at all (lerped toward 1 as the light comes back):
## the marks blend over the street with low alpha, so lights out would otherwise dim them with it, and
## warnings stay as visible as before (GDD §10, owner, October 8, 2026). The shader caps alpha at 0.95.
const MARKS_DARK_BOOST: float = 1.4

var boss: SleepTaker
var step: Step = Step.IDLE
var step_time: float = 0.0
## The current (or last) slash: {n, first, last (its lanes), at (the runner's distance as its warning
## started), strike_at (where the runner will be when it strikes, at their speed then), refuge (the
## refuge's pads' distance, or -1)}.
var attack: Dictionary = {}
## Slashes started so far.
var count: int = 0
## Strikes so far (the claws live).
var strikes: int = 0

var _root: Node3D
var _hitbox: Hazard
var _marks: MeshInstance3D
var _marks_material: ShaderMaterial
var _arc: MeshInstance3D
var _arc_material: ShaderMaterial
var _arc_time: float = -1.0
var _arc_dir: float = 1.0
var _box := AABB()
var _warned: Array[Node3D] = []


func setup(p_boss: SleepTaker) -> void:
	boss = p_boss
	name = "Slash"
	top_level = true
	_root = Node3D.new()
	_root.name = "SlashBox"
	_root.top_level = true
	add_child(_root)
	_hitbox = boss.body.add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, _root)
	_hitbox.hazard_name = "Sleep Taker's slash"
	_hitbox.set_enabled(false)
	_marks_material = BadDreamModel.mark_material()
	_marks = MeshInstance3D.new()
	_marks.name = "LaneMarks"
	_marks.material_override = _marks_material
	_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marks.top_level = true
	_marks.visible = false
	add_child(_marks)
	_arc_material = BadDreamModel.arc_material()
	_arc = MeshInstance3D.new()
	_arc.name = "ClawStreaks"
	_arc.mesh = BadDreamModel.arc_mesh()
	_arc.material_override = _arc_material
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc.top_level = true
	_arc.visible = false
	add_child(_arc)


## The lanes a slash at a runner in `lane` covers: Vector2i(first, last), slash_lanes wide, centred on
## `lane` and kept within the street.
func band_for(lane: int) -> Vector2i:
	var n: int = boss.lane_count()
	var k: int = clampi(boss.tuning.slash_lanes, 1, n)
	var first: int = clampi(lane - (k - 1) / 2, 0, n - k)
	return Vector2i(first, first + k - 1)


## The slash's damage box over lanes `band` (world x and y; z around the runner's spot): the lanes less
## side_margin at an edge next to a free lane and less wall_clearance at the street's edge, from the
## floor to slash_height, slash_depth deep.
func box_for(band: Vector2i) -> AABB:
	var t: SleepTakerTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var n: int = geo.lane_count
	var half: float = geo.lane_width * 0.5
	var x0: float = (-geo.wall_x() + t.wall_clearance) if band.x == 0 else geo.lane_x(band.x) - half + t.side_margin
	var x1: float = (geo.wall_x() - t.wall_clearance) if band.y == n - 1 else geo.lane_x(band.y) + half - t.side_margin
	return AABB(Vector3(x0, 0.0, -t.slash_depth * 0.5), Vector3(x1 - x0, t.slash_height, t.slash_depth))


## Starts a slash at the runner's lane now: the warning (see the header). `refuge` is the pads'
## distance of the refuge it's timed for (-1: none).
func start(refuge: float = -1.0) -> void:
	var t: SleepTakerTuning = boss.tuning
	var p: Player = boss.world.player
	var band: Vector2i = band_for(boss.player_lane())
	count += 1
	var v: float = maxf(p.speed, 1.0)
	attack = {"n": count, "first": band.x, "last": band.y, "at": p.distance,
		"strike_at": p.distance + v * t.slash_warning(), "refuge": refuge}
	_box = box_for(band)
	_hitbox.size = _box.size
	((_hitbox.get_child(0) as CollisionShape3D).shape as BoxShape3D).size = _box.size
	_arc_dir = 1.0 if boss.rng.randf() < 0.5 else -1.0
	_show_marks(band)
	for lane: int in range(band.x, band.y + 1):
		var marker := Node3D.new()
		marker.name = "SlashWarning"
		_warned.append(boss.props.floor_warning(marker, lane, p.distance - 2.0,
			float(attack["strike_at"]) + v * t.slash_active + t.slash_depth))
	_set_step(Step.TELEGRAPH)
	boss.sound(&"sleep_taker_shriek", boss.body.mouth_world())
	boss.log_event(&"slash_warning", {"n": count, "first": band.x, "last": band.y, "at": p.distance,
		"strike_at": attack["strike_at"], "refuge": refuge})


## True from the warning until it has pulled back.
func busy() -> bool:
	return step != Step.IDLE


## True while it warns or strikes (TELEGRAPH, LUNGE, STRIKE).
func warning_on() -> bool:
	return step == Step.TELEGRAPH or step == Step.LUNGE or step == Step.STRIKE


## True while the claws are live.
func striking() -> bool:
	return step == Step.STRIKE


## How far it has lunged toward the runner (0 hovering, 1 its claws in front of them): the encounter
## moves the body.
func pull() -> float:
	var t: SleepTakerTuning = boss.tuning
	match step:
		Step.LUNGE:
			var k: float = clampf(step_time / maxf(t.slash_lunge, 0.01), 0.0, 1.0)
			return k * k
		Step.STRIKE:
			return 1.0
		Step.RECOVER:
			return 1.0 - smoothstep(0.0, 1.0, clampf(step_time / maxf(t.slash_recover, 0.01), 0.0, 1.0))
	return 0.0


func hitbox() -> Hazard:
	return _hitbox


## True while its lanes are lit on the floor (the warning's look).
func marks_shown() -> bool:
	return _marks.visible


## The lanes it's slashing now (or slashed last), first to last.
func lanes() -> Array[int]:
	var out: Array[int] = []
	if not attack.is_empty():
		for lane: int in range(int(attack["first"]), int(attack["last"]) + 1):
			out.append(lane)
	return out


## Stops it at once (a phase change, the defeat): no warning left, nothing live.
func clear() -> void:
	_hitbox.set_enabled(false)
	_marks.visible = false
	_clear_warned()
	_set_step(Step.IDLE)
	_set_body(0.0, 0.0, 0.0, 0.0)


func tick(delta: float) -> void:
	_update_arc(delta)
	if step == Step.IDLE:
		return
	var t: SleepTakerTuning = boss.tuning
	step_time += delta
	var k: float = 0.0
	match step:
		Step.TELEGRAPH:
			k = clampf(step_time / maxf(t.slash_telegraph, 0.01), 0.0, 1.0)
			_set_body(smoothstep(0.0, 0.35, k), smoothstep(0.0, 0.6, k), 0.0, smoothstep(0.05, 0.85, k))
			if step_time >= t.slash_telegraph:
				_set_step(Step.LUNGE)
				boss.sound(&"sleep_taker_slash", boss.body.mouth_world())
		Step.LUNGE:
			k = clampf(step_time / maxf(t.slash_lunge, 0.01), 0.0, 1.0)
			_set_body(1.0, 1.0 - k * 0.5, k * 0.4, 1.0)
			if step_time >= t.slash_lunge:
				_strike()
		Step.STRIKE:
			_set_body(1.0, 0.0, 1.0, 1.0)
			_place_box()
			if step_time >= t.slash_active:
				_hitbox.set_enabled(false)
				_set_step(Step.RECOVER)
				_clear_warned()
		Step.RECOVER:
			k = clampf(step_time / maxf(t.slash_recover, 0.01), 0.0, 1.0)
			_set_body(1.0 - k, 0.0, 1.0 - k, 1.0 - k)
			if k >= 1.0:
				_set_step(Step.IDLE)
				boss.log_event(&"slash_over", {"n": count})
	_update_marks()


func _strike() -> void:
	_set_step(Step.STRIKE)
	strikes += 1
	_place_box()
	_hitbox.set_enabled(true)
	_arc_time = 0.0
	boss.log_event(&"slash", {"n": count, "first": attack["first"], "last": attack["last"],
		"d": boss.player_distance()})


## The damage box sits on the runner's spot along the track while it's live.
func _place_box() -> void:
	_root.global_transform = Transform3D(Basis.IDENTITY,
		Vector3(_box.get_center().x, _box.get_center().y, TrackGeometry.world_z(boss.player_distance())))


## The body's part in it: its great maw (shriek), its arms (raise, slash) and the heat (attack); the
## lunge comes from pull().
func _set_body(shriek: float, raise: float, slash: float, heat: float) -> void:
	var body: SleepTakerBody = boss.body
	if body == null or not is_instance_valid(body):
		return
	body.shriek = shriek
	body.raise = raise
	body.slash = slash
	body.attack = heat
	body.lunge = pull()
	body.reach = 1.0 + 0.35 * raise + 0.25 * slash


func _show_marks(band: Vector2i) -> void:
	var geo: TrackGeometry = boss.world.geo
	var strips: Array[Vector2] = []
	for lane: int in range(band.x, band.y + 1):
		strips.append(Vector2(geo.lane_x(lane) - geo.lane_width * 0.5 + 0.12, geo.lane_x(lane) + geo.lane_width * 0.5 - 0.12))
	_marks.mesh = BadDreamModel.marks_mesh(strips, 0.0, 0.0, MARKS_BEHIND, MARKS_AHEAD)
	_marks.visible = true


## The lane marks travel with the runner: they fill toward them as the strike nears, dim as the claws
## sweep, and go once it's over.
func _update_marks() -> void:
	var shown: bool = step == Step.TELEGRAPH or step == Step.LUNGE or step == Step.STRIKE \
		or (step == Step.RECOVER and step_time < 0.25)
	_marks.visible = shown
	if not shown:
		return
	var t: SleepTakerTuning = boss.tuning
	var progress: float = 1.0
	var fade: float = 1.0
	if step == Step.TELEGRAPH:
		progress = clampf(step_time / maxf(t.slash_telegraph + t.slash_lunge, 0.01), 0.0, 1.0)
		fade = clampf(step_time / 0.12, 0.0, 1.0)
	elif step == Step.LUNGE:
		progress = clampf((t.slash_telegraph + step_time) / maxf(t.slash_telegraph + t.slash_lunge, 0.01), 0.0, 1.0)
	elif step == Step.STRIKE:
		fade = 0.45
	elif step == Step.RECOVER:
		fade = 0.45 * (1.0 - step_time / 0.25)
	_marks_material.set_shader_parameter(&"progress", progress)
	fade *= lerpf(MARKS_DARK_BOOST, 1.0, clampf(boss.light_level(), 0.0, 1.0))
	_marks_material.set_shader_parameter(&"fade", fade)
	_marks.global_position = Vector3(0.0, 0.035, boss.world.player.position.z)


func _update_arc(delta: float) -> void:
	if _arc_time < 0.0:
		_arc.visible = false
		return
	_arc_time += delta
	var t: SleepTakerTuning = boss.tuning
	var live: float = t.slash_active
	if _arc_time >= live + ARC_FADE:
		_arc_time = -1.0
		_arc.visible = false
		return
	_arc.visible = true
	_arc_material.set_shader_parameter(&"sweep", clampf(_arc_time / maxf(live, 0.01), 0.0, 1.0))
	_arc_material.set_shader_parameter(&"fade", 1.0 - clampf((_arc_time - live) / ARC_FADE, 0.0, 1.0))
	_arc_material.set_shader_parameter(&"dir", _arc_dir)
	# The Bad Dream's streaks, scaled to the lanes and the height it slashes.
	_arc.global_transform = Transform3D(Basis.from_scale(Vector3(maxf(_box.size.x, 0.5), t.slash_height / 1.75, 1.6)),
		Vector3(_box.get_center().x, 0.0, boss.world.player.position.z - 0.3))


func _clear_warned() -> void:
	for node: Node3D in _warned:
		boss.props.remove(node)
	_warned.clear()


func _set_step(next: Step) -> void:
	step = next
	step_time = 0.0
