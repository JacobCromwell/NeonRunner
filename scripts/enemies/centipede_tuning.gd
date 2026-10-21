class_name CentipedeTuning
extends EnemyTuning
## Numbers for the Cybernetic Centipede (task O3; GDD §9.15), edited in data/enemies/centipede.tres and shown in the F6
## panel. The enemy (centipede.gd), its generator rules (centipede_rules.gd) and the escape check that proves every
## placement fair (CentipedeEscape) read the same numbers, so a centipede is placed with the speeds, reach and timings
## it plays with. Its wake and give-up distances are given at MovementTuning.REFERENCE_SPEED and stretched by the
## level's pace (wake_distance_at, give_up_distance_at); every other length (its bite's, leave_margin, retire_behind,
## min_spacing) stays as given, whatever the pace; and its speeds follow the level's run speed, so every warning keeps
## its seconds in a faster zone (GDD §3, "Pace": enemies speed up to match, never with shorter warnings). Every value is
## DESIGN-TBD (docs/questions/o3.md): the GDD gives the shape of the encounter, not its numbers.

@export_group("Chase")
## GDD §9.15: "the runner is slightly faster". Its top speed along the maze's open paths, as a share of the level's run
## speed: a runner who keeps moving pulls away; one stopped at debris (speed 0) is caught.
@export_range(0.5, 0.98, 0.01) var speed_share: float = 0.85
## How quickly it gets up to speed from a standstill, and back down (m/s²).
@export_range(5.0, 120.0, 1.0, "suffix:m/s²") var acceleration: float = 32.0
## How fast its head turns toward where it's going (radians a second): it swings round in a lane to come back along a
## cell (GDD §9.15) in about half a second.
@export_range(1.0, 30.0, 0.5, "suffix:rad/s") var turn_rate: float = 7.0
## The share of its top speed it keeps while it faces away from where it's going (it slows to turn round, so it swings
## round inside a lane instead of ploughing on).
@export_range(0.0, 1.0, 0.05) var turn_slow_share: float = 0.15

@export_group("Waking")
## GDD §9.15: "when the runner enters a section of the maze close to it, it wakes and chases". Close: the runner on the
## floor in a section of the maze joined to its own along open paths (DebrisMaze.open_group, with this attempt's
## smashed debris), within this distance along the track (metres at the reference speed).
@export_range(5.0, 80.0, 1.0, "suffix:m") var wake_distance: float = 30.0
## Seconds from its wake (the hiss and the clatter of legs, the warning) until it moves: it rears up and its lenses
## flare. It doesn't move before.
@export_range(0.2, 2.0, 0.05, "suffix:s") var wake_time: float = 0.6

@export_group("Bite")
## GDD §9.15 (proposed): "the head rearing with its mandibles opening just before each bite". Seconds its head rears and
## its jaws stand open, hissing, before its bite can hurt: every bite comes after this.
@export_range(0.2, 1.5, 0.05, "suffix:s") var bite_telegraph: float = 0.45
## Seconds its bite is live after the telegraph (the jaws snapping shut as its head darts forward). One contact bites
## once: the jaws close on it.
@export_range(0.1, 1.0, 0.05, "suffix:s") var bite_window: float = 0.3
## Seconds its jaws rest closed after a bite before it can rear for the next.
@export_range(0.1, 2.0, 0.05, "suffix:s") var bite_rest: float = 0.55
## The bite's reach in front of its head (metres), with the lunge, at most: its hitbox reaches to just short of its
## jaws' tips as they're drawn each frame (CentipedeModel.jaws_reach), never further than this (bite_reach; GDD §3,
## hitboxes no bigger than what's drawn), and the escape proof takes this whole reach.
@export_range(0.3, 2.0, 0.05, "suffix:m") var bite_length: float = 0.6
## The bite's width (metres): well under a lane (2.4 m), so a runner a lane over is never bitten.
@export_range(0.3, 1.6, 0.05, "suffix:m") var bite_width: float = 0.8
## The bite's height (metres): its head rears up to snap, so a jump doesn't clear it (the runner's feet at a jump's peak
## are MovementTuning.jump_height up, 1.6 m), and under the reared head's top drawn (CentipedeModel.reared_top).
@export_range(1.0, 4.0, 0.05, "suffix:m") var bite_height: float = 1.75
## How far its head darts forward as it bites (metres).
@export_range(0.0, 1.5, 0.05, "suffix:m") var lunge_reach: float = 0.5

@export_group("Toughness")
## GDD §9.15: "two dashes kill it" (Enemy.dash_hits): each dash before the last passes through it safely and wounds it.
@export_range(1, 5) var dash_hits: int = 2
## Seconds a wound stuns it (it recoils, jaws shut, sparks fly) before it turns and chases on.
@export_range(0.0, 2.0, 0.05, "suffix:s") var wound_stun: float = 0.45

@export_group("Giving up")
## It gives up once it's this far behind the runner along open paths (metres at the reference speed).
@export_range(10.0, 150.0, 1.0, "suffix:m") var give_up_distance: float = 45.0
## It gives up once the runner is this far past its block's last wall (metres), out in the breather, which is open floor
## in every lane (nothing there can stop them). It never leaves its block's stretch, run-in to breather.
@export_range(0.0, 20.0, 0.5, "suffix:m") var leave_margin: float = 3.0
## Once it has given up (or slept through the runner's passing), it leaves play this far behind them (metres).
@export_range(5.0, 80.0, 1.0, "suffix:m") var retire_behind: float = 20.0

@export_group("Placement")
## The share of a level's maze blocks, from the feature's start, that get a centipede, at difficulty 0 and at 1
## (LevelGenerator.difficulty_at, where the block stands): GDD §9.15 has them "haunt the debris maze".
@export_range(0.0, 1.0, 0.05) var block_share_easy: float = 0.45
@export_range(0.0, 1.0, 0.05) var block_share_hard: float = 0.9
## The chance a block with one gets a second, at difficulty 0 and at 1.
@export_range(0.0, 1.0, 0.05) var second_share_easy: float = 0.0
@export_range(0.0, 1.0, 0.05) var second_share_hard: float = 0.35
## At most this many in one block.
@export_range(1, 4) var max_per_block: int = 2
## The three places GDD §9.15 names, as weights: an ordinary open section near the runner's way ("near"), the section
## the block's quickest way crosses ("way": "in the only way through"), a cell walled in by debris ("trapped": "a dash
## that opens their debris can release one by accident"). Each placement must still leave the block escapable
## (CentipedeEscape), or it goes elsewhere.
@export_range(0.0, 1.0, 0.05) var near_weight: float = 0.45
@export_range(0.0, 1.0, 0.05) var way_weight: float = 0.3
@export_range(0.0, 1.0, 0.05) var trapped_weight: float = 0.25
## Two in one block wait at least this far apart along the track (metres).
@export_range(0.0, 80.0, 1.0, "suffix:m") var min_spacing: float = 20.0


## Its top speed (m/s) in a level run at `run_speed`.
func chase_speed(run_speed: float) -> float:
	return speed_share * run_speed


## The waking distance (metres) at `pace` (MovementTuning.pace).
func wake_distance_at(pace: float) -> float:
	return wake_distance * pace


## The give-up distance (metres) at `pace`.
func give_up_distance_at(pace: float) -> float:
	return give_up_distance * pace


## The share of blocks that get one at difficulty `d` (0–1).
func block_share(d: float) -> float:
	return scaled(block_share_easy, block_share_hard, d)


## The chance of a second in a block at difficulty `d`.
func second_share(d: float) -> float:
	return scaled(second_share_easy, second_share_hard, d)


## How far in front of its head's middle a bite reaches at most (metres): the head's own half length (`head_half`), the
## lunge and the bite's length.
func bite_reach(head_half: float) -> float:
	return head_half + lunge_reach + bite_length
