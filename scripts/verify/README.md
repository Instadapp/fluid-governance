# `scripts/verify/`

Read-only tooling for governance-payload reviews. Two main entry points:

| Script | Phase | What it does |
| --- | --- | --- |
| `prepare-prices.ts` | pre-deploy | Emits a minimal block of `<SYMBOL>_USD_PRICE()` overrides into the payload (one per distinct priceVar it references), using live CoinGecko quotes rounded per the registry's rules. The `getRawAmount` dispatch itself lives once in `contracts/payloads/common/pricehelpers.sol`. |
| `verify-deployment.ts` | post-deploy | Compares on-chain bytecode vs the local Hardhat artifact, normalising the CBOR metadata tail and every `immutableReferences` region. |

Supporting libraries (`lib/`):

- `tokens.ts` — registry of every token address a payload may legitimately reference, its CoinGecko id, decimals, `priceVarName` (the getter name declared in `pricehelpers.sol`), and rounding rule.
- `rounding.ts` — rounding policies (`exactOneDollar`, `nearestCent`, `nearestTenDollars`, `nearestThousandDollars`) matching historical payload style.
- `coingecko.ts` — minimal client for the public `simple/price` endpoint with 429/5xx retries.
- `tokenUsage.ts` — regex-based scanner that returns the set of `*_ADDRESS` constants a payload references (ignores comments, strings, and the auto-generated region itself). Also provides `checkDispatchCoverage` which verifies `pricehelpers.sol` has a `token == <X_ADDRESS>` branch for every used token.
- `generator.ts` — deterministic renderer for the override block. Emits one `function <priceVar>() public pure override returns (uint256) { return … }` per *distinct* priceVar referenced by the payload.
- `bytecode.ts` — metadata + immutables-aware bytecode comparator.
- `markers.ts` — shared `BEGIN` / `END` strings.
- `actionExtractor.ts`, `externalsExtractor.ts` — structural slicers used by the historical action index (see below).

Also in this folder:

- `build-action-index.ts` — one-shot walker producing `.cache/action-index.json` for the `verify-payload` skill's O(1) similarity lookups.

There is no `package.json` specific to this folder; it uses the repo's top-level TypeScript and ts-node config.

## Pre-deploy workflow

1. Author `contracts/payloads/IGP{N}/PayloadIGP{N}.sol`. Inherit `PayloadIGPPriceHelpers` (from `contracts/payloads/common/pricehelpers.sol`) **in addition to** `PayloadIGPMain`. The base class brings the full `getRawAmount` dispatch and every `<SYMBOL>_USD_PRICE()` as a reverting virtual getter.
2. Leave the area where prices would go empty. The script will insert a block between:

   ```
   // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
   // ...
   // --- END AUTO-GENERATED PRICES ---
   ```

   The block contains only per-token overrides, one line each, e.g.:

   ```solidity
   function ETH_USD_PRICE()    public pure override returns (uint256) { return 2_000 * 1e2; }
   function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
   ```

3. Run:

   ```sh
   npm run verify:prices -- --payload IGP129
   # or (equivalent, no npm indirection):
   node --loader ts-node/esm --no-warnings scripts/verify/prepare-prices.ts --payload IGP129
   ```

4. Inspect the printed summary table and the resulting git diff. Values are rounded:
   - `exactOneDollar` — every stable → `1 * 1e2`.
   - `nearestCent` — yield-stables and governance → `1.20 * 1e2`.
   - `nearestTenDollars` — ETH + LSTs/LRTs + gold → `2_000 * 1e2`.
   - `nearestThousandDollars` — BTC family → `69_000 * 1e2`.
5. If happy, `npm run compile` and `npm run deploy:payload`.

### Unknown token / missing dispatch error

The script runs two gates before fetching prices:

- **Unknown token** (exit `2`, `Unknown token address identifier(s) used by ...`): a `*_ADDRESS` has no entry in `lib/tokens.ts`.
- **Missing dispatch** (exit `2`, `pricehelpers.sol has no dispatch branch for ...`): the entry exists but `pricehelpers.sol` doesn't wire the address to its price getter yet.

Both are fixed by `.cursor/skills/add-payload-token/SKILL.md`. The two files (`tokens.ts` and `pricehelpers.sol`) must stay in sync; the skill walks through updating both.

### Dry-run

`--dry-run` prints the proposed block to stdout and leaves the file on disk untouched.

## Post-deploy workflow

After the proposal has been deployed (first step of the full queue/execute flow — the payload contract itself is deployed separately), verify the on-chain bytecode:

```sh
npm run verify:deployment -- \
  --payload IGP129 \
  --address 0xabc... \
  --rpc $ETH_RPC
```

The script:

1. Reads `artifacts/contracts/payloads/IGP129/PayloadIGP129.sol/PayloadIGP129.json`.
2. Fetches `eth_getCode(address)` from the supplied RPC.
3. Zeros out the CBOR metadata tail and every `immutableReferences` region on both sides.
4. Keccak-hashes and compares.
5. Prints both hashes and `PASS` / `FAIL`; exits non-zero on mismatch.

`ETH_RPC` or `RPC_URL` are honoured if `--rpc` is omitted.

## Historical action index

`build-action-index.ts` walks every `contracts/payloads/IGP<N>/PayloadIGP<N>.sol`, extracts each `actionN()` body, and writes a JSON cache that the `verify-payload` skill uses to answer "have we seen this action before?" in O(1). Regenerate it when payloads change:

```sh
npm run verify:action-index
```

The cache lives at `scripts/verify/.cache/action-index.json`. Safe to gitignore.

## Design notes

- Only the payload file being processed is ever modified. Nothing else in the repo is mutated.
- No RPC calls from `prepare-prices.ts`. Only CoinGecko.
- No RPC calls from the lib helpers — only `verify-deployment.ts` talks to chain.
- The price rounding rules live alongside their tokens in one registry so reviewers can diff additions in a single file.
- `pricehelpers.sol` is invariant across IGPs (never mutated per proposal). It changes only when the token universe itself changes — new token support is a one-time update handled by the add-payload-token skill.
- Price getters in `pricehelpers.sol` revert by default. A payload that references a token but forgets to override its getter will revert at simulator time with a clearly-named error (`"ETH_USD_PRICE not set"`), never silently with a zero price.
- CoinGecko IDs are best-effort; fix the id in `tokens.ts` when CoinGecko renames a coin.

## Related

- `.cursor/skills/add-payload-token/SKILL.md` — procedure for registering a new token.
- `.cursor/skills/verify-payload/SKILL.md` — AI-driven pre-deploy action plausibility audit, cross-referenced against `../fluid-contracts/`.
- `.cursor/skills/verify-payload/spec-map.md` — target → SPEC.md mapping the audit skill consults.
