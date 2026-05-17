# Transfer 413.2 wstETH (~510 ETH) to Lite ETH Vault DSA to Cover Fluid Lite ETH User Losses

## Summary

This proposal transfers `413.2 * 1e18` wstETH (~510 ETH) from the Fluid Treasury DSA directly into the **Fluid Lite ETH Vault DSA (iETHv2 DSA)** to cover losses incurred by Fluid Lite ETH users from ETH borrow rate spikes across the underlying lending protocols during recent market conditions.

The withdrawal token (`wstETH`), the amount (`413.2 * 1e18`), and the recipient (Lite ETH Vault DSA, `0x9600A48ed0f931d0c422D574e3275a90D8b22745`) are all hardcoded in the payload and are **not** Team Multisig-configurable before execution.

## Code Changes

### Action 1: Transfer 413.2 wstETH from Treasury to Lite ETH Vault DSA

- **Token**: wstETH (`0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0`)
- **Amount**: `413.2 * 1e18` (~510 ETH)
- **Recipient**: Fluid Lite ETH Vault DSA / iETHv2 DSA (`0x9600A48ed0f931d0c422D574e3275a90D8b22745`)
- **Method**: Casts the Treasury DSA with the `BASIC-A` connector and the `withdraw(address,uint256,address,uint256,uint256)` spell with args `(wstETH_ADDRESS, 413.2 * 1e18, LITE_ETH_VAULT_DSA, 0, 0)`.

## Description

During recent market volatility, ETH borrow rates spiked across the lending protocols used by Fluid Lite. The elevated borrow rates exceeded stETH staking yield, resulting in losses for Lite ETH vault depositors.

This proposal follows the same compensation pattern that was used previously in IGP-119 (which withdrew 250 iETHv2 ≈ 295 ETH to the Team Multisig to cover an earlier ETH borrow rate spike event affecting Lite users). The key difference is that here the refund is sent **directly to the Lite ETH Vault DSA** as `413.2 * 1e18` wstETH (~510 ETH) so it tops up the underlying assets backing Fluid Lite ETH users' iETHv2 positions, rather than being routed through the Team Multisig for off-chain distribution.

> Note: No values on this payload are Team Multisig-configurable. The token, amount, and recipient are fixed in source before submission.

## Conclusion

IGP-130 allocates `413.2 * 1e18` wstETH (~510 ETH) from the Treasury DSA to the Fluid Lite ETH Vault DSA (iETHv2 DSA, `0x9600A48ed0f931d0c422D574e3275a90D8b22745`), via the `BASIC-A` connector, to cover Fluid Lite ETH user losses from the recent ETH borrow rate spike across the underlying lending protocols. The broader maintenance batch previously drafted as IGP-130 (Liquidity Layer module upgrades, auth rotations, wstUSR rebalance, FLUID rewards funding, and Lite/DSA placeholders) has been moved to IGP-131.
