# Increase Foundation Monthly Grant from $250,000 to $350,000

## Summary

This proposal raises the Fluid Foundation's monthly grant from **$250,000** to **$350,000** per month, effective immediately upon approval per the [forum proposal](https://gov.fluid.io/t/increase-foundation-monthly-grant-from-250-000-to-350-000/1787), and executes the first disbursement at the new rate.

The $250,000/month grant approved in February ([Snapshot](https://snapshot.org/#/s:instadapp-gov.eth/proposal/0xde0d55050ef945d3d756219a9ee2cf29ef97c3f5625b107a65e9fd39937d6c5e)) was never drawn: IGP-124, the payload that would have transferred the first tranche, expired without execution while the treasury was absorbing Resolv-incident costs. The disbursement is funded in stETH from the Fluid Reserve rather than the GHO used in IGP-124.

## Code Changes

### Action 1: Transfer the Monthly Grant to the Fluid Foundation

- **Source**: Fluid Reserve (`0x264786EF916af64a1DB19F513F24a3681734ce92`)
- **Method**: `withdrawFunds([stETH], [187000000000000000000], FLUID_FOUNDATION, "FOUNDATION GRANT")`
- **Token**: stETH (`0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84`)
- **Amount**: `187 stETH` — ~$350,000 at the 7-day average ETH price of $1,872.43
- **Recipient**: Fluid Foundation (`0xde0377eF25aD02dBcFbc87D632E46bf1972A0Dc3`)

## Description

In February the DAO approved a $250,000/month grant to the Fluid Foundation, funding protocol operations, development, and growth. The Foundation did not draw it while the treasury was absorbing costs from the Resolv incident and other priorities.

Since February the Foundation's scope has expanded materially. The increased grant covers:

- Continued Sui development and integration work.
- Expansion of AGI3 markets and associated infrastructure.
- Additional security reviews and protocol audits.
- Strengthening the protocol's off-chain security systems.
- Community events and ecosystem initiatives.
- Participation in industry conferences including Devconnect and Token2049.
- Legal expenditures.
- Potential expansion to additional blockchain ecosystems and integrations.
- Additional engineering and developer resources for new products and protocol features.
- Ongoing operational and ecosystem growth expenses.

This proposal executes the first disbursement at the new $350,000 rate. Transfers recur monthly until the next governance review cycle, at which point the community may reassess the amount, scope, or continuation of the grant.

## References

- Forum: https://gov.fluid.io/t/increase-foundation-monthly-grant-from-250-000-to-350-000/1787
- Original Foundation proposal: https://gov.fluid.io/t/proposal-establish-fluid-foundation/1768
- February Snapshot: https://snapshot.org/#/s:instadapp-gov.eth/proposal/0xde0d55050ef945d3d756219a9ee2cf29ef97c3f5625b107a65e9fd39937d6c5e

## Conclusion

IGP-138 increases the Fluid Foundation's monthly grant from $250,000 to $350,000 effective immediately and transfers 187 stETH from the Fluid Reserve to the Fluid Foundation as the first disbursement. Subsequent monthly transfers continue until the next governance review.
