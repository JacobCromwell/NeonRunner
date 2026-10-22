class_name TeleportFlash
extends CanvasLayer
## The teleport's flash (task Q4; GDD §5, Zone 9, proposed: the runner "arrives running in the output pad's lane, with a
## short flash and a sound (honouring Reduced flashing)"): the whole screen tinted the teleporter's green-white as the runner
## arrives (RunWorld.teleported), fading to nothing over TeleporterTuning.flash_seconds from flash_alpha, so the camera's
## cut (RunCamera) reads as a jump and the view past the landing is there to read at once. With Reduced flashing
## (Settings.flashing_reduced) it's no flash: a soft tint, reduced_flash_alpha at most, easing in over the first fifth of
## reduced_flash_seconds and out over the rest. One ColorRect, the default canvas shader: nothing to compile, the same on
## the Compatibility renderer. Under the HUD and the attack markers (LAYER), over the speed lines. Its clock is real
## time, so slow time never stretches it. LevelRun adds it (the review tools may too); nothing in gameplay reads it.

## Its canvas layer: over SpeedLines (3), under the attack markers (4) and the HUD (5).
const LAYER: int = 3
## The tint (sRGB): the teleporter's green, washed toward white.
const COLOR := Color(0.82, 1.0, 0.84)

var world: RunWorld
var tuning: TeleporterTuning
## Seconds since the last teleport (INF: none showing).
var since: float = INF
## How many teleports it has shown (tests and tools).
var shown: int = 0

var _rect: ColorRect


## Rebinds to `p_world` (a level restart builds a fresh RunWorld); builds the overlay once. A tint still showing from a
## jump just before the restart goes with the old run.
func setup(p_world: RunWorld, p_tuning: TeleporterTuning = null) -> void:
	if world != null and is_instance_valid(world) and world.teleported.is_connected(_on_teleported):
		world.teleported.disconnect(_on_teleported)
	world = p_world
	tuning = p_tuning if p_tuning != null else TeleporterTuning.load_default()
	since = INF
	if _rect == null:
		layer = LAYER
		_rect = ColorRect.new()
		_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rect)
	_rect.color = Color(COLOR, 0.0)
	_rect.visible = false
	world.teleported.connect(_on_teleported)


## The tint's alpha `t` seconds after a teleport: flash_alpha fading out linearly over flash_seconds; with Reduced
## flashing (`reduced`) reduced_flash_alpha at most, easing in over the first fifth of reduced_flash_seconds and out over
## the rest. 0 before and after. DESIGN-TBD (docs/questions/q4.md 10): the soft tint that stands in for the flash with
## Reduced flashing (and the flash itself, q4.md 1 and 4).
static func alpha_at(tt: TeleporterTuning, t: float, reduced: bool) -> float:
	if t < 0.0:
		return 0.0
	if not reduced:
		return tt.flash_alpha * clampf(1.0 - t / maxf(tt.flash_seconds, 0.001), 0.0, 1.0)
	var whole: float = maxf(tt.reduced_flash_seconds, 0.001)
	if t >= whole:
		return 0.0
	var rise: float = whole * 0.2
	var k: float = smoothstep(0.0, rise, t) if t < rise else 1.0 - smoothstep(rise, whole, t)
	return tt.reduced_flash_alpha * k


## The tint's alpha now.
func alpha() -> float:
	return _rect.color.a if _rect != null and _rect.visible else 0.0


func _on_teleported(_from: float, _to: float, _entry: Dictionary, _output: Dictionary) -> void:
	since = 0.0
	shown += 1
	_draw(0.0)


func _process(delta: float) -> void:
	if is_inf(since) or _rect == null:
		return
	# Real seconds: slow time scales `delta` (Engine.time_scale), not the flash.
	since += delta / maxf(Engine.time_scale, 0.001)
	_draw(since)


func _draw(t: float) -> void:
	var a: float = alpha_at(tuning, t, Settings.flashing_reduced)
	_rect.color = Color(COLOR, a)
	_rect.visible = a > 0.001
	if a <= 0.001 and t > 0.0:
		since = INF
