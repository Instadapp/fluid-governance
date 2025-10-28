# Launch syrupUSDT DEX and Vaults, Collect Revenue, Configure USDE-JRUSDE and SRUSDE-USDE Dust Limits, and Collect Lite Revenue

## Summary

This proposal implements four key protocol upgrades: (1) launches the syrupUSDT DEX and associated vaults with launch limits and removes Team Multisig authorization post-launch, (2) collects accrued protocol revenue across multiple assets and withdraws it to Team Multisig for October buyback operations, (3) sets conservative dust limits for USDE-JRUSDE and SRUSDE-USDE DEXes, and (4) collects Lite revenue by transferring 82.8 stETH from iETHv2 to Team Multisig for buyback operations. These changes aim to expand protocol offerings with safe integration parameters, optimize revenue collection mechanisms from both Fluid and Lite platforms, and prepare for continued ecosystem growth.

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

### Action 2: Collect Revenue and Withdraw to Team Multisig for October Buyback

- **Revenue Collection**:
  - Collect protocol revenue across a basket of tokens from the Liquidity Layer
  - **Tokens Included**: `USDT, wstETH, ETH, USDC, sUSDe, cbBTC, WBTC, GHO, USDe, wstUSR, ezETH, lBTC, USDTb, RLP`
  - Withdraw nearly all balances from Reserve to Team Multisig, leaving minimal dust for operational safety
  - **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
  - Purpose: Prepare accumulated revenue from October for monthly buyback execution

### Action 3: Set Dust Limits for USDE-JRUSDE and SRUSDE-USDE DEXes

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

### Action 4: Collect Lite Revenue and Transfer to Team Multisig

- **Lite Vault Revenue Collection**:
  - Transfer 82.8 stETH from iETHv2 Lite vault to Team Multisig
  - Transfer executed through Treasury DSA via BASIC-A connector
  - **Amount**: 82.8 stETH (82.8 * 1e18 wei)
  - **Source**: iETHv2 Lite vault
  - **Destination**: Team Multisig
  - Purpose: Collect accumulated Lite vault revenue for October buyback operations

## Description

This proposal implements three major changes to enhance protocol functionality, optimize revenue management, and expand market offerings:

1. **syrupUSDT DEX and Vault Launch**
   - Brings the syrupUSDT market online with conservative launch limits across DEX Pool 40 and Vaults 149–152
   - Sets appropriate withdrawal and borrow limits to ensure safe initial setup and gradual scaling
   - Configures smart collateral functionality while maintaining controlled debt parameters
   - Post-configuration, Team Multisig authorization is removed from the DEX and vaults to decentralize control once launch parameters are set

2. **Revenue Collection and Buyback Preparation**
   - Collects accumulated protocol revenue across 14 different tokens from the Liquidity Layer
   - Withdraws nearly all balances from the Reserve for the above tokens to Team Multisig, leaving minimal dust for operational safety
   - Prepares funds for October buyback operations and demonstrates active treasury management
   - Consolidates revenue streams from diverse asset classes including stablecoins, liquid staking tokens, and yield-bearing assets

3. **USDE-JRUSDE and SRUSDE-USDE Dust Limits**
   - Introduces conservative dust limits for two new DEX pools (USDE-JRUSDE and SRUSDE-USDE)
   - Sets appropriate withdrawal limits ($10k) to ensure safe initial setup while maintaining controlled exposure
   - Configures smart collateral functionality with Team Multisig authorization for proper governance oversight
   - These conservative limits support gradual scaling and risk management for new market integrations

4. **Lite Vault Revenue Management**
   - Collects accumulated stETH revenue from the iETHv2 Lite vault and transfers it to Team Multisig for buyback operations
   - Executes transfer through Treasury DSA via BASIC-A connector to ensure proper treasury management
   - Demonstrates active revenue collection from both Fluid and Lite platform streams
   - Supports October buyback program by consolidating revenue from all protocol sources

## Conclusion

IGP-111 delivers targeted protocol upgrades: it launches the syrupUSDT market with appropriate limits and decentralized post-launch controls, collects and withdraws accumulated revenue from both Fluid and Lite platforms to Team Multisig for October buyback operations, and introduces conservative dust limits for new USDE-related DEX integrations. The proposal balances expansion goals with risk management, ensuring safe integration of new markets while maintaining operational efficiency and treasury management best practices. These changes support sustainable growth and improved revenue distribution across both the Fluid and Lite ecosystems.
