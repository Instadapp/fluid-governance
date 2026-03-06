/**
 * Pre-Setup Script for IGP123 Payload Simulation
 *
 * 1. Upgrade DEX V2 and Money Market proxies (same as IGP117 setup)
 * 2. Set rollback module address on payload contract (once deployed)
 */

import { JsonRpcProvider, ethers } from "ethers";

const TEAM_MULTISIG = "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e";

export async function preSetup(provider: JsonRpcProvider): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP123...");

  try {
    // Upgrade DEX V2 proxy
    {
      await provider.send("eth_sendTransaction", [
        {
          from: TEAM_MULTISIG,
          to: "0x4E42f9e626FAcDdd97EDFA537AA52C5024448625",
          data: "0x3659cfe600000000000000000000000034a09c8f82612dbd3e969410ac9911e9d97751c0",
          value: "",
          gas: "0x9896800",
          gasPrice: "0x0",
        },
      ]);
    }

    // Upgrade Money Market proxy
    {
      await provider.send("eth_sendTransaction", [
        {
          from: TEAM_MULTISIG,
          to: "0xe3B7e3f4da603FC40fD889caBdEe30a4cf15DD34",
          data: "0x3659cfe6000000000000000000000000675c2e62e4b5d77a304805df2632da4157fc68b0",
          value: "",
          gas: "0x9896800",
          gasPrice: "0x0",
        },
      ]);
    }

    // TODO: Set rollback module address on payload contract after deployment
    // const payloadAddress = "0x..."; // IGP123 payload address
    // const rollbackModuleAddress = "0x..."; // Deployed rollback module address
    // const iface = new ethers.Interface([
    //   "function setRollbackModuleAddress(address rollbackModuleAddress_) external",
    // ]);
    // const data = iface.encodeFunctionData("setRollbackModuleAddress", [rollbackModuleAddress]);
    // await provider.send("eth_sendTransaction", [
    //   { from: TEAM_MULTISIG, to: payloadAddress, data, value: "0x0", gas: "0x9896800", gasPrice: "0x0" },
    // ]);

    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
