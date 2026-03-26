/**
 * Pre-Setup Script for IGP127 Payload Simulation
 *
 * 1. Mock Chainlink feed 0x66ac... so latestRoundData() returns fixed values (for FluidGenericOracle._readChainlinkSource / OSETH oracle)
 * 2. Set configurable addresses on the payload (pauseableAuth)
 * 3. Deploy Vault 165: reUSD-USDT / USDC-USDT (T4)
 */

import { JsonRpcProvider, ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";
const VAULT_FACTORY = "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d";
const DEX_FACTORY = "0x91716C4EDA1Fb55e84Bf8b4c7085f84285c19085";
const VAULT_LOGIC_T4 = "0xC292c87F3116CBbfb2186d4594Dc48d55fCa6e34";

/** Chainlink feed mocked so latestRoundData() returns (1, 106475560, 1771926611, 1771926611, 1) */
const CHAINLINK_FEED_TO_MOCK = "0x66ac817f997efd114edfcccdce99f3268557b32c";

/** Dummy address for simulation (non-zero so require checks pass) */
const DUMMY_PAUSEABLE_AUTH = "0x0000000000000000000000000000000000000005";

async function mockChainlinkFeed(provider: JsonRpcProvider): Promise<void> {
  const artifactPath = path.join(
    process.cwd(),
    "artifacts",
    "contracts",
    "payloads",
    "IGP127",
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
    "function setPauseableAuth(address) external",
  ]);

  const calls: { name: string; data: string }[] = [
    {
      name: "setPauseableAuth",
      data: iface.encodeFunctionData("setPauseableAuth", [
        DUMMY_PAUSEABLE_AUTH,
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

async function getDexAddress(
  provider: JsonRpcProvider,
  dexId: number,
): Promise<string> {
  const iface = new ethers.Interface([
    "function getDexAddress(uint256 dexId_) view returns (address)",
  ]);
  const data = iface.encodeFunctionData("getDexAddress", [dexId]);
  const result = await provider.send("eth_call", [
    { to: DEX_FACTORY, data },
    "latest",
  ]);
  return ethers.AbiCoder.defaultAbiCoder().decode(["address"], result)[0];
}

function getDeployVaultT4Calldata(
  smartCol: string,
  smartDebt: string,
): string {
  const ABI = [
    "function vaultT4(address smartCol_, address smartDebt_) external",
  ];
  const DEPLOYERABI = [
    "function deployVault(address vaultDeploymentLogic_, bytes calldata vaultDeploymentData_) external",
  ];
  const logicData = new ethers.Interface(ABI).encodeFunctionData("vaultT4", [
    smartCol,
    smartDebt,
  ]);
  return new ethers.Interface(DEPLOYERABI).encodeFunctionData("deployVault", [
    VAULT_LOGIC_T4,
    logicData,
  ]);
}

async function deployVault165(provider: JsonRpcProvider): Promise<void> {
  const dex44Address = await getDexAddress(provider, 44); // reUSD-USDT
  const dex2Address = await getDexAddress(provider, 2); // USDC-USDT

  if (
    !dex44Address ||
    dex44Address === "0x0000000000000000000000000000000000000000"
  ) {
    throw new Error("DEX 44 (reUSD-USDT) address is zero.");
  }
  if (
    !dex2Address ||
    dex2Address === "0x0000000000000000000000000000000000000000"
  ) {
    throw new Error("DEX 2 (USDC-USDT) address is zero.");
  }

  const vaultData = getDeployVaultT4Calldata(dex44Address, dex2Address);
  const txHash = await provider.send("eth_sendTransaction", [
    {
      from: TEAM_MULTISIG,
      to: VAULT_FACTORY,
      data: vaultData,
      value: "0x0",
      gas: "0x9896800",
      gasPrice: "0x0",
    },
  ]);
  const receipt = await provider.waitForTransaction(txHash);
  if (!receipt || receipt.status !== 1) {
    throw new Error("Vault 165 (T4 reUSD-USDT / USDC-USDT) deployment failed");
  }
  console.log("[SETUP] Vault 165 (T4 reUSD-USDT / USDC-USDT) deployed");
}

export async function preSetup(
  provider: JsonRpcProvider,
  payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP127...");

  try {
    await mockChainlinkFeed(provider);

    await deployVault165(provider);

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
