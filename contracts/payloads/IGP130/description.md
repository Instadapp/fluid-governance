# Liquidity Layer UserModule & AdminModule Upgrades, Pause/Rates/Range Auth Rotations, wstUSR Vault Rebalance Prep, FLUID Rewards Funding, and Auth Cleanups

## Summary

This proposal introduces thirteen updates on Ethereum:

1. Registers the new UserModule rollback on the RollbackModule against the current UserModule (`0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7`).
2. Upgrades the UserModule on the Liquidity Layer InfiniteProxy, preserving the existing set of function selectors.
3. Registers the new AdminModule rollback on the RollbackModule against the current AdminModule (`0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`).
4. Upgrades the AdminModule on the Liquidity Layer InfiniteProxy, preserving the existing set of function selectors.
5. Rotates pause auths: removes the old Liquidity guardian (`0xE9332F2d45e3216B7634cA4C7ab88945CD84ab76`) and the old DexFactory pause auth (`0x735BA3772c2cCC0b92Ff6993bd71da88236C1495`), and registers the new Liquidity guardian and the new DexFactory pause auth.
6. Rotates the Liquidity Layer rates auth from `0x1e6B029284dc2779F8FfBD83a3a5aA00EdCE6ba4` to the new rates auth.
7. Rotates the DexFactory range auth from `0x827089c01E9f761ff1A6D7041a9388bDdae74cc4` to the new range auth.
8. Sets vault 142 (wstUSR / USDtb) wstUSR base withdrawal limit to `24 * 1e18` raw units while keeping expansion settings max-restricted (`0.01%`, max duration).
9. Prepares and executes a wstUSR vault rebalance across vaults 110, 111, 112, 133, 134, and 135, then restores max-restricted (paused) borrow limits.
10. Withdraws `750_000 * 1e18` FLUID from Treasury (BASIC-A) to Team Multisig to fund FLUID rewards.
11. Reserves a placeholder action for PST-related protocol dust limits (no-op in this draft).
12. Reserves a placeholder action to remove DSA connector Chief auths on mainnet and keep only the main multisig auth (no-op in this draft).
13. Reserves a placeholder action to remove the multisig auth from Lite (no-op in this draft).

All new implementation and auth addresses (`newUserModuleAddress`, `newAdminModuleAddress`, `liquidityPauseAuth`, `dexPauseAuth`, `newRatesAuth`, `newRangeAuth`) are configurable by Team Multisig before governance execution.

## Code Changes

### Action 1: Register UserModule LL Upgrade on RollbackModule

- Calls `IFluidLiquidityRollback.registerRollbackImplementation(OLD_USER_MODULE, newUserModuleAddress)` on the Liquidity Layer.
- Captures the current UserModule (`0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7`) for rollback safety before the upgrade.
- Requires `newUserModuleAddress` to be set by Team Multisig before execution.

### Action 2: Upgrade UserModule LL on InfiniteProxy

- Reads existing function selectors from the old UserModule via `IInfiniteProxy.getImplementationSigs()`.
- Removes the old UserModule (`0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7`) from the Liquidity Layer InfiniteProxy.
- Adds the new UserModule (`newUserModuleAddress`) with exactly the same set of selectors.
- Requires `newUserModuleAddress` to be set by Team Multisig before execution.

### Action 3: Register AdminModule LL Upgrade on RollbackModule

- Calls `IFluidLiquidityRollback.registerRollbackImplementation(OLD_ADMIN_MODULE, newAdminModuleAddress)` on the Liquidity Layer.
- Captures the current AdminModule (`0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`) for rollback safety before the upgrade.
- Requires `newAdminModuleAddress` to be set by Team Multisig before execution.

### Action 4: Upgrade AdminModule LL on InfiniteProxy

- Reads existing function selectors from the old AdminModule via `IInfiniteProxy.getImplementationSigs()`.
- Removes the old AdminModule (`0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`) from the Liquidity Layer InfiniteProxy.
- Adds the new AdminModule (`newAdminModuleAddress`) with exactly the same set of selectors.
- Requires `newAdminModuleAddress` to be set by Team Multisig before execution.

### Action 5: Rotate Pause Auths on Liquidity Layer and DexFactory

- Calls `LIQUIDITY.updateGuardians()` with two entries: `OLD_LIQUIDITY_PAUSE_AUTH → false`, `liquidityPauseAuth → true`.
- Calls `DEX_FACTORY.setGlobalAuth(OLD_DEX_PAUSE_AUTH, false)` and `DEX_FACTORY.setGlobalAuth(dexPauseAuth, true)`.
- Old auths (hardcoded): `0xE9332F2d45e3216B7634cA4C7ab88945CD84ab76` (Liquidity), `0x735BA3772c2cCC0b92Ff6993bd71da88236C1495` (Dex).
- Requires `liquidityPauseAuth` and `dexPauseAuth` to be set by Team Multisig before execution.

### Action 6: Rotate Liquidity Layer Rates Auth

- Calls `LIQUIDITY.updateAuths()` with two entries: `OLD_RATES_AUTH → false`, `newRatesAuth → true`.
- Old auth (hardcoded): `0x1e6B029284dc2779F8FfBD83a3a5aA00EdCE6ba4`.
- Requires `newRatesAuth` to be set by Team Multisig before execution.

### Action 7: Rotate DexFactory Range Auth

- Calls `DEX_FACTORY.setGlobalAuth(OLD_RANGE_AUTH, false)` and `DEX_FACTORY.setGlobalAuth(newRangeAuth, true)`.
- Old auth (hardcoded): `0x827089c01E9f761ff1A6D7041a9388bDdae74cc4`.
- Requires `newRangeAuth` to be set by Team Multisig before execution.

### Action 8: Set Vault 142 wstUSR Withdrawal Limit

- Calls `LIQUIDITY.updateUserSupplyConfigs()` for vault 142 (wstUSR / USDtb) on the wstUSR token.
- Config: `mode = 1`, `expandPercent = 1` (0.01%), `expandDuration = 16777215` (max), `baseWithdrawalLimit = 24 * 1e18`.

### Action 9: Rebalance wstUSR Vaults and Restore Borrow Restrictions

Temporarily raises borrow caps just enough to execute reserve rebalances on six wstUSR vaults, then restores max-restricted (paused) borrow limits. Expansion settings stay max-restricted (`expandPercent = 1` / 0.01%, `expandDuration = 16777215`) throughout. `baseDebtCeiling` and `maxDebtCeiling` are set equal in the temporary raises so the vaults can only rebalance the buffered dust and nothing more.

**Temporary borrow caps at Liquidity Layer** (via `LIQUIDITY.updateUserBorrowConfigs()`):
- Vault 110 — wstUSR / USDC → USDC, `4 * 1e6`
- Vault 111 — wstUSR / USDT → USDT, `3 * 1e6`
- Vault 112 — wstUSR / GHO  → GHO,  `0.25 * 1e18`
- Vault 133 — wstUSR-USDC <> USDC → USDC, `0.7 * 1e6`

**Temporary borrow caps at DEX level** (via `IFluidDex.updateUserBorrowConfigs()`):
- Vault 134 — wstUSR-USDC <> USDC-USDT on USDC-USDT DEX (Pool 2), `0.35 * 1e18`
- Vault 135 — wstUSR-USDC <> USDC-USDT concentrated on USDC-USDT concentrated DEX (Pool 34), `0.03 * 1e18`

**Reserve rebalance**:
- `FLUID_RESERVE.updateRebalancer(TIMELOCK, true)` grants Timelock the rebalancer role.
- `FLUID_RESERVE.rebalanceVaults([110, 111, 112], [0, 0, 0])`.
- `FLUID_RESERVE.rebalanceDexVaults([133, 134, 135], values_, colToken0MinMaxs_, colToken1MinMaxs_, debtToken0MinMaxs_, debtToken1MinMaxs_)` with `values_ = [0, 0, 0]`, `colToken0MinMaxs_ = colToken1MinMaxs_ = [0, 0, 0]` (collateral side unused), and per-vault smart-debt min/max:
  - Vault 133: `debtToken0MinMax = debtToken1MinMax = 0` (direct-borrow T2 vault, smart-debt min/max unused)
  - Vault 134: `debtToken0MinMax = 0.4 * 1e6` USDC, `debtToken1MinMax = 0.4 * 1e6` USDT
  - Vault 135: `debtToken0MinMax = 0.04 * 1e6` USDC, `debtToken1MinMax = 0.03 * 1e6` USDT
- `FLUID_RESERVE.updateRebalancer(TIMELOCK, false)` revokes the rebalancer role.

**Restore paused borrow limits**:
- At Liquidity Layer (via `setBorrowProtocolLimitsPaused()`): vaults 110 (USDC), 111 (USDT), 112 (GHO), 133 (USDC).
- At DEX level (via `setBorrowProtocolLimitsPausedDex()`): vaults 134 and 135 on their respective DEXes.
- Paused values: `mode = 1`, `expandPercent = 1` (0.01%), `expandDuration = 16777215` (max), `baseDebtCeiling = 10`, `maxDebtCeiling = 20`.

> Skipped: vaults 142, 143, and 144 — intentionally excluded from this rebalance. No wstUSR revenue collection is included because no wstUSR revenue is expected.

### Action 10: Withdraw 750,000 FLUID from Treasury for Rewards

- Casts the Treasury DSA with the `BASIC-A` connector and `withdraw(FLUID, 750_000 * 1e18, TEAM_MULTISIG, 0, 0)` to fund upcoming FLUID rewards.

### Action 11: PST-Related Protocol Dust Limits (Placeholder)

- No-op in this draft. To be filled in with PST-related protocol dust limit updates before finalizing IGP-130.

### Action 12: Remove DSA Connector Chief Auths (Placeholder)

- No-op in this draft. To be filled in to remove all DSA connector Chief auths on mainnet, keeping only the main multisig auth.

### Action 13: Remove Multisig Auth from Lite (Placeholder)

- No-op in this draft. To be filled in to remove the multisig auth from Lite.

## Description

This proposal covers four areas of protocol maintenance and infrastructure upgrades:

1. **Liquidity Layer Module Upgrades via RollbackModule**
   - Upgrades the UserModule and the AdminModule on the Liquidity Layer's InfiniteProxy to new implementations supplied by Team Multisig before execution. Both upgrades follow the same pattern: register the new implementation against the current one on the RollbackModule, then swap the implementation on the InfiniteProxy while carrying over the exact set of function selectors.
   - The pre-upgrade registration on the RollbackModule enables a rollback to the current implementation within the safety period if issues are discovered.

2. **Pause / Rates / Range Auth Rotations**
   - Replaces the existing Liquidity Layer guardian and DexFactory pause auth with new contracts supplied by Team Multisig, by disabling the old pair and enabling the new pair atomically.
   - Replaces the Liquidity Layer rates auth and the DexFactory range auth with new contracts supplied by Team Multisig, again disabling the old auth and enabling the new auth atomically.

3. **wstUSR Maintenance**
   - Sets vault 142 (wstUSR / USDtb) wstUSR base withdrawal limit to exactly `24 * 1e18` raw units while keeping expansion settings max-restricted.
   - Temporarily raises borrow caps on the active wstUSR vaults (110, 111, 112, 133 at Liquidity Layer; 134, 135 at DEX level) just enough to execute reserve rebalances, then restores max-restricted (paused) borrow limits. Timelock is granted the FLUID reserve rebalancer role for the duration of the rebalance and revoked at the end.
   - Vaults 142, 143, and 144 are intentionally excluded from the rebalance.

4. **FLUID Rewards Funding and Auth Cleanups**
   - Withdraws `750_000 * 1e18` FLUID from the Treasury DSA to Team Multisig via the `BASIC-A` connector to fund upcoming FLUID rewards.
   - Reserves three placeholder actions (PST-related protocol dust limits, removal of DSA connector Chief auths on mainnet, removal of the multisig auth from Lite) that are no-ops in this draft and will be filled in before finalizing IGP-130.

### Configurable Addresses (Team Multisig sets before execution)

| Variable | Purpose |
|---|---|
| `newUserModuleAddress` | New UserModule implementation for the Liquidity Layer InfiniteProxy |
| `newAdminModuleAddress` | New AdminModule implementation for the Liquidity Layer InfiniteProxy |
| `liquidityPauseAuth` | New guardian on the Liquidity Layer (replaces the old pause auth) |
| `dexPauseAuth` | New DexFactory global auth for pausing (replaces the old pause auth) |
| `newRatesAuth` | New rates auth on the Liquidity Layer (replaces the old rates auth) |
| `newRangeAuth` | New DexFactory global auth for range updates (replaces the old range auth) |

Each configurable group has a Team Multisig-only `lock…()` function to freeze its values before execution; calling the matching `set…()` after locking reverts with `locked`. Each action that consumes a configurable address also reverts on execution if the value is left at `address(0)`.

## Conclusion

IGP-130 upgrades the Liquidity Layer UserModule and AdminModule via the InfiniteProxy with pre-upgrade rollback registrations, rotates the Liquidity Layer guardian, rates auth, and the DexFactory pause and range auths, sets vault 142 wstUSR base withdrawal limit to `24 * 1e18`, executes a buffered reserve rebalance across wstUSR vaults 110, 111, 112, 133, 134, and 135 before restoring max-restricted borrow limits, withdraws `750_000` FLUID from Treasury to Team Multisig for upcoming rewards, and reserves three placeholder actions for PST dust limits, DSA connector Chief auth cleanup, and Lite multisig auth cleanup that will be filled in before submission.
