// The victory icons: one picture per victory's signature moment (docs/polish/victories.md), in the
// item's colours, the winner as a block figure on the 1st place block. render.mjs saves them as icons
// named "victory" + the look's Victory (victoryFlex, victoryConfettiStorm...).
const INK = "#111111";
const f = (n) => +(+n).toFixed(2);
let seed = 7;
const rand = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
const between = (a, b) => a + (b - a) * rand();
const reseed = (name) => { seed = [...name].reduce((h, ch) => (h * 31 + ch.charCodeAt(0)) % 2147483646, 11) + 1; };
const rad = (deg) => deg * Math.PI / 180;
function lerpHex(a, b, t) {
  const pa = [1, 3, 5].map((i) => parseInt(a.slice(i, i + 2), 16));
  const pb = [1, 3, 5].map((i) => parseInt(b.slice(i, i + 2), 16));
  return "#" + pa.map((v, i) => Math.round(v + (pb[i] - v) * t).toString(16).padStart(2, "0")).join("");
}
const poly = (pts) => "M" + pts.map(([x, y]) => `${f(x)} ${f(y)}`).join(" L") + " Z";
function spiky(cx, cy, R, r, n, jitter, rot = -90) {
  let d = "";
  for (let i = 0; i < n * 2; i++) {
    const a = rad(rot + i * 180 / n);
    const rr = i % 2 ? r : R * (1 - (jitter || 0) * ((i * 7) % 5) / 5);
    d += (i ? "L" : "M") + f(cx + Math.cos(a) * rr) + " " + f(cy + Math.sin(a) * rr) + " ";
  }
  return d + "Z";
}
const star4 = (cx, cy, R, r) => spiky(cx, cy, R, r, 4, 0);
const ellipsePath = (cx, cy, rx, ry) => `M${f(cx - rx)} ${f(cy)} a${f(rx)} ${f(ry)} 0 1 0 ${f(2 * rx)} 0 a${f(rx)} ${f(ry)} 0 1 0 ${f(-2 * rx)} 0`;
const quad = (cx, cy, w, h, deg) => { const a = rad(deg), c = Math.cos(a), s = Math.sin(a); return poly([[-w / 2, -h / 2], [w / 2, -h / 2], [w / 2, h / 2], [-w / 2, h / 2]].map(([x, y]) => [cx + x * c - y * s, cy + x * s + y * c])); };

let uid = 0;
function makeIcon(draw) {
  const defs = [];
  const id = () => "v" + (++uid);
  const k = {
    id, def: (s) => defs.push(s),
    glow(cx, cy, r, c, o = 0.6) {
      const g = id();
      defs.push(`<radialGradient id="${g}"><stop offset="0" stop-color="${c}" stop-opacity="${o}"/><stop offset="1" stop-color="${c}" stop-opacity="0"/></radialGradient>`);
      return `<circle cx="${f(cx)}" cy="${f(cy)}" r="${f(r)}" fill="url(#${g})"/>`;
    },
    oval(cx, cy, rx, ry, c, o = 0.6) {
      const g = id();
      defs.push(`<radialGradient id="${g}"><stop offset="0" stop-color="${c}" stop-opacity="${o}"/><stop offset="1" stop-color="${c}" stop-opacity="0"/></radialGradient>`);
      return `<ellipse cx="${f(cx)}" cy="${f(cy)}" rx="${f(rx)}" ry="${f(ry)}" fill="url(#${g})"/>`;
    },
    flare(cx, cy, r, c) {
      const g = id();
      defs.push(`<radialGradient id="${g}"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".3" stop-color="#FFFFFF" stop-opacity=".95"/><stop offset=".55" stop-color="${c}" stop-opacity=".85"/><stop offset="1" stop-color="${c}" stop-opacity="0"/></radialGradient>`);
      return `<circle cx="${f(cx)}" cy="${f(cy)}" r="${f(r)}" fill="url(#${g})"/>`;
    },
    streak(x1, y1, x2, y2, w, c, core = true) {
      const one = (ax, ay, bx, by, ww, col, o) => {
        const len = Math.hypot(bx - ax, by - ay) || 1;
        const px = -(by - ay) / len, py = (bx - ax) / len;
        const g = id();
        defs.push(`<linearGradient id="${g}" gradientUnits="userSpaceOnUse" x1="${f(ax)}" y1="${f(ay)}" x2="${f(bx)}" y2="${f(by)}"><stop offset="0" stop-color="${col}" stop-opacity="0"/><stop offset=".6" stop-color="${col}" stop-opacity="${o * 0.8}"/><stop offset="1" stop-color="${col}" stop-opacity="${o}"/></linearGradient>`);
        return `<path d="M${f(ax)} ${f(ay)} L${f(bx + px * ww)} ${f(by + py * ww)} A${f(ww)} ${f(ww)} 0 0 0 ${f(bx - px * ww)} ${f(by - py * ww)} Z" fill="url(#${g})"/>`;
      };
      let out = one(x1, y1, x2, y2, w, c, 1);
      if (core) out += one(x1 + (x2 - x1) * 0.45, y1 + (y2 - y1) * 0.45, x2, y2, w * 0.42, "#FFFFFF", 0.95);
      return out;
    },
    glint(cx, cy, R) { return k.glow(cx, cy, R * 1.1, "#FFFFFF", 0.45) + `<path d="${star4(cx, cy, R, R * 0.16)}" fill="#FFFFFF"/>`; },
    solid(parts, shadow, transform = "", stroke = 3.4, off = [3.8, 3.2]) {
      const back = parts.map(([d]) => `<path d="${d}" fill="${shadow}" stroke="${shadow}" stroke-width="${stroke}" stroke-linejoin="round"/>`).join("");
      const front = parts.map(([d, fill]) => `<path d="${d}" fill="${fill}" stroke="${INK}" stroke-width="${stroke}" stroke-linejoin="round"/>`).join("");
      return `<g transform="${transform}"><g transform="translate(${off[0]} ${off[1]})">${back}</g>${front}</g>`;
    },
    light(d, c, w) {
      return `<path d="${d}" fill="none" stroke="${c}" stroke-width="${f(w * 2.6)}" stroke-opacity=".22" stroke-linejoin="round" stroke-linecap="round"/>` +
        `<path d="${d}" fill="none" stroke="${c}" stroke-width="${f(w)}" stroke-linejoin="round" stroke-linecap="round"/>` +
        `<path d="${d}" fill="none" stroke="#FFFFFF" stroke-width="${f(w * 0.38)}" stroke-linejoin="round" stroke-linecap="round"/>`;
    },
    // A glowing stroke that shifts from c1 to c2 along (x1, y1) -> (x2, y2).
    glight(d, x1, y1, x2, y2, c1, c2, w) {
      const g = id();
      defs.push(`<linearGradient id="${g}" gradientUnits="userSpaceOnUse" x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient>`);
      return `<path d="${d}" fill="none" stroke="url(#${g})" stroke-width="${f(w * 2.6)}" stroke-opacity=".25" stroke-linecap="round"/>` +
        `<path d="${d}" fill="none" stroke="url(#${g})" stroke-width="${f(w)}" stroke-linecap="round"/>` +
        `<path d="${d}" fill="none" stroke="#FFFFFF" stroke-width="${f(w * 0.32)}" stroke-linecap="round" stroke-opacity=".9"/>`;
    },
    rays(cx, cy, n, r0, r1a, r1b, w, colors, flat = 1, start = 0) {
      let out = "";
      for (let i = 0; i < n; i++) {
        const a = rad(start + i * 360 / n + between(-8, 8)), r1 = between(r1a, r1b);
        out += k.streak(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0 * flat, cx + Math.cos(a) * r1, cy + Math.sin(a) * r1 * flat, between(w * 0.7, w * 1.15), colors[i % colors.length]);
      }
      return out;
    },
    dots(cx, cy, n, r0, r1, colors, size = 2.4, flat = 1) {
      let out = "";
      for (let i = 0; i < n; i++) {
        const a = rand() * Math.PI * 2, r = between(r0, r1);
        out += k.flare(cx + Math.cos(a) * r, cy + Math.sin(a) * r * flat, between(size * 0.7, size * 1.3), colors[i % colors.length]);
      }
      return out;
    },
  };
  const body = draw(k);
  return `<svg class="art" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs>${defs.join("")}</defs><g transform="translate(50 50) skewX(-8) translate(-50 -50)">${body}</g></svg>`;
}

// The winner: a block figure in the icon style. Limb angles in degrees, 0 = hanging straight
// down, 90 = out to the screen's left, -90 = out to the right, 180 = straight up; each limb is
// [upper, lower relative to upper]. Returns the drawing and where the hands, feet and head are.
function figure(k, o) {
  const s = o.s || 1, rot = rad(o.rot || 0), cr = Math.cos(rot), sr = Math.sin(rot);
  const map = ([x, y]) => [o.x + (x * cr - y * sr) * s, o.y + (x * sr + y * cr) * s];
  const seg = (px, py, a, len, w) => {
    const dx = -Math.sin(rad(a)), dy = Math.cos(rad(a)), qx = Math.cos(rad(a)), qy = Math.sin(rad(a));
    const sx = px - dx * w * 0.28, sy = py - dy * w * 0.28, ex = px + dx * len, ey = py + dy * len;
    return { d: poly([[sx + qx * w / 2, sy + qy * w / 2], [ex + qx * w / 2, ey + qy * w / 2], [ex - qx * w / 2, ey - qy * w / 2], [sx - qx * w / 2, sy - qy * w / 2]].map(map)), end: [ex, ey] };
  };
  const limb = (px, py, [a1, a2], len, w) => { const u = seg(px, py, a1, len, w); const l = seg(u.end[0], u.end[1], a1 + a2, len, w); return { parts: [u.d, l.d], end: map(l.end), joint: map(u.end) }; };
  if (o.pin) {
    const [what, target] = o.pin;
    const first = figure(k, { ...o, pin: null });
    const at = what === "feet" ? Math.max(first.footL[1], first.footR[1]) : what === "handL" ? first.handL[1] : first.hips[1];
    return figure(k, { ...o, pin: null, y: o.y + target - at });
  }
  const W = { head: "#FFFFFF", torso: o.color || "#E6E9F1", arm: "#FFFFFF", leg: "#C9CFDD" };
  const legL = limb(-4.1, 10, o.legL || [4, 0], 10.5, 7.6), legR = limb(4.1, 10, o.legR || [-4, 0], 10.5, 7.6);
  const armL = limb(-11.6, -8.6, o.armL || [8, 0], 9.6, 7), armR = limb(11.6, -8.6, o.armR || [-8, 0], 9.6, 7);
  const torso = poly([[-8, -10], [8, -10], [8, 10], [-8, 10]].map(map));
  const head = poly([[-6.4, -23.2], [6.4, -23.2], [6.4, -10.6], [-6.4, -10.6]].map(map));
  const parts = [];
  const legs = [[legL.parts[0], W.leg], [legL.parts[1], W.leg], [legR.parts[0], W.leg], [legR.parts[1], W.leg]];
  const arms = [[armL.parts[0], W.arm], [armL.parts[1], W.arm], [armR.parts[0], W.arm], [armR.parts[1], W.arm]];
  if (o.armsBack) parts.push(...arms);
  parts.push(...legs, [torso, W.torso]);
  if (!o.armsBack) parts.push(...arms);
  parts.push([head, W.head]);
  let svg = k.solid(parts, o.shadow || "#8C93A8", "", f(2.2 + 1.1 * s), [f(3.4 * s), f(2.9 * s)]);
  if (o.face !== false) {
    const e1 = map([-2.6, -18]), e2 = map([2.6, -18]), m1 = map([-2.8, -14.6]), mc = map([0, -12.6]), m2 = map([2.8, -14.6]);
    svg += `<circle cx="${f(e1[0])}" cy="${f(e1[1])}" r="${f(1.15 * s)}" fill="${INK}"/><circle cx="${f(e2[0])}" cy="${f(e2[1])}" r="${f(1.15 * s)}" fill="${INK}"/>` +
      `<path d="M${f(m1[0])} ${f(m1[1])} Q${f(mc[0])} ${f(mc[1])} ${f(m2[0])} ${f(m2[1])}" fill="none" stroke="${INK}" stroke-width="${f(1.2 * s)}" stroke-linecap="round"/>`;
  }
  return { svg, handL: armL.end, handR: armR.end, footL: legL.end, footR: legR.end, hips: map([0, 10]), head: map([0, -17]), top: map([0, -23]) };
}

// A podium block in three-quarter view, with its place number.
function block(k, x, y, w, h, d, label, shadow, numberColor = "#FFD60A") {
  const top = poly([[x, y], [x + d, y - d * 0.55], [x + w + d, y - d * 0.55], [x + w, y]]);
  const side = poly([[x + w, y], [x + w + d, y - d * 0.55], [x + w + d, y + h - d * 0.55], [x + w, y + h]]);
  const front = poly([[x, y], [x + w, y], [x + w, y + h], [x, y + h]]);
  let out = k.solid([[side, "#C2C8D8"], [top, "#EEF0F6"], [front, "#FFFFFF"]], shadow);
  if (label) out += `<text x="${f(x + w / 2)}" y="${f(y + h * 0.78)}" text-anchor="middle" font-family="Bangers, Impact, sans-serif" font-size="${f(h * 0.78)}" fill="${numberColor}" stroke="${INK}" stroke-width="1.6" paint-order="stroke">${label}</text>`;
  return out;
}

function confettiBits(k, n, cols, area, sizes = [5, 8]) {
  let out = "";
  for (let i = 0; i < n; i++) {
    const [x0, y0, x1, y1] = area;
    const c = lerpHex(cols[i % cols.length], cols[(i + 1) % cols.length], rand() * 0.5);
    out += k.solid([[quad(between(x0, x1), between(y0, y1), between(sizes[0], sizes[1]), between(2.4, 4) * between(0.35, 1), between(0, 180)), c]], INK, "", 1.1, [1, 1]);
  }
  return out;
}

const VICTORIES = [
  {
    name: "Flex", rarity: "Epic", rar: "#AA50FF",
    moves: "Both arms up in a double bicep on the 1st place block, a gold-to-red sparkle burst behind.",
    draw: (k) => {
      const G = "#FFD63C", R = "#FF5A5A";
      const fig = figure(k, { x: 53, y: 50, s: 1.08, armL: [92, 88], armR: [-92, -88], legL: [8, 0], legR: [-8, 0], shadow: R, color: G, pin: ["feet", 77.8] });
      return k.glow(50, 44, 52, G, 0.5) + k.rays(50, 40, 18, 12, 36, 50, 3.8, [G, R]) +
        k.dots(50, 40, 12, 34, 48, [G, R], 2.6) +
        block(k, 28, 80, 42, 22, 8, "1", R) + fig.svg +
        k.glint(16, 20, 8) + k.glint(84, 16, 7) + k.glint(86, 58, 5) + k.glint(14, 60, 5);
    },
  },
  {
    name: "Backflip", rarity: "Epic", rar: "#AA50FF",
    moves: "Tucked mid-backflip high over the block on a cyan-to-purple trail, the landing's shockwave below.",
    draw: (k) => {
      const C = "#22D3EE", U = "#AA50FF";
      const arc = `M24 74 A30 30 0 1 1 78 66`;
      const fig = figure(k, { x: 52, y: 34, s: 0.92, rot: 165, color: C, armL: [140, 30], armR: [-140, -30], legL: [165, -150], legR: [-165, 150], face: false, shadow: U });
      return k.glow(50, 44, 52, C, 0.45) +
        block(k, 28, 80, 42, 22, 8, "1", U) +
        k.light(ellipsePath(52, 78, 30, 5.5), C, 2.4) +
        k.light("M38 79 L42 83 L40 87 M60 80 L57 84 L60 88", C, 1) +
        k.glight(arc, 24, 74, 78, 66, C, U, 4.5) +
        `<path d="M78 66 L72 62 L82 58 Z" fill="${U}" stroke="${INK}" stroke-width="1.6" stroke-linejoin="round"/>` +
        fig.svg + k.dots(50, 40, 8, 34, 44, [C, U], 2.2) + k.glint(14, 18, 7) + k.glint(88, 30, 6);
    },
  },
  {
    name: "Confetti Storm", rarity: "Epic", rar: "#AA50FF",
    moves: "Arms up firing two confetti cannons while confetti pours down and piles on the block and shoulders.",
    draw: (k) => {
      const cols = ["#FFD23C", "#FF5A5A", "#AA50FF", "#22D3EE"];
      const fig = figure(k, { x: 53, y: 54, s: 1, armL: [152, 6], armR: [-152, -6], legL: [7, 0], legR: [-7, 0], shadow: "#AA50FF", color: "#FFD23C", pin: ["feet", 77.8] });
      const cannon = (x, y, a, c) => k.solid([[quad(x, y, 6.5, 11, a), c], [quad(x + Math.sin(rad(-a)) * 6, y - Math.cos(rad(a)) * 6, 8, 3, a), "#FFFFFF"]], INK, "", 2, [1.4, 1.2]);
      const [lx, ly] = fig.handL, [rx, ry] = fig.handR;
      return k.glow(50, 40, 52, "#FFD23C", 0.4) +
        confettiBits(k, 26, cols, [4, 2, 96, 70]) +
        k.rays(lx - 2, ly - 8, 5, 2, 14, 22, 2.2, ["#FFE9A0"], 1, -120) + k.rays(rx + 2, ry - 8, 5, 2, 14, 22, 2.2, ["#FFE9A0"], 1, -110) +
        block(k, 28, 80, 42, 22, 8, "1", "#AA50FF") + fig.svg +
        cannon(lx, ly - 4, -18, "#FFD23C") + cannon(rx, ry - 4, 18, "#AA50FF") +
        confettiBits(k, 14, cols, [29, 75.5, 76, 79.5], [4, 6]) +
        confettiBits(k, 4, cols, [38, 28, 62, 33], [3.5, 5]);
    },
  },
  {
    name: "Breakdance", rarity: "Epic", rar: "#AA50FF",
    moves: "The one-hand freeze, a leg sticking straight out, pink-to-yellow windmill trails and a bass ring.",
    draw: (k) => {
      const P = "#FF3E8A", Y = "#FFD60A";
      const fig = figure(k, { x: 56, y: 52, s: 0.98, rot: 205, armL: [156, 0], armR: [-60, 40], legL: [60, 0], legR: [-20, 70], face: false, shadow: P, color: P, pin: ["handL", 77.8] });
      return k.glow(50, 50, 52, P, 0.45) +
        k.glight("M14 52 A36 16 -20 0 1 84 30", 14, 52, 84, 30, P, Y, 3.6) +
        k.glight("M22 66 A30 13 -20 0 1 88 44", 22, 66, 88, 44, Y, P, 2.6) +
        block(k, 28, 80, 42, 22, 8, "1", P) +
        k.light(ellipsePath(53, 77.8, 34, 6), P, 2.6) + k.light(ellipsePath(53, 77.8, 20, 3.5), Y, 1.4) +
        fig.svg + k.dots(50, 46, 10, 30, 46, [P, Y], 2.2) + k.glint(18, 16, 7) + k.glint(86, 70, 5);
    },
  },
  {
    name: "Katana", rarity: "Epic", rar: "#AA50FF",
    moves: "Mid-cut with the long katana: the cut hangs in the air, a watermelon falls apart in halves, pink petals.",
    draw: (k) => {
      const K = "#FF8FC2";
      const g = k.id();
      k.def(`<linearGradient id="${g}" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="${K}" stop-opacity="0"/><stop offset=".5" stop-color="${K}" stop-opacity=".85"/><stop offset="1" stop-color="#FFFFFF"/></linearGradient>`);
      const fig = figure(k, { x: 43, y: 56, s: 1, armL: [40, 20], armR: [-128, -12], legL: [16, 0], legR: [-14, 0], shadow: K, color: K, pin: ["feet", 81.8] });
      const [hx, hy] = fig.handR, a = rad(-42), L = 38;
      const tx = hx + Math.cos(a) * L, ty = hy + Math.sin(a) * L;
      const blade = poly([[hx + Math.cos(a) * 4 - 1.2, hy + Math.sin(a) * 4 - 1.2], [tx, ty], [hx + Math.cos(a) * 4 + 1.6, hy + Math.sin(a) * 4 + 1.6]]);
      const melon = (x, y, r, rot) => k.solid([[`M${x - r} ${y} A${r} ${r} 0 0 0 ${x + r} ${y} Z`, "#3FA34D"], [`M${x - r * 0.78} ${y} A${r * 0.78} ${r * 0.78} 0 0 0 ${x + r * 0.78} ${y} Z`, "#FF4D5E"]], INK, `rotate(${rot} ${x} ${y})`, 1.8, [1.4, 1.2]) +
        `<g transform="rotate(${rot} ${x} ${y})">${[-0.4, 0, 0.4].map((t) => `<ellipse cx="${f(x + t * r)}" cy="${f(y + r * 0.35)}" rx=".9" ry="1.4" fill="${INK}"/>`).join("")}</g>`;
      let petals = "";
      for (let i = 0; i < 9; i++) petals += k.solid([[quad(between(8, 96), between(6, 70), 5, 2.8, between(0, 180)), i % 3 ? K : "#FFFFFF"]], "#B0306E", "", 0.9, [0.8, 0.8]);
      return k.glow(56, 40, 50, K, 0.45) +
        `<path d="M8 74 Q42 2 96 14 Q46 16 8 74 Z" fill="url(#${g})"/>` + `<path d="M8 74 Q42 2 96 14" fill="none" stroke="#FFFFFF" stroke-width="1.6" stroke-opacity=".9"/>` +
        block(k, 18, 84, 42, 18, 8, "1", K) + fig.svg +
        k.solid([[blade, "#F4F7FF"], [quad(hx + Math.cos(a) * 3.2, hy + Math.sin(a) * 3.2, 2.2, 8, 48), "#FFD60A"], [quad(hx - Math.cos(a) * 3, hy - Math.sin(a) * 3, 7, 2.6, -42), "#2B2B35"]], "#B0306E", "", 1.8, [1.4, 1.2]) +
        melon(78, 36, 10, -28) + melon(88, 52, 10, 150) +
        k.dots(82, 44, 7, 6, 16, ["#FF4D5E"], 1.8) + petals + k.glint(tx, ty, 6) + k.glint(14, 18, 6);
    },
  },
  {
    name: "Trophy Lift", rarity: "Epic", rar: "#AA50FF",
    moves: "The gold cup held high overhead with both arms, pink and cyan ribbons, a burst of gold sparkles.",
    draw: (k) => {
      const P = "#FF3E8A", C = "#22D3EE", gold = "#FFD60A", goldD = "#D9A200";
      const fig = figure(k, { x: 53, y: 60, s: 0.96, armL: [168, 6], armR: [-168, -6], legL: [7, 0], legR: [-7, 0], shadow: P, color: P, pin: ["feet", 77.8] });
      const tx = (fig.handL[0] + fig.handR[0]) / 2, ty = Math.min(fig.handL[1], fig.handR[1]) - 11;
      const T = `translate(${f(tx)} ${f(ty)}) scale(.48) translate(-32 -32)`;
      const cup = k.solid([["M27 39 H37 L38 48 H26 Z", goldD], ["M17 7 H47 V21 C47 34 41 41 32 41 C23 41 17 34 17 21 Z", gold], ["M18 49 L23 45 H50 L45 49 Z", gold], ["M18 49 H45 V58 H18 Z", gold]], P, T, 3.4, [3, 2.5]);
      const handles = `<g transform="${T}"><path d="M19 13 C7 13 8 30 21 31 M45 13 C57 13 56 30 43 31" fill="none" stroke="${INK}" stroke-width="7" stroke-linecap="round"/><path d="M19 13 C7 13 8 30 21 31 M45 13 C57 13 56 30 43 31" fill="none" stroke="${gold}" stroke-width="3.6" stroke-linecap="round"/><path d="${star4(31, 22, 8, 2.4)}" fill="#FFFFFF"/></g>`;
      const ribbon = (x, y, dir, c) => `<path d="M${f(x)} ${f(y)} C${f(x + dir * 6)} ${f(y + 6)} ${f(x + dir * 2)} ${f(y + 12)} ${f(x + dir * 9)} ${f(y + 17)}" fill="none" stroke="${INK}" stroke-width="5.4" stroke-linecap="round"/><path d="M${f(x)} ${f(y)} C${f(x + dir * 6)} ${f(y + 6)} ${f(x + dir * 2)} ${f(y + 12)} ${f(x + dir * 9)} ${f(y + 17)}" fill="none" stroke="${c}" stroke-width="3" stroke-linecap="round"/>`;
      return k.glow(tx, ty, 46, gold, 0.55) + k.rays(tx, ty, 14, 9, 30, 40, 3, [gold, "#FFF1B8"]) +
        block(k, 28, 80, 42, 22, 8, "1", P) + fig.svg +
        ribbon(tx - 9.5, ty - 4, -1, P) + ribbon(tx + 9.5, ty - 4, 1, C) + handles + cup +
        k.dots(tx, ty, 10, 18, 34, [gold, "#FFFFFF"], 2) + k.glint(tx + 14, ty - 12, 7) + k.glint(16, 50, 5) + k.glint(86, 50, 5);
    },
  },
  {
    name: "Podium Rise", rarity: "Legendary", rar: "#FFB428",
    moves: "The 1st block erupts out of the ground on glowing gold cracks into a gold spotlight, arms spread.",
    draw: (k) => {
      const G = "#FFCF3A", pale = "#FFF1B8";
      const beam = k.id();
      k.def(`<linearGradient id="${beam}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pale}" stop-opacity=".9"/><stop offset=".7" stop-color="${G}" stop-opacity=".35"/><stop offset="1" stop-color="${G}" stop-opacity=".1"/></linearGradient>`);
      const fig = figure(k, { x: 51.5, y: 30, s: 0.82, armL: [128, 10], armR: [-128, -10], legL: [7, 0], legR: [-7, 0], shadow: "#8A5A00", color: G, pin: ["feet", 45.5] });
      let rubble = "";
      for (let i = 0; i < 9; i++) {
        const x = between(8, 92), y = between(56, 92), s = between(2.5, 5);
        rubble += k.solid([[poly([[x - s, y], [x - s * 0.3, y - s], [x + s, y - s * 0.4], [x + s * 0.6, y + s * 0.7]]), "#9AA2B8"]], "#4A4F5E", "", 1.4, [1, 1]);
      }
      return `<rect x="-10" y="-10" width="120" height="120" fill="#000" opacity=".35"/>` +
        `<path d="M40 -6 H58 L80 100 H18 Z" fill="url(#${beam})"/>` +
        k.oval(48, 92, 46, 10, G, 0.7) +
        k.light("M6 94 L16 90 L24 95 L34 91 M62 91 L72 95 L80 90 L94 94 M30 96 L26 100 M70 96 L74 100", G, 1.6) +
        block(k, 30, 48, 34, 48, 9, "1", "#8A5A00", G) + rubble +
        k.oval(48, 98, 40, 6, "#C2C8D8", 0.5) + fig.svg +
        k.dots(48, 36, 14, 8, 44, [G, pale], 1.8) + k.glint(48, 4, 7) + k.glint(80, 24, 5);
    },
  },
  {
    name: "Thunderstorm", rarity: "Legendary", rar: "#FFB428",
    moves: "Under a dark storm cloud the big bolt hits; the winner hangs in the air, arms out, arcs crackling.",
    draw: (k) => {
      const B = "#A0D8FF";
      const fig = figure(k, { x: 53, y: 56, s: 0.9, armL: [110, 14], armR: [-110, -14], legL: [10, 8], legR: [-10, -8], shadow: "#3B6FA8", color: B, pin: ["feet", 70] });
      let rain = "";
      for (let i = 0; i < 16; i++) { const x = between(-4, 104), y = between(18, 96); rain += `<path d="M${f(x)} ${f(y)} l-3 8" stroke="${B}" stroke-width="1" stroke-opacity=".55" stroke-linecap="round"/>`; }
      const cloud = "M-6 26 C-8 14 6 8 14 12 C16 2 32 -2 38 6 C44 -4 62 -2 66 8 C74 0 92 4 92 14 C102 12 110 20 104 28 C80 32 20 32 -6 26 Z";
      return `<rect x="-10" y="-10" width="120" height="120" fill="#0A1430" opacity=".45"/>` + rain +
        k.glow(50, 50, 50, B, 0.45) +
        block(k, 28, 80, 42, 22, 8, "1", "#3B6FA8") +
        k.light("M28 80 H70 L78 75.6", B, 1.8) +
        k.solid([[cloud, "#3B4766"]], "#1C2338", "", 2.4, [0, 2.5]) + `<path d="M4 25 C30 29 70 29 98 25" fill="none" stroke="#56648A" stroke-width="3" stroke-linecap="round"/>` +
        k.light("M60 26 L48 36 L58 40 L" + f(fig.top[0]) + " " + f(fig.top[1] - 1), B, 3.6) +
        fig.svg +
        k.light(`M${f(fig.handL[0])} ${f(fig.handL[1])} L${f(fig.handL[0] - 3)} ${f(fig.handL[1] + 7)} L${f(fig.handL[0] + 1)} ${f(fig.handL[1] + 12)} L34 79`, B, 1.2) +
        k.light(`M${f(fig.handR[0])} ${f(fig.handR[1])} L${f(fig.handR[0] + 3)} ${f(fig.handR[1] + 7)} L${f(fig.handR[0] - 1)} ${f(fig.handR[1] + 12)} L70 78`, B, 1.2) +
        k.flare(fig.top[0], fig.top[1], 9, B) + k.dots(53, 60, 10, 18, 36, [B, "#FFFFFF"], 1.8);
    },
  },
  {
    name: "Throne", rarity: "Legendary", rar: "#FFB428",
    moves: "Lounging on the big gold throne in purple velvet, legs crossed, chin on a fist, the crown floating above.",
    draw: (k) => {
      const U = "#6A2BBF", P = "#FF3E8A", gold = "#FFD60A", goldD = "#C99200";
      const throne = k.solid([
        ["M20 18 L30 8 L40 14 L50 2 L60 14 L70 8 L80 18 L80 70 L20 70 Z", gold],
        ["M28 20 H72 V64 H28 Z", U],
        ["M22 92 V70 H30 V92 Z", goldD], ["M70 92 V70 H78 V92 Z", goldD],
        ["M18 64 H82 V74 H18 Z", gold],
        ["M10 46 H26 V54 H10 Z", gold], ["M74 46 H90 V54 H74 Z", gold],
        ["M26 58 H74 V65 H26 Z", P],
      ], "#3A1670", "", 2.4, [2.4, 2]);
      const gems = `<circle cx="50" cy="9" r="2.4" fill="${P}" stroke="${INK}" stroke-width="1.2"/><circle cx="30" cy="14" r="1.6" fill="#22D3EE" stroke="${INK}" stroke-width="1"/><circle cx="70" cy="14" r="1.6" fill="#22D3EE" stroke="${INK}" stroke-width="1"/>`;
      const fig = figure(k, { x: 52, y: 44, s: 0.92, rot: -8, armL: [84, -70], armR: [-40, 150], legL: [-62, 70], legR: [-82, 92], shadow: "#3A1670", color: P, pin: ["hips", 59] });
      const cx = fig.head[0], cy = fig.top[1] - 9;
      const crown = k.solid([[`M${cx - 9} ${cy + 4} L${cx - 10} ${cy - 5} L${cx - 4.5} ${cy - 1} L${cx} ${cy - 8} L${cx + 4.5} ${cy - 1} L${cx + 10} ${cy - 5} L${cx + 9} ${cy + 4} Z`, gold]], P, "", 2, [1.6, 1.4]);
      return k.glow(50, 40, 52, U, 0.6) + throne + gems + fig.svg + k.glow(cx, cy, 16, gold, 0.6) + crown + k.glint(cx + 10, cy - 7, 5) +
        k.dots(cx, cy, 6, 8, 16, [gold], 1.6) + k.glint(10, 20, 5) + k.glint(90, 30, 4);
    },
  },
  {
    name: "Meteor Touchdown", rarity: "Legendary", rar: "#FFB428",
    moves: "Slammed down from the sky on a fire trail into a three-point landing: the block cracked and glowing, a ring of fire, embers.",
    draw: (k) => {
      const O = "#FFB43C", R = "#FF4A1C";
      const fig = figure(k, { x: 51, y: 60, s: 0.9, rot: 8, armL: [118, -30], armR: [-12, 0], legL: [72, -112], legR: [-58, 100], face: false, shadow: "#7A1E00", color: O, pin: ["feet", 77.8] });
      let flames = "";
      for (let i = 0; i < 7; i++) { const x = 10 + i * 13 + between(-3, 3), h = between(8, 14); flames += k.solid([[`M${f(x - 4)} 82 C${f(x - 4)} ${f(82 - h * 0.6)} ${f(x)} ${f(82 - h * 0.7)} ${f(x + 1)} ${f(82 - h)} C${f(x + 3)} ${f(82 - h * 0.6)} ${f(x + 5)} ${f(82 - h * 0.4)} ${f(x + 4)} 82 Z`, i % 2 ? O : R]], "#7A1E00", "", 1.4, [1, 1]); }
      return k.glow(50, 70, 52, R, 0.5) +
        k.streak(108, -16, 52, 50, 18, R, false) + k.streak(102, -10, 52, 50, 12, O, false) + k.streak(96, -2, 52, 50, 6, "#FFF08C", false) +
        k.light(ellipsePath(53, 80, 46, 9), O, 3.2) + flames +
        block(k, 28, 80, 42, 22, 8, "1", "#7A1E00") +
        k.light("M30 81 L38 86 L36 92 M47 80 L45 87 L50 93 M60 81 L56 88 L62 95", O, 1.4) +
        k.solid([[poly([[28, 80], [33, 80], [28, 86]]), "#2B2B35"], [poly([[65, 80], [70, 80], [70, 87]]), "#2B2B35"]], "#7A1E00", "", 1.2, [0.6, 0.6]) +
        fig.svg + k.flare(fig.handR[0], 78, 10, O) +
        k.dots(48, 60, 14, 14, 44, [O, R, "#FFF08C"], 1.8) + k.oval(70, 40, 12, 8, "#6A6F7E", 0.5) + k.oval(24, 46, 10, 7, "#6A6F7E", 0.45);
    },
  },
  {
    name: "Chrysalis", rarity: "Iridescent", rar: "#FF5078", holo: true,
    moves: "Burst from the cocoon on huge morpho wings, hovering over the overgrown stage, butterflies all round.",
    draw: (k) => {
      const deep = "#1446DC", blue = "#288CFF", violet = "#8C50FF", teal = "#28DCD2";
      const wing = (d, x1, y1, x2, y2) => { const g = k.id(); k.def(`<linearGradient id="${g}" gradientUnits="userSpaceOnUse" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"><stop offset="0" stop-color="${deep}"/><stop offset=".45" stop-color="${blue}"/><stop offset=".75" stop-color="${violet}"/><stop offset="1" stop-color="${teal}"/></linearGradient>`); return `<path d="${d}" fill="url(#${g})" stroke="${INK}" stroke-width="2.2" stroke-linejoin="round"/><path d="${d}" fill="none" stroke="${teal}" stroke-width="1" stroke-opacity=".9"/>`; };
      const mirror = (d) => d.replace(/(-?\d+(\.\d+)?) (-?\d+(\.\d+)?)/g, (m, x, _a, y) => `${f(100 - x)} ${y}`);
      const UP = "M50 40 C52 22 70 6 94 6 C100 18 92 36 74 46 C64 50 56 46 50 44 Z";
      const LO = "M50 46 C60 48 78 54 82 70 C80 80 68 80 60 70 C54 62 51 54 50 48 Z";
      const veins = `<path d="M50 42 L88 12 M50 42 L80 32 M50 47 L76 68 M50 47 L66 74" stroke="#0A1A4A" stroke-width="1" stroke-opacity=".7" fill="none"/>`;
      const eyes = (x) => `<circle cx="${x}" cy="66" r="4" fill="#0A1A4A" stroke="${INK}" stroke-width="1"/><circle cx="${x}" cy="66" r="2.4" fill="${teal}"/><circle cx="${f(x - 0.6)}" cy="65.3" r=".8" fill="#FFFFFF"/>`;
      const fly = (x, y, s, c, r) => `<g transform="translate(${x} ${y}) rotate(${r}) scale(${s})"><path d="M0 0 C-6 -9 -14 -6 -11 1 C-8 5 -3 3 0 1 Z M0 0 C6 -9 14 -6 11 1 C8 5 3 3 0 1 Z" fill="${c}" stroke="${INK}" stroke-width="1.2"/><path d="M0 1 C-4 6 -8 9 -5 11 C-2 12 -1 6 0 2 Z M0 1 C4 6 8 9 5 11 C2 12 1 6 0 2 Z" fill="${c}" stroke="${INK}" stroke-width="1.2"/><path d="M0 -3 V8" stroke="${INK}" stroke-width="1.6" stroke-linecap="round"/></g>`;
      const flower = (x, y, c) => [0, 72, 144, 216, 288].map((a) => `<circle cx="${f(x + Math.cos(rad(a)) * 2.6)}" cy="${f(y + Math.sin(rad(a)) * 2.6)}" r="2.2" fill="${c}" stroke="${INK}" stroke-width=".8"/>`).join("") + `<circle cx="${x}" cy="${y}" r="1.4" fill="#FFD60A"/>`;
      const leaf = (x, y, a, s, c) => `<path d="M0 0 C${3 * s} ${-3 * s} ${8 * s} ${-3 * s} ${10 * s} 0 C${8 * s} ${3 * s} ${3 * s} ${3 * s} 0 0 Z" transform="translate(${x} ${y}) rotate(${a})" fill="${c}" stroke="${INK}" stroke-width="1"/>`;
      const fig = figure(k, { x: 50, y: 48, s: 0.74, armL: [124, 20], armR: [-124, -20], legL: [6, 0], legR: [-6, 0], shadow: violet, color: blue });
      let flakes = "";
      for (let i = 0; i < 10; i++) flakes += `<circle cx="${f(between(6, 94))}" cy="${f(between(4, 70))}" r="${f(between(0.8, 1.6))}" fill="#F4F0FF" opacity=".85"/>`;
      return k.glow(50, 44, 54, blue, 0.55) + k.glow(50, 44, 26, violet, 0.5) +
        wing(UP, 50, 42, 94, 8) + wing(mirror(UP), 50, 42, 6, 8) + wing(LO, 50, 46, 82, 76) + wing(mirror(LO), 50, 46, 18, 76) +
        veins + `<g transform="translate(100 0) scale(-1 1)">${veins}</g>` + eyes(72) + eyes(28) +
        `<path d="M10 100 C14 86 30 84 50 86 C70 84 86 86 90 100 Z" fill="#3C6E28" stroke="${INK}" stroke-width="1.6"/>` +
        leaf(18, 90, -40, 1.2, "#5AA032") + leaf(30, 88, -70, 1, "#78BE3C") + leaf(70, 88, -110, 1, "#5AA032") + leaf(84, 90, -140, 1.2, "#78BE3C") + leaf(46, 88, -95, 0.9, "#78BE3C") +
        flower(24, 86, "#FFFFFF") + flower(40, 84, "#FFB6D9") + flower(62, 85, "#C9A8FF") + flower(78, 86, "#FFFFFF") +
        fig.svg + flakes +
        fly(14, 26, 0.7, teal, -20) + fly(86, 30, 0.6, violet, 15) + fly(20, 66, 0.55, blue, -10) + fly(84, 76, 0.5, teal, 20) + fly(fig.handR[0] + 2, fig.handR[1] - 4, 0.42, blue, 10) +
        k.glint(50, 8, 5);
    },
  },
  {
    name: "Rift", rarity: "Iridescent", rar: "#FF5078", holo: true,
    moves: "Pulled through a pink tear into deep space: floating over the green planet as the pink supernova erupts behind.",
    draw: (k) => {
      const P = "#FF4096", pale = "#FFD7EB";
      let tear = "";
      const n = 22;
      for (let i = 0; i < n; i++) { const a = rad(i * 360 / n - 90), r = i % 2 ? 0.86 : 1; tear += (i ? "L" : "M") + f(50 + Math.cos(a) * 38 * r) + " " + f(50 + Math.sin(a) * 48 * r) + " "; }
      tear += "Z";
      const clip = k.id(), space = k.id(), planet = k.id();
      k.def(`<clipPath id="${clip}"><path d="${tear}"/></clipPath><radialGradient id="${space}" cx=".4" cy=".35"><stop offset="0" stop-color="#2A1650"/><stop offset="1" stop-color="#05061A"/></radialGradient><radialGradient id="${planet}" cx=".5" cy=".1"><stop offset="0" stop-color="#7FD02A"/><stop offset=".35" stop-color="#2E6A12"/><stop offset="1" stop-color="#081505"/></radialGradient>`);
      let stars = "";
      for (let i = 0; i < 26; i++) stars += `<circle cx="${f(between(10, 90))}" cy="${f(between(4, 70))}" r="${f(between(0.3, 0.9))}" fill="#FFFFFF" opacity="${f(between(0.5, 1))}"/>`;
      let points = "";
      for (let i = 0; i < 22; i++) { const a = rand() * Math.PI * 2, r = between(6, 40); points += `<circle cx="${f(30 + Math.cos(a) * r)}" cy="${f(28 + Math.sin(a) * r * 0.8)}" r="${f(between(0.6, 2.2))}" fill="${i % 3 ? P : pale}" opacity="${f(between(0.45, 0.95))}"/>`; }
      const fig = figure(k, { x: 56, y: 56, s: 0.66, rot: -24, armL: [112, 16], armR: [-104, -24], legL: [24, 10], legR: [-30, -16], shadow: P, color: P });
      const inside = `<rect x="0" y="0" width="100" height="100" fill="url(#${space})"/>` + stars +
        `<circle cx="50" cy="132" r="56" fill="url(#${planet})"/>` + `<path d="M-6 92 A56 56 0 0 1 106 92" fill="none" stroke="#B4FF3C" stroke-width="2.2" stroke-opacity=".9"/>` + k.oval(50, 80, 60, 10, "#B4FF3C", 0.25) +
        k.glow(30, 28, 34, P, 0.55) + k.rays(30, 28, 12, 4, 18, 28, 2.4, [P, pale]) + points + k.flare(30, 28, 12, P) +
        k.streak(96, 6, 38, 26, 2.2, P) + fig.svg;
      return k.glow(50, 50, 56, P, 0.4) + `<g clip-path="url(#${clip})">${inside}</g>` +
        k.light(tear, P, 2.4) + k.dots(50, 50, 10, 42, 50, [P, pale], 1.6) + k.glint(86, 12, 5) + k.glint(14, 88, 4);
    },
  },
];


// { iconName: svg } for every victory.
export function icons() {
  const out = {};
  for (const e of VICTORIES) {
    reseed(e.name);
    out["victory" + e.name.replace(/ /g, "")] = makeIcon(e.draw);
  }
  return out;
}
