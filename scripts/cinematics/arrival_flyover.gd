class_name ArrivalFlyover
extends CinematicSequencer
## DESIGN-TBD (docs/questions/f1.md 1): the placeholder "arrival" flyover that every zone's intro slot
## plays (and the City's boss intro, over the fight's arena) until the owner describes the story beats
## (GDD §1: 5-15 second cinematics; task F2 builds them). A short script on the toolkit: the camera
## opens low in the street looking up at the zone's skyline and tilts down as the runner runs in below
## it, glides over the street behind the runner, and settles into the run camera's view of the runner
## as they run under one of the zone's ceilings, then fades to black. A card names the zone (before a
## boss, the boss, as the level select does), and the slot's music comes in.
##
## The stretch is built in the zone's own skin, taken from the zone's data (CineStage.skin_for: the
## zone's skin, before a boss the arena's), so a later change of skin reaches the flyover; the street
## has as many lanes as the level that follows. Its numbers are data: `flyover`, by default
## data/cinematics/arrival_flyover.tres (ArrivalFlyoverTuning).

const FLYOVER_PATH: String = "res://data/cinematics/arrival_flyover.tres"

## Its numbers (null: FLYOVER_PATH's).
@export var flyover: ArrivalFlyoverTuning


func numbers() -> ArrivalFlyoverTuning:
	if flyover == null:
		flyover = load(FLYOVER_PATH) as ArrivalFlyoverTuning
	return flyover


## Where along the track the runner is at time `t` (it runs at the run speed from runner_start).
func runner_at(t: float) -> float:
	return numbers().runner_start + tuning.run_speed * t


func _stage_def() -> CineStageDef:
	var f: ArrivalFlyoverTuning = numbers()
	var d := CineStageDef.new()
	var start: float = runner_at(f.duration) - f.ceiling_before_end
	d.ceilings = PackedVector2Array([Vector2(start, start + f.ceiling_length)])
	d.gaps = f.gaps
	return d


func _make_timeline() -> CineTimeline:
	var f: ArrivalFlyoverTuning = numbers()
	var t := CineTimeline.new()
	t.duration = f.duration
	t.letterbox = true
	# The runner runs in from behind the camera, down the start lane, at the run speed.
	var runner: CineActor = t.actor(&"runner")
	runner.at(0.0, Vector3(0.0, 0.0, f.runner_start), &"run")
	runner.at(f.duration, Vector3(0.0, 0.0, runner_at(f.duration)))
	# The opening: low in the street looking up at the skyline, rising and tilting down the street.
	t.shot(0.0, Vector3(f.open_side, f.open_height, f.open_at),
		Vector3(0.0, f.open_look_height, f.open_at + f.open_look_ahead), CinePath.Move.SMOOTH, f.fov)
	t.shot(f.reveal_end, Vector3(f.open_side * 0.5, f.reveal_height, f.reveal_at),
		Vector3(0.0, 1.0, runner_at(f.reveal_end) + f.glide_look_ahead), CinePath.Move.SMOOTH, f.fov)
	# The glide: above and behind the runner, looking down the street ahead of them.
	var glide: CineCameraKey = t.shot(f.glide_end, Vector3(f.glide_side, f.glide_height, -f.glide_behind),
		Vector3(0.0, 0.5, f.glide_look_ahead), CinePath.Move.SMOOTH, f.fov)
	glide.follow = &"runner"
	glide.watch = &"runner"
	# Settled: the run camera's view of the runner (RunCamera with MovementTuning's camera numbers), riding
	# along to the end, so the level that follows opens on the same view.
	var side: float = (stage.origin_x if stage != null else 0.0) * (tuning.camera_follow_x - 1.0)
	for at: float in [f.duration - f.settled_before_end, f.duration]:
		var settled: CineCameraKey = t.shot(at, Vector3(side, tuning.camera_height, -tuning.camera_distance),
			Vector3(side, 1.0, tuning.camera_look_ahead), CinePath.Move.SMOOTH, tuning.camera_fov)
		settled.follow = &"runner"
		settled.watch = &"runner"
	# The picture fades in from black and out at the end; the slot's music comes in; the card names it.
	# DESIGN-TBD (docs/questions/f1.md 2, 3): the card's words.
	t.effect(0.0, CineEvent.FADE_IN, f.fade_in)
	t.music(0.0, CineEvent.ZONE_MUSIC, f.music_fade)
	if slot == &"boss_intro":
		t.card(f.card_at, "{boss}", "ZONE {zone_number}  ·  BOSS", f.card_seconds)
	else:
		t.card(f.card_at, "{zone}", "ZONE {zone_number}", f.card_seconds)
	t.effect(f.duration - f.fade_out, CineEvent.FADE_OUT, f.fade_out)
	return t
