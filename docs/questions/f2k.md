# Questions from task F2k (the Terminal's intro; the owner's beats, October 21, 2026)

The owner's beats (GDD §6, Cinematics, "Terminal intro") left these details open. Each has a placeholder, marked
DESIGN-TBD in `scripts/cinematics/terminal_intro/` and its numbers in `data/cinematics/terminal_intro_tuning.tres`
(`TerminalIntroTuning`), built so it's cheap to change.

1. **The Grand Terminal Station is a surface building here.** The Terminal zone is "an abandoned subway under the city" (GDD §5,
   Zone 8), and the beats show its outside in the Dead Zone's wasteland. Placeholder: a large old station standing back from the
   street behind a forecourt (head house with a great arched window over the entrance and two wings, 110 m of front), its hall
   running straight into the subway the first level is on: the way in leads, one cut later, onto the track bed. Is the station
   above the subway (stairs down, a concourse) or is the subway simply its hall? Does the Dead Zone's street run past it (as the
   intro has it: the front in an opening of the street's left wall, the plaza its pavement) or is it a separate place?

2. **The station's design** (the reference image shows only the inside). Placeholder (`TerminalIntroStation`): weathered stone in
   the Dead Zone's greys, pilasters, string courses and a heavy cornice, tall arched windows in two rows on the wings (a few
   lit), a broad band over the great window where the sign ran, the right wing broken down toward its end with a hanging floor
   slab and rebar; soot streaks, fallen masonry on the forecourt. 34 m wide and 23 m tall at the head house, the doorway 6.8 m
   by 4.4 m.

3. **How "GRAND" is shown fallen.** Both of the owner's options: a dirty ghost of each letter on the sign's band (the cleaner
   stone it covered) with the bare mounting bolts, and the five letters themselves in the rubble below, sooty and unlit (lying
   flat, one leaning on the front, one half buried). Not shown broken in two.

4. **"TERMINAL" drooping and sparsely lit.** Placeholder: each of the eight letters hangs on its mount tipped by its own angle
   (-24° to +16° in the plane of the front), slipped down 0 to 0.85 m and its foot swung out up to 18°, the last (the L) nearly
   hanging by a corner; four are still lit (E, M, N, L: `lit_letters`). The light is the Terminal's work-lamp amber (the looser
   colour rule of the later zones, the owner, October 20, 2026), dim, a little over the bloom threshold only in a spark's flash.
   They flicker (dimmed for whole 0.3 s cells now and then, never faster) and each sparks about every 3.4 s: nine soft sparks
   flung out and down, falling, with a flash of the letter. The sparks are warm white, never pink (pink is the electric fences').
   With Reduced flashing: no flicker (the lit letters breathe slowly), a third of the bursts, half the sparks, slower and dimmer.

5. **Light out of the station.** Placeholder: the great window's glass glows amber, brighter low in it, with panes broken out; the
   crack of the doorway is a bright warm slit; both throw shafts down and out over the forecourt (additive cards of the skin's
   glow material) and a pool of light on the pavement, with halos, a few lit windows in the wings, and real warm lights for the
   runner. The shafts breathe slowly (steady with Reduced flashing).

6. **The wasteland.** Placeholder: the Dead Zone's own props, drawn by its skin as in a level (doodad picture cards: a broken
   column, a rubble heap, the burned-out bus), eight of them on the plaza and the street, three columns of its smoke; its sky,
   haze and greys. Which props and where is open.

7. **Surveying and the first shots.** Placeholder: 2.8 s on the runner's face (a close shot from in front and a little to their
   left, the gold eyepiece's side), their head turning right, then left toward the station and up at it; then 3.4 s of the camera
   sweeping round them by their right, over the wasteland, to behind them and the station, and a cut to the station's front from
   across the street, craning up to the sign (4.4 s). The runner stands at the plaza's edge, 11 m from the front, in the
   street's left lane area.

8. **The route board.** Placeholder (`TerminalIntroSign`): a dark enamel board 1.5 m by 1.15 m in a rusted frame, hung at the
   height the runner's hand reaches (the wipe pose was measured on the real rig and the board placed there), to the right of the
   doorway, under a film of grime; "ROUTES" over a line down it with a dot at each stop. The stops, my choice, plausible and
   neutral: GRAND TERMINAL, CANAL STREET, OLD MARKET, CINDER ROW, HARBOUR GATE, dull and faded, and THE PALACE last and bigger,
   in gold, with a gold ring for its dot, a dashed gold line to it, an underline and a soft gold glow. Should the other stops
   be the earlier zones' places? Is the Palace's gold the same gold as in the Golden Zone (GDD §5)?

9. **The walk and the wipe.** Placeholder: they walk 2.7 m/s (a quick, natural walk for a 1.28 m runner) from the plaza round the
   heap's foot and along the front to the board (6.6 s, starting as the camera cuts to the station), arriving as the wipe starts;
   they wipe it in three strokes down the board with their right hand (2.4 s), the grime clearing along the hand's own trail with
   a puff of dust; the cut to the close-up comes as the arm comes down, the whole board in view and a slow push in to the Palace
   (2.5 s). They step back out of the shot at the cut.

10. **Making up their mind.** Placeholder: 2.3 s close on them from beside the board, the street behind them: they look at the
    board, nod once and turn to the entrance (a nod is the head dipping 14° and rising).

11. **The entrance and the climb.** Placeholder: the doorway filled with a heap of rubble up to 0.85 m under the lintel (a
    ragged crack of stone teeth, light through it), spilling 6.5 m out onto the forecourt; a 1.4 s shot of them at its foot looking
    up at the crack; they scramble up its slope on hands and feet (`scramble`, 2.8 s) and squeeze through the crack head first,
    lying down as they go (`squeeze`, 1.6 s). The poses (`CinePoses`) are hand-set placeholders like the others.

12. **Inside.** Placeholder (`TerminalIntroEntry`): after a 0.4 s dip to black, the Terminal's own stage (the zone's skin, from its
    data): a section of the station's wall standing at the left platform's back, in the Terminal's old tile and ashlar, with the
    doorway and the back of the heap (a short steep slope into the hall) under the same ragged crack, through which the dusk's cold
    grey light comes as a beam across the platform (cold against the amber lamps). They crawl out over the crest, jump (a free fall
    of 0.84 s, 3.5 m), land on the track bed (the landing's thud), straighten up and turn to face along the line, and the camera,
    round behind them, looks down it: the tracks running off, the platforms, arches and lamps the skin draws. The zone's title card
    comes up over it and holds into black (about 3 s). The wall is a prop of this shot: the skin has no wall at the street's edge.

13. **Timing.** Placeholder: 32.4 s (the owner asked for about 25 to 32) in nineteen shots: the face (2.8 s), the sweep (3.4 s),
    the station from across the street (4.4 s), following the runner across the forecourt (3.0 s), at the board (2.6 s), the
    board close up (2.5 s), the runner deciding (2.3 s), the entrance (1.4 s), the climb (4.5 s), inside (5 s). The zone's music
    fades in over 4 s from the start.

14. **Its sounds.** Seven new ones (`tools/asset_gen/sfx_bank_terminal_intro.gd`): `waste_wind`, `sign_buzz`, `sign_zap` (a
    letter sparking), `grime_wipe`, `rubble_scramble`, `landing_thud` and `station_hum`; the game's `rubble_shift` for the squeeze
    and the crawl out. None is a warning.
