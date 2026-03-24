# wstUSR Migration Prep, Liquidity Layer Upgrades, Pauseable Auth, and VaultFactory Ownership Transfer

## Summary

This proposal implements protocol updates across four areas: (1) adds Team Multisig authorization on active wstUSR vaults and DEXes, max-restricts their borrow limits, and pauses swapAndArbitrage to prepare for wstUSR migration, (2) upgrades the Liquidity Layer UserModule and DummyImplementation via the RollbackModule with rollback safety registrations, and adds a new LL auth for `operateOnBehalfOf`, (3) registers pauseable auth contracts on the Liquidity Layer and DexFactory for emergency pause capabilities, and (4) transfers VaultFactory ownership to enable a position transfer wrapper.

All implementation addresses (`userModuleAddress`, `dummyImplementationAddress`, `onBehalfOfAuth`, `vaultFactoryOwner`, `pauseableAuth`, `pausableDexAuth`) are configurable by Team Multisig before governance execution.

## Code Changes

### Action 1: Add Team Multisig as Auth on wstUSR Vaults and DEXes

Adds Team Multisig as authorized on all active wstUSR-related vaults and DEXes to enable emergency operations during the migration period.

**Vaults** (via `setVaultAuth`):
- Vault 110 — wstUSR / USDC (T1)
- Vault 111 — wstUSR / USDT (T1)
- Vault 112 — wstUSR / GHO (T1)
- Vault 133 — wstUSR-USDC <> USDC (T2)
- Vault 134 — wstUSR-USDC <> USDC-USDT (T4)
- Vault 135 — wstUSR-USDC <> USDC-USDT concentrated (T3)
- Vault 143 — wstUSR <> USDC-USDT (T3)
- Vault 144 — wstUSR <> USDC-USDT concentrated (T3)

**DEXes** (via `setDexAuth`):
- DEX Pool 27 — wstUSR-USDC

> Skipped: Vault 113, Vault 142, DEX 29 — already max-restricted / deprecated in IGP-123.

### Action 2: Register UserModule Upgrade on RollbackModule

- Calls `registerRollbackImplementation(OLD_USER_MODULE, userModuleAddress)` on the Liquidity Layer
- Captures the current UserModule (`0x2e4015880367b7C2613Df77f816739D97A8C46aD`) for rollback safety before the upgrade
- Requires `userModuleAddress` to be set by Team Multisig before execution

### Action 3: Upgrade UserModule on Liquidity Layer

- Removes the old UserModule (`0x2e4015880367b7C2613Df77f816739D97A8C46aD`) from the InfiniteProxy
- Adds the new `userModuleAddress` with all existing function selectors **plus** the new `operateOnBehalfOf(address,address,int256,int256,bytes)` selector
- Requires `userModuleAddress` to be set by Team Multisig before execution

### Action 4: Register DummyImplementation Rollback on RollbackModule

- Calls `registerRollbackDummyImplementation()` on the Liquidity Layer
- Captures the current DummyImplementation for rollback safety before the update

### Action 5: Update DummyImplementation on Liquidity Layer

- Calls `setDummyImplementation(dummyImplementationAddress)` on the InfiniteProxy
- Requires `dummyImplementationAddress` to be set by Team Multisig before execution

### Action 6: Add Liquidity Layer Auth for operateOnBehalfOf

- Calls `LIQUIDITY.updateAuths()` to add `onBehalfOfAuth` as an authorized address on the Liquidity Layer
- Enables the authorized contract to call `operateOnBehalfOf` on behalf of users
- Requires `onBehalfOfAuth` to be set by Team Multisig before execution

### Action 7: Transfer VaultFactory Ownership

- Calls `transferOwnership(vaultFactoryOwner)` on the VaultFactory
- Enables the new owner contract to manage vault position transfers
- Requires `vaultFactoryOwner` to be set by Team Multisig before execution

### Action 8: Max-Restrict Borrow Limits on wstUSR Vaults

Applies max-restriction borrow protocol limits (0.01% expand, max duration, minimal ceilings) to effectively cap new borrows at near-zero without pausing the vaults.

**At Liquidity Layer** (via `setBorrowProtocolLimitsPaused`):
- Vault 110 — wstUSR / USDC → restricts USDC borrowing
- Vault 111 — wstUSR / USDT → restricts USDT borrowing
- Vault 112 — wstUSR / GHO → restricts GHO borrowing
- Vault 133 — wstUSR-USDC <> USDC → restricts USDC borrowing

**At DEX Level** (via `setBorrowProtocolLimitsPausedDex`):
- Vault 134 — borrows from USDC-USDT DEX (Pool 2)
- Vault 143 — borrows from USDC-USDT DEX (Pool 2)
- Vault 144 — borrows from USDC-USDT concentrated DEX (Pool 34)

> Skipped: Vault 113, Vault 135, Vault 142 — already max-restricted / deprecated in IGP-123.

### Action 9: Pause swapAndArbitrage on wstUSR DEXes

- Calls `pauseSwapAndArbitrage()` on DEX Pool 27 (wstUSR-USDC)

> Skipped: DEX Pool 29 (wstUSR-USDT) — already max-restricted / deprecated in IGP-123.

### Action 10: Set Pauseable Auth on Liquidity Layer

- Calls `LIQUIDITY.updateAuths()` to add `pauseableAuth` as an authorized address on the Liquidity Layer
- Enables the pauseable contract to execute emergency pauses on LL protocols
- Requires `pauseableAuth` to be set by Team Multisig before execution

### Action 11: Set Pausable DEX Auth as Global Auth on DexFactory

- Calls `DEX_FACTORY.setGlobalAuth(pausableDexAuth, true)` to grant global auth on DexFactory
- Enables the pausable contract to execute emergency pauses on DEX protocols
- Requires `pausableDexAuth` to be set by Team Multisig before execution

## Description

This proposal covers four areas of protocol maintenance and infrastructure upgrades:

1. **wstUSR Migration Preparation**
   - Adds Team Multisig as authorized on 8 active wstUSR vaults (110, 111, 112, 133, 134, 135, 143, 144) and DEX Pool 27 to enable emergency operations during the migration period
   - Max-restricts borrow limits on all active wstUSR vaults (110, 111, 112, 133 at LL; 134, 143, 144 at DEX level) to prevent new borrowing while allowing existing users to manage and exit positions
   - Pauses `swapAndArbitrage` on the wstUSR-USDC DEX (Pool 27) to halt trading activity
   - Vaults 113, 142, 135 and DEX 29 are excluded as they were already deprecated and max-restricted in IGP-123

2. **Liquidity Layer Upgrades via RollbackModule**
   - Upgrades the UserModule on the Liquidity Layer's InfiniteProxy to a new implementation that adds support for `operateOnBehalfOf`. Both the old UserModule and the old DummyImplementation are registered on the RollbackModule before replacement, enabling rollback within the safety period if issues are discovered
   - Updates the DummyImplementation on the InfiniteProxy to a new version
   - Adds a new authorized address (`onBehalfOfAuth`) on the Liquidity Layer to enable delegated operations via `operateOnBehalfOf`
   - All upgrade addresses are configurable by Team Multisig before governance execution for operational flexibility

3. **Pauseable Auth Registration**
   - Registers `pauseableAuth` as an authorized address on the Liquidity Layer and `pausableDexAuth` as a global auth on DexFactory
   - Enables dedicated pause contracts to execute emergency pauses on both LL and DEX protocols without requiring a full governance proposal
   - Both addresses are configurable by Team Multisig before governance execution

4. **VaultFactory Ownership Transfer**
   - Transfers VaultFactory ownership to a new contract (`vaultFactoryOwner`) to enable a position transfer wrapper that allows users to transfer vault positions
   - The new owner address is configurable by Team Multisig before governance execution

### Configurable Addresses (Team Multisig sets before execution)

| Variable | Purpose |
|---|---|
| `userModuleAddress` | New UserModule implementation for Liquidity Layer |
| `dummyImplementationAddress` | New DummyImplementation for Liquidity Layer InfiniteProxy |
| `onBehalfOfAuth` | Contract authorized for `operateOnBehalfOf` on Liquidity Layer |
| `vaultFactoryOwner` | New owner of VaultFactory (position transfer wrapper) |
| `pauseableAuth` | Contract authorized for emergency pauses on Liquidity Layer |
| `pausableDexAuth` | Contract authorized as global auth on DexFactory for emergency pauses |

## Conclusion

IGP-126 prepares the wstUSR ecosystem for migration by adding Team Multisig authorization and max-restricting borrow limits across active vaults, upgrades the Liquidity Layer with a new UserModule (adding `operateOnBehalfOf` support) and DummyImplementation via the RollbackModule for safe rollback capability, registers pauseable auth contracts on both the Liquidity Layer and DexFactory for emergency response, and transfers VaultFactory ownership to enable position transfers. Existing users in wstUSR markets can still manage and exit their positions.
