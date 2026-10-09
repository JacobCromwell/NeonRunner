class_name DeadZoneCrater
extends Node3D
## The Dead Zone intro's crater (DeadZoneIntro): the hole itself is a gap in the stage's street (CineStageDef.gaps),
## so it looks like a gap (the owner's beat), its edges in the orange gap-edge glow of every zone; this is what is
## down in it, which a hole in play never shows (nothing is ever down there). Visual only: no collision.
## - Its floor: the street that came down with it, the zone's own floor pieces (ZoneSkin.floor_segment, so it
##   follows the skin) broken into plates tipped this way and that, with slabs leaning against its walls and
##   chunks of rubble strewn over it (the skin's solid material, in dark rubble shades).
## - Smoke rising out of it in a few thin columns (the Dead Zone's own smoke, dead_smoke.gdshader: it never
##   flickers), kept off the camera's line to the cyborgs down the street.
## - A faint, cold light down in it, so the runner reads in the dark.
## Positions are world space (the sequencer sits at the origin; CineStage converts track space). The rubble is
## seeded, so it lies the same every time. DESIGN-TBD (docs/questions/f2c.md): the crater's look (its plates, slabs,
## rubble, smoke and light).

## The floor's plates: where each one starts along the crater (share of its length), how far it drops below
## the floor's depth (m) and how it tips (degrees about x and z).
const PLATES: Array[Vector4] = [Vector4(0.0, 0.06, 5.0, -3.0), Vector4(0.36, 0.0, -2.5, 2.5), Vector4(0.68, 0.1, 3.5, -1.5)]
## Slabs leaning against its side walls: (side, share along it, width along it (m), lean (degrees from upright)).
const SLABS: Array[Vector4] = [Vector4(-1, 0.12, 1.1, 38.0), Vector4(1, 0.25, 1.3, 44.0), Vector4(-1, 0.55, 0.9, 50.0),
	Vector4(1, 0.8, 1.0, 40.0)]
const SLAB_HEIGHT: float = 0.9
const SLAB_THICKNESS: float = 0.12
const RUBBLE_SEED: int = 5501
## Rubble keeps clear of where the runner lies and gets up (half widths across and along, from their hips).
const CLEAR_HALF := Vector2(0.5, 0.95)

var intro: DeadZoneIntro
var floor_root: Node3D
var smoke: MeshInstance3D
var light: OmniLight3D


func setup(p_intro: DeadZoneIntro) -> void:
	intro = p_intro
	name = "Crater"
	var n: DeadZoneIntroTuning = intro.n
	var stage: CineStage = intro.stage
	var start: float = intro.crater_start()
	var end: float = n.crater_end
	var half: float = stage.geo.lane_width * 0.5
	floor_root = Node3D.new()
	floor_root.name = "Floor"
	add_child(floor_root)
	# The plates: the zone's floor pieces, a little narrower than the hole so their sides stay off its walls.
	var lane_world_x: float = stage.point(Vector3.ZERO).x
	for i: int in PLATES.size():
		var p: Vector4 = PLATES[i]
		var from: float = lerpf(start, end, p.x)
		var to: float = lerpf(start, end, PLATES[i + 1].x) if i + 1 < PLATES.size() else end
		var plate := Node3D.new()
		plate.name = "Plate%d" % i
		var mid: float = (from + to) * 0.5
		plate.position = Vector3(lane_world_x, -n.crater_depth - p.y, -mid)
		plate.rotation_degrees = Vector3(p.z, 0.0, p.w)
		floor_root.add_child(plate)
		var length: float = to - from + 0.25
		stage.skin.floor_segment(plate, Vector3(0.0, -TrackBuilder.FLOOR_THICKNESS * 0.5, 0.0),
			Vector3(half * 2.0 - 0.12, TrackBuilder.FLOOR_THICKNESS, length), 0.0, false, false)
	_build_rubble(n, start, end, half, lane_world_x)
	_build_smoke(n)
	light = OmniLight3D.new()
	light.name = "Light"
	light.position = stage.point(Vector3(0.0, -n.crater_depth, end) + n.crater_light_at)
	light.light_color = n.crater_light_color
	light.light_energy = n.crater_light_energy
	light.omni_range = n.crater_light_range
	light.shadow_enabled = false
	add_child(light)


## The slabs leaning on its walls and the chunks strewn over its floor, in one mesh.
func _build_rubble(n: DeadZoneIntroTuning, start: float, end: float, half: float, lane_world_x: float) -> void:
	var batch := MeshBatch.new()
	var layer: MeshLayer = batch.layer(_solid())
	var colors: PackedColorArray = n.rubble_colors if not n.rubble_colors.is_empty() else PackedColorArray([Color(0.15, 0.15, 0.15)])
	var floor_y: float = -n.crater_depth
	for k: int in SLABS.size():
		var s: Vector4 = SLABS[k]
		var side: float = s.x
		var along: float = lerpf(start, end, s.y)
		var lean: float = deg_to_rad(s.w)
		# Upright, then tipped toward its wall so its top rests on it.
		var basis := Basis(Vector3.BACK, -side * lean)
		var foot_x: float = lane_world_x + side * (half - 0.06 - SLAB_HEIGHT * sin(lean))
		var center := Vector3(foot_x, floor_y, -along) + basis * Vector3(0.0, SLAB_HEIGHT * 0.5, 0.0)
		layer.box_xform(Transform3D(basis * Basis.from_scale(Vector3(SLAB_THICKNESS, SLAB_HEIGHT, s.z)), center),
			colors[k % colors.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = RUBBLE_SEED
	var hips: float = n.crater_end - n.lie_back
	var placed: int = 0
	var tries: int = 0
	while placed < n.rubble_count and tries < n.rubble_count * 20:
		tries += 1
		var x: float = rng.randf_range(-half + 0.2, half - 0.2)
		var z: float = rng.randf_range(start + 0.2, end - 0.2)
		if absf(x) < CLEAR_HALF.x and absf(z - hips) < CLEAR_HALF.y:
			continue
		var size := Vector3(rng.randf_range(0.14, 0.42), rng.randf_range(0.08, 0.26), rng.randf_range(0.14, 0.4))
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-PI, PI), rng.randf_range(-0.4, 0.4)))
		var at := Vector3(lane_world_x + x, floor_y + size.y * 0.3, -z)
		layer.box_xform(Transform3D(basis * Basis.from_scale(size), at), colors[rng.randi() % colors.size()])
		placed += 1
	batch.commit(floor_root, "Rubble")


## The smoke columns rising out of it (dead_smoke.gdshader: each a quad whose six vertices sit at the column's
## base, spread by the shader into a column turned to the camera).
func _build_smoke(n: DeadZoneIntroTuning) -> void:
	var layer := MeshLayer.new()
	var c: Color = n.smoke_color
	var bounds := AABB()
	for i: int in n.smoke_columns.size():
		var col: Vector4 = n.smoke_columns[i]
		var base: Vector3 = intro.stage.point(Vector3(col.x, -n.crater_depth, n.crater_end - col.y))
		var reach := AABB(base - Vector3(col.z * 2.0, 0.0, col.z * 2.0), Vector3(col.z * 4.0, col.w + n.crater_depth + 1.0, col.z * 4.0))
		bounds = reach if i == 0 else bounds.merge(reach)
		layer.verts.append_array(PackedVector3Array([base, base, base, base, base, base]))
		layer.colors.append_array(PackedColorArray([c, c, c, c, c, c]))
		layer.uvs.append_array(PackedVector2Array([Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1),
			Vector2(1, 1), Vector2(1, -1)]))
		var size := Vector2(col.z, col.w + n.crater_depth)
		layer.uv2s.append_array(PackedVector2Array([size, size, size, size, size, size]))
	if layer.is_empty():
		return
	var batch := MeshBatch.new()
	batch.layer(MeshKit.material("dead_smoke.gdshader", {"rise_speed": n.smoke_rise})).append(layer)
	smoke = batch.commit(self, "Smoke")
	if smoke != null:
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The shader spreads the columns out from their bases (and leans them downwind): cull by all of that.
		smoke.custom_aabb = bounds.grow(1.0)


## The skin's solid material (every zone skin has one), else a plain matte one.
func _solid() -> Material:
	if intro.stage.skin.has_method(&"solid_material"):
		return intro.stage.skin.call(&"solid_material")
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	return m
