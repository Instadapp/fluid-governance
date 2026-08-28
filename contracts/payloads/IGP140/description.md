# Launch the weETH/ETH Vault, Deprecate osETH Markets, and Clean Up DEX Limits and Auth

## Summary

This proposal brings the new **weETH/ETH** T1 vault (id **182**) online by setting its Liquidity Layer limits at dust size and granting the Team Multisig vault auth so limits can be scaled up as the market proves out. It also reduces the deprecated **USDC-ETH DEX (5)** max supply and max borrow shares to **~$1M** each, fully deprecates the **osETH** markets' borrow side (vaults **153–157**, **159**, and the **ETH-osETH DEX 43**), and removes the Team Multisig dex auth granted in IGP-138 on the **USDat/USDC (49)** and **USDC/trUSD (50)** DEXes.

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

### Action 2: Reduce USDC-ETH DEX (5) Max Supply and Borrow Shares to ~$1M

- **DEX**: `0x2886a01a0645390872a9eb99dAe1283664b0c524` (USDC-ETH, id 5)

| Parameter | Current | New |
| --- | --- | --- |
| Max supply shares | `7.5M` (~$15M) | `500k` (~$1M at ~$2/share) |
| Max borrow shares | `5M` (~$10M) | `500k` (~$1M at ~$2/share) |

The DEX has been deprecated since IGP-96 dust-ceilinged its borrow limits and currently holds only dust liquidity (~101 supply / ~100 borrow shares). Calls: `updateMaxSupplyShares(500_000e18)` and `updateMaxBorrowShares(500_000e18)`.

### Action 3: Fully Deprecate the osETH Markets' Borrow Side

IGP-138 had already capped the osETH T1 vaults at $100k borrow (base = max). This action pauses the borrow side entirely — dust debt ceilings with expansion frozen at the minimum (0.01% over max duration) — and blocks new supply into the ETH-osETH DEX. Existing positions can still repay and withdraw.

| Market | Type | Borrow side | Change |
| --- | --- | --- | --- |
| Vault 153 | T1 | USDC (LL) | Paused: dust ceilings, frozen expansion |
| Vault 154 | T1 | USDT (LL) | Paused: dust ceilings, frozen expansion |
| Vault 155 | T1 | GHO (LL) | Paused: dust ceilings, frozen expansion |
| Vault 156 | T3 | USDC-USDT DEX (2) shares | Paused: dust ceilings, frozen expansion |
| Vault 157 | T3 | USDC-USDT conc. DEX (34) shares | Paused: dust ceilings, frozen expansion |
| Vault 159 | T2 | wstETH (LL) | Paused: dust ceilings, frozen expansion |
| DEX 43 | Smart col | — | Max supply shares → `1` wei (from 5,700; ~3,021 outstanding) |

### Action 4: Remove Team Multisig Auth on IGP-138 DEXes

IGP-138 granted the Team Multisig dex auth when launching the USDat/USDC and USDC/trUSD smart-lending pools. With the launches complete, the auth is removed per the standard post-launch cleanup:

| DEX | Pair | Change |
| --- | --- | --- |
| 49 | USDat / USDC | `setDexAuth(dex, TEAM_MULTISIG, false)` |
| 50 | USDC / trUSD | `setDexAuth(dex, TEAM_MULTISIG, false)` |

## Description

weETH/ETH is a correlated-pair leverage market: users supply weETH and borrow ETH to loop into ether.fi staking yield. Fluid already runs weETH markets against stablecoins and wstETH, plus a weETH-ETH DEX (id 9), so both legs are established collateral at the Liquidity Layer.

New markets launch at dust limits by convention. The $7k / $9k ceilings cap total exposure while the vault's oracle and liquidation behaviour are observed under real usage, and the Team Multisig auth lets limits be raised incrementally once it is behaving as expected rather than requiring a governance cycle per step.

This action was originally Action 2 of IGP-139, the Foundation grant payload. It targeted the vault factory directly for the vault-auth call, which reverts because the factory's `setVaultAuth` is owner-gated and the factory is owned by the wrapper contract rather than the timelock. That reverted IGP-139 in full during simulation. Splitting the vault launch into its own payload unblocks the grant, which has no dependency on this market, and corrects the auth routing.

## Conclusion

IGP-140 launches the weETH/ETH T1 vault (id 182) with $7k base withdrawal, $7k base borrow, and $9k max borrow limits at the Liquidity Layer and grants the Team Multisig vault auth for post-launch scaling. It also reduces the deprecated USDC-ETH DEX (5) max supply and max borrow shares to ~$1M each, fully deprecates the osETH markets' borrow side (vaults 153–157 and 159, plus a 1-wei supply-share cap on the ETH-osETH DEX 43), and removes the Team Multisig dex auth granted in IGP-138 on DEXes 49 and 50.
