# Questions from PERF3 (the web demo's load: gradual shader warm-up behind the hint screen)

1. **The level's loading look** (GDD §11: the look; related to item 235, the page's own loading screen).
   While a level's shaders compile behind its hint screen (a minute or more in a Windows browser, a moment
   on a desktop build), the hints can be read and paged, and the PLAY button reads "LOADING 40%" and can't
   be pressed until the level is ready. Placeholder: that (`LevelIntroScreen._show_load`, marked
   DESIGN-TBD). Right, or should the wait show some other way: a progress bar under the hints, a line of
   text ("Preparing the city..."), a short tip, or a loading screen of its own before the hint screen?

2. **The intro's own wait.** Pressing Play on the title still freezes on the title for a while in a
   browser: the City's intro compiles about 40 shader programs in its first frame, before anything moves.
   The same gradual warm-up could run behind a short loading card before the intro starts. What should
   that card look like (the game's title on the dark violet, the zone's name, a progress bar)? Placeholder
   until decided: none (the intro is unchanged in this task).
