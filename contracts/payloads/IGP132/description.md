# Upgrade Liquidity Layer UserModule & AdminModule and Rotate Pause, Rates, and Range Auths

## Summary

This proposal implements protocol infrastructure updates across three areas: (1) upgrades the Liquidity Layer UserModule and AdminModule on the InfiniteProxy with rollback safety registrations, (2) rotates pause authorization on the Liquidity Layer and DexFactory to new operational contracts, and (3) rotates the Liquidity Layer rates auth and DexFactory range auth to new authorized operators. Together, these changes keep core Liquidity Layer logic current, maintain emergency pause capability, and ensure rate and range management remain under the correct authorized contracts.

All new implementation and auth addresses are configurable by Team Multisig before governance execution.

## Code Changes

### Action 1: Register UserModule Upgrade on RollbackModule

- **Old Implementation**: `0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7`
- **New Implementation**: Configurable via `setNewUserModuleAddress()` by Team Multisig
- **Purpose**: Register the current UserModule on the RollbackModule before upgrade so it can be restored within the rollback safety period if needed

### Action 2: Upgrade UserModule on Liquidity Layer

- **Old Implementation**: `0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7`
- **New Implementation**: Configurable via `setNewUserModuleAddress()` by Team Multisig
- **Purpose**: Replace the UserModule on the Liquidity Layer InfiniteProxy while preserving the existing set of function selectors

### Action 3: Register AdminModule Upgrade on RollbackModule

- **Old Implementation**: `0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`
- **New Implementation**: Configurable via `setNewAdminModuleAddress()` by Team Multisig
- **Purpose**: Register the current AdminModule on the RollbackModule before upgrade so it can be restored within the rollback safety period if needed

### Action 4: Upgrade AdminModule on Liquidity Layer

- **Old Implementation**: `0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`
- **New Implementation**: Configurable via `setNewAdminModuleAddress()` by Team Multisig
- **Purpose**: Replace the AdminModule on the Liquidity Layer InfiniteProxy while preserving the existing set of function selectors

### Action 5: Rotate Pause Auths on Liquidity Layer and DexFactory

- **Liquidity Layer Guardian**
  - **Old Auth**: `0xE9332F2d45e3216B7634cA4C7ab88945CD84ab76` (removed)
  - **New Auth**: Configurable via `setPauseAuths()` by Team Multisig
  - **Purpose**: Hand off Liquidity Layer emergency pause capability to the new guardian contract

- **DexFactory Pause Auth**
  - **Old Auth**: `0x735BA3772c2cCC0b92Ff6993bd71da88236C1495` (removed)
  - **New Auth**: Configurable via `setPauseAuths()` by Team Multisig
  - **Purpose**: Hand off DexFactory pause capability to the new global auth contract

### Action 6: Rotate Liquidity Layer Rates Auth

- **Old Auth**: `0x1e6B029284dc2779F8FfBD83a3a5aA00EdCE6ba4` (removed)
- **New Auth**: Configurable via `setNewRatesAuth()` by Team Multisig
- **Purpose**: Transfer Liquidity Layer rate management to the new authorized contract

### Action 7: Rotate DexFactory Range Auth

- **Old Auth**: `0x827089c01E9f761ff1A6D7041a9388bDdae74cc4` (removed)
- **New Auth**: Configurable via `setNewRangeAuth()` by Team Multisig
- **Purpose**: Transfer DexFactory range management to the new global auth contract

## Description

This proposal covers three areas of Liquidity Layer maintenance and operational auth management:

1. **Liquidity Layer Module Upgrades via RollbackModule**
   - Upgrades the UserModule and AdminModule on the Liquidity Layer InfiniteProxy to new implementations supplied by Team Multisig before execution
   - Registers both current implementations on the RollbackModule before replacement, enabling rollback within the safety period if issues are discovered post-deployment
   - Preserves the existing set of function selectors during each upgrade so downstream integrations remain compatible

2. **Pause Auth Rotations**
   - Replaces the Liquidity Layer guardian and DexFactory pause auth with new contracts supplied by Team Multisig
   - Disables the old pause operators and enables the new ones in the same governance action, maintaining continuous emergency pause capability across both the Liquidity Layer and DexFactory

3. **Rates and Range Auth Rotations**
   - Replaces the Liquidity Layer rates auth with a new authorized contract for managing borrow/supply rate updates
   - Replaces the DexFactory range auth with a new global auth contract for managing DEX trading range parameters
   - Each rotation disables the old auth and enables the new auth atomically, ensuring a clean handoff with no gap in authorized operators

### Configurable Addresses (Team Multisig sets before execution)

| Variable | Purpose |
|---|---|
| `newUserModuleAddress` | New UserModule implementation for the Liquidity Layer InfiniteProxy |
| `newAdminModuleAddress` | New AdminModule implementation for the Liquidity Layer InfiniteProxy |
| `liquidityPauseAuth` | New guardian on the Liquidity Layer |
| `dexPauseAuth` | New DexFactory global auth for pausing |
| `newRatesAuth` | New rates auth on the Liquidity Layer |
| `newRangeAuth` | New DexFactory global auth for range updates |

Each configurable group has a Team Multisig-only `lock…()` function to freeze its values before execution. Values must be set before the proposal executes; any action that depends on a configurable address reverts if that address is still unset.

## Conclusion

IGP-132 upgrades the Liquidity Layer UserModule and AdminModule with rollback safety registrations, and rotates pause, rates, and range authorization to new operational contracts on the Liquidity Layer and DexFactory. Module and auth addresses are supplied by Team Multisig before execution, giving the team flexibility to finalize implementations while keeping the on-chain upgrade path governed and auditable. These changes maintain core Liquidity Layer functionality, preserve emergency response capability, and keep rate and range management under the correct authorized operators.
