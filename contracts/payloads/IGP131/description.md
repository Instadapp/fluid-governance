# wstUSR Vault Maintenance, FLUID Rewards Funding, PST Launch Limits, and DSA Chief Cleanup

## Summary

This proposal implements protocol maintenance and market launch updates across four areas: (1) adjusts wstUSR vault limits and executes a reserve rebalance across active wstUSR vaults, (2) withdraws FLUID from the Treasury to Team Multisig to fund upcoming rewards, (3) scales the PST ecosystem from conservative dust limits to operational launch limits on DEX Pool 45 and vaults 165–169, and (4) removes InstaConnectorsV2 Chief auths except Team Multisig. Together, these changes support wstUSR market housekeeping, reward distribution funding, the public launch of PST protocols under governance-controlled caps, and a simplified DSA connector auth model with Team Multisig as the sole remaining Chief.

## Code Changes

### Action 1: Set Vault 142 wstUSR Withdrawal Limit

- **Vault ID 142**<br>
  **wstUSR / USDtb**:
  - **Base Withdrawal Limit**: `24 * 1e18` wstUSR raw units
  - **Expansion**: Max-restricted (`0.01%`, max duration)
  - **Purpose**: Set the wstUSR base withdrawal limit on vault 142 to the intended operational value

### Action 2: Rebalance wstUSR Vaults and Restore Borrow Restrictions

Temporarily raises borrow caps just enough to execute reserve rebalances, then restores max-restricted (paused) borrow limits. Timelock is granted the FLUID reserve rebalancer role for the duration of the rebalance and revoked at the end.

**Temporary borrow caps at Liquidity Layer** (2× dust snapshot, rounded up):

- **Vault 110** — wstUSR / USDC → USDC: `9 * 1e6`
- **Vault 111** — wstUSR / USDT → USDT: `7 * 1e6`
- **Vault 112** — wstUSR / GHO → GHO: `10 * 1e18`
- **Vault 133** — wstUSR-USDC <> USDC → USDC: `10 * 1e6`

**Reserve rebalance**:

- Rebalances vaults 110, 111, and 112 via `rebalanceVaults`
- Rebalances vault 133 via `rebalanceDexVaults`

**Restore paused borrow limits** on vaults 110, 111, 112, and 133 (Liquidity Layer).

### Action 3: Withdraw 750,000 FLUID from Treasury for Rewards

- **Token**: FLUID (`0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb`)
- **Withdrawal Amount**: `750_000 * 1e18` FLUID
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Treasury DSA via `BASIC-A` connector
- **Purpose**: Fund upcoming FLUID rewards distribution

### Action 4: Set Launch Limits for PST Ecosystem

Scales the five PST vaults and PST-USDC DEX from conservative dust limits to operational launch limits, and removes Team Multisig authorization once limits are in place.

- **Vault ID 165**<br>
  **PST / USDC (TYPE 1)**:
  - **Base Withdrawal Limit**: $8M
  - **Base Borrow Limit**: $5M
  - **Max Borrow Limit**: $10M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 166**<br>
  **PST / USDT (TYPE 1)**:
  - **Base Withdrawal Limit**: $8M
  - **Base Borrow Limit**: $5M
  - **Max Borrow Limit**: $10M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 167**<br>
  **PST-USDC / USDC (TYPE 2)**:
  - **Launch limits**: Not set in this proposal (may be added later if needed)
  - **Smart Collateral**: Limits at PST-USDC DEX (Pool 45) deferred with vault limits
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 168**<br>
  **PST / USDC-USDT (TYPE 3)**:
  - **Base Withdrawal Limit**: $8M
  - **Base Borrow Limit**: Set at DEX level (USDC-USDT DEX, Pool 2)
  - **DEX Borrow Limit**: ~2.5M shares ($5M) base, ~5M shares ($10M) max
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 169**<br>
  **PST-USDC / USDC-USDT (TYPE 4)**:
  - **Base Borrow Limit**: Set at DEX level (USDC-USDT DEX, Pool 2)
  - **DEX Borrow Limit**: ~2.5M shares ($5M) base, ~5M shares ($10M) max
  - **Smart Collateral**: Limits at PST-USDC DEX (Pool 45)
  - **Authorization**: Remove Team Multisig auth

- **DEX Pool 45**<br>
  **PST-USDC DEX**:
  - **Base Withdrawal Limit**: $5M per token (Liquidity Layer limits)
  - **Max Supply Shares**: $12M (Not set in this proposal)
  - **Smart Collateral**: Enabled
  - **Authorization**: Remove Team Multisig auth

### Action 5: Remove DSA Connector Chief Auths (Keep Team Multisig)

- **Contract**: InstaConnectorsV2 (`0x97b0B3A8bDeFE8cB9563a3c610019Ad10DB8aD11`)
- **Method**: `toggleChief(address)` on each chief to remove
- **Chiefs removed**:
  - `0xb3e586BCE929312e8B0685E2c12c1d6dbbcdc370`
  - `0xa6AEC494Aa19Dc910944E2374e9EA159dc919c59`
  - `0xCe40798c731Ce4F90EB239E4894D9c643eB1ddE7`
- **Chief retained**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Purpose**: Leave Team Multisig as the sole Chief on InstaConnectorsV2

## Description

This proposal covers four areas of protocol maintenance, treasury operations, and auth cleanup:

1. **wstUSR Vault Maintenance**
   - Sets vault 142 (wstUSR / USDtb) wstUSR base withdrawal limit to the intended operational value while keeping expansion settings max-restricted
   - Temporarily raises borrow caps on wstUSR vaults 110, 111, 112, and 133 to execute reserve rebalances, then restores max-restricted borrow limits
   - Timelock is granted the FLUID reserve rebalancer role for the duration of the rebalance and revoked at the end

2. **FLUID Rewards Funding**
   - Withdraws 750,000 FLUID from the Treasury DSA to Team Multisig via the `BASIC-A` connector
   - Supports upcoming FLUID rewards distribution without changing on-chain reward parameters in this payload

3. **PST Ecosystem Launch Limits**
   - Upgrades the five PST vaults (165–169) and PST-USDC DEX (Pool 45) from conservative dust limits to operational launch limits
   - T1 vaults (165–166): $8M base withdrawal, $5M base borrow, $10M max borrow
   - T2 vault (167): $5M base borrow, $10M max borrow; smart collateral limits at the PST-USDC DEX
   - T3 vault (168): $8M base withdrawal; smart-debt borrow at the USDC-USDT DEX (~$5M / ~$10M in shares)
   - T4 vault (169): smart-debt borrow at the USDC-USDT DEX (~$5M / ~$10M in shares)
   - PST-USDC DEX: $5M per-token Liquidity Layer withdrawal limits (max supply shares deferred until after DEX init)
   - Removes Team Multisig authorization from all five vaults and the PST-USDC DEX once launch limits are in place, enabling broader access under governance-controlled caps

4. **DSA Connector Chief Cleanup**
   - Calls `toggleChief` on InstaConnectorsV2 to remove Chief status from three addresses
   - Keeps Team Multisig as the sole remaining Chief on InstaConnectorsV2

## Conclusion

IGP-131 performs wstUSR vault housekeeping by setting vault 142's wstUSR withdrawal limit and executing a reserve rebalance on wstUSR vaults 110–112 and 133 before restoring max-restricted borrow limits, withdraws 750,000 FLUID from Treasury to Team Multisig for upcoming rewards, launches the PST ecosystem on DEX Pool 45 and vaults 165–169 with operational limits and Team Multisig auth removed, and removes InstaConnectorsV2 Chief auths except Team Multisig. These changes support ongoing wstUSR market maintenance, reward distribution funding, PST protocol launch under appropriate risk parameters, and simplified DSA connector governance with Team Multisig as the sole remaining Chief.
