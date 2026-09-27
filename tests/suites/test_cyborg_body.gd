extends TestSuite
## The cyborgs' body on the shared HumanoidRig (GDD §9.2: one shared body and skeleton with
## swappable parts per zone), in the ragged screen-head base look (task P2): it uses the rig with
## CyborgSuit's parts and one look's attachment set (every skin's enemy_variant wears the base until
## the zone variants exist); draw calls and triangles stay within budget; the hitboxes are exactly
## what they were before the new look and stay inside the visuals; the colour rules hold (only the
## cold white face, the red charge-up and a host's purple glow; nothing copper, no hazard colours,
## purple only on hosts); the faces keep their shapes far away; a defeated cyborg's screen shows ERR,
## then goes dark; the posture is hunched, twitchy and shambling; Settings > Reduced flashing calms
## the host's glitch, the hit flash and the screen; and building cyborgs leaves the player's avatar
## untouched.

const Kit = preload("res://scripts/enemies/cyborg_kit.gd")
const Poses = preload("res://scripts/enemies/cyborg_poses.gd")
const SHADER_PATH: String = "res://scripts/enemies/cyborg_body.gdshader"
## Draw calls: a whole cyborg (was 13, 14 while charging, before the rig) and a window cyborg's upper body.
const FULL_BODY_CALLS: int = 11
const UPPER_BODY_CALLS: int = 7
## Triangles: a whole cyborg (a host's veins included) and a window cyborg's upper body. Several are on
## screen at once on a phone.
const FULL_BODY_TRIANGLES: int = 2400
const UPPER_BODY_TRIANGLES: int = 2000
## The skins' enemy variants in use (they pick the other enemies' weathering); every one must dress
## the cyborgs.
const SKIN_VARIANTS: Array[StringName] = [&"city", &"scavenger"]
## The hitboxes as they were before the new look (task P2 changes looks only): the solid body, the
## stompable head and shoulders, and the window cyborg's body band.
const BODY_BOX := Vector3(0.4, 1.0, 0.28)
const BODY_AT := Vector3(0.0, 0.5, 0.0)
const HEAD_BOX := Vector3(0.7, 0.38, 0.6)
const HEAD_AT := Vector3(0.0, 1.31, 0.0)
## Colours: hazard colours keep this far away on the hue and saturation wheel (test_avatar's measure).
const MIN_HAZARD_DISTANCE: float = 0.3
## Clothing and metal are dull: no piece more saturated or brighter than these.
const MAX_SATURATION: float = 0.6
const MAX_VALUE: float = 0.62
## 14 m ahead of the player at 720p the screen is about this many pixels.
const FAR_PIXELS := Vector2i(7, 5)

var sim: RunSim


func run() -> void:
	sim = RunSim.new(tree, tuning)
	var avatar := PlayerAvatar.new()
	tree.root.add_child(avatar)
	var avatar_meshes: Array[Mesh] = _meshes(avatar.rig)
	var avatar_calls: int = avatar.draw_call_count()
	await _test_rig_and_budget()
	await _test_hitboxes_pinned()
	await _test_hitboxes_inside()
	_test_look()
	_test_colours()
	await _test_poses()
	await _test_posture()
	await _test_faces_and_charge()
	_test_far_faces()
	await _test_deaths()
	await _test_reduced_flashing()
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
				if absf(uvs[i].x - CyborgSuit.ORB) < 0.5:
					continue
				var p: Vector3 = xf * verts[i]
				out = AABB(p, Vector3.ZERO) if first else out.expand(p)
				first = false
	return out


## Every piece of the parts: the shared ones and each attachment set's, by set name ("" = shared).
static func _pieces() -> Dictionary:
	var parts: HumanoidParts = CyborgSuit.parts()
	var out: Dictionary = {"": parts.pieces}
	for set_name: StringName in parts.attachments:
		out[String(set_name)] = parts.attachments[set_name]
	return out


func _test_rig_and_budget() -> void:
	var names: Array[StringName] = CyborgSuit.LOOKS.duplicate()
	names.append_array(SKIN_VARIANTS)
	for v: StringName in names:
		var b := _body(v)
		check(b.rig is HumanoidRig and b.rig.parts == CyborgSuit.parts(), "%s: the body is the shared HumanoidRig with the cyborg parts" % v)
		check(b.look == CyborgSuit.look_for(v) and b.rig.attachments() == [b.look],
			"%s: the look (%s) is an attachment set on the shared skeleton" % [v, b.look])
		check(b.draw_call_count() == FULL_BODY_CALLS, "%s: a whole cyborg is %d draw calls (%d)" % [v, FULL_BODY_CALLS, b.draw_call_count()])
		check(b.rig.triangle_count() <= FULL_BODY_TRIANGLES,
			"%s: a whole cyborg is %d triangles (budget %d)" % [v, b.rig.triangle_count(), FULL_BODY_TRIANGLES])
		b.set_charge(1.0)
		b.set_pose(CyborgBody.Pose.AIM)
		b.aim_at(b.global_position + Vector3(0.5, 1.0, 8.0))
		await physics_frames(3)
		check(b.draw_call_count() == FULL_BODY_CALLS, "%s: charging and aiming cost no extra draw calls" % v)
		b.queue_free()
		var u := _body(v, false, true)
		check(u.draw_call_count() == UPPER_BODY_CALLS, "%s: a window cyborg's upper body is %d draw calls (%d)" % [v, UPPER_BODY_CALLS, u.draw_call_count()])
		check(u.rig.triangle_count() <= UPPER_BODY_TRIANGLES,
			"%s: a window cyborg's upper body is %d triangles (budget %d)" % [v, u.rig.triangle_count(), UPPER_BODY_TRIANGLES])
		u.queue_free()
	var host := _body(&"city", true)
	check(host.draw_call_count() == FULL_BODY_CALLS, "a host costs the same draw calls (its veins ride in the segment meshes)")
	check(host.rig.attachments() == [CyborgSuit.BASE, CyborgSuit.HOST_SET], "a host wears the veins over its look")
	check(host.rig.triangle_count() <= FULL_BODY_TRIANGLES,
		"a host is %d triangles (budget %d)" % [host.rig.triangle_count(), FULL_BODY_TRIANGLES])
	host.queue_free()
	await tree.process_frame


## The looks change nothing in play (task P2): the hitboxes are exactly what they were.
func _test_hitboxes_pinned() -> void:
	check(Cyborg.BODY_SIZE == BODY_BOX and Cyborg.HEAD_SIZE == HEAD_BOX and is_equal_approx(Cyborg.HEAD_Y, HEAD_AT.y),
		"the cyborg's hitbox sizes are unchanged")
	var w: RunWorld = sim.build_world(RunSim.layout(5, 400.0))
	var wt := load("res://data/enemies/window_cyborg.tres") as WindowCyborgTuning
	for v: StringName in SKIN_VARIANTS:
		var skin := w.skin.duplicate() as ZoneSkin
		skin.enemy_variant = v
		w.skin = skin
		for host: bool in [false, true]:
			var c := w.director.spawn({"type": "cyborg", "at": 60.0, "lane": 2, "seed": 3,
				"params": {"panic": false, "fires": false, "host": host}}) as Cyborg
			var boxes: Dictionary = _hitboxes(c)
			check(boxes.size() == 2 and boxes.has(&"body") and boxes.has(&"top"),
				"%s%s: a cyborg has exactly its body and stomp hitboxes (%s)" % [v, " host" if host else "", str(boxes.keys())])
			if boxes.has(&"body") and boxes.has(&"top"):
				check(boxes[&"body"][0] == BODY_BOX and (boxes[&"body"][1] as Vector3).is_equal_approx(BODY_AT),
					"%s: the solid body is %s at %s" % [v, str(boxes[&"body"][0]), str(boxes[&"body"][1])])
				check(boxes[&"top"][0] == HEAD_BOX and (boxes[&"top"][1] as Vector3).is_equal_approx(HEAD_AT),
					"%s: the stomp zone is %s at %s" % [v, str(boxes[&"top"][0]), str(boxes[&"top"][1])])
			c.retire()
		for side: int in [-1, 1]:
			var wc := w.director.spawn({"type": "window_cyborg", "at": 80.0, "lane": 4 if side > 0 else 0,
				"side": side, "seed": 4, "params": {"fires": false}}) as WindowCyborg
			var boxes: Dictionary = _hitboxes(wc)
			var size := Vector3(wt.reach, wt.band_height, wt.hitbox_length)
			var at := Vector3(-side * wt.reach * 0.5, tuning.wall_entry_height + wt.band_offset, 0.0)
			check(boxes.size() == 1 and boxes.has(&"body") and boxes[&"body"][0] == size
				and (boxes[&"body"][1] as Vector3).is_equal_approx(at),
				"%s side %d: a window cyborg's body band is %s at %s" % [v, side, str(size), str(at)])
			wc.retire()
		await physics_frames(1)
	await sim.free_world(w)


## Each hitbox of an enemy by part: [box size, position in the enemy's space].
static func _hitboxes(e: Enemy) -> Dictionary:
	var out: Dictionary = {}
	for child: Node in e.get_children():
		var hazard := child as Hazard
		if hazard == null:
			continue
		var shape := hazard.get_child(0) as CollisionShape3D
		var box := shape.shape as BoxShape3D if shape != null else null
		out[hazard.part] = [box.size if box != null else Vector3.ZERO, hazard.position]
	return out


## The solid body (what a running player meets) sits inside the visible body, and the stomp zone
## tops out within it; the window cyborg's band sits inside its visible upper body. The allowances
## match the body before the rig (measured the same way): the soles may float a few millimetres
## over the floor; the back may breathe in and out across the body box's back face by a couple of
## centimetres (a running player meets the front, which stands well clear of the box, and the
## sides); and the band runs back to the wall face, 4 cm behind the cyborg's back, where the window
## frame is.
func _test_hitboxes_inside() -> void:
	var w: RunWorld = sim.build_world(RunSim.layout(5, 400.0))
	for v: StringName in SKIN_VARIANTS:
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
		check(head_top <= vis.end.y + 0.001, "%s: the stomp zone tops out within the screen head (%.2f ≤ %.2f)" % [v, head_top, vis.end.y])
		var wvis: AABB = _visual_bounds(wc.body, wc)
		var band := AABB(Vector3(-wc.tuning.reach, wc.band_bottom, -wc.tuning.hitbox_length * 0.5),
			Vector3(wc.tuning.reach, wc.band_top - wc.band_bottom, wc.tuning.hitbox_length))
		var band_must := AABB(band.position, band.size - Vector3(0.05, 0.0, 0.0))
		check(wvis.encloses(band_must), "%s: the window cyborg's band %s is inside its visible body %s" % [v, str(band), str(wvis)])
		c.retire()
		wc.retire()
		await physics_frames(1)
	await sim.free_world(w)


## The base look (GDD §9.2, Variant 1): the whole head is a TV (a boxy casing wider than the neck by
## far, its screen the face), the backpack, cables into the head, the cannon arm on the right; a host
## wears veins; every skin variant picks a look.
func _test_look() -> void:
	check(CyborgSuit.LOOKS.has(CyborgSuit.BASE), "the base is a look")
	for v: StringName in SKIN_VARIANTS:
		check(CyborgSuit.look_for(v) == CyborgSuit.BASE, "the %s skins' cyborgs wear the base" % v)
	check(CyborgSuit.look_for(&"no_such_variant") == CyborgSuit.BASE, "an unknown variant wears the base")
	check(CyborgSuit.attachment_sets(CyborgSuit.BASE, true) == [CyborgSuit.BASE, CyborgSuit.HOST_SET],
		"a host's sets are its look and the veins")
	var parts: HumanoidParts = CyborgSuit.parts()
	var sets: Array[StringName] = [CyborgSuit.BASE]
	var head: ArrayMesh = parts.segment_mesh(&"head", 0, sets)
	var bounds: AABB = _mesh_bounds(head)
	check(bounds.size.x >= 0.38 and bounds.size.y >= 0.3 and bounds.size.z >= 0.25,
		"the whole head is a boxy TV (%s)" % str(bounds.size))
	check(CyborgSuit.SCREEN_SIZE.x >= 0.3 and CyborgSuit.SCREEN_SIZE.y >= 0.2
		and CyborgSuit.SCREEN_SIZE.x <= CyborgSuit.TV_SIZE.x and CyborgSuit.SCREEN_SIZE.y <= CyborgSuit.TV_SIZE.y,
		"its screen, the face, fills most of the front (%s)" % str(CyborgSuit.SCREEN_SIZE))
	var rect: Vector4 = CyborgSuit.screen_rect(CyborgSuit.BASE)
	check(absf((rect.z - rect.x) / (rect.w - rect.y) - float(Kit.FACE_GRID.x) / Kit.FACE_GRID.y) < 0.02,
		"the face's LEDs are square on the screen")
	var chest: ArrayMesh = parts.segment_mesh(&"chest", 0, sets)
	var cb: AABB = _mesh_bounds(chest)
	check(cb.end.z > 0.2, "a backpack sits on the back (the chest reaches %.2f m back)" % cb.end.z)
	# The cables and the hose belong to the chest and end inside the part they plug into, near its
	# joint, so they stay plugged in as the head and the arm turn: the cables inside the TV's tube
	# (within 0.12 m of the head joint across, between its bottom and top), the hose inside the shoulder
	# cap (within 0.04 m of the shoulder joint).
	var head_joint := Vector3(0.0, parts.neck_offset.y + parts.head_offset.y, 0.0)
	check(CyborgSuit.HEAD_CABLES.size() >= 2, "cables run from the backpack up into the screen head")
	for cable: Array in CyborgSuit.HEAD_CABLES:
		var d: Vector3 = (cable[cable.size() - 1] as Vector3) - head_joint
		var start: Vector3 = cable[0]
		check(Vector2(d.x, d.z).length() <= 0.12 and d.y > 0.03 and d.y < CyborgSuit.TV_SIZE.y - 0.05 and start.z > 0.15,
			"a cable runs from the backpack (%s) into the TV near the head joint (%s from it)" % [str(start), str(d)])
	var hose_end: Vector3 = CyborgSuit.ARM_HOSE[CyborgSuit.ARM_HOSE.size() - 1]
	var shoulder := Vector3(parts.shoulder_offset.x, parts.shoulder_offset.y, 0.0)
	check(hose_end.distance_to(shoulder) < 0.04, "the hose runs into the cyber arm's shoulder cap (%.3f m from the joint)"
		% hose_end.distance_to(shoulder))
	# The cannon arm is the right one, and only the host set has veins.
	var fore_r: ArrayMesh = parts.segment_mesh(&"forearm", 1, sets)
	var fore_l: ArrayMesh = parts.segment_mesh(&"forearm", -1, sets)
	check(_has_glow(fore_r, CyborgSuit.ORB) and _has_glow(fore_r, CyborgSuit.RING) and not _has_glow(fore_l, CyborgSuit.ORB),
		"the right arm is the cannon")
	var host_sets: Array[StringName] = [CyborgSuit.BASE, CyborgSuit.HOST_SET]
	for seg: Array in [[&"chest", 0], [&"upper_arm", -1], [&"forearm", -1], [&"upper_arm", 1]]:
		check(_has_glow(parts.segment_mesh(seg[0], seg[1], host_sets), CyborgSuit.VEIN)
			and not _has_glow(parts.segment_mesh(seg[0], seg[1], sets), CyborgSuit.VEIN),
			"a host's %s %d carries veins, a plain cyborg's doesn't" % [seg[0], seg[1]])


## GDD §9.2's colour rules. The only glows are the marked pieces the shader draws: the screen (cold
## white), the cannon's ring and orb (enemy-fire red) and, on hosts only, the veins (purple). The
## cold white is the cult feed's, near-white, and far from the player's copper and every hazard and
## "safe" colour; the clothing and metal are dull, never purple, never a hazard colour.
func _test_colours() -> void:
	var hazards: Dictionary = _hazard_colors()
	check(hazards.size() >= 12, "the check covers every skin's hazard colours and the pads' cyan (%d)" % hazards.size())
	check(Kit.LED_COLOR == CultFeed.FEED_COLOR, "the faces glow the cult feed's own cold white")
	check(Kit.LED_COLOR.s < 0.2 and Kit.LED_COLOR.b > 0.9 and Kit.LED_COLOR.b >= Kit.LED_COLOR.r,
		"the face's white is cold and near-white (saturation %.2f)" % Kit.LED_COLOR.s)
	var nearest: float = INF
	for h: String in hazards:
		nearest = minf(nearest, _chroma_distance(Kit.LED_COLOR, hazards[h]))
	check(nearest >= MIN_HAZARD_DISTANCE, "the cold white keeps clear of every hazard colour (%.2f)" % nearest)
	check(_chroma_distance(Kit.LED_COLOR, PlayerSuit.GLOW) >= MIN_HAZARD_DISTANCE,
		"the cold white is nothing like the player's copper (%.2f)" % _chroma_distance(Kit.LED_COLOR, PlayerSuit.GLOW))
	check(_is_purple(Kit.GLITCH_COLOR), "a host's glitch is purple")
	var markers: Array[float] = [CyborgSuit.SCREEN, CyborgSuit.RING, CyborgSuit.ORB]
	var pieces: Dictionary = _pieces()
	for set_name: String in pieces:
		var wrong_glow: PackedStringArray = []
		var loud: PackedStringArray = []
		var purple: PackedStringArray = []
		var hazardous: PackedStringArray = []
		for piece: HumanoidPiece in pieces[set_name]:
			var tag: String = "%s %s" % [piece.segment, piece.color.to_html(false)]
			if set_name == String(CyborgSuit.HOST_SET):
				if piece.glow != CyborgSuit.VEIN or piece.color != Kit.GLITCH_COLOR:
					wrong_glow.append(tag)
				continue
			if piece.glow > 0.0:
				if not markers.has(piece.glow):
					wrong_glow.append(tag)
				continue
			if piece.color.s > MAX_SATURATION or piece.color.v > MAX_VALUE:
				loud.append(tag)
			if _is_purple(piece.color):
				purple.append(tag)
			for h: String in hazards:
				if _chroma_distance(piece.color, hazards[h]) < MIN_HAZARD_DISTANCE:
					hazardous.append("%s (%s)" % [tag, h])
		var what: String = "the %s set" % set_name if set_name != "" else "the shared pieces"
		if set_name == String(CyborgSuit.HOST_SET):
			check(wrong_glow.is_empty() and not (pieces[set_name] as Array).is_empty(),
				"%s: only purple veins (%s)" % [what, ", ".join(wrong_glow)])
			continue
		check(wrong_glow.is_empty(), "%s: nothing glows but the screen, ring and orb (%s)" % [what, ", ".join(wrong_glow)])
		check(loud.is_empty(), "%s: the clothing and metal are dull (%s)" % [what, ", ".join(loud)])
		check(purple.is_empty(), "%s: no purple (it means host) (%s)" % [what, ", ".join(purple)])
		check(hazardous.is_empty(), "%s: no hazard or safe colour (%s)" % [what, ", ".join(hazardous)])
	# The web renderer: vertex colours are shown right (they are linear), glows keep their hue.
	var code: String = FileAccess.get_file_as_string(SHADER_PATH)
	check(code.contains("humanoid_color.gdshaderinc") and code.contains("humanoid_base_color(COLOR.rgb)"),
		"the shader converts the linear vertex colours on the Compatibility renderer")
	check(code.contains("humanoid_glow(charge_color.rgb"), "the charge-up keeps its red on every renderer")
	check(Kit.PART_SHADER.contains("humanoid_base_color(COLOR.rgb)"), "so does the window frame's and generator's shader")


## Every hazard colour the game uses, by name, and the anti-grav pads' "safe" cyan (the saturated
## ones: black and grey carry no hue to confuse).
static func _hazard_colors() -> Dictionary:
	var out: Dictionary = {}
	for file: String in DirAccess.get_files_at("res://data/skins/"):
		if not file.ends_with(".tres"):
			continue
		var skin: Resource = load("res://data/skins/" + file)
		for property: String in ["gap_edge_color", "fence_color", "sign_color", "sign_frame_color", "ramp_color",
				"speed_pad_color", "pad_color"]:
			if property in skin:
				var c: Color = skin.get(property)
				if c.s > 0.4:
					out["%s %s" % [file.get_basename(), property.trim_suffix("_color")]] = c
	return out


## Distance between two colours on the HSV colour wheel (hue as the angle, saturation as the
## radius), as test_avatar measures it.
static func _chroma_distance(a: Color, b: Color) -> float:
	return (Vector2(cos(TAU * a.h), sin(TAU * a.h)) * a.s).distance_to(Vector2(cos(TAU * b.h), sin(TAU * b.h)) * b.s)


static func _is_purple(c: Color) -> bool:
	return c.s > 0.3 and c.h > 0.7 and c.h < 0.86


static func _mesh_bounds(mesh: ArrayMesh) -> AABB:
	var points: PackedVector3Array = mesh.get_meta(&"points")
	var out := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		out = out.expand(p)
	return out


func _test_poses() -> void:
	var b := _body(&"city")
	var head: Node3D = b.rig.joint(&"head")
	var idle_head: Vector3 = b.to_local(head.global_position)
	var face_dir: Vector3 = b.global_basis.inverse() * (head.global_basis * Vector3.FORWARD)
	check(face_dir.z > 0.9, "standing, the screen faces +z, toward the player (%.2f)" % face_dir.z)
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
	check(face_dir.z < -0.5, "running away, the screen turns back over the shoulder (%.2f)" % face_dir.z)
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


## GDD §9.2: gaunt, hunched and twitchy, with a shambling walk.
func _test_posture() -> void:
	var b := _body(&"city")
	b.set_process(false)
	b._animate(0.0)
	var chest: Node3D = b.rig.joint(&"chest")
	var up: Vector3 = b.global_basis.inverse() * (chest.global_basis * Vector3.UP)
	check(up.z > sin(deg_to_rad(Poses.HUNCH * 0.6)), "standing, it hunches forward (the chest leans %.0f°)" % rad_to_deg(asin(up.z)))
	# Twitches: now and then the head jerks, quickly.
	var head: Node3D = b.rig.joint(&"head")
	var step: float = 1.0 / 60.0
	var fastest: float = 0.0
	var last: Quaternion = head.quaternion
	for i: int in int(Poses.TWITCH_SLOT * 6.0 / step):
		b._t += step
		b._animate(step)
		fastest = maxf(fastest, rad_to_deg(last.angle_to(head.quaternion)) / step)
		last = head.quaternion
	check(fastest > 120.0, "now and then its head twitches (%.0f°/s at the fastest)" % fastest)
	var moving: int = 0
	for s: float in [0.0, 0.37, 0.91, 1.3, 2.2, 3.1, 4.4, 5.9, 7.3, 8.8]:
		if Poses.twitch(s, 0.0).w > 0.01:
			moving += 1
	check(moving < 8, "but most of the time it holds still (%d of 10 moments twitching)" % moving)
	# The shamble: the left knee lifts less than the right as each swings through.
	b.set_pose(CyborgBody.Pose.WALK)
	b.set_move_speed(1.4)
	var knee_l: float = 0.0
	var knee_r: float = 0.0
	for i: int in 180:
		b._t += step
		b._animate(step)
		knee_l = maxf(knee_l, -b.rig.joint(&"shin_l").rotation.x)
		knee_r = maxf(knee_r, -b.rig.joint(&"shin_r").rotation.x)
	check(knee_l < knee_r * 0.8 and knee_l > 0.05, "it shambles, dragging its left leg (knees %.0f° and %.0f°)" % [rad_to_deg(knee_l), rad_to_deg(knee_r)])
	b.queue_free()
	await tree.process_frame


func _test_faces_and_charge() -> void:
	var plain := _body(&"city")
	var host := _body(&"city", true)
	for f: Kit.Face in [Kit.Face.AIMING, Kit.Face.SHOCKED, Kit.Face.DEAD, Kit.Face.NEUTRAL]:
		plain.set_expression(f)
		check(plain.material.get_shader_parameter(&"face") == Kit.face_texture(f), "the screen shows expression %s" % Kit.Face.keys()[f])
	check(float(host.material.get_shader_parameter(&"glitch")) == 1.0 and float(plain.material.get_shader_parameter(&"glitch")) == 0.0,
		"a host's screen glitches purple, a plain cyborg's doesn't")
	check(plain.material.get_shader_parameter(&"led_color") == Kit.LED_COLOR, "the face glows cold white")
	check(float(plain.material.get_shader_parameter(&"crack")) == 0.0 and float(plain.material.get_shader_parameter(&"flicker")) == 0.0,
		"the base's screen is neither cracked nor flickering (zone variants may be)")
	check(plain.material != host.material, "each cyborg has its own material")
	plain.set_charge(0.7)
	check(is_equal_approx(float(plain.material.get_shader_parameter(&"charge")), 0.7), "the charge glow follows set_charge")
	# The screen, emitter ring and charge orb are marked pieces inside the segment meshes.
	var parts: Array[MeshInstance3D] = plain.rig.part_instances()
	check(_has_glow(parts[HumanoidPose.HEAD].mesh, CyborgSuit.SCREEN), "the screen is part of the head mesh")
	check(_has_glow(parts[HumanoidPose.FOREARM_R].mesh, CyborgSuit.ORB) and _has_glow(parts[HumanoidPose.FOREARM_R].mesh, CyborgSuit.RING),
		"the emitter ring and charge orb are part of the cannon forearm")
	check(not _has_glow(parts[HumanoidPose.FOREARM_L].mesh, CyborgSuit.ORB), "only the right arm is a cannon")
	var host_parts: Array[MeshInstance3D] = host.rig.part_instances()
	check(_has_glow(host_parts[HumanoidPose.CHEST].mesh, CyborgSuit.VEIN) and _has_glow(host_parts[HumanoidPose.FOREARM_L].mesh, CyborgSuit.VEIN)
		and not _has_glow(parts[HumanoidPose.CHEST].mesh, CyborgSuit.VEIN), "purple veins run along a host's neck and arms, and only a host's")
	var elbow: Vector3 = plain.rig.joint(&"forearm_r").global_position
	check(absf(elbow.distance_to(plain.muzzle_position()) - 0.43) < 0.01, "the muzzle is at the cannon's tip")
	for b: CyborgBody in [plain, host]:
		b.queue_free()
	await tree.process_frame


func _has_glow(mesh: Mesh, glow: float) -> bool:
	if mesh == null:
		return false
	for s: int in mesh.get_surface_count():
		for uv: Vector2 in mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV]:
			if absf(uv.x - glow) < 0.01:
				return true
	return false


## The expressions must read at gameplay distance (the brief): each face is on the grid, "ERR" is the
## defeated face, and shrunk to the few pixels the screen covers 14 m ahead (FAR_PIXELS) the calm,
## aiming and shocked faces still differ clearly. The faces carry mipmaps and the shader averages them
## far away rather than point-sampling (which aliases a distant face to black).
func _test_far_faces() -> void:
	for f: Kit.Face in Kit.FACES:
		var rows: Array = Kit.FACES[f]
		var ok: bool = rows.size() == Kit.FACE_GRID.y
		for row: String in rows:
			ok = ok and row.length() == Kit.FACE_GRID.x
		check(ok, "face %s is %d × %d LEDs" % [Kit.Face.keys()[f], Kit.FACE_GRID.x, Kit.FACE_GRID.y])
	var err: Array = Kit.FACES[Kit.Face.DEAD]
	check(String(err[2]) == ".###.###.###." and String(err[4]) == ".###.##..##..", "a defeated cyborg's screen reads ERR")
	var small: Dictionary = {}
	for f: Kit.Face in [Kit.Face.NEUTRAL, Kit.Face.AIMING, Kit.Face.SHOCKED]:
		small[f] = _shrink(Kit.FACES[f], FAR_PIXELS)
	for a: Kit.Face in small:
		for b: Kit.Face in small:
			if a < b:
				var d: float = _difference(small[a], small[b])
				check(d > 0.12, "14 m ahead the %s and %s faces still differ (%.2f)" % [Kit.Face.keys()[a], Kit.Face.keys()[b], d])
	check(Kit.face_texture(Kit.Face.NEUTRAL).get_image().has_mipmaps(), "the faces carry mipmaps for the far view")
	var code: String = FileAccess.get_file_as_string(SHADER_PATH)
	check(code.contains("textureLod(face") and code.contains("texelFetch(face"),
		"the shader shows each LED close up and averages them far away")


## A face's pixels box-filtered down to `size` (coverage 0-1 per pixel).
static func _shrink(rows: Array, size: Vector2i) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(size.x * size.y)
	var cw: float = float(Kit.FACE_GRID.x) / size.x
	var ch: float = float(Kit.FACE_GRID.y) / size.y
	for py: int in size.y:
		for px: int in size.x:
			var sum: float = 0.0
			for y: int in Kit.FACE_GRID.y:
				var oy: float = maxf(0.0, minf(y + 1.0, (py + 1) * ch) - maxf(float(y), py * ch))
				if oy <= 0.0:
					continue
				for x: int in Kit.FACE_GRID.x:
					var ox: float = maxf(0.0, minf(x + 1.0, (px + 1) * cw) - maxf(float(x), px * cw))
					if ox > 0.0 and String(rows[y])[x] == "#":
						sum += ox * oy
			out[py * size.x + px] = sum / (cw * ch)
	return out


## Mean absolute difference of two shrunk faces.
static func _difference(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var sum: float = 0.0
	for i: int in a.size():
		sum += absf(a[i] - b[i])
	return sum / a.size()


func _test_deaths() -> void:
	for cause: StringName in [&"stomp", &"weapon", &"claws"]:
		var b := _body(&"city", cause == &"weapon")
		var done: Array[bool] = [false]
		b.death_finished.connect(func() -> void: done[0] = true)
		b.die(cause)
		check(b.face == Kit.Face.DEAD and b.material.get_shader_parameter(&"face") == Kit.face_texture(Kit.Face.DEAD),
			"%s: a defeated cyborg's screen shows ERR" % cause)
		check(float(b.material.get_shader_parameter(&"glow_boost")) == 0.0 and float(b.material.get_shader_parameter(&"glitch")) == 0.0,
			"%s: its glows (and a host's glitch) go out" % cause)
		var dark_at: float = -1.0
		var t: float = 0.0
		for i: int in 60:
			await tree.process_frame
			t += 1.0 / Engine.physics_ticks_per_second
			if dark_at < 0.0 and b.screen_power <= 0.0:
				dark_at = t
			if done[0]:
				break
		check(done[0], "%s: the death animation finishes" % cause)
		check(dark_at < 0.0 or dark_at >= CyborgBody.ERR_TIME, "%s: ERR shows for a moment before the screen goes dark" % cause)
		b.queue_free()
	check(CyborgBody.ERR_TIME + CyborgBody.SCREEN_OFF_TIME <= 0.34,
		"ERR and the switch-off fit inside the quickest death (the claws' and the dash's, 0.34 s)")
	var u := _body(&"city", false, true)
	var chest: Node3D = u.rig.joint(&"chest")
	var before_up: Vector3 = u.global_basis.inverse() * (chest.global_basis * Vector3.UP)
	u.die(&"weapon")
	for i: int in 40:
		await tree.process_frame
	var after_up: Vector3 = u.global_basis.inverse() * (chest.global_basis * Vector3.UP)
	check(after_up.z > before_up.z + 0.4, "a window cyborg slumps forward over the sill (%.2f → %.2f)" % [before_up.z, after_up.z])
	check(u.screen_power == 0.0 and float(u.material.get_shader_parameter(&"screen_power")) == 0.0,
		"and its screen stays dark")
	u.queue_free()
	await tree.process_frame


func _set_reduced_flashing(on: bool) -> void:
	var profile := Profile.new()
	Settings.set_value(profile, "reduced_flashing", on)
	Settings.apply_visuals(profile)


## Settings > Reduced flashing: the shader reads the global uniform (the static, a host's static and
## row jumps, a flickering screen, the veins' pulse, the switch-off's bright line and the full charge
## orb all calm down); a host's corrupted faces and its own face each show for at least half a second;
## rapid hits hold a soft tint steady instead of strobing.
func _test_reduced_flashing() -> void:
	var code: String = FileAccess.get_file_as_string(SHADER_PATH)
	check(code.contains("kit_flash.gdshaderinc"), "the cyborg shader reads the Reduced flashing uniform")
	check(code.count("reduced_flashing") >= 6, "the static, glitches, flicker, veins, switch-off and charge orb honour it (%d uses)"
		% code.count("reduced_flashing"))
	var step: float = 1.0 / 60.0
	for reduced: bool in [false, true]:
		_set_reduced_flashing(reduced)
		var b := _body(&"city", true)
		b.set_process(false)
		var shown: Texture2D = b.material.get_shader_parameter(&"face")
		var since: float = 0.0
		var changes: int = 0
		var shortest: float = INF
		for i: int in 1200:
			b._update_visor(step)
			since += step
			var now: Texture2D = b.material.get_shader_parameter(&"face")
			if now != shown:
				if changes > 0:
					shortest = minf(shortest, since)
				changes += 1
				shown = now
				since = 0.0
		var hits_steady: bool = true
		for i: int in 60:
			if i % 6 == 0:
				b.flash()
			b._update_flash(step)
			if (b.material.get_shader_parameter(&"tint") as Color).a <= 0.0:
				hits_steady = false
		var tint: Color = b.material.get_shader_parameter(&"tint")
		if reduced:
			check(changes >= 4 and shortest >= 0.5, "reduced flashing: the host's faces each show for at least 0.5 s (%d changes, shortest %.2f s)" % [changes, shortest])
			check(hits_steady and tint.a < CyborgBody.FLASH_TINT.a, "reduced flashing: rapid hits hold a soft tint steady")
		else:
			check(changes >= 4 and shortest < 0.5, "the host's screen glitches in quick bursts (shortest %.2f s)" % shortest)
			check(not hits_steady, "each hit flashes")
		b.queue_free()
	_set_reduced_flashing(false)
	await tree.process_frame
