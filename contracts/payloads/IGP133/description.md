# IGP-133: Liquidity Layer Upgrades and Borrow Limit Risk Tightening

## Summary

This proposal combines infrastructure upgrades moved from the original IGP-132 draft with borrow-side risk tightening on **66 less-trusted Ethereum vaults**.

**Actions 1–7** register and upgrade the Liquidity Layer **UserModule** and **AdminModule** on the InfiniteProxy (with RollbackModule safety), then rotate Liquidity Layer guardian, DexFactory pause, rates, and range auths. All new implementation and auth addresses are configurable by Team Multisig before execution.

**Actions 8–11** lower base/max debt ceilings, cut borrow expansion to **25%** (or **10%** on the largest pools), and shorten the borrow expansion window from **6h to 3h** on every affected vault. Action 8 updates 54 vaults at the Liquidity Layer; Actions 9–11 update smart-debt vaults on three DEXes.

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

### Action 8: Tighten Liquidity Layer Borrow Limits (54 vaults)

Batched into one `LIQUIDITY.updateUserBorrowConfigs(...)` call. Expansion window for every row goes **6h → 3h**. Base / max columns show **old → new** USD.

| Vault | Market | Type | Debt token | Base (old → new) | Max (old → new) | Expand % | Override price |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 16 | weETH / wstETH | T1 | wstETH | $11.70M → **$2.50M** | $175.51M → **$25M** | 50% → **25%** | $2,620.73 |
| 18 | sUSDe / USDT | T1 | USDT | $12.89M → **$2.50M** | $64.47M → **$25M** | 50% → **25%** | $0.999409 |
| 17 | sUSDe / USDC | T1 | USDC | $13.02M → **$2.50M** | $65.18M → **$25M** | 50% → **25%** | $0.99979 |
| 19 | weETH / USDC | T1 | USDC | $13.16M → **$2.50M** | $65.87M → **$25M** | 50% → **25%** | $0.99979 |
| 20 | weETH / USDT | T1 | USDT | $12.99M → **$2.50M** | $65.05M → **$25M** | 50% → **25%** | $0.999409 |
| 26 | weETH / WBTC | T1 | WBTC | $10.68M → **$100K** | $28.50M → **$1M** | 50% → **25%** | $76,897 |
| 27 | weETHs / wstETH | T1 | wstETH | $8.45M → **$1M** | $28.19M → **$5M** | 50% → **25%** | $2,620.73 |
| 32 | weETH / cbBTC | T1 | cbBTC | $10.76M → **$100K** | $50.17M → **$1M** | 50% → **25%** | $77,100 |
| 56 | sUSDe / GHO | T1 | GHO | $24.14M → **$2.50M** | $120.75M → **$25M** | 50% → **25%** | $0.999374 |
| 57 | weETH / GHO | T1 | GHO | $9.53M → **$2.50M** | $25.39M → **$25M** | 50% → **25%** | $0.999374 |
| 74 | weETH-ETH / wstETH | T2 | wstETH | $15.30M → **$2.50M** | $45.26M → **$50M** | 30% → **10%** | $2,620.73 |
| 80 | weETHs-ETH / wstETH | T2 | wstETH | $4.45M → **$1M** | $5.64M → **$2.50M** | 30% → **25%** | $2,620.73 |
| 92 | sUSDe-USDT / USDT | T2 | USDT | $21.84M → **$2.50M** | $43.67M → **$25M** | 30% → **25%** | $0.999409 |
| 93 | USDe-USDT / USDT | T2 | USDT | $15.39M → **$2.50M** | $92.39M → **$25M** | 30% → **25%** | $0.999409 |
| 94 | eBTC / WBTC | T1 | WBTC | $5.65M → **$100K** | $11.31M → **$1M** | 50% → **25%** | $76,897 |
| 96 | eBTC-cbBTC / WBTC | T2 | WBTC | $5.65M → **$100K** | $11.31M → **$1M** | 30% → **25%** | $76,897 |
| 97 | LBTC-cbBTC / WBTC | T2 | WBTC | $4.59M → **$2.50M** | $4.59M → **$25M** | 30% → **25%** | $76,897 |
| 103 | ezETH / wstETH | T1 | wstETH | $12.23M → **$100K** | $24.46M → **$1M** | 50% → **25%** | $2,620.73 |
| 104 | ezETH-ETH / wstETH | T2 | wstETH | $9.17M → **$2.50M** | $18.34M → **$25M** | 30% → **25%** | $2,620.73 |
| 107 | LBTC / USDC | T1 | USDC | $6.34M → **$2.50M** | $19.03M → **$25M** | 50% → **25%** | $0.99979 |
| 108 | LBTC / USDT | T1 | USDT | $6.28M → **$2.49M** | $18.83M → **$25M** | 50% → **25%** | $0.999409 |
| 109 | LBTC / GHO | T1 | GHO | $6.09M → **$2.50M** | $18.26M → **$25M** | 50% → **25%** | $0.999374 |
| 114 | LBTC-cbBTC / cbBTC | T2 | cbBTC | $10.13M → **$2.50M** | $29.55M → **$25M** | 30% → **25%** | $77,100 |
| 115 | WBTC-LBTC / WBTC | T2 | WBTC | $9.95M → **$2.50M** | $14.90M → **$25M** | 30% → **25%** | $76,897 |
| 116 | XAUt / USDC | T1 | USDC | $6.29M → **$2.50M** | $12.57M → **$25M** | 50% → **25%** | $0.99979 |
| 117 | XAUt / USDT | T1 | USDT | $6.23M → **$2.50M** | $12.46M → **$25M** | 50% → **25%** | $0.999409 |
| 118 | XAUt / GHO | T1 | GHO | $6.02M → **$1M** | $12.03M → **$10M** | 50% → **25%** | $0.999374 |
| 119 | PAXG / USDC | T1 | USDC | $6.29M → **$2.50M** | $12.57M → **$25M** | 50% → **25%** | $0.99979 |
| 120 | PAXG / USDT | T1 | USDT | $6.23M → **$2.50M** | $12.46M → **$25M** | 50% → **25%** | $0.999409 |
| 121 | PAXG / GHO | T1 | GHO | $6.02M → **$1M** | $12.03M → **$10M** | 50% → **25%** | $0.999374 |
| 122 | PAXG-XAUt / USDC | T2 | USDC | $6.29M → **$1M** | $12.57M → **$2.50M** | 30% → **25%** | $0.99979 |
| 123 | PAXG-XAUt / USDT | T2 | USDT | $6.23M → **$2.50M** | $12.46M → **$25M** | 30% → **25%** | $0.999409 |
| 124 | PAXG-XAUt / GHO | T2 | GHO | $6.02M → **$1M** | $12.03M → **$10M** | 30% → **25%** | $0.999374 |
| 130 | weETH / USDtb | T1 | USDtb | $8.53M → **$1M** | $16.00M → **$2.50M** | 50% → **25%** | $0.999168 |
| 137 | USDe-USDtb / USDT | T2 | USDT | $6.23M → **$1M** | $24.91M → **$10M** | 30% → **25%** | $0.999409 |
| 138 | USDe-USDtb / USDC | T2 | USDC | $6.29M → **$1M** | $25.14M → **$10M** | 30% → **25%** | $0.99979 |
| 140 | USDe-USDtb / GHO | T2 | GHO | $5.99M → **$1M** | $23.97M → **$10M** | 30% → **25%** | $0.999374 |
| 141 | GHO-USDe / GHO | T2 | GHO | $5.99M → **$1M** | $11.99M → **$10M** | 30% → **25%** | $0.999374 |
| 145 | syrupUSDC-USDC / USDC | T2 | USDC | $6.18M → **$2.50M** | $24.73M → **$25M** | 30% → **25%** | $0.99979 |
| 146 | syrupUSDC / USDC | T1 | USDC | $6.16M → **$2.50M** | $61.53M → **$25M** | 50% → **25%** | $0.99979 |
| 147 | syrupUSDC / USDT | T1 | USDT | $6.12M → **$1M** | $24.48M → **$2.50M** | 50% → **25%** | $0.999409 |
| 148 | syrupUSDC / GHO | T1 | GHO | $5.87M → **$1M** | $23.49M → **$2.50M** | 50% → **25%** | $0.999374 |
| 149 | syrupUSDT-USDT / USDT | T2 | USDT | $12.18M → **$2.50M** | $24.36M → **$25M** | 30% → **25%** | $0.999409 |
| 150 | syrupUSDT / USDC | T1 | USDC | $12.30M → **$1M** | $24.60M → **$2.50M** | 50% → **25%** | $0.99979 |
| 151 | syrupUSDT / USDT | T1 | USDT | $12.18M → **$2.50M** | $24.36M → **$25M** | 50% → **25%** | $0.999409 |
| 152 | syrupUSDT / GHO | T1 | GHO | $11.66M → **$100K** | $23.33M → **$1M** | 50% → **25%** | $0.999374 |
| 153 | osETH / USDC | T1 | USDC | $6.10M → **$100K** | $12.20M → **$1M** | 50% → **25%** | $0.99979 |
| 154 | osETH / USDT | T1 | USDT | $6.04M → **$100K** | $12.08M → **$1M** | 50% → **25%** | $0.999409 |
| 155 | osETH / GHO | T1 | GHO | $5.78M → **$100K** | $11.55M → **$1M** | 50% → **25%** | $0.999374 |
| 159 | ETH-osETH / wstETH | T2 | wstETH | $6.28M → **$2.50M** | $23.54M → **$25M** | 30% → **10%** | $2,620.73 |
| 160 | reUSD / USDC | T1 | USDC | $9.66M → **$2.50M** | $24.16M → **$20M** | 50% → **10%** | $0.99979 |
| 161 | reUSD / USDT | T1 | USDT | $9.59M → **$2.50M** | $23.95M → **$20M** | 50% → **10%** | $0.999409 |
| 162 | reUSD / GHO | T1 | GHO | $9.12M → **$2.50M** | $22.80M → **$20M** | 50% → **25%** | $0.999374 |
| 164 | reUSD-USDT / USDT | T2 | USDT | $5.99M → **$2.50M** | $11.97M → **$20M** | 30% → **10%** | $0.999409 |

### Action 9: Tighten Smart-Debt Limits on the USDC-USDT (id 2) DEX

DEX id **2**, share price **$2.204907979983792**. Limits are set in DEX shares (1e18) via `setDexBorrowProtocolLimitsInShares`. Expansion window **6h → 3h**.

| Vault | Market | Type | Base (old → new) | Max (old → new) | Expand % |
| --- | --- | --- | --- | --- | --- |
| 47 | weETH / USDC-USDT | T3 | $8.27M → **$2.50M** | $22.03M → **$25M** | 30% → **25%** |
| 50 | sUSDe / USDC-USDT | T3 | $11.02M → **$2.50M** | $44.07M → **$25M** | 30% → **25%** |
| 98 | sUSDe-USDT / USDC-USDT | T4 | $44.07M → **$2.50M** | $88.13M → **$25M** | 30% → **25%** |
| 99 | USDe-USDT / USDC-USDT | T4 | $44.07M → **$2.50M** | $88.13M → **$25M** | 30% → **10%** |
| 156 | osETH / USDC-USDT | T3 | $5.51M → **$100K** | $11.02M → **$1M** | 30% → **25%** |
| 163 | reUSD / USDC-USDT | T3 | $8.82M → **$2.50M** | $22.03M → **$20M** | 30% → **10%** |

### Action 10: Tighten Smart-Debt Limits on the USDC-USDT (id 34) DEX

DEX id **34**, share price **$2.102974865610295**. Limits are set in DEX shares (1e18) via `setDexBorrowProtocolLimitsInShares`. Expansion window **6h → 3h**.

| Vault | Market | Type | Base (old → new) | Max (old → new) | Expand % |
| --- | --- | --- | --- | --- | --- |
| 126 | sUSDe-USDT / USDC-USDT | T4 | $15.77M → **$2.50M** | $42.03M → **$50M** | 30% → **25%** |
| 127 | USDe-USDT / USDC-USDT | T4 | $15.77M → **$2.50M** | $42.03M → **$50M** | 30% → **25%** |
| 157 | osETH / USDC-USDT | T3 | $5.25M → **$100K** | $10.51M → **$1M** | 30% → **25%** |

### Action 11: Tighten Smart-Debt Limits on the GHO-USDC (id 4) DEX

DEX id **4**, share price **$2.2159112801948067**. Limits are set in DEX shares (1e18) via `setDexBorrowProtocolLimitsInShares`. Expansion window **6h → 3h**.

| Vault | Market | Type | Base (old → new) | Max (old → new) | Expand % |
| --- | --- | --- | --- | --- | --- |
| 61 | GHO-USDC / GHO-USDC | T4 | $9.96M → **$2.50M** | $19.11M → **$25M** | 30% → **10%** |
| 125 | GHO-sUSDe / GHO-USDC | T4 | $11.07M → **$1M** | $33.23M → **$25M** | 30% → **25%** |
| 139 | GHO-USDe / GHO-USDC | T4 | $11.07M → **$1M** | $22.14M → **$10M** | 30% → **25%** |

## Description

Following a review of the less-trusted vault set, borrow capacity is being right-sized down to current usage with tighter, slower expansion so that available debt cannot grow as quickly during stress. Module upgrades and auth rotations (Actions 1–7) run first so infrastructure is on the new implementations and auth contracts before limit changes take effect.

For each borrow-limit vault the new **base debt ceiling** is the limit available immediately, and the **max debt ceiling** is the cap the base can expand toward over time. Lowering the **expand percent** (50%/30% → 25%, or → 10% on the deepest pools) and the **expand duration** (6h → 3h) means the borrowable amount refills more conservatively after utilization.

Liquidity-Layer vaults (Action 8) have their ceilings set in the debt token's own units, converted from the USD targets at the per-vault override price and then normalized by the live borrow exchange price at execution. Smart-debt vaults (Actions 9–11) have their ceilings set directly in DEX shares, converted from USD at each pool's override share price.

The 10% expand tier is applied to the largest / most concentrated pools: vaults **61**, **74**, **99**, **159**, **160**, **161**, **163**, and **164**. All other vaults move to the 25% tier.

## Conclusion

IGP-133 upgrades Liquidity Layer UserModule and AdminModule with rollback safety, rotates pause / rates / range auths (Actions 1–7), then tightens borrow limits on 66 less-trusted Ethereum vaults: 54 at the Liquidity Layer (Action 8) and 12 smart-debt vaults across three DEXes (Actions 9–11). Every affected borrow vault gets lower base/max debt ceilings, a reduced borrow expand percent (25%, or 10% on the deepest pools), and a shortened 3h expansion window.
