class_name GoldenConvergenceFire
extends BossPart
## The Helidrone Strafe's fire (GDD §10): what hits, and what it leaves. The strafe (GoldenConvergenceStrafe)
## plans each pass and shows its warning (the red floor lines and the gatling's whine); then this part
## carries the fire, every piece pooled and made with the fight:
## - a vertical pass's rakes (RAKES of them, one per covered lane: set_rake): an enemy attack hitbox over most
##   of the lane's width from the floor to above a jump's reach (so a jump doesn't dodge it: leaving the lane
##   does), RAKE_DEPTH long around the front its guns rake, with the burning streak of its impacts there and a
##   flare of sparks; in an outer lane the fire also climbs the wall beside it to wall_fire_height (GDD §10:
##   "fire in an outer lane hits a runner low on the wall but not one high up"), drawn on the wall's face
##   where the wall is open (GoldenConvergenceCourt; nobody can be on a closed one);
## - a horizontal pass's lines (set_line): the live line across every lane but the buttress's opening, from
##   the floor to above a jump (line_height, GDD §10 proposed: a jump doesn't dodge it) and up both walls at
##   every height (wall_line_height), each lane's part lit as the sweep reaches it: a burning streak on the
##   floor and a curtain of tracer fire as tall as what it hits; the lines for show look the same but have no
##   hitbox at all (their fire is over long before the runner gets to them);
## - the tracers from each firing drone's guns to where they rake (set_tracer; a flicker, steady with Reduced
##   flashing);
## - the scorch marks every rake and line leaves (scorch_lane, scorch_line): dark, never glowing, fading over
##   scorch_seconds, one MultiMesh in one draw.
## Nothing hits anywhere but a warned lane while its rake passes or the live line while it burns. Its
## hitboxes are enemy attacks (the armor and the shield block them; the dash passes through), and every touch
## is reported (`hit`) for the strafe to log. A part of the boss that's no target and no kill of its own.

## A rake or a line touched the runner (`outcome`: a DamageRules.Outcome other than IGNORE).
signal hit(kind: StringName, lane: int, outcome: int)

## Rakes: the most lanes a vertical pass covers (three on 5 or 6 lanes).
const RAKES: int = 3
## Lines: the live one and the lines for show (one per other drone).
const LINES: int = 3
## Lanes a line spans at most.
const LANES_MAX: int = 6
## A rake's hitbox: a share of the lane's width, its height (over a jump's reach) and its depth along the
## lane (longer than it moves in a frame, so it can't step past a runner).
const RAKE_WIDTH_SHARE: float = 0.72
const RAKE_HEIGHT: float = 3.2
const RAKE_DEPTH: float = 3.0
## The scorch marks: how many at once (the oldest gives way), how dark (sRGB), and how far over the floor
## (under the red warnings, which sit at 0.03 m).
const SCORCH_MAX: int = 48
const SCORCH_COLOR := Color(0.16, 0.13, 0.11)
const SCORCH_ALPHA: float = 0.42
const SCORCH_Y: float = 0.012
## A rake's scorch mark is this wide (a narrow sooty streak, never a lane-wide dark band that could read as a
## hole), a line's this deep.
const SCORCH_WIDTH: float = 0.34
const SCORCH_DEPTH: float = 0.45
## The fire's colours: the enemy attacks' red for what burns and hits, a hotter red-orange for the tracers.
const RAKE_COLOR := Color(1.0, 0.16, 0.08)
const TRACER_COLOR := Color(1.0, 0.36, 0.14)

var tuning: GoldenConvergenceTuning
## {node, hazard, wall_hazard, streak, flare, wall, lane, on, side}
var rakes: Array[Dictionary] = []
## {node, at, live, opening, lanes: Array[{node, hazard, streak, curtain, on}], walls: Array[{hazard, mesh, on}]}
var lines: Array[Dictionary] = []
## {beam, on}
var tracers: Array[Dictionary] = []
## Touches reported, by kind (tests).
var hits: Array[Dictionary] = []

var _streak_mat: StandardMaterial3D
var _curtain_mat: StandardMaterial3D
var _tracer_mat: StandardMaterial3D
var _flare_mat: StandardMaterial3D
var _scorch: MultiMeshInstance3D
## {a, b, x0, x1, age, along: bool}
var _scorches: Array[Dictionary] = []
var _next_scorch: int = 0
var _t: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as GoldenConvergenceTuning
	if tuning == null:
		tuning = GoldenConvergenceTuning.new()
	display_name = "the helidrones' guns"
	is_obstacle = true
	immune_to_weapons = true
	_streak_mat = GreyboxMaterials.glow(RAKE_COLOR, 3.2, 0.95)
	_curtain_mat = GreyboxMaterials.glow(RAKE_COLOR, 2.2, 0.32)
	_tracer_mat = GreyboxMaterials.glow(TRACER_COLOR, 3.4, 0.8)
	_flare_mat = GreyboxMaterials.glow(Color(1.0, 0.5, 0.3), 4.0, 0.9)
	var geo: TrackGeometry = world.geo
	var lane_w: float = geo.lane_width
	for i: int in RAKES:
		var node := _rig_node("Rake%d" % i)
		var hazard: Hazard = add_hitbox(&"attack", Vector3(lane_w * RAKE_WIDTH_SHARE, RAKE_HEIGHT, RAKE_DEPTH),
			Vector3(0.0, RAKE_HEIGHT * 0.5, 0.0), true, node)
		hazard.hazard_name = "the helidrones' guns"
		hazard.contacted.connect(_on_contacted.bind(&"rake", i))
		# The wall's part, sized when the rake takes an outer lane (_size_wall_hazard).
		var wall_hazard: Hazard = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, node)
		wall_hazard.hazard_name = "the helidrones' guns"
		wall_hazard.contacted.connect(_on_contacted.bind(&"rake_wall", i))
		var streak: MeshInstance3D = _box(node, _streak_mat,
			Transform3D(Basis.from_scale(Vector3(lane_w * 0.34, 0.06, RAKE_DEPTH)), Vector3(0.0, 0.04, 0.0)))
		var flare: MeshInstance3D = _box(node, _flare_mat,
			Transform3D(Basis.from_scale(Vector3(lane_w * 0.5, 0.5, 0.5)), Vector3(0.0, 0.3, 0.0)))
		var wall: MeshInstance3D = _box(node, _streak_mat, Transform3D.IDENTITY)
		rakes.append({"node": node, "hazard": hazard, "wall_hazard": wall_hazard, "streak": streak, "flare": flare,
			"wall": wall, "lane": -1, "on": false, "side": 0})
	for l: int in LINES:
		var root := _rig_node("Line%d" % l)
		var cells: Array[Dictionary] = []
		for k: int in LANES_MAX:
			var cell := Node3D.new()
			cell.name = "Lane%d" % k
			root.add_child(cell)
			var hazard: Hazard = null
			if l == 0:
				hazard = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, cell)
				hazard.hazard_name = "the helidrones' guns"
				hazard.contacted.connect(_on_contacted.bind(&"line", k))
			var streak: MeshInstance3D = _box(cell, _streak_mat, Transform3D.IDENTITY)
			var curtain: MeshInstance3D = _box(cell, _curtain_mat, Transform3D.IDENTITY)
			cells.append({"node": cell, "hazard": hazard, "streak": streak, "curtain": curtain, "on": false})
		var walls: Array[Dictionary] = []
		for side: int in [-1, 1]:
			var wall_hazard: Hazard = null
			if l == 0:
				wall_hazard = add_hitbox(&"attack", Vector3.ONE, Vector3.ZERO, true, root)
				wall_hazard.hazard_name = "the helidrones' guns"
				wall_hazard.contacted.connect(_on_contacted.bind(&"line_wall", side))
			var mesh: MeshInstance3D = _box(root, _streak_mat, Transform3D.IDENTITY)
			walls.append({"hazard": wall_hazard, "mesh": mesh, "on": false, "side": side})
		lines.append({"node": root, "at": 0.0, "live": l == 0, "opening": -1, "lanes": cells, "walls": walls, "on": false})
	for i: int in GoldenConvergenceSquadron.MAX:
		var beam: MeshInstance3D = _box(self, _tracer_mat, Transform3D.IDENTITY)
		beam.top_level = true
		tracers.append({"beam": beam, "on": false})
	_build_scorch()
	clear()


func _rig_node(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.top_level = true
	add_child(node)
	return node


func _box(parent: Node3D, material: Material, xform: Transform3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = GreyboxMaterials.unit_box()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.transform = xform
	mesh.visible = false
	parent.add_child(mesh)
	return mesh


func _build_scorch() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = SCORCH_MAX
	for i: int in SCORCH_MAX:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -300.0, 0.0)))
		mm.set_instance_color(i, Color(SCORCH_COLOR, 0.0))
		_scorches.append({"age": -1.0, "alpha": 0.0})
	_scorch = MultiMeshInstance3D.new()
	_scorch.name = "Scorch"
	_scorch.multimesh = mm
	_scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scorch.top_level = true
	add_child(_scorch)
	_scorch.global_transform = Transform3D.IDENTITY


# --- Vertical passes -------------------------------------------------------------------------------

## Rake `slot` takes `lane` (switched on) or stops (lane -1): its hitboxes on or off.
func set_rake_lane(slot: int, lane: int) -> void:
	var rig: Dictionary = rakes[slot]
	var on: bool = lane >= 0
	rig["on"] = on
	rig["lane"] = lane
	var n: int = world.geo.lane_count
	rig["side"] = (-1 if lane == 0 else (1 if lane == n - 1 else 0)) if on else 0
	(rig["node"] as Node3D).visible = on
	(rig["streak"] as Node3D).visible = on
	(rig["flare"] as Node3D).visible = on
	(rig["hazard"] as Hazard).set_enabled(on)
	var side: int = int(rig["side"])
	(rig["wall_hazard"] as Hazard).set_enabled(on and side != 0)
	if on and side != 0:
		_size_wall_hazard(rig, lane, side)
	if not on:
		(rig["wall"] as Node3D).visible = false
		(rig["node"] as Node3D).global_position = Vector3(0.0, -200.0, 0.0)


## Puts rake `slot`'s fire at track distance `front` in its lane; `wall_open`: the wall beside its outer
## lane is open there (the fire's climb up it is drawn).
func set_rake_front(slot: int, front: float, wall_open: bool) -> void:
	var rig: Dictionary = rakes[slot]
	if not rig["on"]:
		return
	var node: Node3D = rig["node"]
	node.global_position = Vector3(world.geo.lane_x(int(rig["lane"])), 0.0, TrackGeometry.world_z(front))
	var flare: MeshInstance3D = rig["flare"]
	var k: float = 1.0 if Settings.flashing_reduced else 0.75 + 0.35 * absf(sin(_t * 31.0 + float(slot) * 2.0))
	flare.scale = Vector3(world.geo.lane_width * 0.5 * k, 0.5 * k, 0.6 * k)
	var wall: MeshInstance3D = rig["wall"]
	var side: int = int(rig["side"])
	wall.visible = side != 0 and wall_open
	if wall.visible:
		var face: float = side * world.geo.wall_x() - node.global_position.x
		wall.transform = Transform3D(Basis.from_scale(Vector3(0.08, tuning.wall_fire_height, RAKE_DEPTH)),
			Vector3(face - side * 0.05, tuning.wall_fire_height * 0.5, 0.0))


## The wall's part of an outer lane's rake: from the edge of the rake's main box out past the wall's face,
## from the floor up to wall_fire_height (a wall runner whose feet are above it is safe).
func _size_wall_hazard(rig: Dictionary, lane: int, side: int) -> void:
	var geo: TrackGeometry = world.geo
	var inner: float = geo.lane_width * RAKE_WIDTH_SHARE * 0.5
	var outer: float = absf(side * geo.wall_x() - geo.lane_x(lane)) + 0.45
	var hazard: Hazard = rig["wall_hazard"]
	var size := Vector3(outer - inner, tuning.wall_fire_height, RAKE_DEPTH)
	_resize(hazard, size)
	hazard.position = Vector3(side * (inner + outer) * 0.5, tuning.wall_fire_height * 0.5, 0.0)


# --- Horizontal passes -----------------------------------------------------------------------------

## Line `line` (0: the live one; 1 and up: for show) lies across the track at track distance `at`, every
## lane but `opening` (-1: none); nothing of it burns yet (set_line_lane).
func set_line(line: int, at: float, opening: int) -> void:
	var rig: Dictionary = lines[line]
	var geo: TrackGeometry = world.geo
	rig["at"] = at
	rig["opening"] = opening
	rig["on"] = true
	var root: Node3D = rig["node"]
	root.visible = true
	root.global_position = Vector3(0.0, 0.0, TrackGeometry.world_z(at))
	var depth: float = tuning.line_depth
	var n: int = geo.lane_count
	var cells: Array = rig["lanes"]
	for k: int in cells.size():
		var cell: Dictionary = cells[k]
		cell["on"] = false
		(cell["node"] as Node3D).visible = false
		if cell["hazard"] != null:
			(cell["hazard"] as Hazard).set_enabled(false)
		if k >= n:
			continue
		var span: Vector2 = Vector2(geo.lane_x(k) - geo.lane_width * 0.5, geo.lane_x(k) + geo.lane_width * 0.5)
		if k == 0:
			span.x = -geo.wall_x() - 0.4
		if k == n - 1:
			span.y = geo.wall_x() + 0.4
		var mid: float = (span.x + span.y) * 0.5
		var w: float = span.y - span.x
		(cell["node"] as Node3D).position = Vector3(mid, 0.0, 0.0)
		(cell["streak"] as Node3D).transform = Transform3D(Basis.from_scale(Vector3(w, 0.06, depth * 0.7)), Vector3(0.0, 0.045, 0.0))
		(cell["curtain"] as Node3D).transform = Transform3D(Basis.from_scale(Vector3(w, tuning.line_height, 0.08)),
			Vector3(0.0, tuning.line_height * 0.5, 0.0))
		if cell["hazard"] != null:
			var hazard: Hazard = cell["hazard"]
			_resize(hazard, Vector3(w, tuning.line_height, depth))
			hazard.position = Vector3(0.0, tuning.line_height * 0.5, 0.0)
	for wall: Dictionary in rig["walls"]:
		var side: int = int(wall["side"])
		wall["on"] = false
		(wall["mesh"] as Node3D).visible = false
		(wall["mesh"] as Node3D).transform = Transform3D(Basis.from_scale(Vector3(0.08, tuning.wall_line_height, depth * 0.7)),
			Vector3(side * (geo.wall_x() + 0.02), tuning.wall_line_height * 0.5, 0.0))
		if wall["hazard"] != null:
			var hazard: Hazard = wall["hazard"]
			_resize(hazard, Vector3(1.2, tuning.wall_line_height, depth))
			hazard.position = Vector3(side * (geo.wall_x() + 0.1), tuning.wall_line_height * 0.5, 0.0)
			hazard.set_enabled(false)


## The sweep has reached lane `lane` of line `line` (on) or its fire is out (off). The opening never burns.
func set_line_lane(line: int, lane: int, on: bool) -> void:
	var rig: Dictionary = lines[line]
	if lane < 0 or lane >= world.geo.lane_count or lane == int(rig["opening"]):
		return
	var cell: Dictionary = (rig["lanes"] as Array)[lane]
	cell["on"] = on
	(cell["node"] as Node3D).visible = on
	(cell["streak"] as Node3D).visible = on
	(cell["curtain"] as Node3D).visible = on
	if cell["hazard"] != null:
		(cell["hazard"] as Hazard).set_enabled(on)


## The line's fire up the wall on `side` (live line: at every height), drawn where the wall is open.
func set_line_wall(line: int, side: int, on: bool, wall_open: bool) -> void:
	var rig: Dictionary = lines[line]
	for wall: Dictionary in rig["walls"]:
		if int(wall["side"]) != side:
			continue
		wall["on"] = on
		(wall["mesh"] as Node3D).visible = on and wall_open
		if wall["hazard"] != null:
			(wall["hazard"] as Hazard).set_enabled(on)


## Line `line`'s fire is out.
func stop_line(line: int) -> void:
	var rig: Dictionary = lines[line]
	rig["on"] = false
	for k: int in LANES_MAX:
		var cell: Dictionary = (rig["lanes"] as Array)[k]
		cell["on"] = false
		(cell["node"] as Node3D).visible = false
		if cell["hazard"] != null:
			(cell["hazard"] as Hazard).set_enabled(false)
	for wall: Dictionary in rig["walls"]:
		wall["on"] = false
		(wall["mesh"] as Node3D).visible = false
		if wall["hazard"] != null:
			(wall["hazard"] as Hazard).set_enabled(false)
	(rig["node"] as Node3D).global_position = Vector3(0.0, -200.0, 0.0)


## True if any part of line `line` burns in `lane` now (its hitbox's live, for the live line).
func line_lane_on(line: int, lane: int) -> bool:
	var cells: Array = lines[line]["lanes"]
	return lane >= 0 and lane < cells.size() and bool((cells[lane] as Dictionary)["on"])


# --- Tracers -----------------------------------------------------------------------------------------

## Drone `i`'s tracer from `from` (its muzzle) to `to` (where it rakes), world space.
func set_tracer(i: int, from: Vector3, to: Vector3) -> void:
	var rig: Dictionary = tracers[i]
	var beam: MeshInstance3D = rig["beam"]
	var along: Vector3 = to - from
	var length: float = along.length()
	if length < 0.1:
		beam.visible = false
		return
	# A flicker along the tracer (steady with Reduced flashing: the beam just stays on).
	var width: float = 0.11 if Settings.flashing_reduced else 0.07 + 0.06 * absf(sin(_t * 47.0 + float(i) * 1.3))
	var up: Vector3 = Vector3.UP if absf((along / length).dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	beam.global_transform = Transform3D(Basis.looking_at(along / length, up) * Basis.from_scale(Vector3(width, width, length)),
		(from + to) * 0.5)
	beam.visible = true
	rig["on"] = true


func hide_tracer(i: int) -> void:
	var rig: Dictionary = tracers[i]
	(rig["beam"] as Node3D).visible = false
	rig["on"] = false


# --- Scorch marks ------------------------------------------------------------------------------------

## A scorch mark along `lane` from track distance `a` to `b` (a rake's): returns its id (update_scorch).
func scorch_lane(lane: int, a: float, b: float) -> int:
	var x: float = world.geo.lane_x(lane)
	var half: float = SCORCH_WIDTH * 0.5
	return _new_scorch(x - half, x + half, a, b)


## A scorch mark across the track at `at` (a line's), from world x `x0` to `x1`.
func scorch_line(at: float, x0: float, x1: float) -> int:
	var half: float = SCORCH_DEPTH * 0.5
	return _new_scorch(x0, x1, at - half, at + half)


## Moves scorch mark `id` to cover track distances [a, b] (a rake's grows behind its front).
func update_scorch(id: int, a: float, b: float) -> void:
	if id < 0:
		return
	var s: Dictionary = _scorches[id]
	s["a"] = minf(a, b)
	s["b"] = maxf(a, b)
	_place_scorch(id)


func _new_scorch(x0: float, x1: float, a: float, b: float) -> int:
	var id: int = _next_scorch
	_next_scorch = (_next_scorch + 1) % SCORCH_MAX
	_scorches[id] = {"x0": minf(x0, x1), "x1": maxf(x0, x1), "a": minf(a, b), "b": maxf(a, b), "age": 0.0,
		"alpha": SCORCH_ALPHA}
	_place_scorch(id)
	return id


func _place_scorch(id: int) -> void:
	var s: Dictionary = _scorches[id]
	var mm: MultiMesh = _scorch.multimesh
	var w: float = float(s["x1"]) - float(s["x0"])
	var l: float = maxf(float(s["b"]) - float(s["a"]), 0.01)
	mm.set_instance_transform(id, Transform3D(Basis.from_scale(Vector3(w, 1.0, l)),
		Vector3((float(s["x0"]) + float(s["x1"])) * 0.5, SCORCH_Y, TrackGeometry.world_z((float(s["a"]) + float(s["b"])) * 0.5))))
	mm.set_instance_color(id, Color(SCORCH_COLOR, float(s["alpha"])))


## The scorch marks still showing (tests): {x0, x1, a, b, alpha}.
func scorch_marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in _scorches:
		if float(s.get("age", -1.0)) >= 0.0 and float(s.get("alpha", 0.0)) > 0.0:
			out.append(s)
	return out


func _tick(delta: float) -> void:
	_t += delta
	var fade: float = SCORCH_ALPHA / maxf(tuning.scorch_seconds, 0.5)
	var mm: MultiMesh = _scorch.multimesh
	for i: int in _scorches.size():
		var s: Dictionary = _scorches[i]
		if float(s.get("age", -1.0)) < 0.0:
			continue
		s["age"] = float(s["age"]) + delta
		# Full for half its life, then fading out.
		if float(s["age"]) > tuning.scorch_seconds * 0.5:
			s["alpha"] = maxf(float(s["alpha"]) - fade * 2.0 * delta, 0.0)
			mm.set_instance_color(i, Color(SCORCH_COLOR, float(s["alpha"])))
			if float(s["alpha"]) <= 0.0:
				s["age"] = -1.0
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -300.0, 0.0)))


## Everything off: no rake, no line, no tracer burns (the scorch marks fade on).
func clear() -> void:
	for i: int in rakes.size():
		set_rake_lane(i, -1)
	for l: int in lines.size():
		stop_line(l)
	for i: int in tracers.size():
		hide_tracer(i)


## True if any of its fire can hurt now.
func live() -> bool:
	for rig: Dictionary in rakes:
		if rig["on"]:
			return true
	for cell: Dictionary in lines[0]["lanes"]:
		if cell["on"]:
			return true
	for wall: Dictionary in lines[0]["walls"]:
		if wall["on"]:
			return true
	return false


## Every hitbox of its fire (tests: none is live outside a warned lane or the live line).
func hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for rig: Dictionary in rakes:
		out.append(rig["hazard"])
		out.append(rig["wall_hazard"])
	for line: Dictionary in lines:
		for cell: Dictionary in line["lanes"]:
			if cell["hazard"] != null:
				out.append(cell["hazard"])
		for wall: Dictionary in line["walls"]:
			if wall["hazard"] != null:
				out.append(wall["hazard"])
	return out


func _on_contacted(outcome: int, kind: StringName, index: int) -> void:
	if outcome == DamageRules.Outcome.IGNORE:
		return
	var lane: int = index
	if kind == &"rake" or kind == &"rake_wall":
		lane = int(rakes[index]["lane"])
	var entry := {"kind": kind, "lane": lane, "outcome": outcome, "runner": world.player.distance,
		"h": world.player.h, "surface": world.player.surface}
	hits.append(entry)
	hit.emit(kind, lane, outcome)


## A hazard's box resized (the shape is its first child).
static func _resize(hazard: Hazard, size: Vector3) -> void:
	hazard.size = size
	var shape := hazard.get_child(0) as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		(shape.shape as BoxShape3D).size = size


## Never a target.
func targetable() -> bool:
	return false


## The fight is won: the fire stops.
func _on_defeated(_cause: StringName) -> void:
	clear()
