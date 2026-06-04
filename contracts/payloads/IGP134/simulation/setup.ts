/**
 * Pre-Setup Script for IGP134 Payload Simulation
 *
 * 1. Governor proposalCount bump: create a throwaway IGP-133 placeholder proposal so
 *    the real IGP-134 lands on id 134 (PayloadIGP134 hard-codes PROPOSAL_ID = 134).
 * 2. Mock Chainlink feed 0x66ac... for oracle-dependent vault paths (e.g. osETH).
 * 3. Clone mainnet module/auth bytecode to simulation-only addresses and set them
 *    on the payload via Team Multisig configurators (actions 1–7).
 */

import { JsonRpcProvider, ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

const GOVERNOR = "0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B";
const TIMELOCK = "0x2386DC45AdDed673317eF068992F19421B481F4c";
const INST = "0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb";
const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";

const DELEGATOR = "0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb";
const PROPOSER = "0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01";

const IGP134_PROPOSAL_ID = 134;
const TARGET_PROPOSAL_COUNT = IGP134_PROPOSAL_ID - 1; // 133

/** Chainlink feed mocked so latestRoundData() returns (1, 106475560, 1771926611, 1771926611, 1) */
const CHAINLINK_FEED_TO_MOCK = "0x66ac817f997efd114edfcccdce99f3268557b32c";

/** Matches PayloadIGP134 OLD_* constants — bytecode is cloned to SIM_* below. */
const OLD_USER_MODULE = "0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7";
const OLD_ADMIN_MODULE = "0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E";
const OLD_LIQUIDITY_PAUSE_AUTH = "0xE9332F2d45e3216B7634cA4C7ab88945CD84ab76";
const OLD_DEX_PAUSE_AUTH = "0x735BA3772c2cCC0b92Ff6993bd71da88236C1495";
const OLD_RATES_AUTH = "0x1e6B029284dc2779F8FfBD83a3a5aA00EdCE6ba4";
const OLD_RANGE_AUTH = "0x827089c01E9f761ff1A6D7041a9388bDdae74cc4";

const SIM_NEW_USER_MODULE = "0x0000000000000000000000000000000000000101";
const SIM_NEW_ADMIN_MODULE = "0x0000000000000000000000000000000000000102";
const SIM_LIQUIDITY_PAUSE_AUTH = "0x0000000000000000000000000000000000000103";
const SIM_DEX_PAUSE_AUTH = "0x0000000000000000000000000000000000000104";
const SIM_RATES_AUTH = "0x0000000000000000000000000000000000000105";
const SIM_RANGE_AUTH = "0x0000000000000000000000000000000000000106";

function normalizeHex(raw: string): string {
  return raw.startsWith("0x") ? raw : `0x${raw}`;
}

function readArtifactBytecode(relativeArtifactPath: string): string {
  const artifactPath = path.join(process.cwd(), relativeArtifactPath);
  if (!fs.existsSync(artifactPath)) {
    throw new Error(
      `Artifact not found at ${artifactPath}. Run 'npm run compile' first.`,
    );
  }

  const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf-8"));
  const raw =
    artifact.deployedBytecode?.object ?? artifact.deployedBytecode ?? "";
  const bytecode =
    typeof raw === "string" && raw.length > 0 ? normalizeHex(raw) : "";
  if (!bytecode) {
    throw new Error(`${artifactPath} has no deployedBytecode.object`);
  }
  return bytecode;
}

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
    "delegate INST (delegator -> proposer) for dummy IGP-133",
  );

  const targets = [TIMELOCK];
  const values = [0];
  const signatures = [""];
  const calldatas = ["0x"];
  const description =
    "IGP-133 placeholder (simulation only): consumes governor proposal id 133 so IGP-134 lands on id 134.";

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
    "create dummy IGP-133 proposal",
  );
}

async function ensureGovernorProposalId(provider: JsonRpcProvider): Promise<void> {
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

async function mockChainlinkFeed(provider: JsonRpcProvider): Promise<void> {
  const bytecode = readArtifactBytecode(
    "artifacts/contracts/payloads/IGP134/simulation/MockChainlinkFeed.sol/MockChainlinkFeed.json",
  );
  await provider.send("tenderly_setCode", [CHAINLINK_FEED_TO_MOCK, bytecode]);
  console.log("[SETUP] Mocked Chainlink feed for OSETH oracle path");
}

async function cloneBytecode(
  provider: JsonRpcProvider,
  source: string,
  target: string,
  label: string,
): Promise<void> {
  const code = await provider.getCode(source);
  if (code === "0x") {
    throw new Error(`${label}: source ${source} has no code on this fork`);
  }
  await provider.send("tenderly_setCode", [target, code]);
  console.log(`[SETUP] Cloned ${label} bytecode ${source} -> ${target}`);
}

async function prepareSimulationTargets(
  provider: JsonRpcProvider,
): Promise<void> {
  await cloneBytecode(
    provider,
    OLD_USER_MODULE,
    SIM_NEW_USER_MODULE,
    "new UserModule",
  );
  await cloneBytecode(
    provider,
    OLD_ADMIN_MODULE,
    SIM_NEW_ADMIN_MODULE,
    "new AdminModule",
  );
  await cloneBytecode(
    provider,
    OLD_LIQUIDITY_PAUSE_AUTH,
    SIM_LIQUIDITY_PAUSE_AUTH,
    "new Liquidity pause auth",
  );
  await cloneBytecode(
    provider,
    OLD_DEX_PAUSE_AUTH,
    SIM_DEX_PAUSE_AUTH,
    "new Dex pause auth",
  );
  await cloneBytecode(
    provider,
    OLD_RATES_AUTH,
    SIM_RATES_AUTH,
    "new rates auth",
  );
  await cloneBytecode(
    provider,
    OLD_RANGE_AUTH,
    SIM_RANGE_AUTH,
    "new range auth",
  );
}

async function setConfigurableAddresses(
  provider: JsonRpcProvider,
  payloadAddress: string,
): Promise<void> {
  const iface = new ethers.Interface([
    "function setNewUserModuleAddress(address) external",
    "function setNewAdminModuleAddress(address) external",
    "function setPauseAuths(address,address) external",
    "function setNewRatesAuth(address) external",
    "function setNewRangeAuth(address) external",
  ]);

  const calls: { name: string; data: string }[] = [
    {
      name: "setNewUserModuleAddress",
      data: iface.encodeFunctionData("setNewUserModuleAddress", [
        SIM_NEW_USER_MODULE,
      ]),
    },
    {
      name: "setNewAdminModuleAddress",
      data: iface.encodeFunctionData("setNewAdminModuleAddress", [
        SIM_NEW_ADMIN_MODULE,
      ]),
    },
    {
      name: "setPauseAuths",
      data: iface.encodeFunctionData("setPauseAuths", [
        SIM_LIQUIDITY_PAUSE_AUTH,
        SIM_DEX_PAUSE_AUTH,
      ]),
    },
    {
      name: "setNewRatesAuth",
      data: iface.encodeFunctionData("setNewRatesAuth", [SIM_RATES_AUTH]),
    },
    {
      name: "setNewRangeAuth",
      data: iface.encodeFunctionData("setNewRangeAuth", [SIM_RANGE_AUTH]),
    },
  ];

  for (const call of calls) {
    await sendTx(
      provider,
      TEAM_MULTISIG,
      payloadAddress,
      call.data,
      call.name,
    );
  }
}

export async function preSetup(
  provider: JsonRpcProvider,
  payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP134...");

  try {
    await ensureGovernorProposalId(provider);
    await mockChainlinkFeed(provider);
    await prepareSimulationTargets(provider);

    if (payloadAddress) {
      await setConfigurableAddresses(provider, payloadAddress);
    } else {
      console.warn(
        "[SETUP] No payload address provided, skipping configurable address setup",
      );
    }

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
