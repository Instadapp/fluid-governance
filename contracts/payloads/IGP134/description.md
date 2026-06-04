# Launch USDai Dust Limits, Cap USR/RLP DEX Supply, and Claim Lite Revenue

## Summary

This proposal performs three Ethereum actions: (1) set conservative dust limits and Team Multisig auth on the USDai ecosystem (**DEXes 46–48**, **vaults 170–178**); (2) set max supply shares to **0** on the USR-USDC DEX (**Pool 20**) and RLP-USDC DEX (**Pool 28**); (3) claim accumulated **iETHv2 (Lite) stETH revenue** to Team Multisig. The Lite revenue amount is configurable by Team Multisig before execution.

**Tokens**: USDai (`0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF`), sUSDai (`0x0B2b2B2076d95dda7817e785989fE353fe955ef9`).

Legacy vault 1–10 and sUSDS sunset withdrawal limits (former actions 1 and 5 of the IGP-133 draft) were split out; see `IGP133-actions-1-and-5-description.md` on the Desktop.

Module upgrades and auth rotations (former actions 1–7 of the original IGP-132 draft) ship in a separate follow-on payload.

## Code Changes

### Action 1: USDai Ecosystem Dust Limits + Team Multisig Auth

Assumes deployments receive **DEX ids 46–48** and **vault ids 170–178** when batched in order.

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
| sUSDai / GHO | 178 | TYPE_1 | `$7k` / `$7k` / `$9k` |

Team Multisig auth is granted on all three DEXes and nine vaults.

### Action 2: Set USR and RLP DEX Max Supply Shares to 0

- **DEX Pool 20** — USR-USDC: `updateMaxSupplyShares(0)`
- **DEX Pool 28** — RLP-USDC: `updateMaxSupplyShares(0)`
- **Purpose**: Prevent new supply on these DEXes while existing LPs retain withdrawal access

### Action 3: Claim iETHv2 (Lite) stETH Revenue

- **Lite contract**: iETHv2 (`0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78`)
- **Amount**: Configurable via `setLiteStethRevenueAmount()` by Team Multisig (stETH wei)
- **Step 1**: `IETHV2.collectRevenue(amount)` — pull accrued Lite revenue into treasury
- **Step 2**: Treasury DSA `BASIC-A` `withdraw` — transfer stETH to Team Multisig
- **Purpose**: Claim accumulated Fluid Lite revenue for operational use

## Description

**Action 1** launches the USDai ecosystem at dust scale. **Action 2** sets max supply shares to zero on the USR-USDC and RLP-USDC DEXes. **Action 3** collects iETHv2 stETH revenue and forwards it to Team Multisig.

### Configurable Values (Team Multisig sets before execution)

| Variable | Purpose |
| --- | --- |
| `liteStethRevenueAmount` | stETH amount for iETHv2 revenue claim (Action 3) |

A zero revenue amount causes Action 3 to revert.

## Conclusion

IGP-134 launches the USDai ecosystem at dust limits, caps USR/RLP DEX supply, and claims iETHv2 Lite revenue.
