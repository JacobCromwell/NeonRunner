class_name MechaGuppyBiteWater
extends Node3D
## The sea at the bottom of the holes Mecha Guppy bites out of phase 3's top (the owner, October 2026: "When the shark
## bites the roof in the beach boss battle, there is an open space in the THIRD phase. That open space should have blue
## water at the bottom. The shark bite in phase one and phase two still works great"; task J3). DESIGN-TBD
## (docs/questions/j3.md).
##
## Why: on phase 3's top (task E5e-g, MechaGuppyTop) Mecha Guppy swims in the sea alongside, whose surface
## (MechaGuppyTop.water_y) lies just under the deck on both sides, from just outside the eaves outward. Its chomp bite after
## each wave (MechaGuppyClimb.plan_top_bite, eaten by MechaGuppyStairs.eat_crescent at its snap) opens a crescent in the
## deck whose broken face runs down the top's tower (MechaGuppyLooks._bite_edge), 40-75 m into the haze: an open space with
## the sea right beside it but none at its bottom. (The floor bites of phases 1 and 2, in the climb's roofs, are left as
## they were: "still works great".)
##
## So from its snap, each bite eaten on the top has a sheet of that same sea under its hole, at that same surface and in
## its look (the backdrop's sea shader in the skin's sea_mid_color, as MechaGuppyTop's water): over the whole crescent
## (its track span and ENDS beyond it either way; across the deck from its deepest point to the bitten side's wall, or wall
## to wall for a full-width one) and on out through the bitten side, where its wall and eave are gone, to OVERLAP under
## the water beside the top (both sides for a full-width one). The hole shows the sea at its bottom, one with the sea
## beside the top; past the crescent's ends, the open ends of the eave over the gap the water beside the top leaves at the
## tower's wall show water too, not the haze (task J3's review). The sheet lies SURFACE_UNDER below that water, so where
## they overlap the water beside the top is what shows; under the deck the tower hides it.
## Look only: no collision, so nothing of E5e-g's play changes (its timing, hitboxes, attacks, the falls: a runner who
## falls into the hole still falls through it, with no splash). A small pool of SHEETS quads built once and moved each
## frame; unshaded, so every renderer draws it alike; nothing glows or flickers.

## The sheets kept ready (one per bite eaten on the top within reach: they come one per dive, far apart).
const SHEETS: int = 3
## How far a sheet reaches under the water beside the top, past its inner edge (just outside the eaves) (metres).
const OVERLAP: float = 0.5
## How far a sheet reaches along the track past each end of its crescent (metres): under the eave and the tower's wall there,
## over the gap between the wall and the water beside the top, which the eave's open end would show down to the haze.
const ENDS: float = 6.0
## How far a sheet lies under the water beside the top (metres: never level with it, so the two never fight).
const SURFACE_UNDER: float = 0.002
## A bite that ends this far behind the runner is passed: its sheet goes (metres; the camera never looks back).
const PASSED: float = 40.0

var boss: MechaGuppy
var climb: MechaGuppyClimb
## The holes the sheets showed at the last update (tests): {roof (its index), bite (the MechaGuppyCrescent), x0, x1 (world
## x), from, to (track distances), y (world height)}.
var holes: Array[Dictionary] = []
var _sheets: Array[MeshInstance3D] = []
## The towers' half width, and where the water beside the top begins (world x, from the middle).
var _wall: float = 3.9
var _water_from: float = 5.6


func setup(p_boss: MechaGuppy) -> void:
	boss = p_boss
	climb = boss.climb
	top_level = true
	transform = Transform3D.IDENTITY
	_wall = boss.world.geo.wall_x()
	_water_from = _wall + MechaGuppyLooks.EAVE_REACH
	var mat := ShaderMaterial.new()
	mat.shader = load(MechaGuppyWaterfall.SEA_SHADER_PATH) as Shader
	var beach := boss.world.skin as BeachSkin
	if beach != null:
		mat.set_shader_parameter(&"sea_color", beach.sea_mid_color)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	for i: int in SHEETS:
		var sheet := MeshInstance3D.new()
		sheet.name = "Sheet%d" % i
		sheet.mesh = plane
		sheet.material_override = mat
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.visible = false
		add_child(sheet)
		_sheets.append(sheet)


func _process(_delta: float) -> void:
	update()


## Lays a sheet under each hole bitten out of the top near the runner (none before phase 3's top is reached).
func update() -> void:
	holes.clear()
	if boss != null and boss.top != null and boss.top.started() and climb != null and climb.top_planned() \
			and boss.world != null and boss.world.player != null:
		var d: float = boss.world.player.distance
		var roof: MechaGuppyClimb.Roof = climb.roofs[-1]
		for b: MechaGuppyCrescent in roof.top_bites:
			if holes.size() >= SHEETS:
				break
			if b.eaten and not b.skipped and b.to > d - PASSED:
				holes.append(_hole(roof, b))
	for i: int in _sheets.size():
		var sheet: MeshInstance3D = _sheets[i]
		sheet.visible = i < holes.size()
		if sheet.visible:
			var h: Dictionary = holes[i]
			var x0: float = float(h["x0"])
			var x1: float = float(h["x1"])
			var from: float = float(h["from"])
			var to: float = float(h["to"])
			sheet.transform = Transform3D(Basis.from_scale(Vector3(x1 - x0, 1.0, to - from)),
				Vector3((x0 + x1) * 0.5, float(h["y"]), TrackGeometry.world_z((from + to) * 0.5)))


## Bite `b`'s hole in the top `roof`: its track span and ENDS beyond it either way, across the deck from its deepest point
## (wall to wall for a full-width one) and out through its bitten side (both sides for a full-width one) to OVERLAP under
## the water beside the top, just under that water's surface.
func _hole(roof: MechaGuppyClimb.Roof, b: MechaGuppyCrescent) -> Dictionary:
	var out: float = _water_from + OVERLAP
	var x0: float = -out
	var x1: float = out
	if not b.full:
		var inner: float = b.x_of(minf(b.deepest(), b.width()))
		if b.side > 0:
			x0 = maxf(inner, -_wall)
		else:
			x1 = minf(inner, _wall)
	return {"roof": roof.index, "bite": b, "x0": x0, "x1": x1, "from": b.from - ENDS, "to": b.to + ENDS,
		"y": boss.top.water_y() - SURFACE_UNDER}
