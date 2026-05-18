# Collect Liquidity Layer Revenue Across 22 Tokens into the Reserve Contract and Forward the Full Reserve Balance to Team Multisig

## Summary

This proposal performs a single on-chain action that mirrors IGP-112 action 10:

1. Calls `LIQUIDITY.collectRevenue(tokens_)` with the 22-token list below. Accrued Liquidity Layer revenue for each token is transferred to the configured revenue collector (the Fluid Reserve Contract, `0x264786EF916af64a1DB19F513F24a3681734ce92`).
2. Calls `FLUID_RESERVE.withdrawFunds(tokens_, amounts_, TEAM_MULTISIG)` with the same token list, where each `amounts_[i]` is the current Reserve balance of `tokens_[i]` minus a small dust amount sized to the token's decimals (and `address(reserve).balance - 0.1 ether` for native ETH).

No values on this payload are Team Multisig-configurable. Token addresses and the recipient (`TEAM_MULTISIG`) are fixed in source before submission. Withdrawal amounts are computed at execution time as `IERC20(token).balanceOf(reserve) - dust` (or `address(reserve).balance - 0.1 ether` for native ETH).

## Code Changes

### Action 1: Collect LL Revenue Across 22 Tokens → Reserve Contract → Team Multisig

- **Step 1 (Liquidity Layer revenue collection)**: Calls `LIQUIDITY.collectRevenue(tokens_)` with the 22-token array below. Accrued revenue for each token is transferred from the Liquidity Layer to the Fluid Reserve Contract. This call can revert if any token's Liquidity Layer balance is insufficient to cover its accrued revenue (utilization > 100%).
- **Step 2 (Reserve Contract → Team Multisig)**: Calls `FLUID_RESERVE.withdrawFunds(tokens_, amounts_, TEAM_MULTISIG)`. For each token, `amounts_[i]` is the current Reserve balance of `tokens_[i]` minus a small dust amount.
- Dust convention (matches IGP-112 action 10):
  - 6-decimal tokens (USDC, USDT, syrupUSDC, XAUt): leave `10` wei
  - 8-decimal tokens (cbBTC, WBTC, eBTC, LBTC): leave `10` wei
  - 18-decimal tokens (everything else listed below): leave `0.1 ether` (= `1e17`)
  - Native ETH: leave `0.1 ether`
- Recipient: Team Multisig (`TEAM_MULTISIG`, `0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`).

**Token list (22), ordered by approximate revenue value at the time of drafting:**

| # | Token | Address | Decimals | Snapshot revenue (USD) |
|---:|---|---|---:|---:|
| Above $10k revenue ||||
| 1 | USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | 6 | $175,174.46 |
| 2 | ETH (native) | `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE` | 18 | $151,594.53 |
| 3 | USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` | 6 | $145,094.72 |
| 4 | wstETH | `0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0` | 18 | $37,869.39 |
| 5 | cbBTC | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` | 8 | $34,008.07 |
| 6 | GHO | `0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f` | 18 | $31,240.41 |
| 7 | USDe | `0x4c9EDD5852cd905f086C759E8383e09bff1E68B3` | 18 | $28,013.51 |
| 8 | WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | 8 | $20,144.59 |
| 9 | weETH | `0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee` | 18 | $15,976.61 |
| 10 | syrupUSDC | `0x80ac24aA929eaF5013f6436cdA2a7ba190f5Cc0b` | 6 | $11,529.70 |
| 11 | sUSDe | `0x9D39A5DE30e57443BfF2A8307A4256c8797A3497` | 18 | $10,381.73 |
| Below $10k revenue ||||
| 12 | XAUt | `0x68749665FF8D2d112Fa859AA293F07A622782F38` | 6 | $8,116.12 |
| 13 | USDtb | `0xC139190F447e929f090Edeb554D95AbB8b18aC1C` | 18 | $7,867.96 |
| 14 | PAXG | `0x45804880De22913dAFE09f4980848ECE6EcbAf78` | 18 | $7,842.94 |
| 15 | rsETH | `0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7` | 18 | $6,819.38 |
| 16 | ezETH | `0xbf5495Efe5DB9ce00f80364C8B423567e58d2110` | 18 | $4,730.53 |
| 17 | RLP | `0x4956b52aE2fF65D74CA2d61207523288e4528f96` | 18 | $4,578.90 |
| 18 | reUSD | `0x5086bf358635B81D8C47C66d1C8b9E567Db70c72` | 18 | $3,910.83 |
| 19 | USD0 | `0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5` | 18 | $3,295.46 |
| 20 | eBTC | `0x657e8C867D8B37dCC18fA4Caead9C45EB088C642` | 8 | $2,837.87 |
| 21 | LBTC | `0x8236a87084f8B84306f72007F36F2618A5634494` | 8 | $2,143.32 |
| 22 | fxUSD | `0x085780639CC2cACd35E474e71f4d000e2405d8f6` | 18 | $1,150.23 |

Total snapshot revenue value across the 22 tokens: **~$714,321.26**. Actual on-chain amounts at execution time may differ as additional revenue accrues between proposal drafting and execution.

## Description

IGP-130 follows the same revenue-collection flow used in IGP-112 action 10 (and earlier in IGP-94 / IGP-102): accrued Liquidity Layer revenue is first collected into the Fluid Reserve Contract, and the Reserve Contract then forwards the full balance of each revenue token (minus minimal dust) to the Team Multisig. Both steps run as a single atomic action so the on-chain trail is:

1. `LIQUIDITY.collectRevenue` emits one `Collect` event per token on the Liquidity Layer.
2. `FLUID_RESERVE.withdrawFunds` emits the consolidated transfer event on the Fluid Reserve Contract.

The 22-token list matches the latest revenue snapshot (above-$10k tokens first, then below-$10k tokens, in the order shown by the off-chain revenue dashboard at the time of drafting). The full balance of each token sitting on the Reserve Contract at execution time — including any prior accumulation plus the revenue freshly collected in this action — is forwarded to the Team Multisig.

> Note: No values on this payload are Team Multisig-configurable. Token addresses and recipient are fixed in source before submission. Buyback amounts are computed at execution time as `IERC20(token).balanceOf(reserve) − dust` (or `address(reserve).balance − 0.1 ether` for native ETH).

## Conclusion

IGP-130 collects accrued Liquidity Layer revenue across 22 tokens into the Fluid Reserve Contract and forwards the full Reserve balance of each (minus minimal dust) to the Team Multisig, all in a single action. The broader maintenance batch previously drafted as IGP-130 (Liquidity Layer module upgrades, auth rotations, wstUSR rebalance, FLUID rewards funding, and Lite/DSA placeholders) has been moved to IGP-131.
