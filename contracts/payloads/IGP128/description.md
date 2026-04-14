# Upgrade LL Admin Module and Update USDC/USDT Rate Curve Kinks

## Summary

This proposal introduces three updates on the Ethereum Liquidity Layer:

1. Registers a rollback for the AdminModule upgrade on the RollbackModule.
2. Upgrades the AdminModule on the Liquidity Layer InfiniteProxy from `0x53EFFA0e612d88f39Ab32eb5274F2fae478d261C` to `0xea78faBC13D603895FE9efe8BB4A4f2c56e5698E`.
3. Updates the USDC and USDT V2 interest-rate curve kinks from `85%/93%` to `90%/95%`, while keeping the kink rates unchanged at `4.5%/7.5%`.

## Code Changes

### Action 1: Register AdminModule LL Upgrade on RollbackModule

- Calls `IFluidLiquidityRollback.registerRollbackImplementation()` to register the old and new AdminModule addresses on the RollbackModule.
- Must execute before the actual upgrade so the RollbackModule can record the old implementation.

### Action 2: Upgrade AdminModule LL on InfiniteProxy

- Reads existing function selectors from the old AdminModule via `getImplementationSigs()`.
- Removes the old AdminModule (`0x53EFFA0e612d88f39Ab32eb5274F2fae478d261C`) from the InfiniteProxy.
- Adds the new AdminModule (`0xea78faBC13D603895FE9efe8BB4A4f2c56e5698E`) with the same function selectors.

### Action 3: Update USDC & USDT Rate-Curve

- Calls `LIQUIDITY.updateRateDataV2s()` for `USDC` and `USDT`.
- Changes:
  - `kink1`: `85% -> 90%`
  - `kink2`: `93% -> 95%`
- Keeps unchanged:
  - `rateAtUtilizationKink1 = 4.5%`
  - `rateAtUtilizationKink2 = 7.5%`
  - `rateAtUtilizationZero = 0%`
  - `rateAtUtilizationMax = 100%`

## Description

The first action registers the upcoming AdminModule upgrade on the RollbackModule, enabling a rollback to the old implementation if needed.

The second action performs the actual module upgrade on the Liquidity Layer's InfiniteProxy by swapping the old AdminModule implementation for the new one, preserving all existing function selectors.

The third action adjusts only the utilization breakpoints for USDC and USDT borrow curves to become more conservative near high utilization. By moving the kinks to `90%` and `95%` while preserving kink rates (`4.5%` and `7.5%`), the proposal changes where the slope transitions occur without modifying the target rates at those transition points.

## Conclusion

IGP128 upgrades the Liquidity Layer AdminModule via InfiniteProxy (with rollback registration) and updates Ethereum USDC/USDT curve kinks to `90%/95%` while preserving the existing kink rates (`4.5%/7.5%`).
