/**
 * externalsExtractor — enumerate every external call inside an action body.
 *
 * Payloads are written in a small, stereotyped style. An external call looks
 * like one of:
 *
 *   TARGET.method(arg1, arg2);
 *   ITarget(TARGET).method(arg1, arg2);
 *   ITarget(address(TARGET)).method(...);
 *   IFactory(FACTORY_ADDR).deployVault({ ..named args.. });
 *   SomeLib.helper(...).furtherMethod(...);   // treated as call on the inner
 *
 * The extractor walks the body, identifies receiver + method pairs, and
 * collects literal arguments where we can reason about them without a full
 * AST. String, number, bool, and simple identifier args are recorded
 * verbatim; complex struct/array args are recorded as `"<expr>"` to give
 * the reviewer a breadcrumb without attempting to reconstruct semantics.
 *
 * This is purely a hint provider for the `verify-payload` AI skill. Misses
 * (under-reporting a call) are worse than false positives, because the skill
 * falls back to textual diff review when `NEW_PATTERN` is flagged.
 */

export interface ExtractedCall {
  /** Receiver expression as written (e.g. `LIQUIDITY`, `IFluidVaultT1(vault_)`). */
  receiver: string;
  /** Best-effort target token — the `*_ADDRESS` / `CONST` symbol the call flows to. */
  targetSymbol: string | null;
  /** Interface name when the call uses `IX(addr).method(...)` form. */
  interfaceName: string | null;
  /** The method identifier. */
  method: string;
  /** 4-byte selector placeholder — `0x` if we can't compute it; computed by
   *  the caller with the method signature when available. */
  selector: string | null;
  /** Comma-separated list of raw argument expressions (un-normalised). */
  rawArgs: string[];
  /** Source index inside the body string where the call starts (0-based). */
  offset: number;
}

/**
 * Extract every external-call-shaped expression from `body`.
 *
 * `body` is the raw text between an action's `{}`. It must not contain
 * outer function declarations; callers use `actionExtractor.extractActions`
 * first and feed the `.body` of each action here.
 */
export function extractExternalCalls(body: string): ExtractedCall[] {
  const src = stripComments(body);
  const calls: ExtractedCall[] = [];

  // Walk every `.<ident>(` occurrence. These are either:
  //   - method calls on a prior expression (our primary interest)
  //   - member accesses followed by a paren (same thing syntactically)
  //   - occasional library calls like `LiquidityCalcs.calcExchangePrices(...)`
  //     which we also capture; callers filter these out if irrelevant.
  const METHOD = /\.([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
  let m: RegExpExecArray | null;
  while ((m = METHOD.exec(src)) !== null) {
    const method = m[1]!;
    const parenOpen = src.indexOf("(", m.index + 1);
    if (parenOpen === -1) continue;
    const parenClose = matchParen(src, parenOpen);
    if (parenClose === -1) continue;

    // Receiver: walk backwards from `.` collecting a balanced expression.
    const receiverEnd = m.index;
    const receiverStart = walkReceiverBack(src, receiverEnd);
    if (receiverStart === -1) continue;
    const receiver = src.slice(receiverStart, receiverEnd).trim();

    const argStr = src.slice(parenOpen + 1, parenClose);
    const rawArgs = splitArgs(argStr);

    const { targetSymbol, interfaceName } = parseReceiver(receiver);

    calls.push({
      receiver,
      targetSymbol,
      interfaceName,
      method,
      selector: null,
      rawArgs,
      offset: receiverStart,
    });
  }

  return calls;
}

// ------------------------------------------------------------------
// Helpers
// ------------------------------------------------------------------

/**
 * Classify the receiver expression into `(targetSymbol, interfaceName)`.
 *
 * Recognised shapes:
 *   1. `ITarget(EXPR)` — interface cast. `interfaceName = ITarget`,
 *      `targetSymbol` = inner-most identifier of `EXPR`.
 *   2. `TARGET` — bare identifier. `targetSymbol = TARGET`, no interface.
 *   3. `something.member` — fall back to recursive parse of `something`.
 */
function parseReceiver(
  receiver: string
): { targetSymbol: string | null; interfaceName: string | null } {
  const trimmed = receiver.trim();

  // Shape 1: `IFoo(EXPR)` — only if the whole receiver is that form.
  const interfaceMatch = /^([A-Z][A-Za-z0-9_]*)\s*\(([\s\S]*)\)$/.exec(trimmed);
  if (interfaceMatch && balanced(interfaceMatch[2]!)) {
    const interfaceName = interfaceMatch[1]!;
    const inner = interfaceMatch[2]!.trim();
    return {
      interfaceName,
      targetSymbol: extractInnermostIdentifier(inner),
    };
  }

  // Shape 3: member access — fall back to the head.
  const head = trimmed.split(".")[0]!.trim();
  const ident = extractInnermostIdentifier(head);
  return { interfaceName: null, targetSymbol: ident };
}

/**
 * `address(X)` → `X`. `X.y.z` → `X`. Pure identifier → itself.
 * Numeric / string literals → `null`.
 */
function extractInnermostIdentifier(expr: string): string | null {
  let s = expr.trim();
  while (/^[A-Za-z_][A-Za-z0-9_]*\s*\(/.test(s) && s.endsWith(")")) {
    const open = s.indexOf("(");
    s = s.slice(open + 1, -1).trim();
  }
  const head = s.split(/[.\s(,]/)[0]!.trim();
  if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(head)) return head;
  return null;
}

function balanced(s: string): boolean {
  let depth = 0;
  for (const c of s) {
    if (c === "(") depth += 1;
    else if (c === ")") depth -= 1;
    if (depth < 0) return false;
  }
  return depth === 0;
}

/**
 * Starting from `end`, walk back over the receiver expression of a method
 * call. Stops when we hit a character that cannot be part of an expression
 * (`;`, `{`, `}`, `=`, `,`, leading whitespace in statement position).
 *
 * Returns the starting index of the receiver, or -1.
 */
function walkReceiverBack(src: string, end: number): number {
  let i = end;
  let depth = 0;
  // First, skip any whitespace immediately before the dot.
  while (i > 0 && /\s/.test(src[i - 1]!)) i -= 1;

  while (i > 0) {
    const c = src[i - 1]!;
    if (c === ")" || c === "]") {
      depth += 1;
      i -= 1;
      continue;
    }
    if (c === "(" || c === "[") {
      if (depth === 0) break;
      depth -= 1;
      i -= 1;
      continue;
    }
    if (depth > 0) {
      i -= 1;
      continue;
    }
    if (/[A-Za-z0-9_.\s]/.test(c)) {
      i -= 1;
      continue;
    }
    break;
  }
  return i;
}

function matchParen(src: string, openIdx: number): number {
  let depth = 0;
  for (let i = openIdx; i < src.length; i++) {
    const c = src[i]!;
    if (c === "(") depth += 1;
    else if (c === ")") {
      depth -= 1;
      if (depth === 0) return i;
    }
  }
  return -1;
}

/** Split top-level `,`-separated arguments, respecting parens and braces. */
function splitArgs(s: string): string[] {
  const out: string[] = [];
  let depth = 0;
  let start = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s[i]!;
    if (c === "(" || c === "[" || c === "{") depth += 1;
    else if (c === ")" || c === "]" || c === "}") depth -= 1;
    else if (c === "," && depth === 0) {
      const piece = s.slice(start, i).trim();
      if (piece) out.push(piece);
      start = i + 1;
    }
  }
  const tail = s.slice(start).trim();
  if (tail) out.push(tail);
  return out;
}

function stripComments(s: string): string {
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
    out += c;
    i += 1;
  }
  return out;
}
