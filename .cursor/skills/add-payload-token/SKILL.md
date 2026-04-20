---
name: add-payload-token
description: Register a new token so `prepare-prices.ts` can emit its price override for future payloads. Use when `prepare-prices.ts` exits with "Unknown token address identifier" or "pricehelpers.sol has no dispatch branch for…", or when introducing a brand-new token to a payload.
---

# Add a payload token

Two files must stay in sync for a token to be priceable from a payload:

1. `scripts/verify/lib/tokens.ts` — tells `prepare-prices.ts` which CoinGecko id and rounding rule to use and which `*_USD_PRICE()` override to emit.
2. `contracts/payloads/common/pricehelpers.sol` — tells on-chain `getRawAmount` which price getter + decimals to use for a given token address, and declares the `*_USD_PRICE()` virtual getter itself.

Every `*_ADDRESS` constant a payload references that flows through `getRawAmount` must have an entry in *both* files. The script checks both and refuses to proceed otherwise.

## When this skill applies

- `npm run verify:prices -- --payload IGP<N>` exited with code `2` and printed either:
  - `Unknown token address identifier(s) used by ...` — the token is missing from `tokens.ts`, **or**
  - `pricehelpers.sol has no dispatch branch for ...` — the token is in `tokens.ts` but not wired into `pricehelpers.sol`.
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
   - A token that shares a price with a family: reuse the family's name (`STABLE_USD_PRICE`, `BTC_USD_PRICE`, `FLUID_USD_PRICE`). Each entry still carries its own `decimals` — the dispatch carries them per-token, not per-group.
5. **Append the `tokens.ts` entry** to `TOKENS` in `scripts/verify/lib/tokens.ts`, in the category section it belongs to (comment headers mark each category).
6. **Wire up `pricehelpers.sol`** (skip parts already present if you're reusing a family priceVar):
   - Add an `else if (token == X_ADDRESS) { usdPrice = X_USD_PRICE(); decimals = N; }` branch in `getRawAmount`, placed in the category block that matches the token (ETH/LST, BTC, stable, yield-bearing stable, gov, gold).
   - If the `priceVarName` is brand-new (not shared), declare a reverting virtual getter lower in the file:
     ```solidity
     function X_USD_PRICE() public pure virtual returns (uint256) {
         revert("X_USD_PRICE not set");
     }
     ```
   - If you're reusing an existing priceVar (e.g. adding another stable → `STABLE_USD_PRICE`), only the dispatch branch is needed. Do **not** duplicate the virtual getter.
7. **Re-run** `npm run verify:prices -- --payload IGP<N>`. The script should now print the price summary and write the override block.
8. **Sanity-check** the CoinGecko quote in the summary table against a trusted source (CoinGecko homepage, Coinbase, Kraken). Order-of-magnitude mismatches mean a wrong `coingeckoId`.
9. **Compile** with `npx hardhat compile` to confirm the updated `pricehelpers.sol` still builds cleanly alongside every existing payload.

## Worked example — adding `rETH`

Suppose `PayloadIGP130` adds a new Liquidity action for Rocket Pool ETH. `rETH_ADDRESS` is added to `constants.sol`. `prepare-prices.ts` first fails with an `Unknown token address identifier`:

```
Unknown token address identifier(s) used by IGP130:
  - rETH_ADDRESS
```

rETH facts:

- Mainnet address: `0xae78736Cd615f374D3085123A210448E74Fc6393`.
- Decimals: `18`.
- CoinGecko id: `rocket-pool-eth` (confirmed from `coingecko.com/en/coins/rocket-pool-eth`).
- Price tracks ETH ± rewards-accrual premium. Same category as the other LSTs → `nearestTenDollars` and its own `rETH_USD_PRICE` (not shared with ETH — the premium matters).

**Step 5 — edit `scripts/verify/lib/tokens.ts`**, in the LST section:

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

Re-running now fails one step further — the dispatch-coverage check:

```
pricehelpers.sol has no dispatch branch for:
  - rETH_ADDRESS (priceVar=rETH_USD_PRICE, decimals=18)
```

**Step 6 — edit `contracts/payloads/common/pricehelpers.sol`**. In `getRawAmount`, inside the LST block:

```solidity
} else if (token == rETH_ADDRESS) {
    usdPrice = rETH_USD_PRICE();
    decimals = 18;
```

And lower in the file, next to the other LST getters:

```solidity
function rETH_USD_PRICE() public pure virtual returns (uint256) {
    revert("rETH_USD_PRICE not set");
}
```

Re-run `npm run verify:prices -- --payload IGP130`; it now emits inside the payload:

```solidity
// --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
// fetched: 2026-…, source: coingecko
function rETH_USD_PRICE() public pure override returns (uint256) { return 2_240 * 1e2; }
// --- END AUTO-GENERATED PRICES ---
```

Final `npx hardhat compile` confirms backward compatibility.

## Shortcut — adding another stable (shared priceVar)

If the new token shares an existing priceVar (say another $1-pegged stable `newUSD`), the work is smaller:

- `tokens.ts`: add an entry with `priceVarName: "STABLE_USD_PRICE"` and `rounding: "exactOneDollar"`.
- `pricehelpers.sol`: add only the dispatch branch in the stables block:
  ```solidity
  } else if (token == newUSD_ADDRESS) {
      usdPrice = STABLE_USD_PRICE();
      decimals = 18;
  ```
  Do **not** add a new virtual getter — `STABLE_USD_PRICE` already exists.

## Don'ts

- Don't invent a CoinGecko id — if the coin isn't on CoinGecko, raise it with reviewers first. No alternative price source is wired up.
- Don't add a rounding rule just because a single token's price is awkward. If the category doesn't exist, the token is probably unusual enough to warrant an explicit discussion.
- Don't edit existing payloads (`IGP7` … `IGP128`) as part of adding a token — the registry and `pricehelpers.sol` only affect future payloads.
- Don't duplicate virtual getters for shared priceVars (`STABLE_USD_PRICE`, `BTC_USD_PRICE`, `FLUID_USD_PRICE`) — declare once, dispatch many.
- Don't skip step 8. A wrong CoinGecko id can still fetch — just for the wrong coin.
