class_name GoldenConvergenceDefeat
extends RefCounted
## The Golden Convergence's defeat (GDD §10, "Defeat: the feed dies. When The Magnate falls, the feed cuts out on
## every screen in the world, freeing everyone the cult held"; proposed: "the third stomp: he convulses, his
## cables tear out of his back one by one, and the screens on the towers glitch and go dark, one after another
## outward. The music cuts out with them. In the silence he collapses on the causeway ahead, the last light in
## his cracks goes out, and the runner runs past him; then the victory riff"). A small part of the encounter
## (GoldenConvergence.defeat), from its _on_defeated to victory_over():
## - the death throes (magnate_death): he convulses (`shudder`, gentler with Reduced flashing) and lurches ahead
##   of the runner over defeat_lurch, out of their way into the lane furthest from them, defeat_ahead in front
##   (at the run speed), keeping pace there; his sides block a lane switch into his lane from the runner on
##   (harmless: he's no hitbox left);
## - a cable tears out of his back every tear_every from tear_at (GoldenConvergenceMagnate.tear_cable, sparks in
##   the cult's warm white, magnate_tear);
## - from blackout_at the screens glitch and go dark from him outward (GoldenCourtSkin.set_feed_blackout, its
##   radius growing at blackout_speed; magnate_screens, a pop at each screen as it dies), and the music cuts out
##   (MusicDirector.stop over music_cut); past blackout_reach every screen in the world is dark (the feed's
##   power off);
## - once his last cable is out he collapses where he is (magnate_collapse; the light in his cracks dies over
##   crack_fade): anchored on the causeway, in silence;
## - the runner runs past him; riff_after later the victory riff (the music's own riff, chosen before it cut), or
##   silence (victory_riff_on off: docs/questions/e5d.md 13); then it's over (victory_over).
## The encounter's victory_riff() is false: the riff is this sequence's, not LevelRun's at the defeat.

enum Step { NONE, THROES, DOWN, OVER }

var boss: GoldenConvergence
var magnate: GoldenConvergenceMagnate
var chase: GoldenConvergenceChase
var step: Step = Step.NONE
var time: float = 0.0
## The lane he collapses in (the furthest from the runner), where his body lies (track distance), the cables
## torn, the blackout's radius (-1 before it starts) and centre.
var lane: int = 0
var collapse_at: float = 0.0
var torn: int = 0
var blackout_radius: float = -1.0
var blackout_center := Vector3.ZERO
var music_cut: bool = false
var riff_played: bool = false
## When the runner got past him (seconds into the defeat; -1 before).
var passed_at: float = -1.0

var _from: Vector3
var _from_rel: float = 0.0
var _riff: StringName = &""
var _screens: Array[Dictionary] = []
var _down_t: float = 0.0


func _init(p_boss: GoldenConvergence, p_magnate: GoldenConvergenceMagnate, p_chase: GoldenConvergenceChase) -> void:
	boss = p_boss
	magnate = p_magnate
	chase = p_chase


func start() -> void:
	step = Step.THROES
	time = 0.0
	torn = 0
	blackout_radius = -1.0
	music_cut = false
	riff_played = false
	passed_at = -1.0
	chase.drive(self)
	chase.alarm = 0.0
	var lanes: int = boss.lane_count()
	var pl: int = boss.player_lane()
	lane = lanes - 1 if float(pl) <= (lanes - 1) * 0.5 else 0
	_from = magnate.global_position
	_from_rel = -_from.z - boss.player_distance()
	var music: MusicDirector = MusicDirector.instance()
	_riff = MusicDirector.level_complete_sound(music.library.riff_track(music.current()) if music != null else &"",
		boss.world.sfx_library)
	magnate.play(&"stagger")
	magnate.shudder = 1.0
	magnate.ports_glow = 0.0
	boss.sound(&"magnate_death", boss.sound_point(magnate.head_point()))
	boss.world.effects.shake(0.5, 0.6)
	boss.log_event(&"defeat_start", {"lane": lane, "runner_lane": pl, "riff": _riff})


## True once the runner is past him and the riff (or the silence) has come.
func over() -> bool:
	return step == Step.OVER


func tick(delta: float) -> void:
	if step == Step.NONE:
		return
	time += delta
	var t: GoldenConvergenceTuning = boss.tuning
	# The screens go on dying outward until every one in the world is dark, the riff or not.
	_tick_screens(t)
	if step == Step.OVER:
		_keep_out()
		return
	_tick_cables(t)
	if step == Step.THROES:
		_tick_throes(delta, t)
	else:
		_tick_down(delta, t)
	_keep_out()


## Lurching ahead of the runner into his lane, convulsing, keeping pace there until his last cable is out.
func _tick_throes(delta: float, t: GoldenConvergenceTuning) -> void:
	var d: float = boss.player_distance()
	var v: float = boss.speed_planned()
	var u: float = clampf(time / maxf(t.defeat_lurch, 0.05), 0.0, 1.0)
	var ez: float = u * u * (3.0 - 2.0 * u)
	var kx: float = clampf(u / 0.45, 0.0, 1.0)
	var ex: float = kx * kx * (3.0 - 2.0 * kx)
	var ahead: float = t.defeat_ahead * v + GoldenConvergenceMagnateModel.BODY_LENGTH * 0.5
	var rel: float = lerpf(_from_rel, ahead, ez)
	var x: float = lerpf(_from.x, boss.world.geo.lane_x(lane), ex)
	var y: float = lerpf(_from.y, 0.0, ex) + 0.35 * absf(sin(time * 7.0)) * (1.0 - u)
	magnate.play(&"stagger")
	magnate.shudder = lerpf(1.0, 0.6, u)
	chase.place(Vector3(x, y, TrackGeometry.world_z(d + rel)), 0.0, delta)
	var all_out: bool = torn >= magnate.cable_count() and time >= t.tear_at + t.tear_every * magnate.cable_count()
	if u >= 1.0 and all_out:
		_collapse()


func _collapse() -> void:
	step = Step.DOWN
	_down_t = 0.0
	collapse_at = -magnate.global_position.z
	magnate.play(&"collapse")
	magnate.speed = 0.0
	boss.sound(&"magnate_collapse", boss.sound_point(magnate.global_position))
	boss.world.effects.burst(magnate.global_position + Vector3(0.0, 0.4, 0.0), Color(0.6, 0.57, 0.52), 30, 1.6)
	boss.log_event(&"collapse", {"lane": lane, "at": collapse_at, "runner": boss.player_distance(),
		"runner_lane": boss.player_lane()})


## Down: the convulsions die, the light in his cracks goes out; once the runner is past him, the riff.
func _tick_down(delta: float, t: GoldenConvergenceTuning) -> void:
	_down_t += delta
	magnate.shudder = maxf(0.6 * (1.0 - _down_t / maxf(t.collapse_seconds, 0.05)), 0.0)
	magnate.crack_light = clampf(1.0 - _down_t / maxf(t.crack_fade, 0.05), 0.0, 1.0)
	var d: float = boss.player_distance()
	if passed_at < 0.0 and d > collapse_at + GoldenConvergenceMagnateModel.BODY_LENGTH * 0.5 + 1.0:
		passed_at = time
		boss.log_event(&"runner_past", {"runner": d})
	if passed_at >= 0.0 and time >= passed_at + t.riff_after and magnate.crack_light <= 0.0:
		if t.victory_riff_on and not riff_played:
			riff_played = true
			boss.world.play_sfx(_riff)
			boss.log_event(&"riff", {"name": _riff})
		step = Step.OVER
		boss.log_event(&"defeat_over")


## His cables tear out one by one.
func _tick_cables(t: GoldenConvergenceTuning) -> void:
	var due: int = 0
	if time >= t.tear_at:
		due = mini(int((time - t.tear_at) / maxf(t.tear_every, 0.05)) + 1, magnate.cable_count())
	while torn < due:
		var socket: Vector3 = magnate.socket_point(torn)
		if magnate.tear_cable(torn):
			boss.world.effects.burst(socket, Color(1.0, 0.93, 0.82), 16, 0.5)
			boss.world.effects.burst(socket, Color(0.25, 0.23, 0.21), 10, 0.7)
			boss.sound(&"magnate_tear", boss.sound_point(socket))
			boss.log_event(&"cable_torn", {"n": torn})
		torn += 1


## The screens glitch and die from him outward; the music cuts out.
func _tick_screens(t: GoldenConvergenceTuning) -> void:
	if time < t.blackout_at:
		return
	var skin := boss.world.skin as GoldenCourtSkin
	if blackout_radius < 0.0:
		blackout_center = magnate.global_position
		blackout_radius = 0.0
		_note_screens(skin)
		var music: MusicDirector = MusicDirector.instance()
		if music != null:
			music.stop(t.music_cut)
		music_cut = true
		boss.sound(&"magnate_screens", boss.sound_point(blackout_center))
		boss.log_event(&"music_cut")
		boss.log_event(&"blackout_start", {"center": blackout_center})
	blackout_radius = (time - t.blackout_at) * t.blackout_speed
	if skin != null:
		var dead: bool = blackout_radius >= t.blackout_reach
		skin.set_feed(1, 0.0 if dead else 1.0, 0.0 if dead else 0.7)
		skin.set_feed_blackout(blackout_center, blackout_radius)
	for i: int in range(_screens.size() - 1, -1, -1):
		var s: Dictionary = _screens[i]
		if float(s["distance"]) <= blackout_radius:
			boss.world.play_sfx_at(&"magnate_screen", s["center"])
			_screens.remove_at(i)


## The towers' screens in sight (around the runner), for their pops as they die.
func _note_screens(skin: GoldenCourtSkin) -> void:
	_screens.clear()
	if skin == null:
		return
	var d: float = boss.player_distance()
	var face: float = boss.world.geo.wall_x()
	for side: int in [-1, 1]:
		for tower: Dictionary in skin.towers(side, side * face, d - 80.0, d + 400.0):
			var c: Vector3 = tower["screen_center"]
			_screens.append({"center": c, "distance": c.distance_to(blackout_center)})


## His sides block a switch into his lane from the runner to past him: he's never in their way.
func _keep_out() -> void:
	var geo: TrackGeometry = boss.world.geo
	var d: float = boss.player_distance()
	var far: float = -magnate.global_position.z + GoldenConvergenceMagnateModel.BODY_LENGTH * 0.5 + 0.5
	if far <= d:
		magnate.set_blocker(false)
		return
	var z0: float = d - 1.0
	magnate.set_blocker(true, Vector3(geo.lane_x(lane), GoldenConvergenceMagnate.BLOCKER_HEIGHT * 0.5,
		TrackGeometry.world_z((z0 + far) * 0.5)), Vector3(geo.lane_width * 0.6, GoldenConvergenceMagnate.BLOCKER_HEIGHT, far - z0))
