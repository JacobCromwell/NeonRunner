extends SceneTree
## Paints the zone doodads' picture cards (owner's request October 9, 2026: doodads as simple boxes
## with pictures of the object drawn on them, open air cut out) and writes, per zone,
## assets/sprites/doodads/<zone>.png (the atlas) and <zone>.json (the manifest DoodadCards reads: where
## each picture sits in the atlas and which cards make each size class's looks).
##
##   tools/godot.sh doodads [--only=marketplace,city] [--review]
##
## Each zone's pictures come from tools/asset_gen/doodad_art/<zone>_art.gd (`static func paint(s:
## DoodadArtSet)`), drawn on the CPU (DoodadPaint), so this runs headless. The boxes' sizes come from
## data/tuning/movement.tres (MovementTuning.doodad_size): retune them, then regenerate. --review also
## writes each zone's atlas on a grey backdrop to build/doodad_review/<zone>.png, to look at.

const OUT_DIR: String = "res://assets/sprites/doodads"
const REVIEW_DIR: String = "res://build/doodad_review"
const ZONES: Array[String] = ["city", "gangland", "marketplace", "corporate", "dead_zone", "golden"]
## Pixels between pictures in the atlas (so mipmaps don't bleed one into the next).
const PADDING: int = 8


func _init() -> void:
	var only: PackedStringArray = []
	var review: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
		elif arg == "--review":
			review = true
	var tuning := load("res://data/tuning/movement.tres") as MovementTuning
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if review:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var failed: bool = false
	for zone: String in ZONES:
		if not only.is_empty() and not only.has(zone):
			continue
		var started: int = Time.get_ticks_msec()
		var art := load("res://tools/asset_gen/doodad_art/%s_art.gd" % zone) as GDScript
		if art == null:
			push_error("No doodad art script for %s" % zone)
			failed = true
			continue
		var art_set := DoodadArtSet.new(zone, tuning)
		art.call("paint", art_set)
		if not _write(art_set, review):
			failed = true
			continue
		print("%-12s %3d pictures, %d looks  (%.1f s)" % [zone, art_set.pictures.size(), _look_count(art_set),
			float(Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failed else 0)


func _look_count(art_set: DoodadArtSet) -> int:
	var n: int = 0
	for size_class: String in art_set.designs:
		n += (art_set.designs[size_class] as Array).size()
	return n


## Packs `art_set`'s pictures into an atlas and writes it with its manifest. False on a problem.
func _write(art_set: DoodadArtSet, review: bool) -> bool:
	for size_class: String in art_set.designs:
		for design: Dictionary in art_set.designs[size_class]:
			for c: Dictionary in design["cards"]:
				if not art_set.pictures.has(String(c["image"])):
					push_error("%s: look %s uses a missing picture %s" % [art_set.zone, design["name"], c["image"]])
					return false
	var names: Array = art_set.pictures.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		var ha: int = (art_set.pictures[a] as Image).get_height()
		var hb: int = (art_set.pictures[b] as Image).get_height()
		return ha > hb if ha != hb else a < b)
	var placed: Dictionary = {}
	var size := Vector2i.ZERO
	for width: int in [1024, 2048, 4096]:
		placed = _pack(art_set, names, width)
		if not placed.is_empty():
			var used: int = 0
			for n: String in placed:
				var r: Rect2i = placed[n]
				used = maxi(used, r.end.y + PADDING)
			size = Vector2i(width, _pow2(used))
			if size.y <= width:
				break
	if placed.is_empty():
		push_error("%s: the pictures don't fit a 4096 atlas" % art_set.zone)
		return false
	var atlas := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for n: String in placed:
		var pic: Image = art_set.pictures[n]
		var r: Rect2i = placed[n]
		atlas.blit_rect(pic, Rect2i(Vector2i.ZERO, pic.get_size()), r.position)
	# Colour into every transparent pixel (the padding too), so mipmaps and filtering never pull a
	# dark fringe into an edge; alpha stays as painted.
	atlas.fix_alpha_edges()
	var png_path: String = OUT_DIR.path_join(art_set.zone + ".png")
	if atlas.save_png(ProjectSettings.globalize_path(png_path)) != OK:
		push_error("can't write %s" % png_path)
		return false
	_ensure_import(png_path)
	var images: Dictionary = {}
	for n: String in placed:
		var r: Rect2i = placed[n]
		images[n] = [r.position.x, r.position.y, r.size.x, r.size.y]
	var manifest := {
		"zone": art_set.zone,
		"generated_by": "tools/asset_gen/doodad_art_gen.gd (tools/godot.sh doodads)",
		"atlas": png_path,
		"atlas_size": [size.x, size.y],
		"px_per_m": art_set.px_per_m,
		"boxes": _boxes(art_set),
		"images": images,
		"designs": art_set.designs,
	}
	var f := FileAccess.open(OUT_DIR.path_join(art_set.zone + ".json"), FileAccess.WRITE)
	if f == null:
		push_error("can't write the %s manifest" % art_set.zone)
		return false
	f.store_string(JSON.stringify(manifest, "\t", false) + "\n")
	f.close()
	if review:
		var sheet := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.42, 0.43, 0.46))
		sheet.blend_rect(atlas, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
		sheet.save_png(ProjectSettings.globalize_path(REVIEW_DIR.path_join(art_set.zone + ".png")))
	return true


func _boxes(art_set: DoodadArtSet) -> Dictionary:
	var out: Dictionary = {}
	for size_class: String in art_set.boxes:
		var b: Vector3 = art_set.boxes[size_class]
		out[size_class] = [b.x, b.y, b.z]
	return out


## Shelf packing, tallest first, `width` wide: name -> Rect2i, or {} if a picture is wider.
func _pack(art_set: DoodadArtSet, names: Array, width: int) -> Dictionary:
	var out: Dictionary = {}
	var x: int = PADDING
	var y: int = PADDING
	var shelf: int = 0
	for n: String in names:
		var s: Vector2i = (art_set.pictures[n] as Image).get_size()
		if s.x + PADDING * 2 > width:
			return {}
		if x + s.x + PADDING > width:
			x = PADDING
			y += shelf + PADDING
			shelf = 0
		out[n] = Rect2i(Vector2i(x, y), s)
		x += s.x + PADDING
		shelf = maxi(shelf, s.y)
	return out


func _pow2(v: int) -> int:
	var p: int = 256
	while p < v:
		p *= 2
	return p


## A new atlas gets import settings for a 3D texture seen at a distance: compressed for the GPU
## (ETC2/ASTC on phones and the web, S3TC/BPTC on PC), with mipmaps, colour bled into its borders.
func _ensure_import(png_path: String) -> void:
	var import_path: String = ProjectSettings.globalize_path(png_path + ".import")
	if FileAccess.file_exists(import_path):
		return
	var f := FileAccess.open(import_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("""[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="%s"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
""" % png_path)
	f.close()
