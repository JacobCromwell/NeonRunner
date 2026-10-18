extends SkinSuite
## The Marketplace citizens (GDD §5, "Citizens"; GDD §9.2; tasks D3 and L7): real low-poly people standing in the shop
## windows, scenery only, seeded from the chunk so the same window always gets the same citizen, never in a feed window or
## a window a window cyborg stands in, switched off by Settings.citizens_enabled, one MultiMesh of them to a wall section
## (never a node a person), dressed plainly (muted clothes, nothing glowing, never a hazard's hue) and moved by their shader
## alone; and cheering when the run's CreditField or EnemyDirector says something big happened, or The House asks
## (CLAUDE.md principle 1: they read the player's position but add no collision or gameplay of their own).

const MARKET_SKIN_PATH: String = "res://data/skins/marketplace_skin.tres"
## A clothes colour's limits (HSV): muted (saturation), never bright (value) and never vivid (saturation times value: a
## hazard's glow is near 1, a dark brown or a slate blue about 0.2), so it can't read as a hazard.
const CLOTHES_MAX_SATURATION: float = 0.5
const CLOTHES_MAX_VALUE: float = 0.84
const CLOTHES_MAX_VIVID: float = 0.26
const SKIN_MAX_VALUE: float = 0.9
## The person's budget: vertices and triangles of the one baked mesh every citizen is an instance of.
const PERSON_MAX_VERTICES: int = 400
const PERSON_MAX_TRIANGLES: int = 600
## The most people one wall section holds, and the most a 40 m chunk of both walls does on average (measured: 4.5): the
## SkinSuite budgets count MeshInstance3D surfaces and see no MultiMesh, so the people's own bound is here.
const PEOPLE_MAX_PER_SECTION: int = 9
const PEOPLE_MAX_MEAN_PER_CHUNK: float = 6.0
## The silhouette's grid (metres) and how far an arm or a head may stray from its pivot over its rest distance when posed.
const SILHOUETTE_CELL: float = 0.004
const POSE_TOLERANCE: float = 0.035


func run() -> void:
	var skin := load(MARKET_SKIN_PATH) as MarketplaceSkin
	check(skin != null, "the marketplace skin loads")
	if skin == null:
		return
	_person_asset()
	_person_is_whole()
	_palettes_and_shader()
	_shader_mirror()
	_reactions_blend()
	await _only_in_free_windows(skin)
	await _off_switch(skin)
	await _deterministic(skin)
	await _one_crowd_a_section(skin)
	await _people_per_chunk(skin)
	await _warm_sample(skin)
	await _watching()
	await _cheers()


## The baked person (tools/godot.sh citizens): one indexed surface within budget, tagged for the shader, its pivots right.
func _person_asset() -> void:
	var mesh: ArrayMesh = MarketPeople.mesh()
	check(mesh != null, "the baked person loads (tools/godot.sh citizens regenerates it)")
	if mesh == null:
		return
	check(mesh.get_surface_count() == 1, "the person is one surface (one draw call a crowd)")
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	check(verts.size() <= PERSON_MAX_VERTICES and index.size() / 3 <= PERSON_MAX_TRIANGLES,
		"the person is cheap: %d vertices, %d triangles (budget %d, %d)" % [verts.size(), index.size() / 3,
			PERSON_MAX_VERTICES, PERSON_MAX_TRIANGLES])
	check(uv2.size() == verts.size(), "every vertex is tagged (colour class, what moves it)")
	var classes: Dictionary = {}
	var moves: Dictionary = {}
	var left_ok: bool = true
	var right_ok: bool = true
	var head_low: float = INF
	var arm_high: float = -INF
	for i: int in verts.size():
		classes[int(uv2[i].x)] = true
		moves[int(uv2[i].y)] = true
		if int(uv2[i].y) == 2:
			left_ok = left_ok and verts[i].x < 0.0
			arm_high = maxf(arm_high, verts[i].y)
		elif int(uv2[i].y) == 3:
			right_ok = right_ok and verts[i].x > 0.0
		elif int(uv2[i].y) == 1:
			head_low = minf(head_low, verts[i].y)
	check(classes.size() == 6 and moves.size() == 4, "every colour class (6, the eyes among them) and moving part (4) is on the person")
	check(left_ok and right_ok, "the left arm is on the person's left (-x) and the right on the right")
	var pivots: Dictionary = mesh.get_meta(&"pivots", {})
	var neck: Vector3 = pivots.get(&"neck", Vector3.ZERO)
	var shoulder_l: Vector3 = pivots.get(&"shoulder_l", Vector3.ZERO)
	var shoulder_r: Vector3 = pivots.get(&"shoulder_r", Vector3.ZERO)
	check(neck.y > shoulder_l.y and neck.y < float(pivots.get(&"height", 0.0)), "the neck is above the shoulders, below the crown")
	check(shoulder_l.x < 0.0 and shoulder_r.x > 0.0 and is_equal_approx(shoulder_l.x, -shoulder_r.x),
		"the shoulders are mirrored about the middle")
	check(absf(mesh.get_aabb().position.y) < 0.001, "the person's feet are on y = 0")
	check(MarketPeople.stature() > 1.0 and MarketPeople.stature() < 1.6, "its height is what a person's scale is taken from (%.2f m)" %
		MarketPeople.stature())


## The person is one piece (no limb floating off its joint: the D3 rig centred each limb piece on its joint and left a gap
## below it), and its head sits on its shoulders, not sunk in the collar: the front view's silhouette, drawn on a fine grid,
## is one connected shape, the shoes touch the trousers, the hands the forearms, and the face is above the shirt.
func _person_is_whole() -> void:
	var mesh: ArrayMesh = MarketPeople.mesh()
	if mesh == null:
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var pieces: int = silhouette_pieces(verts, index, SILHOUETTE_CELL)
	check(pieces == 1, "the person's front silhouette is one piece, nothing floating off it (%d pieces on a %.0f mm grid)" % [
		pieces, SILHOUETTE_CELL * 1000.0])
	var shirt_top: float = -INF
	var eyes_low: float = INF
	var head_low: float = INF
	var shoe_top: float = -INF
	var trousers_low: float = INF
	for i: int in verts.size():
		var cls: int = int(uv2[i].x)
		if cls == 1 and int(uv2[i].y) == 0:
			shirt_top = maxf(shirt_top, verts[i].y)
		elif cls == 5:
			eyes_low = minf(eyes_low, verts[i].y)
		elif cls == 2 and int(uv2[i].y) == 1:
			head_low = minf(head_low, verts[i].y)
		elif cls == 4:
			shoe_top = maxf(shoe_top, verts[i].y)
		elif cls == 0:
			trousers_low = minf(trousers_low, verts[i].y)
	check(eyes_low > shirt_top, "the face is above the collar (the eyes' lowest %.3f m, the shirt's top %.3f m)" % [eyes_low, shirt_top])
	check(head_low > shirt_top - 0.03 and head_low < shirt_top + 0.005,
		"the head sits on the shoulders, not sunk in them (its lowest %.3f m, the shirt's top %.3f m)" % [head_low, shirt_top])
	check(trousers_low < shoe_top, "the trousers come down into the shoes (the trousers' lowest %.3f m, the shoes' top %.3f m)" % [
		trousers_low, shoe_top])


## How many separate pieces the mesh's front view (x and y, the z dropped) is made of: its triangles drawn on a grid of
## `cell` metres, the cells touching (sides and corners) counted as one.
static func silhouette_pieces(verts: PackedVector3Array, index: PackedInt32Array, cell: float) -> int:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for v: Vector3 in verts:
		low = low.min(Vector2(v.x, v.y))
		high = high.max(Vector2(v.x, v.y))
	var w: int = int(ceil((high.x - low.x) / cell)) + 2
	var h: int = int(ceil((high.y - low.y) / cell)) + 2
	var filled := PackedByteArray()
	filled.resize(w * h)
	for t: int in index.size() / 3:
		var a: Vector2 = (Vector2(verts[index[t * 3]].x, verts[index[t * 3]].y) - low) / cell
		var b: Vector2 = (Vector2(verts[index[t * 3 + 1]].x, verts[index[t * 3 + 1]].y) - low) / cell
		var c: Vector2 = (Vector2(verts[index[t * 3 + 2]].x, verts[index[t * 3 + 2]].y) - low) / cell
		var area: float = (b - a).cross(c - a)
		if absf(area) < 0.0001:
			continue
		var lo: Vector2i = Vector2i(a.min(b).min(c).floor())
		var hi: Vector2i = Vector2i(a.max(b).max(c).ceil())
		for y: int in range(maxi(lo.y, 0), mini(hi.y, h - 1) + 1):
			for x: int in range(maxi(lo.x, 0), mini(hi.x, w - 1) + 1):
				var q := Vector2(x + 0.5, y + 0.5)
				var u: float = (b - q).cross(c - q) / area
				var v: float = (c - q).cross(a - q) / area
				if u >= 0.0 and v >= 0.0 and u + v <= 1.0:
					filled[y * w + x] = 1
	var seen := PackedByteArray()
	seen.resize(w * h)
	var pieces: int = 0
	for start: int in w * h:
		if filled[start] == 0 or seen[start] == 1:
			continue
		pieces += 1
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var at: int = stack.pop_back()
			var ax: int = at % w
			var ay: int = at / w
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var nx: int = ax + dx
					var ny: int = ay + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var n: int = ny * w + nx
					if filled[n] == 1 and seen[n] == 0:
						seen[n] = 1
						stack.append(n)
	return pieces


## Plain people: the palettes fit the shader's arrays, clothes are muted and nothing glows or flickers.
func _palettes_and_shader() -> void:
	var source: String = FileAccess.get_file_as_string(MarketPeople.SHADER_PATH)
	check(source != "", "the people's shader is there")
	var pools: Dictionary = {"skins": MarketPeople.SKINS, "hairs": MarketPeople.HAIRS, "shirts": MarketPeople.SHIRTS,
		"pants": MarketPeople.PANTS, "shoes": MarketPeople.SHOES}
	for pool: String in pools:
		var colors: PackedColorArray = pools[pool]
		check(source.contains("uniform vec4 %s[%d];" % [pool, colors.size()]),
			"the palette %s has as many colours as the shader's array (%d)" % [pool, colors.size()])
	var worst_s: float = 0.0
	var worst_v: float = 0.0
	var worst_vivid: float = 0.0
	for pool: String in ["shirts", "pants", "shoes"]:
		for c: Color in pools[pool] as PackedColorArray:
			worst_s = maxf(worst_s, c.s)
			worst_v = maxf(worst_v, c.v)
			worst_vivid = maxf(worst_vivid, c.s * c.v)
	check(worst_s <= CLOTHES_MAX_SATURATION and worst_v <= CLOTHES_MAX_VALUE and worst_vivid <= CLOTHES_MAX_VIVID,
		"clothes are muted (at most saturation %.2f of %.2f, brightness %.2f of %.2f, vividness %.2f of %.2f)" % [worst_s,
			CLOTHES_MAX_SATURATION, worst_v, CLOTHES_MAX_VALUE, worst_vivid, CLOTHES_MAX_VIVID])
	var skin_v: float = 0.0
	for pool: String in ["skins", "hairs"]:
		for c: Color in pools[pool] as PackedColorArray:
			skin_v = maxf(skin_v, c.v)
	check(skin_v <= SKIN_MAX_VALUE, "skin and hair are natural tones, nothing bright (%.2f)" % skin_v)
	check(not source.contains("EMISSION") and not source.contains("TIME"),
		"the people never glow (no emission) and never flicker (no shader TIME: their clock is the game's, stopping with a pause)")


## The shader's pose has a GDScript mirror (MarketPeople.posed(), as DashWallKit.hash11 mirrors the kit's): the constants are
## the same in the shader, the head and arms turn about their pivots before the crouch scales the body, and through a cheer,
## a flinch and a blend of the two every arm and the head stay within their rest distance of the shoulder and neck they hang
## from, wherever the body has gone (the crouch once ran first and tore the arms off at the shoulders).
func _shader_mirror() -> void:
	var source: String = FileAccess.get_file_as_string(MarketPeople.SHADER_PATH)
	for pair: Array in [["ARMS_CHEER", MarketPeople.ARMS_CHEER], ["ARMS_FLINCH", MarketPeople.ARMS_FLINCH],
			["CROUCH", MarketPeople.CROUCH], ["TIP", MarketPeople.TIP]]:
		var found: RegExMatch = RegEx.create_from_string("const float %s = ([0-9.]+);" % pair[0]).search(source)
		check(found != null and is_equal_approx(float(found.get_string(1)), float(pair[1])),
			"the shader's %s is the mirror's %s" % [pair[0], pair[1]])
	var turn_at: int = source.find("d.xz = vec2(")
	var arms_at: int = source.find("d.xy = rot(d.xy, arms")
	var crouch_at: int = source.find("p.y *= (1.0 + 0.004")
	check(turn_at > 0 and arms_at > turn_at and crouch_at > arms_at,
		"the shader turns the head, swings the arms, and only then crouches the body (the mirror's order)")
	var mesh: ArrayMesh = MarketPeople.mesh()
	if mesh == null:
		return
	var pivots: Dictionary = mesh.get_meta(&"pivots", {})
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var states: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.5, 0.4, 0.7)]
	var worst: float = 0.0
	var worst_what: String = ""
	for r: Vector3 in states:
		for turn: float in [0.0, 0.9, -0.9]:
			for i: int in verts.size():
				var moves: int = int(uv2[i].y)
				if moves == 0:
					continue
				var anchor: Vector3 = pivots[&"neck"] if moves == 1 else (pivots[&"shoulder_r"] if moves == 3 else pivots[&"shoulder_l"])
				# Where the shoulder (or neck) has gone, as a point of the body.
				var body_anchor: Vector3 = MarketPeople.posed(anchor, 0, r, turn, 0.004, 0.024, 0.25, pivots)
				var at: Vector3 = MarketPeople.posed(verts[i], moves, r, turn, 0.004, 0.024, 0.25, pivots)
				var stray: float = at.distance_to(body_anchor) - verts[i].distance_to(anchor)
				if stray > worst:
					worst = stray
					worst_what = "part %d, state %s" % [moves, r]
	check(worst <= POSE_TOLERANCE, "through a cheer, a flinch and a blend the arms stay on the shoulders and the head on the neck "
		+ "(the worst vertex strays %.3f m past its rest distance, tolerance %.3f; %s)" % [worst, POSE_TOLERANCE, worst_what])


## Two reactions at once add: a reaction begun while another is under way eases in from nothing and the other eases out, so
## nothing snaps (the mirror of the shader's two event slots), and react() keeps the one it follows in the second slot.
func _reactions_blend() -> void:
	MarketPeople.reset()
	var flinch := Vector4(0.0, 0.0, 1.0, 0.0)
	var cheer := Vector4(0.4, 0.0, 0.0, 0.0)
	var worst: float = 0.0
	for e: float in [-1.0, 1.0]:
		var t: float = cheer.x + e * 0.0001
		var r: Vector3 = (MarketPeople.reaction(flinch, -5.0, 0.0, t) + MarketPeople.reaction(cheer, -5.0, 0.0, t)).min(Vector3.ONE)
		worst = maxf(worst, r.x + r.y + r.z)
		if e > 0.0:
			var before: Vector3 = (MarketPeople.reaction(flinch, -5.0, 0.0, cheer.x - 0.0001) + MarketPeople.reaction(cheer, -5.0, 0.0, cheer.x - 0.0001)).min(Vector3.ONE)
			check(absf(r.x - before.x) < 0.01 and absf(r.y - before.y) < 0.01 and absf(r.z - before.z) < 0.01,
				"a cheer begun in the middle of a flinch changes nothing at that instant (it eases in, the flinch eases out)")
	check(worst > 0.5, "and the flinch it follows is still on at that moment (%.2f)" % worst)
	var mid: float = MarketPeople.reaction(flinch, -5.0, 0.0, 0.4).z
	check(mid > 0.5, "(a flinch 0.4 s in is at %.2f of its crouch)" % mid)
	# The 2-slot state: the second react() moves the first into the second slot.
	var world_scene_ok: bool = MarketPeople.material() != null
	if world_scene_ok:
		MarketPeople.react(&"startled")
		var first: Vector4 = MarketPeople.events()[0]
		MarketPeople.react(&"cheer")
		var slots: Array[Vector4] = MarketPeople.events()
		check(first.z == 1.0 and slots[1] == first and slots[0].z == 0.0 and slots[0] != first,
			"react() keeps the reaction under way in the second slot while the new one eases in")
		check((MarketPeople.material().get_shader_parameter(&"u_event_prev") as Vector4) == first,
			"and the shader is given both")
	MarketPeople.reset()


## Never in a window holding an ad screen or a poster (shop_windows()'s `screen`), nor one a window cyborg stands in
## (note_wall_enemies(), GDD §9.2: "kept apart").
func _only_in_free_windows(skin: MarketplaceSkin) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var side: int = 1
	var face_x: float = side * geo.wall_x()
	var windows: Array[Dictionary] = skin.shop_windows(side, face_x, 0.0, 120.0)
	var screen_ats: Array[float] = []
	var free_at: float = -1.0
	for w: Dictionary in windows:
		if bool(w["screen"]):
			screen_ats.append(float(w["at"]))
		elif free_at < 0.0:
			free_at = float(w["at"])
	check(free_at >= 0.0 and not screen_ats.is_empty(), "the test level has both a free and a display window to check")
	skin.note_wall_enemies(side, 0.0, 120.0, [{"type": "window_cyborg", "at": free_at, "side": side}])
	var parent := Node3D.new()
	tree.root.add_child(parent)
	skin.citizens().build(parent, side, face_x, 0.0, 120.0)
	var placed: Array[float] = []
	for person: Dictionary in MarketCrowd.people_under(parent):
		placed.append(float(person["at"]))
	var ok: bool = true
	for at: float in placed:
		if absf(at - free_at) <= MarketCitizens.CYBORG_MARGIN:
			ok = false
		for sa: float in screen_ats:
			if is_equal_approx(at, sa):
				ok = false
	check(ok and not placed.is_empty(), "citizens avoid the reserved window and every display window (%d placed)" %
		placed.size())
	skin.note_wall_enemies(side, 0.0, 120.0, [])  # Leave the skin as _off_switch() etc. expect it.
	parent.queue_free()
	await tree.process_frame


## Settings.citizens_enabled off builds none; back on builds some again.
func _off_switch(skin: MarketplaceSkin) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var face_x: float = geo.wall_x()
	var was_enabled: bool = Settings.citizens_enabled
	Settings.citizens_enabled = false
	var parent := Node3D.new()
	tree.root.add_child(parent)
	skin.citizens().build(parent, 1, face_x, 0.0, 120.0)
	check(parent.get_children().is_empty(), "no citizens build while Settings.citizens_enabled is off")
	Settings.citizens_enabled = true
	skin.citizens().build(parent, 1, face_x, 0.0, 120.0)
	check(not parent.get_children().is_empty(), "citizens build again once the setting is back on")
	Settings.citizens_enabled = was_enabled
	parent.queue_free()
	await tree.process_frame


## The same chunk gets the same citizens (place, height and build, facing, seeds) every time it's built, and every one
## stands inside its window, on its floor, no taller than the opening, facing the lanes.
func _deterministic(skin: MarketplaceSkin) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var face_x: float = geo.wall_x()
	var a := Node3D.new()
	var b := Node3D.new()
	tree.root.add_child(a)
	tree.root.add_child(b)
	skin.citizens().build(a, 1, face_x, 0.0, 160.0)
	skin.citizens().build(b, 1, face_x, 0.0, 160.0)
	var sig_a: Array[Dictionary] = MarketCrowd.people_under(a)
	var sig_b: Array[Dictionary] = MarketCrowd.people_under(b)
	check(not sig_a.is_empty() and sig_a == sig_b, "the same chunk gets the same citizens every time (%d placed)" %
		sig_a.size())
	var inside: bool = true
	var facing: bool = true
	var windows: Array[Dictionary] = skin.shop_windows(1, face_x, 0.0, 160.0)
	for person: Dictionary in sig_a:
		var w: Dictionary = {}
		for candidate: Dictionary in windows:
			if is_equal_approx(float(candidate["at"]), float(person["at"])):
				w = candidate
		var pos: Vector3 = person["pos"]
		var scale: Vector3 = person["scale"]
		var height: float = scale.y * MarketPeople.stature()
		var half: float = float(w["width"]) * 0.5
		inside = inside and not w.is_empty() and absf(pos.y - float(w["bottom"])) < 0.001 \
			and pos.y + height < float(w["top"]) \
			and pos.x > face_x and pos.x < face_x + float(w["depth"]) \
			and absf(pos.z - float((w["center"] as Vector3).z)) < half - 0.3
		# The front is local -z: its x component points toward the lanes (-x on the right wall).
		var front: Vector3 = Basis(Vector3.UP, float(person["heading"])) * Vector3(0.0, 0.0, -1.0)
		facing = facing and front.x < -0.5 and front.z > 0.0
	check(inside, "every citizen stands inside their window, on its floor, under its lintel, clear of its piers")
	check(facing, "every citizen on the right wall faces the lanes, turned a little toward the runner's approach")
	a.queue_free()
	b.queue_free()
	await tree.process_frame


## A wall section's crowd is one MultiMesh and one group member, however many people stand in it: never a node a person.
func _one_crowd_a_section(skin: MarketplaceSkin) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var parent := Node3D.new()
	tree.root.add_child(parent)
	skin.citizens().build(parent, 1, geo.wall_x(), 0.0, 400.0)
	var crowds: int = 0
	var instances: int = 0
	var nodes: int = 0
	var stack: Array[Node] = [parent]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		nodes += 1
		stack.append_array(node.get_children())
		if node is MultiMeshInstance3D:
			crowds += 1
			instances += (node as MultiMeshInstance3D).multimesh.instance_count
	check(crowds == 1 and instances > 4 and instances <= PEOPLE_MAX_PER_SECTION * 10, "a section's citizens are one MultiMesh of them (%d instances in %d)" % [instances, crowds])
	check(nodes == 3, "and three nodes in all, however many people (%d)" % nodes)
	var in_group: int = get_tree_group_count()
	check(in_group >= 1, "the crowd is in the market_citizens group (The House's hook)")
	check(not (parent.get_child(0) as MarketCrowd).spots().is_empty(), "the crowd lists where its people stand")
	parent.queue_free()
	await tree.process_frame


## What a 40 m chunk of the street holds: a section's crowd is one MultiMesh of a handful, the chunks' mean is what the cost
## numbers were measured at (docs/architecture/skins-marketplace-corporate-deadzone-casino.md), and the people come in
## three silhouettes (the vendor, the shopper and the regular: taller or shorter, slimmer or wider).
func _people_per_chunk(skin: MarketplaceSkin) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var biggest: int = 0
	var total: int = 0
	var chunks: int = 0
	var heights: Array[float] = []
	var builds: Array[float] = []
	for k: int in 60:
		var both: int = 0
		for side: int in [-1, 1]:
			var parent := Node3D.new()
			tree.root.add_child(parent)
			skin.citizens().build(parent, side, side * geo.wall_x(), float(k) * 40.0, float(k + 1) * 40.0)
			var people: Array[Dictionary] = MarketCrowd.people_under(parent)
			biggest = maxi(biggest, people.size())
			both += people.size()
			for person: Dictionary in people:
				var scale: Vector3 = person["scale"]
				heights.append(snappedf(scale.y * MarketPeople.stature(), 0.05))
				builds.append(snappedf(scale.x / scale.y, 0.05))
			parent.free()
		total += both
		chunks += 1
	var mean: float = float(total) / float(chunks)
	check(biggest <= PEOPLE_MAX_PER_SECTION and mean <= PEOPLE_MAX_MEAN_PER_CHUNK and mean > 1.0,
		"a wall section holds at most %d people (%d), a 40 m chunk of both walls %.1f on average (limits %d, %.1f)" % [
			PEOPLE_MAX_PER_SECTION, biggest, mean, PEOPLE_MAX_PER_SECTION, PEOPLE_MAX_MEAN_PER_CHUNK])
	var distinct_heights: Dictionary = {}
	for height: float in heights:
		distinct_heights[height] = true
	var tall: float = heights.max()
	var short: float = heights.min()
	var wide: float = builds.max()
	var slim: float = builds.min()
	check(tall - short > 0.2 and wide - slim > 0.25 and distinct_heights.size() >= 3,
		"the people differ in silhouette: heights %.2f to %.2f m, builds %.2f to %.2f" % [short, tall, slim, wide])
	await tree.process_frame


## Who watches the runner: a crowd in a run, or in a review with a runner set, watches (u_state.w 1); a crowd with no run at
## all (the Marketplace intro's street, built through TrackBuilder by CineStage) faces forward (0), however stale the last
## runner was; and a crowd outside the run's tree (the warm-up's sample) never drives a frame a crowd of the run could.
func _watching() -> void:
	MarketPeople.reset()
	var person: Array[Dictionary] = [MarketCitizens.sample_person()]
	var alone := MarketCrowd.new()
	tree.root.add_child(alone)
	alone.setup(person)
	MarketPeople.set_runner(Vector3(0.0, 1.0, -300.0))
	await tree.process_frame
	await tree.process_frame
	check((MarketPeople.material().get_shader_parameter(&"u_state") as Vector4).w == 1.0, "with a runner set the people watch them")
	MarketPeople.reset()  # a new run: the old runner is forgotten
	await tree.process_frame
	await tree.process_frame
	check((MarketPeople.material().get_shader_parameter(&"u_state") as Vector4).w == 0.0,
		"with no run and no runner (the intro's street) the people face forward")
	var sim := RunSim.new(tree, tuning)
	var world: RunWorld = sim.build_world(RunSim.layout(5, 200.0))
	var inside := MarketCrowd.new()
	world.add_child(inside)
	inside.setup(person)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	check((MarketPeople.material().get_shader_parameter(&"u_state") as Vector4).w == 1.0,
		"a crowd in a run drives the frame even with another crowd outside it earlier in the tree, and the people watch the run's runner")
	alone.queue_free()
	await sim.free_world(world)
	MarketPeople.reset()


## The shader warm-up (ShaderWarmup calls the skin's warm_samples) draws one person while the level loads, so the people's
## shader is never first compiled mid-run on the Compatibility renderer; with the citizens off it draws none.
func _warm_sample(skin: MarketplaceSkin) -> void:
	var parent := Node3D.new()
	tree.root.add_child(parent)
	skin.warm_samples(parent)
	var crowds: Array[Node] = parent.get_children().filter(func(n: Node) -> bool: return n is MarketCrowd)
	check(crowds.size() == 1 and (crowds[0] as MarketCrowd).people.size() == 1,
		"the warm-up's sample is one crowd of one person, with the material the real crowds use")
	if crowds.size() == 1:
		check((crowds[0] as MarketCrowd).instances.material_override == MarketPeople.material(),
			"and it draws with the one shared material (the shader the warm-up compiles is the one they use)")
	var saved: bool = Settings.citizens_enabled
	Settings.citizens_enabled = false
	var off := Node3D.new()
	tree.root.add_child(off)
	skin.warm_samples(off)
	check(off.get_child_count() == 0, "with the citizens switched off the warm-up draws none")
	Settings.citizens_enabled = saved
	parent.queue_free()
	off.queue_free()
	await tree.process_frame


func get_tree_group_count() -> int:
	return tree.get_nodes_in_group(MarketPeople.GROUP).size()


## What cheers them: a credit of the top denominations, a big enemy's defeat (the player's), The House's own calls; and not
## a coin, an ordinary enemy or one an enemy's charge flattened. The cheer is one uniform (u_event), for the people near the
## runner, and a second cheer inside the cooldown is let go by.
func _cheers() -> void:
	MarketPeople.reset()
	var sim := RunSim.new(tree, tuning)
	var world: RunWorld = sim.build_world(RunSim.layout(5, 200.0))
	var crowd := MarketCrowd.new()
	world.add_child(crowd)
	var people: Array[Dictionary] = [{"pos": Vector3(4.0, 0.85, -30.0), "heading": 2.0, "scale": Vector3.ONE, "look": 0.3,
		"phase": 0.1, "late": 0.2, "at": 30.0}]
	crowd.setup(people)
	await tree.process_frame
	await tree.process_frame
	check(MarketPeople.since_event() > 100.0, "nothing cheers before anything happens")
	var tune: MarketPeopleTuning = MarketPeople.tuning()
	check(tune.cheer_credit_min_value > 1 and tune.cheer_credit_min_value <= 100 and not tune.cheer_enemy_types.is_empty(),
		"the thresholds are data (data/citizens/market_people.tres)")
	world.credits.collected.emit(1, Vector3.ZERO)
	check(MarketPeople.since_event() > 100.0, "a coin of 1 doesn't cheer")
	world.credits.collected.emit(5, Vector3.ZERO)
	check(MarketPeople.since_event() > 100.0, "a chip of 5 doesn't cheer")
	world.player.distance = 20.0
	await tree.process_frame
	world.credits.collected.emit(tune.cheer_credit_min_value, Vector3.ZERO)
	check(MarketPeople.since_event() < 0.1, "a credit of %d does" % tune.cheer_credit_min_value)
	var event: Vector4 = MarketPeople.material().get_shader_parameter(&"u_event")
	check(is_equal_approx(event.y, world.player.global_position.z) and is_equal_approx(event.z, 0.0),
		"it is a cheer for the people near where the runner is (world z %.1f)" % event.y)
	var state: Vector4 = MarketPeople.material().get_shader_parameter(&"u_state")
	check(is_equal_approx(state.z, world.player.global_position.z), "the one uniform every frame carries the runner's place")
	# Within the cooldown a second big pickup is let go by: the first cheer's start stands.
	var first: float = event.x
	await tree.process_frame
	world.credits.collected.emit(100, Vector3.ZERO)
	var again: Vector4 = MarketPeople.material().get_shader_parameter(&"u_event")
	check(is_equal_approx(again.x, first), "a second big pickup inside the cooldown is let go by (a little cheer, not a rave)")
	# Enemies: a big one defeated by the player cheers; an ordinary one doesn't; a friendly-fire flattening doesn't.
	MarketPeople.reset()
	await tree.process_frame
	var small: Enemy = world.director.spawn({"script": "res://tests/helpers/dummy_enemy.gd", "type": "cyborg", "lane": 1,
		"at": 40.0, "params": {}})
	small.defeat(&"stomp")
	check(MarketPeople.since_event() > 100.0, "an ordinary enemy's defeat doesn't cheer")
	var big_type: String = tune.cheer_enemy_types[0]
	var flattened: Enemy = world.director.spawn({"script": "res://tests/helpers/dummy_enemy.gd", "type": big_type, "lane": 1,
		"at": 44.0, "params": {}})
	flattened.defeat(Enemy.CHARGE_DAMAGE_CAUSE)
	check(MarketPeople.since_event() > 100.0, "a big enemy another's charge flattened earns the player nothing, and no cheer")
	var big: Enemy = world.director.spawn({"script": "res://tests/helpers/dummy_enemy.gd", "type": big_type, "lane": 1,
		"at": 48.0, "params": {}})
	big.defeat(&"stomp")
	check(MarketPeople.since_event() < 0.1, "the player's defeat of a big enemy (%s) cheers" % big_type)
	for kind: String in ["hover_truck", "drone"]:
		check(tune.cheer_enemy_types.has(kind), "%s is one of the big enemies that cheer them" % kind)
	# The House's own calls through the group (D3's hook): a cheer, and a flinch (the duck).
	MarketPeople.reset()
	await tree.process_frame
	tree.call_group(MarketPeople.GROUP, &"react", &"cheer")
	check(MarketPeople.since_event() < 0.1 and (MarketPeople.material().get_shader_parameter(&"u_event") as Vector4).z == 0.0,
		"The House's react(&\"cheer\") on the group cheers them")
	await tree.process_frame
	tree.call_group(MarketPeople.GROUP, &"react", &"startled")
	check(MarketPeople.since_event() < 0.1 and (MarketPeople.material().get_shader_parameter(&"u_event") as Vector4).z == 1.0,
		"and its react(&\"startled\") makes them flinch")
	MarketPeople.reset()
	await sim.free_world(world)
