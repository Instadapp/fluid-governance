/**
 * Pre-Setup Script for IGP136 Payload Simulation
 *
 * Governor proposalCount bump: create a throwaway IGP-135 placeholder proposal so
 * the real IGP-136 lands on id 136 (PayloadIGP136 hard-codes PROPOSAL_ID = 136).
 *
 * No oracle mocks are required: IGP-136 only collects revenue (iETHv2 Lite +
 * Liquidity Layer) into the Reserve and forwards it to Team Multisig.
 */

import { JsonRpcProvider, ethers } from "ethers";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";

const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

const IGP136_PROPOSAL_ID = 136;
const TARGET_PROPOSAL_COUNT = IGP136_PROPOSAL_ID - 1; // 135

// Action 3 (PST T4 vault 169 rebalance) pulls funds from the Reserve at execution:
//   - 2,400 PST  → must be funded into the Reserve SEPARATELY before mainnet execution
//   - 3,400 USDC → self-funded by Action 1 (it retains 3,400 USDC from collected revenue)
const FLUID_RESERVE = "0x264786EF916af64a1DB19F513F24a3681734ce92";
const PST = "0x22aE3D9a738471f405169Af055d31c687087d4c7"; // 6 decimals
const PST_REQUIRED = 2_400n * 10n ** 6n;

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
    "delegate INST (delegator -> proposer) for dummy IGP-135",
  );

  const targets = [TIMELOCK];
  const values = [0];
  const signatures = [""];
  const calldatas = ["0x"];
  const description =
    "IGP-135 placeholder (simulation only): consumes governor proposal id 135 so IGP-136 lands on id 136.";

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
    "create dummy IGP-135 proposal",
  );
}

async function ensureGovernorProposalId(provider: JsonRpcProvider): Promise<void> {
  const count = await getProposalCount(provider);
  console.log(`[SETUP] Current governor proposalCount = ${count}`);

  const needed = TARGET_PROPOSAL_COUNT - count;

  if (needed <= 0) {
    console.log(
      `[SETUP] proposalCount (${count}) already >= ${TARGET_PROPOSAL_COUNT}; ` +
        `IGP-136 will land on id ${count + 1}. No dummy proposal created.`,
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
  if (after + 1 !== IGP136_PROPOSAL_ID) {
    throw new Error(
      `After dummy proposal the next id would be ${after + 1}, expected ${IGP136_PROPOSAL_ID}.`,
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
 * Action 3 requires the Reserve to hold 2,400 PST at execution — this is an
 * OUT-OF-BAND funding step on mainnet (not part of the payload). On the fork we
 * detect the shortfall and top the Reserve up via the Tenderly admin cheat so
 * the rebalance simulates against the funded state.
 *
 * If this logs a shortfall, the same shortfall exists on mainnet: 2,400 PST
 * must be transferred into the Reserve before the proposal is executed.
 */
async function ensureReservePstFunding(
  provider: JsonRpcProvider,
): Promise<void> {
  const balance = await erc20Balance(provider, PST, FLUID_RESERVE);
  console.log(
    `[SETUP] Reserve PST balance = ${ethers.formatUnits(balance, 6)} (required for Action 3: ${ethers.formatUnits(PST_REQUIRED, 6)})`,
  );

  if (balance >= PST_REQUIRED) {
    console.log("[SETUP] Reserve already holds enough PST — no funding needed.");
    return;
  }

  const shortfall = PST_REQUIRED - balance;
  console.warn(
    `[SETUP] ⚠️  MAINNET ACTION REQUIRED: Reserve is short ${ethers.formatUnits(shortfall, 6)} PST — ` +
      `fund 2,400 PST into the Reserve (${FLUID_RESERVE}) BEFORE executing IGP-136, or Action 3 will revert.`,
  );

  // Fork-only cheat: set the Reserve's PST balance to the required amount.
  await provider.send("tenderly_setErc20Balance", [
    PST,
    FLUID_RESERVE,
    ethers.toBeHex(PST_REQUIRED),
  ]);

  const after = await erc20Balance(provider, PST, FLUID_RESERVE);
  if (after < PST_REQUIRED) {
    throw new Error(
      `PST funding cheat failed: Reserve balance ${ethers.formatUnits(after, 6)} < required 2,400`,
    );
  }
  console.log(
    `[SETUP] Funded Reserve with PST on fork (balance now ${ethers.formatUnits(after, 6)}). ` +
      "Remember: this is a simulation cheat — mainnet still needs the real 2,400 PST transfer.",
  );
}

export async function preSetup(
  provider: JsonRpcProvider,
  _payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP136...");

  try {
    await ensureGovernorProposalId(provider);
    await ensureReservePstFunding(provider);

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
