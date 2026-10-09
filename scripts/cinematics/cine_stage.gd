class_name CineStage
extends Node3D
## The set a cinematic plays on: a stretch of a zone built by the track builder in the zone's skin (the
## same pieces, meshes and shaders as its levels), under the zone's sky and fog and the run's sun, so it
## looks like the levels around it on either renderer. Built from a CineStageDef; the sequencer streams
## its chunks as the camera and the actors move along (update()), as a run does.
##
## Track space, which every cinematic point uses: x metres right of the start lane's centre (the lane a
## level's runner starts in, lane_count / 2), y metres up from the floor, z metres along the track.
## World space: x the same plus the start lane's offset, y the same, z = -distance.

## The sun LevelRun lights a level with, so actors and scenery are lit as in play.
const SUN_ROTATION := Vector3(-55.0, 25.0, 0.0)
const SUN_ENERGY: float = 0.7
## Lanes when there's no App to ask (a scene played on its own): the PC count.
const DEFAULT_LANES: int = 5

var def: CineStageDef
var skin: ZoneSkin
var tuning: MovementTuning
var geo: TrackGeometry
var layout: LevelLayout
var track: TrackBuilder
var environment: Environment
## The start lane, and its centre's world x (track space's origin).
var start_lane: int = 0
var origin_x: float = 0.0


## Builds the stretch: `p_skin` dresses it (skin_for() finds a slot's), in `lanes` lanes (0: the
## device's count, lanes_for()).
func build(p_def: CineStageDef, p_skin: ZoneSkin, p_tuning: MovementTuning, lanes: int = 0) -> void:
	def = p_def
	skin = p_skin if p_skin != null else GreyboxSkin.new()
	tuning = p_tuning
	var count: int = lanes if lanes > 0 else lanes_for(def)
	geo = TrackGeometry.new(count, tuning)
	start_lane = count / 2
	origin_x = geo.lane_x(start_lane)
	layout = LevelLayout.new()
	layout.lane_count = count
	layout.length = def.length
	for c: Vector2 in def.ceilings:
		layout.hulls.append({"start": minf(c.x, c.y), "end": maxf(c.x, c.y)})
	for g: Vector3 in def.gaps:
		var lane: int = lane_from_start(g.x)
		if lane >= 0:
			layout.gaps.append({"lane": lane, "start": minf(g.y, g.z), "end": maxf(g.y, g.z)})
	for p: Vector2 in def.pads:
		var lane: int = lane_from_start(p.x)
		if lane >= 0:
			layout.pads.append({"lane": lane, "at": p.y})
	for w: Vector3 in def.wall_gaps:
		if not is_zero_approx(w.x):
			layout.wall_gaps.append({"side": int(signf(w.x)), "start": minf(w.y, w.z), "end": maxf(w.y, w.z)})
	track = TrackBuilder.new()
	track.name = "Track"
	add_child(track)
	track.set_layout(layout, tuning, skin)
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	# The zone's own light, as its levels build it (darkness 0 also sets the scenery light back to 1).
	environment = skin.level_environment(0.0)
	world_env.environment = environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ROTATION
	sun.light_energy = SUN_ENERGY
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)


## Builds the chunks the camera and the actors can see: from `near` (the nearest of them along the
## track) to the track builder's reach ahead of it; chunks well behind it are freed. `time` is the
## cinematic's clock (pulsing pieces follow it).
func update(near: float, time: float) -> void:
	track.update(maxf(near, 0.0), time)


## Takes it out of view as its cinematic ends: hidden (the scenery and the sun), and its environment out
## of the world, so the next step's own lights up the next frame alone.
func retire() -> void:
	visible = false
	var world_env: Node = get_node_or_null(^"Environment")
	if world_env != null:
		remove_child(world_env)
		world_env.queue_free()


## A track-space point in world space.
func point(p: Vector3) -> Vector3:
	return Vector3(origin_x + p.x, p.y, -p.z)


## A world-space point in track space.
func to_track(world: Vector3) -> Vector3:
	return Vector3(world.x - origin_x, world.y, -world.z)


## The lane `offset` lanes from the start lane (rounded), or -1 past the street's edge.
func lane_from_start(offset: float) -> int:
	var lane: int = start_lane + roundi(offset)
	return lane if lane >= 0 and lane < geo.lane_count else -1


## Track-space x of a lane's centre.
func lane_x(lane: int) -> float:
	return geo.lane_x(lane) - origin_x


## Track-space x of each wall's face (-1 left, 1 right).
func wall_x(side: int) -> float:
	return side * geo.wall_x() - origin_x


## The ceiling over `distance` along the track as (start, end), or Vector2.ZERO if there's none.
func ceiling_over(distance: float, margin: float = 0.0) -> Vector2:
	for h: Dictionary in layout.hulls:
		if distance >= float(h["start"]) - margin and distance <= float(h["end"]) + margin:
			return Vector2(h["start"], h["end"])
	return Vector2.ZERO


## True if wall `side` (-1 left, 1 right) is open around `distance` (a wall gap, within `margin`).
func wall_open(side: int, distance: float, margin: float = 0.0) -> bool:
	return not layout.wall_gap_spans(side, distance - margin, distance + margin).is_empty()


## True if `lane` has a hole around `distance` (within `margin`).
func gap_at(lane: int, distance: float, margin: float = 0.0) -> bool:
	return layout.gapped_between(lane, distance - margin, distance + margin)


## Lanes for a stage: its own count, or as many as a level on this device has (App.lane_count()).
static func lanes_for(p_def: CineStageDef) -> int:
	if p_def != null and p_def.lanes > 0:
		return p_def.lanes
	var tree := Engine.get_main_loop() as SceneTree
	var app: Node = tree.root.get_node_or_null(^"App") if tree != null and tree.root != null else null
	if app != null and app.has_method(&"lane_count"):
		return int(app.call(&"lane_count"))
	return DEFAULT_LANES


## The look a cinematic's stage takes from its slot's data (`p_def` has none of its own): before a boss
## the fight arena's skin if it has one (a boss arena may have its own, BossDef.arena), otherwise the
## zone's skin (ZoneDef.skin). Null without a zone.
static func skin_for(p_def: CineStageDef, zone: ZoneDef, slot: StringName) -> ZoneSkin:
	if p_def != null and p_def.skin != null:
		return p_def.skin
	if zone == null:
		return null
	if slot == &"boss_intro" and zone.boss != null and zone.boss.arena != null and zone.boss.arena.skin != null:
		return zone.boss.arena.skin
	return zone.skin
