#!/usr/bin/env ts-node
/**
 * Post-deploy: confirm the on-chain payload at `--address` matches the
 * locally compiled `deployedBytecode` for `--payload`.
 *
 *   npm run verify:deployment -- \
 *     --payload IGP129 --address 0xabc... --rpc $ETH_RPC
 *
 * Artifact resolution order (first match wins; logged on stdout):
 *   1. `--deployment-artifact <path>` (explicit).
 *   2. `ignition/deployments/chain-1/artifacts/PayloadModule#Payload<IGP>.json`
 *      — the deploy-time Ignition snapshot, committed to git when a payload
 *      is deployed. Recommended: it freezes the bytecode from the exact
 *      source tree at deploy time and is immune to post-deploy refactors
 *      of shared base contracts (which legitimately change the Hardhat
 *      artifact for every inheriting payload).
 *   3. `artifacts/contracts/payloads/<IGP>/Payload<IGP>.sol/Payload<IGP>.json`
 *      — the Hardhat artifact from the most recent `npm run compile`.
 *      Pass `--hh-artifact` to force this source even when (2) exists.
 *
 * In every case the script normalises the CBOR metadata tail and every
 * `immutableReferences` region on both sides before hashing.
 *
 * Exit codes:
 *   0   Bytecode matches.
 *   1   Bytecode mismatch / argument or I/O error.
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve, join, dirname, relative, isAbsolute } from "node:path";
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
  deploymentArtifact: string | null;
  forceHhArtifact: boolean;
}

type ArtifactSource =
  | { kind: "explicit"; path: string }
  | { kind: "ignition"; path: string }
  | { kind: "hardhat"; path: string };

function parseArgs(argv: readonly string[]): CliArgs {
  let payload = "";
  let address = "";
  let rpc = process.env.ETH_RPC ?? process.env.RPC_URL ?? "";
  let deploymentArtifact: string | null = null;
  let forceHhArtifact = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (a === "--payload" || a === "-p") payload = argv[++i] ?? "";
    else if (a === "--address" || a === "-a") address = argv[++i] ?? "";
    else if (a === "--rpc") rpc = argv[++i] ?? "";
    else if (a === "--deployment-artifact" || a === "-d") {
      deploymentArtifact = argv[++i] ?? "";
    } else if (a === "--hh-artifact") {
      forceHhArtifact = true;
    } else if (a === "--help" || a === "-h") {
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

  if (deploymentArtifact !== null && forceHhArtifact) {
    fail(
      1,
      "--deployment-artifact and --hh-artifact are mutually exclusive."
    );
  }

  return {
    payload,
    address: address as Address,
    rpc,
    deploymentArtifact,
    forceHhArtifact,
  };
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
      "  --payload, -p               IGP number or name (e.g. IGP129 or 129).",
      "  --address, -a               Deployed contract address.",
      "  --rpc                       RPC URL. Defaults to $ETH_RPC, then $RPC_URL.",
      "  --deployment-artifact, -d   Explicit artifact path (JSON with",
      "                              `deployedBytecode`). Overrides auto-detect.",
      "  --hh-artifact               Force the fresh Hardhat artifact even when",
      "                              an Ignition deployment snapshot exists.",
      "  --help, -h                  Show this help.",
      "",
      "Artifact resolution (first match wins, unless flags force it):",
      "  1. --deployment-artifact <path>",
      "  2. ignition/deployments/chain-1/artifacts/",
      "       PayloadModule#Payload<IGP>.json   (recommended, deploy-frozen)",
      "  3. artifacts/contracts/payloads/<IGP>/",
      "       Payload<IGP>.sol/Payload<IGP>.json (fresh Hardhat compile)",
      "",
    ].join("\n")
  );
}

function resolveArtifact(args: CliArgs, repoRoot: string): ArtifactSource {
  if (args.deploymentArtifact !== null) {
    const raw = args.deploymentArtifact;
    if (!raw) fail(1, "--deployment-artifact requires a non-empty path.");
    const abs = isAbsolute(raw) ? raw : resolve(process.cwd(), raw);
    if (!existsSync(abs)) {
      fail(1, `--deployment-artifact not found: ${abs}`);
    }
    return { kind: "explicit", path: abs };
  }

  const ignitionPath = join(
    repoRoot,
    "ignition",
    "deployments",
    "chain-1",
    "artifacts",
    `PayloadModule#Payload${args.payload}.json`
  );
  const hhPath = join(
    repoRoot,
    "artifacts",
    "contracts",
    "payloads",
    args.payload,
    `Payload${args.payload}.sol`,
    `Payload${args.payload}.json`
  );

  if (!args.forceHhArtifact && existsSync(ignitionPath)) {
    return { kind: "ignition", path: ignitionPath };
  }

  if (!existsSync(hhPath)) {
    const hint = args.forceHhArtifact
      ? "Did you run `npm run compile` first?"
      : existsSync(ignitionPath)
        ? "(Ignition snapshot exists but --hh-artifact was passed.)"
        : "Did you run `npm run compile` first, or ship an Ignition deployment snapshot?";
    fail(1, `Artifact not found at ${hhPath}.\n${hint}`);
  }
  return { kind: "hardhat", path: hhPath };
}

function describeSource(src: ArtifactSource, repoRoot: string): string {
  const rel = relative(repoRoot, src.path) || src.path;
  switch (src.kind) {
    case "explicit":
      return `explicit      ${rel}`;
    case "ignition":
      return `ignition      ${rel}  (deploy-time snapshot; recommended)`;
    case "hardhat":
      return `hardhat       ${rel}  (fresh compile; may drift after base-contract refactors)`;
  }
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const repoRoot = findRepoRoot();

  const source = resolveArtifact(args, repoRoot);

  let artifact: HardhatArtifactLite;
  try {
    artifact = JSON.parse(
      readFileSync(source.path, "utf8")
    ) as HardhatArtifactLite;
  } catch (err) {
    fail(1, `Failed to read artifact ${source.path}: ${(err as Error).message}`);
  }

  if (!artifact.deployedBytecode) {
    fail(1, `Artifact has no deployedBytecode: ${source.path}`);
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
      `payload:       ${args.payload}`,
      `address:       ${args.address}`,
      `artifact:      ${describeSource(source, repoRoot)}`,
      `local bytes:   ${result.localLength}`,
      `on-chain:      ${result.onChainLength}`,
      `stripped:      metadata=${result.stripped.metadataBytes}B ` +
        `immutables=${result.stripped.immutableBytes}B`,
      `local hash:    ${result.localHash}`,
      `on-chain hash: ${result.onChainHash}`,
      "",
      result.match ? "✅ PASS" : "❌ FAIL",
      "",
    ].join("\n")
  );

  if (!result.match) {
    if (result.firstDiffHex) {
      process.stderr.write(
        "First divergence:\n" + result.firstDiffHex + "\n"
      );
    }
    if (source.kind === "hardhat") {
      const ignitionPath = join(
        repoRoot,
        "ignition",
        "deployments",
        "chain-1",
        "artifacts",
        `PayloadModule#Payload${args.payload}.json`
      );
      if (existsSync(ignitionPath)) {
        process.stderr.write(
          "\nNote: you forced --hh-artifact. An Ignition deploy-time " +
            "snapshot exists at\n  " +
            relative(repoRoot, ignitionPath) +
            "\nand would normally be compared first. Shared base contracts " +
            "may have been\nrefactored after deploy; re-run without " +
            "--hh-artifact to verify against\nthe frozen deploy-time bytecode.\n"
        );
      }
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
