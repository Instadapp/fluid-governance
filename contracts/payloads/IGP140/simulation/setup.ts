/**
 * Pre-Setup Script for IGP140 Payload Simulation
 *
 * 1. Governor proposalCount bump: create throwaway placeholder proposals if the
 *    fork's proposalCount has fallen behind, so the real IGP-140 lands on id
 *    140 (PayloadIGP140 hard-codes PROPOSAL_ID = 140).
 *
 *    Mainnet proposalCount is 138, and IGP-139 (Foundation grant) takes 139, so
 *    this normally creates one placeholder to consume id 139.
 *
 * 2. Assert the weETH/ETH vault (id 182) is deployed on the fork. It was
 *    deployed by the Team Multisig at block 25,789,585, so any recent fork has
 *    it. We assert rather than deploy: the Liquidity Layer rejects supply/borrow
 *    configs for an address with no code, and if the vault is missing the fork
 *    is stale in a way worth surfacing rather than papering over.
 */

import { JsonRpcProvider, ethers } from "ethers";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";

const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

const LIQUIDITY = "0x52Aa899454998Be5b000Ad077a46Bbe360F4e497";
const VAULT_FACTORY = "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d";

const weETH_ADDRESS = "0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee";
const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

const VAULT_WEETH_ETH_ID = 182;

/** Liquidity storage slots for the user supply / borrow double mappings. */
const USER_SUPPLY_SLOT = 8;
const USER_BORROW_SLOT = 9;

const IGP140_PROPOSAL_ID = 140;
const TARGET_PROPOSAL_COUNT = IGP140_PROPOSAL_ID - 1; // 139

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
    `IGP-${proposalId} placeholder (simulation only): consumes governor proposal id ${proposalId} so IGP-140 lands on id 140.`,
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
        `IGP-140 will land on id ${count + 1}. No dummy proposal created.`,
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
  if (after + 1 !== IGP140_PROPOSAL_ID) {
    throw new Error(
      `After placeholder proposals the next id would be ${after + 1}, expected ${IGP140_PROPOSAL_ID}.`,
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

async function getVaultAddress(
  provider: JsonRpcProvider,
  vaultId: number,
): Promise<string> {
  const iface = new ethers.Interface([
    "function getVaultAddress(uint256 vaultId_) view returns (address)",
  ]);
  const result = await provider.send("eth_call", [
    { to: VAULT_FACTORY, data: iface.encodeFunctionData("getVaultAddress", [vaultId]) },
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

/** Liquidity `_userSupplyData` / `_userBorrowData` are `mapping(user => mapping(token => uint))`. */
async function readUserConfig(
  provider: JsonRpcProvider,
  baseSlot: number,
  user: string,
  token: string,
): Promise<bigint> {
  const userSlot = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "uint256"],
      [user, baseSlot],
    ),
  );
  const slot = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "bytes32"],
      [token, userSlot],
    ),
  );
  const value = await provider.send("eth_getStorageAt", [
    LIQUIDITY,
    slot,
    "latest",
  ]);
  return BigInt(value);
}

async function assertVaultDeployed(provider: JsonRpcProvider): Promise<void> {
  const vault = await getVaultAddress(provider, VAULT_WEETH_ETH_ID);
  const totalVaults = await getTotalVaults(provider);
  console.log(
    `[SETUP] Vault ${VAULT_WEETH_ETH_ID} address = ${vault} (factory totalVaults = ${totalVaults})`,
  );

  if (!(await hasCode(provider, vault))) {
    throw new Error(
      `Vault ${VAULT_WEETH_ETH_ID} (weETH/ETH) has no code at ${vault} on this fork ` +
        `(totalVaults = ${totalVaults}). It was deployed on mainnet at block 25,789,585, ` +
        `so the fork predates the deployment. Action 1 would revert at the Liquidity Layer ` +
        `with AdminModule__AddressNotAContract (10026).`,
    );
  }
  console.log(`[SETUP] Vault ${VAULT_WEETH_ETH_ID} is deployed on the fork.`);

  // Informational: the payload sets these from scratch, so both should be zero.
  const supplyConfig = await readUserConfig(
    provider,
    USER_SUPPLY_SLOT,
    vault,
    weETH_ADDRESS,
  );
  const borrowConfig = await readUserConfig(
    provider,
    USER_BORROW_SLOT,
    vault,
    ETH_ADDRESS,
  );
  if (supplyConfig !== 0n || borrowConfig !== 0n) {
    console.warn(
      `[SETUP] WARNING: vault ${VAULT_WEETH_ETH_ID} already has Liquidity limits configured ` +
        `(supply=${supplyConfig !== 0n}, borrow=${borrowConfig !== 0n}). ` +
        `IGP-140 will overwrite them with dust limits — confirm that is still intended.`,
    );
  } else {
    console.log(
      `[SETUP] Vault ${VAULT_WEETH_ETH_ID} is unconfigured at the Liquidity Layer, as expected.`,
    );
  }
}

export async function preSetup(
  provider: JsonRpcProvider,
  _payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP140...");

  try {
    await ensureGovernorProposalId(provider);
    await assertVaultDeployed(provider);

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[SETUP] Pre-setup failed:", message);
    throw error;
  }
}

export default preSetup;
