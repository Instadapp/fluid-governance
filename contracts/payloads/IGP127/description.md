# Fix Pauseable Auth on Liquidity Layer & Initiate reUSD-USDT / USDC-USDT T4 Vault

## Summary

This proposal (1) fixes an issue from IGP-126 Action 10, which incorrectly registered `pauseableAuth` as an **auth** on the Liquidity Layer using `updateAuths()` — the fix uses `updateGuardians()` instead since `pauseUser`/`unpauseUser` require the `onlyGuardians` modifier, and (2) initiates the reUSD-USDT / USDC-USDT T4 vault (Vault 165) with dust limits and Team Multisig authorization.

The `pauseableAuth` address is configurable by Team Multisig before governance execution.

## Code Changes

### Action 1: Set Pauseable Auth as Guardian on Liquidity Layer

- Calls `LIQUIDITY.updateGuardians()` to add `pauseableAuth` as a guardian on the Liquidity Layer
- Enables the pauseable contract to execute `pauseUser` / `unpauseUser` for emergency pauses on LL protocols
- Requires `pauseableAuth` to be set by Team Multisig before execution

### Action 2: Initiate reUSD-USDT / USDC-USDT T4 Vault (Vault 165) with Dust Limits

- Sets T4 vault supply limits on reUSD-USDT DEX (Pool 44) as smart collateral: 30% expand, 6h duration, ~$7k base withdrawal (3.5k DEX shares)
- Sets T4 vault borrow limits on USDC-USDT DEX (Pool 2) as smart debt: 30% expand, 6h duration, ~$7k base / ~$9k max (in DEX shares)
- Sets reUSD-USDT DEX (Pool 44) token LL supply limits to $10k for reUSD and USDT
- Adds Team Multisig as vault auth on Vault 165

## Description

This proposal covers two areas:

1. **Pauseable Auth Fix (from IGP-126)**
   - IGP-126 Action 10 attempted to register `pauseableAuth` as an authorized address on the Liquidity Layer using `updateAuths()`. However, the Liquidity Layer's pause functions (`pauseUser`, `unpauseUser`) are protected by the `onlyGuardians` modifier in the `GuardianModule`, not by auth checks. This proposal corrects the issue by calling `updateGuardians()` instead, which grants the `pauseableAuth` contract the guardian role required to invoke emergency pause operations.
   - Note: `pausableDexAuth` (DEX factory global auth from IGP-126 Action 11) is correct as-is — DEX operations use auth-based access control, not guardian-based.

2. **reUSD-USDT / USDC-USDT T4 Vault Initialization (Vault 165)**
   - Initializes Vault 165 with dust supply limits on the reUSD-USDT DEX (smart collateral) and dust borrow limits on the USDC-USDT DEX (smart debt)
   - Sets dust LL token supply limits ($10k) on DEX 44
   - Sets Team Multisig as vault auth for operational flexibility

### Configurable Addresses (Team Multisig sets before execution)

| Variable | Purpose |
|---|---|
| `pauseableAuth` | Contract authorized as guardian for emergency pauses on Liquidity Layer |

## Conclusion

IGP-127 corrects the access control misconfiguration from IGP-126 by registering `pauseableAuth` as a guardian on the Liquidity Layer, and initializes the reUSD-USDT / USDC-USDT T4 vault (Vault 165) with dust limits and Team Multisig authorization.
