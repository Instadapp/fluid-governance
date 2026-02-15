# Withdraw 250 iETHv2 to Team Multisig to Cover Fluid Lite Losses

## Summary

This proposal withdraws 250 iETHv2 tokens (~295 ETH) from the Fluid Treasury to the Team Multisig to cover losses incurred by Lite users from ETH borrow rate spikes across underlying lending protocols due to recent market conditions.

## Code Changes

### Action 1: Withdraw 250 iETHv2 to Team Multisig

- **iETHv2 (Lite) Contract**: `0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78`
- **Amount**: 250 iETHv2 tokens
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Direct withdrawal via BASIC-A connector from treasury DSA

## Description

During recent market volatility, ETH borrow rates spiked across protocols used by Fluid Lite. The elevated borrow rates exceeded stETH staking yield, resulting in losses for Lite vault depositors.

In 2025, Fluid Lite has earned approximately ~$4M in revenue for protocol. A similar rate spike event occurred in 2025 resulting in a ~$0.5M loss, which was covered in the same manner.

This proposal withdraws 250 iETHv2 from the treasury to the Team Multisig for distribution to affected Lite users according to their exposure during the loss period.

## Conclusion

IGP-119 allocates 250 iETHv2 from the treasury to cover Lite user losses from the recent ETH borrow rate spike across underlying lending protocols.