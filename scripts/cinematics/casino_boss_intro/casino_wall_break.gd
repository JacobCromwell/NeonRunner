class_name CasinoWallBreak
extends Node3D
## The stretch of the casino hall's back wall that The House bursts through (CasinoHall; the owner: "the wall to the
## left starts to tremble ... The wall all of a sudden collapses into rubble, and standing in the hole is the casino
## boss"). Until it goes it is wall like the rest (the same wainscot, brass rail, plum paint and picture rail, flush
## with the wall either side, so nothing gives it away), built of blocks in running bond:
## - trembling (from tremble_at): the blocks shiver more and more, cracks spread over its face, grit trickles from
##   them and dust puffs out at its foot;
## - bursting (at burst_at): the blocks fly out into the hall from the middle outward, tumbling, and come down onto
##   the carpet, sliding to rest flat on a heap of rubble that rises at the hole's foot, a cloud of plaster dust
##   billowing out and settling (casino_dust.gdshader).
## Worked out in closed form from the cinematic's clock (update()), so stepping or skipping shows the same. The blocks,
## the grit, the cracks and the dust are a few MultiMeshes (a draw each).
## Its space: the hall's (CasinoHall: track space with z flipped); the maths below is in track space (z into the
## wall), turned into the hall's as it's placed.

## The rows' tops (metres up): the wainscot, two rows up to the picture rail, then rows of about ROW up to the hole's top.
const ROW: float = 1.05
const BLOCK: float = 1.25
## Gravity for the falling blocks (m/s², a touch over the real thing at the characters' scale: weightier).
const GRAVITY: float = 13.0
## The heap at the hole's foot: its height at the wall and how far out it spreads.
const HEAP_HEIGHT: float = 1.4
const HEAP_REACH: float = 5.0
const PLASTER := Color(0.44, 0.38, 0.34)
const CRACK := Color(0.07, 0.04, 0.05)

var hall: CasinoHall
var blocks: Array[Dictionary] = []
var _mm: Dictionary = {}
var grit: MultiMesh
var cracks: MultiMesh
var dust: MultiMesh
var heap: MeshInstance3D
var reveals: MeshInstance3D
var _grit: Array[Dictionary] = []
var _cracks: Array[Dictionary] = []
var _puffs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(solid: Material, p_hall: CasinoHall) -> void:
	name = "WallBreak"
	hall = p_hall
	_rng.seed = 4040
	var x0: float = hall.hole_x - hall.hole_width * 0.5
	var x1: float = hall.hole_x + hall.hole_width * 0.5
	var z: float = CasinoHall.DEPTH + CasinoHall.WALL_THICK * 0.5
	# The rows: [bottom, top, colour].
	var rows: Array = [[0.0, CasinoHall.WAINSCOT, CasinoHall.WOOD]]
	var mid_rows: int = 2
	for i: int in mid_rows:
		var lo: float = lerpf(CasinoHall.WAINSCOT, CasinoHall.RAIL, float(i) / float(mid_rows))
		var hi: float = lerpf(CasinoHall.WAINSCOT, CasinoHall.RAIL, float(i + 1) / float(mid_rows))
		rows.append([lo, hi, CasinoHall.WALL])
	var top: float = hall.hole_height
	var upper: int = maxi(1, int(round((top - CasinoHall.RAIL) / ROW)))
	for i: int in upper:
		rows.append([lerpf(CasinoHall.RAIL, top, float(i) / float(upper)), lerpf(CasinoHall.RAIL, top, float(i + 1) / float(upper)),
			CasinoHall.WALL])
	for r: int in rows.size():
		var lo: float = rows[r][0]
		var hi: float = rows[r][1]
		var color: Color = rows[r][2]
		var x: float = x0
		var first: float = BLOCK * (0.5 if r % 2 == 1 else 1.0)
		var w: float = first
		while x < x1 - 0.01:
			var w_here: float = minf(w * _rng.randf_range(0.85, 1.15), x1 - x)
			if x1 - (x + w_here) < 0.5:
				w_here = x1 - x
			_add_block(Vector3(x + w_here * 0.5, (lo + hi) * 0.5, z), Vector3(w_here, hi - lo, CasinoHall.WALL_THICK), color)
			x += w_here
			w = BLOCK
	# The brass rail and the picture rail across it, in pieces that fall with the blocks.
	for rail: Array in [[CasinoHall.WAINSCOT, 0.12, CasinoHall.BRASS], [CasinoHall.RAIL, 0.08, CasinoHall.BRASS_DARK]]:
		var pieces: int = 4
		for i: int in pieces:
			var a: float = lerpf(x0, x1, float(i) / float(pieces))
			var b: float = lerpf(x0, x1, float(i + 1) / float(pieces))
			_add_block(Vector3((a + b) * 0.5, rail[0], z - 0.06), Vector3(b - a, rail[1], CasinoHall.WALL_THICK + 0.12), rail[2])
	_plan_blocks()
	for color: Color in _mm:
		var entry: Dictionary = _mm[color]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var b := MeshBatch.new()
		var pattern: int = MeshKit.PAT_CASINO_BRASS if color == CasinoHall.BRASS or color == CasinoHall.BRASS_DARK else MeshKit.PAT_PLAIN
		var layer: MeshLayer = b.layer(solid)
		# Its face to the hall in the wall's own colour; the rest broken plaster (brass is brass through).
		var inside: Color = color if pattern == MeshKit.PAT_CASINO_BRASS else PLASTER
		layer.box(Vector3.ZERO, Vector3.ONE, color, 0.0, pattern, MeshKit.FACE_PZ, 0.6)
		layer.box(Vector3.ZERO, Vector3.ONE, inside, 0.0, pattern, MeshKit.ALL_FACES & ~MeshKit.FACE_PZ, 0.6)
		mm.mesh = b.to_mesh()
		mm.instance_count = (entry["blocks"] as Array).size()
		entry["mm"] = mm
		_add_multimesh(mm, "Blocks")
	_build_grit(solid)
	_build_cracks(solid)
	_build_dust()
	_build_heap(solid)
	_build_reveals(solid)


## The hole's cut edges (rough plaster), seen once it's open.
func _build_reveals(solid: Material) -> void:
	var b := MeshBatch.new()
	var s: MeshLayer = b.layer(solid)
	var z: float = CasinoHall.DEPTH + CasinoHall.WALL_THICK * 0.5
	for side: float in [-1.0, 1.0]:
		s.box(CasinoHall.L(Vector3(hall.hole_x + side * hall.hole_width * 0.5, hall.hole_height * 0.5, z)),
			Vector3(0.06, hall.hole_height, CasinoHall.WALL_THICK - 0.02), PLASTER.darkened(0.1), 0.0, MeshKit.PAT_PLAIN)
	s.box(CasinoHall.L(Vector3(hall.hole_x, hall.hole_height, z)), Vector3(hall.hole_width, 0.06, CasinoHall.WALL_THICK - 0.02),
		PLASTER.darkened(0.1), 0.0, MeshKit.PAT_PLAIN)
	reveals = MeshBatch.add_instance(self, b.to_mesh(), "Reveals")
	reveals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_block(center: Vector3, size: Vector3, color: Color) -> void:
	var i: int = blocks.size()
	var block := {"c0": center, "size": size, "color": color, "index": i}
	blocks.append(block)
	if not _mm.has(color):
		_mm[color] = {"blocks": []}
	(_mm[color]["blocks"] as Array).append(i)


func _add_multimesh(mm: MultiMesh, node_name: String) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return inst


## Each block's flight: when it goes (from the middle outward), how fast and which way, how it tumbles, where it lands
## and lies.
func _plan_blocks() -> void:
	var burst := Vector3(hall.hole_x, hall.hole_height * 0.45, CasinoHall.DEPTH + 2.0)
	for b: Dictionary in blocks:
		var c0: Vector3 = b["c0"]
		var size: Vector3 = b["size"]
		var off: Vector3 = c0 - burst
		var delay: float = Vector2(off.x, off.y).length() * 0.018 + _rng.randf_range(0.0, 0.08)
		var spread: float = clampf(off.x / maxf(hall.hole_width * 0.5, 1.0), -1.0, 1.0)
		var v := Vector3(spread * _rng.randf_range(0.6, 2.0), _rng.randf_range(0.3, 2.2) - c0.y * 0.06,
			-_rng.randf_range(1.6, 4.2) * (1.15 - c0.y / maxf(hall.hole_height, 1.0) * 0.4) - (1.8 if c0.y < 2.0 else 0.0))
		var axis := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.6, 0.6)).normalized()
		if axis.length_squared() < 0.01:
			axis = Vector3.RIGHT
		var spin: float = _rng.randf_range(2.0, 6.0)
		# Where it comes down: on the carpet or the heap, lying flat (its thinnest side down).
		var thin: float = minf(size.x, minf(size.y, size.z))
		var g: float = GRAVITY
		# A first guess of where it lands, for the heap's height there.
		var t_guess: float = (v.y + sqrt(maxf(v.y * v.y + 2.0 * g * c0.y, 0.0))) / g
		var land_xz := Vector2(c0.x + v.x * t_guess, c0.z + v.z * t_guess)
		var rest: float = thin * 0.5 + heap_height(land_xz)
		var drop: float = c0.y - rest
		var t_land: float = (v.y + sqrt(maxf(v.y * v.y + 2.0 * g * drop, 0.0))) / g
		b["delay"] = delay
		b["v"] = v
		b["axis"] = axis
		b["spin"] = spin
		b["t_land"] = t_land
		b["rest"] = rest
		b["yaw"] = _rng.randf_range(-0.6, 0.6)
		# Lying flat: its face to the sky, tipped toward the hall (about x), whichever way it was tumbling.
		# Some land face up (the wall's paint), some face down (broken plaster).
		b["flat"] = Basis(Vector3.UP, b["yaw"]) * Basis(Vector3.RIGHT, PI * 0.5 if _rng.randf() < 0.45 else -PI * 0.5)
		# Broken: once it bursts it's a little smaller and less square than the block it was.
		b["broken"] = Vector3(_rng.randf_range(0.7, 0.95), _rng.randf_range(0.7, 0.95), _rng.randf_range(0.8, 1.0))


## The rubble heap's height at a track-space point (x, z) on the floor.
func heap_height(xz: Vector2) -> float:
	var out: float = CasinoHall.DEPTH - xz.y
	var across: float = absf(xz.x - hall.hole_x) / maxf(hall.hole_width * 0.55, 1.0)
	if out < -0.5 or across > 1.0:
		return 0.0
	return maxf(0.0, HEAP_HEIGHT * (1.0 - clampf(out / HEAP_REACH, 0.0, 1.0)) * (1.0 - across * across))


## A block's transform at time `t` in track space (its size in the basis).
func block_transform(b: Dictionary, t: float, n: CasinoBossIntroTuning) -> Transform3D:
	var c0: Vector3 = b["c0"]
	var size: Vector3 = b["size"]
	var i: int = b["index"]
	var sized := Basis.from_scale(size)
	var tau: float = t - n.burst_at - float(b["delay"])
	if tau <= 0.0:
		# Trembling: a shiver growing toward the burst.
		var amp: float = shiver(t, n)
		var j := Vector3(sin(t * 47.0 + float(i) * 1.7), sin(t * 53.0 + float(i) * 2.9) * 0.6, 0.0) * amp
		var rot := Basis(Vector3.BACK, sin(t * 39.0 + float(i)) * amp * 0.25)
		return Transform3D(rot * sized, c0 + j)
	var v: Vector3 = b["v"]
	sized = Basis.from_scale(size * (b["broken"] as Vector3))
	var t_land: float = b["t_land"]
	var air: float = minf(tau, t_land)
	var p: Vector3 = c0 + v * air + Vector3(0.0, -0.5 * GRAVITY * air * air, 0.0)
	var spun := Basis(b["axis"] as Vector3, float(b["spin"]) * air)
	if tau <= t_land:
		return Transform3D(spun * sized, p)
	# Down: sliding to rest along the floor, settling flat.
	var after: float = tau - t_land
	var slide: float = (1.0 - exp(-after * 5.0)) / 5.0
	p += Vector3(v.x, 0.0, v.z) * slide * 0.6
	p.y = float(b["rest"])
	var settle: float = smoothstep(0.0, 0.3, after)
	var basis: Basis = spun.slerp(b["flat"] as Basis, settle)
	return Transform3D(basis * sized, p)


## How hard the wall shivers at time `t` (metres).
static func shiver(t: float, n: CasinoBossIntroTuning) -> float:
	if t < n.tremble_at or t > n.burst_at:
		return 0.0
	var k: float = (t - n.tremble_at) / maxf(n.burst_at - n.tremble_at, 0.05)
	return lerpf(0.004, 0.035, k * k)


## Turns a track-space transform into the hall's (z flipped on both sides: the reflection keeps the shape's handedness).
static func _to_hall(xf: Transform3D) -> Transform3D:
	var f := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK * -1.0)
	return Transform3D(f * xf.basis * f, CasinoHall.L(xf.origin))


# --- Grit, cracks, dust and the heap -----------------------------------------------------------------

func _build_grit(solid: Material) -> void:
	var b := MeshBatch.new()
	b.layer(solid).box(Vector3.ZERO, Vector3.ONE, PLASTER, 0.0, MeshKit.PAT_PLAIN)
	grit = MultiMesh.new()
	grit.transform_format = MultiMesh.TRANSFORM_3D
	grit.mesh = b.to_mesh()
	var x0: float = hall.hole_x - hall.hole_width * 0.5
	var x1: float = hall.hole_x + hall.hole_width * 0.5
	# Trickling grit while it trembles (falling from the cracks), and a spray of rubble as it bursts.
	for i: int in 40:
		_grit.append({"t0": _rng.randf_range(0.2, 1.0), "trickle": true,
			"p0": Vector3(_rng.randf_range(x0 + 0.5, x1 - 0.5), _rng.randf_range(2.0, hall.hole_height - 0.5), CasinoHall.DEPTH - 0.05),
			"v": Vector3(_rng.randf_range(-0.2, 0.2), 0.0, -_rng.randf_range(0.1, 0.6)), "size": _rng.randf_range(0.04, 0.1),
			"spin": Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * 6.0})
	for i: int in 110:
		var p0 := Vector3(_rng.randf_range(x0, x1), _rng.randf_range(0.2, hall.hole_height), CasinoHall.DEPTH - 0.1)
		_grit.append({"t0": _rng.randf_range(0.0, 0.25), "trickle": false, "p0": p0,
			"v": Vector3((p0.x - hall.hole_x) * _rng.randf_range(0.2, 0.6), _rng.randf_range(0.0, 4.0), -_rng.randf_range(4.0, 11.0)),
			"size": _rng.randf_range(0.08, 0.3), "spin": Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * 9.0})
	grit.instance_count = _grit.size()
	_add_multimesh(grit, "Grit")


func _build_cracks(solid: Material) -> void:
	var b := MeshBatch.new()
	b.layer(solid).box(Vector3.ZERO, Vector3.ONE, CRACK, 0.0, MeshKit.PAT_PLAIN)
	cracks = MultiMesh.new()
	cracks.transform_format = MultiMesh.TRANSFORM_3D
	cracks.mesh = b.to_mesh()
	# Branching lines spreading from a few points across the face, each appearing a little after the one before.
	var seeds: Array[Vector3] = [Vector3(hall.hole_x - 1.0, 3.5, 0.0), Vector3(hall.hole_x + 2.5, 6.5, 0.0),
		Vector3(hall.hole_x - 3.5, 7.8, 0.0), Vector3(hall.hole_x + 0.5, 9.5, 0.0), Vector3(hall.hole_x - 0.3, 1.2, 0.0)]
	for s: int in seeds.size():
		var p: Vector3 = seeds[s]
		for branch: int in 3:
			var dir: float = _rng.randf_range(0.0, TAU)
			var q: Vector3 = p
			for seg: int in 6:
				dir += _rng.randf_range(-0.7, 0.7)
				var len: float = _rng.randf_range(0.35, 0.8)
				var nq: Vector3 = q + Vector3(cos(dir), sin(dir), 0.0) * len
				nq.x = clampf(nq.x, hall.hole_x - hall.hole_width * 0.5 + 0.2, hall.hole_x + hall.hole_width * 0.5 - 0.2)
				nq.y = clampf(nq.y, 0.3, hall.hole_height - 0.2)
				_cracks.append({"a": q, "b": nq, "k": (float(s) * 0.12 + float(seg) * 0.13 + float(branch) * 0.04)})
				q = nq
	cracks.instance_count = _cracks.size()
	_add_multimesh(cracks, "Cracks")


func _build_dust() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/cinematics/casino_boss_intro/casino_dust.gdshader")
	quad.material = mat
	dust = MultiMesh.new()
	dust.transform_format = MultiMesh.TRANSFORM_3D
	dust.use_custom_data = true
	dust.mesh = quad
	var x0: float = hall.hole_x - hall.hole_width * 0.5
	var x1: float = hall.hole_x + hall.hole_width * 0.5
	# Puffs at the wall's foot while it trembles; the burst's cloud.
	for i: int in 10:
		_puffs.append({"t0": _rng.randf_range(0.3, 1.0), "tremble": true,
			"p0": Vector3(_rng.randf_range(x0, x1), _rng.randf_range(0.2, 0.6), CasinoHall.DEPTH - 0.4),
			"v": Vector3(_rng.randf_range(-0.2, 0.2), 0.25, -0.4), "s0": 0.6, "grow": 0.8, "life": 1.6, "a": 0.45})
	for i: int in 46:
		var p0 := Vector3(_rng.randf_range(x0, x1), _rng.randf_range(0.5, hall.hole_height), CasinoHall.DEPTH - 0.6)
		_puffs.append({"t0": _rng.randf_range(0.0, 0.5), "tremble": false, "p0": p0,
			"v": Vector3((p0.x - hall.hole_x) * 0.25, _rng.randf_range(-0.3, 0.8), -_rng.randf_range(2.0, 5.0)),
			"s0": _rng.randf_range(1.5, 3.0), "grow": _rng.randf_range(1.2, 2.4), "life": _rng.randf_range(3.0, 4.6), "a": _rng.randf_range(0.5, 0.8)})
	dust.instance_count = _puffs.size()
	_add_multimesh(dust, "Dust")


func _build_heap(solid: Material) -> void:
	var b := MeshBatch.new()
	var s: MeshLayer = b.layer(solid)
	var colors: Array[Color] = [PLASTER, PLASTER.darkened(0.2), CasinoHall.WALL, CasinoHall.WOOD, PLASTER.lightened(0.1)]
	for i: int in 70:
		var out: float = _rng.randf_range(0.0, HEAP_REACH * 0.9)
		var across: float = _rng.randf_range(-1.0, 1.0) * (hall.hole_width * 0.5)
		var xz := Vector2(hall.hole_x + across, CasinoHall.DEPTH - out)
		var h: float = heap_height(xz)
		var size := Vector3(_rng.randf_range(0.3, 1.2), _rng.randf_range(0.2, 0.6), _rng.randf_range(0.3, 1.0))
		var xf := Transform3D(Basis(Vector3(_rng.randf(), _rng.randf(), _rng.randf()).normalized(), _rng.randf_range(0.0, 1.0)) * Basis.from_scale(size),
			CasinoHall.L(Vector3(xz.x, maxf(h - size.y * 0.3, size.y * 0.3), xz.y)))
		s.box_xform(xf, colors[_rng.randi() % colors.size()], 0.0, MeshKit.PAT_PLAIN)
	heap = MeshBatch.add_instance(self, b.to_mesh(), "Heap")
	heap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- On the clock --------------------------------------------------------------------------------------

func update(t: float, n: CasinoBossIntroTuning) -> void:
	for color: Color in _mm:
		var entry: Dictionary = _mm[color]
		var mm: MultiMesh = entry["mm"]
		var list: Array = entry["blocks"]
		for k: int in list.size():
			mm.set_instance_transform(k, _to_hall(block_transform(blocks[list[k]], t, n)))
	_update_grit(t, n)
	_update_cracks(t, n)
	_update_dust(t, n)
	# The heap rises at the hole's foot as the blocks come down.
	var rise: float = smoothstep(n.burst_at + 0.25, n.burst_at + 1.3, t)
	heap.visible = rise > 0.0
	reveals.visible = t >= n.burst_at
	heap.scale = Vector3(1.0, maxf(rise, 0.001), 1.0)


func _update_grit(t: float, n: CasinoBossIntroTuning) -> void:
	var shown: int = 0
	for i: int in _grit.size():
		var g: Dictionary = _grit[i]
		var start: float = (n.tremble_at + float(g["t0"]) * (n.burst_at - n.tremble_at)) if bool(g["trickle"]) else n.burst_at + float(g["t0"])
		var tau: float = t - start
		var xf := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), CasinoHall.L(g["p0"]))
		if tau > 0.0 and tau < 3.0:
			var v: Vector3 = g["v"]
			var p: Vector3 = (g["p0"] as Vector3) + v * tau + Vector3(0.0, -0.5 * GRAVITY * tau * tau, 0.0)
			var size: float = g["size"]
			if p.y < size * 0.5:
				p.y = size * 0.5
			var spin: Vector3 = (g["spin"] as Vector3) * minf(tau, 1.0)
			xf = Transform3D(Basis.from_euler(spin) * Basis.from_scale(Vector3.ONE * size), CasinoHall.L(p))
			shown += 1
		grit.set_instance_transform(i, xf)


func _update_cracks(t: float, n: CasinoBossIntroTuning) -> void:
	var k: float = clampf((t - n.tremble_at) / maxf(n.burst_at - n.tremble_at, 0.05), 0.0, 1.0)
	for i: int in _cracks.size():
		var c: Dictionary = _cracks[i]
		var a: Vector3 = c["a"]
		var b: Vector3 = c["b"]
		# Each segment grows from its start once the crack reaches it; gone with the wall.
		var grow: float = clampf((k * 1.3 - float(c["k"])) / 0.15, 0.0, 1.0)
		if t >= n.burst_at or grow <= 0.0:
			cracks.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), CasinoHall.L(a)))
			continue
		var end: Vector3 = a.lerp(b, grow)
		var along: Vector3 = end - a
		var angle: float = atan2(along.y, along.x)
		var z: float = CasinoHall.DEPTH - 0.012
		var mid := Vector3((a.x + end.x) * 0.5, (a.y + end.y) * 0.5, z)
		var xf := Transform3D(Basis(Vector3.BACK, -angle) * Basis.from_scale(Vector3(maxf(along.length(), 0.01), 0.035, 0.02)), CasinoHall.L(mid))
		# Ride with the block under it (the shiver), roughly.
		var j: float = shiver(t, n)
		xf.origin += Vector3(sin(t * 47.0 + float(i)), 0.0, 0.0) * j * 0.5
		cracks.set_instance_transform(i, xf)


func _update_dust(t: float, n: CasinoBossIntroTuning) -> void:
	var live: int = 0
	for i: int in _puffs.size():
		var p: Dictionary = _puffs[i]
		var start: float = (n.tremble_at + float(p["t0"]) * (n.burst_at - n.tremble_at)) if bool(p["tremble"]) else n.burst_at + float(p["t0"])
		var tau: float = t - start
		var life: float = p["life"]
		var alpha: float = 0.0
		var xf := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), CasinoHall.L(p["p0"]))
		if tau > 0.0 and tau < life:
			var v: Vector3 = p["v"]
			# The cloud slows as it spreads, and drifts up a little.
			var travel: float = (1.0 - exp(-tau * 1.2)) / 1.2
			var pos: Vector3 = (p["p0"] as Vector3) + v * travel + Vector3(0.0, 0.25 * tau, 0.0)
			pos.y = maxf(pos.y, 0.3)
			var size: float = float(p["s0"]) + float(p["grow"]) * tau
			xf = Transform3D(Basis.from_scale(Vector3.ONE * size), CasinoHall.L(pos))
			alpha = float(p["a"]) * smoothstep(0.0, 0.2, tau) * (1.0 - smoothstep(life * 0.45, life, tau))
			live += 1
		dust.set_instance_transform(i, xf)
		dust.set_instance_custom_data(i, Color(alpha, float(i % 7) / 7.0, 0.0, 0.0))
	dust.visible_instance_count = -1 if live > 0 else 0
