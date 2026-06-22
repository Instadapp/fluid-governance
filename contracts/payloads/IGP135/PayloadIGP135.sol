// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {IFluidDex, IFluidAdminDex} from "../common/interfaces/IFluidDex.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP135: Legacy and sUSDS supply withdrawal tightening, risk-tightening
///         of borrow limits across 66 less-trusted Ethereum vaults, capping the
///         fsUSDs fToken base withdrawal limit to total supply + 10%, max supply
///         share caps on USR/RLP DEXes, dust limits for reUSD-USDT / USDC-USDT
///         vault (id 170) and reUSD / GHO-USDC vault (id 181), and removal of
///         launch limits on the USDai-USDC DEX (id 47) and USDai-USDC / USDC
///         T2 vault (id 180), then remove Team Multisig auth retained from the
///         IGP-134 USDai launch, and reduction of the USDC-USDT DEX (id 2) max
///         borrow shares to 20M (from 50M). 
contract PayloadIGP135 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 135;

    uint256 public constant USR_USDC_DEX_ID = 20;
    uint256 public constant RLP_USDC_DEX_ID = 28;
    uint256 public constant REUSD_USDT_DEX_ID = 44;
    uint256 public constant USDC_USDT_DEX_ID = 2;
    uint256 public constant GHO_USDC_DEX_ID = 4;
    uint256 public constant VAULT_REUSD_USDT__USDC_USDT_ID = 170;
    uint256 public constant VAULT_REUSD__GHO_USDC_ID = 181;
    uint256 public constant USDAI_USDC_DEX_ID = 47;
    uint256 public constant VAULT_USDAI_USDC__USDC_ID = 180;

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

        // Action 8: Set USR-USDC and RLP-USDC DEX max supply shares to 0
        action8();

        // Action 9: Set dust limits for reUSD TYPE_4 vaults (170, 181)
        action9();

        // Action 10: USDai-USDC DEX + T2 vault launch limits, remove Team MS auth
        action10();

        // Action 11: Reduce USDC-USDT DEX (id 2) max borrow shares to 20M
        action11();
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

        configs_[0] = _legacyVaultSupplyConfig(1, ETH_ADDRESS, 683849 * 1e12);
        configs_[1] = _legacyVaultSupplyConfig(2, ETH_ADDRESS, 1030056 * 1e12);
        configs_[2] = _legacyVaultSupplyConfig(
            3,
            wstETH_ADDRESS,
            672601 * 1e12
        );
        configs_[3] = _legacyVaultSupplyConfig(
            4,
            wstETH_ADDRESS,
            562376 * 1e12
        );
        configs_[4] = _legacyVaultSupplyConfig(
            5,
            wstETH_ADDRESS,
            568754 * 1e12
        );
        configs_[5] = _legacyVaultSupplyConfig(
            6,
            weETH_ADDRESS,
            695062874 * 1e12
        );
        configs_[6] = _legacyVaultSupplyConfig(
            7,
            sUSDe_ADDRESS,
            3298946017 * 1e12
        );
        configs_[7] = _legacyVaultSupplyConfig(
            8,
            sUSDe_ADDRESS,
            413657753 * 1e12
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
            649 * 1e18
        );
        configs_[1] = _legacyVaultSupplyConfig(
            85,
            wstETH_ADDRESS,
            9372872359 * 1e6
        );

        LIQUIDITY.updateUserSupplyConfigs(configs_);
    }

    /// @notice Action 3: Tighten Liquidity Layer borrow limits (expand window 6h -> 3h)
    /// @dev Base/max debt ceilings are expressed as whole-dollar USD targets and
    ///      resolved on-chain to each borrow token's raw amount via getRawAmount's
    ///      USD path (per-token `<TOKEN>_USD_PRICE()` getter + live borrow
    ///      exchange price). Refreshing for current prices is just a re-run of
    ///      prepare-prices.ts; the literals below never need hand-recomputing.
    function action3() internal isActionSkippable(3) {
        FluidLiquidityAdminStructs.UserBorrowConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                54
            );

        // Vault 16 (weETH / wstETH) - borrow wstETH, $2.5M base / $25M max
        configs_[0] = _borrowConfigUSD(16, wstETH_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 18 (sUSDe / USDT) - borrow USDT, $2.5M base / $25M max
        configs_[1] = _borrowConfigUSD(18, USDT_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 17 (sUSDe / USDC) - borrow USDC, $2.5M base / $25M max
        configs_[2] = _borrowConfigUSD(17, USDC_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 19 (weETH / USDC) - borrow USDC, $2.5M base / $25M max
        configs_[3] = _borrowConfigUSD(19, USDC_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 20 (weETH / USDT) - borrow USDT, $2.5M base / $25M max
        configs_[4] = _borrowConfigUSD(20, USDT_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 26 (weETH / WBTC) - borrow WBTC, $100K base / $1M max
        configs_[5] = _borrowConfigUSD(26, WBTC_ADDRESS, 25 * 1e2, 100_000, 1_000_000);
        // Vault 27 (weETHs / wstETH) - borrow wstETH, $1M base / $5M max
        configs_[6] = _borrowConfigUSD(27, wstETH_ADDRESS, 25 * 1e2, 1_000_000, 5_000_000);
        // Vault 32 (weETH / cbBTC) - borrow cbBTC, $100K base / $1M max
        configs_[7] = _borrowConfigUSD(32, cbBTC_ADDRESS, 25 * 1e2, 100_000, 1_000_000);
        // Vault 56 (sUSDe / GHO) - borrow GHO, $2.5M base / $25M max
        configs_[8] = _borrowConfigUSD(56, GHO_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 57 (weETH / GHO) - borrow GHO, $2.5M base / $25M max
        configs_[9] = _borrowConfigUSD(57, GHO_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 74 (weETH-ETH / wstETH) - borrow wstETH, $2.5M base / $50M max
        configs_[10] = _borrowConfigUSD(74, wstETH_ADDRESS, 10 * 1e2, 2_500_000, 50_000_000);
        // Vault 80 (weETHs-ETH / wstETH) - borrow wstETH, $1M base / $2.5M max
        configs_[11] = _borrowConfigUSD(80, wstETH_ADDRESS, 25 * 1e2, 1_000_000, 2_500_000);
        // Vault 92 (sUSDe-USDT / USDT) - borrow USDT, $2.5M base / $25M max
        configs_[12] = _borrowConfigUSD(92, USDT_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 93 (USDe-USDT / USDT) - borrow USDT, $2.5M base / $25M max
        configs_[13] = _borrowConfigUSD(93, USDT_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 94 (eBTC / WBTC) - borrow WBTC, $100K base / $1M max
        configs_[14] = _borrowConfigUSD(94, WBTC_ADDRESS, 25 * 1e2, 100_000, 1_000_000);
        // Vault 96 (eBTC-cbBTC / WBTC) - borrow WBTC, $100K base / $1M max
        configs_[15] = _borrowConfigUSD(96, WBTC_ADDRESS, 25 * 1e2, 100_000, 1_000_000);
        // Vault 97 (LBTC-cbBTC / WBTC) - borrow WBTC, $2.5M base / $25M max
        configs_[16] = _borrowConfigUSD(97, WBTC_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 103 (ezETH / wstETH) - borrow wstETH, $100K base / $1M max
        configs_[17] = _borrowConfigUSD(103, wstETH_ADDRESS, 25 * 1e2, 100_000, 1_000_000);
        // Vault 104 (ezETH-ETH / wstETH) - borrow wstETH, $2.5M base / $25M max
        configs_[18] = _borrowConfigUSD(104, wstETH_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 107 (LBTC / USDC) - borrow USDC, $2.5M base / $25M max
        configs_[19] = _borrowConfigUSD(107, USDC_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 108 (LBTC / USDT) - borrow USDT, $2.5M base / $25M max
        configs_[20] = _borrowConfigUSD(108, USDT_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 109 (LBTC / GHO) - borrow GHO, $2.5M base / $25M max
        configs_[21] = _borrowConfigUSD(109, GHO_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 114 (LBTC-cbBTC / cbBTC) - borrow cbBTC, $2.5M base / $25M max
        configs_[22] = _borrowConfigUSD(114, cbBTC_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 115 (WBTC-LBTC / WBTC) - borrow WBTC, $2.5M base / $25M max
        configs_[23] = _borrowConfigUSD(115, WBTC_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 116 (XAUt / USDC) - borrow USDC, $2.5M base / $25M max
        configs_[24] = _borrowConfigUSD(116, USDC_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 117 (XAUt / USDT) - borrow USDT, $2.5M base / $25M max
        configs_[25] = _borrowConfigUSD(117, USDT_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 118 (XAUt / GHO) - borrow GHO, $1M base / $10M max
        configs_[26] = _borrowConfigUSD(118, GHO_ADDRESS, 25 * 1e2, 1_000_000, 10_000_000);
        // Vault 119 (PAXG / USDC) - borrow USDC, $2.5M base / $25M max
        configs_[27] = _borrowConfigUSD(119, USDC_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 120 (PAXG / USDT) - borrow USDT, $2.5M base / $25M max
        configs_[28] = _borrowConfigUSD(120, USDT_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 121 (PAXG / GHO) - borrow GHO, $1M base / $10M max
        configs_[29] = _borrowConfigUSD(121, GHO_ADDRESS, 25 * 1e2, 1_000_000, 10_000_000);
        // Vault 122 (PAXG-XAUt / USDC) - borrow USDC, $1M base / $2.5M max
        configs_[30] = _borrowConfigUSD(122, USDC_ADDRESS, 25 * 1e2, 1_000_000, 2_500_000);
        // Vault 123 (PAXG-XAUt / USDT) - borrow USDT, $2.5M base / $25M max
        configs_[31] = _borrowConfigUSD(123, USDT_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 124 (PAXG-XAUt / GHO) - borrow GHO, $1M base / $10M max
        configs_[32] = _borrowConfigUSD(124, GHO_ADDRESS, 25 * 1e2, 1_000_000, 10_000_000);
        // Vault 130 (weETH / USDtb) - borrow USDtb, $1M base / $2.5M max
        configs_[33] = _borrowConfigUSD(130, USDTb_ADDRESS, 25 * 1e2, 1_000_000, 2_500_000);
        // Vault 137 (USDe-USDtb / USDT) - borrow USDT, $1M base / $10M max
        configs_[34] = _borrowConfigUSD(137, USDT_ADDRESS, 25 * 1e2, 1_000_000, 10_000_000);
        // Vault 138 (USDe-USDtb / USDC) - borrow USDC, $1M base / $10M max
        configs_[35] = _borrowConfigUSD(138, USDC_ADDRESS, 25 * 1e2, 1_000_000, 10_000_000);
        // Vault 140 (USDe-USDtb / GHO) - borrow GHO, $1M base / $10M max
        configs_[36] = _borrowConfigUSD(140, GHO_ADDRESS, 25 * 1e2, 1_000_000, 10_000_000);
        // Vault 141 (GHO-USDe / GHO) - borrow GHO, $1M base / $10M max
        configs_[37] = _borrowConfigUSD(141, GHO_ADDRESS, 25 * 1e2, 1_000_000, 10_000_000);
        // Vault 145 (syrupUSDC-USDC / USDC) - borrow USDC, $2.5M base / $25M max
        configs_[38] = _borrowConfigUSD(145, USDC_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 146 (syrupUSDC / USDC) - borrow USDC, $2.5M base / $25M max
        configs_[39] = _borrowConfigUSD(146, USDC_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 147 (syrupUSDC / USDT) - borrow USDT, $1M base / $2.5M max
        configs_[40] = _borrowConfigUSD(147, USDT_ADDRESS, 25 * 1e2, 1_000_000, 2_500_000);
        // Vault 148 (syrupUSDC / GHO) - borrow GHO, $1M base / $2.5M max
        configs_[41] = _borrowConfigUSD(148, GHO_ADDRESS, 25 * 1e2, 1_000_000, 2_500_000);
        // Vault 149 (syrupUSDT-USDT / USDT) - borrow USDT, $2.5M base / $25M max
        configs_[42] = _borrowConfigUSD(149, USDT_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 150 (syrupUSDT / USDC) - borrow USDC, $1M base / $2.5M max
        configs_[43] = _borrowConfigUSD(150, USDC_ADDRESS, 25 * 1e2, 1_000_000, 2_500_000);
        // Vault 151 (syrupUSDT / USDT) - borrow USDT, $2.5M base / $25M max
        configs_[44] = _borrowConfigUSD(151, USDT_ADDRESS, 25 * 1e2, 2_500_000, 25_000_000);
        // Vault 152 (syrupUSDT / GHO) - borrow GHO, $100K base / $1M max
        configs_[45] = _borrowConfigUSD(152, GHO_ADDRESS, 25 * 1e2, 100_000, 1_000_000);
        // Vault 153 (osETH / USDC) - borrow USDC, $100K base / $1M max
        configs_[46] = _borrowConfigUSD(153, USDC_ADDRESS, 25 * 1e2, 100_000, 1_000_000);
        // Vault 154 (osETH / USDT) - borrow USDT, $100K base / $1M max
        configs_[47] = _borrowConfigUSD(154, USDT_ADDRESS, 25 * 1e2, 100_000, 1_000_000);
        // Vault 155 (osETH / GHO) - borrow GHO, $100K base / $1M max
        configs_[48] = _borrowConfigUSD(155, GHO_ADDRESS, 25 * 1e2, 100_000, 1_000_000);
        // Vault 159 (ETH-osETH / wstETH) - borrow wstETH, $2.5M base / $25M max
        configs_[49] = _borrowConfigUSD(159, wstETH_ADDRESS, 10 * 1e2, 2_500_000, 25_000_000);
        // Vault 160 (reUSD / USDC) - borrow USDC, $2.5M base / $20M max
        configs_[50] = _borrowConfigUSD(160, USDC_ADDRESS, 10 * 1e2, 2_500_000, 20_000_000);
        // Vault 161 (reUSD / USDT) - borrow USDT, $2.5M base / $20M max
        configs_[51] = _borrowConfigUSD(161, USDT_ADDRESS, 10 * 1e2, 2_500_000, 20_000_000);
        // Vault 162 (reUSD / GHO) - borrow GHO, $2.5M base / $20M max
        configs_[52] = _borrowConfigUSD(162, GHO_ADDRESS, 25 * 1e2, 2_500_000, 20_000_000);
        // Vault 164 (reUSD-USDT / USDT) - borrow USDT, $2.5M base / $20M max
        configs_[53] = _borrowConfigUSD(164, USDT_ADDRESS, 10 * 1e2, 2_500_000, 20_000_000);

        LIQUIDITY.updateUserBorrowConfigs(configs_);
    }

    /// @notice Action 4: Tighten smart-debt limits on the USDC-USDT DEX (id 2) (expand window 6h -> 3h, share $2.21819925785469)
    function action4() internal isActionSkippable(4) {
        address dex_ = getDexAddress(2);

        // Vault 47 (weETH / USDC-USDT): $2.5M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(47),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_127_040_319_370_520_117_116_771, // $2.5M in shares
                maxBorrowLimit: 11_270_403_193_705_201_171_167_710 // $25M in shares
            })
        );

        // Vault 50 (sUSDe / USDC-USDT): $2.5M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(50),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_127_040_319_370_520_117_116_771, // $2.5M in shares
                maxBorrowLimit: 11_270_403_193_705_201_171_167_710 // $25M in shares
            })
        );

        // Vault 98 (sUSDe-USDT / USDC-USDT): $2.5M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(98),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_127_040_319_370_520_117_116_771, // $2.5M in shares
                maxBorrowLimit: 11_270_403_193_705_201_171_167_710 // $25M in shares
            })
        );

        // Vault 99 (USDe-USDT / USDC-USDT): $2.5M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(99),
                expandPercent: 10 * 1e2, // 10%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_127_040_319_370_520_117_116_771, // $2.5M in shares
                maxBorrowLimit: 11_270_403_193_705_201_171_167_710 // $25M in shares
            })
        );

        // Vault 156 (osETH / USDC-USDT): $100K base / $1M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(156),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 45_081_612_774_820_804_684_671, // $100K in shares
                maxBorrowLimit: 450_816_127_748_208_046_846_708 // $1M in shares
            })
        );

        // Vault 163 (reUSD / USDC-USDT): $2.5M base / $20M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(163),
                expandPercent: 10 * 1e2, // 10%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_127_040_319_370_520_117_116_771, // $2.5M in shares
                maxBorrowLimit: 9_016_322_554_964_160_936_934_168 // $20M in shares
            })
        );
    }

    /// @notice Action 5: Tighten smart-debt limits on the USDC-USDT DEX (id 34) (expand window 6h -> 3h, share $2.117342491154468)
    function action5() internal isActionSkippable(5) {
        address dex_ = getDexAddress(34);

        // Vault 126 (sUSDe-USDT / USDC-USDT): $2.5M base / $50M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(126),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_180_725_371_754_519_788_235_031, // $2.5M in shares
                maxBorrowLimit: 23_614_507_435_090_395_764_700_613 // $50M in shares
            })
        );

        // Vault 127 (USDe-USDT / USDC-USDT): $2.5M base / $50M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(127),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_180_725_371_754_519_788_235_031, // $2.5M in shares
                maxBorrowLimit: 23_614_507_435_090_395_764_700_613 // $50M in shares
            })
        );

        // Vault 157 (osETH / USDC-USDT): $100K base / $1M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(157),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 47_229_014_870_180_791_529_401, // $100K in shares
                maxBorrowLimit: 472_290_148_701_807_915_294_012 // $1M in shares
            })
        );
    }

    /// @notice Action 6: Tighten smart-debt limits on the GHO-USDC DEX (id 4) (expand window 6h -> 3h, share $2.229149988527353)
    function action6() internal isActionSkippable(6) {
        address dex_ = getDexAddress(4);

        // Vault 61 (GHO-USDC / GHO-USDC): $2.5M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(61),
                expandPercent: 10 * 1e2, // 10%
                expandDuration: 3 hours,
                baseBorrowLimit: 1_121_503_717_949_270_340_045_681, // $2.5M in shares
                maxBorrowLimit: 11_215_037_179_492_703_400_456_808 // $25M in shares
            })
        );

        // Vault 125 (GHO-sUSDe / GHO-USDC): $1M base / $25M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(125),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 448_601_487_179_708_136_018_272, // $1M in shares
                maxBorrowLimit: 11_215_037_179_492_703_400_456_808 // $25M in shares
            })
        );

        // Vault 139 (GHO-USDe / GHO-USDC): $1M base / $10M max
        setDexBorrowProtocolLimitsInShares(
            DexBorrowProtocolConfigInShares({
                dex: dex_,
                protocol: getVaultAddress(139),
                expandPercent: 25 * 1e2, // 25%
                expandDuration: 3 hours,
                baseBorrowLimit: 448_601_487_179_708_136_018_272, // $1M in shares
                maxBorrowLimit: 4_486_014_871_797_081_360_182_723 // $10M in shares
            })
        );
    }

    /// @notice Action 7: Restrict the fsUSDs fToken's base withdrawal limit on the
    ///         Liquidity Layer to total supply + 10%.
    /// @dev Sets a fixed base withdrawal limit of `5,516.87` sUSDs (the `5,015.34`
    ///      sUSDs fsUSDs supply at preparation time * 1.1). The existing mode and
    ///      expansion (percent / duration) are read from storage and preserved,
    ///      so only the base withdrawal limit is tightened.
    function action7() internal isActionSkippable(7) {
        uint256 userSupplyData_ = LIQUIDITY.readFromStorage(
            LiquiditySlotsLink.calculateDoubleMappingStorageSlot(
                LiquiditySlotsLink.LIQUIDITY_USER_SUPPLY_DOUBLE_MAPPING_SLOT,
                F_SUSDs_ADDRESS,
                sUSDs_ADDRESS
            )
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
            baseWithdrawalLimit: 5516.87 * 1e18 // 5,015.34 sUSDs * 1.1 = 5,516.87 sUSDs
        });

        LIQUIDITY.updateUserSupplyConfigs(configs_);
    }

    /// @notice Action 8: Set USR-USDC (DEX 20) and RLP-USDC (DEX 28) max supply shares to 0
    function action8() internal isActionSkippable(8) {
        IFluidDex(getDexAddress(USR_USDC_DEX_ID)).updateMaxSupplyShares(0);
        IFluidDex(getDexAddress(RLP_USDC_DEX_ID)).updateMaxSupplyShares(0);
    }

    /// @notice Action 9: Set dust limits for reUSD-USDT / USDC-USDT (170, TYPE_4)
    ///         and reUSD / GHO-USDC (181, TYPE_3) vaults
    function action9() internal isActionSkippable(9) {
        // Vault 170: reUSD-USDT / USDC-USDT (TYPE_4) — smart col at DEX 44,
        // smart debt at USDC-USDT DEX (id 2)
        {
            address REUSD_USDT_DEX = getDexAddress(REUSD_USDT_DEX_ID);
            address USDC_USDT_DEX = getDexAddress(USDC_USDT_DEX_ID);
            address REUSD_USDT__USDC_USDT_VAULT = getVaultAddress(
                VAULT_REUSD_USDT__USDC_USDT_ID
            );

            {
                IFluidAdminDex.UserSupplyConfig[]
                    memory supplyConfigs_ = new IFluidAdminDex.UserSupplyConfig[](
                        1
                    );
                supplyConfigs_[0] = IFluidAdminDex.UserSupplyConfig({
                    user: REUSD_USDT__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseWithdrawalLimit: 3_528_489_595_928_988_517_513 // ~$7k in DEX 44 shares @ $1.9839/share
                });
                IFluidDex(REUSD_USDT_DEX).updateUserSupplyConfigs(
                    supplyConfigs_
                );
            }

            setDexBorrowProtocolLimitsInShares(
                DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: REUSD_USDT__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3_155_712_894_237_456_327_927, // ~$7k in DEX 2 shares @ $2.2182/share
                    maxBorrowLimit: 4_057_345_149_733_872_421_620 // ~$9k in DEX 2 shares
                })
            );

            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                REUSD_USDT__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 181: REUSD / GHO-USDC (TYPE_3) — $7k REUSD supply;
        // GHO-USDC DEX (id 4) borrow shares ~$7k / ~$9k
        {
            address GHO_USDC_DEX = getDexAddress(GHO_USDC_DEX_ID);
            address REUSD__GHO_USDC_VAULT = getVaultAddress(
                VAULT_REUSD__GHO_USDC_ID
            );

            VaultConfig memory VAULT_REUSD__GHO_USDC = VaultConfig({
                vault: REUSD__GHO_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_3,
                supplyToken: REUSD_ADDRESS,
                borrowToken: address(0),
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setVaultLimits(VAULT_REUSD__GHO_USDC);

            setDexBorrowProtocolLimitsInShares(
                DexBorrowProtocolConfigInShares({
                    dex: GHO_USDC_DEX,
                    protocol: REUSD__GHO_USDC_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3_140_210_410_257_956_952_128, // ~$7k in DEX 4 shares @ $2.2291/share
                    maxBorrowLimit: 4_037_413_384_617_373_224_164 // ~$9k in DEX 4 shares
                })
            );

            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                REUSD__GHO_USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }
    }

    /// @notice Action 10: Raise the USDai-USDC market (DEX 47 + vault 180) from
    ///         dust limits (IGP-134) to launch limits, then remove Team Multisig
    ///         auth on both.
    function action10() internal isActionSkippable(10) {
        // DEX 47: USDai-USDC — smart-collateral token limits $5M each;
        // remove Team MS auth
        {
            address USDAI_USDC_DEX = getDexAddress(USDAI_USDC_DEX_ID);
            DexConfig memory DEX_USDAI_USDC = DexConfig({
                dex: USDAI_USDC_DEX,
                tokenA: USDAI_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 5_000_000, // $5M
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_USDAI_USDC);
            DEX_FACTORY.setDexAuth(USDAI_USDC_DEX, TEAM_MULTISIG, false);
        }

        // Vault 180: USDai-USDC / USDC (TYPE_2) — borrow-side launch limits only;
        // remove Team MS auth
        {
            address USDAI_USDC__USDC_VAULT = getVaultAddress(
                VAULT_USDAI_USDC__USDC_ID
            );
            VaultConfig memory VAULT_USDAI_USDC__USDC = VaultConfig({
                vault: USDAI_USDC__USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 10_000_000 // $10M
            });
            setVaultLimits(VAULT_USDAI_USDC__USDC);
            VAULT_FACTORY_WRAPPER_OWNER.setVaultAuth(
                USDAI_USDC__USDC_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
    }

    /// @notice Action 11: Reduce the USDC-USDT DEX (id 2) max borrow shares to
    ///         20M (from 50M) as overall stable liquidity has thinned.
    function action11() internal isActionSkippable(11) {
        IFluidDex(getDexAddress(USDC_USDT_DEX_ID)).updateMaxBorrowShares(
            20_000_000 * 1e18 // 20M shares (from 50M)
        );
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    /// @dev Build a Liquidity Layer borrow config from USD targets. `baseUSD_` /
    ///      `maxUSD_` are whole-dollar amounts; getRawAmount's USD path resolves
    ///      them to the borrow token's raw amount using the per-token
    ///      `<TOKEN>_USD_PRICE()` getter and the live borrow exchange price.
    ///      Refreshing prices is therefore just a re-run of prepare-prices.ts —
    ///      the inline amounts here never need to be hand-recomputed.
    function _borrowConfigUSD(
        uint256 vaultId_,
        address token_,
        uint256 expandPercent_,
        uint256 baseUSD_,
        uint256 maxUSD_
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
                baseDebtCeiling: getRawAmount(token_, 0, baseUSD_, false),
                maxDebtCeiling: getRawAmount(token_, 0, maxUSD_, false)
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

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-06-22T07:46:25.485Z, source: coingecko
    function BTC_USD_PRICE()    public pure override returns (uint256) { return 64_000 * 1e2; }
    function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    function REUSD_USD_PRICE()  public pure override returns (uint256) { return 1.09 * 1e2; }
    function wstETH_USD_PRICE() public pure override returns (uint256) { return 2_160 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
