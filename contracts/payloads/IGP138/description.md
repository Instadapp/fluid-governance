# Tighten Vault Borrow Limits, Update reUSD + osETH DEX Ranges, and Launch USDat/USDC && USDC/trUSD Smart Lending

## Summary

This proposal reduces borrow surface area on legacy collateral vaults, updates two DEX trading ranges, and sets initial limits for the new **USDat/USDC** (DEX **49**) and **USDC/trUSD** (DEX **50**) smart-lending pools:

1. Caps the **five osETH vaults** (153–157) at **$100k** borrow (base = max).
2. Caps the **three tBTC vaults** (88–90) and **eBTC/WBTC** vault (94) at **$100k** borrow.
3. Caps **all six LBTC vaults** (107–109, 97, 114, 115) at **$1M** max borrow (base = max).
4. Caps **ezETH T1** vault (103) at **$100k** and **ezETH-ETH T2** vault (104) at **$1M** borrow.
5. Trims the **reUSD-USDT DEX (44)** range to upper **0.15%** / lower **0.4%** over **4 days**.
6. Widens the **osETH-ETH DEX (43)** upper range to **0.5%** over **12 days** (lower stays **0.0001%**).
7. Sets **$5M**/token LL withdrawal limits for **USDat/USDC DEX (49)** and grants **Team Multisig** dex auth (initialization, max supply shares, fee, ranges, and smart-lending config handled via MS).
8. Swaps the **weETH-ETH DEX (9)** fee-handler auth from `0xD43d…B44a` (IGP-113) to `0x5346…FB6E`.
9. Raises the **legacy ETH/USDC vault (1)** ETH base withdrawal limit to **2 ETH** with a **10% / 12h** expansion to unblock stuck suppliers.
10. Sets **$5M**/token LL withdrawal limits for **USDC/trUSD DEX (50)** and grants **Team Multisig** dex auth (initialization, max supply shares, fee, ranges, and smart-lending config handled via MS).

Withdrawal limits on all vaults in Actions 1–4 are unchanged — only borrow ceilings are tightened.

## Code Changes

### Action 1: osETH Vault Borrow → $100k (Vaults 153–157)

| Vault | Type | Market | Change |
| --- | --- | --- | --- |
| 153 | T1 | osETH / USDC | Borrow `$100K / $1M` → `$100K / $100K` (LL) |
| 154 | T1 | osETH / USDT | Borrow `$100K / $1M` → `$100K / $100K` (LL) |
| 155 | T1 | osETH / GHO | Borrow `$100K / $1M` → `$100K / $100K` (LL) |
| 156 | T3 | osETH / USDC-USDT | DEX 2 borrow shares `$100K / $1M` → `$100K / $100K` |
| 157 | T3 | osETH / USDC-USDT conc. | DEX 34 borrow shares `$100K / $1M` → `$100K / $100K` |

Borrow expansion (25% / 3h) is unchanged.

### Action 2: tBTC + eBTC/WBTC Borrow → $100k (Vaults 88–90, 94)

| Vault | Type | Market | Change |
| --- | --- | --- | --- |
| 88 | T1 | tBTC / USDC | Borrow `$7.5M / $10M` → `$100K / $100K` |
| 89 | T1 | tBTC / USDT | Borrow `$7.5M / $10M` → `$100K / $100K` |
| 90 | T1 | tBTC / GHO | Borrow `$7.5M / $10M` → `$100K / $100K` |
| 94 | T1 | eBTC / WBTC | Borrow `$100K / $1M` → `$100K / $100K` |

### Action 3: LBTC Vault Max Borrow → $1M (Vaults 107–109, 97, 114, 115)

| Vault | Type | Market | Change |
| --- | --- | --- | --- |
| 107 | T1 | LBTC / USDC | Borrow `$2.5M / $25M` → `$1M / $1M` |
| 108 | T1 | LBTC / USDT | Borrow `$2.5M / $25M` → `$1M / $1M` |
| 109 | T1 | LBTC / GHO | Borrow `$2.5M / $25M` → `$1M / $1M` |
| 97 | T2 | LBTC-cbBTC / WBTC | Borrow `$2.5M / $25M` → `$1M / $1M` |
| 114 | T2 | LBTC-cbBTC / cbBTC | Borrow `$2.5M / $25M` → `$1M / $1M` |
| 115 | T2 | WBTC-LBTC / WBTC | Borrow `$2.5M / $25M` → `$1M / $1M` |

### Action 4: ezETH Borrow Caps (Vaults 103–104)

| Vault | Type | Market | Change |
| --- | --- | --- | --- |
| 103 | T1 | ezETH / wstETH | Borrow `$100K / $1M` → `$100K / $100K` |
| 104 | T2 | ezETH-ETH / wstETH | Borrow `$2.5M / $25M` → `$1M / $1M` |

### Action 5: reUSD-USDT DEX (44) Range Trim

- `updateRangePercents(0.15%, 0.4%, 4 days)` — IGP-128 sUSDe-USDT pattern.
- Current on-chain range is **0.3% symmetric** (set via MS1 at IGP-136 launch).

### Action 6: osETH-ETH DEX (43) Upper Range Increase

- `updateRangePercents(0.5%, 0.0001%, 12 days)` — upper **0.5%** (from current **0.15%**), lower **0.0001%** unchanged (current on-chain value).

### Action 7: USDat/USDC DEX (49) Initial Limits + Team MS Auth

Assumes DEX **49** (USDat/USDC) is deployed via MS1 before execution. USDat (Saturn Dollar, `0x23238f20b894f29041f48D88eE91131C395Aaa71`, 6 decimals) is token0. This action only sets Liquidity Layer limits and grants dex auth — initialization, max supply shares (~$12M planned), fee, ranges, and all smart-lending config (limits + rebalancer) are handled by the Team Multisig.

| Parameter | Value |
| --- | --- |
| Token LL withdrawal limits | `$5M` each (USDat + USDC) |
| Team MS auth | granted (`setDexAuth` on DexFactory) |

### Action 8: weETH-ETH DEX (9) Fee-Handler Auth Swap

IGP-113 added `0xD43d85f4F4eEDdA3ed3BbE2Ca7351eE32b8bB44a` as fee-handler auth on the weETH-ETH DEX (id **9**), replacing `0x8eaE…3100`. This action completes the next rotation:

| | Address |
| --- | --- |
| Old handler (revoked) | `0xD43d85f4F4eEDdA3ed3BbE2Ca7351eE32b8bB44a` |
| New handler (granted) | `0x534633b92E67e59D90FBCb73fb6F28CbB8c5FB6E` |

Calls: `setDexAuth(dex, old, false)` then `setDexAuth(dex, new, true)` on DEX 9 (IGP-103 / IGP-113 pattern).

### Action 9: Legacy ETH/USDC Vault (1) ETH Base Withdrawal Limit → 2 ETH

The legacy ETH/USDC vault (id **1**) was wound down with a frozen withdrawal-limit expansion (**0.01%** expand over **max duration**, i.e. 16777215s ≈ 194 days) and its ETH base withdrawal limit ended up at/below the vault's currently supplied balance (~0.737 ETH base vs ~0.96 ETH supplied), leaving suppliers stuck and unable to withdraw.

| Parameter | Value |
| --- | --- |
| Base withdrawal limit | `2 ETH` (from ~0.737 ETH) |
| Expand % / duration | **10%** / **12h** (from frozen 0.01% / max) |

Since 2 ETH exceeds the vault's total supplied ETH, stuck suppliers can exit in full.

### Action 10: USDC/trUSD DEX (50) Initial Limits + Team MS Auth

Assumes trUSD is [listed at the Liquidity Layer](https://docs.tori.finance/resources/contracts) and DEX **50** (USDC/trUSD) is deployed via MS1 before execution — and that it is deployed **after** USDat/USDC so the ids land as 49/50. trUSD (Tori Finance, `0xd0580192E98eA6CEB9c7b6191Ed2E27560911697`, 18 decimals) sorts above USDC, so USDC is token0. This action only sets Liquidity Layer limits and grants dex auth — initialization, max supply shares (~$10M planned), fee (0.01%), ranges (0.15%/0.15%), and smart-lending config ($8M base withdraw) are handled by the Team Multisig.

| Parameter | Value |
| --- | --- |
| Token LL withdrawal limits | `$5M` each (USDC + trUSD) |
| Team MS auth | granted (`setDexAuth` on DexFactory) |

## Pre-Execution Requirements

Actions 7 and 10 configure Liquidity Layer limits for two pools that do not exist yet (`totalDexes` is **48** at the time of writing). All three steps below must be completed by the Team Multisig **before** this payload executes, **in this order**:

| # | Step | Why it is required |
| --- | --- | --- |
| 1 | List **trUSD** at the Liquidity Layer via `LiquidityTokenAuth.listToken` | `updateUserSupplyConfigs` reverts with `AdminModule__InvalidConfigOrder` for a token with no exchange-price config, failing Action 10 |
| 2 | Deploy **USDat/USDC** — lands on DEX **49** | Action 7 reverts with `AdminModule__AddressNotAContract` if id 49 has no code |
| 3 | Deploy **USDC/trUSD** — lands on DEX **50** | Action 10 reverts with `AdminModule__AddressNotAContract` if id 50 has no code |

USDat is already listed at the Liquidity Layer; trUSD is not. Because every action runs in a single `execute()` call, missing any one of these reverts the entire proposal.

Dex ids are assigned sequentially (`dexId_ = ++_totalDexes`), so steps 2 and 3 must run in that order with no other dex deployed in between. If the order is swapped neither action reverts — each pool silently receives the other pool's token limits, and a follow-up proposal would be needed to correct it.

## Conclusion

IGP-138 tightens borrow exposure across osETH, tBTC, eBTC, LBTC, and ezETH collateral vaults, trims the reUSD-USDT DEX range, widens the osETH-ETH DEX upper range, sets initial limits for the USDat/USDC and USDC/trUSD smart-lending pools and grants Team Multisig dex auth for their rollout, rotates the weETH-ETH DEX fee-handler auth to the new handler, and raises the legacy ETH/USDC vault's ETH base withdrawal limit to unblock stuck suppliers.
