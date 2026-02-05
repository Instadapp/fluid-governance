/**
 * Sample Pre-Setup Script for IGP Payload Simulation
 * 
 * This file demonstrates how to create a pre-setup script for IGP payloads.
 * Place this file at: contracts/payloads/IGP{ID}/simulation/setup.ts
 * 
 * The pre-setup script runs before the governance simulation and can:
 * - Deploy required contracts
 * - Set up initial state
 * - Configure addresses and parameters
 * - Initialize external dependencies
 */

import { JsonRpcProvider } from 'ethers';

/**
 * Pre-setup function that runs before governance simulation
 * @param provider - JsonRpcProvider connected to Tenderly VNet
 */
export async function preSetup(provider: JsonRpcProvider): Promise<void> {
  console.log('[SETUP] Running pre-setup for IGP payload...');
  

  try {
    {
      await provider.send("eth_sendTransaction", [{
          from: "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e",
          to: "0x4E42f9e626FAcDdd97EDFA537AA52C5024448625",
          data: "0x3659cfe600000000000000000000000034a09c8f82612dbd3e969410ac9911e9d97751c0",
          value: "",
          "gas":"0x9896800",
          "gasPrice":"0x0"
      }]) 
    }

    {   
        await provider.send("eth_sendTransaction", [{
            from: "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e",
            to: "0xe3B7e3f4da603FC40fD889caBdEe30a4cf15DD34",
            data: "0x3659cfe6000000000000000000000000675c2e62e4b5d77a304805df2632da4157fc68b0",
            value: "",
            "gas":"0x9896800",
            "gasPrice":"0x0"
        }]) 
    }

    console.log('[SETUP] Pre-setup completed successfully');
  } catch (error: any) {
    console.error('[SETUP] Pre-setup failed:', error.message);
    throw error;
  }
}

// Export the main preSetup function
export default preSetup;
