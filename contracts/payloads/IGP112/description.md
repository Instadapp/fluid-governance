# Cleanup Leftover Reserve Allowances from IGP110, Pause Old V1 Vaults, Max Restrict deUSD DEX, Update Lite Treasury, and Update USDT Debt Vault Liquidation Penalties

## Summary

This proposal implements five key operations: (1) cleans up leftover allowances from the Reserve contract that were not properly revoked in IGP110 due to a protocol-token array mismatch, (2) completely pauses very old v1 vaults (IDs 1-10), (3) max restricts the deUSD-USDC DEX, (4) updates the Lite treasury from the main treasury to the Reserve Contract, and (5) updates liquidation penalties on all USDT debt vaults with vault-specific reductions. The proposal revokes 17 protocol-token allowance pairs that remained after IGP110 execution, completely pauses the oldest vaults in the protocol, max restricts the deUSD-USDC DEX, routes Lite revenue collection to the Reserve Contract instead of the main treasury, and reduces liquidation penalties across all USDT debt vaults to improve user experience.

## Code Changes

### Action 1: Cleanup Leftover Allowances from Reserve Contract

- **Reserve Contract Operation**:
  - Revoke allowances for 17 protocol-token pairs from Reserve Contract Proxy
  - These are leftover allowances from IGP110 that were not properly cleaned up due to a protocol-token array mismatch that occurred after array element 20
  - **Protocols**: 17 different protocol addresses (various vaults and protocols)
  - **Tokens**: USDT and USDC
  - **Allowance Amounts**: Range from significant amounts (e.g., 65,890 USDT, 65,463 USDC) to smaller dust amounts (100 USDT/USDC)
  - **Purpose**: Complete the Reserve contract allowance cleanup that was started in IGP110 by removing all remaining unnecessary allowances

### Action 2: Pause Very Old V1 Vaults

- **Vault Pausing**:
  - Completely pause vaults with IDs 1-10
  - **Vaults Affected**: Vault IDs 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
  - **Supply Limits**: Paused with minimal limits (0.01% expand, max duration)
  - **Borrow Limits**: Paused with minimal limits (0.01% expand, max duration)
  - **User Operations**: Paused for both supply and borrow operations
  - **Purpose**: Totally pause these very old v1 vaults that are no longer in active use

### Action 3: Max Restrict deUSD-USDC DEX

- **DEX Pool 19**<br>
  **deUSD-USDC DEX**:
  - **Supply Limits**: Paused for both tokens (deUSD and USDC) with minimal limits (0.01% expand, max duration)
  - **User Operations**: Paused for supply operations (DEX doesn't have borrow capabilities)
  - **Max Supply Shares**: Set to 0
  - **Swap and Arbitrage**: Paused
  - **Purpose**: Completely max restrict the deUSD-USDC DEX by pausing supply limits, user operations, setting max supply shares to 0, and pausing swap and arbitrage to eliminate all exposure to deUSD

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

## Description

This proposal addresses five cleanup, security enhancement, operational management, and parameter standardization tasks:

1. **Reserve Contract Security Enhancement**
   - Completes the allowance cleanup process that was initiated in IGP110
   - Addresses a cleanup issue from IGP110 where not all Reserve contract allowances were properly revoked due to a protocol-token array mismatch that occurred after array element 20
   - Revokes 17 remaining protocol-token allowance pairs that were missed due to the array mismatch
   - Removes unnecessary allowances for protocols that no longer have rewards running or had dust allowances
   - The allowances being revoked include both significant amounts (e.g., 65,890 USDT, 65,463 USDC) and smaller dust amounts (100 USDT/USDC), ensuring complete cleanup of all leftover permissions
   - Improves security posture by reducing attack surface and potential misuse of unused allowances
   - Standardizes the protocol approach to explicitly grant allowances only when needed

2. **Old V1 Vault Pausing**
   - Completely pauses the very oldest vaults in the protocol (vault IDs 1-10)
   - These vaults represent the earliest vault deployments and are no longer in active use
   - Pauses both supply and borrow limits with minimal expand parameters (0.01% expand, max duration)
   - Pauses all user operations (supply and borrow) for these vaults
   - Effectively disables these vaults by preventing any new deposits and borrows
   - Improves protocol security by reducing the attack surface of legacy vault implementations
   - Maintains protocol cleanliness by pausing deprecated vaults

3. **deUSD-USDC DEX Max Restriction**
   - Max restricts the deUSD-USDC DEX (DEX ID 19)
   - Pauses supply limits for both tokens (deUSD and USDC) with minimal expand parameters (0.01% expand, max duration)
   - Pauses user operations for supply operations (DEX doesn't have borrow capabilities)
   - Sets max supply shares to 0 to prevent any new deposits
   - Pauses swap and arbitrage operations
   - Effectively disables the DEX by preventing any new deposits, swaps, or arbitrage
   - Maintains protocol risk management by completely eliminating exposure to deUSD

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

## Conclusion

IGP-112 completes the Reserve contract allowance cleanup from IGP110 by revoking 17 leftover protocol-token allowance pairs, pauses the oldest v1 vaults (IDs 1-10), max restricts the deUSD-USDC DEX, updates the Lite treasury from the main treasury to the Reserve Contract, and reduces liquidation penalties on all USDT debt vaults with vault-specific reductions. These changes improve protocol security, centralize revenue management across Fluid and Lite platforms, and reduce liquidation costs for users borrowing USDT.

