class_name CityIntroWarmup
extends ShaderWarmup
## Draws, while the City intro fades in, one tiny copy of each look that shows for the first time later (the runner, the glass
## shards, the sparks and the flare, the frame's opening: everything the set keeps hidden until its moment). A renderer prepares a
## shader the first time it draws it, and the Compatibility renderer (the web demo, low-end phones) compiles it then: at the burst
## that was a long frame, in the game's first cinematic, just as the runner leaps. It is the run's ShaderWarmup (task PERF1: the
## samples sit in front of the camera, far too small to see, for two drawn frames, then go), which a cinematic never has, since it
## plays before the level exists, pointed at the intro's hidden nodes instead of a RunWorld's. Visual only: the intro is on
## its own, so nothing here touches a run. CityIntro adds it only when the game renders (ShaderWarmup.needed()).


## Samples what `roots` keep hidden, in front of `p_camera` (the warm-up becomes its child).
func setup_intro(p_camera: Camera3D, roots: Array[Node]) -> void:
	name = "CityIntroWarmup"
	p_camera.add_child(self)
	position = Vector3(0.0, 0.0, -AHEAD)
	scale = Vector3.ONE * SCALE
	for root: Node in roots:
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			var geometry := node as GeometryInstance3D
			if geometry != null and not geometry.is_visible_in_tree():
				_sample_geometry(geometry)
	_show_all()
	RenderingServer.frame_post_draw.connect(_on_drawn)


## How many different looks are sampled.
func samples() -> int:
	return keys.size()
