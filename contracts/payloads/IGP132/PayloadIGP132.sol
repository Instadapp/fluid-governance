// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {IFluidDex} from "../common/interfaces/IFluidDex.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP132: Tightened base withdrawal limits on legacy vaults 1–10, USDai
///         ecosystem dust limits, max supply share caps on USR/RLP DEXes, USDC/USDT
///         rate curve updates, iETHv2 revenue claim, and sUSDS vault sunset
///         withdrawal caps. Lite revenue amount is configurable by Team Multisig
///         before execution.
contract PayloadIGP132 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 132;

    uint256 public constant USR_USDC_DEX_ID = 20;
    uint256 public constant RLP_USDC_DEX_ID = 28;

    // --- USDai ecosystem ids (deployments receive these ids when batched) ---
    uint256 public constant USDAI_USDC_DEX_ID = 46;
    uint256 public constant SUSDAI_USDC_DEX_ID = 47;
    uint256 public constant SUSDAI_USDT_DEX_ID = 48;

    uint256 public constant VAULT_USDAI_USDC_ID = 170; // T1: USDai / USDC
    uint256 public constant VAULT_SUSDAI_USDC_ID = 171; // T1: sUSDai / USDC
    uint256 public constant VAULT_SUSDAI_USDT_ID = 172; // T1: sUSDai / USDT
    uint256 public constant VAULT_SUSDAI__USDC_USDT_ID = 173; // T3: sUSDai / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDC__USDC_USDT_ID = 174; // T4: sUSDai-USDC / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDT__USDC_USDT_ID = 175; // T4: sUSDai-USDT / USDC-USDT
    uint256 public constant VAULT_SUSDAI_USDT__USDT_ID = 176; // T2: sUSDai-USDT / USDT
    uint256 public constant VAULT_SUSDAI_USDC__USDC_ID = 177; // T2: sUSDai-USDC / USDC

    uint256 public liteStethRevenueAmount;

    function setLiteStethRevenueAmount(uint256 liteStethRevenueAmount_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        liteStethRevenueAmount = liteStethRevenueAmount_;
    }

    function execute() public virtual override {
        super.execute();

        // Action 1: Reduce base withdrawal limits on legacy vaults 1–10
        action1();

        // Action 2: USDai ecosystem dust limits (DEXes 46–48, vaults 170–177)
        action2();

        // Action 3: Set USR-USDC and RLP-USDC DEX max supply shares to 0
        action3();

        // Action 4: Update USDC and USDT rate curves (max 15% at 100% utilization)
        action4();

        // Action 5: Claim iETHv2 (Lite) stETH revenue to Team Multisig
        action5();

        // Action 6: Restrict base withdrawal limits on sUSDS sunset vaults 58 and 85
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

    /// @notice Action 1: Set legacy vault 1–10 base withdrawal limits to total supply + 5%
    function action1() internal isActionSkippable(1) {
        FluidLiquidityAdminStructs.UserSupplyConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                10
            );

        // ETH / USDC — 0.628187 ETH (0.598274 supplied + 5%)
        configs_[0] = _legacyVaultSupplyConfig(1, ETH_ADDRESS, 628187 * 1e12);
        // ETH / USDT — 0.945974 ETH
        configs_[1] = _legacyVaultSupplyConfig(2, ETH_ADDRESS, 945974 * 1e12);
        // wstETH / ETH — 0.646899 wstETH
        configs_[2] = _legacyVaultSupplyConfig(
            3,
            wstETH_ADDRESS,
            646899 * 1e12
        );
        // wstETH / USDC — 0.544134 wstETH
        configs_[3] = _legacyVaultSupplyConfig(
            4,
            wstETH_ADDRESS,
            544134 * 1e12
        );
        // wstETH / USDT — 0.549870 wstETH
        configs_[4] = _legacyVaultSupplyConfig(
            5,
            wstETH_ADDRESS,
            549870 * 1e12
        );
        // weETH / wstETH — 695.132095 weETH
        configs_[5] = _legacyVaultSupplyConfig(
            6,
            weETH_ADDRESS,
            695132095 * 1e12
        );
        // sUSDe / USDC — 3298.946018 sUSDe
        configs_[6] = _legacyVaultSupplyConfig(
            7,
            sUSDe_ADDRESS,
            3298946018 * 1e12
        );
        // sUSDe / USDT — 413.657754 sUSDe
        configs_[7] = _legacyVaultSupplyConfig(
            8,
            sUSDe_ADDRESS,
            413657754 * 1e12
        );
        // weETH / USDC — 0.240487 weETH
        configs_[8] = _legacyVaultSupplyConfig(
            9,
            weETH_ADDRESS,
            240487 * 1e12
        );
        // weETH / USDT — 0.213728 weETH
        configs_[9] = _legacyVaultSupplyConfig(
            10,
            weETH_ADDRESS,
            213728 * 1e12
        );

        LIQUIDITY.updateUserSupplyConfigs(configs_);
    }

    /// @notice Action 2: Dust limits for USDai ecosystem (DEXes 46–48, vaults 170–177)
    function action2() internal isActionSkippable(2) {
        address USDC_USDT_DEX = getDexAddress(2);

        // DEX 46: USDai-USDC
        {
            address USDAI_USDC_DEX = getDexAddress(USDAI_USDC_DEX_ID);
            DexConfig memory DEX_USDAI_USDC = DexConfig({
                dex: USDAI_USDC_DEX,
                tokenA: USDAI_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_USDAI_USDC);
            DEX_FACTORY.setDexAuth(USDAI_USDC_DEX, TEAM_MULTISIG, true);
        }

        // DEX 47: sUSDai-USDC
        {
            address SUSDAI_USDC_DEX = getDexAddress(SUSDAI_USDC_DEX_ID);
            DexConfig memory DEX_SUSDAI_USDC = DexConfig({
                dex: SUSDAI_USDC_DEX,
                tokenA: SUSDAI_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_SUSDAI_USDC);
            DEX_FACTORY.setDexAuth(SUSDAI_USDC_DEX, TEAM_MULTISIG, true);
        }

        // DEX 48: sUSDai-USDT
        {
            address SUSDAI_USDT_DEX = getDexAddress(SUSDAI_USDT_DEX_ID);
            DexConfig memory DEX_SUSDAI_USDT = DexConfig({
                dex: SUSDAI_USDT_DEX,
                tokenA: SUSDAI_ADDRESS,
                tokenB: USDT_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_SUSDAI_USDT);
            DEX_FACTORY.setDexAuth(SUSDAI_USDT_DEX, TEAM_MULTISIG, true);
        }

        // Vault 170: USDai / USDC (TYPE_1)
        {
            address USDAI_USDC_VAULT = getVaultAddress(VAULT_USDAI_USDC_ID);
            VaultConfig memory VAULT_USDAI_USDC = VaultConfig({
                vault: USDAI_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: USDAI_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_USDAI_USDC);
            VAULT_FACTORY.setVaultAuth(
                USDAI_USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 171: sUSDai / USDC (TYPE_1)
        {
            address SUSDAI_USDC_VAULT = getVaultAddress(VAULT_SUSDAI_USDC_ID);
            VaultConfig memory VAULT_SUSDAI_USDC = VaultConfig({
                vault: SUSDAI_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDC);
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 172: sUSDai / USDT (TYPE_1)
        {
            address SUSDAI_USDT_VAULT = getVaultAddress(VAULT_SUSDAI_USDT_ID);
            VaultConfig memory VAULT_SUSDAI_USDT = VaultConfig({
                vault: SUSDAI_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDT);
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 173: sUSDai / USDC-USDT (TYPE_3)
        {
            address SUSDAI__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI__USDC_USDT_ID
            );
            VaultConfig memory VAULT_SUSDAI__USDC_USDT = VaultConfig({
                vault: SUSDAI__USDC_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_3,
                supplyToken: SUSDAI_ADDRESS,
                borrowToken: address(0),
                baseWithdrawalLimitInUSD: 7_000, // $7k
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setVaultLimits(VAULT_SUSDAI__USDC_USDT);
            VAULT_FACTORY.setVaultAuth(
                SUSDAI__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 174: sUSDai-USDC / USDC-USDT (TYPE_4)
        {
            address SUSDAI_USDC__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDC__USDC_USDT_ID
            );
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDC__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI_USDC__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 175: sUSDai-USDT / USDC-USDT (TYPE_4)
        {
            address SUSDAI_USDT__USDC_USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDT__USDC_USDT_ID
            );
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDT__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                true
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: SUSDAI_USDT__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 3500 * 1e18, // ~$7k shares
                    maxBorrowLimit: 4500 * 1e18 // ~$9k shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 176: sUSDai-USDT / USDT (TYPE_2)
        {
            address SUSDAI_USDT__USDT_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDT__USDT_ID
            );
            VaultConfig memory VAULT_SUSDAI_USDT__USDT = VaultConfig({
                vault: SUSDAI_USDT__USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDT__USDT);
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDT__USDT_VAULT,
                TEAM_MULTISIG,
                true
            );
        }

        // Vault 177: sUSDai-USDC / USDC (TYPE_2)
        {
            address SUSDAI_USDC__USDC_VAULT = getVaultAddress(
                VAULT_SUSDAI_USDC__USDC_ID
            );
            VaultConfig memory VAULT_SUSDAI_USDC__USDC = VaultConfig({
                vault: SUSDAI_USDC__USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 7_000, // $7k
                maxBorrowLimitInUSD: 9_000 // $9k
            });
            setVaultLimits(VAULT_SUSDAI_USDC__USDC);
            VAULT_FACTORY.setVaultAuth(
                SUSDAI_USDC__USDC_VAULT,
                TEAM_MULTISIG,
                true
            );
        }
    }

    /// @notice Action 3: Set USR-USDC (DEX 20) and RLP-USDC (DEX 28) max supply shares to 0
    function action3() internal isActionSkippable(3) {
        IFluidDex(getDexAddress(USR_USDC_DEX_ID)).updateMaxSupplyShares(0);
        IFluidDex(getDexAddress(RLP_USDC_DEX_ID)).updateMaxSupplyShares(0);
    }

    /// @notice Action 4: Update USDC and USDT rate curves — max 15% at 100% utilization
    function action4() internal isActionSkippable(4) {
        FluidLiquidityAdminStructs.RateDataV2Params[]
            memory params_ = new FluidLiquidityAdminStructs.RateDataV2Params[](
                2
            );

        params_[0] = FluidLiquidityAdminStructs.RateDataV2Params({
            token: USDC_ADDRESS,
            kink1: 85 * 1e2, // 85%
            kink2: 93 * 1e2, // 93%
            rateAtUtilizationZero: 0, // 0%
            rateAtUtilizationKink1: 6 * 1e2, // 6%
            rateAtUtilizationKink2: 8 * 1e2, // 8%
            rateAtUtilizationMax: 15 * 1e2 // 15%
        });

        params_[1] = FluidLiquidityAdminStructs.RateDataV2Params({
            token: USDT_ADDRESS,
            kink1: 85 * 1e2, // 85%
            kink2: 93 * 1e2, // 93%
            rateAtUtilizationZero: 0, // 0%
            rateAtUtilizationKink1: 6 * 1e2, // 6%
            rateAtUtilizationKink2: 8 * 1e2, // 8%
            rateAtUtilizationMax: 15 * 1e2 // 15%
        });

        LIQUIDITY.updateRateDataV2s(params_);
    }

    /// @notice Action 5: Claim iETHv2 (Lite) stETH revenue to Team Multisig
    function action5() internal isActionSkippable(5) {
        uint256 stethAmount_ = PayloadIGP132(ADDRESS_THIS).liteStethRevenueAmount();
        require(stethAmount_ != 0, "lite-revenue-amount-not-set");

        IETHV2.collectRevenue(stethAmount_);

        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-A";
        encodedSpells_[0] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            stETH_ADDRESS,
            stethAmount_,
            TEAM_MULTISIG,
            0,
            0
        );

        TREASURY.cast(targets_, encodedSpells_, address(this));
    }

    /// @notice Action 6: Restrict base withdrawal limits on sUSDS sunset vaults
    function action6() internal isActionSkippable(6) {
        FluidLiquidityAdminStructs.UserSupplyConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                2
            );

        // sUSDS / GHO (vault 58) — 650 sUSDS
        configs_[0] = _legacyVaultSupplyConfig(
            58,
            sUSDs_ADDRESS,
            650 * 1e18
        );
        // wstETH / sUSDS (vault 85) — ~0.009372630468 wstETH
        configs_[1] = _legacyVaultSupplyConfig(
            85,
            wstETH_ADDRESS,
            9372630468 * 1e6
        );

        LIQUIDITY.updateUserSupplyConfigs(configs_);
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

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // fetched: 2026-05-30T11:25:35.114Z, source: coingecko
    function ETH_USD_PRICE()    public pure override returns (uint256) { return 2_010 * 1e2; }
    function SUSDAI_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    function sUSDe_USD_PRICE()  public pure override returns (uint256) { return 1.23 * 1e2; }
    function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    function weETH_USD_PRICE()  public pure override returns (uint256) { return 2_200 * 1e2; }
    function wstETH_USD_PRICE() public pure override returns (uint256) { return 2_480 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
