class_name HazardTelegraph
extends AudioStreamPlayer3D
## Plays a positional warning when its Hazard enters WARNING: the audio half of the
## telegraph that CLAUDE.md requires before anything can hurt the player.


func bind(hazard: Hazard, sound: StringName) -> void:
	stream = PlaceholderSfx.get_stream(sound)
	max_distance = 70.0
	unit_size = 8.0
	hazard.state_changed.connect(_on_state_changed)


func _on_state_changed(state: Hazard.State) -> void:
	if state == Hazard.State.WARNING and PlaceholderSfx.audible():
		play()
