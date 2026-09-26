class_name PowerupController
extends Node
## Runs the permanent power-ups of one run (GDD §8). RunWorld creates it by convention as its last
## child and calls setup(world); it reads the run's Loadout (owned, switched-on items) and
## world.powerup_tuning, and runs one module per item:
##   weapon     WeaponPowerup: auto-fire at the nearest valid target, tiers 1–4, plus the enemy
##              health bars (EnemyHealthBars) that come with it
##   claws      ClawsPowerup: nothing to run (contact kills and longer wall runs are in the core)
##   dash       DashPowerup: the juggernaut dash on the `dash` action, with a cooldown
##   magnet     MagnetPowerup: sets the credit field's pull radius
##   slow_time  SlowTimePowerup: slows the world on the `slow_time` action (PC only, GDD §3)
## Without an item nothing of it exists: no input, no visuals, no HUD entry.
##
## It processes after the player, enemies, projectiles and credits, and pauses with the game.
## Input arrives only as the named actions `dash` and `slow_time` (CLAUDE.md principle 1).
##
## API for the HUD, the player model and effects:
## - hud_state() -> Array[Dictionary]: one entry per item the run carries, in shop order
##   (weapon, claws, dash, magnet, slow_time, then armor, shield, grapple):
##     {id: StringName, icon: StringName (the catalog's icon name), tier: int (0 for breakables),
##      ready: float 0–1 (cooldown progress; 1 = ready), active: bool, charges: int}
##   The weapon is `active` while it has a target and `ready` shows its fire cycle; the dash and slow
##   time are `active` while running and `ready` 0 → 1 over their cooldown; claws and the magnet are
##   always active and ready. Armor, shield and grapple carry the player's charges (0 = used up; they
##   stay listed for the whole run, `active` false once used).
## - equipment() -> Dictionary: {claws: bool, armor: bool, shield: bool, weapon_tier: int,
##   magnet: bool} for the player model's set_equipment(); `equipment_changed` fires when it changes
##   (armor or shield broke).
## - try_dash() / try_slow_time() -> bool: what the actions do (for touch buttons and tests).
## - Signals below. Sounds: laser_fire / missile_fire per shot, dash_ready, slow_time_on / _off
##   (the `dash` sound comes from the player's own dash event).

## A player shot left the weapon (weapon tier 1–4).
signal fired(tier: int)
signal dash_started
## The dash's cooldown is over.
signal dash_ready
signal slow_time_changed(on: bool)
signal equipment_changed(equipment: Dictionary)

## Shop order, for hud_state().
const PERMANENT_ORDER: Array[StringName] = [&"weapon", &"claws", &"dash", &"magnet", &"slow_time"]
const BREAKABLES: Array[StringName] = [&"armor", &"shield", &"grapple"]

var world: RunWorld
## PC or mobile (slow time is PC only). From App.mobile when the App autoload exists.
var mobile: bool = false
var weapon: WeaponPowerup
var claws: ClawsPowerup
var dash: DashPowerup
var magnet: MagnetPowerup
var slow_time: SlowTimePowerup
## The running modules, in shop order.
var modules: Array[PowerupModule] = []

## Breakable items this run started with (they stay in hud_state once used up).
var _carried: Array[StringName] = []
var _icons: Dictionary = {}


func setup(p_world: RunWorld) -> void:
	world = p_world
	# Visuals follow the camera, which moves in its own _process: draw after it. Physics order is
	# unchanged (RunWorld adds this node last).
	process_priority = 10
	var app: Node = get_node_or_null(^"/root/App")
	mobile = bool(app.get(&"mobile")) if app != null else DeviceProfile.is_mobile()
	_read_icons(app)
	var loadout: Loadout = world.loadout
	for item: StringName in PERMANENT_ORDER:
		var t: int = loadout.tier(item)
		if t <= 0 or (item == &"slow_time" and mobile):
			continue
		var m: PowerupModule = _create(item)
		add_child(m)
		m.setup(self, item, t)
		modules.append(m)
	for item: StringName in BREAKABLES:
		if loadout.charge(item) > 0:
			_carried.append(item)
	world.player.died.connect(_on_player_died)
	world.player.item_used.connect(_on_item_used)


## Starts the juggernaut dash if the run has it and it's off cooldown. True if it started.
func try_dash() -> bool:
	return dash != null and dash.trigger()


## Starts slow time if the run has it (PC only) and it's off cooldown. True if it started.
func try_slow_time() -> bool:
	return slow_time != null and slow_time.trigger()


func hud_state() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if world == null or world.player == null:
		return out
	for m: PowerupModule in modules:
		out.append(m.hud_entry())
	var p: Player = world.player
	for item: StringName in _carried:
		var n: int = p.armor if item == &"armor" else (p.shield if item == &"shield" else p.grapples)
		out.append(make_hud_entry(item, 0, 1.0, n > 0, n))
	return out


func equipment() -> Dictionary:
	var p: Player = world.player if world != null else null
	return {
		"claws": p != null and p.claws,
		"armor": p != null and p.armor > 0,
		"shield": p != null and p.shield > 0,
		"weapon_tier": weapon.tier if weapon != null else 0,
		"magnet": magnet != null,
	}


## One hud_state() entry. `charges`: uses left for a breakable item, -1 for a permanent power-up
## (the HUD shows no count, and 0 reads as used up).
func make_hud_entry(item: StringName, item_tier: int, ready: float, active: bool, charges: int) -> Dictionary:
	return {"id": item, "icon": _icons.get(item, item), "tier": item_tier, "ready": clampf(ready, 0.0, 1.0),
		"active": active, "charges": charges}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dash"):
		try_dash()
	elif event.is_action_pressed(&"slow_time"):
		try_slow_time()


func _physics_process(delta: float) -> void:
	if world == null or world.player == null:
		return
	for m: PowerupModule in modules:
		m.physics_tick(delta)


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	for m: PowerupModule in modules:
		m.visual_tick(delta)


func _on_player_died(_cause: String) -> void:
	for m: PowerupModule in modules:
		m.stop()


func _on_item_used(item: StringName) -> void:
	if item == &"armor" or item == &"shield":
		equipment_changed.emit(equipment())


func _create(item: StringName) -> PowerupModule:
	match item:
		&"weapon":
			weapon = WeaponPowerup.new()
			return weapon
		&"claws":
			claws = ClawsPowerup.new()
			return claws
		&"dash":
			dash = DashPowerup.new()
			return dash
		&"magnet":
			magnet = MagnetPowerup.new()
			return magnet
		_:
			slow_time = SlowTimePowerup.new()
			return slow_time


## Icon names from the shop catalog (they match the ids today, but the catalog is the source).
func _read_icons(app: Node) -> void:
	var catalog: ShopCatalog = app.get(&"catalog") as ShopCatalog if app != null else null
	if catalog == null:
		return
	for item: ShopItem in catalog.items:
		_icons[item.id] = item.icon
