class_name LastHitWarning
extends Control
## "One hit from death" (GDD §4, owner, October 14, 2026): the moment the player has run out of all armor and
## shields, the screen's edges pulse red with a two-tone siren, then hold a dim red edge for as long as they
## are unprotected, so they know that the next hit ends the run. The HUD owns it (RunHud, under the rest of the
## HUD); its numbers are LastHitWarningTuning's (data/ui/last_hit_warning.tres, F6: "One hit from death").
##
## - **When.** The cue is on while the player is alive, has no armor hit left and no shield, and the run is being
##   played: the level or the boss fight is running (not won, not given up), and it isn't a mini-game level (the
##   Beach's volleyball match, where the runner can't die). It starts on the frame the protection runs out and
##   ends the frame it comes back (the free armor's return, a pickup, a revive) or the player dies. It is read
##   from the player's state every frame, not from a signal, so every way of losing or regaining protection
##   (a break, a pickup, a revive, a test or review tool setting `armor`) is the same to it. A level or a fight
##   that begins unprotected gives the cue once at the start (`LastHitWarningTuning.warn_at_start`, DESIGN-TBD,
##   docs/questions/i6.md). Nothing runs while the game is paused (this node pauses with the run).
## - **Sound.** `last_hit_siren` (tools/asset_gen/sfx_bank_power.gd), once on entering the state, through the
##   run's own PlayerSfx on the SFX bus: not a loop, so it never masks the warning of an attack, and it ducks
##   nothing. `onset_delay` after the break, so the armor's own break sound is heard first. It is cut off if the
##   cue ends first.
## - **Look.** One full-screen ColorRect on a canvas_item shader (like SpeedLines): a soft red band along the four
##   edges, `edge_width` of the screen's height deep, drawn under the HUD and never over the lanes. Its strength
##   pulses once with each high tone of the siren (`pulse_count` times, no faster than 3 a second) and settles
##   at `steady_alpha`. It works on the Compatibility renderer: nothing here is a post-process.
## - **Reduced flashing** (Settings): no pulses. The edge fades in to `reduced_alpha` and holds steady.
## Red is the hazard colour, so it is kept for the HUD (the world never glows it for anything but a hazard).

## The cue began (the protection ran out).
signal started
## The cue ended (the protection came back, the player died or the run ended).
signal ended

## The siren's name in the sound library.
const SIREN: StringName = &"last_hit_siren"
## Below this strength the edge isn't drawn at all.
const MIN_LEVEL: float = 0.002
## Share of a pulse (0–1) it takes to swell to its peak; the rest of it is the fade back to the steady edge.
const PULSE_ATTACK: float = 0.12

const SHADER: String = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.27, 0.3, 1.0);
uniform float edge_width : hint_range(0.01, 0.5) = 0.12;
uniform float aspect = 1.7778;

void fragment() {
	// Distance to the nearest side and to the nearest top or bottom edge, in screen heights.
	float dx = min(UV.x, 1.0 - UV.x) * aspect;
	float dy = min(UV.y, 1.0 - UV.y);
	float sx = 1.0 - smoothstep(0.0, edge_width, dx);
	float sy = 1.0 - smoothstep(0.0, edge_width, dy);
	// The union of the four bands, brightest in the corners, falling off softly toward the middle.
	float band = sx + sy - sx * sy;
	COLOR = vec4(color.rgb, color.a * intensity * band * band);
}
"""

var tuning: LastHitWarningTuning = LastHitWarningTuning.load_default()
var world: RunWorld

var _rect: ColorRect
var _material: ShaderMaterial
## Answers whether the run is still being played (LevelRun.State.RUNNING); empty: always.
var _live: Callable
## A mini-game level: the cue never shows.
var _blocked: bool = false
## The cue is on.
var _on: bool = false
## Seconds since the cue began (it goes on counting while the edge fades out).
var _age: float = 0.0
var _siren_played: bool = false
## 0 to 1: how much of the edge is shown, easing in and out.
var _fade: float = 0.0
## The edge's strength at the screen's edge now (0–1).
var _level: float = 0.0
## The player has been protected since the run began (for `warn_at_start` off).
var _seen_protected: bool = false


func _ready() -> void:
	name = "LastHitWarning"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect = ColorRect.new()
	_rect.name = "Edge"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = Shader.new()
	_material.shader.code = SHADER
	_material.set_shader_parameter(&"color", UiTheme.style().danger)
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)


## Binds to a run's world (a restart builds a fresh one) and starts over. `live` answers whether the run is still
## being played; `context` says whether it is a mini-game level.
func setup(p_world: RunWorld, p_context: RunContext, live: Callable = Callable()) -> void:
	world = p_world
	_live = live
	_blocked = p_context != null and p_context.config != null and p_context.config.plays_minigame()
	_on = false
	_age = 0.0
	_siren_played = false
	_fade = 0.0
	_level = 0.0
	_seen_protected = false
	_apply()


## The player has an armor hit left or a shield in hand.
func is_protected() -> bool:
	var p: Player = world.player if world != null and is_instance_valid(world) else null
	return p == null or p.armor_state.is_up() or p.shield > 0


## The cue is on: it began and hasn't ended.
func is_on() -> bool:
	return _on


## The red at the screen's edge now, 0 (none) to 1 (solid).
func level() -> float:
	return _level


## Whether the cue should be on now: the player is alive and unprotected in a run that is being played.
func wants_cue() -> bool:
	if world == null or not is_instance_valid(world) or world.player == null or _blocked:
		return false
	if not world.player.alive or is_protected():
		return false
	if _live.is_valid() and not bool(_live.call()):
		return false
	return _seen_protected or tuning.warn_at_start


## Moves the cue on by `delta` seconds (the HUD's frames; tests step it by hand).
func advance(delta: float) -> void:
	if world == null or not is_instance_valid(world) or world.player == null:
		return
	if is_protected():
		_seen_protected = true
	var want: bool = wants_cue()
	if want and not _on:
		_on = true
		_age = 0.0
		_siren_played = false
		started.emit()
	elif _on and not want:
		_on = false
		_cut_siren()
		ended.emit()
	if _on or _fade > 0.0:
		_age += delta
	if _on and not _siren_played and _age >= tuning.onset_delay:
		_siren_played = true
		if world.sounds != null:
			world.sounds.play(SIREN)
	var seconds: float = tuning.fade_in_seconds if _on else tuning.fade_out_seconds
	_fade = move_toward(_fade, 1.0 if _on else 0.0, delta / maxf(seconds, 0.01))
	_level = _fade * (_steady() + _pulse())
	_apply()


func _process(delta: float) -> void:
	advance(delta)


## The steady edge's strength: dim, a little stronger with no pulses to carry the cue (Reduced flashing).
func _steady() -> float:
	return tuning.reduced_alpha if Settings.flashing_reduced else tuning.steady_alpha


## What the current pulse adds over the steady edge: one swell for each high tone of the siren, none with
## Reduced flashing.
func _pulse() -> float:
	if Settings.flashing_reduced:
		return 0.0
	var t: float = _age - tuning.onset_delay
	if t < 0.0 or t >= float(tuning.pulse_count) * tuning.pulse_seconds:
		return 0.0
	var u: float = fmod(t, tuning.pulse_seconds) / tuning.pulse_seconds
	var swell: float = smoothstep(0.0, PULSE_ATTACK, u) * (1.0 - smoothstep(PULSE_ATTACK, 1.0, u))
	return swell * maxf(tuning.pulse_alpha - tuning.steady_alpha, 0.0)


## The cue ended while the siren was still playing: cut it off.
func _cut_siren() -> void:
	if _siren_played and world != null and is_instance_valid(world) and world.sounds != null \
			and _age < tuning.onset_delay + tuning.siren_seconds():
		world.sounds.stop(SIREN)


func _apply() -> void:
	if _rect == null:
		return
	_rect.visible = _level > MIN_LEVEL
	if not _rect.visible:
		return
	_material.set_shader_parameter(&"intensity", _level)
	_material.set_shader_parameter(&"edge_width", tuning.edge_width)
	_material.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))
