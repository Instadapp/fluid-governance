/**
 * Pre-Setup Script for IGP137 Payload Simulation
 *
 * Governor proposalCount bump: create throwaway placeholder proposals if the
 * fork's proposalCount has fallen behind, so the real IGP-137 lands on id 137
 * (PayloadIGP137 hard-codes PROPOSAL_ID = 137).
 *
 * No oracle mocks are required: IGP-137 only withdraws FLUID from the Treasury
 * DSA to Team Multisig. The one execution precondition is that the Treasury
 * holds the 5,000,000 FLUID being withdrawn, which this script asserts.
 */

import { JsonRpcProvider, ethers } from "ethers";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";

const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

const IGP137_PROPOSAL_ID = 137;
const TARGET_PROPOSAL_COUNT = IGP137_PROPOSAL_ID - 1; // 136

// Action 1 withdraws FLUID from the Treasury DSA. FLUID and INST are the same
// ERC-20; the Treasury held ~21.3M at the time of writing, so no funding cheat
// should be necessary.
const TREASURY = "0x28849D2b63fA8D361e5fc15cB8aBB13019884d09";
const FLUID = INST;
const FLUID_REQUIRED = 5_000_000n * 10n ** 18n;

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
    `IGP-${proposalId} placeholder (simulation only): consumes governor proposal id ${proposalId} so IGP-137 lands on id 137.`,
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
        `IGP-137 will land on id ${count + 1}. No dummy proposal created.`,
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
  if (after + 1 !== IGP137_PROPOSAL_ID) {
    throw new Error(
      `After placeholder proposals the next id would be ${after + 1}, expected ${IGP137_PROPOSAL_ID}.`,
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
 * Action 1 withdraws 5,000,000 FLUID from the Treasury DSA. Unlike IGP-136's
 * PST requirement this needs no out-of-band funding — the Treasury already
 * holds far more than the withdrawal amount. We assert rather than cheat: if
 * the balance is short on the fork it is short on mainnet too, and the payload
 * would revert on execution.
 */
async function assertTreasuryFluidBalance(
  provider: JsonRpcProvider,
): Promise<void> {
  const balance = await erc20Balance(provider, FLUID, TREASURY);
  console.log(
    `[SETUP] Treasury FLUID balance = ${ethers.formatUnits(balance, 18)} ` +
      `(required for Action 1: ${ethers.formatUnits(FLUID_REQUIRED, 18)})`,
  );

  if (balance < FLUID_REQUIRED) {
    throw new Error(
      `Treasury holds ${ethers.formatUnits(balance, 18)} FLUID but Action 1 withdraws ` +
        `${ethers.formatUnits(FLUID_REQUIRED, 18)} — the payload would revert on execution.`,
    );
  }
  console.log(
    `[SETUP] Treasury has sufficient FLUID (surplus after withdrawal: ` +
      `${ethers.formatUnits(balance - FLUID_REQUIRED, 18)}).`,
  );
}

export async function preSetup(
  provider: JsonRpcProvider,
  _payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP137...");

  try {
    await ensureGovernorProposalId(provider);
    await assertTreasuryFluidBalance(provider);

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
