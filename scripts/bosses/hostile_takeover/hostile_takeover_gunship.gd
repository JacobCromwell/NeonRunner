class_name HostileTakeoverGunship
extends BossPart
## Hostile Takeover's body (GDD §10: "a military gunship paces the train overhead"): the boss's health is
## the fight's (BossPart), so weapon hits on it chip the boss up to BossDef.weapon_share_cap ("weapons chip;
## stomps do the real damage": the stomps are the couplings', HostileTakeoverCouplings). Its model
## (HostileTakeoverModel.gunship) is built to the train's width, its belly as wide as the train.
## The encounter flies it (set_pose: relative to the runner, so nothing depends on how long the fight has
## lasted). It has no hitboxes in phase 1: it flies far over the roofs. Phase 2 (task E5b-b) makes its
## belly a ceiling (add_surface(..., true)) and gives it its attacks; phase 3 (task E5b-c) docks it onto
## the locomotive.
## Declared, never special-cased (CLAUDE.md principle 8): a boss's part, claw-immune, the dash passes it.

var tuning: HostileTakeoverTuning
var model: MeshInstance3D
var belly_width: float = 8.0


func _build() -> void:
	var params: Dictionary = spawn.get("params", {})
	tuning = params.get("tuning") as HostileTakeoverTuning
	if tuning == null:
		tuning = HostileTakeoverTuning.new()
	belly_width = world.geo.wall_x() * 2.0
	model = MeshBatch.add_instance(self, HostileTakeoverModel.gunship(belly_width, world.skin), "Model")


## Flies it with its belly's middle at `pos` (world space), banked by `roll` and pitched by `pitch`
## (radians; its nose ahead, -z).
func set_pose(pos: Vector3, roll: float, pitch: float) -> void:
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, 0.0, roll)), pos)


## Weapons aim at its hull's middle.
func aim_point() -> Vector3:
	return global_transform * Vector3(0.0, 0.9 + HostileTakeoverModel.GUNSHIP_HULL_HEIGHT * 0.5, 2.0)


## Its hull is big: a shot within this of its middle hits it.
func hit_radius() -> float:
	return 4.5


## Where it is along the track (its middle).
func track_distance() -> float:
	return -global_position.z
