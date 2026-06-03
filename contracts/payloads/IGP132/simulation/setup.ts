/**
 * Pre-Setup Script for IGP132 Payload Simulation
 *
 * 1. Mock Chainlink feed 0x66ac... so latestRoundData() returns fixed values.
 * 2. Set liteStethRevenueAmount on the payload for Action 5.
 */

import { JsonRpcProvider, ethers } from "ethers";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";

/** Chainlink feed mocked so latestRoundData() returns (1, 106475560, 1771926611, 1771926611, 1) */
const CHAINLINK_FEED_TO_MOCK = "0x66ac817f997efd114edfcccdce99f3268557b32c";

/** Non-zero stETH wei for Action 5 (iETHv2 revenue claim). */
const SIM_LITE_STETH_REVENUE = 1n;

function normalizeHex(raw: string): string {
  return raw.startsWith("0x") ? raw : `0x${raw}`;
}

function readArtifactBytecode(relativeArtifactPath: string): string {
  const fs = require("fs");
  const path = require("path");
  const artifactPath = path.join(process.cwd(), relativeArtifactPath);
  if (!fs.existsSync(artifactPath)) {
    throw new Error(
      `Artifact not found at ${artifactPath}. Run 'npm run compile' first.`,
    );
  }

  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf-8"));
  const raw =
    artifact.deployedBytecode?.object ?? artifact.deployedBytecode ?? "";
  const bytecode =
    typeof raw === "string" && raw.length > 0 ? normalizeHex(raw) : "";
  if (!bytecode) {
    throw new Error(`${artifactPath} has no deployedBytecode.object`);
  }
  return bytecode;
}

async function mockChainlinkFeed(provider: JsonRpcProvider): Promise<void> {
  const bytecode = readArtifactBytecode(
    "artifacts/contracts/payloads/IGP132/simulation/MockChainlinkFeed.sol/MockChainlinkFeed.json",
  );
  await provider.send("tenderly_setCode", [CHAINLINK_FEED_TO_MOCK, bytecode]);
  console.log("[SETUP] Mocked Chainlink feed for OSETH oracle path");
}

async function setLiteStethRevenueAmount(
  provider: JsonRpcProvider,
  payloadAddress: string,
): Promise<void> {
  const iface = new ethers.Interface([
    "function setLiteStethRevenueAmount(uint256) external",
  ]);
  const data = iface.encodeFunctionData("setLiteStethRevenueAmount", [
    SIM_LITE_STETH_REVENUE,
  ]);

  const txHash = await provider.send("eth_sendTransaction", [
    {
      from: TEAM_MULTISIG,
      to: payloadAddress,
      data,
      value: "0x0",
      gas: "0x989680",
      gasPrice: "0x0",
    },
  ]);
  const receipt = await provider.waitForTransaction(txHash);
  if (!receipt || receipt.status !== 1) {
    throw new Error("setLiteStethRevenueAmount transaction failed");
  }
  console.log("[SETUP] setLiteStethRevenueAmount set successfully");
}

export async function preSetup(
  provider: JsonRpcProvider,
  payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP132...");

  try {
    await mockChainlinkFeed(provider);

    if (payloadAddress) {
      await setLiteStethRevenueAmount(provider, payloadAddress);
    } else {
      console.warn(
        "[SETUP] No payload address provided, skipping lite revenue setup",
      );
    }

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
