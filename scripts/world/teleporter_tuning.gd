class_name TeleporterTuning
extends Resource
## Teleporters (task Q4; GDD §5, Zone 9, the owner, October 21, 2026: "a square pad with a look all its own, with a green,
## slightly space-age antenna on it. Touching it teleports the runner to an output pad further down the track"; "some
## teleporters have a left and a right output pad. A light on the antenna, on its left or its right side, shows which one
## the runner lands on"; "some antennas' light stays on one side ... others blink left and right, and the side lit when the
## runner touches the pad decides where they land"): where the generator may stand one (scripts/enemies/teleporter_rules.gd),
## how its antenna shows its light (Teleporter, scripts/world/teleporter.gd) and how the jump looks (TeleportFlash, and
## the camera's sweep after the runner, RunCamera). How
## many a level asks for is its own LevelConfig.teleporters (and blinking_teleporters). Edit data/tuning/teleporters.tres
## (F6: "Teleporters", in a level that has them; Restart level rebuilds where they stand). Times are seconds of run at the
## level's run speed, or at the fastest a runner comes onto a pad where they say so (the run speed plus
## PowerupTuning.dash_speed_bonus and the most a speed pad's or a ramp's boost adds: TeleporterRules.fastest), so a faster
## zone keeps every one of them (GDD §3, Pace). Every number here is a first value for playtesting (DESIGN-TBD,
## docs/questions/q4.md).

const PATH: String = "res://data/tuning/teleporters.tres"

@export_group("The pads")
## A pad's side as a share of a lane's width (GDD §5, proposed: "the pad fills one floor lane"): the input pad and its
## output pads are squares this wide and as long along the track. Its trigger is the square: a runner on the floor whose
## feet touch it is teleported (Player: "taken by running onto it").
@export_range(0.5, 1.0, 0.01) var pad_share: float = 0.84

@export_group("Where it leads")
## Seconds of run at the run speed from a pad's front to its output pads' fronts, the shortest and the longest
## (GDD §5, proposed: "the output pads stand within sight ahead ... so the player can see where each one leads"): the
## generator picks one of hop_choices between them where the level has room. The longest keeps the output pads within
## the track built ahead (TrackBuilder.BUILD_AHEAD, 180 m) and well short of the fog's end in the Ice Lab's hall from the
## start of the pad's approach.
@export_range(1.0, 5.0, 0.1, "suffix:s") var hop_seconds_min: float = 2.0
@export_range(1.0, 5.0, 0.1, "suffix:s") var hop_seconds_max: float = 2.6
@export_range(1, 5, 1) var hop_choices: int = 3
## The share of the fixed-antenna teleporters past a level's introduction that have two output pads, a left and a right
## (GDD §5: "some teleporters have a left and a right output pad"); the rest have one. A blinking antenna's always has
## two (its light chooses between them), the introduction's one.
@export_range(0.0, 1.0, 0.05) var two_output_share: float = 0.6
## Lanes from a two-output teleporter's left output pad to its right one at the least (as far apart as the track has
## lanes for), so the two read as a left and a right.
@export_range(1, 6, 1) var output_lane_gap: int = 2

@export_group("The antenna")
## Seconds each side of a blinking antenna stays lit before the light changes side (GDD §5, proposed: "a blinking light
## changes side slowly enough to read, about once a second"). It runs on the level clock from each teleporter's own
## phase, so every attempt at a seed blinks the same.
@export_range(0.4, 3.0, 0.05, "suffix:s") var blink_seconds: float = 1.0
## Seconds over which a light fades over to the other side, centred on the change (the side lit at a touch is always
## the one brighter then); with Reduced flashing, the slower fade.
@export_range(0.0, 0.5, 0.01, "suffix:s") var blink_fade_seconds: float = 0.06
@export_range(0.0, 0.8, 0.01, "suffix:s") var reduced_blink_fade_seconds: float = 0.3

@export_group("Fairness")
## Seconds of run, at the fastest a runner comes onto a pad, before its front that its lane and the lane beside it on
## its `side` (the way around it) hold nothing: a runner who finds themselves in its lane (a doodad's push, a ceiling's
## end) has time to see it and switch out, and no attack is timed onto them as they line it up (LevelLayout
## .teleporter_between). Both lanes hold nothing for a lane switch's room past its far end too
## (LevelGenerator.doodad_lane_room), so a runner who switches out at the last moment lands on whole floor.
@export_range(0.3, 2.0, 0.05, "suffix:s") var approach_seconds: float = 0.8
## Seconds of run, at the fastest a runner arrives, past each output pad's front that its lane holds nothing (no hole,
## fence, pad, doodad or floor enemy) and no attack lands in any lane: never a landing straight into a hazard, a gap or
## an enemy in front leaves at least the usual time to react (GDD §5, proposed). Past it, what the level holds is there,
## so a later output pad may sit right in front of a gap or an enemy (GDD §5: "the player has to react quickly").
@export_range(0.5, 3.0, 0.05, "suffix:s") var landing_seconds: float = 1.0
## The level's first teleporter (where it gives the feature a start: its introduction) is safe (GDD §5: "the first
## teleporter is safe, to teach the mechanic"): one output pad, straight ahead in its own lane, its lane holding nothing
## for this long past its front and no enemy using the floor in any lane meanwhile, nor any attack landing there.
@export_range(1.0, 6.0, 0.1, "suffix:s") var intro_landing_seconds: float = 2.5
## Later teleporters prefer output pads with a hole, a fence or a floor enemy in their lane within this many seconds
## past the landing's clear stretch (GDD §5: "later output pads may sit right in front of a gap or an enemy"); 0 leaves
## it to chance.
@export_range(0.0, 4.0, 0.1, "suffix:s") var prefer_hazard_seconds: float = 1.5

@export_group("The jump")
## The flash as the runner arrives (GDD §5, proposed: "with a short flash and a sound"): the screen tinted the
## teleporter's green-white, from this alpha down to none over this many seconds. With Reduced flashing, a softer tint
## that eases in and out instead of flashing.
@export_range(0.0, 1.0, 0.01) var flash_alpha: float = 0.55
@export_range(0.05, 1.0, 0.01, "suffix:s") var flash_seconds: float = 0.28
@export_range(0.0, 0.6, 0.01) var reduced_flash_alpha: float = 0.18
@export_range(0.1, 1.5, 0.01, "suffix:s") var reduced_flash_seconds: float = 0.45

@export_group("The camera's sweep")
## The camera's sweep across the jump (the owner, October 24, 2026: "when the player touches the teleporter, the camera
## should zoom in to where the teleporter's output is. Even though the player character teleports instantly, the camera
## catches up, showing the user what happened through its movement"): the runner is moved at once, but the camera stays
## where it was (the input pad's view, the output pad and the runner on it far ahead) and rushes after them, easing out, so
## the jump reads. Camera only: the runner's position, speed, hitbox and control are the teleport's, whatever this says. Real
## seconds (slow time doesn't stretch it), from the touch to the camera back on its usual framing; the share of the way
## still to go follows `(1 - t / sweep_seconds) ^ sweep_ease_power`, so most of the way is covered in the first half. 0 is
## the old clean cut. DESIGN-TBD (docs/questions/u2-teleport-camera.md 1 and 2): kept short, since the runner has the
## landing's reaction time (landing_seconds) from the arrival, and the view ahead of the landing is in frame throughout.
@export_range(0.0, 1.0, 0.01, "suffix:s") var sweep_seconds: float = 0.35
## How sharply the sweep eases out: 1 is a steady rush that stops dead, higher covers most of the way at once and settles
## slowly.
@export_range(1.0, 5.0, 0.1) var sweep_ease_power: float = 2.0
## Degrees the field of view widens at the touch and eases back from over the sweep (the zoom's punch; negative narrows it).
## No punch with Reduced flashing, nor with Screen shake off (no kick in the view). DESIGN-TBD (u2-teleport-camera.md 3).
@export_range(-15.0, 20.0, 0.5, "suffix:°") var sweep_fov_punch: float = 6.0
## The flash's share of flash_alpha while the camera sweeps (sweep_seconds above 0): the sweep itself shows the jump, and
## the full flash would wash it out. Reduced flashing's tint is its own. DESIGN-TBD (u2-teleport-camera.md 4).
@export_range(0.0, 1.0, 0.05) var sweep_flash_share: float = 0.5

@export_group("Placement")
## Seconds of run between two teleporters' pads at the least (and nothing of one within another's stretch).
@export_range(4.0, 60.0, 0.5, "suffix:s") var spacing_seconds: float = 12.0
## A level that gives the feature a start (LevelConfig.feature_starts: Relay Station) introduces it at the best fair spot
## within this many seconds of run from there, so the player meets it right after its first-encounter hint (within the
## reach every introduction keeps from its start: test_campaign's INTRODUCTION_REACH, 210 m at 18 m/s, about 11.7 s). The
## blinking antennas' start (Specimen Vault's) introduces the first blinking one the same way.
@export_range(2.0, 40.0, 0.5, "suffix:s") var intro_window_seconds: float = 11.5
## Plain holes and fences (never a pulsing fence, one a fence generator powers, or a wall-run gap's hole) that stand
## where a teleporter needs clear floor may be taken out to make room for it (taking content out never makes a level
## unfair); a spot that needs nothing taken out is preferred. Off: teleporters stand only where the floor is clear.
@export var clear_plain_pieces: bool = true
## The grid pads' fronts are tried on (metres): finer finds a spot nearer the one aimed for, coarser is cheaper.
@export_range(0.5, 4.0, 0.25, "suffix:m") var search_step: float = 1.0


## The shared tuning (data/tuning/teleporters.tres), or the defaults if it's missing.
static func load_default() -> TeleporterTuning:
	var res: Resource = load(PATH) if ResourceLoader.exists(PATH) else null
	return res as TeleporterTuning if res is TeleporterTuning else TeleporterTuning.new()


## The hops the generator tries (seconds of run from a pad's front to its output pads'), shortest first: hop_choices of
## them from hop_seconds_min to hop_seconds_max.
func hops() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var lo: float = minf(hop_seconds_min, hop_seconds_max)
	var hi: float = maxf(hop_seconds_min, hop_seconds_max)
	var n: int = maxi(hop_choices, 1)
	for k: int in n:
		out.append(lo if n == 1 else lerpf(lo, hi, float(k) / float(n - 1)))
	return out
