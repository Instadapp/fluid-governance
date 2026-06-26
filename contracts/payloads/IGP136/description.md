# Collect iETHv2 (Lite) and Liquidity Layer Revenue and Forward to Team Multisig, and Migrate sUSDai Vault Oracles

## Summary

This proposal performs two Ethereum actions:

1. Collects accrued protocol revenue into the Fluid Reserve Contract and forwards it to Team Multisig. Specifically, it collects the **iETHv2 (Fluid Lite ETH) stETH revenue** and the **Liquidity Layer revenue for every token currently accruing more than $5k of uncollected revenue** (USDC, USDT, ETH, GHO, weETH), then withdraws the swept balances from the Reserve to Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`).
2. Migrates the **8 live sUSDai vault oracles** (vaults 171–173, 175–179) from the raw exchange-rate contract to newly deployed oracles referencing **CappedRateChainlink_SUSDAI** (`0xC5D27C5d356479b681328351F1583c63051E76a0`, DF nonce 258), and re-points the **sUSDai-USDC (DEX 46)** and **sUSDai-USDT (DEX 48)** DEX center prices to the same capped rate (DF nonce 258).

## Code Changes

### Action 1: Collect Revenue and Forward to Team Multisig

- **iETHv2 (Lite) revenue**: `IETHV2.collectRevenue(33.9 ether)` sends ~33.9 stETH of accrued Lite revenue to the iETHv2 treasury, which is the Fluid Reserve. `ILite.revenue()` reported `33.909507713113132477` stETH collectable at preparation time (2026-06-26); the collected amount is held a touch below the live value to stay within the collectable balance at execution, as Lite revenue accrues over time.
- **Liquidity Layer revenue**: `LIQUIDITY.collectRevenue` across the tokens with >$5k uncollected revenue, sent to the revenue collector (the Fluid Reserve):
  - `USDC` — ~$84.7k
  - `USDT` — ~$50.8k
  - `ETH` — ~$36.5k
  - `GHO` — ~$8.8k
  - `weETH` — ~$5.4k
- **Forward**: `IFluidReserveContractV2.withdrawFunds` on the Reserve (`0x264786EF916af64a1DB19F513F24a3681734ce92`) — nearly full balance per token minus operational dust (`-10` for 6-decimal tokens, `-0.1 ether` for 18-decimal tokens and native ETH) for `stETH, USDC, USDT, ETH, GHO, weETH`.
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`).
- **Reason tag**: `"REVENUE COLLECTION"`.

### Action 2: Migrate sUSDai Vault Oracles to Capped Chainlink Rate

Switches 8 sUSDai vaults from the raw exchange-rate oracles to newly deployed oracles referencing `CappedRateChainlink_SUSDAI` (DF nonce 258). Eight `updateOracle` calls; max operate-rate delta vs the current oracles is **< 0.01%**.

T1 vaults take the full new oracle address; T2/T3/T4 vaults take the DeployerFactory nonce (262–266).

| # | vaultId | Type | Market | updateOracle argument | New oracle (DF nonce) |
| --- | --- | --- | --- | --- | --- |
| 1 | 171 | T1 | sUSDai / USDC | address `0x08E954…Ef4e` | GenericOracle_SUSDAI_USDC (259) |
| 2 | 172 | T1 | sUSDai / USDT | address `0xcDC110…eA72` | GenericOracle_SUSDAI_USDT (260) |
| 3 | 179 | T1 | sUSDai / GHO | address `0x0327cB…63B4` | GenericOracle_SUSDAI_GHO (261) |
| 4 | 178 | T2 | sUSDai-USDC / USDC | nonce 262 | DexSmartColPegOracle_SUSDAI-USDC_USDC (262) |
| 5 | 177 | T2 | sUSDai-USDT / USDT | nonce 263 | DexSmartColPegOracle_SUSDAI-USDT_USDT (263) |
| 6 | 173 | T3 | sUSDai / USDC-USDT | nonce 264 | DexSmartDebtPegOracle_SUSDAI_USDC-USDT (264) |
| 7 | 175 | T4 | sUSDai-USDC / USDC-USDT | nonce 265 | DexSmartDebtPegOracle_T4_SUSDAI-USDC_USDC-USDT (265) |
| 8 | 176 | T4 | sUSDai-USDT / USDC-USDT | nonce 266 | DexSmartDebtPegOracle_T4_SUSDAI-USDT_USDC-USDT (266) |

It also re-points two DEX center prices from the current center-price contract (DF nonce 248) to the capped sUSDai rate (DF nonce 258):

| DEX | Market | Address | New center price (DF nonce) | percent / time |
| --- | --- | --- | --- | --- |
| 46 | sUSDai / USDC | `0xA2E3A4e2A08b5714FA974Ce88466D736BD8b39d9` | CappedRateChainlink_SUSDAI (258) | `1%` / `2 days` |
| 48 | sUSDai / USDT | `0xb9b87A1B79891A8C9251F501B1b5d71bC7c8aA24` | CappedRateChainlink_SUSDAI (258) | `1%` / `2 days` |

DEX 47 (USDai-USDC) does not track the sUSDai rate (it currently has no external center-price address) and is intentionally left unchanged. The `1% / 2 days` shift (matching the IGP-105 oracle + center-price migration) bounds the transition to the new capped-rate center price; since the new value is near-identical (<0.01% delta) to the current one, the shift completes well within the cap.

## Description

Both the iETHv2 treasury and the Liquidity Layer revenue collector are set to the Fluid Reserve, so each `collectRevenue` call lands the funds in the Reserve. A single `withdrawFunds` then forwards the swept balances to Team Multisig, leaving minimal operational dust behind. The Liquidity Layer token set is the set of tokens with more than $5k of uncollected revenue at preparation time; tokens below the $5k threshold (e.g. wstETH at ~$4.5k, USDe at ~$3.2k) are intentionally excluded.

Action 2 migrates the 8 live sUSDai vaults to the newly deployed capped-rate oracles and re-points the sUSDai-USDC (DEX 46) and sUSDai-USDT (DEX 48) center prices to the same capped rate. `updateOracle` probes `getExchangeRateOperate()` / `getExchangeRateLiquidate()` on each target oracle before committing. The expected operate-rate impact is below 0.01% for every pair.

## Conclusion

IGP-136 (1) collects iETHv2 (Lite) stETH revenue and the Liquidity Layer revenue for tokens accruing more than $5k (USDC, USDT, ETH, GHO, weETH) into the Fluid Reserve and forwards the proceeds to Team Multisig, and (2) migrates the 8 live sUSDai vault oracles (171–173, 175–179) to the newly deployed oracles referencing CappedRateChainlink_SUSDAI and re-points the sUSDai-USDC (DEX 46) and sUSDai-USDT (DEX 48) center prices to the same capped rate.
