## Withdraw Assets from Treasury for Formal Audit and Rewards Funding

## Summary

This proposal withdraws funds from the treasury for two operational purposes: (1) withdraws 0.5M GHO from the treasury's fGHO position to Team Multisig for formal audit expenses, and (2) withdraws 500k FLUID tokens to Team Multisig for rewards funding. These withdrawals support protocol operations by allocating resources for security audits and community rewards programs.

## Code Changes

### Action 1: Withdraw 0.5M GHO from fGHO to Team Multisig for Formal Audit

- **fGHO Contract**: `0x6A29A46E21C730DcA1d8b23d637c101cec605C5B`
- **Withdrawal Amount**: 0.5M GHO
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Redeem fGHO shares via BASIC-D-V2 connector to withdraw underlying GHO tokens
- **Purpose**: Withdraw funds from treasury's fGHO position to Team Multisig for formal audit expenses

### Action 2: Withdraw 500k FLUID to Team Multisig for Rewards Funding

- **FLUID Token Contract**: `0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb`
- **Withdrawal Amount**: 500k FLUID tokens
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Direct token withdrawal via BASIC-A connector from treasury DSA
- **Purpose**: Transfer FLUID tokens to Team Multisig for rewards funding and community programs

## Description

This proposal implements two treasury withdrawals to support protocol operations and community engagement:

1. **GHO Withdrawal for Formal Audit**
   - Withdraws 0.5M GHO from the treasury's fGHO position
   - Redeems fGHO shares to receive underlying GHO tokens
   - Transfers GHO to Team Multisig for formal audit expenses
   - Follows the same pattern as previous fGHO withdrawals (e.g., IGP114), using the BASIC-D-V2 connector to redeem fGHO shares

2. **FLUID Withdrawal for Rewards Funding**
   - Withdraws 500k FLUID tokens directly from the treasury
   - Transfers FLUID to Team Multisig for rewards funding
   - Supports community rewards programs and operational needs
   - Uses the BASIC-A connector for direct token withdrawal from the treasury DSA

These withdrawals optimize treasury management by allocating resources for critical security audits and community rewards, ensuring the protocol maintains high security standards while continuing to engage and reward its community.

## Conclusion

IGP-116 is a focused treasury management proposal that withdraws funds for two essential operational purposes: formal audit expenses (0.5M GHO) and rewards funding (500k FLUID). The proposal follows established patterns from prior treasury withdrawals, ensuring safe and efficient fund allocation to Team Multisig for these critical protocol needs. These withdrawals support ongoing security improvements through formal audits and maintain community engagement through rewards programs.
