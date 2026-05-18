# Collect Liquidity Layer Revenue and Withdraw to Team Multisig for Monthly Buyback

## Summary

This proposal performs a single Ethereum action: collects accrued protocol revenue across a basket of tokens from the Liquidity Layer into the Reserve Contract, then withdraws nearly all of those balances from the Reserve to Team Multisig (leaving minimal dust) for the monthly buyback program.

## Code Changes

### Action 1: Collect Revenue and Withdraw to Team Multisig for Monthly Buyback

- **Revenue Collection**:
  - Collect protocol revenue across a basket of tokens from the Liquidity Layer
  - **Tokens Included**: `USDC, ETH, USDT, wstETH, cbBTC, GHO, USDe, WBTC, weETH, syrupUSDC, sUSDe, XAUt, USDtb, PAXG, rsETH, ezETH, RLP, reUSD, USD0, eBTC, LBTC, fxUSD`
  - Withdraw nearly all balances from Reserve to Team Multisig, leaving minimal dust for operational safety
  - **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
  - Purpose: Prepare accumulated revenue for monthly buyback execution

## Description

This proposal collects accumulated protocol revenue across 22 different tokens from the Liquidity Layer into the Reserve Contract, and withdraws nearly all of those balances from the Reserve to Team Multisig (leaving minimal dust for operational safety) to prepare funds for the monthly buyback program. The flow follows the same revenue-collection pattern used in IGP-111 and IGP-112.

## Conclusion

IGP-130 collects accumulated Liquidity Layer revenue across 22 tokens and forwards it to Team Multisig for the monthly buyback program, consolidating revenue streams from stablecoins, liquid staking tokens, BTC variants, gold-backed tokens, and other yield-bearing assets.
