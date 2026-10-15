#!/usr/bin/env python3
"""How bright each rendered frame is, for judging an explosion's glare (task H6).

An explosion must never white the view out: the runner and the lane ahead stay readable. Render frames of a
scene (tools/showcase/fireball_showcase.tscn, 10 fps) and give this the frames' common prefix:

    python3 -I tools/measure/screen_luminance.py build/h6/drone_f build/h6/enforcer_close_f

For each prefix it prints the scene's own brightness (the 25th percentile of the mean luminance over the
frames), the brightest frame, and the verdict: at most ONE frame (after the first two, while the stage
settles) may have a mean luminance above 2x the scene's, and at most one may have more than 10% of the
screen above luminance 0.35. Exit code 1 if any prefix fails. With --frames the per-frame means are listed.
"""
import glob
import sys

from PIL import Image

WIDTH, HEIGHT = 160, 90
MEAN_FACTOR = 2.0
BRIGHT_LEVEL = 0.35
BRIGHT_AREA = 0.10
SETTLE = 2


def _linear(c: float) -> float:
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


LUT = [_linear(i) for i in range(256)]


def frame_stats(path: str) -> tuple:
    """(mean luminance, share of the screen above BRIGHT_LEVEL) of one frame, in linear light."""
    image = Image.open(path).convert("RGB").resize((WIDTH, HEIGHT))
    pixels = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
    lums = [0.2126 * LUT[r] + 0.7152 * LUT[g] + 0.0722 * LUT[b] for r, g, b in pixels]
    return sum(lums) / len(lums), sum(1 for v in lums if v > BRIGHT_LEVEL) / len(lums)


def main(argv: list) -> int:
    show_frames = "--frames" in argv
    prefixes = [a for a in argv if not a.startswith("--")]
    failed = False
    for prefix in prefixes:
        files = sorted(glob.glob(prefix + "*.png"))
        if len(files) <= SETTLE + 1:
            print("%s: no frames" % prefix)
            failed = True
            continue
        stats = [frame_stats(f) for f in files]
        base = sorted(s[0] for s in stats)[len(stats) // 4]
        later = stats[SETTLE:]
        peak = max(range(len(later)), key=lambda i: later[i][0])
        over_mean = sum(1 for s in later if s[0] > MEAN_FACTOR * base)
        over_area = sum(1 for s in later if s[1] > BRIGHT_AREA)
        ok = over_mean <= 1 and over_area <= 1
        failed = failed or not ok
        print("%-34s scene %.3f  peak %.3f (x%.1f) at frame %d  frames over 2x: %d  over 10%% bright: %d (max %.2f)  %s" % (
            prefix.split("/")[-1], base, later[peak][0], later[peak][0] / max(base, 1e-6), peak + SETTLE, over_mean, over_area,
            max(s[1] for s in later), "ok" if ok else "TOO BRIGHT"))
        if show_frames:
            print("   " + " ".join("%d:%.2f" % (i, s[0]) for i, s in enumerate(stats)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
