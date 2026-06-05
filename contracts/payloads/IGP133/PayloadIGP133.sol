// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {BigMathMinified} from "../libraries/bigMathMinified.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP133: Legacy and sUSDS supply withdrawal tightening, risk-tightening
///         of borrow limits across 66 less-trusted Ethereum vaults, and capping the
///         fsUSDs fToken base withdrawal limit to total supply + 10%.
contract PayloadIGP133 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 133;

    function execute() public virtual override {
        super.execute();

        // Action 1: Reduce base withdrawal limits on legacy vaults 1–10
        action1();

        // Action 2: Restrict base withdrawal limits on sUSDS sunset vaults
        action2();

        // Action 3: Tighten Liquidity Layer borrow limits on 54 vaults
        action3();

        // Action 4: Tighten smart-debt limits on the USDC-USDT DEX (id 2)
        action4();

        // Action 5: Tighten smart-debt limits on the USDC-USDT DEX (id 34)
        action5();

        // Action 6: Tighten smart-debt limits on the GHO-USDC DEX (id 4)
        action6();

        // Action 7: Restrict fsUSDs base withdrawal limit to total supply + 10%
        action7();
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

    /// @notice Action 1: Set legacy vault 1–10 base withdrawal limits to total supply + 5%
    function action1() internal isActionSkippable(1) {
        FluidLiquidityAdminStructs.UserSupplyConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                10
            );

        configs_[0] = _legacyVaultSupplyConfig(1, ETH_ADDRESS, 628187 * 1e12);
        configs_[1] = _legacyVaultSupplyConfig(2, ETH_ADDRESS, 945974 * 1e12);
        configs_[2] = _legacyVaultSupplyConfig(
            3,
            wstETH_ADDRESS,
            646899 * 1e12
        );
        configs_[3] = _legacyVaultSupplyConfig(
            4,
            wstETH_ADDRESS,
            544134 * 1e12
        );
        configs_[4] = _legacyVaultSupplyConfig(
            5,
            wstETH_ADDRESS,
            549870 * 1e12
        );
        configs_[5] = _legacyVaultSupplyConfig(
            6,
            weETH_ADDRESS,
            695132095 * 1e12
        );
        configs_[6] = _legacyVaultSupplyConfig(
            7,
            sUSDe_ADDRESS,
            3298946018 * 1e12
        );
        configs_[7] = _legacyVaultSupplyConfig(
            8,
            sUSDe_ADDRESS,
            413657754 * 1e12
        );
        configs_[8] = _legacyVaultSupplyConfig(
            9,
            weETH_ADDRESS,
            240487 * 1e12
        );
        configs_[9] = _legacyVaultSupplyConfig(
            10,
            weETH_ADDRESS,
            213728 * 1e12
        );

        LIQUIDITY.updateUserSupplyConfigs(configs_);
    }

    /// @notice Action 2: Restrict base withdrawal limits on sUSDS sunset vaults
    function action2() internal isActionSkippable(2) {
        FluidLiquidityAdminStructs.UserSupplyConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                2
            );

        configs_[0] = _legacyVaultSupplyConfig(
            58,
            sUSDs_ADDRESS,
            650 * 1e18
        );
        configs_[1] = _legacyVaultSupplyConfig(
            85,
            wstETH_ADDRESS,
            9372630468 * 1e6
        );

        LIQUIDITY.updateUserSupplyConfigs(configs_);
    }

    /// @notice Action 3: Tighten Liquidity Layer borrow limits (expand window 6h -> 3h)
    function action3() internal isActionSkippable(3) {
        FluidLiquidityAdminStructs.UserBorrowConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                54
            );

        // Vault 16 (weETH / wstETH) - borrow wstETH @ $2620.73
        configs_[0] = _borrowConfig(
            16,
            wstETH_ADDRESS,
            25 * 1e2, // 25%
            953_932_682_878_434_634_625, // $2.5M base -> 953.9327 wstETH
            9_539_326_828_784_346_346_247 // $25M max -> 9539.3268 wstETH
        );
        // Vault 18 (sUSDe / USDT) - borrow USDT @ $0.999409
        configs_[1] = _borrowConfig(
            18,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            25_014_783_737_189 // $25M max -> 25014783.7372 USDT
        );
        // Vault 17 (sUSDe / USDC) - borrow USDC @ $0.99979
        configs_[2] = _borrowConfig(
            17,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            2_500_525_110_273, // $2.5M base -> 2500525.1103 USDC
            25_005_251_102_732 // $25M max -> 25005251.1027 USDC
        );
        // Vault 19 (weETH / USDC) - borrow USDC @ $0.99979
        configs_[3] = _borrowConfig(
            19,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            2_500_525_110_273, // $2.5M base -> 2500525.1103 USDC
            25_005_251_102_732 // $25M max -> 25005251.1027 USDC
        );
        // Vault 20 (weETH / USDT) - borrow USDT @ $0.999409
        configs_[4] = _borrowConfig(
            20,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            25_014_783_737_189 // $25M max -> 25014783.7372 USDT
        );
        // Vault 26 (weETH / WBTC) - borrow WBTC @ $76897
        configs_[5] = _borrowConfig(
            26,
            WBTC_ADDRESS,
            25 * 1e2, // 25%
            130_044_085, // $100K base -> 1.3004 WBTC
            1_300_440_849 // $1M max -> 13.0044 WBTC
        );
        // Vault 27 (weETHs / wstETH) - borrow wstETH @ $2620.73
        configs_[6] = _borrowConfig(
            27,
            wstETH_ADDRESS,
            25 * 1e2, // 25%
            381_573_073_151_373_853_850, // $1M base -> 381.5731 wstETH
            1_907_865_365_756_869_269_249 // $5M max -> 1907.8654 wstETH
        );
        // Vault 32 (weETH / cbBTC) - borrow cbBTC @ $77100
        configs_[7] = _borrowConfig(
            32,
            cbBTC_ADDRESS,
            25 * 1e2, // 25%
            129_701_686, // $100K base -> 1.2970 cbBTC
            1_297_016_861 // $1M max -> 12.9702 cbBTC
        );
        // Vault 56 (sUSDe / GHO) - borrow GHO @ $0.999374
        configs_[8] = _borrowConfig(
            56,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            2_501_565_980_303_670_097_481_023, // $2.5M base -> 2501565.9803 GHO
            25_015_659_803_036_700_974_810_231 // $25M max -> 25015659.8030 GHO
        );
        // Vault 57 (weETH / GHO) - borrow GHO @ $0.999374
        configs_[9] = _borrowConfig(
            57,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            2_501_565_980_303_670_097_481_023, // $2.5M base -> 2501565.9803 GHO
            25_015_659_803_036_700_974_810_231 // $25M max -> 25015659.8030 GHO
        );
        // Vault 74 (weETH-ETH / wstETH) - borrow wstETH @ $2620.73
        configs_[10] = _borrowConfig(
            74,
            wstETH_ADDRESS,
            10 * 1e2, // 10%
            953_932_682_878_434_634_625, // $2.5M base -> 953.9327 wstETH
            19_078_653_657_568_692_692_494 // $50M max -> 19078.6537 wstETH
        );
        // Vault 80 (weETHs-ETH / wstETH) - borrow wstETH @ $2620.73
        configs_[11] = _borrowConfig(
            80,
            wstETH_ADDRESS,
            25 * 1e2, // 25%
            381_573_073_151_373_853_850, // $1M base -> 381.5731 wstETH
            953_932_682_878_434_634_625 // $2.5M max -> 953.9327 wstETH
        );
        // Vault 92 (sUSDe-USDT / USDT) - borrow USDT @ $0.999409
        configs_[12] = _borrowConfig(
            92,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            25_014_783_737_189 // $25M max -> 25014783.7372 USDT
        );
        // Vault 93 (USDe-USDT / USDT) - borrow USDT @ $0.999409
        configs_[13] = _borrowConfig(
            93,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            25_014_783_737_189 // $25M max -> 25014783.7372 USDT
        );
        // Vault 94 (eBTC / WBTC) - borrow WBTC @ $76897
        configs_[14] = _borrowConfig(
            94,
            WBTC_ADDRESS,
            25 * 1e2, // 25%
            130_044_085, // $100K base -> 1.3004 WBTC
            1_300_440_849 // $1M max -> 13.0044 WBTC
        );
        // Vault 96 (eBTC-cbBTC / WBTC) - borrow WBTC @ $76897
        configs_[15] = _borrowConfig(
            96,
            WBTC_ADDRESS,
            25 * 1e2, // 25%
            130_044_085, // $100K base -> 1.3004 WBTC
            1_300_440_849 // $1M max -> 13.0044 WBTC
        );
        // Vault 97 (LBTC-cbBTC / WBTC) - borrow WBTC @ $76897
        configs_[16] = _borrowConfig(
            97,
            WBTC_ADDRESS,
            25 * 1e2, // 25%
            3_251_102_124, // $2.5M base -> 32.5110 WBTC
            32_511_021_236 // $25M max -> 325.1102 WBTC
        );
        // Vault 103 (ezETH / wstETH) - borrow wstETH @ $2620.73
        configs_[17] = _borrowConfig(
            103,
            wstETH_ADDRESS,
            25 * 1e2, // 25%
            38_157_307_315_137_385_385, // $100K base -> 38.1573 wstETH
            381_573_073_151_373_853_850 // $1M max -> 381.5731 wstETH
        );
        // Vault 104 (ezETH-ETH / wstETH) - borrow wstETH @ $2620.73
        configs_[18] = _borrowConfig(
            104,
            wstETH_ADDRESS,
            25 * 1e2, // 25%
            953_932_682_878_434_634_625, // $2.5M base -> 953.9327 wstETH
            9_539_326_828_784_346_346_247 // $25M max -> 9539.3268 wstETH
        );
        // Vault 107 (LBTC / USDC) - borrow USDC @ $0.99979
        configs_[19] = _borrowConfig(
            107,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            2_500_525_110_273, // $2.5M base -> 2500525.1103 USDC
            25_005_251_102_732 // $25M max -> 25005251.1027 USDC
        );
        // Vault 108 (LBTC / USDT) - borrow USDT @ $0.999409
        configs_[20] = _borrowConfig(
            108,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            2_491_472_460_224, // $2.49M base -> 2491472.4602 USDT
            25_014_783_737_189 // $25M max -> 25014783.7372 USDT
        );
        // Vault 109 (LBTC / GHO) - borrow GHO @ $0.999374
        configs_[21] = _borrowConfig(
            109,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            2_501_565_980_303_670_097_481_023, // $2.5M base -> 2501565.9803 GHO
            25_015_659_803_036_700_974_810_231 // $25M max -> 25015659.8030 GHO
        );
        // Vault 114 (LBTC-cbBTC / cbBTC) - borrow cbBTC @ $77100
        configs_[22] = _borrowConfig(
            114,
            cbBTC_ADDRESS,
            25 * 1e2, // 25%
            3_242_542_153, // $2.5M base -> 32.4254 cbBTC
            32_425_421_530 // $25M max -> 324.2542 cbBTC
        );
        // Vault 115 (WBTC-LBTC / WBTC) - borrow WBTC @ $76897
        configs_[23] = _borrowConfig(
            115,
            WBTC_ADDRESS,
            25 * 1e2, // 25%
            3_251_102_124, // $2.5M base -> 32.5110 WBTC
            32_511_021_236 // $25M max -> 325.1102 WBTC
        );
        // Vault 116 (XAUt / USDC) - borrow USDC @ $0.99979
        configs_[24] = _borrowConfig(
            116,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            2_500_525_110_273, // $2.5M base -> 2500525.1103 USDC
            25_005_251_102_732 // $25M max -> 25005251.1027 USDC
        );
        // Vault 117 (XAUt / USDT) - borrow USDT @ $0.999409
        configs_[25] = _borrowConfig(
            117,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            25_014_783_737_189 // $25M max -> 25014783.7372 USDT
        );
        // Vault 118 (XAUt / GHO) - borrow GHO @ $0.999374
        configs_[26] = _borrowConfig(
            118,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            1_000_626_392_121_468_038_992_409, // $1M base -> 1000626.3921 GHO
            10_006_263_921_214_680_389_924_092 // $10M max -> 10006263.9212 GHO
        );
        // Vault 119 (PAXG / USDC) - borrow USDC @ $0.99979
        configs_[27] = _borrowConfig(
            119,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            2_500_525_110_273, // $2.5M base -> 2500525.1103 USDC
            25_005_251_102_732 // $25M max -> 25005251.1027 USDC
        );
        // Vault 120 (PAXG / USDT) - borrow USDT @ $0.999409
        configs_[28] = _borrowConfig(
            120,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            25_014_783_737_189 // $25M max -> 25014783.7372 USDT
        );
        // Vault 121 (PAXG / GHO) - borrow GHO @ $0.999374
        configs_[29] = _borrowConfig(
            121,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            1_000_626_392_121_468_038_992_409, // $1M base -> 1000626.3921 GHO
            10_006_263_921_214_680_389_924_092 // $10M max -> 10006263.9212 GHO
        );
        // Vault 122 (PAXG-XAUt / USDC) - borrow USDC @ $0.99979
        configs_[30] = _borrowConfig(
            122,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            1_000_210_044_109, // $1M base -> 1000210.0441 USDC
            2_500_525_110_273 // $2.5M max -> 2500525.1103 USDC
        );
        // Vault 123 (PAXG-XAUt / USDT) - borrow USDT @ $0.999409
        configs_[31] = _borrowConfig(
            123,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            25_014_783_737_189 // $25M max -> 25014783.7372 USDT
        );
        // Vault 124 (PAXG-XAUt / GHO) - borrow GHO @ $0.999374
        configs_[32] = _borrowConfig(
            124,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            1_000_626_392_121_468_038_992_409, // $1M base -> 1000626.3921 GHO
            10_006_263_921_214_680_389_924_092 // $10M max -> 10006263.9212 GHO
        );
        // Vault 130 (weETH / USDtb) - borrow USDtb @ $0.999168
        configs_[33] = _borrowConfig(
            130,
            USDTb_ADDRESS,
            25 * 1e2, // 25%
            1_000_832_692_800_409_941_070_971, // $1M base -> 1000832.6928 USDtb
            2_502_081_732_001_024_852_677_428 // $2.5M max -> 2502081.7320 USDtb
        );
        // Vault 137 (USDe-USDtb / USDT) - borrow USDT @ $0.999409
        configs_[34] = _borrowConfig(
            137,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            1_000_591_349_488, // $1M base -> 1000591.3495 USDT
            10_005_913_494_875 // $10M max -> 10005913.4949 USDT
        );
        // Vault 138 (USDe-USDtb / USDC) - borrow USDC @ $0.99979
        configs_[35] = _borrowConfig(
            138,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            1_000_210_044_109, // $1M base -> 1000210.0441 USDC
            10_002_100_441_093 // $10M max -> 10002100.4411 USDC
        );
        // Vault 140 (USDe-USDtb / GHO) - borrow GHO @ $0.999374
        configs_[36] = _borrowConfig(
            140,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            1_000_626_392_121_468_038_992_409, // $1M base -> 1000626.3921 GHO
            10_006_263_921_214_680_389_924_092 // $10M max -> 10006263.9212 GHO
        );
        // Vault 141 (GHO-USDe / GHO) - borrow GHO @ $0.999374
        configs_[37] = _borrowConfig(
            141,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            1_000_626_392_121_468_038_992_409, // $1M base -> 1000626.3921 GHO
            10_006_263_921_214_680_389_924_092 // $10M max -> 10006263.9212 GHO
        );
        // Vault 145 (syrupUSDC-USDC / USDC) - borrow USDC @ $0.99979
        configs_[38] = _borrowConfig(
            145,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            2_500_525_110_273, // $2.5M base -> 2500525.1103 USDC
            25_005_251_102_732 // $25M max -> 25005251.1027 USDC
        );
        // Vault 146 (syrupUSDC / USDC) - borrow USDC @ $0.99979
        configs_[39] = _borrowConfig(
            146,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            2_500_525_110_273, // $2.5M base -> 2500525.1103 USDC
            25_005_251_102_732 // $25M max -> 25005251.1027 USDC
        );
        // Vault 147 (syrupUSDC / USDT) - borrow USDT @ $0.999409
        configs_[40] = _borrowConfig(
            147,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            1_000_591_349_488, // $1M base -> 1000591.3495 USDT
            2_501_478_373_719 // $2.5M max -> 2501478.3737 USDT
        );
        // Vault 148 (syrupUSDC / GHO) - borrow GHO @ $0.999374
        configs_[41] = _borrowConfig(
            148,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            1_000_626_392_121_468_038_992_409, // $1M base -> 1000626.3921 GHO
            2_501_565_980_303_670_097_481_023 // $2.5M max -> 2501565.9803 GHO
        );
        // Vault 149 (syrupUSDT-USDT / USDT) - borrow USDT @ $0.999409
        configs_[42] = _borrowConfig(
            149,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            25_014_783_737_189 // $25M max -> 25014783.7372 USDT
        );
        // Vault 150 (syrupUSDT / USDC) - borrow USDC @ $0.99979
        configs_[43] = _borrowConfig(
            150,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            1_000_210_044_109, // $1M base -> 1000210.0441 USDC
            2_500_525_110_273 // $2.5M max -> 2500525.1103 USDC
        );
        // Vault 151 (syrupUSDT / USDT) - borrow USDT @ $0.999409
        configs_[44] = _borrowConfig(
            151,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            25_014_783_737_189 // $25M max -> 25014783.7372 USDT
        );
        // Vault 152 (syrupUSDT / GHO) - borrow GHO @ $0.999374
        configs_[45] = _borrowConfig(
            152,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            100_062_639_212_146_803_899_241, // $100K base -> 100062.6392 GHO
            1_000_626_392_121_468_038_992_409 // $1M max -> 1000626.3921 GHO
        );
        // Vault 153 (osETH / USDC) - borrow USDC @ $0.99979
        configs_[46] = _borrowConfig(
            153,
            USDC_ADDRESS,
            25 * 1e2, // 25%
            100_021_004_411, // $100K base -> 100021.0044 USDC
            1_000_210_044_109 // $1M max -> 1000210.0441 USDC
        );
        // Vault 154 (osETH / USDT) - borrow USDT @ $0.999409
        configs_[47] = _borrowConfig(
            154,
            USDT_ADDRESS,
            25 * 1e2, // 25%
            100_059_134_949, // $100K base -> 100059.1349 USDT
            1_000_591_349_488 // $1M max -> 1000591.3495 USDT
        );
        // Vault 155 (osETH / GHO) - borrow GHO @ $0.999374
        configs_[48] = _borrowConfig(
            155,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            100_062_639_212_146_803_899_241, // $100K base -> 100062.6392 GHO
            1_000_626_392_121_468_038_992_409 // $1M max -> 1000626.3921 GHO
        );
        // Vault 159 (ETH-osETH / wstETH) - borrow wstETH @ $2620.73
        configs_[49] = _borrowConfig(
            159,
            wstETH_ADDRESS,
            10 * 1e2, // 10%
            953_932_682_878_434_634_625, // $2.5M base -> 953.9327 wstETH
            9_539_326_828_784_346_346_247 // $25M max -> 9539.3268 wstETH
        );
        // Vault 160 (reUSD / USDC) - borrow USDC @ $0.99979
        configs_[50] = _borrowConfig(
            160,
            USDC_ADDRESS,
            10 * 1e2, // 10%
            2_500_525_110_273, // $2.5M base -> 2500525.1103 USDC
            20_004_200_882_185 // $20M max -> 20004200.8822 USDC
        );
        // Vault 161 (reUSD / USDT) - borrow USDT @ $0.999409
        configs_[51] = _borrowConfig(
            161,
            USDT_ADDRESS,
            10 * 1e2, // 10%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            20_011_826_989_751 // $20M max -> 20011826.9898 USDT
        );
        // Vault 162 (reUSD / GHO) - borrow GHO @ $0.999374
        configs_[52] = _borrowConfig(
            162,
            GHO_ADDRESS,
            25 * 1e2, // 25%
            2_501_565_980_303_670_097_481_023, // $2.5M base -> 2501565.9803 GHO
            20_012_527_842_429_360_779_848_185 // $20M max -> 20012527.8424 GHO
        );
        // Vault 164 (reUSD-USDT / USDT) - borrow USDT @ $0.999409
        configs_[53] = _borrowConfig(
            164,
            USDT_ADDRESS,
            10 * 1e2, // 10%
            2_501_478_373_719, // $2.5M base -> 2501478.3737 USDT
            20_011_826_989_751 // $20M max -> 20011826.9898 USDT
        );

        LIQUIDITY.updateUserBorrowConfigs(configs_);
    }

    /// @notice Action 4: Tighten smart-debt limits on the USDC-USDT DEX (id 2) (expand window 6h -> 3h, share $2.204907979983792)
    function action4() internal isActionSkippable(4) {
        address dex_ = getDexAddress(2);

        // Vault 47 (weETH / USDC-USDT): $2.5M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(47),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_133_834_165_731_658_871_386_632, // $2.5M in shares
                maxBorrowLimit: 11_338_341_657_316_588_713_866_321 // $25M in shares
            })
        );

        // Vault 50 (sUSDe / USDC-USDT): $2.5M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(50),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_133_834_165_731_658_871_386_632, // $2.5M in shares
                maxBorrowLimit: 11_338_341_657_316_588_713_866_321 // $25M in shares
            })
        );

        // Vault 98 (sUSDe-USDT / USDC-USDT): $2.5M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(98),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_133_834_165_731_658_871_386_632, // $2.5M in shares
                maxBorrowLimit: 11_338_341_657_316_588_713_866_321 // $25M in shares
            })
        );

        // Vault 99 (USDe-USDT / USDC-USDT): $2.5M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(99),
                expandPercent: 10 * 1e2, // 10%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_133_834_165_731_658_871_386_632, // $2.5M in shares
                maxBorrowLimit: 11_338_341_657_316_588_713_866_321 // $25M in shares
            })
        );

        // Vault 156 (osETH / USDC-USDT): $100K base / $1M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(156),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 45_353_366_629_266_354_855_465, // $100K in shares
                maxBorrowLimit: 453_533_666_292_663_548_554_653 // $1M in shares
            })
        );

        // Vault 163 (reUSD / USDC-USDT): $2.5M base / $20M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(163),
                expandPercent: 10 * 1e2, // 10%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_133_834_165_731_658_871_386_632, // $2.5M in shares
                maxBorrowLimit: 9_070_673_325_853_270_971_093_057 // $20M in shares
            })
        );
    }

    /// @notice Action 5: Tighten smart-debt limits on the USDC-USDT DEX (id 34) (expand window 6h -> 3h, share $2.102974865610295)
    function action5() internal isActionSkippable(5) {
        address dex_ = getDexAddress(34);

        // Vault 126 (sUSDe-USDT / USDC-USDT): $2.5M base / $50M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(126),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_188_792_144_348_566_000_699_581, // $2.5M in shares
                maxBorrowLimit: 23_775_842_886_971_320_013_991_626 // $50M in shares
            })
        );

        // Vault 127 (USDe-USDT / USDC-USDT): $2.5M base / $50M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(127),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_188_792_144_348_566_000_699_581, // $2.5M in shares
                maxBorrowLimit: 23_775_842_886_971_320_013_991_626 // $50M in shares
            })
        );

        // Vault 157 (osETH / USDC-USDT): $100K base / $1M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(157),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 47_551_685_773_942_640_027_983, // $100K in shares
                maxBorrowLimit: 475_516_857_739_426_400_279_833 // $1M in shares
            })
        );
    }

    /// @notice Action 6: Tighten smart-debt limits on the GHO-USDC DEX (id 4) (expand window 6h -> 3h, share $2.2159112801948067)
    function action6() internal isActionSkippable(6) {
        address dex_ = getDexAddress(4);

        // Vault 61 (GHO-USDC / GHO-USDC): $2.5M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(61),
                expandPercent: 10 * 1e2, // 10%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_128_204_013_556_092_507_093_688, // $2.5M in shares
                maxBorrowLimit: 11_282_040_135_560_925_070_936_876 // $25M in shares
            })
        );

        // Vault 125 (GHO-sUSDe / GHO-USDC): $1M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(125),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 451_281_605_422_437_002_837_475, // $1M in shares
                maxBorrowLimit: 11_282_040_135_560_925_070_936_876 // $25M in shares
            })
        );

        // Vault 139 (GHO-USDe / GHO-USDC): $1M base / $10M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(139),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 451_281_605_422_437_002_837_475, // $1M in shares
                maxBorrowLimit: 4_512_816_054_224_370_028_374_750 // $10M in shares
            })
        );
    }

    /// @notice Action 7: Restrict the fsUSDs fToken's base withdrawal limit on the
    ///         Liquidity Layer to its current total supply + 10%.
    /// @dev Reads the live supply position of `F_SUSDs_ADDRESS` for `sUSDs` and
    ///      caps the base withdrawal limit at `supply * 110 / 100`, preserving the
    ///      existing mode and expansion (percent / duration) so only the base
    ///      withdrawal limit is tightened.
    function action7() internal isActionSkippable(7) {
        uint256 userSupplyData_ = LIQUIDITY.readFromStorage(
            LiquiditySlotsLink.calculateDoubleMappingStorageSlot(
                LiquiditySlotsLink.LIQUIDITY_USER_SUPPLY_DOUBLE_MAPPING_SLOT,
                F_SUSDs_ADDRESS,
                sUSDs_ADDRESS
            )
        );

        uint256 totalSupplyAmount_ = BigMathMinified.fromBigNumber(
            (userSupplyData_ >> LiquiditySlotsLink.BITS_USER_SUPPLY_AMOUNT) & X64,
            DEFAULT_EXPONENT_SIZE,
            DEFAULT_EXPONENT_MASK
        );

        FluidLiquidityAdminStructs.UserSupplyConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                1
            );
        configs_[0] = FluidLiquidityAdminStructs.UserSupplyConfig({
            user: F_SUSDs_ADDRESS,
            token: sUSDs_ADDRESS,
            mode: uint8(userSupplyData_ & 1),
            expandPercent: (userSupplyData_ >>
                LiquiditySlotsLink.BITS_USER_SUPPLY_EXPAND_PERCENT) & X14,
            expandDuration: (userSupplyData_ >>
                LiquiditySlotsLink.BITS_USER_SUPPLY_EXPAND_DURATION) & X24,
            baseWithdrawalLimit: (totalSupplyAmount_ * 110) / 100 // total supply + 10%
        });

        LIQUIDITY.updateUserSupplyConfigs(configs_);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    /// @dev Build a Liquidity Layer borrow config. `baseAmount` / `maxAmount`
    ///      are denominated in the borrow token's own decimals (already
    ///      converted from USD using the per-vault override price); they are
    ///      normalised by the live borrow exchange price via `getRawAmount`.
    function _borrowConfig(
        uint256 vaultId_,
        address token_,
        uint256 expandPercent_,
        uint256 baseAmount_,
        uint256 maxAmount_
    )
        internal
        view
        returns (FluidLiquidityAdminStructs.UserBorrowConfig memory)
    {
        return
            FluidLiquidityAdminStructs.UserBorrowConfig({
                user: getVaultAddress(vaultId_),
                token: token_,
                mode: 1,
                expandPercent: expandPercent_,
                expandDuration: 3 hours,
                baseDebtCeiling: getRawAmount(token_, baseAmount_, 0, false),
                maxDebtCeiling: getRawAmount(token_, maxAmount_, 0, false)
            });
    }

    function _legacyVaultSupplyConfig(
        uint256 vaultId_,
        address supplyToken_,
        uint256 baseWithdrawalLimit_
    )
        internal
        view
        returns (FluidLiquidityAdminStructs.UserSupplyConfig memory)
    {
        return
            FluidLiquidityAdminStructs.UserSupplyConfig({
                user: getVaultAddress(vaultId_),
                token: supplyToken_,
                mode: 1,
                expandPercent: MAX_RESTRICTED_EXPAND_PERCENT,
                expandDuration: MAX_RESTRICTED_EXPAND_DURATION,
                baseWithdrawalLimit: baseWithdrawalLimit_
            });
    }

    // No `*_USD_PRICE()` overrides are needed: every limit in this payload is
    // configured in raw token / share amounts (`getRawAmount(token, amount, 0,
    // ...)` and `setDexBorrowProtocolLimitsInShares`), so `getRawAmount` returns
    // via its raw-`amount` branch and never dispatches to a USD price getter.
}
