# Collect wstETH Revenue from Liquidity Layer and Forward 413.2 wstETH (~510 ETH) from Reserve Contract to Team Multisig to Cover Fluid Lite ETH User Losses

## Summary

This proposal performs a single Ethereum action:

1. Collects accrued **wstETH** revenue from the Liquidity Layer into the Fluid Reserve Contract via `LIQUIDITY.collectRevenue([wstETH])`, then forwards `413.2 * 1e18` wstETH (~510 ETH) from the Reserve Contract to the Team Multisig via `FLUID_RESERVE.withdrawFunds`.

The withdrawal token (`wstETH`), the amount (`413.2 * 1e18`), and the recipient (`TEAM_MULTISIG`) are all hardcoded in the payload and are **not** Team Multisig-configurable before execution.

## Code Changes

### Action 1: Collect wstETH Revenue from LL → Reserve Contract → Team Multisig

- **Step 1 (Liquidity Layer revenue collection)**: Calls `LIQUIDITY.collectRevenue(tokens_)` with `tokens_ = [wstETH_ADDRESS]`. This transfers accrued wstETH revenue from the Liquidity Layer to the configured revenue collector (the Fluid Reserve Contract, `0x264786EF916af64a1DB19F513F24a3681734ce92`).
- **Step 2 (Reserve Contract → Team Multisig)**: Calls `FLUID_RESERVE.withdrawFunds(tokens_, amounts_, TEAM_MULTISIG)` with `tokens_ = [wstETH_ADDRESS]` and `amounts_ = [413.2 * 1e18]` (~510 ETH).
- Any wstETH revenue accrued in excess of `413.2 * 1e18` remains on the Reserve Contract for future use.

| Field | Value |
|---|---|
| Token | wstETH (`0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0`) |
| Amount | `413.2 * 1e18` (~510 ETH) |
| Recipient | Team Multisig (`TEAM_MULTISIG`) |
| Flow | Liquidity Layer → Fluid Reserve Contract → Team Multisig |

## Description

During recent market volatility, ETH borrow rates spiked across the lending protocols used by Fluid Lite. The elevated borrow rates exceeded stETH staking yield, resulting in losses for Lite ETH vault depositors.

To fund the refund without drawing on the broader Treasury, this proposal first collects accrued wstETH revenue at the Liquidity Layer into the Fluid Reserve Contract (same `LIQUIDITY.collectRevenue` mechanism used in IGP-94 and IGP-102), and then forwards a targeted `413.2 * 1e18` wstETH (~510 ETH) from the Reserve Contract to the Team Multisig via `FLUID_RESERVE.withdrawFunds`. The Team Multisig will distribute the refund to affected Fluid Lite ETH users according to their exposure during the loss period.

This follows the same compensation pattern previously used in IGP-119 (which sent 250 iETHv2 ≈ 295 ETH to the Team Multisig to cover an earlier ETH borrow rate spike event affecting Lite users), but funded out of Liquidity-Layer wstETH revenue routed through the Reserve Contract rather than a direct Treasury DSA withdrawal.

> Note: No values on this payload are Team Multisig-configurable. The token, amount, and recipient are fixed in source before submission.

## Conclusion

IGP-130 collects accrued wstETH revenue from the Liquidity Layer into the Fluid Reserve Contract and forwards `413.2 * 1e18` wstETH (~510 ETH) onward to the Team Multisig to cover Fluid Lite ETH user losses from the recent ETH borrow rate spike across the underlying lending protocols. The broader maintenance batch previously drafted as IGP-130 (Liquidity Layer module upgrades, auth rotations, wstUSR rebalance, FLUID rewards funding, and Lite/DSA placeholders) has been moved to IGP-131.
