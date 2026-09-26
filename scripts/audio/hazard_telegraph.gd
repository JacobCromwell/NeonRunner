class_name HazardTelegraph
extends AudioStreamPlayer3D
## Plays a positional warning when its Hazard enters WARNING: the audio half of the
## telegraph that CLAUDE.md requires before anything can hurt the player.


func bind(hazard: Hazard, sound: AudioStream, level_db: float, full_volume_distance: float, silent_distance: float) -> void:
	stream = sound
	volume_db = level_db
	unit_size = full_volume_distance
	max_distance = silent_distance
	hazard.state_changed.connect(_on_state_changed)


func _on_state_changed(state: Hazard.State) -> void:
	if state == Hazard.State.WARNING and SfxLibrary.audible():
		play()
