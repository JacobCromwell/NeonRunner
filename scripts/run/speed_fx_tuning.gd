class_name SpeedFxTuning
extends Resource
## Numbers for speed and impact spectacle (GDD §3, the owner's playtest, September 30, 2026): the
## camera's field-of-view kick and lane-switch lean (RunCamera), screen-space speed lines
## (SpeedLines), and the shake/hit-stop/sparks RunEffects plays on landings, stomps, kills and
## blocked hits. Edit data/tuning/speed_fx.tres; every number shows in F6, "Speed effects".
##
## Shake strengths and hit-stop durations are also scaled by the Screen shake setting
## (Settings.shake_scale, RunEffects.shake_scale): 0 turns them off. Speed lines and the field-of-view
## kick stay on with Screen shake off (they never strobe, so Reduced flashing needs nothing from
## them either): only their own reference numbers shape them.

@export_group("Field of view")
## Player speed (m/s) at and below which the camera sits at MovementTuning's plain camera_fov (the
## City's cruising speed before G1's zone-by-zone rise, GDD §3).
@export_range(5.0, 40.0, 0.5, "suffix:m/s") var fov_reference_speed: float = 18.0
## Degrees of extra field of view per m/s above fov_reference_speed (run speed rising zone by zone,
## a ramp, a speed pad, the dash's own speed bonus: Player.speed already adds them all together).
@export_range(0.0, 3.0, 0.05, "suffix:°/(m/s)") var fov_kick_per_speed: float = 0.85
## The widest the kick may ever get, however fast Player.speed is.
@export_range(0.0, 30.0, 0.5, "suffix:°") var fov_kick_max: float = 14.0
## How fast the kick eases in as speed rises (RunCamera._update, 1 - exp(-rate * delta)).
@export_range(0.5, 20.0, 0.5) var fov_attack_rate: float = 6.0
## How fast it eases back out as speed falls (slower than the attack, so a boost's end reads as a
## settle rather than a snap).
@export_range(0.5, 20.0, 0.5) var fov_release_rate: float = 2.5

@export_group("Lane lean")
## How far the camera rolls (banks) into a lane switch, at the switch's midpoint.
@export_range(0.0, 10.0, 0.25, "suffix:°") var lane_lean_max_deg: float = 3.0
## How fast the lean eases toward its target (1 - exp(-rate * delta)).
@export_range(0.5, 30.0, 0.5) var lane_lean_rate: float = 12.0

@export_group("Speed lines")
## Below this speed the streaks are invisible.
@export_range(5.0, 40.0, 0.5, "suffix:m/s") var lines_min_speed: float = 17.0
## At and above this speed the streaks are at full strength (lines_max_alpha): the Golden Zone's
## cruising speed with a boost running (GDD §3).
@export_range(5.0, 50.0, 0.5, "suffix:m/s") var lines_full_speed: float = 30.0
## Their strongest opacity, at lines_full_speed.
@export_range(0.0, 1.0, 0.02) var lines_max_alpha: float = 0.32
## Half-width, from screen centre (0–1 of the half-screen), kept clear of streaks so a lane's centre
## always reads clean: 0.5 would touch the very edges, 0 would fill the whole screen.
@export_range(0.1, 0.9, 0.02) var lines_safe_width: float = 0.44
## How fast the streaks' strength eases toward the speed-driven target (1 - exp(-rate * delta)).
@export_range(0.5, 20.0, 0.5) var lines_ease_rate: float = 5.0

@export_group("Landings")
## A landing shakes the camera only after falling at least this far above the floor (a ramp jump or
## a drop; an ordinary hop over a gap stays quiet).
@export_range(0.5, 10.0, 0.25, "suffix:m") var land_shake_fall_height: float = 3.0
@export_range(0.0, 1.0, 0.01) var land_shake_strength: float = 0.14
@export_range(0.05, 1.0, 0.01, "suffix:s") var land_shake_time: float = 0.22

@export_group("Stomps")
@export_range(0.0, 1.0, 0.01) var stomp_shake_strength: float = 0.18
@export_range(0.05, 1.0, 0.01, "suffix:s") var stomp_shake_time: float = 0.22
## Hit-stop on a stomp kill (RunEffects.freeze): the camera holds for this long, in real seconds.
## Never touches Engine.time_scale, so physics, timers and the generator tick on underneath and a
## seeded run plays out identically with this on or off (SlowTimePowerup owns time_scale for its own,
## very different, real slow-down).
@export_range(0.0, 0.3, 0.005, "suffix:s") var stomp_freeze_time: float = 0.07

@export_group("Kills")
## Every enemy defeat (EnemyDirector.enemy_defeated), whatever killed it: small and consistent, so a
## bigger, cause-specific shake an enemy or a power-up already plays (a dash kill, a boss hit) is
## never drowned out (RunCamera keeps the stronger of two overlapping shakes).
@export_range(0.0, 1.0, 0.01) var kill_shake_strength: float = 0.05
@export_range(0.05, 1.0, 0.01, "suffix:s") var kill_shake_time: float = 0.14
@export_range(0.0, 0.3, 0.005, "suffix:s") var kill_freeze_time: float = 0.05
## Hit-stops never chain (task PERF1): a freeze asked for less than this long after the last one began
## is left out (one asked in the same frame as it, a stomp's and its kill's, still keeps the longer of
## the two). Kills in quick succession, auto-fire through a cluster or a dash through a row, would
## otherwise hold the camera again and again, which reads as the game stuttering.
@export_range(0.0, 1.0, 0.01, "suffix:s") var freeze_gap: float = 0.3
@export_range(2, 40, 1) var kill_spark_amount: int = 12
@export_range(2, 40, 1) var kill_debris_amount: int = 6

@export_group("Blocked hits")
## The armor or the shield absorbs a hit (Player.movement_event: armor_hit, armor_break,
## shield_break): a spark burst in the item's own colour (PlayerSuit.GLOW / PlayerSuit.SHIELD, never
## a hazard colour) and a small shake, bigger when the item breaks.
@export_range(0.0, 1.0, 0.01) var block_shake_strength: float = 0.08
@export_range(0.0, 1.0, 0.01) var block_break_shake_strength: float = 0.16
@export_range(0.05, 1.0, 0.01, "suffix:s") var block_shake_time: float = 0.18
@export_range(2, 40, 1) var block_spark_amount: int = 10

@export_group("Doodad pushes")
## A zone doodad shoves the runner into the next lane (GDD §3; Player.movement_event doodad_push): a
## small, short shake with the thud, so the shove reads as a bump, never as a hit (no sparks, no
## hit-stop). DESIGN-TBD.
@export_range(0.0, 1.0, 0.01) var push_shake_strength: float = 0.05
@export_range(0.05, 1.0, 0.01, "suffix:s") var push_shake_time: float = 0.14

@export_group("Thefts")
## A thief's theft and payout (GDD §9.12; ScoreKeeper.stolen / recovered): a stream of coins in the
## credit look flies from the runner to the thief, or bursts out of a caught thief into the runner
## (RunEffects.coin_stream). No shake and no hit-stop: a theft is no hit. DESIGN-TBD (the look).
## One coin per this many credits taken or paid (at least 4 coins, at most RunEffects.STREAM_COINS).
@export_range(1, 100, 1) var coin_stream_credits_per_coin: int = 10
## Seconds over which the coins leave, one after another.
@export_range(0.0, 2.0, 0.05, "suffix:s") var coin_stream_spread: float = 0.45
## Seconds each coin takes to fly from one end to the other.
@export_range(0.1, 2.0, 0.05, "suffix:s") var coin_stream_flight: float = 0.4
## How high a coin arcs over the straight line, at its middle.
@export_range(0.0, 4.0, 0.1, "suffix:m") var coin_stream_arc: float = 1.2
@export_range(2, 40, 1) var theft_spark_amount: int = 10

@export_group("Explosions")
## Every explosion in the game is one pooled fireball (RunEffects.fireball, FireballPool; GDD §11, the
## owner, October 8, 2026: "a yellow and red fireball"): a bright yellow core blooming into orange and
## red, rolling outward and up, embers flying and darker smoke after. The caller picks how big (its size
## is the fireball's radius in metres). The counts below are fixed when a level loads (a particle system
## never reallocates mid-run); the rest apply to the next explosion. Fireballs are looks only: they
## collide with nothing and last about a second (a few for a boss), so none ever reads as a hazard.
## Fireballs that can be on screen at once; one more cuts the oldest short.
@export_range(1, 12, 1) var fireball_pool: int = 8
## Scales every fireball's size (1 = as each explosion asks): the quickest way to make all of them bigger or smaller.
@export_range(0.5, 2.0, 0.05) var fireball_scale: float = 1.0
## Fire puffs in one fireball (the glowing, additive body).
@export_range(6, 40, 1) var fireball_puffs: int = 22
## Smoke puffs that follow the fire (dark, see-through; none on a quick fireball, such as a bomb's).
@export_range(0, 20, 1) var fireball_smoke_puffs: int = 8
## Embers thrown out of it (small, glowing, falling).
@export_range(0, 40, 1) var fireball_embers: int = 20
## How long the fire burns (a small fireball; a bigger one is slower, see fireball_big_size).
@export_range(0.3, 2.0, 0.05, "suffix:s") var fireball_seconds: float = 1.0
## How long the smoke takes to clear.
@export_range(0.5, 4.0, 0.1, "suffix:s") var fireball_smoke_seconds: float = 2.0
## How hot the fire draws (the colours are multiplied by this; above about 1.2 it blooms on Forward+).
@export_range(0.5, 3.0, 0.05) var fireball_glow: float = 1.2
## From this size (metres) up, a fireball plays slower, down to fireball_big_pace at three times it: a
## bigger blast reads as bigger by taking its time.
@export_range(1.0, 10.0, 0.5, "suffix:m") var fireball_big_size: float = 3.0
@export_range(0.3, 1.0, 0.05) var fireball_big_pace: float = 0.6
## Reduced flashing (Settings): the fireball plays this many times slower, with no white-hot flash (it
## swells from nothing to a peak this share of the usual brightness, in orange and yellow only).
@export_range(1.0, 3.0, 0.05) var fireball_reduced_slowdown: float = 1.5
@export_range(0.1, 1.0, 0.05) var fireball_reduced_brightness: float = 0.55
