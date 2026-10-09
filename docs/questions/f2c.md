# F2c, Gangland's outro: open questions

The owner's beats (October 9, 2026; GDD §6, Cinematics) are built as given. These are the choices made to fill
them in. Each is a placeholder in data (`data/cinematics/gangland_outro_tuning.tres`, `GanglandOutroTuning`) or in
code marked `DESIGN-TBD` (`scripts/cinematics/gangland_outro/`).

- **Its length** (GDD §1 and §6: "5–15 second cinematics"). Placeholder: 21.2 s (about 12 s for the rubble and
  the key, 9 s for the car), to give each beat time: the screeches' moment, the walk over, the trembling hand-off,
  the unlock and getting in, the drive into the distance. Every time is data, so it can be tightened; at 15 s the
  hand-off and the getting in feel rushed. Is 21 s acceptable here?
- **The sky and look.** Placeholder: both scenes pick up where the fight ended, in the arena's look under Gangland
  3's blood-red sky (`CineStageDef.after_fight`), where the zones' other outros keep the zone's own sky. Or should
  the outro (or only the car scene) have Gangland's own night sky?
- **Where the car scene is** ("cut to a new scene"). Placeholder: another stretch of Gangland's street, the car
  parked in it, driving off down the street toward the Marketplace. Alternatives: a side street or garage, or the
  edge of the Marketplace.
- **The car's look** ("sleek, flashy ... angular, almost triangular ... shiny, like a Lambo"). Placeholder
  (`SportsCarModel`; size, paint and accent in data): a faceted wedge 4.3 m long, 1.95 m wide and 1.0 m tall (a
  little big for the runner, who is about 1.3 m tall, so they fit in it), a blade of a nose, a raked windshield,
  flared fenders, a dark side intake, a rear wing, a scissor door on the driver's (left) side; ultraviolet-purple
  paint with cyan running lights, wheel hubs and glow underneath, white headlights and red taillights. Purple and
  cyan stand clear of Gangland's browns and reds; cyan is also the anti-grav pads' colour, though nothing in a
  cinematic is a hazard or a pad. Another colour (a classic yellow or orange, or gold to match the key)?
- **Who the car belongs to, and what the key opens** (narrative, GDD §1). Placeholder: the Host's key opens the
  car; nothing says whose it was. Should anything (a card, a later beat) say?
- **The Host** ("the swarm host cyborg"). Placeholder: the fight's person (`SwarmHostPerson`), freed, lying back
  against a heap of rubble with their implants dimmed (shorted out at the defeat), 1.45 m tall (the fight holds
  them up at 1.75 m inside the swarm's bulk). They stay in the rubble; the outro shows nothing of what becomes
  of them.
- **The screeches.** Placeholder: four of them, the sewer screech's own body, sniffing round the Host; they look
  up as the runner comes walking down the street, bristle, and scuttle off into the gutters at the walls before the
  runner arrives (so the runner's coming scares them away). How many?
- **The runner's walk.** Placeholder: the run cycle at a walking pace (1.8 m/s; the humanoid rig has no walk
  cycle of its own), which reads as a brisk walk. Should the rig get a proper walk (a shared change)?
- **The key and the hand-off.** Placeholder: an ornate golden key (a faceted bow round a jewel, a shaft, two
  teeth), glowing faintly so it reads as gold in the street's dim red light. The Host trembles, harder as they
  strain, sits up a little and holds it out; it glints (a soft halo and a bell chime, `key_glint`); the runner leans
  in and takes it, then looks at it.
- **The unlock and getting in.** Placeholder: the runner points the key at the car as they walk up; it chirps and
  blinks its lights twice (`car_unlock`; one slow glow with Reduced flashing); the scissor door swings up
  (`car_door`); the runner steps in and sits, out of sight once the door is half down (the cabin is dark).
- **The drive-off.** Placeholder: lights and engine on (`car_start`: the starter, a blip, idling; then
  `car_drive`: the launch through two gears, fading into the distance), a fine idle shudder, then it launches with a squat and a moment of wheelspin,
  accelerating at 13 m/s² to 46 m/s straight down the street, seen from the road behind it, 0.16 m up (the owner:
  "the camera should be at road level"), until it's a pair of taillights in the haze; fade to black. No tyre
  smoke or exhaust flames.
- **Music.** Placeholder: the fight's music fades out as it opens (a quiet aftermath) and no music plays; the
  Marketplace's intro brings its own. No cinematic music is generated (GDD §11). Should a track play over the
  drive-off?
- **The shots.** Placeholder: low beside the Host, looking back up the street at the runner coming; over the
  runner's shoulder as they walk up; low in front of the Host for the hand-off; the car's reveal low off its front
  corner, gliding round to its side; then the road-level shot behind it.
