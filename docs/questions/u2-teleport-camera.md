# U2, the camera's sweep across a teleport

The owner's request (October 24, 2026): "The Ice zone's teleporters work well, but I'd like a visual to accompany them. When
the player touches the teleporter, the camera should zoom in to where the teleporter's output is. Even though the player
character teleports instantly, the camera catches up, showing the user what happened through its movement." Built as
`RunCamera`'s sweep (`TeleporterTuning`, "The camera's sweep", `data/tuning/teleporters.tres`, F6 "Teleporters"). The GDD does
not describe it (the camera's clean cut was task Q4's placeholder, `docs/OPEN_QUESTIONS_DEFERRED.md` item 1156, which this
replaces: the sweep answers its "should the jump take a moment"), so these numbers are placeholders, all marked
`DESIGN-TBD` in `scripts/world/teleporter_tuning.gd` and `scripts/run/run_camera.gd`.

1. **Is a sweep the right reading of "zoom in to where the output is"?** (GDD §5, Zone 9, the camera at a teleport.)
   Placeholder: at the touch the runner is moved at once and the camera stays where it was (the input pad's view, with
   the output pads and the runner far ahead in frame), then rushes after them along the track and across to their new lane,
   easing out, and lands on the usual framing: `sweep_seconds` 0.35, `sweep_ease_power` 2.0 (about three quarters of the
   way in the first half). Camera only: the runner's position, speed, hitbox and control are the teleport's as before.
   `sweep_seconds` 0 is the old clean cut. The camera passes through whatever lies between the pads (ceilings keep it
   down: the ceiling and doodad checks run where it really is), the enemies between having left play at the touch.
2. **How long may the sweep take?** Placeholder 0.35 s of real time (slow time doesn't stretch it): at most half of the
   landing's 1.0 s of guaranteed clear floor (`landing_seconds`), and the runner is back in frame, at the camera's usual
   distance, within about 0.25 s. The view ahead of the landing is in frame throughout (the camera looks down the track from
   the input pad). The runner themselves is a small figure in the distance for the first fifth of a second: the owner may
   prefer a shorter, a longer, or a differently shaped sweep (`sweep_seconds`, `sweep_ease_power`).
3. **The field of view's punch.** Placeholder: +6 degrees at the touch, easing back with the sweep (`sweep_fov_punch`;
   negative narrows the view for a "zoom in" feel instead of a rush). Left out with Reduced flashing and with Screen shake
   off (no kick in the view for a player who asked for none). There is no separate "reduced motion" setting: should the sweep
   itself be gentler (slower, less eased, or a plain cut) for a player who asked for Reduced flashing? Today the sweep
   stays for them, only without the punch, and the flash is the soft tint as before (task Q4's question on it).
4. **The flash beside the sweep.** Placeholder: while the camera sweeps, the flash is `sweep_flash_share` 0.5 of
   `flash_alpha` (0.275 of the screen at the touch instead of 0.55), so it pops without washing the sweep out; with the sweep
   off (`sweep_seconds` 0) the flash is `flash_alpha` as before. Reduced flashing's soft tint is unchanged.
