// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "../libraries/bigMathMinified.sol";
import {LiquidityCalcs} from "../libraries/liquidityCalcs.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";

import {IGovernorBravo} from "../common/interfaces/IGovernorBravo.sol";
import {ITimelock} from "../common/interfaces/ITimelock.sol";

import {
    IFluidLiquidityAdmin,
    AdminModuleStructs as FluidLiquidityAdminStructs
} from "../common/interfaces/IFluidLiquidity.sol";
import {
    IFluidReserveContract
} from "../common/interfaces/IFluidReserveContract.sol";

import {IFluidVaultFactory} from "../common/interfaces/IFluidVaultFactory.sol";
import {IFluidDexFactory} from "../common/interfaces/IFluidDexFactory.sol";

import {
    IFluidDex,
    IFluidAdminDex,
    IFluidDexResolver
} from "../common/interfaces/IFluidDex.sol";

import {IFluidVault, IFluidVaultT1} from "../common/interfaces/IFluidVault.sol";

import {IFTokenAdmin, ILendingRewards} from "../common/interfaces/IFToken.sol";

import {ICodeReader} from "../common/interfaces/ICodeReader.sol";
import {IDSAV2} from "../common/interfaces/IDSA.sol";
import {IERC20} from "../common/interfaces/IERC20.sol";
import {IInfiniteProxy} from "../common/interfaces/IInfiniteProxy.sol";
import {PayloadIGPConstants} from "../common/constants.sol";
import {PayloadIGPHelpers} from "../common/helpers.sol";
import {PayloadIGPMain} from "../common/main.sol";

interface IFluidLiquidityRollback {
    function registerRollbackImplementation(
        address oldImplementation_,
        address newImplementation_
    ) external;

    function registerRollbackDummyImplementation() external;
}

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

/// @notice IGP126: Add TEAM_MULTISIG as auth on wstUSR vaults/DEXes, register & upgrade UserModule LL via RollbackModule,
///         set LL auth for operateOnBehalfOf, set new VaultFactory owner, max-restrict borrows, pause wstUSR DEX swapAndArbitrage.
contract PayloadIGP126 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 126;

    address public constant OLD_USER_MODULE =
        0x2e4015880367b7C2613Df77f816739D97A8C46aD;

    /// @dev IFluidLiquidityLogic.operateOnBehalfOf(address,address,int256,int256,bytes)
    bytes4 private constant OPERATE_ON_BEHALF_OF_SIG =
        bytes4(
            keccak256("operateOnBehalfOf(address,address,int256,int256,bytes)")
        );

    // --- Configurable addresses (Team Multisig can set before execution) ---
    address public userModuleAddress = address(0);
    address public dummyImplementationAddress = address(0);
    address public onBehalfOfAuth = address(0);
    address public vaultFactoryOwner = address(0);
    address public pauseableAuth = address(0);
    address public pausableDexAuth = address(0);

    // --- Lock flags (once true, the corresponding address can no longer be changed) ---
    bool public userModuleAddressLocked;
    bool public dummyImplementationAddressLocked;
    bool public onBehalfOfAuthLocked;
    bool public vaultFactoryOwnerLocked;
    bool public pauseableAuthLocked;
    bool public pausableDexAuthLocked;

    function lockUserModuleAddress() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        userModuleAddressLocked = true;
    }

    function lockDummyImplementationAddress() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        dummyImplementationAddressLocked = true;
    }

    function lockOnBehalfOfAuth() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        onBehalfOfAuthLocked = true;
    }

    function lockVaultFactoryOwner() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        vaultFactoryOwnerLocked = true;
    }

    function lockPauseableAuth() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        pauseableAuthLocked = true;
    }

    function lockPausableDexAuth() external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        pausableDexAuthLocked = true;
    }

    function setUserModuleAddress(address userModuleAddress_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!userModuleAddressLocked, "locked");
        userModuleAddress = userModuleAddress_;
    }

    function setDummyImplementationAddress(
        address dummyImplementationAddress_
    ) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!dummyImplementationAddressLocked, "locked");
        dummyImplementationAddress = dummyImplementationAddress_;
    }

    function setOnBehalfOfAuth(address onBehalfOfAuth_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!onBehalfOfAuthLocked, "locked");
        onBehalfOfAuth = onBehalfOfAuth_;
    }

    function setVaultFactoryOwner(address vaultFactoryOwner_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!vaultFactoryOwnerLocked, "locked");
        vaultFactoryOwner = vaultFactoryOwner_;
    }

    function setPauseableAuth(address pauseableAuth_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!pauseableAuthLocked, "locked");
        pauseableAuth = pauseableAuth_;
    }

    function setPausableDexAuth(address pausableDexAuth_) external {
        require(msg.sender == TEAM_MULTISIG, "not-team-multisig");
        require(!pausableDexAuthLocked, "locked");
        pausableDexAuth = pausableDexAuth_;
    }

    function execute() public virtual override {
        super.execute();

        // Action 1: Add TEAM_MULTISIG as auth on all wstUSR vaults and DEXes
        action1();

        // Action 2: Register UserModule LL upgrade on RollbackModule
        action2();

        // Action 3: Update UserModule LL to settable address
        action3();

        // Action 4: Register DummyImplementation rollback on RollbackModule
        action4();

        // Action 5: Update DummyImplementation on LL to settable address
        action5();

        // Action 6: Set a contract as auth on LL (for operateOnBehalfOf)
        action6();

        // Action 7: Set new owner of VaultFactory (for position transfer wrapper)
        action7();

        // Action 8: Set max restricted borrow limits on all wstUSR vaults
        action8();

        // Action 9: Pause swapAndArbitrage on all wstUSR-related DEXes
        action9();

        // Action 10: Set pauseableAuth as auth on LL
        action10();

        // Action 11: Set pausableDexAuth as globalAuth on DexFactory
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

    /// @notice Action 1: Add TEAM_MULTISIG as auth on all wstUSR vaults and DEXes
    function action1() internal isActionSkippable(1) {
        // wstUSR Vaults
        VAULT_FACTORY.setVaultAuth(getVaultAddress(110), TEAM_MULTISIG, true); // wstUSR / USDC
        VAULT_FACTORY.setVaultAuth(getVaultAddress(111), TEAM_MULTISIG, true); // wstUSR / USDT
        VAULT_FACTORY.setVaultAuth(getVaultAddress(112), TEAM_MULTISIG, true); // wstUSR / GHO
        // skip 113 wstUSR-USDT / USDT: already max restricted / deprecated
        VAULT_FACTORY.setVaultAuth(getVaultAddress(133), TEAM_MULTISIG, true); // wstUSR-USDC <> USDC
        VAULT_FACTORY.setVaultAuth(getVaultAddress(134), TEAM_MULTISIG, true); // wstUSR-USDC <> USDC-USDT
        VAULT_FACTORY.setVaultAuth(getVaultAddress(135), TEAM_MULTISIG, true); // wstUSR-USDC <> USDC-USDT concentrated
        // skip 142 wstUSR / USDtb: already max restricted / deprecated
        VAULT_FACTORY.setVaultAuth(getVaultAddress(143), TEAM_MULTISIG, true); // wstUSR <> USDC-USDT
        VAULT_FACTORY.setVaultAuth(getVaultAddress(144), TEAM_MULTISIG, true); // wstUSR <> USDC-USDT concentrated

        // wstUSR DEXes
        DEX_FACTORY.setDexAuth(getDexAddress(27), TEAM_MULTISIG, true); // wstUSR-USDC
        // skip 29 wstUSR-USDT: already max restricted / deprecated
    }

    /// @notice Action 2: Register UserModule LL upgrade on RollbackModule (must happen before the actual upgrade)
    function action2() internal isActionSkippable(2) {
        address newUserModule_ = PayloadIGP126(ADDRESS_THIS)
            .userModuleAddress();
        require(newUserModule_ != address(0), "user-module-not-set");

        IFluidLiquidityRollback(address(LIQUIDITY))
            .registerRollbackImplementation(OLD_USER_MODULE, newUserModule_);
    }

    /// @notice Action 3: Update UserModule LL to settable address
    function action3() internal isActionSkippable(3) {
        address newUserModule_ = PayloadIGP126(ADDRESS_THIS)
            .userModuleAddress();
        require(newUserModule_ != address(0), "user-module-not-set");

        bytes4[] memory baseSigs_ = IInfiniteProxy(address(LIQUIDITY))
            .getImplementationSigs(OLD_USER_MODULE);
        uint256 len = baseSigs_.length;
        bytes4[] memory sigs_ = new bytes4[](len + 1);
        for (uint256 i; i < len; ++i) {
            sigs_[i] = baseSigs_[i];
        }
        sigs_[len] = OPERATE_ON_BEHALF_OF_SIG;

        IInfiniteProxy(address(LIQUIDITY)).removeImplementation(
            OLD_USER_MODULE
        );

        IInfiniteProxy(address(LIQUIDITY)).addImplementation(
            newUserModule_,
            sigs_
        );
    }

    /// @notice Action 4: Register DummyImplementation rollback on RollbackModule (must happen before the actual update)
    function action4() internal isActionSkippable(4) {
        IFluidLiquidityRollback(address(LIQUIDITY))
            .registerRollbackDummyImplementation();
    }

    /// @notice Action 5: Update DummyImplementation on LL to settable address
    function action5() internal isActionSkippable(5) {
        address newDummyImpl_ = PayloadIGP126(ADDRESS_THIS)
            .dummyImplementationAddress();
        require(newDummyImpl_ != address(0), "dummy-impl-not-set");

        IInfiniteProxy(address(LIQUIDITY)).setDummyImplementation(
            newDummyImpl_
        );
    }

    /// @notice Action 6: Set a contract as auth on LL (for operateOnBehalfOf)
    function action6() internal isActionSkippable(6) {
        address authAddress_ = PayloadIGP126(ADDRESS_THIS).onBehalfOfAuth();
        require(authAddress_ != address(0), "on-behalf-of-auth-not-set");

        FluidLiquidityAdminStructs.AddressBool[]
            memory authsStatus_ = new FluidLiquidityAdminStructs.AddressBool[](
                1
            );
        authsStatus_[0] = FluidLiquidityAdminStructs.AddressBool({
            addr: authAddress_,
            value: true
        });
        LIQUIDITY.updateAuths(authsStatus_);
    }

    /// @notice Action 7: Set new owner of VaultFactory (for position transfer wrapper)
    function action7() internal isActionSkippable(7) {
        address newOwner_ = PayloadIGP126(ADDRESS_THIS).vaultFactoryOwner();
        require(newOwner_ != address(0), "vault-factory-owner-not-set");

        IOwnable(address(VAULT_FACTORY)).transferOwnership(newOwner_);
    }

    /// @notice Action 8: Set max restricted borrow limits on all wstUSR vaults
    function action8() internal isActionSkippable(8) {
        // --- Borrow limits at Liquidity Layer (T1 and T2 vaults) ---

        // Vault 110: wstUSR / USDC (T1)
        setBorrowProtocolLimitsPaused(getVaultAddress(110), USDC_ADDRESS);

        // Vault 111: wstUSR / USDT (T1)
        setBorrowProtocolLimitsPaused(getVaultAddress(111), USDT_ADDRESS);

        // Vault 112: wstUSR / GHO (T1)
        setBorrowProtocolLimitsPaused(getVaultAddress(112), GHO_ADDRESS);

        // skip 113 wstUSR-USDT / USDT: already max restricted / deprecated

        // Vault 133: wstUSR-USDC <> USDC (T2)
        setBorrowProtocolLimitsPaused(getVaultAddress(133), USDC_ADDRESS);

        // skip 142 wstUSR / USDtb: already max restricted / deprecated

        // --- Borrow limits at DEX level (T3 and T4 vaults) ---

        address USDC_USDT_DEX = getDexAddress(2);
        address USDC_USDT_CONCENTRATED_DEX = getDexAddress(34);

        // Vault 134: wstUSR-USDC <> USDC-USDT (T4) — borrows from USDC-USDT DEX
        setBorrowProtocolLimitsPausedDex(USDC_USDT_DEX, getVaultAddress(134));

        // skip 135 wstUSR-USDC / USDC-USDT concentrated: already max restricted / deprecated

        // Vault 143: wstUSR <> USDC-USDT (T3) — borrows from USDC-USDT DEX
        setBorrowProtocolLimitsPausedDex(USDC_USDT_DEX, getVaultAddress(143));

        // Vault 144: wstUSR <> USDC-USDT concentrated (T3) — borrows from USDC-USDT concentrated DEX
        setBorrowProtocolLimitsPausedDex(
            USDC_USDT_CONCENTRATED_DEX,
            getVaultAddress(144)
        );
    }

    /// @notice Action 9: Pause `swapAndArbitrage` on all wstUSR-related DEXes
    function action9() internal isActionSkippable(9) {
        IFluidDex(getDexAddress(27)).pauseSwapAndArbitrage(); // wstUSR-USDC
        // skip 29 wstUSR-USDT: already max restricted / deprecated
    }

    /// @notice Action 10: Set pauseableAuth as auth on Liquidity Layer
    function action10() internal isActionSkippable(10) {
        address authAddress_ = PayloadIGP126(ADDRESS_THIS).pauseableAuth();
        require(authAddress_ != address(0), "pauseable-auth-not-set");

        FluidLiquidityAdminStructs.AddressBool[]
            memory authsStatus_ = new FluidLiquidityAdminStructs.AddressBool[](
                1
            );
        authsStatus_[0] = FluidLiquidityAdminStructs.AddressBool({
            addr: authAddress_,
            value: true
        });
        LIQUIDITY.updateAuths(authsStatus_);
    }

    /// @notice Action 11: Set pausableDexAuth as globalAuth on DexFactory
    function action11() internal isActionSkippable(11) {
        address authAddress_ = PayloadIGP126(ADDRESS_THIS).pausableDexAuth();
        require(authAddress_ != address(0), "pausable-dex-auth-not-set");

        DEX_FACTORY.setGlobalAuth(authAddress_, true);
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants
    uint256 public constant ETH_USD_PRICE = 2_000 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 3_575 * 1e2;
    uint256 public constant weETH_USD_PRICE = 3_050 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 2_980 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 2_920 * 1e2;
    uint256 public constant mETH_USD_PRICE = 3_040 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 3_000 * 1e2;
    uint256 public constant OSETH_USD_PRICE = 3_060 * 1e2;

    uint256 public constant BTC_USD_PRICE = 69_000 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.20 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.08 * 1e2;
    uint256 public constant syrupUSDT_USD_PRICE = 1.10 * 1e2;
    uint256 public constant syrupUSDC_USD_PRICE = 1.14 * 1e2;
    uint256 public constant REUSD_USD_PRICE = 1.06 * 1e2;
    uint256 public constant csUSDL_USD_PRICE = 1.03 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 2.19 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.26 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.12 * 1e2;
    uint256 public constant XAUT_USD_PRICE = 4_040 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 4_050 * 1e2;
    uint256 public constant JRUSDE_USD_PRICE = 1.00 * 1e2;
    uint256 public constant SRUSDE_USD_PRICE = 1.00 * 1e2;

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
        } else if (token == OSETH_ADDRESS) {
            usdPrice = OSETH_USD_PRICE;
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
        } else if (token == syrupUSDT_ADDRESS) {
            usdPrice = syrupUSDT_USD_PRICE;
            decimals = 6;
        } else if (token == syrupUSDC_ADDRESS) {
            usdPrice = syrupUSDC_USD_PRICE;
            decimals = 6;
        } else if (token == REUSD_ADDRESS) {
            usdPrice = REUSD_USD_PRICE;
            decimals = 18;
        } else if (token == csUSDL_ADDRESS) {
            usdPrice = csUSDL_USD_PRICE;
            decimals = 18;
        } else if (token == JRUSDE_ADDRESS) {
            usdPrice = JRUSDE_USD_PRICE;
            decimals = 18;
        } else if (token == SRUSDE_ADDRESS) {
            usdPrice = SRUSDE_USD_PRICE;
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
