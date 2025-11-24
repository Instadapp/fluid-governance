# Cleanup Leftover Reserve Allowances from IGP110, Reduce Limits on Old V1 Vaults, Max Restrict deUSD DEX, Update Lite Treasury, Update USDT Debt Vault Liquidation Penalties, Upgrade Reserve Contract, Adjust syrupUSDC Vault Parameters, and Collect Revenue for Buybacks

## Summary

This proposal implements nine key operations: (1) cleans up leftover allowances from the Reserve contract that were not properly revoked in IGP110 due to a protocol-token array mismatch, (2) reduces limits on very old v1 vaults (IDs 1-10) to allow users to exit while preventing new activity, (3) max restricts the deUSD-USDC DEX by setting max supply shares to minimal value, (4) updates the Lite treasury from the main treasury to the Reserve Contract, (5) updates liquidation penalties on all USDT debt vaults with vault-specific reductions, (6) launches the USDe-JRUSDE and SRUSDE-USDe DEXes with conservative limits, supply share caps, rebalancer updates, and Team Multisig removal, (7) upgrades the Reserve Contract implementation to the latest version, (8) aligns all syrupUSDC vault collateral settings (vault IDs 145-152) to 90% CF / 92% LT, and (9) collects accumulated liquidity-layer revenue for the monthly buyback program. These changes revoke 17 protocol-token allowance pairs that remained after IGP110 execution, reduce limits on the oldest vaults to allow withdrawals while preventing new deposits/borrows, restrict the deUSD-USDC DEX to allow withdrawals, route Lite revenue collection to the Reserve Contract instead of the main treasury, reduce liquidation penalties across all USDT debt vaults, safely launch the new JRUSDE routing pools with operational safeguards, upgrade the Reserve Contract to the latest implementation, harmonize syrupUSDC vault risk parameters with the latest guidance, and move the newly collected revenue to the Team Multisig for buybacks.

## Code Changes

### Action 1: Cleanup Leftover Allowances from Reserve Contract

- **Reserve Contract Operation**:
  - Revoke allowances for 17 protocol-token pairs from Reserve Contract Proxy
  - These are leftover allowances from IGP110 that were not properly cleaned up due to a protocol-token array mismatch that occurred after array element 20
  - **Protocols**: 17 different protocol addresses (various vaults and protocols)
  - **Tokens**: USDT and USDC
  - **Allowance Amounts**: Range from significant amounts (e.g., 65,890 USDT, 65,463 USDC) to smaller dust amounts (100 USDT/USDC)
  - **Purpose**: Complete the Reserve contract allowance cleanup that was started in IGP110 by removing all remaining unnecessary allowances

### Action 2: Reduce Limits on Very Old V1 Vaults

- **Vault Limit Reduction**:
  - Reduce limits on vaults with IDs 1-10 to allow users to exit while preventing new activity
  - **Vaults Affected**: Vault IDs 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
  - **Updated Base Withdrawal Limits (USD)**:
    - Vault 1 (ETH/USDC): $4.0k
    - Vault 2 (ETH/USDT): $6.0k
    - Vault 3 (wstETH/ETH): $5.0k
    - Vault 4 (wstETH/USDC): $4.0k
    - Vault 5 (wstETH/USDT): $4.0k
    - Vault 6 (weETH/wstETH): $8.0M
    - Vault 7 (sUSDe/USDC): $5.0k
    - Vault 8 (sUSDe/USDT): $1.0k
    - Vault 9 (weETH/USDC): $5.8M
    - Vault 10 (weETH/USDT): $2.8M
  - **Borrow Treatment**: All vaults leverage the standard `setBorrowProtocolLimitsPaused` helper (0.01% expand, max duration, $10/$20 ceilings) to keep borrow effectively disabled without pausing the vault
  - **Purpose**: Allow existing users to withdraw/exit these very old v1 vaults while preventing new deposits and borrows

### Action 3: Max Restrict deUSD-USDC DEX

- **DEX Pool 19**<br>
  **deUSD-USDC DEX**:
  - **Max Supply Shares**: Set to 10 (minimal limit to allow withdrawals)
  - **Purpose**: Restrict the deUSD-USDC DEX by setting max supply shares to minimal value, allowing users to withdraw while preventing new deposits

### Action 4: Update Lite Treasury to Reserve Contract

- **Lite Treasury Update**:
  - Update Lite (iETHv2) treasury address from main treasury to Reserve Contract
  - **Source**: Main treasury (current Lite treasury address)
  - **Destination**: Reserve Contract (`0x264786EF916af64a1DB19F513F24a3681734ce92`)
  - **Execution**: Direct call to `updateTreasury(address)` on Lite contract (`0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78`)
  - **Function**: Calls `updateTreasury(address)` on Lite contract
  - **Purpose**: Route Lite revenue collection (from `collectRevenue()`) to Reserve Contract instead of the main treasury, centralizing revenue management across both Fluid and Lite platforms

### Action 5: Update Liquidation Penalty on All USDT Debt Vaults

- **Liquidation Penalty Updates**:
  - Updates liquidation penalties on 8 vaults with USDT as borrow token
  - **ETH/USDT (vault 12)**: 2% → 1% (1% reduction)
  - **wstETH/USDT (vault 15)**: 3% → 2.5% (0.5% reduction)
  - **weETH/USDT (vault 20)**: 4% → 3% (1% reduction)
  - **WBTC/USDT (vault 22)**: 4% → 3% (1% reduction)
  - **cbBTC/USDT (vault 30)**: 4% → 3% (1% reduction)
  - **tBTC/USDT (vault 89)**: 4% → 3% (1% reduction)
  - **lBTC/USDT (vault 108)**: 5% → 4% (1% reduction)
  - **USDe-USDtb/USDT (vault 137, TYPE_2)**: 3% → 2.5% (0.5% reduction)
  - **Purpose**: Reduce liquidation costs for users borrowing USDT across different collateral types, aligning penalties with risk profiles and improving user experience while maintaining appropriate risk management

### Action 6: Launch USDe-JRUSDE and SRUSDE-USDe DEX Limits

- **DEX Pool 41**<br>
  **USDe<>JRUSDE**:
  - **Supply Configuration**:
    - **Supply Mode**: 1
    - **Supply Expand Percent**: 50%
    - **Supply Expand Duration**: 1 hour
    - **Base Withdrawal Limit in USD**: $5,500,000
  - **Borrow Configuration**:
    - **Borrow Mode**: 1
    - **Borrow Expand Percent**: 0%
    - **Borrow Expand Duration**: 0 hours
    - **Borrow Base/Max Limit in USD**: $0 / $0 (disabled)
  - **Max Supply Shares**: 6,000,000 * 1e18
  - **Smart Lending Rebalancer**: Points `fSL41` to the Reserve Contract (rebalancer-only update)
  - **DEX Auth**: Removes Team Multisig authorization after configuration
  - **Purpose**: Provides a tightly capped launch for USDe<>JRUSDE liquidity with governance-only control

- **DEX Pool 42**<br>
  **SRUSDE<>USDe**:
  - **Supply Configuration**:
    - **Supply Mode**: 1
    - **Supply Expand Percent**: 50%
    - **Supply Expand Duration**: 1 hour
    - **Base Withdrawal Limit in USD**: $5,500,000
  - **Borrow Configuration**:
    - **Borrow Mode**: 1
    - **Borrow Expand Percent**: 0%
    - **Borrow Expand Duration**: 0 hours
    - **Borrow Base/Max Limit in USD**: $0 / $0 (disabled)
  - **Max Supply Shares**: 6,000,000 * 1e18
  - **Smart Lending Rebalancer**: Points `fSL42` to the Reserve Contract (rebalancer-only update)
  - **DEX Auth**: Removes Team Multisig authorization after configuration
  - **Purpose**: Applies the same guarded launch template to SRUSDE<>USDe, keeping exposure capped and managed centrally

### Action 7: Upgrade Reserve Contract Implementation

- **Reserve Contract Upgrade**:
  - Upgrades the Reserve Contract proxy implementation to the latest version
  - **Current Implementation**: Existing Reserve Contract implementation
  - **New Implementation**: `0xFb3102759F2d57F547b9C519db49Ce1fFDE15dB2`
  - **Execution**: Calls `upgradeToAndCall` on the Reserve Contract proxy
  - **Purpose**: Deploy the latest Reserve Contract implementation with updated functionality and improvements

### Action 8: Adjust syrupUSDC Vault Parameters

- **Vault Parameter Update**:
  - Updates collateral factor (CF) to 90% and liquidation threshold (LT) to 92% on every syrupUSDC vault in IDs 145-152
  - **Vault IDs**: 145 (TYPE 2 syrupUSDC-USDC<>USDC), 146 (syrupUSDC/USDC), 147 (syrupUSDC/USDT), 148 (syrupUSDC/GHO), 149 (syrupUSDT-USDT<>USDT), 150 (syrupUSDT/USDC), 151 (syrupUSDT/USDT), 152 (syrupUSDT/GHO)
  - **Purpose**: Align syrupUSDC collateral settings with current risk appetite while restoring consistent cross-asset parameters

### Action 9: Collect Liquidity-Layer Revenue for Buybacks

- **Revenue Collection**:
  - Calls `collectRevenue()` on the Liquidity Layer for 8 tokens (`USDT, wstETH, ETH, USDC, sUSDe, cbBTC, WBTC, GHO`)
  - Withdraws nearly all balances of those tokens (leaving minimal dust) from the Reserve contract to Team Multisig
  - **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
  - **Purpose**: Aggregate protocol revenue needed for the next buyback cycle

## Description

This proposal addresses nine cleanup, security enhancement, operational management, parameter standardization, infrastructure upgrade, and treasury management tasks:

1. **Reserve Contract Security Enhancement**
   - Completes the allowance cleanup process that was initiated in IGP110
   - Addresses a cleanup issue from IGP110 where not all Reserve contract allowances were properly revoked due to a protocol-token array mismatch that occurred after array element 20
   - Revokes 17 remaining protocol-token allowance pairs that were missed due to the array mismatch
   - Removes unnecessary allowances for protocols that no longer have rewards running or had dust allowances
   - The allowances being revoked include both significant amounts (e.g., 65,890 USDT, 65,463 USDC) and smaller dust amounts (100 USDT/USDC), ensuring complete cleanup of all leftover permissions
   - Improves security posture by reducing attack surface and potential misuse of unused allowances
   - Standardizes the protocol approach to explicitly grant allowances only when needed

2. **Old V1 Vault Limit Reduction**
   - Reduces limits on the very oldest vaults in the protocol (vault IDs 1-10)
   - These vaults represent the earliest vault deployments and are no longer in active use
   - Updates each vault’s base withdrawal limit (see Action 2 table) to track current TVL while still allowing exits
   - All vaults 1-10: Borrow side uses the `setBorrowProtocolLimitsPaused` helper (0.01% expand, max duration, $10/$20 ceilings)
   - Allows existing users to withdraw/exit while preventing new deposits and borrows
   - Improves protocol security by reducing exposure to legacy vault implementations
   - Maintains protocol cleanliness by restricting deprecated vaults without fully pausing

3. **deUSD-USDC DEX Max Restriction**
   - Max restricts the deUSD-USDC DEX (DEX ID 19)
   - Sets max supply shares to 10 (minimal limit)
   - Allows users to withdraw while preventing new deposits
   - Maintains protocol risk management by restricting exposure to deUSD without fully pausing

4. **Lite Treasury Update**
   - Updates the Lite (iETHv2) treasury address from the main treasury to the Reserve Contract
   - Routes Lite revenue collection (from `collectRevenue()`) to Reserve Contract instead of the main treasury
   - Executed by directly calling `updateTreasury(address)` function on Lite contract
   - The Governance Timelock (as Lite admin) has permission to call this function directly
   - Centralizes revenue management by routing Lite revenue to the same Reserve Contract used for Fluid protocol revenue
   - Improves treasury management consistency and operational efficiency across both Fluid and Lite platforms

5. **USDT Debt Vault Liquidation Penalty Updates**
   - Updates liquidation penalties on all vaults with USDT as borrow token with vault-specific reductions
   - ETH/USDT: 2% → 1%
   - wstETH/USDT: 3% → 2.5%
   - weETH/USDT: 4% → 3%
   - WBTC/USDT: 4% → 3%
   - cbBTC/USDT: 4% → 3%
   - tBTC/USDT: 4% → 3%
   - lBTC/USDT: 5% → 4%
   - USDe-USDtb/USDT: 3% → 2.5%
   - Reduces liquidation costs for users borrowing USDT across different collateral types
   - Aligns liquidation penalties with risk profiles and market conditions

6. **USDe-JRUSDE & SRUSDE-USDe DEX Launch Controls**
   - Sets conservative launch limits on the USDe-JRUSDE (DEX ID 41) and SRUSDE-USDe (DEX ID 42) pools
   - Caps token-level liquidity-layer limits at $5.5M per side and max supply shares at 6,000,000 * 1e18
   - Updates the associated smart lending rebalancers (fSL41 and fSL42) to the Reserve Contract
   - Removes Team Multisig authorization on both DEXes after configuration

7. **Reserve Contract Implementation Upgrade**
   - Upgrades the Reserve Contract proxy to the latest implementation version
   - Deploys new implementation at `0xFb3102759F2d57F547b9C519db49Ce1fFDE15dB2`
   - Executed via `upgradeToAndCall` on the Reserve Contract proxy
   - Ensures the Reserve Contract has the latest features, security improvements, and optimizations

8. **syrupUSDC Vault Parameter Alignment**
   - Sets the collateral factor to 90% and liquidation threshold to 92% for all syrupUSDC family vaults (IDs 145-152)
   - Restores uniform collateralization parameters across both Type 1 and Type 2 syrupUSDC vaults

9. **Buyback Revenue Collection**
   - Collects revenue across 8 tokens from the Liquidity Layer
   - Withdraws the resulting balances from the Reserve contract to the Team Multisig, leaving dust buffers
   - Improves risk management consistency as syrupUSDC markets scale

## Conclusion

IGP-112 completes the Reserve contract allowance cleanup from IGP110 by revoking 17 leftover protocol-token allowance pairs, reduces limits on the oldest v1 vaults (IDs 1-10) to allow exits while preventing new activity, max restricts the deUSD-USDC DEX by setting max supply shares to 10, updates the Lite treasury from the main treasury to the Reserve Contract, reduces liquidation penalties on all USDT debt vaults with vault-specific reductions, launches the USDe-JRUSDE and SRUSDE-USDe DEXes with controlled limits, supply caps, and governance cleanup, upgrades the Reserve Contract implementation to the latest version, aligns syrupUSDC family vault collateral settings at 90% CF / 92% LT, and collects liquidity-layer revenue for the buyback program. These changes improve protocol security, centralize revenue management across Fluid and Lite platforms, cap new DEX exposure, reduce liquidation costs for users borrowing USDT, keep syrupUSDC vaults aligned with current risk parameters, ensure the Reserve Contract operates with the latest features and improvements, and fund the upcoming buyback cycle.