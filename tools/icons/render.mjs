// Renders every icon to a 256 x 256 PNG with a transparent background, ready to upload.
//
//   node tools/icons/render.mjs [out_dir]        (default build/icons)
//
// Writes <out_dir>/svg/<name>.svg, <out_dir>/png/<name>.png, <out_dir>/files.txt (the PNGs, for
// upload.py) and <out_dir>/sheet.html (every icon on the dark menu colour, to look over). Uses
// Google Chrome in headless mode to draw them, so the gradients and the Bangers text come out
// exactly as designed (Bangers is in tools/icons/fonts). Only Node's own modules are used.
import { execFile } from "node:child_process";
import { mkdirSync, writeFileSync, existsSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { icons as objectIcons } from "./objects.mjs";
import { icons as effectIcons } from "./effects.mjs";
import { icons as victoryIcons } from "./victories.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const SIZE = 256;
const CHROME = process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const out = resolve(process.argv[2] || "build/icons");
const font = pathToFileURL(join(HERE, "fonts", "Bangers-Regular.ttf")).href;

const all = { ...objectIcons(), ...effectIcons(), ...victoryIcons() };
const page = (svg) => `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face { font-family: "Bangers"; src: url("${font}"); }
html, body { margin: 0; width: ${SIZE}px; height: ${SIZE}px; overflow: hidden; background: transparent; }
svg { display: block; width: ${SIZE}px; height: ${SIZE}px; }
</style></head><body>${svg}</body></html>`;

for (const sub of ["svg", "png", "html"]) mkdirSync(join(out, sub), { recursive: true });

function shoot(name) {
  const html = join(out, "html", name + ".html");
  const png = join(out, "png", name + ".png");
  writeFileSync(join(out, "svg", name + ".svg"), all[name]);
  writeFileSync(html, page(all[name]));
  const args = [
    "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run", "--no-default-browser-check",
    "--force-device-scale-factor=1", "--default-background-color=00000000",
    `--window-size=${SIZE},${SIZE}`, "--virtual-time-budget=3000", `--screenshot=${png}`, pathToFileURL(html).href,
  ];
  return new Promise((done, fail) => {
    execFile(CHROME, args, { timeout: 60000 }, (error) => {
      if (error || !existsSync(png) || statSync(png).size < 200) fail(new Error(`${name}: ${error ? error.message : "no image"}`));
      else done(name);
    });
  });
}

const names = Object.keys(all).sort();
const queue = [...names];
const failed = [];
await Promise.all(Array.from({ length: 4 }, async () => {
  while (queue.length) {
    const name = queue.shift();
    // Chrome now and then quits before drawing: try each icon up to three times.
    let error = null;
    for (let attempt = 0; attempt < 3; attempt++) {
      try { await shoot(name); error = null; break; } catch (e) { error = e; }
    }
    if (error) failed.push(error.message); else process.stdout.write(".");
  }
}));
writeFileSync(join(out, "files.txt"), names.map((n) => n + ".png").join("\n") + "\n");
writeFileSync(join(out, "sheet.html"), `<!doctype html><meta charset="utf-8"><body style="background:#111;margin:24px;display:flex;flex-wrap:wrap;gap:16px;font:12px sans-serif;color:#aaa">` +
  names.map((n) => `<figure style="margin:0;text-align:center"><img src="png/${n}.png" width="128" height="128" style="background:#1F1F23"><figcaption>${n}</figcaption></figure>`).join("") + "</body>");
console.log(`\n${names.length - failed.length} of ${names.length} icons in ${join(out, "png")}`);
if (failed.length) { console.log(failed.join("\n")); process.exit(1); }
