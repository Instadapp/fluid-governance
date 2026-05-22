// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {
    IFluidDex,
    IFluidAdminDex
} from "../common/interfaces/IFluidDex.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP131: wstUSR vault maintenance, FLUID rewards funding, PST
///         ecosystem launch limits, and DSA connector Chief auth cleanup.
contract PayloadIGP131 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 131;

    // --- PST ecosystem ids ---------------------------------------------
    uint256 public constant PST_USDC_DEX_ID = 45;

    uint256 public constant VAULT_PST_USDC_ID = 165; // T1: PST / USDC
    uint256 public constant VAULT_PST_USDT_ID = 166; // T1: PST / USDT
    uint256 public constant VAULT_PST_USDC__USDC_ID = 167; // T2: PST-USDC / USDC
    uint256 public constant VAULT_PST__USDC_USDT_ID = 168; // T3: PST / USDC-USDT
    uint256 public constant VAULT_PST_USDC__USDC_USDT_ID = 169; // T4: PST-USDC / USDC-USDT

    function execute() public virtual override {
        super.execute();

        // Action 1: Set vault 142 wstUSR withdrawal limit to 24 raw units
        action1();

        // Action 2: Rebalance wstUSR vaults and restore borrow restrictions
        action2();

        // Action 3: Withdraw FLUID rewards funding to Team Multisig
        action3();

        // Action 4: Set PST ecosystem launch limits (PST-USDC DEX + five PST vaults)
        action4();

        // Action 5: Remove DSA connector Chief auths except Team Multisig
        action5();
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

    /// @notice Action 1: Set vault 142 wstUSR withdrawal limit to 24 raw units
    function action1() internal isActionSkippable(1) {
        FluidLiquidityAdminStructs.UserSupplyConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                1
            );

        configs_[0] = FluidLiquidityAdminStructs.UserSupplyConfig({
            user: getVaultAddress(142), // wstUSR / USDtb
            token: wstUSR_ADDRESS,
            mode: 1,
            expandPercent: MAX_RESTRICTED_EXPAND_PERCENT,
            expandDuration: MAX_RESTRICTED_EXPAND_DURATION,
            baseWithdrawalLimit: 24 * 1e18
        });

        LIQUIDITY.updateUserSupplyConfigs(configs_);
    }

    /// @notice Action 2: Rebalance wstUSR vaults and restore borrow restrictions
    function action2() internal isActionSkippable(2) {
        // Base and max are equal: 2x the dust snapshot caps, rounded up to a
        // whole token amount so rebalance operate() is not limit-bound.
        FluidLiquidityAdminStructs.UserBorrowConfig[]
            memory liquidityConfigs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                4
            );

        liquidityConfigs_[0] = _liquidityBorrowConfig(
            getVaultAddress(110), // wstUSR / USDC
            USDC_ADDRESS,
            9 * 1e6
        );
        liquidityConfigs_[1] = _liquidityBorrowConfig(
            getVaultAddress(111), // wstUSR / USDT
            USDT_ADDRESS,
            7 * 1e6
        );
        liquidityConfigs_[2] = _liquidityBorrowConfig(
            getVaultAddress(112), // wstUSR / GHO
            GHO_ADDRESS,
            1 * 1e18
        );
        liquidityConfigs_[3] = _liquidityBorrowConfig(
            getVaultAddress(133), // wstUSR-USDC <> USDC
            USDC_ADDRESS,
            2 * 1e6
        );
        LIQUIDITY.updateUserBorrowConfigs(liquidityConfigs_);

        address USDC_USDT_DEX = getDexAddress(2);
        address USDC_USDT_CONCENTRATED_DEX = getDexAddress(34);

        IFluidAdminDex.UserBorrowConfig[]
            memory dexConfigs_ = new IFluidAdminDex.UserBorrowConfig[](1);

        dexConfigs_[0] = _dexBorrowConfig(
            getVaultAddress(134), // wstUSR-USDC <> USDC-USDT
            1 * 1e18
        );
        IFluidDex(USDC_USDT_DEX).updateUserBorrowConfigs(dexConfigs_);

        dexConfigs_[0] = _dexBorrowConfig(
            getVaultAddress(135), // wstUSR-USDC <> USDC-USDT concentrated
            1 * 1e18
        );
        IFluidDex(USDC_USDT_CONCENTRATED_DEX).updateUserBorrowConfigs(
            dexConfigs_
        );

        FLUID_RESERVE.updateRebalancer(address(TIMELOCK), true);

        {
            address[] memory vaults_ = new address[](3);
            uint256[] memory values_ = new uint256[](3);

            vaults_[0] = getVaultAddress(110);
            vaults_[1] = getVaultAddress(111);
            vaults_[2] = getVaultAddress(112);

            FLUID_RESERVE.rebalanceVaults(vaults_, values_);
        }

        {
            address[] memory vaults_ = new address[](3);
            uint256[] memory values_ = new uint256[](3);
            int256[] memory emptyMinMaxs_ = new int256[](3);
            int256[] memory debtToken0MinMaxs_ = new int256[](3);
            int256[] memory debtToken1MinMaxs_ = new int256[](3);

            vaults_[0] = getVaultAddress(133);
            vaults_[1] = getVaultAddress(134);
            vaults_[2] = getVaultAddress(135);

            // Direct-borrow T2 vault 133 does not use smart-debt min/max values.
            debtToken0MinMaxs_[1] = int256(1 * 1e6); // USDC
            debtToken1MinMaxs_[1] = int256(1 * 1e6); // USDT
            debtToken0MinMaxs_[2] = int256(1 * 1e6); // USDC
            debtToken1MinMaxs_[2] = int256(1 * 1e6); // USDT

            FLUID_RESERVE.rebalanceDexVaults(
                vaults_,
                values_,
                emptyMinMaxs_,
                emptyMinMaxs_,
                debtToken0MinMaxs_,
                debtToken1MinMaxs_
            );
        }

        setBorrowProtocolLimitsPaused(getVaultAddress(110), USDC_ADDRESS);
        setBorrowProtocolLimitsPaused(getVaultAddress(111), USDT_ADDRESS);
        setBorrowProtocolLimitsPaused(getVaultAddress(112), GHO_ADDRESS);
        setBorrowProtocolLimitsPaused(getVaultAddress(133), USDC_ADDRESS);

        setBorrowProtocolLimitsPausedDex(USDC_USDT_DEX, getVaultAddress(134));
        setBorrowProtocolLimitsPausedDex(
            USDC_USDT_CONCENTRATED_DEX,
            getVaultAddress(135)
        );

        FLUID_RESERVE.updateRebalancer(address(TIMELOCK), false);
    }

    /// @notice Action 3: Withdraw 750,000 FLUID from Treasury to Team Multisig for rewards
    function action3() internal isActionSkippable(3) {
        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-A";
        encodedSpells_[0] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            FLUID_ADDRESS,
            750_000 * 1e18,
            TEAM_MULTISIG,
            0,
            0
        );

        TREASURY.cast(targets_, encodedSpells_, address(this));
    }

    /// @notice Action 4: Launch limits for the PST ecosystem (PST-USDC DEX + five PST vaults)
    function action4() internal isActionSkippable(4) {
        address USDC_USDT_DEX = getDexAddress(2);

        // Vault 1: PST / USDC (TYPE_1)
        {
            address PST_USDC_VAULT = getVaultAddress(VAULT_PST_USDC_ID);
            VaultConfig memory VAULT_PST_USDC = VaultConfig({
                vault: PST_USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: PST_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 10_000_000 // $10M
            });
            setVaultLimits(VAULT_PST_USDC);
            FLUID_VAULT_FACTORY_OWNER.setVaultAuth(
                PST_USDC_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        // Vault 2: PST / USDT (TYPE_1)
        {
            address PST_USDT_VAULT = getVaultAddress(VAULT_PST_USDT_ID);
            VaultConfig memory VAULT_PST_USDT = VaultConfig({
                vault: PST_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: PST_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 5_000_000, // $5M
                maxBorrowLimitInUSD: 10_000_000 // $10M
            });
            setVaultLimits(VAULT_PST_USDT);
            FLUID_VAULT_FACTORY_OWNER.setVaultAuth(
                PST_USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        // Vault 3: PST-USDC / USDC (TYPE_2) — remove Team MS auth only; launch limits
        // (LL borrow + smart-col withdrawal at PST-USDC DEX) to be added in a follow-up if needed.
        {
            address PST_USDC__USDC_VAULT = getVaultAddress(
                VAULT_PST_USDC__USDC_ID
            );
            FLUID_VAULT_FACTORY_OWNER.setVaultAuth(
                PST_USDC__USDC_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        // Vault 4: PST / USDC-USDT (TYPE_3) - smart debt at USDC-USDT DEX (id 2)
        {
            address PST__USDC_USDT_VAULT = getVaultAddress(
                VAULT_PST__USDC_USDT_ID
            );
            VaultConfig memory VAULT_PST__USDC_USDT = VaultConfig({
                vault: PST__USDC_USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_3,
                supplyToken: PST_ADDRESS,
                borrowToken: address(0),
                baseWithdrawalLimitInUSD: 8_000_000, // $8M
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setVaultLimits(VAULT_PST__USDC_USDT);
            FLUID_VAULT_FACTORY_OWNER.setVaultAuth(
                PST__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                false
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: PST__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 2_500_000 * 1e18, // ~$5M shares
                    maxBorrowLimit: 5_000_000 * 1e18 // ~$10M shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // Vault 5: PST-USDC / USDC-USDT (TYPE_4) - smart col at PST-USDC DEX, smart debt at USDC-USDT DEX
        {
            address PST_USDC__USDC_USDT_VAULT = getVaultAddress(
                VAULT_PST_USDC__USDC_USDT_ID
            );

            FLUID_VAULT_FACTORY_OWNER.setVaultAuth(
                PST_USDC__USDC_USDT_VAULT,
                TEAM_MULTISIG,
                false
            );

            DexBorrowProtocolConfigInShares
                memory config_ = DexBorrowProtocolConfigInShares({
                    dex: USDC_USDT_DEX,
                    protocol: PST_USDC__USDC_USDT_VAULT,
                    expandPercent: 30 * 1e2, // 30%
                    expandDuration: 6 hours,
                    baseBorrowLimit: 2_500_000 * 1e18, // ~$5M shares
                    maxBorrowLimit: 5_000_000 * 1e18 // ~$10M shares
                });
            setDexBorrowProtocolLimitsInShares(config_);
        }

        // PST-USDC DEX: launch limits + remove Team MS auth
        {
            address PST_USDC_DEX = getDexAddress(PST_USDC_DEX_ID);
            DexConfig memory DEX_PST_USDC = DexConfig({
                dex: PST_USDC_DEX,
                tokenA: PST_ADDRESS,
                tokenB: USDC_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 5_000_000, // $5M per token
                baseBorrowLimitInUSD: 0,
                maxBorrowLimitInUSD: 0
            });
            setDexLimits(DEX_PST_USDC);
            DEX_FACTORY.setDexAuth(PST_USDC_DEX, TEAM_MULTISIG, false);

            IFluidDex(PST_USDC_DEX).updateMaxSupplyShares(
                6_000_000 * 1e18 // $12M
            );
        }
    }

    /// @notice Action 5: Remove DSA connector Chief auths except Team Multisig
    function action5() internal isActionSkippable(5) {
        DSA_CONNECTORS_V2.toggleChief(
            0xb3e586BCE929312e8B0685E2c12c1d6dbbcdc370
        );
        DSA_CONNECTORS_V2.toggleChief(
            0xa6AEC494Aa19Dc910944E2374e9EA159dc919c59
        );
        DSA_CONNECTORS_V2.toggleChief(
            0xCe40798c731Ce4F90EB239E4894D9c643eB1ddE7
        );
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    function _liquidityBorrowConfig(
        address user_,
        address token_,
        uint256 debtCeiling_
    ) internal pure returns (FluidLiquidityAdminStructs.UserBorrowConfig memory) {
        return
            FluidLiquidityAdminStructs.UserBorrowConfig({
                user: user_,
                token: token_,
                mode: 1,
                expandPercent: MAX_RESTRICTED_EXPAND_PERCENT,
                expandDuration: MAX_RESTRICTED_EXPAND_DURATION,
                baseDebtCeiling: debtCeiling_,
                maxDebtCeiling: debtCeiling_
            });
    }

    function _dexBorrowConfig(
        address user_,
        uint256 debtCeiling_
    ) internal pure returns (IFluidAdminDex.UserBorrowConfig memory) {
        return
            IFluidAdminDex.UserBorrowConfig({
                user: user_,
                expandPercent: MAX_RESTRICTED_EXPAND_PERCENT,
                expandDuration: MAX_RESTRICTED_EXPAND_DURATION,
                baseDebtCeiling: debtCeiling_,
                maxDebtCeiling: debtCeiling_
            });
    }

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    function PST_USD_PRICE() public pure override returns (uint256) {
        return 1.10 * 1e2;
    }
    function STABLE_USD_PRICE() public pure override returns (uint256) {
        return 1 * 1e2;
    }
    // --- END AUTO-GENERATED PRICES ---
}
