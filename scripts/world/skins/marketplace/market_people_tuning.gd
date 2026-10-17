class_name MarketPeopleTuning
extends Resource
## The Marketplace citizens' numbers (GDD §5, "Citizens"; task L7): how they watch the runner and when and how they cheer.
## Edit data/citizens/market_people.tres. All DESIGN-TBD (docs/questions/l7.md): placeholders until the owner has seen them.

const PATH: String = "res://data/citizens/market_people.tres"

@export_group("Cheering")
## A credit pickup this valuable cheers the citizens in view: the top two denominations (CreditField.LOOKS: a
## violet diamond is 25, the tall ice-white gem 100), about ten a level. DESIGN-TBD.
@export var cheer_credit_min_value: int = 25
## The enemies whose defeat cheers them, by Enemy.type_id: the big ones (15 or more health, or the Enforcer Truck, which
## only baiting a charge destroys). A friendly-fire kill counts as the player's only for the type that declares it
## (Enemy.charge_bait), as the score counts it. DESIGN-TBD.
@export var cheer_enemy_types: PackedStringArray = PackedStringArray(
	["hover_truck", "enforcer_truck", "drone", "buzz_overdrive", "resonator"])
## One hop with both arms thrown up: how long it lasts, and how high the person leaves the floor.
@export_range(0.3, 2.0, 0.05, "suffix:s") var cheer_seconds: float = 0.9
@export_range(0.05, 0.8, 0.01, "suffix:m") var cheer_hop: float = 0.28
## Who cheers: the citizens this far ahead of the runner (those in view) and this far behind them.
@export_range(5.0, 120.0, 1.0, "suffix:m") var cheer_ahead: float = 48.0
@export_range(0.0, 40.0, 1.0, "suffix:m") var cheer_behind: float = 12.0
## A cheer is let go by while the last one is this recent, so a run of big pickups stays a little cheer, not a rave.
@export_range(0.0, 5.0, 0.1, "suffix:s") var cheer_cooldown: float = 1.6
## The cheer spreads outward from the runner at this many seconds a metre, and each person is up to this much late
## (their own, fixed): a ripple, not everyone at once.
@export_range(0.0, 0.05, 0.001, "suffix:s/m") var ripple: float = 0.012
@export_range(0.0, 0.5, 0.01, "suffix:s") var jitter: float = 0.18
## The House's duck (react(&"startled")): how long a flinch lasts.
@export_range(0.3, 2.0, 0.05, "suffix:s") var startle_seconds: float = 0.8

@export_group("Watching")
## They watch the runner: heads turn toward them from `look_far` away, all the way at `look_near`, never beyond this far
## round from straight ahead of the body.
@export_range(5.0, 120.0, 1.0, "suffix:m") var look_far: float = 52.0
@export_range(0.0, 60.0, 1.0, "suffix:m") var look_near: float = 16.0
@export_range(10.0, 100.0, 1.0, "suffix:deg") var look_limit: float = 72.0
## How far a person sways at ease (their whole body about the feet).
@export_range(0.0, 4.0, 0.1, "suffix:deg") var sway: float = 1.4


## The shared tuning (data/citizens/market_people.tres), or the defaults if it's missing.
static func load_default() -> MarketPeopleTuning:
	var res: Resource = load(PATH) if ResourceLoader.exists(PATH) else null
	return res as MarketPeopleTuning if res is MarketPeopleTuning else MarketPeopleTuning.new()
