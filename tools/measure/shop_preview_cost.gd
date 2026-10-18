extends Node
## Measures what the shop's outfit previews cost (task M4): the frames and draw calls of the shop with its cosmetic cards at
## rest (every preview a still), with one preview live (the card the pointer or the focus is on) and, for scale, with
## every preview live; and the time the shop takes to open. The numbers are the renderer's own, so run it on a real renderer
## (software or not; the dummy one draws nothing), once per renderer you care about, and compare a branch with main in two
## checkouts (the tool reads the previews only through `card.preview`, so it also runs where there are none):
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --resolution 1280x720 \
##     [--rendering-method gl_compatibility] res://tools/measure/shop_preview_cost.tscn -- [--frames=120] [--phone]
## A software renderer (llvmpipe) makes the frame time mostly the rasteriser's, on the CPU: read it against the same run on
## main, not against a phone. `draw calls` and `triangles` are what the renderer counted in a frame, over every viewport.

var _frames: int = 120


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--frames="):
			_frames = maxi(int(arg.get_slice("=", 1)), 10)
	if args.has("--phone"):
		UiTheme.touch_override = 1
		UiScale.assume_web = true
		App.mobile = true
	App.autosave = false
	App.profile = SampleProfiles.rich()
	App.sync_outfit()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("renderer: %s, window %s" % [RenderingServer.get_current_rendering_method(), get_tree().root.size])
	if args.has("--build-times"):
		# What dressing a runner costs the first time (an outfit's meshes are built once per session, then cached).
		for id: StringName in [PlayerOutfits.ECHO, &"rex", &"camo", &"beach_master", &"centurion", &"party_wolf"]:
			var b0: int = Time.get_ticks_usec()
			PlayerOutfits.parts_for(id)
			var b1: int = Time.get_ticks_usec()
			var avatar := PlayerAvatar.new()
			var b2: int = Time.get_ticks_usec()
			avatar.free()
			print("%-14s parts %6.1f ms, then an avatar from them %5.1f ms" % [id, float(b1 - b0) / 1000.0, float(b2 - b1) / 1000.0])
	# Opening the shop: the call itself (the cards), then the frames to the first quiet one.
	await _open("opening the shop (the first time this session)", false)
	var shop := App.screen as ShopScreen
	var cards: Array = shop.cosmetic_cards.values()
	await _settle()
	var drawn_at_open: Variant = _stills_drawn()
	if drawn_at_open != null:
		print("pictures drawn by the time the shop has settled, the Cosmetics below the fold: %d" % drawn_at_open.size())
	_scroll_to_cosmetics(shop)
	await _log_frames("scrolling to the Cosmetics (the pictures are drawn now, the first time)", 40)
	await _settle()
	var drawn: Variant = _stills_drawn()
	if drawn != null:
		var first: Variant = cards[0].get("preview")
		print("pictures drawn: %d (%s), a preview is %s logical px, the window's scale is %.2f" % [drawn.size(), ", ".join(drawn),
			(first as Control).size if first != null else "-", get_tree().root.get_final_transform().get_scale().x])
	_report("A  nothing focused (every preview a still)", await _sample())
	# The focus scrolls the shop to the card; the same scroll for B, C and D, so only the previews differ.
	var focus: CosmeticCard = shop.cosmetic_cards.get(&"camo")
	if focus != null:
		focus.action_button.grab_focus()
	await _settle()
	_report("B  Camo focused (its preview live)", await _sample())
	_set_all_live(cards, false)
	await _settle()
	_report("C  Camo focused, every preview a still", await _sample())
	_set_all_live(cards, true)
	await _settle()
	_report("D  every preview live (not what the shop does)", await _sample())
	_set_all_live(cards, false)
	# The shop is shown after every death: the second visit, with the stills kept.
	App.show_title()
	await _settle()
	await _open("opening it again (the stills kept)", false)
	await _open("opening it a third time and scrolling to the Cosmetics", true)
	get_tree().quit()


## Opens the shop (and, with `scroll`, scrolls its list to the Cosmetics section at once) and prints how long the call took and
## the first frames after it.
func _open(label: String, scroll: bool) -> void:
	var t0: int = Time.get_ticks_usec()
	App.show_shop()
	var call_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	if scroll:
		_scroll_to_cosmetics(App.screen as ShopScreen)
	print("%s: App.show_shop() %.1f ms" % [label, call_ms])
	await _log_frames("  the frames after it", 30)


## Prints the next `count` frame times (ms, wall clock between drawn frames).
func _log_frames(label: String, count: int) -> void:
	var frames: Array[float] = []
	var t0: int = Time.get_ticks_usec()
	for i: int in count:
		await RenderingServer.frame_post_draw
		var t1: int = Time.get_ticks_usec()
		frames.append(float(t1 - t0) / 1000.0)
		t0 = t1
	print("%s (%d frames, ms): %s" % [label, count, frames.map(func(v: float) -> String: return "%.0f" % v)])


## Scrolls the shop's list down to its end, where the Cosmetics are.
func _scroll_to_cosmetics(shop: ShopScreen) -> void:
	var card: Node = shop.cosmetic_cards.values()[0]
	var up: Node = card.get_parent()
	while up != null and not up is ScrollContainer:
		up = up.get_parent()
	if up != null:
		(up as ScrollContainer).scroll_vertical = 100000


## The keys of the pictures drawn so far (OutfitStills, where this build has it).
func _stills_drawn() -> Variant:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry["class"] == "OutfitStills":
			return (load(entry["path"]) as GDScript).get("drawn")
	return null


func _set_all_live(cards: Array, on: bool) -> void:
	for card: Variant in cards:
		var preview: Variant = card.get("preview")
		if preview != null:
			preview.set_live(on)


func _settle() -> void:
	for i: int in 20:
		await RenderingServer.frame_post_draw


## Frame times (ms, wall clock between drawn frames) and the renderer's counts over `_frames` frames.
func _sample() -> Dictionary:
	var times := PackedFloat64Array()
	var calls := PackedInt32Array()
	var tris := PackedInt32Array()
	var t0: int = Time.get_ticks_usec()
	for i: int in _frames:
		await RenderingServer.frame_post_draw
		var t1: int = Time.get_ticks_usec()
		times.append(float(t1 - t0) / 1000.0)
		t0 = t1
		calls.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		tris.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))
	times.sort()
	calls.sort()
	tris.sort()
	var sum: float = 0.0
	for t: float in times:
		sum += t
	return {"mean": sum / times.size(), "p50": times[times.size() / 2], "p99": times[int(times.size() * 0.99)],
		"worst": times[-1], "calls": calls[calls.size() / 2], "calls_max": calls[-1], "tris": tris[tris.size() / 2],
		"tris_max": tris[-1]}


func _report(label: String, r: Dictionary) -> void:
	print("%-46s mean %6.2f ms  p50 %6.2f  p99 %6.2f  worst %6.2f   draw calls %d (max %d), triangles %d (max %d)" % [label,
		r["mean"], r["p50"], r["p99"], r["worst"], r["calls"], r["calls_max"], r["tris"], r["tris_max"]])
