class_name ResonatorTuning
extends EnemyTuning
## Numbers for the Resonator (GDD §9.10), edited in data/enemies/resonator.tres (F6: "Enemy:
## Resonator"). Pairs named _early and _late scale with the level's enemy_scaling across the Golden
## Zone (scaling_from to scaling_to; see zone_t). The helper functions turn them into times and track
## distances at a given run speed; the Resonator (resonator.gd) and its generator rules
## (resonator_rules.gd) both use them, so a pulse is planned with the numbers it's played with.
## Values marked DESIGN-TBD are placeholders, not design decisions (docs/questions/c3.md): GDD §9.10
## fixes only the sequence (warning with halos and chime, then a red wave along the floor across every
## lane, a few pulses, then it leaves), the dodges (jump, a wall, the ceiling) and that it pulses faster
## or sends double waves later in the zone.

@export_group("Zone scaling")
## DESIGN-TBD: the Resonator appears in the Golden Zone only (GDD §5), whose levels sit at the top of
## the campaign's enemy_scaling (Golden 1 at about 0.86, Golden 3 at 1). Its _early numbers apply from
## scaling_from and its _late ones at scaling_to, so "later in the zone it pulses faster or sends
## double waves" (GDD §9.10) spans the zone's own levels rather than the whole campaign.
@export_range(0.0, 1.0, 0.01) var scaling_from: float = 0.85
@export_range(0.0, 1.0, 0.01) var scaling_to: float = 1.0

@export_group("Hovering")
## DESIGN-TBD: how far ahead of the player it hovers while it pulses ("far ahead", GDD §9.10). Kept
## within the weapon's range (PowerupTuning.weapon_range) so auto-fire can target it.
@export_range(20.0, 65.0, 1.0, "suffix:m") var hover_ahead: float = 34.0
## DESIGN-TBD: the height of its red core above the floor: out of reach of a stomp, under the ceiling.
@export_range(2.0, 3.6, 0.05, "suffix:m") var hover_height: float = 3.1
## The model's size (1 = a spire 4.7 m tall, halos 3.3 m across). Its top stays under the ceiling
## (MovementTuning.ceiling_height) at hover_height; the tests check it.
@export_range(0.6, 1.3, 0.05) var model_scale: float = 1.1
## It hovers still where the generator put it until the player is this much further than hover_ahead
## away, then eases into pacing them over twice this distance of their run.
@export_range(2.0, 30.0, 0.5, "suffix:m") var approach_ease: float = 12.0
## Seconds it paces the player before its first pulse may start.
@export_range(0.0, 3.0, 0.05, "suffix:s") var settle_seconds: float = 0.6
## Its slow drift from side to side over the middle of the track (visual only).
@export_range(0.0, 2.0, 0.05, "suffix:m") var sway: float = 0.5
## After its last pulse it pulls away ahead this much faster than the player, and is gone once it's
## leave_distance ahead.
@export_range(2.0, 60.0, 1.0, "suffix:m/s") var leave_speed: float = 24.0
@export_range(60.0, 300.0, 5.0, "suffix:m") var leave_distance: float = 170.0

@export_group("Pulses")
## DESIGN-TBD: pulses per visit (GDD §9.10: "it leaves after a few pulses").
@export_range(1, 8) var pulses_early: int = 3
@export_range(1, 8) var pulses_late: int = 4
## DESIGN-TBD: the warning before each pulse: its halos spin up and line up, facing the player, while
## the chime plays (resonator_chime; its three notes come in the first 0.9 s, so keep this at least
## 1 s). The wave leaves at its end.
@export_range(1.0, 3.0, 0.05, "suffix:s") var warning_seconds: float = 1.3
## DESIGN-TBD: seconds from one pulse's last wave passing the player to the next pulse's warning
## (GDD §9.10: it pulses faster later in the zone).
@export_range(0.3, 6.0, 0.05, "suffix:s") var pulse_rest_early: float = 2.2
@export_range(0.3, 6.0, 0.05, "suffix:s") var pulse_rest_late: float = 1.2
## DESIGN-TBD: the share of pulses that send a double wave (GDD §9.10: later in the zone). The first
## pulse of a level's first visit is always a single wave (one new thing at a time), and a double goes
## only where its longer stretch is clear.
@export_range(0.0, 1.0, 0.05) var double_share_early: float = 0.0
@export_range(0.0, 1.0, 0.05) var double_share_late: float = 0.5
## DESIGN-TBD: seconds between a double pulse's two waves, both leaving and reaching the player: long
## enough to land and jump again, and inside the hit invulnerability window, so armor or a shield that
## blocks the first wave protects through the second.
@export_range(0.5, 2.0, 0.05, "suffix:s") var double_gap: float = 0.9
## DESIGN-TBD: a pulse that isn't ready when it's due (another enemy's big attack is on, GDD §9, or
## the floor where its wave would meet the player isn't clear) waits and moves the visit's other
## pulses on with it. After this long waiting for other attacks in all (waiting for clear floor
## doesn't count) it drops its remaining pulses and leaves, but never before its first: a visit always
## gets to pulse, unless the level ends first.
@export_range(0.0, 30.0, 0.5, "suffix:s") var turn_wait_max: float = 8.0

@export_group("Wave")
## DESIGN-TBD: the wave's speed along the floor toward the player (the player closes in at this plus
## their own speed).
@export_range(4.0, 30.0, 0.5, "suffix:m/s") var wave_speed_early: float = 11.0
@export_range(4.0, 30.0, 0.5, "suffix:m/s") var wave_speed_late: float = 14.0
## DESIGN-TBD: the height of the wave's hitbox, a low band along the floor: a jump's feet stay above
## it for about 0.55 s (MovementTuning's jump), and a player sliding is still hit. The visible wave
## stands a little taller (GDD §3: hitboxes smaller than visuals).
@export_range(0.2, 0.9, 0.01, "suffix:m") var wave_height: float = 0.45
## The hitbox's depth along the track.
@export_range(0.2, 1.5, 0.05, "suffix:m") var wave_depth: float = 0.5
## How far past the outer lanes' centres the hitbox reaches (it covers every lane: a runner in an
## outer lane is hit however they stand in it). Its ends stay clear of a wall runner's body at the
## bottom of their run (GDD §9.10: the waves travel along the floor only); see band_half_width().
@export_range(0.0, 0.4, 0.01, "suffix:m") var wave_outer_reach: float = 0.12
## Once past the player it rolls on this far behind them, fading, and is gone.
@export_range(2.0, 40.0, 1.0, "suffix:m") var wave_roll_on: float = 12.0

@export_group("Generator")
## The floor kept clear in every lane where a wave meets the runner, from this long before it to this
## long after it at run speed (a double's from before its first wave to after its second): no gap,
## fence, floor enemy, pad or ceiling landing, so a jump always has solid floor to leave from and land
## on (GDD §9.10, proposed: never a wave on top of a gap or a fence). DESIGN-TBD.
@export_range(0.2, 2.0, 0.05, "suffix:s") var clear_before_seconds: float = 0.6
@export_range(0.2, 2.0, 0.05, "suffix:s") var clear_after_seconds: float = 0.6
## How far past its earliest point the generator looks for a clear meeting stretch for a pulse (it
## hovers and waits meanwhile). A pulse that finds none is left out.
@export_range(0.0, 600.0, 5.0, "suffix:m") var pulse_slack: float = 240.0
## DESIGN-TBD: a Resonator that can't fit this many pulses is left out.
@export_range(1, 8) var min_pulses: int = 2
## Seconds between one visit's end (its last pulse, plus turn_wait_max for waits) and the next
## Resonator's first pulse: one at a time.
@export_range(0.0, 60.0, 1.0, "suffix:s") var visit_gap_seconds: float = 6.0
## In a level that guarantees its features (LevelConfig.guarantee_features) and ends up without a
## Resonator, the rules add one where its pulses fit.
@export var guarantee_one: bool = true


## Where the level's enemy_scaling `t` falls between scaling_from (0) and scaling_to (1).
func zone_t(t: float) -> float:
	if scaling_to <= scaling_from:
		return 1.0 if t >= scaling_to else 0.0
	return clampf((t - scaling_from) / (scaling_to - scaling_from), 0.0, 1.0)


func pulses_at(t: float) -> int:
	return maxi(1, roundi(scaled(float(pulses_early), float(pulses_late), zone_t(t))))


func pulse_rest_at(t: float) -> float:
	return scaled(pulse_rest_early, pulse_rest_late, zone_t(t))


func double_share_at(t: float) -> float:
	return scaled(double_share_early, double_share_late, zone_t(t))


func wave_speed_at(t: float) -> float:
	return scaled(wave_speed_early, wave_speed_late, zone_t(t))


## Seconds a wave takes from leaving (under the Resonator, hover_ahead ahead) to reaching a player
## running at `speed`.
func travel_seconds(speed: float, t: float) -> float:
	return hover_ahead / maxf(speed + wave_speed_at(t), 1.0)


## Metres the player runs from a pulse's warning start to where its (first) wave meets them.
func meet_offset(speed: float, t: float) -> float:
	return (warning_seconds + travel_seconds(speed, t)) * speed


## Seconds from a pulse's warning start until its last wave has passed a player running at `speed`
## (its back edge `margin` behind their hitbox, whose depth is `body_depth`).
func pulse_seconds(double: bool, speed: float, t: float, body_depth: float = 0.38, margin: float = 0.5) -> float:
	var pass_time: float = (wave_depth + body_depth + margin) / maxf(speed + wave_speed_at(t), 1.0)
	return warning_seconds + travel_seconds(speed, t) + (double_gap if double else 0.0) + pass_time


## The stretch of track the player runs through while a pulse whose warning starts at `warn_at`
## (a player distance) meets them: from clear_before_seconds before its first wave meets them to
## clear_after_seconds after its last. It must be clear floor (Resonator.pulse_clear).
func meeting_stretch(warn_at: float, double: bool, speed: float, t: float) -> Vector2:
	var meet: float = warn_at + meet_offset(speed, t)
	var last: float = meet + (double_gap * speed if double else 0.0)
	return Vector2(meet - clear_before_seconds * speed, last + clear_after_seconds * speed)


## Half the width of the wave's hitbox for `lanes` lanes: to wave_outer_reach past the outer lanes'
## centres (so it covers a runner anywhere in any lane), and never so far that it reaches a wall
## runner's body at the bottom of their run (wall_body_reach; `clearance` short of it).
func band_half_width(lanes: int, movement: MovementTuning, clearance: float = 0.1) -> float:
	var outer: float = (float(lanes) - 1.0) * 0.5 * movement.lane_width
	return minf(outer + wave_outer_reach, wall_body_reach(lanes, movement) - clearance)


## How far from the track's middle a wall runner's body reaches in toward the lanes: it lies across
## the wall's foot, sticking out MovementTuning.hurtbox_size.y from the wall face (Player.hurtbox_aabb).
static func wall_body_reach(lanes: int, movement: MovementTuning) -> float:
	return lanes * movement.lane_width * 0.5 + movement.wall_margin - movement.hurtbox_size.y
