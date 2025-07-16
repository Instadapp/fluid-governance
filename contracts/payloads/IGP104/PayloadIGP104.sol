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



interface ILiteSigsToRemove {
    // From View Module
    // Below function sig got updated in the new implementation
    function getRatioAaveV3(
        uint256 stEthPerWsteth_
    )
        external
        view
        returns (
            uint256 wstEthAmount_,
            uint256 stEthAmount_,
            uint256 ethAmount_,
            uint256 ratio_
        );

    // Removed below sigs
    function getRatioAaveV2() external;
    function getRatioEuler(uint256 stEthPerWsteth_) external;
    function getRatioMorphoAaveV2() external;
    function borrowBalanceMorphoAaveV3(address underlying_) external;
    function collateralBalanceMorphoAaveV3(address underlying_) external;
    function getRatioMorphoAaveV3(uint256 stEthPerWsteth_) external;
    function getRatioFluid(uint256 stEthPerWsteth_) external;
}

contract PayloadIGP104 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 104;

    // State Variables
    struct ModuleImplementation {
        bytes4[] sigs;
        address implementation;
    }
    struct LiteImplementationModules {
        ModuleImplementation adminModule;
        ModuleImplementation viewModule;
        ModuleImplementation claimModule;
        ModuleImplementation fluidStethModule;
        ModuleImplementation leverageModule;
        ModuleImplementation leverageDexModule;
        ModuleImplementation rebalancerModule;
        ModuleImplementation refinanceModule;
        ModuleImplementation stethToEethModule;
        ModuleImplementation unwindDexModule;
        ModuleImplementation withdrawModule;
        ModuleImplementation fluidAaveV3WeETHRebalancerModule;
        ModuleImplementation aaveV3WstETHWeETHSwapModule;
        address dummyImplementation;
    }

    LiteImplementationModules private _liteImplementationModules;

    function getLiteImplementationModules() public view returns (LiteImplementationModules memory) {
        return _liteImplementationModules;
    }

    /**
     * |
     * |     Admin Actions      |
     * |__________________________________
     */
    function setLiteImplementation(LiteImplementationModules memory modules_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        _liteImplementationModules = modules_;
    }

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
    function action1() internal isActionSkippable(1) {
        LiteImplementationModules memory modules_ = PayloadIGP104(ADDRESS_THIS).getLiteImplementationModules();
        
        // Admin Module (Only Module Update with no new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.adminModule;
            address oldImplementation_ = address(0x1BF97Df3D9eFa7036e96fB58F6c4CCfB2a2fDa21);
            address newImplementation_ = address(0x9485b2BE2Ce9672fe8eB36285d07c844DE97f43c);
            bytes4[] memory newSigs_ = new bytes4[](0);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }
        
        // View Module (Module Update with 4 new sigs and remove 8 sigs)
        {
            
            ModuleImplementation memory module_ = modules_.viewModule;
            address oldImplementation_ = address(0x038c28580A22E2b74bfb13E00e9c0a75CD732342);
            address newImplementation_ = address(0x9FB2fDc9F64c1FD7aABedE5D3F0A5BcA9402451F);
            bytes4[] memory newSigs_ = new bytes4[](4);
            bytes4[] memory removeSigs_ = new bytes4[](8);

            newSigs_[0] = ILiteSigs.getRatioAaveV3.selector;
            newSigs_[1] = ILiteSigs.getRatioFluidWeETHWstETH.selector;
            newSigs_[2] = ILiteSigs.maxAllocationToTeamMultisig.selector;
            newSigs_[3] = ILiteSigs.allocationToTeamMultisig.selector;

            removeSigs_[0] = ILiteSigsToRemove.getRatioAaveV3.selector;
            removeSigs_[1] = ILiteSigsToRemove.getRatioAaveV2.selector;
            removeSigs_[2] = ILiteSigsToRemove.getRatioEuler.selector;
            removeSigs_[3] = ILiteSigsToRemove.getRatioMorphoAaveV2.selector;
            removeSigs_[4] = ILiteSigsToRemove.getRatioMorphoAaveV3.selector;
            removeSigs_[5] = ILiteSigsToRemove.getRatioFluid.selector;
            removeSigs_[6] = ILiteSigsToRemove.borrowBalanceMorphoAaveV3.selector;
            removeSigs_[7] = ILiteSigsToRemove.collateralBalanceMorphoAaveV3.selector;

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // Claim Module(Module Update with 1 new sig)
        {
            
            ModuleImplementation memory module_ = modules_.claimModule;
            address oldImplementation_ = address(0xB00df786d3611acE29D19De744B4147f378715f4);
            address newImplementation_ = address(0x012173245e401BAd0cB763C2d7BB2D21b7BE4e5f);
            bytes4[] memory newSigs_ = new bytes4[](1);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            newSigs_[0] = ILiteSigs.claimKingRewards.selector;

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // FluidSteth Module (Only Module Update with no new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.fluidStethModule;
            address oldImplementation_ = address(0xd23a760cD16610f67a68BADC3c5E04E9898d2789);
            address newImplementation_ = address(0x567b3c860eea18Fd0E3E6d4c38577e8DB653113C);
            bytes4[] memory newSigs_ = new bytes4[](0);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // LeverageDex Module (Only Module Update with no new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.leverageDexModule;
            address oldImplementation_ = address(0xbeE5CDBd7Ae69b31CeAEB16485e43F3Bbc1b6983);
            address newImplementation_ = address(0x2D29312C1D70C93cD110e9973874C7083F2730dd);
            bytes4[] memory newSigs_ = new bytes4[](0);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // Leverage Module (Only Module Update with no new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.leverageModule;
            address oldImplementation_ = address(0x42aFc927E8Ab5D14b2760625Eb188158eefB46be);
            address newImplementation_ = address(0x028B980F0b226B17dC53507731195A463D442e95);
            bytes4[] memory newSigs_ = new bytes4[](0);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // Rebalancer Module (Only Module Update with 2 new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.rebalancerModule;
            address oldImplementation_ = address(0x7C44B02dA7826f9e14264a8E2D48a92bb86F72ee);
            address newImplementation_ = address(0x5343Da5F10bD9C36EA9cB04CaaE1452D8D967511);
            bytes4[] memory newSigs_ = new bytes4[](2);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            newSigs_[0] = ILiteSigs.sweepWethToWeEth.selector;
            newSigs_[1] = ILiteSigs.swapKingTokensToWeth.selector;

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // Refinance Module (Only Module Update with 0 new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.refinanceModule;
            address oldImplementation_ = address(0x807675e4D1eC7c1c134940Ab513B288d150E8023);
            address newImplementation_ = address(0x1E5B2b8546015B5537790c47BC7F5B3AF2038C03);
            bytes4[] memory newSigs_ = new bytes4[](0);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // UnwindDex Module (Only Module Update with 0 new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.unwindDexModule;
            address oldImplementation_ = address(0x635D70Fab1B1c3f7E9F3d30Bd1DeB738Daf87725);
            address newImplementation_ = address(0xFfB6B9958d3EA0B676C3945630a676732cf9c7d1);
            bytes4[] memory newSigs_ = new bytes4[](0);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // Withdrawals Module (Only Module Update with 0 new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.withdrawModule;
            address oldImplementation_ = address(0x6aa752b1462e7C71aA90e9236a817263bb5E0c72);
            address newImplementation_ = address(0x61243890c242316C444B5378388Ed24A4dbD2487);
            bytes4[] memory newSigs_ = new bytes4[](0);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // StethToEeth Module (Add new Module Update with 1 new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.stethToEethModule;
            address oldImplementation_ = address(0);
            address newImplementation_ = address(0x7ac6e3C02AC5dB7e7aD69d93ad1A2f60B67CcF5d);
            bytes4[] memory newSigs_ = new bytes4[](1);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            newSigs_[0] = ILiteSigs.convertAaveV3wstETHToWeETH.selector;

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // FluidAaveV3WeETHRebalancer Module (Add new Module Update with 2 new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.fluidAaveV3WeETHRebalancerModule;
            address oldImplementation_ = address(0);
            address newImplementation_ = address(0xCF8beE8092b93E28C046bD8dAE6f48175Fb74Fac);
            bytes4[] memory newSigs_ = new bytes4[](2);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            newSigs_[0] = ILiteSigs.rebalanceFromWeETHToWstETH.selector;
            newSigs_[1] = ILiteSigs.rebalanceFromWstETHToWeETH.selector;

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // AaveV3WstETHWeETHSwap Module (Add new Module Update with 2 new sigs)
        {
            
            ModuleImplementation memory module_ = modules_.aaveV3WstETHWeETHSwapModule;
            address oldImplementation_ = address(0);
            address newImplementation_ = address(0xa1f4499DfdBFfACA9eCe405f5B6d2076e2D9F929);
            bytes4[] memory newSigs_ = new bytes4[](2);
            bytes4[] memory removeSigs_ = new bytes4[](0);

            newSigs_[0] = ILiteSigs.swapWstETHToWeETH.selector;
            newSigs_[1] = ILiteSigs.swapWeETHToWstETH.selector;

            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // Update Dummy Implementation
        {
            address dummyImplementation_ = address(0x4cDeac65c8E0495F608bdEC080Efd97f9532Ee9c);
            IETHV2.setDummyImplementation(modules_.dummyImplementation == address(0) ? dummyImplementation_ : modules_.dummyImplementation);
        }

        // Set Max Risk Ratio for Fluid Dex
        {
            uint8[] memory protocolId_ = new uint8[](1);
            uint256[] memory newRiskRatio_ = new uint256[](1);

            {
                protocolId_[0] = 12;
                newRiskRatio_[0] = 95_0000; // 95%
            }

            IETHV2.updateMaxRiskRatio(protocolId_, newRiskRatio_);
        }
    }

    // @notice Action 2: Adjust wstETH Rate Curve
    function action2() internal isActionSkippable(2) {
        // decrease wstETH rates
        {
            FluidLiquidityAdminStructs.RateDataV2Params[]
                memory params_ = new FluidLiquidityAdminStructs.RateDataV2Params[](1);

            params_[0] = FluidLiquidityAdminStructs.RateDataV2Params({
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

    function _updateLiteImplementationFromStorage(
        address oldImplementation_,
        address newImplementation_,
        bytes4[] memory newSigs_,
        bytes4[] memory removeSigs_,
        ModuleImplementation memory module_,
        bool replace_
    ) internal {
        bytes4[] memory sigs;
        address newImplementationToUpdate;

        // If module is updated by Team MS, then use the latest one set by team MS
        if (module_.implementation != address(0)) {
            newImplementationToUpdate = module_.implementation;

            // If module sigs are not empty, then use the latest one set by team MS
            if (module_.sigs.length > 0) {
                sigs = module_.sigs;
            } else {
                sigs = newSigs_;
            }
        } else {
            // If module is not updated by Team MS, then use the hardcoded new implementation and sigs
            newImplementationToUpdate = newImplementation_;
            sigs = newSigs_;
        }

        bytes4[] memory oldSigs_;

        // If old implementation is not address(0) and replace is false, then get the old sigs
        if (oldImplementation_ != address(0) && !replace_) {
            oldSigs_ = IETHV2.getImplementationSigs(oldImplementation_);
        }

        uint256 signaturesLength_ = oldSigs_.length + newSigs_.length - removeSigs_.length;

        // concat old sigs and new sigs
        bytes4[] memory allSigs_ = new bytes4[](
            signaturesLength_
        );
        uint256 j_;
        for (uint256 i = 0; i < oldSigs_.length; i++) {
            if (removeSigs_.length > 0) {
                bool found_ = false;
                for (uint256 k = 0; k < removeSigs_.length; k++) {
                    if (oldSigs_[i] == removeSigs_[k]) {
                        found_ = true;
                        break;
                    }
                }
                if (!found_) {
                    allSigs_[j_++] = oldSigs_[i];
                }
            } else {
                allSigs_[j_++] = oldSigs_[i];
            }
        }

        for (uint256 i = 0; i < newSigs_.length; i++) {
            allSigs_[j_++] = newSigs_[i];
        }

        if (oldImplementation_ != address(0)) {
            IETHV2.removeImplementation(oldImplementation_);
        }

        IETHV2.addImplementation(newImplementation_, allSigs_);
    }
}
