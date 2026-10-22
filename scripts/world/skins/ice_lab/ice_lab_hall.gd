class_name IceLabHall
extends RefCounted
## The Ice Lab's hall (IceLabSkin, GDD §5, proposed: "an indoor frozen hall with no sky, like the Terminal's vault: cold fog, ice walls
## behind the machinery, small amber machine lamps"; the reference image's cranes and chains hanging in the distance): everything the
## runner sees over and beyond the walls, drawn with the left wall's mesh (a chunk's wall pieces and wall gaps' extras both call it, so it
## is drawn once however the walls are cut; things are anchored to a track distance and drawn by the piece that holds it):
## - the frozen floor far below the street (PAT_IL_UNDER, mode 2), under every lane and every hole;
## - the far ice walls, hall_extra beyond the street's wall lines, tall, with now and then a cluster of big pale crystals growing out of
##   them (a share by the lean: more in the snow and industry level);
## - the crane runways, two beams along the track a side at the skin's crane_height, with cross girders every girder_pitch metres
##   spanning the street, each hanging an icicle fringe, a crane trolley, a chain down to a hook (never lower than 9.5 m, over every
##   ceiling's top) and a small amber lamp; pillars in the hall beyond the wall (steel, snow-capped, in the fog);
## - the roof (GDD §5: "an indoor frozen hall with no sky, like the Terminal's vault"): a dim underside of dark steel and ice at the skin's
##   roof_height over the whole hall, a truss across it every ROOF_PITCH metres with great icicles hanging from them, so the hall is closed
##   overhead and the dark above the cranes reads as a roof, never a night sky;
## - snow drifting down, puffs of cold mist and speed streaks (the still floor's motion cues: kit drift shader).
## None of it is in the play space (nothing below crane_height - 7 over the street), nothing of it glows but the small lamps, and
## nothing flickers. Chunk space: x across, y up (the street at y = 0), z = -distance.

## The lowest a chain's hook hangs (over every ceiling's top, a hull's thickness and the gantry's rise above it).
const HOOK_MIN: float = 9.6
## The tallest the far wall reaches (over the roof, which closes the hall).
const FAR_TOP: float = 34.0
## The roof's trusses across the hall, every this many metres, and their depth.
const ROOF_PITCH: float = 10.0
const ROOF_TRUSS: float = 1.3

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: IceLabSkin:
	get:
		return _skin.get_ref() as IceLabSkin
var _skin: WeakRef
var _parts: IceLabParts


func _init(p_skin: IceLabSkin) -> void:
	_skin = weakref(p_skin)
	_parts = IceLabParts.new(p_skin)


## Adds the hall over the part of the track between two distances (the wall pieces and gaps tile every chunk, so each anchored item is
## built exactly once), for a street whose wall faces stand `wall_x` from the middle.
func build(batch: MeshBatch, wall_x: float, start: float, end: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	_floor(s, wall_x, start, end)
	_far_walls(s, wall_x, start, end)
	_runways(s, wall_x, start, end)
	_girders(s, g, wall_x, start, end)
	_pillars(s, wall_x, start, end)
	_roof(s, wall_x, start, end)
	_crystal_clusters(s, wall_x, start, end)
	_motion(batch, wall_x, start, end)


## The frozen floor across the street, a metre past each wall line.
func _floor(s: MeshLayer, wall_x: float, start: float, end: float) -> void:
	s.rect(Vector3(-wall_x, -skin.pit_depth, -start), Vector3(wall_x * 2.0, 0.0, 0.0), Vector3(0.0, 0.0, -(end - start)),
		skin.pit_floor_color, 0.0, MeshKit.PAT_IL_UNDER, Vector2.ZERO, Vector2.ONE, 2.0)


## The far ice walls on both sides, facing the street, from the frozen floor up.
func _far_walls(s: MeshLayer, wall_x: float, start: float, end: float) -> void:
	var x: float = wall_x + skin.hall_extra
	var color: Color = skin.ice_color.darkened(0.5)
	var y0: float = -skin.pit_depth
	s.rect(Vector3(-x, y0, -start), Vector3(0.0, 0.0, -(end - start)), Vector3(0.0, FAR_TOP - y0, 0.0), color, 0.0, MeshKit.PAT_IL_ICE,
		Vector2(start, y0), Vector2(end, FAR_TOP), 0.0)
	s.rect(Vector3(x, y0, -end), Vector3(0.0, 0.0, end - start), Vector3(0.0, FAR_TOP - y0, 0.0), color, 0.0, MeshKit.PAT_IL_ICE,
		Vector2(start, y0), Vector2(end, FAR_TOP), 0.0)


## The crane runways: a beam along the track a side over the street's edge and another beyond the wall, at crane_height.
func _runways(s: MeshLayer, wall_x: float, start: float, end: float) -> void:
	var y: float = skin.crane_height
	var len: float = end - start
	var zc: float = -(start + end) * 0.5
	for side: float in [-1.0, 1.0]:
		for x: float in [wall_x - 0.9, wall_x + 3.6]:
			s.box(Vector3(side * x, y, zc), Vector3(0.7, 1.0, len), skin.steel_color.lightened(0.04), 0.0, MeshKit.PAT_IL_STEEL,
				MeshKit.ALL_FACES, 0.0)
			s.box(Vector3(side * x, y + 0.5 + 0.03, zc), Vector3(0.5, 0.06, len), skin.snow_color, 0.0, MeshKit.PAT_IL_SNOW,
				MeshKit.FACE_PY | MeshKit.FACE_PX | MeshKit.FACE_NX, 0.0)


## The cross girders every girder_pitch metres, each with its trolley, chain and hook, icicles and lamp.
func _girders(s: MeshLayer, g: MeshLayer, wall_x: float, start: float, end: float) -> void:
	var pitch: float = skin.girder_pitch
	var k: int = ceili(start / pitch - 0.5 - 0.0001)
	var y: float = skin.crane_height
	while (float(k) + 0.5) * pitch < end:
		var at: float = (float(k) + 0.5) * pitch
		if at >= start:
			var z: float = -at
			var half: float = wall_x + 3.9
			var h: int = MeshKit.hash_i(k, 11, 501)
			# The girder across: a box beam with a web's lines (steel plating), snow along its top.
			s.box(Vector3(0.0, y + 0.55, z), Vector3(half * 2.0, 0.9, 0.9), skin.steel_color.lightened(0.06), 0.0, MeshKit.PAT_IL_STEEL,
				MeshKit.ALL_FACES, 0.0)
			s.box(Vector3(0.0, y + 1.03, z), Vector3(half * 2.0 - 1.0, 0.08, 0.7), skin.snow_color, 0.0, MeshKit.PAT_IL_SNOW,
				MeshKit.FACE_PY | MeshKit.FACE_PZ | MeshKit.FACE_NZ, 0.0)
			# A fringe of icicles along its underside.
			for i: int in 6:
				var ix: float = lerpf(-half + 1.0, half - 1.0, (float(i) + MeshKit.hash01(h, i, 502)) / 6.0)
				_parts.spike(s, Vector3(ix, y + 0.1, z + 0.35 * (MeshKit.hash01(h, i, 503) - 0.5)), Vector3(0.0, -1.0, 0.0),
					0.5 + 1.8 * pow(MeshKit.hash01(h, i, 504), 1.6), 0.06 + 0.06 * MeshKit.hash01(h, i, 505), 3, skin.crystal_color,
					MeshKit.PAT_IL_ICE, 1.0, 0.0)
			# The trolley, its chain and hook.
			var tx: float = (MeshKit.hash01(h, 1, 506) - 0.5) * wall_x * 1.4
			s.box(Vector3(tx, y - 0.3, z), Vector3(1.8, 0.6, 1.3), skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL, MeshKit.ALL_FACES, 0.0)
			var drop: float = minf(2.2 + 3.6 * MeshKit.hash01(h, 2, 507), y - 0.6 - HOOK_MIN)
			if drop > 0.5:
				var chain := Transform3D(Basis.from_scale(Vector3(0.05, drop, 0.05)), Vector3(tx, y - 0.6 - drop, z))
				s.prism_xform(chain, 4, skin.steel_color.lightened(0.15), 0.0, MeshKit.PAT_IL_STEEL, false, 3.0)
				s.box(Vector3(tx, y - 0.6 - drop - 0.2, z), Vector3(0.36, 0.4, 0.36), skin.frame_color, 0.0, MeshKit.PAT_IL_STEEL,
					MeshKit.ALL_FACES, 0.0)
				# Now and then a load on the hook: a crate of lab supplies, snow on its lid.
				if MeshKit.hash01(h, 3, 508) < 0.4 and drop > 1.5:
					s.box(Vector3(tx, y - 0.6 - drop - 1.0, z), Vector3(1.3, 0.9, 1.3), skin.enamel_color, 0.0, MeshKit.PAT_IL_PANEL,
						float(MeshKit.IL_PANEL_CABINET + 4 * (h % 100)), MeshKit.ALL_FACES)
					s.box(Vector3(tx, y - 0.6 - drop - 0.52, z), Vector3(1.3, 0.07, 1.3), skin.snow_color, 0.0, MeshKit.PAT_IL_SNOW,
						MeshKit.FACE_PY, 0.0)
			# A small amber lamp under the girder, on one side or the other.
			if MeshKit.hash01(h, 4, 509) < skin.lamp_share + 0.25:
				var lx: float = (wall_x * 0.55) * (1.0 if MeshKit.hash01(h, 5, 510) < 0.5 else -1.0)
				_hang_lamp(s, g, Vector3(lx, y - 0.1, z + 0.5), h)
		k += 1


## A small amber lamp hanging at `at` (a bulkhead light in a cage): a dim glowing box and a faint halo card facing along the track.
func _hang_lamp(s: MeshLayer, g: MeshLayer, at: Vector3, seed: int) -> void:
	s.box(at + Vector3(0.0, -0.18, 0.0), Vector3(0.5, 0.3, 0.5), skin.steel_color, 0.0, MeshKit.PAT_IL_STEEL, MeshKit.ALL_FACES, 2.0)
	s.box(at + Vector3(0.0, -0.2, 0.0), Vector3(0.4, 0.22, 0.4), skin.lamp_color, skin.lamp_tube_glow(), MeshKit.PAT_IL_LAMP,
		MeshKit.ALL_FACES, float(seed % 1000))
	g.rect(at + Vector3(-0.8, -1.0, 0.3), Vector3(1.6, 0.0, 0.0), Vector3(0.0, 1.6, 0.0), skin.lamp_color, 0.12, MeshKit.SHAPE_RADIAL,
		Vector2.ZERO, Vector2.ONE, MeshKit.near_fade(14.0))


## Steel pillars standing in the hall beyond each wall, from the frozen floor up to the roof: dark shapes in the fog.
func _pillars(s: MeshLayer, wall_x: float, start: float, end: float) -> void:
	var pitch: float = skin.girder_pitch * 0.5
	var k: int = ceili(start / pitch - 0.0001)
	var y0: float = -skin.pit_depth
	var y1: float = skin.roof_height
	while float(k) * pitch < end:
		var at: float = float(k) * pitch
		if at >= start:
			for side: float in [-1.0, 1.0]:
				var x: float = side * (wall_x + 3.6 + 2.2 * MeshKit.hash01(k, int(side), 511))
				s.box(Vector3(x, (y0 + y1) * 0.5, -at), Vector3(0.9, y1 - y0, 0.9), skin.steel_color, 0.0, MeshKit.PAT_IL_STEEL,
					MeshKit.ALL_FACES, 0.0)
		k += 1


## The roof: the underside of the hall over both far walls (dim steel with a touch of ice, PAT_IL_STEEL's underside: beams every 3 m), a truss
## across it every ROOF_PITCH metres and a few great icicles hanging from each truss. Dim by design: it only has to close the hall.
func _roof(s: MeshLayer, wall_x: float, start: float, end: float) -> void:
	var y: float = skin.roof_height
	var x: float = wall_x + skin.hall_extra
	var color: Color = skin.steel_color.lerp(skin.ice_color, 0.2)
	# Facing down: its normal is u x v.
	s.rect(Vector3(-x, y, -start), Vector3(0.0, 0.0, -(end - start)), Vector3(x * 2.0, 0.0, 0.0), color, 0.0, MeshKit.PAT_IL_STEEL,
		Vector2.ZERO, Vector2.ONE, 1.0)
	var k: int = ceili(start / ROOF_PITCH - 0.0001)
	while float(k) * ROOF_PITCH < end:
		var at: float = float(k) * ROOF_PITCH
		if at >= start:
			s.box(Vector3(0.0, y - ROOF_TRUSS * 0.5, -at), Vector3(x * 2.0, ROOF_TRUSS, 0.8), color.lightened(0.05), 0.0, MeshKit.PAT_IL_STEEL,
				MeshKit.FACE_NY | MeshKit.FACE_PZ | MeshKit.FACE_NZ, 0.0)
			for i: int in 3:
				var ix: float = lerpf(-x + 3.0, x - 3.0, MeshKit.hash01(k, i, 515))
				_parts.spike(s, Vector3(ix, y - ROOF_TRUSS, -at), Vector3(0.0, -1.0, 0.0), 1.8 + 3.4 * MeshKit.hash01(k, i, 516),
					0.12 + 0.12 * MeshKit.hash01(k, i, 517), 3, skin.ice_color.lightened(0.12), MeshKit.PAT_IL_ICE, 1.0, 0.0)
		k += 1


## Clusters of big pale crystals growing out of the far walls (the reference image's crystals, far off and large): a share of the 40 m
## stretches a side by the lean (more in the snow and industry level), each of five to seven crystals fanning toward the street.
func _crystal_clusters(s: MeshLayer, wall_x: float, start: float, end: float) -> void:
	var share: float = skin.lean(skin.crystal_frost, skin.crystal_lab)
	var chunk: float = TrackBuilder.CHUNK_LENGTH
	var k: int = floori(start / chunk)
	while float(k) * chunk < end:
		for side: int in [-1, 1]:
			if MeshKit.hash01(k, side, 512) >= share:
				continue
			var at: float = (float(k) + 0.15 + 0.7 * MeshKit.hash01(k, side, 513)) * chunk
			if at < start or at >= end:
				continue
			var x: float = float(side) * (wall_x + skin.hall_extra - 0.1)
			var y: float = 5.0 + 11.0 * MeshKit.hash01(k, side, 514)
			_parts.crystals(s, Vector3(x, y, -at), Vector3(-float(side) * 0.9, 0.45, 0.0), 6, 4.5, 0.7, k * 3 + side, 5, 0.32)
		k += 1


## Snow drifting down, puffs of cold mist and speed streaks over the street (the still floor's motion cues: the drift material).
func _motion(batch: MeshBatch, wall_x: float, start: float, end: float) -> void:
	var snow: int = roundi(float(skin.snow_count) * (1.0 - 0.5 * skin.lab_share))
	MeshKit.drift_particles(batch.layer(skin.drift_material()), start, end, TrackBuilder.CHUNK_LENGTH, wall_x - 0.7, 8.0, snow, 0,
		skin.streak_count, PackedColorArray([skin.snow_flake_color, Color.TRANSPARENT, skin.streak_color, skin.mist_color]),
		skin.mist_count)
