class_name RubbleBurst
extends MultiMeshInstance3D
## One burst of broken pieces (RunEffects.rubble; task H5: a zone doodad the dash smashes, GDD §3, owner,
## October 8, 2026; task H7a's dash walls may use it too): solid chunks in the broken thing's own colours,
## flung out of its box along the runner's way and out to the sides, tumbling, falling, skidding off the
## floor and shrinking away. It reads as something solid breaking apart: not an explosion (no fire, no
## flash) and not a hazard (nothing glows, so no hazard colour can show). The chunks are the kit's lit
## surfaces (MeshKit.solid(), their colours' alpha 0), so they light and dim like the scenery they came
## from, and nothing in it flickers: Reduced flashing leaves it as it is.
## One draw call: a MultiMesh of the kit's box, moved on the CPU while it plays (play(), then _process),
## hidden in between. Made once per pool slot with its material on, so ShaderWarmup draws it at the
## level's load like every hidden effect (its first burst never compiles a shader mid-run). Visual only.

## The most pieces in one burst (a large doodad's; smaller ones fling fewer, by their volume).
const MAX_PIECES: int = 28
## The fewest pieces in one burst.
const MIN_PIECES: int = 10
## Pieces per cubic metre of the broken box (a small doodad, 4.7 m³, gives the minimum; a large one,
## 34 m³, about 26).
const PIECES_PER_M3: float = 0.75
## Downward acceleration of the pieces (m/s², a little heavier than the real thing at this scale).
const GRAVITY: float = 22.0
## A piece landing on the floor keeps this much of its speed (bouncing up, skidding along).
const BOUNCE: float = 0.3
const SKID: float = 0.55

## The pieces are still flying.
var active: bool = false
## The pieces of the burst playing now (or last played).
var count: int = 0

var _t: float = 0.0
var _life: float = 0.85
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _size := PackedVector3Array()
var _axis := PackedVector3Array()
var _spin := PackedFloat32Array()
var _ends := PackedFloat32Array()
var _basis: Array[Basis] = []


func _init() -> void:
	name = "Rubble"
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = MeshKit.solid()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = piece_mesh()
	mm.instance_count = MAX_PIECES
	mm.visible_instance_count = 0
	multimesh = mm
	visible = false
	set_process(false)


## The pieces' mesh: the kit's unit box, white and lit (COLOR.a 0: no glow), plain (pattern 0); each
## piece's own colour multiplies it (MultiMesh instance colours).
static func piece_mesh() -> ArrayMesh:
	var batch := MeshBatch.new()
	batch.layer(null).box(Vector3.ZERO, Vector3.ONE, Color.WHITE, 0.0, MeshKit.PAT_PLAIN)
	return batch.to_mesh()


## Flings the pieces of `box` (world space): `colors` (sRGB, lit; a plain grey if empty) one after another,
## `push` the velocity they carry on average (the runner's, scaled by `carry`), `spread` and `lift` the
## sideways and upward speeds they fly out at (m/s), `piece` a large piece's size (m) and `life` how long
## the burst lasts (s). `look_seed` varies it (the same seed, the same burst).
func play(box: AABB, colors: PackedColorArray, push: Vector3, carry: float, spread: float, lift: float, piece: float,
		life: float, look_seed: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var palette: PackedColorArray = colors if not colors.is_empty() else PackedColorArray([Color(0.4, 0.4, 0.42)])
	var volume: float = box.size.x * box.size.y * box.size.z
	count = clampi(roundi(volume * PIECES_PER_M3), MIN_PIECES, MAX_PIECES)
	_life = maxf(life, 0.1)
	_t = 0.0
	_pos.resize(count)
	_vel.resize(count)
	_size.resize(count)
	_axis.resize(count)
	_spin.resize(count)
	_ends.resize(count)
	_basis.resize(count)
	var centre: Vector3 = box.get_center()
	var big: float = minf(piece, minf(box.size.x, box.size.y) * 0.45)
	for i: int in count:
		# A third of them big chunks, the rest small ones; from anywhere in the box, mostly its upper part.
		var large: bool = i % 3 == 0
		var s: float = big * (rng.randf_range(0.65, 1.0) if large else rng.randf_range(0.25, 0.5))
		_size[i] = Vector3(s * rng.randf_range(0.7, 1.35), s * rng.randf_range(0.6, 1.2), s * rng.randf_range(0.7, 1.35))
		var p := Vector3(rng.randf_range(-0.42, 0.42) * box.size.x, rng.randf_range(0.1, 0.95) * box.size.y,
			rng.randf_range(-0.45, 0.45) * box.size.z)
		_pos[i] = box.position + Vector3(box.size.x * 0.5, 0.0, box.size.z * 0.5) + p
		# Out to its own side of the box's middle (either way at the middle), up, and on along the way.
		var out: float = signf(_pos[i].x - centre.x) if absf(_pos[i].x - centre.x) > 0.05 else (1.0 if i % 2 == 0 else -1.0)
		_vel[i] = push * carry * rng.randf_range(0.55, 1.35) \
			+ Vector3(out * spread * rng.randf_range(0.35, 1.25), lift * rng.randf_range(0.45, 1.3), 0.0)
		var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		_axis[i] = axis.normalized() if axis.length() > 0.1 else Vector3.UP
		_spin[i] = rng.randf_range(6.0, 16.0) * (1.0 if large else 1.5)
		_ends[i] = _life * rng.randf_range(0.7, 1.0)
		_basis[i] = Basis(_axis[i], rng.randf_range(0.0, TAU))
		var c: Color = palette[i % palette.size()]
		var shade: float = rng.randf_range(0.85, 1.08)
		multimesh.set_instance_color(i, Color(c.r * shade, c.g * shade, c.b * shade, 0.0))
	multimesh.visible_instance_count = count
	# The ground the pieces can reach in their life, so the burst is never culled while it plays.
	var reach: float = push.length() * carry * 1.4 * _life + 2.0
	custom_aabb = AABB(box.position - Vector3(spread * _life + 2.0, 1.0, reach), box.size + Vector3(
		2.0 * (spread * _life + 2.0), lift * _life + 4.0, 2.0 * reach))
	global_transform = Transform3D.IDENTITY
	active = true
	visible = true
	set_process(true)
	_place(0.0)


## Stops the burst at once and hides it (a pool slot taken back, a level's end).
func stop() -> void:
	active = false
	visible = false
	set_process(false)
	multimesh.visible_instance_count = 0


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		stop()
		return
	_place(delta)


## Moves every piece on by `delta` seconds and sets its transform: flying, tumbling, landing on the floor
## (y 0) and skidding, and shrinking away over the last quarter of its life.
func _place(delta: float) -> void:
	for i: int in count:
		var v: Vector3 = _vel[i]
		v.y -= GRAVITY * delta
		var p: Vector3 = _pos[i] + v * delta
		var half_h: float = _size[i].y * 0.5
		if p.y < half_h and v.y < 0.0:
			p.y = half_h
			v = Vector3(v.x * SKID, -v.y * BOUNCE, v.z * SKID)
			_spin[i] *= 0.6
		_pos[i] = p
		_vel[i] = v
		_basis[i] = Basis(_axis[i], _spin[i] * delta) * _basis[i]
		var k: float = 1.0 - smoothstep(_ends[i] * 0.75, _ends[i], _t)
		multimesh.set_instance_transform(i, Transform3D(_basis[i] * Basis.from_scale(_size[i] * k), p))
