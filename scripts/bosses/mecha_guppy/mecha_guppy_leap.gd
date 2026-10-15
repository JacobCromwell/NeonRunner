class_name MechaGuppyLeap
extends RefCounted
## The defeat of Mecha Guppy and Captain Cogs (GDD §10: "if the player dodges these long enough, then the Mecha Guppy jumps
## over to the boss, Captain Cogs, and eats the boss because the shark is pissed"; "Defeat: Mecha Guppy has eaten Captain
## Cogs, and it swims away"; task E5e-c). MechaGuppy starts it as phase 3's minute ends (the win: the runner keeps running,
## safe in the framework's god mode, and nothing here has a hitbox), and holds the results until it has swum away
## (victory_over). Staged beside the top and out at sea, where the run camera sees it, never over the lanes:
## - the dive (task E5e-g: phase 3's last hit finds it in its watch beside the top on the right): it sinks out of sight
##   there first (DIVE_SECONDS), so it never jumps across to the ship's side in view;
## - the rise (leap_rise): Mecha Guppy bursts up out of the sea under Captain Cogs' ship alongside the top, upright, side-on
##   (an eye toward the runner, its chin toward the top, as it always shows itself), its jaws opening wide round the
##   ship's stern half, with a roar of machinery and water (guppy_leap);
## - the gulp: its jaws snap shut on the stern half with the captain on it (guppy_gulp, a shudder, a shake): the captain
##   and the stern are gone, and the bow half breaks away, tumbling down into the sea (CaptainCogsShip.swallow);
## - it hangs a moment (leap_hang), rising a little on, leaning out from the top;
## - it falls back (leap_fall), straight down out of sight beside the top;
## - it swims away, seen (task E5e-c's review: from the top, the deck's edge hides the sea for tens of metres out and the
##   haze the rest, so a fin at the waterline was never seen): out at sea, ahead of the runner, past the shoreline and far
##   enough out that the run camera sees over the deck's edge (_plan_breach), it bursts out of the water in one long leap
##   heading away, on ahead and out to sea (the leap's roar again; a plume of spray, MechaGuppySplash), its whole body
##   clear of the sea, its tail too, at the top of its arc (breach_seconds from the sea back to it), and dives back in
##   head first (a bigger plume; guppy_swim: the splash, then the churn as it swims off);
## - the results may follow dive_after its snout is back in the water (victory_over: about 6 s after the win), and the dive
##   goes on until its tail is under, then it's gone.
## The victory riff plays riff_after the gulp (MechaGuppyTuning.victory_riff_on; LevelRun's riff at the defeat is off:
## MechaGuppy.victory_riff). Everything keeps pace with the runner (the scene is laid out ahead of them as it begins), so
## it plays out in view; time comes from the boss's ticks. DESIGN-TBD (docs/OPEN_QUESTIONS.md item 807): the leap's
## staging.

enum Step { NONE, DIVE, RISE, HANG, FALL, BREACH, GONE }

## The dive from its watch (task E5e-g): this long (seconds), this far down (metres: out of sight under the deck's edge).
const DIVE_SECONDS: float = 0.45
const DIVE_DROP: float = 26.0
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
## The fall: how far it drops (metres: well out of sight under the deck's edge), its lean out by the end (degrees), and
## its drift out (metres).
const FALL_DROP: float = 40.0
const FALL_LEAN: float = 22.0
const FALL_OUT: float = 8.0
## The breach (the swim away): the hinge's highest is BREACH_UNDER under the deck (but at least BREACH_LOWEST over the
## sea: a low top, as a checkpoint's climb has, still sees a big leap), and at least BREACH_SHOW over the run camera's
## line past the deck's edge there (the camera follows the runner's lane in part: reckoned a lane further from this side
## than they are, to spare), and at least BREACH_CLEAR out from the track's middle (clear of the top's tower and the
## ship's falling bow); where the camera sees the sea's surface it breaks (a low top shows it near, a high one only far
## out), it leaves and meets the sea at least BREACH_SEA past the shoreline; it pulls away at BREACH_AHEAD (m/s, on top
## of keeping pace) and out to sea at BREACH_OUT; the top of its arc is at most BREACH_VIEW (degrees) off the camera's
## forward axis (inside the view on a 4:3 screen too), and it comes up at least BREACH_NEAR ahead of the runner (so most
## of its length is ahead of the camera at the top of its arc). Its hinge rises from BREACH_LEAD (seconds) under the
## surface (its snout breaks the sea first). It takes breach_seconds from the sea back to it for a leap BREACH_REF high,
## longer for a higher one (a higher top, as a runner who never baits climbs to: it moves the same and stays in view
## longer at the top of its arc), up to BREACH_LONGEST times as long. From a high top the camera sees nothing of its rise
## out of the sea, far below its line past the deck's edge: the leap then begins already under way, its snout
## BREACH_HIDDEN under that line (reckoned for the camera over the outer lane on this side, where it sees lowest), so no
## time goes by on an empty view.
const BREACH_UNDER: float = 10.0
const BREACH_LOWEST: float = 24.0
const BREACH_SHOW: float = 9.0
const BREACH_SEA: float = 14.0
const BREACH_CLEAR: float = 40.0
const BREACH_AHEAD: float = 14.0
const BREACH_OUT: float = 3.0
const BREACH_VIEW: float = 38.0
const BREACH_NEAR: float = 55.0
const BREACH_LEAD: float = 0.3
const BREACH_REF: float = 30.0
const BREACH_LONGEST: float = 1.6
const BREACH_HIDDEN: float = 2.0
## The deck's edge the camera looks past (its coping: out past the wall line, up from the deck; the eave slopes away below
## the camera's line).
const KERB := Vector2(0.3, 0.2)
## The plumes (MechaGuppySplash): where it bursts out and where it dives in (height, width; metres).
const BREACH_PLUME := Vector2(18.0, 14.0)
const DIVE_PLUME := Vector2(32.0, 24.0)

var boss: MechaGuppy
var shark: MechaGuppyShark
var ship: CaptainCogsShip
var tuning: MechaGuppyTuning
var step: Step = Step.NONE
## Seconds since the defeat began, and when the gulp came (-1 before).
var time: float = 0.0
var gulped_at: float = -1.0
var riff_played: bool = false
## Moments for the tests (seconds into the defeat): rise, gulp, fall, breach (it starts up from under the sea), surface
## (its snout breaks the sea), dive (its snout back in), over (the results may follow), gone (its tail under).
var marks: Dictionary = {}
## The breach's plan (_plan_breach; tests): its hinge leaves the sea `out` metres out from the track's middle and `ahead`
## of the runner, rises `high` metres over the sea, the sea's height `sea`.
var breach: Dictionary = {}
## The plumes, the breach's and the dive's.
var plumes: Array[MechaGuppySplash] = []

## The leap's place: the hinge's world x beside the top, its offset ahead of the runner (world z), the side it's on (-1
## left), the deck's height, the ship's keel there.
var _x: float = 0.0
var _rel_z: float = 0.0
var _side: float = -1.0
var _deck: float = 0.0
var _keel: float = 0.0
var _riff: StringName = &""
## The breach's motion (relative to the runner): its rise speed and fall-back (m/s, m/s²).
var _up: float = 0.0
var _g: float = 0.0
## Each plume's place, kept pace with: [out, ahead].
var _plume_at: Array[Vector2] = []
## The dive's start: its head's place and turn (unscaled), its jaws, the runner's world z then; and how long the dive
## takes (0 when it wasn't showing).
var _dive_from := Transform3D.IDENTITY
var _dive_jaw: float = 0.0
var _dive_z: float = 0.0
var _lead: float = 0.0


func _init(p_boss: MechaGuppy) -> void:
	boss = p_boss
	shark = boss.shark
	ship = boss.ship
	tuning = boss.tuning


## The minute is up (the win): the leap begins.
func start() -> void:
	var world: RunWorld = boss.world
	var p: Player = world.player
	time = 0.0
	gulped_at = -1.0
	riff_played = false
	# In its watch beside the top (phase 3): it dives out of sight first.
	_lead = DIVE_SECONDS if shark.shown() else 0.0
	step = Step.DIVE if _lead > 0.0 else Step.RISE
	marks = {"rise": _lead}
	var head: Transform3D = shark.head_transform()
	_dive_from = Transform3D(head.basis.orthonormalized(), head.origin)
	_dive_jaw = shark.jaw
	_dive_z = TrackGeometry.world_z(p.distance)
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
	for i: int in 2:
		var plume := MechaGuppySplash.new()
		plume.name = "Plume%d" % i
		boss.add_child(plume)
		plumes.append(plume)
		_plume_at.append(Vector2.ZERO)
	shark.hold(true)
	if step == Step.RISE:
		_begin_rise()
	else:
		shark.pose_free(_dive_from.origin, _dive_from.basis, _dive_jaw)
	boss.log_event(&"leap", {"x": _x, "deck": _deck})


func _begin_rise() -> void:
	_pose_rise(0.0)
	boss.sound(&"guppy_leap", Vector3(_x, _deck - 6.0, _z()))


## True once it has played out (the results may follow: dive_after its snout is back in the sea).
func over() -> bool:
	return marks.has("over")


## One physics step after the defeat (MechaGuppy._defeated_tick).
func tick(delta: float) -> void:
	if step == Step.NONE:
		return
	time += delta
	_riff_due()
	_advance_plumes(delta)
	match step:
		Step.DIVE:
			var k: float = clampf(time / DIVE_SECONDS, 0.0, 1.0)
			var dz: float = TrackGeometry.world_z(boss.world.player.distance) - _dive_z
			var at: Vector3 = _dive_from.origin + Vector3(0.0, -DIVE_DROP * k * k, dz)
			shark.pose_free(at, _dive_from.basis, _dive_jaw * (1.0 - k), k < 1.0)
			if k >= 1.0:
				step = Step.RISE
				_begin_rise()
		Step.RISE:
			var k: float = clampf((time - _lead) / maxf(tuning.leap_rise, 0.05), 0.0, 1.0)
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
				_plan_breach()
				step = Step.BREACH
				marks["breach"] = time
				_pose_breach(float(breach["start"]))
		Step.BREACH:
			var tau: float = time - float(marks["breach"]) + float(breach["start"])
			_pose_breach(tau)
			var tip: Vector3 = snout()
			if not marks.has("surface") and tip.y >= float(breach["sea"]):
				marks["surface"] = time
				_plume(0, tip, BREACH_PLUME)
				boss.sound(&"guppy_leap", tip)
				boss.log_event(&"breach", {"out": absf(tip.x), "ahead": -tip.z - boss.world.player.distance})
			elif marks.has("surface") and not marks.has("dive") and tau > 0.0 and tip.y < float(breach["sea"]):
				marks["dive"] = time
				_plume(1, tip, DIVE_PLUME)
				boss.sound(&"guppy_swim", tip)
				boss.log_event(&"dive", {"out": absf(tip.x)})
			if marks.has("dive") and tail().y < float(breach["sea"]) - 1.0:
				step = Step.GONE
				marks["gone"] = time
				shark.hold(false)
	if marks.has("dive") and not marks.has("over") and time >= float(marks["dive"]) + tuning.dive_after - 0.0001:
		marks["over"] = time
		boss.log_event(&"swum_away")


## The longest the defeat can take until the results may follow, at `t`, for a breach of `airtime` seconds (breach_seconds
## by default: a leap up to BREACH_REF high) (seconds; tests): the dive from its watch, the rise, the hang, the fall, the
## hinge's rise to the surface and the breach, and dive_after.
static func seconds_to_over(t: MechaGuppyTuning, airtime: float = -1.0) -> float:
	return DIVE_SECONDS + t.leap_rise + t.leap_hang + t.leap_fall + BREACH_LEAD \
		+ (airtime if airtime > 0.0 else t.breach_seconds) + t.dive_after


## The same for this leap's breach once it's planned, as it begins (tests).
func over_by() -> float:
	if breach.is_empty():
		return seconds_to_over(tuning)
	return _lead + tuning.leap_rise + tuning.leap_hang + tuning.leap_fall - float(breach["start"]) + float(breach["seconds"]) \
		+ tuning.dive_after


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


## The sea's surface (the open beach's water: BeachSkin.beach_drop under the street).
func _sea_y() -> float:
	# Phase 3's water beside the top (task E5e-g), once it shows: it swims away in that.
	if boss.top != null and boss.top.started():
		return boss.top.water_y()
	var beach := boss.world.skin as BeachSkin
	return -beach.beach_drop if beach != null else MechaGuppyWaterfall.SEA_Y


## Plans the breach (see the header and the BREACH_ numbers): how high, how far out and how far ahead, from the deck's
## height, the run camera's place (MovementTuning's camera numbers, the runner's lane) and the shoreline (BeachOpen.shore)
## along the stretch it plays over.
func _plan_breach() -> void:
	var world: RunWorld = boss.world
	var p: Player = world.player
	var mt: MovementTuning = world.tuning
	var sea: float = _sea_y()
	var high: float = maxf(_deck - BREACH_UNDER - sea, BREACH_LOWEST)
	var seconds: float = maxf(tuning.breach_seconds, 0.5) * clampf(sqrt(high / BREACH_REF), 1.0, BREACH_LONGEST)
	_up = 4.0 * high / seconds
	_g = 8.0 * high / (seconds * seconds)
	# The camera's place out toward this side (it follows the runner's lane in part: a lane further away, to spare), and
	# where its line past the deck's edge runs low enough to pass BREACH_SHOW under the hinge at the top of its arc.
	var cam: float = _side * p.position.x * mt.camera_follow_x - mt.camera_follow_x * world.geo.lane_width
	var edge: float = world.geo.wall_x() + KERB.x
	var rise: float = maxf(mt.camera_height - KERB.y, 0.5)
	var apex: float = sea + high - _deck
	var seen: float = cam + (edge - cam) * maxf(mt.camera_height - apex + BREACH_SHOW, 0.0) / rise
	var half: float = seconds * 0.5
	# Where the sea's own surface may show past the deck's edge (the camera over the outer lane on this side, the nearest it
	# comes to the edge): from there out, it must break the sea past the shoreline, not the sand.
	var near: float = (world.geo.half_width() - world.geo.lane_width * 0.5) * mt.camera_follow_x
	var surface: float = near + (edge - near) * (mt.camera_height + _deck - sea) / rise
	var out: float = maxf(seen - BREACH_OUT * half, BREACH_CLEAR)
	var ahead: float = BREACH_NEAR
	for i: int in 3:
		# In view at the top of its arc; then past the shoreline where it breaks the sea, if the camera sees that far.
		var top_out: float = out + BREACH_OUT * half
		ahead = maxf((top_out - cam) / tan(deg_to_rad(BREACH_VIEW)) - mt.camera_distance - BREACH_AHEAD * half, BREACH_NEAR)
		var from: float = p.distance + ahead - 10.0
		var to: float = p.distance + ahead + (p.speed + BREACH_AHEAD) * (seconds + BREACH_LEAD + 1.5) + 10.0
		var shore: float = 0.0
		var d: float = from
		while d <= to:
			shore = maxf(shore, BeachOpen.shore(int(_side), d))
			d += 4.0
		out = maxf(seen - BREACH_OUT * half, BREACH_CLEAR)
		if out + BREACH_OUT * seconds >= surface:
			out = maxf(out, world.geo.wall_x() + shore + BREACH_SEA + BREACH_OUT * BREACH_LEAD)
	# Where it begins: under the sea (its snout breaking it first), or, from a high top, already risen to just out of sight.
	var start: float = -BREACH_LEAD
	var snout_len: float = (MechaGuppySharkModel.JAW_LENGTH + MechaGuppySharkModel.TIP_CAP) * MechaGuppyShark.SCALE
	var tau: float = -BREACH_LEAD
	while tau < half:
		var x: float = out + BREACH_OUT * tau
		var hinge: float = sea + _up * tau - 0.5 * _g * tau * tau
		var climb: float = (_up - _g * tau) / Vector3(BREACH_OUT, _up - _g * tau, BREACH_AHEAD).length()
		var line: float = _deck + mt.camera_height - rise * (x - near) / maxf(edge - near, 0.1)
		if hinge + climb * snout_len >= line - BREACH_HIDDEN:
			break
		start = tau
		tau += 0.02
	breach = {"out": out, "ahead": ahead, "high": high, "sea": sea, "seen": seen, "surface": surface, "seconds": seconds,
		"start": start}
	boss.log_event(&"breach_plan", breach)


## The breach `tau` seconds after its hinge reaches the sea's surface (negative before): the hinge on its arc, kept pace
## with the runner, the head along the way it moves as the runner sees it (snout first, its back up).
func _pose_breach(tau: float) -> void:
	var p: Player = boss.world.player
	var sea: float = float(breach["sea"])
	var x: float = float(breach["out"]) + BREACH_OUT * tau
	var ahead: float = float(breach["ahead"]) + BREACH_AHEAD * tau
	var pos := Vector3(_side * x, sea + _up * tau - 0.5 * _g * tau * tau, TrackGeometry.world_z(p.distance + ahead))
	var way := Vector3(_side * BREACH_OUT, _up - _g * tau, -BREACH_AHEAD).normalized()
	var down: Vector3 = (Vector3.DOWN - way * way.dot(Vector3.DOWN)).normalized()
	shark.pose_free(pos, Basis(way.cross(down), way, down), 0.0)


## Its snout's tip and its tail's end, in the world (where it breaks the sea; when it's under; tests).
func snout() -> Vector3:
	return shark.head_transform() * Vector3(0.0, MechaGuppySharkModel.JAW_LENGTH + MechaGuppySharkModel.TIP_CAP, 0.0)


func tail() -> Vector3:
	return shark.head_transform() * Vector3(0.0, -MechaGuppySharkModel.BODY_LENGTH - MechaGuppySharkModel.TAIL_STALK
		- MechaGuppySharkModel.TAIL_FIN, 0.0)


## Plume `i` where the snout breaks the sea (at `at`), `size` (height, width), kept pace with from then on.
func _plume(i: int, at: Vector3, size: Vector2) -> void:
	var p: Player = boss.world.player
	_plume_at[i] = Vector2(absf(at.x), -at.z - p.distance)
	plumes[i].play(Vector3(at.x, float(breach["sea"]), at.z), size.x, size.y)


func _advance_plumes(delta: float) -> void:
	var p: Player = boss.world.player
	for i: int in plumes.size():
		var plume: MechaGuppySplash = plumes[i]
		if not is_instance_valid(plume) or not plume.playing():
			continue
		plume.advance(delta)
		var at: Vector2 = _plume_at[i]
		plume.global_position = Vector3(_side * at.x, plume.global_position.y, TrackGeometry.world_z(p.distance + at.y))


## The victory riff riff_after the gulp, if it plays (DESIGN-TBD).
func _riff_due() -> void:
	if riff_played or gulped_at < 0.0 or time < gulped_at + tuning.riff_after:
		return
	riff_played = true
	if tuning.victory_riff_on and _riff != &"":
		boss.world.play_sfx(_riff)
		boss.log_event(&"riff", {"name": _riff})
