extends TestSuite
## The cyborgs' body on the shared HumanoidRig (GDD §9.2: one shared body and skeleton with
## swappable parts per zone): it uses the rig with CyborgSuit's parts and one zone attachment set;
## draw calls stay within budget; the hitboxes stay inside the visuals; the poses, faces, charge glow
## and deaths work; and building cyborgs leaves the player's avatar untouched.

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
## Draw calls: a whole cyborg (was 13, 14 while charging, before the rig) and a window cyborg's upper body.
const FULL_BODY_CALLS: int = 11
const UPPER_BODY_CALLS: int = 7

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var avatar := PlayerAvatar.new()
	tree.root.add_child(avatar)
	var avatar_meshes: Array[Mesh] = _meshes(avatar.rig)
	var avatar_calls: int = avatar.draw_call_count()
	await _test_rig_and_budget()
	await _test_hitboxes_inside()
	await _test_poses()
	await _test_faces_and_charge()
	await _test_deaths()
	check(_meshes(avatar.rig) == avatar_meshes and avatar.draw_call_count() == avatar_calls,
		"building cyborgs on the shared rig leaves the player's avatar as it was")
	avatar.queue_free()
	await tree.process_frame


func _body(v: StringName, host: bool = false, upper: bool = false) -> CyborgBody:
	var b := CyborgBody.new()
	tree.root.add_child(b)
	b.build(v, host, upper, 5)
	return b


func _meshes(rig: HumanoidRig) -> Array[Mesh]:
	var out: Array[Mesh] = []
	for m: MeshInstance3D in rig.part_instances():
		out.append(m.mesh)
	return out


## The visible meshes' exact bounds (every vertex) in `space`'s local coordinates, leaving out the
## charge orb, which the shader shrinks to nothing while the cannon isn't charging.
func _visual_bounds(b: CyborgBody, space: Node3D) -> AABB:
	var to_space: Transform3D = space.global_transform.affine_inverse()
	var out := AABB()
	var first: bool = true
	for m: MeshInstance3D in b.rig.part_instances():
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var xf: Transform3D = to_space * m.global_transform
		for s: int in m.mesh.get_surface_count():
			var arrays: Array = m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			for i: int in verts.size():
				if uvs[i].x > CyborgSuit.ORB - 0.5:
					continue
				var p: Vector3 = xf * verts[i]
				out = AABB(p, Vector3.ZERO) if first else out.expand(p)
				first = false
	return out


func _test_rig_and_budget() -> void:
	for v: StringName in CyborgSuit.VARIANTS:
		var b := _body(v)
		check(b.rig is HumanoidRig and b.rig.parts == CyborgSuit.parts(), "%s: the body is the shared HumanoidRig with the cyborg parts" % v)
		check(b.rig.attachments() == [v], "%s: the zone look is an attachment set on the shared skeleton" % v)
		check(b.draw_call_count() == FULL_BODY_CALLS, "%s: a whole cyborg is %d draw calls (%d)" % [v, FULL_BODY_CALLS, b.draw_call_count()])
		b.set_charge(1.0)
		b.set_pose(CyborgBody.Pose.AIM)
		b.aim_at(b.global_position + Vector3(0.5, 1.0, 8.0))
		await physics_frames(3)
		check(b.draw_call_count() == FULL_BODY_CALLS, "%s: charging and aiming cost no extra draw calls" % v)
		b.queue_free()
		var u := _body(v, false, true)
		check(u.draw_call_count() == UPPER_BODY_CALLS, "%s: a window cyborg's upper body is %d draw calls (%d)" % [v, UPPER_BODY_CALLS, u.draw_call_count()])
		u.queue_free()
	var host := _body(&"city", true)
	check(host.draw_call_count() == FULL_BODY_CALLS, "a host costs the same (its glitch is in the material)")
	host.queue_free()
	await tree.process_frame


## The solid body (what a running player meets) sits inside the visible body, and the stomp zone
## tops out within it; the window cyborg's band sits inside its visible upper body. The allowances
## match the body before the rig (measured the same way): the soles may float a few millimetres
## over the floor; the scavenger's hunched back breathes in and out across the body box's back face
## by about 2 cm (a running player meets the front, which stands well clear of the box, and the
## sides); and the band runs back to the wall face, 4 cm behind the cyborg's back, where the window
## frame is.
func _test_hitboxes_inside() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(5, 400.0))
	for v: StringName in CyborgSuit.VARIANTS:
		var skin := w.skin.duplicate() as ZoneSkin
		skin.enemy_variant = v
		w.skin = skin
		var c := w.director.spawn({"type": "cyborg", "at": 60.0, "lane": 2, "seed": 3,
			"params": {"panic": false, "fires": false}}) as Cyborg
		var wc := w.director.spawn({"type": "window_cyborg", "at": 80.0, "lane": 4, "side": 1, "seed": 4,
			"params": {"fires": false}}) as WindowCyborg
		await physics_frames(2)
		var vis: AABB = _visual_bounds(c.body, c)
		var half: Vector3 = Cyborg.BODY_SIZE * 0.5
		var body_box := AABB(Vector3(-half.x, 0.0, -half.z), Cyborg.BODY_SIZE)
		var body_must := AABB(body_box.position + Vector3(0.0, 0.01, 0.03), body_box.size - Vector3(0.0, 0.01, 0.03))
		check(vis.encloses(body_must), "%s: the solid body hitbox %s is inside the visible body %s" % [v, str(body_box), str(vis)])
		check(vis.end.z >= body_box.end.z + 0.08, "%s: the visible body stands well in front of the hitbox's front face (%.2f > %.2f)"
			% [v, vis.end.z, body_box.end.z])
		var head_top: float = Cyborg.HEAD_Y + Cyborg.HEAD_SIZE.y * 0.5
		check(head_top <= vis.end.y + 0.001, "%s: the stomp zone tops out within the head (%.2f ≤ %.2f)" % [v, head_top, vis.end.y])
		var wvis: AABB = _visual_bounds(wc.body, wc)
		var band := AABB(Vector3(-wc.tuning.reach, wc.band_bottom, -wc.tuning.hitbox_length * 0.5),
			Vector3(wc.tuning.reach, wc.band_top - wc.band_bottom, wc.tuning.hitbox_length))
		var band_must := AABB(band.position, band.size - Vector3(0.05, 0.0, 0.0))
		check(wvis.encloses(band_must), "%s: the window cyborg's band %s is inside its visible body %s" % [v, str(band), str(wvis)])
		c.retire()
		wc.retire()
		await physics_frames(1)
	await sim.free_world(w)


func _test_poses() -> void:
	var b := _body(&"city")
	var head: Node3D = b.rig.joint(&"head")
	var idle_head: Vector3 = b.to_local(head.global_position)
	var face_dir: Vector3 = b.global_basis.inverse() * (head.global_basis * Vector3.FORWARD)
	check(face_dir.z > 0.9, "standing, the cyborg faces +z, toward the player")
	check(absf(idle_head.y - 1.24) < 0.08, "the head sits at the cyborg's height (%.2f m)" % idle_head.y)
	# Walking swings the legs with the speed.
	b.set_pose(CyborgBody.Pose.WALK)
	b.set_move_speed(1.4)
	var thigh: Node3D = b.rig.joint(&"thigh_l")
	var angles: Array[float] = []
	for i: int in 30:
		await tree.process_frame
		angles.append(thigh.rotation.x)
	check(angles.max() - angles.min() > 0.25, "walking swings the legs (%.2f rad)" % (angles.max() - angles.min()))
	# Aiming points the cannon straight at the target.
	b.set_pose(CyborgBody.Pose.AIM)
	var target: Vector3 = b.global_position + Vector3(1.5, 0.6, 9.0)
	b.aim_at(target)
	for i: int in 40:
		await tree.process_frame
	var elbow: Vector3 = b.rig.joint(&"forearm_r").global_position
	var angle: float = rad_to_deg((b.muzzle_position() - elbow).angle_to(target - elbow))
	check(angle < 8.0, "the arm cannon points at its target (%.1f°)" % angle)
	b.clear_aim()
	# The panic sprint twists the head right round to watch the player behind.
	b.set_pose(CyborgBody.Pose.RUN_AWAY)
	b.set_move_speed(8.5)
	for i: int in 40:
		await tree.process_frame
	face_dir = b.global_basis.inverse() * (head.global_basis * Vector3.FORWARD)
	check(face_dir.z < -0.5, "running away, the head turns back over the shoulder (%.2f)" % face_dir.z)
	# Cowering crouches low.
	b.set_pose(CyborgBody.Pose.COWER)
	for i: int in 40:
		await tree.process_frame
	check(b.to_local(head.global_position).y < idle_head.y - 0.35, "cowering crouches low (head at %.2f m)" % b.to_local(head.global_position).y)
	var soles: float = b.rig.bounds().position.y
	check(absf(soles) < 0.03, "every pose keeps the feet on the ground (%.3f)" % soles)
	b.queue_free()
	# A window cyborg's legs are hidden.
	var u := _body(&"city", false, true)
	var parts: Array[MeshInstance3D] = u.rig.part_instances()
	check(not parts[HumanoidPose.THIGH_L].visible and not parts[HumanoidPose.SHIN_R].visible and parts[HumanoidPose.CHEST].visible,
		"a window cyborg shows only its upper body")
	u.queue_free()
	await tree.process_frame


func _test_faces_and_charge() -> void:
	var city := _body(&"city")
	var scav := _body(&"scavenger")
	var host := _body(&"city", true)
	for f: Kit.Face in [Kit.Face.AIMING, Kit.Face.SHOCKED, Kit.Face.DEAD, Kit.Face.NEUTRAL]:
		city.set_expression(f)
		check(city.material.get_shader_parameter(&"face") == Kit.face_texture(f), "the LED face shows expression %d" % f)
	check(float(host.material.get_shader_parameter(&"glitch")) == 1.0 and float(city.material.get_shader_parameter(&"glitch")) == 0.0,
		"a host's visor glitches purple, a plain cyborg's doesn't")
	check(float(scav.material.get_shader_parameter(&"crack")) == 1.0 and float(scav.material.get_shader_parameter(&"flicker")) > 0.0
		and float(city.material.get_shader_parameter(&"crack")) == 0.0, "the scavenger's visor is cracked and flickers")
	check(city.material != scav.material and city.material != host.material, "each cyborg has its own material")
	city.set_charge(0.7)
	check(is_equal_approx(float(city.material.get_shader_parameter(&"charge")), 0.7), "the charge glow follows set_charge")
	# The screen, emitter ring and charge orb are marked pieces inside the segment meshes.
	var parts: Array[MeshInstance3D] = city.rig.part_instances()
	check(_has_glow(parts[HumanoidPose.HEAD].mesh, CyborgSuit.SCREEN), "the LED screen is part of the head mesh")
	check(_has_glow(parts[HumanoidPose.FOREARM_R].mesh, CyborgSuit.ORB) and _has_glow(parts[HumanoidPose.FOREARM_R].mesh, CyborgSuit.RING),
		"the emitter ring and charge orb are part of the cannon forearm")
	check(not _has_glow(parts[HumanoidPose.FOREARM_L].mesh, CyborgSuit.ORB), "only the right arm is a cannon")
	var elbow: Vector3 = city.rig.joint(&"forearm_r").global_position
	check(absf(elbow.distance_to(city.muzzle_position()) - 0.43) < 0.01, "the muzzle is at the cannon's tip")
	for b: CyborgBody in [city, scav, host]:
		b.queue_free()
	await tree.process_frame


func _has_glow(mesh: Mesh, glow: float) -> bool:
	if mesh == null:
		return false
	for uv: Vector2 in mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
		if absf(uv.x - glow) < 0.01:
			return true
	return false


func _test_deaths() -> void:
	for cause: StringName in [&"stomp", &"weapon", &"claws"]:
		var b := _body(&"city")
		var done: Array[bool] = [false]
		b.death_finished.connect(func() -> void: done[0] = true)
		b.die(cause)
		check(b.face == Kit.Face.DEAD and float(b.material.get_shader_parameter(&"glow_boost")) == 0.0,
			"%s: a dead cyborg shows X eyes and its trim goes dark" % cause)
		for i: int in 60:
			await tree.process_frame
			if done[0]:
				break
		check(done[0], "%s: the death animation finishes" % cause)
		b.queue_free()
	var u := _body(&"city", false, true)
	var chest: Node3D = u.rig.joint(&"chest")
	var before_up: Vector3 = u.global_basis.inverse() * (chest.global_basis * Vector3.UP)
	u.die(&"weapon")
	for i: int in 40:
		await tree.process_frame
	var after_up: Vector3 = u.global_basis.inverse() * (chest.global_basis * Vector3.UP)
	check(after_up.z > before_up.z + 0.4, "a window cyborg slumps forward over the sill (%.2f → %.2f)" % [before_up.z, after_up.z])
	u.queue_free()
	await tree.process_frame
