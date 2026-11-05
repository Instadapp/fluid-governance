/**
 * Pre-Setup Script for IGPX Payload Simulation
 *
 * Clone mainnet module/auth bytecode to simulation-only addresses and set them
 * on the payload via Team Multisig configurators (actions 1–7).
 */

import { JsonRpcProvider, ethers } from "ethers";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";

/** Matches PayloadIGPX OLD_* constants — bytecode is cloned to SIM_* below. */
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
  console.log("[SETUP] Running pre-setup for IGPX...");

  try {
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
