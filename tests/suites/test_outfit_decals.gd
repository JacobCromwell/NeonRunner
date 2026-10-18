extends TestSuite
## OutfitDecals (task M2), the printed patches Camo and Beach Master are decorated with: a quad is two triangles, a diamond
## two, a disc one per side; each looks toward the face it is given, has the size it is given and sits on the plane it is
## given; a taper makes a trapezoid; a band over a prism follows the prism's section and taper, covers only the faces in its
## arc and lies a few millimetres off its surface; and a decal merges into its segment's mesh like any piece (no extra draw
## call).

const BACK := OutfitDecals.Face.BACK
const FRONT := OutfitDecals.Face.FRONT
const RIGHT := OutfitDecals.Face.RIGHT
const LEFT := OutfitDecals.Face.LEFT


func run() -> void:
	_test_quad()
	_test_diamond_and_disc()
	_test_on_prism()
	_test_ring_faces()
	_test_in_the_mesh()


func _built(piece: HumanoidPiece, mirror: bool = false) -> HumanoidMeshBuilder:
	var builder := HumanoidMeshBuilder.new()
	builder.add_piece(piece, mirror)
	return builder


## The extent of a set of points, per axis.
static func _box(points: PackedVector3Array) -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for v: Vector3 in points:
		lo = lo.min(v)
		hi = hi.max(v)
	return AABB(lo, hi - lo)


## The mean face normal of the built geometry.
static func _normal(builder: HumanoidMeshBuilder) -> Vector3:
	var sum := Vector3.ZERO
	for n: Vector3 in builder.normals:
		sum += n
	return (sum / maxf(builder.normals.size(), 1)).normalized()


func _test_quad() -> void:
	var list: Array[HumanoidPiece] = []
	var at := Vector3(0.02, 0.15, 0.11)
	var back: HumanoidMeshBuilder = _built(OutfitDecals.quad(list, &"chest", at, 0.08, 0.05, Color.RED, BACK))
	var box: AABB = _box(back.vertices)
	check(back.triangle_count() == 2, "a quad is two triangles (%d)" % back.triangle_count())
	check(is_equal_approx(box.size.x, 0.08) and is_equal_approx(box.size.y, 0.05) and box.size.z < 0.002,
		"…as wide and tall as it is told, and flat (%s)" % box.size)
	check(box.get_center().is_equal_approx(at) or box.get_center().distance_to(at) < 0.001, "…centred where it is put (%s)" % box.get_center())
	check(_normal(back).dot(Vector3.BACK) > 0.99, "a BACK quad looks toward the camera behind the runner (%s)" % _normal(back))
	var front: HumanoidMeshBuilder = _built(OutfitDecals.quad(list, &"chest", at, 0.08, 0.05, Color.RED, FRONT))
	check(_normal(front).dot(Vector3.FORWARD) > 0.99, "a FRONT quad looks the way the runner faces")
	var right: HumanoidMeshBuilder = _built(OutfitDecals.quad(list, &"upper_arm", at, 0.08, 0.05, Color.RED, RIGHT))
	var right_box: AABB = _box(right.vertices)
	check(_normal(right).dot(Vector3.RIGHT) > 0.99 and is_equal_approx(right_box.size.z, 0.08) and is_equal_approx(right_box.size.y, 0.05),
		"a RIGHT quad looks toward +x, its width along z (%s)" % right_box.size)
	var left: HumanoidMeshBuilder = _built(OutfitDecals.quad(list, &"upper_arm", at, 0.08, 0.05, Color.RED, LEFT))
	check(_normal(left).dot(Vector3.LEFT) > 0.99, "a LEFT quad looks toward -x")
	# A mirrored decal (a limb's pair) looks the way a mirrored piece does: its x is reflected, and it still faces back.
	var mirrored: HumanoidMeshBuilder = _built(OutfitDecals.quad(list, &"pelvis", at, 0.04, 0.04, Color.RED, BACK), true)
	check(_box(mirrored.vertices).get_center().x < 0.0 and _normal(mirrored).dot(Vector3.BACK) > 0.99, "a mirrored decal is on the other side, still facing back")
	# A taper: the top is that much wider than the bottom (a jaw, wider above).
	var jaw: HumanoidMeshBuilder = _built(OutfitDecals.quad(list, &"chest", at, 0.06, 0.05, Color.RED, BACK, Vector3.ZERO, 0.0, 1.5))
	var top: float = 0.0
	var bottom: float = 0.0
	for v: Vector3 in jaw.vertices:
		if v.y > at.y:
			top = maxf(top, absf(v.x - at.x))
		else:
			bottom = maxf(bottom, absf(v.x - at.x))
	check(is_equal_approx(top / bottom, 1.5) and is_equal_approx(bottom * 2.0, 0.06), "a taper of 1.5 makes the top half as wide again as the bottom (%.3f, %.3f)" % [top * 2.0, bottom * 2.0])
	# A roll turns it about its own normal, keeping the plane.
	var rolled: HumanoidMeshBuilder = _built(OutfitDecals.quad(list, &"chest", at, 0.08, 0.02, Color.RED, BACK, Vector3(0.0, 0.0, 90.0)))
	var rolled_box: AABB = _box(rolled.vertices)
	check(rolled_box.size.y > 0.07 and rolled_box.size.x < 0.03 and rolled_box.size.z < 0.002, "a roll of 90° stands it on end (%s)" % rolled_box.size)


func _test_diamond_and_disc() -> void:
	var list: Array[HumanoidPiece] = []
	var at := Vector3(0.0, 0.17, 0.11)
	var leaf: HumanoidMeshBuilder = _built(OutfitDecals.diamond(list, &"chest", at, 0.03, 0.09, Color.GREEN, BACK))
	var box: AABB = _box(leaf.vertices)
	check(leaf.triangle_count() == 2 and is_equal_approx(box.size.x, 0.03) and is_equal_approx(box.size.y, 0.09) and _normal(leaf).dot(Vector3.BACK) > 0.99,
		"a diamond is two triangles, as wide and tall as it is told, looking back (%d, %s)" % [leaf.triangle_count(), box.size])
	for sides: int in [3, 5, 8]:
		var disc: HumanoidMeshBuilder = _built(OutfitDecals.disc(list, &"chest", at, 0.1, 0.08, Color.GREEN, sides, BACK))
		var disc_box: AABB = _box(disc.vertices)
		check(disc.triangle_count() == sides, "a %d-sided disc is %d triangles (%d)" % [sides, sides, disc.triangle_count()])
		check(disc_box.size.x <= 0.1 + 0.001 and disc_box.size.x >= 0.1 * 0.7 and disc_box.size.y <= 0.08 + 0.001 and disc_box.size.y >= 0.08 * 0.7
			and disc_box.size.z < 0.002, "…about as wide and tall as it is told, and flat (%s)" % disc_box.size)
		check(_normal(disc).dot(Vector3.BACK) > 0.99 and absf(_box(disc.vertices).get_center().z - at.z) < 0.002,
			"…looking back, on its plane (%s)" % _normal(disc))
	var front: HumanoidMeshBuilder = _built(OutfitDecals.disc(list, &"chest", at, 0.05, 0.05, Color.GREEN, 6, FRONT))
	check(_normal(front).dot(Vector3.FORWARD) > 0.99, "a FRONT disc looks the way the runner faces")
	var right: HumanoidMeshBuilder = _built(OutfitDecals.disc(list, &"chest", at, 0.05, 0.05, Color.GREEN, 6, RIGHT))
	check(_normal(right).dot(Vector3.RIGHT) > 0.99, "a RIGHT disc looks toward +x")


func _test_on_prism() -> void:
	var list: Array[HumanoidPiece] = []
	var host := PlayerOutfit.piece(&"upper_arm", HumanoidPiece.Shape.PRISM, Vector3(0.1, 0.22, 0.095), Vector3(0.0, -0.095, 0.0), Color.WHITE,
		0.0, {"side": HumanoidPiece.Placement.RIGHT, "top_scale": Vector2(1.15, 1.15)})
	var host_mesh: HumanoidMeshBuilder = _built(host)
	var host_box: AABB = _box(host_mesh.vertices)
	var patch: HumanoidPiece = OutfitDecals.on_prism(list, host, Vector2(150.0, 210.0), 0.2, 0.6, Color.GREEN)
	var built: HumanoidMeshBuilder = _built(patch)
	var box: AABB = _box(built.vertices)
	check(built.triangle_count() == 2, "a band over one face of a prism is two triangles (%d)" % built.triangle_count())
	check(patch.side == host.side and patch.offset == host.offset and patch.sides == host.sides, "…placed as its host is (side, offset, section)")
	# Over the back face only, between 20% and 60% of the way up, a few millimetres off the surface.
	var low: float = host_box.position.y + host_box.size.y * 0.2
	var high: float = host_box.position.y + host_box.size.y * 0.6
	check(absf(box.position.y - low) < 0.002 and absf(box.end.y - high) < 0.002, "…covering 20%% to 60%% of its height (%.3f to %.3f)" % [box.position.y, box.end.y])
	var behind: bool = true
	for v: Vector3 in built.vertices:
		behind = behind and v.z > 0.0
	check(behind and box.size.x < host_box.size.x * 0.7, "…on the back face only")
	# Its distance off the surface at its top edge, against the prism's own back face (a hexagon's, 0.866 of its radius) there.
	var host_back: float = 0.095 * 0.5 * lerpf(1.0, 1.15, 0.6) * 0.866
	check(box.end.z - host_back > 0.002 and box.end.z - host_back < 0.008,
		"…a few millimetres off it (%.1f mm)" % ((box.end.z - host_back) * 1000.0))


## The faces of a skirt's ring: an oval ring has its faces at no tidy angle, so a patch asks the shape for them (a decal
## aimed at 105 degrees on an oval ring built nothing in M2's first build).
func _test_ring_faces() -> void:
	var round_faces: PackedFloat32Array = OutfitDecals.face_directions(Vector2(0.3, 0.3), 12, 15.0)
	var tidy: bool = round_faces.size() == 12
	for d: float in round_faces:
		var r: float = fposmod(d - 15.0, 30.0)
		tidy = tidy and (r < 0.01 or r > 29.99)
	check(tidy, "a round ring's twelve faces sit at 15, 45, 75 ... degrees")
	var oval := Vector2(0.308, 0.24)
	var faces: PackedFloat32Array = OutfitDecals.face_directions(oval, 12, 15.0)
	var back: PackedFloat32Array = OutfitDecals.faces_in(faces, Vector2(91.0, 179.0))
	var front: PackedFloat32Array = OutfitDecals.faces_in(faces, Vector2(31.0, 89.0))
	check(back.size() == 3 and absf(back[0] - 101.8) < 0.2 and absf(back[1] - 127.9) < 0.2 and absf(back[2] - 161.0) < 0.2,
		"an oval ring's back-right faces are at 101.8, 127.9 and 161.0 degrees, not 105, 135 and 165 (%s)" % [back])
	check(front.size() == 2 and absf(front[0] - 52.1) < 0.2 and absf(front[1] - 78.2) < 0.2, "...and its front-right ones at 52.1 and 78.2 (%s)" % [front])
	var built: PackedInt32Array = []
	for d: float in back:
		built.append(_ring_band(oval, OutfitDecals.face_arc(d)).triangle_count())
	for d: float in front:
		built.append(_ring_band(oval, OutfitDecals.face_arc(d)).triangle_count())
	check(built == PackedInt32Array([2, 2, 2, 2, 2]), "a band over a face found that way is two triangles on each (%s)" % [built])
	check(_ring_band(oval, Vector2(104.0, 106.0)).triangle_count() == 0, "...while one aimed at a tidy 105 degrees builds nothing on the oval")


func _ring_band(diameter: Vector2, arc: Vector2) -> HumanoidMeshBuilder:
	var band := PlayerOutfit.piece(&"pelvis", HumanoidPiece.Shape.BAND, Vector3(diameter.x, 0.0, diameter.y), Vector3.ZERO, Color.WHITE, 0.0,
		{"sides": 12, "section_phase": 15.0, "arc": arc,
			"profile": PackedVector4Array([Vector4(0.0, 1.0, 1.0, 0.0), Vector4(-0.1, 1.1, 1.1, 0.0)])})
	return _built(band)


## A decal is one more piece in its segment's mesh: it adds its triangles and no surface, so no draw call.
func _test_in_the_mesh() -> void:
	var list: Array[HumanoidPiece] = []
	PlayerOutfit.add(list, &"chest", HumanoidPiece.Shape.BOX, Vector3(0.3, 0.3, 0.2), Vector3.ZERO, Color.WHITE)
	var bare: int = int(_chest_mesh(list).get_meta(&"triangles"))
	for i: int in 10:
		OutfitDecals.quad(list, &"chest", Vector3(0.0, 0.01 * i, 0.101), 0.05, 0.02, Color.RED, BACK)
	var mesh: ArrayMesh = _chest_mesh(list)
	check(int(mesh.get_meta(&"triangles")) == bare + 20 and mesh.get_surface_count() == 1,
		"ten decals add twenty triangles to the segment's one surface (%d -> %d)" % [bare, int(mesh.get_meta(&"triangles"))])
	HumanoidParts.clear_cache()


func _chest_mesh(list: Array[HumanoidPiece]) -> ArrayMesh:
	var parts := HumanoidParts.new()
	parts.cache_key = "test_outfit_decals_%d" % list.size()
	parts.pieces = list
	return parts.segment_mesh(&"chest", 0)
