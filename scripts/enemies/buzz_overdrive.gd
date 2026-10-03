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
## its moment, so it never waits; it reports itself and the others wait for it. Like a Gilded Sentinel
## (task FIX2), a tank that rolls in claims its turn claim_seconds before its rev (claiming(): another
## type's big attack that gets ready meanwhile waits), then asks as its rev would start: with another
## type's attack begun before its claim still on, it lets the runner pass (no rev, no warning, no cut:
## it speeds off ahead, out of view, and its floor stays whole), so it never revs into another big
## attack. A boss's tank (no roll: Hostile Takeover's drop) and every tank with the switch off
## (GameRules.big_attacks_take_turns) rev as planned, as before (takes_turns()).
## Its rev and charge sound from its own voice on the blade, so they come from where it is as it rolls
## and charges past (the world's voices stay where a sound started), at full volume from a charge's
## distance (sound_full_volume_distance); the spin-up is stretched over its rev by pitch (rev_pitch:
## lower where it revs longest), and it's kept until its charge has died away.
## Numbers: BuzzOverdriveTuning (data/enemies/buzz_overdrive.tres). Look: BuzzOverdriveModel.

## PASS (task FIX2) comes last, so the others keep their numbers in event logs (tools/measure).
enum State { PARKED, ROLL, REV, CHARGE, GONE, PASS }

const Rules = preload("res://scripts/enemies/buzz_overdrive_rules.gd")
## The red of every floor warning (the Octodog's lunge line, BossProps.WARNING_COLOR).
const WARNING_COLOR := Color(1.0, 0.12, 0.08)
const SPARK_COLOR := Color(1.0, 0.6, 0.2)
## How long each spark flies (seconds).
const SPARK_LIFETIME: float = 0.3
## The warning line's width, as a share of the lane, as the rev starts and at its end.
const LINE_WIDTH_START: float = 0.2
const LINE_WIDTH_END: float = 0.4
## While it revs, its line starts this far behind the player (metres).
const LINE_BEHIND: float = 2.0
## Its voice's height over the floor at the blade (metres).
const VOICE_HEIGHT: float = 1.2
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
## Its own positional voice (the rev, the charge), moving with it.
var _voice: AudioStreamPlayer3D
var _hitbox: Hazard
var _rev_t: float = 0.0
## It let the runner pass (PASS, then GONE): it speeds off ahead (_passing_front).
var _passed: bool = false
## Its own spark emitter at the blade (built once, emitting only while it cuts): no particle nodes
## per spark, and none of the shared bursts (RunEffects) taken from kills and hits.
var _sparks: CPUParticles3D
## The sparks' shared mesh.
static var _spark_mesh: BoxMesh


## A Buzz Overdrive's look with its eyes flaring too, for EnemyDirector.warm_up (which frees it) and
## ShaderWarmup (task PERF1): the first builds the meshes and materials every later one shares.
static func warm_up(world: RunWorld, _entry: Dictionary) -> Node:
	var t: BuzzOverdriveTuning = EnemyDirector.tuning_for("buzz_overdrive") as BuzzOverdriveTuning
	if t == null:
		t = BuzzOverdriveTuning.new()
	var variant: StringName = world.skin.enemy_variant if world.skin != null else &"city"
	var look := BuzzOverdriveModel.new()
	look.build(variant, t.body_size, t.blade_radius)
	var meshes: Dictionary = BuzzOverdriveModel.meshes_for(variant, t.body_size, t.blade_radius)
	var flare := MeshInstance3D.new()
	flare.mesh = meshes["eyes"]
	flare.material_override = meshes["eye_flare"]
	look.add_child(flare)
	return look


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
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Voice"
	_voice.position = Vector3(0.0, VOICE_HEIGHT, 0.0)
	var library: SfxLibrary = world.sfx_library
	if library != null:
		_voice.unit_size = tuning.sound_full_volume_distance
		_voice.max_distance = library.warning_max_distance * tuning.sound_full_volume_distance \
			/ maxf(library.warning_full_volume_distance, 1.0)
	if AudioServer.get_bus_index(SfxLibrary.BUS) >= 0:
		_voice.bus = SfxLibrary.BUS
	add_child(_voice)
	_sparks = _make_sparks()
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
	var p: float = world.player_distance()
	if state == State.PARKED and p >= FloorCutPlan.lead_at(cut):
		state = State.ROLL
	if state == State.ROLL and p >= FloorCutPlan.warn_at(cut):
		if _lets_runner_pass():
			_pass()
		else:
			_rev()
	if state == State.REV and p >= FloorCutPlan.charge_at(cut):
		_charge()
	# The track's piece of its cut: looked up from its rev on (built by then, the cut lying well inside
	# the track built ahead), not every frame of its long approach.
	if floor_cut == null and (state == State.REV or state == State.CHARGE):
		floor_cut = world.track.floor_cut(lane, float(cut["end"]))
	front = _front_for(p)
	position = world.lane_point(lane, front)
	if state == State.PASS and front - p > tuning.appear_distance:
		_gone()
	if state == State.CHARGE:
		if floor_cut != null:
			floor_cut.advance_to(front)
		var sparking: bool = not Settings.flashing_reduced
		if _sparks.emitting != sparking:
			_sparks.emitting = sparking
		if front <= float(cut["start"]) + 0.001:
			_gone()
	if state != State.GONE:
		visible = front - p <= tuning.appear_distance
	model.spin(_spin_rate(p) * delta)
	_update_line(delta, p)


## Where its blade is when the player is at `p`: parked a charge's distance past where it sets off,
## then that far ahead of the player while it rolls and revs (at the cut's end when the charge
## starts), then the cut's front, charging back past the player (FloorCutPlan.front_at). Once it has
## let the runner pass, speeding off ahead of them (_passing_front).
func _front_for(p: float) -> float:
	if _passed:
		return _passing_front(p)
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


## Where its blade is when the player is at `p` after it let the runner pass (from its warning point,
## keyed to the player's distance like the rest): it speeds off ahead of them, from a charge's distance
## to appear_distance ahead (out of view) in pass_seconds at the run speed.
func _passing_front(p: float) -> float:
	var ahead: float = float(cut["charge"])
	var k: float = maxf(p - FloorCutPlan.warn_at(cut), 0.0) / maxf(_run_speed * tuning.pass_seconds, 0.01)
	return p + ahead + maxf(tuning.appear_distance - ahead, 1.0) * k * k


## Its big attack (GDD §9: big attacks take turns) is on from the rev until its charge has passed the
## player and it's gone, and while it claims its turn before that (claiming()). The generator planned
## nothing else to go on meanwhile, and its moment can't move, so it never waits: the others wait for it.
func is_major_attack_active() -> bool:
	return alive and (state == State.REV or state == State.CHARGE or claiming())


## True if it takes its turn among the big attacks itself (GDD §9; task FIX2): while big attacks take
## turns (GameRules.big_attacks_take_turns), a tank that rolls in ahead of the runner (its cut planned
## with a roll, `lead`: a level's, BuzzOverdriveRules.plan_for) claims its turn before its rev and lets
## the runner pass if another type's big attack is still on then. A tank a boss brings in itself (its
## cut planned without a roll: Hostile Takeover's drop, the boss keeping its own attacks off it) revs as
## planned, as before; so does every tank with the switch off.
func takes_turns() -> bool:
	return cut.has("lead") and world.director.big_attacks_take_turns()


## Where the player is when it claims its turn: claim_seconds (at the run speed) before its rev.
func claim_at() -> float:
	return FloorCutPlan.warn_at(cut) - tuning.claim_seconds * _run_speed


## True while it claims its turn before its rev (takes_turns()): from claim_at() until it revs or lets
## the runner pass. Its attack counts as on meanwhile, so another type's big attack that gets ready
## then waits, and its own ask finds its turn already held.
func claiming() -> bool:
	return alive and not cut.is_empty() and (state == State.PARKED or state == State.ROLL) and takes_turns() \
		and world.player_distance() >= claim_at()


## Gone once its charge has run past the player (off the screen behind them), or if it had no cut. (Not
## sooner: its cut runs on behind the player to its start, wherever the player has got to.) Hidden and
## behind the player by then, it stays until its charge's sound has died away.
func should_retire() -> bool:
	return state == State.GONE and not (_voice != null and _voice.playing)


## The pitch its spin-up (a sound `sound_seconds` long) plays at to last its rev (`rev_seconds`), ending
## as the charge starts: a little lower where it revs longest (Corporate 1), about its own in the
## Golden Zone.
static func rev_pitch(sound_seconds: float, rev_seconds: float) -> float:
	return clampf(sound_seconds / maxf(rev_seconds, 0.01), 0.5, 2.0)


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
	if floor_cut == null and not cut.is_empty():
		floor_cut = world.track.floor_cut(lane, float(cut["end"]))
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
	_play(&"buzz_rev", (float(cut["warn"]) - float(cut["charge"])) / _run_speed)


func _charge() -> void:
	state = State.CHARGE
	_play(&"buzz_charge")


## As its rev would start, a tank that takes turns asks for its turn (EnemyDirector.major_attack_blocked).
## Its claim has held back the other types' big attacks that got ready since, so only one begun before
## its claim and still on (or its shots still on their way), or one that can't wait begun meanwhile (a
## Bad Dream bursting out of a host killed then), holds it: then it gives up its turn and lets the runner
## pass (true) rather than rev into that attack.
func _lets_runner_pass() -> bool:
	if not takes_turns() or not world.director.major_attack_blocked(self):
		return false
	world.director.give_up_turn(self)
	return true


## It lets the runner pass (GDD §9; task FIX2): no rev, no warning, no cut (its floor stays whole for
## good, FloorCut.stop); it speeds off ahead of them (_passing_front) and is gone once out of view.
func _pass() -> void:
	state = State.PASS
	_passed = true
	if floor_cut == null:
		floor_cut = world.track.floor_cut(lane, float(cut["end"]))
	if floor_cut != null:
		floor_cut.stop()


## Plays `sound` on its own voice (cutting off what it played before: the charge cuts the rev short when
## the player runs faster than the run speed), stretched over `seconds` by pitch where given (rev_pitch).
## Silent in headless runs.
func _play(sound: StringName, seconds: float = 0.0) -> void:
	var library: SfxLibrary = world.sfx_library
	if library == null or not SfxLibrary.audible():
		return
	var stream: AudioStream = library.stream(sound)
	if stream == null:
		return
	var length: float = stream.get_length()
	_voice.stream = stream
	_voice.volume_db = library.volume(sound)
	_voice.pitch_scale = rev_pitch(length, seconds) if seconds > 0.0 and length > 0.0 else 1.0
	_voice.play()


func _gone() -> void:
	state = State.GONE
	_line.visible = false
	_sparks.emitting = false
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


## Its spark emitter, where the blade bites into the floor: sparks_per_second while it cuts (none with
## Reduced flashing), left behind in the world as it charges on.
func _make_sparks() -> CPUParticles3D:
	if _spark_mesh == null:
		_spark_mesh = BoxMesh.new()
		_spark_mesh.size = Vector3.ONE * 0.09
	var p := CPUParticles3D.new()
	p.name = "Sparks"
	p.emitting = false
	p.amount = maxi(2, roundi(tuning.sparks_per_second * SPARK_LIFETIME))
	p.lifetime = SPARK_LIFETIME
	p.mesh = _spark_mesh
	p.material_override = GreyboxMaterials.glow(SPARK_COLOR, 3.0)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0.0, -9.0, 0.0)
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.local_coords = false
	p.position = Vector3(0.0, 0.15, 0.4)
	add_child(p)
	return p
