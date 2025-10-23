#!/usr/bin/env ts-node

/// IGP Validator
/// 
/// Validates Insta Governance Proposal (IGP) structure and content.
/// 
/// Key Validations:
/// 1. IGP Sequence: Ensures new IGP is exactly +1 from latest IGP in system
/// 2. Contract Structure: Validates contract name matches PayloadIGP{N} pattern
/// 3. Execute Function: Verifies presence of execute() with proper signature
/// 4. Action Count: Requires minimum 1 numbered action in execute()
/// 5. Action Format: Validates "// Action N: Description" format
/// 
/// Outputs:
/// - Validation status (pass/fail)
/// - Execute function content (action comments) for PR description
/// - Errors and warnings
/// 
/// Usage:
///   npx ts-node utils/igp-validator.ts --id=<igp-number>
///   node --loader ts-node/esm utils/igp-validator.ts --id=<igp-number>

import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
  igpId: string;
  payloadPath?: string;
  ignitionPath?: string;
  executeContent?: string;
  actionsSummary?: string;
}

interface IGPRequirements {
  payloadRequired: boolean;
  ignitionRequired: boolean;
  descriptionRequired: boolean;
  setupScriptOptional: boolean;
}

const DEFAULT_REQUIREMENTS: IGPRequirements = {
  payloadRequired: true,
  ignitionRequired: false,
  descriptionRequired: false,
  setupScriptOptional: true
};

export class IGPValidator {
  private igpId: string;
  private requirements: IGPRequirements;

  constructor(igpId: string, requirements: IGPRequirements = DEFAULT_REQUIREMENTS) {
    this.igpId = igpId;
    this.requirements = requirements;
  }

  validate(): ValidationResult {
    const result: ValidationResult = {
      valid: true,
      errors: [],
      warnings: [],
      igpId: this.igpId
    };

    this.validateIGPSequence(result);

    const standardPath = path.join(process.cwd(), 'contracts', 'payloads', `IGP${this.igpId}`);
    const customPath = path.join(process.cwd(), 'contracts', 'payloads', `igp-${this.igpId}`);

    let baseDir: string | null = null;
    if (fs.existsSync(standardPath)) {
      baseDir = standardPath;
    } else if (fs.existsSync(customPath)) {
      baseDir = customPath;
    }

    if (!baseDir) {
      result.valid = false;
      result.errors.push(`IGP directory not found. Expected one of:\n  - ${standardPath}\n  - ${customPath}`);
      return result;
    }

    this.validatePayload(baseDir, result);
    this.validateIgnition(result);
    this.validateDescription(baseDir, result);
    this.checkOptionalFiles(baseDir, result);

    result.valid = result.errors.length === 0;
    return result;
  }

  private getLatestIGPNumber(): number {
    const payloadsDir = path.join(process.cwd(), 'contracts', 'payloads');

    if (!fs.existsSync(payloadsDir)) {
      return 0;
    }

    const entries = fs.readdirSync(payloadsDir, { withFileTypes: true });
    const currentIGP = parseInt(this.igpId, 10);
    let maxIGP = 0;

    for (const entry of entries) {
      if (entry.isDirectory()) {
        const match = entry.name.match(/^IGP(\d+)$/i);
        if (match) {
          const igpNum = parseInt(match[1], 10);
          // Ignore the current IGP being validated when determining latest
          if (igpNum > maxIGP && igpNum !== currentIGP) {
            maxIGP = igpNum;
          }
        }
      }
    }

    return maxIGP;
  }

  private validateIGPSequence(result: ValidationResult): void {
    const currentIGP = parseInt(this.igpId, 10);
    const latestIGP = this.getLatestIGPNumber();

    if (currentIGP <= latestIGP) {
      const expectedIGP = latestIGP + 1;
      result.errors.push(
        `IGP sequence validation failed:\n` +
        `  - Current IGP: ${currentIGP}\n` +
        `  - Latest IGP in system: ${latestIGP}\n` +
        `  - Expected next IGP: ${expectedIGP}\n` +
        `  - New IGP must be exactly +1 from the latest IGP`
      );
    } else if (currentIGP > latestIGP + 1) {
      result.warnings.push(
        `IGP number ${currentIGP} skips ahead from latest IGP ${latestIGP}. Expected ${latestIGP + 1}.`
      );
    }
  }

  private extractExecuteContent(content: string): string | null {
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
        if (i + 1 < lines.length && lines[i + 1].match(/^action\d+\s*\(/)) {
          actions.push(comment);
        }
      }
    }

    return actions.join('\n');
  }

  private validateContractStructure(content: string, result: ValidationResult): void {
    const expectedContractName = `PayloadIGP${this.igpId}`;
    const contractMatch = content.match(/contract\s+(\w+)/);

    if (!contractMatch) {
      result.errors.push('No contract definition found in payload file');
      return;
    }

    const actualContractName = contractMatch[1];
    if (actualContractName !== expectedContractName) {
      result.errors.push(
        `Contract name mismatch:\n` +
        `  - Expected: ${expectedContractName}\n` +
        `  - Found: ${actualContractName}`
      );
    }

    const executeMatch = content.match(/function\s+execute\s*\([^)]*\)\s+public\s+virtual\s+override/);
    if (!executeMatch) {
      result.errors.push('Contract must have an execute() function with "public virtual override" modifiers');
      return;
    }

    const actionMatches = content.match(/\/\/\s*Action\s+\d+:/gi);
    const actionCount = actionMatches ? actionMatches.length : 0;

    if (actionCount < 1) {
      result.errors.push(
        `Contract must have at least 1 numbered action in execute() function.\n` +
        `  - Found: ${actionCount} action(s)\n` +
        `  - Required: minimum 1 action\n` +
        `  - Format: "// Action 1: Description" followed by "action1();"`
      );
    }

    const executeContent = this.extractExecuteContent(content);
    if (executeContent) {
      result.executeContent = executeContent;
      result.actionsSummary = `Found ${actionCount} action(s) in execute function`;
    }
  }

  private validatePayload(baseDir: string, result: ValidationResult): void {
    const payloadFileName = `PayloadIGP${this.igpId}.sol`;
    const payloadPath = path.join(baseDir, payloadFileName);
    const altPayloadPath = path.join(baseDir, 'payloads', 'Payload.sol');

    if (fs.existsSync(payloadPath)) {
      result.payloadPath = payloadPath;
      this.validatePayloadContent(payloadPath, result);
    } else if (fs.existsSync(altPayloadPath)) {
      result.payloadPath = altPayloadPath;
      this.validatePayloadContent(altPayloadPath, result);
    } else if (this.requirements.payloadRequired) {
      result.errors.push(`Payload contract not found. Expected:\n  - ${payloadPath}\n  - ${altPayloadPath}`);
    }
  }

  private validatePayloadContent(payloadPath: string, result: ValidationResult): void {
    try {
      const content = fs.readFileSync(payloadPath, 'utf8');

      this.validateContractStructure(content, result);

      const constructorMatch = content.match(/constructor\s*\([^)]*\)/);
      if (constructorMatch && constructorMatch[0] !== 'constructor()') {
        result.warnings.push('Payload constructor has parameters. Ensure Ignition module handles deployment args.');
      }

    } catch (error) {
      result.errors.push(`Failed to read payload: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private validateIgnition(result: ValidationResult): void {
    const ignitionPath = path.join(
      process.cwd(),
      'ignition',
      'modules',
      `PayloadIGP${this.igpId}.ts`
    );

    if (fs.existsSync(ignitionPath)) {
      result.ignitionPath = ignitionPath;
      this.validateIgnitionContent(ignitionPath, result);
    } else if (this.requirements.ignitionRequired) {
      result.errors.push(`Ignition module not found: ${ignitionPath}`);
    } else {
      result.warnings.push(`No Ignition module found. Deployment will use direct ethers.js.`);
    }
  }

  private validateIgnitionContent(ignitionPath: string, result: ValidationResult): void {
    try {
      const content = fs.readFileSync(ignitionPath, 'utf8');

      if (!content.includes('buildModule')) {
        result.errors.push('Ignition module must use buildModule()');
      }

      if (!content.includes(`PayloadIGP${this.igpId}`)) {
        result.warnings.push(`Ignition module may not reference PayloadIGP${this.igpId} contract`);
      }

    } catch (error) {
      result.errors.push(`Failed to read Ignition module: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private validateDescription(baseDir: string, result: ValidationResult): void {
    const descPath = path.join(baseDir, 'description.md');

    if (fs.existsSync(descPath)) {
      try {
        const content = fs.readFileSync(descPath, 'utf8');
        if (content.trim().length === 0) {
          result.warnings.push('description.md is empty');
        }
      } catch (error) {
        result.warnings.push(`Failed to read description.md: ${error instanceof Error ? error.message : String(error)}`);
      }
    } else if (this.requirements.descriptionRequired) {
      result.errors.push(`description.md not found in ${baseDir}`);
    }
  }

  private checkOptionalFiles(baseDir: string, result: ValidationResult): void {
    const setupPath = path.join(baseDir, 'simulation', 'setup.ts');
    if (fs.existsSync(setupPath)) {
      result.warnings.push('Pre-setup script found (simulation/setup.ts). Will be executed before governance flow.');
    }

    const testPath = path.join(baseDir, 'test');
    if (fs.existsSync(testPath)) {
      result.warnings.push('Test directory found. Consider running tests before PR submission.');
    }
  }

  static validateFromArgs(args: string[]): ValidationResult | null {
    let igpId = '';

    for (const arg of args) {
      if (arg.startsWith('--id=')) {
        igpId = arg.split('=')[1].replace('igp-', '').replace('IGP', '');
      }
    }

    if (!igpId) {
      return null;
    }

    const validator = new IGPValidator(igpId);
    return validator.validate();
  }
}

async function main() {
  const args = process.argv.slice(2);
  const jsonOutput = args.includes('--json');
  const result = IGPValidator.validateFromArgs(args);

  if (!result) {
    if (jsonOutput) {
      console.log(JSON.stringify({ error: 'IGP ID required' }));
    } else {
      console.error('[ERROR] IGP ID required');
      console.error('\nUsage: npx ts-node utils/igp-validator.ts --id=<igp-id> [--json]');
      console.error('Example: npx ts-node utils/igp-validator.ts --id=111');
    }
    process.exit(1);
  }

  if (jsonOutput) {
    console.log(JSON.stringify(result, null, 2));
    process.exit(result.valid ? 0 : 1);
  }

  console.log(`\n${'='.repeat(70)}`);
  console.log(`IGP ${result.igpId} Validation Results`);
  console.log(`${'='.repeat(70)}\n`);

  if (result.payloadPath) {
    console.log(`[FOUND] Payload: ${result.payloadPath}`);
  }

  if (result.ignitionPath) {
    console.log(`[FOUND] Ignition: ${result.ignitionPath}`);
  }

  if (result.actionsSummary) {
    console.log(`[INFO] ${result.actionsSummary}`);
  }

  if (result.executeContent) {
    console.log(`\n[EXECUTE_CONTENT]`);
    console.log(result.executeContent);
  }

  if (result.warnings.length > 0) {
    console.log(`\n[WARNINGS] ${result.warnings.length} warning(s):`);
    result.warnings.forEach((w, i) => console.log(`  ${i + 1}. ${w}`));
  }

  if (result.errors.length > 0) {
    console.log(`\n[ERRORS] ${result.errors.length} error(s):`);
    result.errors.forEach((e, i) => console.log(`  ${i + 1}. ${e}`));
  }

  if (result.valid) {
    console.log(`\n[SUCCESS] IGP ${result.igpId} passed all validation checks\n`);
    process.exit(0);
  } else {
    console.log(`\n[FAILED] IGP ${result.igpId} failed validation\n`);
    process.exit(1);
  }
}

// ESM entry point check
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error('[FATAL] Validation error:', error);
    process.exit(1);
  });
}

export default IGPValidator;

