#!/usr/bin/env bash
#
# generate-icons.sh — regenerate the tile-upgrade-planner-muluna icon set
#                     from the Factorio base-game sources.
#
# Produces (all 8-bit RGBA PNG):
#   graphics/icons/tile-upgrade-planner-outline.png        64x64  transparent
#   graphics/icons/tile-upgrade-planner-frame.png          64x64  planner frame
#   graphics/icons/tile-upgrade-planner-item.png           64x64  frame + outline
#   graphics/icons/shortcut-toolbar/tile-upgrade-planner-x64.png
#   graphics/icons/shortcut-toolbar/tile-upgrade-planner-x24.png
#   graphics/icons/shortcut-toolbar/tile-upgrade-planner-x24-white.png
#   thumbnail.png                                         144x144
#
# How it works (three inline python heredocs + photocraft-cli)
#   1. geometry: traces the concrete silhouette from the alpha channel of
#      refined-concrete.png frame 0 (gaussian smoothing + sub-pixel marching
#      squares + Douglas-Peucker) and writes photocraft `path.set` payloads for
#      the solid outline band, the arrow, and the abstract dashed-square
#      shortcut glyph.
#   2. raster: photocraft-cli renders those paths into new/existing documents
#      and applies the frame recolour (Image > Adjustments > Levels, white
#      point 204) and the 64 -> 144 thumbnail upscale.
#   3. publish: re-writes the fully opaque renders as RGBA (photocraft stores
#      opaque documents as RGB) into $OUT_ROOT.
#   All numbers worth touching are collected at the top of this file.
#
# Requirements
#   - photocraft-cli on PATH (override with PHOTOCRAFT=/path/to/photocraft-cli)
#   - python3 with: numpy, Pillow, scipy, scikit-image, opencv-python, shapely
#     (cv2 and skimage are only used for the contour trace; shapely builds the
#      mitred stroke band)
#   - Factorio data with base/graphics/icons (FACTORIO_DIR below)
#
# Usage
#   tools/generate-icons.sh                 # regenerate in place (repo root)
#   OUT_ROOT=/tmp/icons tools/generate-icons.sh   # write to another tree
#   tools/generate-icons.sh --preview       # also write a contact sheet to /tmp
#
# Every output is overwritten; the script keeps no state between runs and only
# writes into $WORK_DIR (a fresh temp dir, removed on exit) and $OUT_ROOT.
#
# Notes
#   - Output paths are relative to $OUT_ROOT, which defaults to the repo root,
#     so the script can be invoked from any working directory.
#   - The contour trace is deterministic for a given Factorio data file, but
#     cv2/skimage releases may shift DP vertices by a fraction of a pixel. Set
#     CONTOUR to pin the silhouette (space-separated "x,y" pairs, 64 px frame
#     coordinates) for byte-exact, library-independent output; the set that
#     ships in this repo is the default value below.
#   - The shortcut glyph is deliberately abstract (a dashed square and arrow,
#     like the vanilla upgrade planner) and the x24 version is redrawn on the
#     24 px grid instead of downscaled.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# configuration
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FACTORIO_DIR="${FACTORIO_DIR:-/opt/factorio_space_age_21}"
BASE_ICONS="${BASE_ICONS:-$FACTORIO_DIR/data/base/graphics/icons}"
CONCRETE="${CONCRETE:-$BASE_ICONS/refined-concrete.png}"
PLANNER="${PLANNER:-$BASE_ICONS/upgrade-planner.png}"

PHOTOCRAFT="${PHOTOCRAFT:-photocraft-cli}"
OUT_ROOT="${OUT_ROOT:-$REPO_ROOT}"

# --- geometry tunables (64 px authoring space) -----------------------------
# Pinned silhouette (the committed icon set). Empty = trace the source afresh.
DEFAULT_CONTOUR="15.0,59.29 13.71,58.0 3.63,35.0 3.89,14.0 12.0,11.45 14.36,7.0 23.0,4.69 35.0,2.44 38.0,5.4 48.46,4.0 50.0,6.2 59.56,28.0 59.4,49.0 58.0,49.98 51.0,51.79 49.79,55.0 47.0,56.33 29.0,60.31 27.36,60.0 25.0,57.6"
CONTOUR="${CONTOUR:-$DEFAULT_CONTOUR}"
SIGMA="${SIGMA:-0.9}"             # gaussian pre-blur before tracing
DP_EPS="${DP_EPS:-0.45}"          # Douglas-Peucker tolerance, 64 px outline
INK_SPAN="${INK_SPAN:-58}"        # visible ink span of the 64 px outline
STROKE="${STROKE:-4}"             # outline stroke width, px
INNER_SCALE="${INNER_SCALE:-0.65}"    # outline scale inside the frame
THUMB_SCALE="${THUMB_SCALE:-1.5}"     # outline scale on the thumbnail

# --- colours ----------------------------------------------------------------
LINE_COLOR="${LINE_COLOR:-#e2e2e2}"       # vanilla line-art grey
LEVELS_WHITE="${LEVELS_WHITE:-204}"       # frame recolour: 255/1.25

# --- misc -------------------------------------------------------------------
PREVIEW=0
PREVIEW_OUT="${PREVIEW_OUT:-/tmp/opencode/icon-preview.png}"
if [[ "${1:-}" == "--preview" ]]; then
    PREVIEW=1
elif [[ $# -gt 0 ]]; then
    echo "usage: $0 [--preview]" >&2
    exit 2
fi

# scratch space: fresh every run unless the caller pins WORK_DIR
if [[ -n "${WORK_DIR:-}" ]]; then
    mkdir -p "$WORK_DIR"
    CLEANUP_WORK=0
else
    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gen-icons.XXXXXX")"
    CLEANUP_WORK=1
fi
cleanup() { if (( CLEANUP_WORK )); then rm -rf "$WORK_DIR"; fi; }
trap cleanup EXIT
mkdir -p "$WORK_DIR/out"

for f in "$CONCRETE" "$PLANNER"; do
    [[ -r "$f" ]] || { echo "error: missing source icon: $f" >&2; exit 1; }
done
command -v "$PHOTOCRAFT" >/dev/null || {
    echo "error: photocraft-cli not found (set PHOTOCRAFT=...)" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 not found" >&2; exit 1; }
if ! python3 - <<'PY'
import sys
missing = []
for mod in ("numpy", "PIL", "scipy", "skimage", "cv2", "shapely"):
    try:
        __import__(mod)
    except ImportError:
        missing.append(mod)
if missing:
    sys.stderr.write("error: missing python modules: " + ", ".join(missing) + "\n")
    sys.stderr.write("       pip install numpy Pillow scipy scikit-image "
                     "opencv-python-headless shapely\n")
    sys.exit(1)
PY
then
    exit 1
fi

echo "sources : $BASE_ICONS"
echo "output  : $OUT_ROOT"
echo "work    : $WORK_DIR"

# ---------------------------------------------------------------------------
# 1. geometry -> photocraft path payloads
# ---------------------------------------------------------------------------
CONCRETE="$CONCRETE" WORK_DIR="$WORK_DIR" CONTOUR="$CONTOUR" \
SIGMA="$SIGMA" DP_EPS="$DP_EPS" \
INK_SPAN="$INK_SPAN" STROKE="$STROKE" \
INNER_SCALE="$INNER_SCALE" THUMB_SCALE="$THUMB_SCALE" \
python3 - <<'PY'
import json, os

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage
from shapely.geometry import Polygon
from skimage import measure

OUT = os.environ["WORK_DIR"]
SRC = os.environ["CONCRETE"]
SIGMA = float(os.environ["SIGMA"])
DP_EPS = float(os.environ["DP_EPS"])
INK_SPAN = float(os.environ["INK_SPAN"])
STROKE = float(os.environ["STROKE"])
INNER = float(os.environ["INNER_SCALE"])
THUMB = float(os.environ["THUMB_SCALE"])

CANVAS = 64.0
CENTER = CANVAS / 2.0
ARROW64 = 64.0 / 56.0          # vanilla line art is authored at 56 px
ARROW_BIAS = 2.5               # px above centre in the vanilla 56 px art


# --- silhouette ------------------------------------------------------------
def trace(path, sigma, eps):
    """50 % alpha contour of frame 0, simplified with Douglas-Peucker."""
    alpha = np.array(Image.open(path).convert("RGBA"))[0:64, 0:64, 3] / 255.0
    smooth = ndimage.gaussian_filter(alpha, sigma)
    contour = max(measure.find_contours(smooth, 0.5), key=len)
    pts = np.stack([contour[:, 1], contour[:, 0]], axis=1).astype(np.float32)
    ap = cv2.approxPolyDP(pts.reshape(-1, 1, 2), eps, True).reshape(-1, 2)
    return [tuple(p) for p in ap.astype(float)]


def fit(points, ink_span=INK_SPAN, stroke=STROKE):
    """Uniform scale so the stroked ink is `ink_span` tall, centred."""
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    s = (ink_span - stroke) / (max(ys) - min(ys))
    cx = (min(xs) + max(xs)) / 2.0
    cy = (min(ys) + max(ys)) / 2.0
    return [(CENTER + (x - cx) * s, CENTER + (y - cy) * s) for x, y in points], s


def ring(points, half):
    """Solid stroke band as polygons: mitred buffers, outer minus inner."""
    poly = Polygon(points)
    if not poly.is_valid:
        poly = poly.buffer(0)
    band = poly.buffer(half, join_style=2, mitre_limit=6.0).difference(
        poly.buffer(-half, join_style=2, mitre_limit=6.0))
    return [g for g in getattr(band, "geoms", [band]) if not g.is_empty]


def subpaths(geoms):
    """Exterior loops union, interior loops subtract (ring with a hole)."""
    out = []
    for g in geoms:
        loops = [g.exterior] + list(g.interiors)
        out.append({"closed": True, "op": "combine",
                    "knots": [[round(x, 3), round(y, 3)]
                              for x, y in list(loops[0].coords)[:-1]]})
        for r in loops[1:]:
            out.append({"closed": True, "op": "subtract",
                        "knots": [[round(x, 3), round(y, 3)]
                                  for x, y in list(r.coords)[:-1]]})
    return out


def arrow(scale=1.0):
    """Vanilla up arrow (new-upgrade-planner-x56.png) at 64 px scale."""
    src = [(28.0, 15.2), (38.3, 26.6), (34.0, 26.6), (34.0, 36.0),
           (22.0, 36.0), (22.0, 26.6), (17.7, 26.6)]
    a = ARROW64 * scale
    bias = ARROW_BIAS * ARROW64 * scale
    return [(CENTER + (x - 28.0) * a, CENTER - bias + (y - 25.5) * a)
            for x, y in src]


def small_arrow():
    """Vanilla-style arrow for the 24 px shortcut grid."""
    return [(12.0, 6.0), (17.0, 11.0), (14.0, 11.0), (14.0, 18.0),
            (10.0, 18.0), (10.0, 11.0), (7.0, 11.0)]


def dashed_square(canvas, thickness, dash, period):
    """Dashed border strips on the canvas edge, like the vanilla shortcut."""
    subs = []
    start = 0.0
    while start < canvas:
        end = min(start + dash, canvas)
        subs += [
            rect(start, 0, end, thickness),
            rect(start, canvas - thickness, end, canvas),
            rect(0, start, thickness, end),
            rect(canvas - thickness, start, canvas, end),
        ]
        start += period
    return subs


def arrow_sub(points, op="combine"):
    return {"closed": True, "op": op,
            "knots": [[round(x, 3), round(y, 3)] for x, y in points]}


def rect(x0, y0, x1, y1, op="combine"):
    return {"closed": True, "op": op,
            "knots": [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]}


def write(name, subs):
    with open(os.path.join(OUT, name), "w") as fh:
        json.dump({"name": "work", "path": {"subpaths": subs,
                                            "fillRule": "nonzero",
                                            "inverted": False}}, fh)


def scale_about(points, s, cx, cy):
    return [(cx + (x - cx) * s, cy + (y - cy) * s) for x, y in points]


# --- build the payloads ----------------------------------------------------
pin = os.environ.get("CONTOUR", "").strip()
if pin:
    contour = [tuple(float(v) for v in p.split(",")) for p in pin.split()]
else:
    contour = trace(SRC, SIGMA, DP_EPS)
poly64, scale = fit(contour)
print(f"silhouette: {len(poly64)} vertices, scale {scale:.5f}")
xs = [p[0] for p in poly64]
ys = [p[1] for p in poly64]
print(f"  ink bbox x {min(xs)-STROKE/2:.2f}..{max(xs)+STROKE/2:.2f} "
      f"y {min(ys)-STROKE/2:.2f}..{max(ys)+STROKE/2:.2f}")

# 64 px outline
write("ring-64.json", subpaths(ring(poly64, STROKE / 2.0)))
write("arrow-64.json", [arrow_sub(arrow())])

# item icon: the same art scaled down inside the planner frame
p_inner = scale_about(poly64, INNER, CENTER, CENTER)
write("ring-inner.json", subpaths(ring(p_inner, STROKE * INNER / 2.0)))
write("arrow-inner.json", [arrow_sub(arrow(INNER))])

# thumbnail: the same art at 1.5, on the 144 px thumbnail canvas
THUMB_CANVAS = 144.0
TC = THUMB_CANVAS / 2.0
p_thumb = [(TC + (x - CENTER) * THUMB, TC + (y - CENTER) * THUMB) for x, y in poly64]
write("ring-thumb.json", subpaths(ring(p_thumb, STROKE * THUMB / 2.0)))
write("arrow-thumb.json",
      [arrow_sub([(TC + (x - CENTER) * THUMB, TC + (y - CENTER) * THUMB)
                  for x, y in arrow()])])

# shortcut icons: abstract vanilla-style dashed square + arrow (no concrete)
write("shortcut-64.json", dashed_square(64, 4, 10, 18) + [arrow_sub(arrow())])
write("shortcut-24.json", dashed_square(24, 3, 6, 9) + [arrow_sub(small_arrow())])
PY

# ---------------------------------------------------------------------------
# 2. raster work (photocraft-cli)
# ---------------------------------------------------------------------------
SKETCH="$WORK_DIR/out"

# photocraft prints a JSON result per command; keep that out of the way
pc() { "$PHOTOCRAFT" "$@" >/dev/null; }
FILL="{\"name\":\"work\",\"color\":\"$LINE_COLOR\",\"antiAlias\":true}"

# 2a. outline (transparent background, solid band + arrow)
pc run --new "{\"width\":64,\"height\":64,\"background\":\"transparent\",\"name\":\"outline\"}" \
    --cmd path.set  --params "$(cat "$WORK_DIR/ring-64.json")" \
    --cmd path.fill --params "$FILL" \
    --cmd path.set  --params "$(cat "$WORK_DIR/arrow-64.json")" \
    --cmd path.fill --params "$FILL" \
    --out "$SKETCH/outline.png"

# 2b. frame: vanilla frame 0, one levels transfer to a lighter green
pc run "$PLANNER" \
    --cmd image.crop --params '{"x":0,"y":0,"width":64,"height":64}' \
    --cmd image.adjustments.levels --params "{\"inWhite\":$LEVELS_WHITE}" \
    --out "$SKETCH/frame.png"

# 2c. item icon: frame + outline at INNER_SCALE
pc run "$SKETCH/frame.png" \
    --cmd path.set  --params "$(cat "$WORK_DIR/ring-inner.json")" \
    --cmd path.fill --params "$FILL" \
    --cmd path.set  --params "$(cat "$WORK_DIR/arrow-inner.json")" \
    --cmd path.fill --params "$FILL" \
    --out "$SKETCH/item.png"

# 2d. x64 shortcut: abstract dashed square + arrow, like the vanilla shortcut
pc run --new '{"width":64,"height":64,"background":"transparent","name":"shortcut"}' \
    --cmd path.set  --params "$(cat "$WORK_DIR/shortcut-64.json")" \
    --cmd path.fill --params "$FILL" \
    --out "$SKETCH/shortcut64.png"

# 2e. x24 shortcut: same abstract glyph on the 24 px grid
pc run --new '{"width":24,"height":24,"background":"transparent","name":"shortcut"}' \
    --cmd path.set  --params "$(cat "$WORK_DIR/shortcut-24.json")" \
    --cmd path.fill --params "$FILL" \
    --out "$SKETCH/shortcut24.png"

# 2f. x24 disabled: white line art
pc run --new '{"width":24,"height":24,"background":"transparent","name":"shortcut-white"}' \
    --cmd path.set  --params "$(cat "$WORK_DIR/shortcut-24.json")" \
    --cmd path.fill --params '{"name":"work","color":"#ffffff","antiAlias":true}' \
    --out "$SKETCH/shortcut24-white.png"

# 2g. thumbnail: frame upscaled to 144 (nearest keeps the dashes crisp) + 1.5x art
pc run "$PLANNER" \
    --cmd image.crop --params '{"x":0,"y":0,"width":64,"height":64,"targetWidth":144,"targetHeight":144,"resample":"nearest"}' \
    --cmd image.adjustments.levels --params "{\"inWhite\":$LEVELS_WHITE}" \
    --out "$SKETCH/frame144.png"
pc run "$SKETCH/frame144.png" \
    --cmd path.set  --params "$(cat "$WORK_DIR/ring-thumb.json")" \
    --cmd path.fill --params "$FILL" \
    --cmd path.set  --params "$(cat "$WORK_DIR/arrow-thumb.json")" \
    --cmd path.fill --params "$FILL" \
    --out "$SKETCH/thumbnail.png"

# ---------------------------------------------------------------------------
# 3. publish (force RGBA, write relative to $OUT_ROOT)
# ---------------------------------------------------------------------------
SKETCH="$SKETCH" OUT_ROOT="$OUT_ROOT" python3 - <<'PY'
import os
from PIL import Image

sketch = os.environ["SKETCH"]
root = os.environ["OUT_ROOT"]
targets = [
    ("outline.png",   "graphics/icons/tile-upgrade-planner-outline.png"),
    ("frame.png",     "graphics/icons/tile-upgrade-planner-frame.png"),
    ("item.png",      "graphics/icons/tile-upgrade-planner-item.png"),
    ("shortcut64.png", "graphics/icons/shortcut-toolbar/tile-upgrade-planner-x64.png"),
    ("shortcut24.png", "graphics/icons/shortcut-toolbar/tile-upgrade-planner-x24.png"),
    ("shortcut24-white.png", "graphics/icons/shortcut-toolbar/tile-upgrade-planner-x24-white.png"),
    ("thumbnail.png", "thumbnail.png"),
]
for src, dst in targets:
    path = os.path.join(root, dst)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    im = Image.open(os.path.join(sketch, src)).convert("RGBA")
    im.save(path)
    print(f"  {dst}  {im.size[0]}x{im.size[1]}")
PY

# ---------------------------------------------------------------------------
# 4. optional contact sheet (never written into the repo)
# ---------------------------------------------------------------------------
if (( PREVIEW )); then
    OUT_ROOT="$OUT_ROOT" PREVIEW_OUT="$PREVIEW_OUT" python3 - <<'PY'
import os
from PIL import Image, ImageDraw, ImageFont

root = os.environ["OUT_ROOT"]
dest = os.environ["PREVIEW_OUT"]
os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)

try:
    bold = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
except Exception:
    bold = small = ImageFont.load_default()

row1 = [("graphics/icons/tile-upgrade-planner-outline.png", "outline.png   64x64   @8x", 8),
        ("graphics/icons/tile-upgrade-planner-frame.png", "frame.png   64x64   @8x", 8),
        ("graphics/icons/tile-upgrade-planner-item.png", "item.png   64x64   @8x", 8),
        ("graphics/icons/shortcut-toolbar/tile-upgrade-planner-x64.png", "shortcut x64   64x64   @8x", 8)]
row2 = [("graphics/icons/shortcut-toolbar/tile-upgrade-planner-x24.png", "shortcut x24   24x24   @12x", 12),
        ("graphics/icons/shortcut-toolbar/tile-upgrade-planner-x24-white.png", "x24-white   24x24   @12x", 12),
        ("thumbnail.png", "thumbnail.png   144x144   @2x", 2)]

bg, pad, labelh = (47, 47, 52, 255), 26, 40
gaps = (34, 120)

def dims(row):
    out = []
    for path, _, s in row:
        w, h = Image.open(os.path.join(root, path)).size
        out.append((w * s, h * s))
    return out

d1, d2 = dims(row1), dims(row2)
width = pad * 2 + max(sum(w for w, _ in d1) + gaps[0] * (len(d1) - 1),
                     sum(w for w, _ in d2) + gaps[1] * (len(d2) - 1))
y1 = pad + 30 + labelh
y2 = y1 + max(h for _, h in d1) + 90
height = y2 + labelh + max(h for _, h in d2) + 40

sheet = Image.new("RGBA", (width, height), bg)
draw = ImageDraw.Draw(sheet)
draw.text((pad, 18), "tile-upgrade-planner-muluna  |  icon set  |  nearest-neighbour preview",
          font=small, fill=(196, 196, 204, 255))

def row(items, sizes, y, gap):
    x = pad
    for (path, label, _), (w, h) in zip(items, sizes):
        im = Image.open(os.path.join(root, path)).convert("RGBA")
        draw.rectangle([x - 3, y - 3, x + w + 2, y + h + 2], outline=(74, 74, 80, 255))
        sheet.alpha_composite(im.resize((w, h), Image.NEAREST), (x, y))
        draw.text((x, y - labelh + 8), label, font=bold, fill=(234, 234, 238, 255))
        draw.text((x, y + h + 10), f"{im.size[0]}x{im.size[1]} px  ->  {w}x{h}",
                  font=small, fill=(160, 160, 168, 255))
        x += w + gap

row(row1, d1, y1, gaps[0])
row(row2, d2, y2, gaps[1])
sheet.convert("RGB").save(dest)
print(f"  preview -> {dest}")
PY
fi

echo "done."
