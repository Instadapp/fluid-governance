/**
 * Deterministic Solidity code generator for the auto-managed price region.
 *
 * The region lives inside a payload that inherits
 * `contracts/payloads/common/pricehelpers.sol`. `pricehelpers.sol` already
 * owns the `getRawAmount` dispatch and declares every `<SYMBOL>_USD_PRICE()`
 * as `public pure virtual returns (uint256) { revert(...); }`.
 *
 * This generator therefore emits only the small block of **overrides** —
 * one `function <priceVar>() public pure override returns (uint256) { ... }`
 * per *distinct* priceVar referenced by the payload.
 *
 * Tokens that share a priceVar (stables → `STABLE_USD_PRICE`, BTC family →
 * `BTC_USD_PRICE`, INST/FLUID → `FLUID_USD_PRICE`) collapse to one override.
 *
 * Output is byte-for-byte stable for the same inputs modulo the ISO
 * timestamp embedded in the header comment — callers that want a no-op
 * re-run to produce no diff can preserve the previous timestamp when the
 * emitted overrides are unchanged.
 */

import {
  groupByPriceVar,
  type TokenEntry,
} from "./tokens.js";
import {
  isDeterministic,
  round,
  type RoundedPrice,
  type RoundingRule,
} from "./rounding.js";
import { BEGIN_MARKER_PREFIX, END_MARKER } from "./markers.js";

export interface GenerateInput {
  /** Tokens the payload references, deduplicated. */
  used: readonly TokenEntry[];
  /**
   * Raw USD prices from CoinGecko keyed by `coingeckoId`. Deterministic
   * rules (stables) don't need an entry here.
   */
  prices: ReadonlyMap<string, number>;
  /** ISO timestamp embedded in the header comment. */
  fetchedAt: string;
  /** Indentation prefix used on every emitted line (usually 4 spaces). */
  indent?: string;
}

export interface GenerateResult {
  /** Full text to drop between the BEGIN / END markers (with markers). */
  block: string;
  /** Per-token breakdown for the CLI summary table. */
  summary: Array<{
    symbol: string;
    priceVar: string;
    rule: RoundingRule;
    rawUsd: number | null;
    rounded: RoundedPrice;
  }>;
}

export function generate(input: GenerateInput): GenerateResult {
  const indent = input.indent ?? "    ";
  const groups = groupByPriceVar(input.used);

  // ---- compute one rounded price per priceVar group -------------------
  const pricePerVar = new Map<string, RoundedPrice>();
  const summary: GenerateResult["summary"] = [];

  // Iterate in a stable order. `Map` preserves insertion order; our input
  // `used` is sorted by symbol, so group iteration follows that order.
  for (const [priceVar, members] of groups) {
    const leader = members[0]!;
    const { rounding, coingeckoId } = leader;

    let rawUsd: number | null = null;
    if (!isDeterministic(rounding)) {
      const price = input.prices.get(coingeckoId);
      if (price === undefined) {
        throw new Error(
          `generate: no CoinGecko price for ${leader.symbol} ` +
            `(coingeckoId=${coingeckoId}). Add the id to the registry or ` +
            `verify CoinGecko has the coin listed.`
        );
      }
      rawUsd = price;
    }
    const rounded = round(rawUsd ?? 1, rounding);
    pricePerVar.set(priceVar, rounded);

    for (const m of members) {
      summary.push({
        symbol: m.symbol,
        priceVar,
        rule: m.rounding,
        rawUsd,
        rounded,
      });
    }
  }

  // ---- emit the Solidity override block -------------------------------
  const lines: string[] = [];
  lines.push(`${indent}${BEGIN_MARKER_PREFIX}`);
  lines.push(`${indent}// fetched: ${input.fetchedAt}, source: coingecko`);

  // Align the `=` / `return` so the diff looks tidy. Longest priceVar
  // determines the column.
  const maxNameLen = Math.max(
    0,
    ...[...pricePerVar.keys()].map((n) => n.length)
  );

  for (const [priceVar, rounded] of pricePerVar) {
    const pad = " ".repeat(maxNameLen - priceVar.length);
    lines.push(
      `${indent}function ${priceVar}()${pad} public pure override returns (uint256) { return ${rounded.literal}; }`
    );
  }

  lines.push(`${indent}${END_MARKER}`);

  return {
    block: lines.join("\n"),
    summary,
  };
}

/**
 * Replace an existing marker region inside `src` with `newBlock`. If no
 * marker is present, insert `newBlock` just before the final closing `}` of
 * the contract body.
 *
 * `newBlock` must already include the BEGIN / END markers (as produced by
 * `generate`). Returns the rewritten source.
 */
export function spliceIntoSource(src: string, newBlock: string): string {
  const begin = src.indexOf(BEGIN_MARKER_PREFIX);
  if (begin !== -1) {
    const end = src.indexOf(END_MARKER, begin);
    if (end === -1) {
      throw new Error(
        "spliceIntoSource: BEGIN marker found but END marker is missing. " +
          "Refusing to clobber the payload."
      );
    }

    const lineStart = src.lastIndexOf("\n", begin) + 1;
    let lineEnd = src.indexOf("\n", end);
    if (lineEnd === -1) lineEnd = src.length;

    return src.slice(0, lineStart) + newBlock + src.slice(lineEnd);
  }

  const lastBrace = src.lastIndexOf("}");
  if (lastBrace === -1) {
    throw new Error(
      "spliceIntoSource: no closing `}` found — is this a Solidity file?"
    );
  }
  const braceLineStart = src.lastIndexOf("\n", lastBrace) + 1;

  return (
    src.slice(0, braceLineStart) +
    newBlock +
    "\n" +
    src.slice(braceLineStart)
  );
}
