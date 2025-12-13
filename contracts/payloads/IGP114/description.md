# Withdraw fGHO Rewards, Set Launch Limits for DEX v2 and Money Market Proxies, and Set Launch Limits for OSETH Protocols

## Summary

This proposal implements three coordinated protocol updates: (1) upgrades the Liquidity Layer UserModule on the Liquidity Infinite Proxy to align and future-proof weETH borrowing behavior, (2) sets operational launch limits for OSETH-related protocols including the OSETH-ETH DEX and associated vaults, and (3) withdraws 2.5M GHO rewards from the treasury’s fGHO position to the Team Multisig. Together, these changes improve Liquidity Layer consistency, scale OSETH protocol usage beyond initial dust limits, and optimize treasury management by transferring accrued rewards for operational use.

## Code Changes

### Action 1: Upgrade LL UserModule on Liquidity infiniteProxy
- **UserModule Upgrade**:
  - **Old Implementation**: `0xF1167F851509CA5Ef56f8521fB1EE07e4e5C92C8`
  - **New Implementation**: Configurable by `Team Multisig` using `setUserModuleAddress()` function, defaults to `0x8bd91778fcF8bcF4e578710C9F5AD9bC852DC103` if not set
  - **Purpose**: Update UserModule with minor check adjustments and future-proof WEETH borrow side support

### Action 2: Set Launch Limits for OSETH Protocols

- **DEX Pool 43**<br>
  **OSETH-ETH DEX**:
  - **Base Withdrawal Limit**: $14,000,000 (for ~30M max supply shares)
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Max Supply Shares**: 5k (~$33M) - target for future configuration
  - **Max Borrow Shares**: 12.5k (~$83M) - target for future borrow functionality  
  - **Token LL Limits (Borrow)**: $85,000,000 each (OSETH and ETH) - target for future configuration
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 153**<br>
  **OSETH/USDC (TYPE 1)**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Base Borrow Limit**: $5,000,000
  - **Max Borrow Limit**: $10,000,000
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 154**<br>
  **OSETH/USDT (TYPE 1)**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Base Borrow Limit**: $5,000,000
  - **Max Borrow Limit**: $10,000,000
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 155**<br>
  **OSETH/GHO (TYPE 1)**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Base Borrow Limit**: $5,000,000
  - **Max Borrow Limit**: $10,000,000
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 156**<br>
  **OSETH/USDC-USDT (TYPE 3)**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Base Borrow Limit**: Set at DEX level (USDC-USDT DEX, ID 2)
  - **DEX Borrow Limit**: ~2.5M shares ($5M) base, ~5M shares ($10M) max
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 157**<br>
  **OSETH/USDC-USDT Concentrated (TYPE 3)**:
  - **Base Withdrawal Limit**: $8,000,000
  - **Base Borrow Limit**: Set at DEX level (USDC-USDT Concentrated DEX, ID 34)
  - **DEX Borrow Limit**: ~2.5M shares ($5M) base, ~5M shares ($10M) max
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 158**<br>
  **oseth-eth <> wsteth-eth (TYPE 4)**:
  - **Base Borrow Limit**: Set at DEX level (wstETH-ETH DEX, ID 1): ~1,333 shares (~$8M) base
  - **Max Borrow Limit**: ~4,700 shares (~$30M) max (capped by max dex shares on wstETH-ETH)
  - **Authorization**: Remove Team Multisig auth
  - **Purpose**: Configure borrow launch limits for OSETH-ETH position borrowing against wstETH-ETH DEX

- **Vault ID 44**<br>
  **wsteth-eth <> wsteth-eth (TYPE 4)**:
  - **Base Borrow Limit**: Set at DEX level (wstETH-ETH DEX, ID 1)
  - **DEX Borrow Limit**: ~3,000 shares (~$20M) base (no change), ~8,100 shares (~$54M) max (reduced from ~12k shares)

- **wstETH-ETH DEX (ID 1) Max Borrow Shares Cap & LL Limits**:
  - **Max Borrow Shares Cap**: Increase to 12,600 shares (from current 8,100 + 4,500 for vaults 44 and 158)
  - **Token LL Borrow Limits**: 
    - **wstETH**: 12,500 shares base, 22,500 shares max (~$85M max)
    - **ETH**: 15,000 shares base, 27,000 shares max (~$85M max)

### Action 3: Withdraw 2.5M GHO Rewards from fGHO to Team Multisig

- **fGHO Contract**: `0x6A29A46E21C730DcA1d8b23d637c101cec605C5B`
- **Withdrawal Amount**: 2.5M GHO
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Method**: Redeem fGHO shares via BASIC-D-V2 connector to withdraw underlying GHO tokens
- **Purpose**: Withdraw accrued rewards from treasury's fGHO position and transfer to Team Multisig


## Description

This proposal implements three major changes to enhance protocol operations, optimize treasury management, and support protocol growth:

1. **Liquidity Layer Module Upgrades**
   - Upgrades UserModule on the Liquidity infiniteProxy
   - New implementation address can be set via `setUserModuleAddress()` function (callable by Team Multisig)
   - Defaults to `0x8bd91778fcF8bcF4e578710C9F5AD9bC852DC103` if no custom address is set
   - Includes minor check adjustments and future-proof WEETH borrow side support

2. **OSETH Protocol Launch Limits**
   - Sets launch limits for OSETH-ETH DEX (Pool 43) and associated vaults (153-158)
   - Scales limits from conservative dust limits (set in IGP113) to operational launch limits
   - Removes Team Multisig authorization from OSETH-ETH DEX and all OSETH vaults (153-158) to enable broader access
   - Supports increased usage and adoption of OSETH protocols
   - Updates wstETH-ETH <> wstETH-ETH vault (ID 44) borrow limits and reduces max borrow from ~12k to ~8.1k shares
   - Increases wstETH-ETH DEX max borrow shares cap to 12,600 shares (to accommodate vaults 44 and 158)
   - Sets Liquidity Layer borrow limits for wstETH-ETH DEX tokens: wstETH (12,500 base / 22,500 max shares) and ETH (15,000 base / 27,000 max shares)
   - Maintains risk management parameters while enabling protocol growth
   - Includes support for both standard and concentrated liquidity pools, as well as cross-DEX borrowing
  
3. **fGHO Rewards Withdrawal**
   - Withdraws 2.5M GHO rewards from treasury's fGHO position
   - Redeems fGHO shares to receive underlying GHO tokens
   - Transfers GHO to Team Multisig for operational use
   - Supports treasury optimization by withdrawing accrued rewards from fGHO positions

## Conclusion

IGP-114 delivers comprehensive protocol upgrades: it optimizes treasury management through fGHO rewards withdrawal, updates across the Liquidity Layer, and supports OSETH protocol growth with increased launch limits. The proposal balances expansion goals with risk management, ensuring safe operational scaling from initial dust limits to launch limits while maintaining operational efficiency and treasury management best practices. These changes support sustainable growth, improved protocol functionality, and enhanced capital efficiency across the Fluid ecosystem.