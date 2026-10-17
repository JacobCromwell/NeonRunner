# Questions from task F2i (the Casino's boss intro; the owner's beats, October 17, 2026)

The owner's beats (GDD §10, The House, "Intro cinematic") and the reference image of casino patrons
(`docs/art/reference/casino_patrons.webp`) left these details open. Each has a placeholder, marked DESIGN-TBD in
`scripts/cinematics/casino_boss_intro/`, its numbers in `data/cinematics/casino_boss_intro_tuning.tres`
(`CasinoBossIntroTuning`), built so it's cheap to change.

1. **The hall.** Placeholder (`CasinoHall`): a closed hall 34 m wide, 40 m deep and 16 m high (the runner is 1.28 m tall;
   The House needs the height), in the Casino's look: plum walls over a dark wood wainscot with brass rails, iron
   pillars with brass bands and warm sconces, a coffered iron ceiling, three brass chandeliers, a burgundy carpet woven
   with a gold lattice. The cinematic plays wholly inside it (the street is hidden). Is the casino's interior meant to
   look like this, or more like the zone's street (iron, glass vault, neon signs)?

2. **The tables and the holographic games.** Placeholder: the roulette table (its wheel spinning, the ball dropping
   into a pocket), two blackjack tables, a poker table and a dice table, their cards and chip stacks, banks of slot
   machines along the left wall and near the back, and the bar along the right wall. Three holographic games, in the
   Casino's sign colours (violet, blue, cold and warm white; never a hazard's): a **dice tower** (three big dice
   tumbling in a column of light), an **orbit wheel** (eight glowing cards wheeling over a table) and a **star sphere**
   (a turning lattice globe, tokens orbiting it). Are these the kind of games the owner had in mind?

3. **The patrons' looks** (`CasinoPeople`, simplified from the reference): the woman in red (bun and gold circlet,
   crimson gown with gold trim and red-and-gold pauldrons, gold cybernetic forearms, a blue-grey cocktail); the
   "Lady Luck" gambler (low bun, dark eyepiece on her left eye, dusty rose scarf, bronze bodice, ragged brown and tan
   skirt, bronze bracers and greaves); the grimy patron (messy hair, stubble, a dark-lensed cyber eye, olive bomber,
   cargo trousers, a dark wrist gadget); the high-roller (slicked hair, burgundy suit with gold lapels, high black
   collar). Nothing on any of them glows: the reference's cyan eyepieces and wrist screens would read as a hazard's
   colour. The dealers, croupier and bartender (white shirt, black waistcoat, burgundy bow tie) are not in the reference.
   The women share one fair skin tone.

4. **The two women beside the Chairman.** Placeholder: the woman in red's build and gown, one in a black gown with long
   straight black hair, the other in a red gown with blonde hair in a high ponytail; no glass. They walk at his sides
   and go through the golden door with him.

5. **The Chairman on the rig** (`CasinoPeople.Look.CHAIRMAN`, his new look): the tallest of them (1.42 m), the long black
   coat (its skirt swinging), tall collar, gunmetal shoulder plates, vest and throat brace, the brand's blue lights at a
   low glow (chest, brace, pauldrons, bracers, temple implant), a black cane with a brass head in his left hand.

6. **The crowd.** Placeholder (`CasinoCrowd`): about sixty people at the tables, round the holograms, at the slots,
   along the bar and standing about in twos and threes with drinks, using the reference's looks, some repainted (navy
   or charcoal suits, a brown jacket, sapphire, violet and champagne gowns) so the heroes stay the only ones in their
   colours. They breathe and sway; the roulette's onlookers cheer with its players; when the wall trembles they turn
   to it and when it bursts they draw back a little. Nobody flees or screams. Should the crowd scatter when The House
   breaks in?

7. **The staging and timing.** Placeholder: 34.8 s. Low at the roulette table, panning right along the layout to the
   wheel (0-4.5 s; the ball drops at 3.0 s, settles at 3.8 s, cheers at 3.9 s); tilting up and back to the four players
   cheering (the woman in red raising her glass, the businessman clapping) (4.5-8.2 s); the runner leaning back on the
   bar, hands on the counter's edge, the screech sitting on the counter beside them, looking out (8.2-11 s); telephoto
   across the hall from behind the counter at the Chairman and the women walking, his guards behind (11-14 s); close on
   the runner as they push off the bar (14-15.4 s); following them through the crowd (15.4-18 s); the Chairman from ahead
   as he looks back over his shoulder and flicks his hand (18-19.5 s); wide on the guards' rush and the two dives
   (19.5-22.9 s); behind the runner as the Chairman and the women go through the golden door and it bangs shut
   (22.9-25.9 s); pulling back to the whole wall as it trembles (25.9-28.2 s); the wall bursts (28.3 s), The House's
   lights come on (29.3 s), held to the end; black, and the fight. No title card.

8. **The runner.** Placeholder: they jog through the crowd (about 2.5-3.5 m/s); each dive is a low sideways leap (the
   game's jump pose, 0.55 s, 1.4 m to the side), right past the first guard, left past the second; then on toward the
   door, stopping short of it. The screech stays sitting on the bar (it isn't seen again). Should it follow the runner?

9. **The guards.** Placeholder: two of the Casino's cyborgs walking behind the Chairman. On his flick they shout (a
   gruff mumble) and rush the runner, each lunging with its arms out through where the runner was and stumbling on as
   the runner dives clear; they turn after the runner and then to the wall. They never shoot (the owner's word was
   "block").

10. **The golden door.** Placeholder (`CasinoGoldenDoor`): tall double doors of polished gold with raised panels, sunburst
    bosses and long brass handles, in a gilded surround with a sunburst over it, brass lamps either side, velvet ropes
    marking the way to it. They swing open by themselves as he nears and bang shut about a second after he is through.

11. **The wall and the reveal.** Placeholder (`CasinoWallBreak`): the stretch of back wall to the door's left, a hole
    cut to fit the fight's own machine with a metre to spare. It shivers more and more for 2.8 s as cracks spread, grit
    trickles and dust puffs at its foot; then it bursts from the middle outward, its blocks tumbling into the hall and
    lying on a heap of rubble, a dust cloud billowing and settling. The House stands in the hole, dark until its lights
    blaze on a second later, its reels spinning up and stopping on a cherry, a BAR and a lightning bolt (its three
    attacks), never the jackpot's sevens.

12. **The sounds** (`tools/asset_gen/sfx_bank_casino_boss_intro.gd`, placeholders): the floor's bustle under it all
    (murmur, chips, a slot's chime), the roulette ball's roll and drop, the players' cheer, the guards' shout, the door's
    slam, the wall's rumble and collapse; The House's reel spin as it powers on. The zone's (the fight's) music plays
    under it from the start.
