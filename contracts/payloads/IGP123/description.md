# Launch Limits for REUSD Protocols, DEX V2 Soft Launch (Re-send), Rollback Module on LL, and DexFactory Cleanup

## Summary

This proposal implements four categories of changes: (1) sets launch limits for the REUSD ecosystem including DEX Pool 44 and vaults 160–164, replacing the dust limits set in IGP-122, (2) re-sends the DEX V2 soft launch configuration from IGP-117 with updated D3/D4 admin implementation addresses, (3) rolls out the rollbackModule on the Liquidity Layer (audited by Statemind), and (4) disables the old DexT1DeploymentLogic on DexFactory as cleanup.

## Code Changes

### Action 1: Launch Limits for REUSD Vaults (160–164) + Remove Team MS Auth

- **Vault ID 160**<br>
  **REUSD/USDC (TYPE 1)**:
  - **Base Withdrawal Limit**: $7.5M
  - **Base Borrow Limit**: $5M  
  - **Max Borrow Limit**: $10M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 161**<br>
  **REUSD/USDT (TYPE 1)**:
  - **Base Withdrawal Limit**: $7.5M
  - **Base Borrow Limit**: $5M
  - **Max Borrow Limit**: $10M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 162**<br>
  **REUSD/GHO (TYPE 1)**:
  - **Base Withdrawal Limit**: $7.5M
  - **Base Borrow Limit**: $5M
  - **Max Borrow Limit**: $10M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 163**<br>
  **REUSD/USDC-USDT (TYPE 3)**:
  - **Base Withdrawal Limit**: $7.5M
  - **DEX Borrow Limit**: ~2.5M shares (~$5M) base, ~5M shares (~$10M) max (TODO: confirm)
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 164**<br>
  **REUSD-USDT/USDT (TYPE 2)**:
  - **Base Borrow Limit**: $5M
  - **Max Borrow Limit**: $10M
  - **Authorization**: Remove Team Multisig auth

### Action 2: Launch Limits for REUSD-USDT DEX (Pool 44) + Remove Team MS Auth

- **DEX Pool 44**<br>
  **REUSD-USDT DEX**:
  - **Base Withdrawal Limit**: $5M per token
  - **Max Supply Shares**: 10M shares (~$10M)
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Authorization**: Remove Team Multisig auth

### Action 3: DEX V2 Soft Launch (Re-send from IGP-117)

Re-sends the DEX V2 soft launch configuration from IGP-117 with updated admin implementation addresses. Proxy addresses remain the same.

- **Money Market Proxy**:
  - Set $50K soft launch limits for supply and borrow operations
  - Tokens: ETH, USDC, USDT, cbBTC, WBTC
  - Make Team Multisig an authorized admin

- **DEX V2 Proxy**:
  - Set $75K soft launch limits for supply and borrow operations
  - Tokens: ETH, USDC, USDT, cbBTC, WBTC
  - Make Team Multisig an authorized admin
  - **Updated** D3 Admin Implementation: `0x48956a66F1d7Df6356b2C9364ef786fD7aCACCd9`
  - **Updated** D4 Admin Implementation: `0x944E4C51fCE91587f89352098Fe3C9E341fE1E65`

### Action 4: Roll Out Rollback Module on Liquidity Layer

- **Rollback Module** (audited by Statemind):
  - Adds rollbackModule as a new implementation on the Liquidity Layer's InfiniteProxy
  - Address to be set via `setRollbackModuleAddress()` by Team Multisig after deployment

### Action 5: DexFactory Cleanup

- **DexFactory**:
  - Disable old DexT1DeploymentLogic (`0x7db5101f12555bD7Ef11B89e4928061B7C567D27`) by setting allowed to false

## Description

This proposal covers four areas of protocol development and maintenance:

1. **REUSD Ecosystem Launch**
   - Upgrades all REUSD protocols from dust limits (IGP-122) to full launch limits
   - Sets operational withdrawal and borrow limits across DEX Pool 44 and vaults 160–164
   - Removes Team Multisig authorization since protocols are now launched with proper governance limits
   - Sets max supply shares on DEX 44 to enable real liquidity provision

2. **DEX V2 Soft Launch (Re-send)**
   - Re-sends the DEX V2 soft launch action from IGP-117
   - Same conservative limits: $50K for Money Market, $75K for DEX V2
   - Updated D3 Admin Implementation (`0x48956a66F1d7Df6356b2C9364ef786fD7aCACCd9`) and D4 Admin Implementation (`0x944E4C51fCE91587f89352098Fe3C9E341fE1E65`)
   - Proxy addresses remain unchanged

3. **Rollback Module on Liquidity Layer**
   - Introduces the rollbackModule on the Liquidity Layer, audited by Statemind
   - Deployed address to be set by Team Multisig before proposal execution
   - Enhances protocol safety with rollback capabilities

4. **DexFactory Cleanup**
   - Disables the old DexT1DeploymentLogic (`0x7db5101f12555bD7Ef11B89e4928061B7C567D27`) on DexFactory
   - Prevents new deployments using the deprecated logic

## Conclusion

IGP-123 transitions the REUSD ecosystem from dust limits to full launch limits, re-sends the DEX V2 soft launch configuration with updated admin implementations, introduces the Statemind-audited rollback module on the Liquidity Layer for enhanced safety, and cleans up the DexFactory by disabling the old deployment logic. These changes collectively advance protocol capabilities while maintaining rigorous security standards.
