# Collect Liquidity Layer Revenue and Withdraw to Team Multisig to Cover Fluid Lite ETH User Losses

## Summary

This proposal performs a single Ethereum action: collects accrued protocol revenue across a basket of tokens from the Liquidity Layer into the Reserve Contract, then withdraws nearly all of those balances from the Reserve to Team Multisig (leaving minimal dust) to cover losses incurred by Fluid Lite ETH (iETHv2) users from recent ETH borrow rate spikes across the underlying lending protocols.

## Code Changes

### Action 1: Collect Revenue and Withdraw to Team Multisig to Cover Fluid Lite ETH User Losses

- **Revenue Collection**:
  - Collect protocol revenue across a basket of tokens from the Liquidity Layer
  - **Tokens Included**: `USDC, ETH, USDT, wstETH, cbBTC, GHO, USDe, WBTC, weETH, syrupUSDC, sUSDe, XAUt, USDtb, PAXG, rsETH, ezETH, RLP, reUSD, USD0, eBTC, LBTC, fxUSD`
  - Withdraw nearly all balances from Reserve to Team Multisig, leaving minimal dust for operational safety
  - **Recipient**: Team Multisig (`0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e`)
  - Purpose: Cover losses incurred by Fluid Lite ETH (iETHv2) users from recent ETH borrow rate spikes across the underlying lending protocols

## Description

During recent market volatility, ETH borrow rates spiked across the lending protocols used by Fluid Lite. The elevated borrow rates exceeded stETH staking yield, resulting in losses for Lite ETH (iETHv2) vault depositors.

This proposal collects accumulated protocol revenue across 22 tokens from the Liquidity Layer into the Reserve Contract, and withdraws nearly all of those balances from the Reserve to Team Multisig (leaving minimal dust for operational safety) so that the Team Multisig can apply the proceeds toward the Fluid Lite ETH (iETHv2) user loss coverage. This follows the same Lite-loss compensation precedent set by IGP-119 (250 iETHv2 ≈ 295 ETH to Team Multisig for an earlier ETH borrow rate spike event), and uses the same `collectRevenue` → Reserve → Team Multisig flow used in IGP-111 / IGP-112.

## Conclusion

IGP-130 collects accumulated Liquidity Layer revenue across 22 tokens and forwards it to Team Multisig to cover Fluid Lite ETH (iETHv2) user losses from the recent ETH borrow rate spike across the underlying lending protocols.
