class_name PlayerSfx
extends Node
## Plays a placeholder sound for each Player.movement_event. Gameplay never waits on audio.

var _players: Dictionary = {}


func _ready() -> void:
	for sound: StringName in PlaceholderSfx.names():
		var p := AudioStreamPlayer.new()
		p.stream = PlaceholderSfx.get_stream(sound)
		p.max_polyphony = 3
		add_child(p)
		_players[sound] = p


func bind(player: Player) -> void:
	player.movement_event.connect(_on_movement_event)


func _on_movement_event(kind: StringName) -> void:
	var p: AudioStreamPlayer = _players.get(kind)
	if p != null and PlaceholderSfx.audible():
		p.play()
