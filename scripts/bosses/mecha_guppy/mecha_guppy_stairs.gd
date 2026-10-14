class_name MechaGuppyStairs
extends Node3D
## Builds the climb (MechaGuppyClimb's plan) as the runner goes, through the boss's props (BossProps, freed once
## passed), and answers questions about it (GDD §10, Mecha Guppy and Captain Cogs; task E5e-b1):
## - each roof: its top (BossProps.roof: a box on the floor layer, down to the street) over each run of lanes that
##   starts together, the full-width part in SEGMENT-long pieces as the build horizon reaches them; its sides a lane
##   blocker below its top where a neighbour lane starts later (a lane switch into a roof's side from below its top
##   is a blocked move: the clank and a bump, as into a truck's side), and its front solid below where a runner
##   could still step up onto it (a Hazard, `is_solid`, that the dash doesn't pass: what looks like a hit is a
##   hit). DESIGN-TBD (docs/OPEN_QUESTIONS.md item 775): the roof faces' rules. The plan keeps every front out of a
##   living runner's way: a wrong drop is dead or saved before it gets there; only a runner who steps off the side of a
##   roof's lanes that reach back, into the gap beside them, can fall into the front of the lanes beyond;
## - each step: its pad strip across every lane at the end of its roof (an anti-grav pad per lane, as long as the
##   strip), and its hut (BossProps.ceiling_lanes: each lane ends at its own distance, one section per run of lanes
##   ending together); between one roof's eaten edge and the next roof's front, nothing: the chasm Mecha Guppy has
##   eaten through the towers, down to the water (a fall);
## - the top (phase 3's): the last roof runs on, in segments for as long as the fight lasts;
## - the bait's notch (task E5e-b3; MechaGuppyClimb.Roof.notch_lane): past notch_from a roof's pieces leave out its
##   notch's lane (their collision and their look), with a lane blocker along the notch's inner side below the top (a
##   runner who fell into it can't switch into the tower's side), and the step's pads there go too;
## - Mecha Guppy's floor bite (task E5e-f; MechaGuppyClimb.Roof.bite, MechaGuppyCrescent): at its snap (eat_crescent) the
##   pieces it crosses are built again with the crescent gone: over the bite, the floor its edge leaves in convex pieces,
##   one per stretch of its edge (exactly the edge's polyline, as its look is: what looks like a hole is a hole), a lane
##   blocker under them below the top (a runner falling in the gap bumps off the tower's side, as beside the notch).
## When things are built: everything up to the build horizon, BUILD_MARGIN past the edge of sight (`sight`: the
## arena skin's fog end, where the fog hides everything), so nothing appears in view. Each step is planned as late
## as it can be, as its hut comes to the horizon, in the phase of that moment, and never nearer than the edge of
## sight (MechaGuppyClimb.plan_next's not_before). When the phase changes, every step whose hut is still past the edge
## of sight is taken back and planned again in the new phase (_replan): phase 2's higher steps, or phase 3's top,
## begin with the first step the runner hasn't seen, and nothing they can see ever changes. A roof is never built
## past where it could still be eaten (its end isn't known until the next step is planned).
## The look comes from the arena's skin when it's the Beach's (MechaGuppyLooks: tiki bar towers of stacked storeys,
## the lanes that reach back on a pier, hovering tiki huts, a few neon signs); any other skin gets grey boxes.
## Every frame it keeps the floor the runner's falls count from (Player.floor_base) at the roof of the step they're
## in, so a fall off any roof ends as far below it as a fall into the street's pits (task E5e-a). The work a frame
## doesn't grow with the fight: cursors skip everything finished.

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
## A roof's full-width part is built in pieces this long (metres).
const SEGMENT: float = 24.0
## Everything is built this far past the edge of sight (metres).
const BUILD_MARGIN: float = 30.0
## The edge of sight (metres) when the arena's skin isn't the Beach's (its fog's end otherwise).
const SIGHT_FALLBACK: float = 250.0
## Anything that ends this far behind the runner is passed: never built (metres).
const PASSED: float = 40.0
## A pickup lands this far (metres at 18 m/s) past where a rider lands on a roof, and this far short of the hut
## over its next pads.
const PICKUP_AFTER_LAND: float = 6.0
const PICKUP_BEFORE_HUT: float = 6.0
## A pickup is taken this far either side of its spot (metres; the stretch pickup_spot keeps clear of warnings).
const PICKUP_REACH: float = 2.0
## A grapple's save looks for the higher roof under a lane that leads up this far either side of where the runner
## comes down (metres).
const SAVE_MARGIN: float = 2.0
## Where Mecha Guppy bites a roof across its pads, what's left of them ends this far short of the bite (metres).
const PAD_EATEN: float = 0.6

var boss: MechaGuppy
var world: RunWorld
var climb: MechaGuppyClimb
var props: BossProps
var tuning: MechaGuppyTuning
## The climb's look (MechaGuppyLooks) on the Beach's skin, or null: grey boxes.
var looks: MechaGuppyLooks
## Past this far ahead of the runner the fog hides everything (metres).
var sight: float = SIGHT_FALLBACK

## Per roof index: {front: built, to: how far its full-width part is built, ended: built to its end}.
var _roofs: Dictionary = {}
var _steps_built: Dictionary = {}
## The first roof and step not finished yet: update() starts there.
var _roof_cursor: int = 0
var _step_cursor: int = 0
## Off while setup() plans the opening steps (nothing has been seen yet); on from the first frame.
var _live: bool = false
## What was built for each step, and for each roof ({node, from}: where the piece starts), so a step out of sight can
## be taken back when the phase changes.
var _step_nodes: Dictionary = {}
var _roof_nodes: Dictionary = {}
## The phase (and whether the top was due) the plan last followed.
var _phase_seen: int = -1
var _top_seen: bool = false
## Steps taken back and planned again over the fight (tests).
var replanned: int = 0
## Roofs Mecha Guppy has bitten (eat_roof) over the fight, and floor bites eaten (eat_crescent) (tests).
var eaten: int = 0
var crescents: int = 0
## Work counters for the tests (roofs and steps looked at by the last update()).
var visited: int = 0


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
		sight = beach.fog_end
	_phase_seen = boss.phase_index
	_top_seen = boss.top_due()
	update(world.player.distance)
	_live = true


func _physics_process(_delta: float) -> void:
	if world == null or world.player == null:
		return
	update(world.player.distance)


## How far ahead of track distance `d` things are built.
func horizon(d: float) -> float:
	return d + sight + BUILD_MARGIN


## Plans the next steps as their huts come to the build horizon, builds everything up to it, and keeps the
## runner's floor base at the roof of the step they're in.
func update(d: float) -> void:
	var far: float = horizon(d)
	var not_before: float = d + sight if _live else -MechaGuppyClimb.FAR
	var phase: int = boss.phase_index
	var top: bool = boss.top_due()
	if phase != _phase_seen or top != _top_seen:
		_phase_seen = phase
		_top_seen = top
		if _live:
			_replan(d)
	var guard: int = 0
	while not climb.top_planned() and climb.next_hut_start(phase, top) <= far and guard < 16:
		climb.plan_next(phase, top, not_before)
		guard += 1
	visited = 0
	var behind: float = d - PASSED
	var i: int = _roof_cursor
	while i < climb.roofs.size():
		var roof: MechaGuppyClimb.Roof = climb.roofs[i]
		if roof.index > 0 and roof.first_start() >= far:
			break
		visited += 1
		# A roof already left behind (a review that moves the runner ahead) is never built.
		var done: bool = roof.end < behind or _build_roof(roof, d, far)
		if done and i == _roof_cursor:
			_roof_cursor += 1
		i += 1
	var j: int = _step_cursor
	while j < climb.steps.size():
		var step: MechaGuppyClimb.Step = climb.steps[j]
		if not step.top and step.hut_start >= far:
			break
		visited += 1
		if not step.top and not _steps_built.has(step.index) and step.hut_end() >= behind:
			_build_step(step)
		if j == _step_cursor:
			_step_cursor += 1
		j += 1
	var base: MechaGuppyClimb.Step = climb.step_at(d)
	if base != null and world.player != null:
		world.player.floor_base = base.top_y


## When the phase changes: takes back every step whose hut is past the edge of sight (and the roofs they led to, and
## the pieces of the roof before them past that edge), so they're planned again in the new phase; everything the
## runner can see stays as it is.
func _replan(d: float) -> void:
	var edge: float = d + sight
	var first: int = -1
	for k: int in range(maxi(climb.step_index_at(d), 0), climb.steps.size()):
		var step: MechaGuppyClimb.Step = climb.steps[k]
		if step.top:
			break
		if step.hut_start >= edge:
			first = k
			break
	if first < 0:
		return
	replanned += climb.steps.size() - first
	for k: int in range(first, climb.steps.size()):
		_free_all(_step_nodes.get(k, []))
		_step_nodes.erase(k)
		_steps_built.erase(k)
	for k: int in range(first + 1, climb.roofs.size()):
		_free_roof(k, -MechaGuppyClimb.FAR)
		_roofs.erase(k)
	# The roof the first step started from: its pieces reaching past the edge go (it's no longer eaten there).
	var state: Dictionary = _roofs.get(first, {})
	if not state.is_empty():
		# (Back to notch_back short of the edge: the notch it may now get starts no nearer than that.)
		var kept: float = _free_roof(first, edge - tuning.notch_back)
		state["to"] = minf(float(state["to"]), kept)
		state["ended"] = false
	climb.truncate(first)
	_step_cursor = mini(_step_cursor, first)
	_roof_cursor = mini(_roof_cursor, first)


## Frees roof `index`'s full-width pieces that reach past track distance `edge` (at -FAR: every piece, its front's
## too; otherwise its front, which the step before it decided, stays); returns how far its kept full-width pieces
## reach (its full width's start with none).
func _free_roof(index: int, edge: float) -> float:
	var whole: bool = edge <= -MechaGuppyClimb.FAR * 0.5
	var kept_to: float = -MechaGuppyClimb.FAR
	var kept: Array = []
	for entry: Dictionary in _roof_nodes.get(index, []):
		if not is_instance_valid(entry["node"]):
			continue
		if whole or (bool(entry["segment"]) and float(entry["to"]) > edge + 0.01):
			props.remove(entry["node"])
		else:
			kept.append(entry)
			if bool(entry["segment"]):
				kept_to = maxf(kept_to, float(entry["to"]))
	_roof_nodes[index] = kept
	if kept_to <= -MechaGuppyClimb.FAR * 0.5 and index < climb.roofs.size():
		kept_to = maxf(climb.roofs[index].full_from(), -STREET_BEHIND)
	return kept_to


## How far roof `index`'s full-width pieces (its collision and its look) reach now (track distance; tests: never past
## where Mecha Guppy has eaten it); -FAR with none.
func roof_reach(index: int) -> float:
	var out: float = -MechaGuppyClimb.FAR
	for entry: Dictionary in _roof_nodes.get(index, []):
		if is_instance_valid(entry["node"]) and bool(entry["segment"]):
			out = maxf(out, float(entry["to"]))
	return out


func _free_all(nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			props.remove(node as Node)


## Mecha Guppy eats roof `index` from track distance `cut` to its end (a bite: MechaGuppyShark; GDD §10, it eats the
## floors the runner should have left): its full-width pieces past `cut` go, the one across `cut` is built again to
## end there (its collision and its look together, the eaten edge's look at `cut`: the look follows the collision
## exactly), the pads of the step leaving it go where they lie past `cut` (and end short of it where they cross it),
## and the plan's roof ends at `cut` (MechaGuppyClimb.Roof.end), so every question about the climb agrees. Never
## its front pieces (a bite comes no nearer than its pads). Returns the box eaten (world space) for its rubble, or an
## empty AABB when nothing was.
func eat_roof(index: int, cut: float) -> AABB:
	if index < 0 or index >= climb.roofs.size():
		return AABB()
	var roof: MechaGuppyClimb.Roof = climb.roofs[index]
	cut = maxf(cut, roof.full_from())
	if cut >= roof.end - 0.01:
		return AABB()
	var end: float = roof.end
	var state: Dictionary = _roofs.get(index, {})
	var built_to: float = float(state.get("to", cut))
	var rebuild: Array[Vector2] = []
	var kept: Array = []
	for entry: Dictionary in _roof_nodes.get(index, []):
		# A piece the props have freed already (passed) is gone from the book too.
		if not is_instance_valid(entry["node"]):
			continue
		if not bool(entry["segment"]):
			kept.append(entry)
			continue
		var from: float = float(entry["from"])
		var to: float = float(entry["to"])
		if to <= cut + 0.01:
			kept.append(entry)
		elif from >= cut - 0.01:
			props.remove(entry["node"])
		else:
			props.remove(entry["node"])
			var span := Vector2(from, cut)
			if not rebuild.has(span):
				rebuild.append(span)
	_roof_nodes[index] = kept
	roof.end = cut
	for span: Vector2 in rebuild:
		_roof_segment(roof, span.x, span.y, true)
	if not state.is_empty():
		state["to"] = minf(built_to, cut)
		state["ended"] = true
	_eat_pads(index, cut)
	eaten += 1
	var x: float = world.geo.wall_x()
	var top: float = roof.top
	var far: float = minf(end, maxf(built_to, cut))
	return AABB(Vector3(-x, top - 1.5, TrackGeometry.world_z(far)), Vector3(x * 2.0, 1.5, maxf(far - cut, 0.0)))


## Mecha Guppy's floor bite on roof `index` snaps (MechaGuppyFloorBite): the chunk is gone. Its pieces that the bite
## crosses are built again with the crescent bitten out (_roof_piece; their look too), so the floor holds where its look
## shows deck and nowhere in the gap. Returns the box bitten (world space) for its rubble, or an empty AABB.
func eat_crescent(index: int) -> AABB:
	if index <= 0 or index >= climb.roofs.size():
		return AABB()
	var roof: MechaGuppyClimb.Roof = climb.roofs[index]
	var bite: MechaGuppyCrescent = roof.bite
	if bite == null or bite.skipped:
		return AABB()
	bite.eaten = true
	var rebuild: Array[Vector2] = []
	var kept: Array = []
	for entry: Dictionary in _roof_nodes.get(index, []):
		if not is_instance_valid(entry["node"]):
			continue
		var from: float = float(entry["from"])
		var to: float = float(entry["to"])
		if bool(entry["segment"]) and from < bite.to - 0.01 and to > bite.from + 0.01:
			props.remove(entry["node"])
			if not rebuild.has(Vector2(from, to)):
				rebuild.append(Vector2(from, to))
		else:
			kept.append(entry)
	_roof_nodes[index] = kept
	for span: Vector2 in rebuild:
		var ended: bool = roof.end < MechaGuppyClimb.FAR * 0.5 and absf(span.y - roof.end) < 0.01
		_roof_piece(roof, span.x, span.y, ended)
	crescents += 1
	var w: float = minf(bite.deepest(), bite.width())
	var x0: float = minf(bite.x_of(0.0), bite.x_of(w))
	return AABB(Vector3(x0, roof.top - 1.5, TrackGeometry.world_z(bite.to)), Vector3(w, 1.5, bite.to - bite.from))


## The pads of step `index` (the strip at the end of its roof) where Mecha Guppy has eaten that roof from `cut`:
## each lane's pad goes where it lies past `cut`, and one that crosses it is built again to end PAD_EATEN short of it.
func _eat_pads(index: int, cut: float) -> void:
	if not _step_nodes.has(index) or index >= climb.steps.size():
		return
	var step: MechaGuppyClimb.Step = climb.steps[index]
	if step.top or cut >= step.pad_end:
		return
	var nodes: Array = _step_nodes[index]
	var kept: Array = []
	for node: Variant in nodes:
		if not is_instance_valid(node):
			continue
		if (node as Node).get_meta(&"kind", &"") == &"pad":
			props.remove(node as Node)
		else:
			kept.append(node)
	_step_nodes[index] = kept
	var end: float = cut - PAD_EATEN
	if end - step.pad < 0.5:
		return
	var roof: MechaGuppyClimb.Roof = climb.roofs[index]
	for lane: int in world.geo.lane_count:
		if roof.covers(lane, step.pad):
			_note_step(index, _strip(lane, step.pad, end, step.floor_y))


func _note_step(index: int, node: Node) -> void:
	if not _step_nodes.has(index):
		_step_nodes[index] = []
	(_step_nodes[index] as Array).append(node)


func _note_roof(index: int, node: Node, to: float, segment: bool, from: float = -MechaGuppyClimb.FAR) -> void:
	if not _roof_nodes.has(index):
		_roof_nodes[index] = []
	(_roof_nodes[index] as Array).append({"node": node, "to": to, "segment": segment, "from": from})


# --- Roofs -----------------------------------------------------------------------------------------

## Builds what roof `roof` needs at runner distance `d` with the horizon at `far`: its front pieces once its first
## start is within the horizon (or at once, the street), then its full-width part piece by piece, never past where
## it could still be eaten. True once it's built to its end.
func _build_roof(roof: MechaGuppyClimb.Roof, d: float, far: float) -> bool:
	var state: Dictionary = _roofs.get(roof.index, {})
	if state.is_empty():
		state = {"front": false, "to": maxf(roof.full_from(), -STREET_BEHIND), "ended": false}
		_roofs[roof.index] = state
	if not bool(state["front"]):
		_roof_front(roof)
		state["front"] = true
	var known: bool = roof.end < MechaGuppyClimb.FAR * 0.5 or climb.top_planned() and roof.index == climb.roofs.size() - 1
	var end: float = roof.end if known else MechaGuppyClimb.FAR
	# Unknown end: built no further than the nearest its end or its notch could be (_unknown_limit).
	var limit: float = minf(far, end) if known else minf(far, _unknown_limit(roof, d))
	var to: float = float(state["to"])
	while to < limit - 0.01:
		var next: float = minf(to + SEGMENT, end)
		if next > limit + 0.01 and not (known and next >= end - 0.01 and end <= far):
			break
		_roof_segment(roof, to, next, known and next >= end - 0.01)
		to = next
	state["to"] = to
	state["ended"] = known and to >= end - 0.01
	return bool(state["ended"])


## From a hut's start to where Mecha Guppy has eaten the roof under it: the hut's lead, the longest jump with the
## dash's reach, the pad strip's margin and the eaten margin (metres).
func _strip_reach() -> float:
	return tuning.hut_lead * climb.pace + climb.jump_seconds() * climb.speed + climb.dash_reach + tuning.strip_margin \
		+ tuning.edge_margin


## How far roof `roof` is built while its end isn't known (the next step, from it, not yet planned) with the runner at
## `d`: to the nearest its end could be (the next hut, which starts no nearer than the edge of sight nor than where the
## plan would put it now, MechaGuppyClimb.next_hut_start; then the pad strip and the eaten margin), but on a roof that
## may have a notch no nearer than its notch could start (notch_back before that hut). So it reaches past the edge of sight
## until the next step is planned (task E5e-b3's review: built only to the edge of sight less notch_back, in whole
## SEGMENTs, its pieces came into view 168-192 m out, in the haze).
func _unknown_limit(roof: MechaGuppyClimb.Roof, d: float) -> float:
	var hut: float = maxf(d + sight, climb.next_hut_start(boss.phase_index, boss.top_due()))
	if roof.index < MechaGuppyClimb.FIRST_NOTCH:
		return hut + _strip_reach()
	return hut - tuning.notch_back


## Roof `roof`'s front pieces: each run of lanes starting before the roof is full width (the lanes that reach back:
## REACH_BACK), from its start to there, with its side blockers and solid front; the fronts of the lanes that start
## where it's full width; their look (the street: nothing, its slab comes in segments).
func _roof_front(roof: MechaGuppyClimb.Roof) -> void:
	if roof.index == 0:
		return
	var full: float = roof.full_from()
	for run: Dictionary in runs(roof.starts):
		var lanes: Vector2i = run["lanes"]
		var start: float = float(run["start"])
		if start < full - 0.01:
			_note_roof(roof.index, props.roof(lanes, start, full, roof.top, -1.0, looks == null), full, false)
			_note_roof(roof.index, _blocker(lanes, start, full, roof.top), full, false)
		var front: Hazard = _front(lanes, start, roof.top)
		if front != null:
			_note_roof(roof.index, front, start, false)
	if looks != null:
		_note_roof(roof.index, props.keep(looks.roof_front(roof, _step_into(roof)), full), full, false)


## A full-width piece of roof `roof` from `from` to `to` (`ended`: it ends where Mecha Guppy has eaten it), split where
## its notch begins: past there, its notch's lane is left out (the collision and the look) and a lane blocker stands
## along the notch's inner side.
func _roof_segment(roof: MechaGuppyClimb.Roof, from: float, to: float, ended: bool) -> void:
	if roof.notched() and from < roof.notch_from - 0.01 and to > roof.notch_from + 0.01:
		_roof_piece(roof, from, roof.notch_from, false)
		_roof_piece(roof, roof.notch_from, to, ended)
		return
	_roof_piece(roof, from, to, ended)


## One piece of roof `roof` from `from` to `to`, wholly before its notch or wholly past it (_roof_segment); with its floor
## bite eaten where it crosses it (eat_crescent): its floor before and after the bite, and over the bite the floor its
## edge leaves (_bitten_floor) with a lane blocker under it.
func _roof_piece(roof: MechaGuppyClimb.Roof, from: float, to: float, ended: bool) -> void:
	var lanes := Vector2i(0, world.geo.lane_count - 1)
	var notched: bool = roof.notched() and from >= roof.notch_from - 0.01
	if notched:
		lanes = Vector2i(1, lanes.y) if roof.notch_lane == 0 else Vector2i(0, lanes.y - 1)
	var street: bool = roof.index == 0
	var bite: MechaGuppyCrescent = roof.bite
	if bite != null and bite.eaten and not bite.skipped and not notched and from < bite.to - 0.01 and to > bite.from + 0.01:
		var a: float = maxf(from, bite.from)
		var b: float = minf(to, bite.to)
		if a > from + 0.01:
			_note_roof(roof.index, props.roof(lanes, from, a, roof.top, -1.0, looks == null), to, true, from)
		if b < to - 0.01:
			_note_roof(roof.index, props.roof(lanes, b, to, roof.top, -1.0, looks == null), to, true, from)
		_note_roof(roof.index, _bitten_floor(roof, bite, a, b, false), to, true, from)
		_note_roof(roof.index, _bitten_floor(roof, bite, a, b, true), to, true, from)
	else:
		_note_roof(roof.index, props.roof(lanes, from, to, roof.top, STREET_DEPTH if street else -1.0, looks == null), to, true, from)
		if notched:
			_note_roof(roof.index, _blocker(lanes, from, to, roof.top), to, true, from)
	if looks != null:
		_note_roof(roof.index, props.keep(looks.roof_segment(roof, from, to, ended), to), to, true, from)


## Over track distances [a, b] of roof `roof`'s eaten floor bite `bite`: the floor its edge leaves, one convex piece per
## stretch of the edge (from the edge to the far wall, its top at the roof's, down to the street as a roof's box is), on the
## floor layer; or with `blocker`, the same shapes from BLOCKER_GAP under the top down, a lane blocker (a runner falling in
## the gap bumps off its side). Nothing over a stretch where the bite crosses the whole floor.
func _bitten_floor(roof: MechaGuppyClimb.Roof, bite: MechaGuppyCrescent, a: float, b: float, blocker: bool) -> CollisionObject3D:
	var body: CollisionObject3D
	if blocker:
		var area := Area3D.new()
		area.name = "RoofBittenSide"
		area.collision_layer = TrackBuilder.LAYER_LANE_BLOCKER
		area.monitoring = false
		body = area
	else:
		body = StaticBody3D.new()
		body.name = "RoofBitten"
		body.collision_layer = TrackBuilder.LAYER_FLOOR
	body.collision_mask = 0
	add_child(body)
	var top: float = roof.top - (BLOCKER_GAP if blocker else 0.0)
	var low: float = roof.top - maxf(roof.top, 0.1)
	var far: float = -float(bite.side) * bite.wall
	var pts: PackedVector2Array = bite.edge(a, b)
	for i: int in pts.size() - 1:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[i + 1]
		if q.y - p.y < 0.0005 or (absf(p.x - far) < 0.001 and absf(q.x - far) < 0.001):
			continue
		var points := PackedVector3Array()
		for y: float in [top, low]:
			points.append_array(PackedVector3Array([Vector3(p.x, y, -p.y), Vector3(far, y, -p.y), Vector3(q.x, y, -q.y),
				Vector3(far, y, -q.y)]))
		var shape := CollisionShape3D.new()
		var convex := ConvexPolygonShape3D.new()
		convex.points = points
		shape.shape = convex
		body.add_child(shape)
	props.keep(body, b)
	return body


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

## Step `step`'s pad strip across every lane at the end of its roof (but its notch's), and its hut.
func _build_step(step: MechaGuppyClimb.Step) -> void:
	_steps_built[step.index] = true
	var roof: MechaGuppyClimb.Roof = climb.roofs[step.index]
	for lane: int in world.geo.lane_count:
		if roof.covers(lane, step.pad):
			_note_step(step.index, _strip(lane, step.pad, step.pad_end, step.floor_y))
	var sections: Array[Node3D] = props.ceiling_lanes(step.hut_start, step.ends,
		step.hut_y - world.tuning.ceiling_height)
	for s: Node3D in sections:
		s.name = "Hut%d" % step.index
		_note_step(step.index, s)
	if looks != null:
		_note_step(step.index, props.keep(looks.hut(step), step.hut_end()))


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
## nearest theirs; a runner who fell off the side of a roof they were on (into the bait's notch) goes back up onto it,
## into its lane nearest theirs there. {} with none (the save as it always is: straight up).
func save_spot(player: Player) -> Dictionary:
	var feet: float = player.position.y
	var land: float = player.distance + climb.save_seconds(world.rules.grapple_pull_velocity) * climb.speed
	var first: int = maxi(climb.step_index_at(player.distance) - 1, 0)
	for k: int in range(first, mini(first + 4, climb.steps.size())):
		var step: MechaGuppyClimb.Step = climb.steps[k]
		if step.top or step.index + 1 >= climb.roofs.size():
			continue
		var roof: MechaGuppyClimb.Roof = climb.roofs[step.index + 1]
		if roof.top <= feet + 0.05:
			continue
		var lane: int = step.nearest_up(player.lane)
		# Beside a roof that's full width here (a fall off its side, into its notch or a floor bite's gap): its covered
		# lane nearest theirs.
		if player.distance >= roof.full_from() and not roof.covers(player.lane, player.distance):
			lane = _nearest_covered(roof, player.lane, land)
		# A floor bite that leaves one lane, not yet snapped, ahead of where the save brings them down, too near to read it
		# and cross from that lane to the one it leaves (task E5e-f; its review: counted from the lane the save would bring
		# them down in, not the farthest): into that lane, as the save's pull moves them anyway. DESIGN-TBD
		# (docs/OPEN_QUESTIONS.md item 818): the save near a bite.
		var bite: MechaGuppyCrescent = roof.bite
		if lane >= 0 and bite != null and not bite.skipped and not bite.eaten and not bite.full and land < bite.to \
				and land > bite.from - save_crossing(bite, lane):
			lane = bite.keep
		if lane >= 0 and roof.covers(lane, land - SAVE_MARGIN) and roof.covers(lane, land + SAVE_MARGIN):
			return {"lane": lane, "height": roof.top}
	return {}


## How far short of floor bite `bite` a save may bring a runner down in `lane` (metres): a reaction (the save is sudden),
## every switch from there to the lane the bite leaves and dodge_margin, with half a hurtbox and the dash's reach (as the
## bite's own crossing counts them: MechaGuppyClimb.bite_crossing).
func save_crossing(bite: MechaGuppyCrescent, lane: int) -> float:
	var t: MovementTuning = world.tuning
	return (tuning.dodge_reaction + float(absi(bite.keep - lane)) * t.lane_switch_time + tuning.dodge_margin) * climb.speed \
		+ t.hurtbox_size.z * 0.5 + climb.dash_reach


## The lane of roof `roof` nearest `lane` that it covers at track distance `d` (both ways out to SAVE_MARGIN), or -1.
func _nearest_covered(roof: MechaGuppyClimb.Roof, lane: int, d: float) -> int:
	var best: int = -1
	for l: int in world.geo.lane_count:
		if roof.covers(l, d - SAVE_MARGIN) and roof.covers(l, d + SAVE_MARGIN) and (best < 0 or absi(l - lane) < absi(best - lane)):
			best = l
	return best


## Where the roof whose top is at `height` starts in `lane` (its front a runner falling at `d` reaches next), or `d`
## when no roof planned has that top.
func roof_front(lane: int, height: float, d: float) -> float:
	var first: int = maxi(climb.roof_index_at(d) - 1, 0)
	for k: int in range(first, mini(first + 4, climb.roofs.size())):
		var r: MechaGuppyClimb.Roof = climb.roofs[k]
		if absf(r.top - height) < 0.01:
			return r.start_in(lane)
	return d


## A fair spot for an armor pickup (GDD §10's standard rule) at least `lead` metres ahead of the runner, on the roof
## they'll run along next: past where a rider lands on it (PICKUP_AFTER_LAND) and short of the hut over its pads
## (PICKUP_BEFORE_HUT), in the runner's lane if they're on that roof already, else the nearest lane that leads up
## onto it (where they'll land), never where a boss warning lies (BossProps.warned at that height) nor where a floor bite
## will take the lane, nowhere a runner who takes it couldn't then get out of a floor bite's way (clear_of_bite), and only
## where it's built: {lane, at, height}, or {} until one is far enough ahead.
func pickup_spot(lead: float) -> Dictionary:
	var player: Player = world.player
	var d: float = player.distance
	var k: float = climb.pace
	var first: int = maxi(climb.step_index_at(d) - 1, 0)
	for i: int in range(first, climb.steps.size()):
		var step: MechaGuppyClimb.Step = climb.steps[i]
		var roof: MechaGuppyClimb.Roof = climb.roofs[i]
		var into: MechaGuppyClimb.Step = climb.steps[i - 1] if i > 0 else null
		var from: float = d + lead
		if into != null:
			from = maxf(from, into.land + PICKUP_AFTER_LAND * k)
		var to: float = step.hut_start - PICKUP_BEFORE_HUT * k if not step.top else d + lead + SEGMENT
		to = minf(minf(to, roof.end - PICKUP_BEFORE_HUT * k), float((_roofs.get(roof.index, {}) as Dictionary).get("to", -1.0)))
		# Clear of the bait (its circle follows the runner's lane to where its bomb lands, past the notch's start).
		if roof.notched():
			to = minf(to, roof.notch_from - tuning.pickup_margin - tuning.blast_depth)
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
			# Off any boss warning, off where a floor bite will take the lane, and with time after it to get out of a floor
			# bite's way (task E5e-f and its review).
			if not props.warned(lane, at - PICKUP_REACH, at + PICKUP_REACH, roof.top) and roof.keeps(lane, at - PICKUP_REACH) \
					and roof.keeps(lane, at + PICKUP_REACH) and clear_of_bite(roof, lane, at):
				return {"lane": lane, "at": at, "height": roof.top}
			at += 2.0
	return {}


## True if a pickup at track distance `at` in `lane` of roof `roof` leaves a runner who takes it the time to get out of its
## floor bite's way (task E5e-f's review: one taken just short of the gap left no time for the switches still needed): in a
## lane the bite takes, taken (PICKUP_REACH past `at`) at least every switch from there to the lane the bite leaves (none
## over a full-width one: its jump) and dodge_margin, with half a hurtbox and the dash's reach (a runner who dashes as
## they grab it still clears the bite, as the climb's other promises hold dashing), short of where its gap reaches that
## lane; or past the bite. DESIGN-TBD (docs/OPEN_QUESTIONS.md item 819): pickups near a bite.
func clear_of_bite(roof: MechaGuppyClimb.Roof, lane: int, at: float) -> bool:
	var bite: MechaGuppyCrescent = roof.bite
	if bite == null or bite.skipped:
		return true
	var gap: Vector2 = bite.stretch(bite.near_w(lane))
	if gap.x > gap.y:
		return true
	var h: float = world.tuning.hurtbox_size.z * 0.5
	if at - PICKUP_REACH >= bite.to + h:
		return true
	var switches: int = 0 if bite.full else absi(bite.keep - lane)
	var need: float = (float(switches) * world.tuning.lane_switch_time + tuning.dodge_margin) * climb.speed + h \
		+ climb.dash_reach
	return at + PICKUP_REACH + need <= gap.x


static func _add_box(owner_node: CollisionObject3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	owner_node.add_child(shape)
