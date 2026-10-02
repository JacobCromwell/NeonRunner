class_name SwarmHorde
extends Node3D
## The Sewer Swarm's horde at the roadsides (GDD §10: "a mutant horde of screeches rising from the sewers. It
## builds up on both sides of the street"; the Rising: "manholes and wall vents shake all along both sides,
## and screeches pour out"). Scenery only, never in the lanes and never hurting anyone: the fight's attacks
## are its clusters' (SwarmCluster). Three parts, each drawn in one or two calls:
## - the bands: a SwarmCrowd in each gutter, piled at the wall's foot and clinging low on it, from
##   SewerSwarmTuning.horde_behind behind the runner to horde_ahead ahead, running with them and drifting
##   back; it fills up over horde_fill_seconds from the fight's start (`fill`), and drains away when the
##   swarm is beaten (`drain`);
## - the lairs (SwarmLairs): the manholes and vents along both sides, rattling and bursting open;
## - the spill: a SwarmCrowd whose creatures pour out of each lair as it bursts and run into the gutter.
## Everything is made in setup(), before the fight begins. The crowd sizes are the tuning's (smaller on a
## low-end device). Only the look: it runs from _process.
## DESIGN-TBD (docs/questions/e4.md, 5): a harmless horde in plain view at the walls' feet.

var world: RunWorld
var tuning: SewerSwarmTuning
var bands: Array[SwarmCrowd] = []
var spill: SwarmCrowd
var lairs: SwarmLairs
## How full the bands are (0-1), and the target it eases toward.
var fill: float = 0.15
var fill_target: float = 1.0
## The look's own clock (seconds since setup).
var clock: float = 0.0

var _spill_slot: int = 0
var _spill_slots: int = 16
var _spill_each: int = 0
var _fill_speed: float = 0.2


## Builds the horde for `p_world`'s street: its bands of `horde_count` creatures, its lairs, and a spill of
## `spill_each` creatures a lair.
func setup(p_world: RunWorld, p_tuning: SewerSwarmTuning, horde_count: int, spill_each: int, seed_value: int,
		floor_ok: Callable = Callable()) -> void:
	world = p_world
	tuning = p_tuning
	name = "Horde"
	top_level = true
	var grime: float = 1.0 if world.skin == null or world.skin.enemy_variant != &"city" else 0.0
	var wall_x: float = world.geo.wall_x()
	for side: int in [-1, 1]:
		var band := SwarmCrowd.make(SwarmCrowd.Kind.BAND, horde_count / 2, hash([seed_value, "band", side]), grime,
			tuning.creature_scale)
		band.name = "BandLeft" if side < 0 else "BandRight"
		band.set_band(side * wall_x, side, tuning.horde_ahead, tuning.horde_behind, tuning.horde_depth,
			tuning.horde_climb, tuning.horde_drift, tuning.horde_heap_spacing)
		band.set_life(1.0, fill, 0, 0.0)
		add_child(band)
		bands.append(band)
	_spill_each = maxi(spill_each, 0)
	spill = SwarmCrowd.make(SwarmCrowd.Kind.SPILL, _spill_each * _spill_slots, hash([seed_value, "spill"]), grime,
		tuning.creature_scale)
	spill.name = "Spill"
	add_child(spill)
	lairs = SwarmLairs.new()
	lairs.name = "Lairs"
	lairs.floor_ok = floor_ok
	add_child(lairs)
	lairs.setup(wall_x, tuning, world.tuning.run_speed, world.player.distance, seed_value)
	lairs.burst.connect(_on_lair_burst)
	_fill_speed = (1.0 - fill) / maxf(tuning.horde_fill_seconds, 0.1)
	_follow()


## The swarm is beaten: the horde flees into the sewers.
func drain(seconds: float = 2.0) -> void:
	fill_target = 0.0
	_fill_speed = fill / maxf(seconds, 0.1)


## Draws counted over the horde's parts (the bands, the spill, the two kinds of lair).
func draw_calls() -> int:
	return bands.size() + 1 + 2


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	clock += delta
	fill = move_toward(fill, fill_target, _fill_speed * delta)
	# Filling, more of it rises out of the gutter; draining, its creatures shrink away into the sewers.
	var draining: bool = fill_target <= 0.0
	for band: SwarmCrowd in bands:
		band.set_life(fill if draining else 1.0, 1.0 if draining else fill, 0, 0.0)
	spill.set_param(&"clock", clock)
	lairs.update(world.player.distance, delta)
	_follow()


func _follow() -> void:
	var z: float = TrackGeometry.world_z(world.player.distance)
	for band: SwarmCrowd in bands:
		band.global_position = Vector3(0.0, 0.0, z)


func _on_lair_burst(at: Vector3, side: int) -> void:
	if _spill_each <= 0:
		return
	var first: int = _spill_slot * _spill_each
	for k: int in _spill_each:
		spill.set_spill(first + k, at, side, clock)
	_spill_slot = (_spill_slot + 1) % _spill_slots
