extends Node
## The root scene: a 3D world root (runs, bosses, cinematics) under two UI layers (screens and
## overlays). The App autoload drives everything; this only provides the layers and hands itself
## to App.boot().

var world_root: Node3D
var ui_root: CanvasLayer
var overlay_root: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world_root = Node3D.new()
	world_root.name = "World"
	world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_root)
	ui_root = CanvasLayer.new()
	ui_root.name = "Screens"
	ui_root.layer = 10
	add_child(ui_root)
	overlay_root = CanvasLayer.new()
	overlay_root.name = "Overlays"
	overlay_root.layer = 20
	overlay_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_root)
	App.boot(self)
