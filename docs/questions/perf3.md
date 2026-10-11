# Questions from PERF3 (the web demo's load: gradual shader warm-up and loading cards)

Answered by the owner on October 11, 2026 (recorded in GDD §11, Loading cards): the level's loading look
is a **progress bar**, and the load runs behind a **loading card**, the level's own card or else its zone's;
Zone 1's card shows the runner with an explosion behind him, cyborgs on the sides, an Enforcer Truck behind
and the heli drone overhead, in the Neon City.

Still open:

1. **How long a card shows at least** (GDD §11, Loading cards). On a desktop build a level loads in a
   moment, and a card that flashed for a frame would look like a glitch. Placeholder: at least 1 second
   (`PerformanceTuning.loading_card_min_seconds`, `data/tuning/performance.tres`, F6 "Performance", marked
   DESIGN-TBD). Right, or shorter, or no card at all when the load takes less than that?

2. **The card's words.** A level's card names the level in big letters with its zone under it ("ROOFTOP
   RUSH", "Neon City"); a cinematic's card names only the zone. Placeholder: that
   (`App.show_loading_card`). Should a card also say "Loading", show a tip, or show nothing but the bar?

3. **The other zones' cards.** Only the Neon City has one; the other zones (and the bosses) show a plain
   card on the menu backdrop with the name and the bar. Should each zone get its own card, and what should
   each show? Should a boss fight show a card of its own (the Floating Head, say) rather than its zone's?

4. **The Neon City card's staging** (`assets/sprites/loading_cards/city.png`, rendered by `tools/godot.sh cards`
   from `tools/asset_gen/loading_cards/city_card.gd`; every number in its `LOOK` table). Choices made to fill
   in the brief:
   - The runner runs toward us down the street, turned a little to his right (screen left) so his stride reads;
     the camera is low and close. The street runs away behind him, the City's moon and skyline where the game
     shows them.
   - The cyborgs' arm cannons show their **red charge glow**. It is their own look, but red is the game's attack
     warning colour; on a loading card it may read as a threat that isn't there. Keep it, or switch it off
     (`cy0_charge` to `cy3_charge` at 0)?
   - The fireball lights the runner, the cyborgs and the truck for real; the City's scenery is drawn unlit, so its
     glow on the street and the tower faces is painted on (soft additive patches, as the truck's headlights are
     in the game). The sun is a little brighter than in play (0.8, not 0.7), so the near cyborgs read against the
     dark wall.
   - A dark gradient and a soft vignette are baked into the picture's bottom, under the name and the bar.

