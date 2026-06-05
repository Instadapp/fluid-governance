---
name: verify-payload
description: Pre-deploy AI audit of a Fluid governance payload. Classifies every action as HISTORICALLY_VERIFIED / REVIEW_DIFF / NEW_PATTERN against the historical action index, cross-checks every Fluid call against `../fluid-contracts/**/SPEC.md` plus `docs/errors.md` and `audits/audit-expected-behavior.md`, confirms intent coverage, and emits a structured markdown report. Use whenever a new `PayloadIGP<N>.sol` is up for review — BEFORE deployment.
---

# verify-payload

Precise, read-only pre-deploy audit of a governance payload. Produces a
markdown report that a human reviewer can skim in ~2 minutes instead of
re-reading every historical payload line by line.

**You never modify any file while running this skill.** Output is the
report only.

**Past IGP payloads are immutable.** Never edit any existing
`contracts/payloads/IGP<N>/PayloadIGP<N>.sol` where `N` is lower than the
payload under review, unless the user explicitly asks for that exact past
IGP to be changed. Historical payloads may be read for precedent only.

## 1. Scope & invariants

- Input: one payload file + the human's proposal intent (paragraph or
  bullet list). If the proposer ships a `contracts/payloads/IGP<N>/description.md`
  in-tree, use that as intent when no external text is provided.
- Output: a single markdown document shaped like `§6 Report template`
  below. Nothing else. Keep it concise and reviewer-friendly: no payload
  path, run-mode, action-index metadata, source-file tables, or verbose
  machinery unless it is needed to explain a finding.
- You will **not** run `prepare-prices.ts`, `verify-deployment.ts`, or any
  compiler. Those are separate workflows.
- You will **not** rewrite the payload. Findings belong in the report.
- Prefer false positives (`NEW_PATTERN`, `REVIEW_DIFF`) over false
  negatives. When in doubt, surface the question.

## 2. Setup

Perform these steps exactly, in order:

1. Resolve the payload path. Accept either `IGP<N>` or the full
   `contracts/payloads/IGP<N>/PayloadIGP<N>.sol` path.
2. Resolve the `fluid-contracts` repo:
   - Relative: `../fluid-contracts/` from the governance repo root.
   - Absolute on this machine:
     `/home/bergben/Desktop/Coding/instadapp/fluid-contracts`.
   - If the path does not exist, enable **degraded mode** — every
     Fluid-spec check becomes `FLUID_REPO_MISSING` and the final verdict
     cannot exceed `PASS_WITH_NOTES`. Still run every other step.
3. Check for the historical action index at
   `scripts/verify/.cache/action-index.json`.
   - If missing, instruct the user to run
     `npm run verify:action-index` and stop. Do not try to build the
     index yourself.
   - If the index's `generatedAt` is older than the oldest `git log -1`
     timestamp of `contracts/payloads/IGP*`, it is stale — say so and
     continue with a `STALE_INDEX` note.
4. Load the spec map from `.cursor/skills/verify-payload/spec-map.md`.
5. Extract the new payload's actions using the logic in
   `scripts/verify/lib/actionExtractor.ts` and per-action external calls
   via `scripts/verify/lib/externalsExtractor.ts`. You may either read
   and mentally apply those extractors, or ask the user to pre-run them.
   The former is preferred — they are small, deterministic, and their
   source is authoritative.

## 3. Per-action procedure

Repeat for every `actionN()` found in the payload, in order:

### 3.1 Summarise

- Read the NatSpec immediately above the function.
- In one sentence, describe *what happens on-chain* when this action
  executes. Do not restate the NatSpec — say what it means.

### 3.2 Map to human intent

- Identify which bullet / sentence of the human intent this action
  fulfills. Quote the snippet.
- If you cannot find a mapping, flag `UNCLAIMED_ACTION`.

### 3.3 Historical similarity

Using the action index:

1. Compute the action's `bodyHash` via the normalisation from
   `actionExtractor.normaliseBody`. Compare against every `bodyHash` in
   the index.
   - **Hit (identical hash)**: mark `HISTORICALLY_VERIFIED`. List the
     earlier IGPs + action numbers. Extract the literal argument deltas
     (the normaliser renames locals and strips whitespace/comments, but
     preserves every literal, constant, and method/target symbol).
     - For each changed literal, render `old → new`.
     - Validate each new literal against the relevant SPEC.md bounds
       (see 3.4). Plausible changes go in the report as informational.
2. **Partial hit**: same *Fluid external-call set* as some earlier
   action but different `bodyHash`. Mark `REVIEW_DIFF`. Produce a short
   textual diff against the closest historical precedent. Focus the
   review on the delta.

   The "external-call set" used for this comparison is:

   ```
   {  (interfaceName, method)  for every extracted external call whose
      `receiver` is NOT the payload contract itself or one of its
      inherited helper / variables / constants contracts }
   ```

   In particular:

   - Intra-payload calls (receiver `Payload*`, `PayloadIGPMain`,
     `PayloadIGPHelpers`, `PayloadIGPPriceHelpers`, `Constants`,
     `Variables`, private storage-getter helpers like
     `userModuleAddress()`) are **ignored** for the partial-hit check —
     they are plumbing, not protocol calls.
   - Differences in call order and in the argument literals do **not**
     downgrade a partial hit to `NEW_PATTERN`; they are the `delta` you
     describe in the review.
   - Being the "first time since rollback was introduced" does not
     matter for classification if a prior IGP used the same
     `(interfaceName, method)` tuple. Precedent is precedent.

3. **No hit**: the external-call set has no match in the index. Only
   now mark `NEW_PATTERN`. Full review required via 3.4–3.5.

   Before emitting `NEW_PATTERN`, you **must** explicitly state:
   "No prior IGP calls `<interfaceName>.<method>` on a contract of role
   `<role>`", after a full scan of `action-index.json`. If this
   statement is not true, reclassify to `REVIEW_DIFF`. The most common
   regression here is treating an extra intra-payload helper call as a
   novel external call — don't.

### 3.4 Per-call spec checks

For each external call returned by `externalsExtractor.extractExternalCalls`:

1. Resolve the spec via
   `.cursor/skills/verify-payload/spec-map.md`. Precedence:
   1. `interfaceName + method` exact match.
   2. Target contract role inferred from `targetSymbol` +
      `contracts/payloads/common/constants.sol`.
   3. Fallback to `../fluid-contracts/SPEC.md` with an `UNMAPPED_TARGET`
      note.
2. Open the resolved `SPEC.md`. Verify:
   1. The method still exists in the corresponding Solidity source
      (pointed to from the SPEC.md's sections). Compute and cite the
      4-byte selector from the signature you find there.
   2. Argument types line up (decimals, bits, struct layouts).
   3. Parameter bounds from the spec are satisfied. Examples:
      - `ratesAuth`: rate bps ≤ `X_MAX`; delta ≤ authorised max shift.
      - `limitsAuth` / `limitsAuthDex`: new limit within the bounded
        window of current limit.
      - `withdrawLimitAuth` / `Dex`: shift within rate-limited window.
      - `rangeAuthDex`: upper/lower percent within permitted window.
      - `dexFeeHandler`: invocation is permissionless; no auth gate.
      - `pauseAuth`: caller must already be authorised for the target.
      Flag `SPEC_VIOLATION` for each violated invariant and cite the
      exact SPEC.md heading.
   4. Authorization precondition holds — e.g. caller is `TIMELOCK`, auth
      contract is pre-registered on Liquidity, operator is the expected
      multisig, etc.
3. Consult
   `../fluid-contracts/audits/audit-expected-behavior.md` for any entry
   covering the touched code (use `Ctrl+F` on the target area).
   Expected-behavior entries use stable ids (e.g. `L-01`, `X-13`, `P4-07`,
   `C-02`). If the action conflicts with a listed behavior, flag
   `EXPECTED_BEHAVIOR_CONFLICT` and cite the entry id.
4. Decode any numeric revert-code literals via
   `../fluid-contracts/docs/errors.md` when reasoning about failure
   modes.
5. Resolve vault / dex / oracle / module addresses and their bound
   tokens against `../fluid-contracts/deployments/<chain>/*.json` before
   labelling anything as "on-chain state, not re-verified". The
   deployment JSONs are committed constructor-args snapshots; they are
   the authoritative static mapping between vault ids and their
   supply/borrow tokens, between DEX ids and token pairs, between
   `AdminModule` / `UserModule` addresses and their versions, etc.
   Procedure:
   1. Grep the `deployments/<chain>/` directory for the numeric id
      (`"vaultId": <N>`, `"dexId": <N>`, etc.) — not the filename,
      which is cosmetic.
   2. Read the matching JSON's `args` and extract the constructor
      fields relevant to the action (`supplyToken`, `borrowToken`,
      `borrowToken.token0/token1` for smart-collateral / smart-debt
      DEX vaults, `vaultType`, etc.).
   3. Compare against the literal passed by the payload (typically a
      `*_ADDRESS` constant from
      `contracts/payloads/common/constants.sol`). If they match, the
      mapping is **verified**, not `EXTERNAL_UNVERIFIABLE`. If they
      disagree, flag `SPEC_VIOLATION` — a wrong token ↔ vault binding
      is a deploy-time error, not a runtime assumption.
   4. Only fall back to `EXTERNAL_UNVERIFIABLE` when the id is not
      present in the deployments folder at all (chain not tracked,
      vault not yet registered, etc.). Cite the exact JSON path in the
      report so a reader can re-verify in one click.

6. Read live mutable state via Fluid resolver contracts before flagging
   a `REVIEW_DIFF` as "other params need on-chain confirmation". The
   resolvers exist precisely so payload reviewers can diff a proposed
   `updateX` struct against the current packed storage without
   hand-decoding slots.

   **Resolver address + ABI source (do this, nothing else):** the canonical
   index is `../fluid-contracts/deployments/deployments.md` — every resolver,
   every chain, current address. **Always look up the address for the specific
   chain you are querying, directly from `deployments.md`.** Resolver addresses
   are **NOT** reliably identical across chains — some match (a CREATE3
   coincidence), many do not (e.g. `StakingRewardsResolver`,
   `VaultTicksBranchesResolver` differ per chain). Never assume one chain's
   address works on another, and never hardcode an address from memory; read
   the row for `(resolver, chain)` each time. For the ABI, load the matching
   artifact in the **same** repo: `../fluid-contracts/deployments/<chain>/<Name>.json`
   (it pairs `.address` with `.abi`). Pitfalls that waste time:
   - Do **not** read resolver addresses from the sibling `../fluid-deployments`
     repo — it is stale (e.g. lists an old `VaultResolver` `0x394Ce4…`).
   - Do **not** decode with the `../fluid-contracts/out/**/*.json` source ABI —
     it drifts ahead of the deployed contract and `getVaultEntireData` (and
     other nested structs) will fail with "could not decode result data".
     Always use the deployment artifact's `.abi`, which matches the live code.

   For supply/borrow limit audits prefer the flat structs
   `LiquidityResolver.getUserSupplyData(user, token)` /
   `getUserBorrowData(user, token)` (amounts already in normal token units,
   shares for DEX users) or `VaultResolver.getAllVaultsAddresses()` +
   `getVaultEntireData(vault)` (carries `liquidityUserSupplyData` /
   `liquidityUserBorrowData`, `isSmartCol/isSmartDebt`, totals). fTokens via
   `LendingResolver.getAllFTokens()`; smart lendings via
   `SmartLendingResolver.getAllSmartLendingEntireViewDatas()`.

   Coverage map (resolver → the payload-call it validates):

   | Resolver | Proposed call | Getter to read |
   | --- | --- | --- |
   | `LiquidityResolver` | `LIQUIDITY.updateRateDataV2s` / `V1s` | `getTokenRateData(token)` (and the batch variant) |
   | `LiquidityResolver` | `LIQUIDITY.updateTokenConfigs` / `UserSupplyConfigs` / `UserBorrowConfigs` | `getOverallTokenData(token)`, `getUserSupplyData`, `getUserBorrowData` |
   | `VaultResolver` / `VaultT1Resolver` | `IFluidVaultT1.update{CollateralFactor,LiquidationThreshold,LiquidationMaxLimit,LiquidationPenalty,CollateralPerUnitBorrow}` | `getVaultEntireData(vault)` and `getVaultConfiguration` — read current `CF / LT / LML / liquidationPenalty / collateralPerUnitBorrow` |
   | `DexResolver` / `DexReservesResolver` / `DexLiteResolver` | `IFluidDex.update{RangePercents,ThresholdPercents,CenterPriceLimits,FeeAndRevenueCut,Fees,Shares}` | `getDexEntireData(dex)` / `getDexRangeShift` / `getDexThresholdShift` |
   | `InfiniteProxy` + code `eth_getCode` | `IInfiniteProxy.{addImplementation,removeImplementation,setAdmin,setDummyImplementation}` | `getImplementations()`, `getImplementationSigs(impl)`, `getAdmin()`, `readFromStorage(slot)` |
   | `rollbackModule` | `IFluidLiquidityRollback.registerRollbackImplementation` | `readFromStorage(ROLLBACK_SLOT)` and prior-registration check |

   Procedure:

   1. Pick the resolver for the `(interfaceName, method)` tuple via the
      table. If none matches, document it and fall through to step 7.
   2. Get the resolver address from `deployments.md` (or the per-chain
      `<Name>.json` artifact), and load that artifact's `.abi` to decode.
   3. Call the getter with the RPC configured in the repo (default:
      `https://eth-mainnet.public.blastapi.io`, or `$ETH_RPC` /
      `$RPC_URL` when set). Use the resolver's `iXxxResolver.sol` ABI
      that lives next to the SPEC.md.
   4. For every field in the payload's proposed struct, print the
      on-chain value side-by-side with the proposed value. Mark each
      as `unchanged` / `Δ old → new`.
   5. Every `unchanged` field gets a ✅ — no need to list it as a
      caveat. Every `Δ` field must be explained in the intent and
      bounded against SPEC.md; otherwise flag `SPEC_VIOLATION`.
   6. If the RPC is unreachable or the resolver call reverts, flag
      `EXTERNAL_UNVERIFIABLE` with the resolver address, method,
      calldata, and the revert reason. Do **not** silently downgrade
      the finding.

   The purpose is to convert "large economic change — other curve
   params need on-chain confirmation" into a concrete field-by-field
   proof in the audit report. If you wrote that phrase verbatim, you
   did not run this step.
7. For DSA connector spells invoked through `TREASURY.cast`, cross-check
   connector semantics against the Instadapp DSA connectors repository:
   `https://github.com/Instadapp/dsa-connectors/tree/main/contracts`.
   Mainnet connector source paths commonly used by payloads:
   - `BASIC-A`: `contracts/mainnet/connectors/basic/main.sol`
     (`withdraw(address,uint256,address,uint256,uint256)` resolves
     `uint256(-1)` to the DSA's full token balance and transfers it to
     `to`).
   - `BASIC-D-V2`: `contracts/mainnet/connectors/basic-ERC4626/main.sol`
     (`redeem(address,uint256,address,uint256,uint256)` resolves
     `uint256(-1)` to the DSA's full ERC4626 share balance and redeems
     shares to `to`).
   Mention the GitHub path(s) only if there is a finding or execution
   caveat. Only mark a DSA connector spell `EXTERNAL_UNVERIFIABLE` if the
   relevant connector source or function cannot be resolved.
8. For other non-Fluid targets (Avo, Reserve wrappers used only through a
   non-Fluid interface, third-party tokens, etc.), record
   `EXTERNAL_UNVERIFIABLE` with a one-line note about what could not be
   verified.

### 3.5 Parameter sanity pass

Regardless of hit / miss, run these generic sanity checks on literal
arguments:

- Oracle or price-like args that look off by an order of magnitude.
- Percentage args outside `[0, 1e4]` where bps are expected, or
  `[0, 1e6]` where hundredths-of-bps are expected.
- Duration / timestamp args that wildly differ from the historical
  median for the same `(target, method)` pair — inspect the index for
  prior values.
- `address(0)` where non-zero is expected (recipients, token addresses,
  implementation slots).
- The `isActionSkippable(N)` modifier number matches the action number.
  Off-by-one here silently makes the wrong action skippable.

### 3.6 Sub-report

Emit the per-action section using the template in §6.

## 4. Intent coverage pass

After every action has a sub-report:

1. Build a matrix `intent bullet → action(s)`.
2. Any bullet not mapped to at least one action → `MISSING_ACTION`.
3. Render the matrix in the report.

## 5. Overall verdict

- **BLOCK** if any of:
  - `SPEC_VIOLATION`
  - `UNCLAIMED_ACTION`
  - `MISSING_ACTION`
  - red-flag parameter sanity finding (order-of-magnitude price,
    `address(0)` in a recipient slot, wrong `isActionSkippable` index,
    etc.)
- **PASS_WITH_NOTES** if any of:
  - `EXTERNAL_UNVERIFIABLE`
  - `NEW_PATTERN` (no spec violation found)
  - `FLUID_REPO_MISSING`
  - `STALE_INDEX`
  - `UNMAPPED_TARGET`
  - `EXPECTED_BEHAVIOR_CONFLICT` resolved positively with caveats
- **PASS** otherwise.

Never downgrade a `BLOCK` to `PASS_WITH_NOTES`. If a flag was raised in
error, remove it; do not paper over it with a weaker verdict.

## 6. Report template

Render the final output using **exactly** this compact structure. Keep
headings verbatim so automated diffs between runs stay clean. Do not add
the old long-form metadata sections (`Payload`, `Run mode`, `Action index`,
full `Intent coverage`, `Cross-repo references used`, or `Concise verdict`)
unless the user explicitly asks for the expanded audit.

```markdown
# Payload Audit — IGP<N>

- **Verdict:** <PASS | PASS_WITH_NOTES | BLOCK>
- **Actions reviewed:** <count>
- **Intent:** <one-sentence proposal intent>

## Summary

- <plain-English summary bullet 1>
- <plain-English summary bullet 2>
- <mention historical precedent if useful, e.g. "Similar Treasury withdrawals were done in `IGP116` and `IGP119`.">
- <mention top-line caveat only if there is one>

## Per-Action Findings

### Action 1 — <short action title>

- **What it does:** <one sentence describing the on-chain effect>
- **Intent:** <short mapping to the proposal intent>
- **Precedent:** <prior IGP/action if useful, otherwise omit this line>
- **Findings:** <None | concise finding text with severity and why>

<repeat per action>

## Execution Note

- <only include when there is an execution-time balance/auth/order check; otherwise omit this section>

## Open Questions

- <only include if unresolved proposer input is needed; otherwise omit this section>
```

Formatting rules:
- Use `# Payload Audit — IGP<N>` as the only H1.
- Use section headings exactly as shown.
- Keep per-action sections short. If there are no issues, write
  `- **Findings:** None.`
- Include prior IGP precedent when it gives confidence in the pattern,
  but do not include body hashes, selectors, extractor output, action-index
  details, or spec citations unless there is an actual finding.
- Use `PASS` when all actions are covered by intent and have no findings.
- Use `PASS_WITH_NOTES` only for meaningful caveats that do not block
  deployment, and state the caveat in `Summary` or `Execution Note`.
- Use `BLOCK` for `SPEC_VIOLATION`, `UNCLAIMED_ACTION`, `MISSING_ACTION`,
  or red-flag parameter sanity issues.

## 7. Flag glossary (phrasing reference)

Use these exact flag ids. Descriptions are for your reasoning; do not
include them verbatim in reports.

| Flag | When |
| --- | --- |
| `HISTORICALLY_VERIFIED` | `bodyHash` hit against ≥1 prior IGP. |
| `REVIEW_DIFF` | Same externals signature as a precedent, different body. |
| `NEW_PATTERN` | No hit. Needs full spec review. |
| `SPEC_VIOLATION` | Action violates a bound or invariant in a SPEC.md. |
| `UNCLAIMED_ACTION` | Action maps to no human-intent bullet. |
| `MISSING_ACTION` | Human-intent bullet has no action implementing it. |
| `EXPECTED_BEHAVIOR_CONFLICT` | Action contradicts an entry in `audits/audit-expected-behavior.md`. |
| `EXTERNAL_UNVERIFIABLE` | Target is outside Fluid's repo; no spec to check. |
| `OUT_OF_SCOPE_HANDLER` | Touches `bufferRateHandler`, `ethenaRateHandler`, `expandPercentHandler`, or `maxBorrowHandler`. Defer to human review. |
| `UNMAPPED_TARGET` | Target not in `spec-map.md`; fell back to root SPEC.md. |
| `FLUID_REPO_MISSING` | `../fluid-contracts/` not present; check deferred. |
| `STALE_INDEX` | Action index older than the newest payload. |

## 8. Helper script references

Read these files to understand exactly how data is sliced. Treat them as
the source of truth if this skill and the script disagree:

- `scripts/verify/lib/actionExtractor.ts`
- `scripts/verify/lib/externalsExtractor.ts`
- `scripts/verify/build-action-index.ts`
- `scripts/verify/lib/tokens.ts` (cross-check: every `*_ADDRESS` in the
  payload should appear here; if not, call out
  `.cursor/skills/add-payload-token/SKILL.md`)

## 9. Don'ts

- Don't speculate about spec content. If a SPEC.md is silent on a bound,
  say "spec does not constrain X" rather than inventing a bound.
- Don't "verify" a Fluid action without checking the SPEC.md path that
  supports the verification. Cite the path in the report only when it is
  needed to explain a finding or caveat.
- Don't rely on commit messages or CHANGELOG notes for invariants. Spec
  files and `audits/audit-expected-behavior.md` are the only trusted
  sources inside `fluid-contracts`.
- Don't skip §3.5 (parameter sanity) even for `HISTORICALLY_VERIFIED`
  actions — literal deltas can smuggle in bad values.
- Don't produce a verdict of `PASS_WITH_NOTES` when a `BLOCK` condition
  is met.
