class_name GreyboxSkin
extends ZoneSkin
## Placeholder skin: flat boxes plus glow strips. Colours follow the hazard language
## (pink crackle = electric fence, yellow = sign, orange edge = gap).

@export_group("Environment")
## Sky gradient: dark overhead, a neon glow at the horizon so the corridor reads as open city, not a tunnel.
@export var sky_top_color: Color = Color(0.03, 0.02, 0.09)
@export var sky_horizon_color: Color = Color(0.42, 0.12, 0.45)
@export var ground_color: Color = Color(0.02, 0.015, 0.04)
@export var ambient_color: Color = Color(0.45, 0.45, 0.6)
## Distant geometry fades into the horizon colour.
@export_range(0.0, 0.05, 0.001) var fog_density: float = 0.006
@export_range(0.0, 2.0, 0.05) var glow_intensity: float = 0.9

@export_group("Colours")
@export var floor_color: Color = Color(0.16, 0.17, 0.22)
@export var gap_edge_color: Color = Color(1.0, 0.45, 0.1)
@export var lane_mark_color: Color = Color(0.2, 0.6, 1.0)
@export var wall_color: Color = Color(0.1, 0.11, 0.16)
@export var wall_stripe_color: Color = Color(0.35, 0.2, 0.9)
@export var fence_color: Color = Color(1.0, 0.18, 0.62)
@export var fence_post_color: Color = Color(0.3, 0.3, 0.35)
@export var sign_color: Color = Color(1.0, 0.8, 0.15)
@export var hull_color: Color = Color(0.22, 0.16, 0.3)
@export var hull_seam_color: Color = Color(0.7, 0.4, 1.0)
@export var pad_color: Color = Color(0.1, 1.0, 0.95)
@export var ramp_color: Color = Color(0.3, 1.0, 0.35)
## Speed pads share the ramps' green "safe boost" family, drawn as chevrons (FB 49).
@export var speed_pad_color: Color = Color(0.45, 1.0, 0.55)
@export var finish_color: Color = Color(1.0, 1.0, 1.0)

@export_group("Readability")
## Spacing of floor and wall marks that convey speed.
@export_range(2.0, 40.0, 1.0, "suffix:m") var mark_spacing: float = 10.0
## Faint lines on the walls at these heights, to read how high a wall run is.
@export var wall_height_marks: PackedFloat32Array = PackedFloat32Array([2.0, 4.0])
@export_range(4.0, 20.0, 0.5, "suffix:m") var wall_height: float = 9.0


func make_environment() -> Environment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = sky_top_color
	sky_material.sky_horizon_color = sky_horizon_color
	sky_material.sky_curve = 0.12
	sky_material.ground_bottom_color = ground_color
	sky_material.ground_horizon_color = sky_horizon_color
	sky_material.ground_curve = 0.05
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = glow_intensity
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = fog_density > 0.0
	env.fog_light_color = sky_horizon_color.darkened(0.55)
	env.fog_density = fog_density
	env.fog_sky_affect = 0.0
	return env


func floor_segment(parent: Node3D, center: Vector3, size: Vector3, lane_x: float,
		edge_start: bool, edge_end: bool) -> void:
	# Inset slightly so lane boundaries read as dark seams.
	GreyboxMaterials.add_box(parent, center, size - Vector3(0.08, 0.0, 0.0), GreyboxMaterials.scenery(floor_color))
	var top: float = center.y + size.y * 0.5
	var near_z: float = center.z + size.z * 0.5
	var far_z: float = center.z - size.z * 0.5
	var edge_w: float = size.x - 0.3
	var edge_mat: Material = GreyboxMaterials.glow(gap_edge_color, 2.5)
	if edge_start:
		GreyboxMaterials.add_box(parent, Vector3(center.x, top + 0.01, near_z - 0.1), Vector3(edge_w, 0.04, 0.2), edge_mat)
	if edge_end:
		GreyboxMaterials.add_box(parent, Vector3(center.x, top + 0.01, far_z + 0.1), Vector3(edge_w, 0.04, 0.2), edge_mat)
	var mark_mat: Material = GreyboxMaterials.glow(lane_mark_color, 0.8)
	var d: float = ceilf(-near_z / mark_spacing) * mark_spacing
	while d < -far_z - 0.5:
		GreyboxMaterials.add_box(parent, Vector3(lane_x, top + 0.01, -d), Vector3(0.5, 0.03, 0.12), mark_mat)
		d += mark_spacing


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	var bottom: float = -6.0
	var mid_z: float = -(start + end) * 0.5
	GreyboxMaterials.add_box(parent, Vector3(face_x + side * 0.5, (wall_height + bottom) * 0.5, mid_z),
		Vector3(1.0, wall_height - bottom, end - start), GreyboxMaterials.scenery(wall_color))
	var stripe_x: float = face_x - side * 0.01
	var stripe_mat: Material = GreyboxMaterials.glow(wall_stripe_color, 1.2)
	var d: float = ceilf(start / mark_spacing) * mark_spacing
	while d < end:
		GreyboxMaterials.add_box(parent, Vector3(stripe_x, wall_height * 0.5, -d), Vector3(0.04, wall_height, 0.15), stripe_mat)
		d += mark_spacing
	var line_mat: Material = GreyboxMaterials.glow(wall_stripe_color, 0.5)
	for height: float in wall_height_marks:
		GreyboxMaterials.add_box(parent, Vector3(stripe_x, height, mid_z), Vector3(0.04, 0.05, end - start), line_mat)


func fence(hazard: Hazard, size: Vector3, ground_y: float, _gapped: bool) -> void:
	var energy := HazardVisual.new()
	energy.mesh = GreyboxMaterials.unit_box()
	energy.scale = size
	energy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hazard.add_child(energy)
	energy.bind(hazard, GreyboxMaterials.glow(fence_color, 3.0, 0.75), GreyboxMaterials.glow(fence_color, 0.3, 0.12))
	# Posts run from the floor to the top of the field, so a gapped fence reads as open underneath.
	var top: float = size.y * 0.5
	var post_mat: Material = GreyboxMaterials.flat(fence_post_color)
	for s: float in [-1.0, 1.0]:
		GreyboxMaterials.add_box(hazard, Vector3(s * (size.x * 0.5 + 0.02), (ground_y + top) * 0.5, 0.0),
			Vector3(0.15, top - ground_y, 0.15), post_mat)


func wall_sign(hazard: Hazard, size: Vector3) -> void:
	GreyboxMaterials.add_box(hazard, Vector3.ZERO, size, GreyboxMaterials.glow(sign_color, 1.3))


func hull(parent: Node3D, center: Vector3, size: Vector3, lane_edges_x: Array[float]) -> void:
	GreyboxMaterials.add_box(parent, center, size, GreyboxMaterials.scenery(hull_color))
	var underside: float = center.y - size.y * 0.5 - 0.01
	var seam_mat: Material = GreyboxMaterials.glow(hull_seam_color, 1.5)
	for x: float in lane_edges_x:
		GreyboxMaterials.add_box(parent, Vector3(x, underside, center.z), Vector3(0.06, 0.03, size.z), seam_mat)
	# The far end glows so the drop back to the floor is readable.
	GreyboxMaterials.add_box(parent, Vector3(center.x, underside, center.z - size.z * 0.5 + 0.15),
		Vector3(size.x, 0.05, 0.3), GreyboxMaterials.glow(gap_edge_color, 2.5))


func pad(trigger: Area3D, size: Vector3) -> void:
	GreyboxMaterials.add_box(trigger, Vector3(0.0, -size.y * 0.5 + 0.03, 0.0), Vector3(size.x, 0.06, size.z),
		GreyboxMaterials.glow(pad_color, 3.0))


func ramp(trigger: Area3D, size: Vector3, side: int) -> void:
	var slab := GreyboxMaterials.add_box(trigger, Vector3(0.0, -size.y * 0.5 + 0.3, 0.0), Vector3(size.x, 0.15, size.z),
		GreyboxMaterials.glow(ramp_color, 2.0))
	slab.rotation.z = side * 0.3


func speed_pad(trigger: Area3D, size: Vector3) -> void:
	var mat: Material = GreyboxMaterials.glow(speed_pad_color, 2.5)
	var floor_y: float = -size.y * 0.5 + 0.03
	for i: int in 3:
		var z: float = size.z * 0.5 - (i + 0.5) * size.z / 3.0
		for s: float in [-1.0, 1.0]:
			var bar := GreyboxMaterials.add_box(trigger, Vector3(s * size.x * 0.2, floor_y, z), Vector3(size.x * 0.45, 0.05, 0.12), mat)
			bar.rotation.y = s * 0.6


func finish_line(parent: Node3D, width: float, distance: float) -> void:
	GreyboxMaterials.add_box(parent, Vector3(0.0, 0.02, -distance), Vector3(width, 0.05, 0.6), GreyboxMaterials.glow(finish_color, 3.0))
