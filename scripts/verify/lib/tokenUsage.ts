/**
 * Token-usage detector.
 *
 * Given a payload's `.sol` source, figure out which token address constants
 * flow through USD-denominated limit helpers so `prepare-prices.ts` only emits
 * constants for tokens whose price getters may actually be reached.
 *
 * Strategy:
 *   1. Strip comments and strings from the source so identifier names inside
 *      them are not counted. (Otherwise an explanatory NatSpec about "ETH"
 *      or a URL would falsely flag the token as used.)
 *   2. Keep `allReferences` as every `*_ADDRESS` identifier for debugging.
 *   3. Mark only price-relevant identifiers as `used`:
 *      - direct `getRawAmount(X_ADDRESS, ...)` first arguments
 *      - conservatively, every token reference in payloads that call common
 *        USD helpers (`setVaultLimits`, `setDexLimits`,
 *        `setSupplyProtocolLimits`, `setBorrowProtocolLimits`)
 *   4. Anything price-relevant that is not in the registry is returned as
 *      `unknown` so the caller can surface an actionable error pointing to the
 *      add-token skill. Raw token references are intentionally not unknowns.
 *
 * This regex-first approach is deliberate: parsing Solidity fully would need
 * solc + an AST walk, which is overkill given the payload convention is a
 * small flat file with no imports of other payloads.
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
 * Token constants NOT required to be dispatched in `pricehelpers.sol`
 * because they only appear in payload code for book-keeping (approve,
 * transfer, event topics) and never flow through `getRawAmount`. Listed
 * in `constants.sol` but intentionally absent from the priced universe.
 *
 * Keep this small and explicit — widening it silently weakens the
 * dispatch-coverage check.
 */
const NON_PRICED_EXEMPT = new Set<string>([
  // WETH is used as a transfer-path target but priced through ETH when
  // it appears on the Liquidity side.
  "WETH_ADDRESS",
  // Lido stETH — historical payloads reference it as a transfer target;
  // liquidity-side pricing goes through wstETH. Add only if a new payload
  // genuinely needs a stETH exchange-price lookup.
  "stETH_ADDRESS",
]);

export interface TokenUsageResult {
  used: TokenEntry[];
  /** `*_ADDRESS` identifiers that have no registry entry. */
  unknown: string[];
  /** Debug: raw set of every `*_ADDRESS` identifier found in the payload. */
  allReferences: string[];
}

export interface DispatchCoverageResult {
  /** Tokens that have a `token == X_ADDRESS` branch in pricehelpers.sol. */
  covered: TokenEntry[];
  /** Tokens the payload uses but which are not dispatched. */
  missing: TokenEntry[];
}

/**
 * Scan `contracts/payloads/common/pricehelpers.sol` and return which of the
 * requested tokens have a dispatch branch (`token == X_ADDRESS`) in its
 * `getRawAmount`. Token constants in `NON_PRICED_EXEMPT` are treated as
 * covered unconditionally — they never need a price lookup.
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

export function detectTokensUsedFromSource(src: string): TokenUsageResult {
  const stripped = stripCommentsStringsAndMarkerBlock(src);

  const ADDRESS_IDENT = /\b([A-Za-z_][A-Za-z0-9_]*_ADDRESS)\b/g;
  const allReferences = new Set<string>();
  let match: RegExpExecArray | null;
  while ((match = ADDRESS_IDENT.exec(stripped)) !== null) {
    allReferences.add(match[1]!);
  }

  const seen = detectPriceRelevantTokenConstants(stripped, allReferences);

  const used: TokenEntry[] = [];
  const unknown: string[] = [];
  for (const ident of seen) {
    const entry = tokenByConstantName(ident);
    if (entry) used.push(entry);
    else unknown.push(ident);
  }

  used.sort((a, b) => a.symbol.localeCompare(b.symbol));
  unknown.sort();

  return {
    used,
    unknown,
    allReferences: [...allReferences].sort(),
  };
}

function detectPriceRelevantTokenConstants(
  src: string,
  allReferences: ReadonlySet<string>
): Set<string> {
  const seen = new Set<string>();

  // Direct price conversion: getRawAmount(TOKEN_ADDRESS, ...).
  const DIRECT_RAW_AMOUNT =
    /\bgetRawAmount\s*\(\s*([A-Za-z_][A-Za-z0-9_]*_ADDRESS)\b/g;
  let match: RegExpExecArray | null;
  while ((match = DIRECT_RAW_AMOUNT.exec(src)) !== null) {
    seen.add(match[1]!);
  }

  // Common helpers convert USD-denominated fields through getRawAmount()
  // internally. Their token inputs are sometimes constants in struct fields,
  // but sometimes arrays / variables (`tokens[i]`), so keep this path
  // conservative once those helpers are used.
  const USES_USD_HELPER =
    /\b(?:setSupplyProtocolLimits|setBorrowProtocolLimits|setDexLimits|setVaultLimits)\s*\(/;
  if (USES_USD_HELPER.test(src)) {
    for (const ident of allReferences) seen.add(ident);
  }

  return seen;
}

/**
 * Remove `//` and `/* *\/` comments, double-quoted strings, and any content
 * inside the auto-generated price marker region. What's left is the
 * human-authored Solidity that matters for usage detection.
 *
 * Written as a simple character-by-character scanner to avoid regex
 * pathologies on multi-line comments.
 */
function stripCommentsStringsAndMarkerBlock(src: string): string {
  // Phase 1: drop the marker block if present.
  src = dropMarkerRegion(src);

  // Phase 2: strip comments and strings.
  let out = "";
  let i = 0;
  const n = src.length;
  while (i < n) {
    const c = src[i]!;
    const c2 = src[i + 1];

    if (c === "/" && c2 === "/") {
      // line comment
      const nl = src.indexOf("\n", i);
      i = nl === -1 ? n : nl;
      continue;
    }
    if (c === "/" && c2 === "*") {
      // block comment
      const end = src.indexOf("*/", i + 2);
      i = end === -1 ? n : end + 2;
      continue;
    }
    if (c === '"') {
      // double-quoted string — skip to the closing quote honoring `\"`.
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
  if (end === -1) return src; // malformed — let the generator complain later
  return src.slice(0, begin) + src.slice(end + END_MARKER.length);
}
