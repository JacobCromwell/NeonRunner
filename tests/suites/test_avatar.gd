extends TestSuite
## The player avatar (PlayerAvatar, Razor Echo) and the shared humanoid rig (HumanoidRig): it builds,
## every pose runs cleanly, the run pose fits MovementTuning.visual_size, the budgets hold, equipment
## toggles (the weapon over the gold arm's shoulder, the armor shattering when it breaks), the coat's
## skirt panels swing in every pose without going through the legs or the surface, the copper glow
## stays clear of every hazard colour, the collapse finishes on its own, and a real Player drives it
## through its moves.

const TRIANGLE_BUDGET: int = 2000
const DRAW_CALL_BUDGET: int = 20
const DT: float = 1.0 / 60.0
const RUN_SPEED: float = 18.0
const Activity := HumanoidRig.Activity
## The copper glow's least distance from any hazard colour on the HSV colour wheel (hue and
## saturation together). The two gap-edge oranges (grey box, City and Gangland) are 0.18 apart, so a
## colour 0.3 away can't pass for another zone's gap edge.
const MIN_HAZARD_DISTANCE: float = 0.3
## The copper stays soft: less saturated than this, and its brightest emission (a conduit while
## dashing) at most this multiple of its colour, about the glow threshold, so bloom can't push it
## toward the gap edges' orange.
const MAX_GLOW_SATURATION: float = 0.65
const MAX_GLOW_EMISSION: float = 1.25


func run() -> void:
	_test_build()
	_test_other_parts()
	_test_shell_shape()
	_test_poses()
	_test_transitions()
	_test_run_fits_visual_size()
	_test_pose_heights()
	_test_no_skating_at_jog()
	_test_budget()
	_test_equipment()
	_test_weapon_muzzle()
	_test_armor_shatters()
	_test_coat_panels()
	_test_glow_colours()
	_test_fit_follows_retune()
	_test_flash_death_and_reset()
	_test_cost()
	await _test_tuning_panel()
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


## The pitch of the knee on panel `index`'s side as seen from its hinge (pelvis frame; + = behind).
static func _knee_angle(rig: HumanoidRig, index: int) -> float:
	var panel: HumanoidPanel = rig.parts.panels[index]
	var thigh: Node3D = rig.joint(&"thigh_r" if panel.side > 0 else &"thigh_l")
	var shin: Node3D = rig.joint(&"shin_r" if panel.side > 0 else &"shin_l")
	var v: Vector3 = (thigh.transform * shin.position) - panel.placed_hinge()
	return atan2(v.z, -v.y)


## Where the panels' hems hang from their hinges, on average (the rig's parent space), after
## settling into `state`.
func _mean_hem(avatar: PlayerAvatar, state: Dictionary) -> Vector3:
	avatar.reset()
	_drive(avatar, state, 90, "hem in %s" % state.get("surface", "floor"))
	var sum := Vector3.ZERO
	for i: int in avatar.rig.panel_count():
		sum += avatar.rig.panel_hem(i) - avatar.rig.panel_hinge(i)
	return sum / avatar.rig.panel_count()


## Every hazard colour the game uses, by name: each skin's gap edges, fences, signs, ramps and speed
## pads, and enemy fire.
static func _hazard_colors() -> Dictionary:
	var out: Dictionary = {}
	for file: String in DirAccess.get_files_at("res://data/skins/"):
		if not file.ends_with(".tres"):
			continue
		var skin: Resource = load("res://data/skins/" + file)
		for property: String in ["gap_edge_color", "fence_color", "sign_color", "sign_frame_color", "ramp_color",
				"speed_pad_color"]:
			if property in skin:
				out["%s %s" % [file.get_basename(), property.trim_suffix("_color")]] = skin.get(property)
	for look: StringName in [&"enemy_bolt", &"enemy_shell", &"enemy_bullet"]:
		out[String(look)] = (ProjectilePool.LOOKS[look] as Dictionary)["color"]
	out["cyborg charge"] = preload("res://scripts/enemies/cyborg_kit.gd").CHARGE_COLOR
	return out


## Distance between two colours on the HSV colour wheel (hue as the angle, saturation as the
## radius): how different they look in hue and saturation together, brightness left out.
static func _chroma_distance(a: Color, b: Color) -> float:
	return (Vector2(cos(TAU * a.h), sin(TAU * a.h)) * a.s).distance_to(Vector2(cos(TAU * b.h), sin(TAU * b.h)) * b.s)


## The signed volume a builder's triangles enclose (its sign follows the winding).
static func _signed_volume(built: HumanoidMeshBuilder) -> float:
	var volume: float = 0.0
	for i: int in range(0, built.vertices.size(), 3):
		volume += built.vertices[i].dot(built.vertices[i + 1].cross(built.vertices[i + 2])) / 6.0
	return volume


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
		"run pose: the top of the head (hair tips) averages %.3f m over the stride (visual_size.y %.2f ±3%%)" % [mean, vis.y])
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


## HumanoidPiece.SHELL: a closed sheet cut to its arc (the coat's panels and collar), facing outward
## like every other shape, and section_phase turning the section's corners.
func _test_shell_shape() -> void:
	var shell := HumanoidPiece.new()
	shell.shape = HumanoidPiece.Shape.SHELL
	shell.size = Vector3(0.3, 0.0, 0.24)
	shell.sides = 12
	shell.section_phase = 15.0
	shell.arc = Vector2(91.0, 179.0)
	shell.thickness = 0.02
	shell.profile = PackedVector4Array([Vector4(0.0, 1.0, 1.0, 0.0), Vector4(-0.4, 1.2, 1.2, 0.0)])
	var built := HumanoidMeshBuilder.new()
	built.add_piece(shell, false)
	# Three faces of the 12-sided section, each with an outside, an inside and two rims, plus the
	# two cut edges: two triangles apiece.
	check(built.triangle_count() == 28, "a SHELL over three faces is a closed sheet (%d triangles)" % built.triangle_count())
	var inside: bool = true
	for v: Vector3 in built.vertices:
		inside = inside and v.x > -0.001 and v.z > -0.001
	check(inside, "section_phase 15° and the arc (91°, 179°) keep it to the back-right quarter")
	var box := HumanoidPiece.new()
	box.size = Vector3(0.1, 0.1, 0.1)
	var reference := HumanoidMeshBuilder.new()
	reference.add_piece(box, false)
	var shell_volume: float = _signed_volume(built)
	var box_volume: float = _signed_volume(reference)
	check(signf(shell_volume) == signf(box_volume) and absf(shell_volume) > 0.0005,
		"its faces point outward like a box's (signed volumes %.5f, %.5f)" % [shell_volume, box_volume])


## The weapon power-up unfolds over the gold left arm's shoulder (brief), so shots leave from there.
func _test_weapon_muzzle() -> void:
	var avatar := PlayerAvatar.new()
	tree.root.add_child(avatar)
	avatar.fit_to(tuning.visual_size)
	avatar.set_equipment({"weapon_tier": 1})
	avatar.animate(_state(), DT)
	var muzzle: Vector3 = avatar.to_local(avatar.weapon_muzzle())
	var shoulder: Vector3 = avatar.to_local(avatar.rig.joint(&"upper_arm_l").global_position)
	check(muzzle.x < -0.1 and muzzle.y > shoulder.y and muzzle.z < shoulder.z,
		"the weapon's muzzle is over the left (gold) shoulder, above and in front of it (%s)" % muzzle)
	var weapon_x: float = INF
	for piece: HumanoidPiece in PlayerSuit.parts().attachments[&"weapon_1"]:
		weapon_x = minf(weapon_x, -piece.offset.x if piece.side == HumanoidPiece.Placement.LEFT else piece.offset.x)
	check(weapon_x < -0.1, "every piece of the weapon sits on the left side (%.2f m)" % weapon_x)
	avatar.queue_free()


## Armor that breaks in play shatters (brief: "they shatter visibly when they break"); the run's
## loadout, set right after reset(), never does.
func _test_armor_shatters() -> void:
	var avatar := PlayerAvatar.new()
	tree.root.add_child(avatar)
	avatar.reset()
	avatar.set_equipment({"armor": true})
	avatar.set_equipment({"armor": false})
	check(not avatar.shattering(), "setting up the loadout after reset() doesn't shatter anything")
	avatar.set_equipment({"armor": true})
	avatar.animate(_state(), DT)
	var calls: int = avatar.draw_call_count()
	avatar.set_equipment({"armor": false})
	check(avatar.shattering() and not avatar.rig.attachments().has(&"armor"),
		"armor switched off in play shatters: the plates go and shards fly")
	check(avatar.draw_call_count() == calls + 1 and avatar.draw_call_count() <= DRAW_CALL_BUDGET,
		"the shards cost one draw call while they fly (%d)" % avatar.draw_call_count())
	avatar.set_equipment({"armor": false})
	avatar.reset()
	check(not avatar.shattering(), "reset() clears the shards")
	avatar.queue_free()


## The coat's skirt: four stiff panels hinged at the waist, one mesh (one draw call) that the rig
## swings. They follow the thighs through a spring, trail when sliding, flare when falling, hang
## toward the feet on the ceiling, sag toward real gravity on a wall, and never go through the legs
## or the surface.
func _test_coat_panels() -> void:
	var avatar := PlayerAvatar.new()
	var rig: HumanoidRig = avatar.rig
	var mesh_node: MeshInstance3D = rig.panel_instance()
	check(rig.panel_count() == 4 and mesh_node != null and mesh_node.get_parent() == rig.joint(&"pelvis")
		and mesh_node.mesh.get_surface_count() == 1, "the skirt is four panels in one mesh on the pelvis")
	var back: Array[int] = []
	var front: Array[int] = []
	for i: int in rig.panel_count():
		(back if rig.parts.panels[i].behind else front).append(i)
	check(back.size() == 2 and front.size() == 2, "two panels behind the legs (split by the vent), two in front")

	# Running: every panel swings with the stride, and a knee never passes through a back panel.
	avatar.reset()
	_drive(avatar, _state(), 60, "coat warm-up")
	var low := PackedFloat32Array([INF, INF, INF, INF])
	var high := PackedFloat32Array([-INF, -INF, -INF, -INF])
	var through: float = 0.0
	var s: Dictionary = _state({"distance": 30.0})
	for f: int in 90:
		s["distance"] = float(s["distance"]) + RUN_SPEED * DT
		avatar.animate(s, DT)
		for i: int in rig.panel_count():
			var pitch: float = rig.panel_angles(i).x
			low[i] = minf(low[i], pitch)
			high[i] = maxf(high[i], pitch)
		for i: int in back:
			through = maxf(through, _knee_angle(rig, i) - rig.panel_angles(i).x)
	var swing: float = INF
	for i: int in rig.panel_count():
		swing = minf(swing, rad_to_deg(high[i] - low[i]))
	check(swing > 12.0, "running, every panel swings with the stride (at least %.0f°)" % swing)
	check(through < 0.01, "running, a knee never passes through a back panel (%.3f rad at worst)" % through)

	# Stopping: the panels keep swinging a moment (the spring), then settle hanging.
	var still: Dictionary = _state({"distance": float(s["distance"]), "speed": 0.0})
	var moved: float = 0.0
	for f: int in 12:
		var before: float = rig.panel_angles(back[0]).x
		avatar.animate(still, DT)
		moved += absf(rig.panel_angles(back[0]).x - before)
	_drive(avatar, still, 120, "coat settling")
	var last: PackedFloat32Array = []
	for i: int in rig.panel_count():
		last.append(rig.panel_angles(i).x)
	avatar.animate(still, DT)
	var settled: bool = true
	for i: int in rig.panel_count():
		settled = settled and absf(rig.panel_angles(i).x - last[i]) < deg_to_rad(0.2) \
			and absf(rig.panel_angles(i).x) < deg_to_rad(10.0)
	check(moved > deg_to_rad(3.0) and settled,
		"after a stop the panels swing on for a moment (%.1f°), then hang still" % rad_to_deg(moved))
	var hanging := PackedFloat32Array(last)

	# Sliding feet first: the back panels trail behind along the ground.
	avatar.reset()
	_drive(avatar, _state({"sliding": true}), 40, "coat slide")
	var trail: bool = true
	var pelvis_z: float = _joint_z(avatar, &"pelvis")
	for i: int in back:
		trail = trail and rig.panel_angles(i).x > deg_to_rad(60.0) and rig.panel_hem(i).z > pelvis_z + 0.15
	check(trail, "sliding, the back panels trail behind")

	# Falling fast (the stomp): the panels flare, back and front ones spreading apart and out.
	avatar.reset()
	_drive(avatar, _state({"grounded": false, "vh": -22.0, "stomping": true}), 30, "coat stomp")
	var spread: float = INF
	var roll: float = INF
	for side_panels: Array in [[back[0], front[0]], [back[1], front[1]]]:
		var now: float = rig.panel_angles(side_panels[0]).x - rig.panel_angles(side_panels[1]).x
		var standing: float = hanging[side_panels[0]] - hanging[side_panels[1]]
		spread = minf(spread, now - standing)
	for i: int in rig.panel_count():
		roll = minf(roll, rig.panel_angles(i).y)
	check(spread > deg_to_rad(45.0) and roll > deg_to_rad(10.0),
		"falling fast, the panels flare: back and front spread %.0f° further apart and turn out %.0f°"
		% [rad_to_deg(spread), rad_to_deg(roll)])

	# On the ceiling the panels hang toward the feet, as on the floor; on a wall they sag toward real
	# gravity (sideways in the runner's frame: -x on the right wall).
	var hem_floor: Vector3 = _mean_hem(avatar, _state({"speed": 0.0}))
	var hem_ceiling: Vector3 = _mean_hem(avatar, _state({"speed": 0.0, "surface": "ceiling"}))
	var hem_wall: Vector3 = _mean_hem(avatar, _state({"speed": 0.0, "surface": "wall", "grounded": false, "wall_side": 1}))
	check(hem_ceiling.distance_to(hem_floor) < 0.01, "on the ceiling the panels hang toward the feet, as on the floor")
	check(hem_wall.x < hem_floor.x - 0.02, "on the right wall they sag toward real gravity (%.3f m)" % (hem_wall.x - hem_floor.x))
	avatar.free()


## Razor Echo's glow (GDD §11, the brief's colour rules): soft copper is the only thing that glows
## on the base model, it keeps clear of every hazard colour in hue and saturation, and it stays soft.
## Power-up looks never use it (they read as added on top) and glow in no hazard colour either.
func _test_glow_colours() -> void:
	var hazards: Dictionary = _hazard_colors()
	check(hazards.size() >= 12, "the check covers every skin's hazard colours and enemy fire (%d)" % hazards.size())
	var pad := (load("res://data/skins/greybox_skin.tres") as GreyboxSkin).pad_color
	for named: Array in [["copper glow", PlayerSuit.GLOW], ["pale copper (dash)", PlayerSuit.GLOW_PALE],
			["invulnerability tint", PlayerAvatar.FLASH_COLOR], ["rim light", PlayerSuit.RIM_COLOR]]:
		var nearest: String = ""
		var least: float = INF
		for hazard: String in hazards:
			var d: float = _chroma_distance(named[1], hazards[hazard])
			if d < least:
				least = d
				nearest = hazard
		check(least >= MIN_HAZARD_DISTANCE, "the %s keeps clear of every hazard colour (%.2f from the %s)" % [named[0], least, nearest])
	check(_chroma_distance(PlayerSuit.GLOW, pad) >= MIN_HAZARD_DISTANCE, "the copper is nothing like the anti-grav pads' cyan")
	check(PlayerSuit.GLOW.s <= MAX_GLOW_SATURATION, "the copper is soft: saturation %.2f" % PlayerSuit.GLOW.s)
	var energy: float = PlayerSuit.body_material().get_shader_parameter(&"glow_energy")
	var brightest: float = PlayerSuit.CONDUIT_GLOW * energy * PlayerAvatar.DASH_GLOW
	check(energy > 0.0 and brightest <= MAX_GLOW_EMISSION,
		"its brightest emission (a conduit while dashing) is %.2f× its colour, at the glow threshold" % brightest)
	# The base model: every glowing piece is the copper.
	var base: Array = PlayerSuit.parts().pieces.duplicate()
	for panel: HumanoidPanel in PlayerSuit.parts().panels:
		base.append_array(panel.pieces)
	var others: PackedStringArray = []
	var glowing: int = 0
	for piece: HumanoidPiece in base:
		if piece.glow > 0.0:
			glowing += 1
			if piece.color != PlayerSuit.GLOW:
				others.append("%s %s" % [piece.segment, piece.color])
	check(glowing >= 20 and others.is_empty(),
		"on the base model only the copper glows (%d glowing pieces; others: %s)" % [glowing, ", ".join(others)])
	# Power-ups: never the copper, never a hazard colour (the weapon's lights are the shots' own
	# cyan, violet and white).
	var wrong: PackedStringArray = []
	var attachments: Dictionary = PlayerSuit.parts().attachments
	for set_name: StringName in attachments:
		for piece: HumanoidPiece in attachments[set_name]:
			if piece.glow <= 0.0:
				continue
			var clear: bool = piece.color != PlayerSuit.GLOW
			for hazard: String in hazards:
				clear = clear and _chroma_distance(piece.color, hazards[hazard]) >= MIN_HAZARD_DISTANCE
			if not clear:
				wrong.append("%s %s" % [set_name, piece.color])
	check(wrong.is_empty(), "power-up looks glow in neither the copper nor a hazard colour (%s)" % ", ".join(wrong))


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


## The pose parameters are ranged tunables, so the F6 panel can edit them live once registered.
func _test_tuning_panel() -> void:
	var anim := (load(PlayerAvatar.ANIM_TUNING_PATH) as HumanoidAnimTuning).duplicate() as HumanoidAnimTuning
	var panel := TuningPanel.new()
	tree.root.add_child(panel)
	var sections: Array[Dictionary] = [{"title": "Avatar", "resource": anim, "path": PlayerAvatar.ANIM_TUNING_PATH}]
	panel.setup(sections)
	check(panel.control_count() >= 30, "every pose parameter has an F6 panel control (%d)" % panel.control_count())
	var slider: HSlider = panel.find_slider("forward_lean")
	if slider != null:
		slider.value = 25.0
	check(slider != null and is_equal_approx(anim.forward_lean, 25.0), "the panel edits pose parameters live")
	panel.queue_free()
	await tree.process_frame


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
