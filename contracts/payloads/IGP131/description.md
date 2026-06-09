# wstUSR Vault Maintenance, FLUID Rewards Funding, PST Launch Limits, and DSA Chief Cleanup

## Summary

This proposal performs five actions on mainnet: (1) sets vault 142 (wstUSR / USDtb) wstUSR base withdrawal limit to **24** raw units; (2) temporarily raises borrow caps on wstUSR vaults **110**, **111**, **112**, and **133**, runs reserve rebalances on those vaults, then restores max-restricted (paused) borrow limits; (3) withdraws **750,000 FLUID** from Treasury to Team Multisig for upcoming rewards; (4) sets launch limits on PST TYPE_1 vaults **165–166**, TYPE_3 vault **168**, and PST-USDC DEX **45**, sets USDC-USDT DEX borrow limits for TYPE_3/TYPE_4 vaults **168–169**, removes Team Multisig vault/DEX auth across all five PST vaults and DEX 45 (vault **167** auth-only, no limit changes); (5) removes InstaConnectorsV2 Chief status from three addresses and leaves Team Multisig as the sole remaining Chief.

## Code Changes

### Action 1: Set Vault 142 wstUSR Withdrawal Limit

- **Vault ID 142**<br>
  **wstUSR / USDtb**:
  - **Token**: wstUSR
  - **Base Withdrawal Limit**: `24 * 1e18` raw units
  - **Expansion**: Max-restricted (`0.01%`, max duration)

### Action 2: Rebalance wstUSR Vaults and Restore Borrow Restrictions

Temporarily raises Liquidity Layer borrow caps (2× prior dust snapshot, rounded up to whole-token amounts), grants Timelock the FLUID reserve rebalancer role, executes rebalances, then restores max-restricted (paused) borrow limits and revokes the rebalancer role.

**Temporary borrow caps at Liquidity Layer**:

| Vault | Market | Token | Ceiling |
| --- | --- | --- | --- |
| 110 | wstUSR / USDC | USDC | `9 * 1e6` |
| 111 | wstUSR / USDT | USDT | `7 * 1e6` |
| 112 | wstUSR / GHO | GHO | `10 * 1e18` |
| 133 | wstUSR-USDC <> USDC | USDC | `10 * 1e6` |

**Reserve rebalance**:

- Vaults **110**, **111**, **112** via `rebalanceVaults`
- Vault **133** via `rebalanceDexVaults` (vaults **134** and **135** are not rebalanced — borrow below minimum)

**Restore paused borrow limits** on vaults 110, 111, 112, and 133.

### Action 3: Withdraw 750,000 FLUID from Treasury for Rewards

- **Token**: FLUID (`0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb`)
- **Amount**: `750_000 * 1e18`
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Treasury DSA `cast` with `BASIC-A` `withdraw`

### Action 4: PST Ecosystem Launch Limits and Auth Removal

Vault auth via **VaultFactoryOwner** (`FLUID_VAULT_FACTORY_OWNER`). DEX auth via `DEX_FACTORY`. PST token deployed at `PST_ADDRESS`.

| Market | Id | Type | Limits in this payload | Team MS auth |
| --- | --- | --- | --- | --- |
| PST / USDC | 165 | TYPE_1 | `$8M` withdraw / `$5M` base borrow / `$10M` max borrow | removed |
| PST / USDT | 166 | TYPE_1 | `$8M` / `$5M` / `$10M` | removed |
| PST-USDC / USDC | 167 | TYPE_2 | none (follow-up if needed) | removed |
| PST / USDC-USDT | 168 | TYPE_3 | `$8M` PST withdraw; USDC-USDT DEX (id **2**) borrow shares `2.5M / 5M * 1e18` (~$5M / ~$10M), 30% expand, 6h | removed |
| PST-USDC / USDC-USDT | 169 | TYPE_4 | USDC-USDT DEX (id **2**) borrow shares `2.5M / 5M * 1e18` (~$5M / ~$10M), 30% expand, 6h | removed |
| PST-USDC DEX | **45** | smart col | `$5M` base withdrawal per token; smart debt off; borrow limits not set | removed |

DEX 45 does not call `updateMaxSupplyShares` in this payload.

### Action 5: Remove DSA Connector Chief Auths (Keep Team Multisig)

- **Contract**: InstaConnectorsV2 (`0x97b0B3A8bDeFE8cB9563a3c610019Ad10DB8aD11`)
- **Method**: `toggleChief(address)` per address below
- **Removed**:
  - `0xb3e586BCE929312e8B0685E2c12c1d6dbbcdc370`
  - `0xa6AEC494Aa19Dc910944E2374e9EA159dc919c59`
  - `0xCe40798c731Ce4F90EB239E4894D9c643eB1ddE7`
- **Retained**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)

## Description

**Action 1** sets the wstUSR base withdrawal limit on vault 142 (wstUSR / USDtb) to 24 raw units with max-restricted expansion.

**Action 2** runs wstUSR reserve housekeeping on vaults 110, 111, 112, and 133: temporary borrow headroom at the Liquidity Layer, Timelock as reserve rebalancer, `rebalanceVaults` / `rebalanceDexVaults`, then paused borrow limits restored. Vaults 134 and 135 are skipped.

**Action 3** withdraws 750,000 FLUID from the Treasury DSA to Team Multisig via `BASIC-A` for upcoming rewards distribution.

**Action 4** moves the PST ecosystem toward launch scale: full TYPE_1 limits on vaults 165–166, TYPE_3 supply limit plus USDC-USDT DEX borrow shares on vault 168, USDC-USDT DEX borrow shares only on vault 169, PST-USDC DEX 45 withdrawal limits at $5M per token, and Team Multisig auth removed on all five vaults and DEX 45. Vault 167 (TYPE_2) only drops Team Multisig auth — liquidity and smart-collateral limits are left for a follow-up if needed.

**Action 5** removes Chief status from three InstaConnectorsV2 addresses; Team Multisig remains the sole Chief.

## Conclusion

IGP-131 (1) sets vault 142 wstUSR withdrawal limit, (2) rebalances wstUSR vaults 110–112 and 133 and restores paused borrows, (3) funds rewards with a 750,000 FLUID Treasury withdrawal to Team Multisig, (4) applies PST launch limits where configured (165–166, 168, DEX 45), DEX borrow limits on 168–169, auth removal on all PST vaults and DEX 45 with vault 167 limits deferred, and (5) trims InstaConnectorsV2 Chiefs to Team Multisig only.
