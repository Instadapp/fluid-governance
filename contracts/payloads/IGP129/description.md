# Treasury Withdrawal, Liquidity Layer Module Upgrades, Pause Auths, Rates Auth, and Range Auth Updates

## Summary

This proposal prepares the following Ethereum actions:

1. Withdraws funds from the Treasury DSA to Team Multisig. Token and amount are left as in-code placeholders to fill before finalizing IGP129.
2. Registers and executes a Liquidity Layer UserModule upgrade via the RollbackModule.
3. Registers and executes a Liquidity Layer AdminModule upgrade via the RollbackModule.
4. Replaces the pause auth contracts for the Liquidity Layer and DexFactory.
5. Rotates the Liquidity Layer rates auth from the hardcoded old auth to the new auth.
6. Rotates the DexFactory range auth from the hardcoded old auth to the new auth.
7. Sets vault 142 (wstUSR / USDtb) wstUSR base withdrawal limit to exactly `24 * 1e18` raw units while keeping max-restricted expansion settings.
8. Temporarily raises selected wstUSR vault borrow caps just enough to execute reserve rebalances, then restores max-restricted borrow caps.
9. Withdraws `750_000 * 1e18` FLUID from Treasury to Team Multisig to fund FLUID rewards.
10. Reserves a placeholder action for PST-related protocol dust limits.
11. Reserves a placeholder action to remove DSA connector Chief auths and keep only main multisig auth.
12. Reserves a placeholder action to remove multisig auth from Lite.

New implementation and auth addresses are configurable by Team Multisig before governance execution. The old Liquidity Layer module addresses are hardcoded, and the treasury withdrawal token address and amount are intentionally not Team Multisig-configurable.

## Configurable Values

- `newUserModuleAddress`: new Liquidity Layer UserModule implementation. The old implementation is hardcoded as `0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7`.
- `newAdminModuleAddress`: new Liquidity Layer AdminModule implementation. The old implementation is hardcoded as `0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`.
- `liquidityPauseAuth` and `dexPauseAuth`: new pause auth contracts for Liquidity Layer guardian and DexFactory global auth. The old pause auths are hardcoded and removed in the same action.
- `newRatesAuth`: new rates auth for the Liquidity Layer. The old rates auth is hardcoded as `0x1e6B029284dc2779F8FfBD83a3a5aA00EdCE6ba4`.
- `newRangeAuth`: new range auth for DexFactory. The old range auth is hardcoded as `0x827089c01E9f761ff1A6D7041a9388bDdae74cc4`.

Each configurable group has a Team Multisig-only lock function to freeze values before execution.

## wstUSR Rebalance Prep

Action 10 temporarily sets base and max borrow limits to rounded-up values with buffer for vaults 110, 111, 112, 133, 134, and 135. The expansion settings remain max-restricted (`0.01%`, max duration). It grants Timelock reserve rebalancer permissions, rebalances those vaults, restores their max-restricted borrow limits, and removes the temporary rebalancer permission again.

Vaults 142, 143, and 144 are intentionally skipped for this rebalance action.

No wstUSR revenue collection is included because no wstUSR revenue is expected.
