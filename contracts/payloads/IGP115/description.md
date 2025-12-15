## Configure OSETH T4 Vault and ETH-OSETH DEX Limits

## Summary

This proposal configures the OSETH T4 vault (Vault ID 158, oseth-eth <> wsteth-eth) and the associated ETH-OSETH DEX (ID 43) to align risk parameters, oracle/rebalancer wiring, and launch limits with the intended OSETH T4 setup. It sets the vault’s rebalancer and oracle, updates core risk settings (including CF/LT/LML/LP), increases ETH-OSETH supply caps, and applies Liquidity Layer limits for supply and vault-level withdrawal, without changing any existing borrow-side configuration on the wstETH-ETH DEX.

## Code Changes

### Action 1: Configure OSETH T4 Vault and ETH-OSETH DEX

- **Vault ID 158**<br>
  **oseth-eth <> wsteth-eth (TYPE 4)**:
  - **Rebalancer**: Set rebalancer to `FLUID_RESERVE` via `updateRebalancer(FLUID_RESERVE)`
  - **Oracle**: Set oracle using nonce `205`, pointing to the configured DexSmartPeg oracle route
  - **Risk Params (updateCoreSettings)**:
    - **Collateral Factor (CF)**: 93%
    - **Liquidation Threshold (LT)**: 95%
    - **Liquidation Max Limit (LML)**: 97%
    - **Liquidation Penalty (LP)**: 2%
    - **Rate Multipliers / Fees**: Neutral supply/borrow magnifiers (100%), zero withdraw gap, zero borrow fee

- **ETH-OSETH DEX (ID 43)**<br>
  **OSETH-ETH DEX**:
  - **Max Supply Shares**: 5,000 shares (~$33M)
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Token LL Supply Limits**:
    - **Base Withdrawal Limit**: $14,000,000 each for OSETH and ETH
    - **Expand Percent / Duration**: 50% expand over 1 hour (inherited from shared helper logic)
  - **Vault-Specific Supply Config (OSETH T4 Vault)**:
    - **User**: OSETH T4 vault (ID 158)
    - **Base Withdrawal Limit**: $8,000,000
    - **Expand Percent / Duration**: 50% expand over 1 hour
    - **Applied via**: `updateUserSupplyConfigs` on the ETH-OSETH DEX

## Description

The OSETH T4 vault (Vault ID 158, oseth-eth <> wsteth-eth) previously received dust and launch limits across IGP113 and IGP114, but its rebalancer, oracle, and core risk settings, as well as ETH-OSETH DEX supply limits, required a dedicated configuration pass. This proposal wires the vault to use the Reserve contract as rebalancer, sets the oracle using nonce 205 to follow the intended DexSmartPeg route, and applies T4-specific risk parameters (93% CF, 95% LT, 97% LML, 2% LP) via `updateCoreSettings`. On the ETH-OSETH DEX, it raises max supply shares to 5,000 (~$33M), configures Liquidity Layer supply limits of $14M per side (OSETH and ETH), and sets a vault-specific base withdrawal limit of $8M for the OSETH T4 vault with standard expansion behavior, ensuring consistent and scalable OSETH T4 behavior on the supply side.

## Conclusion

IGP-115 is a focused configuration proposal that finalizes the OSETH T4 vault and ETH-OSETH DEX setup by wiring the correct rebalancer, oracle, and risk parameters, and by setting consistent supply caps and Liquidity Layer limits. It does not introduce new borrow-side changes on the wstETH-ETH DEX beyond what was established in prior proposals, but instead completes the remaining configuration needed for OSETH T4 to operate with the intended safety margins and launch limits.
