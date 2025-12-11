# Withdraw fGHO Rewards, Set Launch Limits for DEX v2 and Money Market Proxies, and Set Launch Limits for OSETH Protocols

## Summary

This proposal implements three key protocol upgrades: (1) withdraws 2.5M GHO rewards from fGHO position in treasury to Team Multisig, (2) sets launch limits for DEX v2 and Money Market proxies at higher operational thresholds than the initial dust limits, and (3) sets launch limits for OSETH-related protocols including the OSETH-ETH DEX and associated vaults. These changes aim to optimize treasury management by withdrawing accrued rewards to Team Multisig, enable operational scaling for DEX v2 and Money Market proxies with appropriate launch limits, and support OSETH protocol growth with increased launch limits that scale beyond initial dust limits.

## Code Changes

### Action 1: Withdraw 2.5M GHO Rewards from fGHO to Team Multisig

- **fGHO Contract**: `0x6A29A46E21C730DcA1d8b23d637c101cec605C5B`
- **Withdrawal Amount**: 2.5M GHO
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Redeem fGHO shares via BASIC-D-V2 connector to withdraw underlying GHO tokens
- **Purpose**: Withdraw accrued rewards from treasury's fGHO position and transfer to Team Multisig

### Action 2: Set Launch Limits for DEX v2 and Money Market Proxies

- **Protocols**: DEX v2 Proxy (`0x4E42f9e626FAcDdd97EDFA537AA52C5024448625`) and Money Market Proxy (`0xe3B7e3f4da603FC40fD889caBdEe30a4cf15DD34`)

- **Borrow (Debt) Limits**:
  - **Tokens**: ETH, USDC, USDT
  - **Base Borrow Limit**: $50,000 per token (launch limit, 10x dust limit)
  - **Max Borrow Limit**: $100,000 per token (launch limit, 10x dust limit)
  - **Expand Percent**: 30%
  - **Expand Duration**: 6 hours
  - **Applied to**: Both DEX v2 and Money Market proxies

- **Supply (Collateral) Limits**:
  - **Tokens**: ETH, USDC, USDT, cbBTC, WBTC
  - **Base Withdrawal Limit**: $100,000 per token (launch limit, 10x dust limit)
  - **Expand Percent**: 50%
  - **Expand Duration**: 6 hours
  - **Applied to**: Both DEX v2 and Money Market proxies

### Action 3: Set Launch Limits for OSETH Protocols

- **DEX Pool 43**<br>
  **OSETH-ETH DEX**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled

- **Vault ID 153**<br>
  **OSETH/USDC (TYPE 1)**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Base Borrow Limit**: $5,000,000
  - **Max Borrow Limit**: $10,000,000

- **Vault ID 154**<br>
  **OSETH/USDT (TYPE 1)**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Base Borrow Limit**: $5,000,000
  - **Max Borrow Limit**: $10,000,000

- **Vault ID 155**<br>
  **OSETH/GHO (TYPE 1)**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Base Borrow Limit**: $5,000,000
  - **Max Borrow Limit**: $10,000,000

- **Vault ID 156**<br>
  **OSETH/USDC-USDT (TYPE 3)**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Base Borrow Limit**: Set at DEX level (USDC-USDT DEX, ID 2)
  - **DEX Borrow Limit**: ~2.5M shares ($5M) base, ~5M shares ($10M) max

- **Vault ID 157**<br>
  **OSETH/USDC-USDT Concentrated (TYPE 3)**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Base Borrow Limit**: Set at DEX level (USDC-USDT Concentrated DEX, ID 34)
  - **DEX Borrow Limit**: ~2.5M shares ($5M) base, ~5M shares ($10M) max

- **Vault ID 158**<br>
  **oseth-eth <> wsteth-eth (TYPE 4)**:
  - **Base Borrow Limit**: Set at DEX level (wstETH-ETH DEX, ID 1)
  - **DEX Borrow Limit**: ~1,333 shares (~$8M) base, ~4,167 shares (~$25M) max
  - **Purpose**: Configure borrow launch limits for OSETH-ETH position borrowing against wstETH-ETH DEX

## Description

This proposal implements three major changes to enhance protocol operations, optimize treasury management, and support protocol growth:

1. **fGHO Rewards Withdrawal**
   - Withdraws 2.5M GHO rewards from treasury's fGHO position
   - Redeems fGHO shares to receive underlying GHO tokens
   - Transfers GHO to Team Multisig for operational use
   - Supports treasury optimization by withdrawing accrued rewards from fGHO positions

2. **DEX v2 and Money Market Proxy Launch Limits**
   - Sets operational launch limits for DEX v2 and Money Market proxy contracts
   - Establishes higher thresholds (10x dust limits) to support initial operational scaling
   - Sets borrow limits ($50k base, $100k max) for ETH, USDC, and USDT on both proxies
   - Sets supply limits ($100k base) for ETH, USDC, USDT, cbBTC, and WBTC on both proxies
   - Enables safe operational growth for new proxy contracts beyond initial dust limit constraints
   - Provides appropriate risk management while supporting increased usage

3. **OSETH Protocol Launch Limits**
   - Sets launch limits for OSETH-ETH DEX (Pool 43) and six associated vaults (153-158)
   - Scales limits from conservative dust limits (set in IGP113) to operational launch limits (10x)
   - Supports increased usage and adoption of OSETH protocols
   - Maintains risk management parameters while enabling protocol growth
   - Includes support for both standard and concentrated liquidity pools, as well as cross-DEX borrowing

## Conclusion

IGP-114 delivers comprehensive protocol upgrades: it optimizes treasury management through fGHO rewards withdrawal, enables operational scaling for DEX v2 and Money Market proxies with appropriate launch limits, and supports OSETH protocol growth with increased launch limits. The proposal balances expansion goals with risk management, ensuring safe operational scaling from initial dust limits to launch limits while maintaining operational efficiency and treasury management best practices. These changes support sustainable growth, improved protocol functionality, and enhanced capital efficiency across the Fluid ecosystem.

