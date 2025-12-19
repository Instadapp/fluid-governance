## Update OSETH Launch Limits, Configure OSETH T2 Vault, and Deprecate OSETH T4 Vault

## Summary

This proposal makes three coordinated changes around the OSETH ecosystem: (1) re-applies the OSETH launch limits from IGP114 for the OSETH-ETH DEX and vaults 153–157, excluding the T4 configuration, (2) configures the new OSETH T2 vault (Vault ID 159) and its ETH-OSETH DEX limits, including rebalancer/oracle wiring and LL dust/launch limits, and (3) deprecates the existing OSETH T4 vault (Vault ID 158) by pausing its supply and borrow paths at the DEX level and max-restricting its LL limits. Together, these changes move OSETH leverage and liquidity from the deprecated T4 structure to the new T2 vault while preserving the previously agreed OSETH launch parameters.

## Code Changes

### Action 1: Re-apply OSETH Launch Limits (Without T4)

- **ETH-OSETH DEX (ID 43)**<br>
  **OSETH-ETH DEX**:
  - **Base Withdrawal Limit**: $14,000,000
  - **Smart Collateral**: Enabled
  - **Smart Debt**: Disabled
  - **Authorization**: Remove Team Multisig auth (`setDexAuth(dex, TEAM_MULTISIG, false)`)

- **Vaults 153–158 (OSETH Type 1/3/4 vaults)**:
  - **Vault ID 153 – OSETH/USDC (TYPE 1)**:
    - **Base Withdrawal Limit**: $8,000,000
    - **Base Borrow Limit**: $5,000,000
    - **Max Borrow Limit**: $10,000,000
    - **Authorization**: Remove Team Multisig auth
  - **Vault ID 154 – OSETH/USDT (TYPE 1)**:
    - Same limits as Vault 153, with USDT as borrow token
  - **Vault ID 155 – OSETH/GHO (TYPE 1)**:
    - Same limits as Vault 153, with GHO as borrow token
  - **Vault ID 156 – OSETH/USDC-USDT (TYPE 3)**:
    - **Base Withdrawal Limit**: $8,000,000
    - Borrow limits pushed to the USDC-USDT DEX (ID 2) via `setDexBorrowProtocolLimitsInShares`
    - **DEX Borrow Limit**: ~2.5M shares ($5M) base, ~5M shares ($10M) max
    - **Authorization**: Remove Team Multisig auth
  - **Vault ID 157 – OSETH/USDC-USDT Concentrated (TYPE 3)**:
    - Same pattern as Vault 156 but on the concentrated USDC-USDT DEX (ID 34), with the same DEX share limits and removal of Team Multisig auth

### Action 2: Configure OSETH T2 Vault (Vault ID 159) and ETH-OSETH DEX Limits

- **Vault ID 159**<br>
  **oseth-eth <> wsteth (TYPE 2)**:
  - **Rebalancer**: Set to `FLUID_RESERVE` via `updateRebalancer(FLUID_RESERVE)`
  - **Oracle**: Set using nonce `207` via `updateOracle(207)`
  - **Risk Params (updateCoreSettings on T2 interface)**:
    - **Supply Rate**: 0%
    - **Borrow Rate Magnifier**: 100%
    - **Collateral Factor (CF)**: 94%
    - **Liquidation Threshold (LT)**: 96%
    - **Liquidation Max Limit (LML)**: 97%
    - **Withdraw Gap**: 5%
    - **Liquidation Penalty**: 2%
    - **Borrow Fee**: 0%
  - **Liquidity Layer Borrow Limits**:
    - **Base Borrow Limit**: $8,000,000
    - **Max Borrow Limit**: $30,000,000

- **ETH-OSETH DEX (ID 43) – T2 Launch Limits**:
  - **Max Supply Shares**: 5,700 shares (~$33M)
  - **Vault-Specific Supply Config (T2 Vault 159)**:
    - **User**: OSETH T2 vault (ID 159)
    - **Base Withdrawal Limit**: ~$8M (represented as 1,400 shares)
    - **Expand Percent / Duration**: 35% expand over 6 hours
    - **Applied via**: `updateUserSupplyConfigs` on the ETH-OSETH DEX

### Action 3: Deprecate OSETH T4 Vault (Vault ID 158)

- **Vault ID 158**<br>
  **OSETH-ETH <> wstETH-ETH (TYPE 4)**:
  - **Pause Supply Side (ETH-OSETH DEX, ID 43)**:
    - Apply `setSupplyProtocolLimitsPausedDex` to max-restrict LL supply limits for the T4 vault user on the ETH-OSETH DEX
    - Call `pauseUser(vault, true, false)` on the ETH-OSETH DEX to pause supply-side operations for the T4 vault
  - **Pause Borrow Side (wstETH-ETH DEX, ID 1)**:
    - Apply `setBorrowProtocolLimitsPausedDex` to max-restrict LL borrow limits for the T4 vault user on the wstETH-ETH DEX
    - Call `pauseUser(vault, false, true)` on the wstETH-ETH DEX to pause borrow-side operations for the T4 vault

## Description

The OSETH suite was initially launched via a mix of dust and launch limit proposals (IGP113 and IGP114), including a T4 vault (Vault 158) that is no longer the preferred structure. This proposal first re-applies the OSETH launch limits from IGP114 for the OSETH-ETH DEX and vaults 153–157, keeping their parameters intact while explicitly omitting any T4-specific changes. It then introduces and fully configures a new T2 vault (Vault 159) with dedicated oracle, rebalancer, and risk settings, plus ETH-OSETH DEX and Liquidity Layer limits aligned with a safer, simpler leverage path. Finally, it deprecates the old T4 vault by pausing its supply and borrow routes at the DEX level and max-restricting its LL limits, effectively preventing new usage while allowing existing positions to be managed under strict controls.

## Conclusion

IGP-115 rectifies and simplifies the OSETH leverage architecture by retaining the previously agreed OSETH launch limits, migrating new leverage flows to a purpose-built T2 vault (ID 159), and cleanly deprecating the legacy T4 vault (ID 158). This keeps risk parameters and limits consistent with prior governance intent while ensuring that future activity flows through the more robust T2 design rather than the deprecated T4 structure.