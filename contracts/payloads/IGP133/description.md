# Launch the USDai Ecosystem on Ethereum at Dust Limits

## Summary

This proposal brings the USDai ecosystem live on Ethereum at **dust limits**: it sets conservative supply / borrow limits and grants Team Multisig auth on the three USDai DEXes (**ids 46–48**) and the nine USDai / sUSDai vaults (**ids 171–179**). Every market is enabled but capped near zero so liquidity, oracles, and integrations can be validated on-chain before launch-scale limits are raised in a follow-up proposal.

**Tokens**: USDai (`0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF`), sUSDai (`0x0B2b2B2076d95dda7817e785989fE353fe955ef9`).

DEX ids 46–48 and vault ids 171–173 are already deployed (live on-chain); vault ids 174–179 are expected per the deployment plan. All ids in this payload are verified against the live Fluid `DEX_FACTORY.getDexAddress` / `VAULT_FACTORY.getVaultAddress`:

| DEX | Id | Address |
| --- | --- | --- |
| sUSDai / USDC | 46 | `0xA2E3A4e2A08b5714FA974Ce88466D736BD8b39d9` |
| USDai / USDC | 47 | `0x4653583Be64eB008d7F34cc6023A81C5033e6f70` |
| sUSDai / USDT | 48 | `0xb9b87A1B79891A8C9251F501B1b5d71bC7c8aA24` |

## Code Changes

### Action 1: USDai Ecosystem Dust Limits + Team Multisig Auth

Team Multisig auth is granted on all three DEXes and nine vaults so operators can adjust configuration during the dust phase.

| Market | Id | Type | Dust limits |
| --- | --- | --- | --- |
| sUSDai-USDC DEX | 46 | smart col | `$10k` base withdrawal per token |
| USDai-USDC DEX | 47 | smart col | `$10k` per token |
| sUSDai-USDT DEX | 48 | smart col | `$10k` per token |
| sUSDai / USDC | 171 | TYPE_1 | `$7k` / `$7k` / `$9k` withdraw / base borrow / max borrow |
| sUSDai / USDT | 172 | TYPE_1 | `$7k` / `$7k` / `$9k` |
| sUSDai / USDC-USDT | 173 | TYPE_3 | `$7k` supply; USDC-USDT DEX (id **2**) borrow shares `3500e18` / `4500e18` |
| USDai / USDC | 174 | TYPE_1 | `$7k` / `$7k` / `$9k` |
| sUSDai-USDC / USDC-USDT | 175 | TYPE_4 | USDC-USDT DEX borrow shares `3500e18` / `4500e18`; smart col at DEX **46** |
| sUSDai-USDT / USDC-USDT | 176 | TYPE_4 | USDC-USDT DEX borrow shares `3500e18` / `4500e18`; smart col at DEX **48** |
| sUSDai-USDT / USDT | 177 | TYPE_2 | USDT debt `$7k` / `$9k`; smart col at DEX **48** |
| sUSDai-USDC / USDC | 178 | TYPE_2 | USDC debt `$7k` / `$9k`; smart col at DEX **46** |
| sUSDai / GHO | 179 | TYPE_1 | `$7k` / `$7k` / `$9k` |

- **Smart-collateral DEXes (46–48)** get a `$10k` base withdrawal limit on each underlying token (50% expand / 1h) via `setDexLimits`.
- **TYPE_1 vaults (171, 172, 174, 179)** get `$7k` base withdrawal, `$7k` base borrow, and `$9k` max borrow at the Liquidity Layer (50% expand / 6h).
- **TYPE_3 vault (173)** gets a `$7k` smart-collateral supply limit and a `3500e18` / `4500e18` (~`$7k` / `$9k`) borrow-shares limit on the USDC-USDT DEX (id **2**).
- **TYPE_4 vaults (175, 176)** get only the `3500e18` / `4500e18` borrow-shares limit on the USDC-USDT DEX (id **2**); their collateral lives on DEXes 46 / 48.
- **TYPE_2 vaults (177, 178)** get `$7k` / `$9k` base / max debt ceilings on their borrow token (30% expand / 6h); their collateral lives on DEXes 48 / 46.

Vault auth is granted via the **VaultFactoryOwner** wrapper (`VAULT_FACTORY_WRAPPER_OWNER`, `0xB031913cB7AD81b8A4Ba412B471c2dA69BEA410B`), which owns `VAULT_FACTORY`; governance (the timelock) is authorized on the wrapper, not directly on the factory. DEX auth is set directly on `DEX_FACTORY`.

## Description

USDai is a `$1`-pegged stable and sUSDai is its yield-bearing variant. This proposal is the first step of the USDai launch on Fluid: it wires up the new DEXes and vaults with intentionally tiny limits so the markets are live for end-to-end verification (pricing, liquidations, routing, UI) without exposing the protocol to meaningful risk.

Because the Fluid admin modules reject literal-zero limits, the borrow-only sides of the smart-collateral DEXes are left at `0` (no smart debt configured), and every other ceiling is set to a small dust value. sUSDai is conservatively priced at `$1.00` for the dust-limit conversions; the exact valuation is irrelevant at this scale and will be revisited when launch limits are set.

Launch-scale limits (max shares, LR/UR, fees, and full vault risk parameters) are **not** included here and will follow in a subsequent proposal once the dust phase is validated.

## Conclusion

IGP-133 launches the USDai ecosystem on Ethereum at dust limits, enabling DEXes 46–48 and vaults 171–179 with minimal supply / borrow ceilings and Team Multisig auth, in preparation for a later launch-limits proposal.
