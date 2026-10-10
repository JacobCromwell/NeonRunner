class_name MechaGuppyStairs
extends Node3D
## Builds the climb (MechaGuppyClimb's plan) within sight as the runner goes, through the boss's props (BossProps,
## freed once passed), and answers questions about it (GDD §10, Mecha Guppy and Captain Cogs; task E5e-b1):
## - each roof: its top (BossProps.roof: a box on the floor layer, down to the street) over each run of lanes that
##   starts together; its sides a lane blocker below its top (a lane switch into a roof's side from below its top
##   is a blocked move: the clank and a bump, as into a truck's side), and its front solid below where a runner
##   could still step up onto it (a Hazard, `is_solid`, that the dash doesn't pass: what looks like a hit is a
##   hit). DESIGN-TBD (docs/questions/e5e.md): the roof faces' rules. The plan keeps every front out of a living
##   runner's way: a wrong drop is dead or saved before it gets there; only a runner who steps off the side of a
##   roof's lanes that reach back, into the gap beside them, can fall into the front of the lanes beyond;
## - each step: its pad strip across every lane at the end of its roof (an anti-grav pad per lane, as long as the
##   strip), its hut (BossProps.ceiling_lanes: each lane ends at its own distance, one section per run of lanes
##   ending together), and the basin Mecha Guppy has eaten into the roof below the hut (look only: no floor, a
##   fall);
## - the top (phase 3's stub): the last roof runs on, built in segments.
## The look comes from the arena's skin when it's the Beach's (MechaGuppyLooks: tiki bar roofs on stacked shacks,
## hovering tiki huts, the basins' dark water, a few neon signs); any other skin gets grey boxes (reviews).
## Every frame it keeps the floor the runner's falls count from (Player.floor_base) at the roof of the step they're
## in, so a fall off any roof ends as far below it as a fall into the street's pits (task E5e-a).

## A roof's lane blocker stops this far under its top, so a runner on the roof never touches it.
const BLOCKER_GAP: float = 0.05
## A roof's solid front reaches up to this far under the depth a runner can still step up onto it from
## (MovementTuning.pit_depth): a falling runner just saved by the grapple (lifted to pit_depth under the top, a
## frame's fall at most below it) never touches it.
const FRONT_DROP: float = 0.12
## How deep a front's hitbox is along the track, and how far in from its lanes' edges.
const FRONT_DEPTH: float = 0.3
const FRONT_INSET: float = 0.05
## Roof 0 (the street the fight starts on): from this far behind the start, a slab this thick.
const STREET_BEHIND: float = 70.0
const STREET_DEPTH: float = 0.1
## The top (phase 3) is built in segments this long.
const TOP_SEGMENT: float = 160.0
## A pickup lands this far (metres at 18 m/s) past where a rider lands on a roof, and this far short of the hut
## over its next pads.
const PICKUP_AFTER_LAND: float = 6.0
const PICKUP_BEFORE_HUT: float = 6.0
## A grapple's save looks for the higher roof under a lane that leads up this far either side of where the runner
## comes down (metres).
const SAVE_MARGIN: float = 2.0

var boss: MechaGuppy
var world: RunWorld
var climb: MechaGuppyClimb
var props: BossProps
var tuning: MechaGuppyTuning
## The climb's look (MechaGuppyLooks) on the Beach's skin, or null: grey boxes.
var looks: MechaGuppyLooks

## Built so far: roofs by index (the top: how far its segments reach), steps by index.
var _roofs_built: Dictionary = {}
var _steps_built: Dictionary = {}


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	world = boss.world
	climb = boss.climb
	props = boss.props
	tuning = boss.tuning
	top_level = true
	transform = Transform3D.IDENTITY
	var beach := world.skin as BeachSkin
	if beach != null:
		looks = MechaGuppyLooks.new(beach, world.geo, world.tuning)
	update(world.player.distance)


func _physics_process(_delta: float) -> void:
	if world == null or world.player == null:
		return
	update(world.player.distance)


## Plans and builds everything that starts within build_ahead of track distance `d`, and keeps the runner's floor
## base at the roof of the step they're in.
func update(d: float) -> void:
	var ahead: float = d + tuning.build_ahead
	climb.plan_until(ahead, boss.phase_index, boss.top_due())
	for step: MechaGuppyClimb.Step in climb.steps:
		var roof: MechaGuppyClimb.Roof = climb.roofs[step.index]
		if roof.first_start() < ahead or step.index == 0:
			_build_roof(roof, ahead)
		if not step.top and step.hut_start < ahead and not _steps_built.has(step.index):
			_build_step(step)
	var base: MechaGuppyClimb.Step = climb.step_at(d)
	if base != null and world.player != null:
		world.player.floor_base = base.top_y


# --- Roofs -----------------------------------------------------------------------------------------

## Builds roof `roof` whole once its end is known (its step planned), or the top's next segments up to `ahead`.
func _build_roof(roof: MechaGuppyClimb.Roof, ahead: float) -> void:
	var top_roof: bool = roof.end >= MechaGuppyClimb.FAR * 0.5
	var built: float = float(_roofs_built.get(roof.index, -MechaGuppyClimb.FAR))
	if not top_roof:
		if built > -MechaGuppyClimb.FAR:
			return
		_roofs_built[roof.index] = roof.end
		_roof_pieces(roof, roof.end, true)
		return
	# The top: its first segment with its fronts, then plain segments as the runner comes.
	if built <= -MechaGuppyClimb.FAR:
		var first_end: float = roof.full_from() + TOP_SEGMENT
		if roof.index == 0:
			first_end = maxf(first_end, world.player.distance + TOP_SEGMENT)
		_roofs_built[roof.index] = first_end
		_roof_pieces(roof, first_end, true)
		built = first_end
	while built < ahead:
		var next: float = built + TOP_SEGMENT
		_top_segment(roof, built, next)
		built = next
		_roofs_built[roof.index] = built


## Roof `roof`'s pieces from its starts to `end`: a top over each run of lanes starting together (roof 0, the
## street, a thin slab from behind the start), with its lane blocker and solid front (not roof 0's), and its look.
func _roof_pieces(roof: MechaGuppyClimb.Roof, end: float, fronts: bool) -> void:
	var street: bool = roof.index == 0
	for run: Dictionary in runs(roof.starts):
		var lanes: Vector2i = run["lanes"]
		var start: float = maxf(float(run["start"]), -STREET_BEHIND)
		if start >= end:
			continue
		props.roof(lanes, start, end, roof.top, STREET_DEPTH if street else -1.0, looks == null)
		if not street:
			_blocker(lanes, start, end, roof.top)
			if fronts:
				_front(lanes, start, roof.top)
	if looks != null:
		var next_starts: PackedFloat32Array = PackedFloat32Array()
		if roof.index < climb.roofs.size() - 1 and roof.end < MechaGuppyClimb.FAR * 0.5:
			next_starts = climb.roofs[roof.index + 1].starts
		var node: Node3D = looks.roof(roof, end, next_starts, _step_into(roof))
		props.keep(node, maxf(end, _last_start(next_starts)))


## A plain segment of the top, full width from `from` to `to`.
func _top_segment(roof: MechaGuppyClimb.Roof, from: float, to: float) -> void:
	var all := Vector2i(0, world.geo.lane_count - 1)
	props.roof(all, from, to, roof.top, -1.0, looks == null)
	_blocker(all, from, to, roof.top)
	if looks != null:
		props.keep(looks.top_segment(roof, from, to), to)


## The step that led onto roof `roof` (its lanes that lead up, its cue), or null for the street.
func _step_into(roof: MechaGuppyClimb.Roof) -> MechaGuppyClimb.Step:
	return climb.steps[roof.index - 1] if roof.index > 0 and roof.index - 1 < climb.steps.size() else null


## A roof's sides below its top over `lanes` from `start` to `end`: a lane blocker (a lane switch into it from
## below the top bumps).
func _blocker(lanes: Vector2i, start: float, end: float, top: float) -> Area3D:
	var x: Vector2 = span(lanes)
	var height: float = maxf(top - BLOCKER_GAP, 0.1)
	var area := Area3D.new()
	area.name = "RoofSide"
	area.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER
	area.collision_mask = 0
	area.monitoring = false
	area.position = Vector3((x.x + x.y) * 0.5, height * 0.5, TrackGeometry.world_z((start + end) * 0.5))
	add_child(area)
	_add_box(area, Vector3(x.y - x.x, height, maxf(end - start, 0.1)))
	props.keep(area, end)
	return area


## A roof's front over `lanes` at `at`: solid from the bottom up to FRONT_DROP under where a runner could still
## step up onto it (MovementTuning.pit_depth under its top), the dash doesn't pass it.
func _front(lanes: Vector2i, at: float, top: float) -> Hazard:
	var x: Vector2 = span(lanes)
	var y1: float = top - world.tuning.pit_depth - FRONT_DROP
	if y1 <= 0.1:
		return null
	var size := Vector3(x.y - x.x - FRONT_INSET * 2.0, y1, FRONT_DEPTH)
	var hazard := Hazard.new()
	hazard.name = "RoofFront"
	hazard.hazard_name = "tiki bar"
	hazard.size = size
	hazard.is_solid = true
	hazard.dash_passes = false
	hazard.collision_layer = TrackBuilder.LAYER_HAZARD
	hazard.collision_mask = 0
	hazard.monitoring = false
	hazard.position = Vector3((x.x + x.y) * 0.5, y1 * 0.5, TrackGeometry.world_z(at + FRONT_DEPTH * 0.5))
	add_child(hazard)
	_add_box(hazard, size)
	props.keep(hazard, at + FRONT_DEPTH)
	return hazard


# --- Steps -----------------------------------------------------------------------------------------

## Step `step`'s pad strip across every lane at the end of its roof, its hut, and the basin eaten into the roof
## under the hut.
func _build_step(step: MechaGuppyClimb.Step) -> void:
	_steps_built[step.index] = true
	for lane: int in world.geo.lane_count:
		_strip(lane, step.pad, step.pad_end, step.floor_y)
	var sections: Array[Node3D] = props.ceiling_lanes(step.hut_start, step.ends,
		step.hut_y - world.tuning.ceiling_height)
	for s: Node3D in sections:
		s.name = "Hut%d" % step.index
	if looks != null:
		var next: MechaGuppyClimb.Roof = climb.roofs[step.index + 1]
		props.keep(looks.hut(step), step.hut_end())
		# The street's own eaten stretch is the water the arena's walls draw (MechaGuppySkin): no basin of its own.
		if step.index > 0:
			props.keep(looks.basin(step, climb.roofs[step.index], next), _last_start(next.starts))


## An anti-grav pad in `lane` from `from` to `to` on the floor `height` up (BossProps.pad's kind, as long as the
## strip), with the zone's pad look.
func _strip(lane: int, from: float, to: float, height: float) -> Area3D:
	var size := Vector3(world.geo.lane_width * 0.7, 0.5, to - from)
	var area := Area3D.new()
	area.name = "Pad"
	area.collision_layer = TrackBuilder.LAYER_TRIGGER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta(&"kind", &"pad")
	area.position = Vector3(world.geo.lane_x(lane), height + size.y * 0.5, TrackGeometry.world_z(from) - size.z * 0.5)
	add_child(area)
	_add_box(area, size)
	if looks != null:
		looks.strip(area, size)
	else:
		world.skin.pad(area, size)
	props.keep(area, to)
	return area


# --- Questions -------------------------------------------------------------------------------------

## The runs of neighbouring lanes that start together in `starts` (a roof's): [{lanes: Vector2i, start}].
static func runs(starts: PackedFloat32Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var first: int = 0
	while first < starts.size():
		var last: int = first
		while last + 1 < starts.size() and is_equal_approx(starts[last + 1], starts[first]):
			last += 1
		out.append({"lanes": Vector2i(first, last), "start": starts[first]})
		first = last + 1
	return out


## World x of a lane run's floor (its outer lanes reaching the walls, as the street's do).
func span(lanes: Vector2i) -> Vector2:
	return Vector2(world.geo.lane_floor_span(lanes.x).x, world.geo.lane_floor_span(lanes.y).y)


## Where the grapple's save (and a revive after a fall) takes a runner falling at `player`'s place (GDD §10,
## proposed: up onto the higher roof, into its nearest lane that leads up): the lowest roof above their feet whose
## lanes that lead up are under them where the save brings them down (the pull lifts them to just under its top,
## Player._pull_up, clear of every solid front, whose tops are lower still: FRONT_DROP), the lane of those
## nearest theirs. {} with none (the save as it always is: straight up).
func save_spot(player: Player) -> Dictionary:
	var feet: float = player.position.y
	var land: float = player.distance + climb.save_seconds(world.rules.grapple_pull_velocity) * climb.speed
	for step: MechaGuppyClimb.Step in climb.steps:
		if step.top or step.index + 1 >= climb.roofs.size():
			continue
		var roof: MechaGuppyClimb.Roof = climb.roofs[step.index + 1]
		if roof.top <= feet + 0.05:
			continue
		var lane: int = step.nearest_up(player.lane)
		if roof.covers(lane, land - SAVE_MARGIN) and roof.covers(lane, land + SAVE_MARGIN):
			return {"lane": lane, "height": roof.top}
	return {}


## A fair spot for an armor pickup (GDD §10's standard rule) at least `lead` metres ahead of the runner, on the roof
## they'll run along next: past where a rider lands on it (PICKUP_AFTER_LAND) and short of the hut over its pads
## (PICKUP_BEFORE_HUT), in the runner's lane if they're on that roof already, else the nearest lane that leads up
## onto it (where they'll land), never where a boss warning lies (BossProps.warned at that height): {lane, at,
## height}, or {} until one is far enough ahead.
func pickup_spot(lead: float) -> Dictionary:
	var player: Player = world.player
	var d: float = player.distance
	var k: float = climb.pace
	for i: int in climb.steps.size():
		var step: MechaGuppyClimb.Step = climb.steps[i]
		var roof: MechaGuppyClimb.Roof = climb.roofs[i]
		var into: MechaGuppyClimb.Step = climb.steps[i - 1] if i > 0 else null
		var from: float = d + lead
		if into != null:
			from = maxf(from, into.land + PICKUP_AFTER_LAND * k)
		var to: float = step.hut_start - PICKUP_BEFORE_HUT * k if not step.top else d + lead + TOP_SEGMENT
		to = minf(to, roof.end - PICKUP_BEFORE_HUT * k)
		if from > to:
			continue
		var lane: int = player.lane
		var on_it: bool = player.surface == Player.Surface.FLOOR and absf(player.floor_y - roof.top) < 0.05
		if not on_it and into != null:
			lane = into.nearest_up(player.lane)
		if not roof.covers(lane, from) or not roof.covers(lane, to):
			continue
		var at: float = from
		while at <= to:
			if not props.warned(lane, at - 2.0, at + 2.0, roof.top):
				return {"lane": lane, "at": at, "height": roof.top}
			at += 2.0
	return {}


## The furthest of `starts` (a roof's lane starts), or 0 for none.
static func _last_start(starts: PackedFloat32Array) -> float:
	var out: float = 0.0
	for s: float in starts:
		out = maxf(out, s)
	return out


static func _add_box(owner_node: CollisionObject3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	owner_node.add_child(shape)
