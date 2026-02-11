## Withdraw Assets from Treasury for JupLend Rewards Funding

## Summary

This proposal withdraws funds from the treasury for JupLend rewards: (1) withdraws 1M GHO from the treasury's fGHO position to Team Multisig for JupLend rewards, and (2) withdraws 500k FLUID tokens to Team Multisig for additional rewards funding. These withdrawals support Fluid's strategic partnership with Jupiter and multi-chain expansion to Solana.

## Code Changes

### Action 1: Withdraw 1M GHO from fGHO to Team Multisig for JupLend Rewards

- **fGHO Contract**: `0x6A29A46E21C730DcA1d8b23d637c101cec605C5B`
- **Withdrawal Amount**: 1M GHO
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Redeem fGHO shares via BASIC-D-V2 connector to withdraw underlying GHO tokens
- **Purpose**: Withdraw funds from treasury's fGHO position to Team Multisig to fund JupLend rewards

### Action 2: Withdraw 500k FLUID to Team Multisig for Rewards Funding

- **FLUID Token Contract**: `0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb`
- **Withdrawal Amount**: 500k FLUID tokens
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Direct token withdrawal via BASIC-A connector from treasury DSA
- **Purpose**: Transfer FLUID tokens to Team Multisig for additional rewards funding and community programs

## Description

This proposal implements two treasury withdrawals to support user incentives on JupLend and broader community rewards:

1. **GHO Withdrawal for JupLend Rewards**
   - Withdraws 1M GHO from the treasury's fGHO position
   - Redeems fGHO shares to receive underlying GHO tokens
   - Transfers GHO to Team Multisig to be bridged and used for JupLend reward programs
   - Uses the BASIC-D-V2 connector to redeem fGHO shares in line with prior fGHO withdrawals

2. **FLUID Withdrawal for Rewards Funding**
   - Withdraws 500k FLUID tokens directly from the treasury
   - Transfers FLUID to Team Multisig for rewards funding and community programs
   - Uses the BASIC-A connector for direct token withdrawal from the treasury DSA

These withdrawals optimize treasury management by allocating assets specifically for JupLend incentives and FLUID-based rewards, reinforcing Fluid's cross-chain strategy and community engagement.

## Conclusion

IGP-118 is a focused treasury management proposal that withdraws 1M GHO and 500k FLUID from the treasury to fund JupLend and FLUID rewards. The proposal follows established patterns from prior treasury withdrawals, ensuring safe and efficient fund allocation to Team Multisig in support of Fluid's multi-chain growth and community programs.
