class_name GoldenConvergenceChase
extends RefCounted
## The Magnate's chase (GDD §10, Second stage: "a chase: stage 1 is a calm, distant giant the player can't
## touch; stage 2 flips it. He's fast and feral and hunts the runner from behind on all fours, leaping along the
## palace's walls and ceilings"; proposed: "behind the runner, his shadow and a marker at the screen's bottom edge
## show his lane, as with the Enforcer Truck"). A small part of the encounter (GoldenConvergence.chase) that moves
## him whenever no attack does:
## - following: chase_gap behind the runner (behind the camera: never seen), in the lane the runner was in
##   chase_lane_delay ago (the Enforcer Truck's way), galloping; his shadow lies on the floor of his lane,
##   stretched forward past the runner so it shows at the screen's bottom, his marker under his lane at the bottom edge
##   (red for a Pounce's warning: `alarm`), his breathing and growls heard from where he is;
## - an attack takes him (drive) and gives him back (drop_back): he drops back behind the runner from wherever
##   it left him over drop_back_seconds (divided by the phase's pace), along a balustrade when he's on one, down
##   into his lane once he's behind the camera;
## - place(): every driver puts him there, so his gallop's rate and his leap's pitch follow how he moves.
## Never solid, never harmful: only his attacks' boxes and his stunned body are (GoldenConvergenceMagnate).
## Framing is kept relative to the runner (metres, not stretched by the pace); time comes from the physics step.
## A Claw Slash's warning (E5d-e) flashes the marker (`alarm_flash`: its red beating, steady red with Reduced
## flashing) and holds it shown while he lunges into view (`marker_hold`).

enum Mode { OFF, FOLLOW, DRIVEN, RETURN }

## How fast his shadow and marker fade in and out (1/s).
const FADE_RATE: float = 3.0
## His shadow while he's behind the runner: a long soft blob on the floor of his lane, its front end this far
## ahead of the runner and its darkest middle just behind them (the run camera's view ends only just behind the
## runner's feet), this long and this wide.
const SHADOW_END: float = -2.5
const SHADOW_LENGTH: float = 7.0
const SHADOW_WIDTH: float = 2.2
## A flashing alarm beats this many times a second (the marker's red never dimmer than ALARM_FLASH_LOW of it).
const ALARM_FLASH_HZ: float = 7.0
const ALARM_FLASH_LOW: float = 0.3
## Where a balustrade's top is (out from the wall's line, over the causeway's edge) when the skin doesn't say.
const BALUSTRADE_OUT: float = 0.55
const BALUSTRADE_Y: float = 1.1

var boss: GoldenConvergence
var magnate: GoldenConvergenceMagnate
var mode: Mode = Mode.OFF
## Who moves him while DRIVEN (an attack, the transition, the defeat): its instance id (0: nobody). An id, not
## the object: the drivers hold the chase, so holding them back would keep both alive after the fight.
var driver: int = 0
## The lane he follows and his world x.
var lane: int = 0
var x: float = 0.0
## 0-1: a Pounce's warning (the marker red).
var alarm: float = 0.0
## A Claw Slash's warning (E5d-e): the alarm flashes, and the marker shows even while he's in view.
var alarm_flash: bool = false
var marker_hold: bool = false
## Drops back done (tests).
var returns: int = 0

var _lane_log: Array = []
var _shown: float = 0.0
var _flash_t: float = 0.0
var _breath_t: float = 0.0
var _growl_t: float = 0.0
var _last_pos := Vector3.ZERO
var _has_last: bool = false
## The drop back: {from (world), rel0, t, seconds, side}.
var _ret: Dictionary = {}


func _init(p_boss: GoldenConvergence, p_magnate: GoldenConvergenceMagnate) -> void:
	boss = p_boss
	magnate = p_magnate


## The chase begins (stage 2's first pattern, or a test): following from the runner's lane now.
func begin(at_lane: int = -1) -> void:
	lane = at_lane if at_lane >= 0 else boss.player_lane()
	x = boss.world.geo.lane_x(lane)
	_lane_log.clear()
	mode = Mode.FOLLOW
	driver = 0
	_breath_t = 0.0
	_growl_t = boss.tuning.growl_every * 0.5


## An attack (or the transition, the defeat) moves him from now on.
func drive(by: Object) -> void:
	driver = by.get_instance_id()
	mode = Mode.DRIVEN


## `by` is done with him: he drops back behind the runner from where he is (along the balustrade on `side`, -1
## or 1, if he's on it; 0 straight back).
func drop_back(by: Object, side: int = 0) -> void:
	if driver != by.get_instance_id() and mode == Mode.DRIVEN:
		return
	driver = 0
	var d: float = boss.player_distance()
	var from: Vector3 = magnate.global_position
	_ret = {"from": from, "rel0": -from.z - d, "t": 0.0, "seconds": boss.tuning.drop_back_seconds / boss.pace(),
		"side": side}
	mode = Mode.RETURN


## True while he's following behind the runner, nobody driving him.
func home() -> bool:
	return mode == Mode.FOLLOW


## Off: nothing moves him (before the transition, after the defeat).
func stop() -> void:
	mode = Mode.OFF
	driver = 0
	alarm = 0.0
	alarm_flash = false
	marker_hold = false


## Every physics frame of stage 2.
func tick(delta: float) -> void:
	_note_lane()
	# His shadow and marker show wherever he's behind the runner out of sight: following, dropping back, or
	# driven there (a Pounce's roar turns the marker red before he leaps).
	var behind: bool = mode != Mode.OFF
	match mode:
		Mode.FOLLOW:
			_follow(delta)
		Mode.RETURN:
			_return(delta)
	_tick_signs(delta, behind)
	if mode == Mode.FOLLOW:
		_tick_voice(delta)


## The lane he'll follow: the runner's, chase_lane_delay ago.
func _note_lane() -> void:
	var now: float = boss.fight_time()
	var pl: int = boss.player_lane()
	if _lane_log.is_empty() or int(_lane_log[-1][1]) != pl:
		_lane_log.append([now, pl])
	var delay: float = boss.tuning.chase_lane_delay
	while _lane_log.size() > 1 and float(_lane_log[1][0]) <= now - delay:
		_lane_log.remove_at(0)
	if not _lane_log.is_empty() and float(_lane_log[0][0]) <= now - delay:
		lane = int(_lane_log[0][1])


## Following chase_gap behind the runner in his lane, galloping.
func _follow(delta: float) -> void:
	var target: float = boss.world.geo.lane_x(lane)
	x = move_toward(x, target, boss.tuning.chase_side_speed * delta)
	magnate.play(&"run")
	place(Vector3(x, 0.0, TrackGeometry.world_z(boss.player_distance() - boss.tuning.chase_gap)), 0.0, delta)


## Dropping back: from where an attack left him to his place behind the runner, along the balustrade first if
## he's on one, down into his lane once he's behind the camera.
func _return(delta: float) -> void:
	var r: Dictionary = _ret
	r["t"] = float(r["t"]) + delta
	var u: float = clampf(float(r["t"]) / maxf(float(r["seconds"]), 0.05), 0.0, 1.0)
	var e: float = u * u * (3.0 - 2.0 * u)
	var d: float = boss.player_distance()
	var from: Vector3 = r["from"]
	var rel: float = lerpf(float(r["rel0"]), -boss.tuning.chase_gap, e)
	var home_x: float = boss.world.geo.lane_x(lane)
	var side: int = int(r["side"])
	var px: float
	var py: float
	if side != 0:
		# Along the balustrade until he's behind the camera, then down into his lane (never into a lane in sight).
		var bx: float = balustrade_x(side)
		var cam: float = boss.world.tuning.camera_distance + 0.5
		var behind: float = clampf((-rel - cam) / maxf(boss.tuning.chase_gap - cam, 0.5), 0.0, 1.0)
		var k: float = 1.0 if u >= 1.0 else minf(clampf((u - 0.65) / 0.35, 0.0, 1.0), behind)
		px = lerpf(lerpf(from.x, bx, clampf(u / 0.2, 0.0, 1.0)), home_x, k * k * (3.0 - 2.0 * k))
		py = lerpf(lerpf(from.y, balustrade_y(), clampf(u / 0.2, 0.0, 1.0)), 0.0, k)
	else:
		px = lerpf(from.x, home_x, e)
		py = lerpf(from.y, 0.0, e)
	x = px
	magnate.play(&"run")
	place(Vector3(px, py, TrackGeometry.world_z(d + rel)), 0.0, delta)
	if u >= 1.0:
		mode = Mode.FOLLOW
		returns += 1
		boss.log_event(&"magnate_home", {"lane": lane})


## His shadow and marker while he's behind the runner (faded out while he's in view).
func _tick_signs(delta: float, behind: bool) -> void:
	var d: float = boss.player_distance()
	var rel: float = -magnate.global_position.z - d
	var out_of_view: bool = behind and rel < -boss.world.tuning.camera_distance + 1.0
	var held: bool = marker_hold and mode != Mode.OFF
	_shown = move_toward(_shown, 1.0 if out_of_view or held else 0.0, FADE_RATE * delta)
	magnate.set_marker(magnate.global_position.x, _shown, marker_alarm(delta))
	if out_of_view:
		# Cast forward from him (the court's light behind him) along his lane, past the runner: its darkest
		# middle just behind them at the screen's bottom, so it shows his lane.
		var end: float = d - SHADOW_END
		magnate.set_shadow(Vector3(magnate.global_position.x, 0.0, TrackGeometry.world_z(end - SHADOW_LENGTH * 0.5)),
			SHADOW_LENGTH, SHADOW_WIDTH, _shown)
	elif mode != Mode.OFF:
		# In view: under him, smaller and fainter the higher he is.
		var p: Vector3 = magnate.global_position
		var lift: float = clampf(p.y / 8.0, 0.0, 0.8)
		var on_floor: bool = absf(p.x) <= boss.world.geo.wall_x() + 0.2
		magnate.set_shadow(p, 3.2 * (1.0 - lift * 0.5), 1.9 * (1.0 - lift * 0.5), (1.0 - lift) if on_floor else 0.0)


## The marker's red now: `alarm`, beating on and off while it flashes (a Claw Slash's warning), steady with Reduced
## flashing.
func marker_alarm(delta: float) -> float:
	if not alarm_flash:
		_flash_t = 0.0
		return alarm
	_flash_t += delta
	if Settings.flashing_reduced:
		return alarm
	var on: bool = fmod(_flash_t * ALARM_FLASH_HZ, 1.0) < 0.5
	return alarm * (1.0 if on else ALARM_FLASH_LOW)


## His breathing and his growls from where he is (cosmetic).
func _tick_voice(delta: float) -> void:
	_breath_t -= delta
	_growl_t -= delta
	if _breath_t <= 0.0:
		_breath_t = boss.tuning.breath_every
		magnate.breathe(&"magnate_breath")
	if _growl_t <= 0.0:
		_growl_t = boss.tuning.growl_every
		magnate.breathe(&"magnate_growl")


# --- Placing him -----------------------------------------------------------------------------------------

## Puts his root at `pos` (world), turned `yaw` (radians; 0 facing down the track, away from the runner), and
## notes how he moved (his gallop's rate, his leap's pitch).
func place(pos: Vector3, yaw: float, delta: float, roll: float = 0.0) -> void:
	if _has_last and delta > 0.0:
		var v: Vector3 = (pos - _last_pos) / delta
		magnate.speed = -v.z
		magnate.rise = v.y
	_last_pos = pos
	_has_last = true
	magnate.set_pose(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, roll), pos))


## The world x of the balustrade's top on `side` (-1 left, 1 right).
func balustrade_x(side: int) -> float:
	return signf(side) * (boss.world.geo.wall_x() + BALUSTRADE_OUT)


## How high the balustrade's top is.
func balustrade_y() -> float:
	var skin := boss.world.skin as GoldenCourtSkin
	return skin.balustrade_height if skin != null else BALUSTRADE_Y


## The balustrade nearer world x `at_x` (ties to the right).
func nearer_side(at_x: float) -> int:
	return -1 if at_x < 0.0 else 1
