// The tag effect icons: one picture per tag effect (client/CosmeticEffects), in the item's colours.
// Each entry draws into a 100 x 100 SVG with makeIcon. render.mjs saves them as icons named
// "tag" + the look's Effect (tagClassic, tagLightning...).
const INK = "#111111";
const f = (n) => +n.toFixed(2);
let seed = 7;
const rand = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
const between = (a, b) => a + (b - a) * rand();
const reseed = (name) => { seed = [...name].reduce((h, ch) => (h * 31 + ch.charCodeAt(0)) % 2147483646, 11) + 1; };
function lerpHex(a, b, t) {
  const pa = [1, 3, 5].map((i) => parseInt(a.slice(i, i + 2), 16));
  const pb = [1, 3, 5].map((i) => parseInt(b.slice(i, i + 2), 16));
  return "#" + pa.map((v, i) => Math.round(v + (pb[i] - v) * t).toString(16).padStart(2, "0")).join("");
}
const rad = (deg) => deg * Math.PI / 180;

// Every icon is drawn into one 100 x 100 SVG. Gradients need ids unique on the page.
let uid = 0;
function makeIcon(draw) {
  const defs = [];
  const id = () => "g" + (++uid);
  const k = {
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
    // A light: white-hot middle, coloured glow round it.
    flare(cx, cy, r, c) {
      const g = id();
      defs.push(`<radialGradient id="${g}"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".3" stop-color="#FFFFFF" stop-opacity=".95"/><stop offset=".55" stop-color="${c}" stop-opacity=".85"/><stop offset="1" stop-color="${c}" stop-opacity="0"/></radialGradient>`);
      return `<circle cx="${f(cx)}" cy="${f(cy)}" r="${f(r)}" fill="url(#${g})"/>`;
    },
    // A comet streak: fades in from its tail (x1, y1) to a round head (x2, y2) `w` wide.
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
    // A curved spark trail (a quadratic curve) ending in a hot head.
    arcSpark(x1, y1, qx, qy, x2, y2, w, c) {
      const g = id();
      defs.push(`<linearGradient id="${g}" gradientUnits="userSpaceOnUse" x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}"><stop offset="0" stop-color="${c}" stop-opacity="0"/><stop offset="1" stop-color="${c}" stop-opacity="1"/></linearGradient>`);
      return `<path d="M${f(x1)} ${f(y1)} Q${f(qx)} ${f(qy)} ${f(x2)} ${f(y2)}" fill="none" stroke="url(#${g})" stroke-width="${f(w)}" stroke-linecap="round"/>` + k.flare(x2, y2, w * 2.2, c);
    },
    // A four-point glint.
    glint(cx, cy, R, c = "#FFFFFF") {
      return k.glow(cx, cy, R * 1.1, c, 0.45) + `<path d="${star4(cx, cy, R, R * 0.16)}" fill="#FFFFFF"/>`;
    },
    // A solid thing in the icon style: ink outline and a hard offset shadow.
    solid(parts, shadow, transform = "", stroke = 3.4, off = [3.8, 3.2]) {
      const back = parts.map(([d]) => `<path d="${d}" fill="${shadow}" stroke="${shadow}" stroke-width="${stroke}" stroke-linejoin="round"/>`).join("");
      const front = parts.map(([d, fill]) => `<path d="${d}" fill="${fill}" stroke="${INK}" stroke-width="${stroke}" stroke-linejoin="round"/>`).join("");
      return `<g transform="${transform}"><g transform="translate(${off[0]} ${off[1]})">${back}</g>${front}</g>`;
    },
    // A glowing line (a ring or a bolt): wide soft glow, the colour, a white-hot core.
    light(d, c, w) {
      return `<path d="${d}" fill="none" stroke="${c}" stroke-width="${f(w * 2.6)}" stroke-opacity=".22" stroke-linejoin="round" stroke-linecap="round"/>` +
        `<path d="${d}" fill="none" stroke="${c}" stroke-width="${f(w)}" stroke-linejoin="round" stroke-linecap="round"/>` +
        `<path d="${d}" fill="none" stroke="#FFFFFF" stroke-width="${f(w * 0.38)}" stroke-linejoin="round" stroke-linecap="round"/>`;
    },
  };
  const body = draw(k);
  return `<svg class="art" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs>${defs.join("")}</defs><g transform="translate(50 50) skewX(-8) translate(-50 -50)">${body}</g></svg>`;
}

function spiky(cx, cy, R, r, n, jitter) {
  let d = "";
  for (let i = 0; i < n * 2; i++) {
    const a = rad(-90 + i * 180 / n);
    const rr = i % 2 ? r : R * (1 - (jitter || 0) * ((i * 7) % 5) / 5);
    d += (i ? "L" : "M") + f(cx + Math.cos(a) * rr) + " " + f(cy + Math.sin(a) * rr) + " ";
  }
  return d + "Z";
}
const star4 = (cx, cy, R, r) => spiky(cx, cy, R, r, 4, 0);
const HEART = "M50 88 C22 70 9 54 9 36 C9 22 20 13 32 13 C40 13 46 18 50 24 C54 18 60 13 68 13 C80 13 91 22 91 36 C91 54 78 70 50 88 Z";
const place = (cx, cy, size, rot) => `translate(${cx} ${cy}) rotate(${rot}) scale(${size / 100}) translate(-50 -50)`;
const ellipsePath = (cx, cy, rx, ry) => `M${cx - rx} ${cy} a${rx} ${ry} 0 1 0 ${2 * rx} 0 a${rx} ${ry} 0 1 0 ${-2 * rx} 0`;
const quad = (cx, cy, w, h, deg) => { const a = rad(deg), c = Math.cos(a), s = Math.sin(a); return [[-w / 2, -h / 2], [w / 2, -h / 2], [w / 2, h / 2], [-w / 2, h / 2]].map(([x, y], i) => `${i ? "L" : "M"}${f(cx + x * c - y * s)} ${f(cy + x * s + y * c)}`).join(" ") + " Z"; };

// Radiating streaks from (cx, cy): n of them, `flat` squashes them into a ground plane.
function rays(k, cx, cy, n, r0, r1a, r1b, w, colors, flat = 1, start = 0) {
  let out = "";
  for (let i = 0; i < n; i++) {
    const a = rad(start + i * 360 / n + between(-9, 9));
    const r1 = between(r1a, r1b);
    out += k.streak(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0 * flat, cx + Math.cos(a) * r1, cy + Math.sin(a) * r1 * flat, between(w * 0.7, w * 1.15), colors[i % colors.length]);
  }
  return out;
}
// Loose sparks (hot dots) round (cx, cy) between radii r0 and r1.
function dots(k, cx, cy, n, r0, r1, colors, size = 2.6, flat = 1) {
  let out = "";
  for (let i = 0; i < n; i++) {
    const a = rand() * Math.PI * 2, r = between(r0, r1);
    out += k.flare(cx + Math.cos(a) * r, cy + Math.sin(a) * r * flat, between(size * 0.7, size * 1.3), colors[i % colors.length]);
  }
  return out;
}

const EFFECTS = [
  {
    name: "Classic", rarity: "Common", rar: "#AAB4BE",
    moves: "A red spark explosion: hot red streaks blasting out of a white flash.",
    draw: (k) => {
      const R = "#FF5050";
      return k.glow(50, 50, 50, R, 0.55) +
        rays(k, 50, 50, 14, 7, 30, 47, 4.6, [R]) +
        dots(k, 50, 50, 14, 32, 48, [R, "#FF9090"], 3) +
        k.flare(50, 50, 20, R) +
        k.glint(22, 22, 9) + k.glint(80, 30, 7) + k.glint(72, 80, 6);
    },
  },
  {
    name: "Pop", rarity: "Common", rar: "#AAB4BE",
    moves: "A ring of white light snapping out across the ground, sparks popping up off it.",
    draw: (k) => {
      const W = "#FFFFFF";
      let pops = "";
      for (let i = 0; i < 12; i++) {
        const a = rad(i * 30 + 15), x = 50 + Math.cos(a) * 43, y = 62 + Math.sin(a) * 14;
        pops += k.streak(50 + Math.cos(a) * 36, 62 + Math.sin(a) * 11.5, x + Math.cos(a) * 6, y + Math.sin(a) * 4, 1.6, W, false);
      }
      let ups = "";
      for (let i = 0; i < 9; i++) {
        const a = rad(-160 + i * 17.5 + between(-5, 5)), L = between(30, 50);
        ups += k.streak(50 + Math.cos(a) * 6, 58 + Math.sin(a) * 4, 50 + Math.cos(a) * L, 58 + Math.sin(a) * L * 0.95, between(2, 3.2), W);
      }
      return k.glow(50, 56, 50, W, 0.28) +
        k.light(ellipsePath(50, 62, 30, 9.5), W, 2.2) +
        k.light(ellipsePath(50, 62, 44, 14), W, 5) +
        pops + ups +
        k.flare(50, 58, 15, "#DDE6FF") +
        k.glint(20, 30, 7) + k.glint(80, 22, 8);
    },
  },
  {
    name: "Sparks", rarity: "Common", rar: "#AAB4BE",
    moves: "A gold fountain: sparks shooting up and out, curving over and falling.",
    draw: (k) => {
      const G = "#FFC850", O = "#FF9A2E";
      let arcs = "";
      for (let i = 0; i < 16; i++) {
        const a = rad(-170 + i * (160 / 15) + between(-4, 4));
        const L = between(30, 46), drop = between(8, 30);
        const ex = 50 + Math.cos(a) * L, ey = 52 + Math.sin(a) * L * 0.55 + drop;
        const qx = 50 + Math.cos(a) * L * 0.55, qy = 52 + Math.sin(a) * L * 1.05 - 10;
        arcs += k.arcSpark(50, 52, qx, qy, ex, ey, between(1.6, 2.8), i % 3 ? G : O);
      }
      return k.glow(50, 48, 50, G, 0.5) + arcs +
        k.flare(50, 52, 18, G) + k.glint(30, 16, 8) + k.glint(74, 22, 7) + k.glint(50, 8, 5);
    },
  },
  {
    name: "Hearts", rarity: "Rare", rar: "#3C96FF",
    moves: "A flurry of pink and white hearts rising and spreading out.",
    draw: (k) => {
      const P = "#FF5A96", PD = "#A0175A";
      const H = [[56, 12, 13, 6, 0], [16, 58, 14, -10, 1], [80, 74, 17, 12, 1], [22, 25, 21, -18, 0], [73, 33, 30, 14, 1], [42, 58, 50, -8, 0]];
      let out = k.glow(48, 52, 50, P, 0.5);
      for (const [x, y, s] of H) out += k.streak(x - s * 0.1, y + s * 0.9 + 10, x, y + s * 0.35, s * 0.18, P, false);
      for (const [x, y, s, r, white] of H) {
        const shine = `<path d="M22 32 C23 25 27 21 33 21" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/>`;
        out += white ? k.solid([[HEART, "#FFFFFF"]], P, place(x, y, s, r), 340 / s, [380 / s, 320 / s])
          : k.solid([[HEART, P]], PD, place(x, y, s, r), 340 / s, [380 / s, 320 / s]) + `<g transform="${place(x, y, s, r)}">${shine}</g>`;
      }
      return out + k.glint(86, 14, 6) + k.glint(10, 84, 5) + k.glint(64, 90, 4);
    },
  },
  {
    name: "Stars", rarity: "Rare", rar: "#3C96FF",
    moves: "A cluster of yellow and white stars twinkling up and outward.",
    draw: (k) => {
      const Y = "#FFF078", YD = "#C98A00";
      const S = [[56, 12, 14, 10, 1], [14, 56, 16, -6, 1], [82, 74, 18, 20, 0], [22, 24, 24, -12, 0], [74, 32, 32, 8, 1], [42, 58, 52, 0, 0]];
      let out = k.glow(48, 52, 50, Y, 0.5);
      for (const [x, y, s] of S) out += k.streak(x - s * 0.08, y + s * 0.9 + 8, x, y + s * 0.3, s * 0.14, Y, false);
      for (const [x, y, s, r, white] of S) {
        const fill = white ? "#FFFFFF" : Y, inner = white ? Y : "#FFFFFF";
        out += k.solid([[star4(50, 50, 48, 13), fill], [star4(50, 50, 20, 6), inner]], white ? Y : YD, place(x, y, s, r), 340 / s, [380 / s, 320 / s]);
      }
      return out + k.glint(88, 14, 6) + k.glint(8, 86, 5) + k.glint(62, 90, 4);
    },
  },
  {
    name: "Pow", rarity: "Rare", rar: "#3C96FF",
    moves: "The comic TAG! burst slamming in, red sparks flying off it.",
    draw: (k) => {
      const Y = "#FFD60A", R = "#E3242B";
      const text = `<text x="50" y="59" text-anchor="middle" transform="rotate(-8 50 50)" font-family="Bangers, Impact, sans-serif" font-size="27" fill="${Y}" stroke="${R}" stroke-width="5.5" paint-order="stroke" letter-spacing="1">TAG!</text>`;
      return k.glow(50, 50, 50, Y, 0.5) +
        rays(k, 50, 50, 12, 24, 44, 50, 3.6, [R], 1, 15) +
        k.solid([[spiky(50, 50, 45, 29, 12, 0.3), Y], [spiky(50, 50, 30, 20.5, 12, 0.15), "#FFFFFF"]], R) + text +
        dots(k, 50, 50, 8, 40, 48, [R], 2.4);
    },
  },
  {
    name: "Confetti", rarity: "Epic", rar: "#AA50FF",
    moves: "An explosion of gold, red and purple confetti and streamers.",
    draw: (k) => {
      const cols = ["#FFD23C", "#FF5A5A", "#AA50FF"];
      let out = k.glow(50, 50, 50, "#FFD23C", 0.42);
      out += rays(k, 50, 50, 10, 6, 26, 38, 2.6, ["#FFE9A0"]);
      const ribbons = [["M50 50 C44 40 34 44 30 34 C26 24 34 18 26 8", cols[2]], ["M50 50 C60 44 66 52 74 46 C82 40 80 30 90 26", cols[1]], ["M50 50 C46 60 36 60 32 70 C28 80 36 86 30 94", cols[0]]];
      for (const [d, c] of ribbons) out += `<path d="${d}" fill="none" stroke="${INK}" stroke-width="7" stroke-linecap="round"/><path d="${d}" fill="none" stroke="${c}" stroke-width="3.8" stroke-linecap="round"/>`;
      const pieces = [];
      for (let i = 0; i < 34; i++) {
        const a = rand() * Math.PI * 2, r = between(12, 46);
        pieces.push([50 + Math.cos(a) * r, 50 + Math.sin(a) * r, between(7, 10.5), between(4, 6) * between(0.35, 1), between(0, 180), lerpHex(cols[i % 3], cols[(i + 1) % 3], rand() * 0.6)]);
      }
      for (const [x, y, w, h, r, c] of pieces) out += k.solid([[quad(x, y, w, h, r), c]], INK, "", 1.4, [1.2, 1.2]);
      return out + k.flare(50, 50, 9, "#FFD23C") + k.glint(84, 80, 5);
    },
  },
  {
    name: "Shockwave", rarity: "Epic", rar: "#AA50FF",
    moves: "A cyan ring tearing across the ground and a purple one above it, energy spraying out.",
    draw: (k) => {
      const C = "#19E3FF", U = "#AA50FF";
      return k.glow(50, 58, 50, C, 0.45) +
        k.oval(50, 50, 22, 40, C, 0.35) +
        rays(k, 50, 58, 16, 10, 40, 50, 3, [C, U], 0.62) +
        k.light(ellipsePath(50, 70, 46, 13), C, 5.5) +
        k.light(ellipsePath(50, 44, 33, 9.5), U, 4.5) +
        dots(k, 50, 56, 12, 30, 48, [C, U], 2.4, 0.7) +
        k.flare(50, 66, 14, C) + k.glint(18, 20, 7) + k.glint(84, 24, 6);
    },
  },
  {
    name: "Thunderstrike", rarity: "Legendary", rar: "#FFB428",
    moves: "A forked light-blue bolt cracking down and blasting sparks off the ground.",
    draw: (k) => {
      const B = "#96DCFF";
      const main = "M58 -4 L44 18 L60 30 L40 50 L57 62 L46 84";
      const fork1 = "M60 30 L74 38 L69 50 L80 58", fork2 = "M40 50 L27 58 L31 69";
      let up = "";
      for (let i = 0; i < 12; i++) {
        const a = rad(-175 + i * 15 + between(-5, 5)), L = between(14, 34);
        up += k.streak(46 + Math.cos(a) * 3, 85 + Math.sin(a) * 2, 46 + Math.cos(a) * L, 85 + Math.sin(a) * L * 0.75, between(1.5, 2.4), B);
      }
      return k.glow(48, 78, 52, B, 0.5) + k.glow(52, 36, 40, B, 0.28) +
        k.oval(46, 87, 32, 8, B, 0.7) + up +
        k.light(fork1, B, 2.6) + k.light(fork2, B, 2.6) + k.light(main, B, 6) +
        k.flare(46, 84, 13, B) +
        k.light("M14 76 L18 72 L16 68 L21 64", B, 1.4) + k.light("M80 80 L76 76 L80 72", B, 1.4) +
        k.glint(20, 24, 7) + k.glint(84, 14, 6);
    },
  },
  {
    name: "Meteor", rarity: "Legendary", rar: "#FFB428",
    moves: "A fireball streaking down on a blazing trail, embers flying off it.",
    draw: (k) => {
      const pale = "#FFF08C", orange = "#FF781E", red = "#C82814";
      let embers = "";
      for (let i = 0; i < 14; i++) {
        const t = between(0.15, 0.85), off = between(-14, 14);
        embers += k.flare(4 + 60 * t + off * 0.7, 4 + 60 * t - off * 0.7, between(1.6, 3.2), i % 2 ? orange : pale);
      }
      return k.glow(62, 62, 46, orange, 0.55) +
        k.streak(-6, -6, 64, 64, 22, red, false) +
        k.streak(2, 2, 64, 64, 16, orange, false) +
        k.streak(14, 14, 64, 64, 9, pale, false) +
        k.streak(30, 2, 70, 50, 2.2, orange, false) + k.streak(2, 34, 52, 72, 2.2, orange, false) +
        embers +
        k.flare(64, 64, 22, orange) +
        `<circle cx="64" cy="64" r="9.5" fill="#FFFFFF"/>` +
        dots(k, 66, 66, 6, 18, 30, [orange, pale], 2.6) +
        k.glint(84, 30, 6) + k.glint(28, 82, 5);
    },
  },
  {
    name: "Shatter", rarity: "Iridescent", rar: "#FF5078", holo: true,
    moves: "The tagged player bursting apart into glowing holo glass shards.",
    draw: (k) => {
      const holo = ["#FF5078", "#FF9AD5", "#B48CFF", "#7CE8FF", "#9DFFCF", "#FFE08A"];
      const blocks = [[42, 9, 16, 16], [33, 28, 34, 32], [20, 29, 11, 29], [69, 29, 11, 29], [34, 61, 15, 29], [51, 61, 15, 29]];
      let out = k.glow(50, 50, 52, "#B48CFF", 0.5) + k.oval(50, 93, 36, 6, "#7CE8FF", 0.8);
      out += rays(k, 50, 48, 12, 18, 42, 50, 2.4, holo);
      let n = 0;
      for (const [x, y, w, h] of blocks) {
        const tris = [[[x, y], [x + w, y], [x, y + h]], [[x + w, y], [x + w, y + h], [x, y + h]]];
        for (const t of tris) {
          const cx = (t[0][0] + t[1][0] + t[2][0]) / 3, cy = (t[0][1] + t[1][1] + t[2][1]) / 3;
          const dx = cx - 50, dy = cy - 48, len = Math.hypot(dx, dy) || 1, push = between(3, 7);
          const ox = dx / len * push, oy = dy / len * push;
          const d = "M" + t.map(([px, py]) => `${f(px + ox)} ${f(py + oy)}`).join(" L") + " Z";
          out += k.solid([[d, holo[n++ % 6]]], "#FFFFFF", `rotate(${f(between(-8, 8))} ${f(cx + ox)} ${f(cy + oy)})`, 2.2, [1.6, 1.4]);
        }
      }
      for (let i = 0; i < 9; i++) {
        const a = rand() * Math.PI * 2, r = between(36, 46), x = 50 + Math.cos(a) * r, y = 50 + Math.sin(a) * r, s = between(4, 7);
        out += k.solid([[`M${f(x - s)} ${f(y - s * 0.6)} L${f(x + s)} ${f(y - s * 0.2)} L${f(x - s * 0.2)} ${f(y + s)} Z`, holo[i % 6]]], "#FFFFFF", "", 1.8, [1.2, 1]);
      }
      return out + k.glint(14, 16, 7) + k.glint(86, 22, 6) + k.glint(80, 84, 5);
    },
  },
];


const KEYS = { Thunderstrike: "Lightning" };
// { iconName: svg } for every tag effect.
export function icons() {
  const out = {};
  for (const e of EFFECTS) {
    reseed(e.name);
    out["tag" + (KEYS[e.name] || e.name)] = makeIcon(e.draw);
  }
  return out;
}
