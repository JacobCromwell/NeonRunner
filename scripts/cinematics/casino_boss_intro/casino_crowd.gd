class_name CasinoCrowd
extends Node3D
## The casino's crowd in the Casino boss intro (CasinoBossIntro; the owner: "We need lots of characters there,
## drinking, laughing, gambling, or manning the tables ... it is a lively establishment"): some sixty people about the
## hall, at its tables (players and dealers), round its holographic games, at the slot machines, along the bar and
## standing about in groups with their drinks. They are the patrons of the owner's reference (CasinoPeople's looks),
## some repainted (a navy or charcoal suit, a brown jacket, a sapphire, violet or champagne gown) so the heroes stay
## the only ones in their own colours, and the dealers.
## Simulate few, render many (CLAUDE.md): each person is posed once on the rig (CasinoPerson) and baked into one mesh, and
## everyone sharing a look and a pose is one MultiMesh (a draw call each, about twenty in all). They live on the
## cinematic's clock (update()): a breath and a sway each, the roulette's onlookers cheering with its players; as the
## wall trembles they turn to it, and as it bursts they shrink back from it.
## Its space: the hall's (CasinoHall: track space with z flipped).
## DESIGN-TBD (docs/questions/casino_boss_intro.md): who stands where, their looks and their poses.

## The looks: [base look, recolour (from hue, hue window, minimum saturation, to colour), or none].
enum Variant { HIGH_ROLLER, HIGH_ROLLER_NAVY, HIGH_ROLLER_CHARCOAL, GRIMY, GRIMY_BROWN, LADY_LUCK, GOWN_SAPPHIRE, GOWN_VIOLET,
	GOWN_CHAMPAGNE, DEALER }
## The baked poses.
enum Pose { STAND, HOLD, DRINK, CHEER, CLAP, LEAN, TABLE }

## Heights by look (the cinematic's: the women's and the men's).
const MAN_HEIGHT_SPREAD := Vector2(0.95, 1.04)
const WOMAN_HEIGHT_SPREAD := Vector2(0.96, 1.03)

## Every person: [variant, pose, x, z, heading (degrees: 0 facing +z, 90 facing -x), flags]. Flags: 1 cheers with the
## roulette's players.
const CHEERS: int = 1

var tuning: CasinoBossIntroTuning
var spots: Array[Dictionary] = []
## (variant, pose) -> {"mm": MultiMesh, "spots": [spot index]}.
var groups: Dictionary = {}
var _baked: Dictionary = {}


func setup(n: CasinoBossIntroTuning) -> void:
	name = "Crowd"
	tuning = n
	_place()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2626
	for i: int in spots.size():
		var s: Dictionary = spots[i]
		s["seed"] = rng.randf_range(0.0, 10.0)
		s["react"] = rng.randf_range(0.0, 0.8)
		_join(i, int(s["variant"]), int(s["pose"]))
		if int(s["flags"]) & CHEERS:
			_join(i, int(s["variant"]), Pose.CHEER)
	for key: Vector2i in groups:
		var g: Dictionary = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _bake(Variant.values()[key.x], Pose.values()[key.y])
		mm.instance_count = (g["spots"] as Array).size()
		g["mm"] = mm
		var inst := MultiMeshInstance3D.new()
		inst.name = "%s_%s" % [Variant.keys()[key.x], Pose.keys()[key.y]]
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
	update(0.0, n)


func _join(i: int, variant: int, pose: int) -> void:
	var key := Vector2i(variant, pose)
	if not groups.has(key):
		groups[key] = {"spots": []}
	(groups[key]["spots"] as Array).append(i)


func _spot(variant: Variant, pose: Pose, x: float, z: float, heading: float, flags: int = 0) -> void:
	spots.append({"variant": variant, "pose": pose, "at": Vector3(x, 0.0, z), "heading": heading, "flags": flags})


## A place at a table: `local` (x across, z toward its players' side) from its middle turned `turn` degrees, facing
## back across it (or `facing` degrees more).
func _at_table(variant: Variant, pose: Pose, center: Vector3, turn: float, local: Vector2, facing: float = 0.0) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(turn))
	var p: Vector3 = center + b * Vector3(local.x, 0.0, local.y)
	var to_middle: float = rad_to_deg(atan2(-(center.x - p.x), center.z - p.z))
	_spot(variant, pose, p.x, p.z, to_middle + facing)


## Round a point, `count` people at `radius`, starting at angle `from` (degrees) every `step`, facing in.
func _ring(center: Vector3, radius: float, from: float, step: float, variants: Array, poses: Array) -> void:
	for i: int in variants.size():
		var a: float = deg_to_rad(from + step * float(i))
		var p: Vector3 = center + Vector3(cos(a), 0.0, sin(a)) * radius
		var to_middle: float = rad_to_deg(atan2(-(center.x - p.x), center.z - p.z))
		_spot(variants[i], poses[i], p.x, p.z, to_middle)


func _place() -> void:
	var V := Variant
	var P := Pose
	# Onlookers behind the roulette's players, cheering with them.
	var r: Vector3 = CasinoHall.ROULETTE
	_spot(V.HIGH_ROLLER_NAVY, P.STAND, r.x - 0.25, r.z + 1.95, 178.0, CHEERS)
	_spot(V.GOWN_SAPPHIRE, P.HOLD, r.x + 0.75, r.z + 1.9, 190.0, CHEERS)
	_spot(V.GRIMY_BROWN, P.STAND, r.x - 1.5, r.z + 1.75, 165.0, CHEERS)
	# The blackjack tables: three players each along the curved side, the dealer across from them.
	var bj: Array = [[CasinoHall.BLACKJACK_A, 25.0, [V.LADY_LUCK, V.HIGH_ROLLER_CHARCOAL, V.GOWN_VIOLET]],
		[CasinoHall.BLACKJACK_B, -15.0, [V.GRIMY, V.GOWN_CHAMPAGNE, V.HIGH_ROLLER_NAVY]]]
	for t: Array in bj:
		var c: Vector3 = t[0]
		var turn: float = t[1]
		var who: Array = t[2]
		for i: int in who.size():
			_at_table(who[i], P.TABLE, c, turn, Vector2(-0.6 + 0.6 * float(i), 0.98 - 0.12 * absf(float(i) - 1.0)))
		_at_table(V.DEALER, P.TABLE, c, turn, Vector2(0.0, -0.9))
	# The poker table.
	var pk: Vector3 = CasinoHall.POKER
	_at_table(V.HIGH_ROLLER, P.TABLE, pk, 0.0, Vector2(-1.75, 0.0))
	_at_table(V.GRIMY_BROWN, P.TABLE, pk, 0.0, Vector2(1.75, 0.1))
	_at_table(V.GOWN_SAPPHIRE, P.HOLD, pk, 0.0, Vector2(-0.6, 1.05))
	_at_table(V.HIGH_ROLLER_CHARCOAL, P.TABLE, pk, 0.0, Vector2(0.6, 1.05))
	_at_table(V.DEALER, P.TABLE, pk, 0.0, Vector2(0.1, -1.0))
	# The dice table (its long side along z), players along both sides, cheering a throw.
	var dc: Vector3 = CasinoHall.DICE_TABLE
	_spot(V.GRIMY, P.CHEER, dc.x - 1.15, dc.z - 0.6, -90.0)
	_spot(V.GOWN_VIOLET, P.CLAP, dc.x - 1.15, dc.z + 0.5, -95.0)
	_spot(V.HIGH_ROLLER_NAVY, P.TABLE, dc.x + 1.15, dc.z - 0.3, 90.0)
	_spot(V.LADY_LUCK, P.CHEER, dc.x + 1.15, dc.z + 0.7, 92.0)
	_spot(V.DEALER, P.TABLE, dc.x, dc.z + 1.85, 180.0)
	# Round the holographic games, watching.
	_ring(CasinoHall.HOLO_DICE, 1.4, 20.0, 70.0, [V.HIGH_ROLLER_CHARCOAL, V.GOWN_CHAMPAGNE, V.GRIMY], [P.HOLD, P.STAND, P.CLAP])
	_ring(CasinoHall.HOLO_WHEEL, 1.4, 120.0, 65.0, [V.LADY_LUCK, V.HIGH_ROLLER, V.GOWN_SAPPHIRE], [P.TABLE, P.HOLD, P.DRINK])
	_ring(CasinoHall.HOLO_SPHERE, 1.45, 190.0, 75.0, [V.GRIMY_BROWN, V.GOWN_VIOLET, V.HIGH_ROLLER_NAVY], [P.STAND, P.HOLD, P.DRINK])
	# At the slot machines along the left wall.
	for z: float in [7.0, 10.0, 15.0, 25.0, 31.0]:
		var v: Variant = [V.GRIMY, V.LADY_LUCK, V.HIGH_ROLLER_CHARCOAL, V.GOWN_CHAMPAGNE, V.GRIMY_BROWN][int(z) % 5]
		_spot(v, P.TABLE, -CasinoHall.HALF_WIDTH + 1.45, z, -90.0)
	# The island of slots near the back right.
	_spot(V.HIGH_ROLLER_NAVY, P.TABLE, 10.05, 34.55, 0.0)
	_spot(V.GOWN_VIOLET, P.HOLD, 11.95, 34.6, 0.0)
	# Along the bar: drinking at the counter, one leaning back on it.
	var bf: float = CasinoHall.BAR_FRONT - 0.45
	_spot(V.HIGH_ROLLER, P.DRINK, bf, 7.6, -90.0)
	_spot(V.GOWN_SAPPHIRE, P.HOLD, bf, 9.2, -100.0)
	_spot(V.GRIMY_BROWN, P.LEAN, CasinoHall.BAR_FRONT - 0.32, 12.3, 90.0)
	_spot(V.LADY_LUCK, P.DRINK, bf, 18.4, -80.0)
	_spot(V.HIGH_ROLLER_CHARCOAL, P.HOLD, bf, 20.6, -90.0)
	# Groups standing about with their drinks.
	var groups_at: Array = [
		[Vector3(0.6, 0.0, 13.8), [V.GOWN_VIOLET, V.HIGH_ROLLER, V.GRIMY], [P.HOLD, P.DRINK, P.STAND]],
		[Vector3(-9.2, 0.0, 21.0), [V.HIGH_ROLLER_NAVY, V.GOWN_CHAMPAGNE], [P.HOLD, P.HOLD]],
		[Vector3(2.4, 0.0, 22.2), [V.LADY_LUCK, V.HIGH_ROLLER_CHARCOAL, V.GOWN_SAPPHIRE], [P.STAND, P.DRINK, P.HOLD]],
		[Vector3(10.4, 0.0, 19.4), [V.GRIMY_BROWN, V.GOWN_CHAMPAGNE], [P.DRINK, P.HOLD]],
		[Vector3(8.1, 0.0, 24.1), [V.HIGH_ROLLER, V.GOWN_VIOLET], [P.HOLD, P.STAND]],
		[Vector3(4.0, 0.0, 19.8), [V.GRIMY, V.HIGH_ROLLER_NAVY], [P.STAND, P.HOLD]],
		[Vector3(-3.6, 0.0, 32.0), [V.GOWN_SAPPHIRE, V.HIGH_ROLLER_CHARCOAL, V.LADY_LUCK], [P.HOLD, P.DRINK, P.STAND]],
		[Vector3(-9.4, 0.0, 33.4), [V.GRIMY, V.GOWN_CHAMPAGNE], [P.CLAP, P.HOLD]],
		[Vector3(-13.2, 0.0, 36.2), [V.HIGH_ROLLER_NAVY], [P.DRINK]],
		[Vector3(1.6, 0.0, 35.6), [V.GOWN_VIOLET, V.GRIMY_BROWN], [P.HOLD, P.STAND]],
	]
	for g: Array in groups_at:
		var c: Vector3 = g[0]
		var who: Array = g[1]
		var poses: Array = g[2]
		var radius: float = 0.38 if who.size() <= 2 else 0.48
		_ring(c, radius, 35.0 * c.x, 360.0 / float(who.size()), who, poses)


# --- The looks and the bakes -------------------------------------------------------------------------

static func base_look(v: Variant) -> CasinoPeople.Look:
	match v:
		Variant.HIGH_ROLLER, Variant.HIGH_ROLLER_NAVY, Variant.HIGH_ROLLER_CHARCOAL:
			return CasinoPeople.Look.HIGH_ROLLER
		Variant.GRIMY, Variant.GRIMY_BROWN:
			return CasinoPeople.Look.GRIMY
		Variant.LADY_LUCK:
			return CasinoPeople.Look.LADY_LUCK
		Variant.GOWN_SAPPHIRE, Variant.GOWN_VIOLET, Variant.GOWN_CHAMPAGNE:
			return CasinoPeople.Look.ESCORT_BLACK
		_:
			return CasinoPeople.Look.DEALER


static func is_woman(v: Variant) -> bool:
	var look: CasinoPeople.Look = base_look(v)
	return look == CasinoPeople.Look.LADY_LUCK or look == CasinoPeople.Look.ESCORT_BLACK


## A variant's repaint: [hue to find, its window, the least saturation (or for a dark cloth the most value), the colour
## it becomes], or empty for none. The gowns repaint the black gown (any dark, unsaturated cloth that isn't hair).
static func repaint(v: Variant) -> Array:
	match v:
		Variant.HIGH_ROLLER_NAVY:
			return [0.97, 0.06, 0.3, Color(0.12, 0.15, 0.32)]
		Variant.HIGH_ROLLER_CHARCOAL:
			return [0.97, 0.06, 0.3, Color(0.21, 0.21, 0.24)]
		Variant.GRIMY_BROWN:
			return [0.18, 0.07, 0.2, Color(0.36, 0.25, 0.15)]
		Variant.GOWN_SAPPHIRE:
			return [-1.0, 0.0, 0.0, Color(0.12, 0.2, 0.5)]
		Variant.GOWN_VIOLET:
			return [-1.0, 0.0, 0.0, Color(0.34, 0.14, 0.44)]
		Variant.GOWN_CHAMPAGNE:
			return [-1.0, 0.0, 0.0, Color(0.72, 0.6, 0.42)]
	return []


## The parts of a variant: the base look's, repainted (cached).
static func variant_parts(v: Variant) -> HumanoidParts:
	var base: HumanoidParts = CasinoPeople.parts(base_look(v))
	var paint: Array = repaint(v)
	if paint.is_empty():
		return base
	var p := HumanoidParts.new()
	for prop: Dictionary in base.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_STORAGE and not prop["name"] in ["pieces", "panels", "attachments", "cache_key",
				"script", "resource_path", "resource_name", "resource_local_to_scene"]:
			p.set(prop["name"], base.get(prop["name"]))
	p.cache_key = "%s_crowd_%s" % [base.cache_key, Variant.keys()[v]]
	var list: Array[HumanoidPiece] = []
	for piece: HumanoidPiece in base.pieces:
		list.append(_repainted(piece, paint))
	p.pieces = list
	var panels: Array[HumanoidPanel] = []
	for panel: HumanoidPanel in base.panels:
		var copy := panel.duplicate() as HumanoidPanel
		var pp: Array[HumanoidPiece] = []
		for piece: HumanoidPiece in panel.pieces:
			pp.append(_repainted(piece, paint))
		copy.pieces = pp
		panels.append(copy)
	p.panels = panels
	return p


static func _repainted(piece: HumanoidPiece, paint: Array) -> HumanoidPiece:
	var c: Color = piece.color
	var hit: bool
	if float(paint[0]) < 0.0:
		# The black gown: dark and unsaturated, but not the black hair (the gown is a little lighter than the hair).
		hit = c.v < 0.2 and c.s < 0.35 and c.v > 0.07
	else:
		var dh: float = absf(c.h - float(paint[0]))
		dh = minf(dh, 1.0 - dh)
		hit = dh <= float(paint[1]) and c.s >= float(paint[2]) and c.v < 0.75
	if not hit:
		return piece
	var copy := piece.duplicate() as HumanoidPiece
	var to: Color = paint[3]
	# Keep its shade relative to the look's main cloth.
	var shade: float = clampf(c.v / 0.16 if float(paint[0]) < 0.0 else c.v / 0.42, 0.55, 1.35)
	copy.color = Color(to.r * shade, to.g * shade, to.b * shade)
	return copy


## One person of variant `v` in pose `pose`, posed on the rig and baked into one mesh in its own space (feet at the
## origin, facing -z), at design height times 1 (the instances scale it). Cached.
func _bake(v: Variant, pose: Pose) -> ArrayMesh:
	var key := Vector2i(v, pose)
	if _baked.has(key):
		return _baked[key]
	var person := CasinoPerson.new()
	add_child(person)
	var height: float = (tuning.woman_height if is_woman(v) else tuning.man_height)
	person.setup(base_look(v), height, variant_parts(v))
	person.global_transform = Transform3D.IDENTITY
	var t: float = 1.3 + float(v) * 0.7
	person.stand(t, 0.0)
	match pose:
		Pose.HOLD:
			person.hold_glass(1.0, 1)
		Pose.DRINK:
			person.drink(0.85, 1)
		Pose.CHEER:
			person.cheer(1.0, 0.1)
		Pose.CLAP:
			person.clap(1.0, 0.05)
		Pose.LEAN:
			person.lean_back_elbows(1.0)
		Pose.TABLE:
			person.look_at_point(person.global_position + Vector3(0.0, 0.25, -0.9), 1.0)
			person.hold_glass(0.6, 1)
	var mesh: ArrayMesh = _merge(person)
	remove_child(person)
	person.free()
	_baked[key] = mesh
	return mesh


## Every part of a posed person merged into one mesh in its space: its body pieces and its panels (turned as the rig
## turned them, so the bake keeps them clear of the legs), drawn with the rig's shared body material.
static func _merge(person: CasinoPerson) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var inv: Transform3D = person.global_transform.affine_inverse()
	var mat: ShaderMaterial = person.rig.material as ShaderMaterial
	var rots: Variant = mat.get_shader_parameter(&"panel_rot") if mat != null else null
	var hinges: Variant = mat.get_shader_parameter(&"panel_hinge") if mat != null else null
	for node: Node in person.rig.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xf: Transform3D = inv * mi.global_transform
		var nb: Basis = xf.basis.inverse().transposed()
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var pn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var pc: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var pu: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var order: PackedInt32Array = idx
			if order.is_empty():
				order.resize(pv.size())
				for i: int in pv.size():
					order[i] = i
			for i: int in order:
				var p: Vector3 = pv[i]
				var nrm: Vector3 = pn[i] if i < pn.size() else Vector3.UP
				var uv: Vector2 = pu[i] if i < pu.size() else Vector2.ZERO
				var panel: int = int(uv.y + 0.5) - 1
				if panel >= 0 and panel < 8 and rots != null and hinges != null and panel < rots.size() and panel < hinges.size():
					var q4: Vector4 = rots[panel]
					var h4: Vector4 = hinges[panel]
					var q := Vector3(q4.x, q4.y, q4.z)
					var hinge := Vector3(h4.x, h4.y, h4.z)
					var d: Vector3 = p - hinge
					p = hinge + d + 2.0 * q.cross(q.cross(d) + q4.w * d)
					nrm = nrm + 2.0 * q.cross(q.cross(nrm) + q4.w * nrm)
				verts.append(xf * p)
				normals.append((nb * nrm).normalized())
				colors.append(pc[i] if i < pc.size() else Color.WHITE)
				uvs.append(Vector2(uv.x, 0.0))
	var arrays_out: Array = []
	arrays_out.resize(Mesh.ARRAY_MAX)
	arrays_out[Mesh.ARRAY_VERTEX] = verts
	arrays_out[Mesh.ARRAY_NORMAL] = normals
	arrays_out[Mesh.ARRAY_COLOR] = colors
	arrays_out[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
		mesh.surface_set_material(0, CitizenRig.material())
	return mesh


# --- On the clock --------------------------------------------------------------------------------------

func update(t: float, n: CasinoBossIntroTuning) -> void:
	var cheer: bool = t >= n.cheer_at and t < n.cheer_at + n.cheer_seconds
	var hole := Vector3(n.hole_x, 0.0, CasinoHall.DEPTH)
	for key: Vector2i in groups:
		var g: Dictionary = groups[key]
		var mm: MultiMesh = g["mm"]
		var list: Array = g["spots"]
		for k: int in list.size():
			var s: Dictionary = spots[list[k]]
			var cheers: bool = int(s["flags"]) & CHEERS != 0
			var hidden: bool = cheers and ((key.y == Pose.CHEER) != cheer)
			mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), CasinoHall.L(s["at"])) if hidden else _place_at(s, t, n, hole))


## Where a person is at `t` (the hall's space): their breath and sway; turning to the wall as it trembles, shrinking back
## from it as it bursts.
func _place_at(s: Dictionary, t: float, n: CasinoBossIntroTuning, hole: Vector3) -> Transform3D:
	var seed: float = s["seed"]
	var at: Vector3 = s["at"]
	var heading: float = deg_to_rad(float(s["heading"]))
	heading += 0.04 * sin(t * 0.37 + seed)
	var to_wall: float = atan2(-(hole.x - at.x), hole.z - at.z)
	var turn: float = smoothstep(n.tremble_at + 0.4 + float(s["react"]), n.tremble_at + 1.2 + float(s["react"]), t)
	heading = lerp_angle(heading, to_wall, turn * 0.85)
	var back: float = smoothstep(n.burst_at + 0.1, n.burst_at + 1.1, t)
	var away: Vector3 = (at - hole)
	away.y = 0.0
	var reach: float = clampf(1.0 - away.length() / 20.0, 0.0, 1.0)
	var pos: Vector3 = at + away.normalized() * 0.7 * back * reach
	pos.y = 0.004 * (1.0 + sin(t * 1.9 + seed * 2.0))
	var spread: Vector2 = WOMAN_HEIGHT_SPREAD if is_woman(int(s["variant"])) else MAN_HEIGHT_SPREAD
	var size: float = lerpf(spread.x, spread.y, fposmod(seed * 0.37, 1.0))
	return Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * size), CasinoHall.L(pos))


## How many people it shows (tests).
func count() -> int:
	return spots.size()
