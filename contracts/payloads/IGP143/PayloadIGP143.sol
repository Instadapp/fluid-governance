// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";
import {IFluidReserveContractV2} from "../common/interfaces/IFluidReserveContract.sol";
import {
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";
import {
    IDSAConnectorsV1,
    IDSAInstaIndex
} from "../common/interfaces/IDSA.sol";
import {IFluidVault} from "../common/interfaces/IFluidVault.sol";
import {IInfiniteProxy} from "../common/interfaces/IInfiniteProxy.sol";

interface IFluidMultisigTimelockController {
    function getMinDelay() external view returns (uint256);
}

/// @notice Liquidity Layer rollback module (routed on the Liquidity proxy).
interface IFluidLiquidityRollbackModule {
    struct RollbackSigsSlot {
        uint40 rollbackRegisterTimestamp;
        address replacesImplementation;
        bytes4[] sigs;
    }

    function cleanupExpiredRollbackImplementation(
        address implementation_
    ) external;

    function registerRollbackImplementation(
        address oldImplementation_,
        address newImplementation_
    ) external;

    function registerRollbackDummyImplementation() external;

    function getRollbackForImplementation(
        address rollbackImplementation_
    ) external view returns (RollbackSigsSlot memory);
}

interface IFluidOracleV2Guardians {
    function setGuardian(address guardian_, bool allowed_) external;
}

/// @notice IGP143: Wind down the tBTC vaults 88, 89 and 90 to exit-only,
///         remove the remaining DSA connector chiefs, switch the
///         USDC-ETH / USDC-ETH vault 77 oracle and upgrade the Liquidity
///         Layer pause setup on mainnet.
///
///         Action 1 fully restricts the Liquidity Layer borrow limits of the
///         tBTC T1 vaults 88 (tBTC/USDC), 89 (tBTC/USDT) and 90 (tBTC/GHO)
///         to dust, sets their tBTC withdrawal limits to current supply +
///         20% (10% expansion over 12 hours) and unpauses them at the
///         Liquidity Layer (supply and borrow legs). The Team Multisig
///         paused the three vaults at the Liquidity Layer (tx 0xf833...8d).
///         After this action users can repay and withdraw, but no new
///         borrow is possible.
///
///         Action 2 updates the DSA connector chiefs: removes the Team
///         Multisig on ConnectorsV2 and four addresses on the legacy v1
///         InstaConnectors, and makes the Team Multisig 24h timelock the
///         ConnectorsV2 chief. The InstaIndex master stays unchanged.
///
///         Action 3 collects the Liquidity Layer's USDC, USDT, GHO, USDe and
///         ETH revenue into the Fluid Reserve and sends the monthly grant
///         tranche of the $350,000/month grant (IGP-139), mostly in
///         stablecoins, to the Team Multisig.
///
///         Action 4 updates the oracle of the T4 USDC-ETH / USDC-ETH
///         vault 77 (DeployerFactory nonce 410).
///
///         Actions 5 to 9 upgrade the Liquidity Layer pause setup, one
///         part per action so each can be skipped on its own:
///         - Action 5 clears the expired rollback registrations and registers
///           rollbacks for the Admin and User modules and the dummy
///           implementation.
///         - Action 6 swaps in the new Admin and User modules and dummy
///           implementation and moves the Liquidity guardian to the new
///           PauseAuthLiquidity (one action: the old PauseAuthLiquidity only
///           calls the old module's pause functions, the new one only the
///           new module's). Runs after Action 1 because the new Admin module
///           no longer routes `unpauseUser`, which Action 1 uses.
///           Skip Actions 5 and 6 together: Action 6 alone has no registered
///           rollback, Action 5 alone leaves registrations that block
///           registering again for 7 days.
///         - Action 7 adds PauseAuthOracleV2 as OracleV2 guardian.
///         - Action 8 moves the DEX pause global auth to the new PauseAuthDex.
///         - Action 9 moves the DEX limits global auth to the new
///           LimitsAuthDex.
contract PayloadIGP143 is PayloadIGPPriceHelpers {
    uint256 public constant PROPOSAL_ID = 143;

    // --- Action 1 ---
    uint256 public constant VAULT_TBTC_USDC_ID = 88; // T1: tBTC / USDC
    uint256 public constant VAULT_TBTC_USDT_ID = 89; // T1: tBTC / USDT
    uint256 public constant VAULT_TBTC_GHO_ID = 90; // T1: tBTC / GHO

    /// @dev Base withdrawal limits (tBTC, 18 decimals) = Liquidity Layer
    ///      supply at block 26313811 + 20%, rounded up to 4 decimals.
    ///      Vault 88: supply ≈0.5589 tBTC (≈$43k) -> 0.6707 tBTC (≈$52k)
    uint256 public constant VAULT_88_BASE_WITHDRAWAL_LIMIT = 6_707 * 1e14;
    ///      Vault 89: supply ≈1.1440 tBTC (≈$89k) -> 1.3729 tBTC (≈$107k)
    uint256 public constant VAULT_89_BASE_WITHDRAWAL_LIMIT = 13_729 * 1e14;
    ///      Vault 90: supply ≈0.0004 tBTC (≈$31) -> 0.0005 tBTC (≈$39)
    uint256 public constant VAULT_90_BASE_WITHDRAWAL_LIMIT = 5 * 1e14;

    uint256 public constant WITHDRAWAL_EXPAND_PERCENT = 10 * 1e2; // 10%
    uint256 public constant WITHDRAWAL_EXPAND_DURATION = 12 hours;

    // --- Action 2 ---
    /// @dev InstaIndex: master() is the governance timelock and stays so.
    IDSAInstaIndex public constant INSTA_INDEX =
        IDSAInstaIndex(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);
    /// @dev Legacy v1 InstaConnectors (InstaIndex connectors(1)).
    ///      Uses enableChief / disableChief.
    IDSAConnectorsV1 public constant DSA_CONNECTORS_V1 =
        IDSAConnectorsV1(0xD6A602C01a023B98Ecfb29Df02FBA380d3B21E0c);

    address public constant V1_CHIEF_1 =
        0xb1DC62EC38E6E3857a887210C38418E4A17Da5B2;
    address public constant V1_CHIEF_2 =
        0x495E5bE71B3fD3ec6dFe54a9e5ccb22550BeF994;
    address public constant V1_CHIEF_3 =
        0x27AC3fFdB94B80Daf5A421e8338dCF6eE23aF73E;
    address public constant V1_CHIEF_4 =
        0xDE13DF1c51364C67dA5cC6360CF5F2e64F1Ae4bd;

    /// @dev Minimum delay the Team Multisig timelock must have to become
    ///      the ConnectorsV2 chief.
    uint256 public constant MIN_CONNECTOR_CHIEF_DELAY = 1 days;

    // --- Action 3 ---
    /// @dev Grant recipient: the Team Multisig.
    address public constant MONTHLY_GRANT_RECIPIENT = TEAM_MULTISIG;
    /// @notice Monthly tranche of the $350,000/month grant (IGP-139), mostly
    ///         in stablecoins: $248k in USDC, USDT, GHO and USDe (~71%), the
    ///         rest in ETH and stETH. Sized to what the Reserve plus
    ///         uncollected Liquidity revenue holds at authoring (block
    ///         26458491: ~100.3k USDC, ~96.3k USDT, ~52.2k GHO, ~5.5k USDe,
    ///         ~18.4 ETH, ~40.7 stETH). ~$350k at the 7-day average ETH /
    ///         stETH price of ~$1,815 (13-19 Nov 2026). Fixed token amounts.
    uint256 public constant MONTHLY_GRANT_USDC = 98_000 * 1e6;
    uint256 public constant MONTHLY_GRANT_USDT = 94_000 * 1e6;
    uint256 public constant MONTHLY_GRANT_GHO = 51_000 * 1e18;
    uint256 public constant MONTHLY_GRANT_USDE = 5_000 * 1e18;
    uint256 public constant MONTHLY_GRANT_ETH = 17 ether;
    uint256 public constant MONTHLY_GRANT_STETH = 39 ether;

    // --- Action 4 ---
    uint256 public constant VAULT_USDC_ETH_USDC_ETH_ID = 77; // T4: USDC-ETH / USDC-ETH
    /// @dev VaultT4Oracle USDC-ETH / USDC-ETH,
    ///      0x317155C3EDdB9ae57097D98b2954CB6cC7f38f6D.
    ///      Replaces nonce 60 (0x9c9cad6Dd23fbDCdA3348726c306bAF20c428c4C).
    uint256 public constant VAULT_77_NEW_ORACLE_NONCE = 410;

    // --- Actions 5 to 9 ---
    /// @dev Expired rollback registrations on the Liquidity Layer, cleared
    ///      before the new rollbacks are registered.
    address public constant EXPIRED_ROLLBACK_USER_MODULE =
        0x2e4015880367b7C2613Df77f816739D97A8C46aD;
    address public constant EXPIRED_ROLLBACK_ADMIN_MODULE =
        0x53EFFA0e612d88f39Ab32eb5274F2fae478d261C;

    /// @dev Liquidity Layer modules removed by the swap.
    address public constant OLD_ADMIN_MODULE =
        0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E;
    address public constant OLD_USER_MODULE =
        0x4bDC8816F2f56914B66EbF3786D78872D3a73Ab7;
    address public constant ZIRCUIT_TRANSFER_MODULE =
        0x9191b9539DD588dB81076900deFDd79Cb1115f72;

    /// @dev New Liquidity Layer modules and dummy implementation.
    address public constant NEW_ADMIN_MODULE =
        0x20ad698963BCc194dd3b5A0b5458ac3c52dE9C56;
    address public constant NEW_USER_MODULE =
        0x6a887dad0852b1A8fa5429FB9c7F83a943469F06;
    address public constant NEW_DUMMY_IMPLEMENTATION =
        0x8bDD171da967345a23Af927051E8860E6b9fAFe7;

    /// @dev Liquidity Layer guardians.
    address public constant NEW_PAUSE_AUTH_LIQUIDITY =
        0x30f8B1FaE1937992556f28c961aE0a1E088ED48c;
    address public constant OLD_PAUSE_AUTH_LIQUIDITY =
        0xE9332F2d45e3216B7634cA4C7ab88945CD84ab76;

    /// @dev OracleV2 and its guardian.
    address public constant ORACLE_V2 =
        0x643E32D5a39C1B0a483BCF2C5c2c55C4b982ac06;
    address public constant PAUSE_AUTH_ORACLE_V2 =
        0x8fcC728708b2D9d6a2B4d49477Ada6042d43dd63;

    /// @dev DexFactory global auths.
    address public constant NEW_PAUSE_AUTH_DEX =
        0x19684DdA3c27735861f6197DE738F5C3ca0c8eE3;
    address public constant NEW_LIMITS_AUTH_DEX =
        0x1E1fcA3cC4436aAE73e9C97Ea0E1584c749DB300;
    address public constant OLD_PAUSE_AUTH_DEX =
        0x735BA3772c2cCC0b92Ff6993bd71da88236C1495;
    address public constant OLD_LIMITS_AUTH_DEX =
        0x5A09B07DFCc0852ADA327Dc81A9cb676B6c676f2;

    function execute() public virtual override {
        super.execute();

        // Action 1: Restrict tBTC vaults 88/89/90 borrow to dust, set withdrawal limits and unpause them (exit-only).
        action1();

        // Action 2: Remove the remaining DSA connector chiefs and make the Team Multisig 24h timelock the ConnectorsV2 chief.
        action2();

        // Action 3: Collect Liquidity Layer revenue and send the monthly grant tranche.
        action3();

        // Action 4: Update oracle on the USDC-ETH / USDC-ETH T4 vault 77.
        action4();

        // Action 5: Liquidity Layer: clear expired rollback registrations and register the new rollbacks.
        action5();

        // Action 6: Liquidity Layer: swap the Admin and User modules and the guardian (must run after Action 1).
        action6();

        // Action 7: OracleV2: add PauseAuthOracleV2 as guardian.
        action7();

        // Action 8: DexFactory: move the pause global auth to the new PauseAuthDex.
        action8();

        // Action 9: DexFactory: move the limits global auth to the new LimitsAuthDex.
        action9();
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

    /// @notice Action 1: Set the tBTC vaults 88, 89 and 90 to exit-only.
    ///         - borrow (USDC / USDT / GHO) at the Liquidity Layer: debt
    ///           ceiling to dust (10 / 20), 0.01% expansion over max duration
    ///         - supply (tBTC): base withdrawal limit = current supply +
    ///           20%, 10% expansion over 12 hours
    ///         - unpause supply and borrow at the Liquidity Layer (only the
    ///           legs that are paused, so the action runs whether or not the
    ///           Team Multisig pause was executed)
    function action1() internal isActionSkippable(1) {
        _setExitOnly(
            getVaultAddress(VAULT_TBTC_USDC_ID),
            USDC_ADDRESS,
            VAULT_88_BASE_WITHDRAWAL_LIMIT
        );
        _setExitOnly(
            getVaultAddress(VAULT_TBTC_USDT_ID),
            USDT_ADDRESS,
            VAULT_89_BASE_WITHDRAWAL_LIMIT
        );
        _setExitOnly(
            getVaultAddress(VAULT_TBTC_GHO_ID),
            GHO_ADDRESS,
            VAULT_90_BASE_WITHDRAWAL_LIMIT
        );
    }

    /// @notice Action 2: Remove the remaining DSA connector chiefs and make
    ///         the Team Multisig 24h timelock the ConnectorsV2 chief.
    ///         - ConnectorsV2 (used by DSA v2 cast): toggleChief(Team Multisig)
    ///           to remove it, toggleChief(Team Multisig timelock) to add it.
    ///           toggleChief flips the flag, so each call only runs while the
    ///           flag is not yet in its target state.
    ///         - legacy v1 InstaConnectors: disableChief for all four chiefs,
    ///           no new chief added there.
    ///         Reverts unless all five old chiefs end false, the timelock is
    ///         the ConnectorsV2 chief with a delay of at least 24h, and the
    ///         InstaIndex master is still the governance timelock.
    function action2() internal isActionSkippable(2) {
        // ConnectorsV2
        if (DSA_CONNECTORS_V2.chief(TEAM_MULTISIG)) {
            DSA_CONNECTORS_V2.toggleChief(TEAM_MULTISIG);
        }
        require(
            !DSA_CONNECTORS_V2.chief(TEAM_MULTISIG),
            "v2-chief-not-removed"
        );

        // ConnectorsV2: Team Multisig 24h timelock becomes the chief
        require(
            IFluidMultisigTimelockController(
                FLUID_MULTISIG_TIMELOCK_CONTROLLER
            ).getMinDelay() >= MIN_CONNECTOR_CHIEF_DELAY,
            "timelock-delay-too-short"
        );
        if (!DSA_CONNECTORS_V2.chief(FLUID_MULTISIG_TIMELOCK_CONTROLLER)) {
            DSA_CONNECTORS_V2.toggleChief(FLUID_MULTISIG_TIMELOCK_CONTROLLER);
        }
        require(
            DSA_CONNECTORS_V2.chief(FLUID_MULTISIG_TIMELOCK_CONTROLLER),
            "v2-timelock-chief-not-set"
        );

        // Legacy v1 InstaConnectors
        address[4] memory v1Chiefs_ = [
            V1_CHIEF_1,
            V1_CHIEF_2,
            V1_CHIEF_3,
            V1_CHIEF_4
        ];
        for (uint256 i = 0; i < v1Chiefs_.length; i++) {
            DSA_CONNECTORS_V1.disableChief(v1Chiefs_[i]);
        }
        for (uint256 i = 0; i < v1Chiefs_.length; i++) {
            require(
                !DSA_CONNECTORS_V1.chief(v1Chiefs_[i]),
                "v1-chief-not-removed"
            );
        }

        require(
            INSTA_INDEX.master() == address(TIMELOCK),
            "insta-index-master-changed"
        );
    }

    /// @notice Action 3: Collect the Liquidity Layer's USDC, USDT, GHO, USDe
    ///         and ETH revenue into the Fluid Reserve and transfer the
    ///         monthly tranche of the $350,000/month grant to the Team
    ///         Multisig.
    /// @dev IGP-141 Action 2 pattern (`collectRevenue`, then
    ///      `FLUID_RESERVE.withdrawFunds`, memo "FOUNDATION GRANT"), to the
    ///      Team Multisig instead of the Foundation address.
    function action3() internal isActionSkippable(3) {
        // Step 1: Collect Liquidity Layer revenue into the Reserve.
        address[] memory liquidityTokens_ = new address[](5);
        liquidityTokens_[0] = USDC_ADDRESS; // ~81.3k uncollected
        liquidityTokens_[1] = USDT_ADDRESS; // ~79.5k uncollected
        liquidityTokens_[2] = GHO_ADDRESS; // ~52.2k uncollected
        liquidityTokens_[3] = USDe_ADDRESS; // ~5.5k uncollected
        liquidityTokens_[4] = ETH_ADDRESS; // ~12.8 ETH uncollected

        LIQUIDITY.collectRevenue(liquidityTokens_);

        // Step 2: Transfer the tranche to the Team Multisig.
        address[] memory tokens_ = new address[](6);
        uint256[] memory amounts_ = new uint256[](6);

        tokens_[0] = USDC_ADDRESS;
        amounts_[0] = MONTHLY_GRANT_USDC; // 98,000 USDC

        tokens_[1] = USDT_ADDRESS;
        amounts_[1] = MONTHLY_GRANT_USDT; // 94,000 USDT

        tokens_[2] = GHO_ADDRESS;
        amounts_[2] = MONTHLY_GRANT_GHO; // 51,000 GHO

        tokens_[3] = USDe_ADDRESS;
        amounts_[3] = MONTHLY_GRANT_USDE; // 5,000 USDe

        tokens_[4] = ETH_ADDRESS;
        amounts_[4] = MONTHLY_GRANT_ETH; // 17 ETH

        tokens_[5] = stETH_ADDRESS;
        amounts_[5] = MONTHLY_GRANT_STETH; // 39 stETH

        IFluidReserveContractV2(address(FLUID_RESERVE)).withdrawFunds(
            tokens_,
            amounts_,
            MONTHLY_GRANT_RECIPIENT,
            "FOUNDATION GRANT"
        );
    }

    /// @notice Action 4: Update oracle on the USDC-ETH / USDC-ETH T4
    ///         vault 77.
    /// @dev T4 vaults take the DeployerFactory nonce via
    ///      `updateOracle(uint256)` and probe the new oracle's
    ///      `getExchangeRateOperate()` / `getExchangeRateLiquidate()` before
    ///      committing (IGP-142 Action 13 pattern).
    function action4() internal isActionSkippable(4) {
        // Vault 77 (T4): VaultT4Oracle USDC-ETH / USDC-ETH, nonce 60 -> 410
        IFluidVault(getVaultAddress(VAULT_USDC_ETH_USDC_ETH_ID)).updateOracle(
            VAULT_77_NEW_ORACLE_NONCE
        );
    }

    /// @notice Action 5: Liquidity Layer rollbacks.
    ///         1. clear the expired rollback registrations (skipped for any
    ///            already cleared, the call is permissionless)
    ///         2. register rollbacks for the Admin and User modules and the
    ///            dummy implementation
    ///         Registration reverts while the expired registrations exist,
    ///         so both steps stay in one action.
    ///         Skip together with Action 6: the registrations made here
    ///         cannot be cleared or replaced for 7 days (ROLLBACK_PERIOD), so
    ///         a later swap would have to wait or go without a rollback.
    function action5() internal isActionSkippable(5) {
        IFluidLiquidityRollbackModule rollback_ = IFluidLiquidityRollbackModule(
            address(LIQUIDITY)
        );

        // 1. Clear expired rollback registrations
        _cleanupExpiredRollback(rollback_, EXPIRED_ROLLBACK_USER_MODULE);
        _cleanupExpiredRollback(rollback_, EXPIRED_ROLLBACK_ADMIN_MODULE);

        // 2. Register rollbacks (old -> new)
        rollback_.registerRollbackImplementation(
            OLD_ADMIN_MODULE,
            NEW_ADMIN_MODULE
        );
        rollback_.registerRollbackImplementation(
            OLD_USER_MODULE,
            NEW_USER_MODULE
        );
        rollback_.registerRollbackDummyImplementation();
    }

    /// @notice Action 6: Liquidity Layer module swap and guardian.
    ///         1. swap the Admin and User modules, remove the Zircuit
    ///            transfer module, set the new dummy implementation
    ///         2. Liquidity guardians: add the new PauseAuthLiquidity,
    ///            remove the old one
    ///         Must run after Action 1. Run Action 5 first so the swap has
    ///         a registered rollback (rollbacks cannot be registered once
    ///         the old modules are removed).
    ///         A rollback only restores the module routing, not the guardian:
    ///         the new PauseAuthLiquidity cannot pause on the old modules and
    ///         the old one is no longer a guardian, so pausing is then manual
    ///         (Team Multisig) until governance sets the guardian again.
    function action6() internal isActionSkippable(6) {
        IInfiniteProxy proxy_ = IInfiniteProxy(address(LIQUIDITY));

        // 1. Module swap
        proxy_.removeImplementation(OLD_ADMIN_MODULE);
        proxy_.removeImplementation(OLD_USER_MODULE);
        proxy_.removeImplementation(ZIRCUIT_TRANSFER_MODULE);
        proxy_.addImplementation(NEW_ADMIN_MODULE, _newAdminModuleSigs());

        bytes4[] memory userSigs_ = new bytes4[](2);
        userSigs_[0] = 0xad967e15; // operate
        userSigs_[1] = 0xdacb5419; // operateOnBehalfOf
        proxy_.addImplementation(NEW_USER_MODULE, userSigs_);

        proxy_.setDummyImplementation(NEW_DUMMY_IMPLEMENTATION);

        require(
            proxy_.getSigsImplementation(0x84badf18) == NEW_ADMIN_MODULE, // pauseUserBorrow
            "pause-user-borrow-not-routed"
        );
        require(
            proxy_.getSigsImplementation(0xdd4cbf6b) == address(0), // pauseUser
            "old-pause-user-routed"
        );
        require(
            proxy_.getSigsImplementation(0xc609684a) == address(0), // pauseTokens(address[])
            "old-pause-tokens-routed"
        );
        require(
            proxy_.getSigsImplementation(0x7a4df6eb) == address(0), // unpauseTokens(address[])
            "old-unpause-tokens-routed"
        );

        // 2. Liquidity guardians
        FluidLiquidityAdminStructs.AddressBool[]
            memory guardians_ = new FluidLiquidityAdminStructs.AddressBool[](2);
        guardians_[0] = FluidLiquidityAdminStructs.AddressBool({
            addr: NEW_PAUSE_AUTH_LIQUIDITY,
            value: true
        });
        guardians_[1] = FluidLiquidityAdminStructs.AddressBool({
            addr: OLD_PAUSE_AUTH_LIQUIDITY,
            value: false
        });
        LIQUIDITY.updateGuardians(guardians_);
    }

    /// @notice Action 7: OracleV2 guardian: add PauseAuthOracleV2.
    function action7() internal isActionSkippable(7) {
        IFluidOracleV2Guardians(ORACLE_V2).setGuardian(
            PAUSE_AUTH_ORACLE_V2,
            true
        );
    }

    /// @notice Action 8: DexFactory pause global auth: add the new
    ///         PauseAuthDex, remove the old one.
    function action8() internal isActionSkippable(8) {
        DEX_FACTORY.setGlobalAuth(NEW_PAUSE_AUTH_DEX, true);
        DEX_FACTORY.setGlobalAuth(OLD_PAUSE_AUTH_DEX, false);
    }

    /// @notice Action 9: DexFactory limits global auth: add the new
    ///         LimitsAuthDex, remove the old one.
    function action9() internal isActionSkippable(9) {
        DEX_FACTORY.setGlobalAuth(NEW_LIMITS_AUTH_DEX, true);
        DEX_FACTORY.setGlobalAuth(OLD_LIMITS_AUTH_DEX, false);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    function _setExitOnly(
        address vault_,
        address borrowToken_,
        uint256 baseWithdrawalLimit_
    ) internal {
        // Borrow: max restrict
        setBorrowProtocolLimitsPaused(vault_, borrowToken_);

        // Supply: current supply + 20%, 10% expansion over 12 hours
        FluidLiquidityAdminStructs.UserSupplyConfig[]
            memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](
                1
            );
        configs_[0] = FluidLiquidityAdminStructs.UserSupplyConfig({
            user: vault_,
            token: tBTC_ADDRESS,
            mode: 1,
            expandPercent: WITHDRAWAL_EXPAND_PERCENT,
            expandDuration: WITHDRAWAL_EXPAND_DURATION,
            baseWithdrawalLimit: baseWithdrawalLimit_
        });
        LIQUIDITY.updateUserSupplyConfigs(configs_);

        // Unpause the paused legs
        _unpauseUserAtLiquidity(vault_, tBTC_ADDRESS, borrowToken_);
    }

    /// @dev `unpauseUser` reverts with UserNotPaused for a leg that is not
    ///      paused, so only the paused legs are passed in.
    function _unpauseUserAtLiquidity(
        address user_,
        address supplyToken_,
        address borrowToken_
    ) internal {
        bool supplyPaused_ = _isPaused(
            LiquiditySlotsLink.LIQUIDITY_USER_SUPPLY_DOUBLE_MAPPING_SLOT,
            user_,
            supplyToken_,
            LiquiditySlotsLink.BITS_USER_SUPPLY_IS_PAUSED
        );
        bool borrowPaused_ = _isPaused(
            LiquiditySlotsLink.LIQUIDITY_USER_BORROW_DOUBLE_MAPPING_SLOT,
            user_,
            borrowToken_,
            LiquiditySlotsLink.BITS_USER_BORROW_IS_PAUSED
        );
        if (!supplyPaused_ && !borrowPaused_) return;

        address[] memory supplyTokens_ = new address[](supplyPaused_ ? 1 : 0);
        if (supplyPaused_) supplyTokens_[0] = supplyToken_;
        address[] memory borrowTokens_ = new address[](borrowPaused_ ? 1 : 0);
        if (borrowPaused_) borrowTokens_[0] = borrowToken_;

        LIQUIDITY.unpauseUser(user_, supplyTokens_, borrowTokens_);
    }

    function _isPaused(
        uint256 mappingSlot_,
        address user_,
        address token_,
        uint256 pauseBit_
    ) internal view returns (bool) {
        uint256 userData_ = LIQUIDITY.readFromStorage(
            LiquiditySlotsLink.calculateDoubleMappingStorageSlot(
                mappingSlot_,
                user_,
                token_
            )
        );
        return (userData_ >> pauseBit_) & 1 == 1;
    }

    /// @dev `cleanupExpiredRollbackImplementation` is permissionless and
    ///      reverts NotRegistered once cleared, so it only runs while the
    ///      registration still exists.
    function _cleanupExpiredRollback(
        IFluidLiquidityRollbackModule rollback_,
        address implementation_
    ) internal {
        if (
            rollback_.getRollbackForImplementation(implementation_).sigs.length > 0
        ) {
            rollback_.cleanupExpiredRollbackImplementation(implementation_);
        }
    }

    /// @dev The 20 function selectors of the new Admin module, from its ABI.
    function _newAdminModuleSigs() internal pure returns (bytes4[] memory sigs_) {
        sigs_ = new bytes4[](20);
        sigs_[0] = 0xeae2c8f1; // NATIVE_TOKEN_MAX_BORROW_LIMIT_CAP()
        sigs_[1] = 0xe8025d77; // changeStatus(uint256)
        sigs_[2] = 0xac862bfa; // collectRevenue(address[])
        sigs_[3] = 0x15a354e2; // pauseTokens(address[],bool,bool,bool,bool)
        sigs_[4] = 0x84badf18; // pauseUserBorrow(address,address[],bool,bool)
        sigs_[5] = 0xfb161750; // pauseUserSupply(address,address[],bool,bool)
        sigs_[6] = 0x0a2e6f3a; // unpauseTokens(address[],bool,bool,bool,bool)
        sigs_[7] = 0x5344919e; // unpauseUserBorrow(address,address[],bool,bool)
        sigs_[8] = 0x87dfb1f6; // unpauseUserSupply(address,address[],bool,bool)
        sigs_[9] = 0x3f66feff; // updateAuths
        sigs_[10] = 0xf4bfa000; // updateExchangePrices
        sigs_[11] = 0xa5eb43ef; // updateGuardians
        sigs_[12] = 0x3fad77fc; // updateRateDataV1s
        sigs_[13] = 0x9dde5977; // updateRateDataV2s
        sigs_[14] = 0x54bb0c1d; // updateRevenueCollector
        sigs_[15] = 0x7f7b6002; // updateTokenConfigs
        sigs_[16] = 0x01b88f86; // updateUserBorrowConfigs
        sigs_[17] = 0xc2da75f0; // updateUserClasses
        sigs_[18] = 0x02c6bb6a; // updateUserSupplyConfigs
        sigs_[19] = 0x8f0c2916; // updateUserWithdrawalLimit
    }

    // --- BEGIN AUTO-GENERATED PRICES (scripts/verify/prepare-prices.ts) ---
    // 7-day average of hourly closes, 2026-11-09 21:00Z to 2026-11-16 20:00Z, source: coinbase
    function ETH_USD_PRICE()    public pure override returns (uint256) { return 1_950 * 1e2; }
    function STABLE_USD_PRICE() public pure override returns (uint256) { return 1 * 1e2; }
    function BTC_USD_PRICE()    public pure override returns (uint256) { return 69_500 * 1e2; }
    // --- END AUTO-GENERATED PRICES ---
}
