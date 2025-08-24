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
import {IFluidSmartLendingFactory} from "../common/interfaces/IFluidSmartLendingFactory.sol";
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

contract PayloadIGP107 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 107;

    // State Variables
    struct ModuleImplementation {
        bytes4[] sigs;
        address implementation;
    }
    struct LiteImplementationModules {
        ModuleImplementation rebalancerModule;
        ModuleImplementation aaveV3WstETHWeETHSwapModule;
        address dummyImplementation;
    }

    LiteImplementationModules private _liteImplementationModules;

    function getLiteImplementationModules()
        public
        view
        returns (LiteImplementationModules memory)
    {
        return _liteImplementationModules;
    }

    /**
     * |
     * |     Admin Actions      |
     * |__________________________________
     */
    function setLiteImplementation(
        LiteImplementationModules memory modules_
    ) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        _liteImplementationModules = modules_;
    }

    function execute() public virtual override {
        super.execute();

        // Action 1: Withdraw ETH for Solana LP and rewards
        action1();

        // Action 2: Provide Credit to Team Multisig for Fluid DEX Lite
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

    // @notice Action 1: Withdraw ETH for Solana LP and rewards
    function action1() internal isActionSkippable(1) {
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string
            memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";

        // Spell 1: Transfer ETH to Team Multisig for Solana LP and rewards
        {
            uint256 ETH_AMOUNT = 230 * 1e18; // 230 ETH
            targets[0] = "BASIC-A";
            encodedSpells[0] = abi.encodeWithSignature(
                withdrawSignature,
                ETH_ADDRESS,
                ETH_AMOUNT,
                TEAM_MULTISIG,
                0,
                0
            );
        }

        IDSAV2(TREASURY).cast(targets, encodedSpells, address(this));
    }

     // @notice Action 2: Provide Credit to Team Multisig for Fluid DEX Lite
    function action2() internal isActionSkippable(2) {
        // Give Team Multisig 4M USDC credit
        {
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: TEAM_MULTISIG,
                token: USDC_ADDRESS,
                mode: 1,
                expandPercent: 1 * 1e2, // 1%
                expandDuration: 16777215, // max time
                baseDebtCeiling: getRawAmount(
                    USDC_ADDRESS,
                    0,
                    4_000_000, // $4M -> additional 2M
                    false
                ),
                maxDebtCeiling: getRawAmount(
                    USDC_ADDRESS,
                    0,
                    4_000_000, // $4M -> additional 2M
                    false
                )
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }

        // Give Team Multisig 4M USDT credit
        {
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: TEAM_MULTISIG,
                token: USDT_ADDRESS,
                mode: 1,
                expandPercent: 1 * 1e2, // 1%
                expandDuration: 16777215, // max time
                baseDebtCeiling: getRawAmount(
                    USDT_ADDRESS,
                    0,
                    6_000_000, // $6M -> additional 2M each for USDC/USDT and USDe/USDT
                    false
                ),
                maxDebtCeiling: getRawAmount(
                    USDT_ADDRESS,
                    0,
                    6_000_000, // $6M -> additional 2M each for USDC/USDT and USDe/USDT
                    false
                )
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }

        // Give Team Multisig 2M USDe credit - USDe/USDT Pool
        {
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: TEAM_MULTISIG,
                token: USDe_ADDRESS,
                mode: 1,
                expandPercent: 1 * 1e2, // 1%
                expandDuration: 16777215, // max time
                baseDebtCeiling: getRawAmount(
                    USDe_ADDRESS,
                    0,
                    2_000_000, // $2M
                    false
                ),
                maxDebtCeiling: getRawAmount(
                    USDe_ADDRESS,
                    0,
                    2_000_000, // $2M
                    false
                )
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }

        // Give Team Multisig 1M wstETH credit - wstETH/ETH Pool
        {
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: TEAM_MULTISIG,
                token: wstETH_ADDRESS,
                mode: 1,
                expandPercent: 1 * 1e2, // 1%
                expandDuration: 16777215, // max time
                baseDebtCeiling: getRawAmount(
                    wstETH_ADDRESS,
                    0,
                    1_000_000, // $1M
                    false
                ),
                maxDebtCeiling: getRawAmount(
                    wstETH_ADDRESS,
                    0,
                    1_000_000, // $1M
                    false
                )
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }

        // Give Team Multisig 1M cbBTC credit - cbBTC/wBTC Pool
        {
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: TEAM_MULTISIG,
                token: cbBTC_ADDRESS,
                mode: 1,
                expandPercent: 1 * 1e2, // 1%
                expandDuration: 16777215, // max time
                baseDebtCeiling: getRawAmount(
                    cbBTC_ADDRESS,
                    0,
                    1_000_000, // $1M
                    false
                ),
                maxDebtCeiling: getRawAmount(
                    cbBTC_ADDRESS,
                    0,
                    1_000_000, // $1M
                    false
                )
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }
    }


    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

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

        uint256 signaturesLength_ = oldSigs_.length +
            newSigs_.length -
            removeSigs_.length;

        // concat old sigs and new sigs
        bytes4[] memory allSigs_ = new bytes4[](signaturesLength_);
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

    // Token Prices Constants
    uint256 public constant ETH_USD_PRICE = 3_700 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 3_700 * 1e2;
    uint256 public constant weETH_USD_PRICE = 3_700 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 3_700 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 3_700 * 1e2;
    uint256 public constant mETH_USD_PRICE = 3_700 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 3_700 * 1e2;

    uint256 public constant BTC_USD_PRICE = 113_000 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.19 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.06 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 6 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.22 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.09 * 1e2;
    uint256 public constant XAUT_USD_PRICE = 3_340 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 3_340 * 1e2;

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
