/**
 * Pre-Setup Script for IGP137 Payload Simulation
 *
 * 1. Governor proposalCount bump: create a throwaway IGP-136 placeholder
 *    proposal so the real IGP-137 lands on id 137.
 * 2. Deploy USDT/USDC DEX 49 if the fork predates it (Action 7).
 */

import { JsonRpcProvider, ethers } from "ethers";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";

const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";
const DEX_FACTORY = "0x91716C4ED4501fe759D925A6362C00952BF5D91d";
const DEX_T1_DEPLOYMENT_LOGIC =
  "0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819";

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7";

const USDT_USDC_DEX_ID = 49;

const IGP137_PROPOSAL_ID = 137;
const TARGET_PROPOSAL_COUNT = IGP137_PROPOSAL_ID - 1; // 136

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
): Promise<void> {
  const txHash = await provider.send("eth_sendTransaction", [
    {
      from,
      to,
      data,
      value: "0x0",
      gas: "0x989680",
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
    "delegate INST (delegator -> proposer) for dummy IGP-136",
  );

  const targets = [TIMELOCK];
  const values = [0];
  const signatures = [""];
  const calldatas = ["0x"];
  const description =
    "IGP-136 placeholder (simulation only): consumes governor proposal id 136 so IGP-137 lands on id 137.";

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
    "create dummy IGP-136 proposal",
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
        `IGP-137 will land on id ${count + 1}. No dummy proposal created.`,
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
  if (after + 1 !== IGP137_PROPOSAL_ID) {
    throw new Error(
      `After dummy proposal the next id would be ${after + 1}, expected ${IGP137_PROPOSAL_ID}.`,
    );
  }
}

async function hasCode(
  provider: JsonRpcProvider,
  address: string,
): Promise<boolean> {
  const code = await provider.send("eth_getCode", [address, "latest"]);
  return code !== "0x" && code !== "0x0";
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

function getDeployDexT1Calldata(
  token0: string,
  token1: string,
): string {
  const [sorted0, sorted1] = [token0, token1].sort((a, b) =>
    BigInt(a) < BigInt(b) ? -1 : 1,
  );
  const dexDeploymentData = new ethers.Interface([
    "function dexT1(address token0_, address token1_, uint256 oracleMapping_) external returns (bytes memory)",
  ]).encodeFunctionData("dexT1", [sorted0, sorted1, 0]);
  return new ethers.Interface([
    "function deployDex(address dexDeploymentLogic_, bytes calldata dexDeploymentData_) external returns (address)",
  ]).encodeFunctionData("deployDex", [
    DEX_T1_DEPLOYMENT_LOGIC,
    dexDeploymentData,
  ]);
}

async function ensureUsdtUsdcDex(
  provider: JsonRpcProvider,
): Promise<void> {
  const dex49 = await getDexAddress(provider, USDT_USDC_DEX_ID);
  if (await hasCode(provider, dex49)) {
    console.log(
      `[SETUP] DEX ${USDT_USDC_DEX_ID} already deployed at ${dex49}`,
    );
    return;
  }

  console.log(
    `[SETUP] Deploying USDT/USDC DEX ${USDT_USDC_DEX_ID} at ${dex49}`,
  );
  await sendTx(
    provider,
    TEAM_MULTISIG,
    DEX_FACTORY,
    getDeployDexT1Calldata(USDT_ADDRESS, USDC_ADDRESS),
    `deploy DEX ${USDT_USDC_DEX_ID} (USDT-USDC)`,
  );

  const after = await getDexAddress(provider, USDT_USDC_DEX_ID);
  if (!(await hasCode(provider, after))) {
    throw new Error(
      `DEX ${USDT_USDC_DEX_ID} deployment did not create code at ${after}`,
    );
  }
}

export async function preSetup(provider: JsonRpcProvider): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP137...");

  try {
    await ensureGovernorProposalId(provider);
    await ensureUsdtUsdcDex(provider);
    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[SETUP] Pre-setup failed:", message);
    throw error;
  }
}
