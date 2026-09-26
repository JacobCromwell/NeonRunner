// Settings > Reduced flashing, for the hazard shaders. Settings.apply_visuals() sets this global
// uniform (declared in project.godot [shader_globals]): 1.0 turns strobes into steady glows, so no
// hazard flashes faster than about 3 times a second.
global uniform float reduced_flashing;

// A hazard WARNING flicker's brightness: `on` is the strobe's state (0 or 1) and `low` the level
// while it's off. With Reduced flashing it's a steady level halfway between: still unlike ON and
// OFF, without flashing.
float warning_flicker(float on, float low) {
	return mix(mix(low, 1.0, on), (low + 1.0) * 0.5, reduced_flashing);
}
