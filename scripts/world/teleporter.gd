class_name Teleporter
extends Node3D
## One teleporter on the track (task Q4; GDD §5, Zone 9, the owner, October 21, 2026: "a square pad with a look all its
## own, with a green, slightly space-age antenna on it. Touching it teleports the runner to an output pad further down the
## track"; "a light on the antenna, on its left or its right side, shows which one the runner lands on"; "others blink left
## and right, and the side lit when the runner touches the pad decides where they land"): its layout entry
## (LevelLayout.teleporters), its input pad's trigger (`pad`: an Area3D on TrackBuilder.LAYER_TRIGGER over the square, of
## kind &"teleporter", carrying its entry as META; a runner on the floor whose feet touch it is teleported: Player._teleport),
## the looks the skin dresses (its pad and antenna on `pad`, ZoneSkin.teleporter_pad and teleporter_antenna; each output
## pad, `outputs`, in the pad's look without the antenna), and its antenna's lamps, which tick() lights on the level clock:
## the side lit_side() says, fading over to the other side over TeleporterTuning.blink_fade_seconds centred on each change
## (the slower reduced_blink_fade_seconds with Reduced flashing), so the brighter lamp is always the side a touch would
## take. Nothing about it is a hazard: no hitbox, no collision but its trigger. TrackBuilder builds it in the chunk where
## its pad stands and keeps that chunk until its output pads are behind the runner (TrackBuilder._build_teleporter).

## The trigger's height over the floor (metres; the feet's sensor reaches 0.3 m up: Player.SENSOR_SIZE).
const TRIGGER_HEIGHT: float = 0.5
## The trigger's meta key that holds the teleporter's layout entry (Player._check_triggers).
const META: StringName = &"teleporter"
## The trigger's kind (its "kind" meta, as every trigger's: Player._check_triggers).
const KIND: StringName = &"teleporter"

## Its layout entry (LevelLayout.teleporters).
var entry: Dictionary = {}
## Its pads' box: a square pad's side across and along, TRIGGER_HEIGHT up (the skin dresses each pad in it, its floor
## at -size.y / 2 and its front, toward the oncoming runner, at +size.z / 2).
var size := Vector3.ONE
## The input pad's trigger, which the skin dresses with the pad and its antenna.
var pad: Area3D
## Each output pad's node, centred on its box (the left first), which the skin dresses.
var outputs: Array[Node3D] = []
## The lit looks of its antenna's lamps the skin made (ZoneSkin.teleporter_antenna): -1 the left, 1 the right, 0 the
## beacon a one-output teleporter keeps lit; tick() shows and scales them.
var lamps: Dictionary = {}
var tuning: TeleporterTuning
## The level time tick() last drew (tests and tools).
var drawn_at: float = -1.0


## Builds it for layout entry `p_entry` (TrackGeometry `geo`, MovementTuning `t`): its trigger and its output pads' nodes,
## undressed (the skin dresses them: TrackBuilder).
func setup(p_entry: Dictionary, geo: TrackGeometry, t: MovementTuning, tt: TeleporterTuning = null) -> void:
	entry = p_entry
	tuning = tt if tt != null else TeleporterTuning.load_default()
	name = "Teleporter%d" % int(entry.get("id", 0))
	var side: float = float(entry["end"]) - float(entry["at"])
	size = Vector3(side, TRIGGER_HEIGHT, side)
	pad = Area3D.new()
	pad.name = "Pad"
	pad.collision_layer = TrackBuilder.LAYER_TRIGGER
	pad.collision_mask = 0
	pad.monitoring = false
	pad.position = box_center(geo, int(entry["lane"]), float(entry["at"]))
	pad.set_meta(&"kind", KIND)
	pad.set_meta(META, entry)
	add_child(pad)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	pad.add_child(shape)
	for o: Dictionary in entry.get("outputs", []):
		var node := Node3D.new()
		node.name = "Output%d" % outputs.size()
		node.position = box_center(geo, int(o["lane"]), float(o["at"]))
		add_child(node)
		outputs.append(node)


## Where a pad of a teleporter in `lane` with its front at track distance `front` is centred (world space): its box's
## middle, TRIGGER_HEIGHT / 2 up.
func box_center(geo: TrackGeometry, lane: int, front: float) -> Vector3:
	return Vector3(geo.lane_x(lane), TRIGGER_HEIGHT * 0.5, TrackGeometry.world_z(front + size.z * 0.5))


## The lit looks of its lamps (ZoneSkin.teleporter_antenna), drawn at once for the level time drawn last.
func set_lamps(lit: Dictionary) -> void:
	lamps = lit
	tick(maxf(drawn_at, 0.0))


## Draws its antenna's light for level time `level_time` (TrackBuilder.update, every physics frame): each side lamp
## scaled by lamp_level() (hidden when it's out), the beacon of a one-output teleporter steady.
func tick(level_time: float) -> void:
	drawn_at = level_time
	var fade: float = tuning.reduced_blink_fade_seconds if Settings.flashing_reduced else tuning.blink_fade_seconds
	for side: int in [-1, 1]:
		var lamp: Variant = lamps.get(side)
		if lamp == null or not is_instance_valid(lamp):
			continue
		var k: float = lamp_level(entry, side, level_time, fade)
		(lamp as Node3D).visible = k > 0.01
		(lamp as Node3D).scale = Vector3.ONE * maxf(k, 0.01)
	var beacon: Variant = lamps.get(0)
	if beacon != null and is_instance_valid(beacon):
		(beacon as Node3D).visible = (entry.get("outputs", []) as Array).size() < 2


## The side of teleporter `tp`'s antenna lit at level time `level_time` (-1 left, 1 right; 0 with one output pad: no
## choice): a fixed light's `light`; a blinking one's, which changes side every `blink` seconds from `light` at its
## `phase` (0–1 of a whole cycle of both sides) at the run's start. What decides where a touch at that moment lands
## (output_at), the same on every attempt.
static func lit_side(tp: Dictionary, level_time: float) -> int:
	if (tp.get("outputs", []) as Array).size() < 2:
		return 0
	var light: int = -1 if int(tp.get("light", -1)) < 0 else 1
	var blink: float = float(tp.get("blink", 0.0))
	if blink <= 0.0:
		return light
	var half: int = floori(level_time / blink + float(tp.get("phase", 0.0)) * 2.0)
	return light if posmod(half, 2) == 0 else -light


## How brightly teleporter `tp`'s lamp on `side` shows at level time `level_time` (0–1): a fixed light's lamp on or off;
## a blinking one's fades over to the other side over `fade` seconds centred on each change (both at one half at the
## change itself), so the brighter lamp is always the side lit_side() gives. A one-output teleporter lights neither.
static func lamp_level(tp: Dictionary, side: int, level_time: float, fade: float) -> float:
	var lit: int = lit_side(tp, level_time)
	if lit == 0:
		return 0.0
	var blink: float = float(tp.get("blink", 0.0))
	if blink <= 0.0 or fade <= 0.0:
		return 1.0 if side == lit else 0.0
	var u: float = level_time / blink + float(tp.get("phase", 0.0)) * 2.0
	var f: float = u - floorf(u)
	# Distance to the nearer change, in shares of a side's time, against half the fade's.
	var edge: float = minf(f, 1.0 - f)
	var s: float = smoothstep(0.0, clampf(fade / blink, 0.0001, 1.0) * 0.5, edge)
	return 0.5 + 0.5 * s if side == lit else 0.5 - 0.5 * s


## The output pad ({lane, at, end}) a runner who touches teleporter `tp`'s pad at level time `level_time` lands on: its
## only one, or the left one with the left side lit and the right one with the right side lit (lit_side). {} without any.
static func output_at(tp: Dictionary, level_time: float) -> Dictionary:
	var outs: Array = tp.get("outputs", [])
	if outs.is_empty():
		return {}
	if outs.size() == 1:
		return outs[0]
	return outs[0] if lit_side(tp, level_time) < 0 else outs[outs.size() - 1]


## A sample of every part of a teleporter's look as `skin` dresses them, under `parent` (ShaderWarmup: drawn once while
## the level loads, so the renderer compiles them before the first one comes): an input pad with its antenna and both
## lamps and the beacon lit, and an output pad. Nothing physical: no trigger. Returns its root (freed with `parent`).
static func warm_look(parent: Node3D, skin: ZoneSkin, geo: TrackGeometry, t: MovementTuning) -> Node3D:
	var root := Node3D.new()
	root.name = "TeleporterSample"
	parent.add_child(root)
	var tt: TeleporterTuning = TeleporterTuning.load_default()
	var side: float = geo.lane_width * tt.pad_share
	var box := Vector3(side, TRIGGER_HEIGHT, side)
	var input := Node3D.new()
	root.add_child(input)
	skin.teleporter_pad(input, box, 0)
	var lit: Dictionary = skin.teleporter_antenna(input, box, 0)
	for k: Variant in lit:
		if lit[k] is Node3D:
			(lit[k] as Node3D).visible = true
	var output := Node3D.new()
	output.position = Vector3(geo.lane_width, 0.0, 0.0)
	root.add_child(output)
	skin.teleporter_pad(output, box, 1)
	return root
