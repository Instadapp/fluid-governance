# Collect Liquidity Layer Revenue and Withdraw to Team Multisig to Cover Fluid Lite ETH User Losses and Set PST Ecosystem Dust Limits

## Summary

This proposal performs two Ethereum actions: (1) collects accrued protocol revenue across a basket of 22 tokens from the Liquidity Layer into the Reserve Contract and withdraws nearly all of those balances from the Reserve to Team Multisig (leaving minimal dust) to cover losses incurred by Fluid Lite ETH (iETHv2) users from recent ETH borrow rate spikes across the underlying lending protocols; (2) sets dust limits and Team Multisig auth on the new PST ecosystem (PST-USDC DEX and five PST vaults).

## Code Changes

### Action 1: Collect Revenue and Withdraw to Team Multisig to Cover Fluid Lite ETH User Losses

- **Revenue Collection**:
  - Collect protocol revenue across a basket of tokens from the Liquidity Layer
  - **Tokens Included**: `USDC, ETH, USDT, wstETH, cbBTC, GHO, USDe, WBTC, weETH, syrupUSDC, sUSDe, XAUt, USDtb, PAXG, rsETH, ezETH, RLP, reUSD, USD0, eBTC, LBTC, fxUSD`
  - Withdraw nearly all balances from Reserve to Team Multisig, leaving minimal dust for operational safety
  - **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
  - Purpose: Cover losses incurred by Fluid Lite ETH (iETHv2) users from recent ETH borrow rate spikes across the underlying lending protocols

### Action 2: PST Ecosystem Dust Limits + Team Multisig Auth

Mirrors the IGP-121 dust-launch pattern (REUSD vaults / REUSD-USDT DEX). PST is priced at $1.10.

- **PST-USDC DEX**: smart-collateral dust limits — `$10k` base withdrawal; smart debt disabled. Team Multisig set as DEX auth.
- **Vault: PST / USDC (TYPE_1)**: `$7k / $7k / $9k` (base withdraw / base borrow / max borrow). Team Multisig set as vault auth.
- **Vault: PST / USDT (TYPE_1)**: `$7k / $7k / $9k`. Team Multisig set as vault auth.
- **Vault: PST-USDC / USDC (TYPE_2)**: USDC debt at LL `$7k / $9k` (base / max borrow). Team Multisig set as vault auth.
- **Vault: PST / USDC-USDT (TYPE_3)**: PST supply at LL `$7k` base withdrawal; USDC-USDT DEX (id 2) borrow share caps `~3,500 / 4,500` (~$7k / ~$9k). Team Multisig set as vault auth.
- **Vault: PST-USDC / USDC-USDT (TYPE_4)**: USDC-USDT DEX (id 2) borrow share caps `~3,500 / 4,500` (~$7k / ~$9k). Team Multisig set as vault auth.

## Description

During recent market volatility, ETH borrow rates spiked across the lending protocols used by Fluid Lite. The elevated borrow rates exceeded stETH staking yield, resulting in losses for Lite ETH (iETHv2) vault depositors. Action 1 collects accumulated protocol revenue across 22 tokens from the Liquidity Layer into the Reserve Contract, and withdraws nearly all of those balances from the Reserve to Team Multisig (leaving minimal dust for operational safety) so that the Team Multisig can apply the proceeds toward the Fluid Lite ETH (iETHv2) user loss coverage.

Action 2 prepares the PST ecosystem for launch by setting minimal dust limits on the PST-USDC DEX and on the five PST-paired vaults (PST/USDC, PST/USDT, PST-USDC/USDC, PST/USDC-USDT, PST-USDC/USDC-USDT), and by granting Team Multisig auth on each so that the Team Multisig can ramp limits incrementally as TVL grows — same playbook used for the REUSD launch in IGP-121.

## Conclusion

IGP-130 (1) collects accumulated Liquidity Layer revenue across 22 tokens and forwards it to Team Multisig to cover Fluid Lite ETH (iETHv2) user losses from the recent ETH borrow rate spike, and (2) launches the PST ecosystem with conservative dust limits and Team Multisig auth on the PST-USDC DEX and five PST vaults.
