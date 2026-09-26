class_name CultEmblemChoice
extends Resource
## D7: the owner's pick among the cult emblem options (CultEmblem, tools/showcase/cult_emblem_sheet.tscn,
## docs/questions/d7.md). A skin calls CultEmblem.build_mesh()/build_texture() with `option` and the
## colours from CultEmblem.default_scheme(option), so making the pick, once the owner has chosen, is
## this one value.
##
## ## DESIGN-TBD: the owner hasn't chosen an option yet (docs/questions/d7.md). Placeholder: A,
## "Broadcast Halo" — the recommended option. Putting the choice into every zone skin (hidden in
## logos and ads, shown openly in the Golden Zone) is a follow-up task once the owner picks.
@export_range(0, 3, 1) var option: int = CultEmblem.Option.A
