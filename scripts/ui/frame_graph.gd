class_name FrameGraph
extends CanvasLayer
## The frame-time graph (task PERF1, debug builds only; F7 shows and hides it, LevelRun): the last
## SHOWN_FRAMES frames of a FrameMonitor as bars, so the owner can see a lag spike the moment it
## happens and say which one they mean.
##
## Each bar is one frame, as tall as its whole time (what the screen showed: the game's work, the
## renderer's and any wait for vsync), its lower part the game's own work (FrameMonitor's `logic`). A
## spike (a frame over SPIKE_FACTOR times the median of the frames shown, and over SPIKE_FLOOR_MS) is
## drawn in the spike colour, and listed below the graph with how long ago it was, its time and its tags
## (what happened in it: a chunk built, an enemy's first spawn, shaders compiled, ...; FrameMonitor's
## header lists them). A hit-stop holds the camera still for a few frames while the run goes on (G2's
## brief freeze on kills): those frames are marked under the graph and listed too, since a held camera
## can read as a hitch even when every frame is on time. The lines across are 16.7 ms (60 fps) and
## 33.3 ms (30 fps).

const SHOWN_FRAMES: int = 300
const SPIKE_FACTOR: float = 1.6
const SPIKE_FLOOR_MS: float = 8.0
## The graph's full height, in ms.
const SCALE_MS: float = 50.0
const LISTED: int = 6
## In the bottom-right corner, clear of the HUD (its score and pause button are top right, its items
## bottom left).
const GRAPH_SIZE := Vector2(480.0, 110.0)
const MARGIN: float = 16.0
const LINE_HEIGHT: float = 16.0
## The longest line of text shown (the panel's width at its font size).
const LINE_CHARS: int = 74
const BACK := Color(0.02, 0.02, 0.05, 0.78)
const LOGIC := Color(0.45, 0.8, 1.0)
const REST := Color(0.35, 0.4, 0.55)
const SPIKE := Color(1.0, 0.42, 0.3)
const HELD := Color(0.75, 0.55, 1.0)
const GUIDE := Color(1.0, 1.0, 1.0, 0.25)

var monitor: FrameMonitor
var _view: Control
var _font: Font


func _init() -> void:
	layer = 50
	visible = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_view.custom_minimum_size = GRAPH_SIZE
	_view.draw.connect(_draw_graph)
	add_child(_view)
	_font = ThemeDB.fallback_font


func toggle() -> void:
	visible = not visible


func _process(_delta: float) -> void:
	if visible and _view != null:
		_view.queue_redraw()


## The spikes and holds among the frames shown, newest first: {frame (its index in the monitor's lists),
## total_ms, logic_ms, held (a hit-stop's frames in a row, 0 for a spike), tags}.
func events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if monitor == null:
		return out
	var n: int = monitor.frame_count()
	var from: int = maxi(n - SHOWN_FRAMES, 0)
	var limit: float = spike_limit_ms()
	var i: int = n - 1
	while i >= from:
		var total: float = monitor.totals[i] / 1000.0
		if monitor.frozen[i] == 1:
			# A hit-stop: its frames in a row, from the first (where the kill's tags are).
			var first: int = i
			while first > from and monitor.frozen[first - 1] == 1:
				first -= 1
			out.append({"frame": first, "total_ms": monitor.totals[first] / 1000.0,
				"logic_ms": monitor.logics[first] / 1000.0, "held": i - first + 1, "tags": _tags_near(first)})
			i = first - 1
			continue
		if total > limit:
			out.append({"frame": i, "total_ms": total, "logic_ms": monitor.logics[i] / 1000.0, "held": 0,
				"tags": monitor.tags[i]})
		i -= 1
	return out


## The time over which a frame shown counts as a spike.
func spike_limit_ms() -> float:
	var n: int = monitor.frame_count() if monitor != null else 0
	var shown := PackedFloat32Array()
	for i: int in range(maxi(n - SHOWN_FRAMES, 0), n):
		shown.append(monitor.totals[i] / 1000.0)
	shown.sort()
	return maxf(SPIKE_FLOOR_MS, FrameMonitor.percentile(shown, 0.5) * SPIKE_FACTOR)


## A hit-stop's tags: those of the frame it began in and the frame before (a kill in a physics step can
## start it a frame early).
func _tags_near(i: int) -> PackedStringArray:
	var out := PackedStringArray()
	for k: int in [i - 1, i]:
		if k >= 0 and k < monitor.frame_count():
			out.append_array(monitor.tags[k])
	return out


func _draw_graph() -> void:
	if monitor == null:
		return
	var listed: Array[Dictionary] = events().slice(0, LISTED)
	var text_height: float = LINE_HEIGHT * (listed.size() + 1) + 8.0
	var origin := Vector2(-GRAPH_SIZE.x - MARGIN, -GRAPH_SIZE.y - text_height - MARGIN)
	_view.draw_rect(Rect2(origin - Vector2(6.0, 6.0), GRAPH_SIZE + Vector2(12.0, 12.0 + text_height)), BACK)
	var n: int = monitor.frame_count()
	var from: int = maxi(n - SHOWN_FRAMES, 0)
	var bar: float = GRAPH_SIZE.x / SHOWN_FRAMES
	var limit: float = spike_limit_ms()
	var worst: float = 0.0
	var sum: float = 0.0
	for i: int in range(from, n):
		var x: float = origin.x + (i - from) * bar
		var total: float = monitor.totals[i] / 1000.0
		var logic: float = monitor.logics[i] / 1000.0
		worst = maxf(worst, total)
		sum += total
		var h: float = minf(total / SCALE_MS, 1.0) * GRAPH_SIZE.y
		var hl: float = minf(logic / SCALE_MS, 1.0) * GRAPH_SIZE.y
		var bottom: float = origin.y + GRAPH_SIZE.y
		_view.draw_rect(Rect2(x, bottom - h, maxf(bar, 1.0), h), SPIKE if total > limit else REST)
		_view.draw_rect(Rect2(x, bottom - hl, maxf(bar, 1.0), hl), SPIKE if total > limit else LOGIC)
		if monitor.frozen[i] == 1:
			_view.draw_rect(Rect2(x, bottom + 2.0, maxf(bar, 1.0), 4.0), HELD)
	for ms: float in [1000.0 / 60.0, 1000.0 / 30.0]:
		var y: float = origin.y + GRAPH_SIZE.y * (1.0 - ms / SCALE_MS)
		_view.draw_line(Vector2(origin.x, y), Vector2(origin.x + GRAPH_SIZE.x, y), GUIDE)
	var shown: int = n - from
	var head: String = "Frame times (F7)   mean %.1f ms   worst %.1f ms   spikes over %.1f ms" % [
		sum / maxf(shown, 1), worst, limit]
	var y_text: float = origin.y + GRAPH_SIZE.y + 22.0
	_view.draw_string(_font, Vector2(origin.x, y_text), head.left(LINE_CHARS), HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var newest: int = monitor.starts[n - 1] if n > 0 else 0
	for e: Dictionary in listed:
		y_text += LINE_HEIGHT
		var ago: float = (newest - monitor.starts[int(e["frame"])]) / 1000000.0
		var line: String
		if int(e["held"]) > 0:
			line = "%4.1f s ago  camera held %d frames (hit-stop)  %s" % [ago, int(e["held"]),
				_short_tags(e["tags"])]
		else:
			line = "%4.1f s ago  %5.1f ms (game %4.1f)  %s" % [ago, float(e["total_ms"]), float(e["logic_ms"]),
				_short_tags(e["tags"])]
		_view.draw_string(_font, Vector2(origin.x, y_text), line.left(LINE_CHARS), HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			HELD if int(e["held"]) > 0 else SPIKE)


## A frame's tags for the list: each once, the credits and sounds left out unless that's all there is.
static func _short_tags(tags: PackedStringArray) -> String:
	var out := PackedStringArray()
	var minor := PackedStringArray()
	for t: String in tags:
		if t == "credit" or t == "fire" or t.begins_with("sound:"):
			if not minor.has(t):
				minor.append(t)
		elif not out.has(t):
			out.append(t)
	if out.is_empty():
		out = minor
	if out.is_empty():
		return "(nothing the run did: the renderer, or another program)"
	return " ".join(out.slice(0, 6))
