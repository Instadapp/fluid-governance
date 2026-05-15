# Treasury Withdrawal to Team Multisig

## Summary

This proposal performs a single Ethereum action:

1. Withdraws funds from the Treasury DSA to Team Multisig. Token and amount are left as in-code placeholders to be filled before finalizing IGP-129.

The treasury withdrawal token address and amount are intentionally **not** Team Multisig-configurable — they are hardcoded in the payload before submission and `action1()` reverts on execution if either is left at its zero placeholder.

## Code Changes

### Action 1: Withdraw Funds from Treasury to Team Multisig

- Casts the Treasury DSA with the `BASIC-A` connector and the `withdraw(address,uint256,address,uint256,uint256)` spell.
- Spell args: `(token_, amount_, TEAM_MULTISIG, 0, 0)`.
- Reverts with `withdraw-token-not-set` if `token_ == address(0)` and with `withdraw-amount-not-set` if `amount_ == 0`.

## Description

IGP-129 carries a single on-chain action that withdraws a hardcoded token and amount from the Treasury DSA into the Team Multisig via the `BASIC-A` connector. Both values are inlined in `action1()` of `PayloadIGP129.sol` and must be filled in before the proposal is submitted; the in-code `require` guards ensure that the proposal cannot execute with the zero placeholders.

This payload is intentionally split out from the broader maintenance batch (covered separately in IGP-130) so that the treasury withdrawal can be reviewed, voted on, and executed on its own.

> Note: No values on this payload are Team Multisig-configurable. The token and amount are fixed in source before submission.

## Conclusion

IGP-129 executes a single Treasury → Team Multisig withdrawal via the `BASIC-A` connector, with the token and amount hardcoded in the payload prior to submission. It is delivered separately from the broader maintenance batch in IGP-130.
