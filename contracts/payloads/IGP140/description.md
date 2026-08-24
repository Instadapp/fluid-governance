# Launch the weETH/ETH Vault at Dust Limits

## Summary

This proposal brings the new **weETH/ETH** T1 vault (id **182**) online by setting its Liquidity Layer limits at dust size and granting the Team Multisig vault auth so limits can be scaled up as the market proves out.

The vault contract was deployed by the Team Multisig at block 25,789,585 and is still unconfigured at the Liquidity Layer, so it cannot be supplied to or borrowed from until this payload executes.

## Code Changes

### Action 1: Set Dust Limits for the weETH/ETH T1 Vault (id 182)

- **Vault**: `0x0b8a681ed46EA8ec6b97D686dF0631fBf84B03d2` (T1, weETH collateral / ETH debt)
- **Collateral**: weETH (`0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee`)
- **Debt**: ETH (`0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`)

| Vault | Type | Market | Limits |
| --- | --- | --- | --- |
| 182 | T1 | weETH / ETH | Withdrawal base `$7k`, Borrow `$7k / $9k` (LL) |

- Limits are set at the Liquidity Layer via `setVaultLimits` with the standard dust-limit config: 50% expansion over 6 hours.
- Team Multisig is granted vault auth so it can raise limits post-launch without a further proposal. The call goes through the VaultFactoryOwner wrapper (`0xB031913cB7AD81b8A4Ba412B471c2dA69BEA410B`), which owns the vault factory and which the timelock is authorized on.

## Description

weETH/ETH is a correlated-pair leverage market: users supply weETH and borrow ETH to loop into ether.fi staking yield. Fluid already runs weETH markets against stablecoins and wstETH, plus a weETH-ETH DEX (id 9), so both legs are established collateral at the Liquidity Layer.

New markets launch at dust limits by convention. The $7k / $9k ceilings cap total exposure while the vault's oracle and liquidation behaviour are observed under real usage, and the Team Multisig auth lets limits be raised incrementally once it is behaving as expected rather than requiring a governance cycle per step.

This action was originally Action 2 of IGP-139, the Foundation grant payload. It targeted the vault factory directly for the vault-auth call, which reverts because the factory's `setVaultAuth` is owner-gated and the factory is owned by the wrapper contract rather than the timelock. That reverted IGP-139 in full during simulation. Splitting the vault launch into its own payload unblocks the grant, which has no dependency on this market, and corrects the auth routing.

## Conclusion

IGP-140 launches the weETH/ETH T1 vault (id 182) with $7k base withdrawal, $7k base borrow, and $9k max borrow limits at the Liquidity Layer, and grants the Team Multisig vault auth for post-launch scaling.
