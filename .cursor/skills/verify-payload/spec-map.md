# Fluid-contracts spec map

Hard-coded routing table the `verify-payload` skill uses to jump from a
payload's external call straight to the authoritative specification.

All paths are **relative to the repo root** and assume the sibling
`../fluid-contracts/` checkout is present. The absolute path on the
governance developer's machine is
`/home/bergben/Desktop/Coding/instadapp/fluid-contracts`.

If `../fluid-contracts/` is absent, the skill reports every spec-dependent
check as `FLUID_REPO_MISSING` and still prints which paths it *would* have
consulted — this file is the authoritative reference for that fallback.

## Repo-level anchors

| Purpose | Path |
| --- | --- |
| Root architecture | `../fluid-contracts/SPEC.md` |
| Docs index | `../fluid-contracts/docs/docs.md` |
| Architecture diagram | `../fluid-contracts/docs/architecture.jpg` |
| Error registry (decode numeric revert codes) | `../fluid-contracts/docs/errors.md` |
| Audit-expected subtle behavior | `../fluid-contracts/audits/audit-expected-behavior.md` |

`audits/audit-expected-behavior.md` is **mandatory** reading for any action
that touches Liquidity, DEX, DexLite, Vault, Lending, Reserve, Oracle, Config,
or any bit-packed storage layout. Entries are labelled (e.g. `L01–L07`,
`X-01 – X-13`, `P4-*`, `C-*`) — cite them by id when flagging
`EXPECTED_BEHAVIOR_CONFLICT`.

## Target → SPEC.md — primary mapping

| Payload target (address / interface / role) | Spec |
| --- | --- |
| `LIQUIDITY` / `IFluidLiquidityAdmin` / rate-data / limits / exchange-price config | `../fluid-contracts/contracts/liquidity/SPEC.md` |
| `VAULT_FACTORY`, individual Vault T1–T4 admin calls, `IFluidVault*` | `../fluid-contracts/contracts/protocols/vault/SPEC.md` |
| `DEX_FACTORY`, DEX pool admin (range, threshold, fee, auth), `IFluidDex` | `../fluid-contracts/contracts/protocols/dex/SPEC.md` |
| DexLite admin (`IFluidAdminDex` on dexLite) | `../fluid-contracts/contracts/protocols/dexLite/SPEC.md` |
| `LENDING_FACTORY`, fToken / NativeUnderlying admin (`IFTokenAdmin`) | `../fluid-contracts/contracts/protocols/lending/SPEC.md` |
| stETH queue admin | `../fluid-contracts/contracts/protocols/steth/SPEC.md` |
| InfiniteProxy (`setDummyImplementation`, `setImplementation`, `addImplementation`, `removeImplementation`, sig add/remove) | `../fluid-contracts/contracts/infiniteProxy/SPEC.md` |
| Oracle config (Oracle v2 supersedes v1) | `../fluid-contracts/contracts/oracle/SPEC.md` |
| Reserve contract (`rebalance`, `collectRevenue`, whitelist, rewards top-ups) | `../fluid-contracts/contracts/reserve/SPEC.md` |
| Libraries (`BigMathMinified`, `LiquiditySlotsLink`, `LiquidityCalcs`, …) | `../fluid-contracts/contracts/libraries/SPEC.md` |
| Deployer | `../fluid-contracts/contracts/deployer/SPEC.md` |

Oracle v1 findings in `audits/audit-expected-behavior.md` are historical;
cross-check against Oracle v2 when a payload touches the current oracle.

`BigMathUnsafe` is explicitly **not production** — flagged in the
expected-behavior doc's "Scope exclusions". If a payload appears to depend
on it, flag `SPEC_VIOLATION` immediately.

## Config auths / handlers — the usual governance targets

These are the most common payload targets. Each has its own spec.

| Role | Spec |
| --- | --- |
| `pauseAuth` — pause / unpause Liquidity, DEX, DexLite | `../fluid-contracts/contracts/config/pauseAuth/SPEC.md` |
| `ratesAuth` — bounded update of Liquidity rate-data curve points | `../fluid-contracts/contracts/config/ratesAuth/SPEC.md` |
| `limitsAuth` — bounded supply/borrow limit changes on Liquidity | `../fluid-contracts/contracts/config/limitsAuth/SPEC.md` |
| `limitsAuthDex` — bounded supply/borrow share-limit changes on DEX | `../fluid-contracts/contracts/config/limitsAuthDex/SPEC.md` |
| `withdrawLimitAuth` — rate-limited withdraw-limit on Liquidity | `../fluid-contracts/contracts/config/withdrawLimitAuth/SPEC.md` |
| `withdrawLimitAuthDex` — rate-limited withdraw-limit on DEX | `../fluid-contracts/contracts/config/withdrawLimitAuthDex/SPEC.md` |
| `rangeAuthDex` — rate-limited upper/lower range shifts on DEX pools | `../fluid-contracts/contracts/config/rangeAuthDex/SPEC.md` |
| `dexFeeHandler` — permissionless fee rebalancer | `../fluid-contracts/contracts/config/dexFeeHandler/SPEC.md` |
| `vaultFeeRewardsAuth` | `../fluid-contracts/contracts/config/vaultFeeRewardsAuth/SPEC.md` |
| `liquidityTokenAuth` — token-listing auth on Liquidity | `../fluid-contracts/contracts/config/liquidityTokenAuth/SPEC.md` |
| Top-level config index + smaller pieces | `../fluid-contracts/contracts/config/SPEC.md` |

## Out-of-scope handlers

Declared in `contracts/config/SPEC.md` but explicitly out of scope for
governance invariant assertions:

- `bufferRateHandler`
- `ethenaRateHandler`
- `expandPercentHandler`
- `maxBorrowHandler`

If a payload action touches one of these, the skill flags
`OUT_OF_SCOPE_HANDLER` and defers to human review rather than asserting
parameter bounds from the spec.

## Resolution precedence

When deciding which spec to read for a given call, the skill resolves in
this order:

1. Exact `interfaceName + method` pair (e.g. `IFluidLiquidityAdmin.updateRateDataV2s`).
2. Target contract role — e.g. "this is the dex factory", "this is an
   fToken admin call", "this is a pauseAuth call". Use the address
   constant (`VAULT_FACTORY`, `LIQUIDITY`, etc.) from
   `contracts/payloads/common/constants.sol` plus the address labels in
   the governance repo's `audit/expected-behavior.md`.
3. Fallback: `../fluid-contracts/SPEC.md` (root) with an
   `UNMAPPED_TARGET` note prompting the operator to extend this map.

## Updating this map

When `fluid-contracts` adds / renames a spec file, update the relevant
row. Keep this document the **only** place the mapping lives — the skill
body imports it by reference rather than duplicating paths.
