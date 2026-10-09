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
- **The screeches.** Placeholder: four of them (`sniffers`), the sewer screech's own body, sniffing round the Host;
  they look up as the runner comes walking down the street, raise their spines (to the level a screech has in play
  when it isn't attacking, never the full blazing bristle of its attack: `GanglandOutroSet.ALARMED`), and scuttle off
  into the gutters at the walls before the runner arrives (`look_up_at`, `scuttle_at`), so the runner's coming
  scares them away. How many, and is that the reason they leave?
- **The runner's walk.** Placeholder: the run cycle at a walking pace (`walk_speed` 1.8 m/s to the Host,
  `car_walk_speed` 2.1 m/s to the car; the humanoid rig has no walk cycle of its own), which reads as a brisk walk.
  Should the rig get a proper walk (a shared change, its own task)?
- **The key and the hand-off.** Placeholder: an ornate golden key (`key_length` 0.21 m: a faceted bow round a
  jewel, a shaft, two teeth), glowing faintly so it reads as gold in the street's dim red light. The Host trembles
  (`tremble`, `tremble_offering`), sits up a little and holds it out (`offer_at`); it glints (`glint_at`: a soft
  halo and a bell chime, `key_glint`); the runner leans in and takes it (`reach_at`), then looks at it
  (`admire_at`). Is the key's look right, and should anything be said or shown (a card)?
- **The unlock and getting in.** Placeholder: the runner points the key at the car as they walk up; it chirps and
  blinks its lights twice (`unlock_at`, `car_unlock`; one slow glow with Reduced flashing); the scissor door swings
  up (`door_up_at`, `car_door`); the runner steps in and sits (`get_in_at`), out of sight once the door is mostly
  down (`door_down_at`; the cabin behind it is dark). Should the runner be seen sitting in the car as it drives off
  (see-through glass, a costlier material)?
- **The drive-off.** Placeholder: lights and engine on (`lights_at`, `car_start`: the starter, a blip, idling), a fine
  idle shudder, then it launches (`launch_at`, `car_drive`: the tyres biting, two gears, fading into the distance)
  with a squat on its rear wheels and a moment of wheelspin, accelerating at 13 m/s² (`acceleration`) straight down
  the street, seen from the road behind it, 0.16 m up (`road_cam`; the owner: "the camera should be at road
  level"). In the 3.1 s before it ends it reaches about 40 m/s and about 60 m away (its `top_speed` of 46 m/s is a
  cap it doesn't reach), a pair of taillights far down the street as it fades to black. No tyre smoke or exhaust
  flames. Faster or longer, so it's gone into the haze?
- **The car's own glow.** Placeholder: red taillights and red halos round them, cyan running lights and glow under
  it, and the gold key's glow. GDD §5 keeps glowing hazard colours for hazards; nothing in a cinematic is one, but
  red is the enemy-attack and weak-point colour. Keep red taillights (as any car has), or another colour?
- **Sounds.** Six new ones (`tools/asset_gen/sfx_bank_cinematics.gd`): `screech_sniff`, `key_glint`, `car_unlock`,
  `car_door`, `car_start`, `car_drive`; and from the fight, `swarm_scatter` as the screeches flee and `host_short`
  at 1.1 s (`spark_at`), a last crackle from the Host's dead implants (heard, not shown). Keep them?
- **Music.** Placeholder: the fight's music fades out as it opens (`music_fade`; a quiet aftermath) and no music
  plays; the Marketplace's intro brings its own. No cinematic music is generated (GDD §11). Should a track play
  over the drive-off?
- **The shots.** Placeholder (`rubble_cam`, `follow_cam`, `handoff_cam`, `reveal_cam`, `road_cam` and their looks
  and fields of view): low beside the Host, looking back up the street at the runner coming; over the runner's
  shoulder as they walk up; low in front of the Host for the hand-off; the car's reveal low off its front corner,
  gliding round to its side; then the road-level shot behind it. Should any beat get a different angle?
