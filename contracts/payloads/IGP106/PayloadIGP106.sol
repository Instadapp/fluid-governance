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

contract PayloadIGP106 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 106;

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

        // Action 1: Withdraw $FLUID for Solana LP and rewards
        action1();

        // Action 2: Update rate curves for USDC, USDT, GHO
        action2();

        // Action 3: Update wstUSR stable T1 vault parameters
        action3();

        // Action 4: Set wstUSR smart vaults T3 and WSTUSR / USDTB vault launch limits
        action4();

        // Action 5: Remove MS as auth for csUSDL-USDC dex and set rebalancer for csUSDL-USDC smart lending
        action5();

        // Action 6: Lite Module Implementation Updates
        action6();
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

    // @notice Action 1: Withdraw $FLUID for Solana LP and rewards
    function action1() internal isActionSkippable(1) {
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string
            memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";

        // Spell 1: Transfer FLUID to Team Multisig for Solana LP and rewards
        {
            uint256 FLUID_AMOUNT = 50_000 * 1e18; // 50,000 FLUID tokens
            targets[0] = "BASIC-A";
            encodedSpells[0] = abi.encodeWithSignature(
                withdrawSignature,
                FLUID_ADDRESS,
                FLUID_AMOUNT,
                TEAM_MULTISIG,
                0,
                0
            );
        }

        IDSAV2(TREASURY).cast(targets, encodedSpells, address(this));
    }

    // @notice Action 2: Update rate curves for USDC, USDT, GHO
    function action2() internal isActionSkippable(2) {
        {
            FluidLiquidityAdminStructs.RateDataV2Params[]
                memory params_ = new FluidLiquidityAdminStructs.RateDataV2Params[](
                    3
                );

            // USDC rate curve
            params_[0] = FluidLiquidityAdminStructs.RateDataV2Params({
                token: USDC_ADDRESS, // USDC
                kink1: 85 * 1e2, // 85%
                kink2: 93 * 1e2, // 93%
                rateAtUtilizationZero: 0, // 0%
                rateAtUtilizationKink1: 7 * 1e2, // 7%
                rateAtUtilizationKink2: 9 * 1e2, // 9%
                rateAtUtilizationMax: 25 * 1e2 // 25%
            });

            // USDT rate curve
            params_[1] = FluidLiquidityAdminStructs.RateDataV2Params({
                token: USDT_ADDRESS, // USDT
                kink1: 85 * 1e2, // 85%
                kink2: 93 * 1e2, // 93%
                rateAtUtilizationZero: 0, // 0%
                rateAtUtilizationKink1: 7 * 1e2, // 7%
                rateAtUtilizationKink2: 9 * 1e2, // 9%
                rateAtUtilizationMax: 15 * 1e2 // 15%
            });

            // GHO rate curve
            params_[2] = FluidLiquidityAdminStructs.RateDataV2Params({
                token: GHO_ADDRESS, // GHO
                kink1: 85 * 1e2, // 85%
                kink2: 93 * 1e2, // 93%
                rateAtUtilizationZero: 0, // 0%
                rateAtUtilizationKink1: 7.2 * 1e2, // 7.2%
                rateAtUtilizationKink2: 9.6 * 1e2, // 9.6%
                rateAtUtilizationMax: 15 * 1e2 // 15%
            });

            LIQUIDITY.updateRateDataV2s(params_);
        }
    }

    // @notice Action 3: Update wstUSR stable T1 vault parameters
    function action3() internal isActionSkippable(3) {
        uint256 CF = 90 * 1e2;
        uint256 LT = 92 * 1e2;

        // Update wstUSR T1 vault parameters
        {
            address wstUSR_USDC_VAULT = getVaultAddress(110);
            
            IFluidVaultT1(wstUSR_USDC_VAULT).updateCollateralFactor(CF);
            IFluidVaultT1(wstUSR_USDC_VAULT).updateLiquidationThreshold(LT);
        }

        {
            address wstUSR_USDT_VAULT = getVaultAddress(111);
            IFluidVaultT1(wstUSR_USDT_VAULT).updateCollateralFactor(CF);
            IFluidVaultT1(wstUSR_USDT_VAULT).updateLiquidationThreshold(LT);
        }

        {
            address wstUSR_GHO_VAULT = getVaultAddress(112);
            IFluidVaultT1(wstUSR_GHO_VAULT).updateCollateralFactor(CF);
            IFluidVaultT1(wstUSR_GHO_VAULT).updateLiquidationThreshold(LT);
        }
    }

    // @notice Action 4: Set wstUSR smart vaults T3 and WSTUSR / USDTB vault launch limits
    function action4() internal isActionSkippable(4) {
        {
            // launch limits for wstUSR/USDTb vault
            address wstUSR_USDTb_VAULT = getVaultAddress(142);

            // [TYPE 1] WSTUSR/USDTbvault - Launch limits
            VaultConfig memory VAULT_wstUSR_USDTb = VaultConfig({
                vault: wstUSR_USDTb_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: wstUSR_ADDRESS,
                borrowToken: USDTb_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 6_000_000, // $6M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_wstUSR_USDTb);
            VAULT_FACTORY.setVaultAuth(wstUSR_USDTb_VAULT, TEAM_MULTISIG, false);
        }

        {
            // launch limits for wstUSR/USDC-USDT vault
            address wstUSR_USDC_USDT_VAULT = getVaultAddress(143);
            address USDC_USDT_DEX = getDexAddress(2);

            {
                // [TYPE 3] WSTUSR<>USDC-USDT vault - Launch limits
                VaultConfig memory VAULT_wstUSR_USDC_USDT = VaultConfig({
                    vault: wstUSR_USDC_USDT_VAULT,
                    vaultType: VAULT_TYPE.TYPE_3,
                    supplyToken: wstUSR_ADDRESS, // Set at vault level
                    borrowToken: address(0), // Set at DEX level
                    baseWithdrawalLimitInUSD: 8_000_000, // $8M
                    baseBorrowLimitInUSD: 0,
                    maxBorrowLimitInUSD: 0
                });

                setVaultLimits(VAULT_wstUSR_USDC_USDT);
                VAULT_FACTORY.setVaultAuth(
                    wstUSR_USDC_USDT_VAULT,
                    TEAM_MULTISIG,
                    false
                );
            }

            {
                DexBorrowProtocolConfigInShares
                    memory config_ = DexBorrowProtocolConfigInShares({
                        dex: USDC_USDT_DEX,
                        protocol: wstUSR_USDC_USDT_VAULT,
                        expandPercent: 30 * 1e2, // 20%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimit: 2_900_000 * 1e18, // $6M
                        maxBorrowLimit: 9_800_000 * 1e18 // $20M
                    });

                setDexBorrowProtocolLimitsInShares(config_);
            }
        }

        {
            // launch limits for wstUSR/USDC-USDT concentrated vault
            address wstUSR_USDC_USDT_CONCENTRATED_VAULT = getVaultAddress(144);
            address USDC_USDT_CONCENTRATED_DEX = getDexAddress(34);

            {
                // [TYPE 3] WSTUSR<>USDC-USDT concentrated vault - Launch limits
                VaultConfig
                    memory VAULT_wstUSR_USDC_USDT_CONCENTRATED = VaultConfig({
                        vault: wstUSR_USDC_USDT_CONCENTRATED_VAULT,
                        vaultType: VAULT_TYPE.TYPE_3,
                        supplyToken: wstUSR_ADDRESS, // Set at vault level
                        borrowToken: address(0), // Set at DEX level
                        baseWithdrawalLimitInUSD: 8_000_000, // $8M
                        baseBorrowLimitInUSD: 0,
                        maxBorrowLimitInUSD: 0
                    });

                setVaultLimits(VAULT_wstUSR_USDC_USDT_CONCENTRATED);
                VAULT_FACTORY.setVaultAuth(
                    wstUSR_USDC_USDT_CONCENTRATED_VAULT,
                    TEAM_MULTISIG,
                    false
                );
            }

            {
                DexBorrowProtocolConfigInShares
                    memory vaultConfig_ = DexBorrowProtocolConfigInShares({
                        dex: USDC_USDT_CONCENTRATED_DEX,
                        protocol: wstUSR_USDC_USDT_CONCENTRATED_VAULT,
                        expandPercent: 30 * 1e2, // 20%
                        expandDuration: 6 hours, // 6 hours
                        baseBorrowLimit: 3_000_000 * 1e18, // $6M
                        maxBorrowLimit: 10_000_000 * 1e18 // $20M
                    });

                setDexBorrowProtocolLimitsInShares(vaultConfig_);
            }
        }
    }

    // @notice Action 5: Remove MS as auth for csUSDL-USDC dex and set rebalancer for csUSDL-USDC smart lending
    function action5() internal isActionSkippable(5) {
        address csUSDL_USDC_DEX = getDexAddress(38);
        {
            // csUSDL-USDC DEX
            DEX_FACTORY.setDexAuth(csUSDL_USDC_DEX, TEAM_MULTISIG, false);
        }
        {
            address fSL38_csUSDL_USDC = getSmartLendingAddress(38);

            // set rebalancer at fSL38 to reserve contract proxy
            ISmartLendingAdmin(fSL38_csUSDL_USDC).setRebalancer(
                address(FLUID_RESERVE)
            );
        }
    }

    // @notice Action 6: Lite Module Implementation Updates
    function action6() internal isActionSkippable(6) {
        LiteImplementationModules memory modules_ = PayloadIGP106(ADDRESS_THIS).getLiteImplementationModules();

        // Rebalancer Module (Module Update with 2 new sigs and remove 1 sig)
        {
            
            ModuleImplementation memory module_ = modules_.rebalancerModule;
            address oldImplementation_ = address(0x5343Da5F10bD9C36EA9cB04CaaE1452D8D967511);
            address newImplementation_ = address(0x475035176043478c74df4AEAb07146484E3c3530);
            bytes4[] memory newSigs_ = new bytes4[](2);
            bytes4[] memory removeSigs_ = new bytes4[](1);

            newSigs_[0] = bytes4(0x97c8b4db); // swapKingTokensToWeth (new signature)
            newSigs_[1] = bytes4(0x84d5f112); // transferKingTokensToTeamMS (new signature)

            removeSigs_[0] = bytes4(0xc4a64d17); // swapKingTokensToWeth (old signature)
 
            _updateLiteImplementationFromStorage(
                oldImplementation_,
                newImplementation_,
                newSigs_,
                removeSigs_,
                module_,
                false
            );
        }

        // AaveV3WstETHWeETHSwap Module (Module Update with 2 new sigs and remove 2 old sigs)
        {
            
            ModuleImplementation memory module_ = modules_.aaveV3WstETHWeETHSwapModule;
            address oldImplementation_ = address(0xa1f4499DfdBFfACA9eCe405f5B6d2076e2D9F929);
            address newImplementation_ = address(0xF95105c0f7ceBFbc5F186cE9E7D22620c75e0c8d);
            bytes4[] memory newSigs_ = new bytes4[](2);
            bytes4[] memory removeSigs_ = new bytes4[](2);

            newSigs_[0] = bytes4(0xf0fefc66); // swapWstETHToWeETH (new signature)
            newSigs_[1] = bytes4(0x2aaa3e6c); // swapWeETHToWstETH (new signature)

            removeSigs_[0] = bytes4(0x1609c001); // swapWstETHToWeETH (old signature)
            removeSigs_[1] = bytes4(0x8a47ea39); // swapWeETHToWstETH (old signature)

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
            address dummyImplementation_ = address(0x6Feb5478f7345aBE1d477Ff6828819b4C8ba551a);
            IETHV2.setDummyImplementation(dummyImplementation_);
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
