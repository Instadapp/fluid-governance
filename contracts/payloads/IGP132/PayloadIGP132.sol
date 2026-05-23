// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {IInfiniteProxy} from "../common/interfaces/IInfiniteProxy.sol";
import {
    IFluidLiquidityRollback
} from "../common/interfaces/IFluidLiquidityRollback.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP132: Liquidity Layer UserModule and AdminModule upgrades with
///         rollback registration, pause / rates / range auth rotations, and
///         tightened base withdrawal limits on legacy vaults 1–10.
///         Module and auth values are configurable by Team Multisig before execution.
contract PayloadIGP132 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 132;

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

        // Action 1: Register UserModule LL upgrade on RollbackModule
        action1();

        // Action 2: Upgrade UserModule LL on InfiniteProxy
        action2();

        // Action 3: Register AdminModule LL upgrade on RollbackModule
        action3();

        // Action 4: Upgrade AdminModule LL on InfiniteProxy
        action4();

        // Action 5: Set new pause auth contracts
        action5();

        // Action 6: Update Rates Auth
        action6();

        // Action 7: Update Ranges Auth
        action7();

        // Action 8: Reduce base withdrawal limits on legacy vaults 1–10
        action8();
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

    /// @notice Action 1: Register UserModule LL upgrade on RollbackModule
    function action1() internal isActionSkippable(1) {
        address newUserModule_ = PayloadIGP132(ADDRESS_THIS)
            .newUserModuleAddress();
        require(newUserModule_ != address(0), "new-user-module-not-set");

        IFluidLiquidityRollback(address(LIQUIDITY))
            .registerRollbackImplementation(OLD_USER_MODULE, newUserModule_);
    }

    /// @notice Action 2: Upgrade UserModule LL on InfiniteProxy
    function action2() internal isActionSkippable(2) {
        address newUserModule_ = PayloadIGP132(ADDRESS_THIS)
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

    /// @notice Action 3: Register AdminModule LL upgrade on RollbackModule
    function action3() internal isActionSkippable(3) {
        address newAdminModule_ = PayloadIGP132(ADDRESS_THIS)
            .newAdminModuleAddress();
        require(newAdminModule_ != address(0), "new-admin-module-not-set");

        IFluidLiquidityRollback(address(LIQUIDITY))
            .registerRollbackImplementation(OLD_ADMIN_MODULE, newAdminModule_);
    }

    /// @notice Action 4: Upgrade AdminModule LL on InfiniteProxy
    function action4() internal isActionSkippable(4) {
        address newAdminModule_ = PayloadIGP132(ADDRESS_THIS)
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

    /// @notice Action 5: Set new pause auth contracts
    function action5() internal isActionSkippable(5) {
        address liquidityPauseAuth_ = PayloadIGP132(ADDRESS_THIS)
            .liquidityPauseAuth();
        address dexPauseAuth_ = PayloadIGP132(ADDRESS_THIS).dexPauseAuth();
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

    /// @notice Action 6: Update Rates Auth on Liquidity Layer
    function action6() internal isActionSkippable(6) {
        address newRatesAuth_ = PayloadIGP132(ADDRESS_THIS).newRatesAuth();
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

    /// @notice Action 7: Update Ranges Auth on DexFactory
    function action7() internal isActionSkippable(7) {
        address newRangeAuth_ = PayloadIGP132(ADDRESS_THIS).newRangeAuth();
        require(newRangeAuth_ != address(0), "new-range-auth-not-set");

        DEX_FACTORY.setGlobalAuth(OLD_RANGE_AUTH, false);
        DEX_FACTORY.setGlobalAuth(newRangeAuth_, true);
    }

    /// @notice Action 8: Set legacy vault 1–10 base withdrawal limits to total supply + 5%
    function action8() internal isActionSkippable(8) {
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
    // --- END AUTO-GENERATED PRICES ---
}
