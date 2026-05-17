/**
 * Bytecode comparison helpers for post-deploy verification.
 *
 * Compares the locally compiled `deployedBytecode` (from a Hardhat artifact)
 * against the on-chain `eth_getCode` result, normalising for:
 *
 *   - The trailing CBOR metadata hash (ipfs/bzzr hash + solc version tag)
 *     which changes on every reproducible build. Structure (see
 *     https://docs.soliditylang.org/en/latest/metadata.html):
 *       ... <cbor> a2 64 69 70 66 73 58 22 12 20 <32-byte hash>
 *                  64 73 6f 6c 63 43 <3-byte solc ver> 00 33
 *     where the final 2 bytes `00 33` are the CBOR length prefix (0x0033 = 51).
 *   - Immutable regions listed in `immutableReferences` which embed values
 *     (like `address(this)`) decided at construction time.
 *
 * After normalisation, a keccak256 hash compare answers "does the on-chain
 * code match what we committed?" unambiguously.
 */

import { keccak256 } from "viem";

export interface HardhatArtifactLite {
  deployedBytecode: string;
  immutableReferences?: Record<string, Array<{ start: number; length: number }>>;
}

export interface CompareResult {
  match: boolean;
  localHash: string;
  onChainHash: string;
  localLength: number;
  onChainLength: number;
  /** First ~256 bytes of divergence, hex, or `null` if equal. */
  firstDiffHex: string | null;
  /** Stats for the operator. */
  stripped: {
    metadataBytes: number;
    immutableBytes: number;
  };
}

export function compareBytecode(
  artifact: HardhatArtifactLite,
  onChainHex: string
): CompareResult {
  const local = hexToBytes(artifact.deployedBytecode);
  const onChain = hexToBytes(onChainHex);

  const immutableRefs = Object.values(artifact.immutableReferences ?? {}).flat();

  const localMetaLen = detectMetadataLength(local);
  const onChainMetaLen = detectMetadataLength(onChain);

  const localNorm = normalise(local, immutableRefs, localMetaLen);
  const onChainNorm = normalise(onChain, immutableRefs, onChainMetaLen);

  const localHash = keccak256(localNorm);
  const onChainHash = keccak256(onChainNorm);

  const match =
    localHash === onChainHash &&
    localNorm.length === onChainNorm.length;

  const firstDiffHex = match ? null : firstDiff(localNorm, onChainNorm);

  const immutableBytes = immutableRefs.reduce((s, r) => s + r.length, 0);

  return {
    match,
    localHash,
    onChainHash,
    localLength: local.length,
    onChainLength: onChain.length,
    firstDiffHex,
    stripped: {
      metadataBytes: Math.max(localMetaLen, onChainMetaLen),
      immutableBytes,
    },
  };
}

/**
 * Overwrite immutable regions and the metadata tail with `0x00` so the
 * comparison is independent of both.
 */
function normalise(
  code: Uint8Array,
  immutableRefs: ReadonlyArray<{ start: number; length: number }>,
  metadataLen: number
): Uint8Array {
  const out = code.slice();
  for (const ref of immutableRefs) {
    const end = Math.min(ref.start + ref.length, out.length);
    for (let i = ref.start; i < end; i++) out[i] = 0;
  }
  const stop = Math.max(0, out.length - metadataLen);
  for (let i = stop; i < out.length; i++) out[i] = 0;
  return out;
}

/**
 * The last two bytes of deployed Solidity bytecode encode the CBOR metadata
 * length (big-endian uint16). Returns `metadataLen + 2` or `0` if we can't
 * find a sane trailer (e.g. bytecode compiled without metadata).
 */
function detectMetadataLength(code: Uint8Array): number {
  if (code.length < 2) return 0;
  const n = code.length;
  const declaredLen = (code[n - 2]! << 8) | code[n - 1]!;
  const total = declaredLen + 2;
  if (declaredLen === 0 || total > code.length) return 0;
  // Sanity check: CBOR map prefix for known structures is 0xa1…0xa3.
  const cborStart = code[n - total];
  if (cborStart === undefined) return 0;
  if (cborStart < 0xa1 || cborStart > 0xa3) return 0;
  return total;
}

function hexToBytes(hex: string): Uint8Array {
  const clean = hex.startsWith("0x") ? hex.slice(2) : hex;
  if (clean.length % 2 !== 0) {
    throw new Error("hexToBytes: odd-length hex");
  }
  const out = new Uint8Array(clean.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

function firstDiff(a: Uint8Array, b: Uint8Array): string {
  const n = Math.min(a.length, b.length);
  let i = 0;
  while (i < n && a[i] === b[i]) i += 1;
  if (i === n && a.length === b.length) return "";

  const windowStart = Math.max(0, i - 8);
  const windowEnd = Math.min(Math.max(a.length, b.length), i + 256);
  const aSlice = a.slice(windowStart, Math.min(a.length, windowEnd));
  const bSlice = b.slice(windowStart, Math.min(b.length, windowEnd));
  return (
    `offset=0x${i.toString(16)}\n` +
    `  local  ${bytesToHex(aSlice)}\n` +
    `  onChain ${bytesToHex(bSlice)}`
  );
}
