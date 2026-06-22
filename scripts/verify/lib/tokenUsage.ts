/**
 * Token-usage detector.
 *
 * Given a payload's `.sol` source, figure out which token address constants
 * need USD price overrides for `prepare-prices.ts`.
 *
 * Only tokens that flow through `getRawAmount` (via limit helpers) are
 * "priced". A payload may reference many `*_ADDRESS` constants for transfers,
 * raw Liquidity configs, or paused-limit helpers — those are *referenced* but
 * not priced.
 *
 * Strategy:
 *   1. Strip comments, strings, and the auto-generated price marker block.
 *   2. Collect every `*_ADDRESS` identifier → `allReferences` (debug).
 *   3. Collect tokens in limit-config struct fields that call `getRawAmount`
 *      inside helpers (`supplyToken`, `borrowToken`, `tokenA`, `tokenB`) →
 *      priced set. Positional `getRawAmount(token, amount, 0, …)` / `_borrowConfig`
 *      raw-amount calls are intentionally excluded (exchange-price only).
 *   4. Map priced + exempt constants to registry entries → `used`.
 *   5. Unknown `*_ADDRESS` identifiers outside the registry → `unknown`.
 */

import { readFileSync } from "node:fs";
import {
  tokenByConstantName,
  type TokenEntry,
} from "./tokens.js";
import {
  BEGIN_MARKER_PREFIX,
  END_MARKER,
} from "./markers.js";

/**
 * Registry tokens that may appear in a payload but never need a price
 * override or `getRawAmount` dispatch (Treasury withdraw, WETH path, etc.).
 */
export const NON_PRICED_EXEMPT = new Set<string>([
  "WETH_ADDRESS",
  "stETH_ADDRESS",
  "FLUID_ADDRESS",
  // fToken admin contracts used as Liquidity `user` / protocol addresses.
  "F_SUSDs_ADDRESS",
]);

/** Struct fields on configs that helpers pass into `getRawAmount`. */
const PRICED_CONFIG_FIELD =
  /(?:supplyToken|borrowToken|tokenA|tokenB):\s*([A-Za-z_][A-Za-z0-9_]*_ADDRESS)\b/g;

/**
 * Positional token argument of a USD-denominated limit helper, e.g.
 * `_borrowConfigUSD(vaultId, TOKEN_ADDRESS, expandPct, baseUSD, maxUSD)`.
 *
 * Such helpers route the token through `getRawAmount`'s USD path
 * (`getRawAmount(token, 0, usd, ...)`), so the token needs a price override
 * even though it is passed positionally rather than in a named struct field.
 * The `USD` suffix on the helper name is the signal: raw-amount helpers (e.g.
 * `_borrowConfig`, which calls `getRawAmount(token, amount, 0, ...)`) do NOT
 * end in `USD` and are intentionally skipped — those carry pre-converted token
 * amounts and only need the live exchange price, not a USD getter.
 */
const PRICED_USD_HELPER_ARG =
  /\b_[A-Za-z0-9_]*USD\s*\(\s*[^(),]+,\s*([A-Za-z_][A-Za-z0-9_]*_ADDRESS)\b/g;

export interface TokenUsageResult {
  /** Tokens that need price overrides in the payload (via `getRawAmount`). */
  used: TokenEntry[];
  /** `*_ADDRESS` identifiers that have no registry entry. */
  unknown: string[];
  /** Every `*_ADDRESS` in the payload (including non-priced references). */
  allReferences: string[];
}

export interface DispatchCoverageResult {
  /** Tokens that have a `token == X_ADDRESS` branch in pricehelpers.sol. */
  covered: TokenEntry[];
  /** Tokens the payload prices but which are not dispatched. */
  missing: TokenEntry[];
}

/**
 * Scan `pricehelpers.sol` and return which priced tokens have a dispatch
 * branch in `getRawAmount`.
 */
export function checkDispatchCoverage(
  pricehelpersPath: string,
  tokens: readonly TokenEntry[]
): DispatchCoverageResult {
  const src = readFileSync(pricehelpersPath, "utf8");
  const covered: TokenEntry[] = [];
  const missing: TokenEntry[] = [];
  for (const t of tokens) {
    if (NON_PRICED_EXEMPT.has(t.constantName)) {
      covered.push(t);
      continue;
    }
    const pattern = new RegExp(
      `token\\s*==\\s*${escapeRegex(t.constantName)}\\b`
    );
    if (pattern.test(src)) covered.push(t);
    else missing.push(t);
  }
  return { covered, missing };
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function detectTokensUsed(payloadPath: string): TokenUsageResult {
  const src = readFileSync(payloadPath, "utf8");
  return detectTokensUsedFromSource(src);
}

/**
 * Return `*_ADDRESS` constants that appear in limit-config struct fields
 * (`VaultConfig`, `DexConfig`, `SupplyProtocolConfig`, `BorrowProtocolConfig`)
 * which helpers convert through `getRawAmount`.
 */
export function detectPricedAddressConstants(stripped: string): Set<string> {
  const priced = new Set<string>();
  for (const re of [PRICED_CONFIG_FIELD, PRICED_USD_HELPER_ARG]) {
    let match: RegExpExecArray | null;
    re.lastIndex = 0;
    while ((match = re.exec(stripped)) !== null) {
      const ident = match[1]!;
      if (ident !== "address") priced.add(ident);
    }
  }
  return priced;
}

export function detectTokensUsedFromSource(src: string): TokenUsageResult {
  const stripped = stripCommentsStringsAndMarkerBlock(src);

  const ADDRESS_IDENT = /\b([A-Za-z_][A-Za-z0-9_]*_ADDRESS)\b/g;
  const allRefs = new Set<string>();
  let match: RegExpExecArray | null;
  while ((match = ADDRESS_IDENT.exec(stripped)) !== null) {
    allRefs.add(match[1]!);
  }

  const pricedIds = detectPricedAddressConstants(stripped);

  const used: TokenEntry[] = [];
  const unknown: string[] = [];
  for (const ident of pricedIds) {
    if (NON_PRICED_EXEMPT.has(ident)) continue;
    const entry = tokenByConstantName(ident);
    if (entry) used.push(entry);
    else unknown.push(ident);
  }

  for (const ident of allRefs) {
    // Book-keeping-only tokens (Treasury withdraw targets, WETH path) never
    // flow through `getRawAmount`, so they need no price override even though
    // they are referenced by the payload.
    if (NON_PRICED_EXEMPT.has(ident)) continue;
    if (!tokenByConstantName(ident) && !unknown.includes(ident)) {
      unknown.push(ident);
    }
  }

  used.sort((a, b) => a.symbol.localeCompare(b.symbol));
  unknown.sort();

  return {
    used,
    unknown,
    allReferences: [...allRefs].sort(),
  };
}

/**
 * Remove `//` and `/* *\/` comments, double-quoted strings, and any content
 * inside the auto-generated price marker region.
 */
function stripCommentsStringsAndMarkerBlock(src: string): string {
  src = dropMarkerRegion(src);

  let out = "";
  let i = 0;
  const n = src.length;
  while (i < n) {
    const c = src[i]!;
    const c2 = src[i + 1];

    if (c === "/" && c2 === "/") {
      const nl = src.indexOf("\n", i);
      i = nl === -1 ? n : nl;
      continue;
    }
    if (c === "/" && c2 === "*") {
      const end = src.indexOf("*/", i + 2);
      i = end === -1 ? n : end + 2;
      continue;
    }
    if (c === '"') {
      i += 1;
      while (i < n) {
        const ch = src[i]!;
        if (ch === "\\" && i + 1 < n) {
          i += 2;
          continue;
        }
        if (ch === '"') {
          i += 1;
          break;
        }
        i += 1;
      }
      continue;
    }

    out += c;
    i += 1;
  }

  return out;
}

function dropMarkerRegion(src: string): string {
  const begin = src.indexOf(BEGIN_MARKER_PREFIX);
  if (begin === -1) return src;
  const end = src.indexOf(END_MARKER, begin);
  if (end === -1) return src;
  return src.slice(0, begin) + src.slice(end + END_MARKER.length);
}
