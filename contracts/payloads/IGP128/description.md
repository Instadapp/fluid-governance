# Set Timelock as VaultFactory Global Auth, Upgrade LL Admin Module, Update USDC/USDT Rate Curve, Update ETH Vault Params, Update sUSDe-USDT DEX Range, Set rsETH Vault Borrow to Min Values, and Cap ETH Max-Util Borrow Rate at 10%

## Summary

This proposal introduces eight updates on Ethereum:

1. Sets the timelock as a global auth on VaultFactory via the VaultFactoryOwner wrapper (`0xB031913cB7AD81b8A4Ba412B471c2dA69BEA410B`).
2. Registers a rollback for the AdminModule upgrade on the RollbackModule.
3. Upgrades the AdminModule on the Liquidity Layer InfiniteProxy from `0x53EFFA0e612d88f39Ab32eb5274F2fae478d261C` to `0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`.
4. Updates the USDC and USDT V2 interest-rate curve kinks from `85%/93%` to `90%/95%`, while keeping the kink rates unchanged at `4.5%/7.5%`.
5. Updates CF, LT, and LML for ETH vaults (IDs 11, 12, 45, 54, 128) to `90%/93%/96%`, keeping LPs unchanged.
6. Updates the sUSDe-USDT DEX (ID: 15) range percents to upper `0.15%` and lower `0.4%`.
7. Sets rsETH vault (IDs 78, 79) borrow protocol limits to paused/minimum values (borrow token: wstETH).
8. Caps the ETH borrow rate at max utilization to `10%` (from `100%`), keeping all other rate model v2 params unchanged.

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

### Action 7: Set rsETH Vault Borrow Limits to Paused

- Calls `setBorrowProtocolLimitsPaused()` for rsETH vaults (IDs 78, 79) with borrow token wstETH.
- Sets borrow config to minimum/paused values: `mode=1`, `expandPercent=1` (0.01%), `expandDuration=16777215` (max), `baseDebtCeiling=10`, `maxDebtCeiling=20`.

### Action 8: Cap ETH Borrow Rate at Max Utilization to 10%

- Calls `LIQUIDITY.updateRateDataV2s()` for `ETH`.
- Changes:
  - `rateAtUtilizationMax`: `100% -> 10%`
- Keeps unchanged (matching current on-chain values):
  - `kink1 = 88%`
  - `kink2 = 93%`
  - `rateAtUtilizationZero = 0%`
  - `rateAtUtilizationKink1 = 2.5%`
  - `rateAtUtilizationKink2 = 4%`

## Description

The first action sets the timelock as a global auth on VaultFactory through the VaultFactoryOwner wrapper contract, enabling governance to execute privileged VaultFactory operations.

The second action registers the upcoming AdminModule upgrade on the RollbackModule, enabling a rollback to the old implementation if needed.

The third action performs the actual module upgrade on the Liquidity Layer's InfiniteProxy by swapping the old AdminModule implementation for the new one, carrying over all existing function selectors and registering the two new selectors (`pauseTokens`, `unpauseTokens`).

The fourth action adjusts only the utilization breakpoints for USDC and USDT borrow curves to become more conservative near high utilization. By moving the kinks to `90%` and `95%` while preserving kink rates (`4.5%` and `7.5%`), the proposal changes where the slope transitions occur without modifying the target rates at those transition points.

The fifth action raises the collateral factor, liquidation threshold, and liquidation max limit for five ETH vaults (11, 12, 45, 54, 128) to `90%/93%/96%` respectively, while keeping liquidation penalties unchanged.

The sixth action updates the range percents for the sUSDe-USDT DEX (ID: 15), setting the upper range to `0.15%` and the lower range to `0.4%` with a `5 day` shift time.

The seventh action sets borrow protocol limits to paused/minimum values for two rsETH vaults (IDs 78, 79) on the Liquidity Layer, effectively minimizing their borrow capacity against wstETH.

The eighth action caps the ETH borrow rate at maximum utilization to `10%` (down from `100%`), while preserving all other rate model v2 parameters at their current on-chain values (`kink1=88%`, `kink2=93%`, `rateAtKink1=2.5%`, `rateAtKink2=4%`).

## Conclusion

IGP128 sets the timelock as VaultFactory global auth, upgrades the Liquidity Layer AdminModule via InfiniteProxy (with rollback registration), updates Ethereum USDC/USDT curve kinks to `90%/95%` while preserving the existing kink rates (`4.5%/7.5%`), raises CF/LT/LML to `90%/93%/96%` for ETH vaults 11, 12, 45, 54, 128, updates sUSDe-USDT DEX (ID: 15) range to upper `0.15%` / lower `0.4%`, sets rsETH vault (IDs 78, 79) borrow limits to paused, and caps the ETH max-utilization borrow rate at `10%`.
