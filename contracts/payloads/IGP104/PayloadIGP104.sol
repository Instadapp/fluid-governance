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
import {ILiteSigs} from "../common/interfaces/ILiteSigs.sol";

contract PayloadIGP104 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 104;

    function execute() public virtual override {
        super.execute();

        // Action 1: Update Lite Modules to integrate weETH
        action1();

        // Action 2: Adjust wstETH Rate Curve
        action2();
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

// @notice Action 1: Update Lite Modules to integrate weETH
    // Struct to hold implementation addresses for each function selector
    struct ModuleImplementation {
        bytes4 selector;
        address implementation;
    }

    struct ModuleImplementations {
        ModuleImplementation[] claimModule;
        ModuleImplementation[] viewModule;
        ModuleImplementation[] stethToEethModule;
        ModuleImplementation[] fluidAaveV3WeETHRebalancerModule;
        ModuleImplementation[] rebalancerModule;
    }

    ModuleImplementations internal moduleImplementations;

    // Setter for module implementations (can be extended for access control)
    function setModuleImplementation(
        uint8 moduleType, // 0: claim, 1: view, 2: stethToEeth, 3: fluidAaveV3WeETHRebalancer, 4: rebalancer
        bytes4 selector,
        address implementation
    ) external {
        ModuleImplementation memory impl = ModuleImplementation({selector: selector, implementation: implementation});
        if (moduleType == 0) {
            moduleImplementations.claimModule.push(impl);
        } else if (moduleType == 1) {
            moduleImplementations.viewModule.push(impl);
        } else if (moduleType == 2) {
            moduleImplementations.stethToEethModule.push(impl);
        } else if (moduleType == 3) {
            moduleImplementations.fluidAaveV3WeETHRebalancerModule.push(impl);
        } else if (moduleType == 4) {
            moduleImplementations.rebalancerModule.push(impl);
        }
    }

    // Helper to get implementation address for a selector in a module
    function _getImplementation(address hardcoded, ModuleImplementation[] storage arr, bytes4 selector) internal view returns (address) {
        for (uint i = 0; i < arr.length; i++) {
            if (arr[i].selector == selector) {
                if (arr[i].implementation != address(0)) {
                    return arr[i].implementation;
                }
                break;
            }
        }
        return hardcoded;
    }

    function action1() internal isActionSkippable(1) {
        {
            // Claim Module - Add KING Rewards
            bytes4[] memory newSigs_ = new bytes4[](1);
            newSigs_[0] = ILiteSigs.claimKingRewards.selector;
            _updateLiteImplementation(
                address(0),
                _getImplementation(0x1111111111111111111111111111111111111111, moduleImplementations.claimModule, ILiteSigs.claimKingRewards.selector),
                newSigs_,
                false
            );
        }
        {
            // View Module - Add Ratio Helper Functions
            bytes4[] memory newSigs_ = new bytes4[](2);
            newSigs_[0] = ILiteSigs.getRatioAaveV3.selector;
            newSigs_[1] = ILiteSigs.getRatioFluidWeETHWstETH.selector;
            _updateLiteImplementation(
                address(0),
                _getImplementation(0x2222222222222222222222222222222222222222, moduleImplementations.viewModule, ILiteSigs.getRatioAaveV3.selector),
                newSigs_,
                false
            );
        }
        {
            // StethToEethModule (New Module) - WeETH Related Functions
            bytes4[] memory newSigs_ = new bytes4[](1);
            newSigs_[0] = ILiteSigs.convertAaveV3wstETHToWeETH.selector;
            _updateLiteImplementation(
                address(0),
                _getImplementation(0x3333333333333333333333333333333333333333, moduleImplementations.stethToEethModule, ILiteSigs.convertAaveV3wstETHToWeETH.selector),
                newSigs_,
                false
            );
        }
        {
            // FluidAaveV3WeETHRebalancerModule (New Module) - WeETH Related Functions
            bytes4[] memory newSigs_ = new bytes4[](2);
            newSigs_[0] = ILiteSigs.rebalanceFromWeETHToWstETH.selector;
            newSigs_[1] = ILiteSigs.rebalanceFromWstETHToWeETH.selector;
            _updateLiteImplementation(
                address(0),
                _getImplementation(0x4444444444444444444444444444444444444444, moduleImplementations.fluidAaveV3WeETHRebalancerModule, ILiteSigs.rebalanceFromWeETHToWstETH.selector),
                newSigs_,
                false
            );
        }
        {
            // Rebalancer Module - KING Rewards and Sweep Functions
            bytes4[] memory newSigs_ = new bytes4[](2);
            newSigs_[0] = ILiteSigs.swapKingTokensToWeth.selector;
            newSigs_[1] = ILiteSigs.sweepWethToWeEth.selector;
            _updateLiteImplementation(
                address(0),
                _getImplementation(0x5555555555555555555555555555555555555555, moduleImplementations.rebalancerModule, ILiteSigs.swapKingTokensToWeth.selector),
                newSigs_,
                false
            );
        }

        // Update Dummy Implementation
        IETHV2.setDummyImplementation(
            0x0000000000000000000000000000000000000000
        );

        // Set Max Risk Ratio for Fluid Dex
        {
            uint8[] memory protocolId_ = new uint8[](1);
            uint256[] memory newRiskRatio_ = new uint256[](1);

            {
                protocolId_[0] = 11;
                newRiskRatio_[0] = 95_0000;
            }

            IETHV2.updateMaxRiskRatio(protocolId_, newRiskRatio_);
        }

        {
            // Set Team Multisig as Secondary Auth and Rebalancer for iETHv2 Lite Vault
            IETHV2.updateSecondaryAuth(TEAM_MULTISIG);
            IETHV2.updateRebalancer(TEAM_MULTISIG, true);
        }
    }

    // @notice Action 2: Adjust wstETH Rate Curve
    function action2() internal isActionSkippable(2) {
        // decrease wstETH rates
        {
            AdminModuleStructs.RateDataV2Params[]
                memory params_ = new AdminModuleStructs.RateDataV2Params[](1);

            params_[0] = AdminModuleStructs.RateDataV2Params({
                token: wstETH_ADDRESS, // wstETH
                kink1: 80 * 1e2, // 80%
                kink2: 90 * 1e2, // 90%
                rateAtUtilizationZero: 0, // 0%
                rateAtUtilizationKink1: 0.5 * 1e2, // 0.5%
                rateAtUtilizationKink2: 3.2 * 1e2, // 3.2%
                rateAtUtilizationMax: 100 * 1e2 // 100%
            });

            LIQUIDITY.updateRateDataV2s(params_);
        }
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
