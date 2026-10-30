/**
 * Pre-Setup Script for IGP142 Payload Simulation
 *
 * Action 13 switches the osETH vaults to OracleV2 oracles. `updateOracle`
 * probes the new oracle's operate and liquidate rates, and the OracleV2 price
 * sources reject stale feed rounds. The simulation warps past the voting
 * period and the timelock delay, so every live feed is stale by then and the
 * probe reverts with UsdOracle__RateZero (310007).
 *
 * This script replaces the Chainlink / RedStone feeds the six new oracles
 * read with a mock that returns the live answer with `updatedAt =
 * block.timestamp`.
 */

import { JsonRpcProvider, ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

const FEEDS: Record<string, string> = {
  CL_ETH_USD: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
  CL_STETH_ETH: "0x86392dC19c0b719886221c78AB11eb8Cf5c52812",
  CL_USDC_USD: "0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6",
  CL_USDT_USD: "0x3E7d1eAB13ad0104d2750B8863b489D65364e32D",
  CL_GHO_USD: "0x3f12643D3f6f874d39C2a4c9f2Cd6f2DbAC877FC",
  RS_ETH_USD: "0x67F6838e58859d612E4ddF04dA396d6DABB66Dc4",
  RS_USDC_USD: "0xeeF31c7d9F2E82e8A497b140cc60cc082Be4b94e",
  RS_USDT_USD: "0x02E1F8d15762047b7a87BA0E5d94B9a0c5b54Ed2",
  RS_WSTETH_USD: "0xe4aE88743c3834d0c492eAbC47384c84BcADC6a6",
};

const FEED_ABI = new ethers.Interface([
  "function latestRoundData() view returns (uint80,int256,uint256,uint256,uint80)",
  "function decimals() view returns (uint8)",
]);

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
  if (typeof raw !== "string" || raw.length === 0) {
    throw new Error(`${artifactPath} has no deployedBytecode`);
  }
  return raw.startsWith("0x") ? raw : `0x${raw}`;
}

async function call(
  provider: JsonRpcProvider,
  to: string,
  data: string,
): Promise<string> {
  return provider.send("eth_call", [{ to, data }, "latest"]);
}

async function mockFeed(
  provider: JsonRpcProvider,
  name: string,
  feed: string,
  bytecode: string,
): Promise<void> {
  const round = FEED_ABI.decodeFunctionResult(
    "latestRoundData",
    await call(provider, feed, FEED_ABI.encodeFunctionData("latestRoundData")),
  );
  const decimals = FEED_ABI.decodeFunctionResult(
    "decimals",
    await call(provider, feed, FEED_ABI.encodeFunctionData("decimals")),
  )[0];
  const answer: bigint = round[1];
  if (answer <= 0n) {
    throw new Error(`${name} (${feed}) has a non-positive live answer`);
  }

  await provider.send("tenderly_setCode", [feed, bytecode]);
  const word = (v: bigint) => ethers.toBeHex(v, 32);
  await provider.send("tenderly_setStorageAt", [feed, word(0n), word(answer)]);
  await provider.send("tenderly_setStorageAt", [
    feed,
    word(1n),
    word(BigInt(decimals)),
  ]);
  console.log(`[SETUP] Mocked ${name} (${feed}): answer=${answer}, decimals=${decimals}`);
}

export async function preSetup(
  provider: JsonRpcProvider,
  _payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP142...");
  try {
    const bytecode = readArtifactBytecode(
      "artifacts/contracts/payloads/IGP142/simulation/MockPriceFeed.sol/MockPriceFeed.json",
    );
    for (const [name, feed] of Object.entries(FEEDS)) {
      await mockFeed(provider, name, feed, bytecode);
    }
    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[SETUP] Pre-setup failed:", message);
    throw error;
  }
}

export default preSetup;
