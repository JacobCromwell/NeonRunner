class_name GoldenConvergenceLash
extends GoldenConvergenceAttack
## The Magnate's Cable Lash (GDD §10, proposed: "from the second phase of stage 2: running along a balustrade
## beside the track, he rears back one of his broadcast cables (with a rising crackle) and whips it across every
## lane ahead: low, jump it; high, slide under it. A red line across the floor shows where it will sweep, as with
## the Floating Head's lasers"): the beat kind `lash`, its argument `low` or `high`
## (GoldenConvergenceTuning.phase_beats). Planned from the runner's distance as it starts, at the run speed:
## - the run-up (lash_run_up, over the phase's pace): from his place behind the runner onto a balustrade (sides
##   in turn, the first by the fight's seed) and past the runner along it, so that he's pacing them well ahead as
##   the warning begins;
## - the warning (lash_warning, never over the pace): he rears back, slowing to a stop on the balustrade where
##   the cable will cross (`line_at`); his cable rises crackling red behind him (magnate_crackle, as long as the
##   warning; its sparks still with Reduced flashing); a red line lies across every lane there
##   (GoldenConvergence.cross_warning: floor warnings) and thin red aim lines across the track show its heights;
## - the whip (lash_sweep): the cable lashes across every lane from his side to the far balustrade
##   (magnate_whip), each lane's stretch live once it's crossed; it lies across them all lash_cross_lead before the
##   runner gets there and stays until lash_after after they're past: enemy attack boxes at its heights
##   (GoldenConvergenceMagnate.set_lash_band), the enemy attacks' red, never the fences' pink. Low: one cable at
##   lash_low (jump it). High: one at lash_high and one at lash_high_top, a gapped fence's shape (slide under
##   both; DESIGN-TBD: a second cable for the high one, as the Floating Head's twin beams). Armor and the shield
##   block it, the dash passes through it;
## - he yanks it back (lash_yank) and drops back behind the runner (the chase), and the beat is over once he's
##   home.

enum Stage { IDLE, RUN_UP, WARN, WHIP, HOLD, YANK, RETURN }

## The floor line's depth along the track (its red bars), the aim lines' thickness, the drawn cable's.
const LINE_DEPTH: float = 0.7
const AIM_THICK: float = 0.045
const CABLE_THICK: float = 0.13
## The hold lasts at most this long after the sweep (a runner who's down).
const HOLD_TIMEOUT: float = 3.0
## The enemy attacks' red (the strafe's fire's: GoldenConvergenceFire.RAKE_COLOR).
const COLOR := Color(1.0, 0.16, 0.08)

var chase: GoldenConvergenceChase
var magnate: GoldenConvergenceMagnate
var stage: Stage = Stage.IDLE
var stage_time: float = 0.0
## Lashes so far (tests), by kind.
var lashes: int = 0
var lows: int = 0
var highs: int = 0
## The lash under way: {kind (&"low"/&"high"), heights, side, d0, v, line_at, t_warn, t_whip, t_swept, warned_at,
## whipped_at, rel_start, from_x, z_warn, tip (the sweep's progress 0-1), passed_at}.
var p: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _first_side: int = 0
var _root: Node3D
var _cables: Array[MeshInstance3D] = []
var _leads: Array[MeshInstance3D] = []
var _aims: Array[MeshInstance3D] = []
var _warnings: Array = []
var _spark_t: float = 0.0
var _glow: StandardMaterial3D
var _aim_glow: StandardMaterial3D


func _init(p_boss: GoldenConvergence) -> void:
	super(p_boss, &"lash")
	chase = boss.chase
	magnate = boss.magnate
	_rng.seed = hash([String(boss.def.id), "lash", boss.rng.seed])
	_first_side = -1 if _rng.randf() < 0.5 else 1


## Its drawn cables and aim lines, made now (pooled): two of each.
func prewarm() -> void:
	if _root != null:
		return
	_root = Node3D.new()
	_root.name = "CableLash"
	_root.top_level = true
	boss.add_child(_root)
	_glow = GreyboxMaterials.glow(COLOR, 3.4, 1.0)
	_aim_glow = GreyboxMaterials.glow(COLOR, 2.2, 0.55)
	for i: int in 2:
		_cables.append(_box(_glow))
		_leads.append(_box(_glow))
		_aims.append(_box(_aim_glow))


func _box(material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = GreyboxMaterials.unit_box()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visible = false
	_root.add_child(mesh)
	return mesh


func busy() -> bool:
	if stage == Stage.RETURN and chase.home():
		_set_stage(Stage.IDLE)
	return stage != Stage.IDLE


## Its warning shows or a cable is live.
func warning_on() -> bool:
	return stage in [Stage.WARN, Stage.WHIP, Stage.HOLD]


## The heights its cables cross the runner's path at, for `kind`.
func heights_for(kind: StringName) -> Array[float]:
	var t: GoldenConvergenceTuning = boss.tuning
	var out: Array[float] = [t.lash_low]
	if kind == &"high":
		out = [t.lash_high, t.lash_high_top]
	return out


func start(beat: Dictionary) -> void:
	clear()
	prewarm()
	lashes += 1
	var kind: StringName = &"high" if String(beat.get("arg", "")) == "high" else &"low"
	if kind == &"high":
		highs += 1
	else:
		lows += 1
	var t: GoldenConvergenceTuning = boss.tuning
	var v: float = boss.speed_planned()
	var d0: float = boss.player_distance()
	var run_up: float = t.lash_run_up / boss.pace()
	var t_warn: float = run_up
	var t_whip: float = t_warn + t.lash_warning
	var t_swept: float = t_whip + t.lash_sweep
	var line_at: float = d0 + v * (t_swept + t.lash_cross_lead)
	var side: int = _first_side if lashes % 2 == 1 else -_first_side
	var from: Vector3 = magnate.global_position
	p = {"kind": kind, "heights": heights_for(kind), "side": side, "d0": d0, "v": v, "line_at": line_at,
		"t": 0.0, "t_warn": t_warn, "t_whip": t_whip, "t_swept": t_swept, "rel_start": -from.z - d0, "from_x": from.x,
		"from_y": from.y, "n": lashes}
	# Where he is as the warning begins: pacing the runner, so that slowing to a stop over the warning he plants
	# himself at the line (his speed matching the runner's as it starts).
	p["z_warn"] = line_at - v * t.lash_warning * 0.5
	_set_stage(Stage.RUN_UP)
	chase.drive(self)
	boss.log_event(&"lash_start", {"n": lashes, "kind": kind, "side": side, "line": line_at, "runner": d0})


func planned(t: float) -> float:
	return float(p["d0"]) + float(p["v"]) * t


func tick(delta: float) -> void:
	if stage == Stage.IDLE or p.is_empty():
		return
	stage_time += delta
	p["t"] = float(p["t"]) + delta
	var t: float = float(p["t"])
	match stage:
		Stage.RUN_UP:
			_tick_run_up(delta, t)
			if t >= float(p["t_warn"]):
				_warn()
		Stage.WARN:
			_tick_warn(delta, t)
			if t >= float(p["t_whip"]):
				_whip()
		Stage.WHIP:
			_tick_whip(delta, t)
		Stage.HOLD:
			_tick_hold(delta)
		Stage.YANK:
			_tick_yank(delta)


# --- The run-up and the warning ----------------------------------------------------------------------------

func _tick_run_up(delta: float, t: float) -> void:
	var u: float = clampf(t / maxf(float(p["t_warn"]), 0.05), 0.0, 1.0)
	var side: int = int(p["side"])
	var k: float = clampf(u / 0.25, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var x: float = lerpf(float(p["from_x"]), chase.balustrade_x(side), k)
	var y: float = lerpf(float(p["from_y"]), chase.balustrade_y(), k)
	var e: float = u * u * (3.0 - 2.0 * u)
	var rel_warn: float = float(p["z_warn"]) - planned(float(p["t_warn"]))
	var rel: float = lerpf(float(p["rel_start"]), rel_warn, e)
	magnate.play(&"run")
	chase.place(Vector3(x, y, TrackGeometry.world_z(planned(t) + rel)), 0.0, delta)


## The warning: he rears back; the red line across every lane, the aim lines at its heights, the crackle.
func _warn() -> void:
	_set_stage(Stage.WARN)
	p["warned_at"] = boss.fight_time()
	var line_at: float = float(p["line_at"])
	var half: float = LINE_DEPTH * 0.5
	_warnings.clear()
	for lane: int in boss.lane_count():
		_warnings.append(boss.cross_warning(lane, line_at - half, line_at + half))
	magnate.play(&"rear")
	boss.sound(&"magnate_crackle", boss.sound_point(magnate.global_position))
	boss.hint("lash")
	boss.log_event(&"lash_warned", {"n": int(p["n"]), "kind": p["kind"], "line": line_at, "heights": p["heights"],
		"runner": boss.player_distance(), "lane": boss.player_lane()})


func _tick_warn(delta: float, t: float) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	var u: float = clampf((t - float(p["t_warn"])) / maxf(tu.lash_warning, 0.05), 0.0, 1.0)
	var z0: float = float(p["z_warn"])
	var z: float = z0 + (float(p["line_at"]) - z0) * (1.0 - (1.0 - u) * (1.0 - u))
	var side: int = int(p["side"])
	magnate.play(&"rear")
	chase.place(Vector3(chase.balustrade_x(side), chase.balustrade_y(), TrackGeometry.world_z(z)), 0.0, delta)
	# His cables rise behind him, crackling; the aim lines brighten across the track.
	var heights: Array = p["heights"]
	var back: Vector3 = magnate.back_point()
	for i: int in heights.size():
		var tip: Vector3 = back + Vector3(-side * (0.4 + 0.3 * i), 1.6 + 0.7 * i + 0.4 * u, 0.9 - 0.3 * i)
		_line(_leads[i], back, tip, CABLE_THICK * (0.6 + 0.4 * u))
		_line(_aims[i], Vector3(-_reach(), float(heights[i]), TrackGeometry.world_z(float(p["line_at"]))),
			Vector3(_reach(), float(heights[i]), TrackGeometry.world_z(float(p["line_at"]))), AIM_THICK * (0.5 + 0.5 * u))
		_crackle(delta, tip, back)


## How far either side of the middle the cable reaches: past the balustrades.
func _reach() -> float:
	return boss.world.geo.wall_x() + 0.9


## Red sparks along a cable now and then (fewer, and none flickering faster, with Reduced flashing).
func _crackle(delta: float, a: Vector3, b: Vector3) -> void:
	_spark_t -= delta
	if _spark_t > 0.0:
		return
	_spark_t = 0.16 if Settings.flashing_reduced else 0.07
	var at: Vector3 = a.lerp(b, _rng.randf())
	boss.world.effects.burst(at, COLOR, 4, 0.18)


# --- The whip and the hold ----------------------------------------------------------------------------------

func _whip() -> void:
	_set_stage(Stage.WHIP)
	p["whipped_at"] = boss.fight_time()
	for aim: MeshInstance3D in _aims:
		aim.visible = false
	magnate.play(&"whip")
	boss.sound(&"magnate_whip", boss.sound_point(magnate.global_position))
	boss.log_event(&"lash_whip", {"n": int(p["n"]), "runner": boss.player_distance()})


## The cable sweeping across: each band from his side to the tip, live over what it has crossed.
func _tick_whip(delta: float, t: float) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	var u: float = clampf((t - float(p["t_whip"])) / maxf(tu.lash_sweep, 0.05), 0.0, 1.0)
	var e: float = 1.0 - (1.0 - u) * (1.0 - u)
	p["tip"] = e
	_draw_cables(e, true)
	chase.place(magnate.global_position, 0.0, delta)
	if u >= 1.0:
		_set_stage(Stage.HOLD)
		boss.log_event(&"lash_across", {"n": int(p["n"]), "runner": boss.player_distance()})


func _tick_hold(delta: float) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	_draw_cables(1.0, true)
	chase.place(magnate.global_position, 0.0, delta)
	var line_at: float = float(p["line_at"])
	if not p.has("passed_at") and boss.player_distance() > line_at + LINE_DEPTH * 0.5 + 0.6:
		p["passed_at"] = stage_time
	var over: bool = p.has("passed_at") and stage_time >= float(p["passed_at"]) + tu.lash_after
	if over or stage_time >= HOLD_TIMEOUT:
		_yank()


## The cables at the line: from his back down to the track's edge, then across every lane to `tip` (0-1 of the
## way to the far balustrade); their boxes live across what they've crossed (`live`).
func _draw_cables(tip: float, live: bool) -> void:
	var heights: Array = p["heights"]
	var side: int = int(p["side"])
	var z: float = TrackGeometry.world_z(float(p["line_at"]))
	var r: float = boss.tuning.lash_radius
	var near_x: float = side * _reach()
	var far_x: float = -side * _reach()
	var back: Vector3 = magnate.back_point()
	for i: int in 2:
		if i >= heights.size():
			_cables[i].visible = false
			_leads[i].visible = false
			magnate.set_lash_band(i, false)
			continue
		var h: float = float(heights[i])
		var tip_x: float = lerpf(near_x, far_x, tip)
		var thick: float = CABLE_THICK * (1.0 if Settings.flashing_reduced else 0.85 + 0.3 * absf(sin(float(p["t"]) * 37.0 + i)))
		_line(_leads[i], back, Vector3(near_x, h, z), CABLE_THICK)
		_line(_cables[i], Vector3(near_x, h, z), Vector3(tip_x, h, z), thick)
		var x0: float = minf(near_x, tip_x)
		var x1: float = maxf(near_x, tip_x)
		if live and x1 - x0 > 0.05:
			magnate.set_lash_band(i, true, Vector3((x0 + x1) * 0.5, h, z), Vector3(x1 - x0, r * 2.0, r * 2.0))
		else:
			magnate.set_lash_band(i, false)


func _yank() -> void:
	_set_stage(Stage.YANK)
	for i: int in 2:
		magnate.set_lash_band(i, false)
	for w: Variant in _warnings:
		boss.props.remove(w as Node)
	_warnings.clear()
	boss.log_event(&"lash_done", {"n": int(p["n"]), "runner": boss.player_distance()})


## He yanks the cables back to him, then drops back behind the runner.
func _tick_yank(delta: float) -> void:
	var tu: GoldenConvergenceTuning = boss.tuning
	var u: float = clampf(stage_time / maxf(tu.lash_yank, 0.05), 0.0, 1.0)
	_draw_cables(1.0 - u, false)
	magnate.play(&"run")
	chase.place(magnate.global_position, 0.0, delta)
	if u >= 1.0:
		_hide_cables()
		_set_stage(Stage.RETURN)
		chase.drop_back(self, int(p["side"]))


func _hide_cables() -> void:
	for group: Array[MeshInstance3D] in [_cables, _leads, _aims]:
		for m: MeshInstance3D in group:
			m.visible = false


## `mesh` (a unit box) stretched from `a` to `b`, `thick` across (world space).
static func _line(mesh: MeshInstance3D, a: Vector3, b: Vector3, thick: float) -> void:
	var along: Vector3 = b - a
	var length: float = along.length()
	if length < 0.02:
		mesh.visible = false
		return
	var dir: Vector3 = along / length
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	mesh.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(thick, thick, length)), (a + b) * 0.5)
	mesh.visible = true


## The cables live now (tests): {heights, line_at, live: Array[bool]} or {}.
func live_cables() -> Dictionary:
	if p.is_empty() or not (stage == Stage.WHIP or stage == Stage.HOLD):
		return {}
	var live: Array[bool] = []
	for box: Hazard in magnate.lash_boxes():
		live.append(box.is_active())
	return {"heights": p["heights"], "line_at": p["line_at"], "live": live}


func _set_stage(next: Stage) -> void:
	stage = next
	stage_time = 0.0


## Everything at once (a phase's end, the defeat): the cables and their warnings gone; whoever comes next moves
## him.
func clear() -> void:
	super()
	if magnate != null:
		for i: int in 2:
			magnate.set_lash_band(i, false)
	for w: Variant in _warnings:
		if boss != null and boss.props != null:
			boss.props.remove(w as Node)
	_warnings.clear()
	if _root != null:
		_hide_cables()
	_set_stage(Stage.IDLE)
	p = {}
