# Withdraw 512 WETH to Team Multisig to Cover Fluid Lite ETH User Losses

## Summary

This proposal withdraws `512 * 1e18` WETH (~512 ETH) from the Fluid Treasury DSA to the Team Multisig to cover losses incurred by Fluid Lite ETH users from ETH borrow rate spikes across the underlying lending protocols during recent market conditions.

The withdrawal token (`WETH`), the amount (`512 * 1e18`), and the recipient (`TEAM_MULTISIG`) are all hardcoded in the payload and are **not** Team Multisig-configurable before execution.

## Code Changes

### Action 1: Withdraw 512 WETH to Team Multisig

- **Token**: WETH (`0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`)
- **Amount**: `512 * 1e18` (~512 ETH)
- **Recipient**: Team Multisig (`TEAM_MULTISIG`)
- **Method**: Casts the Treasury DSA with the `BASIC-A` connector and the `withdraw(address,uint256,address,uint256,uint256)` spell with args `(WETH_ADDRESS, 512 * 1e18, TEAM_MULTISIG, 0, 0)`.

## Description

During recent market volatility, ETH borrow rates spiked across the lending protocols used by Fluid Lite. The elevated borrow rates exceeded stETH staking yield, resulting in losses for Lite ETH vault depositors.

This proposal follows the same compensation pattern that was used previously in IGP-119 (which withdrew 250 iETHv2 ≈ 295 ETH to the Team Multisig to cover an earlier ETH borrow rate spike event affecting Lite users). Here, the protocol withdraws `512 * 1e18` WETH directly from the Treasury DSA so the Team Multisig can distribute the refund to affected Fluid Lite ETH users according to their exposure during the loss period.

> Note: No values on this payload are Team Multisig-configurable. The token, amount, and recipient are fixed in source before submission.

## Conclusion

IGP-130 allocates `512 * 1e18` WETH (~512 ETH) from the Treasury to the Team Multisig, via the `BASIC-A` connector, to cover Fluid Lite ETH user losses from the recent ETH borrow rate spike across the underlying lending protocols. The broader maintenance batch previously drafted as IGP-130 (Liquidity Layer module upgrades, auth rotations, wstUSR rebalance, FLUID rewards funding, and Lite/DSA placeholders) has been moved to IGP-131.
