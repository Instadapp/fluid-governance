#!/usr/bin/env ts-node
/**
 * Post-deploy: confirm the on-chain payload at `--address` matches the
 * locally compiled `deployedBytecode` for `--payload`.
 *
 *   npm run verify:deployment -- \
 *     --payload IGP129 --address 0xabc... --rpc $ETH_RPC
 *
 * Reads the Hardhat artifact at:
 *   artifacts/contracts/payloads/<IGP>/Payload<IGP>.sol/Payload<IGP>.json
 * and compares against `eth_getCode` after normalising the CBOR metadata
 * tail and every `immutableReferences` region.
 *
 * Exit codes:
 *   0   Bytecode matches.
 *   1   Bytecode mismatch / argument or I/O error.
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { createPublicClient, http, type Address } from "viem";

import {
  compareBytecode,
  type HardhatArtifactLite,
} from "./lib/bytecode.js";

interface CliArgs {
  payload: string;
  address: Address;
  rpc: string;
}

function parseArgs(argv: readonly string[]): CliArgs {
  let payload = "";
  let address = "";
  let rpc = process.env.ETH_RPC ?? process.env.RPC_URL ?? "";
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (a === "--payload" || a === "-p") payload = argv[++i] ?? "";
    else if (a === "--address" || a === "-a") address = argv[++i] ?? "";
    else if (a === "--rpc") rpc = argv[++i] ?? "";
    else if (a === "--help" || a === "-h") {
      printHelp();
      process.exit(0);
    } else {
      fail(1, `Unknown argument \`${a}\`. Run with --help for usage.`);
    }
  }

  if (!payload) fail(1, "Missing --payload. Example: --payload IGP129");
  if (!address) fail(1, "Missing --address.");
  if (!rpc) fail(1, "Missing --rpc (or set ETH_RPC / RPC_URL).");

  if (/^\d+$/.test(payload)) payload = `IGP${payload}`;
  if (payload.startsWith("Payload")) payload = payload.slice("Payload".length);
  if (!payload.startsWith("IGP")) {
    fail(1, `--payload must look like IGP129 (got: \`${payload}\`)`);
  }

  if (!/^0x[a-fA-F0-9]{40}$/.test(address)) {
    fail(1, `--address must be a 20-byte hex string (got: \`${address}\`)`);
  }

  return { payload, address: address as Address, rpc };
}

function printHelp(): void {
  process.stdout.write(
    [
      "verify-deployment.ts — compare on-chain bytecode to the local artifact.",
      "",
      "Usage:",
      "  npm run verify:deployment -- \\",
      "    --payload IGP129 --address 0xabc... --rpc $ETH_RPC",
      "",
      "Options:",
      "  --payload, -p   IGP number or name (e.g. IGP129 or 129).",
      "  --address, -a   Deployed contract address.",
      "  --rpc           RPC URL. Defaults to $ETH_RPC, then $RPC_URL.",
      "  --help, -h      Show this help.",
      "",
    ].join("\n")
  );
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const repoRoot = findRepoRoot();

  const artifactPath = join(
    repoRoot,
    "artifacts",
    "contracts",
    "payloads",
    args.payload,
    `Payload${args.payload}.sol`,
    `Payload${args.payload}.json`
  );
  if (!existsSync(artifactPath)) {
    fail(
      1,
      `Artifact not found at ${artifactPath}.\n` +
        `Did you run \`npm run compile\` first?`
    );
  }

  const artifact = JSON.parse(
    readFileSync(artifactPath, "utf8")
  ) as HardhatArtifactLite;

  if (!artifact.deployedBytecode) {
    fail(1, `Artifact has no deployedBytecode: ${artifactPath}`);
  }

  const client = createPublicClient({ transport: http(args.rpc) });
  let onChain: string;
  try {
    onChain = (await client.getCode({ address: args.address })) ?? "0x";
  } catch (err) {
    fail(1, `eth_getCode failed: ${(err as Error).message}`);
  }

  if (!onChain || onChain === "0x") {
    fail(
      1,
      `No bytecode at ${args.address} on the provided RPC. ` +
        `Is the address correct and the RPC on the right chain?`
    );
  }

  const result = compareBytecode(artifact, onChain);

  process.stdout.write(
    [
      `payload:      ${args.payload}`,
      `address:      ${args.address}`,
      `local bytes:  ${result.localLength}`,
      `on-chain:     ${result.onChainLength}`,
      `stripped:     metadata=${result.stripped.metadataBytes}B ` +
        `immutables=${result.stripped.immutableBytes}B`,
      `local hash:   ${result.localHash}`,
      `on-chain hash: ${result.onChainHash}`,
      "",
      result.match ? "PASS" : "FAIL",
      "",
    ].join("\n")
  );

  if (!result.match) {
    if (result.firstDiffHex) {
      process.stderr.write(
        "First divergence:\n" + result.firstDiffHex + "\n"
      );
    }
    process.exit(1);
  }
}

function findRepoRoot(): string {
  const here = dirname(fileURLToPath(import.meta.url));
  return resolve(here, "..", "..");
}

function fail(code: number, msg: string): never {
  process.stderr.write(msg.endsWith("\n") ? msg : msg + "\n");
  process.exit(code);
}

main().catch((err) => {
  process.stderr.write(
    `verify-deployment: unexpected error: ${(err as Error).stack ?? err}\n`
  );
  process.exit(1);
});
