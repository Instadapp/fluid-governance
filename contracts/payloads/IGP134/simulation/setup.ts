/**
 * Pre-Setup Script for IGP134 Payload Simulation
 *
 * Three responsibilities, run before the propose/queue/execute flow:
 *
 * 1. Deploy vault 180 (T2 USDai-USDC / USDC) if not yet live on the fork.
 *    Vaults 171-179 are already deployed on mainnet; only vault 180 is replayed
 *    from the pending Avocado deploy-only transaction before IGP-134 can set
 *    its borrow-side launch limits and deprecate vault 174.
 *
 * 2. Align the governor proposal id to 134.
 *    `PayloadIGPMain.propose()` ends with `require(proposedId == _PROPOSAL_ID())`
 *    and IGP134 hard-codes `PROPOSAL_ID = 134`. If the fork's GovernorBravo
 *    `proposalCount` is below 133, create a single throwaway placeholder
 *    proposal so the real IGP-134 proposal lands on id 134.
 *
 * 3. Set liteStethRevenueAmount on the payload for Action 3.
 *    Action 3 reverts unless Team Multisig configures a non-zero stETH amount.
 *    We set a minimal 1-wei amount so the revenue-claim path executes.
 *
 * Safety / non-interference (proposal id step):
 *   - The dummy proposal is created by the PROPOSER EOA, not the payload, so it
 *     never collides with the "one live proposal per proposer" rule guarding the
 *     real IGP-134 proposal (whose proposer is the deployed payload contract).
 *   - We temporarily delegate the configured delegator's INST to the proposer to
 *     clear the 1,000,000 INST proposal threshold. The main flow's own
 *     delegate(delegator -> payload) later overwrites this delegation.
 *   - The dummy proposal is never voted on, queued, or executed.
 */

import { JsonRpcProvider, ethers } from "ethers";

import { deployVault180IfNeeded } from "../../common/simulation/usdai-vault-deploys.js";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";
const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";

// Matches addresses.delegator / addresses.proposer in config/simulation-config.yml.
const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

// IGP134 hard-codes PROPOSAL_ID = 134, so the governor must be at count 133
// before the real proposal is created.
const IGP134_PROPOSAL_ID = 134;
const TARGET_PROPOSAL_COUNT = IGP134_PROPOSAL_ID - 1; // 133

// Non-zero stETH wei for Action 3 (iETHv2 revenue claim).
const SIM_LITE_STETH_REVENUE = 1n;

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

async function setLiteStethRevenueAmount(
  provider: JsonRpcProvider,
  payloadAddress: string,
): Promise<void> {
  const iface = new ethers.Interface([
    "function setLiteStethRevenueAmount(uint256) external",
  ]);
  const data = iface.encodeFunctionData("setLiteStethRevenueAmount", [
    SIM_LITE_STETH_REVENUE,
  ]);
  await sendTx(
    provider,
    TEAM_MULTISIG,
    payloadAddress,
    data,
    "setLiteStethRevenueAmount",
  );
}

export async function preSetup(
  provider: JsonRpcProvider,
  payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP134...");

  try {
    // Step 1: deploy vault 180 if not yet live (171-179 already on mainnet).
    await deployVault180IfNeeded(provider);

    // Step 2: align the governor proposal id to 134.
    await ensureGovernorProposalId(provider);

    // Step 3: set the iETHv2 revenue amount for Action 3.
    if (payloadAddress) {
      await setLiteStethRevenueAmount(provider, payloadAddress);
    } else {
      console.warn(
        "[SETUP] No payload address provided, skipping lite revenue setup",
      );
    }

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
