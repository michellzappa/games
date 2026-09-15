// Validate store copy and staged screenshot assets without contacting Apple.

import { existsSync, openSync, readSync, closeSync, readdirSync } from "node:fs";
import { join } from "node:path";

import { DEVICES } from "./devices.mjs";
import { appFromArgs } from "./app.mjs";

const APP = appFromArgs();
const SOURCE = join(APP.dir, "appstore.md");
const screenshotDir = (key) => join(APP.dir, "screenshots", key, "en-US");
const validateScreenshots = !process.argv.includes("--metadata-only");
const text = (await import("node:fs")).readFileSync(SOURCE, "utf8");
const limits = {
  name: 30,
  subtitle: 30,
  promotional_text: 170,
  description: 4000,
  keywords: 100,
  release_notes: 4000,
};

const fields = {};
const headings = [...text.matchAll(/^### ([a-z_]+)\s*$/gm)];
for (const [i, heading] of headings.entries()) {
  const start = heading.index + heading[0].length;
  const end = headings[i + 1]?.index ?? text.length;
  fields[heading[1]] = text.slice(start, end).trim();
}

const issues = [];
for (const [field, limit] of Object.entries(limits)) {
  const value = fields[field] ?? "";
  if (!value) issues.push(`missing ${field}`);
  if (value.length > limit) issues.push(`${field}: ${value.length} > ${limit}`);
}
if (fields.keywords?.includes(", ")) issues.push("keywords: use comma-separated values without spaces");

function pngInfo(file) {
  const buffer = Buffer.alloc(26);
  const fd = openSync(file, "r");
  readSync(fd, buffer, 0, buffer.length, 0);
  closeSync(fd);
  if (buffer.toString("ascii", 1, 4) !== "PNG") return null;
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
    colorType: buffer[25],
  };
}

// Apple requires a screenshot set for every device class the app supports.
// EST ships iPhone and iPad (TARGETED_DEVICE_FAMILY 1,2), so a missing iPad
// set is a submission blocker, not a warning.
const counts = [];
if (validateScreenshots) {
  for (const [key, spec] of Object.entries(DEVICES)) {
    const directory = screenshotDir(key);
    const shots = existsSync(directory)
      ? readdirSync(directory).filter((file) => file.endsWith(".png")).sort()
      : [];
    counts.push({ key, label: spec.label, count: shots.length });
    if (shots.length < 1 || shots.length > 10) {
      issues.push(`${key}: ${shots.length} screenshot(s) (expected 1 to 10)`);
      continue;
    }
    for (const shot of shots) {
      const info = pngInfo(join(directory, shot));
      if (!info) { issues.push(`${key}/${shot}: not a PNG`); continue; }
      if (info.width !== spec.width || info.height !== spec.height) {
        issues.push(
          `${key}/${shot}: expected ${spec.width}×${spec.height}, got ${info.width}×${info.height}`,
        );
      }
      if ([4, 6].includes(info.colorType)) issues.push(`${key}/${shot}: alpha channel present`);
    }
  }
}

for (const issue of issues) console.log(`✗ ${issue}`);
if (issues.length) process.exit(1);
console.log(validateScreenshots
  ? `✓ metadata limits passed; ${counts.map((c) => `${c.count} ${c.label}`).join(", ")} screenshot(s) are RGB at the exact ASC sizes`
  : "✓ metadata limits passed; screenshot validation skipped");
