#!/usr/bin/env ts-node
import axios from 'axios';
import { ethers, Contract, JsonRpcProvider, EventLog } from 'ethers';
import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { exec } from 'child_process';
import { promisify } from 'util';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import dotenv from 'dotenv';

dotenv.config();

const execAsync = promisify(exec);

interface VNetConfig {
  id: string;
  adminRpc: string;
  slug: string;
  link: string;
}

interface SimulationConfig {
  tenderly: {
    access_key: string;
    account_id: string;
    project_slug: string;
  };
  addresses: {
    inst: string;
    governor: string;
    proposer: string;
    delegator: string;
    castVotes: string[];
  };
  governance: {
    voting_delay: number;
    voting_period: number;
    timelock_delay: number;
  };
}

const INST_ABI = ['function delegate(address delegatee) external'];
const GOVERNOR_ABI = [
  'event ProposalCreated(uint256 id, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 startBlock, uint256 endBlock, string description)',
  'function castVote(uint256 proposalId, uint8 support) external returns (uint256)',
  'function queue(uint256 proposalId) external',
  'function execute(uint256 proposalId) external payable'
];
const PAYLOAD_ABI = ['function propose(string memory description) external returns (uint256)'];

class TenderlyGovernanceSimulator {
  private igpId: string;
  private config: SimulationConfig;

  constructor(igpId: string) {
    this.igpId = igpId;
    this.config = this.loadConfig();
  }

  private loadConfig(): SimulationConfig {
    const configPath = path.join(process.cwd(), 'config', 'simulation-config.yml');

    const defaultConfig: SimulationConfig = {
      tenderly: {
        access_key: process.env.TENDERLY_ACCESS_KEY || '',
        account_id: process.env.TENDERLY_ACCOUNT_ID || '',
        project_slug: process.env.TENDERLY_PROJECT_SLUG || ''
      },
      addresses: {
        inst: '0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb',
        governor: '0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B',
        proposer: '0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01',
        delegator: '0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb',
        castVotes: [
          '0x5AAB0630aaCa6d0bf1c310aF6C2BB3826A951cFb',
          '0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01'
        ]
      },
      governance: {
        voting_delay: 13140,
        voting_period: 13140,
        timelock_delay: 86400
      }
    };

    if (fs.existsSync(configPath)) {
      try {
        const fileContent = fs.readFileSync(configPath, 'utf8');
        const loadedConfig = yaml.load(fileContent) as any;

        return {
          tenderly: {
            access_key: process.env.TENDERLY_ACCESS_KEY || loadedConfig.tenderly?.access_key || defaultConfig.tenderly.access_key,
            account_id: process.env.TENDERLY_ACCOUNT_ID || loadedConfig.tenderly?.account_id || defaultConfig.tenderly.account_id,
            project_slug: process.env.TENDERLY_PROJECT_SLUG || loadedConfig.tenderly?.project_slug || defaultConfig.tenderly.project_slug
          },
          addresses: loadedConfig.addresses || defaultConfig.addresses,
          governance: loadedConfig.governance || defaultConfig.governance
        };
      } catch (error) {
        console.warn('Failed to load config, using defaults:', error);
        return defaultConfig;
      }
    }

    return defaultConfig;
  }

  async createVnet(): Promise<VNetConfig> {
    console.log('\n=== Step 1: Creating Tenderly Virtual Network ===');

    const { access_key, account_id, project_slug } = this.config.tenderly;

    if (!access_key || !account_id || !project_slug) {
      throw new Error('Tenderly credentials not configured');
    }

    try {
      const response = await axios.post(
        `https://api.tenderly.co/api/v1/account/${account_id}/project/${project_slug}/vnets`,
        {
          slug: `igp-${this.igpId}-${Date.now()}`,
          display_name: `IGP ${this.igpId} Simulation`,
          fork_config: {
            network_id: 1
          },
          virtual_network_config: {
            chain_config: {
              chain_id: 1
            }
          }
        },
        {
          headers: {
            'X-Access-Key': access_key,
            'Content-Type': 'application/json'
          }
        }
      );

      const data = response.data;
      const vnetId = data.id;
      const adminRpc = data.rpcs?.find((r: any) => r.name === 'Admin RPC')?.url || data.admin_rpc_url;
      const slug = data.slug;
      const link = `https://dashboard.tenderly.co/${account_id}/${project_slug}/virtual-network/${vnetId}`;

      console.log(`[SUCCESS] VNet Created: ${vnetId}`);
      console.log(`          RPC: ${adminRpc}`);
      console.log(`          Link: ${link}`);
      console.log('[STAGE:COMPLETED] vnetCreation');

      return { id: vnetId, adminRpc, slug, link };

    } catch (error: any) {
      console.error('Failed to create VNet:', error.response?.data || error.message);
      throw error;
    }
  }

  async deployPayload(vnetRpc: string): Promise<string> {
    console.log('\n=== Step 2: Getting Payload Address ===');

    try {
      const provider = new JsonRpcProvider(vnetRpc);

      // Create a signer with Hardhat's default test account
      const deployer = new ethers.Wallet(
        '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
        provider
      );

      console.log(`[INFO]  Deploying from: ${deployer.address}`);

      // Fund the deployer account on Tenderly VNet
      try {
        await provider.send('tenderly_setBalance', [
          deployer.address,
          '0x56BC75E2D63100000' // 100 ETH in hex
        ]);
        console.log('[INFO]  Funded deployer account with 100 ETH');
      } catch (fundError: any) {
        console.warn('[WARN]  Could not fund deployer via tenderly_setBalance, trying evm_setAccountBalance');
        try {
          await provider.send('evm_setAccountBalance', [
            deployer.address,
            '0x56BC75E2D63100000' // 100 ETH in hex
          ]);
          console.log('[INFO]  Funded deployer account with 100 ETH');
        } catch (fallbackError: any) {
          console.warn(`[WARN]  Account funding failed: ${fallbackError.message}`);
          console.warn('[WARN]  Proceeding with deployment anyway...');
        }
      }

      // Read compiled contract artifacts
      const artifactPath = path.join(
        process.cwd(),
        'artifacts',
        'contracts',
        'payloads',
        `IGP${this.igpId}`,
        `PayloadIGP${this.igpId}.sol`,
        `PayloadIGP${this.igpId}.json`
      );

      if (!fs.existsSync(artifactPath)) {
        throw new Error(
          `Artifact not found: ${artifactPath}\n` +
          `Run 'npx hardhat compile' first or ensure PayloadIGP${this.igpId}.sol exists`
        );
      }

      const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
      console.log(`[INFO]  Loaded artifact: PayloadIGP${this.igpId}`);

      // Deploy contract
      const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, deployer);
      const contract = await factory.deploy();

      console.log('[INFO]  Waiting for deployment confirmation...');
      await contract.waitForDeployment();

      const deployedAddress = await contract.getAddress();
      console.log(`[SUCCESS] Payload deployed: ${deployedAddress}`);
      console.log('[STAGE:COMPLETED] payloadDeployment');

      return deployedAddress;

    } catch (error: any) {
      console.error('[ERROR] Deployment failed:', error.message);
      console.error('[ERROR] Ensure the contract compiles and artifacts are generated');
      throw error;
    }
  }

  async runPreSetup(provider: JsonRpcProvider): Promise<void> {
    console.log('\n=== Step 3: Running Pre-Setup (if available) ===');

    const setupPath = path.join(
      process.cwd(),
      'contracts',
      'payloads',
      `IGP${this.igpId}`,
      'simulation',
      'setup.ts'
    );

    if (!fs.existsSync(setupPath)) {
      console.log('[WARN]  No pre-setup script found, skipping...');
      return;
    }

    try {
      console.log(`Found setup script: ${setupPath}`);
      const setupModule = await import(setupPath);

      if (typeof setupModule.preSetup === 'function') {
        console.log('Executing preSetup...');
        await setupModule.preSetup(provider);
        console.log('[SUCCESS] Pre-setup completed');
        console.log('[STAGE:COMPLETED] preSetup');
      }
    } catch (error: any) {
      console.warn('[WARN]  Pre-setup failed:', error.message);
      console.warn('[STAGE:SKIPPED] preSetup');
    }
  }

  async runGovernanceSimulation(vnetConfig: VNetConfig, payloadAddress: string): Promise<{ proposalId: number; transactionHash: string }> {
    console.log('\n=== Step 4: Running Governance Simulation ===');
    console.log('4-Day Governance Timeline:');
    console.log('  Day 0-1: Voting queuing');
    console.log('  Day 1-2: Voting period');
    console.log('  Day 2-3: Execution queuing');
    console.log('  Day 3-4: Execution');
    console.log('');

    const provider = new JsonRpcProvider(vnetConfig.adminRpc);

    try {
      // Step 4.1: Set payload as executable (like original script)
      console.log('Setting payload as executable...');
      await provider.send("eth_sendTransaction", [{
        from: "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e",
        to: payloadAddress,
        data: "0x0e6a204c0000000000000000000000000000000000000000000000000000000000000001", // setExecutable(true)
        value: "",
        gas: "0x9896800",
        gasPrice: "0x0"
      }]);
      console.log('[SUCCESS] Payload set as executable');
      console.log('[STAGE:COMPLETED] setExecutable');

      // Step 4.2: Delegate voting power to payload
      console.log('Delegating voting power to payload...');

      // Use eth_sendTransaction directly like original script
      const delegateData = new ethers.Interface(['function delegate(address delegatee)']).encodeFunctionData('delegate', [payloadAddress]);

      await provider.send("eth_sendTransaction", [{
        from: this.config.addresses.delegator,
        to: this.config.addresses.inst,
        data: delegateData,
        value: "",
        gas: "0x9896800",
        gasPrice: "0x0"
      }]);
      console.log('[SUCCESS] Delegation completed');
      console.log('[STAGE:COMPLETED] delegation');

      // Step 4.3: Create governance proposal
      const descriptionPath = path.join(
        process.cwd(),
        'contracts',
        'payloads',
        `IGP${this.igpId}`,
        'description.md'
      );

      let description = `IGP-${this.igpId}: Governance Proposal`;
      if (fs.existsSync(descriptionPath)) {
        description = fs.readFileSync(descriptionPath, 'utf8');
      }

      console.log('\nPayload creating governance proposal...');

      // Use eth_sendTransaction directly like original script
      const proposeData = new ethers.Interface(['function propose(string memory description)']).encodeFunctionData('propose', [description]);

      const proposeTxHash = await provider.send("eth_sendTransaction", [{
        from: this.config.addresses.proposer,
        to: payloadAddress,
        data: proposeData,
        value: "",
        gas: "0x9896800",
        gasPrice: "0x0"
      }]);

      console.log(`Proposal transaction sent: ${proposeTxHash}`);
      console.log('[STAGE:COMPLETED] proposalTransaction');

      // Wait a moment for transaction to be processed
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Step 4.4: Find the most recent proposal event (like original script)
      const governorContract = new Contract(this.config.addresses.governor, GOVERNOR_ABI, provider);
      const filter = governorContract.filters["ProposalCreated(uint256,address,address[],uint256[],string[],bytes[],uint256,uint256,string)"]();

      // Get current block to search from
      const currentBlockForEvents = await provider.getBlockNumber();
      console.log(`Searching for events from block ${currentBlockForEvents - 10} to ${currentBlockForEvents}`);

      const events = await governorContract.queryFilter(filter, currentBlockForEvents - 10, "latest");

      if (events.length === 0) {
        throw new Error('No ProposalCreated events found');
      }

      // Use the most recent proposal (like original script)
      const event = events[events.length - 1] as EventLog;

      const proposalId = Number(event.args.id);
      const startBlock = Number(event.args.startBlock);
      const endBlock = Number(event.args.endBlock);

      console.log(`Found proposal ID: ${proposalId} (expected IGP: ${this.igpId})`);

      let currentBlock = await provider.getBlockNumber();

      console.log(`[SUCCESS] Proposal Created: ID ${proposalId}`);
      console.log(`   Start: ${startBlock}, End: ${endBlock}, Current: ${currentBlock}`);
      console.log('[STAGE:COMPLETED] proposalCreation');

      // Step 4.5: Advance to voting start
      console.log('\n Day 0-1: Advancing to voting start...');
      const blocksToVotingStart = startBlock - currentBlock + 2;
      console.log(`[INFO]  Need to advance ${blocksToVotingStart} blocks (current: ${currentBlock}, target: ${startBlock})`);

      // Use evm_increaseBlocks with HEX format (works on Tenderly!)
      await provider.send('evm_increaseBlocks', [ethers.toBeHex(blocksToVotingStart)]);

      currentBlock = await provider.getBlockNumber();
      console.log(`[SUCCESS] Advanced to block ${currentBlock} (increased by ${blocksToVotingStart} blocks instantly)`);
      console.log('[STAGE:COMPLETED] votingStartAdvancement');

      // Step 4.6: Cast votes
      console.log('\n  Day 1-2: Casting votes...');
      const castVoteData = new ethers.Interface(['function castVote(uint256 proposalId, uint8 support)']).encodeFunctionData('castVote', [proposalId, 1]);

      for (const voterAddress of this.config.addresses.castVotes) {
        await provider.send("eth_sendTransaction", [{
          from: voterAddress,
          to: this.config.addresses.governor,
          data: castVoteData,
          value: "",
          gas: "0x989680", // 10M gas
          gasPrice: "0x0"
        }]);
        console.log(`   [SUCCESS] Vote cast from ${voterAddress}`);
      }
      console.log('[SUCCESS] All votes cast');
      console.log('[STAGE:COMPLETED] voting');

      // Step 4.7: Advance to voting end
      currentBlock = await provider.getBlockNumber();
      const blocksToVotingEnd = endBlock - currentBlock + 1;
      console.log(`\n Day 1-2: Advancing to voting end...`);
      console.log(`[INFO]  Need to advance ${blocksToVotingEnd} blocks (current: ${currentBlock}, target: ${endBlock})`);

      // Use evm_increaseBlocks with HEX format
      await provider.send('evm_increaseBlocks', [ethers.toBeHex(blocksToVotingEnd)]);

      currentBlock = await provider.getBlockNumber();
      console.log(`[SUCCESS] Advanced to block ${currentBlock} (increased by ${blocksToVotingEnd} blocks instantly)`);
      console.log('[STAGE:COMPLETED] votingEndAdvancement');

      // Step 4.8: Queue proposal
      console.log('\n Day 2-3: Queuing proposal...');
      const queueData = new ethers.Interface(['function queue(uint256 proposalId)']).encodeFunctionData('queue', [proposalId]);

      const queueTxHash = await provider.send("eth_sendTransaction", [{
        from: this.config.addresses.proposer,
        to: this.config.addresses.governor,
        data: queueData,
        value: "",
        gas: "0x989680", // 10M gas
        gasPrice: "0x0"
      }]);
      console.log('[SUCCESS] Proposal queued');
      console.log('[STAGE:COMPLETED] queueing');

      // Step 4.9: Wait timelock delay (1 day like original)
      console.log('\n Day 3-4: Waiting timelock delay (1 day)...');
      try {
        // Try evm_increaseTime with decimal parameter (Tenderly preferred)
        await provider.send('evm_increaseTime', [86400]); // 1 day = 86400 seconds
        console.log('[INFO]  Time advanced by 86400 seconds (1 day)');
      } catch (timeError: any) {
        console.warn(`[WARN]  evm_increaseTime failed: ${timeError.message}`);
        console.log('[INFO]  Attempting alternative: evm_mine with timestamp...');
        try {
          // Fallback: mine block with increased timestamp
          const currentBlock = await provider.getBlock('latest');
          if (currentBlock) {
            const newTimestamp = currentBlock.timestamp + 86400;
            await provider.send('evm_mine', [newTimestamp]);
            console.log('[INFO]  Mined block with +86400s timestamp');
          }
        } catch (fallbackError: any) {
          console.warn(`[WARN]  Time advancement failed: ${fallbackError.message}`);
          console.warn('[WARN]  Proceeding without time delay (may affect execution)');
        }
      }
      console.log('[STAGE:COMPLETED] timelockDelay');

      // Step 4.10: Execute proposal
      console.log('Executing proposal...');
      const executeData = new ethers.Interface(['function execute(uint256 proposalId)']).encodeFunctionData('execute', [proposalId]);

      const executeTxHash = await provider.send("eth_sendTransaction", [{
        from: this.config.addresses.proposer,
        to: this.config.addresses.governor,
        data: executeData,
        value: "",
        gas: "0x2625A00", // 40M gas
        gasPrice: "0x0"
      }]);

      console.log('[SUCCESS] Proposal executed!');
      console.log('[STAGE:COMPLETED] execution');

      // Optional: Final block advancement (not critical)
      try {
        await provider.send('evm_increaseBlocks', [ethers.toBeHex(10)]);
      } catch (e: any) {
        console.warn('[WARN]  Final block advancement skipped (not critical)');
      }

      return {
        proposalId,
        transactionHash: executeTxHash
      };

    } catch (error: any) {
      console.error('Simulation failed:', error.message);
      throw error;
    }
  }

  async simulate(): Promise<void> {
    console.log(`\n${'='.repeat(70)}`);
    console.log(`[START] Governance Simulation for IGP ${this.igpId}`);
    console.log(`${'='.repeat(70)}`);

    let vnetConfig: VNetConfig | undefined;

    try {
      vnetConfig = await this.createVnet();
      const payloadAddress = await this.deployPayload(vnetConfig.adminRpc);

      const provider = new JsonRpcProvider(vnetConfig.adminRpc);
      await this.runPreSetup(provider);

      const result = await this.runGovernanceSimulation(vnetConfig, payloadAddress);

      const adminRpcId = vnetConfig.adminRpc.split('/')[3] || vnetConfig.adminRpc.split('/').pop();
      const tenderlyExecutionLink = `https://dashboard.tenderly.co/${this.config.tenderly.account_id}/${this.config.tenderly.project_slug}/testnet/${vnetConfig.id}/${result.transactionHash}`;
      const fluidUiLink = `https://staging.fluid.io/?isCustomVnet=true&tenderlyId=${adminRpcId}`;

      console.log(`\n${'='.repeat(70)}`);
      console.log('[SUCCESS] Simulation Completed Successfully!');
      console.log(`${'='.repeat(70)}`);
      console.log(`\nProposal ID: ${result.proposalId}`);
      console.log(`VNet ID: ${vnetConfig.id}`);
      console.log(`TX Hash: ${result.transactionHash}`);
      console.log(`Tenderly: ${tenderlyExecutionLink}`);
      console.log(`Fluid UI: ${fluidUiLink}\n`);

      // Output all results for GitHub Actions using new format
      if (process.env.GITHUB_OUTPUT) {
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `proposal_id=${result.proposalId}\n`);
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `vnet_id=${vnetConfig.id}\n`);
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `transaction_hash=${result.transactionHash}\n`);
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `tenderly_execution_link=${tenderlyExecutionLink}\n`);
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `fluid_ui_link=${fluidUiLink}\n`);
      }

    } catch (error: any) {
      console.error(`\n[ERROR] Simulation Failed: ${error.message}`);

      // Enhanced error reporting
      if (error.message.includes('execution reverted')) {
        console.error('\n[ERROR] Transaction execution reverted. This usually indicates:');
        console.error('  - Contract call failed due to business logic');
        console.error('  - Insufficient permissions or state');
        console.error('  - Invalid parameters or preconditions');
        console.error('  - Check the Tenderly debugger for detailed stack trace');
      }

      if (error.message.includes('Called function does not exist')) {
        console.error('\n[ERROR] Function does not exist in contract. This usually indicates:');
        console.error('  - Incorrect function signature or ABI');
        console.error('  - Contract not properly deployed or initialized');
        console.error('  - Wrong contract address being called');
      }

      if (error.message.includes('AdminModule__AddressNotAContract')) {
        console.error('\n[ERROR] Address is not a contract. This usually indicates:');
        console.error('  - Missing contract deployment in pre-setup');
        console.error('  - Incorrect contract address configuration');
        console.error('  - Contract deployment failed silently');
        console.error('  - Check if pre-setup script needs to deploy required contracts');
      }

      // Output error details for GitHub Actions
      if (process.env.GITHUB_OUTPUT) {
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `simulation_status=failed\n`);
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `error_message=${error.message}\n`);
        if (vnetConfig) {
          fs.appendFileSync(process.env.GITHUB_OUTPUT, `vnet_id=${vnetConfig.id}\n`);
          fs.appendFileSync(process.env.GITHUB_OUTPUT, `vnet_link=${vnetConfig.link}\n`);
        }
      }

      throw error;
    }
  }
}

async function main() {
  const args = process.argv.slice(2);
  let igpId = '';

  for (const arg of args) {
    if (arg.startsWith('--id=')) {
      igpId = arg.split('=')[1].replace('igp-', '').replace('IGP', '');
    }
  }

  if (!igpId) {
    console.error('[ERROR] Error: IGP ID required');
    console.error('\nUsage: npx ts-node scripts/simulate.ts --id=<igp-id>');
    console.error('Example: npx ts-node scripts/simulate.ts --id=110');
    process.exit(1);
  }

  const simulator = new TenderlyGovernanceSimulator(igpId);
  await simulator.simulate();
  process.exit(0);
}

// ESM entry point check
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

export { TenderlyGovernanceSimulator };
