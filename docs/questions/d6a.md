# D6a: the Golden Zone skin

Numbers and colours are exports on `GoldenSkin` (`scripts/world/skins/golden_skin.gd`, in the F6 panel),
unless another file is named.

1. **Time of day** (GDD §5 gives the palette and mood, not the hour). Placeholder: the blue hour. A deep
   blue sky over the warm afterglow of the set sun, a pale moon, the far skyline glittering with warm
   windows; the white palaces floodlit from their entablatures (the light fading up their faces), the
   street's warm lamplight on the calm band, fog from 26 m to 230 m (Environment group). In full daylight
   the hazards' glow washed out against the white; at night the white turned grey. Right hour?
2. **The walkways over water** (GDD §5: golden walkways over water, proposed, owner agreed). Placeholder:
   each lane is its own walkway of burnished gold plates (`walkway_color`, `plate_length` 3.6 m, a fine
   engine-turned finish) between polished gold rails, with a dark 5 cm joint where two walkways meet; the
   outer lanes run on to the facades over a cream marble kerb. The canal lies 5.5 m below (`canal_depth`,
   deeper than a fall that ends the run, so a fall never visibly lands): dark water flowing toward the
   player (`canal_flow`). A gap is a missing stretch of walkway with the City's and Gangland's orange
   edge: the same 18 cm lip on the deck at the collision edge, with a strip along the top of its face. On
   a lit gold floor a dim edge loses its weight, so both glow as brightly as the Marketplace's (its floor
   is lit too), and a soft orange halo runs along the far edge (`GoldenWalkways`); below it only deep shade
   (`gap_inside_color`) and the dark canal. The walkways are a deep, satin-burnished gold (`walkway_color`,
   `walkway_polish`), well below the cream of the zone's ceremonial cyborgs in value and saturation, so the
   cyborgs stand out on them at gameplay distance (a more polished deck paled toward champagne ahead of the
   runner, just where they stand). Right look?
3. **Motion cues on the still walkways** (GDD §5 proposal, approved for every still floor; over water, the
   equivalent). Placeholder, per 40 m: 55 motes of mist, 10 flakes of gold leaf and 12 speed streaks
   drifting toward the player (Motion group), with the plate seams streaming past underfoot and the canal
   flowing in the gaps. Right equivalent for a floor over water?
4. **The facades and the calm band** (GDD §5: opulent facades; in the Golden Zone, wall vents are the
   Screech's lairs and niches the Gilded Sentinels', GDD §9.5, §9.11). Placeholder: every building face is
   flush from the canal up past the wall-run band: polished granite to 0.9 m (`plinth_top`), then calm stone
   to 7 m (`band_top`: rusticated with flush pilasters, large polished ashlar on gold lines, or a blind
   arcade), where nothing opens, lights up, sticks out or looks like a vent or a niche, and only gold inlay
   lines mark the 2 m and 4 m wall-run heights (`wall_height_marks`); an entablature with a gold frieze to
   8.6 m (`frieze_top`). Above it: palaces (45%, white cladding, tall rounded gold-framed windows, balconies,
   statues on a ledge), galleries (20%, gilded frames hung out over the street) and towers of champagne
   mirror glass on gold fins under glazed crowns (34-72 m). Decoration never sits below `decor_min_height`
   (8 m). Right?
5. **The statues** (GDD §9.11). Placeholder: the statue kit (`scripts/world/skins/golden/golden_statue.gd`):
   a 2.6 m gilded guardian in faceted ceremonial armour (plated robe, breastplate, pauldrons, a crested
   helmet with a dark visor slit) holding a 2.95 m halberd, on a marble pedestal, in the same future as every
   zone rather than historical. Three decorative poses (guard, vigil, salute) and two swing poses for the
   live Sentinel (raise, strike, for task C4 to tune). Decorative statues stand on the palaces' ledge over
   the entablature, their feet 8.8 m up (`statue_min_height`; a wall run reaches about 5.8 m), every 5.2 m
   (`statue_spacing`) with 90% of the places filled (`statue_share`), turned a little toward the
   approaching runner. Right look, height and density?
6. **The cult's emblem, shown openly** (GDD §5). Placeholder: the owner's Convergent Triad (read from
   `data/world/cult_emblem_choice.tres`) in polished gold meeting at its red stone, embossed: on red
   banners with gold trims hung from gold poles on 60% of towers (`banner_share`; 3 m wide, the emblem
   2.4 m), in relief on the near ends of 70% of the towers that rise over the building before them
   (`relief_share`), on a 3 m crest at the middle of every golden bridge ceiling and on the keystone of the
   archways, on the sky bridges' faces, on red cloth in 70% of the galleries' gilded frames (the rest play
   the feed), and inlaid as medallions in the walkways (`medallion_share`: 15% of one slot per lane in
   every 40 m). It is drawn large because the kit fades any mark out below about 24 pixels on screen
   (`emblem_size`). How openly, where, and how often?
7. **The retuned gold** (GDD §5, §11: the gold is reflective metal, not neon). `CultEmblem.GOLD_COLOR` and
   `GOLD_ACCENT_COLOR` (`scripts/world/meshes/cult_emblem.gd`) were placeholders; the old gold
   (0.80, 0.64, 0.30) read as sign yellow once lit. Now: a paler, half-saturated gold (0.78, 0.66, 0.42)
   meeting at a deep ruby stone (0.52, 0.09, 0.10), the same gold the whole zone uses (`gold_color`). The
   ceremonial cyborg's medallion takes its red stone from these constants (its gold is the look's own).
   Approve?
8. **The cult's feed** (GDD §5 "Cyborg Viewing Devices"). Placeholder: the shared feed (`CultFeed`) in 30%
   of the galleries' gilded frames (`feed_share`) and on big screens hung out over the street from 35% of
   towers (`feed_hung_share`; at most 4.6 m wide and within 70% of the street's half width, bottoms 13-16 m
   up, facing the oncoming runner). A boss arena can set `feed_hung_share` to 0 to clear the air over the
   street. Right places and amounts?
9. **The ceilings** (GDD §5: undersides of golden bridges, golden archways and other decadent structures).
   Placeholder weights (Ceilings group): a golden bridge 4.0 (a gilded coffered underside, a marble face
   with the emblem's crest and a gold rail; over fewer lanes a suspended gallery on gold beams), a gallery of
   parabolic golden arches 3.0 (only across every lane), a hover-yacht of the elite 2.0 (a cream hull with a
   gold line and a deep red stripe, pale blue-white engines). Over a narrow street (3 lanes) the arches are
   flatter and the bridges' rails shorter, so nothing cuts through the statues, frames and banners on the
   walls. Right mix and forms?
10. **Waterfalls and fountains off the ceilings** (GDD §5: scenery only, sparse). Placeholder: on half the
    golden bridges (`water_share`), water pours off the bridge's face from a gold lip into a gilded trough on
    either side of the crest, all above the ceiling's underside, never over the floor or the walls' band; a
    3-lane street leaves no room beside the crest, so its bridges have none. Is this what the owner means,
    and sparse enough?
11. **Over the street** (GDD §5: the same future in the dominant shapes). Placeholder: sky bridges slung
    between towers 24-30 m up in 70% of 110 m stretches where towers tall enough stand on both sides
    (Overhead group), the emblem on their faces; hover-yachts as ceilings. Enough future?
12. **Red accents** (GDD §5: white and cream with red and gold accents). Besides the banners, the red
    cloth in the gilded frames and the yachts' stripe, half of the lit windows show red velvet drapes.
    Enough red, or too little?
13. **Hazards in the zone's dress** (the language stays the same everywhere). Fences keep the pink field,
    between marble-and-gold stanchions with pink emitters; signs are boutique boards (cream, midnight blue,
    black lacquer, ivory, with gold lettering) in the yellow/black frame. A crimson board was dropped: the
    boards glow a little, and a glowing red would read as a hazard colour. The edge bars and the OFF look of
    fences are proposals, as in the other zones (`scripts/world/skins/golden/golden_props.gd`). OK?
