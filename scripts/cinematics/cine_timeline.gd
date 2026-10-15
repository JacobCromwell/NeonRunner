class_name CineTimeline
extends Resource
## One cinematic, described in data (a .tres of this) or built in a short script (the helpers below):
## how long it lasts, the stretch of zone it plays on, the camera's keys, the actors and the timed
## events. CinematicSequencer plays it; docs/ARCHITECTURE.md, "Writing a cinematic", shows both ways.
##
## Points are in track space (CineStage: x metres right of the start lane's centre, y metres up, z
## metres along the track). Keys and events are sorted by time when it plays.

## Runner poses a key may name (CineActorKey.pose), and a cyborg's.
const RUNNER_POSES: Array[StringName] = [&"run", &"slide", &"dash", &"stomp", &"dead", &"lie", &"get_up", &"climb",
	&"walk", &"get_in"]
const CYBORG_POSES: Array[StringName] = [&"idle", &"walk", &"aim", &"run_away", &"cower", &"die", &"lie", &"crouch"]
const EXPRESSIONS: Array[StringName] = [&"neutral", &"aiming", &"shocked", &"dead", &"corrupt_grin", &"corrupt_broken"]

## Seconds; it ends then (emits `finished`), unless skipped first.
@export_range(1.0, 60.0, 0.1, "or_greater", "suffix:s") var duration: float = 10.0
## The letterbox bars are up from the start (the letterbox_in and letterbox_out effects move them).
@export var letterbox: bool = true
## Where it plays (null: no stage; the scene brings its own set, lights and environment).
@export var stage: CineStageDef
@export var camera: Array[CineCameraKey] = []
@export var actors: Array[CineActor] = []
@export var events: Array[CineEvent] = []


# --- Building one in a script -------------------------------------------------------------------

## A camera key: at `time` the camera is at `position` looking at `target` (track space; see
## CineCameraKey for following and watching an actor).
func shot(time: float, position: Vector3, target: Vector3, move: CinePath.Move = CinePath.Move.SMOOTH,
		fov: float = 70.0) -> CineCameraKey:
	var k := CineCameraKey.new()
	k.time = time
	k.position = position
	k.target = target
	k.move = move
	k.fov = fov
	camera.append(k)
	return k


## An actor (add its path with CineActor.at()).
func actor(id: StringName, kind: CineActor.Kind = CineActor.Kind.RUNNER, look: StringName = &"") -> CineActor:
	var a := CineActor.new()
	a.id = id
	a.kind = kind
	a.look = look
	actors.append(a)
	return a


func sound(time: float, sound_name: StringName, volume_db: float = 0.0) -> CineEvent:
	var e := _event(time, CineEvent.Kind.SOUND, sound_name)
	e.volume_db = volume_db
	return e


## A music cue: `track` from the music library, CineEvent.ZONE_MUSIC, or empty for none, crossfading
## over `fade` seconds.
func music(time: float, track: StringName, fade: float = 1.0) -> CineEvent:
	var e := _event(time, CineEvent.Kind.MUSIC, track)
	e.duration = fade
	return e


## A text card: `text` large, `caption` small above it, for `seconds`.
func card(time: float, text: String, caption: String = "", seconds: float = 3.0) -> CineEvent:
	var e := _event(time, CineEvent.Kind.TEXT, &"")
	e.text = text
	e.caption = caption
	e.duration = seconds
	return e


## An effect (CineEvent.EFFECTS) taking `seconds`.
func effect(time: float, effect_name: StringName, seconds: float = 0.5, strength: float = 1.0,
		color: Color = Color.BLACK) -> CineEvent:
	var e := _event(time, CineEvent.Kind.EFFECT, effect_name)
	e.duration = seconds
	e.strength = strength
	e.color = color
	return e


## A cue the sequencer's script hears at `time` (CinematicSequencer.cue and _on_cue).
func cue(time: float, cue_name: StringName) -> CineEvent:
	return _event(time, CineEvent.Kind.CUE, cue_name)


func find_actor(id: StringName) -> CineActor:
	for a: CineActor in actors:
		if a.id == id:
			return a
	return null


## Sorts the keys and events by time (keeping the order of those at the same time).
func sort() -> void:
	_sort_keys(camera)
	for a: CineActor in actors:
		_sort_keys(a.keys)
	var index: Dictionary = _indices(events)
	events.sort_custom(func(x: CineEvent, y: CineEvent) -> bool:
		return x.time < y.time or (x.time == y.time and int(index[x]) < int(index[y])))


## What's wrong with it, one line each (empty when it's sound). `sfx` also checks the sounds' names.
## Music cues may name a track the library doesn't have yet: it's skipped quietly until it exists.
func problems(sfx: SfxLibrary = null) -> PackedStringArray:
	var out := PackedStringArray()
	if duration <= 0.0:
		out.append("its duration is %.2f s" % duration)
	if camera.is_empty():
		out.append("it has no camera keys")
	var ids: Dictionary = {}
	for a: CineActor in actors:
		if a.id == &"" or ids.has(a.id):
			out.append("actor '%s': ids must be set and unique" % a.id)
		ids[a.id] = a
	_check_keys(camera, "the camera", out)
	for k: CineCameraKey in camera:
		for other: StringName in [k.follow, k.watch]:
			if other != &"" and not ids.has(other):
				out.append("a camera key at %.2f s names no actor '%s'" % [k.time, other])
	for a: CineActor in actors:
		var what: String = "actor '%s'" % a.id
		if a.keys.is_empty():
			out.append("%s has no keys" % what)
		_check_keys(a.keys, what, out)
		for k: CineActorKey in a.keys:
			var poses: Array[StringName] = RUNNER_POSES if a.kind == CineActor.Kind.RUNNER else CYBORG_POSES
			if k.pose != &"" and not poses.has(k.pose):
				out.append("%s: no pose '%s' at %.2f s" % [what, k.pose, k.time])
			if k.expression != &"" and (a.kind != CineActor.Kind.CYBORG or not EXPRESSIONS.has(k.expression)):
				out.append("%s: no face '%s' at %.2f s" % [what, k.expression, k.time])
			if k.aim_at != &"" and k.aim_at != &"none" and (a.kind != CineActor.Kind.CYBORG or not ids.has(k.aim_at)):
				out.append("%s: can't aim at '%s' at %.2f s" % [what, k.aim_at, k.time])
	for e: CineEvent in events:
		var when: String = "the %s event at %.2f s" % [CineEvent.Kind.keys()[e.kind].to_lower(), e.time]
		if e.time < 0.0 or e.time > duration:
			out.append("%s is outside 0-%.2f s" % [when, duration])
		match e.kind:
			CineEvent.Kind.SOUND:
				if e.name == &"" or (sfx != null and not sfx.volume_db.has(String(e.name))):
					out.append("%s plays no sound the library has ('%s')" % [when, e.name])
			CineEvent.Kind.TEXT:
				if e.text.strip_edges() == "":
					out.append("%s has no text" % when)
			CineEvent.Kind.EFFECT:
				if not CineEvent.EFFECTS.has(e.name):
					out.append("%s: no effect '%s'" % [when, e.name])
			CineEvent.Kind.CUE:
				if e.name == &"":
					out.append("%s has no name" % when)
	return out


func _event(time: float, kind: CineEvent.Kind, event_name: StringName) -> CineEvent:
	var e := CineEvent.new()
	e.time = time
	e.kind = kind
	e.name = event_name
	events.append(e)
	return e


static func _check_keys(keys: Array, what: String, out: PackedStringArray) -> void:
	var last: float = -INF
	for k: CineKey in keys:
		if k.time < last:
			out.append("%s: keys out of order at %.2f s" % [what, k.time])
		last = k.time


## Sorts `keys` by time in place, keeping the order of keys at the same time.
static func _sort_keys(keys: Array) -> void:
	var index: Dictionary = _indices(keys)
	keys.sort_custom(func(x: CineKey, y: CineKey) -> bool:
		return x.time < y.time or (x.time == y.time and int(index[x]) < int(index[y])))


## Each item's position in `items`.
static func _indices(items: Array) -> Dictionary:
	var index: Dictionary = {}
	for i: int in items.size():
		index[items[i]] = i
	return index
