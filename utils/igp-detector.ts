import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';

export interface SimulationConfig {
  global: any;
  tenderly: any;
  fluid: any;
  simulation: any;
  vnet: any;
  github: any;
}

export class IGPDetector {
  private config: SimulationConfig;

  constructor(configPath: string = './config/simulation-config.yml') {
    this.config = this.loadConfig(configPath);
  }

  private loadConfig(configPath: string): SimulationConfig {
    try {
      const configContent = fs.readFileSync(configPath, 'utf8');
      return yaml.load(configContent) as SimulationConfig;
    } catch (error) {
      throw new Error(`Failed to load config from ${configPath}: ${error}`);
    }
  }

  public extractIGPNumber(title: string): string | null {
    // Match patterns: IGP 110, IGP-110, IGP_110, igp 110, etc.
    const patterns = [
      /IGP[\s_-]?(\d+)/i,
      /igp[\s_-]?(\d+)/i,
      /Governance[\s_-]?Proposal[\s_-]?(\d+)/i
    ];

    for (const pattern of patterns) {
      const match = title.match(pattern);
      if (match && match[1]) {
        return `igp-${match[1]}`;
      }
    }

    return null;
  }

  public validateIGPStructure(igpNumber: string): boolean {
    const igpPath = path.join('src', igpNumber);

    if (!fs.existsSync(igpPath)) {
      console.warn(`IGP folder not found: ${igpPath}`);
      return false;
    }

    const requiredPaths = [
      path.join(igpPath, 'simulation'),
      path.join(igpPath, 'payloads')
    ];

    for (const requiredPath of requiredPaths) {
      if (!fs.existsSync(requiredPath)) {
        console.warn(`Required path not found: ${requiredPath}`);
        return false;
      }
    }

    return true;
  }

  public getSetupScriptPath(igpNumber: string): string | null {
    // Check for setup script in IGP folder
    const defaultPath = path.join('src', igpNumber, 'simulation', 'setup.ts');
    return fs.existsSync(defaultPath) ? defaultPath : null;
  }

  public getPayloadContractPath(igpNumber: string): string | null {
    // Check for payload contract in IGP folder
    const defaultPath = path.join('src', igpNumber, 'payloads', 'Payload.sol');
    return fs.existsSync(defaultPath) ? defaultPath : null;
  }

  public getGlobalConfig() {
    return this.config.global;
  }

  public getTenderlyConfig() {
    return this.config.tenderly;
  }

  public getFluidConfig() {
    return this.config.fluid;
  }

  public getSimulationParams() {
    return this.config.simulation;
  }

  public getGitHubConfig() {
    return this.config.github;
  }
}