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

## 1. Scope & invariants

- Input: one payload file + the human's proposal intent (paragraph or
  bullet list). If the proposer ships a `contracts/payloads/IGP<N>/description.md`
  in-tree, use that as intent when no external text is provided, and call
  that out in the report's "Run mode" line.
- Output: a single markdown document shaped like `§6 Report template`
  below. Nothing else. The document **must end** with the `## Concise
  verdict` block described in §6 — this is the part a reader should be
  able to consume in 10 seconds, so it goes last (under the full
  findings), not first.
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
2. **Partial hit**: same externals signature vector
   `(targetSymbol, interfaceName, method)` but different `bodyHash`.
   Mark `REVIEW_DIFF`. Produce a short textual diff against the closest
   historical precedent. Focus the review on the delta.
3. **No hit**: mark `NEW_PATTERN`. Full review required via 3.4–3.5.

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
5. For non-Fluid targets (Avo, Reserve wrappers used only through a
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

Render the final output using **exactly** this structure. Keep headings
verbatim so automated diffs between runs stay clean.

```markdown
# Payload audit — IGP<N>

- **Verdict:** <PASS | PASS_WITH_NOTES | BLOCK>
- **Payload:** `contracts/payloads/IGP<N>/PayloadIGP<N>.sol`
- **Actions reviewed:** <count>
- **Run mode:** <full | degraded (FLUID_REPO_MISSING) | stale-index>
- **Action index:** `scripts/verify/.cache/action-index.json`
  (generated <timestamp>)

## Summary

<3–6 bullets: what the proposal does in plain English, any top-line risks>

## Per-action findings

### action1 — <one-sentence on-chain effect>

- **NatSpec:** <quote>
- **Intent mapping:** <quoted human-intent fragment>
- **Historical class:** <HISTORICALLY_VERIFIED | REVIEW_DIFF | NEW_PATTERN>
  - <closest precedent IGP + action>
  - <literal deltas, if any>
- **External calls:**
  | Target | Interface | Method | Selector | Spec |
  | --- | --- | --- | --- | --- |
  | LIQUIDITY | IFluidLiquidityAdmin | updateRateDataV2s | 0x… | `../fluid-contracts/contracts/liquidity/SPEC.md#...` |
- **Spec checks:** <pass/fail per invariant, with citations>
- **Expected-behavior cross-refs:** <cite ids or "none">
- **Parameter sanity:** <pass / list of flags>
- **Flags:** <none | comma-separated list of flag ids>

<repeat per action>

## Intent coverage

| Intent bullet | Action(s) | Status |
| --- | --- | --- |
| ... | action3 | covered |
| ... | — | **MISSING_ACTION** |

## Cross-repo references used

- `../fluid-contracts/contracts/liquidity/SPEC.md` — updateRateDataV2s
- `../fluid-contracts/audits/audit-expected-behavior.md#L-04` — rate curve
- `../fluid-contracts/docs/errors.md#40001` — RateVersionNotSupported
- ...

## Open questions for the proposer

- <unresolved ambiguity 1>
- ...

## Concise verdict

- **Overall:** <✅ PASS | ⚠️ PASS_WITH_NOTES | ❌ BLOCK> — <≤15-word reason>

| Action | Status | Description |
| --- | --- | --- |
| action1 | <✅ PASS \| ⚠️ WARN \| ❌ FAIL> | <≤18-word self-contained headline> |
| action2 | <✅ PASS \| ⚠️ WARN \| ❌ FAIL> | <≤18-word self-contained headline> |
| ... | ... | ... |

- **Must-check before execution:** <1–3 bullets of on-chain reads or
  ordering constraints the executor has to verify; omit the bullet
  entirely if there are none>
```

**Emoji rule (strict):** every status label in the `Concise verdict`
block — the Overall line and every row of the table — **must** be
prefixed inline with its emoji (`✅`, `⚠️`, `❌`). No separate
status-icon column, no emoji-only cells. The emoji goes in front of the
word, e.g. `✅ PASS`, `⚠️ WARN`, `❌ FAIL`, `⚠️ PASS_WITH_NOTES`,
`❌ BLOCK`. Do not introduce new emoji or replace the word itself.

**Concise-verdict mapping rules (strict; do not improvise):**

- `PASS` on an action ⇔ no flag raised on it other than
  `HISTORICALLY_VERIFIED` or `REVIEW_DIFF` where every literal delta is
  spec-validated and no `EXTERNAL_UNVERIFIABLE` / dependency note exists.
- `WARN` on an action ⇔ at least one of `NEW_PATTERN`,
  `EXTERNAL_UNVERIFIABLE`, `UNMAPPED_TARGET`, `OUT_OF_SCOPE_HANDLER`,
  `STALE_INDEX`, `FLUID_REPO_MISSING`, `EXPECTED_BEHAVIOR_CONFLICT`
  (resolved positively), or a parameter-sanity caveat that is
  informational only.
- `FAIL` on an action ⇔ any `SPEC_VIOLATION`, `UNCLAIMED_ACTION`, or a
  red-flag sanity finding (order-of-magnitude price, `address(0)` in a
  recipient slot, wrong `isActionSkippable` index, etc.).
- **Overall verdict** is the max over per-action severity and the
  intent-coverage pass (a `MISSING_ACTION` from §4 forces `BLOCK`).
- The per-action `Description` cell must be self-contained — a reader
  who skipped the full report should still understand what the action
  does and (for `WARN` / `FAIL`) why it's flagged. Keep it to one line;
  do not include bullet lists or links inside the cell.

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
- Don't "verify" a Fluid action without citing the SPEC.md path that
  supports the verification. A report without citations is evidence of a
  missed check.
- Don't rely on commit messages or CHANGELOG notes for invariants. Spec
  files and `audits/audit-expected-behavior.md` are the only trusted
  sources inside `fluid-contracts`.
- Don't skip §3.5 (parameter sanity) even for `HISTORICALLY_VERIFIED`
  actions — literal deltas can smuggle in bad values.
- Don't produce a verdict of `PASS_WITH_NOTES` when a `BLOCK` condition
  is met.
