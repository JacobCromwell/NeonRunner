extends TestSuite
## The player avatar (PlayerAvatar) and the shared humanoid rig (HumanoidRig): it builds, every pose
## runs cleanly, the run pose fits MovementTuning.visual_size, the budgets hold, equipment toggles,
## the collapse finishes on its own, and a real Player drives it through its moves.

const TRIANGLE_BUDGET: int = 2000
const DRAW_CALL_BUDGET: int = 20
const DT: float = 1.0 / 60.0
const RUN_SPEED: float = 18.0
const Activity := HumanoidRig.Activity


func run() -> void:
	_test_build()
	_test_other_parts()
	_test_poses()
	_test_transitions()
	_test_run_fits_visual_size()
	_test_pose_heights()
	_test_no_skating_at_jog()
	_test_budget()
	_test_equipment()
	_test_fit_follows_retune()
	_test_flash_death_and_reset()
	_test_cost()
	await _test_self_drive()
	await _test_in_player()


# --- Helpers -------------------------------------------------------------------

static func _state(extra: Dictionary = {}) -> Dictionary:
	var s := {"surface": "floor", "grounded": true, "vh": 0.0, "sliding": false, "distance": 0.0,
		"speed": RUN_SPEED, "wall_side": 1, "switch_dir": 0, "alive": true, "dashing": false,
		"just_landed": false, "stomping": false}
	s.merge(extra, true)
	return s


## Animates `frames` frames of `state`, advancing the distance at its speed. Returns the union of the
## bounds, and fails a check if any frame produces a non-finite pose.
func _drive(avatar: PlayerAvatar, state: Dictionary, frames: int, label: String) -> AABB:
	var s: Dictionary = state.duplicate()
	var box := AABB()
	var finite: bool = true
	for i: int in frames:
		s["distance"] = float(s["distance"]) + float(s["speed"]) * DT
		avatar.animate(s, DT)
		var b: AABB = avatar.rig.bounds()
		finite = finite and b.position.is_finite() and b.size.is_finite() and _joints_finite(avatar.rig)
		box = b if i == 0 else box.merge(b)
	check(finite, "%s: every frame gives a finite pose" % label)
	return box


static func _joints_finite(rig: HumanoidRig) -> bool:
	for joint_name: StringName in HumanoidRig.JOINT_NAMES:
		var j: Node3D = rig.joint(joint_name)
		if not j.transform.origin.is_finite() or not j.rotation.is_finite():
			return false
	return true


static func _find_avatar(node: Node) -> PlayerAvatar:
	for child: Node in node.get_children():
		if child is PlayerAvatar:
			return child
		var found: PlayerAvatar = _find_avatar(child)
		if found != null:
			return found
	return null


## World-space z of a joint's origin in the avatar's frame, walking up to the avatar.
static func _joint_z(avatar: PlayerAvatar, joint_name: StringName) -> float:
	var node: Node3D = avatar.rig.joint(joint_name)
	var xf := Transform3D.IDENTITY
	while node != avatar:
		xf = node.transform * xf
		node = node.get_parent() as Node3D
	return xf.origin.z


# --- Tests ---------------------------------------------------------------------

func _test_build() -> void:
	var avatar := PlayerAvatar.new()
	check(avatar.rig != null and avatar.rig.get_parent() == avatar, "the avatar builds its rig")
	var missing: PackedStringArray = []
	for joint_name: StringName in HumanoidRig.JOINT_NAMES:
		var j: Node3D = avatar.rig.joint(joint_name)
		var part: MeshInstance3D = j.get_node_or_null("Part") as MeshInstance3D if j != null else null
		if part == null or part.mesh == null:
			missing.append(String(joint_name))
	check(HumanoidRig.JOINT_NAMES.size() == 16 and missing.is_empty(),
		"16 joints (pelvis to feet), each carrying a part mesh (missing: %s)" % ", ".join(missing))
	var second := PlayerAvatar.new()
	var mesh_a: Mesh = (avatar.rig.joint(&"head").get_node("Part") as MeshInstance3D).mesh
	var mesh_b: Mesh = (second.rig.joint(&"head").get_node("Part") as MeshInstance3D).mesh
	check(mesh_a == mesh_b, "meshes are built once and shared between avatars")
	check(avatar.rig.material != second.rig.material, "each avatar has its own material (flash, glow)")
	avatar.free()
	second.free()


## The same rig builds a different character from other parts (the enemy cyborgs will).
func _test_other_parts() -> void:
	var parts := HumanoidParts.new()
	parts.cache_key = "test_box_figure"
	parts.thigh_length = 0.36
	parts.shin_length = 0.34
	var list: Array[HumanoidPiece] = []
	for segment: StringName in HumanoidParts.SEGMENTS:
		var piece := HumanoidPiece.new()
		piece.segment = segment
		piece.side = HumanoidPiece.Placement.CENTER
		piece.size = Vector3(0.1, 0.1, 0.1)
		piece.offset = Vector3(0.0, -0.05, 0.0)
		list.append(piece)
	parts.pieces = list
	var rig := HumanoidRig.new()
	rig.build(parts, null)
	check(rig.triangle_count() == 16 * 12, "a rig builds from other parts (%d triangles)" % rig.triangle_count())
	var ok: bool = true
	for s: Dictionary in [_state(), _state({"sliding": true}), _state({"alive": false}), _state({"grounded": false, "vh": 5.0})]:
		for i: int in 20:
			s["distance"] = float(s["distance"]) + RUN_SPEED * DT
			rig.animate(s, DT)
		var b: AABB = rig.bounds()
		ok = ok and _joints_finite(rig) and absf(b.position.y) < 0.02
	check(ok, "the other figure animates, standing on the ground")
	rig.free()
	HumanoidParts.clear_cache()


func _test_poses() -> void:
	var avatar := PlayerAvatar.new()
	var cases: Array = [
		["idle", _state({"speed": 0.0}), Activity.IDLE],
		["run", _state(), Activity.RUN],
		["jump rise", _state({"grounded": false, "vh": 7.0}), Activity.AIR],
		["jump apex", _state({"grounded": false, "vh": 0.0}), Activity.AIR],
		["jump fall", _state({"grounded": false, "vh": -7.0}), Activity.AIR],
		["slide", _state({"sliding": true}), Activity.SLIDE],
		["wall run right", _state({"surface": "wall", "grounded": false, "wall_side": 1}), Activity.WALL],
		["wall run left", _state({"surface": "wall", "grounded": false, "wall_side": -1}), Activity.WALL],
		["ceiling run", _state({"surface": "ceiling"}), Activity.RUN],
		["lane switch lean", _state({"switch_dir": 1}), Activity.RUN],
		["dash", _state({"dashing": true}), Activity.DASH],
		["stomp", _state({"grounded": false, "vh": -22.0, "stomping": true}), Activity.STOMP],
		["death", _state({"alive": false}), Activity.DEAD],
	]
	for c: Array in cases:
		avatar.reset()
		avatar.animate(_state(), DT)  # Start from a run, so each pose also blends in.
		var box: AABB = _drive(avatar, c[1], 30, c[0])
		var rig: HumanoidRig = avatar.rig
		check(rig.activity == c[2] and rig.weight(c[2]) > 0.95,
			"%s: blends into its pose (weight %.2f)" % [c[0], rig.weight(c[2])])
		check(box.size.y > 0.2 and rig.bounds().position.y > -0.01 and rig.bounds().position.y < 0.05,
			"%s: stands on its surface (lowest point %.3f m)" % [c[0], rig.bounds().position.y])
	# The lane-switch lean tilts the body toward the move; the ceiling mirrors it.
	avatar.reset()
	_drive(avatar, _state({"switch_dir": 1}), 20, "lean right")
	var lean_right: float = (avatar.rig.get_node("Body") as Node3D).rotation.z
	avatar.reset()
	_drive(avatar, _state({"switch_dir": 1, "surface": "ceiling"}), 20, "lean on the ceiling")
	var lean_ceiling: float = (avatar.rig.get_node("Body") as Node3D).rotation.z
	check(lean_right < -0.1 and lean_ceiling > 0.1,
		"lane switch leans into the move, mirrored on the ceiling (%.2f, %.2f rad)" % [lean_right, lean_ceiling])
	# Landing squashes, then recovers.
	avatar.reset()
	_drive(avatar, _state(), 10, "before landing")
	avatar.animate(_state({"just_landed": true, "distance": 100.0}), DT)
	avatar.animate(_state({"distance": 100.3}), DT)
	avatar.animate(_state({"distance": 100.6}), DT)
	var squashed: float = (avatar.rig.get_node("Body") as Node3D).scale.y
	_drive(avatar, _state({"distance": 100.6}), 30, "after landing")
	var recovered: float = (avatar.rig.get_node("Body") as Node3D).scale.y
	check(squashed < 0.95 and is_equal_approx(recovered, 1.0),
		"landing squashes the body, then it recovers (%.3f, %.3f)" % [squashed, recovered])
	avatar.free()


## A whole sequence through every blend, as the Player produces it.
func _test_transitions() -> void:
	var avatar := PlayerAvatar.new()
	var steps: Array = [
		[_state(), 20], [_state({"grounded": false, "vh": 8.0}), 10], [_state({"grounded": false, "vh": 0.0}), 8],
		[_state({"grounded": false, "vh": -8.0}), 10], [_state({"just_landed": true}), 1], [_state(), 10],
		[_state({"sliding": true}), 30], [_state(), 10], [_state({"switch_dir": -1}), 8],
		[_state({"surface": "wall", "grounded": false, "wall_side": -1}), 60], [_state({"grounded": false, "vh": 6.0}), 20],
		[_state({"surface": "ceiling"}), 30], [_state({"dashing": true}), 30],
		[_state({"grounded": false, "vh": -22.0, "stomping": true}), 10], [_state({"alive": false}), 60],
	]
	var distance: float = 0.0
	var ok: bool = true
	for step: Array in steps:
		var s: Dictionary = step[0]
		for i: int in int(step[1]):
			distance += RUN_SPEED * DT
			s["distance"] = distance
			avatar.animate(s, DT)
			ok = ok and _joints_finite(avatar.rig)
	check(ok, "a run through every activity blends without a non-finite pose")
	avatar.free()


func _test_run_fits_visual_size() -> void:
	var vis: Vector3 = tuning.visual_size
	var avatar := PlayerAvatar.new()
	avatar.fit_to(vis)
	_drive(avatar, _state(), 30, "run warm-up")
	var tops: Array[float] = []
	var box := AABB()
	var s: Dictionary = _state({"distance": 50.0})
	for i: int in 120:
		s["distance"] = float(s["distance"]) + RUN_SPEED * DT
		avatar.animate(s, DT)
		var b: AABB = avatar.rig.bounds()
		tops.append(b.end.y)
		box = b if i == 0 else box.merge(b)
	var mean: float = 0.0
	for top: float in tops:
		mean += top / tops.size()
	check(absf(mean - vis.y) <= vis.y * 0.03,
		"run pose: helmet top averages %.3f m over the stride (visual_size.y %.2f ±3%%)" % [mean, vis.y])
	check(box.end.y <= vis.y * 1.04, "run pose: never taller than visual_size.y + 4%% (%.3f m)" % box.end.y)
	check(box.position.y > -0.01 and box.position.y < 0.01, "run pose: feet reach the ground (%.3f m)" % box.position.y)
	check(box.size.x <= vis.x * 1.02 and box.size.x >= vis.x * 0.75,
		"run pose: %.3f m wide (visual_size.x %.2f)" % [box.size.x, vis.x])
	# The stride reaches further than the grey box's depth; it only has to stay a plausible stride.
	check(box.size.z <= vis.z * 2.0, "run pose: stride spans %.2f m front to back" % box.size.z)
	avatar.free()


func _test_pose_heights() -> void:
	var vis: Vector3 = tuning.visual_size
	var avatar := PlayerAvatar.new()
	avatar.fit_to(vis)
	var slide: AABB = _drive(avatar, _state({"sliding": true}), 30, "slide")
	check(slide.end.y < tuning.fence_gapped_bottom - 0.1,
		"slide: top %.2f m, clearly under a gapped fence (%.2f m)" % [slide.end.y, tuning.fence_gapped_bottom])
	avatar.reset()
	_drive(avatar, _state({"alive": false}), 60, "death")
	var dead: AABB = avatar.rig.bounds()
	check(dead.end.y < vis.y * 0.45, "death: collapsed to %.2f m" % dead.end.y)
	avatar.reset()
	var idle: AABB = _drive(avatar, _state({"speed": 0.0}), 30, "idle")
	check(idle.end.y > vis.y and idle.end.y < vis.y * 1.06, "idle: stands a little taller than it runs (%.2f m)" % idle.end.y)
	avatar.free()


## Up to max_cadence × stride_length (about 6 m/s) the planted foot stays put on the ground; faster,
## the cadence is capped for readability and the feet slide by design.
func _test_no_skating_at_jog() -> void:
	var avatar := PlayerAvatar.new()
	var dt: float = 1.0 / 240.0
	for speed: float in [2.0, 5.0]:
		avatar.reset()
		var s: Dictionary = _state({"speed": speed})
		var zs: Array[float] = []
		var windows: int = 0
		var worst: float = 0.0
		for i: int in 960:
			s["distance"] = float(s["distance"]) + speed * dt
			avatar.animate(s, dt)
			var ph: float = avatar.rig.phase()
			# The flat-footed middle of the left foot's stance (the heel-to-toe roll at either end
			# moves the ankle while the contact point stays put).
			if i > 60 and absf(ph - HumanoidPoses.GAIT_MID_STANCE) < 0.07:
				zs.append(_joint_z(avatar, &"foot_l") - float(s["distance"]))
			elif not zs.is_empty():
				if zs.size() >= 4:
					worst = maxf(worst, zs.max() - zs.min())
					windows += 1
				zs.clear()
		check(windows >= 2 and worst < 0.035,
			"at %.0f m/s the planted foot stays put (drifts %.3f m over %d stances)" % [speed, worst, windows])
	avatar.free()


func _test_budget() -> void:
	var avatar := PlayerAvatar.new()
	var tris: int = avatar.triangle_count()
	var calls: int = avatar.draw_call_count()
	check(tris <= TRIANGLE_BUDGET, "suit: %d triangles (budget %d)" % [tris, TRIANGLE_BUDGET])
	check(calls <= DRAW_CALL_BUDGET, "suit: %d draw calls (one per segment)" % calls)
	avatar.set_equipment({"claws": true, "armor": true, "shield": true, "weapon_tier": 4, "magnet": true})
	tris = avatar.triangle_count()
	calls = avatar.draw_call_count()
	check(tris <= TRIANGLE_BUDGET, "suit with every item: %d triangles (budget %d)" % [tris, TRIANGLE_BUDGET])
	check(calls <= DRAW_CALL_BUDGET, "suit with every item: %d draw calls (equipment merges into the segments)" % calls)
	avatar.free()


func _test_equipment() -> void:
	var avatar := PlayerAvatar.new()
	var hand := avatar.rig.joint(&"hand_r").get_node("Part") as MeshInstance3D
	var bare: int = int(hand.mesh.get_meta(&"triangles"))
	avatar.set_equipment({"claws": true})
	check(avatar.rig.attachments() == [&"claws"] and int(hand.mesh.get_meta(&"triangles")) > bare,
		"claws: blades appear on the gloves")
	avatar.set_equipment({"armor": true})
	check(avatar.rig.attachments().has(&"claws") and avatar.rig.attachments().has(&"armor"),
		"set_equipment keeps the items it isn't given")
	for tier: int in [1, 2, 3, 4]:
		avatar.set_equipment({"weapon_tier": tier})
		check(avatar.rig.attachments().has(StringName("weapon_%d" % tier)) and avatar.rig.attachments().size() == 3,
			"weapon tier %d: its emitter only" % tier)
	avatar.set_equipment({"weapon_tier": 0})
	check(avatar.rig.attachments().size() == 2, "weapon tier 0: no emitter")
	var calls: int = avatar.draw_call_count()
	avatar.set_equipment({"shield": true})
	var shield := avatar.get_node("Shield") as MeshInstance3D
	check(shield.visible and avatar.draw_call_count() == calls + 1, "shield: a bubble appears (one extra draw call)")
	avatar.set_equipment({"magnet": true})
	check(avatar.rig.attachments().has(&"magnet"), "magnet: a coil appears")
	avatar.set_equipment({"claws": false, "armor": false, "shield": false, "magnet": false})
	check(avatar.rig.attachments().is_empty() and not shield.visible and int(hand.mesh.get_meta(&"triangles")) == bare,
		"switching everything off restores the plain suit")
	check(avatar.get_equipment() == {"claws": false, "armor": false, "shield": false, "weapon_tier": 0, "magnet": false},
		"get_equipment reports the current items")
	avatar.free()


func _test_fit_follows_retune() -> void:
	var vis: Vector3 = tuning.visual_size
	var avatar := PlayerAvatar.new()
	for size: Vector3 in [vis * 1.25, Vector3(vis.x, vis.y * 0.8, vis.z)]:
		avatar.fit_to(size)
		avatar.reset()
		_drive(avatar, _state(), 30, "run at %s" % size)
		var mean: float = 0.0
		var s: Dictionary = _state({"distance": 20.0})
		for i: int in 60:
			s["distance"] = float(s["distance"]) + RUN_SPEED * DT
			avatar.animate(s, DT)
			mean += avatar.rig.bounds().end.y / 60.0
		check(absf(mean - size.y) <= size.y * 0.03, "fit_to(%s): the run pose follows (top %.3f m)" % [size, mean])
	avatar.free()


func _test_flash_death_and_reset() -> void:
	var avatar := PlayerAvatar.new()
	var material := avatar.rig.material as ShaderMaterial
	avatar.animate(_state(), DT)
	avatar.set_flash(true)
	var on: Color = material.get_shader_parameter(&"tint")
	avatar.set_flash(false)
	var off: Color = material.get_shader_parameter(&"tint")
	check(on.a > 0.3 and off.a == 0.0, "set_flash tints the suit on and off")
	_drive(avatar, _state({"alive": false}), 60, "death glow")
	var dead_glow: float = material.get_shader_parameter(&"glow_boost")
	check(dead_glow < 0.5, "death powers the suit's glow down (%.2f)" % dead_glow)
	avatar.reset()
	avatar.animate(_state(), DT)
	var tint: Color = material.get_shader_parameter(&"tint")
	check(avatar.rig.activity == Activity.RUN and avatar.rig.weight(Activity.RUN) == 1.0 and tint.a == 0.0
		and float(material.get_shader_parameter(&"glow_boost")) == 1.0,
		"reset() snaps back to a clean run")
	avatar.free()


func _test_cost() -> void:
	var avatar := PlayerAvatar.new()
	var s: Dictionary = _state()
	var start: int = Time.get_ticks_usec()
	for i: int in 600:
		s["distance"] = float(s["distance"]) + RUN_SPEED * DT
		avatar.animate(s, DT)
	var per_call: float = (Time.get_ticks_usec() - start) / 600.0
	check(per_call < 500.0, "animate() costs %.0f µs per frame" % per_call)
	avatar.free()


## Nobody calls animate() after death (the Player stops updating): the collapse carries on alone.
func _test_self_drive() -> void:
	var avatar := PlayerAvatar.new()
	tree.root.add_child(avatar)
	avatar.animate(_state(), DT)
	avatar.animate(_state({"alive": false, "distance": 0.3}), DT)
	await physics_frames(60)
	check(avatar.rig.activity == Activity.DEAD and avatar.rig.weight(Activity.DEAD) > 0.95
		and avatar.rig.bounds().end.y < 0.6, "the collapse finishes after the driver stops")
	avatar.reset()
	avatar.animate(_state(), DT)
	await physics_frames(60)
	check(avatar.rig.activity == Activity.IDLE, "a runner nobody drives settles into idle")
	avatar.queue_free()
	await tree.process_frame


## A real Player on real physics drives its avatar through the moves; gameplay is unchanged.
func _test_in_player() -> void:
	var world := Node3D.new()
	tree.root.add_child(world)
	var layout := RunSim.layout(3, 400.0)
	layout.fences.append(RunSim.fence(1, 40.0, "gapped"))
	layout.gaps.append({"lane": 1, "start": 80.0, "end": 86.0})
	layout.gaps.append({"lane": 2, "start": 190.0, "end": 200.0})
	var track := TrackBuilder.new()
	world.add_child(track)
	track.set_layout(layout, tuning)
	track.update(0.0, 0.0)
	var player := Player.new()
	world.add_child(player)
	player.setup(tuning, TrackGeometry.new(3, tuning), 1)
	var avatar: PlayerAvatar = _find_avatar(player)
	check(avatar != null and avatar.get_parent() != player, "the Player shows a PlayerAvatar under its pivot")
	if avatar == null:
		world.queue_free()
		await tree.process_frame
		return
	await tree.physics_frame
	player.running = true
	var pending: Array = [[34.0, &"slide"], [76.0, &"jump"], [100.0, &"move_right"], [104.0, &"move_right"]]
	var seen: Dictionary = {}
	var slide_top: float = 0.0
	var finite: bool = true
	for i: int in 900:
		while not pending.is_empty() and player.distance >= float(pending[0][0]):
			player.press(pending.pop_front()[1])
		track.update(player.distance, player.elapsed)
		await tree.physics_frame
		if not player.alive:
			break
		seen[avatar.rig.activity] = true
		finite = finite and _joints_finite(avatar.rig)
		if absf(player.distance - 40.0) < 0.6:  # Passing under the gapped fence.
			slide_top = maxf(slide_top, avatar.rig.bounds().end.y)
	check(finite, "in play: every frame gives a finite pose")
	for a: Activity in [Activity.RUN, Activity.SLIDE, Activity.AIR, Activity.WALL]:
		check(seen.has(a), "in play: the avatar shows %s" % Activity.keys()[a])
	check(slide_top > 0.0 and slide_top < tuning.fence_gapped_bottom - 0.1,
		"in play: passing under the gapped fence, the sliding avatar is clearly below it (%.2f m)" % slide_top)
	check(not player.alive and player.last_event == "died: fell", "in play: the run ends in the gap (%s)" % player.last_event)
	await physics_frames(60)
	check(avatar.rig.activity == Activity.DEAD and avatar.rig.weight(Activity.DEAD) > 0.95,
		"in play: after death the avatar collapses on its own")
	world.queue_free()
	await tree.process_frame
