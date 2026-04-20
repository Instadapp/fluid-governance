# `scripts/verify/`

Read-only tooling for governance-payload reviews. Two main entry points:

| Script | Phase | What it does |
| --- | --- | --- |
| `prepare-prices.ts` | pre-deploy | Writes an auto-generated `getRawAmount` + price-constant block into the payload, using live CoinGecko quotes rounded per the registry's rules. |
| `verify-deployment.ts` | post-deploy | Compares on-chain bytecode vs the local Hardhat artifact, normalising the CBOR metadata tail and every `immutableReferences` region. |

Supporting libraries (`lib/`):

- `tokens.ts` — registry of every token address a payload may legitimately reference, its CoinGecko id, decimals, and rounding rule.
- `rounding.ts` — rounding policies (`exactOneDollar`, `nearestCent`, `nearestTenDollars`, `nearestThousandDollars`) matching historical payload style.
- `coingecko.ts` — minimal client for the public `simple/price` endpoint with 429/5xx retries.
- `tokenUsage.ts` — regex-based scanner that returns the set of `*_ADDRESS` constants a payload references (ignores comments, strings, and the auto-generated region itself).
- `generator.ts` — deterministic renderer for the marker block.
- `bytecode.ts` — metadata + immutables-aware bytecode comparator.
- `markers.ts` — shared `BEGIN` / `END` strings.
- `actionExtractor.ts`, `externalsExtractor.ts` — structural slicers used by the historical action index (see below).

Also in this folder:

- `build-action-index.ts` — one-shot walker producing `.cache/action-index.json` for the `verify-payload` skill's O(1) similarity lookups.

There is no `package.json` specific to this folder; it uses the repo's top-level TypeScript and ts-node config.

## Pre-deploy workflow

1. Author `contracts/payloads/IGP{N}/PayloadIGP{N}.sol`. Inherit `PayloadIGPPriceHelpers` (from `contracts/payloads/common/pricehelpers.sol`) instead of hand-writing the exchange-price math.
2. Leave the area where prices would go empty. The script will insert a block between:

   ```
   // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
   // ...
   // --- END AUTO-GENERATED PRICES ---
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

### Unknown token error

If the script exits with code 2 and lists `*_ADDRESS` identifiers it does not recognise, add them to `lib/tokens.ts`. See `.cursor/skills/add-payload-token/SKILL.md` for the exact procedure.

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
- CoinGecko IDs are best-effort; fix the id in `tokens.ts` when CoinGecko renames a coin.

## Related

- `.cursor/skills/add-payload-token/SKILL.md` — procedure for registering a new token.
- `.cursor/skills/verify-payload/SKILL.md` — AI-driven pre-deploy action plausibility audit, cross-referenced against `../fluid-contracts/`.
- `.cursor/skills/verify-payload/spec-map.md` — target → SPEC.md mapping the audit skill consults.
