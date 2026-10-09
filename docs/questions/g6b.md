# G6b: the zone doodads as picture cards (owner's request, October 9, 2026)

The owner asked for each doodad to stay a simple box with a picture of the object drawn on it, open air
see-through, and left the choice of what to draw in each zone to the build ("I would go with your
recommendation"). The owner answered every question below the same day; they're recorded in GDD §3
(Zone doodads, their look). Nothing here is open. Review the looks in play with
`tools/showcase/doodad_review.tscn -- --skin=<zone> --lanes=5`, or as atlases with
`tools/godot.sh doodads --review` (build/doodad_review/<zone>.png).

1. **Each zone's three looks** (GDD §3, Zone doodads; §5, each zone's mood). G6 built them as meshes;
   the pictures change some of the pieces, where a picture reads better than the old mesh:
   - City: a street vending machine or a pillar plastered with posters (small, by seed), a street-food
     stall with stools and a corrugated roof (medium), a little shop with a roll-down shutter (large).
   - Gangland: a stack of rusted oil drums under a tyre (small; G6 had a burned-out car), a burned-out
     van (medium; G6 had two cars), a broken-down corrugated shop with a half-open shutter (large).
   - Marketplace: a potted palm or a flowering bush (small), the owner's vendor's stall (medium; G6 had
     two casino cabinets), a bank of slot machines back to back (large; G6 had a hedge row).
   - Corporate: a steel planter with a topiary (small), a glass security booth (medium; G6 had a barrier
     or a kiosk), a ribbed olive military supply container (large; G6 had a sculpture plinth).
   - Dead Zone: a broken column on its square foot (small; G6 had a crushed wreck), a rubble heap
     (medium), a burned-out bus (large; G6 had a fallen slab).
   - Golden Zone (outdoors and in the Golden Palace): a robed statue on a plinth or a gilded urn with a
     topiary (small; G6 had the planter here and the statue as the large one), a wall fountain (medium),
     a colonnade with red drapes and balustrades under a coffered roof (large; new).
   **Answered (owner, October 9, 2026):** the looks are fine. In `tools/asset_gen/doodad_art/<zone>_art.gd`.
2. **The Golden statue** (for the orchestrator: open question 279's placeholder moved). It is now the
   small class, painted rather than modelled, with its front and back on two cards a hair apart. Item
   279's placeholder moved from `golden_doodads.gd` (`_statue`) to
   `tools/asset_gen/doodad_art/golden_art.gd` (`_figure`, `_statue`); the figure is unchanged in
   spirit (faceless, robed, hands clasped, never `GoldenStatue`), and `test_golden_skin` still checks the
   doodad never builds from `GoldenStatue`.
3. **The push side doesn't show** (GDD §3: a push to "the side with room, a side chosen per doodad").
   The old default slanted a doodad's front back toward the side it pushes to; the pictures show the
   object only, the same from either side.
   **Answered (owner, October 9, 2026):** no hint needed. The grey box's default look still slants.
4. **A rubble heap dips at its edges** (GDD §3: a doodad reads as too tall to jump): a mound 2.5 m in
   its middle, 1.5 m at its edges; its collision box is 2.6 m everywhere as before.
   **Answered (owner, October 9, 2026):** fine. `dead_zone_art.gd` (`HEAP_EDGE`, `HEAP_PEAK`).
5. **The doodads' grazing-angle sheen**: a soft neutral sheen instead of the kit's violet default, which
   framed the dark zones' doodads in purple edges.
   **Answered (owner, October 9, 2026):** fine. `doodad_card.gdshader` (`sheen_color`, `sheen_strength`).

For the orchestrator (not design questions):
- The skins' "Doodads" export groups other than `doodad_palette` (the colours the G6 meshes used) are
  now unused. They were left in place so this branch doesn't collide with the dash-smash branch
  (`claude/nifty-brahmagupta-i5ov2i`, H5), which edits every `*_doodads.gd` and `zone_skin.gd`. They can
  go once that branch is resolved. H5's smashed-doodad debris can take a look's colours from its
  manifest entry (`colors`), since the cards have no vertex colours to tag.
- The owner's second request from the same message, doodads preferring the lane beside the side wall
  when it's open, is held until that branch is resolved (the owner's choice, "art first, placement
  later"; `docs/USER_REQUESTS.md`).
