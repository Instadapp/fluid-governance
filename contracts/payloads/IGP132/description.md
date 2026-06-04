# Update USDC, USDT & GHO Max-Utilization Borrow Rate and Remove Team Multisig USDC/USDT Borrow Limit on Liquidity Layer

## Summary

This proposal introduces two updates on Ethereum:

1. Caps the borrow rate at maximum utilization to `15%` (from the current `40%`) for `USDC`, `USDT`, and `GHO` on the Liquidity Layer, keeping every other rate-curve parameter unchanged.
2. Reduces the Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`) `USDC` and `USDT` borrow limits on the Liquidity Layer to the minimum (base `10` / max `20` wei), i.e. effectively `0`.

## Code Changes

### Action 1: Cap USDC, USDT & GHO Borrow Rate at Max Utilization to 15%

- Calls `LIQUIDITY.updateRateDataV2s()` for `USDC`, `USDT`, and `GHO` (all three use rate model v2).
- Changes for every token:
  - `rateAtUtilizationMax`: `40% -> 15%`
- Keeps unchanged (matching the current on-chain `getTokenRateData(token)` values):
  - `USDC` / `USDT`: `kink1 = 85%`, `kink2 = 93%`, `rateAtUtilizationZero = 0%`, `rateAtUtilizationKink1 = 5.4%`, `rateAtUtilizationKink2 = 7.5%`
  - `GHO`: `kink1 = 85%`, `kink2 = 93%`, `rateAtUtilizationZero = 0%`, `rateAtUtilizationKink1 = 6.5%`, `rateAtUtilizationKink2 = 9.5%`
- The Liquidity AdminModule requires `rateAtUtilizationKink2 <= rateAtUtilizationMax`; this holds for all three tokens (`7.5% <= 15%`, `9.5% <= 15%`).

### Action 2: Reduce Team Multisig USDC & USDT Borrow Limits to Effectively Zero

- Calls `setBorrowProtocolLimitsPaused()` for the Team Multisig with borrow tokens `USDC` and `USDT`.
- Lowers the borrow limit to ~`0` (`baseDebtCeiling = 10`, `maxDebtCeiling = 20`, in wei). This sets the debt ceiling to a dust amount — it is **not** an operation-level borrow pause; borrowing is simply capped at ~`0`. Other config: `mode = 1`, `expandPercent = 1` (`0.01%`), `expandDuration = 16777215` (max).
- `mode = 1` (with interest) matches the Team Multisig's existing on-chain borrow config for both tokens, so no mode switch is triggered.

## Description

The first action makes the USDC, USDT, and GHO borrow curves substantially less punitive at the top end by lowering the rate charged at 100% utilization from `40%` to `15%`. Only `rateAtUtilizationMax` is changed; the utilization breakpoints (`kink1 = 85%`, `kink2 = 93%`) and the rates at zero/both kinks are read from the live Liquidity Layer rate config and re-supplied unchanged, so the shape of the curve below `kink2` is preserved and only the final segment (`kink2 -> 100%`) flattens.

The second action drives the Team Multisig's direct USDC and USDT borrow capacity on the Liquidity Layer to effectively zero. Because the Liquidity AdminModule rejects a literal-zero `baseDebtCeiling` / `maxDebtCeiling` (reverting with `LimitZero`), the established convention of minimal "dust" limits (`baseDebtCeiling = 10`, `maxDebtCeiling = 20`, with the slowest possible expansion) is used to represent "0". Existing debt is not affected by the change; the reduced ceiling only blocks new borrowing beyond the dust amount.

## Conclusion

IGP132 caps the USDC, USDT, and GHO max-utilization borrow rate at `15%` (down from `40%`) while preserving all other rate-curve parameters at their current on-chain values, and reduces the Team Multisig's USDC and USDT borrow limits on the Liquidity Layer to the minimum (base `10` / max `20` wei), effectively setting that borrowing capacity to `0`.
