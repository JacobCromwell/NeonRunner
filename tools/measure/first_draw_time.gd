extends SceneTree
## Measures how long a material takes to draw for the first time (task L10): the renderer prepares a shader when it is first drawn
## (the Compatibility renderer, the web demo and low-end phones, compiles it then), so this is the compile time a level pays
## where it first shows the material. A quad with the material is added after the renderer has drawn a plain frame, and the time
## to two drawn frames is printed. Needs a real renderer (the dummy one compiles nothing), software or not; fresh
## XDG_DATA_HOME each run so no shader cache helps, a few runs each (the first of a process is slower):
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path . --rendering-method gl_compatibility \
##     --resolution 640x360 -s res://tools/measure/first_draw_time.gd -- [--display]
## Options: none measures the solid kit material (MeshKit.solid, which every zone compiles: a change to kit_solid.gdshader or the
## includes it takes shows up here); --display the shop windows' display material of the Marketplace skin (WindowDisplay).
## Compare a branch with main in two checkouts: the numbers are the machine's, so read the two side by side.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 2)
	root.add_child(cam)
	cam.make_current()
	var plain := MeshInstance3D.new()
	plain.mesh = QuadMesh.new()
	plain.material_override = StandardMaterial3D.new()
	root.add_child(plain)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var material: Material
	if args.has("--display"):
		material = (load("res://data/skins/marketplace_skin.tres") as MarketplaceSkin).display_material()
	else:
		material = MeshKit.solid({})
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	mi.material_override = material
	var t0: int = Time.get_ticks_usec()
	root.add_child(mi)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	print("first draw of the %s material: %.0f ms" % ["display" if args.has("--display") else "solid kit",
		float(Time.get_ticks_usec() - t0) / 1000.0])
	quit()
