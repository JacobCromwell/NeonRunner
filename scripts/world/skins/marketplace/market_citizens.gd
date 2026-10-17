class_name MarketCitizens
extends RefCounted
## Builds the Marketplace citizens (GDD §5, "Citizens"; tasks D3 and L7) into the shop windows
## MarketplaceSkin.shop_windows() lists: ordinary people standing at ease in the shops (real low-poly people, one
## MarketCrowd of them to a wall section: MarketPeople), watching the runner come and go and cheering at a big
## pickup or a big defeat, a warm contrast to the cult's feed. Picked and placed purely from the window's track
## position (seeded, like every other piece of this skin: MeshKit.hash_i), so a chunk builds the same citizens
## every time; only their watching and cheering depend on the run.
##
## Keeps windows to one use each: never a feed window (shop_windows()'s `screen`), and never a
## window a window cyborg stands in (MarketplaceSkin.note_wall_enemies(); GDD §9.2 says they must
## read apart, see docs/questions/d3.md). Switched off entirely when Settings.citizens_enabled is
## false (a low-end device, or the player's own choice): CLAUDE.md, "added only if they don't
## noticeably cost performance... and don't add much code complexity."

## Share of eligible windows that get a citizen (DESIGN-TBD, docs/questions/d3.md and l7.md: the cards' 0.16 left them
## unnoticed, one at about every second chunk of wall; doubled for the people, whose cost is measured in
## tools/measure/market_people_cost.gd: about 4.5 citizens a 40 m chunk of both walls, 0.25 ms to build).
const CITIZEN_SHARE: float = 0.32
## How far past a window cyborg's own position (its track distance) a citizen still keeps clear,
## wider than its drawn window (WindowCyborgTuning.window_length / 2) so the two are never close
## enough to read as the same thing (DESIGN-TBD, docs/questions/d3.md).
const CYBORG_MARGIN: float = 2.2
## A person's height range (metres: shorter and taller), and the most of a window's height one may take (heads clear the lintel).
const HEIGHT_RANGE := Vector2(1.5, 1.74)
const HEAD_ROOM_SHARE: float = 0.9
## Build (the width and depth over the height), how deep into the display they stand (the share of its depth, from the
## glass), and how far they turn from facing the lanes toward the runner's approach (degrees): DESIGN-TBD.
const BUILD_RANGE := Vector2(0.92, 1.1)
const DEPTH_RANGE := Vector2(0.42, 0.6)
const TURN_RANGE := Vector2(20.0, 50.0)
## A person's width with room to spare, kept clear of a window's piers (metres).
const PERSON_WIDTH: float = 1.1

## Weak: the skin owns this builder (MarketStalls and friends do the same).
var skin: MarketplaceSkin:
	get:
		return _skin.get_ref() as MarketplaceSkin
var _skin: WeakRef


func _init(p_skin: MarketplaceSkin) -> void:
	_skin = weakref(p_skin)


## Adds a MarketCrowd under `parent` of the citizens for every eligible window on `side` whose centre lies in
## [start, end) and is chosen (CITIZEN_SHARE of them).
func build(parent: Node3D, side: int, face_x: float, start: float, end: float) -> void:
	if not Settings.citizens_enabled:
		return
	var people: Array[Dictionary] = []
	for w: Dictionary in skin.shop_windows(side, face_x, start, end):
		if bool(w["screen"]):
			continue
		var at: float = float(w["at"])
		if skin.reserved_near(side, at, CYBORG_MARGIN):
			continue
		var key: int = MeshKit.key(at)
		if MeshKit.hash01(side, key, 211) >= CITIZEN_SHARE:
			continue
		people.append(person_for(w, side, key))
	spawn(parent, people)


## One MarketCrowd of `people` (person_for()) under `parent`; none if there are none, or the person hasn't been baked yet
## (tools/godot.sh citizens): skip rather than crash.
func spawn(parent: Node3D, people: Array[Dictionary]) -> void:
	if people.is_empty() or MarketPeople.mesh() == null:
		return
	var crowd := MarketCrowd.new()
	parent.add_child(crowd)
	crowd.setup(people)


## The citizen of window `w` (shop_windows()'s entry) on `side`, `key` the window's seed (MeshKit.key of its track distance):
## where they stand (inside, a little off the window's middle), their own height and build, the way they face (the lanes,
## turned a little toward the end of the street the runner comes from), and the seeds the shader dresses and times them by.
## Everything comes from the window's own track position.
func person_for(w: Dictionary, side: int, key: int) -> Dictionary:
	var bottom: float = float(w["bottom"])
	var top: float = float(w["top"])
	var height: float = minf(lerpf(HEIGHT_RANGE.x, HEIGHT_RANGE.y, MeshKit.hash01(side, key, 223)),
		(top - bottom) * HEAD_ROOM_SHARE)
	var stature: float = height / MarketPeople.stature()
	var build: float = lerpf(BUILD_RANGE.x, BUILD_RANGE.y, MeshKit.hash01(side, key, 227))
	var center: Vector3 = w["center"]
	var along: float = (MeshKit.hash01(side, key, 229) - 0.5) * maxf(float(w["width"]) - PERSON_WIDTH, 0.0) * 0.8
	var depth: float = float(w["depth"]) * lerpf(DEPTH_RANGE.x, DEPTH_RANGE.y, MeshKit.hash01(side, key, 231))
	var turn: float = deg_to_rad(lerpf(TURN_RANGE.x, TURN_RANGE.y, MeshKit.hash01(side, key, 237)))
	# Facing: toward the lanes (-side on x), and toward +z (the way the runner comes from) by `turn`; the model's front is -z.
	var front := Vector3(-side * cos(turn), 0.0, sin(turn))
	return {
		"pos": Vector3(center.x + side * depth, bottom, center.z + along),
		"heading": atan2(-front.x, -front.z),
		"scale": Vector3(stature * build, stature, stature * build),
		"look": MeshKit.hash01(side, key, 233), "phase": MeshKit.hash01(side, key, 239),
		"late": MeshKit.hash01(side, key, 241), "at": float(w["at"])}


## A person standing at the origin, for the shader warm-up (MarketplaceSkin.warm_samples).
static func sample_person() -> Dictionary:
	return {"pos": Vector3.ZERO, "heading": 0.0, "scale": Vector3.ONE, "look": 0.5, "phase": 0.0, "late": 0.0, "at": 0.0}
