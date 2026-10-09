class_name GoldenConvergenceTransition
extends RefCounted
## Stage 2's intros (GDD §10; task E5d-d), a small part of the encounter (GoldenConvergence.transition):
## - phase 4's, the transition (proposed: "the third ship's blast bursts the suit open; its golden plates fall
##   away and the empty suit crashes down beside the causeway. The Magnate claws his way out, roars, and leaps
##   over the runner to land behind them. The checkpoint is here"), played the same whether the fight got here
##   or a retry resumes here (the checkpoint): the suit's chest plates burst open (GoldenConvergenceSuit.burst,
##   both shoulders' pipes already blown out) and fly off to either side, down past the balustrades; he claws his
##   way out of the man's room (`claw`), roars (magnate_roar, the screech) as the towers' screens switch to his
##   roaring face (GoldenCourtSkin.set_feed mode 1, a glitch fading out: steady with Reduced flashing); the empty
##   suit topples off the causeway's side into the pools (pacing the runner, never over the track) with a crash
##   (magnate_suit_fall; magnate_suit_down as it hits the water); he leaps off it high over the runner and lands
##   behind them, where the chase takes him (GoldenConvergenceChase.begin). From then the suit is gone (hidden,
##   never a target) and he can be hurt;
## - phases 5 and 6's, the hurl (proposed: "after a stomp he hurls himself clear, roaring, and drops back
##   behind"): from where he is, a howling leap up onto the balustrade away from the runner, then the chase's
##   drop back.
## Timings: GoldenConvergenceTuning's transition group and hurl_seconds; never over the phase's pace (intros
## keep their seconds).

## The plates fly off at this speed out to their side, this fast up, and are gone after this long.
const PLATE_OUT: float = 16.0
const PLATE_UP: float = 7.0
const PLATE_LIFE: float = 3.5
## The suit topples off this far to its side and this far down (into the pools), rolling over this far.
const SUIT_OUT: float = 62.0
const SUIT_DOWN: float = 58.0
const SUIT_ROLL: float = 1.25
## The leap over the runner: how high it arcs over its straight line down.
const LEAP_ARC: float = 7.0
## The hurl: its leap's share of hurl_seconds (the rest is the drop back), and how high it goes.
const HURL_LEAP: float = 0.32
const HURL_HEIGHT: float = 3.4
## Where he comes out of the suit: the cavity's front (the suit's space, at its scale 1).
const CAVITY := Vector3(0.0, 10.4, 1.4)

var boss: GoldenConvergence
var magnate: GoldenConvergenceMagnate
var chase: GoldenConvergenceChase
## &"transition", &"hurl" or &"" (none under way); seconds into it.
var kind: StringName = &""
var time: float = 0.0
## Transitions played (tests: once a fight that gets here, again on a retry).
var played: int = 0
var hurls: int = 0
## The suit's fall: its side (-1 left, 1 right), and whether it has crashed.
var fall_side: int = 1
var suit_down: bool = false

var _done: Dictionary = {}
var _plates: Array[Dictionary] = []
## The suit's part of the transition goes on after he lands, until it's down: seconds into it.
var _suit_falling: bool = false
var _suit_time: float = 0.0
var _leap_from: Vector3
var _leap_rel: float = 0.0
var _hurl_from: Vector3
var _hurl_side: int = 1


func _init(p_boss: GoldenConvergence, p_magnate: GoldenConvergenceMagnate, p_chase: GoldenConvergenceChase) -> void:
	boss = p_boss
	magnate = p_magnate
	chase = p_chase


## Phase 4's intro: the suit bursts, he comes out, roars, the suit falls, he leaps over the runner.
func start() -> void:
	clear()
	kind = &"transition"
	time = 0.0
	played += 1
	_done = {}
	suit_down = false
	var suit: GoldenConvergenceSuit = boss.suit
	suit.visible = true
	suit.immune_to_weapons = true
	# The suit's damage so far: both shoulders' pipes blown out by the first two ships (E5d-c's hits).
	suit.set_pipes_broken(-1, true)
	suit.set_pipes_broken(1, true)
	fall_side = -1 if boss.rng.randf() < 0.5 else 1
	_suit_falling = true
	_suit_time = 0.0
	chase.drive(self)
	magnate.hide_all()
	magnate.immune_to_weapons = true
	magnate.restore_cables()
	magnate.crack_light = 1.0
	magnate.shudder = 0.0
	boss.sound(&"magnate_burst", boss.sound_point(suit.head_point()))
	boss.log_event(&"transition", {"n": played, "side": fall_side})


## Phases 5 and 6's intro: he hurls himself clear, howling, and drops back behind.
func start_hurl() -> void:
	clear()
	kind = &"hurl"
	time = 0.0
	hurls += 1
	if not magnate.shown():
		# A review starting past phase 4 (--phase=5): the suit's already gone, the feed his, he's behind.
		boss.suit.visible = false
		boss.suit.immune_to_weapons = true
		var skin := boss.world.skin as GoldenCourtSkin
		if skin != null:
			skin.set_feed(1, 1.0, 0.0)
		chase.begin(boss.player_lane())
		chase.place(Vector3(boss.world.geo.lane_x(boss.player_lane()), 0.0,
			TrackGeometry.world_z(boss.player_distance() - boss.tuning.chase_gap)), 0.0, 0.0)
	magnate.immune_to_weapons = false
	_hurl_from = magnate.global_position
	var lane_x: float = boss.world.geo.lane_x(boss.player_lane())
	_hurl_side = 1 if _hurl_from.x >= lane_x else -1
	chase.drive(self)
	magnate.play(&"hurl")
	magnate.ports_glow = 0.0
	boss.sound(&"magnate_howl", boss.sound_point(magnate.global_position))
	boss.world.effects.shake(0.25, 0.3)
	boss.log_event(&"hurl", {"n": hurls, "side": _hurl_side})


func busy() -> bool:
	return kind != &""


func tick(delta: float) -> void:
	_tick_plates(delta)
	if _suit_falling:
		_suit_time += delta
		_tick_suit()
	if kind == &"":
		return
	time += delta
	if kind == &"hurl":
		_tick_hurl(delta)
	else:
		_tick_transition(delta)


# --- The transition ---------------------------------------------------------------------------------------

func _tick_transition(delta: float) -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var suit: GoldenConvergenceSuit = boss.suit
	# The burst: the chest's plates swing open, a blast of smoke and sparks.
	suit.burst = maxf(suit.burst, clampf(time / maxf(t.burst_seconds, 0.05), 0.0, 1.0))
	if _once(&"blast", 0.0):
		var chest: Vector3 = suit.global_transform * Vector3(0.0, GoldenConvergenceModel.CHEST.y, 4.0)
		boss.world.effects.burst(chest, Color(0.95, 0.88, 0.7), 60, 3.0)
		boss.world.effects.burst(chest, Color(0.22, 0.2, 0.19), 40, 4.0)
		boss.world.effects.shake(0.45, 0.6)
	if _once(&"plates", t.plates_off_at):
		_throw_plates()
	# He claws out of the man's room, roars, and leaps over the runner.
	if time < t.claw_at:
		return
	var cavity: Vector3 = suit.global_transform * (CAVITY * boss.tuning.suit_scale)
	if time < t.leap_at:
		var k: float = clampf((time - t.claw_at) / maxf(t.claw_seconds, 0.05), 0.0, 1.0)
		# Out of the cavity onto the chest's rim, facing the runner.
		var at: Vector3 = cavity + suit.global_transform.basis * Vector3(0.0, -0.6 + 0.6 * k, -1.8 * (1.0 - k))
		magnate.play(&"claw" if time < t.roar_at else &"roar")
		# Burning from the blast: his cracks smoulder bright as he comes out of the dark, settling as he roars.
		magnate.crack_light = lerpf(3.0, 1.0, clampf((time - t.roar_at) / 0.8, 0.0, 1.0))
		chase.place(at, PI, delta)
		if _once(&"emerge", t.claw_at):
			boss.log_event(&"magnate_emerges")
		if _once(&"roar", t.roar_at):
			boss.sound(&"magnate_roar", boss.sound_point(magnate.head_point()))
			var skin := boss.world.skin as GoldenCourtSkin
			if skin != null:
				skin.set_feed(1, 1.0, 0.8)
			boss.log_event(&"magnate_roar")
		_tick_feed_glitch(t)
		return
	_tick_feed_glitch(t)
	if _once(&"leap", t.leap_at):
		_leap_from = magnate.global_position
		_leap_rel = -_leap_from.z - boss.player_distance()
		magnate.play(&"leap")
		boss.sound(&"magnate_leap", boss.sound_point(_leap_from))
		boss.log_event(&"transition_leap")
	var u: float = clampf((time - t.leap_at) / maxf(t.transition_leap_seconds, 0.05), 0.0, 1.0)
	var lane_x: float = boss.world.geo.lane_x(boss.player_lane())
	var rel: float = lerpf(_leap_rel, -t.chase_gap, u)
	var x: float = lerpf(_leap_from.x, lane_x, u * u * (3.0 - 2.0 * u))
	var y: float = lerpf(_leap_from.y, 0.0, u) + LEAP_ARC * 4.0 * u * (1.0 - u)
	# Facing the way he flies (back over the runner), turning to face down the track as he lands.
	var yaw: float = lerp_angle(PI, 0.0, clampf((u - 0.75) / 0.25, 0.0, 1.0))
	chase.place(Vector3(x, y, TrackGeometry.world_z(boss.player_distance() + rel)), yaw, delta)
	if u >= 1.0 and not _done.has(&"landed"):
		_done[&"landed"] = true
		kind = &""
		magnate.immune_to_weapons = false
		chase.begin(boss.player_lane())
		boss.log_event(&"transition_done")


## The suit: floating (and reeling a little from the burst) until it topples off the causeway's side into the
## pools, pacing the runner, never over the track; then it's gone.
func _tick_suit() -> void:
	var t: GoldenConvergenceTuning = boss.tuning
	var suit: GoldenConvergenceSuit = boss.suit
	var fall_k: float = clampf((_suit_time - t.suit_fall_at) / maxf(t.suit_fall_seconds, 0.05), 0.0, 1.0)
	var base: Transform3D = boss.suit_transform()
	if _suit_time < t.suit_fall_at:
		suit.reel = 0.35 * sin(PI * clampf(_suit_time / maxf(t.suit_fall_at, 0.05), 0.0, 1.0))
		suit.set_pose(base)
		return
	var e: float = fall_k * fall_k
	var roll := Basis(Vector3.BACK, -fall_side * SUIT_ROLL * e)
	var at: Vector3 = base.origin + Vector3(fall_side * SUIT_OUT * (1.0 - (1.0 - fall_k) * (1.0 - fall_k)), -SUIT_DOWN * e, 0.0)
	suit.set_pose(Transform3D(base.basis * roll, at))
	if not _done.has(&"fall_sound"):
		_done[&"fall_sound"] = true
		boss.sound(&"magnate_suit_fall", boss.sound_point(at))
	if fall_k >= 1.0:
		_suit_falling = false
		suit_down = true
		suit.visible = false
		var splash := Vector3(fall_side * (boss.world.geo.wall_x() + 25.0), -18.0, at.z)
		boss.world.effects.burst(splash, Color(0.75, 0.72, 0.66), 50, 5.0)
		boss.world.effects.shake(0.4, 0.5)
		boss.sound(&"magnate_suit_down", boss.sound_point(splash))
		boss.log_event(&"suit_down", {"side": fall_side})


## The feed's glitch fading out after the switch to his face.
func _tick_feed_glitch(t: GoldenConvergenceTuning) -> void:
	var skin := boss.world.skin as GoldenCourtSkin
	if skin == null or time < t.roar_at:
		return
	var g: float = clampf(1.0 - (time - t.roar_at) / 0.7, 0.0, 1.0) * 0.8
	skin.set_feed(1, 1.0, g)


## True the first time `key` comes due (its time `at` reached).
func _once(key: StringName, at: float) -> bool:
	if _done.has(key) or time < at:
		return false
	_done[key] = true
	return true


## The chest's plates fly off to either side (the suit's own hidden, copies of their meshes thrown).
func _throw_plates() -> void:
	var suit: GoldenConvergenceSuit = boss.suit
	for mi: MeshInstance3D in suit.meshes():
		if mi.name != "Plate" or not mi.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		copy.name = "FallingPlate"
		copy.mesh = mi.mesh
		copy.material_override = mi.material_override
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.top_level = true
		boss.add_child(copy)
		copy.global_transform = mi.global_transform
		var side: float = signf((mi.global_transform.origin - suit.global_position).x)
		if side == 0.0:
			side = 1.0
		mi.visible = false
		_plates.append({"node": copy, "v": Vector3(side * PLATE_OUT, PLATE_UP, 2.0), "spin": Vector3(1.4, 0.0, side * 2.2),
			"age": 0.0})


func _tick_plates(delta: float) -> void:
	for i: int in range(_plates.size() - 1, -1, -1):
		var pl: Dictionary = _plates[i]
		var node: Node3D = pl["node"]
		pl["age"] = float(pl["age"]) + delta
		var v: Vector3 = pl["v"]
		v.y -= 18.0 * delta
		pl["v"] = v
		node.global_position += v * delta
		node.rotation += (pl["spin"] as Vector3) * delta
		if float(pl["age"]) > PLATE_LIFE:
			node.queue_free()
			_plates.remove_at(i)


# --- The hurl -----------------------------------------------------------------------------------------------

func _tick_hurl(delta: float) -> void:
	var leap: float = boss.tuning.hurl_seconds * HURL_LEAP
	var u: float = clampf(time / maxf(leap, 0.05), 0.0, 1.0)
	var e: float = 1.0 - (1.0 - u) * (1.0 - u)
	var x: float = lerpf(_hurl_from.x, chase.balustrade_x(_hurl_side), e)
	var y: float = lerpf(_hurl_from.y, chase.balustrade_y(), u) + HURL_HEIGHT * 4.0 * u * (1.0 - u)
	var z: float = _hurl_from.z - boss.speed_planned() * leap * 0.6 * e
	magnate.play(&"hurl")
	chase.place(Vector3(x, y, z), 0.0, delta)
	if u >= 1.0:
		kind = &""
		chase.drop_back(self, _hurl_side)
		boss.log_event(&"hurl_done")


## Nothing under way; thrown plates gone (a fresh phase, a test).
func clear() -> void:
	kind = &""
	_suit_falling = false
	for pl: Dictionary in _plates:
		if is_instance_valid(pl["node"]):
			(pl["node"] as Node).queue_free()
	_plates.clear()
