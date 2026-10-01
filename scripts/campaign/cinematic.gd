class_name Cinematic
extends Node
## Base for a cinematic scene (a short scene between levels or zones, GDD §1 and §6). The App
## instances it under the world root, calls play(def, step) and continues on `finished`.
##
## Cinematics are skippable at any moment: the pause action (or a skip button of the scene's own)
## emits `skip_requested`, whoever plays the cinematic answers with skip() (the App does), and the
## scene ends promptly, emitting `finished`. A scene emits `finished` once. DESIGN-TBD
## (docs/questions/f1.md 4): skippable at once, even the first time.
##
## Build cinematics with the toolkit in scripts/cinematics/ (CinematicSequencer: camera paths,
## actors on the humanoid rig, timed events, a stretch of the zone to play on, the skip button,
## Reduced flashing); docs/ARCHITECTURE.md, "Writing a cinematic", shows how.

signal finished
## The player asked to skip: the pause action, or the scene's skip button. The App answers with skip().
signal skip_requested

var def: CinematicDef
## The campaign step it fills: the App's, or when it plays on its own (a review tool, a test), the
## campaign step whose slot holds `def`. Null if no step holds it.
var step: CampaignStep
## The zone it belongs to (the step's), whose data it takes its look from; null without a step.
var zone: ZoneDef
## Which of the zone's slots it fills: &"intro", &"boss_intro" or &"outro" (&"" without a step).
var slot: StringName = &""


func play(p_def: CinematicDef, p_step: CampaignStep = null) -> void:
	def = p_def
	step = p_step if p_step != null else find_step(p_def)
	zone = step.zone if step != null else null
	slot = StringName(step.id.get_slice("/", 1)) if step != null else &""
	_play()


## Override: start the cinematic; emit `finished` at the end.
func _play() -> void:
	finished.emit()


func skip() -> void:
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		skip_requested.emit()


## The campaign step (the App's campaign) whose cinematic slot holds `p_def`, or null.
static func find_step(p_def: CinematicDef) -> CampaignStep:
	var tree := Engine.get_main_loop() as SceneTree
	var app: Node = tree.root.get_node_or_null(^"App") if tree != null and tree.root != null else null
	var campaign := app.get(&"campaign") as Campaign if app != null else null
	if campaign == null or p_def == null:
		return null
	for s: CampaignStep in campaign.steps():
		if s.kind == CampaignStep.Kind.CINEMATIC and s.cinematic != null \
				and (s.cinematic == p_def or (p_def.id != &"" and s.cinematic.id == p_def.id)):
			return s
	return null
