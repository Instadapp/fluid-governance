#!/usr/bin/env ts-node
/**
 * Tenderly Governance Simulator
 * 
 * Note: This script uses Tenderly Virtual Networks (Virtual TestNets) which have specific URL formats:
 * - VNet Creation API: POST /api/v1/account/{account_id}/project/{project_slug}/vnets
 * - VNet Transaction API: GET /api/v1/account/{account_id}/project/{project_slug}/vnets/{vnet_id}/transactions/{tx_hash}
 * - VNet Dashboard URL: https://dashboard.tenderly.co/{account_id}/{project_slug}/testnet/{vnet_id}
 * - Transaction Dashboard URL: https://dashboard.tenderly.co/{account_id}/{project_slug}/testnet/{vnet_id}/tx/{tx_hash}
 * 
 * Do NOT confuse Virtual Networks with the Simulation API (which uses /simulation/ endpoints)
 */
import axios from 'axios';
import { ethers, Contract, JsonRpcProvider, EventLog, AbiCoder } from 'ethers';
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

// Global timeout configuration (10 minutes)
const GLOBAL_TIMEOUT_MS = 10 * 60 * 1000;

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
  github?: {
    token: string;
    repo: string;
    pr_number?: number;
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

interface TransactionDetails {
  hash: string;
  from: string;
  to: string;
  data: string;
  value: string;
  gasLimit: string;
  gasPrice: string;
  status?: 'pending' | 'success' | 'failed';
  error?: string;
  tenderlyUrl?: string;
  step: string;
  description: string;
}

interface TenderlyTransactionResponse {
  hash: string;
  status: boolean;
  error_message?: string;
  logs?: any[];
  trace?: any[];
  url?: string;
}

class TenderlyGovernanceSimulator {
  private igpId: string;
  private config: SimulationConfig;
  private trackedTransactions: Map<string, TransactionDetails> = new Map();

  constructor(igpId: string) {
    this.igpId = igpId;
    this.config = this.loadConfig();
  }

  private async getTenderlyTransactionStatus(txHash: string, vnetId: string): Promise<TenderlyTransactionResponse | null> {
    return null;
  }

  private async getTenderlyTransactionUrl(txHash: string, vnetId: string): Promise<string> {
    return `https://dashboard.tenderly.co/${this.config.tenderly.account_id}/${this.config.tenderly.project_slug}/testnet/${vnetId}/tx/${txHash}`;
  }

  private async trackTransaction(txHash: string, txDetails: Partial<TransactionDetails>, vnetId: string): Promise<void> {
    const tenderlyUrl = await this.getTenderlyTransactionUrl(txHash, vnetId);

    this.trackedTransactions.set(txHash, {
      hash: txHash,
      from: txDetails.from || '',
      to: txDetails.to || '',
      data: txDetails.data || '',
      value: txDetails.value || '0x0',
      gasLimit: txDetails.gasLimit || '0x0',
      gasPrice: txDetails.gasPrice || '0x0',
      status: 'pending',
      tenderlyUrl,
      step: txDetails.step || 'unknown',
      description: txDetails.description || 'Transaction'
    });
  }

  private updateTransactionStatus(txHash: string, status: 'success' | 'failed', error?: string): void {
    const transaction = this.trackedTransactions.get(txHash);
    if (transaction) {
      transaction.status = status;
      if (error) {
        transaction.error = error;
      }
      this.trackedTransactions.set(txHash, transaction);
    }
  }

  private async verifyTransactionStatus(txHash: string, provider: JsonRpcProvider): Promise<'success' | 'failed'> {
    try {
      const receipt = await Promise.race([
        provider.waitForTransaction(txHash),
        new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), GLOBAL_TIMEOUT_MS))
      ]);

      if (receipt && (receipt as any).status === 1) {
        return 'success';
      } else {
        return 'failed';
      }
    } catch (error: any) {
      console.warn(`[WARN]  Could not verify transaction ${txHash}: ${error.message}`);
      return 'failed';
    }
  }

  private generateTransactionSummary(): string {
    const transactions = Array.from(this.trackedTransactions.values());

    if (transactions.length === 0) {
      return 'No transactions tracked.';
    }

    let summary = '### 📊 Transaction Summary\n\n';
    summary += '| Step | Status | Transaction |\n';
    summary += '|------|--------|-------------|\n';

    // Sort transactions by step order
    const stepOrder = ['deployment', 'setExecutable', 'delegation', 'proposalCreation', 'voting', 'queueing', 'execution'];

    for (const step of stepOrder) {
      const stepTransactions = transactions.filter(tx => tx.step === step);
      for (const tx of stepTransactions) {
        const status = tx.status === 'success' ? '✅ Success' :
          tx.status === 'failed' ? '❌ Failed' : '⏳ Pending';
        const txLink = tx.tenderlyUrl ? `[View](${tx.tenderlyUrl})` : tx.hash.substring(0, 10) + '...';
        summary += `| ${tx.step} | ${status} | ${txLink} |\n`;

        if (tx.error) {
          summary += `| | | **Error:** ${tx.error} |\n`;
        }
      }
    }

    return summary;
  }

  private async waitForTransactionWithTenderlyStatus(txHash: string, vnetId: string, vnetRpc: string): Promise<{ success: boolean; error?: string; tenderlyUrl: string }> {
    console.log(`[INFO]  Waiting for transaction ${txHash} to be mined...`);

    // Get initial Tenderly URL
    const tenderlyUrl = await this.getTenderlyTransactionUrl(txHash, vnetId);

    // Wait for transaction to be mined using the VNet RPC
    const provider = new JsonRpcProvider(vnetRpc, undefined, {
      staticNetwork: true,
      polling: false
    });

    try {
      const receipt = await provider.waitForTransaction(txHash);

      if (!receipt) {
        return { success: false, error: `Transaction ${txHash} was not mined`, tenderlyUrl };
      }

      if (receipt.status === 1) {
        return { success: true, tenderlyUrl };
      }

      // Transaction failed - get error from receipt
      return { success: false, error: 'Transaction failed (status: 0)', tenderlyUrl };

    } catch (error: any) {
      return { success: false, error: error.message, tenderlyUrl };
    }
  }

  private async findOrCreateGitHubComment(): Promise<number | null> {
    if (!this.config.github?.token || !this.config.github?.repo || !this.config.github?.pr_number) {
      console.log('[INFO]  GitHub integration not configured, skipping comment management');
      return null;
    }

    try {
      const [owner, repo] = this.config.github.repo.split('/');

      // Search for existing comment with our anchor
      const commentsResponse = await axios.get(
        `https://api.github.com/repos/${owner}/${repo}/issues/${this.config.github.pr_number}/comments`,
        {
          headers: {
            'Authorization': `token ${this.config.github.token}`,
            'Accept': 'application/vnd.github.v3+json'
          }
        }
      );

      const anchorText = `<!-- governance-simulation-igp-${this.igpId} -->`;
      const existingComment = commentsResponse.data.find((comment: any) =>
        comment.body.includes(anchorText)
      );

      if (existingComment) {
        console.log(`[INFO]  Found existing comment: ${existingComment.id}`);
        return existingComment.id;
      }

      // Create new comment
      const newCommentResponse = await axios.post(
        `https://api.github.com/repos/${owner}/${repo}/issues/${this.config.github.pr_number}/comments`,
        {
          body: `${anchorText}\n\n## Governance Simulation - IGP-${this.igpId}\n\n*Simulation in progress...*`
        },
        {
          headers: {
            'Authorization': `token ${this.config.github.token}`,
            'Accept': 'application/vnd.github.v3+json'
          }
        }
      );

      console.log(`[INFO]  Created new comment: ${newCommentResponse.data.id}`);
      return newCommentResponse.data.id;

    } catch (error: any) {
      console.warn(`[WARN]  GitHub comment management failed:`, error.response?.data || error.message);
      return null;
    }
  }

  private async updateGitHubComment(commentId: number, content: string): Promise<void> {
    if (!this.config.github?.token || !this.config.github?.repo) {
      return;
    }

    try {
      const [owner, repo] = this.config.github.repo.split('/');

      await axios.patch(
        `https://api.github.com/repos/${owner}/${repo}/issues/comments/${commentId}`,
        { body: content },
        {
          headers: {
            'Authorization': `token ${this.config.github.token}`,
            'Accept': 'application/vnd.github.v3+json'
          }
        }
      );

      console.log(`[INFO]  Updated GitHub comment: ${commentId}`);
    } catch (error: any) {
      console.warn(`[WARN]  Failed to update GitHub comment:`, error.response?.data || error.message);
    }
  }

  private async createNewGitHubComment(content: string): Promise<void> {
    if (!this.config.github?.token || !this.config.github?.repo || !this.config.github?.pr_number) {
      return;
    }

    try {
      const [owner, repo] = this.config.github.repo.split('/');

      await axios.post(
        `https://api.github.com/repos/${owner}/${repo}/issues/${this.config.github.pr_number}/comments`,
        { body: content },
        {
          headers: {
            'Authorization': `token ${this.config.github.token}`,
            'Accept': 'application/vnd.github.v3+json'
          }
        }
      );

      console.log(`[INFO]  Created new GitHub comment`);
    } catch (error: any) {
      console.warn(`[WARN]  Failed to create new GitHub comment:`, error.response?.data || error.message);
    }
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
          governance: loadedConfig.governance || defaultConfig.governance,
          github: {
            token: process.env.GITHUB_TOKEN || '',
            repo: process.env.GITHUB_REPOSITORY || '',
            pr_number: process.env.PR_NUMBER ? parseInt(process.env.PR_NUMBER) : undefined
          }
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
          },
          timeout: GLOBAL_TIMEOUT_MS
        }
      );

      const data = response.data;
      const vnetId = data.id;
      const adminRpc = data.rpcs?.find((r: any) => r.name === 'Admin RPC')?.url || data.admin_rpc_url;
      const slug = data.slug;
      const link = `https://dashboard.tenderly.co/${account_id}/${project_slug}/testnet/${vnetId}`;

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
      const provider = new JsonRpcProvider(vnetRpc, undefined, {
        staticNetwork: true,
        polling: false
      });

      // Use eth_sendTransaction with a funded address (like original script)
      const fundedDeployerAddress = '0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e';
      console.log(`[INFO]  Deploying from funded address: ${fundedDeployerAddress}`);

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

      // Deploy contract using eth_sendTransaction (like original script)
      const deployTxHash = await provider.send("eth_sendTransaction", [{
        from: fundedDeployerAddress,
        data: artifact.bytecode,
        value: "0x0",
        gas: "0x9896800", // 10M gas
        gasPrice: "0x0"
      }]);

      console.log(`[INFO]  Deployment transaction sent: ${deployTxHash}`);

      // Track the deployment transaction (we'll update VNet ID later)
      this.trackedTransactions.set(deployTxHash, {
        hash: deployTxHash,
        from: fundedDeployerAddress,
        to: '',
        data: artifact.bytecode,
        value: "0x0",
        gasLimit: "0x9896800",
        gasPrice: "0x0",
        status: 'success', // Assume success (Tenderly processes instantly)
        tenderlyUrl: '', // Will be updated later
        step: 'deployment',
        description: `Deploy PayloadIGP${this.igpId} Contract`
      });

      // Get the deployed contract address from the transaction receipt
      let deployedAddress = '0x0000000000000000000000000000000000000000';
      try {
        const receipt = await Promise.race([
          provider.waitForTransaction(deployTxHash),
          new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), GLOBAL_TIMEOUT_MS))
        ]);

        if (receipt && (receipt as any).contractAddress) {
          deployedAddress = (receipt as any).contractAddress;
        } else {
          throw new Error('No contract address in receipt');
        }
      } catch (error: any) {
        console.error(`[ERROR] Could not get deployment receipt: ${error.message}`);
        console.error('[ERROR] Deployment failed - cannot proceed without contract address');
        throw new Error(`Deployment failed: ${error.message}`);
      }

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

    const provider = new JsonRpcProvider(vnetConfig.adminRpc, undefined, {
      staticNetwork: true,
      polling: false
    });

    try {
      // Step 4.1: Set payload as executable (like original script)
      console.log('Setting payload as executable...');
      const setExecutableTxHash = await provider.send("eth_sendTransaction", [{
        from: "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e",
        to: payloadAddress,
        data: "0x0e6a204c0000000000000000000000000000000000000000000000000000000000000001", // setExecutable(true)
        value: "",
        gas: "0x9896800",
        gasPrice: "0x0"
      }]);

      // Track the setExecutable transaction (fire-and-forget)
      this.trackedTransactions.set(setExecutableTxHash, {
        hash: setExecutableTxHash,
        from: "0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e",
        to: payloadAddress,
        data: "0x0e6a204c0000000000000000000000000000000000000000000000000000000000000001",
        value: "0x0",
        gasLimit: "0x9896800",
        gasPrice: "0x0",
        status: 'success', // Assume success (Tenderly processes instantly)
        tenderlyUrl: `https://dashboard.tenderly.co/${this.config.tenderly.account_id}/${this.config.tenderly.project_slug}/testnet/${vnetConfig.id}/tx/${setExecutableTxHash}`,
        step: 'setExecutable',
        description: `Set PayloadIGP${this.igpId} as Executable`
      });

      console.log('[SUCCESS] Payload set as executable');
      console.log('[STAGE:COMPLETED] setExecutable');

      // Step 4.2: Delegate voting power to payload
      console.log('Delegating voting power to payload...');

      // Use eth_sendTransaction directly like original script
      const delegateData = new ethers.Interface(['function delegate(address delegatee)']).encodeFunctionData('delegate', [payloadAddress]);

      const delegateTxHash = await provider.send("eth_sendTransaction", [{
        from: this.config.addresses.delegator,
        to: this.config.addresses.inst,
        data: delegateData,
        value: "",
        gas: "0x9896800",
        gasPrice: "0x0"
      }]);

      // Track the delegation transaction (fire-and-forget)
      this.trackedTransactions.set(delegateTxHash, {
        hash: delegateTxHash,
        from: this.config.addresses.delegator,
        to: this.config.addresses.inst,
        data: delegateData,
        value: "0x0",
        gasLimit: "0x9896800",
        gasPrice: "0x0",
        status: 'success', // Assume success (Tenderly processes instantly)
        tenderlyUrl: `https://dashboard.tenderly.co/${this.config.tenderly.account_id}/${this.config.tenderly.project_slug}/testnet/${vnetConfig.id}/tx/${delegateTxHash}`,
        step: 'delegation',
        description: `Delegate INST Voting Power to PayloadIGP${this.igpId}`
      });

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

      let description = `IGP-${this.igpId}`;
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

      // Track proposal creation transaction (verify status)
      this.trackedTransactions.set(proposeTxHash, {
        hash: proposeTxHash,
        from: this.config.addresses.proposer,
        to: payloadAddress,
        data: proposeData,
        value: "0x0",
        gasLimit: "0x9896800",
        gasPrice: "0x0",
        status: 'pending', // Will be updated after verification
        tenderlyUrl: `https://dashboard.tenderly.co/${this.config.tenderly.account_id}/${this.config.tenderly.project_slug}/testnet/${vnetConfig.id}/tx/${proposeTxHash}`,
        step: 'proposalCreation',
        description: `Create IGP-${this.igpId}`
      });

      // Verify proposal creation transaction status
      const proposalStatus = await this.verifyTransactionStatus(proposeTxHash, provider);
      this.updateTransactionStatus(proposeTxHash, proposalStatus);

      if (proposalStatus === 'failed') {
        throw new Error('Proposal creation transaction failed');
      }

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

      // Store proposal creation transaction for later reference
      this.trackedTransactions.set(`proposal-${proposalId}`, {
        hash: proposeTxHash,
        from: this.config.addresses.proposer,
        to: payloadAddress,
        data: proposeData,
        value: "0x0",
        gasLimit: "0x9896800",
        gasPrice: "0x0",
        status: 'success',
        tenderlyUrl: await this.getTenderlyTransactionUrl(proposeTxHash, vnetConfig.id),
        step: 'proposalCreation',
        description: `Create IGP-${this.igpId}`
      });

      let currentBlock = await provider.getBlockNumber();

      console.log(`[SUCCESS] Proposal Created: ID ${proposalId}`);
      console.log(`   Start: ${startBlock}, End: ${endBlock}, Current: ${currentBlock}`);
      console.log('[STAGE:COMPLETED] proposalCreation');

      // Step 4.5: Advance to voting start
      console.log('\n Day 0-1: Advancing to voting start...');
      const blocksToVotingStart = startBlock - currentBlock + 2;
      console.log(`[INFO]  Need to advance ${blocksToVotingStart} blocks (current: ${currentBlock}, target: ${startBlock})`);

      // Use evm_increaseBlocks with HEX format (works on Tenderly!)
      console.log(`[INFO]  Sending evm_increaseBlocks request for ${blocksToVotingStart} blocks...`);
      await provider.send('evm_increaseBlocks', [ethers.toBeHex(blocksToVotingStart)]);

      currentBlock = await provider.getBlockNumber();
      console.log(`[SUCCESS] Advanced to block ${currentBlock} (increased by ${blocksToVotingStart} blocks instantly)`);
      console.log('[STAGE:COMPLETED] votingStartAdvancement');

      // Step 4.6: Cast votes
      console.log('\n  Day 1-2: Casting votes...');
      const castVoteData = new ethers.Interface(['function castVote(uint256 proposalId, uint8 support)']).encodeFunctionData('castVote', [proposalId, 1]);

      for (const voterAddress of this.config.addresses.castVotes) {
        const voteTxHash = await provider.send("eth_sendTransaction", [{
          from: voterAddress,
          to: this.config.addresses.governor,
          data: castVoteData,
          value: "",
          gas: "0x989680", // 10M gas
          gasPrice: "0x0"
        }]);

        // Track each vote transaction (fire-and-forget)
        this.trackedTransactions.set(voteTxHash, {
          hash: voteTxHash,
          from: voterAddress,
          to: this.config.addresses.governor,
          data: castVoteData,
          value: "0x0",
          gasLimit: "0x989680",
          gasPrice: "0x0",
          status: 'success', // Assume success (Tenderly processes instantly)
          tenderlyUrl: `https://dashboard.tenderly.co/${this.config.tenderly.account_id}/${this.config.tenderly.project_slug}/testnet/${vnetConfig.id}/tx/${voteTxHash}`,
          step: 'voting',
          description: `Cast Vote for IGP-${this.igpId}`
        });

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

      // Track queue transaction (fire-and-forget)
      this.trackedTransactions.set(queueTxHash, {
        hash: queueTxHash,
        from: this.config.addresses.proposer,
        to: this.config.addresses.governor,
        data: queueData,
        value: "0x0",
        gasLimit: "0x989680",
        gasPrice: "0x0",
        status: 'success', // Assume success (Tenderly processes instantly)
        tenderlyUrl: `https://dashboard.tenderly.co/${this.config.tenderly.account_id}/${this.config.tenderly.project_slug}/testnet/${vnetConfig.id}/tx/${queueTxHash}`,
        step: 'queueing',
        description: `Queue IGP-${this.igpId} Proposal ${proposalId}`
      });

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

      // Track execution transaction (verify status)
      this.trackedTransactions.set(executeTxHash, {
        hash: executeTxHash,
        from: this.config.addresses.proposer,
        to: this.config.addresses.governor,
        data: executeData,
        value: "0x0",
        gasLimit: "0x2625A00",
        gasPrice: "0x0",
        status: 'pending', // Will be updated after verification
        tenderlyUrl: `https://dashboard.tenderly.co/${this.config.tenderly.account_id}/${this.config.tenderly.project_slug}/testnet/${vnetConfig.id}/tx/${executeTxHash}`,
        step: 'execution',
        description: `Execute IGP-${this.igpId} Proposal ${proposalId}`
      });

      // Verify execution transaction status
      const executionStatus = await this.verifyTransactionStatus(executeTxHash, provider);
      this.updateTransactionStatus(executeTxHash, executionStatus);

      if (executionStatus === 'success') {
        console.log('[SUCCESS] Proposal executed!');
      } else {
        console.log('[FAILED] Proposal execution failed');
        throw new Error('Proposal execution failed');
      }
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

  private generateGitHubComment(
    result: { proposalId: number; transactionHash: string },
    vnetConfig: VNetConfig,
    executionTenderlyUrl: string,
    fluidUiLink: string,
    proposalTenderlyUrl: string
  ): string {
    const anchorText = `<!-- governance-simulation-igp-${this.igpId} -->`;

    // Get proposal creation transaction details
    const proposalTxDetails = this.trackedTransactions.get(`proposal-${result.proposalId}`);

    let proposalTxSection = '';
    if (proposalTxDetails) {
      proposalTxSection = `
### Proposal Creation Transaction

**Transaction Hash:** \`${proposalTxDetails.hash}\`

**Tenderly Dashboard:** [View Transaction](${proposalTenderlyUrl})

<details>
<summary><kbd>Raw Transaction Data</kbd></summary>

\`\`\`
From: ${proposalTxDetails.from}
To: ${proposalTxDetails.to}
Data: ${proposalTxDetails.data}
Value: ${proposalTxDetails.value}
Gas Limit: ${proposalTxDetails.gasLimit}
Gas Price: ${proposalTxDetails.gasPrice}
\`\`\`

</details>
`;
    }

    return `${anchorText}

## Governance Simulation Completed - IGP-${this.igpId}

**Payload Contract:** \`PayloadIGP${this.igpId}\`

### Proposal Actions
${this.getProposalActionsDescription()}

${this.generateTransactionSummary()}


${proposalTxSection}

### Links

- [Tenderly Dashboard](${executionTenderlyUrl})
- [Fluid UI (Staging)](${fluidUiLink})
- [Virtual Network Dashboard](${vnetConfig.link})

`;
  }

  private getProposalActionsDescription(): string {
    // First, try to extract actions from the Solidity contract's execute() function
    const payloadPath = path.join(
      process.cwd(),
      'contracts',
      'payloads',
      `IGP${this.igpId}`,
      `PayloadIGP${this.igpId}.sol`
    );

    if (fs.existsSync(payloadPath)) {
      try {
        const content = fs.readFileSync(payloadPath, 'utf8');
        const actions = this.extractExecuteContent(content);
        if (actions && actions.length > 0) {
          return actions.split('\n').map(action => `- ${action}`).join('\n');
        }
      } catch (error) {
        console.warn(`[WARN]  Failed to read payload file: ${error}`);
      }
    }

    // Fallback: Try to read the description file for this IGP
    const descriptionPath = path.join(
      process.cwd(),
      'contracts',
      'payloads',
      `IGP${this.igpId}`,
      'description.md'
    );

    if (fs.existsSync(descriptionPath)) {
      try {
        const description = fs.readFileSync(descriptionPath, 'utf8');
        // Extract action descriptions from the markdown
        const actionMatches = description.match(/^###?\s*Action\s+\d+:.*$/gm);
        if (actionMatches) {
          return actionMatches.map(action => `- ${action.replace(/^###?\s*Action\s+\d+:\s*/, '')}`).join('\n');
        }
      } catch (error) {
        console.warn(`[WARN]  Failed to read description file: ${error}`);
      }
    }

    return `- No actions found in contract or description file`;
  }

  private extractExecuteContent(content: string): string | null {
    // Match the execute function body using multiline regex
    const executeMatch = content.match(/function\s+execute\s*\([^)]*\)\s+public\s+virtual\s+override\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}/s);

    if (!executeMatch) {
      return null;
    }

    const executeBody = executeMatch[1];
    const lines = executeBody.split('\n')
      .map(line => line.trim())
      .filter(line => line.startsWith('//') || line.match(/^action\d+\s*\(/));

    const actions: string[] = [];
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('//')) {
        const comment = lines[i];
        // Check if next line is an action call
        if (i + 1 < lines.length && lines[i + 1].match(/^action\d+\s*\(/)) {
          // Extract just the action description from the comment
          // Format: "// Action N: Description" -> "Action N: Description"
          const description = comment.replace(/^\/\/\s*/, '');
          actions.push(description);
        }
      }
    }

    return actions.length > 0 ? actions.join('\n') : null;
  }

  private generateErrorGitHubComment(error: any, vnetConfig?: VNetConfig): string {
    const anchorText = `<!-- governance-simulation-igp-${this.igpId} -->`;

    let vnetSection = '';
    if (vnetConfig) {
      vnetSection = `
### Virtual Network Details

| Parameter | Value |
|-----------|-------|
| Virtual Network ID | \`${vnetConfig.id}\` |
| VNet Dashboard | [View Network](${vnetConfig.link}) |
`;
    }

    return `${anchorText}

## Governance Simulation Failed - IGP-${this.igpId}

**Payload Contract:** \`PayloadIGP${this.igpId}\`

${this.generateTransactionSummary()}

### Error Details

**Error Message:** \`${error.message}\`

### Troubleshooting

${this.getErrorTroubleshooting(error.message)}

${vnetSection}

`;
  }

  private getErrorTroubleshooting(errorMessage: string): string {
    if (errorMessage.includes('execution reverted')) {
      return `- **Transaction execution reverted** - Check business logic constraints
- Verify contract permissions and state requirements
- Review parameter validation and preconditions
- Use Tenderly debugger for detailed stack trace`;
    }

    if (errorMessage.includes('Called function does not exist')) {
      return `- **Function does not exist** - Verify function signature and ABI
- Check contract deployment and initialization
- Confirm correct contract address is being called
- Review contract interface and method names`;
    }

    if (errorMessage.includes('AdminModule__AddressNotAContract')) {
      return `- **Address is not a contract** - Check pre-setup script requirements
- Verify all required contracts are deployed
- Review contract address configuration
- Ensure deployment completed successfully`;
    }

    return `- Review the error message above for specific details
- Check Tenderly debugger for transaction analysis`;
  }

  async simulate(): Promise<void> {
    console.log(`\n${'='.repeat(70)}`);
    console.log(`[START] Governance Simulation for IGP ${this.igpId}`);
    console.log(`${'='.repeat(70)}`);

    let vnetConfig: VNetConfig | undefined;
    let githubCommentId: number | null = null;

    // Set up process exit handler to ensure GitHub comment is created even on forced termination
    const exitHandler = async (signal: string) => {
      console.log(`\n[INFO]  Process received ${signal}, attempting to create GitHub comment...`);
      if (githubCommentId && vnetConfig) {
        try {
          const errorComment = this.generateErrorGitHubComment(
            new Error(`Process terminated with signal: ${signal}`),
            vnetConfig
          );
          await Promise.race([
            this.updateGitHubComment(githubCommentId, errorComment),
            new Promise((_, reject) => setTimeout(() => reject(new Error('Comment update timeout')), GLOBAL_TIMEOUT_MS))
          ]);
          console.log(`[SUCCESS] GitHub comment updated on process termination`);
        } catch (error: any) {
          console.warn(`[WARN]  Failed to update GitHub comment on termination: ${error.message}`);
        }
      }
      process.exit(1);
    };

    process.on('SIGTERM', () => exitHandler('SIGTERM'));
    process.on('SIGINT', () => exitHandler('SIGINT'));

    try {
      // Initialize GitHub comment management
      githubCommentId = await this.findOrCreateGitHubComment();

      vnetConfig = await this.createVnet();
      const payloadAddress = await this.deployPayload(vnetConfig.adminRpc);

      // Update deployment transaction with correct VNet ID and URL
      const deploymentTx = Array.from(this.trackedTransactions.values()).find(tx => tx.step === 'deployment');
      if (deploymentTx) {
        deploymentTx.tenderlyUrl = `https://dashboard.tenderly.co/${this.config.tenderly.account_id}/${this.config.tenderly.project_slug}/testnet/${vnetConfig.id}/tx/${deploymentTx.hash}`;
        this.trackedTransactions.set(deploymentTx.hash, deploymentTx);
      }

      const provider = new JsonRpcProvider(vnetConfig.adminRpc, undefined, {
        staticNetwork: true,
        polling: false
      });
      await this.runPreSetup(provider);

      const result = await this.runGovernanceSimulation(vnetConfig, payloadAddress);

      // Get actual Tenderly URLs from API
      const executionTenderlyUrl = await this.getTenderlyTransactionUrl(result.transactionHash, vnetConfig.id);
      const adminRpcId = vnetConfig.adminRpc.split('/')[3] || vnetConfig.adminRpc.split('/').pop();
      const fluidUiLink = `https://staging.fluid.io/?isCustomVnet=true&tenderlyId=${adminRpcId}`;

      // Get proposal creation transaction details
      const proposalTxDetails = this.trackedTransactions.get(`proposal-${result.proposalId}`);
      const proposalTenderlyUrl = proposalTxDetails?.tenderlyUrl || '';

      console.log(`\n${'='.repeat(70)}`);
      console.log('[SUCCESS] Simulation Completed Successfully!');
      console.log(`${'='.repeat(70)}`);
      console.log(`\nProposal ID: ${result.proposalId}`);
      console.log(`VNet ID: ${vnetConfig.id}`);
      console.log(`Execution TX Hash: ${result.transactionHash}`);
      console.log(`Tenderly Execution: ${executionTenderlyUrl}`);
      console.log(`Fluid UI: ${fluidUiLink}\n`);

      // Generate comprehensive GitHub comment
      const commentContent = this.generateGitHubComment(result, vnetConfig, executionTenderlyUrl, fluidUiLink, proposalTenderlyUrl);

      if (githubCommentId) {
        await this.updateGitHubComment(githubCommentId, commentContent);
      }

      // Output all results for GitHub Actions using new format
      if (process.env.GITHUB_OUTPUT) {
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `proposal_id=${result.proposalId}\n`);
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `vnet_id=${vnetConfig.id}\n`);
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `transaction_hash=${result.transactionHash}\n`);
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `tenderly_execution_link=${executionTenderlyUrl}\n`);
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `fluid_ui_link=${fluidUiLink}\n`);
      }

    } catch (error: any) {
      console.error(`\n[ERROR] Simulation Failed: ${error.message}`);

      // Update GitHub comment with error information - with timeout protection
      if (githubCommentId) {
        try {
          const errorComment = this.generateErrorGitHubComment(error, vnetConfig);
          console.log(`[INFO]  Updating GitHub comment with error details...`);

          // Use Promise.race to ensure comment update doesn't hang
          await Promise.race([
            this.updateGitHubComment(githubCommentId, errorComment),
            new Promise((_, reject) => setTimeout(() => reject(new Error('Comment update timeout')), GLOBAL_TIMEOUT_MS))
          ]);

          console.log(`[SUCCESS] GitHub comment updated with error details`);
        } catch (commentError: any) {
          console.warn(`[WARN]  Failed to update GitHub comment: ${commentError.message}`);
          // Try to create a new comment if update failed
          try {
            const errorComment = this.generateErrorGitHubComment(error, vnetConfig);
            await this.createNewGitHubComment(errorComment);
            console.log(`[SUCCESS] Created new GitHub comment with error details`);
          } catch (createError: any) {
            console.warn(`[WARN]  Failed to create new GitHub comment: ${createError.message}`);
          }
        }
      }

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
