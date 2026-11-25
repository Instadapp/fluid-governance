# Set Launch Limits for the DexV2 and Money Market and Transfer the ETH/FLUID Fluid Dex V1 Position to the Team Multisig

## Summary

This proposal sets the public launch limits on the Liquidity Layer for the **DexV2** proxy and the **Money Market** proxy on Ethereum. For **ETH**, **USDC**, **USDT**, **WBTC**, **cbBTC** and **wstETH** on both proxies, it sets a **$5M** base withdrawal limit and a **$5M** base borrow limit, with borrow ceilings of **$30M** (ETH, USDC, USDT, wstETH), **$15M** (WBTC) and **$5M** (cbBTC). Limits expand by **50%** every **6 hours**. On the DexV2 proxy it also sets a **$5M** base withdrawal limit for **FLUID** (supply only). This replaces the $50k private-beta limits set in IGP-141 and adds cbBTC and wstETH. It also transfers the **ETH/FLUID Fluid Dex V1 position** (NFT **#3192**, vault 76) from the Treasury to the Team Multisig, restricts and pauses the first-generation DexV2 and Money Market proxies at the Liquidity Layer, and makes **OracleV2** fully live by switching the remaining **119** vaults to their OracleV2 oracles.

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

Token amounts are sized at ETH ~$1,650, wstETH ~$2,060, BTC ~$59,000, stablecoins $1 and FLUID ~$1.43 (CoinGecko). At those prices $5M is ~3,030 ETH, ~2,427 wstETH and ~84.7 WBTC / cbBTC; $30M is ~18,182 ETH and ~14,563 wstETH; $15M is ~254.2 WBTC; $5M is ~3.50M FLUID. The token amounts are fixed, so their USD value moves with price until execution.

### Action 2: Transfer the ETH/FLUID Fluid Dex V1 Position to the Team Multisig

- **NFT**: ETH/FLUID Fluid Dex V1 position [#3192](https://etherscan.io/nft/0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d/3192)
- **Position**: ~99.9% of the ETH/FLUID Fluid Dex V1 liquidity (~2.63M FLUID + ~0.89 ETH, ~$3.85M) as collateral, ~0.042 ETH of debt
- **Source**: Treasury DSA (`0x28849D2b63fA8D361e5fc15cB8aBB13019884d09`)
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)

### Action 3: Restrict and Pause the Old DexV2 and Money Market Proxies at the Liquidity Layer

| Protocol | Address |
| --- | --- |
| Old DexV2 proxy | [0x4E42f9e626FAcDdd97EDFA537AA52C5024448625](https://etherscan.io/address/0x4E42f9e626FAcDdd97EDFA537AA52C5024448625) |
| Old Money Market proxy | [0xe3B7e3f4da603FC40fD889caBdEe30a4cf15DD34](https://etherscan.io/address/0xe3B7e3f4da603FC40fD889caBdEe30a4cf15DD34) |

For each proxy, for ETH, USDC, USDT, WBTC and cbBTC:

| Step | Call | Effect |
| --- | --- | --- |
| Borrow | `setBorrowProtocolLimitsPaused` | Debt ceiling `10 / 20` (dust), expansion 0.01% over max duration |
| Supply | `setSupplyProtocolLimitsPaused` | Base withdrawal limit `10` (dust), expansion 0.01% over max duration |
| Pause supply | `LIQUIDITY.pauseUserSupply(proxy, tokens, true, true)` | Supply and withdraw paused for all five tokens |
| Pause borrow | `LIQUIDITY.pauseUserBorrow(proxy, tokens, true, true)` | Borrow and payback paused for all five tokens |

The pause calls use the Liquidity Admin module set in IGP-143, so IGP-144 must execute after IGP-143.

### Action 4: Make OracleV2 Fully Live

Switches every vault that has an OracleV2 oracle registered on the VaultOracleFactory ([0x40C10f5f6C78d2Afcaa2db85cBF6b7BF9d168dF1](https://etherscan.io/address/0x40C10f5f6C78d2Afcaa2db85cBF6b7BF9d168dF1), `getVaultOracleDeployment(vaultId)`) and is not switched yet, 119 vaults in total. Vaults 153 to 157 and 159 were switched in IGP-142. Vaults without an OracleV2 registration are not touched.

- T1 vaults (74) take the oracle address via `updateOracle(address)`.
- T2, T3 and T4 vaults (45) take the DeployerFactory nonce via `updateOracle(uint256)` and read the new oracle's operate and liquidate rates before committing it, so a broken oracle reverts the action.

| Vault | Type | Pair | Call | New oracle |
| --- | --- | --- | --- | --- |
| 1 | T1 | ETH / USDC | `updateOracle(address)` | [0x646f1676eAb96b2F09eCE84a021ba36893D665a0](https://etherscan.io/address/0x646f1676eAb96b2F09eCE84a021ba36893D665a0) |
| 2 | T1 | ETH / USDT | `updateOracle(address)` | [0x1135AEe2779243D484ccC43779472a006b055025](https://etherscan.io/address/0x1135AEe2779243D484ccC43779472a006b055025) |
| 3 | T1 | wstETH / ETH | `updateOracle(address)` | [0x4D668241360F46772936d546c359725B40351121](https://etherscan.io/address/0x4D668241360F46772936d546c359725B40351121) |
| 4 | T1 | wstETH / USDC | `updateOracle(address)` | [0x2717ee42385A885B782EBe8F8Fb51a52089F329B](https://etherscan.io/address/0x2717ee42385A885B782EBe8F8Fb51a52089F329B) |
| 5 | T1 | wstETH / USDT | `updateOracle(address)` | [0x54aC7717A99f6Da579EC494228E0C7265e401d70](https://etherscan.io/address/0x54aC7717A99f6Da579EC494228E0C7265e401d70) |
| 6 | T1 | weETH / wstETH | `updateOracle(address)` | [0xeCaf60b6a0b78d6b358571db11e710f9984799dD](https://etherscan.io/address/0xeCaf60b6a0b78d6b358571db11e710f9984799dD) |
| 7 | T1 | sUSDe / USDC | `updateOracle(address)` | [0xfD8a38040066F2B698Cb31BdCdf4c14C1Ce67dfc](https://etherscan.io/address/0xfD8a38040066F2B698Cb31BdCdf4c14C1Ce67dfc) |
| 8 | T1 | sUSDe / USDT | `updateOracle(address)` | [0x3b94a4Cd158eDFdE61168721D15FFC00EbBF1bF6](https://etherscan.io/address/0x3b94a4Cd158eDFdE61168721D15FFC00EbBF1bF6) |
| 9 | T1 | weETH / USDC | `updateOracle(address)` | [0xe374C831e4823fd816f3F7E225fa97Ee0E7F6190](https://etherscan.io/address/0xe374C831e4823fd816f3F7E225fa97Ee0E7F6190) |
| 10 | T1 | weETH / USDT | `updateOracle(address)` | [0xD4399875b8627fa728C9BEaeeD775734b4982637](https://etherscan.io/address/0xD4399875b8627fa728C9BEaeeD775734b4982637) |
| 11 | T1 | ETH / USDC | `updateOracle(address)` | [0x0EA882896270BF090647015259ce1c038380F160](https://etherscan.io/address/0x0EA882896270BF090647015259ce1c038380F160) |
| 12 | T1 | ETH / USDT | `updateOracle(address)` | [0x412bF8592Dc48Cce76a2F6313a565719d5Db4D0C](https://etherscan.io/address/0x412bF8592Dc48Cce76a2F6313a565719d5Db4D0C) |
| 13 | T1 | wstETH / ETH | `updateOracle(address)` | [0x621Aa6407f9e79bA342559ae48430A17f1CDfD7E](https://etherscan.io/address/0x621Aa6407f9e79bA342559ae48430A17f1CDfD7E) |
| 14 | T1 | wstETH / USDC | `updateOracle(address)` | [0xfd11fB5207D586f8B39b9855beb46cbF8d016d0d](https://etherscan.io/address/0xfd11fB5207D586f8B39b9855beb46cbF8d016d0d) |
| 15 | T1 | wstETH / USDT | `updateOracle(address)` | [0x59a5019FEdc5751318Ae3914C7CFf7922515e83d](https://etherscan.io/address/0x59a5019FEdc5751318Ae3914C7CFf7922515e83d) |
| 16 | T1 | weETH / wstETH | `updateOracle(address)` | [0xf4A1D5c75d00Cf4Eb9d14B95b69c7f50E5582575](https://etherscan.io/address/0xf4A1D5c75d00Cf4Eb9d14B95b69c7f50E5582575) |
| 17 | T1 | sUSDe / USDC | `updateOracle(address)` | [0x75216a2C68014D752F61775eaeDaB19D5eDf0B7D](https://etherscan.io/address/0x75216a2C68014D752F61775eaeDaB19D5eDf0B7D) |
| 18 | T1 | sUSDe / USDT | `updateOracle(address)` | [0x8869a4a0335313Aa3746d0FEEDEa3eF18C71BAcf](https://etherscan.io/address/0x8869a4a0335313Aa3746d0FEEDEa3eF18C71BAcf) |
| 19 | T1 | weETH / USDC | `updateOracle(address)` | [0xe9de88Bed191E02eF90a6dCb2AB907FC329bd83c](https://etherscan.io/address/0xe9de88Bed191E02eF90a6dCb2AB907FC329bd83c) |
| 20 | T1 | weETH / USDT | `updateOracle(address)` | [0x1F6F02deEad88eA96c0952a3E3A519c66770e6a4](https://etherscan.io/address/0x1F6F02deEad88eA96c0952a3E3A519c66770e6a4) |
| 21 | T1 | WBTC / USDC | `updateOracle(address)` | [0x884F600DcCEd547682654175ED40bA7cA13A89F9](https://etherscan.io/address/0x884F600DcCEd547682654175ED40bA7cA13A89F9) |
| 22 | T1 | WBTC / USDT | `updateOracle(address)` | [0x79E56996b3ded9AaDfB1E03707A2CCE98c4bE65b](https://etherscan.io/address/0x79E56996b3ded9AaDfB1E03707A2CCE98c4bE65b) |
| 23 | T1 | WBTC / ETH | `updateOracle(address)` | [0x3966DA1DE03767a6367da01866C385290447F78e](https://etherscan.io/address/0x3966DA1DE03767a6367da01866C385290447F78e) |
| 24 | T1 | ETH / WBTC | `updateOracle(address)` | [0x025108DBE9d7753A1d5f08fc7101dBF577E1EaF8](https://etherscan.io/address/0x025108DBE9d7753A1d5f08fc7101dBF577E1EaF8) |
| 25 | T1 | wstETH / WBTC | `updateOracle(address)` | [0xC75f79ED280771b17a3f0281B1A09FADc341f12c](https://etherscan.io/address/0xC75f79ED280771b17a3f0281B1A09FADc341f12c) |
| 26 | T1 | weETH / WBTC | `updateOracle(address)` | [0xf55b928910FBf7de8a91b81d77813d38CF2dfd86](https://etherscan.io/address/0xf55b928910FBf7de8a91b81d77813d38CF2dfd86) |
| 28 | T1 | cbBTC / ETH | `updateOracle(address)` | [0xc2044f08D715F215cAa136c81D474AADCd32cd83](https://etherscan.io/address/0xc2044f08D715F215cAa136c81D474AADCd32cd83) |
| 29 | T1 | cbBTC / USDC | `updateOracle(address)` | [0x0481e1B3dAe9F8E5a58D71e9dC5e8988c98f8b74](https://etherscan.io/address/0x0481e1B3dAe9F8E5a58D71e9dC5e8988c98f8b74) |
| 30 | T1 | cbBTC / USDT | `updateOracle(address)` | [0xA5494971C8bF3f0E90Aab913D81306cB985D3d23](https://etherscan.io/address/0xA5494971C8bF3f0E90Aab913D81306cB985D3d23) |
| 31 | T1 | ETH / cbBTC | `updateOracle(address)` | [0x08FF2E2826B2eed907b780c512dE1b88a6aeD0d3](https://etherscan.io/address/0x08FF2E2826B2eed907b780c512dE1b88a6aeD0d3) |
| 32 | T1 | weETH / cbBTC | `updateOracle(address)` | [0x6BB4b190a7C8a6D76d7dD5F4408962e68109E149](https://etherscan.io/address/0x6BB4b190a7C8a6D76d7dD5F4408962e68109E149) |
| 33 | T1 | wstETH / cbBTC | `updateOracle(address)` | [0x494EBb94D38Ad09e6E3456A45f0a5083A5DE3042](https://etherscan.io/address/0x494EBb94D38Ad09e6E3456A45f0a5083A5DE3042) |
| 44 | T4 | wstETH-ETH / wstETH-ETH | `updateOracle(317)` | [0xCB7672B4F4749fE2166eb7f0a384ED31B637Ae63](https://etherscan.io/address/0xCB7672B4F4749fE2166eb7f0a384ED31B637Ae63) |
| 45 | T3 | ETH / USDC-USDT | `updateOracle(318)` | [0x1E3e6Fe5A4Ea96f6B438eDCbd4e14af9C565F7e1](https://etherscan.io/address/0x1E3e6Fe5A4Ea96f6B438eDCbd4e14af9C565F7e1) |
| 46 | T3 | wstETH / USDC-USDT | `updateOracle(319)` | [0xE1F99A74f1B6e69C16D778d877fdD84465F4f02b](https://etherscan.io/address/0xE1F99A74f1B6e69C16D778d877fdD84465F4f02b) |
| 47 | T3 | weETH / USDC-USDT | `updateOracle(320)` | [0xA61af44f1102bCB0695984eEa5d8c7D28AdDe34D](https://etherscan.io/address/0xA61af44f1102bCB0695984eEa5d8c7D28AdDe34D) |
| 48 | T3 | WBTC / USDC-USDT | `updateOracle(321)` | [0x8824271D987c8485B0f869Ca4830760b82D518C0](https://etherscan.io/address/0x8824271D987c8485B0f869Ca4830760b82D518C0) |
| 49 | T3 | cbBTC / USDC-USDT | `updateOracle(322)` | [0x5d4B956837Dc43B18B5B837a7F7Af96e78B1070d](https://etherscan.io/address/0x5d4B956837Dc43B18B5B837a7F7Af96e78B1070d) |
| 50 | T3 | sUSDe / USDC-USDT | `updateOracle(323)` | [0xFF4b3A61ad10286cC258D0141151804D3C4CB224](https://etherscan.io/address/0xFF4b3A61ad10286cC258D0141151804D3C4CB224) |
| 51 | T4 | WBTC-cbBTC / WBTC-cbBTC | `updateOracle(324)` | [0x26e703D12A2B29f8ACDC5BDd1408edFE4b67CADF](https://etherscan.io/address/0x26e703D12A2B29f8ACDC5BDd1408edFE4b67CADF) |
| 52 | T2 | WBTC-cbBTC / USDC | `updateOracle(325)` | [0x6d9f4e1D20408f964F80Cb2d285a3cCF1a9cb02C](https://etherscan.io/address/0x6d9f4e1D20408f964F80Cb2d285a3cCF1a9cb02C) |
| 53 | T2 | WBTC-cbBTC / USDT | `updateOracle(326)` | [0x8C6C6c423D5d5c28cD95147E28824514cA42038E](https://etherscan.io/address/0x8C6C6c423D5d5c28cD95147E28824514cA42038E) |
| 54 | T1 | ETH / GHO | `updateOracle(address)` | [0x6b8180FB1936b3FF9C991ef73aD573Bb889084f6](https://etherscan.io/address/0x6b8180FB1936b3FF9C991ef73aD573Bb889084f6) |
| 55 | T1 | wstETH / GHO | `updateOracle(address)` | [0x9e745358EEA03c29ADA97c5f3902fcFE50f3d9f6](https://etherscan.io/address/0x9e745358EEA03c29ADA97c5f3902fcFE50f3d9f6) |
| 56 | T1 | sUSDe / GHO | `updateOracle(address)` | [0x0309D04780372A3bbE55D39C8D228C8115974713](https://etherscan.io/address/0x0309D04780372A3bbE55D39C8D228C8115974713) |
| 57 | T1 | weETH / GHO | `updateOracle(address)` | [0x91F5bb96691308e64a04Ff6aE51202709434884e](https://etherscan.io/address/0x91F5bb96691308e64a04Ff6aE51202709434884e) |
| 59 | T1 | WBTC / GHO | `updateOracle(address)` | [0x38350Afa67103008c3a0B364868B7b895F6334C3](https://etherscan.io/address/0x38350Afa67103008c3a0B364868B7b895F6334C3) |
| 60 | T1 | cbBTC / GHO | `updateOracle(address)` | [0x727A2E0bB9E4dC200dD05aFF1221ed2608f2dcbC](https://etherscan.io/address/0x727A2E0bB9E4dC200dD05aFF1221ed2608f2dcbC) |
| 61 | T4 | GHO-USDC / GHO-USDC | `updateOracle(333)` | [0x26a3Dc740e84868fd1A55ae4D630Bf03d972c46e](https://etherscan.io/address/0x26a3Dc740e84868fd1A55ae4D630Bf03d972c46e) |
| 74 | T2 | weETH-ETH / wstETH | `updateOracle(334)` | [0xF1CAAf544c52735Ac9134a5c28bD448250acb184](https://etherscan.io/address/0xF1CAAf544c52735Ac9134a5c28bD448250acb184) |
| 88 | T1 | tBTC / USDC | `updateOracle(address)` | [0x1Bd11AADF256a3B0F6Bd40957a48D03C3eA7e171](https://etherscan.io/address/0x1Bd11AADF256a3B0F6Bd40957a48D03C3eA7e171) |
| 89 | T1 | tBTC / USDT | `updateOracle(address)` | [0x7dc14c977D9381cf52CC0E2245154b4dCbDaC868](https://etherscan.io/address/0x7dc14c977D9381cf52CC0E2245154b4dCbDaC868) |
| 90 | T1 | tBTC / GHO | `updateOracle(address)` | [0x2fE174d63518CF421CD27eB0EDae7E868BFbfb89](https://etherscan.io/address/0x2fE174d63518CF421CD27eB0EDae7E868BFbfb89) |
| 92 | T2 | sUSDe-USDT / USDT | `updateOracle(338)` | [0x137De2135aF0bae83501Ff63ab0718073a99AA92](https://etherscan.io/address/0x137De2135aF0bae83501Ff63ab0718073a99AA92) |
| 93 | T2 | USDe-USDT / USDT | `updateOracle(339)` | [0x2c8468eA6807339a145021280a8DFb3eCb77c908](https://etherscan.io/address/0x2c8468eA6807339a145021280a8DFb3eCb77c908) |
| 94 | T1 | eBTC / WBTC | `updateOracle(address)` | [0x70e4568830aD14d4cAf843b0D351B788774B2bf0](https://etherscan.io/address/0x70e4568830aD14d4cAf843b0D351B788774B2bf0) |
| 96 | T2 | eBTC-cbBTC / WBTC | `updateOracle(341)` | [0x7EA45c628A26F98b6A65393821FeacE41f58f0FC](https://etherscan.io/address/0x7EA45c628A26F98b6A65393821FeacE41f58f0FC) |
| 97 | T2 | LBTC-cbBTC / WBTC | `updateOracle(342)` | [0x12f33aD40835142B4e8fd314ed5EAE782e586dD8](https://etherscan.io/address/0x12f33aD40835142B4e8fd314ed5EAE782e586dD8) |
| 98 | T4 | sUSDe-USDT / USDC-USDT | `updateOracle(343)` | [0xD2Be3280A56db3B0ED7DD492fA36186818C682F8](https://etherscan.io/address/0xD2Be3280A56db3B0ED7DD492fA36186818C682F8) |
| 99 | T4 | USDe-USDT / USDC-USDT | `updateOracle(344)` | [0x708D59f2aD936fB54d82C4f6A0e05B2EE55f6846](https://etherscan.io/address/0x708D59f2aD936fB54d82C4f6A0e05B2EE55f6846) |
| 100 | T1 | USDC / ETH | `updateOracle(address)` | [0x8f316becf3E47F7D368fa78d621621F5C71bafd7](https://etherscan.io/address/0x8f316becf3E47F7D368fa78d621621F5C71bafd7) |
| 101 | T1 | USDC / WBTC | `updateOracle(address)` | [0x7C0CF242Eab0A497b62E56e419B6E030787C9D44](https://etherscan.io/address/0x7C0CF242Eab0A497b62E56e419B6E030787C9D44) |
| 102 | T1 | USDC / cbBTC | `updateOracle(address)` | [0x1070d57A8E2cd0E3A5851134e17f018D286f058f](https://etherscan.io/address/0x1070d57A8E2cd0E3A5851134e17f018D286f058f) |
| 107 | T1 | LBTC / USDC | `updateOracle(address)` | [0xc9807f6Dc16872df9A3cD0b19935C35B13129bD5](https://etherscan.io/address/0xc9807f6Dc16872df9A3cD0b19935C35B13129bD5) |
| 108 | T1 | LBTC / USDT | `updateOracle(address)` | [0x8bD8094352ba9b769aAA49A31f646227dcACa4F4](https://etherscan.io/address/0x8bD8094352ba9b769aAA49A31f646227dcACa4F4) |
| 109 | T1 | LBTC / GHO | `updateOracle(address)` | [0x9a9E53aE3e56C105187A9Cd195D8B5AB0C60Be6C](https://etherscan.io/address/0x9a9E53aE3e56C105187A9Cd195D8B5AB0C60Be6C) |
| 114 | T2 | LBTC-cbBTC / cbBTC | `updateOracle(351)` | [0x4288DF203D9B091429fe3CA8dfF776DCa374E836](https://etherscan.io/address/0x4288DF203D9B091429fe3CA8dfF776DCa374E836) |
| 115 | T2 | WBTC-LBTC / WBTC | `updateOracle(352)` | [0x23b9ff5a3100c8E30Dd185D58f75515f5373A958](https://etherscan.io/address/0x23b9ff5a3100c8E30Dd185D58f75515f5373A958) |
| 116 | T1 | XAUt / USDC | `updateOracle(address)` | [0x3c872d45Ca49eabbD39Ad6BDe69F3C040839C99D](https://etherscan.io/address/0x3c872d45Ca49eabbD39Ad6BDe69F3C040839C99D) |
| 117 | T1 | XAUt / USDT | `updateOracle(address)` | [0xB33121EC411D1a2b67acD5d650013E905B3B2e0D](https://etherscan.io/address/0xB33121EC411D1a2b67acD5d650013E905B3B2e0D) |
| 118 | T1 | XAUt / GHO | `updateOracle(address)` | [0x48Eb4312D42875E20D59Dc87eC1D5D895a89adE8](https://etherscan.io/address/0x48Eb4312D42875E20D59Dc87eC1D5D895a89adE8) |
| 119 | T1 | PAXG / USDC | `updateOracle(address)` | [0x2a4090a7bFf6df8F7a021439bf6fbed7a0416f1b](https://etherscan.io/address/0x2a4090a7bFf6df8F7a021439bf6fbed7a0416f1b) |
| 120 | T1 | PAXG / USDT | `updateOracle(address)` | [0xCDDFBfC30aF7F4d8dA8C2A0adB25ff0A6eA2da73](https://etherscan.io/address/0xCDDFBfC30aF7F4d8dA8C2A0adB25ff0A6eA2da73) |
| 121 | T1 | PAXG / GHO | `updateOracle(address)` | [0xB3dB50A5da5009cAFB603F87d72fd24f561a0D63](https://etherscan.io/address/0xB3dB50A5da5009cAFB603F87d72fd24f561a0D63) |
| 122 | T2 | PAXG-XAUt / USDC | `updateOracle(359)` | [0x1515117B98cf3b508403Cfe22f8c06C29Bd5a330](https://etherscan.io/address/0x1515117B98cf3b508403Cfe22f8c06C29Bd5a330) |
| 123 | T2 | PAXG-XAUt / USDT | `updateOracle(360)` | [0x4ad6749644DD567D58e52238313F9DA07cCf55D9](https://etherscan.io/address/0x4ad6749644DD567D58e52238313F9DA07cCf55D9) |
| 124 | T2 | PAXG-XAUt / GHO | `updateOracle(361)` | [0xC94FBAecc4F14a3E44721Bc034ec0e85F2A0a9AC](https://etherscan.io/address/0xC94FBAecc4F14a3E44721Bc034ec0e85F2A0a9AC) |
| 125 | T4 | GHO-sUSDe / GHO-USDC | `updateOracle(362)` | [0xE746d1514C406d6bFed03b62C76Dcb1E95C0ff90](https://etherscan.io/address/0xE746d1514C406d6bFed03b62C76Dcb1E95C0ff90) |
| 126 | T4 | sUSDe-USDT / USDC-USDT | `updateOracle(363)` | [0xEdEeb06B09172c98A1F09a369EB42851Ba8D7F82](https://etherscan.io/address/0xEdEeb06B09172c98A1F09a369EB42851Ba8D7F82) |
| 127 | T4 | USDe-USDT / USDC-USDT | `updateOracle(364)` | [0x6c1567a725545aC4dd045a0F08F6A60e2Ee99459](https://etherscan.io/address/0x6c1567a725545aC4dd045a0F08F6A60e2Ee99459) |
| 128 | T1 | ETH / USDtb | `updateOracle(address)` | [0x74A2989f000464fF2333413180909222718C6317](https://etherscan.io/address/0x74A2989f000464fF2333413180909222718C6317) |
| 129 | T1 | wstETH / USDtb | `updateOracle(address)` | [0xA21298B7Dcfa0A850a624820F76C578EC8a92a0f](https://etherscan.io/address/0xA21298B7Dcfa0A850a624820F76C578EC8a92a0f) |
| 130 | T1 | weETH / USDtb | `updateOracle(address)` | [0x19C64cD86b5612e5151129475028C486babf3e8f](https://etherscan.io/address/0x19C64cD86b5612e5151129475028C486babf3e8f) |
| 131 | T1 | WBTC / USDtb | `updateOracle(address)` | [0x38A65816b32Cf5afc0d5f97fcFC28ebDF6F71f97](https://etherscan.io/address/0x38A65816b32Cf5afc0d5f97fcFC28ebDF6F71f97) |
| 132 | T1 | cbBTC / USDtb | `updateOracle(address)` | [0xe5b05e2D6d6004AFdbAa0a50575C93DbFeFca8aC](https://etherscan.io/address/0xe5b05e2D6d6004AFdbAa0a50575C93DbFeFca8aC) |
| 137 | T2 | USDe-USDtb / USDT | `updateOracle(370)` | [0xAD5aA9c27b04c36B21F53e5aCf1Cc198739f2E87](https://etherscan.io/address/0xAD5aA9c27b04c36B21F53e5aCf1Cc198739f2E87) |
| 138 | T2 | USDe-USDtb / USDC | `updateOracle(371)` | [0xd696a005dB0A3402aF7c67650C228CfE2Ad79D04](https://etherscan.io/address/0xd696a005dB0A3402aF7c67650C228CfE2Ad79D04) |
| 139 | T4 | GHO-USDe / GHO-USDC | `updateOracle(372)` | [0x514A07cFF37A06ea093d8bd039c860779aC37F21](https://etherscan.io/address/0x514A07cFF37A06ea093d8bd039c860779aC37F21) |
| 140 | T2 | USDe-USDtb / GHO | `updateOracle(373)` | [0x5831BA648D2B3d86A9aa9A86B2972D4Fa8C484Ff](https://etherscan.io/address/0x5831BA648D2B3d86A9aa9A86B2972D4Fa8C484Ff) |
| 141 | T2 | GHO-USDe / GHO | `updateOracle(374)` | [0x88cBeE210F539bb1301e64b1971aBfcd8ED83E7e](https://etherscan.io/address/0x88cBeE210F539bb1301e64b1971aBfcd8ED83E7e) |
| 145 | T2 | syrupUSDC-USDC / USDC | `updateOracle(375)` | [0xf6154fd987CBc603C285b5D1676329CadcC3d2a6](https://etherscan.io/address/0xf6154fd987CBc603C285b5D1676329CadcC3d2a6) |
| 146 | T1 | syrupUSDC / USDC | `updateOracle(address)` | [0x0d990D135C7f242fA10837BB08821F43f28C6A8f](https://etherscan.io/address/0x0d990D135C7f242fA10837BB08821F43f28C6A8f) |
| 147 | T1 | syrupUSDC / USDT | `updateOracle(address)` | [0x1BC63Cc2C4b0FB18533d64834eE04755a5469614](https://etherscan.io/address/0x1BC63Cc2C4b0FB18533d64834eE04755a5469614) |
| 148 | T1 | syrupUSDC / GHO | `updateOracle(address)` | [0xB5397E17aA9253d2041ce49A7f0F0F83C214D909](https://etherscan.io/address/0xB5397E17aA9253d2041ce49A7f0F0F83C214D909) |
| 149 | T2 | syrupUSDT-USDT / USDT | `updateOracle(379)` | [0x19b44A3Fb8Fe482a76c379372b5e891eC2B4ad26](https://etherscan.io/address/0x19b44A3Fb8Fe482a76c379372b5e891eC2B4ad26) |
| 150 | T1 | syrupUSDT / USDC | `updateOracle(address)` | [0x12f24A66a044879439446b80Cc8A1Df9D32A7bec](https://etherscan.io/address/0x12f24A66a044879439446b80Cc8A1Df9D32A7bec) |
| 151 | T1 | syrupUSDT / USDT | `updateOracle(address)` | [0x2b06813316Fc3815411417ccD932DC0Db7431e3C](https://etherscan.io/address/0x2b06813316Fc3815411417ccD932DC0Db7431e3C) |
| 152 | T1 | syrupUSDT / GHO | `updateOracle(address)` | [0xbb622B72065493bAa531BE8eF53768f30C11CACE](https://etherscan.io/address/0xbb622B72065493bAa531BE8eF53768f30C11CACE) |
| 160 | T1 | reUSD / USDC | `updateOracle(address)` | [0xE2194E8aF233a9096587302414ce270cE60ABD77](https://etherscan.io/address/0xE2194E8aF233a9096587302414ce270cE60ABD77) |
| 161 | T1 | reUSD / USDT | `updateOracle(address)` | [0xd8DDC3f55102699224316fCd595fc516d4c04F78](https://etherscan.io/address/0xd8DDC3f55102699224316fCd595fc516d4c04F78) |
| 162 | T1 | reUSD / GHO | `updateOracle(address)` | [0x8FCF66E43C27203C047FE1CdD0564353920D49f5](https://etherscan.io/address/0x8FCF66E43C27203C047FE1CdD0564353920D49f5) |
| 163 | T3 | reUSD / USDC-USDT | `updateOracle(392)` | [0xb8Be0f1059fAC10DEa4aBADbeC9C19174daF255d](https://etherscan.io/address/0xb8Be0f1059fAC10DEa4aBADbeC9C19174daF255d) |
| 164 | T2 | reUSD-USDT / USDT | `updateOracle(393)` | [0xCEAB3a5E1B719F3DdEf661265e94257A7046ab1a](https://etherscan.io/address/0xCEAB3a5E1B719F3DdEf661265e94257A7046ab1a) |
| 165 | T1 | PST / USDC | `updateOracle(address)` | [0x8ad24a1ed3047EAe302A6a4D2ba6AfBBA9b89A8f](https://etherscan.io/address/0x8ad24a1ed3047EAe302A6a4D2ba6AfBBA9b89A8f) |
| 166 | T1 | PST / USDT | `updateOracle(address)` | [0x007F6F477d8Cbc8e821ceB06613879099d28b8E5](https://etherscan.io/address/0x007F6F477d8Cbc8e821ceB06613879099d28b8E5) |
| 168 | T3 | PST / USDC-USDT | `updateOracle(396)` | [0x0CE7A5557a741ac234276a156D13a2B710A0180B](https://etherscan.io/address/0x0CE7A5557a741ac234276a156D13a2B710A0180B) |
| 169 | T4 | PST-USDC / USDC-USDT | `updateOracle(397)` | [0x03b709554aD54CB09C7Fc270B5b9fdCb7b04aeF9](https://etherscan.io/address/0x03b709554aD54CB09C7Fc270B5b9fdCb7b04aeF9) |
| 170 | T4 | reUSD-USDT / USDC-USDT | `updateOracle(398)` | [0xFfC7cE6FA3fc986422619d7290d7D6d4AD3621B0](https://etherscan.io/address/0xFfC7cE6FA3fc986422619d7290d7D6d4AD3621B0) |
| 171 | T1 | sUSDai / USDC | `updateOracle(address)` | [0x4A84C4302Ab24F44Ea31CF237A576d85aE89CD13](https://etherscan.io/address/0x4A84C4302Ab24F44Ea31CF237A576d85aE89CD13) |
| 172 | T1 | sUSDai / USDT | `updateOracle(address)` | [0xb390f9868e46852b2A9D2C76745A6A8F40938aC8](https://etherscan.io/address/0xb390f9868e46852b2A9D2C76745A6A8F40938aC8) |
| 173 | T3 | sUSDai / USDC-USDT | `updateOracle(401)` | [0x5df9B8E3E04AAead7831fC7270e4D7563f5Dc3E7](https://etherscan.io/address/0x5df9B8E3E04AAead7831fC7270e4D7563f5Dc3E7) |
| 175 | T4 | sUSDai-USDC / USDC-USDT | `updateOracle(402)` | [0x2eEA9766B77F7CcD96F109eDc4C32D9a2bAFE7E7](https://etherscan.io/address/0x2eEA9766B77F7CcD96F109eDc4C32D9a2bAFE7E7) |
| 176 | T4 | sUSDai-USDT / USDC-USDT | `updateOracle(403)` | [0x0c3280E62E00De742F635e27C79C1a064BeF795B](https://etherscan.io/address/0x0c3280E62E00De742F635e27C79C1a064BeF795B) |
| 177 | T2 | sUSDai-USDT / USDT | `updateOracle(404)` | [0xf2dD153Ce5D3A57fE543fdebAa1f1B92BD095f23](https://etherscan.io/address/0xf2dD153Ce5D3A57fE543fdebAa1f1B92BD095f23) |
| 178 | T2 | sUSDai-USDC / USDC | `updateOracle(405)` | [0x6A5478448e8e9B476eB1B4eD0165c603270B4041](https://etherscan.io/address/0x6A5478448e8e9B476eB1B4eD0165c603270B4041) |
| 179 | T1 | sUSDai / GHO | `updateOracle(address)` | [0xd68534c98Bd3F595645152454D27E01323D2AEc4](https://etherscan.io/address/0xd68534c98Bd3F595645152454D27E01323D2AEc4) |
| 180 | T2 | USDai-USDC / USDC | `updateOracle(407)` | [0xd5e0C179363AFf28778502A08B3dC44fEa733Ddc](https://etherscan.io/address/0xd5e0C179363AFf28778502A08B3dC44fEa733Ddc) |
| 181 | T3 | reUSD / GHO-USDC | `updateOracle(408)` | [0x2FA6575A3C62Ca1546cB6480a272075F5F95dC14](https://etherscan.io/address/0x2FA6575A3C62Ca1546cB6480a272075F5F95dC14) |
| 182 | T1 | weETH / ETH | `updateOracle(address)` | [0x1D15D001Ea51AdaC16277D75286D338C005eAdBa](https://etherscan.io/address/0x1D15D001Ea51AdaC16277D75286D338C005eAdBa) |

## Description

The DexV2 and Money Market have run on the Liquidity Layer with $50k limits since IGP-141. This proposal moves them to their launch limits and adds cbBTC and wstETH (plus FLUID supply on the DexV2), so both can open to all users. The base limits are available immediately. Above the base, the borrow limit grows with usage, by up to 50% of current borrows over 6 hours, until it reaches each token's ceiling.

The ETH/FLUID Fluid Dex V1 position (NFT #3192) moves to the Team Multisig so the team can adjust the position directly. It can be transferred back to the Treasury once the adjustments are done.

The first-generation DexV2 and Money Market proxies were replaced in IGP-141 but kept their Liquidity Layer limits (about $50k to $78k per token). Nothing is supplied or borrowed through them, so this closes the unused limits.

OracleV2 is already live on 6 Ethereum vaults (IGP-142). Action 4 moves the remaining 119 registered vaults to it, so all of them price through OracleV2.

## Conclusion

IGP-144 sets $5M base withdrawal and borrow limits for ETH, USDC, USDT, WBTC, cbBTC and wstETH on the DexV2 and Money Market proxies, with borrow ceilings of $30M, $15M and $5M and a 50% / 6h expansion, sets a $5M base withdrawal limit for FLUID on the DexV2 proxy, transfers the ETH/FLUID Fluid Dex V1 position (NFT #3192) from the Treasury to the Team Multisig, restricts and pauses the old DexV2 and Money Market proxies at the Liquidity Layer, and makes OracleV2 fully live by switching 119 vaults to their OracleV2 oracles.
