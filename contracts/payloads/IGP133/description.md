# Launch the USDai Ecosystem on Ethereum at Dust Limits

## Summary

This proposal launches the USDai ecosystem on Ethereum at **dust limits**: it sets conservative supply / borrow limits and grants Team Multisig auth on the three USDai DEXes (ids **46–48**) and the nine USDai / sUSDai vaults (ids **171–179**). Every market is enabled but capped near zero so liquidity, oracles, and integrations can be validated on-chain before launch-scale limits ship in a follow-up proposal.

## Code Changes

### Action 1: USDai Ecosystem Dust Limits + Team Multisig Auth

USDai (`0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF`), sUSDai (`0x0B2b2B2076d95dda7817e785989fE353fe955ef9`). DEX and vault ids are verified against the live Fluid `DEX_FACTORY` / `VAULT_FACTORY`.

Vault auth is set via **VaultFactoryOwner** (`VAULT_FACTORY_WRAPPER_OWNER`, `0xB031913cB7AD81b8A4Ba412B471c2dA69BEA410B`). DEX auth via `DEX_FACTORY`.

| Market | Id | Type | Limits |
| --- | --- | --- | --- |
| sUSDai-USDC DEX | 46 | smart col | `$10k` base withdrawal per token; smart debt off |
| USDai-USDC DEX | 47 | smart col | `$10k` per token; smart debt off |
| sUSDai-USDT DEX | 48 | smart col | `$10k` per token; smart debt off |
| sUSDai / USDC | 171 | TYPE_1 | `$7k / $7k / $9k` withdraw / base borrow / max borrow |
| sUSDai / USDT | 172 | TYPE_1 | `$7k / $7k / $9k` |
| sUSDai / USDC-USDT | 173 | TYPE_3 | `$7k` supply; USDC-USDT DEX (id **2**) borrow shares `3500e18 / 4500e18` |
| USDai / USDC | 174 | TYPE_1 | `$7k / $7k / $9k` |
| sUSDai-USDC / USDC-USDT | 175 | TYPE_4 | USDC-USDT DEX (id **2**) borrow shares `3500e18 / 4500e18`; smart col at DEX **46** |
| sUSDai-USDT / USDC-USDT | 176 | TYPE_4 | USDC-USDT DEX (id **2**) borrow shares `3500e18 / 4500e18`; smart col at DEX **48** |
| sUSDai-USDT / USDT | 177 | TYPE_2 | USDT debt `$7k / $9k`; smart col at DEX **48** |
| sUSDai-USDC / USDC | 178 | TYPE_2 | USDC debt `$7k / $9k`; smart col at DEX **46** |
| sUSDai / GHO | 179 | TYPE_1 | `$7k / $7k / $9k` |

All three DEXes and nine vaults grant Team Multisig auth.

## Description

USDai is a `$1`-pegged stable and sUSDai its yield-bearing variant. This is the first step of the USDai launch on Fluid: it wires up the new DEXes and vaults with intentionally tiny limits so the markets are live for end-to-end verification (pricing, liquidations, routing, UI) without meaningful risk. Because the Fluid admin modules reject literal-zero limits, the smart-debt sides are left off and every other ceiling is set to a small dust value; sUSDai is conservatively priced at `$1.00` for the conversions. Launch-scale limits (max shares, LR/UR, fees, full risk parameters) are **not** included here and follow in a later proposal once the dust phase is validated.

## Conclusion

IGP-133 launches the USDai ecosystem on Ethereum at dust limits, enabling DEXes 46–48 and vaults 171–179 with minimal supply / borrow ceilings and Team Multisig auth, ahead of a later launch-limits proposal.
