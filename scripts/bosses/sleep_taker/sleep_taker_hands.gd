class_name SleepTakerHands
extends Node3D
## The Sleep Taker's grasping hands (GDD §10: "grasping hands rising from the floor: purple mist pools in
## the lane, with whispering. Switch lanes"):
## - the warning: purple mist pools in the runner's lane ahead, where they'll be once it has shown
##   mist_seconds and the hand has been up hand_rise_lead (SleepTakerTuning), with whispering
##   (sleep_taker_whisper) from the pool. The mist is the nightmare's own purple (never a hazard colour)
##   and drawn unshaded, so it reads as well in the dark of lights out. It counts as a floor warning
##   (BossProps.floor_warning): pickups keep off it;
## - the hand bursts up out of the mist (sleep_taker_hand) as the runner comes within hand_rise_lead of
##   it, its claws heating to enemy-attack red, and grasps: an enemy attack (armor or a shield blocks
##   it, the dash passes through) a little smaller than the hand, from the floor to hand_height, above
##   a jump's reach: one lane switch dodges it. Once the runner is past it, it lingers a moment, then
##   sinks back as the mist fades;
## - fairness (plan()): a hand comes only at a runner on the floor, where its lane's floor is clear of
##   holes and fences around the hand (no dodge needed during a jump), under no ceiling, with no pickup
##   in the way, and while a lane max_escape_lanes away is clear from the runner to past the hand.
## Hands are pooled (POOL rigs: the hand, its mist and its rising wisps), drawn by
## sleep_taker_hand.gdshader and sleep_taker_mist.gdshader.

enum Stage { MIST, RISE, UP, SINK }

## Rigs kept ready (more than are ever out at once).
const POOL: int = 3
## How long the mist takes to pool, and a sinking hand to go.
const POOL_SECONDS: float = 0.4
const SINK_SECONDS: float = 0.45
## The hand reaches its full grasp this long after it's up.
const GRASP_SECONDS: float = 0.35
## How much of the mist is left once the hand is up (it drew the rest up into itself; less purple
## glow around its red claws, which would otherwise bloom pink over them).
const MIST_LEFT: float = 0.6
## A hand's attack is over once the runner is this far past it (then the next may come; metres at
## 18 m/s, times the run's pace).
const PASSED: float = 1.0

var boss: SleepTaker
## Hands at work: {n, lane, at (track distance), stage, t, rig (Dictionary), marker}.
var active: Array[Dictionary] = []
## Hands started so far.
var count: int = 0

var _free: Array[Dictionary] = []


func setup(p_boss: SleepTaker) -> void:
	boss = p_boss
	name = "Hands"
	top_level = true
	for i: int in POOL:
		_free.append(_make_rig(i))


## Where a hand could rise fairly now (see the header): {lane, at, escape}, or {} for none.
func plan() -> Dictionary:
	var world: RunWorld = boss.world
	var p: Player = world.player
	if not p.alive or p.surface != Player.Surface.FLOOR or p.in_pit:
		return {}
	var t: SleepTakerTuning = boss.tuning
	var k: float = boss.run_pace()
	var lane: int = clampi(p.lane, 0, boss.lane_count() - 1)
	var d: float = p.distance
	var at: float = d + maxf(p.speed, 1.0) * warning_seconds()
	if not boss.floor_clear_lane(lane, at - t.hand_clear_before * k, at + t.hand_clear_after * k):
		return {}
	if boss.ceiling_between(d, at + t.hand_clear_after * k) or boss.pickup_near(lane, at, t.mist_length):
		return {}
	var escape: int = boss.escape_lane([lane], lane, d, at + t.escape_clear_after * k)
	if escape < 0:
		return {}
	return {"lane": lane, "at": at, "escape": escape}


## How far past a hand the runner is when its attack is over (its depth's far half and PASSED, at the
## run's pace).
func over_distance() -> float:
	return boss.tuning.hand_depth * 0.5 + PASSED * boss.run_pace()


## Seconds from the mist appearing to the runner reaching the hand (at the phase's pace): the warning.
func warning_seconds() -> float:
	var t: SleepTakerTuning = boss.tuning
	return (t.mist_seconds + t.hand_rise_lead) / boss.pace()


## Starts a hand at `plan` (plan()'s answer): the mist and the whispering.
func start(plan: Dictionary) -> void:
	if _free.is_empty():
		return
	var t: SleepTakerTuning = boss.tuning
	var rig: Dictionary = _free.pop_back()
	var lane: int = int(plan["lane"])
	var at: float = float(plan["at"])
	count += 1
	var root: Node3D = rig["root"]
	root.global_position = boss.world.lane_point(lane, at)
	root.visible = true
	(rig["hand_mat"] as ShaderMaterial).set_shader_parameter(&"rise", 0.0)
	(rig["hand_mat"] as ShaderMaterial).set_shader_parameter(&"grasp", 0.0)
	(rig["hand_mat"] as ShaderMaterial).set_shader_parameter(&"attack", 0.0)
	(rig["hand_mat"] as ShaderMaterial).set_shader_parameter(&"fade", 0.0)
	(rig["mist_mat"] as ShaderMaterial).set_shader_parameter(&"amount", 0.0)
	(rig["mist_mat"] as ShaderMaterial).set_shader_parameter(&"surge", 0.0)
	(rig["wisps"] as CPUParticles3D).emitting = true
	var marker := Node3D.new()
	marker.name = "MistWarning"
	boss.props.floor_warning(marker, lane, at - t.mist_length * 0.5, at + t.mist_length * 0.5)
	var hand := {"n": count, "lane": lane, "at": at, "stage": Stage.MIST, "t": 0.0, "rig": rig, "marker": marker}
	active.append(hand)
	boss.sound(&"sleep_taker_whisper", root.global_position + Vector3(0.0, 0.5, 0.0))
	boss.log_event(&"mist", {"n": count, "lane": lane, "at": at, "d": boss.player_distance(),
		"escape": plan.get("escape", -1)})


## True while a hand's warning shows or it can still reach the runner (until they're past it).
func busy() -> bool:
	var d: float = boss.player_distance()
	for h: Dictionary in active:
		if int(h["stage"]) != Stage.SINK and float(h["at"]) + over_distance() > d:
			return true
	return false


## True while a mist warns or a hand is up in front of the runner.
func warning_on() -> bool:
	return busy()


## The hands' damage boxes that are live now.
func live_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for h: Dictionary in active:
		var hz: Hazard = (h["rig"] as Dictionary)["hazard"]
		if hz.is_active():
			out.append(hz)
	return out


## Every rig's damage box (live or not).
func hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for h: Dictionary in active:
		out.append((h["rig"] as Dictionary)["hazard"])
	for rig: Dictionary in _free:
		out.append(rig["hazard"])
	return out


## Every hand goes at once (a phase change, the defeat): mists gone, nothing live.
func clear() -> void:
	for h: Dictionary in active:
		_release(h)
	active.clear()


func tick(delta: float) -> void:
	var t: SleepTakerTuning = boss.tuning
	var p: float = boss.pace()
	var d: float = boss.player_distance()
	for i: int in range(active.size() - 1, -1, -1):
		var h: Dictionary = active[i]
		var rig: Dictionary = h["rig"]
		var hand_mat: ShaderMaterial = rig["hand_mat"]
		var mist_mat: ShaderMaterial = rig["mist_mat"]
		var hz: Hazard = rig["hazard"]
		h["t"] = float(h["t"]) + delta
		var st: float = float(h["t"])
		match int(h["stage"]):
			Stage.MIST:
				mist_mat.set_shader_parameter(&"amount", clampf(st / POOL_SECONDS, 0.0, 1.0))
				if st * p >= t.mist_seconds:
					h["stage"] = Stage.RISE
					h["t"] = 0.0
					boss.sound(&"sleep_taker_hand", (rig["root"] as Node3D).global_position + Vector3(0.0, 1.0, 0.0))
					boss.log_event(&"hand", {"n": h["n"], "lane": h["lane"], "at": h["at"], "d": d})
			Stage.RISE:
				var k: float = clampf(st * p / maxf(t.hand_rise_seconds, 0.01), 0.0, 1.0)
				hand_mat.set_shader_parameter(&"rise", 1.0 - (1.0 - k) * (1.0 - k))
				hand_mat.set_shader_parameter(&"attack", k)
				mist_mat.set_shader_parameter(&"surge", k)
				# It's live from halfway up: the grasp reaches above a jump from there.
				if k >= 0.5 and not hz.is_active():
					hz.set_enabled(true)
				if k >= 1.0:
					h["stage"] = Stage.UP
					h["t"] = 0.0
			Stage.UP:
				hand_mat.set_shader_parameter(&"grasp", clampf(st / GRASP_SECONDS, 0.0, 1.0))
				var drawn: float = clampf(st * 2.0, 0.0, 1.0)
				mist_mat.set_shader_parameter(&"surge", 1.0 - drawn)
				mist_mat.set_shader_parameter(&"amount", lerpf(1.0, MIST_LEFT, drawn))
				var past: float = float(h["at"]) + over_distance()
				if d >= past and not h.has("passed"):
					h["passed"] = st
				if h.has("passed") and st - float(h["passed"]) >= t.hand_linger / p:
					h["stage"] = Stage.SINK
					h["t"] = 0.0
					hz.set_enabled(false)
			Stage.SINK:
				var k: float = clampf(st / SINK_SECONDS, 0.0, 1.0)
				hand_mat.set_shader_parameter(&"rise", 1.0 - k)
				hand_mat.set_shader_parameter(&"attack", 1.0 - k)
				mist_mat.set_shader_parameter(&"amount", MIST_LEFT * (1.0 - k))
				if k >= 1.0:
					_release(h)
					active.remove_at(i)


func _release(h: Dictionary) -> void:
	var rig: Dictionary = h["rig"]
	(rig["hazard"] as Hazard).set_enabled(false)
	(rig["root"] as Node3D).visible = false
	(rig["wisps"] as CPUParticles3D).emitting = false
	boss.props.remove(h["marker"])
	if not _free.has(rig):
		_free.append(rig)


## One pooled hand: its root (placed on a lane at the hand's spot), the hand, its mist pool, the wisps
## rising off it, and its damage box (the body's enemy attack).
func _make_rig(index: int) -> Dictionary:
	var t: SleepTakerTuning = boss.tuning
	var geo: TrackGeometry = boss.world.geo
	var root := Node3D.new()
	root.name = "Hand%d" % index
	root.top_level = true
	root.visible = false
	add_child(root)
	var hand_mat: ShaderMaterial = SleepTakerModel.hand_material(float(index) * 3.1 + 0.7)
	var hand := MeshInstance3D.new()
	hand.name = "Hand"
	hand.mesh = SleepTakerModel.hand_mesh()
	hand.material_override = hand_mat
	hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader lifts it up from below the street: keep it from being culled.
	hand.extra_cull_margin = 4.0
	root.add_child(hand)
	var mist_mat: ShaderMaterial = SleepTakerModel.mist_material(float(index) * 1.7)
	var quad := QuadMesh.new()
	quad.size = Vector2(geo.lane_width * 0.92, t.mist_length)
	var mist := MeshInstance3D.new()
	mist.name = "Mist"
	mist.mesh = quad
	mist.material_override = mist_mat
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.rotation.x = -PI * 0.5
	mist.position = Vector3(0.0, 0.05, 0.0)
	root.add_child(mist)
	var wisps := CPUParticles3D.new()
	wisps.name = "Wisps"
	wisps.amount = 14
	wisps.lifetime = 1.2
	wisps.emitting = false
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wisps.emission_box_extents = Vector3(geo.lane_width * 0.35, 0.05, t.mist_length * 0.4)
	wisps.direction = Vector3(0.0, 1.0, 0.0)
	wisps.spread = 15.0
	wisps.gravity = Vector3(0.0, 0.6, 0.0)
	wisps.initial_velocity_min = 0.3
	wisps.initial_velocity_max = 0.9
	wisps.scale_amount_min = 1.2
	wisps.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	wisps.scale_amount_curve = curve
	var puff := QuadMesh.new()
	puff.size = Vector2(0.6, 0.6)
	wisps.mesh = puff
	wisps.material_override = SleepTakerModel.wisp_material(Color(SleepTakerModel.MIST_COLOR, 0.32))
	wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wisps)
	var size := Vector3(geo.lane_width * t.hand_width_share, t.hand_height, t.hand_depth)
	var hazard: Hazard = boss.body.add_hitbox(&"attack", size, Vector3(0.0, size.y * 0.5, 0.0), true, root)
	hazard.hazard_name = "Sleep Taker's hand"
	hazard.set_enabled(false)
	return {"root": root, "hand": hand, "hand_mat": hand_mat, "mist": mist, "mist_mat": mist_mat, "wisps": wisps,
		"hazard": hazard}
