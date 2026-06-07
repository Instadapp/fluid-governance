# Launch the USDai Ecosystem on Ethereum at Dust Limits

## Summary

This proposal brings the USDai ecosystem live on Ethereum at **dust limits**: it sets conservative supply / borrow limits and grants Team Multisig auth on the three new USDai DEXes (**ids 46–48**) and the nine new USDai / sUSDai vaults (**ids 170–178**). Every market is enabled but capped near zero so liquidity, oracles, and integrations can be validated on-chain before launch-scale limits are raised in a follow-up proposal.

**Tokens**: USDai (`0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF`), sUSDai (`0x0B2b2B2076d95dda7817e785989fE353fe955ef9`).

## Code Changes

### Action 1: USDai Ecosystem Dust Limits + Team Multisig Auth

Assumes the deployments receive **DEX ids 46–48** and **vault ids 170–178** when batched in order. Team Multisig auth is granted on all three DEXes and nine vaults so operators can adjust configuration during the dust phase.

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

- **Smart-collateral DEXes (46–48)** get a `$10k` base withdrawal limit on each underlying token (50% expand / 1h) via `setDexLimits`.
- **TYPE_1 vaults (170, 171, 172, 178)** get `$7k` base withdrawal, `$7k` base borrow, and `$9k` max borrow at the Liquidity Layer (50% expand / 6h).
- **TYPE_3 vault (173)** gets a `$7k` smart-collateral supply limit and a `3500e18` / `4500e18` (~`$7k` / `$9k`) borrow-shares limit on the USDC-USDT DEX (id **2**).
- **TYPE_4 vaults (174, 175)** get only the `3500e18` / `4500e18` borrow-shares limit on the USDC-USDT DEX (id **2**); their collateral lives on DEXes 47 / 48.
- **TYPE_2 vaults (176, 177)** get `$7k` / `$9k` base / max debt ceilings on their borrow token (30% expand / 6h); their collateral lives on DEXes 48 / 47.

## Description

USDai is a `$1`-pegged stable and sUSDai is its yield-bearing variant. This proposal is the first step of the USDai launch on Fluid: it wires up the new DEXes and vaults with intentionally tiny limits so the markets are live for end-to-end verification (pricing, liquidations, routing, UI) without exposing the protocol to meaningful risk.

Because the Fluid admin modules reject literal-zero limits, the borrow-only sides of the smart-collateral DEXes are left at `0` (no smart debt configured), and every other ceiling is set to a small dust value. sUSDai is conservatively priced at `$1.00` for the dust-limit conversions; the exact valuation is irrelevant at this scale and will be revisited when launch limits are set.

Launch-scale limits (max shares, LR/UR, fees, and full vault risk parameters) are **not** included here and will follow in a subsequent proposal once the dust phase is validated.

## Conclusion

IGP-133 launches the USDai ecosystem on Ethereum at dust limits, enabling DEXes 46–48 and vaults 170–178 with minimal supply / borrow ceilings and Team Multisig auth, in preparation for a later launch-limits proposal.
