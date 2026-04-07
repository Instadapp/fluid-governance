# List New LL Admin Module and Update USDC/USDT Rate Curve Kinks

## Summary

This proposal introduces two updates on the Ethereum Liquidity Layer:

1. Adds a new configurable admin module address as an authorized Liquidity Layer auth.
2. Updates the USDC and USDT V2 interest-rate curve kinks from `85%/93%` to `90%/95%`, while keeping the kink rates unchanged at `4.5%/7.5%`.

The admin module address is configurable by Team Multisig before governance execution.

## Code Changes

### Action 1: List Admin Module as LL Auth

- Calls `LIQUIDITY.updateAuths()` to add `liquidityAdminModule` as an authorized address on Liquidity Layer.
- Requires `liquidityAdminModule` to be set by Team Multisig before execution.

### Action 2: Update USDC & USDT Rate-Curve Kinks

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

The first action adds a new Liquidity Layer admin module address to LL auths through `updateAuths()`. This enables the configured module to execute privileged LL admin operations that are gated by auth permissions.

The second action adjusts only the utilization breakpoints for USDC and USDT borrow curves to become more conservative near high utilization. By moving the kinks to `90%` and `95%` while preserving kink rates (`4.5%` and `7.5%`), the proposal changes where the slope transitions occur without modifying the target rates at those transition points.

### Configurable Addresses (Team Multisig sets before execution)

| Variable | Purpose |
|---|---|
| `liquidityAdminModule` | Admin module address to be listed as auth on Liquidity Layer |

## Conclusion

IGP128 lists a new configurable admin module as LL auth and updates Ethereum USDC/USDT curve kinks to `90%/95%` while preserving the existing kink rates (`4.5%/7.5%`), delivering the requested parameter update with minimal scope change.
