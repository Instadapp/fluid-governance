# Set Timelock as VaultFactory Global Auth, Upgrade LL Admin Module, Update USDC/USDT Rate Curve, Update ETH Vault Params, Update sUSDe-USDT DEX Range, and Set rsETH Vault Borrow to Min Values

## Summary

This proposal introduces seven updates on Ethereum:

1. Sets the timelock as a global auth on VaultFactory via the VaultFactoryOwner wrapper (`0xB031913cB7AD81b8A4Ba412B471c2dA69BEA410B`).
2. Registers a rollback for the AdminModule upgrade on the RollbackModule.
3. Upgrades the AdminModule on the Liquidity Layer InfiniteProxy from `0x53EFFA0e612d88f39Ab32eb5274F2fae478d261C` to `0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`.
4. Updates the USDC and USDT V2 interest-rate curve kinks from `85%/93%` to `90%/95%`, while keeping the kink rates unchanged at `4.5%/7.5%`.
5. Updates CF, LT, and LML for ETH vaults (IDs 11, 12, 45, 54, 128) to `90%/93%/96%`, keeping LPs unchanged.
6. Updates the sUSDe-USDT DEX (ID: 15) range percents to upper `0.15%` and lower `0.4%`.
7. Sets rsETH vault borrow configs to minimum values for vaults `0x9A64E3EB9c2F917CBAdDe75Ad23bb402257acf2E` and `0x025C1494b7d15aa931E011f6740E0b46b2136cb9` (borrow token: wstETH).

## Code Changes

### Action 1: Set Timelock as Global Auth on VaultFactory

- Calls `IVaultFactoryOwner.setGlobalAuth()` on the VaultFactoryOwner wrapper (`0xB031913cB7AD81b8A4Ba412B471c2dA69BEA410B`) to add the timelock as a global auth on VaultFactory.

### Action 2: Register AdminModule LL Upgrade on RollbackModule

- Calls `IFluidLiquidityRollback.registerRollbackImplementation()` to register the old and new AdminModule addresses on the RollbackModule.
- Must execute before the actual upgrade so the RollbackModule can record the old implementation.

### Action 3: Upgrade AdminModule LL on InfiniteProxy

- Reads existing function selectors from the old AdminModule via `getImplementationSigs()`.
- Appends two new function selectors: `pauseTokens(address[])` and `unpauseTokens(address[])`.
- Removes the old AdminModule (`0x53EFFA0e612d88f39Ab32eb5274F2fae478d261C`) from the InfiniteProxy.
- Adds the new AdminModule (`0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`) with the combined function selectors.

### Action 4: Update USDC & USDT Rate-Curve

- Calls `LIQUIDITY.updateRateDataV2s()` for `USDC` and `USDT`.
- Changes:
  - `kink1`: `85% -> 90%`
  - `kink2`: `93% -> 95%`
- Keeps unchanged:
  - `rateAtUtilizationKink1 = 4.5%`
  - `rateAtUtilizationKink2 = 7.5%`
  - `rateAtUtilizationZero = 0%`
  - `rateAtUtilizationMax = 100%`

### Action 5: Update CF, LT, LML for ETH Vaults

- Updates vault IDs: 11, 12, 45, 54, 128.
- Sets `CF = 90%`, `LT = 93%`, `LML = 96%`.
- Liquidation Penalty (LP) is kept unchanged.
- Updates are applied in safe order: LML first, then LT, then CF.

### Action 6: Update sUSDe-USDT DEX Range Percents

- Calls `IFluidDex.updateRangePercents()` on DEX ID `15` (sUSDe-USDT).
- Sets upper range to `0.15%` and lower range to `0.4%`, with a `5 day` shift time.

### Action 7: Set rsETH Vault Borrow Configs to Min Values

- Calls `LIQUIDITY.updateUserBorrowConfigs()` for two rsETH vaults (`0x9A64E3EB9c2F917CBAdDe75Ad23bb402257acf2E`, `0x025C1494b7d15aa931E011f6740E0b46b2136cb9`).
- Borrow token: wstETH for both.
- Sets all borrow config parameters to minimum values: `mode=1`, `expandPercent=1`, `expandDuration=16777215`, `baseDebtCeiling=5`, `maxDebtCeiling=10`.

## Description

The first action sets the timelock as a global auth on VaultFactory through the VaultFactoryOwner wrapper contract, enabling governance to execute privileged VaultFactory operations.

The second action registers the upcoming AdminModule upgrade on the RollbackModule, enabling a rollback to the old implementation if needed.

The third action performs the actual module upgrade on the Liquidity Layer's InfiniteProxy by swapping the old AdminModule implementation for the new one, carrying over all existing function selectors and registering the two new selectors (`pauseTokens`, `unpauseTokens`).

The fourth action adjusts only the utilization breakpoints for USDC and USDT borrow curves to become more conservative near high utilization. By moving the kinks to `90%` and `95%` while preserving kink rates (`4.5%` and `7.5%`), the proposal changes where the slope transitions occur without modifying the target rates at those transition points.

The fifth action raises the collateral factor, liquidation threshold, and liquidation max limit for five ETH vaults (11, 12, 45, 54, 128) to `90%/93%/96%` respectively, while keeping liquidation penalties unchanged.

The sixth action updates the range percents for the sUSDe-USDT DEX (ID: 15), setting the upper range to `0.15%` and the lower range to `0.4%` with a `5 day` shift time.

The seventh action sets borrow configs to minimum values for two rsETH vaults on the Liquidity Layer, effectively minimizing their borrow capacity against wstETH.

## Conclusion

IGP128 sets the timelock as VaultFactory global auth, upgrades the Liquidity Layer AdminModule via InfiniteProxy (with rollback registration), updates Ethereum USDC/USDT curve kinks to `90%/95%` while preserving the existing kink rates (`4.5%/7.5%`), raises CF/LT/LML to `90%/93%/96%` for ETH vaults 11, 12, 45, 54, 128, updates sUSDe-USDT DEX (ID: 15) range to upper `0.15%` / lower `0.4%`, and sets rsETH vault borrow configs to minimum values.
