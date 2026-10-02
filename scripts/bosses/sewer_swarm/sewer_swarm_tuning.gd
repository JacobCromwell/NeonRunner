class_name SewerSwarmTuning
extends Resource
## The Sewer Swarm's numbers (GDD §10; data/bosses/gangland_boss_tuning.tres, F6 in its fight). Times are in
## seconds and never change with the run speed. Distances that stand for a time (marked "at 18 m/s": where a
## surge meets the runner, how far it charges, the baits' spacing, the fairness margins) are written for the
## reference run speed (MovementTuning.REFERENCE_SPEED) and multiplied by the run's pace (MovementTuning.pace(),
## SewerSwarm.run_pace()), so the fight keeps its seconds at Gangland's 21.8 m/s as at quick play's 18 m/s.
## Sizes, the crowds and the scenery (the lairs) stay as they are.
##
## Crowd sizes are the look only (GDD §10, owner, October 2, 2026: "build it now and we'll scale it down
## later"; the phone test, task E3, sets them): the fight plays the same at any crowd size, and a low-end
## device (DeviceProfile.is_low_end()) draws the _low_end ones. Every number here is a placeholder
## (DESIGN-TBD, docs/questions/e4.md) unless its comment gives the GDD's.

@export_group("Crowds")
## DESIGN-TBD (E3 sets it): screeches drawn in each cluster (GDD §10: "each rendered as many screech-variant
## creatures using MultiMesh plus a shader"). Only the look: a cluster's hitbox, health and timing don't change.
@export_range(10, 600, 10) var cluster_creatures: int = 140
@export_range(10, 600, 10) var cluster_creatures_low_end: int = 60
## DESIGN-TBD (E3): the roadside horde, both gutters together (GDD §10: "it builds up on both sides of the
## street"). Scenery: it never touches the lanes.
@export_range(0, 1200, 20) var horde_creatures: int = 400
@export_range(0, 1200, 20) var horde_creatures_low_end: int = 160
## DESIGN-TBD (E3): phase 2's wall climb (task E4b: GDD §10, "the swarm also climbs the walls, ... one wall at
## a time"), here so every crowd size lives in one place and the stress scene can draw it.
@export_range(0, 800, 20) var climb_creatures: int = 200
@export_range(0, 800, 20) var climb_creatures_low_end: int = 80
## DESIGN-TBD (E3): screeches pouring out of each manhole or vent as it bursts open (the Rising).
@export_range(0, 40, 1) var spill_creatures: int = 10
@export_range(0, 40, 1) var spill_creatures_low_end: int = 4
## DESIGN-TBD: a swarm screech's size against a sewer screech's (1): smaller, so hundreds fit the street.
@export_range(0.3, 1.2, 0.01) var creature_scale: float = 0.7

@export_group("Clusters")
## GDD §10: 4-5 clusters. Phase 1 ends when two are destroyed, phase 2 when the rest are (the BossDef's
## phases' hits add up to this; test_sewer_swarm checks it).
@export_range(1, 8) var cluster_count: int = 5
## DESIGN-TBD: a cluster's health in laser tier 1 shots (GDD §10: "weapons thin clusters too, and the heavy
## missile gets bonus damage against them"; GDD §8: the heavy missile's swarm bonus). Weapons hurt a cluster
## only while it surges (from its warning until it has passed the runner), so a fence or a hole stays the
## quick way: the heavy missile (3 a shot, twice against a swarm) destroys one over about two of its surges,
## laser tier 1 over about seven. A cluster thinned to nothing is destroyed, like a baited one.
@export_range(1.0, 400.0, 1.0) var cluster_health: float = 36.0
## The clusters wait at the roadside ahead of the runner, keeping pace, alternating sides: the next to surge
## nearest (where its surge starts), the others this far apart behind it.
@export_range(5.0, 60.0, 0.5, "suffix:m") var station_spacing: float = 17.0
## A cluster that surged and missed scatters behind the runner and re-forms at the back of the line over
## this long (rising out of the gutter).
@export_range(0.5, 10.0, 0.1, "suffix:s") var reform_seconds: float = 3.0
## Its mound at the roadside: this long, piled this far out from the wall's foot (never into the outer
## lane's runner), clinging this high up the wall.
@export_range(1.0, 10.0, 0.1, "suffix:m") var mound_length: float = 5.5
@export_range(0.3, 1.2, 0.05, "suffix:m") var mound_depth: float = 1.0
@export_range(0.2, 4.0, 0.1, "suffix:m") var mound_climb: float = 2.6
## The surging mass: this long, this share of a lane wide, piled this high.
@export_range(1.0, 10.0, 0.1, "suffix:m") var mass_length: float = 6.5
@export_range(0.3, 1.0, 0.01) var mass_width_share: float = 0.9
@export_range(0.3, 2.0, 0.05, "suffix:m") var mass_height: float = 1.15
## Its damage hitbox (GDD §3: slightly smaller than the look, so it errs in the runner's favour): this
## share of a lane wide, this high, this share of the mass long, starting this far behind its front.
@export_range(0.2, 0.9, 0.01) var hit_width_share: float = 0.55
@export_range(0.2, 2.0, 0.05, "suffix:m") var hit_height: float = 0.9
@export_range(0.2, 1.0, 0.01) var hit_length_share: float = 0.75
@export_range(0.0, 1.5, 0.05, "suffix:m") var hit_front_inset: float = 0.35

@export_group("Surges")
## GDD §10's warning for a surge, "a red lane line and a rising chitter": from the moment it starts until
## the cluster would meet the runner. The cluster rears up at the roadside where it will pour in, its
## chitter rises (swarm_chitter), and a red line runs down the runner's lane from there, following the
## runner from lane to lane, ending at a fence or a hole on it.
@export_range(1.0, 5.0, 0.05, "suffix:s") var warning_seconds: float = 2.4
## DESIGN-TBD (docs/questions/e4.md, the bait): this long before it would meet the runner, the cluster lands
## in the lane the runner is in (a wall runner's outer lane) and charges down it: the line locks there (the
## standard red lane warning) and won't follow any more. A runner who was in a lane with a fence or a hole
## on the line then gets out of its way (or jumps it), and the cluster, charging at them, runs into it.
@export_range(0.5, 3.0, 0.05, "suffix:s") var lock_seconds: float = 1.1
## It pours out of the roadside into the lane over this long before the lock (toward the line's lane).
@export_range(0.1, 1.5, 0.05, "suffix:s") var pour_seconds: float = 0.55
## How fast it charges down the lane toward the runner (at 18 m/s).
@export_range(4.0, 30.0, 0.5, "suffix:m/s") var charge_speed: float = 18.0
## Where an unbaited surge would meet the runner: this far before its bait spot (at 18 m/s). The cluster
## lands charge_speed × lock_seconds further on (past the bait), so a baited one reaches its fence or hole
## a moment before the runner does, in plain view.
@export_range(0.0, 20.0, 0.5, "suffix:m") var strike_before: float = 6.0
## A surge that missed is over once its front is this far behind the runner, out of view (at 18 m/s): it
## scatters into the gutters and re-forms at the back of the line.
@export_range(4.0, 40.0, 0.5, "suffix:m") var pass_after: float = 14.0
## How long a cluster shocked by a fence or falling into a hole takes to die away (the look).
@export_range(0.3, 3.0, 0.05, "suffix:s") var shock_seconds: float = 1.3
@export_range(0.3, 3.0, 0.05, "suffix:s") var fall_seconds: float = 1.6
## Score for each cluster baited into a fence or a hole (a skill bonus, like the Floating Head's tower).
@export_range(0, 5000, 50) var bait_score: int = 500

@export_group("Baits")
## DESIGN-TBD (docs/questions/e4.md, the arena): each lap of the arena carries bait spots, the first this far
## into the lap and then one every bait_spacing (both at 18 m/s): a live full-height fence or a hole in one
## lane (bait_kinds in turn), the street clear of every other hole and fence in every lane around it, from a
## jump before where its surge's warning finds the runner to clear_after past where the cluster lands. A
## surge comes at every spot the pattern reaches in time; between them the street is the generator's.
@export_range(60.0, 1000.0, 5.0, "suffix:m") var bait_first: float = 170.0
@export_range(80.0, 1000.0, 5.0, "suffix:m") var bait_spacing: float = 200.0
## The kinds, in turn: "fence" (a live full-height fence: GDD §10, "hits a live electric fence and is
## shocked") or "hole" (GDD §10: "baiting a cluster into a hole also works").
@export var bait_kinds: PackedStringArray = PackedStringArray(["fence", "hole"])
## A spot's lane is at most this many lanes from the one before (seeded, never the same one twice running).
@export_range(1, 5) var bait_max_shift: int = 2
## A bait hole's length (at 18 m/s): a jump clears it.
@export_range(2.0, 8.0, 0.25, "suffix:m") var hole_length: float = 4.5
## Clear street kept past where the cluster lands (at 18 m/s), for the runner who dodged.
@export_range(0.0, 40.0, 0.5, "suffix:m") var clear_after: float = 12.0

@export_group("Rising")
## The Rising (GDD §10, phase 1: "manholes and wall vents shake all along both sides, and screeches pour out
## and merge into clusters at the roadside"): a lair (a manhole at the street's edge or a vent at the wall's
## foot, alternating) every lair_spacing metres along both sides (scenery spacing, not a time). The roadside
## horde fills up over horde_fill_seconds from the fight's start.
@export_range(4.0, 40.0, 0.5, "suffix:m") var lair_spacing: float = 9.0
## A lair rattles from rattle_ahead metres ahead of the runner and bursts open at burst_ahead, its screeches
## pouring out into the gutter. At the fight's start every lair in sight bursts (over its first seconds);
## later on, this share of them does.
@export_range(20.0, 200.0, 1.0, "suffix:m") var rattle_ahead: float = 95.0
@export_range(10.0, 180.0, 1.0, "suffix:m") var burst_ahead: float = 75.0
@export_range(0.0, 1.0, 0.05) var lair_burst_share: float = 0.4
## The roadside horde: from horde_behind behind the runner to horde_ahead ahead, piled horde_depth out from
## the wall's foot and clinging up to horde_climb, drifting back past the runner this fast.
@export_range(20.0, 200.0, 1.0, "suffix:m") var horde_ahead: float = 70.0
@export_range(0.0, 40.0, 1.0, "suffix:m") var horde_behind: float = 14.0
@export_range(0.2, 1.2, 0.05, "suffix:m") var horde_depth: float = 0.8
@export_range(0.0, 2.0, 0.05, "suffix:m") var horde_climb: float = 0.75
@export_range(0.0, 10.0, 0.25, "suffix:m/s") var horde_drift: float = 2.5
@export_range(0.5, 15.0, 0.25, "suffix:s") var horde_fill_seconds: float = 5.0


## Creatures in a cluster on this device.
func cluster_size(low_end: bool) -> int:
	return cluster_creatures_low_end if low_end else cluster_creatures


func horde_size(low_end: bool) -> int:
	return horde_creatures_low_end if low_end else horde_creatures


func climb_size(low_end: bool) -> int:
	return climb_creatures_low_end if low_end else climb_creatures


func spill_size(low_end: bool) -> int:
	return spill_creatures_low_end if low_end else spill_creatures


## The bait kind of a lap's spot `index` (bait_kinds in turn).
func bait_kind(index: int) -> String:
	if bait_kinds.is_empty():
		return "fence"
	var kind: String = bait_kinds[posmod(index, bait_kinds.size())]
	return kind if kind == "hole" else "fence"
