class_name SwarmClimb
extends RefCounted
## The Sewer Swarm's wall climb (GDD §10, phase 2: "The swarm also climbs the walls, taking them away as an
## escape route, but only temporarily, and the phase must stay engaging: one wall at a time for a few
## seconds, alternating sides, so one wall is always free"). SewerSwarm ticks it in phase 2's pattern.
##
## In turn: both walls free for climb_gap_seconds, then the swarm climbs one wall for climb_seconds (its crowd,
## climb_creatures screeches, a SwarmCrowd of kind CLIMB, rising up the wall over climb_rise_seconds from
## climb_behind behind the runner to climb_ahead ahead, streaming back past them, its claws heard:
## swarm_climb; then sinking back into the gutter), sides alternating, the first seeded. While it's up the
## wall is taken away: BossProps.block_wall over the whole stretch the runner can reach meanwhile, so an entry
## there clanks and bumps as at a sign (it never hurts: only a surge does). It never climbs the wall the
## runner is on (it waits for them to leave it), and never both: one wall is always free. Visual and the
## block only: nothing here is timed by anything but the phase's own clock and the runner's moves.
## DESIGN-TBD (docs/questions/e4.md, the wall climb).

enum State { GAP, CLIMB }

var boss: SewerSwarm
var crowd: SwarmCrowd
var state: State = State.GAP
## The wall it climbs next (or climbs now): -1 left, +1 right.
var side: int = -1
## Seconds in the current state, and how far the climb has risen (0-1).
var t: float = 0.0
var rise: float = 0.0
## Climbs so far.
var count: int = 0
## The wall taken away while it's up (a BossProps.block_wall), or null.
var block: Area3D



func _init(p_boss: SewerSwarm, p_crowd: SwarmCrowd) -> void:
	boss = p_boss
	crowd = p_crowd
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([String(boss.def.id), "climb"])
	side = -1 if rng.randi_range(0, 1) == 0 else 1
	_send()


## The wall taken away now: -1 left, +1 right, 0 none.
func blocked_side() -> int:
	return side if block != null and is_instance_valid(block) else 0


## Steps the climb on by one physics frame (phase 2's pattern).
func tick(delta: float) -> void:
	var tuning: SewerSwarmTuning = boss.tuning
	t += delta
	match state:
		State.GAP:
			rise = move_toward(rise, 0.0, delta / maxf(tuning.climb_rise_seconds, 0.05))
			if t >= tuning.climb_gap_seconds and not _on_wall(side) and rise <= 0.0:
				_start()
		State.CLIMB:
			if t < tuning.climb_seconds - tuning.climb_rise_seconds:
				rise = move_toward(rise, 1.0, delta / maxf(tuning.climb_rise_seconds, 0.05))
			else:
				rise = move_toward(rise, 0.0, delta / maxf(tuning.climb_rise_seconds, 0.05))
			if t >= tuning.climb_seconds:
				_finish()
	_send()


## Ends the climb at once (a phase change, the win): the wall comes back and the swarm drops away.
func clear() -> void:
	if state == State.CLIMB:
		_finish()
	rise = 0.0
	_send()


func _start() -> void:
	var tuning: SewerSwarmTuning = boss.tuning
	var d: float = boss.player_distance()
	# The whole stretch the runner can reach while it's up (the fastest a ramp's boost carries them), and a
	# little behind.
	var reach: float = (boss.run_speed() + boss.world.tuning.ramp_speed_boost + 6.0) * tuning.climb_seconds
	block = boss.props.block_wall(side, d - tuning.climb_behind, d + reach + tuning.climb_ahead)
	state = State.CLIMB
	t = 0.0
	count += 1
	boss.sound(&"swarm_climb", Vector3(side * (boss.world.geo.wall_x() - 0.3), 2.0, TrackGeometry.world_z(d + 12.0)))
	boss.log_event(&"climb", {"side": side, "d": snappedf(d, 0.01), "until": snappedf(d + reach + tuning.climb_ahead, 0.01)})


func _finish() -> void:
	if block != null and is_instance_valid(block):
		boss.props.remove(block)
	block = null
	boss.log_event(&"climb_end", {"side": side})
	state = State.GAP
	t = 0.0
	side = -side


## True while the runner runs on the wall on `wall_side`.
func _on_wall(wall_side: int) -> bool:
	var p: Player = boss.world.player
	return p.surface == Player.Surface.WALL and p.wall_side == wall_side


func _send() -> void:
	if crowd == null:
		return
	var tuning: SewerSwarmTuning = boss.tuning
	crowd.visible = rise > 0.0
	crowd.global_position = Vector3(0.0, 0.0, TrackGeometry.world_z(boss.player_distance()))
	crowd.set_climb(side * boss.world.geo.wall_x(), side, tuning.climb_ahead, tuning.climb_behind, tuning.climb_drift,
		tuning.climb_height, rise)
