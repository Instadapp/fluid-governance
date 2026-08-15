/**
 * Pre-Setup Script for IGP138 Payload Simulation
 *
 * 1. Governor proposalCount bump: create a throwaway IGP-137 placeholder
 *    proposal so the real IGP-138 lands on id 138.
 * 2. List trUSD at the Liquidity Layer via LiquidityTokenAuth if the fork
 *    predates the MS listing (Action 10 sets LL limits for it).
 * 3. Deploy USDat/USDC DEX 49 and USDC/trUSD DEX 50 — in that order, ids
 *    are sequential — if the fork predates them (Actions 7 and 10).
 */

import { JsonRpcProvider, ethers } from "ethers";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";

const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";
const DEX_FACTORY = "0x91716C4EDA1Fb55e84Bf8b4c7085f84285c19085";
const DEX_T1_DEPLOYMENT_LOGIC =
  "0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819";

const LIQUIDITY = "0x52Aa899454998Be5b000Ad077a46Bbe360F4e497";
const LIQUIDITY_TOKEN_AUTH = "0x3C27B24E9d7f3F5B9B4914A430C34ac8f8B27006";

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const USDAT_ADDRESS = "0x23238f20b894f29041f48D88eE91131C395Aaa71";
const TRUSD_ADDRESS = "0xd0580192E98eA6CEB9c7b6191Ed2E27560911697";

const USDAT_USDC_DEX_ID = 49;
const USDC_TRUSD_DEX_ID = 50;
// mirrors fluid-contracts mainnet-deploy-usdat-usdc-dex.ts (~1 day at 12s blocks)
const ORACLE_MAPPING = 1024;

const IGP138_PROPOSAL_ID = 138;
const TARGET_PROPOSAL_COUNT = IGP138_PROPOSAL_ID - 1; // 137

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
      gas: "0x1000000", // 16,777,216 — EIP-7825 per-tx gas cap; DexT1 deploy needs ~15M
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
    "delegate INST (delegator -> proposer) for dummy IGP-137",
  );

  const targets = [TIMELOCK];
  const values = [0];
  const signatures = [""];
  const calldatas = ["0x"];
  const description =
    "IGP-137 placeholder (simulation only): consumes governor proposal id 137 so IGP-138 lands on id 138.";

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
    "create dummy IGP-137 proposal",
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
        `IGP-138 will land on id ${count + 1}. No dummy proposal created.`,
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
  if (after + 1 !== IGP138_PROPOSAL_ID) {
    throw new Error(
      `After dummy proposal the next id would be ${after + 1}, expected ${IGP138_PROPOSAL_ID}.`,
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
  ]).encodeFunctionData("dexT1", [sorted0, sorted1, ORACLE_MAPPING]);
  return new ethers.Interface([
    "function deployDex(address dexDeploymentLogic_, bytes calldata dexDeploymentData_) external returns (address)",
  ]).encodeFunctionData("deployDex", [
    DEX_T1_DEPLOYMENT_LOGIC,
    dexDeploymentData,
  ]);
}

async function ensureDexDeployed(
  provider: JsonRpcProvider,
  dexId: number,
  tokenA: string,
  tokenB: string,
  label: string,
): Promise<void> {
  const dex = await getDexAddress(provider, dexId);
  if (await hasCode(provider, dex)) {
    console.log(`[SETUP] DEX ${dexId} (${label}) already deployed at ${dex}`);
    return;
  }

  console.log(`[SETUP] Deploying ${label} DEX ${dexId} at ${dex}`);
  await sendTx(
    provider,
    TEAM_MULTISIG,
    DEX_FACTORY,
    getDeployDexT1Calldata(tokenA, tokenB),
    `deploy DEX ${dexId} (${label})`,
  );

  const after = await getDexAddress(provider, dexId);
  if (!(await hasCode(provider, after))) {
    throw new Error(
      `DEX ${dexId} deployment did not create code at ${after}`,
    );
  }
}

async function ensureTokenListedAtLiquidity(
  provider: JsonRpcProvider,
  token: string,
  label: string,
): Promise<void> {
  // exchangePriceAndConfig mapping lives at Liquidity storage slot 5;
  // zero config means the token was never listed.
  const slot = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "uint256"],
      [token, 5],
    ),
  );
  const config = await provider.send("eth_getStorageAt", [
    LIQUIDITY,
    slot,
    "latest",
  ]);
  if (BigInt(config) !== 0n) {
    console.log(`[SETUP] ${label} already listed at Liquidity Layer`);
    return;
  }

  const listData = new ethers.Interface([
    "function listToken(address token_)",
  ]).encodeFunctionData("listToken", [token]);
  await sendTx(
    provider,
    TEAM_MULTISIG,
    LIQUIDITY_TOKEN_AUTH,
    listData,
    `list ${label} at Liquidity via LiquidityTokenAuth`,
  );
}

export async function preSetup(provider: JsonRpcProvider): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP138...");

  try {
    await ensureGovernorProposalId(provider);
    await ensureTokenListedAtLiquidity(provider, TRUSD_ADDRESS, "trUSD");
    // deploy order matters: dex ids are assigned sequentially
    await ensureDexDeployed(
      provider,
      USDAT_USDC_DEX_ID,
      USDAT_ADDRESS,
      USDC_ADDRESS,
      "USDat-USDC",
    );
    await ensureDexDeployed(
      provider,
      USDC_TRUSD_DEX_ID,
      USDC_ADDRESS,
      TRUSD_ADDRESS,
      "USDC-trUSD",
    );
    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[SETUP] Pre-setup failed:", message);
    throw error;
  }
}
