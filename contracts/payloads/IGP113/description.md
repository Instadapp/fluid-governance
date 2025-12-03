# Update WEETH Fee Handler, Upgrade Liquidity Layer Modules, Set OSETH Protocol Dust Limits, Configure DEX v2 and Money Market Dust Limits, and Increase LBTC-cbBTC/WBTC Borrow Caps

## Summary

This proposal implements five key protocol upgrades: (1) updates the WEETH fee handler on DexFactory by removing the old handler and adding the new one, (2) upgrades Liquidity Layer AdminModule and UserModule to add decay limits and other improvements already rolled out on Base, Arbitrum, Polygon, (3) sets conservative dust limits for OSETH protocols including the OSETH-ETH DEX and six associated vaults, (4) configures dust supply and borrow limits for DEX v2 and Money Market proxies at the Liquidity Layer, and (5) increases borrow caps for the LBTC-cbBTC/WBTC vault to support increased usage. These changes aim to maintain operational efficiency through fee handler updates, enhance protocol functionality with upgraded modules, safely integrate new OSETH offerings with appropriate limits, establish foundational limits for new proxy contracts, and optimize existing vault capacity.

## Code Changes

### Action 1: Update WEETH Fee Handler on DexFactory

- **WEETH DEX (ID 9)**:
  - **Old Fee Handler**: `0x8eaE5474C3DFE2c5F07E7423019E443258A73100` (removed as auth)
  - **New Fee Handler**: `0xD43d85f4F4eEDdA3ed3BbE2Ca7351eE32b8bB44a` (added as auth)
  - **Purpose**: Update fee handler authorization for WEETH DEX to maintain proper fee collection mechanisms

### Action 2: Upgrade Liquidity Layer AdminModule and UserModule

- **UserModule Upgrade**:
  - **Old Implementation**: `0x6967e68F7f9b3921181f27E66Aa9c3ac7e13dBc0`
  - **New Implementation**: `0xF1167F851509CA5Ef56f8521fB1EE07e4e5C92C8`
  - **Purpose**: Upgrade UserModule with decay limits and other improvements, same as already rolled out on Base, Arbitrum, Polygon

- **AdminModule Upgrade**:
  - **Old Implementation**: `0xC3800E7527145837e525cfA6AD96B6B5DaE01586`
  - **New Implementation**: `0x53EFFA0e612d88f39Ab32eb5274F2fae478d261C`
  - **Purpose**: Upgrade AdminModule with decay limits and other improvements, same as already rolled out on Base, Arbitrum, Polygon
  - **Note**: Signatures are preserved from old implementation via on-chain code reading

### Action 3: Set Dust Limits for OSETH Protocols

- **DEX Pool 43**<br>
  **OSETH-ETH DEX**:
  - **Base Withdrawal Limit**: $10,000
  - **Base Borrow Limit**: $0
  - **Max Borrow Limit**: $0
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Authorization**: Add Team Multisig auth

- **Vault ID 153**<br>
  **OSETH/USDC (TYPE 1)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

- **Vault ID 154**<br>
  **OSETH/USDT (TYPE 1)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

- **Vault ID 155**<br>
  **OSETH/GHO (TYPE 1)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

- **Vault ID 156**<br>
  **OSETH/USDC-USDT (TYPE 3)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: Set at DEX level (USDC-USDT DEX, ID 2)
  - **DEX Borrow Limit**: 3,500 shares ($7k) base, 4,500 shares ($9k) max
  - **Authorization**: Add Team Multisig auth

- **Vault ID 157**<br>
  **OSETH/USDC-USDT Concentrated (TYPE 3)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: Set at DEX level (USDC-USDT Concentrated DEX, ID 34)
  - **DEX Borrow Limit**: 3,500 shares ($7k) base, 4,500 shares ($9k) max
  - **Authorization**: Add Team Multisig auth

- **Vault ID 158**<br>
  **oseth-eth <> wsteth-eth (TYPE 4)**:
  - **Base Borrow Limit**: Set at DEX level (wstETH-ETH DEX, ID 1)
  - **DEX Borrow Limit**: 1 share ($6k) base, 1.5 shares ($9k) max
  - **Purpose**: Configure borrow dust limits for OSETH-ETH position borrowing against wstETH-ETH DEX

### Action 4: Set Dust Limits for DEX v2 and Money Market Proxies

- **Protocol Addresses**:
  - **DEX v2 Proxy**: `0x4E42f9e626FAcDdd97EDFA537AA52C5024448625`
  - **Money Market Proxy**: `0xe3B7e3f4da603FC40fD889caBdEe30a4cf15DD34`

- **Borrow (Debt) Limits**:
  - **Tokens**: ETH, USDC, USDT
  - **Base Borrow Limit**: $5,000 per token
  - **Max Borrow Limit**: $10,000 per token
  - **Expand Percent**: 30%
  - **Expand Duration**: 6 hours
  - **Applied to**: Both DEX v2 and Money Market proxies

- **Supply (Collateral) Limits**:
  - **Tokens**: ETH, USDC, USDT, cbBTC, WBTC
  - **Base Withdrawal Limit**: $10,000 per token
  - **Expand Percent**: 50%
  - **Expand Duration**: 6 hours
  - **Applied to**: Both DEX v2 and Money Market proxies

### Action 5: Increase Borrow Caps on LBTC-cbBTC/WBTC Vault

- **Vault ID 97**<br>
  **LBTC-cbBTC/WBTC (TYPE 2)**:
  - **Base Borrow Limit**: $5M (increased from $500k)
  - **Max Borrow Limit**: $5M (increased from $1M)
  - **Purpose**: Support increased borrowing demand for LBTC-cbBTC positions against WBTC

## Description

This proposal implements five major changes to enhance protocol operations, upgrade core infrastructure, integrate new offerings, and optimize existing vault capacity:

1. **WEETH Fee Handler Update**
   - Updates fee handler authorization for WEETH DEX by removing the old handler and adding the new one
   - Ensures proper fee collection mechanisms remain operational
   - Maintains operational efficiency through timely handler updates

2. **Liquidity Layer Module Upgrades**
   - Upgrades both AdminModule and UserModule on the Liquidity infiniteProxy
   - Adds decay limits and other improvements that have already been successfully rolled out on other EVM chains
   - Preserves all existing function signatures via on-chain code reading to ensure compatibility
   - Brings Mainnet Liquidity Layer in line with other EVM chains deployment, ensuring feature parity and improved functionality

3. **OSETH Protocol Integration with Conservative Limits**
   - Introduces OSETH-ETH DEX (Pool 43) and six associated vaults (153-158) with conservative dust limits
   - Sets appropriate withdrawal and borrow limits to ensure safe initial setup and gradual scaling
   - Configures smart collateral functionality while maintaining controlled debt parameters
   - Establishes Team Multisig authorization for proper governance oversight
   - Includes support for both standard and concentrated liquidity pools, as well as cross-DEX borrowing (oseth-eth against wsteth-eth)

4. **DEX v2 and Money Market Proxy Dust Limits**
   - Establishes foundational dust limits for newly deployed DEX v2 and Money Market proxy contracts
   - Sets conservative borrow limits ($5k base, $10k max) for ETH, USDC, and USDT on both proxies
   - Sets conservative supply limits ($10k base) for ETH, USDC, USDT, cbBTC, and WBTC on both proxies
   - Ensures safe initial configuration for new proxy contracts while maintaining operational flexibility
   - Provides appropriate risk management for new protocol integrations

5. **LBTC-cbBTC/WBTC Vault Capacity Enhancement**
   - Increases borrow limits for LBTC-cbBTC/WBTC vault (ID 97) to $5M base and max
   - Supports growing demand for LBTC-cbBTC position borrowing against WBTC
   - Maintains appropriate risk management while expanding capacity

## Conclusion

IGP-113 delivers comprehensive protocol upgrades: it maintains operational efficiency through fee handler updates, enhances core infrastructure with Liquidity Layer module upgrades bringing Mainnet in line with other EVM chains, safely integrates new OSETH offerings with conservative dust limits across DEX and vault configurations, establishes foundational limits for new DEX v2 and Money Market proxy contracts, and optimizes existing vault capacity for LBTC-cbBTC/WBTC. The proposal balances expansion goals with risk management, ensuring safe integration of new markets and infrastructure while maintaining operational efficiency and treasury management best practices. These changes support sustainable growth, improved protocol functionality, and enhanced capital efficiency across the Fluid ecosystem.