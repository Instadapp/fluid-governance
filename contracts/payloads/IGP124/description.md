# Establish Fluid Foundation — Monthly Grant Transfer

## Summary

This proposal implements the on-chain action for the Fluid Foundation establishment approved via [Snapshot vote](https://snapshot.org/#/s:instadapp-gov.eth/proposal/0xde0d55050ef945d3d756219a9ee2cf29ef97c3f5625b107a65e9fd39937d6c5e): a withdrawal of **250,000 GHO** from fGHO to the Fluid Foundation. This is part of the approved **$250,000/month** recurring grant program, with disbursements continuing on a monthly basis until the next review. All other components of the Foundation establishment (IP transfer, legal execution) are handled off-chain.

## Code Changes

### Action 1: Withdraw 250,000 GHO from fGHO to Fluid Foundation

- **Token**: fGHO (`0x6A29A46E21C730DcA1d8b23d637c101cec605C5B`)
- **Amount**: 250,000 GHO
- **Recipient**: Fluid Foundation wallet (`0xde0377eF25aD02dBcFbc87D632E46bf1972A0Dc3`)
- **Method**: Withdrawal via BASIC-D-V2 connector from treasury DSA (redeems fGHO for underlying GHO)

## Description

The Fluid community voted to establish the Fluid Foundation — a purpose-built, non-profit legal entity (Cayman Islands) to hold and steward Fluid Protocol intellectual property on behalf of the DAO, and to approve a $250,000/month grant to fund ongoing protocol operations, technical development, and growth.

Covered under the grant:

- Core engineering and smart contract development
- Protocol operations and infrastructure
- Business development and integrations
- Security and risk management
- General team and organizational expenses

This proposal executes a monthly disbursement of 250,000 GHO, withdrawn from the treasury's fGHO position (the Fluid lending token for GHO), under the approved grant program. These transfers will recur each month until the next governance review cycle, at which point the community may reassess the grant amount, scope, or continuation. Revenue consolidation from multi-chain sources into the Ethereum treasury will continue on a recurring basis per the governance approval.

Forum: https://gov.fluid.io/t/proposal-establish-fluid-foundation/1768  
Snapshot: https://snapshot.org/#/s:instadapp-gov.eth/proposal/0xde0d55050ef945d3d756219a9ee2cf29ef97c3f5625b107a65e9fd39937d6c5e

## Conclusion

IGP-124 withdraws 250,000 GHO from the treasury's fGHO position and transfers it to the Fluid Foundation as a monthly grant disbursement under the community-approved funding program. This recurring transfer will continue each month until the next governance review.
