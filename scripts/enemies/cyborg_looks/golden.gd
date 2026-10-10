extends RefCounted
## The Golden Zone's cyborg (GDD §9.2, "Zone variants": "derived from the Casino Mob Enforcer by the
## art agent"; brief docs/art/BRIEF_CYBORG_GANGSTER.md): the elites' ceremonial enforcer. It is the
## Casino Mob Enforcer (casino.gd's build(), the same body, head and drum-fed gun) in the zone's
## white, cream, red and gold (GDD §5, Zone 8), more opulent and ceremonial:
## - a cream suit with pale gold pinstripes over a red shirt, red lapels, the gold breastplate, and a
##   red sash from the right shoulder to the left hip in place of the bandolier;
## - the cult's Convergent Triad worn openly (GDD §5: shown openly only in the Golden Zone) on a
##   medallion on the sash: CultEmblem's drawing of the owner's choice in unlit, polished gold meeting
##   at a small red centre stone (CultEmblem.GOLD_ACCENT_COLOR) on ivory enamel inside a gold rim,
##   drawn by cyborg_body.gdshader (glow 60), which fades the mark out while it is small on screen
##   (under about 24 pixels, where the three-fold mark could read like the radiation trefoil; the
##   skins' rule), leaving the plain medallion;
## - gold fringes hanging from the pauldrons (epaulettes), ivory gauntlets and hands like white
##   gloves, a gold filigree border on the TV's sides instead of card suits;
## - an ornate version of the enforcer's gun: gold, with an ivory stock and a red drum.
## Gold is unlit ornament, never glowing; the red is deep and unlit, kept clear of the charge-up's
## glowing red and every hazard colour (test_cyborg_body).
## DESIGN-TBD (docs/questions/p3.md 3): the ceremonial enforcer's palette and ornaments.

const Casino = preload("res://scripts/enemies/cyborg_looks/casino.gd")
const MIRRORED := HumanoidPiece.Placement.MIRRORED
const CENTER := HumanoidPiece.Placement.CENTER
const PRISM := HumanoidPiece.Shape.PRISM
const BOX := HumanoidPiece.Shape.BOX

## The Golden Zone's palette for Casino.build() (its keys).
const PALETTE: Dictionary = {
	"suit": Color(0.74, 0.69, 0.58),
	"suit_shade": Color(0.62, 0.57, 0.48),
	"shirt": Color(0.4, 0.162, 0.18),
	"lapel": Color(0.42, 0.17, 0.19),
	"gold": Color(0.74, 0.6, 0.35),
	"gold_dark": Color(0.52, 0.42, 0.24),
	"gold_shine": 0.8,
	"lacquer": Color(0.74, 0.71, 0.64),
	"lacquer_shine": 0.55,
	"metal": Color(0.74, 0.71, 0.65),
	"metal_dark": Color(0.64, 0.61, 0.55),
	"metal_shine": 0.35,
	"strap": Color(0.4, 0.162, 0.18),
	"cable": Color(0.55, 0.45, 0.27),
	"tube": Color(0.66, 0.63, 0.56),
	"cartridge": Color(0.52, 0.42, 0.24),
	"stock": Color(0.74, 0.71, 0.64),
	"drum": Color(0.4, 0.162, 0.18),
	"suits": false,
	"bandolier": false,
}
## The sash (deep red) and the medallion: its centre and radius on the chest (chest segment space,
## on the sash where it crosses the breastplate), its ivory enamel and gold rim.
const SASH := Color(0.42, 0.17, 0.19)
const SASH_EDGE := Color(0.52, 0.42, 0.24)
const MEDALLION_CENTER := Vector3(0.028, 0.235, -0.119)
const MEDALLION_RADIUS: float = 0.062
const ENAMEL := Color(0.76, 0.73, 0.66)
## The mark spans CultEmblem's unit square, 2 × EMBLEM_HALF across on the medallion.
const EMBLEM_HALF: float = 0.066
const EMBLEM_PIXELS: int = 128
## The pinstripes, pale gold on cream.
const STRIPE_COLOR := Color(0.62, 0.53, 0.35)

static var _emblem: ImageTexture


static func pieces() -> Array[HumanoidPiece]:
	var list: Array[HumanoidPiece] = []
	Casino.build(list, PALETTE)
	_sash_and_medallion(list)
	_epaulettes(list)
	_filigree(list)
	return list


## Its hosts' veins are the enforcer's (the same body).
static func veins() -> Array[HumanoidPiece]:
	return Casino.host_veins()


## The enforcer's diamond LEDs and gold, pale gold pinstripes, and the Triad on the medallion.
static func material_params() -> Dictionary:
	return {&"stripe_color": STRIPE_COLOR, &"stripe_spacing": Casino.STRIPE_SPACING, &"led_shape": 1.0,
		&"polish_metallic": 0.6, &"emblem": emblem_texture(),
		&"emblem_rect": Vector3(MEDALLION_CENTER.x, MEDALLION_CENTER.y, EMBLEM_HALF), &"emblem_metallic": 0.7}


## The cult's emblem as the medallion shows it: the owner's choice (CultFeed.emblem_option(), from
## data/world/cult_emblem_choice.tres) drawn by CultEmblem in the look's gold, its centre stone in
## CultEmblem's red, on a transparent background of the same gold (so the far mipmaps keep the
## colour), with mipmaps. Built once.
static func emblem_texture() -> ImageTexture:
	if _emblem == null:
		var gold: Color = PALETTE["gold"]
		var img: Image = CultEmblem.build_image(CultFeed.emblem_option(), EMBLEM_PIXELS, gold, CultEmblem.GOLD_ACCENT_COLOR,
			Color(gold, 0.0))
		img.generate_mipmaps()
		_emblem = ImageTexture.create_from_image(img)
	return _emblem


## The red sash from the right shoulder to the left hip, gold-edged, and the Triad's medallion on it:
## a gold rim round an enamel disc facing forward (the emblem is drawn on the disc).
static func _sash_and_medallion(list: Array[HumanoidPiece]) -> void:
	# Over the shoulder, then flat over the breastplate, then down to the hip.
	var path: Array[Vector3] = [Vector3(0.14, 0.405, -0.074), Vector3(0.075, 0.31, -0.107), Vector3(-0.07, 0.08, -0.111),
		Vector3(-0.125, -0.03, -0.104)]
	for k: int in path.size() - 1:
		var a: Vector3 = path[k]
		var b: Vector3 = path[k + 1]
		CyborgSuit.bar(list, &"chest", a, b, Vector2(0.062, 0.008), SASH, Vector3.FORWARD)
		if k == 1:
			# Gold edges along its flat middle run.
			var across: Vector3 = (b - a).normalized().cross(Vector3.FORWARD).normalized()
			for edge: float in [-1.0, 1.0]:
				CyborgSuit.patch(list, &"chest", (a + b) * 0.5 + across * (edge * 0.029) + Vector3(0.0, 0.0, -0.0046),
					Vector2(0.006, a.distance_to(b)), SASH_EDGE, CyborgSuit.facing(Vector3.FORWARD, across))
	var m: Vector3 = MEDALLION_CENTER
	CyborgSuit.add(list, &"chest", PRISM, Vector3(MEDALLION_RADIUS * 2.0 + 0.016, 0.01, MEDALLION_RADIUS * 2.0 + 0.016),
		m + Vector3(0.0, 0.0, 0.006), PALETTE["gold"], 0.0,
		{"sides": 16, "shine": PALETTE["gold_shine"], "rotation_degrees": Vector3(90.0, 0.0, 0.0)})
	CyborgSuit.add(list, &"chest", PRISM, Vector3(MEDALLION_RADIUS * 2.0, 0.008, MEDALLION_RADIUS * 2.0), m, ENAMEL,
		CyborgSuit.EMBLEM, {"sides": 16, "shine": 0.5, "rotation_degrees": Vector3(90.0, 0.0, 0.0)})


## Epaulettes: a fringe of gold cords hanging from each pauldron's rim round its outer half.
static func _epaulettes(list: Array[HumanoidPiece]) -> void:
	for k: int in 7:
		# Round the rim from the front (-z) over the outside (+x) to the back (+z).
		var a: float = deg_to_rad(-80.0 + k * (160.0 / 6.0))
		var out := Vector3(cos(a), 0.0, sin(a))
		var at: Vector3 = Vector3(0.012, -0.108, 0.0) + out * 0.064
		CyborgSuit.patch(list, &"upper_arm", at, Vector2(0.014, 0.05), PALETTE["gold"], CyborgSuit.facing(out,
			Vector3(-sin(a), 0.0, cos(a))), 0.6, MIRRORED)


## A gold filigree border on the TV's side panels (in place of the card suits) and a gold line round
## the tube.
static func _filigree(list: Array[HumanoidPiece]) -> void:
	var tv: Vector3 = CyborgSuit.TV_SIZE
	var at: Vector3 = CyborgSuit.TV_CENTER
	var x: float = tv.x * 0.5 + 0.0012
	for turn: float in [45.0, -45.0]:
		CyborgSuit.patch(list, &"head", Vector3(x, at.y, at.z), Vector2(0.012, 0.16), PALETTE["gold_dark"],
			CyborgSuit.facing(Vector3.RIGHT, Vector3.BACK) + Vector3(0.0, 0.0, turn), 1.0, MIRRORED)
	CyborgSuit.patch(list, &"head", Vector3(x, at.y, at.z), Vector2(0.03, 0.03), PALETTE["gold"],
		CyborgSuit.facing(Vector3.RIGHT, Vector3.BACK) + Vector3(0.0, 0.0, 45.0), 1.0, MIRRORED)
