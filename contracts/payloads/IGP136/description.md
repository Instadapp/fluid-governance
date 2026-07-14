# Collect Liquidity Layer Revenue, Migrate sUSDai Vault Oracles, Rebalance PST Vault 169, and Set reUSD Launch Limits

## Summary

This proposal:

1. Collects the **Liquidity Layer revenue** for every token accruing >$5k (USDC, USDT, ETH, GHO, weETH) into the Fluid Reserve and forwards it to Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`).
2. Migrates the **8 live sUSDai vault oracles** (vaults 171–173, 175–179) to newly deployed oracles referencing **CappedRateChainlink_SUSDAI** (`0xC5D27C5d356479b681328351F1583c63051E76a0`, DF nonce 258) and re-points the sUSDai-USDC (DEX **46**) and sUSDai-USDT (DEX **48**) center prices to the same capped rate.
3. Rebalances the supply-side drift on the **PST T4 vault 169** from the Reserve.
4. Raises **reUSD vault 170** (T4) and **vault 181** (T3) from dust limits (IGP-135) to launch limits and removes Team Multisig auth on both.

## Code Changes

### Action 1: Collect Liquidity Layer Revenue and Forward to Team Multisig

- `LIQUIDITY.collectRevenue` into the Reserve (`0x264786EF916af64a1DB19F513F24a3681734ce92`) for the >$5k tokens: USDC ~$84.7k, USDT ~$50.8k, ETH ~$36.5k, GHO ~$8.8k, weETH ~$5.4k. Tokens below $5k (wstETH ~$4.5k, USDe ~$3.2k) are excluded.
- `withdrawFunds` forwards each balance minus operational dust (`-10` for 6-decimal tokens, `-0.1 ether` for 18-decimal and native ETH) to Team Multisig, reason `"REVENUE COLLECTION"`. **USDC retains `3,400` in the Reserve** to self-fund the Action 3 rebalance's USDC leg.

### Action 2: Migrate sUSDai Vault Oracles to the Capped Chainlink Rate

Eight `updateOracle` calls — T1 vaults by address, T2/T3/T4 by DeployerFactory nonce. Each new oracle's rates are sanity-checked on-chain during the update; max operate-rate delta vs the current oracles is **<0.01%**.

| vaultId | Type | Market | Argument | New oracle (DF nonce) |
| --- | --- | --- | --- | --- |
| 171 | T1 | sUSDai / USDC | address `0x08E954EfD116563894dec499EFF1Ed34F4B1Ef4e` | GenericOracle_SUSDAI_USDC (259) |
| 172 | T1 | sUSDai / USDT | address `0xcDC110DCE4A65c15F613D37D99450dbbC853eA72` | GenericOracle_SUSDAI_USDT (260) |
| 179 | T1 | sUSDai / GHO | address `0x0327cBbBFd3BfF6F32EB0A832F00c7B382b863B4` | GenericOracle_SUSDAI_GHO (261) |
| 178 | T2 | sUSDai-USDC / USDC | nonce 262 | DexSmartColPegOracle_SUSDAI-USDC_USDC (262) |
| 177 | T2 | sUSDai-USDT / USDT | nonce 263 | DexSmartColPegOracle_SUSDAI-USDT_USDT (263) |
| 173 | T3 | sUSDai / USDC-USDT | nonce 264 | DexSmartDebtPegOracle_SUSDAI_USDC-USDT (264) |
| 175 | T4 | sUSDai-USDC / USDC-USDT | nonce 265 | DexSmartDebtPegOracle_T4_SUSDAI-USDC_USDC-USDT (265) |
| 176 | T4 | sUSDai-USDT / USDC-USDT | nonce 266 | DexSmartDebtPegOracle_T4_SUSDAI-USDT_USDC-USDT (266) |

Center prices for DEX 46 (`0xA2E3A4e2A08b5714FA974Ce88466D736BD8b39d9`) and DEX 48 (`0xb9b87A1B79891A8C9251F501B1b5d71bC7c8aA24`) move from the current contract (DF nonce 248) to the capped rate (258) with a `1% / 2 days` bound (IGP-105 pattern); the near-identical new value completes the shift well within the cap. DEX 47 (USDai-USDC) does not track the sUSDai rate and is left unchanged.

### Action 3: Rebalance PST T4 Vault (169) Supply Drift from the Reserve

Vault 169 (smart col `Dex_PST_USDC` / smart debt `Dex_USDC_USDT`, `0x04F461756D3799Bfa05f1a367c41FaBa09743791`) has drifted **+2,809 col shares ≈ ~2,268 PST + ~3,132 USDC (~$5.4k)** above its Liquidity-layer supply position (supply rewards). Flow (IGP-131 pattern):

1. Approve the vault to pull `2,400 PST` + `3,400 USDC` from the Reserve.
2. Temporarily allow-list the Timelock as rebalancer and run `rebalanceDexVaults` on vault 169 — the supply drift is deposited back into the collateral DEX (bounded by the approvals and the vault's own share drift), and any positive smart-debt drift (USDC/USDT) flows into the Reserve — then remove the allow-list entry.
3. Revoke the leftover PST + USDC allowance.

### Action 4: reUSD DEX 44 + Vaults 170 + 181 Launch Limits + Remove Team MS Auth

Raises the reUSD market from dust limits (IGP-135) to launch limits. Vault risk params (CF 87% / LT 90% / LML 93% / LP 3.5%) and the DEX 44 fee (`2 bps`), range (`0.3%` symmetric) and Team MS auth are already set via MS1.

| Market | Change |
| --- | --- |
| DEX 44 (reUSD-USDT, smart col) | Max supply shares → `12.1M` (~$24M @ ~$1.98/share; from ~`6M` on-chain); `$10M` base withdrawal per token (reUSD + USDT) |
| Vault 170 (T4 reUSD-USDT / USDC-USDT, `0x18aEcd810742a6aE160F4C641fBbb14f15b7ED55`) | Col: `~$8M` base withdrawal (`4M` DEX 44 shares), **35%** / 6h. Debt: `~$5M` / `~$10M` base/max borrow (`2.5M` / `5M` DEX 2 shares), **30%** / 6h. Team MS auth removed |
| Vault 181 (T3 reUSD / GHO-USDC, `0x1e3a423bBD2820B08a7Dca2E5D683C143BB11c53`) | Supply: `$8M` REUSD base withdrawal, **35%** / 6h. Debt: `~$5M` / `~$10M` base/max borrow (`2.5M` / `5M` DEX 4 shares), **30%** / 6h. Team MS auth removed |

GHO-USDC DEX (id 4) max borrow shares (`~21.6M`) already cover the vault's `$10M` borrow cap; no DEX-level cap change needed.

## Conclusion

IGP-136 collects the >$5k Liquidity Layer revenue (USDC, USDT, ETH, GHO, weETH) into the Fluid Reserve and forwards it to Team Multisig, migrates the 8 sUSDai vault oracles and the DEX 46/48 center prices to CappedRateChainlink_SUSDAI, rebalances the PST T4 vault (169) supply drift from the Reserve, and raises reUSD vaults 170 and 181 to launch limits with Team Multisig auth removed.
