---
name: add-payload-token
description: Register a new token in `scripts/verify/lib/tokens.ts` so `prepare-prices.ts` can emit its price constant for future payloads. Use when `prepare-prices.ts` exits with "Unknown token address identifier" or when introducing a brand-new token to a payload.
---

# Add a payload token

The token registry in `scripts/verify/lib/tokens.ts` is the single source of truth for `prepare-prices.ts`. Every `*_ADDRESS` constant a payload references must either (a) already have an entry here, or (b) get one added before the script can generate the price block.

## When this skill applies

- `npm run verify:prices -- --payload IGP<N>` exited with code `2` and printed `Unknown token address identifier(s) used by ...`.
- Before authoring a payload that uses a token not present in any historical IGP.

## Procedure

1. **Confirm the Solidity constant exists.** Open `contracts/payloads/common/constants.sol` and locate the `*_ADDRESS` constant. If it does not exist, add it there first — otherwise the payload will not compile and `tokenUsage.ts` cannot detect it.
2. **Gather the token facts.**
   - Mainnet address (checksummed).
   - ERC-20 decimals.
   - CoinGecko id — search the CoinGecko website; the slug in the URL path is the id (`coingecko.com/en/coins/<slug>`). Pin the canonical wrapped/staked variant, not a bridged one.
3. **Pick a rounding rule** from `scripts/verify/lib/rounding.ts`:
   - `exactOneDollar` — anything pegged to $1 (stables). Emits `1 * 1e2`, no fetch.
   - `nearestCent` — yield-bearing stables, governance tokens. `Math.round(usd * 100) / 100`.
   - `nearestTenDollars` — ETH + LSTs/LRTs, gold (XAUT, PAXG). `Math.round(usd / 10) * 10`.
   - `nearestThousandDollars` — BTC family. `Math.round(usd / 1000) * 1000`.
   - If no rule fits, add one to `rounding.ts` *and* update this skill. Adding a rule is rare; prefer reusing an existing one.
4. **Pick a `priceVarName`.**
   - A new token with its own price: use `<SYMBOL>_USD_PRICE` (e.g. `weETH_USD_PRICE`).
   - A token that shares a price with a family: reuse the family's name (stables → `STABLE_USD_PRICE`, BTC → `BTC_USD_PRICE`, INST/FLUID → `FLUID_USD_PRICE`). Each entry still carries its own `decimals`.
5. **Append the entry** to `TOKENS` in `scripts/verify/lib/tokens.ts`, in the category section it belongs to (comment headers mark each category).
6. **Re-run** `npm run verify:prices -- --payload IGP<N>`. The script should now print the price summary and write the block.
7. **Sanity-check** the CoinGecko quote in the summary table against a trusted source (CoinGecko homepage, Coinbase, Kraken). Order-of-magnitude mismatches mean a wrong `coingeckoId`.

## Worked example — adding `rETH`

Suppose `PayloadIGP130` adds a new Liquidity action for Rocket Pool ETH. `rETH_ADDRESS` is added to `constants.sol`. `prepare-prices.ts` then fails:

```
Unknown token address identifier(s) used by IGP130:
  - rETH_ADDRESS
```

rETH facts:

- Mainnet address: `0xae78736Cd615f374D3085123A210448E74Fc6393`.
- Decimals: `18`.
- CoinGecko id: `rocket-pool-eth` (confirmed from `coingecko.com/en/coins/rocket-pool-eth`).
- Price tracks ETH ± rewards-accrual premium. Same category as the other LSTs → `nearestTenDollars` and its own `rETH_USD_PRICE` constant (not shared with ETH — the premium matters).

Edit `scripts/verify/lib/tokens.ts`, in the LST section:

```ts
{
  symbol: "rETH",
  address: "0xae78736Cd615f374D3085123A210448E74Fc6393",
  constantName: "rETH_ADDRESS",
  decimals: 18,
  coingeckoId: "rocket-pool-eth",
  priceVarName: "rETH_USD_PRICE",
  rounding: "nearestTenDollars",
},
```

Re-run `npm run verify:prices -- --payload IGP130`; it now emits:

```solidity
uint256 public constant rETH_USD_PRICE = 2_240 * 1e2;
...
else if (token == rETH_ADDRESS) {
    usdPrice = rETH_USD_PRICE;
    decimals = 18;
}
```

## Don'ts

- Don't invent a CoinGecko id — if the coin isn't on CoinGecko, raise it with reviewers first. No alternative price source is wired up.
- Don't add a rounding rule just because a single token's price is awkward. If the category doesn't exist, the token is probably unusual enough to warrant an explicit discussion.
- Don't edit existing payloads (`IGP7` … `IGP128`) as part of adding a token — the registry only affects future payloads.
- Don't skip step 7. A wrong CoinGecko id can still fetch — just for the wrong coin.
