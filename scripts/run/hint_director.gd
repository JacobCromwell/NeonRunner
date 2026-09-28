class_name HintDirector
extends Node
## First-encounter hints (DESIGN-TBD: the tutorial approach is open, OPEN_QUESTIONS §5). Each hint in
## data/hints/hints.json shows once per profile, a moment before the player first meets its trigger:
## "start" (level start), a piece ("gap", "fence_full", "fence_gapped", "fence_pulsing", "sign",
## "pad", "ramp", "speed_pad"), an enemy ("enemy:<type>", when one spawns; "enemy:boss" for any
## boss without a hint of its own) or a pickup ("pickup:<item>", when one appears ahead; "pickup" for
## any item without a hint of its own). "{action}" in the text becomes the player's key on PC or the
## gesture on touch screens.

signal hint_shown(id: String, text: String)

const PATH: String = "res://data/hints/hints.json"
## How long before reaching a piece its hint appears.
const LEAD_SECONDS: float = 1.6
const TOUCH_WORDS: Dictionary = {
	"move_left": "swipe left", "move_right": "swipe right", "jump": "swipe up",
	"slide": "swipe down", "dash": "tap",
}

var world: RunWorld
var profile: Profile
var touch: bool = false
## Hints waiting on a piece: {id, text, at}.
var _pending: Array[Dictionary] = []
var _enemy_hints: Dictionary = {}
## Item ("" for the one every item shares) -> its hint.
var _pickup_hints: Dictionary = {}
var _start_hints: Array[Dictionary] = []


func setup(p_world: RunWorld, p_profile: Profile, p_touch: bool) -> void:
	world = p_world
	profile = p_profile
	touch = p_touch
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for h: Dictionary in parsed.get("hints", []):
		var id: String = String(h.get("id", ""))
		if id == "" or profile.has_seen("hint/" + id):
			continue
		var trigger: String = String(h.get("trigger", ""))
		var entry := {"id": id, "text": format_text(String(h.get("text", "")))}
		if trigger == "start":
			_start_hints.append(entry)
		elif trigger.begins_with("enemy:"):
			_enemy_hints[trigger.get_slice(":", 1)] = entry
		elif trigger == "pickup" or trigger.begins_with("pickup:"):
			_pickup_hints[trigger.get_slice(":", 1) if trigger.contains(":") else ""] = entry
		else:
			var at: float = _first_at(trigger)
			if at >= 0.0:
				entry["at"] = at
				_pending.append(entry)
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	world.director.enemy_spawned.connect(_on_enemy_spawned)
	if world.pickups != null:
		world.pickups.spawned.connect(_on_pickup_spawned)
	# Enemies already in play (a boss's body, there from the fight's start) get their hint first thing.
	for e: Enemy in world.director.active:
		var entry: Dictionary = _take_enemy_hint(e)
		if not entry.is_empty():
			_start_hints.append(entry)


## Replaces {action} with the player's key or touch gesture.
func format_text(text: String) -> String:
	var out: String = text
	for action: String in ["move_left", "move_right", "jump", "slide", "dash", "slow_time", "pause"]:
		var token: String = "{%s}" % action
		if not out.contains(token):
			continue
		var word: String = String(TOUCH_WORDS.get(action, action)) if touch \
			else " / ".join(Settings.key_names(StringName(action)))
		out = out.replace(token, word)
	return out


func _process(_delta: float) -> void:
	if world == null or world.player == null or not world.player.running:
		return
	if not _start_hints.is_empty():
		_show(_start_hints.pop_front())
		return
	if _pending.is_empty():
		return
	var lead: float = world.player.speed * LEAD_SECONDS
	if world.player.distance >= float(_pending[0]["at"]) - lead:
		_show(_pending.pop_front())


func _on_enemy_spawned(enemy: Enemy) -> void:
	var entry: Dictionary = _take_enemy_hint(enemy)
	if not entry.is_empty():
		_show(entry)


## A pickup appeared ahead: the hint for its item (or the one every item shares), the first time.
func _on_pickup_spawned(pickup: Pickup) -> void:
	var key: String = String(pickup.item) if _pickup_hints.has(String(pickup.item)) else ""
	var entry: Dictionary = _pickup_hints.get(key, {})
	_pickup_hints.erase(key)
	if not entry.is_empty():
		_show(entry)


## The hint waiting for this kind of enemy, taken off the list ({} if none): a boss's own hint
## ("enemy:<boss id>") if it has one, else the one every boss shares ("enemy:boss").
func _take_enemy_hint(enemy: Enemy) -> Dictionary:
	var key: String = "host" if enemy.is_host else String(enemy.type_id)
	if enemy.is_boss and not _enemy_hints.has(key):
		key = "boss"
	var entry: Dictionary = _enemy_hints.get(key, {})
	_enemy_hints.erase(key)
	return entry


func _show(entry: Dictionary) -> void:
	profile.mark_seen("hint/" + String(entry["id"]))
	hint_shown.emit(entry["id"], entry["text"])


## Track distance of the first piece of a kind, or -1 if the level has none.
func _first_at(trigger: String) -> float:
	var layout: LevelLayout = world.layout
	var found: Array[float] = []
	match trigger:
		"gap":
			for g: Dictionary in layout.gaps:
				found.append(float(g["start"]))
		"fence_full", "fence_gapped", "fence_pulsing":
			for f: Dictionary in layout.fences:
				var pulsing: bool = f["pulsing"]
				if (trigger == "fence_pulsing" and pulsing) \
						or (trigger == "fence_full" and f["variant"] == "full" and not pulsing) \
						or (trigger == "fence_gapped" and f["variant"] == "gapped"):
					found.append(float(f["at"]))
		"sign":
			for sg: Dictionary in layout.signs:
				found.append(float(sg["start"]))
		"pad":
			for pd: Dictionary in layout.pads:
				found.append(float(pd["at"]))
		"ramp":
			for r: Dictionary in layout.ramps:
				found.append(float(r["at"]))
		"speed_pad":
			for sp: Dictionary in layout.speed_pads:
				found.append(float(sp["at"]))
	if found.is_empty():
		return -1.0
	return found.min()
