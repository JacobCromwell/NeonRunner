# H7b, dash walls (the art): open questions

The owner's brief (GDD §9.14): the wall "uses the zone's side-wall look (the same building faces), turned to face the
player", "looking like a building in the middle of the street ... crumble and explode into rubble when hit by the
player". Every zone's wall is built from its own side-wall kit (`docs/ARCHITECTURE.md`, Zone skins, "Dash walls'
looks"). What the GDD doesn't say, and what I chose (each is marked `DESIGN-TBD` in the zone's builder):

- **What kind of building, per zone** (the GDD gives none: only "the same building faces"). Placeholder: four layouts
  per zone, picked by the wall's seed, each a block of the zone's own facades. Corporate: a curtain-wall tower's foot
  on a steel canopy, a lobby with ribbon windows, a military compound's front (blast walls under an armoured block),
  a podium building. Dead Zone: a burnt tower's foot, a skeleton of steel and slabs, a blast with a heap of rubble, a
  charred bunker. Golden Zone: a rusticated palace under its frieze, a palace with a storey of gold-framed windows,
  a mirror-glass tower's foot, a gatehouse. Golden Palace: a marble block of moulded panels between gilded
  pilasters, one with galleries, one with arched windows, one with gold bands and a coffered frieze. City: a dark
  block in each of its four window grids. Gangland: a ruined block, one with a makeshift balcony, a shop patched with
  rusty sheets, a collapsed corner. Marketplace: a shop row (two window widths), a market hall under its glass vault,
  an arcade under a tin lean-to. Are these the right buildings, and should any zone's wall be a particular one of
  them (a Corporate wall that is always the military's, say)?
- **How big it reads.** The box is the H7a placeholder (9 m tall, 2.5 m deep, 9.6 to 12 m wide): next to the walls'
  towers (40 to 170 m) it reads as a low block, a podium or a three-storey building, never a tower, however it is
  dressed. The looks are tuned to that box (their storeys, bays and bands are laid out for 9 m; only the roof line and
  the roof plant follow `size.y`), so a different `MovementTuning.dash_wall_height` keeps the box filled but would
  want the proportions looked at again (the Golden zones' frieze and the Golden Palace's panels most). Should it be
  taller (about 12 m would stand clear of the side walls' calm band and read as a building at a distance)?
- **No cue in the dash's colour.** The brief welcomes "a breakable or cracked hint"; I used cracks spreading from a
  few points, a chipped patch with rebar showing and, on the ruins, broken tops and rubble at the foot, all in the
  zone's own unlit colours. A glowing cue (a seam of `PlayerSuit.GLOW_PALE` along a crack, say) would be the one
  thing on the wall that glows, and the hook's contract (and its test) is that nothing does, so I left it out.
  Should the cracks glow faintly in the dash's colour, so the wall reads as "breaks to the dash" before it's close?
- **Dark windows even in the lit zones.** Every vertex's lit-window share is 0, so a wall's windows are dark glass
  and its neon (the City's) is dead paint: in the City and Corporate it is the one dark block among lit towers, and it
  reads as solid for that. Allowed lit windows would make it match the towers more and need the hook's "never
  glowing" rule (`test_dash_walls`, `_test_skins`) loosened to "no glowing hazard colour". Wanted?
- **Dark openings at the foot.** Corporate's lobby look has smoked glass in steel frames down to the floor under a
  canopy, and the Golden Palace's galleries and arched windows are dark (a warm umber with the far floor a shade
  lighter, never black): none is at a runner's height except the lobby's glass, which has a mullion every 3 m and a
  dark brand-paint band above it. Does a dark lobby read as passable? If so it can be cladding like the other
  podium looks.
- **No people, signs or screens.** The Marketplace's shop windows show their displays of goods and nothing else (no
  citizens: they play behind the walls' windows), Corporate has no banner or brand sign, the Golden zones no statue
  (a statue is a Gilded Sentinel's silhouette) or tapestry (red), the Dead Zone no billboard, Gangland no laundry or
  ad, the City no neon sign or screen. Right?
- **The look picks.** The seed's remainder by 4 picks the layout and by 12 the tone (`DashWallKit.look_of`,
  `tone_of`), so a level's 2 to 4 walls, whose seeds come from the level's seed, can repeat a layout. Should the
  walls of one level be forced to differ?
- **Roof plant and finials** (`DashWallKit.ROOF`, 1 m of the box's height): the building's own top is 1 m under the
  box's, and what stands on it (air handlers, urns, a mast) fills the rest, so the silhouette isn't a flat box. The
  hitbox still reaches the box's top, so a flyer's lift (`Enemy.dash_wall_lift`) clears the plant too. The ruins' broken
  tops (the Dead Zone, Gangland) stand lower in places, up to 2.8 m under the box's top, where the hitbox reaches
  higher than the look; nothing but a flyer comes within reach of that.
