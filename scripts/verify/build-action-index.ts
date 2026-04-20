#!/usr/bin/env ts-node
/**
 * Walk every `contracts/payloads/IGP<N>/PayloadIGP<N>.sol`, slice their action
 * bodies, extract external calls, and write a JSON index used by the
 * `verify-payload` AI skill for O(1) similarity lookups.
 *
 *   npm run verify:action-index
 *   # or target a custom output path:
 *   npm run verify:action-index -- --out /tmp/idx.json
 *
 * Record schema (per entry):
 *   {
 *     "igp": "IGP128",
 *     "file": "contracts/payloads/IGP128/PayloadIGP128.sol",
 *     "action": "action3",
 *     "index": 3,
 *     "signature": "function action3() internal isActionSkippable(3)",
 *     "natspec": "Action 3: Upgrade AdminModule LL on InfiniteProxy",
 *     "lineRange": [116, 135],
 *     "bodyHash": "0x...",
 *     "externals": [
 *       {
 *         "receiver": "IInfiniteProxy(address(LIQUIDITY))",
 *         "interfaceName": "IInfiniteProxy",
 *         "targetSymbol": "LIQUIDITY",
 *         "method": "getImplementationSigs",
 *         "rawArgs": ["OLD_ADMIN_MODULE"]
 *       }
 *     ]
 *   }
 *
 * The skill consults this index to classify new actions as
 *   - `HISTORICALLY_VERIFIED` (bodyHash match),
 *   - `REVIEW_DIFF` (same externals signature, different body), or
 *   - `NEW_PATTERN` (no hit).
 */

import { readdirSync, statSync, mkdirSync, writeFileSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { extractActions } from "./lib/actionExtractor.js";
import { extractExternalCalls } from "./lib/externalsExtractor.js";

interface CliArgs {
  out: string;
  verbose: boolean;
}

function parseArgs(argv: readonly string[]): CliArgs {
  const repoRoot = findRepoRoot();
  let out = join(
    repoRoot,
    "scripts",
    "verify",
    ".cache",
    "action-index.json"
  );
  let verbose = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (a === "--out" || a === "-o") out = argv[++i] ?? out;
    else if (a === "--verbose" || a === "-v") verbose = true;
    else if (a === "--help" || a === "-h") {
      process.stdout.write(
        [
          "build-action-index.ts — build the historical action cache.",
          "",
          "Usage:",
          "  npm run verify:action-index",
          "  npm run verify:action-index -- --out path.json",
          "",
          "Options:",
          "  --out, -o      Output JSON path. Default scripts/verify/.cache/action-index.json.",
          "  --verbose, -v  Print one line per payload processed.",
          "",
        ].join("\n")
      );
      process.exit(0);
    } else {
      process.stderr.write(`Unknown argument \`${a}\`.\n`);
      process.exit(1);
    }
  }
  return { out, verbose };
}

interface IndexEntry {
  igp: string;
  file: string;
  action: string;
  index: number;
  signature: string;
  natspec: string;
  lineRange: [number, number];
  bodyHash: string;
  externals: Array<{
    receiver: string;
    interfaceName: string | null;
    targetSymbol: string | null;
    method: string;
    rawArgs: string[];
  }>;
}

function main(): void {
  const args = parseArgs(process.argv.slice(2));
  const repoRoot = findRepoRoot();
  const payloadsDir = join(repoRoot, "contracts", "payloads");

  const entries: IndexEntry[] = [];
  const igpDirs = readdirSync(payloadsDir)
    .filter((name) => /^IGP\d+$/.test(name))
    .sort((a, b) => Number(a.slice(3)) - Number(b.slice(3)));

  for (const igp of igpDirs) {
    const file = join(payloadsDir, igp, `Payload${igp}.sol`);
    try {
      if (!statSync(file).isFile()) continue;
    } catch {
      continue;
    }

    let actions: ReturnType<typeof extractActions>;
    try {
      actions = extractActions(file);
    } catch (err) {
      process.stderr.write(
        `skip ${igp}: extractor failed — ${(err as Error).message}\n`
      );
      continue;
    }

    for (const action of actions) {
      const externals = extractExternalCalls(action.body).map((c) => ({
        receiver: c.receiver,
        interfaceName: c.interfaceName,
        targetSymbol: c.targetSymbol,
        method: c.method,
        rawArgs: c.rawArgs,
      }));

      entries.push({
        igp,
        file: rel(repoRoot, file),
        action: action.name,
        index: action.index,
        signature: action.signature.replace(/\s+/g, " "),
        natspec: action.natspec,
        lineRange: action.lineRange,
        bodyHash: action.bodyHash,
        externals,
      });
    }

    if (args.verbose) {
      process.stdout.write(
        `${igp}: ${actions.length} action(s)\n`
      );
    }
  }

  mkdirSync(dirname(args.out), { recursive: true });
  const payload = {
    generatedAt: new Date().toISOString(),
    repoRoot,
    totalPayloads: igpDirs.length,
    totalActions: entries.length,
    entries,
  };
  writeFileSync(args.out, JSON.stringify(payload, null, 2) + "\n", "utf8");

  process.stdout.write(
    `Wrote ${entries.length} actions across ${igpDirs.length} payloads -> ${args.out}\n`
  );
}

function findRepoRoot(): string {
  const here = dirname(fileURLToPath(import.meta.url));
  return resolve(here, "..", "..");
}

function rel(root: string, file: string): string {
  return file.startsWith(root + "/") ? file.slice(root.length + 1) : file;
}

main();
