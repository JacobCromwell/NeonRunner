extends Enemy
## The Buzz Overdrive (GDD §9.9; first in Corporate 1, then the Dead Zone and the Golden Zone): a
## truck-sized buzzsaw tank that cuts its lane's floor into a gap. The generator planned its cut
## (LevelLayout.cuts, buzz_overdrive_rules.gd; GDD §9.9's limits) and stood it at the cut's end, in its
## lane; the tank is only the visible cause. Everything it does is keyed to the player's distance
## (FloorCutPlan), so it does the same on every attempt and at every frame rate:
## 1. Seen in the distance: it appears parked in its lane (appear_distance ahead), facing the player.
## 2. When the player is a charge's distance from it (FloorCutPlan.lead_at), it rolls ahead of them,
##    keeping that distance (within the missiles' reach, beyond laser tier 1's) for roll_seconds.
## 3. The rev (the warning, from warn_at): its blade spins up with the spin-up whine (buzz_rev), its
##    eyes flare and a red line lights the lane it is about to cut, from the player to its blade (like
##    the Octodog's lunge line: it pulses and widens, and only widens with Reduced flashing), while it
##    keeps rolling.
## 4. The charge (from charge_at, where it has reached the cut's end): it charges along its lane at the
##    player (buzz_charge), its blade biting into the floor, which becomes a gap behind it (FloorCut:
##    advance_to), sparks flying (none with Reduced flashing); it meets the player charge_seconds after
##    it set off and runs on past them, off the screen behind, and is gone.
## Its blade hurts on contact (an enemy attack: the armor and the shield block it, and then the floor
## under the player holds for GameRules.cut_hold_seconds, FloorCut.hold_under); its hitbox is narrow and
## centred on its lane, so it never reaches anyone in another lane, on a wall or on a ceiling. Weapons
## kill it (22 laser tier 1 shots; killing it before it charges saves the floor, mid-charge the cut
## stops where it dies: FloorCut.stop); the claws don't (claw-immune); the dash smashes it (into the cut
## lane: only survivable with the grapple hook); it can't be stomped (the player would land on the
## blade). Its rev and charge are one big attack (GDD §9: big attacks take turns): the generator planned
## its moment, so it never waits; it reports itself and the others wait for it.
## Numbers: BuzzOverdriveTuning (data/enemies/buzz_overdrive.tres). Look: BuzzOverdriveModel.

enum State { PARKED, ROLL, REV, CHARGE, GONE }

const Rules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
## The red of every floor warning (the Octodog's lunge line, BossProps.WARNING_COLOR).
const WARNING_COLOR := Color(1.0, 0.12, 0.08)
const SPARK_COLOR := Color(1.0, 0.6, 0.2)
## The warning line's width, as a share of the lane, as the rev starts and at its end.
const LINE_WIDTH_START: float = 0.2
const LINE_WIDTH_END: float = 0.4
## While it revs, its line starts this far behind the player (metres).
const LINE_BEHIND: float = 2.0
## The blade's spin (radians a second): idling, and full (the end of the rev and the charge).
const SPIN_IDLE: float = 2.5
const SPIN_FULL: float = 34.0

var tuning: BuzzOverdriveTuning
var state: State = State.PARKED
var lane: int = 0
## The layout's cut it runs (LevelLayout.cuts), and the track's once its chunk is built.
var cut: Dictionary = {}
var floor_cut: FloorCut
## Where its blade bites the floor (track distance): the cut's front while it charges.
var front: float = 0.0
var model: BuzzOverdriveModel

var _run_speed: float = 18.0
var _line: MeshInstance3D
var _hitbox: Hazard
var _rev_t: float = 0.0
var _spark_left: float = 0.0


func _build() -> void:
	tuning = tuning_res as BuzzOverdriveTuning
	if tuning == null:
		tuning = BuzzOverdriveTuning.new()
	display_name = "Buzz Overdrive"
	claw_immune = true
	stompable = false
	dash_kills = true
	lane = clampi(int(spawn.get("lane", 0)), 0, world.geo.lane_count - 1)
	cut = Rules.cut_of(world.layout, spawn)
	_run_speed = world.tuning.run_speed
	model = BuzzOverdriveModel.new()
	model.name = "Model"
	add_child(model)
	model.build(world.skin.enemy_variant if world.skin != null else &"city", tuning.body_size, tuning.blade_radius)
	var h: Vector3 = tuning.hitbox_size
	_hitbox = add_hitbox(&"attack", h, Vector3(0.0, h.y * 0.5, 0.0), true)
	_hitbox.hazard_name = "Buzz Overdrive's saw"
	_hitbox.contacted.connect(_on_contacted)
	_line = MeshInstance3D.new()
	_line.name = "WarningLine"
	_line.mesh = GreyboxMaterials.unit_box()
	_line.material_override = GreyboxMaterials.glow(WARNING_COLOR, 3.0, 0.5)
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.top_level = true
	_line.visible = false
	add_child(_line)
	if cut.is_empty():
		state = State.GONE
		front = float(spawn.get("at", 0.0))
	else:
		front = _front_for(world.player_distance())
	position = world.lane_point(lane, front)
	visible = state != State.GONE and front - world.player_distance() <= tuning.appear_distance


func _tick(delta: float) -> void:
	if cut.is_empty():
		return
	if floor_cut == null:
		floor_cut = world.track.floor_cut(lane, float(cut["end"]))
	var p: float = world.player_distance()
	if state == State.PARKED and p >= FloorCutPlan.lead_at(cut):
		state = State.ROLL
	if state == State.ROLL and p >= FloorCutPlan.warn_at(cut):
		_rev()
	if state == State.REV and p >= FloorCutPlan.charge_at(cut):
		_charge()
	front = _front_for(p)
	position = world.lane_point(lane, front)
	if state == State.CHARGE:
		if floor_cut != null:
			floor_cut.advance_to(front)
		_sparks(delta)
		if front <= float(cut["start"]) + 0.001:
			_gone()
	if state != State.GONE:
		visible = front - p <= tuning.appear_distance
	model.spin(_spin_rate(p) * delta)
	_update_line(delta, p)


## Where its blade is when the player is at `p`: parked a charge's distance past where it sets off,
## then that far ahead of the player while it rolls and revs (at the cut's end when the charge
## starts), then the cut's front, charging back past the player (FloorCutPlan.front_at).
func _front_for(p: float) -> float:
	var ahead: float = float(cut["charge"])
	if p < FloorCutPlan.lead_at(cut):
		return FloorCutPlan.lead_at(cut) + ahead
	if p < FloorCutPlan.charge_at(cut):
		return p + ahead
	return FloorCutPlan.front_at(cut, p, _run_speed)


func _spin_rate(p: float) -> float:
	match state:
		State.REV:
			var k: float = clampf((p - FloorCutPlan.warn_at(cut)) / maxf(float(cut["warn"]) - float(cut["charge"]), 0.01), 0.0, 1.0)
			return lerpf(SPIN_IDLE, SPIN_FULL, k * k)
		State.CHARGE:
			return SPIN_FULL
	return SPIN_IDLE


## Its big attack (GDD §9: big attacks take turns) is on from the rev until its charge has passed the
## player and it's gone. The generator planned nothing else to go on meanwhile, and its moment can't
## move, so it never asks for a turn: the others wait for it.
func is_major_attack_active() -> bool:
	return alive and (state == State.REV or state == State.CHARGE)


## Gone once its charge has run past the player (off the screen behind them), or if it had no cut. (Not
## sooner: its cut runs on behind the player to its start, wherever the player has got to.)
func should_retire() -> bool:
	return state == State.GONE


## Auto-fire picks it only while it's in view.
func targetable() -> bool:
	return super.targetable() and visible and state != State.GONE


func aim_point() -> Vector3:
	return global_position + Vector3(0.0, 1.2, BuzzOverdriveModel.hull_front(tuning.blade_radius) + 0.4)


func hit_radius() -> float:
	return 1.5


func _on_defeated(_cause: StringName) -> void:
	# GDD §9.9: "killing it before it charges saves the floor; killing it mid-charge stops the cut where
	# it dies". A cut whose chunk isn't built yet never begins.
	if floor_cut != null:
		floor_cut.stop()
	_line.visible = false
	world.play_sfx_at(&"truck_explode", global_position)
	world.effects.burst(aim_point(), Color(1.0, 0.45, 0.15), 42, 1.3)
	world.effects.burst(aim_point() + Vector3(0.0, 0.6, 0.0), Color(0.32, 0.32, 0.34), 22, 1.0)
	queue_free()


func _rev() -> void:
	state = State.REV
	_rev_t = 0.0
	model.set_flare(true)
	_line.visible = true
	world.play_sfx_at(&"buzz_rev", global_position)


func _charge() -> void:
	state = State.CHARGE
	world.play_sfx_at(&"buzz_charge", global_position)


func _gone() -> void:
	state = State.GONE
	_line.visible = false
	visible = false


## After the shield or the armor blocks its blade, the floor under the player holds for a moment
## (GDD §9.9: "just enough to switch lanes").
func _on_contacted(outcome: int) -> void:
	if outcome != DamageRules.Outcome.BLOCKED_ARMOR and outcome != DamageRules.Outcome.BLOCKED_SHIELD:
		return
	if floor_cut != null and world.player != null:
		floor_cut.hold_under(world.player, world.rules.cut_hold_seconds if world.rules != null else 1.0)


## The red line down the lane it's about to cut, widening over the rev and pulsing (only widening with
## Reduced flashing): while it revs, from just behind the player (or the cut's start, if that's further
## back) to its blade, the whole lane between them; while it charges, the stretch it still has to cut.
func _update_line(delta: float, p: float) -> void:
	if not _line.visible:
		return
	_rev_t += delta
	var from: float = float(cut["start"])
	if state == State.REV:
		from = minf(from, p - LINE_BEHIND)
	var to: float = front
	if to - from < 0.05:
		_line.visible = false
		return
	var k: float = clampf((p - FloorCutPlan.warn_at(cut)) / maxf(float(cut["warn"]) - float(cut["charge"]), 0.01), 0.0, 1.0)
	var beat: float = 1.0 if Settings.flashing_reduced else 0.9 + 0.15 * sin(_rev_t * 30.0)
	var width: float = world.geo.lane_width * lerpf(LINE_WIDTH_START, LINE_WIDTH_END, k) * beat
	_line.global_transform = Transform3D(Basis.from_scale(Vector3(width, 0.04, to - from)),
		Vector3(world.geo.lane_x(lane), 0.03, TrackGeometry.world_z((from + to) * 0.5)))


## Sparks where the blade bites into the floor (none with Reduced flashing).
func _sparks(delta: float) -> void:
	if Settings.flashing_reduced:
		return
	_spark_left -= delta
	if _spark_left > 0.0:
		return
	_spark_left = tuning.spark_every
	world.effects.burst(global_position + Vector3(0.0, 0.15, 0.4), SPARK_COLOR, 6, 0.3)
