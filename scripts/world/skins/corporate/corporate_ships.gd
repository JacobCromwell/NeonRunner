class_name CorporateShips
extends RefCounted
## The military's gunships (CorporateSkin, GDD §5: corporations and the military are one, and the
## military presence is part of the zone's look). A gunship hovering high over the street, nose toward
## the oncoming runner: an armoured olive and gunmetal hull tapering to a blunt nose with a dark
## cockpit band, stub wings with an engine pod at each tip (cold blue exhausts, their down-wash glowing
## under them), a tail fin and masts, steady white running lights, and the corporation's mark stencilled
## large on its belly and flanks in pale paint. No guns: nothing decorative may look like an attack
## (safe things look safe). Built once per variant and shared (one template per skin and variant).
## Ship space: origin at the hull's centre, +z toward the nose.

static var _templates: Dictionary = {}


## The hovering gunship `variant` (0 olive, 1 gunmetal) for `skin`, as a template to append.
static func hover_ship(skin: CorporateSkin, variant: int) -> MeshBatch:
	var key: String = "%d_%d" % [skin.get_instance_id(), variant]
	var found: MeshBatch = _templates.get(key)
	if found != null:
		return found
	var batch := MeshBatch.new()
	var s: MeshLayer = batch.layer(skin.solid_material())
	var g: MeshLayer = batch.layer(skin.glow_material())
	var hull: Color = skin.olive_color if variant == 0 else skin.gunmetal_color.lightened(0.18)
	var trim: Color = skin.gunmetal_color if variant == 0 else skin.olive_color
	var hl: float = 10.0
	var hw: float = 3.0
	var hh: float = 1.6
	var nose_w: float = 1.7
	# The hull: a tapered box, its nose at +z narrower and lower.
	var bl := Vector3(-hw, -hh, -hl)
	var br := Vector3(hw, -hh, -hl)
	var tl := Vector3(-hw, hh, -hl)
	var tr := Vector3(hw, hh, -hl)
	var nbl := Vector3(-nose_w, -hh * 0.6, hl)
	var nbr := Vector3(nose_w, -hh * 0.6, hl)
	var ntl := Vector3(-nose_w, hh * 0.5, hl)
	var ntr := Vector3(nose_w, hh * 0.5, hl)
	# Belly (faces down), top, flanks, nose and stern.
	s.quad(bl, nbl, nbr, br, hull, 0.0, MeshKit.PAT_CORP_PLATE, 1.0)
	s.quad(tr, ntr, ntl, tl, hull.lightened(0.08), 0.0, MeshKit.PAT_CORP_PLATE, 1.0)
	s.quad(br, nbr, ntr, tr, hull, 0.0, MeshKit.PAT_CORP_PLATE, 1.0)
	s.quad(tl, ntl, nbl, bl, hull, 0.0, MeshKit.PAT_CORP_PLATE, 1.0)
	s.quad(nbl, ntl, ntr, nbr, hull.darkened(0.15), 0.0, MeshKit.PAT_CORP_PLATE, 1.0)
	s.quad(br, tr, tl, bl, trim.darkened(0.2))
	# The cockpit band across the nose, dark glass.
	var c0: Vector3 = ntl.lerp(nbl, 0.25)
	var c1: Vector3 = ntr.lerp(nbr, 0.25)
	s.quad(c0 + Vector3(0, 0, 0.02), ntl + Vector3(0, -0.15, 0.02), ntr + Vector3(0, -0.15, 0.02), c1 + Vector3(0, 0, 0.02),
		Color(0.03, 0.035, 0.045), 0.0, MeshKit.PAT_GLASS)
	# The corporation's mark stencilled large on the belly (seen from the street as it hovers over),
	# on the belly's slope, its top toward the nose.
	var m: float = 1.0
	var z0: float = -0.6
	var z1: float = 3.4
	var y0: float = _belly_y(z0, hh, hl) - 0.02
	var y1: float = _belly_y(z1, hh, hl) - 0.02
	s.quad_uv(Vector3(-2.0, y0, z0), Vector3(-2.0, y1, z1), Vector3(2.0, y1, z1), Vector3(2.0, y0, z0), Vector2(-m, -m),
		Vector2(-m, m), Vector2(m, m), Vector2(m, -m), hull, 0.0, MeshKit.PAT_CORP_LOGO, 3.0)
	# Stub wings, an engine pod at each tip: its exhaust glowing cold blue at the back, its down-wash
	# glowing under it.
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(side * (hw + 2.0), -0.3, -1.5), Vector3(4.0, 0.35, 3.4), trim, 0.0, MeshKit.PAT_CORP_PLATE,
			MeshKit.ALL_FACES, 1.0)
		var pod := Vector3(side * (hw + 4.3), -0.2, -1.5)
		s.prism_xform(Transform3D(Basis(Vector3(1.1, 0, 0), Vector3(0, 0, -5.0), Vector3(0, 1.1, 0)), pod + Vector3(0, 0, 2.5)), 8,
			trim.lightened(0.1), 0.0, MeshKit.PAT_CORP_PLATE)
		s.prism_xform(Transform3D(Basis(Vector3(0.8, 0, 0), Vector3(0, 0, -0.05), Vector3(0, 0.8, 0)), pod + Vector3(0, 0, -2.5)), 8,
			skin.engine_color, 1.0)
		g.rect(pod + Vector3(-2.2, -2.2, -2.7), Vector3(4.4, 0, 0), Vector3(0, 4.4, 0), skin.engine_color, 0.45, MeshKit.SHAPE_RADIAL)
		g.rect(pod + Vector3(-1.4, -1.2, 1.6), Vector3(2.8, 0, 0), Vector3(0, 0, -6.2), skin.engine_color, 0.25, MeshKit.SHAPE_RADIAL)
		# Running lights at the wing tips: steady cold white (never a hazard's red or green).
		s.box(pod + Vector3(side * 1.2, 0.0, 2.3), Vector3(0.25, 0.25, 0.25), skin.flood_color, 0.9)
		g.rect(pod + Vector3(side * 1.2 - 0.9, -0.9, 2.4), Vector3(1.8, 0, 0), Vector3(0, 1.8, 0), skin.flood_color, 0.3,
			MeshKit.SHAPE_RADIAL)
		# A pale stencil of the mark on each flank (a vertical plane, slanting in toward the nose), the
		# right way round as seen from that side.
		var za: float = 0.4
		var zb: float = 2.4
		var xa: float = side * (_flank_x(za, hw, nose_w, hl) + 0.02)
		var xb: float = side * (_flank_x(zb, hw, nose_w, hl) + 0.02)
		if side > 0.0:
			s.quad_uv(Vector3(xa, -0.9, za), Vector3(xb, -0.9, zb), Vector3(xb, 0.9, zb), Vector3(xa, 0.9, za), Vector2(m, -m),
				Vector2(-m, -m), Vector2(-m, m), Vector2(m, m), hull, 0.0, MeshKit.PAT_CORP_LOGO, 3.0)
		else:
			s.quad_uv(Vector3(xa, 0.9, za), Vector3(xb, 0.9, zb), Vector3(xb, -0.9, zb), Vector3(xa, -0.9, za), Vector2(-m, m),
				Vector2(m, m), Vector2(m, -m), Vector2(-m, -m), hull, 0.0, MeshKit.PAT_CORP_LOGO, 3.0)
	# A tail fin, two masts, and a light under the nose.
	s.box(Vector3(0, hh + 1.3, -hl + 1.8), Vector3(0.3, 2.6, 3.2), trim, 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.ALL_FACES, 1.0)
	s.box(Vector3(0, hh + 2.7, -hl + 1.2), Vector3(0.22, 0.22, 0.22), skin.flood_color, 0.9)
	for mx: float in [-1.2, 1.2]:
		s.box(Vector3(mx, hh + 0.8, 2.0), Vector3(0.1, 1.6, 0.1), trim)
	s.box(Vector3(0, -hh * 0.6 - 0.12, hl - 0.8), Vector3(0.5, 0.2, 0.5), skin.flood_color, 0.8)
	_templates[key] = batch
	return batch


## The belly's height at z: it rises from -hh at the stern to -0.6 hh at the nose.
static func _belly_y(z: float, hh: float, hl: float) -> float:
	return -hh + 0.4 * hh * (z + hl) / (2.0 * hl)


## How far the flank is from the middle at z: it narrows from hw at the stern to nose_w at the nose.
static func _flank_x(z: float, hw: float, nose_w: float, hl: float) -> float:
	return hw - (hw - nose_w) * (z + hl) / (2.0 * hl)
