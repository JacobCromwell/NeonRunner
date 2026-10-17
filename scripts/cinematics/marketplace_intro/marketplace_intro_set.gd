class_name MarketplaceIntroSet
extends Node3D
## The Marketplace intro's props (MarketplaceIntro), built on its stage so they hide with it:
## - a line of market stalls along the left of the street, end to end: the Marketplace's stall doodad (MarketDoodads,
##   its picture cards from DoodadCards: plank counter, corner posts, striped little roof, goods in its open middle),
##   scaled to the characters as the Beach outro's tiki bar is, their awnings in a few colours (doodad_card.gdshader's
##   recolor; one material a colour), every other one turned end for end;
## - the stall-keeper in hers (MarketplaceIntroVendor), facing the street, the fabrics inside the stall behind her;
## - the photo card the runner shows her (marketplace_intro_card.gdshader: the Chairman's photo, scribbled writing).
## Set space is track space (CineStage.point places it); the cinematic moves the card and poses the vendor.

## The Marketplace's stall doodad: its size class and its box at design scale (DoodadArtSet's medium box).
const STALL_CLASS: StringName = &"medium"
const STALL_LOOK: String = "vendor_stall"
const STALL_BOX := Vector3(1.9, 2.6, 3.6)
const CARD_SHADER: Shader = preload("res://scripts/cinematics/marketplace_intro/marketplace_intro_card.gdshader")

var n: MarketplaceIntroTuning
var stage: CineStage
## The stall's box at the characters' scale, the stalls' middles along the track, and the x of their counters' front.
var stall_size := Vector3.ZERO
var stall_z := PackedFloat32Array()
var front_x: float = 0.0
var stalls: Array[MeshInstance3D] = []
var vendor: MarketplaceIntroVendor
var card: MeshInstance3D
var card_material: ShaderMaterial


func setup(p_stage: CineStage, p_n: MarketplaceIntroTuning) -> void:
	name = "MarketplaceIntroSet"
	stage = p_stage
	n = p_n
	stall_size = STALL_BOX * n.stall_scale
	front_x = stage.wall_x(-1) + n.stall_inset + stall_size.x
	var pitch: float = stall_size.z + n.stall_gap
	stall_z.clear()
	for i: int in n.stall_count:
		stall_z.append(n.stall_at + float(i - n.vendor_stall) * pitch)
	_build_stalls()
	vendor = MarketplaceIntroVendor.new()
	add_child(vendor)
	vendor.setup(n.vendor_height)
	vendor.global_position = stage.point(counter(Vector3(-n.vendor_back, 0.0, 0.0)))
	# Facing the street (+x): the rig faces -z.
	vendor.rotation.y = -PI * 0.5
	_build_card()


## A point given from the front of her stall's counter where she stands (x out into the street, y up, z along the
## track): track space.
func counter(p: Vector3) -> Vector3:
	return Vector3(front_x, 0.0, n.stall_at + n.counter_along) + p


func _build_stalls() -> void:
	var cards: DoodadCards = DoodadCards.for_zone("marketplace")
	var look: Dictionary = {}
	if cards.ok:
		for d: Dictionary in cards.designs.get(String(STALL_CLASS), []):
			if String(d.get("name", "")) == STALL_LOOK:
				look = d
	var mesh: Mesh
	var materials: Array[Material] = []
	if look.is_empty():
		# No cards (the atlas not generated): the zone's plain doodad box.
		mesh = ZoneSkin.default_doodad_mesh(STALL_BOX, 1, PackedColorArray([Color(0.56, 0.39, 0.25)]))
		materials.append(MeshKit.solid())
	else:
		mesh = cards.mesh_for(look, STALL_BOX)
		for c: Color in n.awning_colors:
			var m := cards.material.duplicate() as ShaderMaterial
			m.set_shader_parameter(&"recolor", Vector4(c.r, c.g, c.b, c.a))
			materials.append(m)
	for i: int in stall_z.size():
		var inst := MeshInstance3D.new()
		inst.name = "Stall%d" % i
		inst.mesh = mesh
		# Hers wears the first colour; the others take the rest in turn.
		var k: int = posmod(i - n.vendor_stall, materials.size())
		inst.material_override = materials[k]
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		inst.scale = Vector3.ONE * n.stall_scale
		inst.global_position = stage.point(Vector3(front_x - stall_size.x * 0.5, stall_size.y * 0.5, stall_z[i]))
		if (i - n.vendor_stall) % 2 != 0:
			inst.rotation.y = PI
		stalls.append(inst)


func _build_card() -> void:
	var quad := QuadMesh.new()
	quad.size = n.card_size
	card_material = ShaderMaterial.new()
	card_material.shader = CARD_SHADER
	card_material.set_shader_parameter(&"aspect", n.card_size.x / maxf(n.card_size.y, 0.001))
	card_material.set_shader_parameter(&"scribble_seed", n.scribble_seed)
	card = MeshInstance3D.new()
	card.name = "Card"
	card.mesh = quad
	card.material_override = card_material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.visible = false
	add_child(card)


## The card held up to her: its middle at `at` (world space), its face toward `toward` (world space), upright.
static func facing(at: Vector3, toward: Vector3) -> Transform3D:
	var z: Vector3 = (toward - at).normalized()
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	var y: Vector3 = z.cross(x)
	return Transform3D(Basis(x, y, z), at)


## Draw calls its props add now (each visible mesh's surfaces): tests.
func draw_calls() -> int:
	var count: int = 0
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var g := node as MeshInstance3D
		if g.mesh != null and g.is_visible_in_tree():
			count += g.mesh.get_surface_count()
	return count
