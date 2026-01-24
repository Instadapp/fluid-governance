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
    IFluidReserveContract,
    IFluidReserveContractV2
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

import {ISmartLendingAdmin} from "../common/interfaces/ISmartLending.sol";
import {
    ISmartLendingFactory
} from "../common/interfaces/ISmartLendingFactory.sol";
import {
    IFluidLendingFactory
} from "../common/interfaces/IFluidLendingFactory.sol";

import {ICodeReader} from "../common/interfaces/ICodeReader.sol";
import {IDSAV2} from "../common/interfaces/IDSA.sol";
import {IERC20} from "../common/interfaces/IERC20.sol";
import {IInfiniteProxy} from "../common/interfaces/IInfiniteProxy.sol";
import {PayloadIGPConstants} from "../common/constants.sol";
import {PayloadIGPHelpers} from "../common/helpers.sol";
import {PayloadIGPMain} from "../common/main.sol";
import {ILite} from "../common/interfaces/ILite.sol";

contract PayloadIGP117 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 117;

    function execute() public virtual override {
        super.execute();

        // Action 1: Restrict limits and pause wstUSR-USDT DEX and remove MS auth
        action1();

        // Action 2: Restrict limits and pause vaults 142, 113, 135
        action2();

        // Action 3: Remove MS auth from deprecated dexes 5, 6, 7, 8, 10, 34
        action3();

        // Action 4: Update range percents for syrupUSDC-USDC DEX
        action4();
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

    /// @notice Action 1: Restrict limits and pause wstUSR-USDT DEX and remove MS auth
    function action1() internal isActionSkippable(1) {
        address wstUSR_USDT_DEX = getDexAddress(29);

        // Max restrict supply shares
        IFluidDex(wstUSR_USDT_DEX).updateMaxSupplyShares(10);

        // Pause supply limits at LL for the DEX (smart collateral tokens: wstUSR, USDT)
        setSupplyProtocolLimitsPaused(wstUSR_USDT_DEX, wstUSR_ADDRESS);
        setSupplyProtocolLimitsPaused(wstUSR_USDT_DEX, USDT_ADDRESS);

        // Remove Team Multisig auth
        DEX_FACTORY.setDexAuth(wstUSR_USDT_DEX, TEAM_MULTISIG, false);
    }

    /// @notice Action 2: Restrict limits and pause vaults 142, 113, 135
    function action2() internal isActionSkippable(2) { 
        { // Vault 142: wstUSR/USDTb (TYPE 1)
            address wstUSR_USDTb_VAULT = getVaultAddress(142);

            // Pause supply and borrow at LL
            setSupplyProtocolLimitsPaused(wstUSR_USDTb_VAULT, wstUSR_ADDRESS);
            setBorrowProtocolLimitsPaused(wstUSR_USDTb_VAULT, USDTb_ADDRESS);
        }

        { // Vault 113: wstUSR-USDT<>USDT (TYPE 2)
            address wstUSR_USDT__USDT_VAULT = getVaultAddress(113);
            address wstUSR_USDT_DEX = getDexAddress(29);

            // Pause supply side at DEX level
            setSupplyProtocolLimitsPausedDex(
                wstUSR_USDT_DEX,
                wstUSR_USDT__USDT_VAULT
            );

            // Pause vault at DEX level
            IFluidDex(wstUSR_USDT_DEX).pauseUser(
                wstUSR_USDT__USDT_VAULT,
                true, // pause supply side
                false
            );

            // Pause borrow at LL
            setBorrowProtocolLimitsPaused(wstUSR_USDT__USDT_VAULT, USDT_ADDRESS);

            // Remove Team Multisig auth from vault
            VAULT_FACTORY.setVaultAuth(
                wstUSR_USDT__USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }

        // Vault 135: wstUSR-USDC<>USDC-USDT concentrated (TYPE 3)
        {
            address wstUSR_USDC__USDC_USDT_CONCENTRATED_VAULT = getVaultAddress(
                135
            );
            address USDC_USDT_CONCENTRATED_DEX = getDexAddress(34);

            // Pause supply at LL
            setSupplyProtocolLimitsPaused(
                wstUSR_USDC__USDC_USDT_CONCENTRATED_VAULT,
                wstUSR_ADDRESS
            );

            // Pause borrow side at DEX level
            setBorrowProtocolLimitsPausedDex(
                USDC_USDT_CONCENTRATED_DEX,
                wstUSR_USDC__USDC_USDT_CONCENTRATED_VAULT
            );

            // Pause vault at DEX level (borrow side)
            IFluidDex(USDC_USDT_CONCENTRATED_DEX).pauseUser(
                wstUSR_USDC__USDC_USDT_CONCENTRATED_VAULT,
                false, // no supply side at this DEX
                true // pause borrow side
            );
        }
    }

    /// @notice Action 3: Remove MS auth from deprecated dexes 5, 6, 7, 8, 10, 34
    function action3() internal isActionSkippable(3) {
        // DEX 5: USDC-ETH
        DEX_FACTORY.setDexAuth(getDexAddress(5), TEAM_MULTISIG, false);

        // DEX 6: WBTC-ETH
        DEX_FACTORY.setDexAuth(getDexAddress(6), TEAM_MULTISIG, false);

        // DEX 7: cbBTC-ETH
        DEX_FACTORY.setDexAuth(getDexAddress(7), TEAM_MULTISIG, false);

        // DEX 8: USDe-USDC
        DEX_FACTORY.setDexAuth(getDexAddress(8), TEAM_MULTISIG, false);

        // DEX 10: FLUID-ETH
        DEX_FACTORY.setDexAuth(getDexAddress(10), TEAM_MULTISIG, false);

        // DEX 34: USDC-USDT concentrated
        DEX_FACTORY.setDexAuth(getDexAddress(34), TEAM_MULTISIG, false);
    }

    /// @notice Action 4: Update range percents for syrupUSDC-USDC DEX
    function action4() internal isActionSkippable(4) {
        address syrupUSDC_USDC_DEX = getDexAddress(39);

        // Update range: Upper 0.0001%, Lower 0.4%
        IFluidDex(syrupUSDC_USDC_DEX).updateRangePercents(
            0.0001 * 1e4, // upper range: 0.0001%
            0.4 * 1e4, // lower range: 0.4%
            0 // instant
        );
    }

    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants (same as other IGP files)
    uint256 public constant ETH_USD_PRICE = 2_900 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 3_575 * 1e2;
    uint256 public constant weETH_USD_PRICE = 3_050 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 2_980 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 2_920 * 1e2;
    uint256 public constant mETH_USD_PRICE = 3_040 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 3_000 * 1e2;
    uint256 public constant OSETH_USD_PRICE = 3_060 * 1e2;

    uint256 public constant BTC_USD_PRICE = 86_000 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.20 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.08 * 1e2;
    uint256 public constant syrupUSDT_USD_PRICE = 1.10 * 1e2;
    uint256 public constant syrupUSDC_USD_PRICE = 1.14 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 3.32 * 1e2;

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
