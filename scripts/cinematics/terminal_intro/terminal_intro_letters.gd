class_name TerminalIntroLetters
extends Node3D
## The Grand Terminal Station's sign (TerminalIntroStation; the owner's beats, October 21, 2026): "GRAND TERMINAL" across the
## head house, in big extruded letters (TerminalIntroText, the kit's solid material), of which
## - "GRAND" has fallen off: where it was, a dirty ghost of each letter (the clean stone it covered) and the bare bolts, and
##   the letters themselves in the rubble below, sooty and unlit (one leaning on the front, one half buried);
## - "TERMINAL" is starting to droop: each letter hangs on its mount a little crooked (tipped in its plane, slipped, its
##   foot swung out), and only a few still have light, an amber the Terminal's work lamps' (the Terminal's looser colour
##   rule, the owner, October 20, 2026), which flickers a little; now and then one sparks (sparks, a flash of its light).
## Reduced flashing (Settings): no flicker (the lit letters breathe slowly instead), fewer and slower sparks, no flash.
## Everything is worked out from the time (update()), so stepping or skipping shows the same. Station frame (x along the front,
## y up, z out). DESIGN-TBD (docs/questions/f2k.md): the droop, which letters are lit, the sparks.

const WORD_GAP: float = 0.9
const FALLEN_SEED: int = 8801
const GHOST := Color(0.088, 0.085, 0.08)
const SOOT_LETTER := Color(0.13, 0.12, 0.11)
const SOOT_FRONT := Color(0.26, 0.235, 0.21)
const RUST := Color(0.2, 0.12, 0.08)
const AMBER := Color(1.0, 0.6, 0.18)
## A spark's life (s), how many each burst has, its size (m) and the gravity it falls under.
const SPARK_LIFE: float = 0.7
const SPARKS_PER_BURST: int = 9
const SPARK_SIZE: float = 0.34
const SPARK_GRAVITY: float = 6.5
const MAX_SPARKS: int = 80
## The flicker's cell length (s): a lit letter is dimmed for whole cells, never faster than this.
const FLICKER_CELL: float = 0.3

var n: TerminalIntroTuning
var station: TerminalIntroStation
var solid: ShaderMaterial
## TERMINAL's letters (their pivots at the mounts), each with its own material and halo.
var letters: Array[Node3D] = []
var materials: Array[ShaderMaterial] = []
var halos: Array[ShaderMaterial] = []
var lit: Array[bool] = []
## The sparks: when each burst is (s) and from which letter; the multimesh drawing them.
var bursts: Array[Vector2] = []
var spark_mm: MultiMesh
var spark_node: MultiMeshInstance3D
## How many sparks are in flight now.
var live_sparks: int = 0
var _fallen: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()
## Where the letters' tops are (the sign's line), and the x of each of TERMINAL's letters.
var top_y: float = 0.0
var xs: Array[float] = []


func setup(p_station: TerminalIntroStation, p_numbers: TerminalIntroTuning) -> void:
	name = "Sign"
	station = p_station
	n = p_numbers
	solid = station.solid
	top_y = n.sign_y + n.letter_height * 0.5
	var layout: Dictionary = _layout()
	_ghost(layout)
	_terminal(layout)
	_fallen_letters()
	_bursts()
	_sparks()


## Where each letter of "GRAND TERMINAL" goes: x of its middle, all centred on the head house.
func _layout() -> Dictionary:
	var cap: float = n.letter_height
	var gap: float = n.letter_gap * cap
	var out := {"grand": [], "terminal": []}
	var x: float = 0.0
	var positions: Array[Dictionary] = []
	for word: String in ["GRAND", "TERMINAL"]:
		for ch: String in word:
			var adv: float = TerminalIntroText.advance(ch, cap)
			positions.append({"ch": ch, "word": word, "x": x + adv * 0.5})
			x += adv + gap
		x += cap * WORD_GAP - gap
	var total: float = x
	for p: Dictionary in positions:
		(out[String(p["word"]).to_lower()] as Array).append({"ch": p["ch"], "x": float(p["x"]) - total * 0.5})
	return out


## The dirty outline of each fallen letter on the band and its bare mounting bolts.
func _ghost(layout: Dictionary) -> void:
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(solid)
	for p: Dictionary in layout["grand"]:
		var flat: Dictionary = TerminalIntroText.line(String(p["ch"]), n.letter_height, GHOST, 0.0, MeshKit.PAT_DZ_CONCRETE)
		var l: MeshLayer = flat["layer"]
		var width: float = flat["width"]
		# The line's origin is its left edge at the baseline: put it where the letter's ink box was.
		s.append(l, Transform3D(Basis.IDENTITY, Vector3(float(p["x"]) - width * 0.5, top_y - n.letter_height, 0.09)))
		for bx: float in [-0.3, 0.3]:
			s.box(Vector3(float(p["x"]) + bx * width, top_y - 0.25, 0.12), Vector3(0.18, 0.18, 0.12), RUST * 1.5, 0.0, MeshKit.PAT_DZ_STEEL)
			s.box(Vector3(float(p["x"]) + bx * width, top_y - n.letter_height + 0.25, 0.12), Vector3(0.18, 0.18, 0.12), RUST * 1.5, 0.0,
				MeshKit.PAT_DZ_STEEL)
	var m: MeshInstance3D = batch.commit(station, "SignGhost")
	if m != null:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## TERMINAL's letters, hung crooked on their mounts, a few lit.
func _terminal(layout: Dictionary) -> void:
	var list: Array = layout["terminal"]
	for i: int in list.size():
		var p: Dictionary = list[i]
		var is_lit: bool = n.lit_letters.has(i)
		lit.append(is_lit)
		var body: Dictionary = TerminalIntroText.letter(String(p["ch"]), n.letter_height, n.letter_depth, SOOT_LETTER,
			AMBER if is_lit else SOOT_FRONT, n.letter_glow if is_lit else 0.0, MeshKit.PAT_DZ_STEEL)
		var mat: ShaderMaterial = TerminalIntroStation.own(solid)
		materials.append(mat)
		var pivot := Node3D.new()
		pivot.name = "Letter%d_%s" % [i, p["ch"]]
		var slip: float = n.droop_slip[i] if i < n.droop_slip.size() else 0.0
		pivot.position = Vector3(float(p["x"]), top_y - slip, n.letter_out)
		# Tipped in the plane of the front (about the z axis, + clockwise seen from the street) and its foot swung out.
		var tip: float = n.droop_angle[i] if i < n.droop_angle.size() else 0.0
		var swing: float = n.droop_out[i] if i < n.droop_out.size() else 0.0
		pivot.rotation_degrees = Vector3(-swing, 0.0, -tip)
		add_child(pivot)
		xs.append(float(p["x"]))
		var batch := MeshBatch.new()
		batch.layer(mat).append(body["layer"])
		var mi: MeshInstance3D = batch.commit(pivot, "Mesh")
		if mi != null:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		letters.append(pivot)
		# Its mount: a steel lug on the front, behind the letter's top.
		var lug := MeshBatch.new()
		lug.layer(solid).box(Vector3(float(p["x"]), top_y + 0.05, n.letter_out * 0.5), Vector3(0.22, 0.3, n.letter_out), RUST, 0.0,
			MeshKit.PAT_DZ_STEEL)
		var lm: MeshInstance3D = lug.commit(station, "Lug%d" % i)
		if lm != null:
			lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The halo of a lit letter.
		var halo_mat: ShaderMaterial = null
		if is_lit:
			halo_mat = TerminalIntroStation.own(station.glow)
			var hb := MeshBatch.new()
			var w: float = float(body["width"]) * 1.9 + 1.2
			var h: float = n.letter_height * 1.8
			hb.layer(halo_mat).rect(Vector3(-w * 0.5, -n.letter_height * 0.5 - h * 0.5, n.letter_depth + 0.15), Vector3(w, 0.0, 0.0),
				Vector3(0.0, h, 0.0), AMBER, 0.45, MeshKit.SHAPE_RADIAL, Vector2.ZERO, Vector2.ONE, -4.0)
			var hm: MeshInstance3D = hb.commit(pivot, "Halo")
			if hm != null:
				hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halos.append(halo_mat)


## GRAND's letters in the rubble: sooty and unlit, lying on the forecourt in front of the left wing, one leaning on the front, one
## half buried.
func _fallen_letters() -> void:
	_rng.seed = FALLEN_SEED
	var list: Array = _layout()["grand"]
	# Where each lies (x along the front, z out), its turn (degrees about y) and how it lies: 0 flat, 1 leaning on the front,
	# 2 half buried.
	var spots: Array[Vector4] = [Vector4(-13.5, 4.2, 25.0, 0.0), Vector4(-10.2, 2.6, -20.0, 2.0), Vector4(-7.6, 0.7, 0.0, 1.0),
		Vector4(-15.6, 1.6, 160.0, 1.0), Vector4(-11.5, 6.5, -60.0, 0.0)]
	for i: int in list.size():
		var p: Dictionary = list[i]
		var spot: Vector4 = spots[i % spots.size()]
		var body: Dictionary = TerminalIntroText.letter(String(p["ch"]), n.letter_height, n.letter_depth, SOOT_LETTER, SOOT_FRONT * 0.8,
			0.0, MeshKit.PAT_DZ_STEEL)
		var batch := MeshBatch.new()
		batch.layer(solid).append(body["layer"])
		var node := Node3D.new()
		node.name = "Fallen%d_%s" % [i, p["ch"]]
		add_child(node)
		var mi: MeshInstance3D = batch.commit(node, "Mesh")
		if mi != null:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_fallen.append(mi)
		var h: float = float(body["height"])
		match int(spot.w):
			1:
				# Leaning on the front, hung from its top at the wall, its foot out: tipped about 22 degrees.
				node.position = Vector3(spot.x, h * cos(deg_to_rad(22.0)) + 0.08, 0.5)
				node.rotation_degrees = Vector3(-22.0, 0.0, 0.0)
			2:
				# Half buried: lying face up, sunk into the pavement and rubble.
				node.position = Vector3(spot.x, -0.15, spot.y)
				node.rotation_degrees = Vector3(-90.0, spot.z, 8.0)
			_:
				# Lying flat, face up, a corner on a lump of rubble.
				node.position = Vector3(spot.x, n.letter_depth + 0.12, spot.y)
				node.rotation_degrees = Vector3(-90.0, spot.z, 6.0)


# --- The sparks ---------------------------------------------------------------------------------------------------

## When each lit letter sparks: the first soon after the sign comes into view, then about every `spark_every` s, each
## letter on its own beat.
func _bursts() -> void:
	bursts.clear()
	var list: Array[int] = []
	for i: int in lit.size():
		if lit[i]:
			list.append(i)
	for k: int in list.size():
		var i: int = list[k]
		var t: float = 0.9 + 1.3 * float(k) + MeshKit.hash01(i, 5, 31)
		var count: int = 0
		while t < n.duration:
			bursts.append(Vector2(t, float(i)))
			count += 1
			t += n.spark_every * (0.75 + 0.6 * MeshKit.hash01(i, count, 32))
	bursts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)


func _sparks() -> void:
	spark_mm = MultiMesh.new()
	spark_mm.transform_format = MultiMesh.TRANSFORM_3D
	spark_mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/cinematics/terminal_intro/terminal_intro_spark.gdshader") as Shader
	quad.material = mat
	spark_mm.mesh = quad
	spark_mm.instance_count = MAX_SPARKS
	spark_node = MultiMeshInstance3D.new()
	spark_node.name = "Sparks"
	spark_node.multimesh = spark_mm
	spark_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The sparks are placed in the world each step: cull by a box round the whole sign.
	spark_node.custom_aabb = AABB(Vector3(-40.0, -4.0, -40.0), Vector3(80.0, 40.0, 80.0))
	add_child(spark_node)
	update(0.0)


## A burst's n-th spark's place at `age` seconds in the letter's frame: out of the letter's lower edge, flung out and
## down, falling.
func _spark_at(burst: int, k: int, age: float) -> Vector3:
	var letter_index: int = int(bursts[burst].y)
	var p: Vector3 = letters[letter_index].position
	var seed_id: int = burst * 97 + k
	var v := Vector3(MeshKit.hash01(seed_id, 1, 41) - 0.5, MeshKit.hash01(seed_id, 2, 42) * 1.6 - 0.2, MeshKit.hash01(seed_id, 3, 43) * 0.8 + 0.2)
	v = v * Vector3(5.0, 3.0, 2.4)
	var start := Vector3(p.x + (MeshKit.hash01(seed_id, 4, 44) - 0.5) * 1.0, p.y - n.letter_height * (0.2 + 0.7 * MeshKit.hash01(seed_id, 5, 45)), p.z + n.letter_depth + 0.1)
	return start + v * age + Vector3(0.0, -0.5 * SPARK_GRAVITY * age * age, 0.0)


## The state at time `t`: each lit letter's brightness (flicker or breathing), its halo, and the sparks in flight.
func update(t: float) -> void:
	var soft: bool = Settings.flashing_reduced
	for i: int in letters.size():
		if not lit[i]:
			continue
		var k: float = brightness(i, t, soft)
		materials[i].set_shader_parameter(&"state_glow", k)
		if halos[i] != null:
			halos[i].set_shader_parameter(&"state_glow", k * 0.9)
	# The sparks.
	var used: int = 0
	for b: int in bursts.size():
		var age: float = t - bursts[b].x
		if age < 0.0 or age > SPARK_LIFE * (1.6 if soft else 1.0):
			continue
		if soft and b % 3 != 0:
			continue
		var count: int = SPARKS_PER_BURST / 2 if soft else SPARKS_PER_BURST
		var life: float = SPARK_LIFE * (1.6 if soft else 1.0)
		var slow: float = 0.6 if soft else 1.0
		for s: int in count:
			if used >= MAX_SPARKS:
				break
			var local: Vector3 = _spark_at(b, s, age * slow)
			var fade: float = 1.0 - age / life
			var xf := Transform3D(Basis.from_scale(Vector3.ONE * SPARK_SIZE * (0.6 + 0.6 * fade)), local)
			spark_mm.set_instance_transform(used, xf)
			spark_mm.set_instance_custom_data(used, Color(fade * fade * (0.5 if soft else 1.0), 0.0, 0.0, 0.0))
			used += 1
	for i: int in range(used, MAX_SPARKS):
		spark_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	live_sparks = used


## A lit letter's brightness at `t` (1 steady): flickering (dimmed for whole cells, now and then) with a flash when it
## sparks; with Reduced flashing breathing slowly instead, no flash.
func brightness(i: int, t: float, soft: bool) -> float:
	if i >= lit.size() or not lit[i]:
		return 0.0
	if soft:
		return 0.78 + 0.14 * sin(TAU * 0.2 * t + float(i)) + 0.1 * swell(i, t)
	var cell: int = int(floor(t / FLICKER_CELL + float(i) * 3.1))
	var dip: float = 0.28 + 0.1 * float(i % 3)
	var k: float = 1.0
	if MeshKit.hash01(cell, i, 51) < 0.1 + 0.06 * float(i % 4):
		k = dip
	return k * (0.94 + 0.06 * sin(t * 7.0 + float(i))) + 1.6 * pulse(i, t, 0.14)


## A slow swell for a burst of letter `i` at `t` (0 to 1 and back over about 2.5 s, smooth: with Reduced flashing).
func swell(i: int, t: float) -> float:
	var best: float = 0.0
	for b: Vector2 in bursts:
		if int(b.y) == i and t >= b.x and t < b.x + 2.5:
			best = maxf(best, sin(PI * (t - b.x) / 2.5))
	return best


## How much a burst of letter `i` lights it at `t` (1 at the burst, dying over `over` seconds).
func pulse(i: int, t: float, over: float) -> float:
	var best: float = 0.0
	for b: Vector2 in bursts:
		if int(b.y) == i and t >= b.x and t < b.x + over * 3.0:
			best = maxf(best, exp(-(t - b.x) / over))
	return best


## Draw calls its meshes add now: tests.
func draw_calls() -> int:
	var calls: int = 0
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			calls += m.mesh.get_surface_count()
	if spark_node != null and spark_node.is_visible_in_tree():
		calls += 1
	return calls
