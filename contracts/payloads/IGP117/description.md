# DEX V2 Soft Launch, Restrict Limits and Pause Unused wstUSR Markets, Remove Multisig Auth from Old DEXes, and Update syrup DEX Ranges

## Summary
This proposal performs routine protocol maintenance and prepares for DEX V2 launch: (1) deprecates the unused wstUSR-USDT DEX and related vaults by restricting their limits, (2) removes Team Multisig authorization from several old DEXes that are no longer in active use, (3) adjusts the trading ranges for syrupUSDC-USDC and syrupUSDT-USDT DEXes to optimize performance, and (4) sets up DEX V2 and Money Market proxies with soft launch limits and configurations. These changes improve protocol security, reduce operational overhead, and prepare for the next generation of DEX functionality.

## Code Changes

### Deprecate wstUSR-USDT DEX and Remove Authorization
- **DEX Pool 29** (wstUSR-USDT):
  - Restrict supply limits to effectively pause new deposits
  - Pause swap and arbitrage operations
  - Pause user operations at liquidity layer
  - Remove Team Multisig authorization

### Deprecate wstUSR Vaults
- **Vault 142** (wstUSR/USDTb):
  - Restrict supply and borrow limits to pause new activity
  - Pause user operations at liquidity layer
  
- **Vault 113** (wstUSR-USDT / USDT):
  - Restrict supply limits at DEX level and borrow limits at liquidity layer
  - Pause user operations at both DEX and liquidity layer
  - Remove Team Multisig authorization

- **Vault 135** (wstUSR-USDC / USDC-USDT Concentrated):
  - Restrict supply limits at wstUSR-USDC DEX (Pool 27)
  - Restrict borrow limits at USDC-USDT Concentrated DEX (Pool 34)
  - Pause user operations at both DEXes

### Remove Team Multisig Auth from Deprecated DEXes
The following DEXes were previously deprecated. This action completes the cleanup by removing Team Multisig authorization:
- DEX Pool 5 (USDC-ETH)
- DEX Pool 6 (WBTC-ETH)
- DEX Pool 7 (cbBTC-ETH)
- DEX Pool 8 (USDe-USDC)
- DEX Pool 10 (FLUID-ETH)
- DEX Pool 34 (USDC-USDT Concentrated)

### Update syrup DEX Trading Ranges
- **DEX Pool 39** (syrupUSDC-USDC):
  - Upper Range: 0.0001%
  - Lower Range: 0.4%

- **DEX Pool 40** (syrupUSDT-USDT):
  - Upper Range: 0.0001%
  - Lower Range: 0.4%

### DEX V2 Soft Launch Configuration
- **Money Market Proxy**:
  - Set $50K soft launch limits for supply and borrow operations
  - Tokens: ETH, USDC, USDT, cbBTC, WBTC
  - Base withdrawal limit: $50K, Base/max borrow limit: $50K
  - Make Team Multisig an authorized admin

- **DEX V2 Proxy**:
  - Set $75K soft launch limits for supply and borrow operations
  - Tokens: ETH, USDC, USDT, cbBTC, WBTC
  - Base withdrawal limit: $75K, Base/max borrow limit: $75K
  - Make Team Multisig an authorized admin
  - Add D3 and D4 admin implementations for new DEX types

## Description
This proposal implements several housekeeping updates to maintain protocol health:

1. **wstUSR Market Deprecation**
   - The wstUSR-USDT DEX (Pool 29) and associated vaults (142, 113, 135) are no longer actively used
   - Restricting limits and pausing user operations prevents new deposits while allowing existing users to withdraw
   - Swap and arbitrage operations are paused on the wstUSR-USDT DEX
   - Removing Team Multisig authorization reduces operational overhead

2. **Old DEX Authorization Cleanup**
   - Several DEXes (Pools 5, 6, 7, 8, 10, 34) were previously paused or deprecated
   - Removing Team Multisig authorization completes the deprecation process and improves security

3. **syrup DEX Optimization**
   - Updates the trading range parameters for syrupUSDC-USDC (Pool 39) and syrupUSDT-USDT (Pool 40) DEXes
   - New range: Upper 0.0001%, Lower 0.4%
   - Improves DEX performance under current market conditions

4. **DEX V2 Soft Launch**
   - Configures Money Market with conservative $50K limits for initial launch
   - Configures DEX V2 with $75K limits for initial launch
   - Both support ETH, USDC, USDT, cbBTC, and WBTC for supply and borrow
   - Grants Team Multisig authorization for operational management
   - Registers D3 and D4 admin implementations to support new DEX types

## Conclusion
IGP-117 is a maintenance proposal that cleans up deprecated markets, optimizes active ones, and prepares for DEX V2. By restricting limits and pausing operations on unused wstUSR markets, removing authorization from old DEXes, tuning the syrup DEX ranges, and setting up DEX V2 soft launch configurations ($50K for Money Market, $75K for DEX V2), this proposal keeps the protocol lean, secure, and ready for the next phase. Existing users in deprecated markets can still manage and exit their positions.
