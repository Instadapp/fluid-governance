# Cleanup Leftover Reserve Allowances from IGP110, Reduce Limits on Old V1 Vaults, Max Restrict deUSD DEX, Update Lite Treasury, and Update USDT Debt Vault Liquidation Penalties

## Summary

This proposal implements six key operations: (1) cleans up leftover allowances from the Reserve contract that were not properly revoked in IGP110 due to a protocol-token array mismatch, (2) reduces limits on very old v1 vaults (IDs 1-10) to allow users to exit while preventing new activity, (3) max restricts the deUSD-USDC DEX by setting max supply shares to minimal value, (4) updates the Lite treasury from the main treasury to the Reserve Contract, (5) updates liquidation penalties on all USDT debt vaults with vault-specific reductions, and (6) launches the JRUSDE-SRUSDE DEX with conservative limits, supply share caps, rebalancer updates, and Team Multisig removal. These changes revoke 17 protocol-token allowance pairs that remained after IGP110 execution, reduce limits on the oldest vaults to allow withdrawals while preventing new deposits/borrows, restrict the deUSD-USDC DEX to allow withdrawals, route Lite revenue collection to the Reserve Contract instead of the main treasury, reduce liquidation penalties across all USDT debt vaults, and safely launch the JRUSDE-SRUSDE DEX with operational safeguards.

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
    - Vault 1 (ETH/USDC): $2.2k
    - Vault 2 (ETH/USDT): $3.2k
    - Vault 3 (wstETH/ETH): $2.6k
    - Vault 4 (wstETH/USDC): $2.25k
    - Vault 5 (wstETH/USDT): $2.27k
    - Vault 6 (weETH/wstETH): $14.5M
    - Vault 7 (sUSDe/USDC): $4k
    - Vault 8 (sUSDe/USDT): $520
    - Vault 9 (weETH/USDC): $3.45M
    - Vault 10 (weETH/USDT): $1.75M
  - **All Vaults 1-10**: Borrow limits set to minimal values (0.01% expand, max duration, $10 base / $20 max limits)
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

### Action 6: Launch JRUSDE-SRUSDE DEX Limits

- **DEX Pool 43**<br>
  **JRUSDE<>SRUSDE**:
  - **Supply Configuration**:
    - **Supply Mode**: 1
    - **Supply Expand Percent**: 50%
    - **Supply Expand Duration**: 1 hour
    - **Base Withdrawal Limit in USD**: $10,000,000
  - **Borrow Configuration**:
    - **Borrow Mode**: 1
    - **Borrow Expand Percent**: 0%
    - **Borrow Expand Duration**: 0 hours
    - **Borrow Base/Max Limit in USD**: $0 / $0 (disabled)
  - **Max Supply Shares**: 10,000,000 * 1e18 (mirrors the launch caps used in IGP-79)
  - **Smart Lending Rebalancer**: Sets `fSL43` (JRUSDE-SRUSDE smart lending) rebalancer to the Reserve Contract, as done for csUSDL-USDC in IGP-102
  - **DEX Auth**: Removes Team Multisig as auth post-launch to leave governance-only control
  - **Purpose**: Applies the standard launch playbook—tight withdrawal caps, capped shares, Reserve-controlled rebalancing, and auth cleanup—before opening JRUSDE-SRUSDE liquidity to users

## Description

This proposal addresses six cleanup, security enhancement, operational management, and parameter standardization tasks:

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
   - Vault 1 (ETH/USDC): Base withdrawal limit reduced to 0.7 ETH to allow gradual exits
   - All vaults 1-10: Borrow limits set to minimal values (1% expand, 720 hours duration, $10 base and max limits)
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

6. **JRUSDE-SRUSDE DEX Launch Controls**
   - Sets conservative launch limits on the JRUSDE-SRUSDE DEX (DEX ID 43)
   - Updates max supply shares to 10,000,000 to cap initial exposure
   - Points the associated smart lending rebalancer to the Reserve Contract
   - Removes Team Multisig authorization on the DEX after configuration

## Conclusion

IGP-112 completes the Reserve contract allowance cleanup from IGP110 by revoking 17 leftover protocol-token allowance pairs, reduces limits on the oldest v1 vaults (IDs 1-10) to allow exits while preventing new activity, max restricts the deUSD-USDC DEX by setting max supply shares to 10, updates the Lite treasury from the main treasury to the Reserve Contract, reduces liquidation penalties on all USDT debt vaults with vault-specific reductions, and launches the JRUSDE-SRUSDE DEX with controlled limits, supply caps, and governance cleanup. These changes improve protocol security, centralize revenue management across Fluid and Lite platforms, cap new DEX exposure, and reduce liquidation costs for users borrowing USDT.

