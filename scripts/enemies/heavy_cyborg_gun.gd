class_name HeavyCyborgGun
extends CyborgGun
## The Heavy Cyborg's gatling (GDD §9.16): "an attack like the heli drone's" (§9.6), fired by a cyborg. It is the
## cyborgs' gun (CyborgGun) with a drone's stream in place of a 2–3 bolt burst, so everything that makes a
## cyborg's burst fair holds for it as it is:
## - the warning first: the wind-up (`charge_time`; the barrels spin up and glow red, HeavyCyborgBody, with the
##   heavy_cyborg_windup sound) while a red aim line follows the runner, then the aim locks and the stream flies
##   down that line;
## - its place in the cyborgs' airspace (GDD §9.2, "Up to two bursts in the air at once"; owner, October 23, 2026:
##   it fires when the other small enemies fire): a stream claims one place from its wind-up until burst_gap after
##   its last round, and keeps the crossfire rule, so the runner always has a way out; it never takes part in the
##   big attacks' turns (EnemyDirector), nor does it wait for them;
## - a clear path (path_clear: no fence, gap, zone doodad, gantryway pillar, dash wall or teleporter's calm stretch
##   in any lane around any round's arrival), the minimum warning, never from behind or at a ceiling rider
##   (Cyborg._may_attack), and a teleport calls a stream under way off.
## The stream (HeavyCyborgTuning's Gatling group): its rounds reach a runner who keeps to the locked line
## bullet_gap apart, the gap a zigzag goes through (the drone's), so the gatling fires them further apart than
## that, the runner running into them (shot_interval); and there are only so many that they all arrive within the
## hit invulnerability window, so armor or a shield protects through the whole stream (most_shots), as through a
## drone's barrage. Its rounds are the pool's red enemy_bullet look, the drone gatling's.

const GATLING_NAME: String = "heavy cyborg gatling"
const BULLET_LOOK: StringName = &"enemy_bullet"

var heavy: HeavyCyborgTuning


func _init(p_shooter: Enemy, p_world: RunWorld, p_tuning: HeavyCyborgTuning, p_rng: RandomNumberGenerator,
		p_body: GunModel) -> void:
	super(p_shooter, p_world, p_tuning, p_rng, p_body)
	heavy = p_tuning
	charge_sound = &"heavy_cyborg_windup"
	shot_sound = &"heavy_cyborg_shot"
	shot_name = GATLING_NAME
	look = BULLET_LOOK


## Seconds between two rounds as the gatling fires them: they reach a runner who keeps to the locked line
## bullet_gap_at() apart, so they leave that much further apart, by the round's speed over the runner's closing
## speed. The level's run speed (MovementTuning.run_speed: a stream keeps its spacing through a dash's burst, which
## passes through every hazard anyway), and the rounds' speed at the level's pace, so in seconds it's the same in
## every zone.
func shot_interval() -> float:
	var round_speed: float = maxf(bolt_speed(), 0.1)
	var run: float = world.tuning.run_speed if world != null and world.tuning != null else MovementTuning.REFERENCE_SPEED
	return heavy.bullet_gap_at(_scaling()) * (round_speed + run) / round_speed


## Every stream fires its full count (HeavyCyborgTuning.barrage_count: no more than fit the invulnerability window).
func roll_shots() -> int:
	return most_shots()


func most_shots() -> int:
	var window: float = world.rules.hit_invulnerability if world != null and world.rules != null else 1.0
	return heavy.barrage_count(_scaling(), window)


## The wind-up's sound comes from the gatling, but no further from the runner than windup_heard_within (along the
## way to it), so it's heard as clearly as the stream it warns of: a wind-up 60 m off would barely be.
func charge_sound_point() -> Vector3:
	var at: Vector3 = _muzzle_base()
	if world == null or world.player == null:
		return at
	var ear: Vector3 = world.player.global_position
	var away: Vector3 = at - ear
	if away.length() <= heavy.windup_heard_within:
		return at
	return ear + away.normalized() * heavy.windup_heard_within


## Where the red aim line ends (GDD §9.6, the drone's): on the runner while the gatling winds up (it follows them),
## then on the locked line, where the runner is along the track, while it fires. Its height is the runner's body's,
## as the stream's.
func aim_line_target() -> Vector3:
	var c: Vector3 = world.player.hurtbox_aabb().get_center()
	if state == State.FIRING:
		return Vector3(_lock.x, _lock.y, c.z)
	return c


## How far the wind-up has got (0 to 1; 1 while firing, 0 otherwise), for the aim line's flicker and the barrels.
func windup_progress() -> float:
	match state:
		State.CHARGING:
			return clampf(_timer / maxf(tuning.charge_time, 0.01), 0.0, 1.0)
		State.FIRING:
			return 1.0
	return 0.0
