# Cleanup Reserve Allowances, Set Dust Limits for syrupUSDT DEX and Vaults, and Increase syrupUSDC Vault Borrow Limits

## Summary

This proposal implements three key operations: (1) cleans up allowances from the Reserve contract by revoking protocol permissions as no rewards are ongoing anymore, (2) sets dust limits for the new syrupUSDT DEX and its associated vaults with conservative parameters, and (3) increases borrow limits for the syrupUSDC/USDC vault to support increased usage. These changes aim to optimize protocol security by removing unnecessary allowances, safely integrate new syrupUSDT offerings with appropriate limits, and enhance existing syrupUSDC vault capacity.

## Code Changes

### Action 1: Cleanup Allowances from Reserve Contract

- **Reserve Contract Operation**:
  - Revoke allowances for 44 protocol-token pairs from Reserve Contract Proxy
  - Remove permissions for protocols that no longer need access as rewards are no longer ongoing
  - **Protocols**: 44 different protocol addresses across various token pairs
  - **Tokens**: GHO, sUSDe, wstETH, weETH, USDT, USDC, WBTC
  - **Purpose**: Standardize to no allowance towards protocols and explicitly add when needed

### Action 2: Set Dust Limits for syrupUSDT DEX and Vaults

- **DEX Pool 40**<br>
  **syrupUSDT-USDT DEX**:
  - **Base Withdrawal Limit**: $10,000
  - **Base Borrow Limit**: $0
  - **Max Borrow Limit**: $0
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Authorization**: Add Team Multisig auth

- **Vault ID 149**<br>
  **syrupUSDT-USDT<>USDT (TYPE 2)**:
  - **Base Withdrawal Limit**: $0
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

- **Vault ID 150**<br>
  **syrupUSDT/USDC (TYPE 1)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

- **Vault ID 151**<br>
  **syrupUSDT/USDT (TYPE 1)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

- **Vault ID 152**<br>
  **syrupUSDT/GHO (TYPE 1)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

### Action 3: Increase Borrow Limits for syrupUSDC/USDC Vault

- **Vault ID 146**<br>
  **syrupUSDC/USDC (TYPE 1)**:
  - **Base Withdrawal Limit**: $7M
  - **Base Borrow Limit**: $5M
  - **Max Borrow Limit**: $50M

## Description

This proposal implements three major changes to enhance protocol security, integrate new offerings, and optimize existing vault capacity:

1. **Reserve Contract Security Enhancement**
   - Removes unnecessary allowances from the Reserve contract for 44 protocol-token pairs where rewards are no longer ongoing
   - Standardizes the protocol approach to explicitly grant allowances only when needed rather than maintaining broad permissions
   - Improves security posture by reducing attack surface and potential misuse of unused allowances

2. **syrupUSDT Integration with Conservative Limits**
   - Introduces syrupUSDT DEX (Pool 40) and four associated vaults (149-152) with conservative dust limits
   - Sets appropriate withdrawal and borrow limits to ensure safe initial setup and gradual scaling
   - Configures smart collateral functionality while maintaining controlled debt parameters
   - Establishes Team Multisig authorization for proper governance oversight

3. **syrupUSDC Vault Capacity Enhancement**
   - Increases max borrow limit for syrupUSDC/USDC vault (ID 146) to $50M to support increased usage
   - Maintains existing base withdrawal and borrow limits while expanding maximum capacity
   - Supports growing demand for syrupUSDC borrowing while maintaining appropriate risk management

## Conclusion

This proposal strengthens protocol security through allowance cleanup, safely integrates new syrupUSDT offerings with conservative parameters, and enhances existing syrupUSDC vault capacity. By removing unnecessary Reserve contract allowances, the protocol reduces potential security risks while maintaining operational flexibility. The introduction of syrupUSDT DEX and vaults with dust limits ensures safe onboarding of new assets, while the increase in syrupUSDC vault borrow limits supports continued growth and user demand. These changes collectively improve protocol security, expand available offerings, and optimize capital efficiency for existing vaults.
