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

/**
 * Pre-setup function that runs before governance simulation
 * @param provider - JsonRpcProvider connected to Tenderly VNet
 */
export async function preSetup(provider: JsonRpcProvider): Promise<void> {
  console.log('[SETUP] Running pre-setup for IGP payload...');

  try {
    // Example 1: Deploy a mock contract
    await deployMockContract(provider);

    // Example 2: Set up account balances
    await setupAccountBalances(provider);

    // Example 3: Configure contract state
    await configureContractState(provider);

    console.log('[SETUP] Pre-setup completed successfully');
  } catch (error: any) {
    console.error('[SETUP] Pre-setup failed:', error.message);
    throw error;
  }
}

/**
 * Example: Deploy a mock contract that might be needed by the payload
 */
async function deployMockContract(provider: JsonRpcProvider): Promise<string> {
  console.log('[SETUP] Deploying mock contract...');

  // Create a signer with Hardhat's default test account
  const deployer = new ethers.Wallet(
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
    provider
  );

  // Fund the deployer account
  try {
    await provider.send('tenderly_setBalance', [
      deployer.address,
      '0x56BC75E2D63100000' // 100 ETH in hex
    ]);
  } catch (error) {
    console.warn('[SETUP] Could not fund deployer account');
  }

  // Example: Deploy a simple mock contract
  const mockContractCode = `
    pragma solidity ^0.8.0;
    contract MockContract {
        address public owner;
        uint256 public value;
        
        constructor() {
            owner = msg.sender;
        }
        
        function setValue(uint256 _value) external {
            value = _value;
        }
        
        function getValue() external view returns (uint256) {
            return value;
        }
    }
  `;

  // For demonstration, we'll use a simple contract factory
  // In practice, you would compile this contract and use its ABI/bytecode
  const mockContractABI = [
    'constructor()',
    'function setValue(uint256 _value) external',
    'function getValue() external view returns (uint256)',
    'function owner() external view returns (address)'
  ];

  // This is a simplified example - in practice you'd use compiled bytecode
  console.log('[SETUP] Mock contract deployment simulated');

  // Return a mock address (in practice, this would be the deployed address)
  return '0x1234567890123456789012345678901234567890';
}

/**
 * Example: Set up account balances for testing
 */
async function setupAccountBalances(provider: JsonRpcProvider): Promise<void> {
  console.log('[SETUP] Setting up account balances...');

  const testAccounts = [
    '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
    '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
    '0x90F79bf6EB2c4f870365E785982E1f101E93b906'
  ];

  for (const account of testAccounts) {
    try {
      await provider.send('tenderly_setBalance', [
        account,
        '0x21E19E0C9BAB2400000' // 1000 ETH in hex
      ]);
      console.log(`[SETUP] Funded account: ${account}`);
    } catch (error) {
      console.warn(`[SETUP] Could not fund account: ${account}`);
    }
  }
}

/**
 * Example: Configure contract state (e.g., set permissions, initialize values)
 */
async function configureContractState(provider: JsonRpcProvider): Promise<void> {
  console.log('[SETUP] Configuring contract state...');

  // Example: Set up a contract with specific state
  // This would typically involve calling setter functions on deployed contracts

  // Mock transaction to demonstrate state configuration
  try {
    await provider.send('eth_sendTransaction', [{
      from: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      to: '0x1234567890123456789012345678901234567890',
      data: '0x', // Empty data for demonstration
      value: '0x0',
      gas: '0x989680',
      gasPrice: '0x0'
    }]);
    console.log('[SETUP] Contract state configured');
  } catch (error) {
    console.warn('[SETUP] Contract state configuration failed (this is expected for mock)');
  }
}

/**
 * Example: Deploy and configure Fluid Protocol contracts
 * This is a more realistic example for Fluid-related IGP payloads
 */
async function setupFluidProtocol(provider: JsonRpcProvider): Promise<void> {
  console.log('[SETUP] Setting up Fluid Protocol contracts...');

  // Example addresses (these would be real deployed addresses)
  const fluidLiquidityAddress = '0x1234567890123456789012345678901234567890';
  const fluidAdminModuleAddress = '0x2345678901234567890123456789012345678901';

  // Example: Set up admin permissions
  try {
    const adminData = ethers.Interface.encodeFunctionData('setAdmin', [
      '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // Admin address
      true // Is admin
    ]);

    await provider.send('eth_sendTransaction', [{
      from: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      to: fluidAdminModuleAddress,
      data: adminData,
      value: '0x0',
      gas: '0x989680',
      gasPrice: '0x0'
    }]);

    console.log('[SETUP] Fluid Protocol admin configured');
  } catch (error) {
    console.warn('[SETUP] Fluid Protocol setup failed:', error);
  }
}

/**
 * Example: Set up external protocol integrations
 */
async function setupExternalProtocols(provider: JsonRpcProvider): Promise<void> {
  console.log('[SETUP] Setting up external protocol integrations...');

  // Example: Set up Uniswap V3 pools
  const uniswapV3Factory = '0x1F98431c8aD98523631AE4a59f267346ea31F984';

  // Example: Set up Aave lending pools
  const aaveLendingPool = '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9';

  // Example: Set up Compound markets
  const compoundComptroller = '0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B';

  console.log('[SETUP] External protocol addresses configured');
  console.log(`[SETUP] Uniswap V3 Factory: ${uniswapV3Factory}`);
  console.log(`[SETUP] Aave Lending Pool: ${aaveLendingPool}`);
  console.log(`[SETUP] Compound Comptroller: ${compoundComptroller}`);
}

/**
 * Utility function to check if a contract exists at an address
 */
async function isContract(provider: JsonRpcProvider, address: string): Promise<boolean> {
  try {
    const code = await provider.getCode(address);
    return code !== '0x';
  } catch (error) {
    return false;
  }
}

/**
 * Utility function to get contract balance
 */
async function getContractBalance(provider: JsonRpcProvider, address: string): Promise<string> {
  try {
    const balance = await provider.getBalance(address);
    return ethers.formatEther(balance);
  } catch (error) {
    return '0';
  }
}

// Export the main preSetup function
export default preSetup;
