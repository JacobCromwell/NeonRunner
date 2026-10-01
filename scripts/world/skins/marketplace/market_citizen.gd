class_name MarketCitizen
extends Node3D
## One Marketplace citizen (GDD §5, "Citizens"; task D3): a baked flipbook (CitizenSheet,
## tools/asset_gen/citizen_sheet_gen.gd) on a single cheap textured quad, standing in a shop window.
## Idles in a loop until the runner draws near, then plays one reaction (startled or cheering) and
## eases back to idle. Scenery only: no collision, no gameplay, and never looked at by the player's
## systems in the other direction either.
##
## Which window gets a citizen, which archetype and which reaction it will play are all seeded from
## the chunk (MarketCitizens), so a level builds the same every attempt; only *when* the reaction
## fires depends on the run, through the player's own track distance (kept apart from the player's
## gameplay state on purpose: CLAUDE.md principle 1, "no new collision or gameplay").
##
## Hook for E5a (GDD §10, The House: "the citizens in the shop windows cheer and duck throughout"):
## every live citizen joins the GROUP group, and react(kind) can be called on any of them directly
## (kind: &"startled" or &"cheer"), so the boss can make every citizen in view react without this
## file changing.

const GROUP := &"market_citizens"
## How far ahead of (and past) the citizen the player triggers its own reaction, in metres.
const REACT_LEAD: float = 3.2
const REACT_GRACE: float = 1.5

var at: float = 0.0

var _mat: StandardMaterial3D
var _clip: CitizenRig.Clip = CitizenRig.Clip.IDLE
var _clip_t: float = 0.0
var _phase: float = 0.0
var _reaction: StringName = &"cheer"
var _col: int = -1
var _row: int = -1
var _triggered: bool = false
var _world: WeakRef


## `texture`: the archetype's baked sheet. `size`: the card's width/height (metres), in the wall's
## plane (x = 0 locally; the window's own transform places and turns it). `p_phase`/`p_reaction` are
## seeded by the caller (MarketCitizens) from the window's track position, so they're the same every
## build; only when the reaction fires depends on the run.
func setup(texture: Texture2D, size: Vector2, p_at: float, p_phase: float, p_reaction: StringName) -> void:
	at = p_at
	_phase = p_phase
	_reaction = p_reaction
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _quad_mesh(size)
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = texture
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_mat.uv1_scale = Vector3(1.0 / CitizenSheet.COLS, 1.0 / CitizenSheet.ROWS, 1.0)
	mesh_inst.material_override = _mat
	add_child(mesh_inst)
	add_to_group(GROUP)
	_apply_frame(0, 0)


## Plays `kind` (&"startled" or &"cheer") now, easing back to idle on its own once it's done. Safe
## to call at any time, including mid-reaction (restarts it) — the hook The House (E5a) will use.
func react(kind: StringName) -> void:
	_clip = CitizenRig.Clip.STARTLED if kind == &"startled" else CitizenRig.Clip.CHEER
	_clip_t = 0.0


## True while a reaction is still playing (for tests, and anything that wants to know, e.g. E5a).
func is_reacting() -> bool:
	return _clip != CitizenRig.Clip.IDLE


func _process(delta: float) -> void:
	_clip_t += delta
	var fps: float = CitizenSheet.FPS[_clip]
	var dur: float = float(CitizenSheet.COLS) / fps
	if _clip != CitizenRig.Clip.IDLE and _clip_t >= dur:
		_clip = CitizenRig.Clip.IDLE
		_clip_t = 0.0
	var col: int
	if _clip == CitizenRig.Clip.IDLE:
		var idle_fps: float = CitizenSheet.FPS[CitizenRig.Clip.IDLE]
		col = int(fmod(_clip_t * idle_fps + _phase * CitizenSheet.COLS, float(CitizenSheet.COLS)))
	else:
		col = clampi(int(_clip_t * fps), 0, CitizenSheet.COLS - 1)
	_apply_frame(col, _clip)
	if not _triggered:
		_check_trigger()


func _apply_frame(col: int, row: int) -> void:
	if col == _col and row == _row:
		return
	_col = col
	_row = row
	_mat.uv1_offset = Vector3(float(col) / CitizenSheet.COLS, float(row) / CitizenSheet.ROWS, 0.0)


func _check_trigger() -> void:
	var world: RunWorld = _find_world()
	if world == null:
		return
	var ahead: float = at - world.player_distance()
	if ahead <= REACT_LEAD and ahead >= -REACT_GRACE:
		_triggered = true
		react(_reaction)


func _find_world() -> RunWorld:
	if _world != null:
		var w: Object = _world.get_ref()
		if w != null:
			return w as RunWorld
	var n: Node = get_parent()
	while n != null and not (n is RunWorld):
		n = n.get_parent()
	if n != null:
		_world = weakref(n)
	return n as RunWorld


## A quad `size` (width, height) metres, centred on and facing along the local +x axis (the
## caller's transform turns and places it, as a window's other contents do); double-sided
## (unshaded, CULL_DISABLED in setup()) so which way it ends up facing never matters.
static func _quad_mesh(size: Vector2) -> ArrayMesh:
	var hw: float = size.x * 0.5
	var hh: float = size.y * 0.5
	var verts := PackedVector3Array([
		Vector3(0.0, -hh, -hw), Vector3(0.0, hh, -hw), Vector3(0.0, hh, hw), Vector3(0.0, -hh, hw)])
	var uvs := PackedVector2Array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	var normals := PackedVector3Array([Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT])
	# Unused by the unshaded material (vertex_color_use_as_albedo is off): some test helpers assume
	# every surface carries a colour array, so this is white rather than left null.
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
