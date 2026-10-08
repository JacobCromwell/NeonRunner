class_name PlayerSfx
extends Node
## Plays the sound for each Player.movement_event, plus game-level sounds by name.
## Gameplay never waits on audio. Every sound goes to the SFX bus (settings set its volume).

## Every sound asked for, whether or not it plays (headless runs play none, a library may lack it):
## tests listen.
signal requested(sound: StringName)
## Every sound cut short by stop(): tests listen.
signal stopped(sound: StringName)

var _players: Dictionary = {}


## Readies a player for every sound the library lists and this build has (the web demo leaves out
## sounds it never plays; asking for one of those by name still warns).
func setup(library: SfxLibrary) -> void:
	for sound: String in library.names():
		if not library.has_file(StringName(sound)):
			continue
		var stream: AudioStream = library.stream(sound)
		if stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.volume_db = library.volume(sound)
		p.max_polyphony = 3
		p.bus = SfxLibrary.BUS
		add_child(p)
		_players[sound] = p


func bind(player: Player) -> void:
	player.movement_event.connect(play)


func play(sound: StringName) -> void:
	requested.emit(sound)
	var p: AudioStreamPlayer = _players.get(String(sound))
	if p != null and SfxLibrary.audible():
		p.play()


## Cuts a sound off where it is: a warning whose attack will never come (its enemy was shot down
## first) must not go on to its climax.
func stop(sound: StringName) -> void:
	stopped.emit(sound)
	var p: AudioStreamPlayer = _players.get(String(sound))
	if p != null:
		p.stop()
