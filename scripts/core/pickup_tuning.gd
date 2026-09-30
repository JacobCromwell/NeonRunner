class_name PickupTuning
extends Resource
## Numbers for in-run pickups (GDD §10: a boss fight's armor, shield and grapple pickups; PickupField).
## Edit data/tuning/pickups.tres (also live in the F6 tuning panel). Placement numbers are fairness
## rules: where a pickup may appear so the player can see it coming and take it safely.

@export_group("Where a pickup appears")
## DESIGN-TBD (docs/questions/b7.md): the GDD says when pickups come, not where; this group is the
## placeholder. How far ahead of the player a pickup appears: far enough to see it coming and change
## lanes, near enough to be in plain view. The first fair spot at or after this distance is taken.
@export_range(15.0, 120.0, 1.0, "suffix:m") var lead_distance: float = 42.0
## How much further along the track to look for a fair spot. With none in reach, the pickup waits
## (and keeps looking as the player runs on) until there is one.
@export_range(0.0, 80.0, 1.0, "suffix:m") var search_window: float = 30.0
## Spacing of the spots tried along the track.
@export_range(0.5, 10.0, 0.5, "suffix:m") var search_step: float = 1.0
## DESIGN-TBD (docs/questions/b7.md): the most lanes a pickup may be from the player's lane (a wall
## runner counts as the outer lane on that side). Nearer lanes come first: the player's own, then its
## neighbours.
@export_range(0, 5) var reach_lanes: int = 2
## The pickup's lane has floor and nothing in the way for this far before it: no gap, fence, pad,
## ramp or speed pad, no ceiling overhead and no enemy, so the player can be in that lane, on the
## floor, well before reaching it (a player dropping off a ceiling has landed by then).
@export_range(2.0, 40.0, 0.5, "suffix:m") var clear_before: float = 12.0
## ...and for this far after it, so taking it never leads straight into a gap's edge or a fence.
@export_range(1.0, 30.0, 0.5, "suffix:m") var clear_after: float = 6.0
## Enemies placed on the track (not yet in play) keep pickups out of their own lane and lanes this
## close to it, over the stretch of floor they use.
@export_range(0, 3) var enemy_lane_margin: int = 1
## Height above the floor that must be free of hazards (fences, enemies, blocks, attacks in the air)
## around the spot: everything a running, jumping or sliding player passes through to take it.
@export_range(1.0, 6.0, 0.1, "suffix:m") var clear_height: float = 3.0

@export_group("Taking it")
## DESIGN-TBD (docs/questions/b7.md): the most charges of one breakable item (shield, grapple) the
## player can hold. A pickup of an item the player already holds this many of is taken without adding
## a charge (1 = like the loadout, which brings one charge of each, and a boss's granted items). The
## armor has its own rule (GameRules.armor_pickup_extra_hits).
@export_range(1, 5) var max_charges: int = 1
## The space around the pickup that takes it when the player's hitbox reaches it: width across the
## lane (less than a lane, so the next lane never takes it), height from the floor and depth along
## the track. Running, jumping over it low or sliding under it in its lane all take it.
@export_range(0.4, 2.4, 0.05, "suffix:m") var take_width: float = 1.3
@export_range(0.5, 4.0, 0.05, "suffix:m") var take_height: float = 2.4
@export_range(0.2, 3.0, 0.05, "suffix:m") var take_depth: float = 1.0
## A pickup the player has run this far past is missed and gone (GDD: a missed pickup is gone).
@export_range(0.5, 10.0, 0.25, "suffix:m") var miss_distance: float = 1.5

@export_group("Look")
## The badge: its radius and the height of its centre above the floor. It is much bigger than the
## biggest credit, so the two never read alike.
@export_range(0.2, 1.2, 0.01, "suffix:m") var badge_radius: float = 0.66
@export_range(0.5, 2.5, 0.05, "suffix:m") var float_height: float = 1.25
## A gentle bob and sway (it never spins like a credit). Speeds in cycles per second.
@export_range(0.0, 0.5, 0.01, "suffix:m") var bob_height: float = 0.08
@export_range(0.0, 3.0, 0.05, "suffix:Hz") var bob_speed: float = 0.7
@export_range(0.0, 45.0, 1.0, "suffix:°") var sway_degrees: float = 18.0
## How long it takes to grow in when it appears, and to shrink away when it is taken or missed.
@export_range(0.05, 1.5, 0.05, "suffix:s") var appear_seconds: float = 0.35
@export_range(0.05, 1.5, 0.05, "suffix:s") var vanish_seconds: float = 0.2
## Brightness of the icon and the ring (above 1 blooms), and of the soft halo and floor glow.
@export_range(0.5, 8.0, 0.1) var icon_energy: float = 2.4
@export_range(0.5, 8.0, 0.1) var ring_energy: float = 2.6
@export_range(0.0, 3.0, 0.05) var halo_energy: float = 1.1
