// Generate the canonical metadata files consumed by the `asc` CLI.
//
//   node appstore/metadata.mjs --app est
//
// Copy lives in appstore/<app>/appstore.md. Generated JSON is intentionally small:
// omitted fields are no-ops when `asc metadata push` applies the directory.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { appFromArgs } from "./app.mjs";

const APP = appFromArgs();
const SOURCE = join(APP.dir, "appstore.md");
const OUTPUT = join(APP.dir, "metadata");
const LOCALE = "en-US";

const FIELD_MAP = {
  promotional_text: "promotionalText",
  release_notes: "whatsNew",
  support_url: "supportUrl",
  marketing_url: "marketingUrl",
};

const parse = (text) => {
  const platform = text.match(/^## Platform: (.+?) \((.+?)\)\s*$/m);
  if (!platform) throw new Error("Missing iOS platform header");

  const body = text.slice(platform.index + platform[0].length);
  const fields = {};
  const headings = [...body.matchAll(/^### ([a-z_]+)\s*$/gm)];
  for (const [i, heading] of headings.entries()) {
    const start = heading.index + heading[0].length;
    const end = headings[i + 1]?.index ?? body.length;
    fields[heading[1]] = body.slice(start, end).trim();
  }
  return { platform: platform[1], bundleId: platform[2], fields };
};

const parsed = parse(readFileSync(SOURCE, "utf8"));
if (parsed.bundleId !== APP.bundleId) {
  throw new Error(`Unexpected bundle ID: ${parsed.bundleId}`);
}

const appInfo = {
  name: parsed.fields.name,
  subtitle: parsed.fields.subtitle,
  privacyPolicyUrl: parsed.fields.privacy_url,
};
const version = {};
for (const [source, target] of Object.entries(FIELD_MAP)) {
  version[target] = parsed.fields[source];
}
version.description = parsed.fields.description;
version.keywords = parsed.fields.keywords;

// Apple rejects whatsNew on an app that has never been released: "Attribute
// 'whatsNew' cannot be edited at this time". A first version has nothing to be
// new against. Keep the copy in appstore.md for the next release and omit it
// here until 1.0.0 ships.
const initialRelease = process.argv.includes("--initial-release")
  || process.env.EST_INITIAL_RELEASE === "1"
  || process.env.INITIAL_RELEASE === "1";
if (initialRelease) {
  delete version.whatsNew;
}

mkdirSync(join(OUTPUT, "app-info"), { recursive: true });
mkdirSync(join(OUTPUT, "version", APP.version), { recursive: true });
writeFileSync(join(OUTPUT, "app-info", `${LOCALE}.json`), `${JSON.stringify(appInfo, null, 2)}\n`);
writeFileSync(join(OUTPUT, "version", APP.version, `${LOCALE}.json`), `${JSON.stringify(version, null, 2)}\n`);

console.log(`✓ ${parsed.platform} (${parsed.bundleId}) → appstore/${APP.key}/metadata/`);
