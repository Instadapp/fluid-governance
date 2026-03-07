/**
 * Pre-Setup Script for IGP123 Payload Simulation
 *
 * 1. Mock Chainlink feed 0x66ac... so latestRoundData() returns fixed values (for FluidGenericOracle._readChainlinkSource / OSETH oracle)
 * 2. Upgrade DEX V2 and Money Market proxies
 */

import { JsonRpcProvider } from "ethers";
import * as fs from "fs";
import * as path from "path";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";

/** Chainlink feed mocked so latestRoundData() returns (1, 106475560, 1771926611, 1771926611, 1) */
const CHAINLINK_FEED_TO_MOCK = "0x66ac817f997efd114edfcccdce99f3268557b32c";

async function mockChainlinkFeed(provider: JsonRpcProvider): Promise<void> {
  const artifactPath = path.join(
    process.cwd(),
    "artifacts",
    "contracts",
    "payloads",
    "IGP123",
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

export async function preSetup(provider: JsonRpcProvider): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP123...");

  try {
    await mockChainlinkFeed(provider); // OSETH oracle feed has a built-in max time validation

    // Upgrade DEX V2 proxy
    {
      await provider.send("eth_sendTransaction", [
        {
          from: TEAM_MULTISIG,
          to: "0x4E42f9e626FAcDdd97EDFA537AA52C5024448625",
          data: "0x3659cfe600000000000000000000000034a09c8f82612dbd3e969410ac9911e9d97751c0",
          value: "",
          gas: "0x9896800",
          gasPrice: "0x0",
        },
      ]);
    }

    // Upgrade Money Market proxy
    {
      await provider.send("eth_sendTransaction", [
        {
          from: TEAM_MULTISIG,
          to: "0xe3B7e3f4da603FC40fD889caBdEe30a4cf15DD34",
          data: "0x3659cfe6000000000000000000000000675c2e62e4b5d77a304805df2632da4157fc68b0",
          value: "",
          gas: "0x9896800",
          gasPrice: "0x0",
        },
      ]);
    }

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
