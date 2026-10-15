class_name Settings
extends RefCounted
## The player's settings (GDD §3: audio volume and full key rebinding; plus accessibility options
## from OPEN_QUESTIONS §10), stored in Profile.settings and applied to the engine. Volumes are
## linear 0–1 per bus (Master, Music, SFX). Key bindings replace an action's keyboard keys and
## leave its other devices (touch, later controllers) alone.

const DEFAULTS: Dictionary = {
	"volume_master": 0.9,
	"volume_music": 0.7,
	"volume_sfx": 0.9,
	"screen_shake": true,
	"reduced_flashing": false,
	## First-encounter hints can be turned off here (FB 7).
	"hints": true,
	## The Marketplace citizens (GDD §5, task D3), who also play in the Casino's shop windows (task K1): scenery
	## only, off on a low-end device regardless of this (DeviceProfile.is_low_end(), citizens_enabled()).
	"citizens": true,
	"bindings": {},
}
## The actions a player can rebind, in menu order (CLAUDE.md principle 1: gameplay uses only these).
const REBINDABLE: Array[StringName] = [&"move_left", &"move_right", &"jump", &"slide", &"dash", &"slow_time", &"pause"]
const ACTION_LABELS: Dictionary = {
	&"move_left": "Move left", &"move_right": "Move right", &"jump": "Jump", &"slide": "Slide",
	&"dash": "Juggernaut dash", &"slow_time": "Slow time", &"pause": "Pause",
}

## The profile's Reduced flashing, for visuals that aren't shaders (shaders read the global uniform
## `reduced_flashing`). Kept current by apply_visuals().
static var flashing_reduced: bool = false

## Whether the Marketplace's and the Casino's citizens (tasks D3, K1) build at all: the player's own setting, and off on a
## low-end device regardless (CLAUDE.md: "added only if they don't noticeably cost performance...").
## Kept current by apply_visuals(), like flashing_reduced, so scenery code never needs a Profile.
static var citizens_enabled: bool = true


static func value(profile: Profile, key: String) -> Variant:
	return profile.settings.get(key, DEFAULTS.get(key))


static func set_value(profile: Profile, key: String, v: Variant) -> void:
	profile.settings[key] = v
	apply(profile)


## Applies every setting to the engine (at startup and after changes).
static func apply(profile: Profile) -> void:
	for bus: String in ["Master", "Music", "SFX"]:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var linear: float = clampf(float(value(profile, "volume_" + bus.to_lower())), 0.0, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.001)
	apply_bindings(profile)
	apply_visuals(profile)


## Visual accessibility: Reduced flashing turns hazard strobes into steady glows (the hazard shaders
## read the global shader uniform, other visuals `flashing_reduced`).
static func apply_visuals(profile: Profile) -> void:
	flashing_reduced = reduced_flashing(profile)
	RenderingServer.global_shader_parameter_set(&"reduced_flashing", 1.0 if flashing_reduced else 0.0)
	citizens_enabled = bool(value(profile, "citizens")) and not DeviceProfile.is_low_end()


static func apply_bindings(profile: Profile) -> void:
	var bindings: Dictionary = value(profile, "bindings")
	for action: Variant in bindings:
		var name := StringName(String(action))
		if not InputMap.has_action(name):
			continue
		for e: InputEvent in InputMap.action_get_events(name):
			if e is InputEventKey:
				InputMap.action_erase_event(name, e)
		for code: Variant in bindings[action]:
			var key := InputEventKey.new()
			key.physical_keycode = int(code) as Key
			InputMap.action_add_event(name, key)


## Makes `event`'s key the only keyboard key for `action`. A key already used by another rebindable
## action is taken away from it, so one key never triggers two actions.
static func bind_key(profile: Profile, action: StringName, event: InputEventKey) -> void:
	var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	var bindings: Dictionary = (value(profile, "bindings") as Dictionary).duplicate(true)
	for other: StringName in REBINDABLE:
		if other == action:
			continue
		var codes: Array = bindings.get(String(other), _current_codes(other))
		if codes.has(code):
			codes.erase(code)
			bindings[String(other)] = codes
	bindings[String(action)] = [code]
	profile.settings["bindings"] = bindings
	apply_bindings(profile)


static func reset_bindings(profile: Profile) -> void:
	profile.settings["bindings"] = {}
	InputMap.load_from_project_settings()


## The keyboard keys bound to an action, as readable names.
static func key_names(action: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	if not InputMap.has_action(action):
		return out
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := e as InputEventKey
			var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			out.append(OS.get_keycode_string(code))
	return out


## Multiplier for camera shake (0 when the player turned screen shake off).
static func shake_scale(profile: Profile) -> float:
	return 1.0 if bool(value(profile, "screen_shake")) else 0.0


static func reduced_flashing(profile: Profile) -> bool:
	return bool(value(profile, "reduced_flashing"))


static func _current_codes(action: StringName) -> Array:
	var out: Array = []
	if not InputMap.has_action(action):
		return out
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := e as InputEventKey
			out.append(int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode))
	return out
