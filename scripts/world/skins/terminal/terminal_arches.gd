class_name TerminalArches
extends RefCounted
## The Terminal's side walls (TerminalSkin, GDD §5, owner, October 20, 2026): narrow arches, to read as the old subway's tunnel
## arches or structural supports. Each wall section is one space wide (about a standard doodad's width) with about six
## lengths of open space before the next one, mostly in pairs, left and right; where one side's section is missing, that side
## shows a section cut off about halfway up, as if it had deteriorated over time or fallen in an earthquake, a crumbled ruin.
## The open space between them is the hall, which the floor draws (TerminalHall).
## - An ARCH is a riveted steel pier standing on a concrete plinth, from the floor into the vault: a flush street face in
##   old painted steel (verdigris flaking to rust, PAT_TERMINAL_STEEL) with angle irons up its edges and riveted straps round
##   it, sometimes a rust-red enamel plate (a painted border and four bolts), a flared capital where it meets the shell, and a rib springing from the capital
##   along the vault toward the middle of the street (half an arch: with its partner on the other wall it closes the arch
##   over the street, and a lone one is a broken arch). Vines hang from the capital, and a bush of them grows at its foot
##   beyond the kerb.
## - A STUMP is the same pier broken off at about half its height in three uneven columns, the paint gone from the top of
##   them and the concrete core showing, rebar bristling from the break, rubble heaped at its foot beyond the kerb.
## Nothing stands more than 5 cm off the wall line in the wall-run band (up to 6 m): the straps and irons are 4.5 cm proud; the
## capital, the rib and the vines are above it. Nothing of a stump is inside the wall line.
## A section longer than a space (the wall every other zone has, which the track builder still gives a skin without O1's arches)
## gets several, pier_pitch apart.
## DESIGN-TBD (docs/questions/o4.md item 4): the arches' look.
## Chunk space: x across, y up (the street at y = 0), z = -distance.

## How far a strap or an angle iron stands off the pier's street face (under the 5 cm the suites allow in the wall-run band).
const PROUD: float = 0.045
## The plinth's height, and how far it and the capital reach past the pier on each side.
const PLINTH: float = 0.9
const FLARE: float = 0.14
const CAPITAL: float = 1.5
const CAPITAL_OUT: float = 0.35
## The half-rib's width along the track and its depth under the shell, and how close to the middle it comes.
const RIB_WIDTH: float = 1.0
const RIB_DEPTH: float = 0.6
const RIB_REACH: float = 0.3
## The lowest a hanging vine reaches: over the top of any ceiling (the underside at ceiling_height, its box 0.8 m deep) and what stands on it.
const VINE_FLOOR: float = 7.4

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: TerminalSkin:
	get:
		return _skin.get_ref() as TerminalSkin
var _skin: WeakRef


func _init(p_skin: TerminalSkin) -> void:
	_skin = weakref(p_skin)


## The piers a wall section between track distances `start` and `end` gets, as Vector2(centre distance, width): one for a
## section about a space long (the width of the section, at most pier_width), several pier_pitch apart for a longer one.
func piers(start: float, end: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var length: float = end - start
	if length <= 0.01:
		return out
	if length <= skin.pier_width * 1.6:
		out.append(Vector2((start + end) * 0.5, clampf(length - 0.2, minf(1.4, length), skin.pier_width)))
		return out
	var n: int = maxi(1, roundi(length / skin.pier_pitch))
	for i: int in n:
		out.append(Vector2(start + (float(i) + 0.5) * length / float(n), skin.pier_width))
	return out


## The arches of a wall section.
func build(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	for p: Vector2 in piers(start, end):
		_pier(s, side, face_x, p.x, p.y)


## The stumps of a wall section.
func stump(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	for p: Vector2 in piers(start, end):
		_stump(s, side, face_x, p.x, p.y)


## A pier's corners: the street face's x, the back's x, and the heights the shell leaves over each.
func _heights(face_x: float) -> Vector2:
	var wall: float = absf(face_x)
	var hall: TerminalHall = skin.hall()
	var h: float = hall.half_width(wall)
	return Vector2(hall.vault_y(wall, h), hall.vault_y(wall + skin.pier_depth, h))


func _pier(s: MeshLayer, side: int, face_x: float, dc: float, w: float) -> void:
	var sd: float = float(side)
	var k: int = MeshKit.hash_i(MeshKit.key(dc), side, 361)
	var heights: Vector2 = _heights(face_x)
	var top_face: float = heights.x - 0.12
	var top_back: float = heights.y - 0.12
	var x_back: float = face_x + sd * skin.pier_depth
	var zn: float = -dc + w * 0.5
	var zf: float = -dc - w * 0.5
	var steel: Color = skin.steel_color
	var toward := Vector3(-sd, 0, 0)
	# The street face, and the face toward the runner (a trapezoid under the shell's slope).
	_wall_quad(s, Vector3(face_x, PLINTH, zn), Vector3(face_x, top_face, zn), Vector3(face_x, top_face, zf), Vector3(face_x, PLINTH, zf),
		toward, steel, MeshKit.PAT_TERMINAL_STEEL, 0.0)
	_wall_quad(s, Vector3(face_x, PLINTH, zn), Vector3(face_x, top_face, zn), Vector3(x_back, top_back, zn), Vector3(x_back, PLINTH, zn),
		Vector3(0, 0, 1), steel.darkened(0.12), MeshKit.PAT_TERMINAL_STEEL, 0.0)
	# The plinth: old concrete, a touch wider than the shaft, its face flush with the wall line.
	s.box(Vector3(face_x + sd * (skin.pier_depth + FLARE) * 0.5, PLINTH * 0.5, -dc),
		Vector3(skin.pier_depth + FLARE, PLINTH, w + FLARE * 2.0), skin.concrete_color, 0.0, MeshKit.PAT_TERMINAL_WALL,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 2.0)
	# Angle irons up the street face's edges and riveted straps round it, 4.5 cm proud.
	var iron: Color = steel.lerp(skin.rust_color, 0.45)
	for z: float in [zn - 0.1, zf + 0.1]:
		s.box(Vector3(face_x - sd * PROUD * 0.5, (PLINTH + top_face) * 0.5, z), Vector3(PROUD, top_face - PLINTH, 0.16), iron, 0.0,
			MeshKit.PAT_TERMINAL_STEEL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ, 0.0)
	for y: float in [2.2, 5.0, 8.3]:
		if y < top_face - 2.0:
			s.box(Vector3(face_x - sd * PROUD * 0.5, y, -dc), Vector3(PROUD, 0.34, w + 0.04), iron.darkened(0.1), 0.0,
				MeshKit.PAT_TERMINAL_STEEL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_NY, 0.0)
	# A rust-red enamel plate on some, wordless, matte.
	if MeshKit.hash01(k, 1, 362) < 0.5:
		var py: float = 3.2 + 0.8 * MeshKit.hash01(k, 2, 363)
		var pz: float = -dc + (MeshKit.hash01(k, 3, 364) - 0.5) * (w - 1.2)
		var pw: float = 0.7
		var px: float = face_x - sd * PROUD
		if side < 0:
			s.rect(Vector3(px, py, pz + pw * 0.5), Vector3(0, 0, -pw), Vector3(0, pw, 0), skin.plate_color, 0.0,
				MeshKit.PAT_TERMINAL_BOARD, Vector2(0, 0), Vector2(1, 1), 100.0 + float(MeshKit.hash_i(k, 4, 365) % 100))
		else:
			s.rect(Vector3(px, py, pz - pw * 0.5), Vector3(0, 0, pw), Vector3(0, pw, 0), skin.plate_color, 0.0,
				MeshKit.PAT_TERMINAL_BOARD, Vector2(0, 0), Vector2(1, 1), 100.0 + float(MeshKit.hash_i(k, 4, 365) % 100))
	# The capital: a flared block where the pier meets the shell, standing out toward the street above the wall-run band.
	var cap_top: float = top_face + 0.05
	var cap_x0: float = face_x - sd * CAPITAL_OUT
	s.box(Vector3((cap_x0 + x_back) * 0.5, cap_top - CAPITAL * 0.5, -dc), Vector3(absf(x_back - cap_x0), CAPITAL, w + FLARE * 4.0),
		steel.darkened(0.05), 0.0, MeshKit.PAT_TERMINAL_STEEL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_NY | MeshKit.FACE_PZ, 0.0)
	_half_rib(s, side, face_x, -dc)
	# Vines hanging from the capital, and a bush of them at the foot beyond the kerb.
	for i: int in 3:
		var vz: float = -dc + (MeshKit.hash01(k, i, 371) - 0.5) * (w - 0.6)
		var y0: float = cap_top - CAPITAL
		# Hanging vines stay above every ceiling's top (the ceiling's box, 6.8 m, and what rides it).
		var vl: float = minf(1.6 + 2.8 * MeshKit.hash01(k, i, 372), y0 - VINE_FLOOR)
		var vw: float = 0.25 + 0.2 * MeshKit.hash01(k, i, 373)
		var vx: float = cap_x0 - sd * 0.02
		var a := Vector3(vx, y0, vz)
		var b := Vector3(vx, y0, vz - vw)
		var c := Vector3(vx - sd * 0.06, y0 - vl, vz - vw * 0.6)
		var d := Vector3(vx - sd * 0.06, y0 - vl * 0.8, vz + vw * 0.1)
		TerminalHall._face(s, a, b, c, d, Vector3(-sd, 0, 0), skin.vine_color, 0.0, MeshKit.PAT_TERMINAL_VINE, 0.0)
	_bush(s, side, face_x, -dc, w, k)


## A bush of vine at a pier's foot, outside the wall line (never over a lane).
func _bush(s: MeshLayer, side: int, face_x: float, zc: float, w: float, k: int) -> void:
	var sd: float = float(side)
	for i: int in 2:
		var bz: float = zc + (MeshKit.hash01(k, i, 381) - 0.5) * (w + 1.0)
		var bs: float = 0.7 + 0.5 * MeshKit.hash01(k, i, 382)
		s.box(Vector3(face_x + sd * (0.1 + bs * 0.5), PLINTH * 0.4 + bs * 0.3, bz), Vector3(bs, bs * 0.75, bs * 1.1), skin.vine_color,
			0.0, MeshKit.PAT_TERMINAL_VINE, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ)


## The rib springing from a pier's head along the vault toward the middle of the street: a strip under the shell and its face
## toward the runner.
func _half_rib(s: MeshLayer, side: int, face_x: float, z: float) -> void:
	var hall: TerminalHall = skin.hall()
	var wall: float = absf(face_x)
	var h: float = hall.half_width(wall)
	var sd: float = float(side)
	var zn: float = z + RIB_WIDTH * 0.5
	var zf: float = z - RIB_WIDTH * 0.5
	var segs: int = 7
	var x_from: float = sd * wall
	var x_to: float = sd * RIB_REACH
	var prev_x: float = x_from
	var prev_p := Vector2(prev_x, hall.vault_y(prev_x, h))
	var prev_o: Vector2 = prev_p + hall.vault_inward(prev_x, h) * RIB_DEPTH
	for i: int in range(1, segs + 1):
		var x: float = lerpf(x_from, x_to, float(i) / float(segs))
		var cur_p := Vector2(x, hall.vault_y(x, h))
		var cur_o: Vector2 = cur_p + hall.vault_inward(x, h) * RIB_DEPTH
		TerminalHall._face(s, Vector3(prev_o.x, prev_o.y, zn), Vector3(cur_o.x, cur_o.y, zn), Vector3(cur_o.x, cur_o.y, zf),
			Vector3(prev_o.x, prev_o.y, zf), Vector3(0, -1, 0), skin.steel_color.darkened(0.05), 0.0, MeshKit.PAT_TERMINAL_STEEL, 0.0)
		TerminalHall._face(s, Vector3(prev_p.x, prev_p.y, zn), Vector3(cur_p.x, cur_p.y, zn), Vector3(cur_o.x, cur_o.y, zn),
			Vector3(prev_o.x, prev_o.y, zn), Vector3(0, 0, 1), skin.steel_color.darkened(0.15), 0.0, MeshKit.PAT_TERMINAL_STEEL, 0.0)
		prev_p = cur_p
		prev_o = cur_o


# --- A broken pier ---------------------------------------------------------------------------------

func _stump(s: MeshLayer, side: int, face_x: float, dc: float, w: float) -> void:
	var sd: float = float(side)
	var k: int = MeshKit.hash_i(MeshKit.key(dc), side, 391)
	var heights: Vector2 = _heights(face_x)
	# About half the pier's height, the three columns of the break uneven.
	var half: float = heights.x * (0.42 + 0.14 * MeshKit.hash01(k, 1, 392))
	var depth: float = skin.pier_depth
	var steel: Color = skin.steel_color
	var zc: float = -dc
	var third: float = w / 3.0
	for i: int in 3:
		var zi: float = zc + (1.0 - float(i)) * third
		var hi: float = half + (MeshKit.hash01(k, i, 393) - 0.4) * 1.6
		var clad: float = hi - 0.4
		# The painted steel up to just under the break, then the concrete core, rough where it snapped.
		s.box(Vector3(face_x + sd * depth * 0.5, clad * 0.5, zi), Vector3(depth, clad, third), steel, 0.0, MeshKit.PAT_TERMINAL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_NZ, 0.0)
		var tilt := Basis.from_euler(Vector3((MeshKit.hash01(k, i, 394) - 0.5) * 0.2, 0.0, (MeshKit.hash01(k, i, 395) - 0.5) * 0.18))
		s.box_xform(Transform3D(tilt.scaled_local(Vector3(depth * 0.92, 0.55, third * 0.95)),
			Vector3(face_x + sd * depth * 0.5, clad + 0.22, zi)), skin.concrete_color, 0.0, MeshKit.PAT_TERMINAL_WALL,
			MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 2.0)
		# Rebar bristling out of the break, bent.
		for r: int in 3:
			var rx: float = face_x + sd * depth * (0.2 + 0.6 * MeshKit.hash01(k, i * 3 + r, 396))
			var rz: float = zi + (MeshKit.hash01(k, i * 3 + r, 397) - 0.5) * third * 0.7
			var length: float = 0.5 + 0.9 * MeshKit.hash01(k, i * 3 + r, 398)
			var lean := Basis.from_euler(Vector3((MeshKit.hash01(k, r, 399) - 0.5) * 0.9, 0.0, (MeshKit.hash01(k, i, 400) - 0.5) * 0.9))
			s.box_xform(Transform3D(lean.scaled_local(Vector3(0.03, length, 0.03)), Vector3(rx, clad + 0.4 + length * 0.4, rz)),
				skin.rust_color, 0.0, MeshKit.PAT_TERMINAL_STEEL, MeshKit.ALL_FACES, 2.0)
	# The plinth.
	s.box(Vector3(face_x + sd * (depth + FLARE) * 0.5, PLINTH * 0.5, zc), Vector3(depth + FLARE, PLINTH, w + FLARE * 2.0),
		skin.concrete_color, 0.0, MeshKit.PAT_TERMINAL_WALL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 2.0)
	# Rubble heaped at the foot beyond the kerb: chunks of cast concrete and steel plate.
	for i: int in 9:
		var rx: float = face_x + sd * (1.0 + 2.2 * MeshKit.hash01(k, i, 401))
		var rz: float = zc + (MeshKit.hash01(k, i, 402) - 0.5) * (w + 2.6)
		var sz := Vector3(0.3 + 0.7 * MeshKit.hash01(k, i, 403), 0.25 + 0.5 * MeshKit.hash01(k, i, 404), 0.3 + 0.7 * MeshKit.hash01(k, i, 405))
		var turn := Basis.from_euler(Vector3((MeshKit.hash01(k, i, 406) - 0.5) * 0.6, MeshKit.hash01(k, i, 407) * 3.0, (MeshKit.hash01(k, i, 408) - 0.5) * 0.5))
		var color: Color = skin.concrete_color.darkened(0.25 * MeshKit.hash01(k, i, 409)) if i % 3 != 2 else steel.darkened(0.1)
		s.box_xform(Transform3D(turn.scaled_local(sz), Vector3(rx, sz.y * 0.4, rz)), color, 0.0,
			MeshKit.PAT_TERMINAL_WALL if i % 3 != 2 else MeshKit.PAT_TERMINAL_STEEL, MeshKit.NO_BOTTOM, 2.0 if i % 3 != 2 else 0.0)
	_bush(s, side, face_x, zc, w, k)


## A four-cornered face wound to face `toward`, in a pattern from world position.
func _wall_quad(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, color: Color, pattern: int,
		param: float) -> void:
	TerminalHall._face(s, a, b, c, d, toward, color, 0.0, pattern, param)
