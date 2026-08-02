# AGI3: Strategic Institutional Ecosystem Partnership and Investment in Fluid

## Summary

This proposal approves a Strategic Institutional Ecosystem Partnership with AGI3 and, as part of the [forum proposal](https://gov.fluid.io/t/agi3-strategic-institutional-ecosystem-partnership-and-investment-in-fluid/1783), allocates **5% of the total $FLUID supply (5,000,000 FLUID)** to support integrations with regulated private banks and institutional-grade digital asset custodians across Switzerland, the European Union, Hong Kong, and Singapore. The tokens are first transferred to Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`) and subsequently moved into a dedicated wallet before distribution to the relevant custodial partners.

## Code Changes

### Action 1: Withdraw 5,000,000 FLUID from Treasury to Team Multisig

- **FLUID Token Contract**: `0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb`
- **Withdrawal Amount**: `5,000,000 FLUID` (`5_000_000 * 1e18`) — 5% of the 100,000,000 total supply
- **Source**: Treasury DSA (`0x28849D2b63fA8D361e5fc15cB8aBB13019884d09`), which holds ~21.3M FLUID
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Direct token withdrawal via the `BASIC-A` connector from the Treasury DSA, following the pattern used in IGP-131, IGP-118, and IGP-116
- **Purpose**: Fund the AGI3 institutional custody allocation

## Description

Kinetic Group plans to acquire up to 10% of the $FLUID token supply through open-market buys, over-the-counter deals, and other negotiated arrangements. None of those tokens come from the DAO treasury or the team allocation, and no part of that acquisition is in scope for this payload.

Separately, and as executed by this proposal, Fluid Foundation will provide a 5% allocation of $FLUID for enabling custody within regulated private banks and institutional digital asset custodians in Switzerland, the EU, Hong Kong, and Singapore. These institutions operate under FINMA, MiCA, HKMA, and MAS oversight and meet high standards of asset protection, governance, and operational resilience. This multi-custodian approach signals true institutional adoption and makes $FLUID available to the clients of these financial institutions. These tokens will be legally locked for at least 4 years, until 2030.

As part of the strategic partnership, AGI3 will grant Fluid Foundation a 2% equity stake to align incentives and support long-term collaboration. The AGI3 equity shares held by Fluid Foundation will likewise be legally locked for at least 4 years, until 2030.

## References

- Forum: https://gov.fluid.io/t/agi3-strategic-institutional-ecosystem-partnership-and-investment-in-fluid/1783

## Conclusion

IGP-137 ratifies the AGI3 Strategic Institutional Ecosystem Partnership and Investment proposal and authorizes the transfer of 5,000,000 FLUID from the Treasury to Team Multisig. The transferred tokens will support custody integrations with regulated banking institutions and institutional digital asset custodians across Switzerland, the European Union, Hong Kong, and Singapore.
