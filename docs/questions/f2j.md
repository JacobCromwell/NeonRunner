# Questions from task F2j (the Casino's intro; the owner's beats and reference image, October 18, 2026)

The owner's beats (GDD §6, Cinematics, "Casino intro") left these details open. Each has a placeholder, marked
DESIGN-TBD in `scripts/cinematics/casino_intro/` and its numbers in `data/cinematics/casino_intro_tuning.tres`
(`CasinoIntroTuning`), built so it's cheap to change.

1. **The casino is the Brass Lotus.** The reference image names it, and it is one of the zone's two named casinos (GDD §5,
   task K3), so the intro's casino carries its name: "THE BRASS LOTUS" on a board on the marquee and stacked down a blade
   sign at the far end of the front, in the street's own lettering. Is it the casino the Chairman owns (the boss intro's
   hall would then be inside it)?

2. **Its front, simplified from the reference.** Placeholder (`CasinoIntroLotus`): dark riveted iron banded in brass,
   rows of tall arched windows lit warm, two fluted brass columns either side of the doors, the boss intro's golden doors
   standing open on a warm-lit vestibule, a marquee studded with warm bulbs, and over it an art-deco crest of stepped neon
   bars round a gold lotus. The reference's pink neon is drawn in the Casino's violet (pink is a hazard colour, GDD §5);
   its jackpot screens, steam, hanging plants and street crowd are left out (two planters of dark greenery stand beside
   the steps instead). The front stands in an opening of the left wall 26 m long, 10 m back from the street.

3. **The grand staircase** (the owner's word; the reference has none). Placeholder: 20 steps, 10.4 m wide, rising 2.6 m
   over 4.8 m (against the runner's 1.28 m), a burgundy carpet up the middle held by brass rods, stepped stone cheek walls
   with brass balusters and handrails, a brass lamp post at each corner, and a 3 m terrace at the top.

4. **Who greets the Chairman.** Placeholder: two people from the boss intro's patrons, the well-to-do businessman (the
   "Elite High-Roller") and then the "Lady Luck" gambler, standing either side of him at the top of the steps; he shakes
   each one's hand in turn, then turns and walks in. The two women stand a step behind him while he greets them and walk
   in beside him.

5. **Two cyborg guards** in the Casino's look stand either side of the doors (not in the beats; the boss intro has two
   of his guards), turning their heads to watch him go in. Keep them?

6. **The screech stays in the car.** It sat on the passenger seat in Gangland's outro and is at the bar in the boss
   intro; here it looks round at the runner as they get out, nods to them with a chirp, and stays in its seat.

7. **The staging and timing.** Placeholder: 25.8 s in seven shots: low behind the car down the covered street (3 s);
   the casino's front from across the street as the car comes past the camera and pulls up beside the steps (4.3 s); low
   off the car's front corner as its scissor door swings up and the runner gets out and turns to the steps (4.1 s); low
   behind the runner, tilting up the staircase (2.4 s); up the steps from beside the runner's head, close on the Chairman
   shaking hands (3.6 s); wider, after him as he goes in with the women (3.6 s); back to the runner from a few steps up,
   looking up after him, the title card over them (4.8 s, ending on black). The zone's music fades in from the start.

8. **Its sounds.** Two new ones (`tools/asset_gen/sfx_bank_casino_intro.gd`) on the Gangland car's engine: `car_cruise`
   (the purr down the street) and `car_arrive` (off the throttle, a blip down a gear, braking, idling, switched off). The
   rest are the game's: the car's door, the screech's chirp, and the boss intro's casino bustle at the front.
