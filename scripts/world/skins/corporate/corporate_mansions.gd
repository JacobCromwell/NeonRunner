class_name CorporateMansions
extends RefCounted
## The Corporate backdrop's third layer, high up and rare (CorporateTowers builds it on top of some towers; the owner's
## reference image, docs/art/reference/corporate_backdrop.webp: "brightly lit, lavish mansions of the elites"): an
## elite's mansion crowning a corporate tower. Two or three terraces of ivory stone, each a storey tall and set back
## STEP metres (and END_STEP in from each end) behind the one below, so they climb like a wedding cake. A terrace's face
## is one flat facade quad (corp_facade.gdshader's MANSION style): paired columns every 3.6 m, tall arched windows lit
## warm (a share of the rooms dark), a balustrade along the foot of the storey, a cornice with dentils at its head.
## What stands out of it is cheap geometry: the terrace slabs (the roof of the storey below, wider than it toward the
## street), a clipped hedge along each terrace's edge and a round topiary here and there, a cornice slab over the top
## terrace and on some a small domed pavilion with a lit lantern, and a soft warm halo behind every terrace.
## The light is the skin's mansion_light_color, a champagne white: the colour rule (GDD §5) keeps glowing light to cold
## white and the brand's blue and reserves yellow and orange for hazards, so it is desaturated (the suite pins it clear
## of the hazard hues) and every mansion starts at skin.mansion_min_y, far above the lanes' hazards. Steady: nothing here
## flickers. Everything is behind the wall plane (a mansion never reaches over the street).
## DESIGN-TBD (docs/questions/corporate-backdrop.md): the owner's reference shows a true gold; this keeps the rule.

## A storey's height (the facade shader's storey grid), how far each terrace is set back, how far in from each end of
## the building, how far the slabs overhang the terrace below toward the street, the slab's thickness and the cornice's.
const FLOOR: float = 3.6
const STEP: float = 2.2
const END_STEP: float = 1.4
const OVERHANG: float = 0.55
const SLAB: float = 0.35
const CROWN_HEIGHT: float = 0.9
## How deep a terrace's near end face reaches back, and the roof slab's depth over the top terrace.
const DEPTH_M: float = 12.0
const ROOF_DEPTH: float = 6.0
## The share of rooms lit on a mansion's face (the facade's vertex alpha).
const LIT_SHARE: float = 0.88

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: CorporateSkin:
	get:
		return _skin.get_ref() as CorporateSkin
var towers: CorporateTowers:
	get:
		return _towers.get_ref() as CorporateTowers
var _skin: WeakRef
var _towers: WeakRef


func _init(p_skin: CorporateSkin, p_towers: CorporateTowers) -> void:
	_skin = weakref(p_skin)
	_towers = weakref(p_towers)


## The mansion of tower `b` (standing on its body at b.mansion_y; `tower_x` is the tower's face) between two track
## distances.
func build(facade: MeshLayer, solid: MeshLayer, glow: MeshLayer, b: CorporateTowers.Building, tower_x: float, start: float,
		end: float) -> void:
	var side: int = b.side
	var stone: Color = skin.mansion_stone_colors[MeshKit.hash_i(side, b.id, 16) % skin.mansion_stone_colors.size()]
	var green: Color = skin.greenery_colors[MeshKit.hash_i(side, b.id, 17) % skin.greenery_colors.size()]
	var dark_stone: Color = stone.darkened(0.3)
	var light: Color = skin.mansion_light_color
	var seed: int = b.seed + 31
	for t: int in b.tiers:
		var y0: float = b.mansion_y + FLOOR * float(t)
		var y1: float = y0 + FLOOR
		var front: float = tower_x + side * STEP * float(t)
		var a0: float = b.t0 + END_STEP * float(t)
		var a1: float = b.b1 - END_STEP * float(t)
		var u0: float = maxf(a0, start)
		var u1: float = minf(a1, end)
		if u1 <= u0 + 0.001:
			continue
		# The terrace's face, its near end (facing the runner), and the soft halo of its lit rooms.
		towers.face(facade, side, front, u0, u1, y0, y1, stone, LIT_SHARE, CorporateTowers.STYLE_MANSION, seed + t)
		if a0 >= start and a0 < end:
			var x_min: float = minf(front, front + side * DEPTH_M)
			MeshKit.end_quad(facade, x_min, x_min + DEPTH_M, a0, y0, y1, false, stone, LIT_SHARE, CorporateTowers.STYLE_MANSION,
				float(seed + t))
		var halo: Array = CorporateTowers._wall_rect(side, front - side * 0.7, u0 - 1.0, u1 - u0 + 2.0, y0 - 0.5, FLOOR + 1.0)
		glow.rect(halo[0], halo[1], halo[2], light, 0.16, MeshKit.SHAPE_FLAT)
		# The slab under the terrace (the roof of the storey below, reaching toward the street past its face), or for the
		# first storey a ledge along the tower's top.
		var zc: float = -(u0 + u1) * 0.5
		if t == 0:
			solid.box(Vector3(front - side * (OVERHANG * 0.5 - 0.1), y0 - SLAB * 0.5, zc), Vector3(OVERHANG + 0.2, SLAB, u1 - u0),
				dark_stone, 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.ALL_FACES, 3.0)
		else:
			var prev_front: float = front - side * STEP
			var p0: float = maxf(a0 - END_STEP, start)
			var p1: float = minf(a1 + END_STEP, end)
			solid.box(Vector3((prev_front - side * OVERHANG + front) * 0.5, y0 - SLAB * 0.5, -(p0 + p1) * 0.5),
				Vector3(STEP + OVERHANG, SLAB, p1 - p0), dark_stone, 0.0, MeshKit.PAT_CORP_PLATE, MeshKit.ALL_FACES, 3.0)
			# A clipped hedge along the terrace's street edge, and a round topiary every 6 m or so.
			var hx: float = prev_front - side * (OVERHANG - 0.35)
			solid.box(Vector3(hx, y0 + 0.4, zc), Vector3(0.6, 0.8, u1 - u0 - 0.6), green, 0.0, MeshKit.PAT_PLAIN, MeshKit.NO_BOTTOM)
			var k: int = ceili((u0 - a0 - 2.0) / 6.0)
			while a0 + 2.0 + 6.0 * float(k) < u1:
				var at: float = a0 + 2.0 + 6.0 * float(k) + 1.2 * MeshKit.hash01(b.id, k, 18 + t)
				k += 1
				if at < u0 or at >= u1:
					continue
				solid.prism(Vector3(hx, y0 + 0.8, -at), 0.55, 1.1, 6, green.lightened(0.05))
	# The top terrace's roof: a cornice slab over its face, and on some a small domed pavilion with a lit lantern.
	var top: int = b.tiers - 1
	var ty: float = b.mansion_y + FLOOR * float(b.tiers)
	var tfront: float = tower_x + side * STEP * float(top)
	var ta0: float = b.t0 + END_STEP * float(top)
	var ta1: float = b.b1 - END_STEP * float(top)
	var c0: float = maxf(ta0 - 0.4, start)
	var c1: float = minf(ta1 + 0.4, end)
	if c1 > c0 + 0.001:
		solid.box(Vector3(tfront + side * (ROOF_DEPTH - OVERHANG) * 0.5, ty + CROWN_HEIGHT * 0.5, -(c0 + c1) * 0.5),
			Vector3(ROOF_DEPTH + OVERHANG, CROWN_HEIGHT, c1 - c0), stone.lightened(0.08), 0.0, MeshKit.PAT_CORP_PLATE,
			MeshKit.ALL_FACES, 3.0)
	var mid: float = (ta0 + ta1) * 0.5
	if MeshKit.hash01(side, b.id, 19) < 0.5 and mid >= start and mid < end:
		var base := Vector3(tfront + side * 4.0, ty + CROWN_HEIGHT, -mid)
		solid.prism(base, 2.2, 1.2, 10, stone)
		solid.prism(base + Vector3(0, 1.2, 0), 1.9, 0.5, 10, stone.lightened(0.1))
		solid.prism(base + Vector3(0, 1.7, 0), 0.95, 0.9, 10, light, 0.7)
		solid.prism(base + Vector3(0, 2.6, 0), 1.5, 0.35, 10, stone.lightened(0.12))
		solid.box(base + Vector3(0, 3.5, 0), Vector3(0.14, 1.6, 0.14), stone.darkened(0.1))
		glow.rect(base + Vector3(-2.4, 0.0, 0.0), Vector3(4.8, 0, 0), Vector3(0, 4.8, 0), light, 0.2, MeshKit.SHAPE_RADIAL)
