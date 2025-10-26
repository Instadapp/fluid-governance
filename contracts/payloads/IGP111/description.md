# Launch syrupUSDT DEX and Vaults, Update Revenue Collector, Collect Revenue, and Configure USDE-JRUSDE and SRUSDE-USDE Dust Limits

## Summary

This proposal implements four key protocol upgrades: (1) launches the syrupUSDT DEX and associated vaults with launch limits and removes Team Multisig authorization post-launch, (2) updates the revenue collector address to streamline protocol revenue distribution, (3) collects accrued protocol revenue across multiple assets for buyback operations, and (4) sets conservative dust limits for USDE-JRUSDE and SRUSDE-USDE DEXes. These changes aim to expand protocol offerings with safe integration parameters, optimize revenue collection mechanisms, and prepare for continued ecosystem growth.

## Code Changes

### Action 1: Set Launch Limits for syrupUSDT DEX and Its Vaults

- **DEX Pool 40**<br>
  **syrupUSDT-USDT DEX**:
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Base Withdrawal Limit**: $10M
  - **Base Borrow Limit**: $0
  - **Max Borrow Limit**: $0
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 149**<br>
  **syrupUSDT-USDT<>USDT (TYPE 2)**:
  - **Base Withdrawal Limit**: $0
  - **Base Borrow Limit**: $10M
  - **Max Borrow Limit**: $20M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 150**<br>
  **syrupUSDT/USDC (TYPE 1)**:
  - **Base Withdrawal Limit**: $10M
  - **Base Borrow Limit**: $10M
  - **Max Borrow Limit**: $20M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 151**<br>
  **syrupUSDT/USDT (TYPE 1)**:
  - **Base Withdrawal Limit**: $10M
  - **Base Borrow Limit**: $10M
  - **Max Borrow Limit**: $20M
  - **Authorization**: Remove Team Multisig auth

- **Vault ID 152**<br>
  **syrupUSDT/GHO (TYPE 1)**:
  - **Base Withdrawal Limit**: $10M
  - **Base Borrow Limit**: $10M
  - **Max Borrow Limit**: $20M
  - **Authorization**: Remove Team Multisig auth

### Action 2: Update Revenue Collector Address

- **Revenue Collection Update**:
  - Update revenue collector address on the Liquidity contract
  - **New Revenue Collector Address**: `0x9Afb8C1798B93a8E04a18553eE65bAFa41a012F1`
  - Purpose: Streamline protocol revenue distribution for buyback and operational needs

### Action 3: Collect Revenue from Liquidity Layer

- **Revenue Collection**:
  - Collect protocol revenue across a basket of tokens from the Liquidity Layer
  - **Tokens Included**: `USDT, wstETH, ETH, USDC, sUSDe, cbBTC, WBTC, GHO, USDe, wstUSR, ezETH, lBTC, USDTb, RLP`
  - Purpose: Prepare accumulated revenue from October for monthly buyback execution

### Action 4: Set Dust Limits for USDE-JRUSDE and SRUSDE-USDE DEXes

- **DEX Pool 41**<br>
  **USDE-JRUSDE DEX**:
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Base Withdrawal Limit**: $10k
  - **Base Borrow Limit**: $0
  - **Max Borrow Limit**: $0
  - **Authorization**: Add Team Multisig auth

- **DEX Pool 42**<br>
  **SRUSDE-USDE DEX**:
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Base Withdrawal Limit**: $10k
  - **Base Borrow Limit**: $0
  - **Max Borrow Limit**: $0
  - **Authorization**: Add Team Multisig auth

## Description

This proposal implements four major changes to enhance protocol functionality, optimize revenue management, and expand market offerings:

1. **syrupUSDT DEX and Vault Launch**
   - Brings the syrupUSDT market online with conservative launch limits across DEX Pool 40 and Vaults 149–152
   - Sets appropriate withdrawal and borrow limits to ensure safe initial setup and gradual scaling
   - Configures smart collateral functionality while maintaining controlled debt parameters
   - Post-configuration, Team Multisig authorization is removed from the DEX and vaults to decentralize control once launch parameters are set

2. **Revenue Collector Update**
   - Updates the revenue collector address on the Liquidity contract to streamline protocol revenue distribution
   - This change improves operational efficiency for buyback operations and treasury management

3. **Revenue Collection for Buyback**
   - Collects accumulated protocol revenue across 14 different tokens from the Liquidity Layer
   - Prepares funds for october buyback operations and demonstrates active treasury management
   - Consolidates revenue streams from diverse asset classes including stablecoins, liquid staking tokens, and yield-bearing assets

4. **USDE-JRUSDE and SRUSDE-USDE Dust Limits**
   - Introduces conservative dust limits for two new DEX pools (USDE-JRUSDE and SRUSDE-USDE)
   - Sets appropriate withdrawal limits ($10k) to ensure safe initial setup while maintaining controlled exposure
   - Configures smart collateral functionality with Team Multisig authorization for proper governance oversight
   - These conservative limits support gradual scaling and risk management for new market integrations

## Conclusion

IGP-111 delivers targeted protocol upgrades: it launches the syrupUSDT market with appropriate limits and decentralized post-launch controls, optimizes revenue collection mechanisms, prepares accumulated revenue for buyback operations, and introduces conservative dust limits for new USDE-related DEX integrations. The proposal balances expansion goals with risk management, ensuring safe integration of new markets while maintaining operational efficiency and treasury management best practices. These changes support sustainable growth and improved revenue distribution across the platform.
