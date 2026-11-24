# Set Launch Limits for the DexV2 and Money Market and Transfer the ETH/FLUID Fluid Dex V1 Position to the Team Multisig

## Summary

This proposal sets the public launch limits on the Liquidity Layer for the **DexV2** proxy and the **Money Market** proxy on Ethereum. For **ETH**, **USDC**, **USDT**, **WBTC**, **cbBTC** and **wstETH** on both proxies, it sets a **$5M** base withdrawal limit and a **$5M** base borrow limit, with borrow ceilings of **$30M** (ETH, USDC, USDT, wstETH), **$15M** (WBTC) and **$5M** (cbBTC). Limits expand by **50%** every **6 hours**. On the DexV2 proxy it also sets a **$5M** base withdrawal limit for **FLUID** (supply only). This replaces the $50k private-beta limits set in IGP-141 and adds cbBTC and wstETH. It also transfers the **ETH/FLUID Fluid Dex V1 position** (NFT **#3192**, vault 76) from the Treasury to the Team Multisig.

## Code Changes

### Action 1: Launch Limits for the DexV2 and Money Market Proxies

| Protocol | Address |
| --- | --- |
| DexV2 proxy | [0xaBE4D5AA1Bb188f4B5d3a1aE3B8ec5e300A78261](https://etherscan.io/address/0xaBE4D5AA1Bb188f4B5d3a1aE3B8ec5e300A78261) |
| Money Market proxy | [0x92fC6445a6d57fCA94c3B847E80504B95e2D9e2F](https://etherscan.io/address/0x92fC6445a6d57fCA94c3B847E80504B95e2D9e2F) |

For each proxy, mode with interest, expand 50% over 6h on both sides:

| Token | Supply: base withdrawal limit | Borrow: base debt ceiling | Borrow: max debt ceiling |
| --- | --- | --- | --- |
| ETH | $5M | $5M | $30M |
| USDC | $5M | $5M | $30M |
| USDT | $5M | $5M | $30M |
| wstETH | $5M | $5M | $30M |
| WBTC | $5M | $5M | $15M |
| cbBTC | $5M | $5M | $5M |

DexV2 proxy only, supply only (no borrow config), mode with interest, expand 50% over 6h:

| Token | Supply: base withdrawal limit |
| --- | --- |
| FLUID | $5M |

Token amounts are sized at ETH ~$1,770, wstETH ~$2,230, BTC ~$63,000, stablecoins $1 and FLUID ~$1.48 (CoinGecko). At those prices $5M is ~2,825 ETH, ~2,242 wstETH and ~79.4 WBTC / cbBTC; $30M is ~16,949 ETH and ~13,453 wstETH; $15M is ~238.1 WBTC; $5M is ~3.38M FLUID. The token amounts are fixed, so their USD value moves with price until execution.

### Action 2: Transfer the ETH/FLUID Fluid Dex V1 Position to the Team Multisig

- **NFT**: ETH/FLUID Fluid Dex V1 position, Fluid Vault NFT [#3192](https://etherscan.io/nft/0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d/3192) (vault 76), Vault Factory `0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d`
- **Position**: smart-collateral position on vault 76 (T2: FLUID/ETH DEX liquidity as collateral, ETH debt). It holds ~99.9% of the FLUID/ETH DEX liquidity (~2.63M FLUID + ~0.89 ETH, ~$3.85M) against ~0.042 ETH of debt. The Team Multisig opened it in Dec 2024 and moved it to the Treasury in Aug 2025.
- **Source**: Treasury DSA (`0x28849D2b63fA8D361e5fc15cB8aBB13019884d09`)
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: `withdrawERC721` via the `BASIC-B` (BASIC-ERC721) connector from the Treasury DSA

## Description

The DexV2 and Money Market have run on the Liquidity Layer with $50k limits since IGP-141. This proposal moves them to their launch limits and adds cbBTC and wstETH (plus FLUID supply on the DexV2), so both can open to all users. The base limits are available immediately. Above the base, the borrow limit grows with usage, by up to 50% of current borrows over 6 hours, until it reaches each token's ceiling.

The ETH/FLUID Fluid Dex V1 position (NFT #3192) moves to the Team Multisig so the team can adjust the position directly. It can be transferred back to the Treasury once the adjustments are done.

## Conclusion

IGP-144 sets $5M base withdrawal and borrow limits for ETH, USDC, USDT, WBTC, cbBTC and wstETH on the DexV2 and Money Market proxies, with borrow ceilings of $30M, $15M and $5M and a 50% / 6h expansion, sets a $5M base withdrawal limit for FLUID on the DexV2 proxy, and transfers the ETH/FLUID Fluid Dex V1 position (NFT #3192) from the Treasury to the Team Multisig.
