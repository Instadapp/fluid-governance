/**
 * Pre-Setup Script for IGP126 Payload Simulation
 *
 * 1. Mock Chainlink feed 0x66ac... so latestRoundData() returns fixed values (for FluidGenericOracle._readChainlinkSource / OSETH oracle)
 * 2. Set configurable addresses on the payload (userModuleAddress, dummyImplementationAddress, onBehalfOfAuth, vaultFactoryOwner, pauseableAuth, pausableDexAuth)
 */

import { JsonRpcProvider, ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";

/** Chainlink feed mocked so latestRoundData() returns (1, 106475560, 1771926611, 1771926611, 1) */
const CHAINLINK_FEED_TO_MOCK = "0x66ac817f997efd114edfcccdce99f3268557b32c";

/** Dummy addresses for simulation (non-zero so require checks pass) */
const DUMMY_USER_MODULE = "0x0000000000000000000000000000000000000001";
const DUMMY_DUMMY_IMPLEMENTATION =
  "0x0000000000000000000000000000000000000004";
const DUMMY_ON_BEHALF_OF_AUTH = "0x0000000000000000000000000000000000000002";
const DUMMY_VAULT_FACTORY_OWNER = "0x0000000000000000000000000000000000000003";
const DUMMY_PAUSEABLE_AUTH = "0x0000000000000000000000000000000000000005";
const DUMMY_PAUSABLE_DEX_AUTH = "0x0000000000000000000000000000000000000006";

async function mockChainlinkFeed(provider: JsonRpcProvider): Promise<void> {
  const artifactPath = path.join(
    process.cwd(),
    "artifacts",
    "contracts",
    "payloads",
    "IGP126",
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
    "function setUserModuleAddress(address) external",
    "function setDummyImplementationAddress(address) external",
    "function setOnBehalfOfAuth(address) external",
    "function setVaultFactoryOwner(address) external",
    "function setPauseableAuth(address) external",
    "function setPausableDexAuth(address) external",
  ]);

  const calls: { name: string; data: string }[] = [
    {
      name: "setUserModuleAddress",
      data: iface.encodeFunctionData("setUserModuleAddress", [
        DUMMY_USER_MODULE,
      ]),
    },
    {
      name: "setDummyImplementationAddress",
      data: iface.encodeFunctionData("setDummyImplementationAddress", [
        DUMMY_DUMMY_IMPLEMENTATION,
      ]),
    },
    {
      name: "setOnBehalfOfAuth",
      data: iface.encodeFunctionData("setOnBehalfOfAuth", [
        DUMMY_ON_BEHALF_OF_AUTH,
      ]),
    },
    {
      name: "setVaultFactoryOwner",
      data: iface.encodeFunctionData("setVaultFactoryOwner", [
        DUMMY_VAULT_FACTORY_OWNER,
      ]),
    },
    {
      name: "setPauseableAuth",
      data: iface.encodeFunctionData("setPauseableAuth", [
        DUMMY_PAUSEABLE_AUTH,
      ]),
    },
    {
      name: "setPausableDexAuth",
      data: iface.encodeFunctionData("setPausableDexAuth", [
        DUMMY_PAUSABLE_DEX_AUTH,
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
  console.log("[SETUP] Running pre-setup for IGP126...");

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
