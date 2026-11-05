# IGP-X: Liquidity Layer Module Upgrades and Auth Rotations

## Summary

Staging payload split from IGP-133. Executes **seven actions** that register and upgrade the Liquidity Layer **UserModule** and **AdminModule** on the InfiniteProxy (with RollbackModule safety), then rotate Liquidity Layer guardian, DexFactory pause, rates, and range auths. All new implementation and auth addresses are configurable by Team Multisig before execution.

Assign `PROPOSAL_ID` in `PayloadIGPX.sol` before proposing on governance.

## Configurable Values (Team Multisig sets before execution)

| Variable | Purpose |
| --- | --- |
| `newUserModuleAddress` | New UserModule implementation |
| `newAdminModuleAddress` | New AdminModule implementation |
| `liquidityPauseAuth` | New Liquidity Layer guardian |
| `dexPauseAuth` | New DexFactory pause global auth |
| `newRatesAuth` | New Liquidity Layer rates auth |
| `newRangeAuth` | New DexFactory range global auth |

Module and auth groups have Team Multisig-only `lock…()` functions. Unset addresses cause the dependent action to revert.

### Old addresses (mainnet)

| Role | Address |
| --- | --- |
| Old UserModule | `0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7` |
| Old AdminModule | `0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E` |
| Old Liquidity pause auth | `0xE9332F2d45e3216B7634cA4C7ab88945CD84ab76` |
| Old Dex pause auth | `0x735BA3772c2cCC0b92Ff6993bd71da88236C1495` |
| Old rates auth | `0x1e6B029284dc2779F8FfBD83a3a5aA00EdCE6ba4` |
| Old range auth | `0x827089c01E9f761ff1A6D7041a9388bDdae74cc4` |

## Code Changes

### Action 1: Register UserModule LL upgrade on RollbackModule

- Read `newUserModuleAddress` from payload (must be non-zero).
- `IFluidLiquidityRollback(LIQUIDITY).registerRollbackImplementation(OLD_USER_MODULE, newUserModule_)`.

### Action 2: Upgrade UserModule LL on InfiniteProxy

- Read `newUserModuleAddress` from payload.
- Copy implementation sigs from `OLD_USER_MODULE`, remove old impl, add new impl with same sigs.

### Action 3: Register AdminModule LL upgrade on RollbackModule

- Read `newAdminModuleAddress` from payload (must be non-zero).
- `registerRollbackImplementation(OLD_ADMIN_MODULE, newAdminModule_)`.

### Action 4: Upgrade AdminModule LL on InfiniteProxy

- Same pattern as Action 2 for AdminModule.

### Action 5: Set new pause auth contracts

- Liquidity: `updateGuardians` — disable `OLD_LIQUIDITY_PAUSE_AUTH`, enable `liquidityPauseAuth`.
- DexFactory: `setGlobalAuth(OLD_DEX_PAUSE_AUTH, false)`, `setGlobalAuth(dexPauseAuth, true)`.

### Action 6: Update Rates Auth on Liquidity Layer

- `updateAuths` — disable `OLD_RATES_AUTH`, enable `newRatesAuth`.

### Action 7: Update Ranges Auth on DexFactory

- `setGlobalAuth(OLD_RANGE_AUTH, false)`, `setGlobalAuth(newRangeAuth, true)`.

## Conclusion

IGP-X upgrades Liquidity Layer UserModule and AdminModule with rollback safety, then rotates pause / rates / range auths. Supply and borrow limit changes remain on IGP-133.
