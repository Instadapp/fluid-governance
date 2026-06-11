/**
 * Pre-Setup Script for IGP134 Payload Simulation
 *
 * Three responsibilities, run before the propose/queue/execute flow:
 *
 * 1. Deploy vault 180 (T2 USDai-USDC / USDC) if not yet live on the fork.
 *    Vaults 171-179 are already deployed on mainnet; only vault 180 is deployed
 *    here (collateral at DEX 47, USDC debt) before IGP-134 can set its
 *    borrow-side dust limits and deprecate vault 174.
 *
 * 2. Align the governor proposal id to 134.
 *
 * 3. Fund the Fluid Reserve with stETH so Action 4 can withdraw 148 stETH to
 *    Team Multisig (the payload no longer claims via collectRevenue).
 */

import { JsonRpcProvider, ethers } from "ethers";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";
const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";
const VAULT_FACTORY = "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d";
const DEX_FACTORY = "0x91716C4EDA1Fb55e84Bf8b4c7085f84285c19085";
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const VAULT_LOGIC_T2 = "0xf92b954D3B2F6497B580D799Bf0907332AF1f63B";
const USDAI_USDC_DEX_ID = 47;
const VAULT_180_ID = 180;

const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

const IGP134_PROPOSAL_ID = 134;
const TARGET_PROPOSAL_COUNT = IGP134_PROPOSAL_ID - 1; // 133

// Action 4 sends 148 stETH from the Fluid Reserve. Since the payload no longer
// claims via collectRevenue, the sim pre-funds the Reserve with stETH (with
// margin over 148 to cover stETH's 1-2 wei transfer rounding).
const STETH_ADDRESS = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84";
const FLUID_RESERVE = "0x264786EF916af64a1DB19F513F24a3681734ce92";
// wstETH holds essentially the entire wrapped stETH supply - used as a fork faucet.
const STETH_WHALE = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";
const SIM_RESERVE_STETH_FUNDING = 200n * 10n ** 18n; // 200 stETH

function getDeployVaultT2Calldata(
  supplyDex: string,
  borrowToken: string,
): string {
  const vaultData = new ethers.Interface([
    "function vaultT2(address smartCol_, address borrowToken_) external",
  ]).encodeFunctionData("vaultT2", [supplyDex, borrowToken]);

  return new ethers.Interface([
    "function deployVault(address vaultDeploymentLogic_, bytes calldata vaultDeploymentData_) external",
  ]).encodeFunctionData("deployVault", [VAULT_LOGIC_T2, vaultData]);
}

async function hasCode(
  provider: JsonRpcProvider,
  address_: string,
): Promise<boolean> {
  const code = await provider.getCode(address_);
  return code !== "0x";
}

async function getVaultAddress(
  provider: JsonRpcProvider,
  vaultId: number,
): Promise<string> {
  const iface = new ethers.Interface([
    "function getVaultAddress(uint256 vaultId_) view returns (address)",
  ]);
  const result = await provider.send("eth_call", [
    {
      to: VAULT_FACTORY,
      data: iface.encodeFunctionData("getVaultAddress", [vaultId]),
    },
    "latest",
  ]);
  return ethers.AbiCoder.defaultAbiCoder().decode(["address"], result)[0];
}

async function getDexAddress(
  provider: JsonRpcProvider,
  dexId: number,
): Promise<string> {
  const iface = new ethers.Interface([
    "function getDexAddress(uint256 dexId_) view returns (address)",
  ]);
  const result = await provider.send("eth_call", [
    {
      to: DEX_FACTORY,
      data: iface.encodeFunctionData("getDexAddress", [dexId]),
    },
    "latest",
  ]);
  return ethers.AbiCoder.defaultAbiCoder().decode(["address"], result)[0];
}

async function getTotalVaults(provider: JsonRpcProvider): Promise<number> {
  const iface = new ethers.Interface([
    "function totalVaults() view returns (uint256)",
  ]);
  const result = await provider.send("eth_call", [
    { to: VAULT_FACTORY, data: iface.encodeFunctionData("totalVaults", []) },
    "latest",
  ]);
  return Number(
    ethers.AbiCoder.defaultAbiCoder().decode(["uint256"], result)[0],
  );
}

async function deployVault180IfNeeded(
  provider: JsonRpcProvider,
): Promise<void> {
  const vault180 = await getVaultAddress(provider, VAULT_180_ID);
  if (await hasCode(provider, vault180)) {
    console.log(
      `[SETUP] Vault ${VAULT_180_ID} (T2 USDai-USDC / USDC) already deployed at ${vault180}`,
    );
    return;
  }

  const totalVaults = await getTotalVaults(provider);
  if (totalVaults < VAULT_180_ID - 1) {
    throw new Error(
      `Cannot deploy vault ${VAULT_180_ID}: fork totalVaults=${totalVaults}, ` +
        `expected at least ${VAULT_180_ID - 1} (vaults 171-179 must exist on the fork).`,
    );
  }
  if (totalVaults !== VAULT_180_ID - 1) {
    throw new Error(
      `Cannot deploy vault ${VAULT_180_ID}: fork totalVaults=${totalVaults}, ` +
        `expected exactly ${VAULT_180_ID - 1} before deploy.`,
    );
  }

  const usdaiUsdcDex = await getDexAddress(provider, USDAI_USDC_DEX_ID);
  if (!usdaiUsdcDex || usdaiUsdcDex === ethers.ZeroAddress) {
    throw new Error(
      `DEX ${USDAI_USDC_DEX_ID} (USDai-USDC) address is zero on the fork.`,
    );
  }
  if (!(await hasCode(provider, usdaiUsdcDex))) {
    throw new Error(
      `DEX ${USDAI_USDC_DEX_ID} (USDai-USDC) has no code at ${usdaiUsdcDex}.`,
    );
  }

  const deployData = getDeployVaultT2Calldata(usdaiUsdcDex, USDC_ADDRESS);
  console.log(
    `[SETUP] Deploying vault ${VAULT_180_ID} (T2 USDai-USDC / USDC) at ${vault180} ` +
      `(collateral DEX ${usdaiUsdcDex})`,
  );

  const txHash = await provider.send("eth_sendTransaction", [
    {
      from: TEAM_MULTISIG,
      to: VAULT_FACTORY,
      data: deployData,
      value: "0x0",
      gas: "0x9896800",
      gasPrice: "0x0",
    },
  ]);
  const receipt = await provider.waitForTransaction(txHash);
  if (!receipt || receipt.status !== 1) {
    throw new Error(
      `Vault ${VAULT_180_ID} deploy transaction failed (tx ${txHash})`,
    );
  }
  console.log(
    `[SETUP] deploy vault ${VAULT_180_ID} (T2 USDai-USDC / USDC) succeeded (${txHash})`,
  );

  if (!(await hasCode(provider, vault180))) {
    throw new Error(
      `Vault ${VAULT_180_ID} deploy succeeded but no code at ${vault180}`,
    );
  }

  const totalAfter = await getTotalVaults(provider);
  if (totalAfter !== VAULT_180_ID) {
    throw new Error(
      `Vault ${VAULT_180_ID} deploy succeeded but totalVaults=${totalAfter}, expected ${VAULT_180_ID}.`,
    );
  }
}

async function getProposalCount(provider: JsonRpcProvider): Promise<number> {
  const iface = new ethers.Interface([
    "function proposalCount() view returns (uint256)",
  ]);
  const result = await provider.send("eth_call", [
    { to: GOVERNOR, data: iface.encodeFunctionData("proposalCount", []) },
    "latest",
  ]);
  return Number(
    ethers.AbiCoder.defaultAbiCoder().decode(["uint256"], result)[0],
  );
}

async function sendTx(
  provider: JsonRpcProvider,
  from: string,
  to: string,
  data: string,
  label: string,
  gas = "0x989680",
): Promise<void> {
  const txHash = await provider.send("eth_sendTransaction", [
    {
      from,
      to,
      data,
      value: "0x0",
      gas,
      gasPrice: "0x0",
    },
  ]);
  const receipt = await provider.waitForTransaction(txHash);
  if (!receipt || receipt.status !== 1) {
    throw new Error(`${label} transaction failed (tx ${txHash})`);
  }
  console.log(`[SETUP] ${label} succeeded (${txHash})`);
}

async function createDummyProposal(provider: JsonRpcProvider): Promise<void> {
  const delegateData = new ethers.Interface([
    "function delegate(address delegatee)",
  ]).encodeFunctionData("delegate", [PROPOSER]);
  await sendTx(
    provider,
    DELEGATOR,
    INST,
    delegateData,
    "delegate INST (delegator -> proposer) for dummy placeholder",
  );

  const targets = [TIMELOCK];
  const values = [0];
  const signatures = [""];
  const calldatas = ["0x"];
  const description =
    "Placeholder (simulation only): consumes a governor proposal id so IGP-134 lands on id 134.";

  const proposeData = new ethers.Interface([
    "function propose(address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, string description) returns (uint256)",
  ]).encodeFunctionData("propose", [
    targets,
    values,
    signatures,
    calldatas,
    description,
  ]);
  await sendTx(
    provider,
    PROPOSER,
    GOVERNOR,
    proposeData,
    "create dummy placeholder proposal",
  );
}

async function ensureGovernorProposalId(
  provider: JsonRpcProvider,
): Promise<void> {
  const count = await getProposalCount(provider);
  console.log(`[SETUP] Current governor proposalCount = ${count}`);

  const needed = TARGET_PROPOSAL_COUNT - count;

  if (needed <= 0) {
    console.log(
      `[SETUP] proposalCount (${count}) already >= ${TARGET_PROPOSAL_COUNT}; ` +
        `IGP-134 will land on id ${count + 1}. No dummy proposal created.`,
    );
    return;
  }

  if (needed > 1) {
    throw new Error(
      `Need ${needed} dummy proposals to reach proposalCount ${TARGET_PROPOSAL_COUNT} ` +
        `(current ${count}), but this setup only creates one. Investigate the fork state.`,
    );
  }

  await createDummyProposal(provider);

  const after = await getProposalCount(provider);
  console.log(
    `[SETUP] proposalCount after dummy = ${after} (next proposal -> id ${after + 1})`,
  );
  if (after + 1 !== IGP134_PROPOSAL_ID) {
    throw new Error(
      `After dummy proposal the next id would be ${after + 1}, expected ${IGP134_PROPOSAL_ID}.`,
    );
  }
}

async function fundReserveWithSteth(provider: JsonRpcProvider): Promise<void> {
  const data = new ethers.Interface([
    "function transfer(address to, uint256 amount) returns (bool)",
  ]).encodeFunctionData("transfer", [FLUID_RESERVE, SIM_RESERVE_STETH_FUNDING]);
  await sendTx(
    provider,
    STETH_WHALE,
    STETH_ADDRESS,
    data,
    `fund Fluid Reserve with ${SIM_RESERVE_STETH_FUNDING / 10n ** 18n} stETH (Action 4 withdraws 148)`,
  );
}

export async function preSetup(
  provider: JsonRpcProvider,
  _payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP134...");

  try {
    await deployVault180IfNeeded(provider);
    await ensureGovernorProposalId(provider);
    await fundReserveWithSteth(provider);

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
