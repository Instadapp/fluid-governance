# USDai Ecosystem Launch Limits, Vault 180 Dust, Vault 174 Deprecation, and iETHv2 Revenue Claim

## Summary

This proposal performs four Ethereum actions:

1. Raise the **USDai ecosystem** from dust limits (IGP-133) to **launch limits** — bumping the Liquidity Layer supply / borrow ceilings on the three USDai DEXes (ids **46–48**) and vaults **171–173** and **175–179**, and removing Team Multisig auth on each.
2. Give the new **vault 180** (USDai-USDC / USDC) **borrow-side dust limits only** and **explicitly retain** Team Multisig auth on it — it is not launched yet (launch ships in a later IGP).
3. **Deprecate** the wrongly deployed T1 vault **174** (USDai / USDC) with a full pause and remove its Team Multisig auth.
4. Claim accrued **iETHv2 (Lite) stETH revenue** to Team Multisig.

Governance sets **limits and auth only**. Per-market config (collateral factor, liquidation threshold / max-limit / penalty, DEX max supply shares, range, and fee) is set directly by **Team Multisig** on vault 180, the one market where it retains auth.

## Code Changes

### Action 1: USDai Ecosystem Launch Limits + Remove Team MS Auth

USDai (`0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF`), sUSDai (`0x0B2b2B2076d95dda7817e785989fE353fe955ef9`). DEX and vault ids are verified against the live Fluid `DEX_FACTORY` / `VAULT_FACTORY`.

#### DEX smart-collateral token limits (Liquidity Layer)

| DEX | Id | Per-token limit | Authorization |
| --- | --- | --- | --- |
| sUSDai-USDC | 46 | `$10M` | Remove Team Multisig auth |
| USDai-USDC | 47 | `$5M` | Remove Team Multisig auth |
| sUSDai-USDT | 48 | `$10M` | Remove Team Multisig auth |

#### Vault limits (Liquidity Layer)

| Vault | Id | Type | Base withdraw | Base borrow | Max borrow | Authorization |
| --- | --- | --- | --- | --- | --- | --- |
| sUSDai / USDC | 171 | TYPE_1 | `$8M` | `$8M` | `$15M` | Remove Team Multisig auth |
| sUSDai / USDT | 172 | TYPE_1 | `$8M` | `$8M` | `$15M` | Remove Team Multisig auth |
| sUSDai / GHO | 179 | TYPE_1 | `$8M` | `$8M` | `$15M` | Remove Team Multisig auth |
| sUSDai / USDC-USDT | 173 | TYPE_3 | `$8M` sUSDai supply | USDC-USDT DEX (id **2**) borrow shares `~$8M / ~$15M` (`3.6M / 6.75M` shares) | | Remove Team Multisig auth |
| sUSDai-USDC / USDC-USDT | 175 | TYPE_4 | smart col at DEX **46** | USDC-USDT DEX (id **2**) borrow shares `~$8M / ~$20M` (`3.6M / 9M` shares) | | Remove Team Multisig auth |
| sUSDai-USDT / USDC-USDT | 176 | TYPE_4 | smart col at DEX **48** | USDC-USDT DEX (id **2**) borrow shares `~$8M / ~$20M` (`3.6M / 9M` shares) | | Remove Team Multisig auth |
| sUSDai-USDT / USDT | 177 | TYPE_2 | smart col at DEX **48** | `$8M` USDT | `$20M` USDT | Remove Team Multisig auth |
| sUSDai-USDC / USDC | 178 | TYPE_2 | smart col at DEX **46** | `$8M` USDC | `$20M` USDC | Remove Team Multisig auth |

Vault **174** is intentionally excluded from launch limits; it is deprecated in Action 3. Vault **180** is handled separately in Action 2.

Smart-debt limits on the USDC-USDT DEX (id 2) are denominated in DEX shares (~$2.20/share atm): `~$8M` → `3_600_000 * 1e18`, `~$15M` → `6_750_000 * 1e18`, `~$20M` → `9_000_000 * 1e18` shares.

#### Market config — set by Team Multisig (not in this payload)

For reference, the launch config per market. Team Multisig retains auth only on **vault 180** (Action 2) and applies its config there; config for the auth-removed markets is applied before auth removal (or via governance):

| Market | CF | LT | LML | LP | DEX max shares / range / fee |
| --- | --- | --- | --- | --- | --- |
| USDai-USDC DEX (47) | — | — | — | — | Max shares `$12M`; LR `0.2%` / UR `0.1%`; fee `2bps` |
| sUSDai-USDC DEX (46) | — | — | — | — | Max shares `$22M`; LR `0.4%` / UR `0.1%`; fee `2bps` |
| sUSDai-USDT DEX (48) | — | — | — | — | Max shares `$22M`; LR `0.4%` / UR `0.15%`; fee `2bps` |
| USDai-USDC / USDC (180) | `88%` | `90%` | `95%` | `2.5%` | — |
| sUSDai / USDC (171) | `88%` | `90%` | `95%` | `2%` | — |
| sUSDai / USDT (172) | `88%` | `90%` | `95%` | `2%` | — |
| sUSDai / GHO (179) | `88%` | `90%` | `95%` | `2%` | — |
| sUSDai / USDC-USDT (173) | `88%` | `90%` | `95%` | `2.5%` | — |
| sUSDai-USDC / USDC-USDT (175) | `88%` | `90%` | `95%` | `2.5%` | — |
| sUSDai-USDT / USDC-USDT (176) | `88%` | `90%` | `95%` | `2.5%` | — |
| sUSDai-USDT / USDT (177) | `88%` | `90%` | `95%` | `2.5%` | — |
| sUSDai-USDC / USDC (178) | `88%` | `90%` | `95%` | `2.5%` | — |

### Action 2: Vault 180 (USDai-USDC / USDC) Dust Limits

Vault **180** (USDai-USDC / USDC, TYPE_2) is newly deployed and **not launched yet**. This action gives it **borrow-side dust limits only** and **explicitly retains** Team Multisig auth (sets auth = `true`) so the team can configure it ahead of its launch in a later IGP.

| Vault | Id | Type | Base withdraw | Base borrow | Max borrow | Authorization |
| --- | --- | --- | --- | --- | --- | --- |
| USDai-USDC / USDC | 180 | TYPE_2 | smart col at DEX **47** | `$7k` USDC (dust) | `$9k` USDC (dust) | **Retain** (set auth = true) |

No supply-side Liquidity Layer limits are set on vault 180.

### Action 3: Deprecate Wrongly Deployed Vault 174

- **Vault ID 174**<br>
  **USDai / USDC (TYPE 1)** — wrongly deployed; superseded by vault **180**:
  - Restrict supply and borrow limits (remove IGP-133 dust limits)
  - Pause user operations at Liquidity Layer
  - Remove Team Multisig authorization

### Action 4: Claim iETHv2 (Lite) stETH Revenue

- **Lite contract**: iETHv2 (`0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78`)
- **Amount**: Configurable via `setLiteStethRevenueAmount()` by Team Multisig (stETH wei); a zero amount makes this action revert.
- **Step 1**: `IETHV2.collectRevenue(amount)` — pull accrued Lite revenue into the Treasury.
- **Step 2**: Treasury DSA `BASIC-A` `withdraw` — transfer stETH to Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`).

### Configurable Values (Team Multisig sets before execution)

| Variable | Purpose |
| --- | --- |
| `liteStethRevenueAmount` | stETH amount for the iETHv2 revenue claim (Action 4) |

## Conclusion

IGP-134 raises the USDai ecosystem (DEXes 46–48, vaults 171–173 and 175–179) to launch-scale Liquidity Layer limits and removes Team Multisig auth on each, gives the new vault 180 (USDai-USDC / USDC) borrow-side dust limits while explicitly retaining Team Multisig auth on it, deprecates the wrongly deployed vault 174, and claims accrued iETHv2 Lite stETH revenue to Team Multisig.
