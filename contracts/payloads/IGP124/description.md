# Establish Fluid Foundation — Monthly Grant Transfer

## Summary

This proposal implements the on-chain action for the Fluid Foundation establishment approved via [Snapshot vote](https://snapshot.org/#/s:instadapp-gov.eth/proposal/0xde0d55050ef945d3d756219a9ee2cf29ef97c3f5625b107a65e9fd39937d6c5e): a transfer of **250,000 USDC** from the DAO treasury to the Fluid Foundation. This is part of the approved **$250,000/month** recurring grant program, with disbursements continuing on a monthly basis until the next governance review. All other components of the Foundation establishment (IP transfer, legal execution) are handled off-chain.

## Code Changes

### Action 1: Transfer 250,000 USDC to Fluid Foundation

- **Token**: USDC (`0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`)
- **Amount**: 250,000 USDC
- **Recipient**: Fluid Foundation wallet (`FLUID_FOUNDATION_ADDRESS`)
- **Method**: Direct withdrawal via BASIC-A connector from treasury DSA

## Description

The Fluid community voted to establish the Fluid Foundation — a purpose-built, non-profit legal entity (Cayman Islands) to hold and steward Fluid Protocol intellectual property on behalf of the DAO, and to approve a $250,000/month grant to fund ongoing protocol operations, technical development, and growth.

Covered under the grant:

- Core engineering and smart contract development
- Protocol operations and infrastructure
- Business development and integrations
- Security and risk management
- General team and organizational expenses

This proposal executes a monthly disbursement of 250,000 USDC under the approved grant program. These transfers will recur each month until the next governance review cycle, at which point the community may reassess the grant amount, scope, or continuation. Revenue consolidation from multi-chain sources into the Ethereum treasury will continue on a recurring basis per the governance approval.

Forum: https://gov.fluid.io/t/proposal-establish-fluid-foundation/1768  
Issue: https://github.com/Instadapp/fluid-governance/issues/146

## Conclusion

IGP-124 transfers 250,000 USDC from the DAO treasury to the Fluid Foundation as a monthly grant disbursement under the community-approved funding program. This recurring transfer will continue each month until the next governance review.
