class_name MarketCrowd
extends Node3D
## The citizens standing in the shop windows of one wall section (GDD §5, "Citizens"; task L7): one MultiMeshInstance3D of the
## baked person (MarketPeople), one instance per citizen, so a section's whole crowd is one draw call and a handful of nodes,
## however many of them there are. Scenery only: no collision, no gameplay, nothing here reads the player but through
## MarketPeople (the runner's place, for the heads to follow). Placed from the windows' own track positions
## (MarketCitizens), so a chunk builds the same crowd every time.
##
## Every crowd joins the "market_citizens" group (MarketPeople.GROUP) with a public react(kind), the hook for The House
## (E5a, GDD §10: "the citizens in the shop windows cheer and duck throughout"): &"cheer" and &"startled".

## One entry per person: pos (their feet, in the parent's space), heading (radians about +y: the way they face, their front
## being local -z), scale (their own size), look, phase and late (0-1, their seeds: the shader dresses and times them), at
## (the track distance of their window).
var people: Array[Dictionary] = []
var instances: MultiMeshInstance3D


func setup(p_people: Array[Dictionary]) -> void:
	name = "Crowd"
	people = p_people
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = MarketPeople.mesh()
	mm.instance_count = people.size()
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for i: int in people.size():
		var p: Dictionary = people[i]
		var at: Vector3 = p["pos"]
		var basis: Basis = Basis(Vector3.UP, float(p["heading"])) * Basis.from_scale(p["scale"])
		mm.set_instance_transform(i, Transform3D(basis, at))
		mm.set_instance_custom_data(i, Color(float(p["look"]), float(p["phase"]), float(p["late"]), 0.0))
		low = low.min(at)
		high = high.max(at)
	instances = MultiMeshInstance3D.new()
	instances.name = "People"
	instances.multimesh = mm
	instances.material_override = MarketPeople.material()
	instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Their bounds never need working out from the instances: the people stand, hop and turn within a metre or so.
	instances.custom_aabb = AABB(low - Vector3(1.0, 0.1, 1.0), high - low + Vector3(2.0, 2.6, 2.0))
	add_child(instances)
	add_to_group(MarketPeople.GROUP)


## Every person of every crowd directly under `parent` (what MarketCitizens.build() built there), in order: for tests.
static func people_under(parent: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child: Node in parent.get_children():
		if child is MarketCrowd:
			out.append_array((child as MarketCrowd).people)
	return out


## Where each person stands (their feet, in the world: the crowd sits at its parent's origin), for reviews and tests.
func spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Dictionary in people:
		out.append(global_transform * (p["pos"] as Vector3))
	return out


## Cheer (&"cheer") or flinch (&"startled") now, those within reach of the runner: the hook The House calls on the group.
func react(kind: StringName) -> void:
	MarketPeople.react(kind)


func _process(delta: float) -> void:
	MarketPeople.tick(self, delta)
