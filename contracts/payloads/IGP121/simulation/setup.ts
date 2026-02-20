/**
 * Pre-Setup Script for IGP121 Payload Simulation
 *
 * Deploys all REUSD protocols in the correct order:
 * 1. DEX 44 (REUSD-USDT)
 * 2. Vault 160: REUSD / USDC (TYPE_1)
 * 3. Vault 161: REUSD / USDT (TYPE_1)
 * 4. Vault 162: REUSD / GHO (TYPE_1)
 * 5. Vault 163: REUSD / USDC-USDT (TYPE_3)
 * 6. Vault 164: REUSD-USDT / USDT (TYPE_2) – supply token is DEX 44 address
 */

import { JsonRpcProvider, ethers } from "ethers";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";
const VAULT_FACTORY = "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d";
const DEX_FACTORY = "0x91716C4EDA1Fb55e84Bf8b4c7085f84285c19085";
// T1 deployment logic set in IGP120 – used by DexFactory.deployDex(logic, data)
const DEX_T1_DEPLOYMENT_LOGIC = "0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819";

const REUSD_ADDRESS = "0x5086bf358635B81D8C47C66d1C8b9E567Db70c72";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const GHO_ADDRESS = "0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f";
const VAULT_LOGIC = {
  T1: "0xf4b87b0a2315534a8233724b87f2a8e3197ad649",
  T2: "0xf92b954D3B2F6497B580D799Bf0907332AF1f63B",
  T3: "0xbc9c8528c66D1910CFb6Bde2a8f1C2F1D38026c7",
};

function getDeployVaultCalldata(
  vaultType: "T1" | "T2" | "T3",
  logic: string,
  supplyToken: string,
  borrowToken: string,
): string {
  const ABI =
    vaultType === "T3"
      ? ["function vaultT3(address smartCol_, address borrowToken_) external"]
      : [
          `function vault${vaultType}(address smartCol_, address borrowToken_) external`,
        ];
  const DEPLOYERABI = [
    "function deployVault(address vaultDeploymentLogic_, bytes calldata vaultDeploymentData_) external",
  ];
  const fn = vaultType === "T3" ? "vaultT3" : `vault${vaultType}`;
  const logicData = new ethers.Interface(ABI).encodeFunctionData(fn, [
    supplyToken,
    borrowToken,
  ]);
  return new ethers.Interface(DEPLOYERABI).encodeFunctionData("deployVault", [
    logic,
    logicData,
  ]);
}

async function sendVaultDeploy(
  provider: JsonRpcProvider,
  vaultType: "T1" | "T2" | "T3",
  supplyToken: string,
  borrowToken: string,
): Promise<void> {
  const logic = VAULT_LOGIC[vaultType];
  const data = getDeployVaultCalldata(
    vaultType,
    logic,
    supplyToken,
    borrowToken,
  );
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
  // T1 logic: dexT1(token0_, token1_, oracleMapping_); requires token0 < token1 (address order)
  const [token0, token1] = [REUSD_ADDRESS, USDT_ADDRESS].sort((a, b) =>
    (BigInt(a) < BigInt(b) ? -1 : 1),
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
  console.log("[SETUP] DEX 44 (REUSD-USDT) deploy tx sent via T1 deployment logic");
}

/**
 * Get the deterministic DEX address from the factory (view call).
 */
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
  console.log("[SETUP] Running pre-setup for IGP121 (REUSD protocols)...");

  try {
    // 1. Deploy DEX 44 (REUSD-USDT) first so vault 164 can use it as supply token
    await deployDex44(provider);

    // 2. Vault 160: REUSD / USDC (TYPE_1)
    await sendVaultDeploy(provider, "T1", REUSD_ADDRESS, USDC_ADDRESS);
    console.log("[SETUP] Deployed vault 160 (REUSD/USDC T1)");

    // 3. Vault 161: REUSD / USDT (TYPE_1)
    await sendVaultDeploy(provider, "T1", REUSD_ADDRESS, USDT_ADDRESS);
    console.log("[SETUP] Deployed vault 161 (REUSD/USDT T1)");

    // 4. Vault 162: REUSD / GHO (TYPE_1)
    await sendVaultDeploy(provider, "T1", REUSD_ADDRESS, GHO_ADDRESS);
    console.log("[SETUP] Deployed vault 162 (REUSD/GHO T1)");

    // 5. Vault 163: REUSD / USDC-USDT (TYPE_3) – borrow at USDC-USDT DEX (id 2)
    const usdcUsdtDex = await getDexAddress(provider, 2);
    await sendVaultDeploy(provider, "T3", REUSD_ADDRESS, usdcUsdtDex);
    console.log("[SETUP] Deployed vault 163 (REUSD/USDC-USDT T3)");

    // 6. Vault 164: REUSD-USDT / USDT (TYPE_2) – supply token is DEX 44
    const dex44Address = await getDexAddress(provider, 44);
    if (
      !dex44Address ||
      dex44Address === "0x0000000000000000000000000000000000000000"
    ) {
      throw new Error(
        "DEX 44 address is zero. Deploy DEX 44 first or ensure fork has it.",
      );
    }
    await sendVaultDeploy(provider, "T2", dex44Address, USDT_ADDRESS);
    console.log("[SETUP] Deployed vault 164 (REUSD-USDT/USDT T2)");

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
