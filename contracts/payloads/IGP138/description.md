# Tighten Collateral Borrow Limits, Update reUSD + osETH DEX Ranges, and Launch USDT/USDC Smart Lending

## Summary

This proposal reduces borrow surface area on legacy collateral vaults, updates two DEX trading ranges, and launches the new **USDT/USDC** smart-lending pool (DEX **49**):

1. Caps the **five osETH vaults** (153–157) at **$100k** borrow (base = max).
2. Caps the **three tBTC vaults** (88–90) and **eBTC/WBTC** vault (94) at **$100k** borrow.
3. Caps **all six LBTC vaults** (107–109, 97, 114, 115) at **$1M** max borrow (base = max).
4. Caps **ezETH T1** vault (103) at **$100k** and **ezETH-ETH T2** vault (104) at **$1M** borrow.
5. Trims the **reUSD-USDT DEX (44)** range to upper **0.15%** / lower **0.4%** over **4 days**.
6. Widens the **osETH-ETH DEX (43)** upper range to **0.5%** over **12 days** (lower stays **0.3%**).
7. Launches **USDT/USDC DEX (49)** with **$12M** max supply shares, **$5M**/token LL limits, **0.3%/0.1%** range, **0.01%** fee, and **$8M** smart-lending base withdrawal.
8. Swaps the **weETH-ETH DEX (9)** fee-handler auth from `0xD43d…B44a` (IGP-113) to `0x5346…FB6E`.

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

- `updateRangePercents(0.5%, 0.3%, 12 days)` — upper **0.5%** (from current on-chain), lower **0.3%** unchanged.

### Action 7: USDT/USDC DEX (49) Launch

Assumes DEX **49** (USDT/USDC) and its smart-lending wrapper (`fSL49`) are deployed via MS1 before execution.

| Parameter | Value |
| --- | --- |
| Max supply shares | `6M` (~$12M @ ~$2/share) |
| Token LL withdrawal limits | `$5M` each (USDT + USDC) |
| Range | LR **0.3%** / UR **0.1%**, 4-day shift |
| Fee | **0.01%** (25% revenue cut) |
| Smart-lending base withdrawal | `$8M` (`4M` shares @ ~$2/share), 50% / 6h |
| Smart-lending rebalancer | Fluid Reserve |
| Team MS auth | removed |

### Action 8: weETH-ETH DEX (9) Fee-Handler Auth Swap

IGP-113 added `0xD43d85f4F4eEDdA3ed3BbE2Ca7351eE32b8bB44a` as fee-handler auth on the weETH-ETH DEX (id **9**), replacing `0x8eaE…3100`. This action completes the next rotation:

| | Address |
| --- | --- |
| Old handler (revoked) | `0xD43d85f4F4eEDdA3ed3BbE2Ca7351eE32b8bB44a` |
| New handler (granted) | `0x534633b92E67e59D90FBCb73fb6F28CbB8c5FB6E` |

Calls: `setDexAuth(dex, old, false)` then `setDexAuth(dex, new, true)` on DEX 9 (IGP-103 / IGP-113 pattern).

## Conclusion

IGP-138 tightens borrow exposure across osETH, tBTC, eBTC, LBTC, and ezETH collateral vaults, trims the reUSD-USDT DEX range, widens the osETH-ETH DEX upper range, launches the USDT/USDC smart-lending pool at operational limits, and rotates the weETH-ETH DEX fee-handler auth to the new handler.
