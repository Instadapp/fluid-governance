# Collect Liquidity Layer Revenue to Cover Fluid Lite ETH User Losses, Set PST Ecosystem Dust Limits, Raise Lite ETH Risk Ratios on Aave V3 & Spark, and Raise stETH Redemption Protocol Limits

## Summary

This proposal performs four Ethereum actions: (1) collects accrued protocol revenue across 22 tokens from the Liquidity Layer into the Reserve Contract and withdraws nearly all of those balances to Team Multisig via Reserve V2 `withdrawFunds` (leaving minimal per-token dust); (2) sets dust limits and Team Multisig auth on the new PST ecosystem (PST-USDC DEX id **45** and vaults **165–169**); (3) raises Fluid Lite ETH (iETHv2) max risk ratio on Aave V3 to **94%** and Spark to **92%**; (4) raises the stETH redemption protocol ETH borrow limit on the Liquidity Layer to **20,000 ETH** and max LTV to **97%**.

## Code Changes

### Action 1: Collect Revenue and Withdraw to Team Multisig

- **Revenue collection**: `LIQUIDITY.collectRevenue` across 22 tokens.
- **Tokens**: `USDC, ETH, USDT, wstETH, cbBTC, GHO, USDe, WBTC, weETH, syrupUSDC, sUSDe, XAUT, USDtb, PAXG, rsETH, ezETH, RLP, reUSD, USD0, eBTC, lBTC, fxUSD`
- **Withdraw**: `IFluidReserveContractV2.withdrawFunds` on the Reserve (`0x264786EF916af64a1DB19F513F24a3681734ce92`) — nearly full balance per token minus operational dust (`-10` for 6/8-decimal tokens, `-0.1 ether` for 18-decimal tokens and native ETH).
- **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
- **Reason tag**: `"RESOLV CLEANUP"` (Reserve V2 audit string)
- **Purpose**: Apply proceeds toward Fluid Lite ETH (iETHv2) user loss coverage from recent ETH borrow rate spikes.

### Action 2: PST Ecosystem Dust Limits + Team Multisig Auth

Assumes PST deployments receive ids **165–169** (vaults) and **45** (PST-USDC DEX) when batches execute in order. PST token: `0x22aE3D9a738471f405169Af055d31c687087d4c7`.

Vault auth is set via **VaultFactoryOwner** (`FLUID_VAULT_FACTORY_OWNER`, `0xB031913cB7AD81b8A4Ba412B471c2dA69BEA410B`). DEX auth via `DEX_FACTORY`.

| Market | Id | Type | Limits |
| --- | --- | --- | --- |
| PST / USDC | 165 | TYPE_1 | `$7k / $7k / $9k` withdraw / base borrow / max borrow |
| PST / USDT | 166 | TYPE_1 | `$7k / $7k / $9k` |
| PST-USDC / USDC | 167 | TYPE_2 | USDC debt at LL `$7k / $9k` (smart col at DEX 45) |
| PST / USDC-USDT | 168 | TYPE_3 | PST supply `$7k`; USDC-USDT DEX (id **2**) borrow shares `3500e18 / 4500e18` |
| PST-USDC / USDC-USDT | 169 | TYPE_4 | USDC-USDT DEX (id **2**) borrow shares `3500e18 / 4500e18`; smart col at DEX **45** |
| PST-USDC DEX | **45** | smart col | `$10k` base withdrawal per token side; smart debt off |

All five vaults and DEX 45 grant Team Multisig auth.

### Action 3: Raise Fluid Lite ETH (iETHv2) Max Risk Ratios

- **Aave V3** (protocol id `2`): max risk ratio → **94%** (`94 * 1e4`)
- **Spark** (protocol id `7`): max risk ratio → **92%** (`92 * 1e4`)

### Action 4: Raise stETH Redemption Protocol Limits

- **Protocol**: `0x1F6B2bFDd5D1e6AdE7B17027ff5300419a56Ad6b`
- **ETH borrow limit (Liquidity Layer)**: **20,000 ETH** base ceiling (`getRawAmount(ETH, 20_000 ether, …)`); max ceiling `base * 1001 / 1000`; `expandPercent = 0`, `expandDuration = 1`
- **Max LTV**: **97%** via `setMaxLTV(97 * 1e2)`

## Description

During recent market volatility, ETH borrow rates spiked across the lending protocols used by Fluid Lite. The elevated borrow rates exceeded stETH staking yield, resulting in losses for Lite ETH (iETHv2) vault depositors.

**Action 1** collects accumulated protocol revenue across 22 tokens into the Reserve Contract and withdraws nearly all balances to Team Multisig (minimal dust retained), tagged `"RESOLV CLEANUP"` on the Reserve V2 withdraw, for use toward iETHv2 user loss coverage.

**Action 2** launches the PST ecosystem at dust scale: limits on vaults 165–169 and PST-USDC DEX 45, with Team Multisig auth on each (vault auth through VaultFactoryOwner; DEX auth through DexFactory).

**Action 3** raises iETHv2 per-protocol max risk ratios on Aave V3 (94%) and Spark (92%).

**Action 4** doubles stETH redemption protocol ETH borrow capacity to 20,000 ETH and raises max LTV to 97%.

## Conclusion

IGP-130 (1) collects Liquidity Layer revenue across 22 tokens and forwards it to Team Multisig for iETHv2 user loss coverage, (2) launches the PST ecosystem (DEX 45, vaults 165–169) with conservative dust limits and Team Multisig auth, (3) raises Lite ETH max risk ratios on Aave V3 (94%) and Spark (92%), and (4) expands stETH redemption to 20,000 ETH borrow and 97% max LTV.
