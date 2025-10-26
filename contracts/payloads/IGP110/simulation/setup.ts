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

import { JsonRpcProvider, ethers } from 'ethers';

const VAULT_LOGIC_ADDRESS = (type: string) => {
  if (type === "T2") {
    return "0xf92b954D3B2F6497B580D799Bf0907332AF1f63B"
  } else if (type === "T1") {
    return "0xf4b87b0a2315534a8233724b87f2a8e3197ad649"
  } else {
    throw new Error("Invalid vault type")
  }
}

/**
 * Pre-setup function that runs before governance simulation
 * @param provider - JsonRpcProvider connected to Tenderly VNet
 */
export async function preSetup(provider: JsonRpcProvider): Promise<void> {
  console.log('[SETUP] Running pre-setup for IGP payload...');
  

  try {
    // T2 [TYPE 2] SYRUPUSDT-USDT<>USDT - 149 
    {
        const vaultType = "T2"
        const supplyToken = "0x93b17A6497f045Dc60309921e47c1FA4dC792302"
        const borrowToken = "0xdac17f958d2ee523a2206206994597c13d831ec7"

        await provider.send("eth_sendTransaction", [{
            from: "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e",
            to: "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d",
            data: getDeployVaultCalldata(vaultType, VAULT_LOGIC_ADDRESS(vaultType), supplyToken, borrowToken),
            value: "",
            "gas":"0x9896800",
            "gasPrice":"0x0"
        }]) 
    }

    // T1 [TYPE 1] SYRUPUSDT<>USDC - 150
    {   
        const vaultType = "T1"
        const supplyToken = "0x356b8d89c1e1239cbbb9de4815c39a1474d5ba7d"
        const borrowToken = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

        await provider.send("eth_sendTransaction", [{
            from: "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e",
            to: "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d",
            data: getDeployVaultCalldata(vaultType, VAULT_LOGIC_ADDRESS(vaultType), supplyToken, borrowToken),
            value: "",
            "gas":"0x9896800",
            "gasPrice":"0x0"
        }]) 
    }

    // T1 [TYPE 1] SYRUPUSDT<>USDT - 151
    {   
      const vaultType = "T1"
      const supplyToken = "0x356b8d89c1e1239cbbb9de4815c39a1474d5ba7d"
      const borrowToken = "0xdac17f958d2ee523a2206206994597c13d831ec7"

      await provider.send("eth_sendTransaction", [{
          from: "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e",
          to: "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d",
          data: getDeployVaultCalldata(vaultType, VAULT_LOGIC_ADDRESS(vaultType), supplyToken, borrowToken),
          value: "",
          "gas":"0x9896800",
          "gasPrice":"0x0"
      }]) 
    }

    // T1 [TYPE 1] SYRUPUSDT<>GHO - 152
    {   
      const vaultType = "T1"
      const supplyToken = "0x356b8d89c1e1239cbbb9de4815c39a1474d5ba7d"
      const borrowToken = "0x40d16fc0246ad3160ccc09b8d0d3a2cd28ae6c2f"

      await provider.send("eth_sendTransaction", [{
          from: "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e",
          to: "0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d",
          data: getDeployVaultCalldata(vaultType, VAULT_LOGIC_ADDRESS(vaultType), supplyToken, borrowToken),
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

const getDeployVaultCalldata = (vaultType: any, logic: any, supplyToken: any, borrowToken: any) => {
  const ABI = [
      `function vault${vaultType}(address smartCol_, address borrowToken_) external`
  ]

  const DEPLOYERABI = [
      "function deployVault(address vaultDeploymentLogic_, bytes calldata vaultDeploymentData_) external"
  ]

  const logicData = new ethers.Interface(ABI).encodeFunctionData(`vault${vaultType}`, [supplyToken, borrowToken])
  const deployerData = new ethers.Interface(DEPLOYERABI).encodeFunctionData("deployVault", [logic, logicData])
  return deployerData
}

// Export the main preSetup function
export default preSetup;
