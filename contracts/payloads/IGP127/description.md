# Pauseable Auth on Liquidity Layer — Set as Guardian Instead of Auth

## Summary

This proposal fixes an issue from IGP-126 Action 10, which incorrectly registered `pauseableAuth` as an **auth** on the Liquidity Layer using `updateAuths()`. The Liquidity Layer's `pauseUser` and `unpauseUser` functions are gated by the `onlyGuardians` modifier, so the pauseable contract must be a **guardian** to execute emergency pauses. IGP-126 Action 10 is being skipped, and this proposal correctly adds `pauseableAuth` as a guardian via `updateGuardians()`.

The `pauseableAuth` address is configurable by Team Multisig before governance execution.

## Code Changes

### Action 1: Set Pauseable Auth as Guardian on Liquidity Layer

- Calls `LIQUIDITY.updateGuardians()` to add `pauseableAuth` as a guardian on the Liquidity Layer
- Enables the pauseable contract to execute `pauseUser` / `unpauseUser` for emergency pauses on LL protocols
- Requires `pauseableAuth` to be set by Team Multisig before execution

## Description

IGP-126 Action 10 attempted to register `pauseableAuth` as an authorized address on the Liquidity Layer using `updateAuths()`. However, the Liquidity Layer's pause functions (`pauseUser`, `unpauseUser`) are protected by the `onlyGuardians` modifier in the `GuardianModule`, not by auth checks. As a result, the `pauseableAuth` contract would not have been able to call these functions even after being added as an auth.

This proposal corrects the issue by calling `updateGuardians()` instead, which grants the `pauseableAuth` contract the guardian role required to invoke emergency pause operations.

> Note: `pausableDexAuth` (DEX factory global auth from IGP-126 Action 11) is correct as-is — DEX operations use auth-based access control, not guardian-based.

### Configurable Addresses (Team Multisig sets before execution)

| Variable | Purpose |
|---|---|
| `pauseableAuth` | Contract authorized as guardian for emergency pauses on Liquidity Layer |

## Conclusion

IGP-127 corrects the access control misconfiguration from IGP-126 by registering `pauseableAuth` as a guardian on the Liquidity Layer, enabling the pauseable contract to properly execute emergency pause and unpause operations.
