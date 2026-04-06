/**
 * Pre-Setup Script for IGP128 Payload Simulation
 *
 * 1. Mock Chainlink feed 0x66ac... so latestRoundData() returns fixed values (for FluidGenericOracle._readChainlinkSource / OSETH oracle)
 * 2. Set configurable addresses on the payload (liquidityAdminModule)
 */

import { JsonRpcProvider, ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";

/** Chainlink feed mocked so latestRoundData() returns (1, 106475560, 1771926611, 1771926611, 1) */
const CHAINLINK_FEED_TO_MOCK = "0x66ac817f997efd114edfcccdce99f3268557b32c";

/** Dummy address for simulation (non-zero so require checks pass) */
const DUMMY_LIQUIDITY_ADMIN_MODULE =
  "0x0000000000000000000000000000000000000006";

async function mockChainlinkFeed(provider: JsonRpcProvider): Promise<void> {
  const artifactPath = path.join(
    process.cwd(),
    "artifacts",
    "contracts",
    "payloads",
    "IGP128",
    "simulation",
    "MockChainlinkFeed.sol",
    "MockChainlinkFeed.json",
  );
  if (!fs.existsSync(artifactPath)) {
    throw new Error(
      `MockChainlinkFeed artifact not found at ${artifactPath}. Run 'npm run compile' first.`,
    );
  }
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf-8"));
  const raw =
    artifact.deployedBytecode?.object ?? artifact.deployedBytecode ?? "";
  const bytecode =
    typeof raw === "string" && raw.length > 0
      ? raw.startsWith("0x")
        ? raw
        : "0x" + raw
      : "";
  if (!bytecode) {
    throw new Error(
      "MockChainlinkFeed artifact has no deployedBytecode.object",
    );
  }
  await provider.send("tenderly_setCode", [CHAINLINK_FEED_TO_MOCK, bytecode]);
}

async function setConfigurableAddresses(
  provider: JsonRpcProvider,
  payloadAddress: string,
): Promise<void> {
  const iface = new ethers.Interface([
    "function setLiquidityAdminModule(address) external",
  ]);

  const calls: { name: string; data: string }[] = [
    {
      name: "setLiquidityAdminModule",
      data: iface.encodeFunctionData("setLiquidityAdminModule", [
        DUMMY_LIQUIDITY_ADMIN_MODULE,
      ]),
    },
  ];

  for (const call of calls) {
    const txHash = await provider.send("eth_sendTransaction", [
      {
        from: TEAM_MULTISIG,
        to: payloadAddress,
        data: call.data,
        value: "0x0",
        gas: "0x989680",
        gasPrice: "0x0",
      },
    ]);
    const receipt = await provider.waitForTransaction(txHash);
    if (!receipt || receipt.status !== 1) {
      throw new Error(`${call.name} transaction failed`);
    }
    console.log(`[SETUP] ${call.name} set successfully`);
  }
}

export async function preSetup(
  provider: JsonRpcProvider,
  payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP128...");

  try {
    await mockChainlinkFeed(provider);

    if (payloadAddress) {
      await setConfigurableAddresses(provider, payloadAddress);
    } else {
      console.warn(
        "[SETUP] No payload address provided, skipping configurable address setup",
      );
    }

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
