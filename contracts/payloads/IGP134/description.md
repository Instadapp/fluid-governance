# USDai Ecosystem Launch Limits and iETHv2 Revenue Claim

## Summary

This proposal performs two Ethereum actions:

1. Raise the **USDai ecosystem** from dust limits (IGP-133) to **launch limits** — bumping only the Liquidity Layer supply / borrow ceilings on the three USDai DEXes (ids **46–48**) and the nine USDai / sUSDai vaults (ids **171–179**).
2. Claim accrued **iETHv2 (Lite) stETH revenue** to Team Multisig.

Governance sets **limits only**. Per-market config (collateral factor, liquidation threshold / max-limit / penalty, DEX max supply shares, range, and fee) is set directly by **Team Multisig**, which already holds the vault / DEX auth granted in IGP-133.

## Code Changes

### Action 1: USDai Ecosystem Launch Limits

USDai (`0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF`), sUSDai (`0x0B2b2B2076d95dda7817e785989fE353fe955ef9`). DEX and vault ids are verified against the live Fluid `DEX_FACTORY` / `VAULT_FACTORY`.

#### DEX smart-collateral token limits (Liquidity Layer)

| DEX | Id | Per-token limit |
| --- | --- | --- |
| USDai-USDC | 47 | `$5M` |
| sUSDai-USDC | 46 | `$10M` |
| sUSDai-USDT | 48 | `$10M` |

#### Vault limits (Liquidity Layer)

| Vault | Id | Type | Base withdraw | Base borrow | Max borrow |
| --- | --- | --- | --- | --- | --- |
| USDai / USDC | 174 | TYPE_1 | `$8M` | `$5M` | `$10M` |
| sUSDai / USDC | 171 | TYPE_1 | `$8M` | `$8M` | `$15M` |
| sUSDai / USDT | 172 | TYPE_1 | `$8M` | `$8M` | `$15M` |
| sUSDai / GHO | 179 | TYPE_1 | `$8M` | `$8M` | `$15M` |
| sUSDai / USDC-USDT | 173 | TYPE_3 | `$8M` sUSDai supply | USDC-USDT DEX (id **2**) borrow shares `~$8M / ~$15M` | |
| sUSDai-USDC / USDC-USDT | 175 | TYPE_4 | smart col at DEX **46** | USDC-USDT DEX (id **2**) borrow shares `~$8M / ~$20M` | |
| sUSDai-USDT / USDC-USDT | 176 | TYPE_4 | smart col at DEX **48** | USDC-USDT DEX (id **2**) borrow shares `~$8M / ~$20M` | |
| sUSDai-USDT / USDT | 177 | TYPE_2 | smart col at DEX **48** | `$8M` USDT | `$20M` USDT |
| sUSDai-USDC / USDC | 178 | TYPE_2 | smart col at DEX **46** | `$8M` USDC | `$20M` USDC |

Smart-debt limits on the USDC-USDT DEX (id 2) are denominated in DEX shares, approximated as USD / 2 (~$2 per share, matching IGP-133): `~$8M` → `4_000_000 * 1e18`, `~$15M` → `7_500_000 * 1e18`, `~$20M` → `10_000_000 * 1e18` shares.

#### Market config — set by Team Multisig (not in this payload)

For reference, the launch config Team Multisig applies via its auth:

| Market | CF | LT | LML | LP | DEX max shares / range / fee |
| --- | --- | --- | --- | --- | --- |
| USDai-USDC DEX (47) | — | — | — | — | Max shares `$12M`; LR `0.2%` / UR `0.1%`; fee `2bps` |
| sUSDai-USDC DEX (46) | — | — | — | — | Max shares `$22M`; LR `0.4%` / UR `0.1%`; fee `2bps` |
| sUSDai-USDT DEX (48) | — | — | — | — | Max shares `$22M`; LR `0.4%` / UR `0.15%`; fee `2bps` |
| USDai / USDC (174) | `93%` | `94%` | `95%` | `2%` | — |
| sUSDai / USDC (171) | `88%` | `90%` | `95%` | `2%` | — |
| sUSDai / USDT (172) | `88%` | `90%` | `95%` | `2%` | — |
| sUSDai / GHO (179) | `88%` | `90%` | `95%` | `2%` | — |
| sUSDai / USDC-USDT (173) | `88%` | `90%` | `95%` | `2.5%` | — |
| sUSDai-USDC / USDC-USDT (175) | `88%` | `90%` | `95%` | `2.5%` | — |
| sUSDai-USDT / USDC-USDT (176) | `88%` | `90%` | `95%` | `2.5%` | — |
| sUSDai-USDT / USDT (177) | `88%` | `90%` | `95%` | `2.5%` | — |
| sUSDai-USDC / USDC (178) | `88%` | `90%` | `95%` | `2.5%` | — |

### Action 2: Claim iETHv2 (Lite) stETH Revenue

- **Lite contract**: iETHv2 (`0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78`)
- **Amount**: Configurable via `setLiteStethRevenueAmount()` by Team Multisig (stETH wei); a zero amount makes this action revert.
- **Step 1**: `IETHV2.collectRevenue(amount)` — pull accrued Lite revenue into the Treasury.
- **Step 2**: Treasury DSA `BASIC-A` `withdraw` — transfer stETH to Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`).

### Configurable Values (Team Multisig sets before execution)

| Variable | Purpose |
| --- | --- |
| `liteStethRevenueAmount` | stETH amount for the iETHv2 revenue claim (Action 2) |

## Conclusion

IGP-134 raises the USDai ecosystem (DEXes 46–48, vaults 171–179) from dust limits to launch-scale Liquidity Layer limits — leaving market config to Team Multisig — and claims accrued iETHv2 Lite stETH revenue to Team Multisig.
