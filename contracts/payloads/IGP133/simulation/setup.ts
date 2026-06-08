/**
 * Pre-Setup Script for IGP133 Payload Simulation
 *
 * Two responsibilities, both run before the main propose/queue/execute flow:
 *
 * 1. Deploy the not-yet-live USDai vaults (ids 174-179).
 *    IGP-133 sets dust limits + Team Multisig auth on vaults 171-179, but only
 *    171-173 exist on mainnet today. The remaining six (174-179) are queued as
 *    pending "deploy only, no config" transactions on the Avocado deployer
 *    multisig (0x1e2e1aeD876f67Fe4Fd54090FD7B8F57Ce234219). We replay the exact
 *    `deployVault(logic, vaultData)` calldata of those pending transactions
 *    (fetched from the Avocado multisig API) against the VaultFactory from the
 *    deployer safe so the fork matches the post-deployment mainnet state the
 *    payload assumes. Without this, getVaultAddress(174..179) has no code and
 *    the payload's setVaultLimits / setVaultAuth calls would operate on
 *    undeployed vaults.
 *
 *    Source (status=pending, chain_id=1):
 *      GET https://multisig-api.avocado.instadapp.io/safes/
 *          0x1e2e1aeD876f67Fe4Fd54090FD7B8F57Ce234219/transactions
 *    The deploys MUST run in ascending vaultId order: the factory assigns the
 *    next sequential id on each deployVault, so order determines the ids.
 *
 * 2. Align the governor proposal id to 133.
 *    `PayloadIGPMain.propose()` ends with `require(proposedId == _PROPOSAL_ID())`
 *    and IGP133 hard-codes `PROPOSAL_ID = 133`. The Tenderly fork is taken from
 *    mainnet, where the GovernorBravo `proposalCount` may still be below 132.
 *    This pre-setup creates a single throwaway placeholder proposal (only when
 *    needed) so the governor advances to proposalCount 132. The real IGP-133
 *    proposal created later by the main simulation flow then lands on id 133.
 *
 * Safety / non-interference (proposal id step):
 *   - The dummy proposal is created by the PROPOSER EOA, not the payload, so it
 *     never collides with the "one live proposal per proposer" rule guarding the
 *     real IGP-133 proposal (whose proposer is the deployed payload contract).
 *   - We temporarily delegate the configured delegator's INST to the proposer to
 *     clear the 1,000,000 INST proposal threshold. The main flow's own
 *     delegate(delegator -> payload) later overwrites this delegation.
 *   - The dummy proposal is never voted on, queued, or executed.
 */

import { JsonRpcProvider, ethers } from "ethers";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";
const VAULT_FACTORY = "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d";

// Avocado deployer multisig that owns the pending vault-deploy transactions and
// is an authorized deployer on the VaultFactory (verified on-chain).
const VAULT_DEPLOYER = "0x1e2e1aeD876f67Fe4Fd54090FD7B8F57Ce234219";

// Matches addresses.delegator / addresses.proposer in config/simulation-config.yml.
const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

// IGP133 hard-codes PROPOSAL_ID = 133, so the governor must be at count 132
// before the real proposal is created.
const IGP133_PROPOSAL_ID = 133;
const TARGET_PROPOSAL_COUNT = IGP133_PROPOSAL_ID - 1; // 132

// Pending Avocado deploy-only transactions for the not-yet-live USDai vaults.
// `data` is the raw inner action calldata (deployVault(logic, vaultData)) sent
// to VAULT_FACTORY when the deployer safe executes each cast. Replayed verbatim
// and in ascending vaultId order so the factory assigns ids 174-179.
const USDAI_VAULT_DEPLOY_TXS: {
  vaultId: number;
  note: string;
  data: string;
}[] = [
  {
    vaultId: 174,
    note: "T1 USDai / USDC",
    data: "0x968cbade000000000000000000000000f4b87b0a2315534a8233724b87f2a8e3197ad64900000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000044f9f872f50000000000000000000000000a1a1a107e45b7ced86833863f482bc5f4ed82ef000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000",
  },
  {
    vaultId: 175,
    note: "T4 sUSDai-USDC / USDC-USDT",
    data: "0x968cbade000000000000000000000000c292c87f3116cbbfb2186d4594dc48d55fca6e34000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000449f690ff1000000000000000000000000a2e3a4e2a08b5714fa974ce88466d736bd8b39d9000000000000000000000000667701e51b4d1ca244f17c78f7ab8744b4c99f9b00000000000000000000000000000000000000000000000000000000",
  },
  {
    vaultId: 176,
    note: "T4 sUSDai-USDT / USDC-USDT",
    data: "0x968cbade000000000000000000000000c292c87f3116cbbfb2186d4594dc48d55fca6e34000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000449f690ff1000000000000000000000000b9b87a1b79891a8c9251f501b1b5d71bc7c8aa24000000000000000000000000667701e51b4d1ca244f17c78f7ab8744b4c99f9b00000000000000000000000000000000000000000000000000000000",
  },
  {
    vaultId: 177,
    note: "T2 sUSDai-USDT / USDT",
    data: "0x968cbade000000000000000000000000f92b954d3b2f6497b580d799bf0907332af1f63b0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004446751ee1000000000000000000000000b9b87a1b79891a8c9251f501b1b5d71bc7c8aa24000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000",
  },
  {
    vaultId: 178,
    note: "T2 sUSDai-USDC / USDC",
    data: "0x968cbade000000000000000000000000f92b954d3b2f6497b580d799bf0907332af1f63b0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004446751ee1000000000000000000000000a2e3a4e2a08b5714fa974ce88466d736bd8b39d9000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000",
  },
  {
    vaultId: 179,
    note: "T1 sUSDai / GHO",
    data: "0x968cbade000000000000000000000000f4b87b0a2315534a8233724b87f2a8e3197ad64900000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000044f9f872f50000000000000000000000000b2b2b2076d95dda7817e785989fe353fe955ef900000000000000000000000040d16fc0246ad3160ccc09b8d0d3a2cd28ae6c2f00000000000000000000000000000000000000000000000000000000",
  },
];

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

async function deployUsdaiVaults(provider: JsonRpcProvider): Promise<void> {
  for (const { vaultId, note, data } of USDAI_VAULT_DEPLOY_TXS) {
    const vault = await getVaultAddress(provider, vaultId);
    if (await hasCode(provider, vault)) {
      console.log(
        `[SETUP] Vault ${vaultId} (${note}) already deployed at ${vault}`,
      );
      continue;
    }

    // The factory assigns id = totalVaults + 1 on deploy, so guard against an
    // unexpected fork state that would mis-number the vaults.
    const total = await getTotalVaults(provider);
    if (total !== vaultId - 1) {
      throw new Error(
        `Expected totalVaults ${vaultId - 1} before deploying vault ${vaultId}, ` +
          `but factory reports ${total}. Aborting to avoid mis-numbered vaults.`,
      );
    }

    console.log(`[SETUP] Deploying vault ${vaultId} (${note}) at ${vault}`);
    await sendTx(
      provider,
      VAULT_DEPLOYER,
      VAULT_FACTORY,
      data,
      `deploy vault ${vaultId} (${note})`,
      "0x9896800",
    );

    if (!(await hasCode(provider, vault))) {
      throw new Error(
        `Vault ${vaultId} deployment did not create code at ${vault}`,
      );
    }
  }
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
    "delegate INST (delegator -> proposer) for dummy placeholder",
  );

  // 2. Create a minimal, never-executed proposal so proposalCount advances by 1.
  const targets = [TIMELOCK];
  const values = [0];
  const signatures = [""];
  const calldatas = ["0x"];
  const description =
    "Placeholder (simulation only): consumes a governor proposal id so IGP-133 lands on id 133.";

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

export async function preSetup(
  provider: JsonRpcProvider,
  _payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP133...");

  try {
    // Step 1: deploy the USDai vaults (174-179) the payload configures.
    await deployUsdaiVaults(provider);

    // Step 2: align the governor proposal id to 133.
    const count = await getProposalCount(provider);
    console.log(`[SETUP] Current governor proposalCount = ${count}`);

    const needed = TARGET_PROPOSAL_COUNT - count;

    if (needed <= 0) {
      console.log(
        `[SETUP] proposalCount (${count}) already >= ${TARGET_PROPOSAL_COUNT}; ` +
          `IGP-133 will land on id ${count + 1}. No dummy proposal created.`,
      );
      console.log("[SETUP] Pre-setup completed successfully");
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
