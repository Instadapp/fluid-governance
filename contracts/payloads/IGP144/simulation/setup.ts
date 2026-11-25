/**
 * Pre-Setup Script for IGP144 Payload Simulation
 *
 * IGP-143 executes before IGP-144. IGP-143 action 7 swaps the Liquidity admin
 * module, and IGP-144 action 3 calls pauseUserSupply / pauseUserBorrow, which
 * only exist on the new module. Simulating IGP-144 on today's state therefore
 * reverts, so this script first runs proposal 143 through governance (votes,
 * queue, timelock delay, execute) from wherever it is on chain. Once 143 has
 * executed on mainnet, the script is a no-op.
 */

import { JsonRpcProvider, ethers } from "ethers";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";
const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";
const FLUID_RESERVE = "0x264786EF916af64a1DB19F513F24a3681734ce92";

const PREVIOUS_PROPOSAL_ID = 143;
const PREVIOUS_PAYLOAD = "0xb2b4c4826a666ea7548a5f0077d1aba48281c8e3";

// Same voters as config/simulation-config.yml.
const VOTERS = [
  "0xC7810aA3b0c6A2778EEcC114B93d59B2E9Da9E05",
  "0xa7615cd307f323172331865181dc8b80a2834324",
  "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01",
  "0xd99a63d34F8fF1Daf986C7bB011ceA3cA4e5fFd1",
  "0x71f94Ed2279FA76208e37E025c535B089E3Fd331",
  "0xe9cC02568F6A424cC75424cBFD0093BBe331aA9F",
  "0x4604E3bFbaCcB317a6FfEde8Bf24105F476A7329",
];

// IGP-143 action 4 grant amounts, assumed to be in the Reserve at execution (as in
// IGP143/simulation/setup.ts). tenderly_setErc20Balance rejects GHO, so GHO is
// transferred from the stkGHO contract instead.
const IGP143_RESERVE_FUNDING: { symbol: string; token: string; amount: bigint; holder?: string }[] = [
  { symbol: "USDC", token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", amount: 150_000n * 10n ** 6n },
  { symbol: "USDT", token: "0xdAC17F958D2ee523a2206206994597C13D831ec7", amount: 150_000n * 10n ** 6n },
  {
    symbol: "GHO",
    token: "0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f",
    amount: 50_000n * 10n ** 18n,
    holder: "0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d",
  },
];

const STATES = ["Pending", "Active", "Canceled", "Defeated", "Succeeded", "Queued", "Expired", "Executed"];

const GOVERNOR_ABI = new ethers.Interface([
  "function state(uint256) view returns (uint8)",
  "function proposals(uint256) view returns (uint256 id, address proposer, uint256 eta, uint256 startBlock, uint256 endBlock, uint256 forVotes, uint256 againstVotes, uint256 abstainVotes, bool canceled, bool executed)",
  "function getReceipt(uint256, address) view returns (tuple(bool hasVoted, uint8 support, uint96 votes))",
  "function castVote(uint256, uint8)",
  "function queue(uint256)",
  "function execute(uint256)",
]);

async function readGovernor(provider: JsonRpcProvider, fn: string, args: unknown[]): Promise<ethers.Result> {
  const data = GOVERNOR_ABI.encodeFunctionData(fn, args);
  const raw = await provider.send("eth_call", [{ to: GOVERNOR, data }, "latest"]);
  return GOVERNOR_ABI.decodeFunctionResult(fn, raw);
}

async function proposalState(provider: JsonRpcProvider): Promise<string> {
  const [state] = await readGovernor(provider, "state", [PREVIOUS_PROPOSAL_ID]);
  return STATES[Number(state)];
}

async function send(provider: JsonRpcProvider, from: string, to: string, data: string, label: string): Promise<void> {
  const hash = await provider.send("eth_sendTransaction", [
    { from, to, data, value: "0x0", gas: "0x9896800", gasPrice: "0x0" },
  ]);
  const receipt = await provider.waitForTransaction(hash);
  if (!receipt || receipt.status !== 1) {
    throw new Error(`${label} reverted (${hash})`);
  }
  console.log(`[SETUP] ${label}: ${hash}`);
}

async function erc20Balance(provider: JsonRpcProvider, token: string, holder: string): Promise<bigint> {
  const data = new ethers.Interface(["function balanceOf(address) view returns (uint256)"]).encodeFunctionData(
    "balanceOf",
    [holder],
  );
  return BigInt(await provider.send("eth_call", [{ to: token, data }, "latest"]));
}

async function fundReserveForIgp143(provider: JsonRpcProvider): Promise<void> {
  for (const { symbol, token, amount, holder } of IGP143_RESERVE_FUNDING) {
    const balance = await erc20Balance(provider, token, FLUID_RESERVE);
    if (balance >= amount) continue;
    if (holder) {
      const data = new ethers.Interface(["function transfer(address,uint256)"]).encodeFunctionData("transfer", [
        FLUID_RESERVE,
        amount - balance,
      ]);
      await send(provider, holder, token, data, `Reserve ${symbol} top-up`);
    } else {
      await provider.send("tenderly_setErc20Balance", [token, FLUID_RESERVE, ethers.toBeHex(amount)]);
    }
    console.log(`[SETUP] Reserve ${symbol} balance set to ${amount} for IGP-143 action 4`);
  }
}

async function executePreviousProposal(provider: JsonRpcProvider): Promise<void> {
  const id = PREVIOUS_PROPOSAL_ID;
  let state = await proposalState(provider);
  console.log(`[SETUP] IGP-${id} state: ${state}`);
  if (state === "Executed") return;

  const proposal = await readGovernor(provider, "proposals", [id]);

  if (state === "Pending") {
    const blocks = Number(proposal[3]) - (await provider.getBlockNumber()) + 1;
    await provider.send("evm_increaseBlocks", [ethers.toBeHex(blocks)]);
    state = await proposalState(provider);
  }

  if (state === "Active") {
    const voteData = GOVERNOR_ABI.encodeFunctionData("castVote", [id, 1]);
    for (const voter of VOTERS) {
      const [receipt] = await readGovernor(provider, "getReceipt", [id, voter]);
      if (receipt[0]) continue; // already voted on chain
      await send(provider, voter, GOVERNOR, voteData, `IGP-${id} vote ${voter}`);
    }
    const blocks = Number(proposal[4]) - (await provider.getBlockNumber()) + 1;
    await provider.send("evm_increaseBlocks", [ethers.toBeHex(blocks)]);
    state = await proposalState(provider);
  }

  if (state === "Succeeded") {
    await send(provider, PROPOSER, GOVERNOR, GOVERNOR_ABI.encodeFunctionData("queue", [id]), `IGP-${id} queue`);
    state = await proposalState(provider);
  }

  if (state !== "Queued") {
    throw new Error(`IGP-${id} cannot be executed from state ${state}`);
  }

  const eta = (await readGovernor(provider, "proposals", [id]))[2];
  const latest = await provider.getBlock("latest");
  const wait = Number(eta) - (latest?.timestamp ?? 0) + 1;
  if (wait > 0) await provider.send("evm_increaseTime", [wait]);

  await fundReserveForIgp143(provider);
  await send(
    provider,
    TEAM_MULTISIG,
    PREVIOUS_PAYLOAD,
    new ethers.Interface(["function toggleExecutable(bool)"]).encodeFunctionData("toggleExecutable", [true]),
    `IGP-${id} toggleExecutable`,
  );
  await send(provider, PROPOSER, GOVERNOR, GOVERNOR_ABI.encodeFunctionData("execute", [id]), `IGP-${id} execute`);

  state = await proposalState(provider);
  if (state !== "Executed") {
    throw new Error(`IGP-${id} state after execute: ${state}`);
  }
}

export async function preSetup(provider: JsonRpcProvider, _payloadAddress?: string): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP144...");
  try {
    await executePreviousProposal(provider);
    console.log(`[SETUP] IGP-${PREVIOUS_PROPOSAL_ID} executed, IGP-144 runs on post-IGP-${PREVIOUS_PROPOSAL_ID} state`);
    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[SETUP] Pre-setup failed:", message);
    throw error;
  }
}

export default preSetup;
