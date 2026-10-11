#!/usr/bin/env node
// Builds the Jira Description written by the enrichment agent, in the house format:
//
//   ## Original Story      <- what the product owner wrote, kept exactly as it was (rich text preserved)
//   ---
//   ## AI Enrichment       <- replaced on every enrichment run (rework replaces, never appends)
//
// Usage:
//   node description.mjs build --description current.json --enrichment enrichment.md [--link-base URL]
//       current.json: the issue's current description (ADF document, or null)
//       prints the new ADF document
//   node description.mjs md2adf file.md [--link-base URL]
//
// Markdown subset (what the agent is told to write): # headings, paragraphs, - / * bullets (nested by
// 2+ spaces), 1. numbered lists, ``` code blocks, ---, **bold**, _italic_ / *italic*, `code`, [text](url).
// Relative links (repo paths) become absolute with --link-base. No dependencies.

import { readFileSync } from "node:fs";

export const ORIGINAL = "Original Story";
export const ENRICHMENT = "AI Enrichment";

const text = (t, marks) => (marks && marks.length ? { type: "text", text: t, marks } : { type: "text", text: t });
const nodeText = (n) => (n.text || "") + (n.content || []).map(nodeText).join("");
const isHeading = (n, title) => n && n.type === "heading" && nodeText(n).trim().toLowerCase() === title.toLowerCase();

function absolute(href, base) {
  if (!base || /^[a-z][a-z0-9+.-]*:/i.test(href) || href.startsWith("#")) return href;
  return base.replace(/\/?$/, "/") + href.replace(/^\.?\//, "");
}

// Inline markdown -> ADF text nodes.
export function inline(src, base) {
  const out = [];
  const re = /(\*\*([^*]+)\*\*)|(`([^`]+)`)|(\[([^\]]+)\]\(([^)\s]+)\))|(\*([^*\s][^*]*)\*)|((?<![\w])_([^_]+)_(?![\w]))/g;
  let last = 0, m;
  while ((m = re.exec(src))) {
    if (m.index > last) out.push(text(src.slice(last, m.index)));
    if (m[1]) out.push(text(m[2], [{ type: "strong" }]));
    else if (m[3]) out.push(text(m[4], [{ type: "code" }]));
    else if (m[5]) out.push(text(m[6], [{ type: "link", attrs: { href: absolute(m[7], base) } }]));
    else if (m[8]) out.push(text(m[9], [{ type: "em" }]));
    else if (m[10]) out.push(text(m[11], [{ type: "em" }]));
    last = re.lastIndex;
  }
  if (last < src.length) out.push(text(src.slice(last)));
  return out.filter((n) => n.text.length > 0);
}

const para = (s, base) => {
  const c = inline(s, base);
  return c.length ? { type: "paragraph", content: c } : { type: "paragraph" };
};

// Markdown -> ADF document.
export function md2adf(md, base) {
  const lines = md.replace(/\r\n?/g, "\n").split("\n");
  const content = [];
  let i = 0;
  const listRe = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/;

  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) { i++; continue; }

    let m;
    if ((m = line.match(/^```(\w*)\s*$/))) {
      const body = [];
      i++;
      while (i < lines.length && !/^```\s*$/.test(lines[i])) body.push(lines[i++]);
      i++;
      const node = { type: "codeBlock", content: body.length ? [text(body.join("\n"))] : [] };
      if (m[1]) node.attrs = { language: m[1] };
      content.push(node);
      continue;
    }
    if ((m = line.match(/^(#{1,6})\s+(.*?)\s*#*\s*$/))) {
      content.push({ type: "heading", attrs: { level: m[1].length }, content: inline(m[2], base) });
      i++;
      continue;
    }
    if (/^\s*(-{3,}|\*{3,}|_{3,})\s*$/.test(line)) { content.push({ type: "rule" }); i++; continue; }
    if (listRe.test(line)) {
      const items = [];
      while (i < lines.length && (listRe.test(lines[i]) || (lines[i].trim() === "" && listRe.test(lines[i + 1] || "")))) {
        if (lines[i].trim() === "") { i++; continue; }
        const [, ind, marker, rest] = lines[i].match(listRe);
        items.push({ indent: ind.replace(/\t/g, "    ").length, ordered: /\d/.test(marker), text: rest });
        i++;
        // continuation lines of the same item
        while (i < lines.length && lines[i].trim() && !listRe.test(lines[i]) && /^\s{2,}\S/.test(lines[i])) {
          items[items.length - 1].text += " " + lines[i].trim();
          i++;
        }
      }
      content.push(...buildLists(items, base));
      continue;
    }
    if ((m = line.match(/^>\s?(.*)$/))) {
      const body = [];
      while (i < lines.length && /^>\s?/.test(lines[i])) body.push(lines[i++].replace(/^>\s?/, ""));
      content.push({ type: "blockquote", content: [para(body.join(" "), base)] });
      continue;
    }
    const body = [];
    while (i < lines.length && lines[i].trim() && !listRe.test(lines[i]) && !/^(#{1,6}\s|```|>|\s*(-{3,}|\*{3,}|_{3,})\s*$)/.test(lines[i])) {
      body.push(lines[i++].trim());
    }
    content.push(para(body.join(" "), base));
  }
  return { type: "doc", version: 1, content };
}

// Flat items with indentation -> nested bulletList / orderedList nodes.
function buildLists(items, base) {
  const roots = [];
  const stack = []; // {indent, list}
  for (const it of items) {
    while (stack.length && it.indent < stack[stack.length - 1].indent) stack.pop();
    let top = stack[stack.length - 1];
    if (!top || it.indent > top.indent) {
      const list = { type: it.ordered ? "orderedList" : "bulletList", content: [] };
      if (!top) roots.push(list);
      else {
        const parentItem = top.list.content[top.list.content.length - 1];
        parentItem.content.push(list);
      }
      stack.push((top = { indent: it.indent, list }));
    } else if ((top.list.type === "orderedList") !== it.ordered && stack.length === 1) {
      const list = { type: it.ordered ? "orderedList" : "bulletList", content: [] };
      roots.push(list);
      stack[stack.length - 1] = top = { indent: it.indent, list };
    }
    top.list.content.push({ type: "listItem", content: [para(it.text, base)] });
  }
  return roots;
}

// Current description (ADF or null) -> the product owner's original nodes, without any previous AI Enrichment.
export function originalNodes(desc) {
  let nodes = desc && Array.isArray(desc.content) ? desc.content.slice() : [];
  const cut = nodes.findIndex((n) => isHeading(n, ENRICHMENT));
  if (cut >= 0) nodes = nodes.slice(0, cut);
  if (isHeading(nodes[0], ORIGINAL)) nodes = nodes.slice(1);
  while (nodes.length && (nodes[nodes.length - 1].type === "rule" || isEmptyPara(nodes[nodes.length - 1]))) nodes.pop();
  while (nodes.length && isEmptyPara(nodes[0])) nodes.shift();
  return nodes;
}
const isEmptyPara = (n) => n.type === "paragraph" && !nodeText(n).trim() && !(n.content || []).some((c) => c.type !== "text");

export function build(desc, enrichmentMd, base) {
  const orig = originalNodes(desc);
  const enrich = md2adf(enrichmentMd, base).content;
  // If the agent repeated the section heading, keep a single one.
  if (isHeading(enrich[0], ENRICHMENT)) enrich.shift();
  return {
    type: "doc",
    version: 1,
    content: [
      { type: "heading", attrs: { level: 2 }, content: [text(ORIGINAL)] },
      ...(orig.length ? orig : [para("(No description was provided.)")]),
      { type: "rule" },
      { type: "heading", attrs: { level: 2 }, content: [text(ENRICHMENT)] },
      ...enrich,
    ],
  };
}

function arg(name) {
  const i = process.argv.indexOf(name);
  return i > 0 ? process.argv[i + 1] : undefined;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const cmd = process.argv[2];
  const base = arg("--link-base");
  if (cmd === "build") {
    const descPath = arg("--description"), mdPath = arg("--enrichment");
    if (!descPath || !mdPath) { console.error("usage: description.mjs build --description F --enrichment F [--link-base URL]"); process.exit(2); }
    const desc = JSON.parse(readFileSync(descPath, "utf8") || "null");
    process.stdout.write(JSON.stringify(build(desc, readFileSync(mdPath, "utf8"), base)));
  } else if (cmd === "md2adf") {
    process.stdout.write(JSON.stringify(md2adf(readFileSync(process.argv[3], "utf8"), base)));
  } else {
    console.error("usage: description.mjs build|md2adf ...");
    process.exit(2);
  }
}
