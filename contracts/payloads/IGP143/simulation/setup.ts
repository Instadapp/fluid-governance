import { JsonRpcProvider, ethers } from "ethers";

const FLUID_RESERVE = "0x264786EF916af64a1DB19F513F24a3681734ce92";

// Action 3 grant amounts: assumed to be in the Reserve at execution.
const RESERVE_FUNDING: { symbol: string; token: string; amount: bigint }[] = [
  {
    symbol: "USDC",
    token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    amount: 150_000n * 10n ** 6n,
  },
  {
    symbol: "USDT",
    token: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    amount: 150_000n * 10n ** 6n,
  },
  {
    symbol: "GHO",
    token: "0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f",
    amount: 50_000n * 10n ** 18n,
  },
];

async function erc20Balance(
  provider: JsonRpcProvider,
  token: string,
  holder: string,
): Promise<bigint> {
  const data = new ethers.Interface([
    "function balanceOf(address) view returns (uint256)",
  ]).encodeFunctionData("balanceOf", [holder]);
  return BigInt(await provider.send("eth_call", [{ to: token, data }, "latest"]));
}

async function fundReserve(provider: JsonRpcProvider): Promise<void> {
  for (const { symbol, token, amount } of RESERVE_FUNDING) {
    const balance = await erc20Balance(provider, token, FLUID_RESERVE);
    if (balance >= amount) {
      console.log(`[SETUP] Reserve already holds enough ${symbol}`);
      continue;
    }

    await provider.send("tenderly_setErc20Balance", [
      token,
      FLUID_RESERVE,
      ethers.toBeHex(amount),
    ]);

    const after = await erc20Balance(provider, token, FLUID_RESERVE);
    if (after < amount) {
      throw new Error(`Reserve ${symbol} funding failed: balance ${after}`);
    }
    console.log(`[SETUP] Reserve ${symbol} balance set to ${after}`);
  }
}

export async function preSetup(
  provider: JsonRpcProvider,
  _payloadAddress?: string,
): Promise<void> {
  console.log("[SETUP] Running pre-setup for IGP143...");

  try {
    await fundReserve(provider);
    console.log("[SETUP] Pre-setup completed successfully");
  } catch (error: any) {
    console.error("[SETUP] Pre-setup failed:", error.message);
    throw error;
  }
}

export default preSetup;
