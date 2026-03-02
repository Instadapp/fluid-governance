/**
 * Pre-Setup Script for IGP122 Payload Simulation
 *
 * 1. Mock Chainlink feed 0x66ac... so latestRoundData() returns fixed values (for FluidGenericOracle._readChainlinkSource)
 * 2. IGP120: set DexT1DeploymentLogic on DexFactory (from Timelock)
 * 3. DEX 44 (REUSD-USDT)
 * 4. Vault 164: REUSD-USDT / USDT (TYPE_2) – supply token is DEX 44 address
 */

import { JsonRpcProvider, ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";
const VAULT_FACTORY = "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d";
const DEX_FACTORY = "0x91716C4EDA1Fb55e84Bf8b4c7085f84285c19085";
const DEX_FACTORY_OWNER_TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const DEX_T1_DEPLOYMENT_LOGIC = "0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819";

const REUSD_ADDRESS = "0x5086bf358635B81D8C47C66d1C8b9E567Db70c72";
const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const VAULT_LOGIC_T2 = "0xf92b954D3B2F6497B580D799Bf0907332AF1f63B";

/** Chainlink feed mocked so latestRoundData() returns (1, 106475560, 1771926611, 1771926611, 1) */
const CHAINLINK_FEED_TO_MOCK = "0x66ac817f997efd114edfcccdce99f3268557b32c";

function getDeployVaultT2Calldata(
  supplyToken: string,
  borrowToken: string,
): string {
  const ABI = [
    "function vaultT2(address smartCol_, address borrowToken_) external",
  ];
  const DEPLOYERABI = [
    "function deployVault(address vaultDeploymentLogic_, bytes calldata vaultDeploymentData_) external",
  ];
  const logicData = new ethers.Interface(ABI).encodeFunctionData("vaultT2", [
    supplyToken,
    borrowToken,
  ]);
  return new ethers.Interface(DEPLOYERABI).encodeFunctionData("deployVault", [
    VAULT_LOGIC_T2,
    logicData,
  ]);
}

async function mockChainlinkFeed(provider: JsonRpcProvider): Promise<void> {
  const artifactPath = path.join(
    process.cwd(),
    "artifacts",
    "contracts",
    "payloads",
    "IGP122",
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

async function impersonateAndRunIGP120(
  provider: JsonRpcProvider,
): Promise<void> {
  const iface = new ethers.Interface([
    "function setDexDeploymentLogic(address deploymentLogic_, bool allowed_) external",
  ]);
  const data = iface.encodeFunctionData("setDexDeploymentLogic", [
    DEX_T1_DEPLOYMENT_LOGIC,
    true,
  ]);
  await provider.send("eth_sendTransaction", [
    {
      from: DEX_FACTORY_OWNER_TIMELOCK,
      to: DEX_FACTORY,
      data,
      value: "0x0",
      gas: "0x9896800",
      gasPrice: "0x0",
    },
  ]);
}

async function deployDex44(provider: JsonRpcProvider): Promise<void> {
  const DEX_FACTORY_ABI = [
    "function deployDex(address dexDeploymentLogic_, bytes calldata dexDeploymentData_) external returns (address)",
  ];
  const [token0, token1] = [REUSD_ADDRESS, USDT_ADDRESS].sort((a, b) =>
    BigInt(a) < BigInt(b) ? -1 : 1,
  );
  const oracleMapping = 0;
  const dexDeploymentData = new ethers.Interface([
    "function dexT1(address token0_, address token1_, uint256 oracleMapping_) external returns (bytes memory)",
  ]).encodeFunctionData("dexT1", [token0, token1, oracleMapping]);
  const calldata = new ethers.Interface(DEX_FACTORY_ABI).encodeFunctionData(
    "deployDex",
    [DEX_T1_DEPLOYMENT_LOGIC, dexDeploymentData],
  );
  await provider.send("eth_sendTransaction", [
    {
      from: TEAM_MULTISIG,
      to: DEX_FACTORY,
      data: calldata,
      value: "0x0",
      gas: "0x9896800",
      gasPrice: "0x0",
    },
  ]);
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

export async function preSetup(provider: JsonRpcProvider): Promise<void> {
  console.log(
    "[SETUP] Running pre-setup for IGP122 (IGP120 + DEX 44 + vault 164)...",
  );

  try {
    await mockChainlinkFeed(provider); // OSETH oracle feed has a built in max time validation

    await impersonateAndRunIGP120(provider);

    await deployDex44(provider);

    const dex44Address = await getDexAddress(provider, 44);
    if (
      !dex44Address ||
      dex44Address === "0x0000000000000000000000000000000000000000"
    ) {
      throw new Error(
        "DEX 44 address is zero. Deploy DEX 44 first or ensure fork has 43 dexes.",
      );
    }
    const vaultData = getDeployVaultT2Calldata(dex44Address, USDT_ADDRESS);
    await provider.send("eth_sendTransaction", [
      {
        from: TEAM_MULTISIG,
        to: VAULT_FACTORY,
        data: vaultData,
        value: "0x0",
        gas: "0x9896800",
        gasPrice: "0x0",
      },
    ]);

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
