class_name CinematicSequencer
extends Cinematic
## The cinematic toolkit's player (docs/ARCHITECTURE.md, "Writing a cinematic"). It plays a CineTimeline:
## builds its stage (CineStage: a stretch of the slot's zone in the zone's skin), its actors
## (CineActorNode: the runner and cyborgs on the humanoid rig), a camera and the overlay (CineOverlay:
## letterbox, fades, flashes, text cards, the skip button), then runs the clock: camera keys, actor keys
## and events (sounds, music cues, text cards, effects, cues) in order, and emits `finished` at the end.
##
## Two ways to write one:
## - In data: a scene whose root has this script and `timeline` set to a CineTimeline resource.
## - In a short script: a script extending this class that overrides _make_timeline() (it may read
##   `stage`, already built from _stage_def(), for the street's lanes and walls) and, if it likes,
##   _on_cue() for its own moments and _on_advance() to move things of its own (props) on the clock,
##   and _stage_near() to keep the street built under props standing further back than it sees.
##   switch_stage() cuts to another stretch, even another zone's.
##
## Skippable at any moment: skip() (the App calls it when the player asks, skip_requested) stops the
## clock and its sounds and emits `finished` at once; a music cue already played carries on into the
## next step. Everything that flashes honours Reduced flashing (CineOverlay.flash), camera shake the
## Screen shake setting, and the cinematic holds while the game window is in the background, so it
## never ends (and a level starts) unattended.

## A CUE event's moment came.
signal cue(cue_name: StringName)

const TUNING_PATH: String = "res://data/tuning/movement.tres"
const SFX_PATH: String = "res://data/audio/sfx_library.tres"
## The camera sees as far as the run's (RunCamera).
const CAMERA_FAR: float = 600.0
const CAMERA_NEAR: float = 0.05

## The cinematic in data (null: a script builds it, _make_timeline()).
@export var timeline: CineTimeline

## What's playing, and where: the timeline, the stage (null without one), the camera and the overlay.
var playing: CineTimeline
var stage: CineStage
var camera: Camera3D
var overlay: CineOverlay
var tuning: MovementTuning
var sfx: SfxLibrary
## The actors by id (CineActorNode).
var actors: Dictionary = {}
## Seconds since it started.
var time: float = 0.0
## True once it's over (played out or skipped), and whether it was skipped.
var done: bool = false
var skipped: bool = false
## Every event fired so far, one line each ("music city", "text NEON CITY", "effect fade_out", ...):
## for tests and review tools.
var log_lines: PackedStringArray = []

var _next_event: int = 0
var _sounds: Dictionary = {}
var _held: bool = false
var _shake_strength: float = 0.0
var _shake_time: float = 0.0
var _shake_left: float = 0.0
var _shake_t: float = 0.0


func _play() -> void:
	tuning = load(TUNING_PATH) as MovementTuning
	sfx = load(SFX_PATH) as SfxLibrary
	var stage_def: CineStageDef = _stage_def()
	if stage_def != null:
		stage = CineStage.new()
		stage.name = "Stage"
		add_child(stage)
		stage.build(stage_def, CineStage.skin_for(stage_def, zone, slot), tuning)
	playing = _make_timeline()
	if playing == null:
		push_warning("CinematicSequencer: %s has no timeline" % (def.id if def != null else name))
		_finish()
		return
	playing.sort()
	for line: String in playing.problems(sfx):
		push_warning("CinematicSequencer (%s): %s" % [def.id if def != null else name, line])
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = CAMERA_NEAR
	camera.far = CAMERA_FAR
	add_child(camera)
	camera.make_current()
	var variant: StringName = stage.skin.enemy_variant if stage != null else &"city"
	for i: int in playing.actors.size():
		var a: CineActor = playing.actors[i]
		var node := CineActorNode.new()
		add_child(node)
		node.setup(a, stage, tuning, variant, i + 1)
		actors[a.id] = node
	overlay = CineOverlay.new()
	overlay.name = "Overlay"
	add_child(overlay)
	overlay.set_letterbox(playing.letterbox)
	overlay.skip_pressed.connect(func() -> void: skip_requested.emit())
	for e: CineEvent in playing.events:
		if e.kind == CineEvent.Kind.SOUND:
			_sound_player(e.name)
	# The first frame already shows time 0: its events have fired (a fade from black starts black).
	advance(0.0)


## The stage the timeline plays on (null: none). Default: the timeline's own, `timeline.stage`. A script
## that builds its timeline in _make_timeline() returns its stage's description here.
func _stage_def() -> CineStageDef:
	return timeline.stage if timeline != null else null


## The timeline to play. Default: `timeline` (the cinematic in data). A script overrides this to build one
## (CineTimeline's helpers), and may use `stage`, already built, for the street's geometry.
func _make_timeline() -> CineTimeline:
	return timeline


## A CUE event's moment: override for a script's own beats (the `cue` signal fires too).
func _on_cue(_cue_name: StringName) -> void:
	pass


## Every step of the clock, after the actors have moved and before the camera does (`time` is now, and
## `delta` since the last step; 0 the first time): override to move a script's own things (props) on
## the cinematic's clock, so they keep time with it when a test or a tool steps it.
func _on_advance(_delta: float) -> void:
	pass


## How far back along the track the stage must stay built (metres), given `near`: the nearest the camera and
## the visible actors are. A script whose own props stand further back (a horde behind the runner) returns less.
func _stage_near(near: float) -> float:
	return near


## Cuts to another stretch: builds a stage from `stage_def` dressed in `skin` (null: the slot's own, as
## _stage_def()'s), on the same lanes, so track space stays where it was and every key goes on meaning
## the same place; the stage before goes (hidden, its environment out of the world, then freed), and the
## actors and the camera carry on in the new one. Building a stage takes a few frames' time (the arrival
## flyover's takes 15-40 ms): cut under a fade or a flash. Returns the new stage.
func switch_stage(stage_def: CineStageDef, skin: ZoneSkin = null) -> CineStage:
	var lanes: int = stage.geo.lane_count if stage != null else 0
	var old: CineStage = stage
	if old != null:
		old.retire()
	stage = CineStage.new()
	stage.name = "Stage2" if old != null and old.name == "Stage" else "Stage"
	add_child(stage)
	if old != null:
		move_child(stage, old.get_index())
		old.queue_free()
	stage.build(stage_def, skin if skin != null else CineStage.skin_for(stage_def, zone, slot), tuning, lanes)
	for node: CineActorNode in actors.values():
		node.stage = stage
	var look: String = stage.skin.resource_path.get_file().get_basename()
	log_lines.append("stage %s" % (look if look != "" else "-"))
	return stage


func skip() -> void:
	if done:
		return
	skipped = true
	for p: AudioStreamPlayer in _sounds.values():
		if p != null:
			p.stop()
	_finish()


## How long it lasts (seconds).
func duration() -> float:
	return playing.duration if playing != null else 0.0


func _process(delta: float) -> void:
	if done or _held or playing == null:
		return
	advance(delta)


## Moves the clock on by `delta`: events due, actors, camera, the stage's chunks; ends at the duration.
## The clock runs by itself while it plays (_process); a test or a tool may step it instead, having
## called set_process(false). The overlay's fades and cards run on real frames either way.
func advance(delta: float) -> void:
	if done or playing == null:
		return
	time = minf(time + delta, playing.duration)
	while _next_event < playing.events.size() and playing.events[_next_event].time <= time:
		var e: CineEvent = playing.events[_next_event]
		_next_event += 1
		_fire(e)
		if done:
			return
	for node: CineActorNode in actors.values():
		node.update(time, delta, actors)
	_on_advance(delta)
	_update_camera(delta)
	if stage != null:
		var near: float = stage.to_track(camera.global_position).z
		for node: CineActorNode in actors.values():
			if node.visible:
				near = minf(near, node.track_position.z)
		stage.update(_stage_near(near), time)
	if time >= playing.duration:
		_finish()


## Ends it: nothing of it shows any more (its stage, sun, actors and overlay hide, and its environment
## leaves the world), then `finished`. Whoever plays it frees it; the App starts the next step at once,
## whose first frame then shows only that step.
func _finish() -> void:
	if done:
		return
	done = true
	set_process(false)
	# Over: the pause action belongs to whatever comes next (the level's pause menu), even in the frame
	# before this is freed.
	set_process_unhandled_input(false)
	if stage != null:
		stage.retire()
	for node: CineActorNode in actors.values():
		node.visible = false
	if overlay != null:
		overlay.visible = false
	finished.emit()


# --- Events ----------------------------------------------------------------------------------

func _fire(e: CineEvent) -> void:
	match e.kind:
		CineEvent.Kind.SOUND:
			var p: AudioStreamPlayer = _sound_player(e.name)
			if p != null and SfxLibrary.audible():
				p.play()
			log_lines.append("sound %s" % e.name)
		CineEvent.Kind.MUSIC:
			var track: StringName = music_track(e.name)
			var music: MusicDirector = MusicDirector.instance()
			if e.name == CineEvent.ZONE_MUSIC and track == &"":
				log_lines.append("music -")  # No zone to take it from: the music playing carries on.
			else:
				if music != null:
					if track == &"":
						music.stop(e.duration)
					else:
						music.play(track, e.duration)
				log_lines.append("music %s" % track)
		CineEvent.Kind.TEXT:
			var title: String = fill_text(e.text)
			overlay.show_card(title, fill_text(e.caption), e.duration)
			log_lines.append("text %s" % title)
		CineEvent.Kind.EFFECT:
			_effect(e)
			log_lines.append("effect %s" % e.name)
		CineEvent.Kind.CUE:
			log_lines.append("cue %s" % e.name)
			cue.emit(e.name)
			_on_cue(e.name)


func _effect(e: CineEvent) -> void:
	match e.name:
		CineEvent.FADE_IN:
			overlay.fade_to(0.0, e.duration, e.color, 1.0)
		CineEvent.FADE_OUT:
			overlay.fade_to(1.0, e.duration, e.color)
		CineEvent.FLASH:
			overlay.flash(e.strength, e.duration, e.color if e.color != Color.BLACK else Color.WHITE)
		CineEvent.SHAKE:
			# The Screen shake setting scales it (0 when the player turned shake off).
			var amount: float = 1.0
			var app: Node = get_node_or_null(^"/root/App")
			if app != null and app.get(&"profile") != null:
				amount = Settings.shake_scale(app.get(&"profile") as Profile)
			_shake_strength = e.strength * amount
			_shake_time = maxf(e.duration, 0.01)
			_shake_left = _shake_time
		CineEvent.LETTERBOX_IN:
			overlay.set_letterbox(true, e.duration)
		CineEvent.LETTERBOX_OUT:
			overlay.set_letterbox(false, e.duration)


## The music track a cue names: CineEvent.ZONE_MUSIC is the slot's own (before a boss the fight's,
## BossDef.music, else the zone's), anything else itself (empty: no music).
func music_track(cue_track: StringName) -> StringName:
	if cue_track != CineEvent.ZONE_MUSIC:
		return cue_track
	if zone == null:
		return &""
	if slot == &"boss_intro" and zone.boss != null and zone.boss.music != &"":
		return zone.boss.music
	return zone.music


## `text` translated, with the slot's data filled in (translated too): {zone}, {zone_number}, {boss},
## {title}.
func fill_text(text: String) -> String:
	if text == "":
		return text
	var out: String = tr(text)
	if not out.contains("{"):
		return out
	var number: int = step.zone_index + 1 if step != null else 0
	return out.format({
		"zone": tr(zone.display_name) if zone != null else "",
		"zone_number": str(number) if number > 0 else "",
		"boss": tr(zone.boss.display_name) if zone != null and zone.boss != null else "",
		"title": tr(def.title) if def != null else "",
	})


func _sound_player(sound: StringName) -> AudioStreamPlayer:
	if _sounds.has(sound):
		return _sounds[sound]
	var stream: AudioStream = sfx.stream(sound) if sfx != null and sfx.volume_db.has(String(sound)) else null
	var p: AudioStreamPlayer = null
	if stream != null:
		p = AudioStreamPlayer.new()
		p.name = "Sound_%s" % sound
		p.stream = stream
		p.bus = SfxLibrary.BUS
		p.volume_db = sfx.volume(sound)
		add_child(p)
	_sounds[sound] = p
	return p


# --- Camera -----------------------------------------------------------------------------------

func _update_camera(delta: float) -> void:
	var keys: Array[CineCameraKey] = playing.camera
	if keys.is_empty():
		return
	var positions: Array = []
	var follows: Array = []
	var targets: Array = []
	var watches: Array = []
	var fovs: Array = []
	var rolls: Array = []
	for k: CineCameraKey in keys:
		var follow: StringName = k.follow if actors.has(k.follow) else &""
		var watch: StringName = k.watch if actors.has(k.watch) else &""
		follows.append(follow)
		positions.append(_key_offset(k.position, follow))
		watches.append(watch)
		targets.append(_key_offset(k.target, watch))
		fovs.append(k.fov)
		rolls.append(k.roll)
	var ride := Callable(self, &"_actor_at")
	var from: Vector3 = CinePath.sample_riding(keys, positions, follows, ride, time)
	var to: Vector3 = CinePath.sample_riding(keys, targets, watches, ride, time)
	var shake := Vector3.ZERO
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		_shake_t += delta * 40.0
		var fade: float = _shake_left / _shake_time
		shake = Vector3(sin(_shake_t * 1.3), cos(_shake_t * 1.7), 0.0) * _shake_strength * fade
	camera.fov = float(CinePath.sample(keys, fovs, time))
	var dir: Vector3 = to - from
	if dir.length_squared() < 0.0001:
		camera.global_position = from + shake
		return
	# Straight up or down, "up" can't be the world's up: use the track's direction instead.
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.999 else Vector3.FORWARD
	camera.look_at_from_position(from + shake, to + shake * 0.5, up)
	var roll: float = float(CinePath.sample(keys, rolls, time))
	if not is_zero_approx(roll):
		camera.rotate_object_local(Vector3.BACK, deg_to_rad(roll))


## A camera key's point as the riding path takes it: a track-space point in world space, or with an
## actor to ride with, the offset from it (x right, y up, z ahead of it) in world axes.
func _key_offset(p: Vector3, actor_id: StringName) -> Vector3:
	if actor_id != &"":
		return Vector3(p.x, p.y, -p.z)
	return stage.point(p) if stage != null else Vector3(p.x, p.y, -p.z)


## Where actor `actor_id` is at time `at`, in world space (Vector3.ZERO for none): what a riding camera
## key follows.
func _actor_at(actor_id: StringName, at: float) -> Vector3:
	if actor_id == &"":
		return Vector3.ZERO
	var node := actors.get(actor_id) as CineActorNode
	return node.point_at(at) if node != null else Vector3.ZERO


# --- Holding while the game is in the background ------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_set_held(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_set_held(false)


func _set_held(on: bool) -> void:
	if on == _held:
		return
	_held = on
	for p: AudioStreamPlayer in _sounds.values():
		if p != null:
			p.stream_paused = on
