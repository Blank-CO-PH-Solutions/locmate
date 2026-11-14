// Renders the legal documents that ship with the app (assets/legal/*.md) so the
// landing page and the in-app text always say the same thing.

const fs = require("node:fs");
const path = require("node:path");
const { marked } = require("marked");

const legalDirectory = path.join(__dirname, "..", "..", "assets", "legal");

marked.setOptions({ gfm: true, breaks: false });

const cache = new Map();

function renderLegal(filename) {
  if (cache.has(filename)) return cache.get(filename);

  const file = path.join(legalDirectory, filename);
  const markdown = fs
    .readFileSync(file, "utf8")
    .replace(/^#\s+.*(?:\r?\n)+/, "");
  const html = marked.parse(markdown);
  cache.set(filename, html);
  return html;
}

module.exports = { renderLegal };
