class_name UiStyle
extends Resource
## The UI look in one place: palette, fonts and sizes. UiTheme builds the Godot Theme from it, and
## the custom-drawn widgets (scripts/ui/widgets/) read their colours and sizes from that Theme.
## Retune the look by editing data/ui/ui_style.tres (inspector) and nothing else.
##
## Hazard colours belong to gameplay (GDD §5, CLAUDE.md readability rules): pink = electric fence,
## orange = gap edges, yellow = signs, cyan = anti-grav pads, green = ramps. The UI never uses pink,
## orange or yellow as accents, so the HUD can't be mistaken for a hazard. Red is for warnings only.
## tests/suites/test_ui_kit.gd checks the accents against the hazard hues.
##
## Sizes are pixels at the 1280×720 base resolution; the canvas scales with the window.

@export_group("Palette")
## Primary accent: borders, focus, fills and progress. Azure, clearly bluer than the cyan pads.
@export var accent: Color = Color(0.22, 0.62, 1.0)
## Secondary accent, used sparingly: sub-headings and highlights. Violet, far from the fence pink.
@export var accent_2: Color = Color(0.56, 0.45, 1.0)
@export var text: Color = Color(0.92, 0.95, 1.0)
@export var text_dim: Color = Color(0.6, 0.67, 0.8)
@export var text_disabled: Color = Color(0.33, 0.37, 0.49)
## Errors, warnings and "can't afford". Never decoration.
@export var danger: Color = Color(1.0, 0.27, 0.3)
## Full-screen menu backdrop gradient.
@export var backdrop_top: Color = Color(0.035, 0.04, 0.11)
@export var backdrop_bottom: Color = Color(0.006, 0.006, 0.025)
## Translucent panel fill ("dark glass").
@export var panel: Color = Color(0.028, 0.04, 0.095, 0.88)
## Buttons, cards and other raised surfaces.
@export var surface: Color = Color(0.05, 0.075, 0.16, 0.94)
## Outline behind HUD text so it reads over the 3D scene.
@export var outline: Color = Color(0.0, 0.01, 0.04, 0.92)
## Earned stars: white-hot with an accent glow (yellow is the sign colour).
@export var star: Color = Color(0.97, 0.98, 1.0)
## The credit denominations' colours (1, 5, 25, 100; FB 8): silver, azure, violet, ice-white; the
## shapes differ too. The in-world credits use these too (CreditField), so the world and the UI
## always match.
@export var credit_colors: PackedColorArray = PackedColorArray([
	Color(0.72, 0.78, 0.88), Color(0.3, 0.68, 1.0), Color(0.64, 0.5, 1.0), Color(0.86, 0.95, 1.0)])

@export_group("Fonts")
## Headings and titles. Orbitron (OFL, assets/fonts/orbitron).
@export var display_font: Font = preload("res://assets/fonts/orbitron/Orbitron[wght].ttf")
## Body text, buttons and prices. Exo 2 (OFL, assets/fonts/exo2); has tabular figures.
@export var body_font: Font = preload("res://assets/fonts/exo2/Exo2[wght].ttf")
@export_range(400, 900, 50) var display_weight: int = 700
@export_range(400, 900, 50) var title_weight: int = 800
@export_range(100, 900, 50) var body_weight: int = 500
@export_range(100, 900, 50) var strong_weight: int = 700
## Numbers (scores, credits, HUD values) use the body font at this weight, with tabular figures.
## Not the display font: Orbitron's zero is slashed, so a score of 0 reads like a "no" sign (⊘).
@export_range(400, 900, 50) var value_weight: int = 800

@export_group("Type sizes")
@export_range(16, 96, 1) var title_size: int = 40
@export_range(12, 64, 1) var screen_title_size: int = 28
@export_range(12, 64, 1) var heading_size: int = 24
@export_range(10, 40, 1) var subheading_size: int = 15
@export_range(10, 40, 1) var body_size: int = 20
@export_range(10, 32, 1) var caption_size: int = 16
@export_range(10, 40, 1) var button_size: int = 20
@export_range(12, 64, 1) var value_size: int = 24
@export_range(12, 64, 1) var hud_text_size: int = 20
@export_range(12, 64, 1) var hud_value_size: int = 30

@export_group("Shapes")
@export_range(1, 6, 1) var border_width: int = 1
@export_range(1, 6, 1) var focus_width: int = 2
## Chamfer on buttons and small boxes (top-left and bottom-right corners are cut).
@export_range(0, 32, 1) var corner_cut: int = 10
@export_range(0, 40, 1) var panel_corner_cut: int = 16
@export_range(0, 40, 1) var glow_size: int = 10

@export_group("Sizes")
## Height of buttons and other controls on desktop.
@export_range(32, 96, 1) var control_height: int = 52
## Height of controls on phones and tablets: about 7 mm on a 6-inch phone at the 720p base.
@export_range(48, 120, 1) var touch_control_height: int = 76
## Text, icons and spacing are this much bigger on touch devices.
@export_range(1.0, 1.6, 0.05) var touch_scale: float = 1.2
@export_range(12, 64, 1) var icon_size: int = 24
@export_range(0, 48, 1) var spacing: int = 12
@export_range(0, 96, 1) var screen_margin: int = 32
