#!/usr/bin/env ts-node
/**
 * Pre-deploy: fetch live USD prices for every token referenced by a payload,
 * round them per the registry rules, and write the resulting Solidity block
 * into the payload file (between the BEGIN / END markers).
 *
 *   npm run verify:prices -- --payload IGP129
 *   npm run verify:prices -- --payload 129 --dry-run
 *
 * Exit codes:
 *   0   Success (or --dry-run printed the proposed block).
 *   1   Payload not found / malformed.
 *   2   Unknown `*_ADDRESS` referenced by the payload (see add-payload-token
 *       skill for the fix).
 *   3   CoinGecko fetch failed or returned no price for a non-deterministic
 *       rule.
 *
 * The script never touches any file other than the one payload it was asked
 * about, and never talks to an RPC. Reviewers confirm the rounded values in
 * the resulting PR diff before the proposal is queued.
 */

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { resolve, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import {
  checkDispatchCoverage,
  detectTokensUsed,
} from "./lib/tokenUsage.js";
import { CoinGeckoClient } from "./lib/coingecko.js";
import { generate, spliceIntoSource } from "./lib/generator.js";
import { isDeterministic } from "./lib/rounding.js";
import { groupByPriceVar } from "./lib/tokens.js";

interface CliArgs {
  payload: string;
  dryRun: boolean;
}

function parseArgs(argv: readonly string[]): CliArgs {
  let payload = "";
  let dryRun = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (a === "--payload" || a === "-p") payload = argv[++i] ?? "";
    else if (a === "--dry-run" || a === "-n") dryRun = true;
    else if (a === "--help" || a === "-h") {
      printHelp();
      process.exit(0);
    } else {
      fail(
        1,
        `Unknown argument \`${a}\`. Run with --help for usage.`
      );
    }
  }
  if (!payload) {
    fail(1, "Missing --payload. Example: --payload IGP129");
  }
  // Accept `129`, `IGP129`, or `PayloadIGP129`.
  if (/^\d+$/.test(payload)) payload = `IGP${payload}`;
  if (payload.startsWith("Payload")) payload = payload.slice("Payload".length);
  if (!payload.startsWith("IGP")) {
    fail(1, `--payload must look like IGP129 (got: \`${payload}\`)`);
  }
  return { payload, dryRun };
}

function printHelp(): void {
  process.stdout.write(
    [
      "prepare-prices.ts — auto-generate the price block inside a payload.",
      "",
      "Usage:",
      "  npm run verify:prices -- --payload IGP129",
      "  npm run verify:prices -- --payload 129 --dry-run",
      "",
      "Options:",
      "  --payload, -p   IGP number or name (e.g. IGP129 or 129).",
      "  --dry-run, -n   Print the proposed block; do not modify any file.",
      "  --help, -h      Show this help.",
      "",
      "Env:",
      "  COINGECKO_API_KEY  Optional. Use CoinGecko pro/demo host + header.",
      "",
    ].join("\n")
  );
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));

  const repoRoot = findRepoRoot();
  const payloadPath = join(
    repoRoot,
    "contracts",
    "payloads",
    args.payload,
    `Payload${args.payload}.sol`
  );
  if (!existsSync(payloadPath)) {
    fail(1, `Payload file not found: ${payloadPath}`);
  }

  // ---- 1. detect tokens used ----------------------------------------
  const usage = detectTokensUsed(payloadPath);

  if (usage.unknown.length > 0) {
    const lines = [
      `Unknown token address identifier(s) used by ${args.payload}:`,
      ...usage.unknown.map((x) => `  - ${x}`),
      "",
      "Fix: either remove the reference, or add a registry entry.",
      "See .cursor/skills/add-payload-token/SKILL.md for the workflow.",
    ];
    fail(2, lines.join("\n"));
  }

  if (usage.used.length === 0) {
    process.stderr.write(
      `No known token references found in ${args.payload}. ` +
        `Nothing to write.\n`
    );
    process.exit(0);
  }

  // ---- 1a. verify pricehelpers.sol dispatches every used token ------
  const pricehelpersPath = join(
    repoRoot,
    "contracts",
    "payloads",
    "common",
    "pricehelpers.sol"
  );
  if (!existsSync(pricehelpersPath)) {
    fail(
      1,
      `pricehelpers.sol not found at ${pricehelpersPath}. ` +
        `This file is required for future payloads.`
    );
  }
  const coverage = checkDispatchCoverage(pricehelpersPath, usage.used);
  if (coverage.missing.length > 0) {
    const lines = [
      `pricehelpers.sol has no dispatch branch for:`,
      ...coverage.missing.map(
        (t) => `  - ${t.constantName} (priceVar=${t.priceVarName}, decimals=${t.decimals})`
      ),
      "",
      "Fix: add an `else if (token == X_ADDRESS) { usdPrice = X_USD_PRICE(); decimals = N; }`",
      "branch to `getRawAmount` in contracts/payloads/common/pricehelpers.sol,",
      "and declare the `X_USD_PRICE()` virtual getter there if it's new.",
      "See .cursor/skills/add-payload-token/SKILL.md for the full workflow.",
    ];
    fail(2, lines.join("\n"));
  }

  // ---- 2. fetch live prices -----------------------------------------
  const groups = groupByPriceVar(usage.used);
  const idsToFetch = new Set<string>();
  for (const [, members] of groups) {
    const leader = members[0]!;
    if (!isDeterministic(leader.rounding)) {
      idsToFetch.add(leader.coingeckoId);
    }
  }

  let prices = new Map<string, number>();
  if (idsToFetch.size > 0) {
    const client = new CoinGeckoClient();
    try {
      prices = await client.fetchUsdPrices([...idsToFetch]);
    } catch (err) {
      fail(
        3,
        `CoinGecko fetch failed: ${(err as Error).message}`
      );
    }

    const missing: string[] = [];
    for (const id of idsToFetch) {
      if (!prices.has(id)) missing.push(id);
    }
    if (missing.length > 0) {
      fail(
        3,
        [
          `CoinGecko returned no USD price for: ${missing.join(", ")}.`,
          "Either the coingeckoId is wrong or the coin is unlisted.",
          "See .cursor/skills/add-payload-token/SKILL.md for the workflow.",
        ].join("\n")
      );
    }
  }

  // ---- 3. generate the Solidity block -------------------------------
  const fetchedAt = new Date().toISOString();
  const { block, summary } = generate({
    used: usage.used,
    prices,
    fetchedAt,
  });

  // ---- 4. write or print --------------------------------------------
  const src = readFileSync(payloadPath, "utf8");
  const next = spliceIntoSource(src, block);

  // Print summary table regardless of dry-run / write.
  process.stdout.write(formatSummary(args.payload, summary) + "\n");

  if (args.dryRun) {
    process.stdout.write(
      `\n--- proposed block (--dry-run, ${args.payload}) ---\n`
    );
    process.stdout.write(block + "\n");
    return;
  }

  if (src === next) {
    process.stdout.write(`\n${args.payload}: block unchanged.\n`);
    return;
  }

  writeFileSync(payloadPath, next, "utf8");
  process.stdout.write(
    `\n${args.payload}: wrote ${payloadPath}\n` +
      `Review the diff, commit, compile, deploy.\n`
  );
}

function formatSummary(
  payload: string,
  summary: ReturnType<typeof generate>["summary"]
): string {
  const header = `\n${payload} — price block summary:\n`;
  const rows = summary.map((s) => {
    const raw =
      s.rawUsd === null
        ? "fixed"
        : s.rawUsd.toFixed(s.rawUsd >= 1000 ? 2 : 6);
    return (
      `  ${s.symbol.padEnd(10)} ` +
      `rule=${s.rule.padEnd(22)} ` +
      `raw=${raw.padEnd(14)} ` +
      `-> ${s.rounded.literal}`
    );
  });
  return header + rows.join("\n");
}

function findRepoRoot(): string {
  // The script lives at <root>/scripts/verify/prepare-prices.ts; walk up.
  const here = dirname(fileURLToPath(import.meta.url));
  return resolve(here, "..", "..");
}

function fail(code: number, msg: string): never {
  process.stderr.write(msg.endsWith("\n") ? msg : msg + "\n");
  process.exit(code);
}

main().catch((err) => {
  process.stderr.write(
    `prepare-prices: unexpected error: ${(err as Error).stack ?? err}\n`
  );
  process.exit(1);
});
