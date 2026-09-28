class_name SlowTestSkin
extends GreyboxSkin
## A test-only skin (T-BUDGET): draws exactly like GreyboxSkin, but floor_segment() also busy-waits
## `extra_usec` of real wall-clock time. Proves SkinSuite.whole_level()'s build-time budget check
## still catches a skin that got expensive, even measured as the minimum of several passes
## (SkinSuite.BUILD_TIMING_PASSES): a busy-wait against Time.get_ticks_usec() always burns at least
## `extra_usec`, no matter how the OS schedules the process around it, so every pass -- and so the
## minimum across passes -- carries the full added cost.

## Burned once per lane per chunk (floor_segment is called once per lane's floor piece), so a 3-lane
## chunk alone adds about 3x this to its build time -- comfortably over BUILD_BUDGET_MEAN_MS.
var extra_usec: int = 2000


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	super.floor_segment(parent, center, size, lane_x, edge_start, edge_end)
	var until: int = Time.get_ticks_usec() + extra_usec
	while Time.get_ticks_usec() < until:
		pass
