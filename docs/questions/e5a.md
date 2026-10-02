# E5a: The House (step 1, E5a-a: the machine, the spin and its attacks, the 7 buttons, the jackpot)

Numbers in `data/bosses/marketplace_boss_tuning.tres` (F6 in its fight) and `data/bosses/marketplace_boss.tres`;
play the preview with `./play.sh --boss=marketplace_boss`; review with
`tools/showcase/the_house_showcase.tscn -- --scenario=spin|buttons|jackpot|fight`. Everything below is
`DESIGN-TBD`. Phases 2 and 3 play like phase 1 until task E5a-b, and its defeat is a placeholder.

1. **The 7 buttons' look** (GDD §10: "big glowing 7 buttons appear along the route. Running over one
   locks its reel on 7"; they must read as safe to run over).
   **Placeholder:** a big round ivory button flat on the floor, ringed in white with warm bulbs chasing
   round it, the reels' own 7 in royal blue in its middle, and the same 7 floating upright above head
   height over it (it marks the button from far along the street, and shrinks away as the runner nears).
   Why: white and ivory are the pickups' "safe" neutrals; royal blue is no hazard's colour and not the
   pads' cyan; round is no pad's or ramp's shape; the 7 ties it to the reels. Each lights up 1.35 s
   before the runner reaches it, with a soft chime. **Alternative:** a gold coin-shaped button (gold reads
   as the BAR blocks' colour, so we kept it off).
2. **Do locked reels stay locked?** (GDD §10: "With all three locked: JACKPOT"; "missed buttons: it just
   spins again").
   **Placeholder:** yes, until the jackpot (`locks_persist`): a missed button only means its reel shows its
   symbol and that attack comes; the next spin offers buttons for the reels still spinning, so a runner
   rigs the machine a reel at a time (a missed jackpot clears them). **Alternative:** all three in one spin
   (`locks_persist` off), much harder once phases 2 and 3 put a button on a wall or a ceiling.
3. **How the player reaches the hopper** (GDD §10: "its coin hopper bursts open on top as a glowing red
   weak point while it sags low. The player stomps it").
   **Placeholder:** at the jackpot it rolls to a stop where the runner reaches it 2.6 s later (at any
   speed), and sinks into the street until its top is a low deck (0.35 m) the runner can run onto. The
   hopper is open in that deck across the whole street, glowing red, its stomp box 12 m long at 18 m/s
   (stretched with the speed): any jump that comes down on it stomps it, from the street or from the deck
   (the box is longer than a jump). A runner who doesn't jump runs over it unhurt; then it lurches out
   from under them, rises and spins again. The hopper opens about 1.5 s before the runner reaches it, at
   18 and 22.6 m/s. **Alternative:** it stays standing and its payout chute drops to the street as a ramp
   up to the hopper on its top.
4. **How long a phase lasts before the buttons come** (GDD §10: a fight of about 60-120 s).
   **Placeholder:** each phase opens with two spins without buttons (`opening_spins`: only attacks, about
   6 s each), then every spin offers buttons. A runner who never misses wins a phase in about 20 s (the
   whole fight about 64 s with phases 2 and 3 still played as phase 1). The spins' symbols follow a list
   per phase (`spin_patterns`, with pairs and triples) rather than chance. **Alternative:** buttons from
   the first spin, with fewer buttons per spin.
5. **The arena** (GDD §10: "unique scripted encounters"; the Marketplace's floor is stall roofs with gaps
   between the stalls).
   **Placeholder:** a plain street: the arena's laps keep no holes, fences, signs, ceilings, pads or
   doodads of their own, so every danger is the machine's (its attacks are planned around each other
   and every button and the hopper are always reachable). **Alternative:** the Marketplace's own gaps
   and fences between spins, which the machine's attacks and buttons would keep clear of.
