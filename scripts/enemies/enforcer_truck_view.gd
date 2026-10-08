class_name EnforcerTruckView
extends RefCounted
## What the chase camera sees of the Enforcer Truck (GDD §9.13 "Showing itself", owner, October 8, 2026): the
## run camera's resting view of a runner on the floor in a lane (RunCamera at rest: MovementTuning's camera
## height, distance, look-ahead and sideways follow, its base field of view, on a 16:9 screen), and what's on
## screen in it or hidden behind a box. The truck shows itself only in a lane where its whole look fits on
## screen and hides neither the runner nor the floor of their lane and the lanes past it (fits(); every lane
## and lane count is checked by tests/suites/test_enforcer_truck.gd). The base field of view is the narrowest
## the camera has (it widens with speed), and a wider screen (a phone) shows more at the sides; 4:3 shows less,
## and only 6 lanes (PC only) come near its edges. The blast (EnforcerTruckBlast) is checked in it too.
## Plain arithmetic, no camera node: the same on every machine and in a headless run, so a seeded run decides
## the same way on every screen.

## The screen's shape the truck is placed for (the PC's; phones are wider).
const ASPECT: float = 16.0 / 9.0
## How far inside the screen's edges its look must stay (a share of the half-width and half-height): room for
## the camera's lean into a lane change and its easing after the runner.
const MARGIN: float = 0.05

var origin: Vector3
var basis: Basis
var tan_half_y: float = 1.0
var tan_half_x: float = 1.0


## The resting view of a runner on the floor in `lane` at track distance `distance`.
static func of_runner(t: MovementTuning, geo: TrackGeometry, lane: int, distance: float) -> EnforcerTruckView:
	var v := EnforcerTruckView.new()
	var x: float = geo.lane_x(lane) * t.camera_follow_x
	var z: float = TrackGeometry.world_z(distance)
	v.origin = Vector3(x, t.camera_height, z + t.camera_distance)
	var target := Vector3(x, 1.0, z - t.camera_look_ahead)
	v.basis = Basis.looking_at(target - v.origin, Vector3.UP)
	v.tan_half_y = tan(deg_to_rad(t.camera_fov) * 0.5)
	v.tan_half_x = v.tan_half_y * ASPECT
	return v


## `p` in the camera's space (it looks down -z).
func to_camera(p: Vector3) -> Vector3:
	return basis.transposed() * (p - origin)


## Where `p` lands on the screen, from -1 to 1 across and up (beyond for off screen); Vector2(INF, INF) behind
## the camera.
func screen(p: Vector3) -> Vector2:
	var c: Vector3 = to_camera(p)
	if c.z > -0.05:
		return Vector2(INF, INF)
	return Vector2(c.x / (-c.z * tan_half_x), c.y / (-c.z * tan_half_y))


## True if `p` is on screen, `margin` (a share of the half-width and half-height) inside its edges.
func on_screen(p: Vector3, margin: float = MARGIN) -> bool:
	var s: Vector2 = screen(p)
	return absf(s.x) <= 1.0 - margin and absf(s.y) <= 1.0 - margin


## True if `box` (world space) stands between the camera and `p`.
func hides(box: AABB, p: Vector3) -> bool:
	var to: Vector3 = origin + (p - origin) * 0.995
	return box.intersects_segment(origin, to) != null


## True if any of `boxes` stands between the camera and `p`.
func hidden(boxes: Array[AABB], p: Vector3) -> bool:
	for b: AABB in boxes:
		if hides(b, p):
			return true
	return false


## The truck's look, as boxes in world space (EnforcerTruckModel.profile: its body and each rider), its front at
## track distance `front` in the middle of world x `x`.
static func truck_boxes(profile: Array[AABB], x: float, front: float) -> Array[AABB]:
	var out: Array[AABB] = []
	var at := Vector3(x, 0.0, TrackGeometry.world_z(front))
	for b: AABB in profile:
		out.append(AABB(b.position + at, b.size))
	return out


## The corners of `boxes` (world space).
static func corners(boxes: Array[AABB]) -> PackedVector3Array:
	var out := PackedVector3Array()
	for b: AABB in boxes:
		for i: int in 8:
			out.append(b.get_endpoint(i))
	return out


## The runner's look standing on the floor in the middle of world x `x` at track distance `distance` (its
## visual size, MovementTuning.visual_size): its corners and its middle.
static func runner_points(t: MovementTuning, x: float, distance: float) -> PackedVector3Array:
	var s: Vector3 = t.visual_size
	var z: float = TrackGeometry.world_z(distance)
	var out := PackedVector3Array()
	for dx: float in [-0.5, 0.5]:
		for y: float in [0.0, 1.0]:
			for dz: float in [-0.5, 0.5]:
				out.append(Vector3(x + dx * s.x, y * s.y, z + dz * s.z))
	out.append(Vector3(x, s.y * 0.5, z))
	return out


## Whether the truck shows itself well in `truck_lane` beside a runner in `runner_lane` at `lanes` lanes, its
## front `ahead` metres ahead of them: {fits (every corner of its look on screen), hides_runner (it stands
## between the camera and the runner), hides_floor (it hides a point of the floor, or anything up to 2 m above
## it, in the runner's lane or a lane past it on the far side from the truck, from the runner to `reach` metres
## ahead), worst (the on-screen corner nearest the screen's edge)}. `profile`: EnforcerTruckModel.profile().
static func check(t: MovementTuning, lanes: int, runner_lane: int, truck_lane: int, ahead: float,
		profile: Array[AABB], reach: float = 60.0) -> Dictionary:
	var geo := TrackGeometry.new(lanes, t)
	var view: EnforcerTruckView = of_runner(t, geo, runner_lane, 0.0)
	var boxes: Array[AABB] = truck_boxes(profile, geo.lane_x(truck_lane), ahead)
	var fits: bool = true
	var worst: float = 0.0
	for p: Vector3 in corners(boxes):
		var s: Vector2 = view.screen(p)
		worst = maxf(worst, maxf(absf(s.x), absf(s.y)))
		fits = fits and view.on_screen(p)
	var hides_runner: bool = false
	for p: Vector3 in runner_points(t, geo.lane_x(runner_lane), 0.0):
		hides_runner = hides_runner or view.hidden(boxes, p)
	var hides_floor: bool = false
	var away: int = signi(runner_lane - truck_lane)
	var l: int = runner_lane
	while l >= 0 and l < lanes and not hides_floor:
		var d: float = 1.0
		while d <= reach and not hides_floor:
			for y: float in [0.05, 1.0, 2.0]:
				hides_floor = hides_floor or view.hidden(boxes, Vector3(geo.lane_x(l), y, TrackGeometry.world_z(d)))
			d += 1.0
		l += away
	return {"fits": fits, "hides_runner": hides_runner, "hides_floor": hides_floor, "worst": worst}
