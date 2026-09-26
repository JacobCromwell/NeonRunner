extends SceneTree
## Draws the app icon (assets/icon/icon.png, 512×512): a neon "N" with speed streaks on a dark
## rounded square. Placeholder art until the owner picks a title and brand (OPEN_QUESTIONS §10).
## Regenerate: godot --headless --path . -s res://tools/asset_gen/icon_gen.gd

const SIZE: int = 512
const OUT: String = "res://assets/icon/icon.png"
const CYAN := Color(0.25, 0.92, 1.0)
const PINK := Color(1.0, 0.25, 0.75)
const BG_TOP := Color(0.11, 0.04, 0.2)
const BG_BOTTOM := Color(0.02, 0.01, 0.05)


func _initialize() -> void:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	# The "N": three strokes, slightly italic for speed.
	var strokes: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(190, 380), Vector2(215, 132)]),
		PackedVector2Array([Vector2(215, 132), Vector2(322, 380)]),
		PackedVector2Array([Vector2(322, 380), Vector2(347, 132)]),
	]
	var streaks: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(58, 200), Vector2(150, 200)]),
		PackedVector2Array([Vector2(88, 256), Vector2(160, 256)]),
		PackedVector2Array([Vector2(40, 312), Vector2(150, 312)]),
	]
	for y: int in SIZE:
		for x: int in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var bg_d: float = _rounded_box(p - Vector2(SIZE, SIZE) * 0.5, Vector2(SIZE, SIZE) * 0.5 - Vector2(8, 8), 96.0)
			if bg_d > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c: Color = BG_BOTTOM.lerp(BG_TOP, 1.0 - float(y) / SIZE)
			# Faint horizon grid for the neon-runner feel.
			if y > 360 and (int(y - 360) % 24 < 2 or absf(fmod(float(x) - 256.0 + (y - 360) * (float(x) - 256.0) / 300.0, 48.0)) < 1.5):
				c = c.lerp(Color(0.45, 0.2, 0.9), 0.25)
			c = _neon(c, p, streaks, PINK, 7.0, 20.0)
			c = _neon(c, p, strokes, CYAN, 16.0, 30.0)
			c.a = clampf(1.0 - bg_d, 0.0, 1.0)
			img.set_pixel(x, y, c)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	img.save_png(OUT)
	print("Wrote ", OUT)
	quit()


## Adds a glowing stroke set: a bright core of half-width `core`, fading glow over `glow` pixels.
func _neon(base: Color, p: Vector2, segments: Array[PackedVector2Array], color: Color, core: float, glow: float) -> Color:
	var d: float = INF
	for s: PackedVector2Array in segments:
		d = minf(d, _segment_distance(p, s[0], s[1]))
	var edge: float = d - core
	if edge <= 0.0:
		var inner: float = clampf(-edge / core, 0.0, 1.0)
		return color.lerp(Color(1, 1, 1), inner * 0.55)
	var aa: float = clampf(1.0 - edge, 0.0, 1.0)
	var halo: float = exp(-edge / glow) * 0.85
	return base.lerp(color, maxf(aa, halo))


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _rounded_box(p: Vector2, half: Vector2, radius: float) -> float:
	var q: Vector2 = p.abs() - half + Vector2(radius, radius)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
