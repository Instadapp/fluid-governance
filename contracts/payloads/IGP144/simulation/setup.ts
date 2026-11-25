/**
 * Pre-Setup Script for IGP144 Payload Simulation
 *
 * IGP-143 executes before IGP-144. IGP-143 action 7 swaps the Liquidity admin
 * module, and IGP-144 action 3 calls pauseUserSupply / pauseUserBorrow, which
 * only exist on the new module. Simulating IGP-144 on today's state therefore
 * reverts, so this script first runs proposal 143 through governance (votes,
 * queue, timelock delay, execute) from wherever it is on chain. Once 143 has
 * executed on mainnet, the script is a no-op.
 *
 * IGP-144 action 4 switches vaults to OracleV2 oracles. On T2/T3/T4 vaults
 * `updateOracle` probes the new oracle's operate and liquidate rates, and the
 * OracleV2 price sources reject stale feed rounds. The simulation warps past
 * the voting period and the timelock delays, so every live feed is stale by
 * then. As in IGP142/simulation/setup.ts, the script replaces the Chainlink /
 * RedStone feeds the new oracles read with a mock that returns the live answer
 * with `updatedAt = block.timestamp`.
 */

import { JsonRpcProvider, ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

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

// Chainlink / RedStone feeds read by the action 4 oracles (getExchangeRateOperate /
// getExchangeRateLiquidate traced on mainnet).
const ACTION4_FEEDS: string[] = [
  "0x02E1F8d15762047b7a87BA0E5d94B9a0c5b54Ed2",
  "0x0911af228c32458a560853605eF78b129c7DF099",
  "0x3E7d1eAB13ad0104d2750B8863b489D65364e32D",
  "0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6",
  "0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c",
  "0xfdFD9C85aD200c506Cf9e21F1FD8dd01932FBB23",
  "0x67F6838e58859d612E4ddF04dA396d6DABB66Dc4",
  "0x65eD6a4ac085620eE943c0B15525C4428D23e4Db",
  "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
  "0x3f12643D3f6f874d39C2a4c9f2Cd6f2DbAC877FC",
  "0xFF3BC18cCBd5999CE63E788A1c250a88626aD099",
  "0xeeF31c7d9F2E82e8A497b140cc60cc082Be4b94e",
  "0xBE4d4D2FDdE7408bD00B9912705De7bDC3F9bDeb",
  "0x2665701293fCbEB223D11A08D826563EDcCE423A",
  "0xF7E906179255EF13270604197610B79bFfe546ca",
  "0x5c29868C58b6e15e2b962943278969Ab6a7D3212",
  "0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6",
  "0x9944D86CEB9160aF5C5feB251FD671923323f8C3",
  "0x66704DAD467A7cA508B3be15865D9B9F3E186c90",
  "0x5c9C449BbC9a6075A2c061dF312a35fd1E05fF22",
  "0x8350b7De6a6a2C1368E7D4Bd968190e13E354297",
  "0x86392dC19c0b719886221c78AB11eb8Cf5c52812",
  "0xa569d910839Ae8865Da8F8e70FfFb0cBA869F961",
  "0xbC5FBcf58CeAEa19D523aBc76515b9AEFb5cfd58",
  "0x5c499403bc092C651e35893AF6fE5CE973692795",
];

const FEED_ABI = new ethers.Interface([
  "function latestRoundData() view returns (uint80,int256,uint256,uint256,uint80)",
  "function decimals() view returns (uint8)",
]);

// Same mock as IGP-142 (compiled by `npm run compile`).
const MOCK_FEED_ARTIFACT = "artifacts/contracts/payloads/IGP142/simulation/MockPriceFeed.sol/MockPriceFeed.json";

function readArtifactBytecode(relativeArtifactPath: string): string {
  const artifactPath = path.join(process.cwd(), relativeArtifactPath);
  if (!fs.existsSync(artifactPath)) {
    throw new Error(`Artifact not found at ${artifactPath}. Run 'npm run compile' first.`);
  }
  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf-8"));
  const raw = artifact.deployedBytecode?.object ?? artifact.deployedBytecode ?? "";
  if (typeof raw !== "string" || raw.length === 0) {
    throw new Error(`${artifactPath} has no deployedBytecode`);
  }
  return raw.startsWith("0x") ? raw : `0x${raw}`;
}

async function mockFeeds(provider: JsonRpcProvider): Promise<void> {
  const bytecode = readArtifactBytecode(MOCK_FEED_ARTIFACT);
  const word = (v: bigint) => ethers.toBeHex(v, 32);
  for (const feed of ACTION4_FEEDS) {
    const round = FEED_ABI.decodeFunctionResult(
      "latestRoundData",
      await provider.send("eth_call", [{ to: feed, data: FEED_ABI.encodeFunctionData("latestRoundData") }, "latest"]),
    );
    const decimals = FEED_ABI.decodeFunctionResult(
      "decimals",
      await provider.send("eth_call", [{ to: feed, data: FEED_ABI.encodeFunctionData("decimals") }, "latest"]),
    )[0];
    const answer: bigint = round[1];
    if (answer <= 0n) {
      throw new Error(`${feed} has a non-positive live answer`);
    }
    await provider.send("tenderly_setCode", [feed, bytecode]);
    await provider.send("tenderly_setStorageAt", [feed, word(0n), word(answer)]);
    await provider.send("tenderly_setStorageAt", [feed, word(1n), word(BigInt(decimals))]);
    console.log(`[SETUP] Mocked feed ${feed}: answer=${answer}, decimals=${decimals}`);
  }
}

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
    await mockFeeds(provider);
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
