/**
 * Token-usage detector.
 *
 * Given a payload's `.sol` source, figure out which token address constants
 * need USD price overrides for `prepare-prices.ts`.
 *
 * A token is "priced" iff it reaches `getRawAmount` with `amountInUSD != 0` —
 * that is the only code path that consults a `*_USD_PRICE()` getter. Everything
 * else (raw-`amount` conversions, `*InShares` DEX limits, literal Liquidity
 * configs, transfers, paused-limit helpers) is *referenced* but not priced and
 * needs no override.
 *
 * Strategy:
 *   1. Strip comments, strings, and the auto-generated price marker block.
 *   2. Collect every `*_ADDRESS` identifier → `allReferences` (debug).
 *   3. Collect priced tokens from two sources:
 *      a. limit-config struct fields whose helpers call `getRawAmount` with a
 *         `*InUSD` amount (`supplyToken`, `borrowToken`, `tokenA`, `tokenB`);
 *      b. direct `getRawAmount(token, amount, amountInUSD, ...)` calls where the
 *         literal `amountInUSD` argument is non-zero. Calls with `amountInUSD`
 *         literally `0` (raw-amount mode) are ignored.
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
]);

/** Struct fields on configs that helpers pass into `getRawAmount` with a
 * `*InUSD` amount (always USD-mode), e.g. `setSupplyProtocolLimits`,
 * `setBorrowProtocolLimits`, `setVaultLimits`, `setDexLimits`. */
const PRICED_CONFIG_FIELD =
  /(?:supplyToken|borrowToken|tokenA|tokenB):\s*([A-Za-z_][A-Za-z0-9_]*_ADDRESS)\b/g;

/**
 * Direct `getRawAmount(token, amount, amountInUSD, isSupply)` call sites.
 *
 * A token only needs a `*_USD_PRICE()` override when it reaches `getRawAmount`
 * with `amountInUSD != 0` — that is the ONLY branch that consults the price
 * getter. The raw-`amount` form (`amountInUSD == 0`) is normalised purely by
 * the live exchange price and needs no price at all.
 *
 * Captures the four top-level arguments. These calls never nest
 * parentheses/commas in the payloads, so a non-greedy `[^,]` split is safe.
 */
const GET_RAW_AMOUNT_CALL =
  /getRawAmount\(\s*([^,()]+?)\s*,\s*([^,()]+?)\s*,\s*([^,()]+?)\s*,\s*([^,()]+?)\)/g;

const ADDRESS_CONSTANT = /^[A-Za-z_][A-Za-z0-9_]*_ADDRESS$/;

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
  let match: RegExpExecArray | null;
  PRICED_CONFIG_FIELD.lastIndex = 0;
  while ((match = PRICED_CONFIG_FIELD.exec(stripped)) !== null) {
    const ident = match[1]!;
    if (ident !== "address") priced.add(ident);
  }
  for (const ident of detectPricedFromGetRawAmountCalls(stripped)) {
    priced.add(ident);
  }
  return priced;
}

/**
 * Return `*_ADDRESS` constants passed as the `token` argument of a direct
 * `getRawAmount(...)` call whose `amountInUSD` argument is non-zero. Calls in
 * raw-`amount` mode (`amountInUSD` literally `0`) are ignored — they require no
 * USD price. Tokens passed as a variable (helper indirection) cannot be
 * resolved here and are covered by `detectPricedAddressConstants`'s struct-field
 * scan instead.
 */
export function detectPricedFromGetRawAmountCalls(
  stripped: string
): Set<string> {
  const priced = new Set<string>();
  let match: RegExpExecArray | null;
  GET_RAW_AMOUNT_CALL.lastIndex = 0;
  while ((match = GET_RAW_AMOUNT_CALL.exec(stripped)) !== null) {
    const tokenArg = match[1]!.trim();
    const amountInUSD = match[3]!.trim();
    // raw-amount mode: USD arg is literally 0 -> no price needed.
    if (amountInUSD === "0") continue;
    // only a literal token constant can be mapped to a registry entry.
    if (ADDRESS_CONSTANT.test(tokenArg)) priced.add(tokenArg);
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
