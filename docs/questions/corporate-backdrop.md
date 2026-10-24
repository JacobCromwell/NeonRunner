# Corporate backdrop: the three layers (the owner's reference image)

The owner's request (October 2026): rework the Corporate zone's background to match a new inspiration image
(`docs/art/reference/corporate_backdrop.webp`): a dark, overcast, militarised city street. Layer 1, closest to the player,
at street level: military walls, bunkers, barricades. Layer 2, a little higher and slightly behind the military walls:
corporate buildings, logos, some advertisements. Layer 3, higher up and rarer: brightly lit, lavish mansions of the elites.
Enemies, gameplay, hitboxes and the track pieces the player touches are unchanged. GDD §5, Zone 5 (Corporate).

1. **The mansions' light is a champagne white, not the picture's gold.** The colour rule (GDD §5: only hazards glow in
   hazard colours; decorative light keeps to cold white and the brand's blue) leaves yellow and orange to the hazards
   (the sign frame, the gap edge). The picture's mansions glow a true warm gold. Placeholder (`CorporateSkin.mansion_light_color`,
   DESIGN-TBD): a desaturated champagne white (1.0, 0.88, 0.7), saturation 0.30, clear of the hazard hues (the suite
   pins it under 0.35 and under half the sign yellow's), every mansion at least `mansion_min_y` (18 m) up, steady (the
   facade shader has no `TIME`, so Reduced flashing has nothing to change). The ivory stone under it reads warm gold. Should
   the rule give the elites' layer a true gold high above the lanes (it would be the one decorative warm glow in the game
   outside the Golden Zone), or does the champagne white stand?
2. **The picture's pink and cyan advertisements are in the brand's blue and cold white.** Pink is the electric fence and
   cyan the anti-grav pad. Placeholder: every sign, screen and blade in the brand's blue with cold-white art, as the zone's
   screens already were. Is that right, or should some ads wear another hue (and which)?
3. **The mark in the ring.** The picture's emblem is a "U" in a ring. The brand has one mark (`corp_logo()`, shared with
   Gangland's crates, GDD §5), so the towers' emblem signs and ring plates draw that mark inside a glowing ring
   (`PAT_CORP_LOGO` mode 4), the picture's composition with the brand's own symbol. Should the mark itself change to a
   "U"?
4. **Street-level props stand flush on the wall, not in front of it.** The picture's vehicles, jersey barriers, barrels and
   dishes stand on the street. The street here is the track, and the wall-run band must stay flush with nothing standing
   in the play space (the suite pins it), so the military layer is paint on the wall through the band (armour plate,
   steel gates, camouflaged and bare precast blocks, a jersey-barrier skirt, cable runs, stencils) and above it a roof
   deck with sandbag and precast parapets, razor wire, dishes, masts, water tanks, supply containers, radar domes and
   watchtowers. No vehicles. Is flush paint enough for "barricades and bunkers", or should some barricade blocks stand
   out of the wall above the band (never in it)?
5. **Proportions** (placeholders, all in `CorporateSkin`'s Backdrop groups): the military roof is 8.4 to 11.6 m up; the
   towers stand 2.5 to 6.5 m behind it; about one tower in five is crowned with a mansion, 2 to 4 terraces, its first
   floor 18 to 42 m up. From the runner's low camera most of the walls' height shows only in a slice at the top of the
   frame, so the mansions are small, warm accents there. Are mansions rare enough, and big enough?
6. **The dash walls keep the old look.** A dash wall (the end of a building across the street, `CorporateDashWall`) is a
   gameplay piece and is unchanged: it still wears the sterile podium cladding and glass, not the new military wall.
   Should it be restyled to match?
