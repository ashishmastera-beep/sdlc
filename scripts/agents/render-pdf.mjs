#!/usr/bin/env node
// render-pdf.mjs IN.md OUT.pdf --title "SDLC-12 Technical Specification" --status "Draft – pending review"
// Markdown -> styled HTML -> PDF with headless Chrome. Used to attach specs to the Jira card.
//
// The Markdown is agent output derived from untrusted story text, so: raw HTML is escaped (never rendered),
// and the page has a Content-Security-Policy that blocks every script and network load (script-src and
// img-src fall back to none). Needs `marked` (global or local npm) and Chrome/Chromium (CHROME_BIN or on PATH).
import { readFileSync, writeFileSync, mkdtempSync, existsSync, statSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const args = process.argv.slice(2);
const opt = (n, d = "") => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const [input, output] = args.filter((a, i) => !a.startsWith("--") && !(i > 0 && args[i - 1].startsWith("--")));
if (!input || !output) { console.error("usage: render-pdf.mjs IN.md OUT.pdf --title T [--status S] [--subtitle S]"); process.exit(2); }

function loadMarked() {
  const req = createRequire(import.meta.url);
  const roots = [process.cwd(), process.env.NODE_PATH, execFileSync("npm", ["root", "-g"]).toString().trim()].filter(Boolean);
  for (const r of roots) { try { return req(req.resolve("marked", { paths: [r] })); } catch { /* next */ } }
  throw new Error("npm package 'marked' not found; install it (see config/pipeline.json agents.markedVersion)");
}
const { Marked } = loadMarked();

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const marked = new Marked({ gfm: true, breaks: false });
marked.use({
  renderer: {
    html(token) { return esc(token.text ?? token.raw ?? ""); },           // never render raw HTML
    image(token) { return esc(`[image: ${token.text || token.href}]`); },  // no remote images
  },
});

const title = opt("--title", "Specification");
const status = opt("--status", "");
const subtitle = opt("--subtitle", "");
let md = readFileSync(input, "utf8");
md = md.replace(/^# .*\n+/, "");                    // the document title comes from --title
md = md.replace(/^> .*(\n> .*)*\n+/, "");           // template guidance block quote at the top
const body = marked.parse(md);
const generated = new Date().toISOString().slice(0, 16).replace("T", " ") + " UTC";

const html = `<!doctype html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:">
<title>${esc(title)}</title>
<style>
  @page { size: A4; margin: 18mm 16mm 18mm 16mm; }
  body { font-family: "DejaVu Sans", "Liberation Sans", Arial, sans-serif; font-size: 10.5pt; line-height: 1.45; color: #1d2433; }
  header { border-bottom: 2px solid #0b5cab; padding-bottom: 8px; margin-bottom: 14px; }
  header h1 { font-size: 18pt; margin: 0 0 4px; color: #0b5cab; }
  header .meta { font-size: 9pt; color: #555; }
  header .status { display: inline-block; font-weight: bold; padding: 1px 8px; border-radius: 3px; background: #fff4ce; color: #6b4e00; margin-right: 8px; }
  header .status.approved { background: #dff6dd; color: #1e5b1e; }
  h2 { font-size: 13pt; color: #0b5cab; border-bottom: 1px solid #d0d7e2; padding-bottom: 2px; margin-top: 18px; page-break-after: avoid; }
  h3 { font-size: 11pt; margin-top: 12px; page-break-after: avoid; }
  table { border-collapse: collapse; width: 100%; table-layout: fixed; margin: 8px 0; font-size: 9pt; page-break-inside: auto; }
  th, td { border: 1px solid #c9d1de; padding: 4px 6px; text-align: left; vertical-align: top; overflow-wrap: anywhere; }
  th { background: #eef3fa; }
  tr { page-break-inside: avoid; }
  code { font-family: "DejaVu Sans Mono", monospace; font-size: 9pt; background: #f3f5f8; padding: 0 3px; border-radius: 2px; }
  pre { background: #f3f5f8; padding: 8px; border-radius: 4px; white-space: pre-wrap; word-break: break-word; }
  pre code { background: none; padding: 0; }
  blockquote { border-left: 3px solid #c9d1de; margin: 8px 0; padding: 2px 10px; color: #444; }
  a { color: #0b5cab; text-decoration: none; word-break: break-all; }
</style></head><body>
<header>
  <h1>${esc(title)}</h1>
  <div class="meta">${status ? `<span class="status${/approved/i.test(status) ? " approved" : ""}">${esc(status)}</span>` : ""}${esc(subtitle)}${subtitle ? " · " : ""}Generated ${esc(generated)}</div>
</header>
${body}
</body></html>`;

const dir = mkdtempSync(join(tmpdir(), "spec-pdf-"));
const htmlPath = join(dir, "spec.html");
writeFileSync(htmlPath, html);

const candidates = [process.env.CHROME_BIN, "google-chrome", "google-chrome-stable", "chromium", "chromium-browser"].filter(Boolean);
let chrome;
for (const c of candidates) {
  try { execFileSync(c.includes("/") ? c : "which", c.includes("/") ? ["--version"] : [c], { stdio: "ignore" }); chrome = c; break; } catch { /* next */ }
}
if (!chrome) { console.error("Chrome/Chromium not found; set CHROME_BIN"); process.exit(3); }

const out = resolve(output);
execFileSync(chrome, [
  "--headless=new", "--no-sandbox", "--disable-gpu", "--disable-extensions", "--no-first-run",
  "--no-pdf-header-footer",
  `--user-data-dir=${join(dir, "profile")}`, `--print-to-pdf=${out}`, `file://${htmlPath}`,
], { stdio: ["ignore", "pipe", "pipe"], timeout: 60000 });

if (!existsSync(out) || statSync(out).size < 1000) { console.error("PDF was not produced"); process.exit(4); }
console.log(`${out} (${statSync(out).size} bytes)`);
