# F2a, the Neon City's outro: open questions

The owner gave the story beats on October 8, 2026 (GDD §6, Cinematics). Everything below is staging I chose
to fill them in. The numbers live in `data/cinematics/city_outro_tuning.tres` (`CityOutroTuning`), and the
code is marked `DESIGN-TBD` in `scripts/cinematics/city_outro.gd` and `city_outro_set.gd`.

1. **Length** (GDD §1: 5–15 s). The owner's beats are many. Placeholder: 15.0 s, the top of the range
   (`duration`). The crash takes about 2 s, the stop and the look about 3 s, the roadblock about 3 s, the
   escape and leap about 2 s, and the landing in Gangland about 4.4 s. Should it run longer than 15 s, or
   should the Gangland intro's flyover (next, 9.5 s) be shortened or dropped after this outro, since the
   outro already lands the runner in Gangland?
2. **Where the roadblock stands** ("He looks to the left, and there we see a barricade"). Placeholder: the
   left wall opens onto a side street, built from the City's own truck roofs (laid across it) and lined
   with its building fronts. The roadblock stands at its mouth, a few metres ahead of where the runner
   stops. Is a side street what the owner pictured, or should the roadblock block the main street?
3. **The barricade's look.** Placeholder: low concrete blocks with navy and white rails, in the Enforcer
   Truck's police paint and never a hazard colour, with a cold-white floodlight at each end. The Barnacle
   Turrets stand in the gaps between the blocks like cannons. Should it look like Gangland's crate and
   container barricades instead?
4. **Which battle truck.** Placeholder: the Enforcer Truck (police-style, light bar, two cyborg gunners on
   its roof), because its model was already built to be shown on its own. The hover truck (Neon City 3's
   mini-boss) is the one the player has actually met by Zone 1's end. Which one should it be?
5. **Turrets and drone.** Placeholder: 3 turrets (`turrets`), in the mechanical City look, and the heli
   drone over the truck. The player meets neither in Zone 1 (the drone arrives in Gangland 3, the turret
   in the Marketplace), so the outro previews both. Is that intended?
6. **"Runs in the opposite direction".** Placeholder: away from the roadblock. The runner hops back to the
   right, startled, then sprints right and slightly ahead to an opening in the right wall, and leaps out
   over the drop to the road far below. The other reading is a U-turn back the way they came. Which did
   the owner mean?
7. **The explosion.** Placeholder: the roadblock fires a red volley (each cyborg and turret), which blows
   up the truck roof the runner just leapt from (the Enforcer Truck's blast, bigger). The camera is out
   over the drop, so the runner flies toward it with the fireball behind them. Should the explosion be
   something else, such as the battle truck firing or the Floating Head's wreck going up?
8. **The cut to Gangland.** Placeholder: the runner falls into the haze toward the road far below. The
   picture goes to black for half a second, then the runner drops into a Gangland street from about 7 m,
   lands, glances left and right, and runs off. The cut happens under black because building Gangland's
   street takes a few frames. Is a cut to black acceptable, or should the camera follow the fall all the
   way down? A continuous fall would need the City's road below to become Gangland's street, a bigger job.
9. **Runner animation.** The rig has no "stop and look" or "startled" animation. Placeholders: a head
   turn shared by chest, neck and head (a new `look` value on cinematic keys), and a small hop back
   (`startle_hop`, 0.35 m) that uses the jump pose. Should it have a proper startled pose?
10. **Music.** Placeholder: the City's track plays and fades out as the runner leaps, and Gangland's comes
    in with its intro. No music was made for cinematics (GDD §11). Should the outro have its own sting?
11. **The web demo.** The demo ends after Zone 1, and the outro belongs to Zone 1, so the demo plays it
    (Gangland's landing included) before the store-link screen. That makes it a teaser for Zone 2. Is
    that wanted, or should the demo go straight to the store links (the GDD's §10 wording could be read
    that way)?
