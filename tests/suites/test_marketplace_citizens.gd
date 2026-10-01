extends SkinSuite
## The Marketplace citizens (GDD §5, "Citizens"; GDD §9.2; task D3): scenery only, seeded from the
## chunk so the same window always gets the same citizen, never in a feed window or a window a
## window cyborg stands in, switched off by Settings.citizens_enabled, and reacting only once the
## runner draws near (CLAUDE.md principle 1: the reaction reads the player's position but adds no
## collision or gameplay of its own).

const MARKET_SKIN_PATH: String = "res://data/skins/marketplace_skin.tres"


func run() -> void:
	var skin := load(MARKET_SKIN_PATH) as MarketplaceSkin
	check(skin != null, "the marketplace skin loads")
	if skin == null:
		return
	await _only_in_free_windows(skin)
	await _off_switch(skin)
	await _deterministic(skin)
	await _reaction()
	_sheets_load()


## Never in a feed window (shop_windows()'s `screen`), nor one a window cyborg stands in
## (note_wall_enemies(), GDD §9.2: "kept apart").
func _only_in_free_windows(skin: MarketplaceSkin) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var side: int = 1
	var face_x: float = side * geo.wall_x()
	var windows: Array[Dictionary] = skin.shop_windows(side, face_x, 0.0, 120.0)
	var screen_ats: Array[float] = []
	var free_at: float = -1.0
	for w: Dictionary in windows:
		if bool(w["screen"]):
			screen_ats.append(float(w["at"]))
		elif free_at < 0.0:
			free_at = float(w["at"])
	check(free_at >= 0.0 and not screen_ats.is_empty(), "the test level has both a free and a feed window to check")
	skin.note_wall_enemies(side, 0.0, 120.0, [{"type": "window_cyborg", "at": free_at, "side": side}])
	var parent := Node3D.new()
	tree.root.add_child(parent)
	skin.citizens().build(parent, side, face_x, 0.0, 120.0)
	var placed: Array[float] = []
	for child: Node in parent.get_children():
		if child is MarketCitizen:
			placed.append((child as MarketCitizen).at)
	var ok: bool = true
	for at: float in placed:
		if absf(at - free_at) <= MarketCitizens.CYBORG_MARGIN:
			ok = false
		for sa: float in screen_ats:
			if is_equal_approx(at, sa):
				ok = false
	check(ok and not placed.is_empty(), "citizens avoid the reserved window and every feed window (%d placed)" %
		placed.size())
	skin.note_wall_enemies(side, 0.0, 120.0, [])  # Leave the skin as _off_switch() etc. expect it.
	parent.queue_free()
	await tree.process_frame


## Settings.citizens_enabled off builds none; back on builds some again.
func _off_switch(skin: MarketplaceSkin) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var face_x: float = geo.wall_x()
	var was_enabled: bool = Settings.citizens_enabled
	Settings.citizens_enabled = false
	var parent := Node3D.new()
	tree.root.add_child(parent)
	skin.citizens().build(parent, 1, face_x, 0.0, 120.0)
	check(parent.get_children().is_empty(), "no citizens build while Settings.citizens_enabled is off")
	Settings.citizens_enabled = true
	skin.citizens().build(parent, 1, face_x, 0.0, 120.0)
	check(not parent.get_children().is_empty(), "citizens build again once the setting is back on")
	Settings.citizens_enabled = was_enabled
	parent.queue_free()
	await tree.process_frame


## The same chunk gets the same citizens (position, archetype, reaction) every time it's built.
func _deterministic(skin: MarketplaceSkin) -> void:
	var geo := TrackGeometry.new(5, tuning)
	var face_x: float = geo.wall_x()
	var a := Node3D.new()
	var b := Node3D.new()
	tree.root.add_child(a)
	tree.root.add_child(b)
	skin.citizens().build(a, 1, face_x, 0.0, 160.0)
	skin.citizens().build(b, 1, face_x, 0.0, 160.0)
	var sig_a: Array = _signature(a)
	var sig_b: Array = _signature(b)
	check(not sig_a.is_empty() and sig_a == sig_b, "the same chunk gets the same citizens every time (%d placed)" %
		sig_a.size())
	a.queue_free()
	b.queue_free()
	await tree.process_frame


func _signature(parent: Node3D) -> Array:
	var out: Array = []
	for child: Node in parent.get_children():
		if child is MarketCitizen:
			var c := child as MarketCitizen
			out.append([c.position, c.at])
	return out


## Stays idle while the runner is far off; reacts once they're within range (MarketCitizen.
## REACT_LEAD/REACT_GRACE), driven by the player's own track distance, read-only (no new gameplay).
func _reaction() -> void:
	var sim := RunSim.new(tree, tuning)
	var world: RunWorld = sim.build_world(RunSim.layout(5, 200.0))
	var citizen := MarketCitizen.new()
	world.add_child(citizen)
	citizen.setup(PlaceholderTexture2D.new(), Vector2(0.4, 1.0), 50.0, 0.0, &"cheer")
	world.player.distance = 10.0
	citizen._process(0.016)
	check(not citizen.is_reacting(), "stays idle while the runner is far from its window")
	world.player.distance = 49.0
	citizen._process(0.016)
	check(citizen.is_reacting(), "reacts once the runner comes within range of its window")
	await sim.free_world(world)


## Every archetype's baked sheet loads, at the agreed grid size (tools/godot.sh citizens
## regenerates them if one is missing or the shape of CitizenSheet changes).
func _sheets_load() -> void:
	var count: int = CitizenRig.archetype_count()
	var loaded: int = 0
	for i: int in count:
		var name: String = CitizenRig.ARCHETYPES[i].name
		var tex: Texture2D = load(CitizenSheet.texture_path(name)) as Texture2D
		if tex == null:
			continue
		loaded += 1
		check(tex.get_width() == CitizenSheet.CELL.x * CitizenSheet.COLS
				and tex.get_height() == CitizenSheet.CELL.y * CitizenSheet.ROWS,
			"%s is a %dx%d flipbook sheet" % [name, tex.get_width(), tex.get_height()])
	check(loaded == count, "every archetype's sheet loads (%d of %d; tools/godot.sh citizens regenerates them)" %
		[loaded, count])
