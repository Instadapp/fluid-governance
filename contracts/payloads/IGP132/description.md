# Upgrade Liquidity Layer Modules, Rotate Auths, Tighten Legacy Vault Limits, and Launch USDai Ecosystem Dust Limits

## Summary

This proposal performs thirteen Ethereum actions: (1–2) register and upgrade the Liquidity Layer **UserModule** on the InfiniteProxy with RollbackModule safety; (3–4) register and upgrade the **AdminModule** the same way; (5) rotate Liquidity Layer guardian and DexFactory pause auths; (6) rotate Liquidity Layer rates auth; (7) rotate DexFactory range auth; (8) reduce base withdrawal limits on legacy mainnet vaults **1–10** to **total supply + 5%**; (9) set conservative dust limits and Team Multisig auth on the USDai ecosystem (**DEXes 46–48**, **vaults 170–177**); (10) set max supply shares to **0** on the USR-USDC DEX (**Pool 20**) and RLP-USDC DEX (**Pool 28**); (11) update USDC and USDT Liquidity Layer rate curves to **15% max at 100% utilization**; (12) claim accumulated **iETHv2 (Lite) stETH revenue** to Team Multisig; (13) reserve a placeholder for **Ethereum vault limit updates** (no-op in this draft). New module, auth, and Lite revenue amounts are configurable by Team Multisig before execution.

**Tokens**: USDai (`0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF`), sUSDai (`0x0B2b2B2076d95dda7817e785989fE353fe955ef9`).

## Code Changes

### Actions 1–7: Module Upgrades and Auth Rotations

See prior IGP-132 scope: UserModule/AdminModule upgrades with rollback registration, pause guardian + DexFactory pause auth rotation, Liquidity Layer rates auth rotation, and DexFactory range auth rotation. All new implementation and auth addresses are configurable by Team Multisig before execution.

### Action 8: Reduce Base Withdrawal Limits on Legacy Vaults 1–10

Sets each vault’s Liquidity Layer base withdrawal limit to **current total supply + 5%** in raw supply-token units, with max-restricted expansion. Borrow limits are unchanged.

| Vault | Pair | New base withdrawal limit |
| --- | --- | --- |
| 1 | ETH / USDC | `0.628187` ETH |
| 2 | ETH / USDT | `0.945974` ETH |
| 3 | wstETH / ETH | `0.646899` wstETH |
| 4 | wstETH / USDC | `0.544134` wstETH |
| 5 | wstETH / USDT | `0.549870` wstETH |
| 6 | weETH / wstETH | `695.132095` weETH |
| 7 | sUSDe / USDC | `3298.946018` sUSDe |
| 8 | sUSDe / USDT | `413.657754` sUSDe |
| 9 | weETH / USDC | `0.240487` weETH |
| 10 | weETH / USDT | `0.213728` weETH |

### Action 9: USDai Ecosystem Dust Limits + Team Multisig Auth

Assumes deployments receive **DEX ids 46–48** and **vault ids 170–177** when batched in order.

| Market | Id | Type | Dust limits |
| --- | --- | --- | --- |
| USDai-USDC DEX | 46 | smart col | `$10k` base withdrawal per token |
| sUSDai-USDC DEX | 47 | smart col | `$10k` per token |
| sUSDai-USDT DEX | 48 | smart col | `$10k` per token |
| USDai / USDC | 170 | TYPE_1 | `$7k` / `$7k` / `$9k` withdraw / base borrow / max borrow |
| sUSDai / USDC | 171 | TYPE_1 | `$7k` / `$7k` / `$9k` |
| sUSDai / USDT | 172 | TYPE_1 | `$7k` / `$7k` / `$9k` |
| sUSDai / USDC-USDT | 173 | TYPE_3 | `$7k` supply; USDC-USDT DEX (id **2**) borrow shares `3500e18` / `4500e18` |
| sUSDai-USDC / USDC-USDT | 174 | TYPE_4 | USDC-USDT DEX borrow shares `3500e18` / `4500e18`; smart col at DEX **47** |
| sUSDai-USDT / USDC-USDT | 175 | TYPE_4 | USDC-USDT DEX borrow shares `3500e18` / `4500e18`; smart col at DEX **48** |
| sUSDai-USDT / USDT | 176 | TYPE_2 | USDT debt `$7k` / `$9k`; smart col at DEX **48** |
| sUSDai-USDC / USDC | 177 | TYPE_2 | USDC debt `$7k` / `$9k`; smart col at DEX **47** |

Team Multisig auth is granted on all three DEXes and eight vaults.

### Action 10: Set USR and RLP DEX Max Supply Shares to 0

- **DEX Pool 20** — USR-USDC: `updateMaxSupplyShares(0)`
- **DEX Pool 28** — RLP-USDC: `updateMaxSupplyShares(0)`
- **Purpose**: Prevent new supply on these DEXes while existing LPs retain withdrawal access

### Action 11: Update USDC and USDT Rate Curves

Updates both tokens via `updateRateDataV2s` on the Liquidity Layer (V2 rate curve):

| Token | Kink 1 | Kink 2 | Rate @ 0% | Rate @ Kink 1 | Rate @ Kink 2 | Rate @ 100% |
| --- | --- | --- | --- | --- | --- | --- |
| USDC | 85% | 93% | 0% | 6% | 8% | **15%** |
| USDT | 85% | 93% | 0% | 6% | 8% | **15%** |

### Action 12: Claim iETHv2 (Lite) stETH Revenue

- **Lite contract**: iETHv2 (`0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78`)
- **Amount**: Configurable via `setLiteStethRevenueAmount()` by Team Multisig (stETH wei)
- **Step 1**: `IETHV2.collectRevenue(amount)` — pull accrued Lite revenue into treasury
- **Step 2**: Treasury DSA `BASIC-A` `withdraw` — transfer stETH to Team Multisig
- **Purpose**: Claim accumulated Fluid Lite revenue for operational use

### Action 13: Ethereum Vault Limit Updates (Placeholder)

- No-op in this draft. To be filled in with limit updates across Ethereum vaults before finalizing IGP-132.

## Description

**Actions 1–7** upgrade Liquidity Layer modules and rotate operational auths (configurable addresses from Team Multisig). **Action 8** tightens withdrawal headroom on the oldest vaults to on-chain supply plus 5%. **Action 9** launches the USDai ecosystem at dust scale. **Action 10** sets max supply shares to zero on the USR-USDC and RLP-USDC DEXes. **Action 11** caps USDC and USDT borrow rates at 15% at full utilization. **Action 12** collects iETHv2 stETH revenue and forwards it to Team Multisig. **Action 13** reserves space for a batch of Ethereum vault limit updates to be added before submission.

### Configurable Values (Team Multisig sets before execution)

| Variable | Purpose |
| --- | --- |
| `newUserModuleAddress` | New UserModule implementation |
| `newAdminModuleAddress` | New AdminModule implementation |
| `liquidityPauseAuth` | New Liquidity Layer guardian |
| `dexPauseAuth` | New DexFactory pause global auth |
| `newRatesAuth` | New Liquidity Layer rates auth |
| `newRangeAuth` | New DexFactory range global auth |
| `liteStethRevenueAmount` | stETH amount for iETHv2 revenue claim (Action 12) |

Module and auth groups have Team Multisig-only `lock…()` functions. Unset addresses or a zero revenue amount cause the dependent action to revert.

## Conclusion

IGP-132 upgrades Liquidity Layer modules with rollback safety, rotates pause/rates/range authorization, aligns legacy vault withdrawal limits, launches the USDai ecosystem at dust limits, caps USR/RLP DEX supply, updates USDC/USDT rate curves, claims iETHv2 Lite revenue, and reserves a placeholder for Ethereum vault limit updates to be finalized before submission.
