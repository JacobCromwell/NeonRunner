# Questions from task F2f (the Marketplace's intro; the owner's beats, October 16, 2026)

The owner's beats (GDD §6, Cinematics, "Marketplace intro") left these details open. Each has a placeholder, marked
DESIGN-TBD in `scripts/cinematics/marketplace_intro/` and its numbers in `data/cinematics/marketplace_intro_tuning.tres`
(`MarketplaceIntroTuning`), built so it's cheap to change.

1. **The stall-keeper's look, simplified from the owner's reference picture.** Placeholder (`MarketplaceIntroVendor`):
   dark hair up in a messy bun with loose strands at her temples, a brass eyepiece with a dark lens over her right eye on
   a band round her head, a striped neck scarf (faded rust, teal, cream; muted, never a hazard's red), a short-sleeved
   olive-grey shirt with the sleeves rolled, a worn grey-green apron with a pocket, dark work trousers, a dark bracer
   with a little dark screen on her left wrist. Nothing on her glows (the eyepiece's lens and the bracer's screen would
   otherwise read as a cyborg's screen, GDD §9.2), and she is 1.2 m tall against the runner's 1.28 m. Her hands rest on
   the counter, out of sight behind the goods, between gestures.

2. **The card.** Placeholder (`marketplace_intro_card.gdshader`): a worn, creased card of cream paper, 13 × 9 cm, the
   Chairman's photo (Hostile Takeover's man, the same face as on the fight's merger screens) on its upper left with a
   white border, six lines of fast scribbled handwriting beside and under it, the first underlined. Is the Chairman the
   face the owner means by "the boss from the corporate zone" (Hostile Takeover has no face of its own besides him)?

3. **The line of stalls.** Placeholder: eight of the Marketplace's stall doodads, end to end along the left of the
   street with 0.4 m between them, scaled to 0.72 (their counter at the runner's waist), their awnings blue, green,
   purple, teal and mustard in turn (the doodad's blue repainted; a `recolor` on the doodad card shader that every level
   leaves off), every other one turned end for end. Only hers has a keeper; the others are unattended.

4. **The voices.** Placeholder (`tools/asset_gen/sfx_bank_marketplace_intro.gd`): four mumbles, each syllable a "wah"
   (a buzzing voice through two vowel resonances opening and closing, a muted trombone talking): her chatty 2.3 s line
   to the runner, her emphatic 2.1 s answer to the cyborg ending on a high "that way!", the cyborg's low, gruff,
   crushed 1.8 s question and its two-syllable call to the others. No real words in any.

5. **The staging and timing.** Placeholder: 38.6 s in ten shots: across the street looking back along the stalls as the
   runner walks up; the two at the counter as the card comes up; a close-up of the card from her side, pushing in
   (2.85 s); her talking, over the runner's shoulder, waving her arms; wider as the runner nods twice and walks off down
   the street; low by her stall looking back as the cyborg walks up, the three others standing about further back; the
   cyborg and her (it talks, she answers and points after the runner with the arm on that side, its head turning to
   look); along her arm down the street, the runner small in the distance; it turns to the others and waves them over
   (its arm up toward them, beckoning, with its call); low behind the four as they set off after the runner; then
   black, the zone's title card ("ZONE 3", "MARKETPLACE") on it, and Marketplace 1. The zone's music fades in under
   it from the start. It is longer than GDD §1's 5-15 s, as the Beach outro is.

6. **How many cyborgs come.** Placeholder: the one who talks to her and three others it waves over, all in the zone's
   enemy look (the Marketplace's `casino` variant); they follow at a walk (1.75 m/s), not a run.
