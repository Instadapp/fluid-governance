/**
 * Vault 180 deploy calldata for IGP-134 simulation pre-setup.
 *
 * Vaults 171-179 already exist on the mainnet fork; only vault 180 (T2
 * USDai-USDC / USDC, collateral at DEX 47) is not yet deployed and must be
 * replayed before IGP-134 can set its borrow-side launch limits.
 */

import { JsonRpcProvider, ethers } from "ethers";

export const VAULT_FACTORY = "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d";
export const VAULT_DEPLOYER = "0x1e2e1aeD876f67Fe4Fd54090FD7B8F57Ce234219";

const VAULT_180_ID = 180;
const VAULT_180_NOTE = "T2 USDai-USDC / USDC";

// DEX 47 (USDai-USDC): 0x4653583Be64eB008d7F34cc6023A81C5033e6f70
const VAULT_180_DEPLOY_DATA =
  "0x968cbade000000000000000000000000f92b954d3b2f6497b580d799bf0907332af1f63b0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000004446751ee10000000000000000000000004653583be64eb008d7f34cc6023a81c5033e6f70000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000";

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

async function sendTx(
  provider: JsonRpcProvider,
  from: string,
  to: string,
  data: string,
  label: string,
  gas = "0x9896800",
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

/** Deploy vault 180 if not already live on the fork (vaults 171-179 are assumed deployed). */
export async function deployVault180IfNeeded(
  provider: JsonRpcProvider,
): Promise<void> {
  const vault = await getVaultAddress(provider, VAULT_180_ID);
  if (await hasCode(provider, vault)) {
    console.log(
      `[SETUP] Vault ${VAULT_180_ID} (${VAULT_180_NOTE}) already deployed at ${vault}`,
    );
    return;
  }

  const total = await getTotalVaults(provider);
  if (total !== VAULT_180_ID - 1) {
    throw new Error(
      `Expected totalVaults ${VAULT_180_ID - 1} before deploying vault ${VAULT_180_ID}, ` +
        `but factory reports ${total}. Aborting to avoid mis-numbered vaults.`,
    );
  }

  console.log(
    `[SETUP] Deploying vault ${VAULT_180_ID} (${VAULT_180_NOTE}) at ${vault}`,
  );
  await sendTx(
    provider,
    VAULT_DEPLOYER,
    VAULT_FACTORY,
    VAULT_180_DEPLOY_DATA,
    `deploy vault ${VAULT_180_ID} (${VAULT_180_NOTE})`,
  );

  if (!(await hasCode(provider, vault))) {
    throw new Error(
      `Vault ${VAULT_180_ID} deployment did not create code at ${vault}`,
    );
  }
}
