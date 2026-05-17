# Collect wstETH Revenue from Liquidity Layer and Forward 230 wstETH from Reserve Contract to Team Multisig to Cover Fluid Lite (iETHv2) ETH User Losses

## Summary

This proposal performs a single on-chain action:

1. Collects accrued **wstETH** revenue from the Liquidity Layer into the Fluid Reserve Contract via `LIQUIDITY.collectRevenue([wstETH])`, then forwards `230 * 1e18` wstETH from the Reserve Contract to the Team Multisig via `FLUID_RESERVE.withdrawFunds`.

Once the wstETH lands on the Team Multisig, an off-chain multisig transaction (already prepared on Avocado) will convert the wstETH to ETH and forward it to the iETHv2 loss-coverage recipient at `0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD` (Thrilok) for distribution to affected Fluid Lite ETH (iETHv2) users.

The withdrawal token (`wstETH`), the amount (`230 * 1e18`), and the on-chain recipient (`TEAM_MULTISIG`) are all hardcoded in the payload and are **not** Team Multisig-configurable before execution.

## Code Changes

### Action 1: Collect wstETH Revenue from LL → Reserve Contract → Team Multisig

- **Step 1 (Liquidity Layer revenue collection)**: Calls `LIQUIDITY.collectRevenue(tokens_)` with `tokens_ = [wstETH_ADDRESS]`. This transfers accrued wstETH revenue from the Liquidity Layer to the configured revenue collector (the Fluid Reserve Contract, `0x264786EF916af64a1DB19F513F24a3681734ce92`).
- **Step 2 (Reserve Contract → Team Multisig)**: Calls `FLUID_RESERVE.withdrawFunds(tokens_, amounts_, TEAM_MULTISIG)` with `tokens_ = [wstETH_ADDRESS]` and `amounts_ = [230 * 1e18]`.
- Any wstETH revenue accrued in excess of `230 * 1e18` remains on the Reserve Contract for future use.

| Field | Value |
|---|---|
| Token | wstETH (`0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0`) |
| Amount | `230 * 1e18` |
| On-chain recipient | Team Multisig (`TEAM_MULTISIG`, `0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`) |
| On-chain flow | Liquidity Layer → Fluid Reserve Contract → Team Multisig |
| Off-chain follow-up (multisig) | Team Multisig converts wstETH → ETH and forwards to `0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD` (Thrilok) for iETHv2 user loss coverage |

## Description

During recent market volatility, ETH borrow rates spiked across the lending protocols used by Fluid Lite. The elevated borrow rates exceeded stETH staking yield, resulting in losses for Lite ETH (iETHv2) vault depositors.

To fund the refund without drawing on the broader Treasury, this proposal first collects accrued wstETH revenue at the Liquidity Layer into the Fluid Reserve Contract (same `LIQUIDITY.collectRevenue` mechanism used in IGP-94 and IGP-102), and then forwards a targeted `230 * 1e18` wstETH from the Reserve Contract to the Team Multisig via `FLUID_RESERVE.withdrawFunds`.

After execution, the Team Multisig will run a separately-prepared Avocado multisig transaction (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`) that:

1. Converts the 230 wstETH to ETH, and
2. Transfers the resulting ETH to `0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD` (Thrilok), who applies it to the iETHv2 user loss coverage.

This follows the same compensation pattern previously used in IGP-119 (which sent 250 iETHv2 ≈ 295 ETH to the Team Multisig to cover an earlier ETH borrow rate spike event affecting Lite users), but funded out of Liquidity-Layer wstETH revenue routed through the Reserve Contract rather than a direct Treasury DSA withdrawal.

> Note: No values on this payload are Team Multisig-configurable. The token, amount, and on-chain recipient are fixed in source before submission. The off-chain conversion and downstream transfer happen at the Team Multisig, not in this payload.

## Conclusion

IGP-130 collects accrued wstETH revenue from the Liquidity Layer into the Fluid Reserve Contract and forwards `230 * 1e18` wstETH onward to the Team Multisig, which will then convert it to ETH off-chain and forward it to `0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD` (Thrilok) to cover Fluid Lite (iETHv2) ETH user losses from the recent ETH borrow rate spike across the underlying lending protocols. The broader maintenance batch previously drafted as IGP-130 (Liquidity Layer module upgrades, auth rotations, wstUSR rebalance, FLUID rewards funding, and Lite/DSA placeholders) has been moved to IGP-131.
