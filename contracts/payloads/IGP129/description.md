# Withdraw Treasury iETHv2 and fGHO Balances to Team Multisig

## Summary

This proposal performs two Ethereum actions:

1. Transfers the Treasury DSA's iETHv2 balance to the Team Multisig as iETHv2.
2. Redeems the Treasury DSA's fGHO position to GHO and sends the GHO to the Team Multisig.

## Code Changes

### Action 1: Transfer iETHv2 Balance to Team Multisig

- Uses the `BASIC-A` connector's `withdraw` spell with `type(uint256).max` as the amount, so the Treasury's iETHv2 balance is transferred to the Team Multisig as iETHv2.

### Action 2: Redeem fGHO Position to GHO and Send to Team Multisig

- Uses the `BASIC-D-V2` connector's `redeem` spell with `type(uint256).max` as the share amount, redeeming the fGHO shares held by the Treasury and sending the resulting GHO to the Team Multisig.

## Description

The first action transfers the Treasury's iETHv2 holdings to the Team Multisig as iETHv2.

The second action redeems the Treasury's fGHO position to GHO and sends the GHO to the Team Multisig.

## Conclusion

IGP-129 moves the Treasury's iETHv2 balance to the Team Multisig and redeems the Treasury's fGHO position to GHO for the Team Multisig.
