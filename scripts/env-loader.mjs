#!/usr/bin/env node
/**
 * agentmemory ZCode Plugin — Env Loader
 * Reads ~/.agentmemory/.env into process.env before hook scripts execute.
 * Zero external dependencies. Fails gracefully (warn, don't throw).
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

try {
  const envPath = join(homedir(), ".agentmemory", ".env");
  const content = readFileSync(envPath, "utf-8");

  for (let line of content.split("\n")) {
    line = line.trim();
    // Skip empty lines and comments
    if (!line || line.startsWith("#")) continue;

    const eqIdx = line.indexOf("=");
    if (eqIdx === -1) continue;

    const key = line.slice(0, eqIdx).trim();
    let value = line.slice(eqIdx + 1).trim();

    // Strip surrounding quotes (single or double)
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    // Don't override already-set environment variables
    if (key && !process.env[key]) {
      process.env[key] = value;
    }
  }
} catch (err) {
  // .env missing or unreadable — hooks still work with defaults
  if (err.code !== "ENOENT") {
    console.warn("[agentmemory] env-loader: failed to load .env —", err.message);
  }
}
