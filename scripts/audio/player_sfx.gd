class_name PlayerSfx
extends Node
## Plays the sound for each Player.movement_event, plus game-level sounds by name.
## Gameplay never waits on audio.

var _players: Dictionary = {}


func setup(library: SfxLibrary) -> void:
	for sound: String in library.names():
		var stream: AudioStream = library.stream(sound)
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = library.volume(sound)
		p.max_polyphony = 3
		add_child(p)
		_players[sound] = p


func bind(player: Player) -> void:
	player.movement_event.connect(play)


func play(sound: StringName) -> void:
	var p: AudioStreamPlayer = _players.get(String(sound))
	if p != null and SfxLibrary.audible():
		p.play()
