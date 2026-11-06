// The object icons: menu pages, coins and shop items, small marks, quests and achievements.
// Street sprint style: objects in three-quarter view (a lit white front, a pale top, a grey side),
// ink outlines, the page colour on the details, the whole icon leaning forward, a hard offset
// shadow in the page colour (pink for the gold ones) and three speed lines on the left (not on
// the small controls). Drawn in 0-64 inside a 70-wide box; the outline and shadow match the tag
// effect and victory icons (3.4 and 3.8 x 3.2 in a 100 box).

const INK = "#111111";
const COL = { Y: "#FFD60A", P: "#FF2E88", C: "#19E3FF", L: "#7CFF4F", O: "#FF8A1F", U: "#AA50FF", G: "#9AA2B8" };
const OUTLINE = 2.4; // 3.4 in a 100 box
const SHADOW = [2.7, 2.25]; // 3.8 x 3.2 in a 100 box

const h2r = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const mix = (h, t, k) => "#" + h2r(h).map((v, i) => Math.round(v + (h2r(t)[i] - v) * k).toString(16).padStart(2, "0")).join("");
const f = (n) => +n.toFixed(2);
function star(cx, cy, R, r, n = 5, rot = -90) {
  let d = "";
  for (let i = 0; i < n * 2; i++) {
    const a = (rot + i * 180 / n) * Math.PI / 180, rad = i % 2 ? r : R;
    d += (i ? "L" : "M") + f(cx + Math.cos(a) * rad) + " " + f(cy + Math.sin(a) * rad) + " ";
  }
  return d + "Z";
}
const ell = (cx, cy, rx, ry) => `M${f(cx - rx)} ${f(cy)} a${f(rx)} ${f(ry)} 0 1 0 ${f(2 * rx)} 0 a${f(rx)} ${f(ry)} 0 1 0 ${f(-2 * rx)} 0 Z`;
const rel = (cx, cy, s, pts, cmd) => pts.map((p, i) => `${cmd[i]}${f(cx + p[0] * s)} ${f(cy + p[1] * s)}`).join(" ");
const shift = (d, dx, dy) => d.replace(/(\d+(\.\d+)?) (\d+(\.\d+)?)/g, (m, x, _a, y) => `${+x + dx} ${+y + dy}`);
function burst(cx, cy, s) {
  const R = [29, 27, 30, 26, 29, 27, 31, 26, 28, 27, 30, 25];
  let d = "";
  const n = R.length;
  for (let i = 0; i < n * 2; i++) {
    const a = (-90 + i * 180 / n) * Math.PI / 180, rad = (i % 2 ? 15.5 : R[i / 2]) * s;
    d += (i ? "L" : "M") + f(cx + Math.cos(a) * rad) + " " + f(cy + Math.sin(a) * rad) + " ";
  }
  return d + "Z";
}

// A coin standing up, `s` times the full-size coin.
function coinUp(a, cx, cy, s) {
  a.sh(ell(cx + 4 * s, cy + 2 * s, 21 * s, 25 * s), "goldD");
  a.sh(ell(cx, cy, 21 * s, 25 * s), "gold");
  a.ln2(ell(cx, cy, 15.5 * s, 19.5 * s), "goldM", Math.max(1.4, 2.4 * s));
  a.ln2(rel(cx, cy, s, [[6, -8], [-4, -13], [-10, -4], [-8, 3], [-6, 10], [1, 11], [6, 7]], ["M", "C", "", "", "C", "", ""]), "goldD", Math.max(2.6, 5 * s));
  a.ln2(rel(cx, cy, s, [[-16, -10], [-14, -16], [-10, -20], [-5, -22]], ["M", "C", "", ""]), "white", Math.max(1.6, 3 * s));
}
// A coin lying flat, seen from above.
function flatCoin(a, cx, cy, r, t = 4.5) {
  const ry = r * 0.45;
  a.sh(`M${f(cx - r)} ${f(cy)} A${f(r)} ${f(ry)} 0 0 0 ${f(cx + r)} ${f(cy)} V${f(cy + t)} A${f(r)} ${f(ry)} 0 0 1 ${f(cx - r)} ${f(cy + t)} Z`, "goldD");
  a.sh(ell(cx, cy, r, ry), "gold");
  a.ln2(ell(cx, cy, r * 0.66, ry * 0.62), "goldM", 1.6);
}

// Each icon: c the page colour, shadow the shadow colour (default c), speed false for no speed
// lines, draw(api).
export const ICONS = {
  // Set 1: menu pages, coins and shop.
  shop: { c: "Y", draw: (a) => {
    a.sh("M42 24 L52 19 L54 52 L44 58 Z", "side"); a.sh("M12 24 L42 24 L44 58 L10 58 Z", "front"); a.sh("M12 24 L22 19 L52 19 L42 24 Z", "top");
    a.ln("M19 27 C18 10 37 10 36 27", "P", 3.2); a.sh(star(26, 42, 9, 4.2), "P"); a.plain(ell(23.5, 39, 1.6, 1.6), "white"); a.ln("M47 26 L48 46", "sideD", 2);
  } },
  locker: { c: "C", draw: (a) => {
    a.sh("M40 11 L50 6 L50 53 L40 58 Z", "side"); a.sh("M14 11 L24 6 L50 6 L40 11 Z", "top"); a.sh("M14 11 H40 V58 H14 Z", "front");
    for (const y of [18, 24, 30]) a.ln(`M19 ${y} L35 ${y}`, "P", 2.6);
    a.sh("M33 37 H37 V50 H33 Z", "P"); a.sh(star(22, 46, 6, 2.8), "P"); a.ln("M44 14 L45 50", "sideD", 2);
  } },
  quests: { c: "P", draw: (a) => {
    a.sh("M46 12 L51 9 L51 55 L46 58 Z", "side"); a.sh("M13 12 H46 V58 H13 Z", "front"); a.sh("M23 6 H37 Q39 6 39 8 V15 H21 V8 Q21 6 23 6 Z", "P");
    [[0, 22], [1, 33], [2, 44]].forEach(([i, y]) => {
      a.sh(`M18 ${y} H26 V${y + 8} H18 Z`, "top"); a.plain(`M30 ${y + 2.5} H42 V${y + 5.5} H30 Z`, "side");
      if (i < 2) a.ln(`M18.5 ${y + 3.5} L22 ${y + 7} L29 ${y - 2}`, "P", 2.8);
    });
  } },
  rewards: { c: "L", draw: (a) => {
    a.sh("M38 31 L53 25 L53 52 L38 58 Z", "side"); a.sh("M11 31 H38 V58 H11 Z", "front");
    a.plain("M21.5 32 H27.5 V57 H21.5 Z", "P"); a.plain("M43.5 29.2 L47.5 27.6 L47.5 54.6 L43.5 56.2 Z", "P");
    a.sh("M40 24 L56 18 L56 26 L40 32 Z", "side"); a.sh("M8 24 H40 V32 H8 Z", "front"); a.sh("M8 24 L24 18 L56 18 L40 24 Z", "top");
    a.plain("M21 24 H28 V32 H21 Z", "P"); a.plain("M21 24 L28 24 L44 18 L37 18 Z", "P"); a.plain("M44.5 22 L48 20.7 L48 28.7 L44.5 30 Z", "P");
    a.sh("M32 21 C23 7 11 11 18 18.5 C21.5 22 27 21.5 32 21 Z", "P"); a.sh("M32 21 C41 7 53 11 46 18.5 C42.5 22 37 21.5 32 21 Z", "P"); a.sh(ell(32, 21, 3.4, 3), "PD");
  } },
  leaders: { c: "O", draw: (a) => {
    a.sh("M5 40 L10 36 L27 36 L22 40 Z", "top"); a.sh("M5 40 H22 V58 H5 Z", "front");
    a.sh("M40 30 L45 26 L45 54 L40 58 Z", "side"); a.sh("M22 30 L27 26 L45 26 L40 30 Z", "top"); a.sh("M22 30 H40 V58 H22 Z", "front");
    a.sh("M54 45 L59 41 L59 54 L54 58 Z", "side"); a.sh("M40 45 L45 41 L59 41 L54 45 Z", "top"); a.sh("M40 45 H54 V58 H40 Z", "front");
    a.ln("M28.5 39 L32 36.5 V51", "P", 3.2); a.sh("M24.5 23 L25.5 11 L30 16 L33.5 6.5 L37 16 L41.5 11 L42.5 23 Z", "P"); a.plain(ell(33.5, 19, 1.8, 1.8), "white");
  } },
  sound: { c: "U", draw: (a) => {
    a.sh("M7 25 H17 L31 13 V51 L17 39 H7 Z", "front"); a.sh(ell(31, 32, 4.5, 19), "side"); a.plain("M9 28 H15 V36 H9 Z", "top");
    a.ln("M40 24 C45 28 45 36 40 40", "P", 3.6); a.ln("M46 16 C55 24 55 40 46 48", "P", 3.6);
  } },
  crate: { c: "Y", draw: (a) => {
    a.sh("M38 26 L54 18 L54 50 L38 58 Z", "side"); a.sh("M8 26 L24 18 L54 18 L38 26 Z", "top"); a.sh("M8 26 H38 V58 H8 Z", "front");
    a.ln2("M12 30 H34 V54 H12 Z", "P", 2.6); a.ln2("M42 27 L50 23 V47 L42 51 Z", "P", 2.2);
    a.ln("M18 37 C18 29 29 29 29 36 C29 41 23 41 23 46", "P", 3.6); a.sh(ell(23, 51, 2.4, 2.4), "P");
  } },
  coin: { c: "Y", shadow: "P", draw: (a) => coinUp(a, 31, 31, 1) },
  coins2: { c: "Y", shadow: "P", draw: (a) => { coinUp(a, 23, 25, 0.62); coinUp(a, 38, 38, 0.74); } },
  coins3: { c: "Y", shadow: "P", draw: (a) => { for (const y of [52, 46, 40, 34]) flatCoin(a, 22, y, 15); coinUp(a, 43, 37, 0.68); } },
  coinPile: { c: "Y", shadow: "P", draw: (a) => {
    for (const y of [46, 40, 34, 28]) flatCoin(a, 32, y, 13);
    for (const y of [56, 50, 44, 38]) flatCoin(a, 17, y, 12);
    for (const y of [56, 50, 44]) flatCoin(a, 47, y, 12);
    coinUp(a, 33, 47, 0.5);
    a.sh(star(53, 16, 7, 2, 4), "white");
  } },
  coin2x: { c: "Y", shadow: "P", draw: (a) => {
    coinUp(a, 27, 29, 0.84);
    a.sh("M31 41 H60 L57 59 H28 Z", "P");
    a.ln("M36 46.5 C36 43.5 41.5 43.5 41.5 46.8 C41.5 49.5 36 51.5 35.5 54.5 H42", "white", 2.6);
    a.ln("M46 45 L52.5 54.5 M52.5 45 L46 54.5", "white", 2.6);
  } },
  gem: { c: "C", shadow: "P", draw: (a) => {
    a.sh("M10 24 H54 L32 57 Z", "P");
    a.plain("M10 24 H24 L32 57 Z", "PD"); a.plain("M40 24 H54 L32 57 Z", "PL");
    a.sh("M10 24 L20 12 H44 L54 24 Z", "PL");
    a.plain("M10 24 L20 12 L24 24 Z", "P"); a.plain("M44 12 L54 24 L40 24 Z", "P");
    a.ln2("M20 12 L24 24 L32 57 L40 24 L44 12 M10 24 H54", "ink", 1.6);
    a.ln2("M26 15.5 L31 15.5", "white", 2.4);
    a.sh(star(52, 9, 6, 1.8, 4), "white");
  } },
  crown: { c: "Y", shadow: "P", draw: (a) => {
    a.sh("M12 42 L9 17 L22 29 L32 9 L42 29 L55 17 L52 42 Z", "gold");
    a.plain("M15 40 L13.5 25 L22.5 33 L32 16 L41.5 33 L50.5 25 L49 40 Z", "goldM");
    a.sh("M11 40 H53 V53 H11 Z", "gold");
    a.ln2("M11 44 H53", "goldD", 1.6);
    a.sh(ell(32, 47, 4, 3.6), "pink"); a.sh(ell(20, 47, 2.8, 2.6), "cyan"); a.sh(ell(44, 47, 2.8, 2.6), "cyan");
    a.sh(ell(9, 16, 3, 3), "gold"); a.sh(ell(32, 8, 3.2, 3.2), "gold"); a.sh(ell(55, 16, 3, 3), "gold");
    a.ln2("M14 24 L15.5 37", "white", 2);
  } },

  // Set 2: small marks.
  check: { c: "L", speed: false, draw: (a) => {
    a.sh("M7 34 L19 23 L28 32 L46 9 L58 19 L29 55 Z", "front");
    a.plain("M11 34 L19 27 L28 36.5 L46.5 13 L49 15 L29 41 Z", "top");
  } },
  close: { c: "P", speed: false, draw: (a) => {
    a.sh("M14 5 L32 21 L50 5 L59 14 L43 32 L59 50 L50 59 L32 43 L14 59 L5 50 L21 32 L5 14 Z", "front");
    a.plain("M14 9 L32 25 L50 9 L54 13 L32 30 L10 13 Z", "top");
  } },
  lock: { c: "U", speed: false, draw: (a) => {
    a.ln("M21 30 V21 C21 7 43 7 43 21 V30", "side", 5);
    a.sh("M46 30 L52 26 L52 54 L46 58 Z", "side"); a.sh("M14 30 L20 26 L52 26 L46 30 Z", "top"); a.sh("M14 30 H46 V58 H14 Z", "front");
    a.plain(ell(30, 40, 3.6, 3.6), "ink"); a.plain("M28 42 H32 L33.5 51 H26.5 Z", "ink");
  } },
  play: { c: "Y", speed: false, draw: (a) => {
    a.sh("M15 7 Q12 7 12 11 V53 Q12 57 15.5 55.5 L56 34.5 Q59 32 56 29.5 L15.5 8.5 Z", "front");
    a.plain("M17 13 L49 30 L17 22 Z", "top");
  } },
  dash: { c: "G", speed: false, draw: (a) => {
    a.ln(ell(32, 32, 22, 22), "front", 6);
    a.ln("M17 47 L47 17", "front", 6);
  } },
  clock: { c: "C", draw: (a) => {
    a.sh("M27 5 H37 V12 H27 Z", "P"); a.sh("M46 12 L52 9 L55 15 L49 18 Z", "P");
    a.sh(ell(35, 37, 22, 22), "side");
    a.sh(ell(31, 35, 22, 22), "front");
    a.ln2(ell(31, 35, 16, 16), "top", 3);
    a.ln("M31 35 V23", "ink", 0.5); a.ln("M31 35 L40 40", "P", 2.6);
    a.sh(ell(31, 35, 2.6, 2.6), "ink");
  } },
  flame: { c: "P", draw: (a) => {
    a.sh("M32 4 C38 14 52 20 50 38 C49 50 41 58 32 58 C21 58 13 50 14 38 C15 28 22 24 22 14 C27 18 28 22 28 26 C31 20 33 12 32 4 Z", "O");
    a.sh("M32 24 C36 32 44 36 42 46 C41 52 37 56 32 56 C26 56 22 51 23 45 C24 39 28 36 28 30 C31 33 32 30 32 24 Z", "Y");
    a.plain("M32 40 C35 44 37 47 36 51 C35 54 33 55 32 55 C30 55 28 53 28.5 50 C29 47 31 45 32 40 Z", "white");
  } },
  bolt: { c: "C", draw: (a) => {
    a.sh("M36 3 L11 36 H27 L21 61 L53 24 H36 L45 3 Z", "Y");
    a.ln2("M35 8 L19 31", "white", 2.6);
  } },
  sparkle: { c: "Y", draw: (a) => {
    a.sh(star(30, 34, 27, 7, 4), "front");
    a.plain(star(30, 34, 15, 3.5, 4), "top");
    a.sh(star(52, 11, 8, 2.2, 4), "front");
  } },
  heart: { c: "U", draw: (a) => {
    a.sh("M32 57 C14 45 6 35 6 23 C6 14 13 8 21 8 C26 8 30 11 32 15 C34 11 38 8 43 8 C51 8 58 14 58 23 C58 35 50 45 32 57 Z", "P");
    a.plain("M32 52 C40 46 50 38 52 27 C50 37 42 44 32 50 Z", "PDp");
    a.ln2("M13 20 C14 15 17 13 21 13", "white", 3.4);
  } },

  // Set 3: quests and achievements.
  trophy: { c: "Y", shadow: "P", draw: (a) => {
    a.ln("M19 13 C7 13 8 30 21 31", "gold", 3.4); a.ln("M45 13 C57 13 56 30 43 31", "gold", 3.4);
    a.sh("M27 39 H37 L38 48 H26 Z", "goldD");
    a.sh("M17 7 H47 V21 C47 34 41 41 32 41 C23 41 17 34 17 21 Z", "gold");
    a.plain("M38 9 H45 V21 C45 31 41 37 35 39.5 C39 35 41 29 41 21 Z", "goldM");
    a.sh(star(31, 22, 7.5, 3.2), "white");
    a.ln2("M21.5 11 V24", "white", 2.6);
    a.sh("M45 49 L50 45 V54 L45 58 Z", "goldD"); a.sh("M18 49 L23 45 H50 L45 49 Z", "gold"); a.sh("M18 49 H45 V58 H18 Z", "gold");
    a.plain("M23 52 H40 V55 H23 Z", "goldM");
  } },
  burst: { c: "P", draw: (a) => {
    a.sh(burst(32, 32, 1), "Y");
    a.sh(burst(32, 32, 0.56), "white");
    a.plain(ell(32, 32, 4.5, 4.5), "P");
  } },
  gamepad: { c: "C", draw: (a) => {
    const body = "M14 20 H50 C58 20 62 30 60 44 C59 52 52 54 47 48 L42 42 H22 L17 48 C12 54 5 52 4 44 C2 30 6 20 14 20 Z";
    a.sh(shift(body, 2, 4), "side");
    a.sh(body, "front");
    a.sh("M13 30 H17 V26 H21 V30 H25 V34 H21 V38 H17 V34 H13 Z", "P");
    a.sh(ell(44, 27.5, 2.7, 2.7), "C"); a.sh(ell(50, 32.5, 2.7, 2.7), "Y"); a.sh(ell(38, 32.5, 2.7, 2.7), "L"); a.sh(ell(44, 37.5, 2.7, 2.7), "P");
    a.plain("M27 26 H31 V28.5 H27 Z M33 26 H37 V28.5 H33 Z", "side");
  } },
  shield: { c: "L", draw: (a) => {
    const s = "M32 4 L56 12 V30 C56 46 44 55 32 60 C20 55 8 46 8 30 V12 Z";
    a.sh(shift(s, 3, 2), "side");
    a.sh(s, "front");
    a.plain("M32 7.5 L53 14.5 V30 C53 44 43 52 32 56.5 Z", "top");
    a.sh(star(32, 31, 12, 5.2), "P");
  } },
  wall: { c: "C", draw: (a) => {
    a.sh("M44 15 L54 9 V52 L44 58 Z", "side"); a.sh("M8 15 L18 9 L54 9 L44 15 Z", "front"); a.sh("M8 15 H44 V58 H8 Z", "top");
    a.ln2("M8 26 H44 M8 37 H44 M8 48 H44 M20 15 V26 M34 15 V26 M14 26 V37 M28 26 V37 M40 26 V37 M20 37 V48 M34 37 V48 M14 48 V58 M28 48 V58 M40 48 V58", "sideD", 1.6);
    a.ln("M5 52 C16 49 28 40 38 27", "P", 4);
    a.sh("M32 22 L46 17 L42 32 Z", "P");
  } },
  speed: { c: "P", draw: (a) => {
    a.sh("M7 41 C7 31 11 24 17 24 H26 C30 24 32 29 37 31 L51 37 C59 40 61 45 59 50 H8 C7 48 7 45 7 41 Z", "front");
    a.plain("M38 32.5 L50.5 38 C56 40 58 43 58 47 H40 Z", "top");
    a.ln2("M22 30 L29 33 M25.5 26.5 L32 30", "ink", 1.8);
    a.ln("M16 41 C25 45 36 45 47 40", "P", 2.6);
    a.sh("M6 48 H60 V54 Q60 58 56 58 H10 Q6 58 6 54 Z", "P");
  } },
  chart: { c: "L", draw: (a) => {
    a.sh("M20 44 L24 41 V55 L20 58 Z", "side"); a.sh("M7 44 L11 41 H24 L20 44 Z", "top"); a.sh("M7 44 H20 V58 H7 Z", "front");
    a.sh("M37 34 L41 31 V55 L37 58 Z", "side"); a.sh("M24 34 L28 31 H41 L37 34 Z", "top"); a.sh("M24 34 H37 V58 H24 Z", "front");
    a.sh("M54 24 L58 21 V55 L54 58 Z", "side"); a.sh("M41 24 L45 21 H58 L54 24 Z", "top"); a.sh("M41 24 H54 V58 H41 Z", "front");
    a.ln("M6 34 L22 22 L32 27 L48 10", "P", 4);
    a.sh("M40 8 L54 4 L52 18 Z", "P");
  } },
};

const PAGE_COLOURED = new Set(["shop", "locker", "quests", "rewards", "leaders", "sound", "crate", "coin", "coins2", "coins3", "coinPile", "coin2x", "gem", "crown"]);

function render(name) {
  const ic = ICONS[name];
  const pc = COL[ic.c], sc = COL[ic.shadow || ic.c];
  const pal = {
    front: "#FFFFFF", top: "#EEF0F6", side: "#C2C8D8", sideD: "#9AA2B8", white: "#FFFFFF", ink: INK,
    P: pc, PD: mix(pc, "#000000", 0.35), PL: mix(pc, "#FFFFFF", 0.55), PDp: mix(COL.P, "#000000", 0.3),
    Y: COL.Y, O: COL.O, C: COL.C, L: COL.L, pink: COL.P, cyan: COL.C,
    gold: "#FFD60A", goldD: "#D9A200", goldM: "#F2BC00",
  };
  // Sets 2 and 3 put their details in pink; set 1 (the pages and coins) in the page colour.
  if (!PAGE_COLOURED.has(name)) pal.P = COL.P;
  const pass = (shadow) => {
    let out = "";
    const k = (r) => (shadow ? sc : pal[r]);
    const inkc = shadow ? sc : INK;
    const a = {
      sh: (d, r) => { out += `<path d="${d}" fill="${k(r)}" stroke="${inkc}" stroke-width="${OUTLINE}" stroke-linejoin="round"/>`; },
      plain: (d, r) => { if (!shadow) out += `<path d="${d}" fill="${k(r)}"/>`; },
      ln: (d, r, w) => {
        out += `<path d="${d}" fill="none" stroke="${inkc}" stroke-width="${w + OUTLINE}" stroke-linecap="round" stroke-linejoin="round"/>`;
        if (!shadow) out += `<path d="${d}" fill="none" stroke="${k(r)}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
      },
      ln2: (d, r, w) => { if (!shadow) out += `<path d="${d}" fill="none" stroke="${k(r)}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`; },
    };
    ic.draw(a);
    return out;
  };
  const speed = ic.speed === false ? "" : [[-1, 22, 6], [-3, 31, 9], [-1, 40, 5]].map(([x, y, l]) => `<path d="M${x} ${y} H${x + l}" stroke="${sc}" stroke-width="2.4" stroke-linecap="round"/>`).join("");
  return `<svg viewBox="-4 -2 70 70" fill="none" xmlns="http://www.w3.org/2000/svg"><g transform="translate(32 32) skewX(-8) translate(-32 -32)">${speed}<g transform="translate(${SHADOW[0]} ${SHADOW[1]})">${pass(true)}</g>${pass(false)}</g></svg>`;
}

// { iconName: svg } for every object icon.
export function icons() {
  const out = {};
  for (const name of Object.keys(ICONS)) out[name] = render(name);
  return out;
}
