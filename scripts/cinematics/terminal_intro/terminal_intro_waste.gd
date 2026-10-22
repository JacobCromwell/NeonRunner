class_name TerminalIntroWaste
extends Node3D
## The wasteland round the station (TerminalIntro; the owner's beat: the scene "looks mostly like the Dead Zone"): the Dead Zone's
## own props on the forecourt and the street beyond it, drawn by the Dead Zone's skin as it draws them in a level (its doodad
## picture cards: a broken concrete column with its rebar showing, a heap of rubble, the burned-out bus; DeadDoodads), and a few
## columns of its smoke (dead_smoke.gdshader, never flickering) rising from the heaps. Visual only: no hitboxes. Station frame
## (x along the front, y up, z out). DESIGN-TBD (docs/OPEN_QUESTIONS_DEFERRED.md items 1102-1115): what stands where.

## Each kind's size class (the doodad cards' own boxes: MovementTuning.doodad_size).
const KINDS: Array[StringName] = [&"small", &"medium", &"large"]

var n: TerminalIntroTuning
var station: TerminalIntroStation
var smoke: MeshInstance3D
var props: Array[Node3D] = []


func setup(p_station: TerminalIntroStation, p_numbers: TerminalIntroTuning, tuning: MovementTuning) -> void:
	name = "Wasteland"
	station = p_station
	n = p_numbers
	var skin: ZoneSkin = station.skin
	for i: int in n.props.size():
		var p: Vector4 = n.props[i]
		var kind: StringName = KINDS[clampi(int(p.x), 0, 2)]
		var size: Vector3 = tuning.doodad_size(kind)
		var body := Node3D.new()
		body.name = "Prop%d_%s" % [i, kind]
		body.position = Vector3(p.y, size.y * 0.5, p.z)
		body.rotation_degrees = Vector3(0.0, p.w, 0.0)
		add_child(body)
		skin.doodad(body, size, kind, 0, i * 7 + 3)
		props.append(body)
	_smoke()


## The smoke columns (each a quad whose six vertices sit at its base, spread by the shader into a column turned to the camera).
func _smoke() -> void:
	var layer := MeshLayer.new()
	var bounds := AABB()
	for i: int in n.smoke_columns.size():
		var col: Vector4 = n.smoke_columns[i]
		var base: Vector3 = Vector3(col.x, 0.0, col.y)
		var local_base: Vector3 = base
		var c: Color = n.smoke_color
		layer.verts.append_array(PackedVector3Array([local_base, local_base, local_base, local_base, local_base, local_base]))
		layer.colors.append_array(PackedColorArray([c, c, c, c, c, c]))
		layer.uvs.append_array(PackedVector2Array([Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1)]))
		var size := Vector2(col.z, col.w)
		layer.uv2s.append_array(PackedVector2Array([size, size, size, size, size, size]))
		var reach := AABB(base - Vector3(col.z * 2.0, 0.0, col.z * 2.0), Vector3(col.z * 4.0, col.w + 1.0, col.z * 4.0))
		bounds = reach if i == 0 else bounds.merge(reach)
	if layer.is_empty():
		return
	var batch := MeshBatch.new()
	batch.layer(MeshKit.material("dead_smoke.gdshader", {"rise_speed": n.smoke_rise})).append(layer)
	smoke = batch.commit(self, "Smoke")
	if smoke != null:
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The shader spreads the columns out from their bases (and leans them downwind): cull by all of that.
		smoke.custom_aabb = bounds.grow(3.0)


## Draw calls its meshes add now: tests.
func draw_calls() -> int:
	var calls: int = 0
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			calls += m.mesh.get_surface_count()
	return calls
