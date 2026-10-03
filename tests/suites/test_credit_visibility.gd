extends TestSuite
## Highest-tier readability is visual only: lower tiers, pickup reach and batching stay intact.


func run() -> void:
	check(LevelGenerator.DENOMINATIONS == [1, 5, 25, 100], "100 remains the highest generated credit denomination")
	check(CreditField.denomination(99) == 25 and CreditField.denomination(100) == 100,
		"denomination thresholds are unchanged")
	check(CreditField.PICKUP_MARGIN == Vector3(0.45, 0.35, 0.35), "pickup reach is unchanged")
	var highest: Mesh = CreditField.mesh_for(100)
	var bounds: AABB = highest.get_aabb()
	check(is_equal_approx(bounds.size.y, 1.1), "100 has a taller 1.1 m cut-gem silhouette")
	check(bounds.size.x <= 0.84 + 0.001 and bounds.size.z <= 0.84 + 0.001,
		"100 keeps its old width, not a lane-filling badge")
	check(highest.get_surface_count() == 1, "100 stays one mesh surface for batching")
	check(highest == CreditField.mesh_for(100), "100 mesh is cached")
	var material := CreditField.material_for(100) as ShaderMaterial
	check(material.shader.code == CreditField.HIGH_CREDIT_SHADER, "only 100 uses the contrast shader")
	check(material.shader.code.contains("unshaded") and material.shader.code.contains("fog_disabled")
		and not material.shader.code.contains("EMISSION") and not material.shader.code.contains("ALPHA"),
		"highest tier is opaque and lighting/fog/bloom independent")
	check(not material.shader.code.contains("sin(TIME") and not material.shader.code.contains("cos(TIME"),
		"no brightness flashing (TIME only rotates the mesh)")
	check(CreditField.color_of(100) == UiTheme.credit_color(100), "highest tier retains the shared ice-white currency colour")
	for value: int in [1, 5, 25]:
		var lower := CreditField.material_for(value) as ShaderMaterial
		check(lower.shader.code == CreditField.SPIN_SHADER, "%d keeps its original shader" % value)
		check(is_equal_approx(float(lower.get_shader_parameter(&"energy")), 2.0 if value < 25 else 3.0),
			"%d keeps its original glow energy" % value)
		check(is_equal_approx(float(lower.get_shader_parameter(&"spin_speed")), 3.0),
			"%d keeps its original spin" % value)
	check(is_equal_approx(CreditField.mesh_for(25).get_aabb().size.y, 0.39),
		"25 remains the original small pointed diamond")
	await _test_collection_and_placement()


func _test_collection_and_placement() -> void:
	var sim := RunSim.new(tree, tuning)
	var layout: LevelLayout = RunSim.layout(3)
	layout.credits.append({"at": 10.0, "surface": "floor", "lane": 1, "value": 100})
	var world: RunWorld = sim.build_world(layout)
	world.credits.place([
		{"at": 16.0, "surface": "floor", "lane": 1, "value": 100},
		{"at": 16.0, "surface": "floor", "lane": 0, "value": 100},
	])
	for child: Node in world.credits.get_children():
		var inst := child as MultiMeshInstance3D
		check(inst != null and inst.multimesh.mesh == CreditField.mesh_for(100)
			and inst.material_override == CreditField.material_for(100),
			"initial and pooled placed 100 credits use the same visible mesh/material")
	await sim.step_world(world, 2.0)
	check(world.score.credits == 200 and world.score.credit_pickups == 2,
		"initial and placed highest-tier credits still pay 100 each")
	check(world.credits.remaining() == 1, "taller visuals do not collect credits in a different lane")
	await sim.free_world(world)
