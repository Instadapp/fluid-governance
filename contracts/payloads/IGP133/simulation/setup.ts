/**
 * Pre-Setup Script for IGP133 Payload Simulation
 *
 * Why this exists:
 *   `PayloadIGPMain.propose()` ends with `require(proposedId == _PROPOSAL_ID())`,
 *   and IGP133 hard-codes `PROPOSAL_ID = 133`. The Tenderly fork is taken from
 *   mainnet, where the GovernorBravo `proposalCount` is still 131 (IGP-132 has
 *   not been created on-chain yet). Without intervention the simulation's
 *   `propose()` would be assigned id 132 and revert with "PROPOSAL_IS_NOT_SAME",
 *   which is exactly the `proposalCreation` failure seen on the PR.
 *
 *   This pre-setup creates a single throwaway "IGP-132" proposal so the governor
 *   advances proposalCount 131 -> 132. The real IGP-133 proposal created later by
 *   the main simulation flow then lands on id 133 and passes the require check.
 *
 * Safety / non-interference:
 *   - The dummy proposal is created by the PROPOSER EOA (msg.sender to the
 *     governor), not by the payload contract, so it never collides with the
 *     "one live proposal per proposer" rule that guards the real IGP-133
 *     proposal (whose proposer is the freshly deployed payload contract).
 *   - We temporarily delegate the configured delegator's INST to the proposer to
 *     comfortably clear the 1,000,000 INST proposal threshold. The main flow's
 *     own `delegate(delegator -> payload)` step later overwrites this delegation,
 *     so by IGP-133's voting start the delegator's weight sits on the payload and
 *     the proposer is back to its baseline votes. The real vote tally (cast by
 *     the large delegates in simulation-config.yml) is therefore unchanged.
 *   - The dummy proposal is never voted on, queued, or executed; it simply
 *     occupies id 132 and is left to expire/defeat.
 */

import { JsonRpcProvider, ethers } from "ethers";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";

// Matches addresses.delegator / addresses.proposer in config/simulation-config.yml.
const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

// IGP133 hard-codes PROPOSAL_ID = 133, so the governor must be at count 132
// before the real proposal is created.
const IGP133_PROPOSAL_ID = 133;
const TARGET_PROPOSAL_COUNT = IGP133_PROPOSAL_ID - 1; // 132

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
  // 1. Park the delegator's INST on the proposer so it clears the 1M threshold
  //    with margin. Overwritten later by the main flow's delegate(-> payload).
  const delegateData = new ethers.Interface([
    "function delegate(address delegatee)",
  ]).encodeFunctionData("delegate", [PROPOSER]);
  await sendTx(
    provider,
    DELEGATOR,
    INST,
    delegateData,
    "delegate INST (delegator -> proposer) for dummy IGP-132",
  );

  // 2. Create a minimal, never-executed proposal so proposalCount advances by 1.
  const targets = [TIMELOCK];
  const values = [0];
  const signatures = [""];
  const calldatas = ["0x"];
  const description =
    "IGP-132 placeholder (simulation only): consumes governor proposal id 132 so IGP-133 lands on id 133.";

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
    "create dummy IGP-132 proposal",
  );
}

export async function preSetup(
  provider: JsonRpcProvider,
  _payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP133...");

  try {
    const count = await getProposalCount(provider);
    console.log(`[SETUP] Current governor proposalCount = ${count}`);

    const needed = TARGET_PROPOSAL_COUNT - count;

    if (needed <= 0) {
      console.log(
        `[SETUP] proposalCount (${count}) already >= ${TARGET_PROPOSAL_COUNT}; ` +
          `IGP-133 will land on id ${count + 1}. No dummy proposal created.`,
      );
      return;
    }

    if (needed > 1) {
      // GovernorBravo allows only one live proposal per proposer, so a single
      // proposer cannot fill a gap larger than one in a single pass.
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
    if (after + 1 !== IGP133_PROPOSAL_ID) {
      throw new Error(
        `After dummy proposal the next id would be ${after + 1}, expected ${IGP133_PROPOSAL_ID}.`,
      );
    }

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
