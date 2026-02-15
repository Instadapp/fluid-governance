# Withdraw 250 iETHv2 to Team Multisig for Fluid Lite User Compensation

## Summary

This proposal withdraws 250 iETHv2 tokens from the Fluid Treasury to the Team Multisig to refund Lite users for losses due to poor rates in current market conditions.

## Code Changes

### Action 1: Withdraw 250 iETHv2 to Team Multisig for Fluid Lite User Refunds

- **iETHv2 (Lite) Contract**: `0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78`
- **Withdrawal Amount**: 250 iETHv2 tokens
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Direct token withdrawal via BASIC-A connector from treasury DSA
- **Purpose**: Transfer iETHv2 to Team Multisig to refund Lite users

## Description

This proposal executes a single treasury withdrawal to support Lite users:

1. **iETHv2 Withdrawal for Lite User Refunds**
   - Withdraws 250 iETHv2 tokens from the treasury
   - Transfers iETHv2 to Team Multisig for distribution to Lite users as refunds for losses due to poor rates in current market conditions.
   - Uses the BASIC-A connector for direct token withdrawal from the treasury DSA

## Conclusion

IGP-119 withdraws 250 iETHv2 to the Team Multisig to refund Lite users for for losses due to poor rates in current market conditions. The proposal ensures safe and efficient allocation of funds for user compensation.