class_name HostileTakeoverLobby
extends BossPart
## The defeat's set (GDD §10: "the locomotive derails and ploughs through the lobby of a corporate tower,
## bringing down a giant, soulless logo sculpture"): a corporate tower beside the line with a sky lobby at
## the train's level (HostileTakeoverModel.lobby_tower) and, on its plaza toward the line, the brand's mark
## as a giant steel sculpture (logo_sculpture). Built once with the fight and hidden; the encounter stands
## it ahead beside the line as the defeat begins (place), and topples the sculpture back into the lobby,
## away from the line, as the locomotive ploughs in (topple). It also holds the defeat's blasts (blast: the
## gunship's explosion and the crash, big enough to read far ahead), each a few glowing spheres swelling and
## cooling from white-hot to orange, fading out, dimmer and never white-hot with Reduced flashing. Since a part
## no longer ticks once the boss is beaten, the encounter runs their clock (step). Looks only: no hitbox,
## no target.

## The tower's footprint, and how far beyond the sound barrier its lobby's glass front stands.
const TOWER := Vector2(26.0, 24.0)
const LOBBY_OUT: float = 10.0
## The sculpture stands this far out from the barrier, on the plaza before the lobby; its plinth is this
## deep (it topples about its back edge).
const SCULPTURE_OUT: float = 4.5
const PLINTH_DEPTH: float = 6.0
## Blasts at once, how long one lasts, its spheres (offsets in its size), and their glow (full, and with
## Reduced flashing).
const BLAST_POOL: int = 2
const BLAST_SECONDS: float = 1.1
const BLAST_BALLS: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(0.55, 0.35, -0.3), Vector3(-0.5, 0.25, 0.4)]
const BLAST_GLOW: float = 4.0
const BLAST_GLOW_REDUCED: float = 1.4
const HOT := Color(1.0, 0.94, 0.78)
const WARM := Color(1.0, 0.55, 0.16)

var tower: MeshInstance3D
var sculpture: Node3D
## Where it stands (track distance of the lobby's middle) and on which side (-1 left, 1 right).
var at: float = 0.0
var side: int = 1
var _topple: float = 0.0
## The blasts: {root, material, t (seconds since it went off; -1 idle), size}.
var _blasts: Array[Dictionary] = []


func _build() -> void:
	display_name = "the lobby"
	is_obstacle = true
	immune_to_weapons = true
	top_level = true
	tower = MeshBatch.add_instance(self, HostileTakeoverModel.lobby_tower(TOWER.x, TOWER.y, world.skin), "Tower")
	sculpture = Node3D.new()
	sculpture.name = "Sculpture"
	add_child(sculpture)
	var mark: MeshInstance3D = MeshBatch.add_instance(sculpture, HostileTakeoverModel.logo_sculpture(world.skin), "Mark")
	mark.position = Vector3(0.0, 0.0, PLINTH_DEPTH)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 6
	for i: int in BLAST_POOL:
		var root := Node3D.new()
		root.name = "Blast%d" % i
		root.top_level = true
		root.visible = false
		add_child(root)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = HOT
		m.emission_enabled = true
		m.emission = HOT
		m.emission_energy_multiplier = BLAST_GLOW
		for j: int in BLAST_BALLS.size():
			var sphere := MeshInstance3D.new()
			sphere.mesh = ball
			sphere.material_override = m
			sphere.position = BLAST_BALLS[j]
			sphere.scale = Vector3.ONE * (1.0 - 0.25 * j)
			sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(sphere)
		_blasts.append({"root": root, "material": m, "t": -1.0, "size": 1.0})
	visible = false


## Stands it beside the line on `p_side` with its lobby's middle at track distance `p_at`, its lobby facing
## the line, the sculpture upright.
func place(p_at: float, p_side: int) -> void:
	at = p_at
	side = p_side if p_side != 0 else 1
	var lobby_x: float = side * (world.geo.wall_x() + LOBBY_OUT)
	# Its own +z (the lobby's front) faces the line: turned a quarter about y.
	global_transform = Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(lobby_x, 0.0, TrackGeometry.world_z(at)))
	sculpture.position = Vector3(0.0, 0.0, LOBBY_OUT - SCULPTURE_OUT - PLINTH_DEPTH)
	_topple = 0.0
	sculpture.rotation = Vector3.ZERO
	visible = true


## The sculpture toppling over (0 upright, 1 down on its back, away from the line, into the lobby's front).
func topple(amount: float) -> void:
	_topple = clampf(amount, 0.0, 1.0)
	var k: float = _topple * _topple
	sculpture.rotation = Vector3(-k * PI * 0.5, 0.0, 0.0)


## Sets off a blast `size` metres across at `at` (world space), in the idle rig or the oldest one.
func blast(at: Vector3, size: float) -> void:
	var pick: Dictionary = _blasts[0]
	for b: Dictionary in _blasts:
		if float(b["t"]) < 0.0:
			pick = b
			break
		if float(b["t"]) > float(pick["t"]):
			pick = b
	pick["t"] = 0.0
	pick["size"] = size
	var root: Node3D = pick["root"]
	root.global_position = at
	root.visible = true
	_shape(pick)


## The blasts' clock (see the header).
func step(delta: float) -> void:
	for b: Dictionary in _blasts:
		if float(b["t"]) < 0.0:
			continue
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) >= BLAST_SECONDS:
			b["t"] = -1.0
			(b["root"] as Node3D).visible = false
			continue
		_shape(b)


## A blast at its age: swelling fast then slowly, cooling from white-hot to orange and fading.
func _shape(b: Dictionary) -> void:
	var k: float = clampf(float(b["t"]) / BLAST_SECONDS, 0.0, 1.0)
	var grow: float = 1.0 - pow(1.0 - k, 3.0)
	var root: Node3D = b["root"]
	root.scale = Vector3.ONE * maxf(float(b["size"]) * 0.5 * (0.3 + 0.7 * grow), 0.01)
	var m: StandardMaterial3D = b["material"]
	var reduced: bool = Settings.flashing_reduced
	var heat: Color = WARM if reduced else HOT.lerp(WARM, smoothstep(0.0, 0.5, k))
	var fade: float = 1.0 - smoothstep(0.5, 1.0, k)
	m.albedo_color = Color(heat.r, heat.g, heat.b, fade)
	m.emission = heat
	m.emission_energy_multiplier = (BLAST_GLOW_REDUCED if reduced else BLAST_GLOW) * fade


## The stretch of the track it stands beside (track distances), with `margin` either side.
func span(margin: float = 0.0) -> Vector2:
	return Vector2(at - TOWER.x * 0.5 - margin, at + TOWER.x * 0.5 + margin)


## Where its lobby's front is, in world space (the crash's burst).
func lobby_world() -> Vector3:
	return global_transform * Vector3(0.0, 4.0, -1.5)


## Puts it away.
func hide_set() -> void:
	visible = false


## Never a target.
func targetable() -> bool:
	return false


func _on_defeated(_cause: StringName) -> void:
	pass
