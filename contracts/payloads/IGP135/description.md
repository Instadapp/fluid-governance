# Tighten Supply/Borrow Limits, Cap fsUSDs Withdrawal, Cap USR/RLP DEX Supply, Set reUSD Vault Dust Limits, and Launch USDai-USDC Market

## Summary

This proposal performs eleven Ethereum actions:

1. Reduce base withdrawal limits on **legacy vaults 1–10** to total supply + ~5%.
2. Restrict base withdrawal limits on the **sUSDS sunset vaults** (vaults 58 and 85).
3. Risk-tighten **Liquidity Layer borrow limits across 54 vaults** (expand window 6h → 3h).
4. Tighten smart-debt limits on the **USDC-USDT DEX (id 2)** (expand window 6h → 3h).
5. Tighten smart-debt limits on the **USDC-USDT DEX (id 34)** (expand window 6h → 3h).
6. Tighten smart-debt limits on the **GHO-USDC DEX (id 4)** (expand window 6h → 3h).
7. Restrict the **fsUSDs fToken** base withdrawal limit to total supply + 10%.
8. Set max supply shares to **0** on the **USR-USDC DEX (Pool 20)** and **RLP-USDC DEX (Pool 28)**.
9. Set conservative **dust limits** on **reUSD-USDT / USDC-USDT vault (id 170, TYPE_4)** and **reUSD / GHO-USDC vault (id 181, TYPE_3)** and grant Team Multisig auth.
10. Raise the **USDai-USDC market** (DEX **47** + T2 vault **180**) from dust limits (IGP-134) to **launch limits**, then remove Team Multisig auth on both.
11. Reduce the **USDC-USDT DEX (id 2)** max borrow shares to **20M** (from 50M) as overall stable liquidity has thinned.

## Code Changes

### Action 1: Reduce Legacy Vault 1–10 Base Withdrawal Limits

Sets base withdrawal limits on legacy vaults 1–10 to total supply + ~5%, using `MAX_RESTRICTED_EXPAND_PERCENT` / `MAX_RESTRICTED_EXPAND_DURATION` for the expansion.

| Vault | Supply token | Base withdrawal limit (raw) |
| --- | --- | --- |
| 1 | ETH | `628187e12` |
| 2 | ETH | `945974e12` |
| 3 | wstETH | `646899e12` |
| 4 | wstETH | `544134e12` |
| 5 | wstETH | `549870e12` |
| 6 | weETH | `695132095e12` |
| 7 | sUSDe | `3298946018e12` |
| 8 | sUSDe | `413657754e12` |
| 9 | weETH | `240487e12` |
| 10 | weETH | `213728e12` |

### Action 2: Restrict sUSDS Sunset Vault Withdrawal Limits

| Vault | Supply token | Base withdrawal limit (raw) |
| --- | --- | --- |
| 58 | sUSDs | `650e18` |
| 85 | wstETH | `9372630468e6` |

### Action 3: Tighten Liquidity Layer Borrow Limits (54 Vaults)

Tightens `UserBorrowConfig` for 54 less-trusted Ethereum vaults, reducing the expand window from 6h to 3h and resetting base/max debt ceilings. Amounts are denominated in each borrow token's own decimals and normalised by the live borrow exchange price via `getRawAmount`. Vaults covered: 16, 17, 18, 19, 20, 26, 27, 32, 56, 57, 74, 80, 92, 93, 94, 96, 97, 103, 104, 107, 108, 109, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 130, 137, 138, 140, 141, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 159, 160, 161, 162, 164.

### Action 4: Tighten Smart-Debt Limits on USDC-USDT DEX (id 2)

Sets `DexBorrowProtocolConfigInShares` (expand window 3h) for vaults **47, 50, 98, 99, 156, 163**.

### Action 5: Tighten Smart-Debt Limits on USDC-USDT DEX (id 34)

Sets `DexBorrowProtocolConfigInShares` (expand window 3h) for vaults **126, 127, 157**.

### Action 6: Tighten Smart-Debt Limits on GHO-USDC DEX (id 4)

Sets `DexBorrowProtocolConfigInShares` (expand window 3h) for vaults **61, 125, 139**.

### Action 7: Cap fsUSDs Base Withdrawal Limit

Restricts the fsUSDs fToken's base withdrawal limit on the Liquidity Layer to total supply + 10%. Sets a fixed base withdrawal limit of **5,516.9 sUSDs** (the `5,015.3` sUSDs fsUSDs supply at preparation time × 1.1). The existing mode and expansion (percent / duration) are read from storage and preserved, so only the base withdrawal limit is tightened.

### Action 8: Set USR and RLP DEX Max Supply Shares to 0

- **DEX Pool 20** — USR-USDC: `updateMaxSupplyShares(0)`
- **DEX Pool 28** — RLP-USDC: `updateMaxSupplyShares(0)`
- **Purpose**: Prevent new supply on these DEXes while existing LPs retain withdrawal access

### Action 9: Set Dust Limits for reUSD Vaults (ids 170, 181)

#### Vault 170: reUSD-USDT / USDC-USDT

- **Vault**: reUSD-USDT / USDC-USDT (TYPE_4, vault id 170)
- **Collateral DEX**: reUSD-USDT (Pool 44) — supply shares dust limit (~$7k, 30% expand / 6h)
- **Debt DEX**: USDC-USDT (Pool 2) — borrow shares dust limit (~$7k base / ~$9k max, 30% expand / 6h)
- **Auth**: Grants Team Multisig vault auth for subsequent launch configuration

#### Vault 181: reUSD / GHO-USDC

- **Vault**: reUSD / GHO-USDC (TYPE_3, vault id 181)
- **Supply**: `$7k` REUSD withdraw limit
- **Debt DEX**: GHO-USDC (Pool 4) — borrow shares dust limit (~$7k base / ~$9k max, 30% expand / 6h)
- **Auth**: Grants Team Multisig vault auth for subsequent launch configuration

### Action 10: USDai-USDC Market Launch Limits + Remove Team MS Auth

The USDai-USDC market was held at dust limits in IGP-134 (DEX 47 + vault 180) with Team Multisig auth retained for post-launch configuration. This action raises both to launch-scale Liquidity Layer limits and removes Team Multisig auth.

#### DEX limits (Liquidity Layer)

| DEX | Id | Per-token limit | Authorization |
| --- | --- | --- | --- |
| USDai-USDC | 47 | `$5M` | Remove Team Multisig auth |

#### Vault limits (Liquidity Layer)

| Vault | Id | Type | Base withdraw | Base borrow | Max borrow | Authorization |
| --- | --- | --- | --- | --- | --- | --- |
| USDai-USDC / USDC | 180 | TYPE_2 | smart col at DEX **47** | `$5M` USDC | `$10M` USDC | Remove Team Multisig auth |

No supply-side Liquidity Layer limits are set on vault 180.

### Action 11: Reduce USDC-USDT DEX (id 2) Max Borrow Shares

- **DEX Pool 2** — USDC-USDT: `updateMaxBorrowShares(20_000_000 * 1e18)`
- **Change**: `50M` → `20M` shares
- **Purpose**: Cap borrow exposure against the USDC-USDT pool as overall stable liquidity has thinned

## Description

**Actions 1–7** are risk-tightening measures: they reduce withdrawal headroom on legacy and sunset vaults, shrink borrow limits and expansion windows across less-trusted vaults and DEXes, and cap the fsUSDs withdrawal limit. **Action 8** sets max supply shares to zero on the USR-USDC and RLP-USDC DEXes. **Action 9** introduces the new reUSD vaults (170 TYPE_4, 181 TYPE_3) with conservative dust limits and Team Multisig authorization. **Action 10** launches the USDai-USDC market (DEX 47 + T2 vault 180) from dust to launch limits and removes the Team Multisig auth retained in IGP-134. **Action 11** reduces the USDC-USDT DEX (id 2) max borrow shares from 50M to 20M as overall stable liquidity has thinned.

## Conclusion

IGP-135 tightens supply and borrow limits across legacy/sunset vaults, DEXes, and the fsUSDs fToken, caps USR/RLP DEX supply, sets dust limits on the reUSD vaults (170 and 181), launches the USDai-USDC market (DEX 47 + T2 vault 180) to launch-scale limits while removing Team Multisig auth on both, and reduces the USDC-USDT DEX (id 2) max borrow shares from 50M to 20M.
