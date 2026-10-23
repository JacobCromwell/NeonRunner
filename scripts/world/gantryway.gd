class_name Gantryway
extends Node3D
## A falling gantryway (task Q3; GDD §5, Zone 9, the owner, October 21, 2026: "an upper walkway over one lane only,
## looking like a ceiling section ... Dashing through a pillar knocks down its long section of gantryway. It takes about
## a second to fall. When it lands, it destroys any enemy in its path. A runner under it when it lands is hit"): its
## walkway, hanging over its lane at the ceilings' height, and its fall. TrackBuilder builds it from its layout entry
## (LevelLayout.gantryways) with its pillar, a DashBreakable of kind &"gantry_pillar" that pushes like a zone doodad and
## that the dash smashes like one, and the skin dresses both (ZoneSkin.gantryway, gantry_pillar, gantryway_wreck). Its
## numbers are GantrywayTuning's (data/tuning/gantryways.tres).
##
## It stands overhead, scenery nothing touches (no collision: nobody walks on it or rides it), until its pillar breaks
## (DashBreakable.smashed). Then it falls over fall_seconds, warning for all of it, as every attack must (CLAUDE.md:
## seen and heard first):
## - the groan and creak of its steel as the pillar goes (`gantry_creak`, at the pillar);
## - it lurches down by `sag` and shudders for hold_seconds() (with Reduced flashing it only lurches, then holds
##   still), shaking snow and ice loose;
## - its shadow darkens on its lane, and the lane lights red under its whole length (the floor warnings' red,
##   BossProps.WARNING_COLOR, widening and pulsing as BossProps' lane warnings do, steady with Reduced flashing);
## - then it drops, faster and faster, and lands flat on its lane: the crash (`gantry_land`), its pieces and snow flung
##   out, and the camera shakes (RunWorld). It lies there crushed flat (its wreck), and the runner runs over it.
## DESIGN-TBD (docs/questions/q3.md 4 and 7): the warning's parts, the red line among them; the wreck, flat and harmless.
## Its hitbox (a Hazard, solid, which the armor and the shield absorb: armor_blocks_solid; a hit of it pays for the whole
## of it: passes_after_block) is live only while it drops and as it lands: each tick it spans what the walkway's box went
## through since the last, less hitbox_inset across, at its ends and at its underside (forgiving, CLAUDE.md principle 4:
## a runner under it is hit as it reaches them, on contact only), and LANDING_TICKS ticks after it lands it's off
## (DESIGN-TBD, docs/questions/q3.md 5 and 8: hit as it reaches the runner, not only as it lands; one blocked hit pays
## for the whole of it). Each
## of those ticks every enemy in its path (crushes(): its footprint from its underside up to where it was, a heli drone
## low over the lane too) is destroyed (RunWorld: Enemy.defeat with CRUSH_CAUSE, a kill the runner's score counts, as a
## gap an Octodog was baited into is). DESIGN-TBD (docs/questions/q3.md): the dash passes through its hitbox as through
## every hazard's; crushing scores as any kill.
## It falls on its own physics clock (not the run's level clock, which stops when the runner dies: a walkway that hit
## them still lands), once an attempt: its layout entry is marked "fallen" as it starts, then "landed".

## Its pillar broke and it begins to fall (the warning).
signal fell(gantryway: Gantryway)
## It came down another tick (crushes() answers for that tick's path): RunWorld destroys the enemies in its path.
signal swept(gantryway: Gantryway)
## It landed.
signal landed(gantryway: Gantryway)

enum State { STANDING, SHUDDERING, DROPPING, LANDED }

## The red of every floor warning (BossProps.WARNING_COLOR), as its lane's line is drawn (BossProps.lane_warning).
const WARNING_COLOR := Color(1.0, 0.12, 0.08)
## What an enemy it crushes is defeated by (Enemy.defeat; ScoreKeeper counts it as the runner's kill).
const CRUSH_CAUSE: StringName = &"gantryway"
## How far beyond its footprint an enemy's middle may be and still be in its path (metres): an enemy's body.
const ENEMY_REACH: float = 0.4
## Its pillar's box: a small zone doodad's (LevelLayout.DOODAD_SIZES; MovementTuning.doodad_size), whose push it is
## (GantrywayRules places it so). DESIGN-TBD (docs/questions/q3.md 3): one pillar, under the walkway's near end, a small
## doodad's box whose top can be stood on; the column above it is only its look.
const PILLAR_SIZE: StringName = &"small"
## Its walkway's look is this share of its lane wide, as is its footprint.
const WIDTH_SHARE: float = 0.92
## Its wreck's box (the walkway crushed flat on the floor) is this tall: low enough that the runner's feet, which pass
## through it, show nothing. DESIGN-TBD (docs/questions/q3.md 7): it lies flat and harmless for the rest of the attempt.
const WRECK_HEIGHT: float = 0.14
## Ticks its hitbox stays live counting the one it lands on (a runner under it as it lands is hit, however the physics
## server orders the contact). DESIGN-TBD (docs/questions/q3.md 5).
const LANDING_TICKS: int = 2
## The red line on its lane: this share of a lane wide (BossProps.lane_warning's), its glow and see-through alpha.
## DESIGN-TBD (docs/questions/q3.md 4): whether the red line belongs in its warning at all.
const LINE_WIDTH_SHARE: float = 0.34
## Its shadow: this much wider and longer than its walkway at each side and end, with edges this soft (metres), and
## its darkness on the Compatibility renderer, a share of the tuning's (it blends in sRGB: GoldenConvergenceFist's
## shadow's own ratio, 0.36 / 0.62).
const SHADOW_MARGIN: float = 0.3
const SHADOW_SOFT: float = 0.5
const SHADOW_COMPAT_SHARE: float = 0.58
## The lurch as its pillar goes takes this long (seconds).
const LURCH_SECONDS: float = 0.12
## Snow shakes loose from this many metres of its walkway, from SNOW_AHEAD past its pillar (ahead of the runner who
## dashed it, where they look).
const SNOW_REACH: float = 32.0
const SNOW_AHEAD: float = 8.0
## Its pieces fly from this many metres of the landed walkway nearest the camera.
const LAND_REACH: float = 40.0
## Most pieces in its snow and in its debris (its pillar's column breaking, then its landing).
const SNOW_PIECES: int = 32
const DEBRIS_PIECES: int = 40
## Its sounds (SfxLibrary names).
const CREAK_SOUND: StringName = &"gantry_creak"
const LAND_SOUND: StringName = &"gantry_land"
## The look's shader for its shadow (in MeshKit's shader folder).
const SHADOW_SHADER: String = "gantryway_shadow.gdshader"

## Its layout entry (LevelLayout.gantryways), marked "fallen" and "landed".
var entry: Dictionary = {}
var tuning: GantrywayTuning
## Its pillar (TrackBuilder), or null where it has none (a test's).
var pillar: DashBreakable
var state: State = State.STANDING
var lane: int = 0
## Its walkway's box (width across its lane, its deck's depth, its length along the track), and the height its
## underside hangs at (the ceilings', MovementTuning.ceiling_height) and is at now.
var size: Vector3 = Vector3.ONE
var hang_y: float = 6.0
var underside_y: float = 6.0
## Seconds since its pillar broke.
var t: float = 0.0
var hitbox: Hazard
## The sounds it asked for, in order (tests and tools: a run without a sound library plays none of them).
var sounds_played: Array[StringName] = []
## The colours its landing's pieces fly in (its look's: ZoneSkin.gantryway_debris_colors), and the snow that shakes
## loose from it (ZoneSkin.gantryway_snow_colors); set once the skin has dressed it.
var debris_colors: PackedColorArray = PackedColorArray()
var snow_colors: PackedColorArray = PackedColorArray()

var _start: float = 0.0
var _end: float = 0.0
var _x: float = 0.0
var _look: Node3D
var _wreck: Node3D
var _shadow: MeshInstance3D
var _shadow_mat: ShaderMaterial
var _shadow_alpha: float = 0.6
var _line: MeshInstance3D
var _line_base := Transform3D.IDENTITY
var _hit_shape: BoxShape3D
var _hit_debug: MeshInstance3D
var _snow: RubbleBurst
var _debris: RubbleBurst
var _creak_voice: AudioStreamPlayer3D
var _land_voice: AudioStreamPlayer3D
## This tick's path, full width (world space; empty when it isn't coming down): crushes().
var _sweep := AABB()
var _last_underside: float = 6.0
var _landing_ticks: int = 0


## Sets it up over layout entry `p_entry` on the track `geo` describes, its numbers from `p_tuning`, hanging at
## `mt`'s ceiling height; `show_hitboxes` shows its hitbox in the hitbox view. The node sits on the floor of its lane, at
## the middle of its walkway's stretch.
func setup(p_entry: Dictionary, p_tuning: GantrywayTuning, geo: TrackGeometry, mt: MovementTuning,
		show_hitboxes: bool = false) -> void:
	entry = p_entry
	tuning = p_tuning if p_tuning != null else GantrywayTuning.load_default()
	lane = int(entry["lane"])
	_start = float(entry["start"])
	_end = float(entry["end"])
	_x = geo.lane_x(lane)
	size = Vector3(geo.lane_width * WIDTH_SHARE, tuning.deck_thickness, _end - _start)
	hang_y = mt.ceiling_height
	underside_y = hang_y
	_last_underside = hang_y
	name = "Gantryway"
	position = Vector3(_x, 0.0, -(_start + _end) * 0.5)
	_shadow_alpha = shadow_alpha_for(RenderingServer.get_current_rendering_method())
	_build(geo, show_hitboxes)
	# One that fell already on this attempt (its entry says so) lies where it landed.
	if bool(entry.get("landed", false)) or bool(entry.get("fallen", false)):
		_show_landed()


func _ready() -> void:
	set_physics_process(is_falling())


func _physics_process(delta: float) -> void:
	advance(delta)


## Where its pillar's front is (track distance): the walkway's near end is GantrywayRules.NEAR_OVERHANG before it.
func pillar_front() -> float:
	return float(entry.get("pillar", _start))


## Track distances of its walkway's near and far ends.
func span() -> Vector2:
	return Vector2(_start, _end)


## World x of its lane's middle.
func lane_x() -> float:
	return _x


## The node its walkway's look hangs from (the skin dresses it: ZoneSkin.gantryway): centred on the walkway's box.
func look_node() -> Node3D:
	return _look


## The node its wreck's look lies on (ZoneSkin.gantryway_wreck): centred on the wreck's box, on the floor.
func wreck_node() -> Node3D:
	return _wreck


## Its wreck's box (width, height, length).
func wreck_size() -> Vector3:
	return Vector3(size.x, WRECK_HEIGHT, size.z)


## True while it falls (from its pillar breaking until it lands).
func is_falling() -> bool:
	return state == State.SHUDDERING or state == State.DROPPING


func has_landed() -> bool:
	return state == State.LANDED


## The warning parts (tests and tools): its shadow, its lane's red line.
func shadow() -> MeshInstance3D:
	return _shadow


func warning_line() -> MeshInstance3D:
	return _line


## Its shadow's darkness now (the shader's `darkness`).
func shadow_darkness() -> float:
	return float(_shadow_mat.get_shader_parameter(&"darkness"))


## Its snow's and its debris's bursts (tests and tools).
func bursts() -> Array[RubbleBurst]:
	return [_snow, _debris]


## Its shadow's darkest on rendering method `method` (RenderingServer.get_current_rendering_method()): the tuning's, or
## SHADOW_COMPAT_SHARE of it on the Compatibility renderer.
func shadow_alpha_for(method: String) -> float:
	var dark: float = tuning.shadow_darkness if tuning != null else 0.6
	return dark * SHADOW_COMPAT_SHARE if method == "gl_compatibility" else dark


## Its sounds (TrackBuilder, from the run's SfxLibrary): the creak at its pillar, the crash where it lands nearest the
## camera, each at `*_db`, full within `full_volume` metres and silent past `silent`.
func set_sounds(creak: AudioStream, creak_db: float, land: AudioStream, land_db: float, full_volume: float,
		silent: float) -> void:
	_creak_voice = _voice("Creak", creak, creak_db, full_volume, silent)
	_creak_voice.position = Vector3(0.0, hang_y * 0.6, -(pillar_front() - (_start + _end) * 0.5))
	_land_voice = _voice("Land", land, land_db, full_volume, silent)


## Its pillar broke (DashBreakable.smashed): it begins to fall. Nothing if it fell already.
func fall() -> void:
	if state != State.STANDING:
		return
	state = State.SHUDDERING
	t = 0.0
	entry["fallen"] = true
	_last_underside = hang_y
	hitbox.state = Hazard.State.WARNING
	hitbox.state_changed.emit(hitbox.state)
	_shadow.visible = true
	_line.visible = true
	_update_warning()
	_play(CREAK_SOUND, _creak_voice)
	# Snow and ice shaking loose from the walkway ahead of its pillar (where the runner who dashed it looks), and the
	# pillar's column breaking up, its pieces dropping round its foot.
	var from: float = minf(pillar_front() + SNOW_AHEAD, _end - 1.0)
	var reach: float = clampf(SNOW_REACH, 1.0, _end - from)
	var w: float = size.x * 0.9
	_snow.play(AABB(Vector3(_x - w * 0.5, hang_y - 0.6, TrackGeometry.world_z(from + reach)), Vector3(w, 0.6, reach)),
		snow_colors, Vector3.ZERO, 0.0, 0.5, 0.2, 0.14, 1.25, int(entry.get("seed", 0)))
	if pillar != null and is_instance_valid(pillar):
		var box: AABB = pillar.world_box()
		var column := AABB(Vector3(box.position.x, box.end.y, box.position.z), Vector3(box.size.x, maxf(hang_y - box.end.y,
			0.5), box.size.z))
		_debris.play(column, pillar.debris_colors, Vector3.ZERO, 0.0, 1.2, 0.4, 0.24, 0.9, int(entry.get("seed", 0)) + 1)
	set_physics_process(true)
	fell.emit(self)


## Moves its fall on by `dt` seconds (its own _physics_process; tests may call it).
func advance(dt: float) -> void:
	match state:
		State.STANDING:
			return
		State.LANDED:
			_landing_ticks += 1
			if _landing_ticks < LANDING_TICKS:
				# Still on whoever is under it as it lands; its path is over.
				_set_hitbox(0.0, size.y)
				_sweep = AABB()
			else:
				_hitbox_off()
				_sweep = AABB()
				set_physics_process(false)
			return
	t += dt
	var hold: float = tuning.hold_seconds()
	var sag: float = tuning.sag * _ease_out(clampf(t / LURCH_SECONDS, 0.0, 1.0))
	if t < hold:
		# The shudder: shaking where it hangs, lurched down on its broken end. With Reduced flashing it only lurches and
		# holds still (a fast shake is a flicker of motion, as a Barnacle Turret's death shudder is: none then).
		underside_y = hang_y - sag
		if Settings.flashing_reduced:
			_place_look(underside_y, Vector2.ZERO, 0.0)
		else:
			var w: float = TAU * tuning.shudder_hz * t
			var a: float = tuning.shudder_amplitude
			_place_look(underside_y, Vector2(sin(w) * a, sin(w * 1.37 + 1.0) * a * 0.6), sin(w * 0.71) * 0.012)
		_update_warning()
		return
	if state == State.SHUDDERING:
		state = State.DROPPING
		_last_underside = hang_y - tuning.sag
		hitbox.set_enabled(true)
		hitbox.collision_layer = TrackBuilder.LAYER_HAZARD
	# The drop: from rest, faster and faster, to the floor.
	var u: float = clampf((t - hold) / tuning.drop_seconds(), 0.0, 1.0)
	if u >= 1.0:
		_land()
		return
	underside_y = (hang_y - tuning.sag) * (1.0 - u * u)
	_place_look(underside_y, Vector2.ZERO, 0.0)
	_set_sweep(underside_y, _last_underside + size.y)
	_last_underside = underside_y
	_update_warning()
	swept.emit(self)


## True if `enemy` is in its path this tick (swept): its middle within its footprint (across and along, by
## ENEMY_REACH), and its body (from its feet, or its aim point less its hit radius, up to its aim point and its hit
## radius) reaching into what the walkway went through since the last tick. A heli drone low over the lane is.
func crushes(enemy: Enemy) -> bool:
	if _sweep.size == Vector3.ZERO or enemy == null or not is_instance_valid(enemy):
		return false
	var p: Vector3 = enemy.global_position
	if absf(p.x - _x) > size.x * 0.5 + ENEMY_REACH:
		return false
	if p.z < _sweep.position.z - ENEMY_REACH or p.z > _sweep.end.z + ENEMY_REACH:
		return false
	var aim: Vector3 = enemy.aim_point()
	var r: float = enemy.hit_radius()
	var bottom: float = minf(p.y, aim.y - r)
	var top: float = maxf(p.y, aim.y + r)
	return top >= _sweep.position.y and bottom <= _sweep.end.y


## This tick's path (world space, full width), or an empty AABB when it isn't coming down (tests and tools).
func path() -> AABB:
	return _sweep


## Its landing point nearest `at` (world space): on its lane, on the floor, within its stretch.
func nearest_point(at: Vector3) -> Vector3:
	var z: float = clampf(at.z, TrackGeometry.world_z(_end), TrackGeometry.world_z(_start))
	return Vector3(_x, 0.3, z)


## A look of every part of a gantryway, for the shader warm-up (ShaderWarmup): its walkway, pillar and wreck as `skin`
## dresses them, its shadow and its red line, all shown, under a new node of `parent`. No collision, nothing physical:
## nothing in it is a hazard or an area.
static func warm_look(parent: Node3D, skin: ZoneSkin, geo: TrackGeometry, mt: MovementTuning) -> Node3D:
	var root := Node3D.new()
	root.name = "GantrywaySample"
	parent.add_child(root)
	var size := Vector3(geo.lane_width * WIDTH_SHARE, GantrywayTuning.load_default().deck_thickness, 12.0)
	var look := Node3D.new()
	root.add_child(look)
	skin.gantryway(look, size, 0)
	var wreck := Node3D.new()
	root.add_child(wreck)
	skin.gantryway_wreck(wreck, Vector3(size.x, WRECK_HEIGHT, size.z), 0)
	var box: Vector3 = mt.doodad_size(PILLAR_SIZE)
	var body := Node3D.new()
	root.add_child(body)
	skin.gantry_pillar(body, Vector3(box.x, mt.ceiling_height, box.z), -box.y * 0.5, 1, 0)
	var shadow: MeshInstance3D = _shadow_mesh(Vector2(size.x, size.z))
	(shadow.material_override as ShaderMaterial).set_shader_parameter(&"darkness", 0.5)
	root.add_child(shadow)
	root.add_child(_line_mesh(geo.lane_width, size.z))
	return root


## Its shadow on its lane: a quad over its walkway's footprint `footprint` (width, length) and SHADOW_MARGIN more, in
## its own soft-edged shadow material (darkness 0 until it falls), drawn before the red line over it.
static func _shadow_mesh(footprint: Vector2) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	shadow.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = MeshKit.shader(SHADOW_SHADER)
	mat.render_priority = -1
	var shadow_size := footprint + Vector2.ONE * SHADOW_MARGIN * 2.0
	mat.set_shader_parameter(&"size", shadow_size)
	mat.set_shader_parameter(&"soft", SHADOW_SOFT)
	mat.set_shader_parameter(&"darkness", 0.0)
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.transform = Transform3D(Basis.from_scale(Vector3(shadow_size.x, 1.0, shadow_size.y)), Vector3(0.0, 0.04, 0.0))
	return shadow


## The red line along its lane, `length` long on a lane `lane_width` wide (BossProps.lane_warning's look).
static func _line_mesh(lane_width: float, length: float) -> MeshInstance3D:
	var line := MeshInstance3D.new()
	line.name = "WarningLine"
	line.mesh = GreyboxMaterials.unit_box()
	line.material_override = GreyboxMaterials.glow(WARNING_COLOR, 2.6, 0.75)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.transform = Transform3D(Basis.from_scale(Vector3(lane_width * LINE_WIDTH_SHARE, 0.04, length)), Vector3(0.0, 0.03, 0.0))
	return line


func _build(geo: TrackGeometry, show_hitboxes: bool) -> void:
	_look = Node3D.new()
	_look.name = "Walkway"
	add_child(_look)
	_place_look(hang_y, Vector2.ZERO, 0.0)
	_wreck = Node3D.new()
	_wreck.name = "Wreck"
	_wreck.position = Vector3(0.0, WRECK_HEIGHT * 0.5, 0.0)
	_wreck.visible = false
	add_child(_wreck)
	_shadow = _shadow_mesh(Vector2(size.x, size.z))
	_shadow_mat = _shadow.material_override as ShaderMaterial
	_shadow.visible = false
	add_child(_shadow)
	_line = _line_mesh(geo.lane_width, size.z)
	_line_base = _line.transform
	_line.visible = false
	add_child(_line)
	# Its hitbox: off until it drops.
	hitbox = Hazard.new()
	hitbox.name = "Hitbox"
	hitbox.hazard_name = "falling gantryway"
	# DESIGN-TBD (docs/questions/q3.md 8): the armor, then the shield, absorb it (GDD §5), and one blocked hit pays for the
	# whole walkway (passes_after_block, as for a sign).
	hitbox.is_solid = true
	hitbox.armor_blocks_solid = true
	hitbox.passes_after_block = true
	hitbox.collision_layer = 0
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.state = Hazard.State.OFF
	var shape := CollisionShape3D.new()
	_hit_shape = BoxShape3D.new()
	_hit_shape.size = Vector3(size.x, size.y, size.z)
	shape.shape = _hit_shape
	hitbox.add_child(shape)
	hitbox.size = _hit_shape.size
	hitbox.position = Vector3(0.0, hang_y + size.y * 0.5, 0.0)
	add_child(hitbox)
	_hit_debug = GreyboxMaterials.add_box(hitbox, Vector3.ZERO, Vector3.ONE, GreyboxMaterials.debug_hitbox())
	_hit_debug.scale = _hit_shape.size * 1.01
	_hit_debug.add_to_group(&"debug_hitbox")
	_hit_debug.visible = show_hitboxes
	# Its snow and its debris, made with it (their material, the kit's lit one, is every rubble burst's).
	_snow = RubbleBurst.new(SNOW_PIECES)
	_snow.name = "Snow"
	add_child(_snow)
	_debris = RubbleBurst.new(DEBRIS_PIECES)
	_debris.name = "Debris"
	add_child(_debris)


func _voice(voice_name: String, stream: AudioStream, db: float, full_volume: float, silent: float) -> AudioStreamPlayer3D:
	var v := AudioStreamPlayer3D.new()
	v.name = voice_name
	v.stream = stream
	v.volume_db = db
	v.unit_size = full_volume
	v.max_distance = silent
	if AudioServer.get_bus_index(SfxLibrary.BUS) >= 0:
		v.bus = SfxLibrary.BUS
	add_child(v)
	return v


func _play(sound: StringName, voice: AudioStreamPlayer3D) -> void:
	sounds_played.append(sound)
	if voice != null and voice.stream != null and SfxLibrary.audible():
		voice.play()


## Its walkway's look with its underside at height `underside`, moved across and up by `shake` and rolled by `roll`.
func _place_look(underside: float, shake: Vector2, roll: float) -> void:
	_look.transform = Transform3D(Basis(Vector3.BACK, roll), Vector3(shake.x, underside + size.y * 0.5 + shake.y, 0.0))


## Its shadow darkening and its lane's line widening and pulsing, as far as its fall has come.
func _update_warning() -> void:
	var k: float = clampf(t / maxf(tuning.fall_seconds, 0.01), 0.0, 1.0)
	_shadow_mat.set_shader_parameter(&"darkness", _shadow_alpha * (0.4 + 0.6 * k))
	var grow: float = 0.85 + 0.25 * clampf(t / 0.8, 0.0, 1.0)
	var beat: float = 1.0 if Settings.flashing_reduced else 1.0 + 0.12 * sin(t * 24.0)
	_line.transform = Transform3D(_line_base.basis * Basis.from_scale(Vector3(grow * beat, 1.0, 1.0)), _line_base.origin)


## This tick's path: what the walkway's box went through from underside `lo` up to `hi` (world heights), and its
## hitbox over it, a little smaller (hitbox_inset across, at its ends and at its underside).
func _set_sweep(lo: float, hi: float) -> void:
	var z0: float = TrackGeometry.world_z(_end)
	_sweep = AABB(Vector3(_x - size.x * 0.5, lo, z0), Vector3(size.x, maxf(hi - lo, 0.01), size.z))
	_set_hitbox(lo, hi)


func _set_hitbox(lo: float, hi: float) -> void:
	var inset: float = clampf(tuning.hitbox_inset, 0.0, minf(size.x, size.z) * 0.4)
	var bottom: float = minf(lo + inset, hi - 0.05)
	var box := Vector3(maxf(size.x - inset * 2.0, 0.1), maxf(hi - bottom, 0.05), maxf(size.z - inset * 2.0, 0.1))
	_hit_shape.size = box
	hitbox.size = box
	hitbox.position = Vector3(0.0, bottom + box.y * 0.5, 0.0)
	_hit_debug.scale = box * 1.01


func _hitbox_off() -> void:
	hitbox.set_enabled(false)
	hitbox.collision_layer = 0


## It lands: flat on its lane, its wreck in place of its walkway, its warning gone, its pieces flung out and its crash.
func _land() -> void:
	underside_y = 0.0
	_set_sweep(0.0, _last_underside + size.y)
	_last_underside = 0.0
	state = State.LANDED
	_landing_ticks = 0
	entry["landed"] = true
	_look.visible = false
	_wreck.visible = true
	_shadow.visible = false
	_line.visible = false
	# Its pieces and snow from the stretch nearest the camera (where the runner who got out from under it is).
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var from: float = _start
	if camera != null:
		from = clampf(-camera.global_position.z - 5.0, _start, maxf(_end - LAND_REACH, _start))
	var reach: float = minf(LAND_REACH, _end - from)
	var colors: PackedColorArray = debris_colors.duplicate()
	colors.append_array(snow_colors)
	_debris.play(AABB(Vector3(_x - size.x * 0.5, 0.0, TrackGeometry.world_z(from + reach)), Vector3(size.x, size.y, reach)),
		colors, Vector3.ZERO, 0.0, 3.0, 3.5, 0.3, 1.0, int(entry.get("seed", 0)) + 2)
	if _land_voice != null:
		var at: Vector3 = nearest_point(camera.global_position) if camera != null else global_position
		_land_voice.global_position = at
	_play(LAND_SOUND, _land_voice)
	swept.emit(self)
	landed.emit(self)


## Shown as it lies after its fall (one that fell already when it was built).
func _show_landed() -> void:
	state = State.LANDED
	_landing_ticks = LANDING_TICKS
	underside_y = 0.0
	_look.visible = false
	_wreck.visible = true
	_hitbox_off()


static func _ease_out(u: float) -> float:
	return 1.0 - (1.0 - u) * (1.0 - u)
