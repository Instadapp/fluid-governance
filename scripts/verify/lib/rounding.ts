/**
 * Rounding policies for fetched USD prices.
 *
 * The existing payloads (see e.g. `contracts/payloads/IGP128/PayloadIGP128.sol`
 * lines 231-257) deliberately round prices rather than embedding a live feed —
 * the goal is to avoid pretending that an on-chain stale constant is a real
 * oracle. This file codifies those empirical categories so future payloads
 * produce literals that look like their historical siblings.
 *
 * Solidity convention (unchanged from history):
 *   - Prices are stored as `uint256 constant X_USD_PRICE = <dollars> * 1e2;`.
 *   - `<dollars>` is a decimal number — either an integer (`2_000`) or a
 *     two-decimal fraction (`1.20`) — multiplied by `1e2` at compile time so
 *     the stored uint is USD cents.
 *
 * Each rounding rule therefore returns:
 *   - `cents` : the exact uint256 value the Solidity compiler evaluates to.
 *   - `literal` : the pretty Solidity fragment to emit between `= ` and `;`.
 *
 * If a new token needs a never-seen rule, add an entry here (and document it
 * in `.cursor/skills/add-payload-token/SKILL.md`). Do NOT inline ad-hoc
 * rounding in the payload — that defeats the point of this file.
 */

export type RoundingRule =
  | "exactOneDollar"
  | "nearestCent"
  | "nearestTenDollars"
  | "nearestThousandDollars";

export interface RoundedPrice {
  /** Actual on-chain uint256 value after `* 1e2`. */
  cents: number;
  /** Solidity source fragment without the `* 1e2` suffix. */
  dollarLiteral: string;
  /** The full RHS: `<dollarLiteral> * 1e2`. */
  literal: string;
}

/** Produce the final Solidity literal for `rawUsd` under `rule`. */
export function round(rawUsd: number, rule: RoundingRule): RoundedPrice {
  switch (rule) {
    case "exactOneDollar":
      return makePrice(1);

    case "nearestCent": {
      const dollars = Math.round(rawUsd * 100) / 100;
      return makePrice(dollars);
    }

    case "nearestTenDollars": {
      const dollars = Math.round(rawUsd / 10) * 10;
      return makePrice(dollars);
    }

    case "nearestThousandDollars": {
      const dollars = Math.round(rawUsd / 1000) * 1000;
      return makePrice(dollars);
    }
  }
}

/** Rounding rules that don't actually need a live price (saves a fetch). */
export function isDeterministic(rule: RoundingRule): boolean {
  return rule === "exactOneDollar";
}

function makePrice(dollars: number): RoundedPrice {
  if (!Number.isFinite(dollars) || dollars < 0) {
    throw new Error(`round: refusing to emit non-finite/negative price ${dollars}`);
  }

  const cents = Math.round(dollars * 100);

  let dollarLiteral: string;
  if (Number.isInteger(dollars)) {
    dollarLiteral = groupThousands(dollars);
  } else {
    // Exactly two decimals. Solidity accepts this as a rational literal and
    // folds `X.YY * 1e2` into `XYY` at compile time.
    dollarLiteral = dollars.toFixed(2);
  }

  return {
    cents,
    dollarLiteral,
    literal: `${dollarLiteral} * 1e2`,
  };
}

function groupThousands(n: number): string {
  // Match existing payload style: `2_000`, `69_000`, `4_040`. Only applied to
  // integer dollar values — two-decimal values stay un-grouped (`1.20`).
  const str = String(n);
  if (str.length <= 3) return str;
  const chars = str.split("");
  const out: string[] = [];
  for (let i = 0; i < chars.length; i++) {
    if (i > 0 && (chars.length - i) % 3 === 0) out.push("_");
    out.push(chars[i]!);
  }
  return out.join("");
}
