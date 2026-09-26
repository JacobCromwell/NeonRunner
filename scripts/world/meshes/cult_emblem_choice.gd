class_name CultEmblemChoice
extends Resource
## The cult emblem the skins draw (GDD §5, "The cult"): one of the CultEmblem options compared on
## tools/showcase/cult_emblem_sheet.tscn. A skin calls CultEmblem.build_mesh()/build_texture() with
## `option` and the colours from CultEmblem.default_scheme(option), never a hardcoded option.
##
## The owner chose B, the Convergent Triad (September 26, 2026; recorded in GDD §5).
@export_range(0, 3, 1) var option: int = CultEmblem.Option.B
