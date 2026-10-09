class_name GoldenCourtSkin
extends GoldenPalaceSkin
## The Grand Court, the Golden Convergence's arena (GDD §10, the arena, proposed: "the heart of the Golden
## Palace (§5). A wide golden causeway runs through a hall so vast it has its own sky under a painted, gilded
## vault. No walls line it: low golden balustrades edge it, with reflecting pools far below, and the palace's
## towers stand off to either side, the buildings the Flying Buttresses hold up. Giant screens hung on the
## towers show the feed: the cult's emblem and the calm golden face in stage 1, The Magnate's roaring face in
## stage 2. The track itself is plain"). The Golden Palace's skin (GoldenPalaceSkin: its marble floor with the
## gold runners, its sky and lighting, its hazards' looks), with wall_section() drawing the court instead of
## the colonnade, side by side, chunk by chunk:
## - the balustrade along the causeway's edge (the wall face's line): a marble plinth, gold balusters and a
##   gold rail, low (balustrade_height), with marble posts every post_spacing carrying warm-white lamps; the
##   runner can't get past it anywhere (the encounter takes the walls away: GoldenConvergenceCourt);
## - the causeway's edge dropping away beyond it to the reflecting pools far below (pool_depth; dark still
##   water, never lighter than a gap's inside);
## - the palace's towers standing out of the pools off both sides (tower_spacing apart, sides alternating,
##   tower_offset out from the edge), white marble with gold bands and lit windows, a gold crown and spire,
##   each carrying a giant feed screen angled to the approaching runner (the court's own feed,
##   golden_court_feed.gdshader: the calm golden face and the emblem; set_feed / set_feed_blackout switch
##   them for the later stages);
## - the vast hall beyond: a giant colonnade far out on both sides and the vault's gilded ribs arching over
##   the hall high above, fading into its warm haze (the data file sets the fog and the sky's colours).
## Nothing glows in a hazard colour: the gold is lit reflective metal, the lamps warm white, the screens the
## feed's whites and pale gold. Visual only (TrackBuilder owns every collision shape and gameplay node), and
## every variety comes from hashing track positions (MeshKit.hash_i), so a chunk looks the same whenever it's
## built. A plain track has no wall gaps, so wall_gap() draws only what wall_section() would around one.

@export_group("Grand Court")
## DESIGN-TBD (docs/questions/e5d.md, E5d-a): the balustrade along the causeway's edge.
@export_range(0.6, 2.0, 0.05, "suffix:m") var balustrade_height: float = 1.1
@export_range(0.3, 1.2, 0.05, "suffix:m") var baluster_spacing: float = 0.6
@export_range(2.0, 12.0, 0.5, "suffix:m") var post_spacing: float = 5.0
## How far below the causeway the reflecting pools lie, and their water (sRGB, dark).
@export_range(6.0, 60.0, 0.5, "suffix:m") var pool_depth: float = 22.0
@export var pool_color: Color = Color(0.05, 0.075, 0.09)
## The towers: how far apart along each side (the sides alternate, half that apart), how far out from the
## causeway's edge, and their feed screens' width (16:9) and height above the causeway. How tall they stand
## over the causeway is GoldenSkin's tower_min_height and tower_max_height (the data file's).
@export_range(40.0, 300.0, 5.0, "suffix:m") var tower_spacing: float = 120.0
@export_range(12.0, 80.0, 1.0, "suffix:m") var tower_offset: float = 30.0
@export_range(6.0, 40.0, 0.5, "suffix:m") var screen_width: float = 17.0
@export_range(6.0, 80.0, 0.5, "suffix:m") var screen_height: float = 24.0
## The hall beyond: its colonnade this far out from the edge, its columns this far apart and this tall, the
## vault's ribs this high over the causeway, one every rib_spacing.
@export_range(40.0, 300.0, 5.0, "suffix:m") var hall_offset: float = 95.0
@export_range(20.0, 200.0, 5.0, "suffix:m") var column_spacing: float = 55.0
@export_range(40.0, 300.0, 5.0, "suffix:m") var column_height: float = 135.0
@export_range(40.0, 300.0, 5.0, "suffix:m") var vault_height: float = 120.0
@export_range(60.0, 600.0, 10.0, "suffix:m") var rib_spacing: float = 160.0

## The feed's brightness on the towers' screens.
const SCREEN_BRIGHTNESS: float = 0.9
const COURT_FEED_SHADER: String = "res://scripts/bosses/golden_convergence/golden_court_feed.gdshader"

## A Fist Slam's hole's meshes by footprint and row (GoldenConvergenceHole.meshes: made once, with the fight, and
## shared by every hole of that footprint).
var hole_meshes: Dictionary = {}


## The giant screens' material: one for every tower's screen (the handles below drive it).
func court_feed_material() -> ShaderMaterial:
	if not _materials.has(&"court_feed"):
		var m := ShaderMaterial.new()
		m.shader = load(COURT_FEED_SHADER) as Shader
		m.set_shader_parameter(&"feed_emblem", CultFeed.emblem_texture())
		_materials[&"court_feed"] = m
	return _materials[&"court_feed"]


## What the towers' screens show: `mode` 0 the calm golden face and the emblem (stage 1), 1 The Magnate (stage
## 2, E5d-d); `power` 1 on, 0 dark; `glitch` 0-1.
func set_feed(mode: int, power: float = 1.0, glitch: float = 0.0) -> void:
	var m: ShaderMaterial = court_feed_material()
	m.set_shader_parameter(&"feed_mode", float(mode))
	m.set_shader_parameter(&"feed_power", clampf(power, 0.0, 1.0))
	m.set_shader_parameter(&"feed_glitch", clampf(glitch, 0.0, 1.0))


## Every screen within `radius` of `center` (world space) goes dark (E5d-d's defeat: "the screens on the
## towers glitch and go dark, one after another outward"); a negative radius: none.
func set_feed_blackout(center: Vector3, radius: float) -> void:
	var m: ShaderMaterial = court_feed_material()
	m.set_shader_parameter(&"blackout_center", center)
	m.set_shader_parameter(&"blackout_radius", radius)


## Back to the stage 1 broadcast, every screen on (a fight's start: the skin is shared by every run).
func reset_feed() -> void:
	set_feed(0, 1.0, 0.0)
	set_feed_blackout(Vector3.ZERO, -1.0)


## What the screens show now: {mode, power, glitch, blackout_radius} (tests).
func feed_state() -> Dictionary:
	var m: ShaderMaterial = court_feed_material()
	return {"mode": int(m.get_shader_parameter(&"feed_mode")), "power": float(m.get_shader_parameter(&"feed_power")),
		"glitch": float(m.get_shader_parameter(&"feed_glitch")),
		"blackout_radius": float(m.get_shader_parameter(&"blackout_radius"))}


func wall_section(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	_wall_x = absf(face_x)
	var batch := MeshBatch.new()
	_balustrade(batch, side, face_x, start, end)
	_pools(batch, side, face_x, start, end)
	for t: Dictionary in towers(side, face_x, start, end):
		_tower(batch, t)
	_hall(batch, side, face_x, start, end)
	if side < 0:
		palace_floor().below(batch, absf(face_x), start, end)
	batch.commit(parent)


## E5d-b: a floor cut in the Grand Court is a Fist Slam's hole (its plain laps have none of their own). A slam
## cuts every lane of its row but opens only its footprint's, so nothing is drawn here when the track builds a cut
## (E5d polish: no meshes in the chunk's frame, no hidden inside under the floor): the slam draws the whole square
## hole as it opens (GoldenConvergenceHole.open), from meshes made with the fight (hole_meshes).
func floor_cut(_parent: Node3D, _cut: FloorCutSection) -> void:
	pass


## No wall gaps on a boss's track (BossArena): the court around one is drawn all the same.
func wall_gap(parent: Node3D, side: int, face_x: float, start: float, end: float, _gap: Vector2) -> void:
	wall_section(parent, side, face_x, start, end)


## No niches: the court has no walls for a Gilded Sentinel.
func note_wall_enemies(side: int, _start: float, _end: float, _enemies: Array[Dictionary]) -> void:
	_niches[side] = []


func statue_spots(_side: int, _face_x: float, _start: float, _end: float) -> Array[Dictionary]:
	return []


func cult_emblems(_side: int, _face_x: float, _start: float, _end: float) -> Array[Dictionary]:
	return []


## The towers' feed screens whose middles lie between two track distances (kind &"tower"), as
## GoldenSkin.feed_boards lists them: side, at, kind, width, height, center.
func feed_boards(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in towers(side, face_x, start, end):
		out.append({"side": side, "at": t["at"], "kind": &"tower", "width": screen_width,
			"height": screen_width * 9.0 / 16.0, "center": t["screen_center"]})
	return out


## The towers on `side` whose middles lie in [start, end): {side, at, x (their middle), height, radius,
## screen_center, screen_u, screen_v} (world space).
func towers(side: int, face_x: float, start: float, end: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var spacing: float = maxf(tower_spacing, 10.0)
	var shift: float = 0.0 if side < 0 else spacing * 0.5
	var k: int = floori((start - shift) / spacing)
	while float(k) * spacing + shift < end:
		var at: float = float(k) * spacing + shift
		if at >= start:
			var h01: float = MeshKit.hash01(k, side, 701)
			var height: float = lerpf(tower_min_height, tower_max_height, h01)
			var radius: float = lerpf(6.0, 8.5, MeshKit.hash01(k, side, 709))
			var x: float = side * (absf(face_x) + tower_offset + radius + 6.0 * MeshKit.hash01(k, side, 719))
			# The screen on the tower's face toward the causeway, turned to the approaching runner.
			var w: float = screen_width
			var h: float = screen_width * 9.0 / 16.0
			var turn: float = side * 0.55
			var face := Basis(Vector3.UP, turn) * Vector3(-float(side), 0.0, 0.0)
			# Its width to the viewer's right as they face it (so the picture reads the right way round).
			var u: Vector3 = Vector3.UP.cross(face).normalized()
			var center := Vector3(x, screen_height + h * 0.5, -at) + face * (radius + 1.2)
			out.append({"side": side, "at": at, "x": x, "height": height, "radius": radius, "index": k,
				"screen_center": center, "screen_u": u * w, "screen_v": Vector3(0.0, h, 0.0), "screen_face": face})
		k += 1
	return out


## The balustrade along the causeway's edge on `side`, its inner face just inside the wall's line.
func _balustrade(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(solid_material())
	var g: MeshLayer = batch.layer(glow_material())
	var x_in: float = face_x - side * 0.02
	var depth: float = 0.55
	var xc: float = x_in + side * depth * 0.5
	var mid: float = -(start + end) * 0.5
	var length: float = end - start
	var h: float = balustrade_height
	# The plinth and the rail.
	s.box(Vector3(xc, 0.13, mid), Vector3(depth, 0.26, length), stone_colors[0], 0.0, MeshKit.PAT_MARBLE,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 1.0)
	s.box(Vector3(xc, h - 0.08, mid), Vector3(depth * 0.8, 0.16, length), gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 0.85)
	# The balusters: gold, waisted, between the plinth and the rail.
	var spacing: float = maxf(baluster_spacing, 0.2)
	var n0: int = ceili(start / spacing)
	var post: float = maxf(post_spacing, 1.0)
	var d: float = float(n0) * spacing
	while d < end:
		var near_post: bool = absf(d - roundf(d / post) * post) < 0.45
		if not near_post:
			s.prism(Vector3(xc, 0.26, -d), 0.11, (h - 0.42) * 0.45, 4, gold_color, 0.0, MeshKit.PAT_GOLD, false, 0.8)
			s.prism(Vector3(xc, 0.26 + (h - 0.42) * 0.45, -d), 0.07, (h - 0.42) * 0.55, 4, gold_color, 0.0, MeshKit.PAT_GOLD,
				false, 0.8)
		d += spacing
	# The posts, each with a warm-white lamp.
	var p0: int = ceili(start / post)
	var pd: float = float(p0) * post
	while pd < end:
		s.box(Vector3(xc, h * 0.5 + 0.08, -pd), Vector3(depth * 0.95, h + 0.16, 0.5), stone_colors[1], 0.0,
			MeshKit.PAT_MARBLE, MeshKit.ALL_FACES & ~MeshKit.FACE_NY, 1.0)
		s.prism(Vector3(xc, h + 0.16, -pd), 0.16, 0.22, 6, gold_color, 0.0, MeshKit.PAT_GOLD, true, 0.85)
		s.box(Vector3(xc, h + 0.48, -pd), Vector3(0.24, 0.24, 0.24), lamp_color, 0.9)
		g.rect(Vector3(xc - 0.5, h + 0.0, -pd), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), lamp_color, 0.25, MeshKit.SHAPE_RADIAL)
		pd += post
	# The cornice outside it, where the causeway's edge drops away to the pools.
	s.box(Vector3(x_in + side * (depth + 0.35), -0.2, mid), Vector3(0.7, 0.4, length), gold_color, 0.0, MeshKit.PAT_GOLD,
		MeshKit.ALL_FACES, 0.7)
	var z0: float = -start if side > 0 else -end
	s.rect(Vector3(x_in + side * (depth + 0.7), -pool_depth, z0), Vector3(0, 0, -length * side),
		Vector3(0, pool_depth - 0.4, 0), stone_colors[2], 0.0, MeshKit.PAT_MARBLE, Vector2.ZERO, Vector2.ONE, 0.0)


## The reflecting pools far below on `side`, from the causeway's edge out past the towers.
func _pools(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(solid_material())
	var x0: float = face_x + side * 1.0
	var x1: float = face_x + side * (hall_offset + 40.0)
	var lo: float = minf(x0, x1)
	var hi: float = maxf(x0, x1)
	s.rect(Vector3(lo, -pool_depth, -start), Vector3(hi - lo, 0, 0), Vector3(0, 0, -(end - start)), pool_color, 0.0,
		MeshKit.PAT_CANAL)


## A tower out of the pools (`t` from towers()): an octagonal marble shaft with gold bands and lit windows,
## a setback, a gold crown and spire, and its giant feed screen in a gilded frame.
func _tower(batch: MeshBatch, t: Dictionary) -> void:
	var s: MeshLayer = batch.layer(solid_material())
	var f: MeshLayer = batch.layer(court_feed_material())
	var x: float = float(t["x"])
	var at: float = float(t["at"])
	var r: float = float(t["radius"])
	var h: float = float(t["height"])
	var base := Vector3(x, -pool_depth, -at)
	var shaft: float = h + pool_depth
	s.prism(base, r, shaft * 0.72, 8, stone_colors[0], 0.0, MeshKit.PAT_MARBLE, false, 0.0)
	s.prism(base + Vector3(0.0, shaft * 0.72, 0.0), r * 0.78, shaft * 0.28, 8, stone_colors[3], 0.0, MeshKit.PAT_MARBLE, false, 0.0)
	# Gold bands every so often, and the lit windows between them (warm white, a few).
	var y: float = -pool_depth + 10.0
	var k: int = 0
	while y < h - 4.0:
		var rr: float = r if y < -pool_depth + shaft * 0.72 else r * 0.78
		s.prism(Vector3(x, y, -at), rr + 0.18, 0.7, 8, gold_color, 0.0, MeshKit.PAT_GOLD, true, 0.8)
		if MeshKit.hash01(int(t["index"]), k, 733) < 0.45 and y > 4.0:
			for q: int in 3:
				var a: float = TAU * (float(q) + 0.5 + float(k % 2) * 0.5) / 8.0 + PI * (0.0 if x < 0.0 else 1.0)
				var dir := Vector3(cos(a), 0.0, sin(a))
				s.box(Vector3(x, y + 3.6, -at) + dir * (rr + 0.04), Vector3(1.0, 2.4, 1.0), window_warm_color, 0.7)
		y += 9.0
		k += 1
	# The crown: a gold dome and a spire with a ring.
	s.prism(Vector3(x, h, -at), r * 0.9, 1.2, 8, gold_color, 0.0, MeshKit.PAT_GOLD, true, 0.85)
	s.prism_xform(Transform3D(Basis.from_scale(Vector3(r * 0.7, 6.0, r * 0.7)), Vector3(x, h + 1.2, -at)), 8, gold_color, 0.0,
		MeshKit.PAT_GOLD, true, 0.9)
	s.prism(Vector3(x, h + 7.2, -at), 0.6, 14.0, 6, gold_color, 0.0, MeshKit.PAT_GOLD, true, 0.9)
	# The giant screen, framed in gold, on a bracket from the tower, turned to the approaching runner.
	var c: Vector3 = t["screen_center"]
	var u: Vector3 = t["screen_u"]
	var v: Vector3 = t["screen_v"]
	var face: Vector3 = t["screen_face"]
	var origin: Vector3 = c - u * 0.5 - v * 0.5
	_screen_frame(s, c, u, v, face)
	# The bracket holding it off the tower.
	var tower_mid := Vector3(x, c.y, -at)
	s.box_xform(Transform3D(Basis.looking_at((c - tower_mid).normalized(), Vector3.UP) * Basis.from_scale(Vector3(2.0, 2.0,
		tower_mid.distance_to(c))), (tower_mid + c) * 0.5), gold_color.darkened(0.2), 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.6)
	f.rect(origin + face * 0.06, u, v, Color.WHITE, SCREEN_BRIGHTNESS, 0, Vector2.ZERO, Vector2.ONE, u.length() / maxf(v.length(), 0.01))


## A gilded frame around a screen centred at `c` (`u` its width, `v` its height, facing `face`), and its dark
## back panel behind the picture.
func _screen_frame(s: MeshLayer, c: Vector3, u: Vector3, v: Vector3, face: Vector3) -> void:
	var rim: float = 0.9
	var w: float = u.length()
	var h: float = v.length()
	var ux: Vector3 = u / maxf(w, 0.01)
	var vy: Vector3 = v / maxf(h, 0.01)
	var basis := Basis(ux, vy, face)
	s.box_xform(Transform3D(basis * Basis.from_scale(Vector3(w + rim * 2.0, h + rim * 2.0, 0.6)), c - face * 0.3),
		Color(0.08, 0.07, 0.06), 0.0, MeshKit.PAT_PLAIN, MeshKit.ALL_FACES)
	for edge: Array in [[0.0, 0.5, w + rim * 2.0, rim], [0.0, -0.5, w + rim * 2.0, rim], [0.5, 0.0, rim, h], [-0.5, 0.0, rim, h]]:
		var ex: float = float(edge[0])
		var ey: float = float(edge[1])
		var center: Vector3 = c + ux * (ex * (w + rim)) + vy * (ey * (h + rim)) + face * 0.15
		s.box_xform(Transform3D(basis * Basis.from_scale(Vector3(float(edge[2]), float(edge[3]), 0.5)), center), gold_color,
			0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.85)
	# A crest over it: the cult's halo in gold.
	s.box_xform(Transform3D(basis * Basis.from_scale(Vector3(w * 0.3, rim * 1.4, 0.5)), c + vy * (h * 0.5 + rim * 1.6) + face * 0.15),
		gold_color, 0.0, MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.85)


## The vast hall beyond on `side`: its colonnade far out (giant columns with gold capitals) and, from the
## left side's chunks, the vault's gilded ribs arching over the hall.
func _hall(batch: MeshBatch, side: int, face_x: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(solid_material())
	var x: float = face_x + side * hall_offset
	var spacing: float = maxf(column_spacing, 5.0)
	var k: int = ceili(start / spacing)
	var d: float = float(k) * spacing
	while d < end:
		var base := Vector3(x, -pool_depth, -d)
		s.prism(base, 5.0, column_height + pool_depth, 10, stone_colors[0], 0.0, MeshKit.PAT_MARBLE, false, 0.0)
		s.prism(base + Vector3(0.0, column_height + pool_depth, 0.0), 7.0, 5.0, 10, gold_color, 0.0, MeshKit.PAT_GOLD, true, 0.7)
		d += spacing
	if side > 0:
		return
	var rib: float = maxf(rib_spacing, 20.0)
	var rk: int = ceili(start / rib)
	var rd: float = float(rk) * rib
	while rd < end:
		var steps: int = 14
		var half: float = absf(face_x) + hall_offset
		var prev := Vector3.ZERO
		for i: int in steps + 1:
			var a: float = PI * float(i) / steps
			var p := Vector3(-cos(a) * half, column_height + sin(a) * (vault_height * 0.55), -rd)
			if i > 0:
				var mid: Vector3 = (prev + p) * 0.5
				var along: Vector3 = p - prev
				var basis := Basis.looking_at(along.normalized(), Vector3.BACK)
				s.box_xform(Transform3D(basis * Basis.from_scale(Vector3(4.0, 3.0, along.length() + 0.5)), mid), gold_color, 0.0,
					MeshKit.PAT_GOLD, MeshKit.ALL_FACES, 0.6)
			prev = p
		rd += rib
