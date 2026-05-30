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
import {IFluidDex} from "../common/interfaces/IFluidDex.sol";
import {PayloadIGPPriceHelpers} from "../common/pricehelpers.sol";

/// @notice IGP132: Liquidity Layer UserModule and AdminModule upgrades with
///         rollback registration, pause / rates / range auth rotations,
///         tightened base withdrawal limits on legacy vaults 1–10, USDai
///         ecosystem dust limits, and max supply share caps on USR/RLP DEXes.
///         Module and auth values are configurable by Team Multisig before execution.
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

        // Action 9: USDai ecosystem dust limits (DEXes 46–48, vaults 170–177)
        action9();

        // Action 10: Set USR-USDC and RLP-USDC DEX max supply shares to 0
        action10();
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

    /// @notice Action 9: Dust limits for USDai ecosystem (DEXes 46–48, vaults 170–177)
    function action9() internal isActionSkippable(9) {
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

    /// @notice Action 10: Set USR-USDC (DEX 20) and RLP-USDC (DEX 28) max supply shares to 0
    function action10() internal isActionSkippable(10) {
        IFluidDex(getDexAddress(USR_USDC_DEX_ID)).updateMaxSupplyShares(0);
        IFluidDex(getDexAddress(RLP_USDC_DEX_ID)).updateMaxSupplyShares(0);
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
