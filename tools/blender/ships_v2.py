"""Sort the Shipment ships, second generation (1.12).

blender -b --python tools/blender/ships_v2.py

Same gameplay contract as before: length along X (stern -X, bow +X), beam
along Z, cargo deck at y=0.95 with the three slots at x = -1.15, -0.05, 1.05,
bridge aft. Materials the game tints: Hull, Funnel, Deck; Glass stays glossy;
everything else is folded into vertex colours with baked AO by
solstice_models.finish().

What changed: a lofted hull with a raked stem, flared bow, sheer rising to a
forecastle with a bulwark, a cruiser-like stern and a proper boot-top; and
three distinct, better proportioned bridges with raked windows, bridge wings,
radar masts, lifeboats and railings.
"""
import math
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lib  # noqa: E402
import premium_models as P  # noqa: E402
import solstice_models as S  # noqa: E402

B, C, E = S.roundbox, P.C, P.E
DECK = 0.95
P.PALETTE.update({
    'Cream': (246, 238, 222), 'Navy': (36, 58, 76), 'Teal': (52, 120, 136),
    'Coral': (255, 122, 72), 'Gold': (225, 186, 92), 'Rubber': (44, 50, 58),
    'HullWhite': (250, 246, 236), 'BootTop': (33, 48, 62), 'Bottom': (176, 64, 56),
    'Steel': (150, 162, 172), 'Wood': (196, 158, 112), 'Glint': (150, 214, 222),
    'DeckGrey': (126, 142, 150),
})


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ hull

STERN_DECK, BOW_DECK = -2.66, 2.62


def sheer(x):
    """Deck edge height: flat over the cargo slots, rising to the forecastle."""
    return DECK + 0.05 * smooth(-1.9, -2.66, x) + 0.22 * smooth(1.58, 2.62, x) ** 1.4


def ends(y):
    """Stern and bow x at height y: raked stem, overhanging cruiser stern."""
    k = min(1.0, max(0.0, (y + 0.64) / 1.62))
    stern = -2.42 + (STERN_DECK + 2.42) * k ** 0.7
    bow = 2.22 + (BOW_DECK - 2.22) * k ** 0.85
    return stern, bow


def plan(u, y):
    """Half-breadth fraction along the hull (u: 0 stern .. 1 bow) at height y."""
    hi = min(1.0, max(0.0, (y + 0.2) / 1.2))          # flare: upper sections fuller at the bow
    if u < 0.14:
        f = 0.80 + 0.20 * math.sqrt(u / 0.14)
    elif u < 0.60:
        f = 1.0
    else:
        t = (u - 0.60) / 0.40
        f = (1.0 - t ** (1.7 + 0.5 * hi)) ** (0.75 - 0.2 * hi)
    return max(0.02, f)


def bilge(y):
    """Midship section: round bilge below the waterline."""
    if y >= -0.05:
        return 1.0
    t = (y + 0.64) / 0.59
    return 0.62 + 0.38 * math.sin(t * math.pi / 2) ** 0.6


def hull(kind):
    half = 1.19 if kind != 1 else 1.21
    rows = [-0.64, -0.55, -0.42, -0.26, -0.03, 0.08, 0.36, 'ws', 'deck', 'bulw']
    nst = 26
    us = [0.5 - 0.5 * math.cos(math.pi * i / (nst - 1)) for i in range(nst)]   # denser at the ends
    grid = []   # grid[row][station] = (x, y, halfwidth)
    for r in rows:
        line = []
        for u in us:
            yy = r if isinstance(r, float) else 0.9
            st, bw = ends(yy if isinstance(r, float) else 0.95)
            x = st + (bw - st) * u
            if r == 'ws':
                y = sheer(x) - 0.17
            elif r == 'deck':
                y = sheer(x)
            elif r == 'bulw':
                y = sheer(x) + 0.13 * smooth(1.5, 1.95, x) + 0.05 * smooth(-1.95, -2.4, x) + 0.012
            else:
                y = r
            w = half * plan(u, y) * bilge(y)
            if r in ('deck', 'bulw'):
                w = half * plan(u, 0.9)
            line.append((x, y, w))
        grid.append(line)
    verts, faces, mats = [], [], []

    def vid(ri, si, side):
        return (ri * nst + si) * 2 + (0 if side < 0 else 1)
    for line in grid:
        for (x, y, w) in line:
            verts.append((x, y, -w))
            verts.append((x, y, w))

    def band(y):
        if y < -0.03:
            return 'Bottom'
        if y < 0.08:
            return 'BootTop'
        return 'Hull'
    for ri in range(len(rows) - 1):
        for side in (-1, 1):
            for si in range(nst - 1):
                ymid = (grid[ri][si][1] + grid[ri + 1][si][1]) / 2
                m = band(ymid)
                if rows[ri] in ('ws', 'deck'):
                    m = 'HullWhite'
                faces.append([vid(ri, si, side), vid(ri, si + 1, side), vid(ri + 1, si + 1, side), vid(ri + 1, si, side)])
                mats.append(m)
        # stern transom: close between the two sides
        faces.append([vid(ri, 0, -1), vid(ri, 0, 1), vid(ri + 1, 0, 1), vid(ri + 1, 0, -1)])
        mats.append('HullWhite' if rows[ri] in ('ws', 'deck') else band((grid[ri][0][1] + grid[ri + 1][0][1]) / 2))
    # keel flat
    for si in range(nst - 1):
        faces.append([vid(0, si, -1), vid(0, si + 1, -1), vid(0, si + 1, 1), vid(0, si, 1)])
        mats.append('Bottom')
    parts = []
    hull_verts = list(verts)
    for m in set(mats):
        fs = [f for f, mm in zip(faces, mats) if mm == m]

        def want(c, m=m):
            if m == 'Bottom' and c[1] < -0.6:
                return (0, -1, 0)
            return (c[0] * 0.06, (c[1] - 0.2) * 0.12, c[2])
        parts.append(lib.mesh_from(hull_verts, fs, m, 'hull_v2', outward=want))

    # bulwark: inner face and capping rail, deck plate inside it
    ins = 0.05
    dv, df = [], []
    di, deck_top = 'deck', len(rows) - 2
    for si, (x, y, w) in enumerate(grid[deck_top]):
        bx, by, bwid = grid[-1][si]
        dv += [(x, y, -(w - ins)), (x, y, w - ins), (bx, by, -(bwid - ins)), (bx, by, bwid - ins)]
    for si in range(nst - 1):
        a, b = si * 4, (si + 1) * 4
        df.append([a, a + 1, b + 1, b])                       # deck plate
    dv_in = []
    parts.append(lib.mesh_from(dv, df, 'DeckGrey', 'deck_plate', outward=lambda c: (0, 1, 0)))
    iv, inf, cv, cf = [], [], [], []
    for side in (-1, 1):
        base = len(iv)
        for si in range(nst):
            x, y, w = grid[deck_top][si]
            bx, by, bwid = grid[-1][si]
            iv += [(x, y, side * (w - ins)), (bx, by, side * (bwid - ins))]
            cv += [(bx, by, side * (bwid - ins)), (bx, by + 0.025, side * (bwid - ins * 0.5)), (bx, by, side * bwid)]
        for si in range(nst - 1):
            a, b = base + si * 2, base + (si + 1) * 2
            inf.append([a, b, b + 1, a + 1])
        cbase = (len(cv) // 3 - nst) * 3
        for si in range(nst - 1):
            a, b = cbase + si * 3, cbase + (si + 1) * 3
            cf.append([a, b, b + 1, a + 1])
            cf.append([a + 1, b + 1, b + 2, a + 2])
    parts.append(lib.mesh_from(iv, inf, 'HullWhite', 'bulwark_in', outward=lambda c: (0, 0, -c[2])))
    parts.append(lib.mesh_from(cv, cf, 'Cream', 'cap_rail', outward=lambda c: (0, 1, 0)))
    # transom deck strip at the stern end of the deck plate (closes the gap to the bulwark)
    return parts, grid, nst


def hull_details(grid, nst):
    o = []
    deck_row = grid[-2]

    def edge(x):
        best = min(deck_row, key=lambda p: abs(p[0] - x))
        return best
    for s in (-1, 1):
        # rubbing strake along the parallel body
        o.append(B((-0.2, 0.73, s * 1.2), (3.6, 0.07, 0.05), 'Cream', 0.02, 2))
        # hawse pipe and anchor on the bow flare
        x = 2.05
        _, y, w = edge(x)
        o.append(B((x, y - 0.27, s * (w * 0.83 + 0.02)), (0.2, 0.15, 0.04), 'Rubber', 0.04, 2))
        o.append(B((x - 0.02, y - 0.40, s * (w * 0.83 + 0.04)), (0.05, 0.22, 0.03), 'Navy', 0.01, 1))
        o.append(B((x - 0.02, y - 0.50, s * (w * 0.83 + 0.04)), (0.16, 0.05, 0.03), 'Navy', 0.015, 1))
        # draft marks fore and aft
        for xm in (2.18, -2.32):
            _, _, wm = edge(xm)
            for k in range(4):
                o.append(B((xm, -0.02 + k * 0.12, s * (wm * 0.86 + 0.012)), (0.045, 0.02, 0.012), 'HullWhite'))
        # fenders hanging on the side
        for xf in (-1.45, 0.5):
            o.append(C((xf, 0.42, s * 1.215), 0.075, 0.32, 'Rubber', 10))
        # bollards on the forecastle and aft deck
        for xb in (1.9, -1.88):
            _, yb, wb = edge(xb)
            for dz in (0, 0.13):
                o.append(C((xb + dz, yb + 0.06, s * (wb - 0.22)), 0.035, 0.12, 'Navy', 8))
    # windlass and foremast on the forecastle
    _, yf, _ = edge(2.15)
    o.append(B((2.05, yf + 0.06, 0), (0.28, 0.12, 0.62), 'Navy', 0.03, 2))
    for s in (-1, 1):
        o.append(C((2.05, yf + 0.08, s * 0.36), 0.08, 0.1, 'Steel', 12, 'z'))
    o.append(C((2.38, yf + 0.55, 0), 0.025, 1.0, 'Cream', 8))
    o.append(B((2.38, yf + 0.86, 0), (0.05, 0.03, 0.34), 'Cream', 0.01, 1))
    o.append(P.blob((2.38, yf + 1.07, 0), (0.035, 0.04, 0.035), 'Gold', 1))
    # hatch covers, one per slot: navy coaming with the tinted cover on top
    # (the tinted cover is the colour cue the game relies on)
    for x in (-1.15, -0.05, 1.05):
        o.append(B((x, DECK + 0.023, 0), (1.06, 0.045, 1.98), 'Navy', 0.017, 2))
        o.append(B((x, DECK + 0.044, 0), (1.0, 0.012, 1.89), 'Deck', 0.005, 1))
        for dz in (-0.47, 0.47):
            o.append(B((x, DECK + 0.051, dz), (0.98, 0.006, 0.02), 'Navy'))
    return o


def railing(a, b, h, posts, mat='Cream'):
    """Posts and two rails from a to b (Godot space, at deck height)."""
    o = []
    for i in range(posts + 1):
        t = i / posts
        p = tuple(a[k] + (b[k] - a[k]) * t for k in range(3))
        o.append(C((p[0], p[1] + h / 2, p[2]), 0.012, h, mat, 5))
    for yy in (h, h * 0.5):
        o.append(E((a[0], a[1] + yy, a[2]), (b[0], b[1] + yy, b[2]), 0.018, mat))
    return o


def lifeboat(c, length=0.62, mat='Coral'):
    o = [P.blob(c, (length / 2, 0.15, 0.13), mat, 2)]
    o.append(B((c[0], c[1] + 0.1, c[2]), (length * 0.42, 0.08, 0.14), 'Cream', 0.03, 2))
    return o


def bridge_block(x0, x1, y0, h, half_w, rake=0.0, glass_band=None, mat='Cream'):
    """A deck house tier from x0 (aft) to x1 (fore); optional raked front."""
    o = [B(((x0 + x1) / 2, y0 + h / 2, 0), (x1 - x0, h, half_w * 2), mat, 0.06, 3)]
    if glass_band:
        gy, gh = glass_band
        # wraparound glazing: front and both sides, set slightly proud
        o.append(B((x1 + 0.006, y0 + gy, 0), (0.03, gh, half_w * 2 - 0.12), 'Glass', 0.012, 2))
        for s in (-1, 1):
            o.append(B(((x0 + x1) / 2 + 0.04, y0 + gy, s * (half_w + 0.006)), (x1 - x0 - 0.2, gh, 0.03), 'Glass', 0.012, 2))
            # mullions
            n = max(2, int((x1 - x0) / 0.16))
            for k in range(n + 1):
                xm = x0 + 0.12 + (x1 - x0 - 0.2) * k / n
                o.append(B((xm, y0 + gy, s * (half_w + 0.02)), (0.018, gh + 0.01, 0.012), mat))
        nz = max(3, int(half_w * 2 / 0.2))
        for k in range(nz + 1):
            zm = -half_w + 0.06 + (half_w * 2 - 0.12) * k / nz
            o.append(B((x1 + 0.024, y0 + gy, zm), (0.012, gh + 0.01, 0.018), mat))
    return o


def mast(x, y, z, h):
    o = [C((x, y + h / 2, z), 0.03, h, 'Cream', 8)]
    o.append(E((x - 0.12, y + h * 0.45, z), (x, y + h * 0.75, z), 0.02, 'Cream'))
    o.append(B((x, y + h * 0.78, z), (0.06, 0.05, 0.55), 'Cream', 0.012, 1))
    # radar scanner and its pedestal
    o.append(B((x + 0.04, y + h + 0.06, z), (0.07, 0.06, 0.07), 'Navy', 0.015, 1))
    o.append(B((x + 0.04, y + h + 0.11, z), (0.1, 0.03, 0.62), 'Cream', 0.012, 1))
    o.append(P.blob((x, y + h + 0.02, z + 0.2), (0.04, 0.045, 0.04), 'Gold', 1))
    return o


def funnel(x, y, z, h, w, d, kind):
    o = []
    if kind == 'twin':
        for dz in (-0.28, 0.28):
            o.append(C((x, y + h / 2, z + dz), w, h, 'Funnel', 18, 'y', w * 0.92))
            o.append(C((x, y + h - 0.05, z + dz), w * 0.95, 0.1, 'Navy', 18))
            o.append(C((x, y + h - 0.22, z + dz), w * 0.96, 0.07, 'Cream', 18))
        return o
    # tapered, raked funnel with a black top, white band and an emblem disc
    o.append(B((x, y + h / 2, z), (w, h, d), 'Funnel', min(w, d) * 0.3, 4))
    o.append(B((x - 0.01, y + h - 0.06, z), (w + 0.02, 0.12, d + 0.02), 'Navy', 0.04, 3))
    o.append(B((x, y + h - 0.27, z), (w + 0.015, 0.08, d + 0.015), 'Cream', 0.03, 3))
    for s in (-1, 1):
        o.append(C((x, y + h * 0.48, z + s * (d / 2 + 0.006)), 0.1, 0.012, 'Cream', 16, 'z'))
        o.append(C((x, y + h * 0.48, z + s * (d / 2 + 0.014)), 0.06, 0.008, 'Funnel', 16, 'z'))
    # exhaust pipes
    for dz in (-0.06, 0.06):
        o.append(C((x + 0.02, y + h + 0.05, z + dz), 0.025, 0.12, 'Navy', 8))
    return o


def superstructure(kind):
    """kind 0 feeder: tall modern bridge; 1 tanker: low and long with twin
    funnels; 2 coaster: classic rounded wheelhouse with a tall funnel."""
    o = []
    hw = 1.0
    x_aft = -2.6
    if kind == 0:
        tiers = [(-2.58, -1.78, DECK, 0.5), (-2.52, -1.82, DECK + 0.5, 0.42), (-2.45, -1.86, DECK + 0.92, 0.42)]
        for i, (a, b, y0, h) in enumerate(tiers):
            o += bridge_block(a, b, y0, h, hw - i * 0.06, glass_band=(h * 0.55, 0.13))
            o += railing((a + 0.05, y0 + h, -(hw - i * 0.06) + 0.03), (b - 0.05, y0 + h, -(hw - i * 0.06) + 0.03), 0.14, 5)
            o += railing((a + 0.05, y0 + h, (hw - i * 0.06) - 0.03), (b - 0.05, y0 + h, (hw - i * 0.06) - 0.03), 0.14, 5)
        # navigating bridge: raked front glass and wings out to the ship's side
        by = DECK + 1.34
        o.append(B((-2.12, by + 0.22, 0), (0.62, 0.44, 2.0), 'Cream', 0.07, 3))
        o.append(B((-1.80, by + 0.27, 0), (0.06, 0.2, 1.86), 'Glass', 0.02, 2))
        for s in (-1, 1):
            o.append(B((-2.08, by + 0.27, s * 1.004), (0.48, 0.2, 0.03), 'Glass', 0.012, 2))
            o.append(B((-1.98, by + 0.06, s * 1.14), (0.32, 0.04, 0.3), 'Cream', 0.015, 1))      # wing deck
            o += railing((-2.12, by + 0.08, s * 1.27), (-1.84, by + 0.08, s * 1.27), 0.12, 2)
        for k in range(8):
            o.append(B((-1.775, by + 0.27, -0.88 + k * 0.25), (0.012, 0.21, 0.018), 'Cream'))
        o.append(B((-2.12, by + 0.47, 0), (0.7, 0.05, 2.08), 'Teal', 0.02, 2))            # sun visor roof
        o += mast(-2.25, by + 0.5, 0.0, 0.62)
        o += funnel(-2.47, DECK + 1.3, 0.0, 1.1, 0.36, 0.5, 'single')
        for s in (-1, 1):
            o += lifeboat((-2.22, DECK + 0.98, s * 1.08))
            o.append(E((-2.42, DECK + 0.84, s * 1.0), (-2.38, DECK + 1.12, s * 1.12), 0.03, 'Steel'))
            o.append(E((-2.02, DECK + 0.84, s * 1.0), (-2.06, DECK + 1.12, s * 1.12), 0.03, 'Steel'))
    elif kind == 1:
        tiers = [(-2.6, -1.72, DECK, 0.46), (-2.54, -1.78, DECK + 0.46, 0.4)]
        for i, (a, b, y0, h) in enumerate(tiers):
            o += bridge_block(a, b, y0, h, hw + 0.04 - i * 0.05, glass_band=(h * 0.55, 0.12))
        by = DECK + 0.86
        o.append(B((-2.0, by + 0.21, 0), (0.6, 0.42, 1.9), 'Cream', 0.07, 3))
        o.append(B((-1.69, by + 0.25, 0), (0.05, 0.18, 1.78), 'Glass', 0.02, 2))
        for s in (-1, 1):
            o.append(B((-1.96, by + 0.25, s * 0.955), (0.46, 0.18, 0.03), 'Glass', 0.012, 2))
            o.append(B((-1.86, by + 0.05, s * 1.12), (0.3, 0.04, 0.36), 'Cream', 0.015, 1))
            o += railing((-2.0, by + 0.07, s * 1.28), (-1.72, by + 0.07, s * 1.28), 0.12, 2)
            o += lifeboat((-2.4, DECK + 0.62, s * 1.12), 0.55)
        for k in range(8):
            o.append(B((-1.665, by + 0.25, -0.84 + k * 0.24), (0.012, 0.19, 0.018), 'Cream'))
        o.append(B((-2.0, by + 0.44, 0), (0.68, 0.05, 1.98), 'Teal', 0.02, 2))
        o += mast(-2.1, by + 0.46, 0.0, 0.55)
        o += funnel(-2.45, DECK + 0.86, 0.0, 1.35, 0.12, 0, 'twin')
        # pipe rack along the deck edge -- a tanker cue
        for s in (-1, 1):
            o.append(C((-0.1, DECK + 0.1, s * 1.02), 0.026, 3.3, 'Gold', 8, 'x'))
            o.append(C((-0.1, DECK + 0.16, s * 1.06), 0.018, 3.3, 'Steel', 6, 'x'))
    else:
        # classic coaster: rounded wheelhouse, tall raked funnel, short mast forward of the bridge
        o += bridge_block(-2.62, -1.76, DECK, 0.56, hw, glass_band=(0.3, 0.13))
        by = DECK + 0.56
        o.append(B((-2.06, by + 0.26, 0), (0.7, 0.52, 1.64), 'Cream', 0.22, 5))       # rounded front
        o.append(B((-1.74, by + 0.3, 0), (0.08, 0.2, 1.3), 'Glass', 0.04, 3))
        for s in (-1, 1):
            o.append(B((-2.04, by + 0.3, s * 0.83), (0.5, 0.2, 0.03), 'Glass', 0.012, 2))
            o += lifeboat((-2.42, by + 0.08, s * 0.98), 0.5)
        for k in range(6):
            o.append(B((-1.695, by + 0.3, -0.55 + k * 0.22), (0.012, 0.21, 0.018), 'Cream'))
        o.append(B((-2.06, by + 0.54, 0), (0.78, 0.05, 1.72), 'Teal', 0.02, 2))
        o += railing((-2.4, by + 0.56, -0.8), (-1.75, by + 0.56, -0.8), 0.12, 3)
        o += railing((-2.4, by + 0.56, 0.8), (-1.75, by + 0.56, 0.8), 0.12, 3)
        o += mast(-1.98, by + 0.56, -0.5, 0.7)
        o += funnel(-2.44, DECK + 0.95, 0.42, 1.42, 0.4, 0.42, 'single')
        # a stern flag staff
        o.append(C((-2.66, DECK + 0.55, 0), 0.015, 0.7, 'Cream', 6))
    return o


FUNNEL_TOPS = {0: (-2.47, DECK + 2.4, 0.0), 1: (-2.45, DECK + 2.21, 0.28), 2: (-2.44, DECK + 2.37, 0.42)}


def ship(kind):
    lib.reset()
    parts, grid, nst = hull(kind)
    o = parts + hull_details(grid, nst) + superstructure(kind)
    S.finish(o, ['ship_feeder', 'ship_tanker', 'ship_coaster'][kind], keep={'Hull', 'Funnel', 'Deck', 'Glass'}, ao=0.55,
             tint=[(239, 75, 92), (61, 143, 232), (255, 197, 61)][kind])


if __name__ == '__main__':
    P.finish = S.finish
    P.B = S.roundbox
    for k in (0, 1, 2):
        ship(k)
    print('SHIPS_V2', [(r['name'], r['triangles'], r['bounds_min'], r['bounds_max']) for r in S.REPORT], flush=True)
    print('FUNNEL_TOPS', FUNNEL_TOPS, flush=True)
