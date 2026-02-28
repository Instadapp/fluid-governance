# Re: Set Dust Limits for REUSD DEX and Vaults, and Wind Down csUSDL Smart Lending

## Summary

This proposal is a re-submission of IGP-121. It implements the same two key protocol changes: (1) sets conservative dust limits and Team Multisig authorization for the new REUSD ecosystem including the REUSD-USDT DEX (Pool 44) and five associated vaults (160–164), preparing them for subsequent launch limit configuration, and (2) winds down the csUSDL-USDC smart lending (DEX Pool 38) by restricting supply caps and expansion parameters to prevent new activity while preserving withdrawal access for existing users.

## Code Changes

### Action 1: Set Dust Limits for REUSD Vaults (160–164) + Team MS Auth

- **Vault ID 160**<br>
  **REUSD/USDC (TYPE 1)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

- **Vault ID 161**<br>
  **REUSD/USDT (TYPE 1)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

- **Vault ID 162**<br>
  **REUSD/GHO (TYPE 1)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

- **Vault ID 163**<br>
  **REUSD/USDC-USDT (TYPE 3)**:
  - **Base Withdrawal Limit**: $7,000
  - **Base Borrow Limit**: Set at DEX level (USDC-USDT DEX, ID 2)
  - **DEX Borrow Limit**: 3,500 shares ($7k) base, 4,500 shares ($9k) max
  - **Authorization**: Add Team Multisig auth

- **Vault ID 164**<br>
  **REUSD-USDT/USDT (TYPE 2)**:
  - **Base Borrow Limit**: $7,000
  - **Max Borrow Limit**: $9,000
  - **Authorization**: Add Team Multisig auth

### Action 2: Set Dust Limits for REUSD-USDT DEX (Pool 44) + Team MS Auth

- **DEX Pool 44**<br>
  **REUSD-USDT DEX**:
  - **Base Withdrawal Limit**: $10,000
  - **Base Borrow Limit**: $0
  - **Max Borrow Limit**: $0
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Authorization**: Add Team Multisig auth

### Action 3: Wind Down csUSDL-USDC Smart Lending

- **DEX Pool 38**<br>
  **csUSDL-USDC DEX**:
  - **Max Supply Shares**: Restricted to 1 (blocks new supply)
  - **LL Supply Limit (csUSDL)**: $5,000 base withdrawal, 0.01% expand over max duration
  - **LL Supply Limit (USDC)**: $5,000 base withdrawal, 0.01% expand over max duration
  - **Smart Lending User Supply Config**: 2,000 shares (~$2k) base withdrawal, 0.01% expand over max duration
  - **Purpose**: Restrict new supply while preserving withdrawal access for existing users

## Description

This proposal is a re-submission of IGP-121. The payload is identical and implements two categories of changes to integrate new offerings and maintain protocol health:

1. **REUSD Ecosystem Dust Limits**
   - Introduces the REUSD-USDT DEX (Pool 44) and five associated vaults (160–164) with conservative dust limits
   - Sets appropriate withdrawal and borrow limits to ensure safe initial setup before launch limits are applied
   - Includes three T1 vaults (REUSD/USDC, REUSD/USDT, REUSD/GHO), one T3 vault (REUSD/USDC-USDT borrowing at the USDC-USDT DEX), and one T2 vault (REUSD-USDT/USDT with USDT debt limits)
   - Establishes Team Multisig authorization on all protocols for proper governance oversight during launch

2. **csUSDL Smart Lending Wind-Down**
   - Restricts the csUSDL-USDC smart lending (DEX Pool 38) by setting max supply shares to 1 and minimizing expansion parameters
   - Liquidity Layer supply limits for csUSDL and USDC are reduced to $5k base with minimal expansion (0.01% over max duration)
   - Smart lending DEX-level withdrawal limit reduced to ~$2k in shares with minimal expansion
   - No pause of withdrawals or swaps — existing users can still manage and exit their positions

## Conclusion

IGP-122 is a re-submission of IGP-121 with an identical payload. It integrates the new REUSD ecosystem with conservative dust limits across DEX Pool 44 and vaults 160–164, granting Team Multisig authorization on each for subsequent launch configuration. It simultaneously winds down the csUSDL-USDC smart lending by restricting supply caps while preserving withdrawal access for existing users. These changes support protocol growth through new REUSD offerings while maintaining operational efficiency and risk management best practices.
