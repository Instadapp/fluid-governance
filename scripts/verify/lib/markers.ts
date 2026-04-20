/**
 * Shared marker strings for the auto-generated price region inside payload
 * files. Kept in one place so `tokenUsage.ts`, `generator.ts`, and
 * `prepare-prices.ts` agree byte-for-byte.
 *
 * The region looks like:
 *
 *   // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
 *   // fetched: <ISO-8601 UTC>, source: coingecko
 *   <price constants>
 *   <getRawAmount override>
 *   // --- END AUTO-GENERATED PRICES ---
 *
 * The BEGIN line is prefix-only; the timestamp sits on the next line so a
 * re-run produces minimal diffs on unchanged files.
 */

export const BEGIN_MARKER_PREFIX =
  "// --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---";

export const END_MARKER = "// --- END AUTO-GENERATED PRICES ---";
