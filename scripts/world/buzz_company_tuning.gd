class_name BuzzCompanyTuning
extends Resource
## Numbers for the company a Buzz Overdrive gets (task L2; the owner, October 17, 2026: "unless this is done for
## performance, I'd like other enemies, such as some cyborgs, maybe an Octodog, or extra gaps or laser fences, on the
## playfield at the same time as Buzz Overdrive enemies"; BuzzCompanyPlacement has the rules). Which levels give it
## is each level's own LevelConfig.buzz_company. Edit data/tuning/buzz_company.tres (F6: "Buzz Overdrive company", in
## a level that gives it; Restart level rebuilds). Seconds are at the level's run speed, so they keep their time at
## every zone's speed (GDD §3).

const PATH: String = "res://data/tuning/buzz_company.tres"

@export_group("Which tanks")
## Off: no tank gets company, and every level is built exactly as without the pass.
@export var enabled: bool = true
## Whether the level that introduces the Buzz Overdrive (Corporate 1) gives its first tank company too. Off, the
## player meets it alone first, after its hint (GDD: introduce one new mechanic at a time). DESIGN-TBD
## (items 933-941 in docs/OPEN_QUESTIONS*.md).
@export var on_introduction: bool = false
## A tank whose visit (from where it comes into view to where it's gone) comes within this many seconds of an
## Enforcer Truck's chase gets no company: where a truck is likely on the map with it, sparse is fine (the owner).
## DESIGN-TBD (items 933-941 in docs/OPEN_QUESTIONS*.md): how near counts, and whether the later zones' tanks get company too.
@export_range(0.0, 10.0, 0.5, "suffix:s") var truck_margin_seconds: float = 2.0

@export_group("Where")
## Its attack, where company keeps out of its escape lane (the neighbouring lane a runner in its lane leaves into)
## and cyborgs stand only beside that lane, starts this long before its warning (its rev), and runs to the end of
## its cut's window (FloorCutPlan.window). Before that, while it rolls ahead in view, company keeps out of its own
## lane only. DESIGN-TBD (items 933-941 in docs/OPEN_QUESTIONS*.md): a busier or a calmer attack.
@export_range(0.0, 2.0, 0.05, "suffix:s") var attack_margin_seconds: float = 0.5

@export_group("Rows")
## The most rows of holes or fences (one-row fillers of the level, picked as the fill pass picks them) one tank's
## stretch takes, spaced as the fill pass spaces its fillers. DESIGN-TBD (items 933-941 in docs/OPEN_QUESTIONS*.md).
@export_range(0, 8) var rows_max: int = 4
## The level's spacing between two patterns (the fill pass's margin: the spacing and a pattern's tail) times this
## is what each row keeps from everything around it: 1 keeps the fill pass's own, the fairness floor; more is
## sparser.
@export_range(1.0, 3.0, 0.05) var spacing_scale: float = 1.0

@export_group("Cyborgs")
## The most cyborg encounters (one of the level's plain cyborg patterns: a single or a pair) one tank's stretch
## takes, each where one fits with this chance. DESIGN-TBD (items 933-941 in docs/OPEN_QUESTIONS*.md).
@export_range(0, 4) var cyborgs_max: int = 1
@export_range(0.0, 1.0, 0.05) var cyborg_chance: float = 0.85
## Whether a cyborg may stand where the runner meets it during the attack (in a lane beside the escape lane, never
## the tank's own or the escape lane, so a runner beside it can always step into the clear escape lane). Off, they
## stand only where the runner meets them before the attack, while the tank rolls ahead. DESIGN-TBD
## (items 933-941 in docs/OPEN_QUESTIONS*.md).
@export var cyborgs_in_attack: bool = true
## A company cyborg holds its fire (and no bolt of its arrives) from this long before the tank's warning to this
## long after its cut's window ends (Cyborg's hold_fire, as a cyborg in a charge's path holds it): the rev and the
## charge stay the one thing to dodge. DESIGN-TBD (items 933-941 in docs/OPEN_QUESTIONS*.md).
@export_range(0.0, 3.0, 0.05, "suffix:s") var hold_before_seconds: float = 0.5
@export_range(0.0, 3.0, 0.05, "suffix:s") var hold_after_seconds: float = 0.5


static func load_default() -> BuzzCompanyTuning:
	var res: Resource = load(PATH) if ResourceLoader.exists(PATH) else null
	return res as BuzzCompanyTuning if res is BuzzCompanyTuning else BuzzCompanyTuning.new()
