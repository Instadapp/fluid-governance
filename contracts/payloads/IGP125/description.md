# Unpause Vault 135 (wstUSR-USDC<>USDC-USDT concentrated) and Set Withdrawal Limits

## Summary

This proposal unpauses vault 135 (wstUSR-USDC<>USDC-USDT concentrated, TYPE 3) at both DEXes and sets a $5M base withdrawal limit at the wstUSR-USDC DEX (Pool 27). Borrow limits remain restricted so the vault operates in payback-only mode for the debt side, as the USDC-USDT concentrated borrow path is being retired.

## Code Changes

### Action 1: Unpause Vault 135 and Set Withdrawal Limits

- **Vault**: 135 (wstUSR-USDC<>USDC-USDT concentrated, TYPE 3)

**Step 1 — Set supply (withdrawal) limits at wstUSR-USDC DEX (Pool 27):**
- **Base Withdrawal Limit**: ~$5M (5,000,000 shares)
- **Expand Percent**: 50%
- **Expand Duration**: 6 hours

**Step 2 — Unpause vault 135 at wstUSR-USDC DEX (Pool 27):**
- Enables supply-side operations for the vault

**Step 3 — Unpause vault 135 at USDC-USDT concentrated DEX (Pool 34):**
- Enables borrow-side operations (payback only — borrow limits remain restricted)

## Description

Vault 135 (wstUSR-USDC<>USDC-USDT concentrated) has active TVL with users holding collateral and outstanding debt. This proposal:

1. **Unpauses the vault at both DEXes** — Enables operations at the wstUSR-USDC DEX (Pool 27, supply side) and the USDC-USDT concentrated DEX (Pool 34, borrow side)
2. **Sets a $5M withdrawal limit** — Configures a $5M base withdrawal limit at the wstUSR-USDC DEX so users can withdraw their collateral
3. **Keeps borrow restricted** — Borrow limits at the USDC-USDT concentrated DEX (Pool 34) remain at minimal values, so users can only repay existing debt but cannot take new borrows — consistent with the intent to retire the USDC-USDT concentrated borrow path

## Conclusion

IGP-125 unpauses vault 135 (wstUSR-USDC<>USDC-USDT concentrated) at both DEXes and sets a $5M base withdrawal limit, allowing users to manage their positions. Borrow limits remain restricted for payback-only operation as the USDC-USDT concentrated path is retired.
