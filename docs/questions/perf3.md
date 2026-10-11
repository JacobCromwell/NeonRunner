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
