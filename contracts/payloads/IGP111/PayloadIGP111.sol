pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "../libraries/bigMathMinified.sol";
import {LiquidityCalcs} from "../libraries/liquidityCalcs.sol";
import {LiquiditySlotsLink} from "../libraries/liquiditySlotsLink.sol";

import {IGovernorBravo} from "../common/interfaces/IGovernorBravo.sol";
import {ITimelock} from "../common/interfaces/ITimelock.sol";

import {IFluidLiquidityAdmin, AdminModuleStructs as FluidLiquidityAdminStructs} from "../common/interfaces/IFluidLiquidity.sol";
import {IFluidReserveContract} from "../common/interfaces/IFluidReserveContract.sol";

import {IFluidVaultFactory} from "../common/interfaces/IFluidVaultFactory.sol";
import {IFluidDexFactory} from "../common/interfaces/IFluidDexFactory.sol";

import {IFluidDex, IFluidAdminDex, IFluidDexResolver} from "../common/interfaces/IFluidDex.sol";

import {IFluidVault, IFluidVaultT1} from "../common/interfaces/IFluidVault.sol";

import {IFTokenAdmin, ILendingRewards} from "../common/interfaces/IFToken.sol";

import {ISmartLendingAdmin} from "../common/interfaces/ISmartLending.sol";
import {ISmartLendingFactory} from "../common/interfaces/ISmartLendingFactory.sol";
import {IFluidLendingFactory} from "../common/interfaces/IFluidLendingFactory.sol";

import {ICodeReader} from "../common/interfaces/ICodeReader.sol";

import {IDSAV2} from "../common/interfaces/IDSA.sol";
import {IERC20} from "../common/interfaces/IERC20.sol";
import {IProxy} from "../common/interfaces/IProxy.sol";
import {PayloadIGPConstants} from "../common/constants.sol";
import {PayloadIGPHelpers} from "../common/helpers.sol";
import {PayloadIGPMain} from "../common/main.sol";

contract PayloadIGP111 is PayloadIGPMain {
    uint256 public constant PROPOSAL_ID = 111;

    function execute() public virtual override {
        super.execute();

        // Action 1: Set launch limits for syrupUSDT DEX and its vaults
        action1();

        // Action 2: Collect Revenue from Liquidity Layer for Buybacks
        action2();

        // Action 3: Set dust limits for USDE-JRUSDE and SRUSDE-USDE DEXes
        action3();

        // Action 4: Collect Lite's Revenue for Buybacks
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

    /// @notice Action 1: Set launch limits for syrupUSDT DEX and its vaults
    function action1() internal isActionSkippable(1) {
        {
            // syrupUSDT-USDT DEX
            address syrupUSDT_USDT_DEX = getDexAddress(40);
            DexConfig memory DEX_syrupUSDT_USDT = DexConfig({
                dex: syrupUSDT_USDT_DEX,
                tokenA: syrupUSDT_ADDRESS,
                tokenB: USDT_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000_000, // $10M
                baseBorrowLimitInUSD: 0, // $0
                maxBorrowLimitInUSD: 0 // $0
            });
            setDexLimits(DEX_syrupUSDT_USDT); // Smart Collateral

            DEX_FACTORY.setDexAuth(syrupUSDT_USDT_DEX, TEAM_MULTISIG, false);
        }
        {
            // [TYPE 2] syrupUSDT-USDT<>USDT | smart collateral & debt
            address syrupUSDT_USDT__USDT_VAULT = getVaultAddress(149);
            VaultConfig memory VAULT_syrupUSDT_USDT__USDT = VaultConfig({
                vault: syrupUSDT_USDT__USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_2,
                supplyToken: address(0),
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 0,
                baseBorrowLimitInUSD: 10_000_000, // $10M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_syrupUSDT_USDT__USDT); // TYPE_2 => 149
            VAULT_FACTORY.setVaultAuth(
                syrupUSDT_USDT__USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
        {
            // launch limits for syrupUSDT/USDC vault
            address syrupUSDT__USDC_VAULT = getVaultAddress(150);
            // [TYPE 1] syrupUSDT/USDC vault - Launch limits
            VaultConfig memory VAULT_syrupUSDT__USDC = VaultConfig({
                vault: syrupUSDT__USDC_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: syrupUSDT_ADDRESS,
                borrowToken: USDC_ADDRESS,
                baseWithdrawalLimitInUSD: 10_000_000, // $10M
                baseBorrowLimitInUSD: 10_000_000, // $10M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_syrupUSDT__USDC);
            VAULT_FACTORY.setVaultAuth(
                syrupUSDT__USDC_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
        {
            // launch limits for syrupUSDT/USDT vault
            address syrupUSDT__USDT_VAULT = getVaultAddress(151);
            // [TYPE 1] syrupUSDT/USDT vault - Launch limits
            VaultConfig memory VAULT_syrupUSDT__USDT = VaultConfig({
                vault: syrupUSDT__USDT_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: syrupUSDT_ADDRESS,
                borrowToken: USDT_ADDRESS,
                baseWithdrawalLimitInUSD: 10_000_000, // $10M
                baseBorrowLimitInUSD: 10_000_000, // $10M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_syrupUSDT__USDT);
            VAULT_FACTORY.setVaultAuth(
                syrupUSDT__USDT_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
        {
            // launch limits for syrupUSDT/GHO vault
            address syrupUSDT__GHO_VAULT = getVaultAddress(152);
            // [TYPE 1] syrupUSDT/GHO vault - Launch limits
            VaultConfig memory VAULT_syrupUSDT__GHO = VaultConfig({
                vault: syrupUSDT__GHO_VAULT,
                vaultType: VAULT_TYPE.TYPE_1,
                supplyToken: syrupUSDT_ADDRESS,
                borrowToken: GHO_ADDRESS,
                baseWithdrawalLimitInUSD: 10_000_000, // $10M
                baseBorrowLimitInUSD: 10_000_000, // $10M
                maxBorrowLimitInUSD: 20_000_000 // $20M
            });

            setVaultLimits(VAULT_syrupUSDT__GHO);
            VAULT_FACTORY.setVaultAuth(
                syrupUSDT__GHO_VAULT,
                TEAM_MULTISIG,
                false
            );
        }
    }

    /// @notice Action 2: Collect revenue from Liquidity Layer
    function action2() internal isActionSkippable(2) {
        {
            address[] memory tokens = new address[](14);
            tokens[0] = USDT_ADDRESS;
            tokens[1] = wstETH_ADDRESS;
            tokens[2] = ETH_ADDRESS;
            tokens[3] = USDC_ADDRESS;
            tokens[4] = sUSDe_ADDRESS;
            tokens[5] = cbBTC_ADDRESS;
            tokens[6] = WBTC_ADDRESS;
            tokens[7] = GHO_ADDRESS;
            tokens[8] = USDe_ADDRESS;
            tokens[9] = wstUSR_ADDRESS;
            tokens[10] = ezETH_ADDRESS;
            tokens[11] = lBTC_ADDRESS;
            tokens[12] = USDTb_ADDRESS;
            tokens[13] = RLP_ADDRESS;
            LIQUIDITY.collectRevenue(tokens);
        }
        {
            address[] memory tokens = new address[](14);
            uint256[] memory amounts = new uint256[](14);
            tokens[0] = USDT_ADDRESS;
            amounts[0] =
                IERC20(USDT_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            tokens[1] = wstETH_ADDRESS;
            amounts[1] =
                IERC20(wstETH_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                0.1 ether;
            tokens[2] = ETH_ADDRESS;
            amounts[2] = address(FLUID_RESERVE).balance - 0.1 ether; // 0.1 ETH
            tokens[3] = USDC_ADDRESS;
            amounts[3] =
                IERC20(USDC_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            tokens[4] = sUSDe_ADDRESS;
            amounts[4] =
                IERC20(sUSDe_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                0.1 ether;
            tokens[5] = cbBTC_ADDRESS;
            amounts[5] =
                IERC20(cbBTC_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            tokens[6] = WBTC_ADDRESS;
            amounts[6] =
                IERC20(WBTC_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            tokens[7] = GHO_ADDRESS;
            amounts[7] =
                IERC20(GHO_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            tokens[8] = USDe_ADDRESS;
            amounts[8] =
                IERC20(USDe_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            tokens[9] = wstUSR_ADDRESS;
            amounts[9] =
                IERC20(wstUSR_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            tokens[10] = ezETH_ADDRESS;
            amounts[10] =
                IERC20(ezETH_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                0.1 ether;
            tokens[11] = lBTC_ADDRESS;
            amounts[11] =
                IERC20(lBTC_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            tokens[12] = USDTb_ADDRESS;
            amounts[12] =
                IERC20(USDTb_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            tokens[13] = RLP_ADDRESS;
            amounts[13] =
                IERC20(RLP_ADDRESS).balanceOf(address(FLUID_RESERVE)) -
                10;
            FLUID_RESERVE.withdrawFunds(tokens, amounts, TEAM_MULTISIG);
        }
    }

    /// @notice Action 3: Set dust limits for USDE-JRUSDE and SRUSDE-USDE DEXes
    function action3() internal isActionSkippable(3) {
        {
            // DEX 41: USDE-JRUSDE
            address USDE_JRUSDE_DEX = getDexAddress(41);
            DexConfig memory DEX_USDE_JRUSDE = DexConfig({
                dex: USDE_JRUSDE_DEX,
                tokenA: USDe_ADDRESS,
                tokenB: JRUSDE_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0, // $0
                maxBorrowLimitInUSD: 0 // $0
            });
            setDexLimits(DEX_USDE_JRUSDE); // Smart Collateral

            DEX_FACTORY.setDexAuth(USDE_JRUSDE_DEX, TEAM_MULTISIG, true);
        }
        {
            // DEX 42: SRUSDE-USDE
            address SRUSDE_USDE_DEX = getDexAddress(42);
            DexConfig memory DEX_SRUSDE_USDE = DexConfig({
                dex: SRUSDE_USDE_DEX,
                tokenA: SRUSDE_ADDRESS,
                tokenB: USDe_ADDRESS,
                smartCollateral: true,
                smartDebt: false,
                baseWithdrawalLimitInUSD: 10_000, // $10k
                baseBorrowLimitInUSD: 0, // $0
                maxBorrowLimitInUSD: 0 // $0
            });
            setDexLimits(DEX_SRUSDE_USDE); // Smart Collateral

            DEX_FACTORY.setDexAuth(SRUSDE_USDE_DEX, TEAM_MULTISIG, true);
        }
    }

    /// @notice Action 4: Collect Lite's Revenue for Buybacks
    function action4() internal isActionSkippable(4) {
        string[] memory targets = new string[](1);
        bytes[] memory encodedSpells = new bytes[](1);

        string
            memory withdrawSignature = "withdraw(address,uint256,address,uint256,uint256)";

        // Spell 1: Transfer 82.8 stETH from iETHv2 to Team Multisig
        {
            uint256 STETH_AMOUNT = 82.8 * 1e18; // 82.8 stETH
            targets[0] = "BASIC-A";
            encodedSpells[0] = abi.encodeWithSignature(
                withdrawSignature,
                stETH_ADDRESS,
                STETH_AMOUNT,
                address(TEAM_MULTISIG),
                0,
                0
            );
        }

        IDSAV2(TREASURY).cast(targets, encodedSpells, address(this));
    }
    /**
     * |
     * |     Payload Actions End Here      |
     * |__________________________________
     */

    // Token Prices Constants (same as other IGP files)
    uint256 public constant ETH_USD_PRICE = 2_500 * 1e2;
    uint256 public constant wstETH_USD_PRICE = 3_050 * 1e2;
    uint256 public constant weETH_USD_PRICE = 2_700 * 1e2;
    uint256 public constant rsETH_USD_PRICE = 2_650 * 1e2;
    uint256 public constant weETHs_USD_PRICE = 2_600 * 1e2;
    uint256 public constant mETH_USD_PRICE = 2_690 * 1e2;
    uint256 public constant ezETH_USD_PRICE = 2_650 * 1e2;

    uint256 public constant BTC_USD_PRICE = 103_000 * 1e2;

    uint256 public constant STABLE_USD_PRICE = 1 * 1e2;
    uint256 public constant sUSDe_USD_PRICE = 1.17 * 1e2;
    uint256 public constant sUSDs_USD_PRICE = 1.05 * 1e2;
    uint256 public constant syrupUSDT_USD_PRICE = 1.10 * 1e2;
    uint256 public constant syrupUSDC_USD_PRICE = 1.13 * 1e2;

    uint256 public constant FLUID_USD_PRICE = 4.2 * 1e2;

    uint256 public constant RLP_USD_PRICE = 1.18 * 1e2;
    uint256 public constant wstUSR_USD_PRICE = 1.07 * 1e2;
    uint256 public constant XAUT_USD_PRICE = 3_240 * 1e2;
    uint256 public constant PAXG_USD_PRICE = 3_240 * 1e2;
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
