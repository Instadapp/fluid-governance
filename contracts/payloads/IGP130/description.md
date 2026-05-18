# Collect Liquidity Layer Revenue into the Reserve Contract and Forward to Team Multisig: Fluid Lite (iETHv2) Loss Coverage + Monthly Buyback Revenue Sweep

## Summary

This proposal performs two on-chain actions, both routing accrued Liquidity Layer revenue through the Fluid Reserve Contract to the Team Multisig, but with distinct carve-outs and recipients off-chain:

1. **Action 1 — Lite (iETHv2) loss coverage.** Collects accrued **wstETH** revenue from the Liquidity Layer into the Fluid Reserve Contract via `LIQUIDITY.collectRevenue([wstETH])`, then forwards `230 * 1e18` wstETH from the Reserve Contract to the Team Multisig via `FLUID_RESERVE.withdrawFunds`. The Team Multisig will then convert the wstETH to ETH off-chain and forward it to the iETHv2 loss-coverage recipient at `0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD` (Thrilok) for distribution to affected Fluid Lite ETH (iETHv2) users.
2. **Action 2 — Monthly buyback revenue sweep.** Collects accrued Liquidity Layer revenue across **22 tokens** into the Fluid Reserve Contract via `LIQUIDITY.collectRevenue(tokens)`, then forwards the full Reserve balance of each of those tokens (minus minimal dust) to the Team Multisig via `IFluidReserveContractV2.withdrawFunds(tokens, amounts, TEAM_MULTISIG, "revenue for buybacks")`. This mirrors IGP-112's action 10.

No values on this payload are Team Multisig-configurable. Token addresses, recipient (`TEAM_MULTISIG`), the wstETH carve-out amount (`230 * 1e18`), the buyback amounts (`balance − dust` at execution time), and the on-chain reason strings are all fixed in source before submission.

## Code Changes

### Action 1: Collect wstETH Revenue from LL → Reserve Contract → Team Multisig (Lite loss coverage)

- **Step 1 (Liquidity Layer revenue collection)**: Calls `LIQUIDITY.collectRevenue(tokens_)` with `tokens_ = [wstETH_ADDRESS]`. Transfers accrued wstETH revenue from the Liquidity Layer to the configured revenue collector (the Fluid Reserve Contract, `0x264786EF916af64a1DB19F513F24a3681734ce92`).
- **Step 2 (Reserve Contract → Team Multisig)**: Calls `FLUID_RESERVE.withdrawFunds(tokens_, amounts_, TEAM_MULTISIG)` with `tokens_ = [wstETH_ADDRESS]` and `amounts_ = [230 * 1e18]`.
- Any wstETH revenue accrued in excess of `230 * 1e18` remains on the Reserve Contract and is swept to the Team Multisig as part of action 2 below.

| Field | Value |
|---|---|
| Token | wstETH (`0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0`) |
| Amount | `230 * 1e18` |
| On-chain recipient | Team Multisig (`TEAM_MULTISIG`, `0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`) |
| On-chain flow | Liquidity Layer → Fluid Reserve Contract → Team Multisig |
| Off-chain follow-up (multisig) | Team Multisig converts wstETH → ETH and forwards to `0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD` (Thrilok) for iETHv2 user loss coverage |

### Action 2: Collect LL Revenue Across 22 Tokens → Reserve Contract → Team Multisig (monthly buybacks)

- **Step 1 (Liquidity Layer revenue collection)**: Calls `LIQUIDITY.collectRevenue(tokens_)` with the 22-token array below. Accrued revenue for each token is transferred from the Liquidity Layer to the Fluid Reserve Contract.
- **Step 2 (Reserve Contract → Team Multisig)**: Calls `IFluidReserveContractV2(FLUID_RESERVE).withdrawFunds(tokens_, amounts_, TEAM_MULTISIG, "revenue for buybacks")` where each `amounts_[i]` is the current Reserve balance of `tokens_[i]` (or `address(reserve).balance` for native ETH) minus a small dust amount sized to the token's decimals.
- Dust convention (matches IGP-112):
  - 6-decimal tokens (USDC, USDT, syrupUSDC, XAUt): leave `10` wei
  - 8-decimal tokens (cbBTC, WBTC, eBTC, LBTC): leave `10` wei
  - 18-decimal tokens (everything else listed below): leave `0.1 ether` (= `1e17`)
  - Native ETH: leave `0.1 ether`

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

During recent market volatility, ETH borrow rates spiked across the lending protocols used by Fluid Lite. The elevated borrow rates exceeded stETH staking yield, resulting in losses for Lite ETH (iETHv2) vault depositors.

To fund the Lite refund without drawing on the broader Treasury, **Action 1** first collects accrued wstETH revenue at the Liquidity Layer into the Fluid Reserve Contract (same `LIQUIDITY.collectRevenue` mechanism used in IGP-94 / IGP-102 / IGP-112), and then forwards a targeted `230 * 1e18` wstETH from the Reserve Contract to the Team Multisig via `FLUID_RESERVE.withdrawFunds`. After execution, the Team Multisig will run a separately-prepared Avocado multisig transaction that (i) converts the 230 wstETH to ETH and (ii) transfers the resulting ETH to `0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD` (Thrilok), who applies it to the iETHv2 user loss coverage.

**Action 2** then performs the monthly buyback revenue sweep: it collects accrued revenue for the 22 tokens listed above from the Liquidity Layer into the Fluid Reserve Contract, and forwards the full Reserve balance of each (minus minimal dust) onward to the Team Multisig with the on-chain reason `"revenue for buybacks"`. This is the same flow used in IGP-112 action 10, just expanded to cover the broader token universe that Fluid has accrued revenue on since.

Routing both the Lite loss carve-out and the buyback sweep through the Reserve Contract keeps the protocol-revenue path consistent with the existing buyback flow, makes both transfers visible on-chain with explicit reasons, and avoids touching the main Treasury DSA for either leg.

> Note: No values on this payload are Team Multisig-configurable. Token addresses, the wstETH carve-out amount, recipient, and reason strings are fixed in source before submission. Buyback amounts are computed at execution time as `IERC20(token).balanceOf(reserve) − dust` (or `address(reserve).balance − 0.1 ether` for native ETH).

## Conclusion

IGP-130 routes Liquidity Layer revenue through the Fluid Reserve Contract to the Team Multisig in two carved-out flows: (1) `230 * 1e18` wstETH for Fluid Lite (iETHv2) ETH user loss coverage (the Team Multisig converts to ETH and forwards off-chain to `0x9a403fc58CC6Efe56965Fa6baC0F01bAa11169aD`), and (2) a full revenue sweep across 22 tokens for the monthly buyback program with the on-chain reason `"revenue for buybacks"`. The broader maintenance batch previously drafted as IGP-130 (Liquidity Layer module upgrades, auth rotations, wstUSR rebalance, FLUID rewards funding, and Lite/DSA placeholders) has been moved to IGP-131.
