// Per-app listing config. `appstore/<app>/app.json` holds everything the
// pipeline once hardcoded for EST: names, bundle id, scheme, categories,
// leaderboards, the screenshot order. Every script resolves its app here.
//
//   node --input-type=module -e 'import {app} from "./appstore/app.mjs"; ...'

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const APPSTORE_ROOT = dirname(fileURLToPath(import.meta.url));

export const APP_KEYS = readdirSync(APPSTORE_ROOT, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && existsSync(join(APPSTORE_ROOT, entry.name, "app.json")))
  .map((entry) => entry.name);

export function app(key) {
  if (!APP_KEYS.includes(key)) {
    throw new Error(`Unknown app "${key}". Known: ${APP_KEYS.join(", ")}`);
  }
  const dir = join(APPSTORE_ROOT, key);
  const config = JSON.parse(readFileSync(join(dir, "app.json"), "utf8"));
  return { key, dir, ...config };
}

/// The app named by `--app <key>` on argv, else the APP environment
/// variable, else "est".
export function appFromArgs(argv = process.argv) {
  const index = argv.indexOf("--app");
  const key = index === -1 ? process.env.APP ?? "est" : argv[index + 1];
  return app(key);
}
