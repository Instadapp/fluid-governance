# Tighten Supply/Borrow Limits, Cap fsUSDs Withdrawal, Cap USR/RLP DEX Supply, Set reUSD Vault Dust Limits, and Launch USDai-USDC Market

## Summary

This proposal performs eleven Ethereum actions:

1. Reduce base withdrawal limits on **legacy vaults 1–10** to roughly current supply (+~5%).
2. Restrict base withdrawal limits on the **sUSDS sunset vaults** (58 and 85) to current supply.
3. Tighten **Liquidity Layer borrow limits across 54 vaults** (expand window 6h → 3h).
4. Tighten smart-debt limits on the **USDC-USDT DEX (id 2)** (expand window 6h → 3h).
5. Tighten smart-debt limits on the **USDC-USDT DEX (id 34)** (expand window 6h → 3h).
6. Tighten smart-debt limits on the **GHO-USDC DEX (id 4)** (expand window 6h → 3h).
7. Cap the **fsUSDs fToken** base withdrawal limit to total supply + 10%.
8. Set max supply shares to **0** on the **USR-USDC DEX (id 20)** and **RLP-USDC DEX (id 28)**.
9. Set **dust limits** on the **reUSD-USDT / USDC-USDT vault (id 170)** and **reUSD / GHO-USDC vault (id 181)**, and grant Team Multisig auth.
10. Raise the **USDai-USDC market** (DEX **47** + T2 vault **180**) from dust limits (IGP-134) to **launch limits**, then remove Team Multisig auth on both.
11. Reduce the **USDC-USDT DEX (id 2)** max borrow cap to **~$45M** (from ~$110M).

## Code Changes

### Action 1: Reduce Legacy Vault 1–10 Base Withdrawal Limits

Tightens base withdrawal limits on legacy vaults 1–10 down to roughly each vault's current total supply (+~5% headroom), with the max-restricted expand percent / duration.

- Vaults **1–2** (ETH), **3–5** (wstETH), **6** (weETH), **7–8** (sUSDe), **9–10** (weETH).

### Action 2: Restrict sUSDS Sunset Vault Withdrawal Limits

Restricts base withdrawal limits on the sunset vaults to their current supply.

- Vault **58** (sUSDs), vault **85** (wstETH).

### Action 3: Tighten Liquidity Layer Borrow Limits (54 Vaults)

Resets `UserBorrowConfig` for 54 Ethereum vaults, shrinking the expand window from 6h to 3h and lowering base/max debt ceilings. Targets are set in rounded USD and resolved to each borrow token's raw amount via the live exchange price.

- Most vaults are reset to **~$2.5M base / ~$25M max**; others land at **~$1M / ~$10M**, **~$1M / ~$2.5M**, or **~$100K / ~$1M**.
- Vaults covered: 16, 17, 18, 19, 20, 26, 27, 32, 56, 57, 74, 80, 92, 93, 94, 96, 97, 103, 104, 107, 108, 109, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 130, 137, 138, 140, 141, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 159, 160, 161, 162, 164.

### Action 4: Tighten Smart-Debt Limits on USDC-USDT DEX (id 2)

Lowers borrow limits (expand window 3h) on vaults borrowing from the USDC-USDT DEX:

- Vaults **47, 50, 98, 99**: **~$2.5M base / ~$25M max**
- Vault **156**: **~$100K / ~$1M**
- Vault **163**: **~$2.5M / ~$20M**

### Action 5: Tighten Smart-Debt Limits on USDC-USDT DEX (id 34)

Lowers borrow limits (expand window 3h):

- Vaults **126, 127**: **~$2.5M base / ~$50M max**
- Vault **157**: **~$100K / ~$1M**

### Action 6: Tighten Smart-Debt Limits on GHO-USDC DEX (id 4)

Lowers borrow limits (expand window 3h):

- Vault **61**: **~$2.5M base / ~$25M max**
- Vault **125**: **~$1M / ~$25M**
- Vault **139**: **~$1M / ~$10M**

### Action 7: Cap fsUSDs Base Withdrawal Limit

Caps the fsUSDs fToken's base withdrawal limit on the Liquidity Layer to total supply + 10% (a fixed limit of **~5,500 sUSDs**). The existing mode and expansion (percent / duration) are preserved.

### Action 8: Set USR and RLP DEX Max Supply Shares to 0

- **USR-USDC DEX (id 20)** and **RLP-USDC DEX (id 28)**: max supply shares set to **0**.
- Prevents new supply on these DEXes while existing LPs retain withdrawal access.

### Action 9: Set Dust Limits for reUSD Vaults (ids 170, 181)

Introduces the new reUSD vaults at dust limits (30% expand / 6h) and grants Team Multisig auth on each.

- **Vault 170** (reUSD-USDT / USDC-USDT, TYPE_4): supply dust limit **~$7k** (collateral DEX 44); borrow dust limit **~$7k base / ~$9k max** (debt DEX 2).
- **Vault 181** (reUSD / GHO-USDC, TYPE_3): supply dust limit **~$7k**; borrow dust limit **~$7k base / ~$9k max** (debt DEX 4).

### Action 10: USDai-USDC Market Launch Limits + Remove Team MS Auth

Raises the USDai-USDC market from the dust limits set in IGP-134 to launch-scale limits and removes the Team Multisig auth.

- **USDai-USDC DEX (id 47)**: per-token limit **~$5M**; remove Team Multisig auth.
- **USDai-USDC / USDC vault (id 180, TYPE_2)**: USDC borrow **~$5M base / ~$10M max** (smart col at DEX 47); remove Team Multisig auth. No supply-side limits are set.

### Action 11: Reduce USDC-USDT DEX (id 2) Max Borrow Cap

- Lowers the USDC-USDT DEX (id 2) max borrow cap to **~$45M** (from **~$110M**).

## Description

**Actions 1–7** reduce withdrawal headroom on legacy and sunset vaults, shrink borrow limits and expansion windows across vaults and DEXes, and cap the fsUSDs withdrawal limit. **Action 8** sets max supply shares to 0 on the USR-USDC and RLP-USDC DEXes. **Action 9** introduces the new reUSD vaults (170, 181) at dust limits with Team Multisig auth. **Action 10** launches the USDai-USDC market (DEX 47 + T2 vault 180) from dust to launch limits and removes the Team Multisig auth retained in IGP-134. **Action 11** reduces the USDC-USDT DEX (id 2) max borrow cap to ~$45M.

## Conclusion

IGP-135 tightens supply and borrow limits across legacy/sunset vaults, DEXes, and the fsUSDs fToken, sets USR/RLP DEX max supply shares to 0, sets dust limits on the reUSD vaults (170 and 181), launches the USDai-USDC market (DEX 47 + T2 vault 180) to launch-scale limits while removing Team Multisig auth on both, and reduces the USDC-USDT DEX (id 2) max borrow cap to ~$45M (from ~$110M).
