/**
 * Token registry — single source of truth for the pre-deploy price-fetcher.
 *
 * One entry per token address that may legitimately appear inside a payload's
 * `getRawAmount` dispatch. Multiple entries can share the same `priceVarName`
 * (BTC family → `BTC_USD_PRICE`; stables → `STABLE_USD_PRICE`). In that case
 * the generator emits one Solidity `constant` and one dispatch branch per
 * token, each carrying its own `decimals`.
 *
 * When a payload references an `*_ADDRESS` identifier that has no entry here,
 * `scripts/verify/prepare-prices.ts` exits with an actionable error pointing
 * to `.cursor/skills/add-payload-token/SKILL.md`.
 *
 * CoinGecko IDs are best-effort: if CoinGecko later renames a coin, fix the
 * `coingeckoId` here and re-run. Tokens pinned by rule (`exactOneDollar`) use
 * the configured id only for sanity logging; the rounded output is invariant.
 */

import type { RoundingRule } from "./rounding.js";

export interface TokenEntry {
  /** Human-readable symbol — only used in reports. */
  readonly symbol: string;
  /** Checksummed mainnet address matching the `*_ADDRESS` constant. */
  readonly address: `0x${string}`;
  /** The exact identifier used in `contracts/payloads/common/constants.sol`. */
  readonly constantName: string;
  /** ERC-20 decimals (18 / 8 / 6 / ...). */
  readonly decimals: number;
  /** CoinGecko `simple/price` id. Only fetched once per `priceVarName` group. */
  readonly coingeckoId: string;
  /** Solidity constant name written into the payload (may be shared). */
  readonly priceVarName: string;
  /** Rounding policy — determines the emitted Solidity literal. */
  readonly rounding: RoundingRule;
}

export const TOKENS: readonly TokenEntry[] = [
  // -----------------------------------------------------------------
  // ETH and ETH-correlated LSTs / LRTs — rounded to the nearest $10.
  // -----------------------------------------------------------------
  {
    symbol: "ETH",
    address: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
    constantName: "ETH_ADDRESS",
    decimals: 18,
    coingeckoId: "ethereum",
    priceVarName: "ETH_USD_PRICE",
    rounding: "nearestTenDollars",
  },
  {
    symbol: "wstETH",
    address: "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0",
    constantName: "wstETH_ADDRESS",
    decimals: 18,
    coingeckoId: "wrapped-steth",
    priceVarName: "wstETH_USD_PRICE",
    rounding: "nearestTenDollars",
  },
  {
    symbol: "weETH",
    address: "0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee",
    constantName: "weETH_ADDRESS",
    decimals: 18,
    coingeckoId: "wrapped-eeth",
    priceVarName: "weETH_USD_PRICE",
    rounding: "nearestTenDollars",
  },
  {
    symbol: "rsETH",
    address: "0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7",
    constantName: "rsETH_ADDRESS",
    decimals: 18,
    coingeckoId: "kelp-dao-restaked-eth",
    priceVarName: "rsETH_USD_PRICE",
    rounding: "nearestTenDollars",
  },
  {
    symbol: "weETHs",
    address: "0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88",
    constantName: "weETHs_ADDRESS",
    decimals: 18,
    coingeckoId: "ether-fi-staked-eth",
    priceVarName: "weETHs_USD_PRICE",
    rounding: "nearestTenDollars",
  },
  {
    symbol: "mETH",
    address: "0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa",
    constantName: "mETH_ADDRESS",
    decimals: 18,
    coingeckoId: "mantle-staked-ether",
    priceVarName: "mETH_USD_PRICE",
    rounding: "nearestTenDollars",
  },
  {
    symbol: "ezETH",
    address: "0xbf5495Efe5DB9ce00f80364C8B423567e58d2110",
    constantName: "ezETH_ADDRESS",
    decimals: 18,
    coingeckoId: "renzo-restaked-eth",
    priceVarName: "ezETH_USD_PRICE",
    rounding: "nearestTenDollars",
  },
  {
    symbol: "OSETH",
    address: "0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38",
    constantName: "OSETH_ADDRESS",
    decimals: 18,
    coingeckoId: "stakewise-v3-oseth",
    priceVarName: "OSETH_USD_PRICE",
    rounding: "nearestTenDollars",
  },

  // -----------------------------------------------------------------
  // BTC family — share `BTC_USD_PRICE`. Rounded to the nearest $1000.
  // -----------------------------------------------------------------
  {
    symbol: "WBTC",
    address: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
    constantName: "WBTC_ADDRESS",
    decimals: 8,
    coingeckoId: "wrapped-bitcoin",
    priceVarName: "BTC_USD_PRICE",
    rounding: "nearestThousandDollars",
  },
  {
    symbol: "cbBTC",
    address: "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf",
    constantName: "cbBTC_ADDRESS",
    decimals: 8,
    coingeckoId: "coinbase-wrapped-btc",
    priceVarName: "BTC_USD_PRICE",
    rounding: "nearestThousandDollars",
  },
  {
    symbol: "tBTC",
    address: "0x18084fbA666a33d37592fA2633fD49a74DD93a88",
    constantName: "tBTC_ADDRESS",
    decimals: 18,
    coingeckoId: "tbtc",
    priceVarName: "BTC_USD_PRICE",
    rounding: "nearestThousandDollars",
  },
  {
    symbol: "eBTC",
    address: "0x657e8C867D8B37dCC18fA4Caead9C45EB088C642",
    constantName: "eBTC_ADDRESS",
    decimals: 8,
    coingeckoId: "ether-fi-staked-btc",
    priceVarName: "BTC_USD_PRICE",
    rounding: "nearestThousandDollars",
  },
  {
    symbol: "lBTC",
    address: "0x8236a87084f8B84306f72007F36F2618A5634494",
    constantName: "lBTC_ADDRESS",
    decimals: 8,
    coingeckoId: "lombard-staked-btc",
    priceVarName: "BTC_USD_PRICE",
    rounding: "nearestThousandDollars",
  },

  // -----------------------------------------------------------------
  // Stables pegged to $1 — share `STABLE_USD_PRICE = 1 * 1e2`. No fetch.
  // -----------------------------------------------------------------
  {
    symbol: "USDC",
    address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    constantName: "USDC_ADDRESS",
    decimals: 6,
    coingeckoId: "usd-coin",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },
  {
    symbol: "USDT",
    address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    constantName: "USDT_ADDRESS",
    decimals: 6,
    coingeckoId: "tether",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },
  {
    symbol: "GHO",
    address: "0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f",
    constantName: "GHO_ADDRESS",
    decimals: 18,
    coingeckoId: "gho",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },
  {
    symbol: "USDe",
    address: "0x4c9EDD5852cd905f086C759E8383e09bff1E68B3",
    constantName: "USDe_ADDRESS",
    decimals: 18,
    coingeckoId: "ethena-usde",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },
  {
    symbol: "deUSD",
    address: "0x15700B564Ca08D9439C58cA5053166E8317aa138",
    constantName: "deUSD_ADDRESS",
    decimals: 18,
    coingeckoId: "elixir-deusd",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },
  {
    symbol: "USR",
    address: "0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110",
    constantName: "USR_ADDRESS",
    decimals: 18,
    coingeckoId: "resolv-usr",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },
  {
    symbol: "USD0",
    address: "0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5",
    constantName: "USD0_ADDRESS",
    decimals: 18,
    coingeckoId: "usual-usd",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },
  {
    symbol: "fxUSD",
    address: "0x085780639CC2cACd35E474e71f4d000e2405d8f6",
    constantName: "fxUSD_ADDRESS",
    decimals: 18,
    coingeckoId: "f-x-protocol-fxusd",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },
  {
    symbol: "BOLD",
    address: "0xb01dd87B29d187F3E3a4Bf6cdAebfb97F3D9aB98",
    constantName: "BOLD_ADDRESS",
    decimals: 18,
    coingeckoId: "liquity-bold",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },
  {
    symbol: "iUSD",
    address: "0x48f9e38f3070AD8945DFEae3FA70987722E3D89c",
    constantName: "iUSD_ADDRESS",
    decimals: 18,
    coingeckoId: "instadapp-usd",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },
  {
    symbol: "USDTb",
    address: "0xC139190F447e929f090Edeb554D95AbB8b18aC1C",
    constantName: "USDTb_ADDRESS",
    decimals: 18,
    coingeckoId: "usdtb",
    priceVarName: "STABLE_USD_PRICE",
    rounding: "exactOneDollar",
  },

  // -----------------------------------------------------------------
  // Yield-bearing stables — each has its own price constant. Nearest cent.
  // -----------------------------------------------------------------
  {
    symbol: "sUSDe",
    address: "0x9D39A5DE30e57443BfF2A8307A4256c8797A3497",
    constantName: "sUSDe_ADDRESS",
    decimals: 18,
    coingeckoId: "ethena-staked-usde",
    priceVarName: "sUSDe_USD_PRICE",
    rounding: "nearestCent",
  },
  {
    symbol: "sUSDs",
    address: "0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD",
    constantName: "sUSDs_ADDRESS",
    decimals: 18,
    coingeckoId: "susds",
    priceVarName: "sUSDs_USD_PRICE",
    rounding: "nearestCent",
  },
  {
    symbol: "syrupUSDT",
    address: "0x356B8d89c1e1239Cbbb9dE4815c39A1474d5BA7D",
    constantName: "syrupUSDT_ADDRESS",
    decimals: 6,
    coingeckoId: "maple-syrupusdt",
    priceVarName: "syrupUSDT_USD_PRICE",
    rounding: "nearestCent",
  },
  {
    symbol: "syrupUSDC",
    address: "0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b",
    constantName: "syrupUSDC_ADDRESS",
    decimals: 6,
    coingeckoId: "maple-syrupusdc",
    priceVarName: "syrupUSDC_USD_PRICE",
    rounding: "nearestCent",
  },
  {
    symbol: "REUSD",
    address: "0x5086bf358635B81D8C47C66d1C8b9E567Db70c72",
    constantName: "REUSD_ADDRESS",
    decimals: 18,
    coingeckoId: "resolv-reusd",
    priceVarName: "REUSD_USD_PRICE",
    rounding: "nearestCent",
  },
  {
    symbol: "csUSDL",
    address: "0xbEeFc011e94f43b8B7b455eBaB290C7Ab4E216f1",
    constantName: "csUSDL_ADDRESS",
    decimals: 18,
    coingeckoId: "coinshift-usdl",
    priceVarName: "csUSDL_USD_PRICE",
    rounding: "nearestCent",
  },
  {
    symbol: "JRUSDE",
    address: "0xC58D044404d8B14e953C115E67823784dEA53d8F",
    constantName: "JRUSDE_ADDRESS",
    decimals: 18,
    coingeckoId: "pendle-juniorusde",
    priceVarName: "JRUSDE_USD_PRICE",
    rounding: "nearestCent",
  },
  {
    symbol: "SRUSDE",
    address: "0x3d7d6fdf07EE548B939A80edbc9B2256d0cdc003",
    constantName: "SRUSDE_ADDRESS",
    decimals: 18,
    coingeckoId: "pendle-seniorusde",
    priceVarName: "SRUSDE_USD_PRICE",
    rounding: "nearestCent",
  },
  {
    symbol: "wstUSR",
    address: "0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055",
    constantName: "wstUSR_ADDRESS",
    decimals: 18,
    coingeckoId: "wrapped-staked-usr",
    priceVarName: "wstUSR_USD_PRICE",
    rounding: "nearestCent",
  },
  {
    symbol: "RLP",
    address: "0x4956b52aE2fF65D74CA2d61207523288e4528f96",
    constantName: "RLP_ADDRESS",
    decimals: 18,
    coingeckoId: "resolv-rlp",
    priceVarName: "RLP_USD_PRICE",
    rounding: "nearestCent",
  },

  // -----------------------------------------------------------------
  // Governance — INST and FLUID share an address. Nearest cent.
  // -----------------------------------------------------------------
  {
    symbol: "INST",
    address: "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb",
    constantName: "INST_ADDRESS",
    decimals: 18,
    coingeckoId: "instadapp",
    priceVarName: "FLUID_USD_PRICE",
    rounding: "nearestCent",
  },
  {
    symbol: "FLUID",
    address: "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb",
    constantName: "FLUID_ADDRESS",
    decimals: 18,
    coingeckoId: "instadapp",
    priceVarName: "FLUID_USD_PRICE",
    rounding: "nearestCent",
  },

  // -----------------------------------------------------------------
  // Gold-backed — nearest $10.
  // -----------------------------------------------------------------
  {
    symbol: "XAUT",
    address: "0x68749665FF8D2d112Fa859AA293F07A622782F38",
    constantName: "XAUT_ADDRESS",
    decimals: 6,
    coingeckoId: "tether-gold",
    priceVarName: "XAUT_USD_PRICE",
    rounding: "nearestTenDollars",
  },
  {
    symbol: "PAXG",
    address: "0x45804880De22913dAFE09f4980848ECE6EcbAf78",
    constantName: "PAXG_ADDRESS",
    decimals: 18,
    coingeckoId: "pax-gold",
    priceVarName: "PAXG_USD_PRICE",
    rounding: "nearestTenDollars",
  },
] as const;

// ---------------------------------------------------------------------
// Lookup helpers
// ---------------------------------------------------------------------

const BY_CONSTANT_NAME = new Map(TOKENS.map((t) => [t.constantName, t]));
const BY_ADDRESS = new Map(
  TOKENS.map((t) => [t.address.toLowerCase(), t])
);

export function tokenByConstantName(name: string): TokenEntry | undefined {
  return BY_CONSTANT_NAME.get(name);
}

export function tokenByAddress(addr: string): TokenEntry | undefined {
  return BY_ADDRESS.get(addr.toLowerCase());
}

/** Group by `priceVarName` so the generator emits one constant per group. */
export function groupByPriceVar(
  tokens: readonly TokenEntry[]
): Map<string, TokenEntry[]> {
  const groups = new Map<string, TokenEntry[]>();
  for (const t of tokens) {
    const bucket = groups.get(t.priceVarName);
    if (bucket) bucket.push(t);
    else groups.set(t.priceVarName, [t]);
  }
  return groups;
}
