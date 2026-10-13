#!/usr/bin/env python3
"""Checks every map must pass. Each map generator runs them on what it builds, and you can run
them on the map folders themselves (every map in rotation, or the ones you name):
    python3 tools/mapcheck.py [MapName ...]

  flicker  No two visible faces in the same plane facing the same way where they overlap (that's
           z-fighting: the surfaces flicker as the camera moves), and no surface laid closer
           than MIN_GAP over another (it flickers from a distance). A face is ignored when it's
           buried: right in front of it is something solid and opaque, so no camera can see it.
  windows  Nothing, decoration included, cuts into a window's glass or sits right in front of
           it (parts named "Window", as maplib's walls make them).
  reach    Every walkable area can be reached from the spawns, and you can always get back.
           Areas too small to matter (under MIN_AREA, or with no 4x4 patch to stand in: a ledge,
           a wall top) are skipped, and so are the tops of parts named in the map's OutOfBounds
           attribute (comma-separated: roofs, ceilings, tall furniture).

How players get around, for `reach` (keep in step with Config and the character): walk up
steps of STEP, jump up JUMP_UP, run-and-jump across gaps (jump_reach), drop any height, crouch or
slide under anything CROUCH or more off the floor (SlideBlocker parts don't stop that), climb
Roblox ladders (TrussParts) both ways, ride launch pads (LaunchVelocity) and level swinging
platforms (SwingLevel + Carry) from one end of their swing to the other. Spinning parts count
where they are built. Wall runs and any other route a map needs are passed in as `routes`.
"""
import json
import math
import os
import sys
from collections import defaultdict, deque

MIN_GAP = 0.04  # studs between parallel surfaces facing the same way (less flickers)
STEP = 1.0  # walk up this much without jumping
JUMP_UP = 5.5  # jump onto a ledge this high (the jump peaks at about 7.2)
CROUCH = 3.0  # room you need to crouch or slide through
STAND = 5.0  # room you need standing
ROOT = 3.0  # root part above the feet
GRAVITY = 196.2
JUMP_SPEED = math.sqrt(2 * GRAVITY * 7.2)
RUN = 30.0  # sprint speed
JUMP_MARGIN = 2.5  # studs short of a perfect jump that still counts as reliable
LAUNCH_DRIVE = 0.08  # Config.Gadgets.LaunchDriveTime
MIN_AREA = 24  # studs^2: smaller unreachable spots (the tops of small props) are ignored
CELL = 2.0  # walkable grid spacing

SOLID_CLASSES = {"Part", "WedgePart", "TrussPart", "SpawnLocation", "Seat", "MeshPart",
                 "CornerWedgePart"}


# ---- parts -------------------------------------------------------------------------------------

class Part:
    __slots__ = ("name", "cls", "pos", "rows", "half", "shape", "transparency", "collide",
                 "attrs", "lo", "hi", "material")

    def __init__(self, node):
        p = node.get("properties", {})
        cf = p["CFrame"]["CFrame"]
        self.name = node.get("name", "Part").rstrip("0123456789")
        self.cls = node.get("className", "Part")
        self.pos = cf["position"]
        self.rows = cf.get("orientation", [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
        self.half = [s / 2 for s in p.get("Size", [4, 1, 2])]
        shape = p.get("Shape", "Block")
        self.shape = ("wedge" if self.cls == "WedgePart" else "cylinder" if shape == "Cylinder"
                      else "ball" if shape == "Ball" else "box")
        self.transparency = p.get("Transparency", 0)
        self.collide = p.get("CanCollide", True)
        self.attrs = node.get("attributes") or {}
        self.material = p.get("Material", "Plastic")
        ext = [sum(abs(self.rows[i][j]) * self.half[j] for j in range(3)) for i in range(3)]
        self.lo = [self.pos[i] - ext[i] for i in range(3)]
        self.hi = [self.pos[i] + ext[i] for i in range(3)]

    def axis(self, j):
        return (self.rows[0][j], self.rows[1][j], self.rows[2][j])

    def local(self, point):
        d = [point[i] - self.pos[i] for i in range(3)]
        return [sum(self.rows[i][j] * d[i] for i in range(3)) for j in range(3)]

    def contains(self, point, eps=1e-4):
        if not all(self.lo[i] - eps <= point[i] <= self.hi[i] + eps for i in range(3)):
            return False
        lx, ly, lz = self.local(point)
        hx, hy, hz = self.half
        if self.shape == "ball":
            return lx * lx + ly * ly + lz * lz <= min(self.half) ** 2 + eps
        if abs(lx) > hx + eps:
            return False
        if self.shape == "cylinder":
            r = min(hy, hz)
            return ly * ly + lz * lz <= r * r + eps
        if abs(ly) > hy + eps or abs(lz) > hz + eps:
            return False
        if self.shape == "wedge":
            return (ly + hy) * 2 * hz <= (lz + hz) * 2 * hy + eps
        return True

    @property
    def solid(self):
        """Blocks players (slide gates don't count: you can always crouch through them)."""
        return (self.collide is not False and self.cls in SOLID_CLASSES
                and not self.attrs.get("SlideBlocker") and "SwingPivot" not in self.attrs)

    @property
    def opaque(self):
        return self.transparency <= 0.05 and self.cls in SOLID_CLASSES

    @property
    def visible(self):
        return self.transparency < 0.98 and self.cls in SOLID_CLASSES

    def column(self, x, z):
        """Where the vertical line through (x, z) passes through this part: (bottom, top,
        up-component of the surface normal at the top), or None."""
        if not (self.lo[0] - 1e-6 <= x <= self.hi[0] + 1e-6
                and self.lo[2] - 1e-6 <= z <= self.hi[2] + 1e-6):
            return None
        c = self.pos
        if self.shape == "ball":
            r = min(self.half)
            dd = (x - c[0]) ** 2 + (z - c[2]) ** 2
            if dd > r * r:
                return None
            k = math.sqrt(r * r - dd)
            return (c[1] - k, c[1] + k, k / r if r else 1)
        rows = self.rows
        a = [rows[0][j] * (x - c[0]) - rows[1][j] * c[1] + rows[2][j] * (z - c[2]) for j in range(3)]
        b = [rows[1][j] for j in range(3)]
        lo, hi, top_normal = -math.inf, math.inf, None
        axes = (0,) if self.shape == "cylinder" else (0, 1, 2)
        for j in axes:
            h = self.half[j]
            if abs(b[j]) < 1e-9:
                if abs(a[j]) > h + 1e-6:
                    return None
                continue
            t0, t1 = (-h - a[j]) / b[j], (h - a[j]) / b[j]
            sign = 1 if b[j] > 0 else -1
            if t0 > t1:
                t0, t1 = t1, t0
            if t0 > lo:
                lo = t0
            if t1 < hi:
                hi, top_normal = t1, tuple(sign * v for v in self.axis(j))
        if self.shape == "cylinder":
            r = min(self.half[1], self.half[2])
            qa = b[1] ** 2 + b[2] ** 2
            qb = 2 * (a[1] * b[1] + a[2] * b[2])
            qc = a[1] ** 2 + a[2] ** 2 - r * r
            if qa < 1e-12:
                if qc > 1e-6:
                    return None
            else:
                disc = qb * qb - 4 * qa * qc
                if disc < 0:
                    return None
                s = math.sqrt(disc)
                r0, r1 = (-qb - s) / (2 * qa), (-qb + s) / (2 * qa)
                if r0 > lo:
                    lo = r0
                if r1 < hi:
                    hi = r1
                    ly, lz = a[1] + b[1] * r1, a[2] + b[2] * r1
                    ay, az = self.axis(1), self.axis(2)
                    top_normal = tuple((ay[i] * ly + az[i] * lz) / r for i in range(3))
        if self.shape == "wedge":
            hy, hz = self.half[1], self.half[2]
            fa = (a[1] + hy) * 2 * hz - (a[2] + hz) * 2 * hy
            fb = b[1] * 2 * hz - b[2] * 2 * hy
            if abs(fb) < 1e-9:
                if fa > 1e-6:
                    return None
            elif fb > 0:
                t = -fa / fb
                if t < hi:
                    hi = t
                    n = (0, 2 * hz, -2 * hy)
                    length = math.hypot(n[1], n[2])
                    ay, az = self.axis(1), self.axis(2)
                    top_normal = tuple((ay[i] * n[1] + az[i] * n[2]) / length for i in range(3))
            else:
                lo = max(lo, -fa / fb)
        if hi - lo < 1e-6:
            return None
        return (lo, hi, top_normal[1] if top_normal else 1.0)


class Grid:
    """Parts bucketed by where they are, for fast lookups."""

    def __init__(self, parts, size=8.0):
        self.size = size
        self.cells = defaultdict(list)
        for index, part in enumerate(parts):
            for i in range(int(math.floor(part.lo[0] / size)), int(math.floor(part.hi[0] / size)) + 1):
                for k in range(int(math.floor(part.lo[2] / size)),
                               int(math.floor(part.hi[2] / size)) + 1):
                    self.cells[(i, k)].append(index)

    def near(self, x, z):
        return self.cells.get((int(math.floor(x / self.size)), int(math.floor(z / self.size))), ())


def parts_from_nodes(nodes):
    """Every part in a tree of Rojo model nodes (Folders and Models are walked into)."""
    out = []

    def walk(node):
        cls = node.get("className")
        props = node.get("properties", {})
        if cls in SOLID_CLASSES and "CFrame" in props:
            out.append(Part(node))
        if cls in ("Folder", "Model") or cls is None or cls in SOLID_CLASSES:
            for child in node.get("children", ()):
                walk(child)

    for node in nodes:
        walk(node)
    return out


def load_folder(folder):
    """A map folder from src/maps: its parts, spawn points and attributes."""
    meta = os.path.join(folder, "init.meta.json")
    attrs = json.load(open(meta)).get("attributes", {}) if os.path.exists(meta) else {}
    parts, spawns = [], []

    def read(path, into_spawns):
        nonlocal parts, spawns
        for name in sorted(os.listdir(path)):
            full = os.path.join(path, name)
            if os.path.isdir(full):  # a Rojo folder
                read(full, into_spawns or name == "Spawns")
            elif name.endswith(".model.json"):
                node = json.load(open(full))
                node.setdefault("name", name[: -len(".model.json")])  # Rojo names it by its file
                found = parts_from_nodes([node])
                if into_spawns or name == "Spawns.model.json":
                    spawns += [tuple(p.pos) for p in found]
                else:
                    parts += found

    read(folder, False)
    return parts, spawns, attrs


# ---- flicker -----------------------------------------------------------------------------------

def _faces(part):
    """Flat faces: (outward normal, list of corner points)."""
    c, h = part.pos, part.half
    ax = [part.axis(j) for j in range(3)]

    def at(lx, ly, lz):
        return tuple(c[i] + ax[0][i] * lx + ax[1][i] * ly + ax[2][i] * lz for i in range(3))

    faces = []
    if part.shape == "ball":
        return faces
    if part.shape == "cylinder":
        r = min(h[1], h[2])
        for s in (-1, 1):
            ring = [at(s * h[0], r * math.cos(k * math.pi / 8), r * math.sin(k * math.pi / 8))
                    for k in range(16)]
            faces.append((tuple(s * v for v in ax[0]), ring))
        return faces
    if part.shape == "wedge":
        hx, hy, hz = h
        faces.append((tuple(-v for v in ax[1]), [at(x, -hy, z) for x, z in
                                                  ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz))]))
        faces.append((ax[2], [at(x, y, hz) for x, y in ((-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy))]))
        for s in (-1, 1):
            faces.append((tuple(s * v for v in ax[0]),
                          [at(s * hx, -hy, -hz), at(s * hx, -hy, hz), at(s * hx, hy, hz)]))
        n = (0, 2 * hz, -2 * hy)
        length = math.hypot(n[1], n[2])
        normal = tuple((ax[1][i] * n[1] + ax[2][i] * n[2]) / length for i in range(3))
        faces.append((normal, [at(-hx, -hy, -hz), at(hx, -hy, -hz), at(hx, hy, hz), at(-hx, hy, hz)]))
        return faces
    for j in range(3):
        u, v = [k for k in range(3) if k != j]
        for s in (-1, 1):
            corners = []
            for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                local = [0, 0, 0]
                local[j], local[u], local[v] = s * h[j], a * h[u], b * h[v]
                corners.append(at(*local))
            faces.append((tuple(s * x for x in ax[j]), corners))
    return faces


def _basis(n):
    helper = (1, 0, 0) if abs(n[0]) < 0.9 else (0, 1, 0)
    u = (n[1] * helper[2] - n[2] * helper[1], n[2] * helper[0] - n[0] * helper[2],
         n[0] * helper[1] - n[1] * helper[0])
    length = math.sqrt(sum(x * x for x in u))
    u = tuple(x / length for x in u)
    v = (n[1] * u[2] - n[2] * u[1], n[2] * u[0] - n[0] * u[2], n[0] * u[1] - n[1] * u[0])
    return u, v


def _clip(subject, clip):
    """Intersection of two convex polygons (2D, counter-clockwise or clockwise alike)."""
    def area2(poly):
        return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
                   for i in range(len(poly)))
    if area2(clip) < 0:
        clip = clip[::-1]
    out = subject if area2(subject) >= 0 else subject[::-1]
    for i in range(len(clip)):
        a, b = clip[i], clip[(i + 1) % len(clip)]
        inp, out = out, []
        if not inp:
            break

        def inside(p):
            return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) >= -1e-9

        for k in range(len(inp)):
            p, q = inp[k], inp[(k + 1) % len(inp)]
            if inside(q):
                if not inside(p):
                    out.append(_cross_point(p, q, a, b))
                out.append(q)
            elif inside(p):
                out.append(_cross_point(p, q, a, b))
    return out


def _cross_point(p, q, a, b):
    x1, y1, x2, y2 = p[0], p[1], q[0], q[1]
    x3, y3, x4, y4 = a[0], a[1], b[0], b[1]
    den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if abs(den) < 1e-12:
        return q
    t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
    return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))


def _area(poly):
    return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
                   for i in range(len(poly)))) / 2


def flicker(parts, limit=60):
    problems = []
    visible = [i for i, p in enumerate(parts) if p.visible]
    opaque_idx = [i for i, p in enumerate(parts) if p.opaque]
    opaque_grid = Grid([parts[i] for i in opaque_idx])

    def buried(point):
        for k in opaque_grid.near(point[0], point[2]):
            if parts[opaque_idx[k]].contains(point, eps=1e-4):  # seams between pieces count
                return True
        return False

    groups = defaultdict(list)
    for i in visible:
        for normal, corners in _faces(parts[i]):
            key = tuple(round(v, 3) + 0.0 for v in normal)
            d = sum(normal[k] * corners[0][k] for k in range(3))
            groups[key].append((d, i, corners))
    seen = set()
    for key, faces in groups.items():
        faces.sort(key=lambda f: f[0])
        u, v = _basis(key)
        flat = [[(sum(c[k] * u[k] for k in range(3)), sum(c[k] * v[k] for k in range(3)))
                 for c in corners] for _, _, corners in faces]
        boxes = [(min(p[0] for p in f), max(p[0] for p in f), min(p[1] for p in f),
                  max(p[1] for p in f)) for f in flat]
        for a in range(len(faces)):
            da, ia, _ = faces[a]
            for b in range(a + 1, len(faces)):
                db, ib, _ = faces[b]
                if db - da >= MIN_GAP:
                    break
                if ia == ib:
                    continue
                ba, bb = boxes[a], boxes[b]
                if ba[0] >= bb[1] - 0.02 or bb[0] >= ba[1] - 0.02 or ba[2] >= bb[3] - 0.02 \
                        or bb[2] >= ba[3] - 0.02:
                    continue
                shared = _clip(flat[a], flat[b])
                if len(shared) < 3 or _area(shared) < 0.02:
                    continue
                cx = sum(p[0] for p in shared) / len(shared)
                cy = sum(p[1] for p in shared) / len(shared)
                samples = [(cx, cy)] + [(cx + (p[0] - cx) * 0.8, cy + (p[1] - cy) * 0.8)
                                        for p in shared]
                out = max(da, db) + 0.03
                points = [tuple(s[0] * u[k] + s[1] * v[k] + out * key[k] for k in range(3))
                          for s in samples]
                if all(buried(p) for p in points):
                    continue
                pair = (min(ia, ib), max(ia, ib), key)
                if pair in seen:
                    continue
                seen.add(pair)
                where = points[0]
                kind = "share a surface" if db - da < 0.005 else f"are only {db - da:.3f} apart"
                problems.append(f"flicker: {parts[ia].name} and {parts[ib].name} {kind} at "
                                f"({where[0]:.1f}, {where[1]:.1f}, {where[2]:.1f})")
                if len(problems) >= limit:
                    problems.append("flicker: (more not listed)")
                    return problems
    return problems


# ---- windows -----------------------------------------------------------------------------------

def _obb_overlap(a, b, grow_a=(0, 0, 0), shrink=0.02):
    """Separating-axis test between two parts treated as boxes."""
    axa = [a.axis(j) for j in range(3)]
    axb = [b.axis(j) for j in range(3)]
    ha = [a.half[j] + grow_a[j] - shrink for j in range(3)]
    hb = [b.half[j] - shrink for j in range(3)]
    d = [b.pos[i] - a.pos[i] for i in range(3)]
    axes = axa + axb
    for i in range(3):
        for j in range(3):
            c = (axa[i][1] * axb[j][2] - axa[i][2] * axb[j][1],
                 axa[i][2] * axb[j][0] - axa[i][0] * axb[j][2],
                 axa[i][0] * axb[j][1] - axa[i][1] * axb[j][0])
            if sum(x * x for x in c) > 1e-8:
                axes.append(c)
    for axis in axes:
        ra = sum(ha[j] * abs(sum(axa[j][k] * axis[k] for k in range(3))) for j in range(3))
        rb = sum(hb[j] * abs(sum(axb[j][k] * axis[k] for k in range(3))) for j in range(3))
        if abs(sum(d[k] * axis[k] for k in range(3))) > ra + rb:
            return False
    return True


def windows(parts, limit=40):
    problems = []
    panes = [p for p in parts if p.name == "Window"]
    others = [p for p in parts if p.visible and not p.name.startswith("Window") and p.name != "Wall"]
    grid = Grid(others)
    for pane in panes:
        thin = min(range(3), key=lambda j: pane.half[j])
        grow = [0, 0, 0]
        grow[thin] = 0.5  # and the space just in front of it, both sides
        candidates = set()
        for x in (pane.lo[0], pane.pos[0], pane.hi[0]):
            for z in (pane.lo[2], pane.pos[2], pane.hi[2]):
                candidates.update(grid.near(x, z))
        for k in candidates:
            other = others[k]
            if other.hi[1] <= pane.lo[1] or other.lo[1] >= pane.hi[1]:
                continue
            if _obb_overlap(pane, other, grow):
                problems.append(f"windows: {other.name} cuts into the window at "
                                f"({pane.pos[0]:.1f}, {pane.pos[1]:.1f}, {pane.pos[2]:.1f})")
                if len(problems) >= limit:
                    return problems
    return problems


# ---- reach -------------------------------------------------------------------------------------

def jump_reach(drop):
    """How far a sprinting jump carries you before your feet are `drop` below where you took off
    (negative: above), less a margin so the jump is one you make every time."""
    disc = JUMP_SPEED ** 2 + 2 * GRAVITY * drop
    if disc < 0:
        return 0.0
    t = (JUMP_SPEED + math.sqrt(disc)) / GRAVITY
    return RUN * t - JUMP_MARGIN


class Reach:
    def __init__(self, parts, spawns, kill_height=None, ignore_tops=(), routes=()):
        self.parts = parts
        self.solid_idx = [i for i, p in enumerate(parts) if p.solid]
        self.grid = Grid([parts[i] for i in self.solid_idx])
        self.columns = {}
        self.kill = kill_height
        self.ignore = tuple(ignore_tops)
        self.spawns = spawns
        self.routes = routes

    def column(self, x, z):
        key = (round(x * 4), round(z * 4))
        found = self.columns.get(key)
        if found is None:
            found = []
            for k in self.grid.near(x, z):
                index = self.solid_idx[k]
                hit = self.parts[index].column(x, z)
                if hit:
                    found.append((hit[0], hit[1], index, hit[2]))
            found.sort()
            self.columns[key] = found
        return found

    def free(self, x, z, lo, hi):
        for bottom, top, _, _ in self.column(x, z):
            if bottom < hi and top > lo:
                return False
        return True

    def jump_over(self, x, z, base, start_x, start_z):
        """Can you jump over whatever is at (x, z) from height `base`?"""
        tops = [top for bottom, top, _, _ in self.column(x, z) if base < top <= base + JUMP_UP]
        for s in sorted(set(tops)):
            if self.free(x, z, s + 0.05, s + STAND) and self.free(start_x, start_z, base + 0.2,
                                                                   s + STAND):
                return True
        return False

    def build(self):
        xs = [self.parts[i].lo[0] for i in self.solid_idx] + [self.parts[i].hi[0] for i in self.solid_idx]
        zs = [self.parts[i].lo[2] for i in self.solid_idx] + [self.parts[i].hi[2] for i in self.solid_idx]
        x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
        self.origin = (math.floor(x0 / CELL) * CELL + CELL / 2, math.floor(z0 / CELL) * CELL + CELL / 2)
        nx = int((x1 - self.origin[0]) / CELL) + 1
        nz = int((z1 - self.origin[1]) / CELL) + 1
        self.nodes = []  # (x, z, height, part index, cell)
        self.at = defaultdict(list)
        for i in range(nx):
            for k in range(nz):
                x, z = self.origin[0] + i * CELL, self.origin[1] + k * CELL
                col = self.column(x, z)
                for bottom, top, index, up in col:
                    part = self.parts[index]
                    if up < 0.6 or part.name in self.ignore:
                        continue
                    if self.kill is not None and top < self.kill:
                        continue
                    if not self.free(x, z, top + 0.2, top + CROUCH):
                        continue
                    self.at[(i, k)].append(len(self.nodes))
                    self.nodes.append((x, z, top, index, (i, k)))
        self.edges = defaultdict(set)
        for a, (xa, za, ha, pa, (i, k)) in enumerate(self.nodes):
            for di in (-1, 0, 1):
                for dk in (-1, 0, 1):
                    if di == 0 and dk == 0:
                        continue
                    for b in self.at.get((i + di, k + dk), ()):
                        if self.step_ok(self.nodes[a], self.nodes[b]):
                            self.edges[a].add(b)
        self.long_jumps()
        self.ladders()
        self.launches()
        self.swings()
        for start, end, both in self.routes:
            sa, sb = self.nearest(start), self.nearest(end)
            if sa is not None and sb is not None:
                self.edges[sa].add(sb)
                if both:
                    self.edges[sb].add(sa)

    def step_ok(self, a, b):
        xa, za, ha, pa, _ = a
        xb, zb, hb, pb, _ = b
        mx, mz = (xa + xb) / 2, (za + zb) / 2
        rise = hb - ha
        if pa == pb and self.parts[pa].shape != "cylinder":
            slope = abs(rise) / math.hypot(xb - xa, zb - za)
            if slope <= 1.4:  # along one ramp or stair
                return self.free(mx, mz, max(ha, hb) + 0.3, max(ha, hb) + CROUCH)
        if rise <= STEP:
            if not self.free(xb, zb, hb + 0.2, max(ha, hb) + CROUCH):
                return False
            base = max(ha, hb)
            return (self.free(mx, mz, base + 0.25, base + CROUCH)
                    or self.jump_over(mx, mz, base, xa, za))
        if rise <= JUMP_UP:
            return (self.free(xa, za, ha + 0.2, hb + CROUCH)
                    and self.free(mx, mz, hb + 0.2, hb + CROUCH))
        return False

    def long_jumps(self):
        reach_max = jump_reach(40)
        cells = int(reach_max / CELL) + 1
        for a, (xa, za, ha, pa, (i, k)) in enumerate(self.nodes):
            open_dirs = []
            for di in (-1, 0, 1):
                for dk in (-1, 0, 1):
                    if di == 0 and dk == 0:
                        continue
                    if not any(abs(self.nodes[n][2] - ha) <= STEP for n in self.at.get((i + di, k + dk), ())):
                        open_dirs.append((di / math.hypot(di, dk), dk / math.hypot(di, dk)))
            if not open_dirs:
                continue
            for di in range(-cells, cells + 1):
                for dk in range(-cells, cells + 1):
                    if abs(di) <= 1 and abs(dk) <= 1:
                        continue
                    for b in self.at.get((i + di, k + dk), ()):
                        if b in self.edges[a]:
                            continue
                        xb, zb, hb, _, _ = self.nodes[b]
                        dx, dz = xb - xa, zb - za
                        dist = math.hypot(dx, dz)
                        if hb - ha > JUMP_UP - 1.5 or dist > jump_reach(ha - hb):
                            continue
                        if not any((dx * ox + dz * oz) / dist > 0.7 for ox, oz in open_dirs):
                            continue
                        top = max(ha, hb)
                        steps = int(dist / 1.5)
                        if not (self.free(xa, za, ha + 0.2, ha + STAND)
                                and self.free(xb, zb, hb + 0.2, top + 2.0)):
                            continue
                        if all(self.free(xa + dx * s / steps, za + dz * s / steps, top + 0.6, top + 4.0)
                               for s in range(1, steps)):
                            self.edges[a].add(b)

    def ladders(self):
        for index, part in enumerate(self.parts):
            if part.cls != "TrussPart":
                continue
            group = [n for n, (x, z, h, _, _) in enumerate(self.nodes)
                     if part.lo[0] - 2.5 <= x <= part.hi[0] + 2.5
                     and part.lo[2] - 2.5 <= z <= part.hi[2] + 2.5
                     and part.lo[1] - 1.0 <= h <= part.hi[1] + 0.6]
            for a in group:
                self.edges[a].update(b for b in group if b != a)

    def launches(self):
        for index, part in enumerate(self.parts):
            velocity = part.attrs.get("LaunchVelocity")
            if not velocity:
                continue
            vx, vy, vz = velocity["Vector3"]
            for a, (x, z, h, p, _) in enumerate(self.nodes):
                if p != index:
                    continue
                landing = self.fly(x, h + ROOT, z, vx, vy, vz)
                if landing is not None:
                    self.edges[a].add(landing)

    def fly(self, x, y, z, vx, vy, vz, dt=1 / 120):
        t = 0.0
        while t < 6:
            feet_before = y - ROOT
            if t >= LAUNCH_DRIVE:
                vy -= GRAVITY * dt
            x, y, z = x + vx * dt, y + vy * dt, z + vz * dt
            t += dt
            feet = y - ROOT
            if vy < 0:
                i = round((x - self.origin[0]) / CELL)
                k = round((z - self.origin[1]) / CELL)
                for n in self.at.get((i, k), ()):
                    if feet <= self.nodes[n][2] <= feet_before + 0.5:
                        return n
            if not self.free(x, z, y - 1, y + 1):
                return None
            if self.kill is not None and feet < self.kill:
                return None
        return None

    def swings(self):
        for part in self.parts:
            a = part.attrs
            if not (a.get("SwingLevel") and a.get("Carry")):
                continue
            pivot = a["SwingPivot"]["Vector3"]
            axis = a["SwingAxis"]["Vector3"]
            length = math.sqrt(sum(v * v for v in axis)) or 1
            axis = [v / length for v in axis]
            ends = []
            for sign in (-1, 1):
                ang = math.radians(a.get("SwingAmplitude", 0)) * sign
                rel = [part.pos[i] - pivot[i] for i in range(3)]
                c, s = math.cos(ang), math.sin(ang)
                cross = (axis[1] * rel[2] - axis[2] * rel[1], axis[2] * rel[0] - axis[0] * rel[2],
                         axis[0] * rel[1] - axis[1] * rel[0])
                dot = sum(axis[i] * rel[i] for i in range(3))
                moved = [rel[i] * c + cross[i] * s + axis[i] * dot * (1 - c) + pivot[i] for i in range(3)]
                top = moved[1] + (part.hi[1] - part.lo[1]) / 2
                radius = max(part.half[1], part.half[2])
                ends.append([n for n, (x, z, h, _, _) in enumerate(self.nodes)
                             if math.hypot(x - moved[0], z - moved[2]) <= radius + 2.5
                             and top - 1.5 <= h <= top + 1.5])
            for a_end, b_end in ((ends[0], ends[1]), (ends[1], ends[0])):
                for n in a_end:
                    self.edges[n].update(b_end)

    def nearest(self, point, reach=3.0):
        best, best_d = None, reach
        x, y, z = point
        for n, (nx_, nz_, h, _, _) in enumerate(self.nodes):
            if abs(h - y) > 2.0:
                continue
            d = math.hypot(nx_ - x, nz_ - z)
            if d < best_d:
                best, best_d = n, d
        return best

    def problems(self):
        self.build()
        starts = set()
        for x, y, z in self.spawns:
            n = self.nearest((x, y - 0.5, z), reach=2.5)
            if n is not None:
                starts.add(n)
        problems = []
        if not starts:
            return ["reach: no spawn stands on a walkable floor"]
        forward = self.search(starts, self.edges)
        backward_edges = defaultdict(set)
        for a, bs in self.edges.items():
            for b in bs:
                backward_edges[b].add(a)
        backward = self.search(starts, backward_edges)
        all_nodes = set(range(len(self.nodes)))
        for label, bad in (("can't be reached from the spawns", all_nodes - forward),
                           ("is a dead end (you can't get back)", forward - backward)):
            for cluster in self.clusters(bad):
                area = len(cluster) * CELL * CELL
                cells = {self.nodes[n][4] for n in cluster}
                roomy = any((i + 1, k) in cells and (i, k + 1) in cells and (i + 1, k + 1) in cells
                            for i, k in cells)
                if area < MIN_AREA or not roomy:  # a ledge or wall top, not a place
                    continue
                xs = [self.nodes[n][0] for n in cluster]
                zs = [self.nodes[n][1] for n in cluster]
                hs = [self.nodes[n][2] for n in cluster]
                names = sorted({self.parts[self.nodes[n][3]].name for n in cluster})
                problems.append(f"reach: {area:.0f} studs^2 at height {min(hs):.1f}-{max(hs):.1f} "
                                f"around ({sum(xs) / len(xs):.0f}, {sum(zs) / len(zs):.0f}) "
                                f"(on {', '.join(names[:3])}) {label}")
        return problems

    @staticmethod
    def search(starts, edges):
        seen = set(starts)
        queue = deque(starts)
        while queue:
            a = queue.popleft()
            for b in edges.get(a, ()):
                if b not in seen:
                    seen.add(b)
                    queue.append(b)
        return seen

    def clusters(self, nodes):
        nodes = set(nodes)
        out = []
        while nodes:
            start = nodes.pop()
            cluster, queue = [start], [start]
            while queue:
                a = queue.pop()
                _, _, ha, _, (i, k) = self.nodes[a]
                for di in (-1, 0, 1):
                    for dk in (-1, 0, 1):
                        for b in self.at.get((i + di, k + dk), ()):
                            if b in nodes and abs(self.nodes[b][2] - ha) <= JUMP_UP:
                                nodes.discard(b)
                                cluster.append(b)
                                queue.append(b)
            out.append(cluster)
        out.sort(key=len, reverse=True)
        return out


# ---- running them ------------------------------------------------------------------------------

def check(parts, spawns, attributes, ignore_tops=(), routes=()):
    """All three checks. `parts` from parts_from_nodes (or load_folder); `routes` are extra ways
    across: ((x, y, z) from, (x, y, z) to, both ways?)."""
    problems = flicker(parts) + windows(parts)
    # The map's OutOfBounds attribute names parts whose tops aren't play area (roofs, ceilings,
    # tall furniture), comma-separated.
    off = [n.strip() for n in str(attributes.get("OutOfBounds", "")).split(",") if n.strip()]
    reach = Reach(parts, spawns, attributes.get("KillHeight"), tuple(ignore_tops) + tuple(off),
                  routes)
    return problems + reach.problems()


def check_map(m, attributes, ignore_tops=(), routes=()):
    """For generators: checks a maplib Map before it's written."""
    nodes = [n for group in m.groups.values() for n in group]
    spawns = [(x, y + 0.5, z) for x, y, z in m.spawns]
    return check(parts_from_nodes(nodes), spawns, attributes, ignore_tops, routes)


if __name__ == "__main__":
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "maps")
    names = sys.argv[1:] or sorted(os.listdir(root))
    failed = False
    for name in names:
        folder = os.path.join(root, name)
        if not os.path.isdir(folder):
            continue
        parts, spawns, attrs = load_folder(folder)
        if attrs.get("InRotation") is False and name not in sys.argv[1:]:
            continue
        problems = check(parts, spawns, attrs)
        print(f"{name}: {len(parts)} parts, " + ("ok" if not problems else f"{len(problems)} problems"))
        for line in problems:
            print("  " + line)
        failed = failed or bool(problems)
    raise SystemExit(1 if failed else 0)
