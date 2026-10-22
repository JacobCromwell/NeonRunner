class_name IceLabDoodads
extends RefCounted
## The Ice Lab's zone doodads (IceLabSkin.doodad; GDD §3 and §5, Zone 9, owner, October 21, 2026: "brain jars and other lab equipment", and
## "some jars hold a curled-up Octodog"; proposed: ice crystal clusters and crates of lab supplies among them), drawn as picture cards on
## their boxes (DoodadCards; owner's request October 9, 2026): each is a simple box with a picture of the object drawn on it, the open air
## see-through. Small: a specimen jar with a brain in it, the OCTODOG JAR (a jar with the Octodog curled up inside), a stack of
## lab supply crates, a small ice crystal cluster. Medium: a pair of specimen jars on one base, a server rack, a lab bench with its
## equipment, a big crystal cluster, a pallet of supplies. Large: a row of specimen jars, a console bank, a mound of ice crystals, stacks of
## supply crates, a machine frozen in ice. On the zone's cold palette nothing here competes with the fence's pink or a sign's yellow and
## black, and nothing glows (the jars' liquid is a pale matte paint, not a light). The pictures: tools/asset_gen/doodad_art/ice_lab_art.gd;
## they are drawn to whatever box the zone's doodads have (MovementTuning.doodad_size, the level's own doodad height where it sets one),
## so rerun `tools/godot.sh doodads --only=ice_lab` when the boxes change.
## The lean (the owner, October 21, 2026: level 1 heavily into the snow and industry, the last level heavily into the laboratory): every look
## has a laboratory affinity (LOOKS, 0 snow and industry to 1 laboratory) and the skin's lab_share picks among a class's looks by weights that
## favour the ones nearest it (look_weight), so level 1 is crystals, crates and frozen machinery and level 3 jars, racks and consoles.
## **The Octodog jar** (task Q5 makes some of them break open when smashed and release their Octodog, GDD §5 Zone 9) has its own look name,
## OCTODOG_JAR, in the small class, and a way to find it: look_seed_for() gives a look seed that picks it, is_octodog_jar() says whether a
## seed does, and every card look's body carries its look's name as the metadata META_LOOK (so a built doodad can be told from the brain
## jar beside it). A jar that will release its Octodog looks the same as one that won't (GDD §5): the look carries no hint. It pushes
## like any doodad (it is a card look in its box, nothing more).

## The metadata a built doodad's body carries its look's name in.
const META_LOOK: StringName = &"doodad_look"
## The Octodog jar's look name, in the small class (the manifest's design name: tools/asset_gen/doodad_art/ice_lab_art.gd).
const OCTODOG_JAR: StringName = &"octodog_jar"
const ZONE: String = "ice_lab"
## Each look's laboratory affinity (0 snow and industry, 1 the laboratory); a look not listed here is 0.5.
const LOOKS: Dictionary = {
	"brain_jar": 1.0, "octodog_jar": 0.85, "cryo_tank": 0.5, "supply_crates": 0.35, "crystal_cluster": 0.0,
	"twin_jars": 1.0, "server_rack": 0.8, "lab_bench": 0.9, "crystal_cluster_big": 0.0, "supply_pallet": 0.35,
	"jar_row": 1.0, "console_bank": 0.9, "crystal_mound": 0.0, "supply_stacks": 0.3, "frozen_machine": 0.1,
}
## The weight of a look at the ends of the lean, and how sharply it falls off from its affinity.
const WEIGHT_FLOOR: float = 0.15
const WEIGHT_SPAN: float = 0.85
## A look's own rarity, a factor on its weight (a look not listed here is 1): the Octodog jar is one doodad in a few at the lab end of the lean
## and rare elsewhere (DESIGN-TBD, docs/questions/q2.md item 6), since a jar that never opens is the norm and only some release their Octodog.
const RARITY: Dictionary = {"octodog_jar": 0.25}

## Weak: the skin owns this builder, so a strong reference back would keep both alive forever.
var skin: IceLabSkin:
	get:
		return _skin.get_ref() as IceLabSkin
var _skin: WeakRef


func _init(p_skin: IceLabSkin) -> void:
	_skin = weakref(p_skin)


## The weight of the look `look_name` at lean `lab_share`: 1 at its own affinity, falling to WEIGHT_FLOOR a whole lean away, times its rarity.
static func look_weight(look_name: String, lab_share: float) -> float:
	var affinity: float = float(LOOKS.get(look_name, 0.5))
	var near: float = 1.0 - absf(lab_share - affinity)
	return (WEIGHT_FLOOR + WEIGHT_SPAN * near * near) * float(RARITY.get(look_name, 1.0))


## The look (a design of the zone's manifest) a doodad of `size_class` with `look_seed` gets at this skin's lean, or {} when the zone has
## none for it: picked by hash against look_weight(), so the same seed is the same look wherever and whenever it is built.
func design(cards: DoodadCards, size_class: StringName, look_seed: int) -> Dictionary:
	var list: Array = cards.designs.get(String(size_class), [])
	if list.is_empty():
		return {}
	var total: float = 0.0
	for d: Dictionary in list:
		total += look_weight(String(d["name"]), skin.lab_share)
	var r: float = MeshKit.hash01(look_seed, 0, 17) * total
	for d: Dictionary in list:
		r -= look_weight(String(d["name"]), skin.lab_share)
		if r < 0.0:
			return d
	return list[list.size() - 1]


func build(body: Node3D, size: Vector3, size_class: StringName, side: int, look_seed: int) -> void:
	var cards: DoodadCards = DoodadCards.for_zone(ZONE)
	var d: Dictionary = design(cards, size_class, look_seed) if cards.ok else {}
	if d.is_empty():
		cards.build(body, size, size_class, side, look_seed, skin.doodad_palette)
		return
	var inst := MeshInstance3D.new()
	inst.mesh = cards.mesh_for(d, size)
	inst.material_override = cards.material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)
	body.set_meta(META_LOOK, StringName(d["name"]))


## The name of the look a doodad of `size_class` with `look_seed` gets ("" where the zone has no cards for it).
func look_name(size_class: StringName, look_seed: int) -> String:
	var cards: DoodadCards = DoodadCards.for_zone(ZONE)
	var d: Dictionary = design(cards, size_class, look_seed) if cards.ok else {}
	return String(d.get("name", ""))


## Whether a doodad of `size_class` with `look_seed` is the Octodog jar.
func is_octodog_jar(size_class: StringName, look_seed: int) -> bool:
	return look_name(size_class, look_seed) == String(OCTODOG_JAR)


## A look seed (searching upward from `from`) that gives the look named `wanted` in `size_class` at this lean, or -1 when the zone has no such
## look. For the skin's own use and for task Q5's hook: the generator and gameplay code never call this (they never learn a zone's theme; Q5 adds
## an abstract flag to the layout's doodads and a ZoneSkin hook that turns it into a look here).
func look_seed_for(size_class: StringName, wanted: StringName, from: int = 0) -> int:
	for s: int in range(from, from + 4096):
		if look_name(size_class, s) == String(wanted):
			return s
	return -1
