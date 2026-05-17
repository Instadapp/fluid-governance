pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {LiquidityCalcs} from "../libraries/liquidityCalcs.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";

import {PayloadIGPMain} from "./main.sol";

/**
 * @notice Invariant dispatch for `getRawAmount` used by the off-chain
 * simulator / UI.
 *
 * Design goals:
 *   - Keep future payload bodies minimal: they inherit this contract and
 *     override ONLY the per-token price getters for tokens they touch.
 *   - Keep this file invariant across IGPs — it changes only when the token
 *     universe itself changes (new tokens added / old tokens retired). The
 *     dispatch never encodes a price; it dispatches token → virtual getter.
 *   - Fail loudly. Every price getter reverts by default; a payload that
 *     forgets to override a getter it needs will revert at simulator time
 *     with a clearly-labelled error, never with a silent zero.
 *
 * Pricing convention (unchanged from historical payloads):
 *   - Each `<SYMBOL>_USD_PRICE()` returns the USD price of one whole token,
 *     scaled by `1e2` (two decimal places). E.g. `$2_000` → `2_000 * 1e2`.
 *   - `decimals` is each token's own ERC-20 decimals.
 *   - Returned raw amount is denominated in the token's Liquidity exchange
 *     accounting (`amount * 1e12 / exchangePrice`).
 *
 * How a future payload uses this:
 *
 *     contract PayloadIGP129 is PayloadIGPPriceHelpers {
 *         // ...actions...
 *
 *         // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
 *         // fetched: <iso>, source: coingecko
 *         function ETH_USD_PRICE()    public pure override returns (uint256) { return 2_000 * 1e2; }
 *         function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
 *         function BTC_USD_PRICE()    public pure override returns (uint256) { return 69_000 * 1e2; }
 *         // --- END AUTO-GENERATED PRICES ---
 *     }
 *
 * The script emits one override per *distinct* priceVar the payload
 * actually references, and nothing else.
 */
abstract contract PayloadIGPPriceHelpers is PayloadIGPMain {
    // -----------------------------------------------------------------
    // Token → (priceGetter, decimals) dispatch + shared conversion math.
    // -----------------------------------------------------------------
    function getRawAmount(
        address token,
        uint256 amount,
        uint256 amountInUSD,
        bool isSupply
    ) public view override returns (uint256) {
        if (amount > 0 && amountInUSD > 0) {
            revert("both usd and amount are not zero");
        }

        uint256 usdPrice;
        uint256 decimals;

        // ETH + ETH-correlated LSTs / LRTs ------------------------------
        if (token == ETH_ADDRESS) {
            usdPrice = ETH_USD_PRICE();
            decimals = 18;
        } else if (token == wstETH_ADDRESS) {
            usdPrice = wstETH_USD_PRICE();
            decimals = 18;
        } else if (token == weETH_ADDRESS) {
            usdPrice = weETH_USD_PRICE();
            decimals = 18;
        } else if (token == rsETH_ADDRESS) {
            usdPrice = rsETH_USD_PRICE();
            decimals = 18;
        } else if (token == weETHs_ADDRESS) {
            usdPrice = weETHs_USD_PRICE();
            decimals = 18;
        } else if (token == mETH_ADDRESS) {
            usdPrice = mETH_USD_PRICE();
            decimals = 18;
        } else if (token == ezETH_ADDRESS) {
            usdPrice = ezETH_USD_PRICE();
            decimals = 18;
        } else if (token == OSETH_ADDRESS) {
            usdPrice = OSETH_USD_PRICE();
            decimals = 18;

            // BTC family ----------------------------------------------------
        } else if (token == WBTC_ADDRESS) {
            usdPrice = BTC_USD_PRICE();
            decimals = 8;
        } else if (token == cbBTC_ADDRESS) {
            usdPrice = BTC_USD_PRICE();
            decimals = 8;
        } else if (token == tBTC_ADDRESS) {
            usdPrice = BTC_USD_PRICE();
            decimals = 18;
        } else if (token == eBTC_ADDRESS) {
            usdPrice = BTC_USD_PRICE();
            decimals = 8;
        } else if (token == lBTC_ADDRESS) {
            usdPrice = BTC_USD_PRICE();
            decimals = 8;

            // $1-pegged stables --------------------------------------------
        } else if (token == USDC_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 6;
        } else if (token == USDT_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 6;
        } else if (token == GHO_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 18;
        } else if (token == USDe_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 18;
        } else if (token == deUSD_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 18;
        } else if (token == USR_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 18;
        } else if (token == USD0_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 18;
        } else if (token == fxUSD_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 18;
        } else if (token == BOLD_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 18;
        } else if (token == iUSD_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 18;
        } else if (token == USDTb_ADDRESS) {
            usdPrice = STABLE_USD_PRICE();
            decimals = 18;

            // Yield-bearing stables ----------------------------------------
        } else if (token == sUSDe_ADDRESS) {
            usdPrice = sUSDe_USD_PRICE();
            decimals = 18;
        } else if (token == sUSDs_ADDRESS) {
            usdPrice = sUSDs_USD_PRICE();
            decimals = 18;
        } else if (token == syrupUSDT_ADDRESS) {
            usdPrice = syrupUSDT_USD_PRICE();
            decimals = 6;
        } else if (token == syrupUSDC_ADDRESS) {
            usdPrice = syrupUSDC_USD_PRICE();
            decimals = 6;
        } else if (token == REUSD_ADDRESS) {
            usdPrice = REUSD_USD_PRICE();
            decimals = 18;
        } else if (token == csUSDL_ADDRESS) {
            usdPrice = csUSDL_USD_PRICE();
            decimals = 18;
        } else if (token == JRUSDE_ADDRESS) {
            usdPrice = JRUSDE_USD_PRICE();
            decimals = 18;
        } else if (token == SRUSDE_ADDRESS) {
            usdPrice = SRUSDE_USD_PRICE();
            decimals = 18;
        } else if (token == wstUSR_ADDRESS) {
            usdPrice = wstUSR_USD_PRICE();
            decimals = 18;
        } else if (token == RLP_ADDRESS) {
            usdPrice = RLP_USD_PRICE();
            decimals = 18;

            // Governance (INST and FLUID share the same underlying address) -
        } else if (token == INST_ADDRESS) {
            usdPrice = FLUID_USD_PRICE();
            decimals = 18;

            // Gold-backed ---------------------------------------------------
        } else if (token == XAUT_ADDRESS) {
            usdPrice = XAUT_USD_PRICE();
            decimals = 6;
        } else if (token == PAXG_ADDRESS) {
            usdPrice = PAXG_USD_PRICE();
            decimals = 18;
        } else {
            revert("not-found");
        }

        uint256 exchangePriceAndConfig_ = LIQUIDITY.readFromStorage(
            LiquiditySlotsLink.calculateMappingStorageSlot(
                LiquiditySlotsLink.LIQUIDITY_EXCHANGE_PRICES_MAPPING_SLOT,
                token
            )
        );

        (
            uint256 supplyExchangePrice,
            uint256 borrowExchangePrice
        ) = LiquidityCalcs.calcExchangePrices(exchangePriceAndConfig_);

        uint256 exchangePrice = isSupply
            ? supplyExchangePrice
            : borrowExchangePrice;

        if (amount > 0) {
            return (amount * 1e12) / exchangePrice;
        }

        return
            (amountInUSD * 1e12 * (10 ** decimals)) /
            ((usdPrice * exchangePrice) / 1e2);
    }

    // -----------------------------------------------------------------
    // Per-token USD price getters. Revert by default; the concrete
    // payload overrides exactly those it touches. Values are USD * 1e2.
    // -----------------------------------------------------------------

    // ETH + LSTs / LRTs --------------------------------------------------
    function ETH_USD_PRICE() public pure virtual returns (uint256) {
        revert("ETH_USD_PRICE not set");
    }
    function wstETH_USD_PRICE() public pure virtual returns (uint256) {
        revert("wstETH_USD_PRICE not set");
    }
    function weETH_USD_PRICE() public pure virtual returns (uint256) {
        revert("weETH_USD_PRICE not set");
    }
    function rsETH_USD_PRICE() public pure virtual returns (uint256) {
        revert("rsETH_USD_PRICE not set");
    }
    function weETHs_USD_PRICE() public pure virtual returns (uint256) {
        revert("weETHs_USD_PRICE not set");
    }
    function mETH_USD_PRICE() public pure virtual returns (uint256) {
        revert("mETH_USD_PRICE not set");
    }
    function ezETH_USD_PRICE() public pure virtual returns (uint256) {
        revert("ezETH_USD_PRICE not set");
    }
    function OSETH_USD_PRICE() public pure virtual returns (uint256) {
        revert("OSETH_USD_PRICE not set");
    }

    // BTC family (shared) -----------------------------------------------
    function BTC_USD_PRICE() public pure virtual returns (uint256) {
        revert("BTC_USD_PRICE not set");
    }

    // $1-pegged stables (shared) ----------------------------------------
    function STABLE_USD_PRICE() public pure virtual returns (uint256) {
        revert("STABLE_USD_PRICE not set");
    }

    // Yield-bearing stables ---------------------------------------------
    function sUSDe_USD_PRICE() public pure virtual returns (uint256) {
        revert("sUSDe_USD_PRICE not set");
    }
    function sUSDs_USD_PRICE() public pure virtual returns (uint256) {
        revert("sUSDs_USD_PRICE not set");
    }
    function syrupUSDT_USD_PRICE() public pure virtual returns (uint256) {
        revert("syrupUSDT_USD_PRICE not set");
    }
    function syrupUSDC_USD_PRICE() public pure virtual returns (uint256) {
        revert("syrupUSDC_USD_PRICE not set");
    }
    function REUSD_USD_PRICE() public pure virtual returns (uint256) {
        revert("REUSD_USD_PRICE not set");
    }
    function csUSDL_USD_PRICE() public pure virtual returns (uint256) {
        revert("csUSDL_USD_PRICE not set");
    }
    function JRUSDE_USD_PRICE() public pure virtual returns (uint256) {
        revert("JRUSDE_USD_PRICE not set");
    }
    function SRUSDE_USD_PRICE() public pure virtual returns (uint256) {
        revert("SRUSDE_USD_PRICE not set");
    }
    function wstUSR_USD_PRICE() public pure virtual returns (uint256) {
        revert("wstUSR_USD_PRICE not set");
    }
    function RLP_USD_PRICE() public pure virtual returns (uint256) {
        revert("RLP_USD_PRICE not set");
    }

    // Governance (INST + FLUID share this) ------------------------------
    function FLUID_USD_PRICE() public pure virtual returns (uint256) {
        revert("FLUID_USD_PRICE not set");
    }

    // Gold-backed --------------------------------------------------------
    function XAUT_USD_PRICE() public pure virtual returns (uint256) {
        revert("XAUT_USD_PRICE not set");
    }
    function PAXG_USD_PRICE() public pure virtual returns (uint256) {
        revert("PAXG_USD_PRICE not set");
    }
}
