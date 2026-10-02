class_name GildedSentinelTuning
extends EnemyTuning
## Numbers for the Gilded Sentinels (GDD §9.11), edited in data/enemies/gilded_sentinel.tres (F6: "Enemy:
## Gilded Sentinel"). The Sentinel (gilded_sentinel.gd), its generator rules (gilded_sentinel_rules.gd)
## and the Golden Zone's skins (which open its niche in their walls) all read them, so a swing is
## planned with the numbers it's played with.
## Sizes are physical metres (the statue, its niche, the band and lane its halberd cuts): they don't
## change with a zone's pace. Times are seconds, so every warning keeps its length at every speed (GDD
## §3, owner's playtest September 30, 2026: enemies speed up to match, never with shorter warnings); the
## generator turns them into metres at the level's run speed.
## Values marked DESIGN-TBD are placeholders, not design decisions (docs/questions/c4.md): GDD §9.11
## fixes the look (a golden statue with a halberd in a niche at wall-run height, glowing red eyes), the
## warning (its eyes flare and stone grinds), the swing (across its wall section and the outer floor
## lane), the dodges (above or below on the wall by timing the wall entry; out of the outer lane on the
## floor), that later ones swing twice or come in pairs, 17 laser tier 1 shots (health 15 here: G4's
## tier 1 rule adds two), armor blocking the halberd and, proposed, a stomp from a wall jump and a solid
## body.

@export_group("Statue and niche")
## DESIGN-TBD: the live statue's size against the kit's (GoldenStatue: 2.6 m from its feet to its
## crest at 1), small enough that its niche fits the wall-run band and its swing comes from its
## shoulders at about the band's height.
@export_range(0.5, 1.2, 0.01) var statue_scale: float = 0.85
## DESIGN-TBD: the niche's opening (the statue stands on its floor, its sill): its width along the
## track, the height of its sill above the floor and from the sill to the top of its arch. Within the
## wall-run band (GDD §9.11: a live one stands in a niche at wall-run height).
@export_range(0.8, 2.5, 0.05, "suffix:m") var niche_width: float = 1.4
@export_range(0.0, 2.0, 0.05, "suffix:m") var niche_sill: float = 0.75
@export_range(1.5, 4.0, 0.05, "suffix:m") var niche_height: float = 2.7
## How deep the niche goes into the wall: deep enough for the whole statue, so nothing of it reaches
## out over the wall-run path (a wall runner's body lies along the wall face).
@export_range(0.5, 1.5, 0.05, "suffix:m") var niche_depth: float = 0.8
## How far the front of the statue stands behind the wall face (a little, so its glowing eyes and gold
## catch the light from far down the street, where the wall is seen almost edge-on).
@export_range(0.0, 0.3, 0.01, "suffix:m") var statue_inset: float = 0.05
## DESIGN-TBD: how far it turns from the street toward the approaching runner (radians; the
## decorative statues on the ledges turn the same way, GoldenFacades.STATUE_TURN).
@export_range(0.0, 0.8, 0.01) var statue_turn: float = 0.3

@export_group("Swing")
## DESIGN-TBD: the band of wall-run heights its halberd cuts on its wall, centred band_offset above
## the free wall-entry height (MovementTuning.wall_entry_height), like the window cyborg's (GDD §3: wall
## entry timing decides whether you pass above or below): stepping onto the wall right before it puts
## the runner in the band; a jump onto the wall (or a ramp) passes above, an early entry below.
@export_range(-1.0, 1.0, 0.05, "suffix:m") var band_offset: float = 0.0
@export_range(0.4, 1.6, 0.05, "suffix:m") var band_height: float = 0.9
## How far the cut on its wall reaches out from the face toward the lanes: over a wall runner's whole
## body (it lies along the wall, a hurtbox height out), never into the middle of the outer lane.
@export_range(1.1, 1.3, 0.01, "suffix:m") var wall_reach: float = 1.2
## The cut over the outer floor lane stops this far short of its inner edge (the lane beside it is
## safe; hitboxes are smaller than the visuals, GDD §3). It runs from wall_reach out from the face
## (never touching a wall runner) and from the floor up to the band's top (above any jump).
@export_range(0.0, 0.5, 0.01, "suffix:m") var lane_margin: float = 0.15
## DESIGN-TBD: the stretch of its wall section and the outer lane one swing cuts, along the track
## (centred on its niche). A Sentinel that swings twice cuts the stretch before its niche, then
## swings back across the stretch past it, twice as long in all.
@export_range(2.0, 10.0, 0.5, "suffix:m") var section_length: float = 5.0
## DESIGN-TBD: the warning: its eyes flare, stone grinds (gilded_sentinel_grind), the red marks of the
## band and the lane light up and it draws its halberd back. Its first swing comes at its end, as the
## runner reaches the stretch.
@export_range(0.8, 3.0, 0.05, "suffix:s") var warning_seconds: float = 1.2
## A swing starts as the runner is this long short of its stretch (at their speed then), so they are
## inside it while it cuts.
@export_range(0.0, 0.3, 0.01, "suffix:s") var strike_lead_seconds: float = 0.06
## How long a swing's cut is on (its halberd sweeping, the cut's red flash). A runner crossing a whole
## stretch at the Golden Zone's speed takes about 0.2 s.
@export_range(0.1, 0.8, 0.01, "suffix:s") var strike_seconds: float = 0.3
## A runner slower than at the warning's start (a dash ending) reaches the stretch later: it holds its
## halberd raised, eyes blazing, up to this long past the warning, then swings anyway. A faster one may
## reach it first: the warning always runs its whole length (GDD §3), so they may get past unhurt.
@export_range(0.0, 3.0, 0.05, "suffix:s") var hold_max_seconds: float = 0.8
## Seconds from its last swing back to rest.
@export_range(0.2, 3.0, 0.05, "suffix:s") var recover_seconds: float = 0.8

@export_group("Stomp")
## DESIGN-TBD (GDD §9.11, proposed: a stomp from a wall jump): a wall jump from right by its head kicks
## it (DamageRules' stomp: it's defeated, the runner bounces). The runner's height on its wall (where
## their feet meet the wall) must lie from kick_below under its helmet's base to kick_above over its
## crest, and their hitbox, along the track, within kick_along of the statue's (one frame's run either
## way is added, as a stomp on the floor sweeps the frame's motion).
@export_range(0.0, 1.0, 0.05, "suffix:m") var kick_below: float = 0.25
@export_range(0.0, 1.5, 0.05, "suffix:m") var kick_above: float = 0.55
@export_range(0.0, 1.5, 0.05, "suffix:m") var kick_along: float = 0.45

@export_group("Generator")
## The wall-run approach kept clear on its wall: no sign, window cyborg, wall vent's screech or other
## Sentinel from this long (at run speed) before its stretch (a runner entering early to pass below
## needs the wall from there) to wall_clear_seconds past it (GDD §9.11 with §9.1: never with a sign or a
## wall fence on the same wall section; the wall fences keep off it themselves, WallFencePlacement).
@export_range(0.5, 4.0, 0.05, "suffix:s") var approach_seconds: float = 2.2
@export_range(0.0, 2.0, 0.05, "suffix:s") var wall_clear_seconds: float = 0.6
## The lane beside the outer one (the escape from the cut) holds no hole, fence, floor cut, anti-grav
## pad or floor enemy from this long before a swing starts to the end of its stretch (never when the
## outer lane is the only safe lane).
@export_range(0.2, 2.0, 0.05, "suffix:s") var escape_lead_seconds: float = 0.7
## Seconds between two Sentinels' attacks (from one's last swing to the next one's warning), on either
## wall, unless they are a pair (the same spot on both walls, swinging together).
@export_range(0.0, 10.0, 0.25, "suffix:s") var gap_seconds: float = 1.5


## The band of wall-run heights its halberd cuts on its wall (Vector2(bottom, top)), for `movement`.
func band(movement: MovementTuning) -> Vector2:
	var center: float = movement.wall_entry_height + band_offset
	return Vector2(center - band_height * 0.5, center + band_height * 0.5)


## The statue's height from its feet to the top of its crest.
func statue_height() -> float:
	return GoldenStatue.STATURE * statue_scale


## The stretch of track (Vector2(from, to), track distances) swing `index` of a Sentinel at `at` cuts:
## its whole section for a single swing; for two, the half before its niche, then the half past it.
func swing_stretch(at: float, swings: int, index: int) -> Vector2:
	if swings <= 1:
		return Vector2(at - section_length * 0.5, at + section_length * 0.5)
	return Vector2(at - section_length, at) if index == 0 else Vector2(at, at + section_length)


## Everything its swings cut, from the first one's start to the last one's end.
func guarded_stretch(at: float, swings: int) -> Vector2:
	return Vector2(swing_stretch(at, swings, 0).x, swing_stretch(at, swings, maxi(swings, 1) - 1).y)


## Where the runner is (a track distance) when its warning starts, for a runner at `speed`.
func warn_at(at: float, swings: int, speed: float) -> float:
	return guarded_stretch(at, swings).x - (warning_seconds + strike_lead_seconds) * speed


## The whole attack along the track (Vector2(from, to)) at `speed`: from where the runner is when its
## warning starts to the end of its last stretch. A big attack's keep-out (the generator's rules).
func attack_window(at: float, swings: int, speed: float) -> Vector2:
	return Vector2(warn_at(at, swings, speed), guarded_stretch(at, swings).y)


## The floor its cut uses (params.floor_span; LevelGenerator.enemy_floor_span): the outer lane, from
## escape_lead_seconds before its first swing starts to the end of its last stretch.
func floor_use(at: float, swings: int, speed: float) -> Vector2:
	var s: Vector2 = guarded_stretch(at, swings)
	return Vector2(s.x - (strike_lead_seconds + escape_lead_seconds) * speed, s.y)
