/**
 * Pre-Setup Script for IGP121 Payload Simulation
 *
 * Simulates IGP120 then deploys:
 * 1. IGP120: set DexT1DeploymentLogic on DexFactory (must be called by factory owner)
 * 2. DEX 44 (REUSD-USDT)
 * 3. Vault 164: REUSD-USDT / USDT (TYPE_2) – supply token is DEX 44 address
 */

import { JsonRpcProvider, ethers } from "ethers";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";
const VAULT_FACTORY = "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d";
const DEX_FACTORY = "0x91716C4EDA1Fb55e84Bf8b4c7085f84285c19085";
// IGP120: T1 deployment logic set on DexFactory – used by DexFactory.deployDex(logic, data)
const DEX_T1_DEPLOYMENT_LOGIC = "0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819";

const REUSD_ADDRESS = "0x5086bf358635B81D8C47C66d1C8b9E567Db70c72";
const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const VAULT_LOGIC_T2 = "0xf92b954D3B2F6497B580D799Bf0907332AF1f63B";

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

async function sendVaultT2Deploy(
  provider: JsonRpcProvider,
  supplyToken: string,
  borrowToken: string,
): Promise<void> {
  const data = getDeployVaultT2Calldata(supplyToken, borrowToken);
  await provider.send("eth_sendTransaction", [
    {
      from: TEAM_MULTISIG,
      to: VAULT_FACTORY,
      data,
      value: "0x",
      gas: "0x9896800",
      gasPrice: "0x0",
    },
  ]);
}

/**
 * Deploy the next DEX (id 44 if 43 exist) via DexFactory using T1 deployment logic.
 * Pattern from fluidity-contracts: deployDex(dexDeploymentLogic_, dexDeploymentData_)
 * where dexDeploymentData_ is the encoded call to dexT1(token0_, token1_, oracleMapping_)
 * on the T1 logic (FluidDexT1DeploymentLogic). Logic address set in IGP120.
 */
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
      value: "0x",
      gas: "0x9896800",
      gasPrice: "0x0",
    },
  ]);
  console.log(
    "[SETUP] DEX 44 (REUSD-USDT) deploy tx sent via T1 deployment logic",
  );
}

/**
 * Simulate IGP120: set Dex T1 deployment logic on DexFactory.
 * Must be called by DexFactory owner (e.g. timelock or team multisig depending on fork).
 */
async function simulateIGP120(provider: JsonRpcProvider): Promise<void> {
  const iface = new ethers.Interface([
    "function setDexDeploymentLogic(address deploymentLogic_, bool allowed_) external",
  ]);
  const data = iface.encodeFunctionData("setDexDeploymentLogic", [
    DEX_T1_DEPLOYMENT_LOGIC,
    true,
  ]);
  await provider.send("eth_sendTransaction", [
    {
      from: TEAM_MULTISIG,
      to: DEX_FACTORY,
      data,
      value: "0x",
      gas: "0x9896800",
      gasPrice: "0x0",
    },
  ]);
  console.log(
    "[SETUP] IGP120 simulated: setDexDeploymentLogic(T1, true) on DexFactory",
  );
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
    "[SETUP] Running pre-setup for IGP121 (simulate IGP120 + DEX 44 + vault 164)...",
  );

  try {
    // 1. Simulate IGP120: set Dex T1 deployment logic on DexFactory
    await simulateIGP120(provider);

    // 2. Deploy DEX 44 (REUSD-USDT) so vault 164 can use it as supply token
    await deployDex44(provider);

    // 3. Vault 164: REUSD-USDT / USDT (TYPE_2) – supply token is DEX 44
    const dex44Address = await getDexAddress(provider, 44);
    if (
      !dex44Address ||
      dex44Address === "0x0000000000000000000000000000000000000000"
    ) {
      throw new Error(
        "DEX 44 address is zero. Deploy DEX 44 first or ensure fork has it.",
      );
    }
    await sendVaultT2Deploy(provider, dex44Address, USDT_ADDRESS);
    console.log("[SETUP] Deployed vault 164 (REUSD-USDT/USDT T2)");

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
