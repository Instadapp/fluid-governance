/**
 * actionExtractor — slice every `actionN()` body out of a payload file.
 *
 * Every historical IGP follows the same convention: `action1()`, `action2()`,
 * … declared as `internal` with `isActionSkippable(N)`, and a NatSpec comment
 * immediately above the signature of the form `/// @notice Action N: ...`.
 *
 * We deliberately stay regex-based because:
 *   - Hardhat artifacts expose compiled ABIs and source names, but not the
 *     per-function source ranges we need without pulling in a solc AST walk.
 *   - A lightweight extractor makes the `build-action-index.ts` walker fast
 *     (~120 payloads * ~10 actions each in well under a second).
 *
 * Brace-matching is done character-by-character while honouring string and
 * comment literals so an inline `"}"` inside a string cannot cut the body
 * short.
 */

import { readFileSync } from "node:fs";
import { keccak256, toHex } from "viem";

export interface ExtractedAction {
  /** `action1`, `action2`, … */
  name: string;
  /** Numeric index parsed from the name (1-based). */
  index: number;
  /** Everything between the opening and closing `{}` of the body, trimmed. */
  body: string;
  /** Raw function declaration up to (not including) the opening `{`. */
  signature: string;
  /** Concatenated `///` doc lines directly preceding the function. */
  natspec: string;
  /** The numeric argument of `isActionSkippable(N)` in the modifier, if any. */
  skippableIndex: number | null;
  /** 1-based [startLine, endLine] covering signature + body. */
  lineRange: [number, number];
  /** Keccak256 of the structurally-normalised body. Stable across IGPs. */
  bodyHash: string;
  /** The body after normalisation (whitespace / comments / local rename). */
  normalisedBody: string;
}

export function extractActions(payloadPath: string): ExtractedAction[] {
  const src = readFileSync(payloadPath, "utf8");
  return extractActionsFromSource(src);
}

export function extractActionsFromSource(
  src: string
): ExtractedAction[] {
  const result: ExtractedAction[] = [];

  // Find every function-declaration keyword. The preamble (visibility,
  // modifier, return clause) is captured up to the first `{` past it.
  const FN_START = /\bfunction\s+(action(\d+))\s*\(/g;

  let m: RegExpExecArray | null;
  while ((m = FN_START.exec(src)) !== null) {
    const fullName = m[1]!;
    const index = Number(m[2]!);

    // Find the body open-brace at or after the signature, skipping over
    // comments / strings which cannot legitimately contain a `{` in this
    // context but which we still respect for correctness.
    const openBrace = findNextUnquoted(src, FN_START.lastIndex, "{");
    if (openBrace === -1) continue;

    const closeBrace = findMatchingBrace(src, openBrace);
    if (closeBrace === -1) continue;

    const signature = src.slice(m.index, openBrace).trim();
    const rawBody = src.slice(openBrace + 1, closeBrace);
    const body = rawBody.trim();

    const natspec = grabNatspecAbove(src, m.index);

    const skippableMatch = /isActionSkippable\(\s*(\d+)\s*\)/.exec(signature);
    const skippableIndex = skippableMatch ? Number(skippableMatch[1]) : null;

    const normalisedBody = normaliseBody(body);
    const bodyHash = keccak256(toHex(normalisedBody));

    const [startLine, endLine] = computeLineRange(
      src,
      m.index,
      closeBrace + 1
    );

    result.push({
      name: fullName,
      index,
      body,
      signature,
      natspec,
      skippableIndex,
      lineRange: [startLine, endLine],
      bodyHash,
      normalisedBody,
    });
  }

  result.sort((a, b) => a.index - b.index);
  return result;
}

// ------------------------------------------------------------------
// Body normalisation — defines what "structurally equal" means.
// ------------------------------------------------------------------

/**
 * Produce a canonical form of a function body so two actions with the same
 * structure (but different whitespace, comments, or local variable names)
 * collapse to the same hash.
 *
 * Steps:
 *   1. Strip `//` and `/* *\/` comments.
 *   2. Collapse all runs of whitespace to a single space.
 *   3. Rename local `uintX`/`bytesX`/`address`/`bool`/custom-struct bindings
 *      to `$1, $2, …` in order of first appearance. Only identifiers that
 *      appear as declarations are rewritten; external symbol references
 *      (type names, constants, function names) remain untouched.
 *
 * This is a heuristic — false negatives ("looks different, actually same")
 * are worse than false positives for an audit helper. When in doubt, err
 * on the side of reporting `NEW_PATTERN` and letting the human review.
 */
export function normaliseBody(body: string): string {
  let s = stripCommentsAndStrings(body);

  s = s.replace(/\s+/g, " ").trim();

  // Local variable declarations look like:
  //   uint256 name_ = ...;
  //   address _name;
  //   bool skip = ...;
  //   bytes4[] memory sigs_ = ...;
  //   FluidLiquidityAdminStructs.RateDataV2Params[] memory params_ = new ...;
  //
  // We match the type head (a sequence of identifiers separated by `.` with
  // optional `[...]` array suffixes) followed by optional `memory`/`storage`/
  // `calldata`, followed by the local name.
  const DECL_HEAD =
    /\b([A-Za-z_][A-Za-z_0-9.]*(?:\[\s*\])?(?:\[\s*\])?)\s+(?:(?:memory|storage|calldata)\s+)?([A-Za-z_][A-Za-z_0-9]*)\s*(?==|;|,|\))/g;

  const aliases = new Map<string, string>();
  s = s.replace(DECL_HEAD, (_match, typeHead: string, name: string) => {
    // Skip obvious non-declarations: `return X`, `if X`, `else X`, etc.
    // `DECL_HEAD` only fires on `TYPE NAME` pairs, but `address(X)` is a
    // valid function-call pattern that could match `address` followed by
    // `(X)`. Guard against it explicitly.
    if (RESERVED_HEADS.has(typeHead)) return `${typeHead} ${name}`;

    if (!aliases.has(name)) {
      aliases.set(name, `$${aliases.size + 1}`);
    }
    return `${typeHead} ${aliases.get(name)!}`;
  });

  // Replace every remaining occurrence of the local names with their alias.
  // Use word-boundary replacement so `foo_` inside `foo_bar` is left alone.
  for (const [original, alias] of aliases) {
    const re = new RegExp(`\\b${escapeRegex(original)}\\b`, "g");
    s = s.replace(re, alias);
  }

  return s;
}

const RESERVED_HEADS = new Set([
  "return",
  "if",
  "else",
  "for",
  "while",
  "emit",
  "revert",
  "require",
  "new",
  "delete",
  "assembly",
]);

// ------------------------------------------------------------------
// String / comment-aware helpers
// ------------------------------------------------------------------

function stripCommentsAndStrings(s: string): string {
  let out = "";
  let i = 0;
  const n = s.length;
  while (i < n) {
    const c = s[i]!;
    const c2 = s[i + 1];
    if (c === "/" && c2 === "/") {
      const nl = s.indexOf("\n", i);
      i = nl === -1 ? n : nl;
      continue;
    }
    if (c === "/" && c2 === "*") {
      const end = s.indexOf("*/", i + 2);
      i = end === -1 ? n : end + 2;
      continue;
    }
    if (c === '"' || c === "'") {
      const quote = c;
      i += 1;
      while (i < n) {
        const ch = s[i]!;
        if (ch === "\\" && i + 1 < n) {
          i += 2;
          continue;
        }
        if (ch === quote) {
          i += 1;
          break;
        }
        i += 1;
      }
      // Replace the string literal with a stable placeholder so equal
      // strings still count as equal after normalisation.
      out += '""';
      continue;
    }
    out += c;
    i += 1;
  }
  return out;
}

function findNextUnquoted(
  s: string,
  from: number,
  needle: string
): number {
  let i = from;
  const n = s.length;
  while (i < n) {
    const c = s[i]!;
    const c2 = s[i + 1];
    if (c === "/" && c2 === "/") {
      const nl = s.indexOf("\n", i);
      i = nl === -1 ? n : nl;
      continue;
    }
    if (c === "/" && c2 === "*") {
      const end = s.indexOf("*/", i + 2);
      i = end === -1 ? n : end + 2;
      continue;
    }
    if (c === '"' || c === "'") {
      const quote = c;
      i += 1;
      while (i < n) {
        const ch = s[i]!;
        if (ch === "\\" && i + 1 < n) {
          i += 2;
          continue;
        }
        if (ch === quote) {
          i += 1;
          break;
        }
        i += 1;
      }
      continue;
    }
    if (c === needle) return i;
    i += 1;
  }
  return -1;
}

function findMatchingBrace(s: string, openIdx: number): number {
  let depth = 0;
  let i = openIdx;
  const n = s.length;
  while (i < n) {
    const c = s[i]!;
    const c2 = s[i + 1];
    if (c === "/" && c2 === "/") {
      const nl = s.indexOf("\n", i);
      i = nl === -1 ? n : nl;
      continue;
    }
    if (c === "/" && c2 === "*") {
      const end = s.indexOf("*/", i + 2);
      i = end === -1 ? n : end + 2;
      continue;
    }
    if (c === '"' || c === "'") {
      const quote = c;
      i += 1;
      while (i < n) {
        const ch = s[i]!;
        if (ch === "\\" && i + 1 < n) {
          i += 2;
          continue;
        }
        if (ch === quote) {
          i += 1;
          break;
        }
        i += 1;
      }
      continue;
    }
    if (c === "{") {
      depth += 1;
    } else if (c === "}") {
      depth -= 1;
      if (depth === 0) return i;
    }
    i += 1;
  }
  return -1;
}

/**
 * Return the concatenated `///` doc-comment lines directly preceding the
 * byte at `fnStart`. Stops at the first blank line / non-comment line.
 */
function grabNatspecAbove(src: string, fnStart: number): string {
  const before = src.slice(0, fnStart);
  const lines = before.split("\n");
  const out: string[] = [];
  for (let i = lines.length - 1; i >= 0; i--) {
    const raw = lines[i]!;
    const trimmed = raw.trim();
    if (trimmed === "") {
      if (out.length > 0) break;
      continue;
    }
    if (trimmed.startsWith("///")) {
      out.unshift(trimmed.replace(/^\/{3}\s?/, ""));
      continue;
    }
    // Block comment `/** ... */` — pull the whole block if it ends right
    // before the function.
    if (trimmed.startsWith("*") || trimmed.startsWith("*/")) {
      out.unshift(trimmed.replace(/^\*\/?\s?/, ""));
      continue;
    }
    if (trimmed.startsWith("/**") || trimmed.startsWith("/*")) {
      out.unshift(trimmed.replace(/^\/\*{1,2}\s?/, ""));
      break;
    }
    break;
  }
  return out.join(" ").trim();
}

function computeLineRange(
  src: string,
  startIdx: number,
  endIdx: number
): [number, number] {
  const before = src.slice(0, startIdx);
  const inside = src.slice(startIdx, endIdx);
  const startLine = (before.match(/\n/g)?.length ?? 0) + 1;
  const endLine = startLine + (inside.match(/\n/g)?.length ?? 0);
  return [startLine, endLine];
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
