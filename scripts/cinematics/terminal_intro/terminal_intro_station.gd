class_name TerminalIntroStation
extends Node3D
## The Grand Terminal Station's front, seen from outside (TerminalIntro; the owner's beats, October 21, 2026, GDD §6 Cinematics,
## "Terminal intro"): a large old station, abandoned and decayed, standing back from the Dead Zone's street behind a forecourt of
## rubble, in an opening of the street's left wall (CineStageDef.wall_gaps), so the wasteland round it is the Dead Zone's and
## the street is the zone's own. Visual only: no hitboxes.
## Its frame (the node is turned so that): x along the front to the viewer's right as one looks at it from the street, y up, z
## out from the front toward the street (the front is the plane z = 0; the street's left wall's line is z = forecourt). So a
## letter or a window is built in the plane x-y facing +z, as TextMesh and the kit's quads expect. `track()` turns a point of it
## into track space and `heading()` a direction into a runner's heading.
## - The head house in the middle: tall arched windows beside the entrance and a great arched window over it, its panes
##   broken and lit warm from inside; pilasters, string courses, a heavy cornice, and the broad band over it where the sign
##   ran. The entrance: a doorway under the band, blocked by a heap of rubble (TerminalIntroHeap) up to just under its lintel,
##   so only a crack of light is left at the top, the station's hall behind it glowing warm.
## - The wings either side, two rows of tall windows, a few lit; the right one broken down toward its end.
## - The forecourt: the Dead Zone's street pavement (kit pattern PAT_DZ_STREET, laid out from the world, so it joins the
##   street) across to the front, with fallen masonry.
## - The light coming out (the Terminal's failing orange, TerminalIntroTuning.light_color): shafts and a pool of it on the
##   forecourt from the great window and from the crack, halos round the windows (additive cards of the skin's glow
##   material), and real lights for the runner and the letters. The shafts breathe slowly (steady with Reduced flashing).
## DESIGN-TBD (docs/questions/f2k.md): the station's design, simplified from the owner's reference of the Terminal's look and
## the Dead Zone's grey.

const STONE := Color(0.205, 0.193, 0.182)
const STONE_LIGHT := Color(0.28, 0.265, 0.248)
const STONE_DARK := Color(0.115, 0.108, 0.1)
const SOOT := Color(0.09, 0.087, 0.083)
const STEEL := Color(0.13, 0.12, 0.115)
const GLASS_OFF := Color(0.025, 0.027, 0.03)
const PLATE := Color(0.19, 0.188, 0.185)
## The front's thickness, and how far the pilasters, courses and the cornice stand out of it.
const THICK: float = 1.4
## The glass's offset in front of the wall.
const GLASS_Z: float = 0.05

var n: TerminalIntroTuning
var skin: ZoneSkin
var solid: ShaderMaterial
var glow: ShaderMaterial
## The shafts' own glow material (duplicated, so the cinematic can breathe it), the shafts' mesh and the crack's.
var shaft_material: ShaderMaterial
var pool_material: ShaderMaterial
var body: MeshInstance3D
var shafts: MeshInstance3D
var heap: TerminalIntroHeap
var lights: Array[OmniLight3D] = []
## Track-space x of the front.
var front_x: float = 0.0
var along_at: float = 0.0
var _rng := RandomNumberGenerator.new()


## Turns a point of the station's frame into track space (x across the street, y up, z along it).
func track(p: Vector3) -> Vector3:
	return Vector3(front_x + p.z, p.y, along_at + p.x)


## A material of its own with the same shader and parameters as `src`, to animate one thing without touching the skin's shared
## material. Not Resource.duplicate(): on a colour uniform given as a Vector3 (the zone skins' sRGB rule) the engine's duplicate
## drops the value from the source and the copy alike (the Dead Zone's sheen_color went back to the shader's purple default for the
## rest of the session), so the parameters are copied over by name.
static func own(src: ShaderMaterial) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = src.shader
	if src.shader != null:
		for u: Dictionary in src.shader.get_shader_uniform_list():
			var key: StringName = StringName(u["name"])
			var v: Variant = src.get_shader_parameter(key)
			if v != null:
				m.set_shader_parameter(key, v)
	return m


## A runner's heading (radians, 0 down the street, + turning left) for a direction (dx along the front, dz out from it).
static func heading(dx: float, dz: float) -> float:
	# Track x is the station's z, track z its x.
	return atan2(-dz, dx)


func setup(p_skin: ZoneSkin, p_numbers: TerminalIntroTuning, p_front_x: float, p_station_at: float, stage: CineStage) -> void:
	name = "Station"
	skin = p_skin
	n = p_numbers
	front_x = p_front_x
	along_at = p_station_at
	solid = skin.call(&"solid_material") as ShaderMaterial if skin.has_method(&"solid_material") else MeshKit.solid()
	glow = skin.call(&"glow_material") as ShaderMaterial if skin.has_method(&"glow_material") else MeshKit.glow()
	# Its frame: x along the street's z (toward -z in the world), z out toward +x.
	position = stage.point(Vector3(front_x, 0.0, along_at))
	rotation_degrees = Vector3(0.0, 90.0, 0.0)
	_rng.seed = 7311
	heap = TerminalIntroHeap.new(n.heap_height, n.heap_length, n.heap_foot_width, n.door_width)
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid)
	var g: MeshLayer = batch.layer(glow)
	_ground(s)
	_head_house(s, g)
	_wing(s, g, -1)
	_wing(s, g, 1)
	_hall(s)
	heap.build(s)
	heap.build_chunks(s)
	_fallen(s)
	body = batch.commit(self, "Front")
	if body != null:
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light_shafts()
	_lights()


# --- Drawing helpers ---------------------------------------------------------------------------------------------

## A box from x0 to x1, y0 to y1 and from `back` to `out` in z (the front is z = 0).
func _slab(s: MeshLayer, x0: float, x1: float, y0: float, y1: float, color: Color, out: float = 0.0, back: float = -THICK,
		pattern: int = MeshKit.PAT_DZ_CONCRETE, faces: int = MeshKit.ALL_FACES) -> void:
	s.box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (out + back) * 0.5), Vector3(x1 - x0, y1 - y0, out - back), color, 0.0,
		pattern, faces, 0.0)


## A triangle (corners clockwise seen from the front, +z) on a layer.
func _tri(l: MeshLayer, a: Vector3, b: Vector3, c: Vector3, color: Color, glow_amount: float = 0.0, pattern: int = MeshKit.PAT_PLAIN) -> void:
	l.quad(a, b, c, c, color, glow_amount, pattern, 0.0)


## A triangle with a colour (and glow, alpha) at each corner, plain pattern.
func _tri_c(l: MeshLayer, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	l.verts.append_array(PackedVector3Array([a, b, c]))
	l.colors.append_array(PackedColorArray([ca, cb, cc]))
	l.uvs.append_array(PackedVector2Array([Vector2(a.x, a.y), Vector2(b.x, b.y), Vector2(c.x, c.y)]))
	var p := Vector2(MeshKit.PAT_PLAIN, 0.0)
	l.uv2s.append_array(PackedVector2Array([p, p, p]))


## The outline of an arched window of `w` wide from y0 (its sill) to y1 (the arch's crown) at x = cx: the points from
## the bottom left up and over to the bottom right (the arch a semicircle on a rectangle).
func _arch_points(cx: float, y0: float, y1: float, w: float, segments: int = 8, inset: float = 0.0) -> PackedVector3Array:
	var r: float = w * 0.5 - inset
	var spring: float = y1 - w * 0.5
	var pts := PackedVector3Array()
	pts.append(Vector3(cx - r, y0 + inset, 0.0))
	pts.append(Vector3(cx - r, spring, 0.0))
	for i: int in range(1, segments):
		var a: float = PI - PI * float(i) / float(segments)
		pts.append(Vector3(cx + r * cos(a), spring + r * sin(a), 0.0))
	pts.append(Vector3(cx + r, spring, 0.0))
	pts.append(Vector3(cx + r, y0 + inset, 0.0))
	return pts


## A filled arch at depth `z` (a triangle fan from its middle, so any outline).
func _fill_arch(l: MeshLayer, cx: float, y0: float, y1: float, w: float, z: float, color: Color, glow_amount: float,
		inset: float = 0.0, segments: int = 8, top_scale: float = 1.0) -> void:
	var pts: PackedVector3Array = _arch_points(cx, y0, y1, w, segments, inset)
	var mid := Vector3(cx, (y0 + y1) * 0.5, z)
	var span: float = maxf(y1 - y0, 0.01)
	# The glass dims toward the top (`top_scale` of the glow there): light pooling low in the room behind it.
	var mid_c := Color(color, glow_amount * lerpf(1.0, top_scale, 0.5))
	for i: int in pts.size():
		var a := Vector3(pts[i].x, pts[i].y, z)
		var b := Vector3(pts[(i + 1) % pts.size()].x, pts[(i + 1) % pts.size()].y, z)
		var ca := Color(color, glow_amount * lerpf(1.0, top_scale, clampf((a.y - y0) / span, 0.0, 1.0)))
		var cb := Color(color, glow_amount * lerpf(1.0, top_scale, clampf((b.y - y0) / span, 0.0, 1.0)))
		# Clockwise seen from +z: the outline runs up the left side and over the top to the right: that is clockwise.
		_tri_c(l, mid, a, b, mid_c, ca, cb)


## An arched window: a stone surround standing out of the wall, the glass (warm and glowing: `lit` 0-1, 0 dark), mullions
## and a transom, and panes broken out of it. `arch` false: a flat top.
func _window(s: MeshLayer, cx: float, y0: float, y1: float, w: float, lit: float, panes: int = 3, seed_id: int = 0) -> void:
	var rim: float = 0.28
	# The surround: stone round the opening, deeper than the glass.
	_fill_arch(s, cx, y0 - rim, y1 + rim, w + rim * 2.0, 0.1, STONE_DARK, 0.0)
	if lit > 0.0:
		# The lit glass glows (the vertices' alpha).
		_fill_arch(s, cx, y0, y1, w, 0.16, n.light_color.lerp(Color(1.0, 0.72, 0.4), 0.25) * (0.35 + 0.65 * lit), 0.04 + 0.12 * lit, 0.0, 8, 0.35)
	else:
		_fill_arch(s, cx, y0, y1, w, 0.16, GLASS_OFF, 0.0)
	# Mullions and a transom, charred steel.
	var spring: float = y1 - w * 0.5
	for k: int in range(1, panes):
		var x: float = cx - w * 0.5 + w * float(k) / float(panes)
		var h: float = spring - y0 + sqrt(maxf(1.0 - pow(2.0 * float(k) / float(panes) - 1.0, 2.0), 0.0)) * w * 0.5
		s.box(Vector3(x, y0 + h * 0.5, 0.22), Vector3(0.09, h, 0.1), STEEL, 0.0, MeshKit.PAT_DZ_STEEL, MeshKit.ALL_FACES, 0.0)
	s.box(Vector3(cx, spring - 0.1, 0.22), Vector3(w, 0.1, 0.1), STEEL, 0.0, MeshKit.PAT_DZ_STEEL, MeshKit.ALL_FACES, 0.0)
	# Broken panes: dark holes in the lit glass (a window whose glass is all gone shows the dark inside).
	if lit > 0.0:
		var holes: int = 2 + seed_id % 3
		for k: int in holes:
			var hx: float = cx + (MeshKit.hash01(seed_id, k, 11) - 0.5) * (w - 0.7)
			var hy: float = lerpf(y0 + 0.5, spring + 0.5, MeshKit.hash01(seed_id, k, 12))
			var hw: float = 0.35 + 0.55 * MeshKit.hash01(seed_id, k, 13)
			var hh: float = 0.4 + 0.8 * MeshKit.hash01(seed_id, k, 14)
			var skew: float = (MeshKit.hash01(seed_id, k, 15) - 0.5) * 0.5
			s.quad(Vector3(hx - hw * 0.5, hy - hh * 0.5, 0.2), Vector3(hx - hw * 0.5 + skew, hy + hh * 0.5, 0.2),
				Vector3(hx + hw * 0.5 + skew, hy + hh * 0.5, 0.2), Vector3(hx + hw * 0.5, hy - hh * 0.5, 0.2), GLASS_OFF, 0.0)


# --- The forecourt and the fallen masonry ------------------------------------------------------------------------

## The pavement across the forecourt (the Dead Zone's street, so it joins the street's own floor at the wall's line) and
## the slab the front stands on.
func _ground(s: MeshLayer) -> void:
	var half: float = n.frontage * 0.5 + 6.0
	var out: float = n.forecourt + 0.05
	# PAT_DZ_STREET: UV.x -1 to 1 across a lane, UV.y metres along it; param flags 0 (no lane lines, no gutter): plates and ash.
	s.rect(Vector3(-half, 0.0, out), Vector3(half * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, -out), Color(0.15, 0.148, 0.145), 0.0,
		MeshKit.PAT_DZ_STREET, Vector2(-1.0, 0.0), Vector2(1.0, out), 0.0)
	# A kerb along the street's edge across the opening, over the orange lip a level's wall gap carries there (it tells a
	# runner "the wall stops": here it's an open plaza), and a rubble pier over each cut end's orange edge.
	_slab(s, -n.frontage * 0.5, n.frontage * 0.5, 0.0, 0.07, STONE_DARK, n.forecourt + 0.45, n.forecourt - 0.5)
	for side: float in [-1.0, 1.0]:
		_slab(s, side * n.frontage * 0.5 - 0.9, side * n.frontage * 0.5 + 0.9, 0.0, 7.4, STONE_DARK, n.forecourt + 0.9, n.forecourt - 1.0)
	# The kerb of the station's plinth.
	_slab(s, -n.hall_width * 0.5 - 1.0, n.hall_width * 0.5 + 1.0, 0.0, 0.5, STONE_DARK, 1.4, 0.0)


## Fallen masonry on the forecourt: blocks of the cornice and the broken pilasters, scattered in front of the wings.
func _fallen(s: MeshLayer) -> void:
	_rng.seed = 4409
	for i: int in 26:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * _rng.randf_range(n.hall_width * 0.5 + 1.0, n.hall_width * 0.5 + n.wing_width * 0.9)
		var z: float = _rng.randf_range(0.8, 6.5)
		# Not where they walk (the way round the heap to the board).
		if x > 2.5 and x < 10.5 and z < 12.0:
			continue
		var size := Vector3(_rng.randf_range(0.5, 2.0), _rng.randf_range(0.25, 0.9), _rng.randf_range(0.5, 1.5))
		var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-PI, PI), _rng.randf_range(-0.3, 0.3)))
		s.box_xform(Transform3D(basis * Basis.from_scale(size), Vector3(x, size.y * 0.35, z)),
			(STONE if _rng.randf() < 0.6 else STONE_DARK) * _rng.randf_range(0.8, 1.15), 0.0, MeshKit.PAT_DZ_CONCRETE, MeshKit.ALL_FACES, 0.0)


# --- The head house ---------------------------------------------------------------------------------------------

func _head_house(s: MeshLayer, g: MeshLayer) -> void:
	var hw: float = n.hall_width * 0.5
	var dw: float = n.door_width * 0.5
	var top: float = n.hall_height
	# The wall in three: left of the door, right of it, and over it (the lintel course, as high as the sign's band).
	_slab(s, -hw, -dw, 0.0, top, STONE)
	_slab(s, dw, hw, 0.0, top, STONE)
	_slab(s, -dw, dw, n.door_height, top, STONE)
	# The doorway's jambs and the reveal into the dark passage: a dark inside to the hall behind.
	_slab(s, -dw - 0.5, -dw, 0.0, n.door_height + 0.5, STONE_DARK, 0.5, -THICK, MeshKit.PAT_DZ_CONCRETE)
	_slab(s, dw, dw + 0.5, 0.0, n.door_height + 0.5, STONE_DARK, 0.5, -THICK, MeshKit.PAT_DZ_CONCRETE)
	_slab(s, -dw - 0.5, dw + 0.5, n.door_height, n.door_height + 0.6, STONE_DARK, 0.6, -THICK, MeshKit.PAT_DZ_CONCRETE)
	# The lintel broken: stone teeth hanging into the doorway, so the crack under it is ragged.
	var tooth: float = -dw
	var ti: int = 0
	while tooth < dw - 0.1:
		var tw: float = 0.5 + 0.9 * MeshKit.hash01(ti, 7, 71)
		var td: float = 0.12 + 0.5 * MeshKit.hash01(ti, 8, 72)
		_tri(s, Vector3(tooth, n.door_height, 0.25), Vector3(tooth + tw * 0.5, n.door_height - td, 0.25), Vector3(minf(tooth + tw, dw), n.door_height, 0.25),
			STONE_DARK, 0.0, MeshKit.PAT_DZ_CONCRETE)
		tooth += tw
		ti += 1
	# Plinth and courses.
	_slab(s, -hw - 0.5, hw + 0.5, 0.0, 0.45, STONE_DARK, 0.28)
	_slab(s, -hw - 0.3, hw + 0.3, 8.2, 8.75, STONE_LIGHT, 0.4)
	_slab(s, -hw - 0.3, hw + 0.3, 18.2, 19.0, STONE_LIGHT, 0.5)
	# The band the sign ran along: a darker panel, soot streaked.
	s.rect(Vector3(-hw + 1.0, 19.1, 0.05), Vector3(hw * 2.0 - 2.0, 0.0, 0.0), Vector3(0.0, top - 19.9, 0.0), Color(0.05, 0.047, 0.045), 0.0,
		MeshKit.PAT_DZ_CONCRETE, Vector2.ZERO, Vector2.ONE, 0.0)
	# The cornice and the parapet over it.
	_slab(s, -hw - 0.9, hw + 0.9, top, top + 0.5, STONE_LIGHT, 1.0, -THICK)
	_slab(s, -hw - 0.5, hw + 0.5, top + 0.5, top + 1.5, STONE, 0.5, -0.4)
	# Pilasters: either side of the great window, between the bays and at the ends of the head house.
	for side: float in [-1.0, 1.0]:
		for px: float in [7.2, 12.6, hw - 0.5]:
			_slab(s, side * px - 0.7, side * px + 0.7, 0.4, 18.2, STONE_LIGHT, 0.55)
			_slab(s, side * px - 0.85, side * px + 0.85, 17.7, 18.2, STONE, 0.7)
	# Windows: tall arches either side of the door and in the bays, the lower row dark; in the upper row a few lit.
	var sid: int = 0
	for side: float in [-1.0, 1.0]:
		_window(s, side * 5.3, 1.8, 7.2, 2.2, 0.0, 2, sid)
		_window(s, side * 9.9, 1.8, 7.2, 3.2, 0.0, 2, sid + 1)
		_window(s, side * 14.8, 1.8, 7.2, 2.4, 0.0, 2, sid + 2)
		sid += 3
	var lit_small: Array = [[-1.0, 9.9, 0.0], [-1.0, 14.8, 0.55], [1.0, 9.9, 0.35], [1.0, 14.8, 0.0]]
	for w: Array in lit_small:
		_window(s, float(w[0]) * float(w[1]), 10.2, 16.4, 3.0 if float(w[1]) < 12.0 else 2.4, float(w[2]), 2, sid)
		sid += 1
	# The great window over the entrance: its glass mostly gone, the hall behind lit warm.
	var ww: float = n.window_width
	_window(s, 0.0, n.window_from, n.window_to, ww, 1.0, 5, 41)
	# The head house's halo of light: the great window's, and the crack of the doorway's.
	var halo: Color = n.light_color
	g.rect(Vector3(-ww * 0.8, n.window_from - 1.2, 0.6), Vector3(ww * 1.6, 0.0, 0.0), Vector3(0.0, (n.window_to - n.window_from) + 2.8, 0.0),
		halo, 0.34, MeshKit.SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE, -4.0)
	g.rect(Vector3(-dw - 1.6, n.door_height - 2.6, 0.7), Vector3(dw * 2.0 + 3.2, 0.0, 0.0), Vector3(0.0, 4.8, 0.0), halo, 0.3,
		MeshKit.SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE, -4.0)
	_streaks(s, hw)


## Soot streaks down the front from the sills and the cornice (dark strips), and stains.
func _streaks(s: MeshLayer, hw: float) -> void:
	_rng.seed = 5521
	for i: int in 34:
		var x: float = _rng.randf_range(-hw, hw)
		var top: float = _rng.randf_range(8.0, n.hall_height - 1.0)
		var length: float = _rng.randf_range(2.0, 7.0)
		if absf(x) < n.door_width * 0.5 + 0.8 and top - length < n.door_height:
			continue
		s.rect(Vector3(x, maxf(top - length, 0.3), 0.07), Vector3(_rng.randf_range(0.2, 0.7), 0.0, 0.0), Vector3(0.0, minf(length, top - 0.3), 0.0),
			SOOT * 1.3, 0.0, MeshKit.PAT_PLAIN, Vector2.ZERO, Vector2.ONE, 0.0)


# --- The wings --------------------------------------------------------------------------------------------------

## A wing: `side` -1 the left, 1 the right (broken down toward its end).
func _wing(s: MeshLayer, g: MeshLayer, side: float) -> void:
	var hw: float = n.hall_width * 0.5
	var width: float = n.wing_width
	var height: float = n.wing_height_left if side < 0.0 else n.wing_height_right
	var x0: float = hw if side > 0.0 else -hw - width
	var x1: float = x0 + width
	# The wall, in sections of its bays, each its own height: the right wing's last ones broken off.
	var bay: float = 4.6
	var count: int = int(round(width / bay))
	var pitch: float = width / float(count)
	for i: int in count:
		var a: float = x0 + pitch * float(i)
		var b: float = a + pitch
		var u: float = (float(i) + 0.5) / float(count)
		var along_end: float = u if side > 0.0 else 1.0 - u
		var h: float = height
		if side > 0.0 and along_end > 0.55:
			h = height * lerpf(1.0, 0.5, smoothstep(0.55, 1.0, along_end)) - 0.8 * MeshKit.hash01(i, 3, 9) * 3.0
		_slab(s, a, b, 0.0, h, STONE)
		# The wing's top edge: a cornice while it stands, jagged where it is broken.
		if h >= height - 0.01:
			_slab(s, a - 0.05, b + 0.05, h, h + 0.55, STONE_LIGHT, 0.7, -0.9)
		else:
			var jag: float = 0.6 + 1.6 * MeshKit.hash01(i, 5, 9)
			_tri(s, Vector3(a, h, 0.0), Vector3(a + pitch * 0.35, h + jag, 0.0), Vector3(a + pitch * 0.7, h, 0.0), STONE, 0.0,
				MeshKit.PAT_DZ_CONCRETE)
			# A floor slab hanging out of the broken top, and rebar.
			_slab(s, a + 0.4, b - 0.4, h - 0.9, h - 0.6, STONE_DARK, 1.4, -1.0)
		# Windows: two rows of tall arches, a few lit; none above a broken top.
		var cx: float = (a + b) * 0.5
		var lit_low: float = 0.0
		var lit_high: float = 0.0
		var roll: float = MeshKit.hash01(i, int(side) + 3, 21)
		if roll < 0.2:
			lit_low = 0.4 + 0.4 * MeshKit.hash01(i, 1, 22)
		elif roll > 0.85:
			lit_high = 0.3 + 0.4 * MeshKit.hash01(i, 2, 23)
		_window(s, cx, 1.8, 7.6, 2.5, lit_low, 2, i * 7 + int(side) + 20)
		if h > 14.2:
			_window(s, cx, 8.8, 13.6, 2.5, lit_high, 2, i * 5 + int(side) + 30)
		# Pilasters between the bays.
		_slab(s, b - 0.4, b + 0.4, 1.0, minf(h, height) - 0.2, STONE_LIGHT, 0.5)
	# Plinth and string course.
	_slab(s, x0, x1, 0.0, 0.45, STONE_DARK, 0.28)
	_slab(s, x0, x1, 8.2, 8.65, STONE_LIGHT, 0.35)
	# The end of the wing.
	_slab(s, x1 if side > 0.0 else x0 - 0.1, (x1 + 0.1) if side > 0.0 else x0, 0.0, height * (0.55 if side > 0.0 else 1.0), STONE_DARK, 0.3)


# --- The hall behind ----------------------------------------------------------------------------------------------

## The station's hall behind the front, seen through the crack and the windows: a dark box whose far wall glows warm, a big
## room lit by its work lamps.
func _hall(s: MeshLayer) -> void:
	var hw: float = n.hall_width * 0.5 - 1.0
	var depth: float = 16.0
	var lamp: Color = n.light_color
	# The far wall: a warm glow, brighter toward its middle; the floor and the ceiling dark.
	s.rect(Vector3(-hw, 0.0, -depth), Vector3(hw * 2.0, 0.0, 0.0), Vector3(0.0, 19.0, 0.0), lamp.lerp(Color(1.0, 0.75, 0.4), 0.15), 0.12,
		MeshKit.PAT_PLAIN, Vector2.ZERO, Vector2.ONE, 0.0)
	s.rect(Vector3(-hw, 0.2, -THICK), Vector3(hw * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, -(depth - THICK)), SOOT, 0.0, MeshKit.PAT_PLAIN)
	s.rect(Vector3(-hw, 19.0, -depth), Vector3(hw * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, depth - THICK), SOOT, 0.0, MeshKit.PAT_PLAIN)
	# The side walls inside (dark), so the crack sees the glow beyond and nothing else.
	for side: float in [-1.0, 1.0]:
		var along := Vector3(0.0, 0.0, -(depth - THICK))
		var up := Vector3(0.0, 19.0, 0.0)
		s.rect(Vector3(side * hw, 0.0, -THICK), along if side < 0.0 else up, up if side < 0.0 else along, SOOT * 1.4, 0.0, MeshKit.PAT_PLAIN)


# --- The light ----------------------------------------------------------------------------------------------------

## The shafts of light out of the great window and the crack, and the pools they make on the forecourt: additive cards of
## the skin's glow material (a copy of it, so the cinematic can breathe it).
func _light_shafts() -> void:
	shaft_material = own(glow)
	pool_material = own(glow)
	var batch := MeshBatch.new()
	var g: MeshLayer = batch.layer(shaft_material)
	var c: Color = n.light_color
	var dw: float = n.door_width * 0.5
	# From the crack: a fan down onto the heap and the forecourt, and out; one sheet tilted down, two upright.
	var crack_y: float = n.door_height - 0.5
	for k: int in 3:
		var fan: float = float(k - 1) * 1.6
		g.rect(Vector3(-dw + 0.4 + fan * 0.3, crack_y, 0.1), Vector3(dw * 2.0 - 0.8 + absf(fan), 0.0, 0.0),
			Vector3(fan * 2.0, -crack_y + 0.1, n.heap_length + 4.0 + float(k) * 2.0) , c, n.shaft_glow * 1.2, MeshKit.SHAPE_BEAM, Vector2.ZERO, Vector2.ONE, -3.5)
	# From the great window: slanting shafts out and down to the forecourt.
	var ww: float = n.window_width
	for k: int in 4:
		var x0: float = -ww * 0.4 + ww * 0.8 * float(k) / 3.0
		var drift: float = (float(k) - 1.5) * 1.4
		g.rect(Vector3(x0 - 1.3, n.window_from + 1.0, 0.3), Vector3(2.6, 0.0, 0.0),
			Vector3(drift, -(n.window_from + 1.0), n.forecourt * 0.85 + 2.0), c, n.shaft_glow, MeshKit.SHAPE_BEAM, Vector2.ZERO, Vector2.ONE, -3.5)
	shafts = batch.commit(self, "Shafts")
	if shafts != null:
		shafts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The pools: warm light lying on the forecourt and the heap (flat cards on the ground, soft).
	var pool := MeshBatch.new()
	var p: MeshLayer = pool.layer(pool_material)
	p.rect(Vector3(-9.0, 0.06, 0.5), Vector3(18.0, 0.0, 0.0), Vector3(0.0, 0.0, n.forecourt * 0.9), c, n.pool_glow, MeshKit.SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE, -2.0)
	p.rect(Vector3(-4.0, 0.08, 0.3), Vector3(8.0, 0.0, 0.0), Vector3(0.0, 0.0, 6.0), c, n.pool_glow * 1.3, MeshKit.SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE, -2.0)
	var pools: MeshInstance3D = pool.commit(self, "Pools")
	if pools != null:
		pools.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The real lights: warm, at the doorway and the great window, for the runner and whatever the kit's lights don't reach.
func _lights() -> void:
	for at: Vector3 in [Vector3(0.0, n.door_height - 1.0, 3.0), Vector3(0.0, n.window_from + 3.0, 4.0), Vector3(6.0, 3.0, 4.0)]:
		var l := OmniLight3D.new()
		l.position = at
		l.light_color = n.light_color
		l.light_energy = n.light_energy
		l.omni_range = n.light_range
		l.shadow_enabled = false
		add_child(l)
		lights.append(l)


## Breathes the light: `k` 0-1.3 around 1 (its strength now), for the shafts, the pools and the real lights.
func set_light(k: float) -> void:
	if shaft_material != null:
		shaft_material.set_shader_parameter(&"state_glow", k)
	if pool_material != null:
		pool_material.set_shader_parameter(&"state_glow", k)
	for l: OmniLight3D in lights:
		l.light_energy = n.light_energy * k


## Draw calls its meshes add now (each visible mesh's surfaces): tests.
func draw_calls() -> int:
	var calls: int = 0
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			calls += m.mesh.get_surface_count()
	return calls
