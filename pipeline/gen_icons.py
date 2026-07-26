#!/usr/bin/env python3
"""Draw flat white UI icons with an alpha channel, 160x160.

The game tints icons at runtime (`UI.icon(name, size, colour)`), so the source art is a
pure-white silhouette and only the alpha matters. Shapes are drawn at 4x and downsampled,
which is what gives the edges their anti-aliasing without any external dependency.

Usage:  python3 pipeline/gen_icons.py <game_dir> [name ...]
Existing files are only rewritten when named explicitly, so regenerating one icon can
never quietly restyle the rest of the set.
"""
import sys
import os
from PIL import Image, ImageDraw

S = 160
SS = 4          # supersample factor
W = (255, 255, 255, 255)


def _canvas():
    im = Image.new("RGBA", (S * SS, S * SS), (255, 255, 255, 0))
    return im, ImageDraw.Draw(im)


def _finish(im):
    return im.resize((S, S), Image.LANCZOS)


def heart(_d=None):
    """Supporter tip: a heart, slightly wide so it reads at 24 px."""
    im, d = _canvas()
    u = S * SS / 100.0
    d.ellipse([26 * u, 20 * u, 54 * u, 50 * u], fill=W)
    d.ellipse([46 * u, 20 * u, 74 * u, 50 * u], fill=W)
    d.polygon([(27 * u, 40 * u), (73 * u, 40 * u), (50 * u, 82 * u)], fill=W)
    return _finish(im)


def cart(_d=None):
    """Buy action: a shopping cart — basket, handle, two wheels."""
    im, d = _canvas()
    u = S * SS / 100.0
    # handle
    d.line([(14 * u, 22 * u), (26 * u, 22 * u), (36 * u, 62 * u)], fill=W,
           width=int(6 * u), joint="curve")
    # basket: a trapezoid, wider at the top
    d.polygon([(30 * u, 32 * u), (88 * u, 32 * u), (78 * u, 62 * u), (38 * u, 62 * u)],
              fill=W)
    # wheels
    d.ellipse([38 * u, 70 * u, 52 * u, 84 * u], fill=W)
    d.ellipse([66 * u, 70 * u, 80 * u, 84 * u], fill=W)
    return _finish(im)


def shield(_d=None):
    """Streak shield: flat crown, straight flanks, tapering to a point.

    Drawn crown-first rather than as two lobes — lobes read as a heart, which is the
    other icon in this set and exactly the confusion to avoid.
    """
    im, d = _canvas()
    u = S * SS / 100.0
    d.rounded_rectangle([16 * u, 14 * u, 84 * u, 52 * u], radius=int(8 * u), fill=W)
    d.polygon([(16 * u, 44 * u), (84 * u, 44 * u), (74 * u, 70 * u), (50 * u, 88 * u),
               (26 * u, 70 * u)], fill=W)
    return _finish(im)


def key(_d=None):
    """Treasury key: bow, shaft, two teeth."""
    im, d = _canvas()
    u = S * SS / 100.0
    d.ellipse([12 * u, 30 * u, 52 * u, 70 * u], fill=W)
    d.ellipse([24 * u, 42 * u, 40 * u, 58 * u], fill=(255, 255, 255, 0))
    d.rectangle([46 * u, 43 * u, 90 * u, 57 * u], fill=W)
    d.rectangle([68 * u, 57 * u, 78 * u, 74 * u], fill=W)
    d.rectangle([84 * u, 57 * u, 90 * u, 70 * u], fill=W)
    return _finish(im)


def dice(_d=None):
    """Mission reroll: a die showing five, pips punched out of the face."""
    im, d = _canvas()
    u = S * SS / 100.0
    d.rounded_rectangle([16 * u, 16 * u, 84 * u, 84 * u], radius=int(14 * u), fill=W)
    for cx, cy in [(32, 32), (68, 32), (50, 50), (32, 68), (68, 68)]:
        d.ellipse([(cx - 7) * u, (cy - 7) * u, (cx + 7) * u, (cy + 7) * u],
                  fill=(255, 255, 255, 0))
    return _finish(im)


def undo(_d=None):
    """Undo: a counter-clockwise arc with a solid arrowhead."""
    im, d = _canvas()
    u = S * SS / 100.0
    d.arc([18 * u, 22 * u, 82 * u, 86 * u], start=150, end=390, fill=W, width=int(13 * u))
    d.polygon([(10 * u, 46 * u), (44 * u, 46 * u), (27 * u, 16 * u)], fill=W)
    return _finish(im)


def frame(_d=None):
    """Card frame cosmetic: a picture frame with a mount inside."""
    im, d = _canvas()
    u = S * SS / 100.0
    d.rounded_rectangle([12 * u, 18 * u, 88 * u, 82 * u], radius=int(9 * u), fill=W)
    d.rounded_rectangle([24 * u, 30 * u, 76 * u, 70 * u], radius=int(5 * u),
                        fill=(255, 255, 255, 0))
    d.polygon([(30 * u, 66 * u), (46 * u, 44 * u), (58 * u, 60 * u), (66 * u, 50 * u),
               (70 * u, 66 * u)], fill=W)
    return _finish(im)


ICONS = {"heart": heart, "cart": cart, "shield": shield, "key": key, "dice": dice,
         "undo": undo, "frame": frame}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    out_dir = os.path.join(sys.argv[1], "assets", "icons")
    os.makedirs(out_dir, exist_ok=True)
    wanted = sys.argv[2:] or list(ICONS)
    explicit = bool(sys.argv[2:])
    for name in wanted:
        if name not in ICONS:
            print(f"unknown icon: {name} (known: {', '.join(sorted(ICONS))})")
            return 1
        path = os.path.join(out_dir, f"{name}.png")
        if os.path.exists(path) and not explicit:
            print(f"skip {name} (exists)")
            continue
        ICONS[name]().save(path)
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
