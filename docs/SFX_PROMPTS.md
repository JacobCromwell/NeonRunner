# NeonRunner — Sound Effect Prompts (ElevenLabs)

Prompts for rebuilding every sound in `assets/sfx/` with a text-to-sound-effect model. They describe how each sound
**should** feel (punchy, weighty, a little over the top), not how the current synthesized files sound. Each entry is
`file name` · target length · prompt. Use the file name for the downloaded file so it drops straight into `assets/sfx/`.

## How to use

- **Style suffix.** Append this to every prompt unless noted: *"Dry, no reverb tail, no music, no speech, tight transient, loud and punchy, game sound effect, retro-futuristic cyberpunk."* For sounds that should sit in a space (bosses, explosions), drop "dry" and let the tail ring.
- **Duration.** Set the duration field to the length shown (ElevenLabs allows 0.5–22 s). Warning sounds must be at least as long as the in-game warning, so they are listed with their real lengths; if the game's warning is tunable, generate a little long and trim.
- **Prompt influence.** High (0.7–0.9) for short one-shots so they stay exact; around 0.5 for long ambient or boss sounds so the model can embellish.
- **Generate 3–4 takes** of anything that repeats a lot (laser, enemy hit, credits, UI) and pick the cleanest; trim silence at the head so the transient lands on frame 0.
- **Voices.** Sound models can't produce readable speech. Every "voice" below is non-verbal (growls, shrieks, garbled loudhailer noise). That fits the game: the propaganda is meant to be unintelligible.
- **Fairness reminder (CLAUDE.md).** Every warning sound must be unmistakably a *warning* (rising, building, alarm-like) and must differ from the hit it announces. Hazards keep the same sonic language in every zone.
- **Loudness.** Aim for consistent perceived loudness; the player's own actions and deadly hits are loudest, UI and ambience quietest.

Total: 243 sounds.

---

## 1. Player movement

- `jump` · 0.4 s — A springy, snappy upward launch: a tight rubber-and-servo "boing" with a bright rising synth chirp and a small air whoosh. Cheeky, energetic, instantly satisfying.
- `land` · 0.4 s — A heavy boot-and-metal slam onto steel: a deep punchy kick-drum thud, a short metallic clank, and a puff of grit. Weighty and tight, no ringing tail.
- `slide` · 0.8 s — A long screeching metal grind with a shower of sparks: harsh scraping steel on concrete, rising then falling in pitch, crackling and hot.
- `wall_enter` · 0.5 s — A fast guitar-pick scrape sweeping up a distorted string, then a sticky magnetic clamp as boots lock onto a wall. Edgy and rock-and-roll.
- `wall_jump` · 0.5 s — A single crunchy distorted power-chord stab with a hard kick punch underneath and a sharp whoosh. Explosive and rebellious.
- `wall_blocked` · 0.5 s — A dull, heavy metallic clank: a body bouncing off a steel sign. Flat thud, short inharmonic ring, clearly a "no".
- `ramp` · 1.2 s — A V-twin motorbike throttle blip launching off a ramp: aggressive uneven engine roar, tyres leaving the ground, a heavy whoosh into the air.
- `pad` · 0.8 s — An anti-gravity boost pad: a deep sub thump, then a bright rising electric sweep with a whoosh, as if gravity switches off. Big, fizzy, uplifting.
- `dash` · 0.7 s — A juggernaut charge: a huge kick-drum punch, a roaring low rumble and a fast heavy whoosh, like a freight train shoulder-charging. Pure force.
- `grapple` · 0.9 s — A grappling hook: a whip-crack launch with chain rattling out fast, a heavy metal clunk as it bites, then the chain snapping taut with a twang. Mechanical and muscular.
- `slow_time_on` · 1.2 s — Time slowing: a tape-stop slide down an octave on a warbling chord, wobble slowing to a crawl, over a deep sub whoom. Dreamy and weighty.
- `slow_time_off` · 0.8 s — Time resuming: the tape spooling back up to pitch with a rising whoosh and a crisp snap back to full speed.
- `dash_ready` · 0.5 s — A crisp double mechanical reload clack followed by a bright chime. Satisfying "locked and loaded".
- `dash_wall_smash` · 2.0 s — A building front exploding as a runner bursts through: a huge concrete crack, a deep sub boom, a roar of crumbling masonry, then heavy chunks thudding down, last ones sparse. Heavy but not a fireball.
- `doodad_push` · 0.4 s — A dull, heavy shoulder-barge into something solid: a low padded thud, no ring, no pain.
- `doodad_smash` · 1.0 s — A dash smashing through scenery: a sharp crack, a heavy thud, crumbling grit and a few small pieces clattering after. Crunchy and gratifying.
- `edge_grab` · 0.6 s — A gloved hand slapping onto broken concrete, a tight grunt-free grip, grit trickling into a hole below.
- `hull_end` · 1.5 s — A vehicle powering down in agony: a falling whine, sputtering stalls, electric fizzle, then a final low clunk. Dramatic, final.
- `splash` · 1.2 s — A big body hitting pool water: a bright burst of spray, a deep round "bloop" as it closes over, then a handful of bubbles. Soft-edged, no crunch.

## 2. Damage, armor, death

- `armor_hit` · 0.5 s — One huge plate-metal clang as armor takes a hit and holds: ringing steel, a thud underneath, a spark of energy. Defiant.
- `armor_break` · 1.0 s — Armor plates shattering off the body: a crunchy impact, scattered metallic clanks, rattling debris skidding away. Dramatic loss.
- `armor_back` · 0.8 s — Armor plates sliding home and locking: soft hydraulic slide, a series of satisfying latches, and a calm rising chime.
- `shield_break` · 1.0 s — An energy bubble shattering: glassy electric shards, a falling zap and a power-down. Bright, then gone.
- `emp` · 1.8 s — A deep electric "whomp" pressure wave, a falling zap, a crackle of dying electronics rolling outward. Heavy, with a sub-bass thump.
- `died` · 2.0 s — A guitar dive-bomb: a distorted power chord bent down two octaves, a kick drum, a cymbal crash and a final low rumble. Fatal and a little theatrical.
- `revive` · 1.8 s — A second chance: a reversed cymbal swell into a rising brass arpeggio and a bright ringing chord. Triumphant gasp of life.
- `robbed` · 1.0 s — A thief's snatch: a fast upward grab swoosh, then a bag of coins jangling away and a sad descending blip.
- `fence_warning` · 1.2 s — An electric fence about to switch on: a crunchy crackle swelling louder with rising pitch, ending just before the zap. Menacing.
- `stomp` · 0.6 s — A heavy boot crushing a robot: a kick-drum thud, crunching metal, and a squelching robotic squeal that drops away. Brutal and funny.

## 3. Weapons

- `laser_fire` · 0.25 s — A clean, bright sci-fi "pew" that drops fast in pitch. Short and crisp since it repeats; punchy bass click at the front.
- `missile_fire` · 0.9 s — A heavy thump launch, an ignition whoosh and a sizzling rocket trail flying off. Weighty.
- `missile_explode` · 1.2 s — A mid-sized explosion: sharp crack, round boom, a little debris. Satisfying, smaller than a truck.
- `enemy_hit` · 0.2 s — A tight metallic tick with a crunchy impact. Very short and punchy; must feel good repeated.
- `enemy_death` · 0.7 s — A robot dying: a glitchy falling electronic squeal, a pop and a fizzle with a tiny spark.

## 4. Pickups, credits, scoring

- `pickup` · 0.6 s — A protective item snapping on: a quick rising swoop, a mechanical latch and a bright shimmer. Confident "powered up".
- `pickup_appear` · 0.8 s — A soft reversed swell into a delicate pair of high bells. Inviting, magical.
- `credit_1` · 0.15 s — A single bright coin blip, crisp and high.
- `credit_5` · 0.25 s — Two quick rising coin notes, a perfect fourth apart.
- `credit_25` · 0.4 s — Three rising coin notes ending in a small bell.
- `credit_100` · 0.9 s — A big jackpot-coin run to a high bell chord, a low thump and a sparkling tail. Rewarding and chunky.
- `star` · 0.7 s — A star popping onto the results screen: a fast upward chirp, a bell strike and a sparkle.
- `bonus` · 1.0 s — A short brassy fanfare, three rising notes with the last held with vibrato, and a sparkle.
- `jackpot` · 2.5 s — Slot-machine jackpot: wailing siren, a cascade of coins and a bell fanfare. Over the top.
- `key_glint` · 1.2 s — A bright three-note bell arpeggio rising into a shimmering high glint. Precious, magical.

## 5. UI

- `ui_move` · 0.1 s — A tiny soft electronic tick. Barely there but crisp.
- `ui_select` · 0.3 s — Two hollow rising notes, bright and decisive.
- `ui_back` · 0.3 s — Two softer, rounder falling notes: the confirm sound undone.
- `ui_buy` · 1.0 s — "Ka-ching" metal-style: a coin run up to a ringing bell over a palm-muted guitar chug. Satisfying purchase.
- `ui_error` · 0.4 s — A harsh double buzz on a dissonant interval. Unmistakably "no".
- `ui_equip` · 0.4 s — A mechanical latch, click-clack, and a small blip. Solid and tactile.
- `ui_unlock` · 1.5 s — A rising major arpeggio on brass into a big ringing power chord. A moment of triumph.
- `countdown` · 0.4 s — A firm square-wave beep with a thump for weight.
- `go` · 1.0 s — The countdown beep an octave higher and held, over a ringing power chord, a kick drum and a crash. Explosive start.

## 6. Level-complete stingers (guitar riffs, 2–4 s each)

Each is a short palm-muted guitar phrase: chug, chug, third, then a ringing note with a crash cymbal and a kick on every hit. Generate in a tight 2–3 s window.

- `level_complete` · 3.0 s — The City: heavy metal in E minor at a fast tempo, chug-chug-chug then a ringing high note and a crash. Triumphant, aggressive.
- `level_complete_gangland` · 3.0 s — Gangland: slow, menacing, heavy D phrygian chugs with a booming kick, ending on a long ringing note. Street swagger.
- `level_complete_marketplace` · 3.0 s — Marketplace: bouncy, upbeat major-key guitar riff with a brassy horn crowning the last note. Playful.
- `level_complete_corporate` · 3.0 s — Corporate: tight, tuned-down, mechanical sixteenth-note chugs locked to a kick, ending on a cold ringing note. Efficient and cold.
- `level_complete_dead_zone` · 3.5 s — Dead Zone: slow, dark, low chugs with a final ringing note left to die away. Eerie, defiant.
- `level_complete_golden` · 3.0 s — Golden Zone: harmonic-minor riff, regal and grand, crowned by a golden fanfare shimmer. Epic.

## 7. Environment and hazards

- `ceiling_lower` · 2.0 s — A massive metal ceiling lowering overhead: engine drone dropping in pitch, hydraulic hiss, a final heavy settle. Oppressive.
- `crater_smoulder` · 2.4 s — A smoking crater: a low rumble swelling in and dying back, embers ticking and popping, a soft hiss. Ambient, loopable.
- `rubble_shift` · 0.7 s — A body shifting on rubble: gritty scraping and a couple of concrete chunks knocking together.
- `searchlight_on` · 1.5 s — A huge arc lamp switching on: heavy relay clunk, then a rising electric hum. Ominous.
- `searchlight_lock` · 1.2 s — A gimbal clacking into place, a rising targeting tone. Clear warning.
- `tower_crack` · 1.2 s — Concrete cracking under strain: a sharp crack and a long groaning creak. Danger.
- `tower_crash` · 3.0 s — A tower slamming onto a ship: a huge crash, crumpling metal, a long rattle of debris. Cinematic.
- `ramp_slam` · 1.5 s — A heavy broken slab slamming into a lane: a stone thud, a rumble, dust and debris.
- `pads_light` · 1.5 s — Anti-grav pads lighting up in every lane: a rising electric hum cascading in sync, bright and inviting.
- `wall_marks_light` · 1.2 s — Wall-jump marks lighting up along both walls: a fast electric zip racing along each wall and a soft chime.
- `bomb_whistle` · 1.5 s — A classic falling-bomb whistle, high to low, accelerating. Clear warning.
- `bomb_blast` · 1.5 s — A bomb hitting truck roofs: a crack, a deep boom and clattering debris.

## 8. Vehicles and trucks

- `truck_bang` · 1.0 s — Three heavy bangs on a wall from inside: a vehicle hammering a building. Escalating warning.
- `truck_burst` · 1.5 s — A hover truck bursting through a wall: explosive blast, concrete crumbling, twisting metal.
- `truck_cannon_charge` · 1.5 s — A heavy shell clunks in, then a deep hum rises in pitch and intensity. Dangerous.
- `truck_cannon` · 1.2 s — A huge low boom with a metallic ring and a sub thump. Enormous.
- `truck_rev` · 1.2 s — A hard engine climb to the redline before a lurch forward. Aggressive.
- `truck_explode` · 2.5 s — A hover truck exploding: two big blasts, burning debris raining down, metal clanging. Huge payoff.
- `car_door` · 0.8 s — A hydraulic hiss, servo whine, and a soft latch.
- `car_drive` · 3.0 s — A high-performance launch: tyres spinning and biting, engine screaming up through gears, receding into distance.
- `car_start` · 2.0 s — An engine starting: starter cranking, catching, throttle blip, settling to a purring idle.
- `car_unlock` · 0.6 s — Two quick electronic chirps and locks clunking open.

## 9. Enemies

### Cyborg and Host
- `cyborg_charge` · 1.0 s — A bright whine climbing in pitch with electric crackle, an arm cannon charging. Clear warning.
- `cyborg_shot` · 0.5 s — A harsh buzzy saw-zap laser with crackle. Harsher and lower than the player's laser.
- `cyborg_drop_land` · 0.8 s — A heavy thud with a ringing metallic clank, a cyborg landing on a roof.
- `cyborg_host_glitch` · 2.4 s — A corrupted screen up close: stuttering static, low detuned hum sinking, rows of image jumping.
- `cyborg_host_turn` · 1.0 s — A neck servo grinding up and ratcheting, a burst of static as it lifts its head.
- `bad_dream_emerge` · 1.8 s — Dark vapor swelling and a dissonant drone bursting from a host. Horror.
- `bad_dream_shriek` · 1.2 s — A piercing, wavering ghostly shriek as the maw opens. Warning.
- `bad_dream_slash` · 0.7 s — A vapor swish with three claws ringing like blades.
- `bad_dream_dissolve` · 1.5 s — A moan sinking and breaking into hiss as it dissolves.

### Drone and Enforcer
- `drone_swoop` · 2.0 s — A helicopter rotor chop approaching, passing overhead, receding. Doppler.
- `drone_windup` · 1.5 s — A buzzing motor climbing in pitch as a gatling spins up. Warning.
- `drone_fire` · 0.5 s — Four rapid sharp gun cracks.
- `drone_crash` · 1.5 s — A drone slamming into a hull: metal clang and crunch, a small blast, rotors winding down.
- `enforcer_siren` · 2.0 s — Two police siren whoops with a diesel rumble. Arrival.
- `enforcer_whine` · 1.5 s — Emitters charging: a rising saw whine becoming a scream. Warning.
- `enforcer_laser` · 0.4 s — A fast electric zap falling in pitch with a noise crack.
- `enforcer_pickup` · 1.0 s — A boot on a steel roof, hatch clanking, radio squelch and chirp.
- `enforcer_crash` · 2.0 s — Brakes screaming, a nose-first steel crunch, deep boom and debris clatter.

### Barnacle, Octodog, Screech, Buzz
- `barnacle_emerge` · 0.8 s — A dull metal clunk, a rubbery pop and a rising servo chirp.
- `barnacle_charge` · 1.0 s — An FM whine climbing 220 Hz to 1.4 kHz. Warning.
- `barnacle_shot` · 0.4 s — A plosive thump and a rounder "pew" falling in pitch.
- `barnacle_death` · 0.7 s — A squeal falling away, a pop, and a fizzle.
- `octodog_windup` · 1.0 s — A wet rough snarl over a whirring servo. Warning.
- `octodog_lunge` · 0.6 s — A fast whoosh with a snarl and skittering metal claws.
- `screech_shake` · 1.0 s — A manhole cover or vent rattling faster. Warning.
- `screech_burst` · 0.9 s — A cover clanging open, a squealing shriek, a wet splash.
- `screech_swipe` · 0.4 s — A fast swish with claw scrape and squeak.
- `screech_chirp` · 0.7 s — A happy trill, questioning, with a soft purr. Friendly creature.
- `screech_sniff` · 1.2 s — Short wet snuffling breaths in twos and threes with squeaks and claws.
- `buzz_rev` · 1.5 s — A diesel cough and climbing growl under a saw blade whine rising from hum to scream. Warning.
- `buzz_charge` · 1.5 s — A blade at full speed tearing into the floor: grinding, shrieking, enormous.

### Resonator and Volley
- `resonator_warning` · 3.0 s — A fire roaring up for the entire warning and a huge wave crashing at its end. Epic build.
- `resonator_pulse` · 1.5 s — A deep thump dropping away, a wave rolling in.
- `resonator_death` · 2.0 s — Three resonant glassy tones struck together and bending out of tune as halos break.
- `volley_hit` · 0.35 s — A hollow thump, a sharp slap of skin on a ball.
- `volley_bounce` · 0.45 s — A dull low thump into sand with a puff of grains.
- `volley_whistle` · 0.6 s — A bright referee's pea whistle trill.

## 10. Sewer Swarm (boss)

- `swarm_rise` · 3.0 s — Manhole covers rattling and clanging, then a vast horde of rats screaming up out of the sewers over a deep rumbling roar. Overwhelming and nasty.
- `swarm_chitter` · 1.5 s — A frantic chittering of thousands of tiny voices climbing in pitch and density, ending in a sharp hiss. Clear incoming-attack warning.
- `swarm_surge` · 1.5 s — A wall of claws rushing across asphalt, a big air whoosh and a burst of shrieks. Fast and frightening.
- `swarm_wave` · 2.0 s — A rising chitter over a swelling surf of claws and squeals, building like a tide about to break from behind. Warning.
- `swarm_shock` · 1.0 s — A crackling electric zap, squeals cut short mid-scream, a fizzling sizzle. Satisfyingly brutal.
- `swarm_fall` · 1.0 s — Squeals falling away, frantic scrabbling claws, a distant dull thud far below.
- `swarm_scatter` · 1.2 s — A horde thinned to nothing: squeals and claws scattering away in all directions.
- `swarm_climb` · 1.2 s — Many claws scrabbling up rough brick, pitch climbing, excited squeaks.
- `host_burst` · 2.0 s — A hulking cyborg beast bursting out of a pipe: tearing metal, a huge thud, a groaning roar and the swarm spilling out. Monstrous entrance.
- `host_roar` · 1.5 s — A deep, rising, ragged monster roar with the swarm shrieking inside it. Warning for a lunge.
- `host_fling` · 1.0 s — A big heave, a whoosh and squeals flung through the air.
- `host_crouch` · 0.8 s — A heavy thud as a giant beast crouches, implants humming up with electrical whine.
- `host_short` · 1.0 s — Implants shorting out: crackling zaps and a buzz dying away. Satisfying payoff.

## 11. Giant Head (boss)

- `head_flyover` · 3.0 s — A colossal airship passing low overhead from behind: deep detuned engine drones, the rumble shaking the ground, a Doppler sweep into the distance.
- `head_reveal` · 2.0 s — A gigantic face-screen powering on: a CRT thunk, a rising whine, a burst of static, a deep ominous hum. Dread.
- `head_laser_charge` · 1.5 s — Two detuned energy whines rising in pitch and volume as giant eyes charge. Clear warning.
- `head_laser_fire` · 1.5 s — Twin beams firing: a zap diving from a shriek into a harsh buzz, hot sizzle on top, sub-bass punch. Devastating.
- `head_mouth_open` · 1.5 s — Gears ratcheting under a grinding mechanical drone as a huge mouth opens. Ominous.
- `head_weak_open` · 1.0 s — Hydraulic hiss and heavy armored covers swinging open with a clank. "Hit me now."
- `head_shriek` · 1.5 s — A distorted mechanical scream through blown-out loudspeakers, pitch lurching up. Pain and fury.
- `head_shake_free` · 2.0 s — A long grinding scrape of metal on stone, a lurching thud and a roar of engines straining free.
- `head_voice_1` · 1.5 s — A booming loudhailer shout of garbled, unintelligible syllables, ring-modulated and blown-out. Authoritarian propaganda.
- `head_voice_2` · 1.5 s — A second garbled loudhailer shout, different cadence, rising at the end.
- `head_voice_3` · 1.5 s — A third garbled shout, shorter and clipped, barked like an order.
- `head_voice_4` · 1.5 s — A fourth garbled shout with a long drawn-out vowel, climaxing and echoing off buildings.
- `head_voice_cut` · 1.2 s — A shout climbing into a held vowel, then breaking up and cutting out mid-shout into silence. Victory.
- `head_power_down` · 3.0 s — Engines spinning down, power cutting in and out as they die. A great machine losing its life.
- `head_crash` · 3.5 s — A colossal head crashing into a street: huge impact, deep sub boom, hull crumpling, long debris rattle. Cinematic finale.

## 12. Hostile Takeover (boss)

- `takeover_gunship` · 3.0 s — A massive gunship sweeping in: turbine whine falling as it passes (Doppler), a jet roar swelling and shaking the speakers.
- `takeover_couplings` · 1.5 s — Heavy steel couplings clunking home twice, an electric hum swelling, a two-note tone. Ominous.
- `takeover_decouple` · 1.5 s — A coupling cracking apart: a huge clank, a low thud and a hydraulic burst. Crunchy and heavy.
- `takeover_breakaway` · 2.5 s — Carriages tearing loose: steel shrieking on the guideway, scraping and falling away.
- `takeover_whine` · 1.5 s — Cannon barrels spinning up, rising whine, servo whirr. Warning for a strafing run.
- `takeover_strafe` · 2.0 s — A rattling burst of heavy cannon rounds, each a sharp crack with a deep thump, slightly irregular.
- `takeover_drop` · 1.5 s — A huge machine landing on a roof: massive steel slam, low boom, crunching grit.
- `takeover_bay` · 1.5 s — A pneumatic hiss, two heavy clunks as bay doors part, a low two-note warning tone.
- `takeover_clamp` · 1.0 s — A docking clamp ripped loose: hydraulic burst, steel snapping with a ringing clank, falling alarm.
- `takeover_clamps` · 2.0 s — Three huge clamps slamming home one after another, each a heavy clank over a thud.
- `takeover_merger` · 2.5 s — A cold corporate broadcast sting: a swelling synthetic chord with a cold chime. "Merger complete." Menacing.
- `takeover_explode` · 3.0 s — A gunship exploding: huge boom, fireball roar and crackle, turbines winding down, debris raining.
- `takeover_derail` · 4.0 s — A locomotive derailing: long screech of steel, a crash of glass and girders, a final heavy slump.

## 13. Magnate (boss)

- `magnate_breath` · 1.5 s — Heavy rasping breath in, a deep rattling breath out. Huge, wounded creature.
- `magnate_growl` · 1.5 s — A deep rattling growl from behind. Menacing.
- `magnate_roar` · 2.0 s — A rising bellow falling into a growl. Warning for a pounce.
- `magnate_howl` · 1.5 s — A howl rising and falling as he hurls himself through the air.
- `magnate_leap` · 1.0 s — Claws scraping stone, a thump pushing off, a grunt, the rush of a huge body through the air.
- `magnate_crash` · 1.5 s — A deep boom with a heavy thump as a beast lands. Shakes the speakers.
- `magnate_slam` · 1.5 s — A clang of gold plates, a boom, stone giving way. Brutal impact.
- `magnate_stun` · 1.5 s — A dazed groan sinking in pitch, ports sparking on his spine.
- `magnate_stomp` · 1.0 s — A heavy thud and crunch, ports shorting with a zap and a shriek. Satisfying.
- `magnate_pain` · 0.85 s — A yelp leaping upward and breaking into a choked cry.
- `magnate_death` · 2.0 s — A roar sinking, breaking into convulsions, then a rattling final breath. Climactic.
- `magnate_collapse` · 2.0 s — A heavy body falling in silence: a boom, a thud, a smaller shift. Final.
- `magnate_snarl` · 0.55 s — A sharp snarl jumping upward in pitch. Warning for a claw slash.
- `magnate_swipe` · 0.5 s — A rush of air sweeping down and three claws raking. Fast, lethal.
- `magnate_glitch` · 1.5 s — A feed whine rising with stuttering static. Warning for a falling screen.
- `magnate_smash` · 1.0 s — A heavy hit with a boom and thud and glass shattering.
- `magnate_yank` · 0.5 s — A metal cable whipping taut with a twang.
- `magnate_crackle` · 1.5 s — Electricity building along a cable, crackles thickening. Warning for a lash.
- `magnate_whip` · 0.7 s — A swish across the track, a sharp cable crack and a zap dying away.
- `magnate_tear` · 0.8 s — A cable ripping out of his back: a rip, a spark pop and a snap.
- `magnate_screens` · 1.5 s — Screens dying: a hum falling away under a power-cut thump and a static collapse.
- `magnate_screen` · 0.8 s — One screen going dark: a static burst, a switch-off whine and a pop.
- `magnate_burst` · 1.5 s — A suit bursting open: a blast, gold plates clanging off in every direction, metal tearing, a hiss.
- `magnate_suit_fall` · 2.5 s — An empty suit toppling off a causeway: metal groaning, scraping and crashing down.
- `magnate_suit_down` · 2.5 s — A distant boom, a heavy splash and rippling water far below.

## 14. Sleep Taker (boss)

- `sleep_taker_rise` · 3.0 s — A deep rumble swelling from the street with a chorus of moans rising a semitone apart. Nightmarish.
- `sleep_taker_shriek` · 1.5 s — A choir of screaming voices on a tritone. Warning for a giant slash.
- `sleep_taker_slash` · 0.9 s — A huge low swish, five claws ringing, a deep thud.
- `sleep_taker_whisper` · 2.5 s — Many breathy voices whispering made-up words over each other, sibilant and close. Warning for hands.
- `sleep_taker_hand` · 1.0 s — A wet crack, a thud and the scrape of claws as a hand bursts from mist.
- `sleep_taker_inhale` · 2.5 s — A long rasping inhale through dozens of maws rising over a moan. Warning for lights out.
- `sleep_taker_exhale` · 2.0 s — A long sigh sinking and dying away. Relief.
- `sleep_taker_lure` · 2.0 s — A deep growl rising, hungry moans climbing, the rush of its lunge.
- `sleep_taker_crackle` · 1.5 s — Generator arcs crackling into it: a buzzing hum with sharp zaps.
- `sleep_taker_torn` · 1.5 s — A choir's howl of pain falling, a wet rip and a deep thud.
- `sleep_taker_wisps` · 2.5 s — Soft airy voices sighing upward with a faint shimmer, fading into silence. Release.

## 15. Gilded Sentinel and Tithe Collector

- `gilded_sentinel_grind` · 2.0 s — Stone grinding on stone, a deep wind-up as a halberd is drawn back. Warning.
- `gilded_sentinel_swing` · 0.8 s — A ringing blade, a fast heavy whoosh, a stone thud.
- `gilded_sentinel_break` · 1.5 s — Stone cracking and crumbling, gold pieces clattering down, a dull thump.
- `tithe_collector_cue` · 1.0 s — A smug little chuckle: three "heh" syllables, each a touch lower. Mean and cheeky.

## 16. The House (slot-machine boss)

- `house_roll` · 2.0 s — A tank-tread rumble and clank under a cheery slot-machine jingle. Entrance.
- `house_lever` · 1.0 s — A big ratchet and heavy clunk at the bottom of a lever pull.
- `house_spin` · 2.5 s — Reels whirring with accelerating clicks under a rising whirr, then slowing.
- `house_ding` · 0.5 s — A bright bell over a clunk as a reel stops.
- `house_lock` · 0.8 s — A rising two-bell chime and sparkle. Clearly different from a plain ding.
- `house_button` · 0.4 s — A soft bright "bling".
- `house_cherry` · 1.0 s — A cartoon lob and fuses hissing. Warning.
- `house_lightning` · 1.0 s — An electric zap and buzzing crackle. Warning.
- `house_bar` · 1.0 s — A heavy metal ring and falling ringing whoosh. Warning for gold blocks.
- `house_slam` · 1.0 s — A deep thud and clanging ring.
- `house_jackpot` · 3.0 s — Two-tone sirens wailing over a fanfare of bells. Over the top.
- `house_coins` · 2.5 s — A fountain cascade of coins.
- `house_sag` · 1.5 s — Overload: groaning metal and a hydraulic hiss.
- `house_hit` · 1.5 s — A crunching crash, a burst of coins and a jingle dying away.
- `house_billboard` · 2.0 s — A falling whoosh, hover jets settling, a hum.
- `house_tilt` · 2.0 s — Reels clunk to a stop one after another, then a TILT buzzer blares.
- `house_collapse` · 3.0 s — Groaning, crashing metal and a cascade of coins. Spectacular finish.

## 17. Golden Convergence (final boss)

- `gc_rise` · 4.0 s — A sub rumble and mechanical groan swelling as a colossus rises, a deep hum climbing, a cape flapping. Epic entrance.
- `gc_chime` · 4.0 s — A huge, slow cult chime: mallet-and-glass notes G5, C6, E6, ringing long.
- `gc_emerge` · 2.5 s — A cloth rustle, then three rotors spinning up a little apart.
- `gc_whine` · 2.5 s — Gatlings spinning up together. Warning for a gun pass.
- `gc_rake` · 2.5 s — Rounds cracking over rotors, chewing stone. Vertical pass.
- `gc_sweep` · 2.5 s — Rounds swept low to high across the screen. Horizontal pass.
- `gc_spark` · 0.8 s — Ricochet pings falling in pitch off stone and gold.
- `gc_buttress` · 2.0 s — Stone grinding and rumbling as a buttress rises.
- `gc_crumble` · 2.5 s — A sharp crack, a deep thud, rubble pattering down.
- `gc_hurl` · 1.2 s — A spring twang and a rotor screaming up in pitch as a drone is flung.
- `gc_return` · 2.5 s — Rotors receding, darker and softer under a rush of cloth.
- `gc_grind` · 2.5 s — A deep grinding wind-up of a golden fist. Warning.
- `gc_slam` · 1.5 s — A huge thud, a golden clank and a stone thump.
- `gc_break` · 2.5 s — Stone splitting, slabs grinding apart, rubble.
- `gc_topple` · 4.0 s — A deep groaning creak and rumble as a tower leans and falls.
- `gc_hatch` · 1.5 s — Two hatch clanks and a hydraulic hiss. Warning for a missile barrage.
- `gc_launch` · 3.0 s — Missiles launching one after another: a pop and a roar each.
- `gc_whistle` · 2.5 s — A chorus of whistles rising as missiles dive. Warning; clearly different from `gc_whine`.
- `gc_fire` · 3.0 s — A blast of flame rushing over the floor, then roaring.
- `gc_ship` · 4.0 s — A huge ship flying in, engines droning and swelling.
- `gc_feed` · 1.5 s — A pneumatic pop and hose hiss as a feed line shoots out.
- `gc_ride` · 2.0 s — Rollers clattering faster up a hose, with a hiss.
- `gc_ripple` · 3.0 s — Metal smashing, then missiles popping one after another along a rack.
- `gc_crash` · 4.0 s — A ship exploding: huge blast, a second blast, hull tearing.
- `gc_blast` · 2.5 s — A roar climbing in pitch racing up a line.
- `gc_pipes` · 3.0 s — Pipes blowing out: a boom, metal tearing, steam venting.
- `gc_leave` · 2.5 s — A ship's engines spooling up and receding.
