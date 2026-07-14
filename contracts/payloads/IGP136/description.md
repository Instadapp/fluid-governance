# Collect Liquidity Layer Revenue and Forward to Team Multisig, and Migrate sUSDai Vault Oracles

## Summary

This proposal performs four Ethereum actions:

1. Collects the **Liquidity Layer revenue for every token currently accruing more than $5k of uncollected revenue** (USDC, USDT, ETH, GHO, weETH) into the Fluid Reserve Contract, then withdraws the swept balances from the Reserve to Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`).
2. Migrates the **8 live sUSDai vault oracles** (vaults 171–173, 175–179) from the raw exchange-rate contract to newly deployed oracles referencing **CappedRateChainlink_SUSDAI** (`0xC5D27C5d356479b681328351F1583c63051E76a0`, DF nonce 258), and re-points the **sUSDai-USDC (DEX 46)** and **sUSDai-USDT (DEX 48)** DEX center prices to the same capped rate (DF nonce 258).
3. Rebalances the supply-side drift on the **PST T4 vault** (`169`, smart col `Dex_PST_USDC` / smart debt `Dex_USDC_USDT`, `0x04F461756D3799Bfa05f1a367c41FaBa09743791`) from the Reserve: approve PST + USDC, run `rebalanceDexVaults`, allow any positive smart-debt drift to flow into the Reserve, then revoke the allowance.
4. Raises **reUSD vault 170** (T4 reUSD-USDT / USDC-USDT) and **vault 181** (T3 reUSD / GHO-USDC) from dust limits (IGP-135) to launch limits and removes Team Multisig auth on both. Oracle / rebalancer / core settings are configured separately via MS1.

## Code Changes

### Action 1: Collect Liquidity Layer Revenue and Forward to Team Multisig

- **Liquidity Layer revenue**: `LIQUIDITY.collectRevenue` across the tokens with >$5k uncollected revenue, sent to the revenue collector (the Fluid Reserve):
  - `USDC` — ~$84.7k
  - `USDT` — ~$50.8k
  - `ETH` — ~$36.5k
  - `GHO` — ~$8.8k
  - `weETH` — ~$5.4k
- **Forward**: `IFluidReserveContractV2.withdrawFunds` on the Reserve (`0x264786EF916af64a1DB19F513F24a3681734ce92`) — nearly full balance per token minus operational dust (`-10` for 6-decimal tokens, `-0.1 ether` for 18-decimal tokens and native ETH) for `USDT, ETH, GHO, weETH`. **USDC retains `3,400` in the Reserve** (instead of dust) to self-fund the Action 3 rebalance's USDC leg; the remainder is forwarded.
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

### Action 3: Rebalance the PST T4 Vault (169) Supply Drift from the Reserve

The PST T4 vault (`VaultT4_DEX-PST-USDC_DEX-USDC-USDT`, id 169) has accrued a positive supply-side drift — its vault supply sits above its Liquidity-layer supply position (supply rewards / supply-rate magnifier) by roughly **+2,809 col shares ≈ ~2,268 PST + ~3,132 USDC (~$5.4k)**. This action tops the difference back into the collateral DEX (`Dex_PST_USDC`) from the Reserve.

Self-contained in-payload flow (matching the IGP-131 pattern):

1. **Approve**: `FLUID_RESERVE.approve` lets the vault pull PST + USDC from the Reserve, with buffers covering the drift with headroom:
   - PST (6 dec): `2,400 PST`
   - USDC (6 dec): `3,400 USDC`
2. **Allow-list**: `FLUID_RESERVE.updateRebalancer(TIMELOCK, true)` temporarily authorizes the Timelock as a rebalancer.
3. **Rebalance**: `FLUID_RESERVE.rebalanceDexVaults` on vault 169 deposits the supply drift back into the collateral DEX and, if any positive smart-debt drift exists, borrows it from the debt DEX into the Reserve. The deposit amount is bounded by the Reserve approvals and the vault's own share drift.
4. **Remove from allow-list**: `FLUID_RESERVE.updateRebalancer(TIMELOCK, false)`.
5. **Revoke**: `FLUID_RESERVE.revoke([169 × PST], [169 × USDC])` clears the leftover allowance.

**Prerequisite**: ~`2,400` PST must be deposited into the Reserve before execution (the USDC side is already covered by the `3,400 USDC` Action 1 retains in the Reserve).

**Borrow side**: even without a configured borrow reward or magnifier, small positive drift can accrue between the vault and DEX accounting; any such USDC/USDT amounts flow into the Reserve as part of the rebalance.

### Action 4: reUSD DEX 44 + Vaults 170 + 181 Launch Limits + Remove Team MS Auth

Raises the reUSD market from dust limits (IGP-135) to launch limits and removes Team Multisig auth. Vault risk params (CF 87% / LT 90% / LML 93% / LP 3.5%) are configured via MS1, not in this action.

**DEX 44** (reUSD-USDT, smart col) — only limits that still need raising (fee `2 bps`, range `0.3%` symmetric, and Team MS auth are already set on-chain via MS1):

| Setting | Value |
| --- | --- |
| Max supply shares | ~$24M (`12.1M` shares @ ~$1.98/share; from ~`6M` on-chain) |
| Token LL limits | `$10M` base withdrawal per token (reUSD + USDT) |

**Vault 170** (T4 reUSD-USDT / USDC-USDT, `0x18aE…ED55`):

| Leg | Where | Launch limit |
| --- | --- | --- |
| Collateral | DEX 44 | `~$8M` base withdrawal (`4M` shares), **35%** / 6h |
| Debt | DEX 2 USDC-USDT | `~$5M` / `~$10M` base/max borrow (`2.5M` / `5M` shares), **30%** / 6h |
| Auth | vault | Team MS removed (currently `true`) |

**Vault 181** (T3 reUSD / GHO-USDC, `0x1e3a…c53`):

| Leg | Where | Launch limit |
| --- | --- | --- |
| Supply | REUSD at Liquidity | `$8M` base withdrawal (**35%** / 6h) |
| Debt | DEX 4 GHO-USDC | `~$5M` / `~$10M` base/max borrow (`2.5M` / `5M` shares), **30%** / 6h |
| Auth | vault | Team MS removed (currently `true`) |

GHO-USDC DEX (id 4) on-chain max borrow shares (`~21.6M`) already comfortably covers the vault's `$10M` borrow cap; no DEX-level cap change needed.

## Description

The Liquidity Layer revenue collector is set to the Fluid Reserve, so `collectRevenue` lands the funds in the Reserve. A single `withdrawFunds` then forwards the swept balances to Team Multisig, leaving minimal operational dust behind. The Liquidity Layer token set is the set of tokens with more than $5k of uncollected revenue at preparation time; tokens below the $5k threshold (e.g. wstETH at ~$4.5k, USDe at ~$3.2k) are intentionally excluded.

Action 2 migrates the 8 live sUSDai vaults to the newly deployed capped-rate oracles and re-points the sUSDai-USDC (DEX 46) and sUSDai-USDT (DEX 48) center prices to the same capped rate. Each new oracle's rates are sanity-checked on-chain as part of the update. The expected operate-rate impact is below 0.01% for every pair.

## Conclusion

IGP-136 (1) collects the Liquidity Layer revenue for tokens accruing more than $5k (USDC, USDT, ETH, GHO, weETH) into the Fluid Reserve and forwards the proceeds to Team Multisig, (2) migrates the 8 live sUSDai vault oracles (171–173, 175–179) to the newly deployed oracles referencing CappedRateChainlink_SUSDAI and re-points the sUSDai-USDC (DEX 46) and sUSDai-USDT (DEX 48) center prices to the same capped rate, (3) rebalances the PST T4 vault (169) supply-side drift from the Reserve while allowing positive smart-debt drift to flow into the Reserve, and (4) raises reUSD vaults 170 and 181 from dust to launch limits and removes Team Multisig auth on both.
