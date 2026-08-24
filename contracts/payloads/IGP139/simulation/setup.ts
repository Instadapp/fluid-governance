/**
 * Pre-Setup Script for IGP139 Payload Simulation
 *
 * Governor proposalCount bump: create throwaway placeholder proposals if the
 * fork's proposalCount has fallen behind, so the real IGP-139 lands on id 139
 * (PayloadIGP139 hard-codes PROPOSAL_ID = 139).
 *
 * Mainnet proposalCount is 137, and IGP-138 (borrow caps / DEX ranges) takes
 * 138, so this script normally creates one placeholder to consume id 138.
 *
 * No oracle mocks are required: IGP-139 only withdraws stETH from the Fluid
 * Reserve to the Fluid Foundation. The one execution precondition is that the
 * Reserve holds the 154.5 stETH being withdrawn, which this script asserts.
 */

import { JsonRpcProvider, ethers } from "ethers";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";

const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

const IGP139_PROPOSAL_ID = 139;
const TARGET_PROPOSAL_COUNT = IGP139_PROPOSAL_ID - 1; // 138

// Action 1 withdraws a fixed 154.5 stETH from the Fluid Reserve, which accrues
// the balance from iETHv2 (Lite) revenue. The Reserve held ~194.8 stETH at the
// time of writing, so there is ~26% headroom, but the amount is fixed and
// `withdrawFunds` does no balance check of its own, so the assertion below
// still guards against an stETH egress between queueing and execution.
const STETH_ADDRESS = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84";
const FLUID_RESERVE = "0x264786EF916af64a1DB19F513F24a3681734ce92";
const FLUID_FOUNDATION = "0xde0377eF25aD02dBcFbc87D632E46bf1972A0Dc3";
const STETH_REQUIRED = 1545n * 10n ** 17n; // 154.5 stETH

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

async function delegateToProposer(provider: JsonRpcProvider): Promise<void> {
  const delegateData = new ethers.Interface([
    "function delegate(address delegatee)",
  ]).encodeFunctionData("delegate", [PROPOSER]);
  await sendTx(
    provider,
    DELEGATOR,
    INST,
    delegateData,
    "delegate INST (delegator -> proposer) for placeholder proposals",
  );
}

async function createDummyProposal(
  provider: JsonRpcProvider,
  proposalId: number,
): Promise<void> {
  const proposeData = new ethers.Interface([
    "function propose(address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, string description) returns (uint256)",
  ]).encodeFunctionData("propose", [
    [TIMELOCK],
    [0],
    [""],
    ["0x"],
    `IGP-${proposalId} placeholder (simulation only): consumes governor proposal id ${proposalId} so IGP-139 lands on id 139.`,
  ]);
  await sendTx(
    provider,
    PROPOSER,
    GOVERNOR,
    proposeData,
    `create dummy IGP-${proposalId} proposal`,
  );
}

async function ensureGovernorProposalId(
  provider: JsonRpcProvider,
): Promise<void> {
  const count = await getProposalCount(provider);
  console.log(`[SETUP] Current governor proposalCount = ${count}`);

  if (count >= TARGET_PROPOSAL_COUNT) {
    console.log(
      `[SETUP] proposalCount (${count}) already >= ${TARGET_PROPOSAL_COUNT}; ` +
        `IGP-139 will land on id ${count + 1}. No dummy proposal created.`,
    );
    return;
  }

  const needed = TARGET_PROPOSAL_COUNT - count;
  console.log(
    `[SETUP] Need ${needed} placeholder proposal(s) to reach proposalCount ${TARGET_PROPOSAL_COUNT}.`,
  );

  await delegateToProposer(provider);
  for (let id = count + 1; id <= TARGET_PROPOSAL_COUNT; id++) {
    await createDummyProposal(provider, id);
  }

  const after = await getProposalCount(provider);
  console.log(
    `[SETUP] proposalCount after placeholders = ${after} (next proposal -> id ${after + 1})`,
  );
  if (after + 1 !== IGP139_PROPOSAL_ID) {
    throw new Error(
      `After placeholder proposals the next id would be ${after + 1}, expected ${IGP139_PROPOSAL_ID}.`,
    );
  }
}

async function erc20Balance(
  provider: JsonRpcProvider,
  token: string,
  holder: string,
): Promise<bigint> {
  const iface = new ethers.Interface([
    "function balanceOf(address) view returns (uint256)",
  ]);
  const result = await provider.send("eth_call", [
    { to: token, data: iface.encodeFunctionData("balanceOf", [holder]) },
    "latest",
  ]);
  return BigInt(result);
}

/**
 * Action 1 withdraws 154.5 stETH from the Fluid Reserve. We assert rather than
 * pre-fund: if the Reserve is short on the fork it is short on mainnet too,
 * and the payload would revert on execution. Team Multisig tops the Reserve up
 * out of band via Lite revenue collection.
 */
async function assertReserveStethBalance(
  provider: JsonRpcProvider,
): Promise<void> {
  const balance = await erc20Balance(provider, STETH_ADDRESS, FLUID_RESERVE);
  console.log(
    `[SETUP] Fluid Reserve stETH balance = ${ethers.formatUnits(balance, 18)} ` +
      `(required for Action 1: ${ethers.formatUnits(STETH_REQUIRED, 18)})`,
  );

  if (balance < STETH_REQUIRED) {
    throw new Error(
      `Fluid Reserve holds ${ethers.formatUnits(balance, 18)} stETH but Action 1 withdraws ` +
        `${ethers.formatUnits(STETH_REQUIRED, 18)} — the payload would revert on execution. ` +
        `Collect Lite revenue into the Reserve before proposing.`,
    );
  }
  console.log(
    `[SETUP] Reserve has sufficient stETH (surplus after withdrawal: ` +
      `${ethers.formatUnits(balance - STETH_REQUIRED, 18)}).`,
  );

  const foundationBalance = await erc20Balance(
    provider,
    STETH_ADDRESS,
    FLUID_FOUNDATION,
  );
  console.log(
    `[SETUP] Fluid Foundation stETH balance before execution = ` +
      `${ethers.formatUnits(foundationBalance, 18)}`,
  );
}

export async function preSetup(
  provider: JsonRpcProvider,
  _payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP139...");

  try {
    await ensureGovernorProposalId(provider);
    await assertReserveStethBalance(provider);

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
