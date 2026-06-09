/**
 * Pre-Setup Script for IGP130 Payload Simulation
 *
 * 1. Mock Chainlink feed 0x66ac... so FluidGenericOracle._readChainlinkSource
 *    can read a fresh fixed value during fork simulation.
 * 2. Deploy PST-USDC DEX 45 if the fork predates it.
 * 3. Deploy the five PST ecosystem vaults (ids 165-169) if the fork predates them.
 *
 * Note: this setup intentionally reads PST_ADDRESS from common/constants.sol so
 * the simulation cannot silently run while the Solidity constant is still the
 * placeholder address(0).
 */

import { JsonRpcProvider, ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";
const VAULT_FACTORY = "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d";
const DEX_FACTORY = "0x91716C4EDA1Fb55e84Bf8b4c7085f84285c19085";

const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const USDT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7";

const PST_USDC_DEX_ID = 45;
const USDC_USDT_DEX_ID = 2;

const VAULT_PST_USDC_ID = 165;
const VAULT_PST_USDT_ID = 166;
const VAULT_PST_USDC__USDC_ID = 167;
const VAULT_PST__USDC_USDT_ID = 168;
const VAULT_PST_USDC__USDC_USDT_ID = 169;

const DEX_T1_DEPLOYMENT_LOGIC = "0x3FB3FE857C1eE52e7002196E295a7ADfFeD80819";
const VAULT_LOGIC_T1 = "0xF4b87B0A2315534A8233724b87f2a8E3197ad649";
const VAULT_LOGIC_T2 = "0xf92b954D3B2F6497B580D799Bf0907332AF1f63B";
const VAULT_LOGIC_T3 = "0xbc9c8528c66D1910CFb6Bde2a8f1C2F1D38026c7";
const VAULT_LOGIC_T4 = "0xC292c87F3116CBbfb2186d4594Dc48d55fCa6e34";

/** Chainlink feed mocked so latestRoundData() returns (1, 106475560, 1771926611, 1771926611, 1) */
const CHAINLINK_FEED_TO_MOCK = "0x66ac817f997efd114edfcccdce99f3268557b32c";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

function normalizeHex(raw: string): string {
  return raw.startsWith("0x") ? raw : `0x${raw}`;
}

function isZeroAddress(address_: string): boolean {
  return address_.toLowerCase() === ZERO_ADDRESS;
}

async function hasCode(
  provider: JsonRpcProvider,
  address_: string,
): Promise<boolean> {
  const code = await provider.getCode(address_);
  return code !== "0x";
}

function readPstAddressFromConstants(): string {
  const constantsPath = path.join(
    process.cwd(),
    "contracts",
    "payloads",
    "common",
    "constants.sol",
  );
  const source = fs.readFileSync(constantsPath, "utf-8");
  const match = source.match(
    /PST_ADDRESS\s*=\s*(address\(0\)|0x[a-fA-F0-9]{40})\s*;/,
  );
  if (!match) {
    throw new Error(
      `Could not resolve PST_ADDRESS from ${constantsPath}. Keep the constant on one assignment line for simulation setup.`,
    );
  }
  if (match[1] === "address(0)") {
    throw new Error(
      "PST_ADDRESS is still address(0). Fill the real PST mainnet address before simulating IGP130 PST vault deployment.",
    );
  }
  return ethers.getAddress(match[1]);
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

async function mockChainlinkFeed(provider: JsonRpcProvider): Promise<void> {
  const bytecode = readArtifactBytecode(
    path.join(
      "artifacts",
      "contracts",
      "payloads",
      "IGP130",
      "simulation",
      "MockChainlinkFeed.sol",
      "MockChainlinkFeed.json",
    ),
  );
  await provider.send("tenderly_setCode", [CHAINLINK_FEED_TO_MOCK, bytecode]);
  console.log("[SETUP] Mocked Chainlink feed for OSETH oracle path");
}

async function sendFactoryTx(
  provider: JsonRpcProvider,
  to: string,
  data: string,
  label: string,
): Promise<void> {
  const txHash = await provider.send("eth_sendTransaction", [
    {
      from: TEAM_MULTISIG,
      to,
      data,
      value: "0x0",
      gas: "0x9896800",
      gasPrice: "0x0",
    },
  ]);
  const receipt = await provider.waitForTransaction(txHash);
  if (!receipt || receipt.status !== 1) {
    throw new Error(`${label} transaction failed`);
  }
  console.log(`[SETUP] ${label} succeeded`);
}

async function getDexAddress(
  provider: JsonRpcProvider,
  dexId: number,
): Promise<string> {
  const iface = new ethers.Interface([
    "function getDexAddress(uint256 dexId_) view returns (address)",
  ]);
  const result = await provider.send("eth_call", [
    {
      to: DEX_FACTORY,
      data: iface.encodeFunctionData("getDexAddress", [dexId]),
    },
    "latest",
  ]);
  return ethers.AbiCoder.defaultAbiCoder().decode(["address"], result)[0];
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

function getDeployDexT1Calldata(
  tokenA: string,
  tokenB: string,
  oracleMapping = 0,
): string {
  const [token0, token1] = [tokenA, tokenB].sort((a, b) =>
    BigInt(a) < BigInt(b) ? -1 : 1,
  );
  const dexDeploymentData = new ethers.Interface([
    "function dexT1(address token0_, address token1_, uint256 oracleMapping_) external returns (bytes memory)",
  ]).encodeFunctionData("dexT1", [token0, token1, oracleMapping]);
  return new ethers.Interface([
    "function deployDex(address dexDeploymentLogic_, bytes calldata dexDeploymentData_) external returns (address)",
  ]).encodeFunctionData("deployDex", [
    DEX_T1_DEPLOYMENT_LOGIC,
    dexDeploymentData,
  ]);
}

function getDeployVaultCalldata(
  vaultType: "T1" | "T2" | "T3" | "T4",
  tokenA: string,
  tokenB: string,
): string {
  const perType = {
    T1: {
      logic: VAULT_LOGIC_T1,
      signature: "function vaultT1(address supplyToken_, address borrowToken_) external",
      method: "vaultT1",
    },
    T2: {
      logic: VAULT_LOGIC_T2,
      signature: "function vaultT2(address smartCol_, address borrowToken_) external",
      method: "vaultT2",
    },
    T3: {
      logic: VAULT_LOGIC_T3,
      signature: "function vaultT3(address supplyToken_, address smartDebt_) external",
      method: "vaultT3",
    },
    T4: {
      logic: VAULT_LOGIC_T4,
      signature: "function vaultT4(address smartCol_, address smartDebt_) external",
      method: "vaultT4",
    },
  }[vaultType];

  const vaultDeploymentData = new ethers.Interface([
    perType.signature,
  ]).encodeFunctionData(perType.method, [tokenA, tokenB]);
  return new ethers.Interface([
    "function deployVault(address vaultDeploymentLogic_, bytes calldata vaultDeploymentData_) external returns (address vault_)",
  ]).encodeFunctionData("deployVault", [perType.logic, vaultDeploymentData]);
}

async function ensureDex45(
  provider: JsonRpcProvider,
  pstAddress: string,
): Promise<string> {
  const dex45 = await getDexAddress(provider, PST_USDC_DEX_ID);
  if (await hasCode(provider, dex45)) {
    console.log(`[SETUP] DEX ${PST_USDC_DEX_ID} already deployed at ${dex45}`);
    return dex45;
  }

  console.log(`[SETUP] Deploying PST-USDC DEX ${PST_USDC_DEX_ID} at ${dex45}`);
  await sendFactoryTx(
    provider,
    DEX_FACTORY,
    getDeployDexT1Calldata(pstAddress, USDC_ADDRESS),
    `deploy DEX ${PST_USDC_DEX_ID} (PST-USDC)`,
  );

  if (!(await hasCode(provider, dex45))) {
    throw new Error(`DEX ${PST_USDC_DEX_ID} deployment did not create code at ${dex45}`);
  }
  return dex45;
}

async function ensureVault(
  provider: JsonRpcProvider,
  vaultId: number,
  vaultType: "T1" | "T2" | "T3" | "T4",
  tokenA: string,
  tokenB: string,
  label: string,
): Promise<void> {
  const vault = await getVaultAddress(provider, vaultId);
  if (await hasCode(provider, vault)) {
    console.log(`[SETUP] Vault ${vaultId} (${label}) already deployed at ${vault}`);
    return;
  }

  console.log(`[SETUP] Deploying vault ${vaultId} (${label}) at ${vault}`);
  await sendFactoryTx(
    provider,
    VAULT_FACTORY,
    getDeployVaultCalldata(vaultType, tokenA, tokenB),
    `deploy vault ${vaultId} (${label})`,
  );

  if (!(await hasCode(provider, vault))) {
    throw new Error(`Vault ${vaultId} deployment did not create code at ${vault}`);
  }
}

export async function preSetup(provider: JsonRpcProvider): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP130 (PST ecosystem + Chainlink feed)...");

  try {
    await mockChainlinkFeed(provider);

    const pstAddress = readPstAddressFromConstants();
    if (isZeroAddress(pstAddress)) {
      throw new Error("PST_ADDRESS resolved to zero");
    }
    if (!(await hasCode(provider, pstAddress))) {
      throw new Error(`PST_ADDRESS has no code on this fork: ${pstAddress}`);
    }

    const pstUsdcDex = await ensureDex45(provider, pstAddress);
    const usdcUsdtDex = await getDexAddress(provider, USDC_USDT_DEX_ID);
    if (!(await hasCode(provider, usdcUsdtDex))) {
      throw new Error(`Required USDC-USDT DEX ${USDC_USDT_DEX_ID} has no code at ${usdcUsdtDex}`);
    }

    await ensureVault(
      provider,
      VAULT_PST_USDC_ID,
      "T1",
      pstAddress,
      USDC_ADDRESS,
      "PST / USDC",
    );
    await ensureVault(
      provider,
      VAULT_PST_USDT_ID,
      "T1",
      pstAddress,
      USDT_ADDRESS,
      "PST / USDT",
    );
    await ensureVault(
      provider,
      VAULT_PST_USDC__USDC_ID,
      "T2",
      pstUsdcDex,
      USDC_ADDRESS,
      "PST-USDC / USDC",
    );
    await ensureVault(
      provider,
      VAULT_PST__USDC_USDT_ID,
      "T3",
      pstAddress,
      usdcUsdtDex,
      "PST / USDC-USDT",
    );
    await ensureVault(
      provider,
      VAULT_PST_USDC__USDC_USDT_ID,
      "T4",
      pstUsdcDex,
      usdcUsdtDex,
      "PST-USDC / USDC-USDT",
    );

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
