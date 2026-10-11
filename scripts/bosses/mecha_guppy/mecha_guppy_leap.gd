class_name MechaGuppyLeap
extends RefCounted
## The defeat of Mecha Guppy and Captain Cogs (GDD §10: "if the player dodges these long enough, then the Mecha Guppy jumps
## over to the boss, Captain Cogs, and eats the boss because the shark is pissed"; "Defeat: Mecha Guppy has eaten Captain
## Cogs, and it swims away"; task E5e-c). MechaGuppy starts it as phase 3's minute ends (the win: the runner keeps running,
## safe in the framework's god mode, and nothing here has a hitbox), and holds the results until it's over
## (victory_over). Staged beside the top, where the camera sees it, never over the lanes:
## - the rise (leap_rise): Mecha Guppy bursts up out of the sea under Captain Cogs' ship alongside the top, upright, side-on
##   (an eye toward the runner, its chin toward the top, as it always shows itself), its jaws opening wide round the
##   ship's stern half, with a roar of machinery and water (guppy_leap);
## - the gulp: its jaws snap shut on the stern half with the captain on it (guppy_gulp, a shudder, a shake): the captain
##   and the stern are gone, and the bow half breaks away, tumbling down into the sea (CaptainCogsShip.swallow);
## - it hangs a moment (leap_hang), rising a little on, leaning out from the top;
## - it falls back (leap_fall), straight down out of sight beside the top (its splash heard: guppy_swim);
## - it swims away (swim_seconds): out at sea beyond the shoreline, its dorsal fin cutting through the water ahead and out
##   to sea, a trail of foam behind it, until the haze takes it.
## The victory riff plays riff_after the gulp (MechaGuppyTuning.victory_riff_on; LevelRun's riff at the defeat is off:
## MechaGuppy.victory_riff). Everything keeps pace with the runner (the stern half's place beside them when it began), so
## it plays out in view; time comes from the boss's ticks. DESIGN-TBD (docs/questions/e5e.md): the leap's staging.

enum Step { NONE, RISE, HANG, FALL, SWIM, OVER }

## The rise starts this far under the deck (metres: out of sight), and ends with the hinge this far under the ship's keel
## (its open jaws round the stern half and the captain); the hinge stands this far out from the ship's middle (its chin,
## dropped toward the top, under the hull, its tip clear of the lanes and the top's eaves: never over them).
const RISE_FROM: float = 45.0
const GULP_UNDER: float = 6.0
const HINGE_OUT: float = 4.0
## The jaws open over this share of the rise (from, to), this wide (0 to 1: MechaGuppySharkModel's opening), and snap shut
## over GULP_SECONDS at the gulp.
const OPEN_FROM: float = 0.15
const OPEN_TO: float = 0.75
const JAW_OPEN: float = 0.85
const GULP_SECONDS: float = 0.15
## The hang: how far it rises on (metres), how far it leans out from the top by its end (degrees).
const HANG_RISE: float = 3.0
const HANG_LEAN: float = 12.0
## The fall: how far it drops (metres, under gravity), its lean out by the end (degrees), and its drift out (metres).
const FALL_DROP: float = 70.0
const FALL_LEAN: float = 22.0
const FALL_OUT: float = 8.0
## The swim: the hinge this far under the sea (the top of its head and its back just breaking the water, its dorsal fin
## standing out of it), past the shoreline (SWIM_OUT) and at least SWIM_CLEAR out from the track's middle (nearer, the
## top's own edge hides the sea far below from the run camera), from SWIM_FROM to SWIM_TO ahead of the runner and out by
## SWIM_AWAY more (metres; the haze takes it as it goes), a puff of foam at the fin every FOAM_EVERY seconds (its wake:
## white reads through the haze).
const SWIM_DEPTH: float = 3.8
const SWIM_OUT: float = 7.0
const SWIM_CLEAR: float = 62.0
const SWIM_FROM: float = 45.0
const SWIM_TO: float = 120.0
const SWIM_AWAY: float = 25.0
const FOAM_EVERY: float = 0.07
const FOAM_COLOR := Color(0.93, 0.95, 0.93)
## Where its dorsal fin stands, in its head's space (MechaGuppySharkModel's body: the fin's root along the back), for the
## foam at the waterline.
const FIN_AT := Vector3(0.0, -18.0, -3.4)

var boss: MechaGuppy
var shark: MechaGuppyShark
var ship: CaptainCogsShip
var tuning: MechaGuppyTuning
var step: Step = Step.NONE
## Seconds since the defeat began, and when the gulp came (-1 before).
var time: float = 0.0
var gulped_at: float = -1.0
var riff_played: bool = false
## Moments for the tests: {rise, gulp, fall, swim, over} (seconds into the defeat).
var marks: Dictionary = {}

## The leap's place: the hinge's world x beside the top, its offset ahead of the runner (world z), the side it's on (-1
## left), the deck's height, the ship's keel there.
var _x: float = 0.0
var _rel_z: float = 0.0
var _side: float = -1.0
var _deck: float = 0.0
var _keel: float = 0.0
var _foam_t: float = 0.0
var _riff: StringName = &""


func _init(p_boss: MechaGuppy) -> void:
	boss = p_boss
	shark = boss.shark
	ship = boss.ship
	tuning = boss.tuning


## The minute is up (the win): the leap begins.
func start() -> void:
	var world: RunWorld = boss.world
	var p: Player = world.player
	step = Step.RISE
	time = 0.0
	gulped_at = -1.0
	riff_played = false
	marks = {"rise": 0.0}
	_side = float(CaptainCogsShip.LEVEL_SIDE)
	_deck = p.floor_base
	var stern := Vector3(0.0, 0.0, (CaptainCogsModel.SPLIT_Z + CaptainCogsModel.LENGTH * 0.5) * 0.5)
	var at: Vector3 = ship.global_transform * stern if ship != null else Vector3(_side * (world.geo.wall_x() + 9.0),
		_deck, TrackGeometry.world_z(p.distance + tuning.level_ahead))
	_x = at.x + _side * HINGE_OUT
	_rel_z = at.z - TrackGeometry.world_z(p.distance)
	_keel = ship.global_position.y if ship != null else _deck + tuning.level_keel
	var music: MusicDirector = MusicDirector.instance()
	_riff = MusicDirector.level_complete_sound(music.library.riff_track(music.current()) if music != null else &"",
		world.sfx_library)
	shark.hold(true)
	_pose_rise(0.0)
	boss.sound(&"guppy_leap", Vector3(_x, _deck - 6.0, _z()))
	boss.log_event(&"leap", {"x": _x, "deck": _deck})


## True once it has played out (the results may follow).
func over() -> bool:
	return step == Step.OVER


## One physics step after the defeat (MechaGuppy._defeated_tick).
func tick(delta: float) -> void:
	if step == Step.NONE or step == Step.OVER:
		return
	time += delta
	_riff_due()
	match step:
		Step.RISE:
			var k: float = clampf(time / maxf(tuning.leap_rise, 0.05), 0.0, 1.0)
			_pose_rise(k)
			if k >= 1.0:
				_gulp()
		Step.HANG:
			var k: float = clampf((time - gulped_at) / maxf(tuning.leap_hang, 0.05), 0.0, 1.0)
			var e: float = 1.0 - (1.0 - k) * (1.0 - k)
			var shut: float = (1.0 - clampf((time - gulped_at) / GULP_SECONDS, 0.0, 1.0)) * JAW_OPEN
			shark.pose_free(Vector3(_x, _gulp_y() + HANG_RISE * e, _z()), _upright(HANG_LEAN * e), shut)
			if k >= 1.0:
				step = Step.FALL
				marks["fall"] = time
		Step.FALL:
			var k: float = clampf((time - float(marks["fall"])) / maxf(tuning.leap_fall, 0.05), 0.0, 1.0)
			var drop: float = FALL_DROP * k * k
			var lean: float = lerpf(HANG_LEAN, FALL_LEAN, k)
			shark.pose_free(Vector3(_x + _side * FALL_OUT * k, _gulp_y() + HANG_RISE - drop, _z()), _upright(lean), 0.0)
			if k >= 1.0:
				_begin_swim()
		Step.SWIM:
			var k: float = clampf((time - float(marks["swim"])) / maxf(tuning.swim_seconds, 0.1), 0.0, 1.0)
			_pose_swim(k)
			_foam_t -= delta
			if _foam_t <= 0.0 and k < 0.92:
				_foam_t = FOAM_EVERY
				var fin: Vector3 = _fin_point()
				boss.world.effects.burst(Vector3(fin.x, _sea_y() + 0.4, fin.z), FOAM_COLOR, 14, 1.3)
			if k >= 1.0:
				shark.hold(false)
				step = Step.OVER
				marks["over"] = time
				boss.log_event(&"swum_away")


## Where the leap keeps pace: its world z now (the runner's, plus its offset).
func _z() -> float:
	return TrackGeometry.world_z(boss.world.player.distance) + _rel_z


## The hinge's height at the gulp: GULP_UNDER under the ship's keel.
func _gulp_y() -> float:
	return _keel - GULP_UNDER


## Upright, side-on (its chin toward the top, an eye toward the runner), leaning out from the top by `lean` degrees.
func _upright(lean: float) -> Basis:
	return Basis(Vector3.BACK, -_side * deg_to_rad(lean)) * Basis(Vector3.UP, -_side * PI * 0.5)


## The rise, `k` (0 to 1) of the way: up out of the sea under the ship, slowing as it gets there, its jaws opening.
func _pose_rise(k: float) -> void:
	var e: float = 1.0 - (1.0 - k) * (1.0 - k)
	var y: float = lerpf(_deck - RISE_FROM, _gulp_y(), e)
	var open: float = smoothstep(OPEN_FROM, OPEN_TO, k) * JAW_OPEN
	shark.pose_free(Vector3(_x, y, _z()), _upright(0.0), open)


## The gulp: its jaws snap shut on the ship's stern half with the captain on it, and the bow half breaks away.
func _gulp() -> void:
	step = Step.HANG
	gulped_at = time
	marks["gulp"] = time
	var world: RunWorld = boss.world
	var p: Player = world.player
	if ship != null and is_instance_valid(ship):
		ship.swallow(Vector3(_side, 0.0, 0.0), Vector3(0.0, 0.0, -p.speed))
	shark.shudder()
	var mouth := Vector3(_x - _side * 2.0, _keel + 3.0, _z())
	world.effects.shake(0.45, 0.5)
	boss.sound(&"guppy_gulp", mouth)
	boss.log_event(&"gulp", {"x": mouth.x, "y": mouth.y})


## The splash beside the top, then the swim out at sea.
func _begin_swim() -> void:
	step = Step.SWIM
	marks["swim"] = time
	_foam_t = 0.0
	boss.sound(&"guppy_swim", Vector3(_x, _deck - 8.0, _z()))
	_pose_swim(0.0)
	boss.log_event(&"swim", {"fin": _fin_point()})


## The sea's surface (the open beach's water: BeachSkin.beach_drop under the street).
func _sea_y() -> float:
	var beach := boss.world.skin as BeachSkin
	return -beach.beach_drop if beach != null else MechaGuppyWaterfall.SEA_Y


## The swim, `k` (0 to 1) of the way: horizontal under the sea out past the shoreline, its back under the water and its
## dorsal fin out of it, heading away ahead and out to sea.
func _pose_swim(k: float) -> void:
	var world: RunWorld = boss.world
	var p: Player = world.player
	var ahead: float = lerpf(SWIM_FROM, SWIM_TO, k)
	var d: float = p.distance + ahead
	var shore: float = maxf(world.geo.wall_x() + BeachOpen.shore(int(_side), d) + SWIM_OUT, SWIM_CLEAR)
	var out: float = shore + SWIM_AWAY * k
	var pos := Vector3(_side * out, _sea_y() - SWIM_DEPTH, TrackGeometry.world_z(d))
	# Heading ahead and out: its snout along the way it swims, its back up.
	var way := Vector3(_side * SWIM_AWAY, 0.0, -(SWIM_TO - SWIM_FROM + p.speed * tuning.swim_seconds)).normalized()
	var down := Vector3.DOWN
	var across: Vector3 = way.cross(down)
	shark.pose_free(pos, Basis(across, way, down), 0.0)


## The dorsal fin's root at the waterline, in the world.
func _fin_point() -> Vector3:
	return shark.head_transform() * FIN_AT


## The victory riff riff_after the gulp, if it plays (DESIGN-TBD).
func _riff_due() -> void:
	if riff_played or gulped_at < 0.0 or time < gulped_at + tuning.riff_after:
		return
	riff_played = true
	if tuning.victory_riff_on and _riff != &"":
		boss.world.play_sfx(_riff)
		boss.log_event(&"riff", {"name": _riff})
