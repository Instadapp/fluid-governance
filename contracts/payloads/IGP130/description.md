# Collect Liquidity Layer Revenue to Cover Fluid Lite ETH User Losses, Set PST Ecosystem Dust Limits, Raise Lite ETH Risk Ratios on Aave V3 & Spark, and Raise stETH Redemption Protocol Limits

## Summary

This proposal performs four Ethereum actions: (1) collects accrued protocol revenue across a basket of 22 tokens from the Liquidity Layer into the Reserve Contract and withdraws nearly all of those balances from the Reserve to Team Multisig (leaving minimal dust) to cover losses incurred by Fluid Lite ETH (iETHv2) users from recent ETH borrow rate spikes across the underlying lending protocols; (2) sets dust limits and Team Multisig auth on the new PST ecosystem (PST-USDC DEX and five PST vaults); (3) raises Fluid Lite ETH (iETHv2) max risk ratio on Aave V3 to 94% and on Spark to 92%; (4) raises the stETH redemption protocol ETH borrow limit on the Liquidity Layer to 20,000 ETH and the max LTV to 97%.

## Code Changes

### Action 1: Collect Revenue and Withdraw to Team Multisig to Cover Fluid Lite ETH User Losses

- **Revenue Collection**:
  - Collect protocol revenue across a basket of tokens from the Liquidity Layer
  - **Tokens Included**: `USDC, ETH, USDT, wstETH, cbBTC, GHO, USDe, WBTC, weETH, syrupUSDC, sUSDe, XAUt, USDtb, PAXG, rsETH, ezETH, RLP, reUSD, USD0, eBTC, LBTC, fxUSD`
  - Withdraw nearly all balances from Reserve to Team Multisig, leaving minimal dust for operational safety
  - **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
  - Purpose: Cover losses incurred by Fluid Lite ETH (iETHv2) users from recent ETH borrow rate spikes across the underlying lending protocols

### Action 2: PST Ecosystem Dust Limits + Team Multisig Auth


- **PST-USDC DEX**: smart-collateral dust limits — `$10k` base withdrawal; smart debt disabled. Team Multisig set as DEX auth.
- **Vault: PST / USDC (TYPE_1)**: `$7k / $7k / $9k` (base withdraw / base borrow / max borrow). Team Multisig set as vault auth.
- **Vault: PST / USDT (TYPE_1)**: `$7k / $7k / $9k`. Team Multisig set as vault auth.
- **Vault: PST-USDC / USDC (TYPE_2)**: USDC debt at LL `$7k / $9k` (base / max borrow). Team Multisig set as vault auth.
- **Vault: PST / USDC-USDT (TYPE_3)**: PST supply at LL `$7k` base withdrawal; USDC-USDT DEX (id 2) borrow share caps `~3,500 / 4,500` (~$7k / ~$9k). Team Multisig set as vault auth.
- **Vault: PST-USDC / USDC-USDT (TYPE_4)**: USDC-USDT DEX (id 2) borrow share caps `~3,500 / 4,500` (~$7k / ~$9k). Team Multisig set as vault auth.

### Action 3: Raise Fluid Lite ETH (iETHv2) Max Risk Ratios

- **Aave V3** (protocol id `2`): max risk ratio raised to **94%**.
- **Spark** (protocol id `7`): max risk ratio raised to **92%**.

### Action 4: Raise stETH Redemption Protocol Limits

- **ETH borrow limit on Liquidity Layer**: raised to **20,000 ETH** (base and max ceilings; `maxDebtCeiling = base * 1001 / 1000` for ~0.1% headroom, `expandPercent = 0`).
- **Max LTV** on the stETH redemption protocol (`0x1F6B2bFDd5D1e6AdE7B17027ff5300419a56Ad6b`): raised from **90%** to **97%** via `setMaxLTV(9700)`.

## Description

During recent market volatility, ETH borrow rates spiked across the lending protocols used by Fluid Lite. The elevated borrow rates exceeded stETH staking yield, resulting in losses for Lite ETH (iETHv2) vault depositors. Action 1 collects accumulated protocol revenue across 22 tokens from the Liquidity Layer into the Reserve Contract, and withdraws nearly all of those balances from the Reserve to Team Multisig (leaving minimal dust for operational safety) so that the Team Multisig can apply the proceeds toward the Fluid Lite ETH (iETHv2) user loss coverage.

Action 2 prepares the PST ecosystem for launch by setting minimal dust limits on the PST-USDC DEX and on the five PST-paired vaults (PST/USDC, PST/USDT, PST-USDC/USDC, PST/USDC-USDT, PST-USDC/USDC-USDT), and by granting Team Multisig auth on each so that the Team Multisig can adjust parameters.

Action 3 raises the max risk ratio on Fluid Lite ETH (iETHv2) for the Aave V3 integration to 94% and the Spark integration to 92%, allowing Lite ETH to operate at higher loan ratios on those venues now that markets have normalized.

Action 4 expands stETH redemption protocol capacity: it raises the ETH borrow allowance on the Liquidity Layer to 20,000 ETH and increases the max LTV from 90% to 97%, enabling larger and tighter stETH-to-ETH redemptions through the protocol.

## Conclusion

IGP-130 (1) collects accumulated Liquidity Layer revenue across 22 tokens and forwards it to Team Multisig to cover Fluid Lite ETH (iETHv2) user losses from the recent ETH borrow rate spike, (2) launches the PST ecosystem with conservative dust limits and Team Multisig auth on the PST-USDC DEX and five PST vaults, (3) raises Lite ETH max risk ratios on Aave V3 (94%) and Spark (92%), and (4) expands stETH redemption protocol capacity to 20,000 ETH borrow and 97% max LTV.
