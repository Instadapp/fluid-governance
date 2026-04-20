/**
 * Deterministic Solidity code generator for the auto-managed price region.
 *
 * Given a list of tokens the payload uses and a map of fetched/rounded USD
 * prices, emit the text that will sit between the BEGIN / END markers.
 *
 * Guarantees:
 *   - Output is byte-for-byte stable for the same inputs modulo the ISO
 *     timestamp (to keep git diffs minimal on no-op re-runs, call sites can
 *     choose to preserve the old timestamp when the code block is unchanged).
 *   - Tokens with a shared `priceVarName` (BTC family, stables, …) emit one
 *     `uint256 public constant` and N dispatch branches.
 *   - Branches are ordered first by `priceVarName` group (grouped by insertion
 *     order of the first occurrence in the sorted `used` list), then by
 *     token symbol inside each group. This matches how existing payloads
 *     read top-to-bottom.
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
  // `used` is sorted by symbol, so group iteration follows that symbol order.
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
    // For `exactOneDollar` we pass any value — the rule ignores it.
    const rounded = round(rawUsd ?? 1, rounding);
    pricePerVar.set(priceVar, rounded);

    for (const m of members) {
      summary.push({
        symbol: m.symbol,
        rule: m.rounding,
        rawUsd,
        rounded,
      });
    }
  }

  // ---- emit the Solidity block ---------------------------------------
  const lines: string[] = [];

  lines.push(`${indent}${BEGIN_MARKER_PREFIX}`);
  lines.push(`${indent}// fetched: ${input.fetchedAt}, source: coingecko`);
  lines.push("");

  // One `uint256 public constant` per priceVar group.
  for (const [priceVar, _members] of groups) {
    const rounded = pricePerVar.get(priceVar)!;
    lines.push(
      `${indent}uint256 public constant ${priceVar} = ${rounded.literal};`
    );
  }
  lines.push("");

  // Emit the `getRawAmount` override that dispatches on token address.
  lines.push(
    `${indent}function getRawAmount(`,
    `${indent}    address token,`,
    `${indent}    uint256 amount,`,
    `${indent}    uint256 amountInUSD,`,
    `${indent}    bool isSupply`,
    `${indent}) public view override returns (uint256) {`,
    `${indent}    uint256 usdPrice;`,
    `${indent}    uint256 decimals;`,
    ""
  );

  let first = true;
  for (const [priceVar, members] of groups) {
    for (const m of members) {
      const head = first ? "if" : "else if";
      first = false;
      lines.push(
        `${indent}    ${head} (token == ${m.constantName}) {`,
        `${indent}        usdPrice = ${priceVar};`,
        `${indent}        decimals = ${m.decimals};`,
        `${indent}    }`
      );
    }
  }
  lines.push(
    `${indent}    else revert("not-found");`,
    "",
    `${indent}    return _computeRawAmount(`,
    `${indent}        token,`,
    `${indent}        amount,`,
    `${indent}        amountInUSD,`,
    `${indent}        usdPrice,`,
    `${indent}        decimals,`,
    `${indent}        isSupply`,
    `${indent}    );`,
    `${indent}}`,
    ""
  );

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

    // Expand to the start of the line containing the BEGIN marker so leading
    // indentation is cleanly replaced.
    const lineStart = src.lastIndexOf("\n", begin) + 1;

    // And to the end of the line containing the END marker.
    let lineEnd = src.indexOf("\n", end);
    if (lineEnd === -1) lineEnd = src.length;

    return src.slice(0, lineStart) + newBlock + src.slice(lineEnd);
  }

  // No marker: insert before the last `}` of the file (the contract's
  // closing brace). Find it by scanning backwards.
  const lastBrace = src.lastIndexOf("}");
  if (lastBrace === -1) {
    throw new Error(
      "spliceIntoSource: no closing `}` found — is this a Solidity file?"
    );
  }

  // Find the start of the line that contains that `}`.
  const braceLineStart = src.lastIndexOf("\n", lastBrace) + 1;

  return (
    src.slice(0, braceLineStart) +
    newBlock +
    "\n" +
    src.slice(braceLineStart)
  );
}
