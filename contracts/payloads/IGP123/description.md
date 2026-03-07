# REUSD Launch, wstUSR Deprecation, DEX Cleanup, DEX V2 Soft Launch, Rollback Module, and DexFactory Cleanup

## Summary

This proposal implements protocol-wide updates across six areas: (1) launches the REUSD ecosystem with full operational limits on DEX Pool 44 and vaults 160–164, (2) deprecates the unused wstUSR-USDT DEX and associated vaults by restricting limits and pausing operations, (3) removes Team Multisig authorization from previously deprecated DEXes, (4) optimizes syrup DEX trading ranges, (5) configures the DEX V2 and Money Market soft launch with conservative limits and updated admin implementations, (6) rolls out the Statemind-audited rollbackModule on the Liquidity Layer, and disables the old DexT1DeploymentLogic on DexFactory.

## Code Changes

### Action 1: Launch Limits for REUSD Vaults (160–164) + Remove Team MS Auth

- **Vault ID 160**<br>
  **REUSD/USDC (TYPE 1)**:
  - **Base Withdrawal Limit**: $8M
  - **Base Borrow Limit**: $8M
  - **Max Borrow Limit**: $20M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 161**<br>
  **REUSD/USDT (TYPE 1)**:
  - **Base Withdrawal Limit**: $8M
  - **Base Borrow Limit**: $8M
  - **Max Borrow Limit**: $20M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 162**<br>
  **REUSD/GHO (TYPE 1)**:
  - **Base Withdrawal Limit**: $8M
  - **Base Borrow Limit**: $8M
  - **Max Borrow Limit**: $20M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 163**<br>
  **REUSD/USDC-USDT (TYPE 3)**:
  - **Base Withdrawal Limit**: $8M
  - **DEX Borrow Limit**: ~4M shares (~$8M) base, ~10M shares (~$20M) max
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 164**<br>
  **REUSD-USDT/USDT (TYPE 2)**:
  - **Base Borrow Limit**: $5M
  - **Max Borrow Limit**: $10M
  - **Authorization**: Remove Team Multisig auth

### Action 2: Launch Limits for REUSD-USDT DEX (Pool 44) + Remove Team MS Auth

- **DEX Pool 44**<br>
  **REUSD-USDT DEX**:
  - **Base Withdrawal Limit**: $5M per token (LL limits)
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Authorization**: Remove Team Multisig auth

### Action 3: Deprecate wstUSR-USDT DEX and Remove Authorization

- **DEX Pool 29** (wstUSR-USDT):
  - Restrict supply limits to effectively pause new deposits
  - Pause swap and arbitrage operations
  - Pause user operations at liquidity layer
  - Remove Team Multisig authorization

### Action 4: Deprecate wstUSR Vaults

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

### Action 5: Remove Team Multisig Auth from Deprecated DEXes

The following DEXes were previously deprecated. This action completes the cleanup by removing Team Multisig authorization:
- DEX Pool 5 (USDC-ETH)
- DEX Pool 6 (WBTC-ETH)
- DEX Pool 7 (cbBTC-ETH)
- DEX Pool 8 (USDe-USDC)
- DEX Pool 10 (FLUID-ETH)
- DEX Pool 34 (USDC-USDT Concentrated)

### Action 6: Update syrup DEX Trading Ranges

- **DEX Pool 39** (syrupUSDC-USDC):
  - Upper Range: 0.0001%
  - Lower Range: 0.4%

- **DEX Pool 40** (syrupUSDT-USDT):
  - Upper Range: 0.0001%
  - Lower Range: 0.4%

### Action 7: DEX V2 Soft Launch Configuration

- **Money Market Proxy**:
  - Set $50K soft launch limits for supply and borrow operations
  - Tokens: ETH, USDC, USDT, cbBTC, WBTC
  - Make Team Multisig an authorized admin

- **DEX V2 Proxy**:
  - Set $75K soft launch limits for supply and borrow operations
  - Tokens: ETH, USDC, USDT, cbBTC, WBTC
  - Make Team Multisig an authorized admin
  - D3 Admin Implementation: `0x48956a66F1d7Df6356b2C9364ef786fD7aCACCd9`
  - D4 Admin Implementation: `0x944E4C51fCE91587f89352098Fe3C9E341fE1E65`

### Action 8: Roll Out Rollback Module on Liquidity Layer

- **Rollback Module** (audited by Statemind):
  - Adds `InfiniteProxyRollbackModule` (`0x463874c5A102ceEa919D63f748a433304D1bd1c0`) as a new implementation on the Liquidity Layer's InfiniteProxy
  - Registers 9 function selectors for rollback registration, execution, cleanup, and view functions

### Action 9: DexFactory Cleanup

- **DexFactory**:
  - Disable old DexT1DeploymentLogic (`0x7db5101f12555bD7Ef11B89e4928061B7C567D27`) by setting allowed to false

## Description

This proposal implements a broad set of protocol updates covering new launches, deprecations, optimizations, and infrastructure upgrades:

1. **REUSD Ecosystem Launch**
   - Upgrades all REUSD protocols from dust limits (IGP-122) to full launch limits
   - T1 vaults (160–162): $8M base withdrawal, $8M base borrow, $20M max borrow
   - T3 vault (163): $8M base withdrawal, ~4M/$10M shares DEX borrow (~$8M/$20M)
   - T2 vault (164): $5M base borrow, $10M max borrow
   - DEX 44: $5M LL token limits
   - Removes Team Multisig authorization since protocols are now launched with proper governance limits

2. **wstUSR Market Deprecation**
   - The wstUSR-USDT DEX (Pool 29) and associated vaults (142, 113, 135) are no longer actively used
   - Restricting limits and pausing user operations prevents new deposits while allowing existing users to withdraw
   - Swap and arbitrage operations are paused on the wstUSR-USDT DEX
   - Removing Team Multisig authorization from vault 113 and DEX 29 reduces operational overhead

3. **DEX Authorization Cleanup and syrup DEX Optimization**
   - Several DEXes (Pools 5, 6, 7, 8, 10, 34) were previously deprecated — removing Team Multisig authorization completes the process and improves security
   - Updates the trading range parameters for syrupUSDC-USDC (Pool 39) and syrupUSDT-USDT (Pool 40) DEXes to Upper 0.0001%, Lower 0.4% for improved performance under current market conditions

4. **DEX V2 Soft Launch**
   - Configures Money Market with conservative $50K limits for initial launch
   - Configures DEX V2 with $75K limits for initial launch
   - Both support ETH, USDC, USDT, cbBTC, and WBTC for supply and borrow
   - Grants Team Multisig authorization for operational management
   - Registers D3 (`0x48956a66F1d7Df6356b2C9364ef786fD7aCACCd9`) and D4 (`0x944E4C51fCE91587f89352098Fe3C9E341fE1E65`) admin implementations to support new DEX types

5. **Rollback Module and DexFactory Cleanup**
   - Introduces the Statemind-audited `InfiniteProxyRollbackModule` (`0x463874c5A102ceEa919D63f748a433304D1bd1c0`) on the Liquidity Layer for enhanced protocol safety with rollback capabilities
   - Disables the old DexT1DeploymentLogic (`0x7db5101f12555bD7Ef11B89e4928061B7C567D27`) on DexFactory to prevent deployments using deprecated logic

## Conclusion

IGP-123 launches the REUSD ecosystem with full operational limits, deprecates unused wstUSR markets, cleans up old DEX authorizations, optimizes syrup DEX ranges, configures the DEX V2 soft launch with D3/D4 admin implementations, introduces the rollback module on the Liquidity Layer for enhanced safety, and disables deprecated deployment logic on DexFactory. These changes collectively advance protocol capabilities, reduce operational overhead, and maintain rigorous security standards. Existing users in deprecated markets can still manage and exit their positions.
