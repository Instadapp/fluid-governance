# Wind Down the tBTC Vaults 88, 89 and 90 to Exit-Only

## Summary

This proposal sets the three mainnet **tBTC T1 vaults** (88 tBTC/USDC, 89 tBTC/USDT, 90 tBTC/GHO) to exit-only at the Liquidity Layer. Borrow limits are fully restricted to dust, tBTC withdrawal limits are set to current supply plus a 20% buffer, and the vaults are unpaused so users can repay and withdraw. No new borrow is possible.

## Code Changes

### Action 1: Restrict Borrow, Set Withdrawal Limits and Unpause the tBTC Vaults

| Vault | Address | Collateral / Debt | tBTC supply (block 26313811) | Debt at Liquidity Layer |
| --- | --- | --- | --- | --- |
| 88 | `0xd312bf768de0c9e3709fF707AB4847B197A49160` | tBTC / USDC | ≈0.5589 tBTC (≈$43k) | ≈22,072 USDC |
| 89 | `0x888f89dd277a3e69C3607f67dEd93877ED359ba7` | tBTC / USDT | ≈1.1440 tBTC (≈$89k) | ≈53,392 USDT |
| 90 | `0x1810278703934B8E9e68cf535bDBB46d920F0470` | tBTC / GHO | ≈0.0004 tBTC (≈$31) | ≈11.31 GHO |

| Step | Call | Effect |
| --- | --- | --- |
| Borrow | `setBorrowProtocolLimitsPaused` for USDC / USDT / GHO | Debt ceiling `10 / 20` (dust), expansion 0.01% over max duration. Repayments still work. |
| Supply | `LIQUIDITY.updateUserSupplyConfigs` for tBTC | Base withdrawal limit = supply + 20%: **0.6707 / 1.3729 / 0.0005 tBTC**, expansion **10% over 12 hours** |
| Unpause | `LIQUIDITY.unpauseUser(vault, [tBTC], [debt token])` | Supply and borrow legs unpaused at the Liquidity Layer |

The Team Multisig pauses the three vaults at the Liquidity Layer (both legs) in the meantime. `unpauseUser` reverts for a leg that is not paused, so the payload reads each leg's pause bit and only unpauses the paused legs. The action runs whether or not the Team Multisig pause was executed.

## Description

1. **tBTC vaults 88 / 89 / 90**: closes all new borrowing and reopens the vaults for exits only. The withdrawal limits sit 20% above current supply, so every user can withdraw their full collateral after repaying.

## Conclusion

IGP-143 moves the tBTC vaults 88, 89 and 90 to exit-only: borrow restricted to dust, withdrawal limits at current supply + 20% (10% expansion over 12 hours), and the vaults unpaused at the Liquidity Layer.
