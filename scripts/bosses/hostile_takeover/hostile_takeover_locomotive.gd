class_name HostileTakeoverLocomotive
extends BossPart
## The locomotive leading the Chairman's train (GDD §10: the runner "runs forward along it toward the
## locomotive"; "the player gets a glimpse of him: in the locomotive's window during the fight"): an
## armoured power car as wide as the train (HostileTakeoverModel.locomotive), and the Chairman standing in
## the suite behind its rear window, watching the runner (HostileTakeoverModel.chairman). The encounter
## keeps it far ahead of the runner (set_front: HostileTakeoverTuning.loco_ahead), past the guards' spawn
## lead, so it's the head of the train at the end of the view. Phase 3 (task E5b-c) brings it closer: the
## gunship docks onto it with huge clamps.
## A part of the boss (shares its health): it has no hitboxes in phase 1, and it's beyond any weapon's reach.

var tuning: HostileTakeoverTuning
var model: MeshInstance3D
var chairman: MeshInstance3D
## Where its rear face is along the track.
var front_at: float = 0.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as HostileTakeoverTuning
	if tuning == null:
		tuning = HostileTakeoverTuning.new()
	is_obstacle = true
	var width: float = world.geo.wall_x() * 2.0
	model = MeshBatch.add_instance(self, HostileTakeoverModel.locomotive(width, world.skin), "Model")
	chairman = MeshBatch.add_instance(self, HostileTakeoverModel.chairman(world.skin), "Chairman",
		HostileTakeoverModel.chairman_spot())


## Puts its rear face at track distance `at`, on the track's middle at the roofs' plane.
func set_front(at: float) -> void:
	front_at = at
	global_position = Vector3(0.0, 0.0, TrackGeometry.world_z(at))


## The Chairman's head, in world space (reviews and tests).
func chairman_head() -> Vector3:
	return chairman.global_transform * Vector3(0.0, HostileTakeoverModel.CHAIRMAN_HEIGHT * 0.95, 0.0)


func track_distance() -> float:
	return front_at


## Far ahead in phase 1: never a weapon's target there.
func targetable() -> bool:
	return false
