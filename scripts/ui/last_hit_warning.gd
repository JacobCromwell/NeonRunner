class_name LastHitWarning
extends CanvasLayer
## "One hit from death" (GDD §4, owner, October 14, 2026): the moment the player has run out of all armor and
## shields, the screen's edges pulse red with a two-tone siren, then hold a dim red edge for as long as they
## are unprotected, so they know that the next hit ends the run. The HUD owns it (RunHud.last_hit); its numbers
## are LastHitWarningTuning's (data/ui/last_hit_warning.tres, F6: "One hit from death").
##
## - **When.** The cue is on while the player is alive, has no armor hit left and no shield, and the run is being
##   played: the level or the boss fight is running (not won, not given up), and it isn't a mini-game level (the
##   Beach's volleyball match, where the runner can't die). It starts on the frame the protection runs out and
##   ends the frame it comes back (the free armor's return, a pickup, a revive) or the player dies. It is read
##   from the player's state every frame, not from a signal, so every way of losing or regaining protection
##   (a break, a pickup, a revive, a test or review tool setting `armor`) is the same to it. A level or a fight
##   that begins unprotected gives the cue once at the start (`LastHitWarningTuning.warn_at_start`, DESIGN-TBD,
##   items 832–835). Nothing runs while the game is paused (this node pauses with the run). Its clock is
##   real time: slow time slows `delta`, not the siren, so the pulses are divided back to real seconds.
## - **Sound.** `last_hit_siren` (tools/asset_gen/sfx_bank_power.gd), once on entering the state, through the
##   run's own PlayerSfx on the SFX bus: not a loop, so it never masks the warning of an attack, and it ducks
##   nothing. `onset_delay` after the break, so the armor's own break sound is heard first. It is cut off if the
##   cue ends first. It is mixed under every attack warning in the library on the general loudness weighting
##   (test_last_hit_warning); on a phone speaker, which has little below 450 Hz, it is closer to some of them
##   (item 833).
## - **Look.** Four ColorRects (the two sides and the stretches of top and bottom between them, so nothing is
##   drawn twice and the middle of the screen costs nothing) on one canvas_item shader, like SpeedLines: a soft
##   red band along the edges, `edge_width` of the screen's height (its shorter side) deep, on a CanvasLayer of its own **under**
##   every other overlay (LAYER, below SpeedLines' 3 and the attack markers' 4: the Enforcer Truck's lane marker,
##   the Magnate's chevron and blink, the slow-time tint, the HUD), so it never covers a marker or a number. It
##   does tint the scenery along the edges, and the floor right below the runner. Its strength pulses once with
##   each high tone of the siren (`pulse_count` times, no faster than 3 a second) and settles at `steady_alpha`.
##   It works on the Compatibility renderer: nothing here is a post-process.
## - **Compiled with the level.** The shader is one Shader for the whole session (`shared_shader()`), and the
##   edge is drawn at no strength for ShaderWarmup.DRAWN_FRAMES frames as the run loads (`warm_up()`), so the
##   first armor break doesn't compile it in the middle of play (task PERF1's rule).
## - **Reduced flashing** (Settings): no pulses. The edge fades in to `reduced_alpha` and holds steady.
## Red is the hazard colour, so it is kept for the HUD (the world never glows it for anything but a hazard).

## The cue began (the protection ran out).
signal started
## The cue ended (the protection came back, the player died or the run ended).
signal ended

## The siren's name in the sound library.
const SIREN: StringName = &"last_hit_siren"
## The cue's canvas layer: under SpeedLines (3), the attack markers (4: the Enforcer Truck's, the Magnate's), the
## slow-time tint (4) and the HUD (5), above the 3D world.
const LAYER: int = 2
## Below this strength the edge isn't drawn at all.
const MIN_LEVEL: float = 0.002
## Share of a pulse (0–1) it takes to swell to its peak; the rest of it is the fade back to the steady edge.
const PULSE_ATTACK: float = 0.12

const SHADER: String = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.27, 0.3, 1.0);
uniform float edge_width : hint_range(0.01, 0.5) = 0.12;
// The screen's size in units of its shorter side (a landscape screen: its aspect and 1).
uniform vec2 unit = vec2(1.7778, 1.0);
// Where this strip sits on the screen (0–1 each way), so every strip shades by the screen's own edges.
uniform vec2 origin = vec2(0.0);
uniform vec2 extent = vec2(1.0);

void fragment() {
	vec2 p = origin + UV * extent;
	// Distance to the nearest side and to the nearest top or bottom edge, in shorter sides of the screen.
	float dx = min(p.x, 1.0 - p.x) * unit.x;
	float dy = min(p.y, 1.0 - p.y) * unit.y;
	float sx = 1.0 - smoothstep(0.0, edge_width, dx);
	float sy = 1.0 - smoothstep(0.0, edge_width, dy);
	// The union of the four bands, brightest in the corners, falling off softly toward the middle.
	float band = sx + sy - sx * sy;
	COLOR = vec4(color.rgb, color.a * intensity * band * band);
}
"""

## The shader every cue of the session shares (made on first use), so it is compiled once.
static var _shader: Shader
## The shader has been drawn in this session (ShaderWarmup.DRAWN_FRAMES frames): a later run needn't warm it again.
static var warmed: bool = false

var tuning: LastHitWarningTuning = LastHitWarningTuning.load_default()
var world: RunWorld

var _holder: Control
var _strips: Array[ColorRect] = []
var _materials: Array[ShaderMaterial] = []
## The size and band width the strips were last laid out for.
var _laid_size: Vector2 = Vector2.ZERO
var _laid_width: float = -1.0
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
## Frames still to be drawn at no strength to compile the shader (see warm_up).
var _warm_frames_left: int = 0


## The one Shader all cues share.
static func shared_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


## The four strips, in pixels, for a screen of `size` and a band `edge_width` of its shorter side (its height, held
## sideways) deep: the two sides, full height, and the top and bottom between them. Nothing overlaps, and the middle
## of the screen is empty.
static func strip_rects(size: Vector2, edge_width: float) -> Array[Rect2]:
	var depth: float = minf(maxf(edge_width, 0.0) * minf(size.x, size.y), minf(size.x, size.y) * 0.5)
	var rects: Array[Rect2] = [
		Rect2(0.0, 0.0, depth, size.y),
		Rect2(size.x - depth, 0.0, depth, size.y),
		Rect2(depth, 0.0, maxf(size.x - 2.0 * depth, 0.0), minf(depth, size.y * 0.5)),
		Rect2(depth, maxf(size.y - depth, size.y * 0.5), maxf(size.x - 2.0 * depth, 0.0), minf(depth, size.y * 0.5)),
	]
	return rects


func _ready() -> void:
	name = "LastHitWarning"
	layer = LAYER
	_holder = Control.new()
	_holder.name = "Edge"
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.visible = false
	add_child(_holder)
	for i: int in 4:
		var strip := ColorRect.new()
		strip.name = "Strip%d" % i
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = shared_shader()
		material.set_shader_parameter(&"color", UiTheme.style().danger)
		material.set_shader_parameter(&"intensity", 0.0)
		strip.material = material
		_holder.add_child(strip)
		_strips.append(strip)
		_materials.append(material)


## Binds to a run's world (a restart builds a fresh one) and starts over. `live` answers whether the run is still
## being played; `context` says whether it is a mini-game level. A game that renders compiles the shader now,
## while the run loads (warm_up).
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
	if ShaderWarmup.needed():
		warm_up()
	_apply()


## Draws the edge at no strength for ShaderWarmup.DRAWN_FRAMES frames, so the renderer compiles the shader now
## (the first compiles, the second catches what it defers by one), not in the frame of the first armor break. Once a
## session: the shader is shared. Frames are counted as they are drawn, so it works while the run's intro holds the
## game still.
func warm_up() -> void:
	if warmed or _warm_frames_left > 0:
		return
	_warm_frames_left = ShaderWarmup.DRAWN_FRAMES
	if not RenderingServer.frame_post_draw.is_connected(note_frame_drawn):
		RenderingServer.frame_post_draw.connect(note_frame_drawn)
	_apply()


## A frame was drawn (the renderer's frame_post_draw; tests call it).
func note_frame_drawn() -> void:
	if _warm_frames_left <= 0:
		return
	_warm_frames_left -= 1
	if _warm_frames_left == 0:
		warmed = true
		if RenderingServer.frame_post_draw.is_connected(note_frame_drawn):
			RenderingServer.frame_post_draw.disconnect(note_frame_drawn)
		_apply()


## The shader is being drawn at no strength to compile it.
func is_warming() -> bool:
	return _warm_frames_left > 0


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


## The strips are being drawn (the cue shows, or the shader is warming up).
func is_drawn() -> bool:
	return _holder != null and _holder.visible


## Whether the cue should be on now: the player is alive and unprotected in a run that is being played.
func wants_cue() -> bool:
	if world == null or not is_instance_valid(world) or world.player == null or _blocked:
		return false
	if not world.player.alive or is_protected():
		return false
	if _live.is_valid() and not bool(_live.call()):
		return false
	return _seen_protected or tuning.warn_at_start


## Moves the cue on by `delta` real seconds (the HUD's frames, slow time taken out; tests step it by hand).
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


## The frame's `delta` is game time, which slow time (Engine.time_scale) slows, and the siren is a recording that
## it doesn't: the cue runs on real time, as MusicDirector and the slow-time tint do.
func _process(delta: float) -> void:
	advance(delta / maxf(Engine.time_scale, 0.01))


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
	if _holder == null:
		return
	var shown: bool = _level > MIN_LEVEL or _warm_frames_left > 0
	_holder.visible = shown
	if not shown:
		return
	var strength: float = _level if _level > MIN_LEVEL else 0.0
	var size_now: Vector2 = _holder.size
	if size_now != _laid_size or not is_equal_approx(tuning.edge_width, _laid_width):
		_lay_out(size_now)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"intensity", strength)


## Places the four strips for the screen's size and the band's width (and tells each its place on the screen).
func _lay_out(size_now: Vector2) -> void:
	_laid_size = size_now
	_laid_width = tuning.edge_width
	var rects: Array[Rect2] = strip_rects(size_now, tuning.edge_width)
	var screen: Vector2 = Vector2(maxf(size_now.x, 1.0), maxf(size_now.y, 1.0))
	for i: int in 4:
		_strips[i].position = rects[i].position
		_strips[i].size = rects[i].size
		var material: ShaderMaterial = _materials[i]
		material.set_shader_parameter(&"origin", rects[i].position / screen)
		material.set_shader_parameter(&"extent", rects[i].size / screen)
		material.set_shader_parameter(&"edge_width", tuning.edge_width)
		material.set_shader_parameter(&"unit", screen / minf(screen.x, screen.y))
