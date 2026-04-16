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

interface IVaultFactoryOwner {
    function setGlobalAuth(address globalAuth_, bool allowed_) external;
}

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
import {
    IFluidLiquidityRollback
} from "../common/interfaces/IFluidLiquidityRollback.sol";
import {PayloadIGPConstants} from "../common/constants.sol";
import {PayloadIGPHelpers} from "../common/helpers.sol";
import {PayloadIGPMain} from "../common/main.sol";

/// @notice IGP128: Set timelock as global auth on VaultFactory, upgrade admin module on LL, update USDC/USDT rate curve, and update sUSDe-USDT DEX range.
contract PayloadIGP128 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 128;

    address public constant VAULT_FACTORY_OWNER =
        0xB031913cB7AD81b8A4Ba412B471c2dA69BEA410B;

    address public constant OLD_ADMIN_MODULE =
        0x53EFFA0e612d88f39Ab32eb5274F2fae478d261C;

    address public constant NEW_ADMIN_MODULE =
        0xea78faBC13D603895FE9efe8BB4A4F2c56e5698E;

    function execute() public virtual override {
        super.execute();

        // Action 1: Set timelock as global auth on VaultFactory (via VaultFactoryOwner wrapper)
        action1();

        // Action 2: Register AdminModule LL upgrade on RollbackModule
        action2();

        // Action 3: Upgrade AdminModule LL on InfiniteProxy
        action3();

        // Action 4: Update USDC & USDT Interest Rate Curve on Ethereum
        action4();

        // Action 5: Update CF, LT, LML for ETH vaults (11, 12, 45, 54, 128)
        action5();

        // Action 6: Update sUSDe-USDT DEX range percents
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

    /// @notice Action 1: Set timelock as global auth on VaultFactory via VaultFactoryOwner wrapper
    function action1() internal isActionSkippable(1) {
        IVaultFactoryOwner(VAULT_FACTORY_OWNER).setGlobalAuth(
            address(TIMELOCK),
            true
        );
    }

    /// @notice Action 2: Register AdminModule LL upgrade on RollbackModule (must happen before the actual upgrade)
    function action2() internal isActionSkippable(2) {
        IFluidLiquidityRollback(address(LIQUIDITY))
            .registerRollbackImplementation(OLD_ADMIN_MODULE, NEW_ADMIN_MODULE);
    }

    /// @notice Action 3: Upgrade AdminModule LL on InfiniteProxy
    function action3() internal isActionSkippable(3) {
        bytes4[] memory baseSigs_ = IInfiniteProxy(address(LIQUIDITY))
            .getImplementationSigs(OLD_ADMIN_MODULE);
        uint256 len = baseSigs_.length;
        bytes4[] memory sigs_ = new bytes4[](len + 2);
        for (uint256 i; i < len; ++i) {
            sigs_[i] = baseSigs_[i];
        }
        sigs_[len] = bytes4(keccak256("pauseTokens(address[])"));
        sigs_[len + 1] = bytes4(keccak256("unpauseTokens(address[])"));

        IInfiniteProxy(address(LIQUIDITY)).removeImplementation(
            OLD_ADMIN_MODULE
        );

        IInfiniteProxy(address(LIQUIDITY)).addImplementation(
            NEW_ADMIN_MODULE,
            sigs_
        );
    }

    /// @notice Action 4: Update USDC & USDT rate-curve kinks (90%, 95%) while keeping kink rates (4.5%, 7.5%)
    function action4() internal isActionSkippable(4) {
        FluidLiquidityAdminStructs.RateDataV2Params[]
            memory params_ = new FluidLiquidityAdminStructs.RateDataV2Params[](
                2
            );

        params_[0] = FluidLiquidityAdminStructs.RateDataV2Params({
            token: USDC_ADDRESS,
            kink1: 90 * 1e2, // 90%
            kink2: 95 * 1e2, // 95%
            rateAtUtilizationZero: 0, // 0%
            rateAtUtilizationKink1: 4.5 * 1e2, // 4.5%
            rateAtUtilizationKink2: 7.5 * 1e2, // 7.5%
            rateAtUtilizationMax: 100 * 1e2 // 100%
        });

        params_[1] = FluidLiquidityAdminStructs.RateDataV2Params({
            token: USDT_ADDRESS,
            kink1: 90 * 1e2, // 90%
            kink2: 95 * 1e2, // 95%
            rateAtUtilizationZero: 0, // 0%
            rateAtUtilizationKink1: 4.5 * 1e2, // 4.5%
            rateAtUtilizationKink2: 7.5 * 1e2, // 7.5%
            rateAtUtilizationMax: 100 * 1e2 // 100%
        });

        LIQUIDITY.updateRateDataV2s(params_);
    }

    /// @notice Action 5: Update CF, LT, LML for ETH vaults (11, 12, 45, 54, 128)
    function action5() internal isActionSkippable(5) {
        uint256 CF = 90 * 1e2; // 90%
        uint256 LT = 93 * 1e2; // 93%
        uint256 LML = 96 * 1e2; // 96%

        uint256[] memory vaultIds = new uint256[](5);
        vaultIds[0] = 11;
        vaultIds[1] = 12;
        vaultIds[2] = 45;
        vaultIds[3] = 54;
        vaultIds[4] = 128;

        for (uint256 i = 0; i < vaultIds.length; i++) {
            address vaultAddress = getVaultAddress(vaultIds[i]);

            IFluidVaultT1(vaultAddress).updateLiquidationMaxLimit(LML);
            IFluidVaultT1(vaultAddress).updateLiquidationThreshold(LT);
            IFluidVaultT1(vaultAddress).updateCollateralFactor(CF);
        }
    }

    /// @notice Action 6: Update sUSDe-USDT DEX (ID: 15) range percents
    function action6() internal isActionSkippable(6) {
        address sUSDe_USDT_DEX = getDexAddress(15);

        IFluidDex(sUSDe_USDT_DEX).updateRangePercents(
            0.15 * 1e4, // upper range: 0.15%
            0.4 * 1e4, // lower range: 0.4%
            5 days
        );
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
