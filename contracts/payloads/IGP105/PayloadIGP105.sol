pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "../libraries/bigMathMinified.sol";
import {LiquidityCalcs} from "../libraries/liquidityCalcs.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";

import {IGovernorBravo} from "../common/interfaces/IGovernorBravo.sol";
import {ITimelock} from "../common/interfaces/ITimelock.sol";

import {IFluidLiquidityAdmin, AdminModuleStructs as FluidLiquidityAdminStructs} from "../common/interfaces/IFluidLiquidity.sol";
import {IFluidReserveContract} from "../common/interfaces/IFluidReserveContract.sol";

import {IFluidVaultFactory} from "../common/interfaces/IFluidVaultFactory.sol";
import {IFluidDexFactory} from "../common/interfaces/IFluidDexFactory.sol";

import {IFluidDex, IFluidAdminDex, IFluidDexResolver} from "../common/interfaces/IFluidDex.sol";

import {IFluidVault, IFluidVaultT1} from "../common/interfaces/IFluidVault.sol";

import {IFTokenAdmin, ILendingRewards} from "../common/interfaces/IFToken.sol";

import {ISmartLendingAdmin} from "../common/interfaces/ISmartLending.sol";
import {ISmartLendingFactory} from "../common/interfaces/ISmartLendingFactory.sol";
import {IFluidLendingFactory} from "../common/interfaces/IFluidLendingFactory.sol";

import {ICodeReader} from "../common/interfaces/ICodeReader.sol";

import {IDSAV2} from "../common/interfaces/IDSA.sol";
import {IERC20} from "../common/interfaces/IERC20.sol";
import {IProxy} from "../common/interfaces/IProxy.sol";
import {PayloadIGPConstants} from "../common/constants.sol";
import {PayloadIGPHelpers} from "../common/helpers.sol";
import {PayloadIGPMain} from "../common/main.sol";

import {ILite} from "../common/interfaces/ILite.sol";

contract PayloadIGP105 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 105;

    function execute() public virtual override {
        super.execute();

        // Action 1: Clean up the default rate curves on unutilized assets
        action1();

        // Action 2: Update ETH interest rate curve
        action2();

        // Action 3: Make Multisig 2 as deployer on all factories
        action3();

        // Action 4:
        action4();
    }

    function verifyProposal() public view override {}

    function _PROPOSAL_ID() internal view override returns (uint256) {
        return PROPOSAL_ID;
    }

    /**
     * |
     * |     Proposal Payload Actions      |
     * |__________________________________
     */

    // @notice Action 1: Clean up the default rate curves on unutilized assets
    function action1() internal isActionSkippable(1) {
        address[16] memory tokens = [
            lBTC_ADDRESS,    // lBTC
            rsETH_ADDRESS,   // rsETH
            ezETH_ADDRESS,   // ezETH
            wstUSR_ADDRESS,  // wstUSR
            eBTC_ADDRESS,    // eBTC
            USD0_ADDRESS,    // USD0
            iUSD_ADDRESS,    // iUSD
            fxUSD_ADDRESS,   // fxUSD
            RLP_ADDRESS,     // RLP
            XAUT_ADDRESS,    // XAUT
            PAXG_ADDRESS,    // PAXG
            USR_ADDRESS,     // USR
            tBTC_ADDRESS,    // tBTC
            csUSDL_ADDRESS,  // csUSDL
            deUSD_ADDRESS    // deUSD
        ];

        for (uint256 i = 0; i < tokens.length; i++) {
            FluidLiquidityAdminStructs.RateDataV2Params[] memory params_ = new FluidLiquidityAdminStructs.RateDataV2Params[](1);
            params_[0] = FluidLiquidityAdminStructs.RateDataV2Params({
                token: tokens[i],
                kink1: 50 * 1e2, // 50%
                kink2: 80 * 1e2, // 80%
                rateAtUtilizationZero: 0, // 0%
                rateAtUtilizationKink1: 20 * 1e2, // 20%
                rateAtUtilizationKink2: 40 * 1e2, // 40%
                rateAtUtilizationMax: 100 * 1e2 // 100%
            });
            LIQUIDITY.updateRateDataV2s(params_);
        }
    }

    // @notice Action 2: Update ETH interest rate curve
    function action2() internal isActionSkippable(2) {
        {
            FluidLiquidityAdminStructs.RateDataV2Params[]
                memory params_ = new FluidLiquidityAdminStructs.RateDataV2Params[](
                    1
                );

            params_[0] = FluidLiquidityAdminStructs.RateDataV2Params({
                token: ETH_ADDRESS, // ETH
                kink1: 88 * 1e2, // 50%
                kink2: 93 * 1e2, // 80%
                rateAtUtilizationZero: 0, // 0%
                rateAtUtilizationKink1: 2.75 * 1e2, // 2.75%
                rateAtUtilizationKink2: 4 * 1e2, // 4%
                rateAtUtilizationMax: 100 * 1e2 // 100%
            });

            LIQUIDITY.updateRateDataV2s(params_);
        }
    }

    // @notice Action 3: Make Multisig 2 as deployer on all factories
    function action3() internal isActionSkippable(3) {
        // Set TEAM_MULTISIG_2 as deployer on all factories
        IFluidVaultFactory(VAULT_FACTORY).setFactoryAuth(TEAM_MULTISIG_2, true);
        IFluidDexFactory(DEX_FACTORY).setFactoryAuth(TEAM_MULTISIG_2, true);
        IFluidLendingFactory(LENDING_FACTORY).setFactoryAuth(TEAM_MULTISIG_2, true);
        ISmartLendingFactory(SMART_LENDING_FACTORY).setFactoryAuth(TEAM_MULTISIG_2, true);
    }

    // @notice Action 4:
    function action4() internal isActionSkippable(4) {
    }
    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants
    uint256 public constant ETH_USD_PRICE = 2_500 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 3_050 * 1e2;
    uint256 public constant weETH_USD_PRICE = 2_700 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 2_650 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 2_600 * 1e2;
    uint256 public constant mETH_USD_PRICE = 2_690 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 2_650 * 1e2;

    uint256 public constant BTC_USD_PRICE = 103_000 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.17 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.05 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 4.2 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.18 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.07 * 1e2;
    uint256 public constant XAUT_USD_PRICE = 3_240 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 3_240 * 1e2;

    uint256 public constant csUSDL_USD_PRICE = 1.03 * 1e2;

    function getRawAmount(
        address token,
        uint256 amount,
        uint256 amountInUSD,
        bool isSupply
    ) public view override returns (uint256) {
        if (amount > 0 && amountInUSD > 0) {
            revert("both usd and amount are not zero");
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

        uint256 usdPrice = 0;
        uint256 decimals = 18;
        if (token == ETH_ADDRESS) {
            usdPrice = ETH_USD_PRICE;
            decimals = 18;
        } else if (token == wstETH_ADDRESS) {
            usdPrice = wstETH_USD_PRICE;
            decimals = 18;
        } else if (token == weETH_ADDRESS) {
            usdPrice = weETH_USD_PRICE;
            decimals = 18;
        } else if (token == rsETH_ADDRESS) {
            usdPrice = rsETH_USD_PRICE;
            decimals = 18;
        } else if (token == weETHs_ADDRESS) {
            usdPrice = weETHs_USD_PRICE;
            decimals = 18;
        } else if (token == mETH_ADDRESS) {
            usdPrice = mETH_USD_PRICE;
            decimals = 18;
        } else if (token == ezETH_ADDRESS) {
            usdPrice = ezETH_USD_PRICE;
            decimals = 18;
        } else if (
            token == cbBTC_ADDRESS ||
            token == WBTC_ADDRESS ||
            token == eBTC_ADDRESS ||
            token == lBTC_ADDRESS
        ) {
            usdPrice = BTC_USD_PRICE;
            decimals = 8;
        } else if (token == tBTC_ADDRESS) {
            usdPrice = BTC_USD_PRICE;
            decimals = 18;
        } else if (token == USDC_ADDRESS || token == USDT_ADDRESS) {
            usdPrice = STABLE_USD_PRICE;
            decimals = 6;
        } else if (token == sUSDe_ADDRESS) {
            usdPrice = sUSDe_USD_PRICE;
            decimals = 18;
        } else if (token == sUSDs_ADDRESS) {
            usdPrice = sUSDs_USD_PRICE;
            decimals = 18;
        } else if (token == csUSDL_ADDRESS) {
            usdPrice = csUSDL_USD_PRICE;
            decimals = 18;
        } else if (
            token == GHO_ADDRESS ||
            token == USDe_ADDRESS ||
            token == deUSD_ADDRESS ||
            token == USR_ADDRESS ||
            token == USD0_ADDRESS ||
            token == fxUSD_ADDRESS ||
            token == BOLD_ADDRESS ||
            token == iUSD_ADDRESS ||
            token == USDTb_ADDRESS
        ) {
            usdPrice = STABLE_USD_PRICE;
            decimals = 18;
        } else if (token == INST_ADDRESS) {
            usdPrice = FLUID_USD_PRICE;
            decimals = 18;
        } else if (token == wstUSR_ADDRESS) {
            usdPrice = wstUSR_USD_PRICE;
            decimals = 18;
        } else if (token == RLP_ADDRESS) {
            usdPrice = RLP_USD_PRICE;
            decimals = 18;
        } else if (token == XAUT_ADDRESS) {
            usdPrice = XAUT_USD_PRICE;
            decimals = 6;
        } else if (token == PAXG_ADDRESS) {
            usdPrice = PAXG_USD_PRICE;
            decimals = 18;
        } else {
            revert("not-found");
        }

        uint256 exchangePrice = isSupply
            ? supplyExchangePrice
            : borrowExchangePrice;

        if (amount > 0) {
            return (amount * 1e12) / exchangePrice;
        } else {
            return
                (amountInUSD * 1e12 * (10 ** decimals)) /
                ((usdPrice * exchangePrice) / 1e2);
        }
    }
}