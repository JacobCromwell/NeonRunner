class_name HintDirector
extends Node
## First-encounter hints collected before play for LevelIntroScreen. The catalog's existing
## triggers select unseen hints from the generated layout, plus a boss's hints and actual pickups.
## No runtime events present hints. Only acknowledge() marks displayed entries seen.

signal hint_shown(id: String, text: String)

const PATH: String = "res://data/hints/hints.json"
const TOUCH_WORDS: Dictionary = {
	"move_left": "swipe left", "move_right": "swipe right", "jump": "swipe up",
	"slide": "swipe down", "dash": "tap",
}

var world: RunWorld
var profile: Profile
var touch: bool = false
## Ordered {id: String, text: String} entries for the intro; collecting never changes the profile.
var intro_hints: Array[Dictionary] = []
var context: RunContext


func setup(p_world: RunWorld, p_profile: Profile, p_touch: bool, p_context: RunContext = null) -> void:
	world = p_world
	profile = p_profile
	touch = p_touch
	context = p_context
	intro_hints.clear()
	if not bool(Settings.value(profile, "hints")):
		return
	var enemies: PackedStringArray = []
	for e: Dictionary in world.layout.enemies:
		var host: bool = bool((e.get("params", {}) as Dictionary).get("host", false))
		enemies.append("host" if host else String(e.get("type", "")))
		if host:
			enemies.append("bad_dream")
	var encounter: BossEncounter = BossEncounter.of(world)
	var boss_id: String = String(encounter.def.id) if encounter != null else ""
	for enemy: Enemy in world.director.active:
		enemies.append("host" if enemy.is_host else String(enemy.type_id))
	var pickups: PackedStringArray = []
	if encounter != null:
		pickups.append("armor")
		if encounter is TestBoss:
			var test_tuning: TestBossTuning = (encounter as TestBoss).tuning
			if test_tuning != null and test_tuning.bonus_pickup_phase > 0 \
					and not test_tuning.bonus_pickup.is_empty():
				pickups.append(test_tuning.bonus_pickup)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var new_hints: Array[Dictionary] = []
	var reminders: Array[Dictionary] = []
	for h: Dictionary in parsed.get("hints", []):
		var id: String = String(h.get("id", ""))
		if id == "" or profile.has_seen("hint/" + id):
			continue
		var trigger: String = String(h.get("trigger", ""))
		var include: bool = trigger == "start" and encounter == null \
			and (context == null or not context.is_campaign() or context.level_index == 0)
		if trigger.begins_with("enemy:"):
			var key: String = trigger.trim_prefix("enemy:")
			include = enemies.has(key) or key == boss_id
			if key == "boss" and boss_id != "":
				include = not _has_boss_hint(parsed.get("hints", []), boss_id)
		elif trigger.begins_with("boss:"):
			include = boss_id != "" and trigger.begins_with("boss:" + boss_id + "/")
		elif trigger == "pickup" or trigger.begins_with("pickup:"):
			include = not pickups.is_empty() if trigger == "pickup" \
				else pickups.has(trigger.trim_prefix("pickup:"))
		elif trigger != "start":
			include = _first_at(trigger) >= 0.0
		if include:
			var entry: Dictionary = {"id": id, "text": format_text(String(h.get("text", "")))}
			if _is_introduced(trigger, boss_id):
				new_hints.append(entry)
			else:
				reminders.append(entry)
	intro_hints.append_array(new_hints)
	intro_hints.append_array(reminders)


## Campaign recency is already derived from the actual ordered level configs. Older unseen
## encounters remain eligible (skipped pages or hints disabled), but new concepts come first.
func _is_introduced(trigger: String, boss_id: String) -> bool:
	if boss_id != "":
		return trigger == "enemy:" + boss_id or trigger == "enemy:boss" \
			or trigger.begins_with("boss:" + boss_id + "/")
	if world.config.feature_ages.is_empty():
		return true
	var feature: String = trigger.trim_prefix("enemy:")
	match trigger:
		"pad": feature = "ceilings"
		"ramp": feature = "ramps"
		"speed_pad": feature = "speed_pads"
		"fence_pulsing": feature = "pulsing"
		"wall_fence": feature = "wall_fences"
		"wall_gap": feature = "wall_gaps"
		"wall_fence_low", "wall_fence_high": feature = "wall_fences_partial"
		"enemy:bad_dream": feature = "host"
	if feature == "screech" and not world.config.feature_ages.has(feature):
		feature = "screech_vents"
	if world.config.feature_ages.has(feature):
		return world.config.feature_ages[feature] == 0
	return context != null and context.level_index == 0


func _has_boss_hint(catalog: Array, boss_id: String) -> bool:
	for hint: Dictionary in catalog:
		if String(hint.get("trigger", "")) == "enemy:" + boss_id:
			return true
	return false


## Called by the intro once its entries have been displayed, not when the world is prepared.
func acknowledge(entries: Array[Dictionary]) -> void:
	if not bool(Settings.value(profile, "hints")):
		return
	for entry: Dictionary in entries:
		var id: String = String(entry.get("id", ""))
		if not intro_hints.has(entry) or profile.has_seen("hint/" + id):
			continue
		profile.mark_seen("hint/" + id)
		hint_shown.emit(id, String(entry["text"]))


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
		"wall_fence", "wall_fence_low", "wall_fence_high":
			# Task B5: the first full-height wall fence, or the first low or high one.
			var band: String = "full" if trigger == "wall_fence" else trigger.trim_prefix("wall_fence_")
			for w: Dictionary in layout.wall_fences:
				if String(w["band"]) == band:
					found.append(float(w["at"]))
		"wall_gap":
			for wg: Dictionary in layout.wall_gaps:
				found.append(float(wg["start"]))
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
