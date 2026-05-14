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
import {IInfiniteProxy} from "../common/interfaces/IInfiniteProxy.sol";
import {
    IFluidLiquidityRollback
} from "../common/interfaces/IFluidLiquidityRollback.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP129: treasury withdrawal, Liquidity Layer module upgrades with rollback registration,
///         pause auth registration, and rates/ranges auth rotation. Module and auth values are
///         configurable by Team Multisig before execution.
contract PayloadIGP129 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 129;

    address public constant OLD_USER_MODULE =
        0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7;
    address public constant OLD_ADMIN_MODULE =
        0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E;
    address public constant OLD_LIQUIDITY_PAUSE_AUTH =
        0xE9332F2d45e3216B7634cA4C7ab88945CD84ab76;
    address public constant OLD_DEX_PAUSE_AUTH =
        0x735BA3772c2cCC0b92Ff6993bd71da88236C1495;
    address public constant OLD_RATES_AUTH =
        0x1e6B029284dc2779F8FfBD83a3a5aA00EdCE6ba4;
    address public constant OLD_RANGE_AUTH =
        0x827089c01E9f761ff1A6D7041a9388bDdae74cc4;

    // --- Configurable values (Team Multisig can set before execution) ---
    address public newUserModuleAddress = address(0);

    address public newAdminModuleAddress = address(0);

    address public liquidityPauseAuth = address(0);
    address public dexPauseAuth = address(0);

    address public newRatesAuth = address(0);

    address public newRangeAuth = address(0);

    // --- Lock flags (once true, the corresponding values can no longer be changed) ---
    bool public newUserModuleAddressLocked;
    bool public newAdminModuleAddressLocked;
    bool public pauseAuthsLocked;
    bool public ratesAuthsLocked;
    bool public rangeAuthsLocked;

    function lockNewUserModuleAddress() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        newUserModuleAddressLocked = true;
    }

    function lockNewAdminModuleAddress() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        newAdminModuleAddressLocked = true;
    }

    function lockPauseAuths() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        pauseAuthsLocked = true;
    }

    function lockRatesAuths() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        ratesAuthsLocked = true;
    }

    function lockRangeAuths() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        rangeAuthsLocked = true;
    }

    function setNewUserModuleAddress(address newUserModuleAddress_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!newUserModuleAddressLocked, "locked");
        newUserModuleAddress = newUserModuleAddress_;
    }

    function setNewAdminModuleAddress(address newAdminModuleAddress_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!newAdminModuleAddressLocked, "locked");
        newAdminModuleAddress = newAdminModuleAddress_;
    }

    function setPauseAuths(
        address liquidityPauseAuth_,
        address dexPauseAuth_
    ) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!pauseAuthsLocked, "locked");
        liquidityPauseAuth = liquidityPauseAuth_;
        dexPauseAuth = dexPauseAuth_;
    }

    function setNewRatesAuth(address newRatesAuth_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!ratesAuthsLocked, "locked");
        newRatesAuth = newRatesAuth_;
    }

    function setNewRangeAuth(address newRangeAuth_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!rangeAuthsLocked, "locked");
        newRangeAuth = newRangeAuth_;
    }

    function execute() public virtual override {
        super.execute();

        // Action 1: Withdraw funds from Treasury to Team Multisig
        action1();

        // Action 2: Register UserModule LL upgrade on RollbackModule
        action2();

        // Action 3: Upgrade UserModule LL on InfiniteProxy
        action3();

        // Action 4: Register AdminModule LL upgrade on RollbackModule
        action4();

        // Action 5: Upgrade AdminModule LL on InfiniteProxy
        action5();

        // Action 6: Set new pause auth contracts
        action6();

        // Action 7: Update Rates Auth
        action7();

        // Action 8: Update Ranges Auth
        action8();

        // Action 9: Set vault 142 wstUSR withdrawal limit to 24 raw units
        action9();

        // Action 10: Rebalance wstUSR vaults and restore borrow restrictions
        action10();

        // Action 11: Withdraw FLUID rewards funding to Team Multisig
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

    /// @notice Action 1: Withdraw funds from Treasury to Team Multisig
    function action1() internal isActionSkippable(1) {
        // TODO: fill token and amount before finalizing IGP129.
        address token_ = address(0);
        uint256 amount_ = 0;
        require(token_ != address(0), "withdraw-token-not-set");
        require(amount_ != 0, "withdraw-amount-not-set");

        string[] memory targets_ = new string[](1);
        bytes[] memory encodedSpells_ = new bytes[](1);

        targets_[0] = "BASIC-A";
        encodedSpells_[0] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            token_,
            amount_,
            TEAM_MULTISIG,
            0,
            0
        );

        TREASURY.cast(targets_, encodedSpells_, address(this));
    }

    /// @notice Action 2: Register UserModule LL upgrade on RollbackModule
    function action2() internal isActionSkippable(2) {
        address newUserModule_ = PayloadIGP129(ADDRESS_THIS)
            .newUserModuleAddress();
        require(newUserModule_ != address(0), "new-user-module-not-set");

        IFluidLiquidityRollback(address(LIQUIDITY))
            .registerRollbackImplementation(OLD_USER_MODULE, newUserModule_);
    }

    /// @notice Action 3: Upgrade UserModule LL on InfiniteProxy
    function action3() internal isActionSkippable(3) {
        address newUserModule_ = PayloadIGP129(ADDRESS_THIS)
            .newUserModuleAddress();
        require(newUserModule_ != address(0), "new-user-module-not-set");

        bytes4[] memory sigs_ = IInfiniteProxy(address(LIQUIDITY))
            .getImplementationSigs(OLD_USER_MODULE);

        IInfiniteProxy(address(LIQUIDITY)).removeImplementation(
            OLD_USER_MODULE
        );

        IInfiniteProxy(address(LIQUIDITY)).addImplementation(
            newUserModule_,
            sigs_
        );
    }

    /// @notice Action 4: Register AdminModule LL upgrade on RollbackModule
    function action4() internal isActionSkippable(4) {
        address newAdminModule_ = PayloadIGP129(ADDRESS_THIS)
            .newAdminModuleAddress();
        require(newAdminModule_ != address(0), "new-admin-module-not-set");

        IFluidLiquidityRollback(address(LIQUIDITY))
            .registerRollbackImplementation(OLD_ADMIN_MODULE, newAdminModule_);
    }

    /// @notice Action 5: Upgrade AdminModule LL on InfiniteProxy
    function action5() internal isActionSkippable(5) {
        address newAdminModule_ = PayloadIGP129(ADDRESS_THIS)
            .newAdminModuleAddress();
        require(newAdminModule_ != address(0), "new-admin-module-not-set");

        bytes4[] memory sigs_ = IInfiniteProxy(address(LIQUIDITY))
            .getImplementationSigs(OLD_ADMIN_MODULE);

        IInfiniteProxy(address(LIQUIDITY)).removeImplementation(
            OLD_ADMIN_MODULE
        );

        IInfiniteProxy(address(LIQUIDITY)).addImplementation(
            newAdminModule_,
            sigs_
        );
    }

    /// @notice Action 6: Set new pause auth contracts
    function action6() internal isActionSkippable(6) {
        address liquidityPauseAuth_ = PayloadIGP129(ADDRESS_THIS)
            .liquidityPauseAuth();
        address dexPauseAuth_ = PayloadIGP129(ADDRESS_THIS).dexPauseAuth();
        require(liquidityPauseAuth_ != address(0), "ll-pause-auth-not-set");
        require(dexPauseAuth_ != address(0), "dex-pause-auth-not-set");

        FluidLiquidityAdminStructs.AddressBool[]
            memory guardiansStatus_ = new FluidLiquidityAdminStructs.AddressBool[](
                2
            );
        guardiansStatus_[0] = FluidLiquidityAdminStructs.AddressBool({
            addr: OLD_LIQUIDITY_PAUSE_AUTH,
            value: false
        });
        guardiansStatus_[1] = FluidLiquidityAdminStructs.AddressBool({
            addr: liquidityPauseAuth_,
            value: true
        });
        LIQUIDITY.updateGuardians(guardiansStatus_);

        DEX_FACTORY.setGlobalAuth(OLD_DEX_PAUSE_AUTH, false);
        DEX_FACTORY.setGlobalAuth(dexPauseAuth_, true);
    }

    /// @notice Action 7: Update Rates Auth on Liquidity Layer
    function action7() internal isActionSkippable(7) {
        address newRatesAuth_ = PayloadIGP129(ADDRESS_THIS).newRatesAuth();
        require(newRatesAuth_ != address(0), "new-rates-auth-not-set");

        FluidLiquidityAdminStructs.AddressBool[]
            memory authsStatus_ = new FluidLiquidityAdminStructs.AddressBool[](
                2
            );

        authsStatus_[0] = FluidLiquidityAdminStructs.AddressBool({
            addr: OLD_RATES_AUTH,
            value: false
        });
        authsStatus_[1] = FluidLiquidityAdminStructs.AddressBool({
            addr: newRatesAuth_,
            value: true
        });

        LIQUIDITY.updateAuths(authsStatus_);
    }

    /// @notice Action 8: Update Ranges Auth on DexFactory
    function action8() internal isActionSkippable(8) {
        address newRangeAuth_ = PayloadIGP129(ADDRESS_THIS).newRangeAuth();
        require(newRangeAuth_ != address(0), "new-range-auth-not-set");

        DEX_FACTORY.setGlobalAuth(OLD_RANGE_AUTH, false);
        DEX_FACTORY.setGlobalAuth(newRangeAuth_, true);
    }

    /// @notice Action 9: Set vault 142 wstUSR withdrawal limit to 24 raw units
    function action9() internal isActionSkippable(9) {
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

    /// @notice Action 10: Rebalance wstUSR vaults and restore borrow restrictions
    function action10() internal isActionSkippable(10) {
        // Base and max are equal so the vaults can only rebalance the
        // screenshot dust plus a small buffer.
        FluidLiquidityAdminStructs.UserBorrowConfig[]
            memory liquidityConfigs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                4
            );

        liquidityConfigs_[0] = _liquidityBorrowConfig(
            getVaultAddress(110), // wstUSR / USDC
            USDC_ADDRESS,
            4 * 1e6
        );
        liquidityConfigs_[1] = _liquidityBorrowConfig(
            getVaultAddress(111), // wstUSR / USDT
            USDT_ADDRESS,
            3 * 1e6
        );
        liquidityConfigs_[2] = _liquidityBorrowConfig(
            getVaultAddress(112), // wstUSR / GHO
            GHO_ADDRESS,
            0.25 * 1e18
        );
        liquidityConfigs_[3] = _liquidityBorrowConfig(
            getVaultAddress(133), // wstUSR-USDC <> USDC
            USDC_ADDRESS,
            0.7 * 1e6
        );
        LIQUIDITY.updateUserBorrowConfigs(liquidityConfigs_);

        address USDC_USDT_DEX = getDexAddress(2);
        address USDC_USDT_CONCENTRATED_DEX = getDexAddress(34);

        IFluidAdminDex.UserBorrowConfig[]
            memory dexConfigs_ = new IFluidAdminDex.UserBorrowConfig[](1);

        dexConfigs_[0] = _dexBorrowConfig(
            getVaultAddress(134), // wstUSR-USDC <> USDC-USDT
            0.35 * 1e18
        );
        IFluidDex(USDC_USDT_DEX).updateUserBorrowConfigs(dexConfigs_);

        dexConfigs_[0] = _dexBorrowConfig(
            getVaultAddress(135), // wstUSR-USDC <> USDC-USDT concentrated
            0.03 * 1e18
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
            debtToken0MinMaxs_[1] = int256(0.4 * 1e6); // USDC
            debtToken1MinMaxs_[1] = int256(0.4 * 1e6); // USDT
            debtToken0MinMaxs_[2] = int256(0.04 * 1e6); // USDC
            debtToken1MinMaxs_[2] = int256(0.03 * 1e6); // USDT

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

    /// @notice Action 11: Withdraw 750,000 FLUID from Treasury to Team Multisig for rewards
    function action11() internal isActionSkippable(11) {
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
    // --- END AUTO-GENERATED PRICES ---
}
