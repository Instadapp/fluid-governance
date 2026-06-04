# Tighten Legacy Vault Limits, Launch USDai Dust Limits, and Update Rates / DEX Caps

## Summary

This proposal performs six Ethereum actions: (1) reduce base withdrawal limits on legacy mainnet vaults **1–10** to **total supply + 5%**; (2) set conservative dust limits and Team Multisig auth on the USDai ecosystem (**DEXes 46–48**, **vaults 170–177**); (3) set max supply shares to **0** on the USR-USDC DEX (**Pool 20**) and RLP-USDC DEX (**Pool 28**); (4) update USDC and USDT Liquidity Layer rate curves to **15% max at 100% utilization**; (5) claim accumulated **iETHv2 (Lite) stETH revenue** to Team Multisig; (6) restrict base withdrawal limits on **sUSDS sunset vaults 58 and 85**. The Lite revenue amount is configurable by Team Multisig before execution.

**Tokens**: USDai (`0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF`), sUSDai (`0x0B2b2B2076d95dda7817e785989fE353fe955ef9`).

Module upgrades and auth rotations (former actions 1–7 of the original draft) ship in a separate follow-on payload.

## Code Changes

### Action 1: Reduce Base Withdrawal Limits on Legacy Vaults 1–10

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

### Action 2: USDai Ecosystem Dust Limits + Team Multisig Auth

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

### Action 3: Set USR and RLP DEX Max Supply Shares to 0

- **DEX Pool 20** — USR-USDC: `updateMaxSupplyShares(0)`
- **DEX Pool 28** — RLP-USDC: `updateMaxSupplyShares(0)`
- **Purpose**: Prevent new supply on these DEXes while existing LPs retain withdrawal access

### Action 4: Update USDC and USDT Rate Curves

Updates both tokens via `updateRateDataV2s` on the Liquidity Layer (V2 rate curve):

| Token | Kink 1 | Kink 2 | Rate @ 0% | Rate @ Kink 1 | Rate @ Kink 2 | Rate @ 100% |
| --- | --- | --- | --- | --- | --- | --- |
| USDC | 85% | 93% | 0% | 6% | 8% | **15%** |
| USDT | 85% | 93% | 0% | 6% | 8% | **15%** |

### Action 5: Claim iETHv2 (Lite) stETH Revenue

- **Lite contract**: iETHv2 (`0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78`)
- **Amount**: Configurable via `setLiteStethRevenueAmount()` by Team Multisig (stETH wei)
- **Step 1**: `IETHV2.collectRevenue(amount)` — pull accrued Lite revenue into treasury
- **Step 2**: Treasury DSA `BASIC-A` `withdraw` — transfer stETH to Team Multisig
- **Purpose**: Claim accumulated Fluid Lite revenue for operational use

### Action 6: Restrict Base Withdrawal Limits on sUSDS Sunset Vaults

Sets max-restricted expansion on each vault’s Liquidity Layer supply config. Borrow limits are unchanged.

| Vault | Market | Supply token | New base withdrawal limit |
| --- | --- | --- | --- |
| 58 | sUSDS / GHO | sUSDS | `650` sUSDS |
| 85 | wstETH / sUSDS | wstETH | `~0.009372630468` wstETH |

## Description

**Action 1** tightens withdrawal headroom on the oldest vaults to on-chain supply plus 5%. **Action 2** launches the USDai ecosystem at dust scale. **Action 3** sets max supply shares to zero on the USR-USDC and RLP-USDC DEXes. **Action 4** caps USDC and USDT borrow rates at 15% at full utilization. **Action 5** collects iETHv2 stETH revenue and forwards it to Team Multisig. **Action 6** caps withdrawals on the sUSDS/GHO and wstETH/sUSDS vaults as part of sunsetting the sUSDS vault set.

### Configurable Values (Team Multisig sets before execution)

| Variable | Purpose |
| --- | --- |
| `liteStethRevenueAmount` | stETH amount for iETHv2 revenue claim (Action 5) |

A zero revenue amount causes Action 5 to revert.

## Conclusion

IGP-133 aligns legacy vault withdrawal limits, launches the USDai ecosystem at dust limits, caps USR/RLP DEX supply, updates USDC/USDT rate curves, claims iETHv2 Lite revenue, and restricts withdrawals on sUSDS sunset vaults 58 and 85.
