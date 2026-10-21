class_name TerminalHall
extends RefCounted
## The hall the Terminal's street runs through (TerminalSkin, GDD §5: "vaulted tunnels and platforms, rusted and
## vine-covered trains, dead departure boards, cables strung everywhere, puddles and dripping water, steam, and failing orange
## work lamps"), drawn in 10 m cells from the floor's own hook, never from the walls: the arches are a few and far between,
## so the open spaces between them must still read as open, and the floor is the one piece every chunk has. Each chunk's root
## remembers which cells it holds (the `terminal_cells` meta), so a floor piece cut short by a hole, or any other hook, only
## adds the cells nothing has drawn yet.
## From the street outwards, on each side (x measured from the track's centre, W the wall face's distance):
## - a low kerb along the wall line (x from W to W + 0.5) that closes the street, so the platform lane reads as a
##   boundary;
## - a second track lying track_drop below the street from the kerb to the far wall, with subway cars parked on it in
##   stretches (a car is a box in flaking paint with a band of windows, doors, vines draped over its roof and hanging
##   down its side: PAT_TERMINAL_CAR), the cars' stretches picked by a hash of where they are;
## - the far wall at x = H = W + hall_extra: old white tile at its foot, black ashlar over it (PAT_TERMINAL_WALL), a pair of
##   rusted pipes running along it, and a work lamp every lamp_pitch;
## - the vault: an elliptical shell springing from the far walls at spring_height and rising to crown_height over the
##   middle, on steel ribs every lamp_pitch with a work lamp hung from each (the lamps' light is painted into the surfaces
##   by kit_terminal.gdshaderinc, from where the fixtures stand), dead departure boards hung from some ribs and cables strung
##   between them.
## Under the street, seen through the holes, lies the service level's floor and, on each side, the pit's wall.
## DESIGN-TBD (docs/questions/o4.md items 1, 3, 6): the hall's proportions, the kerb as the street's boundary, the scavengers.
## Chunk space: x across, y up (the street at y = 0), z = -distance.

## The cells the hall is drawn in, along the track.
const CELL: float = 10.0
const META_CELLS: StringName = &"terminal_cells"
const META_SLICES: StringName = &"terminal_slices"
## The vault is drawn in this many segments across (each one quad along a cell).
const VAULT_SEGMENTS: int = 12
## A rib's width along the track and how far it stands below the shell.
const RIB_WIDTH: float = 0.9
const RIB_DEPTH: float = 0.5
## The kerb's thickness (x).
const KERB: float = 0.5
## A subway car: its length with the gap to the next, width, and body height; its side's distance beyond the kerb.
const CAR_LENGTH: float = 16.4
const CAR_PITCH: float = 17.2
const CAR_WIDTH: float = 2.9
const CAR_HEIGHT: float = 3.3
const CAR_SETBACK: float = 0.55
## Trains are laid out in blocks this long.
const TRAIN_BLOCK: float = 90.0
## The scavengers' camps are rolled in blocks this long.
const CAMP_BLOCK: float = 130.0
## Where lamps and fixtures sit, from the shader (kit_terminal.gdshaderinc).
const LAMP_LENGTH: float = 1.9
const WALL_LAMP_SETBACK: float = 0.35

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: TerminalSkin:
	get:
		return _skin.get_ref() as TerminalSkin
var _skin: WeakRef


func _init(p_skin: TerminalSkin) -> void:
	_skin = weakref(p_skin)


## The far walls' distance from the track's centre for a street whose wall faces are `wall_x` out.
func half_width(wall_x: float) -> float:
	return wall_x + skin.hall_extra


## The vault's height over x (measured from the track's centre) in a hall `h` wide on each side.
func vault_y(x: float, h: float) -> float:
	var u: float = clampf(absf(x) / h, 0.0, 1.0)
	return skin.spring_height + (skin.crown_height - skin.spring_height) * sqrt(1.0 - u * u)


## The inward normal of the vault at x (pointing into the hall, as a unit vector in x and y).
func vault_inward(x: float, h: float) -> Vector2:
	var rise: float = skin.crown_height - skin.spring_height
	var y: float = vault_y(x, h) - skin.spring_height
	var out := Vector2(x / (h * h), y / (rise * rise))
	if out.length() < 0.00001:
		return Vector2(0.0, -1.0)
	return -out.normalized()


## Draws the cells overlapping [d0, d1) (track distances) that nothing under `parent` has drawn yet, for a street whose
## walls are `wall_x` out and whose lanes are `2 * lane_half` wide (the second track's rails and sleepers are drawn with the
## street's lanes' own pattern), as one mesh; and the chunk's drifting dust and steam, once. `parent` is the chunk's root
## (TerminalSkin.chunk_root): the hall belongs to the chunk and to no piece of floor, which a floor cut hides or shortens.
func ensure(parent: Node3D, wall_x: float, lane_half: float, d0: float, d1: float) -> void:
	if d1 <= d0 + 0.001 or wall_x <= 0.0 or lane_half <= 0.0:
		return
	var done: Dictionary = parent.get_meta(META_CELLS, {})
	var first: int = floori(d0 / CELL + 0.0001)
	var last: int = ceili(d1 / CELL - 0.0001) - 1
	var batch := MeshBatch.new()
	var run_start: int = 0
	var in_run: bool = false
	var any: bool = false
	for cell: int in range(first, last + 2):
		var fresh: bool = cell <= last and not done.has(cell)
		if fresh and not in_run:
			in_run = true
			run_start = cell
		elif not fresh and in_run:
			in_run = false
			_run(batch, wall_x, lane_half, float(run_start) * CELL, float(cell) * CELL)
			any = true
		if fresh:
			done[cell] = true
	parent.set_meta(META_CELLS, done)
	# The dust and steam drifting through the lamplight: one slice of the 40 m cut a chunk's, the first time the chunk asks.
	var slices: Dictionary = parent.get_meta(META_SLICES, {})
	var slice_first: int = floori(d0 / TrackBuilder.CHUNK_LENGTH + 0.0001)
	var slice_last: int = ceili(d1 / TrackBuilder.CHUNK_LENGTH - 0.0001) - 1
	for slice: int in range(slice_first, slice_last + 1):
		if not slices.has(slice):
			slices[slice] = true
			var a: float = float(slice) * TrackBuilder.CHUNK_LENGTH
			MeshKit.drift_particles(batch.layer(skin.drift_material()), a, a + TrackBuilder.CHUNK_LENGTH,
				TrackBuilder.CHUNK_LENGTH, wall_x - 0.7, 8.0, skin.dust_count, 0, skin.streak_count,
				PackedColorArray([skin.dust_color, Color.TRANSPARENT, skin.streak_color, skin.steam_color]), skin.steam_count)
			any = true
	parent.set_meta(META_SLICES, slices)
	if any:
		batch.commit(parent, "Hall")


## The hall between track distances d0 and d1 (cells' edges), both sides.
func _run(batch: MeshBatch, wall_x: float, lane_half: float, d0: float, d1: float) -> void:
	var s: MeshLayer = batch.layer(skin.solid_material())
	var h: float = half_width(wall_x)
	var z0: float = -d0
	var z1: float = -d1
	var length: float = d1 - d0
	var zm: float = (z0 + z1) * 0.5
	# What the holes show: the service level's floor and, along each side, the pit's wall.
	s.rect(Vector3(-wall_x, -skin.pit_depth, z0), Vector3(wall_x * 2.0, 0, 0), Vector3(0, 0, -length), skin.pit_floor_color, 0.0,
		MeshKit.PAT_TERMINAL_UNDER, Vector2.ZERO, Vector2.ONE, 2.0)
	s.rect(Vector3(-wall_x, -skin.pit_depth, z0), Vector3(0, 0, -length), Vector3(0, skin.pit_depth, 0), skin.gap_inside_color, 0.0,
		MeshKit.PAT_TERMINAL_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	s.rect(Vector3(wall_x, -skin.pit_depth, z1), Vector3(0, 0, length), Vector3(0, skin.pit_depth, 0), skin.gap_inside_color, 0.0,
		MeshKit.PAT_TERMINAL_UNDER, Vector2.ZERO, Vector2.ONE, 1.0)
	for side: int in [-1, 1]:
		_side(s, side, wall_x, lane_half, h, d0, d1)
	_steam(batch.layer(skin.smoke_material()), wall_x, h, d0, d1)
	_vault(batch, s, wall_x, h, d0, d1)


## Plumes of steam leaking from the old pipes beyond the walls: a soft column of smoke rising from the second track, widening and
## thinning as it climbs (the kit's smoke shader, dead_smoke.gdshader: alpha-blended and unbanded, it never glows, flickers or
## flashes, and nothing about it is a light column like a pad's beam), now and then in a cell. Scenery only, beyond the kerb.
func _steam(smoke: MeshLayer, wall_x: float, h: float, d0: float, d1: float) -> void:
	var color := Color(skin.steam_jet_color, skin.plume_opacity())
	var first: int = floori(d0 / CELL + 0.0001)
	var last: int = ceili(d1 / CELL - 0.0001) - 1
	for cell: int in range(first, last + 1):
		for side: int in [-1, 1]:
			if MeshKit.hash01(cell, side, 411) >= skin.jet_share:
				continue
			var x: float = float(side) * lerpf(wall_x + 4.6, h - 1.0, MeshKit.hash01(cell, side, 412))
			var z: float = -(float(cell) + MeshKit.hash01(cell, side, 413)) * CELL
			var base := Vector3(x, -skin.track_drop + 0.1, z)
			var width: float = 1.6 + 1.0 * MeshKit.hash01(cell, side, 414)
			var height: float = 4.4 + 2.4 * MeshKit.hash01(cell, side, 415)
			# One quad whose six vertices all sit at the column's base; the shader spreads them out.
			smoke.verts.append_array(PackedVector3Array([base, base, base, base, base, base]))
			smoke.colors.append_array(PackedColorArray([color, color, color, color, color, color]))
			smoke.uvs.append_array(PackedVector2Array([Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1),
				Vector2(1, -1)]))
			var size := Vector2(width, height)
			smoke.uv2s.append_array(PackedVector2Array([size, size, size, size, size, size]))


## One side's kerb, second track, cars, far wall, pipes and lamps.
func _side(s: MeshLayer, side: int, wall_x: float, lane_half: float, h: float, d0: float, d1: float) -> void:
	var sd: float = float(side)
	var z0: float = -d0
	var z1: float = -d1
	var length: float = d1 - d0
	var zm: float = (z0 + z1) * 0.5
	var drop: float = skin.track_drop
	# The kerb along the wall line.
	s.box(Vector3(sd * (wall_x + KERB * 0.5), skin.kerb_height * 0.5, zm), Vector3(KERB, skin.kerb_height, length),
		skin.concrete_color, 0.0, MeshKit.PAT_TERMINAL_WALL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY, 2.0)
	# The second track, from the kerb to the far wall, its rails under the cars' middle.
	var bed_in: float = wall_x + KERB
	var car_x: float = bed_in + CAR_SETBACK + CAR_WIDTH * 0.5
	var xa: float = minf(sd * bed_in, sd * h)
	var xb: float = maxf(sd * bed_in, sd * h)
	var rail_c: float = sd * car_x
	s.rect(Vector3(xa, -drop, z0), Vector3(xb - xa, 0, 0), Vector3(0, 0, -length), skin.ballast_color.darkened(0.12), 0.0,
		MeshKit.PAT_TERMINAL_TRACK, Vector2((xa - rail_c) / lane_half, 0.0), Vector2((xb - rail_c) / lane_half, length),
		TerminalTrack.half_width_param(lane_half))
	# The far wall: tile and ashlar, from the second track up to where the vault springs.
	var y_top: float = skin.spring_height
	if side < 0:
		s.rect(Vector3(-h, -drop, z0), Vector3(0, 0, -length), Vector3(0, y_top + drop, 0), skin.stone_color, 0.0,
			MeshKit.PAT_TERMINAL_WALL, Vector2.ZERO, Vector2.ONE, 0.0)
	else:
		s.rect(Vector3(h, -drop, z1), Vector3(0, 0, length), Vector3(0, y_top + drop, 0), skin.stone_color, 0.0,
			MeshKit.PAT_TERMINAL_WALL, Vector2.ZERO, Vector2.ONE, 0.0)
	# Two rusted pipes along the far wall.
	for py: float in [2.9, 3.75]:
		s.box(Vector3(sd * (h - 0.2), py, zm), Vector3(0.3, 0.3, length), skin.steel_color.lerp(skin.rust_color, 0.5), 0.0,
			MeshKit.PAT_TERMINAL_STEEL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_NY, 0.0)
	_cars(s, side, car_x, d0, d1)
	_wall_lamps(s, side, h, d0, d1)
	_camps(s, side, wall_x, h, d0, d1)


## The subway cars parked on the second track whose near ends lie in [d0, d1): trains of up to train_cars cars in blocks of
## TRAIN_BLOCK, a block with a train or not by hash. Each is drawn once, by the cell its near end lies in.
func _cars(s: MeshLayer, side: int, car_x: float, d0: float, d1: float) -> void:
	var sd: float = float(side)
	var first: int = floori((d0 - CAR_PITCH * skin.train_cars) / TRAIN_BLOCK)
	var last: int = floori(d1 / TRAIN_BLOCK)
	for block: int in range(first, last + 1):
		if MeshKit.hash01(block, side, 301) >= skin.train_share:
			continue
		var cars: int = 1 + MeshKit.hash_i(block, side, 302) % skin.train_cars
		var slack: float = maxf(TRAIN_BLOCK - float(cars) * CAR_PITCH, 0.0)
		var start: float = float(block) * TRAIN_BLOCK + slack * MeshKit.hash01(block, side, 303)
		for c: int in cars:
			var near_d: float = start + float(c) * CAR_PITCH
			if near_d < d0 or near_d >= d1:
				continue
			_car(s, side, car_x, near_d, MeshKit.hash_i(block, side, c + 310))


## One car: a box in flaking paint on the second track, its street-facing side with windows and doors (PAT_TERMINAL_CAR), its
## near end blank with a dark cab window, its roof rounded off with a second, narrower box and draped in vine, vines hanging
## down its side.
func _car(s: MeshLayer, side: int, car_x: float, near_d: float, k: int) -> void:
	var sd: float = float(side)
	var drop: float = skin.track_drop
	var y0: float = -drop + 0.6
	var y1: float = y0 + CAR_HEIGHT
	var x_in: float = sd * (car_x - CAR_WIDTH * 0.5)
	var x_out: float = sd * (car_x + CAR_WIDTH * 0.5)
	var color: Color = skin.car_colors[k % skin.car_colors.size()]
	var seed: float = float(k % 100)
	var zn: float = -near_d
	var zf: float = -(near_d + CAR_LENGTH)
	# The street-facing side, UV in metres along the car and up from its floor.
	if side < 0:
		s.rect(Vector3(x_in, y0, zn), Vector3(0, 0, -CAR_LENGTH), Vector3(0, CAR_HEIGHT, 0), color, 0.0,
			MeshKit.PAT_TERMINAL_CAR, Vector2(0, 0), Vector2(CAR_LENGTH, CAR_HEIGHT), seed)
	else:
		s.rect(Vector3(x_in, y0, zf), Vector3(0, 0, CAR_LENGTH), Vector3(0, CAR_HEIGHT, 0), color, 0.0,
			MeshKit.PAT_TERMINAL_CAR, Vector2(0, 0), Vector2(CAR_LENGTH, CAR_HEIGHT), seed)
	# The roof and the near end.
	var xm: float = (x_in + x_out) * 0.5
	var zm: float = (zn + zf) * 0.5
	s.box(Vector3(xm, y1 + 0.04, zm), Vector3(CAR_WIDTH, 0.08, CAR_LENGTH), color.darkened(0.2), 0.0, MeshKit.PAT_TERMINAL_STEEL,
		MeshKit.FACE_PY, 0.0)
	s.box(Vector3(xm, y1 + 0.2, zm), Vector3(CAR_WIDTH * 0.7, 0.25, CAR_LENGTH * 0.96), color.darkened(0.3), 0.0,
		MeshKit.PAT_TERMINAL_STEEL, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
	s.box(Vector3(xm, (y0 + y1) * 0.5, zn), Vector3(CAR_WIDTH, CAR_HEIGHT, 0.02), color.darkened(0.15), 0.0,
		MeshKit.PAT_TERMINAL_STEEL, MeshKit.FACE_PZ, 0.0)
	s.box(Vector3(xm, y0 + 2.0, zn + 0.015), Vector3(1.0, 0.8, 0.02), Color(0.02, 0.025, 0.025), 0.0, MeshKit.PAT_PLAIN,
		MeshKit.FACE_PZ)
	# Vine draped over the roof, in clumps, and hanging down the side facing the street.
	var clumps: int = 2 + k % 3
	for i: int in clumps:
		var cz: float = zn - CAR_LENGTH * (0.1 + 0.8 * MeshKit.hash01(k, i, 321))
		var cx: float = xm + sd * (CAR_WIDTH * 0.3) * (MeshKit.hash01(k, i, 322) * 2.0 - 1.0)
		var cl: float = 1.4 + 2.6 * MeshKit.hash01(k, i, 323)
		s.box(Vector3(cx, y1 + 0.5, cz), Vector3(1.2 + 0.6 * MeshKit.hash01(k, i, 324), 0.5, cl), skin.vine_color, 0.0,
			MeshKit.PAT_TERMINAL_VINE, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ)
	for i: int in 3:
		var vz: float = zn - CAR_LENGTH * (0.08 + 0.84 * MeshKit.hash01(k, i, 331))
		var vl: float = 1.3 + 2.2 * MeshKit.hash01(k, i, 332)
		var vw: float = 0.35 + 0.5 * MeshKit.hash01(k, i, 333)
		var vx: float = x_in - sd * 0.04
		var a := Vector3(vx, y1, vz)
		var b := Vector3(vx, y1, vz - vw)
		var c := Vector3(vx - sd * 0.1, y1 - vl, vz - vw * 0.7)
		var d := Vector3(vx - sd * 0.1, y1 - vl * 0.85, vz + vw * 0.1)
		_face(s, a, b, c, d, Vector3(-sd, 0, 0), skin.vine_color, 0.0, MeshKit.PAT_TERMINAL_VINE, 0.0)


## A few scavengers' camps on the second track between the cars and the far wall, scenery only (GDD §5: "a few scavengers"): a fire
## barrel with a dim ember glow and three still figures round it, dark silhouettes (a body, a head, hunched, no faces), one a block
## of 130 m a side by hash. Seen mostly through the gaps between the trains.
func _camps(s: MeshLayer, side: int, wall_x: float, h: float, d0: float, d1: float) -> void:
	var sd: float = float(side)
	var first: int = floori(d0 / CAMP_BLOCK) - 1
	var last: int = floori(d1 / CAMP_BLOCK)
	for block: int in range(first, last + 1):
		if MeshKit.hash01(block, side, 401) >= skin.camp_share:
			continue
		var at: float = float(block) * CAMP_BLOCK + 20.0 + (CAMP_BLOCK - 40.0) * MeshKit.hash01(block, side, 402)
		if at < d0 or at >= d1:
			continue
		var x: float = sd * lerpf(wall_x + 5.0, h - 1.6, MeshKit.hash01(block, side, 403))
		var y: float = -skin.track_drop
		var z: float = -at
		var rust: Color = skin.steel_color.lerp(skin.rust_color, 0.6)
		s.prism(Vector3(x, y, z), 0.32, 0.9, 8, rust, 0.0, MeshKit.PAT_TERMINAL_STEEL, true, 0.0)
		s.prism(Vector3(x, y + 0.9, z), 0.33, 0.05, 8, rust.darkened(0.4), 0.0, MeshKit.PAT_PLAIN, true, 0.0)
		s.box(Vector3(x, y + 0.95, z), Vector3(0.46, 0.05, 0.46), skin.ember_color, skin.ember_glow, MeshKit.PAT_TERMINAL_LAMP,
			MeshKit.FACE_PY | MeshKit.FACE_PZ | MeshKit.FACE_PX | MeshKit.FACE_NX, 2.0)
		for i: int in 3:
			var a: float = TAU * (float(i) + 0.3 * MeshKit.hash01(block, i, 404)) / 3.0 + float(block)
			var fx: float = x + cos(a) * 1.15
			var fz: float = z + sin(a) * 1.15
			var fh: float = 0.75 + 0.35 * MeshKit.hash01(block, i, 405)
			var cloth: Color = Color(0.06, 0.055, 0.05).lerp(Color(0.13, 0.1, 0.08), MeshKit.hash01(block, i, 406))
			var turn := Basis(Vector3.UP, -a + PI * 0.5)
			s.box_xform(Transform3D(turn.scaled_local(Vector3(0.5, fh, 0.32)), Vector3(fx, y + fh * 0.5, fz)), cloth, 0.0, MeshKit.PAT_PLAIN,
				MeshKit.NO_BOTTOM)
			s.box_xform(Transform3D(turn.scaled_local(Vector3(0.3, 0.26, 0.3)), Vector3(fx, y + fh + 0.18, fz) + turn * Vector3(0.0, 0.0, 0.08)),
				cloth.lightened(0.15), 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)


## The far wall's work lamps, one every lamp_pitch at z = -k * lamp_pitch (their light is painted on the wall, by the same
## index): a bracket on the wall and a short cage with a tube in it.
func _wall_lamps(s: MeshLayer, side: int, h: float, d0: float, d1: float) -> void:
	var sd: float = float(side)
	var pitch: float = skin.lamp_pitch
	var k0: int = ceili(d0 / pitch - 0.0001)
	var k1: int = ceili(d1 / pitch - 0.0001) - 1
	for k: int in range(k0, k1 + 1):
		var z: float = -float(k) * pitch
		var x: float = sd * (h - WALL_LAMP_SETBACK)
		var y: float = skin.wall_lamp_height
		s.box(Vector3(sd * (h - 0.08), y, z), Vector3(0.16, 0.5, 0.5), skin.post_color, 0.0, MeshKit.PAT_TERMINAL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_PY, 0.0)
		s.box(Vector3(x, y, z), Vector3(0.26, 0.2, 1.3), skin.post_color, 0.0, MeshKit.PAT_TERMINAL_STEEL,
			MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_PZ, 0.0)
		s.box(Vector3(x - sd * 0.08, y - 0.02, z), Vector3(0.1, 0.12, 1.1), skin.lamp_color, skin.lamp_tube_glow(),
			MeshKit.PAT_TERMINAL_LAMP, MeshKit.ALL_FACES, 1.0)


# --- The vault ---------------------------------------------------------------------------------

## The vault over [d0, d1): the shell, the ribs whose lamps hang in it (z = -(k + 0.5) * lamp_pitch), the lamps, the boards
## and the cables strung between the ribs.
func _vault(batch: MeshBatch, s: MeshLayer, wall_x: float, h: float, d0: float, d1: float) -> void:
	var z0: float = -d0
	var z1: float = -d1
	# The shell: segments across, one quad each along the run; UV in metres along the arch and along the track.
	var arc: float = 0.0
	var prev := Vector2(-h, skin.spring_height)
	for i: int in range(1, VAULT_SEGMENTS + 1):
		var x: float = lerpf(-h, h, float(i) / float(VAULT_SEGMENTS))
		var cur := Vector2(x, vault_y(x, h))
		var seg: float = prev.distance_to(cur)
		var a := Vector3(prev.x, prev.y, z0)
		var b := Vector3(cur.x, cur.y, z0)
		var c := Vector3(cur.x, cur.y, z1)
		var d := Vector3(prev.x, prev.y, z1)
		var toward := Vector3(0, skin.spring_height, (z0 + z1) * 0.5) - (a + b + c + d) * 0.25
		_face(s, a, b, c, d, toward, skin.vault_color, 0.0, MeshKit.PAT_TERMINAL_WALL, 1.0,
			[Vector2(arc, -z0), Vector2(arc + seg, -z0), Vector2(arc + seg, -z1), Vector2(arc, -z1)])
		arc += seg
		prev = cur
	# The ribs, lamps and boards: one a pitch, the rib k at z = -(k + 0.5) * lamp_pitch.
	var pitch: float = skin.lamp_pitch
	var k0: int = ceili(d0 / pitch - 0.5 - 0.0001)
	var k1: int = ceili(d1 / pitch - 0.5 - 0.0001) - 1
	for k: int in range(k0, k1 + 1):
		var zk: float = -(float(k) + 0.5) * pitch
		_rib(s, h, zk)
		_lamp(s, h, zk)
		if MeshKit.hash01(k, 0, 341) < 0.55:
			_board(s, wall_x, h, zk, k)
		_cables(s, h, zk, k)


## One steel rib across the hall at z: a strip under the shell (the soffit) and its face toward the runner.
func _rib(s: MeshLayer, h: float, zk: float) -> void:
	var zn: float = zk + RIB_WIDTH * 0.5
	var zf: float = zk - RIB_WIDTH * 0.5
	var prev_p := Vector2(-h, vault_y(-h, h))
	var prev_o: Vector2 = prev_p + vault_inward(-h, h) * RIB_DEPTH
	for i: int in range(1, VAULT_SEGMENTS + 1):
		var x: float = lerpf(-h, h, float(i) / float(VAULT_SEGMENTS))
		var cur_p := Vector2(x, vault_y(x, h))
		var cur_o: Vector2 = cur_p + vault_inward(x, h) * RIB_DEPTH
		# The soffit (facing down into the hall) and the face toward the runner (+z).
		_face(s, Vector3(prev_o.x, prev_o.y, zn), Vector3(cur_o.x, cur_o.y, zn), Vector3(cur_o.x, cur_o.y, zf),
			Vector3(prev_o.x, prev_o.y, zf), Vector3(0, -1, 0), skin.steel_color, 0.0, MeshKit.PAT_TERMINAL_STEEL, 0.0)
		_face(s, Vector3(prev_p.x, prev_p.y, zn), Vector3(cur_p.x, cur_p.y, zn), Vector3(cur_o.x, cur_o.y, zn),
			Vector3(prev_o.x, prev_o.y, zn), Vector3(0, 0, 1), skin.steel_color.darkened(0.1), 0.0, MeshKit.PAT_TERMINAL_STEEL, 0.0)
		prev_p = cur_p
		prev_o = cur_o


## The work lamp hung from the rib at z over the middle of the street: a chain, a cage and the tube in it (it burns, fails or
## is dead as the shader says).
func _lamp(s: MeshLayer, h: float, zk: float) -> void:
	var y: float = skin.lamp_height
	var top: float = vault_y(0.0, h) - RIB_DEPTH
	var chain: Color = skin.post_color
	s.box(Vector3(0, (top + y + 0.2) * 0.5, zk), Vector3(0.05, top - y - 0.2, 0.05), chain, 0.0, MeshKit.PAT_TERMINAL_STEEL,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ, 2.0)
	s.box(Vector3(0, y + 0.1, zk), Vector3(0.6, 0.22, LAMP_LENGTH), chain, 0.0, MeshKit.PAT_TERMINAL_STEEL, MeshKit.ALL_FACES, 0.0)
	s.box(Vector3(0, y - 0.04, zk), Vector3(0.34, 0.1, LAMP_LENGTH - 0.3), skin.lamp_color, skin.lamp_tube_glow(), MeshKit.PAT_TERMINAL_LAMP,
		MeshKit.ALL_FACES, 0.0)


## A dead departure board hung from the rib by two rods, its face toward the runner: dark glass in a worn frame, wordless.
func _board(s: MeshLayer, wall_x: float, h: float, zk: float, k: int) -> void:
	var side: float = 1.0 if MeshKit.hash01(k, 1, 342) < 0.5 else -1.0
	var x: float = side * lerpf(1.6, wall_x - 1.4, MeshKit.hash01(k, 2, 343))
	var bw: float = 1.7
	var bh: float = 0.95
	var y: float = skin.lamp_height - 0.7
	var z: float = zk + RIB_WIDTH * 0.5 + 0.12
	var top: float = vault_y(x, h) - RIB_DEPTH
	for dx: float in [-0.7, 0.7]:
		s.box(Vector3(x + dx, (top + y + bh) * 0.5, z - 0.05), Vector3(0.03, top - y - bh, 0.03), skin.post_color, 0.0,
			MeshKit.PAT_PLAIN, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ)
	s.box(Vector3(x, y + bh * 0.5, z - 0.07), Vector3(bw + 0.1, bh + 0.1, 0.1), skin.board_frame_color, 0.0, MeshKit.PAT_TERMINAL_STEEL,
		MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PY | MeshKit.FACE_NY, 0.0)
	s.rect(Vector3(x - bw * 0.5, y, z), Vector3(bw, 0, 0), Vector3(0, bh, 0), Color(0.05, 0.05, 0.05), 0.0, MeshKit.PAT_TERMINAL_BOARD,
		Vector2(0, 0), Vector2(bw, bh), float(MeshKit.hash_i(k, 3, 344) % 100))


## Cables strung along the vault from this rib to the next, one a side, sagging between them.
func _cables(s: MeshLayer, h: float, zk: float, k: int) -> void:
	var pitch: float = skin.lamp_pitch
	for side: float in [-1.0, 1.0]:
		var x: float = side * (2.2 + 2.0 * MeshKit.hash01(k, int(side), 351))
		var y: float = vault_y(x, h) - RIB_DEPTH - 0.25
		var segs: int = 4
		var prev := Vector3(x, y, zk)
		for i: int in range(1, segs + 1):
			var t: float = float(i) / float(segs)
			var sag: float = 1.3 * 4.0 * t * (1.0 - t)
			var cur := Vector3(x + side * 0.3 * sin(t * PI), y - sag, zk - pitch * t)
			_rod(s, prev, cur, 0.045, skin.post_color.darkened(0.4))
			prev = cur


## A thin rod or cable from a to b.
func _rod(s: MeshLayer, a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 0.01:
		return
	var y_axis: Vector3 = d / length
	var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD if absf(y_axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis)
	var basis := Basis(x_axis * thickness, y_axis * length, z_axis * thickness)
	s.box_xform(Transform3D(basis, (a + b) * 0.5), color, 0.0, MeshKit.PAT_PLAIN, MeshKit.FACE_PX | MeshKit.FACE_NX | MeshKit.FACE_PZ | MeshKit.FACE_NZ)


## A four-cornered face, wound to face `toward` (Godot's front faces wind clockwise; MeshLayer.quad faces (d - a) x (b - a)).
## `uvs` (a, b, c, d) when the pattern takes UV in metres.
static func _face(s: MeshLayer, a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3, color: Color, glow: float,
		pattern: int, param: float, uvs: Array = []) -> void:
	var forward: bool = (d - a).cross(b - a).dot(toward) >= 0.0
	if uvs.is_empty():
		if forward:
			s.quad(a, b, c, d, color, glow, pattern, param)
		else:
			s.quad(a, d, c, b, color, glow, pattern, param)
	elif forward:
		s.quad_uv(a, b, c, d, uvs[0], uvs[1], uvs[2], uvs[3], color, glow, pattern, param)
	else:
		s.quad_uv(a, d, c, b, uvs[0], uvs[3], uvs[2], uvs[1], color, glow, pattern, param)
