# USDai Ecosystem Launch Limits and Lite ETH Revenue Claim

## Summary

This proposal:

1. Raises the **USDai ecosystem** from dust limits (IGP-133) to **launch limits** on DEXes **46** and **48** and vaults **171–173** and **175–179**, removing Team Multisig auth on each.
2. **Holds the USDai-USDC market** (DEX **47** + vault **180**) until a later launch — vault 180 gets borrow dust limits and Team Multisig auth is retained on both (DEX 47 launch limits ship together with the vault).
3. **Deprecates** the T1 vault **174** (USDai / USDC).
4. Claims accrued **iETHv2 (Lite) stETH revenue** to Team Multisig.

Governance sets limits and auth only; per-market config (CF, LT, etc.) is applied by Team Multisig.

## Code Changes

### Action 1: USDai Ecosystem Launch Limits + Remove Team Multisig Auth

USDai (`0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF`), sUSDai (`0x0B2b2B2076d95dda7817e785989fE353fe955ef9`). Ids verified against the live Fluid `DEX_FACTORY` / `VAULT_FACTORY`.

| Market | Id | Type | Limits |
| --- | --- | --- | --- |
| sUSDai-USDC DEX | 46 | smart col | `$10M` per token |
| sUSDai-USDT DEX | 48 | smart col | `$10M` per token |
| sUSDai / USDC | 171 | TYPE_1 | `$8M / $8M / $15M` withdraw / base borrow / max borrow |
| sUSDai / USDT | 172 | TYPE_1 | `$8M / $8M / $15M` |
| sUSDai / GHO | 179 | TYPE_1 | `$8M / $8M / $15M` |
| sUSDai / USDC-USDT | 173 | TYPE_3 | `$8M` supply; USDC-USDT DEX (id **2**) borrow shares `3.6M / 6.75M` |
| sUSDai-USDC / USDC-USDT | 175 | TYPE_4 | smart col at DEX **46**; USDC-USDT DEX (id **2**) borrow shares `3.6M / 9M` |
| sUSDai-USDT / USDC-USDT | 176 | TYPE_4 | smart col at DEX **48**; USDC-USDT DEX (id **2**) borrow shares `3.6M / 9M` |
| sUSDai-USDT / USDT | 177 | TYPE_2 | USDT debt `$8M / $20M`; smart col at DEX **48** |
| sUSDai-USDC / USDC | 178 | TYPE_2 | USDC debt `$8M / $20M`; smart col at DEX **46** |

Team Multisig auth is removed on every market above. USDC-USDT DEX (id 2) borrow shares are denominated in `1e18` shares (~$2.20/share).

### Action 2: Hold USDai-USDC Market (DEX 47 + Vault 180)

DEX 47 is used only by the T2 vault 180, so both launch together in a later IGP. Team Multisig auth is retained on both; vault 180 gets borrow dust limits (`$7k / $9k`), and DEX 47 limits are left unchanged.

### Action 3: Deprecate Vault 174

Vault **174** (USDai / USDC, TYPE_1) is superseded by vault 180: limits restricted, user operations paused, Team Multisig auth removed.

### Action 4: Claim iETHv2 (Lite) stETH Revenue

Collect accrued Lite revenue via `IETHV2.collectRevenue` (stETH is deposited into the Fluid Reserve), then forward the Reserve's stETH balance minus a `0.1` stETH buffer to Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`) via `FLUID_RESERVE.withdrawFunds`. Amount is set by Team Multisig via `setLiteStethRevenueAmount()` (a zero amount reverts).

## Conclusion

IGP-134 raises the USDai ecosystem (DEXes 46 and 48, vaults 171–173 and 175–179) to launch limits, holds the USDai-USDC market (DEX 47 + vault 180) until its later launch, deprecates vault 174, and claims iETHv2 Lite stETH revenue.
