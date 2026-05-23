# Upgrade Liquidity Layer Modules, Rotate Pause/Rates/Range Auths, and Tighten Legacy Vault Withdrawal Limits

## Summary

This proposal performs eight Ethereum actions: (1–2) register and upgrade the Liquidity Layer **UserModule** on the InfiniteProxy with RollbackModule safety; (3–4) register and upgrade the **AdminModule** the same way; (5) rotate Liquidity Layer guardian and DexFactory pause auths; (6) rotate Liquidity Layer rates auth; (7) rotate DexFactory range auth; (8) reduce base withdrawal limits on legacy mainnet vaults **1–10** to **total supply + 5%** (raw supply-token units, max-restricted expansion). New module and auth addresses are configurable by Team Multisig before execution.

## Code Changes

### Action 1: Register UserModule Upgrade on RollbackModule

- **Old Implementation**: `0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7`
- **New Implementation**: Configurable via `setNewUserModuleAddress()` by Team Multisig
- **Purpose**: Register the current UserModule on the RollbackModule before upgrade so it can be restored within the rollback safety period if needed

### Action 2: Upgrade UserModule on Liquidity Layer

- **Old Implementation**: `0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7`
- **New Implementation**: Configurable via `setNewUserModuleAddress()` by Team Multisig
- **Purpose**: Replace the UserModule on the Liquidity Layer InfiniteProxy while preserving the existing set of function selectors

### Action 3: Register AdminModule Upgrade on RollbackModule

- **Old Implementation**: `0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`
- **New Implementation**: Configurable via `setNewAdminModuleAddress()` by Team Multisig
- **Purpose**: Register the current AdminModule on the RollbackModule before upgrade so it can be restored within the rollback safety period if needed

### Action 4: Upgrade AdminModule on Liquidity Layer

- **Old Implementation**: `0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E`
- **New Implementation**: Configurable via `setNewAdminModuleAddress()` by Team Multisig
- **Purpose**: Replace the AdminModule on the Liquidity Layer InfiniteProxy while preserving the existing set of function selectors

### Action 5: Rotate Pause Auths on Liquidity Layer and DexFactory

- **Liquidity Layer Guardian**
  - **Old Auth**: `0xE9332F2d45e3216B7634cA4C7ab88945CD84ab76` (removed)
  - **New Auth**: Configurable via `setPauseAuths()` by Team Multisig
- **DexFactory Pause Auth**
  - **Old Auth**: `0x735BA3772c2cCC0b92Ff6993bd71da88236C1495` (removed)
  - **New Auth**: Configurable via `setPauseAuths()` by Team Multisig

### Action 6: Rotate Liquidity Layer Rates Auth

- **Old Auth**: `0x1e6B029284dc2779F8FfBD83a3a5aA00EdCE6ba4` (removed)
- **New Auth**: Configurable via `setNewRatesAuth()` by Team Multisig

### Action 7: Rotate DexFactory Range Auth

- **Old Auth**: `0x827089c01E9f761ff1A6D7041a9388bDdae74cc4` (removed)
- **New Auth**: Configurable via `setNewRangeAuth()` by Team Multisig

### Action 8: Reduce Base Withdrawal Limits on Legacy Vaults 1–10

Sets each vault’s Liquidity Layer base withdrawal limit to **current total supply + 5%** in raw supply-token units, with max-restricted expansion (`0.01%`, max duration). Borrow limits are unchanged.

| Vault | Pair | Supply token | New base withdrawal limit |
| --- | --- | --- | --- |
| 1 | ETH / USDC | ETH | `0.628187` ETH |
| 2 | ETH / USDT | ETH | `0.945974` ETH |
| 3 | wstETH / ETH | wstETH | `0.646899` wstETH |
| 4 | wstETH / USDC | wstETH | `0.544134` wstETH |
| 5 | wstETH / USDT | wstETH | `0.549870` wstETH |
| 6 | weETH / wstETH | weETH | `695.132095` weETH |
| 7 | sUSDe / USDC | sUSDe | `3298.946018` sUSDe |
| 8 | sUSDe / USDT | sUSDe | `413.657754` sUSDe |
| 9 | weETH / USDC | weETH | `0.240487` weETH |
| 10 | weETH / USDT | weETH | `0.213728` weETH |

## Description

**Actions 1–4** upgrade the Liquidity Layer UserModule and AdminModule via RollbackModule registration followed by InfiniteProxy replacement, preserving function selectors. **Action 5** rotates pause guardians on the Liquidity Layer and DexFactory. **Actions 6–7** rotate rates and range auths. **Action 8** aligns legacy vault withdrawal headroom with on-chain supply so existing depositors can exit without leaving oversized withdrawal buffers from earlier limit settings.

### Configurable Addresses (Team Multisig sets before execution)

| Variable | Purpose |
| --- | --- |
| `newUserModuleAddress` | New UserModule implementation for the Liquidity Layer InfiniteProxy |
| `newAdminModuleAddress` | New AdminModule implementation for the Liquidity Layer InfiniteProxy |
| `liquidityPauseAuth` | New guardian on the Liquidity Layer |
| `dexPauseAuth` | New DexFactory global auth for pausing |
| `newRatesAuth` | New rates auth on the Liquidity Layer |
| `newRangeAuth` | New DexFactory global auth for range updates |

Each configurable group has a Team Multisig-only `lock…()` function to freeze its values before execution. Values must be set before the proposal executes; any action that depends on a configurable address reverts if that address is still unset.

## Conclusion

IGP-132 upgrades Liquidity Layer UserModule and AdminModule with rollback safety, rotates pause/rates/range authorization on the Liquidity Layer and DexFactory, and tightens base withdrawal limits on legacy vaults 1–10 to total supply plus a 5% buffer. Module and auth addresses are supplied by Team Multisig before execution.
