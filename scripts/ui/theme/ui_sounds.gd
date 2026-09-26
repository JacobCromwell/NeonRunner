class_name UiSounds
extends RefCounted
## The one hook the widgets use for UI sounds: UiSounds.play(UiSounds.MOVE). Sounds come from the
## game's SfxLibrary (data/audio/sfx_library.tres). A name the library doesn't list, or whose file
## is missing, is skipped silently, so the UI never fails because a sound isn't made yet.
## Set `hook` to route UI sounds somewhere else (an audio manager, a test).

const LIBRARY_PATH: String = "res://data/audio/sfx_library.tres"
## Focus or hover moved to another control.
const MOVE: StringName = &"ui_move"
## A control was activated.
const SELECT: StringName = &"ui_select"
## The same sound again within this many milliseconds is dropped (hover and focus together).
const REPEAT_GUARD_MS: int = 45

static var muted: bool = false
## When valid, UI sounds go to hook.call(sound) instead of the built-in players.
static var hook: Callable = Callable()
static var _library: SfxLibrary
static var _host: Node
static var _players: Dictionary = {}
static var _last_played: Dictionary = {}
static var _quiet_until_ms: int = 0


static func play(sound: StringName) -> void:
	var now: int = Time.get_ticks_msec()
	if muted or sound == &"" or now < _quiet_until_ms:
		return
	if now - int(_last_played.get(sound, -REPEAT_GUARD_MS)) < REPEAT_GUARD_MS:
		return
	_last_played[sound] = now
	if hook.is_valid():
		hook.call(sound)
		return
	if not SfxLibrary.audible() or not has_sound(sound):
		return
	var player: AudioStreamPlayer = _player(sound)
	if player != null:
		# Deferred: on the first sound the players' host is still being added to the tree.
		player.play.call_deferred()


## Whether the library has this sound and its file exists.
static func has_sound(sound: StringName) -> bool:
	var lib: SfxLibrary = library()
	if lib == null or not lib.names().has(String(sound)):
		return false
	return ResourceLoader.exists(lib.folder.path_join(String(sound) + ".wav"))


static func library() -> SfxLibrary:
	if _library == null and ResourceLoader.exists(LIBRARY_PATH):
		_library = load(LIBRARY_PATH) as SfxLibrary
	return _library


## No UI sounds for a moment: e.g. while a screen gives its first control focus.
static func quiet(seconds: float = 0.15) -> void:
	_quiet_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)


## Wires a plain button: `move` on hover and keyboard focus, `select` on press. Kit widgets do
## this themselves.
static func bind(button: BaseButton, move: StringName = MOVE, select: StringName = SELECT) -> void:
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			play(move))
	button.focus_entered.connect(func() -> void:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			play(move))
	button.pressed.connect(func() -> void: play(select))


static func _player(sound: StringName) -> AudioStreamPlayer:
	# Untyped first: the player may have been freed with the tree.
	var existing: Variant = _players.get(sound)
	if is_instance_valid(existing):
		return existing as AudioStreamPlayer
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if not is_instance_valid(_host):
		_host = Node.new()
		_host.name = "UiSounds"
		# UI sounds must play while the game is paused.
		_host.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child.call_deferred(_host)
	var lib: SfxLibrary = library()
	var p := AudioStreamPlayer.new()
	p.stream = lib.stream(sound)
	p.volume_db = lib.volume(sound)
	p.max_polyphony = 2
	_host.add_child(p)
	_players[sound] = p
	return p
